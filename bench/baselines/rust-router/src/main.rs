// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Noncommercial use is free; commercial use requires a paid license.
// See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

//! The Hive Router query planner baseline of gql_router.
//!
//! `hive-router/query_plan` is the `query_plan` benchmark of upstream
//! `bin/router/benches/qp_benches.rs`: the supergraph state, the graph and
//! the normalized `TestQuery` are built once, and one operation walks the
//! operation, finds the best combination, builds the fetch graph and builds
//! the query plan. The fixtures are upstream `bench/supergraph.graphql` and
//! `bench/operation.graphql`, copied to `bench/fixtures/hive-router-qp/`.
//!
//! `hive-router/execute` is one upstream `execute_query_plan` call
//! (`bin/router/src/executor/execution/plan.rs`) for the plan of the same
//! `TestQuery`. It prepares the fetches and the entity representations,
//! builds each subgraph request body, turns canned response bytes into a
//! `SubgraphResponse` with `SubgraphResponse::deserialize_from_bytes`,
//! merges, and projects the final response with the projection plan. The
//! subgraphs answer in-process, with no network. The planner, the
//! normalized operation, the query plan, the projection plan, the schema
//! metadata, the executor map and the plugin state are built once, in the
//! style of upstream `bin/router/benches/executor_benches.rs`. See
//! `execute.rs` for how a plugin injects the canned responses. Before the
//! timing, the program checks once that the body equals
//! `bench/fixtures/hive-router-exec/expected_response.json` byte for byte.
//!
//! `hive-router/subscription-event` is what the stream of upstream
//! `execute_query_plan` does for one event of `subscription { reviewAdded
//! { id body product { upc name } } }` on upstream `e2e/supergraph.graphql`:
//! it reads the `reviews` event with `SubgraphResponse::deserialize_from_bytes`,
//! runs the rest of the plan (the `products` entity fetch, answered from
//! `bench/fixtures/hive-router-sub/responses.json`) with
//! `execute_query_plan_with_data`, and projects. `build.sh` makes that
//! function public; upstream keeps it private.
//!
//! `--record` regenerates `bench/fixtures/hive-router-exec/` from the real
//! upstream bench subgraphs (`upstream/bench/subgraphs`, port 4200):
//!
//! ```sh
//! (cd upstream && cargo build --release -p subgraphs --features hive-router/graphiql \
//!   && ./target/release/subgraphs &)
//! ./target/release/mojographql-bench-router-rust --record
//! ```
//!
//! The timing method is the one of bench/gql_language/_harness.mojo: warm
//! up, then rounds of at least `ROUND_NS` each, and report the fastest
//! round as `BENCH <workload> <ns per op>`.

mod execute;

use std::hint::black_box;
use std::path::PathBuf;
use std::time::Instant;

use hive_router::query_planner::ast::normalization::normalize_operation;
use hive_router::query_planner::graph::Graph;
use hive_router::query_planner::graph::PlannerOverrideContext;
use hive_router::query_planner::planner::best::find_best_combination;
use hive_router::query_planner::planner::fetch::fetch_graph::build_fetch_graph_from_query_tree;
use hive_router::query_planner::planner::query_plan::build_query_plan_from_fetch_graph;
use hive_router::query_planner::planner::walker::walk_operation;
use hive_router::query_planner::planner::QueryPlannerOptions;
use hive_router::query_planner::state::supergraph_state::SupergraphState;
use hive_router::query_planner::utils::cancellation::CancellationToken;
use hive_router::query_planner::utils::parsing::{parse_operation, parse_schema};

const ROUND_NS: u128 = 1_000_000_000;
const ROUNDS: usize = 5;
const WARMUP_NS: u128 = 200_000_000;

/// Read a fixture from bench/fixtures/. The program runs from
/// bench/baselines/rust-router/, as tools/bench.mojo runs it.
fn fixture(name: &str) -> String {
    let path = fixture_path(name);
    std::fs::read_to_string(&path).unwrap_or_else(|e| panic!("{}: {e}", path.display()))
}

/// The path of a fixture in bench/fixtures/.
fn fixture_path(name: &str) -> PathBuf {
    PathBuf::from("../../fixtures").join(name)
}

fn run(work: &mut dyn FnMut() -> usize, iterations: u64) -> u128 {
    let mut sink = 0usize;
    let start = Instant::now();
    for _ in 0..iterations {
        sink = sink.wrapping_add(work());
    }
    let elapsed = start.elapsed().as_nanos();
    black_box(sink);
    elapsed
}

/// Time one workload and print its `BENCH` line.
fn measure(name: &str, mut work: impl FnMut() -> usize) {
    let work: &mut dyn FnMut() -> usize = &mut work;
    let mut iterations: u64 = 1;
    let mut warm: u128 = 0;
    loop {
        let elapsed = run(work, iterations);
        warm += elapsed;
        if elapsed * 4 >= WARMUP_NS || warm >= WARMUP_NS {
            let per_op = (elapsed / iterations as u128).max(1);
            iterations = ((ROUND_NS / per_op) as u64).max(1);
            break;
        }
        iterations *= 2;
    }
    let mut best = f64::MAX;
    for _ in 0..ROUNDS {
        let elapsed = run(work, iterations);
        best = best.min(elapsed as f64 / iterations as f64);
    }
    println!("BENCH {name} {best:.1}");
}

fn main() {
    hive_router::init_rustls_crypto_provider();
    // One current-thread runtime, built outside the timed loop.
    let rt = hive_router::tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .expect("tokio runtime");
    let _guard = rt.enter();
    if std::env::args().any(|arg| arg == "--record") {
        execute::record(&rt);
        return;
    }
    query_plan();

    let execution = execute::Execution::canned();
    let body = rt.block_on(execution.run());
    let expected = fixture(execute::EXPECTED);
    assert!(
        body == expected.as_bytes(),
        "the canned execution does not produce {}",
        execute::EXPECTED
    );
    measure("hive-router/execute", || {
        let body = rt.block_on(black_box(&execution).run());
        let len = body.len();
        black_box(body);
        len
    });

    let subscription = execute::Execution::subscription();
    let event = bytes::Bytes::from(fixture(execute::SUB_EVENT).trim().to_string());
    let body = rt.block_on(subscription.run_event(&event));
    let expected = fixture(execute::SUB_EXPECTED);
    assert!(
        body == expected.as_bytes(),
        "the subscription event does not produce {}: {}",
        execute::SUB_EXPECTED,
        String::from_utf8_lossy(&body)
    );
    measure("hive-router/subscription-event", || {
        let body = rt.block_on(black_box(&subscription).run_event(black_box(&event)));
        let len = body.len();
        black_box(body);
        len
    });
}

/// The `hive-router/query_plan` workload.
fn query_plan() {
    let schema = parse_schema(&fixture("hive-router-qp/supergraph.graphql"));
    let supergraph_state = SupergraphState::new(&schema);
    let graph = Graph::graph_from_supergraph_state(&supergraph_state).expect("graph");
    let document = parse_operation(&fixture("hive-router-qp/operation.graphql"));
    let operation = normalize_operation(&supergraph_state, &document, Some("TestQuery"))
        .expect("normalize")
        .operation;
    let override_context = PlannerOverrideContext::default();
    let cancellation_token = CancellationToken::new();
    let options = QueryPlannerOptions::default();

    measure("hive-router/query_plan", || {
        let best_paths_per_leaf = walk_operation(
            black_box(&graph),
            black_box(&supergraph_state),
            black_box(&override_context),
            black_box(&operation),
            &cancellation_token,
        )
        .expect("walk_operation");
        let query_tree =
            find_best_combination(&graph, best_paths_per_leaf, &cancellation_token).unwrap();
        let fetch_graph = build_fetch_graph_from_query_tree(
            &graph,
            &supergraph_state,
            &override_context,
            query_tree,
            &operation,
            &options,
            &cancellation_token,
        )
        .unwrap();
        let query_plan =
            build_query_plan_from_fetch_graph(fetch_graph, &supergraph_state, &cancellation_token)
                .unwrap();
        let nodes = query_plan.node.is_some() as usize;
        black_box(query_plan);
        nodes
    });
}

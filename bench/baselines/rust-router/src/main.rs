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
//! The timing method is the one of bench/gql_language/_harness.mojo: warm
//! up, then rounds of at least `ROUND_NS` each, and report the fastest
//! round as `BENCH <workload> <ns per op>`.

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
    let path = PathBuf::from("../../fixtures").join(name);
    std::fs::read_to_string(&path).unwrap_or_else(|e| panic!("{}: {e}", path.display()))
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

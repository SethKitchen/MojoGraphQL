// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Noncommercial use is free; commercial use requires a paid license.
// See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

//! The timing method shared by the apollo-rs baselines. It is the method of
//! bench/gql_language/_harness.mojo: warm up, then rounds of at least
//! `ROUND_NS` each, and report the fastest round as
//! `BENCH <workload> <ns per op>`.

use std::hint::black_box;
use std::path::PathBuf;
use std::time::Instant;

const ROUND_NS: u128 = 1_000_000_000;
const ROUNDS: usize = 5;
const WARMUP_NS: u128 = 200_000_000;

/// The fixtures of the shared workloads.
pub const SHARED: [&str; 3] = ["kitchen-sink", "github-schema", "github-query"];

/// The graphql-go-tools parse benchmarks and their fixtures.
pub const GO_TOOLS_PARSE: [(&str, &str); 6] = [
    ("go-tools/ParseStarwars", "go-tools-starwars.schema.graphql"),
    ("go-tools/ParseGithub", "go-tools-github.schema.graphql"),
    ("go-tools/SelectionSet", "go-tools-selection-set.graphql"),
    ("go-tools/IntrospectionQuery", "go-tools-introspection-query.graphql"),
    ("go-tools/KitchenSink", "go-tools-kitchen-sink.graphql"),
    ("go-tools/Parse", "go-tools-parse-input.graphql"),
];

/// Read a fixture from bench/fixtures/. The program runs from
/// bench/baselines/rust/, as tools/bench.mojo runs it.
pub fn fixture(name: &str) -> String {
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
pub fn measure(name: &str, mut work: impl FnMut() -> usize) {
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

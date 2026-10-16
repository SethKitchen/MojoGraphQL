// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Noncommercial use is free; commercial use requires a paid license.
// See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

//! The serde_json baseline. It prints `BENCH <workload> <ns per op>` lines
//! with the same method as bench/gql_json/json.mojo: warm up, then rounds of
//! at least ROUND_NS each, and report the fastest round.
//!
//! A parse is `serde_json::from_str::<Value>`: a tree that a program can
//! read, as the Mojo `JsonDocument`. A stringify is `serde_json::to_vec`
//! of that `Value`: new UTF-8 bytes, as Mojo `stringify_bytes` makes.

use std::hint::black_box;
use std::time::Instant;

use serde_json::Value;

const ROUND_NS: u128 = 1_000_000_000;
const ROUNDS: usize = 5;
const WARMUP_NS: u128 = 200_000_000;

fn run<T: ?Sized>(work: &dyn Fn(&T) -> usize, input: &T, iterations: u64) -> u128 {
    let mut sink = 0usize;
    let start = Instant::now();
    for _ in 0..iterations {
        sink = sink.wrapping_add(work(black_box(input)));
    }
    let elapsed = start.elapsed().as_nanos();
    black_box(sink);
    elapsed
}

fn measure<T: ?Sized>(name: &str, work: &dyn Fn(&T) -> usize, input: &T) {
    let mut iterations: u64 = 1;
    let mut warm: u128 = 0;
    loop {
        let elapsed = run(work, input, iterations);
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
        let elapsed = run(work, input, iterations);
        best = best.min(elapsed as f64 / iterations as f64);
    }
    println!("BENCH {} {:.1}", name, best);
}

/// Reads a fixture from bench/fixtures/. The program runs from
/// bench/baselines/rust-json/.
fn fixture(name: &str) -> String {
    std::fs::read_to_string(format!("../../fixtures/{}", name)).expect("fixture")
}

fn parse_once(text: &str) -> usize {
    match serde_json::from_str::<Value>(text).expect("valid JSON") {
        Value::Object(map) => map.len(),
        _ => 1,
    }
}

fn stringify_once(value: &Value) -> usize {
    serde_json::to_vec(value).expect("serializable").len()
}

fn main() {
    let introspection = fixture("github-schema.json");
    let small = fixture("small-response.json");
    let variables = fixture("variables.json");
    let introspection_value: Value = serde_json::from_str(&introspection).unwrap();
    let small_value: Value = serde_json::from_str(&small).unwrap();
    measure("json/parse-introspection", &parse_once, introspection.as_str());
    measure("json/stringify-introspection", &stringify_once, &introspection_value);
    measure("json/parse-small-response", &parse_once, small.as_str());
    measure("json/stringify-small-response", &stringify_once, &small_value);
    measure("json/parse-variables", &parse_once, variables.as_str());
}

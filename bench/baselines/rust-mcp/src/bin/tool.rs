// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

//! The Apollo MCP Server baseline of `mcp/tool-from-operation-large`: make
//! the MCP tool of one large operation of the GitHub schema, as the server
//! does for each operation file: parse, tree-shake the description, and
//! build the JSON Schemas of the variables and of the result. The method is
//! that of the Mojo benchmark: a warm-up, then the fastest of 5 rounds of at
//! least one second each.

use std::collections::HashMap;
use std::hint::black_box;
use std::time::Instant;

use apollo_compiler::Schema;
use apollo_mcp_server::operations::{MutationMode, Operation, RawOperation};

fn once(text: &str, schema: &apollo_compiler::validation::Valid<Schema>) -> usize {
    let operation = Operation::from_raw(
        RawOperation::from((text.to_string(), None)),
        schema,
        None,
        MutationMode::None,
        false,
        false,
        true,
        &HashMap::new(),
        &HashMap::new(),
    )
    .expect("the operation loads")
    .expect("the operation is a query");
    let name_length = operation.as_ref().name.len();
    black_box(operation);
    name_length
}

fn run(iterations: u64, text: &str, schema: &apollo_compiler::validation::Valid<Schema>) -> u128 {
    let start = Instant::now();
    let mut sink = 0usize;
    for _ in 0..iterations {
        sink = sink.wrapping_add(once(black_box(text), schema));
    }
    black_box(sink);
    start.elapsed().as_nanos()
}

fn main() {
    let sdl = std::fs::read_to_string("../../fixtures/github-schema.graphql")
        .expect("the schema fixture");
    let schema = Schema::parse_and_validate(sdl, "github-schema.graphql")
        .expect("the schema is valid");
    let text = std::fs::read_to_string("../../fixtures/mcp-large-operation.graphql")
        .expect("the operation fixture");
    let mut iterations = 1u64;
    loop {
        let elapsed = run(iterations, &text, &schema);
        if elapsed >= 200_000_000 {
            let per_op = (elapsed / iterations as u128).max(1);
            iterations = (1_000_000_000 / per_op).max(1) as u64;
            break;
        }
        iterations *= 2;
    }
    let mut best = f64::MAX;
    for _ in 0..5 {
        let elapsed = run(iterations, &text, &schema);
        best = best.min(elapsed as f64 / iterations as f64);
    }
    println!("BENCH mcp/tool-from-operation-large {:.1}", best);
}

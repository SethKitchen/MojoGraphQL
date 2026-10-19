// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

//! The h3 baseline of the `qpack/*` workloads: h3's `encode_stateless` and
//! `decode_stateless`, the QPACK calls that h3's server and client make,
//! on the header fields of a GraphQL request and of its response. The
//! method is that of the Mojo benchmark: a warm-up, then the fastest of 5
//! rounds of at least one second each.

#![allow(
    dead_code,
    unused_imports,
    unused_variables,
    unexpected_cfgs,
    mismatched_lifetime_syntaxes
)]

#[path = "../proto.rs"]
mod proto;
#[path = "../../upstream/h3/src/qpack/mod.rs"]
mod qpack;

use qpack::{decode_stateless, encode_stateless, HeaderField};
use std::hint::black_box;
use std::time::Instant;

const REQUEST: &[(&str, &str)] = &[
    (":method", "POST"),
    (":scheme", "https"),
    (":authority", "api.example.com"),
    (":path", "/graphql"),
    ("content-type", "application/json"),
    ("accept", "application/graphql-response+json, application/json"),
    (
        "user-agent",
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36",
    ),
    ("content-length", "126"),
    ("origin", "https://app.example.com"),
    ("referer", "https://app.example.com/"),
    ("accept-encoding", "gzip, deflate, br"),
    ("accept-language", "en-US,en;q=0.9"),
    ("sec-fetch-mode", "cors"),
    ("sec-fetch-site", "same-site"),
];

const RESPONSE: &[(&str, &str)] = &[
    (":status", "200"),
    ("content-type", "application/graphql-response+json; charset=utf-8"),
    ("content-length", "1534"),
    ("date", "Sun, 18 Oct 2026 12:00:00 GMT"),
    ("cache-control", "no-store"),
    ("vary", "accept-encoding"),
    ("access-control-allow-origin", "https://app.example.com"),
    ("server", "MojoGraphQL"),
];

fn fields(pairs: &[(&str, &str)]) -> Vec<HeaderField> {
    pairs.iter().map(|(n, v)| HeaderField::new(*n, *v)).collect()
}

fn encode_run(fields: &[HeaderField], iterations: u64) -> u128 {
    let mut block: Vec<u8> = Vec::with_capacity(1024);
    let mut sink = 0usize;
    let start = Instant::now();
    for _ in 0..iterations {
        block.clear();
        encode_stateless(&mut block, black_box(fields).iter()).unwrap();
        sink = sink.wrapping_add(block.len());
    }
    black_box(sink);
    start.elapsed().as_nanos()
}

fn decode_run(block: &[u8], iterations: u64) -> u128 {
    let mut sink = 0usize;
    let start = Instant::now();
    for _ in 0..iterations {
        let mut buf = black_box(block);
        let decoded = decode_stateless(&mut buf, u64::MAX).unwrap();
        sink = sink.wrapping_add(decoded.fields.len());
    }
    black_box(sink);
    start.elapsed().as_nanos()
}

fn time(name: &str, run: &dyn Fn(u64) -> u128) {
    let mut iterations = 1u64;
    let mut warm = 0u128;
    loop {
        let elapsed = run(iterations);
        warm += elapsed;
        if elapsed * 4 >= 200_000_000 || warm >= 200_000_000 {
            let per_op = (elapsed / iterations as u128).max(1);
            iterations = (1_000_000_000 / per_op).max(1) as u64;
            break;
        }
        iterations *= 2;
    }
    let mut best = f64::MAX;
    for _ in 0..5 {
        let elapsed = run(iterations);
        best = best.min(elapsed as f64 / iterations as f64);
    }
    println!("BENCH {} {:.1}", name, best);
}

fn main() {
    for (kind, pairs) in [("request", REQUEST), ("response", RESPONSE)] {
        let list = fields(pairs);
        let mut block = Vec::new();
        encode_stateless(&mut block, list.iter()).unwrap();
        time(&format!("qpack/encode-{}", kind), &|n| encode_run(&list, n));
        time(&format!("qpack/decode-{}", kind), &|n| decode_run(&block, n));
    }
}

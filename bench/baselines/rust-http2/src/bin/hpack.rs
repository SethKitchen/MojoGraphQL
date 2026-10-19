// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

//! The h2 baseline of `http2/hpack-encode` and `http2/hpack-decode`: the
//! HPACK encoder and decoder of h2 0.4.20 on the header block of a typical
//! GraphQL request. Each operation is cold, as on the first request of a
//! connection: a new encoder or decoder, Huffman coding and table
//! insertions. The method is that of the Mojo benchmark: a warm-up, then
//! the fastest of 5 rounds of about one second each.

#![allow(dead_code, unused_imports, unused_variables, unexpected_cfgs)]

include!(concat!(env!("OUT_DIR"), "/h2_src.rs"));

/// The part of h2's `frame` module that `hpack::decoder` names.
mod frame {
    #[derive(Debug)]
    pub enum Error {
        Hpack(crate::hpack::DecoderError),
    }
}

use bytes::BytesMut;
use hpack::{BytesStr, Decoder, Encoder, Header};
use http::header::{HeaderName, HeaderValue};
use http::Method;
use std::hint::black_box;
use std::io::Cursor;
use std::ops::ControlFlow;
use std::time::Instant;

/// The regular fields of the block, after `:method POST`, `:scheme http`,
/// `:authority localhost:4000` and `:path /graphql`. The Mojo benchmark
/// `bench/gql_http2/hpack.mojo` encodes the same list.
const FIELDS: [(&str, &str); 10] = [
    ("content-type", "application/json"),
    ("accept", "application/graphql-response+json, application/json"),
    (
        "user-agent",
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36",
    ),
    ("accept-encoding", "gzip, deflate, br"),
    ("accept-language", "en-US,en;q=0.9"),
    ("origin", "http://localhost:3000"),
    ("referer", "http://localhost:3000/"),
    ("apollo-require-preflight", "true"),
    ("x-request-id", "3f2b9c1e-8d4a-4b6f-9e2d-1a7c5b8e0f34"),
    ("content-length", "64"),
];

fn headers() -> Vec<Header<Option<HeaderName>>> {
    let mut out = vec![
        Header::Method(Method::POST),
        Header::Scheme(BytesStr::from_static("http")),
        Header::Authority(BytesStr::from_static("localhost:4000")),
        Header::Path(BytesStr::from_static("/graphql")),
    ];
    for (name, value) in FIELDS {
        out.push(Header::Field {
            name: Some(HeaderName::from_static(name)),
            value: HeaderValue::from_static(value),
        });
    }
    out
}

fn encode_once(list: &[Header<Option<HeaderName>>], dst: &mut BytesMut) -> usize {
    let mut encoder = Encoder::default();
    dst.clear();
    encoder.encode(list.iter().cloned(), dst);
    dst.len()
}

fn decode_once(block: &[u8], buffer: &mut BytesMut) -> usize {
    let mut decoder = Decoder::new(4096);
    buffer.clear();
    buffer.extend_from_slice(block);
    let mut count = 0usize;
    decoder
        .decode(&mut Cursor::new(buffer), |header| {
            count += header.len();
            black_box(&header);
            ControlFlow::Continue(())
        })
        .unwrap();
    count
}

fn time<F: FnMut() -> usize>(name: &str, mut once: F) {
    let mut run = |iterations: u64| -> u128 {
        let start = Instant::now();
        let mut sink = 0usize;
        for _ in 0..iterations {
            sink = sink.wrapping_add(once());
        }
        black_box(sink);
        start.elapsed().as_nanos()
    };
    let mut iterations = 1u64;
    loop {
        let elapsed = run(iterations);
        if elapsed >= 50_000_000 {
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
    let list = headers();
    let mut dst = BytesMut::with_capacity(4096);
    encode_once(&list, &mut dst);
    let block = dst.to_vec();
    time("http2/hpack-encode", || encode_once(black_box(&list), &mut dst));
    let mut buffer = BytesMut::with_capacity(4096);
    time("http2/hpack-decode", || decode_once(black_box(&block), &mut buffer));
}

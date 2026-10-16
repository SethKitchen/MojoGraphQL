// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

//! The httparse baseline of `http/parse-request`: parse the head of a
//! typical GraphQL POST from a browser, with 64 header slots on the stack.
//! The method is that of the Mojo benchmark: a warm-up, then the fastest
//! of 5 rounds of at least one second each.

use std::hint::black_box;
use std::time::Instant;

const REQUEST: &[u8] = b"POST /graphql HTTP/1.1\r\n\
Host: localhost:4000\r\n\
Connection: keep-alive\r\n\
Content-Length: 126\r\n\
sec-ch-ua: \"Chromium\";v=\"128\", \"Not;A=Brand\";v=\"24\"\r\n\
accept: application/graphql-response+json, application/json\r\n\
content-type: application/json\r\n\
User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36\r\n\
Origin: http://localhost:4000\r\n\
Sec-Fetch-Site: same-origin\r\n\
Sec-Fetch-Mode: cors\r\n\
Referer: http://localhost:4000/\r\n\
Accept-Encoding: gzip, deflate, br\r\n\
Accept-Language: en-US,en;q=0.9\r\n\
\r\n\
{\"query\":\"query Hero($episode: Episode) { hero(episode: $episode) { name friends { name } } }\",\"variables\":{\"episode\":\"JEDI\"}}";

fn once(data: &[u8]) -> usize {
    let mut headers = [httparse::EMPTY_HEADER; 64];
    let mut request = httparse::Request::new(&mut headers);
    match request.parse(data) {
        Ok(httparse::Status::Complete(size)) => size + request.headers.len(),
        _ => panic!("the request did not parse"),
    }
}

fn run(iterations: u64) -> u128 {
    let start = Instant::now();
    let mut sink = 0usize;
    for _ in 0..iterations {
        sink = sink.wrapping_add(once(black_box(REQUEST)));
    }
    black_box(sink);
    start.elapsed().as_nanos()
}

fn main() {
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
    println!("BENCH http/parse-request {:.1}", best);
}

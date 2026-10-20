// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

//! The tungstenite baselines of `ws/frame-parse` and `ws/frame-write`.
//!
//! `ws/frame-parse`: a server `WebSocket` reads one masked text frame of
//! 1 KiB from a client, unmasks it, checks its UTF-8, and returns the
//! message. `ws/frame-write`: a server `WebSocket` writes one text message
//! of 1 KiB, and the output is taken. The bytes and the method are those
//! of `bench/gql_ws/frames.mojo`: a warm-up, then the fastest of 5 rounds
//! of at least one second each.

use std::hint::black_box;
use std::io::{self, Read, Write};
use std::time::Instant;

use tungstenite::protocol::{Role, WebSocket};
use tungstenite::Message;

const SIZE: usize = 1024;

fn payload() -> String {
    let mut text = String::from(r#"{"id":"1","type":"next","payload":{"data":{"greetings":""#);
    while text.len() < SIZE - 4 {
        text.push_str("hello ");
    }
    text.truncate(SIZE - 4);
    text.push_str(r#""}}}"#);
    text
}

fn masked_frame(text: &str) -> Vec<u8> {
    let mask = 0x9ABCDEF0u32.to_le_bytes();
    let mut out = vec![0x81u8, 0x80 | 126, (text.len() >> 8) as u8, text.len() as u8];
    out.extend_from_slice(&mask);
    for (i, byte) in text.bytes().enumerate() {
        out.push(byte ^ mask[i & 3]);
    }
    out
}

/// A stream that gives the same frame to each read, and drops writes.
struct Replay {
    frame: Vec<u8>,
    at: usize,
    written: usize,
}

impl Read for Replay {
    fn read(&mut self, buf: &mut [u8]) -> io::Result<usize> {
        if self.at == self.frame.len() {
            self.at = 0;
        }
        let n = buf.len().min(self.frame.len() - self.at);
        buf[..n].copy_from_slice(&self.frame[self.at..self.at + n]);
        self.at += n;
        Ok(n)
    }
}

impl Write for Replay {
    fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
        self.written += buf.len();
        Ok(buf.len())
    }
    fn flush(&mut self) -> io::Result<()> {
        Ok(())
    }
}

fn time(mut op: impl FnMut(u64) -> u128) -> f64 {
    let mut iterations = 1u64;
    loop {
        let elapsed = op(iterations);
        if elapsed >= 125_000_000 {
            let per_op = (elapsed / iterations as u128).max(1);
            iterations = (1_000_000_000 / per_op).max(1) as u64;
            break;
        }
        iterations *= 2;
    }
    let mut best = f64::MAX;
    for _ in 0..5 {
        let elapsed = op(iterations);
        best = best.min(elapsed as f64 / iterations as f64);
    }
    (best * 10.0).trunc() / 10.0
}

fn main() {
    let text = payload();
    let frame = masked_frame(&text);
    let stream = Replay { frame, at: 0, written: 0 };
    let mut server = WebSocket::from_raw_socket(stream, Role::Server, None);
    let parse = time(|iterations| {
        let start = Instant::now();
        let mut sink = 0usize;
        for _ in 0..iterations {
            match server.read() {
                Ok(Message::Text(t)) => sink += t.len(),
                other => panic!("unexpected {:?}", other.map(|_| ())),
            }
        }
        black_box(sink);
        start.elapsed().as_nanos()
    });
    println!("BENCH ws/frame-parse {}", parse);
    let sink = Replay { frame: Vec::new(), at: 0, written: 0 };
    let mut writer = WebSocket::from_raw_socket(sink, Role::Server, None);
    let write = time(|iterations| {
        let start = Instant::now();
        for _ in 0..iterations {
            writer.send(Message::text(text.as_str())).unwrap();
        }
        black_box(writer.get_ref().written);
        start.elapsed().as_nanos()
    });
    println!("BENCH ws/frame-write {}", write);
}

// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

//! The hyper baseline of `http/keepalive-small-json` and
//! `http/chunked-16-parts`.
//!
//! A hyper 1 HTTP/1.1 server on a tokio runtime with one thread. It reads
//! each request body and answers `{"data":{"hello":"world"}}`. On the path
//! `/stream`, the body is `Chunks`: 16 frames of that JSON with no length,
//! so hyper sends them as chunks. It prints `PORT <n>` and serves until it
//! is killed. `bench/gql_http/_loadgen.mojo` drives it.

use std::convert::Infallible;
use std::io::Write;
use std::pin::Pin;
use std::task::{Context, Poll};

use bytes::Bytes;
use http_body_util::{BodyExt, Either, Full};
use hyper::body::{Body, Frame, Incoming};
use hyper::server::conn::http1;
use hyper::service::service_fn;
use hyper::{Request, Response};
use hyper_util::rt::TokioIo;
use tokio::net::TcpListener;

const BODY: &[u8] = br#"{"data":{"hello":"world"}}"#;
const CHUNKS: usize = 16;

/// A streamed body: `left` more frames of `BODY`, one per poll.
struct Chunks {
    left: usize,
}

impl Body for Chunks {
    type Data = Bytes;
    type Error = Infallible;

    fn poll_frame(
        mut self: Pin<&mut Self>,
        _: &mut Context<'_>,
    ) -> Poll<Option<Result<Frame<Bytes>, Infallible>>> {
        if self.left == 0 {
            return Poll::Ready(None);
        }
        self.left -= 1;
        Poll::Ready(Some(Ok(Frame::data(Bytes::from_static(BODY)))))
    }
}

type Reply = Either<Full<Bytes>, Chunks>;

async fn hello(request: Request<Incoming>) -> Result<Response<Reply>, Infallible> {
    let stream = request.uri().path() == "/stream";
    // Read the whole request body, as a GraphQL server must.
    let body = request.into_body().collect().await.map(|b| b.to_bytes());
    std::hint::black_box(&body);
    let content = if stream {
        Either::Right(Chunks { left: CHUNKS })
    } else {
        Either::Left(Full::new(Bytes::from_static(BODY)))
    };
    let response = Response::builder()
        .header("Content-Type", "application/json")
        .body(content)
        .unwrap();
    Ok(response)
}

fn main() {
    let runtime = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .unwrap();
    runtime.block_on(async {
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let port = listener.local_addr().unwrap().port();
        println!("PORT {}", port);
        std::io::stdout().flush().unwrap();
        loop {
            let (stream, _) = listener.accept().await.unwrap();
            stream.set_nodelay(true).unwrap();
            tokio::task::spawn(async move {
                let _ = http1::Builder::new()
                    .serve_connection(TokioIo::new(stream), service_fn(hello))
                    .await;
            });
        }
    });
}

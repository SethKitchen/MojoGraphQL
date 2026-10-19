// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

//! The hyper baseline of `http2/roundtrip-small-json`: hyper 1 with h2,
//! HTTP/2 only with h2c prior knowledge, on a tokio runtime with one thread.
//! It reads each request body whole, as a GraphQL server must, and answers
//! `{"data":{"hello":"world"}}`. It prints `PORT <n>` for the Mojo load
//! generator `bench/gql_http2/_h2load.mojo`.

use std::convert::Infallible;
use std::io::Write;

use bytes::Bytes;
use http_body_util::{BodyExt, Full};
use hyper::body::Incoming;
use hyper::server::conn::http2;
use hyper::service::service_fn;
use hyper::{Request, Response};
use hyper_util::rt::{TokioExecutor, TokioIo};
use tokio::net::TcpListener;

const BODY: &[u8] = br#"{"data":{"hello":"world"}}"#;

async fn hello(request: Request<Incoming>) -> Result<Response<Full<Bytes>>, Infallible> {
    let body = request.into_body().collect().await.map(|b| b.to_bytes());
    std::hint::black_box(&body);
    let response = Response::builder()
        .header("Content-Type", "application/json")
        .body(Full::new(Bytes::from_static(BODY)))
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
                let _ = http2::Builder::new(TokioExecutor::new())
                    .serve_connection(TokioIo::new(stream), service_fn(hello))
                    .await;
            });
        }
    });
}

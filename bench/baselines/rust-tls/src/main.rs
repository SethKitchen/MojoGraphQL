// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

//! `tls/keepalive-roundtrip` with hyper 1 and rustls on both ends.
//!
//! A server thread with its own tokio runtime answers each small GraphQL
//! POST to `/graphql` with `{"data":{"hello":"world"}}`. The client on the
//! main thread, with its own runtime, sends the requests one after the
//! other on one TLS 1.3 connection, which it verifies against the
//! certificate in `bench/fixtures/tls/`. The handshake is outside the timer.
//! The number is nanoseconds per round trip: the best of `ROUNDS` rounds of
//! `REQUESTS` requests, as in `bench/gql_tls/tls.mojo`.

use std::convert::Infallible;
use std::sync::Arc;
use std::time::Instant;

use bytes::Bytes;
use http_body_util::{BodyExt, Full};
use hyper::body::Incoming;
use hyper::service::service_fn;
use hyper::{Request, Response};
use hyper_util::rt::TokioIo;
use rustls::pki_types::pem::PemObject;
use rustls::pki_types::{CertificateDer, PrivateKeyDer, ServerName};
use tokio::net::{TcpListener, TcpStream};
use tokio_rustls::{TlsAcceptor, TlsConnector};

const CERT: &[u8] = include_bytes!("../../../fixtures/tls/cert.pem");
const KEY: &[u8] = include_bytes!("../../../fixtures/tls/key.pem");
const QUERY: &[u8] = br#"{"query":"{ hello }"}"#;
const ANSWER: &[u8] = br#"{"data":{"hello":"world"}}"#;
const WARMUP: usize = 2000;
const REQUESTS: usize = 20000;
const ROUNDS: usize = 5;

fn certs() -> Vec<CertificateDer<'static>> {
    CertificateDer::pem_slice_iter(CERT)
        .map(|c| c.expect("certificate"))
        .collect()
}

async fn hello(_: Request<Incoming>) -> Result<Response<Full<Bytes>>, Infallible> {
    let mut response = Response::new(Full::new(Bytes::from_static(ANSWER)));
    response.headers_mut().insert(
        hyper::header::CONTENT_TYPE,
        hyper::header::HeaderValue::from_static("application/json"),
    );
    Ok(response)
}

async fn serve(listener: std::net::TcpListener) {
    let key = PrivateKeyDer::from_pem_slice(KEY).expect("key");
    let mut config = rustls::ServerConfig::builder()
        .with_no_client_auth()
        .with_single_cert(certs(), key)
        .expect("server config");
    config.alpn_protocols = vec![b"http/1.1".to_vec()];
    let acceptor = TlsAcceptor::from(Arc::new(config));
    let listener = TcpListener::from_std(listener).expect("listener");
    loop {
        let (tcp, _) = listener.accept().await.expect("accept");
        tcp.set_nodelay(true).expect("nodelay");
        let acceptor = acceptor.clone();
        tokio::spawn(async move {
            if let Ok(tls) = acceptor.accept(tcp).await {
                let _ = hyper::server::conn::http1::Builder::new()
                    .serve_connection(TokioIo::new(tls), service_fn(hello))
                    .await;
            }
        });
    }
}

async fn round_trips(
    sender: &mut hyper::client::conn::http1::SendRequest<Full<Bytes>>,
    count: usize,
) {
    for _ in 0..count {
        sender.ready().await.expect("ready");
        let request = Request::post("/graphql")
            .header(hyper::header::HOST, "localhost")
            .header(hyper::header::CONTENT_TYPE, "application/json")
            .body(Full::new(Bytes::from_static(QUERY)))
            .expect("request");
        let response = sender.send_request(request).await.expect("response");
        let body = response.into_body().collect().await.expect("body");
        assert_eq!(body.to_bytes().as_ref(), ANSWER);
    }
}

async fn measure(port: u16) -> f64 {
    let mut roots = rustls::RootCertStore::empty();
    for cert in certs() {
        roots.add(cert).expect("root");
    }
    let mut config = rustls::ClientConfig::builder()
        .with_root_certificates(roots)
        .with_no_client_auth();
    config.alpn_protocols = vec![b"http/1.1".to_vec()];
    let connector = TlsConnector::from(Arc::new(config));
    let tcp = TcpStream::connect(("127.0.0.1", port)).await.expect("connect");
    tcp.set_nodelay(true).expect("nodelay");
    let name = ServerName::try_from("localhost").expect("name");
    let tls = connector.connect(name, tcp).await.expect("handshake");
    let (mut sender, connection) = hyper::client::conn::http1::handshake(TokioIo::new(tls))
        .await
        .expect("http handshake");
    tokio::spawn(connection);
    round_trips(&mut sender, WARMUP).await;
    let mut best = f64::MAX;
    for _ in 0..ROUNDS {
        let start = Instant::now();
        round_trips(&mut sender, REQUESTS).await;
        let took = start.elapsed().as_nanos() as f64 / REQUESTS as f64;
        best = best.min(took);
    }
    best
}

fn runtime() -> tokio::runtime::Runtime {
    tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .expect("runtime")
}

fn main() {
    let listener = std::net::TcpListener::bind("127.0.0.1:0").expect("bind");
    listener.set_nonblocking(true).expect("nonblocking");
    let port = listener.local_addr().expect("address").port();
    std::thread::spawn(move || runtime().block_on(serve(listener)));
    let best = runtime().block_on(measure(port));
    println!("BENCH tls/keepalive-roundtrip {:.1}", best);
}

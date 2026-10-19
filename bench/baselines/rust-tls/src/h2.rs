// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

//! `https2/roundtrip-small-json` with hyper 1, h2 and rustls on both ends.
//!
//! A server thread with its own tokio runtime answers each small GraphQL
//! POST to `/graphql` with `{"data":{"hello":"world"}}` over HTTP/2. The
//! client on the main thread, with its own runtime, sends the requests one
//! after the other, one stream at a time, on one TLS 1.3 connection with
//! ALPN `h2`, which it verifies against the certificate in
//! `bench/fixtures/tls/`. The handshake is outside the timer. The number is
//! nanoseconds per round trip: the best of `ROUNDS` rounds of `REQUESTS`
//! requests, as in `bench/gql_https2/roundtrip.mojo`.

use std::convert::Infallible;
use std::sync::Arc;
use std::time::Instant;

use bytes::Bytes;
use http_body_util::{BodyExt, Full};
use hyper::body::Incoming;
use hyper::service::service_fn;
use hyper::{Request, Response};
use hyper_util::rt::{TokioExecutor, TokioIo};
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

async fn hello(request: Request<Incoming>) -> Result<Response<Full<Bytes>>, Infallible> {
    // Read the whole request, as the Mojo server does. An unread body
    // makes h2 reset the stream, and h2 ends a connection after many.
    let _ = request.into_body().collect().await;
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
    config.alpn_protocols = vec![b"h2".to_vec(), b"http/1.1".to_vec()];
    let acceptor = TlsAcceptor::from(Arc::new(config));
    let listener = TcpListener::from_std(listener).expect("listener");
    loop {
        let (tcp, _) = listener.accept().await.expect("accept");
        tcp.set_nodelay(true).expect("nodelay");
        let acceptor = acceptor.clone();
        tokio::spawn(async move {
            if let Ok(tls) = acceptor.accept(tcp).await {
                if let Err(e) = hyper::server::conn::http2::Builder::new(TokioExecutor::new())
                    .serve_connection(TokioIo::new(tls), service_fn(hello))
                    .await
                {
                    eprintln!("server: {e}");
                }
            }
        });
    }
}

async fn round_trips(
    sender: &mut hyper::client::conn::http2::SendRequest<Full<Bytes>>,
    count: usize,
) {
    for _ in 0..count {
        sender.ready().await.expect("ready");
        let request = Request::post("https://localhost/graphql")
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
    config.alpn_protocols = vec![b"h2".to_vec(), b"http/1.1".to_vec()];
    let connector = TlsConnector::from(Arc::new(config));
    let tcp = TcpStream::connect(("127.0.0.1", port)).await.expect("connect");
    tcp.set_nodelay(true).expect("nodelay");
    let name = ServerName::try_from("localhost").expect("name");
    let tls = connector.connect(name, tcp).await.expect("handshake");
    assert_eq!(tls.get_ref().1.alpn_protocol(), Some(&b"h2"[..]));
    let (mut sender, connection) =
        hyper::client::conn::http2::handshake(TokioExecutor::new(), TokioIo::new(tls))
            .await
            .expect("http2 handshake");
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
    println!("BENCH https2/roundtrip-small-json {:.1}", best);
}

// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

//! `h3/roundtrip-small-json` with h3, h3-quinn and quinn: one client sends
//! small GraphQL POSTs one after another on one QUIC connection, after the
//! handshake, and the server answers `{"data":{"hello":"world"}}`.

use std::sync::Arc;
use std::time::Instant;

use bytes::{Buf, Bytes};
use h3_quinn::quinn;
use quinn::crypto::rustls::{QuicClientConfig, QuicServerConfig};
use rustls::pki_types::{CertificateDer, PrivateKeyDer, PrivatePkcs8KeyDer};

const REQUEST_BODY: &[u8] = br#"{"query":"{ hello }"}"#;
const RESPONSE_BODY: &[u8] = br#"{"data":{"hello":"world"}}"#;
const WARMUP: usize = 200;
const REQUESTS: usize = 5000;

async fn serve(endpoint: quinn::Endpoint) {
    while let Some(incoming) = endpoint.accept().await {
        tokio::spawn(async move {
            let conn = match incoming.await {
                Ok(conn) => conn,
                Err(_) => return,
            };
            let mut h3_conn: h3::server::Connection<h3_quinn::Connection, Bytes> =
                match h3::server::Connection::new(h3_quinn::Connection::new(conn)).await {
                    Ok(c) => c,
                    Err(_) => return,
                };
            while let Ok(Some(resolver)) = h3_conn.accept().await {
                tokio::spawn(async move {
                    let (_req, mut stream) = match resolver.resolve_request().await {
                        Ok(r) => r,
                        Err(_) => return,
                    };
                    while let Ok(Some(mut chunk)) = stream.recv_data().await {
                        chunk.advance(chunk.remaining());
                    }
                    let resp = http::Response::builder()
                        .status(http::StatusCode::OK)
                        .header("content-type", "application/json")
                        .body(())
                        .unwrap();
                    if stream.send_response(resp).await.is_err() {
                        return;
                    }
                    let _ = stream.send_data(Bytes::from_static(RESPONSE_BODY)).await;
                    let _ = stream.finish().await;
                });
            }
        });
    }
}

fn main() {
    let _ = rustls::crypto::ring::default_provider().install_default();
    let cert = rcgen::generate_simple_self_signed(vec!["localhost".into()]).unwrap();
    let cert_der = CertificateDer::from(cert.cert.der().to_vec());
    let key = PrivateKeyDer::from(PrivatePkcs8KeyDer::from(cert.key_pair.serialize_der()));

    let mut tls = rustls::ServerConfig::builder()
        .with_no_client_auth()
        .with_single_cert(vec![cert_der.clone()], key)
        .unwrap();
    tls.alpn_protocols = vec![b"h3".to_vec()];
    let server_config =
        quinn::ServerConfig::with_crypto(Arc::new(QuicServerConfig::try_from(tls).unwrap()));

    let (tx, rx) = std::sync::mpsc::channel();
    std::thread::spawn(move || {
        let runtime = tokio::runtime::Builder::new_current_thread().enable_all().build().unwrap();
        runtime.block_on(async move {
            let endpoint =
                quinn::Endpoint::server(server_config, "127.0.0.1:0".parse().unwrap()).unwrap();
            tx.send(endpoint.local_addr().unwrap()).unwrap();
            serve(endpoint).await;
        });
    });
    let addr = rx.recv().unwrap();

    let runtime = tokio::runtime::Builder::new_current_thread().enable_all().build().unwrap();
    runtime.block_on(async move {
        let mut roots = rustls::RootCertStore::empty();
        roots.add(cert_der).unwrap();
        let mut tls = rustls::ClientConfig::builder()
            .with_root_certificates(roots)
            .with_no_client_auth();
        tls.alpn_protocols = vec![b"h3".to_vec()];
        let mut endpoint = quinn::Endpoint::client("127.0.0.1:0".parse().unwrap()).unwrap();
        endpoint.set_default_client_config(quinn::ClientConfig::new(Arc::new(
            QuicClientConfig::try_from(tls).unwrap(),
        )));
        let conn = endpoint.connect(addr, "localhost").unwrap().await.unwrap();
        let (mut driver, mut send_request) =
            h3::client::new(h3_quinn::Connection::new(conn)).await.unwrap();
        tokio::spawn(async move {
            let _ = futures::future::poll_fn(|cx| driver.poll_close(cx)).await;
        });
        let url = format!("https://localhost:{}/graphql", addr.port());
        let mut start = Instant::now();
        for index in 0..WARMUP + REQUESTS {
            if index == WARMUP {
                start = Instant::now();
            }
            let req = http::Request::post(url.as_str())
                .header("content-type", "application/json")
                .body(())
                .unwrap();
            let mut stream = send_request.send_request(req).await.unwrap();
            stream.send_data(Bytes::from_static(REQUEST_BODY)).await.unwrap();
            stream.finish().await.unwrap();
            let resp = stream.recv_response().await.unwrap();
            assert_eq!(resp.status(), http::StatusCode::OK);
            while let Some(mut chunk) = stream.recv_data().await.unwrap() {
                chunk.advance(chunk.remaining());
            }
        }
        let elapsed = start.elapsed().as_nanos() as usize;
        println!("BENCH h3/roundtrip-small-json {}", elapsed / REQUESTS);
    });
}

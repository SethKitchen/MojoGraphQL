// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

//! `quic/echo-roundtrip-32b` with quinn and tokio over localhost UDP: one
//! client opens bidirectional streams one after another on one connection,
//! after the handshake. On each stream it writes 32 bytes and finishes, and
//! the server echoes the bytes back and finishes. The time is per stream.

use std::sync::Arc;
use std::time::Instant;

use quinn::crypto::rustls::{QuicClientConfig, QuicServerConfig};
use rustls::pki_types::{CertificateDer, PrivateKeyDer, PrivatePkcs8KeyDer};

const PAYLOAD: [u8; 32] = [b'x'; 32];
const WARMUP: usize = 200;
const ROUNDS: usize = 5000;

async fn serve(endpoint: quinn::Endpoint) {
    while let Some(incoming) = endpoint.accept().await {
        tokio::spawn(async move {
            let conn = match incoming.await {
                Ok(conn) => conn,
                Err(_) => return,
            };
            while let Ok((mut send, mut recv)) = conn.accept_bi().await {
                tokio::spawn(async move {
                    let data = match recv.read_to_end(64 * 1024).await {
                        Ok(data) => data,
                        Err(_) => return,
                    };
                    if send.write_all(&data).await.is_err() {
                        return;
                    }
                    let _ = send.finish();
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
    tls.alpn_protocols = vec![b"bench".to_vec()];
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
        tls.alpn_protocols = vec![b"bench".to_vec()];
        let mut endpoint = quinn::Endpoint::client("127.0.0.1:0".parse().unwrap()).unwrap();
        endpoint.set_default_client_config(quinn::ClientConfig::new(Arc::new(
            QuicClientConfig::try_from(tls).unwrap(),
        )));
        let conn = endpoint.connect(addr, "localhost").unwrap().await.unwrap();
        let mut start = Instant::now();
        for index in 0..WARMUP + ROUNDS {
            if index == WARMUP {
                start = Instant::now();
            }
            let (mut send, mut recv) = conn.open_bi().await.unwrap();
            send.write_all(&PAYLOAD).await.unwrap();
            send.finish().unwrap();
            let echo = recv.read_to_end(64 * 1024).await.unwrap();
            assert_eq!(echo.as_slice(), &PAYLOAD[..]);
        }
        let elapsed = start.elapsed().as_nanos() as usize;
        println!("BENCH quic/echo-roundtrip-32b {}", elapsed / ROUNDS);
        conn.close(0u32.into(), b"done");
        endpoint.wait_idle().await;
    });
}

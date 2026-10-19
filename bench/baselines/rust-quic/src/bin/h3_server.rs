// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

//! `h3-interop-server`: an HTTP/3 peer for the gql_http3 interop tests, on
//! h3 0.0.8, h3-quinn 0.0.10 and quinn 0.11. It is a test peer, not a
//! measurement.
//!
//! Usage: `h3-interop-server [--port <p>] [--cert <pem> --key <pem>]`
//!
//! `--port 0` (the default) lets the system choose the port. When the
//! server listens, it prints `PORT <n>` on stdout. The certificate file can
//! hold a chain. The key file can hold a PKCS#8, PKCS#1 (RSA) or SEC1 (EC)
//! key. Without `--cert`, the server makes a self-signed certificate for
//! `localhost`. The ALPN is `h3`. The server binds `[::]` (IPv4 and IPv6),
//! or `127.0.0.1` when IPv6 is not available.
//!
//! Every response has status 200 and `content-type: application/json`. The
//! body of a POST response is `{"echo":<request body length>}`. The body of
//! any other response is `{"data":{"hello":"world"}}`. The server serves
//! until it is killed.

use std::io::Write;
use std::net::SocketAddr;
use std::sync::Arc;

use bytes::{Buf, Bytes};
use h3_quinn::quinn;
use quinn::crypto::rustls::QuicServerConfig;
use rustls::pki_types::pem::PemObject;
use rustls::pki_types::{CertificateDer, PrivateKeyDer, PrivatePkcs8KeyDer};

const HELLO_BODY: &[u8] = br#"{"data":{"hello":"world"}}"#;

fn usage(message: &str) -> ! {
    eprintln!("h3-interop-server: {message}");
    eprintln!("usage: h3-interop-server [--port <p>] [--cert <pem> --key <pem>]");
    std::process::exit(2);
}

struct Args {
    port: u16,
    cert: Option<String>,
    key: Option<String>,
}

fn parse_args() -> Args {
    let mut args = Args { port: 0, cert: None, key: None };
    let mut iter = std::env::args().skip(1);
    while let Some(flag) = iter.next() {
        let mut value = || iter.next().unwrap_or_else(|| usage(&format!("{flag} needs a value")));
        match flag.as_str() {
            "--port" => args.port = value().parse().unwrap_or_else(|_| usage("bad --port")),
            "--cert" => args.cert = Some(value()),
            "--key" => args.key = Some(value()),
            _ => usage(&format!("unknown argument {flag}")),
        }
    }
    if args.cert.is_some() != args.key.is_some() {
        usage("--cert and --key go together");
    }
    args
}

fn load_identity(args: &Args) -> (Vec<CertificateDer<'static>>, PrivateKeyDer<'static>) {
    match (&args.cert, &args.key) {
        (Some(cert), Some(key)) => {
            let certs = CertificateDer::pem_file_iter(cert)
                .and_then(|iter| iter.collect::<Result<Vec<_>, _>>())
                .unwrap_or_else(|e| usage(&format!("cannot read {cert}: {e}")));
            if certs.is_empty() {
                usage(&format!("no certificate in {cert}"));
            }
            let key = PrivateKeyDer::from_pem_file(key)
                .unwrap_or_else(|e| usage(&format!("cannot read {key}: {e}")));
            (certs, key)
        }
        _ => {
            let cert = rcgen::generate_simple_self_signed(vec!["localhost".into()]).unwrap();
            let der = CertificateDer::from(cert.cert.der().to_vec());
            let key = PrivateKeyDer::from(PrivatePkcs8KeyDer::from(cert.key_pair.serialize_der()));
            (vec![der], key)
        }
    }
}

async fn handle_connection(conn: quinn::Connection) {
    let mut h3_conn: h3::server::Connection<h3_quinn::Connection, Bytes> =
        match h3::server::Connection::new(h3_quinn::Connection::new(conn)).await {
            Ok(c) => c,
            Err(e) => {
                eprintln!("h3-interop-server: h3 setup failed: {e}");
                return;
            }
        };
    loop {
        match h3_conn.accept().await {
            Ok(Some(resolver)) => {
                tokio::spawn(async move {
                    let (req, mut stream) = match resolver.resolve_request().await {
                        Ok(r) => r,
                        Err(e) => {
                            eprintln!("h3-interop-server: bad request: {e}");
                            return;
                        }
                    };
                    let mut length = 0usize;
                    loop {
                        match stream.recv_data().await {
                            Ok(Some(mut chunk)) => {
                                length += chunk.remaining();
                                chunk.advance(chunk.remaining());
                            }
                            Ok(None) => break,
                            Err(e) => {
                                eprintln!("h3-interop-server: body read failed: {e}");
                                return;
                            }
                        }
                    }
                    let body = if req.method() == http::Method::POST {
                        Bytes::from(format!("{{\"echo\":{length}}}"))
                    } else {
                        Bytes::from_static(HELLO_BODY)
                    };
                    let resp = http::Response::builder()
                        .status(http::StatusCode::OK)
                        .header("content-type", "application/json")
                        .body(())
                        .unwrap();
                    if let Err(e) = stream.send_response(resp).await {
                        eprintln!("h3-interop-server: send_response failed: {e}");
                        return;
                    }
                    if let Err(e) = stream.send_data(body).await {
                        eprintln!("h3-interop-server: send_data failed: {e}");
                        return;
                    }
                    let _ = stream.finish().await;
                });
            }
            Ok(None) => return,
            Err(e) => {
                if !e.is_h3_no_error() {
                    eprintln!("h3-interop-server: connection ended: {e}");
                }
                return;
            }
        }
    }
}

fn main() {
    let args = parse_args();
    let _ = rustls::crypto::ring::default_provider().install_default();
    let (certs, key) = load_identity(&args);
    let mut tls = rustls::ServerConfig::builder()
        .with_no_client_auth()
        .with_single_cert(certs, key)
        .unwrap_or_else(|e| usage(&format!("bad certificate or key: {e}")));
    tls.alpn_protocols = vec![b"h3".to_vec()];
    let server_config =
        quinn::ServerConfig::with_crypto(Arc::new(QuicServerConfig::try_from(tls).unwrap()));

    let runtime = tokio::runtime::Builder::new_current_thread().enable_all().build().unwrap();
    runtime.block_on(async move {
        let dual: SocketAddr = format!("[::]:{}", args.port).parse().unwrap();
        let endpoint = match quinn::Endpoint::server(server_config.clone(), dual) {
            Ok(endpoint) => endpoint,
            Err(_) => {
                let v4: SocketAddr = format!("127.0.0.1:{}", args.port).parse().unwrap();
                quinn::Endpoint::server(server_config, v4)
                    .unwrap_or_else(|e| usage(&format!("cannot bind port {}: {e}", args.port)))
            }
        };
        println!("PORT {}", endpoint.local_addr().unwrap().port());
        std::io::stdout().flush().unwrap();
        while let Some(incoming) = endpoint.accept().await {
            tokio::spawn(async move {
                match incoming.await {
                    Ok(conn) => handle_connection(conn).await,
                    Err(e) => eprintln!("h3-interop-server: handshake failed: {e}"),
                }
            });
        }
    });
}

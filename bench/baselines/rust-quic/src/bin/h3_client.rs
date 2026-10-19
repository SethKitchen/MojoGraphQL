// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

//! `h3-interop-client`: an HTTP/3 client for the gql_http3 interop tests,
//! on h3 0.0.8, h3-quinn 0.0.10 and quinn 0.11. It is a test peer, not a
//! measurement.
//!
//! Usage: `h3-interop-client --url https://<host>:<port>/<path>
//! [--requests <n>] [--post <body>] (--insecure | --ca <pem>)`
//!
//! The client sends `<n>` requests (default 3) one after another on one
//! connection: a POST with `content-type: application/json` and the body
//! when `--post` is given, else a GET. For each response it prints
//! `STATUS <code> BODY <body>` on stdout. `--insecure` accepts any server
//! certificate; `--ca` trusts the certificates in the PEM file, as roots
//! or, when the server shows one of them itself, as pinned. The ALPN is
//! `h3`. The client exits with 0 when it has every response, and with 1 on
//! a connection, protocol or timeout failure. The whole run has a 5 s limit.

use std::io::Write;
use std::net::{SocketAddr, ToSocketAddrs};
use std::sync::Arc;
use std::time::Duration;

use bytes::{Buf, Bytes};
use h3_quinn::quinn;
use quinn::crypto::rustls::QuicClientConfig;
use rustls::client::danger::{HandshakeSignatureValid, ServerCertVerified, ServerCertVerifier};
use rustls::client::WebPkiServerVerifier;
use rustls::crypto::{verify_tls12_signature, verify_tls13_signature, CryptoProvider};
use rustls::pki_types::pem::PemObject;
use rustls::pki_types::{CertificateDer, ServerName, UnixTime};
use rustls::{DigitallySignedStruct, SignatureScheme};

const TIMEOUT: Duration = Duration::from_secs(5);

fn usage(message: &str) -> ! {
    eprintln!("h3-interop-client: {message}");
    eprintln!(
        "usage: h3-interop-client --url https://<host>:<port>/<path> [--requests <n>] \
         [--post <body>] (--insecure | --ca <pem>)"
    );
    std::process::exit(2);
}

struct Args {
    url: http::Uri,
    requests: usize,
    post: Option<String>,
    insecure: bool,
    ca: Option<String>,
}

fn parse_args() -> Args {
    let mut url = None;
    let mut args = Args {
        url: http::Uri::default(),
        requests: 3,
        post: None,
        insecure: false,
        ca: None,
    };
    let mut iter = std::env::args().skip(1);
    while let Some(flag) = iter.next() {
        let mut value = || iter.next().unwrap_or_else(|| usage(&format!("{flag} needs a value")));
        match flag.as_str() {
            "--url" => url = Some(value()),
            "--requests" => {
                args.requests = value().parse().unwrap_or_else(|_| usage("bad --requests"))
            }
            "--post" => args.post = Some(value()),
            "--insecure" => args.insecure = true,
            "--ca" => args.ca = Some(value()),
            _ => usage(&format!("unknown argument {flag}")),
        }
    }
    let url = url.unwrap_or_else(|| usage("--url is required"));
    args.url = url.parse().unwrap_or_else(|_| usage(&format!("bad --url {url}")));
    if args.url.scheme_str() != Some("https") || args.url.host().is_none() {
        usage("--url must be https://<host>[:<port>]/<path>");
    }
    if args.insecure == args.ca.is_some() {
        usage("give one of --insecure and --ca");
    }
    args
}

/// Accepts every certificate, but checks the handshake signatures.
#[derive(Debug)]
struct AcceptAnyCert(Arc<CryptoProvider>);

impl ServerCertVerifier for AcceptAnyCert {
    fn verify_server_cert(
        &self,
        _end_entity: &CertificateDer<'_>,
        _intermediates: &[CertificateDer<'_>],
        _server_name: &ServerName<'_>,
        _ocsp_response: &[u8],
        _now: UnixTime,
    ) -> Result<ServerCertVerified, rustls::Error> {
        Ok(ServerCertVerified::assertion())
    }

    fn verify_tls12_signature(
        &self,
        message: &[u8],
        cert: &CertificateDer<'_>,
        dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, rustls::Error> {
        verify_tls12_signature(message, cert, dss, &self.0.signature_verification_algorithms)
    }

    fn verify_tls13_signature(
        &self,
        message: &[u8],
        cert: &CertificateDer<'_>,
        dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, rustls::Error> {
        verify_tls13_signature(message, cert, dss, &self.0.signature_verification_algorithms)
    }

    fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
        self.0.signature_verification_algorithms.supported_schemes()
    }
}

/// Trusts the `--ca` certificates. A server certificate that is one of them
/// byte for byte is accepted as it is, because `openssl req -x509` marks a
/// self-signed certificate as a CA, and webpki refuses a CA as the end
/// entity. Every other certificate goes through the webpki verifier.
#[derive(Debug)]
struct TrustCa {
    pinned: Vec<CertificateDer<'static>>,
    webpki: Arc<WebPkiServerVerifier>,
    any: AcceptAnyCert,
}

impl ServerCertVerifier for TrustCa {
    fn verify_server_cert(
        &self,
        end_entity: &CertificateDer<'_>,
        intermediates: &[CertificateDer<'_>],
        server_name: &ServerName<'_>,
        ocsp_response: &[u8],
        now: UnixTime,
    ) -> Result<ServerCertVerified, rustls::Error> {
        if self.pinned.iter().any(|c| c.as_ref() == end_entity.as_ref()) {
            return Ok(ServerCertVerified::assertion());
        }
        self.webpki.verify_server_cert(end_entity, intermediates, server_name, ocsp_response, now)
    }

    fn verify_tls12_signature(
        &self,
        message: &[u8],
        cert: &CertificateDer<'_>,
        dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, rustls::Error> {
        self.any.verify_tls12_signature(message, cert, dss)
    }

    fn verify_tls13_signature(
        &self,
        message: &[u8],
        cert: &CertificateDer<'_>,
        dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, rustls::Error> {
        self.any.verify_tls13_signature(message, cert, dss)
    }

    fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
        self.any.supported_verify_schemes()
    }
}

fn tls_config(args: &Args) -> rustls::ClientConfig {
    let provider = Arc::new(rustls::crypto::ring::default_provider());
    let builder = rustls::ClientConfig::builder_with_provider(provider.clone())
        .with_protocol_versions(&[&rustls::version::TLS13])
        .unwrap();
    let mut tls = match &args.ca {
        Some(ca) => {
            let mut roots = rustls::RootCertStore::empty();
            let certs = CertificateDer::pem_file_iter(ca)
                .and_then(|iter| iter.collect::<Result<Vec<_>, _>>())
                .unwrap_or_else(|e| usage(&format!("cannot read {ca}: {e}")));
            for cert in &certs {
                roots
                    .add(cert.clone())
                    .unwrap_or_else(|e| usage(&format!("bad CA in {ca}: {e}")));
            }
            let webpki =
                WebPkiServerVerifier::builder_with_provider(Arc::new(roots), provider.clone())
                    .build()
                    .unwrap_or_else(|e| usage(&format!("bad CA in {ca}: {e}")));
            let verifier = TrustCa { pinned: certs, webpki, any: AcceptAnyCert(provider) };
            builder
                .dangerous()
                .with_custom_certificate_verifier(Arc::new(verifier))
                .with_no_client_auth()
        }
        None => builder
            .dangerous()
            .with_custom_certificate_verifier(Arc::new(AcceptAnyCert(provider)))
            .with_no_client_auth(),
    };
    tls.alpn_protocols = vec![b"h3".to_vec()];
    tls
}

/// Returns the address to connect to, IPv4 first, as `localhost` can name
/// both and a test server can bind only `127.0.0.1`.
fn resolve(host: &str, port: u16) -> Result<SocketAddr, String> {
    let host = host.trim_start_matches('[').trim_end_matches(']');
    let addrs: Vec<SocketAddr> = (host, port)
        .to_socket_addrs()
        .map_err(|e| format!("cannot resolve {host}: {e}"))?
        .collect();
    addrs
        .iter()
        .find(|a| a.is_ipv4())
        .or(addrs.first())
        .copied()
        .ok_or_else(|| format!("no address for {host}"))
}

async fn run(args: Args) -> Result<(), String> {
    let host = args.url.host().unwrap().to_string();
    let port = args.url.port_u16().unwrap_or(443);
    let addr = resolve(&host, port)?;
    let bind: SocketAddr =
        if addr.is_ipv4() { "0.0.0.0:0".parse().unwrap() } else { "[::]:0".parse().unwrap() };
    let mut endpoint = quinn::Endpoint::client(bind).map_err(|e| format!("bind failed: {e}"))?;
    let crypto = QuicClientConfig::try_from(tls_config(&args)).map_err(|e| e.to_string())?;
    endpoint.set_default_client_config(quinn::ClientConfig::new(Arc::new(crypto)));

    let server_name = host.trim_start_matches('[').trim_end_matches(']');
    let conn = endpoint
        .connect(addr, server_name)
        .map_err(|e| format!("connect failed: {e}"))?
        .await
        .map_err(|e| format!("handshake failed: {e}"))?;
    let (mut driver, mut send_request) = h3::client::new(h3_quinn::Connection::new(conn.clone()))
        .await
        .map_err(|e| format!("h3 setup failed: {e}"))?;
    let drive = tokio::spawn(async move {
        let _ = futures::future::poll_fn(|cx| driver.poll_close(cx)).await;
    });

    for _ in 0..args.requests {
        let builder = match args.post {
            Some(_) => http::Request::post(args.url.clone()).header("content-type", "application/json"),
            None => http::Request::get(args.url.clone()),
        };
        let req = builder.body(()).unwrap();
        let mut stream =
            send_request.send_request(req).await.map_err(|e| format!("send_request: {e}"))?;
        if let Some(body) = &args.post {
            stream
                .send_data(Bytes::from(body.clone()))
                .await
                .map_err(|e| format!("send_data: {e}"))?;
        }
        stream.finish().await.map_err(|e| format!("finish: {e}"))?;
        let resp = stream.recv_response().await.map_err(|e| format!("recv_response: {e}"))?;
        let mut body = Vec::new();
        while let Some(mut chunk) =
            stream.recv_data().await.map_err(|e| format!("recv_data: {e}"))?
        {
            while chunk.has_remaining() {
                let part = chunk.chunk();
                body.extend_from_slice(part);
                let n = part.len();
                chunk.advance(n);
            }
        }
        println!("STATUS {} BODY {}", resp.status().as_u16(), String::from_utf8_lossy(&body));
        std::io::stdout().flush().unwrap();
    }

    drop(send_request);
    // H3_NO_ERROR (RFC 9114, section 8.1).
    conn.close(0x100u32.into(), b"");
    drive.abort();
    endpoint.wait_idle().await;
    Ok(())
}

fn main() {
    let args = parse_args();
    let _ = rustls::crypto::ring::default_provider().install_default();
    let runtime = tokio::runtime::Builder::new_current_thread().enable_all().build().unwrap();
    let result = runtime.block_on(async move {
        match tokio::time::timeout(TIMEOUT, run(args)).await {
            Ok(result) => result,
            Err(_) => Err(format!("timed out after {} s", TIMEOUT.as_secs())),
        }
    });
    match result {
        Ok(()) => std::process::exit(0),
        Err(message) => {
            eprintln!("h3-interop-client: {message}");
            std::process::exit(1);
        }
    }
}

// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

//! The in-memory QUIC baselines on the public quinn-proto 0.11.19 API. Two
//! `Endpoint`s, one client and one server, exchange datagrams through
//! queues, with no sockets, as `Pair` does in quinn-proto/src/tests/util.rs.
//! Time is the real clock: a connection timer that is due runs before the
//! connection sends.
//!
//! `quic/inmemory-stream-32b`: the client opens a bidirectional stream,
//! writes 32 bytes and finishes. The server accepts the stream, reads it to
//! the end, writes 32 bytes back and finishes. The client reads the reply
//! to the end. The time is per stream.
//!
//! `quic/inmemory-packet-1k`: the client writes 1000 bytes on one
//! long-lived stream, the client connection builds one packet, the server
//! endpoint handles it and the server reads the bytes. The acknowledgments
//! and flow-control updates go back to the client in the same loop. The
//! time is per packet.

use std::collections::VecDeque;
use std::net::{Ipv4Addr, SocketAddr};
use std::sync::Arc;
use std::time::Instant;

use bytes::BytesMut;
use quinn_proto::crypto::rustls::{QuicClientConfig, QuicServerConfig};
use quinn_proto::{
    ClientConfig, Connection, ConnectionHandle, DatagramEvent, Dir, Endpoint, EndpointConfig,
    Event, ReadError, ServerConfig, StreamId, Transmit,
};
use rustls::pki_types::{CertificateDer, PrivateKeyDer, PrivatePkcs8KeyDer};

const STREAM_WARMUP: usize = 1000;
const STREAMS: usize = 100000;
const PACKET_WARMUP: usize = 2000;
const PACKETS: usize = 300000;
const MAX_DATAGRAMS: usize = 10;

/// One side of the in-memory link: an endpoint, its one connection, and the
/// datagrams that wait for it.
struct Side {
    endpoint: Endpoint,
    addr: SocketAddr,
    conn: Option<(ConnectionHandle, Connection)>,
    inbound: VecDeque<BytesMut>,
    buf: Vec<u8>,
    sent: usize,
}

/// Queues the datagrams of one transmit, split at its segment size.
fn queue(transmit: &Transmit, buf: &[u8], out: &mut VecDeque<BytesMut>) {
    let data = &buf[..transmit.size];
    match transmit.segment_size {
        Some(size) => {
            for segment in data.chunks(size) {
                out.push_back(BytesMut::from(segment));
            }
        }
        None => out.push_back(BytesMut::from(data)),
    }
}

impl Side {
    fn new(endpoint: Endpoint, port: u16) -> Self {
        Self {
            endpoint,
            addr: SocketAddr::new(Ipv4Addr::LOCALHOST.into(), port),
            conn: None,
            inbound: VecDeque::new(),
            buf: Vec::with_capacity(1500),
            sent: 0,
        }
    }

    fn conn(&mut self) -> &mut Connection {
        &mut self.conn.as_mut().expect("no connection").1
    }

    /// Gives the waiting datagrams to the endpoint. Returns whether there
    /// were any.
    fn receive(&mut self, now: Instant, remote: SocketAddr, out: &mut VecDeque<BytesMut>) -> bool {
        let mut any = false;
        while let Some(data) = self.inbound.pop_front() {
            any = true;
            match self.endpoint.handle(now, remote, None, None, data, &mut self.buf) {
                Some(DatagramEvent::ConnectionEvent(_, event)) => {
                    self.conn.as_mut().expect("no connection").1.handle_event(event);
                }
                Some(DatagramEvent::NewConnection(incoming)) => {
                    let mut buf = Vec::new();
                    match self.endpoint.accept(incoming, now, &mut buf, None) {
                        Ok(pair) => self.conn = Some(pair),
                        Err(error) => panic!("accept failed: {:?}", error.cause),
                    }
                }
                Some(DatagramEvent::Response(transmit)) => {
                    queue(&transmit, &self.buf, out);
                }
                None => {}
            }
            self.buf.clear();
        }
        any
    }

    /// Runs a due timer, hands the endpoint events over, and queues every
    /// datagram that the connection wants to send. Returns whether there
    /// were any.
    fn transmit(&mut self, now: Instant, out: &mut VecDeque<BytesMut>) -> bool {
        let Some((ch, conn)) = self.conn.as_mut() else {
            return false;
        };
        if conn.poll_timeout().is_some_and(|t| t <= now) {
            conn.handle_timeout(now);
        }
        while let Some(event) = conn.poll_endpoint_events() {
            if let Some(event) = self.endpoint.handle_event(*ch, event) {
                conn.handle_event(event);
            }
        }
        let mut any = false;
        while let Some(transmit) = conn.poll_transmit(now, MAX_DATAGRAMS, &mut self.buf) {
            queue(&transmit, &self.buf, out);
            self.buf.clear();
            self.sent += 1;
            any = true;
        }
        any
    }

    /// Drops the application events; the benchmarks poll the streams.
    fn drain_events(&mut self) {
        let conn = self.conn();
        while let Some(event) = conn.poll() {
            if let Event::ConnectionLost { reason } = event {
                panic!("connection lost: {reason}");
            }
        }
    }
}

struct Pair {
    client: Side,
    server: Side,
}

impl Pair {
    /// Moves datagrams both ways until neither side has one to send.
    fn drive(&mut self) {
        loop {
            let now = Instant::now();
            let mut busy = self.client.transmit(now, &mut self.server.inbound);
            busy |= self.server.receive(now, self.client.addr, &mut self.client.inbound);
            busy |= self.server.transmit(now, &mut self.client.inbound);
            busy |= self.client.receive(now, self.server.addr, &mut self.server.inbound);
            if !busy {
                break;
            }
        }
    }
}

/// Reads what the stream has. Returns the byte count and whether the
/// stream is at its end.
fn read_all(conn: &mut Connection, id: StreamId) -> (usize, bool) {
    let mut recv = conn.recv_stream(id);
    let mut chunks = recv.read(true).expect("stream not readable");
    let mut count = 0;
    let mut fin = false;
    loop {
        match chunks.next(usize::MAX) {
            Ok(Some(chunk)) => count += chunk.bytes.len(),
            Ok(None) => {
                fin = true;
                break;
            }
            Err(ReadError::Blocked) => break,
            Err(error) => panic!("read failed: {error}"),
        }
    }
    let _ = chunks.finalize();
    (count, fin)
}

fn connect() -> Pair {
    let _ = rustls::crypto::ring::default_provider().install_default();
    let cert = rcgen::generate_simple_self_signed(vec!["localhost".into()]).unwrap();
    let cert_der = CertificateDer::from(cert.cert.der().to_vec());
    let key = PrivateKeyDer::from(PrivatePkcs8KeyDer::from(cert.key_pair.serialize_der()));

    let mut server_tls = rustls::ServerConfig::builder()
        .with_no_client_auth()
        .with_single_cert(vec![cert_der.clone()], key)
        .unwrap();
    server_tls.alpn_protocols = vec![b"bench".to_vec()];
    let server_config =
        ServerConfig::with_crypto(Arc::new(QuicServerConfig::try_from(server_tls).unwrap()));

    let mut roots = rustls::RootCertStore::empty();
    roots.add(cert_der).unwrap();
    let mut client_tls = rustls::ClientConfig::builder()
        .with_root_certificates(roots)
        .with_no_client_auth();
    client_tls.alpn_protocols = vec![b"bench".to_vec()];
    let client_config =
        ClientConfig::new(Arc::new(QuicClientConfig::try_from(client_tls).unwrap()));

    let endpoint_config = Arc::new(EndpointConfig::default());
    let server = Endpoint::new(endpoint_config.clone(), Some(Arc::new(server_config)), true, None);
    let client = Endpoint::new(endpoint_config, None, true, None);
    let mut pair = Pair { client: Side::new(client, 4001), server: Side::new(server, 4433) };

    let server_addr = pair.server.addr;
    pair.client.conn = Some(
        pair.client
            .endpoint
            .connect(Instant::now(), client_config, server_addr, "localhost")
            .unwrap(),
    );
    pair.drive();
    assert!(pair.server.conn.is_some(), "the server did not accept");
    assert!(!pair.client.conn().is_handshaking(), "the client is still handshaking");
    assert!(!pair.server.conn().is_handshaking(), "the server is still handshaking");
    pair.client.drain_events();
    pair.server.drain_events();
    pair
}

/// One request and one reply on a new stream.
fn stream_round(pair: &mut Pair, payload: &[u8]) {
    let id = pair.client.conn().streams().open(Dir::Bi).expect("no stream credit");
    let mut send = pair.client.conn().send_stream(id);
    assert_eq!(send.write(payload).unwrap(), payload.len());
    send.finish().unwrap();
    pair.drive();

    let server = pair.server.conn();
    let sid = server.streams().accept(Dir::Bi).expect("no stream to accept");
    assert_eq!(read_all(server, sid), (payload.len(), true));
    let mut send = server.send_stream(sid);
    assert_eq!(send.write(payload).unwrap(), payload.len());
    send.finish().unwrap();
    pair.drive();

    assert_eq!(read_all(pair.client.conn(), id), (payload.len(), true));
    pair.client.drain_events();
    pair.server.drain_events();
}

fn bench_streams() {
    let mut pair = connect();
    let payload = [b'x'; 32];
    let mut start = Instant::now();
    for index in 0..STREAM_WARMUP + STREAMS {
        if index == STREAM_WARMUP {
            start = Instant::now();
        }
        stream_round(&mut pair, &payload);
    }
    let elapsed = start.elapsed().as_nanos() as usize;
    println!("BENCH quic/inmemory-stream-32b {}", elapsed / STREAMS);
}

fn bench_packets() {
    let mut pair = connect();
    let payload = [b'x'; 1000];
    let id = pair.client.conn().streams().open(Dir::Bi).expect("no stream credit");
    let mut sid = None;
    let mut start = Instant::now();
    let mut sent_before = 0;
    for index in 0..PACKET_WARMUP + PACKETS {
        if index == PACKET_WARMUP {
            start = Instant::now();
            sent_before = pair.client.sent;
        }
        let written = pair.client.conn().send_stream(id).write(&payload).unwrap();
        assert_eq!(written, payload.len());
        pair.drive();
        let server = pair.server.conn();
        let stream = *sid.get_or_insert_with(|| {
            server.streams().accept(Dir::Bi).expect("no stream to accept")
        });
        assert_eq!(read_all(server, stream), (payload.len(), false));
        if index % 64 == 0 {
            pair.client.drain_events();
            pair.server.drain_events();
        }
    }
    let elapsed = start.elapsed().as_nanos() as usize;
    let sent = pair.client.sent - sent_before;
    eprintln!("client datagrams per 1000-byte write: {:.3}", sent as f64 / PACKETS as f64);
    println!("BENCH quic/inmemory-packet-1k {}", elapsed / PACKETS);
}

fn main() {
    bench_streams();
    bench_packets();
}

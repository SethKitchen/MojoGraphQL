<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Quic

`gql_quic` is a QUIC transport in Mojo: RFC 9000, its TLS handshake (RFC 9001) and its loss recovery (RFC 9002). It ports quinn-proto 0.11.19 under the MIT arm of its dual license. libssl of OpenSSL 3.5 runs the TLS handshake, and libcrypto protects the packets. `gql_http3` uses this transport by default.

The package depends only on `gql_tls`. It runs on Linux only. The state machines do no I/O and read no clock. The caller gives them datagrams and the time, and takes datagrams and the next deadline.

| Module | Contents |
| --- | --- |
| `gql_quic.driver` | `QuicDriver`: a poll loop with listeners, connections and streams as `Int` handles |
| `gql_quic.endpoint` | `Endpoint`: the connections of one UDP socket, routed by connection ID |
| `gql_quic.connection` | `Connection`, `TransportConfig`, `ConnectionState`: one end of a connection, without I/O |
| `gql_quic.streams` | `StreamsState`, `ReadStatus`: streams and flow control |
| `gql_quic.udp` | `UdpIo`: batched UDP I/O with `recvmmsg`, `sendmmsg` and GSO |
| `gql_quic.tls` | `QuicTls`, `TlsSession`: the TLS 1.3 handshake through `SSL_set_quic_tls_cbs` |
| `gql_quic.crypto` | `Crypto` with `hkdf_expand_label`, `PacketKey`, `HeaderKey`, `KeyPair`, `initial_keys` |
| `gql_quic.recovery` | `RttEstimator`, `NewReno` |
| `gql_quic.spaces` | `PacketSpace`, `SentPacket`, `SentFrame`: packet number spaces and sent packets |
| `gql_quic.send_buffer` | `SendBuffer`: the bytes that wait for an acknowledgment |
| `gql_quic.assembler` | `Assembler`: the reassembly of stream and CRYPTO bytes |
| `gql_quic.packet` | `parse_header`, `PacketHeader`, the header writers and the packet number coder |
| `gql_quic.frame` | `Frame`, `read_frame`, `ack_ranges` and the frame writers |
| `gql_quic.transport_params` | `TransportParameters` with `encode` and `decode` |
| `gql_quic.cid` | `ConnectionId`, `ResetToken` |
| `gql_quic.range_set` | `RangeSet`, `Interval` |
| `gql_quic.varint` | `read_varint`, `write_varint`: the variable-length integers of RFC 9000 section 16 |
| `gql_quic.shared` | `Side`, `Dir`, `StreamId` |
| `gql_quic.error` | `QuicError`, `TransportErrorCode` |

```mojo
from gql_tls.openssl import OpenSsl
from gql_quic.connection import TransportConfig
from gql_quic.crypto import Crypto
from gql_quic.driver import QuicDriver
from gql_quic.tls import QuicTls


def main() raises:
    var config = TransportConfig()
    config.max_idle_timeout_ms = 10_000
    var quic = QuicDriver(Crypto(OpenSsl()), QuicTls(OpenSsl()), config^)
```

## Layers

The wire layers are `varint`, `cid`, `range_set`, `frame`, `packet` and `transport_params`. They decode and encode bytes, and they raise `QuicError` for bytes that break RFC 9000. `error` holds the transport error codes.

`crypto` and `tls` bind OpenSSL. `spaces`, `send_buffer`, `assembler`, `streams` and `recovery` hold the state of a connection. `connection` and `endpoint` are the sans-I/O state machines. `udp` moves the datagrams, and `driver` joins all of them into one poll loop.

## Driver

`QuicDriver(crypto, tls, config)` makes a driver without sockets. It has the same handle shape as the QUIC API of OpenSSL. A listener, a connection and a stream are non-zero `Int` handles. Network I/O happens only in `handle_events`.

| Call | Result |
| --- | --- |
| `listener(ctx, fd)` | A listener that serves a bound UDP socket |
| `accept_connection(listener)` | The next new connection, or 0 |
| `client_connection(ctx, fd, host, verify)` | A client on a connected UDP socket |
| `connect(conn)` | 1 when the handshake is done, 0 while it runs, -1 when it failed |
| `failure(conn)`, `verify_failure(conn)` | Why a connection failed, and why the certificate check failed |
| `handshake_done(conn)`, `connection_closed(conn)` | The state of a connection |
| `close_connection(conn, code)` | Close with an application error code |
| `new_stream(conn, unidirectional)`, `accept_stream(conn)` | A stream that this end opens, or the next stream of the peer |
| `read(stream, ptr, size)`, `write(stream, data, fin)` | Read into a buffer, and queue bytes |
| `reset_stream(stream, code)`, `stream_id(stream)` | Reset a stream, and get its QUIC stream ID |
| `free(handle)` | Free a stream or a connection |
| `handle_events(handle)` | Read every datagram that waits, run the timers, and send |
| `event_timeout_ms(handle)` | How soon `handle_events` must run again |

`ctx` is the `SSL_CTX` of a `gql_tls.TlsContext`. The caller waits on the socket with `poll`, at most until `event_timeout_ms`. A write only queues bytes. Thus a response and its ACK leave in one datagram when `handle_events` runs.

An invalid or stale handle is not an error. A read gives `ReadStatus.RESET`, a write gives -1, and the other calls do nothing.

## Connection

`Connection.client` and `Connection.server` make one end of a connection. The caller gives it datagrams and the time in nanoseconds of a monotonic clock.

- `handle_datagram(now, data, size)` opens and reads every packet of a datagram, in place.
- `poll_transmit(now, out)` appends the next datagram to `out`. It coalesces the packets of each space that has data to send. It returns 0 when nothing waits.
- `poll_timeout()` gives the next deadline. `handle_timeout(now)` runs loss detection, the probe timeout, the delayed ACK, the idle timeout, and the closing and draining periods.
- `open`, `accept`, `write`, `read`, `reset`, `stop` and `release` act on the streams.
- `close(now, code, reason)` closes the connection. `is_established`, `is_closed` and `is_drained` give its state.

An ACK frame goes out at once for Initial and Handshake packets, after two ack-eliciting packets, or after a gap. Else it waits up to `max_ack_delay` and rides on the next packet that carries data. Thus one request and one response cost one datagram each way.

`TransportConfig()` holds the defaults of quinn, with a 1200-byte datagram. Its fields set the idle timeout, the receive windows and the stream limits. Other fields set the ACK delay, the datagram size, the initial RTT and the connection ID length.

## Endpoint

`Endpoint` holds the connections of one UDP socket. It routes each datagram by its Destination Connection ID. A server makes a connection for the first Initial packet of a client, in a datagram of at least 1200 bytes. It answers a long header of another version with Version Negotiation. It drops the other datagrams that match no connection.

## TLS and packet protection

`QuicTls` is the table of the libssl functions. `TlsSession` owns one `SSL` object, and `SSL_set_quic_tls_cbs` replaces its TLS record layer with callbacks. The callbacks only queue: the handshake bytes of each level, the secrets, the transport parameters of the peer and the alert. The connection reads the queues after each `advance`, so the handshake is sans-I/O too.

`Crypto` is the table of the libcrypto functions: AEAD, header protection and HKDF. `PacketKey` seals and opens a packet in place, and `HeaderKey` applies and removes header protection. The package implements no cryptographic primitive. AES-GCM, ChaCha20-Poly1305, AES-ECB, ChaCha20 and HKDF all run in libcrypto.

The server discards the Initial keys when the first Handshake packet opens. The client discards them when it first sends a Handshake packet. Both ends discard the Handshake keys when the handshake is confirmed (RFC 9001 section 4.9).

## Recovery and streams

`RttEstimator` keeps the latest, the smallest and the smoothed RTT, and its variation (RFC 9002 section 5). `NewReno` is the congestion controller of RFC 9002 section 7. A congestion event halves the window.

`StreamsState` holds the open streams, the stream limits of both ends, and the flow control of the connection. `write` takes the bytes that the credit allows, and keeps them in a `SendBuffer` until they are acknowledged. A received STREAM frame goes into an `Assembler`, and `read` gives the bytes in order. The limits grow with MAX_STREAM_DATA, MAX_DATA and MAX_STREAMS frames.

## UDP

`UdpIo` reads and writes the datagrams of one non-blocking IPv4 UDP socket. `recv` takes up to `BATCH` datagrams with one `recvmmsg` call. `send` sends the datagrams to one peer of one size as one GSO message with `UDP_SEGMENT`. A kernel without GSO fails the first such send. `UdpIo` then turns GSO off and sends the datagrams one by one.

A connected socket sends without addresses. That is the client of `gql_http3`. An unconnected socket gives and takes an address for each datagram. That is the server.

## Transport in gql_http3

`gql_http3.quic.Quic` is one API over two QUIC stacks. `QuicTransport` chooses the stack:

- `QuicTransport.NATIVE` is the default. It runs `gql_quic` through `QuicDriver`.
- `QuicTransport.OPENSSL` runs the QUIC stack of OpenSSL 3.5. Its listeners, connections and streams are `SSL` objects.

`Quic(openssl, marker, transport)` selects the stack. The server, the client and the fallback chain use the same calls on both stacks. Copies of a `Quic` share one `QuicDriver`. See [Http3](Http3) for the server and the client.

```mojo
from gql_tls.openssl import OpenSsl
from gql_http3.quic import Quic, QuicTransport


def main() raises:
    var native = Quic(OpenSsl())
    var openssl = Quic(OpenSsl(), transport=QuicTransport.OPENSSL)
```

## Differences from upstream

The module docstrings list each difference in full. These are the differences that change the behavior on the wire:

- **Features:** there is no 0-RTT, no Retry, no path migration and no MTU discovery. The datagram size stays `TransportConfig.datagram_size`.
- **Network:** there is no ECN, no pacing, no keep-alive and no stateless reset. UDP is IPv4 only, with no GRO and no `IP_PKTINFO`.
- **Congestion:** the controller is NewReno. The default of quinn is Cubic. Persistent congestion is not detected.
- **Key update:** this end never starts a key update. It follows a key update that the peer starts.
- **Connection IDs:** this end issues no extra connection IDs. It reads the NEW_CONNECTION_ID frames of the peer only to retire IDs.
- **Server:** a server accepts every valid Initial, with no connection limit. quinn gives `Incoming` values that the application accepts or refuses.
- **Frames:** the DATAGRAM, ACK_FREQUENCY and IMMEDIATE_ACK extension frames are not ported. Their types are `invalid frame ID`.
- **Transport parameters:** this end writes no preferred address and no grease parameter. `max_datagram_frame_size` and `min_ack_delay` are skipped as unknown IDs.
- **Streams:** `accept` gives the streams of the peer of both directions, in the order that they opened. Reads are in order only. STREAM_DATA_BLOCKED and STREAMS_BLOCKED are not sent.
- **Crypto:** only QUIC version 1 is supported, so there is one Initial salt. The keys are concrete types over libcrypto, where quinn uses rustls and ring through traits.

These are the differences in the shape of the API:

- **Driver:** quinn is async on tokio. `QuicDriver` is a poll loop without threads, and its handles follow the QUIC API of OpenSSL.
- **Events:** a `Connection` keeps no queue of events. The caller asks for the state.
- **Errors:** a decoder raises `QuicError` with the reason of upstream, such as `invalid header: malformed cid`. Upstream returns a `PacketDecodeError`.
- **Values:** `Frame` is one flat struct, and a run of PADDING bytes is one frame. `Side` and `Dir` are structs with `is_valid`.

## Tests

The suites are `tests/gql_quic/test_*.mojo`. They port the tests of quinn-proto `src/tests`, `frame.rs`, `packet.rs`, `range_set` and the other modules, and of quinn-udp `tests/tests.rs`. `test_crypto` checks the keys and packets of RFC 9001 Appendix A.

- `test_connection_handshake`, `test_connection_streams` and `test_connection_frames` run two `Connection` values in memory. `_inject.mojo` writes the packets of a peer by hand.
- `test_endpoint` routes datagrams in memory.
- `test_udp` and `test_driver` use localhost UDP sockets. `test_driver` runs an echo, a 200 KB echo through small windows, a refused handshake and a handshake timeout.

`make test PKG=gql_quic` runs the suites of `gql_quic` and of `gql_http3`, which depends on it. `make coverage PKG=gql_quic ONLY=1` measures `gql_quic` alone. Line, branch, condition and MC/DC coverage are 100%.

## Benchmarks

`bench/gql_quic/echo.mojo` times `quic/echo-roundtrip-32b`. A `QuicDriver` server in a child process echoes each bidirectional stream. One client writes 32 bytes and FIN on each stream, and reads the echo to the end. The baseline `bench/baselines/rust-quic` runs quinn 0.11.12 and tokio in the same way.

| Workload | Mojo | quinn 0.11 | Speedup |
| --- | --- | --- | --- |
| `quic/echo-roundtrip-32b` | 73 µs | 90 µs | 1.23x |
| `h3/roundtrip-small-json` on `gql_http3` | 98 µs | 112 µs with h3 | 1.14x |

`make bench-check PKG=gql_quic` must pass. See [Benchmarks](Benchmarks) for the method.

## License

quinn-proto and quinn-udp are MIT OR Apache-2.0. This port uses them under the MIT License. `THIRD-PARTY-NOTICES.md` holds the license text. OpenSSL is Apache-2.0 licensed. `gql_quic` loads it at run time and calls its public API. The project ports no OpenSSL code, and it does not ship OpenSSL.

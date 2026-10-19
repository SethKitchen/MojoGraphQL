<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Http3

`gql_http3` is HTTP/3 (RFC 9114) and QPACK (RFC 9204) in Mojo, over the QUIC API of the system OpenSSL 3.5. It serves the `Handler` of `gql_http` on UDP. It has a client, `Alt-Svc` support (RFC 7838), and a client that falls back to TCP. It depends on `gql_http` and `gql_tls`, and it runs on Linux only.

| Module | Contents |
| --- | --- |
| `gql_http3.server` | `H3Server`, `H3Config`, `listen_h3`, `ControlReader`, `StreamRole`, `control_preface` |
| `gql_http3.client` | `H3Client`, `h3_error` |
| `gql_http3.fallback` | `FallbackClient`, `FallbackConfig`, `Protocol` |
| `gql_http3.alt_svc` | `AltSvc`, `AltService`, `AltSvcCache`, `parse_alt_svc` |
| `gql_http3.quic` | `Quic`, `QuicContext`, `QuicCall`, `QuicFaults`, `ReadResult`, `ReadState` |
| `gql_http3.message` | `MessageReader`, `to_http1_request`, `from_http1_response`, `request_fields`, `to_http1_response`, `write_message` |
| `gql_http3.frame` | `FrameType`, `StreamType`, `SettingId`, `Settings`, `FrameReader`, `parse_frame_head` and the frame writers |
| `gql_http3.qpack` | `QpackEncoder`, `QpackDecoder`, `FieldList`, the static table, prefix integers and strings |
| `gql_http3.huffman` | The Huffman code of RFC 7541 Appendix B |
| `gql_http3.varint` | The variable-length integers of RFC 9000 section 16 |
| `gql_http3.error` | `H3Error`, `H3ErrorCode` |

```mojo
from gql_http.server import ServerConfig
from gql_tls.context import TlsContext
from gql_tls.openssl import OpenSsl
from gql_tls.server import listen_https
from gql_http3.alt_svc import AltSvc
from gql_http3.quic import Quic
from gql_http3.server import H3Config, listen_h3


def main() raises:
    var h3_config = H3Config()
    h3_config.port = 4433
    var h3 = listen_h3(Hello(), "cert.pem", "key.pem", h3_config, Quic(OpenSsl()))
    # The TCP server announces the UDP port to its clients.
    var protocols = List[String]()
    protocols.append("http/1.1")
    var context = TlsContext.server(OpenSsl(), "cert.pem", "key.pem", protocols^)
    var tcp_config = ServerConfig()
    tcp_config.port = 4433
    var https = listen_https(AltSvc(Hello(), 4433), context^, tcp_config)
    while True:
        _ = h3.poll(0)
        _ = https.poll(1)
```

## Server

`H3Server[H]` is one event loop on one UDP socket. `poll(timeout_ms)` waits for a datagram or a QUIC timer, and then serves every connection. `run()` serves until `close()`.

| `H3Config` field | Default | Contents |
| --- | --- | --- |
| `host` | `IPv4Address.ANY` | The local address |
| `port` | `4433` | The UDP port; `0` lets the system choose one |
| `limits` | `Limits()` | The size limits of a request, as for HTTP/1.1 |

- **Requests:** a request stream carries a HEADERS frame and DATA frames. At the end of the stream, the server writes the request as HTTP/1.1, and the `RequestReader` of `gql_http` parses it. Thus a handler serves HTTP/1.1, HTTPS and HTTP/3 the same way.
- **Responses:** the server reads the response of the `ResponseWriter`, and sends a HEADERS frame and a DATA frame. It drops the fields that are specific to a connection, such as `Connection`.
- **Control streams:** the control stream of the client must start with SETTINGS. The server opens its own control stream when the handshake ends.
- **QPACK:** the server announces a dynamic table capacity of 0. Thus it uses the static table and literals only.
- **Errors:** a malformed request resets its stream with `H3_MESSAGE_ERROR`. A connection error, such as a second control stream, closes the connection with its code.
- **Limits:** `limits.max_head_bytes` is `SETTINGS_MAX_FIELD_SECTION_SIZE`, and `limits.max_body_bytes` limits the content of a request.

The QUIC objects of the server use explicit event handling: network I/O occurs only in `SSL_handle_events`. `poll` serves until a turn finds no work. Thus the socket holds each datagram that is not read yet, and the next wait sees it.

The writer has no socket, so `ResponseWriter.flush` keeps the bytes. Streamed content goes out after the handler returns. The server sends no GOAWAY at shutdown, and it never pushes.

## Client

`H3Client` sends one request at a time and returns the whole `gql_http.client.Response`, the type of the other clients. It keeps one QUIC connection per address and port, and it opens one request stream for each request.

| Method | Result |
| --- | --- |
| `H3Client(context, config)` | A client with a context from `QuicContext.client` |
| `H3Client.system(config)` | A client that trusts the system CA store |
| `get(url)`, `post(url, content_type, body)` | Send a request to an `https` URL |
| `endpoint(url)`, `send(endpoint, method, target, headers, body)` | Resolve a URL once, for many requests |
| `connections()`, `close()` | The open connections |

Each request has the deadline `ClientConfig.timeout_ms`. The handshake also has the limit `connect_timeout_ms`. When a reused connection gives no stream, such as a connection that is closing, the client sends the request on a new connection.

## Fallback chain

`FallbackClient` sends each request with the first protocol that works:

1. HTTP/3 over QUIC, for an `https` URL. The client tries it when `enable_h3` is set, or when the origin announced `h3` in an `Alt-Svc` field. The QUIC handshake has the short limit `h3_timeout_ms`.
2. HTTPS over TCP, with TLS and the ALPN protocol `http/1.1`, for an `https` URL.
3. HTTP/1.1 over TCP, for an `http` URL.

When HTTP/3 fails before a response, the client forgets the `Alt-Svc` entry of the origin. It uses TCP for that origin during `h3_retry_after_s`, and it sends the request again over TCP. An `Alt-Svc` field in a TCP response adds the origin to the cache, so that later requests use HTTP/3. `protocol` tells how the last response came.

| `FallbackConfig` field | Default | Contents |
| --- | --- | --- |
| `client` | `ClientConfig()` | The timeouts and limits of each request |
| `enable_h3` | `False` | Whether to try HTTP/3 on the port of the URL without `Alt-Svc` |
| `h3_timeout_ms` | `300` | The longest QUIC handshake before the client uses TCP |
| `h3_retry_after_s` | `300` | How long the client uses TCP after HTTP/3 failed for an origin |
| `ca_file` | empty | A PEM file of trusted CA certificates; empty for the system store |
| `verify` | `True` | Whether to verify servers; turn it off only in tests |

A network that blocks UDP drops the QUIC packets, so the handshake times out after `h3_timeout_ms`. A closed UDP port gives an ICMP error, and the client falls back at once. The client loads OpenSSL only for the first `https` request.

HTTP/2 over TLS is not in the chain yet. It needs the client of `gql_http2`, and the package that joins TLS and HTTP/2.

## Alt-Svc

`AltSvc(handler, port, max_age)` is a `Handler` that adds `Alt-Svc: h3=":<port>"; ma=<max_age>` to each response, and then calls `handler`. Put it around the handler of the TCP servers of `gql_http` and `gql_tls`.

`parse_alt_svc(value)` gives the first `h3` alternative of an `Alt-Svc` value, or None. The value `clear` gives an alternative with port 0. `AltSvcCache` keeps one alternative for each origin until its `ma` ends: `remember(origin, value, now)`, `lookup(origin, now)` and `forget(origin)`.

## QPACK and frames

`QpackEncoder` and `QpackDecoder` port the QPACK coder of hyperium/h3. The dynamic table is complete: capacity and eviction, absolute, relative and post-base indexing, and the instructions of the encoder and decoder streams. The server and the client use a capacity of 0.

- `QpackDecoder.decode(stream_id, block, fields)` returns False for a section that waits for the encoder stream.
- A field section over the size limit raises `H3_EXCESSIVE_LOAD`.
- `FieldList` keeps the names and values of a field section in one buffer.
- `FrameReader` reads frames as bytes arrive. It skips reserved frame types, and it refuses the HTTP/2 frame types.

## QUIC

`Quic(openssl)` looks up the QUIC functions in the library of a `gql_tls.OpenSsl`. An OpenSSL older than 3.5 has no QUIC server API, and `Quic` raises a `LIBRARY` error. `QuicContext.server(quic, cert_file, key_file)` and `QuicContext.client(quic, ca_file, verify)` make the contexts, with the ALPN protocol `h3`. `Quic.faults` makes one kind of call fail, for tests.

## Performance

The QPACK coder is 2.5 to 3.1 times faster than the coder of h3. The HTTP/3 round trip is slower than h3 with quinn: about 140 µs against 111 µs on localhost. This is an open item.

- **Datagrams:** OpenSSL sends an ACK in a datagram of its own, after each second packet that it receives. Thus a round trip costs 3 datagrams, against 2.2 for quinn. quinn puts the ACK into its next packet.
- **CPU:** the QUIC stack of OpenSSL takes about two times the user CPU of quinn for each round trip. The framing and QPACK of this package are a small part of the time.
- **Fix:** a QUIC transport in Mojo, with the third-party QUIC TLS API of OpenSSL 3.5 (`SSL_set_quic_tls_cbs`) for the handshake. That is a separate task.

## Differences from upstream

- **Async:** h3 is async and generic over a QUIC implementation. This port is a poll loop over the OpenSSL QUIC API.
- **Messages:** h3 builds `http::Request` values. The server writes HTTP/1.1 bytes instead, because the handlers take a `gql_http` `Request`.
- **Huffman:** the encoder uses Huffman only when it is shorter, so the empty string is `0x00` where h3 writes `0x80`. Huffman padding of more than 7 bits is an error, as RFC 7541 section 5.2 tells.
- **Encoder base:** the encoder base is the insert count, and the prefix is encoded against the SETTINGS maximum.
- **Checks:** the decoder refuses a dynamic reference at or above the Required Insert Count. It also refuses an Insert Count Increment of 0, and a boolean setting above 1.
- **Duplicate:** the encoder does not emit the Duplicate instruction. The decoder accepts it.

## License

hyperium/h3 is MIT licensed; `THIRD-PARTY-NOTICES.md` holds its license text. OpenSSL is Apache-2.0 licensed. `gql_http3` loads OpenSSL at run time and calls its public API. The project ports no OpenSSL code, and it does not ship OpenSSL.

<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Http3

`gql_http3` is HTTP/3 (RFC 9114) and QPACK (RFC 9204) in Mojo. The default QUIC transport is `gql_quic`. OpenSSL 3.5 runs the TLS handshake. The same library can run the OpenSSL QUIC stack instead. The server serves the `Handler` of `gql_http` on UDP. It has a client, `Alt-Svc` (RFC 7838) and a TCP fallback.

It depends on `gql_http`, `gql_tls`, `gql_quic`, `gql_http2` and `gql_https2`. It runs on Linux only. The fallback chain needs the HTTP/2 packages.

| Module | Contents |
| --- | --- |
| `gql_http3.server` | `H3Server`, `H3Config`, `listen_h3`, `ControlReader`, `StreamRole`, `control_preface` |
| `gql_http3.client` | `H3Client`, `h3_error` |
| `gql_http3.fallback` | `FallbackClient`, `FallbackConfig`, `Protocol` |
| `gql_http3.alt_svc` | `AltSvc`, `AltService`, `AltSvcCache`, `parse_alt_svc` |
| `gql_http3.quic` | `Quic`, `QuicTransport`, `QuicContext`, `QuicCall`, `QuicFaults`, `ReadResult`, `ReadState` |
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
| `enable_connect` | `False` | Send `SETTINGS_ENABLE_CONNECT_PROTOCOL = 1`, and give each extended `CONNECT` to the application as tunnel events |

- **Requests:** a request stream carries a HEADERS frame and DATA frames. At the end of the stream, the server writes the request as HTTP/1.1, and the `RequestReader` of `gql_http` parses it. Thus a handler serves HTTP/1.1, HTTPS and HTTP/3 the same way.
- **Responses:** the server reads the response of the `ResponseWriter`, and sends a HEADERS frame and a DATA frame. It drops the fields that are specific to a connection, such as `Connection`.
- **Control streams:** the control stream of the client must start with SETTINGS. The server opens its own control stream when the handshake ends.
- **QPACK:** the server announces a dynamic table capacity of 0. Thus it uses the static table and literals only.
- **Errors:** a malformed request resets its stream with `H3_MESSAGE_ERROR`. A connection error, such as a second control stream, closes the connection with its code.
- **Limits:** `limits.max_head_bytes` is `SETTINGS_MAX_FIELD_SECTION_SIZE`, and `limits.max_body_bytes` limits the content of a request.

The QUIC objects of the server use explicit event handling: network I/O occurs only in `SSL_handle_events`. `poll` serves until a turn finds no work. Thus the socket holds each datagram that is not read yet, and the next wait sees it.

The writer has no socket, so `ResponseWriter.flush` keeps the bytes. Streamed content goes out after the handler returns. The server sends no GOAWAY at shutdown, and it never pushes.

### Tunnels

With `enable_connect`, a request stream with `:method CONNECT` and `:protocol` is a tunnel (RFC 9220). The handler does not see it. The server appends a `TunnelEvent` to `H3Server.events` for each step, and the application clears the list.

| `TunnelEventKind` | When |
| --- | --- |
| `HEAD` | The HEADERS of the extended `CONNECT` arrived; `fields` holds them |
| `DATA` | Content of DATA frames arrived; `data` holds it |
| `END` | The peer ended its side of the stream (FIN) |
| `RESET` | The peer reset the stream, the content was too large, or the connection ended |

- **Send:** `send(stream, data, fin)` writes HEADERS and DATA frames on a tunnel. QUIC sends at once what the stream has credit for, and each `poll` sends the rest. `pending(stream)` is the count of bytes that wait for credit.
- **Reset:** `reset(stream, code)` resets a tunnel, such as for a malformed extended `CONNECT`.
- **Ends:** a tunnel stays until the application ends its side with `fin`, or resets it. [WsHttp3](WsHttp3) runs WebSockets on these events.

## Client

`H3Client` sends one request at a time and returns the whole `gql_http.client.Response`, the type of the other clients. It keeps one QUIC connection per address and port, and it opens one request stream for each request.

| Method | Result |
| --- | --- |
| `H3Client(context, config)` | A client with a context from `QuicContext.client` |
| `H3Client.system(config)` | A client that trusts the system CA store |
| `get(url)`, `post(url, content_type, body)` | Send a request to an `https` URL |
| `endpoint(url)`, `send(endpoint, method, target, headers, body)` | Resolve a URL once, for many requests |
| `connections()`, `close()` | The open connections |
| `open_stream(endpoint)` | A request stream that stays open, for the tunnel of an extended `CONNECT` |
| `write_stream(stream, data, fin)`, `read_stream(stream, data, timeout_ms)` | Write frames on such a stream, and read what arrived |
| `reset_stream(stream, code)`, `close_stream(stream)` | Reset the stream, or free it; the connection stays open |

`open_stream` waits for the SETTINGS of the server. It raises `PROTOCOL` when the server does not send `SETTINGS_ENABLE_CONNECT_PROTOCOL = 1`. `read_stream` returns `DATA`, `WAIT` after the timeout, `END` at the FIN of the server, or `RESET`.

Each request has the deadline `ClientConfig.timeout_ms`. The handshake also has the limit `connect_timeout_ms`. When a reused connection gives no stream, such as a connection that is closing, the client sends the request on a new connection.

## Fallback chain

`FallbackClient` sends each request with the first protocol that works. The chain is h3, then h2 over TLS, then HTTPS/1.1, then h2c, then HTTP/1.1:

1. **h3:** HTTP/3 over QUIC, for an `https` URL. The client tries it when `enable_h3` is set, or when the origin announced `h3` in an `Alt-Svc` field. The QUIC handshake has the short limit `h3_timeout_ms`.
2. **h2:** HTTP/2 over TLS, for an `https` URL. The TLS handshake offers the ALPN protocols `h2` and `http/1.1` when `enable_h2` is set. The server chooses one.
3. **https/1.1:** HTTPS/1.1 on the same TLS connection, when the server does not choose `h2`. The client remembers the endpoint, and its later requests use HTTPS/1.1 at once.
4. **h2c:** HTTP/2 over TCP with prior knowledge, for an `http` URL, when `enable_h2c` is set.
5. **http/1.1:** HTTP/1.1 over TCP, for an `http` URL. With `enable_h2c`, this step is for a server that does not answer the h2c preface.

Steps 2 and 3 are one TLS connection, through the `Https2Client` of [Https2](Https2). Step 4 uses the `Client` of [Http2](Http2#client), which does step 5 for a server without HTTP/2.

When HTTP/3 fails before a response, the client forgets the `Alt-Svc` entry of the origin. It uses TCP for that origin during `h3_retry_after_s`, and it sends the request again over TCP. An `Alt-Svc` field in a TCP response adds the origin to the cache, so that later requests use HTTP/3. `protocol` tells how the last response came.

| `FallbackConfig` field | Default | Contents |
| --- | --- | --- |
| `client` | `ClientConfig()` | The timeouts and limits of each request |
| `enable_h3` | `False` | Whether to try HTTP/3 on the port of the URL without `Alt-Svc` |
| `h3_timeout_ms` | `300` | The longest QUIC handshake before the client uses TCP |
| `h3_retry_after_s` | `300` | How long the client uses TCP after HTTP/3 failed for an origin |
| `ca_file` | empty | A PEM file of trusted CA certificates; empty for the system store |
| `verify` | `True` | Whether to verify servers; turn it off only in tests |
| `enable_h2` | `True` | Whether the TLS handshake offers `h2` before `http/1.1` |
| `enable_h2c` | `False` | Whether an `http` URL gets h2c with prior knowledge first |

A network that blocks UDP drops the QUIC packets, so the handshake times out after `h3_timeout_ms`. A closed UDP port gives an ICMP error, and the client falls back at once. The client loads OpenSSL only for the first `https` request.

| `Protocol` | Meaning |
| --- | --- |
| `NONE` | No request yet |
| `HTTP3` | HTTP/3 over QUIC |
| `HTTPS2` | HTTP/2 over TLS, after ALPN chose `h2` |
| `HTTPS1` | HTTP/1.1 over TLS |
| `H2C` | HTTP/2 over TCP with prior knowledge |
| `HTTP1` | HTTP/1.1 over TCP |

h2c is off by default, because a server without HTTP/2 must first refuse the preface. That costs one more connection on the first request.

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

`Quic(openssl)` uses the native transport, `QuicTransport.NATIVE`, by default. That is [Quic](Quic). Pass `transport=QuicTransport.OPENSSL` to use the QUIC stack of OpenSSL 3.5 instead. An older OpenSSL has neither API, and `Quic` raises a `LIBRARY` error. `QuicContext.server` and `QuicContext.client` make the contexts, with the ALPN protocol `h3`. `Quic.faults` makes one kind of call fail, for tests.

## Performance

The round-trip gap to h3 with quinn is closed. The QPACK coder is 2.6 to 3.2 times faster than the coder of h3. A 32-byte QUIC stream echo takes 73 µs. quinn takes 90 µs for the same echo. An HTTP/3 round trip of a small JSON body takes 99 µs. h3 with quinn takes 111 µs.

The tunnels of the extended `CONNECT` did not change the time of a round trip.

The OpenSSL QUIC stack remains an option. It sends each ACK in its own datagram, so a round trip on that stack is slower.

## Differences from upstream

- **Async:** h3 is async and generic over a QUIC implementation. This port is a poll loop. The default transport is `gql_quic`. OpenSSL QUIC remains available.
- **Messages:** h3 builds `http::Request` values. The server writes HTTP/1.1 bytes instead, because the handlers take a `gql_http` `Request`.
- **Huffman:** the encoder uses Huffman only when it is shorter, so the empty string is `0x00` where h3 writes `0x80`. Huffman padding of more than 7 bits is an error, as RFC 7541 section 5.2 tells.
- **Encoder base:** the encoder base is the insert count, and the prefix is encoded against the SETTINGS maximum.
- **Checks:** the decoder refuses a dynamic reference at or above the Required Insert Count. It also refuses an Insert Count Increment of 0, and a boolean setting above 1.
- **Duplicate:** the encoder does not emit the Duplicate instruction. The decoder accepts it.
- **Extended CONNECT:** h3 gives each request to the application at its head, with the `Protocol` extension. Here only a tunnel is given at its head, as events. h3 0.0.8 accepts only the `:protocol` values `webtransport` and `connect-udp`, and refuses a request with another value. Here any value opens a tunnel, such as `websocket` of RFC 9220.

## License

hyperium/h3 is MIT licensed; `THIRD-PARTY-NOTICES.md` holds its license text. OpenSSL is Apache-2.0 licensed. `gql_http3` loads OpenSSL at run time and calls its public API. The project ports no OpenSSL code, and it does not ship OpenSSL.

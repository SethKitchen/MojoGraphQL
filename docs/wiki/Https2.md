<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Https2

`gql_https2` is HTTP/2 over TLS (RFC 9113 section 3.2) with the ALPN protocol `h2`. It serves `h2` and HTTP/1.1 on one TLS port with one gql_http `Handler`. Its client speaks `h2` when the server chooses it, and HTTPS/1.1 when the server does not. The package depends on `gql_http`, `gql_http2` and `gql_tls`, and it runs on Linux only.

| Module | Contents |
| --- | --- |
| `gql_https2.server` | `H2Protocol`, `SharedHandler`, `listen_https2`, `H2` |
| `gql_https2.client` | `Https2Client`, `http1_response`, `tls_error` |
| `gql_https2.transport` | `TlsTransport`, `transport_errno` |

```mojo
from gql_http.server import ServerConfig
from gql_tls.context import TlsContext
from gql_tls.openssl import OpenSsl
from gql_https2.server import listen_https2


def main() raises:
    # The default ALPN protocols are h2, then http/1.1.
    var context = TlsContext.server(OpenSsl(), "cert.pem", "key.pem")
    var config = ServerConfig()
    config.port = 4443
    var server = listen_https2(Hello(), context^, config)
    server.run()
```

## Why a separate package

The glue is in its own package, so that each user gets the smallest closure:

- `gql_http2` does not import `gql_tls`. A user of h2c does not need OpenSSL.
- `gql_tls` does not import `gql_http2`. A user of HTTPS/1.1 does not compile HTTP/2.
- A user of HTTP/2 over TLS builds `gql_http`, `gql_http2`, `gql_tls` and `gql_https2`, and not the QUIC and QPACK code of `gql_http3`.

`gql_http3` depends on `gql_https2`, because its fallback chain includes HTTP/2 over TLS. A module inside `gql_http3` would add HTTP/3 to the closure of each HTTP/2 user. See [How to pick packages](How-to-pick-packages).

## Server

`listen_https2(handler, context, config, h2)` opens a `gql_tls` `TlsServer` whose `TlsProtocol` is `H2Protocol`. After the handshake, ALPN decides the protocol of a connection:

- **h2:** the server gives the decrypted bytes to a gql_http2 `ServerSession`, and sends the frames that it answers.
- **http/1.1, or no ALPN:** the server serves HTTP/1.1, as `listen_https` does.

The server chooses the first of its protocols that the client offers (RFC 7301 section 3.2). The context of `TlsContext.server` lists `h2` first, so `h2` is preferred. A client that offers only `http/1.1` gets HTTP/1.1. A context without `h2` gives HTTP/1.1 to each client.

| Argument | Default | Contents |
| --- | --- | --- |
| `handler` | | The handler of every request of both protocols |
| `context` | | A server context, with the ALPN protocols `h2` and `http/1.1` |
| `config` | | The `gql_http.server.ServerConfig`: the address, the port, the timeouts and the limits |
| `h2` | `Config()` | The limits of each HTTP/2 connection, as in [Http2](Http2#connection) |

`SharedHandler` gives the HTTP/1.1 part and the HTTP/2 part the same handler. Thus the handler has one state. `server.handler.shared[]` is the handler, and `server.other.sessions()` is the count of open HTTP/2 connections.

The requests and responses of `h2` follow the rules of [Http2](Http2#requests-and-responses). The handler cannot see which protocol carried a request.

## Client

`Https2Client` sends one request and returns the whole gql_http2 `Response`. It has `get(url)`, `post(url, content_type, body)`, `endpoint(url)` and `send(endpoint, method, target, headers, body)`. It raises a `TlsError`.

- **ALPN:** each handshake offers `h2`, then `http/1.1`.
- **h2:** when the server chooses `h2`, the request goes on a gql_http2 `ClientConnection` over a `TlsTransport`. The client keeps one HTTP/2 connection per address and port.
- **HTTPS/1.1:** when the server does not choose `h2`, the client gives the connection to its gql_tls `HttpsClient`, and sends the request on it. Later requests to that endpoint go with HTTPS/1.1 at once.
- **Retry:** when a `GOAWAY` refused the stream of a reused connection, the request goes again on a new connection. When the transport failed, only an idempotent method goes again.

| Function | Result |
| --- | --- |
| `Https2Client.create(openssl, ca_file, verify, offer_h2, config, h2)` | A client and its two contexts; `offer_h2=False` speaks HTTPS/1.1 only |
| `Https2Client(context, http1_context, config, h2)` | A client with two client contexts: one with `h2` and `http/1.1`, and one with `http/1.1` alone |
| `connections()` | The count of HTTP/2 connections |
| `speaks_http1(endpoint)` | Whether the server of an endpoint did not choose `h2` |
| `close()` | Closes every connection of both protocols |

`Response.protocol` is `Protocol.HTTP_2` or `Protocol.HTTP_1_1`. `http1_response(response, method, config)` copies a `Response` into a `gql_http.client.Response`, the type of the other clients. `tls_error(error)` maps an `H2Error` to a `TlsError`.

## Transport

`TlsTransport` is the gql_http2 `Transport` over a `TlsStream` after its handshake. It owns the stream and its socket.

| Method | Contract |
| --- | --- |
| `read(data, size)` | The count of decrypted bytes, 0 at the end of the stream, `-EAGAIN` when the stream waits for the socket, or another negative error number |
| `write(data, size)` | The count of bytes that the stream took, `-EAGAIN`, or another negative error number |
| `close()` | Sends `close_notify`, frees the stream and closes the socket, once |
| `fd()` | The socket, or -1 after `close` |

OpenSSL gives the bytes that it holds before it waits. Thus a caller that waits on `fd()` after `-EAGAIN` does not miss a byte. A failed TLS call gives its system error number, or `-ECONNRESET` when it has none.

## Differences from upstream

There is no upstream: the package ports no code. These are the differences from the h2c server of `gql_http2`:

- **Shutdown.** `TlsProtocol` has no shutdown. A graceful shutdown of the server does not send `GOAWAY`. An `h2` connection ends when its client closes it, or at `shutdown_timeout_ms`.
- **One process.** `TlsServer` is one event loop. Run one server for each core with `reuse_port`.
- **A read that needs a write.** A TLS 1.3 read can wait for a write. The transport returns `-EAGAIN`, and the caller waits for a readable socket.

## Tests

The tests are in `tests/gql_https2/`. They use real sockets on the loopback address, with servers in child processes.

- **Round trips.** `test_server.mojo` checks `h2` requests on one connection, the ALPN preference for `h2`, and HTTP/1.1 for a client that offers only `http/1.1`.
- **Client.** `test_client.mojo` checks the fallback to HTTPS/1.1 and the retries. A scripted protocol refuses a stream with `GOAWAY`, ignores a stream, or closes the connection.
- **Protocol and transport.** `test_protocol.mojo` drives `H2Protocol` without TLS. `test_transport.mojo` makes TLS calls fail with `TlsFaults`.
- **Interop.** `test_interop.mojo` runs `curl --http2 -k` and `curl --http1.1 -k` against the server. It passes at once when the curl has no HTTP/2.

## Benchmarks

`bench/gql_https2/roundtrip.mojo` has the workload `https2/roundtrip-small-json`. A server in a child process answers each small GraphQL `POST`. The client sends the requests one at a time, on one TLS 1.3 connection with `h2`. The handshake is outside the timer.

The baseline `hyper-rustls-h2` in `bench/baselines/rust-tls` runs hyper 1.12.0 with h2 0.4.20 and rustls 0.23.45, as the client and as the server.

| Workload | Mojo | hyper, h2 and rustls |
| --- | --- | --- |
| `https2/roundtrip-small-json`, ns | 91,959 | 113,448 |

The numbers come from one run of the bench tool for `gql_https2` on one machine. They change from machine to machine.

## License

OpenSSL is Apache-2.0 licensed. The package loads it at run time through `gql_tls`, and calls its public API. The project ports no OpenSSL code, and it does not ship OpenSSL.

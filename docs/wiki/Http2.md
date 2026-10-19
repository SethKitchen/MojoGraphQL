<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Http2

`gql_http2` is HTTP/2 (RFC 9113) with HPACK (RFC 7541) for the other packages. The server serves HTTP/2 and HTTP/1.1 on one port with one gql_http `Handler`, so `gql_server` works over HTTP/2 unchanged. The client speaks h2c with prior knowledge, and falls back to HTTP/1.1. The package ports h2 v0.4.20, and it depends on `gql_http` only.

| Module | Contents |
| --- | --- |
| `gql_http2.server` | `ServerConfig`, `Server`, `listen`, `start_workers`, `run_worker`, `serve` |
| `gql_http2.session` | `Transport`, `SocketTransport`, `ServerSession`, `serve_transport`, `write_all`, `is_h2c_upgrade`, `decode_base64url` |
| `gql_http2.client` | `Client`, `ClientConfig`, `ClientConnection`, `Response`, `Protocol`, `http_error` |
| `gql_http2.connection` | `Connection`, `Config`, `Role`, `StreamState`, `Stream`, `Event`, `EventKind`, and the message checks |
| `gql_http2.frame` | `FrameKind`, `FrameHead`, `Settings`, `SettingId`, and the frame writers and readers |
| `gql_http2.hpack` | `Encoder`, `Decoder`, `HeaderList`, `HpackError`, `HpackErrorKind`, `encode_integer`, `decode_integer` |
| `gql_http2.hpack_table` | The static table and the dynamic table |
| `gql_http2.huffman` | The Huffman code of RFC 7541 Appendix B |
| `gql_http2.error` | `H2Error`, `H2ErrorKind`, `Reason` |

```mojo
from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter
from gql_http.status import Status
from gql_http2.server import ServerConfig, serve


struct Hello(Handler):
    def __init__(out self):
        pass

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        response.send(Status.OK, "application/json", '{"data":{"hello":"world"}}')


def main() raises:
    var config = ServerConfig()
    config.http.workers = 4
    serve(Hello(), config)
```

## Server

The server reads the first bytes of each connection to choose its protocol. The handler, the workers and the shutdown are those of [Http](Http).

- **Prior knowledge:** a connection that starts with the preface `PRI * HTTP/2.0` gets HTTP/2 (RFC 9113 section 3.3).
- **HTTP/1.1:** any other connection goes to a gql_http server in the same process, with the bytes that were read. Its epoll descriptor is inside the loop of the HTTP/2 server.
- **Upgrade:** when `upgrade` is on, a first request with `Upgrade: h2c`, one `HTTP2-Settings` field and both names in `Connection` gets 101. Then the connection is HTTP/2, and the request is stream 1 (RFC 7540 section 3.2).
- **Graceful shutdown:** an HTTP/2 connection gets `GOAWAY` with the largest stream id and a `PING`. When the `PING` comes back, the server sends `GOAWAY` with the last stream that it took, as h2 does.

RFC 9113 deprecates the upgrade, so it is off by default. Only the first request of a connection can upgrade, and a chunked request cannot.

| `ServerConfig` field | Default | Contents |
| --- | --- | --- |
| `http` | `gql_http.server.ServerConfig()` | The address, the port, the workers, the timeouts and the request limits |
| `h2` | `Config()` | The limits of each HTTP/2 connection |
| `prior_knowledge` | `True` | Whether a connection that starts with the preface gets HTTP/2 |
| `upgrade` | `False` | Whether a first request with `Upgrade: h2c` switches to HTTP/2 |

| Function | Result |
| --- | --- |
| `listen(handler, config)` | A `Server` with one event loop in this process; its `port` is the port it listens on |
| `start_workers(handler, config)` | A gql_http `WorkerPool` of `config.http.workers` forked processes on one port |
| `serve(handler, config)` | Starts the workers and waits until they end |

A `Server` has `poll(timeout_ms)`, `run()`, `begin_shutdown()`, `listen_signals()`, `stopped()` and `close()`, as the gql_http server has. Its `http1` field is the HTTP/1.1 server, which owns the handler.

### Requests and responses

Each whole request becomes a gql_http `Request` in HTTP/1.1 form, so the handler cannot see the difference:

- `:method` and `:path` become the request line. For `CONNECT`, the target is `:authority`.
- `:authority` becomes `host`, and a `host` field is dropped. Without `:authority`, a `host` field stays.
- The `cookie` fields become one field, joined with `; ` (RFC 9113 section 8.2.3).
- `content-length` is the length of the content.

The `ResponseWriter` becomes `HEADERS` and `DATA`. The names are in lowercase. The server adds `date` and `content-length`, and drops `connection`, `keep-alive`, `proxy-connection`, `transfer-encoding` and `upgrade`. A response that the handler streams with `begin_chunked` goes out whole when the handler returns. When the handler raises after `begin_chunked`, the stream gets `RST_STREAM` with `INTERNAL_ERROR`. `close_connection()` begins a graceful shutdown of the connection.

## Transport

A `Transport` is the byte stream that an HTTP/2 connection runs over. `SocketTransport` is a plain socket. A TLS layer, such as `gql_tls`, implements the trait for a TLS connection after ALPN chose `h2`.

```mojo
trait Transport(Deinitable, Movable):
    def read(mut self, data: Pointer[UInt8, MutUntrackedOrigin], size: Int) -> Int: ...
    def write(mut self, data: Pointer[UInt8, ImmUntrackedOrigin], size: Int) -> Int: ...
    def close(mut self): ...
    def fd(self) -> Int: ...
```

| Method | Contract |
| --- | --- |
| `read(data, size)` | Returns the count of bytes read, 0 when the peer closed the stream, `-EAGAIN` when no byte is there now, or another negative error number |
| `write(data, size)` | Returns the count of bytes written, which can be fewer than `size`, `-EAGAIN` when the transport takes none now, or another negative error number |
| `close()` | Closes the transport and its descriptor |
| `fd()` | Returns the descriptor for `poll`, or -1 |

A transport must not block. A TLS transport must give the plaintext bytes that it holds before it returns `-EAGAIN`, because the caller waits on `fd()` only after `-EAGAIN`.

There are two ways to serve a transport:

- **`serve_transport(handler, transport, config, limits, idle_timeout_ms, read_already)`** serves one connection until it ends, and then closes the transport. It waits with `poll` on `fd()`. `read_already` holds bytes that were read already, such as the bytes after the TLS handshake.
- **`ServerSession`** is the same server without I/O, for an event loop. Call `start()` once, and `receive(handler, data)` with each read. Send the bytes of `session.conn.out`, and clear them. Close the transport when `is_done()` is True and `conn.out` is empty.

A client over TLS uses `ClientConnection[T: Transport](transport, config)` in the same way.

## Client

`Client` sends one request and returns the whole `Response`. It has the methods of the gql_http client: `get(url)`, `post(url, content_type, body)`, `endpoint(url)` and `send(endpoint, method, target, headers, body)`. It raises a gql_http `HttpError`.

- **h2c first:** with `prior_knowledge`, the client opens an h2c connection, and keeps one connection per address and port.
- **Fallback:** a server that does not answer the preface with `SETTINGS` speaks HTTP/1.1. With `fallback`, the client sends the request with the gql_http client, and remembers the endpoint for later requests.
- **Retry:** a reused connection can fail before the response. When a `GOAWAY` refused the stream, the request goes again on a new connection. When the transport failed, only an idempotent method goes again.
- **Headers:** the client writes the pseudo-header fields and `content-length`. It drops `host`, `connection`, `keep-alive`, `proxy-connection`, `transfer-encoding` and `upgrade`.

| `ClientConfig` field | Default | Contents |
| --- | --- | --- |
| `http` | `gql_http.client.ClientConfig()` | The timeouts and limits, also of the HTTP/1.1 client |
| `h2` | `Config()` | The limits of each HTTP/2 connection |
| `prior_knowledge` | `True` | Whether the client tries h2c first |
| `fallback` | `True` | Whether a server without HTTP/2 gets HTTP/1.1 |

A `Response` has `status`, `protocol`, `headers`, `header(name)`, `header_count()`, `header_name(index)`, `header_value(index)`, `body()` and `text()`. `protocol` is `Protocol.HTTP_2` or `Protocol.HTTP_1_1`. `speaks_http1(endpoint)` tells whether the client sends HTTP/1.1 to an endpoint.

## Connection

`Connection` is the state machine of one HTTP/2 connection, without I/O. `receive(data)` reads frames, and the bytes to send collect in `out`. A whole request or response becomes a `MESSAGE` event. A stream that ends early becomes a `RESET` event.

- **Streams:** the states of RFC 9113 section 5.1, without the reserved states of push. The connection refuses `PUSH_PROMISE` and sends `SETTINGS_ENABLE_PUSH = 0` as a client.
- **Flow control:** the connection gives each `DATA` frame back to the peer's window at once, at half of the window. Content that waits for a window goes out when a `WINDOW_UPDATE` grows it.
- **Settings:** this endpoint's settings apply when the peer acknowledges them. Until then, the larger of the old and the new receive window applies.
- **Checks:** the connection checks each head as RFC 9113 section 8 tells. A malformed message is a stream error `PROTOCOL_ERROR`.
- **Limits:** a request head over `max_header_list_size` gets 431, and content over `max_body_bytes` gets 413.
- **Floods:** too many `CONTINUATION` frames, empty `DATA` frames or early resets end the connection with `ENHANCE_YOUR_CALM`.

| `Config` field | Default | Contents |
| --- | --- | --- |
| `max_concurrent_streams` | `200` | The most streams that the peer can open at once; -1 for no limit |
| `initial_window_size` | 1 MiB | The receive window of each stream |
| `connection_window_size` | 1 MiB | The receive window of the connection |
| `max_frame_size` | 16 KiB | The largest frame payload that this endpoint takes |
| `max_header_list_size` | 16 KiB | The largest header list |
| `header_table_size` | 4 KiB | The HPACK dynamic table of the decoder |
| `max_body_bytes` | 16 MiB | The largest content of a message |
| `max_remote_resets` | `20` | The most streams that the peer can reset before their response |
| `max_empty_data_frames` | `100` | The most empty `DATA` frames without `END_STREAM` |
| `enable_connect_protocol` | `False` | Whether a server allows the extended `CONNECT` of RFC 8441 |

## HPACK

`Encoder` and `Decoder` are the HPACK coders of h2. `HeaderList` holds fields in one buffer, with a `too_large` flag that the decoder sets when a list passes its limit. The decoder still decodes the rest of the block, so that the dynamic table stays in step. The encoder uses the static table and the dynamic table as h2 does, never indexes a sensitive field, and Huffman codes each literal.

## Errors

`H2Error` has a `kind`, a `reason`, a `stream_id` and a `message`. `Reason` is the error code of RFC 9113 section 7.

| `H2ErrorKind` | Meaning |
| --- | --- |
| `CONNECTION` | This endpoint found a connection error, and sent `GOAWAY` |
| `STREAM` | This endpoint found a stream error, and sent `RST_STREAM` |
| `REMOTE_RESET` | The peer reset the stream |
| `REMOTE_GOAWAY` | The peer's `GOAWAY` refused the stream, so the request can go again |
| `IO` | The transport failed or closed |
| `USAGE` | The caller gave a value that the function does not accept |
| `TIMEOUT` | An operation did not complete before its deadline |

## Differences from upstream

The package ports h2 v0.4.20. These are the differences:

- **Whole messages.** h2 gives a request to the application when its head arrives. Here a message is ready when its stream ends, and its window goes back at once.
- **A gql_http handler.** The application is a gql_http `Handler`, and the request is in HTTP/1.1 form.
- **No push and no priority.** The connection refuses `PUSH_PROMISE`, and reads and ignores `PRIORITY`, as RFC 9113 allows.
- **Rapid reset.** A reset of a stream that has no response yet counts, and a response sets the count to 0.
- **Self-dependency.** h2 resets a `HEADERS` stream that depends on itself before it decodes the block. Here the block is decoded first, so that the HPACK state stays in step.
- **Listener and HTTP/1.1.** h2 serves a connection that its caller accepted. Here the server listens, chooses the protocol, and serves HTTP/1.1 with gql_http.
- **A whole-response client.** `send` waits for the whole response with one deadline, as the gql_http client does. h2 returns a future of the response.

## Tests

The tests are in `tests/gql_http2/`. The suites port the tests of h2 `tests/h2-tests` and `src/hpack`, and each test names the upstream test that it follows.

- **Mock peer.** `_frames.mojo` is the mock of h2-support: it writes frames with its own HPACK encoder and decodes what a connection sends.
- **HPACK.** The suites check the RFC 7541 Appendix C examples, the h2 unit tests and the hpack-test-case corpus. The corpus has no license file, so it is not in the repository. The test reads it from `~/mgql-upstream/hyperium_h2/fixtures/hpack` when that folder is there.
- **Server and client.** The tests use real sockets on the loopback address, with worker processes and scripted peers. `Faults` reaches the error paths.
- **Interop.** `test_interop.mojo` runs `curl --http2-prior-knowledge`, `curl --http2` and `curl --http1.1` against the server. It passes at once when the curl has no HTTP/2.

## Benchmarks

`bench/gql_http2/` has three workloads. The baseline in `bench/baselines/rust-http2` runs hyper 1.12.0 with h2 0.4.20. h2 keeps its HPACK coder private, so the baseline compiles the h2 sources from the cargo registry.

| Workload | Contents |
| --- | --- |
| `http2/hpack-encode` | Encode the header block of a typical GraphQL request with a new encoder |
| `http2/hpack-decode` | Decode that block with a new decoder |
| `http2/roundtrip-small-json` | One server process answers a small GraphQL `POST` over one h2c connection, one stream at a time. The result is nanoseconds per round trip. |

The load generator `bench/gql_http2/_h2load.mojo` drives both servers, so only the server is different.

| Workload | Mojo | hyper and h2 |
| --- | --- | --- |
| `http2/hpack-encode`, ns | 843 | 1,045 |
| `http2/hpack-decode`, ns | 1,018 | 2,053 |
| `http2/roundtrip-small-json`, ns | 73,302 | 80,547 |

The numbers come from one run of `make bench-check PKG=gql_http2` on one machine. They change from machine to machine.

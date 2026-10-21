<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Http

`gql_http` is the HTTP/1.1 transport of the other packages: a server for GraphQL endpoints and a client for subgraph calls. It uses POSIX sockets and epoll through the C library, and it needs only the Mojo standard library. It runs on Linux only, and it has no TLS and no IPv6.

| Module | Contents |
| --- | --- |
| `gql_http.server` | `Handler`, `ResponseWriter`, `Router`, `ServerConfig`, `Server`, `listen`, `serve`, `start_workers`, `WorkerPool`, `format_http_date` |
| `gql_http.client` | `Client`, `ClientConfig`, `Endpoint`, `Response`, `ResponseStream`, `BodyStream` |
| `gql_http.body` | `BodyPoll`, `BodySource`, `BodyPump`, `append_chunk`, `append_last_chunk`, `append_hex` |
| `gql_http.multipart` | `MultipartEncoder`, `MultipartDecoder`, `MultipartPart`, `boundary_of`, `INCREMENTAL_CONTENT_TYPE`, `INCREMENTAL_ACCEPT` |
| `gql_http.parser` | `Request`, `RequestReader`, `parse_request_head`, `parse_response_head`, `ChunkedDecoder`, `Limits`, `ParseState`, `BodyKind` |
| `gql_http.headers` | `Headers`, `parse_media_type`, `MediaType`, `parse_accept`, `accept_quality`, `is_token`, `is_field_value` |
| `gql_http.url` | `Url`, `percent_decode`, `parse_query`, `query_value` |
| `gql_http.status` | `Status`, `Method`, `Version` |
| `gql_http.error` | `HttpError`, `ErrorKind` |
| `gql_http.socket` | `Sys`, `IPv4Address`, `Faults`, `SysCall`, and the Linux constants |
| `gql_http.scan` | The SIMD finders for field ends, targets and bytes |

```mojo
from gql_http.parser import Request
from gql_http.server import Handler, MatchKind, ResponseWriter, Router
from gql_http.server import ServerConfig, serve
from gql_http.status import Method, Status


struct Hello(Handler):
    var router: Router

    def __init__(out self):
        self.router = Router()
        self.router.add(Method.POST, "/graphql", 1)

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        var found = self.router.find(request.method, request.path())
        if found.kind != MatchKind.FOUND:
            self.router.reject(found, response)
            return
        response.send(Status.OK, "application/json", '{"data":{"hello":"world"}}')


def main() raises:
    var config = ServerConfig()
    config.workers = 4
    serve(Hello(), config)
```

## Server

A `Handler` gets each `Request` and fills a `ResponseWriter`. The request and its content are valid until `handle` returns. When `handle` raises before the response goes out, the client gets an empty 500 response.

| Function | Result |
| --- | --- |
| `listen(handler, config)` | A `Server` with one event loop in this process; its `port` is the port it listens on |
| `start_workers(handler, config)` | A `WorkerPool` of `config.workers` forked processes on one port; the call returns at once |
| `serve(handler, config)` | Starts the workers and waits until they end |

A `Server` has `poll(timeout_ms)`, which runs one turn of the loop, and `run()`, which runs until a graceful shutdown ends. `begin_shutdown()` starts a graceful shutdown. `listen_signals()` starts one on `SIGTERM` or `SIGINT`.

Each worker has its own listening socket with `SO_REUSEPORT`, so the kernel spreads the connections over the workers. The project uses no threads. A worker gets `SIGTERM` when its parent process ends.

- **Event loop:** the loop is level-triggered epoll. Each readable connection costs one `recv`, and each response costs one `send`.
- **Pipelining:** the pipelined requests of one read get their responses in one `send`, in order.
- **Back pressure:** a response that does not fit in the socket waits for `EPOLLOUT`. The server does not read the connection until the response has gone out.
- **Graceful shutdown:** the server closes its listening socket and its idle connections. A busy connection gets its response with `Connection: close`. The loop ends when no connection is open, or after `shutdown_timeout_ms`.
- **Close:** when the client can still send, the server first sends its end of the stream. Then it reads until the client closes (RFC 9112 section 9.6). Thus the client gets the response and not a reset.

| `ServerConfig` field | Default | Contents |
| --- | --- | --- |
| `host` | `IPv4Address.ANY` | The local address |
| `port` | `4000` | The port; `0` lets the system choose one |
| `workers` | `1` | The worker processes of `start_workers` and `serve` |
| `backlog` | `1024` | The queue of pending connections of each listening socket |
| `limits` | `Limits()` | The size limits of a request |
| `idle_timeout_ms` | `5000` | How long a connection can be quiet |
| `shutdown_timeout_ms` | `10000` | How long a graceful shutdown waits for busy connections |
| `max_connections` | `100000` | The most open connections of one event loop |
| `max_events` | `512` | The most events of one `epoll_wait` |
| `reuse_port` | `True` | Whether the listening socket sets `SO_REUSEPORT` |

A connection is quiet between requests, while a request arrives, and while the client reads no part of a response. A client that reads a large response slowly keeps its connection open.

### ResponseWriter

The writer starts as an empty 200 response. The handler sets the status, adds fields and writes content. When the handler returns, the server adds `Date`, `Content-Length` and, when the connection closes, `Connection: close`.

| Method | Result |
| --- | --- |
| `set_status(status)` | Sets the status code |
| `add_header(name, value)` | Adds a field; refuses `Content-Length`, `Transfer-Encoding`, `Connection` and `Date` |
| `write(data)`, `write_text(text)` | Appends content |
| `send(status, content_type, body)` | Sets the status, the `Content-Type` and the whole content |
| `close_connection()` | Closes the connection after this response |
| `begin_chunked()` | Starts a stream with chunked transfer coding |
| `write_chunk(data)` | Appends one chunk to the stream |
| `flush()` | Sends what the writer holds now, as far as the socket takes it |
| `hold()` | Keeps the stream open after `handle` returns; call it after `begin_chunked` |
| `connection()` | The connection of the response: the `id` of `poll_body` |

An HTTP/1.0 client gets a stream without chunks, and the connection closes at its end.

### Held responses

A held response streams content after `handle` returns. Use it for content that comes over time, such as SSE events or `multipart/mixed` parts.

1. In `handle`, call `begin_chunked()` and then `hold()`.
2. Keep the state of the stream by `response.connection()`.
3. Implement `poll_body(id, out)`. Append the next bytes to `out`, and return a `BodyPoll`.
4. Implement `body_closed(id)`. The server calls it when the stream ends before `DONE`.

| `BodyPoll` | Meaning |
| --- | --- |
| `READY` | The handler appended bytes, and can have more |
| `PENDING` | The handler has no bytes now; the server polls again on a later turn |
| `DONE` | The content is complete; the server sends the last chunk |
| `ERROR` | The content failed; the server closes the connection without the last chunk |

The server calls `poll_body` first in the turn of `handle`, until it gets no `READY`. Thus the head and the first content go out in one `send`. While a response is held, the loop waits at most `stream_poll_ms` milliseconds, 10 at first. A client that reads no content stops the polls of its stream.

`BodySource` and `BodyPump` do the same work outside of a `Handler`. A `BodyPump` polls a source, frames its chunks and sends them without a block. Over `high_water` bytes that are not sent, it does not poll the source.

### Multipart

`gql_http.multipart` is the `multipart/mixed` format of incremental delivery over HTTP (RFC 2046 section 5.1). The content type is `INCREMENTAL_CONTENT_TYPE`: `multipart/mixed; boundary="-"; deferSpec=20220824`.

- **Encoder:** `MultipartEncoder.part(out, body)` appends one part, with `content-type: application/json; charset=utf-8` at first. `end(out)` appends the close delimiter. The bytes are the bytes of Apollo Server 4.
- **Decoder:** `MultipartDecoder.feed(data)` reads content in parts of any size. `take()` returns the complete parts, and `finish()` raises when the content ends early.
- **Boundary:** `boundary_of(content_type)` reads the boundary of a `Content-Type` value.

### Router

`Router` is a table of routes by method and path. `add(method, path, id)` adds a route. A path is exact, such as `/graphql`, or a prefix and `*`. `find(method, path)` returns a `RouteMatch` for the first route that matches:

- `MatchKind.FOUND`, with the `id` of the route. A `GET` route also matches `HEAD`.
- `MatchKind.METHOD_NOT_ALLOWED`, with the `Allow` value, when routes have the path but not the method.
- `MatchKind.NOT_FOUND`, when no route has the path.

`reject(found, response)` writes the 404 or the 405 response.

## Client

`Client` sends one request and returns the whole `Response`. It keeps a pool of keep-alive connections, by address and port.

`start` and `finish` put several requests in flight at once. Each request in flight has its own connection. The caller must finish each request that it starts.

| Method | Result |
| --- | --- |
| `get(url)` | Sends a `GET` request |
| `post(url, content_type, body)` | Sends a `POST` request with content |
| `endpoint(url)` | Parses and resolves a URL once, for many requests to one service |
| `send(endpoint, method, target, headers, body)` | Sends a request; the client writes `Host` and `Content-Length` |
| `start(endpoint, method, target, headers, body)` | Sends a request and returns a `PendingRequest` before the response |
| `finish(pending)` | Reads the whole response of a `PendingRequest` |
| `stream(pending)` | Reads the head of a response, and returns a `ResponseStream` before the content |
| `read_body(stream, out)` | Appends the next part of a streamed content to `out`; False at the end |
| `close_stream(stream)` | Stops a streamed response before its end, and closes its connection |
| `idle_connections()` | The count of connections in the pool |
| `close_idle()` | Closes the connections in the pool |

- **Deadline:** each request has a deadline, `ClientConfig.timeout_ms`, for the connect, the send and the whole response. The sockets do not block, and each wait is a `poll` that ends at the deadline.
- **Stale connections:** before the client uses a connection from the pool, it makes sure that the server did not close it.
- **Retry:** when a reused connection fails before any byte of the response arrives, the client sends the request again on a new connection. It does this only for an idempotent method, or when the send failed. A `POST` that the server could have received is not sent twice. This is the rule of Go `net/http`.
- **Framing:** the client reads `Content-Length` content, chunked content, and content that ends when the connection closes.

| `ClientConfig` field | Default | Contents |
| --- | --- | --- |
| `connect_timeout_ms` | `5000` | The longest wait for a connection |
| `timeout_ms` | `30000` | The deadline of a whole request |
| `max_idle_per_host` | `64` | The most idle connections per address and port |
| `limits` | 64 MiB of content | The size limits of a response |

A `Response` has `status`, `version`, `reason()`, `header(name)`, `header_count()`, `header_name(index)`, `header_value(index)`, `body()` and `text()`.

## Parser

The parser reads a message in place, and it copies no byte. A `Field` holds four offsets into the message. `ChunkedDecoder` decodes chunked content in place, so the content is one span of the buffer. `RequestReader` reads a stream of pipelined requests, and the server gives it the bytes of each `recv`.

| Function | Result |
| --- | --- |
| `parse_request_head(data, end, limits, request)` | A `ParseResult`: `COMPLETE`, `INCOMPLETE` or `ERROR`, with the size of the head or the status of the error |
| `parse_response_head(data, end, limits, head)` | The same, for a status line and its fields |

The parser is strict. Where RFC 9112 lets a recipient choose, the parser makes the safe choice. A lenient parser in front of a strict one lets an attacker smuggle requests.

- **Lines:** a line ends with CRLF. A bare LF or a bare CR gives 400.
- **Request line:** one SP separates the parts. A target is visible ASCII. Empty lines before a request line are skipped.
- **Versions:** the parser reads `HTTP/1.0` and `HTTP/1.1`, and reads `HTTP/1.2` to `HTTP/1.9` as 1.1. Another major version gives 505.
- **Fields:** an obsolete line fold, white space before a colon, and a control byte in a value give 400.
- **Host:** an HTTP/1.1 request must have exactly one `Host` field, with only the bytes of a host and a port.
- **Content-Length:** the value is digits only. A second field or a list gives 400.
- **Transfer-Encoding:** `Transfer-Encoding` with `Content-Length` gives 400. The parser reads only `chunked`, and another coding gives 501.
- **Chunks:** a chunk size has at most 15 hexadecimal digits. The parser checks chunk extensions and trailer fields, and then drops them.
- **Expect:** `Expect: 100-continue` sets `expect_continue`, and the server sends `100 Continue`. Another expectation gives 417.

| `Limits` field | Default | Error |
| --- | --- | --- |
| `max_head_bytes` | 16 KiB | 431 |
| `max_headers` | 100 | 431 |
| `max_body_bytes` | 16 MiB | 413 |
| `max_chunk_line_bytes` | 4 KiB | 400 |
| `require_host` | `True` | 400 |

A `Request` has `method`, `version`, `content_length`, `chunked`, `keep_alive` and `expect_continue`. Its methods are `target()`, `path()`, `query()`, `header(name)`, `find_header(name)`, `header_count()`, `header_name(index)`, `header_value(index)` and `body()`. A header name matches without regard to case.

## Headers, media types and URLs

- **Headers:** `Headers` holds fields to send in their wire form, so a message copies them in one copy. It has `add`, `set`, `remove`, `find`, `get` and `clear`. `add` refuses a name that is not a token and a value with a control byte.
- **Media types:** `parse_media_type(text)` reads a `Content-Type` value (RFC 9110 section 8.3.1) into a `MediaType`. `essence()` gives `type/subtype` in lowercase, and `parameter(name)` gives one parameter.
- **Accept:** `parse_accept(text)` reads an `Accept` value into `MediaRange` values. `accept_quality(accept, type, subtype)` gives the weight of a media type, times 1000. The most specific range that covers the type gives the weight (RFC 9110 section 12.5.1).
- **URLs:** `Url.parse(text)` reads an absolute URL: `scheme://[userinfo@]host[:port][/path][?query][#fragment]`. The text of each part stays encoded.
- **Query strings:** `parse_query(query)` reads `application/x-www-form-urlencoded` as the WHATWG URL standard tells. `query_value(params, name)` gives the value of the first pair with a name.
- **Percent-decoding:** `percent_decode(text, plus_is_space=False)` decodes `%XX` escapes (RFC 3986 section 2.1).

`Status`, `Method` and `Version` are types with `is_valid`. `Status` has `reason()`, `is_informational()` and `has_body()`. `Method` has `text()`, `is_idempotent()` and `from_bytes(data)`. `Method.OTHER` is a method that the package does not know.

## HttpError

`HttpError` is the error of the socket layer, the server and the client.

| Field | Contents |
| --- | --- |
| `kind: ErrorKind` | What went wrong |
| `message: String` | A description for people |
| `errno: Int` | The system error number of an `OS` or `CONNECT` error, else 0 |

| `ErrorKind` | Meaning |
| --- | --- |
| `OS` | A system call failed |
| `RESOLVE` | A host name did not resolve to an IPv4 address |
| `CONNECT` | The connection to the peer failed |
| `TIMEOUT` | An operation did not complete before its deadline |
| `CLOSED` | The peer closed the connection before the message was complete |
| `PROTOCOL` | The peer sent a message that RFC 9112 does not allow |
| `LIMIT` | A message was larger than a configured limit |
| `USAGE` | The caller gave a value that the function does not accept |

## System calls

`gql_http.socket` is the only module that calls the operating system. Each call goes through `Sys`, and returns its result or the negated error number, such as `-EAGAIN`. A port to macOS replaces only this module.

`Sys.faults` holds a `Faults` plan, which makes one kind of call fail. The plan lets the first `skip` calls of a `SysCall` kind run, and then fails `count` calls with an error number. The tests use it to reach the error paths of the server and the client. `Sys.peek` counts as a `RECV` call.

## Differences from upstream

The package ports no code, so it has no upstream. The behavior follows RFC 9110, RFC 9112 and the GraphQL over HTTP specification. These are the differences from the servers that the benchmarks compare:

- **Strict parsing.** Node.js, Go `net/http` and hyper accept some messages that this parser refuses, such as a bare LF.
- **Percent-decoding.** Unlike the WHATWG parser, `percent_decode` refuses a `%` that two hexadecimal digits do not follow, and a result that is not UTF-8. A server can then answer 400.
- **Processes, not threads.** Each worker is a process with its own event loop.

## Tests

The tests are in `tests/gql_http/`. They use real sockets on the loopback address.

- **Parser.** Each rule of the parser has a test, with valid and invalid messages, whole and one byte at a time.
- **Server and client.** The tests run a server and a client against a scripted peer process. The peer can keep, close, drop or hold a connection, and can pause in a reply.
- **Faults.** For each system call, `Faults` makes the call fail with each error number that the code handles.

## Benchmarks

`bench/gql_http/` has four workloads. The baselines in `bench/baselines/js-http`, `go-http` and `rust-http` run the first two. `rust-http` also runs `http/chunked-16-parts`, and `js-sse` runs meros for `multipart/parse-100-parts`.

| Workload | Contents |
| --- | --- |
| `http/keepalive-small-json` | One server process answers a small GraphQL `POST` with `{"data":{"hello":"world"}}`, over 64 keep-alive connections. The result is nanoseconds per request. |
| `http/parse-request` | The parser reads the head of a typical GraphQL `POST` from a browser. |
| `http/chunked-16-parts` | One server process answers each `POST /stream` with a held response of 16 chunks of `{"data":{"hello":"world"}}`, over 64 keep-alive connections. The result is nanoseconds per request. |
| `multipart/parse-100-parts` | A new `MultipartDecoder` reads a `multipart/mixed` body of 100 incremental payloads, and parses the JSON of each part. |

The load generator `bench/gql_http/_loadgen.mojo` drives every server, so only the server is different. On each workload, `gql_http` is faster than every baseline.

| Workload | Mojo | Node.js | Go | Rust |
| --- | --- | --- | --- | --- |
| `http/keepalive-small-json`, ns per request | 10,471 | 66,046 | 44,072 | 14,781 |
| `http/parse-request`, ns | 222 | 3,010 | 4,441 | 227 |
| `http/chunked-16-parts`, ns per request | 10,103 | | | 25,841 |
| `multipart/parse-100-parts`, ns | 134,982 | 349,263 | | |

The numbers come from one run of `tools/bench.mojo --check` for `gql_http` and `gql_sse` on one machine. They change from machine to machine. The Node.js baseline of `multipart/parse-100-parts` is meros 1.3.2.

The parser looks up the `tchar` and `Host` byte classes in tables of 256 bytes. It finds the end of a target and of a field value with SIMD. It compares the field names of the framing rules 8 bytes at a time. The baselines are Node.js `node:http` and llhttp, Go `net/http`, and hyper on a tokio runtime with one thread, with httparse. The [Benchmarks](Benchmarks) page tells how the project measures speed.

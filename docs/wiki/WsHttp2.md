<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# WsHttp2

`gql_ws_http2` is WebSockets over HTTP/2 (RFC 8441). One HTTP/2 connection carries many WebSockets and requests. Each WebSocket is one stream, opened with an extended `CONNECT`. The frames and `graphql-transport-ws` are those of `gql_ws`, so a `WsHandler` serves WebSockets of HTTP/1.1 and HTTP/2 the same way.

| Module | Contents |
| --- | --- |
| `gql_ws_http2.handshake` | `server_accept`, `response_head`, `reject_head`, `client_head`, `verify_head`, `offered_protocols`, `H2Accepted`, `WEBSOCKET_PROTOCOL` |
| `gql_ws_http2.session` | `WsH2Session`, `Tunnel` |
| `gql_ws_http2.server` | `Server`, `ServerConfig`, `listen` |
| `gql_ws_http2.client` | `H2WebSocket`, `H2TransportClient`, `connect_h2c`, `connect_transport_h2c` |
| `gql_ws_http2.fallback` | `WsAnyClient`, `connect_ws`, `connect_transport` |

```mojo
from gql_ws.transport_client import ClientEvent
from gql_ws_http2.fallback import connect_transport


def main() raises:
    var client = connect_transport("ws://localhost:4000/graphql")
    _ = client.subscribe('{"query":"subscription { greetings }"}')
    var event = ClientEvent()
    if client.next(event, 5000):
        print(event.payload)
    client.close()
```

## Handshake

The client must wait for the SETTINGS of the server. It can send an extended `CONNECT` only when `SETTINGS_ENABLE_CONNECT_PROTOCOL` is 1. The request has `:method CONNECT`, `:protocol websocket`, `:scheme`, `:authority` and `:path`.

- **No key.** RFC 8441 drops `Sec-WebSocket-Key`, `Sec-WebSocket-Accept`, `Upgrade` and `Connection`. The stream is the connection.
- **Version and subprotocol.** `Sec-WebSocket-Version: 13` and `Sec-WebSocket-Protocol` stay as in RFC 6455.
- **Answer.** A 200 opens the WebSocket. Another status is a refusal, and `verify_head` raises `HANDSHAKE` with the status.
- **Errors.** The error texts are those of tungstenite 0.30.0 where the two handshakes agree.

## Server

`WsH2Session` is the server end of one connection, without input or output. `Server` is an h2c event loop with one session per connection.

- **Requests.** A request that is not an extended `CONNECT` goes to the `gql_http` `Handler`.
- **Sockets.** Each WebSocket is a slot in the `Sockets` of `gql_ws`, opened with `attach`. The handler sends with `send_text`, as for HTTP/1.1.
- **Path.** A WebSocket on another path than `ServerConfig.path` gets 404. An empty path takes every path.
- **Refusals.** A refused WebSocket gets its status and `END_STREAM`, then `RST_STREAM` with `NO_ERROR`.
- **Back pressure.** A WebSocket waits while its stream has content that waits for a window.
- **Closing.** After the closing handshake, the server ends its side with `END_STREAM`. A reset is a close without a handshake, with code 1006.
- **Turns.** Each `poll` calls `on_tick`, and then sends what the handler sent.

```mojo
from gql_http.server import Handler
from gql_ws.graphql_ws import GRAPHQL_TRANSPORT_WS_PROTOCOL
from gql_ws.server import WsHandler
from gql_ws_http2.server import ServerConfig, listen


def serve[W: WsHandler, H: Handler](var handler: W, var http: H) raises:
    var config = ServerConfig()
    config.protocols = [GRAPHQL_TRANSPORT_WS_PROTOCOL]
    var server = listen(handler^, http^, config)
    while True:
        _ = server.poll(-1)
```

## Client

`H2WebSocket[T]` is a WebSocket on one stream, over any `Transport` of `gql_http2`. It conforms to the `MessageSocket` trait of `gql_ws`. Thus `TransportClientOf[H2WebSocket[T]]` speaks `graphql-transport-ws` over HTTP/2.

| Function | Result |
| --- | --- |
| `connect_h2c(url, protocols)` | Opens h2c with prior knowledge on a `ws://` URL, and does the handshake |
| `connect_transport_h2c(url)` | Does `connect_h2c`, then sends `connection_init` and waits for the ack |
| `H2WebSocket(transport)` and `handshake(scheme, authority, path, protocols)` | Use a transport that you opened, such as `TlsTransport` of `gql_https2` |

- **TLS.** Open a `TlsTransport` with ALPN `h2`. Give it to `H2WebSocket`, and call `handshake` with the scheme `https`.
- **Reads.** `read(message, timeout_ms)` returns False after the timeout. It raises `CLOSED` after the closing handshake, and `PROTOCOL` for a reset.
- **Sends.** A send waits for the window of the server until `write_timeout_ms`. Then it raises `TIMEOUT`.

## Fallback

`connect_ws` tries HTTP/2 first. It falls back to the HTTP/1.1 Upgrade of `WsClient` in these cases:

- the server does not speak HTTP/2;
- the server does not allow the extended `CONNECT`;
- the server does not answer within `connect_timeout_ms`.

A refusal with a status, such as 404, is the answer of the server. The client does not try again. `uses_http2()` tells which protocol the client chose. HTTP/3 is not in the chain, because [WsHttp3](WsHttp3) has no QUIC driver yet.

## Differences from upstream

No code of an upstream project is ported. The behavior follows RFC 8441 sections 3 to 6.

- **Reset after a response.** A client keeps a whole response when the server resets the stream with `NO_ERROR` after it (RFC 9113 section 8.1). h2 does the same. This change is in `gql_http2`.

## Tests

The tests are in `tests/gql_ws_http2/`. There is no upstream suite. The cases follow the server and client cases of `gql_ws`, on an HTTP/2 stream.

- **Session.** A session and a client `Connection`, in memory.
- **Client.** `H2WebSocket` on a `Loop` transport, whose far end is a session in memory.
- **Server and fallback.** Real sockets on the loopback address, with a server in this process or in a child process. `Faults` makes system calls fail.

## Benchmarks

`bench/gql_ws_http2/` has one workload. The baseline in `bench/baselines/rust-ws_http2` runs the same workload. The load generator `bench/gql_ws_http2/_h2wsload.mojo` drives both servers, so only the server is different.

| Workload | Contents |
| --- | --- |
| `ws-h2/echo-roundtrip` | A server echoes text messages of 64 bytes over 16 h2c connections, with one WebSocket stream each; the result is nanoseconds per round trip |

| Workload | Mojo | Rust |
| --- | --- | --- |
| `ws-h2/echo-roundtrip`, ns | 7,606 | 11,319 |

The numbers come from one run of `make bench-check PKG=gql_ws_http2` on one machine. The Rust baseline is h2 0.4.20 with `enable_connect_protocol` and tungstenite 0.30.0, on a tokio runtime with one thread. The [Benchmarks](Benchmarks) page tells how the project measures speed.

<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Ws

`gql_ws` is WebSocket (RFC 6455) and the GraphQL over WebSocket protocol `graphql-transport-ws`. It has a server and a client of each. One socket carries many operations in both directions. It runs on `gql_http` and `gql_stream`, on Linux only, and it has no TLS. `gql_ws_execution` connects the protocol to `gql_execution`.

| Module | Contents |
| --- | --- |
| `gql_ws.protocol` | `WebSocket`, `Role`, `WsState`, `WsConfig`, `Message`, `MessageKind` |
| `gql_ws.frame` | `OpCode`, `CloseCode`, `FrameHeader`, `HeaderState`, `parse_header`, `write_header`, `apply_mask`, `random_mask` |
| `gql_ws.handshake` | `server_response`, `reject_response`, `client_request`, `verify_response`, `accept_key`, `generate_key`, `is_upgrade` |
| `gql_ws.server` | `Server`, `ServerConfig`, `WsHandler`, `Sockets`, `UpgradeRequired`, `listen` |
| `gql_ws.client` | `WsClient`, `ClientConfig` |
| `gql_ws.graphql_ws` | `MessageType`, `ProtocolMessage`, `parse_message`, the close codes, and the message writers |
| `gql_ws.transport_server` | `TransportServer`, `GraphQLExecutor`, `Operation`, `Acknowledgement`, `TransportOptions` |
| `gql_ws.transport_client` | `TransportClient`, `ClientEvent`, `subscribe_payload`, `generate_id` |
| `gql_ws.utf8` | `Utf8Validator`, `is_utf8` |
| `gql_ws.sha1` | `sha1`, `base64_encode` |
| `gql_ws.error` | `WsError`, `WsErrorKind` |
| `gql_ws_execution.executor` | `GraphQLExecution`, `Hooks`, `DefaultHooks`, `PubSubRoot` |

```mojo
from gql_execution.execute import Resolvers
from gql_schema.build import build_schema
from gql_stream.pubsub import PubSub
from gql_ws.graphql_ws import GRAPHQL_TRANSPORT_WS_PROTOCOL
from gql_ws.server import ServerConfig, UpgradeRequired, listen
from gql_ws.transport_server import TransportServer
from gql_ws_execution.executor import GraphQLExecution, PubSubRoot


def main() raises:
    var pubsub = PubSub()
    var hooks = PubSubRoot(pubsub)
    hooks.add("greetings", "GREETINGS")
    var schema = build_schema(
        "type Query { hello: String } type Subscription { greetings: String }"
    )
    var executor = GraphQLExecution(schema^, Resolvers(), hooks^)
    var config = ServerConfig()
    config.protocols = [GRAPHQL_TRANSPORT_WS_PROTOCOL]
    var server = listen(TransportServer(executor^), UpgradeRequired(), config)
    server.run()
```

## WebSocket

A `WebSocket` is one end of a connection after the handshake. It does no input or output. The caller gives it the bytes of the socket and sends the bytes of its output.

| Method | Result |
| --- | --- |
| `receive(data)` | Adds bytes from the peer |
| `reserve(size)`, `write_pointer()`, `space()`, `commit(count)` | Let the caller read from the socket into the buffer, without a copy |
| `read(message)` | Fills the next message and returns True; returns False when no whole message is in the buffer |
| `send_text(text)`, `send_binary(data)` | Adds a message in one frame |
| `send_fragment(opcode, is_final, data)` | Adds one frame of a fragmented message |
| `ping(data)`, `pong(data)` | Adds a control frame of at most 125 bytes |
| `close(code, reason)` | Starts the closing handshake |
| `pending()`, `output()`, `advance(count)` | Give the output, and drop the bytes that went out |
| `should_close()` | Tells when the caller must close the socket |
| `peer_closed()` | Records the end of the TCP stream; True after a closing handshake |

- **Fragments:** `read` joins the frames of a message. It checks text as UTF-8 frame by frame, so an invalid byte fails the connection at once.
- **Control frames:** a ping gets its pong in the output at once. A close frame gets its reply. A reply to a code that a peer cannot send is 1002 `Protocol violation`.
- **Masking:** a client masks each frame with a new random key. A server refuses an unmasked frame, and a client refuses a masked frame.
- **Failures:** an error of the peer adds a close frame with the code of the error, and the connection ends. The code is 1002 for a protocol error, 1007 for invalid UTF-8, and 1009 for a frame or message that is too large.

| `WsConfig` field | Default | Contents |
| --- | --- | --- |
| `max_message_size` | 64 MiB | The largest message of the peer |
| `max_frame_size` | 16 MiB | The largest frame of the peer; the header alone fails it |
| `max_write_buffer_size` | no limit | The most output that can wait for the peer |
| `accept_unmasked_frames` | `False` | Whether a server reads unmasked frames |

A send that does not fit in `max_write_buffer_size` raises `WRITE_BUFFER_FULL`. That is the back pressure of a slow peer. A pong or a close frame always goes into the output.

## Handshake

`server_response(request, protocols)` checks an Upgrade request and makes the `101` answer. The request must use `GET` and HTTP/1.1. It must have `Connection: upgrade`, `Upgrade: websocket`, `Sec-WebSocket-Version: 13` and a valid `Sec-WebSocket-Key`. The answer has `Sec-WebSocket-Accept`, the base64 of the SHA-1 of the key and the GUID.

The server chooses the first subprotocol of the client that it supports. `reject_response(error)` writes the error answer: 405 for another method, 426 for another version, and 400 for the rest.

`client_request` writes the request of a client, and `verify_response` checks the answer as RFC 6455 section 4.1 tells.

## Server

`Server[W, H]` is one epoll event loop. A request with `Upgrade: websocket` on `ServerConfig.path` becomes a WebSocket. The `gql_http` server of `H` answers any other request in the same loop. `UpgradeRequired` answers each HTTP request with 426.

A `WsHandler` gets these calls:

| Method | When |
| --- | --- |
| `on_open(sockets, id)` | After the handshake |
| `on_message(sockets, id, message)` | For each text or binary message |
| `on_close(sockets, id, code, reason)` | Once, when the socket closes; 1006 when no close frame came |
| `on_tick(sockets)` | On each turn of the loop |
| `fd()` | A descriptor for the loop to watch, or -1 |
| `wait_ms()` | The longest wait of the loop, or -1 |

`Sockets` is the table of open connections. Its methods are `send_text`, `send_binary`, `ping`, `close`, `is_open`, `protocol`, `path` and `pending`. An id stays valid until `on_close`. A connection with output that waits for the peer is not read until the output goes out.

| `ServerConfig` field | Default | Contents |
| --- | --- | --- |
| `http` | `gql_http` defaults | The address, the port, the request limits and `idle_timeout_ms` for the handshake |
| `ws` | `WsConfig()` | The limits of each WebSocket |
| `path` | empty | The WebSocket path; empty takes every path |
| `protocols` | empty | The subprotocols, by preference |
| `close_timeout_ms` | 30000 | How long a close frame waits for its reply |

## Client

`WsClient.connect(url, protocols, config)` connects to a `ws://` URL and does the handshake. `read(message, timeout_ms)` returns the next message, or False after the timeout. A ping gets its pong. After the closing handshake, `read` raises `CLOSED`.

## graphql-transport-ws

`TransportServer[E]` is a `WsHandler` that runs the protocol. It acknowledges `connection_init`, answers `ping`, and gives each `subscribe` to a `GraphQLExecutor`.

| `Operation` | Messages |
| --- | --- |
| `Operation.result(json)` | One `next`, then `complete` |
| `Operation.errors(json)` | One `error` |
| `Operation.of_stream(stream)` | A `next` for each event; `complete` at the end; `error` for a failure |

The streams run in a `gql_stream` `EventLoop`, and the server watches its descriptor. A published event wakes the loop. A `complete` from the client cancels its stream. A close cancels each stream of the socket.

| Code | Reason | Cause |
| --- | --- | --- |
| 4400 | `Invalid message received` | A message that `parse_message` refuses |
| 4401 | `Unauthorized` | A `subscribe` before the acknowledgement |
| 4403 | `Forbidden` | The executor refuses the connection |
| 4406 | `Subprotocol not acceptable` | The client did not offer `graphql-transport-ws` |
| 4408 | `Connection initialisation timeout` | No `connection_init` within `connection_init_wait_timeout_ms`, 3000 at first |
| 4409 | `Subscriber for <id> already exists` | An id that is in use |
| 4429 | `Too many initialisation requests` | A second `connection_init` |
| 4500 | The error text, or `Internal server error` with `is_prod` | The executor raises |
| 1013 | `Write buffer full` | A `next` without room in the output |

`parse_message` checks each message as graphql-ws `validateMessage` does, with the same error texts.

`TransportClient.connect(url, connection_params, ack_timeout_ms)` sends `connection_init` and waits for `connection_ack`. `subscribe(payload)` returns the id of a new operation. `next(event, timeout_ms)` returns the next `next`, `error` or `complete`. `complete(id)` stops an operation. A first message that is not `connection_ack`, or an invalid message, closes with 4004. No ack in time closes with 4504.

## Execution

`GraphQLExecution[K](schema, resolvers, hooks)` is the executor on `gql_execution`. It parses the query and validates it. Then it runs `execute` for a query or a mutation, and `subscribe` for a subscription.

- **Syntax errors** close the socket with 4500 and the error text.
- **Validation errors** are one `error` message.
- **No operation** for the operation name is one `error`: `Unable to identify operation`.
- **Hooks:** `Hooks` holds `on_connect`, `root` and `on_close`. Mojo has no closures, so a subscription finds its source stream in the root value. `PubSubRoot` gives each root field a new stream of a `PubSub` trigger.

## Differences from upstream

The WebSocket layer ports tungstenite 0.30.0. The protocol ports graphql-ws 6.4.1.

- **Failures.** The endpoint sends the close frame of an error itself, as the Node `ws` receiver does. tungstenite returns the error and sends nothing.
- **Closed connections.** `read` returns False after the closing handshake, and `should_close` tells the caller to close. tungstenite raises `ConnectionClosed`.
- **Error answers.** `reject_response` writes the error answer of the handshake, as `ws` does. tungstenite leaves it to its caller.
- **Bytes after the request** are the first frames of the client, as in `ws`. tungstenite refuses them.
- **The header parser** refuses a 64-bit length with the top bit set, which RFC 6455 forbids.
- **Executor.** The hooks of graphql-ws are one `GraphQLExecutor`, and execution is synchronous.
- **Back pressure.** A `next` without room closes the socket with 1013. graphql-ws buffers without a limit.
- **Keep-alive.** The client keeps a connection alive with protocol pings. The `ws` adapter of graphql-ws pings each socket.
- **Client.** `TransportClient` is not lazy and does not retry. Results come from `next`, not through sinks.
- **Result order.** A `next` payload has `errors` before `data`, as graphql-js writes a result.

## Tests

The tests are in `tests/gql_ws/` and `tests/gql_ws_execution/`. The Autobahn testsuite needs Docker or Python 2, so its cases of sections 1 to 7 are tests here.

- **Frames and protocol.** The tests of tungstenite: frames, masking, fragments, limits, the closing handshake, and invalid UTF-8.
- **Handshake.** The key examples of RFC 6455, the invalid keys of tungstenite, and each refusal.
- **Server and client.** Real sockets on the loopback address, with a server in this process or in a child process. `Faults` makes system calls fail.
- **graphql-transport-ws.** The cases of graphql-ws `common.test.ts`, `server.test.ts`, `use.test.ts` and `client.test.ts`, by name.

## Benchmarks

`bench/gql_ws/` has four workloads. The baselines in `bench/baselines/rust-ws` and `js-ws` run the same workloads. The load generator `bench/gql_ws/_wsload.mojo` drives every server, so only the server is different.

| Workload | Contents |
| --- | --- |
| `ws/frame-parse` | A server reads a masked text frame of 1 KiB: unmask, check UTF-8, and return the message |
| `ws/frame-write` | A server writes a text message of 1 KiB as a frame |
| `ws/echo-roundtrip` | A server echoes text messages of 64 bytes over 16 connections; the result is nanoseconds per round trip |
| `graphql-ws/subscribe-1000-next` | Each subscription gets 1000 events of a `PubSub`; each event is executed and sent as a `next`; the result is nanoseconds per `next` |

| Workload | Mojo | Rust | Node.js |
| --- | --- | --- | --- |
| `ws/frame-parse`, ns | 79 | 741 | 1,622 |
| `ws/frame-write`, ns | 37 | 59 | 309 |
| `ws/echo-roundtrip`, ns | 7,443 | 10,769 | 24,189 |
| `graphql-ws/subscribe-1000-next`, ns | 2,001 | | 37,737 |

The numbers come from one run of `make bench-check PKG=gql_ws` on one machine. The Rust baselines are tungstenite and tokio-tungstenite on a tokio runtime with one thread. The Node.js baselines are `ws` 8 and graphql-ws 6 with graphql-js 16 and graphql-subscriptions 3. The [Benchmarks](Benchmarks) page tells how the project measures speed.

<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# WsHttp3

`gql_ws_http3` is WebSockets over HTTP/3 (RFC 9220), on a real QUIC connection. Each WebSocket is one HTTP/3 request stream, opened with an extended `CONNECT`. The frames and `graphql-transport-ws` are those of `gql_ws`, so a `WsHandler` serves WebSockets of HTTP/1.1, HTTP/2 and HTTP/3 the same way.

| Module | Contents |
| --- | --- |
| `gql_ws_http3.handshake` | `control_preface`, `allows_extended_connect`, `check_connect`, `is_extended_connect`, `to_header_list`, `to_field_list` |
| `gql_ws_http3.tunnel` | `H3Tunnel` |
| `gql_ws_http3.server` | `Server`, `ServerConfig`, `H3WsTunnel`, `listen_ws_h3` |
| `gql_ws_http3.client` | `H3WebSocket`, `H3TransportClient`, `connect_h3`, `connect_transport_h3`, `ws_error` |
| `gql_ws_http3.fallback` | `WsH3AnyClient`, `connect_any`, `connect_any_transport`, `connect_h2_tls` |

```mojo
from gql_ws.transport_client import ClientEvent
from gql_ws_http3.fallback import connect_any_transport


def main() raises:
    var client = connect_any_transport("wss://localhost:4433/graphql")
    _ = client.subscribe('{"query":"subscription { greetings }"}')
    var event = ClientEvent()
    if client.next(event, 5000):
        print(event.payload)
    client.close()
```

## Handshake

RFC 9220 uses the fields of RFC 8441. `to_header_list` and `to_field_list` let the checks of [WsHttp2](WsHttp2) serve HTTP/3 too.

- **Setting.** `control_preface` starts a control stream whose SETTINGS have `SETTINGS_ENABLE_CONNECT_PROTOCOL = 1`. `allows_extended_connect` reads the SETTINGS of the peer. The default is off, as in hyperium/h3.
- **Checks.** `check_connect` raises `H3_MESSAGE_ERROR` when the server did not send the setting. It also raises it for `:protocol` with another method than `CONNECT`, and for a missing `:scheme`, `:path` or `:authority`.

## Tunnel

`H3Tunnel` joins the `MessageReader` of `gql_http3` and the `WebSocket` of `gql_ws`, without input or output. The server and the client below drive it. You can drive it with your own QUIC loop: give it the bytes of the stream, and send its `out`.

| Method | Result |
| --- | --- |
| `request(encoder, scheme, authority, path, protocols)` | Writes the HEADERS of the extended `CONNECT`, on a client |
| `receive(data, decoder)` | Reads bytes of the stream, and gives the content to an open WebSocket |
| `has_head()` | Tells when the HEADERS of the peer arrived |
| `verify(protocols)` | Checks the answer, and opens the WebSocket, on a client |
| `accept(encoder, protocols, path, enabled)` | Checks the request, writes the answer, and opens the WebSocket, on a server |
| `flush()` | Moves the output of the WebSocket into DATA frames |

- **Closing.** The end of the stream (FIN) is the end of the TCP connection of RFC 6455. The driver calls `ws.peer_closed()` then.

## Server

`Server` runs the `H3Server` of [Http3](Http3) with `enable_connect`. Each extended `CONNECT` becomes a tunnel event, and opens a WebSocket in one `Sockets` of `gql_ws`. Each other request goes to the `gql_http` `Handler`.

- **Path.** A WebSocket on another path than `ServerConfig.path` gets 404, and the stream ends. An empty path takes every path.
- **Refusals.** A WebSocket that `server_accept` refuses gets its status, such as 400 or 426. A malformed extended `CONNECT` is reset with `H3_MESSAGE_ERROR`.
- **Back pressure.** A WebSocket waits while its stream has content that waits for credit.
- **Closing.** After the closing handshake, the server ends its side of the stream (FIN). A FIN of the peer ends the WebSocket. A reset, or the end of the QUIC connection, is a close without a handshake, with code 1006.
- **Turns.** Each `poll` runs the QUIC loop, gives the tunnel events to the WebSockets, calls `on_tick`, and sends the output of every WebSocket. `wait_ms` of the handler limits the wait.

```mojo
from gql_http.server import Handler
from gql_http3.quic import Quic
from gql_tls.openssl import OpenSsl
from gql_ws.graphql_ws import GRAPHQL_TRANSPORT_WS_PROTOCOL
from gql_ws.server import WsHandler
from gql_ws_http3.server import ServerConfig, listen_ws_h3


def serve[W: WsHandler, H: Handler](var handler: W, var http: H) raises:
    var config = ServerConfig()
    config.protocols = [GRAPHQL_TRANSPORT_WS_PROTOCOL]
    var server = listen_ws_h3(
        handler^, http^, "cert.pem", "key.pem", config, Quic(OpenSsl())
    )
    while True:
        _ = server.poll(-1)
```

## Client

`H3WebSocket` is a WebSocket on one stream of an `H3Client`. It conforms to the `MessageSocket` trait of `gql_ws`. Thus `H3TransportClient` speaks `graphql-transport-ws` over HTTP/3.

| Function | Result |
| --- | --- |
| `connect_h3(client, url, protocols, config)` | Opens the QUIC connection of `client` to a `wss://` URL, and does the handshake |
| `connect_transport_h3(client, url)` | Does `connect_h3`, then sends `connection_init` and waits for the ack |

- **Settings.** `connect_h3` waits for the SETTINGS of the server. It raises `HANDSHAKE` when the server does not send `SETTINGS_ENABLE_CONNECT_PROTOCOL = 1`.
- **Timeouts.** `connect_timeout_ms` limits the QUIC handshake and the extended `CONNECT`. `write_timeout_ms` limits the wait for the SETTINGS and for credit.
- **Reads.** `read(message, timeout_ms)` returns False after the timeout. It raises `CLOSED` after the closing handshake, and `PROTOCOL` for a reset or an end without a handshake.
- **QPACK.** The tunnel uses QPACK coders with a table of capacity 0, as the connection does.

## Fallback

`connect_any` chooses by the scheme of the URL:

1. `wss://`: HTTP/3. The QUIC handshake and the wait for the SETTINGS have the short limit `h3_timeout_ms`, because a network that blocks UDP drops the packets silently.
2. `wss://`, when HTTP/3 fails: `connect_h2_tls`, the extended `CONNECT` of RFC 8441 on HTTP/2 over TLS, with ALPN `h2`.
3. `ws://`: `connect_ws` of [WsHttp2](WsHttp2), which tries h2c and then the HTTP/1.1 Upgrade.

The client tries HTTP/2 over TLS when HTTP/3 times out, when the connection fails, or when the server does not allow the extended `CONNECT`. A refusal with a status, such as 404, is the answer of the server. The client does not try again. `version()` tells which protocol the client chose: `h3`, `h2`, `h2c` or `http/1.1`.

- **No downgrade.** The client never goes from `wss://` to a connection without TLS. RFC 9220 needs TLS, so a `ws://` URL does not try HTTP/3.
- **HTTPS/1.1.** A `wss://` server that does not choose `h2` fails with `HANDSHAKE`, because `gql_ws` has no WebSocket over HTTPS/1.1.

## Differences from upstream

The settings and the `:protocol` rules port hyperium/h3 h3-v0.0.8 `h3/src/config.rs` and `h3/src/proto/headers.rs`. The server, the client and the fallback port no code.

- **`:protocol` without `CONNECT`.** h3 drops the field from such a request. Here the request is malformed, as RFC 9220 section 3 and RFC 8441 section 4 tell.
- **The handler source.** The `fd` of a `WsHandler` does not wake the loop of `Server`, because the loop waits on its UDP socket only. Use `wait_ms`.

## Tests

The tests are in `tests/gql_ws_http3/`. There is no upstream suite.

- **Handshake and tunnel.** The settings cases follow `h3/src/config.rs`. The tunnel cases join a client tunnel and a server tunnel in memory.
- **Server.** `Rig` runs a `Server` and a raw QUIC client in one thread, on the loopback address.
- **Client and fallback.** Real QUIC and TCP on the loopback address, with the servers in child processes. The fallback cases use an HTTP/3 server and servers that fail the tunnel. They also use a TLS server with WebSockets on HTTP/2, and the h2c and HTTP/1.1 servers.

## Benchmarks

`gql_ws_http3` has no benchmark. The only HTTP/3 baseline of the project, hyperium/h3 0.0.8, cannot open a WebSocket. Its `ext::Protocol` knows only `webtransport` and `connect-udp` (`h3/src/ext.rs`). The header parser turns `:protocol websocket` into an invalid value, so the server refuses the request (`h3/src/proto/headers.rs`). A baseline with a patched h3 is not the upstream. The QUIC and the HTTP/3 paths have their benchmarks in [Http3](Http3).

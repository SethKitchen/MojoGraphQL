<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# WsHttp3

`gql_ws_http3` is the protocol part of WebSockets over HTTP/3 (RFC 9220). It has the setting `SETTINGS_ENABLE_CONNECT_PROTOCOL`, the checks of the extended `CONNECT`, and a WebSocket on one HTTP/3 request stream. It does no input or output. The QUIC event loops of `gql_http3` do not route an extended `CONNECT` to a WebSocket yet.

| Module | Contents |
| --- | --- |
| `gql_ws_http3.handshake` | `control_preface`, `allows_extended_connect`, `check_connect`, `is_extended_connect`, `to_header_list`, `to_field_list` |
| `gql_ws_http3.tunnel` | `H3Tunnel` |

## Handshake

RFC 9220 uses the fields of RFC 8441. `to_header_list` and `to_field_list` let the checks of [WsHttp2](WsHttp2) serve HTTP/3 too.

- **Setting.** `control_preface` starts a control stream whose SETTINGS have `SETTINGS_ENABLE_CONNECT_PROTOCOL = 1`. `allows_extended_connect` reads the SETTINGS of the peer. The default is off, as in hyperium/h3.
- **Checks.** `check_connect` raises `H3_MESSAGE_ERROR` when the server did not send the setting. It also raises it for `:protocol` with another method than `CONNECT`, and for a missing `:scheme`, `:path` or `:authority`.

## Tunnel

`H3Tunnel` joins the `MessageReader` of `gql_http3` and the `WebSocket` of `gql_ws`. A QUIC driver gives it the bytes of the stream, and sends its `out`.

| Method | Result |
| --- | --- |
| `request(encoder, scheme, authority, path, protocols)` | Writes the HEADERS of the extended `CONNECT`, on a client |
| `receive(data, decoder)` | Reads bytes of the stream, and gives the content to an open WebSocket |
| `has_head()` | Tells when the HEADERS of the peer arrived |
| `verify(protocols)` | Checks the answer, and opens the WebSocket, on a client |
| `accept(encoder, protocols, path, enabled)` | Checks the request, writes the answer, and opens the WebSocket, on a server |
| `flush()` | Moves the output of the WebSocket into DATA frames |

- **Refusals.** `accept` returns False for a refusal. Then `out` holds the answer with its status, and the driver ends the stream.
- **Malformed requests.** `accept` raises the error of `check_connect`. Then the driver resets the stream with `H3_MESSAGE_ERROR`.
- **Closing.** The end of the stream (FIN) is the end of the TCP connection of RFC 6455. The driver calls `ws.peer_closed()` then.

## What is not done

These parts need changes to the QUIC event loops of `gql_http3`:

- `H3Server` does not send `SETTINGS_ENABLE_CONNECT_PROTOCOL`, and it refuses `CONNECT`.
- `H3Server` reads each request stream until its end, so it cannot give a tunnel its bytes as they arrive.
- The client of `gql_http3` has no stream that stays open for a tunnel.
- `connect_ws` of [WsHttp2](WsHttp2) does not try HTTP/3.

## Differences from upstream

The settings and the `:protocol` rules port hyperium/h3 h3-v0.0.8 `h3/src/config.rs` and `h3/src/proto/headers.rs`.

- **`:protocol` without `CONNECT`.** h3 drops the field from such a request. Here the request is malformed, as RFC 9220 section 3 and RFC 8441 section 4 tell.

## Tests

The tests are in `tests/gql_ws_http3/`. The settings cases follow `h3/src/config.rs`. The tunnel cases join a client tunnel and a server tunnel in memory, each with its QPACK coder.

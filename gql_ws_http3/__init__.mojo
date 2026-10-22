# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""WebSockets over HTTP/3 (RFC 9220): `gql_ws` on the request streams of
`gql_http3`, over a real QUIC connection.

`handshake` has `SETTINGS_ENABLE_CONNECT_PROTOCOL` and the checks of the
extended `CONNECT`. `tunnel` is a WebSocket on one request stream, without
I/O. `server` serves WebSockets and requests on the QUIC loop of
`gql_http3`. `client` connects to a `wss://` URL over HTTP/3, and speaks
`graphql-transport-ws`. `fallback` tries HTTP/3, then HTTP/2 over TLS,
and gives a `ws://` URL to `connect_ws` of `gql_ws_http2`.
"""

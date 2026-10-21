# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""WebSockets over HTTP/3 (RFC 9220): `gql_ws` on the request streams of
`gql_http3`, without I/O.

`handshake` has `SETTINGS_ENABLE_CONNECT_PROTOCOL` and the checks of the
extended `CONNECT`. `tunnel` is a WebSocket on one request stream. The
QUIC event loops of `gql_http3` do not route an extended `CONNECT` to a
tunnel yet: a driver gives the bytes of the stream to `H3Tunnel`.
"""

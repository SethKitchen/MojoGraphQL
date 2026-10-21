# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""WebSockets over HTTP/2 (RFC 8441): `gql_ws` on the tunnel streams of
`gql_http2`.

The package joins `gql_ws` and `gql_http2`, so that neither imports the
other. `handshake` is the extended `CONNECT` with `:protocol websocket`,
`session` carries WebSockets and requests on one HTTP/2 connection without
I/O, `server` is an h2c event loop, and `client` is a WebSocket on an
HTTP/2 stream over any `gql_http2` `Transport`, with TLS too.
"""

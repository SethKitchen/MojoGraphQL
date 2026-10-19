# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""HTTP/2 over TLS (RFC 9113 section 3.2), with ALPN `h2`.

The package joins `gql_tls` and `gql_http2`, so that neither imports the
other. `transport` is a `gql_http2` `Transport` over a TLS stream, `server`
serves `h2` and HTTP/1.1 on one TLS port, and `client` sends requests with
`h2` when ALPN chooses it and with HTTPS/1.1 when it does not.
"""

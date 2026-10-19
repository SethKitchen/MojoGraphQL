# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""HTTP/3 (RFC 9114) and QPACK (RFC 9204).

The pure-Mojo layers are `varint` (QUIC integers), `huffman` (the code of
RFC 7541), the QPACK field coder in `qpack` and its helper modules, and
the frames of `frame`. `error` holds the error codes and `H3Error`.

Over them, `quic` binds the QUIC API of the system OpenSSL 3.5, `message`
maps HTTP/3 messages to and from HTTP/1.1, `server` serves a `gql_http`
handler over HTTP/3, `client` sends requests, `alt_svc` announces and
remembers HTTP/3 ports, and `fallback` chooses HTTP/3, HTTP/2 over TLS,
HTTPS/1.1, h2c or HTTP/1.1.
"""

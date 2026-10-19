# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""QUIC (RFC 9000), its TLS handshake (RFC 9001) and its loss recovery
(RFC 9002), in Mojo.

The wire layers are `varint`, `cid`, `range_set`, `frame`, `packet` and
`transport_params`. `error` holds the transport error codes.

Over them, `crypto` binds the AEAD, header protection and HKDF of
libcrypto, `tls` drives the handshake of libssl through its third-party
QUIC API, and `connection` and `endpoint` are the sans-I/O state
machines. `udp` sends and receives datagrams in batches, and `driver`
joins them into the poll loop that `gql_http3` uses.
"""

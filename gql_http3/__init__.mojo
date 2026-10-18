# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""HTTP/3 (RFC 9114) and QPACK (RFC 9204).

The pure-Mojo layers are `varint` (QUIC integers), `huffman` (the code of
RFC 7541), the QPACK field coder in `qpack` and its helper modules, and
the frames of `frame`. `error` holds the error codes and `H3Error`.
"""

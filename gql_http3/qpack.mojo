# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""QPACK (RFC 9204): the field compression of HTTP/3.

This module gathers the QPACK API in one place:

- `FieldList`: header fields in one byte buffer (`qpack_field`).
- `QpackEncoder`: writes field sections and encoder stream instructions
  (`qpack_encoder`).
- `QpackDecoder`: reads field sections and encoder stream instructions,
  and writes the decoder stream (`qpack_decoder`).

The other modules are the parts: `qpack_prefix` (prefixed integers and
strings), `qpack_static` (the static table), `qpack_vas` and
`qpack_table` (the dynamic table), and `qpack_block` (the wire forms).

This module ports `h3/src/qpack/mod.rs` of hyperium/h3 h3-v0.0.8
(22c1aa3), MIT.

Differences from upstream: upstream's `encode_stateless` and
`decode_stateless` are an encoder and a decoder of capacity 0.
"""

from gql_http3.qpack_decoder import NO_LIMIT, QpackDecoder
from gql_http3.qpack_encoder import QpackEncoder, encode_static_field
from gql_http3.qpack_field import ENTRY_OVERHEAD, FieldList, field_size

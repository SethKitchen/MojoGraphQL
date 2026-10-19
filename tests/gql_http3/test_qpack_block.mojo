# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_http3.qpack_block`.

Upstream: `h3/src/qpack/block.rs` (`indexed_static`, `indexed_dynamic`,
`indexed_with_postbase`, `literal_with_name_ref`,
`literal_with_post_base_name_ref`, `literal`, `header_prefix`,
`header_prefix_table_size_0`, `base_index_too_small`) and
`h3/src/qpack/stream.rs` (`insert_with_name_ref`, `insert_without_name_ref`,
`insert_duplicate`, `dynamic_table_size_update`, `insert_count_increment`,
`header_ack`, `stream_cancel`) of hyperium/h3 h3-v0.0.8. Upstream decodes
each representation with its own type; here the bytes are checked, and the
kinds are read back from the first byte.
"""

from gql_http3.error import H3ErrorCode
from gql_http3.qpack_block import (
    DecoderInstructionKind,
    EncoderInstructionKind,
    FieldLineKind,
    HeaderPrefix,
    decode_header_prefix,
    to_index,
    write_duplicate,
    write_indexed_dynamic,
    write_indexed_post_base,
    write_indexed_static,
    write_insert_count_increment,
    write_insert_dynamic_name,
    write_insert_literal,
    write_insert_static_name,
    write_literal,
    write_literal_dynamic_name,
    write_literal_post_base_name,
    write_literal_static_name,
    write_section_ack,
    write_set_capacity,
    write_stream_cancel,
)
from gql_http3.qpack_prefix import decode_prefix_int, encode_prefix_int
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime TABLE_SIZE = 4096


def _b(text: StaticString) -> Span[UInt8, ImmStaticOrigin]:
    return text.as_bytes()


def _int(size: Int, data: List[UInt8]) raises -> Tuple[Int, Int]:
    var read = decode_prefix_int(size, Span(data), 0)
    return (Int(read.flags), Int(read.value))


def test_indexed() raises:
    var out = List[UInt8]()
    write_indexed_static(42, out)
    assert_true(FieldLineKind.of(out[0]) == FieldLineKind.INDEXED)
    assert_equal(_int(6, out)[0], 0b11)
    assert_equal(_int(6, out)[1], 42)
    out.clear()
    write_indexed_dynamic(42, out)
    assert_true(FieldLineKind.of(out[0]) == FieldLineKind.INDEXED)
    assert_equal(_int(6, out)[0], 0b10)
    out.clear()
    write_indexed_post_base(42, out)
    assert_true(FieldLineKind.of(out[0]) == FieldLineKind.INDEXED_POST_BASE)
    assert_equal(_int(4, out)[0], 0b0001)
    assert_equal(_int(4, out)[1], 42)


def test_literals() raises:
    var out = List[UInt8]()
    write_literal_static_name(42, _b("foo"), out)
    assert_true(FieldLineKind.of(out[0]) == FieldLineKind.LITERAL_NAME_REF)
    assert_equal(_int(4, out)[0], 0b0101)
    out.clear()
    write_literal_dynamic_name(42, _b("foo"), out)
    assert_equal(_int(4, out)[0], 0b0100)
    out.clear()
    write_literal_post_base_name(42, _b("foo"), out)
    var kind = FieldLineKind.of(out[0])
    assert_true(kind == FieldLineKind.LITERAL_POST_BASE_NAME_REF)
    assert_equal(_int(3, out)[1], 42)
    out.clear()
    write_literal(_b("foo"), _b("bar"), out)
    assert_true(FieldLineKind.of(out[0]) == FieldLineKind.LITERAL)
    # "foo" is 2 bytes Huffman coded: 001, N 0, H 1, length 2.
    var expected = 0x2A
    assert_equal(Int(out[0]), expected)


def test_kinds() raises:
    assert_true(FieldLineKind.LITERAL.is_valid())
    assert_false(FieldLineKind(5).is_valid())
    assert_equal(String(FieldLineKind.LITERAL), "field line kind 4")
    assert_true(EncoderInstructionKind.DUPLICATE.is_valid())
    assert_false(EncoderInstructionKind(4).is_valid())
    assert_equal(String(EncoderInstructionKind(1)), "encoder instruction 1")
    assert_true(DecoderInstructionKind.SECTION_ACK.is_valid())
    assert_false(DecoderInstructionKind(3).is_valid())
    assert_equal(String(DecoderInstructionKind(2)), "decoder instruction 2")


def test_encoder_instructions() raises:
    var out = List[UInt8]()
    write_insert_static_name(0, _b("value"), out)
    var kind = EncoderInstructionKind.of(out[0])
    assert_true(kind == EncoderInstructionKind.INSERT_NAME_REF)
    assert_equal(_int(6, out)[0], 0b11)
    out.clear()
    write_insert_dynamic_name(3, _b("value"), out)
    assert_equal(_int(6, out)[0], 0b10)
    out.clear()
    write_insert_literal(_b("name"), _b("value"), out)
    kind = EncoderInstructionKind.of(out[0])
    assert_true(kind == EncoderInstructionKind.INSERT_LITERAL)
    out.clear()
    write_duplicate(42, out)
    kind = EncoderInstructionKind.of(out[0])
    assert_true(kind == EncoderInstructionKind.DUPLICATE)
    assert_equal(_int(5, out)[1], 42)
    out.clear()
    write_set_capacity(42, out)
    kind = EncoderInstructionKind.of(out[0])
    assert_true(kind == EncoderInstructionKind.SET_CAPACITY)
    assert_equal(_int(5, out)[0], 0b001)
    assert_equal(_int(5, out)[1], 42)


def test_decoder_instructions() raises:
    var out = List[UInt8]()
    write_insert_count_increment(42, out)
    var kind = DecoderInstructionKind.of(out[0])
    assert_true(kind == DecoderInstructionKind.INSERT_COUNT_INCREMENT)
    assert_equal(_int(6, out)[1], 42)
    out.clear()
    write_section_ack(42, out)
    kind = DecoderInstructionKind.of(out[0])
    assert_true(kind == DecoderInstructionKind.SECTION_ACK)
    assert_equal(_int(7, out)[1], 42)
    out.clear()
    write_stream_cancel(42, out)
    kind = DecoderInstructionKind.of(out[0])
    assert_true(kind == DecoderInstructionKind.STREAM_CANCEL)
    assert_equal(_int(6, out)[0], 0b01)


def _get_error(prefix: HeaderPrefix, total: Int, size: Int) raises -> String:
    try:
        _ = prefix.get(total, size)
    except e:
        assert_true(e.code == H3ErrorCode.QPACK_DECOMPRESSION_FAILED)
        return e.message.copy()
    return "no error"


def test_header_prefix() raises:
    var prefix = HeaderPrefix.new(10, 5, 12, TABLE_SIZE)
    var buf = List[UInt8]()
    prefix.encode(buf)
    var decoded = HeaderPrefix(0, False, 0)
    assert_equal(decode_header_prefix(Span(buf), decoded), len(buf))
    assert_true(decoded == prefix)
    var counts = decoded.get(13, 3332)
    assert_equal(counts[0], 10)
    assert_equal(counts[1], 5)
    assert_equal(String(prefix), "prefix 11 True 4")
    # A positive delta.
    prefix = HeaderPrefix.new(4, 6, 6, TABLE_SIZE)
    counts = prefix.get(6, TABLE_SIZE)
    assert_equal(counts[0], 4)
    assert_equal(counts[1], 6)


def test_header_prefix_table_size_0() raises:
    var prefix = HeaderPrefix.new(10, 5, 12, 0)
    assert_true(prefix == HeaderPrefix(0, False, 0))
    var counts = prefix.get(1, 0)
    assert_equal(counts[0], 0)
    assert_equal(HeaderPrefix.new(0, 5, 12, TABLE_SIZE).encoded_insert_count, 0)


def test_base_index_too_small() raises:
    var buf = List[UInt8]()
    encode_prefix_int(8, 0, UInt64(2 % (2 * TABLE_SIZE // 32) + 1), buf)
    encode_prefix_int(7, 1, 2, buf)
    var prefix = HeaderPrefix(0, False, 0)
    _ = decode_header_prefix(Span(buf), prefix)
    assert_equal(_get_error(prefix, 2, TABLE_SIZE), "invalid base -1")


def test_insert_count_wraps() raises:
    # RFC 9204 section 4.5.1.1: 2 * MaxEntries is 256 for 4096 bytes.
    var prefix = HeaderPrefix.new(300, 300, 300, TABLE_SIZE)
    assert_equal(prefix.encoded_insert_count, 300 % 256 + 1)
    assert_equal(prefix.get(300, TABLE_SIZE)[0], 300)
    assert_equal(prefix.get(250, TABLE_SIZE)[0], 300)
    # Encoded 255: 254 or 510, whichever is within 128 of the insert
    # count.
    var back = HeaderPrefix(255, False, 0)
    assert_equal(back.get(400, TABLE_SIZE)[0], 510)
    assert_equal(back.get(200, TABLE_SIZE)[0], 254)
    assert_equal(back.get(500, TABLE_SIZE)[0], 510)


def test_invalid_insert_count() raises:
    var message = "invalid encoded insert count"
    # Above 2 * MaxEntries.
    assert_equal(
        _get_error(HeaderPrefix(257, False, 0), 0, TABLE_SIZE), message
    )
    # No table at all.
    assert_equal(_get_error(HeaderPrefix(1, False, 0), 0, 0), message)
    # The count wraps below 1.
    assert_equal(
        _get_error(HeaderPrefix(200, False, 0), 0, TABLE_SIZE), message
    )
    # The decoded count is 0: encoded 1 means 256 after 300 inserts.
    assert_equal(
        _get_error(HeaderPrefix(1, False, 0), 100, TABLE_SIZE), message
    )


def test_truncated_prefix() raises:
    var prefix = HeaderPrefix(0, False, 0)
    var cases: List[List[UInt8]] = [[], [0xFF], [0x00]]
    for ref data in cases:
        var failed = False
        try:
            _ = decode_header_prefix(Span(data), prefix)
        except e:
            failed = True
            assert_equal(e.message, "truncated field section prefix")
        assert_true(failed)


def test_to_index() raises:
    assert_equal(to_index(7), 7)
    var failed = False
    try:
        _ = to_index(UInt64(1) << 62)
    except e:
        failed = True
        assert_equal(e.message, "integer too large")
    assert_true(failed)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

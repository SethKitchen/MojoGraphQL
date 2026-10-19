# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_http3.qpack_decoder`.

Upstream: `h3/src/qpack/decoder.rs` of hyperium/h3 h3-v0.0.8
(`test_header_too_long`, `test_insert_field_with_name_ref_into_dynamic_table`,
`test_insert_field_with_wrong_name_index_from_static_table`,
`test_insert_field_with_wrong_name_index_from_dynamic_table`,
`test_insert_field_without_name_ref`, `test_duplicate_field`,
`test_dynamic_table_size_update`, `enc_recv_buf_too_short`,
`enc_recv_accepts_truncated_messages`, `largest_ref_too_big`,
`decode_indexed_header_field`, `decode_post_base_indexed`,
`decode_name_ref_header_field`, `decode_post_base_name_ref_header_field`,
`decode_without_name_ref_header_field`, `decode_single_pass_encoded`,
`largest_ref_greater_than_max_entries`). The blocked stream, the limits
and the decoder stream instructions are tested beyond upstream.
"""

from gql_http3.error import H3ErrorCode
from gql_http3.qpack_block import (
    HeaderPrefix,
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
from gql_http3.qpack_decoder import QpackDecoder
from gql_http3.qpack_encoder import encode_static_field
from gql_http3.qpack_field import FieldList
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime TABLE_SIZE = 4096


def _b(text: StaticString) -> Span[UInt8, ImmStaticOrigin]:
    return text.as_bytes()


def _decoder(fields: Int) -> QpackDecoder:
    """A decoder whose table holds `foo1: bar` to `foo<n>: bar`."""
    var decoder = QpackDecoder(TABLE_SIZE, 100)
    decoder.table.set_capacity(TABLE_SIZE)
    for i in range(fields):
        decoder.table.insert(String("foo", i + 1).as_bytes(), _b("bar"))
    return decoder^


def _stream(mut decoder: QpackDecoder) -> List[UInt8]:
    var out = List[UInt8]()
    decoder.take_decoder_stream(out)
    return out^


def _check(fields: FieldList, index: Int, name: String, value: String) raises:
    assert_equal(String(fields.name_text(index)), name)
    assert_equal(String(fields.value_text(index)), value)


def _encoder_error(
    mut decoder: QpackDecoder, data: List[UInt8]
) raises -> String:
    try:
        decoder.on_encoder_stream(Span(data))
    except e:
        assert_true(e.code == H3ErrorCode.QPACK_ENCODER_STREAM_ERROR)
        return e.message.copy()
    return "no error"


def _decode_error(
    mut decoder: QpackDecoder, data: List[UInt8]
) raises -> String:
    var fields = FieldList()
    try:
        _ = decoder.decode(0, Span(data), fields)
    except e:
        return String(e)
    return "no error"


def test_header_too_long() raises:
    var block: List[UInt8] = [0, 0]
    encode_static_field(_b("trailer"), _b("value"), block)
    encode_static_field(_b("trailer2"), _b("value2"), block)
    var decoder = QpackDecoder(0, 0, 2)
    assert_equal(
        _decode_error(decoder, block),
        "H3_EXCESSIVE_LOAD: field section too large",
    )
    var fields = FieldList()
    decoder.max_field_section_size = 44 + 46
    assert_true(decoder.decode(0, Span(block), fields))
    assert_equal(fields.size(), 90)


def test_insert_field_with_name_ref_into_dynamic_table() raises:
    var decoder = _decoder(0)
    var buf = List[UInt8]()
    write_insert_static_name(1, _b("serial value"), buf)
    decoder.on_encoder_stream(Span(buf))
    var a = decoder.table.from_insert_count(0)
    assert_true(decoder.table.name(a) == _b(":path"))
    assert_true(decoder.table.value(a) == _b("serial value"))
    var expected = List[UInt8]()
    write_insert_count_increment(1, expected)
    assert_true(_stream(decoder) == expected)
    assert_equal(decoder.insert_count(), 1)


def test_insert_field_with_wrong_name_index() raises:
    var decoder = _decoder(0)
    var buf = List[UInt8]()
    write_insert_static_name(3000, _b(""), buf)
    assert_equal(_encoder_error(decoder, buf), "bad static index 3000")
    buf.clear()
    write_insert_dynamic_name(3000, _b(""), buf)
    assert_equal(_encoder_error(decoder, buf), "bad relative index 3000")
    assert_equal(len(_stream(decoder)), 0)


def test_insert_field_without_name_ref() raises:
    var decoder = _decoder(0)
    var buf = List[UInt8]()
    write_insert_literal(_b("key"), _b("value"), buf)
    decoder.on_encoder_stream(Span(buf))
    assert_true(decoder.table.name(0) == _b("key"))
    assert_true(decoder.table.value(0) == _b("value"))
    var expected = List[UInt8]()
    write_insert_count_increment(1, expected)
    assert_true(_stream(decoder) == expected)


def test_insert_with_dynamic_name() raises:
    var decoder = _decoder(2)
    var buf = List[UInt8]()
    write_insert_dynamic_name(1, _b("baz"), buf)
    decoder.on_encoder_stream(Span(buf))
    assert_true(decoder.table.name(2) == _b("foo1"))
    assert_true(decoder.table.value(2) == _b("baz"))


def test_duplicate_field() raises:
    var decoder = _decoder(0)
    decoder.table.insert(_b(""), _b(""))
    decoder.table.insert(_b("a"), _b("b"))
    var buf = List[UInt8]()
    write_duplicate(1, buf)
    decoder.on_encoder_stream(Span(buf))
    assert_equal(decoder.insert_count(), 3)
    assert_equal(len(decoder.table.name(2)), 0)
    var expected = List[UInt8]()
    write_insert_count_increment(1, expected)
    assert_true(_stream(decoder) == expected)


def test_dynamic_table_size_update() raises:
    var decoder = _decoder(0)
    var buf = List[UInt8]()
    write_set_capacity(25, buf)
    decoder.on_encoder_stream(Span(buf))
    assert_equal(decoder.table.capacity, 25)
    assert_equal(len(_stream(decoder)), 0)
    buf.clear()
    write_set_capacity(TABLE_SIZE + 1, buf)
    assert_equal(_encoder_error(decoder, buf), "capacity above the maximum")


def test_entry_larger_than_capacity() raises:
    var decoder = _decoder(0)
    decoder.table.set_capacity(40)
    var buf = List[UInt8]()
    write_insert_literal(_b("name"), _b("value"), buf)
    assert_equal(_encoder_error(decoder, buf), "entry larger than the capacity")


def test_enc_recv_buf_too_short() raises:
    var decoder = _decoder(0)
    decoder.on_encoder_stream(Span(List[UInt8]()))
    var one: List[UInt8] = [0b1100_0000]
    decoder.on_encoder_stream(Span(one))
    assert_equal(decoder.insert_count(), 0)
    # The cut instruction completes with the next byte: static name 0 and
    # an empty value.
    var rest: List[UInt8] = [0]
    decoder.on_encoder_stream(Span(rest))
    assert_equal(decoder.insert_count(), 1)
    assert_true(decoder.table.name(0) == _b(":authority"))
    # Cut inside a long static index, a duplicate and a capacity.
    var cuts: List[List[UInt8]] = [[0xFF], [0x1F], [0x3F]]
    for ref cut in cuts:
        decoder = _decoder(0)
        decoder.on_encoder_stream(Span(cut))
        assert_equal(decoder.insert_count(), 0)
    assert_equal(decoder.table.capacity, TABLE_SIZE)


def test_enc_recv_accepts_truncated_messages() raises:
    var buf = List[UInt8]()
    write_insert_literal(_b("keyfoobarbaz"), _b("value"), buf)
    var first = len(buf)
    write_insert_literal(_b("keyfoobarbaz2"), _b("value"), buf)
    # Cut in the middle of the first string.
    var decoder = _decoder(0)
    decoder.on_encoder_stream(Span(buf)[:2])
    assert_equal(decoder.insert_count(), 0)
    # Cut the last byte of the first value: still nothing.
    decoder.on_encoder_stream(Span(buf)[2 : first - 1])
    assert_equal(decoder.insert_count(), 0)
    # The first field completes; the second waits for its last byte.
    decoder.on_encoder_stream(Span(buf)[first - 1 : len(buf) - 1])
    assert_equal(decoder.insert_count(), 1)
    var expected = List[UInt8]()
    write_insert_count_increment(1, expected)
    assert_true(_stream(decoder) == expected)
    decoder.on_encoder_stream(Span(buf)[len(buf) - 1 :])
    assert_equal(decoder.insert_count(), 2)
    assert_true(decoder.table.name(1) == _b("keyfoobarbaz2"))


def test_bad_huffman_on_encoder_stream() raises:
    var decoder = _decoder(0)
    var buf: List[UInt8] = [0b0110_0001, 0xFF]
    assert_equal(_encoder_error(decoder, buf), "invalid Huffman encoding")


def test_largest_ref_too_big() raises:
    # The section needs 8 entries; the table has none: the stream blocks.
    var decoder = _decoder(0)
    var buf = List[UInt8]()
    HeaderPrefix.new(8, 8, 10, TABLE_SIZE).encode(buf)
    var fields = FieldList()
    assert_false(decoder.decode(4, Span(buf), fields))
    assert_equal(decoder.required_insert_count, 8)
    assert_equal(decoder.blocked_streams(), 1)
    # The same stream again does not count twice.
    assert_false(decoder.decode(4, Span(buf), fields))
    assert_equal(decoder.blocked_streams(), 1)
    decoder.max_blocked_streams = 1
    assert_equal(
        _decode_error(decoder, buf),
        "QPACK_DECOMPRESSION_FAILED: too many blocked streams",
    )
    decoder.cancel_stream(4)
    assert_equal(decoder.blocked_streams(), 0)
    var expected = List[UInt8]()
    write_stream_cancel(4, expected)
    assert_true(_stream(decoder) == expected)
    decoder.cancel_stream(8)
    assert_equal(len(_stream(decoder)), 1)


def test_cancel_without_table_sends_nothing() raises:
    var decoder = QpackDecoder()
    decoder.cancel_stream(4)
    assert_equal(len(_stream(decoder)), 0)


def test_blocked_stream_unblocks() raises:
    var decoder = _decoder(0)
    var block = List[UInt8]()
    HeaderPrefix.new(1, 0, 1, TABLE_SIZE).encode(block)
    write_indexed_post_base(0, block)
    var fields = FieldList()
    assert_false(decoder.decode(8, Span(block), fields))
    var buf = List[UInt8]()
    write_insert_literal(_b("foo"), _b("bar"), buf)
    decoder.on_encoder_stream(Span(buf))
    assert_true(decoder.decode(8, Span(block), fields))
    assert_equal(decoder.blocked_streams(), 0)
    _check(fields, 0, "foo", "bar")
    var expected = List[UInt8]()
    write_insert_count_increment(1, expected)
    write_section_ack(8, expected)
    assert_true(_stream(decoder) == expected)


def test_decode_indexed_header_field() raises:
    var buf = List[UInt8]()
    HeaderPrefix.new(2, 2, 2, TABLE_SIZE).encode(buf)
    write_indexed_dynamic(0, buf)
    write_indexed_dynamic(1, buf)
    write_indexed_static(18, buf)
    var decoder = _decoder(2)
    var fields = FieldList()
    assert_true(decoder.decode(0, Span(buf), fields))
    _check(fields, 0, "foo2", "bar")
    _check(fields, 1, "foo1", "bar")
    _check(fields, 2, ":method", "HEAD")
    var expected = List[UInt8]()
    write_section_ack(0, expected)
    assert_true(_stream(decoder) == expected)


def test_decode_post_base_indexed() raises:
    var buf = List[UInt8]()
    HeaderPrefix.new(4, 2, 4, TABLE_SIZE).encode(buf)
    write_indexed_dynamic(0, buf)
    write_indexed_post_base(0, buf)
    write_indexed_post_base(1, buf)
    var decoder = _decoder(4)
    var fields = FieldList()
    assert_true(decoder.decode(0, Span(buf), fields))
    _check(fields, 0, "foo2", "bar")
    _check(fields, 1, "foo3", "bar")
    _check(fields, 2, "foo4", "bar")


def test_decode_name_ref_header_field() raises:
    var buf = List[UInt8]()
    HeaderPrefix.new(2, 2, 4, TABLE_SIZE).encode(buf)
    write_literal_dynamic_name(1, _b("new bar1"), buf)
    write_literal_static_name(18, _b("PUT"), buf)
    var decoder = _decoder(4)
    var fields = FieldList()
    assert_true(decoder.decode(0, Span(buf), fields))
    _check(fields, 0, "foo1", "new bar1")
    _check(fields, 1, ":method", "PUT")


def test_decode_post_base_name_ref_header_field() raises:
    var buf = List[UInt8]()
    HeaderPrefix.new(3, 2, 4, TABLE_SIZE).encode(buf)
    write_literal_post_base_name(0, _b("new bar3"), buf)
    var decoder = _decoder(4)
    var fields = FieldList()
    assert_true(decoder.decode(0, Span(buf), fields))
    _check(fields, 0, "foo3", "new bar3")


def test_decode_without_name_ref_header_field() raises:
    var buf = List[UInt8]()
    HeaderPrefix.new(0, 0, 0, TABLE_SIZE).encode(buf)
    write_literal(_b("foo"), _b("bar"), buf)
    var decoder = _decoder(0)
    var fields = FieldList()
    assert_true(decoder.decode(0, Span(buf), fields))
    _check(fields, 0, "foo", "bar")
    assert_equal(len(_stream(decoder)), 0)


def test_decode_single_pass_encoded() raises:
    var buf = List[UInt8]()
    HeaderPrefix.new(4, 0, 4, TABLE_SIZE).encode(buf)
    for i in range(4):
        write_indexed_post_base(i, buf)
    var decoder = _decoder(4)
    var fields = FieldList()
    assert_true(decoder.decode(0, Span(buf), fields))
    for i in range(4):
        _check(fields, i, String("foo", i + 1), "bar")


def test_largest_ref_greater_than_max_entries() raises:
    var max_entries = TABLE_SIZE // 32
    var decoder = _decoder(max_entries + 10)
    var buf = List[UInt8]()
    HeaderPrefix.new(
        max_entries + 5, max_entries + 5, max_entries + 10, TABLE_SIZE
    ).encode(buf)
    write_indexed_dynamic(10, buf)
    var fields = FieldList()
    assert_true(decoder.decode(0, Span(buf), fields))
    _check(fields, 0, String("foo", max_entries - 5), "bar")
    buf.clear()
    HeaderPrefix.new(
        max_entries + 10, max_entries + 5, max_entries + 10, TABLE_SIZE
    ).encode(buf)
    write_indexed_post_base(0, buf)
    write_indexed_post_base(4, buf)
    assert_true(decoder.decode(0, Span(buf), fields))
    _check(fields, 0, String("foo", max_entries + 6), "bar")
    _check(fields, 1, String("foo", max_entries + 10), "bar")


def _section(required: Int, base: Int, line: List[UInt8]) -> List[UInt8]:
    var buf = List[UInt8]()
    HeaderPrefix.new(required, base, required, TABLE_SIZE).encode(buf)
    buf.extend(Span(line))
    return buf^


def test_invalid_sections() raises:
    var decoder = _decoder(4)
    var failed = "QPACK_DECOMPRESSION_FAILED: "
    var line = List[UInt8]()
    write_indexed_static(99, line)
    assert_equal(
        _decode_error(decoder, _section(0, 0, line)),
        failed + "bad static index 99",
    )
    line.clear()
    write_literal_static_name(120, _b("x"), line)
    assert_equal(
        _decode_error(decoder, _section(0, 0, line)),
        failed + "bad static index 120",
    )
    # Upstream's decode_post_base_name_ref_header_field names entry 3 in a
    # section of Required Insert Count 2; RFC 9204 forbids that.
    line.clear()
    write_literal_post_base_name(0, _b("x"), line)
    assert_equal(
        _decode_error(decoder, _section(2, 2, line)),
        failed + "reference above the insert count",
    )
    line.clear()
    write_indexed_dynamic(0, line)
    assert_equal(
        _decode_error(decoder, _section(0, 0, line)),
        failed + "bad relative index 0",
    )


def test_truncated_field_lines() raises:
    var decoder = _decoder(4)
    var message = "QPACK_DECOMPRESSION_FAILED: truncated field line"
    var lines: List[List[UInt8]] = [
        [0xFF],
        [0x1F],
        [0x2F],
        [0x23, 0x61],
        [0x21, 0x61, 0x05],
        [0x5F],
        [0x51, 0x05],
        [0x07],
        [0x00, 0x05],
    ]
    for ref line in lines:
        assert_equal(_decode_error(decoder, _section(4, 0, line)), message)


def test_stateless_decode() raises:
    # Upstream decode_stateless: a decoder of capacity 0.
    var block: List[UInt8] = [0, 0]
    encode_static_field(_b(":method"), _b("GET"), block)
    encode_static_field(_b(":path"), _b("/index.html"), block)
    encode_static_field(_b("x-name"), _b("value"), block)
    var decoder = QpackDecoder()
    var fields = FieldList()
    fields.add_text("stale", "field")
    assert_true(decoder.decode(0, Span(block), fields))
    assert_equal(fields.count(), 3)
    _check(fields, 0, ":method", "GET")
    _check(fields, 1, ":path", "/index.html")
    _check(fields, 2, "x-name", "value")
    var bad: List[UInt8] = [1, 0]
    assert_equal(
        _decode_error(decoder, bad),
        "QPACK_DECOMPRESSION_FAILED: invalid encoded insert count",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

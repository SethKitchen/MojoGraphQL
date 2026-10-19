# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_http3.qpack`: the encoder and the decoder together.

Upstream: `h3/src/qpack/tests.rs` of hyperium/h3 h3-v0.0.8
(`codec_basic_get`, `blocked_header`, `codec_table_size_0`,
`codec_table_full`). The examples of RFC 9204 Appendix B (B.1 to B.5) are
added: the decoder reads their bytes, and the encoder's own output for the
same fields decodes to the same fields. The RFC shows only the Section
Acknowledgment on the decoder stream of B.2; this decoder sends an Insert
Count Increment first, which RFC 9204 section 4.4.3 allows.
"""

from gql_http3.qpack import FieldList, QpackDecoder, QpackEncoder
from gql_http3.qpack_block import write_insert_count_increment
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime TABLE_SIZE = 4096


def _hex(text: StaticString) -> List[UInt8]:
    var out = List[UInt8]()
    var digits = List[Int]()
    for b in text.as_bytes():
        var c = Int(b)
        if c >= 48 and c <= 57:
            digits.append(c - 48)
        elif c >= 97 and c <= 102:
            digits.append(c - 87)
    var i = 0
    while i + 1 < len(digits):
        out.append(UInt8(digits[i] * 16 + digits[i + 1]))
        i += 2
    return out^


def _header() -> FieldList:
    var fields = FieldList()
    fields.add_text(":method", "GET")
    fields.add_text(":path", "/")
    fields.add_text("foo", "bar")
    return fields^


def _stream(mut decoder: QpackDecoder) -> List[UInt8]:
    var out = List[UInt8]()
    decoder.take_decoder_stream(out)
    return out^


def _round_trip(
    mut encoder: QpackEncoder, mut decoder: QpackDecoder, fields: FieldList
) raises:
    var block = List[UInt8]()
    var to_decoder = List[UInt8]()
    _ = encoder.encode(42, fields, block, to_decoder)
    decoder.on_encoder_stream(Span(to_decoder))
    var decoded = FieldList()
    assert_true(decoder.decode(42, Span(block), decoded))
    assert_equal(String(decoded), String(fields))
    encoder.on_decoder_stream(Span(_stream(decoder)))


def test_codec_basic_get() raises:
    var encoder = QpackEncoder()
    var decoder = QpackDecoder()
    _round_trip(encoder, decoder, _header())


def test_blocked_header() raises:
    var encoder = QpackEncoder(TABLE_SIZE, 100)
    var ignored = List[UInt8]()
    encoder.set_capacity(TABLE_SIZE, ignored)
    var decoder = QpackDecoder(TABLE_SIZE, 100)
    var block = List[UInt8]()
    var to_decoder = List[UInt8]()
    var fields = FieldList()
    fields.add_text("foo", "bar")
    _ = encoder.encode(42, fields, block, to_decoder)
    var decoded = FieldList()
    assert_false(decoder.decode(42, Span(block), decoded))
    assert_equal(decoder.required_insert_count, 1)


def test_codec_table_size_0() raises:
    var encoder = QpackEncoder(TABLE_SIZE, 100)
    var decoder = QpackDecoder(TABLE_SIZE, 100)
    _round_trip(encoder, decoder, _header())


def test_codec_table_full() raises:
    var encoder = QpackEncoder(42, 100)
    var decoder = QpackDecoder(42, 100)
    var to_decoder = List[UInt8]()
    encoder.set_capacity(42, to_decoder)
    decoder.on_encoder_stream(Span(to_decoder))
    var fields = FieldList()
    fields.add_text("foo", "bar")
    fields.add_text("foo1", "bar1")
    _round_trip(encoder, decoder, fields)
    assert_equal(decoder.insert_count(), 1)


def _check(fields: FieldList, index: Int, name: String, value: String) raises:
    assert_equal(String(fields.name_text(index)), name)
    assert_equal(String(fields.value_text(index)), value)


def test_rfc9204_b1_literal_with_name_reference() raises:
    var decoder = QpackDecoder()
    var fields = FieldList()
    var block = _hex("0000 510b 2f69 6e64 6578 2e68 746d 6c")
    assert_true(decoder.decode(4, Span(block), fields))
    assert_equal(fields.count(), 1)
    _check(fields, 0, ":path", "/index.html")
    assert_equal(len(_stream(decoder)), 0)
    # The encoder's form decodes to the same field.
    var encoder = QpackEncoder()
    _round_trip(encoder, decoder, fields)


def test_rfc9204_b2_to_b5_dynamic_table() raises:
    var decoder = QpackDecoder(220, 1)
    # B.2: capacity 220, two insertions with static name references.
    decoder.on_encoder_stream(
        Span(
            _hex(
                "3fbd01 c00f 7777 772e 6578 616d 706c 652e 636f 6d"
                " c10c 2f73 616d 706c 652f 7061 7468"
            )
        )
    )
    assert_equal(decoder.table.capacity, 220)
    assert_equal(decoder.table.size, 106)
    var fields = FieldList()
    assert_true(decoder.decode(4, Span(_hex("0381 10 11")), fields))
    _check(fields, 0, ":authority", "www.example.com")
    _check(fields, 1, ":path", "/sample/path")
    var expected = List[UInt8]()
    write_insert_count_increment(2, expected)
    expected.append(0x84)
    assert_true(_stream(decoder) == expected)
    # B.3: a speculative insert.
    decoder.on_encoder_stream(
        Span(
            _hex("4a63 7573 746f 6d2d 6b65 790c 6375 7374 6f6d 2d76 616c 7565")
        )
    )
    assert_equal(decoder.table.size, 160)
    assert_true(_stream(decoder) == _hex("01"))
    # B.4: duplicate of entry 0, a section that uses it, a cancellation.
    decoder.on_encoder_stream(Span(_hex("02")))
    assert_equal(decoder.table.size, 217)
    assert_true(decoder.decode(8, Span(_hex("0500 80 c1 81")), fields))
    _check(fields, 0, ":authority", "www.example.com")
    _check(fields, 1, ":path", "/")
    _check(fields, 2, "custom-key", "custom-value")
    _ = _stream(decoder)
    decoder.cancel_stream(8)
    assert_true(_stream(decoder) == _hex("48"))
    # B.5: an insertion with a dynamic name reference evicts entry 0.
    decoder.on_encoder_stream(
        Span(_hex("810d 6375 7374 6f6d 2d76 616c 7565 32"))
    )
    assert_equal(decoder.table.size, 215)
    assert_equal(decoder.table.dropped(), 1)
    assert_true(decoder.table.name(4) == StaticString("custom-key").as_bytes())
    assert_true(
        decoder.table.value(4) == StaticString("custom-value2").as_bytes()
    )
    assert_true(_stream(decoder) == _hex("01"))


def test_rfc9204_encoder_side() raises:
    # The encoder, given the fields of Appendix B, keeps both tables equal.
    var encoder = QpackEncoder(220, 1)
    var decoder = QpackDecoder(220, 1)
    var to_decoder = List[UInt8]()
    encoder.set_capacity(220, to_decoder)
    decoder.on_encoder_stream(Span(to_decoder))
    var first = FieldList()
    first.add_text(":authority", "www.example.com")
    first.add_text(":path", "/sample/path")
    _round_trip(encoder, decoder, first)
    var second = FieldList()
    second.add_text(":authority", "www.example.com")
    second.add_text(":path", "/")
    second.add_text("custom-key", "custom-value")
    _round_trip(encoder, decoder, second)
    _round_trip(encoder, decoder, second)
    assert_equal(encoder.table.size, decoder.table.size)
    assert_equal(encoder.known_received, encoder.table.insert_count())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

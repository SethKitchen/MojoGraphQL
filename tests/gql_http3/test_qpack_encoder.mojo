# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_http3.qpack_encoder`.

Upstream: `h3/src/qpack/encoder.rs` (`encode_static`,
`encode_static_nameref`, `encode_static_nameref_indexed_in_dynamic`,
`encode_dynamic_insert`, `encode_dynamic_insert_nameref`, `encode_literal`,
`encode_literal_nameref`, `encode_literal_postbase_nameref`,
`encode_with_header_block`, `decoder_block_ack`, `decoder_stream_cacnceled`)
and the encoder tests of `h3/src/qpack/dynamic.rs`
(`encoder_does_not_evict_referenced`, `encoder_can_evict_unreferenced`,
`no_insert_when_max_blocked_0`, `no_insert_after_max_blocked_reached`,
`insert_again_after_encoder_ack`) of hyperium/h3 h3-v0.0.8. Each block is
checked byte for byte against the writers of `qpack_block`.
"""

from gql_http3.error import H3ErrorCode
from gql_http3.qpack_block import (
    HeaderPrefix,
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
from gql_http3.qpack_encoder import QpackEncoder
from gql_http3.qpack_field import FieldList
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime TABLE_SIZE = 4096


def _b(text: StaticString) -> Span[UInt8, ImmStaticOrigin]:
    return text.as_bytes()


def _encoder(capacity: Int, blocked: Int = 100) raises -> QpackEncoder:
    var encoder = QpackEncoder(TABLE_SIZE, blocked)
    var ignored = List[UInt8]()
    encoder.set_capacity(capacity, ignored)
    return encoder^


def _fields(*pairs: StaticString) -> FieldList:
    var fields = FieldList()
    var i = 0
    while i + 1 < len(pairs):
        fields.add_text(pairs[i], pairs[i + 1])
        i += 2
    return fields^


struct _Out(Movable):
    var block: List[UInt8]
    var stream: List[UInt8]
    var required: Int

    def __init__(out self):
        self.block = List[UInt8]()
        self.stream = List[UInt8]()
        self.required = 0


def _encode(
    mut encoder: QpackEncoder, stream_id: UInt64, fields: FieldList
) -> _Out:
    var out = _Out()
    out.required = encoder.encode(stream_id, fields, out.block, out.stream)
    return out^


def _prefix(required: Int, base: Int) -> List[UInt8]:
    var out = List[UInt8]()
    HeaderPrefix.new(required, base, required, TABLE_SIZE).encode(out)
    return out^


def test_encode_static() raises:
    var encoder = _encoder(TABLE_SIZE)
    var out = _encode(encoder, 1, _fields(":method", "GET"))
    var expected = _prefix(0, 0)
    write_indexed_static(17, expected)
    assert_true(out.block == expected)
    assert_equal(len(out.stream), 0)
    assert_equal(out.required, 0)


def test_encode_static_nameref() raises:
    var encoder = _encoder(TABLE_SIZE)
    var out = _encode(encoder, 1, _fields("location", "/bar"))
    var expected = _prefix(1, 0)
    write_indexed_post_base(0, expected)
    assert_true(out.block == expected)
    var stream = List[UInt8]()
    write_insert_static_name(12, _b("/bar"), stream)
    assert_true(out.stream == stream)
    assert_equal(out.required, 1)


def test_encode_static_nameref_indexed_in_dynamic() raises:
    var encoder = _encoder(TABLE_SIZE)
    encoder.table.insert(_b("location"), _b("/bar"))
    var out = _encode(encoder, 1, _fields("location", "/bar"))
    var expected = _prefix(1, 1)
    write_indexed_dynamic(0, expected)
    assert_true(out.block == expected)
    assert_equal(len(out.stream), 0)


def test_encode_dynamic_insert() raises:
    var encoder = _encoder(TABLE_SIZE)
    var out = _encode(encoder, 1, _fields("foo", "bar"))
    var stream = List[UInt8]()
    write_insert_literal(_b("foo"), _b("bar"), stream)
    assert_true(out.stream == stream)


def test_encode_dynamic_insert_nameref() raises:
    var encoder = _encoder(TABLE_SIZE)
    encoder.table.insert(_b("foo"), _b("bar"))
    encoder.table.insert(_b("baz"), _b("bar"))
    var out = _encode(encoder, 1, _fields("foo", "quxx"))
    var expected = _prefix(3, 2)
    write_indexed_post_base(0, expected)
    assert_true(out.block == expected)
    var stream = List[UInt8]()
    write_insert_dynamic_name(1, _b("quxx"), stream)
    assert_true(out.stream == stream)


def test_encode_literal() raises:
    var encoder = QpackEncoder()
    var out = _encode(encoder, 1, _fields("foo", "bar", ":path", "/x"))
    var expected = _prefix(0, 0)
    write_literal(_b("foo"), _b("bar"), expected)
    write_literal_static_name(1, _b("/x"), expected)
    assert_true(out.block == expected)
    assert_equal(len(out.stream), 0)


def test_encode_literal_nameref() raises:
    var encoder = _encoder(63)
    var first = _encode(encoder, 1, _fields("foo", "bar"))
    assert_equal(first.required, 1)
    # foo: bar is referenced by stream 1: it cannot be evicted.
    var out = _encode(encoder, 2, _fields("foo", "quxx"))
    var expected = _prefix(1, 1)
    write_literal_dynamic_name(0, _b("quxx"), expected)
    assert_true(out.block == expected)
    assert_equal(len(out.stream), 0)


def test_encode_literal_postbase_nameref() raises:
    var encoder = _encoder(63)
    var out = _encode(encoder, 1, _fields("foo", "bar", "foo", "quxx"))
    var expected = _prefix(1, 0)
    write_indexed_post_base(0, expected)
    write_literal_post_base_name(0, _b("quxx"), expected)
    assert_true(out.block == expected)
    var stream = List[UInt8]()
    write_insert_literal(_b("foo"), _b("bar"), stream)
    assert_true(out.stream == stream)


def test_encode_with_header_block() raises:
    var encoder = _encoder(TABLE_SIZE)
    for i in range(1, 5):
        encoder.table.insert(
            String("foo", i).as_bytes(), String("bar", i).as_bytes()
        )
    var fields = _fields(
        ":method",
        "GET",
        "foo1",
        "bar1",
        "foo3",
        "new bar3",
        ":method",
        "staticnameref",
        "newfoo",
        "newbar",
    )
    var out = _encode(encoder, 1, fields)
    assert_equal(out.required, 7)
    var stream = List[UInt8]()
    write_insert_dynamic_name(1, _b("new bar3"), stream)
    write_insert_static_name(15, _b("staticnameref"), stream)
    write_insert_literal(_b("newfoo"), _b("newbar"), stream)
    assert_true(out.stream == stream)
    var expected = _prefix(7, 4)
    write_indexed_static(17, expected)
    write_indexed_dynamic(3, expected)
    write_indexed_post_base(0, expected)
    write_indexed_post_base(1, expected)
    write_indexed_post_base(2, expected)
    assert_true(out.block == expected)
    var prefix = HeaderPrefix.new(7, 4, 7, TABLE_SIZE)
    assert_equal(prefix.get(7, TABLE_SIZE)[1], 4)


def _decoder_error(
    mut encoder: QpackEncoder, data: List[UInt8]
) raises -> String:
    try:
        encoder.on_decoder_stream(Span(data))
    except e:
        assert_true(e.code == H3ErrorCode.QPACK_DECODER_STREAM_ERROR)
        return e.message.copy()
    return "no error"


def test_decoder_block_ack() raises:
    var encoder = _encoder(TABLE_SIZE)
    _ = _encode(encoder, 2, _fields("foo", "bar", "foo", "quxx"))
    assert_equal(encoder.table.refs_of(0), 1)
    var ack = List[UInt8]()
    write_section_ack(2, ack)
    encoder.on_decoder_stream(Span(ack))
    assert_equal(encoder.table.refs_of(0), 0)
    assert_equal(encoder.known_received, 2)
    assert_equal(
        _decoder_error(encoder, ack),
        "acknowledgment of stream 2 without a section",
    )


def test_decoder_stream_canceled() raises:
    var encoder = _encoder(TABLE_SIZE)
    _ = _encode(encoder, 2, _fields("foo", "bar"))
    _ = _encode(encoder, 4, _fields("foo", "bar"))
    _ = _encode(encoder, 2, _fields("foo", "bar"))
    assert_equal(encoder.table.refs_of(0), 3)
    var cancel = List[UInt8]()
    write_stream_cancel(2, cancel)
    encoder.on_decoder_stream(Span(cancel))
    assert_equal(encoder.table.refs_of(0), 1)
    # Cancelling again, or a stream without sections, is no error.
    encoder.on_decoder_stream(Span(cancel))
    assert_equal(encoder.known_received, 0)


def test_insert_count_increment() raises:
    var encoder = _encoder(TABLE_SIZE)
    _ = _encode(encoder, 0, _fields("a", "1", "b", "2"))
    var buf = List[UInt8]()
    write_insert_count_increment(0, buf)
    assert_equal(_decoder_error(encoder, buf), "invalid insert count increment")
    buf.clear()
    write_insert_count_increment(3, buf)
    assert_equal(_decoder_error(encoder, buf), "invalid insert count increment")
    buf.clear()
    write_insert_count_increment(2, buf)
    encoder.on_decoder_stream(Span(buf))
    assert_equal(encoder.known_received, 2)
    assert_equal(encoder.blocked_streams(), 0)
    var big: List[UInt8] = [
        0x3F,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0x7F,
    ]
    assert_equal(_decoder_error(encoder, big), "integer too large")


def test_partial_decoder_stream() raises:
    var encoder = _encoder(TABLE_SIZE)
    _ = _encode(encoder, 300, _fields("a", "1"))
    var buf = List[UInt8]()
    write_section_ack(300, buf)
    write_insert_count_increment(1, buf)
    assert_equal(len(buf), 4)
    encoder.on_decoder_stream(Span(buf)[:1])
    assert_equal(encoder.blocked_streams(), 1)
    encoder.on_decoder_stream(Span(buf)[1:3])
    assert_equal(encoder.blocked_streams(), 0)
    var cut: List[UInt8] = [0x3F]
    encoder.on_decoder_stream(Span(buf)[3:3])
    encoder.on_decoder_stream(Span(cut))
    assert_equal(encoder.known_received, 1)


def test_encoder_does_not_evict_referenced() raises:
    var encoder = _encoder(80)
    _ = _encode(encoder, 1, _fields("foo", "bar"))
    _ = _encode(encoder, 2, _fields("foo2", "bar2"))
    # No room: both entries are referenced, so the third is a literal.
    var out = _encode(encoder, 3, _fields("foo3", "bar3"))
    assert_equal(len(out.stream), 0)
    assert_equal(encoder.table.live(), 2)
    var ack = List[UInt8]()
    write_section_ack(1, ack)
    encoder.on_decoder_stream(Span(ack))
    # encoder_can_evict_unreferenced: foo: bar goes, foo3: bar3 comes.
    out = _encode(encoder, 3, _fields("foo3", "bar3"))
    assert_true(len(out.stream) > 0)
    assert_equal(encoder.table.dropped(), 1)


def test_no_insert_when_max_blocked_0() raises:
    var encoder = _encoder(TABLE_SIZE, 0)
    var out = _encode(encoder, 1, _fields("foo", "bar"))
    assert_equal(len(out.stream), 0)
    assert_equal(out.required, 0)
    assert_equal(encoder.table.live(), 0)


def test_no_insert_after_max_blocked_reached() raises:
    var encoder = _encoder(TABLE_SIZE, 1)
    var first = _encode(encoder, 1, _fields("foo", "bar"))
    assert_equal(first.required, 1)
    # Stream 1 can block further; stream 2 cannot, and sees no unacknowledged
    # entry.
    var again = _encode(encoder, 1, _fields("foo", "bar", "foo", "baz"))
    assert_equal(again.required, 2)
    var other = _encode(encoder, 2, _fields("foo", "bar", "foo", "qux"))
    assert_equal(other.required, 0)
    assert_equal(len(other.stream), 0)
    var expected = _prefix(0, 0)
    write_literal(_b("foo"), _b("bar"), expected)
    write_literal(_b("foo"), _b("qux"), expected)
    assert_true(other.block == expected)
    # insert_again_after_encoder_ack: the decoder has both entries now.
    var buf = List[UInt8]()
    write_insert_count_increment(2, buf)
    encoder.on_decoder_stream(Span(buf))
    var acked = _encode(encoder, 2, _fields("foo", "bar", "foo", "quux"))
    assert_equal(acked.required, 3)
    var expected_acked = _prefix(3, 2)
    write_indexed_dynamic(1, expected_acked)
    write_indexed_post_base(0, expected_acked)
    assert_true(acked.block == expected_acked)


def test_acknowledged_entries_without_blocking() raises:
    var encoder = _encoder(TABLE_SIZE, 1)
    _ = _encode(encoder, 1, _fields("foo", "bar"))
    var buf = List[UInt8]()
    write_insert_count_increment(1, buf)
    encoder.on_decoder_stream(Span(buf))
    _ = _encode(encoder, 1, _fields("other", "x"))
    assert_equal(encoder.blocked_streams(), 1)
    # Stream 2 cannot block: it uses only entry 0, which the decoder has.
    var out = _encode(encoder, 2, _fields("foo", "bar", "foo", "zzz"))
    assert_equal(out.required, 1)
    var expected = _prefix(1, 2)
    write_indexed_dynamic(1, expected)
    write_literal_dynamic_name(1, _b("zzz"), expected)
    assert_true(out.block == expected)
    assert_equal(len(out.stream), 0)


def test_post_base_exact_match() raises:
    # The second copy of a field inserted in the same section is after the
    # base.
    var encoder = _encoder(TABLE_SIZE)
    var out = _encode(encoder, 1, _fields("foo", "bar", "foo", "bar"))
    var expected = _prefix(1, 0)
    write_indexed_post_base(0, expected)
    write_indexed_post_base(0, expected)
    assert_true(out.block == expected)


def test_static_name_without_insert() raises:
    var encoder = _encoder(TABLE_SIZE, 0)
    var out = _encode(encoder, 1, _fields("location", "/x"))
    var expected = _prefix(0, 0)
    write_literal_static_name(12, _b("/x"), expected)
    assert_true(out.block == expected)


def test_ack_of_a_later_section() raises:
    var encoder = _encoder(TABLE_SIZE)
    _ = _encode(encoder, 1, _fields("a", "1"))
    _ = _encode(encoder, 2, _fields("b", "2"))
    var ack = List[UInt8]()
    write_section_ack(2, ack)
    encoder.on_decoder_stream(Span(ack))
    assert_equal(encoder.known_received, 2)
    assert_equal(encoder.table.refs_of(0), 1)
    assert_equal(encoder.table.refs_of(1), 0)


def test_set_capacity() raises:
    var encoder = QpackEncoder(100, 10)
    var stream = List[UInt8]()
    var failed = False
    try:
        encoder.set_capacity(101, stream)
    except e:
        failed = True
        assert_true(e.code == H3ErrorCode.H3_INTERNAL_ERROR)
    assert_true(failed)
    encoder.set_capacity(100, stream)
    var expected = List[UInt8]()
    write_set_capacity(100, expected)
    assert_true(stream == expected)
    _ = _encode(encoder, 1, _fields("foo", "bar", "foo2", "bar2"))
    failed = False
    try:
        encoder.set_capacity(50, stream)
    except e:
        failed = True
        assert_equal(e.message, "referenced entries do not fit")
    assert_true(failed)
    var cancel = List[UInt8]()
    write_stream_cancel(1, cancel)
    encoder.on_decoder_stream(Span(cancel))
    encoder.set_capacity(50, stream)
    assert_equal(encoder.table.live(), 1)
    encoder.set_capacity(100, stream)
    assert_equal(encoder.table.capacity, 100)


def test_round_trip_with_decoder() raises:
    # The dynamic table of both sides stays in step over many sections.
    from gql_http3.qpack_decoder import QpackDecoder

    var encoder = QpackEncoder(256, 4)
    var decoder = QpackDecoder(256, 4)
    var to_decoder = List[UInt8]()
    encoder.set_capacity(256, to_decoder)
    for round in range(40):
        var fields = FieldList()
        fields.add_text(":method", "POST")
        fields.add_text(":path", "/graphql")
        fields.add_text("x-request", String(round % 7))
        fields.add_text("x-trace", String("t", round))
        fields.add_text("content-type", "application/json")
        var block = List[UInt8]()
        var stream_id = UInt64(round * 4)
        _ = encoder.encode(stream_id, fields, block, to_decoder)
        decoder.on_encoder_stream(Span(to_decoder))
        to_decoder.clear()
        var decoded = FieldList()
        assert_true(decoder.decode(stream_id, Span(block), decoded))
        assert_equal(String(decoded), String(fields))
        var back = List[UInt8]()
        decoder.take_decoder_stream(back)
        encoder.on_decoder_stream(Span(back))
    assert_true(encoder.table.insert_count() > 5)
    assert_equal(encoder.blocked_streams(), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

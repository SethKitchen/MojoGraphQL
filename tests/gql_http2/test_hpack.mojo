# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the decoder of `gql_http2.hpack`: the examples of RFC 7541
Appendix C, the errors, the list size limit and `HeaderList`.

Ports the tests of `src/hpack/decoder.rs` of hyperium/h2 v0.4.20. The
decoder takes whole blocks, so the test of a block that ends inside a
string checks a `NEED_MORE` error, and then decodes the whole block.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from gql_http2.hpack import (
    Decoder,
    HeaderList,
    HpackError,
    HpackErrorKind,
    decode_integer,
    encode_integer,
)
from gql_http2.huffman import huffman_encode

from _hpack_util import (
    decode_block,
    decode_error,
    fields_text,
    hex_bytes,
    table_text,
)


def _bytes(text: StringSlice) -> List[UInt8]:
    return List[UInt8](text.as_bytes())


def _huff(text: StringSlice) -> List[UInt8]:
    var out = List[UInt8]()
    huffman_encode(text.as_bytes(), out)
    return out^


def _step(
    mut decoder: Decoder,
    block: StringSlice,
    fields: StringSlice,
    table: StringSlice,
) raises:
    var out = decode_block(decoder, hex_bytes(block))
    assert_equal(fields_text(out), String(fields))
    assert_equal(table_text(decoder.table), String(table))


def test_error_kinds() raises:
    assert_true(HpackErrorKind.NEED_MORE.is_valid())
    assert_false(HpackErrorKind(7).is_valid())
    assert_equal(String(HpackErrorKind(7)), "invalid")
    assert_equal(
        String(HpackErrorKind.INVALID_REPRESENTATION), "invalid representation"
    )
    assert_equal(
        String(HpackErrorKind.INVALID_INTEGER_PREFIX), "invalid integer prefix"
    )
    assert_equal(
        String(HpackErrorKind.INVALID_TABLE_INDEX), "invalid table index"
    )
    assert_equal(
        String(HpackErrorKind.INVALID_HUFFMAN_CODE), "invalid Huffman code"
    )
    assert_equal(
        String(HpackErrorKind.INVALID_MAX_DYNAMIC_SIZE),
        "invalid max dynamic size",
    )
    assert_equal(String(HpackErrorKind.INTEGER_OVERFLOW), "integer overflow")
    assert_true(HpackErrorKind.NEED_MORE == HpackErrorKind(6))
    var error = HpackError(HpackErrorKind.NEED_MORE, "short")
    assert_equal(String(error), "need more: short")


def _encoded(value: Int, prefix_bits: Int, flags: UInt8) -> List[UInt8]:
    var out = List[UInt8]()
    encode_integer(value, prefix_bits, flags, out)
    return out^


def _decoded(data: List[UInt8], prefix_bits: Int) raises -> Int:
    var position = 0
    var value = decode_integer(Span(data), position, prefix_bits)
    assert_equal(position, len(data))
    return value


def _integer_error(data: List[UInt8], prefix_bits: Int) raises -> HpackError:
    var position = 0
    try:
        _ = decode_integer(Span(data), position, prefix_bits)
    except e:
        return e^
    raise Error("expected an integer error")


def test_integers() raises:
    # RFC 7541 C.1.1 to C.1.3.
    assert_true(_encoded(10, 5, 0) == [10])
    assert_true(_encoded(1337, 5, 0) == [31, 154, 10])
    assert_true(_encoded(42, 8, 0) == [42])
    assert_true(_encoded(127, 7, 0x80) == [0xFF, 0])
    assert_true(_encoded(126, 7, 0x80) == [0xFE])
    assert_equal(_decoded([10], 5), 10)
    assert_equal(_decoded([0xEA], 5), 10)
    assert_equal(_decoded([31, 154, 10], 5), 1337)
    assert_equal(_decoded([42], 8), 42)
    assert_equal(_decoded([0xFF, 0x80, 0x80, 0x80, 0x7F], 8), 255 + (127 << 21))
    for value in [0, 1, 30, 31, 32, 127, 128, 16383, 16384, 1 << 20]:
        for prefix in range(1, 9):
            assert_equal(_decoded(_encoded(value, prefix, 0), prefix), value)


def test_integer_errors() raises:
    var kind = _integer_error([1], 0).kind
    assert_true(kind == HpackErrorKind.INVALID_INTEGER_PREFIX)
    kind = _integer_error([1], 9).kind
    assert_true(kind == HpackErrorKind.INVALID_INTEGER_PREFIX)
    kind = _integer_error([], 5).kind
    assert_true(kind == HpackErrorKind.NEED_MORE)
    kind = _integer_error([31, 154], 5).kind
    assert_true(kind == HpackErrorKind.NEED_MORE)
    kind = _integer_error([31, 0xFF, 0xFF, 0xFF, 0xFF, 1], 5).kind
    assert_true(kind == HpackErrorKind.INTEGER_OVERFLOW)


def test_decode_empty() raises:
    var decoder = Decoder(0)
    var out = decode_block(decoder, [])
    assert_equal(out.count(), 0)


def test_decode_string_empty() raises:
    var decoder = Decoder(0)
    var error = decode_error(decoder, [0x40])
    assert_true(error.kind == HpackErrorKind.NEED_MORE)
    assert_equal(error.message, "the block ends before a string")


def test_decode_indexed_larger_than_table() raises:
    var decoder = Decoder(0)
    var block: List[UInt8] = [0b01000000, 0x80 | 2]
    block += _huff("foo")
    block.append(0x80 | 3)
    block += _huff("bar")
    var out = decode_block(decoder, block)
    assert_equal(fields_text(out), "foo: bar\n")
    assert_equal(decoder.table.size(), 0)
    assert_equal(decoder.table.count(), 0)


def test_decode_continuation_header_with_non_huff_encoded_name() raises:
    var decoder = Decoder(0)
    var value = _huff("bar")
    var block: List[UInt8] = [0b01000000, 3]
    block += _bytes("foo")
    block.append(0x80 | 3)
    block.append(value[0])
    var error = decode_error(decoder, block)
    assert_true(error.kind == HpackErrorKind.NEED_MORE)
    assert_equal(error.message, "the block ends inside a string")
    block.extend(value[1:])
    var out = decode_block(decoder, block)
    assert_equal(fields_text(out), "foo: bar\n")
    assert_equal(decoder.table.size(), 0)


def test_rfc_c2_literals() raises:
    # C.2.1: a literal with indexing.
    var decoder = Decoder()
    _step(
        decoder,
        "400a 6375 7374 6f6d 2d6b 6579 0d63 7573 746f 6d2d 6865 6164 6572",
        "custom-key: custom-header\n",
        "custom-key: custom-header\nsize 55",
    )
    # C.2.2: a literal without indexing.
    decoder = Decoder()
    _step(
        decoder,
        "040c 2f73 616d 706c 652f 7061 7468",
        ":path: /sample/path\n",
        "size 0",
    )
    # C.2.3: a literal that is never indexed.
    decoder = Decoder()
    var out = decode_block(
        decoder, hex_bytes("1008 7061 7373 776f 7264 0673 6563 7265 74")
    )
    assert_equal(fields_text(out), "password: secret\n")
    assert_true(out.is_sensitive(0))
    assert_equal(decoder.table.size(), 0)
    # C.2.4: an indexed field.
    decoder = Decoder()
    out = decode_block(decoder, [0x82])
    assert_equal(fields_text(out), ":method: GET\n")
    assert_false(out.is_sensitive(0))


comptime _C3_FIRST = (
    ":method: GET\n:scheme: http\n:path: /\n:authority: www.example.com\n"
)
comptime _C3_SECOND = _C3_FIRST + "cache-control: no-cache\n"
comptime _C3_THIRD = (
    ":method: GET\n:scheme: https\n:path: /index.html\n"
    ":authority: www.example.com\ncustom-key: custom-value\n"
)
comptime _C3_TABLE_1 = ":authority: www.example.com\nsize 57"
comptime _C3_TABLE_2 = "cache-control: no-cache\n" + _C3_TABLE_1
comptime _C3_TABLE_3 = "custom-key: custom-value\n" + _C3_TABLE_2


def test_rfc_c3_requests() raises:
    var decoder = Decoder()
    _step(
        decoder,
        "8286 8441 0f77 7777 2e65 7861 6d70 6c65 2e63 6f6d",
        _C3_FIRST,
        _C3_TABLE_1,
    )
    _step(
        decoder,
        "8286 84be 5808 6e6f 2d63 6163 6865",
        _C3_SECOND,
        String(_C3_TABLE_2).replace("size 57", "size 110"),
    )
    _step(
        decoder,
        (
            "8287 85bf 400a 6375 7374 6f6d 2d6b 6579 0c63 7573 746f 6d2d"
            " 7661 6c75 65"
        ),
        _C3_THIRD,
        String(_C3_TABLE_3).replace("size 57", "size 164"),
    )


def test_rfc_c4_requests_huffman() raises:
    var decoder = Decoder()
    _step(
        decoder,
        "8286 8441 8cf1 e3c2 e5f2 3a6b a0ab 90f4 ff",
        _C3_FIRST,
        _C3_TABLE_1,
    )
    _step(
        decoder,
        "8286 84be 5886 a8eb 1064 9cbf",
        _C3_SECOND,
        String(_C3_TABLE_2).replace("size 57", "size 110"),
    )
    _step(
        decoder,
        "8287 85bf 4088 25a8 49e9 5ba9 7d7f 8925 a849 e95b b8e8 b4bf",
        _C3_THIRD,
        String(_C3_TABLE_3).replace("size 57", "size 164"),
    )


comptime _C5_FIRST = (
    ":status: 302\ncache-control: private\n"
    "date: Mon, 21 Oct 2013 20:13:21 GMT\n"
    "location: https://www.example.com\n"
)
comptime _C5_SECOND = (
    ":status: 307\ncache-control: private\n"
    "date: Mon, 21 Oct 2013 20:13:21 GMT\n"
    "location: https://www.example.com\n"
)
comptime _C5_THIRD = (
    ":status: 200\ncache-control: private\n"
    "date: Mon, 21 Oct 2013 20:13:22 GMT\n"
    "location: https://www.example.com\ncontent-encoding: gzip\n"
    "set-cookie: foo=ASDJKHQKBZXOQWEOPIUAXQWEOIU; max-age=3600; version=1\n"
)
comptime _C5_TABLE_1 = (
    "location: https://www.example.com\n"
    "date: Mon, 21 Oct 2013 20:13:21 GMT\n"
    "cache-control: private\n:status: 302\nsize 222"
)
comptime _C5_TABLE_2 = (
    ":status: 307\nlocation: https://www.example.com\n"
    "date: Mon, 21 Oct 2013 20:13:21 GMT\n"
    "cache-control: private\nsize 222"
)
comptime _C5_TABLE_3 = (
    "set-cookie: foo=ASDJKHQKBZXOQWEOPIUAXQWEOIU; max-age=3600; version=1\n"
    "content-encoding: gzip\n"
    "date: Mon, 21 Oct 2013 20:13:22 GMT\nsize 215"
)


def test_rfc_c5_responses() raises:
    var decoder = Decoder(256)
    _step(
        decoder,
        (
            "4803 3330 3258 0770 7269 7661 7465 611d 4d6f 6e2c 2032 3120"
            " 4f63 7420 3230 3133 2032 303a 3133 3a32 3120 474d 546e 1768"
            " 7474 7073 3a2f 2f77 7777 2e65 7861 6d70 6c65 2e63 6f6d"
        ),
        _C5_FIRST,
        _C5_TABLE_1,
    )
    _step(decoder, "4803 3330 37c1 c0bf", _C5_SECOND, _C5_TABLE_2)
    _step(
        decoder,
        (
            "88c1 611d 4d6f 6e2c 2032 3120 4f63 7420 3230 3133 2032 303a"
            " 3133 3a32 3220 474d 54c0 5a04 677a 6970 7738 666f 6f3d 4153"
            " 444a 4b48 514b 425a 584f 5157 454f 5049 5541 5851 5745 4f49"
            " 553b 206d 6178 2d61 6765 3d33 3630 303b 2076 6572 7369 6f6e"
            " 3d31"
        ),
        _C5_THIRD,
        _C5_TABLE_3,
    )


def test_rfc_c6_responses_huffman() raises:
    var decoder = Decoder(256)
    _step(
        decoder,
        (
            "4882 6402 5885 aec3 771a 4b61 96d0 7abe 9410 54d4 44a8 2005"
            " 9504 0b81 66e0 82a6 2d1b ff6e 919d 29ad 1718 63c7 8f0b 97c8"
            " e9ae 82ae 43d3"
        ),
        _C5_FIRST,
        _C5_TABLE_1,
    )
    _step(decoder, "4883 640e ffc1 c0bf", _C5_SECOND, _C5_TABLE_2)
    _step(
        decoder,
        (
            "88c1 6196 d07a be94 1054 d444 a820 0595 040b 8166 e084 a62d"
            " 1bff c05a 839b d9ab 77ad 94e7 821d d7f2 e6c7 b335 dfdf cd5b"
            " 3960 d5af 2708 7f36 72c1 ab27 0fb5 291f 9587 3160 65c0 03ed"
            " 4ee5 b106 3d50 07"
        ),
        _C5_THIRD,
        _C5_TABLE_3,
    )


def _kind(block: List[UInt8]) raises -> HpackErrorKind:
    var decoder = Decoder()
    return decode_error(decoder, block).kind


def test_errors() raises:
    assert_true(_kind([0x80]) == HpackErrorKind.INVALID_TABLE_INDEX)
    assert_true(_kind([0xBE]) == HpackErrorKind.INVALID_TABLE_INDEX)
    # A literal whose name is at index 63 of an empty table.
    assert_true(_kind([0x7F, 0, 0]) == HpackErrorKind.INVALID_TABLE_INDEX)
    # A Huffman string of one zero byte.
    assert_true(
        _kind([0x40, 0x81, 0, 0]) == HpackErrorKind.INVALID_HUFFMAN_CODE
    )
    assert_true(_kind([0x40, 0x85, 1]) == HpackErrorKind.NEED_MORE)
    assert_true(_kind([0x1F]) == HpackErrorKind.NEED_MORE)
    assert_true(_kind([0x40, 0, 0]) == HpackErrorKind.NEED_MORE)
    assert_true(
        _kind([0x1F, 0xFF, 0xFF, 0xFF, 0xFF, 1])
        == HpackErrorKind.INTEGER_OVERFLOW
    )
    assert_true(_kind([0x82, 0x20]) == HpackErrorKind.INVALID_MAX_DYNAMIC_SIZE)
    # 4097 is above the size of a new decoder.
    var fresh = Decoder()
    var error = decode_error(fresh, [0x3F, 0xE2, 0x1F])
    assert_true(error.kind == HpackErrorKind.INVALID_MAX_DYNAMIC_SIZE)
    assert_equal(
        error.message, "a table size update to 4097 is above the allowed 4096"
    )
    var other = Decoder()
    var index = decode_error(other, [0xBE])
    assert_equal(
        index.message,
        "a field refers to index 62; the dynamic table has 0 entries",
    )


def test_size_updates() raises:
    var decoder = Decoder()
    # Two updates at the start of a block: 0, then 4096.
    var out = decode_block(decoder, [0x20, 0x3F, 0xE1, 0x1F, 0x82])
    assert_equal(fields_text(out), ":method: GET\n")
    assert_equal(decoder.table.max_size(), 4096)
    # A larger SETTINGS value allows a larger update from the next block.
    decoder.queue_size_update(100)
    decoder.queue_size_update(8192)
    _ = decode_block(decoder, [0x3F, 0xE1, 0x3F])
    assert_equal(decoder.table.max_size(), 8192)
    decoder.queue_size_update(50)
    var error = decode_error(decoder, [0x3F, 0x14])
    assert_true(error.kind == HpackErrorKind.INVALID_MAX_DYNAMIC_SIZE)


def test_size_update_evicts() raises:
    var decoder = Decoder()
    _ = decode_block(
        decoder,
        hex_bytes(
            "400a 6375 7374 6f6d 2d6b 6579 0d63 7573 746f 6d2d 6865 6164 6572"
        ),
    )
    assert_equal(decoder.table.count(), 1)
    _ = decode_block(decoder, [0x3F, 0x19])
    assert_equal(decoder.table.max_size(), 56)
    assert_equal(decoder.table.count(), 1)
    _ = decode_block(decoder, [0x3F, 0x17])
    assert_equal(decoder.table.count(), 0)


def test_literal_with_dynamic_name() raises:
    # The name of the new entry is the entry that the insertion evicts.
    var decoder = Decoder(60)
    var first = hex_bytes(
        "400a 6375 7374 6f6d 2d6b 6579 0d63 7573 746f 6d2d 6865 6164 6572"
    )
    _ = decode_block(decoder, first)
    var block: List[UInt8] = [0x40 | 62, 3]
    block += _bytes("abc")
    var out = decode_block(decoder, block)
    assert_equal(fields_text(out), "custom-key: abc\n")
    assert_equal(table_text(decoder.table), "custom-key: abc\nsize 45")
    # Without indexing, the name is read in place.
    var plain: List[UInt8] = [0x0F, 47, 0x83]
    plain += _huff("xyz")
    out = decode_block(decoder, plain)
    assert_equal(fields_text(out), "custom-key: xyz\n")
    # A Huffman name and value, both in the scratch buffer.
    var both: List[UInt8] = [0x40, 0x80 | 2]
    both += _huff("foo")
    both.append(0x80 | 3)
    both += _huff("bar")
    out = decode_block(decoder, both)
    assert_equal(fields_text(out), "foo: bar\n")
    assert_equal(table_text(decoder.table), "foo: bar\nsize 38")


def test_max_list_size() raises:
    var decoder = Decoder()
    var block = hex_bytes("8286 8441 0f77 7777 2e65 7861 6d70 6c65 2e63 6f6d")
    # :method GET is 42, :scheme http is 43: two fields fit in 85.
    var out = decode_block(decoder, block, 85)
    assert_equal(fields_text(out), ":method: GET\n:scheme: http\n")
    assert_true(out.too_large)
    assert_equal(out.list_size(), 85)
    # The table took the last field all the same.
    assert_equal(table_text(decoder.table), _C3_TABLE_1)
    # The list appends; a full list stays full.
    var more = HeaderList()
    more.add_text("x", "y")
    var one: List[UInt8] = [0x82]
    decoder.decode(Span(one), 1000, more)
    assert_equal(fields_text(more), "x: y\n:method: GET\n")
    assert_false(more.too_large)
    var two: List[UInt8] = [0x82, 0x82]
    decoder.decode(Span(two), 76, more)
    assert_true(more.too_large)
    assert_equal(more.count(), 2)


def test_header_list() raises:
    var fields = HeaderList()
    fields.add_text(":method", "GET")
    fields.add(_bytes("password"), _bytes("secret"), True)
    assert_equal(fields.count(), 2)
    assert_equal(String(fields.name_text(1)), "password")
    assert_equal(String(fields.value_text(0)), "GET")
    assert_true(fields.is_sensitive(1))
    assert_false(fields.is_sensitive(0))
    assert_true(fields.name(0) == Span(_bytes(":method")))
    assert_true(fields.value(1) == Span(_bytes("secret")))
    assert_equal(fields.list_size(), 7 + 3 + 32 + 8 + 6 + 32)
    var copy = fields.copy()
    fields.too_large = True
    fields.clear()
    assert_equal(fields.count(), 0)
    assert_equal(fields.list_size(), 0)
    assert_false(fields.too_large)
    assert_equal(copy.count(), 2)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

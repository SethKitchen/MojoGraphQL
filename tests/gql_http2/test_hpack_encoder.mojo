# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the encoder of `gql_http2.hpack`, and for the tables of
`gql_http2.hpack_table`.

Ports the tests of `src/hpack/encoder.rs` of hyperium/h2 v0.4.20. h2's
`test_nameless_header` is not ported: this encoder takes a name with each
field. h2 reads the pending size updates of its encoder; these tests read
the bytes that `begin_block` writes instead.
"""

from std.builtin.globals import global_constant
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from gql_http2.hpack import Decoder, Encoder, HeaderList
from gql_http2.hpack_table import (
    DynamicTable,
    HASH_BUCKETS,
    StaticIndex,
    _STATIC_SLOTS,
    name_hash,
    static_name,
)

from _hpack_util import (
    decode_block,
    fields_text,
    hex_bytes,
    huff_text,
    table_text,
)


def _bytes(text: StringSlice) -> List[UInt8]:
    return List[UInt8](text.as_bytes())


def _starts(data: List[UInt8], prefix: List[UInt8]) -> Bool:
    return len(data) >= len(prefix) and Span(data)[: len(prefix)] == Span(
        prefix
    )


def _field(
    mut encoder: Encoder,
    name: String,
    value: String,
    sensitive: Bool = False,
) -> List[UInt8]:
    var out = List[UInt8]()
    encoder.begin_block(out)
    encoder.encode_field(name.as_bytes(), value.as_bytes(), sensitive, out)
    return out^


def _updates(mut encoder: Encoder) -> List[UInt8]:
    var out = List[UInt8]()
    encoder.begin_block(out)
    return out^


def test_encode_method_get() raises:
    var encoder = Encoder()
    assert_true(_field(encoder, ":method", "GET") == [0x80 | 2])
    assert_equal(encoder.table.count(), 0)


def test_encode_method_post() raises:
    var encoder = Encoder()
    assert_true(_field(encoder, ":method", "POST") == [0x80 | 3])
    assert_equal(encoder.table.count(), 0)


def test_encode_method_patch() raises:
    var encoder = Encoder()
    var res = _field(encoder, ":method", "PATCH")
    assert_equal(res[0], 0b01000000 | 2)
    assert_equal(res[1], 0x80 | 5)
    assert_equal(huff_text(Span(res)[2:7]), "PATCH")
    assert_equal(encoder.table.count(), 1)
    res = _field(encoder, ":method", "PATCH")
    assert_true(res == [0x80 | 62])


def test_encode_indexed_name_literal_value() raises:
    var encoder = Encoder()
    var res = _field(encoder, "content-language", "foo")
    assert_equal(res[0], 0b01000000 | 27)
    assert_equal(res[1], 0x80 | 2)
    assert_equal(huff_text(Span(res)[2:4]), "foo")
    res = _field(encoder, "content-language", "bar")
    assert_equal(res[0], 0b01000000 | 27)
    assert_equal(res[1], 0x80 | 3)
    assert_equal(huff_text(Span(res)[2:5]), "bar")


def test_repeated_headers_are_indexed() raises:
    var encoder = Encoder()
    var res = _field(encoder, "foo", "hello")
    assert_true(_starts(res, [0b01000000, 0x80 | 2]))
    assert_equal(huff_text(Span(res)[2:4]), "foo")
    assert_equal(res[4], 0x80 | 4)
    assert_equal(huff_text(Span(res)[5:]), "hello")
    assert_equal(len(res), 9)
    assert_equal(encoder.table.count(), 1)
    res = _field(encoder, "foo", "hello")
    assert_true(res == [0x80 | 62])
    assert_equal(encoder.table.count(), 1)


def _key(index: Int) -> String:
    var digits = String(index)
    if index < 10:
        digits = "0" + digits
    return "x-hello-world-" + digits


def _check_inserted(res: List[UInt8], key: String) raises:
    assert_equal(res[0], 0b01000000)
    assert_equal(res[1], 0x80 | 12)
    assert_equal(huff_text(Span(res)[2:14]), key)
    assert_equal(res[14], 0x80 | 12)
    assert_equal(huff_text(Span(res)[15:]), key)
    assert_equal(len(res), 27)


def test_evicting_headers() raises:
    var encoder = Encoder()
    for index in range(64):
        var key = _key(index)
        _check_inserted(_field(encoder, key, key), key)
        assert_equal(_field(encoder, key, key)[0] & 0x80, 0x80)
    assert_equal(encoder.table.size(), 4096)
    assert_equal(encoder.table.count(), 64)
    for index in range(64):
        var key = _key(index)
        assert_equal(_field(encoder, key, key)[0] & 0x80, 0x80)
    _check_inserted(_field(encoder, _key(64), _key(64)), _key(64))
    assert_equal(encoder.table.count(), 64)
    for index in range(1, 65):
        var key = _key(index)
        assert_equal(
            Int(_field(encoder, key, key)[0]), 0x80 | (61 + 65 - index)
        )


def test_large_headers_are_not_indexed() raises:
    var encoder = Encoder(128)
    # h2's `HeaderName` makes the name lowercase; the value keeps its case.
    var key = "hello-world-hello-world-HELLO-zzz"
    var res = _field(encoder, "hello-world-hello-world-hello-zzz", key)
    assert_true(_starts(res, [0, 0x80 | 25]))
    assert_equal(encoder.table.count(), 0)
    assert_equal(encoder.table.size(), 0)


def test_sensitive_headers_are_never_indexed() raises:
    var encoder = Encoder()
    var res = _field(encoder, "my-password", "12345", True)
    assert_true(_starts(res, [0b10000, 0x80 | 8]))
    assert_equal(huff_text(Span(res)[2:10]), "my-password")
    assert_equal(res[10], 0x80 | 4)
    assert_equal(huff_text(Span(res)[11:]), "12345")
    # A sensitive field with a name in the static table.
    encoder = Encoder()
    res = _field(encoder, "authorization", "12345", True)
    assert_true(_starts(res, [0b11111, 8, 0x80 | 4]))
    assert_equal(huff_text(Span(res)[3:]), "12345")
    # The name of an entry that is in the table, not sensitive.
    _ = _field(encoder, "my-password", "not-so-secret")
    res = _field(encoder, "my-password", "12345", True)
    assert_true(_starts(res, [0b11111, 47, 0x80 | 4]))
    assert_equal(huff_text(Span(res)[3:]), "12345")
    assert_equal(encoder.table.count(), 1)
    # A sensitive field with a static name, not one of h2's skipped names.
    res = _field(encoder, "accept", "secret", True)
    assert_true(_starts(res, [0b11111, 4]))
    assert_equal(encoder.table.count(), 1)
    # A sensitive field whose name and value are in the table.
    res = _field(encoder, "my-password", "not-so-secret", True)
    assert_true(res == [0x80 | 62])


def test_content_length_value_not_indexed() raises:
    var encoder = Encoder()
    var res = _field(encoder, "content-length", "1234")
    assert_true(_starts(res, [15, 13, 0x80 | 3]))
    assert_equal(huff_text(Span(res)[3:]), "1234")
    assert_equal(len(res), 6)
    # `:path: /` is in the static table, so it is indexed.
    assert_true(_field(encoder, ":path", "/") == [0x84])
    res = _field(encoder, ":path", "/graphql")
    assert_equal(res[0], 0x04)
    assert_equal(encoder.table.count(), 0)


def test_encoding_headers_with_same_name() raises:
    var encoder = Encoder()
    _ = _field(encoder, "hello", "one")
    var res = _field(encoder, "hello", "two")
    assert_true(_starts(res, [0x40 | 62, 0x80 | 3]))
    assert_equal(huff_text(Span(res)[2:]), "two")
    assert_equal(len(res), 5)
    assert_true(_field(encoder, "hello", "one") == [0x80 | 63])
    assert_true(_field(encoder, "hello", "two") == [0x80 | 62])


def test_evicting_headers_when_multiple_of_same_name_are_in_table() raises:
    var encoder = Encoder(76)
    _ = _field(encoder, "foo", "bar")
    assert_equal(encoder.table.count(), 1)
    _ = _field(encoder, "bar", "foo")
    assert_equal(encoder.table.count(), 2)
    var res = _field(encoder, "foo", "baz")
    assert_true(_starts(res, [0x40 | 63, 0, 0x80 | 3]))
    assert_equal(encoder.table.count(), 2)
    assert_true(_field(encoder, "foo", "baz") == [0x80 | 62])
    assert_equal(encoder.table.count(), 2)


def test_max_size_zero() raises:
    var encoder = Encoder(0)
    assert_true(_field(encoder, ":method", "GET") == [0x80 | 2])
    assert_equal(encoder.table.count(), 0)
    var res = _field(encoder, "foo", "bar")
    assert_true(_starts(res, [0, 0x80 | 2]))
    assert_equal(huff_text(Span(res)[2:4]), "foo")
    assert_equal(res[4], 0x80 | 3)
    assert_equal(huff_text(Span(res)[5:8]), "bar")
    assert_equal(encoder.table.count(), 0)
    res = _field(encoder, "transfer-encoding", "chunked")
    assert_true(_starts(res, [15, 42, 0x80 | 6]))
    assert_equal(huff_text(Span(res)[3:]), "chunked")


def test_update_max_size_combos() raises:
    var encoder = Encoder()
    assert_equal(encoder.table.max_size(), 4096)
    encoder.update_max_size(4096)
    assert_equal(len(_updates(encoder)), 0)
    encoder.update_max_size(0)
    encoder.update_max_size(100)
    # Two(0, 100).
    assert_true(_updates(encoder) == [0x20, 0x3F, 69])
    encoder = Encoder()
    encoder.set_max_allowed_size(8000)
    encoder.update_max_size(8000)
    encoder.update_max_size(100)
    encoder.update_max_size(8000)
    encoder.update_max_size(4000)
    # Two(100, 4000).
    assert_true(_updates(encoder) == [0x3F, 69, 0x3F, 0x81, 0x1F])
    assert_equal(encoder.table.max_size(), 4000)
    encoder.update_max_size(8000)
    encoder.update_max_size(100)
    encoder.update_max_size(8000)
    encoder.update_max_size(50)
    # One(50).
    assert_true(_updates(encoder) == [0x3F, 19])
    # One(old) with old above the table size: a larger value replaces it.
    encoder.update_max_size(6000)
    encoder.update_max_size(7000)
    assert_true(_updates(encoder) == [0x3F, 0xB9, 0x36])


def test_resizing_table() raises:
    var encoder = Encoder()
    _ = _field(encoder, "foo", "bar")
    encoder.update_max_size(1)
    assert_equal(encoder.table.count(), 1)
    assert_true(_field(encoder, ":method", "GET") == [32 | 1, 0x80 | 2])
    assert_equal(encoder.table.count(), 0)
    assert_equal(_field(encoder, "foo", "bar")[0], 0)
    encoder.update_max_size(100)
    var res = _field(encoder, "foo", "bar")
    assert_true(_starts(res, [32 | 31, 69, 64]))
    encoder.update_max_size(0)
    res = _field(encoder, "foo", "bar")
    assert_true(_starts(res, [32, 0]))


def test_decreasing_table_size_without_eviction() raises:
    var encoder = Encoder()
    _ = _field(encoder, "foo", "bar")
    encoder.update_max_size(100)
    assert_equal(encoder.table.count(), 1)
    assert_true(_field(encoder, "foo", "bar") == [32 | 31, 69, 0x80 | 62])


def test_large_size_update() raises:
    var encoder = Encoder()
    encoder.set_max_allowed_size(Int.MAX)
    encoder.update_max_size(1912930560)
    assert_true(_updates(encoder) == [63, 225, 129, 148, 144, 7])


def test_large_size_update_is_capped() raises:
    var encoder = Encoder(0)
    encoder.update_max_size(1912930560)
    assert_true(_updates(encoder) == [63, 225, 31])
    assert_equal(encoder.table.max_size(), 4096)
    # A smaller allowed size cuts the table now.
    encoder.set_max_allowed_size(1000)
    assert_true(_updates(encoder) == [63, 201, 7])
    encoder.set_max_allowed_size(2000)
    assert_equal(len(_updates(encoder)), 0)


def _request() -> HeaderList:
    var fields = HeaderList()
    fields.add_text(":method", "GET")
    fields.add_text(":scheme", "http")
    fields.add_text(":path", "/")
    fields.add_text(":authority", "www.example.com")
    return fields^


def test_rfc_c4_encoding() raises:
    # h2 makes the same choices as the examples of RFC 7541 C.4.
    var encoder = Encoder()
    var out = List[UInt8]()
    encoder.encode(_request(), out)
    assert_true(out == hex_bytes("8286 8441 8cf1 e3c2 e5f2 3a6b a0ab 90f4 ff"))
    var second = _request()
    second.add_text("cache-control", "no-cache")
    out.clear()
    encoder.encode(second, out)
    assert_true(out == hex_bytes("8286 84be 5886 a8eb 1064 9cbf"))
    var third = HeaderList()
    third.add_text(":method", "GET")
    third.add_text(":scheme", "https")
    third.add_text(":path", "/index.html")
    third.add_text(":authority", "www.example.com")
    third.add_text("custom-key", "custom-value")
    out.clear()
    encoder.encode(third, out)
    assert_true(
        out
        == hex_bytes(
            "8287 85bf 4088 25a8 49e9 5ba9 7d7f 8925 a849 e95b b8e8 b4bf"
        )
    )
    assert_equal(encoder.table.size(), 164)


def test_long_huffman_string() raises:
    # 300 `a` bytes have a 5-bit code: 188 bytes, a two-byte length.
    var encoder = Encoder()
    var value = String("a") * 300
    var res = _field(encoder, "x-long", value)
    assert_true(_starts(res, [0x40, 0x80 | 5]))
    assert_equal(res[7], 0xFF)
    assert_equal(res[8], 61)
    assert_equal(len(res), 9 + 188)
    assert_equal(huff_text(Span(res)[9:]), value)
    var decoder = Decoder()
    var out = decode_block(decoder, res)
    assert_equal(fields_text(out), "x-long: " + value + "\n")


def test_round_trip_responses() raises:
    # The responses of RFC 7541 C.6 with a 256-byte table, and an empty
    # value: the encoder output decodes to the same fields and tables.
    var encoder = Encoder(256)
    var decoder = Decoder(256)
    var dates: List[String] = [
        "Mon, 21 Oct 2013 20:13:21 GMT",
        "Mon, 21 Oct 2013 20:13:21 GMT",
        "Mon, 21 Oct 2013 20:13:22 GMT",
    ]
    var statuses: List[String] = ["302", "307", "200"]
    for step in range(3):
        var fields = HeaderList()
        fields.add_text(":status", statuses[step])
        fields.add_text("cache-control", "private")
        fields.add_text("date", dates[step])
        fields.add_text("location", "https://www.example.com")
        fields.add_text("x-empty", "")
        if step == 2:
            fields.add_text("content-encoding", "gzip")
            fields.add_text(
                "set-cookie",
                "foo=ASDJKHQKBZXOQWEOPIUAXQWEOIU; max-age=3600; version=1",
            )
        var out = List[UInt8]()
        encoder.encode(fields, out)
        var decoded = decode_block(decoder, out)
        assert_equal(fields_text(decoded), fields_text(fields))
        assert_equal(table_text(decoder.table), table_text(encoder.table))


def test_sensitive_round_trip() raises:
    var encoder = Encoder()
    var decoder = Decoder()
    var fields = HeaderList()
    fields.add_text("authorization", "Bearer abc", True)
    fields.add_text(":authority", "secret.example", True)
    fields.add_text("x-token", "t", True)
    var out = List[UInt8]()
    encoder.encode(fields, out)
    var decoded = decode_block(decoder, out)
    assert_equal(fields_text(decoded), fields_text(fields))
    for index in range(3):
        assert_true(decoded.is_sensitive(index))
    assert_equal(encoder.table.count(), 0)


def test_static_index() raises:
    var index = StaticIndex()
    for entry in range(1, 62):
        var name = static_name(entry)
        var found = index.find(name.as_bytes(), name_hash(name.as_bytes()))
        assert_equal(String(static_name(found)), String(name))
        assert_true(found <= entry)
    var missing = _bytes("x-missing")
    assert_equal(index.find(Span(missing), name_hash(Span(missing))), 0)
    assert_equal(index.find_value(0, Span(missing)), 0)
    assert_equal(index.find_value(2, Span(_bytes("POST"))), 3)
    assert_equal(index.find_value(2, Span(_bytes("PUT"))), 0)
    assert_equal(index.find_value(61, Span(_bytes(""))), 0)
    assert_equal(index.find_value(16, Span(_bytes("gzip, deflate"))), 16)


def test_static_slots_match_the_names() raises:
    # Build the slot table from the static names and `name_hash`, and
    # compare it with the constant of the module.
    var slots = List[Int](length=HASH_BUCKETS, fill=0)
    var last = String("")
    for entry in range(1, 62):
        var name = String(static_name(entry))
        if name == last:
            continue
        last = name
        var slot = Int(name_hash(name.as_bytes()) >> 57)
        while slots[slot] != 0:
            slot = (slot + 1) % HASH_BUCKETS
        slots[slot] = entry
    var known = global_constant[_STATIC_SLOTS]().unsafe_ptr()
    for slot in range(HASH_BUCKETS):
        assert_equal(Int(known[unsafe_offset=slot]), slots[slot], String(slot))


def test_name_hash() raises:
    var short = name_hash(Span(_bytes("ab")))
    assert_true(short != name_hash(Span(_bytes("ba"))))
    assert_true(
        name_hash(Span(_bytes("abcd"))) != name_hash(Span(_bytes("abce")))
    )
    assert_true(
        name_hash(Span(_bytes("abcdefgh")))
        != name_hash(Span(_bytes("abcdefgi")))
    )
    assert_true(name_hash(Span(List[UInt8]())) != short)


def _name(number: Int, length: Int) -> String:
    var name = String("n", number)
    while name.byte_length() < length:
        name = "x" + name
    return name^


def _same_chain(first_length: Int, second_length: Int) raises -> List[String]:
    """Return two different names of the given lengths in one chain."""
    var first = List[String]()
    for _ in range(HASH_BUCKETS):
        first.append("")
    for number in range(1000):
        var name = _name(number, first_length)
        var chain = Int(name_hash(name.as_bytes()) >> 57)
        if first[chain] == "":
            first[chain] = name
    for number in range(1000, 100000):
        var name = _name(number, second_length)
        var chain = Int(name_hash(name.as_bytes()) >> 57)
        if first[chain] != "":
            return [first[chain], name]
    raise Error("no two names share a chain")


def test_table_chains() raises:
    var table = DynamicTable(4096, True)
    var pair = _same_chain(6, 6)
    var a = _bytes(pair[0])
    var b = _bytes(pair[1])
    assert_true(table.insert(a, _bytes("1"), name_hash(a)))
    assert_true(table.insert(b, _bytes("2"), name_hash(b)))
    # The walk passes `b`: same chain and length, other bytes.
    var found = table.find(a, _bytes("1"), name_hash(a))
    assert_equal(found.value_index, 1)
    assert_equal(found.name_index, 1)
    found = table.find(a, _bytes("9"), name_hash(a))
    assert_equal(found.value_index, -1)
    assert_equal(found.name_index, 1)
    # Names of two lengths in one chain.
    var other = _same_chain(6, 7)
    var c = _bytes(other[0])
    var d = _bytes(other[1])
    assert_true(table.insert(c, _bytes("3"), name_hash(c)))
    found = table.find(d, _bytes("3"), name_hash(d))
    assert_equal(found.value_index, -1)
    assert_equal(found.name_index, -1)
    # The same name and a value of the same length.
    found = table.find(c, _bytes("4"), name_hash(c))
    assert_equal(found.value_index, -1)
    assert_equal(found.name_index, 0)


def test_table_compaction() raises:
    # Many evictions: the table drops the evicted bytes, and keeps working.
    var encoder = Encoder()
    var decoder = Decoder()
    for round in range(400):
        var fields = HeaderList()
        fields.add_text("x-round", String(round))
        fields.add_text("x-big", String("v") * (round % 50 + 1))
        var out = List[UInt8]()
        encoder.encode(fields, out)
        var decoded = decode_block(decoder, out)
        assert_equal(fields_text(decoded), fields_text(fields))
    assert_equal(table_text(decoder.table), table_text(encoder.table))
    # One entry that is too large empties the table.
    var table = DynamicTable(100, False)
    assert_true(table.insert(_bytes("a"), _bytes("b"), 0))
    assert_false(table.insert(_bytes("a"), _bytes("b") * 100, 0))
    assert_equal(table.count(), 0)
    assert_equal(table.size(), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

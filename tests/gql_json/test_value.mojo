# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_json.value`: the readers, the builder, the object index
and the string and number helpers.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _fixtures import must_parse
from gql_json.value import (
    JsonDocument,
    JsonKind,
    JsonObjectIndex,
    NO_NODE,
    append_codepoint,
    decode_string,
    hex_value,
    is_canonical_number,
    number_end,
    read_hex4,
)
from gql_json.writer import stringify


def test_kind() raises:
    assert_true(JsonKind.OBJECT.is_valid())
    assert_false(JsonKind(6).is_valid())
    var names = List[String]()
    for value in range(7):
        names.append(String(JsonKind(UInt8(value))))
    assert_equal(
        " ".join(names), "null boolean number string array object <invalid>"
    )


def test_navigation() raises:
    var document = must_parse('{"a": [10, 20, 30], "b": {}, "c": "x"}')
    var root = document.root
    assert_equal(document.kind(root), JsonKind.OBJECT)
    assert_equal(document.length(root), 3)
    var a = document.first(root)
    assert_equal(document.key(a), "a")
    assert_equal(document.length(a), 3)
    assert_equal(document.as_int64(document.at(a, 0)), 10)
    assert_equal(document.as_int64(document.at(a, 2)), 30)
    assert_equal(document.at(a, 3), NO_NODE)
    assert_equal(document.at(a, -1), NO_NODE)
    var b = document.next(a)
    assert_equal(document.first(b), NO_NODE)
    assert_equal(document.length(b), 0)
    var c = document.next(b)
    assert_equal(document.next(c), NO_NODE)
    assert_equal(document.length(c), 0)
    var children = document.children(a)
    assert_equal(len(children), 3)
    assert_equal(document.text(children[1]), "20")
    assert_equal(len(document.children(c)), 0)
    # A container has no text, and an array item has no key.
    assert_equal(document.text(a), "")
    assert_equal(document.text(b), "")
    assert_equal(document.raw_key(children[0]), "")


def test_keys_and_lookup() raises:
    var document = must_parse(
        '{"plain": 1, "esc\\u0061ped": 2, "dup": 3, "dup": 4}'
    )
    var root = document.root
    var plain = document.first(root)
    var escaped = document.next(plain)
    assert_equal(document.raw_key(escaped), "esc\\u0061ped")
    assert_equal(document.key(escaped), "escaped")
    assert_true(document.key_equals(escaped, "escaped"))
    assert_false(document.key_equals(escaped, "esc\\u0061ped"))
    assert_true(document.key_equals(plain, "plain"))
    assert_false(document.key_equals(plain, "other"))
    assert_equal(document.find(root, "escaped"), escaped)
    assert_equal(document.find(root, "missing"), NO_NODE)
    # The last member with a key wins, as in JSON.parse.
    assert_equal(document.as_int64(document.get(root, "dup")), 4)
    var failed = False
    try:
        _ = document.get(root, "missing")
    except e:
        failed = True
        assert_equal(e.message, "No member named missing")
    assert_true(failed)


def test_scalars() raises:
    var document = must_parse(
        '[true, false, null, "a\\nb", "plain", 1.5, 2e3, 12, -0]'
    )
    var items = document.children(document.root)
    assert_true(document.bool_value(items[0]))
    assert_false(document.bool_value(items[1]))
    assert_false(document.bool_value(items[2]))
    assert_equal(document.kind(items[2]), JsonKind.NULL)
    assert_true(document.has_escapes(items[3]))
    assert_equal(document.text(items[3]), "a\\nb")
    assert_equal(document.string_value(items[3]), "a\nb")
    assert_false(document.has_escapes(items[4]))
    assert_false(document.has_escapes(items[0]))
    assert_equal(document.string_value(items[4]), "plain")
    assert_equal(document.string_value(items[0]), "")
    assert_false(document.is_integer(items[5]))
    assert_true(document.is_integer(items[6]))
    assert_true(document.is_integer(items[7]))
    assert_true(document.is_integer(items[8]))
    assert_false(document.is_integer(items[4]))
    assert_equal(document.as_float64(items[5]), 1.5)
    assert_equal(document.as_float64(items[6]), 2000.0)
    var nan = document.as_float64(items[4])
    assert_true(nan != nan)
    assert_equal(document.as_int64(items[6]), 2000)
    assert_equal(document.as_int64(items[8]), 0)


def test_as_int64_errors() raises:
    var document = must_parse('[1.5, 1e30, "1"]')
    var items = document.children(document.root)
    var messages = List[String]()
    for index in range(3):
        try:
            _ = document.as_int64(items[index])
        except e:
            messages.append(e.message)
    assert_equal(len(messages), 3)
    assert_equal(messages[0], "The number 1.5 is not an integer")
    assert_equal(messages[1], "The number 1e30 overflows Int64")
    assert_equal(messages[2], "Expected a number, found string")


def test_build() raises:
    var document = JsonDocument()
    assert_equal(document.root, NO_NODE)
    var root = document.add_object()
    document.root = root
    document.add_member(root, "null", document.add_null())
    document.add_member(root, "yes", document.add_bool(True))
    document.add_member(root, "no", document.add_bool(False))
    document.add_member(root, "int", document.add_int(-42))
    document.add_member(root, "big", document.add_int(Int64.MAX))
    document.add_member(root, "float", document.add_float(0.1))
    var zero: Float64 = 0.0
    document.add_member(root, "nan", document.add_float(zero / zero))
    document.add_member(root, "text", document.add_number("1.50"))
    document.add_member(root, "short", document.add_number("15"))
    document.add_member(root, "quote\n", document.add_string('say "hi"\t'))
    var list = document.add_array()
    document.append(list, document.add_int(1))
    document.append(list, document.add_array())
    document.add_member(root, "list", list)
    assert_equal(
        stringify(document, root),
        (
            '{"null":null,"yes":true,"no":false,"int":-42,'
            '"big":9223372036854775807,"float":0.1,"nan":null,"text":1.5,'
            '"short":15,"quote\\n":"say \\"hi\\"\\t","list":[1,[]]}'
        ),
    )
    var big = document.get(root, "big")
    assert_equal(document.as_int64(big), Int64.MAX)
    assert_true(document.is_integer(document.get(root, "short")))
    assert_equal(
        document.string_value(document.get(root, "quote\n")), 'say "hi"\t'
    )
    var failed = False
    try:
        _ = document.add_number("1.")
    except e:
        failed = True
        assert_equal(e.message, "Not a JSON number: 1.")
    assert_true(failed)
    failed = False
    try:
        _ = document.add_number("12x")
    except e:
        failed = True
    assert_true(failed)


def test_add_copy() raises:
    var source = must_parse(
        '{"a\\u0062": [1, {"k": "v\\n"}, []], "plain": {"x": 2.50}, "e": {}}'
    )
    var target = JsonDocument()
    var root = target.add_object()
    target.root = root
    target.add_member(root, "copied", target.add_copy(source, source.root))
    target.add_member(
        root,
        "scalar",
        target.add_copy(source, source.find(source.root, "plain")),
    )
    assert_equal(
        stringify(target, root),
        (
            '{"copied":{"ab":[1,{"k":"v\\n"},[]],"plain":{"x":2.5},"e":{}},'
            '"scalar":{"x":2.5}}'
        ),
    )
    # A copy of a built document keeps its decoded keys.
    var again = JsonDocument()
    again.root = again.add_copy(target, root)
    assert_equal(stringify(again, again.root), stringify(target, root))
    var copied = again.get(again.root, "copied")
    assert_equal(again.key(again.first(copied)), "ab")
    var scalar = JsonDocument()
    scalar.root = scalar.add_copy(
        source, source.at(source.first(source.root), 0)
    )
    assert_equal(stringify(scalar, scalar.root), "1")


def test_object_index() raises:
    var text = String("{")
    for index in range(40):
        if index > 0:
            text += ","
        text += '"key' + String(index) + '":' + String(index)
    text += ',"key7":"last","esc\\u0061":0}'
    var document = must_parse(text)
    var lookup = JsonObjectIndex(document, document.root)
    assert_equal(document.as_int64(lookup.find(document, "key39")), 39)
    assert_equal(document.as_int64(lookup.find(document, "key0")), 0)
    assert_equal(document.string_value(lookup.find(document, "key7")), "last")
    assert_equal(document.key(lookup.find(document, "esca")), "esca")
    assert_equal(lookup.find(document, "missing"), NO_NODE)
    assert_equal(lookup.find(document, ""), NO_NODE)
    var empty = must_parse("{}")
    var none = JsonObjectIndex(empty, empty.root)
    assert_equal(none.find(empty, "a"), NO_NODE)


def test_hex_and_codepoints() raises:
    var digits = "09afAFgG/:@`"
    var values = List[Int]()
    for byte in digits.as_bytes():
        values.append(hex_value(byte))
    assert_equal(len(values), 12)
    var expected: List[Int] = [0, 9, 10, 15, 10, 15, -1, -1, -1, -1, -1, -1]
    for index in range(12):
        assert_equal(values[index], expected[index])
    var text = "12aF".as_bytes()
    assert_equal(read_hex4(text, 0), 0x12AF)
    assert_equal(read_hex4("12x4".as_bytes(), 0), -1)
    var out = List[UInt8]()
    append_codepoint(out, 0x41)
    append_codepoint(out, 0xE9)
    append_codepoint(out, 0x20AC)
    append_codepoint(out, 0x1F600)
    assert_equal(String(unsafe_from_utf8=out^), "Aé€\U0001F600")


def test_decode_string() raises:
    var text = String(
        'ab\\"\\\\\\/\\b\\f\\n\\r\\t\\u00e9\\uD83D\\uDE00\\uE000z'
    )
    var out = List[UInt8]()
    decode_string(text.as_bytes(), 0, text.byte_length(), out)
    assert_equal(
        String(unsafe_from_utf8=out^),
        'ab"\\/\x08\x0c\n\r\té\U0001F600z',
    )
    var plain = List[UInt8]()
    decode_string("abc".as_bytes(), 0, 3, plain)
    assert_equal(len(plain), 3)


def test_number_end() raises:
    var texts: List[String] = [
        "0",
        "-0",
        "12",
        "1.5",
        "1e5",
        "1E+5",
        "1e-5",
        "0x",
        "-",
        "",
        "-x",
        "1.",
        "1e",
        "1e+",
        "01",
        "1.5]",
        ".5",
    ]
    var ends: List[Int] = [
        1,
        2,
        2,
        3,
        3,
        4,
        4,
        1,
        -1,
        -1,
        -1,
        -1,
        -1,
        -1,
        1,
        3,
        -1,
    ]
    for index in range(len(texts)):
        assert_equal(
            number_end(texts[index].as_bytes(), 0), ends[index], texts[index]
        )


def test_is_canonical_number() raises:
    var canonical: List[String] = ["0", "12", "-12", "123456789012345"]
    for text in canonical:
        assert_true(is_canonical_number(text.as_bytes()), text)
    var other: List[String] = ["-0", "1234567890123456", "1.5", "1e2", "-1.0"]
    for text in other:
        assert_false(is_canonical_number(text.as_bytes()), text)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_json.writer`: the streaming `JsonWriter`, string escapes,
and `stringify` of parsed and built documents.

Each expected text is what Node.js `JSON.stringify` writes for the same
value.
"""

from std.testing import TestSuite, assert_equal, assert_true

from _fixtures import must_parse
from gql_json.value import JsonDocument
from gql_json.writer import JsonWriter, stringify, stringify_bytes, write_string


def _escaped(text: StringSlice) -> String:
    var out = List[UInt8]()
    write_string(out, text.as_bytes())
    return String(unsafe_from_utf8=out^)


def test_write_string_escapes() raises:
    assert_equal(_escaped(""), '""')
    assert_equal(_escaped("plain"), '"plain"')
    assert_equal(
        _escaped('"\\\x08\x0c\n\r\t\x01\x1f\x7f'),
        '"\\"\\\\\\b\\f\\n\\r\\t\\u0001\\u001f\x7f"',
    )
    # U+2028, U+2029 and other code points stay as UTF-8.
    assert_equal(_escaped("  é"), '"  é"')
    # Runs longer than one SIMD block, with an escape inside and after.
    var long = String("a") * 40 + "\n" + String("b") * 40 + '"'
    assert_equal(
        _escaped(long),
        '"' + String("a") * 40 + "\\n" + String("b") * 40 + '\\""',
    )


def test_writer_compact() raises:
    var writer = JsonWriter()
    writer.begin_object()
    writer.key("a")
    writer.int(1)
    writer.key("b\n")
    writer.begin_array()
    writer.float(1.5)
    writer.float(1e21)
    writer.bool(True)
    writer.bool(False)
    writer.null()
    writer.string("x")
    writer.raw('{"r":[]}')
    writer.begin_object()
    writer.end_object()
    writer.begin_array()
    writer.end_array()
    writer.end_array()
    writer.end_object()
    assert_equal(
        writer^.take_string(),
        '{"a":1,"b\\n":[1.5,1e+21,true,false,null,"x",{"r":[]},{},[]]}',
    )


def test_writer_indent() raises:
    var writer = JsonWriter(indent=2)
    writer.begin_object()
    writer.key("a")
    writer.begin_array()
    writer.int(1)
    writer.begin_object()
    writer.end_object()
    writer.end_array()
    writer.key("b")
    writer.string("c")
    writer.end_object()
    assert_equal(
        writer^.take_string(),
        '{\n  "a": [\n    1,\n    {}\n  ],\n  "b": "c"\n}',
    )


def test_writer_indent_is_clamped() raises:
    var wide = JsonWriter(indent=40)
    wide.begin_array()
    wide.int(1)
    wide.end_array()
    assert_equal(wide^.take_string(), "[\n" + String(" ") * 10 + "1\n]")
    var negative = JsonWriter(indent=-3)
    negative.begin_array()
    negative.int(1)
    negative.end_array()
    assert_equal(negative^.take_string(), "[1]")


def test_writer_clear_and_bytes() raises:
    var writer = JsonWriter(capacity=4)
    writer.begin_array()
    writer.int(1)
    writer.clear()
    writer.int(-7)
    var bytes = writer^.take_bytes()
    assert_equal(String(unsafe_from_utf8=bytes^), "-7")


def test_writer_value() raises:
    var document = must_parse('{"k": [1, {"z": null}], "e": []}')
    var writer = JsonWriter(indent=2)
    writer.begin_array()
    writer.value(document, document.root)
    writer.value(document, document.find(document.root, "e"))
    writer.end_array()
    assert_equal(
        writer^.take_string(),
        (
            '[\n  {\n    "k": [\n      1,\n      {\n        "z": null\n     '
            ' }\n    ],\n    "e": []\n  },\n  []\n]'
        ),
    )
    var compact = JsonWriter()
    compact.begin_object()
    compact.key("v")
    compact.value(document, document.root)
    compact.end_object()
    assert_equal(compact^.take_string(), '{"v":{"k":[1,{"z":null}],"e":[]}}')


def test_stringify_scalars() raises:
    var texts: List[String] = [
        '"plain"',
        '"a\\u0041\\/"',
        "true",
        "false",
        "null",
        "12",
        "1.50",
        "-0",
        "1E2",
    ]
    var expected: List[String] = [
        '"plain"',
        '"aA/"',
        "true",
        "false",
        "null",
        "12",
        "1.5",
        "0",
        "100",
    ]
    for index in range(len(texts)):
        var document = must_parse(texts[index])
        assert_equal(stringify(document, document.root), expected[index])


def test_stringify_reescapes() raises:
    var document = must_parse(
        '["\\u0001\\u001F\\u0022\\u005c\\u00e9\\uD83D\\uDE00\\/\\n\\"\\\\",'
        ' {"\\u006Bey\\n": "\\t"}]'
    )
    assert_equal(
        stringify(document, document.root),
        '["\\u0001\\u001f\\"\\\\é\U0001F600/\\n\\"\\\\",{"key\\n":"\\t"}]',
    )


def test_stringify_built_document() raises:
    var document = JsonDocument()
    var root = document.add_object()
    document.root = root
    document.add_member(root, "t\tab", document.add_string("line\nbreak"))
    document.add_member(root, "n", document.add_float(-2.5e-7))
    document.add_member(root, "plain", document.add_string("ok"))
    assert_equal(
        stringify(document, root),
        '{"t\\tab":"line\\nbreak","n":-2.5e-7,"plain":"ok"}',
    )
    assert_equal(
        stringify(document, root, 1),
        '{\n "t\\tab": "line\\nbreak",\n "n": -2.5e-7,\n "plain": "ok"\n}',
    )


def test_stringify_copy_sizes() raises:
    # Keys and strings of each copy size, from a document with no spare
    # bytes after its text and from a parsed one.
    var parts = List[String]()
    var lengths: List[Int] = [0, 3, 8, 12, 16, 20, 32, 33, 70]
    for ref length in lengths:
        var text = String("k") * length
        parts.append('"' + text + '":"' + String("v") * length + '"')
    var source = "{" + ",".join(parts) + "}"
    var parsed = must_parse(source)
    assert_equal(stringify(parsed, parsed.root), source)
    var tight_bytes = List[UInt8](capacity=len(parsed.bytes))
    tight_bytes.extend(Span(parsed.bytes))
    var tight = JsonDocument(tight_bytes^, parsed.nodes.copy())
    assert_equal(stringify(tight, tight.root), source)
    var numbers = must_parse("[1, 12345678, 123456789012345]")
    var tight_numbers_bytes = List[UInt8](capacity=len(numbers.bytes))
    tight_numbers_bytes.extend(Span(numbers.bytes))
    var tight_numbers = JsonDocument(tight_numbers_bytes^, numbers.nodes.copy())
    assert_equal(
        stringify(tight_numbers, tight_numbers.root),
        "[1,12345678,123456789012345]",
    )


def test_stringify_large_output() raises:
    # The output buffer grows many times.
    var text = (
        String("[") + ",".join(List[String](length=2000, fill='"abc"')) + "]"
    )
    var document = must_parse(text)
    var out = stringify_bytes(document, document.root, 3)
    assert_true(len(out) > 2000 * 8)
    assert_equal(
        stringify(document, document.root),
        String("[") + ",".join(List[String](length=2000, fill='"abc"')) + "]",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

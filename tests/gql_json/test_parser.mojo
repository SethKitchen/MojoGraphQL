# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_json.parser` and `gql_json.error`: the error of each
refusal, its position, and the limits.

The JSONTestSuite (`test_suite.mojo`) checks which texts parse. These tests
check what the parser says about the texts that do not.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _fixtures import must_parse, parse_error
from gql_json.error import JsonError
from gql_json.parser import MAX_LENGTH, parse, parse_bytes
from gql_json.value import JsonKind


def _bytes_error(var bytes: List[UInt8]) raises -> JsonError:
    try:
        _ = parse_bytes(bytes^)
    except e:
        return e^
    raise Error("expected a parse error")


def _check(
    text: StringSlice, message: StringSlice, offset: Int, max_depth: Int = 1000
) raises:
    var error = parse_error(text, max_depth)
    assert_equal(error.message, String(message), String(text))
    assert_equal(error.offset, offset, String(text))


def test_unexpected_characters() raises:
    _check("", "Unexpected end of input", 0)
    _check("   ", "Unexpected end of input", 3)
    _check("[1", "Unexpected end of input", 2)
    _check("[1,]", "Unexpected character ']'", 3)
    _check("[1 2]", "Unexpected character '2'", 3)
    _check('{"a":1]', "Unexpected character ']'", 6)
    _check('{"a":1,}', "Unexpected character '}'", 7)
    _check("{1:2}", "Unexpected character '1'", 1)
    _check('{"a" 1}', "Unexpected character '1'", 5)
    _check("1 2", "Unexpected character '2'", 2)
    _check("01", "Unexpected character '1'", 1)
    _check("x", "Unexpected character 'x'", 0)
    _check("tru", "Unexpected character 't'", 0)
    _check("trUe", "Unexpected character 't'", 0)
    _check("fals", "Unexpected character 'f'", 0)
    _check("nul", "Unexpected character 'n'", 0)
    _check("[\x01]", "Unexpected byte 0x1", 1)
    _check("[é]", "Unexpected byte 0xc3", 1)


def test_invalid_numbers() raises:
    _check("-", "Invalid number", 0)
    _check("-a", "Invalid number", 0)
    _check("[1.]", "Invalid number", 1)
    _check("1.e2", "Invalid number", 0)
    _check("1e", "Invalid number", 0)
    _check("1e+", "Invalid number", 0)
    var document = must_parse("[-0, 1.5e+3, 2E-2, 0.25]")
    assert_equal(document.length(document.root), 4)


def test_invalid_strings() raises:
    _check('"abc', "Unterminated string", 0)
    _check('["a\tb"]', "Control character in a string", 3)
    _check('"\\x"', "Invalid escape", 1)
    _check('"\\u12G4"', "Invalid \\u escape", 1)
    _check('"\\u12"', "Invalid \\u escape", 1)
    _check('"\\uDC00"', "Lone surrogate in a \\u escape", 1)
    _check('"\\uD800"', "Lone surrogate in a \\u escape", 1)
    _check('"\\uD800a"', "Lone surrogate in a \\u escape", 1)
    _check('"\\uD800\\n"', "Lone surrogate in a \\u escape", 1)
    _check('"\\uD800\\u0041"', "Lone surrogate in a \\u escape", 1)
    _check('"\\uD800\\uE000"', "Lone surrogate in a \\u escape", 1)
    var document = must_parse(
        '["\\"\\\\\\/\\b\\f\\n\\r\\t", "\\u0041\\uE000\\uD83D\\uDE00",'
        ' "\\uabcd\\uABCD\\u09af"]'
    )
    assert_equal(document.length(document.root), 3)


def test_invalid_utf8() raises:
    # Each list is one string body after a quote; each must be refused.
    var bad: List[List[UInt8]] = [
        [0x80],  # a continuation byte first
        [0xC0, 0x80],  # an overlong form of U+0000
        [0xC2, 0x41],  # a missing continuation
        [0xE0, 0x9F, 0x80],  # an overlong 3-byte form
        [0xED, 0xA0, 0x80],  # a surrogate
        [0xE1, 0x80, 0x41],  # a bad third byte
        [0xE1, 0xC0, 0x80],  # a bad second byte
        [0xF0, 0x8F, 0x80, 0x80],  # an overlong 4-byte form
        [0xF4, 0x90, 0x80, 0x80],  # above U+10FFFF
        [0xF1, 0x80, 0x41, 0x80],  # a bad third byte
        [0xF1, 0x80, 0x80, 0x41],  # a bad fourth byte
        [0xF1, 0xC0, 0x80, 0x80],  # a bad second byte
        [0xF5, 0x80, 0x80, 0x80],  # no such lead byte
    ]
    for ref body in bad:
        var bytes: List[UInt8] = [0x22]
        bytes.extend(Span(body))
        bytes.append(0x22)
        var error = _bytes_error(bytes^)
        assert_equal(error.message, "Invalid UTF-8")
        assert_equal(error.offset, 1)
    var good: List[UInt8] = [
        0x22,
        0xC2,
        0x80,
        0xE0,
        0xA0,
        0x80,
        0xED,
        0x9F,
        0xBF,
        0xEF,
        0xBF,
        0xBF,
        0xF0,
        0x90,
        0x80,
        0x80,
        0xF4,
        0x8F,
        0xBF,
        0xBF,
        0x22,
    ]
    var document = parse_bytes(good^)
    assert_equal(document.kind(document.root), JsonKind.STRING)


def test_error_position() raises:
    var error = parse_error('{\n  "a": tru\n}')
    assert_equal(error.line, 2)
    assert_equal(error.column, 8)
    assert_equal(error.offset, 9)
    assert_equal(
        String(error), "Unexpected character 't' at line 2, column 8 (byte 9)"
    )
    # CR LF is one line break, and a lone CR is one too.
    var crlf = parse_error("[\r\n1,\r\n]")
    assert_equal(crlf.line, 3)
    assert_equal(crlf.column, 1)
    var cr = parse_error("[\r1,\r]")
    assert_equal(cr.line, 3)
    var trailing = parse_error("[1,\r")
    assert_equal(trailing.line, 2)
    assert_equal(trailing.column, 1)
    # The column counts code points.
    var wide = parse_error('["é", x]')
    assert_equal(wide.offset, 7)
    assert_equal(wide.column, 7)


def test_error_without_position() raises:
    var error = JsonError("No member named a")
    assert_equal(error.offset, -1)
    assert_equal(error.line, 0)
    assert_equal(String(error), "No member named a")


def test_max_depth() raises:
    _check("[[[]]]", "The input nests too deeply", 2, max_depth=2)
    var document = parse("[[[]]]", max_depth=3)
    assert_equal(document.length(document.root), 1)
    _check('{"a":{}}', "The input nests too deeply", 5, max_depth=1)
    _check("[]", "The input nests too deeply", 0, max_depth=0)
    var scalar = parse("7", max_depth=0)
    assert_equal(scalar.kind(scalar.root), JsonKind.NUMBER)
    var negative = parse_error("1", max_depth=-1)
    assert_equal(negative.message, "max_depth must not be negative: -1")
    # A deep input does not overflow the call stack.
    var deep = String("[") * 1500 + String("]") * 1500
    _check(deep, "The input nests too deeply", 1000)
    var parsed = parse(deep, max_depth=1500)
    assert_equal(len(parsed.nodes), 1500)


def test_max_length() raises:
    var refused = False
    try:
        _ = parse("[1, 2]", max_length=5)
    except e:
        refused = True
        assert_equal(
            e.message, "The input is too large: 6 bytes; the limit is 5"
        )
    assert_true(refused)
    var document = parse("[1, 2]", max_length=6)
    assert_equal(document.length(document.root), 2)
    var large = parse("[]", max_length=Int.MAX)
    assert_equal(large.length(large.root), 0)
    assert_true(MAX_LENGTH < 2_147_483_647)


def test_white_space() raises:
    var document = must_parse(' \t\r\n{ "a" : [ 1 , 2 ] } \n')
    assert_equal(document.kind(document.root), JsonKind.OBJECT)
    # A long run of white space, past one SIMD block.
    var spaced = String(" ") * 100 + "true" + String("\n") * 70
    var flag = must_parse(spaced)
    assert_true(flag.bool_value(flag.root))


def test_long_strings() raises:
    # Strings longer than one SIMD block, with escapes and UTF-8 after it.
    var text = String('"') + String("a") * 70 + "\\n" + String("é") * 40 + '"'
    var document = must_parse(text)
    assert_true(document.has_escapes(document.root))
    assert_equal(
        document.string_value(document.root),
        String("a") * 70 + "\n" + String("é") * 40,
    )


def test_an_item_after_an_object_has_no_key() raises:
    var document = must_parse('[{"k\\n": 1}, 2]')
    var second = document.at(document.root, 1)
    assert_equal(document.raw_key(second), "")
    assert_equal(document.key(second), "")
    assert_false(document.key_equals(second, "k\n"))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

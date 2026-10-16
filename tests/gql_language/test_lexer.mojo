# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_language.lexer`, ported from graphql-js 16.14.2
`src/language/__tests__/lexer-test.ts`.

Token offsets are UTF-8 bytes here and UTF-16 units in graphql-js; the two
differ only where a test has a non-ASCII character, and those tests say so.
Lines and columns are the same. The lone-surrogate cases of graphql-js have
no Mojo equivalent: a Mojo string is valid UTF-8.
"""

from gql_language.error import GraphQLError
from gql_language.lexer import (
    Lexer,
    Token,
    read_comments,
    token_description,
    token_value,
)
from gql_language.source import Source, SourceLocation
from gql_language.token_kind import TokenKind
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def lex_one(text: StringSlice) raises -> Token:
    """Return the first token of a text."""
    var lexer = Lexer(Source(text))
    return lexer.advance()


def value_of(text: StringSlice) raises -> String:
    """Return the value of the first token of a text."""
    var source = Source(text)
    var lexer = Lexer(source.copy())
    return token_value(source, lexer.advance())


def expect_token(
    text: StringSlice, kind: TokenKind, start: Int, end: Int, value: String
) raises:
    """Assert the first token of a text."""
    var source = Source(text)
    var lexer = Lexer(source.copy())
    var token = lexer.advance()
    assert_equal(token.kind, kind)
    assert_equal(token.start, start)
    assert_equal(token.end, end)
    assert_equal(token_value(source, token), value)


def expect_error(text: StringSlice, message: String, column: Int) raises:
    """Assert that lexing a text fails at line 1."""
    expect_error_at(text, message, 1, column)


def expect_error_at(
    text: StringSlice, message: String, line: Int, column: Int
) raises:
    """Assert that lexing the first two tokens of a text fails, as
    graphql-js `lexSecond`."""
    var lexer = Lexer(Source(text))
    try:
        _ = lexer.advance()
        _ = lexer.advance()
    except error:
        assert_equal(error.message, message)
        assert_equal(len(error.locations), 1)
        assert_equal(error.locations[0], SourceLocation(line, column))
        return
    raise Error("expected a syntax error for: " + String(text))


def location_of(text: StringSlice) raises -> SourceLocation:
    """Return the line and column of the first token of a text."""
    var source = Source(text)
    var lexer = Lexer(source.copy())
    return source.get_location(lexer.advance().start)


def test_ignores_bom_header() raises:
    # The BOM is three bytes in UTF-8 and one unit in UTF-16.
    expect_token("﻿ foo", TokenKind.NAME, 4, 7, "foo")


def test_tracks_line_breaks() raises:
    expect_token("foo", TokenKind.NAME, 0, 3, "foo")
    assert_equal(location_of("foo"), SourceLocation(1, 1))
    expect_token("\nfoo", TokenKind.NAME, 1, 4, "foo")
    assert_equal(location_of("\nfoo"), SourceLocation(2, 1))
    expect_token("\rfoo", TokenKind.NAME, 1, 4, "foo")
    assert_equal(location_of("\rfoo"), SourceLocation(2, 1))
    expect_token("\r\nfoo", TokenKind.NAME, 2, 5, "foo")
    assert_equal(location_of("\r\nfoo"), SourceLocation(2, 1))
    expect_token("\n\rfoo", TokenKind.NAME, 2, 5, "foo")
    assert_equal(location_of("\n\rfoo"), SourceLocation(3, 1))
    expect_token("\r\r\n\nfoo", TokenKind.NAME, 4, 7, "foo")
    assert_equal(location_of("\r\r\n\nfoo"), SourceLocation(4, 1))
    expect_token("\n\n\r\rfoo", TokenKind.NAME, 4, 7, "foo")
    assert_equal(location_of("\n\n\r\rfoo"), SourceLocation(5, 1))


def test_records_line_and_column() raises:
    expect_token("\n \r\n \r  foo\n", TokenKind.NAME, 8, 11, "foo")
    assert_equal(location_of("\n \r\n \r  foo\n"), SourceLocation(4, 3))


def test_writes_tokens_and_kinds() raises:
    var token = lex_one("foo")
    assert_equal(String(token), "Name[0:3]")
    assert_equal(String(TokenKind.SPREAD), "...")
    assert_equal(TokenKind.BRACE_L.description(), '"{"')
    assert_equal(TokenKind.NAME.description(), "Name")
    assert_false(TokenKind(23).is_valid())
    assert_equal(String(TokenKind(23).text()), "<invalid>")


def test_skips_whitespace_and_comments() raises:
    expect_token("\n\n    foo\n\n\n", TokenKind.NAME, 6, 9, "foo")
    expect_token("\t\tfoo\t\t", TokenKind.NAME, 2, 5, "foo")
    expect_token(
        "\n    #comment\n    foo#comment\n", TokenKind.NAME, 18, 21, "foo"
    )
    expect_token(",,,foo,,,", TokenKind.NAME, 3, 6, "foo")


def test_errors_respect_whitespace() raises:
    var lexer = Lexer(Source("\n\n ~\n"))
    try:
        _ = lexer.advance()
    except error:
        assert_equal(
            String(error),
            'Syntax Error: Unexpected character: "~".\n\n'
            + "GraphQL request:3:2\n"
            + "2 |\n"
            + "3 |  ~\n"
            + "  |  ^\n"
            + "4 |",
        )
        return
    raise Error("expected an error")


def test_updates_line_numbers_in_error_for_file_context() raises:
    var lexer = Lexer(Source("\n\n     ~\n", "foo.js", SourceLocation(11, 12)))
    try:
        _ = lexer.advance()
    except error:
        assert_equal(
            String(error),
            'Syntax Error: Unexpected character: "~".\n\n'
            + "foo.js:13:6\n"
            + "12 |\n"
            + "13 |      ~\n"
            + "   |      ^\n"
            + "14 |",
        )
        return
    raise Error("expected an error")


def test_updates_column_numbers_in_error_for_file_context() raises:
    var lexer = Lexer(Source("~", "foo.js", SourceLocation(1, 5)))
    try:
        _ = lexer.advance()
    except error:
        assert_equal(
            String(error),
            'Syntax Error: Unexpected character: "~".\n\n'
            + "foo.js:1:5\n"
            + "1 |     ~\n"
            + "  |     ^",
        )
        return
    raise Error("expected an error")


def test_source_rejects_bad_offsets() raises:
    var raised = False
    try:
        _ = Source("x", "a", SourceLocation(0, 1))
    except e:
        raised = True
        assert_equal(
            String(e),
            "line in locationOffset is 1-indexed and must be positive.",
        )
    assert_true(raised)
    raised = False
    try:
        _ = Source("x", "a", SourceLocation(1, 0))
    except e:
        raised = True
        assert_equal(
            String(e),
            "column in locationOffset is 1-indexed and must be positive.",
        )
    assert_true(raised)


def test_lexes_strings() raises:
    expect_token('""', TokenKind.STRING, 0, 2, "")
    expect_token('"simple"', TokenKind.STRING, 0, 8, "simple")
    expect_token('" white space "', TokenKind.STRING, 0, 15, " white space ")
    expect_token('"quote \\""', TokenKind.STRING, 0, 10, 'quote "')
    expect_token(
        '"escaped \\n\\r\\b\\t\\f"',
        TokenKind.STRING,
        0,
        20,
        "escaped \n\r\x08\t\x0c",
    )
    expect_token('"slashes \\\\ \\/"', TokenKind.STRING, 0, 15, "slashes \\ /")
    # UTF-8: the emoji is four bytes, so the end is 36 and not 34.
    expect_token(
        '"unescaped unicode outside BMP \U0001f600"',
        TokenKind.STRING,
        0,
        36,
        "unescaped unicode outside BMP \U0001f600",
    )
    expect_token(
        '"unescaped maximal unicode outside BMP \U0010ffff"',
        TokenKind.STRING,
        0,
        44,
        "unescaped maximal unicode outside BMP \U0010ffff",
    )
    expect_token(
        '"unicode \\u1234\\u5678\\u90AB\\uCDEF"',
        TokenKind.STRING,
        0,
        34,
        "unicode ሴ噸邫췯",
    )
    expect_token(
        '"unicode \\u{1234}\\u{5678}\\u{90AB}\\u{CDEF}"',
        TokenKind.STRING,
        0,
        42,
        "unicode ሴ噸邫췯",
    )
    expect_token(
        '"string with unicode escape outside BMP \\u{1F600}"',
        TokenKind.STRING,
        0,
        50,
        "string with unicode escape outside BMP \U0001f600",
    )
    expect_token(
        '"string with minimal unicode escape \\u{0}"',
        TokenKind.STRING,
        0,
        42,
        "string with minimal unicode escape \x00",
    )
    expect_token(
        '"string with maximal unicode escape \\u{10FFFF}"',
        TokenKind.STRING,
        0,
        47,
        "string with maximal unicode escape \U0010ffff",
    )
    expect_token(
        '"string with maximal minimal unicode escape \\u{00000000}"',
        TokenKind.STRING,
        0,
        57,
        "string with maximal minimal unicode escape \x00",
    )
    expect_token(
        '"string with unicode surrogate pair escape \\uD83D\\uDE00"',
        TokenKind.STRING,
        0,
        56,
        "string with unicode surrogate pair escape \U0001f600",
    )
    expect_token(
        '"string with minimal surrogate pair escape \\uD800\\uDC00"',
        TokenKind.STRING,
        0,
        56,
        "string with minimal surrogate pair escape \U00010000",
    )
    expect_token(
        '"string with maximal surrogate pair escape \\uDBFF\\uDFFF"',
        TokenKind.STRING,
        0,
        56,
        "string with maximal surrogate pair escape \U0010ffff",
    )


def test_lex_reports_useful_string_errors() raises:
    expect_error('"', "Syntax Error: Unterminated string.", 2)
    expect_error('"""', "Syntax Error: Unterminated string.", 4)
    expect_error('""""', "Syntax Error: Unterminated string.", 5)
    expect_error('"no end quote', "Syntax Error: Unterminated string.", 14)
    expect_error(
        "'single quotes'",
        (
            "Syntax Error: Unexpected single quote character ('), did you mean"
            ' to use a double quote (")?'
        ),
        1,
    )
    expect_error('"multi\nline"', "Syntax Error: Unterminated string.", 7)
    expect_error('"multi\rline"', "Syntax Error: Unterminated string.", 7)
    expect_error(
        '"bad \\z esc"',
        'Syntax Error: Invalid character escape sequence: "\\z".',
        6,
    )
    expect_error(
        '"bad \\x esc"',
        'Syntax Error: Invalid character escape sequence: "\\x".',
        6,
    )
    expect_error(
        '"bad \\u1 esc"',
        'Syntax Error: Invalid Unicode escape sequence: "\\u1 es".',
        6,
    )
    expect_error(
        '"bad \\u0XX1 esc"',
        'Syntax Error: Invalid Unicode escape sequence: "\\u0XX1".',
        6,
    )
    expect_error(
        '"bad \\uXXXX esc"',
        'Syntax Error: Invalid Unicode escape sequence: "\\uXXXX".',
        6,
    )
    expect_error(
        '"bad \\uFXXX esc"',
        'Syntax Error: Invalid Unicode escape sequence: "\\uFXXX".',
        6,
    )
    expect_error(
        '"bad \\uXXXF esc"',
        'Syntax Error: Invalid Unicode escape sequence: "\\uXXXF".',
        6,
    )
    expect_error(
        '"bad \\u{} esc"',
        'Syntax Error: Invalid Unicode escape sequence: "\\u{}".',
        6,
    )
    expect_error(
        '"bad \\u{FXXX} esc"',
        'Syntax Error: Invalid Unicode escape sequence: "\\u{FX".',
        6,
    )
    expect_error(
        '"bad \\u{FFFF esc"',
        'Syntax Error: Invalid Unicode escape sequence: "\\u{FFFF ".',
        6,
    )
    expect_error(
        '"bad \\u{FFFF"',
        'Syntax Error: Invalid Unicode escape sequence: "\\u{FFFF"".',
        6,
    )
    expect_error(
        '"too high \\u{110000} esc"',
        'Syntax Error: Invalid Unicode escape sequence: "\\u{110000}".',
        11,
    )
    expect_error(
        '"way too high \\u{12345678} esc"',
        'Syntax Error: Invalid Unicode escape sequence: "\\u{12345678}".',
        15,
    )
    expect_error(
        '"too long \\u{000000000} esc"',
        'Syntax Error: Invalid Unicode escape sequence: "\\u{000000000".',
        11,
    )
    expect_error(
        '"bad surrogate \\uDEAD esc"',
        'Syntax Error: Invalid Unicode escape sequence: "\\uDEAD".',
        16,
    )
    expect_error(
        '"bad surrogate \\u{DEAD} esc"',
        'Syntax Error: Invalid Unicode escape sequence: "\\u{DEAD}".',
        16,
    )
    expect_error(
        '"cannot use braces for surrogate pair \\u{D83D}\\u{DE00} esc"',
        'Syntax Error: Invalid Unicode escape sequence: "\\u{D83D}".',
        39,
    )
    expect_error(
        '"bad high surrogate pair \\uDEAD\\uDEAD esc"',
        'Syntax Error: Invalid Unicode escape sequence: "\\uDEAD".',
        26,
    )
    expect_error(
        '"bad low surrogate pair \\uD800\\uD800 esc"',
        'Syntax Error: Invalid Unicode escape sequence: "\\uD800".',
        25,
    )
    expect_error(
        '"bad \\uD83D\\not an escape"',
        'Syntax Error: Invalid Unicode escape sequence: "\\uD83D".',
        6,
    )


def test_escape_errors_at_the_end_and_after_overflow() raises:
    # The escape is cut at the end of the source.
    expect_error(
        '"\\u12',
        'Syntax Error: Invalid Unicode escape sequence: "\\u12".',
        2,
    )
    expect_error(
        '"\\',
        'Syntax Error: Invalid character escape sequence: "\\".',
        2,
    )
    # graphql-js stops when its 32-bit accumulator turns negative.
    expect_error(
        '"\\u{FFFFFFFFF}"',
        'Syntax Error: Invalid Unicode escape sequence: "\\u{FFFFFFFF".',
        2,
    )
    # Bits shifted past 32 are lost, as in graphql-js.
    expect_error(
        '"\\u{100000001}"',
        'Syntax Error: Invalid Unicode escape sequence: "\\u{100000001".',
        2,
    )
    # An escape cut inside a multibyte character keeps it whole.
    expect_error(
        '"\\é"',
        'Syntax Error: Invalid character escape sequence: "\\é".',
        2,
    )


def test_lexes_block_strings() raises:
    expect_token('""""""', TokenKind.BLOCK_STRING, 0, 6, "")
    expect_token('"""simple"""', TokenKind.BLOCK_STRING, 0, 12, "simple")
    expect_token(
        '""" white space """', TokenKind.BLOCK_STRING, 0, 19, " white space "
    )
    expect_token(
        '"""contains " quote"""',
        TokenKind.BLOCK_STRING,
        0,
        22,
        'contains " quote',
    )
    expect_token(
        '"""contains \\""" triple quote"""',
        TokenKind.BLOCK_STRING,
        0,
        32,
        'contains """ triple quote',
    )
    expect_token(
        '"""multi\nline"""', TokenKind.BLOCK_STRING, 0, 16, "multi\nline"
    )
    expect_token(
        '"""multi\rline\r\nnormalized"""',
        TokenKind.BLOCK_STRING,
        0,
        28,
        "multi\nline\nnormalized",
    )
    expect_token(
        '"""unescaped \\n\\r\\b\\t\\f\\u1234"""',
        TokenKind.BLOCK_STRING,
        0,
        32,
        "unescaped \\n\\r\\b\\t\\f\\u1234",
    )
    # UTF-8: the end is 40 and not 38.
    expect_token(
        '"""unescaped unicode outside BMP \U0001f600"""',
        TokenKind.BLOCK_STRING,
        0,
        40,
        "unescaped unicode outside BMP \U0001f600",
    )
    expect_token(
        '"""slashes \\\\ \\/"""',
        TokenKind.BLOCK_STRING,
        0,
        19,
        "slashes \\\\ \\/",
    )
    expect_token(
        '"""\n\n        spans\n          multiple\n            lines\n\n'
        + '        """',
        TokenKind.BLOCK_STRING,
        0,
        68,
        "spans\n  multiple\n    lines",
    )


def test_advance_line_after_lexing_multiline_block_string() raises:
    var text = (
        '"""\n\n        spans\n          multiple\n            lines\n\n'
        + '        \n """ second_token'
    )
    var source = Source(text)
    var lexer = Lexer(source.copy())
    _ = lexer.advance()
    var token = lexer.advance()
    assert_equal(token.start, 71)
    assert_equal(token.end, 83)
    assert_equal(token_value(source, token), "second_token")
    assert_equal(source.get_location(token.start), SourceLocation(8, 6))
    var second = '""" \nspans \r\nmultiple \n\rlines \n\n"""\n second_token'
    var source2 = Source(second)
    var lexer2 = Lexer(source2.copy())
    _ = lexer2.advance()
    var token2 = lexer2.advance()
    assert_equal(token2.start, 37)
    assert_equal(token2.end, 49)
    assert_equal(source2.get_location(token2.start), SourceLocation(8, 2))


def test_lex_reports_useful_block_string_errors() raises:
    expect_error('"""', "Syntax Error: Unterminated string.", 4)
    expect_error('"""no end quote', "Syntax Error: Unterminated string.", 16)
    expect_error('"""a \\"" b', "Syntax Error: Unterminated string.", 11)


def test_lexes_numbers() raises:
    expect_token("4", TokenKind.INT, 0, 1, "4")
    expect_token("4.123", TokenKind.FLOAT, 0, 5, "4.123")
    expect_token("-4", TokenKind.INT, 0, 2, "-4")
    expect_token("9", TokenKind.INT, 0, 1, "9")
    expect_token("0", TokenKind.INT, 0, 1, "0")
    expect_token("-4.123", TokenKind.FLOAT, 0, 6, "-4.123")
    expect_token("0.123", TokenKind.FLOAT, 0, 5, "0.123")
    expect_token("123e4", TokenKind.FLOAT, 0, 5, "123e4")
    expect_token("123E4", TokenKind.FLOAT, 0, 5, "123E4")
    expect_token("123e-4", TokenKind.FLOAT, 0, 6, "123e-4")
    expect_token("123e+4", TokenKind.FLOAT, 0, 6, "123e+4")
    expect_token("-1.123e4", TokenKind.FLOAT, 0, 8, "-1.123e4")
    expect_token("-1.123E4", TokenKind.FLOAT, 0, 8, "-1.123E4")
    expect_token("-1.123e-4", TokenKind.FLOAT, 0, 9, "-1.123e-4")
    expect_token("-1.123e+4", TokenKind.FLOAT, 0, 9, "-1.123e+4")
    expect_token("-1.123e4567", TokenKind.FLOAT, 0, 11, "-1.123e4567")


def test_lex_reports_useful_number_errors() raises:
    expect_error(
        "00", 'Syntax Error: Invalid number, unexpected digit after 0: "0".', 2
    )
    expect_error(
        "01", 'Syntax Error: Invalid number, unexpected digit after 0: "1".', 2
    )
    expect_error(
        "01.23",
        'Syntax Error: Invalid number, unexpected digit after 0: "1".',
        2,
    )
    expect_error("+1", 'Syntax Error: Unexpected character: "+".', 1)
    expect_error(
        "1.", "Syntax Error: Invalid number, expected digit but got: <EOF>.", 3
    )
    expect_error(
        "1e", "Syntax Error: Invalid number, expected digit but got: <EOF>.", 3
    )
    expect_error(
        "1E", "Syntax Error: Invalid number, expected digit but got: <EOF>.", 3
    )
    expect_error(
        "1.e1", 'Syntax Error: Invalid number, expected digit but got: "e".', 3
    )
    expect_error(".123", 'Syntax Error: Unexpected character: ".".', 1)
    expect_error(
        "1.A", 'Syntax Error: Invalid number, expected digit but got: "A".', 3
    )
    expect_error(
        "-A", 'Syntax Error: Invalid number, expected digit but got: "A".', 2
    )
    expect_error(
        "1.0e",
        "Syntax Error: Invalid number, expected digit but got: <EOF>.",
        5,
    )
    expect_error(
        "1.0eA",
        'Syntax Error: Invalid number, expected digit but got: "A".',
        5,
    )
    expect_error(
        '1.0e"',
        "Syntax Error: Invalid number, expected digit but got: '\"'.",
        5,
    )
    expect_error(
        "1.2e3e",
        'Syntax Error: Invalid number, expected digit but got: "e".',
        6,
    )
    expect_error(
        "1.2e3.4",
        'Syntax Error: Invalid number, expected digit but got: ".".',
        6,
    )
    expect_error(
        "1.23.4",
        'Syntax Error: Invalid number, expected digit but got: ".".',
        5,
    )


def test_lex_does_not_allow_name_start_after_a_number() raises:
    expect_error(
        "0xF1", 'Syntax Error: Invalid number, expected digit but got: "x".', 2
    )
    expect_error(
        "0b10", 'Syntax Error: Invalid number, expected digit but got: "b".', 2
    )
    expect_error(
        "123abc",
        'Syntax Error: Invalid number, expected digit but got: "a".',
        4,
    )
    expect_error(
        "1_234",
        'Syntax Error: Invalid number, expected digit but got: "_".',
        2,
    )
    expect_error("1ß", "Syntax Error: Unexpected character: U+00DF.", 2)
    expect_error(
        "1.23f",
        'Syntax Error: Invalid number, expected digit but got: "f".',
        5,
    )
    expect_error(
        "1.234_5",
        'Syntax Error: Invalid number, expected digit but got: "_".',
        6,
    )


def test_lexes_punctuation() raises:
    expect_token("!", TokenKind.BANG, 0, 1, "")
    expect_token("$", TokenKind.DOLLAR, 0, 1, "")
    expect_token("&", TokenKind.AMP, 0, 1, "")
    expect_token("(", TokenKind.PAREN_L, 0, 1, "")
    expect_token(")", TokenKind.PAREN_R, 0, 1, "")
    expect_token("...", TokenKind.SPREAD, 0, 3, "")
    expect_token(":", TokenKind.COLON, 0, 1, "")
    expect_token("=", TokenKind.EQUALS, 0, 1, "")
    expect_token("@", TokenKind.AT, 0, 1, "")
    expect_token("[", TokenKind.BRACKET_L, 0, 1, "")
    expect_token("]", TokenKind.BRACKET_R, 0, 1, "")
    expect_token("{", TokenKind.BRACE_L, 0, 1, "")
    expect_token("|", TokenKind.PIPE, 0, 1, "")
    expect_token("}", TokenKind.BRACE_R, 0, 1, "")


def test_lex_reports_useful_unknown_character_error() raises:
    expect_error("..", 'Syntax Error: Unexpected character: ".".', 1)
    expect_error("~", 'Syntax Error: Unexpected character: "~".', 1)
    expect_error("\x00", "Syntax Error: Unexpected character: U+0000.", 1)
    expect_error("\x08", "Syntax Error: Unexpected character: U+0008.", 1)
    expect_error("ª", "Syntax Error: Unexpected character: U+00AA.", 1)
    expect_error("પ", "Syntax Error: Unexpected character: U+0AAA.", 1)
    expect_error("※", "Syntax Error: Unexpected character: U+203B.", 1)
    expect_error(
        "\U0001f600", "Syntax Error: Unexpected character: U+1F600.", 1
    )
    expect_error(
        "\U00010000", "Syntax Error: Unexpected character: U+10000.", 1
    )
    expect_error(
        "\U0010ffff", "Syntax Error: Unexpected character: U+10FFFF.", 1
    )
    # A byte order mark that is not at the start is still ignored, and a
    # character that only starts like one is not.
    expect_token("a﻿", TokenKind.NAME, 0, 1, "a")
    expect_error("", "Syntax Error: Unexpected character: U+F000.", 1)
    expect_error("ﻮ", "Syntax Error: Unexpected character: U+FEEE.", 1)


def test_lex_reports_useful_information_for_dashes_in_names() raises:
    var source = Source("a-b")
    var lexer = Lexer(source.copy())
    var first = lexer.advance()
    assert_equal(first.kind, TokenKind.NAME)
    assert_equal(first.start, 0)
    assert_equal(first.end, 1)
    try:
        _ = lexer.advance()
    except error:
        assert_equal(
            error.message,
            'Syntax Error: Invalid number, expected digit but got: "b".',
        )
        assert_equal(error.locations[0], SourceLocation(1, 3))
        return
    raise Error("expected an error")


def test_advance_stops_at_eof_and_lookahead_caches() raises:
    var lexer = Lexer(Source("{ a }"))
    assert_equal(lexer.token.kind, TokenKind.SOF)
    var ahead = lexer.lookahead()
    assert_equal(ahead.kind, TokenKind.BRACE_L)
    assert_equal(lexer.lookahead().start, ahead.start)
    assert_equal(lexer.advance().kind, TokenKind.BRACE_L)
    assert_equal(lexer.advance().kind, TokenKind.NAME)
    assert_equal(lexer.advance().kind, TokenKind.BRACE_R)
    assert_equal(lexer.advance().kind, TokenKind.EOF)
    assert_equal(lexer.lookahead().kind, TokenKind.EOF)
    assert_equal(lexer.advance().kind, TokenKind.EOF)
    assert_equal(lexer.last_token.kind, TokenKind.EOF)


def test_lexes_comments() raises:
    var comments = read_comments(
        Source("\n      {\n        #comment\n        field\n      }\n    ")
    )
    assert_equal(len(comments), 1)
    assert_equal(comments[0].kind, TokenKind.COMMENT)
    var source = Source("# Comment")
    var found = read_comments(source)
    assert_equal(found[0].start, 0)
    assert_equal(found[0].end, 9)
    assert_equal(token_value(source, found[0]), " Comment")
    var source2 = Source("# Comment\nAnother line")
    assert_equal(read_comments(source2)[0].end, 9)
    var source3 = Source("# Comment\r\nAnother line")
    assert_equal(read_comments(source3)[0].end, 9)
    # UTF-8: the end is 14 and not 12.
    var source4 = Source("# Comment \U0001f600")
    var emoji = read_comments(source4)
    assert_equal(emoji[0].end, 14)
    assert_equal(token_value(source4, emoji[0]), " Comment \U0001f600")
    var many = read_comments(Source('#a\n"#not" #b\r#c'))
    assert_equal(len(many), 3)
    assert_equal(token_description(source, found[0]), 'Comment " Comment"')


def test_token_values_and_descriptions() raises:
    var source = Source('a 1 2.5 "s" """b""" ! ...')
    var lexer = Lexer(source.copy())
    var expected: List[String] = [
        'Name "a"',
        'Int "1"',
        'Float "2.5"',
        'String "s"',
        'BlockString "b"',
        '"!"',
        '"..."',
        "<EOF>",
    ]
    for ref want in expected:
        assert_equal(token_description(source, lexer.advance()), want)
    assert_equal(value_of("!"), "")


def test_is_punctuator_token_kind() raises:
    var punctuators: List[String] = [
        "!",
        "$",
        "&",
        "(",
        ")",
        "...",
        ":",
        "=",
        "@",
        "[",
        "]",
        "{",
        "|",
        "}",
    ]
    for ref text in punctuators:
        assert_true(lex_one(text).kind.is_punctuator())
    var others: List[String] = ["", "name", "1", "3.14", '"str"', '"""str"""']
    for ref text in others:
        assert_false(lex_one(text).kind.is_punctuator())


def test_utf16_columns() raises:
    # graphql-js counts UTF-16 units, so the emoji before the error is two.
    expect_error(
        '"\U0001f600\\z"',
        'Syntax Error: Invalid character escape sequence: "\\z".',
        4,
    )
    expect_error("é ~", "Syntax Error: Unexpected character: U+00E9.", 1)


def test_decodes_every_utf8_width_and_bad_pairs() raises:
    expect_token(
        '"\\u00e9\\u0800\\u{10000}"',
        TokenKind.STRING,
        0,
        23,
        "éࠀ\U00010000",
    )
    # A leading surrogate that no `\\u` follows is not a pair.
    expect_error(
        '"\\uD800x"',
        'Syntax Error: Invalid Unicode escape sequence: "\\uD800".',
        2,
    )
    expect_error(
        '"\\uD800\\x"',
        'Syntax Error: Invalid Unicode escape sequence: "\\uD800".',
        2,
    )


def test_block_strings_keep_partial_escapes() raises:
    expect_token(
        '"""a\\"b\\""c\\x"""',
        TokenKind.BLOCK_STRING,
        0,
        16,
        'a\\"b\\""c\\x',
    )
    expect_token('"""\n  \n"""', TokenKind.BLOCK_STRING, 0, 10, "")
    expect_token('"""first\n   \n"""', TokenKind.BLOCK_STRING, 0, 16, "first")
    expect_token(
        '"""\r\n  a\r\n   b\r"""', TokenKind.BLOCK_STRING, 0, 18, "a\n b"
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

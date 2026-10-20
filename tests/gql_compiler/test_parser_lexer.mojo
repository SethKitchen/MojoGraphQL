# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the lexer of the recovering parser.

Port of apollo-parser 0.8.6 (apollo-rs `b7eee5c`) `src/lexer/mod.rs`
tests: `token_limit`, `token_limit_exact`, `errors_and_token_limit`,
`stream_produces_original_input`, `quoted_block_comment` and
`unexpected_character`. `unterminated_string` only prints, and is not
ported. The last tests check the lexer states that the fixtures do not
reach.
"""

from gql_compiler.parser_lexer import (
    ErrorData,
    LexState,
    SyntaxError,
    TokenKind,
    lex,
    rust_debug_string,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _tokens(text: String, limit: Int = Int.MAX) -> Int:
    """Return how many tokens the upstream `lex` returns."""
    var count = 0
    for token in lex(text, limit).tokens:
        if token.kind != TokenKind.ERROR:
            count += 1
    return count


def _errors(text: String, limit: Int = Int.MAX) -> String:
    """Return the errors of a lex, one `Debug` line each."""
    var out = String()
    for error in lex(text, limit).errors:
        out += String(error, "\n")
    return out^


def _data(text: String, index: Int) -> String:
    """Return the text of the token at an index of the upstream list."""
    var bytes = text.as_bytes()
    var seen = 0
    for token in lex(text).tokens:
        if token.kind == TokenKind.ERROR:
            continue
        if seen == index:
            return String(
                StringSlice(
                    unsafe_from_utf8=bytes[Int(token.start) : Int(token.end)]
                )
            )
        seen += 1
    return String("")


comptime _QUERY = "type Query { a a a a a a a a a }"
"""The input of the token limit tests."""


def test_token_limit() raises:
    assert_equal(
        _errors(_QUERY, 10),
        'ERROR@17:17 "token limit reached, aborting lexing" \n',
    )


def test_token_limit_exact() raises:
    assert_equal(_tokens(_QUERY, 26), 26)
    assert_equal(_errors(_QUERY, 26), "")
    assert_equal(_tokens(_QUERY, 25), 25)
    assert_equal(
        _errors(_QUERY, 25),
        'ERROR@31:31 "token limit reached, aborting lexing" \n',
    )
    assert_equal(lex(_QUERY, 25).token_high, 25)


def test_errors_and_token_limit() raises:
    var text = "type Query { ..a a a a a a a a a }"
    assert_equal(_tokens(text, 10), 9)
    assert_equal(
        _errors(text, 10),
        (
            'ERROR@13:15 "Unterminated spread operator" ..\n'
            'ERROR@18:18 "token limit reached, aborting lexing" \n'
        ),
    )


def test_stream_produces_original_input() raises:
    var schema = (
        "\ntype Query {\n    name: String\n    format: String ="
        ' "Y-m-d\\\\TH:i:sP"\n}\n        '
    )
    var lexed = lex(schema)
    var bytes = schema.as_bytes()
    var out = String()
    for token in lexed.tokens:
        out += StringSlice(
            unsafe_from_utf8=bytes[Int(token.start) : Int(token.end)]
        )
    assert_equal(out, schema)


def test_quoted_block_comment() raises:
    var block = (
        '"""\nNot an escape character:\n\'/\\W/\'\nEscape character:\n'
        '\\"""\n\\"""\\"""\nNot escape characters:\n\\" \\""\n'
        'Escape character followed by a quote:\n\\""""\n"""'
    )
    var input = "\n" + block + "\n        "
    assert_equal(_errors(input), "")
    assert_equal(_data(input, 1), block)
    input = (
        '\n# String contents: """\n"""\\""""""\n# Unclosed block string\n'
        '"""\\"""\n        '
    )
    assert_equal(_data(input, 3), '"""\\""""""')
    assert_equal(
        _errors(input),
        'ERROR@59:75 "unterminated string value" """\\"""\n        \n',
    )


def test_unexpected_character() raises:
    var schema = "\ntype Query {\n    name: String\n}\n/\n        "
    assert_equal(
        _errors(schema), 'ERROR@33:34 "Unexpected character \\"/\\"" /\n'
    )


def test_kinds() raises:
    assert_true(TokenKind.FLOAT.is_valid())
    assert_false(TokenKind(23).is_valid())
    assert_equal(String(TokenKind.L_CURLY), "LCurly")
    assert_equal(String(TokenKind(23)), "<invalid>")
    assert_true(ErrorData.LIMIT.is_valid())
    assert_false(ErrorData(3).is_valid())
    assert_equal(String(ErrorData.TEXT), "Text")
    assert_equal(String(ErrorData.EOF), "Eof")
    assert_equal(String(ErrorData.LIMIT), "LimitExceeded")
    assert_true(LexState.MINUS.is_valid())
    assert_false(LexState(19).is_valid())
    var eof = SyntaxError("m", String(""), ErrorData.EOF, 4)
    assert_true(eof.is_eof())
    assert_false(eof.is_limit())
    assert_equal(eof.length(), 0)
    assert_equal(String(eof), 'ERROR@4:4 "m" EOF')


def _debug(code: Int) -> String:
    """Return the `{:?}` text of one character, without the quotes."""
    var quoted = rust_debug_string(chr(code))
    return String(quoted[byte = 1 : quoted.byte_length() - 1])


def test_debug_string() raises:
    assert_equal(rust_debug_string('a"\\\t\r\n'), '"a\\"\\\\\\t\\r\\n"')
    # Each escaped range, with the characters just outside it.
    var escaped: List[Int] = [
        0x00,
        0x08,
        0x0B,
        0x0E,
        0x1F,
        0x7F,
        0xA0,
        0xAD,
        0x1680,
        0x2000,
        0x200F,
        0x2028,
        0x202F,
        0x205F,
        0x206F,
        0x3000,
        0xFEFF,
        0xFFF9,
        0xFFFB,
    ]
    for code in escaped:
        assert_equal(_debug(code), String("\\u{", hex(code, prefix=""), "}"))
    var kept: List[Int] = [
        0x20,
        0x7E,
        0xA1,
        0xAE,
        0x1681,
        0x2010,
        0x2030,
        0x2070,
        0x3001,
        0xFFFC,
        0x1F600,
    ]
    for code in kept:
        assert_equal(_debug(code), chr(code))


def test_lexer_states() raises:
    # An empty string at the end, and before a name.
    assert_equal(_tokens('""'), 2)
    assert_equal(_data('""x', 1), "x")
    # Quotes inside a block string, and escapes in it.
    assert_equal(_errors('"""a"b""c"""'), "")
    assert_equal(_data('"""\\"x"""', 0), '"""\\"x"""')
    assert_equal(_errors('"""\\\\a"""'), "")
    # Unicode escapes below and above the surrogates.
    assert_equal(_errors('"\\u0041\\uE000"'), "")
    # A carriage return in a string, and at the end of a comment.
    assert_equal(
        _errors('"a\rb"'), 'ERROR@0:5 "unexpected line terminator" "a\rb"\n'
    )
    assert_equal(_data("# c\rname", 2), "name")
    # Signs and exponents.
    assert_equal(_errors("-0 1.5e3 -12"), "")
    assert_equal(_errors("-a"), 'ERROR@0:2 "Unexpected character `a`" -a\n')
    assert_equal(
        _errors("1ex"),
        (
            'ERROR@0:3 "Unexpected character `x`, expected exponent digit or'
            ' sign" 1ex\n'
        ),
    )
    assert_equal(
        _errors("1e+x"),
        'ERROR@0:4 "Unexpected character `x`, expected exponent digit" 1e+x\n',
    )
    # A carriage return inside whitespace, and a comment at the end.
    assert_equal(_data("a \r\nb", 1), " \r\n")
    assert_equal(_tokens("# c"), 2)
    # Whitespace that holds a byte order mark is one token.
    var bom = chr(0xFEFF)
    for space in ["\t", " ", "\n", "\r"]:
        var text = String(space, bom, "a")
        assert_equal(_data(text, 0), String(space, bom))
        assert_equal(_data(text, 1), "a")
    # A three-byte character that starts as a byte order mark does.
    var near_bom = chr(0xFEC0)
    assert_equal(
        _errors(near_bom),
        String(
            'ERROR@0:3 "Unexpected character \\"',
            near_bom,
            '\\"" ',
            near_bom,
            "\n",
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

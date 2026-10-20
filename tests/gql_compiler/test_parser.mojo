# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the recovering parser, over the apollo-parser fixtures.

Port of apollo-parser 0.8.6 (apollo-rs `b7eee5c`) `src/tests.rs`
`lexer_tests` and `parser_tests` for `test_data/lexer/err/` and
`test_data/parser/err/`. A lexer case must dump its tokens and errors as
the upstream `.txt` file does. A parser case must give the `- ERROR@`
lines and the `recursion limit:` line of the upstream `.txt` file, in
order. The concrete syntax tree lines are not compared, because the
parser builds an AST and not a syntax tree; `test_parser_ast.mojo` checks
the recovered AST. The fixtures are in `_parser_fixtures.mojo`.
"""

from gql_compiler.parser import parse_recovering
from gql_compiler.parser_lexer import (
    Token,
    TokenKind,
    lex,
    rust_debug_string,
)
from std.os import listdir
from std.os.path import exists
from std.pathlib import Path
from std.testing import TestSuite, assert_equal, assert_true

from _parser_fixtures import parser_cases, parser_expected, parser_input

comptime FIXTURES = "tests/gql_compiler/parser_fixtures/"
"""The fixture files, from the repository root."""


def _token_name(kind: TokenKind) -> String:
    """Return the upstream `Debug` prefix of a token kind."""
    comptime names: Array[StaticString, 22] = [
        "WHITESPACE",
        "COMMENT",
        "BANG",
        "DOLLAR",
        "AMP",
        "SPREAD",
        "COMMA",
        "COLON",
        "EQ",
        "AT",
        "L_PAREN",
        "R_PAREN",
        "L_BRACKET",
        "R_BRACKET",
        "L_CURLY",
        "R_CURLY",
        "PIPE",
        "EOF",
        "NAME",
        "STRING_VALUE",
        "INT",
        "FLOAT",
    ]
    return String(materialize[names]()[Int(kind.value)])


def dump_tokens(text: String) -> String:
    """Write the tokens and errors as upstream `dump_tokens_and_errors`."""
    var lexed = lex(text)
    var out = String()
    var bytes = text.as_bytes()
    for token in lexed.tokens:
        if token.kind == TokenKind.ERROR:
            out += String(lexed.errors[Int(token.start)], "\n")
        elif token.kind == TokenKind.EOF:
            out += String("EOF@", token.start, ":", token.end, "\n")
        else:
            var data = StringSlice(
                unsafe_from_utf8=bytes[Int(token.start) : Int(token.end)]
            )
            out += String(
                _token_name(token.kind),
                "@",
                token.start,
                ":",
                token.end,
                " ",
                rust_debug_string(data),
                "\n",
            )
    return out^


def dump_errors(text: String) -> String:
    """Write the error lines and the recursion line of a parse."""
    var tree = parse_recovering(text)
    var out = String()
    for error in tree.errors:
        out += String("- ", error, "\n")
    out += String("recursion limit: 500, high: ", tree.recursion_high, "\n")
    return out^


def run_case(index: Int, path: String) -> String:
    """Run one case as `tests.rs` does.

    Args:
        index: The case.
        path: The path of the case, from `parser_cases`.

    Returns:
        The lines to compare with `parser_expected`.
    """
    if path.startswith("lexer_err/"):
        return dump_tokens(parser_input(index))
    return dump_errors(parser_input(index))


def _check(start: Int, end: Int) raises:
    """Run the cases in a range; each must give the upstream lines."""
    var paths = parser_cases()
    var index = start
    while index < min(end, len(paths)):
        assert_equal(
            run_case(index, paths[index]), parser_expected(index), paths[index]
        )
        index += 1


def test_lexer_fixtures() raises:
    _check(0, 29)


def test_parser_fixtures_0() raises:
    _check(29, 61)


def test_parser_fixtures_1() raises:
    _check(61, 93)


def test_parser_fixtures_are_current() raises:
    if not exists(FIXTURES):
        return
    var embedded = parser_cases()
    assert_equal(len(embedded), 93)
    var index = 0
    for directory in ["lexer_err", "parser_err"]:
        var entries = listdir(FIXTURES + directory)
        sort(entries)
        for ref entry in entries:
            if entry.endswith(".graphql"):
                var path = String(directory, "/", entry)
                assert_equal(embedded[index], path)
                assert_equal(
                    parser_input(index),
                    Path(FIXTURES + path).read_text(),
                    path,
                )
                index += 1
    assert_equal(index, len(embedded))
    assert_equal(parser_input(index), "")
    assert_equal(parser_expected(index), "")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

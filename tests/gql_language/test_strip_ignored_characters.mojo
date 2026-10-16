# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_language.strip_ignored_characters`, ported from
graphql-js 16.14.2 `src/utilities/__tests__/stripIgnoredCharacters-test.ts`.

`stripIgnoredCharacters-fuzz.ts` is not ported: it runs for minutes over
every short token sequence. The kitchen sink tests compare the AST shapes
without locations, as graphql-js compares with `noLocation: true`.
"""

from _ast_dump import dedent, shape
from _fixtures import KITCHEN_SINK_QUERY, KITCHEN_SINK_SDL
from gql_language.lexer import Lexer, token_value
from gql_language.parser import parse
from gql_language.source import Source
from gql_language.strip_ignored_characters import strip_ignored_characters
from gql_language.token_kind import TokenKind
from std.testing import TestSuite, assert_equal, assert_true


def bom() -> String:
    """Return the byte order mark, U+FEFF, as UTF-8."""
    var bytes: List[UInt8] = [0xEF, 0xBB, 0xBF]
    return String(unsafe_from_utf8=bytes)


def ignored_tokens() -> List[String]:
    """Return the upstream `ignoredTokens`."""
    return [
        bom(),
        "\t",
        " ",
        "\n",
        "\r",
        "\r\n",
        '# "Comment" string\n',
        ",",
    ]


def punctuator_tokens() -> List[String]:
    """Return the upstream `punctuatorTokens`."""
    return ["!", "$", "(", ")", "...", ":", "=", "@", "[", "]", "{", "|", "}"]


def non_punctuator_tokens() -> List[String]:
    """Return the upstream `nonPunctuatorTokens`."""
    return [
        "name_token",
        "1",
        "3.14",
        '"some string value"',
        '"""block\nstring\nvalue"""',
    ]


def joined(tokens: List[String]) -> String:
    """Return the tokens joined with nothing between them."""
    var out = String("")
    for token in tokens:
        out += token
    return out^


def json_stringify(text: String) -> String:
    """Return a text as JSON `stringify` writes the ignored tokens."""
    var out = String('"')
    var escaped = (
        text.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\t", "\\t")
        .replace("\n", "\\n")
        .replace("\r", "\\r")
    )
    out += escaped
    return out + '"'


def expect_stripped(document: String, expected: String) raises:
    """Assert the stripped text, and that stripping it again changes
    nothing, as `expectStripped(...).toEqual`."""
    var stripped = strip_ignored_characters(document)
    assert_equal(stripped, expected)
    assert_equal(strip_ignored_characters(stripped), stripped)


def expect_same(document: String) raises:
    """Assert that stripping changes nothing, as `toStayTheSame`."""
    expect_stripped(document, document)


def lex_value(text: String) raises -> String:
    """Return the value of the one token of a text, as `lexValue`."""
    var lexer = Lexer(Source(text))
    var token = lexer.advance()
    var value = token_value(lexer.source, token)
    assert_true(lexer.advance().kind == TokenKind.EOF)
    return value^


def expect_stripped_string(block: String, expected: String) raises:
    """Assert that a stripped block string keeps its value, and its
    stripped text, as `expectStrippedString`."""
    var original = lex_value(block)
    assert_equal(lex_value(strip_ignored_characters(block)), original)
    expect_stripped(block, expected)


def test_strips_query_document() raises:
    var query = dedent(
        """
        query SomeQuery($foo: String!, $bar: String) {
          someField(foo: $foo, bar: $bar) {
            a
            b {
              c
              d
            }
          }
        }
        """
    )
    assert_equal(
        strip_ignored_characters(query),
        (
            "query SomeQuery($foo:String!$bar:String){someField(foo:$foo"
            " bar:$bar){a b{c d}}}"
        ),
    )


def test_accepts_source() raises:
    assert_equal(strip_ignored_characters(Source("{ a }")), "{a}")


def test_strips_sdl_document() raises:
    var sdl = dedent(
        '''
        """
        Type description
        """
        type Foo {
          """
          Field description
          """
          bar: String
        }
        '''
    )
    assert_equal(
        strip_ignored_characters(sdl),
        '"""Type description""" type Foo{"""Field description""" bar:String}',
    )


def test_reports_invalid_token() raises:
    var message = String("")
    try:
        _ = strip_ignored_characters('{ foo(arg: "\n"')
    except error:
        message = String(error)
    assert_equal(
        message,
        dedent(
            """
            Syntax Error: Unterminated string.

            GraphQL request:1:13
            1 | { foo(arg: "
              |             ^
            2 | "
            """
        ),
    )


def test_strips_non_parsable_document() raises:
    expect_stripped('{ foo(arg: "str"', '{foo(arg:"str"')


def test_strips_only_ignored_characters() raises:
    expect_stripped("\n", "")
    expect_stripped(",", "")
    expect_stripped(",,", "")
    expect_stripped("#comment\n, \n", "")
    var ignored = ignored_tokens()
    for first in ignored:
        expect_stripped(first, "")
        for second in ignored:
            expect_stripped(first + second, "")
    expect_stripped(joined(ignored), "")


def test_strips_leading_and_trailing_ignored_tokens() raises:
    expect_stripped("\n1", "1")
    expect_stripped(",1", "1")
    expect_stripped(",,1", "1")
    expect_stripped("#comment\n, \n1", "1")
    expect_stripped("1\n", "1")
    expect_stripped("1,", "1")
    expect_stripped("1,,", "1")
    expect_stripped("1#comment\n, \n", "1")
    var ignored = ignored_tokens()
    var tokens = punctuator_tokens()
    tokens.extend(non_punctuator_tokens())
    for token in tokens:
        for first in ignored:
            expect_stripped(first + token, token)
            expect_stripped(token + first, token)
            for second in ignored:
                expect_stripped(token + first + first, token)
                expect_stripped(first + second + token, token)
        expect_stripped(joined(ignored) + token, token)
        expect_stripped(token + joined(ignored), token)


def test_strips_between_punctuators() raises:
    expect_stripped("[,)", "[)")
    expect_stripped("[\r)", "[)")
    expect_stripped("[\r\r)", "[)")
    expect_stripped("[\r,)", "[)")
    expect_stripped("[,\n)", "[)")
    var ignored = ignored_tokens()
    var punctuators = punctuator_tokens()
    for left in punctuators:
        for right in punctuators:
            for first in ignored:
                expect_stripped(left + first + right, left + right)
                for second in ignored:
                    expect_stripped(left + first + second + right, left + right)
            expect_stripped(left + joined(ignored) + right, left + right)


def test_strips_between_punctuator_and_non_punctuator() raises:
    expect_stripped("[,1", "[1")
    expect_stripped("[\r1", "[1")
    expect_stripped("[\r\r1", "[1")
    expect_stripped("[\r,1", "[1")
    expect_stripped("[,\n1", "[1")
    var ignored = ignored_tokens()
    for value in non_punctuator_tokens():
        for punctuator in punctuator_tokens():
            for first in ignored:
                expect_stripped(punctuator + first + value, punctuator + value)
                for second in ignored:
                    expect_stripped(
                        punctuator + first + second + value, punctuator + value
                    )
            expect_stripped(
                punctuator + joined(ignored) + value, punctuator + value
            )


def test_strips_between_non_punctuator_and_punctuator() raises:
    expect_stripped("1,[", "1[")
    expect_stripped("1\r[", "1[")
    expect_stripped("1\r\r[", "1[")
    expect_stripped("1\r,[", "1[")
    expect_stripped("1,\n[", "1[")
    var ignored = ignored_tokens()
    for value in non_punctuator_tokens():
        for punctuator in punctuator_tokens():
            # The spread is the special case of the next test.
            if punctuator == "...":
                continue
            for first in ignored:
                expect_stripped(value + first + punctuator, value + punctuator)
                for second in ignored:
                    expect_stripped(
                        value + first + second + punctuator, value + punctuator
                    )
            expect_stripped(
                value + joined(ignored) + punctuator, value + punctuator
            )


def test_keeps_space_between_non_punctuator_and_spread() raises:
    expect_stripped("a ...", "a ...")
    expect_stripped("1 ...", "1 ...")
    expect_stripped("1 ... ...", "1 ......")
    var ignored = ignored_tokens()
    for value in non_punctuator_tokens():
        for first in ignored:
            expect_stripped(value + first + "...", value + " ...")
            for second in ignored:
                expect_stripped(value + first + second + " ...", value + " ...")
        expect_stripped(value + joined(ignored) + "...", value + " ...")


def test_keeps_space_between_non_punctuators() raises:
    expect_same("1 2")
    expect_same('"" ""')
    expect_same("a b")
    expect_stripped("a,1", "a 1")
    expect_stripped("a,,1", "a 1")
    expect_stripped("a  1", "a 1")
    expect_stripped("a \t 1", "a 1")
    var ignored = ignored_tokens()
    var values = non_punctuator_tokens()
    for left in values:
        for right in values:
            for first in ignored:
                expect_stripped(left + first + right, left + " " + right)
                for second in ignored:
                    expect_stripped(
                        left + first + second + right, left + " " + right
                    )
            expect_stripped(left + joined(ignored) + right, left + " " + right)


def test_keeps_ignored_tokens_in_strings() raises:
    expect_same('" "')
    expect_same('","')
    expect_same('",,"')
    expect_same('",|"')
    var ignored = ignored_tokens()
    for first in ignored:
        expect_same(json_stringify(first))
        for second in ignored:
            expect_same(json_stringify(first + second))
    expect_same(json_stringify(joined(ignored)))


def test_keeps_ignored_tokens_in_block_strings() raises:
    expect_same('""","""')
    expect_same('""",,"""')
    expect_same('""",|"""')
    var ignored = List[String]()
    for token in ignored_tokens():
        if (
            token != "\n"
            and token != "\r"
            and token != "\r\n"
            and token != "\t"
            and token != " "
        ):
            ignored.append(token)
    for first in ignored:
        expect_same('"""|' + first + '|"""')
        for second in ignored:
            expect_same('"""|' + first + second + '|"""')
    expect_same('"""|' + joined(ignored) + '|"""')


def test_strips_inside_block_strings() raises:
    expect_stripped_string('""""""', '""""""')
    expect_stripped_string('""" """', '""""""')
    expect_stripped_string('"""a"""', '"""a"""')
    expect_stripped_string('""" a"""', '""" a"""')
    expect_stripped_string('""" a """', '""" a """')
    expect_stripped_string('"""\n"""', '""""""')
    expect_stripped_string('"""a\nb"""', '"""a\nb"""')
    expect_stripped_string('"""a\rb"""', '"""a\nb"""')
    expect_stripped_string('"""a\r\nb"""', '"""a\nb"""')
    expect_stripped_string('"""a\r\n\nb"""', '"""a\n\nb"""')
    expect_stripped_string('"""\\\n"""', '"""\\\n"""')
    expect_stripped_string('""""\n"""', '""""\n"""')
    expect_stripped_string('"""\\"""\n"""', '"""\\""""""')
    expect_stripped_string('"""\na\n b"""', '"""\na\n b"""')
    expect_stripped_string('"""\n a\n b"""', '"""a\nb"""')
    expect_stripped_string('"""\na\n b\nc"""', '"""a\n b\nc"""')


def test_strips_kitchen_sink_query_keeping_ast() raises:
    var stripped = strip_ignored_characters(KITCHEN_SINK_QUERY)
    assert_equal(strip_ignored_characters(stripped), stripped)
    assert_equal(shape(parse(stripped)), shape(parse(KITCHEN_SINK_QUERY)))


def test_strips_kitchen_sink_sdl_keeping_ast() raises:
    var stripped = strip_ignored_characters(KITCHEN_SINK_SDL)
    assert_equal(strip_ignored_characters(stripped), stripped)
    assert_equal(shape(parse(stripped)), shape(parse(KITCHEN_SINK_SDL)))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

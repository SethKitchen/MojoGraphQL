# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_language.error`: the parts of graphql-js 16.14.2
`error/GraphQLError.ts` that this package ports, from
`src/error/__tests__/GraphQLError-test.ts`.

graphql-js tests that build errors from AST nodes, original errors and
stack traces belong to the execution package, which attaches them.
"""

from gql_language.error import (
    GraphQLError,
    PathSegment,
    print_source_location,
    quote_json_string,
    syntax_error,
)
from gql_language.source import Source, SourceLocation
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_uses_the_message_alone() raises:
    var error = GraphQLError("msg")
    assert_equal(String(error), "msg")
    assert_equal(len(error.locations), 0)
    assert_equal(error.to_json(), '{"message":"msg"}')


def test_converts_source_and_positions_to_locations() raises:
    var source = Source("{\n      field\n}")
    var error = GraphQLError("msg", source, [6])
    assert_equal(error.locations[0], SourceLocation(2, 5))
    assert_equal(
        String(error),
        "msg\n\nGraphQL request:2:5\n1 | {\n2 |       field\n  |     ^\n3 | }",
    )


def test_without_positions_has_no_locations() raises:
    var error = GraphQLError("msg", Source("{}"), [])
    assert_equal(len(error.locations), 0)
    assert_equal(String(error), "msg")


def test_prints_an_error_with_two_positions() raises:
    var source = Source("type Foo {\n  field: String\n}", "SourceA")
    var error = GraphQLError("Example error", source, [13, 15])
    assert_equal(len(error.locations), 2)
    assert_equal(
        String(error),
        "Example error\n\n"
        + "SourceA:2:3\n1 | type Foo {\n2 |   field: String\n  |   ^\n3 | }"
        + "\n\n"
        + "SourceA:2:5\n1 | type Foo {\n2 |   field: String\n  |     ^\n3 | }",
    )


def test_serializes_to_include_all_standard_fields() raises:
    var error = GraphQLError("msg", Source("{ a }"), [2])
    error.path = [PathSegment.of_key("path"), PathSegment.of_index(3)]
    error.path.append(PathSegment.of_key("to"))
    error.extensions = String('{"foo":"bar"}')
    assert_equal(
        error.to_json(),
        '{"message":"msg","locations":[{"line":1,"column":3}],'
        + '"path":["path",3,"to"],"extensions":{"foo":"bar"}}',
    )


def test_path_segments() raises:
    var key = PathSegment.of_key("hero")
    var index = PathSegment.of_index(0)
    assert_false(key.is_index())
    assert_true(index.is_index())
    assert_equal(String(key), "hero")
    assert_equal(String(index), "0")
    assert_true(key == PathSegment.of_key("hero"))
    assert_false(key == index)


def test_syntax_error_prefixes_the_message() raises:
    var error = syntax_error(Source("x"), 0, "Bad.")
    assert_equal(error.message, "Syntax Error: Bad.")
    assert_equal(error.locations[0], SourceLocation(1, 1))


def test_quote_json_string_escapes() raises:
    assert_equal(
        quote_json_string('a"b\\c\n\r\t\x08\x0c\x01\x1fé'),
        '"a\\"b\\\\c\\n\\r\\t\\b\\f\\u0001\\u001fé"',
    )


def test_print_source_location_splits_crlf_lines() raises:
    var source = Source("a\r\nb\rc\nd")
    assert_equal(
        print_source_location(source, SourceLocation(2, 1)),
        "GraphQL request:2:1\n1 | a\n2 | b\n  | ^\n3 | c",
    )
    assert_equal(
        print_source_location(Source("a\r"), SourceLocation(1, 1)),
        "GraphQL request:1:1\n1 | a\n  | ^\n2 |",
    )


def test_print_source_location_long_line_without_a_next_piece() raises:
    var line = String("x") * 121
    var text = print_source_location(Source(line), SourceLocation(1, 121))
    assert_equal(
        text,
        "GraphQL request:1:121\n1 | "
        + String("x") * 80
        + "\n  | "
        + String("x") * 41
        + "\n  | "
        + String(" ") * 40
        + "^",
    )


def test_print_source_location_column_zero() raises:
    var line = String("y") * 130
    var text = print_source_location(Source(line), SourceLocation(1, 80))
    # graphql-js `'^'.padStart(0)` is a caret alone.
    assert_true(text.endswith("\n  | " + String("y") * 50 + "\n  | ^"))


def test_quote_json_string_of_empty_text() raises:
    assert_equal(quote_json_string(""), '""')


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

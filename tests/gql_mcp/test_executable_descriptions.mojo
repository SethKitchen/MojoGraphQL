# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_mcp.executable_descriptions` and
`gql_mcp.executable_print`.

Ported from Apollo MCP Server 2.0.0 (04e4e6e)
`crates/apollo-mcp-server/src/operations/executable_descriptions.rs`. The
printer tests check the one-line output of apollo-compiler 2.0.0-beta.1
`src/ast/serialize.rs`.
"""

from gql_language.parser import parse
from gql_mcp.executable_descriptions import (
    node_description,
    non_blank_description,
    strip_executable_descriptions,
)
from gql_mcp.executable_print import (
    PrintOptions,
    print_definition,
    print_document,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_strip_executable_descriptions_reports_nothing_stripped_without_descriptions() raises:
    var document = parse(
        "query Q($id: ID) { id ...F } fragment F on Query { id }"
    )
    assert_false(strip_executable_descriptions(document))


def test_strip_executable_descriptions_reports_stripped_operation_description() raises:
    assert_true(strip_executable_descriptions(parse('"Get it" query Q { id }')))


def test_strip_executable_descriptions_reports_stripped_variable_description() raises:
    assert_true(
        strip_executable_descriptions(parse('query Q("The ID" $id: ID) { id }'))
    )


def test_strip_executable_descriptions_reports_stripped_fragment_description() raises:
    assert_true(
        strip_executable_descriptions(
            parse('query Q { ...F } "Shared fields" fragment F on Query { id }')
        )
    )


def test_strip_executable_descriptions_removes_every_description() raises:
    var document = parse(
        '"Get it" query Q("The ID" $id: ID) { ...F } "Shared fields" fragment'
        + " F on Query { id }"
    )
    assert_equal(
        print_document(document, PrintOptions(True, False)),
        "query Q($id: ID) { ...F } fragment F on Query { id }",
    )


def test_non_blank_description_is_none_without_description() raises:
    assert_false(Bool(non_blank_description(None)))


def test_non_blank_description_treats_blank_description_as_missing() raises:
    assert_false(Bool(non_blank_description(String("   "))))


def test_non_blank_description_trims_surrounding_whitespace() raises:
    assert_equal(
        non_blank_description(String("  Look up a thing  ")).value(),
        "Look up a thing",
    )


def test_node_description() raises:
    var document = parse('"d" query Q { id } query R { id }')
    var definitions = document.definitions()
    assert_equal(node_description(document, definitions[0]).value(), "d")
    assert_false(Bool(node_description(document, definitions[1])))
    assert_false(strip_executable_descriptions(parse("type T { a: Int }")))


def test_print_keeps_descriptions_and_values() raises:
    var document = parse(
        '"""Op\nline""" query Q("v" $a: [Int!]! = [1, 2] @d, $b: In = {x:'
        + ' "q\\"\\\\\\n\\t\\b\\f\\r\\u0001", z: null, w: true, e:'
        + " ENUM, f: false, g: 1.5, h: [], i: {}}) @live { a: f(x: 1, y: $a)"
        " @private"
        + " @skip(if: true) { b } ... on T @x { c } ... @y { d } ...F @z }"
        + ' "frag" fragment F on T @k { e } { s } type T { a: Int }'
    )
    var expected = (
        '"Op\\nline" query Q("v" $a: [Int!]! = [1, 2] @d, $b: In = {x:'
        + ' "q\\"\\\\\\n\t\\b\\f\\r\\u0001", z: null, w: true, e:'
        + " ENUM, f: false, g: 1.5, h: [], i: {}}) @live { a: f(x: 1, y: $a)"
        " @private"
        + " @skip(if: true) { b } ... on T @x { c } ... @y { d } ...F @z }"
        + ' "frag" fragment F on T @k { e } query { s } type T { a: Int }'
    )
    assert_equal(print_document(document, PrintOptions(False, False)), expected)
    var stripped = print_document(document, PrintOptions(True, True))
    assert_true(stripped.startswith("query Q($a: [Int!]! = [1, 2] @d, "))
    assert_true("a: f(x: 1, y: $a) @skip(if: true)" in stripped)
    assert_true("} fragment F on T @k { e }" in stripped)


def test_print_definition_shorthand() raises:
    var document = parse(
        "{ id } mutation { id } query @d { id } query ($v: Int) { id }"
    )
    var definitions = document.definitions()
    assert_equal(print_definition(document, definitions[0]), "{ id }")
    assert_equal(print_definition(document, definitions[1]), "mutation { id }")
    assert_equal(print_definition(document, definitions[2]), "query @d { id }")
    assert_equal(
        print_definition(document, definitions[3]), "query($v: Int) { id }"
    )
    var described = parse('"d" query { id }')
    assert_equal(
        print_definition(described, described.definitions()[0]),
        '"d" query { id }',
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

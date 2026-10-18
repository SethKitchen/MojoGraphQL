# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_composition.printer`.

Upstream has no test file for `src/graphql/printer.ts`. The expected text is
the output of the upstream `print` in Node.js, for each directive, argument,
list type and non-null type of the document, in `visit` order.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_language.parser import parse
from gql_composition.printer import json_string, print_node, utf16_length
from gql_composition.walk import Walker
from std.testing import TestSuite, assert_equal


comptime SDL = (
    'type T @d(a: "q\\"b\\\\s\\b\\t\\n\\f\\r\\u0001\\u001f é 😀") @d(b: """block'
    ' \\""" x""") @d(c: true, d: false, e: null) { f: Int }\ntype U @d(f: 12,'
    " g: -1.5e3, h: ENUM, i: [1, [2]], j: { a: 1, b: [x] }, k: [], l: {}) {"
    " f(x: [Int!]!, y: String): Int }\ntype V @d(long:"
    ' "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", other:'
    ' "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb") @e { f: Int }\ntype W @d(long:'
    ' "😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀") @d(x:'
    ' "ééééééééééééééééééééééééééééééééééééé", y: 1) { f: Int }\nquery Q($v:'
    " Int) { a(x: $v, y: [$v]) }"
)


def _printed(document: Document) -> List[String]:
    var out = List[String]()
    var walker = Walker(document.definitions())
    while walker.next(document):
        if not walker.entering:
            continue
        var kind = document.kind(walker.node)
        if (
            kind == Kind.DIRECTIVE
            or kind == Kind.ARGUMENT
            or kind == Kind.LIST_TYPE
            or kind == Kind.NON_NULL_TYPE
        ):
            out.append(print_node(document, walker.node))
    return out^


def test_print_nodes() raises:
    var expected: List[String] = [
        '@d(a: "q\\"b\\\\s\\b\\t\\n\\f\\r\\u0001\\u001f é 😀")',
        'a: "q\\"b\\\\s\\b\\t\\n\\f\\r\\u0001\\u001f é 😀"',
        '@d(b: """\nblock \\""" x\n""")',
        'b: """\nblock \\""" x\n"""',
        "@d(c: true, d: false, e: null)",
        "c: true",
        "d: false",
        "e: null",
        (
            "@d(f: 12, g: -1.5e3, h: ENUM, i: [1, [2]], j: {a: 1, b: [x]}, k:"
            " [], l: {})"
        ),
        "f: 12",
        "g: -1.5e3",
        "h: ENUM",
        "i: [1, [2]]",
        "j: {a: 1, b: [x]}",
        "k: []",
        "l: {}",
        "[Int!]!",
        "[Int!]",
        "Int!",
        (
            '@d(\n  long: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"\n  other:'
            ' "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"\n)'
        ),
        'long: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"',
        'other: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"',
        "@e",
        '@d(long: "😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀")',
        'long: "😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀"',
        '@d(x: "ééééééééééééééééééééééééééééééééééééé", y: 1)',
        'x: "ééééééééééééééééééééééééééééééééééééé"',
        "y: 1",
        "x: $v",
        "y: [$v]",
    ]
    var got = _printed(parse(SDL))
    assert_equal(len(got), len(expected))
    for index in range(len(expected)):
        assert_equal(got[index], expected[index])


def test_print_other_nodes() raises:
    var document = parse("type Query { a: Int }")
    assert_equal(print_node(document, NO_NODE), "")
    var definition = document.first_child(document.root)
    assert_equal(print_node(document, definition), "")
    assert_equal(
        print_node(document, document.child(definition, Role.NAME)), "Query"
    )


def test_json_string_and_length() raises:
    assert_equal(json_string("a\u007f"), '"a\u007f"')
    assert_equal(utf16_length("a\u00e9😀"), 4)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

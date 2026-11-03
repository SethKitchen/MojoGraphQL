# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `gql_validation.spread_depth`. There is no upstream suite:
graphql-js has no such limit."""

from std.testing import TestSuite, assert_equal, assert_true
from gql_language.parser import parse
from gql_language.source import SourceLocation
from gql_schema.build import build_schema
from gql_validation.spread_depth import MAX_SPREAD_DEPTH, deepest_spread_chain
from gql_validation.validate import validate

comptime SDL = "type Query { a: Query b: Boolean }"


def _chain(levels: Int) -> String:
    """`{ ...F0 }` and `levels` fragments, each spreading the next."""
    var text = String("{ ...F0 }")
    for index in range(levels):
        text += (
            " fragment F"
            + String(index)
            + " on Query { ...F"
            + String(index + 1)
            + " }"
        )
    text += " fragment F" + String(levels) + " on Query { b }"
    return text^


def test_the_depth_of_a_chain() raises:
    var document = parse(_chain(3))
    var deepest = deepest_spread_chain(document)
    # The operation and the fragments F0 to F3.
    assert_equal(deepest[0], 5)
    assert_equal(deepest[1], document.definitions()[0])
    var flat = parse("{ b } fragment F on Query { b }")
    assert_equal(deepest_spread_chain(flat)[0], 1)


def test_cycles_and_unknown_fragments_add_no_depth() raises:
    var cycle = parse(
        "{ ...A } fragment A on Query { ...B a { ...A } }"
        " fragment B on Query { ...A ...Missing }"
    )
    assert_equal(deepest_spread_chain(cycle)[0], 3)
    var errors = validate(build_schema(SDL), cycle)
    assert_true(len(errors) > 0)
    assert_true("Cannot spread fragment" in errors[0].message)


def test_validate_refuses_a_deep_chain() raises:
    var schema = build_schema(SDL)
    assert_equal(len(validate(schema, parse(_chain(MAX_SPREAD_DEPTH - 2)))), 0)
    # Without the limit, OverlappingFieldsCanBeMergedRule overflows the
    # stack on this chain.
    var errors = validate(schema, parse(_chain(MAX_SPREAD_DEPTH * 40)))
    assert_equal(len(errors), 1)
    assert_equal(
        errors[0].message, "Fragment spreads are nested deeper than 500 levels."
    )
    assert_equal(errors[0].locations[0], SourceLocation(1, 1))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

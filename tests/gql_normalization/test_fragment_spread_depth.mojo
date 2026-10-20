# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests ported from graphql-go-tools v2
`v2/pkg/astnormalization/fragmentspread_depth_test.go`.

`get` takes no definition, so `testDefinition` is not parsed. The
benchmark is in `bench/gql_normalization/`. The last tests are not from
upstream.
"""

from gql_language.parser import parse
from gql_normalization.fragment_spread_depth import (
    Depths,
    FragmentSpreadDepth,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime NESTED = """
				subscription sub {
					...frag1
				}
				fragment frag1 on Subscription {
					newMessage {
						body
						sender
					}
					disallowedSecondRootField
					...frag2
				}
				fragment frag2 on Subscription {
					frag2Field
				}"""


def run(operation: StringSlice, spread_name: StringSlice, want: Int) raises:
    """Find the depth of the first spread of a fragment: upstream `run`.

    Args:
        operation: The operation.
        spread_name: The fragment name.
        want: The expected depth, or -1 for none.

    Raises:
        Error: If the depths differ.
    """
    var document = parse(operation)
    var depths = Depths()
    FragmentSpreadDepth().get(document, depths)
    var got = -1
    for index in range(len(depths)):
        if depths[index].spread_name == spread_name:
            got = depths[index].depth
            break
    assert_equal(got, want)


def test_simple() raises:
    run(NESTED, "frag1", 3)


def test_nested() raises:
    run(NESTED, "frag2", 6)


def test_inline_fragment_and_by_ref() raises:
    var document = parse(
        "{ a { ... on A { ...f } } } fragment f on A { b ...g } fragment g"
        " on A { c }"
    )
    var depths = Depths()
    var calculator = FragmentSpreadDepth()
    calculator.get(document, depths)
    assert_equal(len(depths), 2)
    assert_equal(depths[0].depth, 7)
    assert_false(depths[0].is_nested)
    assert_true(depths[1].is_nested)
    assert_equal(depths[1].parent_fragment_name, "f")
    assert_equal(depths[1].depth, 10)
    var found = depths.by_ref(depths[1].spread_ref)
    assert_true(Bool(found))
    assert_equal(found.value(), 10)
    assert_false(Bool(depths.by_ref(-5)))
    # A nested spread of a fragment that no one spreads keeps its depth.
    depths.clear()
    # A type system definition has no spreads.
    calculator.get(parse("scalar S fragment f on A { ...g }"), depths)
    assert_equal(depths[0].depth, 3)


def test_cycle_raises() raises:
    var depths = Depths()
    var document = parse("fragment f on A { ...g } fragment g on A { ...f }")
    try:
        FragmentSpreadDepth().get(document, depths)
    except error:
        assert_equal(
            String(error), "fragment spread depth: fragment f spreads itself"
        )
        return
    assert_true(False, "a cycle should raise")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

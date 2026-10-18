# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `contains_supergraph_spec`.

The expected values are what Hive `containsSupergraphSpec` returns.
"""

from gql_composition.contains_supergraph_spec import contains_supergraph_spec
from std.testing import TestSuite, assert_equal


def test_a_join_directive_is_not_a_spec_match() raises:
    assert_equal(
        contains_supergraph_spec("type Query { a: String @join__field }"),
        False,
    )


def test_join_graph_is_not_a_spec_name() raises:
    assert_equal(contains_supergraph_spec("enum join__Graph { USERS }"), False)


def test_a_spec_scalar_after_whitespace_matches() raises:
    assert_equal(
        contains_supergraph_spec("scalar X\nscalar join__FieldSet"), True
    )


def test_a_spec_name_in_brackets_matches() raises:
    assert_equal(
        contains_supergraph_spec("type Query { a: [join__FieldSet] }"), True
    )


def test_context_matches_and_link_does_not() raises:
    assert_equal(
        contains_supergraph_spec('type User @context(name: "a") { id: ID }'),
        True,
    )
    assert_equal(
        contains_supergraph_spec(
            'schema @link(url: "https://specs.apollo.dev/link/v1.0")'
            " { query: Query }"
        ),
        False,
    )


def test_a_public_schema_does_not_match() raises:
    assert_equal(
        contains_supergraph_spec(
            "type Query { user: User }\ntype User { id: ID! name: String }"
        ),
        False,
    )


def test_tag_and_cost_directives_do_not_match() raises:
    assert_equal(
        contains_supergraph_spec('type User @tag(name: "a") { id: ID }'),
        False,
    )
    assert_equal(
        contains_supergraph_spec("type Query { a: String @cost(weight: 1) }"),
        False,
    )


def test_core_matches() raises:
    assert_equal(
        contains_supergraph_spec('schema @core(feature: "x") { query: Query }'),
        True,
    )


def test_join_owner_and_join_directive_match() raises:
    assert_equal(
        contains_supergraph_spec("type User @join__owner(graph: A) { id: ID }"),
        True,
    )
    assert_equal(
        contains_supergraph_spec(
            'type User @join__directive(name: "a") { id: ID }'
        ),
        True,
    )


def test_a_spec_name_at_the_start_does_not_match() raises:
    assert_equal(contains_supergraph_spec("tag"), False)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

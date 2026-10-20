# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests ported from graphql-go-tools v2
`v2/pkg/astnormalization/defer_ensure_typename_test.go`.

The tests that start with `test_extra` are extra. Their outputs are the
outputs of the upstream visitor.
"""

from _norm import *
from _norm_fixtures import *
from gql_language.ast import Document
from gql_normalization.defer import defer_ensure_typename
from gql_schema.definition import Schema
from std.testing import TestSuite


def ensure_pass(
    mut document: Document, schema: Schema, mut variables: String
) raises:
    """Upstream `deferEnsureTypename`."""
    defer_ensure_typename(document)


def test_mixed_deferred_and_non_deferred_fields_no_placeholder_needed() raises:
    run(
        ensure_pass,
        TEST_DEFINITION,
        """
				{
					user {
						id
						name @__defer_internal(id: 1)
					}
				}""",
        """
				{
					user {
						id
						name @__defer_internal(id: 1)
					}
				}""",
    )


def test_all_fields_deferred_parent_not_deferred_plain_placeholder_added() raises:
    run(
        ensure_pass,
        TEST_DEFINITION,
        """
				{
					user {
						name @__defer_internal(id: 1)
						age @__defer_internal(id: 1)
					}
				}""",
        """
				{
					user {
						name @__defer_internal(id: 1)
						age @__defer_internal(id: 1)
						__internal_typename: __typename
					}
				}""",
    )


def test_all_fields_deferred_with_different_ids_parent_not_deferred_plain_placeholder_added() raises:
    run(
        ensure_pass,
        TEST_DEFINITION,
        """
				{
					user {
						name @__defer_internal(id: 1)
						age @__defer_internal(id: 2)
					}
				}""",
        """
				{
					user {
						name @__defer_internal(id: 1)
						age @__defer_internal(id: 2)
						__internal_typename: __typename
					}
				}""",
    )


def test_all_fields_deferred_parent_deferred_with_same_id_intersection_no_placeholder() raises:
    run(
        ensure_pass,
        TEST_DEFINITION,
        """
				{
					user @__defer_internal(id: 1) {
						name @__defer_internal(id: 1)
						age @__defer_internal(id: 2)
					}
				}""",
        """
				{
					user @__defer_internal(id: 1) {
						name @__defer_internal(id: 1)
						age @__defer_internal(id: 2)
					}
				}""",
    )


def test_all_fields_deferred_parent_deferred_with_different_id_no_intersection_placeholder_with_parent_id_added() raises:
    run(
        ensure_pass,
        TEST_DEFINITION,
        """
				{
					user @__defer_internal(id: 1) {
						name @__defer_internal(id: 2)
						age @__defer_internal(id: 3)
					}
				}""",
        """
				{
					user @__defer_internal(id: 1) {
						name @__defer_internal(id: 2)
						age @__defer_internal(id: 3)
						__internal_typename: __typename @__defer_internal(id: 1)
					}
				}""",
    )


def test_extra_selection_set_without_fields() raises:
    run(
        ensure_pass,
        TEST_DEFINITION,
        """
				{
					user {
						... on Dog {
							name @__defer_internal(id: 1)
						}
					}
				}""",
        """
				{
					user {
						... on Dog {
							name @__defer_internal(id: 1)
							__internal_typename: __typename
						}
					}
				}""",
    )


def test_extra_nearest_deferred_field_is_the_parent() raises:
    run(
        ensure_pass,
        TEST_DEFINITION,
        """
				{
					user @__defer_internal(id: 1) {
						info {
							name @__defer_internal(id: 2)
							age @__defer_internal(id: "x")
						}
					}
				}""",
        """
				{
					user @__defer_internal(id: 1) {
						info {
							name @__defer_internal(id: 2)
							age @__defer_internal(id: "x")
							__internal_typename: __typename @__defer_internal(id: 1)
						}
					}
				}""",
    )


def test_extra_parent_directive_without_integer_id() raises:
    run(
        ensure_pass,
        TEST_DEFINITION,
        """
				{
					user @__defer_internal(id: "x") {
						name @__defer_internal(id: 1)
					}
					friend @__defer_internal {
						name @__defer_internal(id: 1)
					}
				}
				fragment UserFields on Dog {
					info {
						name @__defer_internal(id: 1)
					}
				}""",
        """
				{
					user @__defer_internal(id: "x") {
						name @__defer_internal(id: 1)
						__internal_typename: __typename
					}
					friend @__defer_internal {
						name @__defer_internal(id: 1)
						__internal_typename: __typename
					}
				}
				fragment UserFields on Dog {
					info {
						name @__defer_internal(id: 1)
						__internal_typename: __typename
					}
				}""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

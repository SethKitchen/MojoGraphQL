# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests ported from graphql-go-tools v2
`v2/pkg/astnormalization/directive_include_skip_test.go`."""

from _norm import *
from _norm_fixtures import *
from std.testing import TestSuite


def test_remove_static_include_true_on_inline_fragment() raises:
    run(
        directive_include_skip_pass,
        TEST_DEFINITION,
        """
				{
					dog {
						name: nickname
						... @include(if: true) {
							includeName: name @include(if: true)
							notIncludeName: name @include(if: false)
							notSkipName: name @skip(if: false)
							skipName: name @skip(if: true)
						}
					}
					notInclude: dog @include(if: false) {
						name
					}
					skip: dog @skip(if: true) {
						name
					}
				}""",
        """
				{
					dog {
						name: nickname
						... {
							includeName: name
							notSkipName: name
						}
					}
				}""",
    )


def test_if_node_is_last_one_replace_selection_with_a_typename() raises:
    run(
        directive_include_skip_pass,
        TEST_DEFINITION,
        """
				{
					dog {
						... @include(if: false) {
							includeName: name
						}
					}
					notInclude: dog {
						name @include(if: false)
					}
					skip: dog {
						name @skip(if: true)
					}
				}""",
        """
				{
					dog {__internal_typename: __typename}
					notInclude: dog {__internal_typename: __typename}
					skip: dog {__internal_typename: __typename}
				}""",
    )


def test_include_variables_true() raises:
    run_with_variables(
        directive_include_skip_pass,
        TEST_DEFINITION,
        """
				query($yes: Boolean!) {
					dog {
						... @include(if: $yes) {
							includeName: name
						}
					}
					withAlias: dog {
						name @include(if: $yes)
					}
				}""",
        """
				query($yes: Boolean!) {
					dog {
						... {
							includeName: name
						}
					}
					withAlias: dog {
						name
					}
				}""",
        """{"yes":true}""",
    )


def test_include_variables_false() raises:
    run_with_variables(
        directive_include_skip_pass,
        TEST_DEFINITION,
        """
				query($no: Boolean!) {
					dog {
						... @include(if: $no) {
							includeName: name
						}
					}
					withAlias: dog {
						name @include(if: $no)
					}
				}""",
        """
				query($no: Boolean!){
					dog {
						__internal_typename: __typename
					}
					withAlias: dog {
						__internal_typename: __typename
					}
				}""",
        """{"no":false}""",
    )


def test_include_variables_mixed() raises:
    run_with_variables(
        directive_include_skip_pass,
        TEST_DEFINITION,
        """
				query($yes: Boolean!, $no: Boolean!) {
					dog {
						... @include(if: $yes) {
							includeName: name
						}
					}
					withAlias: dog {
						name @include(if: $no)
					}
				}""",
        """
				query($yes: Boolean! $no: Boolean!){
					dog {
						__internal_typename: __typename
					}
					withAlias: dog {
						name
					}
				}""",
        """{"yes":false,"no":true}""",
    )


def test_skip_variables_true() raises:
    run_with_variables(
        directive_include_skip_pass,
        TEST_DEFINITION,
        """
				query($yes: Boolean!) {
					dog {
						... @skip(if: $yes) {
							includeName: name
						}
					}
					withAlias: dog {
						name @skip(if: $yes)
					}
				}""",
        """
				query($yes: Boolean!) {
					dog {
						__internal_typename: __typename
					}
					withAlias: dog {
						__internal_typename: __typename
					}
				}""",
        """{"yes":true}""",
    )


def test_skip_variables_false() raises:
    run_with_variables(
        directive_include_skip_pass,
        TEST_DEFINITION,
        """
				query($no: Boolean!) {
					dog {
						... @skip(if: $no) {
							includeName: name
						}
					}
					withAlias: dog {
						name @skip(if: $no)
					}
				}""",
        """
				query($no: Boolean!){
					dog {
						... {
							includeName: name
						}
					}
					withAlias: dog {
						name
					}
				}""",
        """{"no":false}""",
    )


def test_skip_variables_mixed() raises:
    run_with_variables(
        directive_include_skip_pass,
        TEST_DEFINITION,
        """
				query($yes: Boolean!, $no: Boolean!) {
					dog {
						... @skip(if: $yes) {
							includeName: name
						}
					}
					withAlias: dog {
						name @skip(if: $no)
					}
				}""",
        """
				query($yes: Boolean!, $no: Boolean!) {
					dog {
						__internal_typename: __typename
					}
					withAlias: dog {
						name
					}
				}""",
        """{"yes":true,"no":false}""",
    )


def test_skip_include_variables_mixed() raises:
    run_with_variables(
        directive_include_skip_pass,
        TEST_DEFINITION,
        """
				query($yes: Boolean!, $no: Boolean!) {
					dog {
						... @skip(if: $yes) {
							includeName: name
						}
					}
					withAlias: dog {
						name @include(if: $no)
					}
				}""",
        """
				query($yes: Boolean!, $no: Boolean!) {
					dog {
						__internal_typename: __typename
					}
					withAlias: dog {
						__internal_typename: __typename
					}
				}""",
        """{"yes":true,"no":false}""",
    )


def test_skip_include_variables_mixed_reverse() raises:
    run_with_variables(
        directive_include_skip_pass,
        TEST_DEFINITION,
        """
				query($yes: Boolean!, $no: Boolean!) {
					dog {
						... @include(if: $yes) {
							includeName: name
						}
					}
					withAlias: dog {
						name @skip(if: $no)
					}
				}""",
        """
				query($yes: Boolean!, $no: Boolean!) {
					dog {
						... {
							includeName: name
						}
					}
					withAlias: dog {
						name
					}
				}""",
        """{"yes":true,"no":false}""",
    )


def test_skip_should_respect_default_values_for_variables() raises:
    run_with_variables(
        directive_include_skip_pass,
        TEST_DEFINITION,
        """
				query($yes: Boolean = true, $no: Boolean = false) {
					dog {
						... @skip(if: $yes) {
							includeName: name
						}
					}
					withAlias: dog {
						name @skip(if: $no)
					}
				}""",
        """
				query($yes: Boolean = true, $no: Boolean = false) {
					dog {
						__internal_typename: __typename
					}
					withAlias: dog {
						name
					}
				}""",
        """{}""",
    )


def test_include_should_respect_default_values_for_variables() raises:
    run_with_variables(
        directive_include_skip_pass,
        TEST_DEFINITION,
        """
				query($yes: Boolean = true, $no: Boolean = false) {
					dog {
						... @include(if: $yes) {
							includeName: name
						}
					}
					withAlias: dog {
						name @include(if: $no)
					}
				}""",
        """
				query($yes: Boolean = true, $no: Boolean = false) {
					dog {
						... {
							includeName: name
						}
					}
					withAlias: dog {
						__internal_typename: __typename
					}
				}""",
        """{}""",
    )


def test_skip_should_respect_values_over_default_values_for_variables() raises:
    run_with_variables(
        directive_include_skip_pass,
        TEST_DEFINITION,
        """
				query($yes: Boolean = false, $no: Boolean = true) {
					dog {
						... @skip(if: $yes) {
							includeName: name
						}
					}
					withAlias: dog {
						name @skip(if: $no)
					}
				}""",
        """
				query($yes: Boolean = false, $no: Boolean = true) {
					dog {
						__internal_typename: __typename
					}
					withAlias: dog {
						name
					}
				}""",
        """{"yes":true,"no":false}""",
    )


def test_include_should_respect_values_over_default_values_for_variables() raises:
    run_with_variables(
        directive_include_skip_pass,
        TEST_DEFINITION,
        """
				query($yes: Boolean = false, $no: Boolean = true) {
					dog {
						... @include(if: $yes) {
							includeName: name
						}
					}
					withAlias: dog {
						name @include(if: $no)
					}
				}""",
        """
				query($yes: Boolean = false, $no: Boolean = true) {
					dog {
						... {
							includeName: name
						}
					}
					withAlias: dog {
						__internal_typename: __typename
					}
				}""",
        """{"yes":true,"no":false}""",
    )


def test_keep_nodes_skip_should_keep_nodes() raises:
    run_with_variables(
        keep_nodes_pass,
        TEST_DEFINITION,
        """
				query($yes: Boolean = false, $no: Boolean = true) {
					dog {
						... @skip(if: $yes) {
							includeName: name
						}
					}
					withAlias: dog {
						name @skip(if: $no)
					}
				}""",
        """
				query($yes: Boolean = false, $no: Boolean = true) {
					dog {
						... {
							includeName: name
						}
					}
					withAlias: dog {
						name
					}
				}""",
        """{"yes":true,"no":false}""",
    )


def test_keep_nodes_include_should_keep_nodes() raises:
    run_with_variables(
        keep_nodes_pass,
        TEST_DEFINITION,
        """
				query($yes: Boolean = false, $no: Boolean = true) {
					dog {
						... @include(if: $yes) {
							includeName: name
						}
					}
					withAlias: dog {
						name @include(if: $no)
					}
				}""",
        """
				query($yes: Boolean = false, $no: Boolean = true) {
					dog {
						... {
							includeName: name
						}
					}
					withAlias: dog {
						name
					}
				}""",
        """{"yes":true,"no":false}""",
    )


def test_keep_nodes_include_skip_should_keep_nodes_using_default_values() raises:
    run_with_variables(
        keep_nodes_pass,
        TEST_DEFINITION,
        """
				query($yes: Boolean = false, $no: Boolean = true) {
					dog {
						... @include(if: $yes) {
							includeName: name
						}
					}
					withAlias: dog {
						name @skip(if: $no)
					}
				}""",
        """
				query($yes: Boolean = false, $no: Boolean = true) {
					dog {
						... {
							includeName: name
						}
					}
					withAlias: dog {
						name
					}
				}""",
        """{}""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

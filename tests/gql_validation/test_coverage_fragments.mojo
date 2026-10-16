# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests beyond upstream for the fragment rules: they cover unknown type
conditions in FragmentsOnCompositeTypesRule and PossibleFragmentSpreadsRule,
fragments under a field with no composite type, and NoUnusedFragmentsRule on
a document with no operation and on unused fragments before and between
used ones.

The expected errors come from graphql-js 16.14.2: each document was run
through `validate` with the same schema and rule.
"""

from _harness import expect_errors, expect_valid
from gql_validation.rules import ValidationRule
from std.testing import TestSuite


def test_fragment_on_an_unknown_type_is_not_reported() raises:
    expect_valid(
        ValidationRule.FRAGMENTS_ON_COMPOSITE_TYPES,
        "fragment F on Unknown { name }",
    )


def test_document_with_no_operation() raises:
    expect_errors(
        ValidationRule.NO_UNUSED_FRAGMENTS,
        "fragment F on Dog { name }",
        ['Fragment "F" is never used. (1:1)'],
    )


def test_unused_fragment_before_a_used_fragment() raises:
    expect_errors(
        ValidationRule.NO_UNUSED_FRAGMENTS,
        (
            "fragment A on Dog { name } fragment B on Dog { name } { dog {"
            " ...B } }"
        ),
        ['Fragment "A" is never used. (1:1)'],
    )


def test_unused_fragment_between_used_fragments() raises:
    # The spread of B takes the first fragment id, so the unused A has an
    # id below that of the used C.
    expect_errors(
        ValidationRule.NO_UNUSED_FRAGMENTS,
        (
            "fragment A on Dog { name } fragment B on Dog { ...C } fragment C"
            " on Dog { name } { dog { ...B } }"
        ),
        ['Fragment "A" is never used. (1:1)'],
    )


def test_inline_fragments_without_two_composite_types() raises:
    expect_valid(
        ValidationRule.POSSIBLE_FRAGMENT_SPREADS,
        (
            "{ dog { ... on Unknown { name } ... on Int { name } } unknown {"
            " ... on Dog { name } } }"
        ),
    )


def test_fragment_spreads_without_two_composite_types() raises:
    expect_valid(
        ValidationRule.POSSIBLE_FRAGMENT_SPREADS,
        (
            "{ dog { ...F } unknown { ...G } } fragment F on Unknown { name }"
            " fragment G on Dog { name }"
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

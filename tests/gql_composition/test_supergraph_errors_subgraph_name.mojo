# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Checks for `SubgraphNameRule`.

The id is the constant-case subgraph name. Hive's `composeServices` is
the source of the expected errors.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_id_must_not_start_with_two_underscores() raises:
    check(
        [
            sg("__users", "type Query {\n  a: String\n}"),
        ],
        [
            (
                '[INVALID_GRAPHQL] Name "__USERS" must not begin with "__",'
                " which is reserved by GraphQL introspection."
            ),
        ],
    )


def test_ids_are_reported_in_id_order() raises:
    check(
        [
            sg("__zeta", "type Query {\n  a: String\n}"),
            sg("__alpha", "type Query {\n  b: String\n}"),
        ],
        [
            (
                '[INVALID_GRAPHQL] Name "__ALPHA" must not begin with "__",'
                " which is reserved by GraphQL introspection."
            ),
            (
                '[INVALID_GRAPHQL] Name "__ZETA" must not begin with "__",'
                " which is reserved by GraphQL introspection."
            ),
        ],
    )


def test_ordinary_name_is_allowed() raises:
    check(
        [
            sg("users", "type Query {\n  a: String\n}"),
        ],
        [],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

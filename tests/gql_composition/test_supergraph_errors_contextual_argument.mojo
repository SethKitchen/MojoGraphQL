# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Checks for `ContextualArgumentRule`.

Hive's `composeServices` is the source of the expected errors. A nullable
copy of the argument does not make it required.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_required_copy_is_not_contextual() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext"])\n\ntype Query {\n '
                    ' a: Owner\n}\n\ntype Owner @key(fields: "id")'
                    ' @context(name: "c") {\n  id: ID!\n  child: Target\n  s:'
                    ' String!\n}\n\ntype Target @key(fields: "id") {\n  id:'
                    ' ID!\n  f(x: String @fromContext(field: "$c { s }")):'
                    " Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext"])\n\ntype Query {\n '
                    ' b: Target\n}\n\ntype Target @key(fields: "id") {\n  id:'
                    " ID!\n  f(x: String!): Int\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Target.f" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "a" and "b" and defined as non-shareable in all of'
                " them"
            ),
            (
                "[CONTEXTUAL_ARGUMENT_NOT_CONTEXTUAL_IN_ALL_SUBGRAPHS] Argument"
                ' "Target.f(x:)" is contextual in at least one subgraph but in'
                ' "Target.f(x:)" it does not have @fromContext, is not nullable'
                " and has no default value."
            ),
        ],
    )


def test_nullable_copy_is_allowed() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext"])\n\ntype Query {\n '
                    ' a: Owner\n}\n\ntype Owner @key(fields: "id")'
                    ' @context(name: "c") {\n  id: ID!\n  child: Target\n  s:'
                    ' String!\n}\n\ntype Target @key(fields: "id") {\n  id:'
                    ' ID!\n  f(x: String @fromContext(field: "$c { s }")):'
                    " Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext"])\n\ntype Query {\n '
                    ' b: Target\n}\n\ntype Target @key(fields: "id") {\n  id:'
                    " ID!\n  f(x: String): Int\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Target.f" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "a" and "b" and defined as non-shareable in all of'
                " them"
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

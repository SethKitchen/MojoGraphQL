# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Composed directive checks of the supergraph phase.

The upstream file for these checks is Hive Federation Composition v0.27.0
`__tests__/subgraph/errors/DIRECTIVE_COMPOSITION_ERROR.spec.ts`. These
tests add cases that the upstream file does not have: a feature link
without a version, and one applied name that two subgraphs share. The
expected errors are Hive `validate` on the same subgraphs.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_hive_case_d1_versionless() raises:
    # The expected errors are Hive v0.27.0 `validate` on these subgraphs.
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\nextend schema @link(url:'
                    ' "https://myspecs.dev/lowercase", import:'
                    ' ["@lowercase"]) @composeDirective(name:'
                    ' "@lowercase")\ndirective @lowercase on'
                    " FIELD_DEFINITION\ntype Query { a: String @lowercase }"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype Query { b: String }'
                ),
            ),
        ],
        [],
    )


def test_hive_case_d3_alias3() raises:
    # The expected errors are Hive v0.27.0 `validate` on these subgraphs.
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\nextend schema @link(url:'
                    ' "https://myspecs.dev/lowercase/v1.0", import: [{name:'
                    ' "@lowercase", as: "@lower"}]) @composeDirective(name:'
                    ' "@lower")\ndirective @lower on FIELD_DEFINITION\ntype'
                    " Query { a: String @lower }"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\nextend schema @link(url:'
                    ' "https://myspecs.dev/lowercase/v1.0", import: [{name:'
                    ' "@lowercase", as: "@lower"}]) @composeDirective(name:'
                    ' "@lower")\ndirective @lower on FIELD_DEFINITION\ntype'
                    " Query { b: String @lower }"
                ),
            ),
            sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\nextend schema @link(url:'
                    ' "https://myspecs.dev/lowercase/v1.0", import:'
                    ' ["@lowercase"]) @composeDirective(name:'
                    ' "@lowercase")\ndirective @lowercase on'
                    " FIELD_DEFINITION\ntype Query { c: String @lowercase }"
                ),
            ),
        ],
        [
            (
                "[DIRECTIVE_COMPOSITION_ERROR] Composed directive"
                ' "@lowercase" has incompatible name across subgraphs: it'
                ' has name "@lower" in subgraphs "a", "b" but name'
                ' "@lowercase" in subgraph "c". Composed directive must'
                " have the same name across all subgraphs."
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

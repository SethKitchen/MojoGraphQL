# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_composition.rules_marks`.

Upstream has no test file for these cases. The expected errors are those of
the subgraph phase of Hive Federation Composition v0.27.0 `validate` in
Node.js on the same subgraphs.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_inaccessible_everywhere() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@inaccessible\", \"@tag\", \"@interfaceObject\"])\ntype Query { a: Int b(x: Int @inaccessible): Int @inaccessible }\ntype O @inaccessible { a(x: Int @inaccessible): Int @inaccessible }\nextend type O @inaccessible\ntype IO @key(fields: \"id\") @interfaceObject @inaccessible { id: ID! a: Int @inaccessible }\ninterface I @inaccessible { a(x: Int @inaccessible): Int @inaccessible }\nextend interface I @inaccessible\nscalar S @inaccessible\nextend scalar S @inaccessible\nunion U @inaccessible = O\nextend union U @inaccessible\ninput In @inaccessible { a: Int @inaccessible b: Int }\nextend input In @inaccessible\nenum E @inaccessible { A @inaccessible B }\nextend enum E @inaccessible\ndirective @d(x: Int @inaccessible) on OBJECT\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] The directive \"@inaccessible\" can only be used once at this location.",
            "[INVALID_GRAPHQL] [a] The directive \"@inaccessible\" can only be used once at this location.",
            "[INVALID_GRAPHQL] [a] The directive \"@inaccessible\" can only be used once at this location.",
            "[INVALID_GRAPHQL] [a] The directive \"@inaccessible\" can only be used once at this location.",
            "[INVALID_GRAPHQL] [a] The directive \"@inaccessible\" can only be used once at this location.",
            "[INVALID_GRAPHQL] [a] The directive \"@inaccessible\" can only be used once at this location.",
        ],
    )


def test_tag_everywhere() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@inaccessible\", \"@tag\", \"@interfaceObject\"])\ntype Query { a: Int b(x: Int @tag(name: \"t\")): Int @tag(name: \"t\") }\ntype O @tag(name: \"t\") { a(x: Int @tag(name: \"t\")): Int @tag(name: \"t\") }\nextend type O @tag(name: \"t\")\ntype IO @key(fields: \"id\") @interfaceObject @tag(name: \"t\") { id: ID! a: Int @tag(name: \"t\") }\ninterface I @tag(name: \"t\") { a(x: Int @tag(name: \"t\")): Int @tag(name: \"t\") }\nextend interface I @tag(name: \"t\")\nscalar S @tag(name: \"t\")\nextend scalar S @tag(name: \"t\")\nunion U @tag(name: \"t\") = O\nextend union U @tag(name: \"t\")\ninput In @tag(name: \"t\") { a: Int @tag(name: \"t\") b: Int }\nextend input In @tag(name: \"t\")\nenum E @tag(name: \"t\") { A @tag(name: \"t\") B }\nextend enum E @tag(name: \"t\")\ndirective @d(x: Int @tag(name: \"t\")) on OBJECT\nextend schema @tag(name: \"s\")\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Directive \"@tag\" may not be used on SCHEMA.",
        ],
    )


def test_tag_without_name() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@inaccessible\", \"@tag\", \"@interfaceObject\"])\ntype Query { a: Int @tag b: Int @tag(name: 1) c: Int @tag(name: \"\") }\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Directive \"@tag\" argument \"name\" of type \"String!\" is required, but it was not provided.",
            "[INVALID_GRAPHQL] [a] Invalid value for \"@tag(name:)\" of type \"String!\" in application of \"@tag\" to \"Query.b\".",
        ],
    )


def test_tag_and_inaccessible_v1() raises:
    check(
        [
            sg("a", "type Query { a: Int @tag(name: \"t\") @inaccessible }\ntype O @inaccessible @tag(name: \"o\") { a: Int }\n"),
        ],
        [
        ],
    )


def test_inaccessible_on_input_with_fields() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@inaccessible\", \"@tag\", \"@interfaceObject\"])\ntype Query { a(x: In): Int }\ninput In @inaccessible { a: Int b: Int }\n"),
        ],
        [
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

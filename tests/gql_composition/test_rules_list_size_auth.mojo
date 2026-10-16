# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_composition.rules_list_size` and `gql_composition.rules_auth`.

Upstream has no test file for these cases. The expected errors are those of
the subgraph phase of Hive Federation Composition v0.27.0 `validate` in
Node.js on the same subgraphs.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_list_size_arguments() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@listSize\", \"@cost\", \"@authenticated\", \"@policy\", \"@requiresScopes\", \"@interfaceObject\"])\ntype Query {\n  a(first: Int): [Int] @listSize(assumedSize: 1, slicingArguments: [\"first\"], sizedFields: [], requireOneSlicingArgument: false)\n  b: [Int] @listSize(assumedSize: \"x\")\n  c: [Int] @listSize(slicingArguments: \"first\")\n  d: [Int] @listSize(slicingArguments: [1])\n  e: P @listSize(sizedFields: \"items\")\n  f: P @listSize(sizedFields: [1])\n  g: [Int] @listSize(requireOneSlicingArgument: \"yes\")\n  h: [Int] @listSize(slicingArguments: null, sizedFields: null)\n  i(first: Int!, last: Int): [Int] @listSize(slicingArguments: [\"first\", \"last\", \"missing\"])\n  j: P @listSize(sizedFields: [\"items\", \"count\", \"missing\"])\n  k: Int @listSize(assumedSize: -1)\n  l(first: String): [Int] @listSize(slicingArguments: [\"first\"], requireOneSlicingArgument: true)\n  m(first: Int): [Int] @listSize(slicingArguments: [], requireOneSlicingArgument: true)\n}\ntype P { items: [Int] count: Int }\n"),
        ],
        [
            "[LIST_SIZE_INVALID_ASSUMED_SIZE] [a] The value of @listSize(assumedSize:) must be an integer",
            "[LIST_SIZE_INVALID_SLICING_ARGUMENT] [a] The value of @listSize(slicingArguments:) must be a list of strings",
            "[LIST_SIZE_INVALID_SLICING_ARGUMENT] [a] The value of @listSize(slicingArguments:) must be a list of strings",
            "[LIST_SIZE_INVALID_SIZED_FIELD] [a] The value of @listSize(sizedFields:) must be a list of strings",
            "[LIST_SIZE_INVALID_SIZED_FIELD] [a] The value of @listSize(sizedFields:) must be a list of strings",
            "[LIST_SIZE_INVALID_REQUIRE_ONE_SLICING_ARGUMENT] [a] The value of @listSize(requireOneSlicingArgument:) must be a boolean when defined",
            "[LIST_SIZE_INVALID_SLICING_ARGUMENT] [a] The value of @listSize(slicingArguments:) must be a list of strings",
            "[LIST_SIZE_INVALID_SLICING_ARGUMENT] [a] \"Query.i\" references \"missing\" argument in @listSize(slicingArguments:) that does not exist.",
            "[LIST_SIZE_APPLIED_TO_NON_LIST] [a] \"Query.j\" references \"count\" field in @listSize(sizedFields:) argument that is not a list.",
            "[LIST_SIZE_INVALID_SIZED_FIELD] [a] \"Query.j\" references \"missing\" field in @listSize(sizedFields:) argument that does not exist.",
            "[LIST_SIZE_INVALID_ASSUMED_SIZE] [a] \"Query.k\" has negative @listSize(assumedSize:) value",
            "[LIST_SIZE_INVALID_SLICING_ARGUMENT] [a] \"Query.l\" references \"first\" argument in @listSize(slicingArguments:) that is not an integer.",
            "[INVALID_GRAPHQL] [a] Invalid value for \"@listSize(assumedSize:)\" of type \"Int\" in application of \"@listSize\" to \"Query.b\".",
            "[INVALID_GRAPHQL] [a] Invalid value for \"@listSize(slicingArguments:)\" of type \"[String!]\" in application of \"@listSize\" to \"Query.d\".",
            "[INVALID_GRAPHQL] [a] Invalid value for \"@listSize(sizedFields:)\" of type \"[String!]\" in application of \"@listSize\" to \"Query.f\".",
            "[INVALID_GRAPHQL] [a] Invalid value for \"@listSize(requireOneSlicingArgument:)\" of type \"Boolean\" in application of \"@listSize\" to \"Query.g\".",
            "[INVALID_GRAPHQL] [a] Invalid value for \"@listSize(slicingArguments:)\" of type \"[String!]\" in application of \"@listSize\" to \"Query.h\".",
            "[INVALID_GRAPHQL] [a] Invalid value for \"@listSize(sizedFields:)\" of type \"[String!]\" in application of \"@listSize\" to \"Query.h\".",
        ],
    )


def test_list_size_places() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@listSize\", \"@cost\", \"@authenticated\", \"@policy\", \"@requiresScopes\", \"@interfaceObject\"])\ntype Query { a: Int }\ntype T @listSize(assumedSize: 1) { a: [Int] }\ninterface I { a: [Int] @listSize(assumedSize: 1) }\ntype IO @key(fields: \"id\") @interfaceObject { id: ID! a: [Int] @listSize(assumedSize: 1) }\ninput In { a: [Int] @listSize(assumedSize: 1) }\nextend schema @listSize(assumedSize: 1)\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Directive \"@listSize\" may not be used on SCHEMA.",
            "[INVALID_GRAPHQL] [a] Directive \"@listSize\" may not be used on OBJECT.",
            "[INVALID_GRAPHQL] [a] Directive \"@listSize\" may not be used on INPUT_FIELD_DEFINITION.",
        ],
    )


def test_auth_places() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@listSize\", \"@cost\", \"@authenticated\", \"@policy\", \"@requiresScopes\", \"@interfaceObject\"])\ntype Query { a: Int }\ntype T @authenticated @policy(policies: [[\"a\"]]) @requiresScopes(scopes: [[\"s\"]]) { a: Int @authenticated @policy(policies: [[\"b\", \"c\"], [\"d\"]]) @requiresScopes(scopes: [[\"t\"]]) }\nextend type T @policy(policies: [[\"e\"]]) @requiresScopes(scopes: [[\"u\"], [\"v\"]]) @authenticated\ninterface I @authenticated { a: Int @authenticated @policy(policies: [[\"x\"]]) }\ntype IO @key(fields: \"id\") @interfaceObject @authenticated @policy(policies: [[\"io\"]]) { id: ID! a: Int @requiresScopes(scopes: [[\"s\"]]) }\nscalar S @authenticated @policy(policies: [[\"s\"]]) @requiresScopes(scopes: [[\"s\"]])\nextend scalar S @policy(policies: [[\"t\"]])\nenum E @authenticated @requiresScopes(scopes: [[\"e\"]]) { A }\nextend enum E @authenticated\nextend schema @authenticated\nunion U @authenticated = T\ninput In { a: Int @authenticated }\n"),
        ],
        [
            "[AUTH_REQUIREMENTS_APPLIED_ON_INTERFACE] [a] Invalid use of @authenticated on interface \"I\": @authenticated cannot be applied on interfaces, interface fields and interface objects",
            "[AUTH_REQUIREMENTS_APPLIED_ON_INTERFACE] [a] Invalid use of @authenticated on field \"I.a\": @authenticated cannot be applied on interfaces, interface fields and interface objects",
            "[AUTH_REQUIREMENTS_APPLIED_ON_INTERFACE] [a] Invalid use of @policy on field \"I.a\": @policy cannot be applied on interfaces, interface fields and interface objects",
            "[AUTH_REQUIREMENTS_APPLIED_ON_INTERFACE] [a] Invalid use of @authenticated on interface object \"IO\": @authenticated cannot be applied on interfaces, interface fields and interface objects",
            "[AUTH_REQUIREMENTS_APPLIED_ON_INTERFACE] [a] Invalid use of @policy on interface object \"IO\": @policy cannot be applied on interfaces, interface fields and interface objects",
            "[INVALID_GRAPHQL] [a] Directive \"@authenticated\" may not be used on SCHEMA.",
            "[INVALID_GRAPHQL] [a] The directive \"@policy\" can only be used once at this location.",
            "[INVALID_GRAPHQL] [a] The directive \"@requiresScopes\" can only be used once at this location.",
            "[INVALID_GRAPHQL] [a] The directive \"@authenticated\" can only be used once at this location.",
            "[INVALID_GRAPHQL] [a] The directive \"@policy\" can only be used once at this location.",
            "[INVALID_GRAPHQL] [a] The directive \"@authenticated\" can only be used once at this location.",
            "[INVALID_GRAPHQL] [a] Directive \"@authenticated\" may not be used on UNION.",
            "[INVALID_GRAPHQL] [a] Directive \"@authenticated\" may not be used on INPUT_FIELD_DEFINITION.",
        ],
    )


def test_auth_bad_values() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@listSize\", \"@cost\", \"@authenticated\", \"@policy\", \"@requiresScopes\", \"@interfaceObject\"])\ntype Query { a: Int }\ntype T { a: Int @policy(policies: \"x\") b: Int @policy(policies: [\"x\"]) c: Int @policy(policies: [[1]]) d: Int @requiresScopes(scopes: [[\"s\"], \"t\"]) e: Int @policy f: Int @requiresScopes(scopes: [[]]) g: Int @policy(policies: []) }\n"),
        ],
        [
            "THROWS Expected \"@policy(policies:)\" to be a list",
        ],
    )


def test_auth_on_interface_v2_8() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@listSize\", \"@cost\", \"@authenticated\", \"@policy\", \"@requiresScopes\", \"@interfaceObject\"])\ntype Query { a: Int }\ninterface I @authenticated @policy(policies: [[\"a\"]]) @requiresScopes(scopes: [[\"s\"]]) { a: Int @authenticated }\n"),
        ],
        [
            "[AUTH_REQUIREMENTS_APPLIED_ON_INTERFACE] [a] Invalid use of @authenticated on interface \"I\": @authenticated cannot be applied on interfaces, interface fields and interface objects",
            "[AUTH_REQUIREMENTS_APPLIED_ON_INTERFACE] [a] Invalid use of @policy on interface \"I\": @policy cannot be applied on interfaces, interface fields and interface objects",
            "[AUTH_REQUIREMENTS_APPLIED_ON_INTERFACE] [a] Invalid use of @requiresScopes on interface \"I\": @requiresScopes cannot be applied on interfaces, interface fields and interface objects",
            "[AUTH_REQUIREMENTS_APPLIED_ON_INTERFACE] [a] Invalid use of @authenticated on field \"I.a\": @authenticated cannot be applied on interfaces, interface fields and interface objects",
        ],
    )


def test_auth_on_interface_object_v2_8() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@listSize\", \"@cost\", \"@authenticated\", \"@policy\", \"@requiresScopes\", \"@interfaceObject\"])\ntype Query { a: Int }\ntype IO @key(fields: \"id\") @interfaceObject @authenticated @requiresScopes(scopes: [[\"s\"]]) { id: ID! }\n"),
        ],
        [
            "[AUTH_REQUIREMENTS_APPLIED_ON_INTERFACE] [a] Invalid use of @authenticated on interface object \"IO\": @authenticated cannot be applied on interfaces, interface fields and interface objects",
            "[AUTH_REQUIREMENTS_APPLIED_ON_INTERFACE] [a] Invalid use of @requiresScopes on interface object \"IO\": @requiresScopes cannot be applied on interfaces, interface fields and interface objects",
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

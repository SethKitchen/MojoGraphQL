# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_composition.rules_elements`.

Upstream has no test file for these cases. The expected errors are those of
the subgraph phase of Hive Federation Composition v0.27.0 `validate` in
Node.js on the same subgraphs.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_cost_weights() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int }\ntype T @cost(weight: 1) { a(x: Int @cost(weight: 2)): Int @cost(weight: 3) }\ninterface I @cost(weight: 1) { a: Int @cost(weight: 1) }\ntype IO @key(fields: \"id\") @interfaceObject @cost(weight: 4) { id: ID! }\nscalar S @cost(weight: 5)\nextend scalar S @cost(weight: 6)\nenum E @cost(weight: 7) { A }\nextend enum E @cost(weight: 8)\ninput In { a: Int @cost(weight: 9) }\ndirective @d(x: Int @cost(weight: 10)) on OBJECT\nextend schema @cost(weight: 1)\nunion U @cost(weight: 1) = T\n"),
        ],
        [
            "[COST_APPLIED_TO_INTERFACE_FIELD] [a] @cost cannot be applied to interface \"I.a\"",
            "[INVALID_GRAPHQL] [a] Directive \"@cost\" may not be used on SCHEMA.",
            "[INVALID_GRAPHQL] [a] Directive \"@cost\" may not be used on INTERFACE.",
            "[INVALID_GRAPHQL] [a] The directive \"@cost\" can only be used once at this location.",
            "[INVALID_GRAPHQL] [a] The directive \"@cost\" can only be used once at this location.",
            "[INVALID_GRAPHQL] [a] Directive \"@cost\" may not be used on UNION.",
        ],
    )


def test_cost_weight_missing() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int }\ntype T @cost { a: Int }\n"),
        ],
        [
            "THROWS Expected @cost to have a \"weight\" argument",
        ],
    )


def test_cost_weight_string() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int }\ntype T @cost(weight: \"1\") { a: Int }\n"),
        ],
        [
            "THROWS Expected \"@cost(weight:)\" to be of type Int",
        ],
    )


def test_cost_weight_huge() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int }\ntype T @cost(weight: 99999999999999999999999) { a: Int @cost(weight: -99999999999999999999999) }\n"),
        ],
        [
        ],
    )


def test_interface_object_old_version() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@interfaceObject\"])\ntype Query { a: Int }\ntype T @key(fields: \"id\") @interfaceObject { id: ID! }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@interfaceObject\".",
        ],
    )


def test_interface_object_places() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int }\ninterface I @interfaceObject { a: Int }\ntype T @key(fields: \"id\") { id: ID! a: Int @interfaceObject }\nextend schema @interfaceObject\nextend type T @interfaceObject\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_extends_places() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int }\ninterface I @extends @key(fields: \"a\") { a: Int }\ntype T @extends @key(fields: \"id\") { id: ID! b: Int }\nextend type U @extends @key(fields: \"id\") { id: ID! }\nextend schema @extends\nscalar S @extends\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_extends_v1() raises:
    check(
        [
            sg("a", "type Query { a: Int }\ntype T @extends @key(fields: \"id\") { id: ID! @external b: Int }\ninterface I @extends { a: Int }\n"),
        ],
        [
        ],
    )


def test_shareable_places() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int }\ntype T @shareable { a: Int @shareable }\nextend type T @shareable { b: Int }\ninterface I @shareable { a: Int @shareable }\nextend schema @shareable\ntype IO @key(fields: \"id\") @interfaceObject @shareable { id: ID! a: Int @shareable }\ninput In { a: Int @shareable }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_shareable_old() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\ntype Query { a: Int }\ntype T @shareable @shareable { a: Int @shareable @shareable }\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] The directive \"@shareable\" can only be used once at this location.",
            "[INVALID_GRAPHQL] [a] The directive \"@shareable\" can only be used once at this location.",
        ],
    )


def test_external_places() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int }\ntype T @key(fields: \"id\") @external { id: ID! a: Int @external }\nextend type T @external { b: Int @external }\ninterface I { a: Int @external }\nextend schema @external\ntype IO @key(fields: \"id\") @interfaceObject { id: ID! a: Int @external }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_external_v1() raises:
    check(
        [
            sg("a", "type Query { a: Int }\ntype T @key(fields: \"id\") @external { id: ID! a: Int @external }\nextend type U @key(fields: \"id\") { id: ID! @external b: Int @external @requires(fields: \"id\") }\n"),
        ],
        [
        ],
    )


def test_external_with_other_directives() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\", \"@tag\", \"@inaccessible\"])\ntype Query { a: Int }\ntype T @key(fields: \"id\") { id: ID! a: Int @external @tag(name: \"x\") @inaccessible @shareable @deprecated b: Int @external @provides(fields: \"x\") }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_override_label_0() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int @override(from: \"b\", label: \"percent(50)\") }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_override_label_1() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int @override(from: \"b\", label: \"percent(0.5)\") }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_override_label_2() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int @override(from: \"b\", label: \"percent(100)\") }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_override_label_3() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int @override(from: \"b\", label: \"percent(100.0)\") }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_override_label_4() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int @override(from: \"b\", label: \"percent(101)\") }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_override_label_5() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int @override(from: \"b\", label: \"percent(0)\") }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_override_label_6() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int @override(from: \"b\", label: \"percent(1234)\") }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_override_label_7() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int @override(from: \"b\", label: \"percent(50.12345678)\") }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_override_label_8() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int @override(from: \"b\", label: \"percent(50.123456789)\") }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_override_label_9() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int @override(from: \"b\", label: \"percent()\") }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_override_label_10() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int @override(from: \"b\", label: \"percent(5\") }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_override_label_11() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int @override(from: \"b\", label: \"percent(a)\") }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_override_label_12() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int @override(from: \"b\", label: \"percent(.5)\") }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_override_label_13() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int @override(from: \"b\", label: \"percent(5.)\") }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_override_label_14() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int @override(from: \"b\", label: \"percent(05)\") }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_override_label_15() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int @override(from: \"b\", label: \"percent(100.1)\") }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_override_label_16() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int @override(from: \"b\", label: \"percent(100.00)\") }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_override_label_17() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int @override(from: \"b\", label: \"percent(1.x)\") }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_override_label_18() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int @override(from: \"b\", label: \"x\") }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_override_label_19() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int @override(from: \"b\", label: \"\") }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_override_label_20() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int @override(from: \"b\", label: \"x:y\") }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_override_label_21() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int @override(from: \"b\", label: \"1abc\") }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_override_label_22() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int @override(from: \"b\", label: \"a-b_c:d.e/f\") }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_override_label_23() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int @override(from: \"b\", label: \"a b\") }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_override_label_24() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int @override(from: \"b\", label: \"_a\") }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_override_label_25() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int @override(from: \"b\", label: \"é\") }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_override_label_int() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int @override(from: \"b\", label: 1) }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_override_label_old_version() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int @override(from: \"b\", label: \"percent(5)\") }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_override_from_missing() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int @override b: Int @override(from: 1) c: Int @override(from: \"a\") }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_override_places() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int }\ninterface I { a: Int @override(from: \"b\") }\ntype T @override(from: \"b\") @key(fields: \"id\") { id: ID! }\nextend schema @override(from: \"b\")\ntype IO @key(fields: \"id\") @interfaceObject { id: ID! a: Int @override(from: \"b\") }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@cost\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@context\".",
        ],
    )


def test_context_names() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@cost\", \"@interfaceObject\", \"@extends\", \"@shareable\", \"@external\", \"@override\", \"@context\", \"@composeDirective\", \"@provides\", \"@requires\"])\ntype Query { a: Int }\ntype A @context(name: \"a1\") { a: Int }\ntype B @context(name: \"1a\") { a: Int }\ntype C @context(name: \"\") { a: Int }\ntype D @context(name: \"a_b\") { a: Int }\ntype E @context(name: 1) { a: Int }\ntype F @context { a: Int }\nscalar S @context(name: \"s\")\nextend schema @context(name: \"x\")\ninterface I @context(name: \"i\") { a: Int }\nunion U @context(name: \"u\") = A\nextend union U @context(name: \"v\")\ntype IO @key(fields: \"id\") @interfaceObject @context(name: \"io\") { id: ID! }\nextend type A @context(name: \"ext\")\n"),
        ],
        [
            "[CONTEXT_NAME_INVALID] [a] Context name \"1a\" is invalid. It should have only alphanumeric characters.",
            "[CONTEXT_NAME_INVALID] [a] Context name \"\" is invalid. It should have only alphanumeric characters.",
            "[CONTEXT_NAME_INVALID] [a] Context name \"a_b\" is invalid. It should have only alphanumeric characters.",
            "[INVALID_GRAPHQL] [a] Directive \"@context\" may not be used on SCHEMA.",
            "[INVALID_GRAPHQL] [a] Invalid value for \"@context(name:)\" of type \"String!\" in application of \"@context\" to \"E\".",
            "[INVALID_GRAPHQL] [a] Directive \"@context\" argument \"name\" of type \"String!\" is required, but it was not provided.",
            "[INVALID_GRAPHQL] [a] Directive \"@context\" may not be used on SCALAR.",
        ],
    )


def test_compose_directive_old_version() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\nextend schema @composeDirective(name: \"@x\")\ntype Query { a: Int }\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Unknown directive \"@composeDirective\".",
        ],
    )


def test_compose_directive_names() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@composeDirective\"]) @link(url: \"https://example.com/my/v1.0\", import: [\"@my\", { name: \"@other\", as: \"@renamed\" }, \"Type\"])\nextend schema @composeDirective(name: \"@my\") @composeDirective(name: \"my\") @composeDirective(name: 1) @composeDirective @composeDirective(name: \"@renamed\") @composeDirective(name: \"@other\") @composeDirective(name: \"@missing\") @composeDirective(name: \"@key\") @composeDirective(name: \"@local\")\ndirective @my on OBJECT\ndirective @renamed on OBJECT\ndirective @local on OBJECT\ntype Query { a: Int }\n"),
        ],
        [
            "[DIRECTIVE_COMPOSITION_ERROR] Could not find matching directive definition for argument to @composeDirective \"@other\" in subgraph \"a\".",
            "[DIRECTIVE_COMPOSITION_ERROR] Could not find matching directive definition for argument to @composeDirective \"@missing\" in subgraph \"a\".",
            "[DIRECTIVE_COMPOSITION_ERROR] Could not find matching directive definition for argument to @composeDirective \"@key\" in subgraph \"a\".",
            "[DIRECTIVE_COMPOSITION_ERROR] Directive \"@local\" in subgraph \"a\" cannot be composed because it is not a member of a core feature",
            "[INVALID_GRAPHQL] [a] Invalid value for \"@composeDirective(name:)\" of type \"String!\" in application of \"@composeDirective\" to \"schema\".",
            "[INVALID_GRAPHQL] [a] Directive \"@composeDirective\" argument \"name\" of type \"String!\" is required, but it was not provided.",
        ],
    )


def test_compose_directive_no_definitions() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@composeDirective\"]) @link(url: \"https://example.com/my/v1.0\")\nextend schema @composeDirective(name: \"@my\")\ntype Query { a: Int }\n"),
        ],
        [
            "[DIRECTIVE_COMPOSITION_ERROR] Could not find matching directive definition for argument to @composeDirective \"@my\" in subgraph \"a\".",
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_composition.rules_field_sets`.

Upstream has no test file for these cases. The expected errors are those of
the subgraph phase of Hive Federation Composition v0.27.0 `validate` in
Node.js on the same subgraphs.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v1_key_list() raises:
    check(
        [
            sg("a", "type Query { a: Int }\ntype T @key(fields: [\"id\", \"name\"]) { id: ID! name: String }\ntype U @key(fields: [\"id\", 1]) { id: ID! }\ntype V @key(fields: 1) { id: ID! }\ntype W @key(fields: []) { id: ID! }\n"),
        ],
        [
            "[KEY_INVALID_FIELDS_TYPE] [a] On type \"U\", for @key(fields: [\"id\", 1]): Invalid value for argument \"fields\": must be a string.",
            "[KEY_INVALID_FIELDS_TYPE] [a] On type \"V\", for @key(fields: 1): Invalid value for argument \"fields\": must be a string.",
            "[KEY_INVALID_FIELDS] [a] On type \"W\", for @key(fields: []): Syntax Error: Expected Name, found \"}\".",
        ],
    )


def test_v2_key_list() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@provides\", \"@requires\", \"@external\", \"@interfaceObject\", \"@shareable\"])\ntype Query { a: Int }\ntype T @key(fields: [\"id\"]) { id: ID! }\n"),
        ],
        [
            "[KEY_INVALID_FIELDS_TYPE] [a] On type \"T\", for @key(fields: [\"id\"]): Invalid value for argument \"fields\": must be a string.",
        ],
    )


def test_key_without_fields() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@provides\", \"@requires\", \"@external\", \"@interfaceObject\", \"@shareable\"])\ntype Query { a: Int }\ntype T @key { id: ID! }\ntype U @key(resolvable: false) { id: ID! }\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Directive \"@key\" argument \"fields\" of type \"FieldSet!\" is required, but it was not provided.",
            "[INVALID_GRAPHQL] [a] Directive \"@key\" argument \"fields\" of type \"FieldSet!\" is required, but it was not provided.",
        ],
    )


def test_interface_key_implementations() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@provides\", \"@requires\", \"@external\", \"@interfaceObject\", \"@shareable\"])\ntype Query { a: Int }\ninterface I @key(fields: \"id\") { id: ID! }\ntype A implements I @key(fields: 1) { id: ID! }\ntype B implements I @key { id: ID! }\ntype C implements I @shareable @key(fields: \"x\") { id: ID! x: Int }\ntype D implements I @key(fields: \"id\") { id: ID! }\ninterface J implements I @key(fields: \"id\") { id: ID! }\n"),
        ],
        [
            "[INTERFACE_KEY_NOT_ON_IMPLEMENTATION] [a] Key @key(fields: \"id\") on interface type \"I\" is missing on implementation type \"A\".",
            "[INTERFACE_KEY_NOT_ON_IMPLEMENTATION] [a] Key @key(fields: \"id\") on interface type \"I\" is missing on implementation type \"B\".",
            "[INTERFACE_KEY_NOT_ON_IMPLEMENTATION] [a] Key @key(fields: \"id\") on interface type \"I\" is missing on implementation type \"C\".",
            "[KEY_INVALID_FIELDS_TYPE] [a] On type \"A\", for @key(fields: 1): Invalid value for argument \"fields\": must be a string.",
            "[INVALID_GRAPHQL] [a] Directive \"@key\" argument \"fields\" of type \"FieldSet!\" is required, but it was not provided.",
        ],
    )


def test_interface_key_v1() raises:
    check(
        [
            sg("a", "type Query { a: Int }\ninterface I @key(fields: \"id\") { id: ID! }\ntype A implements I { id: ID! }\n"),
        ],
        [
        ],
    )


def test_provides_on_extension_keys() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@provides\", \"@requires\", \"@external\", \"@interfaceObject\", \"@shareable\"])\ntype Query { u: User @provides(fields: \"id name\") v: User @provides(fields: \"name\") }\nextend type User @key(fields: 1) @key(fields: \"other\") @key(fields: \"id\") @shareable { id: ID! @external name: String @external other: Int }\n"),
        ],
        [
            "[PROVIDES_FIELDS_MISSING_EXTERNAL] [a] On field \"Query.u\", for @provides(fields: \"id name\"): field \"User.id\" should not be part of a @provides since it is already \"effectively\" provided by this subgraph (while it is marked @external, it is a @key field of an extension type, which are not internally considered external for historical/backward compatibility reasons)",
            "[KEY_INVALID_FIELDS_TYPE] [a] On type \"User\", for @key(fields: 1): Invalid value for argument \"fields\": must be a string.",
        ],
    )


def test_provides_on_extension_bad_key() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@provides\", \"@requires\", \"@external\", \"@interfaceObject\", \"@shareable\"])\ntype Query { u: User @provides(fields: \"name\") }\nextend type User @key(fields: \"id {\") @key(fields: \"id\") { id: ID! @external name: String @external }\n"),
        ],
        [
            "THROWS Syntax Error: Expected Name, found \"}\".",
        ],
    )


def test_provides_v1_extension() raises:
    check(
        [
            sg("a", "type Query { u: User @provides(fields: \"id name\") }\nextend type User @key(fields: \"id\") { id: ID! @external name: String @external }\n"),
        ],
        [
        ],
    )


def test_provides_and_requires_places() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@provides\", \"@requires\", \"@external\", \"@interfaceObject\", \"@shareable\"])\ntype Query { a: Int }\ntype T @provides(fields: \"a\") @requires(fields: \"a\") { a: Int }\nextend schema @provides(fields: \"a\") @requires(fields: \"a\")\ninterface I { a: T @provides(fields: \"a\") b: Int @requires(fields: \"a\") }\n"),
        ],
        [
            "[PROVIDES_UNSUPPORTED_ON_INTERFACE] [a] Cannot use @provides on field \"I.a\" of parent type \"I\": @provides is not yet supported within interfaces",
            "[REQUIRES_UNSUPPORTED_ON_INTERFACE] [a] Cannot use @requires on field \"I.b\" of parent type \"I\": @requires is not yet supported within interfaces",
            "[INVALID_GRAPHQL] [a] Directive \"@provides\" may not be used on SCHEMA.",
            "[INVALID_GRAPHQL] [a] Directive \"@requires\" may not be used on SCHEMA.",
            "[INVALID_GRAPHQL] [a] Directive \"@provides\" may not be used on OBJECT.",
            "[INVALID_GRAPHQL] [a] Directive \"@requires\" may not be used on OBJECT.",
        ],
    )


def test_provides_union() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@provides\", \"@requires\", \"@external\", \"@interfaceObject\", \"@shareable\"])\ntype Query { u: U @provides(fields: \"... on A { x }\") }\nunion U = A | B\ntype A @key(fields: \"id\") { id: ID! x: Int @external }\ntype B { y: Int }\n"),
        ],
        [
        ],
    )


def test_provides_nested_invalid() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@provides\", \"@requires\", \"@external\", \"@interfaceObject\", \"@shareable\"])\ntype Query { u: User @provides(fields: \"friend { missing }\") w: User @provides(fields: \"friend { id(x: 1) }\") }\ntype User @key(fields: \"id\") { id: ID! friend: User @external }\n"),
        ],
        [
            "[PROVIDES_INVALID_FIELDS] [a] On field \"Query.u\", for @provides(fields: \"friend { missing }\"): Cannot query field \"missing\" on type \"User\" (if the field is defined in another subgraph, you need to add it to this subgraph with @external).",
        ],
    )


def test_requires_on_interface_object() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@provides\", \"@requires\", \"@external\", \"@interfaceObject\", \"@shareable\"])\ntype Query { a: Int }\ntype IO @key(fields: \"id\") @interfaceObject { id: ID! x: Int @external y: Int @requires(fields: \"x\") }\n"),
        ],
        [
        ],
    )


def test_requires_nested() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@provides\", \"@requires\", \"@external\", \"@interfaceObject\", \"@shareable\"])\ntype Query { a: Int }\ntype T @key(fields: \"id\") { id: ID! n: N @external y: Int @requires(fields: \"n { a }\") z: Int @requires(fields: \"n { missing }\") }\ntype N { a: Int }\n"),
        ],
        [
            "[REQUIRES_INVALID_FIELDS] [a] On field \"T.z\", for @requires(fields: \"n { missing }\"): Cannot query field \"missing\" on type \"N\" (if the field is defined in another subgraph, you need to add it to this subgraph with @external).",
        ],
    )


def test_requires_v1() raises:
    check(
        [
            sg("a", "type Query { a: Int }\nextend type T @key(fields: \"id\") { id: ID! @external x: Int @external y: Int @requires(fields: \"x\") z: Int @requires(fields: \"missing\") }\n"),
        ],
        [
            "[REQUIRES_INVALID_FIELDS] [a] On field \"T.z\", for @requires(fields: \"missing\"): Cannot query field \"missing\" on type \"T\" (if the field is defined in another subgraph, you need to add it to this subgraph with @external).",
        ],
    )


def test_key_fields_not_string_v2() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@provides\", \"@requires\", \"@external\", \"@interfaceObject\", \"@shareable\"])\ntype Query { a: Int }\ntype T @key(fields: {a: 1}) { id: ID! }\ntype U @key(fields: true) { id: ID! }\n"),
        ],
        [
            "[KEY_INVALID_FIELDS_TYPE] [a] On type \"T\", for @key(fields: {a: 1}): Invalid value for argument \"fields\": must be a string.",
            "[KEY_INVALID_FIELDS_TYPE] [a] On type \"U\", for @key(fields: true): Invalid value for argument \"fields\": must be a string.",
        ],
    )


def test_provides_requires_not_string() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@provides\", \"@requires\", \"@external\", \"@interfaceObject\", \"@shareable\"])\ntype Query { u: User @provides(fields: 1) v: User @provides(fields: [\"id\"]) }\ntype User @key(fields: \"id\") { id: ID! x: Int @requires(fields: 1) y: Int @requires(fields: [\"id\"]) z: Int @requires }\n"),
        ],
        [
            "[PROVIDES_INVALID_FIELDS_TYPE] [a] On field \"Query.u\", for @provides(fields: 1): Invalid value for argument \"fields\": must be a string.",
            "[PROVIDES_INVALID_FIELDS_TYPE] [a] On field \"Query.v\", for @provides(fields: [\"id\"]): Invalid value for argument \"fields\": must be a string.",
            "[REQUIRES_INVALID_FIELDS_TYPE] [a] On field \"User.x\", for @requires(fields: 1): Invalid value for argument \"fields\": must be a string.",
            "[REQUIRES_INVALID_FIELDS_TYPE] [a] On field \"User.y\", for @requires(fields: [\"id\"]): Invalid value for argument \"fields\": must be a string.",
            "[INVALID_GRAPHQL] [a] Directive \"@requires\" argument \"fields\" of type \"FieldSet!\" is required, but it was not provided.",
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

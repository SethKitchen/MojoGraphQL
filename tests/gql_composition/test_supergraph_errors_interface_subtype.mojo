# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Checks for `InterfaceSubtypeRule`.

Hive's published spec reports this code from the subgraph phase. These
checks are the supergraph phase: each subgraph is valid alone, and the
merged field types are not.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_merged_named_types_are_not_subtypes() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  t: T\n}\n\ninterface I {\n '
                    ' f: String\n}\n\ntype T implements I @key(fields: "id")'
                    " {\n  id: ID!\n  f: String!\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ninterface I {\n  f: ID!\n}\n\ntype T'
                    ' implements I @key(fields: "id") {\n  id: ID!\n  f: ID!\n}'
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "T.f" is incompatible'
                ' across subgraphs: it has type "String!" in subgraph "a" but'
                ' type "ID!" in subgraph "b"'
            ),
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "T.f" is resolved'
                ' from multiple subgraphs: it is resolved from subgraphs "a"'
                ' and "b" and defined as non-shareable in all of them'
            ),
            (
                "[INVALID_GRAPHQL] Interface field I.f expects type String but"
                " T.f of type ID! is not a proper subtype."
            ),
        ],
    )


def test_union_member_is_a_subtype() raises:
    check(
        [
            sg(
                "a",
                (
                    "type Query {\n  t: T\n}\n\ninterface I {\n  f:"
                    " U\n}\n\nunion U = A | B\n\ntype A {\n  x: Int\n}\n\ntype"
                    " B {\n  y: Int\n}\n\ntype T implements I {\n  f: A\n}"
                ),
            ),
            sg(
                "b",
                (
                    "interface I {\n  f: U\n}\n\nunion U = A | B\n\ntype A {\n "
                    " x: Int\n}\n\ntype B {\n  y: Int\n}\n\ntype T implements I"
                    " {\n  f: B\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "T.f" is incompatible'
                ' across subgraphs: it has type "A" in subgraph "a" but type'
                ' "B" in subgraph "b"'
            ),
        ],
    )


comptime _HEAD = (
    "extend schema @link(url:"
    ' "https://specs.apollo.dev/federation/v2.3", import: ["@key",'
    ' "@shareable"])\n\n'
)


def test_list_and_named_types_are_not_subtypes() raises:
    # A list is not a subtype of a named type, and the reverse.
    check(
        [
            sg(
                "a",
                String(_HEAD)
                + "type Query {\n  t: T\n}\n\ninterface I {\n  f: [String]\n"
                + "  g: String\n}\n\ntype T implements I @shareable {\n"
                + "  f: [String]!\n  g: String!\n}",
            ),
            sg(
                "b",
                String(_HEAD)
                + "interface I {\n  f: String\n  g: [String]\n}\n\ntype T"
                + " implements I @shareable {\n  f: String\n  g: [String]\n}",
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "T.f" is incompatible'
                ' across subgraphs: it has type "[String]!" in subgraph "a"'
                ' but type "String" in subgraph "b"'
            ),
            (
                "[INVALID_GRAPHQL] Interface field I.f expects type [String]"
                " but T.f of type String is not a proper subtype."
            ),
            (
                '[FIELD_TYPE_MISMATCH] Type of field "T.g" is incompatible'
                ' across subgraphs: it has type "String!" in subgraph "a" but'
                ' type "[String]" in subgraph "b"'
            ),
            (
                "[INVALID_GRAPHQL] Interface field I.g expects type String but"
                " T.g of type [String] is not a proper subtype."
            ),
        ],
    )


def test_object_outside_the_union() raises:
    # Subgraph "a" has no union, and no subgraph lists "C" in it.
    check(
        [
            sg(
                "a",
                String(_HEAD)
                + "type Query {\n  t: T\n}\n\ntype C {\n  z: Int\n}\n\ntype T"
                + " @shareable {\n  f: C\n}",
            ),
            sg(
                "b",
                String(_HEAD)
                + "interface I {\n  f: U\n}\n\nunion U = A | B\n\ntype A {\n"
                + "  x: Int\n}\n\ntype B {\n  y: Int\n}\n\ntype T implements I"
                + " @shareable {\n  f: A\n}",
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "T.f" is incompatible'
                ' across subgraphs: it has type "C" in subgraph "a" but type'
                ' "A" in subgraph "b"'
            ),
            (
                "[INVALID_GRAPHQL] Interface field I.f expects type U but T.f"
                " of type C is not a proper subtype."
            ),
        ],
    )


def test_interface_without_implementers() raises:
    # No type implements "Node", so "X" is not its subtype.
    check(
        [
            sg(
                "a",
                String(_HEAD)
                + "type Query {\n  t: T\n}\n\ntype X {\n  id: ID\n}\n\ntype T"
                + " @shareable {\n  f: X\n}",
            ),
            sg(
                "b",
                String(_HEAD)
                + "interface Node {\n  id: ID\n}\n\ninterface I {\n  f: Node\n"
                + "}\n\ntype T implements I @shareable {\n  f: Node\n}",
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "T.f" is incompatible'
                ' across subgraphs: it has type "X" in subgraph "a" but type'
                ' "Node" in subgraph "b"'
            ),
            (
                "[INVALID_GRAPHQL] Interface field I.f expects type Node but"
                " T.f of type X is not a proper subtype."
            ),
        ],
    )


def test_federation_1_external_fields() raises:
    # In v1.0 an `@external` field is external only under `@extends`.
    check(
        [
            sg(
                "a",
                "type Query {\n  t: T\n}\n\ninterface I {\n  id: ID!\n}\n\n"
                + 'type T implements I @key(fields: "id") {\n  id: ID!\n'
                + "  name: String\n}",
            ),
            sg(
                "b",
                'extend type T @key(fields: "id") {\n  id: ID! @external\n'
                + "  nick: String\n}",
            ),
            sg(
                "c",
                'type T @extends @key(fields: "id") {\n  id: ID! @external\n'
                + "  other: String\n}",
            ),
        ],
        [],
    )


def test_interface_field_types_merge() raises:
    # A nullable copy replaces a non-null interface field type.
    check(
        [
            sg(
                "a",
                String(_HEAD)
                + "type Query {\n  t: T\n}\n\ninterface I {\n  f: String!\n"
                + "  g: String!\n}\n\ntype T implements I @shareable {\n"
                + "  f: String!\n  g: String!\n}",
            ),
            sg(
                "b",
                String(_HEAD)
                + "interface I {\n  f: String\n  g: String!\n}\n\ntype T"
                + " implements I @shareable {\n  f: String\n  g: String!\n}",
            ),
        ],
        [],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

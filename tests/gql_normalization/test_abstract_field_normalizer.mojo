# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of graphql-go-tools v2 `v2/pkg/astnormalization`
`abstract_field_normalizer.go`.

Upstream has no test file for `AbstractFieldNormalizer`. Each expected
output here is the output of upstream `NewAbstractFieldNormalizer(...)
.Normalize()` at the pinned revision, for the field with the alias or the
name of the case.
"""

from _norm import printed, schema_of
from gql_language.ast import Document, Kind, NO_NODE, Role
from gql_language.parser import parse
from gql_language.printer import print_ast
from gql_normalization.abstract_field_normalizer import (
    AbstractFieldNormalizer,
)
from std.testing import TestSuite, assert_equal, assert_true

comptime DEFINITION = """
interface Node { id: ID! }
type User implements Node { id: ID! name: String! friends: [User!]! }
type Admin implements Node { id: ID! role: String! }
union Entity = User | Admin
type Query { node: Node nodes: [Node!]! entity: Entity user: User }
"""
"""The definition of the cases."""


def field_named(document: Document, node: Int, name: StringSlice) -> Int:
    """Return the first field under a node with an alias or a name.

    Args:
        document: The document.
        node: The node to search under.
        name: The alias, or the name of a field without an alias.

    Returns:
        The `Field` node, or `NO_NODE`.
    """
    var child = document.first_child(node)
    while child != NO_NODE:
        if document.kind(child) == Kind.FIELD:
            var alias = document.child(child, Role.ALIAS)
            var label = document.name(child)
            if alias != NO_NODE:
                label = document.text(alias)
            if label == name:
                return child
        var found = field_named(document, child, name)
        if found != NO_NODE:
            return found
        child = document.next_sibling(child)
    return NO_NODE


def run(input: StringSlice, target: StringSlice, output: StringSlice) raises:
    """Normalize one field, and compare the operation.

    Args:
        input: The operation.
        target: The alias or the name of the field.
        output: The expected operation.

    Raises:
        Error: If the output differs.
    """
    var schema = schema_of(DEFINITION)
    var document = parse(input)
    var field = field_named(document, document.root, target)
    AbstractFieldNormalizer(field).normalize(document, schema)
    assert_equal(print_ast(document), printed(output))


def test_merges_and_deduplicates_only_the_target() raises:
    run(
        (
            "query { node { ... on User { name } ... on User { id } id id }"
            " user { ... on User { id } id id } }"
        ),
        "node",
        "{node {... on User {name id} id} user {... on User {id} id id}}",
    )


def test_merges_before_it_inlines() raises:
    run(
        (
            "query { user { ... on User { friends { ... on User { name } name"
            " } } ... on User { friends { id } } } }"
        ),
        "user",
        "{user {friends {name} friends {id}}}",
    )


def test_target_in_a_fragment_definition() raises:
    run(
        (
            "scalar S fragment F on Query { node { ... on Node { id } id } }"
            " query { user { id id } }"
        ),
        "node",
        "scalar S fragment F on Query {node {id}} {user {id id}}",
    )


def test_target_in_an_inline_fragment() raises:
    run(
        (
            "query { user { name } node { id ... on User { friends { ... on"
            " User { id } id } } } }"
        ),
        "friends",
        "{user {name} node {id ... on User {friends {id}}}}",
    )


def test_target_without_selections() raises:
    run("query { user { n: name name } }", "n", "{user {n: name name}}")


def test_no_target() raises:
    run(
        "scalar S query { user { name name } }",
        "none",
        "scalar S {user {name name}}",
    )


def test_union_target() raises:
    run(
        (
            "query { entity { ... on User { id } ... on Admin { id } ... on"
            " User { name } } }"
        ),
        "entity",
        "{entity {... on User {id name} ... on Admin {id}}}",
    )


def test_spread_and_inline_fragment_before_the_target() raises:
    run(
        (
            "query { user { ...F ... on User { id } } node { id id } }"
            " fragment F on User { id }"
        ),
        "node",
        "{user {...F ... on User {id}} node {id}} fragment F on User {id}",
    )


def test_unknown_type_before_the_target() raises:
    var schema = schema_of(DEFINITION)
    var document = parse(
        "query { a: user { ... on Unknown { id } } node { id id } }"
    )
    var field = field_named(document, document.root, "node")
    var message = String()
    try:
        AbstractFieldNormalizer(field).normalize(document, schema)
    except error:
        message = String(error)
    assert_true('Unknown type "Unknown"' in message, message)
    assert_equal(
        print_ast(document),
        printed("{a: user {... on Unknown {id}} node {id id}}"),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the public schema of a supergraph.

The expected SDL is what Hive Federation Composition v0.27.0 `publicSdl`
prints for the same subgraphs.
"""

from gql_composition.compose import compose_subgraphs
from gql_composition.public_schema import public_schema
from gql_composition.validate import Subgraph
from gql_language.parser import parse
from std.testing import TestSuite, assert_equal, assert_true


def _sg(name: String, sdl: String) raises -> Subgraph:
    """Parse a subgraph with no URL."""
    return Subgraph(name, None, parse(sdl))


def test_a_public_schema_omits_join_metadata() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\ntype Query { user: User }\ntype User'
                    ' @key(fields: "id") { id: ID! name: String }\n'
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(result.public_sdl, _ENTITY)


comptime _ENTITY = """type Query {
  user: User
}

type User {
  id: ID!
  name: String
}"""


def test_a_public_schema_omits_inaccessible_elements() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@inaccessible", "@tag"])\ntype Query { user:'
                    " User secret: String @inaccessible }\ntype User"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String'
                    ' @tag(name: "public")\n  hidden: String'
                    " @inaccessible\n}\ntype Internal @inaccessible { id: ID!"
                    " }\ninterface Secret @inaccessible { id: ID! }\ntype Book"
                    " implements Secret { id: ID! title: String }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(result.public_sdl, _INACCESSIBLE)


comptime _INACCESSIBLE = """type Query {
  user: User
}

type User {
  id: ID!
  name: String
}

type Book {
  id: ID!
  title: String
}"""


def test_a_public_schema_keeps_composed_directives_and_deprecated() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@cost", "@composeDirective"])\nextend schema'
                    ' @link(url: "https://example.com/foo/v1.0", import:'
                    ' ["@foo"]) @composeDirective(name: "@foo")\ndirective'
                    " @foo(n: Int) on FIELD_DEFINITION\ninput Filter @oneOf {"
                    " a: String b: Int }\nenum Color { RED @deprecated(reason:"
                    ' "old") GREEN }\nscalar Date @specifiedBy(url:'
                    ' "https://example.com/date")\ntype Query {\n  user(kind:'
                    ' String @deprecated(reason: "old")): User @foo(n: 1)'
                    ' @cost(weight: 2)\n}\ntype User @key(fields: "id") { id:'
                    " ID! }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(result.public_sdl, _MARKS)


comptime _MARKS = """directive @foo(n: Int) on FIELD_DEFINITION

directive @oneOf on INPUT_OBJECT

scalar Date @specifiedBy(url: "https://example.com/date")

type Query {
  user(kind: String @deprecated(reason: "old")): User @foo(n: 1)
}

type User {
  id: ID!
}

enum Color {
  RED @deprecated(reason: "old")
  GREEN
}

input Filter @oneOf {
  a: String
  b: Int
}"""


def test_a_public_schema_reads_link_names_and_imports() raises:
    # Upstream: `transformSupergraphToPublicSchema` on the same document.
    var result = public_schema(_LINKED)
    assert_equal(result, _LINKED_PUBLIC)


comptime _LINKED = '''schema
  @link(url: "https://specs.apollo.dev/link/v1.0")
  @link(url: "https://specs.apollo.dev/join/v0.3", for: EXECUTION)
  @link(url: "https://specs.apollo.dev/inaccessible/v0.2", as: "hidden", for: SECURITY)
  @link(url: "https://specs.apollo.dev/foo/v1.0", import: ["@bar", "Baz", {name: "Qux", as: "Quux"}])
  @link(url: "https://example.com/other/v1.0", import: ["@other"])
  @link(url: 1)
  @custom
{
  query: Query
}

directive @hidden on FIELD_DEFINITION | OBJECT | INTERFACE
directive @foo__thing on FIELD_DEFINITION
directive @bar on FIELD_DEFINITION
directive @other on FIELD_DEFINITION
directive @custom on SCHEMA
directive @skip(if: Boolean!) on FIELD
extend schema @custom
scalar Baz
enum Quux { A }
interface Open { id: ID }
"""
A block description
"""
input Qux {
  a: Int = 1
  b: Float = 1.5
  c: Level = HIGH
  d: Boolean = true
  e: Boolean = false
}
enum Level { HIGH }
scalar _FieldSet
type Query {
  a: Int @foo__thing @bar @other @hidden
  b: Int @hidden
  foo__c: Int
  d: Baz
}
extend type Query @hidden { e: Int @hidden f: Int }
extend scalar Baz @hidden
extend enum Quux @hidden
'''

comptime _LINKED_PUBLIC = '''directive @other on FIELD_DEFINITION

directive @custom on SCHEMA

interface Open {
  id: ID
}

"""A block description"""
input Qux {
  a: Int = 1
  b: Float = 1.5
  c: Level = HIGH
  d: Boolean = true
  e: Boolean = false
}

enum Level {
  HIGH
}

type Query {
  d: Baz
}

extend type Query {
  f: Int
}

extend scalar Baz

extend enum Quux'''


def test_errors_have_no_public_schema() raises:
    var result = compose_subgraphs([_sg("users", "type User { id: ID }")])
    assert_true(len(result.errors) > 0)
    assert_equal(result.public_sdl, "")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the tag filter and the unreachable-type pass of contracts.

Modeled on Hive Federation Composition v0.27.0
`__tests__/contracts/compose-schema-contract.spec.ts`,
`__tests__/contracts/federation-tag-extraction.spec.ts`, and
`__tests__/contracts/reachable-type-filter.spec.ts`. The expected SDL is
what Hive `composeSchemaContract` prints for the same subgraphs.
"""

from gql_composition.contract import compose_contract
from gql_composition.validate import Subgraph
from gql_language.parser import parse
from std.testing import TestSuite, assert_equal, assert_raises, assert_true


def _sg(name: String, sdl: String) raises -> Subgraph:
    """Parse a subgraph with no URL."""
    return Subgraph(name, None, parse(sdl))


def _link(imports: String) -> String:
    """Return a federation v2.9 `@link` with these imports."""
    return (
        'extend schema @link(url: "https://specs.apollo.dev/federation/v2.9",'
        " import: ["
        + imports
        + "])\n"
    )


def _tags(name: String) -> List[String]:
    """Return a filter with one tag."""
    var tags = List[String]()
    tags.append(name)
    return tags^


def _from_graphs(sdl: String) -> String:
    """Return the supergraph from `enum join__Graph` onward."""
    var at = sdl.find("enum join__Graph")
    return String(sdl[byte=at:])


comptime _KEY_TAG = '"@key", "@tag", "@inaccessible"'


def test_input_and_interface_fields_are_filtered() raises:
    var result = compose_contract(
        [
            _sg(
                "shop",
                _link(_KEY_TAG)
                + "type Query { products(filter: Filter): [Product] node:"
                " Node }\n"
                + "interface Node { id: ID! }\n"
                + "extend interface Node { secret: String @tag(name:"
                ' "internal")'
                " }\n"
                + 'type Product implements Node @key(fields: "id") { id: ID!'
                ' secret: String @tag(name: "internal") price: Int }\n'
                + "input Filter { name: String hidden: String @tag(name:"
                ' "internal") }\n'
                + 'extend input Filter { more: String @tag(name: "internal")'
                " }\n",
            )
        ],
        List[String](),
        _tags("internal"),
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _INPUT_SUPERGRAPH)
    assert_equal(result.public_sdl, _INPUT_PUBLIC)


comptime _INPUT_SUPERGRAPH = """enum join__Graph {
  SHOP @join__graph(name: "shop", url: "")
}

type Query @join__type(graph: SHOP) {
  products(filter: Filter): [Product]
  node: Node
}

type Product implements Node @join__type(graph: SHOP, key: "id") @join__implements(graph: SHOP, interface: "Node") {
  id: ID!
  secret: String @inaccessible
  price: Int
}

interface Node @join__type(graph: SHOP) {
  id: ID!
  secret: String @inaccessible
}

input Filter @join__type(graph: SHOP) {
  name: String
  hidden: String @inaccessible
  more: String @inaccessible
}"""


comptime _INPUT_PUBLIC = """type Query {
  products(filter: Filter): [Product]
  node: Node
}

type Product implements Node {
  id: ID!
  price: Int
}

interface Node {
  id: ID!
}

input Filter {
  name: String
}"""


def test_excluded_types_and_enums() raises:
    var result = compose_contract(
        [
            _sg(
                "shop",
                _link(_KEY_TAG)
                + 'type Query { a: String b: Secret @tag(name: "internal") c:'
                ' Color @tag(name: "internal") d: String @inaccessible'
                ' @tag(name: "internal") e: Mood @tag(name: "internal") f:'
                " Size }\n"
                + 'extend type Secret @tag(name: "internal")\n'
                + "type Secret { x: String }\n"
                + 'enum Color @tag(name: "internal") @inaccessible { RED }\n'
                + 'enum Mood @tag(name: "internal") { HAPPY }\n'
                + "enum Size { S }\n"
                + 'extend enum Size { M @tag(name: "internal") }\n',
            )
        ],
        List[String](),
        _tags("internal"),
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _TYPES_SUPERGRAPH)
    assert_equal(result.public_sdl, _TYPES_PUBLIC)


comptime _TYPES_SUPERGRAPH = """enum join__Graph {
  SHOP @join__graph(name: "shop", url: "")
}

type Query @join__type(graph: SHOP) {
  a: String
  b: Secret @inaccessible
  c: Color @inaccessible
  d: String @inaccessible
  e: Mood @inaccessible
  f: Size
}

type Secret @join__type(graph: SHOP) @inaccessible {
  x: String @inaccessible
}

enum Color @join__type(graph: SHOP) @inaccessible {
  RED @join__enumValue(graph: SHOP) @inaccessible
}

enum Mood @join__type(graph: SHOP) @inaccessible {
  HAPPY @join__enumValue(graph: SHOP) @inaccessible
}

enum Size @join__type(graph: SHOP) {
  S @join__enumValue(graph: SHOP)
  M @join__enumValue(graph: SHOP) @inaccessible
}"""


comptime _TYPES_PUBLIC = """type Query {
  a: String
  f: Size
}

enum Size {
  S
}"""


def test_include_hides_enums_and_inputs() raises:
    var result = compose_contract(
        [
            _sg(
                "shop",
                _link(_KEY_TAG)
                + 'type Query { a: String @tag(name: "public") b(size: Size):'
                ' String @tag(name: "public") c(f: F): String @tag(name:'
                ' "public") }\n'
                + "enum Size { S M }\n"
                + "input F { x: String }\n",
            )
        ],
        _tags("public"),
        List[String](),
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _INCLUDE_SUPERGRAPH)
    assert_equal(result.public_sdl, _INCLUDE_PUBLIC)


comptime _INCLUDE_SUPERGRAPH = """enum join__Graph {
  SHOP @join__graph(name: "shop", url: "")
}

type Query @join__type(graph: SHOP) {
  a: String
  b(size: Size @inaccessible): String
  c(f: F @inaccessible): String
}

enum Size @join__type(graph: SHOP) @inaccessible {
  S @join__enumValue(graph: SHOP) @inaccessible
  M @join__enumValue(graph: SHOP) @inaccessible
}

input F @join__type(graph: SHOP) @inaccessible {
  x: String @inaccessible
}"""


comptime _INCLUDE_PUBLIC = """type Query {
  a: String
  b: String
  c: String
}"""


comptime _SHAREABLE = '"@shareable", "@tag", "@inaccessible"'


def test_a_type_with_a_field_in_another_subgraph_stays() raises:
    var result = compose_contract(
        [
            _sg(
                "a",
                _link(_SHAREABLE)
                + "type Query { info: Info @shareable }\n"
                + 'type Info @shareable { a: String @tag(name: "internal") }\n',
            ),
            _sg(
                "b",
                _link(_SHAREABLE)
                + "type Query { info: Info @shareable }\n"
                + "type Info @shareable { a: String b: String }\n",
            ),
        ],
        List[String](),
        _tags("internal"),
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _STAYS_SUPERGRAPH)
    assert_equal(result.public_sdl, _STAYS_PUBLIC)


comptime _STAYS_SUPERGRAPH = """enum join__Graph {
  A @join__graph(name: "a", url: "")
  B @join__graph(name: "b", url: "")
}

type Query @join__type(graph: A) @join__type(graph: B) {
  info: Info
}

type Info @join__type(graph: A) @join__type(graph: B) {
  a: String @inaccessible
  b: String @join__field(graph: B)
}"""


comptime _STAYS_PUBLIC = """type Query {
  info: Info
}

type Info {
  b: String
}"""


def test_a_type_hidden_in_every_subgraph_is_marked() raises:
    var result = compose_contract(
        [
            _sg(
                "a",
                _link(_SHAREABLE)
                + 'type Query { info: Info @shareable @tag(name: "internal") b:'
                " String }\n"
                + 'type Info @shareable { a: String @tag(name: "internal") }\n',
            ),
            _sg(
                "b",
                _link(_SHAREABLE)
                + "type Query { info: Info @shareable c: String }\n"
                + "type Info @shareable { a: String }\n",
            ),
        ],
        List[String](),
        _tags("internal"),
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _EVERY_SUPERGRAPH)
    assert_equal(result.public_sdl, _EVERY_PUBLIC)


comptime _EVERY_SUPERGRAPH = """enum join__Graph {
  A @join__graph(name: "a", url: "")
  B @join__graph(name: "b", url: "")
}

type Query @join__type(graph: A) @join__type(graph: B) {
  info: Info @inaccessible
  b: String @join__field(graph: A)
  c: String @join__field(graph: B)
}

type Info @join__type(graph: A) @join__type(graph: B) @inaccessible {
  a: String @inaccessible
}"""


comptime _EVERY_PUBLIC = """type Query {
  b: String
  c: String
}"""


def test_custom_root_names() raises:
    var result = compose_contract(
        [
            _sg(
                "shop",
                'schema @link(url: "https://specs.apollo.dev/federation/v2.9",'
                ' import: ["@tag", "@inaccessible"]) { query: RootQuery'
                " mutation: RootMutation }\n"
                + 'type RootQuery { a: String @tag(name: "internal") b: String'
                " }\n"
                + 'type RootMutation { m: String @tag(name: "internal") n:'
                " String }\n",
            )
        ],
        List[String](),
        _tags("internal"),
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _ROOT_SUPERGRAPH)
    assert_equal(result.public_sdl, _ROOT_PUBLIC)


comptime _ROOT_SUPERGRAPH = """enum join__Graph {
  SHOP @join__graph(name: "shop", url: "")
}

type Query @join__type(graph: SHOP) {
  a: String @inaccessible
  b: String
}

type Mutation @join__type(graph: SHOP) {
  m: String @inaccessible
  n: String
}"""


comptime _ROOT_PUBLIC = """type Query {
  b: String
}

type Mutation {
  n: String
}"""


def test_an_external_field_is_not_filtered() raises:
    var result = compose_contract(
        [
            _sg(
                "a",
                _link(_KEY_TAG)
                + "type Query { user: User }\n"
                + 'type User @key(fields: "id") { id: ID! name: String'
                ' @tag(name: "internal") }\n',
            ),
            _sg(
                "b",
                _link(_KEY_TAG + ', "@external", "@requires"')
                + "type Query { users: [User] }\n"
                + 'type User @key(fields: "id") { id: ID! name: String'
                ' @external note: String @requires(fields: "name") }\n',
            ),
        ],
        List[String](),
        _tags("internal"),
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _EXTERNAL_SUPERGRAPH)
    assert_equal(result.public_sdl, _EXTERNAL_PUBLIC)


comptime _EXTERNAL_SUPERGRAPH = """enum join__Graph {
  A @join__graph(name: "a", url: "")
  B @join__graph(name: "b", url: "")
}

type Query @join__type(graph: A) @join__type(graph: B) {
  user: User @join__field(graph: A)
  users: [User] @join__field(graph: B)
}

type User @join__type(graph: A, key: "id") @join__type(graph: B, key: "id") {
  id: ID!
  name: String @join__field(graph: A) @join__field(graph: B, external: true) @inaccessible
  note: String @join__field(graph: B, requires: "name")
}"""


comptime _EXTERNAL_PUBLIC = """type Query {
  user: User
  users: [User]
}

type User {
  id: ID!
  note: String
}"""


def test_the_arguments_of_an_external_field_are_filtered() raises:
    var result = compose_contract(
        [
            _sg(
                "a",
                _link(_KEY_TAG)
                + "type Query { product: Product }\n"
                + 'type Product @key(fields: "id") { id: ID! price(currency:'
                ' String @tag(name: "internal")): Int }\n',
            ),
            _sg(
                "b",
                _link(_KEY_TAG + ', "@external", "@requires"')
                + 'type Product @key(fields: "id") { id: ID! price(currency:'
                ' String @tag(name: "internal")): Int @external total: Int'
                ' @requires(fields: "price") }\n',
            ),
        ],
        List[String](),
        _tags("internal"),
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _ARGUMENT_SUPERGRAPH)
    assert_equal(result.public_sdl, _ARGUMENT_PUBLIC)


comptime _ARGUMENT_SUPERGRAPH = """enum join__Graph {
  A @join__graph(name: "a", url: "")
  B @join__graph(name: "b", url: "")
}

type Query @join__type(graph: A) @join__type(graph: B) {
  product: Product @join__field(graph: A)
}

type Product @join__type(graph: A, key: "id") @join__type(graph: B, key: "id") {
  id: ID!
  price(currency: String @inaccessible): Int @join__field(graph: A) @join__field(graph: B, external: true)
  total: Int @join__field(graph: B, requires: "price")
}"""


comptime _ARGUMENT_PUBLIC = """type Query {
  product: Product
}

type Product {
  id: ID!
  price: Int
  total: Int
}"""


def test_a_tag_without_a_string_name_adds_no_tag() raises:
    var result = compose_contract(
        [
            _sg(
                "shop",
                _link('"@tag", "@inaccessible"')
                + 'type Query { a: String @tag(label: "internal") b: String'
                ' @tag(name: 1) c: String @tag(name: "internal") }\n',
            )
        ],
        List[String](),
        _tags("internal"),
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _NAMELESS_SUPERGRAPH)
    assert_equal(result.public_sdl, "type Query {\n  a: String\n  b: String\n}")


comptime _NAMELESS_SUPERGRAPH = """enum join__Graph {
  SHOP @join__graph(name: "shop", url: "")
}

type Query @join__type(graph: SHOP) {
  a: String
  b: String
  c: String @inaccessible
}"""


def test_a_tag_without_arguments_raises() raises:
    # Upstream throws a TypeError for the same subgraph.
    with assert_raises(contains="@tag has no name argument"):
        _ = compose_contract(
            [
                _sg(
                    "shop",
                    _link('"@tag", "@inaccessible"')
                    + "type Query { a: String @tag b: String }\n",
                )
            ],
            List[String](),
            _tags("internal"),
        )


def test_a_directive_argument_type_is_reachable() raises:
    var result = compose_contract(
        [
            _sg(
                "shop",
                'extend schema @link(url: "https://specs.apollo.dev/federation'
                '/v2.9", import: ["@composeDirective", "@tag",'
                ' "@inaccessible"]) @link(url:'
                ' "https://specs.example.com/custom/v1.0", import:'
                ' ["@custom"]) @composeDirective(name: "@custom")\n'
                + "directive @custom(level: Level) on FIELD_DEFINITION\n"
                + "enum Level { LOW HIGH }\n"
                + "type Query { a: String @custom(level: LOW) b: String"
                ' @tag(name: "internal") }\n',
            )
        ],
        List[String](),
        _tags("internal"),
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _DIRECTIVE_SUPERGRAPH)
    assert_equal(result.public_sdl, _DIRECTIVE_PUBLIC)


comptime _DIRECTIVE_SUPERGRAPH = """enum join__Graph {
  SHOP @join__graph(name: "shop", url: "")
}

directive @custom(level: Level) on FIELD_DEFINITION

type Query @join__type(graph: SHOP) {
  a: String @custom(level: LOW)
  b: String @inaccessible
}

enum Level @join__type(graph: SHOP) {
  LOW @join__enumValue(graph: SHOP)
  HIGH @join__enumValue(graph: SHOP)
}"""


comptime _DIRECTIVE_PUBLIC = """directive @custom(level: Level) on FIELD_DEFINITION

type Query {
  a: String @custom(level: LOW)
}

enum Level {
  LOW
  HIGH
}"""


def test_policy_and_scope_scalars_are_marked() raises:
    var result = compose_contract(
        [
            _sg(
                "a",
                _link('"@policy", "@requiresScopes", "@tag", "@inaccessible"')
                + 'type Query { a: String @policy(policies: [["p"]]) b: String'
                ' @requiresScopes(scopes: [["s"]]) c: String @tag(name:'
                ' "internal") }\n',
            )
        ],
        List[String](),
        _tags("internal"),
    )
    assert_equal(len(result.errors), 0)
    var sdl = result.supergraph_sdl
    assert_true(sdl.find("\nscalar policy__Policy @inaccessible\n") != -1)
    assert_true(
        sdl.find("\nscalar requiresScopes__Scope @inaccessible\n") != -1
    )
    assert_true(sdl.find("\nscalar join__FieldSet\n") != -1)
    assert_true(sdl.find("\nscalar link__Import\n") != -1)
    assert_equal(result.public_sdl, "type Query {\n  a: String\n  b: String\n}")


def test_unreachable_types_of_every_kind() raises:
    var result = compose_contract(
        [
            Subgraph(
                "shop",
                String("http://shop.example.com"),
                parse(
                    _link(_KEY_TAG)
                    + "type Query { search: [Result] node: Node hidden: Orphan"
                    ' @tag(name: "internal") }\n'
                    + "union Result = User | Post\n"
                    + "interface Node { id: ID! }\n"
                    + "interface Entity { id: ID! }\n"
                    + "type User implements Node & Entity @key(fields:"
                    ' "id") { id: ID! }\n'
                    + "type Post { title: String }\n"
                    + "type Orphan { e(arg: OrphanInput): Mood s: Date i:"
                    " Thing u: Either }\n"
                    + "enum Mood { HAPPY }\n"
                    + "scalar Date\n"
                    + "interface Thing { x: Int }\n"
                    + "union Either = Post\n"
                    + "input OrphanInput { x: Int }\n"
                ),
            )
        ],
        List[String](),
        _tags("internal"),
    )
    assert_equal(len(result.errors), 0)
    assert_equal(result.supergraph_sdl, _KINDS_SUPERGRAPH)
    assert_equal(result.public_sdl, _KINDS_PUBLIC)


comptime _KINDS_SUPERGRAPH = '''schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url: "https://specs.apollo.dev/join/v0.5", for: EXECUTION) @link(url: "https://specs.apollo.dev/inaccessible/v0.2", for: SECURITY) {
  query: Query
}

directive @join__enumValue(graph: join__Graph!) repeatable on ENUM_VALUE

directive @join__graph(name: String!, url: String!) on ENUM_VALUE

directive @join__field(
  graph: join__Graph
  requires: join__FieldSet
  provides: join__FieldSet
  type: String
  external: Boolean
  override: String
  usedOverridden: Boolean
  overrideLabel: String
  contextArguments: [join__ContextArgument!]
) repeatable on FIELD_DEFINITION | INPUT_FIELD_DEFINITION

input join__ContextArgument {
  name: String!
  type: String!
  context: String!
  selection: join__FieldValue!
}

directive @join__implements(graph: join__Graph!, interface: String!) repeatable on OBJECT | INTERFACE

directive @join__type(
  graph: join__Graph!
  key: join__FieldSet
  extension: Boolean! = false
  resolvable: Boolean! = true
  isInterfaceObject: Boolean! = false
) repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT | SCALAR

directive @join__unionMember(graph: join__Graph!, member: String!) repeatable on UNION

scalar join__FieldSet

scalar join__FieldValue

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

scalar link__Import

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY
  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

directive @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION

enum join__Graph {
  SHOP @join__graph(name: "shop", url: "http://shop.example.com")
}

scalar Date @join__type(graph: SHOP) @inaccessible

type Query @join__type(graph: SHOP) {
  search: [Result]
  node: Node
  hidden: Orphan @inaccessible
}

type User implements Node & Entity @join__type(graph: SHOP, key: "id") @join__implements(graph: SHOP, interface: "Node") @join__implements(graph: SHOP, interface: "Entity") {
  id: ID!
}

type Post @join__type(graph: SHOP) {
  title: String
}

type Orphan @join__type(graph: SHOP) @inaccessible {
  e(arg: OrphanInput): Mood
  s: Date
  i: Thing
  u: Either
}

interface Node @join__type(graph: SHOP) {
  id: ID!
}

interface Entity @join__type(graph: SHOP) {
  id: ID!
}

interface Thing @join__type(graph: SHOP) @inaccessible {
  x: Int
}

union Result @join__type(graph: SHOP) @join__unionMember(graph: SHOP, member: "User") @join__unionMember(graph: SHOP, member: "Post") = User | Post

union Either @join__type(graph: SHOP) @join__unionMember(graph: SHOP, member: "Post") @inaccessible = Post

enum Mood @join__type(graph: SHOP) @inaccessible {
  HAPPY @join__enumValue(graph: SHOP)
}

input OrphanInput @join__type(graph: SHOP) @inaccessible {
  x: Int
}'''


comptime _KINDS_PUBLIC = """type Query {
  search: [Result]
  node: Node
}

type User implements Node & Entity {
  id: ID!
}

type Post {
  title: String
}

interface Node {
  id: ID!
}

interface Entity {
  id: ID!
}

union Result = User | Post"""


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

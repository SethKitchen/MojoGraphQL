# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `build_subgraph_schema`, ported from `@apollo/subgraph`
2.14.4 `src/__tests__/buildSubgraphSchema.test.ts`: the `buildSubgraphSchema`
cases about the schema and `_service`. The `_entities` cases are in
`test_entities.mojo`, and the `@tag` and backward compatibility cases are
in `test_federation_versions.mojo`.

Upstream cases that are not ported:

- `do not break if the schema definition AST uses undefined for
  directives`: a Mojo document has no `undefined` properties.
- `correctly attaches the provided subscribe function to the schema
  object`: `gql_execution` has no `subscribe`.
"""

from std.testing import TestSuite, assert_equal
from _helpers import (
    assert_service_sdl,
    build_error,
    run,
    sdl_document,
    subgraph,
    type_sdl,
)
from gql_execution.execute import ResolveInfo
from gql_execution.value import Values
from gql_language.ast import Document
from gql_schema.definition import NO_TYPE
from gql_subgraph.build_subgraph_schema import (
    SubgraphResolvers,
    build_subgraph_schema,
)

comptime FED1_DIRECTIVES = """directive @key(fields: _FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE

directive @requires(fields: _FieldSet!) on FIELD_DEFINITION

directive @provides(fields: _FieldSet!) on FIELD_DEFINITION

directive @external(reason: String) on OBJECT | FIELD_DEFINITION

directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION

directive @extends on OBJECT | INTERFACE"""

comptime FED1_TYPES = """scalar _FieldSet

scalar _Any

type _Service {
  sdl: String
}"""

comptime ENTITY_QUERY = """type Query {
  _entities(representations: [_Any!]!): [_Entity]!
  _service: _Service!
}"""


def test_marks_a_type_with_a_key_field_as_an_entity() raises:
    var schema = subgraph(
        'type Product @key(fields: "upc") { upc: String! name: String price:'
        " Int }"
    )
    assert_equal(
        type_sdl(schema, "Product"),
        "type Product {\n  upc: String!\n  name: String\n  price: Int\n}",
    )
    assert_equal(type_sdl(schema, "_Entity"), "union _Entity = Product")


def test_marks_a_type_with_multiple_key_fields_as_an_entity() raises:
    var schema = subgraph(
        'type Product @key(fields: "upc") @key(fields: "sku") { upc: String!'
        " sku: String! name: String price: Int }"
    )
    assert_equal(
        type_sdl(schema, "Product"),
        "type Product {\n  upc: String!\n  sku: String!\n  name: String\n"
        "  price: Int\n}",
    )
    assert_equal(type_sdl(schema, "_Entity"), "union _Entity = Product")


def test_does_not_mark_a_type_without_a_key_field_as_an_entity() raises:
    var schema = subgraph("type Money { amount: Int! currencyCode: String! }")
    assert_equal(
        type_sdl(schema, "Money"),
        "type Money {\n  amount: Int!\n  currencyCode: String!\n}",
    )
    assert_equal(schema.schema.type_named("_Entity"), NO_TYPE)


def test_preserves_description_text_in_generated_sdl() raises:
    var schema = subgraph(
        '''"Description text on 'SchemaDefinition' nodes supported as per the October 2021 Edition of the spec."
schema {
  query: Query
}

"A user. This user is very complicated and requires so so so so so so so so so so so so so so so so so so so so so so so so so so so so so so so so much description text"
type User @key(fields: "id") {
  """
  The unique ID of the user.
  """
  id: ID!
  "The user's name."
  name: String
  username: String
  foo(
    "Description 1"
    arg1: String
    "Description 2"
    arg2: String
    "Description 3 Description 3 Description 3 Description 3 Description 3 Description 3 Description 3 Description 3 Description 3 Description 3 Description 3"
    arg3: String
  ): String
}

extend type Query {
  _dummyField: Boolean
}'''
    )
    assert_service_sdl(
        schema,
        '''"""
Description text on 'SchemaDefinition' nodes supported as per the October 2021 Edition of the spec.
"""
schema {
  query: Query
}

'''
        + FED1_DIRECTIVES
        + '''

"""
A user. This user is very complicated and requires so so so so so so so so so so so so so so so so so so so so so so so so so so so so so so so so much description text
"""
type User
  @key(fields: "id")
{
  """The unique ID of the user."""
  id: ID!

  """The user's name."""
  name: String
  username: String
  foo(
    """Description 1"""
    arg1: String

    """Description 2"""
    arg2: String

    """
    Description 3 Description 3 Description 3 Description 3 Description 3 Description 3 Description 3 Description 3 Description 3 Description 3 Description 3
    """
    arg3: String
  ): String
}

'''
        + ENTITY_QUERY
        + """

extend type Query {
  _dummyField: Boolean
}

"""
        + FED1_TYPES
        + "\n\nunion _Entity = User",
    )


def test_adds_entities_to_a_query_root_with_the_default_name() raises:
    var schema = subgraph(
        'type Query { rootField: String } type Product @key(fields: "upc") {'
        " upc: ID! }"
    )
    assert_equal(
        type_sdl(schema, "Query"),
        "type Query {\n  rootField: String\n  _entities(representations:"
        " [_Any!]!): [_Entity]!\n  _service: _Service!\n}",
    )


def test_adds_entities_to_a_query_root_with_another_name() raises:
    var schema = subgraph(
        "schema { query: QueryRoot } type QueryRoot { rootField: String } type"
        ' Product @key(fields: "upc") { upc: ID! }'
    )
    assert_equal(
        type_sdl(schema, "QueryRoot"),
        "type QueryRoot {\n  rootField: String\n  _entities(representations:"
        " [_Any!]!): [_Entity]!\n  _service: _Service!\n}",
    )


def test_does_not_add_entities_when_no_query_root_type_is_defined() raises:
    var schema = build_subgraph_schema(Document())
    assert_equal(
        type_sdl(schema, "Query"), "type Query {\n  _service: _Service!\n}"
    )


def test_does_not_add_entities_when_no_types_with_keys_are_found() raises:
    var schema = subgraph("type Query { rootField: String }")
    assert_equal(
        type_sdl(schema, "Query"),
        "type Query {\n  rootField: String\n  _service: _Service!\n}",
    )


def test_does_not_add_entities_when_only_an_interface_has_keys() raises:
    var schema = subgraph(
        'type Query { rootField: String } interface Product @key(fields: "upc")'
        " { upc: ID! }"
    )
    assert_equal(
        type_sdl(schema, "Query"),
        "type Query {\n  rootField: String\n  _service: _Service!\n}",
    )


def test_keeps_extension_types_when_owner_type_is_not_present() raises:
    var schema = subgraph(
        "type Review { id: ID } extend type Review { title: String } extend"
        ' type Product @key(fields: "upc") { upc: String @external reviews:'
        " [Review] }"
    )
    assert_service_sdl(
        schema,
        FED1_DIRECTIVES
        + """

type Review {
  id: ID
}

extend type Review {
  title: String
}

extend type Product
  @key(fields: "upc")
{
  upc: String @external
  reviews: [Review]
}

"""
        + FED1_TYPES
        + "\n\nunion _Entity = Product\n\n"
        + ENTITY_QUERY,
    )


def test_keeps_extension_interface_when_owner_interface_is_not_present() raises:
    var schema = subgraph(
        "type Review { id: ID } extend type Review { title: String } interface"
        ' Node @key(fields: "id") { id: ID! } extend interface Product'
        ' @key(fields: "upc") { upc: String @external reviews: [Review] }'
    )
    assert_service_sdl(
        schema,
        FED1_DIRECTIVES
        + """

type Review {
  id: ID
}

extend type Review {
  title: String
}

interface Node
  @key(fields: "id")
{
  id: ID!
}

extend interface Product
  @key(fields: "upc")
{
  upc: String @external
  reviews: [Review]
}

"""
        + FED1_TYPES
        + "\n\ntype Query {\n  _service: _Service!\n}",
    )


def test_returns_valid_sdl_for_key_directives() raises:
    var schema = subgraph(
        'type Product @key(fields: "upc") { upc: String! name: String price:'
        " Int }"
    )
    assert_service_sdl(
        schema,
        FED1_DIRECTIVES
        + """

type Product
  @key(fields: "upc")
{
  upc: String!
  name: String
  price: Int
}

"""
        + FED1_TYPES
        + "\n\nunion _Entity = Product\n\n"
        + ENTITY_QUERY,
    )


def test_returns_valid_sdl_for_multiple_key_directives() raises:
    var schema = subgraph(
        'type Product @key(fields: "upc") @key(fields: "name") { upc: String!'
        " name: String price: Int }"
    )
    assert_service_sdl(
        schema,
        FED1_DIRECTIVES
        + """

type Product
  @key(fields: "upc")
  @key(fields: "name")
{
  upc: String!
  name: String
  price: Int
}

"""
        + FED1_TYPES
        + "\n\nunion _Entity = Product\n\n"
        + ENTITY_QUERY,
    )


def test_supports_all_federation_directives() raises:
    var schema = subgraph(
        """type Review @key(fields: "id") {
  id: ID!
  body: String
  author: User @provides(fields: "email")
  product: Product @provides(fields: "upc")
}
extend type User @key(fields: "email") {
  email: String @external
  reviews: [Review]
}
extend type Product @key(fields: "upc") {
  upc: String @external
  reviews: [Review]
}"""
    )
    assert_service_sdl(
        schema,
        FED1_DIRECTIVES
        + """

type Review
  @key(fields: "id")
{
  id: ID!
  body: String
  author: User @provides(fields: "email")
  product: Product @provides(fields: "upc")
}

extend type User
  @key(fields: "email")
{
  email: String @external
  reviews: [Review]
}

extend type Product
  @key(fields: "upc")
{
  upc: String @external
  reviews: [Review]
}

"""
        + FED1_TYPES
        + "\n\nunion _Entity = Product | Review | User\n\n"
        + ENTITY_QUERY,
    )


def test_keeps_custom_directives() raises:
    var schema = subgraph(
        'directive @custom on FIELD extend type User @key(fields: "email") {'
        " email: String @external }"
    )
    assert_service_sdl(
        schema,
        "directive @custom on FIELD\n\n"
        + FED1_DIRECTIVES
        + """

extend type User
  @key(fields: "email")
{
  email: String @external
}

"""
        + FED1_TYPES
        + "\n\nunion _Entity = User\n\n"
        + ENTITY_QUERY,
    )


def test_fails_on_bad_linking() raises:
    assert_equal(
        build_error(
            """extend schema
  @link(url: "https://specs.apollo.dev/link/v1.0")
  @link(
    url: "https://specs.apollo.dev/federation/v2.0"
    import: [{ name: "@key", as: "@primaryKey" }]
  )
type Query { t: T }
type T @key(fields: "id") { id: ID! }"""
        ),
        "The schema is not a valid GraphQL schema.. Caused by:\nUnknown"
        ' directive "@key". If you meant the "@key" federation directive, you'
        ' should use "@primaryKey" as it is imported under that name in the'
        " @link to the federation specification of this schema.",
    )


# --- legacy interface ---------------------------------------------------

comptime LEGACY_FIRST = """type Query {
  product: Product
}
type Product @key(fields: "upc") {
  upc: String!
  name: String
}"""

comptime LEGACY_SECOND = "extend type Product { price: Int }"

comptime LEGACY_SINGLE = """type Query {
  product: Product
}
type Product @key(fields: "upc") {
  upc: String!
  name: String
  price: Int
}"""


def _product(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.add_object()


def _upc(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.add_string("1234")


def _price(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.add_number(10)


def _legacy_resolvers() -> SubgraphResolvers:
    var resolvers = SubgraphResolvers()
    resolvers.field("Query", "product", _product)
    resolvers.field("Product", "upc", _upc)
    resolvers.field("Product", "price", _price)
    return resolvers^


def _legacy_documents() raises -> List[Document]:
    var documents = List[Document]()
    documents.append(sdl_document(LEGACY_FIRST))
    documents.append(sdl_document(LEGACY_SECOND))
    return documents^


def test_legacy_array_of_type_defs_and_resolvers() raises:
    var schema = build_subgraph_schema(_legacy_documents(), _legacy_resolvers())
    assert_equal(type_sdl(schema, "_Entity"), "union _Entity = Product")
    assert_equal(
        run(schema, "{ product { price upc } }"),
        '{"data":{"product":{"price":10,"upc":"1234"}}}',
    )


def test_legacy_single_module() raises:
    var documents = List[Document]()
    documents.append(sdl_document(LEGACY_SINGLE))
    var schema = build_subgraph_schema(documents^, _legacy_resolvers())
    assert_equal(type_sdl(schema, "_Entity"), "union _Entity = Product")
    assert_equal(
        run(schema, "{ product { price upc } }"),
        '{"data":{"product":{"price":10,"upc":"1234"}}}',
    )


def test_legacy_single_module_without_resolvers() raises:
    var schema = subgraph(LEGACY_SINGLE)
    assert_equal(
        type_sdl(schema, "Product"),
        "type Product {\n  upc: String!\n  name: String\n  price: Int\n}",
    )
    assert_equal(type_sdl(schema, "_Entity"), "union _Entity = Product")


def test_defines_the_resolve_type_resolver_on_the_entity_union() raises:
    var schema = build_subgraph_schema(
        _legacy_documents(), SubgraphResolvers()
    )
    ref resolvers = schema.resolvers.resolvers
    assert_equal(resolvers.type_names[len(resolvers.type_names) - 1], "_Entity")


def test_legacy_simple_array_of_documents() raises:
    var schema = build_subgraph_schema(
        _legacy_documents(), SubgraphResolvers()
    )
    assert_equal(
        type_sdl(schema, "Product"),
        "type Product {\n  upc: String!\n  name: String\n  price: Int\n}",
    )
    assert_equal(type_sdl(schema, "_Entity"), "union _Entity = Product")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

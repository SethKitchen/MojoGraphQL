# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the consumer schema.

Ports of the tests of Hive Router `1a29df9`
`bin/router/src/query_planner/consumer_schema/mod.rs`,
`prune_inacessible.rs` and `strip_schema_internals.rs`, and of the insta
snapshot
`snapshots/hive_router__query_planner__consumer_schema__strip_schema_internals__test__strip_schema_internals.snap`.
The snapshot is upstream `Display` text; graphql-js `print` writes the
same text without the last newline.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_language.parser import parse
from gql_language.printer import print_ast
from gql_router.consumer_schema import (
    ConsumerSchema,
    PruneInaccessible,
    StripSchemaInternals,
)
from gql_router.schema_metadata import schema_metadata
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)


def _count(document: Document, kind: Kind, name: StringSlice) -> Int:
    """Count the definitions of a kind and a name."""
    var total = 0
    for definition in document.definitions():
        if (
            document.kind(definition) == kind
            and document.name(definition) == name
        ):
            total += 1
    return total


def _find(document: Document, kind: Kind, name: StringSlice) -> Int:
    """Return the first definition of a kind and a name."""
    for definition in document.definitions():
        if (
            document.kind(definition) == kind
            and document.name(definition) == name
        ):
            return definition
    return NO_NODE


def _field_names(document: Document, node: Int) -> String:
    """Join the names of the fields of a definition with spaces."""
    var out = String()
    for field in document.children(node, Role.FIELD):
        if out.byte_length() > 0:
            out += " "
        out += document.name(field)
    return out^


def test_does_not_duplicate_built_in_directives_defined_in_supergraph() raises:
    var supergraph = parse(
        """
        schema
          @link(url: "https://specs.apollo.dev/link/v1.0")
          @link(url: "https://specs.apollo.dev/join/v0.3", for: EXECUTION) {
          query: Query
        }

        directive @oneOf on INPUT_OBJECT
        directive @deprecated(
          reason: String = "No longer supported"
        ) on FIELD_DEFINITION | ARGUMENT_DEFINITION | INPUT_FIELD_DEFINITION | ENUM_VALUE

        input Filter @oneOf {
          id: ID
          name: String
        }

        type Query {
          search(filter: Filter!, old: String @deprecated): String
        }
        """
    )
    var consumer = ConsumerSchema.new_from_supergraph(supergraph)
    for name in ["oneOf", "deprecated", "skip", "include", "specifiedBy"]:
        assert_equal(
            _count(consumer.document, Kind.DIRECTIVE_DEFINITION, name), 1
        )


def test_prune_preserves_root_type_names() raises:
    var schema = parse(
        """
        type Query { hello: String }
        type Mutation { doThing: String }
        type Subscription { onThing: String }
        """
    )
    var metadata = schema_metadata(PruneInaccessible.prune(schema))
    assert_equal(metadata.query_type_name, "Query")
    assert_equal(metadata.mutation_type_name, "Mutation")
    assert_equal(metadata.subscription_type_name, "Subscription")


def test_prune_preserves_renamed_root_type_names() raises:
    var schema = parse(
        """
        schema {
          query: RootQuery
          mutation: RootMutation
          subscription: RootSubscription
        }

        type RootQuery { hello: String }
        type RootMutation { doThing: String }
        type RootSubscription { onThing: String }
        """
    )
    var metadata = schema_metadata(PruneInaccessible.prune(schema))
    assert_equal(metadata.query_type_name, "RootQuery")
    assert_equal(metadata.mutation_type_name, "RootMutation")
    assert_equal(metadata.subscription_type_name, "RootSubscription")


def test_prune_removes_inaccessible_parts() raises:
    var schema = parse(
        """
        directive @d(keep: Int, hide: Int @inaccessible) on FIELD_DEFINITION
        type Query {
          a(keep: Int, hide: Int @inaccessible): String
          b: Hidden @inaccessible
          c: Color
        }
        type Hidden @inaccessible { x: Int }
        interface I @inaccessible { x: Int }
        union U @inaccessible = Hidden
        scalar S @inaccessible
        enum Gone @inaccessible { A }
        input Gone2 @inaccessible { x: Int }
        enum Color { RED BLUE @inaccessible }
        input Filter { keep: Int hide: Int @inaccessible }
        interface Node { id: ID secret: ID @inaccessible }
        """
    )
    var pruned = PruneInaccessible.prune(schema)
    var text = print_ast(pruned)
    assert_equal(
        text,
        (
            "directive @d(keep: Int) on FIELD_DEFINITION\n\n"
            "type Query {\n  a(keep: Int): String\n  c: Color\n}\n\n"
            "enum Color {\n  RED\n}\n\n"
            "input Filter {\n  keep: Int\n}\n\n"
            "interface Node {\n  id: ID\n}"
        ),
    )
    var query = _find(schema, Kind.OBJECT_TYPE_DEFINITION, "Query")
    var hidden = _find(schema, Kind.OBJECT_TYPE_DEFINITION, "Hidden")
    assert_false(PruneInaccessible.has_inaccessible_directive(schema, query))
    assert_true(PruneInaccessible.has_inaccessible_directive(schema, hidden))


def test_prune_keeps_type_extensions_and_strip_refuses_them() raises:
    var schema = parse("type Query { a: Int }\nextend type Query { b: Int }")
    var pruned = PruneInaccessible.prune(schema)
    assert_equal(len(pruned.definitions()), 2)
    with assert_raises(contains="TypeExtension not implemented"):
        _ = StripSchemaInternals.strip_schema_internals(pruned)
    with assert_raises(contains="TypeExtension not implemented"):
        _ = ConsumerSchema.new_from_supergraph(schema)


def _strip_input() -> String:
    """Return the schema of upstream `test_strip_schema_internals`."""
    return String(
        """
schema
  @link(url: "https://specs.apollo.dev/link/v1.0")
  @link(url: "https://specs.apollo.dev/join/v0.3", for: EXECUTION)
  @link(url: "https://specs.apollo.dev/tag/v0.3")
  @link(url: "https://specs.apollo.dev/inaccessible/v0.2", for: SECURITY)
  @link(
    url: "https://myspecs.dev/myDirective/v1.0"
    import: ["@myDirective", { name: "@anotherDirective", as: "@hello" }]
  ) {
  query: Query
}

directive @join__enumValue(graph: join__Graph!) repeatable on ENUM_VALUE

directive @join__field(
  graph: join__Graph
  requires: join__FieldSet
  provides: join__FieldSet
  type: String
  external: Boolean
  override: String
  usedOverridden: Boolean
) repeatable on FIELD_DEFINITION | INPUT_FIELD_DEFINITION

directive @join__graph(name: String!, url: String!) on ENUM_VALUE

directive @join__implements(
  graph: join__Graph!
  interface: String!
) repeatable on OBJECT | INTERFACE

directive @join__type(
  graph: join__Graph!
  key: join__FieldSet
  extension: Boolean! = false
  resolvable: Boolean! = true
  isInterfaceObject: Boolean! = false
) repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT | SCALAR

directive @join__unionMember(
  graph: join__Graph!
  member: String!
) repeatable on UNION

directive @join__directive(graphs: [join__Graph!], name: String!, args: join__DirectiveArguments) repeatable on SCHEMA | OBJECT | INTERFACE | FIELD_DEFINITION

scalar join__DirectiveArguments

scalar join__FieldSet

directive @link(
  url: String
  as: String
  for: link__Purpose
  import: [link__Import]
) repeatable on SCHEMA

scalar link__Import

enum link__Purpose {
  \"\"\"
  `SECURITY` features provide metadata necessary to securely resolve fields.
  \"\"\"
  SECURITY

  \"\"\"
  `EXECUTION` features provide metadata necessary for operation execution.
  \"\"\"
  EXECUTION
}

directive @tag(
  name: String!
) repeatable on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION | SCHEMA

directive @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION

directive @authenticated on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

scalar requiresScopes__Scope
directive @requiresScopes(
  scopes: [[requiresScopes__Scope!]!]!
) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

enum join__Graph {
  INVENTORY @join__graph(name: "inventory", url: "")
  PANDAS @join__graph(name: "pandas", url: "")
  PRODUCTS @join__graph(name: "products", url: "")
  REVIEWS @join__graph(name: "reviews", url: "")
  USERS @join__graph(name: "users", url: "")
}

directive @myDirective(a: String!) on FIELD_DEFINITION

directive @hello on FIELD_DEFINITION

type Product implements ProductItf & SkuItf
  @join__type(graph: INVENTORY, key: "id")
  @join__type(graph: PRODUCTS, key: "id")
  @join__type(graph: PRODUCTS, key: "sku package")
  @join__type(graph: PRODUCTS, key: "sku variation { id }")
  @join__type(graph: REVIEWS, key: "id")
  @join__implements(graph: INVENTORY, interface: "ProductItf")
  @join__implements(graph: PRODUCTS, interface: "ProductItf")
  @join__implements(graph: PRODUCTS, interface: "SkuItf")
  @join__implements(graph: REVIEWS, interface: "ProductItf") {
  id: ID! @tag(name: "hi-from-products")
  dimensions: ProductDimension
    @join__field(graph: INVENTORY, external: true)
    @join__field(graph: PRODUCTS)
  delivery(zip: String): DeliveryEstimates
    @join__field(
      graph: INVENTORY
      requires: "dimensions{...on ProductDimension{size weight}}"
    )
  sku: String @join__field(graph: PRODUCTS)
  package: String @join__field(graph: PRODUCTS)
  variation: ProductVariation @join__field(graph: PRODUCTS)
  name: String @hello @join__field(graph: PRODUCTS)
  createdBy: User @join__field(graph: PRODUCTS)
  hidden: String @join__field(graph: PRODUCTS) @requiresScopes(scopes: ["read", "admin"])
  reviewsScore: Float! @join__field(graph: REVIEWS, override: "products")
  oldField: String @join__field(graph: PRODUCTS)
  reviewsCount: Int! @join__field(graph: REVIEWS)
  reviews: [Review!]! @join__field(graph: REVIEWS)
}

type ProductDimension
  @join__type(graph: INVENTORY)
  @join__type(graph: PRODUCTS) {
  size: String
  weight: Float
}

type DeliveryEstimates @join__type(graph: INVENTORY) {
  estimatedDelivery: String
  fastestDelivery: String
}

type Query
  @join__type(graph: INVENTORY)
  @join__type(graph: PANDAS)
  @join__type(graph: PRODUCTS)
  @join__type(graph: REVIEWS)
  @join__type(graph: USERS) {
  allPandas: [Panda] @join__field(graph: PANDAS) @authenticated
  panda(name: ID!): Panda @join__field(graph: PANDAS)
  allProducts: [ProductItf] @join__field(graph: PRODUCTS)
  product(id: ID!): ProductItf @join__field(graph: PRODUCTS)
  review(id: Int!): Review @join__field(graph: REVIEWS)
}

type Mutation
  @join__type(graph: REVIEWS)
{
  newRandomReview: Review
}

type Panda @join__type(graph: PANDAS) {
  name: ID!
  favoriteFood: String @tag(name: "nom-nom-nom")
}

type ProductVariation @join__type(graph: PRODUCTS) {
  id: ID!
  name: String
}

type User
  @join__type(graph: PRODUCTS, key: "email")
  @join__type(graph: USERS, key: "email") {
  email: ID! @tag(name: "test-from-users")
  totalProductsCreated: Int
  name: String @join__field(graph: USERS)
}

type Review @join__type(graph: REVIEWS) {
  id: Int!
  body: String!
}

interface ProductItf implements SkuItf
  @join__type(graph: INVENTORY)
  @join__type(graph: PRODUCTS)
  @join__type(graph: REVIEWS)
  @join__implements(graph: PRODUCTS, interface: "SkuItf") {
  id: ID!
  dimensions: ProductDimension
    @join__field(graph: INVENTORY)
    @join__field(graph: PRODUCTS)
  delivery(zip: String): DeliveryEstimates @join__field(graph: INVENTORY)
  sku: String @join__field(graph: PRODUCTS)
  name: String @join__field(graph: PRODUCTS)
  package: String @join__field(graph: PRODUCTS)
  variation: ProductVariation @join__field(graph: PRODUCTS)
  createdBy: User @join__field(graph: PRODUCTS)
  hidden: String @join__field(graph: PRODUCTS) @inaccessible
  oldField: String
    @join__field(graph: PRODUCTS)
    @deprecated(reason: "refactored out")
  reviewsCount: Int! @join__field(graph: REVIEWS)
  reviewsScore: Float! @join__field(graph: REVIEWS)
  reviews: [Review!]! @join__field(graph: REVIEWS)
}

interface SkuItf @join__type(graph: PRODUCTS) {
  sku: String
}

enum ShippingClass @join__type(graph: INVENTORY) @join__type(graph: PRODUCTS) {
  STANDARD @join__enumValue(graph: INVENTORY) @join__enumValue(graph: PRODUCTS)
  EXPRESS @join__enumValue(graph: INVENTORY) @join__enumValue(graph: PRODUCTS)
  OVERNIGHT @join__enumValue(graph: INVENTORY)
}
"""
    )


def test_strip_schema_internals() raises:
    var schema = parse(_strip_input())
    var stripped = StripSchemaInternals.strip_schema_internals(schema)
    var text = print_ast(stripped)
    var expected = String(
        "schema {\n  query: Query\n}\n\ndirective @myDirective(a: String!) on"
        " FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype"
        " Product implements ProductItf & SkuItf {\n  id: ID!\n  dimensions:"
        " ProductDimension\n  delivery(zip: String): DeliveryEstimates\n "
        " sku: String\n  package: String\n  variation: ProductVariation\n "
        " name: String @hello\n  createdBy: User\n  hidden: String\n "
        " reviewsScore: Float!\n  oldField: String\n  reviewsCount: Int!\n "
        " reviews: [Review!]!\n}\n\ntype ProductDimension {\n  size:"
        " String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n "
        " estimatedDelivery: String\n  fastestDelivery: String\n}\n\ntype"
        " Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n "
        " allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n "
        " review(id: Int!): Review\n}\n\ntype Mutation {\n  newRandomReview:"
        " Review\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood:"
        " String\n}\n\ntype ProductVariation {\n  id: ID!\n  name:"
        " String\n}\n\ntype User {\n  email: ID!\n  totalProductsCreated:"
        " Int\n  name: String\n}\n\ntype Review {\n  id: Int!\n  body:"
        " String!\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n "
        " dimensions: ProductDimension\n  delivery(zip: String):"
        " DeliveryEstimates\n  sku: String\n  name: String\n  package:"
        " String\n  variation: ProductVariation\n  createdBy: User\n "
        ' hidden: String\n  oldField: String @deprecated(reason: "refactored'
        ' out")\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews:'
        " [Review!]!\n}\n\ninterface SkuItf {\n  sku: String\n}\n\nenum"
        " ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}\n"
    )
    assert_equal(text + "\n", expected)
    # Upstream parses the result again.
    _ = parse(text)


def test_consumer_schema_extends_the_query_type() raises:
    var consumer = ConsumerSchema.new_from_supergraph(parse(_strip_input()))
    var query = _find(consumer.document, Kind.OBJECT_TYPE_DEFINITION, "Query")
    assert_equal(
        _field_names(consumer.document, query),
        "allPandas panda allProducts product review __schema __type",
    )
    assert_equal(
        _count(consumer.document, Kind.OBJECT_TYPE_DEFINITION, "Query"), 1
    )
    assert_equal(
        _count(consumer.document, Kind.OBJECT_TYPE_DEFINITION, "__Type"), 1
    )
    assert_equal(
        _count(consumer.document, Kind.SCALAR_TYPE_DEFINITION, "String"), 1
    )
    assert_equal(
        _count(consumer.document, Kind.ENUM_TYPE_DEFINITION, "__TypeKind"), 1
    )
    assert_equal(
        _count(consumer.document, Kind.DIRECTIVE_DEFINITION, "skip"), 1
    )
    assert_equal(
        _count(consumer.document, Kind.DIRECTIVE_DEFINITION, "join__type"), 0
    )
    assert_equal(consumer.sdl, print_ast(consumer.document))
    assert_true("__schema: __Schema!" in consumer.sdl)
    # The printed schema parses again.
    _ = parse(consumer.sdl)


def test_consumer_schema_extends_a_renamed_query_type() raises:
    var consumer = ConsumerSchema.new_from_supergraph(
        parse("schema { query: Root }\ntype Root { a: Int }")
    )
    var root = _find(consumer.document, Kind.OBJECT_TYPE_DEFINITION, "Root")
    assert_equal(_field_names(consumer.document, root), "a __schema __type")
    assert_equal(
        _count(consumer.document, Kind.OBJECT_TYPE_DEFINITION, "Query"), 0
    )


def test_consumer_schema_adds_query_when_the_root_type_is_missing() raises:
    # The schema names a query type that it does not define, so upstream
    # adds the `Query` type of the introspection schema.
    var consumer = ConsumerSchema.new_from_supergraph(
        parse("schema { mutation: M query: Root }\ntype M { a: Int }")
    )
    var query = _find(consumer.document, Kind.OBJECT_TYPE_DEFINITION, "Query")
    assert_equal(_field_names(consumer.document, query), "__schema __type")


def test_consumer_schema_finds_the_default_query_type() raises:
    # The schema definition has a directive and no query type, so the
    # query type is the type named `Query`.
    var consumer = ConsumerSchema.new_from_supergraph(
        parse(
            "schema @custom { mutation: M }\ndirective @custom on SCHEMA\n"
            "type M { a: Int }\ntype Query { b: Int }"
        )
    )
    var query = _find(consumer.document, Kind.OBJECT_TYPE_DEFINITION, "Query")
    assert_equal(_field_names(consumer.document, query), "b __schema __type")
    assert_equal(
        _count(consumer.document, Kind.OBJECT_TYPE_DEFINITION, "Query"), 1
    )


def test_consumer_schema_needs_a_query_type() raises:
    var no_query = parse("type M { a: Int }")
    with assert_raises(contains="Query type not found in schema"):
        _ = ConsumerSchema.new_from_supergraph(no_query)
    var mutation_only = parse("schema { mutation: M }\ntype M { a: Int }")
    with assert_raises(contains="Query type not found in schema"):
        _ = ConsumerSchema.new_from_supergraph(mutation_only)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

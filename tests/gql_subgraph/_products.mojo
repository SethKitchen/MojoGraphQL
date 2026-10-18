# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The `products` subgraph of the Apollo Federation subgraph compatibility
suite (f9520a4, MIT): the SDL of `implementations/apollo-server/
products.graphql`, with the data and the resolvers of
`implementations/apollo-server/index.js`.

`tests/gql_subgraph/test_compatibility.mojo` tests it, and
`bench/compat/products.mojo` serves it on port 4001.
"""

from gql_execution.execute import ResolveInfo
from gql_execution.value import ValueKind, Values
from gql_language.parser import parse
from gql_subgraph.build_subgraph_schema import (
    SchemaModule,
    SubgraphResolvers,
    SubgraphSchema,
    build_subgraph_schema,
)

comptime PRODUCTS_SDL = """extend schema
  @link(
    url: "https://specs.apollo.dev/federation/v2.3",
    import: ["@composeDirective", "@extends", "@external", "@key", "@inaccessible", "@interfaceObject", "@override", "@provides", "@requires", "@shareable", "@tag"]
  )
  @link(url: "https://myspecs.dev/myCustomDirective/v1.0", import: ["@custom"])
  @composeDirective(name: "@custom")

directive @custom on OBJECT

type Product @custom @key(fields: "id") @key(fields: "sku package") @key(fields: "sku variation { id }") {
  id: ID!
  sku: String
  package: String
  variation: ProductVariation
  dimensions: ProductDimension
  createdBy: User @provides(fields: "totalProductsCreated")
  notes: String @tag(name: "internal")
  research: [ProductResearch!]!
}

type DeprecatedProduct @key(fields: "sku package") {
  sku: String!
  package: String!
  reason: String
  createdBy: User
}

type ProductVariation {
  id: ID!
}

type ProductResearch @key(fields: "study { caseNumber }") {
  study: CaseStudy!
  outcome: String
}

type CaseStudy {
  caseNumber: ID!
  description: String
}

type ProductDimension @shareable {
  size: String
  weight: Float
  unit: String @inaccessible
}

extend type Query {
  product(id: ID!): Product
  deprecatedProduct(sku: String!, package: String!): DeprecatedProduct @deprecated(reason: "Use product query instead")
}

extend type User @key(fields: "email") {
  averageProductsCreatedPerYear: Int @requires(fields: "totalProductsCreated yearsOfEmployment")
  email: ID! @external
  name: String @override(from: "users")
  totalProductsCreated: Int @external
  yearsOfEmployment: Int! @external
}

type Inventory @interfaceObject @key(fields: "id") {
  id: ID!
  deprecatedProducts: [DeprecatedProduct!]!
}
"""
"""The SDL of the `products` subgraph, as the suite gives it."""

comptime EMAIL = "support@apollographql.com"
"""The email of the one user."""

# The products of index.js: id, sku, package and variation.
comptime _PRODUCTS: Array[StaticString, 8] = [
    "apollo-federation",
    "federation",
    "@apollo/federation",
    "OSS",
    "apollo-studio",
    "studio",
    "",
    "platform",
]


def _field(index: Int) -> StaticString:
    """Return entry `index` of `_PRODUCTS`."""
    return materialize[_PRODUCTS]()[index]


def _truthy(values: Values, value: Int) -> Bool:
    """Return True for a JavaScript truthy value."""
    var kind = values.kind(value)
    if kind == ValueKind.UNDEFINED or kind == ValueKind.NULL:
        return False
    if kind == ValueKind.BOOLEAN:
        return values.bool_value(value)
    if kind == ValueKind.NUMBER:
        var number = values.number(value)
        return number == number and number != 0
    if kind == ValueKind.STRING:
        return values.string(value).byte_length() > 0
    return True


def _equals(values: Values, value: Int, text: StringSlice) -> Bool:
    """Return True when a value is the string `text`, as JavaScript `==`."""
    return (
        values.kind(value) == ValueKind.STRING and values.string(value) == text
    )


def _member(mut values: Values, object: Int, key: String, text: StringSlice):
    """Add a string member to an object."""
    values.add_member(object, key, values.add_string(text))


def _product(mut values: Values, index: Int) -> Int:
    """Make product `index` of index.js."""
    var product = values.add_object()
    _member(values, product, "id", _field(index * 4))
    _member(values, product, "sku", _field(index * 4 + 1))
    _member(values, product, "package", _field(index * 4 + 2))
    _member(values, product, "variation", _field(index * 4 + 3))
    return product


def _find_product(
    values: Values, key: Int, value: Int, second_key: Int, second: Int
) -> Int:
    """Return the index of the first product whose field `key` is `value`
    and, when `second_key` is not -1, whose field `second_key` is
    `second`, as `products.find`; -1 when none is."""
    var index = 0
    while index < 2:
        if _equals(values, value, _field(index * 4 + key)) and (
            second_key < 0
            or _equals(values, second, _field(index * 4 + second_key))
        ):
            return index
        index += 1
    return -1


def _product_or_null(mut values: Values, index: Int) -> Int:
    """Make a found product, or `null` when none was found."""
    if index < 0:
        return values.add_null()
    return _product(values, index)


def _user(mut values: Values) -> Int:
    """Make the user of index.js."""
    var user = values.add_object()
    _member(values, user, "email", EMAIL)
    _member(values, user, "name", "Jane Smith")
    values.add_member(user, "totalProductsCreated", values.add_number(1337))
    return user


def _deprecated_product(mut values: Values) -> Int:
    """Make the deprecated product of index.js."""
    var product = values.add_object()
    _member(values, product, "sku", "apollo-federation-v1")
    _member(values, product, "package", "@apollo/federation-v1")
    _member(values, product, "reason", "Migrate to Federation V2")
    return product


def _is_deprecated_product(values: Values, object: Int) -> Bool:
    """Return True when `sku` and `package` name the deprecated product."""
    return _equals(
        values, values.get(object, "sku"), "apollo-federation-v1"
    ) and _equals(
        values, values.get(object, "package"), "@apollo/federation-v1"
    )


def _research(mut values: Values, index: Int) -> Int:
    """Make product research `index` of index.js."""
    var study = values.add_object()
    _member(values, study, "caseNumber", "1234" if index == 0 else "1235")
    _member(
        values,
        study,
        "description",
        "Federation Study" if index == 0 else "Studio Study",
    )
    var research = values.add_object()
    values.add_member(research, "study", study)
    return research


def _query_product(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`Query.product`: the product with the `id`."""
    return _product_or_null(
        values, _find_product(values, 0, values.get(args, "id"), -1, 0)
    )


def _query_deprecated_product(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`Query.deprecatedProduct`: the deprecated product, or `null`."""
    if _is_deprecated_product(values, args):
        return _deprecated_product(values)
    return values.add_null()


def _created_by(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`Product.createdBy` and `DeprecatedProduct.createdBy`: the user."""
    return _user(values)


def _deprecated_product_reference(
    mut values: Values, reference: Int, context: Int, info: ResolveInfo
) raises -> Int:
    """`DeprecatedProduct.__resolveReference`."""
    if _is_deprecated_product(values, reference):
        return _deprecated_product(values)
    return values.add_null()


def _variation(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`Product.variation`: `{ id }` of the variation of the product."""
    var variation = values.add_object()
    var own = values.get(source, "variation")
    if _truthy(values, own):
        values.add_member(variation, "id", values.copy(own))
        return variation
    var found = _find_product(values, 0, values.get(source, "id"), -1, 0)
    if found >= 0:
        _member(values, variation, "id", _field(found * 4 + 3))
    return variation


def _dimensions(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`Product.dimensions`: the one dimension."""
    var dimension = values.add_object()
    _member(values, dimension, "size", "small")
    values.add_member(dimension, "weight", values.add_number(1))
    _member(values, dimension, "unit", "kg")
    return dimension


def _product_research(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`Product.research`: the research of the product, by its id."""
    var out = values.add_list()
    var id = values.get(source, "id")
    if _equals(values, id, "apollo-federation"):
        values.append(out, _research(values, 0))
    elif _equals(values, id, "apollo-studio"):
        values.append(out, _research(values, 1))
    return out


def _product_reference(
    mut values: Values, reference: Int, context: Int, info: ResolveInfo
) raises -> Int:
    """`Product.__resolveReference`: by `id`, by `sku package`, or by
    `sku variation { id }`."""
    var id = values.get(reference, "id")
    if _truthy(values, id):
        return _product_or_null(values, _find_product(values, 0, id, -1, 0))
    var sku = values.get(reference, "sku")
    var package = values.get(reference, "package")
    if _truthy(values, sku) and _truthy(values, package):
        return _product_or_null(
            values, _find_product(values, 1, sku, 2, package)
        )
    var variation = values.get(values.get(reference, "variation"), "id")
    return _product_or_null(values, _find_product(values, 1, sku, 3, variation))


def _research_reference(
    mut values: Values, reference: Int, context: Int, info: ResolveInfo
) raises -> Int:
    """`ProductResearch.__resolveReference`: by `study.caseNumber`."""
    var case_number = values.get(values.get(reference, "study"), "caseNumber")
    if _equals(values, case_number, "1234"):
        return _research(values, 0)
    if _equals(values, case_number, "1235"):
        return _research(values, 1)
    return values.add_null()


def _average_products_created_per_year(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`User.averageProductsCreatedPerYear`: `Math.round` of the products
    per year; NaN when a number is missing, as in JavaScript."""
    if not _equals(values, values.get(source, "email"), EMAIL):
        raise Error("user.email was not 'support@apollographql.com'")
    var total = values.get(source, "totalProductsCreated")
    var years = values.get(source, "yearsOfEmployment")
    var nan = Float64(0) / Float64(0)
    if (
        values.kind(total) != ValueKind.NUMBER
        or values.kind(years) != ValueKind.NUMBER
    ):
        return values.add_number(nan)
    var quotient = values.number(total) / values.number(years)
    return values.add_number(Float64(Int(quotient + 0.5)))


def _user_reference(
    mut values: Values, reference: Int, context: Int, info: ResolveInfo
) raises -> Int:
    """`User.__resolveReference`: the user, with the fields that the
    representation gives."""
    var email = values.get(reference, "email")
    if not _truthy(values, email):
        return values.add_null()
    var user = values.add_object()
    values.add_member(user, "email", values.copy(email))
    _member(values, user, "name", "Jane Smith")
    var total = values.get(reference, "totalProductsCreated")
    if _truthy(values, total):
        values.add_member(user, "totalProductsCreated", values.copy(total))
    else:
        values.add_member(user, "totalProductsCreated", values.add_number(1337))
    var years = values.get(reference, "yearsOfEmployment")
    if _truthy(values, years):
        values.add_member(user, "yearsOfEmployment", values.copy(years))
    return user


def _inventory_reference(
    mut values: Values, reference: Int, context: Int, info: ResolveInfo
) raises -> Int:
    """`Inventory.__resolveReference`: the `apollo-oss` inventory."""
    if not _equals(values, values.get(reference, "id"), "apollo-oss"):
        return values.add_null()
    var inventory = values.add_object()
    _member(values, inventory, "id", "apollo-oss")
    var products = values.add_list()
    values.append(products, _deprecated_product(values))
    values.add_member(inventory, "deprecatedProducts", products)
    return inventory


def products_resolvers() -> SubgraphResolvers:
    """Return the resolvers of index.js.

    Returns:
        The resolver map.
    """
    var resolvers = SubgraphResolvers()
    resolvers.field("Query", "product", _query_product)
    resolvers.field("Query", "deprecatedProduct", _query_deprecated_product)
    resolvers.field("DeprecatedProduct", "createdBy", _created_by)
    resolvers.resolve_reference(
        "DeprecatedProduct", _deprecated_product_reference
    )
    resolvers.field("Product", "variation", _variation)
    resolvers.field("Product", "dimensions", _dimensions)
    resolvers.field("Product", "research", _product_research)
    resolvers.field("Product", "createdBy", _created_by)
    resolvers.resolve_reference("Product", _product_reference)
    resolvers.resolve_reference("ProductResearch", _research_reference)
    resolvers.field(
        "User",
        "averageProductsCreatedPerYear",
        _average_products_created_per_year,
    )
    resolvers.resolve_reference("User", _user_reference)
    resolvers.resolve_reference("Inventory", _inventory_reference)
    return resolvers^


def build_products() raises -> SubgraphSchema:
    """Build the `products` subgraph, as
    `buildSubgraphSchema([{ typeDefs, resolvers }])` in index.js.

    Returns:
        The subgraph schema.

    Raises:
        Error: As `build_subgraph_schema` raises.
    """
    var modules = List[SchemaModule]()
    modules.append(SchemaModule(parse(PRODUCTS_SDL), products_resolvers()))
    return build_subgraph_schema(modules^)

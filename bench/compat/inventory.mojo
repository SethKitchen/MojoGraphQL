# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The `inventory` subgraph of the Apollo Federation subgraph compatibility
suite (f9520a4, MIT), served over HTTP: the Mojo counterpart of
`packages/subgraphs/inventory/index.js`, with the SDL of
`inventory.graphql`.

The port is 4003, or the value of `INVENTORY_PORT`. Run it from the
repository root:

    .venv/bin/mojo run -I . bench/compat/inventory.mojo
"""

from _serve import serve_subgraph
from gql_execution.execute import ResolveInfo
from gql_execution.value import ValueKind, Values
from gql_language.parser import parse
from gql_subgraph.build_subgraph_schema import (
    SchemaModule,
    SubgraphResolvers,
    SubgraphSchema,
    build_subgraph_schema,
)

comptime INVENTORY_SDL = """extend schema
  @link(
    url: "https://specs.apollo.dev/federation/v2.3"
    import: [
      "@key"
      "@requires"
      "@shareable"
      "@provides"
      "@external"
      "@tag"
    ]
  )

extend type Product @key(fields: "id") {
  id: ID! @external
  dimensions: ProductDimension @external
  delivery(zip: String): DeliveryEstimates
    @requires(fields: "dimensions { size weight }")
}

type ProductDimension @shareable {
  size: String
  weight: Float
}

type DeliveryEstimates {
  estimatedDelivery: String
  fastestDelivery: String
}

interface Inventory @key(fields: "id") {
  id: ID!
  products: [Product!]!
}

type OpenSourceInventory implements Inventory @key(fields: "id") {
  id: ID!
  products: [Product!]!
}

type Query {
  inventory(id: ID!): Inventory
}
"""
"""The SDL of `inventory.graphql`."""

comptime INVENTORY_ID = "apollo-oss"
"""The id of the one inventory."""


def _is_string(values: Values, value: Int, text: StringSlice) -> Bool:
    """Return True when a value is the string `text`, as JavaScript `==`."""
    return (
        values.kind(value) == ValueKind.STRING and values.string(value) == text
    )


def _query_inventory(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`Query.inventory`: the inventory with the `id`, as `inventory.find`."""
    if not _is_string(values, values.get(args, "id"), INVENTORY_ID):
        return values.add_null()
    var product = values.add_object()
    values.add_member(product, "id", values.add_string("apollo-federation"))
    var products = values.add_list()
    values.append(products, product)
    var inventory = values.add_object()
    values.add_member(inventory, "id", values.add_string(INVENTORY_ID))
    values.add_member(inventory, "products", products)
    return inventory


def _delivery(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`Product.delivery`: check the `@requires` fields and the argument,
    then return the delivery estimate."""
    if not _is_string(values, values.get(source, "id"), "apollo-federation"):
        raise Error("product.id was not 'apollo-federation'")
    var dimensions = values.get(source, "dimensions")
    if not _is_string(values, values.get(dimensions, "size"), "small"):
        raise Error("product.dimensions.size was not 'small'")
    var weight = values.get(dimensions, "weight")
    if values.kind(weight) != ValueKind.NUMBER or values.number(weight) != 1:
        raise Error("product.dimensions.weight was not '1'")
    if not _is_string(values, values.get(args, "zip"), "94111"):
        raise Error("product.delivery input zip was not '94111'")
    var estimate = values.add_object()
    values.add_member(
        estimate, "estimatedDelivery", values.add_string("5/1/2019")
    )
    values.add_member(
        estimate, "fastestDelivery", values.add_string("5/1/2019")
    )
    return estimate


def _inventory_type(
    mut values: Values, value: Int, info: ResolveInfo, abstract_type: Int
) raises -> Int:
    """`Inventory.__resolveType`: `OpenSourceInventory` for `apollo-oss`,
    and `null` otherwise, so that graphql-js raises its error."""
    if _is_string(values, values.get(value, "id"), INVENTORY_ID):
        return values.add_string("OpenSourceInventory")
    return values.add_null()


def build_inventory() raises -> SubgraphSchema:
    """Build the `inventory` subgraph, as `buildSubgraphSchema` in
    index.js.

    Returns:
        The subgraph schema.

    Raises:
        Error: As `build_subgraph_schema` raises.
    """
    var resolvers = SubgraphResolvers()
    resolvers.field("Query", "inventory", _query_inventory)
    resolvers.field("Product", "delivery", _delivery)
    resolvers.resolve_type("Inventory", _inventory_type)
    var modules = List[SchemaModule]()
    modules.append(SchemaModule(parse(INVENTORY_SDL), resolvers^))
    return build_subgraph_schema(modules^)


def main() raises:
    """Serve the `inventory` subgraph until the process is stopped."""
    serve_subgraph(build_inventory(), "Inventory", "INVENTORY_PORT", 4003)

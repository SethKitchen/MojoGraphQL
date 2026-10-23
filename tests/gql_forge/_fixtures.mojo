# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Shared fixtures of the `gql_forge` tests."""

from std.os import getenv
from std.time import perf_counter_ns

from gql_forge.catalog import Catalog

comptime PRODUCTS_SDL = """type Query {
  product(id: ID!): Product
}

type Product {
  id: ID!
  name: String!
}
"""

comptime STAGING_SDL = """type Query {
  product(id: ID!): Product
  products: [Product!]!
}

type Product {
  id: ID!
  name: String!
  sku: String
}

enum Status {
  HOT
  COLD
}
"""

comptime INTROSPECTION_OK = """type Query {
  health: String
}
"""


def fresh_directory(name: String) -> String:
    """Return a catalog directory that no other test uses.

    Args:
        name: A short test name.

    Returns:
        A path under the process temporary directory.
    """
    return (
        getenv("TMPDIR", "/tmp")
        + "/forge_"
        + name
        + "_"
        + String(perf_counter_ns())
    )


def seeded_catalog(name: String) raises -> Catalog:
    """Return a catalog with one org, graph and two variants.

    Args:
        name: A short test name.

    Returns:
        An open catalog.

    Raises:
        Error: When the catalog cannot be written.
    """
    var catalog = Catalog(fresh_directory(name))
    catalog.open()
    var org = catalog.create_organization("acme", "Acme")
    if not org.accepted:
        raise Error(org.error)
    var graph = catalog.create_graph("acme", "shop", "Shop", "A shop graph")
    if not graph.accepted:
        raise Error(graph.error)
    var prod = catalog.create_variant(
        "acme", "shop", "prod", "http://127.0.0.1:4000/graphql", ""
    )
    if not prod.accepted:
        raise Error(prod.error)
    var staging = catalog.create_variant(
        "acme", "shop", "staging", "https://graph.example/graphql", "pull"
    )
    if not staging.accepted:
        raise Error(staging.error)
    return catalog^

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the entity keys of each subgraph, `gql_router.entity_keys`.

The keys follow `SupergraphState` and the `@join__type` keys that upstream
Hive Router `1a29df9` reads for `project_requires` in
`bin/router/src/executor/projection/request.rs`. A key that is not
resolvable is left out, and `__typename` is not a key field.
"""

from _fixtures import simplest_requires
from gql_router.entity_keys import EntityKeys, KeysByType, key_fields_of
from gql_router.normalize import selection_set_from_text
from gql_router.planner import Planner
from gql_router.store import Store
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _sdl() -> String:
    var sdl = simplest_requires.sdl()
    return sdl.replace(
        '@join__type(graph: INVENTORY, key: "upc")',
        '@join__type(graph: INVENTORY, key: "__typename upc")'
        + ' @join__type(graph: INVENTORY, key: "price", resolvable: false)',
    )


def test_keys_by_subgraph_and_type() raises:
    var planner = Planner(_sdl())
    var keys = EntityKeys.new(planner.store, planner.state)
    var inventory = keys.of_subgraph("inventory").value().copy()
    var product = inventory.get("Product").value().copy()
    assert_equal(len(product), 1)
    assert_equal(len(product[0]), 1)
    assert_equal(product[0][0], "upc")
    assert_false(inventory.get("Query"))
    assert_false(keys.of_subgraph("missing"))
    assert_true(keys.of_subgraph("products"))


def test_a_fragment_in_a_key_is_not_a_key_field() raises:
    var sdl = simplest_requires.sdl().replace(
        '@join__type(graph: PRODUCTS, key: "upc")',
        '@join__type(graph: PRODUCTS, key: "upc ... on Product { price }")',
    )
    var planner = Planner(sdl)
    var keys = EntityKeys.new(planner.store, planner.state)
    var product = (
        keys.of_subgraph("products").value().get("Product").value().copy()
    )
    # Normalization folds a fragment on the entity type into its fields.
    assert_equal(len(product[0]), 2)
    assert_equal(product[0][1], "price")
    var store = Store()
    var set = selection_set_from_text(
        store, "{ upc ... on A { b } __typename id }"
    )
    var fields = key_fields_of(store, set)
    assert_equal(len(fields), 2)
    assert_equal(fields[0], "upc")
    assert_equal(fields[1], "id")


def test_an_empty_table_knows_no_type() raises:
    var empty = KeysByType()
    assert_equal(empty.index_of("Product"), -1)
    assert_false(empty.get("Product"))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

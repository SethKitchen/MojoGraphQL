# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_forge.compare`."""

from std.os import makedirs

from _fixtures import PRODUCTS_SDL, STAGING_SDL, seeded_catalog
from gql_forge.compare import (
    SchemaChange,
    VariantDiff,
    additive_changes,
    compare_json,
    compare_schemas,
    compare_variants,
    current_schema_sdl,
    field_names,
)
from gql_forge.pull import store_schema_sdl
from gql_forge.store import write_file_atomic
from gql_schema.build import build_schema
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_compare_schemas() raises:
    var changes = compare_schemas(PRODUCTS_SDL, STAGING_SDL)
    var additive = 0
    for ref change in changes:
        if change.severity == "additive":
            additive += 1
    assert_true(additive >= 1)
    var same = compare_schemas(PRODUCTS_SDL, PRODUCTS_SDL)
    assert_equal(len(same), 0)
    var breaking = compare_schemas(STAGING_SDL, PRODUCTS_SDL)
    var found = False
    for ref change in breaking:
        if change.severity == "breaking":
            found = True
    assert_true(found)
    var add = additive_changes(
        build_schema(PRODUCTS_SDL), build_schema(STAGING_SDL)
    )
    assert_true(len(add) >= 1)


def test_additive_edges() raises:
    var schema = build_schema(PRODUCTS_SDL)
    assert_equal(len(field_names(schema, -1)), 0)
    assert_equal(len(field_names(schema, 9999)), 0)
    assert_equal(len(field_names(schema, schema.type_named("String"))), 0)
    var old_enum = build_schema(
        "type Query { a: String }\nenum Status { HOT }\n"
    )
    var new_obj = build_schema(
        "type Query { a: String }\ntype Status { id: ID }\n"
    )
    _ = additive_changes(old_enum, new_obj)
    var new_enum = build_schema(
        "type Query { a: String }\nenum Status { HOT\nCOLD }\n"
    )
    _ = additive_changes(old_enum, new_enum)
    var ghost_old = build_schema(PRODUCTS_SDL)
    var extra = ghost_old.types[ghost_old.type_named("Product")].copy()
    extra.name = String("Ghost")
    extra.is_builtin = False
    ghost_old.types.append(extra.copy())
    ghost_old.type_map.append(Int32(len(ghost_old.types) - 1))
    var ghost_new = build_schema(STAGING_SDL)
    var extra2 = ghost_new.types[ghost_new.type_named("Product")].copy()
    extra2.name = String("Ghost")
    extra2.is_builtin = False
    ghost_new.types.append(extra2.copy())
    ghost_new.type_map.append(Int32(len(ghost_new.types) - 1))
    _ = additive_changes(ghost_old, ghost_new)
    var mixed = List[SchemaChange]()
    mixed.append(SchemaChange(String("breaking"), String("X"), String("a")))
    mixed.append(SchemaChange(String("dangerous"), String("Y"), String("b")))
    mixed.append(SchemaChange(String("additive"), String("Z"), String("c")))
    var json = compare_json(
        VariantDiff(String("a"), String("b"), 1, 2, String("oops"), mixed^)
    )
    assert_true(json.find('"breaking":1') >= 0)
    assert_true(json.find("oops") >= 0)


def test_compare_variants() raises:
    var catalog = seeded_catalog("cmp")
    var missing = compare_variants(catalog, "acme", "shop", "nope", "prod")
    assert_true(missing.error.find("nope") >= 0)
    var missing2 = compare_variants(catalog, "acme", "shop", "prod", "nope")
    assert_true(missing2.error.find("nope") >= 0)
    var empty = compare_variants(catalog, "acme", "shop", "prod", "staging")
    assert_true(empty.error.find("snapshot") >= 0)
    var prod = catalog.get_variant("acme", "shop", "prod")
    _ = store_schema_sdl(catalog, prod, PRODUCTS_SDL)
    var still = compare_variants(catalog, "acme", "shop", "prod", "staging")
    assert_true(still.error.find("staging") >= 0)
    var staging = catalog.get_variant("acme", "shop", "staging")
    _ = store_schema_sdl(catalog, staging, STAGING_SDL)
    var diff = compare_variants(catalog, "acme", "shop", "prod", "staging")
    assert_equal(diff.error, "")
    var json = compare_json(diff)
    assert_true(json.find("additive") >= 0)
    assert_true(current_schema_sdl(catalog, "acme", "shop", "prod"))
    assert_false(current_schema_sdl(catalog, "acme", "shop", "none"))
    var zero_dir = catalog.store.schema_dir("acme", "shop", "prod")
    makedirs(zero_dir, exist_ok=True)
    write_file_atomic(
        catalog.store.current_schema_path("acme", "shop", "prod"), "0\n"
    )
    assert_false(current_schema_sdl(catalog, "acme", "shop", "prod"))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

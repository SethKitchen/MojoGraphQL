# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_forge.pull`."""

from _fixtures import PRODUCTS_SDL, seeded_catalog
from gql_forge.pull import (
    introspection_body,
    pull_variant,
    read_introspection_sdl,
    record_pull_error,
    store_schema_sdl,
    upload_schema,
)
from gql_json.writer import stringify
from gql_schema.build import build_schema
from gql_schema.introspection import introspection_from_schema
from std.testing import (
    TestSuite,
    assert_false,
    assert_true,
    assert_raises,
)


def test_read_introspection_sdl() raises:
    var data = introspection_from_schema(build_schema(PRODUCTS_SDL))
    var body = '{"data":' + stringify(data, data.root) + "}"
    var sdl = read_introspection_sdl(200, List[UInt8](body.as_bytes()))
    assert_true(sdl.find("type Product") >= 0)
    with assert_raises(contains="HTTP 500"):
        _ = read_introspection_sdl(500, List[UInt8]("x".as_bytes()))
    with assert_raises(contains="not a JSON object"):
        _ = read_introspection_sdl(200, List[UInt8]("[]".as_bytes()))
    with assert_raises(contains="the graph answered:"):
        _ = read_introspection_sdl(
            200, List[UInt8]('{"errors":[{"message":"boom"}]}'.as_bytes())
        )
    with assert_raises(contains="GraphQL errors"):
        _ = read_introspection_sdl(
            200, List[UInt8]('{"errors":[1]}'.as_bytes())
        )
    with assert_raises(contains="no data object"):
        _ = read_introspection_sdl(200, List[UInt8]("{}".as_bytes()))
    _ = introspection_body()


def test_upload_and_store() raises:
    var catalog = seeded_catalog("pull")
    var missing = upload_schema(catalog, "acme", "shop", "nope", PRODUCTS_SDL)
    assert_true(missing.find("not in Forge") >= 0)
    var bad = upload_schema(catalog, "acme", "shop", "prod", "not sdl")
    assert_true(bad.find("error") >= 0)
    var ok = upload_schema(catalog, "acme", "shop", "prod", PRODUCTS_SDL)
    assert_true(ok.find("revision") >= 0)
    var again = upload_schema(catalog, "acme", "shop", "prod", PRODUCTS_SDL)
    assert_true(again.find("revision") >= 0)
    var prod = catalog.get_variant("acme", "shop", "prod")
    assert_true(prod.last_pull_ok)
    assert_true(prod.schema_revision >= 1)
    record_pull_error(catalog, prod, String("x"))
    assert_false(catalog.get_variant("acme", "shop", "prod").last_pull_ok)
    var https = pull_variant(catalog, "acme", "shop", "staging")
    assert_true(https.find("http://") >= 0)
    var none = pull_variant(catalog, "acme", "shop", "nope")
    assert_true(none.find("not in Forge") >= 0)
    var fail = pull_variant(catalog, "acme", "shop", "prod", 10)
    assert_true(fail.find("error") >= 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

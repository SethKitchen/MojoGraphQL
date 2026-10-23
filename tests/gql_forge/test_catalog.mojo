# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_forge.catalog`."""

from std.os import makedirs

from _fixtures import fresh_directory, seeded_catalog
from gql_forge.catalog import (
    Catalog,
    Graph,
    Organization,
    Variant,
    file_stem,
    graph_json,
    list_json_files,
    organization_json,
    parse_graph,
    parse_organization,
    parse_variant,
    variant_json,
)
from gql_forge.store import write_file_atomic
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)


def test_json_round_trip() raises:
    var org = Organization("acme", "Acme", 9)
    var back = parse_organization(organization_json(org))
    assert_equal(back.slug, "acme")
    assert_equal(back.name, "Acme")
    assert_equal(back.created_at, 9)
    var nameless = parse_organization('{"slug":"solo"}')
    assert_equal(nameless.name, "solo")
    var graph = Graph("acme", "shop", "Shop", "d", 3)
    var g2 = parse_graph(graph_json(graph))
    assert_equal(g2.key, "shop")
    assert_equal(g2.description, "d")
    var g3 = parse_graph('{"org":"acme","ref":"x"}')
    assert_equal(g3.name, "x")
    var variant = Variant(
        "acme", "shop", "prod", "http://a/", "p", "frg_t", 2, 1, "", True, 8
    )
    var v2 = parse_variant(variant_json(variant))
    assert_equal(v2.ingest_token, "frg_t")
    assert_true(v2.last_pull_ok)
    assert_equal(file_stem("prod.json"), "prod")
    assert_equal(file_stem("prod"), "prod")
    assert_equal(file_stem(".json"), ".json")
    assert_equal(len(list_json_files(fresh_directory("empty-list"))), 0)
    var mixed = fresh_directory("mixed-list")
    makedirs(mixed, exist_ok=True)
    write_file_atomic(mixed + "/keep.json", "{}")
    write_file_atomic(mixed + "/skip.txt", "x")
    assert_equal(len(list_json_files(mixed)), 1)


def test_catalog_create_and_lists() raises:
    var catalog = seeded_catalog("cat")
    assert_true(catalog.has_organization("acme"))
    assert_false(catalog.has_organization("nope"))
    assert_equal(len(catalog.organizations()), 1)
    assert_equal(catalog.get_organization("acme").name, "Acme")
    assert_equal(len(catalog.graphs("acme")), 1)
    assert_equal(catalog.get_graph("acme", "shop").description, "A shop graph")
    assert_equal(len(catalog.variants("acme", "shop")), 2)
    assert_true(catalog.has_variant("acme", "shop", "prod"))
    assert_equal(
        catalog.get_variant("acme", "shop", "prod").endpoint_url,
        "http://127.0.0.1:4000/graphql",
    )
    assert_true(
        catalog.get_variant("acme", "shop", "prod").ingest_token.startswith(
            "frg_"
        )
    )


def test_catalog_refusals() raises:
    var catalog = Catalog(fresh_directory("refuse"))
    catalog.open()
    assert_false(catalog.create_organization("9", "n").accepted)
    var first = catalog.create_organization("acme", "")
    assert_true(first.accepted)
    assert_equal(catalog.get_organization("acme").name, "acme")
    assert_false(catalog.create_organization("acme", "x").accepted)
    assert_false(catalog.create_graph("9", "shop", "", "").accepted)
    assert_false(catalog.create_graph("acme", "9", "", "").accepted)
    assert_false(catalog.create_graph("missing", "shop", "", "").accepted)
    var graph = catalog.create_graph("acme", "shop", "", "")
    assert_true(graph.accepted)
    assert_equal(catalog.get_graph("acme", "shop").name, "shop")
    assert_false(catalog.create_graph("acme", "shop", "", "").accepted)
    assert_false(
        catalog.create_variant("acme", "shop", "9", "http://a/", "").accepted
    )
    assert_false(
        catalog.create_variant("acme", "shop", "prod", "ftp://a", "").accepted
    )
    assert_false(
        catalog.create_variant(
            "acme", "missing", "prod", "http://a/", ""
        ).accepted
    )
    assert_true(
        catalog.create_variant(
            "acme", "shop", "prod", "http://a/", "tok"
        ).accepted
    )
    assert_false(
        catalog.create_variant("acme", "shop", "prod", "http://a/", "").accepted
    )


def test_update_and_remove_variant() raises:
    var catalog = seeded_catalog("upd")
    var missing = catalog.update_variant("acme", "shop", "nope", None, None)
    assert_false(missing.accepted)
    var bad = catalog.update_variant(
        "acme", "shop", "prod", Optional[String]("ftp://x"), None
    )
    assert_false(bad.accepted)
    var ok = catalog.update_variant(
        "acme",
        "shop",
        "prod",
        Optional[String]("http://127.0.0.1:9/"),
        Optional[String]("secret"),
    )
    assert_true(ok.accepted)
    var variant = catalog.get_variant("acme", "shop", "prod")
    assert_equal(variant.endpoint_url, "http://127.0.0.1:9/")
    assert_equal(variant.pull_token, "secret")
    var keep = catalog.update_variant("acme", "shop", "prod", None, None)
    assert_true(keep.accepted)
    assert_true(catalog.remove_variant("acme", "shop", "prod").accepted)
    assert_false(catalog.has_variant("acme", "shop", "prod"))
    assert_false(catalog.remove_variant("acme", "shop", "prod").accepted)


def test_parse_errors() raises:
    with assert_raises(contains="not an object"):
        _ = parse_organization("[]")
    with assert_raises(contains="no string slug"):
        _ = parse_organization("{}")
    with assert_raises(contains="no string org"):
        _ = parse_graph("{}")
    with assert_raises(contains="no string name"):
        _ = parse_variant('{"org":"a","graph":"b"}')


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

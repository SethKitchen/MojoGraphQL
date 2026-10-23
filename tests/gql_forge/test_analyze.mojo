# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_forge.analyze`."""

from _fixtures import PRODUCTS_SDL, STAGING_SDL, fresh_directory, seeded_catalog
from gql_forge.analyze import (
    AnalyzeIntent,
    analysis_json,
    analyze,
    analyze_type,
    classify_question,
    matched_type_name,
)
from gql_forge.catalog import Catalog
from gql_forge.pull import store_schema_sdl
from gql_forge.telemetry import TelemetryEvent, ingest_event
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_intent_type() raises:
    var invalid = AnalyzeIntent(9)
    assert_false(invalid.is_valid())
    assert_equal(String(invalid), "<invalid>")
    assert_true(AnalyzeIntent.HEALTH.is_valid())
    assert_equal(AnalyzeIntent.HEALTH.text(), "HEALTH")
    assert_equal(AnalyzeIntent.COMPARE.text(), "COMPARE")
    assert_equal(AnalyzeIntent.LATENCY.text(), "LATENCY")
    assert_equal(AnalyzeIntent.ERRORS.text(), "ERRORS")
    assert_equal(AnalyzeIntent.TYPE.text(), "TYPE")
    assert_equal(AnalyzeIntent.OPERATIONS.text(), "OPERATIONS")
    assert_equal(AnalyzeIntent.CONNECT.text(), "CONNECT")


def test_classify() raises:
    var types = List[String]()
    types.append("Product")
    types.append("A")
    assert_equal(classify_question("", types), AnalyzeIntent.HEALTH)
    assert_equal(
        classify_question("allowlist our IP", types), AnalyzeIntent.CONNECT
    )
    assert_equal(
        classify_question("register endpoint", types), AnalyzeIntent.CONNECT
    )
    assert_equal(
        classify_question("connect ingest", types), AnalyzeIntent.CONNECT
    )
    assert_equal(
        classify_question("breaking between staging", types),
        AnalyzeIntent.COMPARE,
    )
    assert_equal(
        classify_question("diff environment", types), AnalyzeIntent.COMPARE
    )
    assert_equal(
        classify_question("error rate failed", types), AnalyzeIntent.ERRORS
    )
    assert_equal(classify_question("exception", types), AnalyzeIntent.ERRORS)
    assert_equal(
        classify_question("slow p95 latency", types), AnalyzeIntent.LATENCY
    )
    assert_equal(
        classify_question("p50 duration p99", types), AnalyzeIntent.LATENCY
    )
    assert_equal(
        classify_question("which operation ran", types),
        AnalyzeIntent.OPERATIONS,
    )
    assert_equal(
        classify_question("mutation query list", types),
        AnalyzeIntent.OPERATIONS,
    )
    assert_equal(
        classify_question("tell me about Product", types), AnalyzeIntent.TYPE
    )
    assert_equal(
        classify_question("summary please", types), AnalyzeIntent.HEALTH
    )
    assert_equal(matched_type_name("Product please", types), "Product")
    assert_equal(matched_type_name("nope", types), "")
    assert_equal(matched_type_name("A letter", types), "")


def test_analyze_paths() raises:
    var missing = analyze(
        Catalog(fresh_directory("none")), "acme", "shop", "", "", ""
    )
    assert_true(missing.summary.find("not in Forge") >= 0)
    var catalog = seeded_catalog("an")
    var connect = analyze(catalog, "acme", "shop", "how do I connect", "", "")
    assert_equal(connect.intent, AnalyzeIntent.CONNECT)
    catalog.store.set_advertise_ip("203.0.113.10")
    var connect2 = analyze(catalog, "acme", "shop", "allowlist", "", "")
    assert_true(connect2.findings[0].find("203.0.113.10") >= 0)
    var health = analyze(catalog, "acme", "shop", "", "", "")
    assert_equal(health.intent, AnalyzeIntent.HEALTH)
    var prod = catalog.get_variant("acme", "shop", "prod")
    _ = store_schema_sdl(catalog, prod, PRODUCTS_SDL)
    var staging = catalog.get_variant("acme", "shop", "staging")
    _ = store_schema_sdl(catalog, staging, STAGING_SDL)
    var record_fail = catalog.get_variant("acme", "shop", "prod")
    record_fail.last_pull_ok = False
    record_fail.last_pull_error = String("timeout")
    catalog.save_variant(record_fail)
    var health2 = analyze(
        catalog, "acme", "shop", "overview", "prod", "staging"
    )
    assert_true(len(health2.findings) >= 2)
    var same = analyze(catalog, "acme", "shop", "compare", "prod", "prod")
    assert_true(same.summary.find("two different") >= 0)
    var diff = analyze(
        catalog, "acme", "shop", "breaking changes", "prod", "staging"
    )
    assert_equal(diff.intent, AnalyzeIntent.COMPARE)
    _ = analysis_json(diff)
    var latency_empty = analyze(
        catalog, "acme", "shop", "slow operations", "prod", ""
    )
    assert_equal(latency_empty.intent, AnalyzeIntent.LATENCY)


def test_analyze_telemetry_and_types() raises:
    var catalog = seeded_catalog("an2")
    var prod = catalog.get_variant("acme", "shop", "prod")
    _ = store_schema_sdl(catalog, prod, PRODUCTS_SDL)
    _ = ingest_event(
        catalog,
        TelemetryEvent("acme", "shop", "prod", "Hero", "", 12, True, 0, "", 10),
    )
    _ = ingest_event(
        catalog,
        TelemetryEvent(
            "acme", "shop", "prod", "Hero", "", 80, False, 1, "", 11
        ),
    )
    _ = ingest_event(
        catalog,
        TelemetryEvent(
            "acme", "shop", "prod", "Search", "", 3, True, 0, "", 12
        ),
    )
    var latency = analyze(catalog, "acme", "shop", "p95 latency", "prod", "")
    assert_true(latency.summary.find("Hero") >= 0)
    var errors = analyze(catalog, "acme", "shop", "errors", "prod", "")
    assert_true(errors.summary.find("Hero") >= 0)
    var ops = analyze(catalog, "acme", "shop", "operations", "prod", "")
    assert_true(ops.summary.find("2") >= 0)
    var typ = analyze(catalog, "acme", "shop", "What is Product", "prod", "")
    assert_equal(typ.type_name, "Product")
    var unknown = analyze(catalog, "acme", "shop", "What is Review", "prod", "")
    assert_equal(unknown.intent, AnalyzeIntent.HEALTH)


def test_analyze_empty_telemetry() raises:
    var catalog = seeded_catalog("edge")
    var no_tel = analyze(catalog, "acme", "shop", "slow", "prod", "")
    assert_true(no_tel.summary.find("No operation") >= 0)
    var no_err = analyze(catalog, "acme", "shop", "errors", "prod", "")
    assert_true(no_err.summary.find("No failed") >= 0)
    var no_ops = analyze(catalog, "acme", "shop", "operations", "prod", "")
    assert_true(no_ops.summary.find("No operations") >= 0)
    var from_staging = analyze(
        catalog, "acme", "shop", "compare", "staging", ""
    )
    assert_true(
        from_staging.summary.find("two different") >= 0
        or from_staging.summary.find("snapshot") >= 0
    )


def test_analyze_compare_edges() raises:
    var one = Catalog(fresh_directory("onev"))
    one.open()
    _ = one.create_organization("acme", "Acme")
    _ = one.create_graph("acme", "shop", "Shop", "")
    _ = one.create_variant("acme", "shop", "prod", "http://127.0.0.1/", "")
    var cmp = analyze(one, "acme", "shop", "compare environments", "", "")
    assert_true(
        cmp.summary.find("two different") >= 0
        or cmp.summary.find("two variants") >= 0
        or cmp.title.find("Same") >= 0
    )
    var empty_graph = Catalog(fresh_directory("novar"))
    empty_graph.open()
    _ = empty_graph.create_organization("acme", "Acme")
    _ = empty_graph.create_graph("acme", "shop", "Shop", "")
    var no_var = analyze(empty_graph, "acme", "shop", "compare", "", "")
    assert_true(
        no_var.summary.find("two variants") >= 0
        or no_var.summary.find("No environments") >= 0
    )
    var latency_none = analyze(empty_graph, "acme", "shop", "slow", "", "")
    assert_true(latency_none.summary.find("Add a variant") >= 0)
    var pair = Catalog(fresh_directory("zebra"))
    pair.open()
    _ = pair.create_organization("acme", "Acme")
    _ = pair.create_graph("acme", "shop", "Shop", "")
    _ = pair.create_variant("acme", "shop", "prod", "http://127.0.0.1/", "")
    _ = pair.create_variant("acme", "shop", "zebra", "http://127.0.0.1/", "")
    var auto = analyze(pair, "acme", "shop", "compare environments", "", "")
    assert_true(auto.intent == AnalyzeIntent.COMPARE)


def test_analyze_type_edges() raises:
    var catalog = seeded_catalog("atype")
    var prod = catalog.get_variant("acme", "shop", "prod")
    _ = store_schema_sdl(catalog, prod, PRODUCTS_SDL)
    var type_ok = analyze(catalog, "acme", "shop", "Product fields", "prod", "")
    assert_equal(type_ok.intent, AnalyzeIntent.TYPE)
    var empty_name = analyze_type(catalog, "acme", "shop", "prod", String(""))
    assert_true(empty_name.summary.find("does not name") >= 0)
    var missing = analyze_type(
        catalog, "acme", "shop", "prod", String("Review")
    )
    assert_true(missing.summary.find("not in") >= 0)
    assert_equal(matched_type_name("zzz", List[String]()), "")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

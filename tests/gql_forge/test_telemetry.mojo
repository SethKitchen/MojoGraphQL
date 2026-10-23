# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_forge.telemetry`."""

from _fixtures import seeded_catalog
from gql_forge.telemetry import (
    MAX_RECENT,
    MAX_SAMPLES,
    MAX_WINDOWS,
    TelemetryEvent,
    apply_event,
    empty_log,
    ingest_event,
    insights_json,
    load_log,
    parse_telemetry_event,
    parse_telemetry_log,
    percentile,
    telemetry_json,
)
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)


def test_percentile() raises:
    assert_equal(percentile(List[Int](), 50), 0)
    var one = List[Int]()
    one.append(8)
    assert_equal(percentile(one, 50), 8)
    var many = List[Int]()
    many.append(9)
    many.append(1)
    many.append(5)
    assert_equal(percentile(many, 0), 1)
    assert_equal(percentile(many, 100), 9)
    assert_equal(percentile(many, -5), 1)
    assert_equal(percentile(many, 200), 9)


def test_parse_event() raises:
    var event = parse_telemetry_event(
        '{"org":"acme","graph":"shop","variant":"prod","operationName":"Hero","durationMs":-2,"errors":-1}'
    )
    assert_equal(event.name, "Hero")
    assert_equal(event.duration_ms, 0)
    assert_equal(event.errors, 0)
    var anon = parse_telemetry_event(
        '{"org":"acme","graph":"shop","variant":"prod"}'
    )
    assert_equal(anon.name, "(anonymous)")
    var named = parse_telemetry_event(
        '{"org":"acme","graph":"shop","variant":"prod","name":"Q","durationMs":4,"ok":true}'
    )
    assert_equal(named.name, "Q")
    var failed = parse_telemetry_event(
        '{"org":"acme","graph":"shop","variant":"prod","name":"Q","errors":2,"ok":true}'
    )
    assert_false(failed.ok)
    with assert_raises(contains="no string org"):
        _ = parse_telemetry_event("{}")


def test_apply_and_insights() raises:
    var log = empty_log()
    var event = TelemetryEvent(
        "acme", "shop", "prod", "Hero", "sig", 10, True, 0, "ios", 100
    )
    apply_event(log, event, 100)
    apply_event(log, event, 100)
    var fail = event.copy()
    fail.ok = False
    fail.duration_ms = 40
    fail.signature = String("")
    apply_event(log, fail, 100)
    var other = event.copy()
    other.name = String("Search")
    other.duration_ms = 3
    apply_event(log, other, 160)
    assert_equal(len(log.operations), 2)
    assert_equal(log.operations[0].count, 3)
    assert_equal(log.operations[0].errors, 1)
    assert_equal(log.operations[0].max_ms, 40)
    assert_equal(log.operations[0].min_ms, 10)
    assert_equal(len(log.windows), 2)
    var json = telemetry_json(log)
    var back = parse_telemetry_log(json)
    assert_equal(len(back.operations), 2)
    assert_equal(len(back.recent), 4)
    var insights = insights_json(log)
    assert_true(insights.find('"requests":4') >= 0)
    var empty = insights_json(empty_log())
    assert_true(empty.find('"requests":0') >= 0)
    var parsed_empty = parse_telemetry_log("{}")
    assert_equal(len(parsed_empty.operations), 0)
    var messy = parse_telemetry_log(
        '{"operations":[1,{"name":"A","samples":["x",2,1.5]}],"recent":[1,{"name":"A"}],"windows":[1,{"at":1}]}'
    )
    assert_equal(len(messy.operations), 1)
    assert_equal(len(messy.operations[0].samples), 2)


def test_ingest() raises:
    var catalog = seeded_catalog("tel")
    var missing = ingest_event(
        catalog,
        TelemetryEvent("acme", "shop", "nope", "Q", "", 1, True, 0, "", 1),
    )
    assert_true(missing.find("not in Forge") >= 0)
    var ok = ingest_event(
        catalog,
        TelemetryEvent("acme", "shop", "prod", "Q", "s", 5, True, 0, "", 0),
    )
    assert_true(ok.find("accepted") >= 0)
    var log = load_log(catalog, "acme", "shop", "prod")
    assert_equal(len(log.operations), 1)
    var none = load_log(catalog, "acme", "shop", "missing")
    assert_equal(len(none.operations), 0)
    var cap = empty_log()
    var ev = TelemetryEvent("acme", "shop", "prod", "Q", "", 1, True, 0, "", 1)
    var i = 0
    while i < MAX_SAMPLES + MAX_RECENT + 2:
        apply_event(cap, ev, 1000 + i)
        i += 1
    assert_true(len(cap.operations[0].samples) <= MAX_SAMPLES)
    assert_true(len(cap.recent) <= MAX_RECENT)
    var w = 0
    while w < MAX_WINDOWS + 2:
        apply_event(cap, ev, w * 60)
        w += 1
    assert_true(len(cap.windows) <= MAX_WINDOWS)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

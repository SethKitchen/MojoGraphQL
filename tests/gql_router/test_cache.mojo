# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the router operation cache.

The cases follow `should_build_cache_with_combined_ttl_and_tti`,
`should_build_cache_without_expiry_by_default`,
`should_ignore_zero_ttl_and_tti`, `should_cache_nothing_when_max_entries_is_zero`,
and `should_expire_entries_after_ttl` in Hive Router `cache_state.rs`.
"""

from gql_router.cache import (
    CacheOverride,
    OperationCache,
    cache_config_from_json,
    default_cache_config,
    default_cache_limits,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_default_limits_have_no_expiry() raises:
    var limits = default_cache_limits()
    assert_equal(limits.max_entries, 1000)
    assert_equal(limits.time_to_live_ms, 0)
    assert_equal(limits.time_to_idle_ms, 0)


def test_limits_keep_time_to_live_and_time_to_idle() raises:
    var limits = (
        default_cache_limits()
        .with_max_entries(10)
        .with_time_to_live_ms(1800000)
        .with_time_to_idle_ms(300000)
    )
    assert_equal(limits.max_entries, 10)
    assert_equal(limits.time_to_live_ms, 1800000)
    assert_equal(limits.time_to_idle_ms, 300000)


def test_zero_expiry_stays_unset() raises:
    var limits = (
        default_cache_limits().with_time_to_live_ms(0).with_time_to_idle_ms(0)
    )
    assert_equal(limits.time_to_live_ms, 0)
    assert_equal(limits.time_to_idle_ms, 0)


def test_a_zero_entry_limit_stores_nothing() raises:
    var cache = OperationCache(default_cache_limits().with_max_entries(0))
    cache.insert("1", "1", 0)
    assert_equal(cache.entry_count(0), 0)
    assert_false(cache.get("1", 0))


def test_an_entry_expires_after_its_time_to_live() raises:
    var cache = OperationCache(default_cache_limits().with_time_to_live_ms(20))
    cache.insert("1", "1", 0)
    assert_equal(cache.entry_count(0), 1)
    assert_false(cache.get("1", 50))
    assert_equal(cache.entry_count(50), 0)


def test_an_entry_expires_after_it_is_idle() raises:
    var cache = OperationCache(default_cache_limits().with_time_to_idle_ms(30))
    cache.insert("1", "1", 0)
    assert_true(cache.get("1", 10))
    assert_false(cache.get("1", 40))


def test_a_full_cache_drops_the_oldest_entry() raises:
    var cache = OperationCache(default_cache_limits().with_max_entries(1))
    cache.insert("a", "1", 0)
    cache.insert("b", "2", 1)
    assert_false(cache.get("a", 1))
    var found = cache.get("b", 1)
    assert_true(found)
    assert_equal(found.value(), "2")


def test_an_empty_config_uses_every_default() raises:
    var config = default_cache_config()
    assert_equal(config.router.parsing.max_entries, 1000)
    assert_equal(config.router.plugin_supergraph_runtimes, 10)
    assert_equal(config.router.parsing.time_to_live_ms, 0)
    assert_equal(config.router.parsing.time_to_idle_ms, 0)
    assert_equal(config.supergraph.query_plans.max_entries, 1000)
    assert_equal(config.supergraph.validation.max_entries, 1000)
    assert_equal(config.supergraph.normalization.max_entries, 1000)


def test_an_override_replaces_one_dimension() raises:
    var inherited = (
        default_cache_limits()
        .with_max_entries(9)
        .with_time_to_live_ms(1800000)
        .with_time_to_idle_ms(300000)
    )
    var untouched = CacheOverride()
    var same = untouched.resolve(inherited)
    assert_equal(same.max_entries, 9)
    assert_equal(same.time_to_live_ms, 1800000)
    assert_equal(same.time_to_idle_ms, 300000)
    var live_only = CacheOverride()
    live_only.set_time_to_live_ms(60000)
    var resolved = live_only.resolve(inherited)
    assert_equal(resolved.max_entries, 9)
    assert_equal(resolved.time_to_live_ms, 60000)
    assert_equal(resolved.time_to_idle_ms, 300000)
    var disabled = CacheOverride()
    disabled.set_time_to_live_ms(0)
    disabled.set_time_to_idle_ms(0)
    var cleared = disabled.resolve(inherited)
    assert_equal(cleared.max_entries, 9)
    assert_equal(cleared.time_to_live_ms, 0)
    assert_equal(cleared.time_to_idle_ms, 0)
    disabled.disable()
    assert_equal(disabled.resolve(inherited).max_entries, 0)
    disabled.inherit()
    assert_equal(disabled.resolve(inherited).max_entries, 9)


def test_json_keeps_defaults_for_unset_caches() raises:
    var empty = cache_config_from_json("{}")
    assert_equal(empty.router.parsing.max_entries, 1000)
    assert_equal(empty.router.plugin_supergraph_runtimes, 10)
    assert_equal(empty.router.parsing.time_to_live_ms, 0)
    assert_equal(empty.supergraph.query_plans.max_entries, 1000)
    var partial = cache_config_from_json(
        '{"supergraph": {"query_plans": {"max_entries": 5}}}'
    )
    assert_equal(partial.supergraph.query_plans.max_entries, 5)
    assert_equal(partial.supergraph.query_plans.time_to_live_ms, 0)
    assert_equal(partial.supergraph.query_plans.time_to_idle_ms, 0)
    assert_equal(partial.supergraph.validation.max_entries, 1000)
    assert_equal(partial.router.parsing.max_entries, 1000)
    var timed = cache_config_from_json(
        '{"supergraph": {"query_plans": {"max_entries": 5,'
        ' "time_to_live": "30m", "time_to_idle": "5m"}}}'
    )
    assert_equal(timed.supergraph.query_plans.max_entries, 5)
    assert_equal(timed.supergraph.query_plans.time_to_live_ms, 1800000)
    assert_equal(timed.supergraph.query_plans.time_to_idle_ms, 300000)
    assert_equal(timed.supergraph.validation.time_to_live_ms, 0)
    assert_equal(timed.supergraph.validation.time_to_idle_ms, 0)


def test_json_reads_router_and_every_supergraph_cache() raises:
    var config = cache_config_from_json(
        '{"router": {"parsing": {"time_to_live": "500ms"},'
        ' "plugin_supergraph_runtimes": 3},'
        ' "supergraph": {"validation": {"time_to_idle": "5s"},'
        ' "normalization": {"time_to_live": "2h"}}}'
    )
    assert_equal(config.router.parsing.max_entries, 1000)
    assert_equal(config.router.parsing.time_to_live_ms, 500)
    assert_equal(config.router.plugin_supergraph_runtimes, 3)
    assert_equal(config.supergraph.validation.time_to_idle_ms, 5000)
    assert_equal(config.supergraph.normalization.time_to_live_ms, 7200000)
    assert_equal(config.supergraph.query_plans.max_entries, 1000)
    var router_only = cache_config_from_json('{"router": {}}')
    assert_equal(router_only.router.parsing.max_entries, 1000)
    assert_equal(router_only.router.plugin_supergraph_runtimes, 10)


def _raises_with(text: String, message: String) raises:
    """Assert that a cache configuration fails with a message."""
    try:
        _ = cache_config_from_json(text)
    except error:
        assert_equal(String(error), message)
        return
    raise Error("expected an error for " + text)


def test_json_rejects_a_bad_cache_config() raises:
    _raises_with("[]", "Cache config must be an object")
    _raises_with('{"other": {}}', "Unknown cache field other")
    _raises_with('{"router": 1}', "Router cache config must be an object")
    _raises_with('{"router": {"size": 1}}', "Unknown cache field size")
    _raises_with('{"router": {"parsing": 1}}', "Cache limits must be an object")
    _raises_with(
        '{"supergraph": []}', "Supergraph cache config must be an object"
    )
    _raises_with('{"supergraph": {"plans": {}}}', "Unknown cache field plans")
    _raises_with(
        '{"supergraph": {"validation": {"ttl": "1s"}}}',
        "Unknown cache field ttl",
    )


def test_json_rejects_a_bad_duration() raises:
    for text in ["30", "m", "-5s", "", "5d", "3.5s"]:
        _raises_with(
            '{"supergraph": {"query_plans": {"time_to_live": "'
            + String(text)
            + '"}}}',
            "Invalid cache duration " + String(text),
        )


def test_an_insert_replaces_the_value_of_a_key() raises:
    var cache = OperationCache(default_cache_limits().with_max_entries(2))
    cache.insert("a", "1", 0)
    cache.insert("a", "2", 1)
    assert_equal(cache.get("a", 1).value(), "2")
    assert_equal(cache.entry_count(1), 1)


def test_eviction_keeps_the_newer_entries() raises:
    var cache = OperationCache(default_cache_limits().with_max_entries(2))
    cache.insert("a", "1", 0)
    cache.insert("b", "2", 1)
    cache.insert("c", "3", 2)
    assert_false(cache.get("a", 2))
    assert_equal(cache.get("b", 2).value(), "2")
    assert_equal(cache.get("c", 2).value(), "3")
    assert_equal(cache.entry_count(2), 2)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

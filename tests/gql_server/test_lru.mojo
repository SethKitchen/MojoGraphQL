# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `gql_server.lru.InMemoryLRUCache`: the `maxSize`, size and
time to live behavior of `lru-cache` 11.5.3, which
`@apollo/utils.keyvaluecache` 4.0.0 `InMemoryLRUCache` uses. The upstream
package has no tests of its own in Apollo Server 5.5.1; these cases
follow the `lru-cache` README.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_true
from gql_server.lru import InMemoryLRUCache

comptime SECOND = 1_000_000_000
"""One second in nanoseconds."""


def _has(mut cache: InMemoryLRUCache[String], key: String) -> Bool:
    return Bool(cache.get(key, 0))


def test_get_and_set() raises:
    var cache = InMemoryLRUCache[String](10)
    assert_false(_has(cache, "a"))
    cache.set("a", "1", 3, 0)
    cache.set("b", "2", 3, 0)
    assert_equal(cache.get("a", 0).value(), "1")
    cache.set("a", "one", 4, 0)
    assert_equal(cache.get("a", 0).value(), "one")
    assert_equal(cache.total_size, 7)
    assert_equal(len(cache), 2)


def test_evicts_least_recently_used() raises:
    var cache = InMemoryLRUCache[String](10)
    cache.set("a", "1", 4, 0)
    cache.set("b", "2", 4, 0)
    _ = cache.get("a", 0)
    cache.set("c", "3", 4, 0)
    assert_true(_has(cache, "a"))
    assert_false(_has(cache, "b"))
    assert_true(_has(cache, "c"))
    # Two entries go to make room for a large one.
    cache.set("d", "4", 9, 0)
    assert_equal(len(cache), 1)
    assert_true(_has(cache, "d"))


def test_too_large_entry() raises:
    var cache = InMemoryLRUCache[String](10)
    cache.set("a", "1", 4, 0)
    cache.set("big", "x", 11, 0)
    assert_false(_has(cache, "big"))
    cache.set("a", "huge", 11, 0)
    assert_false(_has(cache, "a"))
    assert_equal(cache.total_size, 0)


def test_time_to_live() raises:
    var cache = InMemoryLRUCache[String](10)
    cache.set("a", "1", 1, 0, 2)
    cache.set("b", "2", 1, 0)
    assert_true(Bool(cache.get("a", 2 * SECOND - 1)))
    assert_false(Bool(cache.get("a", 2 * SECOND)))
    assert_equal(len(cache), 1)
    assert_true(Bool(cache.get("b", 1000 * SECOND)))


def test_delete_keeps_the_order() raises:
    var cache = InMemoryLRUCache[String](100)
    cache.set("a", "1", 1, 0)
    cache.set("b", "2", 1, 0)
    cache.set("c", "3", 1, 0)
    cache.set("d", "4", 1, 0)
    assert_true(cache.delete("b"))
    assert_false(cache.delete("b"))
    assert_true(cache.delete("d"))
    assert_equal(len(cache), 2)
    # The order is still a, then c: a goes first.
    cache.max_size = 2
    cache.set("e", "5", 1, 0)
    assert_false(_has(cache, "a"))
    assert_true(_has(cache, "c"))
    assert_true(_has(cache, "e"))
    _ = cache.get("c", 0)
    assert_true(cache.delete("e"))
    assert_true(cache.delete("c"))
    assert_equal(len(cache), 0)
    cache.set("f", "6", 1, 0)
    assert_equal(cache.get("f", 0).value(), "6")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the `Alt-Svc` parser and cache of `gql_http3.alt_svc`. There
is no upstream suite; the cases follow RFC 7838 section 3."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from gql_http3.alt_svc import AltService, AltSvcCache, parse_alt_svc


def test_write() raises:
    assert_equal(String(AltService("h", 443, 60)), 'h3="h:443"; ma=60')


def test_refused_entries() raises:
    var values: List[StaticString] = [
        'h3=":443',
        'h3=":"',
        'h3=":1234567890"',
        'h3=":70000"',
        'h3=":4x"',
        'h3=":4/"',
        "",
    ]
    var index = 0
    while index < len(values):
        assert_false(Bool(parse_alt_svc(values[index])))
        index += 1


def test_max_age() raises:
    assert_equal(parse_alt_svc('h3=":1"; ma=abc').value().max_age, 86400)
    assert_equal(parse_alt_svc('h3=":1"; v=2; ma=0').value().max_age, 0)


def test_cache_rules() raises:
    var cache = AltSvcCache()
    cache.remember("a", 'h3=":5"; ma=0', 1)
    assert_equal(len(cache), 0)
    cache.remember("a", 'h3=":5"', 1)
    cache.remember("b", 'h3=":6"', 1)
    assert_equal(cache.lookup("b", 2).value().port, 6)
    cache.forget("zzz")
    cache.forget("b")
    assert_equal(len(cache), 1)
    assert_false(Bool(cache.lookup("b", 2)))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

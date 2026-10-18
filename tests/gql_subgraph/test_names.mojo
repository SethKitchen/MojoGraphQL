# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the small types of `gql_subgraph`: `PrintMode`,
`FederationVersion`, and `locale_compare`, the name order of `_Entity`.

`@apollo/subgraph` 2.14.4 has no unit tests of these. `locale_compare`
gives the order of JavaScript `localeCompare`, which upstream uses to sort
the members of `_Entity`; `test_print_cases.mojo` checks the same order on
a whole subgraph.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_true
from gql_subgraph.printer import PrintMode
from gql_subgraph.spec import LATEST_MINOR, FederationVersion
from gql_subgraph.subgraph import locale_compare


def test_print_mode_names() raises:
    assert_equal(String(PrintMode.SDL), "SDL")
    assert_equal(String(PrintMode.SUBGRAPH), "SUBGRAPH")
    assert_equal(String(PrintMode.MERGED), "MERGED")
    assert_equal(String(PrintMode(9)), "<invalid>")
    assert_true(PrintMode.MERGED.is_valid())
    assert_false(PrintMode(3).is_valid())


def test_federation_versions() raises:
    assert_equal(String(FederationVersion.FED1), "v1")
    assert_equal(String(FederationVersion.v2(0)), "v2.0")
    assert_equal(String(FederationVersion.v2(LATEST_MINOR)), "v2.15")
    assert_true(FederationVersion.v2(LATEST_MINOR).is_valid())
    assert_false(FederationVersion(UInt8(LATEST_MINOR + 2)).is_valid())


def test_locale_compare() raises:
    assert_equal(locale_compare("a", "a"), 0)
    assert_true(locale_compare("_b", "b") < 0)
    assert_true(locale_compare("b", "B0") < 0)
    assert_true(locale_compare("B0", "b1") < 0)
    assert_true(locale_compare("b1", "B1") < 0)
    assert_true(locale_compare("bA", "Ba") < 0)
    assert_true(locale_compare("Ba", "bA") > 0)
    assert_true(locale_compare("ab", "a") > 0)
    assert_true(locale_compare("a", "ab") < 0)
    assert_true(locale_compare("AB", "ab") > 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

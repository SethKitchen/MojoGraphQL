# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the planner AST kinds and value printing.

Upstream `bin/router/src/query_planner/ast/` has no tests of its own for
these helpers. The expected texts are those of Rust `f64` `Display` and
of upstream `write_graphql_string_literal`.
"""

from gql_router.ast import (
    NONE,
    Cond,
    ItemKind,
    ValueKind,
    _rust_float_text,
    write_graphql_string,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_kinds_are_valid() raises:
    assert_true(ValueKind.OBJECT.is_valid())
    assert_false(ValueKind(9).is_valid())
    assert_true(ItemKind.ROOT.is_valid())
    assert_false(ItemKind(4).is_valid())


def test_cond() raises:
    assert_false(Cond.none().is_some())
    assert_true(Cond(1, NONE).is_some())
    assert_true(Cond(NONE, 1).is_some())


def test_float_text_matches_rust_display() raises:
    var nan = Float64(0.0) / Float64(0.0)
    assert_equal(_rust_float_text(nan), "NaN")
    assert_equal(_rust_float_text(Float64.MAX_FINITE * 2.0), "inf")
    assert_equal(_rust_float_text(-Float64.MAX_FINITE * 2.0), "-inf")
    assert_equal(_rust_float_text(0.0), "0")
    assert_equal(_rust_float_text(-0.0), "-0")
    assert_equal(_rust_float_text(1.5), "1.5")
    assert_equal(_rust_float_text(-2.5), "-2.5")
    assert_equal(_rust_float_text(5.0), "5")
    assert_equal(_rust_float_text(0.5), "0.5")
    assert_equal(_rust_float_text(0.001), "0.001")
    assert_equal(_rust_float_text(12.25), "12.25")
    assert_equal(_rust_float_text(1e21), "1000000000000000000000")
    assert_equal(_rust_float_text(1.5e-7), "0.00000015")


def test_graphql_string_escapes() raises:
    var out = String()
    var text = String('a"\\\n\r\t') + chr(8) + chr(12) + chr(1) + chr(127) + "é"
    write_graphql_string(out, text)
    assert_equal(out, '"a\\"\\\\\\n\\r\\t\\b\\f\\u0001\\u007fé"')


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

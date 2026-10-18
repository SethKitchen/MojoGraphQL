# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_mcp.text_analysis`.

The upstream tests of `expand_identifiers` are in
`crates/apollo-schema-index/src/lib.rs` and are ported in
`test_schema_index.mojo`. The expected values here come from the upstream
code itself, run with heck 0.5.0, Rust `str::to_lowercase`, Rust
`char::is_alphanumeric` and rust-stemmers 1.2.0.
"""

from gql_mcp.text_analysis import (
    analyze,
    expand_identifiers,
    is_alphanumeric,
    is_lowercase,
    is_uppercase,
    to_lowercase,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _c(value: Int) -> UInt32:
    return UInt32(value)


def test_alphanumeric() raises:
    assert_true(is_alphanumeric(_c(ord("5"))))
    assert_true(is_alphanumeric(_c(ord("A"))))
    assert_true(is_alphanumeric(_c(ord("a"))))
    assert_false(is_alphanumeric(_c(ord("-"))))
    assert_false(is_alphanumeric(_c(ord("_"))))
    assert_true(is_alphanumeric(0xAA))
    assert_false(is_alphanumeric(0xA9))
    assert_true(is_alphanumeric(0xC9))
    assert_false(is_alphanumeric(0xD7))
    assert_false(is_alphanumeric(0x2014))
    assert_false(is_alphanumeric(0x1F600))
    assert_true(is_alphanumeric(0x4E2D))
    assert_false(is_alphanumeric(0xFE0F))


def test_case() raises:
    assert_true(is_uppercase(_c(ord("A"))))
    assert_false(is_uppercase(_c(ord("a"))))
    assert_true(is_lowercase(_c(ord("a"))))
    assert_false(is_lowercase(_c(ord("1"))))
    assert_equal(to_lowercase(_c(ord("Q"))), UInt32(_c(ord("q"))))
    assert_equal(to_lowercase(_c(ord("q"))), UInt32(_c(ord("q"))))
    assert_equal(to_lowercase(0xC9), 0xE9)
    assert_equal(to_lowercase(0x100), 0x101)
    assert_equal(to_lowercase(0x101), 0x101)
    assert_true(is_lowercase(0x101))
    assert_equal(to_lowercase(0x139), 0x13A)
    assert_equal(to_lowercase(0x13A), 0x13A)
    assert_true(is_lowercase(0x13A))
    assert_equal(to_lowercase(0x178), 0xFF)
    assert_equal(to_lowercase(0x3A3), 0x3C3)
    assert_equal(to_lowercase(0x410), 0x430)
    assert_equal(to_lowercase(0x401), 0x451)
    assert_true(is_lowercase(0x138))
    assert_true(is_lowercase(0xE9))
    assert_false(is_lowercase(0x4E2D))
    assert_false(is_uppercase(0x4E2D))


def test_expand_identifiers() raises:
    assert_equal(expand_identifiers("ΣΑΣ"), "σας")
    assert_equal(expand_identifiers("été2024Test"), "été2024 test")
    assert_equal(expand_identifiers("ÉtéTest"), "été test")
    assert_equal(expand_identifiers("fooΣ"), "foo ς")
    assert_equal(expand_identifiers("abcDEF"), "abc def")
    assert_equal(expand_identifiers("ABCdef"), "ab cdef")
    assert_equal(expand_identifiers("a1B2"), "a1 b2")
    assert_equal(expand_identifiers("x"), "x")
    assert_equal(expand_identifiers("__typename"), "typename")
    assert_equal(expand_identifiers("_"), "")
    assert_equal(expand_identifiers(""), "")
    assert_equal(expand_identifiers("Ab_Cd"), "ab cd")
    assert_equal(expand_identifiers("HTTPRequestID"), "http request id")
    assert_equal(expand_identifiers("ĀāĹĺŸ"), "āā ĺĺ ÿ")
    assert_equal(expand_identifiers("ЁжИк"), "ёж ик")
    assert_equal(expand_identifiers("中文Name"), "中文name")
    assert_equal(expand_identifiers("ΑΣ1"), "ασ1")
    assert_equal(expand_identifiers("1Σ"), "1ς")
    assert_equal(
        expand_identifiers("Hello, WORLD’s cafés — Running!"),
        "hello, world’s cafés — running!",
    )
    assert_equal(expand_identifiers("über_Größe"), "über größe")


def _joined(terms: List[String]) -> String:
    var out = String()
    for term in terms:
        out += "[" + term + "]"
    return out^


def test_analyze() raises:
    assert_equal(
        _joined(analyze("Hello, WORLD’s cafés — Running!")),
        "[hello][world][s][café][run]",
    )
    assert_equal(_joined(analyze("über_Größe")), "[über][größe]")
    assert_equal(
        _joined(analyze("ΑΣ1 ΣΑ ΑΣ ΑΣΑ Σ aΣ ΣΣ 1Σ")),
        "[ας1][σα][ας][ασα][σ][aς][σς][1σ]",
    )
    assert_equal(_joined(analyze("")), "")
    assert_equal(_joined(analyze("  --  ")), "")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

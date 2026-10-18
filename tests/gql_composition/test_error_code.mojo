# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_composition.error_code`.

Upstream has no test file for the error codes. The codes are the
`extensions.code` strings of Hive Federation Composition v0.27.0.
"""

from gql_composition.error_code import CompositionError, ErrorCode
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_codes() raises:
    assert_equal(ErrorCode.NONE.text(), "")
    assert_equal(String(ErrorCode.INVALID_GRAPHQL), "INVALID_GRAPHQL")
    assert_equal(String(ErrorCode.EXTERNAL_UNUSED), "EXTERNAL_UNUSED")
    assert_true(ErrorCode(82).is_valid())
    assert_equal(
        String(ErrorCode.SATISFIABILITY_ERROR),
        "SATISFIABILITY_ERROR",
    )
    assert_false(ErrorCode(83).is_valid())
    assert_equal(ErrorCode(83).text(), "<invalid>")


def test_extensions() raises:
    assert_equal(
        CompositionError(
            "m", ErrorCode.INVALID_GRAPHQL, String('a"b')
        ).to_json_extensions(),
        '{"code":"INVALID_GRAPHQL","subgraphName":"a\\"b"}',
    )
    assert_equal(
        CompositionError(
            "m", ErrorCode.INVALID_GRAPHQL, None
        ).to_json_extensions(),
        '{"code":"INVALID_GRAPHQL"}',
    )
    assert_equal(
        CompositionError("m", ErrorCode.NONE, String("a")).to_json_extensions(),
        '{"subgraphName":"a"}',
    )
    assert_equal(
        CompositionError("m", ErrorCode.NONE, None).to_json_extensions(), ""
    )


def test_write_to() raises:
    assert_equal(
        String(CompositionError("[a] m", ErrorCode.INVALID_GRAPHQL, None)),
        "[INVALID_GRAPHQL] [a] m",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

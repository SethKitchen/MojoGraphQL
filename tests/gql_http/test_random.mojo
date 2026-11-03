# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of gql_http.random. There is no upstream suite."""

from std.testing import TestSuite, assert_equal, assert_true

from gql_http.random import ENTROPY_CALL_MAX, random_bytes, random_u64


def _nonzero(bytes: List[UInt8]) -> Int:
    """Return the number of bytes that are not 0."""
    var count = 0
    for byte in bytes:
        if byte != 0:
            count += 1
    return count


def test_random_bytes_length() raises:
    assert_equal(len(random_bytes(0)), 0)
    assert_equal(len(random_bytes(1)), 1)
    assert_equal(len(random_bytes(32)), 32)


def test_random_bytes_more_than_one_call() raises:
    # 600 bytes take three getentropy calls: 256, 256 and 88.
    var bytes = random_bytes(2 * ENTROPY_CALL_MAX + 88)
    assert_equal(len(bytes), 600)
    # Each call fills its part. The chance that a random part of 88 bytes
    # has fewer than 40 bytes that are not 0 is negligible.
    var tail = List[UInt8]()
    for index in range(512, 600):
        tail.append(bytes[index])
    assert_true(_nonzero(tail) > 40)
    assert_true(_nonzero(bytes) > 500)


def test_random_bytes_differ_each_call() raises:
    var first = random_bytes(16)
    var second = random_bytes(16)
    assert_true(first != second)


def test_random_u64_differs_each_call() raises:
    var a = random_u64()
    var b = random_u64()
    var c = random_u64()
    assert_true(a != b or b != c)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

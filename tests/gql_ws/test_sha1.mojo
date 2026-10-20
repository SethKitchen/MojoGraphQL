# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_ws.sha1`: the FIPS 180-4 examples of SHA-1, and the RFC
4648 section 10 vectors of base64."""

from gql_ws.sha1 import base64_encode, base64_value, sha1
from std.testing import TestSuite, assert_equal


def hex(digest: Array[UInt8, 20]) -> String:
    var digits = "0123456789abcdef"
    var out = String()
    var index = 0
    while index < 20:
        out += digits[byte=Int(digest[index] >> 4)]
        out += digits[byte=Int(digest[index] & 15)]
        index += 1
    return out^


def digest(text: StringSlice) -> String:
    return hex(sha1(text.as_bytes()))


def test_sha1_vectors() raises:
    assert_equal(digest(""), "da39a3ee5e6b4b0d3255bfef95601890afd80709")
    assert_equal(digest("abc"), "a9993e364706816aba3e25717850c26c9cd0d89d")
    assert_equal(
        digest("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"),
        "84983e441c3bd26ebaae4aa1f95129e5e54670f1",
    )


def test_sha1_lengths() raises:
    # 55 bytes fit one padded block; 56 need two; 64 is one whole block.
    var a55 = String("a") * 55
    var a56 = String("a") * 56
    var a64 = String("a") * 64
    assert_equal(digest(a55), "c1c8bbdc22796e28c0e15163d20899b65621d65a")
    assert_equal(digest(a56), "c2db330f6083854c99d4b5bfb6e8f29f201be699")
    assert_equal(digest(a64), "0098ba824b5c16427bd7a1122a5a442a25ec644d")
    assert_equal(
        digest("The quick brown fox jumps over the lazy dog"),
        "2fd4e1c67a2d28fced849ee1bb76e7391b93eb12",
    )


def test_base64_vectors() raises:
    assert_equal(base64_encode("".as_bytes()), "")
    assert_equal(base64_encode("f".as_bytes()), "Zg==")
    assert_equal(base64_encode("fo".as_bytes()), "Zm8=")
    assert_equal(base64_encode("foo".as_bytes()), "Zm9v")
    assert_equal(base64_encode("foob".as_bytes()), "Zm9vYg==")
    assert_equal(base64_encode("fooba".as_bytes()), "Zm9vYmE=")
    assert_equal(base64_encode("foobar".as_bytes()), "Zm9vYmFy")
    var high = List[UInt8]()
    high.append(0xFB)
    high.append(0xFF)
    assert_equal(base64_encode(high), "+/8=")


def test_base64_value() raises:
    assert_equal(base64_value(65), 0)
    assert_equal(base64_value(90), 25)
    assert_equal(base64_value(97), 26)
    assert_equal(base64_value(122), 51)
    assert_equal(base64_value(48), 52)
    assert_equal(base64_value(57), 61)
    assert_equal(base64_value(43), 62)
    assert_equal(base64_value(47), 63)
    assert_equal(base64_value(61), -1)
    assert_equal(base64_value(0), -1)
    assert_equal(base64_value(91), -1)
    assert_equal(base64_value(123), -1)
    assert_equal(base64_value(58), -1)
    assert_equal(base64_value(255), -1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `gql_server.sha256`: the FIPS 180-4 examples, and messages at
each padding boundary. The expected digests come from Node.js
`createHash('sha256')`, which Apollo Server 5.5.1 uses for query hashes.
"""

from std.testing import TestSuite, assert_equal
from gql_server.sha256 import sha256, sha256_hex


def test_fips_examples() raises:
    assert_equal(
        sha256_hex("abc"),
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
    )
    assert_equal(
        sha256_hex("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"),
        "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1",
    )
    assert_equal(
        sha256_hex(""),
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    )


def test_padding_boundaries() raises:
    assert_equal(
        sha256_hex("a" * 55),
        "9f4390f8d30c2dd92ec9f095b65e2b9ae9b0a925a5258e241c9f1e910f734318",
    )
    assert_equal(
        sha256_hex("a" * 56),
        "b35439a4ac6f0948b6d6f9e3c6af0f5f590ce20f1bde7090ef7970686ec6738a",
    )
    assert_equal(
        sha256_hex("a" * 64),
        "ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb",
    )
    assert_equal(
        sha256_hex("a" * 119),
        "31eba51c313a5c08226adf18d4a359cfdfd8d2e816b13f4af952f7ea6584dcfb",
    )


def test_utf8() raises:
    assert_equal(
        sha256_hex("héllo ✓"),
        "5657cdef8a85a584e0e961e6f8247cf5d3f8ed21496ed6fdbcfd43a761e94245",
    )
    assert_equal(len(sha256(StaticString("abc").as_bytes())), 32)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

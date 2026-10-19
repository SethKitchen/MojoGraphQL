# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_quic.error`.

Upstream: quinn-proto 0.11.19 (8192ed3) quinn-proto/src/transport_error.rs
has no unit tests. The values are the values of RFC 9000 section 20.1.
"""

from gql_quic.error import NO_FRAME, QuicError, TransportErrorCode
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_codes() raises:
    assert_equal(TransportErrorCode.NO_ERROR.value, 0)
    assert_equal(TransportErrorCode.FRAME_ENCODING_ERROR.value, 7)
    assert_equal(TransportErrorCode.PROTOCOL_VIOLATION.value, 0xA)
    assert_equal(TransportErrorCode.NO_VIABLE_PATH.value, 0x10)
    for v in [0, 1, 0xA, 0x10, 0x100, 0x12A, 0x1FF]:
        assert_true(TransportErrorCode(UInt64(v)).is_valid(), String(v))
    for v in [0x11, 0xFF, 0x200, 0x4000]:
        assert_false(TransportErrorCode(UInt64(v)).is_valid(), String(v))


def test_crypto() raises:
    var code = TransportErrorCode.crypto(0x2A)
    assert_equal(code.value, 0x12A)
    assert_true(code.is_crypto())
    assert_false(TransportErrorCode.NO_VIABLE_PATH.is_crypto())
    assert_false(TransportErrorCode(0x200).is_crypto())
    assert_equal(String(code), "crypto(0x2a)")


def test_names() raises:
    assert_equal(String(TransportErrorCode.NO_ERROR), "NO_ERROR")
    assert_equal(
        String(TransportErrorCode.TRANSPORT_PARAMETER_ERROR),
        "TRANSPORT_PARAMETER_ERROR",
    )
    assert_equal(String(TransportErrorCode.NO_VIABLE_PATH), "NO_VIABLE_PATH")
    assert_equal(String(TransportErrorCode(0x11)), "unknown(0x11)")
    assert_equal(TransportErrorCode(0x11).text(), "invalid")
    assert_equal(TransportErrorCode.INVALID_TOKEN.text(), "INVALID_TOKEN")


def test_error() raises:
    var e = QuicError(TransportErrorCode.PROTOCOL_VIOLATION, "bad")
    assert_false(e.has_frame())
    assert_equal(e.frame_type, NO_FRAME)
    assert_equal(String(e), "PROTOCOL_VIOLATION: bad")
    var f = QuicError(TransportErrorCode.FRAME_ENCODING_ERROR, 0x8, "offset")
    assert_true(f.has_frame())
    assert_equal(String(f), "FRAME_ENCODING_ERROR in 0x8: offset")
    var g = QuicError(TransportErrorCode.NO_ERROR, "")
    assert_equal(String(g), "NO_ERROR")
    assert_true(f.copy().code == TransportErrorCode.FRAME_ENCODING_ERROR)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

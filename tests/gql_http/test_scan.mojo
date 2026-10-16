# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_http.scan`: the byte classes of RFC 9110 and RFC 3986,
checked for all 256 bytes, and the SIMD scanners, with the byte they look
for in the vector part, in the tail, and absent."""

from gql_http.scan import (
    WIDTH,
    equals_ignore_case,
    equals_lower,
    find_byte,
    find_field_end,
    find_target_end,
    is_field_byte,
    is_host_byte,
    is_tchar,
    lower,
    move_down,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _alnum(byte: Int) -> Bool:
    return (
        (byte >= 48 and byte <= 57)
        or (byte >= 65 and byte <= 90)
        or (byte >= 97 and byte <= 122)
    )


def _one_of(byte: Int, chars: StaticString) -> Bool:
    for c in chars.as_bytes():
        if Int(c) == byte:
            return True
    return False


def test_byte_classes() raises:
    for byte in range(256):
        var b = UInt8(byte)
        var tchar = _alnum(byte) or _one_of(byte, "!#$%&'*+-.^_`|~")
        assert_equal(is_tchar(b), tchar, String(byte))
        var host = _alnum(byte) or _one_of(byte, "-._~!$&'()*+,;=%:[]")
        assert_equal(is_host_byte(b), host, String(byte))
        var field = (byte >= 32 and byte != 127) or byte == 9
        assert_equal(is_field_byte(b), field, String(byte))
        var folded = byte + 32 if byte >= 65 and byte <= 90 else byte
        assert_equal(Int(lower(b)), folded, String(byte))


def _buffer(n: Int, at: Int, byte: UInt8) -> List[UInt8]:
    """Return `n` bytes of `a`, with `byte` at `at` when `at` is in range."""
    var out = List[UInt8](length=n, fill=97)
    if at >= 0 and at < n:
        out[at] = byte
    return out^


def test_find_field_end() raises:
    var n = 2 * WIDTH + 5
    for bad in [UInt8(0), UInt8(10), UInt8(13), UInt8(31), UInt8(127)]:
        for at in [3, WIDTH + 1, 2 * WIDTH + 2]:
            var data = _buffer(n, at, bad)
            assert_equal(find_field_end(data.unsafe_ptr(), 0, n), at)
    var tab = _buffer(n, 4, 9)
    tab[2 * WIDTH + 1] = 255
    assert_equal(find_field_end(tab.unsafe_ptr(), 0, n), n)
    var short = _buffer(4, 9, 0)
    assert_equal(find_field_end(short.unsafe_ptr(), 1, 4), 4)


def test_find_target_end() raises:
    var n = 2 * WIDTH + 5
    for bad in [UInt8(32), UInt8(0), UInt8(127), UInt8(200)]:
        for at in [3, WIDTH + 1, 2 * WIDTH + 2]:
            var data = _buffer(n, at, bad)
            assert_equal(find_target_end(data.unsafe_ptr(), 0, n), at)
    var visible = _buffer(n, 5, 33)
    visible[2 * WIDTH + 1] = 126
    assert_equal(find_target_end(visible.unsafe_ptr(), 0, n), n)


def test_find_byte() raises:
    var n = 2 * WIDTH + 5
    for at in [0, WIDTH + 1, 2 * WIDTH + 4]:
        var data = _buffer(n, at, 58)
        assert_equal(find_byte(data.unsafe_ptr(), 0, n, 58), at)
    var none = _buffer(n, -1, 0)
    assert_equal(find_byte(none.unsafe_ptr(), 0, n, 58), n)
    assert_equal(find_byte(none.unsafe_ptr(), 3, 3, 97), 3)


def test_move_down() raises:
    var n = 3 * WIDTH + 7
    var data = List[UInt8](capacity=n)
    for index in range(n):
        data.append(UInt8(index))
    move_down(data.unsafe_ptr(), 0, 5, n - 5)
    for index in range(n - 5):
        assert_equal(Int(data[index]), index + 5)
    var same = List[UInt8](length=4, fill=7)
    move_down(same.unsafe_ptr(), 1, 1, 0)
    assert_equal(Int(same[1]), 7)


def test_case_folding() raises:
    var a = StaticString("Content-Length").as_bytes()
    assert_true(
        equals_ignore_case(a, StaticString("content-LENGTH").as_bytes())
    )
    assert_false(
        equals_ignore_case(a, StaticString("content-lengtx").as_bytes())
    )
    assert_false(equals_ignore_case(a, StaticString("content").as_bytes()))
    assert_true(
        equals_ignore_case(
            StaticString("").as_bytes(), StaticString("").as_bytes()
        )
    )
    var text = StaticString("xxKeep-Alivexx").as_bytes()
    var p = text.unsafe_ptr()
    assert_true(equals_lower(p, 2, 12, "keep-alive"))
    assert_false(equals_lower(p, 2, 12, "keep-alivf"))
    assert_false(equals_lower(p, 2, 11, "keep-alive"))
    assert_true(equals_lower(p, 2, 2, ""))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

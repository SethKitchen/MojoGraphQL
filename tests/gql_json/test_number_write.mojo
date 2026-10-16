# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_json.number` writing, against Node.js 22.14.0.

`fixtures/numbers.txt` has one line per `Float64`: its 64 bits in hex,
then `JSON.stringify` of it; see `fixtures/README.md`. `write_number` must
give the same text. `test_number.mojo` reads the same file back.
"""

from std.memory import bitcast
from std.testing import TestSuite, assert_equal, assert_true

from _fixtures import read_fixture
from gql_json.number import write_int, write_number


def _hex(text: StringSlice) -> UInt64:
    var bits = UInt64(0)
    for byte in text.as_bytes():
        var digit = UInt64(byte - 48) if byte < 58 else UInt64(byte - 87)
        bits = bits * 16 + digit
    return bits


def _number(value: Float64) -> String:
    var out = List[UInt8]()
    write_number(out, value)
    return String(unsafe_from_utf8=out^)


def test_write_number_matches_node() raises:
    var text = String(unsafe_from_utf8=read_fixture("numbers.txt"))
    var count = 0
    for line in text.splitlines():
        var parts = line.split(" ")
        var value = bitcast[DType.float64](_hex(parts[0]))
        assert_equal(_number(value), String(parts[1]), String(parts[0]))
        count += 1
    assert_true(count > 2000)


def test_write_int() raises:
    var out = List[UInt8]()
    write_int(out, 0)
    out.append(UInt8(ord(" ")))
    write_int(out, -5)
    out.append(UInt8(ord(" ")))
    write_int(out, Int64.MAX)
    out.append(UInt8(ord(" ")))
    write_int(out, Int64.MIN)
    assert_equal(
        String(unsafe_from_utf8=out^),
        "0 -5 9223372036854775807 -9223372036854775808",
    )


def test_write_number_special_values() raises:
    var zero: Float64 = 0.0
    assert_equal(_number(zero / zero), "null")
    assert_equal(_number(1.0 / zero), "null")
    assert_equal(_number(-1.0 / zero), "null")
    assert_equal(_number(-0.0), "0")
    assert_equal(_number(-1.5), "-1.5")
    assert_equal(_number(1e21), "1e+21")
    assert_equal(_number(1e-7), "1e-7")
    assert_equal(_number(1.5e-7), "1.5e-7")
    assert_equal(_number(0.000001), "0.000001")
    assert_equal(_number(123e20), "1.23e+22")
    assert_equal(_number(9007199254740992.0), "9007199254740992")
    assert_equal(_number(-9007199254740994.0), "-9007199254740994")


def test_write_number_shortest_digits() raises:
    # Two shortest candidates, the value exactly between them: the even
    # digit wins.
    assert_equal(_number(614048859500263.25), "614048859500263.2")
    assert_equal(_number(614048859500263.75), "614048859500263.8")
    # A power of two has a narrower gap below it.
    assert_equal(_number(0.5), "0.5")
    assert_equal(_number(1152921504606846976.0), "1152921504606847000")
    # The smallest normal value is a power of two with the regular gap.
    assert_equal(_number(2.2250738585072014e-308), "2.2250738585072014e-308")
    # Subnormal values: one digit is the shortest form.
    assert_equal(_number(5e-324), "5e-324")
    assert_equal(_number(1e-323), "1e-323")
    assert_equal(_number(1.5e-323), "1.5e-323")
    assert_equal(_number(1e23), "1e+23")
    assert_equal(_number(9.5e-7), "9.5e-7")
    assert_equal(_number(123456789012345680000.0), "123456789012345680000")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

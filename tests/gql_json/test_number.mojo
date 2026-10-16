# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_json.number` reading, against Node.js 22.14.0.

`fixtures/numbers.txt` has one line per `Float64`: its 64 bits in hex,
then `JSON.stringify` of it. Node.js wrote it once from edge cases, 1000
random bit patterns and 1000 random decimals; see `fixtures/README.md`.
`read_float64` must read the text back to the same bits, as `JSON.parse`
does. `test_number_write.mojo` checks `write_number` on the same file.
"""

from std.memory import bitcast
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _fixtures import read_fixture
from gql_json.number import (
    IntStatus,
    is_integer_text,
    read_float64,
    read_int64,
)


def _hex(text: StringSlice) -> UInt64:
    var bits = UInt64(0)
    for byte in text.as_bytes():
        var digit = UInt64(byte - 48) if byte < 58 else UInt64(byte - 87)
        bits = bits * 16 + digit
    return bits


def _read(text: StringSlice) -> Float64:
    return read_float64(text.as_bytes())


def _bits(value: Float64) -> UInt64:
    return bitcast[DType.uint64](value)


def test_read_float64_matches_node() raises:
    var text = String(unsafe_from_utf8=read_fixture("numbers.txt"))
    for line in text.splitlines():
        var parts = line.split(" ")
        if parts[1] == "null":
            continue
        var bits = _hex(parts[0])
        var got = _bits(_read(parts[1]))
        # -0 prints as 0, which reads back as +0.
        if bits == UInt64(1) << 63:
            bits = 0
        assert_equal(got, bits, String(parts[1]))


def test_read_float64_edge_cases() raises:
    assert_equal(_read("0"), 0.0)
    assert_equal(_bits(_read("-0")), UInt64(1) << 63)
    assert_equal(_bits(_read("-0.0e5")), UInt64(1) << 63)
    assert_equal(_read("1.5"), 1.5)
    assert_equal(_read("-2.5E+2"), -250.0)
    assert_equal(_read("1e22"), 1e22)
    assert_equal(_read("1e23"), 1e23)
    assert_equal(_read("1e-22"), 1e-22)
    # More than 15 digits, and trailing zeros the fast path counts.
    assert_equal(_read("1.000000000000000000"), 1.0)
    assert_equal(_read("12345678901234567890"), 12345678901234567890.0)
    # Ties go to the even significand.
    assert_equal(_read("9007199254740993"), 9007199254740992.0)
    assert_equal(_read("9007199254740995"), 9007199254740996.0)
    assert_equal(
        _read("1.00000000000000011102230246251565404236316680908203125"), 1.0
    )
    assert_equal(
        _read("1.00000000000000011102230246251565404236316680908203126"),
        1.0000000000000002,
    )
    # Rounding up carries into the next power of two.
    assert_equal(_read("18014398509481983"), 18014398509481984.0)
    # The largest value, and the first text that rounds to infinity.
    assert_equal(_read("1.7976931348623157e308"), 1.7976931348623157e308)
    assert_equal(_read("1.7976931348623159e308"), _read("1e400"))
    assert_true(_read("1e400") > 1.7976931348623157e308)
    assert_true(_read("-1e400") < -1.7976931348623157e308)
    # The subnormal range, and below half of the smallest subnormal.
    assert_equal(_read("2.4703282292062328e-324"), 5e-324)
    assert_equal(_read("2.4703282292062327e-324"), 0.0)
    assert_equal(_read("1e-330"), 0.0)
    assert_equal(_read("1e-400"), 0.0)
    assert_equal(_read("2.2250738585072011e-308"), 2.225073858507201e-308)
    # A huge exponent is clamped, not overflowed.
    assert_true(_read("1e99999999999999999999") > 1e308)
    assert_equal(_read("1e-99999999999999999999"), 0.0)
    assert_equal(_read("0e99999999999999999999"), 0.0)


def test_read_float64_keeps_a_sticky_digit() raises:
    # 900 digits: the digits after the first 800 only round.
    var text = String("1.") + "0" * 898 + "1"
    assert_equal(_read(text), 1.0)
    var tie = String("9007199254740993.") + "0" * 790 + "1"
    assert_equal(_read(tie), 9007199254740994.0)
    var zeros = String("9007199254740993.") + "0" * 900
    assert_equal(_read(zeros), 9007199254740992.0)
    assert_true(_read(String("1") * 400) > 1e308)


def test_read_int64() raises:
    var texts: List[String] = [
        "0",
        "-0",
        "123",
        "-45",
        "1.0",
        "1e2",
        "1E+2",
        "0.5e1",
        "120e-1",
        "9223372036854775807",
        "-9223372036854775808",
        "0.0e-5",
    ]
    var values: List[Int64] = [
        0,
        0,
        123,
        -45,
        1,
        100,
        100,
        5,
        12,
        Int64.MAX,
        Int64.MIN,
        0,
    ]
    for index in range(len(texts)):
        var result = read_int64(texts[index].as_bytes())
        assert_equal(result[1], IntStatus.OK, texts[index])
        assert_equal(result[0], values[index], texts[index])


def test_read_int64_refuses_a_fraction_or_an_overflow() raises:
    var fractions: List[String] = ["1.5", "1e-1", "15e-1", "0.001"]
    for text in fractions:
        var result = read_int64(text.as_bytes())
        assert_equal(result[1], IntStatus.FRACTION, text)
        assert_equal(result[0], 0)
    var overflows: List[String] = [
        "9223372036854775808",
        "-9223372036854775809",
        "9999999999999999999",
        "10000000000000000000",
        "1e19",
        "1e400",
        String("1") * 900,
    ]
    for text in overflows:
        assert_equal(read_int64(text.as_bytes())[1], IntStatus.OVERFLOW, text)
    # 900 digits with a fraction is a fraction, not an overflow.
    var long_fraction = String("1") * 900 + "e-950"
    assert_equal(read_int64(long_fraction.as_bytes())[1], IntStatus.FRACTION)


def test_is_integer_text() raises:
    var integers: List[String] = ["0", "-0", "1.0", "1e400", "150e-1", "0e-9"]
    for text in integers:
        assert_true(is_integer_text(text.as_bytes()), text)
    var fractions: List[String] = ["1.5", "15e-1", "1e-400", "0.1"]
    for text in fractions:
        assert_false(is_integer_text(text.as_bytes()), text)


def test_int_status() raises:
    assert_true(IntStatus.OK.is_valid())
    assert_true(IntStatus.OVERFLOW.is_valid())
    assert_false(IntStatus(3).is_valid())
    assert_equal(String(IntStatus.OK), "ok")
    assert_equal(String(IntStatus.FRACTION), "fraction")
    assert_equal(String(IntStatus.OVERFLOW), "overflow")
    assert_equal(String(IntStatus(9)), "<invalid>")


def test_read_float64_paths() raises:
    # Clinger: at most 15 digits and a power of ten from -22 to 22.
    assert_equal(_read("0.05"), 0.05)
    assert_equal(_read("10"), 10.0)
    assert_equal(_read("1e-22"), 1e-22)
    assert_equal(_read("1e30"), 1e30)
    assert_equal(_read("1e-30"), 1e-30)
    # Eisel-Lemire: up to 19 digits, any power in the table.
    assert_equal(_read("0.30000000000000004"), 0.30000000000000004)
    assert_equal(_read("1.2345678901234567e-300"), 1.2345678901234567e-300)
    assert_equal(_read("9999999999999999999"), 1e19)
    # Outside the table: an infinity, or a zero.
    assert_true(_read("1.2345678901234567e400") > 1.7976931348623157e308)
    assert_equal(_read("1.2345678901234567e-400"), 0.0)
    # A subnormal result takes the exact path.
    assert_equal(_read("1.2345678901234567e-310"), 1.2345678901234567e-310)
    # More than 19 digits takes the exact path.
    assert_equal(_read("0.10000000000000000000000"), 0.1)
    assert_equal(_read("100000000000000000000"), 1e20)
    assert_equal(_read("0.00000000000000000000000"), 0.0)
    # An exact tie on the exact path goes to the even significand.
    assert_equal(
        _read("9007199254740995.00000000000000000000"), 9007199254740996.0
    )
    assert_equal(
        _read("9007199254740993.00000000000000000000"), 9007199254740992.0
    )
    assert_equal(_bits(_read("-0.00000000000000000000000")), UInt64(1) << 63)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

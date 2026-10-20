# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_ws.frame` and `gql_ws.utf8`.

Ported from tungstenite 0.30.0 `src/protocol/frame/frame.rs` (`parse`,
`format`), `coding.rs` (`opcode_from_u8`, `closecode_from_u16`) and
`mask.rs` (`test_apply_mask`), with the UTF-8 cases of Autobahn section
6 and the Markus Kuhn decoder test.
"""

from gql_ws.frame import (
    CloseCode,
    FrameHeader,
    HeaderState,
    MAX_HEADER_SIZE,
    OpCode,
    apply_mask,
    header_size,
    parse_header,
    random_mask,
    write_header,
)
from gql_ws.utf8 import Utf8Validator, is_utf8
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def bytes(*values: Int) -> List[UInt8]:
    var out = List[UInt8]()
    for value in values:
        out.append(UInt8(value))
    return out^


def parse(data: List[UInt8]) -> FrameHeader:
    return parse_header(data.unsafe_ptr(), 0, len(data))


def test_parse() raises:
    var raw = bytes(0x82, 0x07, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07)
    var header = parse(raw)
    assert_true(header.state == HeaderState.COMPLETE)
    assert_equal(Int(header.length), 7)
    assert_equal(header.size, 2)
    assert_true(header.is_final)
    assert_true(header.opcode == OpCode.BINARY)
    assert_false(header.masked)


def test_parse_incomplete() raises:
    assert_true(parse(bytes(0x81)).state == HeaderState.INCOMPLETE)
    assert_true(parse(bytes(0x81, 126, 0)).state == HeaderState.INCOMPLETE)
    assert_true(
        parse(bytes(0x81, 127, 0, 0, 0)).state == HeaderState.INCOMPLETE
    )
    assert_true(
        parse(bytes(0x81, 0x85, 1, 2, 3)).state == HeaderState.INCOMPLETE
    )


def test_parse_lengths_and_mask() raises:
    var h16 = parse(bytes(0x01, 126, 0x01, 0x00))
    assert_true(h16.state == HeaderState.COMPLETE)
    assert_equal(Int(h16.length), 256)
    assert_equal(h16.size, 4)
    assert_false(h16.is_final)
    var h64 = parse(bytes(0x02, 127, 0, 0, 0, 0, 0, 1, 0, 0))
    assert_equal(Int(h64.length), 65536)
    assert_equal(h64.size, 10)
    var masked = parse(bytes(0x81, 0x85, 0x37, 0xFA, 0x21, 0x3D))
    assert_true(masked.masked)
    assert_equal(masked.size, 6)
    assert_equal(Int(masked.mask), 0x3D21FA37)
    var rsv = parse(bytes(0xF1, 0))
    assert_equal(Int(rsv.rsv), 0x70)


def test_parse_errors() raises:
    # A reserved opcode, as tungstenite `InvalidOpcode`.
    var reserved = parse(bytes(0x83, 0))
    assert_true(reserved.state == HeaderState.INVALID_OPCODE)
    assert_true(parse(bytes(0x8B, 0)).state == HeaderState.INVALID_OPCODE)
    # tungstenite `parse_overflow`: the length must not crash.
    var huge = parse(
        bytes(
            0x83,
            0xFF,
            0xFF,
            0xFF,
            0xFF,
            0xFF,
            0xFF,
            0xFF,
            0xFF,
            0xFF,
            0,
            0,
            0,
            0,
        )
    )
    assert_true(huge.state == HeaderState.INVALID_OPCODE)
    var top = parse(bytes(0x82, 127, 0x80, 0, 0, 0, 0, 0, 0, 0))
    assert_true(top.state == HeaderState.INVALID_LENGTH)


def test_format() raises:
    # tungstenite `format`: a ping with two bytes.
    var out = List[UInt8]()
    write_header(out, True, OpCode.PING, 2, False, 0)
    out.append(1)
    out.append(2)
    assert_true(out == bytes(0x89, 0x02, 0x01, 0x02))
    var mid = List[UInt8]()
    write_header(mid, False, OpCode.TEXT, 300, True, 0x04030201)
    assert_true(mid == bytes(0x01, 0xFE, 0x01, 0x2C, 1, 2, 3, 4))
    var big = List[UInt8]()
    write_header(big, True, OpCode.BINARY, 65536, False, 0)
    assert_true(big == bytes(0x82, 127, 0, 0, 0, 0, 0, 1, 0, 0))
    assert_equal(header_size(125, False), 2)
    assert_equal(header_size(126, False), 4)
    assert_equal(header_size(65535, True), 8)
    assert_equal(header_size(65536, True), MAX_HEADER_SIZE)


def test_round_trip() raises:
    var lengths = bytes(0, 1, 125, 126, 127)
    var index = 0
    while index < len(lengths):
        var length = Int(lengths[index]) * 600
        var out = List[UInt8]()
        write_header(out, True, OpCode.TEXT, length, True, 0xAABBCCDD)
        var header = parse(out)
        assert_equal(Int(header.length), length)
        assert_equal(header.size, len(out))
        assert_equal(Int(header.mask), 0xAABBCCDD)
        index += 1


def test_apply_mask() raises:
    # tungstenite `test_apply_mask`, at every length and offset, against
    # the byte-by-byte definition; and long enough for the wide path.
    var mask: UInt32 = 0x80B2B66D
    var key = bytes(0x6D, 0xB6, 0xB2, 0x80)
    var plain = List[UInt8]()
    var index = 0
    while index < 80:
        plain.append(UInt8((index * 37 + 11) & 0xFF))
        index += 1
    var length = 0
    while length <= len(plain):
        var off = 0
        while off <= 3:
            if off <= length:
                var data = plain.copy()
                apply_mask(data.unsafe_ptr(), off, length - off, mask)
                var at = 0
                while at < len(data):
                    var want = plain[at]
                    if at >= off and at < length:
                        want ^= key[(at - off) & 3]
                    assert_equal(data[at], want)
                    at += 1
            off += 1
        length += 1


def test_random_mask() raises:
    var a = random_mask()
    var b = random_mask()
    var c = random_mask()
    assert_true(a != b or b != c)


def test_opcode() raises:
    assert_equal(OpCode(2).text(), "BINARY")
    assert_equal(String(OpCode.TEXT), "TEXT")
    assert_equal(OpCode(0).text(), "CONTINUE")
    assert_equal(OpCode(8).text(), "CLOSE")
    assert_equal(OpCode(9).text(), "PING")
    assert_equal(OpCode(10).text(), "PONG")
    assert_equal(OpCode(3).text(), "RESERVED_DATA_3")
    assert_equal(OpCode(11).text(), "RESERVED_CONTROL_11")
    assert_true(OpCode.PONG.is_control())
    assert_false(OpCode.BINARY.is_control())
    assert_false(OpCode(7).is_valid())
    assert_false(OpCode(15).is_valid())


def test_close_code() raises:
    assert_true(CloseCode(1008) == CloseCode.POLICY)
    assert_equal(String(CloseCode.AWAY), "1001")
    assert_true(CloseCode.NORMAL.is_valid())
    assert_true(CloseCode(4999).is_valid())
    assert_false(CloseCode(999).is_valid())
    assert_false(CloseCode(5000).is_valid())
    # The allowed codes of tungstenite `is_allowed`, and Autobahn 7.9.
    var allowed: List[Int] = [
        1000,
        1001,
        1002,
        1003,
        1007,
        1008,
        1009,
        1010,
        1011,
        1012,
        1013,
        3000,
        3999,
        4000,
        4999,
    ]
    for code in allowed:
        assert_true(CloseCode(UInt16(code)).is_allowed(), String(code))
    var refused: List[Int] = [
        0,
        999,
        1004,
        1005,
        1006,
        1014,
        1015,
        1016,
        1100,
        2000,
        2999,
        5000,
        65535,
    ]
    for code in refused:
        assert_false(CloseCode(UInt16(code)).is_allowed(), String(code))


def test_states_valid() raises:
    assert_true(HeaderState.COMPLETE.is_valid())
    assert_false(HeaderState(4).is_valid())
    assert_equal(String(HeaderState.INVALID_LENGTH), "3")


def utf8(*values: Int) -> Bool:
    var data = List[UInt8]()
    for value in values:
        data.append(UInt8(value))
    return is_utf8(data)


def test_utf8_valid() raises:
    assert_true(is_utf8("".as_bytes()))
    assert_true(is_utf8("Hello-µ@ßöäüàá-UTF-8!!".as_bytes()))
    assert_true(is_utf8("κόσμε".as_bytes()))
    assert_true(utf8(0xF0, 0x90, 0x80, 0x80))
    assert_true(utf8(0xF4, 0x8F, 0xBF, 0xBF))
    assert_true(utf8(0xED, 0x9F, 0xBF))
    assert_true(utf8(0xE0, 0xA0, 0x80))
    assert_true(utf8(0xEF, 0xBF, 0xBF))
    assert_true(utf8(0xC2, 0x80))
    assert_true(utf8(0xF2, 0x80, 0x80, 0x80))
    var long = String("a") * 70 + "é" + String("b") * 40
    assert_true(is_utf8(long.as_bytes()))


def test_utf8_invalid() raises:
    assert_false(utf8(0x80))
    assert_false(utf8(0xC0, 0x80))
    assert_false(utf8(0xC1, 0xBF))
    assert_false(utf8(0xE0, 0x9F, 0xBF))
    assert_false(utf8(0xED, 0xA0, 0x80))
    assert_false(utf8(0xF0, 0x8F, 0xBF, 0xBF))
    assert_false(utf8(0xF4, 0x90, 0x80, 0x80))
    assert_false(utf8(0xF5, 0x80, 0x80, 0x80))
    assert_false(utf8(0xFF))
    assert_false(utf8(0xC2))
    assert_false(utf8(0xC2, 0x41))
    assert_false(utf8(0xC2, 0xC0))
    assert_false(utf8(0xE1, 0x80))


def test_utf8_fragments() raises:
    # A sequence that spans two fragments, as Autobahn 6.2.4.
    var text = "κόσμε".as_bytes()
    var validator = Utf8Validator()
    var data = List[UInt8](text)
    assert_true(validator.feed(data.unsafe_ptr(), 0, 3))
    assert_false(validator.is_complete())
    assert_true(validator.feed(data.unsafe_ptr(), 3, len(data)))
    assert_true(validator.is_complete())
    validator.reset()
    assert_true(validator.is_complete())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

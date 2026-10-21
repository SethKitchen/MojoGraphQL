# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_ws_http3.handshake`: SETTINGS_ENABLE_CONNECT_PROTOCOL and
the checks of the extended `CONNECT`.

The settings cases follow hyperium/h3 h3-v0.0.8 h3/src/config.rs
(`enable_extended_connect`, default off). The field cases follow RFC 9220
section 3 and RFC 8441 section 4.
"""

from gql_http2.hpack import HeaderList
from gql_http3.error import H3ErrorCode
from gql_http3.frame import (
    FrameType,
    SettingId,
    Settings,
    StreamType,
    parse_frame_head,
)
from gql_http3.qpack_field import FieldList
from gql_http3.varint import decode_varint
from gql_ws_http3.handshake import (
    allows_extended_connect,
    check_connect,
    control_preface,
    is_extended_connect,
    to_field_list,
    to_header_list,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_control_preface() raises:
    var out = control_preface(16384)
    var type = decode_varint(Span(out), 0)
    assert_equal(type.value, StreamType.CONTROL.value)
    var head = parse_frame_head(Span(out), type.end)
    assert_true(head.type == FrameType.SETTINGS)
    var settings = Settings.decode(
        Span(out)[head.payload_start : head.payload_end()]
    )
    assert_true(allows_extended_connect(settings))
    assert_equal(
        Int(settings.get_or(SettingId.MAX_FIELD_SECTION_SIZE, 0)), 16384
    )


def test_extended_connect_is_off_by_default() raises:
    assert_false(allows_extended_connect(Settings()))
    var zero = Settings()
    zero.insert(SettingId.ENABLE_CONNECT_PROTOCOL, 0)
    assert_false(allows_extended_connect(zero))


def _connect() -> FieldList:
    var fields = FieldList()
    fields.add_text(":method", "CONNECT")
    fields.add_text(":protocol", "websocket")
    fields.add_text(":scheme", "https")
    fields.add_text(":authority", "localhost")
    fields.add_text(":path", "/graphql")
    return fields^


def _code(fields: FieldList, enabled: Bool) -> Int:
    """The error code of `check_connect`, or 0."""
    try:
        check_connect(fields, enabled)
    except e:
        return Int(e.code.value)
    return 0


def _without(name: StringSlice) -> FieldList:
    """The extended CONNECT without one field."""
    var all = _connect()
    var fields = FieldList()
    var index = 0
    while index < all.count():
        if all.name_text(index) != name:
            fields.add(all.name(index), all.value(index))
        index += 1
    return fields^


def test_check_connect() raises:
    var fields = _connect()
    assert_true(is_extended_connect(fields))
    assert_equal(_code(fields, True), 0)
    var error = Int(H3ErrorCode.H3_MESSAGE_ERROR.value)
    assert_equal(_code(fields, False), error)
    assert_equal(_code(_without(":method"), True), error)
    assert_equal(_code(_without(":scheme"), True), error)
    assert_equal(_code(_without(":path"), True), error)
    assert_equal(_code(_without(":authority"), True), error)
    var get = FieldList()
    get.add_text(":method", "GET")
    get.add_text(":protocol", "websocket")
    assert_equal(_code(get, True), error)
    assert_false(is_extended_connect(_without(":protocol")))


def test_field_conversions() raises:
    var fields = _connect()
    var list = to_header_list(fields)
    assert_equal(list.count(), 5)
    assert_equal(String(list.name_text(1)), ":protocol")
    var back = to_field_list(list)
    assert_equal(back.count(), 5)
    assert_equal(String(back.value_text(4)), "/graphql")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

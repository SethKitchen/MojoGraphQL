# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The WebSocket handshake over HTTP/3 (RFC 9220): the setting
`SETTINGS_ENABLE_CONNECT_PROTOCOL`, and the extended `CONNECT` with
`:protocol websocket`.

`control_preface` starts a control stream whose SETTINGS allow the
extended `CONNECT`. `allows_extended_connect` reads the SETTINGS of the
peer. `check_connect` applies the rules of the pseudo-header fields of an
extended `CONNECT`. RFC 9220 uses the fields of RFC 8441, so
`to_header_list` and `to_field_list` let the checks of
`gql_ws_http2.handshake` serve HTTP/3 too.

This module ports the extended `CONNECT` rules of hyperium/h3 h3-v0.0.8
(MIT): `enable_extended_connect` of h3/src/config.rs, and the `:protocol`
pseudo-header field of `Pseudo::request` and `Header::into_request_parts`
in h3/src/proto/headers.rs.

Differences from upstream: h3 keeps `:protocol` on a request with
another method than `CONNECT`, and drops it. Here such a request is
malformed, as RFC 9220 section 3 and RFC 8441 section 4 tell.
"""

from gql_http2.hpack import HeaderList
from gql_http3.error import H3Error, H3ErrorCode
from gql_http3.frame import (
    FrameType,
    SettingId,
    Settings,
    StreamType,
    write_frame_header,
)
from gql_http3.qpack_field import FieldList
from gql_http3.varint import encode_varint


def control_preface(max_field_section_size: Int) -> List[UInt8]:
    """Return the start of a control stream: its type, and SETTINGS with
    `SETTINGS_ENABLE_CONNECT_PROTOCOL = 1`.

    Args:
        max_field_section_size: `SETTINGS_MAX_FIELD_SECTION_SIZE`.

    Returns:
        The bytes.
    """
    var payload = List[UInt8]()
    encode_varint(SettingId.MAX_FIELD_SECTION_SIZE.value, payload)
    encode_varint(UInt64(max_field_section_size), payload)
    encode_varint(SettingId.ENABLE_CONNECT_PROTOCOL.value, payload)
    encode_varint(1, payload)
    var out = List[UInt8]()
    encode_varint(StreamType.CONTROL.value, out)
    write_frame_header(out, FrameType.SETTINGS, len(payload))
    out.extend(Span(payload))
    return out^


def allows_extended_connect(settings: Settings) -> Bool:
    """Return True when the SETTINGS of a peer allow the extended
    `CONNECT` (RFC 9220 section 3).

    Args:
        settings: The SETTINGS of the peer.

    Returns:
        Whether `SETTINGS_ENABLE_CONNECT_PROTOCOL` is 1.
    """
    return settings.get_or(SettingId.ENABLE_CONNECT_PROTOCOL, 0) == 1


def to_header_list(fields: FieldList) -> HeaderList:
    """Copy the fields of an HTTP/3 field section into a `HeaderList`.

    Args:
        fields: The fields.

    Returns:
        The same fields, in order.
    """
    var out = HeaderList()
    var index = 0
    while index < fields.count():
        out.add(fields.name(index), fields.value(index))
        index += 1
    return out^


def to_field_list(fields: HeaderList) -> FieldList:
    """Copy the fields of a `HeaderList` into an HTTP/3 field section.

    Args:
        fields: The fields.

    Returns:
        The same fields, in order.
    """
    var out = FieldList()
    var index = 0
    while index < fields.count():
        out.add(fields.name(index), fields.value(index))
        index += 1
    return out^


def _message_error(message: String) -> H3Error:
    """Make the error of a malformed request."""
    return H3Error(H3ErrorCode.H3_MESSAGE_ERROR, message)


def is_extended_connect(fields: FieldList) -> Bool:
    """Return True when a request head has a `:protocol` field.

    Args:
        fields: The fields of the request head.

    Returns:
        Whether the request is an extended `CONNECT`, or claims to be.
    """
    return fields.find(":protocol") >= 0


def check_connect(fields: FieldList, enabled: Bool) raises H3Error:
    """Check the pseudo-header fields of an extended `CONNECT`.

    Args:
        fields: The fields of the request head.
        enabled: Whether this server sent
            `SETTINGS_ENABLE_CONNECT_PROTOCOL = 1`.

    Raises:
        H3Error: `H3_MESSAGE_ERROR` when the server did not allow the
            extended `CONNECT`, for `:protocol` with another method than
            `CONNECT`, and for a missing `:scheme`, `:path` or
            `:authority`.
    """
    if not enabled:
        raise _message_error("the extended CONNECT is not enabled")
    var method = fields.find(":method")
    if method < 0 or String(fields.value_text(method)) != "CONNECT":
        raise _message_error(":protocol without CONNECT")
    if (
        fields.find(":scheme") < 0
        or fields.find(":path") < 0
        or fields.find(":authority") < 0
    ):
        raise _message_error("a missing pseudo-header field")

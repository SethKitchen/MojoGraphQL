# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""HTTP/3 messages: the frames of a request stream, and the mapping to and
from HTTP/1.1.

`MessageReader` reads the frames of one request stream or response stream
(RFC 9114 section 4.1): a HEADERS frame, DATA frames, and optional
trailers, which it drops. It skips reserved frame types, and refuses the
frames that do not belong on a request stream.

The server serves the `Handler` of `gql_http`. `to_http1_request` writes
an HTTP/3 request as an HTTP/1.1 request, which the `RequestReader` of
`gql_http` parses. `from_http1_response` reads the response that the
`ResponseWriter` wrote, and gives its status, fields and content. The
client does the opposite with `request_fields` and `to_http1_response`.

The mapping follows RFC 9114 section 4.2 and 4.3: field names are
lowercase, the pseudo-header fields come first, and the fields that are
specific to a connection (`Connection`, `Keep-Alive`, `Proxy-Connection`,
`Transfer-Encoding`, `Upgrade`) are refused in a request and dropped from
a response. `:authority` becomes `Host`.

This module ports the request stream rules of hyperium/h3 h3-v0.0.8
h3/src/proto/headers.rs (MIT): the pseudo-header checks of
`Header::request` and `Header::into_request_parts`.

Differences from upstream: h3 builds `http::Request` values. This module
writes HTTP/1.1 bytes instead, because the handlers of this project take a
`gql_http` `Request`. A request without `:authority` and without `Host`
gets `Host: localhost`, because HTTP/1.1 requires a `Host` field.
"""

from gql_http.headers import Headers
from gql_http.parser import (
    BodyKind,
    ChunkedDecoder,
    Limits,
    ParseState,
    ResponseHead,
    parse_response_head,
)
from gql_http.status import Method
from gql_http3.error import H3Error, H3ErrorCode
from gql_http3.frame import (
    FrameType,
    parse_frame_head,
    write_data_frame,
    write_headers_frame,
)
from gql_http3.qpack_decoder import QpackDecoder
from gql_http3.qpack_field import FieldList


def message_error(message: String) -> H3Error:
    """Make the error of a malformed message (RFC 9114 section 4.1.2).

    Args:
        message: A description.

    Returns:
        An `H3_MESSAGE_ERROR`.
    """
    return H3Error(H3ErrorCode.H3_MESSAGE_ERROR, message)


def _equals(left: Span[UInt8, _], right: StaticString) -> Bool:
    """Compare bytes with ASCII text, exactly."""
    var other = right.as_bytes()
    if len(left) != len(other):
        return False
    var index = 0
    while index < len(left):
        if left[index] != other[index]:
            return False
        index += 1
    return True


def is_connection_field(name: Span[UInt8, _]) -> Bool:
    """Return True for a field that HTTP/3 does not carry.

    Args:
        name: The field name, in lowercase.

    Returns:
        Whether it is `connection`, `keep-alive`, `proxy-connection`,
        `transfer-encoding` or `upgrade`.
    """
    return (
        _equals(name, "connection")
        or _equals(name, "keep-alive")
        or _equals(name, "proxy-connection")
        or _equals(name, "transfer-encoding")
        or _equals(name, "upgrade")
    )


struct MessageReader(Movable):
    """The frames of one request or response stream, fed as they arrive."""

    var fields: FieldList
    """The fields of the HEADERS frame."""
    var body: List[UInt8]
    """The payload of every DATA frame."""
    var has_headers: Bool
    """Whether the HEADERS frame arrived."""
    var max_body: Int
    """The most content to accept."""
    var _buffer: List[UInt8]
    var _start: Int
    var _trailers: FieldList

    def __init__(out self, max_body: Int):
        """Make a reader for one stream.

        Args:
            max_body: The most content to accept.
        """
        self.fields = FieldList()
        self.body = List[UInt8]()
        self.has_headers = False
        self.max_body = max_body
        self._buffer = List[UInt8]()
        self._start = 0
        self._trailers = FieldList()

    def feed(
        mut self,
        data: Span[UInt8, _],
        stream_id: UInt64,
        mut decoder: QpackDecoder,
    ) raises H3Error:
        """Take bytes of the stream, and read every complete frame.

        Args:
            data: The bytes that arrived.
            stream_id: The id of the stream, for QPACK.
            decoder: The QPACK decoder of the connection.

        Raises:
            H3Error: `H3_FRAME_UNEXPECTED` for a frame that does not belong
                on the stream; `H3_EXCESSIVE_LOAD` for content over
                `max_body`; the QPACK errors.
        """
        self._buffer.extend(data)
        while True:
            var head = parse_frame_head(self._buffer, self._start)
            if not head.complete():
                break
            if head.type == FrameType.DATA:
                if not self.has_headers:
                    raise H3Error(
                        H3ErrorCode.H3_FRAME_UNEXPECTED, "DATA before HEADERS"
                    )
                if len(self.body) + head.length > self.max_body:
                    raise H3Error(
                        H3ErrorCode.H3_EXCESSIVE_LOAD,
                        "the content is too large",
                    )
            elif head.type == FrameType.HEADERS:
                pass
            elif head.type.is_valid() or head.type.is_http2_only():
                # Unknown and reserved types are skipped (section 9).
                raise H3Error(
                    H3ErrorCode.H3_FRAME_UNEXPECTED,
                    "a " + String(head.type) + " frame on a request stream",
                )
            if head.payload_end() > len(self._buffer):
                break
            var payload = Span(self._buffer)[
                head.payload_start : head.payload_end()
            ]
            if head.type == FrameType.DATA:
                self.body.extend(payload)
            elif head.type == FrameType.HEADERS:
                if self.has_headers:
                    _ = decoder.decode(stream_id, payload, self._trailers)
                else:
                    if not decoder.decode(stream_id, payload, self.fields):
                        raise H3Error(
                            H3ErrorCode.QPACK_DECOMPRESSION_FAILED,
                            "the field section is blocked",
                        )
                    self.has_headers = True
            self._start = head.payload_end()
        if self._start > 0:
            var rest = len(self._buffer) - self._start
            var index = 0
            while index < rest:
                self._buffer[index] = self._buffer[self._start + index]
                index += 1
            self._buffer.resize(rest, 0)
            self._start = 0

    def finish(self) raises H3Error:
        """Check the stream at its end (FIN).

        Raises:
            H3Error: `H3_REQUEST_INCOMPLETE` without HEADERS, or when the
                stream ends inside a frame.
        """
        if not self.has_headers or len(self._buffer) > 0:
            raise H3Error(
                H3ErrorCode.H3_REQUEST_INCOMPLETE,
                "the stream ended before the message",
            )


def _has_upper(name: Span[UInt8, _]) -> Bool:
    """Return True when a field name has an uppercase ASCII letter."""
    var index = 0
    while index < len(name):
        if name[index] >= 65 and name[index] <= 90:
            return True
        index += 1
    return False


def _append_line(
    mut out: List[UInt8], name: Span[UInt8, _], value: Span[UInt8, _]
):
    """Append `name: value` and CRLF."""
    out.extend(name)
    out.append(58)
    out.append(32)
    out.extend(value)
    out.append(13)
    out.append(10)


def to_http1_request(
    fields: FieldList, body: Span[UInt8, _], mut out: List[UInt8]
) raises H3Error:
    """Write an HTTP/3 request as an HTTP/1.1 request (RFC 9114 section
    4.3.1).

    Args:
        fields: The fields of the HEADERS frame, pseudo-header fields first.
        body: The content of the DATA frames.
        out: Receives the request: head and content.

    Raises:
        H3Error: `H3_MESSAGE_ERROR` for a malformed request: a missing,
            repeated or unknown pseudo-header field, a pseudo-header field
            after a regular one, an uppercase name, a field that is
            specific to a connection, `te` other than `trailers`, a
            `content-length` that does not match the content, or the
            method `CONNECT`.
    """
    var method = -1
    var path = -1
    var authority = -1
    var scheme = -1
    var regular = False
    var index = 0
    while index < fields.count():
        var name = fields.name(index)
        if len(name) > 0 and name[0] == 58:
            if regular:
                raise message_error("a pseudo-header field after a field")
            var slot: Int
            if _equals(name, ":method"):
                slot = method
                method = index
            elif _equals(name, ":path"):
                slot = path
                path = index
            elif _equals(name, ":authority"):
                slot = authority
                authority = index
            elif _equals(name, ":scheme"):
                slot = scheme
                scheme = index
            else:
                raise message_error("an unknown pseudo-header field")
            if slot >= 0:
                raise message_error("a repeated pseudo-header field")
        else:
            regular = True
            if len(name) == 0 or _has_upper(name) or is_connection_field(name):
                raise message_error("a field that HTTP/3 does not allow")
            if _equals(name, "te") and not _equals(
                fields.value(index), "trailers"
            ):
                raise message_error("te other than trailers")
            if _equals(name, "content-length") and not _equals_number(
                fields.value(index), len(body)
            ):
                raise message_error("content-length does not match")
        index += 1
    if method < 0 or scheme < 0 or path < 0 or len(fields.value(path)) == 0:
        raise message_error("a missing pseudo-header field")
    if _equals(fields.value(method), "CONNECT"):
        raise message_error("CONNECT is not supported")
    out.extend(fields.value(method))
    out.append(32)
    out.extend(fields.value(path))
    out.extend(StaticString(" HTTP/1.1\r\nHost: ").as_bytes())
    if authority >= 0:
        out.extend(fields.value(authority))
    else:
        var host = fields.find("host")
        if host >= 0:
            out.extend(fields.value(host))
        else:
            out.extend(StaticString("localhost").as_bytes())
    out.extend(StaticString("\r\n").as_bytes())
    index = 0
    while index < fields.count():
        var name = fields.name(index)
        var skip = (
            name[0] == 58
            or _equals(name, "host")
            or _equals(name, "content-length")
        )
        if not skip:
            _append_line(out, name, fields.value(index))
        index += 1
    out.extend(StaticString("Content-Length: ").as_bytes())
    out.extend(String(len(body)).as_bytes())
    out.extend(StaticString("\r\n\r\n").as_bytes())
    out.extend(body)


def _equals_number(text: Span[UInt8, _], value: Int) -> Bool:
    """Return True when decimal digits spell a value."""
    var digits = String(value).as_bytes()
    if len(text) != len(digits):
        return False
    var index = 0
    while index < len(text):
        if text[index] != digits[index]:
            return False
        index += 1
    return True


def from_http1_response(
    mut data: List[UInt8],
    method: Method,
    limits: Limits,
    mut fields: FieldList,
    mut body: List[UInt8],
) raises H3Error:
    """Read the HTTP/1.1 response of a `ResponseWriter` as HTTP/3 fields
    and content (RFC 9114 section 4.3.2).

    Args:
        data: The response; chunked content is decoded in place.
        method: The method of the request.
        limits: The size limits.
        fields: Receives `:status` and the fields, in lowercase, without
            the fields that are specific to a connection.
        body: Receives the content.

    Raises:
        H3Error: `H3_INTERNAL_ERROR` when the response is not valid.
    """
    var head = ResponseHead()
    var result = parse_response_head(data.unsafe_ptr(), len(data), limits, head)
    if result.state != ParseState.COMPLETE:
        raise H3Error(H3ErrorCode.H3_INTERNAL_ERROR, "invalid response")
    fields.clear()
    body.clear()
    fields.add_text(":status", String(head.status.code))
    var name = List[UInt8]()
    var index = 0
    while index < len(head.fields):
        var field = head.fields[index]
        name.clear()
        var at = Int(field.name_start)
        while at < Int(field.name_end):
            var byte = data[at]
            name.append(byte + 32 if byte >= 65 and byte <= 90 else byte)
            at += 1
        var drop = is_connection_field(name) or (
            head.chunked and _equals(name, "content-length")
        )
        if not drop:
            fields.add(
                name,
                Span(data)[Int(field.value_start) : Int(field.value_end)],
            )
        index += 1
    var kind = head.body_kind(method)
    var start = head.head_size
    if kind == BodyKind.LENGTH:
        body.extend(Span(data)[start : start + head.content_length])
    elif kind == BodyKind.CHUNKED:
        var decoder = ChunkedDecoder()
        decoder.reset(start)
        var chunks = decoder.feed(data.unsafe_ptr(), len(data), limits)
        if chunks.state != ParseState.COMPLETE:
            raise H3Error(H3ErrorCode.H3_INTERNAL_ERROR, "invalid chunks")
        body.extend(Span(data)[start : decoder.write])
    elif kind == BodyKind.CLOSE:
        body.extend(Span(data)[start:])


def request_fields(
    method: Method,
    authority: StringSlice,
    target: StringSlice,
    headers: Headers,
    body_size: Int,
    mut fields: FieldList,
):
    """Make the fields of an HTTP/3 request (RFC 9114 section 4.3.1).

    Args:
        method: The method.
        authority: The `:authority`: the host, and the port when needed.
        target: The `:path`: the path and the query.
        headers: The other fields, in wire form; names become lowercase,
            and `Host` and the fields that are specific to a connection are
            dropped.
        body_size: The size of the content; `content-length` is written
            when there is content, or for `POST`, `PUT` and `PATCH`.
        fields: Receives the fields.
    """
    fields.clear()
    fields.add_text(":method", method.text())
    fields.add_text(":scheme", "https")
    fields.add_text(":authority", authority)
    fields.add_text(":path", target)
    var data = Span(headers.data)
    var name = List[UInt8]()
    var at = 0
    while at < len(data):
        name.clear()
        while data[at] != 58:
            var byte = data[at]
            name.append(byte + 32 if byte >= 65 and byte <= 90 else byte)
            at += 1
        at += 2
        var start = at
        while data[at] != 13:
            at += 1
        var drop = (
            is_connection_field(name)
            or _equals(name, "host")
            or _equals(name, "content-length")
        )
        if not drop:
            fields.add(name, data[start:at])
        at += 2
    var with_body = (
        method == Method.POST or method == Method.PUT or method == Method.PATCH
    )
    if body_size > 0 or with_body:
        fields.add_text("content-length", String(body_size))


def to_http1_response(
    fields: FieldList, body: Span[UInt8, _], mut out: List[UInt8]
) raises H3Error:
    """Write an HTTP/3 response as an HTTP/1.1 response with
    `Content-Length`, for `gql_http.client.read_response`.

    Args:
        fields: The fields of the HEADERS frame, `:status` first.
        body: The content of the DATA frames.
        out: Receives the response.

    Raises:
        H3Error: `H3_MESSAGE_ERROR` without one valid `:status`, with
            another pseudo-header field, or with a field that HTTP/3 does
            not allow.
    """
    if fields.count() == 0 or not _equals(fields.name(0), ":status"):
        raise message_error("the response has no :status")
    var status = fields.value(0)
    var valid = len(status) == 3
    var index = 0
    while valid and index < 3:
        valid = status[index] >= 48 and status[index] <= 57
        index += 1
    if not valid or status[0] < 49 or status[0] > 53:
        raise message_error("an invalid :status")
    out.extend(StaticString("HTTP/1.1 ").as_bytes())
    out.extend(status)
    out.extend(StaticString(" \r\n").as_bytes())
    index = 1
    while index < fields.count():
        var name = fields.name(index)
        if (
            len(name) == 0
            or name[0] == 58
            or _has_upper(name)
            or is_connection_field(name)
        ):
            raise message_error("a field that HTTP/3 does not allow")
        if not _equals(name, "content-length"):
            _append_line(out, name, fields.value(index))
        index += 1
    out.extend(StaticString("Content-Length: ").as_bytes())
    out.extend(String(len(body)).as_bytes())
    out.extend(StaticString("\r\n\r\n").as_bytes())
    out.extend(body)


def write_message(
    block: Span[UInt8, _], body: Span[UInt8, _], mut out: List[UInt8]
):
    """Write a HEADERS frame, and a DATA frame when there is content.

    Args:
        block: The encoded field section.
        body: The content.
        out: Receives the frames.
    """
    write_headers_frame(out, block)
    if len(body) > 0:
        write_data_frame(out, body)

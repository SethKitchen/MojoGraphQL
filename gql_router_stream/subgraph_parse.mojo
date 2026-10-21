# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Read the events of a subgraph subscription over HTTP streaming.

Port of Hive Router `1a29df9` `bin/router/src/executor/executors/sse.rs`
(`parse_to_stream`, `find_sse_event_boundary`, `parse`) and
`executor/executors/multipart_subscribe.rs` (`parse_boundary_from_header`,
`parse_to_stream`, `find_next_part`, `parse_part`,
`extract_body_after_headers`, `extract_payload`).

`SseParser` and `MultipartParser` read the content as it arrives. `feed`
adds bytes, and `take` appends the JSON of each complete event. `take`
returns True at the end of the subscription: an SSE `complete` event or
the multipart close delimiter.

A parser keeps at most `MAX_BUFFER_SIZE` bytes without an event boundary,
as upstream.

**Differences from upstream.** The parsers return the JSON text of each
event, and the router reads it as a `SubgraphResponse` when it executes
the event. Upstream reads it in the parser. An event that is not a
GraphQL response thus fails at the same point of the stream.
"""

from gql_json.parser import parse
from gql_json.value import NO_NODE, JsonDocument, JsonKind
from gql_router.exec_value import write_value


comptime MAX_BUFFER_SIZE = 10 * 1024 * 1024
"""The most bytes without an event boundary, as upstream: 10 MB."""


def _find(buffer: List[UInt8], needle: Span[UInt8, _], start: Int = 0) -> Int:
    """Return the first position of `needle` in `buffer`, or -1."""
    var count = len(needle)
    var position = start
    while position + count <= len(buffer):
        var same = True
        # The needles are delimiters, which are not empty.
        var index = 0
        while index < count:
            if buffer[position + index] != needle[index]:
                same = False
                break
            index += 1
        if same:
            return position
        position += 1
    return -1


def _newline_after(buffer: List[UInt8], start: Int) -> Int:
    """Return the position of the first `\\n` at or after `start`, or -1."""
    var position = start
    while position < len(buffer):
        if buffer[position] == 10:
            return position
        position += 1
    return -1


def _drain(mut buffer: List[UInt8], count: Int) -> List[UInt8]:
    """Remove the first `count` bytes and return them."""
    var head = List[UInt8](buffer[:count])
    var rest = List[UInt8](buffer[count:])
    buffer = rest^
    return head^


def _text(bytes: List[UInt8]) raises -> String:
    """Decode UTF-8, as upstream `std::str::from_utf8`."""
    try:
        return String(from_utf8=Span(bytes))
    except:
        raise Error("Invalid UTF-8 sequence")


def find_sse_event_boundary(buffer: List[UInt8]) -> Int:
    """Find the end of the first complete SSE event, as upstream.

    Args:
        buffer: The bytes so far.

    Returns:
        The position after the first `\\n\\n` or `\\r\\n\\r\\n`, or -1.
    """
    var size = len(buffer)
    for i in range(max(size - 1, 0)):
        if (
            buffer[i] == 13
            and i + 3 < size
            and buffer[i + 1] == 10
            and buffer[i + 2] == 13
            and buffer[i + 3] == 10
        ):
            return i + 4
        if buffer[i] == 10 and buffer[i + 1] == 10:
            return i + 2
    return -1


struct SseEvent(Copyable, Movable):
    """One SSE event of a subgraph, as upstream `SubgraphSseEvent`."""

    var has_event: Bool
    """Whether the event has an `event` field."""
    var event: String
    """The `event` field."""
    var data: String
    """The `data` lines, joined with `\\n`."""

    def __init__(out self):
        """Make an empty event."""
        self.has_event = False
        self.event = String()
        self.data = String()


def parse_sse_event(raw: List[UInt8], mut out: SseEvent) raises -> Bool:
    """Parse the bytes of one SSE event, as upstream `parse`.

    Args:
        raw: The bytes of the event, up to its boundary.
        out: The event.

    Returns:
        True when the bytes hold an event; False for a heartbeat or for
        nothing.

    Raises:
        Error: `Invalid UTF-8 sequence`.
    """
    var text = _text(raw)
    var lines = List[String]()
    var has_data = False
    for line_slice in text.splitlines():
        var line = String(line_slice)
        if line.byte_length() == 0:
            if out.has_event or has_data:
                break
            continue
        if line.startswith(":"):
            continue
        var colon = line.find(":")
        if colon < 0:
            continue
        var field = String(line[byte=:colon])
        var value = String(line[byte = colon + 1 :].strip())
        if field == "event":
            out.has_event = True
            out.event = value^
        elif field == "data":
            lines.append(value^)
            has_data = True
    out.data = String("\n").join(lines)
    return out.has_event or has_data


struct SseParser(Movable):
    """The SSE events of a subgraph stream, as upstream
    `sse::parse_to_stream`."""

    var buffer: List[UInt8]
    """The bytes after the last event."""
    var limit: Int
    """The most bytes without an event boundary."""

    def __init__(out self, limit: Int = MAX_BUFFER_SIZE):
        """Start with no bytes.

        Args:
            limit: The most bytes without an event boundary.
        """
        self.buffer = List[UInt8]()
        self.limit = limit

    def feed(mut self, data: Span[UInt8, _]) raises:
        """Add bytes of the content.

        Args:
            data: The bytes.

        Raises:
            Error: When the buffer is larger than `limit`.
        """
        self.buffer.extend(data)
        if len(self.buffer) > self.limit:
            raise Error(
                "Buffer size limit exceeded: stream sent more than "
                + String(self.limit)
                + " bytes without an event boundary"
            )

    def take(mut self, mut events: List[List[UInt8]]) raises -> Bool:
        """Append the data of each complete `next` event.

        Args:
            events: The destination; one JSON text per event.

        Returns:
            True after a `complete` event: the stream ends.

        Raises:
            Error: For an event that is not UTF-8.
        """
        while True:
            var boundary = find_sse_event_boundary(self.buffer)
            if boundary < 0:
                return False
            var raw = _drain(self.buffer, boundary)
            var event = SseEvent()
            if not parse_sse_event(raw, event) or not event.has_event:
                continue
            if event.event == "next" and event.data.byte_length() > 0:
                events.append(List[UInt8](event.data.as_bytes()))
            elif event.event == "complete":
                return True


def parse_boundary_from_header(content_type: StringSlice) raises -> String:
    """Read the boundary of a `multipart/mixed` content type, as upstream
    `parse_boundary_from_header`.

    Args:
        content_type: Such as `multipart/mixed; boundary=graphql`.

    Returns:
        The boundary, without quotes.

    Raises:
        Error: `Missing boundary parameter in Content-Type header`, or
            `Invalid boundary parameter: ...` for an empty or unclosed
            value.
    """
    var text = String(content_type.strip())
    var start = text.lower().find("boundary=")
    if start < 0:
        raise Error("Missing boundary parameter in Content-Type header")
    var remaining = String(text[byte = start + 9 :])
    var boundary: String
    if remaining.startswith('"'):
        var close = remaining.find('"', 1)
        if close < 0:
            raise Error("Invalid boundary parameter: Unclosed quoted boundary")
        boundary = String(remaining[byte=1:close])
    else:
        var end = remaining.byte_length()
        var bytes = remaining.as_bytes()
        for index in range(len(bytes)):
            var byte = bytes[index]
            if byte == 59 or byte == 32 or (byte >= 9 and byte <= 13):
                end = index
                break
        boundary = String(remaining[byte=:end])
    if boundary.byte_length() == 0:
        raise Error("Invalid boundary parameter: Empty boundary value")
    return boundary^


def extract_body_after_headers(content: String) -> String:
    """Return the body of a part, as upstream
    `extract_body_after_headers`.

    Args:
        content: The part, with its header fields.

    Returns:
        The trimmed text after the first blank line, or the whole trimmed
        text when there is no blank line.
    """
    var crlf = content.find("\r\n\r\n")
    if crlf >= 0:
        return String(content[byte = crlf + 4 :].strip())
    var lf = content.find("\n\n")
    if lf >= 0:
        return String(content[byte = lf + 2 :].strip())
    return String(content.strip())


def extract_payload(body: String, mut out: List[UInt8]) -> Bool:
    """Read the subgraph response of a part body, as upstream
    `extract_payload`.

    Args:
        body: The part body.
        out: Where the JSON of the response goes.

    Returns:
        False for the heartbeat `{}` and for a `null` payload without
        `errors`; True with the response in `out`. A body with
        `"payload":null` and `errors` is the transport error
        `{"errors":...}`. A body without `payload` is the response
        itself. A body that is not JSON goes as it is, and fails as a
        subgraph response.
    """
    if body == "{}":
        return False
    var document: JsonDocument
    try:
        document = parse(body)
    except:
        out.extend(body.as_bytes())
        return True
    var payload = NO_NODE
    if document.kind(document.root) == JsonKind.OBJECT:
        payload = document.find(document.root, "payload")
    if payload == NO_NODE:
        out.extend(body.as_bytes())
        return True
    if document.kind(payload) != JsonKind.NULL:
        write_value(document, payload, out)
        return True
    var errors = document.find(document.root, "errors")
    if errors == NO_NODE:
        return False
    out.extend('{"errors":'.as_bytes())
    write_value(document, errors, out)
    out.append(UInt8(ord("}")))
    return True


struct MultipartParser(Movable):
    """The parts of a multipart subgraph stream, as upstream
    `multipart_subscribe::parse_to_stream`."""

    var delimiter: List[UInt8]
    """`--` and the boundary."""
    var end_marker: List[UInt8]
    """`--`, the boundary and `--`."""
    var buffer: List[UInt8]
    """The bytes after the last part."""
    var started: Bool
    """Whether the first delimiter has been read."""

    var limit: Int
    """The most bytes without a part boundary."""

    def __init__(out self, boundary: StringSlice, limit: Int = MAX_BUFFER_SIZE):
        """Start a parser.

        Args:
            boundary: The boundary of the content type.
            limit: The most bytes without a part boundary.
        """
        self.limit = limit
        self.delimiter = List[UInt8](("--" + String(boundary)).as_bytes())
        self.end_marker = List[UInt8](
            ("--" + String(boundary) + "--").as_bytes()
        )
        self.buffer = List[UInt8]()
        self.started = False

    def feed(mut self, data: Span[UInt8, _]) raises:
        """Add bytes of the content.

        Args:
            data: The bytes.

        Raises:
            Error: When the buffer is larger than `limit`.
        """
        self.buffer.extend(data)
        if len(self.buffer) > self.limit:
            raise Error(
                "Buffer size limit exceeded: stream sent more than "
                + String(self.limit)
                + " bytes without a part boundary"
            )

    def take(mut self, mut events: List[List[UInt8]]) raises -> Bool:
        """Append the response of each complete part, as upstream
        `find_next_part` and `parse_part`.

        Args:
            events: The destination; one JSON text per part.

        Returns:
            True after the close delimiter: the stream ends.

        Raises:
            Error: For a part that is not UTF-8.
        """
        while True:
            if not self.started:
                var first = _find(self.buffer, Span(self.delimiter))
                if first < 0:
                    return False
                var newline = _newline_after(
                    self.buffer, first + len(self.delimiter)
                )
                if newline < 0:
                    return False
                _ = _drain(self.buffer, newline + 1)
                self.started = True
                continue
            var next = _find(self.buffer, Span(self.delimiter))
            if next < 0:
                return False
            var is_end = _find(self.buffer, Span(self.end_marker), next) == next
            var marker = len(self.end_marker) if is_end else len(self.delimiter)
            var skip = marker
            var newline = _newline_after(self.buffer, next + marker)
            if newline >= 0:
                skip = newline + 1 - next
            var part = _drain(self.buffer, next)
            _ = _drain(self.buffer, skip)
            if len(part) > 0:
                var body = extract_body_after_headers(_text(part))
                if body.byte_length() > 0:
                    var response = List[UInt8]()
                    if extract_payload(body, response):
                        events.append(response^)
            if is_end:
                return True

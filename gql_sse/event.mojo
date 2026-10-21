# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The messages of the GraphQL over Server-Sent Events protocol.

A message is an event, `next` or `complete`, and a JSON value as its data.
`print_message` writes one message in the `text/event-stream` format.
`EventParser` reads messages incrementally from the bytes of a stream.

Ports graphql-sse 2.6.3 `src/common.ts` (`print`, `validateStreamEvent`,
`parseStreamData`) and `src/parser.ts` (`createParser`).
"""

from gql_json.parser import parse


struct StreamEvent(Equatable, ImplicitlyCopyable, Writable):
    """The event of a message: `next` or `complete`."""

    var value: UInt8
    """The index of the event; see `is_valid`."""

    comptime NEXT = StreamEvent(0)
    """A result of the operation."""
    comptime COMPLETE = StreamEvent(1)
    """The end of the operation."""

    @implicit
    def __init__(out self, value: Int):
        """Make an event from its index.

        Args:
            value: The index.
        """
        self.value = UInt8(value)

    def is_valid(self) -> Bool:
        """Return True for `NEXT` and `COMPLETE`.

        Returns:
            Whether the index is in range.
        """
        return self.value <= 1

    def name(self) -> StaticString:
        """Return the name of the event in the stream.

        Returns:
            `next` or `complete`.
        """
        if self == StreamEvent.NEXT:
            return "next"
        return "complete"

    def write_to(self, mut writer: Some[Writer]):
        """Write the name of the event.

        Args:
            writer: The destination.
        """
        writer.write(self.name())


def validate_stream_event(name: StringSlice) raises -> StreamEvent:
    """Return the event of a name.

    Args:
        name: The name from the `event` field.

    Returns:
        The event.

    Raises:
        Error: `Invalid stream event "<name>"` for another name.
    """
    if name == "next":
        return StreamEvent.NEXT
    if name == "complete":
        return StreamEvent.COMPLETE
    raise Error('Invalid stream event "' + String(name) + '"')


def print_message(mut out: List[UInt8], event: StreamEvent, data: StringSlice):
    """Append one message: `event: <event>`, `data: <data>`, a blank line.

    Args:
        out: The destination.
        event: The event.
        data: The data as JSON text; empty for none, as `null` is.
    """
    out.extend(StaticString("event: ").as_bytes())
    out.extend(event.name().as_bytes())
    out.extend(StaticString("\ndata:").as_bytes())
    if data.byte_length() > 0 and not (data == "null"):
        out.append(32)
        out.extend(data.as_bytes())
    out.extend(StaticString("\n\n").as_bytes())


def print_ping(mut out: List[UInt8]):
    """Append a comment line that keeps the connection alive.

    Args:
        out: The destination.
    """
    out.extend(StaticString(":\n\n").as_bytes())


@fieldwise_init
struct StreamMessage(Copyable, Movable):
    """One message that `EventParser` read."""

    var event: StreamEvent
    """The event."""
    var data: String
    """The data as JSON text; empty for none."""


def parse_stream_data(event: StreamEvent, data: String) raises -> String:
    """Check the data of a message.

    Args:
        event: The event.
        data: The data as JSON text, or empty.

    Returns:
        The data; empty for `null`.

    Raises:
        Error: `Invalid stream data` for invalid JSON, and `Stream data
            must be an object for "next" events` for none.
    """
    if data.byte_length() > 0:
        try:
            _ = parse(data)
        except:
            raise Error("Invalid stream data")
    if data == "null":
        if event == StreamEvent.NEXT:
            raise Error('Stream data must be an object for "next" events')
        return String()
    if event == StreamEvent.NEXT and data.byte_length() == 0:
        raise Error('Stream data must be an object for "next" events')
    return data


struct EventParser(Movable):
    """Reads the messages of a `text/event-stream` as its bytes arrive.

    A line ends at LF, CR or CRLF. Only the fields `event` and `data` count,
    and a blank line ends a message.
    """

    var _buf: List[UInt8]
    var _position: Int
    var _field_length: Int
    var _discard_lf: Bool
    var _event: String
    var _data: String

    def __init__(out self):
        """Make a parser at the start of a stream."""
        self._buf = List[UInt8]()
        self._position = 0
        self._field_length = -1
        self._discard_lf = False
        self._event = String()
        self._data = String()

    def feed(
        mut self, chunk: Span[UInt8, _], mut out: List[StreamMessage]
    ) raises:
        """Parse a chunk, and append the complete messages to `out`.

        Args:
            chunk: The next bytes of the stream.
            out: The destination of the messages.

        Raises:
            Error: `Missing message event`, `Invalid stream event`, and the
                errors of `parse_stream_data`.
        """
        self._buf.extend(chunk)
        var n = len(self._buf)
        var line_start = 0
        while self._position < n:
            if self._discard_lf:
                if self._buf[self._position] == 10:
                    self._position += 1
                    line_start = self._position
                self._discard_lf = False
            var line_end = -1
            while self._position < n and line_end == -1:
                var byte = self._buf[self._position]
                if byte == 58:
                    if self._field_length == -1:
                        self._field_length = self._position - line_start
                elif byte == 13:
                    self._discard_lf = True
                    line_end = self._position
                elif byte == 10:
                    line_end = self._position
                self._position += 1
            if line_end == -1:
                break
            if line_start == line_end:
                self._dispatch(out)
            elif self._field_length > 0:
                self._field(line_start, line_end)
            line_start = self._position
            self._field_length = -1
        if line_start > 0:
            var rest = n - line_start
            var i = 0
            while i < rest:
                self._buf[i] = self._buf[line_start + i]
                i += 1
            self._buf.resize(rest, 0)
            self._position -= line_start

    def _dispatch(mut self, mut out: List[StreamMessage]) raises:
        """End the message at a blank line."""
        if self._event.byte_length() == 0 and self._data.byte_length() == 0:
            return
        if self._event.byte_length() == 0:
            raise Error("Missing message event")
        var event = validate_stream_event(self._event)
        var data = parse_stream_data(event, self._data)
        out.append(StreamMessage(event, data^))
        self._event = String()
        self._data = String()

    def _field(mut self, line_start: Int, line_end: Int):
        """Read one `field: value` line."""
        var line = Span(self._buf)[line_start:line_end]
        var length = self._field_length
        var offset = length + 1
        if length + 1 < len(line) and line[length + 1] == 32:
            offset = length + 2
        var field = String(unsafe_from_utf8=line[0:length])
        var value = String(unsafe_from_utf8=line[min(offset, len(line)) :])
        if field == "event":
            self._event = value^
        elif field == "data":
            if self._data.byte_length() > 0:
                self._data += "\n" + value
            else:
                self._data = value^

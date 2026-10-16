# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The error every GraphQL stage reports, and the source excerpt it prints.

Port of graphql-js 16.14.2 `error/GraphQLError.ts`, `error/syntaxError.ts`
and `language/printLocation.ts`.

A `GraphQLError` holds what the GraphQL over HTTP response shows: a message,
the locations in the request, the response path, and extensions. Writing an
error gives graphql-js `toString()`: the message, then an excerpt of the
source at each location. `to_json` gives graphql-js `toJSON()`.

**Difference from graphql-js.** The excerpt cuts a line longer than 120
UTF-16 units into pieces of 80 units. graphql-js can cut a surrogate pair in
two. This port keeps a pair in the earlier piece.
"""

from gql_language.block_string import utf16_count
from gql_language.source import Source, SourceLocation

comptime _HEX = "0123456789abcdef"


@fieldwise_init
struct PathSegment(Copyable, Equatable, ImplicitlyCopyable, Writable):
    """One step of a response path: a field key, or a list index."""

    var key: String
    """The response key, or empty for an index."""
    var index: Int
    """The list index, or -1 for a key."""

    @staticmethod
    def of_key(key: String) -> PathSegment:
        """Return a segment for a response key.

        Args:
            key: The response key.

        Returns:
            The segment.
        """
        return PathSegment(key, -1)

    @staticmethod
    def of_index(index: Int) -> PathSegment:
        """Return a segment for a list index.

        Args:
            index: The list index; zero or more.

        Returns:
            The segment.
        """
        return PathSegment(String(""), index)

    def is_index(self) -> Bool:
        """Return True if the segment is a list index.

        Returns:
            Whether the segment names a list position.
        """
        return self.index >= 0

    def write_to(self, mut writer: Some[Writer]):
        """Write the key, or the index.

        Args:
            writer: The destination.
        """
        if self.is_index():
            writer.write(self.index)
        else:
            writer.write(self.key)


struct GraphQLError(Copyable, Movable, Writable):
    """A GraphQL error: a message, its locations, its path and extensions."""

    var message: String
    """The description of the error."""
    var locations: List[SourceLocation]
    """The one-based positions in the request that the error refers to."""
    var path: List[PathSegment]
    """The response path of the field that failed, or empty."""
    var extensions: String
    """A JSON object of extra data, or empty for none."""
    var excerpt: String
    """The source excerpts that `toString()` appends; empty without a
    source."""

    def __init__(out self, message: String):
        """Create an error with only a message.

        Args:
            message: The description.
        """
        self.message = message
        self.locations = List[SourceLocation]()
        self.path = List[PathSegment]()
        self.extensions = String("")
        self.excerpt = String("")

    def __init__(
        out self, message: String, source: Source, positions: List[Int]
    ):
        """Create an error at byte offsets of a source.

        Args:
            message: The description.
            source: The source that the positions are in.
            positions: Byte offsets into the source body.
        """
        self.message = message
        self.locations = List[SourceLocation]()
        self.path = List[PathSegment]()
        self.extensions = String("")
        self.excerpt = String("")
        for position in positions:
            var location = source.get_location(position)
            self.locations.append(location)
            self.excerpt += "\n\n" + print_source_location(source, location)

    def write_to(self, mut writer: Some[Writer]):
        """Write the message and the source excerpts, as `toString()`.

        Args:
            writer: The destination.
        """
        writer.write(self.message, self.excerpt)

    def to_json(self) -> String:
        """Return the error as a GraphQL response error, as `toJSON()`.

        Returns:
            A JSON object with `message`, and `locations`, `path` and
            `extensions` when they are not empty.
        """
        var out = String('{"message":')
        out += quote_json_string(self.message)
        # Each list opens before its first item and closes after its last,
        # so an empty list writes nothing.
        var separator = String(',"locations":[')
        for ref location in self.locations:
            out += separator + '{"line":' + String(location.line)
            out += ',"column":' + String(location.column) + "}"
            separator = String(",")
        if len(self.locations) > 0:
            out += "]"
        separator = String(',"path":[')
        for ref segment in self.path:
            out += separator
            separator = String(",")
            if segment.is_index():
                out += String(segment.index)
            else:
                out += quote_json_string(segment.key)
        if len(self.path) > 0:
            out += "]"
        if self.extensions != "":
            out += ',"extensions":' + self.extensions
        out += "}"
        return out^


def syntax_error(
    source: Source, position: Int, description: String
) -> GraphQLError:
    """Return a syntax error at a byte offset.

    Args:
        source: The source being read.
        position: The byte offset of the problem.
        description: What is wrong.

    Returns:
        An error whose message starts `Syntax Error: `.
    """
    return GraphQLError("Syntax Error: " + description, source, [position])


def quote_json_string(text: String) -> String:
    """Return text as a JSON string literal, with its escapes.

    Args:
        text: The text.

    Returns:
        The text in double quotes, with `"`, `\\` and control characters
        escaped.
    """
    var out = List[UInt8](capacity=text.byte_length() + 2)
    out.append(34)
    for byte in text.as_bytes():
        if byte == 34 or byte == 92:
            out.append(92)
            out.append(byte)
        elif byte < 32:
            out.append(92)
            if byte == 10:
                out.append(110)
            elif byte == 13:
                out.append(114)
            elif byte == 9:
                out.append(116)
            elif byte == 8:
                out.append(98)
            elif byte == 12:
                out.append(102)
            else:
                out.append(117)
                out.append(48)
                out.append(48)
                out.append(_HEX.as_bytes()[Int(byte >> 4)])
                out.append(_HEX.as_bytes()[Int(byte & 15)])
        else:
            out.append(byte)
    out.append(34)
    return String(unsafe_from_utf8=out)


def _split_lines(text: String) -> List[String]:
    """Split text at `\\r\\n`, `\\n` and `\\r`, keeping empty lines."""
    var lines = List[String]()
    var bytes = text.as_bytes()
    var start = 0
    var index = 0
    var size = len(bytes)
    while index < size:
        var byte = bytes[index]
        if byte == 10 or byte == 13:
            lines.append(String(unsafe_from_utf8=bytes[start:index]))
            if byte == 13 and index + 1 < size and bytes[index + 1] == 10:
                index += 1
            start = index + 1
        index += 1
    lines.append(String(unsafe_from_utf8=bytes[start:size]))
    return lines^


def _split_units(text: String, width: Int) -> List[String]:
    """Cut text into pieces of `width` UTF-16 units, pairs kept whole."""
    var pieces = List[String]()
    var bytes = text.as_bytes()
    var start = 0
    var index = 0
    var units = 0
    while index < len(bytes):
        if units >= width:
            pieces.append(String(unsafe_from_utf8=bytes[start:index]))
            start = index
            units = 0
        var lead = bytes[index]
        index += 1
        units += 1
        if lead >= 0xF0:
            units += 1
        while index < len(bytes) and bytes[index] & 0xC0 == 0x80:
            index += 1
    # The text is a line longer than 120 units, so a last piece remains.
    pieces.append(String(unsafe_from_utf8=bytes[start : len(bytes)]))
    return pieces^


@fieldwise_init
struct _Prefixed(Copyable, Movable):
    """A gutter prefix and an optional line of source."""

    var prefix: String
    var line: String
    var present: Bool


def _print_prefixed_lines(lines: List[_Prefixed]) -> String:
    """Right-align the prefixes and join the lines that exist."""
    var width = 0
    var index = 0
    while index < len(lines):
        if lines[index].present:
            width = max(width, lines[index].prefix.byte_length())
        index += 1
    var out = String("")
    var separator = String("")
    index = 0
    while index < len(lines):
        ref entry = lines[index]
        index += 1
        if not entry.present:
            continue
        out += separator
        separator = String("\n")
        out += " " * (width - entry.prefix.byte_length()) + entry.prefix
        if entry.line != "":
            out += " " + entry.line
    return out^


def _line_at(lines: List[String], index: Int) -> _Prefixed:
    """Return a line by index, or an absent entry when out of range."""
    if index < 0 or index >= len(lines):
        return _Prefixed(String(""), String(""), False)
    return _Prefixed(String(""), lines[index], True)


def print_source_location(source: Source, location: SourceLocation) -> String:
    """Return the location and the lines around it, with a caret.

    Args:
        source: The source the location is in.
        location: A one-based line and column in the body.

    Returns:
        `name:line:column`, then the previous, current and next lines with
        a `^` under the column.
    """
    var first_line_column_offset = source.location_offset.column - 1
    var body = " " * first_line_column_offset + String(source.body())
    var line_index = location.line - 1
    var line_offset = source.location_offset.line - 1
    var line_num = location.line + line_offset
    var column_offset = 0
    if location.line == 1:
        column_offset = first_line_column_offset
    var column_num = location.column + column_offset
    var location_str = (
        source.name + ":" + String(line_num) + ":" + String(column_num) + "\n"
    )
    var lines = _split_lines(body)
    var location_line = String("")
    if line_index < len(lines):
        location_line = lines[line_index]
    var caret = " " * max(0, column_num - 1) + "^"
    var entries = List[_Prefixed]()
    if utf16_count(location_line.as_bytes()) > 120:
        var sub_line_index = column_num // 80
        var sub_line_column_num = column_num % 80
        var sub_lines = _split_units(location_line, 80)
        entries.append(_Prefixed(String(line_num) + " |", sub_lines[0], True))
        for index in range(1, min(sub_line_index + 1, len(sub_lines))):
            entries.append(_Prefixed(String("|"), sub_lines[index], True))
        entries.append(
            _Prefixed(
                String("|"), " " * max(0, sub_line_column_num - 1) + "^", True
            )
        )
        var after = _line_at(sub_lines, sub_line_index + 1)
        after.prefix = String("|")
        entries.append(after^)
        return location_str + _print_prefixed_lines(entries)
    var before = _line_at(lines, line_index - 1)
    before.prefix = String(line_num - 1) + " |"
    entries.append(before^)
    entries.append(_Prefixed(String(line_num) + " |", location_line, True))
    entries.append(_Prefixed(String("|"), caret, True))
    var after = _line_at(lines, line_index + 1)
    after.prefix = String(line_num + 1) + " |"
    entries.append(after^)
    return location_str + _print_prefixed_lines(entries)

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""GraphQL source text, and the line and column of a position in it.

Port of graphql-js 16.14.2 `language/source.ts` and `language/location.ts`.

A `Source` keeps the body as UTF-8 bytes, followed by `PADDING` zero bytes.
The lexer reads past the last character without a bounds check: a zero byte
ends every name, number and digit run, and the lexer stops at the length.

**Difference from graphql-js.** Positions are byte offsets into the UTF-8
body. graphql-js counts UTF-16 code units. `get_location` converts, so a
column is the same number that graphql-js reports.
"""

# Zero bytes after the body. The lexer looks at most three bytes ahead.
from gql_language.block_string import utf16_count

comptime PADDING = 4
"""How many zero bytes follow the body of a `Source`."""


@fieldwise_init
struct SourceLocation(Equatable, ImplicitlyCopyable, Writable):
    """A one-based line and column, as graphql-js `SourceLocation`."""

    var line: Int
    """The one-based line."""
    var column: Int
    """The one-based column, in UTF-16 code units."""

    def write_to(self, mut writer: Some[Writer]):
        """Write the location as `line:column`.

        Args:
            writer: The destination.
        """
        writer.write(self.line, ":", self.column)


struct Source(Copyable, Movable):
    """A body of GraphQL text with a name and a location offset.

    The name appears in error messages. The location offset moves the first
    line and column, for a source embedded in a larger file.
    """

    var bytes: List[UInt8]
    """The body as UTF-8, then `PADDING` zero bytes."""
    var length: Int
    """The body length in bytes, without the padding."""
    var name: String
    """The name used in error messages."""
    var location_offset: SourceLocation
    """The line and column of the first character."""

    def __init__(out self, body: StringSlice, name: String = "GraphQL request"):
        """Copy a body into a new source that starts at line 1, column 1.

        Args:
            body: The GraphQL text.
            name: The name used in error messages.
        """
        var data = body.as_bytes()
        self.length = len(data)
        self.bytes = List[UInt8](capacity=self.length + PADDING)
        self.bytes.extend(data)
        self.bytes.resize(self.length + PADDING, 0)
        self.name = name
        self.location_offset = SourceLocation(1, 1)

    def __init__(
        out self,
        body: StringSlice,
        name: String,
        location_offset: SourceLocation,
    ) raises:
        """Copy a body into a new source with a location offset.

        Args:
            body: The GraphQL text.
            name: The name used in error messages.
            location_offset: The one-based position of the first character.

        Raises:
            Error: If the line or the column of the offset is not positive.
        """
        if location_offset.line <= 0:
            raise Error(
                "line in locationOffset is 1-indexed and must be positive."
            )
        if location_offset.column <= 0:
            raise Error(
                "column in locationOffset is 1-indexed and must be positive."
            )
        self = Source(body, name)
        self.location_offset = location_offset

    def body(self) -> StringSlice[origin_of(self.bytes)]:
        """Return the body text.

        Returns:
            A view of the body, without the padding.
        """
        return StringSlice(unsafe_from_utf8=Span(self.bytes)[: self.length])

    def slice(self, start: Int, end: Int) -> StringSlice[origin_of(self.bytes)]:
        """Return the body text between two byte offsets.

        Args:
            start: The first byte offset.
            end: The byte offset after the last byte.

        Returns:
            A view of those bytes.
        """
        return StringSlice(unsafe_from_utf8=Span(self.bytes)[start:end])

    def get_location(self, position: Int) -> SourceLocation:
        """Return the line and column of a byte offset.

        A line ends at `\\r\\n`, `\\n` or `\\r`. The column counts UTF-16
        code units, as graphql-js does.

        Args:
            position: A byte offset into the body.

        Returns:
            The one-based line and column.
        """
        var line = 1
        var line_start = 0
        var index = 0
        var stop = min(position, self.length)
        var data = self.bytes.unsafe_ptr()
        while index < stop:
            var byte = data[unsafe_offset=index]
            if byte == 10:
                line += 1
                line_start = index + 1
            elif byte == 13:
                line += 1
                if data[unsafe_offset=index + 1] == 10:
                    index += 1
                line_start = index + 1
            index += 1
        return SourceLocation(
            line,
            1
            + utf16_count(Span(self.bytes)[line_start : max(stop, line_start)]),
        )

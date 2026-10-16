# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The error that the JSON parser and the value readers raise.

A `JsonError` has a message and, for a parse error, the byte offset, the
line and the column of the problem. ECMAScript `JSON.parse` raises a
`SyntaxError` whose message names a position; this module gives the same
facts as fields.

This module has no upstream counterpart.

Differences from upstream: the messages are not the V8 messages.
"""


struct JsonError(Copyable, Movable, Writable):
    """A JSON syntax error, or a value that a reader cannot convert."""

    var message: String
    """The description of the error."""
    var offset: Int
    """The byte offset of the problem in the input, or -1 for none."""
    var line: Int
    """The one-based line of the offset, or 0 for none."""
    var column: Int
    """The one-based column of the offset, in code points, or 0."""

    def __init__(out self, message: String):
        """Create an error that has no position.

        Args:
            message: The description.
        """
        self.message = message
        self.offset = -1
        self.line = 0
        self.column = 0

    def __init__(out self, message: String, data: Span[UInt8, _], offset: Int):
        """Create an error at a byte offset of the input.

        A line ends at `\\n`, at `\\r`, and at `\\r\\n`. The column counts
        code points: every byte that does not continue a UTF-8 sequence.

        Args:
            message: The description.
            data: The input bytes.
            offset: The byte offset of the problem; at most `len(data)`.
        """
        self.message = message
        self.offset = offset
        self.line = 1
        var line_start = 0
        var index = 0
        while index < offset:
            var byte = data[index]
            if byte == 0x0A or (
                byte == 0x0D
                and (index + 1 == len(data) or data[index + 1] != 0x0A)
            ):
                self.line += 1
                line_start = index + 1
            index += 1
        self.column = 1
        index = line_start
        while index < offset:
            if data[index] & 0xC0 != 0x80:
                self.column += 1
            index += 1

    def write_to(self, mut writer: Some[Writer]):
        """Write the message, then the position when there is one.

        Args:
            writer: The destination.
        """
        writer.write(self.message)
        if self.offset >= 0:
            writer.write(
                " at line ",
                self.line,
                ", column ",
                self.column,
                " (byte ",
                self.offset,
                ")",
            )

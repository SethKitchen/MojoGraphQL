# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The text layout of apollo-compiler, for the SDL that Rover prints.

Port of the parts of apollo-compiler 1.33.0 `src/ast/serialize.rs` (MIT
arm of MIT OR Apache-2.0) that `rover graph introspect` uses: the indent
state, `comma_separated`, `curly_brackets_space_separated`, string values
and block strings. Rover encodes an introspection result through that
serializer, so the same layout gives the same text.
"""


struct Serializer(Movable):
    """The output and the indent state of apollo-compiler `State`."""

    var out: String
    """The text so far."""
    var level: Int
    """The indent level; each level is two spaces."""
    var newlines: Bool
    """False inside `on_single_line`, which writes spaces for line breaks."""

    def __init__(out self):
        """Start an empty output at level 0, with line breaks."""
        self.out = String()
        self.level = 0
        self.newlines = True

    def take(deinit self) -> String:
        """Return the text.

        Returns:
            The output.
        """
        return self.out^

    def write(mut self, text: StringSlice):
        """Append text.

        Args:
            text: The text.
        """
        self.out += text

    def _line(mut self, space: Bool):
        """Write a line break and the indent, or a space or nothing."""
        if self.newlines:
            self.out += "\n"
            for _ in range(self.level):
                self.out += "  "
        elif space:
            self.out += " "

    def indent(mut self, space: Bool):
        """Go one level in and start a line, as `indent` or
        `indent_or_space`.

        Args:
            space: Write a space when line breaks are off.
        """
        self.level += 1
        self._line(space)

    def dedent(mut self, space: Bool):
        """Go one level out and start a line, as `dedent` or
        `dedent_or_space`.

        Args:
            space: Write a space when line breaks are off.
        """
        self.level -= 1
        self._line(space)

    def new_line_or_space(mut self):
        """Start a line, or write a space when line breaks are off."""
        self._line(True)

    def string_value(mut self, text: StringSlice, is_description: Bool):
        """Write a string value, as `serialize_string_value`.

        A description, or a value with a line break, is a block string
        when line breaks are on and the value can be one.

        Args:
            text: The value.
            is_description: Whether the value is a description.
        """
        var has_newline = text.find("\n") >= 0
        if (
            self.newlines
            and (is_description or has_newline)
            and can_be_block_string(text)
        ):
            self._block_string(text, has_newline)
            return
        self.out += '"'
        var bytes = text.as_bytes()
        var run = 0
        for index in range(len(bytes)):
            var byte = bytes[index]
            if byte >= 32 and byte != 34 and byte != 92 or byte == 9:
                continue
            self.out += String(text[byte=run:index])
            run = index + 1
            if byte == 8:
                self.out += "\\b"
            elif byte == 10:
                self.out += "\\n"
            elif byte == 12:
                self.out += "\\f"
            elif byte == 13:
                self.out += "\\r"
            elif byte == 34:
                self.out += '\\"'
            elif byte == 92:
                self.out += "\\\\"
            else:
                var digits = "0123456789ABCDEF"
                self.out += (
                    "\\u00"
                    + String(
                        digits[byte = Int(byte) // 16 : Int(byte) // 16 + 1]
                    )
                    + String(digits[byte = Int(byte) % 16 : Int(byte) % 16 + 1])
                )
        self.out += String(text[byte=run:])
        self.out += '"'

    def _block_string(mut self, text: StringSlice, has_newline: Bool):
        """Write a block string, as `serialize_block_string`."""
        var multi_line = (
            has_newline
            or text.byte_length() > 70
            or text.endswith('"')
            or text.endswith("\\")
        )
        self.out += '"""'
        if not multi_line:
            self.out += String(text).replace('"""', '\\"""')
        else:
            var lines = text.split("\n")
            var index = 0
            while index < len(lines):
                var line = lines[index]
                index += 1
                if line.byte_length() == 0:
                    self.out += "\n"
                else:
                    self._line(False)
                    self.out += String(line).replace('"""', '\\"""')
            self._line(False)
        self.out += '"""'

    def description(mut self, text: Optional[String]):
        """Write a description and the line break after it, as
        `serialize_description`.

        Args:
            text: The description, if there is one.
        """
        if text:
            self.string_value(text.value(), True)
            self.new_line_or_space()


def _blank(line: StringSlice) -> Bool:
    """Return True for a line of only spaces and tabs."""
    for byte in line.as_bytes():
        if byte != 32 and byte != 9:
            return False
    return True


def can_be_block_string(value: StringSlice) -> Bool:
    """Return True when a block string can hold a value exactly, as
    apollo-compiler `can_be_block_string`.

    Args:
        value: The value.

    Returns:
        False for a carriage return, a blank first or last line, or a
        common indent.
    """
    if value.find("\r") >= 0:
        return False
    var lines = value.split("\n")
    if _blank(lines[0]) or _blank(lines[len(lines) - 1]):
        return False
    var common = -1
    var index = 0
    while index < len(lines):
        var line = lines[index]
        index += 1
        if _blank(line):
            continue
        var bytes = line.as_bytes()
        var indent = 0
        while bytes[indent] == 32 or bytes[indent] == 9:
            indent += 1
        if common < 0 or indent < common:
            common = indent
    return common <= 0

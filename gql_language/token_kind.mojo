# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The kinds of lexical token. Port of graphql-js 16.14.2 `tokenKind.ts`."""


@fieldwise_init
struct TokenKind(Equatable, ImplicitlyCopyable, Writable):
    """The kind of a lexical token, as a type and not a bare integer."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime SOF = TokenKind(0)
    """The `<SOF>` token."""
    comptime EOF = TokenKind(1)
    """The `<EOF>` token."""
    comptime BANG = TokenKind(2)
    """The `!` token."""
    comptime DOLLAR = TokenKind(3)
    """The `$` token."""
    comptime AMP = TokenKind(4)
    """The `&` token."""
    comptime PAREN_L = TokenKind(5)
    """The `(` token."""
    comptime PAREN_R = TokenKind(6)
    """The `)` token."""
    comptime DOT = TokenKind(7)
    """The `.` token."""
    comptime SPREAD = TokenKind(8)
    """The `...` token."""
    comptime COLON = TokenKind(9)
    """The `:` token."""
    comptime EQUALS = TokenKind(10)
    """The `=` token."""
    comptime AT = TokenKind(11)
    """The `@` token."""
    comptime BRACKET_L = TokenKind(12)
    """The `[` token."""
    comptime BRACKET_R = TokenKind(13)
    """The `]` token."""
    comptime BRACE_L = TokenKind(14)
    """The `{` token."""
    comptime PIPE = TokenKind(15)
    """The `|` token."""
    comptime BRACE_R = TokenKind(16)
    """The `}` token."""
    comptime NAME = TokenKind(17)
    """The `Name` token."""
    comptime INT = TokenKind(18)
    """The `Int` token."""
    comptime FLOAT = TokenKind(19)
    """The `Float` token."""
    comptime STRING = TokenKind(20)
    """The `String` token."""
    comptime BLOCK_STRING = TokenKind(21)
    """The `BlockString` token."""
    comptime COMMENT = TokenKind(22)
    """The `Comment` token."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the token kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 22

    def is_punctuator(self) -> Bool:
        """Return True for a punctuation token, as `isPunctuatorTokenKind`.

        Returns:
            Whether the kind is one of the fifteen punctuators.
        """
        return self.value >= 2 and self.value <= 16

    def text(self) -> StaticString:
        """Return the graphql-js string for the kind.

        Returns:
            `<SOF>`, `!`, `Name`, and so on.
        """
        comptime names: Array[StaticString, 23] = [
            "<SOF>",
            "<EOF>",
            "!",
            "$",
            "&",
            "(",
            ")",
            ".",
            "...",
            ":",
            "=",
            "@",
            "[",
            "]",
            "{",
            "|",
            "}",
            "Name",
            "Int",
            "Float",
            "String",
            "BlockString",
            "Comment",
        ]
        if not self.is_valid():
            return "<invalid>"
        return materialize[names]()[Int(self.value)]

    def description(self) -> String:
        """Return the kind as parser errors name it, as `getTokenKindDesc`.

        Returns:
            A punctuator in double quotes, or the kind's name.
        """
        if self.is_punctuator():
            return '"' + String(self.text()) + '"'
        return String(self.text())

    def write_to(self, mut writer: Some[Writer]):
        """Write the graphql-js string for the kind.

        Args:
            writer: The destination.
        """
        writer.write(self.text())

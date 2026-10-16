# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Block strings and quoted strings, as the printer writes them.

Port of graphql-js 16.14.2 `language/blockString.ts` (the printing half;
`dedent_block_string_lines` is in `lexer`) and `language/printString.ts`.
Lengths are UTF-16 code units, as in graphql-js.

Each `append_*` function writes into a byte list, so the printer builds a
document in one buffer. `print_block_string` and `print_string` return a
`String` for a caller that wants one.
"""

from gql_language.scan import (
    count_utf16,
    find_byte,
    find_byte2,
    find_string_escape,
    string_from_utf8,
)

comptime _HEX = "0123456789ABCDEF"


def utf16_count(text: Span[UInt8, _]) -> Int:
    """Return the length of UTF-8 text in UTF-16 code units.

    Args:
        text: Valid UTF-8 bytes.

    Returns:
        One unit per code point, and two above U+FFFF.
    """
    return count_utf16(text, 0, len(text))


@always_inline
def _is_white_space(byte: UInt8) -> Bool:
    """Return True for a tab or a space."""
    return byte == 0x09 or byte == 0x20


def is_printable_as_block_string(value: StringSlice) -> Bool:
    """Return True if a block string can hold the value exactly.

    Port of graphql-js `isPrintableAsBlockString`.

    Args:
        value: The string value.

    Returns:
        False when the value has a control character, a `\\r`, a leading
        blank line, a trailing blank line, or an indent common to all lines.
    """
    var bytes = value.as_bytes()
    if len(bytes) == 0:
        return True
    var is_empty_line = True
    var has_indent = False
    var has_common_indent = True
    var seen_non_empty_line = False
    var index = 0
    while index < len(bytes):
        var byte = bytes[index]
        index += 1
        if (byte <= 0x08) or byte == 0x0B or byte == 0x0C or byte == 0x0E:
            return False
        if byte == 0x0F or byte == 0x0D:
            return False
        if byte == 0x0A:
            if is_empty_line and not seen_non_empty_line:
                return False
            seen_non_empty_line = True
            is_empty_line = True
            has_indent = False
        elif byte == 0x09 or byte == 0x20:
            has_indent = has_indent or is_empty_line
        elif byte & 0xC0 != 0x80:
            has_common_indent = has_common_indent and has_indent
            is_empty_line = False
    if is_empty_line:
        return False
    if has_common_indent and seen_non_empty_line:
        return False
    return True


@fieldwise_init
struct BlockStringLayout(ImplicitlyCopyable, Movable):
    """Where `printBlockString` puts line breaks around the value."""

    var leading_newline: Bool
    """Start with a line break after the opening quotes."""
    var trailing_newline: Bool
    """End with a line break before the closing quotes."""


def _ends_with_escaped_triple_quote(value: Span[UInt8, _]) -> Bool:
    """Return True if escaping `\"\"\"` from the left ends at the last byte,
    as graphql-js `escapedValue.endsWith('\\\\\"\"\"')`."""
    var size = len(value)
    var last_end = -1
    var index = find_byte(value, 0, size, 0x22)
    while index + 2 < size:
        if value[index + 1] == 0x22 and value[index + 2] == 0x22:
            index += 3
            last_end = index
        else:
            index += 1
        index = find_byte(value, index, size, 0x22)
    return last_end == size


def block_string_layout(
    value: Span[UInt8, _], minimize: Bool = False
) -> BlockStringLayout:
    """Decide the line breaks of a block string, as graphql-js
    `printBlockString`.

    Args:
        value: The string value, as UTF-8.
        minimize: Print on one line when possible.

    Returns:
        Whether a line break follows the opening quotes and precedes the
        closing quotes.
    """
    var size = len(value)
    var index = find_byte2(value, 0, size, 0x0A, 0x0D)
    var is_single_line = index == size
    # Every line after the first is empty or starts with white space.
    var later_lines_indented = True
    while index < size:
        # `index` is at a line break; look at the start of the next line.
        if (
            value[index] == 0x0D
            and index + 1 < size
            and value[index + 1] == 0x0A
        ):
            index += 1
        index += 1
        if index < size:
            var first = value[index]
            if first != 0x0A and first != 0x0D and not _is_white_space(first):
                later_lines_indented = False
        index = find_byte2(value, index, size, 0x0A, 0x0D)
    # Only a single line needs its length.
    var units = 0
    if is_single_line:
        units = count_utf16(value, 0, size)
    var force_leading_new_line = not is_single_line and later_lines_indented
    var ends_with_quote = size > 0 and value[size - 1] == 0x22
    var has_trailing_triple_quotes = (
        ends_with_quote and _ends_with_escaped_triple_quote(value)
    )
    var has_trailing_quote = ends_with_quote and not has_trailing_triple_quotes
    var has_trailing_slash = size > 0 and value[size - 1] == 0x5C
    var force_trailing_newline = has_trailing_quote or has_trailing_slash
    var print_as_multiple_lines = not minimize and (
        not is_single_line
        or units > 70
        or force_trailing_newline
        or force_leading_new_line
        or has_trailing_triple_quotes
    )
    var skip_leading_new_line = (
        is_single_line and size > 0 and _is_white_space(value[0])
    )
    return BlockStringLayout(
        (print_as_multiple_lines and not skip_leading_new_line)
        or force_leading_new_line,
        print_as_multiple_lines or force_trailing_newline,
    )


def append_escaped_triple_quotes(mut out: List[UInt8], value: Span[UInt8, _]):
    """Append a value with each `\"\"\"` written as `\\\\\"\"\"`.

    Args:
        out: The destination.
        value: The string value, as UTF-8.
    """
    var size = len(value)
    var chunk = 0
    var index = find_byte(value, 0, size, 0x22)
    while index + 2 < size:
        if value[index + 1] == 0x22 and value[index + 2] == 0x22:
            out.extend(value[chunk:index])
            out.append(0x5C)
            # The quotes start the next run.
            chunk = index
            index += 3
        else:
            index += 1
        index = find_byte(value, index, size, 0x22)
    out.extend(value[chunk:size])


def append_block_string(
    mut out: List[UInt8], value: Span[UInt8, _], minimize: Bool = False
):
    """Append a value as a block string literal.

    Args:
        out: The destination.
        value: The string value, as UTF-8.
        minimize: Print on one line when possible.
    """
    var layout = block_string_layout(value, minimize)
    out.extend('"""'.as_bytes())
    if layout.leading_newline:
        out.append(0x0A)
    append_escaped_triple_quotes(out, value)
    if layout.trailing_newline:
        out.append(0x0A)
    out.extend('"""'.as_bytes())


def print_block_string(value: StringSlice, minimize: Bool = False) -> String:
    """Return a value as a block string literal.

    Port of graphql-js `printBlockString`.

    Args:
        value: The string value.
        minimize: Print on one line when possible.

    Returns:
        The value between triple quotes, with `\"\"\"` escaped.
    """
    var out = List[UInt8](capacity=value.byte_length() + 8)
    append_block_string(out, value.as_bytes(), minimize)
    return string_from_utf8(out)


def append_string_literal(mut out: List[UInt8], value: Span[UInt8, _]):
    """Append a value as a quoted string literal.

    Port of graphql-js `printString`: it escapes U+0000 to U+001F, `"`,
    `\\` and U+007F to U+009F.

    Args:
        out: The destination.
        value: The string value, as UTF-8.
    """
    out.append(0x22)
    var size = len(value)
    var chunk = 0
    var index = find_string_escape(value, 0, size)
    while index < size:
        var byte = value[index]
        var code: Int
        var width = 1
        if byte != 0xC2:
            code = Int(byte)
        elif value[index + 1] <= 0x9F:
            # U+0080 to U+009F: C2 80 to C2 9F.
            code = Int(value[index + 1])
            width = 2
        else:
            # U+00A0 to U+00BF need no escape.
            index = find_string_escape(value, index + 1, size)
            continue
        out.extend(value[chunk:index])
        out.append(0x5C)
        if code == 0x22 or code == 0x5C:
            out.append(UInt8(code))
        elif code == 0x08:
            out.append(0x62)
        elif code == 0x09:
            out.append(0x74)
        elif code == 0x0A:
            out.append(0x6E)
        elif code == 0x0C:
            out.append(0x66)
        elif code == 0x0D:
            out.append(0x72)
        else:
            out.append(0x75)
            out.append(0x30)
            out.append(0x30)
            out.append(_HEX.as_bytes()[code >> 4])
            out.append(_HEX.as_bytes()[code & 15])
        index += width
        chunk = index
        index = find_string_escape(value, index, size)
    out.extend(value[chunk:size])
    out.append(0x22)


def print_string(value: StringSlice) -> String:
    """Return a value as a quoted string literal, as graphql-js
    `printString`.

    Args:
        value: The string value.

    Returns:
        The value in double quotes, with its escapes.
    """
    var out = List[UInt8](capacity=value.byte_length() + 2)
    append_string_literal(out, value.as_bytes())
    return string_from_utf8(out)

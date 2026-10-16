# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The GraphQL lexer: source bytes in, tokens out.

Port of graphql-js 16.14.2 `language/lexer.ts` and
`language/characterClasses.ts`. The error messages are the same.

**Differences from graphql-js.**

- A token is a kind and a byte range. It has no value: `token_value`
  decodes one on demand. A string is checked for valid escapes when it is
  read, and decoded only when a caller asks. This keeps the lexer free of
  allocation, and is most of why it is fast.
- A token has no line and column. `Source.get_location` computes them for
  the rare error that needs them.
- Comments are skipped and not returned, as graphql-js `lookahead` does.
  `read_comments` returns them for tools that need them.
- A Mojo string is valid UTF-8, so it has no lone surrogate. The
  `Invalid character:` errors for a lone surrogate cannot happen.
"""

from std.memory import unsafe_memcpy

from gql_language.error import GraphQLError, syntax_error
from gql_language.scan import (
    find_byte,
    find_byte2,
    find_byte4,
)
from gql_language.source import Source
from gql_language.token_kind import TokenKind


@always_inline
def is_name_start(byte: UInt8) -> Bool:
    """Return True if a byte can start a name: a letter or `_`.

    Args:
        byte: The byte.

    Returns:
        Whether the byte starts a name.
    """
    var folded = byte | 0x20
    return (folded >= 0x61 and folded <= 0x7A) or byte == 0x5F


@always_inline
def is_name_continue(byte: UInt8) -> Bool:
    """Return True if a byte can continue a name: a letter, digit or `_`.

    Args:
        byte: The byte.

    Returns:
        Whether the byte continues a name.
    """
    var folded = byte | 0x20
    return (
        (folded >= 0x61 and folded <= 0x7A)
        or byte == 0x5F
        or (byte >= 0x30 and byte <= 0x39)
    )


@always_inline
def is_digit(byte: UInt8) -> Bool:
    """Return True if a byte is an ASCII digit.

    Args:
        byte: The byte.

    Returns:
        Whether the byte is `0` to `9`.
    """
    return byte >= 0x30 and byte <= 0x39


@fieldwise_init
struct Token(ImplicitlyCopyable, Movable, Writable):
    """A lexical token: its kind and its byte range in the source."""

    var kind: TokenKind
    """What the token is."""
    var start: Int
    """The byte offset of the first character."""
    var end: Int
    """The byte offset after the last character."""

    def write_to(self, mut writer: Some[Writer]):
        """Write the kind and the range, for debugging.

        Args:
            writer: The destination.
        """
        writer.write(self.kind, "[", self.start, ":", self.end, "]")


def decode_codepoint(bytes: List[UInt8], position: Int) -> Int:
    """Return the code point that starts at a byte offset of valid UTF-8.

    Args:
        bytes: The UTF-8 bytes, padded with zeros.
        position: The offset of a code point's first byte.

    Returns:
        The code point.
    """
    var first = Int(bytes[position])
    if first < 0x80:
        return first
    if first < 0xE0:
        return ((first & 0x1F) << 6) | (Int(bytes[position + 1]) & 0x3F)
    if first < 0xF0:
        return (
            ((first & 0x0F) << 12)
            | ((Int(bytes[position + 1]) & 0x3F) << 6)
            | (Int(bytes[position + 2]) & 0x3F)
        )
    return (
        ((first & 0x07) << 18)
        | ((Int(bytes[position + 1]) & 0x3F) << 12)
        | ((Int(bytes[position + 2]) & 0x3F) << 6)
        | (Int(bytes[position + 3]) & 0x3F)
    )


def _hex4(value: Int) -> String:
    """Return a value as at least four uppercase hexadecimal digits."""
    comptime digits = "0123456789ABCDEF"
    var out = String("")
    var shift = 20
    var started = False
    while shift >= 0:
        var digit = (value >> shift) & 15
        if digit != 0 or started or shift <= 12:
            started = True
            out += digits[byte=digit]
        shift -= 4
    return out^


def print_codepoint_at(source: Source, position: Int) -> String:
    """Return the character at a byte offset as errors print it.

    Port of graphql-js `printCodePointAt`.

    Args:
        source: The source.
        position: A byte offset at or after the start of a code point.

    Returns:
        `<EOF>` past the end, `"c"` for printable ASCII, `'"'` for a double
        quote, and `U+XXXX` for anything else.
    """
    if position >= source.length:
        return String("<EOF>")
    var code = decode_codepoint(source.bytes, position)
    if code >= 0x20 and code <= 0x7E:
        if code == 0x22:
            return String("'\"'")
        return '"' + String(chr(code)) + '"'
    return "U+" + _hex4(code)


@always_inline
def _hex_digit(byte: UInt8) -> Int:
    """Return a hexadecimal digit's value, or -1."""
    var code = Int(byte)
    if code >= 0x30 and code <= 0x39:
        return code - 0x30
    if code >= 0x41 and code <= 0x46:
        return code - 0x37
    if code >= 0x61 and code <= 0x66:
        return code - 0x57
    return -1


def _read_16bit_hex(bytes: Span[UInt8, _], position: Int) -> Int:
    """Read four hex digits; negative when one of them is not hex."""
    return (
        (_hex_digit(bytes[position]) << 12)
        | (_hex_digit(bytes[position + 1]) << 8)
        | (_hex_digit(bytes[position + 2]) << 4)
        | _hex_digit(bytes[position + 3])
    )


@always_inline
def _is_scalar(code: Int) -> Bool:
    """Return True for a Unicode scalar value."""
    return (code >= 0 and code <= 0xD7FF) or (
        code >= 0xE000 and code <= 0x10FFFF
    )


@always_inline
def _is_leading_surrogate(code: Int) -> Bool:
    """Return True for U+D800 to U+DBFF."""
    return code >= 0xD800 and code <= 0xDBFF


@always_inline
def _is_trailing_surrogate(code: Int) -> Bool:
    """Return True for U+DC00 to U+DFFF."""
    return code >= 0xDC00 and code <= 0xDFFF


@fieldwise_init
struct _Escape(ImplicitlyCopyable, Movable):
    """A decoded escape: the code point and how many bytes it took."""

    var codepoint: Int
    var size: Int


comptime _BAD_CHARACTER_ESCAPE = -1
comptime _BAD_UNICODE_ESCAPE = -2


def _decode_escape(bytes: Span[UInt8, _], position: Int) -> _Escape:
    """Decode the escape sequence whose backslash is at `position`.

    Returns:
        The code point and size; or, for an invalid escape, a negative
        code point and the number of bytes the error message quotes.
    """
    var next = bytes[position + 1]
    if next == 0x75:  # u
        if bytes[position + 2] == 0x7B:  # {
            return _decode_unicode_variable(bytes, position)
        return _decode_unicode_fixed(bytes, position)
    var code: Int
    if next == 0x22:
        code = 0x22
    elif next == 0x5C:
        code = 0x5C
    elif next == 0x2F:
        code = 0x2F
    elif next == 0x62:
        code = 0x08
    elif next == 0x66:
        code = 0x0C
    elif next == 0x6E:
        code = 0x0A
    elif next == 0x72:
        code = 0x0D
    elif next == 0x74:
        code = 0x09
    else:
        code = _BAD_CHARACTER_ESCAPE
    return _Escape(code, 2)


def _read_escape(source: Source, position: Int) raises GraphQLError -> _Escape:
    """Decode the escape sequence at `position`, or raise graphql-js's error."""
    var escape = _decode_escape(Span(source.bytes), position)
    if escape.codepoint >= 0:
        return escape
    var description: StaticString = "Invalid Unicode escape sequence"
    if escape.codepoint == _BAD_CHARACTER_ESCAPE:
        description = "Invalid character escape sequence"
    var end = _codepoint_end(source, min(position + escape.size, source.length))
    raise syntax_error(
        source,
        position,
        String(description)
        + ': "'
        + String(source.slice(position, end))
        + '".',
    )


def _codepoint_end(source: Source, end: Int) -> Int:
    """Move an end offset forward to the end of the code point it cuts."""
    var index = end
    while index < source.length and source.bytes[index] & 0xC0 == 0x80:
        index += 1
    return index


def _decode_unicode_variable(bytes: Span[UInt8, _], position: Int) -> _Escape:
    """Decode `\\u{...}`, as graphql-js `readEscapedUnicodeVariableWidth`."""
    var point = 0
    var size = 3
    while size < 12:
        var byte = bytes[position + size]
        size += 1
        if byte == 0x7D:
            if size < 5 or not _is_scalar(point):
                break
            return _Escape(point, size)
        var digit = _hex_digit(byte)
        if digit < 0:
            break
        # graphql-js shifts a 32-bit signed integer, and stops when the
        # sign bit is set.
        point = ((point << 4) | digit) & 0xFFFFFFFF
        if point >= 0x80000000:
            break
    return _Escape(_BAD_UNICODE_ESCAPE, size)


def _decode_unicode_fixed(bytes: Span[UInt8, _], position: Int) -> _Escape:
    """Decode `\\uXXXX`, and a surrogate pair of two of them."""
    var code = _read_16bit_hex(bytes, position + 2)
    if _is_scalar(code):
        return _Escape(code, 6)
    if _is_leading_surrogate(code):
        if bytes[position + 6] == 0x5C and bytes[position + 7] == 0x75:
            var trailing = _read_16bit_hex(bytes, position + 8)
            if _is_trailing_surrogate(trailing):
                var point = (
                    0x10000 + ((code - 0xD800) << 10) + (trailing - 0xDC00)
                )
                return _Escape(point, 12)
    return _Escape(_BAD_UNICODE_ESCAPE, 6)


def _is_whitespace(byte: UInt8) -> Bool:
    """Return True for a tab or a space, as graphql-js `isWhiteSpace`."""
    return byte == 0x09 or byte == 0x20


def dedent_block_string_lines(lines: List[String]) -> List[String]:
    """Remove the common indent and the blank first and last lines.

    Port of graphql-js `dedentBlockStringLines`.

    Args:
        lines: The raw lines of a block string.

    Returns:
        The lines, with the common indent removed from all but the first,
        and leading and trailing blank lines dropped.
    """
    var common_indent = Int.MAX
    var first_non_empty = -1
    var last_non_empty = -1
    for index in range(len(lines)):
        var bytes = lines[index].as_bytes()
        var indent = 0
        while indent < len(bytes) and _is_whitespace(bytes[indent]):
            indent += 1
        if indent == len(bytes):
            continue
        if first_non_empty < 0:
            first_non_empty = index
        last_non_empty = index
        if index != 0 and indent < common_indent:
            common_indent = indent
    var out = List[String]()
    if first_non_empty < 0:
        first_non_empty = 0
    for index in range(first_non_empty, last_non_empty + 1):
        if index == 0:
            out.append(lines[index])
            continue
        var bytes = lines[index].as_bytes()
        var cut = min(common_indent, len(bytes))
        out.append(String(unsafe_from_utf8=bytes[cut:]))
    return out^


comptime _Out = Pointer[UInt8, UntrackedOrigin[mut=True]]
"""A destination that the decoders write through. Each decoder writes at
most as many bytes as the token has, so a buffer of the token's size is
enough."""


@always_inline
def _put(
    dest: _Out, at: Int, data: Span[UInt8, _], start: Int, end: Int
) -> Int:
    """Copy `data[start:end]` to `dest + at`; return the offset after it."""
    var count = end - start
    unsafe_memcpy(
        dest=dest.unsafe_offset(at),
        src=data.unsafe_ptr().unsafe_offset(start),
        count=count,
    )
    return at + count


def _put_codepoint(dest: _Out, at: Int, code: Int) -> Int:
    """Write a code point as UTF-8 at `dest + at`; return the offset after
    it."""
    if code < 0x80:
        dest[unsafe_offset=at] = UInt8(code)
        return at + 1
    if code < 0x800:
        dest[unsafe_offset=at] = UInt8(0xC0 | (code >> 6))
        dest[unsafe_offset=at + 1] = UInt8(0x80 | (code & 0x3F))
        return at + 2
    if code < 0x10000:
        dest[unsafe_offset=at] = UInt8(0xE0 | (code >> 12))
        dest[unsafe_offset=at + 1] = UInt8(0x80 | ((code >> 6) & 0x3F))
        dest[unsafe_offset=at + 2] = UInt8(0x80 | (code & 0x3F))
        return at + 3
    dest[unsafe_offset=at] = UInt8(0xF0 | (code >> 18))
    dest[unsafe_offset=at + 1] = UInt8(0x80 | ((code >> 12) & 0x3F))
    dest[unsafe_offset=at + 2] = UInt8(0x80 | ((code >> 6) & 0x3F))
    dest[unsafe_offset=at + 3] = UInt8(0x80 | (code & 0x3F))
    return at + 4


def _put_unescaped(
    dest: _Out, at: Int, data: Span[UInt8, _], start: Int, end: Int
) -> Int:
    """Write bytes, with each `\\\"\"\"` written as `\"\"\"`; return the
    offset after them.

    Runs are copied whole; at each escape the backslash is dropped and the
    quotes start the next run.
    """
    var bytes = data.unsafe_ptr()
    var out = at
    var chunk = start
    var index = find_byte(data, start, end, 0x5C)
    while index < end:
        if (
            bytes[unsafe_offset=index + 1] == 0x22
            and bytes[unsafe_offset=index + 2] == 0x22
            and bytes[unsafe_offset=index + 3] == 0x22
        ):
            out = _put(dest, out, data, chunk, index)
            chunk = index + 1
            index += 4
        else:
            index += 1
        index = find_byte(data, index, end, 0x5C)
    return _put(dest, out, data, chunk, end)


def _line_end(data: Span[UInt8, _], position: Int, stop: Int) -> Int:
    """Return the offset of the line break that ends the line at `position`,
    or `stop`.

    A `\\\"\"\"` holds no line break, so the scan needs no special case.
    """
    return find_byte2(data, position, stop, 0x0A, 0x0D)


@always_inline
def _next_line(data: Span[UInt8, _], line_end: Int, stop: Int) -> Int:
    """Return the offset after the line break at `line_end`."""
    if line_end >= stop:
        return stop + 1
    if data[line_end] == 0x0D and data[line_end + 1] == 0x0A:
        return line_end + 2
    return line_end + 1


def _put_block_string(
    dest: _Out, at: Int, data: Span[UInt8, _], start: Int, end: Int
) -> Int:
    """Write the value of a block string token; return the offset after it."""
    var bytes = data.unsafe_ptr()
    var stop = end - 3
    var first_end = _line_end(data, start + 3, stop)
    if first_end == stop:
        # One line: it is never dedented, and is dropped when it is blank.
        var index = start + 3
        while index < stop and _is_whitespace(bytes[unsafe_offset=index]):
            index += 1
        if index < stop:
            return _put_unescaped(dest, at, data, start + 3, stop)
        return at
    # First pass: the common indent, and the first and last lines that are
    # not blank. A blank line is white space only.
    var common_indent = Int.MAX
    var first_line = -1
    var last_line = -1
    var line_index = 0
    var position = start + 3
    while position <= stop:
        var indent = 0
        while position + indent < stop and _is_whitespace(
            bytes[unsafe_offset=position + indent]
        ):
            indent += 1
        var line_end = _line_end(data, position + indent, stop)
        if position + indent < line_end:
            if first_line < 0:
                first_line = line_index
            last_line = line_index
            if line_index != 0 and indent < common_indent:
                common_indent = indent
        position = _next_line(data, line_end, stop)
        line_index += 1
    if common_indent == Int.MAX:
        common_indent = 0
    # Second pass: the kept lines, dedented, joined with line feeds.
    var out = at
    line_index = 0
    position = start + 3
    while line_index <= last_line:
        var line_end = _line_end(data, position, stop)
        if line_index >= first_line:
            if line_index > first_line:
                dest[unsafe_offset=out] = 0x0A
                out += 1
            var from_ = position
            if line_index != 0:
                from_ = min(position + common_indent, line_end)
            out = _put_unescaped(dest, out, data, from_, line_end)
        position = _next_line(data, line_end, stop)
        line_index += 1
    return out


def _put_string_value(
    dest: _Out, at: Int, data: Span[UInt8, _], start: Int, end: Int
) -> Int:
    """Write the value of a checked string token; return the offset after
    it."""
    var out = at
    var position = start + 1
    var stop = end - 1
    var chunk = position
    position = find_byte(data, position, stop, 0x5C)
    while position < stop:
        out = _put(dest, out, data, chunk, position)
        # The lexer checked every escape, so this one is valid.
        var escape = _decode_escape(data, position)
        out = _put_codepoint(dest, out, escape.codepoint)
        position += escape.size
        chunk = position
        position = find_byte(data, position, stop, 0x5C)
    return _put(dest, out, data, chunk, stop)


def _list_end(mut out: List[UInt8], count: Int) -> _Out:
    """Reserve room for `count` more bytes; return the end of the list."""
    out.reserve(len(out) + count)
    return out.unsafe_ptr().unsafe_origin_cast[UntrackedOrigin[mut=True]]()


def block_string_value_into(
    data: Span[UInt8, _], start: Int, end: Int, mut out: List[UInt8]
):
    """Append the value of a block string token, without building lines.

    The same result as graphql-js `dedentBlockStringLines(lines).join("\\n")`
    on the raw lines.

    Args:
        data: The source bytes, padded as a `Source` pads them.
        start: The offset of the opening `\"\"\"`.
        end: The offset after the closing `\"\"\"`.
        out: The destination.
    """
    var dest = _list_end(out, end - start)
    out._len = _put_block_string(dest, len(out), data, start, end)


def block_string_value(source: Source, start: Int, end: Int) -> String:
    """Return the value of a block string token.

    Args:
        source: The source.
        start: The offset of the opening `\"\"\"`.
        end: The offset after the closing `\"\"\"`.

    Returns:
        The lines between the quotes, with `\\\"\"\"` unescaped,
        dedented and joined with `\\n`.
    """
    # The value is never longer than the token, so the string is made at
    # the token's size and then cut: one allocation, and no UTF-8 check.
    var text = String(unsafe_uninit_length=end - start)
    var dest = text.unsafe_ptr_mut().unsafe_origin_cast[
        UntrackedOrigin[mut=True]
    ]()
    var size = _put_block_string(dest, 0, Span(source.bytes), start, end)
    text.resize(unsafe_uninit_length=size)
    return text^


def string_value_into(
    data: Span[UInt8, _], start: Int, end: Int, mut out: List[UInt8]
):
    """Append the value of a checked string token, with escapes decoded.

    Args:
        data: The source bytes, padded as a `Source` pads them.
        start: The offset of the opening quote.
        end: The offset after the closing quote.
        out: The destination.
    """
    var dest = _list_end(out, end - start)
    out._len = _put_string_value(dest, len(out), data, start, end)


def string_value(source: Source, start: Int, end: Int) -> String:
    """Return the value of a checked string token, with escapes decoded.

    Args:
        source: The source.
        start: The offset of the opening quote.
        end: The offset after the closing quote.

    Returns:
        The characters between the quotes.
    """
    var text = String(unsafe_uninit_length=end - start)
    var dest = text.unsafe_ptr_mut().unsafe_origin_cast[
        UntrackedOrigin[mut=True]
    ]()
    var size = _put_string_value(dest, 0, Span(source.bytes), start, end)
    text.resize(unsafe_uninit_length=size)
    return text^


def token_value(source: Source, token: Token) -> String:
    """Return a token's value, as graphql-js `Token.value`.

    Args:
        source: The source the token is in.
        token: The token.

    Returns:
        The name or number text, the decoded string, or empty for a
        punctuator.
    """
    if token.kind == TokenKind.STRING:
        return string_value(source, token.start, token.end)
    if token.kind == TokenKind.BLOCK_STRING:
        return block_string_value(source, token.start, token.end)
    if token.kind == TokenKind.COMMENT:
        return String(source.slice(token.start + 1, token.end))
    if (
        token.kind == TokenKind.NAME
        or token.kind == TokenKind.INT
        or token.kind == TokenKind.FLOAT
    ):
        return String(source.slice(token.start, token.end))
    return String("")


def token_description(source: Source, token: Token) -> String:
    """Return a token as parser errors name it, as `getTokenDesc`.

    Args:
        source: The source the token is in.
        token: The token.

    Returns:
        The kind's description, then the value in quotes when it has one.
    """
    var text = token.kind.description()
    if (
        token.kind == TokenKind.NAME
        or token.kind == TokenKind.INT
        or token.kind == TokenKind.FLOAT
        or token.kind == TokenKind.STRING
        or token.kind == TokenKind.BLOCK_STRING
        or token.kind == TokenKind.COMMENT
    ):
        text += ' "' + token_value(source, token) + '"'
    return text^


struct Lexer(Movable):
    """Reads tokens from a source one at a time.

    `token` is the current token. `advance` moves to the next one, and
    `lookahead` reads the next one without moving.
    """

    var source: Source
    """The source being read."""
    var token: Token
    """The current token."""
    var last_token: Token
    """The token before the current one."""
    var coordinates: Bool
    """Read schema coordinate tokens: no ignored characters, and `.`."""
    var _next: Token
    var _has_next: Bool

    def __init__(out self, var source: Source):
        """Start a lexer at the start-of-file token.

        Args:
            source: The source to read.
        """
        self.source = source^
        self.token = Token(TokenKind.SOF, 0, 0)
        self.last_token = self.token
        self.coordinates = False
        self._next = self.token
        self._has_next = False

    def take_source(deinit self) -> Source:
        """End the lexer and return its source.

        Returns:
            The source it read.
        """
        return self.source^

    def advance(mut self) raises GraphQLError -> Token:
        """Move to the next token, past comments.

        Returns:
            The new current token.

        Raises:
            GraphQLError: If the source has a lexical error.
        """
        self.last_token = self.token
        if self._has_next:
            self.token = self._next
            self._has_next = False
        elif self.token.kind != TokenKind.EOF:
            self.token = self._read(self.token.end)
        return self.token

    def lookahead(mut self) raises GraphQLError -> Token:
        """Return the token after the current one, without moving.

        Returns:
            The next token, or the current one at the end of the file.

        Raises:
            GraphQLError: If the source has a lexical error.
        """
        if self.token.kind == TokenKind.EOF:
            return self.token
        if not self._has_next:
            self._next = self._read(self.token.end)
            self._has_next = True
        return self._next

    def _read(self, start: Int) raises GraphQLError -> Token:
        """Read the token that starts at or after `start`."""
        if self.coordinates:
            return self._read_coordinate(start)
        var bytes = self.source.bytes.unsafe_ptr()
        var length = self.source.length
        var position = start
        while position < length:
            var code = bytes[unsafe_offset=position]
            # Ignored tokens: white space, line terminators, commas, BOM.
            if (
                code == 0x20
                or code == 0x0A
                or code == 0x2C
                or code == 0x09
                or code == 0x0D
            ):
                position += 1
                continue
            if code == 0xEF:
                if (
                    bytes[unsafe_offset=position + 1] == 0xBB
                    and bytes[unsafe_offset=position + 2] == 0xBF
                ):
                    position += 3
                    continue
            elif code == 0x23:  # #
                position = find_byte2(
                    Span(self.source.bytes), position + 1, length, 0x0A, 0x0D
                )
                continue
            if is_name_start(code):
                var end = position + 1
                while is_name_continue(bytes[unsafe_offset=end]):
                    end += 1
                return Token(TokenKind.NAME, position, end)
            if code == 0x7B:
                return Token(TokenKind.BRACE_L, position, position + 1)
            if code == 0x7D:
                return Token(TokenKind.BRACE_R, position, position + 1)
            if code == 0x3A:
                return Token(TokenKind.COLON, position, position + 1)
            if code == 0x28:
                return Token(TokenKind.PAREN_L, position, position + 1)
            if code == 0x29:
                return Token(TokenKind.PAREN_R, position, position + 1)
            if code == 0x24:
                return Token(TokenKind.DOLLAR, position, position + 1)
            if code == 0x21:
                return Token(TokenKind.BANG, position, position + 1)
            if code == 0x40:
                return Token(TokenKind.AT, position, position + 1)
            if code == 0x5B:
                return Token(TokenKind.BRACKET_L, position, position + 1)
            if code == 0x5D:
                return Token(TokenKind.BRACKET_R, position, position + 1)
            if code == 0x3D:
                return Token(TokenKind.EQUALS, position, position + 1)
            if code == 0x7C:
                return Token(TokenKind.PIPE, position, position + 1)
            if code == 0x26:
                return Token(TokenKind.AMP, position, position + 1)
            if code == 0x2E:
                if (
                    bytes[unsafe_offset=position + 1] == 0x2E
                    and bytes[unsafe_offset=position + 2] == 0x2E
                ):
                    return Token(TokenKind.SPREAD, position, position + 3)
            elif code == 0x22:
                if (
                    bytes[unsafe_offset=position + 1] == 0x22
                    and bytes[unsafe_offset=position + 2] == 0x22
                ):
                    return self._read_block_string(position)
                return self._read_string(position)
            elif is_digit(code) or code == 0x2D:
                return self._read_number(position, code)
            var message: String
            if code == 0x27:
                message = String(
                    "Unexpected single quote character ('), did you mean to"
                    ' use a double quote (")?'
                )
            else:
                message = (
                    "Unexpected character: "
                    + print_codepoint_at(self.source, position)
                    + "."
                )
            raise syntax_error(self.source, position, message)
        return Token(TokenKind.EOF, length, length)

    def _read_coordinate(self, position: Int) raises GraphQLError -> Token:
        """Read a schema coordinate token, as graphql-js
        `SchemaCoordinateLexer`."""
        var length = self.source.length
        if position >= length:
            return Token(TokenKind.EOF, length, length)
        var code = self.source.bytes[position]
        if code == 0x2E:
            return Token(TokenKind.DOT, position, position + 1)
        if code == 0x28:
            return Token(TokenKind.PAREN_L, position, position + 1)
        if code == 0x29:
            return Token(TokenKind.PAREN_R, position, position + 1)
        if code == 0x3A:
            return Token(TokenKind.COLON, position, position + 1)
        if code == 0x40:
            return Token(TokenKind.AT, position, position + 1)
        if is_name_start(code):
            var end = position + 1
            while is_name_continue(self.source.bytes[end]):
                end += 1
            return Token(TokenKind.NAME, position, end)
        raise syntax_error(
            self.source,
            position,
            "Invalid character: "
            + print_codepoint_at(self.source, position)
            + ".",
        )

    def _read_number(
        self, start: Int, first: UInt8
    ) raises GraphQLError -> Token:
        """Read an Int or a Float, as graphql-js `readNumber`."""
        var bytes = self.source.bytes.unsafe_ptr()
        var position = start
        var code = first
        var is_float = False
        if code == 0x2D:
            position += 1
            code = bytes[unsafe_offset=position]
        if code == 0x30:
            position += 1
            code = bytes[unsafe_offset=position]
            if is_digit(code):
                raise syntax_error(
                    self.source,
                    position,
                    "Invalid number, unexpected digit after 0: "
                    + print_codepoint_at(self.source, position)
                    + ".",
                )
        else:
            position = self._read_digits(position, code)
            code = bytes[unsafe_offset=position]
        if code == 0x2E:
            is_float = True
            position += 1
            code = bytes[unsafe_offset=position]
            position = self._read_digits(position, code)
            code = bytes[unsafe_offset=position]
        if code == 0x45 or code == 0x65:
            is_float = True
            position += 1
            code = bytes[unsafe_offset=position]
            if code == 0x2B or code == 0x2D:
                position += 1
                code = bytes[unsafe_offset=position]
            position = self._read_digits(position, code)
            code = bytes[unsafe_offset=position]
        if code == 0x2E or is_name_start(code):
            raise syntax_error(
                self.source,
                position,
                "Invalid number, expected digit but got: "
                + print_codepoint_at(self.source, position)
                + ".",
            )
        if is_float:
            return Token(TokenKind.FLOAT, start, position)
        return Token(TokenKind.INT, start, position)

    def _read_digits(self, start: Int, first: UInt8) raises GraphQLError -> Int:
        """Return the offset after a run of one or more digits."""
        if not is_digit(first):
            raise syntax_error(
                self.source,
                start,
                "Invalid number, expected digit but got: "
                + print_codepoint_at(self.source, start)
                + ".",
            )
        var bytes = self.source.bytes.unsafe_ptr()
        var position = start + 1
        while is_digit(bytes[unsafe_offset=position]):
            position += 1
        return position

    def _read_string(self, start: Int) raises GraphQLError -> Token:
        """Check a quoted string and return its token."""
        var data = Span(self.source.bytes)
        var length = self.source.length
        var position = find_byte4(
            data, start + 1, length, 0x22, 0x5C, 0x0A, 0x0D
        )
        while position < length:
            var code = data[position]
            if code == 0x22:
                return Token(TokenKind.STRING, start, position + 1)
            if code != 0x5C:
                break
            var escape = _read_escape(self.source, position)
            position = find_byte4(
                data, position + escape.size, length, 0x22, 0x5C, 0x0A, 0x0D
            )
        raise syntax_error(self.source, position, "Unterminated string.")

    def _read_block_string(self, start: Int) raises GraphQLError -> Token:
        """Check a block string and return its token."""
        var data = Span(self.source.bytes)
        var bytes = data.unsafe_ptr()
        var length = self.source.length
        var position = find_byte2(data, start + 3, length, 0x22, 0x5C)
        while position < length:
            var code = bytes[unsafe_offset=position]
            var quoted = (
                bytes[unsafe_offset=position + 1] == 0x22
                and bytes[unsafe_offset=position + 2] == 0x22
            )
            if code == 0x22 and quoted:
                return Token(TokenKind.BLOCK_STRING, start, position + 3)
            if (
                code == 0x5C
                and quoted
                and bytes[unsafe_offset=position + 3] == 0x22
            ):
                position += 4
            else:
                position += 1
            position = find_byte2(data, position, length, 0x22, 0x5C)
        raise syntax_error(self.source, position, "Unterminated string.")


def read_comments(source: Source) raises GraphQLError -> List[Token]:
    """Return every comment token of a source, in order.

    Args:
        source: The source.

    Returns:
        The comment tokens; each range starts at its `#`.

    Raises:
        GraphQLError: If the source has a lexical error.
    """
    var comments = List[Token]()
    var lexer = Lexer(source.copy())
    var position = 0
    while True:
        var token = lexer._read(position)
        # Every comment sits in the ignored gap before the next token.
        var gap = position
        while gap < token.start:
            if source.bytes[gap] == 0x23:
                var end = gap + 1
                while end < source.length:
                    var next = source.bytes[end]
                    if next == 0x0A or next == 0x0D:
                        break
                    end += 1
                comments.append(Token(TokenKind.COMMENT, gap, end))
                gap = end
                continue
            gap += 1
        if token.kind == TokenKind.EOF:
            break
        position = token.end
    return comments^

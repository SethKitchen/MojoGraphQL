# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The lexer of the recovering parser.

Port of apollo-parser 0.8.6 (apollo-rs `b7eee5c`) `src/lexer/mod.rs`,
`src/lexer/cursor.rs`, `src/lexer/lookup.rs`, `src/lexer/token_kind.rs`,
`src/error.rs` and `src/limit.rs`, under the MIT arm of its MIT OR
Apache-2.0 license.

The lexer does not stop at an error. It reports the error with the upstream
message, data and byte index, and goes on with the next token. A token
limit stops it: then the stream has no `EOF` token.

**Differences from upstream.**

- `lex` returns one list. A lexer error is in the list as a token of kind
  `TokenKind.ERROR`, at the place where the upstream iterator returns it.
- The upstream `Error` is `SyntaxError`, because `Error` is a Mojo type.
- `Cursor.fast` reads the names, punctuators and comments, and the plain
  whitespace, strings and integers, without the state machine. It ends
  each token where the state machine ends it, and leaves the cursor as the
  state machine leaves it. The state machine reads every other token.
"""


@fieldwise_init
struct TokenKind(Equatable, ImplicitlyCopyable, Writable):
    """The kind of an apollo-parser token, as a type and not a bare integer."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime WHITESPACE = TokenKind(0)
    """Whitespace and line terminators."""
    comptime COMMENT = TokenKind(1)
    """A `#` comment."""
    comptime BANG = TokenKind(2)
    """The `!` token."""
    comptime DOLLAR = TokenKind(3)
    """The `$` token."""
    comptime AMP = TokenKind(4)
    """The `&` token."""
    comptime SPREAD = TokenKind(5)
    """The `...` token."""
    comptime COMMA = TokenKind(6)
    """The `,` token."""
    comptime COLON = TokenKind(7)
    """The `:` token."""
    comptime EQ = TokenKind(8)
    """The `=` token."""
    comptime AT = TokenKind(9)
    """The `@` token."""
    comptime L_PAREN = TokenKind(10)
    """The `(` token."""
    comptime R_PAREN = TokenKind(11)
    """The `)` token."""
    comptime L_BRACKET = TokenKind(12)
    """The `[` token."""
    comptime R_BRACKET = TokenKind(13)
    """The `]` token."""
    comptime L_CURLY = TokenKind(14)
    """The `{` token."""
    comptime R_CURLY = TokenKind(15)
    """The `}` token."""
    comptime PIPE = TokenKind(16)
    """The `|` token."""
    comptime EOF = TokenKind(17)
    """The end of the input."""
    comptime NAME = TokenKind(18)
    """A name."""
    comptime STRING_VALUE = TokenKind(19)
    """A string or a block string."""
    comptime INT = TokenKind(20)
    """An integer."""
    comptime FLOAT = TokenKind(21)
    """A float."""
    comptime ERROR = TokenKind(22)
    """A lexer error; the token's `start` is the error's index in the
    error list."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the token kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 22

    def write_to(self, mut writer: Some[Writer]):
        """Write the upstream `Debug` name of the kind.

        Args:
            writer: The destination.
        """
        comptime names: Array[StaticString, 23] = [
            "Whitespace",
            "Comment",
            "Bang",
            "Dollar",
            "Amp",
            "Spread",
            "Comma",
            "Colon",
            "Eq",
            "At",
            "LParen",
            "RParen",
            "LBracket",
            "RBracket",
            "LCurly",
            "RCurly",
            "Pipe",
            "Eof",
            "Name",
            "StringValue",
            "Int",
            "Float",
            "Error",
        ]
        if self.is_valid():
            writer.write(materialize[names]()[Int(self.value)])
        else:
            writer.write("<invalid>")


@fieldwise_init
struct Token(ImplicitlyCopyable, Movable):
    """One token: its kind and the byte range of its text."""

    var kind: TokenKind
    """What the token is."""
    var start: Int32
    """The byte offset of the token, or the error index of an `ERROR`."""
    var end: Int32
    """The byte offset after the token's text."""


@fieldwise_init
struct ErrorData(Equatable, ImplicitlyCopyable, Writable):
    """What an error's data is: upstream `ErrorData`."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime TEXT = ErrorData(0)
    """The text of the token at the error."""
    comptime EOF = ErrorData(1)
    """The error is at the end of the input."""
    comptime LIMIT = ErrorData(2)
    """A limit was reached."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the data kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 2

    def write_to(self, mut writer: Some[Writer]):
        """Write the kind's name.

        Args:
            writer: The destination.
        """
        if self == ErrorData.TEXT:
            writer.write("Text")
        elif self == ErrorData.EOF:
            writer.write("Eof")
        else:
            writer.write("LimitExceeded")


@fieldwise_init
struct SyntaxError(Copyable, Movable, Writable):
    """A lexer or parser error: upstream `apollo_parser::Error`."""

    var message: String
    """What is wrong, such as `expected R_CURLY, got EOF`."""
    var data: String
    """The text at the error; empty for `EOF` and `LIMIT`."""
    var kind: ErrorData
    """Whether the data is text, the end of the input, or a limit."""
    var index: Int
    """The byte offset where the error begins."""

    def is_limit(self) -> Bool:
        """Return True if the error is a token or recursion limit.

        Returns:
            Upstream `is_limit`.
        """
        return self.kind == ErrorData.LIMIT

    def is_eof(self) -> Bool:
        """Return True if the error is at the end of the input.

        Returns:
            Upstream `is_eof`.
        """
        return self.kind == ErrorData.EOF

    def length(self) -> Int:
        """Return the byte length of the error's data.

        Returns:
            The length of the text, or 0 for `EOF` and `LIMIT`.
        """
        if self.kind == ErrorData.TEXT:
            return len(self.data.as_bytes())
        return 0

    def write_to(self, mut writer: Some[Writer]):
        """Write the error as the upstream `Debug` form does.

        That is `ERROR@<start>:<end> "<message>" <data>`, with the message
        escaped as a Rust string.

        Args:
            writer: The destination.
        """
        writer.write(
            "ERROR@",
            self.index,
            ":",
            self.index + self.length(),
            " ",
            rust_debug_string(self.message),
            " ",
        )
        if self.kind == ErrorData.TEXT:
            writer.write(self.data)
        elif self.kind == ErrorData.EOF:
            writer.write("EOF")


def rust_debug_string(text: StringSlice) -> String:
    """Quote a string as Rust `{:?}` does for the messages of errors.

    Args:
        text: The string.

    Returns:
        The string in double quotes, with `"`, `\\`, tab, line feed and
        carriage return escaped, and the characters of `_escaped_in_debug`
        written as `\\u{..}`.
    """
    var bytes = text.as_bytes()
    var out = List[UInt8](capacity=len(bytes) + 2)
    out.append(34)
    var index = 0
    while index < len(bytes):
        var byte = bytes[index]
        var size = _char_len(byte)
        var code = _decode(bytes, index, size)
        var escape = _escape(code)
        if escape:
            out.extend(escape.as_bytes())
        else:
            out.extend(bytes[index : index + size])
        index += size
    out.append(34)
    return String(unsafe_from_utf8=out)


def _decode(bytes: Span[UInt8, _], index: Int, size: Int) -> Int:
    """Return the code point of the UTF-8 character at `index`."""
    var code = Int(bytes[index])
    if size > 1:
        code &= 0x7F >> size
    var position = index + 1
    while position < index + size:
        code = (code << 6) | (Int(bytes[position]) & 0x3F)
        position += 1
    return code


comptime _ESCAPED: Array[Int, 24] = [
    0x00,
    0x08,
    0x0B,
    0x0C,
    0x0E,
    0x1F,
    0x7F,
    0xA0,
    0xAD,
    0xAD,
    0x1680,
    0x1680,
    0x2000,
    0x200F,
    0x2028,
    0x202F,
    0x205F,
    0x206F,
    0x3000,
    0x3000,
    0xFEFF,
    0xFEFF,
    0xFFF9,
    0xFFFB,
]
"""The ranges of code points, as pairs of first and last, that Rust `{:?}`
writes as `\\u{..}`: the control, format and separator characters other
than the space, tab, line feed and carriage return."""


def _escape(code: Int) -> String:
    """Return how Rust `{:?}` escapes a character, or empty when it does not."""
    if code == 34:
        return '\\"'
    if code == 92:
        return "\\\\"
    if code == 9:
        return "\\t"
    if code == 10:
        return "\\n"
    if code == 13:
        return "\\r"
    var index = 0
    while index < 24:
        if (
            code >= materialize[_ESCAPED]()[index]
            and code <= materialize[_ESCAPED]()[index + 1]
        ):
            return String("\\u{", hex(code, prefix=""), "}")
        index += 2
    return String("")


@fieldwise_init
struct LexState(Equatable, ImplicitlyCopyable):
    """The state of the lexer inside one token: upstream `State`."""

    var value: UInt8
    """The state's index; see `is_valid`."""

    comptime START = LexState(0)
    """Before the first character of a token."""
    comptime IDENT = LexState(1)
    """In a name. `Cursor.fast` reads names, so the state machine does not
    use this state."""
    comptime UNICODE = LexState(2)
    """In the hex digits of a `\\u` escape."""
    comptime STRING = LexState(3)
    """In a string."""
    comptime STRING_START = LexState(4)
    """After the opening quote."""
    comptime BLOCK = LexState(5)
    """In a block string."""
    comptime BLOCK_BACKSLASH = LexState(6)
    """After a backslash in a block string."""
    comptime STRING_BACKSLASH = LexState(7)
    """After a backslash in a string."""
    comptime LEADING_ZERO = LexState(8)
    """After a leading `0`."""
    comptime INTEGER_PART = LexState(9)
    """In the digits of an integer."""
    comptime DECIMAL_POINT = LexState(10)
    """After the `.` of a float."""
    comptime FRACTIONAL_PART = LexState(11)
    """In the fractional digits of a float."""
    comptime EXPONENT_INDICATOR = LexState(12)
    """After the `e` of a float."""
    comptime EXPONENT_SIGN = LexState(13)
    """After the sign of an exponent."""
    comptime EXPONENT_DIGIT = LexState(14)
    """In the digits of an exponent."""
    comptime WHITESPACE = LexState(15)
    """In whitespace."""
    comptime COMMENT = LexState(16)
    """In a comment. `Cursor.fast` reads comments, so the state machine does
    not use this state."""
    comptime SPREAD = LexState(17)
    """After the first `.` of a spread."""
    comptime MINUS = LexState(18)
    """After a `-`."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the states.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 18


def _char_len(lead: UInt8) -> Int:
    """Return the byte length of the UTF-8 character with a lead byte."""
    if lead < 0x80:
        return 1
    if lead < 0xE0:
        return 2
    if lead < 0xF0:
        return 3
    return 4


def _punctuation(c: UInt8) -> TokenKind:
    """Return the kind of a punctuation byte, or `ERROR` for another byte."""
    if c == 123:
        return TokenKind.L_CURLY
    if c == 125:
        return TokenKind.R_CURLY
    if c == 33:
        return TokenKind.BANG
    if c == 36:
        return TokenKind.DOLLAR
    if c == 38:
        return TokenKind.AMP
    if c == 40:
        return TokenKind.L_PAREN
    if c == 41:
        return TokenKind.R_PAREN
    if c == 58:
        return TokenKind.COLON
    if c == 44:
        return TokenKind.COMMA
    if c == 91:
        return TokenKind.L_BRACKET
    if c == 93:
        return TokenKind.R_BRACKET
    if c == 61:
        return TokenKind.EQ
    if c == 64:
        return TokenKind.AT
    if c == 124:
        return TokenKind.PIPE
    return TokenKind.ERROR


def is_name_start(c: UInt8) -> Bool:
    """Return True for a byte that can start a name: `[A-Za-z_]`.

    Args:
        c: The byte.

    Returns:
        Upstream `is_namestart`.
    """
    var folded = c | 0x20
    return (folded >= 97 and folded <= 122) or c == 95


def is_name_continue(c: UInt8) -> Bool:
    """Return True for a byte that can continue a name: `[A-Za-z0-9_]`.

    Args:
        c: The byte.

    Returns:
        Upstream `is_name_continue`.
    """
    return is_name_start(c) or (c >= 48 and c <= 57)


def _is_digit(c: UInt8) -> Bool:
    """Return True for an ASCII digit."""
    return c >= 48 and c <= 57


def _is_hex(c: UInt8) -> Bool:
    """Return True for an ASCII hex digit."""
    var folded = c | 0x20
    return _is_digit(c) or (folded >= 97 and folded <= 102)


def _hex_value(c: UInt8) -> Int:
    """Return the value of an ASCII hex digit."""
    if _is_digit(c):
        return Int(c) - 48
    return Int(c | 0x20) - 87


def _is_escaped(c: UInt8) -> Bool:
    """Return True for a character that may follow `\\` in a string."""
    return (
        c == 34
        or c == 92
        or c == 47
        or c == 98
        or c == 102
        or c == 110
        or c == 114
        or c == 116
    )


def _is_whitespace(data: Span[UInt8, _], at: Int) -> Bool:
    """Return True for whitespace, a line terminator or a byte order mark."""
    var c = data[at]
    if c == 9 or c == 32 or c == 10 or c == 13:
        return True
    return (
        c == 0xEF
        and at + 2 < len(data)
        and data[at + 1] == 0xBB
        and data[at + 2] == 0xBF
    )


def _text(data: Span[UInt8, _], start: Int, end: Int) -> String:
    """Copy a byte range of the input as a string."""
    return String(unsafe_from_utf8=data[start:end])


struct Cursor(Movable):
    """The position of the lexer: upstream `Cursor`.

    `offset` is the start of the last character that `bump` returned, and
    `pos` is the start of the next character of the upstream `CharIndices`.
    A pending character is the one at `offset`, to be returned again.
    """

    var length: Int
    """The byte length of the input."""
    var index: Int
    """The start of the current token."""
    var offset: Int
    """The start of the last character read."""
    var pos: Int
    """The start of the next unread character."""
    var pending: Bool
    """Whether the character at `offset` is to be read again."""
    var has_err: Bool
    """Whether a string error waits for the end of the string."""
    var err_message: String
    """The message of the waiting error."""
    var text_start: Int
    """The start of the text that the last `*_str` call returned."""
    var text_end: Int
    """The end of that text."""

    def __init__(out self, length: Int):
        """Start at the beginning of an input.

        Args:
            length: The byte length of the input.
        """
        self.length = length
        self.index = 0
        self.offset = 0
        self.pos = 0
        self.pending = False
        self.has_err = False
        self.err_message = String("")
        self.text_start = 0
        self.text_end = 0

    def bump(mut self, data: Span[UInt8, _]) -> Int:
        """Read the next character: upstream `bump`.

        Args:
            data: The input.

        Returns:
            The start of the character, or -1 at the end of the input.
        """
        if self.pending:
            self.pending = False
            return self.offset
        if self.offset == self.length or self.pos >= self.length:
            return -1
        self.offset = self.pos
        self.pos += _char_len(data.unsafe_ptr()[unsafe_offset=self.pos])
        return self.offset

    def current_str(mut self, data: Span[UInt8, _]):
        """End the text after the last character: upstream `current_str`.

        Args:
            data: The input.
        """
        self.pending = False
        self.text_start = self.index
        if self.pos < self.length:
            self.index = self.pos
            self.offset = self.pos
            self.pending = True
            self.pos += _char_len(data.unsafe_ptr()[unsafe_offset=self.pos])
            self.text_end = self.index
        else:
            self.index = self.length - 1
            self.text_end = self.length

    def prev_str(mut self):
        """End the text before the last character: upstream `prev_str`."""
        self.text_start = self.index
        self.text_end = self.offset
        self.index = self.offset
        self.pending = self.offset < self.length

    def eatc(mut self, data: Span[UInt8, _], c: UInt8) -> Bool:
        """Read the next character if it is `c`: upstream `eatc`.

        Args:
            data: The input.
            c: An ASCII character.

        Returns:
            Whether the character was `c`. Otherwise it is pending.
        """
        if self.pos < self.length:
            self.offset = self.pos
            self.pos += _char_len(data.unsafe_ptr()[unsafe_offset=self.pos])
            if data.unsafe_ptr()[unsafe_offset=self.offset] == c:
                return True
            self.pending = True
        return False

    def drain(mut self):
        """Take the rest of the input as the text: upstream `drain`."""
        self.pending = False
        self.text_start = self.index
        self.text_end = self.length
        self.index = self.length - 1

    def add_err(mut self, message: String):
        """Keep an error for the end of the string: upstream `add_err`.

        Args:
            message: The error's message.
        """
        self.has_err = True
        self.err_message = message

    def error(
        mut self,
        data: Span[UInt8, _],
        mut errors: List[SyntaxError],
        var message: String,
        start: Int,
    ) -> Token:
        """Report an error whose data is the last text.

        Args:
            data: The input.
            errors: The error list.
            message: The error's message.
            start: The start of the token.

        Returns:
            An `ERROR` token for the error.
        """
        errors.append(
            SyntaxError(
                message^,
                _text(data, self.text_start, self.text_end),
                ErrorData.TEXT,
                start,
            )
        )
        return Token(TokenKind.ERROR, Int32(len(errors) - 1), 0)

    def done(
        mut self,
        data: Span[UInt8, _],
        mut errors: List[SyntaxError],
        kind: TokenKind,
        start: Int,
    ) -> Token:
        """Finish a token, or report the waiting error: upstream `done`.

        Args:
            data: The input.
            errors: The error list.
            kind: The token's kind.
            start: The start of the token.

        Returns:
            The token, or an `ERROR` token.
        """
        if self.has_err:
            self.has_err = False
            return self.error(data, errors, String(self.err_message), start)
        return Token(kind, Int32(start), Int32(self.text_end))

    def spread_error(
        mut self,
        data: Span[UInt8, _],
        mut errors: List[SyntaxError],
        start: Int,
    ) -> Token:
        """Report an unterminated spread: upstream
        `unterminated_spread_operator`.

        Args:
            data: The input.
            errors: The error list.
            start: The start of the token.

        Returns:
            An `ERROR` token.
        """
        if self.pending:
            self.prev_str()
        else:
            self.current_str(data)
        return self.error(data, errors, "Unterminated spread operator", start)

    @always_inline
    def fast(mut self, data: Span[UInt8, _]) -> Token:
        """Read a name, whitespace, a comment, a punctuator, a plain string
        or a plain integer without the state machine.

        Each token ends where the state machine ends it, and the cursor is
        left as the state machine leaves it. Any other token, and any token
        that could hold an error, is left to the state machine.

        Args:
            data: The input. The cursor is at the start of a token, before
                the end.

        Returns:
            The token, or a token of an invalid kind to say that the state
            machine must read it.
        """
        var p = data.unsafe_ptr()
        var length = self.length
        var at = self.pos
        var c = p[unsafe_offset=at]
        var end = at + 1
        var kind = _punctuation(c)
        if kind != TokenKind.ERROR:
            pass
        elif is_name_start(c):
            kind = TokenKind.NAME
            while end < length and is_name_continue(p[unsafe_offset=end]):
                end += 1
        elif c == 32 or c == 10 or c == 9 or c == 13:
            kind = TokenKind.WHITESPACE
            while end < length:
                var next = p[unsafe_offset=end]
                if next != 32 and next != 10 and next != 9 and next != 13:
                    break
                end += 1
            if end < length and p[unsafe_offset=end] == 0xEF:
                return Token(TokenKind(255), 0, 0)
        elif c == 35:
            kind = TokenKind.COMMENT
            while end < length:
                var next = p[unsafe_offset=end]
                if next == 10 or next == 13:
                    break
                end += 1
        elif c == 34:
            kind = TokenKind.STRING_VALUE
            while True:
                if end >= length:
                    return Token(TokenKind(255), 0, 0)
                var next = p[unsafe_offset=end]
                end += 1
                if next == 34:
                    # `""` may start a block string.
                    if end == at + 2:
                        return Token(TokenKind(255), 0, 0)
                    break
                if next == 92 or next == 10 or next == 13:
                    return Token(TokenKind(255), 0, 0)
        elif c >= 49 and c <= 57:
            kind = TokenKind.INT
            while end < length and _is_digit(p[unsafe_offset=end]):
                end += 1
            if end < length:
                var next = p[unsafe_offset=end]
                if next == 46 or is_name_start(next):
                    return Token(TokenKind(255), 0, 0)
        else:
            return Token(TokenKind(255), 0, 0)
        if end < length:
            self.index = end
            self.offset = end
            self.pos = end
        else:
            self.index = length - 1
            self.offset = length - 1
            self.pos = length
        return Token(kind, Int32(at), Int32(end))

    def advance(
        mut self, data: Span[UInt8, _], mut errors: List[SyntaxError]
    ) -> Token:
        """Read one token or one error: upstream `Cursor::advance`.

        Args:
            data: The input.
            errors: The error list.

        Returns:
            The token, or an `ERROR` token for an error.
        """
        # A pending character is the next one of the iterator again.
        if self.pending:
            self.pending = False
            self.pos = self.offset
        if self.pos == self.index and self.pos < self.length:
            var fast = self.fast(data)
            if fast.kind.is_valid():
                return fast
        var state = LexState.START
        var kind = TokenKind.EOF
        var start = self.index
        var remaining = 0
        while True:
            var at = self.bump(data)
            if at < 0:
                return self.eof(data, errors, state, kind, start)
            var c = data.unsafe_ptr()[unsafe_offset=at]
            if state == LexState.START:
                # `fast` reads every punctuator, name and comment, so they
                # never start here.
                if c != 48 and _is_digit(c):
                    kind = TokenKind.INT
                    state = LexState.INTEGER_PART
                elif c == 34:
                    kind = TokenKind.STRING_VALUE
                    state = LexState.STRING_START
                elif c == 46:
                    kind = TokenKind.SPREAD
                    state = LexState.SPREAD
                elif c == 45:
                    kind = TokenKind.INT
                    state = LexState.MINUS
                elif c == 48:
                    kind = TokenKind.INT
                    state = LexState.LEADING_ZERO
                elif _is_whitespace(data, at):
                    kind = TokenKind.WHITESPACE
                    state = LexState.WHITESPACE
                else:
                    var char = _text(data, at, at + _char_len(c))
                    self.current_str(data)
                    return self.error(
                        data,
                        errors,
                        String('Unexpected character "', char, '"'),
                        start,
                    )
            elif state == LexState.WHITESPACE:
                if not _is_whitespace(data, at):
                    self.prev_str()
                    return self.done(data, errors, kind, start)
            elif state == LexState.BLOCK:
                if c == 92:
                    state = LexState.BLOCK_BACKSLASH
                elif c == 34 and self.eatc(data, 34) and self.eatc(data, 34):
                    self.current_str(data)
                    return self.done(data, errors, kind, start)
            elif state == LexState.STRING_START:
                if c == 34:
                    if self.eatc(data, 34):
                        state = LexState.BLOCK
                        continue
                    if self.pending:
                        self.prev_str()
                    else:
                        self.current_str(data)
                    return self.done(data, errors, kind, start)
                elif c == 92:
                    state = LexState.STRING_BACKSLASH
                else:
                    state = LexState.STRING
            elif state == LexState.UNICODE:
                if c == 34:
                    self.add_err("incomplete unicode escape sequence")
                    self.current_str(data)
                    return self.done(data, errors, kind, start)
                elif not _is_hex(c):
                    self.add_err("invalid unicode escape sequence")
                    state = LexState.STRING
                elif remaining <= 1:
                    state = LexState.STRING
                    var code = 0
                    var digit = self.offset - 3
                    while digit <= self.offset:
                        code = code * 16 + _hex_value(data[digit])
                        digit += 1
                    if code >= 0xD800 and code <= 0xDFFF:
                        self.add_err(
                            "surrogate code point is invalid in unicode"
                            " escape sequence (paired surrogate not"
                            " supported yet:"
                            " https://github.com/apollographql/apollo-rs/issues/657)"
                        )
                else:
                    remaining -= 1
            elif state == LexState.STRING:
                if c == 34:
                    self.current_str(data)
                    return self.done(data, errors, kind, start)
                elif c == 10 or c == 13:
                    self.add_err("unexpected line terminator")
                elif c == 92:
                    state = LexState.STRING_BACKSLASH
            elif state == LexState.BLOCK_BACKSLASH:
                if c == 34:
                    if self.eatc(data, 34):
                        _ = self.eatc(data, 34)
                    state = LexState.BLOCK
                elif c != 92:
                    state = LexState.BLOCK
            elif state == LexState.STRING_BACKSLASH:
                if _is_escaped(c):
                    state = LexState.STRING
                elif c == 117:
                    remaining = 4
                    state = LexState.UNICODE
                else:
                    self.add_err("unexpected escaped character")
                    state = LexState.STRING
            elif state == LexState.SPREAD:
                if c == 46 and self.eatc(data, 46):
                    self.current_str(data)
                    return Token(kind, Int32(start), Int32(self.text_end))
                return self.spread_error(data, errors, start)
            else:
                var message = self.number(data, state, kind, c, at)
                if message:
                    self.current_str(data)
                    return self.error(data, errors, message^, start)
                if state == LexState.START:
                    self.prev_str()
                    return self.done(data, errors, kind, start)

    def number(
        mut self,
        data: Span[UInt8, _],
        mut state: LexState,
        mut kind: TokenKind,
        c: UInt8,
        at: Int,
    ) -> String:
        """Take one character of a number.

        Args:
            data: The input.
            state: The number state; `START` when the number ends before
                `c`.
            kind: The token kind, `INT` or `FLOAT`.
            c: The first byte of the character.
            at: The start of the character.

        Returns:
            The message of an error at `c`, or empty.
        """
        var char = _text(data, at, at + _char_len(c))
        var exponent = c == 101 or c == 69
        if state == LexState.MINUS:
            if c == 48:
                state = LexState.LEADING_ZERO
            elif _is_digit(c):
                state = LexState.INTEGER_PART
            else:
                return String("Unexpected character `", char, "`")
        elif state == LexState.LEADING_ZERO or state == LexState.INTEGER_PART:
            if state == LexState.INTEGER_PART and _is_digit(c):
                pass
            elif c == 46:
                kind = TokenKind.FLOAT
                state = LexState.DECIMAL_POINT
            elif exponent:
                kind = TokenKind.FLOAT
                state = LexState.EXPONENT_INDICATOR
            elif _is_digit(c):
                return String(
                    "Numbers must not have non-significant leading zeroes"
                )
            elif is_name_start(c):
                return String(
                    "Unexpected character `", char, "` as integer suffix"
                )
            else:
                state = LexState.START
        elif state == LexState.DECIMAL_POINT:
            if not _is_digit(c):
                return String(
                    "Unexpected character `",
                    char,
                    "`, expected fractional digit",
                )
            state = LexState.FRACTIONAL_PART
        elif state == LexState.EXPONENT_INDICATOR:
            if _is_digit(c):
                state = LexState.EXPONENT_DIGIT
            elif c == 43 or c == 45:
                state = LexState.EXPONENT_SIGN
            else:
                return String(
                    "Unexpected character `",
                    char,
                    "`, expected exponent digit or sign",
                )
        elif state == LexState.EXPONENT_SIGN:
            if not _is_digit(c):
                return String(
                    "Unexpected character `", char, "`, expected exponent digit"
                )
            state = LexState.EXPONENT_DIGIT
        else:
            # FRACTIONAL_PART and EXPONENT_DIGIT.
            if _is_digit(c):
                pass
            elif exponent and state == LexState.FRACTIONAL_PART:
                state = LexState.EXPONENT_INDICATOR
            elif c == 46 or is_name_start(c):
                return String(
                    "Unexpected character `", char, "` as float suffix"
                )
            else:
                state = LexState.START
        return String("")

    def eof(
        mut self,
        data: Span[UInt8, _],
        mut errors: List[SyntaxError],
        state: LexState,
        kind: TokenKind,
        start: Int,
    ) -> Token:
        """End a token at the end of the input: upstream `Cursor::eof`.

        Args:
            data: The input.
            errors: The error list.
            state: The state at the end.
            kind: The token's kind.
            start: The start of the token.

        Returns:
            The token, `EOF`, or an `ERROR` token.
        """
        if state == LexState.START:
            self.offset = self.length
            return Token(TokenKind.EOF, Int32(self.length), Int32(self.length))
        if state == LexState.STRING_START:
            self.current_str(data)
            return self.error(
                data,
                errors,
                "unexpected end of data while lexing string value",
                start,
            )
        if (
            state == LexState.STRING
            or state == LexState.BLOCK
            or state == LexState.UNICODE
            or state == LexState.BLOCK_BACKSLASH
            or state == LexState.STRING_BACKSLASH
        ):
            self.drain()
            return self.error(data, errors, "unterminated string value", start)
        if state == LexState.SPREAD:
            return self.spread_error(data, errors, start)
        self.current_str(data)
        if state == LexState.MINUS:
            return self.error(data, errors, 'Unexpected character "-"', start)
        if (
            state == LexState.DECIMAL_POINT
            or state == LexState.EXPONENT_INDICATOR
            or state == LexState.EXPONENT_SIGN
        ):
            return self.error(
                data, errors, "Unexpected EOF in float value", start
            )
        return Token(kind, Int32(start), Int32(self.text_end))


struct LexOutput(Movable):
    """The tokens and the errors of an input."""

    var tokens: List[Token]
    """The tokens, whitespace and comments included, with an `ERROR`
    token where the lexer reported an error."""
    var errors: List[SyntaxError]
    """The lexer errors, in order."""
    var token_high: Int
    """The upstream token `LimitTracker.high`."""

    def __init__(out self, capacity: Int):
        """Start an empty output.

        Args:
            capacity: The expected number of tokens.
        """
        self.tokens = List[Token](capacity=capacity)
        self.errors = List[SyntaxError]()
        self.token_high = 0


def lex(text: StringSlice, token_limit: Int = Int.MAX) -> LexOutput:
    """Lex an input: the upstream `Lexer` iterator, run to its end.

    Args:
        text: The input.
        token_limit: The upstream `token_limit`. Whitespace, comments and
            errors count against it.

    Returns:
        The tokens and the errors.
    """
    var data = text.as_bytes()
    var out = LexOutput(len(data) // 2 + 2)
    var cursor = Cursor(len(data))
    var count = 0
    while True:
        if count >= token_limit:
            out.errors.append(
                SyntaxError(
                    "token limit reached, aborting lexing",
                    String(""),
                    ErrorData.LIMIT,
                    cursor.index,
                )
            )
            out.tokens.append(
                Token(TokenKind.ERROR, Int32(len(out.errors) - 1), 0)
            )
            break
        count += 1
        var token = cursor.advance(data, out.errors)
        out.tokens.append(token)
        if token.kind == TokenKind.EOF:
            break
    out.token_high = count
    return out^

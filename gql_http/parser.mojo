# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""An incremental, zero-copy HTTP/1.1 message parser, after RFC 9112.

`parse_request_head` and `parse_response_head` read a start line and the
header fields. They copy no byte: a `Field` holds four offsets into the
message. `ChunkedDecoder` decodes a chunked body in place, so the content
is one span of the buffer. `RequestReader` joins them into a reader of a
stream of pipelined requests, which the server feeds with each `recv`.

The parser is strict. Each rule below names its section of RFC 9112 (or
RFC 9110). Where the RFC lets a recipient choose, the choice is the safe
one, because a lenient parse in front of a strict one is how requests are
smuggled.

- A line ends with CRLF. A bare LF or a bare CR is an error, 400 (2.2).
- Empty lines before a request line are skipped (2.2).
- The request line has one SP between its parts (3). A target is visible
  ASCII, `%x21-7E` (3.2).
- `HTTP/1.0` and `HTTP/1.1` are read. `HTTP/1.2` to `HTTP/1.9` are read as
  1.1 (RFC 9110 2.5). Another major version is 505 (2.3).
- A field line that starts with SP or HTAB (obs-fold, or white space
  before the first field) is 400 (5.2, 2.2). White space between a field
  name and its colon is 400 (5.1). A field value cannot hold a control
  byte other than HTAB, or DEL (5.5).
- An HTTP/1.1 request without exactly one `Host` field is 400. A `Host`
  value holds only the bytes of `uri-host [":" port]` (3.2).
- A `Content-Length` value is `1*DIGIT`. A second `Content-Length` field,
  or a list, is 400 (6.3).
- A request with both `Transfer-Encoding` and `Content-Length` is 400
  (6.1). So is a `Transfer-Encoding` in an HTTP/1.0 request (6.1), and one
  whose final coding is not `chunked`, or that applies `chunked` twice
  (6.3). Any other transfer coding is 501 (6.1): only `chunked` is read.
- A chunk size is `1*HEXDIG`, at most 15 digits. Chunk extensions are
  checked and ignored. A chunk without its CRLF is 400 (7.1). Trailer
  fields are checked and dropped (7.1.2).
- `Expect: 100-continue` in an HTTP/1.1 request sets `expect_continue`.
  Another expectation is 417 (RFC 9110 10.1.1). HTTP/1.0 ignores it.
- The head is at most `Limits.max_head_bytes`, and has at most
  `Limits.max_headers` fields, or 431. The content is at most
  `Limits.max_body_bytes`, or 413.

This module ports no code. It follows RFC 9112.

Differences from upstream: none; there is no upstream.
"""

from std.memory import bitcast

from gql_http.scan import (
    COLON,
    CR,
    HTAB,
    LF,
    SP,
    equals_lower,
    find_byte,
    find_field_end,
    find_target_end,
    is_host_byte,
    is_tchar,
    lower,
    move_down,
)
from gql_http.status import Method, Status, Version

comptime _MORE = 1
"""The private code of `_parse_fields` for incomplete input."""


@fieldwise_init
struct ParseState(Equatable, ImplicitlyCopyable, Writable):
    """The outcome of a parse step, as a type and not a bare integer."""

    var value: UInt8
    """The state's index; see `is_valid`."""

    comptime COMPLETE = ParseState(0)
    """The message, or its head, is complete."""
    comptime INCOMPLETE = ParseState(1)
    """More bytes are necessary."""
    comptime ERROR = ParseState(2)
    """The message is malformed or too large."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the states.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 2

    def write_to(self, mut writer: Some[Writer]):
        """Write the name of the state.

        Args:
            writer: The destination.
        """
        if self.value == 0:
            writer.write("complete")
        elif self.value == 1:
            writer.write("incomplete")
        else:
            writer.write("error")


@fieldwise_init
struct ParseResult(ImplicitlyCopyable, Writable):
    """The result of a parse step."""

    var state: ParseState
    """Whether the step completed, needs more bytes, or failed."""
    var status: Status
    """For `ERROR`, the status code of the error response."""
    var size: Int
    """For `COMPLETE`, how many bytes the step consumed."""

    @staticmethod
    def complete(size: Int) -> ParseResult:
        """Make a complete result.

        Args:
            size: How many bytes the step consumed.

        Returns:
            The result.
        """
        return ParseResult(ParseState.COMPLETE, Status.OK, size)

    @staticmethod
    def incomplete() -> ParseResult:
        """Make an incomplete result.

        Returns:
            The result.
        """
        return ParseResult(ParseState.INCOMPLETE, Status.OK, 0)

    @staticmethod
    def error(status: Status) -> ParseResult:
        """Make an error result.

        Args:
            status: The status code of the error response.

        Returns:
            The result.
        """
        return ParseResult(ParseState.ERROR, status, 0)

    def write_to(self, mut writer: Some[Writer]):
        """Write the state, and the status or the size.

        Args:
            writer: The destination.
        """
        if self.state == ParseState.ERROR:
            writer.write("error ", self.status.code)
        else:
            writer.write(self.state, " ", self.size)


@fieldwise_init
struct BodyKind(Equatable, ImplicitlyCopyable, Writable):
    """How the content of a message is delimited (RFC 9112 section 6.3)."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime NONE = BodyKind(0)
    """The message has no content."""
    comptime LENGTH = BodyKind(1)
    """`Content-Length` gives the size of the content."""
    comptime CHUNKED = BodyKind(2)
    """The content is in the chunked transfer coding."""
    comptime CLOSE = BodyKind(3)
    """The content ends when the connection closes; responses only."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 3

    def write_to(self, mut writer: Some[Writer]):
        """Write the index of the kind.

        Args:
            writer: The destination.
        """
        writer.write("BodyKind(", self.value, ")")


@fieldwise_init
struct Limits(ImplicitlyCopyable):
    """The size limits of a message, and how strict the parser is."""

    var max_head_bytes: Int
    """The most bytes of a start line and its fields, or of the trailers."""
    var max_headers: Int
    """The most header fields of a message."""
    var max_body_bytes: Int
    """The most bytes of content, after chunked decoding."""
    var max_chunk_line_bytes: Int
    """The most bytes of one chunk-size line, with its extensions."""
    var require_host: Bool
    """Whether an HTTP/1.1 request without a `Host` field is 400, as RFC
    9112 section 3.2 tells a server. A proxy test can turn it off."""

    def __init__(out self):
        """Make the default limits: a 16 KiB head, 100 fields, 16 MiB of
        content, and chunk lines of 4 KiB."""
        self.max_head_bytes = 16384
        self.max_headers = 100
        self.max_body_bytes = 16 * 1024 * 1024
        self.max_chunk_line_bytes = 4096
        self.require_host = True


@fieldwise_init
struct Field(ImplicitlyCopyable):
    """One field line: the offsets of its name and its trimmed value."""

    var name_start: Int32
    """The offset of the first byte of the name."""
    var name_end: Int32
    """The offset after the last byte of the name."""
    var value_start: Int32
    """The offset of the first byte of the value."""
    var value_end: Int32
    """The offset after the last byte of the value."""


@always_inline
def _untracked(address: Int) -> Pointer[UInt8, ImmUntrackedOrigin]:
    """Return a read-only pointer to an address, without an origin."""
    return Pointer[UInt8, ImmUntrackedOrigin](unsafe_from_address=address)


@always_inline
def _slice(
    base: Pointer[UInt8, ImmUntrackedOrigin], start: Int, end: Int
) -> StringSlice[ImmUntrackedOrigin]:
    """Return the bytes `start` to `end` from `base` as text."""
    return StringSlice(
        unsafe_from_utf8=Span[UInt8, ImmUntrackedOrigin](
            unsafe_ptr=base.unsafe_offset(start), length=end - start
        )
    )


@always_inline
def _is_digit(byte: UInt8) -> Bool:
    """Return True for `0` to `9`."""
    return byte >= 48 and byte <= 57


def _hex_value(byte: UInt8) -> Int:
    """Return the value of a hexadecimal digit, or -1."""
    if _is_digit(byte):
        return Int(byte) - 48
    var folded = lower(byte)
    if folded >= 97 and folded <= 102:
        return Int(folded) - 87
    return -1


def _token_end(p: Pointer[UInt8, _], start: Int, end: Int) -> Int:
    """Return the offset after the run of `tchar` bytes at `start`."""
    var index = start
    while index < end:
        if not is_tchar(p[unsafe_offset=index]):
            return index
        index += 1
    return end


@always_inline
def _is_ows(byte: UInt8) -> Bool:
    """Return True for SP and HTAB."""
    return byte == SP or byte == HTAB


def _skip_ows(p: Pointer[UInt8, _], start: Int, end: Int) -> Int:
    """Return the offset after the SP and HTAB bytes at `start`."""
    var index = start
    while index < end:
        if not _is_ows(p[unsafe_offset=index]):
            return index
        index += 1
    return end


def _trim_end(p: Pointer[UInt8, _], start: Int, end: Int) -> Int:
    """Return `end` moved back over the SP and HTAB bytes before it."""
    var index = end
    while index > start:
        if not _is_ows(p[unsafe_offset=index - 1]):
            return index
        index -= 1
    return start


def _same(p: Pointer[UInt8, _], start: Int, word: StaticString) -> Bool:
    """Compare the bytes at `start` with a word, case kept."""
    var w = word.unsafe_ptr()
    var index = 0
    while index < word.byte_length():
        if p[unsafe_offset=start + index] != w[unsafe_offset=index]:
            return False
        index += 1
    return True


def _prefix_matches(
    p: Pointer[UInt8, _], start: Int, end: Int, word: StaticString
) -> Bool:
    """Return True when the bytes up to `end` could begin `word`."""
    var count = min(end - start, word.byte_length())
    var w = word.unsafe_ptr()
    var index = 0
    while index < count:
        if p[unsafe_offset=start + index] != w[unsafe_offset=index]:
            return False
        index += 1
    return True


def _incomplete(size: Int, limit: Int) -> ParseResult:
    """Return INCOMPLETE, or 431 when the head has reached its limit."""
    if size >= limit:
        return ParseResult.error(Status.REQUEST_HEADER_FIELDS_TOO_LARGE)
    return ParseResult.incomplete()


def _parse_length(p: Pointer[UInt8, _], start: Int, end: Int) -> Int:
    """Read a `Content-Length` value: -1 if it is not `1*DIGIT`, -2 if it
    has more than 18 digits, else its value."""
    if start == end:
        return -1
    if end - start > 18:
        return -2
    var value = 0
    var index = start
    while index < end:
        var byte = p[unsafe_offset=index]
        if not _is_digit(byte):
            return -1
        value = value * 10 + Int(byte) - 48
        index += 1
    return value


def _parse_fields(
    p: Pointer[UInt8, _],
    start: Int,
    end: Int,
    max_fields: Int,
    mut fields: List[Field],
) -> Tuple[Int, Int]:
    """Read field lines up to the empty line that ends a head.

    Returns:
        (0, offset after the empty line), (`_MORE`, _) for incomplete
        input, or (400 or 431, _) for an error.
    """
    var i = start
    while True:
        if i >= end:
            return (_MORE, i)
        if p[unsafe_offset=i] == CR:
            if i + 1 >= end:
                return (_MORE, i)
            if p[unsafe_offset=i + 1] != LF:
                return (400, i)
            return (0, i + 2)
        var name_start = i
        i = _token_end(p, i, end)
        if i >= end:
            return (_MORE, i)
        if p[unsafe_offset=i] != COLON or i == name_start:
            return (400, i)
        var name_end = i
        var value_start = _skip_ows(p, i + 1, end)
        i = find_field_end(p, value_start, end)
        if i >= end:
            return (_MORE, i)
        if p[unsafe_offset=i] != CR:
            return (400, i)
        if i + 1 >= end:
            return (_MORE, i)
        if p[unsafe_offset=i + 1] != LF:
            return (400, i)
        if len(fields) >= max_fields:
            return (431, i)
        fields.append(
            Field(
                Int32(name_start),
                Int32(name_end),
                Int32(value_start),
                Int32(_trim_end(p, value_start, i)),
            )
        )
        i += 2


def _read_version(p: Pointer[UInt8, _], i: Int) -> Int:
    """Read `HTTP/x.y` at `i`: the minor version, -1 if malformed, or -2
    for a major version other than 1."""
    if not _same(p, i, "HTTP/"):
        return -1
    var major = p[unsafe_offset=i + 5]
    var minor = p[unsafe_offset=i + 7]
    if not _is_digit(major) or p[unsafe_offset=i + 6] != 46:
        return -1
    if not _is_digit(minor):
        return -1
    if major != 49:
        return -2
    return Int(minor) - 48


struct _Codings(Copyable):
    """What the `Transfer-Encoding` fields of a message say."""

    var seen: Bool
    var chunked: Bool
    var last_chunked: Bool
    var unknown: Bool
    var bad: Bool

    def __init__(out self):
        self.seen = False
        self.chunked = False
        self.last_chunked = False
        self.unknown = False
        self.bad = False

    def read(mut self, p: Pointer[UInt8, _], start: Int, end: Int):
        """Read one `Transfer-Encoding` value: a list of codings."""
        self.seen = True
        var i = start
        while i < end:
            var byte = p[unsafe_offset=i]
            if byte == 44 or _is_ows(byte):
                i += 1
                continue
            var token_start = i
            i = _token_end(p, i, end)
            if i == token_start:
                self.bad = True
                return
            var is_chunked = equals_lower(p, token_start, i, "chunked")
            i = _skip_ows(p, i, end)
            if i < end:
                var next = p[unsafe_offset=i]
                if next == 59 and not is_chunked:
                    # Parameters of an unknown coding; the coding is 501.
                    i = find_byte(p, i, end, 44)
                elif next != 44:
                    self.bad = True
                    return
            if is_chunked:
                if self.chunked:
                    self.bad = True
                    return
                self.chunked = True
                self.last_chunked = True
            else:
                if self.chunked:
                    self.bad = True
                    return
                self.unknown = True
                self.last_chunked = False


struct _Tokens(Copyable):
    """The `close` and `keep-alive` options of `Connection` fields."""

    var close: Bool
    var keep_alive: Bool

    def __init__(out self):
        self.close = False
        self.keep_alive = False

    def read(mut self, p: Pointer[UInt8, _], start: Int, end: Int):
        """Read one `Connection` value: a list of options."""
        var i = start
        while i < end:
            var item_end = find_byte(p, i, end, 44)
            var item_start = _skip_ows(p, i, item_end)
            var trimmed = _trim_end(p, item_start, item_end)
            var size = trimmed - item_start
            if size == 5:
                if (_folded8(p, item_start) & 0xFFFFFFFFFF) == _CLOSE:
                    self.close = True
            elif size == 10:
                if (
                    _folded8(p, item_start) == _KEEP_ALI
                    and _folded8(p, item_start + 2) == _EP_ALIVE
                ):
                    self.keep_alive = True
            i = item_end + 1


struct Request(Movable):
    """A parsed request: its method, target, version, fields and content.

    The text and the content point into the buffer of the reader that
    parsed them. They are valid until the reader reads again: in a
    handler, until it returns. Copy what must live longer.
    """

    var method: Method
    """The method; `OTHER` for an extension method."""
    var version: Version
    """The protocol version."""
    var fields: List[Field]
    """The header fields, in order."""
    var head_size: Int
    """The bytes of the request line, the fields and the empty line."""
    var content_length: Int
    """The `Content-Length` value, or -1 without one."""
    var chunked: Bool
    """Whether the content is in the chunked transfer coding."""
    var keep_alive: Bool
    """Whether the connection stays open after the response (RFC 9112
    section 9.3)."""
    var expect_continue: Bool
    """Whether the client waits for `100 Continue` before the content."""
    var _base: Pointer[UInt8, ImmUntrackedOrigin]
    var _method_start: Int
    var _method_end: Int
    var _target_start: Int
    var _target_end: Int
    var _body_start: Int
    var _body_end: Int

    def __init__(out self):
        """Make an empty request: `GET` with no target."""
        self.method = Method.GET
        self.version = Version.HTTP_1_1
        self.fields = List[Field]()
        self.head_size = 0
        self.content_length = -1
        self.chunked = False
        self.keep_alive = True
        self.expect_continue = False
        self._base = _untracked(0)
        self._method_start = 0
        self._method_end = 0
        self._target_start = 0
        self._target_end = 0
        self._body_start = 0
        self._body_end = 0

    def _reset(mut self):
        """Forget the last request, and keep the capacity of the fields."""
        self.fields.clear()
        self.content_length = -1
        self.chunked = False
        self.keep_alive = True
        self.expect_continue = False
        self._body_start = 0
        self._body_end = 0

    def method_text(self) -> StringSlice[ImmUntrackedOrigin]:
        """Return the method as it was sent, such as `POST`.

        Returns:
            The method token.
        """
        return _slice(self._base, self._method_start, self._method_end)

    def target(self) -> StringSlice[ImmUntrackedOrigin]:
        """Return the request target, such as `/graphql?query=x`.

        Returns:
            The target, as it was sent.
        """
        return _slice(self._base, self._target_start, self._target_end)

    def path(self) -> StringSlice[ImmUntrackedOrigin]:
        """Return the target up to its `?`, still percent-encoded.

        Returns:
            The path, such as `/graphql`.
        """
        var end = find_byte(
            self._base, self._target_start, self._target_end, 63
        )
        return _slice(self._base, self._target_start, end)

    def query(self) -> StringSlice[ImmUntrackedOrigin]:
        """Return the target after its `?`, still percent-encoded.

        Returns:
            The query, or an empty string when the target has no `?`.
        """
        var mark = find_byte(
            self._base, self._target_start, self._target_end, 63
        )
        var start = min(mark + 1, self._target_end)
        return _slice(self._base, start, self._target_end)

    def header_count(self) -> Int:
        """Return the number of header fields.

        Returns:
            The count.
        """
        return len(self.fields)

    def header_name(self, index: Int) -> StringSlice[ImmUntrackedOrigin]:
        """Return the name of a header field, case kept.

        Args:
            index: The field's index, from 0 to `header_count() - 1`.

        Returns:
            The name.
        """
        var field = self.fields[index]
        return _slice(self._base, Int(field.name_start), Int(field.name_end))

    def header_value(self, index: Int) -> StringSlice[ImmUntrackedOrigin]:
        """Return the value of a header field, without white space around it.

        Args:
            index: The field's index, from 0 to `header_count() - 1`.

        Returns:
            The value.
        """
        var field = self.fields[index]
        return _slice(self._base, Int(field.value_start), Int(field.value_end))

    def find_header(self, name: StringSlice, start: Int = 0) -> Int:
        """Return the index of the next field with a name, case folded.

        Args:
            name: The field name, in any case.
            start: The first index to look at.

        Returns:
            The index, or -1 when no field from `start` has the name.
        """
        var bytes = name.as_bytes()
        var w = bytes.unsafe_ptr()
        var index = start
        while index < len(self.fields):
            var field = self.fields[index]
            if _same_folded(
                self._base,
                Int(field.name_start),
                Int(field.name_end),
                w,
                len(bytes),
            ):
                return index
            index += 1
        return -1

    def header(
        self, name: StringSlice
    ) -> Optional[StringSlice[ImmUntrackedOrigin]]:
        """Return the value of the first field with a name, case folded.

        Args:
            name: The field name, in any case.

        Returns:
            The value, or None when no field has the name.
        """
        var index = self.find_header(name)
        if index < 0:
            return None
        return self.header_value(index)

    def body(self) -> Span[UInt8, ImmUntrackedOrigin]:
        """Return the content, after chunked decoding.

        Returns:
            The bytes; empty for a request without content.
        """
        return Span[UInt8, ImmUntrackedOrigin](
            unsafe_ptr=self._base.unsafe_offset(self._body_start),
            length=self._body_end - self._body_start,
        )


def _same_folded(
    p: Pointer[UInt8, _], start: Int, end: Int, w: Pointer[UInt8, _], n: Int
) -> Bool:
    """Compare bytes with ASCII case folded on both sides."""
    if end - start != n:
        return False
    var index = 0
    while index < n:
        if lower(p[unsafe_offset=start + index]) != lower(
            w[unsafe_offset=index]
        ):
            return False
        index += 1
    return True


def parse_request_head(
    data: Pointer[UInt8, _], size: Int, limits: Limits, mut request: Request
) -> ParseResult:
    """Parse a request line and its header fields.

    The bytes need not be complete: the result says INCOMPLETE until the
    empty line that ends the head has arrived. The request gets the
    offsets of its parts, relative to `data`, and its framing. It does not
    get a pointer: `RequestReader.next` sets it when the content is there.

    Args:
        data: The first byte of the message.
        size: How many bytes are at `data`.
        limits: The size limits.
        request: The request to fill; it is reset first.

    Returns:
        COMPLETE with the size of the head, INCOMPLETE, or ERROR with the
        status code to answer with.
    """
    request._reset()
    var p = data
    var n = min(size, limits.max_head_bytes)
    var i = 0
    while True:
        if i >= n:
            return _incomplete(size, limits.max_head_bytes)
        if p[unsafe_offset=i] != CR:
            break
        if i + 1 >= n:
            return _incomplete(size, limits.max_head_bytes)
        if p[unsafe_offset=i + 1] != LF:
            return ParseResult.error(Status.BAD_REQUEST)
        i += 2
    var method_start = i
    i = _token_end(p, i, n)
    if i >= n:
        return _incomplete(size, limits.max_head_bytes)
    if p[unsafe_offset=i] != SP or i == method_start:
        return ParseResult.error(Status.BAD_REQUEST)
    request.method = Method.from_bytes(
        Span[UInt8, ImmUntrackedOrigin](
            unsafe_ptr=_untracked(Int(p.unsafe_offset(method_start))),
            length=i - method_start,
        )
    )
    request._method_start = method_start
    request._method_end = i
    request._target_start = i + 1
    i = find_target_end(p, i + 1, n)
    if i >= n:
        return _incomplete(size, limits.max_head_bytes)
    if p[unsafe_offset=i] != SP or i == request._target_start:
        return ParseResult.error(Status.BAD_REQUEST)
    request._target_end = i
    i += 1
    if n - i < 10:
        if not _prefix_matches(p, i, n, "HTTP/"):
            return ParseResult.error(Status.BAD_REQUEST)
        return _incomplete(size, limits.max_head_bytes)
    var minor = _read_version(p, i)
    if minor == -2:
        return ParseResult.error(Status.HTTP_VERSION_NOT_SUPPORTED)
    if minor < 0:
        return ParseResult.error(Status.BAD_REQUEST)
    if p[unsafe_offset=i + 8] != CR or p[unsafe_offset=i + 9] != LF:
        return ParseResult.error(Status.BAD_REQUEST)
    request.version = Version(UInt8(min(minor, 1)))
    var fields = _parse_fields(p, i + 10, n, limits.max_headers, request.fields)
    if fields[0] == _MORE:
        return _incomplete(size, limits.max_head_bytes)
    if fields[0] != 0:
        return ParseResult.error(Status(fields[0]))
    request.head_size = fields[1]
    var status = _request_framing(p, request, limits)
    if status != 0:
        return ParseResult.error(Status(status))
    return ParseResult.complete(request.head_size)


@always_inline
def _folded8(p: Pointer[UInt8, _], at: Int) -> UInt64:
    """Read 8 bytes as a little-endian word, with bit 5 of each byte set.

    For a byte of a field name or a field value, this maps letters to
    lowercase and keeps `-`. Only CR maps to `-` too, and CR ends a value.
    So a name, or a `Connection` option, is compared to a lowercase word
    with one integer compare per 8 bytes. A head has at least 4 bytes
    after a name or a value, CRLF and CRLF, and a word of 4 or more bytes
    can be read as 8 bytes.
    """
    var bytes = p.unsafe_offset(at).unsafe_load[width=8]()
    return bitcast[DType.uint64, 1](bytes)[0] | 0x2020202020202020


comptime _HOST: UInt64 = 0x74736F68
"""`host`, as `_folded8` reads it, in the low 4 bytes."""
comptime _EXPECT: UInt64 = 0x746365707865
"""`expect`, in the low 6 bytes."""
comptime _CONNECTI: UInt64 = 0x697463656E6E6F63
"""`connecti`: bytes 0 to 7 of `connection`."""
comptime _NNECTION: UInt64 = 0x6E6F697463656E6E
"""`nnection`: bytes 2 to 9 of `connection`."""
comptime _CONTENT_: UInt64 = 0x2D746E65746E6F63
"""`content-`: bytes 0 to 7 of `content-length`."""
comptime _T_LENGTH: UInt64 = 0x6874676E656C2D74
"""`t-length`: bytes 6 to 13 of `content-length`."""
comptime _TRANSFER: UInt64 = 0x726566736E617274
"""`transfer`: bytes 0 to 7 of `transfer-encoding`."""
comptime _DASH_ENCODIN: UInt64 = 0x6E69646F636E652D
"""`-encodin`: bytes 8 to 15 of `transfer-encoding`."""
comptime _ENCODING: UInt64 = 0x676E69646F636E65
"""`encoding`: bytes 9 to 16 of `transfer-encoding`."""
comptime _CLOSE: UInt64 = 0x65736F6C63
"""`close`, in the low 5 bytes."""
comptime _KEEP_ALI: UInt64 = 0x696C612D7065656B
"""`keep-ali`: bytes 0 to 7 of `keep-alive`."""
comptime _EP_ALIVE: UInt64 = 0x6576696C612D7065
"""`ep-alive`: bytes 2 to 9 of `keep-alive`."""


def _request_framing(
    p: Pointer[UInt8, _], mut request: Request, limits: Limits
) -> Int:
    """Apply the field rules to a parsed head: 0, or a status code."""
    var hosts = 0
    var codings = _Codings()
    var tokens = _Tokens()
    var expect_failed = False
    var length_fields = 0
    var http11 = request.version == Version.HTTP_1_1
    var all = request.fields.unsafe_ptr()
    for k in range(len(request.fields)):
        var field = all[unsafe_offset=k]
        var ns = Int(field.name_start)
        var ne = Int(field.name_end)
        var vs = Int(field.value_start)
        var ve = Int(field.value_end)
        var size = ne - ns
        # One test skips the names that no rule reads: their sizes are not
        # 4, 6, 10, 14 or 17.
        if size > 17 or ((0x24450 >> size) & 1) == 0:
            continue
        if size == 4:
            if (_folded8(p, ns) & 0xFFFFFFFF) == _HOST:
                hosts += 1
                if not _valid_host(p, vs, ve):
                    return 400
        elif size == 6:
            if (_folded8(p, ns) & 0xFFFFFFFFFFFF) == _EXPECT and http11:
                if equals_lower(p, vs, ve, "100-continue"):
                    request.expect_continue = True
                else:
                    expect_failed = True
        elif size == 10:
            if (
                _folded8(p, ns) == _CONNECTI
                and _folded8(p, ns + 2) == _NNECTION
            ):
                tokens.read(p, vs, ve)
        elif size == 14:
            if (
                _folded8(p, ns) == _CONTENT_
                and _folded8(p, ns + 6) == _T_LENGTH
            ):
                length_fields += 1
                request.content_length = _parse_length(p, vs, ve)
                if request.content_length == -1 or length_fields > 1:
                    return 400
        else:
            # The size is 17.
            if (
                _folded8(p, ns) == _TRANSFER
                and _folded8(p, ns + 8) == _DASH_ENCODIN
                and _folded8(p, ns + 9) == _ENCODING
            ):
                codings.read(p, vs, ve)
    if codings.bad:
        return 400
    if codings.seen:
        if not http11 or length_fields > 0:
            return 400
        if not codings.last_chunked:
            return 400
        if codings.unknown:
            return 501
        request.chunked = True
    if hosts > 1:
        return 400
    if hosts == 0 and http11 and limits.require_host:
        return 400
    if request.content_length == -2:
        return 413
    if request.content_length > limits.max_body_bytes:
        return 413
    if expect_failed:
        return 417
    if http11:
        request.keep_alive = not tokens.close
    else:
        request.keep_alive = tokens.keep_alive and not tokens.close
    return 0


def _valid_host(p: Pointer[UInt8, _], start: Int, end: Int) -> Bool:
    """Return True when every byte of a `Host` value is a host byte."""
    var index = start
    while index < end:
        if not is_host_byte(p[unsafe_offset=index]):
            return False
        index += 1
    return True


@fieldwise_init
struct _ChunkPhase(Equatable, ImplicitlyCopyable):
    """Where a chunked decoder is in the coding."""

    var value: UInt8

    comptime SIZE = _ChunkPhase(0)
    comptime DATA = _ChunkPhase(1)
    comptime DATA_END = _ChunkPhase(2)
    comptime TRAILER = _ChunkPhase(3)

    def is_valid(self) -> Bool:
        return self.value <= 3


struct ChunkedDecoder(Copyable):
    """A resumable decoder of the chunked transfer coding (RFC 9112 7.1).

    It decodes in place: the data of each chunk moves down over the chunk
    lines before it, so the content is one span from `start`.
    """

    var read: Int
    """The offset of the next byte to decode."""
    var write: Int
    """The offset after the last decoded byte."""
    var start: Int
    """The offset of the first byte of the content."""
    var _phase: _ChunkPhase
    var _remaining: Int
    var _trailer_start: Int

    def __init__(out self):
        """Make a decoder at offset 0."""
        self.read = 0
        self.write = 0
        self.start = 0
        self._phase = _ChunkPhase.SIZE
        self._remaining = 0
        self._trailer_start = 0

    def reset(mut self, start: Int):
        """Start a new chunked content.

        Args:
            start: The offset of the first chunk-size line.
        """
        self.read = start
        self.write = start
        self.start = start
        self._phase = _ChunkPhase.SIZE
        self._remaining = 0
        self._trailer_start = 0

    def rebase(mut self) -> Int:
        """Forget the decoded content, so that the buffer can shrink.

        The caller takes the content from `start` to `write` first. Then
        it moves the bytes from the old `read` offset down to offset 0, and
        decodes on. A stream of chunks needs no larger buffer than one
        read.

        Returns:
            The old `read` offset: the count of bytes to drop.
        """
        var shift = self.read
        self._trailer_start -= shift
        self.read = 0
        self.write = 0
        self.start = 0
        return shift

    def decoded(self) -> Int:
        """Return how many content bytes the decoder has produced.

        Returns:
            The count.
        """
        return self.write - self.start

    def feed(
        mut self, data: Pointer[mut=True, UInt8, _], end: Int, limits: Limits
    ) -> ParseResult:
        """Decode the bytes up to `end`.

        Args:
            data: The buffer that the offsets are relative to.
            end: The offset after the last byte that has arrived.
            limits: The size limits.

        Returns:
            COMPLETE with the offset after the last chunk and its trailers,
            INCOMPLETE, or ERROR with 400, 413 or 431.
        """
        while True:
            if self._phase == _ChunkPhase.SIZE:
                var window = min(end, self.read + limits.max_chunk_line_bytes)
                var lf = find_byte(data, self.read, window, LF)
                if lf >= window:
                    if window - self.read >= limits.max_chunk_line_bytes:
                        return ParseResult.error(Status.BAD_REQUEST)
                    return ParseResult.incomplete()
                var size = _chunk_size(data, self.read, lf)
                if size == -1:
                    return ParseResult.error(Status.BAD_REQUEST)
                if size == -2 or self.decoded() + size > limits.max_body_bytes:
                    return ParseResult.error(Status.CONTENT_TOO_LARGE)
                self.read = lf + 1
                if size == 0:
                    self._phase = _ChunkPhase.TRAILER
                    self._trailer_start = self.read
                else:
                    self._remaining = size
                    self._phase = _ChunkPhase.DATA
            elif self._phase == _ChunkPhase.DATA:
                var take = min(end - self.read, self._remaining)
                move_down(data, self.write, self.read, take)
                self.write += take
                self.read += take
                self._remaining -= take
                if self._remaining > 0:
                    return ParseResult.incomplete()
                self._phase = _ChunkPhase.DATA_END
            elif self._phase == _ChunkPhase.DATA_END:
                if end - self.read < 2:
                    return ParseResult.incomplete()
                if data[unsafe_offset=self.read] != CR:
                    return ParseResult.error(Status.BAD_REQUEST)
                if data[unsafe_offset=self.read + 1] != LF:
                    return ParseResult.error(Status.BAD_REQUEST)
                self.read += 2
                self._phase = _ChunkPhase.SIZE
            else:
                var limit = self._trailer_start + limits.max_head_bytes
                var window = min(end, limit)
                var lf = find_byte(data, self.read, window, LF)
                if lf >= window:
                    if window >= limit:
                        return ParseResult.error(
                            Status.REQUEST_HEADER_FIELDS_TOO_LARGE
                        )
                    return ParseResult.incomplete()
                if lf == self.read or data[unsafe_offset=lf - 1] != CR:
                    return ParseResult.error(Status.BAD_REQUEST)
                var line_end = lf - 1
                var line_start = self.read
                self.read = lf + 1
                if line_end == line_start:
                    return ParseResult.complete(self.read)
                if not _valid_field_line(data, line_start, line_end):
                    return ParseResult.error(Status.BAD_REQUEST)


def _chunk_size(p: Pointer[UInt8, _], start: Int, lf: Int) -> Int:
    """Read a chunk-size line that ends at `lf`: -1 if malformed, -2 if it
    has more than 15 digits, else the size."""
    if lf == start:
        return -1
    var cr = lf - 1
    if p[unsafe_offset=cr] != CR:
        return -1
    var value = 0
    var i = start
    while i < cr:
        var digit = _hex_value(p[unsafe_offset=i])
        if digit < 0:
            break
        if i - start == 15:
            return -2
        value = value * 16 + digit
        i += 1
    if i == start:
        return -1
    var j = _skip_ows(p, i, cr)
    if j < cr:
        if p[unsafe_offset=j] != 59:
            return -1
        if find_field_end(p, j, cr) != cr:
            return -1
    elif j != i:
        return -1
    return value


def _valid_field_line(p: Pointer[UInt8, _], start: Int, end: Int) -> Bool:
    """Return True for `token ":" OWS field-value OWS` from `start` to
    `end`, which is a CR."""
    var colon = _token_end(p, start, end)
    if colon == start or colon >= end:
        return False
    if p[unsafe_offset=colon] != COLON:
        return False
    return find_field_end(p, colon + 1, end) == end


@fieldwise_init
struct _ReadPhase(Equatable, ImplicitlyCopyable):
    """Which part of a request a reader waits for."""

    var value: UInt8

    comptime HEAD = _ReadPhase(0)
    comptime LENGTH = _ReadPhase(1)
    comptime CHUNKED = _ReadPhase(2)

    def is_valid(self) -> Bool:
        return self.value <= 2


struct RequestReader(Movable):
    """A buffer that reads a stream of pipelined requests.

    Put bytes in with `reserve`, `write_pointer` and `commit`, or with
    `append`. Then call `next`. When it is COMPLETE, `request` is the next
    request with its content. Call `consume` when you are done with it.
    """

    var buffer: List[UInt8]
    """The bytes; the unread ones are from `start` to `end`."""
    var start: Int
    """The offset of the first byte of the current message."""
    var end: Int
    """The offset after the last byte that has arrived."""
    var request: Request
    """The current request; complete after `next` returns COMPLETE."""
    var limits: Limits
    """The size limits."""
    var needs_continue: Bool
    """True after `next` when the client waits for `100 Continue`: the
    request has `Expect: 100-continue`, its content has not arrived, and
    `continue_sent` is False."""
    var continue_sent: Bool
    """Set it when you send `100 Continue` for the current request."""
    var _phase: _ReadPhase
    var _scanned: Int
    var _size: Int
    var _decoder: ChunkedDecoder

    def __init__(out self, limits: Limits, capacity: Int = 4096):
        """Make an empty reader.

        Args:
            limits: The size limits.
            capacity: The first size of the buffer.
        """
        self.buffer = List[UInt8](length=max(capacity, 16), fill=0)
        self.start = 0
        self.end = 0
        self.request = Request()
        self.limits = limits
        self.needs_continue = False
        self.continue_sent = False
        self._phase = _ReadPhase.HEAD
        self._scanned = 0
        self._size = 0
        self._decoder = ChunkedDecoder()

    def buffered(self) -> Int:
        """Return the count of bytes that have arrived and are not consumed.

        Returns:
            `end - start`.
        """
        return self.end - self.start

    def reserve(mut self, room: Int):
        """Make room for at least `room` more bytes after `end`.

        The unread bytes can move to the front of the buffer, so call it
        only between requests or while `next` is INCOMPLETE.

        Args:
            room: The count of bytes.
        """
        if self.start == self.end:
            self.start = 0
            self.end = 0
        if len(self.buffer) - self.end >= room:
            return
        if self.start > 0:
            var count = self.end - self.start
            move_down(self.buffer.unsafe_ptr(), 0, self.start, count)
            self.start = 0
            self.end = count
        if len(self.buffer) - self.end < room:
            self.buffer.resize(max(len(self.buffer) * 2, self.end + room), 0)

    def space(self) -> Int:
        """Return the room after `end`.

        Returns:
            The count of bytes that `write_pointer` can take.
        """
        return len(self.buffer) - self.end

    def write_pointer(mut self) -> Pointer[UInt8, MutUntrackedOrigin]:
        """Return where the next bytes go: the byte at `end`.

        Returns:
            The pointer; valid until the next `reserve`.
        """
        return Pointer[UInt8, MutUntrackedOrigin](
            unsafe_from_address=Int(self.buffer.unsafe_ptr()) + self.end
        )

    def commit(mut self, count: Int):
        """Record that `count` bytes have arrived at `write_pointer`.

        Args:
            count: The count of bytes.
        """
        self.end += count

    def append(mut self, data: Span[UInt8, _]):
        """Copy bytes to the end of the buffer.

        Args:
            data: The bytes.
        """
        self.reserve(len(data))
        var p = self.write_pointer()
        var index = 0
        while index < len(data):
            p[unsafe_offset=index] = data[index]
            index += 1
        self.commit(len(data))

    def next(mut self) -> ParseResult:
        """Parse the next request as far as the bytes go.

        Returns:
            COMPLETE with the size of the message, INCOMPLETE, or ERROR
            with the status code to answer with. After an ERROR, answer and
            close the connection: the framing of the stream is lost.
        """
        var address = Int(self.buffer.unsafe_ptr()) + self.start
        var base = Pointer[UInt8, MutUntrackedOrigin](
            unsafe_from_address=address
        )
        var size = self.end - self.start
        if self._phase == _ReadPhase.HEAD:
            if find_byte(base, self._scanned, size, LF) == size:
                self._scanned = size
                return _incomplete(size, self.limits.max_head_bytes)
            var head = parse_request_head(base, size, self.limits, self.request)
            if head.state != ParseState.COMPLETE:
                self._scanned = size
                return head
            if self.request.chunked:
                self._phase = _ReadPhase.CHUNKED
                self._decoder.reset(head.size)
            else:
                self._phase = _ReadPhase.LENGTH
        var head_size = self.request.head_size
        if self._phase == _ReadPhase.LENGTH:
            var length = max(self.request.content_length, 0)
            if size - head_size < length:
                self.needs_continue = (
                    self.request.expect_continue and not self.continue_sent
                )
                return ParseResult.incomplete()
            self.request._body_start = head_size
            self.request._body_end = head_size + length
            self._size = head_size + length
        else:
            var body = self._decoder.feed(base, size, self.limits)
            if body.state == ParseState.INCOMPLETE:
                self.needs_continue = (
                    self.request.expect_continue and not self.continue_sent
                )
                return body
            if body.state == ParseState.ERROR:
                return body
            self.request._body_start = head_size
            self.request._body_end = self._decoder.write
            self._size = body.size
        self.needs_continue = False
        self.request._base = _untracked(address)
        return ParseResult.complete(self._size)

    def reset(mut self, capacity: Int = 4096):
        """Drop every byte, for a new connection.

        A buffer that grew past four times `capacity` shrinks back.

        Args:
            capacity: The size of the buffer to keep.
        """
        if len(self.buffer) > 4 * capacity:
            self.buffer = List[UInt8](length=capacity, fill=0)
        self.start = 0
        self.end = 0
        self._size = 0
        self.consume()

    def consume(mut self):
        """Drop the current request, after `next` returned COMPLETE."""
        self.start += self._size
        self._size = 0
        self._scanned = 0
        self._phase = _ReadPhase.HEAD
        self.needs_continue = False
        self.continue_sent = False


struct ResponseHead(Movable):
    """A parsed status line and its fields, for the client."""

    var status: Status
    """The status code."""
    var version: Version
    """The protocol version."""
    var fields: List[Field]
    """The header fields, in order."""
    var head_size: Int
    """The bytes of the status line, the fields and the empty line."""
    var content_length: Int
    """The `Content-Length` value, or -1 without one."""
    var chunked: Bool
    """Whether the final transfer coding is `chunked`."""
    var keep_alive: Bool
    """Whether the connection stays open after the response."""
    var reason_start: Int
    """The offset of the reason phrase."""
    var reason_end: Int
    """The offset after the reason phrase."""

    def __init__(out self):
        """Make an empty head."""
        self.status = Status.OK
        self.version = Version.HTTP_1_1
        self.fields = List[Field]()
        self.head_size = 0
        self.content_length = -1
        self.chunked = False
        self.keep_alive = True
        self.reason_start = 0
        self.reason_end = 0

    def _reset(mut self):
        """Forget the last head, and keep the capacity of the fields."""
        self.fields.clear()
        self.content_length = -1
        self.chunked = False
        self.keep_alive = True

    def body_kind(self, method: Method) -> BodyKind:
        """Return how the content of this response is delimited.

        RFC 9112 section 6.3: a response to `HEAD`, a 1xx, 204 or 304 has
        no content; then `Transfer-Encoding`, then `Content-Length`; else
        the content ends at the close of the connection.

        Args:
            method: The method of the request.

        Returns:
            The kind.
        """
        if method == Method.HEAD or not self.status.has_body():
            return BodyKind.NONE
        if self.chunked:
            return BodyKind.CHUNKED
        if self.content_length >= 0:
            return BodyKind.LENGTH
        return BodyKind.CLOSE


def parse_response_head(
    data: Pointer[UInt8, _], size: Int, limits: Limits, mut head: ResponseHead
) -> ParseResult:
    """Parse a status line and its header fields.

    The reason phrase can be empty, and the SP before an empty one can be
    missing. A `Transfer-Encoding` overrides a `Content-Length`. A
    response with both fields makes the connection close after it (RFC
    9112 section 6.3). A chunked response alone keeps the connection.

    Args:
        data: The first byte of the message.
        size: How many bytes are at `data`.
        limits: The size limits.
        head: The head to fill; it is reset first.

    Returns:
        COMPLETE with the size of the head, INCOMPLETE, or ERROR with 502.
    """
    head._reset()
    var p = data
    var n = min(size, limits.max_head_bytes)
    var bad = ParseResult.error(Status.BAD_GATEWAY)
    if n < 13:
        if not _prefix_matches(p, 0, n, "HTTP/"):
            return bad
        if size >= limits.max_head_bytes:
            return bad
        return ParseResult.incomplete()
    var minor = _read_version(p, 0)
    if minor < 0 or p[unsafe_offset=8] != SP:
        return bad
    var code = 0
    var i = 9
    while i < 12:
        var byte = p[unsafe_offset=i]
        if not _is_digit(byte):
            return bad
        code = code * 10 + Int(byte) - 48
        i += 1
    head.status = Status(code)
    head.version = Version(UInt8(min(minor, 1)))
    if not head.status.is_valid():
        return bad
    if p[unsafe_offset=12] == SP:
        i = 13
    elif p[unsafe_offset=12] != CR:
        return bad
    head.reason_start = i
    i = find_field_end(p, i, n)
    if i + 1 >= n:
        if size >= limits.max_head_bytes:
            return bad
        return ParseResult.incomplete()
    if p[unsafe_offset=i] != CR or p[unsafe_offset=i + 1] != LF:
        return bad
    head.reason_end = i
    var fields = _parse_fields(p, i + 2, n, limits.max_headers, head.fields)
    if fields[0] == _MORE:
        if size >= limits.max_head_bytes:
            return bad
        return ParseResult.incomplete()
    if fields[0] != 0:
        return bad
    head.head_size = fields[1]
    if not _response_framing(p, head):
        return bad
    return ParseResult.complete(head.head_size)


def _response_framing(p: Pointer[UInt8, _], mut head: ResponseHead) -> Bool:
    """Apply the field rules to a response head; False when malformed."""
    var codings = _Codings()
    var tokens = _Tokens()
    var length_fields = 0
    for k in range(len(head.fields)):
        var field = head.fields[k]
        var ns = Int(field.name_start)
        var ne = Int(field.name_end)
        var vs = Int(field.value_start)
        var ve = Int(field.value_end)
        if equals_lower(p, ns, ne, "content-length"):
            length_fields += 1
            head.content_length = _parse_length(p, vs, ve)
            if head.content_length < 0 or length_fields > 1:
                return False
        elif equals_lower(p, ns, ne, "transfer-encoding"):
            codings.read(p, vs, ve)
        elif equals_lower(p, ns, ne, "connection"):
            tokens.read(p, vs, ve)
    if codings.bad:
        return False
    var http11 = head.version == Version.HTTP_1_1
    if http11:
        head.keep_alive = not tokens.close
    else:
        head.keep_alive = tokens.keep_alive and not tokens.close
    if codings.seen:
        if codings.unknown or not codings.chunked:
            return False
        if length_fields > 0:
            # RFC 9112 section 6.3: the coding wins, and the connection
            # cannot be trusted after a message with both fields.
            head.keep_alive = False
            head.content_length = -1
        head.chunked = True
    return True

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The `multipart/mixed` format of incremental delivery over HTTP.

A server sends the result of an operation with `@defer` or `@stream` as
parts of one response (RFC 2046 section 5.1). The content type is
`multipart/mixed; boundary="-"; deferSpec=20220824`. Each part has the
field `content-type: application/json; charset=utf-8` and one JSON
payload. `MultipartEncoder` writes the parts, and `MultipartDecoder` reads
them incrementally on the client.

The encoder writes the bytes of Apollo Server 4 `runHttpQuery`. The
decoder reads what meros 1.3 reads. The module ports no code.
"""

from gql_http.error import ErrorKind, HttpError
from gql_http.scan import CR, LF, equals_ignore_case, find_byte, move_down


comptime INCREMENTAL_CONTENT_TYPE = (
    'multipart/mixed; boundary="-"; deferSpec=20220824'
)
"""The `Content-Type` of an incremental response."""
comptime INCREMENTAL_ACCEPT = (
    "multipart/mixed;deferSpec=20220824, application/json"
)
"""The `Accept` of a client that takes an incremental response."""
comptime JSON_PART_TYPE = "application/json; charset=utf-8"
"""The `content-type` of each part."""


def boundary_of(content_type: StringSlice) raises HttpError -> String:
    """Return the `boundary` parameter of a `multipart/mixed` type.

    The parameter can be a token or a quoted string (RFC 9110 5.6.6).

    Args:
        content_type: The `Content-Type` value.

    Returns:
        The boundary.

    Raises:
        HttpError: `PROTOCOL` when the type is not `multipart/mixed`, or
            has no valid boundary.
    """
    var bytes = content_type.as_bytes()
    var n = len(bytes)
    var semi = find_byte(bytes.unsafe_ptr(), 0, n, 59)
    var media = _trim(bytes, 0, semi)
    if not equals_ignore_case(
        media, StaticString("multipart/mixed").as_bytes()
    ):
        raise HttpError(ErrorKind.PROTOCOL, "not a multipart/mixed type", 0)
    var pos = semi
    while pos < n:
        var start = pos + 1
        pos = find_byte(bytes.unsafe_ptr(), start, n, 59)
        var eq = find_byte(bytes.unsafe_ptr(), start, pos, 61)
        var name = _trim(bytes, start, eq)
        if eq == pos or not equals_ignore_case(
            name, StaticString("boundary").as_bytes()
        ):
            continue
        var value = _trim(bytes, eq + 1, pos)
        if len(value) >= 2 and value[0] == 34 and value[len(value) - 1] == 34:
            value = value[1 : len(value) - 1]
        if len(value) == 0 or len(value) > 70:
            break
        return String(unsafe_from_utf8=value)
    raise HttpError(ErrorKind.PROTOCOL, "no multipart boundary", 0)


def _trim(
    bytes: Span[UInt8, _], start: Int, end: Int
) -> Span[UInt8, bytes.origin]:
    """Return the bytes from `start` to `end` without outer spaces."""
    var a = start
    var b = end
    while a < b and (bytes[a] == 32 or bytes[a] == 9):
        a += 1
    while b > a and (bytes[b - 1] == 32 or bytes[b - 1] == 9):
        b -= 1
    return bytes[a:b]


struct MultipartEncoder(Movable):
    """Writes the parts of a `multipart/mixed` content."""

    var boundary: String
    """The boundary; `-` for incremental delivery."""
    var parts: Int
    """The count of parts written."""
    var ended: Bool
    """Whether the close delimiter is written."""

    def __init__(out self, boundary: StringSlice = "-"):
        """Make an encoder.

        Args:
            boundary: The boundary of the content type.
        """
        self.boundary = String(boundary)
        self.parts = 0
        self.ended = False

    def part(
        mut self,
        mut out: List[UInt8],
        body: Span[UInt8, _],
        content_type: StringSlice = JSON_PART_TYPE,
    ) raises HttpError:
        """Append one part: the delimiter, its field and its body.

        Args:
            out: The destination.
            body: The body of the part, such as one JSON payload.
            content_type: The `content-type` of the part.

        Raises:
            HttpError: `USAGE` after `end`.
        """
        if self.ended:
            raise HttpError(ErrorKind.USAGE, "the multipart content ended", 0)
        out.extend(StaticString("\r\n--").as_bytes())
        out.extend(self.boundary.as_bytes())
        out.extend(StaticString("\r\ncontent-type: ").as_bytes())
        out.extend(content_type.as_bytes())
        out.extend(StaticString("\r\n\r\n").as_bytes())
        out.extend(body)
        self.parts += 1

    def end(mut self, mut out: List[UInt8]):
        """Append the close delimiter, once.

        Args:
            out: The destination.
        """
        if self.ended:
            return
        out.extend(StaticString("\r\n--").as_bytes())
        out.extend(self.boundary.as_bytes())
        out.extend(StaticString("--\r\n").as_bytes())
        self.ended = True


@fieldwise_init
struct MultipartPart(Copyable, Movable):
    """One part of a `multipart/mixed` content."""

    var content_type: String
    """The value of its `content-type` field; empty when it has none."""
    var headers: String
    """Its header lines, as they came, without the last CRLF."""
    var body: List[UInt8]
    """Its body."""

    def text(self) -> String:
        """Return the body as text.

        Returns:
            The body, read as UTF-8.
        """
        return String(unsafe_from_utf8=self.body)


struct _Phase(Equatable, ImplicitlyCopyable):
    """Where the decoder is in the content."""

    var value: UInt8

    comptime DELIMITER = _Phase(0)
    comptime AFTER = _Phase(1)
    comptime HEAD = _Phase(2)
    comptime BODY = _Phase(3)
    comptime DONE = _Phase(4)

    @implicit
    def __init__(out self, value: Int):
        self.value = UInt8(value)

    def is_valid(self) -> Bool:
        """Return True for one of the five phases.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 4


struct MultipartDecoder(Movable):
    """Reads the parts of a `multipart/mixed` content as its bytes arrive.

    The preamble and the epilogue are dropped (RFC 2046 section 5.1.1).
    """

    var boundary: String
    """The boundary."""
    var parts: List[MultipartPart]
    """The parts that are complete and not taken."""
    var max_part_bytes: Int
    """The largest part; 16 MiB at first."""
    var _buf: List[UInt8]
    var _delim: List[UInt8]
    var _phase: _Phase
    var _start: Int
    var _scan: Int
    var _headers: String

    def __init__(out self, boundary: StringSlice = "-"):
        """Make a decoder for a boundary.

        Args:
            boundary: The boundary of the content type.
        """
        self.boundary = String(boundary)
        self.parts = List[MultipartPart]()
        self.max_part_bytes = 16 << 20
        # A CRLF before the content lets the first delimiter be at offset 0.
        self._buf = List[UInt8]()
        self._buf.extend(StaticString("\r\n").as_bytes())
        self._delim = List[UInt8]()
        self._delim.extend(StaticString("\r\n--").as_bytes())
        self._delim.extend(self.boundary.as_bytes())
        self._phase = _Phase.DELIMITER
        self._start = 0
        self._scan = 0
        self._headers = String()

    def done(self) -> Bool:
        """Tell if the close delimiter has arrived.

        Returns:
            True after the close delimiter.
        """
        return self._phase == _Phase.DONE

    def feed(mut self, data: Span[UInt8, _]) raises HttpError -> Int:
        """Decode more bytes of the content.

        Args:
            data: The bytes, in the order they arrived.

        Returns:
            The count of parts in `parts`.

        Raises:
            HttpError: `LIMIT` for a part over `max_part_bytes`.
        """
        if self._phase != _Phase.DONE:
            self._buf.extend(data)
            self._run()
        return len(self.parts)

    def take(mut self) -> List[MultipartPart]:
        """Take the parts that are complete.

        Returns:
            The parts, in order; `parts` becomes empty.
        """
        var out = self.parts^
        self.parts = List[MultipartPart]()
        return out^

    def finish(self) raises HttpError:
        """Check the end of the content, when the stream has ended.

        Raises:
            HttpError: `PROTOCOL` when the close delimiter did not arrive.
        """
        if self._phase != _Phase.DONE:
            raise HttpError(
                ErrorKind.PROTOCOL, "the multipart content ended early", 0
            )

    def _run(mut self) raises HttpError:
        """Decode what the buffer holds."""
        while True:
            if self._phase == _Phase.AFTER:
                if len(self._buf) < 2:
                    return
                if self._buf[0] == 45 and self._buf[1] == 45:
                    self._phase = _Phase.DONE
                    self._buf.clear()
                    return
                var n = len(self._buf)
                var lf = find_byte(self._buf.unsafe_ptr(), 0, n, LF)
                if lf == n:
                    return
                self._drop(lf + 1)
                self._phase = _Phase.HEAD
                self._start = 0
                self._scan = 0
            elif self._phase == _Phase.HEAD:
                if len(self._buf) < 2:
                    return
                var body = 2
                var head_end = 0
                if self._buf[0] != CR or self._buf[1] != LF:
                    var at = _find(
                        self._buf,
                        self._scan,
                        StaticString("\r\n\r\n").as_bytes(),
                    )
                    if at < 0:
                        self._check(len(self._buf))
                        return
                    head_end = at
                    body = at + 4
                self._headers = String(
                    unsafe_from_utf8=Span(self._buf)[0:head_end]
                )
                self._phase = _Phase.BODY
                self._start = body
                self._scan = body
            else:
                var at = _find(self._buf, self._scan, self._delim)
                if at < 0:
                    if self._phase == _Phase.BODY:
                        self._check(len(self._buf) - self._start)
                    else:
                        # Drop the preamble that cannot hold a delimiter.
                        self._drop(self._scan)
                    return
                if self._phase == _Phase.BODY:
                    var part = List[UInt8]()
                    part.extend(Span(self._buf)[self._start : at])
                    self.parts.append(
                        MultipartPart(
                            _content_type(self._headers),
                            self._headers^,
                            part^,
                        )
                    )
                    self._headers = String()
                self._drop(at + len(self._delim))
                self._phase = _Phase.AFTER
                self._start = 0
                self._scan = 0

    def _check(self, size: Int) raises HttpError:
        """Refuse a part over `max_part_bytes`."""
        if size > self.max_part_bytes:
            raise HttpError(ErrorKind.LIMIT, "the part is too large", 0)

    def _drop(mut self, count: Int):
        """Drop the first `count` bytes of the buffer."""
        var rest = len(self._buf) - count
        move_down(self._buf.unsafe_ptr(), 0, count, rest)
        self._buf.resize(rest, 0)
        self._start -= count
        self._scan -= count


def _content_type(headers: String) -> String:
    """Return the value of the `content-type` line of a part head."""
    var bytes = headers.as_bytes()
    var n = len(bytes)
    var start = 0
    while start < n:
        var lf = find_byte(bytes.unsafe_ptr(), start, n, LF)
        var colon = find_byte(bytes.unsafe_ptr(), start, lf, 58)
        var name = _trim(bytes, start, colon)
        if colon < lf and equals_ignore_case(
            name, StaticString("content-type").as_bytes()
        ):
            return String(unsafe_from_utf8=_trim(bytes, colon + 1, lf))
        start = lf + 1
    return String()


def _find(buf: List[UInt8], mut scan: Int, pattern: Span[UInt8, _]) -> Int:
    """Find a pattern that starts with CR, from `scan` on; -1 when it is
    not there yet. `scan` moves past the bytes that cannot start it."""
    var p = buf.unsafe_ptr()
    var end = len(buf)
    var m = len(pattern)
    var pos = scan
    while True:
        var at = find_byte(p, pos, end, CR)
        if end - at < m:
            scan = at
            return -1
        var i = 1
        while i < m and p[unsafe_offset=at + i] == pattern[i]:
            i += 1
        if i == m:
            return at
        pos = at + 1

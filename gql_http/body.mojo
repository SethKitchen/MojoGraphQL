# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Content that a response makes over time, and its chunked framing.

A `BodySource` makes the content of a response chunk by chunk. The owner of
the connection polls the source. `BodyPump` frames each chunk with
`Transfer-Encoding: chunked` (RFC 9112 section 7.1) and sends it without a
block. `ChunkedDecoder` reads a chunked body incrementally on the client.

The module ports no code. hyper `proto::h1::encode` and `decode` are the
model of the framing.
"""

from gql_http.scan import move_down
from gql_http.socket import EAGAIN, EINTR, Sys


comptime _CRLF = "\r\n"
comptime _LAST = "0\r\n\r\n"
comptime _DEFAULT_HIGH_WATER = 1 << 16


@fieldwise_init
struct BodyPoll(Equatable, ImplicitlyCopyable, Writable):
    """The result of one poll of a body source."""

    var value: UInt8
    """The code: 0 to 3."""

    comptime READY = BodyPoll(0)
    """The source appended bytes, and can have more."""
    comptime PENDING = BodyPoll(1)
    """The source has nothing now. Poll it again later."""
    comptime DONE = BodyPoll(2)
    """The content is complete."""
    comptime ERROR = BodyPoll(3)
    """The source failed. The content is incomplete."""

    def is_valid(self) -> Bool:
        """Tell if the code is one of the four results.

        Returns:
            True for `READY`, `PENDING`, `DONE` and `ERROR`.
        """
        return self.value <= 3

    def write_to(self, mut writer: Some[Writer]):
        """Write the name of the result.

        Args:
            writer: The destination.
        """
        if self == BodyPoll.READY:
            writer.write("READY")
        elif self == BodyPoll.PENDING:
            writer.write("PENDING")
        elif self == BodyPoll.DONE:
            writer.write("DONE")
        elif self == BodyPoll.ERROR:
            writer.write("ERROR")
        else:
            writer.write("BodyPoll(", Int(self.value), ")")


trait BodySource(Deinitable, Movable):
    """A source of content that comes over time."""

    def poll_body(mut self, mut out: List[UInt8]) raises -> BodyPoll:
        """Append the next bytes of the content to `out`, if there are any.

        Args:
            out: The destination of the bytes.

        Returns:
            `READY` after it appends bytes, `PENDING` when it has none now,
            `DONE` at the end, and `ERROR` when it fails. A source can
            append bytes and return `DONE` in one call.

        Raises:
            An error is the same as `ERROR`.
        """
        ...


def append_hex(mut out: List[UInt8], value: Int):
    """Append a non-negative integer in lowercase hexadecimal.

    Args:
        out: The destination.
        value: The integer.
    """
    var shift = 0
    while (value >> (shift + 4)) != 0:
        shift += 4
    while shift >= 0:
        var digit = (value >> shift) & 15
        if digit < 10:
            out.append(UInt8(48 + digit))
        else:
            out.append(UInt8(87 + digit))
        shift -= 4


def append_chunk(mut out: List[UInt8], data: Span[UInt8, _]):
    """Append one chunk: the size, CRLF, the data and CRLF.

    Empty data appends nothing, because an empty chunk ends the content.

    Args:
        out: The destination.
        data: The data of the chunk.
    """
    if len(data) == 0:
        return
    append_hex(out, len(data))
    out.extend(StaticString(_CRLF).as_bytes())
    out.extend(data)
    out.extend(StaticString(_CRLF).as_bytes())


def append_last_chunk(mut out: List[UInt8]):
    """Append the last chunk and the empty trailer section.

    Args:
        out: The destination.
    """
    out.extend(StaticString(_LAST).as_bytes())


struct BodyPump[S: BodySource](Movable):
    """Polls a body source, frames its chunks and sends them to a socket.

    The pump keeps at most about `high_water` bytes that are not sent. Over
    that mark it does not poll the source, so a slow client slows the
    source.

    Parameters:
        S: The type of the source.
    """

    var source: Self.S
    """The source of the content."""
    var out: List[UInt8]
    """The framed bytes that are not sent yet, from `sent` on."""
    var sent: Int
    """The count of bytes of `out` that are sent."""
    var state: BodyPoll
    """`PENDING` while the source runs, then `DONE` or `ERROR`."""
    var chunked: Bool
    """Whether the pump frames chunks. False for an HTTP/1.0 client, which
    gets the bytes as they are, and an end of the connection at the end."""
    var high_water: Int
    """The count of bytes not sent over which the pump stops polling."""
    var _scratch: List[UInt8]

    def __init__(
        out self,
        var source: Self.S,
        chunked: Bool = True,
        high_water: Int = _DEFAULT_HIGH_WATER,
    ):
        """Make a pump for a source.

        Args:
            source: The source of the content.
            chunked: Whether to frame chunks.
            high_water: The count of bytes not sent over which the pump
                stops polling.
        """
        self.source = source^
        self.out = List[UInt8]()
        self.sent = 0
        self.state = BodyPoll.PENDING
        self.chunked = chunked
        self.high_water = high_water
        self._scratch = List[UInt8]()

    def buffered(self) -> Int:
        """Return the count of framed bytes that are not sent.

        Returns:
            The count.
        """
        return len(self.out) - self.sent

    def finished(self) -> Bool:
        """Tell if the source has ended and every byte is sent.

        Returns:
            True after `DONE` or `ERROR`, when nothing waits.
        """
        return self.state != BodyPoll.PENDING and self.buffered() == 0

    def fill(mut self) -> BodyPoll:
        """Poll the source until it waits, ends, or the buffer is full.

        Returns:
            `PENDING` when the source waits, `READY` when the buffer is
            full and the source can have more, and `DONE` or `ERROR` when
            the content has ended.
        """
        while self.state == BodyPoll.PENDING:
            if self.buffered() >= self.high_water:
                return BodyPoll.READY
            self._scratch.clear()
            var result: BodyPoll
            try:
                result = self.source.poll_body(self._scratch)
            except:
                result = BodyPoll.ERROR
            if result == BodyPoll.ERROR:
                self.state = BodyPoll.ERROR
                return BodyPoll.ERROR
            self._frame()
            if result == BodyPoll.DONE:
                if self.chunked:
                    append_last_chunk(self.out)
                self.state = BodyPoll.DONE
                return BodyPoll.DONE
            if result == BodyPoll.PENDING:
                return BodyPoll.PENDING
        return self.state

    def _frame(mut self):
        """Move the scratch bytes to `out`, framed as one chunk."""
        if self.chunked:
            append_chunk(self.out, self._scratch)
        else:
            self.out.extend(Span(self._scratch))

    def send(mut self, mut sys: Sys, fd: Int) -> Int:
        """Send the framed bytes, as far as the socket takes them.

        Args:
            sys: The system calls.
            fd: The connection.

        Returns:
            The count of bytes sent, 0 when the socket is full, or a
            negative error number when the connection has failed.
        """
        var rest = self.buffered()
        if rest == 0:
            return 0
        var n = sys.send(
            fd, self.out.unsafe_ptr().unsafe_offset(self.sent), rest
        )
        if n == -EAGAIN or n == -EINTR:
            return 0
        if n < 0:
            return n
        self.sent += n
        if self.sent == len(self.out):
            self.out.clear()
            self.sent = 0
        elif self.sent >= self.high_water:
            var left = len(self.out) - self.sent
            move_down(self.out.unsafe_ptr(), 0, self.sent, left)
            self.out.resize(left, 0)
            self.sent = 0
        return n

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Event streams as streamed HTTP content.

`SseBody` writes the events of a `gql_stream` stream as `next` messages
and one `complete`. `MultipartBody` writes them as the parts of a
`multipart/mixed` content, the format of incremental delivery over HTTP.
`HeldBodies` keeps one body for each held response of a `gql_http`
handler. The bridge lives here, so that `gql_http` needs no `gql_stream`.

The module ports no code.
"""

from gql_http.body import BodyPoll, BodySource
from gql_http.multipart import MultipartEncoder
from gql_sse.event import StreamEvent, print_message
from gql_stream.stream import AnyStream
from gql_stream.waker import Waker


struct SseBody(BodySource):
    """The events of a stream as `text/event-stream` messages of the
    distinct connections mode."""

    var stream: AnyStream
    """The events; each one is the data of a `next` message."""
    var waker: Waker
    """The waker of each poll."""
    var _done: Bool

    def __init__(out self, var stream: AnyStream) raises:
        """Make a body.

        Args:
            stream: The events.

        Raises:
            Error: Never; the waker opens no descriptor.
        """
        self.stream = stream^
        self.waker = Waker.noop()
        self._done = False

    def poll_body(mut self, mut out: List[UInt8]) raises -> BodyPoll:
        """Write the messages of the events that are ready.

        Args:
            out: The destination.

        Returns:
            `READY` after messages, `PENDING`, `DONE` after `complete`, or
            `ERROR` when the stream fails.

        Raises:
            Error: Never.
        """
        if self._done:
            return BodyPoll.DONE
        var poll = self.stream.poll_next(self.waker)
        if poll.is_pending():
            return BodyPoll.PENDING
        if poll.is_error():
            return BodyPoll.ERROR
        if poll.is_done():
            print_message(out, StreamEvent.COMPLETE, "")
            self._done = True
            return BodyPoll.DONE
        print_message(out, StreamEvent.NEXT, poll.value().to_json())
        return BodyPoll.READY


struct MultipartBody(BodySource):
    """The events of a stream as the parts of a `multipart/mixed` content."""

    var stream: AnyStream
    """The events; each one is the body of a part."""
    var encoder: MultipartEncoder
    """The encoder of the parts."""
    var waker: Waker
    """The waker of each poll."""

    def __init__(
        out self, var stream: AnyStream, boundary: StringSlice = "-"
    ) raises:
        """Make a body.

        Args:
            stream: The events.
            boundary: The boundary of the content type.

        Raises:
            Error: Never; the waker opens no descriptor.
        """
        self.stream = stream^
        self.encoder = MultipartEncoder(boundary)
        self.waker = Waker.noop()

    def poll_body(mut self, mut out: List[UInt8]) raises -> BodyPoll:
        """Write the parts of the events that are ready.

        Args:
            out: The destination.

        Returns:
            `READY` after a part, `PENDING`, `DONE` after the close
            delimiter, or `ERROR` when the stream fails.

        Raises:
            Error: Never.
        """
        if self.encoder.ended:
            return BodyPoll.DONE
        var poll = self.stream.poll_next(self.waker)
        if poll.is_pending():
            return BodyPoll.PENDING
        if poll.is_error():
            return BodyPoll.ERROR
        if poll.is_done():
            self.encoder.end(out)
            return BodyPoll.DONE
        self.encoder.part(out, poll.value().to_json().as_bytes())
        return BodyPoll.READY


struct HeldBodies[S: BodySource](Movable):
    """One body for each held response of a handler, by its connection.

    A handler adds a body in `handle`, polls it in `poll_body`, and drops
    it in `body_closed`.

    Parameters:
        S: The type of the bodies.
    """

    var _bodies: List[Optional[Self.S]]

    def __init__(out self):
        """Make an empty table."""
        self._bodies = List[Optional[Self.S]]()

    def add(mut self, id: Int, var body: Self.S):
        """Keep the body of a connection.

        Args:
            id: The connection, from `ResponseWriter.connection`.
            body: The body.
        """
        while len(self._bodies) <= id:
            self._bodies.append(None)
        self._bodies[id] = body^

    def count(self) -> Int:
        """Return the count of bodies.

        Returns:
            The count.
        """
        var count = 0
        var i = 0
        while i < len(self._bodies):
            if self._bodies[i]:
                count += 1
            i += 1
        return count

    def poll(mut self, id: Int, mut out: List[UInt8]) raises -> BodyPoll:
        """Poll the body of a connection; drop it when it ends.

        Args:
            id: The connection.
            out: The destination.

        Returns:
            The result of the body, or `DONE` when there is none.

        Raises:
            Error: The errors of the body.
        """
        if id >= len(self._bodies) or not self._bodies[id]:
            return BodyPoll.DONE
        var result = self._bodies[id].value().poll_body(out)
        if result == BodyPoll.DONE or result == BodyPoll.ERROR:
            self._bodies[id] = None
        return result

    def drop(mut self, id: Int):
        """Drop the body of a connection, if any.

        Args:
            id: The connection.
        """
        if id < len(self._bodies):
            self._bodies[id] = None

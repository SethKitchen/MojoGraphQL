# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""`AnyStream`, an event stream of any type, and `ListStream`, a stream of
known values.

Mojo has no trait objects. `AnyStream` boxes a stream on the heap and keeps
two functions for its type: poll and drop. One `List[AnyStream]` can then
hold streams of many types, as an event loop or a resolver needs. A poll
costs one indirect call.

`ListStream` yields the events of a list, then ends, or fails with a
message. It is the Mojo form of an `async function*` generator with
`yield` statements and an optional `throw`, as the graphql-js tests write
them.

No code is ported.

Differences from upstream: none; there is no upstream.
"""

from std.memory import Layout, alloc

from gql_stream.poll import Event, EventStream, Poll
from gql_stream.waker import Waker

comptime _PollFn = def(Int, mut Waker) thin -> Poll
comptime _CloseFn = def(Int) thin -> None
comptime _DropFn = def(Int) thin -> None


def _poll_box[S: EventStream](address: Int, mut waker: Waker) -> Poll:
    """Poll the boxed stream at an address."""
    return Pointer[S, MutAnyOrigin](unsafe_from_address=address)[].poll_next(
        waker
    )


def _close_box[S: EventStream](address: Int):
    """Close the boxed stream at an address."""
    Pointer[S, MutAnyOrigin](unsafe_from_address=address)[].close()


def _drop_box[S: EventStream](address: Int):
    """Destroy the boxed stream at an address, and free its memory."""
    var pointer = Pointer[S, MutAnyOrigin](unsafe_from_address=address)
    _ = pointer.unsafe_take_pointee()
    pointer.unsafe_free()


struct AnyStream(EventStream):
    """An event stream of any type, boxed on the heap."""

    var _address: Int
    var _poll: _PollFn
    var _close: _CloseFn
    var _drop: _DropFn

    def __init__[S: EventStream](out self, var stream: S):
        """Box a stream.

        Parameters:
            S: The type of the stream.

        Args:
            stream: The stream; the box owns it.
        """
        var pointer = alloc(Layout[S](count=1)).unsafe_leak()
        pointer.unsafe_write(stream^)
        self._address = Int(pointer)
        self._poll = _poll_box[S]
        self._close = _close_box[S]
        self._drop = _drop_box[S]

    def __deinit__(deinit self):
        """Destroy the boxed stream. It does not call `close()`."""
        self._drop(self._address)

    def poll_next(mut self, mut waker: Waker) -> Poll:
        """Poll the boxed stream.

        Args:
            waker: The waker of this poll.

        Returns:
            The result of the boxed stream.
        """
        return self._poll(self._address, waker)

    def close(mut self):
        """Close the boxed stream."""
        self._close(self._address)


struct ListStream(EventStream):
    """Yields the events of a list, then ends or fails."""

    var events: List[Event]
    """The events, in order."""
    var error: String
    """The message to fail with after the events; empty to end."""
    var _next: Int
    var _closed: Bool

    def __init__(out self, var events: List[Event], error: String = ""):
        """Make a stream of known events.

        Args:
            events: The events, in order.
            error: The message to fail with after the last event, as a
                generator that throws; empty to end with `DONE`.
        """
        self.events = events^
        self.error = error
        self._next = 0
        self._closed = False

    @staticmethod
    def of_json(texts: List[String], error: String = "") raises -> ListStream:
        """Make a stream of JSON texts.

        Args:
            texts: One JSON text for each event.
            error: The message to fail with after the last event.

        Returns:
            The stream.

        Raises:
            JsonError: When a text is not JSON.
        """
        var events = List[Event](capacity=len(texts))
        var index = 0
        while index < len(texts):
            events.append(Event.parse(texts[index]))
            index += 1
        return ListStream(events^, error)

    def poll_next(mut self, mut waker: Waker) -> Poll:
        """Return the next event, then `DONE` or the error once.

        Args:
            waker: Not kept; the stream is never `PENDING`.

        Returns:
            The next event, `DONE`, or `ERROR` once.
        """
        if self._closed:
            return Poll.done()
        if self._next < len(self.events):
            self._next += 1
            return Poll.ready(self.events[self._next - 1].copy())
        self._closed = True
        if self.error:
            return Poll.error(self.error)
        return Poll.done()

    def close(mut self):
        """End the stream; the events that are left are dropped."""
        self._closed = True
        self.events.clear()

    def closed(self) -> Bool:
        """Return True after `close()`, `DONE` or the error.

        Returns:
            Whether the stream has ended.
        """
        return self._closed

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Pull-based event streams: `Event`, `Poll` and the `EventStream` trait.

An `EventStream` is the Mojo form of a JavaScript `AsyncIterator`. Its
owner pulls it with `poll_next(waker)`, and it answers at once:

- `READY` with an `Event`: the next value, as `{ value, done: false }`.
- `PENDING`: no value yet. The stream keeps the waker, and wakes it when it
  can make progress. The owner polls it again after the wake.
- `DONE`: the end, as `{ value: undefined, done: true }`.
- `ERROR` with a message: the stream failed, as a rejected `next()`.

After `DONE` or `ERROR`, each later poll returns `DONE`. `close()` is the
JavaScript `return()`: it ends the stream and frees what it holds, such as
its subscriptions. It is idempotent, and later polls return `DONE`.

An `Event` is one JSON value, shared and read-only: an `ArcPointer` to a
`gql_json` `JsonDocument`, and the value is the root of the document. A
copy of an event costs a reference count, so one publish can go to many
subscribers without copies. A GraphQL payload and a GraphQL response are
both JSON values, so one event type serves the source streams and the
response streams of subscriptions.

The model is the Rust `futures::Stream` trait; the semantics of the
results are those of the ECMAScript async iterator protocol. No code is
ported.

Differences from upstream: none; there is no upstream.
"""

from std.memory import ArcPointer

from gql_json.parser import parse
from gql_json.value import JsonDocument, JsonKind
from gql_json.writer import stringify
from gql_stream.waker import Waker


@fieldwise_init
struct PollState(Equatable, ImplicitlyCopyable, Writable):
    """The state of one poll of an event stream."""

    var value: UInt8
    """The state's index; see `is_valid`."""

    comptime READY = PollState(0)
    """The stream has a value."""
    comptime PENDING = PollState(1)
    """The stream has no value yet, and keeps the waker."""
    comptime DONE = PollState(2)
    """The stream has ended."""
    comptime ERROR = PollState(3)
    """The stream failed; the poll has a message."""

    def is_valid(self) -> Bool:
        """Return True for one of the four states.

        Returns:
            Whether the index names a state.
        """
        return self.value <= 3

    def write_to(self, mut writer: Some[Writer]):
        """Write the name of the state.

        Args:
            writer: The writer.
        """
        if self.value == 0:
            writer.write("READY")
        elif self.value == 1:
            writer.write("PENDING")
        elif self.value == 2:
            writer.write("DONE")
        elif self.value == 3:
            writer.write("ERROR")
        else:
            writer.write("PollState(", self.value, ")")


struct Event(Copyable, Movable):
    """One JSON value of a stream, shared and read-only."""

    var document: ArcPointer[JsonDocument]
    """The document; its root is the value."""

    def __init__(out self, var document: JsonDocument):
        """Wrap a document; its root is the value.

        Args:
            document: The document.
        """
        self.document = ArcPointer(document^)

    @staticmethod
    def parse(text: StringSlice) raises -> Event:
        """Parse a JSON text into an event.

        Args:
            text: The JSON text.

        Returns:
            The event.

        Raises:
            JsonError: When the text is not JSON.
        """
        return Event(parse(text))

    def root(self) -> Int:
        """Return the node of the value in `document`.

        Returns:
            The root node.
        """
        return self.document[].root

    def kind(self) -> JsonKind:
        """Return the kind of the value.

        Returns:
            The JSON kind.
        """
        return self.document[].kind(self.document[].root)

    def to_json(self) -> String:
        """Write the value as `JSON.stringify` does.

        Returns:
            The JSON text.
        """
        return stringify(self.document[], self.document[].root)

    def same(self, other: Event) -> Bool:
        """Return True when both events share one document.

        Args:
            other: The other event.

        Returns:
            Whether the two are copies of one event.
        """
        return Int(Pointer(to=self.document[])) == Int(
            Pointer(to=other.document[])
        )


struct Poll(Copyable, Movable):
    """The result of one `poll_next`: graphql-js `IteratorResult`, with
    `PENDING` for a value that has not come yet."""

    var state: PollState
    """The state."""
    var event: Optional[Event]
    """The value of a `READY` poll; None otherwise."""
    var message: String
    """The message of an `ERROR` poll; empty otherwise."""

    def __init__(
        out self, state: PollState, var event: Optional[Event], message: String
    ):
        """Make a poll from its parts.

        Args:
            state: The state.
            event: The value, for `READY`.
            message: The message, for `ERROR`.
        """
        self.state = state
        self.event = event^
        self.message = message

    @staticmethod
    def ready(var event: Event) -> Poll:
        """Make a `READY` poll.

        Args:
            event: The value.

        Returns:
            The poll.
        """
        return Poll(PollState.READY, Optional(event^), "")

    @staticmethod
    def pending() -> Poll:
        """Make a `PENDING` poll.

        Returns:
            The poll.
        """
        return Poll(PollState.PENDING, None, "")

    @staticmethod
    def done() -> Poll:
        """Make a `DONE` poll.

        Returns:
            The poll.
        """
        return Poll(PollState.DONE, None, "")

    @staticmethod
    def error(message: String) -> Poll:
        """Make an `ERROR` poll.

        Args:
            message: What failed.

        Returns:
            The poll.
        """
        return Poll(PollState.ERROR, None, message)

    def is_ready(self) -> Bool:
        """Return True for a value.

        Returns:
            Whether the state is `READY`.
        """
        return self.state == PollState.READY

    def is_pending(self) -> Bool:
        """Return True for no value yet.

        Returns:
            Whether the state is `PENDING`.
        """
        return self.state == PollState.PENDING

    def is_done(self) -> Bool:
        """Return True for the end of the stream.

        Returns:
            Whether the state is `DONE`.
        """
        return self.state == PollState.DONE

    def is_error(self) -> Bool:
        """Return True for a failure.

        Returns:
            Whether the state is `ERROR`.
        """
        return self.state == PollState.ERROR

    def value(self) raises -> Event:
        """Return the value of a `READY` poll.

        Returns:
            A copy of the event; it shares the document.

        Raises:
            Error: When the poll is not `READY`.
        """
        if not self.event:
            raise Error("Poll has no value: ", self.state)
        return self.event.value().copy()


trait EventStream(Deinitable, Movable):
    """A stream of events that its owner pulls: graphql-js
    `AsyncIterator`, in the Rust `Stream` model."""

    def poll_next(mut self, mut waker: Waker) -> Poll:
        """Try to get the next value, without waiting.

        On `PENDING`, the stream keeps `waker` and wakes it later. It must
        not return `PENDING` without a way to wake it.

        Args:
            waker: The waker of this poll.

        Returns:
            The next value, `PENDING`, `DONE` or `ERROR`.
        """
        ...

    def close(mut self):
        """End the stream, as `AsyncIterator.return()` does.

        Idempotent; each later poll returns `DONE`.
        """
        ...

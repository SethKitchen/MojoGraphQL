# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Helpers of the incremental delivery tests: run an operation with
`experimental_execute_incrementally` and read every payload."""

from std.memory import ArcPointer
from std.testing import assert_equal

from gql_execution.execute import (
    ExecutionArgs,
    ResolveInfo,
    default_field_resolver,
)
from gql_execution.incremental import experimental_execute_incrementally
from gql_execution.incremental_results import subsequent_document
from gql_execution.value import UNDEFINED, ValueKind, Values
from gql_json.parser import parse as parse_json
from gql_json.value import NO_NODE as NO_JSON
from gql_json.writer import stringify
from gql_stream.poll import Event, EventStream, Poll
from gql_stream.stream import AnyStream, ListStream
from gql_language.parser import parse
from gql_schema.definition import Schema
from gql_stream.waker import Waker

comptime DEFER_STREAM_SDL = """
directive @defer(if: Boolean! = true, label: String) on FRAGMENT_SPREAD | INLINE_FRAGMENT
directive @stream(initialCount: Int! = 0, if: Boolean! = true, label: String) on FIELD
"""
"""The graphql-js 17 `@defer` and `@stream` definitions, as SDL."""


def throwing_resolver(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """Resolve a field as `default_field_resolver` does, but raise for a
    property `{"__throw": message}`: the form of an upstream resolver that
    throws.

    Args:
        values: The arena.
        source: The source object.
        args: The arguments.
        info: The field.

    Returns:
        The property.

    Raises:
        Error: The message of a `__throw` property.
    """
    var value = default_field_resolver(values, source, args, info)
    if values.kind(value) == ValueKind.OBJECT:
        var message = values.get(value, "__throw")
        if message != UNDEFINED:
            raise Error(values.string(message))
        var items = values.get(value, "__stream")
        if items != UNDEFINED:
            return values.add_stream(
                AnyStream(
                    _list_stream(values, items, values.get(value, "__error"))
                )
            )
    return value


def _list_stream(values: Values, items: Int, error: Int) raises -> ListStream:
    """Return the event stream of a `__stream` marker: the JSON array text
    of its items, and the `__error` message that ends it, if any."""
    var document = parse_json(String(values.string(items)))
    var texts = List[String]()
    var item = document.first(document.root)
    while item != NO_JSON:
        texts.append(stringify(document, item))
        item = document.next(item)
    var message = String("")
    if error != UNDEFINED:
        message = String(values.string(error))
    return ListStream.of_json(texts, message)


def root_value(mut values: Values, text: String) raises -> Int:
    """Add a value from its JSON text.

    Args:
        values: The arena.
        text: The JSON text.

    Returns:
        The value's index.

    Raises:
        Error: For text that is not JSON.
    """
    var document = parse_json(text)
    return values.add_json(document, document.root)


def payloads(
    schema: Schema, query: String, var args: ExecutionArgs
) raises -> List[String]:
    """Execute incrementally and return the JSON of each payload: the
    single result, or the initial result and each subsequent result.

    Args:
        schema: The schema.
        query: The operation.
        args: The inputs.

    Returns:
        The JSON texts, in order.

    Raises:
        Error: As execution raises, or when the stream is `PENDING`.
    """
    var results = experimental_execute_incrementally(
        schema, parse(query), args^
    )
    var out = List[String]()
    out.append(results.to_json())
    if not results.is_incremental():
        return out^
    var stream = results.take_subsequent_results()
    var waker = Waker.noop()
    while True:
        var payload = stream.poll_payload(waker)
        if not payload:
            if not stream.is_done():
                raise Error("The subsequent results are PENDING.")
            return out^
        # The text of the payload and its JSON document must agree.
        var text = payload.value().to_json()
        var document = subsequent_document(payload.value())
        assert_equal(stringify(document, document.root), text)
        out.append(text)


def expect(
    schema: Schema,
    query: String,
    root: String,
    expected: List[String],
    early: Bool = False,
) raises:
    """Check the payloads of an operation with a JSON root value.

    Args:
        schema: The schema.
        query: The operation.
        root: The JSON of the root value.
        expected: The JSON of each payload, as graphql-js 17 gives it.
        early: The graphql-js `enableEarlyExecution`.

    Raises:
        Error: When a payload differs.
    """
    var args = ExecutionArgs()
    args.enable_early_execution = early
    args.root_value = root_value(args.values, root)
    args.resolvers.field_resolver(throwing_resolver)
    var got = payloads(schema, query, args^)
    var index = 0
    while index < len(expected) and index < len(got):
        assert_equal(got[index], expected[index])
        index += 1
    assert_equal(len(got), len(expected))


struct ProbeState(Movable):
    """What a `ProbeStream` shares with its test: the upstream iterator
    with a spy on `next` and on `return`."""

    var events: List[Event]
    """The items, in order."""
    var ends: Bool
    """After the items: True gives `DONE`; False gives `PENDING`, as a
    `next()` promise that never resolves."""
    var polls: Int
    """The count of polls: the upstream `next()` calls."""
    var closes: Int
    """The count of `close()` calls: the upstream `return()` spy."""

    def __init__(out self, texts: List[String], ends: Bool) raises:
        """Make the state of a stream of JSON texts.

        Args:
            texts: One JSON text for each item.
            ends: Whether the stream ends after the items.

        Raises:
            Error: When a text is not JSON.
        """
        self.events = List[Event](capacity=len(texts))
        for text in texts:
            self.events.append(Event.parse(text))
        self.ends = ends
        self.polls = 0
        self.closes = 0


struct ProbeStream(EventStream):
    """An event stream that counts its polls and its closes in a state
    that the test keeps."""

    var state: ArcPointer[ProbeState]
    """The shared state."""
    var _next: Int
    var _ended: Bool

    def __init__(out self, state: ArcPointer[ProbeState]):
        """Share a state.

        Args:
            state: The state.
        """
        self.state = state
        self._next = 0
        self._ended = False

    def poll_next(mut self, mut waker: Waker) -> Poll:
        """Return the next item, then `DONE` or `PENDING`.

        Args:
            waker: Not kept: a `PENDING` stream never wakes.

        Returns:
            The next item, `DONE` or `PENDING`.
        """
        self.state[].polls += 1
        if self._ended:
            return Poll.done()
        if self._next < len(self.state[].events):
            self._next += 1
            return Poll.ready(self.state[].events[self._next - 1].copy())
        if self.state[].ends:
            self._ended = True
            return Poll.done()
        return Poll.pending()

    def close(mut self):
        """Count the close, and end the stream."""
        self.state[].closes += 1
        self._ended = True


def probe(
    mut values: Values, texts: List[String], ends: Bool
) raises -> Tuple[Int, ArcPointer[ProbeState]]:
    """Add a `ProbeStream` to an arena.

    Args:
        values: The arena.
        texts: One JSON text for each item.
        ends: Whether the stream ends after the items.

    Returns:
        The value of the stream, and its state.

    Raises:
        Error: When a text is not JSON.
    """
    var state = ArcPointer(ProbeState(texts, ends))
    var value = values.add_stream(AnyStream(ProbeStream(state)))
    return (value, state)

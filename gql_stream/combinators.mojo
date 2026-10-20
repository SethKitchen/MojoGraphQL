# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Stream combinators: `map_stream` and `with_filter`.

`MapStream` ports graphql-js 16.14.2 `src/execution/mapAsyncIterator.ts`.
It maps each value of a source stream with a `Mapper`. When the mapper
raises, the stream closes the source and fails with the message, as
`mapAsyncIterator` calls `return()` and rethrows. An error of the source
passes through. `close()` closes the source.

`FilterStream` ports graphql-subscriptions 3.0.0 `src/with-filter.ts`. It
yields the values of a source stream that a `Predicate` accepts, and skips
the others. A predicate that raises skips the value, as upstream ignores
errors of the filter. The end and the errors of the source pass through.

A `Mapper` or a `Predicate` is a struct, so it can carry state, such as
the arguments of a subscription field. `FnMapper` and `FnPredicate` wrap a
plain function.

Differences from upstream:

- `throw()` is not ported: an `EventStream` has no `throw`.
- `with_filter` takes the stream, not a resolver that makes it. Mojo has
  no closures, so a resolver calls `with_filter` on the stream it makes.
- The filter of upstream gets the payload, the arguments, the context and
  the info. A `Predicate` gets the payload; it carries the rest itself.
- A filter cannot be asynchronous. Upstream waits for a promise of a
  Boolean; a `Predicate` returns one.
"""

from gql_stream.poll import Event, EventStream, Poll
from gql_stream.waker import Waker

comptime MapFn = def(event: Event) raises thin -> Event
"""A function that maps one value of a stream."""
comptime FilterFn = def(event: Event) raises thin -> Bool
"""A function that accepts or skips one value of a stream: graphql-
subscriptions `FilterFn`."""


trait Mapper(Deinitable, Movable):
    """Maps each value of a stream: the callback of `mapAsyncIterator`."""

    def map(mut self, event: Event) raises -> Event:
        """Map one value.

        Args:
            event: The value of the source.

        Returns:
            The value of the mapped stream.

        Raises:
            Error: Any error; the mapped stream closes its source and
                fails with the message.
        """
        ...


trait Predicate(Deinitable, Movable):
    """Accepts or skips each value of a stream: the `filterFn` of
    `withFilter`."""

    def test(mut self, event: Event) raises -> Bool:
        """Decide whether to yield one value.

        Args:
            event: The value of the source.

        Returns:
            True to yield the value, False to skip it.

        Raises:
            Error: Any error; the value is skipped.
        """
        ...


struct FnMapper(Mapper):
    """A `Mapper` that calls a function."""

    var function: MapFn
    """The function."""

    def __init__(out self, function: MapFn):
        """Wrap a function.

        Args:
            function: The function.
        """
        self.function = function

    def map(mut self, event: Event) raises -> Event:
        """Call the function.

        Args:
            event: The value of the source.

        Returns:
            The result of the function.

        Raises:
            Error: What the function raises.
        """
        return self.function(event)


struct FnPredicate(Predicate):
    """A `Predicate` that calls a function."""

    var function: FilterFn
    """The function."""

    def __init__(out self, function: FilterFn):
        """Wrap a function.

        Args:
            function: The function.
        """
        self.function = function

    def test(mut self, event: Event) raises -> Bool:
        """Call the function.

        Args:
            event: The value of the source.

        Returns:
            The result of the function.

        Raises:
            Error: What the function raises.
        """
        return self.function(event)


struct MapStream[S: EventStream, M: Mapper](EventStream):
    """The values of a stream, mapped: graphql-js `mapAsyncIterator`.

    Parameters:
        S: The type of the source stream.
        M: The type of the mapper.
    """

    var source: Self.S
    """The source stream."""
    var mapper: Self.M
    """The mapper."""

    def __init__(out self, var source: Self.S, var mapper: Self.M):
        """Map a stream.

        Args:
            source: The source stream.
            mapper: The mapper.
        """
        self.source = source^
        self.mapper = mapper^

    def poll_next(mut self, mut waker: Waker) -> Poll:
        """Poll the source, and map a value.

        Args:
            waker: Passed to the source.

        Returns:
            The mapped value, or what the source returns. When the mapper
            raises, the source is closed and the poll is `ERROR`.
        """
        var poll = self.source.poll_next(waker)
        if not poll.event:
            return poll^
        try:
            return Poll.ready(self.mapper.map(poll.event.value()))
        except error:
            self.source.close()
            return Poll.error(String(error))

    def close(mut self):
        """Close the source: `return()`."""
        self.source.close()


struct FilterStream[S: EventStream, P: Predicate](EventStream):
    """The values of a stream that a predicate accepts: graphql-
    subscriptions `withFilter`.

    Parameters:
        S: The type of the source stream.
        P: The type of the predicate.
    """

    var source: Self.S
    """The source stream."""
    var predicate: Self.P
    """The predicate."""

    def __init__(out self, var source: Self.S, var predicate: Self.P):
        """Filter a stream.

        Args:
            source: The source stream.
            predicate: The predicate.
        """
        self.source = source^
        self.predicate = predicate^

    def poll_next(mut self, mut waker: Waker) -> Poll:
        """Poll the source until it has a value that the predicate accepts.

        Args:
            waker: Passed to the source.

        Returns:
            The first accepted value, or the first poll of the source that
            is not `READY`.
        """
        while True:
            var poll = self.source.poll_next(waker)
            if not poll.event:
                return poll^
            var accepted: Bool
            try:
                accepted = self.predicate.test(poll.event.value())
            except:
                accepted = False
            if accepted:
                return poll^

    def close(mut self):
        """Close the source: `return()`."""
        self.source.close()


def map_stream[
    S: EventStream
](var source: S, function: MapFn) -> MapStream[S, FnMapper]:
    """Map a stream with a function: graphql-js `mapAsyncIterator`.

    Parameters:
        S: The type of the source stream.

    Args:
        source: The source stream.
        function: The function.

    Returns:
        The mapped stream.
    """
    return MapStream(source^, FnMapper(function))


def with_filter[
    S: EventStream
](var source: S, function: FilterFn) -> FilterStream[S, FnPredicate]:
    """Filter a stream with a function: graphql-subscriptions `withFilter`.

    Parameters:
        S: The type of the source stream.

    Args:
        source: The source stream.
        function: The filter function.

    Returns:
        The filtered stream.
    """
    return FilterStream(source^, FnPredicate(function))

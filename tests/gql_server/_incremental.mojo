# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Helpers of the incremental delivery tests: the schema of the upstream
`incremental delivery` cases, event streams that are not always ready,
and a reader of `chunked` bodies."""

from gql_execution.execute import ResolveInfo, Resolvers
from gql_execution.value import Values
from gql_http.body import BodyPoll
from gql_server.plugin import ServerPlugin
from gql_server.http_types import HTTPGraphQLResponse
from gql_server.server import ApolloServer
from gql_stream.poll import Event, EventStream, Poll
from gql_stream.stream import AnyStream
from gql_stream.waker import Waker

comptime INCREMENTAL_SDL = """
directive @defer(if: Boolean! = true, label: String) on FRAGMENT_SPREAD | INLINE_FRAGMENT
directive @stream(if: Boolean! = true, label: String, initialCount: Int! = 0) on FIELD
type Query {
  testString: String
  barrierString: String
  testStrings: [String]
  failing: String
  nonNull: String!
}
"""
"""The schema of upstream `incremental delivery`, with `@stream`,
`testStrings` and two fields that fail."""

comptime ALPHA_9_ACCEPT = "multipart/mixed; incrementalSpec=v0.2"
"""The `accept` of the current format."""
comptime ALPHA_2_ACCEPT = "multipart/mixed; deferSpec=20220824"
"""The `accept` of the legacy format."""
comptime PART = "content-type: application/json; charset=utf-8\r\n\r\n"
"""The field of each part."""
comptime NOT_ACCEPTED = (
    "Apollo server received an operation that uses incremental delivery"
    " (@defer or @stream), but the client does not accept multipart/mixed"
    " HTTP responses. To enable incremental delivery support, add the HTTP"
    " header 'Accept: multipart/mixed; incrementalSpec=v0.2' if your client"
    " supports the current incremental format or 'Accept: multipart/mixed;"
    " deferSpec=20220824' if your client supports the legacy incremental"
    " format"
)
"""The 406 error of upstream for a client that takes no multipart."""


struct Steps(EventStream):
    """Yields its events with a `PENDING` poll before each one and before
    the end, as an async generator that awaits a timer."""

    var events: List[Event]
    """The events, in order."""
    var next: Int
    """The index of the next event."""
    var waiting: Bool
    """Whether the next poll is `PENDING`."""
    var error: String
    """The message to fail with after the events; empty to end."""

    def __init__(out self, var events: List[Event], error: String = ""):
        """Make the stream.

        Args:
            events: The events.
            error: The message to fail with at the end, or empty.
        """
        self.events = events^
        self.next = 0
        self.waiting = True
        self.error = error

    def poll_next(mut self, mut waker: Waker) -> Poll:
        """Return `PENDING`, then the next event, in turn.

        Args:
            waker: Woken at once, as a timer that fires.

        Returns:
            The poll.
        """
        if self.waiting:
            self.waiting = False
            waker.wake()
            return Poll.pending()
        self.waiting = True
        if self.next < len(self.events):
            self.next += 1
            return Poll.ready(self.events[self.next - 1].copy())
        if self.error.byte_length() > 0:
            return Poll.error(self.error)
        return Poll.done()

    def close(mut self):
        """End the stream."""
        self.next = len(self.events)
        self.error = ""


def test_string(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`testString`: `it works`."""
    return values.add_string("it works")


def barrier_string(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`barrierString`: `we waited`."""
    return values.add_string("we waited")


def test_strings(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`testStrings`: an async generator of three strings."""
    var events = List[Event]()
    events.append(Event.parse('"it works"'))
    events.append(Event.parse('"it works again"'))
    events.append(Event.parse('"it works again again"'))
    return values.add_stream(AnyStream(Steps(events^)))


def failing(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`failing`: throws `boom`."""
    raise Error("boom")


def incremental_resolvers() -> Resolvers:
    """The resolvers of `INCREMENTAL_SDL`."""
    var out = Resolvers()
    out.field("Query", "testString", test_string)
    out.field("Query", "barrierString", barrier_string)
    out.field("Query", "testStrings", test_strings)
    out.field("Query", "failing", failing)
    out.field("Query", "nonNull", failing)
    return out^


def read_chunks[
    P: ServerPlugin
](
    mut server: ApolloServer[P],
    response: HTTPGraphQLResponse,
    mut parts: List[String],
) raises -> BodyPoll:
    """Read the later parts of a `chunked` body until it ends.

    Args:
        server: The server of the response.
        response: The response.
        parts: Gets the text of each part.

    Returns:
        The last poll: `DONE` or `ERROR`.
    """
    var chunks = response.chunks.value()
    var polls = 0
    while polls < 1000:
        var out = List[UInt8]()
        var result = server.poll_chunk(chunks, out)
        if len(out) > 0:
            parts.append(String(unsafe_from_utf8=out))
        if result == BodyPoll.DONE or result == BodyPoll.ERROR:
            return result
        polls += 1
    raise Error("the body does not end")


def body_of[
    P: ServerPlugin
](mut server: ApolloServer[P], response: HTTPGraphQLResponse) raises -> String:
    """Return the whole `multipart/mixed` body of a response.

    Args:
        server: The server of the response.
        response: The response.

    Returns:
        The first part and the later parts, joined.
    """
    var parts = List[String]()
    _ = read_chunks(server, response, parts)
    var out = response.body
    for ref part in parts:
        out += part
    return out^

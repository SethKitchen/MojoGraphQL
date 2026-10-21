# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Time event delivery and event parsing of gql_sse.

    mojo build -I . -o .cache/bin/sse bench/gql_sse/sse.mojo
    .cache/bin/sse

`sse/subscribe-1000-next`: the executor of gql_sse_execution parses the
body of one POST `subscription { greetings }` in the distinct connections
mode, validates and subscribes, and an `SseBody` writes each of the 1000
events of the root field as a `next` message, then `complete`.
`sse/parse-1000-next`: an `EventParser` reads a body of 1000 `next`
messages and one `complete`, and checks the JSON of each.

The baseline is graphql-sse 2.6.3 on graphql-js 16 (Node.js), in
`bench/baselines/js-sse`: `createHandler` with a request object, and
`createParser`. The method is a warm-up, then the fastest of 5 rounds of
at least one second each.
"""

from std.benchmark import keep
from std.time import perf_counter_ns

from gql_execution.execute import Resolvers
from gql_execution.value import UNDEFINED, Values
from gql_http.body import BodyPoll
from gql_http.parser import Limits, RequestReader
from gql_language.ast import Document, OperationType
from gql_schema.build import build_schema
from gql_sse.bridge import SseBody
from gql_sse.event import EventParser, StreamMessage
from gql_sse.handler import parse_request
from gql_sse_execution.executor import GraphQLExecution, Roots
from gql_stream.poll import Event
from gql_stream.stream import AnyStream, ListStream

comptime ROUNDS = 5
"""How many rounds are timed."""
comptime ROUND_NS = 1_000_000_000
"""The least length of a round, in nanoseconds."""
comptime WARMUP_NS = 500_000_000
"""How long a workload warms up, in nanoseconds."""
comptime EVENTS = 1000
"""The events of each subscription, and the messages of each body."""
comptime NEXT = '{"data":{"greetings":"hi"}}'
"""The data of each `next` message."""
comptime SDL = (
    "type Query { hello: String } type Subscription { greetings: String }"
)
"""The schema of the subscription."""
comptime BODY = '{"query":"subscription { greetings }"}'
"""The body of the POST."""


struct Greetings(Roots):
    """A root whose `greetings` is a stream of `EVENTS` events."""

    var events: List[Event]

    def __init__(out self) raises:
        self.events = List[Event](capacity=EVENTS)
        for _ in range(EVENTS):
            self.events.append(Event.parse('{"greetings":"hi"}'))

    def root(
        mut self, mut values: Values, document: Document, operation: Int
    ) raises -> Int:
        if document.operation(operation) != OperationType.SUBSCRIPTION:
            return UNDEFINED
        var root = values.add_object()
        var stream = ListStream(self.events.copy())
        values.add_member(
            root, "greetings", values.add_stream(AnyStream(stream^))
        )
        return root


trait Work:
    """One operation of a workload."""

    def run(mut self) raises -> Int:
        """Run the operation once; return a count to keep."""
        ...


struct Subscribe(Movable, Work):
    """One POST of a subscription, and the text of every message."""

    var executor: GraphQLExecution[Greetings]
    var reader: RequestReader
    var out: List[UInt8]

    def __init__(out self) raises:
        self.executor = GraphQLExecution(
            build_schema(SDL), Resolvers(), Greetings()
        )
        self.reader = RequestReader(Limits())
        var text = (
            String("POST / HTTP/1.1\r\nHost: x\r\nAccept: text/event-stream")
            + "\r\nContent-Type: application/json\r\nContent-Length: "
            + String(StaticString(BODY).byte_length())
            + "\r\n\r\n"
            + BODY
        )
        self.reader.append(text.as_bytes())
        _ = self.reader.next()
        self.out = List[UInt8](capacity=4096)

    def run(mut self) raises -> Int:
        var outcome = parse_request(self.reader.request)
        var prepared = self.executor.prepare(
            self.reader.request, outcome.params.value(), True
        )
        var body = SseBody(prepared.stream.take())
        var total = 0
        while True:
            var poll = body.poll_body(self.out)
            total += len(self.out)
            self.out.clear()
            if poll != BodyPoll.READY:
                break
        return total


struct Parse(Movable, Work):
    """One body of `EVENTS` messages, read by a new parser."""

    var body: List[UInt8]
    var messages: List[StreamMessage]

    def __init__(out self):
        var text = String()
        for _ in range(EVENTS):
            text += "event: next\ndata: "
            text += NEXT
            text += "\n\n"
        text += "event: complete\ndata:\n\n"
        self.body = List[UInt8](text.as_bytes())
        self.messages = List[StreamMessage](capacity=EVENTS + 1)

    def run(mut self) raises -> Int:
        var parser = EventParser()
        parser.feed(self.body, self.messages)
        var count = len(self.messages)
        self.messages.clear()
        return count


def _round[W: Work](mut work: W, iterations: Int) raises -> Int:
    """Run the operation a number of times; return the nanoseconds."""
    var sink = 0
    var start = perf_counter_ns()
    for _ in range(iterations):
        sink += work.run()
    var elapsed = Int(perf_counter_ns() - start)
    keep(sink)
    return elapsed


def measure[W: Work](mut work: W, name: StaticString) raises:
    """Warm up, time the rounds, and print the `BENCH` line."""
    var iterations = 1
    var warm = 0
    while True:
        var elapsed = _round(work, iterations)
        warm += elapsed
        if elapsed * 4 >= WARMUP_NS or warm >= WARMUP_NS:
            iterations = max(ROUND_NS // max(elapsed // iterations, 1), 1)
            break
        iterations *= 2
    var best = Float64.MAX
    for _ in range(ROUNDS):
        var elapsed = _round(work, iterations)
        best = min(best, Float64(elapsed) / Float64(iterations))
    print("BENCH", name, Float64(Int(best * 10.0)) / 10.0)


def main() raises:
    """Run the workloads and print their `BENCH` lines."""
    var subscribe = Subscribe()
    if subscribe.run() < EVENTS * StaticString(NEXT).byte_length():
        raise Error("the subscription wrote too little")
    measure(subscribe, "sse/subscribe-1000-next")
    var parse = Parse()
    if parse.run() != EVENTS + 1:
        raise Error("the parser read the wrong count of messages")
    measure(parse, "sse/parse-1000-next")

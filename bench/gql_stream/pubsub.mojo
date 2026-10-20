# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The fan-out benchmark of gql_stream.

`stream/pubsub-fanout-1000` publishes one event to 1000 subscribed
iterators of a `PubSub`, and reads the event of each. The iterators are
streams of an `EventLoop`, and one turn of the loop polls each of them.
The baseline is graphql-subscriptions 3.0.0, where each iterator has a
pending `next()` and the benchmark awaits each, in
`bench/baselines/js-stream`. Both subscribe outside the timer.

The timing method is that of `bench/gql_execution/_harness.mojo`.
"""

from std.benchmark import keep
from std.time import perf_counter_ns

from gql_json.value import JsonDocument
from gql_stream.event_loop import EventLoop
from gql_stream.poll import Event
from gql_stream.pubsub import PubSub

comptime ROUND_NS = 1_000_000_000
comptime ROUNDS = 5
comptime WARMUP_NS = 200_000_000
comptime SUBSCRIBERS = 1000


struct Fanout(Movable):
    """One publish to `SUBSCRIBERS` iterators, and one read of each."""

    var pubsub: PubSub
    var loop: EventLoop
    var counter: Int

    def __init__(out self) raises:
        self.pubsub = PubSub()
        self.loop = EventLoop()
        self.counter = 0
        for _ in range(SUBSCRIBERS):
            _ = self.loop.add(self.pubsub.async_iterable_iterator("FAN"))
        _ = self.loop.poll(0)

    def run(mut self) raises -> Int:
        self.counter += 1
        var document = JsonDocument()
        var root = document.add_object()
        document.add_member(root, "n", document.add_int(Int64(self.counter)))
        document.root = root
        self.pubsub.publish("FAN", Event(document^))
        _ = self.loop.poll(0)
        var total = 0
        for index in range(len(self.loop.stream_events)):
            ref event = self.loop.stream_events[index].poll.event.value()
            ref value = event.document[]
            total += Int(value.as_int64(value.find(value.root, "n")))
        return total


def _round(mut work: Fanout, iterations: Int) raises -> Int:
    var sink = 0
    var start = perf_counter_ns()
    for _ in range(iterations):
        sink += work.run()
    var elapsed = Int(perf_counter_ns() - start)
    keep(sink)
    return elapsed


def main() raises:
    var work = Fanout()
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
    print(
        "BENCH", "stream/pubsub-fanout-1000", Float64(Int(best * 10.0)) / 10.0
    )

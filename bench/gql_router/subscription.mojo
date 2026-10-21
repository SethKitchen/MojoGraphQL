# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Time the router on one event of a subscription.

    mojo build -I . -o .cache/bin/subscription bench/gql_router/subscription.mojo
    .cache/bin/subscription

The program prints `BENCH hive-router/subscription-event <ns per op>`,
which `tools/bench.mojo` reads. The subscription is `subscription {
reviewAdded { id body product { upc name } } }` on upstream Hive Router
`e2e/supergraph.graphql`. One operation is one event of the `reviews`
subgraph: the router reads the event, runs the rest of the plan (the
`products` entity fetch), and projects the client response. `products`
answers in the same process from
`bench/fixtures/hive-router-sub/responses.json`. The plan and the
projection plan are built once. The baseline in
`bench/baselines/rust-router` runs the same step of upstream Hive Router
`1a29df9`: the body of the stream of `execute_query_plan`, with
`execute_query_plan_with_data`.

Before it times anything, the program checks that the response equals
`bench/fixtures/hive-router-sub/expected_event.json`, byte for byte.

The timing method is the one of `bench/gql_router/execute.mojo`.
"""

from std.benchmark import keep
from std.pathlib import Path
from std.time import perf_counter_ns

from gql_json.parser import parse
from gql_json.value import NO_NODE, JsonDocument
from gql_json.writer import stringify
from gql_router.exec_http import CannedTransport
from gql_router.exec_value import string_text
from gql_router.pipeline import PreparedRequest, Router, RouterSchema

comptime FIXTURES = "bench/fixtures/"
"""The directory of the fixtures, from the repository root."""
comptime QUERY = "subscription { reviewAdded { id body product { upc name } } }"
"""The subscription."""
comptime ROUND_NS = 1_000_000_000
"""The shortest round, in nanoseconds."""
comptime ROUNDS = 5
"""How many timed rounds the workload runs."""
comptime WARMUP_NS = 200_000_000
"""How long the workload warms up, in nanoseconds."""


def _canned() raises -> CannedTransport:
    """Read the canned subgraph responses."""
    var canned = parse(
        Path(FIXTURES + "hive-router-sub/responses.json").read_text()
    )
    var transport = CannedTransport()
    var item = canned.first(canned.root)
    while item != NO_NODE:
        transport.add(
            string_text(canned, canned.find(item, "subgraph")),
            string_text(canned, canned.find(item, "query")),
            stringify(canned, canned.find(item, "response")),
        )
        item = canned.next(item)
    return transport^


def _once(
    mut router: Router[CannedTransport],
    prepared: PreparedRequest,
    event: List[UInt8],
) raises -> List[UInt8]:
    """Run one event and return the response body."""
    router.executor.transport.reset()
    return router.subscription_event(
        prepared.slot, prepared.variables, event.copy()
    )


def _run(
    mut router: Router[CannedTransport],
    prepared: PreparedRequest,
    event: List[UInt8],
    iterations: Int,
) raises -> Int:
    """Run the event a number of times; return the elapsed nanoseconds."""
    var sink = 0
    var start = perf_counter_ns()
    for _ in range(iterations):
        sink += len(_once(router, prepared, event))
    var elapsed = Int(perf_counter_ns() - start)
    keep(sink)
    return elapsed


def main() raises:
    """Run the `subscription-event` workload."""
    var sdl = Path(FIXTURES + "hive-router-sub/supergraph.graphql").read_text()
    var event = List[UInt8](
        Path(FIXTURES + "hive-router-sub/event.json")
        .read_text()
        .strip()
        .as_bytes()
    )
    var router = Router(RouterSchema(sdl), _canned())
    var prepared = router.prepare_request(
        QUERY, None, JsonDocument(), NO_NODE, False, True
    )
    var expected = Path(
        FIXTURES + "hive-router-sub/expected_event.json"
    ).read_text()
    var body = String(unsafe_from_utf8=_once(router, prepared, event))
    if body != expected:
        raise Error("the response differs from expected_event.json: " + body)
    var iterations = 1
    var warm = 0
    while True:
        var elapsed = _run(router, prepared, event, iterations)
        warm += elapsed
        if elapsed * 4 >= WARMUP_NS or warm >= WARMUP_NS:
            var per_op = max(elapsed // iterations, 1)
            iterations = max(ROUND_NS // per_op, 1)
            break
        iterations *= 2
    var best = Float64.MAX
    for _ in range(ROUNDS):
        var elapsed = _run(router, prepared, event, iterations)
        best = min(best, Float64(elapsed) / Float64(iterations))
    print(
        "BENCH",
        "hive-router/subscription-event",
        Float64(Int(best * 10.0)) / 10.0,
    )

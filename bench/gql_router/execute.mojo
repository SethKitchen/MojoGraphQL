# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Time the executor on the Hive Router benchmark operation.

    mojo build -I . -o .cache/bin/execute bench/gql_router/execute.mojo
    .cache/bin/execute

The program prints `BENCH hive-router/execute <ns per op>`, which
`tools/bench.mojo` reads. One operation runs the query plan of upstream
`bench/operation.graphql` (`TestQuery`) against `bench/supergraph.graphql`:
it prepares each fetch and its entity representations, writes each
request body, reads each canned subgraph response, merges the data, and
projects the client response. The subgraphs answer in the same process
from `bench/fixtures/hive-router-exec/responses.json`. The planner, the
normalized operation, the query plan and the projection plan are built
once. The baseline in `bench/baselines/rust-router` runs the same steps of
upstream Hive Router `1a29df9` `execute_query_plan`, with the same canned
responses.

Before it times anything, the program checks that the response equals
`bench/fixtures/hive-router-exec/expected_response.json`, byte for byte.

The timing method is the one of `bench/gql_router/query_plan.mojo`: warm
up, then rounds of at least `ROUND_NS` each, and report the fastest round.
"""

from std.benchmark import keep
from std.pathlib import Path
from std.time import perf_counter_ns

from gql_json.parser import parse
from gql_json.value import NO_NODE, JsonDocument
from gql_json.writer import stringify
from gql_router.exec_http import CannedTransport
from gql_router.exec_value import string_text
from gql_router.exec_variables import CoerceVariablesPayload
from gql_router.graphql_error import GraphQLError
from gql_router.pipeline import Router, RouterSchema

comptime FIXTURES = "bench/fixtures/"
"""The directory of the fixtures, from the repository root."""
comptime ROUND_NS = 1_000_000_000
"""The shortest round, in nanoseconds."""
comptime ROUNDS = 5
"""How many timed rounds the workload runs."""
comptime WARMUP_NS = 200_000_000
"""How long the workload warms up, in nanoseconds."""


def _canned() raises -> CannedTransport:
    """Read the canned subgraph responses."""
    var canned = parse(
        Path(FIXTURES + "hive-router-exec/responses.json").read_text()
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


def _once(mut router: Router[CannedTransport], slot: Int) raises -> List[UInt8]:
    """Run the plan once and return the response body."""
    router.executor.transport.reset()
    var output = router.executor.execute(
        router.schema.planner.store,
        router.slots[slot].plan,
        router.schema.metadata,
        router.schema.keys,
        CoerceVariablesPayload(),
        router.slots[slot].projection,
        router.slots[slot].root_type_name,
        JsonDocument(),
        NO_NODE,
        List[GraphQLError](),
    )
    return output^.take_body()


def _run(
    mut router: Router[CannedTransport], slot: Int, iterations: Int
) raises -> Int:
    """Run the plan a number of times; return the elapsed nanoseconds."""
    var sink = 0
    var start = perf_counter_ns()
    for _ in range(iterations):
        sink += len(_once(router, slot))
    var elapsed = Int(perf_counter_ns() - start)
    keep(sink)
    return elapsed


def main() raises:
    """Run the `execute` workload."""
    var sdl = Path(FIXTURES + "hive-router-qp/supergraph.graphql").read_text()
    var query = Path(FIXTURES + "hive-router-qp/operation.graphql").read_text()
    var router = Router(RouterSchema(sdl), _canned())
    var first = router.execute(
        query, String("TestQuery"), JsonDocument(), NO_NODE, False, True
    )
    var slot = router.prepare(query, String("TestQuery"))
    var expected = Path(
        FIXTURES + "hive-router-exec/expected_response.json"
    ).read_text()
    var body = String(unsafe_from_utf8=_once(router, slot))
    if first.status != 200 or body != expected:
        raise Error("the response differs from expected_response.json")
    var iterations = 1
    var warm = 0
    while True:
        var elapsed = _run(router, slot, iterations)
        warm += elapsed
        if elapsed * 4 >= WARMUP_NS or warm >= WARMUP_NS:
            var per_op = max(elapsed // iterations, 1)
            iterations = max(ROUND_NS // per_op, 1)
            break
        iterations *= 2
    var best = Float64.MAX
    for _ in range(ROUNDS):
        var elapsed = _run(router, slot, iterations)
        best = min(best, Float64(elapsed) / Float64(iterations))
    print("BENCH", "hive-router/execute", Float64(Int(best * 10.0)) / 10.0)

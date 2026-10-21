# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The incremental delivery workload of the client, against Apollo Client
4.3.3 `GraphQL17Alpha9Handler`.

- `client/merge-deferred-chunks-100`: a new request, then `handle` of 101
  payloads in the graphql-js 17 format. The initial payload has 100 items
  and a pending `@defer` for each item. Each of the 100 next payloads
  delivers the deferred fields of one item and completes it. The
  operation returns the count of items of the last result.

The payloads are parsed in setup: the upstream handler gets objects that
the link has parsed. `bench/baselines/js-client/bench.mjs` runs the same
workload.
"""

from gql_client.incremental import GraphQL17Alpha9Handler
from gql_json.parser import parse as parse_json
from gql_json.value import JsonDocument

from _harness import Workload, measure

comptime COUNT = 100
"""The count of items and of deferred payloads."""


def chunk_texts() -> List[String]:
    """Return the JSON text of the 101 payloads.

    Returns:
        The initial payload, then one payload for each item.
    """
    var items = String()
    var pending = String()
    var index = 0
    while index < COUNT:
        if index > 0:
            items += ","
            pending += ","
        items += String('{"__typename":"Item","id":"', index, '"}')
        pending += String('{"id":"', index, '","path":["items",', index, "]}")
        index += 1
    var out: List[String] = [
        String(
            '{"data":{"items":[',
            items,
            ']},"pending":[',
            pending,
            '],"hasNext":true}',
        )
    ]
    index = 0
    while index < COUNT:
        out.append(
            String(
                '{"incremental":[{"id":"',
                index,
                '","data":{"title":"Item number ',
                index,
                '","score":',
                index,
                '}}],"completed":[{"id":"',
                index,
                '"}],"hasNext":',
                "true" if index + 1 < COUNT else "false",
                "}",
            )
        )
        index += 1
    return out^


struct MergeDeferred(Movable, Workload):
    """`handle` of the 101 payloads of one request."""

    var chunks: List[JsonDocument]
    """The parsed payloads."""
    var handler: GraphQL17Alpha9Handler
    """The handler."""

    def __init__(out self) raises:
        """Parse the payloads.

        Raises:
            Error: If a payload is not JSON.
        """
        self.chunks = List[JsonDocument]()
        var texts = chunk_texts()
        var index = 0
        while index < len(texts):
            self.chunks.append(parse_json(texts[index]))
            index += 1
        self.handler = GraphQL17Alpha9Handler()

    def run(mut self) raises -> Int:
        """Merge the payloads.

        Returns:
            The count of items of the last result.

        Raises:
            Error: If a payload does not merge.
        """
        var request = self.handler.start_request()
        var index = 0
        var data = 0
        while index < len(self.chunks):
            data = request.handle(None, self.chunks[index]).data
            index += 1
        ref values = request.acc.values
        return values.length(values.get(data, "items"))


def main() raises:
    """Run the workload."""
    measure("client/merge-deferred-chunks-100", MergeDeferred())

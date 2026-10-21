# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The incremental delivery benchmarks of gql_execution.

- `incremental/defer-100`: a list of 100 objects, each with a deferred
  fragment: `{ friends { id ... @defer { name } } }`.
- `incremental/stream-1000`: a list of 1000 objects with
  `@stream(initialCount: 10)`.

Each operation executes with `experimental_execute_incrementally` and
reads every payload: the count of the pending results and of the
incremental entries. The baseline is graphql-js v17.0.2
`experimentalExecuteIncrementally`, in `bench/baselines/js-incremental`.
Both build the schema, parse the document and make the list once, outside
the timer. graphql-js keeps the root value between runs; here each run
copies it into a new arena, which is inside the timer.
"""

from std.memory import ArcPointer

from _harness import Workload, measure, parse_document
from gql_execution.execute import ExecutionArgs
from gql_execution.incremental import experimental_execute_incrementally
from gql_json.value import JsonDocument
from gql_language.ast import Document
from gql_schema.build import build_schema
from gql_schema.definition import Schema
from gql_stream.waker import Waker


def _friends(count: Int) -> JsonDocument:
    """Return `{"friends":[{"id":"0","name":"friend"},...]}`."""
    var document = JsonDocument()
    var root = document.add_object()
    var list = document.add_array()
    for i in range(count):
        var friend = document.add_object()
        document.add_member(friend, "id", document.add_string(String(i)))
        document.add_member(friend, "name", document.add_string("friend"))
        document.append(list, friend)
    document.add_member(root, "friends", list)
    document.root = root
    return document^


struct Incremental(Movable, Workload):
    """Execute an operation incrementally and read every payload."""

    var schema: ArcPointer[Schema]
    var document: ArcPointer[Document]
    var root: JsonDocument
    var waker: Waker

    def __init__(out self, query: String, count: Int) raises:
        self.schema = ArcPointer(
            build_schema(
                "type Friend { id: ID name: String }"
                " type Query { friends: [Friend] }"
            )
        )
        self.document = ArcPointer(parse_document(query))
        self.root = _friends(count)
        self.waker = Waker.noop()

    def run(mut self) raises -> Int:
        var args = ExecutionArgs()
        args.assume_valid_schema = True
        args.root_value = args.values.add_json(self.root, self.root.root)
        var results = experimental_execute_incrementally(
            self.schema, self.document, args^
        )
        var total = len(results.initial_result.value().pending)
        var stream = results.take_subsequent_results()
        while True:
            var payload = stream.poll_payload(self.waker)
            if not payload:
                return total
            total += len(payload.value().incremental)


def main() raises:
    measure(
        "incremental/defer-100",
        Incremental("{ friends { id ... @defer { name } } }", 100),
    )
    measure(
        "incremental/stream-1000",
        Incremental("{ friends @stream(initialCount: 10) { id name } }", 1000),
    )

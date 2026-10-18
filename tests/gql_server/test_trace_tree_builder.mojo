# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `gql_server.trace_tree_builder`.

Apollo Server 5.5.1 has no test file of `plugin/traceTreeBuilder.ts`;
`inlineTracePlugin.test.ts` and the usage reporting tests use it through
the plugins. These tests check its internal errors, its timestamps and
its error JSON against the upstream code.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_raises
from std.testing import assert_true
from gql_execution.execute import FieldTiming
from gql_language.error import PathSegment
from gql_language.source import SourceLocation
from gql_schema.build import build_schema
from gql_schema.definition import TypeRef
from gql_server.errors import ServerError
from gql_server.trace_tree_builder import (
    SendErrorsKind,
    TraceTreeBuilder,
    date_to_proto_timestamp,
    error_to_protobuf_error,
    wall_clock_ns,
)


def _timing() raises -> FieldTiming:
    """The timing of `Query.a`."""
    var schema = build_schema("type Query { a: String }")
    var query = schema.type_named("Query")
    var path: List[PathSegment] = [PathSegment.of_key("a")]
    return FieldTiming(
        path^,
        "a",
        schema.fields[schema.field_named(query, "a")].type,
        query,
        0,
    )


def test_internal_errors() raises:
    var schema = build_schema("type Query { a: String }")
    var builder = TraceTreeBuilder("m")
    with assert_raises(
        contains=(
            "[internal apollo-server error] stopTiming called before"
            " startTiming!"
        )
    ):
        builder.stop_timing()
    with assert_raises(contains="willResolveField called before startTiming!"):
        builder.will_resolve_field(_timing(), schema)
    var errors: List[ServerError] = [ServerError("e")]
    with assert_raises(contains="addProtobufError called before startTiming!"):
        builder.did_encounter_errors(errors)
    builder.start_timing()
    with assert_raises(contains="startTiming called twice!"):
        builder.start_timing()
    builder.stop_timing()
    with assert_raises(contains="stopTiming called twice!"):
        builder.stop_timing()
    with assert_raises(contains="addProtobufError called after stopTiming!"):
        builder.did_encounter_errors(errors)
    var stopped = TraceTreeBuilder("m")
    stopped.stopped = True
    with assert_raises(contains="startTiming called after stopTiming!"):
        stopped.start_timing()


def test_fields_after_stop_timing_are_ignored() raises:
    var schema = build_schema("type Query { a: String }")
    var builder = TraceTreeBuilder("m")
    builder.start_timing()
    builder.will_resolve_field(_timing(), schema)
    builder.did_encounter_errors(List[ServerError]())
    assert_equal(len(builder.trace.nodes[0].error), 0)
    assert_equal(len(builder.trace.nodes), 2)
    builder.stop_timing()
    builder.will_resolve_field(_timing(), schema)
    assert_equal(len(builder.trace.nodes), 2)
    assert_equal(builder.trace.nodes[1].type, "String")
    assert_equal(builder.trace.nodes[1].parent_type, "Query")
    assert_true(builder.trace.duration_ns >= 0)


def test_errors_create_the_nodes_of_their_path() raises:
    var builder = TraceTreeBuilder("m")
    builder.start_timing()
    var error = ServerError("e")
    error.path = [
        PathSegment.of_key("a"),
        PathSegment.of_index(2),
        PathSegment.of_key("b"),
    ]
    var errors: List[ServerError] = [error^]
    builder.did_encounter_errors(errors)
    ref nodes = builder.trace.nodes
    assert_equal(len(nodes), 4)
    var a = nodes[0].child[0]
    assert_equal(nodes[a].response_name.value(), "a")
    var item = nodes[a].child[0]
    assert_equal(nodes[item].index.value(), 2)
    var b = nodes[item].child[0]
    assert_equal(nodes[b].response_name.value(), "b")
    assert_equal(len(nodes[b].error), 1)
    assert_equal(
        nodes[b].error[0].json,
        (
            '{"message":"<masked>","path":["a",2,"b"],'
            '"extensions":{"maskedBy":"m"}}'
        ),
    )


def test_date_to_proto_timestamp() raises:
    var time = date_to_proto_timestamp(1_700_000_000_123_456_789)
    assert_equal(time.seconds, 1_700_000_000)
    assert_equal(time.nanos, 123_000_000)
    assert_true(wall_clock_ns() > 1_700_000_000_000_000_000)


def test_error_to_protobuf_error() raises:
    var plain = error_to_protobuf_error(ServerError("m"))
    assert_equal(plain.json, '{"message":"m"}')
    assert_equal(len(plain.location), 0)
    var located = ServerError("n")
    located.locations.append(SourceLocation(2, 3))
    var error = error_to_protobuf_error(located)
    assert_equal(
        error.json, '{"message":"n","locations":[{"line":2,"column":3}]}'
    )
    assert_equal(error.location[0].line, 2)


def test_send_errors_kind() raises:
    assert_equal(String(SendErrorsKind.MASKED), "masked")
    assert_equal(String(SendErrorsKind.UNMODIFIED), "unmodified")
    assert_equal(String(SendErrorsKind.TRANSFORM), "transform")
    assert_equal(String(SendErrorsKind(9)), "<invalid>")
    assert_true(SendErrorsKind.TRANSFORM.is_valid())
    assert_false(SendErrorsKind(3).is_valid())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of the incremental publisher and the work queue: graphql-js
v17.0.2 `IncrementalPublisher.ts` and `WorkQueue.ts`, through
`experimental_execute_incrementally`.

The upstream `WorkQueue-test.ts`, `Queue-test.ts` and `Computation-test.ts`
test the generic queue of promises, which this port does not have. These
cases test the same rules on operations instead: the release of child
groups, a task shared by a released group and a child group, the pruning
of empty groups, the failure of a task of two groups, the filtering of
work under a `null`, the stream batches and their capacity of 100, the
failure of a stream after some items, and the streams that start in a
tick. The expected payloads of the `_expect` cases are the output of
graphql-js v17.0.2, run in Node.js on the same operation and the
same synchronous root value.

The other cases test what has no graphql-js equivalent: an event stream
that is `PENDING`, `close()`, and the API of the results.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from gql_execution.execute import ExecutionArgs
from gql_execution.incremental import experimental_execute_incrementally
from gql_execution.incremental_results import (
    CompletedResult,
    SubsequentIncrementalExecutionResult,
    subsequent_document,
)
from gql_json.writer import stringify
from gql_language.error import GraphQLError
from gql_language.parser import parse
from gql_schema.build import build_schema
from gql_stream.poll import Event
from gql_stream.pubsub import PubSub
from gql_stream.stream import AnyStream
from gql_stream.waker import Waker

from _incremental import expect, throwing_resolver

comptime _SDL = """
type Friend { id: ID name: String nonNullName: String! friends: [Friend] }
type Hero { id: ID name: String nonNullName: String! friends: [Friend] }
type G { h: String }
type Query {
  hero: Hero
  scalarList: [String]
  nnList: [String!]
  friendList: [Friend]
  big: [Int]
  a: String
  nn: String!
  g: G
}
type Subscription { a: String s: [String] }
"""


def _expect(query: String, root: String, expected: List[String]) raises:
    """Check the payloads of an operation."""
    expect(build_schema(_SDL), query, root, expected)


def _pubsub_args(mut pubsub: PubSub, field: String) raises -> ExecutionArgs:
    """Return inputs whose root value has a `PubSub` stream in a field."""
    var args = ExecutionArgs()
    var root = args.values.add_object()
    args.values.add_member(
        root, field, args.values.add_stream(AnyStream(pubsub.subscribe("T")))
    )
    args.root_value = root
    return args^


def test_pending_event_stream() raises:
    var pubsub = PubSub()
    var results = experimental_execute_incrementally(
        build_schema(_SDL),
        parse("{ scalarList @stream(initialCount: 1) }"),
        _pubsub_args(pubsub, "scalarList"),
    )
    assert_equal(
        results.to_json(),
        (
            '{"data":{"scalarList":[]},"pending":[{"id":"0","path":'
            '["scalarList"]}],"hasNext":true}'
        ),
    )
    var stream = results.take_subsequent_results()
    var waker = Waker.noop()
    assert_true(stream.poll_next(waker).is_pending())
    pubsub.publish("T", Event.parse('"apple"'))
    assert_equal(
        stream.poll_next(waker).value().to_json(),
        '{"hasNext":true,"incremental":[{"id":"0","items":["apple"]}]}',
    )
    assert_true(stream.poll_next(waker).is_pending())
    assert_false(stream.is_done())
    stream.close()
    assert_true(stream.is_done())
    assert_equal(pubsub.listener_count("T"), 0)
    assert_true(stream.poll_next(waker).is_done())


def test_pending_event_stream_without_stream() raises:
    var pubsub = PubSub()
    var results = experimental_execute_incrementally(
        build_schema(_SDL),
        parse("{ scalarList ... @defer { a } }"),
        _pubsub_args(pubsub, "scalarList"),
    )
    assert_equal(
        results.to_json(),
        (
            '{"errors":[{"message":"The event stream of field'
            ' \\"Query.scalarList\\" has no item ready; use @stream to stream'
            ' it.","locations":[{"line":1,"column":3}],"path":["scalarList"]}],'
            '"data":{"scalarList":null},"pending":[{"id":"0","path":[]}],'
            '"hasNext":true}'
        ),
    )
    assert_equal(pubsub.listener_count("T"), 0)


def test_filtered_event_stream_is_closed() raises:
    var pubsub = PubSub()
    var args = ExecutionArgs()
    var root = args.values.add_object()
    var hero = args.values.add_object()
    args.values.add_member(
        hero,
        "friends",
        args.values.add_stream(AnyStream(pubsub.subscribe("T"))),
    )
    args.values.add_member(hero, "nonNullName", args.values.add_null())
    args.values.add_member(root, "hero", hero)
    args.root_value = root
    var results = experimental_execute_incrementally(
        build_schema(_SDL),
        parse("{ hero { friends @stream { name } nonNullName } }"),
        args^,
    )
    assert_false(results.is_incremental())
    assert_equal(pubsub.listener_count("T"), 0)


def test_single_result_api() raises:
    var args = ExecutionArgs()
    args.resolvers.field_resolver(throwing_resolver)
    var results = experimental_execute_incrementally(
        build_schema(_SDL), parse("{ a }"), args^
    )
    assert_false(results.is_incremental())
    assert_equal(results.to_json(), '{"data":{"a":null}}')
    var raised = False
    try:
        _ = results.take_subsequent_results()
    except e:
        raised = True
        assert_equal(
            String(e), 'The execution has a single result: {"data":{"a":null}}'
        )
    assert_true(raised)


def test_unknown_operation() raises:
    var args = ExecutionArgs()
    args.operation_name = String("Missing")
    var results = experimental_execute_incrementally(
        build_schema(_SDL), parse("{ a }"), args^
    )
    assert_equal(
        results.to_json(),
        '{"errors":[{"message":"Unknown operation named \\"Missing\\"."}]}',
    )


def test_payload_document_of_error_without_location() raises:
    var payload = SubsequentIncrementalExecutionResult()
    var errors = List[GraphQLError]()
    errors.append(GraphQLError("lost"))
    payload.completed.append(CompletedResult("7", errors^))
    payload.has_next = False
    var document = subsequent_document(payload)
    assert_equal(stringify(document, document.root), payload.to_json())
    assert_equal(
        payload.to_json(),
        (
            '{"hasNext":false,"completed":[{"id":"7","errors":[{"message":'
            '"lost"}]}]}'
        ),
    )


def test_inline_fragment_without_defer() raises:
    _expect(
        "{ hero { ... on Hero { name } ... @defer { id } } }",
        '{"hero":{"id":"1","name":"Luke","nonNullName":"L","friends":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}]},"scalarList":["apple","banana","coconut"],"nnList":["a",null,"c"],"friendList":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}],"a":"A","nn":"N","g":{"h":"H"}}',
        [
            '{"data":{"hero":{"name":"Luke"}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","data":{"id":"1"}}],"completed":[{"id":"0"}]}',
        ],
    )


def test_other_directive_before_defer() raises:
    _expect(
        "{ hero { ... @include(if: true) @defer(if: true) { name } } }",
        '{"hero":{"id":"1","name":"Luke","nonNullName":"L","friends":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}]},"scalarList":["apple","banana","coconut"],"nnList":["a",null,"c"],"friendList":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}],"a":"A","nn":"N","g":{"h":"H"}}',
        [
            '{"data":{"hero":{}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","data":{"name":"Luke"}}],"completed":[{"id":"0"}]}',
        ],
    )


def test_stream_if_true() raises:
    _expect(
        "{ scalarList @stream(if: true, initialCount: 1) }",
        '{"hero":{"id":"1","name":"Luke","nonNullName":"L","friends":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}]},"scalarList":["apple","banana","coconut"],"nnList":["a",null,"c"],"friendList":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}],"a":"A","nn":"N","g":{"h":"H"}}',
        [
            '{"data":{"scalarList":["apple"]},"pending":[{"id":"0","path":["scalarList"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","items":["banana","coconut"]}],"completed":[{"id":"0"}]}',
        ],
    )


def test_spread_unknown_and_type_mismatch() raises:
    _expect(
        (
            "{ hero { ...Unknown ...OnQuery ...F @defer ...F } } fragment"
            " OnQuery on Query { a } fragment F on Hero { name }"
        ),
        '{"hero":{"id":"1","name":"Luke","nonNullName":"L","friends":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}]},"scalarList":["apple","banana","coconut"],"nnList":["a",null,"c"],"friendList":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}],"a":"A","nn":"N","g":{"h":"H"}}',
        [
            '{"data":{"hero":{"name":"Luke"}}}',
        ],
    )


def test_repeated_spread_not_deferred() raises:
    _expect(
        "{ hero { ...F ...F ... @defer { id } } } fragment F on Hero { name }",
        '{"hero":{"id":"1","name":"Luke","nonNullName":"L","friends":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}]},"scalarList":["apple","banana","coconut"],"nnList":["a",null,"c"],"friendList":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}],"a":"A","nn":"N","g":{"h":"H"}}',
        [
            '{"data":{"hero":{"name":"Luke"}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","data":{"id":"1"}}],"completed":[{"id":"0"}]}',
        ],
    )


def test_stream_of_value_that_is_not_a_list() raises:
    _expect(
        "{ hero { friends @stream { id } } }",
        '{"hero":{"friends":"x"}}',
        [
            (
                '{"errors":[{"message":"Expected Iterable, but did not find one'
                " for field"
                ' \\"Hero.friends\\".","locations":[{"line":1,"column":10}],"path":["hero","friends"]}],"data":{"hero":{"friends":null}}}'
            ),
        ],
    )


def test_deferred_field_that_type_does_not_have() raises:
    _expect(
        "{ hero { ... @defer { unknownField id } } }",
        '{"hero":{"id":"1","name":"Luke","nonNullName":"L","friends":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}]},"scalarList":["apple","banana","coconut"],"nnList":["a",null,"c"],"friendList":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}],"a":"A","nn":"N","g":{"h":"H"}}',
        [
            '{"data":{"hero":{}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","data":{"id":"1"}}],"completed":[{"id":"0"}]}',
        ],
    )


def test_root_null_with_defer() raises:
    _expect(
        "{ nn ... @defer { a } }",
        '{"hero":{"id":"1","name":"Luke","nonNullName":"L","friends":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}]},"scalarList":["apple","banana","coconut"],"nnList":["a",null,"c"],"friendList":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}],"a":"A","nn":null,"g":{"h":"H"}}',
        [
            (
                '{"errors":[{"message":"Cannot return null for non-nullable'
                " field"
                ' Query.nn.","locations":[{"line":1,"column":3}],"path":["nn"]}],"data":null}'
            ),
        ],
    )


def test_defer_in_introspection() raises:
    _expect(
        "{ __schema { ... @defer { queryType { name } } } }",
        '{"hero":{"id":"1","name":"Luke","nonNullName":"L","friends":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}]},"scalarList":["apple","banana","coconut"],"nnList":["a",null,"c"],"friendList":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}],"a":"A","nn":"N","g":{"h":"H"}}',
        [
            '{"data":{"__schema":{}},"pending":[{"id":"0","path":["__schema"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","data":{"queryType":{"name":"Query"}}}],"completed":[{"id":"0"}]}',
        ],
    )


def test_repeated_field_in_defer() raises:
    _expect(
        "{ hero { ... @defer { name name } } }",
        '{"hero":{"id":"1","name":"Luke","nonNullName":"L","friends":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}]},"scalarList":["apple","banana","coconut"],"nnList":["a",null,"c"],"friendList":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}],"a":"A","nn":"N","g":{"h":"H"}}',
        [
            '{"data":{"hero":{}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","data":{"name":"Luke"}}],"completed":[{"id":"0"}]}',
        ],
    )


def test_nullable_error_beside_defer() raises:
    _expect(
        "{ hero { name ... @defer { id } } }",
        '{"hero":{"id":"1","name":{"__throw":"bad"}}}',
        [
            '{"errors":[{"message":"bad","locations":[{"line":1,"column":10}],"path":["hero","name"]}],"data":{"hero":{"name":null}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","data":{"id":"1"}}],"completed":[{"id":"0"}]}',
        ],
    )


def test_defer_in_items_of_deferred_stream() raises:
    _expect(
        "{ ... @defer { friendList @stream { ... @defer { name } } } }",
        '{"hero":{"id":"1","name":"Luke","nonNullName":"L","friends":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}]},"scalarList":["apple","banana","coconut"],"nnList":["a",null,"c"],"friendList":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}],"a":"A","nn":"N","g":{"h":"H"}}',
        [
            '{"data":{},"pending":[{"id":"0","path":[]}],"hasNext":true}',
            '{"hasNext":true,"pending":[{"id":"1","path":["friendList"]}],"incremental":[{"id":"0","data":{"friendList":[]}}],"completed":[{"id":"0"}]}',
            '{"hasNext":false,"pending":[{"id":"2","path":["friendList",0]},{"id":"3","path":["friendList",1]}],"incremental":[{"id":"1","items":[{},{}]},{"id":"2","data":{"name":"Han"}},{"id":"3","data":{"name":"Leia"}}],"completed":[{"id":"1"},{"id":"2"},{"id":"3"}]}',
        ],
    )


def test_task_filtered_by_later_null() raises:
    _expect(
        "{ hero { friends { ... @defer { name } } nonNullName } }",
        '{"hero":{"id":"1","name":"Luke","nonNullName":null,"friends":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}]}}',
        [
            (
                '{"errors":[{"message":"Cannot return null for non-nullable'
                " field"
                ' Hero.nonNullName.","locations":[{"line":1,"column":42}],"path":["hero","nonNullName"]}],"data":{"hero":null}}'
            ),
        ],
    )


def test_stream_filtered_by_later_null() raises:
    _expect(
        "{ hero { friends @stream { name } nonNullName } }",
        '{"hero":{"id":"1","name":"Luke","nonNullName":null,"friends":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}]}}',
        [
            (
                '{"errors":[{"message":"Cannot return null for non-nullable'
                " field"
                ' Hero.nonNullName.","locations":[{"line":1,"column":35}],"path":["hero","nonNullName"]}],"data":{"hero":null}}'
            ),
        ],
    )


def test_task_shared_with_child_group() raises:
    _expect(
        (
            '{ ... @defer(label: "P") { g { h } ... @defer(label: "C") { hero {'
            ' id } } } ... @defer(label: "Q") { hero { id } } }'
        ),
        '{"hero":{"id":"1","name":"Luke","nonNullName":"L","friends":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}]},"scalarList":["apple","banana","coconut"],"nnList":["a",null,"c"],"friendList":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}],"a":"A","nn":"N","g":{"h":"H"}}',
        [
            '{"data":{},"pending":[{"id":"0","path":[],"label":"P"},{"id":"1","path":[],"label":"Q"}],"hasNext":true}',
            '{"hasNext":false,"pending":[{"id":"2","path":[],"label":"C"}],"incremental":[{"id":"0","data":{"g":{"h":"H"}}},{"id":"2","data":{"hero":{"id":"1"}}}],"completed":[{"id":"0"},{"id":"2"},{"id":"1"}]}',
        ],
    )


def test_task_done_before_its_child_group_is_released() raises:
    _expect(
        (
            '{ ... @defer(label: "Q") { hero { id } } ... @defer(label: "P") {'
            ' g { h } ... @defer(label: "C") { hero { id } } } }'
        ),
        '{"hero":{"id":"1","name":"Luke","nonNullName":"L","friends":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}]},"scalarList":["apple","banana","coconut"],"nnList":["a",null,"c"],"friendList":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}],"a":"A","nn":"N","g":{"h":"H"}}',
        [
            '{"data":{},"pending":[{"id":"0","path":[],"label":"Q"},{"id":"1","path":[],"label":"P"}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","data":{"hero":{"id":"1"}}},{"id":"1","data":{"g":{"h":"H"}}}],"completed":[{"id":"0"},{"id":"1"}]}',
        ],
    )


def test_two_item_errors() raises:
    _expect(
        "{ friendList @stream { nonNullName } }",
        '{"friendList":[{"nonNullName":null},{"nonNullName":null}]}',
        [
            '{"data":{"friendList":[]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
            (
                '{"hasNext":false,"incremental":[{"id":"0","items":[null,null],"errors":[{"message":"Cannot'
                " return null for non-nullable field"
                ' Friend.nonNullName.","locations":[{"line":1,"column":24}],"path":["friendList",0,"nonNullName"]},{"message":"Cannot'
                " return null for non-nullable field"
                ' Friend.nonNullName.","locations":[{"line":1,"column":24}],"path":["friendList",1,"nonNullName"]}]}],"completed":[{"id":"0"}]}'
            ),
        ],
    )


def test_stream_in_deferred_fragment() raises:
    _expect(
        "{ hero { ... @defer { friends @stream { name } } } }",
        '{"hero":{"id":"1","name":"Luke","nonNullName":"L","friends":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}]},"scalarList":["apple","banana","coconut"],"nnList":["a",null,"c"],"friendList":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}],"a":"A","nn":"N","g":{"h":"H"}}',
        [
            '{"data":{"hero":{}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
            '{"hasNext":true,"pending":[{"id":"1","path":["hero","friends"]}],"incremental":[{"id":"0","data":{"friends":[]}}],"completed":[{"id":"0"}]}',
            '{"hasNext":false,"incremental":[{"id":"1","items":[{"name":"Han"},{"name":"Leia"}]}],"completed":[{"id":"1"}]}',
        ],
    )


def test_stream_in_stream_items() raises:
    _expect(
        "{ friendList @stream { id friends @stream { name } } }",
        '{"hero":{"id":"1","name":"Luke","nonNullName":"L","friends":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}]},"scalarList":["apple","banana","coconut"],"nnList":["a",null,"c"],"friendList":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}],"a":"A","nn":"N","g":{"h":"H"}}',
        [
            '{"data":{"friendList":[]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
            '{"hasNext":true,"pending":[{"id":"1","path":["friendList",0,"friends"]},{"id":"2","path":["friendList",1,"friends"]}],"incremental":[{"id":"0","items":[{"id":"2","friends":[]},{"id":"3","friends":[]}]}],"completed":[{"id":"0"}]}',
            '{"hasNext":false,"incremental":[{"id":"1","items":[{"name":"X"}]}],"completed":[{"id":"1"},{"id":"2"}]}',
        ],
    )


def test_streams_of_different_lengths() raises:
    _expect(
        "{ scalarList @stream big @stream(initialCount: 1) }",
        '{"hero":{"id":"1","name":"Luke","nonNullName":"L","friends":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}]},"scalarList":["apple","banana","coconut"],"nnList":["a",null,"c"],"friendList":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}],"a":"A","nn":"N","g":{"h":"H"},"big":[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,240,241,242,243,244,245,246,247,248,249]}',
        [
            '{"data":{"scalarList":[],"big":[0]},"pending":[{"id":"0","path":["scalarList"]},{"id":"1","path":["big"]}],"hasNext":true}',
            '{"hasNext":true,"incremental":[{"id":"0","items":["apple","banana","coconut"]},{"id":"1","items":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100]}],"completed":[{"id":"0"}]}',
            '{"hasNext":true,"incremental":[{"id":"1","items":[101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,192,193,194,195,196,197,198,199,200]}]}',
            '{"hasNext":false,"incremental":[{"id":"1","items":[201,202,203,204,205,206,207,208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,240,241,242,243,244,245,246,247,248,249]}],"completed":[{"id":"1"}]}',
        ],
    )


def test_stream_of_exactly_one_batch() raises:
    _expect(
        "{ big @stream(initialCount: 1) }",
        '{"big":[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100]}',
        [
            '{"data":{"big":[0]},"pending":[{"id":"0","path":["big"]}],"hasNext":true}',
            '{"hasNext":true,"incremental":[{"id":"0","items":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100]}]}',
            '{"hasNext":false,"completed":[{"id":"0"}]}',
        ],
    )


def test_stream_item_failure_after_items() raises:
    _expect(
        "{ nnList @stream }",
        '{"hero":{"id":"1","name":"Luke","nonNullName":"L","friends":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}]},"scalarList":["apple","banana","coconut"],"nnList":["a",null,"c"],"friendList":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}],"a":"A","nn":"N","g":{"h":"H"}}',
        [
            '{"data":{"nnList":[]},"pending":[{"id":"0","path":["nnList"]}],"hasNext":true}',
            '{"hasNext":true,"incremental":[{"id":"0","items":["a"]}]}',
            (
                '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"Cannot'
                " return null for non-nullable field"
                ' Query.nnList.","locations":[{"line":1,"column":3}],"path":["nnList",1]}]}]}'
            ),
        ],
    )


def test_stream_item_failure_first() raises:
    _expect(
        "{ nnList @stream(initialCount: 1) }",
        '{"hero":{"id":"1","name":"Luke","nonNullName":"L","friends":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}]},"scalarList":["apple","banana","coconut"],"nnList":["a",null,"c"],"friendList":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}],"a":"A","nn":"N","g":{"h":"H"}}',
        [
            '{"data":{"nnList":["a"]},"pending":[{"id":"0","path":["nnList"]}],"hasNext":true}',
            (
                '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"Cannot'
                " return null for non-nullable field"
                ' Query.nnList.","locations":[{"line":1,"column":3}],"path":["nnList",1]}]}]}'
            ),
        ],
    )


def test_initial_count_equals_length() raises:
    _expect(
        "{ scalarList @stream(initialCount: 3) }",
        '{"hero":{"id":"1","name":"Luke","nonNullName":"L","friends":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}]},"scalarList":["apple","banana","coconut"],"nnList":["a",null,"c"],"friendList":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}],"a":"A","nn":"N","g":{"h":"H"}}',
        [
            '{"data":{"scalarList":["apple","banana","coconut"]},"pending":[{"id":"0","path":["scalarList"]}],"hasNext":true}',
            '{"hasNext":false,"completed":[{"id":"0"}]}',
        ],
    )


def test_event_stream() raises:
    _expect(
        "{ scalarList @stream(initialCount: 1) }",
        '{"scalarList":{"__stream":"[\\"apple\\",\\"banana\\",\\"coconut\\"]"}}',
        [
            '{"data":{"scalarList":["apple"]},"pending":[{"id":"0","path":["scalarList"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","items":["banana","coconut"]}],"completed":[{"id":"0"}]}',
        ],
    )


def test_event_stream_shorter_than_initial_count() raises:
    _expect(
        "{ scalarList @stream(initialCount: 5) }",
        '{"scalarList":{"__stream":"[\\"apple\\",\\"banana\\"]"}}',
        [
            '{"data":{"scalarList":["apple","banana"]}}',
        ],
    )


def test_event_stream_error_before_initial_count() raises:
    _expect(
        "{ scalarList @stream(initialCount: 5) }",
        '{"scalarList":{"__stream":"[\\"apple\\"]","__error":"broken"}}',
        [
            '{"errors":[{"message":"broken","locations":[{"line":1,"column":3}],"path":["scalarList"]}],"data":{"scalarList":null}}',
        ],
    )


def test_event_stream_error_after_items() raises:
    _expect(
        "{ scalarList @stream(initialCount: 1) }",
        '{"scalarList":{"__stream":"[\\"apple\\",\\"banana\\"]","__error":"broken"}}',
        [
            '{"data":{"scalarList":["apple"]},"pending":[{"id":"0","path":["scalarList"]}],"hasNext":true}',
            '{"hasNext":true,"incremental":[{"id":"0","items":["banana"]}]}',
            '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"broken","locations":[{"line":1,"column":3}],"path":["scalarList"]}]}]}',
        ],
    )


def test_event_stream_error_first() raises:
    _expect(
        "{ scalarList @stream(initialCount: 1) }",
        '{"scalarList":{"__stream":"[\\"apple\\"]","__error":"broken"}}',
        [
            '{"data":{"scalarList":["apple"]},"pending":[{"id":"0","path":["scalarList"]}],"hasNext":true}',
            '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"broken","locations":[{"line":1,"column":3}],"path":["scalarList"]}]}]}',
        ],
    )


def test_event_stream_without_stream() raises:
    _expect(
        "{ scalarList ... @defer { a } }",
        '{"hero":{"id":"1","name":"Luke","nonNullName":"L","friends":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}]},"scalarList":{"__stream":"[\\"apple\\",\\"banana\\"]"},"nnList":["a",null,"c"],"friendList":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}],"a":"A","nn":"N","g":{"h":"H"}}',
        [
            '{"data":{"scalarList":["apple","banana"]},"pending":[{"id":"0","path":[]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","data":{"a":"A"}}],"completed":[{"id":"0"}]}',
        ],
    )


def test_failed_group_with_child() raises:
    _expect(
        (
            '{ hero { ... @defer(label: "A") { nonNullName ... @defer(label:'
            ' "B") { name } } } }'
        ),
        '{"hero":{"id":"1","name":"Luke","nonNullName":null,"friends":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}]}}',
        [
            '{"data":{"hero":{}},"pending":[{"id":"0","path":["hero"],"label":"A"}],"hasNext":true}',
            (
                '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"Cannot'
                " return null for non-nullable field"
                ' Hero.nonNullName.","locations":[{"line":1,"column":35}],"path":["hero","nonNullName"]}]}]}'
            ),
        ],
    )


def test_failed_task_of_two_groups() raises:
    _expect(
        (
            '{ hero { ... @defer(label: "A") { nonNullName } ... @defer(label:'
            ' "B") { nonNullName } } }'
        ),
        '{"hero":{"id":"1","name":"Luke","nonNullName":null,"friends":[{"id":"2","name":"Han","friends":[{"name":"X"}]},{"id":"3","name":"Leia","friends":[]}]}}',
        [
            '{"data":{"hero":{}},"pending":[{"id":"0","path":["hero"],"label":"A"},{"id":"1","path":["hero"],"label":"B"}],"hasNext":true}',
            (
                '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"Cannot'
                " return null for non-nullable field"
                ' Hero.nonNullName.","locations":[{"line":1,"column":35},{"line":1,"column":74}],"path":["hero","nonNullName"]}]},{"id":"1","errors":[{"message":"Cannot'
                " return null for non-nullable field"
                ' Hero.nonNullName.","locations":[{"line":1,"column":35},{"line":1,"column":74}],"path":["hero","nonNullName"]}]}]}'
            ),
        ],
    )


def test_defer_in_subscription() raises:
    _expect(
        "subscription { ... @defer { a } }",
        '{"a":"A"}',
        [
            (
                '{"errors":[{"message":"`@defer` directive not supported on'
                " subscription operations. Disable `@defer` by setting the `if`"
                ' argument to `false`."}],"data":null}'
            ),
        ],
    )


def test_stream_in_subscription() raises:
    _expect(
        "subscription { s @stream }",
        '{"s":["x"]}',
        [
            (
                '{"errors":[{"message":"`@stream` directive not supported on'
                " subscription operations. Disable `@stream` by setting the"
                " `if` argument to"
                ' `false`.","locations":[{"line":1,"column":16}],"path":["s"]}],"data":{"s":null}}'
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

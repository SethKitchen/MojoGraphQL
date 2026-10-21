# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of the paths of `gql_client.incremental` that the upstream cases
do not reach: the document helpers (`hasDirectives`,
`addDeferFragmentLabels`, `prepareRequest`), `extractErrors`, the
`DeepMerger` at a path with malformed targets, and the payloads with
extensions, numeric ids and unknown ids.

Apollo Client 4.3.3 has no upstream test file for these helpers. The
expected values are what the upstream functions give.
"""

from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)

from gql_client.incremental import (
    Defer20220824Handler,
    GraphQL17Alpha9Handler,
    StreamFieldInfo,
    add_defer_fragment_labels,
    has_directives,
    merge_at_path,
    path_key_append,
)
from gql_client.values import Member, NO_VALUE, NULL_VALUE, Values
from gql_json.value import JsonDocument
from gql_language.printer import print_ast

from _helpers import gql, json, text_of


def test_stream_field_info_writes_its_json() raises:
    """`StreamFieldInfo` writes the JSON of upstream `StreamFieldInfo`."""
    assert_equal(
        String(StreamFieldInfo(True, False)),
        '{"isFirstChunk":true,"isLastChunk":false}',
    )
    assert_equal(
        String(StreamFieldInfo(False, True)),
        '{"isFirstChunk":false,"isLastChunk":true}',
    )


def test_has_directives() raises:
    """`hasDirectives` with one name, a repeated name, and `all`."""
    var stream = gql("{ a @include(if: true) b @stream }")
    assert_true(has_directives(["defer", "stream", "defer"], stream))
    assert_false(has_directives(["defer"], stream))
    assert_false(has_directives(["defer", "stream"], stream, True))
    var both = gql("{ a @stream ... @defer { b } }")
    assert_true(has_directives(["defer", "stream"], both, True))
    assert_true(has_directives(["stream"], both, True))
    assert_false(has_directives(List[String](), both))


def test_add_defer_fragment_labels() raises:
    """`addDeferFragmentLabels` labels each `@defer` without a string
    label or with an `ac_` label, in document order."""
    var document = gql(
        'query Q($v: String) { a ... @defer { b } ... @defer(label: "x")'
        ' { c } ... @defer(label: "ac_9") { d } ... @defer(label: $v) { e }'
        ' ... @defer(if: true, label: "") { f } ... @defer(if: false)'
        " { g } ... @include(if: true) { h } }"
    )
    var text = print_ast(add_defer_fragment_labels(document))
    assert_true('... @defer(label: "ac_0") {' in text)
    assert_true('... @defer(label: "x") {' in text)
    assert_true('... @defer(label: "ac_1") {' in text)
    assert_true('... @defer(label: "ac_2") {' in text)
    assert_true('... @defer(if: true, label: "ac_3") {' in text)
    assert_true('... @defer(if: false, label: "ac_4") {' in text)
    assert_true("... @include(if: true) {" in text)
    var handler = GraphQL17Alpha9Handler()
    assert_equal(print_ast(handler.transform_document(document)), text)


def test_prepare_accept() raises:
    """`prepareRequest` puts the `accept` value of the handler first for a
    document with `@defer` or `@stream`."""
    var accept: List[String] = ["application/json"]
    var deferred = gql("{ ... @defer { a } }")
    var plain = gql("{ a }")
    var modern = GraphQL17Alpha9Handler().prepare_accept(deferred, accept)
    assert_equal(len(modern), 2)
    assert_equal(modern[0], "multipart/mixed;incrementalSpec=v0.2")
    assert_equal(modern[1], "application/json")
    var old = Defer20220824Handler().prepare_accept(
        gql("{ a @stream }"), accept
    )
    assert_equal(old[0], "multipart/mixed;deferSpec=20220824")
    assert_equal(len(GraphQL17Alpha9Handler().prepare_accept(plain, accept)), 1)
    assert_equal(len(Defer20220824Handler().prepare_accept(plain, accept)), 1)


def test_extract_errors() raises:
    """`extractErrors` of both handlers."""
    var modern = GraphQL17Alpha9Handler()
    var old = Defer20220824Handler()
    var plain = json('{"data":null,"errors":[{"message":"a"}]}')
    assert_equal(
        text_of(modern.extract_errors(plain).value()), '[{"message":"a"}]'
    )
    assert_false(Bool(old.extract_errors(plain)))
    var payload = json(
        '{"hasNext":false,"errors":[{"message":"a"}],"incremental":[{"id":"0",'
        '"data":{},"errors":[{"message":"b"}]},{"id":"1","data":{}}],'
        '"completed":[{"id":"0","errors":[{"message":"c"}]}]}'
    )
    assert_equal(
        text_of(modern.extract_errors(payload).value()),
        '[{"message":"a"},{"message":"b"},{"message":"c"}]',
    )
    assert_equal(
        text_of(old.extract_errors(payload).value()),
        '[{"message":"a"},{"message":"b"}]',
    )
    assert_false(Bool(modern.extract_errors(json('{"hasNext":true}'))))
    assert_false(Bool(modern.extract_errors(json('{"data":{}}'))))


def _path(mut values: Values, text: StringSlice) raises -> List[Int]:
    """Return the segments of a JSON path array."""
    var document = json(text)
    return values.array_items(values.from_json(document, document.root))


def _value(mut values: Values, text: StringSlice) raises -> Int:
    """Add a JSON value to an arena."""
    var document = json(text)
    return values.from_json(document, document.root)


def test_merge_at_path_makes_containers() raises:
    """`DeepMerger` at a path makes `{}` for a key and `[]` for an index,
    and for the key `Infinity`, which converts to a number."""
    var values = Values()
    var made = merge_at_path(
        values, NO_VALUE, _path(values, '["a",1,"b"]'), 0, _value(values, "3")
    )
    assert_equal(values.stringify(made), '{"a":[null,{"b":3}]}')
    var odd = merge_at_path(
        values, NO_VALUE, _path(values, '["Infinity"]'), 0, _value(values, "1")
    )
    # An array gets no item for a key that is not an index.
    assert_equal(values.stringify(odd), "[]")
    var deep = merge_at_path(
        values,
        NO_VALUE,
        _path(values, '["x","Infinity"]'),
        0,
        _value(values, "{}"),
    )
    # The new array does not change, so upstream does not attach it.
    assert_equal(values.stringify(deep), "{}")


def test_merge_at_path_into_arrays() raises:
    """A merge at an index past the end of an array leaves holes, and a
    hole reads as `undefined`."""
    var values = Values()
    var target = _value(values, "[1]")
    var merged = merge_at_path(
        values, target, _path(values, "[3]"), 0, _value(values, '"x"')
    )
    assert_equal(values.stringify(merged), '[1,null,null,"x"]')
    var again = merge_at_path(
        values, merged, _path(values, "[1]"), 0, _value(values, '{"a":1}')
    )
    assert_equal(values.stringify(again), '[1,{"a":1},null,"x"]')
    var same = merge_at_path(
        values, again, _path(values, "[0]"), 0, _value(values, "1")
    )
    assert_true(same == again)


def test_merge_at_path_through_null_and_scalars() raises:
    """A merge through `null` or a scalar raises the upstream
    `TypeError` message."""
    var values = Values()
    with assert_raises(contains="Cannot read properties of null (reading 'a')"):
        _ = merge_at_path(
            values, NULL_VALUE, _path(values, '["a"]'), 0, _value(values, "1")
        )
    with assert_raises(contains="Cannot create property 'a' on"):
        _ = merge_at_path(
            values,
            _value(values, '"text"'),
            _path(values, '["a"]'),
            0,
            _value(values, "1"),
        )
    with assert_raises(contains="Cannot create property 'a' on"):
        _ = merge_at_path(
            values,
            _value(values, "true"),
            _path(values, '["a","b"]'),
            0,
            _value(values, "{}"),
        )


def test_merge_streamed_items() raises:
    """Streamed items merge into an array, an object, or a value that is
    neither."""
    var values = Values()
    var items = _value(values, '[{"a":1},2]')
    var array = merge_at_path(
        values, _value(values, '[0,{"a":1},2,3]'), List[Int](), 0, items, 1
    )
    assert_equal(values.stringify(array), '[0,{"a":1},2]')
    var unchanged = merge_at_path(values, array, List[Int](), 0, items, 1)
    assert_true(unchanged == array)
    var shared = _value(values, "[5]")
    var equal = merge_at_path(
        values,
        shared,
        List[Int](),
        0,
        values.add_array([values.item(shared, 0)]),
        0,
    )
    assert_true(equal == shared)
    var longer = merge_at_path(
        values, _value(values, "[0]"), List[Int](), 0, items, 3
    )
    assert_equal(values.stringify(longer), '[0,null,null,{"a":1},2]')
    var object = merge_at_path(
        values, _value(values, '{"1":{"b":2},"c":3}'), List[Int](), 0, items, 1
    )
    assert_equal(values.stringify(object), '{"1":{"b":2,"a":1},"2":2,"c":3}')
    var same = merge_at_path(
        values, object, List[Int](), 0, _value(values, "[2]"), 2
    )
    assert_true(same == object)
    var sparse = merge_at_path(values, NO_VALUE, List[Int](), 0, items, 2)
    assert_equal(values.stringify(sparse), '[null,null,{"a":1},2]')
    var changed = merge_at_path(
        values, _value(values, '[{"b":2}]'), List[Int](), 0, items, 0
    )
    assert_equal(values.stringify(changed), '[{"b":2,"a":1},2]')


def test_pending_that_comes_again_and_members_that_are_not_arrays() raises:
    """A `pending` id that comes again keeps its place, a member that is
    not an array has no items, and a defer that completes at the path of
    a stream marks the stream as complete."""
    var request = GraphQL17Alpha9Handler().start_request()
    _ = request.handle(
        None,
        json(
            '{"data":{"list":[]},"pending":[{"id":"0","path":["list"]}],'
            '"incremental":5,"hasNext":true}'
        ),
    )
    var result = request.handle(
        None,
        json(
            '{"pending":[{"id":"0","path":["list"]},{"id":"1","path":["list"]}],'
            '"completed":[{"id":"1"}],"hasNext":true}'
        ),
    )
    assert_equal(len(request.pending_with_info()), 2)
    assert_true(result.has_stream_info)
    var key = String()
    path_key_append(key, "list", False)
    assert_true(request.stream_info.peek(key).value().current.is_last_chunk)
    _ = request.handle(None, json('{"pending":{},"hasNext":false}'))
    assert_equal(len(request.pending_with_info()), 2)


def test_payloads_with_extensions_and_numeric_ids() raises:
    """Extensions merge as `Object.assign`, an id can be a number, and a
    path can have a `subPath`."""
    var request = GraphQL17Alpha9Handler().start_request()
    _ = request.handle(
        None,
        json(
            '{"data":{"a":{}},"pending":[{"id":0,"path":["a"],"label":"L"}],'
            '"hasNext":true,"extensions":{"x":1,"y":2}}'
        ),
    )
    var pending = request.pending_with_info()
    assert_equal(len(pending), 1)
    assert_false(pending[0].is_stream)
    assert_false(pending[0].delivered)
    assert_equal(request.acc.values.stringify(pending[0].label), '"L"')
    var result = request.handle(
        None,
        json(
            '{"incremental":[{"id":0,"subPath":["b"],"data":{"c":1},'
            '"extensions":{"y":3,"z":4}}],"completed":[{"id":0}],'
            '"hasNext":false}'
        ),
    )
    # Extensions that are not an object are not merged, and cache data
    # without a root is `undefined`.
    result = request.handle(
        JsonDocument(), json('{"hasNext":false,"extensions":[1]}')
    )
    assert_equal(
        request.stringify(result),
        '{"data":{"a":{"b":{"c":1}}},"extensions":{"x":1,"y":3,"z":4}}',
    )
    assert_equal(
        text_of(request.to_json(result)),
        '{"data":{"a":{"b":{"c":1}}},"extensions":{"x":1,"y":3,"z":4}}',
    )
    assert_equal(text_of(request.data_json(result)), '{"a":{"b":{"c":1}}}')
    assert_true(request.pending_with_info()[0].delivered)
    assert_false(request.is_streaming(gql("{ a }")))
    assert_false(request.chunk_has_errors(json('{"data":{}}')))
    assert_false(Bool(request.current_stream_info()))


def test_unknown_ids_raise() raises:
    """An `incremental` or `completed` id that no `pending` announced
    raises, and so does a stream whose data is not an array."""
    var request = GraphQL17Alpha9Handler().start_request()
    with assert_raises(contains="Could not find pending chunk"):
        _ = request.handle(
            None, json('{"incremental":[{"data":{}}],"hasNext":true}')
        )
    with assert_raises(contains="Cannot destructure property 'path'"):
        _ = request.handle(
            None, json('{"completed":[{"id":"9"}],"hasNext":false}')
        )
    var stream = GraphQL17Alpha9Handler().start_request()
    _ = stream.handle(
        None,
        json(
            '{"data":{"list":[]},"pending":[{"id":"0","path":["list"]}],'
            '"hasNext":true}'
        ),
    )
    var info = stream.pending_with_info()
    assert_true(info[0].is_stream)
    with assert_raises(contains="dataAtPath.slice is not a function"):
        _ = stream.handle(
            json('{"list":{}}'),
            json('{"completed":[{"id":"0"}],"hasNext":false}'),
        )


def test_deferred_data_without_a_pending_array() raises:
    """Deferred data that is not an object reads as `undefined` for the
    streams that it does not have."""
    var request = GraphQL17Alpha9Handler().start_request()
    _ = request.handle(
        None,
        json(
            '{"data":{"a":null},"pending":[{"id":"0","path":["a"]},{"id":"1",'
            '"path":["a","list"]}],"hasNext":true}'
        ),
    )
    var result = request.handle(
        None,
        json('{"incremental":[{"id":"0","data":"x"}],"hasNext":true}'),
    )
    assert_equal(request.stringify(result), '{"data":{"a":"x"}}')


def test_paths_that_are_not_arrays() raises:
    """A `path` or a `subPath` that is not an array has no segments."""
    var request = GraphQL17Alpha9Handler().start_request()
    _ = request.handle(
        None, json('{"data":{"a":1},"pending":[{"id":"0"}],"hasNext":true}')
    )
    var result = request.handle(
        None,
        json(
            '{"incremental":[{"id":"0","subPath":null,"data":{"b":2}}],'
            '"completed":[{"id":"0"}],"hasNext":false}'
        ),
    )
    assert_equal(request.stringify(result), '{"data":{"a":1,"b":2}}')


def test_defer20220824_items_and_paths() raises:
    """`Defer20220824Handler`: `items: null` stops a stream path, items
    merge at their indices, and `data: null` of a defer is not merged."""
    var request = Defer20220824Handler().start_request()
    _ = request.handle(
        None, json('{"data":{"list":[1],"o":{"p":1}},"hasNext":true}')
    )
    var result = request.handle(
        None,
        json(
            '{"incremental":[{"items":[2,3],"path":["list",1]},{"items":null,'
            '"path":["o","q",0],"errors":[{"message":"e"}]},{"items":[9],'
            '"path":["o","q",1]},{"data":null,"path":["o"]},{"data":{"r":2},'
            '"path":["o"],"extensions":{"k":1}},{"items":[4],"path":["z"]}],'
            '"hasNext":false}'
        ),
    )
    comptime data = '{"list":[1,2,3],"o":{"p":1,"r":2},"z":[4]}'
    comptime full = (
        '{"data":' + data + ',"errors":[{"message":"e"}],"extensions":{"k":1}}'
    )
    assert_equal(request.stringify(result), full)
    assert_false(request.has_next)
    assert_false(request.is_streaming(gql("{ ... @defer { a } }")))
    assert_true(
        request.chunk_has_errors(json('{"hasNext":true,"errors":[{}]}'))
    )
    assert_equal(text_of(request.data_json(result)), data)
    assert_equal(text_of(request.to_json(result)), full)


def test_defer20220824_object_items() raises:
    """Items whose last path segment is a number merge one by one; other
    items merge at the path as a whole."""
    var request = Defer20220824Handler().start_request()
    _ = request.handle(None, json('{"data":{"list":[{"a":1}]},"hasNext":true}'))
    var result = request.handle(
        None,
        json(
            '{"incremental":[{"items":[{"b":2},{"c":3}],"path":["list",0]},'
            '{"items":{"d":4},"path":["list",5]},{"data":{"e":5},'
            '"path":["x"]}],"hasNext":true}'
        ),
    )
    assert_equal(
        request.stringify(result),
        '{"data":{"list":[{"a":1,"b":2},{"c":3},null,null,null,{"d":4}],"x":{"e":5}}}',
    )
    assert_true(request.is_streaming(gql("{ ... @defer { a } }")))
    assert_false(Bool(request.current_stream_info()))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

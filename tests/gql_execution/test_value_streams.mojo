# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of the event streams of a `Values` arena, and of `mark` and
`release`, which drop the values of one subscription event.

There is no upstream test file: graphql-js has no arena.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from gql_execution.value import PROMISE_TAG, STREAM_TAG, UNDEFINED, Values
from gql_stream.stream import AnyStream, ListStream
from gql_stream.waker import Waker


def _stream() raises -> AnyStream:
    var texts = List[String]()
    texts.append("1")
    return AnyStream(ListStream.of_json(texts))


def test_add_and_take_a_stream() raises:
    var values = Values()
    var handle = values.add_stream(_stream())
    assert_equal(values.tag(handle), STREAM_TAG)
    assert_true(values.is_stream(handle))
    assert_false(values.is_stream(UNDEFINED))
    assert_false(values.is_stream(values.add_handle(STREAM_TAG + 1, 0)))
    assert_false(values.is_stream(values.add_handle(STREAM_TAG, 5)))
    var stream = values.take_stream(handle)
    var waker = Waker.noop()
    assert_equal(stream.poll_next(waker).value().to_json(), "1")
    assert_false(values.is_stream(handle))
    try:
        _ = values.take_stream(handle)
    except error:
        assert_equal(String(error), "The value is not an event stream.")
        return
    raise Error("expected an error")


def test_release_drops_the_values_after_a_mark() raises:
    var values = Values()
    var root = values.add_object()
    values.add_member(root, "a", values.add_string("kept"))
    var mark = values.mark()
    var event = values.add_object()
    values.add_member(event, "b", values.add_string("dropped"))
    assert_true(values.release(mark))
    assert_equal(values.mark()[0], mark[0])
    assert_equal(values.mark()[1], mark[1])
    assert_equal(values.string(values.get(root, "a")), "kept")


def test_release_keeps_values_that_an_older_container_holds() raises:
    var values = Values()
    var list = values.add_list()
    var mark = values.mark()
    values.append(list, values.add_number(1))
    assert_false(values.release(mark))
    var object = values.add_object()
    values.add_member(object, "a", values.add_number(1))
    mark = values.mark()
    values.add_member(object, "b", values.add_number(2))
    assert_false(values.release(mark))
    assert_equal(values.length(object), 2)


def test_release_keeps_a_value_that_set_puts_in_an_older_object() raises:
    var values = Values()
    var object = values.add_object()
    values.add_member(object, "a", values.add_number(1))
    values.add_member(object, "b", values.add_number(2))
    var mark = values.mark()
    values.set(object, "a", values.add_number(3))
    assert_true(values.release(mark))
    assert_equal(values.number(values.get(object, "a")), 3)
    values.set(object, "a", values.add_string("new text"))
    assert_false(values.release(mark))
    mark = values.mark()
    values.set(object, "b", values.add_error("new message"))
    assert_false(values.release(mark))


def test_release_keeps_a_newer_sibling_of_an_older_member() raises:
    var values = Values()
    var first = values.add_number(1)
    var object = values.add_object()
    values.add_member(object, "a", first)
    var mark = values.mark()
    values.add_member(object, "b", values.add_number(2))
    assert_false(values.release(mark))
    assert_equal(values.length(object), 2)


def test_release_keeps_a_container_whose_first_child_is_newer() raises:
    var values = Values()
    var list = values.add_list()
    var orphan = values.add_number(1)
    var mark = values.mark()
    values.append(list, values.add_number(2))
    values.append(list, orphan)
    assert_false(values.release(mark))
    assert_equal(values.length(list), 2)


def test_add_promise_and_rejected_promise() raises:
    var values = Values()
    var inner = values.add_string("ok")
    var p = values.add_promise(inner)
    assert_equal(values.tag(p), PROMISE_TAG)
    assert_true(values.is_promise(p))
    assert_false(values.is_rejected_promise(p))
    assert_equal(values.promise_value(p), inner)
    assert_false(values.is_promise(UNDEFINED))
    assert_false(values.is_promise(inner))

    var r = values.add_rejected_promise("boom")
    assert_true(values.is_promise(r))
    assert_true(values.is_rejected_promise(r))
    assert_equal(values.string(values.promise_value(r)), "boom")

    var mark = values.mark()
    var newer = values.add_number(42)
    values.nodes[p].payload = Int64(newer)
    assert_false(values.release(mark))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

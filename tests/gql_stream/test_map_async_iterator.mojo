# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `MapStream` and `map_stream`.

Ports graphql-js 16.14.2 `src/execution/__tests__/mapAsyncIterator-test.ts`.
An `async function*` source is a `ListStream`; a source with a `finally`
block is `ListStream`, whose `closed()` tells that `return()` ran.

Not ported: "compatible with for-await-of" (Mojo has no `for await`),
"allows throwing errors through async iterable" and "passes through caught
errors through async generators" (an `EventStream` has no `throw()`), and
"closes source if mapper rejects" (a mapper cannot return a promise; the
case is the same as "closes source if mapper throws an error"). The early
return of upstream gives the value of the `finally` block; `close()`
returns nothing, and the next poll is `DONE`.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from gql_json.value import JsonDocument
from gql_stream.combinators import FnMapper, MapStream, map_stream
from gql_stream.poll import Event, EventStream, Poll
from gql_stream.stream import AnyStream, ListStream
from gql_stream.waker import Waker


def _numbers(*values: Int) raises -> ListStream:
    var texts = List[String]()
    for value in values:
        texts.append(String(value))
    return ListStream.of_json(texts)


def _int(event: Event) raises -> Int:
    return Int(event.document[].as_int64(event.root()))


def _number(value: Int) -> Event:
    var document = JsonDocument()
    document.root = document.add_int(Int64(value))
    return Event(document^)


def _double(event: Event) raises -> Event:
    return _number(_int(event) * 2)


def _string_twice(event: Event) raises -> Event:
    var text = event.document[].string_value(event.root())
    var document = JsonDocument()
    var twice = text.copy()
    twice += text
    document.root = document.add_string(twice)
    return Event(document^)


def _throw_over_1(event: Event) raises -> Event:
    var value = _int(event)
    if value > 1:
        raise Error("Cannot count to ", value)
    return event.copy()


def _next[S: EventStream](mut stream: S) raises -> Poll:
    var waker = Waker.noop()
    return stream.poll_next(waker)


def test_maps_over_async_generator() raises:
    var doubles = map_stream(_numbers(1, 2, 3), _double)
    assert_equal(_int(_next(doubles).value()), 2)
    assert_equal(_int(_next(doubles).value()), 4)
    assert_equal(_int(_next(doubles).value()), 6)
    assert_true(_next(doubles).is_done())


def test_maps_over_async_iterable() raises:
    var doubles = map_stream(AnyStream(_numbers(1, 2, 3)), _double)
    var values = List[Int]()
    while True:
        var poll = _next(doubles)
        if poll.is_done():
            break
        values.append(_int(poll.value()))
    assert_equal(len(values), 3)
    assert_equal(values[0], 2)
    assert_equal(values[2], 6)


def test_maps_over_async_values_with_async_function() raises:
    var doubles = MapStream(_numbers(1, 2, 3), FnMapper(_double))
    assert_equal(_int(_next(doubles).value()), 2)
    assert_equal(_int(_next(doubles).value()), 4)
    assert_equal(_int(_next(doubles).value()), 6)
    assert_true(_next(doubles).is_done())


def test_allows_returning_early_from_mapped_async_generator() raises:
    var doubles = map_stream(_numbers(1, 2, 3), _double)
    assert_equal(_int(_next(doubles).value()), 2)
    assert_equal(_int(_next(doubles).value()), 4)
    doubles.close()
    assert_true(doubles.source.closed())
    assert_true(_next(doubles).is_done())
    assert_true(_next(doubles).is_done())


def test_passes_through_early_return_from_async_values() raises:
    var doubles = map_stream(AnyStream(_numbers(1, 2, 3)), _double)
    assert_equal(_int(_next(doubles).value()), 2)
    doubles.close()
    doubles.close()
    assert_true(_next(doubles).is_done())


def test_does_not_normally_map_over_thrown_errors() raises:
    var texts = List[String]()
    texts.append('"Hello"')
    var doubles = map_stream(
        ListStream.of_json(texts, "Goodbye"), _string_twice
    )
    assert_equal(_next(doubles).value().to_json(), '"HelloHello"')
    var poll = _next(doubles)
    assert_true(poll.is_error())
    assert_equal(poll.message, "Goodbye")
    assert_true(_next(doubles).is_done())


def test_closes_source_if_mapper_throws_an_error() raises:
    var throw_over_1 = map_stream(_numbers(1, 2, 3), _throw_over_1)
    assert_equal(_int(_next(throw_over_1).value()), 1)
    var poll = _next(throw_over_1)
    assert_true(poll.is_error())
    assert_equal(poll.message, "Cannot count to 2")
    assert_true(_next(throw_over_1).is_done())
    assert_true(throw_over_1.source.closed())


def test_poll_value_raises_when_not_ready() raises:
    var poll = Poll.pending()
    try:
        _ = poll.value()
    except error:
        assert_equal(String(error), "Poll has no value: PENDING")
        return
    raise Error("expected an error")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

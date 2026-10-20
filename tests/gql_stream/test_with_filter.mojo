# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `FilterStream` and `with_filter`.

Ports the "withFilter" cases of graphql-subscriptions 3.0.0
`src/test/asyncIteratorSubscription.ts`. The "GraphQL-JS asyncIterator"
cases of that file need `subscribe`, so they are in
`tests/gql_execution/test_subscribe_pubsub.mojo`.

"does not leak memory with promise chain" is not ported: it measures the
heap of Node.js. A `FilterStream` keeps no state between values, so a
skipped value holds no memory. The cases after it test a filter that
raises, a `PENDING` source and `close()`.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from gql_stream.combinators import FilterStream, FnPredicate, with_filter
from gql_stream.poll import Event, EventStream, Poll
from gql_stream.pubsub import PubSub
from gql_stream.stream import ListStream
from gql_stream.waker import Waker


def _numbers(count: Int) raises -> ListStream:
    var texts = List[String]()
    var value = 1
    while value <= count:
        texts.append(String(value))
        value += 1
    return ListStream.of_json(texts)


def _int(event: Event) raises -> Int:
    return Int(event.document[].as_int64(event.root()))


def _is_even(event: Event) raises -> Bool:
    return _int(event) % 2 == 0


def _raises_over_2(event: Event) raises -> Bool:
    if _int(event) > 2:
        raise Error("Undefined value passed to filterFn")
    return True


def _never(event: Event) raises -> Bool:
    return False


def _next[S: EventStream](mut stream: S) raises -> Poll:
    var waker = Waker.noop()
    return stream.poll_next(waker)


def test_works_properly_with_finite_async_iterators() raises:
    var filtered = with_filter(_numbers(8), _is_even)
    for i in range(1, 5):
        var result = _next(filtered)
        assert_true(result.is_ready())
        assert_equal(_int(result.value()), i * 2)
    var done_result = _next(filtered)
    assert_true(done_result.is_done())
    assert_false(Bool(done_result.event))


def test_errors_of_the_filter_skip_the_value() raises:
    var filtered = FilterStream(_numbers(4), FnPredicate(_raises_over_2))
    assert_equal(_int(_next(filtered).value()), 1)
    assert_equal(_int(_next(filtered).value()), 2)
    assert_true(_next(filtered).is_done())


def test_pending_source_and_close() raises:
    var ps = PubSub()
    var filtered = with_filter(ps.subscribe("a"), _is_even)
    var waker = Waker.noop()
    assert_true(filtered.poll_next(waker).is_pending())
    ps.publish("a", Event.parse("1"))
    assert_true(waker.woken())
    assert_true(filtered.poll_next(waker).is_pending())
    ps.publish("a", Event.parse("2"))
    assert_equal(_int(filtered.poll_next(waker).value()), 2)
    filtered.close()
    assert_equal(ps.listener_count("a"), 0)
    assert_true(filtered.poll_next(waker).is_done())


def test_should_detect_when_the_payload_is_done_when_filtering() raises:
    var ps = PubSub()
    var filtered = with_filter(ps.subscribe("FIRST_EVENT"), _never)
    assert_true(_next(filtered).is_pending())
    filtered.close()
    ps.publish("FIRST_EVENT", Event.parse("{}"))
    assert_true(_next(filtered).is_done())


def test_source_error_passes_through() raises:
    var texts = List[String]()
    texts.append("1")
    var filtered = with_filter(ListStream.of_json(texts, "boom"), _never)
    var poll = _next(filtered)
    assert_true(poll.is_error())
    assert_equal(poll.message, "boom")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

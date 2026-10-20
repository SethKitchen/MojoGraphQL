# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `subscribe` with a `PubSub` and `with_filter`: the "GraphQL-JS
asyncIterator" cases of graphql-subscriptions 3.0.0
`src/test/asyncIteratorSubscription.ts`.

Upstream gives the iterator to `withFilter` in a closure. Mojo has no
closures, so the root value holds the filtered stream, and the default
`subscribeFieldResolver` returns it. "should allow async filter" uses a
filter that returns True, because a Mojo filter cannot be asynchronous.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from gql_execution.execute import ExecutionArgs, ResolveInfo
from gql_execution.subscribe import ResponseStream, subscribe
from gql_execution.value import Values
from gql_language.parser import parse
from gql_schema.build import build_schema
from gql_stream.combinators import FilterFn, with_filter
from gql_stream.poll import Event, Poll
from gql_stream.pubsub import PubSub
from gql_stream.stream import AnyStream
from gql_stream.waker import Waker

comptime FIRST_EVENT = "FIRST_EVENT"
comptime _QUERY = """
      subscription S1 {

        testSubscription
      }
"""


def _default_filter(event: Event) raises -> Bool:
    return True


def _never(event: Event) raises -> Bool:
    return False


def _first_event(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.add_string("FIRST_EVENT")


def _build(mut pubsub: PubSub, filter_fn: FilterFn) raises -> ResponseStream:
    var args = ExecutionArgs()
    args.resolvers.field("Subscription", "testSubscription", _first_event)
    var root = args.values.add_object()
    var iterator = with_filter(
        pubsub.async_iterable_iterator(FIRST_EVENT), filter_fn
    )
    args.values.add_member(
        root, "testSubscription", args.values.add_stream(AnyStream(iterator^))
    )
    args.root_value = root
    var subscription = subscribe(
        build_schema(
            "type Query { testString: String }"
            " type Subscription { testSubscription: String }"
        ),
        parse(_QUERY),
        args^,
    )
    return subscription.take_stream()


def _expect_first_event(mut pubsub: PubSub, filter_fn: FilterFn) raises:
    var results = _build(pubsub, filter_fn)
    var waker = Waker.noop()
    assert_true(results.poll_next(waker).is_pending())
    pubsub.publish(FIRST_EVENT, Event.parse("{}"))
    assert_true(waker.woken())
    assert_equal(
        results.poll_next(waker).value().to_json(),
        '{"data":{"testSubscription":"FIRST_EVENT"}}',
    )


def test_should_allow_subscriptions() raises:
    var pubsub = PubSub()
    _expect_first_event(pubsub, _default_filter)


def test_should_allow_async_filter() raises:
    var pubsub = PubSub()
    _expect_first_event(pubsub, _default_filter)


def test_should_detect_when_the_payload_is_done_when_filtering() raises:
    var pubsub = PubSub()
    var results = _build(pubsub, _never)
    var waker = Waker.noop()
    assert_true(results.poll_next(waker).is_pending())
    results.close()
    pubsub.publish(FIRST_EVENT, Event.parse("{}"))
    assert_true(results.poll_next(waker).is_done())


def test_should_clear_event_handlers() raises:
    var pubsub = PubSub()
    var results = _build(pubsub, _default_filter)
    var waker = Waker.noop()
    assert_true(results.poll_next(waker).is_pending())
    assert_equal(pubsub.listener_count(FIRST_EVENT), 1)
    results.close()
    assert_equal(pubsub.listener_count(FIRST_EVENT), 0)
    pubsub.publish(FIRST_EVENT, Event.parse("{}"))
    assert_true(results.poll_next(waker).is_done())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

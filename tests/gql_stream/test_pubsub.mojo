# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `PubSub` and `PubSubAsyncIterableIterator`.

Ports graphql-subscriptions 3.0.0 `src/test/tests.ts`: each case of
"PubSub" and "AsyncIterator". A callback listener of upstream is an
iterator here, so "can subscribe and is called when events happen" polls
the iterator. "should expose valid asyncIterator" checks that the
iterator is an `EventStream`, which the type system proves.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from gql_stream.event_loop import EventLoop
from gql_stream.poll import Event, EventStream, Poll
from gql_stream.pubsub import PubSub, PubSubAsyncIterableIterator
from gql_stream.waker import Waker


def _poll[S: EventStream](mut stream: S) raises -> Poll:
    var waker = Waker.noop()
    return stream.poll_next(waker)


def test_can_subscribe_and_is_called_when_events_happen() raises:
    var ps = PubSub()
    var iterator = ps.subscribe("a")
    ps.publish("a", Event.parse('"test"'))
    assert_equal(_poll(iterator).value().to_json(), '"test"')


def test_can_unsubscribe() raises:
    var ps = PubSub()
    var iterator = ps.subscribe("a")
    var ids = iterator.subscription_ids()
    assert_equal(len(ids), 1)
    assert_true(ps.unsubscribe(ids[0]))
    ps.publish("a", Event.parse('"test"'))
    assert_true(_poll(iterator).is_pending())
    assert_false(ps.unsubscribe(ids[0]))


def test_should_trigger_event_on_async_iterator_when_published() raises:
    var ps = PubSub()
    var iterator = ps.async_iterable_iterator("test")
    var waker = Waker.noop()
    assert_true(iterator.poll_next(waker).is_pending())
    assert_false(waker.woken())
    ps.publish("test", Event.parse('{"test":true}'))
    assert_true(waker.woken())
    var result = iterator.poll_next(waker)
    assert_true(result.is_ready())
    assert_equal(result.value().to_json(), '{"test":true}')


def test_should_not_trigger_event_when_publishing_other_event() raises:
    var ps = PubSub()
    var iterator = ps.async_iterable_iterator("test")
    var waker = Waker.noop()
    assert_true(iterator.poll_next(waker).is_pending())
    ps.publish("test2", Event.parse('{"test":true}'))
    assert_false(waker.woken())
    assert_true(iterator.poll_next(waker).is_pending())


def test_register_to_multiple_events() raises:
    var ps = PubSub()
    var triggers = List[String]()
    triggers.append("test")
    triggers.append("test2")
    var iterator = ps.async_iterable_iterator(triggers^)
    var waker = Waker.noop()
    assert_true(iterator.poll_next(waker).is_pending())
    assert_equal(len(iterator.subscription_ids()), 2)
    ps.publish("test2", Event.parse('{"test":true}'))
    assert_true(waker.woken())
    assert_true(iterator.poll_next(waker).is_ready())


def test_should_not_trigger_event_on_async_iterator_already_returned() raises:
    var ps = PubSub()
    var iterator = ps.async_iterable_iterator("test")
    var waker = Waker.noop()
    assert_true(iterator.poll_next(waker).is_pending())
    ps.publish("test", Event.parse('{"test":true}'))
    iterator.close()
    ps.publish("test", Event.parse('{"test":true}'))
    assert_true(iterator.poll_next(waker).is_done())
    assert_true(iterator.poll_next(waker).is_done())
    assert_equal(ps.listener_count("test"), 0)


def test_should_not_register_event_listeners_before_next_is_called() raises:
    var ps = PubSub()
    var iterator = ps.async_iterable_iterator("test")
    assert_equal(ps.listener_count("test"), 0)
    assert_equal(len(iterator.subscription_ids()), 0)
    _ = _poll(iterator)
    assert_equal(ps.listener_count("test"), 1)
    iterator.close()


def test_a_new_waker_replaces_the_old_one() raises:
    var ps = PubSub()
    var iterator = ps.subscribe("a")
    var old = Waker.noop()
    var new = Waker.noop()
    assert_true(iterator.poll_next(old).is_pending())
    assert_true(iterator.poll_next(old).is_pending())
    assert_true(iterator.poll_next(new).is_pending())
    ps.publish("a", Event.parse("1"))
    assert_false(old.woken())
    assert_true(new.woken())


def test_close_wakes_the_waiting_poll() raises:
    var ps = PubSub()
    var iterator = ps.subscribe("a")
    var waker = Waker.noop()
    assert_true(iterator.poll_next(waker).is_pending())
    iterator.close()
    assert_true(waker.woken())
    iterator.close()
    assert_true(iterator.poll_next(waker).is_done())


def test_queue_keeps_order_and_payloads_are_shared() raises:
    var ps = PubSub()
    var first = ps.subscribe("a")
    var second = ps.subscribe("a")
    var payload = Event.parse("[1]")
    ps.publish("a", payload)
    ps.publish("a", Event.parse("2"))
    assert_equal(first.queued(), 2)
    var one = _poll(first).value()
    assert_true(one.same(payload))
    assert_equal(_poll(first).value().to_json(), "2")
    assert_equal(first.queued(), 0)
    assert_true(_poll(second).value().same(payload))
    assert_equal(second.queued(), 1)


def test_dropped_iterator_unsubscribes_and_slot_is_reused() raises:
    var ps = PubSub()
    var first = ps.subscribe("a")
    assert_equal(ps.listener_count("a"), 1)
    _ = first^
    assert_equal(ps.listener_count("a"), 0)
    var second = ps.subscribe("b")
    var third = ps.subscribe("a")
    ps.publish("a", Event.parse("3"))
    assert_true(_poll(second).is_pending())
    assert_equal(_poll(third).value().to_json(), "3")


def test_unsubscribe_one_of_many_listeners() raises:
    var ps = PubSub()
    var first = ps.subscribe("a")
    var second = ps.subscribe("a")
    assert_true(ps.unsubscribe(second.subscription_ids()[0]))
    assert_equal(ps.listener_count("a"), 1)
    ps.publish("a", Event.parse("1"))
    assert_true(_poll(first).is_ready())
    assert_true(_poll(second).is_pending())


def test_publish_wakes_streams_of_an_event_loop() raises:
    var ps = PubSub()
    var loop = EventLoop()
    var ids = List[Int]()
    for _ in range(1000):
        ids.append(loop.add(ps.subscribe("fan")))
    assert_equal(loop.poll(0), 0)
    assert_equal(ps.listener_count("fan"), 1000)
    ps.publish("fan", Event.parse('{"n":1}'))
    assert_equal(loop.poll(1000), 1000)
    assert_equal(loop.stream_events[999].id, ids[999])
    assert_equal(loop.poll(0), 0)
    assert_true(loop.cancel(ids[0]))
    assert_equal(ps.listener_count("fan"), 999)
    assert_equal(loop.stream_count(), 999)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

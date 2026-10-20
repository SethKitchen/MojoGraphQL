# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `EventLoop`, `WakeSet`, `Waker`, `Poll` and `AnyStream`, with
real `eventfd` and epoll descriptors and many streams.

There is no upstream test file. The error paths use real failures: a low
`RLIMIT_NOFILE`, a descriptor that is not watched, a closed epoll
descriptor, and `SIGSTOP` then `SIGCONT` from a child process, which
interrupts `epoll_wait` with `EINTR`.
"""

from std.ffi import external_call
from std.memory import ArcPointer, stack_allocation
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from std.time import perf_counter_ns

from gql_json.value import JsonKind
from gql_stream.event_loop import EPOLLIN, EPOLLOUT, EventLoop
from gql_stream.poll import Event, Poll, PollState
from gql_stream.pubsub import PubSub
from gql_stream.stream import AnyStream, ListStream
from gql_stream.waker import WakeSet, Waker

comptime _RLIMIT_NOFILE: Int32 = 7


def _texts(count: Int) -> List[String]:
    var texts = List[String]()
    var value = 0
    while value < count:
        texts.append(String(value))
        value += 1
    return texts^


def _set_nofile(limit: UInt64, maximum: UInt64):
    var rlimit = stack_allocation[2, UInt64]()
    rlimit.unsafe_store(limit)
    rlimit.unsafe_offset(1).unsafe_store(maximum)
    _ = external_call["setrlimit", Int32](
        _RLIMIT_NOFILE, rlimit.unsafe_bitcast[NoneType]()
    )


def _nofile() -> List[UInt64]:
    var rlimit = stack_allocation[2, UInt64]()
    _ = external_call["getrlimit", Int32](
        _RLIMIT_NOFILE, rlimit.unsafe_bitcast[NoneType]()
    )
    var out = List[UInt64]()
    out.append(rlimit.unsafe_load())
    out.append(rlimit.unsafe_offset(1).unsafe_load())
    return out^


def test_list_stream_runs_to_done() raises:
    var loop = EventLoop()
    var texts = List[String]()
    texts.append("1")
    texts.append('{"a":2}')
    var id = loop.add(ListStream.of_json(texts))
    assert_equal(loop.stream_count(), 1)
    assert_equal(loop.poll(1000), 3)
    assert_equal(loop.stream_events[0].id, id)
    assert_equal(loop.stream_events[0].poll.value().to_json(), "1")
    assert_equal(loop.stream_events[1].poll.value().to_json(), '{"a":2}')
    assert_true(loop.stream_events[2].poll.is_done())
    assert_equal(loop.stream_count(), 0)
    assert_false(loop.has(id))
    assert_equal(loop.add(ListStream.of_json(texts, "boom")), id)
    assert_equal(loop.poll(0), 3)
    assert_true(loop.stream_events[2].poll.is_error())
    assert_equal(loop.stream_events[2].poll.message, "boom")


def test_budget_shares_turns_between_streams() raises:
    var loop = EventLoop(max_events=0, budget=3)
    var first = loop.add(ListStream.of_json(_texts(5)))
    var second = loop.add(AnyStream(ListStream.of_json(_texts(1))))
    assert_equal(loop.poll(0), 5)
    assert_equal(loop.stream_events[2].id, first)
    assert_equal(loop.stream_events[3].id, second)
    assert_true(loop.stream_events[4].poll.is_done())
    assert_equal(loop.poll(-1), 3)
    assert_true(loop.stream_events[2].poll.is_done())
    assert_equal(loop.poll(0), 0)


def test_cancel_closes_and_ids_are_reused() raises:
    var loop = EventLoop()
    var ps = PubSub()
    var first = loop.add(ps.subscribe("t"))
    var second = loop.add(ps.subscribe("t"))
    assert_equal(loop.poll(0), 0)
    assert_true(loop.cancel(first))
    assert_false(loop.cancel(first))
    assert_false(loop.has(-1))
    assert_false(loop.has(99))
    assert_true(loop.has(second))
    assert_equal(ps.listener_count("t"), 1)
    assert_equal(loop.add(ps.subscribe("t")), first)
    assert_equal(loop.waker(second).id(), second)
    var woken = loop.add(ListStream.of_json(_texts(1)))
    assert_true(loop.cancel(woken))
    assert_equal(loop.poll(0), 0)
    assert_equal(loop.stream_count(), 2)


def test_thousands_of_streams_share_one_eventfd() raises:
    var loop = EventLoop()
    var ps = PubSub()
    var count = 5000
    var index = 0
    while index < count:
        _ = loop.add(ps.subscribe("t"))
        index += 1
    assert_equal(loop.poll(0), 0)
    var round = 0
    while round < 3:
        ps.publish("t", Event.parse("1"))
        assert_equal(loop.poll(1000), count)
        round += 1
    assert_equal(loop.poll(0), 0)
    assert_equal(loop.stream_count(), count)


def test_descriptors_and_an_embedded_loop() raises:
    var outer = EventLoop()
    var inner = EventLoop()
    var signal = WakeSet(True)
    outer.watch(signal.fd, EPOLLIN)
    outer.watch(inner.fd(), EPOLLIN)
    assert_equal(outer.poll(0), 0)
    signal.wake(0)
    _ = inner.add(ListStream.of_json(_texts(1)))
    assert_equal(outer.poll(1000), 2)
    assert_equal(len(outer.fd_events), 2)
    assert_equal(inner.poll(0), 2)
    outer.modify(signal.fd, EPOLLOUT)
    assert_equal(outer.poll(0), 1)
    assert_equal(outer.fd_events[0].fd, signal.fd)
    assert_equal(outer.fd_events[0].flags, EPOLLOUT)
    outer.unwatch(signal.fd)
    outer.unwatch(inner.fd())
    assert_equal(outer.poll(0), 0)
    assert_equal(signal.pending(), 1)
    assert_equal(inner.stream_count(), 0)


def test_watch_errors() raises:
    var loop = EventLoop()
    var raised = 0
    try:
        loop.watch(-1, EPOLLIN)
    except error:
        assert_true(String(error).startswith("epoll_ctl failed: errno 9"))
        raised += 1
    try:
        loop.modify(0, EPOLLIN)
    except:
        raised += 1
    try:
        loop.unwatch(0)
    except:
        raised += 1
    assert_equal(raised, 3)


def test_open_errors_under_a_low_descriptor_limit() raises:
    var saved = _nofile()
    var probe = WakeSet(True)
    var lowest = probe.fd
    _ = probe^
    var raised = 0
    _set_nofile(0, saved[1])
    try:
        _ = WakeSet(True)
    except error:
        assert_true(String(error).startswith("eventfd failed: errno 24"))
        raised += 1
    _set_nofile(UInt64(lowest + 1), saved[1])
    try:
        _ = EventLoop()
    except error:
        assert_true(String(error).startswith("epoll_create1 failed"))
        raised += 1
    _set_nofile(saved[0], saved[1])
    assert_equal(raised, 2)


def test_epoll_wait_error_and_eintr() raises:
    var loop = EventLoop()
    var parent = external_call["getpid", Int32]()
    var child = external_call["fork", Int32]()
    if child == 0:
        _ = external_call["usleep", Int32](UInt32(100_000))
        _ = external_call["kill", Int32](parent, Int32(19))
        _ = external_call["usleep", Int32](UInt32(50_000))
        _ = external_call["kill", Int32](parent, Int32(18))
        external_call["_exit", NoneType](Int32(0))
    var start = perf_counter_ns()
    assert_equal(loop.poll(3000), 0)
    assert_true(perf_counter_ns() - start < 2_000_000_000)
    var status = stack_allocation[1, Int32]()
    _ = external_call["waitpid", Int32](
        child, status.unsafe_bitcast[NoneType](), Int32(0)
    )
    _ = external_call["close", Int32](Int32(loop.fd()))
    try:
        _ = loop.poll(0)
    except error:
        assert_true(String(error).startswith("epoll_wait failed: errno 9"))
        return
    raise Error("expected an error")


def test_wakers() raises:
    var set = ArcPointer(WakeSet(False))
    var first = Waker(set, 3)
    var same = Waker(set, 3)
    var other_id = Waker(set, 4)
    var other_set = Waker.noop()
    assert_true(first.will_wake(same))
    assert_false(first.will_wake(other_id))
    assert_false(other_set.will_wake(Waker(ArcPointer(WakeSet(False)), 0)))
    assert_false(first.woken())
    assert_false(Waker(set, 0).woken())
    first.wake()
    first.wake()
    assert_true(same.woken())
    assert_equal(first.id(), 3)
    assert_equal(set[].pending(), 1)
    var ids = List[Int]()
    set[].take(ids)
    assert_equal(len(ids), 1)
    assert_false(first.woken())


def test_poll_states_and_events() raises:
    assert_equal(String(PollState.READY), "READY")
    assert_equal(String(PollState.PENDING), "PENDING")
    assert_equal(String(PollState.DONE), "DONE")
    assert_equal(String(PollState.ERROR), "ERROR")
    assert_equal(String(PollState(7)), "PollState(7)")
    assert_true(PollState.ERROR.is_valid())
    assert_false(PollState(4).is_valid())
    var event = Event.parse('{"a":[1]}')
    assert_true(event.kind() == JsonKind.OBJECT)
    assert_true(event.same(event.copy()))
    assert_false(event.same(Event.parse('{"a":[1]}')))
    var poll = Poll.ready(event.copy())
    assert_true(poll.is_ready())
    assert_false(poll.is_pending() or poll.is_done() or poll.is_error())
    assert_true(Poll.error("x").is_error())
    var stream = ListStream.of_json(_texts(2))
    var waker = Waker.noop()
    _ = stream.poll_next(waker)
    stream.close()
    assert_true(stream.closed())
    assert_true(stream.poll_next(waker).is_done())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of the abort signal, `close()` and `abort()` of the subsequent
results: graphql-js v17.0.2 (71606d73)
`src/execution/incremental/__tests__/defer-test.ts` and `stream-test.ts`.

The upstream iterator with a spy on `return()` is a `ProbeStream`. Its
state counts the polls (the upstream `next()` calls) and the closes (the
upstream `return()` calls). A `next()` promise that never resolves is a
`ProbeStream` that is `PENDING` after its items. `return()` and the
disposal of `Symbol.asyncDispose` are `close()`. The upstream abort comes
before the next `next()`: the next poll raises the reason, and each later
poll is `DONE`.

The upstream cases that are adapted:

- "Returns underlying async iterables when returned generator is thrown":
  there is no `throw()`. `close()` closes the source, as `throw()` does;
  the error is the caller's own.
- "cancels pending deferred tasks with async child stream cleanup": the
  abort comes after the deferred fragment completes, not during the
  initial execution.
- "cancels streaming when aborted during async iterator next" and "should
  ignore repeated cancellation attempts during incremental execution": the
  abort comes after a poll that is `PENDING`, and the deferred field is
  synchronous.

These upstream cases are not ported:

- "should ignore deferred payloads resolved after cancellation", "should
  ignore deferred errors after cancellation", "cancels streaming when
  aborted while item promise is pending", "cancels pending stream item
  executors with deferred work when consumer cancels", "cancels stream
  item executors with deferred work and nested streams" and "stops
  streaming when a pending stream item resolves after cancellation": they
  resolve a promise after the cancellation. Resolvers and stream items are
  synchronous, so nothing resolves later.
- "cancels tasks and streams when aborted before initial execution
  finishes" and "cancels async stream source cleanup when aborted before
  initial execution finishes": the initial execution is synchronous, so no
  abort can come during it.
- "Awaits stream source async iterable return before iterator return
  settles", "waits for async stream source return cleanup before abort
  cancellation settles" and "waits for async deferred nested stream item
  cleanup before abort cancellation settles": `close()` is synchronous.
- "stops when the stream queue is back-pressured and the consumer
  cancels": a synchronous iterable is a list, and no item is read before
  the first poll.
"""

from std.memory import ArcPointer
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from gql_execution.abort import AbortController
from gql_execution.execute import ExecutionArgs
from gql_execution.incremental import experimental_execute_incrementally
from gql_language.parser import parse
from gql_schema.build import build_schema
from gql_stream.waker import Waker

from _incremental import ProbeState, payloads, probe, root_value

comptime _SDL = """
type Todo { id: ID items: [String] author: User }
type User { id: ID name: String }
type Friend { id: ID name: String }
type Query {
  todo: Todo
  scalarList: [String]
  slowScalarList: [String]
  friendList: [Friend]
}
"""

comptime _ABORTED = "This operation was aborted"


def _friends(n: Int) -> List[String]:
    """Return the JSON of the first `n` upstream `friends`."""
    var all = List[String]()
    all.append('{"name":"Luke","id":1}')
    all.append('{"name":"Han","id":2}')
    all.append('{"name":"Leia","id":3}')
    var out = List[String]()
    for index in range(n):
        out.append(all[index])
    return out^


def _root_with(
    mut args: ExecutionArgs, field: String, texts: List[String], ends: Bool
) raises -> ArcPointer[ProbeState]:
    """Make the root value `{field: ProbeStream}`, and return the state."""
    var root = args.values.add_object()
    var made = probe(args.values, texts, ends)
    args.values.add_member(root, field, made[0])
    args.root_value = root
    return made[1]


def _todo_with_items(
    mut args: ExecutionArgs, texts: List[String], ends: Bool
) raises -> ArcPointer[ProbeState]:
    """Make the root value `{todo: {id, author, items: ProbeStream}}`."""
    var todo = root_value(args.values, '{"id":"todo","author":{"id":"a"}}')
    var made = probe(args.values, texts, ends)
    args.values.add_member(todo, "items", made[0])
    var root = args.values.add_object()
    args.values.add_member(root, "todo", todo)
    args.root_value = root
    return made[1]


def test_allows_deferred_execution_when_passed_abort_signal_if_not_aborted() raises:
    var controller = AbortController()
    var args = ExecutionArgs()
    args.root_value = root_value(args.values, '{"todo":{"author":{"id":"1"}}}')
    args.abort_signal = controller.signal()
    var got = payloads(
        build_schema(_SDL),
        "query { todo { id ... on Todo @defer { author { id } } } }",
        args^,
    )
    assert_equal(len(got), 2)
    assert_equal(
        got[0],
        (
            '{"data":{"todo":{"id":null}},"pending":[{"id":"0","path":["todo"]}],'
            '"hasNext":true}'
        ),
    )
    assert_equal(
        got[1],
        (
            '{"hasNext":false,"incremental":[{"id":"0","data":{"author":{"id":"1"}}}],'
            '"completed":[{"id":"0"}]}'
        ),
    )


def test_stops_deferred_execution_when_aborted() raises:
    var controller = AbortController()
    controller.abort()
    var args = ExecutionArgs()
    args.root_value = root_value(args.values, '{"todo":{"id":"1"}}')
    args.abort_signal = controller.signal()
    var message = String("")
    try:
        _ = experimental_execute_incrementally(
            build_schema(_SDL),
            parse("query { todo { id ... on Todo @defer { author { id } } } }"),
            args^,
        )
    except e:
        message = String(e)
    assert_equal(message, _ABORTED)


def test_stops_deferred_execution_when_aborted_mid_execution() raises:
    var controller = AbortController()
    var args = ExecutionArgs()
    args.root_value = root_value(
        args.values, '{"todo":{"id":"1","author":{"id":"2"}}}'
    )
    args.abort_signal = controller.signal()
    var results = experimental_execute_incrementally(
        build_schema(_SDL),
        parse("query { ... on Query @defer { todo { id author { id } } } }"),
        args^,
    )
    var stream = results.take_subsequent_results()
    controller.abort()
    var waker = Waker.noop()
    var message = String("")
    try:
        _ = stream.poll_payload(waker)
    except e:
        message = String(e)
    assert_equal(message, _ABORTED)
    assert_true(stream.is_done())
    assert_false(stream.poll_payload(waker))
    assert_true(stream.poll_next(waker).is_done())


def test_cancels_pending_deferred_execution_groups() raises:
    var controller = AbortController()
    var args = ExecutionArgs()
    args.root_value = root_value(
        args.values, '{"scalarList":["a"],"slowScalarList":["b"]}'
    )
    args.abort_signal = controller.signal()
    args.enable_early_execution = True
    var results = experimental_execute_incrementally(
        build_schema(_SDL),
        parse("{ scalarList ... @defer { slowScalarList } }"),
        args^,
    )
    assert_true(results.is_incremental())
    var stream = results.take_subsequent_results()
    controller.abort()
    var waker = Waker.noop()
    var poll = stream.poll_next(waker)
    assert_true(poll.is_error())
    assert_equal(poll.message, _ABORTED)
    assert_true(stream.poll_next(waker).is_done())


def test_cancels_deferred_tasks_with_child_stream_cleanup() raises:
    var controller = AbortController()
    var args = ExecutionArgs()
    var state = _todo_with_items(args, List[String](), False)
    args.abort_signal = controller.signal()
    args.enable_early_execution = True
    var results = experimental_execute_incrementally(
        build_schema(_SDL),
        parse(
            "query { todo { id ... @defer { items @stream(initialCount: 0)"
            " author { id } } } }"
        ),
        args^,
    )
    var stream = results.take_subsequent_results()
    var waker = Waker.noop()
    assert_true(stream.poll_next(waker).is_ready())
    controller.abort()
    var poll = stream.poll_next(waker)
    assert_true(poll.is_error())
    assert_equal(poll.message, _ABORTED)
    assert_equal(state[].closes, 1)
    assert_true(stream.poll_next(waker).is_done())


def test_does_not_close_an_exhausted_event_stream() raises:
    var args = ExecutionArgs()
    var texts = List[String]()
    texts.append('"apple"')
    texts.append('"banana"')
    texts.append('"coconut"')
    var state = _root_with(args, "scalarList", texts, True)
    var got = payloads(
        build_schema(_SDL), "{ scalarList @stream(initialCount: 1) }", args^
    )
    assert_equal(len(got), 2)
    assert_equal(
        got[0],
        (
            '{"data":{"scalarList":["apple"]},"pending":[{"id":"0","path":'
            '["scalarList"]}],"hasNext":true}'
        ),
    )
    assert_equal(
        got[1],
        (
            '{"hasNext":false,"incremental":[{"id":"0","items":["banana","coconut"]}],'
            '"completed":[{"id":"0"}]}'
        ),
    )
    assert_equal(state[].closes, 0)
    assert_equal(state[].polls, 4)


def test_closes_event_streams_when_returned() raises:
    var args = ExecutionArgs()
    var state = _root_with(args, "friendList", List[String](), False)
    var results = experimental_execute_incrementally(
        build_schema(_SDL),
        parse("query { friendList @stream(initialCount: 0) { id } }"),
        args^,
    )
    assert_equal(
        results.to_json(),
        (
            '{"data":{"friendList":[]},"pending":[{"id":"0","path":'
            '["friendList"]}],"hasNext":true}'
        ),
    )
    var stream = results.take_subsequent_results()
    var waker = Waker.noop()
    assert_true(stream.poll_next(waker).is_pending())
    stream.close()
    assert_true(stream.poll_next(waker).is_done())
    assert_equal(state[].closes, 1)


def test_closes_when_the_event_stream_ends_on_its_own() raises:
    var args = ExecutionArgs()
    _ = _root_with(args, "friendList", _friends(3), True)
    var results = experimental_execute_incrementally(
        build_schema(_SDL),
        parse("query { friendList @stream(initialCount: 1) { name id } }"),
        args^,
    )
    assert_equal(
        results.to_json(),
        (
            '{"data":{"friendList":[{"name":"Luke","id":"1"}]},"pending":'
            '[{"id":"0","path":["friendList"]}],"hasNext":true}'
        ),
    )
    var stream = results.take_subsequent_results()
    stream.close()
    var waker = Waker.noop()
    assert_true(stream.poll_next(waker).is_done())


def test_closes_event_streams_when_thrown() raises:
    var args = ExecutionArgs()
    var state = _root_with(args, "friendList", _friends(3), True)
    var results = experimental_execute_incrementally(
        build_schema(_SDL),
        parse(
            "query { friendList @stream(initialCount: 1) { ... @defer { name }"
            " id } }"
        ),
        args^,
    )
    assert_equal(
        results.to_json(),
        (
            '{"data":{"friendList":[{"id":"1"}]},"pending":[{"id":"0","path":'
            '["friendList",0]},{"id":"1","path":["friendList"]}],"hasNext":true}'
        ),
    )
    var stream = results.take_subsequent_results()
    stream.close()
    var waker = Waker.noop()
    assert_true(stream.poll_next(waker).is_done())
    assert_equal(state[].closes, 1)


def test_closes_event_streams_when_disposed_before_completion() raises:
    var args = ExecutionArgs()
    var state = _root_with(args, "friendList", List[String](), False)
    var results = experimental_execute_incrementally(
        build_schema(_SDL),
        parse("query { friendList @stream(initialCount: 0) { id } }"),
        args^,
    )
    var stream = results.take_subsequent_results()
    stream.close()
    assert_equal(state[].closes, 1)


def test_does_not_close_event_streams_when_disposed_after_completion() raises:
    var args = ExecutionArgs()
    var state = _root_with(args, "friendList", _friends(1), True)
    var results = experimental_execute_incrementally(
        build_schema(_SDL),
        parse("query { friendList @stream(initialCount: 0) { id } }"),
        args^,
    )
    var stream = results.take_subsequent_results()
    var waker = Waker.noop()
    assert_equal(
        stream.poll_next(waker).value().to_json(),
        (
            '{"hasNext":false,"incremental":[{"id":"0","items":[{"id":"1"}]}],'
            '"completed":[{"id":"0"}]}'
        ),
    )
    stream.close()
    assert_equal(state[].closes, 0)


def test_stops_streamed_execution_when_aborted() raises:
    var controller = AbortController()
    var args = ExecutionArgs()
    args.root_value = root_value(
        args.values, '{"todo":{"id":"1","items":["item"]}}'
    )
    args.abort_signal = controller.signal()
    var results = experimental_execute_incrementally(
        build_schema(_SDL),
        parse("query { todo { id items @stream } }"),
        args^,
    )
    var stream = results.take_subsequent_results()
    controller.abort()
    var waker = Waker.noop()
    var poll = stream.poll_next(waker)
    assert_true(poll.is_error())
    assert_equal(poll.message, _ABORTED)


def test_cancels_streaming_when_aborted_during_next() raises:
    var controller = AbortController()
    var args = ExecutionArgs()
    var state = _root_with(args, "scalarList", List[String](), False)
    args.abort_signal = controller.signal()
    var results = experimental_execute_incrementally(
        build_schema(_SDL),
        parse("{ scalarList @stream(initialCount: 0) }"),
        args^,
    )
    var stream = results.take_subsequent_results()
    var waker = Waker.noop()
    assert_true(stream.poll_next(waker).is_pending())
    controller.abort()
    var poll = stream.poll_next(waker)
    assert_true(poll.is_error())
    assert_equal(poll.message, _ABORTED)
    assert_equal(state[].closes, 1)
    assert_true(stream.poll_next(waker).is_done())


def test_ignores_repeated_cancellation_attempts() raises:
    var controller = AbortController()
    var args = ExecutionArgs()
    var state = _todo_with_items(args, List[String](), False)
    args.abort_signal = controller.signal()
    args.enable_early_execution = True
    var results = experimental_execute_incrementally(
        build_schema(_SDL),
        parse(
            "query { todo { id items @stream(initialCount: 0) ... @defer {"
            " author { id } } } }"
        ),
        args^,
    )
    var stream = results.take_subsequent_results()
    controller.abort()
    var waker = Waker.noop()
    var poll = stream.poll_next(waker)
    assert_true(poll.is_error())
    assert_equal(poll.message, _ABORTED)
    assert_true(stream.poll_next(waker).is_done())
    assert_equal(state[].closes, 1)
    controller.abort()
    stream.abort()
    stream.close()
    assert_true(stream.poll_next(waker).is_done())
    assert_equal(state[].closes, 1)


def test_abort_with_a_reason() raises:
    var controller = AbortController()
    var args = ExecutionArgs()
    var state = _root_with(args, "scalarList", List[String](), False)
    args.abort_signal = controller.signal()
    var results = experimental_execute_incrementally(
        build_schema(_SDL),
        parse("{ scalarList @stream(initialCount: 0) }"),
        args^,
    )
    var stream = results.take_subsequent_results()
    controller.abort("stop")
    controller.abort("again")
    var waker = Waker.noop()
    var poll = stream.poll_next(waker)
    assert_true(poll.is_error())
    assert_equal(poll.message, "stop")
    assert_equal(state[].closes, 1)


def test_abort_of_the_stream() raises:
    var args = ExecutionArgs()
    var state = _root_with(args, "scalarList", List[String](), False)
    var results = experimental_execute_incrementally(
        build_schema(_SDL),
        parse("{ scalarList @stream(initialCount: 0) }"),
        args^,
    )
    var stream = results.take_subsequent_results()
    stream.abort()
    assert_true(stream.is_done())
    assert_equal(state[].closes, 1)
    var waker = Waker.noop()
    var poll = stream.poll_next(waker)
    assert_true(poll.is_error())
    assert_equal(poll.message, _ABORTED)
    assert_true(stream.poll_next(waker).is_done())


def test_abort_after_the_last_payload() raises:
    var controller = AbortController()
    var args = ExecutionArgs()
    args.root_value = root_value(args.values, '{"scalarList":["a","b"]}')
    args.abort_signal = controller.signal()
    var results = experimental_execute_incrementally(
        build_schema(_SDL),
        parse("{ scalarList @stream(initialCount: 1) }"),
        args^,
    )
    var stream = results.take_subsequent_results()
    var waker = Waker.noop()
    assert_true(stream.poll_next(waker).is_ready())
    controller.abort()
    assert_true(stream.poll_next(waker).is_done())


def test_signal_state() raises:
    var controller = AbortController()
    var signal = controller.signal()
    assert_false(signal.aborted())
    assert_equal(signal.reason(), "")
    controller.abort()
    assert_true(signal.aborted())
    assert_equal(signal.reason(), _ABORTED)


def _deferred_items(early: Bool) raises -> List[String]:
    """Execute a deferred `@stream` of a `ProbeStream`, and return the
    payloads, after a check of when the deferred fields execute."""
    var args = ExecutionArgs()
    var texts = List[String]()
    texts.append('"a"')
    texts.append('"b"')
    var state = _todo_with_items(args, texts, True)
    args.enable_early_execution = early
    var results = experimental_execute_incrementally(
        build_schema(_SDL),
        parse(
            "query { todo { id ... @defer { items @stream(initialCount: 1) } }"
            " }"
        ),
        args^,
    )
    # graphql-js executes the deferred fields before the initial result
    # only with `enableEarlyExecution`.
    if early:
        assert_equal(state[].polls, 1)
    else:
        assert_equal(state[].polls, 0)
    var out = List[String]()
    out.append(results.to_json())
    var stream = results.take_subsequent_results()
    var waker = Waker.noop()
    while True:
        var poll = stream.poll_next(waker)
        if poll.is_done():
            return out^
        out.append(poll.value().to_json())


def test_executes_deferred_fragments_early_when_specified() raises:
    var late = _deferred_items(False)
    var early = _deferred_items(True)
    assert_equal(len(late), 3)
    assert_equal(len(early), len(late))
    for index in range(len(late)):
        assert_equal(early[index], late[index])
    assert_equal(
        late[1],
        (
            '{"hasNext":true,"pending":[{"id":"1","path":["todo","items"]}],'
            '"incremental":[{"id":"0","data":{"items":["a"]}}],'
            '"completed":[{"id":"0"}]}'
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

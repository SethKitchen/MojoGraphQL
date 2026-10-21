# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Incremental delivery: `@defer` and `@stream`, with
`experimental_execute_incrementally`.

Port of graphql-js v17.0.2 `experimentalExecuteIncrementally`
(`execution/execute.ts`), `execution/incremental/IncrementalExecutor.ts`,
`execution/incremental/IncrementalPublisher.ts` and
`execution/incremental/WorkQueue.ts`. The executor of `execute.mojo` runs
the fields; `incremental_graph.mojo` has the records and the execution
plan; `incremental_results.mojo` has the payloads.

**The result.** `experimental_execute_incrementally` returns one
`ExecutionResult` when the operation has no deferred fragment and no
stream to deliver. Otherwise it returns the initial result, with
`pending` and `hasNext`, and a `SubsequentResultStream`: a `gql_stream`
`EventStream` whose events are the JSON of the subsequent payloads.

**Ticks.** graphql-js delivers the work that settles in one turn of the
event loop as one payload. Execution here is synchronous, so a poll runs
one tick, as graphql-js runs one turn with resolvers that do not return
promises:

- The first tick executes the execution groups of the initial delivery
  groups. The execution groups that become ready in a tick, as the
  children of a completed delivery group, execute in that tick too.
- A stream that starts in a tick gives its first items in the next tick.
  A tick gives at most 100 items of a stream, the capacity of the
  graphql-js stream queue. The items of an event stream are those that are
  ready: a poll that is `PENDING` ends them.
- An item that fails the stream ends its batch. The failure is in the next
  tick, after the items before it.
- A tick with no event gives no payload. A poll returns `PENDING` when no
  stream can make progress.

The tests compare each payload with graphql-js v17.0.2, run in
Node.js on the same operation.

**Differences from upstream.**

- Execution is synchronous: `experimental_execute_incrementally` returns
  at once, and the subsequent results are a pull-based `EventStream`, not
  an `AsyncGenerator`. `close()` is `return()`; there is no `throw()`.
- `@stream` streams a list, or an event stream that `Values.add_stream`
  made: the Mojo form of an async iterable. An item of an event stream is
  a JSON value. Before `initialCount`, an item that is not ready starts the
  stream early, at that index. An event stream with no `@stream` must have
  each item ready, or the field fails.
- `ExecutionArgs.enable_early_execution` executes the groups of the
  initial result before `experimental_execute_incrementally` returns.
  Without it, they execute at the first poll. A nested group executes in
  the tick that releases it, with or without the flag. The payloads do not
  change, because the resolvers are synchronous.
- `ExecutionArgs.abort_signal` is read before the root fields execute and
  at each poll, not during a tick: an abort cannot stop a resolver. A
  signal that aborted before the execution makes
  `experimental_execute_incrementally` raise the reason. A later abort
  closes the event streams of `@stream`, and the next poll gives the
  reason one time. `abort()` aborts the stream with no signal.
- The arena of the execution stays with the subsequent results until the
  stream is dropped, because the deferred fields read it.
- `field_timing` records no timing for an incremental execution.
"""

from std.memory import ArcPointer

from gql_json.value import JsonDocument
from gql_execution.abort import ABORT_REASON, AbortSignal
from gql_language.ast import Document, OperationType
from gql_language.error import GraphQLError, PathSegment
from gql_schema.definition import Schema
from gql_execution.execute import (
    ExecutionArgs,
    ExecutionResult,
    Resolvers,
    _Executor,
    assert_valid_execution_arguments,
)
from gql_execution.incremental_graph import is_prefix
from gql_execution.incremental_results import (
    CompletedResult,
    IncrementalResult,
    InitialIncrementalExecutionResult,
    PendingResult,
    SubsequentIncrementalExecutionResult,
    subsequent_document,
)
from gql_execution.value import UNDEFINED, Values
from gql_stream.poll import Event, EventStream, Poll
from gql_stream.waker import Waker

comptime _Untracked = UntrackedOrigin[mut=False]
comptime _Engine = _Executor[_Untracked, _Untracked, _Untracked]
"""The executor of an incremental execution: its schema, document and
resolvers are in `ArcPointer`s that the stream keeps."""

comptime STREAM_CAPACITY = 100
"""The most items of one stream in one tick: the graphql-js stream queue
capacity."""

comptime _TASK_SUCCESS = 0
comptime _TASK_FAILURE = 1
comptime _STREAM_ITEMS = 2
comptime _STREAM_SUCCESS = 3
comptime _STREAM_FAILURE = 4


@fieldwise_init
struct _Work(Copyable, Movable):
    """graphql-js 17 `IncrementalWork`: the records that one run made."""

    var groups: List[Int32]
    var tasks: List[Int32]
    var streams: List[Int32]


struct _GroupNode(Copyable, Movable):
    """graphql-js 17 `GroupNode` of the work queue."""

    var present: Bool
    var child_groups: List[Int32]
    var tasks: List[Int32]
    var pending: Int

    def __init__(out self):
        self.present = False
        self.child_groups = List[Int32]()
        self.tasks = List[Int32]()
        self.pending = 0


struct _TaskNode(Movable):
    """graphql-js 17 `TaskNode`, with the value of the task."""

    var present: Bool
    var has_value: Bool
    var data: JsonDocument
    var root: Int
    var errors: List[GraphQLError]
    var path: List[PathSegment]
    var child_streams: List[Int32]

    def __init__(out self):
        self.present = False
        self.has_value = False
        self.data = JsonDocument()
        self.root = 0
        self.errors = List[GraphQLError]()
        self.path = List[PathSegment]()
        self.child_streams = List[Int32]()


struct _Event(Movable):
    """A graph event of the work queue."""

    var kind: Int
    var id: Int
    var errors: List[GraphQLError]
    var data: JsonDocument
    var root: Int
    var works: List[_Work]
    var stopped: Bool

    def __init__(out self, kind: Int, id: Int):
        self.kind = kind
        self.id = id
        self.errors = List[GraphQLError]()
        self.data = JsonDocument()
        self.root = 0
        self.works = List[_Work]()
        self.stopped = False


def _pin[T: AnyType](value: T) -> Pointer[T, _Untracked]:
    """Return a pointer to a value that an `ArcPointer` keeps alive."""
    return Pointer(to=value).unsafe_origin_cast[_Untracked]()


def _incremental_work(mut engine: _Engine) -> _Work:
    """Return graphql-js 17 `getIncrementalWork` for the current run: the
    execution groups and the streams under a path that the run made `null`
    are dropped, and the dropped streams are closed."""
    var tasks = List[Int32]()
    var index = 0
    while index < len(engine.inc.work_tasks):
        var task = engine.inc.work_tasks[index]
        if not engine.inc.has_nulled_position(engine.inc.tasks[Int(task)].path):
            tasks.append(task)
        index += 1
    var streams = List[Int32]()
    index = 0
    while index < len(engine.inc.work_streams):
        var stream = Int(engine.inc.work_streams[index])
        if engine.inc.has_nulled_position(engine.inc.streams[stream].path):
            _close_source(engine, stream)
        else:
            streams.append(Int32(stream))
        index += 1
    return _Work(engine.inc.work_groups.copy(), tasks^, streams^)


def _close_source(mut engine: _Engine, stream: Int):
    """Close the event stream of an item stream, if it has one and it has
    not ended: graphql-js returns only an iterator that is not done."""
    ref record = engine.inc.streams[stream]
    if record.stopped:
        return
    record.stopped = True
    if record.source:
        record.source.value().close()


struct SubsequentResultStream(EventStream):
    """The subsequent results of an incremental execution: graphql-js 17
    `subsequentResults`, with the work queue and the publisher. Each event
    is the JSON of a `SubsequentIncrementalExecutionResult`."""

    var schema: ArcPointer[Schema]
    """The schema."""
    var document: ArcPointer[Document]
    """The document."""
    var resolvers: ArcPointer[Resolvers]
    """The resolvers."""
    var engine: _Engine
    """The executor, with the arena and the records."""
    var _group_nodes: List[_GroupNode]
    var _task_nodes: List[_TaskNode]
    var _root_groups: List[Int32]
    var _root_streams: List[Int32]
    var _ids: Dict[Int, String]
    var _next_id: Int
    var _scheduled: List[Int32]
    var _failures: List[List[GraphQLError]]
    var _events: List[_Event]
    var _payload: SubsequentIncrementalExecutionResult
    var _started: Bool
    var _finished: Bool
    var _signal: Optional[AbortSignal]
    var _abort_reason: Optional[String]
    var _groups_started: Bool

    def __init__(
        out self,
        schema: ArcPointer[Schema],
        document: ArcPointer[Document],
        resolvers: ArcPointer[Resolvers],
        var engine: _Engine,
    ):
        """Keep an executor after its initial run.

        Args:
            schema: The schema of the executor.
            document: The document of the executor.
            resolvers: The resolvers of the executor.
            engine: The executor.
        """
        self.schema = schema
        self.document = document
        self.resolvers = resolvers
        self.engine = engine^
        self._group_nodes = List[_GroupNode]()
        self._task_nodes = List[_TaskNode]()
        self._root_groups = List[Int32]()
        self._root_streams = List[Int32]()
        self._ids = Dict[Int, String]()
        self._next_id = 0
        self._scheduled = List[Int32]()
        self._failures = List[List[GraphQLError]]()
        self._events = List[_Event]()
        self._payload = SubsequentIncrementalExecutionResult()
        self._started = False
        self._finished = False
        self._signal = None
        self._abort_reason = None
        self._groups_started = False

    # --- the work queue: graphql-js 17 createWorkQueue -------------------

    def _sync_nodes(mut self):
        """Give each new record its node."""
        while len(self._group_nodes) < len(self.engine.inc.groups):
            self._group_nodes.append(_GroupNode())
        while len(self._task_nodes) < len(self.engine.inc.tasks):
            self._task_nodes.append(_TaskNode())
        while len(self._failures) < len(self.engine.inc.streams):
            self._failures.append(List[GraphQLError]())

    def integrate(
        mut self, work: _Work, parent_task: Int, mut new_streams: List[Int32]
    ) -> List[Int32]:
        """Run graphql-js 17 `maybeIntegrateWork`.

        Args:
            work: The records of a run.
            parent_task: The task of the run, or -1.
            new_streams: Gets the streams to start now.

        Returns:
            The new root groups.
        """
        self._sync_nodes()
        var new_groups = List[Int32]()
        var visited = List[Int32]()
        var index = 0
        while index < len(work.groups):
            self._add_group(
                work.groups[index],
                work.groups,
                new_groups,
                visited,
                parent_task,
            )
            index += 1
        index = 0
        while index < len(work.tasks):
            self._add_task(Int(work.tasks[index]))
            index += 1
        if parent_task < 0:
            new_streams.extend(work.streams.copy())
        else:
            self._task_nodes[parent_task].child_streams.extend(
                work.streams.copy()
            )
        return new_groups^

    def _add_group(
        mut self,
        group: Int32,
        group_set: List[Int32],
        mut new_groups: List[Int32],
        mut visited: List[Int32],
        parent_task: Int,
    ):
        """Run graphql-js 17 `addGroup`: the parent of a group comes
        first."""
        if group in visited:
            return
        visited.append(group)
        var parent = self.engine.inc.groups[Int(group)].parent
        if parent >= 0 and Int32(parent) in group_set:
            self._add_group(
                Int32(parent), group_set, new_groups, visited, parent_task
            )
        self._group_nodes[Int(group)] = _GroupNode()
        self._group_nodes[Int(group)].present = True
        # A group of a task always has a parent: the task's own group, or
        # an ancestor of it. That parent is present while the task runs.
        if parent < 0:
            new_groups.append(group)
        else:
            self._group_nodes[parent].child_groups.append(group)

    def _add_task(mut self, task: Int):
        """Run graphql-js 17 `addTask`. Each group of a new task is
        present: a run makes tasks only for the groups of its own map."""
        var groups = self.engine.inc.tasks[task].groups.copy()
        var index = 0
        while index < len(groups):
            var group = Int(groups[index])
            self._group_nodes[group].tasks.append(Int32(task))
            self._group_nodes[group].pending += 1
            if Int32(group) in self._root_groups:
                self._start_task(task)
            index += 1

    def prune(mut self, groups: List[Int32], mut out: List[Int32]):
        """Run graphql-js 17 `pruneEmptyGroups`.

        Args:
            groups: The new groups.
            out: Gets the groups that have work, or the first descendants
                that have work.
        """
        var index = 0
        while index < len(groups):
            var group = Int(groups[index])
            if self._group_nodes[group].pending == 0:
                self._group_nodes[group].present = False
                var children = self._group_nodes[group].child_groups.copy()
                self.prune(children, out)
            else:
                out.append(Int32(group))
            index += 1

    def _start_new_work(mut self, groups: List[Int32], streams: List[Int32]):
        """Run graphql-js 17 `startNewWork`."""
        var index = 0
        while index < len(groups):
            self._root_groups.append(groups[index])
            self._start_group(Int(groups[index]))
            index += 1
        index = 0
        while index < len(streams):
            self._root_streams.append(streams[index])
            self._scheduled.append(streams[index])
            index += 1

    def _start_group(mut self, group: Int):
        """Run graphql-js 17 `startGroup`."""
        var tasks = self._group_nodes[group].tasks.copy()
        var index = 0
        while index < len(tasks):
            self._start_task(Int(tasks[index]))
            index += 1

    def _start_task(mut self, task: Int):
        """Run graphql-js 17 `startTask`: execute the execution group now,
        and queue its event."""
        if self._task_nodes[task].present:
            return
        self._task_nodes[task].present = True
        var fresh = JsonDocument()
        self.engine.swap_data(fresh)
        var errors = List[GraphQLError]()
        swap(errors, self.engine.errors)
        try:
            var root = self.engine.run_task(task)
            var event = _Event(_TASK_SUCCESS, task)
            event.root = root
            swap(event.data, self.engine.data)
            swap(event.errors, self.engine.errors)
            event.works.append(_incremental_work(self.engine))
            self._events.append(event^)
        except e:
            self.engine.path.clear()
            var event = _Event(_TASK_FAILURE, task)
            event.errors.append(e^)
            self._events.append(event^)

    def _stream_batch(mut self, stream: Int, waker: Waker) -> Bool:
        """Complete the items of a stream for this tick: the loop of
        graphql-js 17 `buildStreamItemQueue`, and the batch that the stream
        queue delivers. Return True when the stream gave an event."""
        self._sync_nodes()
        if self._failures[stream]:
            var event = _Event(_STREAM_FAILURE, stream)
            swap(event.errors, self._failures[stream])
            self._events.append(event^)
            return True
        var fresh = JsonDocument()
        self.engine.swap_data(fresh)
        var items = self.engine.data.add_array()
        var event = _Event(_STREAM_ITEMS, stream)
        var poll_waker = waker.copy()
        var count = 0
        var done = False
        var pending = False
        var failure = List[GraphQLError]()
        var group = self.engine.inc.streams[stream].group
        var parent = self.engine.inc.streams[stream].parent_type
        var field = self.engine.inc.streams[stream].field
        var item_type = self.engine.inc.streams[stream].item_type
        while count < STREAM_CAPACITY and not done and not pending:
            var item: Int
            if self.engine.inc.streams[stream].source:
                var poll = (
                    self.engine.inc.streams[stream]
                    .source.value()
                    .poll_next(poll_waker)
                )
                if poll.is_pending():
                    pending = True
                    continue
                if poll.is_done():
                    done = True
                    continue
                if poll.is_error():
                    self.engine.path = self.engine.inc.streams[
                        stream
                    ].path.copy()
                    failure.append(
                        self.engine._locate(
                            GraphQLError(poll.message),
                            group,
                            len(self.engine.path),
                        )
                    )
                    break
                ref value = poll.event.value()
                item = self.engine.values.add_json(
                    value.document[], value.root()
                )
            else:
                item = self.engine.inc.streams[stream].next_item
                if item == UNDEFINED:
                    done = True
                    continue
                self.engine.inc.streams[
                    stream
                ].next_item = self.engine.values.next(item)
            var index = self.engine.inc.streams[stream].index
            self.engine.inc.streams[stream].index += 1
            self.engine.inc.begin_run(-1, List[Int32]())
            self.engine.errors.clear()
            self.engine.path = self.engine.inc.streams[stream].path.copy()
            try:
                self.engine.complete_item(
                    items, item_type, group, parent, field, item, index
                )
            except e:
                failure.append(e^)
                break
            self.engine.path.clear()
            event.errors.extend(self.engine.errors.copy())
            event.works.append(_incremental_work(self.engine))
            count += 1
        self.engine.path.clear()
        if failure:
            _close_source(self.engine, stream)
            if count == 0:
                var failed = _Event(_STREAM_FAILURE, stream)
                failed.errors = failure^
                self._events.append(failed^)
                return True
            self._failures[stream] = failure^
            self._scheduled.append(Int32(stream))
        elif done:
            self.engine.inc.streams[stream].stopped = True
            if count == 0:
                self._events.append(_Event(_STREAM_SUCCESS, stream))
                return True
            event.stopped = True
        else:
            self._scheduled.append(Int32(stream))
            if count == 0:
                return False
        swap(event.data, self.engine.data)
        event.root = items
        self._events.append(event^)
        return True

    def _handle(mut self, mut event: _Event):
        """Run graphql-js 17 `handleGraphEvents` for one graph event, and
        give its work queue events to the publisher."""
        if event.kind == _TASK_SUCCESS:
            self._task_success(event)
        elif event.kind == _TASK_FAILURE:
            self._task_failure(event)
        elif event.kind == _STREAM_ITEMS:
            self._stream_items(event)
        else:
            # `STREAM_SUCCESS` or `STREAM_FAILURE`; a scheduled stream is a
            # root stream, so upstream's `rootStreams.has` always holds.
            self._remove_root_stream(event.id)
            self._completed(2 * event.id + 1, event.errors.copy())

    def _task_success(mut self, mut event: _Event):
        """Run graphql-js 17 `taskSuccess`."""
        var task = event.id
        ref node = self._task_nodes[task]
        node.has_value = True
        swap(node.data, event.data)
        node.root = event.root
        swap(node.errors, event.errors)
        node.path = self.engine.path_segments(self.engine.inc.tasks[task].path)
        var unused = List[Int32]()
        _ = self.integrate(event.works[0], task, unused)
        var new_groups = List[Int32]()
        var new_streams = List[Int32]()
        var groups = self.engine.inc.tasks[task].groups.copy()
        var index = 0
        while index < len(groups):
            var group = Int(groups[index])
            if self._group_nodes[group].present:
                self._group_nodes[group].pending -= 1
                if (
                    Int32(group) in self._root_groups
                    and self._group_nodes[group].pending == 0
                ):
                    self._finish_group_success(group, new_groups, new_streams)
            index += 1
        self._start_new_work(new_groups, new_streams)

    def _task_failure(mut self, mut event: _Event):
        """Run graphql-js 17 `taskFailure`."""
        var task = event.id
        self._task_nodes[task].present = False
        var groups = self.engine.inc.tasks[task].groups.copy()
        var index = 0
        while index < len(groups):
            var group = Int(groups[index])
            if self._group_nodes[group].present:
                self._remove_group(group)
                self._remove_root_group(group)
                self._completed(2 * group, event.errors.copy())
            index += 1

    def _stream_items(mut self, mut event: _Event):
        """Run graphql-js 17 `streamItems`, and publish `STREAM_VALUES`."""
        var new_groups = List[Int32]()
        var new_streams = List[Int32]()
        var index = 0
        while index < len(event.works):
            var item_streams = List[Int32]()
            var item_groups = self.integrate(
                event.works[index], -1, item_streams
            )
            var non_empty = List[Int32]()
            self.prune(item_groups, non_empty)
            self._start_new_work(non_empty, item_streams)
            new_groups.extend(non_empty^)
            new_streams.extend(item_streams^)
            index += 1
        var id = self._ensure_id(2 * event.id + 1)
        var errors = List[GraphQLError]()
        swap(errors, event.errors)
        var data = JsonDocument()
        swap(data, event.data)
        self._payload.incremental.append(
            IncrementalResult(
                id, True, data^, event.root, errors^, List[PathSegment]()
            )
        )
        self._to_pending(new_groups, new_streams)
        if event.stopped:
            self._remove_root_stream(event.id)
            self._completed(2 * event.id + 1, List[GraphQLError]())

    def _finish_group_success(
        mut self,
        group: Int,
        mut new_groups: List[Int32],
        mut new_streams: List[Int32],
    ):
        """Run graphql-js 17 `finishGroupSuccess`, and publish
        `GROUP_VALUES` and `GROUP_SUCCESS`."""
        self._group_nodes[group].present = False
        var tasks = self._group_nodes[group].tasks.copy()
        var id = self._ensure_id(2 * group)
        var streams = List[Int32]()
        var index = 0
        # Each task of a group whose pending count is zero succeeded: a
        # failed task removes its groups.
        while index < len(tasks):
            var task = Int(tasks[index])
            self._group_value(id, group, task)
            streams.extend(self._task_nodes[task].child_streams.copy())
            self._remove_task(task)
            index += 1
        var children = self._group_nodes[group].child_groups.copy()
        var groups = List[Int32]()
        self.prune(children, groups)
        self._remove_root_group(group)
        self._completed(2 * group, List[GraphQLError]())
        self._to_pending(groups, streams)
        new_groups.extend(groups^)
        new_streams.extend(streams^)

    def _remove_group(mut self, group: Int):
        """Run graphql-js 17 `removeGroup`."""
        self._group_nodes[group].present = False
        var tasks = self._group_nodes[group].tasks.copy()
        var index = 0
        while index < len(tasks):
            var task = Int(tasks[index])
            var groups = self.engine.inc.tasks[task].groups.copy()
            var orphan = True
            var at = 0
            while at < len(groups):
                if self._group_nodes[Int(groups[at])].present:
                    orphan = False
                at += 1
            if orphan:
                self._remove_task(task)
            index += 1
        # The children of a released group are not pruned yet.
        var children = self._group_nodes[group].child_groups.copy()
        index = 0
        while index < len(children):
            self._remove_child(Int(children[index]))
            index += 1

    def _remove_child(mut self, group: Int):
        """Remove a child group; mutual recursion with `_remove_group`."""
        self._remove_group(group)

    def _remove_task(mut self, task: Int):
        """Run graphql-js 17 `removeTask`."""
        var groups = self.engine.inc.tasks[task].groups.copy()
        var index = 0
        while index < len(groups):
            ref tasks = self._group_nodes[Int(groups[index])].tasks
            var at = 0
            while at < len(tasks):
                if tasks[at] == Int32(task):
                    _ = tasks.pop(at)
                else:
                    at += 1
            index += 1
        self._task_nodes[task] = _TaskNode()

    def _remove_root_group(mut self, group: Int):
        """Delete a group from the root groups."""
        var index = 0
        while index < len(self._root_groups):
            if self._root_groups[index] == Int32(group):
                _ = self._root_groups.pop(index)
            else:
                index += 1

    def _remove_root_stream(mut self, stream: Int):
        """Delete a stream from the root streams."""
        var index = 0
        while index < len(self._root_streams):
            if self._root_streams[index] == Int32(stream):
                _ = self._root_streams.pop(index)
            else:
                index += 1

    # --- the publisher: graphql-js 17 IncrementalPublisher ---------------

    def _ensure_id(mut self, key: Int) -> String:
        """Return graphql-js 17 `_ensureId`: the id of a group (`2 * id`)
        or of a stream (`2 * id + 1`), made on first use."""
        var found = self._ids.get(key)
        if found:
            return found.value()
        var id = String(self._next_id)
        self._next_id += 1
        self._ids[key] = id
        return id

    def _completed(mut self, key: Int, var errors: List[GraphQLError]):
        """Publish a completed group or stream, and forget its id."""
        var id = self._ensure_id(key)
        self._payload.completed.append(CompletedResult(id, errors^))
        _ = self._ids.pop(key, String(""))

    def to_pending(
        mut self, groups: List[Int32], streams: List[Int32]
    ) -> List[PendingResult]:
        """Return graphql-js 17 `_toPendingResults`: give each new group
        and stream its id.

        Args:
            groups: The new groups.
            streams: The new streams.

        Returns:
            The pending results, the groups first.
        """
        var out = List[PendingResult]()
        var index = 0
        while index < len(groups):
            var group = Int(groups[index])
            out.append(
                PendingResult(
                    self._ensure_id(2 * group),
                    self.engine.path_segments(
                        self.engine.inc.groups[group].path
                    ),
                    self.engine.inc.groups[group].label,
                )
            )
            index += 1
        index = 0
        while index < len(streams):
            var stream = Int(streams[index])
            out.append(
                PendingResult(
                    self._ensure_id(2 * stream + 1),
                    self.engine.path_segments(
                        self.engine.inc.streams[stream].path
                    ),
                    self.engine.inc.streams[stream].label,
                )
            )
            index += 1
        return out^

    def _to_pending(mut self, groups: List[Int32], streams: List[Int32]):
        """Publish the pending results of new groups and streams."""
        if len(groups) > 0 or len(streams) > 0:
            self._payload.pending.extend(self.to_pending(groups, streams))

    def _group_value(mut self, id: String, group: Int, task: Int):
        """Publish the value of a task: graphql-js 17 `GROUP_VALUES`, with
        `_getBestIdAndSubPath`."""
        var length = len(self.engine.inc.groups[group].path)
        var best = id
        var groups = self.engine.inc.tasks[task].groups.copy()
        var index = 0
        while index < len(groups):
            var other = Int(groups[index])
            var found = self._ids.get(2 * other)
            if other != group and found:
                var other_length = len(self.engine.inc.groups[other].path)
                if other_length > length:
                    length = other_length
                    best = found.value()
            index += 1
        ref node = self._task_nodes[task]
        var sub_path = List[PathSegment]()
        index = length
        while index < len(node.path):
            sub_path.append(node.path[index].copy())
            index += 1
        var data = JsonDocument()
        swap(data, node.data)
        var errors = List[GraphQLError]()
        swap(errors, node.errors)
        self._payload.incremental.append(
            IncrementalResult(best, False, data^, node.root, errors^, sub_path^)
        )

    # --- polling ---------------------------------------------------------

    def start(mut self, work: _Work) -> List[PendingResult]:
        """Integrate the work of the initial run: the initial groups and
        streams of graphql-js 17 `createWorkQueue`.

        Args:
            work: The records of the initial run.

        Returns:
            The `pending` of the initial result.
        """
        var streams = List[Int32]()
        var groups = self.integrate(work, -1, streams)
        var non_empty = List[Int32]()
        self.prune(groups, non_empty)
        self._root_groups = non_empty.copy()
        self._root_streams = streams.copy()
        return self.to_pending(non_empty, streams)

    def _start_root_groups(mut self):
        """Execute the groups of the initial result, one time: at the first
        tick, or at once for graphql-js `enableEarlyExecution`."""
        if self._groups_started:
            return
        self._groups_started = True
        var groups = self._root_groups.copy()
        var index = 0
        while index < len(groups):
            self._start_group(Int(groups[index]))
            index += 1

    def _tick(mut self, waker: Waker) -> Bool:
        """Run one tick; return True when it had an event."""
        if not self._started:
            self._started = True
            self._start_root_groups()
            self._scheduled = self._root_streams.copy()
        else:
            var current = self._scheduled^
            self._scheduled = List[Int32]()
            var index = 0
            while index < len(current):
                _ = self._stream_batch(Int(current[index]), waker)
                index += 1
        if not self._events:
            return False
        var at = 0
        while at < len(self._events):
            var event = _Event(-1, -1)
            swap(event, self._events[at])
            self._handle(event)
            at += 1
        self._events.clear()
        # A released group completes in the tick that releases it, because
        # its execution groups run at once; so only streams can remain.
        if len(self._root_streams) == 0:
            self._payload.has_next = False
            self._finished = True
        return True

    def poll_payload(
        mut self, mut waker: Waker
    ) raises -> Optional[SubsequentIncrementalExecutionResult]:
        """Run ticks until one gives a payload, or none can progress.

        Args:
            waker: The waker of the owner; an event stream that is not
                ready keeps it.

        Returns:
            The next payload, or None when the stream is `PENDING` or
            done: `is_done()` tells which.

        Raises:
            Error: The reason of an abort, one time: graphql-js `next()`
                rejects with it. Each later poll returns None.
        """
        self._check_signal()
        if self._abort_reason:
            raise Error(self._abort_reason.take())
        # Each graph event of a tick publishes an entry, so a tick with an
        # event gives a payload. The first tick has no event when the
        # initial work has only streams: their items come in the next tick.
        while not self._finished:
            var first = not self._started
            if self._tick(waker):
                var payload = self._payload^
                self._payload = SubsequentIncrementalExecutionResult()
                return payload^
            if not first:
                return None
        return None

    def is_done(self) -> Bool:
        """Return True after the last payload, or after `close`.

        Returns:
            Whether no payload follows.
        """
        return self._finished

    def poll_next(mut self, mut waker: Waker) -> Poll:
        """Poll the next payload, as its JSON event.

        Args:
            waker: The waker of the owner.

        Returns:
            `READY` with the JSON of the payload, `PENDING`, `DONE`, or
            `ERROR` with the reason of an abort, one time.
        """
        var payload: Optional[SubsequentIncrementalExecutionResult]
        try:
            payload = self.poll_payload(waker)
        except e:
            return Poll.error(String(e))
        if payload:
            return Poll.ready(Event(subsequent_document(payload.value())))
        if self._finished:
            return Poll.done()
        return Poll.pending()

    def close(mut self):
        """End the stream: graphql-js `return()`. Each event stream of a
        `@stream` that has not ended is closed, one time."""
        var index = 0
        while index < len(self.engine.inc.streams):
            _close_source(self.engine, index)
            index += 1
        self._finished = True

    def abort(mut self, reason: String = ABORT_REASON):
        """Abort the execution: what graphql-js v17.0.2 does when the
        `abortSignal` aborts. The stream closes, as `close()`, and the next
        poll raises the reason. After the last payload, or after an earlier
        `close()` or `abort()`, nothing changes.

        Args:
            reason: The message of the abort.
        """
        if self._finished:
            return
        self.close()
        self._abort_reason = reason

    def _check_signal(mut self):
        """Abort when the abort signal of the execution has aborted."""
        if self._signal and self._signal.value().aborted():
            self.abort(self._signal.value().reason())


struct ExperimentalIncrementalExecutionResults(Movable):
    """What `experimental_execute_incrementally` returns: graphql-js 17
    `ExecutionResult | ExperimentalIncrementalExecutionResults`."""

    var result: Optional[ExecutionResult]
    """The single result, when there is nothing to deliver later."""
    var initial_result: Optional[InitialIncrementalExecutionResult]
    """The initial result, with `pending` and `hasNext`."""
    var subsequent_results: Optional[SubsequentResultStream]
    """The stream of the subsequent results."""

    def __init__(out self, var result: ExecutionResult):
        """Make a single result.

        Args:
            result: The result.
        """
        self.result = result^
        self.initial_result = None
        self.subsequent_results = None

    def __init__(
        out self,
        var initial_result: InitialIncrementalExecutionResult,
        var subsequent_results: SubsequentResultStream,
    ):
        """Make an incremental result.

        Args:
            initial_result: The initial result.
            subsequent_results: The stream of the subsequent results.
        """
        self.result = None
        self.initial_result = initial_result^
        self.subsequent_results = subsequent_results^

    def is_incremental(self) -> Bool:
        """Return True when payloads follow the initial result.

        Returns:
            Whether `initial_result` and `subsequent_results` are set.
        """
        return Bool(self.initial_result)

    def take_subsequent_results(mut self) raises -> SubsequentResultStream:
        """Take the stream of the subsequent results out.

        Returns:
            The stream.

        Raises:
            Error: For a single result.
        """
        if not self.subsequent_results:
            raise Error("The execution has a single result: ", self.to_json())
        return self.subsequent_results.take()

    def to_json(self) -> String:
        """Return the JSON of the single result or of the initial result.

        Returns:
            The text of graphql-js `JSON.stringify`.
        """
        if self.result:
            return self.result.value().to_json()
        return self.initial_result.value().to_json()


def experimental_execute_incrementally(
    schema: ArcPointer[Schema],
    document: ArcPointer[Document],
    var args: ExecutionArgs,
) raises -> ExperimentalIncrementalExecutionResults:
    """Execute an operation with `@defer` and `@stream`: graphql-js 17
    `experimentalExecuteIncrementally`.

    Args:
        schema: The schema, shared with the subsequent results.
        document: The document; execution does not validate it.
        args: The inputs; the subsequent results keep them, with their
            arena and their resolvers.

    Returns:
        A single result, or the initial result and the stream of the
        subsequent results.

    Raises:
        Error: As `execute` raises.
    """
    var resolvers = ArcPointer(Resolvers())
    swap(resolvers[], args.resolvers)
    return experimental_execute_incrementally(
        schema, document, resolvers, args^
    )


def experimental_execute_incrementally(
    schema: ArcPointer[Schema],
    document: ArcPointer[Document],
    resolvers: ArcPointer[Resolvers],
    var args: ExecutionArgs,
) raises -> ExperimentalIncrementalExecutionResults:
    """Execute incrementally with shared resolvers, so that a server does
    not copy its resolvers for each operation.

    Args:
        schema: The schema, shared with the subsequent results.
        document: The document; execution does not validate it.
        resolvers: The resolvers, shared with the subsequent results.
            `args.resolvers` is not used.
        args: The inputs; the subsequent results keep them, with their
            arena.

    Returns:
        As the other `experimental_execute_incrementally` returns.

    Raises:
        Error: As `execute` raises.
    """
    assert_valid_execution_arguments(schema[], args)
    var values = Values(capacity=0)
    swap(values, args.values)
    var schema_ref = _pin(schema[])
    var document_ref = _pin(document[])
    var resolvers_ref = _pin(resolvers[])
    var engine = _Engine(schema_ref[], document_ref[], resolvers_ref[], values^)
    engine.custom_default = resolvers[].has_default_field
    engine.collector.defer_enabled = True
    engine.inc.enabled = True
    engine.inc.waker = Waker.noop()
    var early = engine.prepare(
        args.operation_name, args.variable_values, args.max_coercion_errors
    )
    if early:
        return ExperimentalIncrementalExecutionResults(early.take())
    # graphql-js `throwIfAborted` at the start of the root selection set.
    if args.abort_signal and args.abort_signal.value().aborted():
        raise Error(args.abort_signal.value().reason())
    engine.inc.subscription = (
        document[].operation(engine.operation) == OperationType.SUBSCRIPTION
    )
    engine.root_value = args.root_value
    engine.context_value = args.context_value
    engine.data.root = engine.run_initial()
    var work = _incremental_work(engine)
    var data = JsonDocument()
    swap(data, engine.data)
    var errors = List[GraphQLError]()
    swap(errors, engine.errors)
    if not work.tasks and not work.streams:
        return ExperimentalIncrementalExecutionResults(
            ExecutionResult(data^, errors^)
        )
    var stream = SubsequentResultStream(schema, document, resolvers, engine^)
    stream._signal = args.abort_signal.copy()
    var pending = stream.start(work)
    # graphql-js `enableEarlyExecution`: the released groups execute
    # before the initial result returns, and not at the first poll.
    if args.enable_early_execution:
        stream._start_root_groups()
    return ExperimentalIncrementalExecutionResults(
        InitialIncrementalExecutionResult(data^, errors^, pending^), stream^
    )


def experimental_execute_incrementally(
    schema: Schema, document: Document, var args: ExecutionArgs
) raises -> ExperimentalIncrementalExecutionResults:
    """Execute incrementally, with copies of the schema and the document
    for the subsequent results.

    Args:
        schema: The schema.
        document: The document.
        args: The inputs.

    Returns:
        As the other `experimental_execute_incrementally` returns.

    Raises:
        Error: As the other `experimental_execute_incrementally` raises.
    """
    return experimental_execute_incrementally(
        ArcPointer(schema.copy()), ArcPointer(document.copy()), args^
    )

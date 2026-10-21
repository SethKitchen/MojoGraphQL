# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The work of incremental delivery: delivery groups, execution groups
and item streams, and the execution plan of a selection set.

Port of graphql-js v17.0.2
`execution/incremental/buildExecutionPlan.ts` and of the records of
`execution/incremental/IncrementalExecutor.ts`: `DeliveryGroup`,
`ExecutionGroup` (a task of the work queue) and `ItemStream`.

graphql-js keeps the records as objects, and compares them by identity.
Here the executor keeps each kind in a list, and a record is its index.
A path is the executor's path: a field group's index, or `-index - 1` for
a list index. A position is unique in one execution, so a path compares by
value as upstream compares a `Path` by identity.

**Differences from upstream.** None in behavior.
"""

from gql_schema.definition import NO_TYPE, TypeRef
from gql_execution.collect_fields import NO_DEFER, FieldCollector
from gql_execution.value import UNDEFINED
from gql_stream.stream import AnyStream
from gql_stream.waker import Waker


@fieldwise_init
struct DeliveryGroup(Copyable, Movable):
    """A deferred fragment at one path: graphql-js 17 `DeliveryGroup`."""

    var path: List[Int32]
    """The path of the object that has the fragment."""
    var label: Optional[String]
    """The `label` of the `@defer`."""
    var parent: Int
    """The delivery group that holds this one, or -1."""


struct ExecutionGroup(Copyable, Movable):
    """The deferred fields of one set of defer usages at one path:
    graphql-js 17 `ExecutionGroup`, a task of the work queue."""

    var groups: List[Int32]
    """The delivery groups that need the fields."""
    var path: List[Int32]
    """The path of the object."""
    var parent_type: Int
    """The object type."""
    var source_tag: Int32
    """The tag of the source: 0 for a value of the arena."""
    var source_id: Int
    """The source value, or the introspection element."""
    var source_first: Int32
    """The first extra number of an introspection source."""
    var source_second: Int32
    """The second extra number of an introspection source."""
    var fields: List[Int32]
    """The field groups to execute, in response order."""
    var defer_set: List[Int32]
    """The defer usages of the fields: the `deferUsageSet` of the
    executor that runs them."""
    var delivery_map: Int
    """The delivery group map of the fields, in `IncrementalState.maps`."""

    def __init__(out self):
        """Make an empty execution group."""
        self.groups = List[Int32]()
        self.path = List[Int32]()
        self.parent_type = NO_TYPE
        self.source_tag = 0
        self.source_id = UNDEFINED
        self.source_first = 0
        self.source_second = 0
        self.fields = List[Int32]()
        self.defer_set = List[Int32]()
        self.delivery_map = -1


struct ItemStream(Movable):
    """The items of a list after `initialCount`: graphql-js 17
    `ItemStream`. The items come from an arena list, or from an event
    stream."""

    var path: List[Int32]
    """The path of the list field."""
    var label: Optional[String]
    """The `label` of the `@stream`."""
    var group: Int
    """The field group of the list field."""
    var parent_type: Int
    """The object type of the field."""
    var field: Int
    """The field."""
    var item_type: TypeRef
    """The type of an item."""
    var next_item: Int
    """The next arena item of a list, or `UNDEFINED` at the end."""
    var source: Optional[AnyStream]
    """The event stream of the items, when the field returned one."""
    var index: Int
    """The index of the next item."""
    var stopped: Bool
    """True when there is no more item."""

    def __init__(out self):
        """Make an empty item stream."""
        self.path = List[Int32]()
        self.label = None
        self.group = 0
        self.parent_type = NO_TYPE
        self.field = NO_TYPE
        self.item_type = TypeRef.of(NO_TYPE)
        self.next_item = UNDEFINED
        self.source = None
        self.index = 0
        self.stopped = False


struct ExecutionPlan(Movable):
    """The graphql-js 17 `ExecutionPlan`: the fields to execute now, and the
    fields of each new set of defer usages."""

    var fields: List[Int32]
    """The field groups of the current defer usages."""
    var sets: List[List[Int32]]
    """Each new set of defer usages, in order of first use."""
    var set_fields: List[List[Int32]]
    """The field groups of each set of `sets`."""

    def __init__(out self):
        """Make an empty plan."""
        self.fields = List[Int32]()
        self.sets = List[List[Int32]]()
        self.set_fields = List[List[Int32]]()


def same_set(a: List[Int32], b: List[Int32]) -> Bool:
    """Return graphql-js `isSameSet` for two sets without repeats.

    Args:
        a: A set.
        b: Another set.

    Returns:
        Whether they have the same elements.
    """
    if len(a) != len(b):
        return False
    var index = 0
    while index < len(a):
        if a[index] not in b:
            return False
        index += 1
    return True


def filtered_defer_set(collector: FieldCollector, group: Int) -> List[Int32]:
    """Return graphql-js 17 `getFilteredDeferUsageSet` for a field group:
    the defer usages of its nodes, without a usage under another one, or
    an empty set when one node is not deferred.

    Args:
        collector: The collector; `defer_enabled` is set.
        group: The field group.

    Returns:
        The set, in order of first use.
    """
    var found = collector.group(group)
    var out = List[Int32]()
    var index = Int(found.start)
    while index < Int(found.start + found.count):
        var usage = Int32(collector.node_defer(index))
        if usage == NO_DEFER:
            return List[Int32]()
        if usage not in out:
            out.append(usage)
        index += 1
    var kept = List[Int32]()
    index = 0
    while index < len(out):
        var parent = collector.defer_usages[Int(out[index])].parent
        var under = False
        while parent != NO_DEFER and not under:
            under = parent in out
            parent = collector.defer_usages[Int(parent)].parent
        if not under:
            kept.append(out[index])
        index += 1
    return kept^


def build_execution_plan(
    collector: FieldCollector, plan: Int, parent_set: List[Int32]
) -> ExecutionPlan:
    """Return graphql-js 17 `buildExecutionPlan` for a collected plan.

    Args:
        collector: The collector; `defer_enabled` is set.
        plan: The collected plan.
        parent_set: The defer usages of the executor: empty for the
            initial execution.

    Returns:
        The fields of `parent_set`, and the fields of each other set.
    """
    var out = ExecutionPlan()
    var found = collector.plan(plan)
    var group = Int(found.start)
    while group < Int(found.start + found.count):
        var usages = filtered_defer_set(collector, group)
        if same_set(usages, parent_set):
            out.fields.append(Int32(group))
        else:
            var at = -1
            var index = 0
            while index < len(out.sets):
                if same_set(out.sets[index], usages):
                    at = index
                index += 1
            if at < 0:
                out.sets.append(usages^)
                out.set_fields.append(List[Int32]())
                at = len(out.sets) - 1
            out.set_fields[at].append(Int32(group))
        group += 1
    return out^


def is_prefix(prefix: List[Int32], path: List[Int32]) -> Bool:
    """Return True when a path starts with another path.

    Args:
        prefix: The shorter path.
        path: The path.

    Returns:
        Whether each entry of `prefix` is the entry of `path` there.
    """
    if len(prefix) > len(path):
        return False
    var index = 0
    while index < len(prefix):
        if prefix[index] != path[index]:
            return False
        index += 1
    return True


struct IncrementalState(Movable):
    """What an executor keeps for incremental delivery: the records, the
    delivery group maps, and the work of the current run."""

    var enabled: Bool
    """True for `experimental_execute_incrementally`."""
    var subscription: Bool
    """True when the operation is a subscription."""
    var groups: List[DeliveryGroup]
    """Every delivery group, by index."""
    var tasks: List[ExecutionGroup]
    """Every execution group, by index."""
    var streams: List[ItemStream]
    """Every item stream, by index."""
    var maps: List[List[Int32]]
    """Each delivery group map: pairs of a defer usage and its group."""
    var current_map: Int
    """The map of the fields that execute now, or -1."""
    var defer_set: List[Int32]
    """The defer usages of the current run; empty for the initial run."""
    var work_groups: List[Int32]
    """The delivery groups that the current run made."""
    var work_tasks: List[Int32]
    """The execution groups that the current run made."""
    var work_streams: List[Int32]
    """The item streams that the current run made."""
    var plans: List[ExecutionPlan]
    """Each execution plan that a run built."""
    var initial_plans: Dict[Int, Int]
    """The plan of the initial defer usages for each collected plan."""
    var nulled: List[List[Int32]]
    """The paths that the current run made `null` for an error; an empty
    path is the root."""
    var waker: Optional[Waker]
    """The waker to poll an event stream with; the driver sets it."""

    def __init__(out self):
        """Start with incremental delivery off."""
        self.enabled = False
        self.subscription = False
        self.groups = List[DeliveryGroup]()
        self.tasks = List[ExecutionGroup]()
        self.streams = List[ItemStream]()
        self.maps = List[List[Int32]]()
        self.current_map = -1
        self.defer_set = List[Int32]()
        self.work_groups = List[Int32]()
        self.work_tasks = List[Int32]()
        self.work_streams = List[Int32]()
        self.plans = List[ExecutionPlan]()
        self.initial_plans = Dict[Int, Int]()
        self.nulled = List[List[Int32]]()
        self.waker = None

    def begin_run(mut self, map: Int, var defer_set: List[Int32]):
        """Start a run: graphql-js 17 `createSubExecutor`.

        Args:
            map: The delivery group map of the run, or -1.
            defer_set: The defer usages of the run.
        """
        self.current_map = map
        self.defer_set = defer_set^
        self.work_groups.clear()
        self.work_tasks.clear()
        self.work_streams.clear()
        self.nulled.clear()

    def has_nulled_position(self, path: List[Int32]) -> Bool:
        """Return graphql-js `CollectedErrors.hasNulledPosition`.

        Args:
            path: A path.

        Returns:
            Whether the run made the path, or a path above it, `null`.
        """
        var index = 0
        while index < len(self.nulled):
            if is_prefix(self.nulled[index], path):
                return True
            index += 1
        return False

    def group_of(self, map: Int, usage: Int32) -> Int:
        """Return graphql-js 17 `deliveryGroupFromDeferUsage`.

        Args:
            map: A delivery group map.
            usage: A defer usage.

        Returns:
            The delivery group of the usage in the map. The map has each
            usage that the plan names, as graphql-js asserts with `!`.
        """
        ref pairs = self.maps[map]
        var index = 0
        while pairs[index] != usage:
            index += 2
        return Int(pairs[index + 1])

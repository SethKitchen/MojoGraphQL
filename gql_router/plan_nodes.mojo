# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The nodes of a query plan.

Port of Hive Router `1a29df9`
`bin/router/src/query_planner/planner/plan_nodes/`: `mod.rs`, `path.rs`,
`prepare.rs` and `state.rs`, and `utils/pretty_display.rs`.

The plan keeps its nodes in one arena, `QueryPlan.nodes`. A node refers to
its children by index. A fetch node keeps its data in `QueryPlan.fetches`
and a batch fetch node in `QueryPlan.batches`.

**Differences from upstream.**

- Upstream marks a plan as `Planning` or `Executable` with a type
  parameter. This port has one plan type with an `executable` flag;
  `into_executable` sets it, and the plan then prints each operation on
  one line, as upstream `SubgraphFetchOperation`.
- A `requires` selection is a selection set in the store, not a
  `RequiresSelectionSet`. Upstream prints both the same way.
- `custom_scalar_paths` is not kept: only the JSON form and the executor
  read it.
- A `Defer` node has no fields: the planner does not make one, and
  upstream prints nothing for it.
"""

from gql_router.ast import NONE, Cond, ItemKind, ValueKind
from gql_router.federation_spec import OperationKind, TypeNode
from gql_router.fetch_operation import PlanningFetchOperation
from gql_router.fetch_step import (
    FetchRewrite,
    FetchStepData,
)
from gql_router.merge_path import MergePath, SegmentKind
from gql_router.minification import minify_operation
from gql_router.operation import OperationDefinition, VariableDefinition
from gql_router.selection_set import (
    pretty_set,
    strip_for_plan_input,
    write_indent,
)
from gql_router.store import Store
from gql_router.supergraph_state import SupergraphState


# --- paths ---------------------------------------------------------------


@fieldwise_init
struct PathSegmentKind(Equatable, ImplicitlyCopyable, Movable):
    """The kind of a flatten path step, as upstream `PathSegment`."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime FIELD = PathSegmentKind(0)
    """A field, by response key."""
    comptime TYPE_CONDITION = PathSegmentKind(1)
    """A type condition, written `|[A|B]`."""
    comptime LIST = PathSegmentKind(2)
    """A step into a list, written `@`."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the three kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 2


@fieldwise_init
struct PathSegment(Equatable, ImplicitlyCopyable, Movable):
    """One step of a flatten path, as upstream `PathSegment`."""

    var kind: PathSegmentKind
    """What the step is."""
    var name: Int
    """The response key of a field, as a symbol."""
    var types: Int
    """The interned type set of a type condition: sorted, once each."""

    def write(self, store: Store, mut out: String):
        """Write the step as upstream `Display`.

        Args:
            store: The store with the names.
            out: The destination.
        """
        if self.kind == PathSegmentKind.FIELD:
            out += store.name(self.name)
        elif self.kind == PathSegmentKind.LIST:
            out += "@"
        else:
            out += "|["
            ref names = store.type_sets[self.types]
            out += store.name(names[0])
            var index = 1
            while index < len(names):
                out += "|"
                out += store.name(names[index])
                index += 1
            out += "]"


struct FlattenNodePath(Copyable, Equatable, Movable, Sized):
    """The response path of a flatten node, as upstream
    `FlattenNodePath`."""

    var segments: List[PathSegment]
    """The steps."""

    def __init__(out self):
        """Start an empty path."""
        self.segments = List[PathSegment]()

    def __init__(out self, var segments: List[PathSegment]):
        """Make a path of steps.

        Args:
            segments: The steps.
        """
        self.segments = segments^

    @staticmethod
    def from_merge_path(path: MergePath) -> FlattenNodePath:
        """Convert a merge path, as upstream `From<&MergePath>`.

        Args:
            path: The merge path.

        Returns:
            The path: response keys, type sets and list steps.
        """
        var out = List[PathSegment]()
        var index = 0
        while index < len(path.segments):
            ref segment = path.segments[index]
            index += 1
            if segment.kind == SegmentKind.TYPE_CONDITION:
                out.append(
                    PathSegment(
                        PathSegmentKind.TYPE_CONDITION, NONE, segment.types
                    )
                )
            elif segment.kind == SegmentKind.FIELD:
                out.append(
                    PathSegment(
                        PathSegmentKind.FIELD, segment.response_key(), NONE
                    )
                )
            else:
                out.append(PathSegment(PathSegmentKind.LIST, NONE, NONE))
        return FlattenNodePath(out^)

    def __eq__(self, other: Self) -> Bool:
        """Return True if two paths have the same steps.

        Args:
            other: Another path.

        Returns:
            Whether the steps are equal.
        """
        if len(self.segments) != len(other.segments):
            return False
        var index = 0
        while index < len(self.segments):
            if self.segments[index] != other.segments[index]:
                return False
            index += 1
        return True

    def __len__(self) -> Int:
        """Return the number of steps.

        Returns:
            The length.
        """
        return len(self.segments)

    def is_empty(self) -> Bool:
        """Return True for a path with no step.

        Returns:
            Whether the path is empty.
        """
        return len(self.segments) == 0

    def text(self, store: Store) -> String:
        """Return the path as upstream `Display`: steps joined by `.`, and
        no `.` before a type condition.

        Args:
            store: The store with the names.

        Returns:
            Such as `products.@|[Book]`.
        """
        var out = String()
        var index = 0
        while index < len(self.segments):
            self.segments[index].write(store, out)
            if (
                index + 1 < len(self.segments)
                and self.segments[index + 1].kind
                != PathSegmentKind.TYPE_CONDITION
            ):
                out += "."
            index += 1
        return out^


# --- nodes ---------------------------------------------------------------


@fieldwise_init
struct PlanNodeKind(Equatable, ImplicitlyCopyable, Movable):
    """The kind of a plan node, as upstream `PlanNode`."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime FETCH = PlanNodeKind(0)
    """A fetch."""
    comptime BATCH_FETCH = PlanNodeKind(1)
    """A batch of entity fetches to one subgraph."""
    comptime SEQUENCE = PlanNodeKind(2)
    """Nodes that run one after another."""
    comptime PARALLEL = PlanNodeKind(3)
    """Nodes that run at the same time."""
    comptime FLATTEN = PlanNodeKind(4)
    """A fetch that writes at a response path."""
    comptime CONDITION = PlanNodeKind(5)
    """A node that runs when a variable is true or false."""
    comptime SUBSCRIPTION = PlanNodeKind(6)
    """A subscription fetch."""
    comptime DEFER = PlanNodeKind(7)
    """A deferred node."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the eight kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 7

    def name(self) -> StaticString:
        """Return the upstream variant name.

        Returns:
            Such as `Fetch` or `Parallel`.
        """
        if self == PlanNodeKind.FETCH:
            return "Fetch"
        if self == PlanNodeKind.BATCH_FETCH:
            return "BatchFetch"
        if self == PlanNodeKind.SEQUENCE:
            return "Sequence"
        if self == PlanNodeKind.PARALLEL:
            return "Parallel"
        if self == PlanNodeKind.FLATTEN:
            return "Flatten"
        if self == PlanNodeKind.CONDITION:
            return "Condition"
        if self == PlanNodeKind.SUBSCRIPTION:
            return "Subscription"
        return "Defer"


struct FetchNode(Copyable, Movable):
    """One fetch, as upstream `FetchNode`."""

    var id: Int
    """The fetch step id."""
    var service_name: Int
    """The subgraph name, as a symbol, or `NONE` for `*`."""
    var variable_usages: List[Int]
    """The variables the fetch uses, sorted by name."""
    var has_variable_usages: Bool
    """False when upstream `variable_usages` is `None`."""
    var operation_kind: OperationKind
    """The operation kind."""
    var operation: PlanningFetchOperation
    """The operation sent to the subgraph."""
    var requires: Int
    """The representations selection, or `NONE` for a root call."""
    var planner_requires: Int
    """The same selection, as upstream `planner_requires`, or `NONE`."""
    var input_rewrites: List[FetchRewrite]
    """The input rewrites."""
    var has_input_rewrites: Bool
    """False when upstream `input_rewrites` is `None`."""
    var output_rewrites: List[FetchRewrite]
    """The output rewrites."""
    var has_output_rewrites: Bool
    """False when upstream `output_rewrites` is `None`."""

    def __init__(
        out self,
        id: Int,
        service_name: Int,
        operation_kind: OperationKind,
        var operation: PlanningFetchOperation,
        requires: Int,
    ):
        """Make a fetch with no variables and no rewrites.

        Args:
            id: The fetch step id.
            service_name: The subgraph name, or `NONE`.
            operation_kind: The operation kind.
            operation: The operation.
            requires: The representations selection, or `NONE`.
        """
        self.id = id
        self.service_name = service_name
        self.variable_usages = List[Int]()
        self.has_variable_usages = False
        self.operation_kind = operation_kind
        self.operation = operation^
        self.requires = requires
        self.planner_requires = requires
        self.input_rewrites = List[FetchRewrite]()
        self.has_input_rewrites = False
        self.output_rewrites = List[FetchRewrite]()
        self.has_output_rewrites = False


@fieldwise_init
struct EntityBatchAlias(Copyable, Movable):
    """One `_entities` alias of a batch, as upstream `EntityBatchAlias`."""

    var alias: Int
    """The alias, such as `_e0`, as a symbol."""
    var representations_variable_name: Int
    """The representations variable, as a symbol."""
    var merge_paths: List[FlattenNodePath]
    """The response paths the alias fills."""
    var requires: Int
    """The representations selection."""
    var input_rewrites: List[FetchRewrite]
    """The input rewrites."""
    var has_input_rewrites: Bool
    """False when upstream `input_rewrites` is `None`."""
    var output_rewrites: List[FetchRewrite]
    """The output rewrites."""
    var has_output_rewrites: Bool
    """False when upstream `output_rewrites` is `None`."""


@fieldwise_init
struct BatchFetchNode(Copyable, Movable):
    """Entity fetches to one subgraph in one request, as upstream
    `BatchFetchNode`."""

    var id: Int
    """The id of the first fetch of the batch."""
    var service_name: Int
    """The subgraph name, as a symbol."""
    var variable_usages: List[Int]
    """The variables the fetches use, sorted by name."""
    var has_variable_usages: Bool
    """False when upstream `variable_usages` is `None`."""
    var operation_kind: OperationKind
    """The operation kind: always a query."""
    var operation: PlanningFetchOperation
    """The batched operation."""
    var aliases: List[EntityBatchAlias]
    """Upstream `entity_batch.aliases`."""


@fieldwise_init
struct PlanNode(Copyable, Movable):
    """One plan node, as upstream `PlanNode`."""

    var kind: PlanNodeKind
    """What the node is."""
    var nodes: List[Int]
    """The children of a sequence or a parallel node."""
    var node: Int
    """The child of a flatten node, or `NONE`."""
    var fetch: Int
    """The index in `fetches` of a fetch or a subscription primary, or in
    `batches` of a batch fetch; `NONE` otherwise."""
    var path: FlattenNodePath
    """The path of a flatten node."""
    var condition: Int
    """The variable of a condition node, as a symbol."""
    var if_clause: Int
    """The node a condition runs when the variable is true, or `NONE`."""
    var else_clause: Int
    """The node a condition runs when the variable is false, or `NONE`."""

    @staticmethod
    def of(kind: PlanNodeKind) -> PlanNode:
        """Return an empty node of a kind.

        Args:
            kind: The kind.

        Returns:
            The node, with no child.
        """
        return PlanNode(
            kind,
            List[Int](),
            NONE,
            NONE,
            FlattenNodePath(),
            NONE,
            NONE,
            NONE,
        )


comptime QUERY_PLAN_KIND = "QueryPlan"
"""The `kind` of every plan, as upstream `QUERY_PLAN_KIND`."""


struct QueryPlan(Movable):
    """A query plan, as upstream `QueryPlan`, and the arena of its
    nodes."""

    var kind: String
    """Always `QueryPlan`."""
    var node: Int
    """The root node, or `NONE`."""
    var nodes: List[PlanNode]
    """Every node, by index."""
    var fetches: List[FetchNode]
    """The data of every fetch node."""
    var batches: List[BatchFetchNode]
    """The data of every batch fetch node."""
    var executable: Bool
    """True after `into_executable`."""

    def __init__(out self):
        """Start a plan with no node."""
        self.kind = String(QUERY_PLAN_KIND)
        self.node = NONE
        self.nodes = List[PlanNode]()
        self.fetches = List[FetchNode]()
        self.batches = List[BatchFetchNode]()
        self.executable = False

    # --- making nodes ---------------------------------------------------

    def add(mut self, var node: PlanNode) -> Int:
        """Add a node to the arena.

        Args:
            node: The node.

        Returns:
            Its index.
        """
        self.nodes.append(node^)
        return len(self.nodes) - 1

    def add_fetch(mut self, var fetch: FetchNode) -> Int:
        """Add a fetch node.

        Args:
            fetch: The fetch.

        Returns:
            The index of the new `Fetch` node.
        """
        self.fetches.append(fetch^)
        var node = PlanNode.of(PlanNodeKind.FETCH)
        node.fetch = len(self.fetches) - 1
        return self.add(node^)

    def add_batch_fetch(mut self, var batch: BatchFetchNode) -> Int:
        """Add a batch fetch node.

        Args:
            batch: The batch.

        Returns:
            The index of the new `BatchFetch` node.
        """
        self.batches.append(batch^)
        var node = PlanNode.of(PlanNodeKind.BATCH_FETCH)
        node.fetch = len(self.batches) - 1
        return self.add(node^)

    def add_flatten(mut self, var path: FlattenNodePath, child: Int) -> Int:
        """Add a flatten node.

        Args:
            path: The response path.
            child: The node it wraps.

        Returns:
            The index of the new node.
        """
        var node = PlanNode.of(PlanNodeKind.FLATTEN)
        node.path = path^
        node.node = child
        return self.add(node^)

    def add_condition(
        mut self, condition: Int, if_clause: Int, else_clause: Int
    ) -> Int:
        """Add a condition node.

        Args:
            condition: The variable, as a symbol.
            if_clause: The node for true, or `NONE`.
            else_clause: The node for false, or `NONE`.

        Returns:
            The index of the new node.
        """
        var node = PlanNode.of(PlanNodeKind.CONDITION)
        node.condition = condition
        node.if_clause = if_clause
        node.else_clause = else_clause
        return self.add(node^)

    def add_list(mut self, kind: PlanNodeKind, var nodes: List[Int]) -> Int:
        """Add a sequence or a parallel node.

        Args:
            kind: `SEQUENCE` or `PARALLEL`.
            nodes: The children.

        Returns:
            The index of the new node.
        """
        var node = PlanNode.of(kind)
        node.nodes = nodes^
        return self.add(node^)

    def sequence(mut self, var nodes: List[Int]) -> Int:
        """Return the only node, or a new sequence, as upstream
        `PlanNode::sequence`.

        Args:
            nodes: The nodes.

        Returns:
            The node.
        """
        if len(nodes) == 1:
            return nodes[0]
        return self.add_list(PlanNodeKind.SEQUENCE, nodes^)

    def parallel(mut self, var nodes: List[Int]) -> Int:
        """Return the only node, or a new parallel node, as upstream
        `PlanNode::parallel`.

        Args:
            nodes: The nodes.

        Returns:
            The node.
        """
        if len(nodes) == 1:
            return nodes[0]
        return self.add_list(PlanNodeKind.PARALLEL, nodes^)

    # --- reading nodes --------------------------------------------------

    def into_nodes(self, node: Int) -> List[Int]:
        """Return the children of a sequence or a parallel node, or the
        node itself, as upstream `into_nodes`.

        Args:
            node: The node.

        Returns:
            The nodes.
        """
        var kind = self.nodes[node].kind
        if kind == PlanNodeKind.SEQUENCE or kind == PlanNodeKind.PARALLEL:
            return self.nodes[node].nodes.copy()
        return [node]

    def flatten_sequence(self, node: Int) -> List[Int]:
        """Return the children of a sequence, or the node itself, as
        upstream `flatten_sequence`.

        Args:
            node: The node.

        Returns:
            The nodes.
        """
        if self.nodes[node].kind == PlanNodeKind.SEQUENCE:
            return self.nodes[node].nodes.copy()
        return [node]

    def flatten_parallel(self, nodes: List[Int]) -> List[Int]:
        """Splice the children of parallel nodes, as upstream
        `flatten_parallel`.

        Args:
            nodes: The nodes.

        Returns:
            The nodes, with each parallel node replaced by its children.
        """
        var out = List[Int]()
        var index = 0
        while index < len(nodes):
            var node = nodes[index]
            index += 1
            if self.nodes[node].kind == PlanNodeKind.PARALLEL:
                out.extend(self.nodes[node].nodes.copy())
            else:
                out.append(node)
        return out^

    def is_fetching_node(self, node: Int) -> Bool:
        """Return True for a fetch, a batch fetch, or a flatten of a fetch,
        as upstream `is_fetching_node`.

        Args:
            node: The node.

        Returns:
            Whether the node fetches.
        """
        var kind = self.nodes[node].kind
        if kind == PlanNodeKind.FETCH or kind == PlanNodeKind.BATCH_FETCH:
            return True
        if kind == PlanNodeKind.FLATTEN:
            return self.nodes[self.nodes[node].node].kind == PlanNodeKind.FETCH
        return False

    # --- conditions -----------------------------------------------------

    def can_merge_with(self, node: Int, other: Int) -> Bool:
        """Return True if two condition nodes can merge, as upstream
        `ConditionNode::can_merge_with`.

        Args:
            node: A condition node.
            other: Another condition node.

        Returns:
            Whether both test one variable and both have only an `if` or
            only an `else` clause.
        """
        ref a = self.nodes[node]
        ref b = self.nodes[other]
        if a.condition != b.condition:
            return False
        var both_if = a.else_clause == NONE and b.else_clause == NONE
        var both_else = a.if_clause == NONE and b.if_clause == NONE
        return both_if or both_else

    def _take_inner_nodes(mut self, node: Int) -> List[Int]:
        """Take the clause of a condition node, as upstream
        `take_inner_nodes`."""
        var clause = self.nodes[node].if_clause
        if clause != NONE:
            self.nodes[node].if_clause = NONE
        else:
            clause = self.nodes[node].else_clause
            self.nodes[node].else_clause = NONE
        if clause == NONE:
            return List[Int]()
        return self.flatten_sequence(clause)

    def merge_condition(mut self, node: Int, other: Int):
        """Merge a compatible condition node into another, as upstream
        `ConditionNode::merge`.

        Args:
            node: The condition node that stays.
            other: The condition node merged into it.
        """
        var merge_into_if_clause = self.nodes[node].if_clause != NONE
        var nodes = self._take_inner_nodes(node)
        for child in self._take_inner_nodes(other):
            nodes.append(child)
        var body = self.sequence(nodes^)
        if merge_into_if_clause:
            self.nodes[node].if_clause = body
        else:
            self.nodes[node].else_clause = body

    def under_condition(mut self, node: Int, cond: Cond) -> Int:
        """Return the node, run only when a condition holds, as upstream
        `under_condition`.

        Args:
            node: The node.
            cond: The condition; it must be some.

        Returns:
            A new condition node: `Skip` around `Include` for both.
        """
        if cond.skip != NONE and cond.include != NONE:
            var include_node = self.add_condition(cond.include, node, NONE)
            return self.add_condition(cond.skip, NONE, include_node)
        if cond.include != NONE:
            return self.add_condition(cond.include, node, NONE)
        return self.add_condition(cond.skip, NONE, node)

    def into_executable(var self) -> QueryPlan:
        """Return the plan ready to run, as upstream `into_executable`.

        Returns:
            The plan; it prints each operation as its text on one line.
        """
        self.executable = True
        return self^

    # --- printing -------------------------------------------------------

    def text(self, store: Store) raises -> String:
        """Return the plan as upstream `Display`.

        Args:
            store: The store with the selections.

        Returns:
            `QueryPlan {` ... `},` with two spaces per level.

        Raises:
            Error: For a condition node with both clauses or none, as
                upstream panics.
        """
        var out = String("QueryPlan {\n")
        if self.node != NONE:
            self.pretty(store, out, self.node, 1)
        else:
            out += "  None,\n"
        out += "},\n"
        return out^

    def node_text(self, store: Store, node: Int) raises -> String:
        """Return one node as upstream `Display`.

        Args:
            store: The store with the selections.
            node: The node.

        Returns:
            The node at depth 0.

        Raises:
            Error: For a condition node with both clauses or none.
        """
        var out = String()
        self.pretty(store, out, node, 0)
        return out^

    def pretty(
        self, store: Store, mut out: String, node: Int, depth: Int
    ) raises:
        """Write one node as upstream `PrettyDisplay`.

        Args:
            store: The store with the selections.
            out: The destination.
            node: The node.
            depth: The indentation depth.

        Raises:
            Error: For a condition node with both clauses or none.
        """
        ref found = self.nodes[node]
        var kind = found.kind
        if kind == PlanNodeKind.FETCH:
            self._pretty_fetch(store, out, found.fetch, depth)
        elif kind == PlanNodeKind.BATCH_FETCH:
            self._pretty_batch(store, out, found.fetch, depth)
        elif kind == PlanNodeKind.FLATTEN:
            write_indent(out, depth)
            out += 'Flatten(path: "'
            out += found.path.text(store)
            out += '") {\n'
            self.pretty(store, out, found.node, depth + 1)
            write_indent(out, depth)
            out += "},\n"
        elif kind == PlanNodeKind.SEQUENCE or kind == PlanNodeKind.PARALLEL:
            write_indent(out, depth)
            out += (
                "Sequence {\n" if kind
                == PlanNodeKind.SEQUENCE else "Parallel {\n"
            )
            var index = 0
            while index < len(found.nodes):
                self.pretty(store, out, found.nodes[index], depth + 1)
                index += 1
            write_indent(out, depth)
            out += "},\n"
        elif kind == PlanNodeKind.CONDITION:
            if found.if_clause != NONE and found.else_clause == NONE:
                write_indent(out, depth)
                out += "Include(if: $"
                out += store.name(found.condition)
                out += ") {\n"
                self.pretty(store, out, found.if_clause, depth + 1)
            elif found.if_clause == NONE and found.else_clause != NONE:
                write_indent(out, depth)
                out += "Skip(if: $"
                out += store.name(found.condition)
                out += ") {\n"
                self.pretty(store, out, found.else_clause, depth + 1)
            elif found.if_clause != NONE:
                raise Error(
                    "not yet implemented: Implement pretty_fmt for"
                    " ConditionNode with both if and else clauses"
                )
            else:
                raise Error("Invalid condition node")
            write_indent(out, depth)
            out += "},\n"
        elif kind == PlanNodeKind.SUBSCRIPTION:
            write_indent(out, depth)
            out += "Subscription {\n"
            self._pretty_fetch(store, out, found.fetch, depth + 1)
            write_indent(out, depth)
            out += "},\n"

    def _write_operation(
        self,
        store: Store,
        mut out: String,
        operation: PlanningFetchOperation,
        depth: Int,
    ):
        """Write an operation, in the form of the plan state."""
        if self.executable:
            operation.pretty_executable(out, depth)
        else:
            operation.pretty(store, out, depth)

    def _pretty_fetch(
        self, store: Store, mut out: String, fetch: Int, depth: Int
    ):
        """Write a fetch node as upstream `PrettyDisplay`."""
        ref data = self.fetches[fetch]
        write_indent(out, depth)
        out += 'Fetch(service: "'
        out += _service_text(store, data.service_name)
        out += '") {\n'
        if data.requires != NONE:
            write_indent(out, depth)
            out += "  {\n"
            pretty_set(store, out, data.requires, depth + 2)
            write_indent(out, depth)
            out += "  } =>\n"
        self._write_operation(store, out, data.operation, depth)
        write_indent(out, depth)
        out += "},\n"

    def _pretty_batch(
        self, store: Store, mut out: String, batch: Int, depth: Int
    ):
        """Write a batch fetch node as upstream `PrettyDisplay`."""
        ref data = self.batches[batch]
        write_indent(out, depth)
        out += 'BatchFetch(service: "'
        out += _service_text(store, data.service_name)
        out += '") {\n'
        write_indent(out, depth)
        out += "  {\n"
        var index = 0
        while index < len(data.aliases):
            ref alias = data.aliases[index]
            index += 1
            write_indent(out, depth)
            out += "    "
            out += store.name(alias.alias)
            out += " {\n"
            write_indent(out, depth)
            out += "      paths: [\n"
            var at = 0
            while at < len(alias.merge_paths):
                write_indent(out, depth)
                out += '        "'
                out += alias.merge_paths[at].text(store)
                out += '"\n'
                at += 1
            write_indent(out, depth)
            out += "      ]\n"
            write_indent(out, depth)
            out += "      {\n"
            pretty_set(store, out, alias.requires, depth + 4)
            write_indent(out, depth)
            out += "      }\n"
            write_indent(out, depth)
            out += "    }\n"
        write_indent(out, depth)
        out += "  }\n"
        self._write_operation(store, out, data.operation, depth)
        write_indent(out, depth)
        out += "},\n"


def _service_text(store: Store, service_name: Int) -> String:
    """Return a subgraph name; `*` for upstream `SubgraphName::any()`."""
    if service_name == NONE:
        return "*"
    return store.name(service_name)


# --- from fetch steps ----------------------------------------------------


def representations_type(mut store: Store) -> TypeNode:
    """Return the type `[_Any!]!` of a representations variable.

    Args:
        store: The store for the name.

    Returns:
        The type.
    """
    return TypeNode(store.sym("_Any"), "[%!]!")


def variable_args(mut store: Store, name: StringSlice, variable: Int) -> Int:
    """Return the argument map `{name: $variable}`.

    Args:
        store: The store.
        name: The argument name.
        variable: The variable name, as a symbol.

    Returns:
        The interned map.
    """
    var value = store.add_value(ValueKind.VARIABLE)
    store.values[value].text = variable
    return store.intern_args([store.sym(name)], [value])


def _create_output_operation(
    mut store: Store, step: FetchStepData, state: SupergraphState
) raises -> PlanningFetchOperation:
    """Return the `_entities` operation of an entity call, as upstream
    `create_output_operation`."""
    var representations = store.sym("representations")
    var variables: List[VariableDefinition] = [
        VariableDefinition(representations, representations_type(store), NONE)
    ]
    if step.has_variable_definitions:
        variables.extend(step.variable_definitions.copy())
    var entities = store.add_item(
        ItemKind.FIELD,
        store.sym("_entities"),
        args=variable_args(store, "representations", representations),
    )
    var selections = step.output.to_non_root_selection_set(store)
    store.set_children(entities, store.children(selections))
    var set = store.new_set()
    store.append(set, entities)
    var operation = OperationDefinition(OperationKind.QUERY, set)
    operation.variables = variables^
    operation.has_variables = True
    return _minified(store, operation^, state)


def _minified(
    mut store: Store, var operation: OperationDefinition, state: SupergraphState
) raises -> PlanningFetchOperation:
    """Minify an operation and print it, as upstream
    `minify_operation(...).expect("Failed to minify")`."""
    try:
        var document = minify_operation(store, operation^, state)
        return PlanningFetchOperation(document^, store)
    except error:
        raise Error("Failed to minify: " + String(error))


def fetch_node_from_fetch_step(
    mut store: Store, step: FetchStepData, state: SupergraphState
) raises -> FetchNode:
    """Make the fetch node of a fetch step, as upstream
    `FetchNode::from_fetch_step`.

    Args:
        store: The store.
        step: The fetch step.
        state: The supergraph.

    Returns:
        The fetch node.

    Raises:
        Error: When the root type is missing or minification fails.
    """
    var operation_kind = step.operation_kind
    var requires = NONE
    var operation: PlanningFetchOperation
    if step.is_entity_call():
        var input = step.input.to_non_root_selection_set(store)
        requires = strip_for_plan_input(store, input)
        operation_kind = OperationKind.QUERY
        operation = _create_output_operation(store, step, state)
    else:
        var root_type_name = state.root_type_name(step.operation_kind)
        var definition = OperationDefinition(
            step.operation_kind,
            step.output.to_root_selection_set(store, root_type_name),
        )
        if step.has_variable_definitions:
            definition.variables = step.variable_definitions.copy()
            definition.has_variables = True
        operation = _minified(store, definition^, state)
    var node = FetchNode(
        step.id, step.service_name, operation_kind, operation^, requires
    )
    if step.has_variable_usages:
        node.variable_usages = step.variable_usages.copy()
        node.has_variable_usages = True
    if step.has_input_rewrites:
        node.input_rewrites = step.input_rewrites.copy()
        node.has_input_rewrites = True
    if step.has_output_rewrites:
        node.output_rewrites = step.output_rewrites.copy()
        node.has_output_rewrites = True
    return node^


def plan_node_from_fetch_step(
    mut store: Store,
    mut plan: QueryPlan,
    step: FetchStepData,
    state: SupergraphState,
) raises -> Int:
    """Make the plan node of a fetch step, as upstream
    `PlanNode::from_fetch_step`: a flatten node at a response path, a
    subscription node, or a fetch node, under the conditions of the path
    and the step, outermost first.

    Args:
        store: The store.
        plan: The plan that holds the new nodes.
        step: The fetch step.
        state: The supergraph.

    Returns:
        The node.

    Raises:
        Error: When the root type is missing or minification fails.
    """
    var fetch = fetch_node_from_fetch_step(store, step, state)
    var is_subscription = fetch.operation_kind == OperationKind.SUBSCRIPTION
    var node: Int
    if not step.response_path.is_empty():
        var child = plan.add_fetch(fetch^)
        node = plan.add_flatten(
            FlattenNodePath.from_merge_path(step.response_path), child
        )
    elif is_subscription:
        plan.fetches.append(fetch^)
        var subscription = PlanNode.of(PlanNodeKind.SUBSCRIPTION)
        subscription.fetch = len(plan.fetches) - 1
        node = plan.add(subscription^)
    else:
        node = plan.add_fetch(fetch^)
    var conditions = List[Cond]()
    var candidates = step.response_path.conditions()
    if step.condition.is_some():
        candidates.append(step.condition)
    for cond in candidates:
        var seen = False
        for known in conditions:
            if known == cond:
                seen = True
                break
        if not seen:
            conditions.append(cond)
    var index = len(conditions) - 1
    while index >= 0:
        node = plan.under_condition(node, conditions[index])
        index -= 1
    return node

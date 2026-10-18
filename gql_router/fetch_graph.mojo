# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The fetch graph builder: from a query tree to fetch steps.

Port of Hive Router `1a29df9`
`bin/router/src/query_planner/planner/fetch/fetch_graph.rs`, from
`create_noop_fetch_step` to `requirements_resolve_in_place`, and
`build_fetch_graph_from_query_tree`; and `add_variables_to_fetch_steps`
of `planner/mod.rs`.

`build_fetch_graph` walks the query tree once. Each tree node adds a field,
a fragment or a new fetch step, and connects the steps that depend on each
other. The result is the graph before optimization.

**Differences from upstream.** Upstream keeps `entity_owners` and
`response_keys` in `FetchGraph` while it builds the graph. This port keeps
them in `FetchGraphBuilder`, and `FetchGraph` holds only the steps.
`build_fetch_graph` does not optimize the graph and does not collect the
variable usages; the caller does that. `find_satisfiable_key` checks the
keys with a `Walker` of its own, made on first use. Upstream returns a
`FetchGraphError` for states the builder never makes: an edge of the wrong
kind, an end that is not a subgraph type, a node with an edge but no
parent step, a missing entity owner or a fetch graph without one root.
This port leaves those checks out.
"""

from gql_router.ast import NONE, Cond, ItemKind
from gql_router.federation_spec import OperationKind
from gql_router.fetch_step import (
    FetchGraph,
    FetchNodePathSegment,
    FetchRewrite,
    FetchStepData,
    FetchStepFlags,
    FetchStepKind,
    FetchStepSelections,
)
from gql_router.graph import EdgeKind, Graph, PlannerOverrideContext
from gql_router.merge_path import MergePath, Segment, SegmentKind
from gql_router.operation import OperationDefinition, VariableDefinition
from gql_router.query_tree import OperationPath, PlanSpace
from gql_router.response_keys import ResponseKeys, place_of
from gql_router.selection_set import items_are_subset_of
from gql_router.store import Store
from gql_router.supergraph_state import SupergraphState
from gql_router.walker import Walker, requirement_ids


@fieldwise_init
struct TypeAwareSelection(ImplicitlyCopyable, Movable):
    """A selection set of a type, as upstream `TypeAwareSelection`."""

    var type_name: Int
    """The type, as a symbol."""
    var selection_set: Int
    """The set, a `ROOT` item."""


def _single_field_set(
    mut store: Store,
    name: Int,
    alias: Int,
    args: Int,
    cond: Cond,
    with_typename: Bool,
) -> Int:
    """Return a set with one field, and `__typename` below it when asked."""
    var set = store.new_set()
    var field = store.add_item(
        ItemKind.FIELD,
        name,
        alias=alias,
        args=args,
        skip=cond.skip,
        include=cond.include,
    )
    if with_typename:
        store.append(
            field, store.add_item(ItemKind.FIELD, store.sym("__typename"))
        )
    store.append(set, field)
    return set


def _typename_rewrite(mut store: Store, type_name: Int) -> FetchRewrite:
    """Return the `ValueSetter` that sets `__typename` of `... on Type` to
    the type."""
    var path: List[FetchNodePathSegment] = [
        FetchNodePathSegment(False, NONE, store.single_type_set(type_name)),
        FetchNodePathSegment(True, store.sym("__typename"), NONE),
    ]
    return FetchRewrite(True, path^, type_name)


def _condition_in_path(fetch_path: MergePath, cond: Cond) -> Bool:
    """Return True if a field or type condition step of a path has the
    condition."""
    if not cond.is_some():
        return False
    for segment in fetch_path.segments:
        if (
            segment.kind != SegmentKind.LIST
            and segment.cond.is_some()
            and segment.cond == cond
        ):
            return True
    return False


def requirements_resolve_in_place(
    graph: Graph, space: PlanSpace, query_node: Int
) -> Bool:
    """Return True if the required fields of a node can be fetched in the
    same fetch as the field, as upstream `requirements_resolve_in_place`.

    Args:
        graph: The planner graph.
        space: The plan space with the trees.
        query_node: The tree node.

    Returns:
        Whether every path to the requirements stays in the subgraph.
    """
    ref requirements = space.trees[query_node].requirements
    var index = 0
    while index < len(requirements):
        if not _stays_in_subgraph(graph, space, requirements[index]):
            return False
        index += 1
    return True


def _stays_in_subgraph(graph: Graph, space: PlanSpace, node: Int) -> Bool:
    """Return upstream `stays_in_subgraph`."""
    ref tree = space.trees[node]
    if len(tree.requirements) > 0:
        return False
    if tree.edge_from_parent != NONE:
        var kind = graph.edges[tree.edge_from_parent].kind
        if (
            kind != EdgeKind.FIELD_MOVE
            and kind != EdgeKind.ABSTRACT_MOVE
            and kind != EdgeKind.SELFIE
        ):
            return False
    for child in tree.children:
        if not _stays_in_subgraph(graph, space, child):
            return False
    return True


def add_variables_to_fetch_steps(
    mut fetch_graph: FetchGraph,
    variables: List[VariableDefinition],
    has_variables: Bool,
):
    """Give each step the definitions of the variables it uses, as upstream
    `add_variables_to_fetch_steps`.

    Args:
        fetch_graph: The fetch graph, with the variable usages collected.
        variables: The operation's variable definitions.
        has_variables: False when upstream `variable_definitions` is `None`.
    """
    if not has_variables:
        return
    var indices = fetch_graph.step_indices()
    var at = 0
    while at < len(indices):
        var index = indices[at]
        at += 1
        if not fetch_graph.steps[index].has_variable_usages:
            continue
        var relevant = List[VariableDefinition]()
        ref usages = fetch_graph.steps[index].variable_usages
        var used = 0
        while used < len(usages):
            var known = 0
            while known < len(variables):
                if variables[known].name == usages[used]:
                    relevant.append(variables[known].copy())
                    break
                known += 1
            used += 1
        fetch_graph.steps[index].variable_definitions = relevant^
        fetch_graph.steps[index].has_variable_definitions = True


struct FetchGraphBuilder(Movable):
    """The fetch graph while it is built, with the builder-only state of
    upstream `FetchGraph<SingleTypeFetchStep>`."""

    var fetch_graph: FetchGraph
    """The steps and their dependencies."""
    var entity_owners: Dict[Int, Int]
    """The step whose output each entity call gets its representations
    from: the step that holds the object the entity call extends."""
    var response_keys: ResponseKeys
    """The keys of the fields the planner adds itself."""
    var walker: Walker
    """The walker that checks the keys of `find_satisfiable_key`."""
    var walker_ready: Bool
    """Whether `walker` has the graph's requirement ids."""

    def __init__(out self, kind: OperationKind):
        """Start an empty graph.

        Args:
            kind: The operation kind.
        """
        self.fetch_graph = FetchGraph(kind)
        self.entity_owners = Dict[Int, Int]()
        self.response_keys = ResponseKeys()
        self.walker = Walker(List[Int](), NONE)
        self.walker_ready = False

    def into_fetch_graph(deinit self) -> FetchGraph:
        """Return the fetch graph and drop the builder-only state, as
        upstream `to_multi_type`.

        Returns:
            The fetch graph.
        """
        return self.fetch_graph^

    # --- response keys --------------------------------------------------

    def read_at(
        mut self,
        mut store: Store,
        response_path: MergePath,
        selection: TypeAwareSelection,
    ) -> TypeAwareSelection:
        """Return a key or requirement of the objects at a path, the way an
        entity call reads it, as upstream `read_at`.

        Args:
            store: The store.
            response_path: The response path of the objects.
            selection: The key or requirement.

        Returns:
            The selection with each planner field read from its key.
        """
        return TypeAwareSelection(
            selection.type_name,
            self.response_keys.input(
                store, place_of(response_path), selection.selection_set
            ),
        )

    def alias_at(
        mut self,
        mut store: Store,
        space: PlanSpace,
        response_path: MergePath,
        query_node: Int,
        field_name: Int,
        created_from_requires: Bool,
    ) -> Int:
        """Return the alias of a field on the objects at a path, as upstream
        `alias_at`.

        Args:
            store: The store.
            space: The plan space with the trees.
            response_path: The response path of the objects.
            query_node: The tree node of the field.
            field_name: The field name, as a symbol.
            created_from_requires: Whether the planner adds the field itself.

        Returns:
            The client alias, or for a planner field the key it gets when
            that is not its name; `NONE` for no alias.
        """
        var alias = space.trees[query_node].alias
        var args = space.trees[query_node].args
        if not created_from_requires:
            return alias
        var key = self.response_keys.wire_key_of(
            store, place_of(response_path), field_name, args
        )
        if key != field_name:
            return key
        return NONE

    # --- steps ----------------------------------------------------------

    def create_noop_fetch_step(mut self, created_from_requires: Bool) -> Int:
        """Add the root step that fetches nothing, as upstream
        `create_noop_fetch_step`.

        Args:
            created_from_requires: Whether to flag it `USED_FOR_REQUIRES`.

        Returns:
            The step index.
        """
        var flags = FetchStepFlags.EMPTY
        if created_from_requires:
            flags = FetchStepFlags.USED_FOR_REQUIRES
        var id = self.fetch_graph.create_fetch_id()
        return self.fetch_graph.add_step(
            FetchStepData(
                id,
                NONE,
                MergePath(),
                FetchStepSelections.new_empty(),
                FetchStepSelections.new_empty(),
                FetchStepKind.ROOT,
                OperationKind.QUERY,
                flags,
                Cond.none(),
                NONE,
            )
        )

    def create_fetch_step_for_entity_call(
        mut self,
        mut store: Store,
        owner_index: Int,
        subgraph_name: Int,
        input_type_name: Int,
        output_type_name: Int,
        response_path: MergePath,
        condition: Cond,
        used_for_requires: Bool,
    ) raises -> Int:
        """Add an entity call, as upstream
        `create_fetch_step_for_entity_call`.

        Args:
            store: The store.
            owner_index: The step that holds the objects.
            subgraph_name: The subgraph, as a symbol.
            input_type_name: The type of the representations.
            output_type_name: The type of the output.
            response_path: The response path.
            condition: The condition of the fetch.
            used_for_requires: Whether to flag it `USED_FOR_REQUIRES`.

        Returns:
            The step index.

        Raises:
            Error: On a response key conflict.
        """
        var flags = FetchStepFlags.EMPTY
        if used_for_requires:
            flags = FetchStepFlags.USED_FOR_REQUIRES
        var input = FetchStepSelections.new(store, input_type_name)
        var typename = store.new_set()
        store.append(
            typename, store.add_item(ItemKind.FIELD, store.sym("__typename"))
        )
        input.add(store, typename)
        var output = FetchStepSelections.new(store, output_type_name)
        var id = self.fetch_graph.create_fetch_id()
        var step_index = self.fetch_graph.add_step(
            FetchStepData(
                id,
                subgraph_name,
                response_path.copy(),
                input^,
                output^,
                FetchStepKind.ENTITY,
                OperationKind.QUERY,
                flags,
                condition,
                NONE,
            )
        )
        self.entity_owners[step_index] = owner_index
        return step_index

    def create_fetch_step_for_root_move(
        mut self,
        mut store: Store,
        root_step_index: Int,
        subgraph_name: Int,
        type_name: Int,
        operation_kind: OperationKind,
        mutation_field_position: Int,
        response_path: MergePath,
        condition: Cond,
    ) -> Int:
        """Add a root call below a step, as upstream
        `create_fetch_step_for_root_move`.

        Args:
            store: The store.
            root_step_index: The parent step.
            subgraph_name: The subgraph, as a symbol.
            type_name: The root type, as a symbol.
            operation_kind: The operation kind of the fetch.
            mutation_field_position: The mutation field position, or `NONE`.
            response_path: The response path.
            condition: The condition of the fetch.

        Returns:
            The step index.
        """
        var input = FetchStepSelections.new(store, type_name)
        var output = FetchStepSelections.new(store, type_name)
        var id = self.fetch_graph.create_fetch_id()
        var index = self.fetch_graph.add_step(
            FetchStepData(
                id,
                subgraph_name,
                response_path.copy(),
                input^,
                output^,
                FetchStepKind.ROOT,
                operation_kind,
                FetchStepFlags.EMPTY,
                condition,
                mutation_field_position,
            )
        )
        _ = self.fetch_graph.connect(root_step_index, index)
        return index

    def ensure_fetch_step_for_subgraph(
        mut self,
        mut store: Store,
        parent_fetch_step_index: Int,
        subgraph_name: Int,
        input_type_name: Int,
        output_type_name: Int,
        response_path: MergePath,
        key: TypeAwareSelection,
        requires: TypeAwareSelection,
        condition: Cond,
        created_from_requires: Bool,
    ) raises -> Int:
        """Return a child entity call that can take a key, or add one, as
        upstream `ensure_fetch_step_for_subgraph`.

        Args:
            store: The store.
            parent_fetch_step_index: The parent step.
            subgraph_name: The subgraph, as a symbol.
            input_type_name: The type of the representations.
            output_type_name: The type of the output.
            response_path: The response path.
            key: The key; its `selection_set` is `NONE` for no key.
            requires: The requirement; its `selection_set` is `NONE` for
                none. A requirement never reuses a step.
            condition: The condition of the fetch.
            created_from_requires: Whether a `@requires` needs the step.

        Returns:
            The step index.

        Raises:
            Error: On a response key conflict.
        """
        var has_key = key.selection_set != NONE
        var has_requires = requires.selection_set != NONE
        var matching = NONE
        if not has_requires:
            for child in self.fetch_graph.child_steps(parent_fetch_step_index):
                if not self._can_reuse_for_subgraph(
                    store,
                    child,
                    subgraph_name,
                    input_type_name,
                    response_path,
                    key,
                    has_key,
                    condition,
                ):
                    continue
                matching = child
                break
        if matching != NONE:
            return matching
        var step_index = self.create_fetch_step_for_entity_call(
            store,
            parent_fetch_step_index,
            subgraph_name,
            input_type_name,
            output_type_name,
            response_path,
            condition,
            created_from_requires or has_requires,
        )
        if has_key:
            self.fetch_graph.step(step_index).input.add(
                store, key.selection_set
            )
        return step_index

    def _can_reuse_for_subgraph(
        self,
        store: Store,
        child: Int,
        subgraph_name: Int,
        input_type_name: Int,
        response_path: MergePath,
        key: TypeAwareSelection,
        has_key: Bool,
        condition: Cond,
    ) raises -> Bool:
        """Return True if a child step matches, as the `find_map` of
        upstream `ensure_fetch_step_for_subgraph`."""
        ref step = self.fetch_graph.steps[child]
        if step.service_name != subgraph_name:
            return False
        if step.input.definition_name() != input_type_name:
            return False
        if step.response_path != response_path:
            return False
        if step.condition != condition:
            return False
        if has_key:
            if step.input.definition_name() != key.type_name:
                return False
            if not items_are_subset_of(
                store, step.input.selection_set(), key.selection_set
            ):
                return False
        if step.flags.contains(FetchStepFlags.USED_FOR_REQUIRES):
            return False
        return True

    def ensure_fetch_step_for_requirement(
        mut self,
        mut store: Store,
        parent_fetch_step_index: Int,
        subgraph_name: Int,
        type_name: Int,
        response_path: MergePath,
        condition: Cond,
        requirement: TypeAwareSelection,
    ) raises -> Int:
        """Return a child entity call whose input has a requirement, or add
        one, as upstream `ensure_fetch_step_for_requirement`.

        Args:
            store: The store.
            parent_fetch_step_index: The parent step.
            subgraph_name: The subgraph, as a symbol.
            type_name: The entity type, as a symbol.
            response_path: The response path.
            condition: The condition of the fetch.
            requirement: The requirement.

        Returns:
            The step index.

        Raises:
            Error: On a response key conflict.
        """
        for child in self.fetch_graph.child_steps(parent_fetch_step_index):
            if self._can_reuse_for_requirement(
                store,
                child,
                subgraph_name,
                type_name,
                response_path,
                condition,
                requirement,
            ):
                return child
        return self.create_fetch_step_for_entity_call(
            store,
            parent_fetch_step_index,
            subgraph_name,
            type_name,
            type_name,
            response_path,
            condition,
            True,
        )

    def _can_reuse_for_requirement(
        self,
        store: Store,
        child: Int,
        subgraph_name: Int,
        type_name: Int,
        response_path: MergePath,
        condition: Cond,
        requirement: TypeAwareSelection,
    ) raises -> Bool:
        """Return True if a child step matches, as the `find_map` of
        upstream `ensure_fetch_step_for_requirement`."""
        ref step = self.fetch_graph.steps[child]
        if step.service_name != subgraph_name:
            return False
        if step.condition != condition:
            return False
        if step.input.definition_name() != type_name:
            return False
        if step.response_path != response_path:
            return False
        return step.input.contains(
            store, requirement.type_name, requirement.selection_set
        )

    # --- keys -----------------------------------------------------------

    def find_satisfiable_key(
        mut self,
        store: Store,
        graph: Graph,
        state: SupergraphState,
        ctx: PlannerOverrideContext,
        space: PlanSpace,
        query_node: Int,
    ) raises -> TypeAwareSelection:
        """Return the key of an entity call to the node's own subgraph that
        the subgraph can satisfy, as upstream `find_satisfiable_key`.

        Args:
            store: The store.
            graph: The planner graph.
            state: The supergraph.
            ctx: The override context.
            space: The plan space with the trees.
            query_node: The tree node of the requirement.

        Returns:
            The key of the most expensive satisfiable entity move.

        Raises:
            Error: When no key can be satisfied.
        """
        if not self.walker_ready:
            self.walker.requirement_ids = requirement_ids(graph, store)
            self.walker_ready = True
        var node_index = space.trees[query_node].node_index
        var moves = List[Int]()
        var costs = List[Int]()
        var edges = graph.edges_from(node_index)
        var index = 0
        while index < len(edges):
            var edge = edges[index]
            index += 1
            if graph.edges[edge].kind != EdgeKind.ENTITY_MOVE:
                continue
            # A stable sort, most expensive first.
            var cost = graph.edges[edge].cost(store)
            var at = len(moves)
            while at > 0 and costs[at - 1] < cost:
                at -= 1
            moves.insert(at, edge)
            costs.insert(at, cost)
        # An entity move always has its key as its requirements.
        for edge in moves:
            var satisfied = self.walker.can_satisfy_edge(
                graph,
                store,
                state,
                ctx,
                edge,
                OperationPath(node_index, NONE, 0, NONE),
                List[Int](),
                List[Int](),
                True,
            )
            if satisfied:
                ref found = graph.edges[edge]
                return TypeAwareSelection(
                    found.requirement_type, found.requirements
                )
        raise Error("Internal Error: Failed to find Satisfiable Key")

    # --- children and requirements --------------------------------------

    def process_children_for_fetch_steps(
        mut self,
        mut store: Store,
        graph: Graph,
        state: SupergraphState,
        ctx: PlannerOverrideContext,
        space: PlanSpace,
        query_node: Int,
        parent_fetch_step_index: Int,
        response_path: MergePath,
        fetch_path: MergePath,
        requiring_fetch_step_index: Int,
        condition: Cond,
        created_from_requires: Bool,
    ) raises -> List[Int]:
        """Process each child of a node, as upstream
        `process_children_for_fetch_steps`.

        Args:
            store: The store.
            graph: The planner graph.
            state: The supergraph.
            ctx: The override context.
            space: The plan space with the trees.
            query_node: The tree node.
            parent_fetch_step_index: The step the children go into.
            response_path: The response path.
            fetch_path: The path in the parent's output.
            requiring_fetch_step_index: The step that requires these fields,
                or `NONE`.
            condition: The condition.
            created_from_requires: Whether the planner adds the fields.

        Returns:
            The leaf steps; the parent alone when there is no child.

        Raises:
            Error: When a step cannot be built.
        """
        var children = space.trees[query_node].children.copy()
        if len(children) == 0:
            return [parent_fetch_step_index]
        var leaves = List[Int]()
        var index = 0
        while index < len(children):
            leaves.extend(
                self.process_query_node(
                    store,
                    graph,
                    state,
                    ctx,
                    space,
                    children[index],
                    parent_fetch_step_index,
                    response_path,
                    fetch_path,
                    requiring_fetch_step_index,
                    condition,
                    created_from_requires,
                )
            )
            index += 1
        return leaves^

    def _connect_leaves(mut self, leaves: List[Int], child: Int):
        """Make each leaf step a parent of a step. Upstream also connects
        the requirements step when there is no leaf, but a node always has
        a leaf: its parent step when it has no child."""
        var index = 0
        while index < len(leaves):
            _ = self.fetch_graph.connect(leaves[index], child)
            index += 1

    def process_requirements_for_fetch_steps(
        mut self,
        mut store: Store,
        graph: Graph,
        state: SupergraphState,
        ctx: PlannerOverrideContext,
        space: PlanSpace,
        query_node: Int,
        parent_fetch_step_index: Int,
        requiring_fetch_step_index: Int,
        condition: Cond,
        response_path: MergePath,
        fetch_path: MergePath,
    ) raises:
        """Process each requirement of a node, as upstream
        `process_requirements_for_fetch_steps`.

        Args:
            store: The store.
            graph: The planner graph.
            state: The supergraph.
            ctx: The override context.
            space: The plan space with the trees.
            query_node: The tree node.
            parent_fetch_step_index: The step the requirements go into.
            requiring_fetch_step_index: The step that requires them, or
                `NONE`.
            condition: The condition.
            response_path: The response path.
            fetch_path: The path in the parent's output.

        Raises:
            Error: When a step cannot be built.
        """
        var requirements = space.trees[query_node].requirements.copy()
        for requirement in requirements:
            _ = self.process_query_node(
                store,
                graph,
                state,
                ctx,
                space,
                requirement,
                parent_fetch_step_index,
                response_path,
                fetch_path,
                requiring_fetch_step_index,
                condition,
                True,
            )

    def process_noop_edge(
        mut self,
        mut store: Store,
        graph: Graph,
        state: SupergraphState,
        ctx: PlannerOverrideContext,
        space: PlanSpace,
        query_node: Int,
        parent_fetch_step_index: Int,
        response_path: MergePath,
        fetch_path: MergePath,
        requiring_fetch_step_index: Int,
        condition: Cond,
        created_from_requires: Bool,
    ) raises -> List[Int]:
        """Process a node with no edge: the root, as upstream
        `process_noop_edge`.

        Args:
            store: The store.
            graph: The planner graph.
            state: The supergraph.
            ctx: The override context.
            space: The plan space with the trees.
            query_node: The tree node.
            parent_fetch_step_index: The parent step, or `NONE` to add the
                root step.
            response_path: The response path.
            fetch_path: The path in the parent's output.
            requiring_fetch_step_index: The requiring step, or `NONE`.
            condition: The condition.
            created_from_requires: Whether the planner adds the fields.

        Returns:
            The leaf steps.

        Raises:
            Error: When a step cannot be built.
        """
        var fetch_step_index = parent_fetch_step_index
        if fetch_step_index == NONE:
            fetch_step_index = self.create_noop_fetch_step(
                created_from_requires
            )
        return self.process_children_for_fetch_steps(
            store,
            graph,
            state,
            ctx,
            space,
            query_node,
            fetch_step_index,
            response_path,
            fetch_path,
            requiring_fetch_step_index,
            condition,
            created_from_requires,
        )

    # --- entity moves ---------------------------------------------------

    def process_entity_move_edge(
        mut self,
        mut store: Store,
        graph: Graph,
        state: SupergraphState,
        ctx: PlannerOverrideContext,
        space: PlanSpace,
        query_node: Int,
        parent_fetch_step_index: Int,
        response_path: MergePath,
        fetch_path: MergePath,
        requiring_fetch_step_index: Int,
        edge_index: Int,
        condition: Cond,
        created_from_requires: Bool,
    ) raises -> List[Int]:
        """Process an entity call, as upstream `process_entity_move_edge`.

        Args:
            store: The store.
            graph: The planner graph.
            state: The supergraph.
            ctx: The override context.
            space: The plan space with the trees.
            query_node: The tree node.
            parent_fetch_step_index: The step that holds the objects.
            response_path: The response path.
            fetch_path: The path in the parent's output.
            requiring_fetch_step_index: The requiring step, or `NONE`.
            edge_index: The entity move.
            condition: The condition.
            created_from_requires: Whether the planner adds the fields.

        Returns:
            The leaf steps.

        Raises:
            Error: When a step cannot be built.
        """
        # The caller dispatches on the edge kind, and both ends of an entity
        # move are subgraph types.
        ref edge = graph.edges[edge_index]
        var is_interface = edge.is_interface
        var requirement = self.read_at(
            store,
            response_path,
            TypeAwareSelection(edge.requirement_type, edge.requirements),
        )
        var input_type_name = graph.nodes[edge.head].name
        ref tail = graph.nodes[edge.tail]
        var output_type_name = tail.name
        var subgraph_name = tail.subgraph
        var fetch_step_index = self.ensure_fetch_step_for_subgraph(
            store,
            parent_fetch_step_index,
            subgraph_name,
            input_type_name,
            output_type_name,
            response_path,
            requirement,
            TypeAwareSelection(NONE, NONE),
            condition,
            created_from_requires,
        )
        self.fetch_graph.step(fetch_step_index).input.add(
            store, requirement.selection_set
        )
        if is_interface:
            var rewrite = _typename_rewrite(store, output_type_name)
            self.fetch_graph.step(fetch_step_index).add_input_rewrite(rewrite^)
            var flags = self.fetch_graph.step(fetch_step_index).flags
            self.fetch_graph.step(fetch_step_index).flags = flags.with_flag(
                FetchStepFlags.USED_FOR_TYPE_CONDITION
            )
        self.fetch_graph.step(
            parent_fetch_step_index
        ).output.add_selection_typename(store, fetch_path)
        _ = self.fetch_graph.connect(parent_fetch_step_index, fetch_step_index)
        self.process_requirements_for_fetch_steps(
            store,
            graph,
            state,
            ctx,
            space,
            query_node,
            parent_fetch_step_index,
            fetch_step_index,
            condition,
            response_path,
            fetch_path,
        )
        return self.process_children_for_fetch_steps(
            store,
            graph,
            state,
            ctx,
            space,
            query_node,
            fetch_step_index,
            response_path,
            MergePath(),
            requiring_fetch_step_index,
            condition,
            created_from_requires,
        )

    def process_interface_object_type_move_edge(
        mut self,
        mut store: Store,
        graph: Graph,
        state: SupergraphState,
        ctx: PlannerOverrideContext,
        space: PlanSpace,
        query_node: Int,
        parent_fetch_step_index: Int,
        response_path: MergePath,
        fetch_path: MergePath,
        requiring_fetch_step_index: Int,
        edge_index: Int,
        object_type_name: Int,
        condition: Cond,
        created_from_requires: Bool,
    ) raises -> List[Int]:
        """Process a move from an `@interfaceObject` to an object type, as
        upstream `process_interface_object_type_move_edge`.

        Args:
            store: The store.
            graph: The planner graph.
            state: The supergraph.
            ctx: The override context.
            space: The plan space with the trees.
            query_node: The tree node.
            parent_fetch_step_index: The step that holds the objects.
            response_path: The response path.
            fetch_path: The path in the parent's output.
            requiring_fetch_step_index: The requiring step, or `NONE`.
            edge_index: The interface object type move.
            object_type_name: The object type, as a symbol.
            condition: The condition.
            created_from_requires: Whether the planner adds the fields.

        Returns:
            The leaf steps.

        Raises:
            Error: When a step cannot be built.
        """
        # The caller dispatches on the edge kind, and both ends of the move
        # are subgraph types.
        ref edge = graph.edges[edge_index]
        var requirement = self.read_at(
            store,
            response_path,
            TypeAwareSelection(edge.requirement_type, edge.requirements),
        )
        var head_subgraph_name = graph.nodes[edge.head].subgraph
        ref tail = graph.nodes[edge.tail]
        var interface_type_name = tail.name
        var subgraph_name = tail.subgraph
        var step_for_children_index = self.ensure_fetch_step_for_subgraph(
            store,
            parent_fetch_step_index,
            subgraph_name,
            object_type_name,
            interface_type_name,
            response_path,
            requirement,
            TypeAwareSelection(NONE, NONE),
            condition,
            created_from_requires,
        )
        var requirement_tree = space.trees[query_node].requirements[0]
        var key = self.find_satisfiable_key(
            store, graph, state, ctx, space, requirement_tree
        )
        var key_to_reenter_subgraph = self.read_at(store, response_path, key)
        self.fetch_graph.step(step_for_children_index).input.add(
            store, requirement.selection_set
        )
        self.fetch_graph.step(step_for_children_index).input.add(
            store, key_to_reenter_subgraph.selection_set
        )
        var rewrite = _typename_rewrite(store, interface_type_name)
        self.fetch_graph.step(step_for_children_index).add_input_rewrite(
            rewrite^
        )
        self.fetch_graph.step(
            parent_fetch_step_index
        ).output.add_selection_typename(store, fetch_path)
        var step_for_requirements_index = (
            self.create_fetch_step_for_entity_call(
                store,
                parent_fetch_step_index,
                head_subgraph_name,
                object_type_name,
                interface_type_name,
                response_path,
                condition,
                False,
            )
        )
        self.fetch_graph.step(step_for_requirements_index).input.add(
            store, key_to_reenter_subgraph.selection_set
        )
        # parent -> step_for_requirements -> step_for_children
        _ = self.fetch_graph.connect(
            parent_fetch_step_index, step_for_requirements_index
        )
        var leaves = self.process_query_node(
            store,
            graph,
            state,
            ctx,
            space,
            requirement_tree,
            step_for_requirements_index,
            response_path,
            MergePath(),
            NONE,
            condition,
            True,
        )
        self._connect_leaves(leaves, step_for_children_index)
        return self.process_children_for_fetch_steps(
            store,
            graph,
            state,
            ctx,
            space,
            query_node,
            step_for_children_index,
            response_path,
            MergePath(),
            requiring_fetch_step_index,
            condition,
            created_from_requires,
        )

    # --- root moves -----------------------------------------------------

    def process_subgraph_entrypoint_edge(
        mut self,
        mut store: Store,
        graph: Graph,
        state: SupergraphState,
        ctx: PlannerOverrideContext,
        space: PlanSpace,
        query_node: Int,
        parent_fetch_step_index: Int,
        subgraph_name: Int,
        type_name: Int,
        operation_kind: OperationKind,
        created_from_requires: Bool,
    ) raises -> List[Int]:
        """Process an entrypoint into a subgraph's root type, as upstream
        `process_subgraph_entrypoint_edge`.

        Args:
            store: The store.
            graph: The planner graph.
            state: The supergraph.
            ctx: The override context.
            space: The plan space with the trees.
            query_node: The tree node.
            parent_fetch_step_index: The root step.
            subgraph_name: The subgraph, as a symbol.
            type_name: The root type, as a symbol.
            operation_kind: The operation kind.
            created_from_requires: Whether the planner adds the fields.

        Returns:
            The leaf steps.

        Raises:
            Error: When a step cannot be built.
        """
        var fetch_step_index = self.create_fetch_step_for_root_move(
            store,
            parent_fetch_step_index,
            subgraph_name,
            type_name,
            operation_kind,
            space.trees[query_node].mutation_field_position,
            MergePath(),
            Cond.none(),
        )
        return self.process_children_for_fetch_steps(
            store,
            graph,
            state,
            ctx,
            space,
            query_node,
            fetch_step_index,
            MergePath(),
            MergePath(),
            NONE,
            Cond.none(),
            created_from_requires,
        )

    def process_subgraph_reentry(
        mut self,
        mut store: Store,
        graph: Graph,
        state: SupergraphState,
        edge_index: Int,
        ctx: PlannerOverrideContext,
        space: PlanSpace,
        query_node: Int,
        parent_fetch_step_index: Int,
        created_from_requires: Bool,
        response_path: MergePath,
        fetch_path: MergePath,
        requiring_fetch_step_index: Int,
        condition: Cond,
    ) raises -> List[Int]:
        """Process a field that reenters a root type in another fetch, as
        upstream `process_subgraph_reentry`.

        Args:
            store: The store.
            graph: The planner graph.
            state: The supergraph.
            edge_index: The reentry move.
            ctx: The override context.
            space: The plan space with the trees.
            query_node: The tree node.
            parent_fetch_step_index: The step the field goes into.
            created_from_requires: Whether the planner adds the fields.
            response_path: The response path.
            fetch_path: The path in the parent's output.
            requiring_fetch_step_index: The requiring step, or `NONE`.
            condition: The condition.

        Returns:
            The leaf steps.

        Raises:
            Error: When a step cannot be built.
        """
        ref edge = graph.edges[edge_index]
        var field_name = edge.name
        var is_list = edge.is_list
        # The tail of a reentry move is the root type of a subgraph.
        ref tail = graph.nodes[edge.tail]
        var type_name = tail.name
        var subgraph_name = tail.subgraph
        var should_strip_condition = _condition_in_path(
            fetch_path, condition
        ) or (
            condition.is_some()
            and self.fetch_graph.is_condition_on_step(
                parent_fetch_step_index, requiring_fetch_step_index, condition
            )
        )
        var field_alias = self.alias_at(
            store,
            space,
            response_path,
            query_node,
            field_name,
            created_from_requires,
        )
        var field_cond = Cond.none() if should_strip_condition else condition
        var set = _single_field_set(
            store,
            field_name,
            field_alias,
            space.trees[query_node].args,
            field_cond,
            True,
        )
        self.fetch_graph.step(parent_fetch_step_index).output.add_at_path(
            store, fetch_path, set
        )
        var child_response_path = response_path.push(
            Segment.field(field_name, field_alias, NONE, Cond.none())
        )
        if is_list:
            child_response_path = child_response_path.push(Segment.list())
        var fetch_step_index = self.create_fetch_step_for_root_move(
            store,
            parent_fetch_step_index,
            subgraph_name,
            type_name,
            OperationKind.QUERY,
            space.trees[query_node].mutation_field_position,
            child_response_path,
            condition,
        )
        return self.process_children_for_fetch_steps(
            store,
            graph,
            state,
            ctx,
            space,
            query_node,
            fetch_step_index,
            child_response_path,
            MergePath(),
            requiring_fetch_step_index,
            Cond.none(),
            created_from_requires,
        )

    # --- type conditions ------------------------------------------------

    def process_selfie_edge(
        mut self,
        mut store: Store,
        graph: Graph,
        state: SupergraphState,
        ctx: PlannerOverrideContext,
        space: PlanSpace,
        query_node: Int,
        parent_fetch_step_index: Int,
        requiring_fetch_step_index: Int,
        response_path: MergePath,
        fetch_path: MergePath,
        target_type_name: Int,
        condition: Cond,
        created_from_requires: Bool,
    ) raises -> List[Int]:
        """Process a type condition on the same type, as upstream
        `process_selfie_edge`.

        Args:
            store: The store.
            graph: The planner graph.
            state: The supergraph.
            ctx: The override context.
            space: The plan space with the trees.
            query_node: The tree node.
            parent_fetch_step_index: The step the fragment goes into.
            requiring_fetch_step_index: The requiring step, or `NONE`.
            response_path: The response path.
            fetch_path: The path in the parent's output.
            target_type_name: The type, as a symbol.
            condition: The condition.
            created_from_requires: Whether the planner adds the fields.

        Returns:
            The leaf steps.

        Raises:
            Error: When a step cannot be built.
        """
        var condition_on_step = condition.is_some() and (
            self.fetch_graph.is_condition_on_step(
                parent_fetch_step_index, requiring_fetch_step_index, condition
            )
        )
        var segment_condition = Cond.none() if condition_on_step else condition
        var set = store.new_set()
        store.append(
            set,
            store.add_item(
                ItemKind.FRAGMENT,
                target_type_name,
                skip=segment_condition.skip,
                include=segment_condition.include,
            ),
        )
        self.fetch_graph.step(parent_fetch_step_index).output.add_at_path(
            store, fetch_path, set
        )
        var types = store.single_type_set(target_type_name)
        var child_response_path = response_path.push(
            Segment.type_condition(types, segment_condition)
        )
        var child_fetch_path = fetch_path.push(
            Segment.type_condition(types, segment_condition)
        )
        return self.process_children_for_fetch_steps(
            store,
            graph,
            state,
            ctx,
            space,
            query_node,
            parent_fetch_step_index,
            child_response_path,
            child_fetch_path,
            requiring_fetch_step_index,
            condition,
            created_from_requires,
        )

    def process_abstract_edge(
        mut self,
        mut store: Store,
        graph: Graph,
        state: SupergraphState,
        ctx: PlannerOverrideContext,
        space: PlanSpace,
        query_node: Int,
        parent_fetch_step_index: Int,
        requiring_fetch_step_index: Int,
        response_path: MergePath,
        fetch_path: MergePath,
        target_type_name: Int,
        condition: Cond,
        created_from_requires: Bool,
    ) raises -> List[Int]:
        """Process a move from an abstract type to an object type, as
        upstream `process_abstract_edge`.

        Args:
            store: The store.
            graph: The planner graph.
            state: The supergraph.
            ctx: The override context.
            space: The plan space with the trees.
            query_node: The tree node.
            parent_fetch_step_index: The step the fragment goes into.
            requiring_fetch_step_index: The requiring step, or `NONE`.
            response_path: The response path.
            fetch_path: The path in the parent's output.
            target_type_name: The object type, as a symbol.
            condition: The condition.
            created_from_requires: Whether the planner adds the fields.

        Returns:
            The leaf steps.

        Raises:
            Error: When a step cannot be built.
        """
        var set = store.new_set()
        store.append(
            set, store.add_item(ItemKind.FIELD, store.sym("__typename"))
        )
        store.append(set, store.add_item(ItemKind.FRAGMENT, target_type_name))
        self.fetch_graph.step(parent_fetch_step_index).output.add_at_path(
            store, fetch_path, set
        )
        var types = store.single_type_set(target_type_name)
        var child_response_path = response_path.push(
            Segment.type_condition(types, Cond.none())
        )
        var child_fetch_path = fetch_path.push(
            Segment.type_condition(types, Cond.none())
        )
        return self.process_children_for_fetch_steps(
            store,
            graph,
            state,
            ctx,
            space,
            query_node,
            parent_fetch_step_index,
            child_response_path,
            child_fetch_path,
            requiring_fetch_step_index,
            condition,
            created_from_requires,
        )

    # --- fields ---------------------------------------------------------

    def process_plain_field_edge(
        mut self,
        mut store: Store,
        graph: Graph,
        state: SupergraphState,
        ctx: PlannerOverrideContext,
        space: PlanSpace,
        query_node: Int,
        parent_fetch_step_index: Int,
        requiring_fetch_step_index: Int,
        response_path: MergePath,
        fetch_path: MergePath,
        edge_index: Int,
        condition: Cond,
        created_from_requires: Bool,
    ) raises -> List[Int]:
        """Process a field the parent step fetches itself, as upstream
        `process_plain_field_edge`.

        Args:
            store: The store.
            graph: The planner graph.
            state: The supergraph.
            ctx: The override context.
            space: The plan space with the trees.
            query_node: The tree node.
            parent_fetch_step_index: The step the field goes into.
            requiring_fetch_step_index: The requiring step, or `NONE`.
            response_path: The response path.
            fetch_path: The path in the parent's output.
            edge_index: The field move.
            condition: The condition.
            created_from_requires: Whether the planner adds the field.

        Returns:
            The leaf steps.

        Raises:
            Error: When a step cannot be built.
        """
        if requiring_fetch_step_index != NONE:
            _ = self.fetch_graph.connect(
                parent_fetch_step_index, requiring_fetch_step_index
            )
        var field_name = graph.edges[edge_index].name
        var is_list = graph.edges[edge_index].is_list
        var should_strip_condition = _condition_in_path(
            fetch_path, condition
        ) or (
            condition.is_some()
            and self.fetch_graph.is_condition_on_step(
                parent_fetch_step_index, requiring_fetch_step_index, condition
            )
        )
        var field_alias = self.alias_at(
            store,
            space,
            response_path,
            query_node,
            field_name,
            created_from_requires,
        )
        var args = space.trees[query_node].args
        var segment_condition = (
            Cond.none() if should_strip_condition else condition
        )
        var set = _single_field_set(
            store, field_name, field_alias, args, segment_condition, False
        )
        self.fetch_graph.step(parent_fetch_step_index).output.add_at_path(
            store, fetch_path, set
        )
        var segment = Segment.field(
            field_name, field_alias, args, segment_condition
        )
        var child_response_path = response_path.push(segment)
        var child_fetch_path = fetch_path.push(segment)
        if is_list:
            child_response_path = child_response_path.push(Segment.list())
            child_fetch_path = child_fetch_path.push(Segment.list())
        return self.process_children_for_fetch_steps(
            store,
            graph,
            state,
            ctx,
            space,
            query_node,
            parent_fetch_step_index,
            child_response_path,
            child_fetch_path,
            requiring_fetch_step_index,
            condition,
            created_from_requires,
        )

    def process_requires_field_edge(
        mut self,
        mut store: Store,
        graph: Graph,
        state: SupergraphState,
        ctx: PlannerOverrideContext,
        space: PlanSpace,
        query_node: Int,
        parent_fetch_step_index: Int,
        response_path: MergePath,
        requiring_fetch_step_index: Int,
        edge_index: Int,
        condition: Cond,
        created_from_requires: Bool,
    ) raises -> List[Int]:
        """Process a field with `@requires`, as upstream
        `process_requires_field_edge`.

        The field goes into an entity call that waits for every step that
        fetches a required field, and the step that holds the objects
        writes the key.

        Args:
            store: The store.
            graph: The planner graph.
            state: The supergraph.
            ctx: The override context.
            space: The plan space with the trees.
            query_node: The tree node.
            parent_fetch_step_index: The current step.
            response_path: The response path.
            requiring_fetch_step_index: The requiring step, or `NONE`.
            edge_index: The field move.
            condition: The condition.
            created_from_requires: Whether the planner adds the field.

        Returns:
            The leaf steps.

        Raises:
            Error: When a step cannot be built.
        """
        # The caller sends only a field move with `@requires` here, and its
        # head is a subgraph type.
        ref edge = graph.edges[edge_index]
        var requires = TypeAwareSelection(
            edge.requirement_type, edge.requirements
        )
        var field_name = edge.name
        var is_list = edge.is_list
        ref head = graph.nodes[edge.head]
        var head_type_name = head.name
        var head_subgraph_name = head.subgraph
        var is_interface_object = head.is_interface_object
        var is_using_provides = head.is_using_provides()
        var requirement_tree = space.trees[query_node].requirements[0]
        var key = self.find_satisfiable_key(
            store, graph, state, ctx, space, requirement_tree
        )
        # What the entity calls read, and the keys the step holding the
        # objects writes.
        var requires_input = self.read_at(store, response_path, requires)
        var key_input = self.read_at(store, response_path, key)
        var key_output = self.response_keys.output(
            store, place_of(response_path), key.selection_set
        )
        var field_alias = self.alias_at(
            store,
            space,
            response_path,
            query_node,
            field_name,
            created_from_requires,
        )
        var real_parent_fetch_step_index = parent_fetch_step_index
        var selecting = self.fetch_graph.step(
            parent_fetch_step_index
        ).output.is_selecting_definition(head_type_name)
        var parent_path_len = len(
            self.fetch_graph.step(parent_fetch_step_index).response_path
        )
        if selecting and not (parent_path_len < len(response_path)):
            # The parent is an entity call of the same type: go to the step
            # that holds the object the entity call extends. Every entity
            # call records its owner when it is made.
            real_parent_fetch_step_index = self.entity_owners[
                parent_fetch_step_index
            ]
        var step_for_children_index = self.ensure_fetch_step_for_requirement(
            store,
            real_parent_fetch_step_index,
            head_subgraph_name,
            head_type_name,
            response_path,
            condition,
            requires_input,
        )
        var args = space.trees[query_node].args
        var field_set = _single_field_set(
            store, field_name, field_alias, args, Cond.none(), False
        )
        self.fetch_graph.step(step_for_children_index).output.add_at_path(
            store, MergePath(), field_set
        )
        if is_interface_object:
            var rewrite = _typename_rewrite(store, head_type_name)
            self.fetch_graph.step(step_for_children_index).add_input_rewrite(
                rewrite^
            )
        self.fetch_graph.step(step_for_children_index).input.add(
            store, requires_input.selection_set
        )
        self.fetch_graph.step(step_for_children_index).input.add(
            store, key_input.selection_set
        )
        # The step holding the objects is above them.
        var real_parent_path_len = len(
            self.fetch_graph.step(real_parent_fetch_step_index).response_path
        )
        var key_to_reenter_at = response_path.slice_from(real_parent_path_len)
        self.fetch_graph.step(real_parent_fetch_step_index).output.add_at_path(
            store, key_to_reenter_at, key_output
        )
        self.fetch_graph.step(
            real_parent_fetch_step_index
        ).output.add_selection_typename(store, key_to_reenter_at)
        # On a `@provides` path, the fetch that went through the path gets
        # the required fields that only exist on that path.
        var step_for_requirements_index = real_parent_fetch_step_index
        var requirements_fetch_path = key_to_reenter_at.copy()
        if not is_using_provides:
            step_for_requirements_index = (
                self.create_fetch_step_for_entity_call(
                    store,
                    real_parent_fetch_step_index,
                    head_subgraph_name,
                    head_type_name,
                    head_type_name,
                    response_path,
                    condition,
                    True,
                )
            )
            self.fetch_graph.step(step_for_requirements_index).input.add(
                store, key_input.selection_set
            )
            _ = self.fetch_graph.connect(
                real_parent_fetch_step_index, step_for_requirements_index
            )
            requirements_fetch_path = MergePath()
        var segment = Segment.field(field_name, field_alias, args, Cond.none())
        var child_response_path = response_path.push(segment)
        var child_fetch_path = MergePath().push(segment)
        if is_list:
            child_response_path = child_response_path.push(Segment.list())
            child_fetch_path = child_fetch_path.push(Segment.list())
        var leaves = self.process_query_node(
            store,
            graph,
            state,
            ctx,
            space,
            requirement_tree,
            step_for_requirements_index,
            response_path,
            requirements_fetch_path,
            NONE,
            condition,
            True,
        )
        # Every leaf of the requirements becomes a parent of the step with
        # the field: f0 -> f2 -> f1 for `f0 { f1 @requires(fields: f2) }`.
        self._connect_leaves(leaves, step_for_children_index)
        return self.process_children_for_fetch_steps(
            store,
            graph,
            state,
            ctx,
            space,
            query_node,
            step_for_children_index,
            child_response_path,
            child_fetch_path,
            requiring_fetch_step_index,
            condition,
            created_from_requires,
        )

    # --- dispatch -------------------------------------------------------

    def process_query_node(
        mut self,
        mut store: Store,
        graph: Graph,
        state: SupergraphState,
        ctx: PlannerOverrideContext,
        space: PlanSpace,
        query_node: Int,
        parent_fetch_step_index: Int,
        response_path: MergePath,
        fetch_path: MergePath,
        requiring_fetch_step_index: Int,
        condition: Cond,
        created_from_requires: Bool,
    ) raises -> List[Int]:
        """Process one tree node by the kind of its edge, as upstream
        `process_query_node`.

        Args:
            store: The store.
            graph: The planner graph.
            state: The supergraph.
            ctx: The override context.
            space: The plan space with the trees.
            query_node: The tree node.
            parent_fetch_step_index: The parent step, or `NONE` at the root.
            response_path: The response path.
            fetch_path: The path in the parent's output.
            requiring_fetch_step_index: The requiring step, or `NONE`.
            condition: The condition from above; the node's own condition
                wins.
            created_from_requires: Whether the planner adds the fields.

        Returns:
            The leaf steps.

        Raises:
            Error: When a step cannot be built.
        """
        var own = space.trees[query_node].cond
        var cond = own if own.is_some() else condition
        var edge_index = space.trees[query_node].edge_from_parent
        if edge_index == NONE:
            return self.process_noop_edge(
                store,
                graph,
                state,
                ctx,
                space,
                query_node,
                parent_fetch_step_index,
                response_path,
                fetch_path,
                requiring_fetch_step_index,
                cond,
                created_from_requires,
            )
        # Only the root node has no edge, so every other node has a parent
        # step.
        ref edge = graph.edges[edge_index]
        var kind = edge.kind
        if kind == EdgeKind.SUBGRAPH_ENTRYPOINT:
            return self.process_subgraph_entrypoint_edge(
                store,
                graph,
                state,
                ctx,
                space,
                query_node,
                parent_fetch_step_index,
                edge.name,
                graph.nodes[edge.tail].name,
                edge.operation_kind,
                created_from_requires,
            )
        if kind == EdgeKind.ENTITY_MOVE:
            return self.process_entity_move_edge(
                store,
                graph,
                state,
                ctx,
                space,
                query_node,
                parent_fetch_step_index,
                response_path,
                fetch_path,
                requiring_fetch_step_index,
                edge_index,
                cond,
                created_from_requires,
            )
        if kind == EdgeKind.REENTRY_MOVE:
            return self.process_subgraph_reentry(
                store,
                graph,
                state,
                edge_index,
                ctx,
                space,
                query_node,
                parent_fetch_step_index,
                created_from_requires,
                response_path,
                fetch_path,
                requiring_fetch_step_index,
                cond,
            )
        if kind == EdgeKind.FIELD_MOVE:
            if edge.requirements != NONE and not requirements_resolve_in_place(
                graph, space, query_node
            ):
                return self.process_requires_field_edge(
                    store,
                    graph,
                    state,
                    ctx,
                    space,
                    query_node,
                    parent_fetch_step_index,
                    response_path,
                    requiring_fetch_step_index,
                    edge_index,
                    cond,
                    created_from_requires,
                )
            # Required fields we can get from here go into the same fetch as
            # the field.
            self.process_requirements_for_fetch_steps(
                store,
                graph,
                state,
                ctx,
                space,
                query_node,
                parent_fetch_step_index,
                requiring_fetch_step_index,
                cond,
                response_path,
                fetch_path,
            )
            return self.process_plain_field_edge(
                store,
                graph,
                state,
                ctx,
                space,
                query_node,
                parent_fetch_step_index,
                requiring_fetch_step_index,
                response_path,
                fetch_path,
                edge_index,
                cond,
                created_from_requires,
            )
        if kind == EdgeKind.SELFIE:
            return self.process_selfie_edge(
                store,
                graph,
                state,
                ctx,
                space,
                query_node,
                parent_fetch_step_index,
                requiring_fetch_step_index,
                response_path,
                fetch_path,
                edge.name,
                cond,
                created_from_requires,
            )
        if kind == EdgeKind.ABSTRACT_MOVE:
            return self.process_abstract_edge(
                store,
                graph,
                state,
                ctx,
                space,
                query_node,
                parent_fetch_step_index,
                requiring_fetch_step_index,
                response_path,
                fetch_path,
                edge.name,
                cond,
                created_from_requires,
            )
        return self.process_interface_object_type_move_edge(
            store,
            graph,
            state,
            ctx,
            space,
            query_node,
            parent_fetch_step_index,
            response_path,
            fetch_path,
            requiring_fetch_step_index,
            edge_index,
            edge.name,
            cond,
            created_from_requires,
        )


def build_fetch_graph(
    mut store: Store,
    graph: Graph,
    state: SupergraphState,
    ctx: PlannerOverrideContext,
    space: PlanSpace,
    root_tree: Int,
    operation: OperationDefinition,
) raises -> FetchGraph:
    """Build the fetch graph of a query tree, as upstream
    `build_fetch_graph_from_query_tree` before it optimizes the graph and
    collects the variable usages.

    Args:
        store: The store.
        graph: The planner graph.
        state: The supergraph.
        ctx: The override context.
        space: The plan space with the trees.
        root_tree: The root tree node, from `find_best_combination`.
        operation: The normalized operation.

    Returns:
        The fetch graph, with `root_index` set.

    Raises:
        Error: When a step cannot be built.
    """
    var builder = FetchGraphBuilder(operation.kind)
    builder.response_keys = ResponseKeys.from_operation(
        store, operation.selection_set
    )
    _ = builder.process_query_node(
        store,
        graph,
        state,
        ctx,
        space,
        root_tree,
        NONE,
        MergePath(),
        MergePath(),
        NONE,
        Cond.none(),
        False,
    )
    # Every step hangs under the no-op step of the root node, so the graph
    # has that one root step.
    builder.fetch_graph.root_index = builder.fetch_graph.roots()[0]
    return builder^.into_fetch_graph()

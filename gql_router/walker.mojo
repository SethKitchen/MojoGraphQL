# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The walk of an operation through the planner graph.

Port of Hive Router `1a29df9` `bin/router/src/query_planner/planner/walker/`:
`mod.rs`, `pathfinder.rs`, `best_path.rs`, `excluded.rs`, `utils.rs` and
`error.rs`.

`walk_operation` finds, for each leaf of the operation, the cheapest
paths from a root of the graph. A direct path moves by fields; an indirect
path also moves by entity calls, whose requirements are checked by the
same search.

**Differences from upstream.** Upstream keeps the requirements it has
visited as a set of `TypeAwareSelection` references. This port interns
each requirement by its type and its text, so two equal requirements of
different edges are one entry, as upstream equality has it.
"""

from gql_router.ast import NONE, Cond, ItemKind
from gql_router.federation_spec import OperationKind
from gql_router.graph import (
    EdgeKind,
    Graph,
    PlannerOverrideContext,
    satisfies_override_rules,
)
from gql_router.query_tree import OperationPath, PlanSpace
from gql_router.selection_set import set_text
from gql_router.store import Store
from gql_router.supergraph_state import DefinitionKind, SupergraphState


@fieldwise_init
struct Target(Copyable, Movable):
    """What a search moves to, as upstream `NavigationTarget`."""

    var field: Int
    """The field item, or `NONE` for a type target."""
    var type_name: Int
    """The type of a type target, as a symbol."""
    var cond: Cond
    """The condition of a type target."""
    var subgraph_ids: List[Int]
    """The subgraphs that resolve a field target."""
    var has_subgraph_ids: Bool
    """Whether `subgraph_ids` limits the search."""

    @staticmethod
    def for_field(field: Int) -> Target:
        """Return a field target with no subgraph limit.

        Args:
            field: The field item.

        Returns:
            The target.
        """
        return Target(field, NONE, Cond.none(), List[Int](), False)

    @staticmethod
    def for_type(type_name: Int, cond: Cond) -> Target:
        """Return a type target.

        Args:
            type_name: The type, as a symbol.
            cond: The condition.

        Returns:
            The target.
        """
        return Target(NONE, type_name, cond, List[Int](), False)

    def is_field(self) -> Bool:
        """Return True for a field target.

        Returns:
            Whether `field` is set.
        """
        return self.field != NONE


struct BestPathTracker(Movable):
    """The cheapest paths per subgraph, as upstream `BestPathTracker`."""

    var subgraphs: List[Int]
    """The subgraph names, as symbols, sorted by name."""
    var paths: List[List[OperationPath]]
    """The cheapest paths of each subgraph."""
    var costs: List[Int]
    """The cost of those paths."""

    def __init__(out self):
        """Start with no paths."""
        self.subgraphs = List[Int]()
        self.paths = List[List[OperationPath]]()
        self.costs = List[Int]()

    def add(
        mut self,
        graph: Graph,
        store: Store,
        space: PlanSpace,
        path: OperationPath,
    ):
        """Keep a path when it is as cheap as the best of its subgraph.

        Args:
            graph: The graph.
            store: The store with the names.
            space: The plan space.
            path: The path.
        """
        var subgraph = graph.nodes[space.tail(path)].subgraph
        var at = 0
        while at < len(self.subgraphs):
            if self.subgraphs[at] == subgraph:
                if path.cost < self.costs[at]:
                    self.costs[at] = path.cost
                    self.paths[at] = [path]
                elif path.cost == self.costs[at]:
                    self.paths[at].append(path)
                return
            if store.less(subgraph, self.subgraphs[at]):
                break
            at += 1
        self.subgraphs.insert(at, subgraph)
        self.paths.insert(at, [path])
        self.costs.insert(at, path.cost)

    def best_paths(self) -> List[OperationPath]:
        """Return the kept paths, by subgraph name.

        Returns:
            The paths.
        """
        var out = List[OperationPath]()
        for ref paths in self.paths:
            # Each subgraph keeps at least one path.
            var at = 0
            while at < len(paths):
                out.append(paths[at])
                at += 1
        return out^


def find_best_paths(paths: List[OperationPath]) -> List[OperationPath]:
    """Return the cheapest paths, as upstream `find_best_paths`.

    Args:
        paths: The paths.

    Returns:
        The paths of the lowest cost. Like upstream, a path of cost 0
        starts the search again.
    """
    var best = List[OperationPath]()
    var best_cost = 0
    for path in paths:
        if best_cost == 0:
            best_cost = path.cost
            best = [path]
        elif best_cost == path.cost:
            best.append(path)
        elif best_cost > path.cost:
            best_cost = path.cost
            best = [path]
    return best^


def pick_shared_paths(
    space: PlanSpace, tied: List[List[OperationPath]]
) -> List[OperationPath]:
    """Pick one path per requirement leaf, as upstream `pick_shared_paths`:
    on a tie, the path whose edges the most leaves use, the first one when
    that ties too.

    Args:
        space: The plan space.
        tied: The tied cheapest paths of each leaf.

    Returns:
        One path per leaf that has any.
    """
    var any_tie = False
    for paths in tied:
        if len(paths) > 1:
            any_tie = True
    var counts = Dict[Int, Int]()
    var leaf = 0
    while any_tie and leaf < len(tied):
        var edges = List[Int]()
        for path in tied[leaf]:
            for edge in space.edges_of(path):
                var seen = False
                for known in edges:
                    if known == edge:
                        seen = True
                        break
                if not seen:
                    edges.append(edge)
        for edge in edges:
            counts[edge] = counts.get(edge, 0) + 1
        leaf += 1
    var out = List[OperationPath]()
    for ref paths in tied:
        if len(paths) == 0:
            continue
        if len(paths) == 1:
            out.append(paths[0])
            continue
        var best = 0
        var best_score = -1
        var index = 0
        while index < len(paths):
            var score = 0
            for edge in space.edges_of(paths[index]):
                score += counts.get(edge, 0)
            if score > best_score:
                best_score = score
                best = index
            index += 1
        out.append(paths[best])
    return out^


@fieldwise_init
struct ResolvedOperation(Movable):
    """The best paths of each leaf, grouped by root field, as upstream
    `ResolvedOperation`."""

    var operation_kind: OperationKind
    """The operation kind."""
    var root_field_groups: List[List[List[OperationPath]]]
    """For each root field, the best paths of each of its leaves."""


def requirement_ids(graph: Graph, store: Store) -> List[Int]:
    """Intern the requirements of every edge by type and text.

    Args:
        graph: The graph.
        store: The store with the selections.

    Returns:
        For each edge, the id of its requirements, or `NONE`.
    """
    var ids = Dict[String, Int]()
    var out = List[Int]()
    var index = 0
    while index < len(graph.edges):
        ref edge = graph.edges[index]
        index += 1
        if edge.requirements == NONE:
            out.append(NONE)
            continue
        var key = store.name(edge.requirement_type) + set_text(
            store, edge.requirements
        )
        var found = ids.get(key)
        if found:
            out.append(found.value())
        else:
            var id = len(ids)
            ids[key^] = id
            out.append(id)
    return out^


@fieldwise_init
struct _MoveRequirement(Copyable, Movable):
    """A requirement selection and the paths it starts from."""

    var paths: Int
    """The index of the path list in the search."""
    var selection: Int
    """The selection item."""


def _same_field_identity(store: Store, a: Int, b: Int) -> Bool:
    """Return True for two fields of one name and the same arguments."""
    return (
        store.items[a].name == store.items[b].name
        and store.items[a].args == store.items[b].args
    )


def _contains(list: List[Int], value: Int) -> Bool:
    """Return True if a list holds a value."""
    for item in list:
        if item == value:
            return True
    return False


struct Walker(Movable):
    """The state of one walk, as upstream `PathSearch`."""

    var space: PlanSpace
    """The paths and trees of the plan."""
    var requirement_ids: List[Int]
    """The interned requirements of each edge."""
    var active_edge_checks: Dict[Int, Bool]
    """The `(tail, edge)` pairs whose requirements are being checked."""
    var typename_field: Int
    """A `__typename` field item, the upstream `FieldSelection::new_typename`.
    """

    def __init__(out self, var requirement_ids: List[Int], typename_field: Int):
        """Start a walker.

        Args:
            requirement_ids: The value of `requirement_ids` for the graph.
            typename_field: A `__typename` field item.
        """
        self.space = PlanSpace()
        self.requirement_ids = requirement_ids^
        self.active_edge_checks = Dict[Int, Bool]()
        self.typename_field = typename_field

    # --- helpers --------------------------------------------------------

    def _type_condition_matches(
        self, state: SupergraphState, current: Int, condition: Int
    ) -> Bool:
        """Return True if a type is the condition, or implements it."""
        if current == condition:
            return True
        var found = state.interface_to_object_types.get(condition)
        if not found:
            return False
        return _contains(found.value(), current)

    def _advance(
        mut self,
        graph: Graph,
        store: Store,
        path: OperationPath,
        edge: Int,
        requirement: Int,
        target: Target,
    ) -> OperationPath:
        """Advance a path toward a target."""
        return self.space.advance(
            graph, store, path, edge, requirement, target.field, target.cond
        )

    # --- direct paths ---------------------------------------------------

    def find_direct_paths(
        mut self,
        graph: Graph,
        store: Store,
        state: SupergraphState,
        ctx: PlannerOverrideContext,
        path: OperationPath,
        target: Target,
    ) raises -> List[OperationPath]:
        """Return the paths one move longer that reach a target, as
        upstream `find_direct_paths`.

        Args:
            graph: The graph.
            store: The store with the selections.
            state: The supergraph.
            ctx: The override context.
            path: The path.
            target: The target.

        Returns:
            The paths.

        Raises:
            Error: When a requirement search fails.
        """
        var out = List[OperationPath]()
        if not target.is_field() and not self.space.can_resolve_union_member(
            path, target.type_name
        ):
            return out^
        var name = target.type_name
        if target.is_field():
            name = store.items[target.field].name
        var edge = graph.first_out[self.space.tail(path)]
        while edge != NONE:
            ref found = graph.edges[edge]
            var matches: Bool
            if target.is_field():
                matches = (
                    found.kind == EdgeKind.FIELD_MOVE
                    or found.kind == EdgeKind.REENTRY_MOVE
                ) and found.name == name
            else:
                matches = (
                    found.kind == EdgeKind.ABSTRACT_MOVE
                    or found.kind == EdgeKind.INTERFACE_OBJECT_TYPE_MOVE
                ) and found.name == name
            if matches:
                var advanced = self._try_advance_direct_path(
                    graph, store, state, ctx, path, edge, target
                )
                if advanced:
                    out.append(advanced.value())
            edge = found.next_out
        return out^

    def _try_advance_direct_path(
        mut self,
        graph: Graph,
        store: Store,
        state: SupergraphState,
        ctx: PlannerOverrideContext,
        path: OperationPath,
        edge: Int,
        target: Target,
    ) raises -> Optional[OperationPath]:
        """Advance a path by an edge whose requirements are met."""
        var satisfied = self.can_satisfy_edge(
            graph,
            store,
            state,
            ctx,
            edge,
            path,
            List[Int](),
            List[Int](),
            False,
        )
        if not satisfied:
            return None
        var tree = self.space.tree_from_paths(graph, satisfied.value(), NONE)
        return self._advance(graph, store, path, edge, tree, target)

    def find_self_referencing_direct_path(
        mut self,
        graph: Graph,
        store: Store,
        state: SupergraphState,
        ctx: PlannerOverrideContext,
        path: OperationPath,
        type_name: Int,
        cond: Cond,
    ) raises -> OperationPath:
        """Return the path one selfie longer, as upstream
        `find_self_referencing_direct_path`.

        Args:
            graph: The graph.
            store: The store with the selections.
            state: The supergraph.
            ctx: The override context.
            path: The path.
            type_name: The type condition, as a symbol.
            cond: The condition.

        Returns:
            The path.

        Raises:
            Error: When there is no such path.
        """
        var edge = graph.first_out[self.space.tail(path)]
        while edge != NONE:
            ref found = graph.edges[edge]
            if found.kind == EdgeKind.SELFIE and found.name == type_name:
                # A selfie has no requirements, so it always advances.
                return self._try_advance_direct_path(
                    graph,
                    store,
                    state,
                    ctx,
                    path,
                    edge,
                    Target.for_type(type_name, cond),
                ).value()
            edge = found.next_out
        raise Error(
            "No paths found for selection item: " + store.name(type_name)
        )

    # --- indirect paths -------------------------------------------------

    def find_indirect_paths(
        mut self,
        graph: Graph,
        store: Store,
        state: SupergraphState,
        ctx: PlannerOverrideContext,
        path: OperationPath,
        target: Target,
        excluded_graphs: List[Int],
        excluded_requirements: List[Int],
    ) raises -> List[OperationPath]:
        """Return the cheapest paths to a target through entity calls, as
        upstream `find_indirect_paths`.

        Args:
            graph: The graph.
            store: The store with the selections.
            state: The supergraph.
            ctx: The override context.
            path: The path.
            target: The target.
            excluded_graphs: The subgraphs not to call, as name symbols.
            excluded_requirements: The requirement ids already visited.

        Returns:
            The cheapest paths, by subgraph.

        Raises:
            Error: When the path tail is a root, or a search fails.
        """
        var tracker = BestPathTracker()
        var seen = List[Int]()
        var tail_node = self.space.tail(path)
        var source_graph = graph.nodes[tail_node].subgraph
        if source_graph == NONE:
            raise Error("Tail node missing info")
        var current_type = graph.nodes[tail_node].name
        if not target.is_field() and not self.space.can_resolve_union_member(
            path, target.type_name
        ):
            return List[OperationPath]()
        var queue_graphs: List[List[Int]] = [excluded_graphs.copy()]
        var queue_requirements: List[List[Int]] = [excluded_requirements.copy()]
        var queue_paths: List[OperationPath] = [path]
        while len(queue_paths) > 0:
            var visited_graphs = queue_graphs.pop()
            var visited_requirements = queue_requirements.pop()
            var current = queue_paths.pop()
            var current_tail = self.space.tail(current)
            if _contains(seen, current_tail):
                continue
            seen.append(current_tail)
            var edge = graph.first_out[current_tail]
            while edge != NONE:
                ref found = graph.edges[edge]
                var next_edge = found.next_out
                if (
                    found.kind != EdgeKind.ENTITY_MOVE
                    and found.kind != EdgeKind.INTERFACE_OBJECT_TYPE_MOVE
                ):
                    edge = next_edge
                    continue
                ref edge_tail = graph.nodes[found.tail]
                var tail_graph = edge_tail.subgraph
                if target.has_subgraph_ids and not _contains(
                    target.subgraph_ids, edge_tail.subgraph_index
                ):
                    edge = next_edge
                    continue
                if _contains(visited_graphs, tail_graph):
                    edge = next_edge
                    continue
                if (
                    tail_graph == source_graph
                    and found.kind != EdgeKind.INTERFACE_OBJECT_TYPE_MOVE
                ):
                    edge = next_edge
                    continue
                # An entity move and a type move always have requirements.
                if (
                    target.is_field()
                    and self._requirements_depend_on_target_field(
                        store,
                        state,
                        current_type,
                        found.requirement_type,
                        found.requirements,
                        target.field,
                    )
                ):
                    edge = next_edge
                    continue
                # An entity move and a type move always have requirements.
                var requirement_id = self.requirement_ids[edge]
                if _contains(visited_requirements, requirement_id):
                    edge = next_edge
                    continue
                var new_graphs = visited_graphs.copy()
                new_graphs.append(tail_graph)
                var satisfied = self.can_satisfy_edge(
                    graph,
                    store,
                    state,
                    ctx,
                    edge,
                    current,
                    new_graphs,
                    visited_requirements,
                    False,
                )
                if not satisfied:
                    edge = next_edge
                    continue
                var tree = self.space.tree_from_paths(
                    graph, satisfied.value(), NONE
                )
                var next_path = self._advance(
                    graph, store, current, edge, tree, target
                )
                var direct = self.find_direct_paths(
                    graph, store, state, ctx, next_path, target
                )
                for direct_path in direct:
                    tracker.add(graph, store, self.space, direct_path)
                if len(direct) > 0:
                    edge = next_edge
                    continue
                var next_requirements = visited_requirements.copy()
                next_requirements.append(requirement_id)
                queue_graphs.append(new_graphs^)
                queue_requirements.append(next_requirements^)
                queue_paths.append(next_path)
                edge = next_edge
        return tracker.best_paths()

    # --- requirements ---------------------------------------------------

    def can_satisfy_edge(
        mut self,
        graph: Graph,
        store: Store,
        state: SupergraphState,
        ctx: PlannerOverrideContext,
        edge: Int,
        path: OperationPath,
        excluded_graphs: List[Int],
        excluded_requirements: List[Int],
        use_only_direct_edges: Bool,
    ) raises -> Optional[List[OperationPath]]:
        """Return the paths that satisfy an edge's requirements, as upstream
        `can_satisfy_edge`.

        Args:
            graph: The graph.
            store: The store with the selections.
            state: The supergraph.
            ctx: The override context.
            edge: The edge.
            path: The path the edge leaves.
            excluded_graphs: The subgraphs not to call.
            excluded_requirements: The requirement ids already visited.
            use_only_direct_edges: Whether to skip entity calls.

        Returns:
            The paths to the requirements, empty when there are none, or
            `None` when they cannot be met, or the edge is already being
            checked from this tail.

        Raises:
            Error: When a search fails.
        """
        var key = (self.space.tail(path) << 32) | edge
        if key in self.active_edge_checks:
            return None
        self.active_edge_checks[key] = True
        # Nothing below raises for a path that leaves a subgraph type, so
        # the check is always removed again. `walk_operation` also starts
        # from an empty set.
        var result = self._check_edge_requirements(
            graph,
            store,
            state,
            ctx,
            edge,
            path,
            excluded_graphs,
            excluded_requirements,
            use_only_direct_edges,
        )
        _ = self.active_edge_checks.pop(key)
        return result^

    def _check_edge_requirements(
        mut self,
        graph: Graph,
        store: Store,
        state: SupergraphState,
        ctx: PlannerOverrideContext,
        edge: Int,
        path: OperationPath,
        excluded_graphs: List[Int],
        excluded_requirements: List[Int],
        use_only_direct_edges: Bool,
    ) raises -> Optional[List[OperationPath]]:
        """Check the requirements of an edge, as upstream
        `check_edge_requirements`."""
        ref found = graph.edges[edge]
        if found.kind == EdgeKind.FIELD_MOVE and not satisfies_override_rules(
            store, found, ctx
        ):
            return None
        if found.requirements == NONE:
            return List[OperationPath]()
        var path_lists: List[List[OperationPath]] = [[path]]
        var queue = List[_MoveRequirement]()
        var child = store.items[found.requirements].first
        while child != NONE:
            queue.append(_MoveRequirement(0, child))
            child = store.items[child].next
        var tied = List[List[OperationPath]]()
        var head = 0
        while head < len(queue):
            var requirement = queue[head].copy()
            head += 1
            var selection = requirement.selection
            var paths = path_lists[requirement.paths].copy()
            var next_paths: List[OperationPath]
            if store.items[selection].kind == ItemKind.FIELD:
                next_paths = self._field_requirement_paths(
                    graph,
                    store,
                    state,
                    ctx,
                    paths,
                    selection,
                    excluded_graphs,
                    excluded_requirements,
                    use_only_direct_edges,
                )
                if len(next_paths) == 0:
                    return None
                if store.items[selection].first == NONE:
                    tied.append(find_best_paths(next_paths))
            else:
                # A normalized field set has fields and inline fragments.
                next_paths = self._fragment_requirement_paths(
                    graph,
                    store,
                    state,
                    ctx,
                    paths,
                    store.items[selection].name,
                    excluded_graphs,
                    excluded_requirements,
                )
                if len(next_paths) == 0:
                    return None
            if store.items[selection].first == NONE:
                continue
            var children = store.children(selection)
            path_lists.append(next_paths^)
            var index = len(children) - 1
            while index >= 0:
                queue.append(
                    _MoveRequirement(len(path_lists) - 1, children[index])
                )
                index -= 1
        # Every requirement ends in leaf fields, so `tied` has one entry per
        # leaf and each entry has paths.
        var best = pick_shared_paths(self.space, tied)
        var out = List[OperationPath]()
        var at = 0
        while at < len(best):
            out.append(self.space.requirement_continuation(path, best[at]))
            at += 1
        return out^

    def _field_requirement_paths(
        mut self,
        graph: Graph,
        store: Store,
        state: SupergraphState,
        ctx: PlannerOverrideContext,
        paths: List[OperationPath],
        field: Int,
        excluded_graphs: List[Int],
        excluded_requirements: List[Int],
        use_only_direct_edges: Bool,
    ) raises -> List[OperationPath]:
        """Return the paths to a required field, as upstream
        `validate_field_requirement`."""
        var target_ids = self.field_target_subgraph_ids(
            graph, store, state, field, paths
        )
        var is_leaf = store.items[field].first == NONE
        var direct_results = List[OperationPath]()
        var indirect_results = List[OperationPath]()
        var at = 0
        while at < len(paths):
            var path = paths[at]
            at += 1
            var direct = self.find_direct_paths(
                graph, store, state, ctx, path, Target.for_field(field)
            )
            var found_leaf = len(direct) > 0 and is_leaf
            for item in direct:
                direct_results.append(item)
            if not use_only_direct_edges and not found_leaf:
                var target = Target.for_field(field)
                if target_ids:
                    target.subgraph_ids = target_ids.value().copy()
                    target.has_subgraph_ids = True
                for item in self.find_indirect_paths(
                    graph,
                    store,
                    state,
                    ctx,
                    path,
                    target,
                    excluded_graphs,
                    excluded_requirements,
                ):
                    indirect_results.append(item)
        for item in indirect_results:
            direct_results.append(item)
        return direct_results^

    def _fragment_requirement_paths(
        mut self,
        graph: Graph,
        store: Store,
        state: SupergraphState,
        ctx: PlannerOverrideContext,
        paths: List[OperationPath],
        type_name: Int,
        excluded_graphs: List[Int],
        excluded_requirements: List[Int],
    ) raises -> List[OperationPath]:
        """Return the paths to a required type condition, as upstream
        `validate_fragment_requirement`."""
        # The paths of a requirement are never empty.
        var out = List[OperationPath]()
        var at = 0
        while at < len(paths):
            var path = paths[at]
            at += 1
            var current = graph.nodes[self.space.tail(path)].name
            if self._type_condition_matches(state, current, type_name):
                out.append(path)
            else:
                for item in self.find_direct_paths(
                    graph,
                    store,
                    state,
                    ctx,
                    path,
                    Target.for_type(type_name, Cond.none()),
                ):
                    out.append(item)
        at = 0
        while at < len(paths):
            for item in self.find_indirect_paths(
                graph,
                store,
                state,
                ctx,
                paths[at],
                Target.for_type(type_name, Cond.none()),
                excluded_graphs,
                excluded_requirements,
            ):
                out.append(item)
            at += 1
        return out^

    def field_target_subgraph_ids(
        self,
        graph: Graph,
        store: Store,
        state: SupergraphState,
        field: Int,
        paths: List[OperationPath],
    ) -> Optional[List[Int]]:
        """Return the subgraphs that resolve a field from the tails of
        paths, as upstream `field_target_subgraph_ids`.

        Args:
            graph: The graph.
            store: The store with the selections.
            state: The supergraph.
            field: The field item.
            paths: The paths.

        Returns:
            The sorted subgraph indices, or `None` when there are none.
        """
        var ids = Optional[List[Int]](None)
        var name = store.items[field].name
        for path in paths:
            var parent = graph.nodes[self.space.tail(path)].name
            var definition = state.definition(parent)
            if definition == NONE:
                continue
            var index = state.definitions[definition].field_index(name)
            if index == NONE:
                continue
            ref field_ids = (
                state.definitions[definition].fields[index].resolvable_in
            )
            if not ids:
                ids = field_ids.copy()
                continue
            var all_in = True
            for id in field_ids:
                if not _contains(ids.value(), id):
                    all_in = False
                    break
            if all_in:
                continue
            # `field_ids` has an id that `ids` lacks.
            var merged = ids.value().copy()
            var at = 0
            while at < len(field_ids):
                if not _contains(merged, field_ids[at]):
                    merged.append(field_ids[at])
                at += 1
            sort(merged)
            ids = merged^
        if ids and len(ids.value()) == 0:
            return None
        return ids^

    # --- requirement cycles ---------------------------------------------

    def _requirements_depend_on_target_field(
        self,
        store: Store,
        state: SupergraphState,
        current_type: Int,
        requirement_type: Int,
        requirements: Int,
        target_field: Int,
    ) -> Bool:
        """Return upstream `requirements_depend_on_target_field`."""
        if not self._type_condition_matches(
            state, current_type, requirement_type
        ):
            return False
        var child = store.items[requirements].first
        while child != NONE:
            if self._item_depends(
                store, state, current_type, child, target_field
            ):
                return True
            child = store.items[child].next
        return False

    def _item_depends(
        self,
        store: Store,
        state: SupergraphState,
        current_type: Int,
        requirement: Int,
        target_field: Int,
    ) -> Bool:
        """Return upstream `requirement_item_depends_on_target_field`."""
        ref item = store.items[requirement]
        if item.kind == ItemKind.FIELD:
            if not _same_field_identity(store, requirement, target_field):
                return False
            return self._sets_overlap(
                store, state, current_type, requirement, target_field
            )
        # A normalized field set has fields and inline fragments.
        if not self._type_condition_matches(state, current_type, item.name):
            return False
        var child = item.first
        while child != NONE:
            if self._item_depends(
                store, state, current_type, child, target_field
            ):
                return True
            child = store.items[child].next
        return False

    def _sets_overlap(
        self,
        store: Store,
        state: SupergraphState,
        current_type: Int,
        requirement: Int,
        target: Int,
    ) -> Bool:
        """Return upstream `selection_sets_overlap` of two items' children."""
        if (
            store.items[target].first == NONE
            or store.items[requirement].first == NONE
        ):
            return True
        var target_item = store.items[target].first
        while target_item != NONE:
            var requirement_item = store.items[requirement].first
            while requirement_item != NONE:
                if self._items_overlap(
                    store, state, current_type, requirement_item, target_item
                ):
                    return True
                requirement_item = store.items[requirement_item].next
            target_item = store.items[target_item].next
        return False

    def _items_overlap(
        self,
        store: Store,
        state: SupergraphState,
        current_type: Int,
        requirement: Int,
        target: Int,
    ) -> Bool:
        """Return upstream `selection_items_overlap`."""
        # An item is a field or an inline fragment: normalization inlines
        # every fragment spread.
        ref t = store.items[target]
        ref r = store.items[requirement]
        if t.kind == ItemKind.FIELD:
            if r.kind == ItemKind.FIELD:
                if _same_field_identity(store, target, requirement):
                    return self._sets_overlap(
                        store, state, current_type, target, requirement
                    )
                return False
            if not self._type_condition_matches(state, current_type, r.name):
                return False
            var inner = r.first
            while inner != NONE:
                if self._items_overlap(
                    store, state, current_type, inner, target
                ):
                    return True
                inner = store.items[inner].next
            return False
        if not self._type_condition_matches(state, current_type, t.name):
            return False
        if r.kind == ItemKind.FIELD:
            var inner = t.first
            while inner != NONE:
                if self._items_overlap(
                    store, state, current_type, requirement, inner
                ):
                    return True
                inner = store.items[inner].next
            return False
        if not self._type_condition_matches(state, current_type, r.name):
            return False
        return self._sets_overlap(
            store, state, current_type, requirement, target
        )

    # --- the walk -------------------------------------------------------

    def walk_operation(
        mut self,
        graph: Graph,
        store: Store,
        state: SupergraphState,
        ctx: PlannerOverrideContext,
        kind: OperationKind,
        selection_set: Int,
    ) raises -> ResolvedOperation:
        """Find the best paths of each leaf of an operation, as upstream
        `walk_operation`.

        Args:
            graph: The graph.
            store: The store with the selections.
            state: The supergraph.
            ctx: The override context.
            kind: The operation kind.
            selection_set: The operation's root selection set.

        Returns:
            The best paths of each leaf, by root field.

        Raises:
            Error: When the root is missing, or a selection has no path.
        """
        self.active_edge_checks.clear()
        # A root of the supergraph has an entrypoint into each subgraph
        # that resolves one of its fields.
        var entrypoints = graph.entrypoints(kind)
        var initial = List[OperationPath]()
        var at = 0
        while at < len(entrypoints):
            initial.append(
                self.space.new_entrypoint(graph, store, entrypoints[at])
            )
            at += 1
        var groups = List[List[List[OperationPath]]]()
        var root_item = store.items[selection_set].first
        while root_item != NONE:
            var stack_items: List[Int] = [root_item]
            var stack_paths: List[List[OperationPath]] = [initial.copy()]
            var per_leaf = List[List[OperationPath]]()
            while len(stack_items) > 0:
                var item = stack_items.pop()
                var paths = stack_paths.pop()
                var next_items = List[Int]()
                var next_paths = List[List[OperationPath]]()
                self._process_selection(
                    graph,
                    store,
                    state,
                    ctx,
                    item,
                    paths,
                    List[Int](),
                    next_items,
                    next_paths,
                    per_leaf,
                )
                var index = len(next_items) - 1
                while index >= 0:
                    stack_items.append(next_items[index])
                    stack_paths.append(next_paths[index].copy())
                    index -= 1
            groups.append(per_leaf^)
            root_item = store.items[root_item].next
        return ResolvedOperation(kind, groups^)

    def _process_selection(
        mut self,
        graph: Graph,
        store: Store,
        state: SupergraphState,
        ctx: PlannerOverrideContext,
        item: Int,
        paths: List[OperationPath],
        locally: List[Int],
        mut next_items: List[Int],
        mut next_paths: List[List[OperationPath]],
        mut per_leaf: List[List[OperationPath]],
    ) raises:
        """Resolve one selection, as upstream `process_selection`."""
        var kind = store.items[item].kind
        if kind == ItemKind.FRAGMENT:
            self._process_inline_fragment(
                graph,
                store,
                state,
                ctx,
                item,
                paths,
                locally,
                next_items,
                next_paths,
                per_leaf,
            )
        else:
            # Normalization inlines every fragment spread.
            self._process_field(
                graph,
                store,
                state,
                ctx,
                item,
                paths,
                locally,
                next_items,
                next_paths,
                per_leaf,
            )

    def _process_selection_set(
        mut self,
        graph: Graph,
        store: Store,
        state: SupergraphState,
        ctx: PlannerOverrideContext,
        set: Int,
        paths: List[OperationPath],
        locally: List[Int],
        mut next_items: List[Int],
        mut next_paths: List[List[OperationPath]],
        mut per_leaf: List[List[OperationPath]],
    ) raises:
        """Resolve each selection of a set, as upstream
        `process_selection_set`."""
        var child = store.items[set].first
        while child != NONE:
            self._process_selection(
                graph,
                store,
                state,
                ctx,
                child,
                paths,
                locally,
                next_items,
                next_paths,
                per_leaf,
            )
            child = store.items[child].next

    def _process_inline_fragment(
        mut self,
        graph: Graph,
        store: Store,
        state: SupergraphState,
        ctx: PlannerOverrideContext,
        fragment: Int,
        paths: List[OperationPath],
        locally: List[Int],
        mut next_items: List[Int],
        mut next_paths: List[List[OperationPath]],
        mut per_leaf: List[List[OperationPath]],
    ) raises:
        """Resolve an inline fragment, as upstream
        `process_inline_fragment`."""
        # The tail of an edge is always a subgraph type, so upstream's
        # "Expected a subgraph type" error cannot happen.
        var first_segment = paths[0].last_segment
        var tail = graph.edges[self.space.segments[first_segment].edge].tail
        var tail_type = graph.nodes[tail].name
        ref item = store.items[fragment]
        var type_condition = item.name
        var cond = Cond(item.skip, item.include)
        if tail_type == type_condition:
            if not cond.is_some():
                self._process_selection_set(
                    graph,
                    store,
                    state,
                    ctx,
                    fragment,
                    paths,
                    locally,
                    next_items,
                    next_paths,
                    per_leaf,
                )
                return
            var selfie_paths = List[OperationPath]()
            var at = 0
            while at < len(paths):
                selfie_paths.append(
                    self.find_self_referencing_direct_path(
                        graph,
                        store,
                        state,
                        ctx,
                        paths[at],
                        type_condition,
                        cond,
                    )
                )
                at += 1
            self._process_selection_set(
                graph,
                store,
                state,
                ctx,
                fragment,
                selfie_paths,
                locally,
                next_items,
                next_paths,
                per_leaf,
            )
            return
        var found = List[OperationPath]()
        var target = Target.for_type(type_condition, cond)
        var at = 0
        while at < len(paths):
            var path = paths[at]
            at += 1
            var direct = self.find_direct_paths(
                graph, store, state, ctx, path, target
            )
            if len(direct) > 0:
                found.append(direct[0])
            if len(locally) == 0:
                for indirect in self.find_indirect_paths(
                    graph,
                    store,
                    state,
                    ctx,
                    path,
                    target,
                    List[Int](),
                    List[Int](),
                ):
                    found.append(indirect)
        if len(found) == 0:
            var tracker = BestPathTracker()
            at = 0
            while at < len(paths):
                var direct = self.find_direct_paths(
                    graph,
                    store,
                    state,
                    ctx,
                    paths[at],
                    Target.for_field(self.typename_field),
                )
                at += 1
                if len(direct) == 0:
                    raise Error("No paths found for selection item: __typename")
                var index = 0
                while index < len(direct):
                    tracker.add(graph, store, self.space, direct[index])
                    index += 1
            # Each path added a path, so the tracker is not empty.
            per_leaf.append(find_best_paths(tracker.best_paths()))
            return
        self._process_selection_set(
            graph,
            store,
            state,
            ctx,
            fragment,
            found,
            locally,
            next_items,
            next_paths,
            per_leaf,
        )

    def _narrow_partial_union_paths(mut self, mut paths: List[OperationPath]):
        """Keep only the union members every subgraph resolves, as upstream
        `narrow_partial_union_paths`."""
        if len(paths) <= 1 or paths[0].union_context == NONE:
            return
        # From here on, there are at least two paths and two members lists.
        var first = paths[0].union_context
        var at = 0
        while at < len(paths):
            var union_context = paths[at].union_context
            at += 1
            if union_context == NONE:
                return
            ref context = self.space.unions[union_context]
            if (
                context.parent_type_name
                != self.space.unions[first].parent_type_name
                or context.field_name != self.space.unions[first].field_name
            ):
                return
        var graphs = List[Int]()
        var members = List[List[Int]]()
        at = 0
        while at < len(paths):
            ref context = self.space.unions[paths[at].union_context]
            at += 1
            if not _contains(graphs, context.graph_id):
                graphs.append(context.graph_id)
                members.append(context.possible_members.copy())
        if len(graphs) <= 1:
            return
        var least = 0
        var index = 1
        while index < len(members):
            if len(members[index]) < len(members[least]):
                least = index
            index += 1
        var shared = members[least].copy()
        index = 0
        while index < len(members):
            var kept = List[Int]()
            for member in shared:
                if _contains(members[index], member):
                    kept.append(member)
            shared = kept^
            if len(shared) == 0:
                paths.clear()
                return
            index += 1
        var out = List[OperationPath]()
        at = 0
        while at < len(paths):
            var path = paths[at]
            at += 1
            var context = self.space.unions[path.union_context].copy()
            if not _contains(shared, context.member_name):
                continue
            context.possible_members = shared.copy()
            self.space.unions.append(context^)
            var narrowed = path
            narrowed.union_context = len(self.space.unions) - 1
            out.append(narrowed)
        paths = out^

    def _process_field(
        mut self,
        graph: Graph,
        store: Store,
        state: SupergraphState,
        ctx: PlannerOverrideContext,
        field: Int,
        paths: List[OperationPath],
        locally: List[Int],
        mut next_items: List[Int],
        mut next_paths: List[List[OperationPath]],
        mut per_leaf: List[List[OperationPath]],
    ) raises:
        """Resolve a field, as upstream `process_field`."""
        var tracker = BestPathTracker()
        var name = store.items[field].name
        var is_leaf = store.items[field].first == NONE
        var resolve_locally = _contains(locally, name)
        # A field always comes with paths to its parent.
        var target_ids = Optional[List[Int]](None)
        if not resolve_locally:
            target_ids = self.field_target_subgraph_ids(
                graph, store, state, field, paths
            )
        var at = 0
        while at < len(paths):
            var path = paths[at]
            at += 1
            var direct = self.find_direct_paths(
                graph, store, state, ctx, path, Target.for_field(field)
            )
            var found_leaf = len(direct) > 0 and is_leaf
            for direct_path in direct:
                tracker.add(graph, store, self.space, direct_path)
            if not resolve_locally and not found_leaf:
                var target = Target.for_field(field)
                if target_ids:
                    target.subgraph_ids = target_ids.value().copy()
                    target.has_subgraph_ids = True
                for indirect in self.find_indirect_paths(
                    graph,
                    store,
                    state,
                    ctx,
                    path,
                    target,
                    List[Int](),
                    List[Int](),
                ):
                    tracker.add(graph, store, self.space, indirect)
        var found = tracker.best_paths()
        self._narrow_partial_union_paths(found)
        if len(found) == 0:
            raise Error(
                "No paths found for selection item: " + store.name(name)
            )
        var fields_locally = List[Int]()
        if not is_leaf:
            fields_locally = self._fields_to_resolve_locally(
                graph, store, state, field, found
            )
        if len(fields_locally) > 0:
            var valid = List[OperationPath]()
            at = 0
            while at < len(found):
                var candidate = found[at]
                at += 1
                var resolvable = True
                var child = store.items[field].first
                while child != NONE:
                    var child_items = List[Int]()
                    var child_paths = List[List[OperationPath]]()
                    var child_leaves = List[List[OperationPath]]()
                    try:
                        self._process_selection(
                            graph,
                            store,
                            state,
                            ctx,
                            child,
                            [candidate],
                            fields_locally,
                            child_items,
                            child_paths,
                            child_leaves,
                        )
                    except:
                        resolvable = False
                        break
                    if len(child_items) == 0 and len(child_leaves) == 0:
                        resolvable = False
                        break
                    child = store.items[child].next
                if resolvable:
                    valid.append(candidate)
            found = valid^
            # Only a field with a selection set resolves fields locally.
            if len(found) == 0:
                raise Error(
                    "No paths found for selection item: " + store.name(name)
                )
        if is_leaf:
            per_leaf.append(find_best_paths(found))
            return
        var child = store.items[field].first
        while child != NONE:
            next_items.append(child)
            next_paths.append(found.copy())
            child = store.items[child].next

    def _fields_to_resolve_locally(
        self,
        graph: Graph,
        store: Store,
        state: SupergraphState,
        field: Int,
        paths: List[OperationPath],
    ) raises -> List[Int]:
        """Return the fields of an interface to resolve in one subgraph,
        when a shared field selects more than one type condition."""
        var name = store.items[field].name
        var at = 0
        while at < len(paths):
            var edge = self.space.segments[paths[at].last_segment].edge
            at += 1
            if graph.edges[edge].kind != EdgeKind.FIELD_MOVE:
                continue
            var parent_type = graph.nodes[graph.edges[edge].head].name
            var parent = state.definition(parent_type)
            if parent == NONE:
                raise Error(
                    "Type Definition of '"
                    + store.name(parent_type)
                    + "' not found in Supergraph"
                )
            var index = state.definitions[parent].field_index(name)
            if index == NONE:
                raise Error(
                    "Field '"
                    + store.name(name)
                    + "' not found in type '"
                    + store.name(parent_type)
                    + "'"
                )
            var output_type = graph.nodes[graph.edges[edge].tail].name
            var output = state.definition(output_type)
            if output == NONE:
                raise Error(
                    "Type Definition of '"
                    + store.name(output_type)
                    + "' not found in Supergraph"
                )
            var fragments = 0
            var child = store.items[field].first
            while child != NONE:
                if store.items[child].kind == ItemKind.FRAGMENT:
                    fragments += 1
                child = store.items[child].next
            var out = List[Int]()
            if (
                state.definitions[output].kind == DefinitionKind.INTERFACE
                and len(state.definitions[parent].fields[index].resolvable_in)
                > 1
                and fragments > 1
            ):
                # An interface has at least one field.
                ref fields = state.definitions[output].fields
                var index_out = 0
                while index_out < len(fields):
                    out.append(fields[index_out].name)
                    index_out += 1
            return out^
        return List[Int]()

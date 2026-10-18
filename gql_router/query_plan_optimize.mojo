# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Query plan rewrites: nested sequences are inlined, adjacent conditions
merge, and entity fetches to one subgraph in a parallel node become one
`BatchFetch`.

Port of Hive Router `1a29df9`
`bin/router/src/query_planner/planner/query_plan/optimize.rs`.

**Differences from upstream.** Upstream groups fetch shapes by a hash key
and then compares the full values. This port compares the full values
that the key stands for: the order-independent shape (`semantic_eq`) and
the ordered selections. The outcome is the same, except for hash
collisions. The error for a flatten node that does not wrap a fetch names
the node kind, not the Rust `Debug` form of the node.
"""

from gql_router.ast import NONE, ItemKind, ValueKind
from gql_router.federation_spec import OperationKind
from gql_router.fetch_operation import (
    FetchDocument,
    FragmentDefinition,
    PlanningFetchOperation,
    inline_fragment_spreads,
)
from gql_router.fetch_step import FetchRewrite
from gql_router.minification import minify_operation
from gql_router.operation import OperationDefinition, VariableDefinition
from gql_router.plan_nodes import (
    BatchFetchNode,
    EntityBatchAlias,
    FlattenNodePath,
    PlanNodeKind,
    QueryPlan,
    representations_type,
    variable_args,
)
from gql_router.selection_set import entities_field, semantic_eq, sets_equal
from gql_router.store import Store
from gql_router.supergraph_state import SupergraphState


def rewrites_equal(
    has_a: Bool, a: List[FetchRewrite], has_b: Bool, b: List[FetchRewrite]
) -> Bool:
    """Return upstream `Option<Vec<FetchRewrite>>` equality.

    Args:
        has_a: Whether the first list is some.
        a: The first list.
        has_b: Whether the second list is some.
        b: The second list.

    Returns:
        Whether both are none, or both are equal lists.
    """
    if has_a != has_b:
        return False
    if len(a) != len(b):
        return False
    var index = 0
    while index < len(a):
        if a[index] != b[index]:
            return False
        index += 1
    return True


def _hash_eq(store: Store, a: Int, b: Int) -> Bool:
    """Return True if two sets are equal as a key of a Rust `HashMap`:
    equal upstream `Hash` (names, aliases, arguments, in order) and equal
    upstream `PartialEq` (`sets_equal`)."""
    return sets_equal(store, a, b) and _same_keys(store, a, b)


def _same_keys(store: Store, a: Int, b: Int) -> Bool:
    """Return True if two sets that are `sets_equal` also have the same
    aliases and arguments at every depth. `sets_equal` has checked the
    count, kinds and names of the items."""
    var x = store.items[a].first
    var y = store.items[b].first
    while x != NONE:
        ref left = store.items[x]
        ref right = store.items[y]
        if left.kind == ItemKind.FIELD and (
            left.alias != right.alias or left.args != right.args
        ):
            return False
        if not _same_keys(store, x, y):
            return False
        x = left.next
        y = right.next
    return True


def representations_variable_name(store: Store, field: Int) -> Int:
    """Return the variable of a field's `representations` argument, as
    upstream `representations_variable_name`.

    Args:
        store: The store.
        field: The field.

    Returns:
        The variable, as a symbol, or `NONE` when the argument is missing
        or is not a variable.
    """
    var name = store.find_sym("representations")
    if name == NONE:
        return NONE
    var value = store.arg_value(store.items[field].args, name)
    if value == NONE or store.values[value].kind != ValueKind.VARIABLE:
        return NONE
    return store.values[value].text


struct EntityFetch(Copyable, Movable):
    """One entity fetch that can join a batch, as upstream
    `EntityFetch`."""

    var index: Int
    """The position in the parallel node."""
    var fetch_node_id: Int
    """The fetch id."""
    var service_name: Int
    """The subgraph name, as a symbol."""
    var flatten_path: FlattenNodePath
    """The response path."""
    var variable_usages: List[Int]
    """The variables the fetch uses."""
    var has_variable_usages: Bool
    """False when upstream `variable_usages` is `None`."""
    var requires: Int
    """The representations selection, spreads inlined."""
    var entities_selection: Int
    """The `_entities` selections, spreads inlined."""
    var input_rewrites: List[FetchRewrite]
    """The input rewrites."""
    var has_input_rewrites: Bool
    """False when upstream `input_rewrites` is `None`."""
    var output_rewrites: List[FetchRewrite]
    """The output rewrites."""
    var has_output_rewrites: Bool
    """False when upstream `output_rewrites` is `None`."""
    var non_representations_variable_definitions: List[VariableDefinition]
    """The variables of the operation, without the representations one."""

    def __init__(out self, index: Int, fetch_node_id: Int, service_name: Int):
        """Start a candidate with no selections.

        Args:
            index: The position in the parallel node.
            fetch_node_id: The fetch id.
            service_name: The subgraph name.
        """
        self.index = index
        self.fetch_node_id = fetch_node_id
        self.service_name = service_name
        self.flatten_path = FlattenNodePath()
        self.variable_usages = List[Int]()
        self.has_variable_usages = False
        self.requires = NONE
        self.entities_selection = NONE
        self.input_rewrites = List[FetchRewrite]()
        self.has_input_rewrites = False
        self.output_rewrites = List[FetchRewrite]()
        self.has_output_rewrites = False
        self.non_representations_variable_definitions = List[
            VariableDefinition
        ]()

    def eq_shape(self, store: Store, right: Self) -> Bool:
        """Return True if two candidates have one shape, as upstream
        `eq_shape` after its hash key matched.

        Args:
            store: The store.
            right: Another candidate.

        Returns:
            Whether requires, selections and rewrites are equal.
        """
        return (
            semantic_eq(store, self.requires, right.requires)
            and semantic_eq(
                store, self.entities_selection, right.entities_selection
            )
            and sets_equal(store, self.requires, right.requires)
            and sets_equal(
                store, self.entities_selection, right.entities_selection
            )
            and rewrites_equal(
                self.has_input_rewrites,
                self.input_rewrites,
                right.has_input_rewrites,
                right.input_rewrites,
            )
            and rewrites_equal(
                self.has_output_rewrites,
                self.output_rewrites,
                right.has_output_rewrites,
                right.output_rewrites,
            )
        )


def entity_fetch_from_node(
    mut store: Store, plan: QueryPlan, index: Int, node: Int
) raises -> Optional[EntityFetch]:
    """Read a `Flatten(Fetch)` entity call, as upstream
    `EntityFetch::from_node`.

    Args:
        store: The store.
        plan: The plan.
        index: The position in the parallel node.
        node: The node.

    Returns:
        The candidate, or none for another node.

    Raises:
        Error: `Fragment expansion error: ...` for a bad spread.
    """
    if plan.nodes[node].kind != PlanNodeKind.FLATTEN:
        return None
    var child = plan.nodes[node].node
    if plan.nodes[child].kind != PlanNodeKind.FETCH:
        return None
    ref fetch = plan.fetches[plan.nodes[child].fetch]
    ref document = fetch.operation.document
    var field = entities_field(store, document.operation.selection_set)
    if field == NONE:
        return None
    var representations_var = representations_variable_name(store, field)
    if representations_var == NONE:
        return None
    if fetch.planner_requires == NONE:
        return None
    var out = EntityFetch(index, fetch.id, fetch.service_name)
    try:
        out.requires = inline_fragment_spreads(
            store, fetch.planner_requires, document.fragments
        )
        out.entities_selection = inline_fragment_spreads(
            store, field, document.fragments
        )
    except error:
        raise Error("Fragment expansion error: " + String(error))
    out.flatten_path = plan.nodes[node].path.copy()
    out.variable_usages = fetch.variable_usages.copy()
    out.has_variable_usages = fetch.has_variable_usages
    out.input_rewrites = fetch.input_rewrites.copy()
    out.has_input_rewrites = fetch.has_input_rewrites
    out.output_rewrites = fetch.output_rewrites.copy()
    out.has_output_rewrites = fetch.has_output_rewrites
    # The variables have `$representations`, so the list is never empty.
    ref variables = document.operation.variables
    var at = 0
    while at < len(variables):
        if variables[at].name != representations_var:
            out.non_representations_variable_definitions.append(
                variables[at].copy()
            )
        at += 1
    return out^


@fieldwise_init
struct VariableCompatibleGroup(Copyable, Movable):
    """Candidates that can share their variables, as upstream
    `VariableCompatibleGroup`."""

    var candidates: List[EntityFetch]
    """The candidates."""
    var variables: List[VariableDefinition]
    """The union of their variables."""


def can_merge_variable_definitions(
    store: Store,
    merged_variables: List[VariableDefinition],
    other_variables: List[VariableDefinition],
) -> Bool:
    """Return True if no variable of one list conflicts with the other, as
    upstream `can_merge_variable_definitions`.

    Args:
        store: The store with the values.
        merged_variables: The variables so far.
        other_variables: The new variables.

    Returns:
        Whether each shared name has one type and one default value.
    """
    for other in other_variables:
        for existing in merged_variables:
            if existing.name == other.name:
                if not existing.can_merge(store, other):
                    return False
                break
    return True


def merge_variable_definitions(
    mut merged_variables: List[VariableDefinition],
    other_variables: List[VariableDefinition],
):
    """Add the variables with a new name, as upstream
    `merge_variable_definitions`.

    Args:
        merged_variables: The variables so far.
        other_variables: The new variables.
    """
    for variable in other_variables:
        var seen = False
        for existing in merged_variables:
            if existing.name == variable.name:
                seen = True
                break
        if not seen:
            merged_variables.append(variable.copy())


def partition_by_variables_compatibility(
    store: Store, var candidates: List[EntityFetch]
) -> List[VariableCompatibleGroup]:
    """Put each candidate in the first group whose variables it can share,
    as upstream `partition_by_variables_compatibility`.

    Args:
        store: The store with the values.
        candidates: The candidates, in node order.

    Returns:
        The groups, in creation order.
    """
    var groups = List[VariableCompatibleGroup]()
    for candidate in candidates:
        ref variables = candidate.non_representations_variable_definitions
        var chosen = NONE
        for index in range(len(groups)):
            if can_merge_variable_definitions(
                store, groups[index].variables, variables
            ):
                chosen = index
                break
        if chosen != NONE:
            merge_variable_definitions(groups[chosen].variables, variables)
            groups[chosen].candidates.append(candidate.copy())
            continue
        groups.append(
            VariableCompatibleGroup([candidate.copy()], variables.copy())
        )
    return groups^


def partition_by_shape(
    store: Store, var candidates: List[EntityFetch]
) -> List[List[EntityFetch]]:
    """Group candidates of one shape, in first-seen order, as upstream
    `partition_by_shape`.

    Args:
        store: The store.
        candidates: The candidates.

    Returns:
        The groups.
    """
    var groups = List[List[EntityFetch]]()
    for candidate in candidates:
        var placed = False
        for index in range(len(groups)):
            if groups[index][0].eq_shape(store, candidate):
                groups[index].append(candidate.copy())
                placed = True
                break
        if not placed:
            groups.append([candidate.copy()])
    return groups^


def next_unique_representations_var_name(
    mut store: Store, mut used_variable_names: List[Int], mut next_index: Int
) -> Int:
    """Return the next free `__batch_reps_N` name, as upstream
    `next_unique_representations_var_name`.

    Args:
        store: The store for the name.
        used_variable_names: The names in use, as symbols; the new name is
            added.
        next_index: The next number to try; it advances.

    Returns:
        The name, as a symbol.
    """
    while True:
        var name = store.sym("__batch_reps_" + String(next_index))
        next_index += 1
        var used = False
        for known in used_variable_names:
            if known == name:
                used = True
                break
        if not used:
            used_variable_names.append(name)
            return name


def _paths_equal(a: List[FlattenNodePath], b: List[FlattenNodePath]) -> Bool:
    """Return True if two lists of paths are equal."""
    if len(a) != len(b):
        return False
    var index = 0
    while index < len(a):
        if a[index] != b[index]:
            return False
        index += 1
    return True


@fieldwise_init
struct _RepresentationsKey(Copyable, Movable):
    """Upstream `RepresentationsInputKey` and the variable it names."""

    var requires: Int
    """The representations selection."""
    var input_rewrites: List[FetchRewrite]
    """The input rewrites."""
    var has_input_rewrites: Bool
    """False when upstream `input_rewrites` is `None`."""
    var merge_paths: List[FlattenNodePath]
    """The response paths."""
    var name: Int
    """The representations variable, as a symbol."""


struct BatchFetchBuilder(Movable):
    """Builds one `BatchFetch`, as upstream `BatchFetchBuilder`."""

    var merged_non_representation_variables: List[VariableDefinition]
    """The variables the batched fetches share."""
    var operation_variable_definitions: List[VariableDefinition]
    """The variables of the batched operation."""
    var operation_selection_items: List[Int]
    """The `_entities` fields of the batched operation."""
    var batched_aliases: List[EntityBatchAlias]
    """The aliases."""
    var used_variable_names: List[Int]
    """The variable names in use, as symbols."""
    var representations_var_index: Int
    """The next `__batch_reps_N` number."""
    var variable_usages: List[Int]
    """The variables the fetches use, sorted by name."""
    var representations_var_by_input_key: List[_RepresentationsKey]
    """The representations variable of each input, in creation order."""

    def __init__(
        out self, merged_non_representation_variables: List[VariableDefinition]
    ):
        """Start a builder.

        Args:
            merged_non_representation_variables: The shared variables.
        """
        self.merged_non_representation_variables = (
            merged_non_representation_variables.copy()
        )
        self.operation_variable_definitions = List[VariableDefinition]()
        self.operation_selection_items = List[Int]()
        self.batched_aliases = List[EntityBatchAlias]()
        self.used_variable_names = List[Int]()
        for variable in merged_non_representation_variables:
            self.used_variable_names.append(variable.name)
        self.representations_var_index = 0
        self.variable_usages = List[Int]()
        self.representations_var_by_input_key = List[_RepresentationsKey]()

    def add_shape_group(
        mut self,
        mut store: Store,
        alias_index: Int,
        shape_group: List[EntityFetch],
    ) raises:
        """Add one alias for a group of one shape, as upstream
        `add_shape_group`.

        Args:
            store: The store.
            alias_index: The alias number.
            shape_group: The candidates of the group.

        Raises:
            Error: When the group is empty.
        """
        if len(shape_group) == 0:
            raise Error(
                "Internal Error: Batched entities shape group cannot be empty"
            )
        ref representative = shape_group[0]
        var index = 0
        while index < len(shape_group):
            ref usages = shape_group[index].variable_usages
            index += 1
            var at = 0
            while at < len(usages):
                _insert_sorted(store, self.variable_usages, usages[at])
                at += 1
        var alias = store.sym("_e" + String(alias_index))
        var merge_paths = List[FlattenNodePath]()
        index = 0
        while index < len(shape_group):
            ref candidate = shape_group[index]
            index += 1
            var seen = False
            for known in merge_paths:
                if known == candidate.flatten_path:
                    seen = True
                    break
            if not seen:
                merge_paths.append(candidate.flatten_path.copy())
        var representations = self._get_or_create_representations_var(
            store, representative, merge_paths
        )
        var field = store.add_item(
            ItemKind.FIELD,
            store.sym("_entities"),
            alias=alias,
            args=variable_args(store, "representations", representations),
        )
        var copy = store.copy_set(representative.entities_selection)
        store.set_children(field, store.children(copy))
        self.operation_selection_items.append(field)
        self.batched_aliases.append(
            EntityBatchAlias(
                alias,
                representations,
                merge_paths^,
                representative.requires,
                representative.input_rewrites.copy(),
                representative.has_input_rewrites,
                representative.output_rewrites.copy(),
                representative.has_output_rewrites,
            )
        )

    def _get_or_create_representations_var(
        mut self,
        mut store: Store,
        representative: EntityFetch,
        merge_paths: List[FlattenNodePath],
    ) -> Int:
        """Return the representations variable of an input, as upstream
        `get_or_create_representations_var`."""
        for key in self.representations_var_by_input_key:
            if (
                _hash_eq(store, key.requires, representative.requires)
                and rewrites_equal(
                    key.has_input_rewrites,
                    key.input_rewrites,
                    representative.has_input_rewrites,
                    representative.input_rewrites,
                )
                and _paths_equal(key.merge_paths, merge_paths)
            ):
                return key.name
        var name = next_unique_representations_var_name(
            store, self.used_variable_names, self.representations_var_index
        )
        self.operation_variable_definitions.append(
            VariableDefinition(name, representations_type(store), NONE)
        )
        self.representations_var_by_input_key.append(
            _RepresentationsKey(
                representative.requires,
                representative.input_rewrites.copy(),
                representative.has_input_rewrites,
                merge_paths.copy(),
                name,
            )
        )
        return name

    def finish(
        mut self,
        mut store: Store,
        first_candidate: EntityFetch,
        state: SupergraphState,
    ) raises -> BatchFetchNode:
        """Make the batch fetch, as upstream `finish`.

        Args:
            store: The store.
            first_candidate: The first candidate of the first group.
            state: The supergraph.

        Returns:
            The batch fetch node.

        Raises:
            Error: When minification fails.
        """
        for variable in self.merged_non_representation_variables:
            self.operation_variable_definitions.append(variable.copy())
        var set = store.new_set()
        var index = 0
        while index < len(self.operation_selection_items):
            store.append(set, self.operation_selection_items[index])
            index += 1
        var operation = OperationDefinition(OperationKind.QUERY, set)
        operation.variables = self.operation_variable_definitions.copy()
        operation.has_variables = True
        var document: FetchDocument
        try:
            document = minify_operation(store, operation^, state)
        except error:
            raise Error(
                "Internal Error: Failed to minify batched entities operation: "
                + String(error)
            )
        return BatchFetchNode(
            first_candidate.fetch_node_id,
            first_candidate.service_name,
            self.variable_usages.copy(),
            len(self.variable_usages) > 0,
            OperationKind.QUERY,
            PlanningFetchOperation(document^, store),
            self.batched_aliases.copy(),
        )


def _insert_sorted(store: Store, mut out: List[Int], name: Int):
    """Insert a symbol into a name-sorted list, once."""
    for known in out:
        if known == name:
            return
    var at = len(out)
    while at > 0 and store.less(name, out[at - 1]):
        at -= 1
    out.insert(at, name)


def build_batched_fetch_node(
    mut store: Store,
    shape_groups: List[List[EntityFetch]],
    merged_non_representation_variables: List[VariableDefinition],
    state: SupergraphState,
) raises -> BatchFetchNode:
    """Make one batch fetch with one alias per shape group, as upstream
    `build_batched_fetch_node`.

    Args:
        store: The store.
        shape_groups: The groups.
        merged_non_representation_variables: The shared variables.
        state: The supergraph.

    Returns:
        The batch fetch node.

    Raises:
        Error: When there is no candidate, or minification fails.
    """
    if len(shape_groups) == 0 or len(shape_groups[0]) == 0:
        raise Error("Internal Error: Batched entities candidates were empty")
    var builder = BatchFetchBuilder(merged_non_representation_variables)
    var index = 0
    while index < len(shape_groups):
        builder.add_shape_group(store, index, shape_groups[index])
        index += 1
    return builder.finish(store, shape_groups[0][0], state)


def partition_by_subgraph(
    mut store: Store, plan: QueryPlan, nodes: List[Int]
) raises -> List[List[EntityFetch]]:
    """Group the entity fetch candidates of a parallel node by subgraph,
    as upstream `partition_by_subgraph`.

    Args:
        store: The store.
        plan: The plan.
        nodes: The children of the parallel node.

    Returns:
        One list per subgraph, in first-seen order. Upstream iterates a
        `HashMap`; the order does not change the result.

    Raises:
        Error: For a bad fragment spread.
    """
    var groups = List[List[EntityFetch]]()
    var services = List[Int]()
    var index = 0
    while index < len(nodes):
        var candidate = entity_fetch_from_node(store, plan, index, nodes[index])
        index += 1
        if not candidate:
            continue
        var found = candidate.take()
        var at = NONE
        for position in range(len(services)):
            if services[position] == found.service_name:
                at = position
                break
        if at == NONE:
            services.append(found.service_name)
            groups.append(List[EntityFetch]())
            at = len(groups) - 1
        groups[at].append(found^)
    return groups^


def optimize_parallel_node(
    mut store: Store,
    mut plan: QueryPlan,
    nodes: List[Int],
    state: SupergraphState,
) raises -> List[Int]:
    """Merge the entity fetches of a parallel node into `BatchFetch` nodes,
    as upstream `optimize_parallel_node`.

    Args:
        store: The store.
        plan: The plan.
        nodes: The children of the parallel node.
        state: The supergraph.

    Returns:
        The children: each batch at the place of its first fetch, and the
        other fetches of the batch removed.

    Raises:
        Error: For a bad fragment spread, or when minification fails.
    """
    var replacements = List[Int](length=len(nodes), fill=NONE)
    var removed = List[Bool](length=len(nodes), fill=False)
    var replaced = False
    for candidates in partition_by_subgraph(store, plan, nodes):
        if len(candidates) < 2:
            continue
        # At least two candidates make at least one group, and the shape
        # groups of a group of two or more are never empty.
        var groups = partition_by_variables_compatibility(
            store, candidates.copy()
        )
        var at = 0
        while at < len(groups):
            ref group = groups[at]
            at += 1
            if len(group.candidates) < 2:
                continue
            var shape_groups = partition_by_shape(
                store, group.candidates.copy()
            )
            var first_index = shape_groups[0][0].index
            var batch = build_batched_fetch_node(
                store, shape_groups, group.variables, state
            )
            replacements[first_index] = plan.add_batch_fetch(batch^)
            replaced = True
            var shape = 0
            while shape < len(shape_groups):
                ref shape_group = shape_groups[shape]
                shape += 1
                var member = 0
                while member < len(shape_group):
                    var candidate_index = shape_group[member].index
                    member += 1
                    if candidate_index != first_index:
                        removed[candidate_index] = True
    if not replaced:
        return nodes.copy()
    var out = List[Int]()
    var index = 0
    while index < len(nodes):
        var current = index
        index += 1
        if replacements[current] != NONE:
            out.append(replacements[current])
            continue
        if removed[current]:
            continue
        out.append(nodes[current])
    return out^


def optimize_plan_sequence(mut plan: QueryPlan, nodes: List[Int]) -> List[Int]:
    """Inline nested sequences and merge adjacent compatible conditions, as
    upstream `optimize_plan_sequence`.

    Args:
        plan: The plan.
        nodes: The children of a sequence.

    Returns:
        The new children.
    """
    var flattened = List[Int]()
    var index = 0
    while index < len(nodes):
        var node = nodes[index]
        index += 1
        if plan.nodes[node].kind == PlanNodeKind.SEQUENCE:
            flattened.extend(plan.nodes[node].nodes.copy())
        else:
            flattened.append(node)
    var out = List[Int]()
    index = 0
    while index < len(flattened):
        var node = flattened[index]
        index += 1
        if (
            len(out) > 0
            and plan.nodes[out[len(out) - 1]].kind == PlanNodeKind.CONDITION
            and plan.nodes[node].kind == PlanNodeKind.CONDITION
            and plan.can_merge_with(out[len(out) - 1], node)
        ):
            plan.merge_condition(out[len(out) - 1], node)
            continue
        out.append(node)
    return out^


def optimize_top_level_sequence(
    mut plan: QueryPlan, nodes: List[Int]
) -> List[Int]:
    """Run the light top-level normalization, as upstream
    `optimize_top_level_sequence`.

    Args:
        plan: The plan.
        nodes: The top-level waves.

    Returns:
        The new waves.
    """
    return optimize_plan_sequence(plan, nodes)


def optimize_root_node(
    mut store: Store, mut plan: QueryPlan, node: Int, state: SupergraphState
) raises -> Int:
    """Run every rewrite on a plan node, as upstream `optimize_root_node`.

    Args:
        store: The store.
        plan: The plan.
        node: The root node.
        state: The supergraph.

    Returns:
        The optimized node.

    Raises:
        Error: For a flatten node that does not wrap a fetch, a bad
            fragment spread, or a failed minification.
    """
    return _optimize_node(store, plan, node, state)


def _optimize_node(
    mut store: Store, mut plan: QueryPlan, node: Int, state: SupergraphState
) raises -> Int:
    """Optimize one node, as upstream `PlanOptimizer::optimize_node`."""
    var kind = plan.nodes[node].kind
    if kind == PlanNodeKind.FETCH or kind == PlanNodeKind.BATCH_FETCH:
        return node
    if kind == PlanNodeKind.FLATTEN:
        var child = plan.nodes[node].node
        if plan.nodes[child].kind != PlanNodeKind.FETCH:
            raise Error(
                "Internal Error: FlattenNode is expected to wrap a FetchNode,"
                " got "
                + String(plan.nodes[child].kind.name())
            )
        return node
    if kind == PlanNodeKind.SEQUENCE:
        var children = _optimize_children(
            store, plan, plan.nodes[node].nodes.copy(), state
        )
        children = optimize_plan_sequence(plan, children)
        if len(children) == 1:
            return children[0]
        plan.nodes[node].nodes = children^
        return node
    if kind == PlanNodeKind.PARALLEL:
        var children = plan.nodes[node].nodes.copy()
        var all_fetching = True
        var index = 0
        while index < len(children):
            if not plan.is_fetching_node(children[index]):
                all_fetching = False
                break
            index += 1
        if not all_fetching:
            children = _optimize_children(store, plan, children, state)
        children = plan.flatten_parallel(children)
        children = optimize_parallel_node(store, plan, children, state)
        if len(children) == 1:
            return children[0]
        plan.nodes[node].nodes = children^
        return node
    if kind == PlanNodeKind.CONDITION:
        var if_clause = plan.nodes[node].if_clause
        if if_clause != NONE:
            plan.nodes[node].if_clause = _optimize_node(
                store, plan, if_clause, state
            )
        var else_clause = plan.nodes[node].else_clause
        if else_clause != NONE:
            plan.nodes[node].else_clause = _optimize_node(
                store, plan, else_clause, state
            )
        return node
    return node


def _optimize_children(
    mut store: Store,
    mut plan: QueryPlan,
    nodes: List[Int],
    state: SupergraphState,
) raises -> List[Int]:
    """Optimize each node of a list, in order."""
    var out = List[Int]()
    var index = 0
    while index < len(nodes):
        out.append(_optimize_node(store, plan, nodes[index], state))
        index += 1
    return out^

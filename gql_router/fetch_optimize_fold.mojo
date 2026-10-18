# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The fetch graph optimizer pass that folds object selections into an
interface.

Port of Hive Router `1a29df9` `bin/router/src/query_planner/planner/fetch/
optimize/fold_concrete_selections_to_interfaces.rs`.

When a step asks for the same fields on every object type of an interface
in its subgraph, one selection on the interface replaces them:
`media { ... on Book { id } ... on Movie { id } }` becomes `media { id }`.

**Differences from upstream.** Upstream reads the subgraph of a step from
`SupergraphState::subgraphs_state`. This port's `SupergraphState` does not
hold the subgraphs, so the caller passes them, in the order of
`subgraph_names`. Upstream `rewrite_root_output` is left out: it folds the
output types of a step at the root, and that step has only the root type.
"""

from gql_router.ast import NONE, Cond, ItemKind
from gql_router.fetch_optimize_types import subgraph_of
from gql_router.fetch_step import FetchGraph, FetchStepData, QueryPlannerOptions
from gql_router.selection_set import (
    fields_of_same_type,
    merge_selection_set,
    semantic_eq,
)
from gql_router.selection_tools import insert_sorted_once
from gql_router.store import Store
from gql_router.subgraph_state import SubgraphState
from gql_router.supergraph_state import DefinitionKind, SupergraphState


@fieldwise_init
struct ObjectTypeBranch(ImplicitlyCopyable, Movable):
    """An object type selection that might fold into an interface, as
    upstream `ObjectTypeBranch`."""

    var type_name: Int
    """The object type, as a symbol."""
    var set: Int
    """Its selection set: a `ROOT` set or an inline fragment."""
    var condition: Cond
    """The fragment's condition."""
    var remove_index: Int
    """The fragment's position in its set, or `NONE`."""


@fieldwise_init
struct FoldCandidate(Copyable, Movable):
    """The result of a fold, as upstream `FoldCandidate`."""

    var found: Bool
    """False for upstream `None`."""
    var interface_name: Int
    """The interface, as a symbol."""
    var set: Int
    """A copy of the shared selection set."""
    var condition: Cond
    """The shared condition."""
    var remove_indexes: List[Int]
    """The positions of the folded fragments."""

    @staticmethod
    def none() -> FoldCandidate:
        """Return no candidate.

        Returns:
            A candidate that is not found.
        """
        return FoldCandidate(False, NONE, NONE, Cond.none(), List[Int]())


struct StepConverter:
    """Folds the selections of one step, as upstream `StepConverter`."""

    var abstract_type_folding: Bool
    """`QueryPlannerOptions.experimental_abstract_type_folding`."""

    def __init__(out self, abstract_type_folding: Bool):
        """Start a converter. Upstream also keeps the root type of the
        operation, which only `rewrite_root_output` reads.

        Args:
            abstract_type_folding: Fold into any matching interface.
        """
        self.abstract_type_folding = abstract_type_folding

    def rewrite_step(
        self,
        mut store: Store,
        supergraph: SupergraphState,
        subgraph: SubgraphState,
        mut step: FetchStepData,
    ) raises -> Bool:
        """Fold the nested selections of a step, as upstream `rewrite_step`.

        Upstream first tries `rewrite_root_output`, which folds the output
        types of a step at the root. Such a step has one output type, the
        root type, and a fold needs two, so this port leaves it out.

        Args:
            store: The store.
            supergraph: The supergraph.
            subgraph: The step's subgraph.
            step: The step.

        Returns:
            Whether anything changed.

        Raises:
            Error: When a field is not in its type, or on a fragment spread.
        """
        return self.rewrite_nested_output(store, supergraph, subgraph, step)

    def rewrite_nested_output(
        self,
        mut store: Store,
        supergraph: SupergraphState,
        subgraph: SubgraphState,
        mut step: FetchStepData,
    ) raises -> Bool:
        """Fold the inline fragments below every type of a step.

        Args:
            store: The store.
            supergraph: The supergraph.
            subgraph: The step's subgraph.
            step: The step.

        Returns:
            Whether anything changed.

        Raises:
            Error: When a field is not in its type, or on a fragment spread.
        """
        var changed = False
        var index = 0
        while index < len(step.output.types):
            if self.rewrite_selection_set(
                store,
                supergraph,
                subgraph,
                step.output.types[index],
                step.output.sets[index],
            ):
                changed = True
            index += 1
        return changed

    def rewrite_selection_set(
        self,
        mut store: Store,
        supergraph: SupergraphState,
        subgraph: SubgraphState,
        current_type_name: Int,
        set: Int,
    ) raises -> Bool:
        """Fold the inline fragments of a set, deepest first.

        Args:
            store: The store.
            supergraph: The supergraph.
            subgraph: The step's subgraph.
            current_type_name: The type of the set, as a symbol.
            set: The set.

        Returns:
            Whether anything changed.

        Raises:
            Error: When a field is not in its type, or on a fragment spread.
        """
        var changed = False
        for item in store.children(set):
            var found = store.items[item]
            if found.kind == ItemKind.FIELD:
                var child_type = supergraph.field_return_type_name(
                    store, current_type_name, found.name
                )
                if child_type == NONE:
                    raise Error(
                        "Internal Error: No field found for name '"
                        + store.name(found.name)
                        + "' in type '"
                        + store.name(current_type_name)
                        + "'"
                    )
                if self.rewrite_selection_set(
                    store, supergraph, subgraph, child_type, item
                ):
                    changed = True
            elif found.kind == ItemKind.FRAGMENT:
                if self.rewrite_selection_set(
                    store, supergraph, subgraph, found.name, item
                ):
                    changed = True
            else:
                raise Error(_SPREAD_ERROR)
        if self.rewrite_inline_fragments(
            store, supergraph, subgraph, current_type_name, set
        ):
            changed = True
        return changed

    def rewrite_inline_fragments(
        self,
        mut store: Store,
        supergraph: SupergraphState,
        subgraph: SubgraphState,
        current_type_name: Int,
        set: Int,
    ) raises -> Bool:
        """Replace the object fragments of a set with one interface
        selection, as upstream `rewrite_inline_fragments`.

        Args:
            store: The store.
            supergraph: The supergraph.
            subgraph: The step's subgraph.
            current_type_name: The type of the set, as a symbol.
            set: The set.

        Returns:
            Whether the set changed.

        Raises:
            Error: When a fold check meets a fragment spread, or on a
                response key conflict.
        """
        var children = store.children(set)
        var branches = List[ObjectTypeBranch]()
        for index in range(len(children)):
            var found = store.items[children[index]]
            if found.kind == ItemKind.FRAGMENT:
                branches.append(
                    ObjectTypeBranch(
                        found.name,
                        children[index],
                        Cond(found.skip, found.include),
                        index,
                    )
                )
        var candidate = self.try_fold(
            store, supergraph, subgraph, current_type_name, branches
        )
        if not candidate.found:
            return False
        # A found candidate folded at least two fragments of the set.
        var kept = List[Int]()
        var index = 0
        while index < len(children):
            var removed = False
            var at = 0
            while at < len(candidate.remove_indexes):
                if candidate.remove_indexes[at] == index:
                    removed = True
                    break
                at += 1
            if not removed:
                kept.append(children[index])
            index += 1
        store.set_children(set, kept)
        if candidate.condition.is_some():
            var fragment = store.add_item(
                ItemKind.FRAGMENT,
                candidate.interface_name,
                skip=candidate.condition.skip,
                include=candidate.condition.include,
            )
            store.set_children(fragment, store.children(candidate.set))
            store.append(set, fragment)
        elif candidate.interface_name != current_type_name:
            var fragment = store.add_item(
                ItemKind.FRAGMENT, candidate.interface_name
            )
            store.set_children(fragment, store.children(candidate.set))
            store.append(set, fragment)
        else:
            merge_selection_set(store, set, candidate.set, False)
        return True

    def try_fold(
        self,
        mut store: Store,
        supergraph: SupergraphState,
        subgraph: SubgraphState,
        default_interface_name: Int,
        branches: List[ObjectTypeBranch],
    ) raises -> FoldCandidate:
        """Fold into the default interface, or into any interface of the
        first branch when abstract type folding is on.

        Args:
            store: The store.
            supergraph: The supergraph.
            subgraph: The step's subgraph.
            default_interface_name: The type of the set, as a symbol.
            branches: The object type branches.

        Returns:
            The candidate, or one that is not found.

        Raises:
            Error: On a fragment spread.
        """
        if self.abstract_type_folding:
            return self.try_fold_into_any_matching_interface(
                store, supergraph, subgraph, branches
            )
        return self.try_fold_into_interface(
            store, supergraph, subgraph, default_interface_name, branches
        )

    def try_fold_into_any_matching_interface(
        self,
        mut store: Store,
        supergraph: SupergraphState,
        subgraph: SubgraphState,
        branches: List[ObjectTypeBranch],
    ) raises -> FoldCandidate:
        """Try each interface the first branch implements in the subgraph,
        sorted by name.

        Args:
            store: The store.
            supergraph: The supergraph.
            subgraph: The step's subgraph.
            branches: The object type branches.

        Returns:
            The first candidate, or one that is not found.

        Raises:
            Error: On a fragment spread.
        """
        if len(branches) == 0:
            return FoldCandidate.none()
        var definition = supergraph.definition(branches[0].type_name)
        if (
            definition == NONE
            or supergraph.definitions[definition].kind != DefinitionKind.OBJECT
        ):
            return FoldCandidate.none()
        var interface_names = List[Int]()
        for join_implements in supergraph.definitions[
            definition
        ].join_implements:
            if join_implements.graph_id == subgraph.graph_id:
                insert_sorted_once(
                    store, interface_names, join_implements.interface
                )
        for interface_name in interface_names:
            var candidate = self.try_fold_into_interface(
                store, supergraph, subgraph, interface_name, branches
            )
            if candidate.found:
                return candidate^
        return FoldCandidate.none()

    def try_fold_into_interface(
        self,
        mut store: Store,
        supergraph: SupergraphState,
        subgraph: SubgraphState,
        interface_name: Int,
        branches: List[ObjectTypeBranch],
    ) raises -> FoldCandidate:
        """Fold the branches into one interface, as upstream
        `try_fold_into_interface`.

        The branches must be every object type of the interface in the
        subgraph, share one condition, and ask for the same fields, all of
        them on the interface.

        Args:
            store: The store.
            supergraph: The supergraph.
            subgraph: The step's subgraph.
            interface_name: The interface, as a symbol.
            branches: The object type branches.

        Returns:
            The candidate, or one that is not found.

        Raises:
            Error: On a fragment spread.
        """
        if len(branches) < 2:
            return FoldCandidate.none()
        var interface_def = subgraph.definition(interface_name)
        if (
            interface_def == NONE
            or not subgraph.definitions[interface_def].is_interface_type()
        ):
            return FoldCandidate.none()
        if not supergraph.has_interface_members(interface_name):
            return FoldCandidate.none()
        var members = List[Int]()
        var all_members = supergraph.interface_members(interface_name)
        var at = 0
        while at < len(all_members):
            if self.object_is_interface_member_in_subgraph(
                supergraph, subgraph, all_members[at], interface_name
            ):
                insert_sorted_once(store, members, all_members[at])
            at += 1
        if len(members) == 0:
            return FoldCandidate.none()

        var first = branches[0]
        var concrete_types = List[Int]()
        at = 0
        while at < len(branches):
            ref branch = branches[at]
            at += 1
            if branch.condition != first.condition:
                return FoldCandidate.none()
            var own = subgraph.definition(branch.type_name)
            if own == NONE or not subgraph.definitions[own].is_object_type():
                return FoldCandidate.none()
            insert_sorted_once(store, concrete_types, branch.type_name)
        if concrete_types != members:
            return FoldCandidate.none()
        at = 1
        while at < len(branches):
            if not semantic_eq(store, first.set, branches[at].set):
                return FoldCandidate.none()
            at += 1
        var typename = store.find_sym("__typename")
        var fields = fields_of_same_type(store, first.set, first.type_name)
        at = 0
        while at < len(fields):
            var name = store.items[fields[at]].name
            at += 1
            if name == typename:
                continue
            if subgraph.definitions[interface_def].field(name) == NONE:
                return FoldCandidate.none()
        if not self.selection_set_is_valid_for_type(
            store, supergraph, subgraph, interface_name, first.set
        ):
            return FoldCandidate.none()
        # Every branch is an inline fragment of the set, so each one has its
        # position. Upstream skips a branch without one, which only its
        # `rewrite_root_output` makes.
        var remove_indexes = List[Int]()
        at = 0
        while at < len(branches):
            remove_indexes.append(branches[at].remove_index)
            at += 1
        return FoldCandidate(
            True,
            interface_name,
            store.copy_set(first.set),
            first.condition,
            remove_indexes^,
        )

    def selection_set_is_valid_for_type(
        self,
        store: Store,
        supergraph: SupergraphState,
        subgraph: SubgraphState,
        type_name: Int,
        set: Int,
    ) -> Bool:
        """Return True if a set is valid for a type in the subgraph, as
        upstream `selection_set_is_valid_for_type`.

        Args:
            store: The store.
            supergraph: The supergraph.
            subgraph: The step's subgraph.
            type_name: The type, as a symbol.
            set: The set.

        Returns:
            Whether every field and fragment fits the type.
        """
        if store.is_empty(set):
            return True
        # The interface, the type of a field of the subgraph, or the parent
        # type: always a type of the subgraph.
        var definition = subgraph.definition(type_name)
        var typename = store.find_sym("__typename")
        var children = store.children(set)
        var at = 0
        while at < len(children):
            var item = children[at]
            at += 1
            var found = store.items[item]
            if found.kind == ItemKind.FIELD:
                if found.name == typename:
                    continue
                var field = subgraph.definitions[definition].field(found.name)
                if field == NONE:
                    return False
                var inner = (
                    subgraph.definitions[definition]
                    .fields[field]
                    .field_type.inner_type()
                )
                if not self.selection_set_is_valid_for_type(
                    store, supergraph, subgraph, inner, item
                ):
                    return False
            else:
                # `rewrite_selection_set` has already refused a spread, so
                # this is an inline fragment.
                if not self.fragment_type_is_valid_for_parent_type(
                    supergraph, subgraph, type_name, found.name
                ):
                    return False
                if not self.selection_set_is_valid_for_type(
                    store, supergraph, subgraph, found.name, item
                ):
                    return False
        return True

    def fragment_type_is_valid_for_parent_type(
        self,
        supergraph: SupergraphState,
        subgraph: SubgraphState,
        parent_type_name: Int,
        fragment_type_name: Int,
    ) -> Bool:
        """Return True if a fragment type fits its parent type.

        Args:
            supergraph: The supergraph.
            subgraph: The step's subgraph.
            parent_type_name: The parent type, as a symbol.
            fragment_type_name: The fragment type, as a symbol.

        Returns:
            Whether the types are equal, or the parent is an interface the
            fragment type implements in the subgraph.
        """
        if parent_type_name == fragment_type_name:
            return True
        var parent = subgraph.definition(parent_type_name)
        return (
            parent != NONE
            and subgraph.definitions[parent].is_interface_type()
            and self.object_is_interface_member_in_subgraph(
                supergraph, subgraph, fragment_type_name, parent_type_name
            )
        )

    def object_is_interface_member_in_subgraph(
        self,
        supergraph: SupergraphState,
        subgraph: SubgraphState,
        object_type_name: Int,
        interface_name: Int,
    ) -> Bool:
        """Return True if an object implements an interface in the subgraph.

        Args:
            supergraph: The supergraph.
            subgraph: The step's subgraph.
            object_type_name: The object type, as a symbol.
            interface_name: The interface, as a symbol.

        Returns:
            Whether a `@join__implements` of the subgraph says so.
        """
        var definition = supergraph.definition(object_type_name)
        if (
            definition == NONE
            or supergraph.definitions[definition].kind != DefinitionKind.OBJECT
        ):
            return False
        if subgraph.definition(object_type_name) == NONE:
            return False
        for join_implements in supergraph.definitions[
            definition
        ].join_implements:
            if (
                join_implements.graph_id == subgraph.graph_id
                and join_implements.interface == interface_name
            ):
                return True
        return False


comptime _SPREAD_ERROR = (
    "Internal Error: fragment spreads should have been inlined before"
    " abstract type conversion"
)
"""The error for a fragment spread."""


def fold_concrete_selections_to_interfaces(
    mut store: Store,
    supergraph: SupergraphState,
    subgraphs: List[SubgraphState],
    mut fetch_graph: FetchGraph,
    options: QueryPlannerOptions,
) raises -> Bool:
    """Fold object type selections into their interface in every step, as
    upstream `fold_concrete_selections_to_interfaces`.

    Args:
        store: The store.
        supergraph: The supergraph.
        subgraphs: The subgraph states, in the order of `subgraph_names`.
        fetch_graph: The fetch graph.
        options: The planner options.

    Returns:
        Whether a step changed.

    Raises:
        Error: When a field is not in its type, or on a fragment spread.
    """
    var converter = StepConverter(options.experimental_abstract_type_folding)
    var changed = False
    var indices = fetch_graph.step_indices()
    var at = 0
    while at < len(indices):
        var index = indices[at]
        at += 1
        var subgraph = subgraph_of(
            supergraph, subgraphs, fetch_graph.steps[index].service_name
        )
        if subgraph == NONE:
            continue
        if converter.rewrite_step(
            store, supergraph, subgraphs[subgraph], fetch_graph.steps[index]
        ):
            changed = True
    return changed

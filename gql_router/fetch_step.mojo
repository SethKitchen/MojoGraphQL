# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Fetch steps and the fetch graph.

Port of Hive Router `1a29df9` `bin/router/src/query_planner/planner/fetch/`:
`fetch_step_data.rs`, `selections.rs`, `state.rs` and the graph part of
`fetch_graph.rs`, and `FetchRewrite` of `plan_nodes/mod.rs`.

The fetch graph keeps the adjacency of `petgraph` `StableDiGraph`: the
edges of a step are visited newest first, a removed step leaves a hole,
and a new step takes the index that was freed last.

**Differences from upstream.** Upstream marks a step as single-type while
the graph is built and as multi-type while it is optimized, with a type
parameter. This port has one step type; the builder uses only the
single-type methods.
"""

from gql_router.ast import NONE, Cond, ItemKind
from gql_router.federation_spec import OperationKind
from gql_router.merge_path import MergePath, SegmentKind
from gql_router.operation import VariableDefinition
from gql_router.selection_set import (
    find_by_path,
    items_are_subset_of,
    merge_selection_set,
    set_text,
    variable_usages,
)
from gql_router.store import Store


@fieldwise_init
struct QueryPlannerOptions(Copyable, Movable):
    """The planner options, as upstream `QueryPlannerOptions`."""

    var experimental_abstract_type_folding: Bool
    """Fold the selections of object types into their interface."""

    @staticmethod
    def default() -> QueryPlannerOptions:
        """Return the default options.

        Returns:
            Options with every experiment off.
        """
        return QueryPlannerOptions(False)


@fieldwise_init
struct FetchStepKind(Equatable, ImplicitlyCopyable, Movable):
    """The kind of a fetch step, as upstream `FetchStepKind`."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime ENTITY = FetchStepKind(0)
    """An `_entities` call."""
    comptime ROOT = FetchStepKind(1)
    """A root field call."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the two kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 1


@fieldwise_init
struct FetchStepFlags(Equatable, ImplicitlyCopyable, Movable):
    """The flags of a fetch step, as upstream `FetchStepFlags`."""

    var value: UInt8
    """The flag bits; see `is_valid`."""

    comptime EMPTY = FetchStepFlags(0)
    """No flag."""
    comptime USED_FOR_REQUIRES = FetchStepFlags(1)
    """The fetch resolves a `@requires`."""
    comptime USED_FOR_TYPE_CONDITION = FetchStepFlags(2)
    """The fetch resolves a type condition on an interface."""

    def is_valid(self) -> Bool:
        """Return True if only known bits are set.

        Returns:
            Whether the value is at most 3.
        """
        return self.value <= 3

    def contains(self, other: FetchStepFlags) -> Bool:
        """Return True if every bit of a flag is set.

        Args:
            other: The flag.

        Returns:
            Whether the bits are set.
        """
        return (self.value & other.value) == other.value

    def with_flag(self, other: FetchStepFlags) -> FetchStepFlags:
        """Return the flags with more bits set.

        Args:
            other: The bits to set.

        Returns:
            The union.
        """
        return FetchStepFlags(self.value | other.value)


@fieldwise_init
struct FetchNodePathSegment(Copyable, Equatable, Movable):
    """One step of a rewrite path, as upstream `FetchNodePathSegment`."""

    var is_key: Bool
    """True for `Key`, False for `TypenameEquals`."""
    var key: Int
    """The key, as a symbol, for `Key`."""
    var types: Int
    """The interned type set, for `TypenameEquals`."""


@fieldwise_init
struct FetchRewrite(Copyable, Equatable, Movable):
    """A rewrite of an input or output, as upstream `FetchRewrite`."""

    var is_value_setter: Bool
    """True for `ValueSetter`, False for `KeyRenamer`."""
    var path: List[FetchNodePathSegment]
    """Where the rewrite applies."""
    var value: Int
    """`set_value_to` or `rename_key_to`, as a symbol."""


@fieldwise_init
struct FetchStepSelections(Copyable, Movable):
    """The selections of a fetch step by type, as upstream
    `FetchStepSelections`."""

    var types: List[Int]
    """The type names, as symbols, sorted by name."""
    var sets: List[Int]
    """The selection set of each type, a `ROOT` item."""

    @staticmethod
    def new(mut store: Store, definition_name: Int) -> FetchStepSelections:
        """Return selections with one empty set for a type.

        Args:
            store: The store.
            definition_name: The type, as a symbol.

        Returns:
            The selections.
        """
        return FetchStepSelections([definition_name], [store.new_set()])

    @staticmethod
    def new_empty() -> FetchStepSelections:
        """Return selections with no type.

        Returns:
            The selections.
        """
        return FetchStepSelections(List[Int](), List[Int]())

    def definition_name(self) -> Int:
        """Return the type of a single-type step.

        Returns:
            The first type, as a symbol.
        """
        return self.types[0]

    def selection_set(self) -> Int:
        """Return the set of a single-type step.

        Returns:
            The first set.
        """
        return self.sets[0]

    def is_fetching_multiple_types(self) -> Bool:
        """Return True for more than one type.

        Returns:
            Whether there are two types or more.
        """
        return len(self.types) > 1

    def index_of(self, definition_name: Int) -> Int:
        """Return the position of a type.

        Args:
            definition_name: The type, as a symbol.

        Returns:
            The index in `types`, or `NONE`.
        """
        for index in range(len(self.types)):
            if self.types[index] == definition_name:
                return index
        return NONE

    def selections_for_definition(self, definition_name: Int) -> Int:
        """Return the set of a type.

        Args:
            definition_name: The type, as a symbol.

        Returns:
            The set, or `NONE`.
        """
        var index = self.index_of(definition_name)
        if index == NONE:
            return NONE
        return self.sets[index]

    def is_selecting_definition(self, definition_name: Int) -> Bool:
        """Return True if the selections have a type.

        Args:
            definition_name: The type, as a symbol.

        Returns:
            Whether the type is there.
        """
        return self.index_of(definition_name) != NONE

    def contains(self, store: Store, definition_name: Int, set: Int) -> Bool:
        """Return True if a type's set covers another set.

        Args:
            store: The store.
            definition_name: The type, as a symbol.
            set: The set.

        Returns:
            Whether every item of `set` is in the type's set.
        """
        var own = self.selections_for_definition(definition_name)
        if own == NONE:
            return False
        return items_are_subset_of(store, own, set)

    def is_empty(self, store: Store) -> Bool:
        """Return True if there is no type, or every set is empty.

        Args:
            store: The store.

        Returns:
            Whether nothing is selected.
        """
        var index = 0
        while index < len(self.sets):
            if not store.is_empty(self.sets[index]):
                return False
            index += 1
        return True

    def variable_usages(self, store: Store) -> List[Int]:
        """Return the variables the sets use.

        Args:
            store: The store.

        Returns:
            The variable symbols, sorted by name, once each.
        """
        var out = List[Int]()
        for set in self.sets:
            variable_usages(store, set, out)
        return out^

    def try_as_single(self) -> Int:
        """Return the only type, as upstream `try_as_single`.

        Returns:
            The type, or `NONE` when there is not exactly one.
        """
        if len(self.types) == 1:
            return self.types[0]
        return NONE

    def selecting_same_types(self, other: Self) -> Bool:
        """Return True if two selections have the same types.

        Args:
            other: Other selections.

        Returns:
            Whether the type lists are equal.
        """
        return self.types == other.types

    def declare_known_type(mut self, mut store: Store, definition_name: Int):
        """Add an empty set for a type, unless it is there.

        Args:
            store: The store.
            definition_name: The type, as a symbol.
        """
        if self.index_of(definition_name) != NONE:
            return
        var at = len(self.types)
        while at > 0 and store.less(definition_name, self.types[at - 1]):
            at -= 1
        self.types.insert(at, definition_name)
        self.sets.insert(at, store.new_set())

    def add(mut self, mut store: Store, set: Int) raises:
        """Merge a set into the set of a single-type step.

        Args:
            store: The store.
            set: The set.

        Raises:
            Error: On a response key conflict.
        """
        merge_selection_set(store, self.sets[0], set, False)

    def add_at_path_inner(
        mut self,
        mut store: Store,
        definition_name: Int,
        path: MergePath,
        set: Int,
        as_first: Bool,
    ) raises:
        """Merge a set at a path of a type's set.

        Args:
            store: The store.
            definition_name: The type, as a symbol.
            path: The path in the type's set.
            set: The set.
            as_first: Put new items first.

        Raises:
            Error: When the type or the path is missing, or on a response
                key conflict.
        """
        var current = self.selections_for_definition(definition_name)
        if current == NONE:
            raise Error(
                "Unexpected missing definition: " + store.name(definition_name)
            )
        var at = find_by_path(store, current, path)
        if at == NONE:
            raise Error(
                "Path '"
                + path.text(store)
                + "' cannot be found in selection set of type "
                + store.name(definition_name)
            )
        merge_selection_set(store, at, set, as_first)

    def add_at_path(
        mut self, mut store: Store, path: MergePath, set: Int
    ) raises:
        """Merge a set at a path of a single-type step.

        Args:
            store: The store.
            path: The path.
            set: The set.

        Raises:
            Error: When the path is missing, or on a key conflict.
        """
        self.add_at_path_inner(store, self.types[0], path, set, False)

    def add_selection_typename(
        mut self, mut store: Store, path: MergePath
    ) raises:
        """Put `__typename` first at a path of a single-type step.

        Args:
            store: The store.
            path: The path.

        Raises:
            Error: When the path is missing.
        """
        var set = store.new_set()
        store.append(
            set, store.add_item(ItemKind.FIELD, store.sym("__typename"))
        )
        self.add_at_path_inner(store, self.types[0], path, set, True)

    def migrate_from_another(
        mut self, mut store: Store, other: Self, path: MergePath
    ) raises:
        """Merge another step's selections at a path, as upstream
        `migrate_from_another`.

        Args:
            store: The store.
            other: The other selections.
            path: The path.

        Raises:
            Error: When a type or the path is missing.
        """
        var single = self.try_as_single()
        var index = 0
        while index < len(other.types):
            var target = single if single != NONE else other.types[index]
            self.add_at_path_inner(
                store, target, path, other.sets[index], False
            )
            index += 1

    # --- conditions -----------------------------------------------------

    def wrap_with_condition(mut self, mut store: Store, cond: Cond):
        """Wrap every type's set in `... on Type` with a condition.

        Args:
            store: The store.
            cond: The condition; it must be some.
        """
        var index = 0
        while index < len(self.types):
            _wrap_with_condition(
                store, self.types[index], self.sets[index], cond
            )
            index += 1

    def wrap_with_condition_for_types(
        mut self, mut store: Store, cond: Cond, types: List[Int]
    ):
        """Wrap the sets of some types in `... on Type` with a condition.

        Args:
            store: The store.
            cond: The condition; it must be some.
            types: The types to wrap, as symbols.
        """
        var index = 0
        while index < len(self.types):
            var at = 0
            while at < len(types):
                if types[at] == self.types[index]:
                    _wrap_with_condition(
                        store, self.types[index], self.sets[index], cond
                    )
                    break
                at += 1
            index += 1

    def take_shared_top_level_fragment_condition(
        mut self, mut store: Store
    ) -> Cond:
        """Lift a condition that guards every type, as upstream
        `take_shared_top_level_fragment_condition`.

        Args:
            store: The store.

        Returns:
            The condition, cleared from the top-level fragments, or no
            condition when the types do not share one.
        """
        if self.is_empty(store):
            return Cond.none()
        var common = Cond.none()
        var index = 0
        while index < len(self.types):
            var cond = _shared_top_level_fragment_condition(
                store, self.types[index], self.sets[index]
            )
            if not cond.is_some():
                return Cond.none()
            if common.is_some() and common != cond:
                return Cond.none()
            common = cond
            index += 1
        # Every top-level item of every set is now `... on Type` with the
        # common condition, so each one loses it.
        index = 0
        while index < len(self.types):
            var child = store.items[self.sets[index]].first
            while child != NONE:
                store.items[child].skip = NONE
                store.items[child].include = NONE
                child = store.items[child].next
            index += 1
        return common

    # --- output ---------------------------------------------------------

    def to_non_root_selection_set(self, mut store: Store) -> Int:
        """Return the sets as `... on Type` fragments, for an entity call.

        Args:
            store: The store.

        Returns:
            A new set.
        """
        return self._wrap_in_type_fragments(store)

    def to_root_selection_set(
        self, mut store: Store, root_type_name: Int
    ) -> Int:
        """Return the sets for a root call: the root type's set itself, or
        `... on Type` fragments.

        Args:
            store: The store.
            root_type_name: The root type, as a symbol.

        Returns:
            A new set.
        """
        if len(self.types) == 1 and self.types[0] == root_type_name:
            return store.copy_set(self.sets[0])
        return self._wrap_in_type_fragments(store)

    def _wrap_in_type_fragments(self, mut store: Store) -> Int:
        """Wrap each type's set in `... on Type`, lifting a shared
        condition onto the wrapper, as upstream `wrap_in_type_fragments`.
        """
        var out = store.new_set()
        var index = 0
        while index < len(self.types):
            var type_name = self.types[index]
            var set = self.sets[index]
            var wrapper = store.add_item(ItemKind.FRAGMENT, type_name)
            var cond = _liftable_condition(store, type_name, set)
            if not cond.is_some():
                _append_copies(store, wrapper, set, False)
            else:
                store.items[wrapper].skip = cond.skip
                store.items[wrapper].include = cond.include
                var first = store.items[set].first
                if store.items[first].next == NONE:
                    _append_copies(store, wrapper, first, False)
                else:
                    _append_copies(store, wrapper, set, True)
            store.append(out, wrapper)
            index += 1
        return out

    def text(self, store: Store) -> String:
        """Return the first type's set, as upstream `Display` of a
        single-type step.

        Args:
            store: The store.

        Returns:
            The set text.
        """
        return set_text(store, self.sets[0])

    def copy_into(self, mut store: Store) -> FetchStepSelections:
        """Return selections with copies of every set.

        Args:
            store: The store.

        Returns:
            The copy.
        """
        var sets = List[Int]()
        var index = 0
        while index < len(self.sets):
            sets.append(store.copy_set(self.sets[index]))
            index += 1
        return FetchStepSelections(self.types.copy(), sets^)


def _append_copies(mut store: Store, parent: Int, source: Int, clear: Bool):
    """Append a copy of each child of `source` to `parent`; `clear` drops
    the copies' `@skip` and `@include`."""
    var child = store.items[source].first
    while child != NONE:
        var copy = store.copy_item(child)
        if clear:
            store.items[copy].skip = NONE
            store.items[copy].include = NONE
        store.append(parent, copy)
        child = store.items[child].next


def _wrap_with_condition(
    mut store: Store, type_name: Int, set: Int, cond: Cond
):
    """Move a set's items into `... on Type` with a condition."""
    var fragment = store.add_item(
        ItemKind.FRAGMENT, type_name, skip=cond.skip, include=cond.include
    )
    var children = store.children(set)
    store.set_children(fragment, children)
    store.set_children(set, [fragment])


def _shared_top_level_fragment_condition(
    store: Store, type_name: Int, set: Int
) -> Cond:
    """Return the condition every top-level item shares, when each is
    `... on Type` with that one condition."""
    var cond = Cond.none()
    var child = store.items[set].first
    while child != NONE:
        ref item = store.items[child]
        if item.kind != ItemKind.FRAGMENT or item.name != type_name:
            return Cond.none()
        var own = Cond(item.skip, item.include)
        if not own.is_some():
            return Cond.none()
        if cond.is_some() and cond != own:
            return Cond.none()
        cond = own
        child = item.next
    return cond


def _liftable_condition(store: Store, type_name: Int, set: Int) -> Cond:
    """Return the condition `try_lift_condition` lifts, or none."""
    var first = store.items[set].first
    if first == NONE or store.items[first].kind != ItemKind.FRAGMENT:
        return Cond.none()
    var cond = Cond(store.items[first].skip, store.items[first].include)
    if not cond.is_some():
        return Cond.none()
    var child = first
    while child != NONE:
        ref item = store.items[child]
        if (
            item.kind != ItemKind.FRAGMENT
            or item.name != type_name
            or Cond(item.skip, item.include) != cond
        ):
            return Cond.none()
        child = item.next
    return cond


def type_condition_types(store: Store, path: MergePath) -> List[Int]:
    """Return the types of the type conditions of a response path, as
    upstream `type_condition_types_from_response_path`.

    Args:
        store: The store with the type sets.
        path: The response path.

    Returns:
        The types, sorted by name, once each; empty when there are none.
    """
    var out = List[Int]()
    var index = 0
    while index < len(path.segments):
        ref segment = path.segments[index]
        index += 1
        if segment.kind != SegmentKind.TYPE_CONDITION:
            continue
        ref names = store.type_sets[segment.types]
        var at_name = 0
        while at_name < len(names):
            var name = names[at_name]
            at_name += 1
            var seen = False
            for known in out:
                if known == name:
                    seen = True
            if seen:
                continue
            var at = len(out)
            while at > 0 and store.less(name, out[at - 1]):
                at -= 1
            out.insert(at, name)
    return out^


struct FetchStepData(Copyable, Movable):
    """One fetch, as upstream `FetchStepData`."""

    var id: Int
    """The step id."""
    var service_name: Int
    """The subgraph name, as a symbol, or `NONE` for upstream
    `SubgraphName::any()`."""
    var response_path: MergePath
    """Where the fetch writes into the response."""
    var input: FetchStepSelections
    """The representations an entity call sends."""
    var output: FetchStepSelections
    """The selections the fetch asks for."""
    var kind: FetchStepKind
    """An entity call or a root call."""
    var operation_kind: OperationKind
    """The operation kind of the fetch."""
    var flags: FetchStepFlags
    """The flags."""
    var condition: Cond
    """The condition of the whole fetch."""
    var variable_usages: List[Int]
    """The variables the output uses."""
    var has_variable_usages: Bool
    """False when upstream `variable_usages` is `None`."""
    var variable_definitions: List[VariableDefinition]
    """The definitions of those variables."""
    var has_variable_definitions: Bool
    """False when upstream `variable_definitions` is `None`."""
    var mutation_field_position: Int
    """The position of the root mutation field, or `NONE`."""
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
        var response_path: MergePath,
        var input: FetchStepSelections,
        var output: FetchStepSelections,
        kind: FetchStepKind,
        operation_kind: OperationKind,
        flags: FetchStepFlags,
        condition: Cond,
        mutation_field_position: Int,
    ):
        """Start a step with no variables and no rewrites.

        Args:
            id: The step id.
            service_name: The subgraph name, or `NONE`.
            response_path: The response path.
            input: The input selections.
            output: The output selections.
            kind: The step kind.
            operation_kind: The operation kind.
            flags: The flags.
            condition: The condition.
            mutation_field_position: The mutation field position, or `NONE`.
        """
        self.id = id
        self.service_name = service_name
        self.response_path = response_path^
        self.input = input^
        self.output = output^
        self.kind = kind
        self.operation_kind = operation_kind
        self.flags = flags
        self.condition = condition
        self.variable_usages = List[Int]()
        self.has_variable_usages = False
        self.variable_definitions = List[VariableDefinition]()
        self.has_variable_definitions = False
        self.mutation_field_position = mutation_field_position
        self.input_rewrites = List[FetchRewrite]()
        self.has_input_rewrites = False
        self.output_rewrites = List[FetchRewrite]()
        self.has_output_rewrites = False

    def is_entity_call(self) -> Bool:
        """Return True for an entity call.

        Returns:
            Whether the kind is `ENTITY`.
        """
        return self.kind == FetchStepKind.ENTITY

    def is_fetching_multiple_types(self) -> Bool:
        """Return True if the input or the output has more than one type.

        Returns:
            Whether the step is multi-type.
        """
        return (
            self.input.is_fetching_multiple_types()
            or self.output.is_fetching_multiple_types()
        )

    def add_input_rewrite(mut self, var rewrite: FetchRewrite):
        """Add an input rewrite once.

        Args:
            rewrite: The rewrite.
        """
        self.has_input_rewrites = True
        for known in self.input_rewrites:
            if known == rewrite:
                return
        self.input_rewrites.append(rewrite^)

    def add_output_rewrite(mut self, var rewrite: FetchRewrite):
        """Add an output rewrite once.

        Args:
            rewrite: The rewrite.
        """
        self.has_output_rewrites = True
        for known in self.output_rewrites:
            if known == rewrite:
                return
        self.output_rewrites.append(rewrite^)

    def scope_condition_to_output(
        mut self, mut store: Store, scope_by_response_path_types: Bool
    ):
        """Move the fetch condition into the output selections, as upstream
        `scope_condition_to_output`.

        Args:
            store: The store.
            scope_by_response_path_types: Whether to wrap only the types of
                the response path's type conditions.
        """
        if not self.condition.is_some():
            return
        var cond = self.condition
        self.condition = Cond.none()
        var types = List[Int]()
        if scope_by_response_path_types:
            types = type_condition_types(store, self.response_path)
        if len(types) > 0:
            self.output.wrap_with_condition_for_types(store, cond, types)
        else:
            self.output.wrap_with_condition(store, cond)

    def lift_shared_output_condition_to_fetch(mut self, mut store: Store):
        """Lift a condition shared by every output type back onto the fetch,
        as upstream `lift_shared_output_condition_to_fetch`.

        Args:
            store: The store.
        """
        if not self.condition.is_some():
            self.condition = (
                self.output.take_shared_top_level_fragment_condition(store)
            )

    def text(self, store: Store) -> String:
        """Return the step as upstream `Display`.

        Args:
            store: The store with the names.

        Returns:
            Such as `[a]: User/{__typename id} -> User/{name} at $.me`.
        """
        var out = String("[")
        if self.service_name != NONE:
            out += store.name(self.service_name)
        out += "]: "
        for index in range(len(self.input.types)):
            out += store.name(self.input.types[index])
            out += "/"
            out += set_text(store, self.input.sets[index])
            out += " "
        out += "-> "
        for index in range(len(self.output.types)):
            out += store.name(self.output.types[index])
            out += "/"
            out += set_text(store, self.output.sets[index])
            out += " "
        out += "at $."
        out += self.response_path.text(store)
        if self.flags.contains(FetchStepFlags.USED_FOR_REQUIRES):
            out += " [@requires]"
        if self.flags.contains(FetchStepFlags.USED_FOR_TYPE_CONDITION):
            out += " [no_pass_through]"
        if self.condition.is_some():
            out += " ["
            if self.condition.skip != NONE:
                out += "@skip(if: $"
                out += store.name(self.condition.skip)
                out += ")"
                if self.condition.include != NONE:
                    out += " "
            if self.condition.include != NONE:
                out += "@include(if: $"
                out += store.name(self.condition.include)
                out += ")"
            out += "]"
        return out^


def scope_fetch_conditions_before_merge(
    mut store: Store, mut target: FetchStepData, mut source: FetchStepData
):
    """Scope the conditions of two entity calls before they merge, as
    upstream `scope_fetch_conditions_before_merge`.

    Args:
        store: The store.
        target: The step merged into.
        source: The step merged from.
    """
    if not target.is_entity_call():
        return
    var can_scope_by_type = (
        target.is_fetching_multiple_types()
        or source.is_fetching_multiple_types()
    )
    var type_scoped = (
        target.condition.is_some()
        and target.is_fetching_multiple_types()
        and len(type_condition_types(store, target.response_path)) > 0
    )
    if type_scoped:
        target.scope_condition_to_output(store, True)
    if target.condition != source.condition:
        target.scope_condition_to_output(store, can_scope_by_type)
        source.scope_condition_to_output(store, can_scope_by_type)


# --- the fetch graph -----------------------------------------------------


@fieldwise_init
struct FetchEdge(Copyable, Movable):
    """One dependency between fetch steps."""

    var parent: Int
    """The step that runs first, or `NONE` for a free slot."""
    var child: Int
    """The step that depends on it."""
    var next_out: Int
    """The next outgoing edge of `parent`, or `NONE`."""
    var next_in: Int
    """The next incoming edge of `child`, or `NONE`."""


struct FetchGraph(Movable):
    """The fetch steps and their dependencies, as upstream `FetchGraph`
    over a `petgraph` `StableDiGraph`."""

    var steps: List[FetchStepData]
    """Every step slot, by index; a removed step keeps its slot."""
    var alive: List[Bool]
    """Whether each slot holds a step."""
    var free_steps: List[Int]
    """The freed slots; the last one is reused first."""
    var first_out: List[Int]
    """The newest outgoing edge of each step, or `NONE`."""
    var first_in: List[Int]
    """The newest incoming edge of each step, or `NONE`."""
    var edges: List[FetchEdge]
    """Every edge slot, by index."""
    var free_edges: List[Int]
    """The freed edge slots; the last one is reused first."""
    var step_count: Int
    """The number of steps."""
    var root_index: Int
    """The root step, or `NONE`."""
    var operation_kind: OperationKind
    """The operation kind."""

    def __init__(out self, kind: OperationKind):
        """Start an empty graph.

        Args:
            kind: The operation kind.
        """
        self.steps = List[FetchStepData]()
        self.alive = List[Bool]()
        self.free_steps = List[Int]()
        self.first_out = List[Int]()
        self.first_in = List[Int]()
        self.edges = List[FetchEdge]()
        self.free_edges = List[Int]()
        self.step_count = 0
        self.root_index = NONE
        self.operation_kind = kind

    def create_fetch_id(self) -> Int:
        """Return the id for a new step: the step count plus one.

        Returns:
            The id.
        """
        return self.step_count + 1

    def add_step(mut self, var data: FetchStepData) -> Int:
        """Add a step, in the slot freed last when there is one.

        Args:
            data: The step.

        Returns:
            Its index.
        """
        self.step_count += 1
        if len(self.free_steps) > 0:
            var index = self.free_steps.pop()
            self.steps[index] = data^
            self.alive[index] = True
            self.first_out[index] = NONE
            self.first_in[index] = NONE
            return index
        self.steps.append(data^)
        self.alive.append(True)
        self.first_out.append(NONE)
        self.first_in.append(NONE)
        return len(self.steps) - 1

    def contains_step(self, index: Int) -> Bool:
        """Return True if a slot holds a step.

        Args:
            index: The slot.

        Returns:
            Whether the step exists.
        """
        return index >= 0 and index < len(self.alive) and self.alive[index]

    def step(ref self, index: Int) raises -> ref[self.steps[0]] FetchStepData:
        """Return a step.

        Args:
            index: The step index.

        Returns:
            The step.

        Raises:
            Error: When there is no such step.
        """
        if not self.contains_step(index):
            raise Error(
                "Missing FetchStep: "
                + String(index)
                + " when getting step data"
            )
        return self.steps[index]

    def step_indices(self) -> List[Int]:
        """Return every step index, in index order.

        Returns:
            The indices.
        """
        var out = List[Int]()
        var index = 0
        while index < len(self.alive):
            if self.alive[index]:
                out.append(index)
            index += 1
        return out^

    def find_edge(self, parent: Int, child: Int) -> Int:
        """Return the edge from one step to another.

        Args:
            parent: The parent step.
            child: The child step.

        Returns:
            The edge, or `NONE`.
        """
        var edge = self.first_out[parent]
        while edge != NONE:
            if self.edges[edge].child == child:
                return edge
            edge = self.edges[edge].next_out
        return NONE

    def connect(mut self, parent: Int, child: Int) -> Int:
        """Add an edge from one step to another, unless there is one, as
        `petgraph` `update_edge`.

        Args:
            parent: The parent step.
            child: The child step.

        Returns:
            The edge.
        """
        var existing = self.find_edge(parent, child)
        if existing != NONE:
            return existing
        var edge = FetchEdge(
            parent, child, self.first_out[parent], self.first_in[child]
        )
        var index: Int
        if len(self.free_edges) > 0:
            index = self.free_edges.pop()
            self.edges[index] = edge^
        else:
            index = len(self.edges)
            self.edges.append(edge^)
        self.first_out[parent] = index
        self.first_in[child] = index
        return index

    def remove_edge(mut self, edge: Int) -> Bool:
        """Remove an edge.

        Args:
            edge: The edge.

        Returns:
            Whether the edge existed.
        """
        if (
            edge < 0
            or edge >= len(self.edges)
            or self.edges[edge].parent == NONE
        ):
            return False
        var parent = self.edges[edge].parent
        var child = self.edges[edge].child
        if self.first_out[parent] == edge:
            self.first_out[parent] = self.edges[edge].next_out
        else:
            var at = self.first_out[parent]
            while self.edges[at].next_out != edge:
                at = self.edges[at].next_out
            self.edges[at].next_out = self.edges[edge].next_out
        if self.first_in[child] == edge:
            self.first_in[child] = self.edges[edge].next_in
        else:
            var at = self.first_in[child]
            while self.edges[at].next_in != edge:
                at = self.edges[at].next_in
            self.edges[at].next_in = self.edges[edge].next_in
        self.edges[edge] = FetchEdge(NONE, NONE, NONE, NONE)
        self.free_edges.append(edge)
        return True

    def remove_step(mut self, index: Int) -> Bool:
        """Remove a step and its edges.

        Args:
            index: The step.

        Returns:
            Whether the step existed.
        """
        if not self.contains_step(index):
            return False
        while self.first_out[index] != NONE:
            _ = self.remove_edge(self.first_out[index])
        while self.first_in[index] != NONE:
            _ = self.remove_edge(self.first_in[index])
        self.alive[index] = False
        self.free_steps.append(index)
        self.step_count -= 1
        return True

    def parents_of(self, index: Int) -> List[Int]:
        """Return the incoming edges of a step, newest first.

        Args:
            index: The step.

        Returns:
            The edges.
        """
        var out = List[Int]()
        var edge = self.first_in[index]
        while edge != NONE:
            out.append(edge)
            edge = self.edges[edge].next_in
        return out^

    def child_steps(self, index: Int) -> List[Int]:
        """Return the children of a step, newest edge first.

        Args:
            index: The step.

        Returns:
            The child steps.
        """
        var out = List[Int]()
        var edge = self.first_out[index]
        while edge != NONE:
            out.append(self.edges[edge].child)
            edge = self.edges[edge].next_out
        return out^

    def parent_steps(self, index: Int) -> List[Int]:
        """Return the parents of a step, newest edge first.

        Args:
            index: The step.

        Returns:
            The parent steps.
        """
        var out = List[Int]()
        var edge = self.first_in[index]
        while edge != NONE:
            out.append(self.edges[edge].parent)
            edge = self.edges[edge].next_in
        return out^

    def is_descendant_of(self, descendant: Int, ancestor: Int) -> Bool:
        """Return True if a path leads from one step to another, as
        `petgraph` `has_path_connecting`.

        Args:
            descendant: The step to reach.
            ancestor: The step to start from.

        Returns:
            Whether `descendant` is reachable from `ancestor`; True when
            they are the same step.
        """
        var seen = List[Bool](length=len(self.alive), fill=False)
        var stack: List[Int] = [ancestor]
        seen[ancestor] = True
        while len(stack) > 0:
            var current = stack.pop()
            if current == descendant:
                return True
            var edge = self.first_out[current]
            while edge != NONE:
                var child = self.edges[edge].child
                if not seen[child]:
                    seen[child] = True
                    stack.append(child)
                edge = self.edges[edge].next_out
        return False

    def is_ancestor_or_descendant(self, a: Int, b: Int) -> Bool:
        """Return True if either step reaches the other.

        Args:
            a: A step.
            b: Another step.

        Returns:
            Whether they are on one path.
        """
        return self.is_descendant_of(a, b) or self.is_descendant_of(b, a)

    def bfs_order(self, root: Int) -> List[Int]:
        """Return the steps reachable from a step, breadth first, as
        `petgraph` `Bfs`.

        Args:
            root: The first step.

        Returns:
            The steps in visit order; empty when `root` does not exist.
        """
        var out = List[Int]()
        if not self.contains_step(root):
            return out^
        var seen = List[Bool](length=len(self.alive), fill=False)
        seen[root] = True
        out.append(root)
        var head = 0
        while head < len(out):
            var current = out[head]
            head += 1
            var edge = self.first_out[current]
            while edge != NONE:
                var child = self.edges[edge].child
                if not seen[child]:
                    seen[child] = True
                    out.append(child)
                edge = self.edges[edge].next_out
        return out^

    def is_condition_on_step(
        self, step_index: Int, requiring_step_index: Int, cond: Cond
    ) -> Bool:
        """Return True if a step, or the step that requires it, has a
        condition, as upstream `is_condition_on_step`.

        Args:
            step_index: The step.
            requiring_step_index: The requiring step, or `NONE`.
            cond: The condition.

        Returns:
            Whether either step's condition equals `cond`.
        """
        if (
            self.contains_step(step_index)
            and self.steps[step_index].condition == cond
        ):
            return True
        return (
            requiring_step_index != NONE
            and self.contains_step(requiring_step_index)
            and self.steps[requiring_step_index].condition == cond
        )

    def collect_variable_usages(mut self, store: Store):
        """Set the variables each step's output uses, as upstream
        `collect_variable_usages`.

        Args:
            store: The store.
        """
        for index in self.step_indices():
            var usages = self.steps[index].output.variable_usages(store)
            if len(usages) > 0:
                self.steps[index].variable_usages = usages^
                self.steps[index].has_variable_usages = True

    def roots(self) -> List[Int]:
        """Return the steps with no parent, as upstream `find_graph_roots`.

        Returns:
            The steps, in index order.
        """
        var out = List[Int]()
        for index in self.step_indices():
            if self.first_in[index] == NONE:
                out.append(index)
        return out^

    def text(self, store: Store) -> String:
        """Return the graph as upstream `Display`: the steps, then the
        tree under the root.

        Args:
            store: The store with the names.

        Returns:
            The text.
        """
        var out = String("Nodes:\n")
        for index in self.step_indices():
            if index == 0:
                continue
            out += "["
            out += String(index)
            out += "] "
            out += self.steps[index].text(store)
            out += "\n"
        out += "\nTree:\n"
        var roots = self.roots()
        if len(roots) == 0:
            out += "Fetch step graph is empty or has no roots.\n"
            return out^
        if len(roots) > 1:
            out += "Fetch step graph has multiple roots:\n"
            return out^
        # Upstream pushes the root's children to the front and pops the
        # back, then pushes grandchildren to the back.
        var queue_steps = List[Int]()
        var queue_depths = List[Int]()
        for child in self.child_steps(roots[0]):
            queue_steps.insert(0, child)
            queue_depths.insert(0, 0)
        while len(queue_steps) > 0:
            var step = queue_steps.pop()
            var depth = queue_depths.pop()
            for _ in range(depth):
                out += "  "
            out += "["
            out += String(step)
            out += "]\n"
            for child in self.child_steps(step):
                queue_steps.append(child)
                queue_depths.append(depth + 1)
        return out^

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Fetch operation minification: a repeated selection set becomes a
fragment.

Port of Hive Router `1a29df9`
`bin/router/src/query_planner/ast/minification/`: `mod.rs`, `stats.rs`,
`transform.rs`, `selection_id.rs` and `error.rs`.

**Differences from upstream.** Upstream identifies a selection set by a
64-bit order-independent hash of its type and items (`SelectionId`). This
port uses a canonical key: the type and the sorted keys of the items. Two
sets have the same key exactly when upstream hashes them the same way,
except for hash collisions, and except that upstream's XOR fold lets two
equal items in one set cancel out.
"""

from gql_router.ast import NONE, ItemKind
from gql_router.federation_spec import OperationKind
from gql_router.fetch_operation import FetchDocument, FragmentDefinition
from gql_router.operation import OperationDefinition
from gql_router.store import Store
from gql_router.supergraph_state import SupergraphState

comptime ALPHABET = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
"""The letters of fragment names, as upstream `ALPHABET`."""


def generate_fragment_name(mut index: Int) -> String:
    """Return the fragment name of an index and advance it, as upstream
    `generate_fragment_name`.

    Args:
        index: The next index; it grows by one.

    Returns:
        `a` to `Z`, then `ab`, `bb`, and so on, least significant first.
    """
    var i = index
    index += 1
    var size = ALPHABET.byte_length()
    if i < size:
        return String(ALPHABET[byte=i])
    var name = String()
    while i > 0:
        name += ALPHABET[byte=i % size]
        i //= size
    return name^


def selection_id(store: Store, type_name: Int, set: Int) -> String:
    """Return the identity of a typed selection set, as upstream
    `generate_selection_id`.

    Args:
        store: The store.
        type_name: The type of the set, as a symbol.
        set: The set.

    Returns:
        A key that does not depend on the order of the items.
    """
    var out = String(type_name)
    out += ":"
    out += _set_key(store, set)
    return out^


def _set_key(store: Store, set: Int) -> String:
    """Return the order-independent key of a set's items."""
    var keys = List[String]()
    var child = store.items[set].first
    while child != NONE:
        keys.append(_item_key(store, child))
        child = store.items[child].next
    sort(keys)
    var out = String(len(keys))
    out += "["
    for key in keys:
        out += key
        out += ";"
    out += "]"
    return out^


def _item_key(store: Store, item: Int) -> String:
    """Return the key of one item: kind, names, conditions and children."""
    ref found = store.items[item]
    var out = String()
    if found.kind == ItemKind.SPREAD:
        out += "S"
        out += String(found.name)
        return out^
    if found.kind == ItemKind.FIELD:
        out += "F"
        out += String(found.name)
        out += ","
        out += String(found.alias)
        out += ","
        out += String(found.args)
        out += ","
        out += "1" if found.omit else "0"
    else:
        out += "I"
        out += String(found.name)
    out += ","
    out += String(found.include)
    out += ","
    out += String(found.skip)
    out += _set_key(store, item)
    return out^


struct Stats(Movable):
    """How often each typed selection set occurs, as upstream `Stats`."""

    var state: Dict[String, Int]
    """The occurrences of each selection id."""
    var contains_duplicates: Bool
    """Whether a set occurs more than once."""

    def __init__(out self):
        """Start with no set."""
        self.state = Dict[String, Int]()
        self.contains_duplicates = False

    def has_duplicates(self) -> Bool:
        """Return True if a set occurs more than once.

        Returns:
            Whether there is a duplicate.
        """
        return self.contains_duplicates

    def is_duplicated(self, key: String) -> Bool:
        """Return True if a set occurs more than once.

        Args:
            key: The selection id.

        Returns:
            Whether the count is above one.
        """
        var found = self.state.get(key)
        return Bool(found) and found.value() > 1

    def increase(mut self, key: String) -> Int:
        """Count one more occurrence of a set.

        Args:
            key: The selection id.

        Returns:
            The new count.
        """
        var count = self.state.get(key).or_else(0) + 1
        self.state[key] = count
        if count > 1:
            self.contains_duplicates = True
        return count

    @staticmethod
    def from_operation(
        store: Store, set: Int, state: SupergraphState, root_type_name: Int
    ) raises -> Stats:
        """Count the sets of an operation, as upstream
        `Stats::from_operation`.

        Args:
            store: The store.
            set: The root selection set.
            state: The supergraph.
            root_type_name: The root type, as a symbol.

        Returns:
            The counts.

        Raises:
            Error: When a type or a field is not in the supergraph, or on a
                fragment spread.
        """
        var stats = Stats()
        _walk_and_collect_stats(stats, store, state, set, root_type_name)
        return stats^


def _is_introspection(store: Store, item: Int) -> Bool:
    """Return upstream `is_introspection_field`: the name starts `__`."""
    return store.name(store.items[item].name).startswith("__")


def _child_type(
    store: Store, state: SupergraphState, type_name: Int, field: Int
) raises -> Int:
    """Return the named type of a field, or raise `FieldNotFound`. The
    stats walk has already checked that the type exists."""
    var definition = state.definition(type_name)
    var name = store.items[field].name
    var index = NONE
    if state.definitions[definition].is_composite_type():
        index = state.field(type_name, name)
    if index == NONE:
        raise Error(
            "Field '"
            + store.name(name)
            + "' not found in type '"
            + store.name(type_name)
            + "'"
        )
    return state.definitions[definition].fields[index].field_type.name


def _walk_and_collect_stats(
    mut stats: Stats,
    store: Store,
    state: SupergraphState,
    set: Int,
    type_name: Int,
) raises:
    """Count a set and the sets below it, as upstream
    `walk_and_collect_stats`."""
    if store.is_empty(set):
        return
    if stats.increase(selection_id(store, type_name, set)) > 1:
        return
    if state.definition(type_name) == NONE:
        raise Error("Type not found: " + store.name(type_name))
    var item = store.items[set].first
    while item != NONE:
        var current = item
        item = store.items[item].next
        var kind = store.items[current].kind
        if kind == ItemKind.FIELD:
            if _is_introspection(store, current):
                continue
            if store.name(store.items[current].name) == "_entities":
                var inner = store.items[current].first
                while inner != NONE:
                    var entry = inner
                    inner = store.items[inner].next
                    _entities_stats(stats, store, state, entry, type_name)
                continue
            var child_type = _child_type(store, state, type_name, current)
            _walk_and_collect_stats(stats, store, state, current, child_type)
        elif kind == ItemKind.FRAGMENT:
            _walk_and_collect_stats(
                stats, store, state, current, store.items[current].name
            )
        else:
            raise Error("Unsupported fragment spread")


def _entities_stats(
    mut stats: Stats,
    store: Store,
    state: SupergraphState,
    inner: Int,
    type_name: Int,
) raises:
    """Count one item of an `_entities` field."""
    var inner_kind = store.items[inner].kind
    if inner_kind == ItemKind.FIELD:
        if _is_introspection(store, inner):
            return
        raise Error(
            "Unsupported field in `_entities`: "
            + store.name(type_name)
            + "."
            + store.name(store.items[inner].name)
        )
    elif inner_kind == ItemKind.FRAGMENT:
        _walk_and_collect_stats(
            stats, store, state, inner, store.items[inner].name
        )
    else:
        raise Error("Unsupported fragment spread")


struct _Fragments(Movable):
    """The fragments made so far, by selection id."""

    var ids: Dict[String, Int]
    """The index of each selection id's fragment."""
    var definitions: List[FragmentDefinition]
    """The fragments, in creation order."""
    var next_name: Int
    """The index of the next fragment name."""

    def __init__(out self):
        """Start with no fragment."""
        self.ids = Dict[String, Int]()
        self.definitions = List[FragmentDefinition]()
        self.next_name = 0


def minify_operation(
    mut store: Store, var operation: OperationDefinition, state: SupergraphState
) raises -> FetchDocument:
    """Replace each repeated selection set with a fragment spread, as
    upstream `minify_operation`.

    Args:
        store: The store.
        operation: The operation.
        state: The supergraph.

    Returns:
        The operation and its fragments, sorted by name. The operation is
        unchanged when no set repeats.

    Raises:
        Error: `Type not found for operation kind: mutation` and the other
            upstream `MinificationError` texts.
    """
    var root_type_name = state.query_type
    if operation.kind == OperationKind.MUTATION:
        if state.mutation_type == NONE:
            raise Error("Type not found for operation kind: mutation")
        root_type_name = state.mutation_type
    elif operation.kind == OperationKind.SUBSCRIPTION:
        if state.subscription_type == NONE:
            raise Error("Type not found for operation kind: subscription")
        root_type_name = state.subscription_type
    var stats = Stats.from_operation(
        store, operation.selection_set, state, root_type_name
    )
    if not stats.has_duplicates():
        return FetchDocument(operation^, List[FragmentDefinition]())
    var fragments = _Fragments()
    var set = _transform_selection_set(
        store, state, stats, fragments, operation.selection_set, root_type_name
    )
    operation.selection_set = set
    # Upstream sorts the fragments by name.
    var sorted = List[FragmentDefinition]()
    var index = 0
    while index < len(fragments.definitions):
        ref fragment = fragments.definitions[index]
        index += 1
        var at = len(sorted)
        while at > 0 and store.less(fragment.name, sorted[at - 1].name):
            at -= 1
        sorted.insert(at, fragment.copy())
    return FetchDocument(operation^, sorted^)


def _transform_selection_set(
    mut store: Store,
    state: SupergraphState,
    stats: Stats,
    mut fragments: _Fragments,
    set: Int,
    type_name: Int,
) raises -> Int:
    """Return a new set: one spread when the set repeats, or the
    transformed items, as upstream `transform_selection_set`."""
    var id = selection_id(store, type_name, set)
    var out = store.new_set()
    if stats.is_duplicated(id):
        var name = _get_or_create_fragment(
            store, state, stats, fragments, id, type_name, set
        )
        store.append(out, store.add_item(ItemKind.SPREAD, name))
        return out
    for item in _transform_selection_set_items(
        store, state, stats, fragments, set, type_name
    ):
        store.append(out, item)
    return out


def _with_children(mut store: Store, item: Int, set: Int) -> Int:
    """Return a copy of one item, without its children, that owns the
    children of `set`."""
    var found = store.items[item]
    var copy = store.add_item(
        found.kind,
        found.name,
        found.alias,
        found.args,
        found.skip,
        found.include,
        found.omit,
    )
    store.items[copy].directives = found.directives
    store.set_children(copy, store.children(set))
    return copy


def _transform_selection_set_items(
    mut store: Store,
    state: SupergraphState,
    stats: Stats,
    mut fragments: _Fragments,
    set: Int,
    type_name: Int,
) raises -> List[Int]:
    """Return the transformed items of a set, as upstream
    `transform_selection_set_items`."""
    var out = List[Int]()
    for item in store.children(set):
        var kind = store.items[item].kind
        if kind == ItemKind.FIELD:
            out.append(
                _transform_field(
                    store, state, stats, fragments, item, type_name
                )
            )
        else:
            # The stats walk refuses a spread, so this is an inline
            # fragment.
            var inner = _transform_selection_set(
                store, state, stats, fragments, item, store.items[item].name
            )
            out.append(_with_children(store, item, inner))
    return out^


def _transform_field(
    mut store: Store,
    state: SupergraphState,
    stats: Stats,
    mut fragments: _Fragments,
    field: Int,
    type_name: Int,
) raises -> Int:
    """Return a transformed field, as upstream `transform_field`."""
    if _is_introspection(store, field):
        return store.copy_item(field)
    if store.name(store.items[field].name) == "_entities":
        # The stats walk refuses a spread and a field other than an
        # introspection field in `_entities`.
        var entities = store.new_set()
        var inner = store.items[field].first
        while inner != NONE:
            var entry = inner
            inner = store.items[inner].next
            if store.items[entry].kind == ItemKind.FIELD:
                store.append(entities, store.copy_item(entry))
                continue
            var selections = _transform_selection_set(
                store,
                state,
                stats,
                fragments,
                entry,
                store.items[entry].name,
            )
            store.append(entities, _with_children(store, entry, selections))
        return _with_children(store, field, entities)
    var child_type = _child_type(store, state, type_name, field)
    var selections = _transform_selection_set(
        store, state, stats, fragments, field, child_type
    )
    return _with_children(store, field, selections)


def _get_or_create_fragment(
    mut store: Store,
    state: SupergraphState,
    stats: Stats,
    mut fragments: _Fragments,
    id: String,
    type_name: Int,
    set: Int,
) raises -> Int:
    """Return the name of the fragment for a repeated set, making it on
    first use, as upstream `get_or_create_fragment`."""
    var found = fragments.ids.get(id)
    if found:
        return fragments.definitions[found.value()].name
    var name = store.sym(generate_fragment_name(fragments.next_name))
    var index = len(fragments.definitions)
    fragments.definitions.append(
        FragmentDefinition(name, store.new_set(), type_name)
    )
    fragments.ids[id] = index
    var items = _transform_selection_set_items(
        store, state, stats, fragments, set, type_name
    )
    var body = store.new_set()
    var at = 0
    while at < len(items):
        store.append(body, items[at])
        at += 1
    fragments.definitions[index].selection_set = body
    return name

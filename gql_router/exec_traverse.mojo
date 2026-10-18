# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Find the values at a flatten path of the response data.

Port of `traverse_and_callback` and `traverse_and_callback_mut` of Hive
Router `1a29df9` `bin/router/src/executor/utils/traverse.rs`.

A field step goes into the first member with that key. A list step goes
into each item. A type condition keeps an object whose `__typename` is
absent or satisfies one of the types; on a list it checks each item. At
the end of the path, a list gives each of its items, and any other value
gives itself. A missing field, or a value of the wrong kind, gives
nothing.

**Differences from upstream.** Upstream calls a closure for each value.
This port appends each value to `TraverseTargets`, in the same order, with
its error path when asked. The caller then merges into the values; node
indices stay valid while the data grows.
"""

from gql_json.value import NO_NODE, JsonDocument, JsonKind
from gql_router.exec_value import object_get, string_text, typename_node
from gql_router.graphql_error import (
    ErrorPath,
    ErrorSegment,
    field_segment,
    index_segment,
)
from gql_router.plan_nodes import FlattenNodePath, PathSegmentKind
from gql_router.schema_metadata import PossibleTypes
from gql_router.store import Store


struct TraverseTargets(Movable):
    """The values a path reaches, in walk order."""

    var nodes: List[Int]
    """The values."""
    var paths: List[ErrorPath]
    """The response path of each value, when `collect_paths` is set."""
    var collect_paths: Bool
    """Whether to record the paths."""

    def __init__(out self, collect_paths: Bool):
        """Start with no values.

        Args:
            collect_paths: Whether to record the response path of each
                value.
        """
        self.nodes = List[Int]()
        self.paths = List[ErrorPath]()
        self.collect_paths = collect_paths


def satisfies_any(
    store: Store,
    possible_types: PossibleTypes,
    type_name: StringSlice,
    types: Int,
) -> Bool:
    """Return True if a type satisfies one type of an interned type set,
    as upstream `entity_satisfies_any_type_condition`.

    Args:
        store: The store with the type set.
        possible_types: The possible types of each abstract type.
        type_name: The type of the object.
        types: The interned type set.

    Returns:
        Whether one condition holds.
    """
    for name in store.type_sets[types]:
        if possible_types.entity_satisfies_type_condition(
            type_name, store.name(name)
        ):
            return True
    return False


def traverse(
    document: JsonDocument,
    start: Int,
    path: FlattenNodePath,
    store: Store,
    possible_types: PossibleTypes,
    mut targets: TraverseTargets,
):
    """Find the values at a path, as upstream `traverse_and_callback_mut`.

    Args:
        document: The response data.
        start: The value the path starts at.
        path: The flatten path.
        store: The store with the path names.
        possible_types: The possible types of each abstract type.
        targets: Where the values go.
    """
    var current = List[ErrorSegment]()
    _walk(document, start, path, 0, store, possible_types, current, targets)


def _record(mut targets: TraverseTargets, node: Int, current: List[ErrorSegment]):
    """Add one value and, when asked, its path."""
    targets.nodes.append(node)
    if targets.collect_paths:
        targets.paths.append(ErrorPath(current.copy()))


def _push(mut current: List[ErrorSegment], collect: Bool, var segment: ErrorSegment):
    """Add a step to the walk path when paths are collected."""
    if collect:
        current.append(segment^)


def _pop(mut current: List[ErrorSegment], collect: Bool):
    """Remove the last step of the walk path."""
    if collect:
        _ = current.pop()


def _walk(
    document: JsonDocument,
    node: Int,
    path: FlattenNodePath,
    at: Int,
    store: Store,
    possible_types: PossibleTypes,
    mut current: List[ErrorSegment],
    mut targets: TraverseTargets,
):
    """Walk the rest of a path from one value."""
    var kind = document.kind(node)
    var collect = targets.collect_paths
    if at == len(path.segments):
        if kind != JsonKind.ARRAY:
            _record(targets, node, current)
            return
        var item = document.first(node)
        var index = 0
        while item != NO_NODE:
            _push(current, collect, index_segment(index))
            _record(targets, item, current)
            _pop(current, collect)
            item = document.next(item)
            index += 1
        return
    var segment = path.segments[at]
    if segment.kind == PathSegmentKind.LIST:
        if kind != JsonKind.ARRAY:
            return
        var item = document.first(node)
        var index = 0
        while item != NO_NODE:
            _push(current, collect, index_segment(index))
            _walk(document, item, path, at + 1, store, possible_types, current, targets)
            _pop(current, collect)
            item = document.next(item)
            index += 1
        return
    if segment.kind == PathSegmentKind.FIELD:
        if kind != JsonKind.OBJECT:
            return
        var name = store.name(segment.name)
        var found = object_get(document, node, name)
        if found == NO_NODE:
            return
        _push(current, collect, field_segment(name))
        _walk(document, found, path, at + 1, store, possible_types, current, targets)
        _pop(current, collect)
        return
    if kind == JsonKind.OBJECT:
        var type_node = typename_node(document, node)
        if type_node == NO_NODE or satisfies_any(
            store, possible_types, string_text(document, type_node), segment.types
        ):
            _walk(document, node, path, at + 1, store, possible_types, current, targets)
        return
    if kind != JsonKind.ARRAY:
        return
    var item = document.first(node)
    var index = 0
    while item != NO_NODE:
        _push(current, collect, index_segment(index))
        _walk(document, item, path, at, store, possible_types, current, targets)
        _pop(current, collect)
        item = document.next(item)
        index += 1

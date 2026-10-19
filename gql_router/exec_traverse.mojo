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
from gql_router.exec_value import object_get, type_satisfies, typename_node
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

    def take_nodes(deinit self) -> List[Int]:
        """Return the values.

        Returns:
            The values, in walk order.
        """
        return self.nodes^


def satisfies_any(
    store: Store,
    possible_types: PossibleTypes,
    document: JsonDocument,
    type_node: Int,
    types: Int,
) -> Bool:
    """Return True if a type satisfies one type of an interned type set,
    as upstream `entity_satisfies_any_type_condition`.

    Args:
        store: The store with the type set.
        possible_types: The possible types of each abstract type.
        document: The response data.
        type_node: The `__typename` string of the object.
        types: The interned type set.

    Returns:
        Whether one condition holds.
    """
    ref names = store.type_sets[types]
    var index = 0
    while index < len(names):
        if type_satisfies(
            possible_types, document, type_node, store.name(names[index])
        ):
            return True
        index += 1
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
    var walker = _Walker(
        document,
        path,
        store,
        possible_types,
        Pointer(to=targets).unsafe_origin_cast[MutUntrackedOrigin](),
        Pointer(to=current).unsafe_origin_cast[MutUntrackedOrigin](),
    )
    walker.walk(start, 0)
    _ = current^


@fieldwise_init
struct _Walker[
    d: Origin[mut=False],
    p: Origin[mut=False],
    s: Origin[mut=False],
    t: Origin[mut=False],
](ImplicitlyCopyable):
    """The inputs of one walk and pointers to its outputs.

    The recursive walk takes this handle of six pointers, so that each call
    does not get the fields of every input as arguments.
    """

    var document: Pointer[JsonDocument, Self.d]
    """The response data."""
    var path: Pointer[FlattenNodePath, Self.p]
    """The flatten path."""
    var store: Pointer[Store, Self.s]
    """The store with the path names."""
    var possible_types: Pointer[PossibleTypes, Self.t]
    """The possible types of each abstract type."""
    var targets: Pointer[TraverseTargets, MutUntrackedOrigin]
    """Where the values go."""
    var current: Pointer[List[ErrorSegment], MutUntrackedOrigin]
    """The response path of the value being walked, when paths are
    collected."""

    def __init__(
        out self,
        ref[Self.d] document: JsonDocument,
        ref[Self.p] path: FlattenNodePath,
        ref[Self.s] store: Store,
        ref[Self.t] possible_types: PossibleTypes,
        targets: Pointer[TraverseTargets, MutUntrackedOrigin],
        current: Pointer[List[ErrorSegment], MutUntrackedOrigin],
    ):
        """Start a walk.

        Args:
            document: The response data.
            path: The flatten path.
            store: The store with the path names.
            possible_types: The possible types of each abstract type.
            targets: Where the values go.
            current: The walk path.
        """
        self.document = Pointer(to=document)
        self.path = Pointer(to=path)
        self.store = Pointer(to=store)
        self.possible_types = Pointer(to=possible_types)
        self.targets = targets
        self.current = current

    def record(self, node: Int):
        """Add one value and, when asked, its path.

        Args:
            node: The value.
        """
        self.targets[].nodes.append(node)
        if self.targets[].collect_paths:
            self.targets[].paths.append(ErrorPath(self.current[].copy()))

    def items(self, node: Int, at: Int, last: Bool):
        """Walk each item of a list.

        Args:
            node: The list.
            at: The path segment the items continue at.
            last: Whether the items are the values.
        """
        var collect = self.targets[].collect_paths
        var item = self.document[].first(node)
        var index = 0
        while item != NO_NODE:
            if collect:
                self.current[].append(index_segment(index))
            if last:
                self.record(item)
            else:
                self.walk(item, at)
            if collect:
                _ = self.current[].pop()
            item = self.document[].next(item)
            index += 1

    def walk(self, node: Int, at: Int):
        """Walk the rest of a path from one value.

        Args:
            node: The value.
            at: The path segment to take next.
        """
        ref document = self.document[]
        var kind = document.kind(node)
        if at == len(self.path[].segments):
            if kind != JsonKind.ARRAY:
                self.record(node)
                return
            self.items(node, at, True)
            return
        ref segment = self.path[].segments[at]
        if segment.kind == PathSegmentKind.LIST:
            if kind == JsonKind.ARRAY:
                self.items(node, at + 1, False)
            return
        if segment.kind == PathSegmentKind.FIELD:
            if kind != JsonKind.OBJECT:
                return
            var name = self.store[].name(segment.name)
            var found = object_get(document, node, name)
            if found == NO_NODE:
                return
            var collect = self.targets[].collect_paths
            if collect:
                self.current[].append(field_segment(String(name)))
            self.walk(found, at + 1)
            if collect:
                _ = self.current[].pop()
            return
        if kind == JsonKind.OBJECT:
            var type_node = typename_node(document, node)
            if type_node == NO_NODE or satisfies_any(
                self.store[],
                self.possible_types[],
                document,
                type_node,
                segment.types,
            ):
                self.walk(node, at + 1)
            return
        if kind == JsonKind.ARRAY:
            self.items(node, at, False)

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Walk a response path and merge a fetch into the values there.

Port of `traverse_and_callback_mut` in Hive Router `1a29df9`
`bin/router/src/executor/utils/traverse.rs`, and the root and reentry
merge in `process_job_result`.

An empty path visits the value. On an array, it visits each item. A
field steps into that object field. `@` steps into each list item. A
type condition stays on the same object when `__typename` is absent or
matches, and checks each item of an array again. `merge_fetch_data`
deep-merges the fetch into every visited value.

**Differences from upstream.** The recorded path is text, such as
`items.0`. The walk does not mutate the value except through
`merge_fetch_data`.
"""

from gql_json.parser import parse
from gql_json.value import NO_NODE, JsonDocument, JsonKind
from gql_json.writer import stringify
from gql_router.graphql_error import (
    ErrorPath,
    ErrorSegment,
    field_segment,
    index_segment,
)
from gql_router.plan_nodes import FlattenNodePath, PathSegmentKind
from gql_router.response_merge import deep_merge
from gql_router.rewrite import PossibleTypes, entity_satisfies
from gql_router.store import Store


@fieldwise_init
struct _Work(Copyable, Movable):
    """One step of the path walk."""

    var op: Int
    """`0` walks, `1` pops, `2` pushes an index, `3` pushes a field."""
    var node: Int
    """The JSON node for a walk."""
    var at: Int
    """The path step for a walk."""
    var extra: Int
    """The list index, or the field-name slot."""


struct PathVisit(Movable):
    """The values a response path visits."""

    var nodes: List[Int]
    """The visited JSON nodes."""
    var paths: List[String]
    """The error path of each node, such as `items.0`."""

    def __init__(out self):
        """Start an empty visit."""
        self.nodes = List[Int]()
        self.paths = List[String]()


def visit_response_path(
    store: Store,
    document: JsonDocument,
    node: Int,
    path: FlattenNodePath,
    possible: PossibleTypes,
) -> PathVisit:
    """Visit every value at a response path.

    Args:
        store: The store with the field and type names.
        document: The JSON document.
        node: The value where the path starts.
        path: The response path.
        possible: The concrete types of each abstract type.

    Returns:
        The visited nodes and their error paths. A missing field adds
        nothing.
    """
    var visit = PathVisit()
    var error = ErrorPath(List[ErrorSegment]())
    var work = List[_Work]()
    var fields = List[String]()
    work.append(_Work(0, node, 0, 0))
    while len(work) > 0:
        var step = work.pop()
        if step.op == 1:
            if len(error.segments) > 0:
                _ = error.segments.pop()
            continue
        if step.op == 2:
            error.segments.append(index_segment(step.extra))
            continue
        if step.op == 3:
            var name = String("")
            if step.extra >= 0 and step.extra < len(fields):
                name = String(fields[step.extra])
            error.segments.append(field_segment(name))
            continue
        _walk(
            store,
            document,
            possible,
            path,
            step.node,
            step.at,
            error,
            visit,
            work,
            fields,
        )
    return visit^


def merge_fetch_data(
    mut target: JsonDocument,
    source: JsonDocument,
    path: FlattenNodePath,
    store: Store,
    possible: PossibleTypes,
):
    """Deep-merge a fetch into every value at a path.

    Args:
        target: The response being built. The path starts at its root.
        source: The fetch data. Its root is merged in.
        path: The response path. Empty when the fetch is at the root.
        store: The store with the field and type names.
        possible: The concrete types of each abstract type.
    """
    if len(path.segments) == 0:
        var copy = target.add_copy(source, source.root)
        deep_merge(target, target.root, copy)
        return
    var visit = visit_response_path(store, target, target.root, path, possible)
    for index in range(len(visit.nodes)):
        var copy = target.add_copy(source, source.root)
        deep_merge(target, visit.nodes[index], copy)


def path_list(visit: PathVisit) -> String:
    """Join visited error paths with spaces.

    Args:
        visit: The visit.

    Returns:
        The paths in visit order. An empty path is an empty entry.
    """
    var text = String("")
    for index in range(len(visit.paths)):
        if index > 0:
            text += " "
        text += visit.paths[index]
    return text^


def _walk(
    store: Store,
    document: JsonDocument,
    possible: PossibleTypes,
    path: FlattenNodePath,
    node: Int,
    at: Int,
    mut error: ErrorPath,
    mut visit: PathVisit,
    mut work: List[_Work],
    mut fields: List[String],
):
    """Continue the walk at one value and one path step.

    Args:
        store: The store with the field and type names.
        document: The JSON document.
        possible: The concrete types of each abstract type.
        path: The response path.
        node: The current value.
        at: The path step. Past the end, the value is visited.
        error: The error path built so far.
        visit: The visited nodes.
        work: The remaining steps.
        fields: Field names queued by later steps.
    """
    if at >= len(path.segments):
        if document.kind(node) == JsonKind.ARRAY:
            var items = document.children(node)
            for index in range(len(items)):
                error.segments.append(index_segment(index))
                _record(visit, items[index], error)
                _ = error.segments.pop()
            return
        _record(visit, node, error)
        return
    ref segment = path.segments[at]
    if segment.kind == PathSegmentKind.LIST:
        if document.kind(node) != JsonKind.ARRAY:
            return
        var items = document.children(node)
        var index = len(items)
        while index > 0:
            index -= 1
            _later(work, 1, 0, 0, 0)
            _later(work, 0, items[index], at + 1, 0)
            _later(work, 2, 0, 0, index)
        return
    if segment.kind == PathSegmentKind.FIELD:
        if document.kind(node) != JsonKind.OBJECT:
            return
        var child = document.find(node, store.name(segment.name))
        if child == NO_NODE:
            return
        fields.append(String(store.name(segment.name)))
        _later(work, 1, 0, 0, 0)
        _later(work, 0, child, at + 1, 0)
        _later(work, 3, 0, 0, len(fields) - 1)
        return
    if document.kind(node) == JsonKind.ARRAY:
        var items = document.children(node)
        var index = len(items)
        while index > 0:
            index -= 1
            _later(work, 1, 0, 0, 0)
            _later(work, 0, items[index], at, 0)
            _later(work, 2, 0, 0, index)
        return
    if document.kind(node) == JsonKind.OBJECT and _type_ok(
        store, document, node, segment.types, possible
    ):
        _later(work, 0, node, at + 1, 0)


def _record(mut visit: PathVisit, node: Int, error: ErrorPath):
    """Record one visited value.

    Args:
        visit: The visit.
        node: The JSON node.
        error: The error path.
    """
    visit.nodes.append(node)
    visit.paths.append(_show(error))


def _later(mut work: List[_Work], op: Int, node: Int, at: Int, extra: Int):
    """Queue a step that runs after the steps already queued.

    Args:
        work: The stack. The last step runs next.
        op: The step kind.
        node: The JSON node.
        at: The path step.
        extra: The list index or field-name slot.
    """
    work.append(_Work(op, node, at, extra))


def _show(error: ErrorPath) -> String:
    """Write an error path with dots between steps.

    Args:
        error: The error path.

    Returns:
        Text such as `users.0.posts.1`.
    """
    var text = String("")
    for index in range(len(error.segments)):
        if index > 0:
            text += "."
        ref segment = error.segments[index]
        if segment.kind.value == 1:
            text += String(segment.index)
        else:
            text += segment.field
    return text^


def _type_ok(
    store: Store,
    document: JsonDocument,
    node: Int,
    types: Int,
    possible: PossibleTypes,
) -> Bool:
    """Return True when an object's type meets a type set.

    Args:
        store: The store with the type names.
        document: The JSON document.
        node: The object.
        types: The interned type set.
        possible: The concrete types of each abstract type.

    Returns:
        True when `__typename` is absent or not a string, or it satisfies
        one name in the set.
    """
    var type_node = document.find(node, "__typename")
    if type_node == NO_NODE or document.kind(type_node) != JsonKind.STRING:
        return True
    if types < 0 or types >= len(store.type_sets):
        return False
    var type_name = document.string_value(type_node)
    ref names = store.type_sets[types]
    for index in range(len(names)):
        if entity_satisfies(possible, type_name, store.name(names[index])):
            return True
    return False


def merged_text(
    target_text: String,
    source_text: String,
    path: FlattenNodePath,
    store: Store,
    possible: PossibleTypes,
) raises -> String:
    """Merge two JSON texts and return the target.

    Args:
        target_text: The response JSON.
        source_text: The fetch JSON.
        path: The response path.
        store: The store with the field and type names.
        possible: The concrete types of each abstract type.

    Returns:
        The merged response JSON.

    Raises:
        Error: When either text is not JSON.
    """
    var target = parse_json(target_text)
    var source = parse_json(source_text)
    merge_fetch_data(target, source, path, store, possible)
    return stringify(target, target.root)


def parse_json(text: String) raises -> JsonDocument:
    """Parse one JSON value.

    Args:
        text: The JSON text.

    Returns:
        The document.

    Raises:
        Error: When the text is not JSON.
    """
    try:
        return parse(text)
    except e:
        raise Error("invalid JSON: " + String(e))

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Merge one JSON response value into another.

Port of `deep_merge` in Hive Router `1a29df9`
`bin/router/src/executor/response/merge.rs`.

A null source leaves the target unchanged. Two objects merge by key.
Shared keys merge again. New keys are appended in source order. Two
arrays merge item by item, and the longer side keeps its extra items.
Any other pair replaces the target with the source.
"""

from gql_json.value import (
    FLAG_KEY_DECODED,
    FLAG_KEY_ESCAPED,
    NO_NODE,
    JsonDocument,
    JsonKind,
)


def deep_merge(mut document: JsonDocument, target: Int, source: Int):
    """Merge `source` into `target`.

    Args:
        document: The JSON document that holds both values.
        target: The value that stays.
        source: The value to merge in.
    """
    var targets = List[Int]()
    var sources = List[Int]()
    targets.append(target)
    sources.append(source)
    var index = 0
    while index < len(targets):
        _merge_one(document, targets[index], sources[index], targets, sources)
        index += 1


def _merge_one(
    mut document: JsonDocument,
    target: Int,
    source: Int,
    mut targets: List[Int],
    mut sources: List[Int],
):
    """Merge one pair, and queue nested pairs.

    Args:
        document: The JSON document.
        target: The value that stays.
        source: The value to merge in.
        targets: The queue of target nodes.
        sources: The queue of source nodes.
    """
    if document.kind(source) == JsonKind.NULL:
        return
    var target_kind = document.kind(target)
    var source_kind = document.kind(source)
    if target_kind == JsonKind.OBJECT and source_kind == JsonKind.OBJECT:
        _merge_objects(document, target, source, targets, sources)
        return
    if target_kind == JsonKind.ARRAY and source_kind == JsonKind.ARRAY:
        _merge_arrays(document, target, source, targets, sources)
        return
    _replace(document, target, source)


def _merge_objects(
    mut document: JsonDocument,
    target: Int,
    source: Int,
    mut targets: List[Int],
    mut sources: List[Int],
):
    """Merge two objects by key.

    Args:
        document: The JSON document.
        target: The object that stays.
        source: The object to merge in.
        targets: The queue of target nodes.
        sources: The queue of source nodes.
    """
    if document.length(source) == 0:
        return
    if document.length(target) == 0:
        _steal_children(document, target, source)
        return
    var child = document.first(source)
    while child != NO_NODE:
        var nxt = document.next(child)
        var found = document.find(target, document.key(child))
        if found == NO_NODE:
            _detach(document, source, child)
            _append(document, target, child)
        else:
            targets.append(found)
            sources.append(child)
        child = nxt


def _merge_arrays(
    mut document: JsonDocument,
    target: Int,
    source: Int,
    mut targets: List[Int],
    mut sources: List[Int],
):
    """Merge two arrays item by item.

    Args:
        document: The JSON document.
        target: The array that stays.
        source: The array to merge in.
        targets: The queue of target nodes.
        sources: The queue of source nodes.
    """
    var left = document.first(target)
    var right = document.first(source)
    while left != NO_NODE and right != NO_NODE:
        targets.append(left)
        sources.append(right)
        left = document.next(left)
        right = document.next(right)


def _steal_children(mut document: JsonDocument, target: Int, source: Int):
    """Move every child of `source` onto an empty `target`.

    Args:
        document: The JSON document.
        target: The empty container.
        source: The container that gives up its children.
    """
    var start = document.nodes[source].start
    var end = document.nodes[source].end
    var count = document.nodes[source].count
    document.nodes[target].start = start
    document.nodes[target].end = end
    document.nodes[target].count = count
    document.nodes[source].start = Int32(NO_NODE)
    document.nodes[source].end = Int32(NO_NODE)
    document.nodes[source].count = Int32(0)


def _detach(mut document: JsonDocument, parent: Int, child: Int):
    """Unlink a child from its parent.

    Args:
        document: The JSON document.
        parent: The container.
        child: The child to remove.
    """
    var current = document.first(parent)
    var prev = NO_NODE
    while current != NO_NODE:
        var nxt = document.next(current)
        if current != child:
            prev = current
            current = nxt
            continue
        if prev == NO_NODE:
            document.nodes[parent].start = Int32(nxt)
        else:
            document.nodes[prev].next = Int32(nxt)
        document.nodes[parent].count -= 1
        if document.nodes[parent].count == 0:
            document.nodes[parent].start = Int32(NO_NODE)
            document.nodes[parent].end = Int32(NO_NODE)
        elif Int(document.nodes[parent].end) == child:
            document.nodes[parent].end = Int32(prev)
        document.nodes[child].next = Int32(NO_NODE)
        return


def _append(mut document: JsonDocument, parent: Int, child: Int):
    """Make a node the last child of a container.

    Args:
        document: The JSON document.
        parent: The container.
        child: The node to append. Its `next` link is cleared.
    """
    ref container = document.nodes[parent]
    var last = Int(container.end)
    container.end = Int32(child)
    container.count += 1
    if container.count == 1:
        container.start = Int32(child)
    else:
        document.nodes[last].next = Int32(child)
    document.nodes[child].next = Int32(NO_NODE)


def _replace(mut document: JsonDocument, target: Int, source: Int):
    """Give `target` the value of `source` and keep its key.

    Args:
        document: The JSON document.
        target: The value that stays in place.
        source: The value to copy.
    """
    var kind = document.nodes[source].kind
    var flags = document.nodes[source].flags
    var start = document.nodes[source].start
    var end = document.nodes[source].end
    var count = document.nodes[source].count
    ref item = document.nodes[target]
    var key_bits = item.flags & (FLAG_KEY_ESCAPED | FLAG_KEY_DECODED)
    var value_bits = flags & ~(FLAG_KEY_ESCAPED | FLAG_KEY_DECODED)
    item.kind = kind
    item.flags = key_bits | value_bits
    item.start = start
    item.end = end
    item.count = count

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Bubble a removed non-null field to the nearest nullable ancestor.

Port of the null propagation in Hive Router `1a29df9`
`bin/router/src/executor/operation_filter.rs`. A denied field is removed.
When that field's type is non-null, its parent is removed as well. The
walk continues until it reaches a field whose type can be null. That
nullable field is removed, and its parent stays. `__typename` is never
removed.

A child must be stored after its parent. That is the order a document
walk produces.

**Differences from upstream.** Upstream records response paths and
rebuilds the operation. This module reports the removed field names. A
non-null field at the operation root is removed. It does not reject the
whole operation. `filter` discards the root propagation result.
"""


@fieldwise_init
struct BubbleNode(Copyable, Movable):
    """One field in a selection tree."""

    var name: String
    """The field name."""
    var parent: Int
    """The index of the parent field, or `-1` at the root."""
    var non_null: Bool
    """Whether the field type is non-null."""
    var denied: Bool
    """Whether authorization removed this field."""


def bubble_null_removals(nodes: List[BubbleNode]) -> List[String]:
    """Remove denied fields and the ancestors a non-null type forces out.

    Args:
        nodes: The selection tree. A child has a higher index than its
            parent.

    Returns:
        The removed field names, in document order.
    """
    var count = len(nodes)
    var propagates = List[Bool]()
    var removed = List[Bool]()
    for _ in range(count):
        propagates.append(False)
        removed.append(False)
    var cursor = count
    while cursor > 0:
        cursor -= 1
        ref node = nodes[cursor]
        if node.name == "__typename":
            continue
        var child_propagates = False
        for child in range(cursor + 1, count):
            ref child_node = nodes[child]
            if child_node.parent == cursor and propagates[child]:
                child_propagates = True
                break
        var reject = node.denied or child_propagates
        if reject:
            removed[cursor] = True
        propagates[cursor] = reject and node.non_null
    var names = List[String]()
    for index in range(count):
        if removed[index]:
            names.append(String(nodes[index].name))
    return names^

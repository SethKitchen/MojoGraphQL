# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Apply a fetch rewrite to a JSON response value.

Port of `FetchRewriteExt::rewrite` in Hive Router `1a29df9`
`bin/router/src/executor/execution/rewrites.rs`.

A key renamer changes a field name at the end of a path. A value setter
replaces the value at the end of a path with a string. An array applies
the same path to each item. A type condition passes when `__typename` is
absent or that type satisfies one name in the set. A missing field is left
in place.

**Differences from upstream.** An empty path on a key renamer leaves the
value unchanged. Upstream reads `path[0]` and panics.
"""

from gql_json.value import (
    FLAG_DECODED,
    FLAG_KEY_DECODED,
    FLAG_KEY_ESCAPED,
    NO_NODE,
    JsonDocument,
    JsonKind,
)
from gql_router.fetch_step import FetchRewrite
from gql_router.store import Store


@fieldwise_init
struct PossibleTypes(Movable):
    """The concrete types of each abstract type."""

    var names: List[String]
    """The abstract type names."""
    var members: List[List[String]]
    """The concrete types of each name, parallel to `names`."""


def apply_fetch_rewrite(
    store: Store,
    rewrite: FetchRewrite,
    mut document: JsonDocument,
    node: Int,
    possible: PossibleTypes,
):
    """Apply one fetch rewrite to a JSON value.

    Args:
        store: The store with the path names.
        rewrite: The key renamer or value setter.
        document: The JSON document to change.
        node: The value the path starts at.
        possible: The concrete types of each abstract type.
    """
    var nodes = List[Int]()
    var indexes = List[Int]()
    nodes.append(node)
    indexes.append(0)
    while len(nodes) > 0:
        var current = nodes.pop()
        var at = indexes.pop()
        if at >= len(rewrite.path):
            if rewrite.is_value_setter:
                _set_string(document, current, store.name(rewrite.value))
            continue
        if document.kind(current) == JsonKind.ARRAY:
            var child = document.first(current)
            while child != NO_NODE:
                nodes.append(child)
                indexes.append(at)
                child = document.next(child)
            continue
        if document.kind(current) != JsonKind.OBJECT:
            continue
        ref segment = rewrite.path[at]
        if not segment.is_key:
            if not _type_ok(store, document, current, segment.types, possible):
                continue
            if at + 1 >= len(rewrite.path):
                if rewrite.is_value_setter:
                    _set_string(document, current, store.name(rewrite.value))
                continue
            nodes.append(current)
            indexes.append(at + 1)
            continue
        var field = store.name(segment.key)
        var child = document.find(current, field)
        if child == NO_NODE:
            continue
        if not rewrite.is_value_setter and at + 1 >= len(rewrite.path):
            var target = store.name(rewrite.value)
            if field != target:
                _rename(document, child, target)
            continue
        nodes.append(child)
        indexes.append(at + 1)


def entity_satisfies(
    possible: PossibleTypes, type_name: String, condition: String
) -> Bool:
    """Return True when a concrete type meets one type condition.

    Args:
        possible: The concrete types of each abstract type.
        type_name: The entity's `__typename`.
        condition: One name from the type set.

    Returns:
        True when the names are equal, or `type_name` is a concrete type
        of `condition`.
    """
    if type_name == condition:
        return True
    var limit = len(possible.names)
    if len(possible.members) < limit:
        limit = len(possible.members)
    for index in range(limit):
        if possible.names[index] != condition:
            continue
        return _listed(possible.members[index], type_name)
    return False


def _type_ok(
    store: Store,
    document: JsonDocument,
    node: Int,
    types: Int,
    possible: PossibleTypes,
) -> Bool:
    """Return True when the object's type meets the type set.

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
    var type_name = document.string_value(type_node)
    if types < 0 or types >= len(store.type_sets):
        return False
    ref names = store.type_sets[types]
    for index in range(len(names)):
        if entity_satisfies(possible, type_name, store.name(names[index])):
            return True
    return False


def _set_string(mut document: JsonDocument, node: Int, text: String):
    """Replace a value with a string and keep its key.

    Args:
        document: The JSON document.
        node: The value to replace.
        text: The new string.
    """
    var start = len(document.bytes)
    document.bytes.extend(text.as_bytes())
    ref item = document.nodes[node]
    item.kind = JsonKind.STRING
    item.flags = (
        item.flags & (FLAG_KEY_ESCAPED | FLAG_KEY_DECODED)
    ) | FLAG_DECODED
    item.start = Int32(start)
    item.end = Int32(len(document.bytes))
    item.count = Int32(0)


def _rename(mut document: JsonDocument, node: Int, key: String):
    """Give an object member a new key.

    Args:
        document: The JSON document.
        node: The member.
        key: The new key.
    """
    var start = len(document.bytes)
    document.bytes.extend(key.as_bytes())
    ref item = document.nodes[node]
    item.key_start = Int32(start)
    item.key_end = Int32(len(document.bytes))
    item.flags = (item.flags & ~FLAG_KEY_ESCAPED) | FLAG_KEY_DECODED


def _listed(names: List[String], name: String) -> Bool:
    """Return True when a name is present.

    Args:
        names: The names.
        name: The candidate.

    Returns:
        Whether `name` is present.
    """
    for index in range(len(names)):
        if names[index] == name:
            return True
    return False

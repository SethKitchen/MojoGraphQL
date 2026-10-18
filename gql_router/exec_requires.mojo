# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Write the entity representations of a fetch, and hash them.

Port of `project_requires` and `project_requires_map_mut` of Hive Router
`1a29df9` `bin/router/src/executor/projection/request.rs`, and of
`Value::to_hash` with `hash_with_requires` of
`bin/router/src/executor/response/value.rs`.

A requires selection set is an item of the planner `Store`: its children
are fields and inline fragments. `project_requires` writes the JSON of one
entity, filtered by that selection, and returns False when the entity
cannot be sent: it has no complete `@key`, or it is of none of the
selection's types. `requires_hash` hashes the same filtered value, so two
entities that would send the same representation get the same hash.

**Differences from upstream.** The hash is FNV-1a with a final mix, not
XXH3. Strings and numbers keep their source text; see
`gql_router.exec_value`.
"""

from gql_json.value import NO_NODE, JsonDocument, JsonKind
from gql_router.ast import NONE, ItemKind
from gql_router.entity_keys import KeysByType
from gql_router.exec_value import (
    FNV_OFFSET,
    TYPENAME,
    finish_hash,
    hash_bytes,
    hash_tag,
    hash_value,
    object_get,
    raw_key_bytes,
    string_text,
    typename_node,
    write_value,
)
from gql_router.schema_metadata import PossibleTypes
from gql_router.store import Store

comptime _TYPENAME_FIELD = '"__typename":'
"""The key of `__typename` in a representation."""


@always_inline
def _put(mut buffer: List[UInt8], text: StringSlice):
    """Append text to a buffer."""
    buffer.extend(text.as_bytes())


def _write_response_key(
    first: Bool,
    response_key: StringSlice,
    has_key: Bool,
    mut buffer: List[UInt8],
):
    """Write a comma when needed, and a key, as upstream
    `write_response_key`."""
    if not first:
        buffer.append(UInt8(ord(",")))
    if has_key:
        buffer.append(UInt8(ord('"')))
        _put(buffer, response_key)
        buffer.append(UInt8(ord('"')))
        buffer.append(UInt8(ord(":")))


def _write_typename_field(
    document: JsonDocument, type_node: Int, mut buffer: List[UInt8]
):
    """Write `"__typename":"Type"`."""
    _put(buffer, _TYPENAME_FIELD)
    write_value(document, type_node, buffer)


@fieldwise_init
struct _Applied(ImplicitlyCopyable, Movable):
    """What the selections that apply to an object ask for, as upstream
    `AppliedSelections`."""

    var typename: Bool
    """`__typename` is one of them."""
    var missing_field: Bool
    """One of the fields is not in the object."""


def project_requires(
    store: Store,
    possible_types: PossibleTypes,
    selections: Int,
    document: JsonDocument,
    entity: Int,
    mut buffer: List[UInt8],
    first: Bool,
    response_key: StringSlice,
    has_key: Bool,
    nested: Bool,
    subgraph_keys: KeysByType,
    has_keys: Bool,
) -> Bool:
    """Write the representation of an entity, as upstream
    `project_requires`.

    Args:
        store: The store with the selections.
        possible_types: The possible types of each abstract type.
        selections: The item whose children are the requires selections.
        document: The response data.
        entity: The value to write.
        buffer: The destination.
        first: Whether nothing was written before in the container.
        response_key: The key to write before the value.
        has_key: Whether there is a key to write.
        nested: Whether the value is inside the representation.
        subgraph_keys: The keys of each entity type in the target subgraph.
        has_keys: Whether `subgraph_keys` is known.

    Returns:
        False when nothing was written: the value is `null`, or the entity
        cannot be sent.
    """
    var kind = document.kind(entity)
    if kind == JsonKind.NULL:
        return False
    if kind == JsonKind.ARRAY:
        _write_response_key(first, response_key, has_key, buffer)
        buffer.append(UInt8(ord("[")))
        var item_first = True
        var item = document.first(entity)
        while item != NO_NODE:
            if project_requires(
                store,
                possible_types,
                selections,
                document,
                item,
                buffer,
                item_first,
                "",
                False,
                nested,
                subgraph_keys,
                has_keys,
            ):
                item_first = False
            item = document.next(item)
        buffer.append(UInt8(ord("]")))
        return True
    if kind != JsonKind.OBJECT:
        _write_response_key(first, response_key, has_key, buffer)
        write_value(document, entity, buffer)
        return True
    if store.items[selections].first == NONE:
        # A scalar with an object value: write it whole.
        _write_response_key(first, response_key, has_key, buffer)
        write_value(document, entity, buffer)
        return True
    if document.length(entity) == 0:
        return False
    var parent_first = first
    var object_first = True
    var type_node = typename_node(document, entity)
    var type_keys = List[List[String]]()
    var keys_known = False
    if has_keys and type_node != NO_NODE:
        var found = subgraph_keys.get(string_text(document, type_node))
        if found:
            type_keys = found.value().copy()
            keys_known = True
    var object_start = len(buffer)
    var applied = _project_map(
        store,
        possible_types,
        selections,
        document,
        entity,
        type_node,
        buffer,
        object_first,
        response_key,
        has_key,
        parent_first,
        keys_known,
    )
    if keys_known and not _has_complete_key(document, entity, type_keys):
        buffer.resize(object_start, 0)
        return False
    if (
        object_first
        and not applied.missing_field
        and (nested or applied.typename)
        and type_node != NO_NODE
    ):
        _write_response_key(parent_first, response_key, has_key, buffer)
        buffer.append(UInt8(ord("{")))
        _write_typename_field(document, type_node, buffer)
        object_first = False
    if object_first:
        return False
    buffer.append(UInt8(ord("}")))
    return True


def _has_complete_key(
    document: JsonDocument, entity: Int, type_keys: List[List[String]]
) -> Bool:
    """Return True if the entity has every field of one of its keys."""
    for key_fields in type_keys:
        var complete = True
        for field in key_fields:
            if object_get(document, entity, field) == NO_NODE:
                complete = False
                break
        if complete:
            return True
    return False


def _type_matches(
    possible_types: PossibleTypes,
    type_name: StringSlice,
    condition: StringSlice,
) -> Bool:
    """Return True if either side of a type condition satisfies the other,
    as upstream checks for projection."""
    if possible_types.entity_satisfies_type_condition(type_name, condition):
        return True
    return possible_types.entity_satisfies_type_condition(condition, type_name)


def _project_map(
    store: Store,
    possible_types: PossibleTypes,
    selections: Int,
    document: JsonDocument,
    entity: Int,
    type_node: Int,
    mut buffer: List[UInt8],
    mut first: Bool,
    parent_response_key: StringSlice,
    parent_has_key: Bool,
    parent_first: Bool,
    keys_known: Bool,
) -> _Applied:
    """Write the selected fields of an object, as upstream
    `project_requires_map_mut`."""
    var applied = _Applied(False, False)
    var child = store.items[selections].first
    while child != NONE:
        var current = child
        ref item = store.items[current]
        child = item.next
        if item.kind == ItemKind.FRAGMENT:
            var condition = store.name(item.name)
            var matches: Bool
            if type_node == NO_NODE:
                matches = True
            else:
                matches = _type_matches(
                    possible_types, string_text(document, type_node), condition
                )
            if matches:
                var inner = _project_map(
                    store,
                    possible_types,
                    current,
                    document,
                    entity,
                    type_node,
                    buffer,
                    first,
                    parent_response_key,
                    parent_has_key,
                    parent_first,
                    keys_known,
                )
                applied.typename = applied.typename or inner.typename
                applied.missing_field = (
                    applied.missing_field or inner.missing_field
                )
            continue
        ref field_name = store.name(item.name)
        var response_key = field_name
        if item.alias != NONE:
            response_key = store.name(item.alias)
        if response_key == TYPENAME:
            applied.typename = True
            continue
        var original = object_get(document, entity, field_name)
        if original == NO_NODE:
            original = object_get(document, entity, response_key)
        if original == NO_NODE and not keys_known:
            applied.missing_field = True
            continue
        var object_start = -1
        if first:
            object_start = len(buffer)
            _write_response_key(
                parent_first, parent_response_key, parent_has_key, buffer
            )
            buffer.append(UInt8(ord("{")))
            if type_node != NO_NODE:
                _write_typename_field(document, type_node, buffer)
                first = False
        if original == NO_NODE or document.kind(original) == JsonKind.NULL:
            _write_response_key(first, response_key, True, buffer)
            _put(buffer, "null")
            first = False
            continue
        var empty = KeysByType()
        var projected = project_requires(
            store,
            possible_types,
            current,
            document,
            original,
            buffer,
            first,
            response_key,
            True,
            True,
            empty,
            False,
        )
        if projected:
            first = False
        elif first and object_start >= 0:
            buffer.resize(object_start, 0)
    return applied


def requires_hash(
    store: Store,
    possible_types: PossibleTypes,
    selections: Int,
    document: JsonDocument,
    entity: Int,
) -> UInt64:
    """Hash an entity by its required fields, as upstream `Value::to_hash`.

    Args:
        store: The store with the selections.
        possible_types: The possible types of each abstract type.
        selections: The item whose children are the requires selections.
        document: The response data.
        entity: The value to hash.

    Returns:
        The hash.
    """
    return finish_hash(
        _hash_with_requires(
            store, possible_types, selections, document, entity, FNV_OFFSET
        )
    )


def _hash_with_requires(
    store: Store,
    possible_types: PossibleTypes,
    selections: Int,
    document: JsonDocument,
    node: Int,
    state: UInt64,
) -> UInt64:
    """Fold a value, filtered by selections, into a hash state."""
    if store.items[selections].first == NONE:
        return hash_value(document, node, state)
    var kind = document.kind(node)
    if kind == JsonKind.OBJECT:
        return _hash_object(
            store, possible_types, selections, document, node, NO_NODE, state
        )
    if kind == JsonKind.ARRAY:
        var hash = state
        var item = document.first(node)
        while item != NO_NODE:
            hash = _hash_with_requires(
                store, possible_types, selections, document, item, hash
            )
            item = document.next(item)
        return hash
    return hash_value(document, node, state)


def _hash_object(
    store: Store,
    possible_types: PossibleTypes,
    selections: Int,
    document: JsonDocument,
    object: Int,
    known_type: Int,
    state: UInt64,
) -> UInt64:
    """Fold the selected members of an object, as upstream
    `hash_object_with_requires`."""
    var hash = state
    var type_node = known_type
    var looked_up = known_type != NO_NODE
    var child = store.items[selections].first
    while child != NONE:
        var current = child
        ref item = store.items[current]
        child = item.next
        if item.kind == ItemKind.FIELD:
            var found = object_get(document, object, store.name(item.name))
            if found != NO_NODE:
                hash = hash_tag(
                    hash_bytes(hash, raw_key_bytes(document, found)), 0xFF
                )
                hash = _hash_with_requires(
                    store, possible_types, current, document, found, hash
                )
            continue
        if not looked_up:
            type_node = typename_node(document, object)
            looked_up = True
        var condition = store.name(item.name)
        var matches = type_node == NO_NODE
        if not matches:
            matches = possible_types.entity_satisfies_type_condition(
                string_text(document, type_node), condition
            )
        if matches:
            hash = _hash_object(
                store,
                possible_types,
                current,
                document,
                object,
                type_node,
                hash,
            )
    return hash

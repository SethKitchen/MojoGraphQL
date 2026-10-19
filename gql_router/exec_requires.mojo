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

**Differences from upstream.** The hash is a word-at-a-time multiply hash
with a final mix, not XXH3. Strings and numbers keep their source text; see
`gql_router.exec_value`.
"""

from gql_json.value import NO_NODE, JsonDocument, JsonKind
from gql_router.ast import NONE, ItemKind
from gql_router.entity_keys import KeysByType
from gql_router.exec_value import (
    append_text,
    FNV_OFFSET,
    TYPENAME,
    finish_hash,
    hash_bytes,
    hash_tag,
    hash_value,
    object_get,
    raw_key_bytes,
    is_plain_string,
    raw_string,
    string_text,
    type_satisfies,
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
    append_text(buffer, text)


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


def _has_complete_key(
    document: JsonDocument, entity: Int, type_keys: List[List[String]]
) -> Bool:
    """Return True if the entity has every field of one of its keys."""
    var index = 0
    while index < len(type_keys):
        var complete = True
        for field in type_keys[index]:
            if object_get(document, entity, field) == NO_NODE:
                complete = False
                break
        if complete:
            return True
        index += 1
    return False


def _type_matches(
    possible_types: PossibleTypes,
    document: JsonDocument,
    type_node: Int,
    condition: StringSlice,
) -> Bool:
    """Return True if either side of a type condition satisfies the other,
    as upstream checks for projection."""
    if type_satisfies(possible_types, document, type_node, condition):
        return True
    return possible_types.entity_satisfies_type_condition(
        condition, string_text(document, type_node)
    )


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
    var projector = _Requires(
        store,
        possible_types,
        document,
        subgraph_keys,
        Pointer(to=buffer).unsafe_origin_cast[MutUntrackedOrigin](),
    )
    return projector.project(
        selections, entity, first, response_key, has_key, nested, has_keys
    )


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
    var keys = KeysByType()
    var buffer = List[UInt8]()
    var hasher = _Requires(
        store,
        possible_types,
        document,
        keys,
        Pointer(to=buffer).unsafe_origin_cast[MutUntrackedOrigin](),
    )
    return finish_hash(
        hasher.hash_with_requires(selections, entity, FNV_OFFSET)
    )


@fieldwise_init
struct _Requires[
    s: Origin[mut=False],
    t: Origin[mut=False],
    d: Origin[mut=False],
    k: Origin[mut=False],
](ImplicitlyCopyable):
    """The inputs of one representation walk and a pointer to its output.

    The recursive steps take this handle of five pointers, so that each
    call does not get the fields of every input as arguments.
    """

    var store: Pointer[Store, Self.s]
    """The store with the selections."""
    var possible_types: Pointer[PossibleTypes, Self.t]
    """The possible types of each abstract type."""
    var document: Pointer[JsonDocument, Self.d]
    """The response data."""
    var keys: Pointer[KeysByType, Self.k]
    """The keys of each entity type in the target subgraph."""
    var buffer: Pointer[List[UInt8], MutUntrackedOrigin]
    """The destination."""

    def __init__(
        out self,
        ref[Self.s] store: Store,
        ref[Self.t] possible_types: PossibleTypes,
        ref[Self.d] document: JsonDocument,
        ref[Self.k] keys: KeysByType,
        buffer: Pointer[List[UInt8], MutUntrackedOrigin],
    ):
        """Start a walk.

        Args:
            store: The store with the selections.
            possible_types: The possible types of each abstract type.
            document: The response data.
            keys: The keys of each entity type in the target subgraph.
            buffer: The destination.
        """
        self.store = Pointer(to=store)
        self.possible_types = Pointer(to=possible_types)
        self.document = Pointer(to=document)
        self.keys = Pointer(to=keys)
        self.buffer = buffer

    def project(
        self,
        selections: Int,
        entity: Int,
        first: Bool,
        response_key: StringSlice,
        has_key: Bool,
        nested: Bool,
        has_keys: Bool,
    ) -> Bool:
        """Write one value, as upstream `project_requires`.

        Args:
            selections: The item whose children are the selections.
            entity: The value to write.
            first: Whether nothing was written before in the container.
            response_key: The key to write before the value.
            has_key: Whether there is a key to write.
            nested: Whether the value is inside the representation.
            has_keys: Whether `keys` applies to this value.

        Returns:
            False when nothing was written.
        """
        ref document = self.document[]
        ref buffer = self.buffer[]
        var kind = document.kind(entity)
        if kind == JsonKind.NULL:
            return False
        if kind == JsonKind.ARRAY:
            _write_response_key(first, response_key, has_key, buffer)
            buffer.append(UInt8(ord("[")))
            var item_first = True
            var item = document.first(entity)
            while item != NO_NODE:
                if self.project(
                    selections, item, item_first, "", False, nested, has_keys
                ):
                    item_first = False
                item = document.next(item)
            buffer.append(UInt8(ord("]")))
            return True
        if kind != JsonKind.OBJECT:
            _write_response_key(first, response_key, has_key, buffer)
            write_value(document, entity, buffer)
            return True
        if self.store[].items[selections].first == NONE:
            # A scalar with an object value: write it whole.
            _write_response_key(first, response_key, has_key, buffer)
            write_value(document, entity, buffer)
            return True
        if document.length(entity) == 0:
            return False
        var parent_first = first
        var object_first = True
        var type_node = typename_node(document, entity)
        var key_index = -1
        if has_keys and type_node != NO_NODE:
            if is_plain_string(document, type_node):
                key_index = self.keys[].index_of(
                    raw_string(document, type_node)
                )
            else:
                key_index = self.keys[].index_of(
                    string_text(document, type_node)
                )
        var keys_known = key_index >= 0
        var object_start = len(buffer)
        var applied = self.project_map(
            selections,
            entity,
            type_node,
            object_first,
            response_key,
            has_key,
            parent_first,
            keys_known,
        )
        if keys_known and not _has_complete_key(
            document, entity, self.keys[].keys[key_index]
        ):
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

    def project_map(
        self,
        selections: Int,
        entity: Int,
        type_node: Int,
        mut first: Bool,
        parent_response_key: StringSlice,
        parent_has_key: Bool,
        parent_first: Bool,
        keys_known: Bool,
    ) -> _Applied:
        """Write the selected fields of an object, as upstream
        `project_requires_map_mut`.

        Args:
            selections: The item whose children are the selections.
            entity: The object.
            type_node: Its `__typename` string, or `NO_NODE`.
            first: Whether the object is not opened yet.
            parent_response_key: The key of the object in its parent.
            parent_has_key: Whether there is a key to write.
            parent_first: Whether nothing was written in the parent.
            keys_known: Whether the keys of the entity type are known.

        Returns:
            What the selections that apply ask for.
        """
        ref store = self.store[]
        ref document = self.document[]
        ref buffer = self.buffer[]
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
                        self.possible_types[], document, type_node, condition
                    )
                if matches:
                    var inner = self.project_map(
                        current,
                        entity,
                        type_node,
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
            var projected = self.project(
                current, original, first, response_key, True, True, False
            )
            if projected:
                first = False
            elif first:
                # The object was opened for this field: `first` is still
                # set, so `object_start` was set above.
                buffer.resize(object_start, 0)
        return applied

    def hash_with_requires(
        self, selections: Int, node: Int, state: UInt64
    ) -> UInt64:
        """Fold a value, filtered by selections, into a hash state.

        Args:
            selections: The item whose children are the selections.
            node: The value.
            state: The hash state.

        Returns:
            The new hash state.
        """
        ref document = self.document[]
        if self.store[].items[selections].first == NONE:
            return hash_value(document, node, state)
        var kind = document.kind(node)
        if kind == JsonKind.OBJECT:
            return self.hash_object(selections, node, NO_NODE, state)
        if kind == JsonKind.ARRAY:
            var hash = state
            var item = document.first(node)
            while item != NO_NODE:
                hash = self.hash_with_requires(selections, item, hash)
                item = document.next(item)
            return hash
        return hash_value(document, node, state)

    def hash_object(
        self, selections: Int, object: Int, known_type: Int, state: UInt64
    ) -> UInt64:
        """Fold the selected members of an object, as upstream
        `hash_object_with_requires`.

        Args:
            selections: The item whose children are the selections.
            object: The object.
            known_type: Its `__typename` string when looked up, or
                `NO_NODE`.
            state: The hash state.

        Returns:
            The new hash state.
        """
        ref store = self.store[]
        ref document = self.document[]
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
                    hash = self.hash_with_requires(current, found, hash)
                continue
            if not looked_up:
                type_node = typename_node(document, object)
                looked_up = True
            var condition = store.name(item.name)
            var matches = type_node == NO_NODE
            if not matches:
                matches = type_satisfies(
                    self.possible_types[], document, type_node, condition
                )
            if matches:
                hash = self.hash_object(current, object, type_node, hash)
        return hash

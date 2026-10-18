# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Apply the input and output rewrites of a fetch to response data.

Port of `FetchRewriteExt::rewrite`, `KeyRenamer::apply_path` and
`ValueSetter::apply_path` of Hive Router `1a29df9`
`bin/router/src/executor/execution/rewrites.rs`.

A key renamer gives a new key to the member at the end of its path. A value
setter replaces the value at the end of its path with a string. A list
applies the rest of the path to each item. A type condition passes when
`__typename` is absent or satisfies one of its types.

**Differences from upstream.** A key renamer with an empty path, or whose
last step is a type condition, changes nothing. Upstream reads past the end
of the path and panics. This module works on the executor arena of
`gql_router.exec_value`; `gql_router.rewrite` is the same rewrite for its
own possible types.
"""

from gql_json.value import NO_NODE, JsonDocument, JsonKind
from gql_router.exec_traverse import satisfies_any
from gql_router.exec_value import (
    key_is,
    set_key,
    set_string,
    string_text,
    typename_node,
)
from gql_router.fetch_step import FetchRewrite
from gql_router.schema_metadata import PossibleTypes
from gql_router.store import Store


def apply_rewrite(
    store: Store,
    possible_types: PossibleTypes,
    rewrite: FetchRewrite,
    mut document: JsonDocument,
    node: Int,
):
    """Apply one rewrite to a value, as upstream `FetchRewrite::rewrite`.

    Args:
        store: The store with the path names and type sets.
        possible_types: The possible types of each abstract type.
        rewrite: The key renamer or the value setter.
        document: The response arena.
        node: The value the path starts at.
    """
    _apply(store, possible_types, rewrite, document, node, 0)


def _apply(
    store: Store,
    possible_types: PossibleTypes,
    rewrite: FetchRewrite,
    mut document: JsonDocument,
    node: Int,
    at: Int,
):
    """Apply the rest of a rewrite path from one value."""
    var setter = rewrite.is_value_setter
    if setter and at == len(rewrite.path):
        set_string(document, node, store.name(rewrite.value))
        return
    var kind = document.kind(node)
    if kind == JsonKind.ARRAY:
        var item = document.first(node)
        while item != NO_NODE:
            _apply(store, possible_types, rewrite, document, item, at)
            item = document.next(item)
        return
    if kind != JsonKind.OBJECT or at == len(rewrite.path):
        return
    ref segment = rewrite.path[at]
    if not segment.is_key:
        var type_node = typename_node(document, node)
        if type_node == NO_NODE or satisfies_any(
            store, possible_types, string_text(document, type_node), segment.types
        ):
            _apply(store, possible_types, rewrite, document, node, at + 1)
        return
    var name = store.name(segment.key)
    var member = document.first(node)
    while member != NO_NODE and not key_is(document, member, name):
        member = document.next(member)
    if member == NO_NODE:
        return
    var last = at + 1 == len(rewrite.path)
    if setter or not last:
        _apply(store, possible_types, rewrite, document, member, at + 1)
        return
    var new_key = store.name(rewrite.value)
    if new_key != name:
        set_key(document, member, new_key)

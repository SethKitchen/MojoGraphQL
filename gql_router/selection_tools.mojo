# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Selection set helpers for the fetch graph optimizer.

Port of Hive Router `1a29df9` helpers that the passes of
`bin/router/src/query_planner/planner/fetch/optimize/` use:
`read_as_written` of `planner/fetch/response_keys.rs`,
`field_condition_equal` of `ast/selection_set.rs`, and the
`From<&MergePath> for Vec<FetchNodePathSegment>` of
`planner/plan_nodes/path.rs`.
"""

from gql_router.ast import NONE, Cond, ItemKind
from gql_router.fetch_step import FetchNodePathSegment
from gql_router.merge_path import MergePath, SegmentKind
from gql_router.store import Store


def read_as_written(mut store: Store, set: Int):
    """Turn a representation read back into the fetch that writes it, as
    upstream `read_as_written`: `price: _internal_qp_alias_0` becomes
    `_internal_qp_alias_0: price`.

    Args:
        store: The store.
        set: The set to change in place.
    """
    var child = store.items[set].first
    while child != NONE:
        var kind = store.items[child].kind
        if kind == ItemKind.FIELD:
            var alias = store.items[child].alias
            if alias != NONE:
                store.items[child].alias = store.items[child].name
                store.items[child].name = alias
            read_as_written(store, child)
        elif kind == ItemKind.FRAGMENT:
            read_as_written(store, child)
        child = store.items[child].next


def field_condition_equal(store: Store, cond: Cond, field: Int) -> Bool:
    """Return True if a field has exactly a condition, as upstream
    `field_condition_equal`.

    Args:
        store: The store.
        cond: The condition, or none.
        field: The field.

    Returns:
        Whether the field's `@skip` and `@include` are the condition's.
    """
    var found = store.items[field]
    return Cond(found.skip, found.include) == cond


def fetch_node_path(
    store: Store, path: MergePath
) -> List[FetchNodePathSegment]:
    """Return the rewrite path of a merge path, as upstream
    `Vec<FetchNodePathSegment>::from(&MergePath)`.

    Args:
        store: The store.
        path: The merge path.

    Returns:
        A `Key` per field, by response key, and a `TypenameEquals` per type
        condition; list steps are left out.
    """
    var out = List[FetchNodePathSegment]()
    for segment in path.segments:
        if segment.kind == SegmentKind.TYPE_CONDITION:
            out.append(FetchNodePathSegment(False, NONE, segment.types))
        elif segment.kind == SegmentKind.FIELD:
            out.append(FetchNodePathSegment(True, segment.response_key(), NONE))
    return out^


def sorted_union(store: Store, a: List[Int], b: List[Int]) -> List[Int]:
    """Return the union of two lists of names, as a `BTreeSet`.

    Args:
        store: The store with the names.
        a: Names, as symbols.
        b: More names, as symbols.

    Returns:
        Every name once, sorted by text.
    """
    var out = List[Int]()
    for name in a:
        insert_sorted_once(store, out, name)
    for name in b:
        insert_sorted_once(store, out, name)
    return out^


def insert_sorted_once(store: Store, mut out: List[Int], name: Int):
    """Insert a name into a sorted list unless it is there.

    Args:
        store: The store with the names.
        out: Names, sorted by text.
        name: The name, as a symbol.
    """
    for known in out:
        if known == name:
            return
    var at = len(out)
    while at > 0 and store.less(name, out[at - 1]):
        at -= 1
    out.insert(at, name)

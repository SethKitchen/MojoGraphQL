# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Split a batch response by alias and merge entities back.

Port of `partition_batch_errors_by_alias`,
`collect_batched_entities_by_alias`, and `merge_batch_alias_entities` in
Hive Router `1a29df9` `bin/router/src/executor/execution/plan.rs`.

An error belongs to the alias named by the first step of its path. That
step is rewritten to `_entities`. An error with no such alias stays
unmatched. Each alias array is taken off the response data. A field that
is not an array is removed and not returned. Each entity is merged into
the visited value whose index the caller supplies.

**Differences from upstream.** The caller supplies the entity index for
each visit. Upstream finds that index from a representation hash.
"""

from gql_json.value import NO_NODE, JsonDocument, JsonKind
from gql_json.writer import stringify
from gql_router.graphql_error import ErrorSegmentKind, GraphQLError
from gql_router.plan_nodes import FlattenNodePath
from gql_router.response_merge import deep_merge
from gql_router.response_path import visit_response_path
from gql_router.rewrite import PossibleTypes
from gql_router.store import Store


struct BatchErrorSplit(Movable):
    """Errors grouped by alias, plus the unmatched errors."""

    var groups: List[List[GraphQLError]]
    """One list per alias, in alias order."""
    var unmatched: List[GraphQLError]
    """Errors that do not name a known alias."""

    def __init__(out self, alias_count: Int):
        """Start empty groups for each alias.

        Args:
            alias_count: The number of aliases.
        """
        self.groups = List[List[GraphQLError]]()
        var index = 0
        while index < alias_count:
            self.groups.append(List[GraphQLError]())
            index += 1
        self.unmatched = List[GraphQLError]()


def partition_batch_errors(
    aliases: List[String], var errors: List[GraphQLError]
) -> BatchErrorSplit:
    """Group subgraph errors by batch alias.

    Args:
        aliases: The alias names, such as `_e0`.
        errors: The errors from the batch response.

    Returns:
        The errors for each alias, and the errors that match none.
    """
    var split = BatchErrorSplit(len(aliases))
    for index in range(len(errors)):
        var error = errors[index].copy()
        var alias = _alias_name(error)
        var slot = _last_alias(aliases, alias)
        if slot < 0:
            split.unmatched.append(error^)
            continue
        _rename_alias(error)
        split.groups[slot].append(error^)
    return split^


def collect_batch_entities(
    mut data: JsonDocument, aliases: List[String]
) -> List[String]:
    """Take each alias array off the response.

    Args:
        data: The batch `data` object. Matching fields are removed.
        aliases: The alias names, in order.

    Returns:
        The JSON of each alias array. An empty entry means that alias had
        no array.
    """
    var texts = List[String]()
    for index in range(len(aliases)):
        var node = _take_field(data, aliases[index])
        if node < 0 or data.kind(node) != JsonKind.ARRAY:
            texts.append(String(""))
            continue
        texts.append(stringify(data, node))
    return texts^


def merge_alias_entities(
    mut data: JsonDocument,
    entities: JsonDocument,
    path: FlattenNodePath,
    store: Store,
    possible: PossibleTypes,
    indexes: List[Int],
    has_errors: Bool,
) -> String:
    """Merge alias entities into the values at one path.

    Args:
        data: The response. Visited values are updated.
        entities: The alias entity array.
        path: The response path of this alias.
        store: The store with the field and type names.
        possible: The concrete types of each abstract type.
        indexes: The entity index for each visit. A negative index skips
            that visit.
        has_errors: True when visit paths are recorded for error expansion.

    Returns:
        The entity indexes and their visit paths, such as
        `0:products.0 | 1:products.1`. Empty when errors are not recorded.
    """
    var visit = visit_response_path(store, data, data.root, path, possible)
    var entity_nodes = List[Int]()
    if entities.kind(entities.root) == JsonKind.ARRAY:
        entity_nodes = entities.children(entities.root)
    var seen = List[Int]()
    var grouped = List[String]()
    for index in range(len(visit.nodes)):
        var entity_index = -1
        if index < len(indexes):
            entity_index = indexes[index]
        if entity_index < 0:
            continue
        if has_errors:
            _keep_path(seen, grouped, entity_index, visit.paths[index])
        if entity_index >= len(entity_nodes):
            continue
        var copy = data.add_copy(entities, entity_nodes[entity_index])
        deep_merge(data, visit.nodes[index], copy)
    return _grouped_text(seen, grouped)


def _keep_path(
    mut seen: List[Int],
    mut grouped: List[String],
    entity_index: Int,
    path: String,
):
    """Append a visit path under its entity index.

    Args:
        seen: The entity indexes already recorded.
        grouped: The paths of each entity index, parallel to `seen`.
        entity_index: The entity index.
        path: The visit path.
    """
    for index in range(len(seen)):
        if seen[index] != entity_index:
            continue
        grouped[index] = grouped[index] + " " + path
        return
    seen.append(entity_index)
    grouped.append(path)


def _grouped_text(seen: List[Int], grouped: List[String]) -> String:
    """Write entity indexes and their visit paths.

    Args:
        seen: The entity indexes.
        grouped: The paths of each index, parallel to `seen`.

    Returns:
        The text. Empty when nothing was recorded.
    """
    var text = String("")
    var limit = len(seen)
    if len(grouped) < limit:
        limit = len(grouped)
    for index in range(limit):
        if index > 0:
            text += " | "
        text += String(seen[index])
        text += ":"
        text += grouped[index]
    return text^


def _alias_name(error: GraphQLError) -> String:
    """Return the alias at the start of an error path.

    Args:
        error: The subgraph error.

    Returns:
        The field name. Empty when the path does not start with a field.
    """
    if not error.has_path or len(error.path.segments) == 0:
        return String("")
    ref first = error.path.segments[0]
    if first.kind != ErrorSegmentKind.FIELD:
        return String("")
    return String(first.field)


def _rename_alias(mut error: GraphQLError):
    """Replace the first path field with `_entities`.

    Args:
        error: The error. Its first field step is rewritten.
    """
    if not error.has_path or len(error.path.segments) == 0:
        return
    ref first = error.path.segments[0]
    if first.kind != ErrorSegmentKind.FIELD:
        return
    first.field = String("_entities")


def _last_alias(aliases: List[String], name: String) -> Int:
    """Return the last alias with this name.

    Args:
        aliases: The alias names.
        name: The candidate. Empty matches nothing.

    Returns:
        The index. `-1` when the name is absent.
    """
    if name.byte_length() == 0:
        return -1
    var found = -1
    for index in range(len(aliases)):
        if aliases[index] == name:
            found = index
    return found


def _take_field(mut data: JsonDocument, name: String) -> Int:
    """Remove one field from the root object.

    Args:
        data: The document. The field is unlinked when it exists.
        name: The field name.

    Returns:
        The removed value. `-1` when the field is absent or the root is
        not an object.
    """
    if data.kind(data.root) != JsonKind.OBJECT:
        return -1
    var child = data.find(data.root, name)
    if child == NO_NODE:
        return -1
    _detach(data, data.root, child)
    return child


def _detach(mut data: JsonDocument, parent: Int, child: Int):
    """Unlink a child from its parent.

    Args:
        data: The document.
        parent: The object.
        child: The member to remove.
    """
    var current = data.first(parent)
    var previous = NO_NODE
    while current != NO_NODE:
        var nxt = data.next(current)
        if current != child:
            previous = current
            current = nxt
            continue
        if previous == NO_NODE:
            data.nodes[parent].start = Int32(nxt)
        else:
            data.nodes[previous].next = Int32(nxt)
        data.nodes[parent].count -= 1
        if data.nodes[parent].count == 0:
            data.nodes[parent].start = Int32(NO_NODE)
            data.nodes[parent].end = Int32(NO_NODE)
        elif Int(data.nodes[parent].end) == child:
            data.nodes[parent].end = Int32(previous)
        data.nodes[child].next = Int32(NO_NODE)
        return

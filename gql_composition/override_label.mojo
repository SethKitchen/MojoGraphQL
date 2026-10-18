# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A labeled `@override` cannot replace a field that uses `@requires`.

Port of `OverrideLabelWithRequiresRule` of Hive Federation Composition
v0.27.0
`src/supergraph/validation/rules/override-label-with-requires.ts`.

The label marks a progressive override. Hive allows that migration only
when the source field has no `@requires`.
"""

from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.later_versions import GraphFacts
from gql_composition.merged import field_names, type_names
from gql_composition.state import TypeKind


def check_override_label(
    facts: List[GraphFacts], mut found: List[String]
) -> List[CompositionError]:
    """Report a progressive `@override` of a field that uses `@requires`.

    Args:
        facts: The subgraphs, in id order, after a clean subgraph phase.
        found: Receives `Type.field` for each error, in the same order.

    Returns:
        The `OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE` errors, in
        Hive's field order.
    """
    var errors = List[CompositionError]()
    var all_type_names = type_names(facts, TypeKind.OBJECT)
    for type_index in range(len(all_type_names)):
        var type_name = String(all_type_names[type_index])
        var all_field_names = field_names(facts, type_name, TypeKind.OBJECT)
        for field_index in range(len(all_field_names)):
            var field_name = String(all_field_names[field_index])
            _check_field(facts, type_name, field_name, errors, found)
    return errors^


def _check_field(
    facts: List[GraphFacts],
    type_name: String,
    field_name: String,
    mut errors: List[CompositionError],
    mut found: List[String],
):
    """Append an error for each labeled override whose source uses `@requires`.

    Args:
        facts: The subgraphs, in id order.
        type_name: The object type.
        field_name: The field.
        errors: The errors to append.
        found: Receives `Type.field` when an error is appended.
    """
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var field = _field(graph, type_name, field_name)
        if field == -1:
            continue
        var type_at = graph.find_kind(type_name, TypeKind.OBJECT)
        ref fact = graph.types[type_at].fields[field]
        if (
            fact.override_from.byte_length() == 0
            or fact.override_label.byte_length() == 0
        ):
            continue
        var source = _graph_named(facts, fact.override_from)
        if source == -1:
            continue
        if not _source_requires(facts[source], type_name, field_name):
            continue
        found.append(type_name + "." + field_name)
        errors.append(
            CompositionError(
                "@override with label (progressive override) cannot be"
                + ' used on field "'
                + type_name
                + "."
                + field_name
                + '" on subgraph "'
                + graph.graph_name
                + '" since "'
                + type_name
                + "."
                + field_name
                + '" on "'
                + facts[source].graph_name
                + '" is marked with directive "@requires". Use'
                + " non-progressive @override (without label) for this"
                + " migration.",
                ErrorCode.OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE,
                None,
            )
        )


def _source_requires(
    graph: GraphFacts, type_name: String, field_name: String
) -> Bool:
    """Return True when the source field has `@requires`.

    Args:
        graph: The source subgraph.
        type_name: The object type.
        field_name: The field.

    Returns:
        Whether that field's `@requires` set is non-empty. False when the
        source subgraph does not define the field.
    """
    var field = _field(graph, type_name, field_name)
    if field == -1:
        return False
    var type_at = graph.find_kind(type_name, TypeKind.OBJECT)
    return graph.types[type_at].fields[field].requires.byte_length() > 0


def _field(graph: GraphFacts, type_name: String, field_name: String) -> Int:
    """Return the index of an object field, or -1.

    Args:
        graph: One subgraph.
        type_name: The object type.
        field_name: The field.

    Returns:
        The index in the type's fields, or -1.
    """
    var type_at = graph.find_kind(type_name, TypeKind.OBJECT)
    if type_at == -1:
        return -1
    return graph.types[type_at].find_field(field_name)


def _graph_named(facts: List[GraphFacts], name: String) -> Int:
    """Return the index of the subgraph with a name, or -1.

    Args:
        facts: The subgraphs, in id order. It is not empty.
        name: The subgraph name.

    Returns:
        The index in `facts`, or -1 when no subgraph has that name.
    """
    var graph_index = 0
    while graph_index < len(facts):
        if facts[graph_index].graph_name == name:
            return graph_index
        graph_index += 1
    return -1

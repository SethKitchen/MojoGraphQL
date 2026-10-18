# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Input fields that share a name must share a default value.

Port of `InputFieldDefaultMismatchRule` of Hive Federation Composition
v0.27.0
`src/supergraph/validation/rules/input-field-default-mismatch-rule.ts`.

A subgraph that omits the default does not join a group. Two different
printed defaults are an error.
"""

from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.later_versions import GraphFacts
from gql_composition.merged import field_names, subgraph_place, type_names
from gql_composition.state import TypeKind


@fieldwise_init
struct _Group(Movable):
    """One default value and the subgraphs that use it."""

    var value: String
    """The printed default."""
    var graphs: List[String]
    """The subgraph names, in id order."""


def check_input_defaults(
    facts: List[GraphFacts], mut found: List[String]
) -> List[CompositionError]:
    """Report an input field whose defaults disagree.

    Args:
        facts: The subgraphs, in id order, after a clean subgraph phase.
        found: Receives `Type.field` for each error, in the same order.

    Returns:
        The `INPUT_FIELD_DEFAULT_MISMATCH` errors.
    """
    var errors = List[CompositionError]()
    var all_type_names = type_names(facts, TypeKind.INPUT_OBJECT)
    for type_index in range(len(all_type_names)):
        var type_name = String(all_type_names[type_index])
        var all_field_names = field_names(
            facts, type_name, TypeKind.INPUT_OBJECT
        )
        # An input object type has fields.
        var field_index = 0
        while field_index < len(all_field_names):
            _check_field(
                facts,
                type_name,
                String(all_field_names[field_index]),
                errors,
                found,
            )
            field_index += 1
    return errors^


def _check_field(
    facts: List[GraphFacts],
    type_name: String,
    field_name: String,
    mut errors: List[CompositionError],
    mut found: List[String],
):
    """Append an error when one input field has two defaults.

    Args:
        facts: The subgraphs, in id order.
        type_name: The input object.
        field_name: The field.
        errors: The errors to append.
        found: Receives `Type.field` when an error is appended.
    """
    var groups = List[_Group]()
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find_kind(type_name, TypeKind.INPUT_OBJECT)
        if type_at == -1:
            continue
        var field_at = graph.types[type_at].find_field(field_name)
        if field_at == -1:
            continue
        ref field = graph.types[type_at].fields[field_at]
        if field.default_value.byte_length() == 0:
            continue
        _add(groups, field.default_value, graph.graph_name)
    if len(groups) < 2:
        return
    found.append(type_name + "." + field_name)
    errors.append(
        CompositionError(
            'Input field "'
            + type_name
            + "."
            + field_name
            + '" has incompatible default values across subgraphs: it has '
            + _join(groups),
            ErrorCode.INPUT_FIELD_DEFAULT_MISMATCH,
            None,
        )
    )


def _add(mut groups: List[_Group], value: String, graph_name: String):
    """Add a subgraph to the group for a default, or start that group.

    Args:
        groups: The groups so far.
        value: The printed default.
        graph_name: The subgraph name.
    """
    for index in range(len(groups)):
        if groups[index].value != value:
            continue
        groups[index].graphs.append(String(graph_name))
        return
    var graphs = List[String]()
    graphs.append(String(graph_name))
    groups.append(_Group(String(value), graphs^))


def _join(groups: List[_Group]) -> String:
    """Join default groups with Hive's `but` and `and`.

    Args:
        groups: At least two groups.

    Returns:
        The text after `it has `.
    """
    var message = _group(groups[0]) + " but " + _group(groups[1])
    for index in range(2, len(groups)):
        message += " and " + _group(groups[index])
    return message


def _group(group: _Group) -> String:
    """Return one default group, as Hive prints it.

    Args:
        group: The default and its subgraphs.

    Returns:
        Such as `default value 5 in subgraph "users"`.
    """
    return (
        "default value " + group.value + " in " + subgraph_place(group.graphs)
    )

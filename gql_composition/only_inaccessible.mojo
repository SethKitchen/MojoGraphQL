# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A public type must keep one visible child.

Port of `OnlyInaccessibleChildrenRule` of Hive Federation Composition
v0.27.0
`src/supergraph/validation/rules/only-inaccessible-children-rule.ts`.

A child is `@inaccessible` when any subgraph marks it `@inaccessible`.
The type is skipped when it is itself `@inaccessible`.
"""

from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.later_versions import GraphFacts
from gql_composition.merged import append_new, field_names, type_names
from gql_composition.state import TypeKind


def check_only_inaccessible(
    facts: List[GraphFacts], mut found: List[String]
) -> List[CompositionError]:
    """Report a type whose children are all `@inaccessible`.

    Args:
        facts: The subgraphs, in id order, after a clean subgraph phase.
        found: Receives the type name for each error, in the same order.

    Returns:
        The `ONLY_INACCESSIBLE_CHILDREN` errors. Objects come first,
        then enums, input objects, and interfaces.
    """
    var errors = List[CompositionError]()
    _kinds(facts, TypeKind.OBJECT, "fields", errors, found)
    _enums(facts, errors, found)
    _kinds(facts, TypeKind.INPUT_OBJECT, "fields", errors, found)
    _kinds(facts, TypeKind.INTERFACE, "fields", errors, found)
    return errors^


def _kinds(
    facts: List[GraphFacts],
    kind: TypeKind,
    child: String,
    mut errors: List[CompositionError],
    mut found: List[String],
):
    """Append errors for object, input, or interface types.

    Args:
        facts: The subgraphs, in id order.
        kind: The kind to check.
        child: `fields`, the word in the message.
        errors: The errors to append.
        found: Receives the type name for each error.
    """
    var names = type_names(facts, kind)
    for name_index in range(len(names)):
        var name = String(names[name_index])
        if _type_hidden(facts, name, kind):
            continue
        if not _all_fields_hidden(facts, name, kind):
            continue
        _append(errors, found, name, child)


def _enums(
    facts: List[GraphFacts],
    mut errors: List[CompositionError],
    mut found: List[String],
):
    """Append errors for enums whose values are all `@inaccessible`.

    Args:
        facts: The subgraphs, in id order.
        errors: The errors to append.
        found: Receives the enum name for each error.
    """
    var names = type_names(facts, TypeKind.ENUM)
    for name_index in range(len(names)):
        var name = String(names[name_index])
        if _type_hidden(facts, name, TypeKind.ENUM):
            continue
        if not _all_values_hidden(facts, name):
            continue
        _append(errors, found, name, "values")


def _append(
    mut errors: List[CompositionError],
    mut found: List[String],
    name: String,
    child: String,
):
    """Append one `ONLY_INACCESSIBLE_CHILDREN` error.

    Args:
        errors: The errors to append.
        found: Receives the type name.
        name: The type name.
        child: `fields` or `values`.
    """
    found.append(String(name))
    errors.append(
        CompositionError(
            'Type "'
            + name
            + '" is in the API schema but all of its '
            + child
            + " are @inaccessible.",
            ErrorCode.ONLY_INACCESSIBLE_CHILDREN,
            None,
        )
    )


def _type_hidden(facts: List[GraphFacts], name: String, kind: TypeKind) -> Bool:
    """Return True when the type is `@inaccessible`.

    Args:
        facts: The subgraphs, in id order.
        name: The type name. Some subgraph defines it.
        kind: The kind.

    Returns:
        Whether Hive skips the type.
    """
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find_kind(name, kind)
        if type_at == -1:
            continue
        if graph.types[type_at].inaccessible:
            return True
    return False


def _all_fields_hidden(
    facts: List[GraphFacts], name: String, kind: TypeKind
) -> Bool:
    """Return True when every field of a type is `@inaccessible`.

    Args:
        facts: The subgraphs, in id order.
        name: The type name.
        kind: The kind.

    Returns:
        Whether each merged field is `@inaccessible`. A type with no
        fields gives True, as upstream `Array.every` does.
    """
    var all_field_names = field_names(facts, name, kind)
    for name_index in range(len(all_field_names)):
        if not _field_hidden(facts, name, all_field_names[name_index], kind):
            return False
    return True


def _field_hidden(
    facts: List[GraphFacts],
    type_name: String,
    field_name: String,
    kind: TypeKind,
) -> Bool:
    """Return True when any subgraph marks the field `@inaccessible`.

    Args:
        facts: The subgraphs, in id order.
        type_name: The type name.
        field_name: The field.
        kind: The kind.

    Returns:
        Whether the merged field is `@inaccessible`.
    """
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find_kind(type_name, kind)
        if type_at == -1:
            continue
        var field_at = graph.types[type_at].find_field(field_name)
        if field_at == -1:
            continue
        if graph.types[type_at].fields[field_at].inaccessible:
            return True
    return False


def _all_values_hidden(facts: List[GraphFacts], name: String) -> Bool:
    """Return True when every enum value is `@inaccessible`.

    Args:
        facts: The subgraphs, in id order.
        name: The enum name.

    Returns:
        Whether each merged value is `@inaccessible`. An enum type has
        values, so the list is not empty.
    """
    var value_names = _value_names(facts, name)
    var name_index = 0
    while name_index < len(value_names):
        if not _value_hidden(facts, name, value_names[name_index]):
            return False
        name_index += 1
    return True


def _value_hidden(
    facts: List[GraphFacts], type_name: String, value_name: String
) -> Bool:
    """Return True when any subgraph marks the enum value `@inaccessible`.

    Args:
        facts: The subgraphs, in id order.
        type_name: The enum name.
        value_name: The value.

    Returns:
        Whether the merged value is `@inaccessible`.
    """
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find_kind(type_name, TypeKind.ENUM)
        if type_at == -1:
            continue
        ref type = graph.types[type_at]
        var value_index = 0
        while value_index < len(type.values):
            var at = value_index
            value_index += 1
            if type.values[at] != value_name:
                continue
            if type.value_hidden[at]:
                return True
    return False


def _value_names(facts: List[GraphFacts], type_name: String) -> List[String]:
    """Return the values of an enum, in first-seen order.

    Args:
        facts: The subgraphs, in id order.
        type_name: The enum name.

    Returns:
        The value names, once each.
    """
    var names = List[String]()
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find_kind(type_name, TypeKind.ENUM)
        if type_at == -1:
            continue
        ref values = graph.types[type_at].values
        var value_index = 0
        while value_index < len(values):
            append_new(names, values[value_index])
            value_index += 1
    return names^

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""An object field that implements an interface field cannot be hidden.

Port of `NoInaccessibleOnImplementedInterfaceFieldsRule` of Hive
Federation Composition v0.27.0
`src/supergraph/validation/rules/no-inaccessible-on-implemented-interface-fields-rule.ts`.

The error is skipped when the object type is `@inaccessible`, or when
the interface field is `@inaccessible`.
"""

from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.later_versions import GraphFacts
from gql_composition.merged import (
    has_field,
    append_new,
    field_names,
    type_names,
)
from gql_composition.state import TypeKind


def check_implemented_inaccessible(
    facts: List[GraphFacts], mut found: List[String]
) -> List[CompositionError]:
    """Report an `@inaccessible` field that implements a public interface field.

    Args:
        facts: The subgraphs, in id order, after a clean subgraph phase.
        found: Receives `Type.field` for each error, in the same order.

    Returns:
        The `IMPLEMENTED_BY_INACCESSIBLE` errors.
    """
    var errors = List[CompositionError]()
    var names = type_names(facts, TypeKind.OBJECT)
    for index in range(len(names)):
        _check_object(facts, String(names[index]), errors, found)
    return errors^


def _check_object(
    facts: List[GraphFacts],
    type_name: String,
    mut errors: List[CompositionError],
    mut found: List[String],
):
    """Append errors for one object type.

    Args:
        facts: The subgraphs, in id order.
        type_name: The object type.
        errors: The errors to append.
        found: Receives `Type.field` for each error.
    """
    if _type_hidden(facts, type_name, TypeKind.OBJECT):
        return
    var interfaces = _interfaces(facts, type_name)
    if len(interfaces) == 0:
        return
    # An object type has fields, and `interfaces` is not empty.
    var fields = field_names(facts, type_name, TypeKind.OBJECT)
    var field_index = 0
    while field_index < len(fields):
        var field_name = String(fields[field_index])
        field_index += 1
        if not _field_hidden(facts, type_name, TypeKind.OBJECT, field_name):
            continue
        var interface_index = 0
        while interface_index < len(interfaces):
            var interface_name = String(interfaces[interface_index])
            interface_index += 1
            if not has_field(
                facts, interface_name, TypeKind.INTERFACE, field_name
            ):
                continue
            if _field_hidden(
                facts, interface_name, TypeKind.INTERFACE, field_name
            ):
                continue
            var coordinate = type_name + "." + field_name
            found.append(coordinate)
            errors.append(
                CompositionError(
                    'Field "'
                    + coordinate
                    + '" is @inaccessible but implements the interface field "'
                    + interface_name
                    + "."
                    + field_name
                    + '", which is in the API schema.',
                    ErrorCode.IMPLEMENTED_BY_INACCESSIBLE,
                    None,
                )
            )


def _type_hidden(facts: List[GraphFacts], name: String, kind: TypeKind) -> Bool:
    """Return True when any subgraph marks the type `@inaccessible`.

    Args:
        facts: The subgraphs, in id order.
        name: The type name.
        kind: The kind.

    Returns:
        Whether the merged type is `@inaccessible`.
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


def _field_hidden(
    facts: List[GraphFacts],
    type_name: String,
    kind: TypeKind,
    field_name: String,
) -> Bool:
    """Return True when any subgraph marks the field `@inaccessible`.

    Args:
        facts: The subgraphs, in id order.
        type_name: The type name.
        kind: The kind.
        field_name: The field.

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


def _interfaces(facts: List[GraphFacts], type_name: String) -> List[String]:
    """Return the interfaces of an object, in first-seen order.

    Args:
        facts: The subgraphs, in id order.
        type_name: The object type.

    Returns:
        The interface names, once each.
    """
    var names = List[String]()
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find_kind(type_name, TypeKind.OBJECT)
        if type_at == -1:
            continue
        ref interfaces = graph.types[type_at].interfaces
        for index in range(len(interfaces)):
            append_new(names, interfaces[index])
    return names^

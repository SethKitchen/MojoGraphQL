# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""An object must define the fields of each interface it implements.

Port of `InterfaceFieldNoImplementationRule` of Hive Federation
Composition v0.27.0
`src/supergraph/validation/rules/interface-field-no-implementation-rule.ts`.

A field that an `@interfaceObject` defines, and does not mark
`@external`, is not required. A type-kind mismatch stops the check for
that object.
"""

from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.later_versions import GraphFacts
from gql_composition.merged import (
    append_new,
    contains,
    field_names,
    subgraph_place,
    type_names,
)
from gql_composition.state import TypeKind


def check_interface_fields(
    facts: List[GraphFacts], mut found: List[String]
) -> List[CompositionError]:
    """Report an interface field that an implementer does not define.

    Args:
        facts: The subgraphs, in id order, after a clean subgraph phase.
        found: Receives the object type name for each error, in the same
            order.

    Returns:
        The `INTERFACE_FIELD_NO_IMPLEM` errors.
    """
    var errors = List[CompositionError]()
    var names = type_names(facts, TypeKind.OBJECT)
    for index in range(len(names)):
        _check_object(facts, String(names[index]), errors, found)
    return errors^


def _check_object(
    facts: List[GraphFacts],
    object_name: String,
    mut errors: List[CompositionError],
    mut found: List[String],
):
    """Append errors for one object type.

    Args:
        facts: The subgraphs, in id order.
        object_name: The object type.
        errors: The errors to append.
        found: Receives the object type name for each error.
    """
    var interfaces = _interfaces(facts, object_name)
    if len(interfaces) == 0:
        return
    var object_fields = field_names(facts, object_name, TypeKind.OBJECT)
    # `interfaces` is not empty, and an interface type has fields.
    var interface_index = 0
    while interface_index < len(interfaces):
        var interface_name = String(interfaces[interface_index])
        interface_index += 1
        if not _is_interface(facts, interface_name):
            return
        var optional = _optional_fields(facts, interface_name)
        var all_field_names = field_names(
            facts, interface_name, TypeKind.INTERFACE
        )
        var field_index = 0
        while field_index < len(all_field_names):
            var field_name = String(all_field_names[field_index])
            field_index += 1
            if contains(optional, field_name):
                continue
            if contains(object_fields, field_name):
                continue
            _report_missing(
                facts,
                object_name,
                interface_name,
                field_name,
                errors,
                found,
            )


def _report_missing(
    facts: List[GraphFacts],
    object_name: String,
    interface_name: String,
    field_name: String,
    mut errors: List[CompositionError],
    mut found: List[String],
):
    """Append one error for each subgraph that implements the interface.

    Args:
        facts: The subgraphs, in id order.
        object_name: The object type.
        interface_name: The interface.
        field_name: The missing field.
        errors: The errors to append.
        found: Receives the object type name for each error.
    """
    var place = subgraph_place(_declared_in(facts, interface_name, field_name))
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        if not _implements(graph, object_name, interface_name):
            continue
        var message = (
            'Interface field "'
            + interface_name
            + "."
            + field_name
            + '" is declared in '
            + place
            + ' but type "'
            + object_name
            + '", which implements "'
            + interface_name
            + '" in subgraph "'
            + graph.graph_name
            + '" does not have field "'
            + field_name
            + '".'
        )
        found.append(String(object_name))
        errors.append(
            CompositionError(message, ErrorCode.INTERFACE_FIELD_NO_IMPLEM, None)
        )


def _optional_fields(
    facts: List[GraphFacts], interface_name: String
) -> List[String]:
    """Return interface fields that an `@interfaceObject` provides.

    Args:
        facts: The subgraphs, in id order.
        interface_name: The interface.

    Returns:
        Field names that implementers do not have to repeat.
    """
    var names = List[String]()
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find_kind(interface_name, TypeKind.INTERFACE)
        if type_at == -1:
            continue
        ref type = graph.types[type_at]
        if not type.is_interface_object:
            continue
        # An `@interfaceObject` type has fields.
        var field_index = 0
        while field_index < len(type.fields):
            ref field = type.fields[field_index]
            field_index += 1
            if not field.external:
                append_new(names, field.name)
    return names^


def _declared_in(
    facts: List[GraphFacts], interface_name: String, field_name: String
) -> List[String]:
    """Return the subgraphs that define an interface field.

    Args:
        facts: The subgraphs, in id order.
        interface_name: The interface.
        field_name: The field.

    Returns:
        The subgraph names, in id order.
    """
    var names = List[String]()
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find_kind(interface_name, TypeKind.INTERFACE)
        if type_at == -1:
            continue
        if graph.types[type_at].find_field(field_name) != -1:
            names.append(String(graph.graph_name))
    return names^


def _is_interface(facts: List[GraphFacts], name: String) -> Bool:
    """Return True when every definition of the name is an interface.

    Args:
        facts: The subgraphs, in id order.
        name: The type name.

    Returns:
        Whether Hive would read the name as an interface type. A subgraph
        state has one type for each name, and the object lists the name,
        so some subgraph defines it.
    """
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find(name)
        if type_at == -1:
            continue
        if graph.types[type_at].kind != TypeKind.INTERFACE:
            return False
    return True


def _interfaces(facts: List[GraphFacts], object_name: String) -> List[String]:
    """Return the interfaces of an object, in first-seen order.

    Args:
        facts: The subgraphs, in id order.
        object_name: The object type.

    Returns:
        The interface names, once each.
    """
    var names = List[String]()
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find_kind(object_name, TypeKind.OBJECT)
        if type_at == -1:
            continue
        ref interfaces = graph.types[type_at].interfaces
        for index in range(len(interfaces)):
            append_new(names, interfaces[index])
    return names^


def _implements(
    graph: GraphFacts, object_name: String, interface_name: String
) -> Bool:
    """Return True when one subgraph's object implements an interface.

    Args:
        graph: One subgraph.
        object_name: The object type.
        interface_name: The interface.

    Returns:
        Whether that subgraph lists the interface.
    """
    var type_at = graph.find_kind(object_name, TypeKind.OBJECT)
    if type_at == -1:
        return False
    return contains(graph.types[type_at].interfaces, interface_name)

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""An `@external` field needs a definition in some subgraph.

Port of `ExternalMissingOnBaseRule` of Hive Federation Composition
v0.27.0
`src/supergraph/validation/rules/external-missing-on-base-rule.ts`.

A key field on an extension is allowed. In Federation 1, an
`@external` field is an error only when a directive uses it. An
`@interfaceObject` field that is not `@external` supplies the base.

The upstream rule also has a check for an object type that is `@external`
in every subgraph. Upstream never sets `external` on an object type state
(`setExternal` of the object type builder has no caller), so that check
never reports. This port leaves it out.
"""

from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.later_versions import FieldFact, GraphFacts
from gql_composition.merged import (
    and_list,
    append_new,
    field_names,
    type_names,
)
from gql_composition.state import TypeKind


def check_external_missing(
    facts: List[GraphFacts], mut found: List[String]
) -> List[CompositionError]:
    """Report a field that is `@external` in every subgraph.

    Args:
        facts: The subgraphs, in id order, after a clean subgraph phase.
        found: Receives `Type.field` for each error, in the same order.

    Returns:
        The `EXTERNAL_MISSING_ON_BASE` errors.
    """
    var errors = List[CompositionError]()
    var all_type_names = type_names(facts, TypeKind.OBJECT)
    var type_index = 0
    while type_index < len(all_type_names):
        var type_name = String(all_type_names[type_index])
        var all_field_names = field_names(facts, type_name, TypeKind.OBJECT)
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
        type_index += 1
    return errors^


def _check_field(
    facts: List[GraphFacts],
    type_name: String,
    field_name: String,
    mut errors: List[CompositionError],
    mut found: List[String],
):
    """Append an error when every subgraph marks the field `@external`.

    Args:
        facts: The subgraphs, in id order.
        type_name: The object type.
        field_name: The field.
        errors: The errors to append.
        found: Receives `Type.field` when an error is appended.
    """
    # The field comes from a subgraph, so `names` is not empty at the end.
    var names = List[String]()
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find_kind(type_name, TypeKind.OBJECT)
        if type_at == -1:
            continue
        var field_at = graph.types[type_at].find_field(field_name)
        if field_at == -1:
            continue
        if not _external_only(
            graph.version_number,
            graph.types[type_at].extension,
            graph.types[type_at].fields[field_at],
        ):
            return
        names.append(String(graph.graph_name))
    if _interface_object_provides(facts, type_name, field_name):
        return
    found.append(type_name + "." + field_name)
    errors.append(_error(type_name + "." + field_name, names))


def _external_only(version: Int, extension: Bool, field: FieldFact) -> Bool:
    """Return True when Hive treats this site as external-only.

    Args:
        version: The federation version number.
        extension: Whether the object type is an extension.
        field: The field.

    Returns:
        Whether this site satisfies the `every` test.
    """
    if field.used_as_key:
        return field.external and not extension
    if version == 100:
        return field.external and field.used
    return field.external


def _interface_object_provides(
    facts: List[GraphFacts], type_name: String, field_name: String
) -> Bool:
    """Return True when an `@interfaceObject` field is not `@external`.

    Args:
        facts: The subgraphs, in id order.
        type_name: The object type.
        field_name: The field.

    Returns:
        Whether Hive skips the field error.
    """
    var interfaces = _interfaces(facts, type_name)
    for name_index in range(len(interfaces)):
        if _interface_field_is_base(facts, interfaces[name_index], field_name):
            return True
    return False


def _interface_field_is_base(
    facts: List[GraphFacts], interface_name: String, field_name: String
) -> Bool:
    """Return True when one `@interfaceObject` copy of the field is concrete.

    Args:
        facts: The subgraphs, in id order.
        interface_name: The interface the object implements.
        field_name: The field.

    Returns:
        Whether that interface object defines the field without
        `@external`.
    """
    # Upstream first checks `hasInterfaceObject`. The loop below reads only
    # `@interfaceObject` copies, so that check changes nothing.
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
        var field_at = type.find_field(field_name)
        if field_at == -1:
            continue
        if not type.fields[field_at].external:
            return True
    return False


def _error(name: String, graphs: List[String]) -> CompositionError:
    """Build one `EXTERNAL_MISSING_ON_BASE` error.

    Args:
        name: The `Type.field` coordinate.
        graphs: The subgraph names, in id order.

    Returns:
        The error.
    """
    var word = String("subgraph")
    if len(graphs) > 1:
        word = "subgraphs"
    return CompositionError(
        'Field "'
        + name
        + '" is marked @external on all the subgraphs in which it is'
        + " listed ("
        + word
        + " "
        + and_list(graphs)
        + ").",
        ErrorCode.EXTERNAL_MISSING_ON_BASE,
        None,
    )


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
        var type_at = facts[graph_index].find_kind(type_name, TypeKind.OBJECT)
        if type_at != -1:
            ref interfaces = facts[graph_index].types[type_at].interfaces
            for name_index in range(len(interfaces)):
                append_new(names, interfaces[name_index])
        graph_index += 1
    return names^

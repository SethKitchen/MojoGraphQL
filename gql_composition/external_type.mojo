# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""An `@external` field must use the same type as its base.

Port of `ExternalTypeMismatchRule` of Hive Federation Composition
v0.27.0
`src/supergraph/validation/rules/external-type-mismatch-rule.ts`.

A key field is skipped. In Federation 1, `@external` counts only on a
federation extension. The base type is the merged output type.
"""

from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.later_versions import GraphFacts, TypeFacts
from gql_composition.merged import and_list, field_names, type_names
from gql_composition.state import ExtensionType, TypeKind


@fieldwise_init
struct _Site(Movable):
    """One subgraph's type for a field."""

    var graph_name: String
    """The subgraph name."""
    var type_text: String
    """The printed type."""
    var external: Bool
    """Whether Hive treats the field as `@external`."""


@fieldwise_init
struct _Group(Movable):
    """One external type and the subgraphs that use it."""

    var type_text: String
    """The printed type."""
    var graphs: List[String]
    """The subgraph names, in id order."""


def check_external_type_mismatch(
    facts: List[GraphFacts], mut found: List[String]
) -> List[CompositionError]:
    """Report an `@external` field whose type differs from the base.

    Args:
        facts: The subgraphs, in id order, after a clean subgraph phase.
        found: Receives `Type.field` for each error, in the same order.

    Returns:
        The `EXTERNAL_TYPE_MISMATCH` errors.
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
    """Append an error when an external type disagrees with the base.

    Args:
        facts: The subgraphs, in id order.
        type_name: The object type.
        field_name: The field.
        errors: The errors to append.
        found: Receives `Type.field` when an error is appended.
    """
    if _used_as_key(facts, type_name, field_name):
        return
    # The field comes from a subgraph, so `sites` is not empty. The site
    # whose type is the merged type is not external or has that type, so
    # `equal` is not empty either.
    var sites = _sites(facts, type_name, field_name)
    var merged = _merged_type(sites)
    var equal = List[String]()
    var groups = List[_Group]()
    var index = 0
    while index < len(sites):
        ref site = sites[index]
        index += 1
        if (not site.external) or site.type_text == merged:
            equal.append(String(site.graph_name))
            continue
        _add_group(groups, site.type_text, site.graph_name)
    if len(groups) == 0:
        return
    var message = (
        'Type of field "'
        + type_name
        + "."
        + field_name
        + '" is incompatible across subgraphs (where marked @external):'
        + " it has "
        + _typed(merged, equal)
        + " but "
        + _typed(groups[0].type_text, groups[0].graphs)
    )
    for index in range(1, len(groups)):
        message += " and " + _typed(
            groups[index].type_text, groups[index].graphs
        )
    found.append(type_name + "." + field_name)
    errors.append(
        CompositionError(message, ErrorCode.EXTERNAL_TYPE_MISMATCH, None)
    )


def _merged_type(sites: List[_Site]) -> String:
    """Return the merged output type, in subgraph id order.

    Args:
        sites: The field sites, in id order.

    Returns:
        The type Hive keeps for the field.
    """
    var merged = String(sites[0].type_text)
    var seen = not sites[0].external
    for index in range(1, len(sites)):
        ref site = sites[index]
        var should_force = not site.external and not seen
        var should_change = should_force or (
            not site.external
            and _last_bang(merged) > _last_bang(site.type_text)
        )
        if should_change:
            merged = String(site.type_text)
        if not seen and not site.external:
            seen = True
    return merged


def _sites(
    facts: List[GraphFacts], type_name: String, field_name: String
) -> List[_Site]:
    """Return each subgraph's type for a field, in id order.

    Args:
        facts: The subgraphs, in id order.
        type_name: The object type.
        field_name: The field.

    Returns:
        The sites that define the field.
    """
    var sites = List[_Site]()
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find_kind(type_name, TypeKind.OBJECT)
        if type_at == -1:
            continue
        ref type = graph.types[type_at]
        var field_at = type.find_field(field_name)
        if field_at == -1:
            continue
        ref field = type.fields[field_at]
        var external = field.external
        if graph.version_number == 100:
            external = external and _federation_extension(type)
        sites.append(
            _Site(String(graph.graph_name), String(field.type_text), external)
        )
    return sites^


def _federation_extension(type: TypeFacts) -> Bool:
    """Return True when Hive treats a Federation 1 object as a federation
    extension.

    Upstream `isFederationExtension` in Federation 1 is true only for an
    extension with `@extends`.

    Args:
        type: The object type in one Federation 1 subgraph.

    Returns:
        Whether `isFederationExtension` is true.
    """
    if not type.extension:
        return False
    return type.extension_type == ExtensionType.EXTENDS


def _used_as_key(
    facts: List[GraphFacts], type_name: String, field_name: String
) -> Bool:
    """Return True when any subgraph uses the field in a `@key`.

    Args:
        facts: The subgraphs, in id order.
        type_name: The object type.
        field_name: The field.

    Returns:
        Whether the merged field is a key field.
    """
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
        if graph.types[type_at].fields[field_at].used_as_key:
            return True
    return False


def _add_group(mut groups: List[_Group], type_text: String, graph_name: String):
    """Add a subgraph to the group for an external type.

    Args:
        groups: The groups so far.
        type_text: The external type.
        graph_name: The subgraph name.
    """
    for index in range(len(groups)):
        ref group = groups[index]
        if group.type_text != type_text:
            continue
        group.graphs.append(String(graph_name))
        return
    var graphs = List[String]()
    graphs.append(String(graph_name))
    groups.append(_Group(String(type_text), graphs^))


def _typed(type_text: String, graphs: List[String]) -> String:
    """Return one type group, as Hive prints it.

    Args:
        type_text: The printed type.
        graphs: The subgraph names.

    Returns:
        Such as `type "[String!]" in subgraph "users"`.
    """
    var plural = String("")
    if len(graphs) > 1:
        plural = "s"
    return (
        'type "' + type_text + '" in subgraph' + plural + " " + and_list(graphs)
    )


def _last_bang(text: String) -> Int:
    """Return the byte index of the last `!`, or -1.

    Args:
        text: A printed type.

    Returns:
        The index Hive's `lastIndexOf` returns.
    """
    return text.rfind("!")

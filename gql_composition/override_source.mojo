# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""An `@override` chain cannot visit a subgraph twice.

Port of `OverrideSourceHasOverrideRule` of Hive Federation Composition
v0.27.0 `src/supergraph/validation/rules/override-source-has-override.ts`.

The rule follows `@override(from:)` from each subgraph that sets it. It
reports an error when that walk returns to a subgraph it already
visited. One `@override` on a field, or a chain that ends, is allowed.
"""

from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.later_versions import GraphFacts
from gql_composition.merged import contains, field_names, type_names
from gql_composition.state import TypeKind


@fieldwise_init
struct _Site(Movable):
    """One subgraph that marks a field with `@override`."""

    var graph_name: String
    """The subgraph name."""
    var override_from: String
    """The `@override(from:)` subgraph name."""


def check_override_source(
    facts: List[GraphFacts], mut found: List[String]
) -> List[CompositionError]:
    """Report an `@override` chain that revisits a subgraph.

    Args:
        facts: The subgraphs, in id order, after a clean subgraph phase.
        found: Receives `Type.field` for each error, in the same order.

    Returns:
        The `OVERRIDE_SOURCE_HAS_OVERRIDE` errors. Object fields come
        first, in Hive's visitor order.
    """
    var errors = List[CompositionError]()
    var all_type_names = type_names(facts, TypeKind.OBJECT)
    for type_index in range(len(all_type_names)):
        var type_name = String(all_type_names[type_index])
        var all_field_names = field_names(facts, type_name, TypeKind.OBJECT)
        for field_index in range(len(all_field_names)):
            var field_name = String(all_field_names[field_index])
            var sites = _sites(facts, type_name, field_name)
            if len(sites) < 2:
                continue
            var site_index = 0
            while site_index < len(sites):
                _walk(
                    facts,
                    sites[site_index],
                    type_name,
                    field_name,
                    errors,
                    found,
                )
                site_index += 1
    return errors^


def _walk(
    facts: List[GraphFacts],
    site: _Site,
    type_name: String,
    field_name: String,
    mut errors: List[CompositionError],
    mut found: List[String],
):
    """Follow one `@override` chain and report a repeated subgraph.

    Args:
        facts: The subgraphs, in id order.
        site: The subgraph where the walk starts.
        type_name: The object type.
        field_name: The field.
        errors: The errors to append.
        found: Receives `Type.field` when an error is appended.
    """
    var current = _graph_named(facts, site.override_from)
    var seen = List[String]()
    while current != -1:
        ref graph = facts[current]
        if contains(seen, graph.graph_name):
            found.append(type_name + "." + field_name)
            errors.append(
                CompositionError(
                    'Field "'
                    + type_name
                    + "."
                    + field_name
                    + '" on subgraph "'
                    + site.graph_name
                    + '" is also marked with directive @override in'
                    + ' subgraph "'
                    + graph.graph_name
                    + '". Only one @override directive is allowed per'
                    + " field.",
                    ErrorCode.OVERRIDE_SOURCE_HAS_OVERRIDE,
                    None,
                )
            )
            return
        seen.append(String(graph.graph_name))
        var next_from = _field_override(graph, type_name, field_name)
        if next_from.byte_length() == 0:
            return
        current = _graph_named(facts, next_from)


def _sites(
    facts: List[GraphFacts], type_name: String, field_name: String
) -> List[_Site]:
    """Return the subgraphs that override one field, in id order.

    Args:
        facts: The subgraphs, in id order.
        type_name: The object type.
        field_name: The field.

    Returns:
        The overriding sites.
    """
    var sites = List[_Site]()
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var from_name = _field_override(graph, type_name, field_name)
        if from_name.byte_length() == 0:
            continue
        sites.append(_Site(String(graph.graph_name), from_name^))
    return sites^


def _field_override(
    graph: GraphFacts, type_name: String, field_name: String
) -> String:
    """Return the `@override(from:)` name on one field, or empty.

    Args:
        graph: One subgraph.
        type_name: The object type.
        field_name: The field.

    Returns:
        The source subgraph name, or empty when the subgraph does not
        define the field or the field has no `@override`.
    """
    var type_at = graph.find_kind(type_name, TypeKind.OBJECT)
    if type_at == -1:
        return String("")
    var field_at = graph.types[type_at].find_field(field_name)
    if field_at == -1:
        return String("")
    return String(graph.types[type_at].fields[field_at].override_from)


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

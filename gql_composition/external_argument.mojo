# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""An `@external` field must repeat the arguments of its base.

Port of `ExternalArgumentMissingRule` of Hive Federation Composition
v0.27.0
`src/supergraph/validation/rules/external-argument-missing-rule.ts`.

When one subgraph declares an argument and another marks the same field
`@external` without that argument, composition reports an error.
"""

from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.later_versions import GraphFacts
from gql_composition.merged import (
    append_new,
    arg_names,
    field_names,
    subgraph_place,
    type_names,
)
from gql_composition.state import TypeKind


@fieldwise_init
struct _Site(Movable):
    """One subgraph's field and whether it declares an argument."""

    var graph_name: String
    """The subgraph name."""
    var external: Bool
    """Whether the field is `@external`."""
    var has_arg: Bool
    """Whether this subgraph declares the argument."""


def check_external_arguments(
    facts: List[GraphFacts], mut found: List[String]
) -> List[CompositionError]:
    """Report an argument missing from an `@external` field.

    Args:
        facts: The subgraphs, in id order, after a clean subgraph phase.
        found: Receives `Type.field` for each error, in the same order.

    Returns:
        The `EXTERNAL_ARGUMENT_MISSING` errors.
    """
    var errors = List[CompositionError]()
    var all_type_names = type_names(facts, TypeKind.OBJECT)
    var type_index = 0
    while type_index < len(all_type_names):
        var type_name = String(all_type_names[type_index])
        var all_field_names = field_names(facts, type_name, TypeKind.OBJECT)
        var field_index = 0
        while field_index < len(all_field_names):
            var field_name = String(all_field_names[field_index])
            _check_field(facts, type_name, field_name, errors, found)
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
    """Append errors for arguments missing on `@external` copies of a field.

    Args:
        facts: The subgraphs, in id order.
        type_name: The object type.
        field_name: The field.
        errors: The errors to append.
        found: Receives `Type.field` when an error is appended.
    """
    var all_arg_names = arg_names(facts, type_name, TypeKind.OBJECT, field_name)
    for arg_index in range(len(all_arg_names)):
        var arg_name = String(all_arg_names[arg_index])
        var sites = _sites(facts, type_name, field_name, arg_name)
        if _all_have_arg(sites):
            continue
        var declared = _declared(sites)
        var missing = _missing(sites)
        if len(missing) == 0:
            continue
        var field_at = type_name + "." + field_name
        var arg_at = field_at + "(" + arg_name + ":)"
        found.append(field_at)
        errors.append(
            CompositionError(
                'Field "'
                + field_at
                + '" is missing argument "'
                + arg_at
                + '" in some subgraphs where it is marked @external:'
                + ' argument "'
                + arg_at
                + '" is declared in '
                + subgraph_place(declared)
                + " but not in "
                + subgraph_place(missing)
                + ' (where "'
                + field_at
                + '" is @external)',
                ErrorCode.EXTERNAL_ARGUMENT_MISSING,
                None,
            )
        )


def _all_have_arg(sites: List[_Site]) -> Bool:
    """Return True when every subgraph that defines the field has the argument.

    Args:
        sites: The field sites, in id order.

    Returns:
        Whether the argument is not missing anywhere.
    """
    var index = 0
    while index < len(sites):
        if not sites[index].has_arg:
            return False
        index += 1
    return True


def _declared(sites: List[_Site]) -> List[String]:
    """Return subgraphs that declare the argument and are not `@external`.

    Args:
        sites: The field sites, in id order.

    Returns:
        The subgraph names.
    """
    var names = List[String]()
    var index = 0
    while index < len(sites):
        if sites[index].has_arg and not sites[index].external:
            names.append(String(sites[index].graph_name))
        index += 1
    return names^


def _missing(sites: List[_Site]) -> List[String]:
    """Return `@external` subgraphs that omit the argument.

    Args:
        sites: The field sites, in id order.

    Returns:
        The subgraph names.
    """
    var names = List[String]()
    var index = 0
    while index < len(sites):
        if (not sites[index].has_arg) and sites[index].external:
            names.append(String(sites[index].graph_name))
        index += 1
    return names^


def _sites(
    facts: List[GraphFacts],
    type_name: String,
    field_name: String,
    arg_name: String,
) -> List[_Site]:
    """Return each subgraph that defines the field.

    Args:
        facts: The subgraphs, in id order.
        type_name: The object type.
        field_name: The field.
        arg_name: The argument being checked.

    Returns:
        The sites, in id order.
    """
    var sites = List[_Site]()
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find_kind(type_name, TypeKind.OBJECT)
        if type_at == -1:
            continue
        ref fields = graph.types[type_at].fields
        var field_index = -1
        while field_index + 1 < len(fields):
            field_index += 1
            if fields[field_index].name != field_name:
                continue
            var has_arg = False
            ref args = fields[field_index].arg_facts
            for arg_index in range(len(args)):
                if args[arg_index].name == arg_name:
                    has_arg = True
            sites.append(
                _Site(
                    String(graph.graph_name),
                    fields[field_index].external,
                    has_arg,
                )
            )
    return sites^

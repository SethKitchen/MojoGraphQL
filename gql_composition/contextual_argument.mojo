# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A `@fromContext` argument must not be required in another subgraph.

Port of `ContextualArgumentRule` of Hive Federation Composition v0.27.0
`src/supergraph/validation/rules/contextual-argument-rule.ts`.

The argument is required in a subgraph when that subgraph omits
`@fromContext`, the type is non-null, and there is no default value.
"""

from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.later_versions import GraphFacts
from gql_composition.merged import (
    append_new,
    arg_names,
    field_names,
    type_names,
)
from gql_composition.state import TypeKind


def check_contextual_arguments(
    facts: List[GraphFacts], mut found: List[String]
) -> List[CompositionError]:
    """Report a contextual argument that another subgraph requires.

    Args:
        facts: The subgraphs, in id order, after a clean subgraph phase.
        found: Receives `Type.field` for each error, in the same order.

    Returns:
        The `CONTEXTUAL_ARGUMENT_NOT_CONTEXTUAL_IN_ALL_SUBGRAPHS` errors.
    """
    var errors = List[CompositionError]()
    var names = type_names(facts, TypeKind.OBJECT)
    var type_index = 0
    while type_index < len(names):
        var type_name = String(names[type_index])
        type_index += 1
        var fields = field_names(facts, type_name, TypeKind.OBJECT)
        var field_index = 0
        while field_index < len(fields):
            var field_name = String(fields[field_index])
            field_index += 1
            var args = arg_names(facts, type_name, TypeKind.OBJECT, field_name)
            for arg_index in range(len(args)):
                var arg_name = String(args[arg_index])
                if not _reports(facts, type_name, field_name, arg_name):
                    continue
                var coordinate = (
                    type_name + "." + field_name + "(" + arg_name + ":)"
                )
                found.append(type_name + "." + field_name)
                errors.append(
                    CompositionError(
                        'Argument "'
                        + coordinate
                        + '" is contextual in at least one subgraph but in "'
                        + coordinate
                        + '" it does not have @fromContext, is not nullable and'
                        " has no default value.",
                        ErrorCode.CONTEXTUAL_ARGUMENT_NOT_CONTEXTUAL_IN_ALL_SUBGRAPHS,
                        None,
                    )
                )
    return errors^


def _reports(
    facts: List[GraphFacts],
    type_name: String,
    field_name: String,
    arg_name: String,
) -> Bool:
    """Return True when Hive reports one argument.

    Args:
        facts: The subgraphs, in id order.
        type_name: The object type.
        field_name: The field.
        arg_name: The argument.

    Returns:
        Whether some subgraph uses `@fromContext` and another requires
        the argument.
    """
    var contextual = False
    var required = False
    # The argument comes from a subgraph, so `facts` is not empty.
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
        ref args = graph.types[type_at].fields[field_at].arg_facts
        for arg_index in range(len(args)):
            if args[arg_index].name != arg_name:
                continue
            if args[arg_index].from_context:
                contextual = True
            elif (
                args[arg_index].type_text.endswith("!")
                and args[arg_index].default_value.byte_length() == 0
            ):
                required = True
    return contextual and required

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A required argument must appear in every subgraph that defines the field.

Port of `RequiredArgumentMissingInSomeSubgraph` of Hive Federation
Composition v0.27.0
`src/supergraph/validation/rules/required-argument-missing-in-some-subgraph-rule.ts`.

The merged argument type is non-null when any subgraph adds `!`. The
rule reports an error when that argument is missing from another
subgraph that defines the field.
"""

from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.later_versions import GraphFacts
from gql_composition.merged import (
    arg_names,
    field_names,
    subgraph_place,
    type_names,
)
from gql_composition.state import TypeKind


def check_required_arguments(
    facts: List[GraphFacts], mut found: List[String]
) -> List[CompositionError]:
    """Report a non-null argument missing from some subgraphs.

    Args:
        facts: The subgraphs, in id order, after a clean subgraph phase.
        found: Receives `Type.field` for each error, in the same order.

    Returns:
        The `REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH` errors.
    """
    var errors = List[CompositionError]()
    for ref type_name in type_names(facts, TypeKind.OBJECT):
        for ref field_name in field_names(facts, type_name, TypeKind.OBJECT):
            _check_field(facts, type_name, field_name, errors, found)
    return errors^


def _check_field(
    facts: List[GraphFacts],
    type_name: String,
    field_name: String,
    mut errors: List[CompositionError],
    mut found: List[String],
):
    """Append errors for one field's required arguments.

    Args:
        facts: The subgraphs, in id order.
        type_name: The object type.
        field_name: The field.
        errors: The errors to append.
        found: Receives `Type.field` when an error is appended.
    """
    for ref arg_name in arg_names(
        facts, type_name, TypeKind.OBJECT, field_name
    ):
        var required = List[String]()
        var missing = List[String]()
        var graph_index = 0
        while graph_index < len(facts):
            ref graph = facts[graph_index]
            graph_index += 1
            var at = graph.find_kind(type_name, TypeKind.OBJECT)
            if at == -1:
                continue
            var field = graph.types[at].find_field(field_name)
            if field == -1:
                continue
            var present = False
            ref args = graph.types[at].fields[field].arg_facts
            for arg_index in range(len(args)):
                if args[arg_index].name == arg_name:
                    present = True
                    if args[arg_index].type_text.endswith("!"):
                        required.append(graph.graph_name)
            if not present:
                missing.append(graph.graph_name)
        if len(required) == 0 or len(missing) == 0:
            continue
        found.append(type_name + "." + field_name)
        errors.append(
            CompositionError(
                'Argument "'
                + type_name
                + "."
                + field_name
                + "("
                + arg_name
                + ':)" is required in some subgraphs but does not appear'
                + " in all subgraphs: it is required in "
                + subgraph_place(required)
                + " but does not appear in "
                + subgraph_place(missing),
                ErrorCode.REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH,
                None,
            )
        )

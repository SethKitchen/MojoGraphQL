# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A required input field must appear in every subgraph that defines the input.

Port of `RequiredInputFieldMissingInSomeSubgraphRule` of Hive Federation
Composition v0.27.0
`src/supergraph/validation/rules/required-input-field-missing-in-some-subgraph-rule.ts`.

The merged field type is non-null when any subgraph adds `!`. The rule
reports an error when that field is missing from another subgraph that
defines the input object.
"""

from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.later_versions import GraphFacts
from gql_composition.merged import field_names, subgraph_place, type_names
from gql_composition.state import TypeKind


def check_required_input_fields(
    facts: List[GraphFacts], mut found: List[String]
) -> List[CompositionError]:
    """Report a non-null input field missing from some subgraphs.

    Args:
        facts: The subgraphs, in id order, after a clean subgraph phase.
        found: Receives `Type.field` for each error, in the same order.

    Returns:
        The `REQUIRED_INPUT_FIELD_MISSING_IN_SOME_SUBGRAPH` errors.
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
    """Append an error when a required input field is missing somewhere.

    The merged type is non-null when some subgraph has a non-null type.
    An input in one subgraph, or a field in every subgraph of the input,
    has no missing subgraph.

    Args:
        facts: The subgraphs, in id order.
        type_name: The input object.
        field_name: The field.
        errors: The errors to append.
        found: Receives `Type.field` when an error is appended.
    """
    var required = List[String]()
    var missing = List[String]()
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find_kind(type_name, TypeKind.INPUT_OBJECT)
        if type_at == -1:
            continue
        var field_at = graph.types[type_at].find_field(field_name)
        if field_at == -1:
            missing.append(String(graph.graph_name))
        elif graph.types[type_at].fields[field_at].type_text.endswith("!"):
            required.append(String(graph.graph_name))
    if len(missing) == 0 or len(required) == 0:
        return
    found.append(type_name + "." + field_name)
    errors.append(
        CompositionError(
            'Input object field "'
            + type_name
            + "."
            + field_name
            + '" is required in some subgraphs but does not appear in'
            + " all subgraphs: it is required in "
            + subgraph_place(required)
            + " but does not appear in "
            + subgraph_place(missing),
            ErrorCode.REQUIRED_INPUT_FIELD_MISSING_IN_SOME_SUBGRAPH,
            None,
        )
    )

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""An input object must keep one field that every subgraph defines.

Port of `InputObjectValuesRule` of Hive Federation Composition v0.27.0
`src/supergraph/validation/rules/input-object-values-rule.ts`.

Hive merges an input object by keeping only the fields that every
subgraph defines. When that set is empty, the merged type would have
no fields.
"""

from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.later_versions import GraphFacts
from gql_composition.merged import type_names
from gql_composition.state import TypeKind


def check_input_values(
    facts: List[GraphFacts], mut found: List[String]
) -> List[CompositionError]:
    """Report an input object that would merge to no fields.

    Args:
        facts: The subgraphs, in id order, after a clean subgraph phase.
        found: Receives the input type name for each error.

    Returns:
        The `EMPTY_MERGED_INPUT_TYPE` errors, in first-seen type order.
    """
    var names = type_names(facts, TypeKind.INPUT_OBJECT)
    var errors = List[CompositionError]()
    for name_index in range(len(names)):
        var name = String(names[name_index])
        if _has_common_field(facts, name):
            continue
        found.append(String(name))
        errors.append(
            CompositionError(
                'None of the fields of input object type "'
                + name
                + '" are consistently defined in all the subgraphs'
                + " defining that type. As only fields common to all"
                + " subgraphs are merged, this would result in an empty"
                + " type.",
                ErrorCode.EMPTY_MERGED_INPUT_TYPE,
                None,
            )
        )
    return errors^


def _has_common_field(facts: List[GraphFacts], name: String) -> Bool:
    """Return True when one field is in every subgraph that defines the input.

    Args:
        facts: The subgraphs, in id order.
        name: The input object name.

    Returns:
        Whether the merged input would keep a field. One subgraph is
        enough when it defines the type alone.
    """
    # The name comes from a subgraph, and an input object type has fields,
    # so each loop below runs at least once.
    var total = 0
    var field_names = List[String]()
    var counts = List[Int]()
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find_kind(name, TypeKind.INPUT_OBJECT)
        if type_at == -1:
            continue
        total += 1
        ref fields = graph.types[type_at].fields
        var field_index = 0
        while field_index < len(fields):
            _count(field_names, counts, fields[field_index].name)
            field_index += 1
    var index = 0
    while index < len(counts):
        if counts[index] == total:
            return True
        index += 1
    return False


def _count(mut names: List[String], mut counts: List[Int], name: String):
    """Add one to the count for a field name.

    Args:
        names: The field names, parallel to `counts`.
        counts: How many subgraphs define each field.
        name: The field name.
    """
    var index = 0
    while index < len(names):
        if names[index] == name:
            counts[index] += 1
            return
        index += 1
    names.append(String(name))
    counts.append(1)

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A `@listSize` slicing argument must exist on every copy of the field.

Port of `ListSizeSlicingArgumentsRule` of Hive Federation Composition
v0.27.0
`src/supergraph/validation/rules/list-size-slicing-arguments-rule.ts`.

An argument that is missing from one subgraph is disregarded. When every
slicing argument is disregarded, the field is an error.
"""

from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.later_versions import GraphFacts
from gql_composition.merged import append_new, field_names, type_names
from gql_composition.state import TypeKind


def check_list_size_slicing(
    facts: List[GraphFacts], mut found: List[String]
) -> List[CompositionError]:
    """Report a field whose `@listSize` slicing arguments were all dropped.

    Args:
        facts: The subgraphs, in id order, after a clean subgraph phase.
        found: Receives `Type.field` for each error, in the same order.

    Returns:
        The `LIST_SIZE_INVALID_SLICING_ARGUMENT` errors.
    """
    var errors = List[CompositionError]()
    _check_kind(facts, TypeKind.OBJECT, errors, found)
    _check_kind(facts, TypeKind.INTERFACE, errors, found)
    return errors^


def _check_kind(
    facts: List[GraphFacts],
    kind: TypeKind,
    mut errors: List[CompositionError],
    mut found: List[String],
):
    """Append errors for every type of one kind.

    Args:
        facts: The subgraphs, in id order.
        kind: `OBJECT` or `INTERFACE`.
        errors: The errors to append.
        found: Receives `Type.field` for each error.
    """
    var names = type_names(facts, kind)
    for type_index in range(len(names)):
        var type_name = String(names[type_index])
        var fields = field_names(facts, type_name, kind)
        for field_index in range(len(fields)):
            var field_name = String(fields[field_index])
            if not _all_disregarded(facts, type_name, kind, field_name):
                continue
            var coordinate = type_name + "." + field_name
            found.append(coordinate)
            errors.append(
                CompositionError(
                    'All arguments for @listSize(slicingArguments:) on field "'
                    + coordinate
                    + '" were disregarded. For an argument to be valid, it must'
                    " be defined in every subgraph where the field exists.",
                    ErrorCode.LIST_SIZE_INVALID_SLICING_ARGUMENT,
                    None,
                )
            )


def _all_disregarded(
    facts: List[GraphFacts],
    type_name: String,
    kind: TypeKind,
    field_name: String,
) -> Bool:
    """Return True when every slicing argument is missing somewhere.

    Args:
        facts: The subgraphs, in id order.
        type_name: The type name.
        kind: `OBJECT` or `INTERFACE`.
        field_name: The field.

    Returns:
        Whether Hive reports the field. A field with no slicing arguments
        is not reported.
    """
    var graphs = _field_graphs(facts, type_name, kind, field_name)
    var names = _slicing_names(facts, type_name, kind, field_name, graphs)
    if len(names) == 0:
        return False
    var index = 0
    while index < len(names):
        if _arg_in_every(
            facts, type_name, kind, field_name, names[index], graphs
        ):
            return False
        index += 1
    return True


def _slicing_names(
    facts: List[GraphFacts],
    type_name: String,
    kind: TypeKind,
    field_name: String,
    graphs: List[Int],
) -> List[String]:
    """Return the merged slicing argument names, in first-seen order.

    Args:
        facts: The subgraphs, in id order.
        type_name: The type name.
        kind: `OBJECT` or `INTERFACE`.
        field_name: The field.
        graphs: The subgraphs that define the field. It is not empty.

    Returns:
        The names, once each.
    """
    var names = List[String]()
    var index = 0
    while index < len(graphs):
        ref graph = facts[graphs[index]]
        index += 1
        ref type = graph.types[graph.find_kind(type_name, kind)]
        ref slicing = type.fields[type.find_field(field_name)].slicing_arguments
        for name_index in range(len(slicing)):
            append_new(names, slicing[name_index])
    return names^


def _field_graphs(
    facts: List[GraphFacts],
    type_name: String,
    kind: TypeKind,
    field_name: String,
) -> List[Int]:
    """Return the subgraph indexes that define a field.

    Args:
        facts: The subgraphs, in id order.
        type_name: The type name.
        kind: `OBJECT` or `INTERFACE`.
        field_name: The field.

    Returns:
        The indexes.
    """
    var graphs = List[Int]()
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find_kind(type_name, kind)
        if type_at == -1:
            continue
        if graph.types[type_at].find_field(field_name) != -1:
            graphs.append(graph_index - 1)
    return graphs^


def _arg_in_every(
    facts: List[GraphFacts],
    type_name: String,
    kind: TypeKind,
    field_name: String,
    arg_name: String,
    graphs: List[Int],
) -> Bool:
    """Return True when every field copy defines an argument.

    Args:
        facts: The subgraphs, in id order.
        type_name: The type name.
        kind: `OBJECT` or `INTERFACE`.
        field_name: The field.
        arg_name: The argument.
        graphs: The subgraphs that define the field. It is not empty.

    Returns:
        Whether the argument is on the field in each of those subgraphs.
    """
    var index = 0
    while index < len(graphs):
        ref graph = facts[graphs[index]]
        index += 1
        ref type = graph.types[graph.find_kind(type_name, kind)]
        ref args = type.fields[type.find_field(field_name)].arg_facts
        var arg_index = 0
        while arg_index < len(args) and args[arg_index].name != arg_name:
            arg_index += 1
        if arg_index == len(args):
            return False
    return True

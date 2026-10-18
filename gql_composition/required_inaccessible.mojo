# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A required field or argument cannot be `@inaccessible`.

Port of `RequiredArgumentOrFieldIsNotInaccessibleRule` of Hive Federation
Composition v0.27.0
`src/supergraph/validation/rules/required-argument-or-field-is-not-inaccessible-rule.ts`.

A non-null type with no default is required. `@inaccessible` on the
parent input type, or on the object field, suppresses the error.
"""

from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.later_versions import FieldFact, GraphFacts
from gql_composition.merged import (
    append_new,
    arg_names,
    field_names,
    type_names,
)
from gql_composition.state import TypeKind


def check_required_inaccessible(
    facts: List[GraphFacts],
    mut field_errors: List[CompositionError],
    mut field_found: List[String],
    mut arg_errors: List[CompositionError],
    mut arg_found: List[String],
):
    """Report a required `@inaccessible` input field or argument.

    Args:
        facts: The subgraphs, in id order, after a clean subgraph phase.
        field_errors: Receives the input-field errors.
        field_found: Receives `Type.field` for each input-field error.
        arg_errors: Receives the argument errors.
        arg_found: Receives `Type.field` for each argument error.
    """
    var inputs = type_names(facts, TypeKind.INPUT_OBJECT)
    for index in range(len(inputs)):
        _check_input(facts, String(inputs[index]), field_errors, field_found)
    var objects = type_names(facts, TypeKind.OBJECT)
    for index in range(len(objects)):
        _check_object(facts, String(objects[index]), arg_errors, arg_found)


def _check_input(
    facts: List[GraphFacts],
    type_name: String,
    mut errors: List[CompositionError],
    mut found: List[String],
):
    """Append errors for one input object.

    Args:
        facts: The subgraphs, in id order.
        type_name: The input type.
        errors: The errors to append.
        found: Receives `Type.field` for each error.
    """
    if _type_hidden(facts, type_name, TypeKind.INPUT_OBJECT):
        return
    var fields = field_names(facts, type_name, TypeKind.INPUT_OBJECT)
    # An input object type has fields.
    var index = 0
    while index < len(fields):
        var field_name = String(fields[index])
        index += 1
        if not _input_field_errors(facts, type_name, field_name):
            continue
        found.append(type_name + "." + field_name)
        errors.append(
            CompositionError(
                'Input field "'
                + type_name
                + "."
                + field_name
                + '" is @inaccessible but is a required input field of its'
                " type.",
                ErrorCode.REQUIRED_INACCESSIBLE,
                None,
            )
        )


def _check_object(
    facts: List[GraphFacts],
    type_name: String,
    mut errors: List[CompositionError],
    mut found: List[String],
):
    """Append errors for one object type.

    Args:
        facts: The subgraphs, in id order.
        type_name: The object type.
        errors: The errors to append.
        found: Receives `Type.field` for each error.
    """
    var fields = field_names(facts, type_name, TypeKind.OBJECT)
    for field_index in range(len(fields)):
        var field_name = String(fields[field_index])
        if _field_hidden(facts, type_name, field_name):
            continue
        var args = arg_names(facts, type_name, TypeKind.OBJECT, field_name)
        for arg_index in range(len(args)):
            var arg_name = String(args[arg_index])
            if not _arg_errors(facts, type_name, field_name, arg_name):
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
                    + ':)" is @inaccessible but is a required argument of its'
                    " field.",
                    ErrorCode.REQUIRED_INACCESSIBLE,
                    None,
                )
            )


def _input_field_errors(
    facts: List[GraphFacts], type_name: String, field_name: String
) -> Bool:
    """Return True when a merged input field is required and hidden.

    Args:
        facts: The subgraphs, in id order.
        type_name: The input type.
        field_name: The field.

    Returns:
        Whether Hive reports the field.
    """
    var hidden = False
    var non_null = False
    var has_default = False
    var seen = False
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find_kind(type_name, TypeKind.INPUT_OBJECT)
        if type_at == -1:
            continue
        var field_at = graph.types[type_at].find_field(field_name)
        if field_at == -1:
            continue
        ref field = graph.types[type_at].fields[field_at]
        seen = True
        if field.inaccessible:
            hidden = True
        if field.type_text.endswith("!"):
            non_null = True
        if field.default_value.byte_length() > 0:
            has_default = True
    return seen and hidden and non_null and not has_default


def _arg_errors(
    facts: List[GraphFacts],
    type_name: String,
    field_name: String,
    arg_name: String,
) -> Bool:
    """Return True when a merged argument is required and hidden.

    Args:
        facts: The subgraphs, in id order.
        type_name: The object type.
        field_name: The field.
        arg_name: The argument.

    Returns:
        Whether Hive reports the argument.
    """
    var hidden = False
    var non_null = False
    var has_default = False
    var seen = False
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var arg_at = _arg_index(graph, type_name, field_name, arg_name)
        if arg_at == -1:
            continue
        var field_at = _object_field(graph, type_name, field_name)
        ref arg = graph.types[field_at[0]].fields[field_at[1]].arg_facts[arg_at]
        seen = True
        if arg.inaccessible:
            hidden = True
        if arg.type_text.endswith("!"):
            non_null = True
        if arg.default_value.byte_length() > 0:
            has_default = True
    return seen and hidden and non_null and not has_default


def _type_hidden(facts: List[GraphFacts], name: String, kind: TypeKind) -> Bool:
    """Return True when any subgraph marks the type `@inaccessible`.

    Args:
        facts: The subgraphs, in id order.
        name: The type name.
        kind: The kind.

    Returns:
        Whether the merged type is `@inaccessible`.
    """
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find_kind(name, kind)
        if type_at == -1:
            continue
        if graph.types[type_at].inaccessible:
            return True
    return False


def _field_hidden(
    facts: List[GraphFacts], type_name: String, field_name: String
) -> Bool:
    """Return True when any subgraph marks the object field `@inaccessible`.

    Args:
        facts: The subgraphs, in id order.
        type_name: The object type.
        field_name: The field.

    Returns:
        Whether the merged field is `@inaccessible`.
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
        if graph.types[type_at].fields[field_at].inaccessible:
            return True
    return False


def _object_field(
    graph: GraphFacts, type_name: String, field_name: String
) -> List[Int]:
    """Return the type index and the field index, or -1 and -1.

    Args:
        graph: One subgraph.
        type_name: The object type.
        field_name: The field.

    Returns:
        Two indexes. The first is -1 when the field is absent.
    """
    var place = List[Int]()
    var type_at = graph.find_kind(type_name, TypeKind.OBJECT)
    if type_at == -1:
        place.append(-1)
        place.append(-1)
        return place^
    var field_at = graph.types[type_at].find_field(field_name)
    place.append(type_at)
    place.append(field_at)
    return place^


def _arg_index(
    graph: GraphFacts, type_name: String, field_name: String, arg_name: String
) -> Int:
    """Return the index of an argument, or -1.

    Args:
        graph: One subgraph.
        type_name: The object type.
        field_name: The field.
        arg_name: The argument.

    Returns:
        The index in the field's arguments, or -1.
    """
    var place = _object_field(graph, type_name, field_name)
    if place[1] == -1:
        return -1
    ref args = graph.types[place[0]].fields[place[1]].arg_facts
    for index in range(len(args)):
        if args[index].name == arg_name:
            return index
    return -1

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A public field must not reference an `@inaccessible` type.

Port of `ReferencedInaccessibleRule` of Hive Federation Composition
v0.27.0
`src/supergraph/validation/rules/referenced-inaccessible-rule.ts`.

An output field may reference an enum, object, interface, union, or
scalar. An argument may reference an enum or an input object. The
reference is allowed when the field, the argument, or the parent type
is `@inaccessible`.
"""

from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.later_versions import GraphFacts
from gql_composition.merged import arg_names, field_names, type_names
from gql_composition.state import TypeKind


def check_referenced_inaccessible(
    facts: List[GraphFacts],
    mut field_errors: List[CompositionError],
    mut field_found: List[String],
    mut arg_errors: List[CompositionError],
    mut arg_found: List[String],
):
    """Report a public reference to an `@inaccessible` type.

    Args:
        facts: The subgraphs, in id order, after a clean subgraph phase.
        field_errors: Receives the field errors.
        field_found: Receives `Type.field` for each field error.
        arg_errors: Receives the argument errors.
        arg_found: Receives `Type.field` for each argument error.
    """
    for ref type_name in type_names(facts, TypeKind.OBJECT):
        for ref field_name in field_names(facts, type_name, TypeKind.OBJECT):
            _check_field(
                facts, type_name, field_name, field_errors, field_found
            )
            _check_args(facts, type_name, field_name, arg_errors, arg_found)


def _check_field(
    facts: List[GraphFacts],
    type_name: String,
    field_name: String,
    mut errors: List[CompositionError],
    mut found: List[String],
):
    """Append an error when a public field returns an inaccessible type.

    Args:
        facts: The subgraphs, in id order.
        type_name: The object type.
        field_name: The field.
        errors: The errors to append.
        found: Receives `Type.field` when an error is appended.
    """
    # Some subgraph defines the field, so `type_text` is set.
    var type_text = String("")
    var hidden = False
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find_kind(type_name, TypeKind.OBJECT)
        if type_at == -1:
            continue
        ref type = graph.types[type_at]
        if type.inaccessible:
            hidden = True
        var field_index = type.find_field(field_name)
        if field_index == -1:
            continue
        if type.fields[field_index].inaccessible:
            hidden = True
        type_text = type.fields[field_index].type_text
    if hidden:
        return
    var named = _named(type_text)
    if not _output_hidden(facts, named):
        return
    var coordinate = type_name + "." + field_name
    found.append(coordinate)
    errors.append(_error(named, coordinate))


def _check_args(
    facts: List[GraphFacts],
    type_name: String,
    field_name: String,
    mut errors: List[CompositionError],
    mut found: List[String],
):
    """Append errors for public arguments whose type is inaccessible.

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
        # Some subgraph defines the argument, so `type_text` is set.
        var type_text = String("")
        var hidden = False
        var graph_index = 0
        while graph_index < len(facts):
            ref graph = facts[graph_index]
            graph_index += 1
            var type_at = graph.find_kind(type_name, TypeKind.OBJECT)
            if type_at == -1:
                continue
            ref type = graph.types[type_at]
            if type.inaccessible:
                hidden = True
            var field_index = type.find_field(field_name)
            if field_index == -1:
                continue
            if type.fields[field_index].inaccessible:
                hidden = True
            ref args = type.fields[field_index].arg_facts
            for inner in range(len(args)):
                if args[inner].name != arg_name:
                    continue
                if args[inner].inaccessible:
                    hidden = True
                type_text = args[inner].type_text
        if hidden:
            continue
        var named = _named(type_text)
        if not _input_hidden(facts, named):
            continue
        found.append(type_name + "." + field_name)
        errors.append(
            _error(named, type_name + "." + field_name + "(" + arg_name + ":)")
        )


def _error(type_name: String, shown: String) -> CompositionError:
    """Build one `REFERENCED_INACCESSIBLE` error.

    Args:
        type_name: The inaccessible type.
        shown: The field or argument coordinate.

    Returns:
        The error.
    """
    return CompositionError(
        'Type "'
        + type_name
        + '" is @inaccessible but is referenced by "'
        + shown
        + '", which is in the API schema.',
        ErrorCode.REFERENCED_INACCESSIBLE,
        None,
    )


def _output_hidden(facts: List[GraphFacts], name: String) -> Bool:
    """Return True when the first output type of this name is `@inaccessible`.

    Args:
        facts: The subgraphs, in id order.
        name: The named type.

    Returns:
        Whether Hive's output lookup finds an `@inaccessible` type.
        The lookup order is enum, object, interface, union, then scalar.
    """
    var state = _kind_state(facts, name, TypeKind.ENUM)
    if state == -1:
        state = _kind_state(facts, name, TypeKind.OBJECT)
    if state == -1:
        state = _kind_state(facts, name, TypeKind.INTERFACE)
    if state == -1:
        state = _kind_state(facts, name, TypeKind.UNION)
    if state == -1:
        state = _kind_state(facts, name, TypeKind.SCALAR)
    return state == 1


def _input_hidden(facts: List[GraphFacts], name: String) -> Bool:
    """Return True when the first input type of this name is `@inaccessible`.

    Args:
        facts: The subgraphs, in id order.
        name: The named type.

    Returns:
        Whether an enum, or else an input object, is `@inaccessible`.
    """
    var state = _kind_state(facts, name, TypeKind.ENUM)
    if state == -1:
        state = _kind_state(facts, name, TypeKind.INPUT_OBJECT)
    return state == 1


def _kind_state(facts: List[GraphFacts], name: String, kind: TypeKind) -> Int:
    """Return whether a type of one kind exists and is `@inaccessible`.

    Args:
        facts: The subgraphs, in id order.
        name: The type name.
        kind: The kind.

    Returns:
        `-1` when no subgraph has the type, `1` when any subgraph marks
        it `@inaccessible`, and `0` when it exists and is visible.
    """
    var saw = False
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find_kind(name, kind)
        if type_at == -1:
            continue
        saw = True
        if graph.types[type_at].inaccessible:
            return 1
    if saw:
        return 0
    return -1


def _named(type_text: String) -> String:
    """Drop list brackets and non-null marks from a printed type.

    Args:
        type_text: A printed type, such as `[User!]!`.

    Returns:
        The named type.
    """
    return type_text.replace("[", "").replace("]", "").replace("!", "")

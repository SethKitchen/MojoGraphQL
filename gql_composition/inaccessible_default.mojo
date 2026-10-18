# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A public default must not use an `@inaccessible` enum value.

Port of `DefaultValueUsesInaccessibleRule` of Hive Federation
Composition v0.27.0
`src/supergraph/validation/rules/default-value-uses-inaccessible-rule.ts`.

The check skips a field or argument that is itself `@inaccessible`.
It reports an error when the default names an `@inaccessible` enum or
enum value.
"""

from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.later_versions import GraphFacts
from gql_composition.merged import arg_names, field_names, type_names
from gql_composition.state import TypeKind


def check_inaccessible_defaults(
    facts: List[GraphFacts], mut found: List[String]
) -> List[CompositionError]:
    """Report a default that uses an `@inaccessible` enum value.

    Args:
        facts: The subgraphs, in id order, after a clean subgraph phase.
        found: Receives `Type.field` for each error, in the same order.

    Returns:
        The `DEFAULT_VALUE_USES_INACCESSIBLE` errors. Input fields come
        before object-field arguments.
    """
    var errors = List[CompositionError]()
    _input_fields(facts, errors, found)
    _arguments(facts, errors, found)
    return errors^


def _input_fields(
    facts: List[GraphFacts],
    mut errors: List[CompositionError],
    mut found: List[String],
):
    """Append errors for input-field defaults.

    Args:
        facts: The subgraphs, in id order.
        errors: The errors to append.
        found: Receives `Type.field` when an error is appended.
    """
    var all_type_names = type_names(facts, TypeKind.INPUT_OBJECT)
    for type_index in range(len(all_type_names)):
        var type_name = String(all_type_names[type_index])
        var all_field_names = field_names(
            facts, type_name, TypeKind.INPUT_OBJECT
        )
        # An input object type has fields, and `facts` is not empty.
        var field_index = 0
        while field_index < len(all_field_names):
            var field_name = String(all_field_names[field_index])
            field_index += 1
            var merged = String("")
            var type_text = String("")
            var hidden = False
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
                if field.inaccessible:
                    hidden = True
                if field.default_value.byte_length() == 0:
                    continue
                merged = String(field.default_value)
                type_text = String(field.type_text)
            if hidden or merged.byte_length() == 0:
                continue
            _report(
                facts,
                errors,
                found,
                type_name + "." + field_name,
                type_name + "." + field_name,
                type_text,
                merged,
            )


def _arguments(
    facts: List[GraphFacts],
    mut errors: List[CompositionError],
    mut found: List[String],
):
    """Append errors for field-argument defaults.

    Args:
        facts: The subgraphs, in id order.
        errors: The errors to append.
        found: Receives `Type.field` when an error is appended.
    """
    var all_type_names = type_names(facts, TypeKind.OBJECT)
    for type_index in range(len(all_type_names)):
        var type_name = String(all_type_names[type_index])
        var all_field_names = field_names(facts, type_name, TypeKind.OBJECT)
        # An object type has fields.
        var field_index = 0
        while field_index < len(all_field_names):
            var field_name = String(all_field_names[field_index])
            field_index += 1
            var all_arg_names = arg_names(
                facts, type_name, TypeKind.OBJECT, field_name
            )
            for arg_index in range(len(all_arg_names)):
                var arg_name = String(all_arg_names[arg_index])
                _one_argument(
                    facts, type_name, field_name, arg_name, errors, found
                )


def _one_argument(
    facts: List[GraphFacts],
    type_name: String,
    field_name: String,
    arg_name: String,
    mut errors: List[CompositionError],
    mut found: List[String],
):
    """Append an error for one argument when its default is inaccessible.

    Args:
        facts: The subgraphs, in id order.
        type_name: The object type.
        field_name: The field.
        arg_name: The argument.
        errors: The errors to append.
        found: Receives `Type.field` when an error is appended.
    """
    var merged = String("")
    var type_text = String("")
    var hidden = False
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
            if args[arg_index].inaccessible:
                hidden = True
            if args[arg_index].default_value.byte_length() == 0:
                continue
            merged = String(args[arg_index].default_value)
            type_text = String(args[arg_index].type_text)
    if hidden or merged.byte_length() == 0:
        return
    var coordinate = type_name + "." + field_name
    _report(
        facts,
        errors,
        found,
        coordinate,
        coordinate + "(" + arg_name + ":)",
        type_text,
        merged,
    )


def _report(
    facts: List[GraphFacts],
    mut errors: List[CompositionError],
    mut found: List[String],
    field_at: String,
    shown: String,
    type_text: String,
    default_value: String,
):
    """Append an error when the default names an inaccessible enum value.

    Args:
        facts: The subgraphs, in id order.
        errors: The errors to append.
        found: Receives `field_at` when an error is appended.
        field_at: `Type.field`, used to order the error.
        shown: The coordinate in the message.
        type_text: The printed type of the field or argument.
        default_value: The merged printed default.
    """
    var enum_name = _named(type_text)
    if not _enum_or_value_hidden(facts, enum_name, default_value):
        return
    found.append(String(field_at))
    errors.append(
        CompositionError(
            'Enum value "'
            + enum_name
            + "."
            + default_value
            + '" is @inaccessible but is used in the default value of "'
            + shown
            + '", which is in the API schema.',
            ErrorCode.DEFAULT_VALUE_USES_INACCESSIBLE,
            None,
        )
    )


def _enum_or_value_hidden(
    facts: List[GraphFacts], enum_name: String, value_name: String
) -> Bool:
    """Return True when the enum or the named value is `@inaccessible`.

    Args:
        facts: The subgraphs, in id order.
        enum_name: The enum name.
        value_name: The printed default.

    Returns:
        Whether Hive treats that value as inaccessible. False when the
        name is not an enum.
    """
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find_kind(enum_name, TypeKind.ENUM)
        if type_at == -1:
            continue
        ref type = graph.types[type_at]
        if type.inaccessible:
            return True
        # An enum type has values.
        var value_index = 0
        while value_index < len(type.values):
            var at = value_index
            value_index += 1
            if type.values[at] != value_name:
                continue
            if type.value_hidden[at]:
                return True
    return False


def _named(type_text: String) -> String:
    """Drop list brackets and non-null marks from a printed type.

    Args:
        type_text: A printed type, such as `[FriendType!]!`.

    Returns:
        The named type.
    """
    return type_text.replace("[", "").replace("]", "").replace("!", "")

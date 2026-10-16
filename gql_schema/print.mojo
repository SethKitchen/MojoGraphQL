# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Print a schema as SDL.

Port of graphql-js 16.14.2 `utilities/printSchema.ts`: `printSchema`,
`printIntrospectionSchema` and `printType`. The output is the same text,
byte for byte: the schema definition when the root types are not named
Query, Mutation and Subscription, then the directives, then the types, in
type map order.
"""

from gql_language.block_string import (
    is_printable_as_block_string,
    print_block_string,
    print_string,
)
from gql_language.ast import Role
from gql_schema.builtins import (
    DEFAULT_DEPRECATION_REASON,
    SPECIFIED_DIRECTIVE_NAMES,
)
from gql_schema.definition import NO_TYPE, AstRef, Range, Schema, TypeKind
from gql_schema.values import print_default


def _print_description(
    schema: Schema,
    at: AstRef,
    indentation: StaticString = "",
    first_in_block: Bool = True,
) -> String:
    """Print a description and a line break, as `printDescription`."""
    if not at.exists():
        return String("")
    var description = schema.description_text(at)
    var block: String
    if is_printable_as_block_string(description):
        block = print_block_string(description)
    else:
        block = print_string(description)
    var prefix = String(indentation)
    if indentation != "" and not first_in_block:
        prefix = "\n" + String(indentation)
    return prefix + block.replace("\n", "\n" + String(indentation)) + "\n"


def _print_deprecated(is_deprecated: Bool, reason: String) -> String:
    """Print `@deprecated`, as `printDeprecated`."""
    if not is_deprecated:
        return String("")
    if reason != DEFAULT_DEPRECATION_REASON:
        return " @deprecated(reason: " + print_string(reason) + ")"
    return String(" @deprecated")


def _print_input_value(schema: Schema, index: Int) raises -> String:
    """Print an argument or input field, as `printInputValue`."""
    ref value = schema.input_values[index]
    var out = value.name + ": " + schema.type_name(value.type)
    var default = print_default(schema, index)
    if default:
        out += " = " + default.value()
    return out + _print_deprecated(
        value.is_deprecated, value.deprecation_reason
    )


def _print_args(
    schema: Schema, arguments: Range, indentation: StaticString = ""
) raises -> String:
    """Print arguments, one per line when any has a description."""
    if arguments.count == 0:
        return String("")
    # The arguments are not empty, so each loop runs at least once.
    var first = Int(arguments.start)
    var described = False
    var index = first
    while index < arguments.end():
        ref argument = schema.input_values[index]
        if schema.description_text(argument.description) != "":
            described = True
        index += 1
    if not described:
        var out = String("(")
        index = first
        while index < arguments.end():
            if index > first:
                out += ", "
            out += _print_input_value(schema, index)
            index += 1
        return out + ")"
    var inner: StaticString = "  "
    if indentation != "":
        inner = "    "
    var out = String("(\n")
    index = first
    while index < arguments.end():
        ref argument = schema.input_values[index]
        if index > first:
            out += "\n"
        out += _print_description(
            schema,
            argument.description,
            inner,
            index == first,
        )
        out += String(inner) + _print_input_value(schema, index)
        index += 1
    return out + "\n" + String(indentation) + ")"


def _print_block(items: List[String]) -> String:
    """Print items in braces, one per line, as `printBlock`."""
    if len(items) == 0:
        return String("")
    var out = String(" {\n")
    var index = 0
    while index < len(items):
        if index > 0:
            out += "\n"
        out += items[index]
        index += 1
    return out + "\n}"


def _print_fields(schema: Schema, type: Int) raises -> String:
    """Print an object's or interface's fields, as `printFields`."""
    var items = List[String]()
    ref named = schema.types[type]
    for index in range(Int(named.fields.start), named.fields.end()):
        ref field = schema.fields[index]
        items.append(
            _print_description(
                schema,
                field.description,
                "  ",
                index == Int(named.fields.start),
            )
            + "  "
            + field.name
            + _print_args(schema, field.arguments, "  ")
            + ": "
            + schema.type_name(field.type)
            + _print_deprecated(field.is_deprecated, field.deprecation_reason)
        )
    return _print_block(items)


def _print_interfaces(schema: Schema, type: Int) -> String:
    """Print ` implements A & B`, or nothing."""
    ref span = schema.types[type].interfaces
    if span.count == 0:
        return String("")
    var out = String(" implements ")
    var index = Int(span.start)
    while index < span.end():
        if index > Int(span.start):
            out += " & "
        out += schema.types[Int(schema.type_lists[index])].name
        index += 1
    return out^


def print_type(schema: Schema, type: Int) raises -> String:
    """Print one named type as SDL, as graphql-js `printType`.

    Args:
        schema: The schema.
        type: The type's index.

    Returns:
        The type's definition, with its description.

    Raises:
        Error: When a default value cannot be printed, as graphql-js
            raises for a custom scalar default that is an object.
    """
    ref named = schema.types[type]
    var out = _print_description(schema, named.description)
    var kind = named.kind
    if kind == TypeKind.SCALAR:
        out += "scalar " + named.name
        if named.has_specified_by_url:
            out += (
                " @specifiedBy(url: "
                + print_string(named.specified_by_url)
                + ")"
            )
    elif kind == TypeKind.OBJECT:
        out += "type " + named.name + _print_interfaces(schema, type)
        out += _print_fields(schema, type)
    elif kind == TypeKind.INTERFACE:
        out += "interface " + named.name + _print_interfaces(schema, type)
        out += _print_fields(schema, type)
    elif kind == TypeKind.UNION:
        out += "union " + named.name
        if named.members.count > 0:
            out += " = "
            var index = Int(named.members.start)
            while index < named.members.end():
                if index > Int(named.members.start):
                    out += " | "
                out += schema.types[Int(schema.type_lists[index])].name
                index += 1
    elif kind == TypeKind.ENUM:
        var items = List[String]()
        for index in range(
            Int(named.enum_values.start), named.enum_values.end()
        ):
            ref value = schema.enum_values[index]
            items.append(
                _print_description(
                    schema,
                    value.description,
                    "  ",
                    index == Int(named.enum_values.start),
                )
                + "  "
                + value.name
                + _print_deprecated(
                    value.is_deprecated, value.deprecation_reason
                )
            )
        out += "enum " + named.name + _print_block(items)
    else:
        var items = List[String]()
        for index in range(
            Int(named.input_fields.start), named.input_fields.end()
        ):
            ref field = schema.input_values[index]
            items.append(
                _print_description(
                    schema,
                    field.description,
                    "  ",
                    index == Int(named.input_fields.start),
                )
                + "  "
                + _print_input_value(schema, index)
            )
        out += "input " + named.name
        if named.is_one_of:
            out += " @oneOf"
        out += _print_block(items)
    return out^


def _print_directive(schema: Schema, directive: Int) raises -> String:
    """Print a directive definition, as `printDirective`."""
    ref definition = schema.directives[directive]
    var out = _print_description(schema, definition.description)
    out += "directive @" + definition.name
    out += _print_args(schema, definition.arguments)
    out += _print_deprecated(
        definition.is_deprecated, definition.deprecation_reason
    )
    if definition.is_repeatable:
        out += " repeatable"
    out += " on "
    # graphql-js keeps the locations in the order the definition lists them.
    ref document = schema.documents[Int(definition.definition.document)]
    var locations = document.children(
        Int(definition.definition.node), Role.LOCATION
    )
    # A definition has at least one location.
    var index = 0
    while index < len(locations):
        if index > 0:
            out += " | "
        out += String(document.text(locations[index]))
        index += 1
    return out^


def _is_specified_directive(name: String) -> Bool:
    """Return True for the name of a specified directive, as graphql-js
    `isSpecifiedDirective`, which compares names."""
    var names = materialize[SPECIFIED_DIRECTIVE_NAMES]()
    var index = 0
    while index < len(names):
        if name == names[index]:
            return True
        index += 1
    return False


def _print_schema_definition(schema: Schema) -> String:
    """Print `schema { ... }` unless the roots have the common names."""
    if not schema.description.exists() and _has_common_root_names(schema):
        return String("")
    var operations = List[String]()
    if schema.query_type != NO_TYPE:
        operations.append(
            "  query: " + schema.types[Int(schema.query_type)].name
        )
    if schema.mutation_type != NO_TYPE:
        operations.append(
            "  mutation: " + schema.types[Int(schema.mutation_type)].name
        )
    if schema.subscription_type != NO_TYPE:
        operations.append(
            "  subscription: "
            + schema.types[Int(schema.subscription_type)].name
        )
    var out = _print_description(schema, schema.description)
    out += "schema {\n"
    # A schema definition from SDL names at least one root type.
    var index = 0
    while index < len(operations):
        if index > 0:
            out += "\n"
        out += operations[index]
        index += 1
    return out + "\n}"


def _has_common_root_names(schema: Schema) -> Bool:
    """Return True when each root type has its common name."""
    if (
        schema.query_type != NO_TYPE
        and schema.types[Int(schema.query_type)].name != "Query"
    ):
        return False
    if (
        schema.mutation_type != NO_TYPE
        and schema.types[Int(schema.mutation_type)].name != "Mutation"
    ):
        return False
    if (
        schema.subscription_type != NO_TYPE
        and schema.types[Int(schema.subscription_type)].name != "Subscription"
    ):
        return False
    return True


def _print_filtered(schema: Schema, introspection: Bool) raises -> String:
    """Print the schema definition, then the directives and types that pass
    the filter, as `printFilteredSchema`."""
    var parts = List[String]()
    if not introspection:
        var definition = _print_schema_definition(schema)
        if definition != "":
            parts.append(definition^)
    # A schema always has directives and types: the specified ones.
    var directive = 0
    while directive < len(schema.directives):
        if (
            _is_specified_directive(schema.directives[directive].name)
            == introspection
        ):
            parts.append(_print_directive(schema, directive))
        directive += 1
    var position = 0
    while position < len(schema.type_map):
        var type = Int(schema.type_map[position])
        position += 1
        ref named = schema.types[type]
        var is_introspection = named.name.startswith("__") and named.is_builtin
        var keep: Bool
        if introspection:
            keep = is_introspection
        else:
            keep = not named.is_builtin
        if keep:
            parts.append(print_type(schema, type))
    var out = String("")
    var index = 0
    while index < len(parts):
        if index > 0:
            out += "\n\n"
        out += parts[index]
        index += 1
    return out^


def print_schema(schema: Schema) raises -> String:
    """Print a schema as SDL, as graphql-js `printSchema`.

    The specified scalars, the specified directives and the introspection
    types are left out.

    Args:
        schema: The schema.

    Returns:
        The SDL.

    Raises:
        Error: When a default value cannot be printed; see `print_type`.
    """
    return _print_filtered(schema, False)


def print_introspection_schema(schema: Schema) raises -> String:
    """Print the specified directives and the introspection types, as
    graphql-js `printIntrospectionSchema`.

    Args:
        schema: The schema.

    Returns:
        The SDL.

    Raises:
        Error: Never for the built-in definitions.
    """
    return _print_filtered(schema, True)

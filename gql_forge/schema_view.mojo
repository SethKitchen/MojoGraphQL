# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Walk a schema into JSON for the Forge explorer.

The explorer shows types, fields, arguments and descriptions. It does
not run operations against the customer graph. That graph stays on the
customer's machines.

Differences from upstream: none; there is no upstream.
"""

from gql_json.writer import JsonWriter
from gql_schema.build import build_schema
from gql_schema.definition import NO_TYPE, Schema, TypeKind, TypeRef
from gql_schema.introspection import is_introspection_type
from gql_schema.print import print_schema


def type_ref_text(schema: Schema, type: TypeRef) -> String:
    """Print a type reference, such as `[ID!]!`.

    Args:
        schema: The schema that holds the named type.
        type: The field or argument type.

    Returns:
        The GraphQL type text, or `Unknown` when the named type is
        missing.
    """
    var named = Int(type.named)
    if named < 0 or named >= len(schema.types):
        return String("Unknown")
    var text = schema.types[named].name.copy()
    var wrappers = List[Bool]()
    var current = type
    while current.is_wrapped():
        wrappers.append(current.is_list())
        current = current.of_type()
    var index = len(wrappers) - 1
    while index >= 0:
        if wrappers[index]:
            text = "[" + text + "]"
        else:
            text = text + "!"
        index -= 1
    return text^


def root_type_name(schema: Schema, type: Int32) -> String:
    """Return the name of a root type, or empty when it is missing.

    Args:
        schema: The schema.
        type: A type index, or `NO_TYPE`.

    Returns:
        The type name, or an empty string.
    """
    var index = Int(type)
    if index == NO_TYPE or index < 0 or index >= len(schema.types):
        return String("")
    return schema.types[index].name.copy()


def _write_input_values(
    mut writer: JsonWriter, schema: Schema, start: Int, count: Int
):
    """Write an array of input values.

    Args:
        writer: The JSON writer.
        schema: The schema.
        start: The first input value.
        count: How many input values.
    """
    writer.begin_array()
    var index = 0
    while index < count:
        var value = schema.input_values[start + index].copy()
        writer.begin_object()
        writer.key("name")
        writer.string(value.name)
        writer.key("type")
        writer.string(type_ref_text(schema, value.type))
        writer.key("description")
        writer.string(schema.description_text(value.description))
        writer.key("deprecated")
        writer.bool(value.is_deprecated)
        writer.end_object()
        index += 1
    writer.end_array()


def _write_fields(
    mut writer: JsonWriter, schema: Schema, start: Int, count: Int
):
    """Write an array of output fields.

    Args:
        writer: The JSON writer.
        schema: The schema.
        start: The first field.
        count: How many fields.
    """
    writer.begin_array()
    var index = 0
    while index < count:
        var field = schema.fields[start + index].copy()
        writer.begin_object()
        writer.key("name")
        writer.string(field.name)
        writer.key("type")
        writer.string(type_ref_text(schema, field.type))
        writer.key("description")
        writer.string(schema.description_text(field.description))
        writer.key("deprecated")
        writer.bool(field.is_deprecated)
        writer.key("args")
        _write_input_values(
            writer,
            schema,
            Int(field.arguments.start),
            Int(field.arguments.count),
        )
        writer.end_object()
        index += 1
    writer.end_array()


def _write_enum_values(
    mut writer: JsonWriter, schema: Schema, start: Int, count: Int
):
    """Write an array of enum values.

    Args:
        writer: The JSON writer.
        schema: The schema.
        start: The first enum value.
        count: How many values.
    """
    writer.begin_array()
    var index = 0
    while index < count:
        var value = schema.enum_values[start + index].copy()
        writer.begin_object()
        writer.key("name")
        writer.string(value.name)
        writer.key("description")
        writer.string(schema.description_text(value.description))
        writer.key("deprecated")
        writer.bool(value.is_deprecated)
        writer.end_object()
        index += 1
    writer.end_array()


def write_type_names(
    mut writer: JsonWriter, schema: Schema, start: Int, count: Int
):
    """Write an array of named types from `type_lists`.

    Args:
        writer: The JSON writer.
        schema: The schema.
        start: The first `type_lists` entry.
        count: How many entries.
    """
    writer.begin_array()
    var index = 0
    while index < count:
        var named = Int(schema.type_lists[start + index])
        if named >= 0 and named < len(schema.types):
            writer.string(schema.types[named].name)
        else:
            writer.string("Unknown")
        index += 1
    writer.end_array()


def schema_index_json(schema: Schema) raises -> String:
    """Write the explorer index of a schema.

    Args:
        schema: The schema.

    Returns:
        A JSON object with root types, SDL and every user type.

    Raises:
        Error: When the schema cannot be printed.
    """
    var writer = JsonWriter()
    writer.begin_object()
    writer.key("queryType")
    writer.string(root_type_name(schema, schema.query_type))
    writer.key("mutationType")
    writer.string(root_type_name(schema, schema.mutation_type))
    writer.key("subscriptionType")
    writer.string(root_type_name(schema, schema.subscription_type))
    writer.key("sdl")
    writer.string(print_schema(schema))
    writer.key("types")
    write_user_types(writer, schema)
    writer.end_object()
    return writer^.take_string()


def write_user_types(mut writer: JsonWriter, schema: Schema):
    """Write the user types of a schema as a JSON array.

    Args:
        writer: The JSON writer.
        schema: The schema. Invalid `type_map` entries are skipped.
    """
    writer.begin_array()
    for ref entry in schema.type_map:
        var index = Int(entry)
        if index < 0 or index >= len(schema.types):
            continue
        var typ = schema.types[index].copy()
        if typ.is_builtin or is_introspection_type(typ.name):
            continue
        writer.begin_object()
        writer.key("name")
        writer.string(typ.name)
        writer.key("kind")
        writer.string(typ.kind.text())
        writer.key("description")
        writer.string(schema.description_text(typ.description))
        writer.key("fields")
        if typ.kind.has_fields():
            _write_fields(
                writer, schema, Int(typ.fields.start), Int(typ.fields.count)
            )
        else:
            writer.begin_array()
            writer.end_array()
        writer.key("inputFields")
        if typ.kind == TypeKind.INPUT_OBJECT:
            _write_input_values(
                writer,
                schema,
                Int(typ.input_fields.start),
                Int(typ.input_fields.count),
            )
        else:
            writer.begin_array()
            writer.end_array()
        writer.key("enumValues")
        if typ.kind == TypeKind.ENUM:
            _write_enum_values(
                writer,
                schema,
                Int(typ.enum_values.start),
                Int(typ.enum_values.count),
            )
        else:
            writer.begin_array()
            writer.end_array()
        writer.key("interfaces")
        write_type_names(
            writer, schema, Int(typ.interfaces.start), Int(typ.interfaces.count)
        )
        writer.key("possibleTypes")
        write_type_names(
            writer, schema, Int(typ.members.start), Int(typ.members.count)
        )
        writer.end_object()
    writer.end_array()


def schema_index_from_sdl(sdl: StringSlice) raises -> String:
    """Build a schema from SDL and write its explorer index.

    Args:
        sdl: The SDL.

    Returns:
        The JSON of `schema_index_json`.

    Raises:
        Error: When the SDL is not a schema, or as `schema_index_json`
            raises.
    """
    return schema_index_json(build_schema(sdl))


def user_type_names(schema: Schema) -> List[String]:
    """Return the names of user types, without built-ins.

    Args:
        schema: The schema.

    Returns:
        The type names, in `type_map` order.
    """
    var names = List[String]()
    for ref entry in schema.type_map:
        var index = Int(entry)
        if index < 0 or index >= len(schema.types):
            continue
        var typ = schema.types[index].copy()
        if typ.is_builtin or is_introspection_type(typ.name):
            continue
        names.append(typ.name.copy())
    return names^

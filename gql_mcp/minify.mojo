# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The minified text of schema types, for the `introspect` and `search`
tools when `minify` is on.

Port of Apollo MCP Server 2.0.0 (04e4e6e)
`crates/apollo-mcp-server/src/introspection/minify.rs`. A type is one
line: a kind letter (`T` object, `I` input, `E` enum, `U` union, `F`
interface), the quoted description and the name, then the fields. The
built-in scalars are `s`, `i`, `f`, `b` and `d`, and `@deprecated` is
`@D`.

Differences from upstream: `normalize_description` collapses and trims
ASCII white space only. The upstream uses the Unicode white space of the
Rust `regex` `\\s` class and of `str::trim`.
"""

from gql_language.ast import Kind, Role
from gql_schema.definition import AstRef, Range, Schema, TypeKind, TypeRef
from gql_mcp.serialize import type_members, union_members


def _is_space(byte: UInt8) -> Bool:
    """Whether a byte is ASCII white space."""
    return byte == 32 or (byte >= 9 and byte <= 13)


def normalize_description(text: StringSlice) -> String:
    """Collapse each run of white space to one space, and trim the ends.

    Args:
        text: The description.

    Returns:
        The description on one line.
    """
    var out = List[UInt8](capacity=text.byte_length())
    var pending = False
    for byte in text.as_bytes():
        if _is_space(byte):
            pending = len(out) > 0
        else:
            if pending:
                out.append(32)
                pending = False
            out.append(byte)
    return String(unsafe_from_utf8=out^)


def shorten_scalar_name(name: StringSlice) -> String:
    """Return the short name of a built-in scalar.

    Args:
        name: A type name.

    Returns:
        `s`, `i`, `f`, `b` or `d` for `String`, `Int`, `Float`, `Boolean`
        and `ID`; else the name.
    """
    if name == "String":
        return "s"
    if name == "Int":
        return "i"
    if name == "Float":
        return "f"
    if name == "Boolean":
        return "b"
    if name == "ID":
        return "d"
    return String(name)


def _type_name(schema: Schema, type: TypeRef) -> String:
    """A type reference with the short scalar names, such as `[s!]!`."""
    var out = shorten_scalar_name(schema.types[Int(type.named)].name)
    var level = Int(type.depth) - 1
    while level >= 0:
        if (type.bits >> UInt32(level)) & 1 == 1:
            out = "[" + out + "]"
        else:
            out += "!"
        level -= 1
    return out^


def _directives(schema: Schema, directives: Range) -> String:
    """`@D` or `@D("reason")` for an applied `@deprecated`; nothing for the
    other directives."""
    var out = String()
    for index in range(Int(directives.start), directives.end()):
        var at = schema.applied[index]
        ref document = schema.documents[Int(at.document)]
        var node = Int(at.node)
        if String(document.name(node)) != "deprecated":
            continue
        # `reason` is the only argument of `@deprecated`.
        var argument = document.child(node, Role.ARGUMENT)
        var value = (
            document.child(argument, Role.VALUE) if argument >= 0 else -1
        )
        if value >= 0 and document.kind(value) == Kind.STRING:
            out += '@D("'
            out += normalize_description(document.string_value(value))
            out += '")'
        else:
            out += "@D"
    return out^


def _described(schema: Schema, at: AstRef) -> String:
    """The quoted, normalized description, or nothing."""
    if not at.exists():
        return String()
    return '"' + normalize_description(schema.description_text(at)) + '"'


def _input_value(schema: Schema, index: Int) -> String:
    """An argument or input field: description, name, type, directives."""
    ref value = schema.input_values[index]
    return (
        _described(schema, value.description)
        + value.name
        + ":"
        + _type_name(schema, value.type)
        + _directives(schema, value.directives)
    )


def _field(schema: Schema, index: Int) -> String:
    """A field: description, name, arguments, type, directives."""
    ref field = schema.fields[index]
    var out = _described(schema, field.description) + field.name
    var span = field.arguments
    if span.count > 0:
        out += "("
        var argument = Int(span.start)
        while argument < span.end():
            if argument > Int(span.start):
                out += ","
            out += _input_value(schema, argument)
            argument += 1
        out += ")"
    out += ":" + _type_name(schema, field.type)
    out += _directives(schema, field.directives)
    return out^


def _joined(names: List[String]) -> String:
    """Names with commas between them."""
    var out = String()
    for index in range(len(names)):
        if index > 0:
            out += ","
        out += names[index]
    return out^


def minify_type(schema: Schema, type: Int) -> String:
    """Return the minified text of a type, as upstream `MinifyExt::minify`.

    Args:
        schema: The schema.
        type: The type's index.

    Returns:
        The minified definition.
    """
    return minify_type_with(
        schema, type, type_members(schema, type), union_members(schema, type)
    )


def minify_type_with(
    schema: Schema, type: Int, members: List[Int], union_types: List[Int]
) -> String:
    """Return the minified text of a type with some of its members, as the
    minified type of a tree-shaken schema.

    Args:
        schema: The schema.
        type: The type's index.
        members: The fields, input fields or enum values to keep.
        union_types: The union members to keep.

    Returns:
        The minified definition.
    """
    ref named = schema.types[type]
    var kind = named.kind
    if kind == TypeKind.SCALAR:
        return shorten_scalar_name(named.name)
    var parts = List[String]()
    if kind == TypeKind.UNION:
        for member in union_types:
            parts.append(schema.types[member].name.copy())
    else:
        for member in members:
            if kind == TypeKind.ENUM:
                parts.append(schema.enum_values[member].name.copy())
            elif kind == TypeKind.INPUT_OBJECT:
                parts.append(_input_value(schema, member))
            else:
                parts.append(_field(schema, member))
    var name = _described(schema, named.description) + named.name
    if kind == TypeKind.OBJECT:
        var interfaces = List[String]()
        for interface in schema.interfaces_of(type):
            interfaces.append(schema.types[interface].name.copy())
        if len(interfaces) > 0:
            name += "<" + _joined(interfaces) + ">"
    return _letter(kind) + ":" + name + ":" + _joined(parts)


def _letter(kind: TypeKind) -> String:
    """The letter of a kind of type that is not a scalar."""
    if kind == TypeKind.OBJECT:
        return "T"
    if kind == TypeKind.INTERFACE:
        return "F"
    if kind == TypeKind.UNION:
        return "U"
    if kind == TypeKind.ENUM:
        return "E"
    return "I"

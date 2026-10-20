# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Value literals as JSON, and type references, as graphql-go-tools `ast`
has them.

- `value_to_json` is `Document.ValueToJSON`: a literal of the operation or
  of the schema as JSON text. A variable takes its raw value from the
  variables JSON.
- `type_ref_of` makes a `gql_schema` `TypeRef` from a type node of the
  operation, so the passes ask the same questions of both:
  `TypeIsNonNull`, `TypeIsList`, `ResolveListOrNameType`,
  `TypeNumberOfListWraps`.
- `add_type_node` is `astimport.Importer.ImportType`: it writes a schema
  type as type nodes of the operation.
"""

from gql_language.ast import Document, FLAG_BLOCK, Kind, NO_NODE, Role
from gql_schema.definition import Schema, TypeRef

from gql_normalization.variables_json import members, top_level_member

comptime _HEX = "0123456789abcdef"
"""The hexadecimal digits of a `\\u` escape, in lower case as Go writes
them."""


def append_json_string(mut out: String, value: StringSlice):
    """Append a value as a JSON string, as Go `encoding/json` writes it with
    `SetEscapeHTML(false)`.

    Args:
        out: The text to append to.
        value: The decoded string.
    """
    out += '"'
    var data = value.as_bytes()
    var start = 0
    var at = 0
    while at < len(data):
        var byte = data[at]
        var escape = ""
        if byte == UInt8(ord('"')):
            escape = '\\"'
        elif byte == UInt8(ord("\\")):
            escape = "\\\\"
        elif byte == UInt8(ord("\n")):
            escape = "\\n"
        elif byte == UInt8(ord("\r")):
            escape = "\\r"
        elif byte == UInt8(ord("\t")):
            escape = "\\t"
        elif byte == 8:
            escape = "\\b"
        elif byte == 12:
            escape = "\\f"
        elif byte < 0x20:
            escape = "\\u00"
            escape += _HEX[byte = Int(byte >> 4) : Int(byte >> 4) + 1]
            escape += _HEX[byte = Int(byte & 15) : Int(byte & 15) + 1]
        elif (
            byte == 0xE2
            and data[at + 1] == 0x80
            and (data[at + 2] == 0xA8 or data[at + 2] == 0xA9)
        ):
            escape = "\\u2028" if data[at + 2] == 0xA8 else "\\u2029"
        if escape.byte_length() == 0:
            at += 1
            continue
        out += value[byte=start:at]
        out += escape
        at += 3 if escape.startswith("\\u202") else 1
        start = at
    out += value[byte=start:]
    out += '"'


def value_to_json(document: Document, value: Int, variables: String) -> String:
    """Return a value literal as JSON: `ValueToJSON`.

    An enum value is a string. A string that is not a block string keeps
    its escapes as written. A variable is its raw value in the variables,
    or `null` when it has none. An object field whose value is a variable
    without a value is left out.

    Args:
        document: The document of the value.
        value: A value node.
        variables: The variables JSON.

    Returns:
        The JSON text.
    """
    var out = String()
    _write_json(out, document, value, variables)
    return out^


def _write_json(
    mut out: String, document: Document, value: Int, variables: String
):
    """Append a value literal as JSON."""
    var kind = document.kind(value)
    if kind == Kind.NULL:
        out += "null"
    elif kind == Kind.ENUM:
        out += '"'
        out += document.text(value)
        out += '"'
    elif kind == Kind.BOOLEAN:
        out += "true" if document.boolean_value(value) else "false"
    elif kind == Kind.STRING:
        if document.nodes[value].flags & FLAG_BLOCK != 0:
            append_json_string(out, document.string_value(value))
        else:
            out += document.text(value)
    elif kind == Kind.LIST:
        out += "["
        var item = document.first_child(value)
        while item != NO_NODE:
            if item != document.first_child(value):
                out += ","
            _write_json(out, document, item, variables)
            item = document.next_sibling(item)
        out += "]"
    elif kind == Kind.OBJECT:
        out += "{"
        var rendered = False
        var field = document.first_child(value)
        while field != NO_NODE:
            var inner = document.child(field, Role.VALUE)
            if (
                document.kind(inner) == Kind.VARIABLE
                and top_level_member(variables, document.name(inner)) < 0
            ):
                field = document.next_sibling(field)
                continue
            if rendered:
                out += ","
            rendered = True
            out += '"'
            out += document.name(field)
            out += '":'
            _write_json(out, document, inner, variables)
            field = document.next_sibling(field)
        out += "}"
    elif kind == Kind.VARIABLE:
        var index = top_level_member(variables, document.name(value))
        if index < 0:
            out += "null"
        else:
            out += members(variables)[index].value(variables)
    else:
        out += document.text(value)


def contains_variable(document: Document, value: Int) -> Bool:
    """Return True if a value is or holds a variable:
    `ValueContainsVariable`.

    Args:
        document: The document.
        value: A value node.

    Returns:
        Whether a variable is in the value.
    """
    var kind = document.kind(value)
    if kind == Kind.VARIABLE:
        return True
    if kind == Kind.LIST:
        var item = document.first_child(value)
        while item != NO_NODE:
            if contains_variable(document, item):
                return True
            item = document.next_sibling(item)
    elif kind == Kind.OBJECT:
        var field = document.first_child(value)
        while field != NO_NODE:
            if contains_variable(document, document.child(field, Role.VALUE)):
                return True
            field = document.next_sibling(field)
    return False


def type_ref_of(schema: Schema, document: Document, type: Int) -> TypeRef:
    """Return the `TypeRef` of a type node.

    Args:
        schema: The schema, for the named type.
        document: The document of the node.
        type: A `NamedType`, `ListType` or `NonNullType` node.

    Returns:
        The reference; its named type is -1 when the schema has no such
        type.
    """
    var depth = 0
    var bits: UInt32 = 0
    var current = type
    while document.kind(current) != Kind.NAMED_TYPE:
        if document.kind(current) == Kind.LIST_TYPE:
            bits |= UInt32(1) << UInt32(depth)
        depth += 1
        current = document.child(current, Role.TYPE)
    return TypeRef(
        Int32(schema.type_named(document.name(current))), UInt8(depth), bits
    )


def is_non_null(type: TypeRef) -> Bool:
    """Return True if the outermost wrapper is a non-null: `TypeIsNonNull`.

    Args:
        type: The type.

    Returns:
        Whether the type is non-null.
    """
    return type.depth > 0 and type.bits & 1 == 0


def unwrap(type: TypeRef) -> TypeRef:
    """Return the type inside the outermost wrapper: `OfType`.

    Args:
        type: A wrapped type.

    Returns:
        The type without its outermost wrapper.
    """
    return TypeRef(type.named, type.depth - 1, type.bits >> 1)


def list_or_name(type: TypeRef) -> TypeRef:
    """Return the type without its outer non-nulls: `ResolveListOrNameType`.

    Args:
        type: The type.

    Returns:
        A list or a named type.
    """
    var out = type
    while is_non_null(out):
        out = unwrap(out)
    return out


def is_list(type: TypeRef) -> Bool:
    """Return True if a type is a list, under its outer non-null:
    `TypeIsList`.

    Args:
        type: The type.

    Returns:
        Whether the type is a list.
    """
    return list_or_name(type).depth > 0


def list_wraps(type: TypeRef) -> Int:
    """Return how many lists wrap a type: `TypeNumberOfListWraps`.

    Args:
        type: The type.

    Returns:
        The count of list wrappers.
    """
    var count = 0
    var depth = 0
    while depth < Int(type.depth):
        if (type.bits >> UInt32(depth)) & 1 == 1:
            count += 1
        depth += 1
    return count


def add_type_node(mut document: Document, schema: Schema, type: TypeRef) -> Int:
    """Add the type nodes of a schema type: `ImportType`.

    Args:
        document: The operation document.
        schema: The schema.
        type: The type.

    Returns:
        The outermost type node, with the role `TYPE` and no parent.
    """
    var current = type
    var root = NO_NODE
    var parent = NO_NODE
    while current.depth > 0:
        var kind = (
            Kind.LIST_TYPE if current.bits & 1 == 1 else Kind.NON_NULL_TYPE
        )
        var node = document.add(kind, Role.TYPE)
        if parent == NO_NODE:
            root = node
        else:
            document.append_child(parent, node)
        parent = node
        current = unwrap(current)
    var named = document.add(Kind.NAMED_TYPE, Role.TYPE)
    _ = document.add_name(
        named, Role.NAME, schema.types[Int(current.named)].name
    )
    if parent == NO_NODE:
        return named
    document.append_child(parent, named)
    return root

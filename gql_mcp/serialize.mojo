# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""SDL text of schema types, as apollo-compiler writes it.

Apollo MCP Server puts schema types in tool descriptions and in the results
of `introspect` and `search`, with apollo-compiler 2.0.0-beta.1
`ExtendedType::serialize().to_string()`. That text is not the text of
graphql-js `printType`: a description that fits on one line is a
one-line block string, there is no empty line between described fields, an argument
list with a description or a directive takes one line per argument with a
trailing comma, and a list or object value in a multi-line context takes one
line per item. This module writes that text from a `gql_schema.Schema`.

Port of apollo-compiler 2.0.0-beta.1 (MIT) `src/ast/serialize.rs`: the
`State` writer, `top_level`, `comma_separated`,
`curly_brackets_space_separated`, `serialize_string_value`,
`serialize_block_string`, `can_be_block_string`, and the `serialize_impl`
of the type definitions, field definitions, input value definitions, enum
value definitions, directive definitions, the schema definition, directives
and values.

Differences from upstream: a type with extensions prints as one
definition, with the fields of its extensions. Apollo MCP Server prints
only the types of a tree-shaken schema, which has no extensions, so its
output does not change.
"""

from gql_language.ast import Document, Kind, Role
from gql_schema.definition import AstRef, Range, Schema, TypeKind


struct SdlWriter(Movable):
    """The apollo-compiler `State`: the text, the indent level, and whether
    line breaks are on."""

    var out: String
    """The text written so far."""
    var newlines: Bool
    """Whether line breaks and the two-space indent are on."""
    var level: Int
    """The indent level."""

    def __init__(out self):
        """Start an empty writer with line breaks on, at level 0."""
        self.out = String()
        self.newlines = True
        self.level = 0

    def write(mut self, text: StringSlice):
        """Append text.

        Args:
            text: The text.
        """
        self.out += text

    def _line(mut self, space: Bool):
        """Write a line break and the indent, or a space, or nothing."""
        if self.newlines:
            self.out += "\n"
            for _ in range(self.level):
                self.out += "  "
        elif space:
            self.out += " "

    def indent(mut self):
        """Go one level in, and start a line."""
        self.level += 1
        self._line(False)

    def indent_or_space(mut self):
        """Go one level in, and start a line or write a space."""
        self.level += 1
        self._line(True)

    def dedent(mut self):
        """Go one level out, and start a line."""
        self.level -= 1
        self._line(False)

    def dedent_or_space(mut self):
        """Go one level out, and start a line or write a space."""
        self.level -= 1
        self._line(True)

    def new_line_or_space(mut self):
        """Start a line, or write a space."""
        self._line(True)

    def take(deinit self) -> String:
        """Return the text, and end the writer.

        Returns:
            The text.
        """
        return self.out^


def _is_white(byte: UInt8) -> Bool:
    """Whether a byte is GraphQL white space: a space or a tab."""
    return byte == 32 or byte == 9


def _all_white(text: StringSlice) -> Bool:
    """Whether a line has only spaces and tabs."""
    for byte in text.as_bytes():
        if not _is_white(byte):
            return False
    return True


def can_be_block_string(value: String) -> Bool:
    """Return whether a block string can hold a value exactly.

    Args:
        value: The value.

    Returns:
        False when the value has a carriage return, starts or ends with a
        line of only white space, or has a common indent.
    """
    if "\r" in value:
        return False
    var lines = value.split("\n")
    if _all_white(lines[0]):
        return False
    if len(lines) > 1 and _all_white(lines[len(lines) - 1]):
        return False
    var index = 0
    while index < len(lines):
        ref line = lines[index]
        if line.byte_length() > 0 and not _is_white(line.as_bytes()[0]):
            return True
        index += 1
    return False


def _hex_digit(value: UInt8) -> String:
    """The uppercase hexadecimal digit of a value below 16."""
    if value < 10:
        return chr(Int(value) + 48)
    return chr(Int(value) + 55)


def write_string_value(
    mut writer: SdlWriter, is_description: Bool, value: String
):
    """Write a string value, as apollo-compiler `serialize_string_value`.

    A description, or a value with a line break, is a block string when
    line breaks are on and `can_be_block_string` allows it. Else the value
    is a quoted string with `\\b`, `\\n`, `\\f`, `\\r`, `\\"`, `\\\\` and
    `\\uXXXX` escapes.

    Args:
        writer: The writer.
        is_description: Whether the value is a description.
        value: The decoded value.
    """
    var has_newline = "\n" in value
    if (
        writer.newlines
        and (is_description or has_newline)
        and can_be_block_string(value)
    ):
        _write_block_string(writer, has_newline, value)
        return
    var out = List[UInt8](capacity=value.byte_length() + 2)
    out.append(34)
    for byte in value.as_bytes():
        if byte == 8:
            out.extend("\\b".as_bytes())
        elif byte == 10:
            out.extend("\\n".as_bytes())
        elif byte == 12:
            out.extend("\\f".as_bytes())
        elif byte == 13:
            out.extend("\\r".as_bytes())
        elif byte == 34:
            out.extend('\\"'.as_bytes())
        elif byte == 92:
            out.extend("\\\\".as_bytes())
        elif byte < 32 and byte != 9:
            out.extend("\\u00".as_bytes())
            out.extend(_hex_digit(byte >> 4).as_bytes())
            out.extend(_hex_digit(byte & 15).as_bytes())
        else:
            out.append(byte)
    out.append(34)
    writer.write(String(unsafe_from_utf8=out^))


def _write_block_line(mut writer: SdlWriter, line: StringSlice):
    """Write one line of a block string, with each triple quote escaped."""
    writer.write(String(line).replace('"""', '\\"""'))


def _write_block_string(
    mut writer: SdlWriter, has_newline: Bool, value: String
):
    """Write a block string, as apollo-compiler `serialize_block_string`."""
    var multi_line = (
        has_newline
        or value.byte_length() > 70
        or value.endswith('"')
        or value.endswith("\\")
    )
    writer.write('"""')
    if not multi_line:
        _write_block_line(writer, value)
    else:
        var lines = value.split("\n")
        var index = 0
        while index < len(lines):
            ref line = lines[index]
            if line.byte_length() == 0:
                writer.write("\n")
            else:
                writer._line(False)
                _write_block_line(writer, line)
            index += 1
        writer._line(False)
    writer.write('"""')


def _write_value(mut writer: SdlWriter, document: Document, node: Int):
    """Write a constant value literal, as apollo-compiler `Value`."""
    var kind = document.kind(node)
    if kind == Kind.STRING:
        write_string_value(writer, False, document.string_value(node))
    elif kind == Kind.LIST or kind == Kind.OBJECT:
        _write_items(writer, document, node, kind == Kind.OBJECT)
    elif kind == Kind.BOOLEAN:
        writer.write("true" if document.boolean_value(node) else "false")
    elif kind == Kind.NULL:
        writer.write("null")
    else:
        writer.write(document.text(node))


def _write_item(
    mut writer: SdlWriter, document: Document, item: Int, is_object: Bool
):
    """Write a list item, or an object field and its value."""
    if is_object:
        writer.write(document.name(item))
        writer.write(": ")
        _write_value(writer, document, document.child(item, Role.VALUE))
    else:
        _write_value(writer, document, item)


def _write_items(
    mut writer: SdlWriter, document: Document, node: Int, is_object: Bool
):
    """Write a list or object value, as apollo-compiler `comma_separated`."""
    var items = document.children(
        node, Role.FIELD if is_object else Role.LIST_ITEM
    )
    writer.write("{" if is_object else "[")
    if len(items) > 0:
        writer.indent()
        _write_item(writer, document, items[0], is_object)
        var index = 1
        while index < len(items):
            writer.write(",")
            writer.new_line_or_space()
            _write_item(writer, document, items[index], is_object)
            index += 1
        if writer.newlines:
            writer.write(",")
        writer.dedent()
    writer.write("}" if is_object else "]")


def _write_directive(mut writer: SdlWriter, document: Document, node: Int):
    """Write an applied directive and its arguments, on one line."""
    writer.write("@")
    writer.write(document.name(node))
    var arguments = document.children(node, Role.ARGUMENT)
    if len(arguments) == 0:
        return
    var newlines = writer.newlines
    writer.newlines = False
    writer.write("(")
    var index = 0
    while index < len(arguments):
        if index > 0:
            writer.write(", ")
        writer.write(document.name(arguments[index]))
        writer.write(": ")
        _write_value(
            writer, document, document.child(arguments[index], Role.VALUE)
        )
        index += 1
    writer.write(")")
    writer.newlines = newlines


def _write_directives(mut writer: SdlWriter, schema: Schema, directives: Range):
    """Write the applied directives of a definition, each after a space."""
    for index in range(Int(directives.start), directives.end()):
        var at = schema.applied[index]
        writer.write(" ")
        _write_directive(
            writer, schema.documents[Int(at.document)], Int(at.node)
        )


def _write_description(mut writer: SdlWriter, schema: Schema, at: AstRef):
    """Write a description and the line break after it, when there is one."""
    if at.exists():
        write_string_value(writer, True, schema.description_text(at))
        writer.new_line_or_space()


def _write_input_value(mut writer: SdlWriter, schema: Schema, index: Int):
    """Write an argument or input field definition."""
    ref value = schema.input_values[index]
    _write_description(writer, schema, value.description)
    writer.write(value.name)
    writer.write(": ")
    writer.write(schema.type_name(value.type))
    if value.default_value.exists():
        writer.write(" = ")
        _write_value(
            writer,
            schema.documents[Int(value.default_value.document)],
            Int(value.default_value.node),
        )
    _write_directives(writer, schema, value.directives)


def _write_arguments_definition(
    mut writer: SdlWriter, schema: Schema, arguments: Range
):
    """Write `(...)` argument definitions, one per line when one of them has
    a description or a directive."""
    if arguments.count == 0:
        return
    var multi_line = False
    var index = Int(arguments.start)
    while index < arguments.end():
        ref argument = schema.input_values[index]
        if argument.description.exists() or argument.directives.count > 0:
            multi_line = True
        index += 1
    var newlines = writer.newlines
    writer.newlines = multi_line
    writer.write("(")
    writer.indent()
    index = Int(arguments.start)
    while index < arguments.end():
        if index > Int(arguments.start):
            writer.write(",")
            writer.new_line_or_space()
        _write_input_value(writer, schema, index)
        index += 1
    if writer.newlines:
        writer.write(",")
    writer.dedent()
    writer.write(")")
    writer.newlines = newlines


def _write_field(mut writer: SdlWriter, schema: Schema, index: Int):
    """Write a field definition."""
    ref field = schema.fields[index]
    _write_description(writer, schema, field.description)
    writer.write(field.name)
    _write_arguments_definition(writer, schema, field.arguments)
    writer.write(": ")
    writer.write(schema.type_name(field.type))
    _write_directives(writer, schema, field.directives)


def _write_enum_value(mut writer: SdlWriter, schema: Schema, index: Int):
    """Write an enum value definition."""
    ref value = schema.enum_values[index]
    _write_description(writer, schema, value.description)
    writer.write(value.name)
    _write_directives(writer, schema, value.directives)


def _write_member(
    mut writer: SdlWriter, schema: Schema, kind: TypeKind, index: Int
):
    """Write a field, an input field or an enum value of a type."""
    if kind == TypeKind.ENUM:
        _write_enum_value(writer, schema, index)
    elif kind == TypeKind.INPUT_OBJECT:
        _write_input_value(writer, schema, index)
    else:
        _write_field(writer, schema, index)


def _write_block(
    mut writer: SdlWriter, schema: Schema, kind: TypeKind, members: List[Int]
):
    """Write ` { ... }`, as apollo-compiler
    `curly_brackets_space_separated`, when there are members."""
    if len(members) == 0:
        return
    writer.write(" {")
    writer.indent_or_space()
    _write_member(writer, schema, kind, members[0])
    var index = 1
    while index < len(members):
        writer.new_line_or_space()
        _write_member(writer, schema, kind, members[index])
        index += 1
    writer.dedent_or_space()
    writer.write("}")


def _range_list(span: Range) -> List[Int]:
    """The indices of a range, in order."""
    var out = List[Int](capacity=Int(span.count))
    for index in range(Int(span.start), span.end()):
        out.append(index)
    return out^


def type_members(schema: Schema, type: Int) -> List[Int]:
    """Return every field, input field or enum value of a type.

    Args:
        schema: The schema.
        type: The type's index.

    Returns:
        Indices into `schema.fields` for an object or interface, into
        `schema.input_values` for an input object, into
        `schema.enum_values` for an enum; empty for a scalar or union.
    """
    ref named = schema.types[type]
    if named.kind == TypeKind.ENUM:
        return _range_list(named.enum_values)
    if named.kind == TypeKind.INPUT_OBJECT:
        return _range_list(named.input_fields)
    if named.kind.has_fields():
        return _range_list(named.fields)
    return List[Int]()


def union_members(schema: Schema, type: Int) -> List[Int]:
    """Return the member types of a union, in order.

    Args:
        schema: The schema.
        type: The union's index.

    Returns:
        The members' type indices; empty for another kind.
    """
    var out = List[Int]()
    ref span = schema.types[type].members
    for index in range(Int(span.start), span.end()):
        out.append(Int(schema.type_lists[index]))
    return out^


def _write_names(
    mut writer: SdlWriter,
    schema: Schema,
    var types: List[Int],
    lead: StaticString,
    separator: StaticString,
):
    """Write a lead and type names with a separator, when there are some."""
    var index = 0
    while index < len(types):
        writer.write(lead if index == 0 else separator)
        writer.write(schema.types[types[index]].name)
        index += 1


def write_type(
    mut writer: SdlWriter,
    schema: Schema,
    type: Int,
    members: List[Int],
    union_types: List[Int],
):
    """Write a type definition, as apollo-compiler writes the definition of
    an `ExtendedType`, with the given members.

    Args:
        writer: The writer.
        schema: The schema.
        type: The type's index.
        members: The fields, input fields or enum values to write; see
            `type_members`.
        union_types: The member types of a union to write.
    """
    ref named = schema.types[type]
    _write_description(writer, schema, named.description)
    writer.write(_keyword(named.kind))
    writer.write(" ")
    writer.write(named.name)
    if named.kind.has_fields():
        _write_names(
            writer, schema, schema.interfaces_of(type), " implements ", " & "
        )
    _write_directives(writer, schema, named.directives)
    _write_names(writer, schema, union_types.copy(), " = ", " | ")
    _write_block(writer, schema, named.kind, members)


def serialize_type(schema: Schema, type: Int) -> String:
    """Return the SDL text of a type, as apollo-compiler
    `ExtendedType::serialize().to_string()`.

    Args:
        schema: The schema.
        type: The type's index.

    Returns:
        The definition and a line break.
    """
    return serialize_type_with(
        schema, type, type_members(schema, type), union_members(schema, type)
    )


def serialize_type_with(
    schema: Schema, type: Int, members: List[Int], union_types: List[Int]
) -> String:
    """Return the SDL text of a type with some of its members, as the
    serialization of the type in a tree-shaken schema.

    Args:
        schema: The schema.
        type: The type's index.
        members: The fields, input fields or enum values to keep.
        union_types: The union members to keep.

    Returns:
        The definition and a line break.
    """
    var writer = SdlWriter()
    write_type(writer, schema, type, members, union_types)
    writer.write("\n")
    return writer^.take()


def _keyword(kind: TypeKind) -> StaticString:
    """The SDL keyword of a kind of type."""
    if kind == TypeKind.SCALAR:
        return "scalar"
    if kind == TypeKind.OBJECT:
        return "type"
    if kind == TypeKind.INTERFACE:
        return "interface"
    if kind == TypeKind.UNION:
        return "union"
    if kind == TypeKind.ENUM:
        return "enum"
    return "input"


def write_directive_definition(
    mut writer: SdlWriter, schema: Schema, directive: Int
):
    """Write a directive definition, as apollo-compiler
    `DirectiveDefinition`.

    Args:
        writer: The writer.
        schema: The schema.
        directive: The directive's index in `schema.directives`.
    """
    ref definition = schema.directives[directive]
    _write_description(writer, schema, definition.description)
    writer.write("directive @")
    writer.write(definition.name)
    _write_arguments_definition(writer, schema, definition.arguments)
    if definition.is_repeatable:
        writer.write(" repeatable")
    ref at = definition.definition
    ref document = schema.documents[Int(at.document)]
    var locations = document.children(Int(at.node), Role.LOCATION)
    var index = 0
    while index < len(locations):
        writer.write(" on " if index == 0 else " | ")
        writer.write(document.text(locations[index]))
        index += 1


def write_schema_definition(
    mut writer: SdlWriter,
    schema: Schema,
    operations: List[StaticString],
    types: List[Int],
):
    """Write a schema definition, as apollo-compiler `SchemaDefinition`,
    with the schema's description and directives.

    Args:
        writer: The writer.
        schema: The schema.
        operations: The operation keywords, such as `query`, in order; at
            least one.
        types: The root type of each operation.
    """
    _write_description(writer, schema, schema.description)
    writer.write("schema")
    _write_directives(writer, schema, schema.schema_directives)
    writer.write(" {")
    writer.indent_or_space()
    var index = 0
    while index < len(operations):
        if index > 0:
            writer.new_line_or_space()
        writer.write(operations[index])
        writer.write(": ")
        writer.write(schema.types[types[index]].name)
        index += 1
    writer.dedent_or_space()
    writer.write("}")

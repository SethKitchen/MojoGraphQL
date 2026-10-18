# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Print an operation or a fragment as Apollo Kotlin prints it.

Port of Apollo Kotlin `apollo-ast` `SDLWriter.kt` and the `writeInternal`
methods of the executable nodes in `gql.kt`, which `GQLNode.toUtf8()`
calls. The operation id hashes this text after `minify`, so the text must
be the upstream text byte for byte. It is not the graphql-js `print`:

- Each selection is on its own line, indented by two spaces, and a field,
  a fragment spread and a selection set end with a line feed.
- An argument list is never wrapped, and a list value separates its items
  with `,` and no space.
- An object value puts each field on its own line.
- A variable definition with a default value ends with a space, and its
  directives are not printed.
- A string is always printed with single quotes, with the escapes of
  `encode_single_quoted`. A block string is printed the same way.

**Differences from upstream.** None for the executable definitions. The
type system definitions are not printed: the generator does not need them.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role

from gql_codegen.strings import encode_single_quoted


struct _Writer(Movable):
    """Apollo `SDLWriter`: text, with an indent at each line start."""

    var out: String
    """The text so far."""
    var indent: Int
    """How many indents start the next line."""
    var bol: Bool
    """Whether the next character starts a line."""

    def __init__(out self):
        """Start with no text, at the start of a line."""
        self.out = String("")
        self.indent = 0
        self.bol = True

    def write(mut self, text: StringSlice):
        """Write text; indent each line that it starts, as upstream
        `SDLWriter.write`.

        Args:
            text: The text.
        """
        var bytes = text.as_bytes()
        var start = 0
        for index in range(len(bytes)):
            if bytes[index] == UInt8(ord("\n")):
                self.bol = True
            elif self.bol:
                self.bol = False
                self.out += StringSlice(
                    unsafe_from_utf8=Span(bytes)[start:index]
                )
                start = index
                for _ in range(self.indent):
                    self.out += "  "
        self.out += StringSlice(unsafe_from_utf8=Span(bytes)[start:])

    def take(deinit self) -> String:
        """Return the text.

        Returns:
            Everything written.
        """
        return self.out^


def _name(document: Document, node: Int) -> String:
    """Return the `NAME` child of a node."""
    return String(document.name(node))


def _type(mut writer: _Writer, document: Document, node: Int):
    """Write a type reference."""
    var kind = document.kind(node)
    if kind == Kind.NAMED_TYPE:
        writer.write(_name(document, node))
    elif kind == Kind.LIST_TYPE:
        writer.write("[")
        _type(writer, document, document.child(node, Role.TYPE))
        writer.write("]")
    else:
        _type(writer, document, document.child(node, Role.TYPE))
        writer.write("!")


def _value(mut writer: _Writer, document: Document, node: Int):
    """Write a value, as the upstream `GQLValue` nodes do."""
    var kind = document.kind(node)
    if kind == Kind.VARIABLE:
        writer.write("$")
        writer.write(_name(document, node))
    elif kind == Kind.INT or kind == Kind.FLOAT or kind == Kind.ENUM:
        writer.write(String(document.text(node)))
    elif kind == Kind.STRING:
        writer.write('"')
        writer.write(encode_single_quoted(document.string_value(node)))
        writer.write('"')
    elif kind == Kind.BOOLEAN:
        if document.boolean_value(node):
            writer.write("true")
        else:
            writer.write("false")
    elif kind == Kind.NULL:
        writer.write("null")
    elif kind == Kind.LIST:
        writer.write("[")
        var items = document.children(node, Role.LIST_ITEM)
        for index in range(len(items)):
            if index > 0:
                writer.write(",")
            _value(writer, document, items[index])
        writer.write("]")
    else:
        writer.write("{\n")
        writer.indent += 1
        var fields = document.children(node, Role.FIELD)
        for index in range(len(fields)):
            if index > 0:
                writer.write("\n")
            writer.write(_name(document, fields[index]))
            writer.write(": ")
            _value(writer, document, document.child(fields[index], Role.VALUE))
        writer.indent -= 1
        writer.write("\n}\n")


def _arguments(mut writer: _Writer, document: Document, node: Int):
    """Write the arguments of a node, if it has any."""
    var arguments = document.children(node, Role.ARGUMENT)
    for index in range(len(arguments)):
        writer.write("(" if index == 0 else ", ")
        writer.write(_name(document, arguments[index]))
        writer.write(": ")
        _value(writer, document, document.child(arguments[index], Role.VALUE))
    if len(arguments) > 0:
        writer.write(")")


def _directives(mut writer: _Writer, document: Document, node: Int):
    """Write ` @a @b(x: 1)` for the directives of a node, if it has any."""
    for directive in document.children(node, Role.DIRECTIVE):
        writer.write(" @")
        writer.write(_name(document, directive))
        _arguments(writer, document, directive)


def _selections(mut writer: _Writer, document: Document, node: Int):
    """Write a selection set: `{`, one selection per line, `}`."""
    writer.write("{\n")
    writer.indent += 1
    var current = document.first_child(node)
    while current != NO_NODE:
        _selection(writer, document, current)
        current = document.next_sibling(current)
    writer.indent -= 1
    writer.write("}\n")


def _selection(mut writer: _Writer, document: Document, node: Int):
    """Write a field, a fragment spread or an inline fragment."""
    var kind = document.kind(node)
    if kind == Kind.FIELD:
        var alias = document.child(node, Role.ALIAS)
        if alias != NO_NODE:
            writer.write(String(document.text(alias)))
            writer.write(": ")
        writer.write(_name(document, node))
        _arguments(writer, document, node)
        _directives(writer, document, node)
        var selection_set = document.child(node, Role.SELECTION_SET)
        if selection_set != NO_NODE:
            writer.write(" ")
            _selections(writer, document, selection_set)
        else:
            writer.write("\n")
    elif kind == Kind.FRAGMENT_SPREAD:
        writer.write("...")
        writer.write(_name(document, node))
        _directives(writer, document, node)
        writer.write("\n")
    else:
        writer.write("...")
        var condition = document.child(node, Role.TYPE_CONDITION)
        if condition != NO_NODE:
            writer.write(" on ")
            writer.write(_name(document, condition))
        _directives(writer, document, node)
        writer.write(" ")
        _selections(writer, document, document.child(node, Role.SELECTION_SET))


def _variable_definitions(mut writer: _Writer, document: Document, node: Int):
    """Write `($a: T, $b: U = 1 )` for the variables of a definition."""
    var variables = document.children(node, Role.VARIABLE_DEFINITION)
    for index in range(len(variables)):
        writer.write("(" if index == 0 else ", ")
        var variable = variables[index]
        writer.write("$")
        writer.write(_name(document, document.child(variable, Role.VARIABLE)))
        writer.write(": ")
        _type(writer, document, document.child(variable, Role.TYPE))
        var default = document.child(variable, Role.DEFAULT_VALUE)
        if default != NO_NODE:
            writer.write(" = ")
            _value(writer, document, default)
            writer.write(" ")
    if len(variables) > 0:
        writer.write(")")


def print_executable(document: Document, node: Int) -> String:
    """Print an operation or a fragment definition, as Apollo
    `GQLNode.toUtf8()`.

    Args:
        document: The document.
        node: An `OperationDefinition` or a `FragmentDefinition` node.

    Returns:
        The text, which ends with a line feed.
    """
    var writer = _Writer()
    if document.kind(node) == Kind.OPERATION_DEFINITION:
        writer.write(document.operation(node).text())
        var name = document.child(node, Role.NAME)
        if name != NO_NODE:
            writer.write(" ")
            writer.write(String(document.text(name)))
            _variable_definitions(writer, document, node)
    else:
        writer.write("fragment ")
        writer.write(_name(document, node))
        _variable_definitions(writer, document, node)
        writer.write(" on ")
        writer.write(_name(document, document.child(node, Role.TYPE_CONDITION)))
    _directives(writer, document, node)
    writer.write(" ")
    _selections(writer, document, document.child(node, Role.SELECTION_SET))
    return writer^.take()

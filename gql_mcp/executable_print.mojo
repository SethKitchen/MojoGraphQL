# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Print an executable document on one line, as apollo-compiler does.

Port of the executable part of apollo-compiler 2.0.0-beta.1
`src/ast/serialize.rs` with `no_indent()`: operations, fragments,
variables, selections, directives, arguments and values. Apollo MCP Server
sends this text to the GraphQL endpoint when it removed descriptions or
`@private` directives from an operation, and it puts it in the error of an
operation without a name.

The definitions are separated by one space. A selection set is
`{ a b }`, an argument list is `(a: 1, b: 2)`, and a string is always a
quoted string with the escapes of apollo-compiler: `\\b`, `\\n`, `\\f`,
`\\r`, `\\"`, `\\\\` and `\\uXXXX` with capital digits for the other control
characters. A tab stays as it is.

Differences from upstream: a type system definition in the document is
written as its source text, because the MCP server does not print SDL on
one line anywhere else. Apollo-compiler prints it again.
"""

from gql_language.ast import Document, Kind, NO_NODE, OperationType, Role


comptime _HEX = "0123456789ABCDEF"


struct PrintOptions(ImplicitlyCopyable):
    """What the printer leaves out."""

    var strip_descriptions: Bool
    """Leave out the descriptions of operations, variables and fragments."""
    var strip_private: Bool
    """Leave out each `@private` directive of a field."""

    def __init__(out self, strip_descriptions: Bool, strip_private: Bool):
        """Make the options.

        Args:
            strip_descriptions: Whether to leave out executable descriptions.
            strip_private: Whether to leave out `@private` on fields.
        """
        self.strip_descriptions = strip_descriptions
        self.strip_private = strip_private


def print_document(document: Document, options: PrintOptions) -> String:
    """Print every definition of a document on one line.

    Args:
        document: The document.
        options: What to leave out.

    Returns:
        The text, as `document.serialize().no_indent().to_string()`.
    """
    var out = String()
    var definitions = document.definitions()
    var index = 0
    while index < len(definitions):
        if index > 0:
            out += " "
        _definition(out, document, definitions[index], options, index == 0)
        index += 1
    return out^


def print_definition(document: Document, node: Int) -> String:
    """Print one operation or fragment on one line.

    Args:
        document: The document.
        node: An `OperationDefinition` or `FragmentDefinition`.

    Returns:
        The text, as `node.serialize().no_indent().to_string()`.
    """
    var out = String()
    _definition(out, document, node, PrintOptions(False, False), True)
    return out^


def _definition(
    mut out: String,
    document: Document,
    node: Int,
    options: PrintOptions,
    first: Bool,
):
    """Print one definition; `first` allows the query shorthand."""
    var kind = document.kind(node)
    if kind == Kind.OPERATION_DEFINITION:
        _operation(out, document, node, options, first)
    elif kind == Kind.FRAGMENT_DEFINITION:
        _description(out, document, node, options)
        out += "fragment "
        out += document.name(node)
        out += " on "
        out += document.named_type(document.child(node, Role.TYPE_CONDITION))
        _directives(out, document, node, options, False)
        out += " "
        _selection_set(
            out, document, document.child(node, Role.SELECTION_SET), options
        )
    else:
        out += document.source.slice(document.start(node), document.end(node))


def _description(
    mut out: String, document: Document, node: Int, options: PrintOptions
):
    """Print the description of a definition and a space, if any."""
    if options.strip_descriptions or not document.has_description(node):
        return
    _string(out, document.description(node))
    out += " "


def _operation(
    mut out: String,
    document: Document,
    node: Int,
    options: PrintOptions,
    first: Bool,
):
    """Print an operation definition."""
    var described = (
        document.has_description(node) and not options.strip_descriptions
    )
    var name = document.child(node, Role.NAME)
    var variables = document.children(node, Role.VARIABLE_DEFINITION)
    var shorthand = (
        first
        and not described
        and document.operation(node) == OperationType.QUERY
        and name == NO_NODE
        and len(variables) == 0
        and document.child(node, Role.DIRECTIVE) == NO_NODE
    )
    if not shorthand:
        _description(out, document, node, options)
        out += document.operation(node).text()
        if name != NO_NODE:
            out += " "
            out += document.text(name)
        if len(variables) > 0:
            out += "("
            var index = 0
            while index < len(variables):
                if index > 0:
                    out += ", "
                _variable(out, document, variables[index], options)
                index += 1
            out += ")"
        _directives(out, document, node, options, False)
        out += " "
    _selection_set(
        out, document, document.child(node, Role.SELECTION_SET), options
    )


def _variable(
    mut out: String, document: Document, node: Int, options: PrintOptions
):
    """Print a variable definition."""
    _description(out, document, node, options)
    out += "$"
    out += document.name(document.child(node, Role.VARIABLE))
    out += ": "
    _type(out, document, document.child(node, Role.TYPE))
    var default = document.child(node, Role.DEFAULT_VALUE)
    if default != NO_NODE:
        out += " = "
        _value(out, document, default)
    _directives(out, document, node, options, False)


def _type(mut out: String, document: Document, node: Int):
    """Print a type reference, as apollo-compiler `Type` `Display`."""
    var closers = String()
    var current = node
    while document.kind(current) != Kind.NAMED_TYPE:
        if document.kind(current) == Kind.LIST_TYPE:
            out += "["
            closers = "]" + closers
        else:
            closers = "!" + closers
        current = document.child(current, Role.TYPE)
    out += document.name(current)
    out += closers


def _directives(
    mut out: String,
    document: Document,
    node: Int,
    options: PrintOptions,
    on_field: Bool,
):
    """Print the directives of a node, each after a space."""
    var child = document.first_child(node)
    while child != NO_NODE:
        if document.role(child) == Role.DIRECTIVE:
            var name = document.name(child)
            if not (on_field and options.strip_private and name == "private"):
                out += " @"
                out += name
                _arguments(out, document, child)
        child = document.next_sibling(child)


def _arguments(mut out: String, document: Document, node: Int):
    """Print the arguments of a field or a directive, if any."""
    var arguments = document.children(node, Role.ARGUMENT)
    if len(arguments) == 0:
        return
    out += "("
    var index = 0
    while index < len(arguments):
        if index > 0:
            out += ", "
        out += document.name(arguments[index])
        out += ": "
        _value(out, document, document.child(arguments[index], Role.VALUE))
        index += 1
    out += ")"


def _selection_set(
    mut out: String, document: Document, node: Int, options: PrintOptions
):
    """Print a selection set, as `{ a b }`."""
    out += "{"
    var child = document.first_child(node)
    while child != NO_NODE:
        out += " "
        _selection(out, document, child, options)
        child = document.next_sibling(child)
    out += " }"


def _selection(
    mut out: String, document: Document, node: Int, options: PrintOptions
):
    """Print a field, a fragment spread or an inline fragment."""
    var kind = document.kind(node)
    if kind == Kind.FIELD:
        var alias = document.child(node, Role.ALIAS)
        if alias != NO_NODE:
            out += document.text(alias)
            out += ": "
        out += document.name(node)
        _arguments(out, document, node)
        _directives(out, document, node, options, True)
        var selections = document.child(node, Role.SELECTION_SET)
        if selections != NO_NODE:
            out += " "
            _selection_set(out, document, selections, options)
    elif kind == Kind.FRAGMENT_SPREAD:
        out += "..."
        out += document.name(node)
        _directives(out, document, node, options, False)
    else:
        var condition = document.child(node, Role.TYPE_CONDITION)
        if condition != NO_NODE:
            out += "... on "
            out += document.name(condition)
        else:
            out += "..."
        _directives(out, document, node, options, False)
        out += " "
        _selection_set(
            out, document, document.child(node, Role.SELECTION_SET), options
        )


def _value(mut out: String, document: Document, node: Int):
    """Print a value literal."""
    var kind = document.kind(node)
    if kind == Kind.VARIABLE:
        out += "$"
        out += document.name(node)
    elif kind == Kind.STRING:
        _string(out, document.string_value(node))
    elif kind == Kind.BOOLEAN:
        out += "true" if document.boolean_value(node) else "false"
    elif kind == Kind.NULL:
        out += "null"
    elif kind == Kind.LIST or kind == Kind.OBJECT:
        _composite(out, document, node, kind == Kind.OBJECT)
    else:
        out += document.text(node)


def _composite(mut out: String, document: Document, node: Int, object: Bool):
    """Print a list as `[a, b]` or an object as `{a: 1, b: 2}`."""
    out += "{" if object else "["
    var child = document.first_child(node)
    var first = True
    while child != NO_NODE:
        if not first:
            out += ", "
        first = False
        if object:
            out += document.name(child)
            out += ": "
            _value(out, document, document.child(child, Role.VALUE))
        else:
            _value(out, document, child)
        child = document.next_sibling(child)
    out += "}" if object else "]"


def _string(mut out: String, text: String):
    """Print a quoted string with apollo-compiler's escapes."""
    out += '"'
    var bytes = text.as_bytes()
    var start = 0
    var index = 0
    while index < len(bytes):
        var byte = bytes[index]
        if (byte < 32 and byte != 9) or byte == 34 or byte == 92:
            out += StringSlice(unsafe_from_utf8=bytes[start:index])
            out += _escape(byte)
            start = index + 1
        index += 1
    out += StringSlice(unsafe_from_utf8=bytes[start:])
    out += '"'


def _escape(byte: UInt8) -> String:
    """Return the escape of one byte that apollo-compiler escapes."""
    if byte == 8:
        return "\\b"
    if byte == 10:
        return "\\n"
    if byte == 12:
        return "\\f"
    if byte == 13:
        return "\\r"
    if byte == 34:
        return '\\"'
    if byte == 92:
        return "\\\\"
    var hex = _HEX.as_bytes()
    var out = String("\\u00")
    out += chr(Int(hex[Int(byte >> 4)]))
    out += chr(Int(hex[Int(byte & 15)]))
    return out^

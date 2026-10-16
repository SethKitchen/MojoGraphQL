# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The printer of Hive Federation Composition, for values, types and
directives.

Port of Hive Federation Composition v0.27.0 `src/graphql/printer.ts`, the
part that prints value literals, type references, arguments and directive
applications. The error messages of composition print these nodes.

This printer is not the graphql-js printer. A string is printed with
`JSON.stringify`, and a block string is printed as three quotes, a line
break, the value with each `\"\"\"` escaped, a line break and three quotes.

**Differences from upstream.** The type system definitions are not ported
yet; they print only in the supergraph phase.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role


def json_string(value: StringSlice) -> String:
    """Return a string as JavaScript `JSON.stringify` writes it.

    Args:
        value: The string.

    Returns:
        The string in double quotes, with `"`, `\\` and the control
        characters escaped.
    """
    var out = List[UInt8](capacity=value.byte_length() + 2)
    out.append(UInt8(ord('"')))
    var bytes = value.as_bytes()
    var index = 0
    while index < len(bytes):
        var byte = bytes[index]
        if byte == UInt8(ord('"')) or byte == UInt8(ord("\\")):
            out.append(UInt8(ord("\\")))
            out.append(byte)
        elif byte < 0x20:
            out.append(UInt8(ord("\\")))
            if byte == 0x08:
                out.append(UInt8(ord("b")))
            elif byte == 0x09:
                out.append(UInt8(ord("t")))
            elif byte == 0x0A:
                out.append(UInt8(ord("n")))
            elif byte == 0x0C:
                out.append(UInt8(ord("f")))
            elif byte == 0x0D:
                out.append(UInt8(ord("r")))
            else:
                out.append(UInt8(ord("u")))
                out.append(UInt8(ord("0")))
                out.append(UInt8(ord("0")))
                out.append(_hex_digit(byte >> 4))
                out.append(_hex_digit(byte & 15))
        else:
            out.append(byte)
        index += 1
    out.append(UInt8(ord('"')))
    return String(unsafe_from_utf8=out)


def _hex_digit(value: UInt8) -> UInt8:
    """Return the lowercase hex digit of a value below 16."""
    if value < 10:
        return UInt8(ord("0")) + value
    return UInt8(ord("a")) + value - 10


def utf16_length(text: StringSlice) -> Int:
    """Return the length of a string in UTF-16 code units, as JavaScript
    `length`.

    Args:
        text: The string.

    Returns:
        The number of UTF-16 code units.
    """
    var bytes = text.as_bytes()
    var units = 0
    var index = 0
    while index < len(bytes):
        var byte = bytes[index]
        if byte & 0xC0 != 0x80:
            units += 1
            if byte >= 0xF0:
                units += 1
        index += 1
    return units


def _block_string(value: String) -> String:
    """Return a block string as the Hive printer writes it."""
    return '"""\n' + value.replace('"""', '\\"""') + '\n"""'


def print_node(document: Document, node: Int) -> String:
    """Print a value, a type reference, an argument or a directive, as the
    Hive `print`.

    Args:
        document: The document that holds the node.
        node: The node's index, or `NO_NODE`.

    Returns:
        The printed node; empty for `NO_NODE` and for a kind that this port
        does not print.
    """
    if node == NO_NODE:
        return String("")
    var kind = document.kind(node)
    if kind == Kind.STRING:
        var value = document.string_value(node)
        if document.is_block(node):
            return _block_string(value)
        return json_string(value)
    if kind == Kind.BOOLEAN:
        return String("true") if document.boolean_value(node) else String(
            "false"
        )
    if kind == Kind.NULL:
        return String("null")
    if (
        kind == Kind.INT
        or kind == Kind.FLOAT
        or kind == Kind.ENUM
        or kind == Kind.NAME
    ):
        return String(document.text(node))
    if kind == Kind.VARIABLE:
        return "$" + String(document.name(node))
    if kind == Kind.LIST:
        return "[" + _join_children(document, node, Role.LIST_ITEM) + "]"
    if kind == Kind.OBJECT:
        return "{" + _join_children(document, node, Role.FIELD) + "}"
    if kind == Kind.OBJECT_FIELD or kind == Kind.ARGUMENT:
        return (
            String(document.name(node))
            + ": "
            + print_node(document, document.child(node, Role.VALUE))
        )
    if kind == Kind.DIRECTIVE:
        return (
            "@" + String(document.name(node)) + print_arguments(document, node)
        )
    if kind == Kind.NAMED_TYPE:
        return String(document.name(node))
    if kind == Kind.LIST_TYPE:
        return "[" + print_node(document, document.first_child(node)) + "]"
    if kind == Kind.NON_NULL_TYPE:
        return print_node(document, document.first_child(node)) + "!"
    return String("")


def _join_children(document: Document, node: Int, role: Role) -> String:
    """Print the children of a node with a role, joined by `, `."""
    var out = String("")
    var child = document.first_child(node)
    var first = True
    while child != NO_NODE:
        if document.role(child) == role:
            if not first:
                out += ", "
            out += print_node(document, child)
            first = False
        child = document.next_sibling(child)
    return out^


def print_arguments(document: Document, node: Int) -> String:
    """Print the arguments of a field or a directive, as the Hive
    `printArgs`.

    Args:
        document: The document that holds the node.
        node: The field or directive.

    Returns:
        Empty without arguments; else the arguments in parentheses, on
        separate lines when one line would be longer than 80 characters.
    """
    var printed = List[String]()
    var child = document.first_child(node)
    while child != NO_NODE:
        if document.role(child) == Role.ARGUMENT:
            printed.append(print_node(document, child))
        child = document.next_sibling(child)
    if len(printed) == 0:
        return String("")
    var line = "(" + String(", ").join(printed) + ")"
    if utf16_length(line) <= 80:
        return line^
    var body = String("\n").join(printed).replace("\n", "\n  ")
    return "(\n  " + body + "\n)"

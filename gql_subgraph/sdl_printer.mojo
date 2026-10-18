# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Print the parts of SDL nodes as the federation printer prints them.

`@apollo/subgraph` 2.14.4 prints `_service.sdl` and `printSubgraphSchema`
with the `printSchema` of `@apollo/federation-internals`, which is Elastic
licensed and is not read. This module implements that format from the
GraphQL specification and the graphql-js 16.14.2 `printSchema` (MIT),
with the differences that `@apollo/subgraph` shows as a black box:

- A value prints as graphql-js `print` prints a value, except that a block
  string prints as an ordinary string.
- The directives of a type print one per line, before its fields.

**Differences from upstream.** None known.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_language.block_string import (
    is_printable_as_block_string,
    print_block_string,
    print_string,
)
from gql_language.lexer import block_string_value
from gql_language.printer import print_node
from gql_language.source import Source


def print_value(doc: Document, node: Int) -> String:
    """Print a value literal.

    Args:
        doc: The document.
        node: A value node.

    Returns:
        The value, with each string as an ordinary string literal.
    """
    var kind = doc.kind(node)
    if kind == Kind.STRING:
        return print_string(doc.string_value(node))
    if kind == Kind.BOOLEAN:
        return String("true") if doc.boolean_value(node) else String("false")
    if kind == Kind.NULL:
        return String("null")
    if kind == Kind.LIST:
        var out = String("[")
        var item = doc.first_child(node)
        while item != NO_NODE:
            if out.byte_length() > 1:
                out += ", "
            out += print_value(doc, item)
            item = doc.next_sibling(item)
        return out + "]"
    if kind == Kind.OBJECT:
        var out = String("{")
        var field = doc.first_child(node)
        while field != NO_NODE:
            if out.byte_length() > 1:
                out += ", "
            out += String(doc.name(field)) + ": "
            out += print_value(doc, doc.child(field, Role.VALUE))
            field = doc.next_sibling(field)
        return out + "}"
    return String(doc.text(node))


def print_directive(doc: Document, node: Int) -> String:
    """Print a directive application.

    Args:
        doc: The document.
        node: A `Directive` node.

    Returns:
        The directive, such as `@key(fields: "id")`.
    """
    var out = "@" + String(doc.name(node))
    var argument = doc.child(node, Role.ARGUMENT)
    if argument == NO_NODE:
        return out^
    out += "("
    var first = True
    while argument != NO_NODE:
        if not first:
            out += ", "
        first = False
        out += String(doc.name(argument)) + ": "
        out += print_value(doc, doc.child(argument, Role.VALUE))
        argument = doc.next_with_role(argument)
    return out + ")"


def print_description(
    doc: Document,
    node: Int,
    indentation: String,
    first_in_block: Bool,
    round_trip: Bool = False,
) -> String:
    """Print the description of a definition and a line break, as
    graphql-js `printDescription`.

    Args:
        doc: The document.
        node: A definition node.
        indentation: The indentation of the definition.
        first_in_block: Whether the definition is the first in its block.
        round_trip: Print the value that a block string of the description
            holds, as `printSubgraphSchema` does: it prints the schema that
            upstream builds from printed SDL. A description that a block
            string cannot hold exactly loses its blank first and last lines
            and its common indent.

    Returns:
        The description, or empty when there is none.
    """
    if not doc.has_description(node):
        return String("")
    var description = doc.description(node)
    if round_trip and not is_printable_as_block_string(description):
        var printed = print_block_string(description)
        description = block_string_value(
            Source(printed), 0, printed.byte_length()
        )
    var block = print_block_string(description)
    var prefix = indentation
    if indentation != "" and not first_in_block:
        prefix = "\n" + indentation
    return prefix + block.replace("\n", "\n" + indentation) + "\n"


def print_input_value(doc: Document, node: Int) -> String:
    """Print an argument or an input field, without its description.

    Args:
        doc: The document.
        node: An `InputValueDefinition` node.

    Returns:
        The name, the type, the default value and the directives.
    """
    var out = String(doc.name(node)) + ": "
    out += print_node(doc, doc.child(node, Role.TYPE))
    var default = doc.child(node, Role.DEFAULT_VALUE)
    if default != NO_NODE:
        out += " = " + print_value(doc, default)
    out += print_directives_inline(doc, node)
    return out^


def print_directives_inline(doc: Document, node: Int) -> String:
    """Print the directives of a node, each after a space.

    Args:
        doc: The document.
        node: The node that holds the directives.

    Returns:
        The directives, or empty when there are none.
    """
    var out = String("")
    var directive = doc.child(node, Role.DIRECTIVE)
    while directive != NO_NODE:
        out += " " + print_directive(doc, directive)
        directive = doc.next_with_role(directive)
    return out^


def print_args(
    doc: Document, node: Int, indentation: String, round_trip: Bool = False
) -> String:
    """Print the arguments of a field or a directive, as graphql-js
    `printArgs`: on one line, or one per line when one has a description.

    Args:
        doc: The document.
        node: A `FieldDefinition` or `DirectiveDefinition` node.
        indentation: The indentation of the node.
        round_trip: As `print_description` takes it.

    Returns:
        The arguments in parentheses, or empty when there are none.
    """
    var args = doc.children(node, Role.ARGUMENT)
    var described = False
    var index = 0
    while index < len(args):
        described = described or doc.has_description(args[index])
        index += 1
    if len(args) == 0:
        return String("")
    var out = String("(")
    if not described:
        index = 0
        while index < len(args):
            if index > 0:
                out += ", "
            out += print_input_value(doc, args[index])
            index += 1
        return out + ")"
    var inner = "  " + indentation
    index = 0
    while index < len(args):
        out += "\n" + print_description(
            doc, args[index], inner, index == 0, round_trip
        )
        out += inner + print_input_value(doc, args[index])
        index += 1
    return out + "\n" + indentation + ")"


def print_item(
    doc: Document, node: Int, first: Bool, round_trip: Bool = False
) -> String:
    """Print a field, an input field or an enum value of a type, with its
    description.

    Args:
        doc: The document.
        node: A `FieldDefinition`, `InputValueDefinition` or
            `EnumValueDefinition` node.
        first: Whether the item is the first of its block.
        round_trip: As `print_description` takes it.

    Returns:
        The item, indented by two spaces, with no line break at the end.
    """
    var out = print_description(doc, node, "  ", first, round_trip) + "  "
    var kind = doc.kind(node)
    if kind == Kind.FIELD_DEFINITION:
        out += String(doc.name(node)) + print_args(doc, node, "  ", round_trip)
        out += ": "
        out += print_node(doc, doc.child(node, Role.TYPE))
        return out + print_directives_inline(doc, node)
    if kind == Kind.INPUT_VALUE_DEFINITION:
        return out + print_input_value(doc, node)
    return out + String(doc.name(node)) + print_directives_inline(doc, node)


def print_directive_definition(
    doc: Document, node: Int, round_trip: Bool = False
) -> String:
    """Print a directive definition with its description.

    Args:
        doc: The document.
        node: A `DirectiveDefinition` node.
        round_trip: As `print_description` takes it.

    Returns:
        The definition, such as `directive @a on FIELD`.
    """
    var out = print_description(doc, node, "", True, round_trip)
    out += "directive @" + String(doc.name(node))
    out += print_args(doc, node, "", round_trip)
    if doc.is_repeatable(node):
        out += " repeatable"
    out += " on "
    var location = doc.child(node, Role.LOCATION)
    var first = True
    while location != NO_NODE:
        if not first:
            out += " | "
        first = False
        out += String(doc.text(location))
        location = doc.next_with_role(location)
    return out^

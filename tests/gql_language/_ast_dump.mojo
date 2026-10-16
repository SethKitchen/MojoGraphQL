# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Test helpers: an AST as indented text, and graphql-js `dedent`.

`dump` writes one line per node: the role it fills, its kind, its byte
range and its value. It holds what the graphql-js tests compare with
`expectJSON(...).toDeepEqual(...)`, in a form a test can spell out:

    Document 0..6
      definitions: OperationDefinition 0..6 query
        selectionSet: SelectionSet 0..6
          selections: Field 2..4
            name: Name 2..4 "id"
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_language.error import quote_json_string


def _line(
    document: Document, node: Int, depth: Int, ranges: Bool = True
) -> String:
    """Return the text of one node, without a line break."""
    var out = String("  ") * depth
    var role = document.role(node)
    if role != Role.ROOT:
        out += String(role.text()) + ": "
    var kind = document.kind(node)
    out += String(kind.text())
    if ranges:
        out += " " + String(document.start(node)) + ".."
        out += String(document.end(node))
    if (
        kind == Kind.NAME
        or kind == Kind.INT
        or kind == Kind.FLOAT
        or kind == Kind.ENUM
    ):
        out += " " + quote_json_string(String(document.text(node)))
    elif kind == Kind.STRING:
        out += " " + quote_json_string(document.string_value(node))
        if document.is_block(node):
            out += " block"
    elif kind == Kind.BOOLEAN:
        if document.boolean_value(node):
            out += " true"
        else:
            out += " false"
    elif (
        kind == Kind.OPERATION_DEFINITION
        or kind == Kind.OPERATION_TYPE_DEFINITION
    ):
        out += " " + String(document.operation(node).text())
    elif kind == Kind.DIRECTIVE_DEFINITION and document.is_repeatable(node):
        out += " repeatable"
    return out^


def _push_children(
    document: Document, node: Int, depth: Int, mut stack: List[Int]
):
    """Push a node's children, last first, each with its depth."""
    var children = List[Int]()
    var child = document.first_child(node)
    while child != NO_NODE:
        children.append(child)
        child = document.next_sibling(child)
    for index in range(len(children) - 1, -1, -1):
        stack.append(children[index])
        stack.append(depth + 1)


def dump(document: Document, node: Int, ranges: Bool = True) -> String:
    """Return a node and its descendants as indented text.

    Args:
        document: The document.
        node: The node to start at.
        ranges: Write each node's byte range.

    Returns:
        One line per node, each ending in a line break.
    """
    var out = String("")
    var stack: List[Int] = [node, 0]
    while len(stack) > 0:
        var depth = stack.pop()
        var current = stack.pop()
        out += _line(document, current, depth, ranges) + "\n"
        _push_children(document, current, depth, stack)
    return out^


def dump_root(document: Document) -> String:
    """Return the whole document as indented text.

    Args:
        document: The document.

    Returns:
        The dump of its root node.
    """
    return dump(document, document.root)


def shape(document: Document) -> String:
    """Return the whole document as indented text without byte ranges.

    Two documents with the same shape are equal ASTs, as graphql-js
    compares them with `noLocation: true`.

    Args:
        document: The document.

    Returns:
        The dump of its root node, without ranges.
    """
    return dump(document, document.root, False)


def dedent(text: String) -> String:
    """Strip a template's indent, as graphql-js test `dedent`.

    Leading line breaks and trailing white space go; then the indent of the
    first line is removed from every line that starts with it.

    Args:
        text: The text, often a triple-quoted Mojo string.

    Returns:
        The dedented text.
    """
    var bytes = text.as_bytes()
    var start = 0
    while start < len(bytes) and bytes[start] == 10:
        start += 1
    var end = len(bytes)
    while end > start and (
        bytes[end - 1] == 32 or bytes[end - 1] == 9 or bytes[end - 1] == 10
    ):
        end -= 1
    var trimmed = String(unsafe_from_utf8=bytes[start:end])
    var indent = 0
    var trimmed_bytes = trimmed.as_bytes()
    while indent < len(trimmed_bytes) and (
        trimmed_bytes[indent] == 32 or trimmed_bytes[indent] == 9
    ):
        indent += 1
    var prefix = String(unsafe_from_utf8=trimmed_bytes[0:indent])
    var out = String("")
    var lines = trimmed.split("\n")
    for index in range(len(lines)):
        if index > 0:
            out += "\n"
        var line = String(lines[index])
        if indent > 0 and line.startswith(prefix):
            out += String(line[byte=indent:])
        else:
            out += line
    return out^

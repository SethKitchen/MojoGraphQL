# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Sort a GraphQL document the way Hive prints a normalized schema.

Port of Hive Federation Composition v0.27.0 `src/graphql/sort-sdl.ts`.
Definitions, fields, enum values, implements entries, union members, and
directives are sorted by kind and then by name. Directive arguments and
directive locations are sorted. A string value is trimmed. Field arguments
stay in source order. The lists in a type extension or a schema extension
stay in source order, because upstream visits definitions only.
"""

from gql_language.ast import (
    NO_NODE,
    Document,
    FLAG_BLOCK,
    FLAG_REPEATABLE,
    FLAG_TRUE,
    Kind,
    Role,
)
from gql_language.parser import parse
from gql_language.printer import print_ast


def sort_sdl(sdl: String) raises -> String:
    """Return SDL sorted as upstream `sortSDL`, then printed.

    Args:
        sdl: A GraphQL document.

    Returns:
        The sorted document.

    Raises:
        GraphQLError: The SDL does not parse.
    """
    var document = parse(sdl)
    var out = Document()
    var children = List[Int]()
    var child = document.first_child(document.root)
    while child != NO_NODE:
        children.append(child)
        child = document.next_sibling(child)
    _sort_groups(document, document.root, children)
    var index = 0
    while index < len(children):
        var copied = _copy_sorted(
            out, document, children[index], Role.DEFINITION
        )
        out.append_child(out.root, copied)
        index += 1
    return print_ast(out)


def _copy_sorted(
    mut dest: Document, src: Document, node: Int, role: Role
) -> Int:
    """Copy a tree, sorting the lists Hive sorts.

    Args:
        dest: The destination document.
        src: The parsed document.
        node: The node to copy.
        role: The role of the copy.

    Returns:
        The copy.
    """
    var root = _copy_one(dest, src, node, role)
    var stack = List[Int]()
    stack.append(node)
    stack.append(root)
    while len(stack) > 0:
        var copy = stack.pop()
        var original = stack.pop()
        var children = List[Int]()
        var child = src.first_child(original)
        while child != NO_NODE:
            children.append(child)
            child = src.next_sibling(child)
        _sort_groups(src, original, children)
        var copies = List[Int]()
        for index in range(len(children)):
            var child_copy = _copy_one(
                dest, src, children[index], src.role(children[index])
            )
            dest.append_child(copy, child_copy)
            copies.append(child_copy)
        var back = len(children)
        while back > 0:
            back -= 1
            stack.append(children[back])
            stack.append(copies[back])
    return root


def _sort_groups(src: Document, parent: Int, mut children: List[Int]):
    """Sort one role's children in place, leaving the other children.

    Args:
        src: The parsed document.
        parent: The parent node.
        children: The children, in source order.
    """
    var kind = src.kind(parent)
    _sort_role(src, children, kind, Role.DEFINITION)
    _sort_role(src, children, kind, Role.DIRECTIVE)
    _sort_role(src, children, kind, Role.FIELD)
    _sort_role(src, children, kind, Role.INTERFACE)
    _sort_role(src, children, kind, Role.ENUM_VALUE)
    _sort_role(src, children, kind, Role.MEMBER_TYPE)
    _sort_role(src, children, kind, Role.LOCATION)
    _sort_role(src, children, kind, Role.ARGUMENT)


def _sort_role(src: Document, mut children: List[Int], kind: Kind, role: Role):
    """Sort the children of one role when Hive sorts that list.

    Args:
        src: The parsed document.
        children: The children.
        kind: The parent kind.
        role: The child role.
    """
    if not _sorts(kind, role):
        return
    var picked = List[Int]()
    var slots = List[Int]()
    var at = 0
    while at < len(children):
        if src.role(children[at]) == role:
            picked.append(children[at])
            slots.append(at)
        at += 1
    _sort_nodes(src, picked)
    for index in range(len(slots)):
        children[slots[index]] = picked[index]


def _sorts(kind: Kind, role: Role) -> Bool:
    """Return True when Hive sorts this child list.

    Upstream visits definitions only, so an extension keeps its order.

    Args:
        kind: The parent kind.
        role: The child role.

    Returns:
        Whether the list is sorted.
    """
    if kind == Kind.DOCUMENT:
        return role == Role.DEFINITION
    if kind == Kind.OBJECT_TYPE_DEFINITION:
        return (
            role == Role.DIRECTIVE
            or role == Role.FIELD
            or role == Role.INTERFACE
        )
    if kind == Kind.INTERFACE_TYPE_DEFINITION:
        return role == Role.DIRECTIVE or role == Role.FIELD
    if kind == Kind.INPUT_OBJECT_TYPE_DEFINITION:
        return role == Role.DIRECTIVE or role == Role.FIELD
    if kind == Kind.ENUM_TYPE_DEFINITION:
        return role == Role.DIRECTIVE or role == Role.ENUM_VALUE
    if kind == Kind.UNION_TYPE_DEFINITION:
        return role == Role.MEMBER_TYPE or role == Role.DIRECTIVE
    if kind == Kind.DIRECTIVE_DEFINITION:
        return role == Role.LOCATION
    if kind == Kind.DIRECTIVE:
        return role == Role.ARGUMENT
    return role == Role.DIRECTIVE and (
        kind == Kind.SCHEMA_DEFINITION
        or kind == Kind.SCALAR_TYPE_DEFINITION
        or kind == Kind.ENUM_VALUE_DEFINITION
        or kind == Kind.FIELD_DEFINITION
    )


def _sort_nodes(src: Document, mut nodes: List[Int]):
    """Sort nodes by Hive's key, keeping the original order on a tie.

    Args:
        src: The parsed document.
        nodes: The nodes to sort.
    """
    var index = 1
    while index < len(nodes):
        var current = nodes[index]
        var key = _key(src, current)
        var at = index
        while at > 0 and _less(key, _key(src, nodes[at - 1])):
            nodes[at] = nodes[at - 1]
            at -= 1
        nodes[at] = current
        index += 1


def _key(document: Document, node: Int) -> String:
    """Return the sort key of a node.

    Args:
        document: The parsed document.
        node: The node.

    Returns:
        A key that sorts like `lodash.sortby` on kind and name.
    """
    var kind = document.kind(node)
    if kind == Kind.DIRECTIVE:
        return _directive_key(document, node)
    if kind == Kind.NAME:
        return String(document.text(node))
    return String(kind.text()) + "\n" + String(document.name(node))


def _directive_key(document: Document, node: Int) -> String:
    """Return a directive's sort key, including its argument values.

    Args:
        document: The parsed document.
        node: The directive.

    Returns:
        The directive name plus its argument keys, sorted.
    """
    var parts = List[String]()
    var child = document.first_child(node)
    while child != NO_NODE:
        if document.role(child) == Role.ARGUMENT:
            var value = document.child(child, Role.VALUE)
            parts.append(
                String(document.name(child)) + _value_text(document, value)
            )
        child = document.next_sibling(child)
    _sort_strings(parts)
    var args = String("")
    for index in range(len(parts)):
        if index > 0:
            args += ";"
        args += parts[index]
    return String(document.name(node)) + args


def _value_text(document: Document, node: Int) -> String:
    """Return the text Hive uses when it sorts a directive argument.

    Args:
        document: The parsed document.
        node: The value node.

    Returns:
        The sort text.
    """
    var kind = document.kind(node)
    if kind == Kind.STRING:
        return document.string_value(node)
    if kind == Kind.INT or kind == Kind.FLOAT or kind == Kind.ENUM:
        return String(document.text(node))
    if kind == Kind.BOOLEAN:
        if document.boolean_value(node):
            return String("true")
        return String("false")
    if kind == Kind.LIST:
        var out = String("")
        var child = document.first_child(node)
        var first = True
        while child != NO_NODE:
            if not first:
                out += ","
            first = False
            out += _value_text(document, child)
            child = document.next_sibling(child)
        return out
    if kind == Kind.OBJECT:
        return String("OBJECT")
    return String("NULL")


def _sort_strings(mut items: List[String]):
    """Sort strings in byte order, keeping ties in place.

    Args:
        items: The strings.
    """
    var index = 1
    while index < len(items):
        var current = items[index]
        var at = index
        while at > 0 and _less(current, items[at - 1]):
            items[at] = items[at - 1]
            at -= 1
        items[at] = current
        index += 1


def _less(left: String, right: String) -> Bool:
    """Return True when `left` sorts before `right`.

    Args:
        left: A key.
        right: Another key.

    Returns:
        Whether `left` is first.
    """
    var a = left.as_bytes()
    var b = right.as_bytes()
    var count = len(a)
    if len(b) < count:
        count = len(b)
    var index = 0
    while index < count:
        if a[index] < b[index]:
            return True
        if a[index] > b[index]:
            return False
        index += 1
    return len(a) < len(b)


def _copy_one(mut dest: Document, src: Document, node: Int, role: Role) -> Int:
    """Copy one node. A string value is trimmed.

    Args:
        dest: The destination document.
        src: The parsed document.
        node: The node.
        role: The role of the copy.

    Returns:
        The copy.
    """
    var kind = src.kind(node)
    if (
        kind == Kind.NAME
        or kind == Kind.INT
        or kind == Kind.FLOAT
        or kind == Kind.ENUM
    ):
        return dest.add_text(kind, role, src.text(node))
    if kind == Kind.STRING:
        var flags = UInt8(0)
        if src.is_block(node):
            flags = FLAG_BLOCK
        return dest.add_text(kind, role, _trim(src.string_value(node)), flags)
    if kind == Kind.BOOLEAN:
        var flags = UInt8(0)
        if src.boolean_value(node):
            flags = FLAG_TRUE
        return dest.add(kind, role, flags)
    if kind == Kind.OPERATION_TYPE_DEFINITION:
        return dest.add(kind, role, src.operation(node).value)
    if kind == Kind.DIRECTIVE_DEFINITION and src.is_repeatable(node):
        return dest.add(kind, role, FLAG_REPEATABLE)
    return dest.add(kind, role, 0)


def _trim(text: String) -> String:
    """Trim whitespace the way JavaScript `String.trim` trims ASCII.

    Args:
        text: The string value.

    Returns:
        The text without leading or trailing whitespace.
    """
    var bytes = text.as_bytes()
    var start = 0
    var end = len(bytes)
    while start < end and _space(bytes[start]):
        start += 1
    while end > start and _space(bytes[end - 1]):
        end -= 1
    return String(text[byte=start:end])


def _space(byte: UInt8) -> Bool:
    """Return True for ASCII whitespace.

    Args:
        byte: One byte.

    Returns:
        Whether JavaScript treats the byte as trim whitespace.
    """
    return (
        byte == 9
        or byte == 10
        or byte == 11
        or byte == 12
        or byte == 13
        or byte == 32
    )

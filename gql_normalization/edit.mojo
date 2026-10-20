# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Edits of a `gql_language` `Document` in place, and node comparisons.

A `Document` adds and links nodes, but has no removal. The normalization
passes of graphql-go-tools edit the reference lists of their AST in place:
`RemoveFromSelectionSet`, `ReplaceSelectionOnSelectionSet`,
`AppendSelectionSet`. These functions do the same on the links of the
arena. A node that is unlinked stays in `Document.nodes`, and no walk or
print reaches it.

A node has no parent link, so each function takes the parent. Each one
keeps the `roles` bits of the parent exact, as the printer needs.

The comparisons are those of graphql-go-tools `ast`: `ValuesAreEqual`,
`ArgumentSetsAreEquals` (in order) and `DirectiveSetsAreEqual` (as
multisets).
"""

from gql_language.ast import (
    Document,
    FLAG_BLOCK,
    FLAG_TRUE,
    Kind,
    NO_NODE,
    Role,
    role_bit,
)


@always_inline
def recompute_roles(mut document: Document, parent: Int):
    """Set the `roles` bits of a node from its children.

    Args:
        document: The document.
        parent: The node.
    """
    var bits: UInt32 = 0
    var current = Int(document.nodes[parent].first)
    while current != NO_NODE:
        bits |= role_bit(document.nodes[current].role)
        current = Int(document.nodes[current].next)
    document.nodes[parent].roles = bits


@always_inline
def previous_sibling(document: Document, parent: Int, child: Int) -> Int:
    """Return the sibling before a child, or `NO_NODE` for the first child.

    Args:
        document: The document.
        parent: The parent of `child`.
        child: The child.

    Returns:
        The previous sibling, or `NO_NODE`.
    """
    var previous = NO_NODE
    var current = Int(document.nodes[parent].first)
    while current != child:
        previous = current
        current = Int(document.nodes[current].next)
    return previous


@always_inline
def remove_child(mut document: Document, parent: Int, child: Int):
    """Unlink a child from its parent.

    Args:
        document: The document.
        parent: The parent.
        child: The child to unlink; it must be a child of `parent`.
    """
    var previous = previous_sibling(document, parent, child)
    var after = document.nodes[child].next
    if previous == NO_NODE:
        document.nodes[parent].first = after
    else:
        document.nodes[previous].next = after
    if Int(document.nodes[parent].last) == child:
        document.nodes[parent].last = Int32(previous)
    document.nodes[child].next = Int32(NO_NODE)
    recompute_roles(document, parent)


@always_inline
def insert_after(
    mut document: Document, parent: Int, previous: Int, child: Int
):
    """Link a node without a parent after a child, or first.

    Args:
        document: The document.
        parent: The parent.
        previous: The child to insert after, or `NO_NODE` to insert first.
        child: The node to insert.
    """
    if previous == NO_NODE:
        document.nodes[child].next = document.nodes[parent].first
        document.nodes[parent].first = Int32(child)
    else:
        document.nodes[child].next = document.nodes[previous].next
        document.nodes[previous].next = Int32(child)
    if Int(document.nodes[child].next) == NO_NODE:
        document.nodes[parent].last = Int32(child)
    document.nodes[parent].roles |= role_bit(document.nodes[child].role)


def move_children(mut document: Document, to: Int, from_parent: Int):
    """Move every child of a node to the end of the children of another.

    graphql-go-tools `AppendSelectionSet`.

    Args:
        document: The document.
        to: The node that gets the children.
        from_parent: The node that loses them.
    """
    var current = Int(document.nodes[from_parent].first)
    document.nodes[from_parent].first = Int32(NO_NODE)
    document.nodes[from_parent].last = Int32(NO_NODE)
    document.nodes[from_parent].roles = 0
    while current != NO_NODE:
        var after = Int(document.nodes[current].next)
        document.nodes[current].next = Int32(NO_NODE)
        document.append_child(to, current)
        current = after


def splice(mut document: Document, parent: Int, child: Int, from_parent: Int):
    """Replace a child with every child of another node, in order.

    graphql-go-tools `ReplaceSelectionOnSelectionSet`.

    Args:
        document: The document.
        parent: The parent of `child`.
        child: The child to replace.
        from_parent: The node whose children take its place.
    """
    var previous = previous_sibling(document, parent, child)
    remove_child(document, parent, child)
    var current = Int(document.nodes[from_parent].first)
    while current != NO_NODE:
        var after = Int(document.nodes[current].next)
        insert_after(document, parent, previous, current)
        previous = current
        current = after
    document.nodes[from_parent].first = Int32(NO_NODE)
    document.nodes[from_parent].last = Int32(NO_NODE)
    document.nodes[from_parent].roles = 0


def clone(mut document: Document, node: Int) -> Int:
    """Copy a node and its descendants within one document.

    The copies keep the byte ranges, so they share the text.

    Args:
        document: The document.
        node: The node to copy.

    Returns:
        The copy, without a parent.
    """
    var root = _clone_node(document, node)
    var stack: List[Int] = [node, root]
    while len(stack) > 0:
        var copy = stack.pop()
        var original = stack.pop()
        var current = Int(document.nodes[original].first)
        while current != NO_NODE:
            var child_copy = _clone_node(document, current)
            document.append_child(copy, child_copy)
            stack.append(current)
            stack.append(child_copy)
            current = Int(document.nodes[current].next)
    return root


def _clone_node(mut document: Document, node: Int) -> Int:
    """Copy one node without its links."""
    var copy = document.nodes[node]
    copy.first = Int32(NO_NODE)
    copy.last = Int32(NO_NODE)
    copy.next = Int32(NO_NODE)
    copy.roles = 0
    document.nodes.append(copy)
    return len(document.nodes) - 1


@always_inline
def text_equal(document: Document, left: Int, right: Int) -> Bool:
    """Return True if two text nodes, or two missing nodes, are equal.

    Args:
        document: The document.
        left: A node with text, or `NO_NODE`.
        right: A node with text, or `NO_NODE`.

    Returns:
        Whether both are missing, or both have the same text.
    """
    if left == NO_NODE or right == NO_NODE:
        return left == right
    return document.text(left) == document.text(right)


def values_equal(document: Document, left: Int, right: Int) -> Bool:
    """Return True if two value nodes are equal: graphql-go-tools
    `ValuesAreEqual`.

    Args:
        document: The document.
        left: A value node.
        right: A value node.

    Returns:
        Whether the kinds and the contents agree; list items and object
        fields compare in order.
    """
    var kind = document.kind(left)
    if kind != document.kind(right):
        return False
    if kind == Kind.VARIABLE:
        return document.name(left) == document.name(right)
    if kind == Kind.STRING:
        if (document.nodes[left].flags & FLAG_BLOCK) != (
            document.nodes[right].flags & FLAG_BLOCK
        ):
            return False
        return document.string_value(left) == document.string_value(right)
    if kind == Kind.BOOLEAN:
        return (document.nodes[left].flags & FLAG_TRUE) == (
            document.nodes[right].flags & FLAG_TRUE
        )
    if kind == Kind.LIST or kind == Kind.OBJECT:
        var a = Int(document.nodes[left].first)
        var b = Int(document.nodes[right].first)
        while a != NO_NODE and b != NO_NODE:
            if kind == Kind.OBJECT:
                if document.name(a) != document.name(b):
                    return False
                if not values_equal(
                    document,
                    document.child(a, Role.VALUE),
                    document.child(b, Role.VALUE),
                ):
                    return False
            elif not values_equal(document, a, b):
                return False
            a = Int(document.nodes[a].next)
            b = Int(document.nodes[b].next)
        return a == b
    if kind == Kind.NULL:
        return True
    return document.text(left) == document.text(right)


@always_inline
def arguments_equal(document: Document, left: Int, right: Int) -> Bool:
    """Return True if the arguments of two nodes are equal, in order:
    graphql-go-tools `ArgumentSetsAreEquals`.

    Args:
        document: The document.
        left: A field or a directive.
        right: A field or a directive.

    Returns:
        Whether both have the same count, and each pair of arguments has
        the same name and an equal value.
    """
    var a = document.child(left, Role.ARGUMENT)
    var b = document.child(right, Role.ARGUMENT)
    while a != NO_NODE and b != NO_NODE:
        if document.name(a) != document.name(b):
            return False
        if not values_equal(
            document,
            document.child(a, Role.VALUE),
            document.child(b, Role.VALUE),
        ):
            return False
        a = document.next_with_role(a)
        b = document.next_with_role(b)
    return a == b


comptime DEFER_INTERNAL = "__defer_internal"
"""The internal defer directive of upstream: `literal.DEFER_INTERNAL`."""


@always_inline
def _without_defer_internal(document: Document, node: Int) -> List[Int]:
    """Return the directives of a node without `@__defer_internal`:
    `directivesWithoutDeferInternal`."""
    var out = List[Int]()
    var directive = document.child(node, Role.DIRECTIVE)
    while directive != NO_NODE:
        if not document.name(directive) == DEFER_INTERNAL:
            out.append(directive)
        directive = document.next_with_role(directive)
    return out^


def merge_fields_defer(mut document: Document, left: Int, right: Int):
    """Keep on `left` the `@__defer_internal` that wins when `right` merges
    into it: `MergeFieldsDefer`.

    A field without the directive wins. Of two, the smaller `id` wins.

    Args:
        document: The document.
        left: The field that stays.
        right: The field that goes.
    """
    var left_defer = _find_directive(document, left, DEFER_INTERNAL)
    var right_defer = _find_directive(document, right, DEFER_INTERNAL)
    if left_defer == NO_NODE:
        return
    if right_defer == NO_NODE:
        remove_child(document, left, left_defer)
        return
    if _defer_id(document, left_defer) > _defer_id(document, right_defer):
        remove_child(document, left, left_defer)
        var last = Int(document.nodes[left].last)
        if document.role(last) == Role.SELECTION_SET:
            last = previous_sibling(document, left, last)
        insert_after(document, left, last, clone(document, right_defer))


@always_inline
def _find_directive(document: Document, node: Int, name: StringSlice) -> Int:
    """Return the first directive of a node with a name, or `NO_NODE`."""
    var directive = document.child(node, Role.DIRECTIVE)
    while directive != NO_NODE:
        if document.name(directive) == name:
            return directive
        directive = document.next_with_role(directive)
    return NO_NODE


def _defer_id(document: Document, directive: Int) -> Int:
    """Return the `id` argument of `@__defer_internal`, or 0."""
    var argument = document.child(directive, Role.ARGUMENT)
    while argument != NO_NODE:
        if document.name(argument) == "id":
            var digits = document.text(
                document.child(argument, Role.VALUE)
            ).as_bytes()
            var total = 0
            var at = 0
            while at < len(digits):
                total = total * 10 + Int(digits[at]) - ord("0")
                at += 1
            return total
        argument = document.next_with_role(argument)
    return 0


@always_inline
def directives_equal(document: Document, left: Int, right: Int) -> Bool:
    """Return True if the directives of two nodes are equal as multisets:
    graphql-go-tools `DirectiveSetsAreEqual`.

    Args:
        document: The document.
        left: A node with directives.
        right: A node with directives.

    Returns:
        Whether each directive of one node matches a distinct directive of
        the other, by name and arguments.
    """
    var lefts = _without_defer_internal(document, left)
    var rights = _without_defer_internal(document, right)
    if len(lefts) != len(rights):
        return False
    var matched = List[Bool](length=len(rights), fill=False)
    for a in lefts:
        var found = False
        var j = 0
        while j < len(rights):
            if not matched[j]:
                var b = rights[j]
                if document.name(a) == document.name(b) and arguments_equal(
                    document, a, b
                ):
                    matched[j] = True
                    found = True
                    break
            j += 1
        if not found:
            return False
    return True

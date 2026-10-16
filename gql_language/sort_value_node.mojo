# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Sort the fields of an input object value, at every depth.

Port of graphql-js 16.14.2 `utilities/sortValueNode.ts` and
`jsutils/naturalCompare.ts`. The fields of each object value are sorted by
name in natural order, where a run of digits compares as a number. The sort
is stable, as JavaScript `Array.prototype.sort` is.

**Differences from upstream.** graphql-js returns new objects for the
object values and their fields, and the same objects for the other values.
A `Document` is one arena, so this port returns a new document that holds a
sorted copy of the value. The copy has no source locations. graphql-js
`naturalCompare` compares UTF-16 code units; this port compares bytes. The
two agree for names, which are ASCII.
"""

from gql_language.ast import Document, Kind, Node, Role
from gql_language.source import Source


@always_inline
def _byte_at(bytes: Span[UInt8, _], index: Int) -> Int:
    """Return a byte, or -1 past the end: JavaScript `charCodeAt` NaN."""
    if index < len(bytes):
        return Int(bytes[index])
    return -1


@always_inline
def _is_digit(code: Int) -> Bool:
    """Return True for the code of `0` through `9`."""
    return code >= 48 and code <= 57


def _natural_compare(a: StringSlice, b: StringSlice) -> Int:
    """Compare two texts as graphql-js `naturalCompare`: negative when `a`
    comes first, positive when `b` comes first."""
    var a_bytes = a.as_bytes()
    var b_bytes = b.as_bytes()
    var a_index = 0
    var b_index = 0
    while a_index < len(a_bytes) and b_index < len(b_bytes):
        var a_char = Int(a_bytes[a_index])
        var b_char = Int(b_bytes[b_index])
        if _is_digit(a_char) and _is_digit(b_char):
            # As graphql-js, a number ends after a leading zero.
            a_index += 1
            var a_number = a_char - 48
            a_char = _byte_at(a_bytes, a_index)
            while _is_digit(a_char) and a_number > 0:
                a_index += 1
                a_number = a_number * 10 + a_char - 48
                a_char = _byte_at(a_bytes, a_index)
            b_index += 1
            var b_number = b_char - 48
            b_char = _byte_at(b_bytes, b_index)
            while _is_digit(b_char) and b_number > 0:
                b_index += 1
                b_number = b_number * 10 + b_char - 48
                b_char = _byte_at(b_bytes, b_index)
            if a_number != b_number:
                return -1 if a_number < b_number else 1
        else:
            if a_char != b_char:
                return -1 if a_char < b_char else 1
            a_index += 1
            b_index += 1
    return len(a_bytes) - len(b_bytes)


def _copy_value(
    mut out: Document, document: Document, node: Int, role: Role
) -> Int:
    """Copy a value into `out`, with the fields of each object sorted."""
    var kind = document.kind(node)
    if kind == Kind.OBJECT:
        return _copy_object(out, document, node, role)
    if kind == Kind.LIST:
        return _copy_list(out, document, node, role)
    return out.copy_subtree(document, node, role)


def _copy_list(
    mut out: Document, document: Document, node: Int, role: Role
) -> Int:
    """Copy a list value, each item sorted."""
    var copy = out.add(Kind.LIST, role)
    var items = document.children(node, Role.LIST_ITEM)
    for item in items:
        out.append_child(copy, _copy_value(out, document, item, Role.LIST_ITEM))
    return copy


def _copy_object(
    mut out: Document, document: Document, node: Int, role: Role
) -> Int:
    """Copy an object value with its fields sorted by name."""
    var fields = document.children(node, Role.FIELD)
    # An insertion sort: stable, and an object has few fields.
    var index = 1
    while index < len(fields):
        var at = index
        while (
            at > 0
            and _natural_compare(
                document.name(fields[at - 1]), document.name(fields[at])
            )
            > 0
        ):
            var earlier = fields[at - 1]
            fields[at - 1] = fields[at]
            fields[at] = earlier
            at -= 1
        index += 1
    var copy = out.add(Kind.OBJECT, role)
    for field in fields:
        var field_copy = out.add(Kind.OBJECT_FIELD, Role.FIELD)
        _ = out.add_name(field_copy, Role.NAME, document.name(field))
        var value = document.child(field, Role.VALUE)
        out.append_child(
            field_copy, _copy_value(out, document, value, Role.VALUE)
        )
        out.append_child(copy, field_copy)
    return copy


def sort_value_node(document: Document, node: Int) -> Document:
    """Return a copy of a value with the fields of every object value
    sorted by name, as graphql-js `sortValueNode`.

    Args:
        document: The document that holds the value.
        node: A value node: a literal, a list, an object or a variable.

    Returns:
        A new document whose root is the sorted copy of the value.
    """
    var out = Document(Source(""), List[Node](), 0)
    out.root = _copy_value(out, document, node, Role.ROOT)
    return out^

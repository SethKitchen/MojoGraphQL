# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Test helpers for `gql_schema.values`: build `JsValues` trees and show
them as JavaScript literals."""

from gql_language.error import quote_json_string
from gql_language.parser import parse_value
from gql_schema.definition import Schema, TypeRef
from gql_schema.values import (
    UNDEFINED,
    JsKind,
    JsNode,
    JsValues,
    js_number_to_string,
    value_from_ast_untyped,
)


struct Js(Movable):
    """A `JsValues` tree and its root value."""

    var values: JsValues
    """The tree."""
    var root: Int
    """The root value's index, or `UNDEFINED`."""

    def __init__(out self, var values: JsValues, root: Int):
        """Wrap a tree.

        Args:
            values: The tree.
            root: The root value's index.
        """
        self.values = values^
        self.root = root


def js(text: String) raises -> Js:
    """Build a value from GraphQL literal text, as `valueFromASTUntyped`:
    an enum literal is a string and a variable is `undefined`.

    Args:
        text: Such as `{ foo: 3, bar: HELLO }`.

    Returns:
        The value.

    Raises:
        Error: For text that is not one value.
    """
    var document = parse_value(text)
    var values = JsValues()
    var root = value_from_ast_untyped(document, document.root, values)
    return Js(values^, root)


def js_number(value: Float64) -> Js:
    """Build a number, such as NaN, that no literal gives.

    Args:
        value: The number.

    Returns:
        The value.
    """
    var values = JsValues()
    var node = JsNode(JsKind.NUMBER)
    node.number = value
    var root = values.add(node^)
    return Js(values^, root)


def js_string(text: String) -> Js:
    """Build a string.

    Args:
        text: The string.

    Returns:
        The value.
    """
    var values = JsValues()
    var node = JsNode(JsKind.STRING)
    node.text = text
    var root = values.add(node^)
    return Js(values^, root)


def js_undefined() -> Js:
    """Build `undefined`.

    Returns:
        The value.
    """
    return Js(JsValues(), UNDEFINED)


def show(values: JsValues, value: Int) -> String:
    """Show a value in full as a JavaScript literal, for comparison.

    Args:
        values: The tree.
        value: The value's index.

    Returns:
        Such as `{int: 42, list: [true, null, "x"]}` or `undefined`.
    """
    var kind = values.kind(value)
    if kind == JsKind.UNDEFINED:
        return String("undefined")
    ref node = values.nodes[value]
    if kind == JsKind.NULL:
        return String("null")
    if kind == JsKind.BOOLEAN:
        return String("true") if node.flag else String("false")
    if kind == JsKind.NUMBER:
        return js_number_to_string(node.number)
    if kind == JsKind.STRING:
        return quote_json_string(node.text)
    var out = String("[") if kind == JsKind.LIST else String("{")
    for index in range(len(node.items)):
        if index > 0:
            out += ", "
        if kind == JsKind.OBJECT:
            out += node.keys[index] + ": "
        out += show(values, node.items[index])
    return out + ("]" if kind == JsKind.LIST else "}")


def ref_of(schema: Schema, text: String) -> TypeRef:
    """Return the reference for a type written as SDL, such as `[Int!]`.

    Args:
        schema: The schema that holds the named type.
        text: The type.

    Returns:
        The reference.
    """
    var bytes = text.as_bytes()
    var length = len(bytes)
    if bytes[length - 1] == 0x21:
        return ref_of(schema, String(text[byte = 0 : length - 1])).non_null()
    if bytes[0] == 0x5B:
        return ref_of(schema, String(text[byte = 1 : length - 1])).list_of()
    return TypeRef.of(schema.type_named(text))

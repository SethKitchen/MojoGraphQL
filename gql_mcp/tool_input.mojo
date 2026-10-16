# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Check the arguments of a built-in tool, with the messages of `serde`.

The upstream tools read their arguments with `serde_json::from_value` into
a struct `Input`, and a failure becomes the tool error `Invalid input:
<message>`. `check_input` gives the same messages for the field kinds that
the built-in tools use:

- `invalid type: null, expected struct Input` when there are no arguments;
- `invalid type: <found>, expected <kind>` for a value of the wrong kind,
  where `<found>` is `null`, ``boolean `true` ``, ``integer `5` ``,
  ``floating point `1.5` ``, `string "x"`, `sequence` or `map`;
- ``invalid value: integer `-1`, expected usize`` for a negative count;
- ``duplicate field `name` `` and ``missing field `name` ``.

As in `serde`, the members are checked in their order, and a missing field
is reported only when no member has an error.

This module ports no code; the messages are those of `serde` 1.0 and of
`serde_json` 1.0, observed on the upstream binary.

Differences from upstream: a floating point number is written in the `ryu`
layout; `serde` writes it with Rust `Display`, which never uses an exponent.
"""

from gql_json.value import JsonDocument, JsonKind, NO_NODE
from gql_mcp.jsonrpc import is_integer_id
from gql_mcp.schema_walker import ryu_text
from gql_json.number import read_float64


struct FieldKind(Equatable, ImplicitlyCopyable):
    """The Rust type of a field of a tool's `Input` struct."""

    var value: UInt8
    """The kind's number."""

    comptime STRING = FieldKind(0)
    """`String`."""
    comptime USIZE = FieldKind(1)
    """`usize`."""
    comptime STRINGS = FieldKind(2)
    """`Vec<String>`."""
    comptime ANY = FieldKind(3)
    """`serde_json::Value`, which takes any value."""

    def __init__(out self, value: UInt8):
        """Make a kind from its number.

        Args:
            value: The number.
        """
        self.value = value

    def is_valid(self) -> Bool:
        """Return whether the kind is one of the four kinds.

        Returns:
            True for the four kinds.
        """
        return self.value <= 3


@fieldwise_init
struct InputField(Copyable, Movable):
    """One field of a tool's `Input` struct."""

    var name: String
    """The JSON key."""
    var kind: FieldKind
    """The Rust type."""
    var required: Bool
    """Whether a missing member is an error; false for `Option` and
    `#[serde(default)]` fields."""


def describe(document: JsonDocument, node: Int) -> String:
    """Return a JSON value as `serde::de::Unexpected` writes it.

    Args:
        document: The document.
        node: The value.

    Returns:
        Such as ``integer `5` `` or `string "x"`.
    """
    var kind = document.kind(node)
    if kind == JsonKind.NULL:
        return String("null")
    if kind == JsonKind.BOOLEAN:
        return "boolean `true`" if document.bool_value(
            node
        ) else "boolean `false`"
    if kind == JsonKind.NUMBER:
        var text = document.text(node)
        if is_integer_id(text):
            return "integer `" + String(text) + "`"
        return (
            "floating point `" + ryu_text(read_float64(text.as_bytes())) + "`"
        )
    if kind == JsonKind.STRING:
        return "string " + _debug_string(document.string_value(node))
    if kind == JsonKind.ARRAY:
        return String("sequence")
    return String("map")


def _debug_string(text: String) -> String:
    """Quote a text as Rust `{:?}` does, for the common escapes."""
    var out = String('"')
    for char in text.codepoint_slices():
        if char == '"':
            out += '\\"'
        elif char == "\\":
            out += "\\\\"
        elif char == "\n":
            out += "\\n"
        elif char == "\r":
            out += "\\r"
        elif char == "\t":
            out += "\\t"
        else:
            out += char
    out += '"'
    return out^


def check_input(
    document: JsonDocument, node: Int, fields: List[InputField]
) raises:
    """Check tool arguments against the fields of an `Input` struct.

    Args:
        document: The document of the request.
        node: The `arguments` object, or `NO_NODE` when the request has none
            or `null`.
        fields: The fields of the struct; other members are allowed.

    Raises:
        Error: With the `serde` message, without the `Invalid input: `
            prefix.
    """
    if node == NO_NODE:
        raise Error("invalid type: null, expected struct Input")
    if document.kind(node) != JsonKind.OBJECT:
        raise Error(
            "invalid type: "
            + describe(document, node)
            + ", expected struct Input"
        )
    var seen = List[Bool](length=len(fields), fill=False)
    var member = document.first(node)
    while member != NO_NODE:
        var index = 0
        while index < len(fields):
            if document.key_equals(member, fields[index].name):
                if seen[index]:
                    raise Error("duplicate field `" + fields[index].name + "`")
                seen[index] = True
                _check_value(document, member, fields[index].kind)
            index += 1
        member = document.next(member)
    var index = 0
    while index < len(fields):
        if fields[index].required and not seen[index]:
            raise Error("missing field `" + fields[index].name + "`")
        index += 1


def _check_value(document: JsonDocument, node: Int, kind: FieldKind) raises:
    """Check one member against the Rust type of its field."""
    var found = document.kind(node)
    if kind == FieldKind.STRING:
        if found != JsonKind.STRING:
            raise Error(_invalid_type(document, node, "a string"))
    elif kind == FieldKind.USIZE:
        if found != JsonKind.NUMBER or not is_integer_id(document.text(node)):
            raise Error(_invalid_type(document, node, "usize"))
        if document.text(node).startswith("-"):
            raise Error(
                "invalid value: "
                + describe(document, node)
                + ", expected usize"
            )
    elif kind == FieldKind.STRINGS:
        if found != JsonKind.ARRAY:
            raise Error(_invalid_type(document, node, "a sequence"))
        var item = document.first(node)
        while item != NO_NODE:
            _check_value(document, item, FieldKind.STRING)
            item = document.next(item)


def _invalid_type(
    document: JsonDocument, node: Int, expected: StaticString
) -> String:
    """Return the `invalid type` message of a value."""
    return (
        "invalid type: " + describe(document, node) + ", expected " + expected
    )

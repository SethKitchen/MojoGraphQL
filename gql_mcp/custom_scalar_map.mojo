# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The JSON Schemas of custom scalars, from a configuration file.

Port of Apollo MCP Server 2.0.0 (04e4e6e)
`crates/apollo-mcp-server/src/custom_scalar_map.rs`.

The file is a JSON object. Each member names a custom scalar, and its
value is the JSON Schema of the scalar. An empty map behaves as the
upstream `None`.

Differences from upstream:

- A JSON syntax error has the message of `gql_json`, not of `serde_json`:
  `invalid custom_scalar_config: <gql_json message>`.
- The upstream checks each schema against the JSON Schema meta-schema with
  the `jsonschema` crate. This module checks the part that the upstream
  tests exercise: a schema is an object or a boolean, and each `type` is
  a simple type name or an array of them, in the schema and in its
  subschemas. The message is the `jsonschema` message for that case.
"""

from gql_json.parser import parse
from gql_json.value import JsonKind
from gql_mcp.json_tree import JsonTree
from std.pathlib import Path


struct CustomScalarMap(Copyable, Movable):
    """The JSON Schema of each custom scalar, by name."""

    var tree: JsonTree
    """The schemas; `tree.root` is an object of name to schema."""

    def __init__(out self):
        """Make an empty map."""
        self.tree = JsonTree()
        self.tree.root = self.tree.add_object()

    @staticmethod
    def parse(text: StringSlice) raises -> CustomScalarMap:
        """Read a map from JSON text, as upstream `FromStr`.

        Args:
            text: The JSON text: an object of name to JSON Schema.

        Returns:
            The map.

        Raises:
            Error: `invalid custom_scalar_config: ...` for text that is not
                a JSON object, and `invalid json schema: ...` for a value
                that is not a valid JSON Schema.
        """
        var map = CustomScalarMap()
        try:
            var document = parse(text)
            map.tree.root = map.tree.add_document(document, document.root)
        except e:
            raise Error("invalid custom_scalar_config: ", e)
        if map.tree.kind(map.tree.root) != JsonKind.OBJECT:
            raise Error(
                "invalid custom_scalar_config: invalid type: expected a map"
            )
        var index = 0
        while index < map.tree.length(map.tree.root):
            _check(map.tree, map.tree.item(map.tree.root, index))
            index += 1
        return map^

    @staticmethod
    def load(path: String) raises -> CustomScalarMap:
        """Read a map from a file, as upstream `TryFrom<&PathBuf>`.

        Args:
            path: The file's path.

        Returns:
            The map.

        Raises:
            Error: When the file cannot be read, or as `parse` does.
        """
        return CustomScalarMap.parse(Path(path).read_text())

    def get(self, name: StringSlice) -> Int:
        """Return the schema of a custom scalar.

        Args:
            name: The scalar's name.

        Returns:
            The schema's node in `tree`, or `NO_NODE`.
        """
        return self.tree.find(self.tree.root, name)


def _check(tree: JsonTree, schema: Int) raises:
    """Check the `type` keywords of a schema and of its subschemas."""
    var stack = List[Int]()
    stack.append(schema)
    while len(stack) > 0:
        var node = stack.pop()
        var kind = tree.kind(node)
        if kind == JsonKind.BOOLEAN:
            continue
        if kind != JsonKind.OBJECT:
            raise Error(
                "invalid json schema: ",
                tree.to_string(node),
                ' is not of types "boolean", "object"',
            )
        var index = 0
        while index < tree.length(node):
            var key = tree.key(node, index)
            var value = tree.item(node, index)
            if key == "type":
                _check_type(tree, value)
            elif _has_subschemas(key) or (
                key == "items" and tree.kind(value) == JsonKind.ARRAY
            ):
                _push_members(tree, value, stack)
            elif _is_subschema(key):
                stack.append(value)
            index += 1


def _has_subschemas(key: String) -> Bool:
    """Whether a keyword holds an object or an array of schemas."""
    return (
        key == "properties"
        or key == "patternProperties"
        or key == "definitions"
        or key == "$defs"
        or key == "allOf"
        or key == "anyOf"
        or key == "oneOf"
    )


def _is_subschema(key: String) -> Bool:
    """Whether a keyword holds one schema."""
    return (
        key == "items"
        or key == "not"
        or key == "additionalProperties"
        or key == "additionalItems"
        or key == "contains"
        or key == "propertyNames"
        or key == "if"
        or key == "then"
        or key == "else"
    )


def _check_type(tree: JsonTree, value: Int) raises:
    """Check a `type` keyword: a simple type name or an array of them."""
    var valid = _is_simple_type(tree, value)
    if tree.kind(value) == JsonKind.ARRAY:
        valid = True
        var index = 0
        while index < tree.length(value):
            if not _is_simple_type(tree, tree.item(value, index)):
                valid = False
            index += 1
    if not valid:
        raise Error(
            "invalid json schema: ",
            tree.to_string(value),
            " is not valid under any of the schemas listed in the 'anyOf'",
            " keyword",
        )


def _is_simple_type(tree: JsonTree, value: Int) -> Bool:
    """Whether a value is one of the seven simple type names."""
    if tree.kind(value) != JsonKind.STRING:
        return False
    var name = tree.text(value)
    return (
        name == "array"
        or name == "boolean"
        or name == "integer"
        or name == "null"
        or name == "number"
        or name == "object"
        or name == "string"
    )


def _push_members(tree: JsonTree, node: Int, mut stack: List[Int]):
    """Push the values of an object, or the items of an array."""
    var index = 0
    while index < tree.length(node):
        stack.append(tree.item(node, index))
        index += 1

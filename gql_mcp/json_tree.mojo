# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A mutable JSON tree for the JSON Schemas and messages of the MCP server.

Apollo MCP Server builds its JSON Schemas with `serde_json::Map`, with the
`preserve_order` feature: an object keeps the order of insertion, and an
insert of a key that is there already replaces the value in its place.
`JsonTree` behaves the same. A `gql_json.JsonDocument` cannot replace a
member, so the server keeps its schemas here.

Each value is a `TreeNode` in one arena, named by its index. An object
keeps its keys and its values in two parallel lists. A string keeps its
decoded text, and a number keeps its JSON text.

`order_schema` applies the keyword order of `schemars` 1.2 `Schema`
serialization, which the upstream applies when it turns a schema into a
`serde_json::Value`.

This module ports no code.

Differences from upstream: none; `serde_json` is the upstream, and this
module has only the part of its API that the server uses.
"""

from gql_json.value import JsonDocument, JsonKind, NO_NODE
from gql_json.writer import JsonWriter


struct TreeNode(Copyable, Movable):
    """One JSON value of a `JsonTree`."""

    var kind: JsonKind
    """The kind of the value."""
    var text: String
    """The decoded string, the number text, or `true` or `false`."""
    var keys: List[String]
    """The keys of an object, in order."""
    var items: List[Int]
    """The items of an array, or the values of an object, in order."""

    def __init__(out self, kind: JsonKind, var text: String):
        """Make a value without children.

        Args:
            kind: The kind of the value.
            text: The stored text.
        """
        self.kind = kind
        self.text = text^
        self.keys = List[String]()
        self.items = List[Int]()


struct JsonTree(Copyable, Movable):
    """An arena of JSON values that a program can change."""

    var nodes: List[TreeNode]
    """Every value; an index names a value."""
    var root: Int
    """The root value, or `NO_NODE`."""

    def __init__(out self):
        """Make an empty tree."""
        self.nodes = List[TreeNode]()
        self.root = NO_NODE

    def _add(mut self, kind: JsonKind, var text: String) -> Int:
        """Add a value and return its index."""
        self.nodes.append(TreeNode(kind, text^))
        return len(self.nodes) - 1

    def add_null(mut self) -> Int:
        """Add `null`.

        Returns:
            The new value's index.
        """
        return self._add(JsonKind.NULL, String())

    def add_bool(mut self, value: Bool) -> Int:
        """Add `true` or `false`.

        Args:
            value: The value.

        Returns:
            The new value's index.
        """
        return self._add(JsonKind.BOOLEAN, String("true" if value else "false"))

    def add_int(mut self, value: Int) -> Int:
        """Add an integer.

        Args:
            value: The value.

        Returns:
            The new value's index.
        """
        return self._add(JsonKind.NUMBER, String(value))

    def add_number(mut self, text: StringSlice) -> Int:
        """Add a number from its JSON text, which the tree does not check.

        Args:
            text: The JSON text of the number.

        Returns:
            The new value's index.
        """
        return self._add(JsonKind.NUMBER, String(text))

    def add_string(mut self, text: StringSlice) -> Int:
        """Add a string.

        Args:
            text: The decoded value.

        Returns:
            The new value's index.
        """
        return self._add(JsonKind.STRING, String(text))

    def add_array(mut self) -> Int:
        """Add an empty array.

        Returns:
            The new value's index.
        """
        return self._add(JsonKind.ARRAY, String())

    def add_object(mut self) -> Int:
        """Add an empty object.

        Returns:
            The new value's index.
        """
        return self._add(JsonKind.OBJECT, String())

    def kind(self, node: Int) -> JsonKind:
        """Return the kind of a value.

        Args:
            node: A value's index.

        Returns:
            The kind.
        """
        return self.nodes[node].kind

    def text(self, node: Int) -> String:
        """Return the stored text of a scalar.

        Args:
            node: A value's index.

        Returns:
            The decoded string, the number text, `true`, `false`, or empty.
        """
        return self.nodes[node].text.copy()

    def length(self, node: Int) -> Int:
        """Return the number of items or members of a value.

        Args:
            node: A value's index.

        Returns:
            The count; 0 for a scalar.
        """
        return len(self.nodes[node].items)

    def item(self, node: Int, index: Int) -> Int:
        """Return an item of an array, or the value of a member.

        Args:
            node: An array's or an object's index.
            index: The position, from 0.

        Returns:
            The child's index.
        """
        return self.nodes[node].items[index]

    def key(self, node: Int, index: Int) -> String:
        """Return the key of a member.

        Args:
            node: An object's index.
            index: The position, from 0.

        Returns:
            The key.
        """
        return self.nodes[node].keys[index].copy()

    def position(self, node: Int, key: StringSlice) -> Int:
        """Return the position of a member.

        Args:
            node: An object's index.
            key: The key.

        Returns:
            The position, or -1 when the object has no member with the key.
        """
        ref keys = self.nodes[node].keys
        var index = 0
        while index < len(keys):
            if keys[index] == key:
                return index
            index += 1
        return -1

    def find(self, node: Int, key: StringSlice) -> Int:
        """Return the value of a member.

        Args:
            node: An object's index.
            key: The key.

        Returns:
            The value's index, or `NO_NODE`.
        """
        var index = self.position(node, key)
        if index < 0:
            return NO_NODE
        return self.nodes[node].items[index]

    def set(mut self, node: Int, key: StringSlice, child: Int):
        """Set a member, as `IndexMap::insert`: a new key goes last, and an
        old key keeps its place.

        Args:
            node: An object's index.
            key: The key.
            child: The new value's index.
        """
        var index = self.position(node, key)
        if index < 0:
            self.nodes[node].keys.append(String(key))
            self.nodes[node].items.append(child)
        else:
            self.nodes[node].items[index] = child

    def entry(mut self, node: Int, key: StringSlice, default: Int) -> Int:
        """Return the value of a member, and add it first when it is not
        there, as `entry(key).or_insert(default)`.

        Args:
            node: An object's index.
            key: The key.
            default: The value to add when the key is not there.

        Returns:
            The value's index.
        """
        var found = self.find(node, key)
        if found != NO_NODE:
            return found
        self.set(node, key, default)
        return default

    def push(mut self, node: Int, child: Int):
        """Make a value the last item of an array.

        Args:
            node: An array's index.
            child: The item's index.
        """
        self.nodes[node].items.append(child)

    def copy_from(mut self, other: JsonTree, node: Int) -> Int:
        """Copy a value and its descendants from another tree.

        Args:
            other: The tree to copy from.
            node: The value's index in `other`.

        Returns:
            The copy's index in this tree.
        """
        var top = self._add(
            other.nodes[node].kind, other.nodes[node].text.copy()
        )
        var sources = List[Int]()
        sources.append(node)
        var targets = List[Int]()
        targets.append(top)
        while len(sources) > 0:
            var source = sources.pop()
            var target = targets.pop()
            ref from_node = other.nodes[source]
            self.nodes[target].keys = from_node.keys.copy()
            for child in from_node.items:
                var copy = self._add(
                    other.nodes[child].kind, other.nodes[child].text.copy()
                )
                self.nodes[target].items.append(copy)
                sources.append(child)
                targets.append(copy)
        return top

    def add_document(mut self, document: JsonDocument, node: Int) -> Int:
        """Copy a value and its descendants from a parsed JSON document.

        Args:
            document: The document.
            node: The value's index in the document.

        Returns:
            The copy's index in this tree.
        """
        var top = self._add_from(document, node)
        var sources = List[Int]()
        sources.append(node)
        var targets = List[Int]()
        targets.append(top)
        while len(sources) > 0:
            var source = sources.pop()
            var target = targets.pop()
            var is_object = document.kind(source) == JsonKind.OBJECT
            var child = document.first(source)
            while child != NO_NODE:
                var copy = self._add_from(document, child)
                if is_object:
                    self.set(target, document.key(child), copy)
                else:
                    self.nodes[target].items.append(copy)
                sources.append(child)
                targets.append(copy)
                child = document.next(child)
        return top

    def _add_from(mut self, document: JsonDocument, node: Int) -> Int:
        """Add a value without children from a document."""
        var kind = document.kind(node)
        if kind == JsonKind.STRING:
            return self.add_string(document.string_value(node))
        if kind == JsonKind.BOOLEAN:
            return self.add_bool(document.bool_value(node))
        if kind == JsonKind.NUMBER:
            return self.add_number(document.text(node))
        return self._add(kind, String())

    def equals(self, node: Int, other: JsonTree, other_node: Int) -> Bool:
        """Return whether two values are equal, as `serde_json::Value`
        equality: members in any order, numbers by their text.

        Args:
            node: A value's index in this tree.
            other: The other tree.
            other_node: A value's index in `other`.

        Returns:
            Whether the values are equal.
        """
        var left = List[Int]()
        left.append(node)
        var right = List[Int]()
        right.append(other_node)
        while len(left) > 0:
            ref a = self.nodes[left.pop()]
            ref b = other.nodes[right.pop()]
            if a.kind != b.kind or a.text != b.text:
                return False
            if len(a.items) != len(b.items):
                return False
            var index = 0
            while index < len(a.items):
                left.append(a.items[index])
                if a.kind == JsonKind.OBJECT:
                    var at = _position(b.keys, a.keys[index])
                    if at < 0:
                        return False
                    right.append(b.items[at])
                else:
                    right.append(b.items[index])
                index += 1
        return True

    def write(self, mut writer: JsonWriter, node: Int):
        """Write a value and its descendants, members in their order.

        Args:
            writer: The writer.
            node: The value's index.
        """
        var stack = List[Int]()
        stack.append(node)
        var next = List[Int]()
        next.append(-1)
        while len(stack) > 0:
            var top = stack[len(stack) - 1]
            ref value = self.nodes[top]
            var index = next[len(next) - 1]
            if index == -1:
                if value.kind == JsonKind.OBJECT:
                    writer.begin_object()
                elif value.kind == JsonKind.ARRAY:
                    writer.begin_array()
                else:
                    _write_scalar(writer, value)
                    _ = stack.pop()
                    _ = next.pop()
                    continue
                index = 0
            if index == len(value.items):
                if value.kind == JsonKind.OBJECT:
                    writer.end_object()
                else:
                    writer.end_array()
                _ = stack.pop()
                _ = next.pop()
                continue
            if value.kind == JsonKind.OBJECT:
                writer.key(value.keys[index])
            next[len(next) - 1] = index + 1
            stack.append(value.items[index])
            next.append(-1)

    def to_string(self, node: Int, indent: Int = 0) -> String:
        """Return the JSON text of a value.

        Args:
            node: The value's index.
            indent: The spaces for each level; 2 gives the text of
                `serde_json::to_string_pretty`.

        Returns:
            The text.
        """
        var writer = JsonWriter(indent)
        self.write(writer, node)
        return writer^.take_string()

    def order_schema(mut self, node: Int):
        """Order the keywords of a JSON Schema and of its subschemas, as
        `schemars` serializes a `Schema`.

        `$id`, `$schema`, `title`, `description`, `type`, `format` and
        `properties` come first, `$defs` and `definitions` last, and the
        other keys keep their order. The values of `default`, `examples` and
        `x-` keys do not change. The members of `properties`,
        `patternProperties`, `dependentSchemas`, `$defs` and `definitions`
        keep their order, and each of their values is a schema.

        Args:
            node: The schema's index.
        """
        var stack = List[Int]()
        stack.append(node)
        var maps = List[Bool]()
        maps.append(False)
        while len(stack) > 0:
            var top = stack.pop()
            var is_map = maps.pop()
            if self.nodes[top].kind == JsonKind.OBJECT and not is_map:
                _reorder(self.nodes[top])
            ref value = self.nodes[top]
            var index = 0
            while index < len(value.items):
                var key = String()
                if value.kind == JsonKind.OBJECT and not is_map:
                    key = value.keys[index].copy()
                if not _is_plain_value(key):
                    stack.append(value.items[index])
                    maps.append(_is_schema_map(key))
                index += 1


def _position(keys: List[String], key: String) -> Int:
    """Return the position of a key, or -1."""
    var index = 0
    while index < len(keys):
        if keys[index] == key:
            return index
        index += 1
    return -1


def _write_scalar(mut writer: JsonWriter, value: TreeNode):
    """Write a value that has no children."""
    if value.kind == JsonKind.STRING:
        writer.string(value.text)
    elif value.kind == JsonKind.NULL:
        writer.null()
    else:
        writer.raw(value.text)


def _is_plain_value(key: String) -> Bool:
    """Whether `schemars` writes the value of a key without reordering."""
    return key == "default" or key == "examples" or key.startswith("x-")


def _is_schema_map(key: String) -> Bool:
    """Whether the value of a key is a map of schemas."""
    return (
        key == "properties"
        or key == "patternProperties"
        or key == "dependentSchemas"
        or key == "$defs"
        or key == "definitions"
    )


def _rank(key: String) -> Int:
    """The place of a keyword: 0 to 6 first, 7 in order, 8 and 9 last."""
    if key == "$id":
        return 0
    if key == "$schema":
        return 1
    if key == "title":
        return 2
    if key == "description":
        return 3
    if key == "type":
        return 4
    if key == "format":
        return 5
    if key == "properties":
        return 6
    if key == "$defs":
        return 8
    if key == "definitions":
        return 9
    return 7


def _reorder(mut value: TreeNode):
    """Order the members of a schema object by `_rank`, stably."""
    var ranks = List[Int](capacity=len(value.keys))
    var sorted = True
    var index = 0
    while index < len(value.keys):
        ranks.append(_rank(value.keys[index]))
        if index > 0 and ranks[index] < ranks[index - 1]:
            sorted = False
        index += 1
    if sorted:
        return
    var keys = List[String](capacity=len(ranks))
    var items = List[Int](capacity=len(ranks))
    var rank = 0
    while rank < 10:
        index = 0
        while index < len(ranks):
            if ranks[index] == rank:
                keys.append(value.keys[index].copy())
                items.append(value.items[index])
            index += 1
        rank += 1
    value.keys = keys^
    value.items = items^

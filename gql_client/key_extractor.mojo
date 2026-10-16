# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Key specifiers: the `keyFields` and `keyArgs` arrays of a policy.

Port of Apollo Client 4.3.3 `src/cache/inmemory/key-extractor.ts`.

A key specifier is an array of names, in which an array after a name holds
the names inside that name. `["title", "author", ["name"]]` names the paths
`title` and `author.name`. `KeySpecifier.parse` reads the specifier from
its JSON text, so the text is the same as the upstream array literal.

| Function | Upstream |
| --- | --- |
| `KeySpecifier.parse`, `KeySpecifier.paths` | `getSpecifierPaths` |
| `collect_specifier_paths` | `collectSpecifierPaths` |
| `extract_key_path` | `extractKeyPath` |
| `normalize` | `normalize` |

`keyFieldsFnFromSpecifier` and `keyArgsFnFromSpecifier` read the store,
so they are in `gql_client.policies`.

Differences from upstream:

- A specifier is JSON text, or a list of dotted paths, not a JavaScript
  array. `KeySpecifier.parse` refuses an item that is not a string or an
  array.
"""

from gql_json.parser import parse
from gql_json.value import JsonDocument, JsonKind, NO_NODE
from gql_client.values import Member, NO_VALUE, ValueKind, Values


struct KeySpecifier(Copyable, Movable):
    """The paths of a `keyFields` or `keyArgs` specifier."""

    var paths: List[List[String]]
    """Each path, as a list of names, in specifier order."""
    var text: String
    """The specifier's JSON text, as `JSON.stringify(specifier)` gives it."""

    def __init__(out self):
        """Make an empty specifier, `[]`."""
        self.paths = List[List[String]]()
        self.text = "[]"

    @staticmethod
    def parse(text: StringSlice) raises -> KeySpecifier:
        """Read a specifier from its JSON text.

        Args:
            text: A JSON array, such as `["id", "author", ["name"]]`.

        Returns:
            The specifier.

        Raises:
            Error: If the text is not a JSON array of names and arrays.
        """
        var document: JsonDocument
        try:
            document = parse(text)
        except e:
            raise Error(String("Invalid key specifier: ", e))
        var out = KeySpecifier()
        if document.kind(document.root) != JsonKind.ARRAY:
            raise Error("A key specifier must be an array")
        var prefix = List[String]()
        _collect_paths(document, document.root, prefix, out.paths)
        out.text = _compact(document)
        return out^

    @staticmethod
    def from_paths(paths: List[String]) raises -> KeySpecifier:
        """Make a specifier from dotted paths.

        `["title", "author.name"]` is the specifier
        `["title", "author", ["name"]]`.

        Args:
            paths: The paths; each name is separated by a `.`.

        Returns:
            The specifier.

        Raises:
            Error: If a path has an empty name.
        """
        var out = KeySpecifier()
        var index = 0
        while index < len(paths):
            var path = List[String]()
            var parts = paths[index].split(".")
            var part = 0
            while part < len(parts):
                if parts[part].byte_length() == 0:
                    raise Error(
                        String("Invalid key specifier path: ", paths[index])
                    )
                path.append(String(parts[part]))
                part += 1
            out.paths.append(path^)
            index += 1
        out.text = _paths_text(out.paths)
        return out^


def _collect_paths(
    document: JsonDocument,
    array: Int,
    prefix: List[String],
    mut paths: List[List[String]],
) raises:
    """Add the paths of a specifier array, after a prefix of names."""
    var item = document.first(array)
    while item != NO_NODE:
        if document.kind(item) == JsonKind.ARRAY:
            # An array that follows no name adds its paths as they are.
            _collect_paths(document, item, prefix, paths)
            item = document.next(item)
            continue
        if document.kind(item) != JsonKind.STRING:
            raise Error("A key specifier holds only names and arrays")
        var name = document.string_value(item)
        var next = document.next(item)
        if next != NO_NODE and document.kind(next) == JsonKind.ARRAY:
            var inner = prefix.copy()
            inner.append(name)
            _collect_paths(document, next, inner, paths)
            next = document.next(next)
        else:
            var path = prefix.copy()
            path.append(name)
            paths.append(path^)
        item = next


def _compact(document: JsonDocument) -> String:
    """Return the compact JSON text of a parsed specifier."""
    from gql_json.writer import stringify

    return stringify(document, document.root)


def _paths_text(paths: List[List[String]]) -> String:
    """Return the specifier array text of a list of paths."""
    var document = JsonDocument()
    document.root = document.add_array()
    var index = 0
    while index < len(paths):
        _append_path(document, document.root, paths[index], 0)
        index += 1
    return _compact(document)


def _append_path(
    mut document: JsonDocument, array: Int, path: List[String], start: Int
):
    """Add one path to a specifier array, as a name and nested arrays."""
    document.append(array, document.add_string(path[start]))
    if start + 1 < len(path):
        var inner = document.add_array()
        _append_path(document, inner, path, start + 1)
        document.append(array, inner)


def collect_specifier_paths(
    mut values: Values, paths: List[List[String]], extracted: List[Int]
) -> Int:
    """Return the object that some extracted path values make.

    Port of `collectSpecifierPaths`: the value of each path goes in nested
    objects, which merge with a deep merge. A path whose value is
    `NO_VALUE` is left out.

    Args:
        values: The arena.
        paths: The paths.
        extracted: The value of each path, or `NO_VALUE`.

    Returns:
        The new object.
    """
    var collected = values.add_object(List[Member]())
    var index = 0
    while index < len(paths):
        var value = extracted[index]
        if value != NO_VALUE:
            ref path = paths[index]
            var depth = len(path) - 1
            while depth >= 0:
                var members = List[Member]()
                members.append(
                    Member(
                        Int32(values.names.intern(path[depth])), Int32(value)
                    )
                )
                value = values.add_object(members)
                depth -= 1
            collected = values.merge(collected, value)
        index += 1
    return collected


def extract_key_path(
    mut values: Values, object: Int, path: List[String]
) -> Int:
    """Return the normalized value at a path of an object.

    Port of `extractKeyPath` with the plain `extractKey`: an array maps
    each item through the rest of the path.

    Args:
        values: The arena.
        object: The object.
        path: The names.

    Returns:
        The value, normalized, or `NO_VALUE`.
    """
    return normalize(values, _reduce_path(values, object, path, 0))


def _reduce_path(
    mut values: Values, object: Int, path: List[String], start: Int
) -> Int:
    """Follow a path from a position; map an array item by item."""
    var current = object
    var position = start
    while position < len(path):
        if values.is_array(current):
            var items = List[Int]()
            var index = 0
            while index < values.length(current):
                items.append(
                    _reduce_path(
                        values, values.item(current, index), path, position
                    )
                )
                index += 1
            return values.add_array(items)
        if not values.truthy(current):
            return current
        current = values.get(current, path[position])
        position += 1
    return current


def normalize(mut values: Values, value: Int) -> Int:
    """Return a value whose objects have their keys sorted.

    Port of the key-extractor `normalize`.

    Args:
        values: The arena.
        value: The value.

    Returns:
        The normalized value, or `value` when it is not an object.
    """
    var kind = values.kind(value)
    if kind == ValueKind.ARRAY:
        var items = List[Int]()
        var index = 0
        while index < values.length(value):
            items.append(normalize(values, values.item(value, index)))
            index += 1
        return values.add_array(items)
    if kind != ValueKind.OBJECT:
        return value
    var order = values.sorted_members(value)
    var members = List[Member]()
    var index = 0
    while index < len(order):
        var inner = values.member_value(value, order[index])
        if not values.is_undefined(inner):
            members.append(
                Member(
                    Int32(values.member_name(value, order[index])),
                    Int32(normalize(values, inner)),
                )
            )
        index += 1
    return values.add_object(members)

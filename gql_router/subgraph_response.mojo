# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Read a GraphQL response from a subgraph.

Port of `SubgraphResponse` in Hive Router `1a29df9`
`bin/router/src/executor/response/subgraph_response.rs`.

The object may hold `data`, `errors`, and `extensions`. Any other field
is ignored. Missing `data` is null. Null `data` with no `errors` is
malformed. A custom-scalar path keeps the original JSON text of that
value, including escapes. An array uses the same path for each item.

**Differences from upstream.** Headers, the status code, and the raw
body bytes are not stored. The caller passes the response text.
"""

from gql_json.parser import parse
from gql_json.value import NO_NODE, JsonDocument, JsonKind, number_end
from gql_json.writer import stringify
from gql_router.graphql_error import (
    ErrorPath,
    ErrorSegment,
    GraphQLError,
    field_segment,
    graphql_error,
    index_segment,
)


@fieldwise_init
struct _Read(Copyable, Movable):
    """The end index and node of one parsed value."""

    var end: Int
    """The index after the value."""
    var node: Int
    """The node that holds the value."""


struct CustomScalarPaths(Movable):
    """Field paths whose values stay raw JSON."""

    var parents: List[Int]
    """The parent of each node. The root's parent is `-1`."""
    var names: List[String]
    """The field name of each node. The root name is empty."""
    var terminal: List[Bool]
    """True when the value at that field is raw JSON."""

    def __init__(out self):
        """Start an empty path set."""
        self.parents = List[Int]()
        self.names = List[String]()
        self.terminal = List[Bool]()
        self.parents.append(-1)
        self.names.append(String(""))
        self.terminal.append(False)

    def insert_path(mut self, segments: List[String]):
        """Mark the value at a field path as raw JSON.

        Args:
            segments: The field names, from the data root.
        """
        var node = 0
        for index in range(len(segments)):
            var child = _child_of(self, node, segments[index])
            if child < 0:
                child = len(self.parents)
                self.parents.append(node)
                self.names.append(String(segments[index]))
                self.terminal.append(False)
            node = child
        self.terminal[node] = True

    def is_empty(self) -> Bool:
        """Return True when no path is marked.

        Returns:
            Whether the root has no children and is not terminal.
        """
        return (
            not self.terminal[0]
            and _child_of(self, 0, String("")) < 0
            and not _has_child(self, 0)
        )


struct SubgraphResponse(Movable):
    """One GraphQL response body."""

    var data: JsonDocument
    """The `data` value. Null when `data` is absent."""
    var raw_nodes: List[Int]
    """Nodes in `data` whose text is original JSON."""
    var raw_text: List[String]
    """That JSON, parallel to `raw_nodes`."""
    var errors: List[GraphQLError]
    """The `errors` array. Empty when the field is absent."""
    var has_errors: Bool
    """True when the response has an `errors` field."""
    var extensions: JsonDocument
    """The `extensions` value."""
    var has_extensions: Bool
    """True when the response has an `extensions` field."""

    def __init__(out self):
        """Start an empty response whose data is null."""
        self.data = JsonDocument()
        self.data.root = self.data.add_null()
        self.raw_nodes = List[Int]()
        self.raw_text = List[String]()
        self.errors = List[GraphQLError]()
        self.has_errors = False
        self.extensions = JsonDocument()
        self.has_extensions = False

    def append_error(mut self, var error: GraphQLError):
        """Add one error.

        Args:
            error: The error to add.
        """
        self.has_errors = True
        self.errors.append(error^)


def raw_text_at(response: SubgraphResponse, node: Int) -> String:
    """Return the original JSON of a custom-scalar value.

    Args:
        response: The response.
        node: A node in `response.data`.

    Returns:
        The original JSON. Empty when the node is structured.
    """
    for index in range(len(response.raw_nodes)):
        if response.raw_nodes[index] == node:
            return String(response.raw_text[index])
    return String("")


def read_subgraph_response(
    text: String, paths: CustomScalarPaths
) raises -> SubgraphResponse:
    """Read a subgraph response.

    Args:
        text: The response JSON.
        paths: Field paths that stay raw JSON. An empty set parses every
            value.

    Returns:
        The data, errors, and extensions.

    Raises:
        Error: When the JSON is invalid, a field is repeated, trailing
            text remains, or `data` is null and `errors` is absent.
    """
    var response = SubgraphResponse()
    var index = _space(text, 0)
    if not _is(text, index, 123):
        raise Error(
            "Failed to deserialize subgraph response: expected an object"
        )
    index += 1
    var saw_data = False
    var saw_errors = False
    var saw_extensions = False
    index = _space(text, index)
    if not _is(text, index, 125):
        while True:
            var key = String("")
            index = _read_string(text, index, key)
            index = _space(text, index)
            if not _is(text, index, 58):
                raise Error(
                    "Failed to deserialize subgraph response: expected ':'"
                )
            index = _space(text, index + 1)
            if key == "data":
                if saw_data:
                    raise Error("duplicate field `data`")
                saw_data = True
                index = _read_data(text, index, paths, 0, response)
            elif key == "errors":
                if saw_errors:
                    raise Error("duplicate field `errors`")
                saw_errors = True
                index = _read_errors(text, index, response)
            elif key == "extensions":
                if saw_extensions:
                    raise Error("duplicate field `extensions`")
                saw_extensions = True
                index = _read_extensions(text, index, response)
            else:
                index = _skip_value(text, index)
            index = _space(text, index)
            if _is(text, index, 125):
                break
            if not _is(text, index, 44):
                raise Error(
                    "Failed to deserialize subgraph response: expected ','"
                )
            index = _space(text, index + 1)
    if not _is(text, index, 125):
        raise Error("Failed to deserialize subgraph response: expected '}'")
    index = _space(text, index + 1)
    if index < text.byte_length():
        raise Error("Failed to deserialize subgraph response: trailing data")
    response.has_errors = saw_errors
    if not saw_data:
        response.data.root = response.data.add_null()
    if (
        response.data.kind(response.data.root) == JsonKind.NULL
        and not saw_errors
    ):
        raise Error("Subgraph returned malformed response")
    return response^


def _read_data(
    text: String,
    index: Int,
    paths: CustomScalarPaths,
    node: Int,
    mut response: SubgraphResponse,
) raises -> Int:
    """Read the `data` value.

    Args:
        text: The response JSON.
        index: The first byte of the value.
        paths: The custom-scalar paths.
        node: The path node. `0` is the root.
        response: The response being filled.

    Returns:
        The index after the value.

    Raises:
        Error: When the value is not JSON.
    """
    var raw_nodes = List[Int]()
    var raw_text = List[String]()
    var placed = _read_placed(
        text,
        index,
        paths,
        node,
        response.data,
        -1,
        String(""),
        False,
        raw_nodes,
        raw_text,
    )
    response.data.root = placed.node
    response.raw_nodes = raw_nodes^
    response.raw_text = raw_text^
    return placed.end


def _read_placed(
    text: String,
    index: Int,
    paths: CustomScalarPaths,
    node: Int,
    mut document: JsonDocument,
    parent: Int,
    key: String,
    member: Bool,
    mut raw_nodes: List[Int],
    mut raw_text: List[String],
) raises -> _Read:
    """Read one JSON value and attach it.

    Args:
        text: The response JSON.
        index: The first byte of the value.
        paths: The custom-scalar paths.
        node: The path node. Negative when the value is structured.
        document: The document that receives the value.
        parent: The parent node. Negative for a root value.
        key: The object key. Empty for an array item.
        member: True when `parent` is an object.
        raw_nodes: Nodes whose text is original JSON.
        raw_text: That JSON, parallel to `raw_nodes`.

    Returns:
        The index after the value, and the new node.

    Raises:
        Error: When the value is not JSON.
    """
    var at = _space(text, index)
    if node >= 0 and paths.terminal[node]:
        var end = _skip_value(text, at)
        var raw = _slice(text, at, end)
        var child = document.add_string(raw)
        _attach(document, parent, key, member, child)
        raw_nodes.append(child)
        raw_text.append(raw)
        return _Read(end, child)
    if node < 0 or _node_empty(paths, node):
        var end = _skip_value(text, at)
        var child = _parsed(document, _slice(text, at, end))
        _attach(document, parent, key, member, child)
        return _Read(end, child)
    if _is(text, at, 91):
        return _read_array(
            text,
            at,
            paths,
            node,
            document,
            parent,
            key,
            member,
            raw_nodes,
            raw_text,
        )
    if _is(text, at, 123):
        return _read_object(
            text,
            at,
            paths,
            node,
            document,
            parent,
            key,
            member,
            raw_nodes,
            raw_text,
        )
    var end = _skip_value(text, at)
    var child = _parsed(document, _slice(text, at, end))
    _attach(document, parent, key, member, child)
    return _Read(end, child)


def _read_array(
    text: String,
    index: Int,
    paths: CustomScalarPaths,
    node: Int,
    mut document: JsonDocument,
    parent: Int,
    key: String,
    member: Bool,
    mut raw_nodes: List[Int],
    mut raw_text: List[String],
) raises -> _Read:
    """Read a JSON array. Each item uses the same path.

    Args:
        text: The response JSON.
        index: The `[` byte.
        paths: The custom-scalar paths.
        node: The path node for every item.
        document: The document that receives the array.
        parent: The parent node.
        key: The object key.
        member: True when `parent` is an object.
        raw_nodes: Nodes whose text is original JSON.
        raw_text: That JSON, parallel to `raw_nodes`.

    Returns:
        The index after the array, and the array node.

    Raises:
        Error: When the array is not valid JSON.
    """
    var array = document.add_array()
    _attach(document, parent, key, member, array)
    var cursor = _space(text, index + 1)
    if _is(text, cursor, 93):
        return _Read(cursor + 1, array)
    while True:
        var placed = _read_placed(
            text,
            cursor,
            paths,
            node,
            document,
            array,
            String(""),
            False,
            raw_nodes,
            raw_text,
        )
        cursor = _space(text, placed.end)
        if _is(text, cursor, 93):
            return _Read(cursor + 1, array)
        if not _is(text, cursor, 44):
            raise Error("Failed to deserialize subgraph response: expected ','")
        cursor = _space(text, cursor + 1)


def _read_object(
    text: String,
    index: Int,
    paths: CustomScalarPaths,
    node: Int,
    mut document: JsonDocument,
    parent: Int,
    key: String,
    member: Bool,
    mut raw_nodes: List[Int],
    mut raw_text: List[String],
) raises -> _Read:
    """Read a JSON object and follow custom-scalar children.

    Args:
        text: The response JSON.
        index: The `{` byte.
        paths: The custom-scalar paths.
        node: The path node of this object.
        document: The document that receives the object.
        parent: The parent node.
        key: The object key.
        member: True when `parent` is an object.
        raw_nodes: Nodes whose text is original JSON.
        raw_text: That JSON, parallel to `raw_nodes`.

    Returns:
        The index after the object, and the object node.

    Raises:
        Error: When the object is not valid JSON.
    """
    var obj = document.add_object()
    _attach(document, parent, key, member, obj)
    var cursor = _space(text, index + 1)
    if _is(text, cursor, 125):
        return _Read(cursor + 1, obj)
    while True:
        var name = String("")
        cursor = _read_string(text, cursor, name)
        cursor = _space(text, cursor)
        if not _is(text, cursor, 58):
            raise Error("Failed to deserialize subgraph response: expected ':'")
        cursor = _space(text, cursor + 1)
        var child_path = _child_of(paths, node, name)
        var placed = _read_placed(
            text,
            cursor,
            paths,
            child_path,
            document,
            obj,
            name,
            True,
            raw_nodes,
            raw_text,
        )
        cursor = _space(text, placed.end)
        if _is(text, cursor, 125):
            return _Read(cursor + 1, obj)
        if not _is(text, cursor, 44):
            raise Error("Failed to deserialize subgraph response: expected ','")
        cursor = _space(text, cursor + 1)


def _read_errors(
    text: String, index: Int, mut response: SubgraphResponse
) raises -> Int:
    """Read the `errors` array.

    Args:
        text: The response JSON.
        index: The first byte of the value.
        response: The response being filled.

    Returns:
        The index after the value.

    Raises:
        Error: When `errors` is not an array of error objects.
    """
    var end = _skip_value(text, index)
    var parsed = _parse(_slice(text, index, end))
    if parsed.kind(parsed.root) != JsonKind.ARRAY:
        raise Error(
            "Failed to deserialize subgraph response: expected errors array"
        )
    var item = parsed.first(parsed.root)
    while item != NO_NODE:
        response.errors.append(_one_error(parsed, item))
        item = parsed.next(item)
    return end


def _one_error(parsed: JsonDocument, node: Int) raises -> GraphQLError:
    """Read one error object.

    Args:
        parsed: The errors document.
        node: The error object.

    Returns:
        The error.

    Raises:
        Error: When `message` is missing.
    """
    if parsed.kind(node) != JsonKind.OBJECT:
        raise Error(
            "Failed to deserialize subgraph response: expected an error object"
        )
    var message_node = parsed.find(node, "message")
    if message_node == NO_NODE or parsed.kind(message_node) != JsonKind.STRING:
        raise Error(
            "Failed to deserialize subgraph response: missing field `message`"
        )
    var error = graphql_error(parsed.string_value(message_node))
    var locations = parsed.find(node, "locations")
    if locations != NO_NODE and parsed.kind(locations) == JsonKind.ARRAY:
        var place = parsed.first(locations)
        while place != NO_NODE:
            var line = parsed.find(place, "line")
            var column = parsed.find(place, "column")
            if line != NO_NODE and column != NO_NODE:
                error.lines.append(Int(parsed.as_int64(line)))
                error.columns.append(Int(parsed.as_int64(column)))
            place = parsed.next(place)
    var path_node = parsed.find(node, "path")
    if path_node != NO_NODE and parsed.kind(path_node) == JsonKind.ARRAY:
        error.has_path = True
        error.path = _error_path(parsed, path_node)
    var extensions = parsed.find(node, "extensions")
    if extensions != NO_NODE and parsed.kind(extensions) == JsonKind.OBJECT:
        _read_extensions_object(parsed, extensions, error)
    return error^


def _error_path(parsed: JsonDocument, node: Int) raises -> ErrorPath:
    """Read a GraphQL error path.

    Args:
        parsed: The errors document.
        node: The path array.

    Returns:
        The path.

    Raises:
        Error: When a step is not a string or a number.
    """
    var segments = List[ErrorSegment]()
    var item = parsed.first(node)
    while item != NO_NODE:
        if parsed.kind(item) == JsonKind.STRING:
            segments.append(field_segment(parsed.string_value(item)))
        elif parsed.kind(item) == JsonKind.NUMBER:
            segments.append(index_segment(Int(parsed.as_int64(item))))
        else:
            raise Error(
                "Failed to deserialize subgraph response: invalid error path"
            )
        item = parsed.next(item)
    return ErrorPath(segments^)


def _read_extensions_object(
    parsed: JsonDocument, node: Int, mut error: GraphQLError
) raises:
    """Copy extension fields onto an error.

    Args:
        parsed: The errors document.
        node: The extensions object.
        error: The error to update.

    Raises:
        Error: When `code`, `service`, or `affectedPath` is not a string.
    """
    var item = parsed.first(node)
    while item != NO_NODE:
        var name = parsed.key(item)
        if name == "code" or name == "service" or name == "affectedPath":
            if parsed.kind(item) != JsonKind.STRING:
                raise Error(
                    "Failed to deserialize subgraph response: expected a string"
                )
            var value = parsed.string_value(item)
            if name == "code":
                error.code = value
            elif name == "service":
                error.service = value
            else:
                error.affected_path = value
        else:
            error.extra_names.append(name)
            error.extra_values.append(stringify(parsed, item))
        item = parsed.next(item)


def _read_extensions(
    text: String, index: Int, mut response: SubgraphResponse
) raises -> Int:
    """Read the `extensions` value.

    Args:
        text: The response JSON.
        index: The first byte of the value.
        response: The response being filled.

    Returns:
        The index after the value.

    Raises:
        Error: When the value is not JSON.
    """
    var end = _skip_value(text, index)
    response.extensions = _parse(_slice(text, index, end))
    response.has_extensions = True
    return end


def _parsed(mut document: JsonDocument, text: String) raises -> Int:
    """Copy a parsed JSON value into `document`.

    Args:
        document: The destination.
        text: One JSON value.

    Returns:
        The copied node.

    Raises:
        Error: When `text` is not JSON.
    """
    var parsed = _parse(text)
    return document.add_copy(parsed, parsed.root)


def _parse(text: String) raises -> JsonDocument:
    """Parse one JSON value.

    Args:
        text: The JSON text.

    Returns:
        The document.

    Raises:
        Error: When the text is not JSON.
    """
    try:
        return parse(text)
    except e:
        raise Error("Failed to deserialize subgraph response: " + e.message)


def _attach(
    mut document: JsonDocument,
    parent: Int,
    key: String,
    member: Bool,
    child: Int,
):
    """Attach a node to its parent.

    Args:
        document: The document.
        parent: The parent node. Negative when `child` is a root.
        key: The object key.
        member: True when `parent` is an object.
        child: The node to attach.
    """
    if parent < 0:
        document.root = child
        return
    if member:
        document.add_member(parent, key, child)
        return
    document.append(parent, child)


def _child_of(paths: CustomScalarPaths, node: Int, name: String) -> Int:
    """Return the child of a path node.

    Args:
        paths: The custom-scalar paths.
        node: The parent node.
        name: The field name. Empty never matches.

    Returns:
        The child index. `-1` when it is absent.
    """
    if name.byte_length() == 0 or node < 0:
        return -1
    for index in range(len(paths.parents)):
        if paths.parents[index] == node and paths.names[index] == name:
            return index
    return -1


def _has_child(paths: CustomScalarPaths, node: Int) -> Bool:
    """Return True when a path node has a child.

    Args:
        paths: The custom-scalar paths.
        node: The parent node.

    Returns:
        Whether a child exists.
    """
    for index in range(len(paths.parents)):
        if paths.parents[index] == node:
            return True
    return False


def _node_empty(paths: CustomScalarPaths, node: Int) -> Bool:
    """Return True when a path node marks nothing.

    Args:
        paths: The custom-scalar paths.
        node: The path node.

    Returns:
        Whether the node is not terminal and has no children.
    """
    if node < 0 or node >= len(paths.terminal):
        return True
    return not paths.terminal[node] and not _has_child(paths, node)


def _skip_value(text: String, index: Int) raises -> Int:
    """Return the index after one JSON value.

    Args:
        text: The JSON text.
        index: The first byte of the value.

    Returns:
        The index after the value.

    Raises:
        Error: When the value is not JSON.
    """
    var at = _space(text, index)
    if at >= text.byte_length():
        raise Error("Failed to deserialize subgraph response: unexpected end")
    var byte = _byte(text, at)
    if byte == 34:
        return _string_end(text, at)
    if byte == 116:
        return _word(text, at, "true")
    if byte == 102:
        return _word(text, at, "false")
    if byte == 110:
        return _word(text, at, "null")
    if byte == 45 or (byte >= 48 and byte <= 57):
        var end = number_end(text.as_bytes(), at)
        if end < 0:
            raise Error(
                "Failed to deserialize subgraph response: invalid number"
            )
        return end
    if byte == 123 or byte == 91:
        return _skip_container(text, at)
    raise Error("Failed to deserialize subgraph response: invalid JSON")


def _skip_container(text: String, index: Int) raises -> Int:
    """Return the index after an object or an array.

    Args:
        text: The JSON text.
        index: The `{` or `[` byte.

    Returns:
        The index after the matching closer.

    Raises:
        Error: When the container does not close.
    """
    var depth = 0
    var cursor = index
    var limit = text.byte_length()
    while cursor < limit:
        var byte = _byte(text, cursor)
        if byte == 34:
            cursor = _string_end(text, cursor)
            continue
        if byte == 123 or byte == 91:
            depth += 1
        elif byte == 125 or byte == 93:
            depth -= 1
            if depth == 0:
                return cursor + 1
        cursor += 1
    raise Error("Failed to deserialize subgraph response: unexpected end")


def _read_string(text: String, index: Int, mut value: String) raises -> Int:
    """Read a JSON string.

    Args:
        text: The JSON text.
        index: The opening quote, after spaces.
        value: The decoded text to fill.

    Returns:
        The index after the closing quote.

    Raises:
        Error: When the string does not close.
    """
    var at = _space(text, index)
    var end = _string_end(text, at)
    value = _decode(text, at + 1, end - 1)
    return end


def _string_end(text: String, index: Int) raises -> Int:
    """Return the index after a JSON string.

    Args:
        text: The JSON text.
        index: The opening quote.

    Returns:
        The index after the closing quote.

    Raises:
        Error: When the string does not start or close.
    """
    if not _is(text, index, 34):
        raise Error(
            "Failed to deserialize subgraph response: expected a string"
        )
    var cursor = index + 1
    var limit = text.byte_length()
    while cursor < limit:
        var byte = _byte(text, cursor)
        if byte == 92:
            cursor += 2
            continue
        if byte == 34:
            return cursor + 1
        cursor += 1
    raise Error("Failed to deserialize subgraph response: unexpected end")


def _decode(text: String, start: Int, end: Int) -> String:
    """Decode the inside of a JSON string.

    Args:
        text: The JSON text.
        start: The first byte inside the quotes.
        end: The closing quote.

    Returns:
        The decoded text. A string with no escape is copied as it is.
    """
    var bytes = text.as_bytes()
    var escaped = False
    var cursor = start
    while cursor < end:
        if bytes[cursor] == 92:
            escaped = True
            break
        cursor += 1
    if not escaped:
        return _slice(text, start, end)
    var out = List[UInt8]()
    # decode_string is not used: a local copy keeps the span short.
    cursor = start
    while cursor < end:
        if bytes[cursor] != 92:
            out.append(bytes[cursor])
            cursor += 1
            continue
        var mark = bytes[cursor + 1]
        if mark == 34 or mark == 92 or mark == 47:
            out.append(mark)
        elif mark == 98:
            out.append(8)
        elif mark == 102:
            out.append(12)
        elif mark == 110:
            out.append(10)
        elif mark == 114:
            out.append(13)
        elif mark == 116:
            out.append(9)
        else:
            out.append(mark)
        cursor += 2
    return String(unsafe_from_utf8=out^)


def _word(text: String, index: Int, word: String) raises -> Int:
    """Match a JSON literal.

    Args:
        text: The JSON text.
        index: The first byte.
        word: `true`, `false`, or `null`.

    Returns:
        The index after the literal.

    Raises:
        Error: When the literal does not match.
    """
    var limit = word.byte_length()
    if index + limit > text.byte_length():
        raise Error("Failed to deserialize subgraph response: unexpected end")
    var offset = 0
    while offset < limit:
        if _byte(text, index + offset) != _byte(word, offset):
            raise Error("Failed to deserialize subgraph response: invalid JSON")
        offset += 1
    return index + limit


def _slice(text: String, start: Int, end: Int) -> String:
    """Copy a byte range as text.

    Args:
        text: The source text.
        start: The first byte.
        end: The byte after the last one.

    Returns:
        The copied text.
    """
    var bytes = text.as_bytes()
    var out = List[UInt8]()
    var index = start
    while index < end:
        out.append(bytes[index])
        index += 1
    return String(unsafe_from_utf8=out^)


def _space(text: String, index: Int) -> Int:
    """Skip JSON spaces.

    Args:
        text: The JSON text.
        index: The first byte to look at.

    Returns:
        The index of the next value byte, or the end.
    """
    var cursor = index
    var limit = text.byte_length()
    while cursor < limit:
        var byte = _byte(text, cursor)
        if byte != 32 and byte != 9 and byte != 10 and byte != 13:
            return cursor
        cursor += 1
    return cursor


def _is(text: String, index: Int, byte: Int) -> Bool:
    """Return True when a byte is present.

    Args:
        text: The JSON text.
        index: The byte index.
        byte: The expected byte.

    Returns:
        Whether the byte is there.
    """
    if index < 0 or index >= text.byte_length():
        return False
    return _byte(text, index) == byte


def _byte(text: String, index: Int) -> Int:
    """Return one byte.

    Args:
        text: The text.
        index: The byte index.

    Returns:
        The byte value.
    """
    return Int(text.as_bytes()[index])

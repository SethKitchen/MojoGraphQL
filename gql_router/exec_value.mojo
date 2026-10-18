# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The response data of the executor, kept in one JSON arena.

Port of the operations of `Value` of Hive Router `1a29df9`
`bin/router/src/executor/response/value.rs` (`object_position_from`,
`object_get`, `take_entities_by_key`, `to_hash`), of `deep_merge` of
`response/merge.rs`, and of `serialize_value_to_buffer` of
`projection/response.rs`.

The executor keeps every value of a request in one
`gql_json.value.JsonDocument`: the data so far, and each subgraph response
after `import_document` appends it. A node index names a value. An object
member is a node with a key. Merging relinks nodes; it does not copy them.

**Differences from upstream.** Upstream parses numbers into `u64`, `i64`
or `f64` and writes them again. This port keeps the source text of each
number and of each string, escapes included, and writes it unchanged. So a
response keeps the digits and the escapes that the subgraph sent.
`deep_merge` moves the source into the target, so a source must not be
used again; `copy_value` makes a copy first, where upstream clones.
`to_hash` uses FNV-1a with a final mix, not XXH3, so the hash values
differ; equal representations still have equal hashes.
"""

from gql_json.value import (
    FLAG_DECODED,
    FLAG_ESCAPED,
    FLAG_KEY_DECODED,
    FLAG_KEY_ESCAPED,
    FLAG_TRUE,
    NO_NODE,
    JsonDocument,
    JsonKind,
    JsonNode,
    decode_string,
)
from gql_json.writer import write_string

comptime KEY_FLAGS: UInt8 = FLAG_KEY_ESCAPED | FLAG_KEY_DECODED
"""The bits of `JsonNode.flags` that describe the key of a member."""
comptime TYPENAME = "__typename"
"""The name of the type name meta field."""


@always_inline
def node_at(document: JsonDocument, node: Int) -> JsonNode:
    """Return a copy of a node, without a bounds check.

    Args:
        document: The document.
        node: The node's index.

    Returns:
        The node.
    """
    return document.nodes.unsafe_ptr()[unsafe_offset=node]


@always_inline
def raw_key_bytes(
    document: JsonDocument, node: Int
) -> Span[UInt8, origin_of(document.bytes)]:
    """Return the key text of a member, escapes not decoded.

    Args:
        document: The document.
        node: The member's index.

    Returns:
        The key bytes.
    """
    var found = node_at(document, node)
    return Span(document.bytes)[Int(found.key_start) : Int(found.key_end)]


@always_inline
def raw_text_bytes(
    document: JsonDocument, node: Int
) -> Span[UInt8, origin_of(document.bytes)]:
    """Return the text of a number or a string, escapes not decoded.

    Args:
        document: The document.
        node: The node's index.

    Returns:
        The text bytes.
    """
    var found = node_at(document, node)
    return Span(document.bytes)[Int(found.start) : Int(found.end)]


def key_is(document: JsonDocument, node: Int, key: StringSlice) -> Bool:
    """Return True if the key of a member equals a text.

    Args:
        document: The document.
        node: The member's index.
        key: The decoded key to compare.

    Returns:
        Whether the keys are equal.
    """
    if node_at(document, node).flags & FLAG_KEY_ESCAPED == 0:
        return raw_key_bytes(document, node) == key.as_bytes()
    return document.key(node) == key


def keys_equal(document: JsonDocument, a: Int, b: Int) -> Bool:
    """Return True if two members have the same key.

    Args:
        document: The document.
        a: One member.
        b: The other member.

    Returns:
        Whether the decoded keys are equal.
    """
    var escaped = node_at(document, a).flags | node_at(document, b).flags
    if escaped & FLAG_KEY_ESCAPED == 0:
        return raw_key_bytes(document, a) == raw_key_bytes(document, b)
    return document.key(a) == document.key(b)


def object_get(document: JsonDocument, object: Int, key: StringSlice) -> Int:
    """Return the first member of an object with a key, as upstream
    `object_get`.

    Args:
        document: The document.
        object: The object.
        key: The decoded key.

    Returns:
        The member, or `NO_NODE`.
    """
    var current = document.first(object)
    while current != NO_NODE:
        if key_is(document, current, key):
            return current
        current = document.next(current)
    return NO_NODE


def object_get_from(
    document: JsonDocument, object: Int, key: StringSlice, mut cursor: Int
) -> Int:
    """Find a member from a cursor, then from the start, as upstream
    `object_position_from`.

    Args:
        document: The document.
        object: The object.
        key: The decoded key.
        cursor: The member to start at, or `NO_NODE` for the end; it moves
            past the member that is found.

    Returns:
        The member, or `NO_NODE`.
    """
    var start = cursor
    var current = start
    while current != NO_NODE:
        if key_is(document, current, key):
            cursor = document.next(current)
            return current
        current = document.next(current)
    current = document.first(object)
    while current != start:
        if key_is(document, current, key):
            cursor = document.next(current)
            return current
        current = document.next(current)
    return NO_NODE


def string_is(document: JsonDocument, node: Int, text: StringSlice) -> Bool:
    """Return True if a node is a string with a value.

    Args:
        document: The document.
        node: The node.
        text: The decoded value to compare.

    Returns:
        Whether the node is that string.
    """
    if document.kind(node) != JsonKind.STRING:
        return False
    if node_at(document, node).flags & FLAG_ESCAPED == 0:
        return raw_text_bytes(document, node) == text.as_bytes()
    return document.string_value(node) == text


def typename_node(document: JsonDocument, object: Int) -> Int:
    """Return the `__typename` string of an object.

    Args:
        document: The document.
        object: An object, or any other value.

    Returns:
        The string node, or `NO_NODE` when the value is not an object or
        has no string `__typename`.
    """
    if document.kind(object) != JsonKind.OBJECT:
        return NO_NODE
    var found = object_get(document, object, TYPENAME)
    if found == NO_NODE or document.kind(found) != JsonKind.STRING:
        return NO_NODE
    return found


def string_text(document: JsonDocument, node: Int) -> String:
    """Return the decoded value of a string node.

    Args:
        document: The document.
        node: A string node.

    Returns:
        The value.
    """
    if node_at(document, node).flags & FLAG_ESCAPED == 0:
        return String(unsafe_from_utf8=raw_text_bytes(document, node))
    return document.string_value(node)


def take_member(
    mut document: JsonDocument, object: Int, key: StringSlice
) -> Int:
    """Unlink the first member of an object with a key, as upstream
    `take_entities_by_key` takes the member out.

    Args:
        document: The document.
        object: The object.
        key: The decoded key.

    Returns:
        The member, now in no container, or `NO_NODE`.
    """
    if document.kind(object) != JsonKind.OBJECT:
        return NO_NODE
    var previous = NO_NODE
    var current = document.first(object)
    while current != NO_NODE:
        var following = document.next(current)
        if key_is(document, current, key):
            if previous == NO_NODE:
                document.nodes[object].start = Int32(following)
            else:
                document.nodes[previous].next = Int32(following)
            if Int(document.nodes[object].end) == current:
                document.nodes[object].end = Int32(previous)
            document.nodes[object].count -= 1
            document.nodes[current].next = Int32(NO_NODE)
            return current
        previous = current
        current = following
    return NO_NODE


def append_child(mut document: JsonDocument, parent: Int, child: Int):
    """Make a node the last child of a container.

    Args:
        document: The document.
        parent: The array or the object.
        child: The node; its `next` link is cleared.
    """
    document.nodes[child].next = Int32(NO_NODE)
    var last = Int(document.nodes[parent].end)
    if document.nodes[parent].count == 0:
        document.nodes[parent].start = Int32(child)
    else:
        document.nodes[last].next = Int32(child)
    document.nodes[parent].end = Int32(child)
    document.nodes[parent].count += 1


def replace_value(mut document: JsonDocument, target: Int, source: Int):
    """Put the value of one node in the place of another.

    The target keeps its key and its place in its container. A container
    source gives its children to the target.

    Args:
        document: The document.
        target: The node to overwrite.
        source: The node whose value moves.
    """
    var from_node = node_at(document, source)
    ref into = document.nodes[target]
    into.kind = from_node.kind
    into.flags = (from_node.flags & ~KEY_FLAGS) | (into.flags & KEY_FLAGS)
    into.start = from_node.start
    into.end = from_node.end
    into.count = from_node.count


def deep_merge(mut document: JsonDocument, target: Int, source: Int):
    """Merge a source value into a target, as upstream `deep_merge`.

    A null source changes nothing. Two objects merge by key: a shared key
    merges again, and a new key is appended in source order. Two arrays
    merge item by item. Any other pair replaces the target. The source is
    used up: its nodes move into the target.

    Args:
        document: The document that holds both values.
        target: The value that stays.
        source: The value to merge in.
    """
    var source_kind = document.kind(source)
    if source_kind == JsonKind.NULL:
        return
    var target_kind = document.kind(target)
    if source_kind == JsonKind.OBJECT and target_kind == JsonKind.OBJECT:
        _merge_objects(document, target, source)
    elif source_kind == JsonKind.ARRAY and target_kind == JsonKind.ARRAY:
        var left = document.first(target)
        var right = document.first(source)
        while left != NO_NODE and right != NO_NODE:
            var right_next = document.next(right)
            deep_merge(document, left, right)
            left = document.next(left)
            right = right_next
    else:
        replace_value(document, target, source)


def _merge_objects(mut document: JsonDocument, target: Int, source: Int):
    """Merge two objects, as upstream `deep_merge_objects`."""
    if document.length(source) == 0:
        return
    if document.length(target) == 0:
        replace_value(document, target, source)
        return
    var cursor = document.first(target)
    var child = document.first(source)
    while child != NO_NODE:
        var following = document.next(child)
        var found = _find_member_from(document, target, child, cursor)
        if found == NO_NODE:
            append_child(document, target, child)
        else:
            deep_merge(document, found, child)
        child = following


def _find_member_from(
    document: JsonDocument, object: Int, member: Int, mut cursor: Int
) -> Int:
    """Find the member with the key of another member, from a cursor."""
    var start = cursor
    var current = start
    while current != NO_NODE:
        if keys_equal(document, current, member):
            cursor = document.next(current)
            return current
        current = document.next(current)
    current = document.first(object)
    while current != start:
        if keys_equal(document, current, member):
            cursor = document.next(current)
            return current
        current = document.next(current)
    return NO_NODE


def copy_value(mut document: JsonDocument, node: Int) -> Int:
    """Copy a value and every value under it, as upstream `clone`.

    Args:
        document: The document.
        node: The value; a member keeps its key in the copy.

    Returns:
        The copy; it is in no container.
    """
    var found = node_at(document, node)
    document.nodes.append(found)
    var copy = len(document.nodes) - 1
    document.nodes[copy].next = Int32(NO_NODE)
    if found.kind.value < JsonKind.ARRAY.value or found.count == 0:
        return copy
    document.nodes[copy].start = Int32(NO_NODE)
    document.nodes[copy].end = Int32(NO_NODE)
    document.nodes[copy].count = 0
    var child = Int(found.start)
    while child != NO_NODE:
        var child_copy = copy_value(document, child)
        append_child(document, copy, child_copy)
        child = document.next(child)
    return copy


def import_document(mut document: JsonDocument, other: JsonDocument) -> Int:
    """Append every node and byte of another document.

    Args:
        document: The arena.
        other: A parsed or built document.

    Returns:
        The index of the other document's root in the arena, or `NO_NODE`
        when it has none.
    """
    var node_offset = Int32(len(document.nodes))
    var byte_offset = Int32(len(document.bytes))
    document.bytes.extend(Span(other.bytes))
    var count = len(other.nodes)
    document.nodes.reserve(len(document.nodes) + count)
    var source = other.nodes.unsafe_ptr()
    var index = 0
    while index < count:
        var node = source[unsafe_offset=index]
        if node.kind.value >= JsonKind.ARRAY.value:
            if node.count > 0:
                node.start += node_offset
                node.end += node_offset
        else:
            node.start += byte_offset
            node.end += byte_offset
        node.key_start += byte_offset
        node.key_end += byte_offset
        if Int(node.next) != NO_NODE:
            node.next += node_offset
        document.nodes.append(node)
        index += 1
    if other.root == NO_NODE:
        return NO_NODE
    return other.root + Int(node_offset)


def set_key(mut document: JsonDocument, node: Int, key: StringSlice):
    """Give a member a new key.

    Args:
        document: The document.
        node: The member.
        key: The decoded key.
    """
    var start = len(document.bytes)
    document.bytes.extend(key.as_bytes())
    ref member = document.nodes[node]
    member.key_start = Int32(start)
    member.key_end = Int32(len(document.bytes))
    member.flags = (member.flags & ~KEY_FLAGS) | FLAG_KEY_DECODED


def set_string(mut document: JsonDocument, node: Int, text: StringSlice):
    """Make a node the string with a value; it keeps its key.

    Args:
        document: The document.
        node: The node to overwrite.
        text: The decoded value.
    """
    var start = len(document.bytes)
    document.bytes.extend(text.as_bytes())
    ref target = document.nodes[node]
    target.kind = JsonKind.STRING
    target.flags = FLAG_DECODED | (target.flags & KEY_FLAGS)
    target.start = Int32(start)
    target.end = Int32(len(document.bytes))
    target.count = 0


def write_key(document: JsonDocument, node: Int, mut out: List[UInt8]):
    """Append the quoted key of a member.

    Args:
        document: The document.
        node: The member.
        out: The destination.
    """
    if node_at(document, node).flags & FLAG_KEY_DECODED != 0:
        write_string(out, raw_key_bytes(document, node))
        return
    out.append(UInt8(ord('"')))
    out.extend(raw_key_bytes(document, node))
    out.append(UInt8(ord('"')))


def write_value(document: JsonDocument, node: Int, mut out: List[UInt8]):
    """Append the JSON text of a value, as upstream
    `serialize_value_to_buffer`.

    Args:
        document: The document.
        node: The value.
        out: The destination.
    """
    var found = node_at(document, node)
    var kind = found.kind
    if kind == JsonKind.STRING:
        if found.flags & FLAG_DECODED != 0:
            write_string(out, raw_text_bytes(document, node))
        else:
            out.append(UInt8(ord('"')))
            out.extend(raw_text_bytes(document, node))
            out.append(UInt8(ord('"')))
    elif kind == JsonKind.NUMBER:
        out.extend(raw_text_bytes(document, node))
    elif kind == JsonKind.OBJECT:
        out.append(UInt8(ord("{")))
        var child = Int(found.start) if found.count > 0 else NO_NODE
        var first = True
        while child != NO_NODE:
            if not first:
                out.append(UInt8(ord(",")))
            first = False
            write_key(document, child, out)
            out.append(UInt8(ord(":")))
            write_value(document, child, out)
            child = document.next(child)
        out.append(UInt8(ord("}")))
    elif kind == JsonKind.ARRAY:
        out.append(UInt8(ord("[")))
        var child = Int(found.start) if found.count > 0 else NO_NODE
        var first = True
        while child != NO_NODE:
            if not first:
                out.append(UInt8(ord(",")))
            first = False
            write_value(document, child, out)
            child = document.next(child)
        out.append(UInt8(ord("]")))
    elif kind == JsonKind.BOOLEAN:
        if found.flags & FLAG_TRUE != 0:
            out.extend("true".as_bytes())
        else:
            out.extend("false".as_bytes())
    else:
        out.extend("null".as_bytes())


comptime FNV_OFFSET: UInt64 = 0xCBF29CE484222325
"""The FNV-1a offset basis."""
comptime FNV_PRIME: UInt64 = 0x100000001B3
"""The FNV-1a prime."""


@always_inline
def hash_bytes(state: UInt64, bytes: Span[UInt8, _]) -> UInt64:
    """Fold bytes into a hash state with FNV-1a.

    Args:
        state: The state.
        bytes: The bytes.

    Returns:
        The new state.
    """
    var hash = state
    var data = bytes.unsafe_ptr()
    var index = 0
    var length = len(bytes)
    while index < length:
        hash = (hash ^ UInt64(data[unsafe_offset=index])) * FNV_PRIME
        index += 1
    return hash


@always_inline
def hash_tag(state: UInt64, tag: UInt8) -> UInt64:
    """Fold one tag byte into a hash state.

    Args:
        state: The state.
        tag: The byte.

    Returns:
        The new state.
    """
    return (state ^ UInt64(tag)) * FNV_PRIME


def hash_key(document: JsonDocument, node: Int, state: UInt64) -> UInt64:
    """Fold the decoded key of a member into a hash state.

    Args:
        document: The document.
        node: The member.
        state: The state.

    Returns:
        The new state.
    """
    if node_at(document, node).flags & FLAG_KEY_ESCAPED == 0:
        return hash_tag(hash_bytes(state, raw_key_bytes(document, node)), 0xFF)
    var key = document.key(node)
    return hash_tag(hash_bytes(state, key.as_bytes()), 0xFF)


def hash_value(document: JsonDocument, node: Int, state: UInt64) -> UInt64:
    """Fold a whole value into a hash state, as upstream `Hash for Value`.

    Args:
        document: The document.
        node: The value.
        state: The state.

    Returns:
        The new state.
    """
    var found = node_at(document, node)
    var kind = found.kind
    var hash = hash_tag(state, kind.value)
    if kind == JsonKind.STRING:
        if found.flags & FLAG_ESCAPED == 0:
            return hash_bytes(hash, raw_text_bytes(document, node))
        var decoded = List[UInt8]()
        decode_string(
            Span(document.bytes), Int(found.start), Int(found.end), decoded
        )
        return hash_bytes(hash, Span(decoded))
    if kind == JsonKind.NUMBER:
        return hash_bytes(hash, raw_text_bytes(document, node))
    if kind == JsonKind.BOOLEAN:
        return hash_tag(hash, found.flags & FLAG_TRUE)
    if kind.value < JsonKind.ARRAY.value:
        return hash
    var child = Int(found.start) if found.count > 0 else NO_NODE
    while child != NO_NODE:
        if kind == JsonKind.OBJECT:
            hash = hash_key(document, child, hash)
        hash = hash_value(document, child, hash)
        child = document.next(child)
    return hash_tag(hash, 0xFE)


@always_inline
def finish_hash(state: UInt64) -> UInt64:
    """Mix the bits of a hash state, as the SplitMix64 finalizer.

    Args:
        state: The state.

    Returns:
        The hash.
    """
    var z = state
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9
    z = (z ^ (z >> 27)) * 0x94D049BB133111EB
    return z ^ (z >> 31)

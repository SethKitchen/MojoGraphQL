# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Incremental delivery on the client: merging `@defer` and `@stream`
payloads into one result.

Port of Apollo Client 4.3.3 `src/incremental/handlers/graphql17Alpha9.ts`
(`GraphQL17Alpha9Handler` and its `IncrementalRequest`),
`src/incremental/handlers/defer20220824.ts` (`Defer20220824Handler` and
its `DeferRequest`), and of the helpers they use from
`src/utilities/internal`: `DeepMerger` with `arrayMerge: "truncate"` and
`atPath`, `makeStreamInfoTrie`, `StreamArrayState`,
`addDeferFragmentLabels` and `hasDirectives`.

`GraphQL17Alpha9Handler` reads the format of graphql-js 17, which
`gql_execution.incremental` writes: `pending`, `incremental` with `id`
and `subPath`, `completed` and `hasNext`. `Defer20220824Handler` reads the
older format, where each incremental result has a `path` and a `label`.

A request merges each payload into its data, and gives the result after
each payload. A client writes that result to the cache, reads it back, and
gives the read to the next `handle` as `cache_data`. `QueryInfo` in
`gql_client.query_info` does those steps.

Differences from upstream:

- A result is a `FormattedExecutionResult` of value indices into the
  arena of the request (`request.values`). `request.stringify(result)`
  gives its JSON, and `request.to_json(result)` a `JsonDocument`.
- The stream information of upstream is a `WeakRef` under a symbol key
  in `extensions`. Here it is `request.stream_info`, and
  `result.has_stream_info` tells when upstream adds the key.
- `prepareRequest` changes the `context.http.accept` of a request. Here
  `prepare_accept(document, accept)` returns the new list of `accept`
  values, because there is no link.
- `StreamArrayState` keeps no `optimism` dependency: there is no result
  cache to make dirty.
- Malformed input. A `pending` path that goes through a value that is
  not an object reads as `undefined`. Upstream fails with a `TypeError`.
  A merge at a path that goes through `null` or through a scalar raises
  an `Error` with the message of the upstream `TypeError`.
"""

from std.collections import Dict

from gql_json.value import JsonDocument, JsonKind, NO_NODE
from gql_language.ast import Document, FLAG_EXTRA, Kind, Role
from gql_language.ast import NO_NODE as NO_AST_NODE
from gql_client.values import (
    Member,
    NO_VALUE,
    NULL_VALUE,
    UNDEFINED_VALUE,
    ValueKind,
    Values,
    array_index,
)


comptime RESERVED_PREFIX = "ac_"
"""The prefix of the labels that `add_defer_fragment_labels` adds."""
comptime INCREMENTAL_SPEC_ACCEPT = "multipart/mixed;incrementalSpec=v0.2"
"""The `accept` value of `GraphQL17Alpha9Handler`."""
comptime DEFER_SPEC_ACCEPT = "multipart/mixed;deferSpec=20220824"
"""The `accept` value of `Defer20220824Handler`."""


# --- stream information --------------------------------------------------


@fieldwise_init
struct StreamFieldInfo(Equatable, ImplicitlyCopyable, Writable):
    """Where a `@stream` array is in its stream: upstream
    `Incremental.StreamFieldInfo`."""

    var is_first_chunk: Bool
    """True for the payload that announced the stream."""
    var is_last_chunk: Bool
    """True for the payload that completed the stream."""

    def write_to(self, mut writer: Some[Writer]):
        """Write the JSON of the information.

        Args:
            writer: The writer.
        """
        writer.write(
            '{"isFirstChunk":',
            "true" if self.is_first_chunk else "false",
            ',"isLastChunk":',
            "true" if self.is_last_chunk else "false",
            "}",
        )


@fieldwise_init
struct StreamArrayState(ImplicitlyCopyable):
    """The state of one `@stream` array: upstream `StreamArrayState`."""

    var truncate: Bool
    """Whether a read cuts the array at `stream_position`."""
    var stream_position: Int
    """The count of items that have arrived."""


@fieldwise_init
struct StreamInfoEntry(ImplicitlyCopyable):
    """The entry of one path in a `StreamInfo`."""

    var current: StreamFieldInfo
    """The information of the last payload."""
    var state: StreamArrayState
    """The state of the array."""


struct StreamInfo(Boolable, Copyable, Movable):
    """The `@stream` arrays of a request, by path: upstream
    `StreamInfoTrie`, from `makeStreamInfoTrie`.

    A path key comes from `path_key_append`: each segment is a key or an
    array index, as the trie of upstream tells them apart.
    """

    var entries: Dict[String, StreamInfoEntry]
    """The entries, by path key."""

    def __init__(out self):
        """Make an empty trie."""
        self.entries = Dict[String, StreamInfoEntry]()

    def __bool__(self) -> Bool:
        """Tell if the trie has an entry, as the `strong` map of upstream.

        Returns:
            True when an entry exists.
        """
        return len(self.entries) > 0

    def lookup(mut self, key: String) -> StreamInfoEntry:
        """Return the entry of a path, and make it when it does not exist,
        as `lookupArray`.

        Args:
            key: The path key.

        Returns:
            A copy of the entry.
        """
        var found = self.entries.get(key)
        if found:
            return found.value()
        var entry = StreamInfoEntry(
            StreamFieldInfo(True, False), StreamArrayState(False, 0)
        )
        self.entries[key] = entry
        return entry

    def peek(self, key: String) -> Optional[StreamInfoEntry]:
        """Return the entry of a path, as `peekArray`.

        Args:
            key: The path key.

        Returns:
            The entry, or None.
        """
        return self.entries.get(key)

    def set(mut self, key: String, entry: StreamInfoEntry):
        """Store the entry of a path.

        Args:
            key: The path key.
            entry: The entry.
        """
        self.entries[key] = entry


def path_key_append(mut key: String, segment: StringSlice, is_index: Bool):
    """Add one segment to a path key.

    Args:
        key: The key so far.
        segment: The key, or the decimal text of the index.
        is_index: Whether the segment is an array index.
    """
    key += "#" if is_index else "$"
    key += segment
    key += "\x1f"


def path_key(values: Values, path: List[Int]) -> String:
    """Return the key of a path whose segments are values.

    Args:
        values: The arena.
        path: The segments: strings and numbers.

    Returns:
        The path key.
    """
    var key = String()
    var index = 0
    while index < len(path):
        var segment = path[index]
        path_key_append(
            key,
            values.text(segment),
            values.kind(segment) == ValueKind.NUMBER,
        )
        index += 1
    return key^


# --- documents -----------------------------------------------------------


def _directives(document: Document) -> List[Int]:
    """Return the `Directive` nodes of a document, in document order."""
    var out = List[Int]()
    var stack: List[Int] = [document.root]
    while len(stack) > 0:
        var node = stack.pop()
        if document.kind(node) == Kind.DIRECTIVE:
            out.append(node)
        var children = List[Int]()
        var child = document.first_child(node)
        while child != NO_AST_NODE:
            children.append(child)
            child = document.next_sibling(child)
        while len(children) > 0:
            stack.append(children.pop())
    return out^


def has_directives(
    names: List[String], document: Document, all: Bool = False
) -> Bool:
    """Tell if a document uses some directives: upstream `hasDirectives`.

    Args:
        names: The directive names.
        document: The document.
        all: Whether every name must be used, and not one of them.

    Returns:
        True when one name is used, or with `all` when each name is used.
    """
    var left = List[String]()
    var index = 0
    while index < len(names):
        if names[index] not in left:
            left.append(names[index])
        index += 1
    var unique = len(left)
    var directives = _directives(document)
    index = 0
    while index < len(directives):
        var name = String(document.name(directives[index]))
        var position = 0
        while position < len(left) and left[position] != name:
            position += 1
        if position < len(left):
            _ = left.pop(position)
            if not all or len(left) == 0:
                break
        index += 1
    if all:
        return len(left) == 0
    return len(left) < unique


def _argument(document: Document, directive: Int, name: StringSlice) -> Int:
    """Return the first argument of a directive that has a name."""
    var argument = document.child(directive, Role.ARGUMENT)
    while argument != NO_AST_NODE:
        if document.name(argument) == name:
            return argument
        argument = document.next_with_role(argument)
    return NO_AST_NODE


def add_defer_fragment_labels(document: Document) -> Document:
    """Return a copy of a document whose `@defer` directives each have a
    label: upstream `addDeferFragmentLabels`.

    A `@defer` without a string `label`, or whose label starts with
    `ac_`, gets the label `ac_0`, `ac_1` and so on, in document order.

    Args:
        document: The document.

    Returns:
        The new document.
    """
    var out = document.copy()
    var directives = _directives(out)
    var count = 0
    var index = 0
    while index < len(directives):
        var directive = directives[index]
        index += 1
        if not out.has_text(out.child(directive, Role.NAME), "defer"):
            continue
        var argument = _argument(out, directive, "label")
        if argument != NO_AST_NODE:
            var value = out.child(argument, Role.VALUE)
            if out.kind(value) == Kind.STRING:
                var label = out.string_value(value)
                if label.byte_length() > 0 and not label.startswith(
                    RESERVED_PREFIX
                ):
                    continue
        var text = String(RESERVED_PREFIX, count)
        count += 1
        if argument == NO_AST_NODE:
            argument = out.add_child(directive, Kind.ARGUMENT, Role.ARGUMENT)
            _ = out.add_name(argument, Role.NAME, "label")
            out.append_child(
                argument, out.add_text(Kind.STRING, Role.VALUE, text)
            )
            continue
        # Make the value a string in place: the argument keeps its name.
        var value = out.child(argument, Role.VALUE)
        var start = len(out.source.bytes)
        out.source.bytes.extend(text.as_bytes())
        out.nodes[value].kind = Kind.STRING
        out.nodes[value].flags = FLAG_EXTRA
        out.nodes[value].start = Int32(start)
        out.nodes[value].end = Int32(len(out.source.bytes))
        out.nodes[value].first = Int32(NO_AST_NODE)
        out.nodes[value].last = Int32(NO_AST_NODE)
        out.nodes[value].roles = 0
    return out^


def prepare_accept(
    document: Document, accept: List[String], value: StringSlice
) -> List[String]:
    """Return the `accept` values of a request, as `prepareRequest`.

    A document with `@defer` or `@stream` gets `value` first.

    Args:
        document: The operation document.
        accept: The `accept` values of the request.
        value: `INCREMENTAL_SPEC_ACCEPT` or `DEFER_SPEC_ACCEPT`.

    Returns:
        The new list.
    """
    if not has_directives(["defer", "stream"], document):
        return accept.copy()
    var out: List[String] = [String(value)]
    out.extend(accept.copy())
    return out^


# --- DeepMerger at a path ------------------------------------------------


def _key_text(values: Values, key: Int) -> String:
    """Return the text of a path segment, as JavaScript converts a
    property key."""
    return String(values.text(key))


def _obj_for_key(mut values: Values, key: Int) -> Int:
    """Return a new container for a key, as upstream `objForKey`.

    `isNaN(+key)` is false for a number, and for the name `Infinity`, the
    one GraphQL name that converts to a number.
    """
    if values.kind(key) == ValueKind.NUMBER or values.text(key) == "Infinity":
        return values.add_array(List[Int]())
    return values.add_object(List[Member]())


def _get(values: Values, target: Int, key: Int) raises -> Int:
    """Return `target[key]`, or `NO_VALUE` for `undefined`."""
    var kind = values.kind(target)
    if kind == ValueKind.NULL:
        raise Error(
            String(
                "Cannot read properties of null (reading '",
                _key_text(values, key),
                "')",
            )
        )
    if kind == ValueKind.OBJECT:
        return values.get(target, values.text(key))
    if kind == ValueKind.ARRAY:
        var index = Int(array_index(values.text(key)))
        if index >= 0 and index < values.length(target):
            var item = values.item(target, index)
            if item != UNDEFINED_VALUE:
                return item
    return NO_VALUE


def _set(mut values: Values, target: Int, key: Int, value: Int) raises -> Int:
    """Return a copy of `target` with `target[key] = value`."""
    var kind = values.kind(target)
    if kind == ValueKind.OBJECT:
        var name = Int32(values.names.intern(values.text(key)))
        var members = values.members(target)
        var position = 0
        while position < len(members) and members[position].name != name:
            position += 1
        if position < len(members):
            members[position].value = Int32(value)
        else:
            members.append(Member(name, Int32(value)))
        return values.add_object(members)
    if kind == ValueKind.ARRAY:
        var index = Int(array_index(values.text(key)))
        if index < 0:
            # A property that is not an index: no item changes.
            return target
        var items = values.array_items(target)
        while len(items) <= index:
            items.append(UNDEFINED_VALUE)
        items[index] = value
        return values.add_array(items)
    raise Error(
        String(
            "Cannot create property '",
            _key_text(values, key),
            "' on ",
            values.kind(target),
        )
    )


def _merge_items(
    mut values: Values, target: Int, position: Int, items: Int
) raises -> Int:
    """Merge streamed items into an array at a position.

    Upstream builds a sparse array with the items at `position` and merges
    it: the target is cut to the end of the items, and each item merges
    with the target item at its index.
    """
    var count = values.length(items)
    var end = position + count
    var kind = values.kind(target)
    if kind == ValueKind.ARRAY:
        var out = values.array_items(target)
        var changed = False
        if len(out) > end:
            out.resize(end, NO_VALUE)
            changed = True
        var index = 0
        while index < count:
            var incoming = values.item(items, index)
            var at = position + index
            index += 1
            if at < len(out):
                if incoming != out[at]:
                    var merged = values.merge(out[at], incoming, True)
                    if merged != out[at]:
                        out[at] = merged
                        changed = True
                continue
            while len(out) < at:
                out.append(UNDEFINED_VALUE)
            out.append(incoming)
            changed = True
        if not changed:
            return target
        return values.add_array(out)
    if kind == ValueKind.OBJECT:
        # The object gets the items as members named by their indices.
        var result = target
        var index = 0
        while index < count:
            var key = values.add_int(position + index)
            var incoming = values.item(items, index)
            index += 1
            var existing = _get(values, result, key)
            var merged = incoming
            if existing != NO_VALUE:
                merged = values.merge(existing, incoming, True)
            if merged != existing:
                result = _set(values, result, key, merged)
        return result
    var out = List[Int](length=position, fill=UNDEFINED_VALUE)
    var index = 0
    while index < count:
        out.append(values.item(items, index))
        index += 1
    return values.add_array(out)


def merge_at_path(
    mut values: Values,
    target: Int,
    path: List[Int],
    depth: Int,
    source: Int,
    position: Int = -1,
) raises -> Int:
    """Deep merge a source into a target at a path, as `DeepMerger.merge`
    with `arrayMerge: "truncate"` and `atPath`.

    Args:
        values: The arena.
        target: The target, or `NO_VALUE` for `undefined`.
        path: The path segments: strings and numbers.
        depth: The count of segments already followed.
        source: The source. With `position`, an array of streamed items.
        position: The index of the first streamed item, or -1 to merge
            `source` itself.

    Returns:
        The merged target.

    Raises:
        Error: When the path goes through `null` or a scalar.
    """
    if depth == len(path):
        if position >= 0:
            return _merge_items(values, target, position, source)
        return values.merge(target, source, True)
    var head = path[depth]
    var result = target
    if values.kind(result) == ValueKind.UNDEFINED:
        result = _obj_for_key(values, head)
    var nested = _get(values, result, head)
    if nested == NO_VALUE and depth + 1 < len(path):
        nested = _obj_for_key(values, path[depth + 1])
    var merged = merge_at_path(
        values, nested, path, depth + 1, source, position
    )
    if merged != nested:
        result = _set(values, result, head, merged)
    return result


# --- results -------------------------------------------------------------


@fieldwise_init
struct FormattedExecutionResult(ImplicitlyCopyable):
    """The result after one payload: upstream `FormattedExecutionResult`.

    Each member is a value of the arena of the request.
    """

    var data: Int
    """The data."""
    var errors: Int
    """The array of errors, or `NO_VALUE` when there is no error."""
    var extensions: Int
    """The extensions object, or `NO_VALUE` when there is none."""
    var has_stream_info: Bool
    """Whether upstream adds the stream information to `extensions`."""


@fieldwise_init
struct PendingWithInfo(Copyable, Movable):
    """One pending result: an item of upstream `getPendingWithInfo`."""

    var is_stream: Bool
    """True for `type: "stream"`, False for `type: "defer"`."""
    var delivered: Bool
    """For a defer, whether it completed without errors."""
    var path: Int
    """The path array."""
    var label: Int
    """For a defer, the label string, or `NO_VALUE`."""


def _result_object(
    values: Values, result: FormattedExecutionResult
) -> List[Member]:
    """Return the members of the JSON object of a result."""
    # A request always has data: `{}` at first, and `undefined` from the
    # cache keeps it.
    var members: List[Member] = [
        Member(Int32(values.names.find("data")), Int32(result.data))
    ]
    if result.errors != NO_VALUE:
        members.append(
            Member(Int32(values.names.find("errors")), Int32(result.errors))
        )
    if result.extensions != NO_VALUE:
        members.append(
            Member(
                Int32(values.names.find("extensions")), Int32(result.extensions)
            )
        )
    return members^


def _intern_result_names(mut values: Values):
    """Intern the keys of a result object."""
    _ = values.names.intern("data")
    _ = values.names.intern("errors")
    _ = values.names.intern("extensions")


def result_to_json(
    mut values: Values, result: FormattedExecutionResult
) -> JsonDocument:
    """Return a result as a JSON document.

    Args:
        values: The arena of the result.
        result: The result.

    Returns:
        The document of `{data, errors, extensions}`.
    """
    var object = values.add_object(_result_object(values, result))
    var document = JsonDocument()
    document.root = values.to_json(document, object)
    return document^


def value_to_json(values: Values, value: Int) -> JsonDocument:
    """Return a value as a JSON document.

    Args:
        values: The arena.
        value: The value.

    Returns:
        The document.
    """
    var document = JsonDocument()
    document.root = values.to_json(document, value)
    return document^


def _id_text(chunk: JsonDocument, node: Int) -> String:
    """Return the text of an `id` member: a string, or another value's
    JSON text."""
    var id = chunk.find(node, "id")
    if id == NO_NODE:
        return String("undefined")
    if chunk.kind(id) == JsonKind.STRING:
        return chunk.string_value(id)
    return String(chunk.text(id))


def _items(chunk: JsonDocument, node: Int, key: StringSlice) -> List[Int]:
    """Return the items of an array member, or none when the member is
    not an array."""
    var out = List[Int]()
    var found = chunk.find(node, key)
    if found == NO_NODE or chunk.kind(found) != JsonKind.ARRAY:
        return out^
    var item = chunk.first(found)
    while item != NO_NODE:
        out.append(item)
        item = chunk.next(item)
    return out^


def _value_at(
    values: Values, start: Int, path: List[Int], from_index: Int
) raises -> Int:
    """Follow a path with optional chaining: `undefined` when a step is
    missing."""
    var value = start
    var index = from_index
    while index < len(path) and value != NO_VALUE:
        var kind = values.kind(value)
        if kind != ValueKind.OBJECT and kind != ValueKind.ARRAY:
            return NO_VALUE
        value = _get(values, value, path[index])
        index += 1
    return value


def _path_items(values: Values, path: Int) -> List[Int]:
    """Return the segments of a path array; none for another value."""
    if not values.is_array(path):
        return List[Int]()
    return values.array_items(path)


struct _Accumulator(Movable):
    """The data, errors and extensions that a request merges: the `merge`
    method and the fields that both upstream request classes have."""

    var values: Values
    """The arena of every value of the request."""
    var data: Int
    """The merged data: `{}` at first."""
    var errors: List[Int]
    """The errors so far."""
    var extensions: List[Member]
    """The members of the merged extensions."""

    def __init__(out self):
        """Start with `{}` data, no error and no extension."""
        self.values = Values()
        _intern_result_names(self.values)
        self.data = self.values.add_object(List[Member]())
        self.errors = List[Int]()
        self.extensions = List[Member]()

    def set_data(mut self, cache_data: Optional[JsonDocument]):
        """Start a payload from the data of the cache, when it is given.

        Args:
            cache_data: The data that the cache reads, or None to keep the
                data of the request. A document with no root is
                `undefined`, so it keeps the data too.
        """
        if cache_data and cache_data.value().root != NO_NODE:
            ref document = cache_data.value()
            self.data = self.values.from_json(document, document.root)

    def merge(
        mut self,
        data: Int,
        chunk: JsonDocument,
        node: Int,
        path: List[Int],
        position: Int = -1,
    ) raises:
        """Merge data at a path, and the errors and extensions of a JSON
        object, as the `merge` method of upstream.

        Args:
            data: The data to merge, or `NO_VALUE` for `undefined`.
            chunk: The document of the errors and extensions.
            node: The object that has them, or `NO_NODE`.
            path: The path of the data.
            position: The index of the first streamed item, or -1.
        """
        if data != NO_VALUE:
            self.data = merge_at_path(
                self.values, self.data, path, 0, data, position
            )
        if node == NO_NODE:
            return
        var errors = _items(chunk, node, "errors")
        var index = 0
        while index < len(errors):
            self.errors.append(self.values.from_json(chunk, errors[index]))
            index += 1
        var extensions = chunk.find(node, "extensions")
        if extensions == NO_NODE or chunk.kind(extensions) != JsonKind.OBJECT:
            return
        var member = chunk.first(extensions)
        while member != NO_NODE:
            var name = Int32(self.values.names.intern(chunk.key(member)))
            var value = Int32(self.values.from_json(chunk, member))
            member = chunk.next(member)
            var position = 0
            while (
                position < len(self.extensions)
                and self.extensions[position].name != name
            ):
                position += 1
            if position < len(self.extensions):
                self.extensions[position].value = value
            else:
                self.extensions.append(Member(name, value))

    def result(mut self, has_stream_info: Bool) -> FormattedExecutionResult:
        """Return the result of the request so far.

        Args:
            has_stream_info: Whether the request has stream information.

        Returns:
            The result.
        """
        var errors = NO_VALUE
        if len(self.errors) > 0:
            errors = self.values.add_array(self.errors)
        var extensions = NO_VALUE
        # The stream information is a symbol key of `extensions`, so an
        # empty `extensions` object shows it.
        if len(self.extensions) > 0 or has_stream_info:
            extensions = self.values.add_object(self.extensions)
        return FormattedExecutionResult(
            self.data, errors, extensions, has_stream_info
        )


def _has_next(chunk: JsonDocument) -> Bool:
    """Return the truth of the `hasNext` member of a payload."""
    var found = chunk.find(chunk.root, "hasNext")
    return (
        found != NO_NODE
        and chunk.kind(found) == JsonKind.BOOLEAN
        and chunk.bool_value(found)
    )


# --- requests ------------------------------------------------------------


trait IncrementalRequestType(Movable):
    """What a client needs of a request: upstream
    `Incremental.IncrementalRequest`."""

    def handle(
        mut self, cache_data: Optional[JsonDocument], chunk: JsonDocument
    ) raises -> FormattedExecutionResult:
        """Merge one payload.

        Args:
            cache_data: The data of the cache, or None.
            chunk: The payload.

        Returns:
            The result so far.

        Raises:
            Error: For a malformed payload.
        """
        ...

    def to_json(mut self, result: FormattedExecutionResult) -> JsonDocument:
        """Return a result as a JSON document.

        Args:
            result: A result of the request.

        Returns:
            The document of `{data, errors, extensions}`.
        """
        ...

    def data_json(self, result: FormattedExecutionResult) -> JsonDocument:
        """Return the data of a result as a JSON document.

        Args:
            result: A result of the request.

        Returns:
            The document of the data.
        """
        ...

    def is_streaming(self, document: Document) raises -> Bool:
        """Tell if the data state of the last result is `streaming`.

        Args:
            document: The operation document.

        Returns:
            True while deferred data has to come.

        Raises:
            Error: Never.
        """
        ...

    def current_stream_info(self) -> StreamInfo:
        """Return the stream information that a cache write gets.

        Returns:
            A copy of the trie; empty when the request has no stream.
        """
        ...

    def chunk_has_errors(self, chunk: JsonDocument) -> Bool:
        """Tell if the `extractErrors` of the handler finds errors.

        Args:
            chunk: A result or a payload.

        Returns:
            True when the handler extracts an error.
        """
        ...


# --- GraphQL17Alpha9Handler ----------------------------------------------


struct _Pending(Copyable, Movable):
    """A pending result: upstream `PendingResult`, in the arena, with the
    entries of `streamPositions` and `completedMap` for its id."""

    var path: Int
    """The path array."""
    var label: Int
    """The label, or `NO_VALUE`."""
    var segments: List[Int]
    """The items of the path array."""
    var position: Int
    """The entry of `streamPositions`, or -1 when there is none."""
    var delivered: Bool
    """The entry of `completedMap`: completed without errors."""

    def __init__(out self, path: Int, label: Int, var segments: List[Int]):
        """Make a pending result that has no stream position.

        Args:
            path: The path array.
            label: The label, or `NO_VALUE`.
            segments: The items of the path array.
        """
        self.path = path
        self.label = label
        self.segments = segments^
        self.position = -1
        self.delivered = False


struct IncrementalRequest(IncrementalRequestType):
    """The merge of the payloads of one request in the graphql-js 17
    format: upstream `IncrementalRequest` of `graphql17Alpha9.ts`."""

    var has_next: Bool
    """The `hasNext` of the last payload."""
    var acc: _Accumulator
    """The merged data, errors and extensions."""
    var slots: List[_Pending]
    """The pending results, in the order they came: the order of the
    upstream `Map`."""
    var pending: Dict[String, Int]
    """The slot of each pending id."""
    var stream_info: StreamInfo
    """The `@stream` arrays, by path."""

    def __init__(out self):
        """Start a request."""
        self.has_next = True
        self.acc = _Accumulator()
        self.slots = List[_Pending]()
        self.pending = Dict[String, Int]()
        self.stream_info = StreamInfo()

    def pending_with_info(self) -> List[PendingWithInfo]:
        """Return the pending results, as `getPendingWithInfo`.

        Returns:
            One item for each pending id, in order.
        """
        var out = List[PendingWithInfo]()
        var index = 0
        while index < len(self.slots):
            ref slot = self.slots[index]
            index += 1
            if slot.position >= 0:
                out.append(PendingWithInfo(True, False, slot.path, NO_VALUE))
            else:
                out.append(
                    PendingWithInfo(
                        False, slot.delivered, slot.path, slot.label
                    )
                )
        return out^

    def is_streaming(self, document: Document) raises -> Bool:
        """Tell if a deferred fragment is pending and not delivered, the
        rule of upstream `QueryInfo.markQueryResult`.

        Args:
            document: The operation document.

        Returns:
            True when a defer has not completed without errors.

        Raises:
            Error: Never.
        """
        var pending = self.pending_with_info()
        var index = 0
        while index < len(pending):
            if not pending[index].is_stream and not pending[index].delivered:
                return True
            index += 1
        return False

    def current_stream_info(self) -> StreamInfo:
        """Return the stream information that a cache write gets.

        Returns:
            A copy of `stream_info`.
        """
        return self.stream_info.copy()

    def chunk_has_errors(self, chunk: JsonDocument) -> Bool:
        """Tell if `GraphQL17Alpha9Handler.extract_errors` finds errors.

        Args:
            chunk: A result or a payload.

        Returns:
            True when it finds an error.
        """
        return Bool(_extract_errors(chunk, True, True))

    def handle(
        mut self, cache_data: Optional[JsonDocument], chunk: JsonDocument
    ) raises -> FormattedExecutionResult:
        """Merge one payload, as upstream `handle`.

        Args:
            cache_data: The data that the cache has for the query, or None
                (upstream `undefined`) to go on from the data of the
                request.
            chunk: The payload: an initial or a subsequent result.

        Returns:
            The result so far.

        Raises:
            Error: For an `incremental` or `completed` id that no
                `pending` announced, or a merge through `null`.
        """
        self.has_next = _has_next(chunk)
        self.acc.set_data(cache_data)
        ref values = self.acc.values
        var root = chunk.root
        var data_node = chunk.find(root, "data")
        var chunk_data = values.from_json(chunk, data_node)
        var pendings = _items(chunk, root, "pending")
        var index = 0
        while index < len(pendings):
            var node = pendings[index]
            index += 1
            var id = _id_text(chunk, node)
            var path = values.from_json(chunk, chunk.find(node, "path"))
            var label = values.from_json(chunk, chunk.find(node, "label"))
            var segments = _path_items(values, path)
            var slot = self.pending.get(id, -1)
            if slot < 0:
                slot = len(self.slots)
                self.pending[id] = slot
                self.slots.append(_Pending(path, label, segments.copy()))
            else:
                # `Map.set` keeps the place of the id.
                self.slots[slot].path = path
                self.slots[slot].label = label
                self.slots[slot].segments = segments.copy()
            if data_node == NO_NODE:
                continue
            var at = _value_at(values, chunk_data, segments, 0)
            if values.is_array(at):
                var length = values.length(at)
                self.slots[slot].position = length
                var key = path_key(values, segments)
                var entry = self.stream_info.lookup(key)
                entry.current = StreamFieldInfo(True, False)
                entry.state.stream_position = length
                self.stream_info.set(key, entry)
        var incrementals = _items(chunk, root, "incremental")
        if len(incrementals) == 0:
            self.acc.merge(chunk_data, chunk, root, List[Int]())
        index = 0
        while index < len(incrementals):
            var node = incrementals[index]
            index += 1
            self._incremental(chunk, node)
        var completions = _items(chunk, root, "completed")
        index = 0
        while index < len(completions):
            self._completed(chunk, completions[index])
            index += 1
        return self.acc.result(Bool(self.stream_info))

    def _incremental(mut self, chunk: JsonDocument, node: Int) raises:
        """Merge one item of `incremental`."""
        var id = _id_text(chunk, node)
        var found = self.pending.get(id)
        if not found:
            raise Error(
                "Could not find pending chunk for incremental value. Please"
                " file an issue for the Apollo Client team to investigate."
            )
        var slot = found.value()
        ref values = self.acc.values
        var depth = len(self.slots[slot].segments)
        var path = self.slots[slot].segments.copy()
        var sub = chunk.find(node, "subPath")
        if sub != NO_NODE:
            path.extend(_path_items(values, values.from_json(chunk, sub)))
        var items = chunk.find(node, "items")
        if items != NO_NODE:
            var data = values.from_json(chunk, items)
            var position = max(self.slots[slot].position, 0)
            var next = position + (
                values.length(data) if values.is_array(data) else 0
            )
            self.slots[slot].position = next
            var key = path_key(values, path)
            var entry = self.stream_info.lookup(key)
            entry.current = StreamFieldInfo(False, False)
            entry.state.stream_position = next
            self.stream_info.set(key, entry)
            self.acc.merge(data, chunk, node, path, position)
            return
        var data = values.from_json(chunk, chunk.find(node, "data"))
        # A stream inside deferred data starts after the items that the
        # deferred data has.
        var index = 0
        while index < len(self.slots):
            ref other = self.slots[index]
            index += 1
            if other.position >= 0:
                continue
            var at = _value_at(values, data, other.segments, depth)
            if values.is_array(at):
                other.position = values.length(at)
        self.acc.merge(data, chunk, node, path)

    def _completed(mut self, chunk: JsonDocument, node: Int) raises:
        """Apply one item of `completed`."""
        var id = _id_text(chunk, node)
        var found = self.pending.get(id)
        if not found:
            raise Error(
                (
                    "Cannot destructure property 'path' of undefined: no"
                    " pending result has the id "
                ),
                id,
            )
        var slot = found.value()
        var path = self.slots[slot].segments.copy()
        var errors = chunk.find(node, "errors")
        self.slots[slot].delivered = errors == NO_NODE
        var position = self.slots[slot].position
        if position >= 0:
            # Cut the array to the streamed items, for a payload that has
            # only `completed`.
            var at = _value_at(self.acc.values, self.acc.data, path, 0)
            if not self.acc.values.is_array(at):
                raise Error(
                    "dataAtPath.slice is not a function: the streamed field"
                    " is not an array"
                )
            var kept = self.acc.values.array_items(at)
            if len(kept) > position:
                kept.resize(position, NO_VALUE)
            var sliced = self.acc.values.add_array(kept)
            self.acc.merge(sliced, chunk, NO_NODE, path)
        # `peekArray` finds nothing in an empty trie.
        if self.stream_info:
            var key = path_key(self.acc.values, path)
            var details = self.stream_info.peek(key)
            if details:
                var entry = details.value()
                entry.current = StreamFieldInfo(False, True)
                if position >= 0:
                    entry.state.stream_position = position
                self.stream_info.set(key, entry)
        var listed = _items(chunk, node, "errors")
        var index = 0
        while index < len(listed):
            var error = self.acc.values.from_json(chunk, listed[index])
            self.acc.errors.append(error)
            index += 1

    def stringify(mut self, result: FormattedExecutionResult) -> String:
        """Return the `JSON.stringify` text of a result.

        Args:
            result: A result of this request.

        Returns:
            The JSON text of `{data, errors, extensions}`.
        """
        return _stringify(self.acc.values, result)

    def to_json(mut self, result: FormattedExecutionResult) -> JsonDocument:
        """Return a result as a JSON document.

        Args:
            result: A result of this request.

        Returns:
            The document of `{data, errors, extensions}`.
        """
        return result_to_json(self.acc.values, result)

    def data_json(self, result: FormattedExecutionResult) -> JsonDocument:
        """Return the data of a result as a JSON document, for a cache
        write.

        Args:
            result: A result of this request.

        Returns:
            The document of the data.
        """
        return value_to_json(self.acc.values, result.data)


def _stringify(mut values: Values, result: FormattedExecutionResult) -> String:
    """Return the JSON text of a result."""
    var object = values.add_object(_result_object(values, result))
    return values.stringify(object)


def _push_errors(mut out: JsonDocument, chunk: JsonDocument, nodes: List[Int]):
    """Copy the items of the `errors` member of some objects into an
    array."""
    var position = 0
    while position < len(nodes):
        var items = _items(chunk, nodes[position], "errors")
        position += 1
        var index = 0
        while index < len(items):
            out.append(out.root, out.add_copy(chunk, items[index]))
            index += 1


def _extract_errors(
    chunk: JsonDocument, plain: Bool, completed: Bool
) -> Optional[JsonDocument]:
    """Collect the errors of a result, as `extractErrors`.

    `plain` tells if the errors of a result that is not a payload count,
    and `completed` if the errors of the `completed` items count.
    """
    var out = JsonDocument()
    out.root = out.add_array()
    var root = chunk.root
    var is_incremental = chunk.find(root, "hasNext") != NO_NODE
    if is_incremental or plain:
        _push_errors(out, chunk, [root])
    if is_incremental:
        _push_errors(out, chunk, _items(chunk, root, "incremental"))
        if completed:
            _push_errors(out, chunk, _items(chunk, root, "completed"))
    if out.length(out.root) == 0:
        return None
    return out^


struct GraphQL17Alpha9Handler(Copyable, Defaultable, Movable):
    """The incremental handler of the graphql-js 17 format: upstream
    `GraphQL17Alpha9Handler`."""

    def __init__(out self):
        """Make a handler."""
        pass

    def transform_document(self, document: Document) -> Document:
        """Apply the `documentTransform` of the handler.

        Args:
            document: The operation document.

        Returns:
            The document with a label on each `@defer`.
        """
        return add_defer_fragment_labels(document)

    def is_incremental_result(self, result: JsonDocument) -> Bool:
        """Tell if a result is a payload: `"hasNext" in result`.

        Args:
            result: The result.

        Returns:
            True when the result has `hasNext`.
        """
        return result.find(result.root, "hasNext") != NO_NODE

    def prepare_accept(
        self, document: Document, accept: List[String]
    ) -> List[String]:
        """Return the `accept` values of a request, as `prepareRequest`.

        Args:
            document: The operation document.
            accept: The `accept` values so far.

        Returns:
            The values, with `multipart/mixed;incrementalSpec=v0.2` first
            when the document has `@defer` or `@stream`.
        """
        return prepare_accept(document, accept, INCREMENTAL_SPEC_ACCEPT)

    def extract_errors(self, result: JsonDocument) -> Optional[JsonDocument]:
        """Collect the errors of a result, as `extractErrors`.

        Args:
            result: A result or a payload.

        Returns:
            The array of the errors of the result, of its `incremental`
            items and of its `completed` items, or None when there is none.
        """
        return _extract_errors(result, True, True)

    def start_request(self) -> IncrementalRequest:
        """Start the merge of the payloads of one request.

        Returns:
            The new request.
        """
        return IncrementalRequest()


# --- Defer20220824Handler ------------------------------------------------


struct DeferRequest(IncrementalRequestType):
    """The merge of the payloads of one request in the format of the
    2022-08-24 `@defer` specification: upstream `DeferRequest`."""

    var has_next: Bool
    """The `hasNext` of the last payload."""
    var acc: _Accumulator
    """The merged data, errors and extensions."""
    var ignored_impossible_stream_paths: List[String]
    """The `@stream` paths whose `items` was `null`: their later items
    are not merged."""

    def __init__(out self):
        """Start a request."""
        self.has_next = True
        self.acc = _Accumulator()
        self.ignored_impossible_stream_paths = List[String]()

    def is_streaming(self, document: Document) raises -> Bool:
        """Tell if the data state is `streaming`, as upstream
        `QueryInfo.markQueryResult` decides it for this format: payloads
        are to come and the document has `@defer`.

        Args:
            document: The operation document.

        Returns:
            True while payloads are to come for a document with `@defer`.

        Raises:
            Error: Never.
        """
        return self.has_next and has_directives(["defer"], document)

    def current_stream_info(self) -> StreamInfo:
        """Return the stream information that a cache write gets.

        Returns:
            An empty trie: this format has no stream information.
        """
        return StreamInfo()

    def chunk_has_errors(self, chunk: JsonDocument) -> Bool:
        """Tell if `Defer20220824Handler.extract_errors` finds errors.

        Args:
            chunk: A result or a payload.

        Returns:
            True when it finds an error.
        """
        return Bool(_extract_errors(chunk, False, False))

    def handle(
        mut self, cache_data: Optional[JsonDocument], chunk: JsonDocument
    ) raises -> FormattedExecutionResult:
        """Merge one payload, as upstream `handle`.

        Args:
            cache_data: The data that the cache has for the query, or None
                (upstream `undefined`) to go on from the data of the
                request.
            chunk: The payload: an initial or a subsequent result.

        Returns:
            The result so far.

        Raises:
            Error: For a merge through `null` or a scalar.
        """
        self.has_next = _has_next(chunk)
        self.acc.set_data(cache_data)
        var root = chunk.root
        var incrementals = _items(chunk, root, "incremental")
        if len(incrementals) == 0:
            var data = self.acc.values.from_json(
                chunk, chunk.find(root, "data")
            )
            self.acc.merge(data, chunk, root, List[Int]())
        var index = 0
        while index < len(incrementals):
            self._incremental(chunk, incrementals[index])
            index += 1
        return self.acc.result(False)

    def _incremental(mut self, chunk: JsonDocument, node: Int) raises:
        """Merge one item of `incremental`."""
        var path = _path_items(
            self.acc.values,
            self.acc.values.from_json(chunk, chunk.find(node, "path")),
        )
        var items = chunk.find(node, "items")
        var data: Int
        if items != NO_NODE:
            # The index at the end changes with each payload of a stream.
            var string_path = String()
            var position = 0
            while position + 1 < len(path):
                if position > 0:
                    string_path += "."
                string_path += self.acc.values.text(path[position])
                position += 1
            if chunk.kind(items) == JsonKind.NULL:
                self.ignored_impossible_stream_paths.append(string_path)
            if string_path in self.ignored_impossible_stream_paths:
                self.acc.merge(NO_VALUE, chunk, node, List[Int]())
                return
            data = self.acc.values.from_json(chunk, items)
        else:
            data = self.acc.values.from_json(chunk, chunk.find(node, "data"))
            if data == NULL_VALUE:
                # `data: null` of a `@defer` is not merged.
                data = NO_VALUE
        var last = len(path) - 1
        if (
            last >= 0
            and self.acc.values.kind(path[last]) == ValueKind.NUMBER
            and self.acc.values.is_array(data)
        ):
            var start = atol(self.acc.values.text(path[last]))
            var count = self.acc.values.length(data)
            var base = path.copy()
            var index = 0
            while index < count:
                var item = self.acc.values.item(data, index)
                base[last] = self.acc.values.add_int(start + index)
                self.acc.merge(item, chunk, NO_NODE, base)
                index += 1
        else:
            self.acc.merge(data, chunk, NO_NODE, path)
        self.acc.merge(NO_VALUE, chunk, node, List[Int]())

    def stringify(mut self, result: FormattedExecutionResult) -> String:
        """Return the `JSON.stringify` text of a result.

        Args:
            result: A result of this request.

        Returns:
            The JSON text of `{data, errors, extensions}`.
        """
        return _stringify(self.acc.values, result)

    def to_json(mut self, result: FormattedExecutionResult) -> JsonDocument:
        """Return a result as a JSON document.

        Args:
            result: A result of this request.

        Returns:
            The document of `{data, errors, extensions}`.
        """
        return result_to_json(self.acc.values, result)

    def data_json(self, result: FormattedExecutionResult) -> JsonDocument:
        """Return the data of a result as a JSON document, for a cache
        write.

        Args:
            result: A result of this request.

        Returns:
            The document of the data.
        """
        return value_to_json(self.acc.values, result.data)


struct Defer20220824Handler(Copyable, Defaultable, Movable):
    """The incremental handler of the 2022-08-24 `@defer` format: upstream
    `Defer20220824Handler`."""

    def __init__(out self):
        """Make a handler."""
        pass

    def is_incremental_result(self, result: JsonDocument) -> Bool:
        """Tell if a result is a payload: `"hasNext" in result`.

        Args:
            result: The result.

        Returns:
            True when the result has `hasNext`.
        """
        return result.find(result.root, "hasNext") != NO_NODE

    def prepare_accept(
        self, document: Document, accept: List[String]
    ) -> List[String]:
        """Return the `accept` values of a request, as `prepareRequest`.

        Args:
            document: The operation document.
            accept: The `accept` values so far.

        Returns:
            The values, with `multipart/mixed;deferSpec=20220824` first
            when the document has `@defer` or `@stream`.
        """
        return prepare_accept(document, accept, DEFER_SPEC_ACCEPT)

    def extract_errors(self, result: JsonDocument) -> Optional[JsonDocument]:
        """Collect the errors of a payload, as `extractErrors`.

        Args:
            result: A result or a payload.

        Returns:
            The array of the errors of a payload and of its `incremental`
            items, or None when there is none. A result that is not a
            payload gives None, as upstream.
        """
        return _extract_errors(result, False, False)

    def start_request(self) -> DeferRequest:
        """Start the merge of the payloads of one request.

        Returns:
            The new request.
        """
        return DeferRequest()

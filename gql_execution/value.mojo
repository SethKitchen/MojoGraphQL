# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The values that execution reads and makes: root values, resolver
results, arguments and variables.

graphql-js passes JavaScript values to and from resolvers. Mojo has no
dynamic objects, so this module keeps them in one arena, `Values`: each
value is a fixed `ValueNode` in one list, and a value is an `Int` index
into that list. `UNDEFINED`, which is `-1`, is the JavaScript `undefined`.

A value is one of the JavaScript kinds that execution can see: `null`, a
boolean, a number (a `Float64`, as a JavaScript number), a string, an
array, and a plain object whose keys keep their insertion order. Two more
kinds stand in for JavaScript objects that are not plain data:

- **A handle** names a host object: a `tag` and an `id` that the
  resolvers give a meaning, such as a row of a table. A resolver that
  returns a handle gets it back as the `source` of the fields below it.
  Introspection uses handles with negative tags for the schema, its types,
  fields, input values, enum values and directives.
- **An error** is a JavaScript `Error` instance that a resolver returns,
  not raises. Execution raises it when it completes the value, as
  graphql-js does.
- **An event stream** is a handle with the tag `STREAM_TAG`. The arena
  holds the `gql_stream` stream that `add_stream` gave it, as a
  JavaScript `AsyncIterable`. A `subscribe` function returns one.

`mark` and `release` drop the values of one subscription event, when no
older value links to them.

Port of the value model of graphql-js 16.14.2 `jsutils/inspect.ts` and of
the JavaScript values that `execution/execute.ts` reads.

**Differences from upstream.**

- There are no functions, promises, iterables other than arrays, classes,
  `valueOf` or `toJSON`. A handle has no properties: `inspect` writes it
  as `{}`, and the default field resolver gives `undefined` for it.
- `inspect` writes an error value as `{}`, as graphql-js writes an `Error`
  with no enumerable properties.
"""

from std.memory import bitcast
from gql_json.value import JsonDocument, JsonKind
from gql_language.error import quote_json_string
from gql_schema.values import js_number_to_string
from gql_stream.stream import AnyStream


@fieldwise_init
struct ValueKind(Equatable, ImplicitlyCopyable, Writable):
    """The kind of a value of a `Values` arena."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime UNDEFINED = ValueKind(0)
    """`undefined`: no value."""
    comptime NULL = ValueKind(1)
    """`null`."""
    comptime BOOLEAN = ValueKind(2)
    """A boolean."""
    comptime NUMBER = ValueKind(3)
    """A number: a `Float64`, as a JavaScript number."""
    comptime STRING = ValueKind(4)
    """A string."""
    comptime LIST = ValueKind(5)
    """An array."""
    comptime OBJECT = ValueKind(6)
    """A plain object, with its keys in insertion order."""
    comptime HANDLE = ValueKind(7)
    """A host object: a tag and an id."""
    comptime ERROR = ValueKind(8)
    """A JavaScript `Error` instance, with a message."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the nine kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 8

    def text(self) -> StaticString:
        """Return the name of the kind, such as `object`.

        Returns:
            The name, or `<invalid>`.
        """
        comptime names: Array[StaticString, 9] = [
            "undefined",
            "null",
            "boolean",
            "number",
            "string",
            "array",
            "object",
            "handle",
            "error",
        ]
        if self.is_valid():
            return materialize[names]()[Int(self.value)]
        return "<invalid>"

    def write_to(self, mut writer: Some[Writer]):
        """Write the name of the kind.

        Args:
            writer: The destination.
        """
        writer.write(self.text())


comptime UNDEFINED = -1
"""The index that stands for `undefined`."""
comptime STREAM_TAG = -7
"""The tag of a handle to an event stream that `Values.add_stream` holds.
The introspection tags are -1 to -6."""
comptime PROMISE_TAG = -8
"""The tag of a handle to a promise that `Values.add_promise` or
`Values.add_rejected_promise` holds."""


@fieldwise_init
struct ValueNode(ImplicitlyCopyable, Movable):
    """One value of a `Values` arena."""

    var kind: ValueKind
    """What the value is."""
    var flag: Bool
    """A boolean's value."""
    var start: Int32
    """A string's first byte, a container's first child, or a handle's
    first extra number."""
    var end: Int32
    """A string's end byte, a container's last child, or a handle's second
    extra number."""
    var count: Int32
    """How many children a container has."""
    var next: Int32
    """The next sibling in its container, or `UNDEFINED`."""
    var key_start: Int32
    """The first byte of the key of an object member."""
    var key_end: Int32
    """The end byte of the key of an object member."""
    var tag: Int32
    """A handle's tag."""
    var payload: Int64
    """A number's bits, or a handle's id."""


struct Values(Movable):
    """An arena of JavaScript values: each value is an index into `nodes`.

    A value has at most one parent. The `add_` methods add a value with no
    parent; `append`, `add_member` and `set` give it one.
    """

    var nodes: List[ValueNode]
    """Every value."""
    var bytes: List[UInt8]
    """The text of the strings, the error messages and the keys."""
    var streams: List[Optional[AnyStream]]
    """The event streams that `add_stream` holds, by handle id."""

    def __init__(out self):
        """Start an empty arena."""
        self.nodes = List[ValueNode](capacity=64)
        self.bytes = List[UInt8](capacity=256)
        self.streams = List[Optional[AnyStream]]()

    def __init__(out self, *, capacity: Int):
        """Start an empty arena with room for some values.

        Args:
            capacity: How many values fit before the arena grows; zero
                allocates nothing, for an arena that only holds a place.
        """
        self.nodes = List[ValueNode](capacity=capacity)
        self.bytes = List[UInt8](capacity=capacity * 4)
        self.streams = List[Optional[AnyStream]]()

    # --- building -------------------------------------------------------

    @always_inline
    def _add(
        mut self,
        kind: ValueKind,
        start: Int,
        end: Int,
        tag: Int32 = 0,
        payload: Int64 = 0,
        flag: Bool = False,
    ) -> Int:
        """Add a node with no parent; return its index."""
        self.nodes.append(
            ValueNode(
                kind,
                flag,
                Int32(start),
                Int32(end),
                0,
                Int32(UNDEFINED),
                0,
                0,
                tag,
                payload,
            )
        )
        return len(self.nodes) - 1

    def _add_text(mut self, kind: ValueKind, text: StringSlice) -> Int:
        """Add a node whose text goes after the bytes."""
        var start = len(self.bytes)
        self.bytes.extend(text.as_bytes())
        return self._add(kind, start, len(self.bytes))

    def add_undefined(mut self) -> Int:
        """Add `undefined` as a value, such as an item of an array.

        Returns:
            The new value's index.
        """
        return self._add(ValueKind.UNDEFINED, 0, 0)

    def add_null(mut self) -> Int:
        """Add `null`.

        Returns:
            The new value's index.
        """
        return self._add(ValueKind.NULL, 0, 0)

    def add_bool(mut self, value: Bool) -> Int:
        """Add a boolean.

        Args:
            value: The boolean.

        Returns:
            The new value's index.
        """
        return self._add(ValueKind.BOOLEAN, 0, 0, flag=value)

    def add_number(mut self, value: Float64) -> Int:
        """Add a number.

        Args:
            value: The number; NaN and the infinities too.

        Returns:
            The new value's index.
        """
        return self._add(
            ValueKind.NUMBER, 0, 0, payload=bitcast[DType.int64](value)
        )

    def add_string(mut self, text: StringSlice) -> Int:
        """Add a string.

        Args:
            text: The string.

        Returns:
            The new value's index.
        """
        return self._add_text(ValueKind.STRING, text)

    def add_error(mut self, message: StringSlice) -> Int:
        """Add an `Error` instance, which a resolver returns as a value.

        Args:
            message: The error's message.

        Returns:
            The new value's index.
        """
        return self._add_text(ValueKind.ERROR, message)

    def add_list(mut self) -> Int:
        """Add an empty array.

        Returns:
            The new value's index.
        """
        return self._add(ValueKind.LIST, UNDEFINED, UNDEFINED)

    def add_object(mut self) -> Int:
        """Add an empty object.

        Returns:
            The new value's index.
        """
        return self._add(ValueKind.OBJECT, UNDEFINED, UNDEFINED)

    def add_handle(
        mut self, tag: Int, id: Int, first: Int = 0, second: Int = 0
    ) -> Int:
        """Add a handle to a host object.

        Args:
            tag: What kind of host object it is. Introspection uses the
                negative tags; a program uses zero or more.
            id: Which object it is.
            first: An extra number, which the program gives a meaning.
            second: A second extra number.

        Returns:
            The new value's index.
        """
        return self._add(
            ValueKind.HANDLE, first, second, tag=Int32(tag), payload=Int64(id)
        )

    def append(mut self, list: Int, item: Int):
        """Make a value the last item of an array.

        Args:
            list: An array's index.
            item: A value with no parent.
        """
        var nodes = self.nodes.unsafe_ptr()
        ref container = nodes[unsafe_offset=list]
        var last = Int(container.end)
        container.end = Int32(item)
        container.count += 1
        if container.count == 1:
            container.start = Int32(item)
        else:
            nodes[unsafe_offset=last].next = Int32(item)

    def add_member(mut self, object: Int, key: StringSlice, item: Int):
        """Make a value the last member of an object, with a key.

        The method does not look for the key: use `set` to replace a
        member.

        Args:
            object: An object's index.
            key: The key.
            item: A value with no parent.
        """
        var start = len(self.bytes)
        self.bytes.extend(key.as_bytes())
        ref member = self.nodes[item]
        member.key_start = Int32(start)
        member.key_end = Int32(len(self.bytes))
        self.append(object, item)

    def set(mut self, object: Int, key: StringSlice, item: Int):
        """Set a property of an object, as JavaScript `object[key] = item`.

        A new key goes last. A key that is there keeps its position and
        takes the new value.

        Args:
            object: An object's index.
            key: The key.
            item: A value with no parent.
        """
        var member = self.member(object, key)
        if member == UNDEFINED:
            self.add_member(object, key, item)
            return
        var old = self.nodes[member]
        var replacement = self.nodes[item]
        replacement.next = old.next
        replacement.key_start = old.key_start
        replacement.key_end = old.key_end
        self.nodes[member] = replacement

    def copy(mut self, value: Int) -> Int:
        """Copy a value with no parent, so that a new container can hold it.

        A string shares its bytes with the original. A container's
        children are copied too.

        Args:
            value: The value's index, or `UNDEFINED`.

        Returns:
            The copy's index, or `UNDEFINED` for `UNDEFINED`.
        """
        if value < 0:
            return UNDEFINED
        var found = self.node(value)
        if found.kind != ValueKind.LIST and found.kind != ValueKind.OBJECT:
            found.next = Int32(UNDEFINED)
            found.key_start = 0
            found.key_end = 0
            self.nodes.append(found)
            return len(self.nodes) - 1
        var out = self._add(found.kind, UNDEFINED, UNDEFINED)
        var child = self.first(value)
        while child != UNDEFINED:
            var item = self.copy(child)
            if found.kind == ValueKind.OBJECT:
                var source = self.node(child)
                ref target = self.nodes[item]
                target.key_start = source.key_start
                target.key_end = source.key_end
            self.append(out, item)
            child = self.next(child)
        return out

    def add_json(mut self, document: JsonDocument, node: Int) -> Int:
        """Copy a JSON value, as `JSON.parse` gives it.

        Args:
            document: The JSON document.
            node: The JSON value's index.

        Returns:
            The new value's index.
        """
        var kind = document.kind(node)
        if kind == JsonKind.NULL:
            return self.add_null()
        if kind == JsonKind.BOOLEAN:
            return self.add_bool(document.bool_value(node))
        if kind == JsonKind.NUMBER:
            return self.add_number(document.as_float64(node))
        if kind == JsonKind.STRING:
            return self.add_string(document.string_value(node))
        var is_object = kind == JsonKind.OBJECT
        var out = self.add_object() if is_object else self.add_list()
        var child = document.first(node)
        while child != -1:
            var item = self.add_json(document, child)
            if is_object:
                self.set(out, document.key(child), item)
            else:
                self.append(out, item)
            child = document.next(child)
        return out

    # --- reading --------------------------------------------------------

    @always_inline
    def kind(self, value: Int) -> ValueKind:
        """Return a value's kind; `UNDEFINED` for index `UNDEFINED`.

        Args:
            value: The value's index, or `UNDEFINED`.

        Returns:
            Its kind.
        """
        if value < 0:
            return ValueKind.UNDEFINED
        return self.nodes.unsafe_ptr()[unsafe_offset=value].kind

    @always_inline
    def node(self, value: Int) -> ValueNode:
        """Return a copy of a value's node.

        Args:
            value: The value's index; not `UNDEFINED`.

        Returns:
            The node.
        """
        return self.nodes.unsafe_ptr()[unsafe_offset=value]

    def is_nullish(self, value: Int) -> Bool:
        """Return True for `null` and `undefined`, as JavaScript `== null`.

        Args:
            value: The value's index, or `UNDEFINED`.

        Returns:
            Whether the value is `null` or `undefined`.
        """
        var kind = self.kind(value)
        return kind == ValueKind.UNDEFINED or kind == ValueKind.NULL

    def bool_value(self, value: Int) -> Bool:
        """Return a boolean's value.

        Args:
            value: A boolean's index.

        Returns:
            The boolean; False for another kind.
        """
        return self.node(value).flag

    def number(self, value: Int) -> Float64:
        """Return a number's value.

        Args:
            value: A number's index.

        Returns:
            The number.
        """
        return bitcast[DType.float64](self.node(value).payload)

    def string(self, value: Int) -> StringSlice[origin_of(self.bytes)]:
        """Return the text of a string, or the message of an error.

        Args:
            value: A string's or an error's index.

        Returns:
            A view of the text.
        """
        var found = self.node(value)
        return StringSlice(
            unsafe_from_utf8=Span(self.bytes)[Int(found.start) : Int(found.end)]
        )

    def key(self, member: Int) -> StringSlice[origin_of(self.bytes)]:
        """Return the key of an object member.

        Args:
            member: A member's index.

        Returns:
            A view of the key.
        """
        var found = self.node(member)
        return StringSlice(
            unsafe_from_utf8=Span(self.bytes)[
                Int(found.key_start) : Int(found.key_end)
            ]
        )

    def length(self, value: Int) -> Int:
        """Return how many items or members a container has.

        Args:
            value: A container's index.

        Returns:
            The count; 0 for a value that is not a container.
        """
        return Int(self.node(value).count)

    @always_inline
    def first(self, value: Int) -> Int:
        """Return the first item or member of a container.

        Args:
            value: A container's index.

        Returns:
            The child's index, or `UNDEFINED`.
        """
        var found = self.node(value)
        if found.count == 0:
            return UNDEFINED
        return Int(found.start)

    @always_inline
    def next(self, value: Int) -> Int:
        """Return the next item or member after a child.

        Args:
            value: A child's index.

        Returns:
            The sibling's index, or `UNDEFINED`.
        """
        return Int(self.node(value).next)

    def item(self, list: Int, index: Int) -> Int:
        """Return an item of an array.

        Args:
            list: An array's index.
            index: The position.

        Returns:
            The item's index, or `UNDEFINED` when the position is out of
            range.
        """
        var current = self.first(list)
        var at = 0
        while current != UNDEFINED and at < index:
            current = self.next(current)
            at += 1
        return current

    def member(self, object: Int, key: StringSlice) -> Int:
        """Return the member of an object with a key.

        Args:
            object: An object's index.
            key: The key.

        Returns:
            The member's index, or `UNDEFINED` when there is none.
        """
        var nodes = self.nodes.unsafe_ptr()
        var data = self.bytes.unsafe_ptr()
        var wanted = key.as_bytes()
        var size = len(wanted)
        var current = self.first(object)
        while current != UNDEFINED:
            var found = nodes[unsafe_offset=current]
            if Int(found.key_end - found.key_start) == size:
                var start = Int(found.key_start)
                var same = True
                var index = 0
                while index < size:
                    if data[unsafe_offset=start + index] != wanted[index]:
                        same = False
                        break
                    index += 1
                if same:
                    return current
            current = Int(found.next)
        return UNDEFINED

    def get(self, object: Int, key: StringSlice) -> Int:
        """Return a property of a value, as JavaScript `value[key]`.

        Args:
            object: A value's index.
            key: The key.

        Returns:
            The property's index; `UNDEFINED` when the value is not an
            object or has no such key.
        """
        if self.kind(object) != ValueKind.OBJECT:
            return UNDEFINED
        return self.member(object, key)

    def tag(self, value: Int) -> Int:
        """Return a handle's tag.

        Args:
            value: A handle's index.

        Returns:
            The tag.
        """
        return Int(self.node(value).tag)

    def id(self, value: Int) -> Int:
        """Return a handle's id.

        Args:
            value: A handle's index.

        Returns:
            The id.
        """
        return Int(self.node(value).payload)

    def handle_first(self, value: Int) -> Int:
        """Return a handle's first extra number.

        Args:
            value: A handle's index.

        Returns:
            The number.
        """
        return Int(self.node(value).start)

    def handle_second(self, value: Int) -> Int:
        """Return a handle's second extra number.

        Args:
            value: A handle's index.

        Returns:
            The number.
        """
        return Int(self.node(value).end)

    # --- event streams --------------------------------------------------

    def add_stream(mut self, var stream: AnyStream) -> Int:
        """Hold an event stream, and add a handle to it.

        A `subscribe` function returns this value: the source event stream
        of a subscription, as a JavaScript `AsyncIterable`.

        Args:
            stream: The stream; the arena owns it until `take_stream`.

        Returns:
            A handle with the tag `STREAM_TAG`.
        """
        self.streams.append(Optional(stream^))
        return self.add_handle(STREAM_TAG, len(self.streams) - 1)

    def is_stream(self, value: Int) -> Bool:
        """Return True for a handle that `add_stream` made, whose stream is
        still in the arena.

        Args:
            value: A value's index, or `UNDEFINED`.

        Returns:
            Whether the value is an event stream.
        """
        if self.kind(value) != ValueKind.HANDLE or self.tag(value) != (
            STREAM_TAG
        ):
            return False
        var id = self.id(value)
        return id < len(self.streams) and Bool(self.streams[id])

    def take_stream(mut self, value: Int) raises -> AnyStream:
        """Take an event stream out of the arena.

        Args:
            value: A value that `is_stream` accepts.

        Returns:
            The stream.

        Raises:
            Error: When the value is not an event stream.
        """
        if not self.is_stream(value):
            raise Error("The value is not an event stream.")
        return self.streams[self.id(value)].take()

    # --- promises -------------------------------------------------------

    def add_promise(mut self, resolved: Int) -> Int:
        """Add a resolved promise value, as JavaScript
        `Promise.resolve(resolved)`.

        Args:
            resolved: The value that the promise resolves to.

        Returns:
            A handle with the tag `PROMISE_TAG`.
        """
        return self.add_handle(PROMISE_TAG, resolved, first=0)

    def add_rejected_promise(mut self, message: StringSlice) -> Int:
        """Add a rejected promise value, as JavaScript
        `Promise.reject(new Error(message))`.

        Args:
            message: The error's message.

        Returns:
            A handle with the tag `PROMISE_TAG`.
        """
        var err = self.add_error(message)
        return self.add_handle(PROMISE_TAG, err, first=1)

    def is_promise(self, value: Int) -> Bool:
        """Return True for a promise handle that `add_promise` or
        `add_rejected_promise` made.

        Args:
            value: A value's index, or `UNDEFINED`.

        Returns:
            Whether the value is a promise.
        """
        if self.kind(value) != ValueKind.HANDLE:
            return False
        return self.tag(value) == PROMISE_TAG

    def is_rejected_promise(self, value: Int) -> Bool:
        """Return True for a rejected promise handle.

        Args:
            value: A promise handle's index.

        Returns:
            Whether the promise is rejected.
        """
        if not self.is_promise(value):
            return False
        return self.handle_first(value) != 0

    def promise_value(self, value: Int) -> Int:
        """Return the resolved value or error node of a promise handle.

        Args:
            value: A promise handle's index.

        Returns:
            The target value's index.
        """
        return self.id(value)

    def mark(self) -> Tuple[Int, Int]:
        """Return the sizes of the arena, for `release`.

        Returns:
            The counts of nodes and of bytes.
        """
        return (len(self.nodes), len(self.bytes))

    def release(mut self, mark: Tuple[Int, Int]) -> Bool:
        """Drop each value that was added after a mark, when no older value
        links to one of them or to their text.

        Args:
            mark: What `mark` returned.

        Returns:
            Whether the values were dropped. An older container that holds
            a newer value keeps them all.
        """
        var count = mark[0]
        var index = 0
        while index < count:
            ref node = self.nodes[index]
            index += 1
            if Int(node.next) >= count:
                return False
            var kind = node.kind
            if kind == ValueKind.LIST or kind == ValueKind.OBJECT:
                if Int(node.start) >= count or Int(node.end) >= count:
                    return False
            elif kind == ValueKind.HANDLE and node.tag == PROMISE_TAG:
                if Int(node.payload) >= count:
                    return False
            elif kind == ValueKind.STRING or kind == ValueKind.ERROR:
                if Int(node.end) > mark[1]:
                    return False
        self.nodes.shrink(count)
        self.bytes.shrink(mark[1])
        return True


def inspect(values: Values, value: Int) -> String:
    """Return a value as graphql-js `inspect` writes it.

    Strings are in JSON quotes. An array shows at most ten items, and an
    array or an object nested three deep shows as `[Array]` or `[Object]`.

    Args:
        values: The arena.
        value: The value's index, or `UNDEFINED`.

    Returns:
        Such as `{ a: 1, b: "x" }` or `[1, 2]`.
    """
    return _format_value(values, value, 0)


def _format_value(values: Values, value: Int, depth: Int) -> String:
    """Return graphql-js `formatValue`; `depth` counts the enclosing
    arrays and objects."""
    var kind = values.kind(value)
    if kind == ValueKind.UNDEFINED:
        return String("undefined")
    if kind == ValueKind.NULL:
        return String("null")
    if kind == ValueKind.BOOLEAN:
        return String("true") if values.bool_value(value) else String("false")
    if kind == ValueKind.NUMBER:
        return js_number_to_string(values.number(value))
    if kind == ValueKind.STRING:
        return quote_json_string(String(values.string(value)))
    var count = values.length(value)
    if kind == ValueKind.LIST:
        if count == 0:
            return String("[]")
        if depth >= 2:
            return String("[Array]")
        var out = String("[")
        var item = values.first(value)
        var index = 0
        while index < min(count, 10):
            if index > 0:
                out += ", "
            out += _format_value(values, item, depth + 1)
            item = values.next(item)
            index += 1
        var remaining = count - index
        if remaining == 1:
            out += ", ... 1 more item"
        elif remaining > 1:
            out += ", ... " + String(remaining) + " more items"
        return out + "]"
    if count == 0:
        return String("{}")
    if depth >= 2:
        return String("[Object]")
    var out = String("{ ")
    var member = values.first(value)
    while member != UNDEFINED:
        if member != values.first(value):
            out += ", "
        out += String(values.key(member)) + ": "
        out += _format_value(values, member, depth + 1)
        member = values.next(member)
    return out + " }"

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The `Trace` protobuf message of a federated trace, and its encoding.

Port of the `Trace` message of Apollo Server 5.5.1
`packages/usage-reporting-protobuf/src/reports.proto` (MIT), with
`google.protobuf.Timestamp`. Upstream generates the code of the message
with protobufjs; this module writes the encoding of the protobuf wire
format by hand.

`Trace.encode` writes the fields that the inline trace plugin sets, in
the order of their field numbers, as protobufjs does: `end_time` (3),
`start_time` (4), `duration_ns` (11), `root` (14) and
`field_execution_weight` (31). A `TraceNode` has `response_name` (1) or
`index` (2), `type` (3), `start_time` (8), `end_time` (9), `error` (11),
`child` (12), `parent_type` (13) and `original_field_name` (14). A
`TraceError` has `message` (1), `location` (2), `time_ns` (3) and `json`
(4); a `TraceLocation` has `line` (1) and `column` (2).

`Trace.decode` reads these fields and skips every other field, as
protobufjs `Trace.decode` reads the fields it knows.

**Differences from upstream.**
- Only the fields above are ported. The other fields of `Trace`, such as
  `query_plan`, `http` and `cache_policy`, are not: the inline trace
  plugin does not set them.
- The nodes of a trace are in one list, `Trace.nodes`, and a node holds
  the indexes of its children. `Trace.nodes[0]` is the root.
- A field with the default value is not written, as in proto3. The
  `response_name` and `index` of a node are a `oneof`, so the one that is
  set is always written.
- `Trace.decode` does not check that a string is UTF-8.
"""

from std.memory import bitcast


@fieldwise_init
struct Timestamp(Copyable, Equatable, ImplicitlyCopyable, Movable):
    """A point in time: `google.protobuf.Timestamp`."""

    var seconds: Int
    """The seconds since the Unix epoch: field 1."""
    var nanos: Int
    """The nanoseconds of the second: field 2."""


@fieldwise_init
struct TraceLocation(Copyable, Equatable, ImplicitlyCopyable, Movable):
    """A location in the query: upstream `Trace.Location`."""

    var line: Int
    """The line, from 1: field 1."""
    var column: Int
    """The column, from 1: field 2."""


struct TraceError(Copyable, Movable):
    """An error at a node: upstream `Trace.Error`."""

    var message: String
    """The message: field 1."""
    var location: List[TraceLocation]
    """The locations: field 2."""
    var time_ns: Int
    """The time of the error: field 3. The plugin does not set it."""
    var json: String
    """The JSON of the error: field 4."""

    def __init__(out self, message: String = ""):
        """Make an error.

        Args:
            message: The message.
        """
        self.message = message
        self.location = List[TraceLocation]()
        self.time_ns = 0
        self.json = String("")


struct TraceNode(Copyable, Movable):
    """A field or a list item of the response: upstream `Trace.Node`."""

    var response_name: Optional[String]
    """The response key of a field: field 1, of the `id` oneof."""
    var index: Optional[Int]
    """The index of a list item: field 2, of the `id` oneof."""
    var original_field_name: String
    """The field name of an aliased field: field 14."""
    var type: String
    """The type of the field, such as `[String!]!`: field 3."""
    var parent_type: String
    """The object type of the field: field 13."""
    var start_time: Int
    """The start of the resolver, in nanoseconds from the start of the
    trace: field 8."""
    var end_time: Int
    """The end of the resolver, in nanoseconds from the start of the
    trace: field 9."""
    var error: List[TraceError]
    """The errors at this node: field 11."""
    var child: List[Int]
    """The indexes in `Trace.nodes` of the children: field 12."""

    def __init__(out self):
        """Make a node with no id, such as the root."""
        self.response_name = None
        self.index = None
        self.original_field_name = String("")
        self.type = String("")
        self.parent_type = String("")
        self.start_time = 0
        self.end_time = 0
        self.error = List[TraceError]()
        self.child = List[Int]()


struct Trace(Copyable, Movable):
    """A trace: the fields of upstream `Trace` that the inline trace
    plugin sets."""

    var start_time: Timestamp
    """The wall clock time of the start: field 4."""
    var end_time: Timestamp
    """The wall clock time of the end: field 3."""
    var duration_ns: Int
    """The duration in nanoseconds: field 11."""
    var nodes: List[TraceNode]
    """The nodes; `nodes[0]` is the root, field 14."""
    var field_execution_weight: Float64
    """The weight of the trace in the field statistics: field 31."""

    def __init__(out self):
        """Make a trace with only a root node."""
        self.start_time = Timestamp(0, 0)
        self.end_time = Timestamp(0, 0)
        self.duration_ns = 0
        self.nodes = List[TraceNode]()
        self.nodes.append(TraceNode())
        self.field_execution_weight = 0

    def encode(self) -> List[UInt8]:
        """Return the protobuf encoding: upstream
        `Trace.encode(trace).finish()`.

        Returns:
            The bytes.
        """
        var sizes = _node_sizes(self)
        var writer = _Writer(sizes[0] + 64)
        writer.message_key(3, _timestamp_size(self.end_time))
        writer.timestamp(self.end_time)
        writer.message_key(4, _timestamp_size(self.start_time))
        writer.timestamp(self.start_time)
        writer.uint(11, self.duration_ns)
        writer.message_key(14, sizes[0])
        writer.tree(self, sizes)
        if self.field_execution_weight != 0:
            writer.varint(UInt64(31 << 3 | 1))
            var bits = bitcast[DType.uint64](self.field_execution_weight)
            var shift = UInt64(0)
            while shift < 64:
                writer.out.append(UInt8((bits >> shift) & 255))
                shift += 8
        return writer^.take()

    @staticmethod
    def decode(bytes: Span[UInt8, _]) raises -> Trace:
        """Read a trace from its protobuf encoding: upstream
        `Trace.decode`.

        Args:
            bytes: The bytes.

        Returns:
            The trace; a field that this module does not port is skipped.

        Raises:
            Error: When the bytes end inside a field, or a field has a
                wire type that protobuf does not define.
        """
        var trace = Trace()
        var pos = 0
        var end = len(bytes)
        while pos < end:
            var key = _read_varint(bytes, pos, end)
            if key == 26:
                var stop = _read_length(bytes, pos, end)
                trace.end_time = _decode_timestamp(bytes, pos, stop)
                pos = stop
            elif key == 34:
                var stop = _read_length(bytes, pos, end)
                trace.start_time = _decode_timestamp(bytes, pos, stop)
                pos = stop
            elif key == 88:
                trace.duration_ns = Int(_read_varint(bytes, pos, end))
            elif key == 114:
                var stop = _read_length(bytes, pos, end)
                _decode_node(trace, bytes, pos, stop)
                pos = stop
            elif key == 249:
                if pos + 8 > end:
                    raise Error("protobuf: the message ends inside a field")
                var bits = UInt64(0)
                var at = 0
                while at < 8:
                    bits |= UInt64(bytes[pos + at]) << UInt64(at * 8)
                    at += 1
                trace.field_execution_weight = bitcast[DType.float64](bits)
                pos += 8
            else:
                _skip(bytes, pos, end, Int(key & 7))
        return trace^


def _varint_size(value: UInt64) -> Int:
    """Return the size of a varint."""
    var size = 1
    var rest = value >> 7
    while rest != 0:
        size += 1
        rest >>= 7
    return size


def _uint_size(field: Int, value: Int) -> Int:
    """Return the size of a varint field; 0 for the default value."""
    if value == 0:
        return 0
    return _varint_size(UInt64(field << 3)) + _varint_size(UInt64(value))


def _text_size(field: Int, value: StringSlice) -> Int:
    """Return the size of a string field; 0 for the empty string."""
    if value.byte_length() == 0:
        return 0
    return _length_size(field, value.byte_length())


def _length_size(field: Int, length: Int) -> Int:
    """Return the size of a length-delimited field of `length` bytes."""
    return (
        _varint_size(UInt64(field << 3))
        + _varint_size(UInt64(length))
        + (length)
    )


def _timestamp_size(time: Timestamp) -> Int:
    """Return the size of the body of a timestamp."""
    return _uint_size(1, time.seconds) + _uint_size(2, time.nanos)


def _location_size(location: TraceLocation) -> Int:
    """Return the size of the body of a location."""
    return _uint_size(1, location.line) + _uint_size(2, location.column)


def _error_size(error: TraceError) -> Int:
    """Return the size of the body of an error."""
    var size = _text_size(1, error.message)
    for ref location in error.location:
        size += _length_size(2, _location_size(location))
    size += _uint_size(3, error.time_ns)
    return size + _text_size(4, error.json)


def _node_sizes(trace: Trace) -> List[Int]:
    """Return the size of the body of each node. The nodes are visited in
    reverse preorder, so that the children of a node come before it."""
    var order = List[Int](capacity=len(trace.nodes))
    var stack: List[Int] = [0]
    while len(stack) > 0:
        var node = stack.pop()
        order.append(node)
        for child in trace.nodes[node].child:
            stack.append(child)
    var sizes = List[Int](length=len(trace.nodes), fill=0)
    var at = len(order) - 1
    while at >= 0:
        var node = order[at]
        ref found = trace.nodes[node]
        var size = 0
        if found.index:
            size += 1 + _varint_size(UInt64(found.index.value()))
        elif found.response_name:
            size += _length_size(1, found.response_name.value().byte_length())
        size += _text_size(3, found.type)
        size += _uint_size(8, found.start_time)
        size += _uint_size(9, found.end_time)
        for ref error in found.error:
            size += _length_size(11, _error_size(error))
        for child in found.child:
            size += _length_size(12, sizes[child])
        size += _text_size(13, found.parent_type)
        size += _text_size(14, found.original_field_name)
        sizes[node] = size
        at -= 1
    return sizes^


struct _Writer(Movable):
    """The bytes of an encoding, as protobufjs `Writer`."""

    var out: List[UInt8]

    def __init__(out self, capacity: Int):
        self.out = List[UInt8](capacity=capacity)

    def take(deinit self) -> List[UInt8]:
        """End the writer and return its bytes."""
        return self.out^

    def varint(mut self, var value: UInt64):
        while value >= 0x80:
            self.out.append(UInt8(value & 0x7F) | 0x80)
            value >>= 7
        self.out.append(UInt8(value))

    def uint(mut self, field: Int, value: Int):
        if value != 0:
            self.varint(UInt64(field << 3))
            self.varint(UInt64(value))

    def message_key(mut self, field: Int, size: Int):
        self.varint(UInt64(field << 3 | 2))
        self.varint(UInt64(size))

    def bytes(mut self, field: Int, value: StringSlice):
        self.message_key(field, value.byte_length())
        self.out.extend(value.as_bytes())

    def text(mut self, field: Int, value: StringSlice):
        if value.byte_length() > 0:
            self.bytes(field, value)

    def timestamp(mut self, time: Timestamp):
        self.uint(1, time.seconds)
        self.uint(2, time.nanos)

    def error(mut self, error: TraceError):
        self.text(1, error.message)
        for ref location in error.location:
            self.message_key(2, _location_size(location))
            self.uint(1, location.line)
            self.uint(2, location.column)
        self.uint(3, error.time_ns)
        self.text(4, error.json)

    def head(mut self, node: TraceNode):
        """Write the fields of a node before its children."""
        if node.index:
            self.varint(UInt64(2 << 3))
            self.varint(UInt64(node.index.value()))
        elif node.response_name:
            self.bytes(1, node.response_name.value())
        self.text(3, node.type)
        self.uint(8, node.start_time)
        self.uint(9, node.end_time)
        for ref error in node.error:
            self.message_key(11, _error_size(error))
            self.error(error)

    def tree(mut self, trace: Trace, sizes: List[Int]):
        """Write the body of the root and of its descendants, with a stack
        of the nodes and of the next child of each."""
        var nodes: List[Int] = [0]
        var next: List[Int] = [0]
        self.head(trace.nodes[0])
        while len(nodes) > 0:
            ref found = trace.nodes[nodes[len(nodes) - 1]]
            var at = next[len(next) - 1]
            if at < len(found.child):
                var child = found.child[at]
                next[len(next) - 1] = at + 1
                self.message_key(12, sizes[child])
                self.head(trace.nodes[child])
                nodes.append(child)
                next.append(0)
            else:
                self.text(13, found.parent_type)
                self.text(14, found.original_field_name)
                _ = nodes.pop()
                _ = next.pop()


def _read_varint(
    bytes: Span[UInt8, _], mut pos: Int, end: Int
) raises -> UInt64:
    """Read a varint at `pos`."""
    var value = UInt64(0)
    var shift = 0
    while True:
        if pos >= end:
            raise Error("protobuf: the message ends inside a field")
        if shift > 63:
            raise Error("protobuf: a varint is longer than 10 bytes")
        var byte = bytes[pos]
        pos += 1
        value |= UInt64(byte & 0x7F) << UInt64(shift)
        if byte < 0x80:
            return value
        shift += 7


def _read_length(bytes: Span[UInt8, _], mut pos: Int, end: Int) raises -> Int:
    """Read the length of a length-delimited field, and return its end."""
    var length = Int(_read_varint(bytes, pos, end))
    if length > end - pos:
        raise Error("protobuf: the message ends inside a field")
    return pos + length


def _read_text(bytes: Span[UInt8, _], mut pos: Int, end: Int) raises -> String:
    """Read a string field at `pos`."""
    var stop = _read_length(bytes, pos, end)
    var text = String(unsafe_from_utf8=bytes[pos:stop])
    pos = stop
    return text^


def _skip(bytes: Span[UInt8, _], mut pos: Int, end: Int, wire: Int) raises:
    """Skip the value of a field that is not read."""
    if wire == 0:
        _ = _read_varint(bytes, pos, end)
        return
    if wire == 2:
        pos = _read_length(bytes, pos, end)
        return
    var size: Int
    if wire == 1:
        size = 8
    elif wire == 5:
        size = 4
    else:
        raise Error("protobuf: invalid wire type " + String(wire))
    if size > end - pos:
        raise Error("protobuf: the message ends inside a field")
    pos += size


def _decode_timestamp(
    bytes: Span[UInt8, _], var pos: Int, end: Int
) raises -> Timestamp:
    """Read the body of a timestamp."""
    var time = Timestamp(0, 0)
    while pos < end:
        var key = _read_varint(bytes, pos, end)
        if key == 8:
            time.seconds = Int(_read_varint(bytes, pos, end))
        elif key == 16:
            time.nanos = Int(_read_varint(bytes, pos, end))
        else:
            _skip(bytes, pos, end, Int(key & 7))
    return time


def _decode_location(
    bytes: Span[UInt8, _], var pos: Int, end: Int
) raises -> TraceLocation:
    """Read the body of a location."""
    var location = TraceLocation(0, 0)
    while pos < end:
        var key = _read_varint(bytes, pos, end)
        if key == 8:
            location.line = Int(_read_varint(bytes, pos, end))
        elif key == 16:
            location.column = Int(_read_varint(bytes, pos, end))
        else:
            _skip(bytes, pos, end, Int(key & 7))
    return location


def _decode_error(
    bytes: Span[UInt8, _], var pos: Int, end: Int
) raises -> TraceError:
    """Read the body of an error."""
    var error = TraceError()
    while pos < end:
        var key = _read_varint(bytes, pos, end)
        if key == 10:
            error.message = _read_text(bytes, pos, end)
        elif key == 18:
            var stop = _read_length(bytes, pos, end)
            error.location.append(_decode_location(bytes, pos, stop))
            pos = stop
        elif key == 24:
            error.time_ns = Int(_read_varint(bytes, pos, end))
        elif key == 34:
            error.json = _read_text(bytes, pos, end)
        else:
            _skip(bytes, pos, end, Int(key & 7))
    return error^


def _decode_node(
    mut trace: Trace, bytes: Span[UInt8, _], var pos: Int, root_end: Int
) raises:
    """Read the body of the root into `trace.nodes[0]`, and its
    descendants, with a stack of the open nodes and of their ends."""
    var nodes: List[Int] = [0]
    var ends: List[Int] = [root_end]
    while len(nodes) > 0:
        var node = nodes[len(nodes) - 1]
        var end = ends[len(ends) - 1]
        if pos >= end:
            _ = nodes.pop()
            _ = ends.pop()
            continue
        var key = _read_varint(bytes, pos, end)
        if key == 10:
            trace.nodes[node].response_name = _read_text(bytes, pos, end)
            trace.nodes[node].index = None
        elif key == 16:
            trace.nodes[node].index = Int(_read_varint(bytes, pos, end))
            trace.nodes[node].response_name = None
        elif key == 26:
            trace.nodes[node].type = _read_text(bytes, pos, end)
        elif key == 64:
            trace.nodes[node].start_time = Int(_read_varint(bytes, pos, end))
        elif key == 72:
            trace.nodes[node].end_time = Int(_read_varint(bytes, pos, end))
        elif key == 90:
            var stop = _read_length(bytes, pos, end)
            trace.nodes[node].error.append(_decode_error(bytes, pos, stop))
            pos = stop
        elif key == 98:
            var child_end = _read_length(bytes, pos, end)
            var child = len(trace.nodes)
            trace.nodes.append(TraceNode())
            trace.nodes[node].child.append(child)
            nodes.append(child)
            ends.append(child_end)
        elif key == 106:
            trace.nodes[node].parent_type = _read_text(bytes, pos, end)
        elif key == 114:
            trace.nodes[node].original_field_name = _read_text(bytes, pos, end)
        else:
            _skip(bytes, pos, end, Int(key & 7))

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The QPACK decoder (RFC 9204 sections 2.2, 3.2 and 4).

`QpackDecoder.decode` reads one field section into a `FieldList`. The
names and the values are decoded straight into the buffer of the list.
`on_encoder_stream` applies the instructions of the peer's encoder stream
to the dynamic table. The bytes can arrive in any pieces: an instruction
that is not complete waits for the next call.

The decoder writes the instructions of its own decoder stream into a
buffer, and `take_decoder_stream` hands them over: an Insert Count
Increment after each call of `on_encoder_stream` that inserted entries, a
Section Acknowledgment after each section with dynamic references, and a
Stream Cancellation from `cancel_stream`.

A blocked stream: when a section needs entries that have not arrived,
`decode` returns False and keeps nothing. The caller keeps the section,
and calls `decode` again when `insert_count()` reaches
`required_insert_count`. The decoder counts the blocked streams, and
refuses more than `max_blocked_streams`.

The field section size limit: the sum of the field sizes (the name, the
value and 32) must not exceed `max_field_section_size`, or `decode` raises
`H3_EXCESSIVE_LOAD`. A server answers that with status 431.

This module ports `h3/src/qpack/decoder.rs` of hyperium/h3 h3-v0.0.8
(22c1aa3), MIT.

Differences from upstream: upstream returns `MissingRefs` for a blocked
section; here `decode` returns False and counts the blocked stream. The
size limit applies to every section; upstream checks it in
`decode_stateless` only, and returns `HeaderTooLong`. The decoder refuses a
dynamic reference at or above the Required Insert Count, an entry larger
than the capacity, and a capacity above the maximum, as RFC 9204 requires;
upstream does not check them. Upstream's `ack_header` and
`stream_canceled` are `cancel_stream` and the automatic acknowledgment.
"""

from gql_http3.error import H3Error, H3ErrorCode
from gql_http3.qpack_block import (
    EncoderInstructionKind,
    FieldLineKind,
    HeaderPrefix,
    decode_header_prefix,
    decompression_failed,
    to_index,
    write_insert_count_increment,
    write_section_ack,
    write_stream_cancel,
)
from gql_http3.qpack_field import ENTRY_OVERHEAD, FieldList, field_size
from gql_http3.qpack_prefix import decode_prefix_int, decode_prefix_string
from gql_http3.qpack_static import STATIC_TABLE_SIZE, static_name, static_value
from gql_http3.qpack_table import DynamicTable

comptime NO_LIMIT = Int.MAX
"""A field section size limit that never applies."""


def _truncated() -> H3Error:
    """Return the error of a field line that the section cuts."""
    return decompression_failed("truncated field line")


@always_inline
def _static_index(value: UInt64) raises H3Error -> Int:
    """Return a static index, or raise for one past the table."""
    if value >= UInt64(STATIC_TABLE_SIZE):
        raise decompression_failed(String("bad static index ", value))
    return Int(value)


struct QpackDecoder(Movable):
    """The decoding side of a QPACK connection: the table of the peer's
    encoder, and the decoder stream to send back."""

    var table: DynamicTable
    """The dynamic table, filled by the encoder stream."""
    var max_table_capacity: Int
    """SETTINGS_QPACK_MAX_TABLE_CAPACITY that this endpoint sends."""
    var max_blocked_streams: Int
    """SETTINGS_QPACK_BLOCKED_STREAMS that this endpoint sends."""
    var max_field_section_size: Int
    """The largest field section to accept, by field sizes."""
    var required_insert_count: Int
    """The Required Insert Count of the last section that `decode` read
    or found blocked."""
    var _blocked: List[UInt64]
    """The streams whose section waits for entries."""
    var _pending: List[UInt8]
    """Encoder stream bytes of an instruction that is not complete."""
    var _out: List[UInt8]
    """Decoder stream bytes to send."""
    var _scratch: List[UInt8]
    """The name and the value of an entry to insert."""

    def __init__(
        out self,
        max_table_capacity: Int = 0,
        max_blocked_streams: Int = 0,
        max_field_section_size: Int = NO_LIMIT,
    ):
        """Make a decoder with an empty table of capacity 0.

        Args:
            max_table_capacity: The maximum capacity that the encoder can
                set; 0 allows the static table and literals only.
            max_blocked_streams: How many streams can wait for entries.
            max_field_section_size: The field section size limit.
        """
        self.table = DynamicTable()
        self.max_table_capacity = max_table_capacity
        self.max_blocked_streams = max_blocked_streams
        self.max_field_section_size = max_field_section_size
        self.required_insert_count = 0
        self._blocked = List[UInt64]()
        self._pending = List[UInt8]()
        self._out = List[UInt8]()
        self._scratch = List[UInt8]()

    def insert_count(self) -> Int:
        """Return the number of entries that the encoder stream inserted.

        Returns:
            The insert count.
        """
        return self.table.insert_count()

    def blocked_streams(self) -> Int:
        """Return the number of streams whose section waits for entries.

        Returns:
            The count.
        """
        return len(self._blocked)

    def _blocked_index(self, stream_id: UInt64) -> Int:
        """Return the position of a stream in the blocked list, or -1."""
        var index = 0
        while index < len(self._blocked):
            if self._blocked[index] == stream_id:
                return index
            index += 1
        return -1

    def _unblock(mut self, stream_id: UInt64):
        """Remove a stream from the blocked list."""
        var index = self._blocked_index(stream_id)
        if index >= 0:
            _ = self._blocked.pop(index)

    def take_decoder_stream(mut self, mut out: List[UInt8]):
        """Move the decoder stream bytes to send into `out`.

        Args:
            out: The destination; the bytes are appended.
        """
        out.extend(self._out)
        self._out.clear()

    def cancel_stream(mut self, stream_id: UInt64):
        """Forget a stream that was reset or abandoned, and tell the
        encoder with a Stream Cancellation.

        With a maximum capacity of 0, no instruction is sent (RFC 9204
        section 4.4.2).

        Args:
            stream_id: The stream.
        """
        self._unblock(stream_id)
        if self.max_table_capacity > 0:
            write_stream_cancel(stream_id, self._out)

    @always_inline
    def _dynamic(
        self, base: Int, index: Int, required: Int, post_base: Bool
    ) raises H3Error -> Int:
        """Return the absolute index of a dynamic reference of a section."""
        var absolute: Int
        if post_base:
            absolute = self.table.after_base(base, index)
        else:
            absolute = self.table.before_base(base, index)
        if absolute >= required:
            raise decompression_failed("reference above the insert count")
        return absolute

    def decode(
        mut self, stream_id: UInt64, block: Span[UInt8, _], mut fields: FieldList
    ) raises H3Error -> Bool:
        """Decode a field section: the payload of a HEADERS frame.

        Args:
            stream_id: The stream of the section.
            block: The encoded field section.
            fields: Cleared, then filled with the fields in order.

        Returns:
            True when the section is decoded. False when it needs entries
            that the encoder stream has not inserted yet: the stream is
            blocked, and `required_insert_count` says how many entries it
            needs.

        Raises:
            H3Error: `QPACK_DECOMPRESSION_FAILED` for a malformed section,
                or too many blocked streams; `H3_EXCESSIVE_LOAD` when the
                section exceeds `max_field_section_size`.
        """
        fields.clear()
        var prefix = HeaderPrefix(0, False, 0)
        var at = decode_header_prefix(block, prefix)
        var counts = prefix.get(self.table.insert_count(), self.max_table_capacity)
        var required = counts[0]
        var base = counts[1]
        self.required_insert_count = required
        if required > self.table.insert_count():
            if self._blocked_index(stream_id) < 0:
                if len(self._blocked) >= self.max_blocked_streams:
                    raise decompression_failed("too many blocked streams")
                self._blocked.append(stream_id)
            return False
        self._unblock(stream_id)
        var n = len(block)
        var p = block.unsafe_ptr()
        var limit = self.max_field_section_size
        while at < n:
            var before = len(fields.data)
            var kind = FieldLineKind.of(p[unsafe_offset=at])
            if kind == FieldLineKind.INDEXED:
                var head = decode_prefix_int(6, block, at)
                if not head.complete():
                    raise _truncated()
                at = head.end
                if head.flags & 1 == 1:
                    var index = _static_index(head.value)
                    fields.add(
                        static_name(index).as_bytes(),
                        static_value(index).as_bytes(),
                    )
                else:
                    var a = self._dynamic(
                        base, to_index(head.value), required, False
                    )
                    fields.add(self.table.name(a), self.table.value(a))
            elif kind == FieldLineKind.INDEXED_POST_BASE:
                var head = decode_prefix_int(4, block, at)
                if not head.complete():
                    raise _truncated()
                at = head.end
                var a = self._dynamic(base, to_index(head.value), required, True)
                fields.add(self.table.name(a), self.table.value(a))
            elif kind == FieldLineKind.LITERAL:
                var name = decode_prefix_string(4, block, at, fields.data)
                if not name.complete():
                    raise _truncated()
                fields._end_name()
                var value = decode_prefix_string(8, block, name.end, fields.data)
                if not value.complete():
                    raise _truncated()
                fields._end_value()
                at = value.end
            else:
                var post_base = kind == FieldLineKind.LITERAL_POST_BASE_NAME_REF
                var size = 3 if post_base else 4
                var head = decode_prefix_int(size, block, at)
                if not head.complete():
                    raise _truncated()
                if not post_base and head.flags & 1 == 1:
                    var index = _static_index(head.value)
                    fields.data.extend(static_name(index).as_bytes())
                else:
                    var a = self._dynamic(
                        base, to_index(head.value), required, post_base
                    )
                    fields.data.extend(self.table.name(a))
                fields._end_name()
                var value = decode_prefix_string(8, block, head.end, fields.data)
                if not value.complete():
                    raise _truncated()
                fields._end_value()
                at = value.end
            limit -= len(fields.data) - before + ENTRY_OVERHEAD
            if limit < 0:
                raise H3Error(
                    H3ErrorCode.H3_EXCESSIVE_LOAD, "field section too large"
                )
        if required > 0:
            write_section_ack(stream_id, self._out)
        return True

    def on_encoder_stream(mut self, data: Span[UInt8, _]) raises H3Error:
        """Apply the instructions of the peer's encoder stream.

        An instruction that the bytes cut waits for the next call. After
        the call, the decoder stream holds an Insert Count Increment for
        the entries that it inserted.

        Args:
            data: The next bytes of the encoder stream.

        Raises:
            H3Error: `QPACK_ENCODER_STREAM_ERROR` for an instruction that is
                malformed or that the table cannot apply.
        """
        var buffer = self._pending^
        self._pending = List[UInt8]()
        buffer.extend(data)
        var before = self.table.insert_count()
        var at = 0
        try:
            while at < len(buffer):
                var end = self._apply(Span(buffer), at)
                if end < 0:
                    break
                at = end
        except e:
            raise H3Error(H3ErrorCode.QPACK_ENCODER_STREAM_ERROR, e.message)
        self._pending.extend(Span(buffer)[at:])
        var inserted = self.table.insert_count() - before
        if inserted > 0:
            write_insert_count_increment(inserted, self._out)

    def _insert_scratch(mut self, name_length: Int) raises H3Error:
        """Insert the entry that `_scratch` holds: the name, then the value."""
        var size = field_size(name_length, len(self._scratch) - name_length)
        if size > self.table.capacity:
            raise decompression_failed("entry larger than the capacity")
        var entry = Span(self._scratch)
        self.table.insert(entry[:name_length], entry[name_length:])

    def _apply(mut self, data: Span[UInt8, _], at: Int) raises H3Error -> Int:
        """Apply one instruction; return its end, or -1 when it is cut."""
        var kind = EncoderInstructionKind.of(data[at])
        self._scratch.clear()
        if kind == EncoderInstructionKind.SET_CAPACITY:
            var head = decode_prefix_int(5, data, at)
            if not head.complete():
                return -1
            if head.value > UInt64(self.max_table_capacity):
                raise decompression_failed("capacity above the maximum")
            self.table.set_capacity(Int(head.value))
            return head.end
        if kind == EncoderInstructionKind.DUPLICATE:
            var head = decode_prefix_int(5, data, at)
            if not head.complete():
                return -1
            var a = self.table.from_insert_count(to_index(head.value))
            self._scratch.extend(self.table.name(a))
            var name_length = len(self._scratch)
            self._scratch.extend(self.table.value(a))
            self._insert_scratch(name_length)
            return head.end
        var end: Int
        if kind == EncoderInstructionKind.INSERT_LITERAL:
            end = decode_prefix_string(6, data, at, self._scratch).end
        else:
            var head = decode_prefix_int(6, data, at)
            if not head.complete():
                return -1
            if head.flags & 1 == 1:
                var index = _static_index(head.value)
                self._scratch.extend(static_name(index).as_bytes())
            else:
                var a = self.table.from_insert_count(to_index(head.value))
                self._scratch.extend(self.table.name(a))
            end = head.end
        var name_length = len(self._scratch)
        if end == at:
            return -1
        var value = decode_prefix_string(8, data, end, self._scratch)
        if not value.complete():
            return -1
        self._insert_scratch(name_length)
        return value.end

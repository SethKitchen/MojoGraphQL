# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The QPACK encoder (RFC 9204 sections 2.1, 3.2 and 4).

`QpackEncoder.encode` writes one field section. With a table capacity of
0, the default, it uses the static table and literals only, as h3 does on
its connections: an indexed line for an exact match, a literal with the
static name for a name match, else a literal. A string is Huffman coded
when that is shorter.

`set_capacity` turns the dynamic table on, up to the maximum that the
peer's SETTINGS allow. The encoder then inserts each field that the static
table does not match, as upstream does, and references it with a
post-base index. It references an entry that the decoder has not
acknowledged only when the stream can block: it already waits, or fewer
than `max_blocked_streams` streams wait. It never evicts an entry that a
field section still references.

`on_decoder_stream` reads the peer's decoder stream: a Section
Acknowledgment releases the references of the oldest section of a stream,
a Stream Cancellation those of every section of a stream, and an Insert
Count Increment raises the Known Received Count.

This module ports `h3/src/qpack/encoder.rs` and the encoder side of
`h3/src/qpack/dynamic.rs` of hyperium/h3 h3-v0.0.8 (22c1aa3), MIT.

Differences from upstream: the base of a section is the insert count, and
the Required Insert Count is encoded against the maximum capacity of the
peer, as RFC 9204 section 4.5.1 says; upstream uses the number of live
entries and the current capacity, which disagree with the decoder after an
eviction. A Section Acknowledgment raises the Known Received Count, and a
section can block only within `max_blocked_streams`; upstream inserts
entries but references them in any stream. The encoder does not send
Duplicate instructions. An Insert Count Increment of 0 or above the insert
count, and an acknowledgment of a stream without sections, are
`QPACK_DECODER_STREAM_ERROR`, as RFC 9204 section 4.4 requires. The
static-only path is upstream's `encode_stateless`.
"""

from gql_http3.error import H3Error, H3ErrorCode
from gql_http3.qpack_block import (
    DecoderInstructionKind,
    HeaderPrefix,
    to_index,
    write_indexed_dynamic,
    write_indexed_post_base,
    write_indexed_static,
    write_insert_dynamic_name,
    write_insert_literal,
    write_insert_static_name,
    write_literal,
    write_literal_dynamic_name,
    write_literal_post_base_name,
    write_literal_static_name,
    write_set_capacity,
)
from gql_http3.qpack_field import FieldList, field_size
from gql_http3.qpack_prefix import decode_prefix_int
from gql_http3.qpack_static import static_find
from gql_http3.qpack_table import DynamicTable


@fieldwise_init
struct _Section(Copyable, Movable):
    """A field section with dynamic references that is not acknowledged."""

    var stream_id: UInt64
    """The stream of the section."""
    var required: Int
    """Its Required Insert Count."""
    var refs: List[Int]
    """The absolute index of each reference, one per reference."""


def _decoder_stream_error(message: String) -> H3Error:
    """Return a `QPACK_DECODER_STREAM_ERROR`."""
    return H3Error(H3ErrorCode.QPACK_DECODER_STREAM_ERROR, message)


@always_inline
def encode_static_field(
    name: Span[UInt8, _], value: Span[UInt8, _], mut out: List[UInt8]
):
    """Append the field line of a field with the static table only.

    Args:
        name: The name, in lowercase.
        value: The value.
        out: The field section.
    """
    var hit = static_find(name, value)
    if hit.exact >= 0:
        write_indexed_static(hit.exact, out)
    elif hit.name >= 0:
        write_literal_static_name(hit.name, value, out)
    else:
        write_literal(name, value, out)


struct QpackEncoder(Movable):
    """The encoding side of a QPACK connection: the table that the peer's
    decoder mirrors, and the references that it has not acknowledged."""

    var table: DynamicTable
    """The dynamic table."""
    var max_table_capacity: Int
    """SETTINGS_QPACK_MAX_TABLE_CAPACITY of the peer."""
    var max_blocked_streams: Int
    """SETTINGS_QPACK_BLOCKED_STREAMS of the peer."""
    var known_received: Int
    """The Known Received Count: the entries that the decoder has."""
    var _sections: List[_Section]
    """The sections with dynamic references, oldest first."""
    var _refs: List[Int]
    """The references of the section being encoded."""
    var _lines: List[UInt8]
    """The field lines of the section being encoded."""
    var _pending: List[UInt8]
    """Decoder stream bytes of an instruction that is not complete."""

    def __init__(
        out self, max_table_capacity: Int = 0, max_blocked_streams: Int = 0
    ):
        """Make an encoder with a table of capacity 0.

        Args:
            max_table_capacity: SETTINGS_QPACK_MAX_TABLE_CAPACITY of the
                peer; 0 keeps the encoder to the static table.
            max_blocked_streams: SETTINGS_QPACK_BLOCKED_STREAMS of the peer.
        """
        self.table = DynamicTable()
        self.max_table_capacity = max_table_capacity
        self.max_blocked_streams = max_blocked_streams
        self.known_received = 0
        self._sections = List[_Section]()
        self._refs = List[Int]()
        self._lines = List[UInt8]()
        self._pending = List[UInt8]()

    def set_capacity(
        mut self, capacity: Int, mut encoder_stream: List[UInt8]
    ) raises H3Error:
        """Set the capacity of the table, and tell the decoder.

        Args:
            capacity: The new capacity, at most `max_table_capacity`.
            encoder_stream: Receives a Set Dynamic Table Capacity.

        Raises:
            H3Error: `H3_INTERNAL_ERROR` for a capacity above the maximum,
                or when referenced entries do not fit the new capacity.
        """
        if capacity > self.max_table_capacity:
            raise H3Error(
                H3ErrorCode.H3_INTERNAL_ERROR, "capacity above the maximum"
            )
        var free = self.table.capacity - capacity
        if free > 0 and not self.table.can_free(free):
            raise H3Error(
                H3ErrorCode.H3_INTERNAL_ERROR, "referenced entries do not fit"
            )
        self.table.set_capacity(capacity)
        write_set_capacity(capacity, encoder_stream)

    def blocked_streams(self) -> Int:
        """Return the number of streams whose sections can block.

        Returns:
            The streams with a section whose Required Insert Count is above
            the Known Received Count.
        """
        var streams = List[UInt64]()
        for ref section in self._sections:
            if section.required > self.known_received:
                if section.stream_id not in streams:
                    streams.append(section.stream_id)
        return len(streams)

    def _may_block(self, stream_id: UInt64) -> Bool:
        """Return True when a section of a stream may reference entries that
        the decoder does not have yet."""
        for ref section in self._sections:
            if section.stream_id == stream_id:
                if section.required > self.known_received:
                    return True
        return self.blocked_streams() < self.max_blocked_streams

    def _reference(mut self, absolute: Int):
        """Count a reference of the section being encoded."""
        self.table.add_ref(absolute, 1)
        self._refs.append(absolute)

    def _insert(
        mut self,
        name: Span[UInt8, _],
        value: Span[UInt8, _],
        static_name: Int,
        mut encoder_stream: List[UInt8],
    ) -> Bool:
        """Insert a field if it fits; return True when it was inserted."""
        if not self.table.can_free(field_size(len(name), len(value))):
            return False
        if static_name >= 0:
            write_insert_static_name(static_name, value, encoder_stream)
        else:
            var named = self.table.find_name(name)
            if named >= 0:
                var relative = self.table.insert_count() - 1 - named
                write_insert_dynamic_name(relative, value, encoder_stream)
            else:
                write_insert_literal(name, value, encoder_stream)
        self.table.insert(name, value)
        return True

    def encode(
        mut self,
        stream_id: UInt64,
        fields: FieldList,
        mut out_block: List[UInt8],
        mut out_encoder_stream: List[UInt8],
    ) -> Int:
        """Encode a field section: the payload of a HEADERS frame.

        Args:
            stream_id: The stream of the section.
            fields: The fields, with lowercase names.
            out_block: Receives the field section.
            out_encoder_stream: Receives the insertions, if any.

        Returns:
            The Required Insert Count of the section; 0 when it references
            no dynamic entry.
        """
        var count = fields.count()
        if self.table.capacity == 0:
            out_block.append(0)
            out_block.append(0)
            var index = 0
            while index < count:
                encode_static_field(
                    fields.name(index), fields.value(index), out_block
                )
                index += 1
            return 0
        var base = self.table.insert_count()
        var may_block = self._may_block(stream_id)
        self._refs.clear()
        self._lines.clear()
        var index = 0
        while index < count:
            self._encode_field(
                fields.name(index),
                fields.value(index),
                base,
                may_block,
                out_encoder_stream,
            )
            index += 1
        var required = 0
        for absolute in self._refs:
            required = max(required, absolute + 1)
        HeaderPrefix.new(
            required, base, self.table.insert_count(), self.max_table_capacity
        ).encode(out_block)
        out_block.extend(Span(self._lines))
        if required > 0:
            self._sections.append(
                _Section(stream_id, required, self._refs.copy())
            )
        return required

    def _encode_field(
        mut self,
        name: Span[UInt8, _],
        value: Span[UInt8, _],
        base: Int,
        may_block: Bool,
        mut encoder_stream: List[UInt8],
    ):
        """Append the field line of one field, with the dynamic table."""
        var hit = static_find(name, value)
        if hit.exact >= 0:
            write_indexed_static(hit.exact, self._lines)
            return
        var found = self.table.find(name, value)
        if found >= 0 and (may_block or found < self.known_received):
            self._reference(found)
            if found < base:
                write_indexed_dynamic(base - 1 - found, self._lines)
            else:
                write_indexed_post_base(found - base, self._lines)
            return
        if may_block and self._insert(name, value, hit.name, encoder_stream):
            var inserted = self.table.insert_count() - 1
            self._reference(inserted)
            write_indexed_post_base(inserted - base, self._lines)
            return
        if hit.name >= 0:
            write_literal_static_name(hit.name, value, self._lines)
            return
        var named = self.table.find_name(name)
        if named >= 0 and (may_block or named < self.known_received):
            self._reference(named)
            if named < base:
                write_literal_dynamic_name(base - 1 - named, value, self._lines)
            else:
                write_literal_post_base_name(named - base, value, self._lines)
            return
        write_literal(name, value, self._lines)

    def _release(mut self, position: Int):
        """Drop the references of a section, and forget it."""
        var section = self._sections.pop(position)
        var index = 0
        while index < len(section.refs):
            self.table.add_ref(section.refs[index], -1)
            index += 1

    def on_decoder_stream(mut self, data: Span[UInt8, _]) raises H3Error:
        """Apply the instructions of the peer's decoder stream.

        An instruction that the bytes cut waits for the next call.

        Args:
            data: The next bytes of the decoder stream.

        Raises:
            H3Error: `QPACK_DECODER_STREAM_ERROR` for a malformed
                instruction, an acknowledgment of a stream without a
                section, or an increment of 0 or past the insert count.
        """
        var buffer = self._pending^
        self._pending = List[UInt8]()
        buffer.extend(data)
        var at = 0
        try:
            while at < len(buffer):
                var end = self._apply(Span(buffer), at)
                if end < 0:
                    break
                at = end
        except e:
            raise _decoder_stream_error(e.message)
        self._pending.extend(Span(buffer)[at:])

    def _apply(mut self, data: Span[UInt8, _], at: Int) raises H3Error -> Int:
        """Apply one instruction; return its end, or -1 when it is cut."""
        var kind = DecoderInstructionKind.of(data[at])
        if kind == DecoderInstructionKind.INSERT_COUNT_INCREMENT:
            var head = decode_prefix_int(6, data, at)
            if not head.complete():
                return -1
            var increment = to_index(head.value)
            var room = self.table.insert_count() - self.known_received
            if increment == 0 or increment > room:
                raise _decoder_stream_error("invalid insert count increment")
            self.known_received += increment
            return head.end
        var head = decode_prefix_int(
            7 if kind == DecoderInstructionKind.SECTION_ACK else 6, data, at
        )
        if not head.complete():
            return -1
        var stream_id = head.value
        if kind == DecoderInstructionKind.STREAM_CANCEL:
            var position = len(self._sections) - 1
            while position >= 0:
                if self._sections[position].stream_id == stream_id:
                    self._release(position)
                position -= 1
            return head.end
        var position = 0
        while position < len(self._sections):
            if self._sections[position].stream_id == stream_id:
                var required = self._sections[position].required
                self.known_received = max(self.known_received, required)
                self._release(position)
                return head.end
            position += 1
        raise _decoder_stream_error(
            String("acknowledgment of stream ", stream_id, " without a section")
        )

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Streams and flow control (RFC 9000 sections 2, 3 and 4).

`StreamsState` holds every open stream of a connection, the stream limits
of both ends, and the flow control of the connection.

- **Send:** `write` takes the bytes that the credit of the stream and of
  the connection allow, and keeps them in the `SendBuffer` of the stream
  until they are acknowledged. `write_frames` writes STREAM and
  RESET_STREAM frames into a packet, in round-robin order.
- **Receive:** `on_stream_frame` puts the bytes in the `Assembler` of the
  stream, after the checks of flow control and final size. `read` gives
  them in order and raises the limits with MAX_STREAM_DATA and MAX_DATA
  when half of a window is used.
- **Limits:** a stream of the peer above `MAX_STREAMS` is
  `STREAM_LIMIT_ERROR`. When a stream of the peer is done in both
  directions and the application has released it, the limit grows by one
  and a MAX_STREAMS frame goes out.
- **Recovery:** `on_frame_acked` and `on_frame_lost` take the records of
  the frames of a packet.

This module ports quinn-proto 0.11.19 (8192ed3)
quinn-proto/src/connection/streams: state.rs, send.rs and recv.rs (MIT OR
Apache-2.0, used under MIT).

Differences from upstream: quinn has separate `accept(Dir)` queues and
reads that may be unordered; here `accept` gives the streams of the peer
in the order that they opened, of both directions, and reads are in
order. A stream leaves the state when it is done in both directions and
`release` was called, which is the `SSL_free` of the stream for
`gql_http3`. Writes are limited by the flow control credit, not by a
separate send window. STREAM_DATA_BLOCKED and STREAMS_BLOCKED are not
sent.
"""

from std.collections import Dict

from gql_quic.assembler import Assembler
from gql_quic.error import QuicError, TransportErrorCode
from gql_quic.frame import (
    FrameType,
    stream_header_size,
    write_max_data,
    write_max_stream_data,
    write_max_streams,
    write_reset_stream,
    write_stop_sending,
    write_stream_header,
)
from gql_quic.send_buffer import SendBuffer
from gql_quic.shared import Dir, Side, StreamId
from gql_quic.spaces import SentFrame


@fieldwise_init
struct ReadStatus(Equatable, ImplicitlyCopyable, Writable):
    """The state of a stream after a read, as a type."""

    var value: UInt8
    """The state's index; see `is_valid`."""

    comptime DATA = ReadStatus(0)
    """Bytes arrived; more can follow."""
    comptime WAIT = ReadStatus(1)
    """No bytes now; more can follow."""
    comptime END = ReadStatus(2)
    """The peer ended the stream, and every byte was read."""
    comptime RESET = ReadStatus(3)
    """The peer reset the stream, or the stream is gone."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the states.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 3

    def write_to(self, mut writer: Some[Writer]):
        """Write the name of the state.

        Args:
            writer: The destination.
        """
        comptime names: Array[StaticString, 5] = [
            "data",
            "wait",
            "end",
            "reset",
            "invalid",
        ]
        writer.write(materialize[names]()[Int(min(self.value, 4))])


@fieldwise_init
struct StreamRead(ImplicitlyCopyable, Writable):
    """The result of a read: a count and a state."""

    var count: Int
    """The count of bytes read."""
    var status: ReadStatus
    """What the stream does next."""

    def write_to(self, mut writer: Some[Writer]):
        """Write the count and the state.

        Args:
            writer: The destination.
        """
        writer.write(self.count, " ", self.status)


struct Stream(Movable):
    """One stream: its send part and its receive part."""

    var id: StreamId
    """The id."""
    var can_send: Bool
    """Whether this end sends on it."""
    var can_recv: Bool
    """Whether this end receives on it."""
    var send: SendBuffer
    """The bytes that wait for acknowledgment."""
    var send_max: UInt64
    """The limit of the peer on the send offset."""
    var finished: Bool
    """Whether the application ended the stream."""
    var fin_pending: Bool
    """Whether the FIN must be sent, or sent again."""
    var fin_acked: Bool
    """Whether the peer acknowledged the FIN."""
    var reset_code: Int64
    """The code of the RESET_STREAM of this end; -1 for none."""
    var reset_pending: Bool
    """Whether the RESET_STREAM must be sent, or sent again."""
    var reset_acked: Bool
    """Whether the peer acknowledged the RESET_STREAM."""
    var queued: Bool
    """Whether the stream is in the send queue."""
    var recv: Assembler
    """The bytes that arrived."""
    var recv_max: UInt64
    """The limit of this end on the receive offset."""
    var recv_end: UInt64
    """The offset after the highest byte that arrived."""
    var final_size: Int64
    """The final size; -1 while it is unknown."""
    var peer_reset: Bool
    """Whether the peer reset the stream."""
    var peer_reset_code: UInt64
    """The code of the RESET_STREAM of the peer."""
    var stop_code: Int64
    """The code of the STOP_SENDING of this end; -1 for none."""
    var stop_pending: Bool
    """Whether the STOP_SENDING must be sent, or sent again."""
    var released: Bool
    """Whether the application gave up the stream."""

    def __init__(out self, id: StreamId, side: Side, send_max: UInt64, recv_max: UInt64):
        """Make a stream.

        Args:
            id: The id.
            side: This end, which tells the directions.
            send_max: The send limit of the peer.
            recv_max: The receive limit of this end.
        """
        self.id = id
        var bidi = id.dir() == Dir.BI
        self.can_send = bidi or id.initiator() == side
        self.can_recv = bidi or id.initiator() != side
        self.send = SendBuffer()
        self.send_max = send_max
        self.finished = False
        self.fin_pending = False
        self.fin_acked = False
        self.reset_code = -1
        self.reset_pending = False
        self.reset_acked = False
        self.queued = False
        self.recv = Assembler()
        self.recv_max = recv_max
        self.recv_end = 0
        self.final_size = -1
        self.peer_reset = False
        self.peer_reset_code = 0
        self.stop_code = -1
        self.stop_pending = False
        self.released = False

    def send_done(self) -> Bool:
        """Return True when the send part needs nothing more.

        Returns:
            Whether the FIN and every byte, or the reset, were acknowledged.
        """
        if not self.can_send or self.reset_acked:
            return True
        return self.fin_acked and self.send.is_fully_acked()

    def recv_done(self) -> Bool:
        """Return True when the receive part needs nothing more.

        Returns:
            Whether the peer reset it, or every byte was read.
        """
        if not self.can_recv or self.peer_reset:
            return True
        return self.final_size >= 0 and self.recv.bytes_read == UInt64(
            self.final_size
        )

    def has_send_work(self) -> Bool:
        """Return True when a frame of this stream waits to be sent.

        Returns:
            Whether bytes, a FIN or a RESET_STREAM wait.
        """
        if self.reset_code >= 0:
            return self.reset_pending
        return self.send.has_unsent_data() or self.fin_pending


def _stream_error(code: TransportErrorCode, kind: FrameType, reason: StaticString) -> QuicError:
    """Make an error that a frame of some type caused."""
    return QuicError(code, kind.value, String(reason))


struct StreamsState(Movable):
    """Every stream of a connection, its limits and its flow control."""

    var side: Side
    """This end."""
    var streams: List[Stream]
    """The stream slots; see `_index`."""
    var _index: Dict[UInt64, Int]
    var _free: List[Int]
    var next_local: List[UInt64]
    """The index of the next stream that this end opens, by `Dir`."""
    var max_local: List[UInt64]
    """The stream limit of the peer, by `Dir`."""
    var next_remote: List[UInt64]
    """The count of streams that the peer opened, by `Dir`."""
    var max_remote: List[UInt64]
    """The stream limit of this end, by `Dir`."""
    var max_streams_pending: List[Bool]
    """Whether a MAX_STREAMS frame must go out, by `Dir`."""
    var accept_queue: List[UInt64]
    """The streams of the peer that wait for `accept`."""
    var send_queue: List[UInt64]
    """The streams with frames to send, in round-robin order."""
    var max_stream_data_pending: List[UInt64]
    """The streams whose MAX_STREAM_DATA must go out."""
    var stop_queue: List[UInt64]
    """The streams whose STOP_SENDING must go out."""
    var stream_window: UInt64
    """The receive window of each stream."""
    var peer_bidi_local: UInt64
    """`initial_max_stream_data_bidi_local` of the peer."""
    var peer_bidi_remote: UInt64
    """`initial_max_stream_data_bidi_remote` of the peer."""
    var peer_uni: UInt64
    """`initial_max_stream_data_uni` of the peer."""
    var peer_max_data: UInt64
    """The connection send limit of the peer."""
    var written: UInt64
    """The bytes that the application wrote on every stream."""
    var local_max_data: UInt64
    """The connection receive limit of this end."""
    var conn_window: UInt64
    """The connection receive window."""
    var data_recvd: UInt64
    """The sum of the highest offsets that arrived on each stream."""
    var data_read: UInt64
    """The bytes that the application read, or that were dropped."""
    var max_data_pending: Bool
    """Whether a MAX_DATA frame must go out."""

    def __init__(
        out self,
        side: Side,
        max_bidi: UInt64,
        max_uni: UInt64,
        stream_window: UInt64,
        conn_window: UInt64,
    ):
        """Make the state before the peer's transport parameters.

        Args:
            side: This end.
            max_bidi: The bidirectional streams that the peer can open.
            max_uni: The unidirectional streams that the peer can open.
            stream_window: The receive window of each stream.
            conn_window: The receive window of the connection.
        """
        self.side = side
        self.streams = List[Stream]()
        self._index = Dict[UInt64, Int]()
        self._free = List[Int]()
        self.next_local = List[UInt64](length=2, fill=0)
        self.max_local = List[UInt64](length=2, fill=0)
        self.next_remote = List[UInt64](length=2, fill=0)
        self.max_remote = List[UInt64]()
        self.max_remote.append(max_bidi)
        self.max_remote.append(max_uni)
        self.max_streams_pending = List[Bool](length=2, fill=False)
        self.accept_queue = List[UInt64]()
        self.send_queue = List[UInt64]()
        self.max_stream_data_pending = List[UInt64]()
        self.stop_queue = List[UInt64]()
        self.stream_window = stream_window
        self.peer_bidi_local = 0
        self.peer_bidi_remote = 0
        self.peer_uni = 0
        self.peer_max_data = 0
        self.written = 0
        self.local_max_data = conn_window
        self.conn_window = conn_window
        self.data_recvd = 0
        self.data_read = 0
        self.max_data_pending = False

    def set_peer_limits(
        mut self,
        max_data: UInt64,
        bidi_local: UInt64,
        bidi_remote: UInt64,
        uni: UInt64,
        max_bidi: UInt64,
        max_uni: UInt64,
    ):
        """Take the limits of the transport parameters of the peer.

        Args:
            max_data: `initial_max_data`.
            bidi_local: `initial_max_stream_data_bidi_local`.
            bidi_remote: `initial_max_stream_data_bidi_remote`.
            uni: `initial_max_stream_data_uni`.
            max_bidi: `initial_max_streams_bidi`.
            max_uni: `initial_max_streams_uni`.
        """
        self.peer_max_data = max_data
        self.peer_bidi_local = bidi_local
        self.peer_bidi_remote = bidi_remote
        self.peer_uni = uni
        self.max_local[0] = max_bidi
        self.max_local[1] = max_uni

    def find(self, id: UInt64) -> Int:
        """Return the slot of a stream, or -1 when it is not open.

        Args:
            id: The stream id.

        Returns:
            The index in `streams`.
        """
        var slot = self._index.get(id)
        if slot:
            return slot.value()
        return -1

    def _add(mut self, id: StreamId) -> Int:
        """Make a stream with the limits of its kind; return its slot."""
        var send_max = self.peer_uni
        if id.dir() == Dir.BI:
            send_max = (
                self.peer_bidi_remote if id.initiator()
                == self.side else self.peer_bidi_local
            )
        var stream = Stream(id, self.side, send_max, self.stream_window)
        var slot = len(self.streams)
        if len(self._free) > 0:
            slot = self._free.pop()
            self.streams[slot] = stream^
        else:
            self.streams.append(stream^)
        self._index[id.value] = slot
        return slot

    def open(mut self, dir: Dir) -> Int64:
        """Open a stream of this end, when the limit of the peer allows.

        Args:
            dir: The direction.

        Returns:
            The stream id, or -1 when the peer allows no more streams now.
        """
        var d = Int(dir.value)
        if self.next_local[d] >= self.max_local[d]:
            return -1
        var id = StreamId(self.side, dir, self.next_local[d])
        self.next_local[d] += 1
        _ = self._add(id)
        return Int64(id.value)

    def accept(mut self) -> Int64:
        """Take the oldest stream that the peer opened.

        Returns:
            Its id, or -1 when none waits.
        """
        if len(self.accept_queue) == 0:
            return -1
        return Int64(self.accept_queue.pop(0))

    def _remote(
        mut self, raw: UInt64, kind: FrameType
    ) raises QuicError -> Int:
        """Return the slot of a stream that a frame names, opening the
        streams of the peer up to it; -1 when the stream is closed."""
        var id = StreamId(raw)
        var d = Int(id.dir().value)
        var index = id.index()
        if id.initiator() == self.side:
            if index >= self.next_local[d]:
                raise _stream_error(
                    TransportErrorCode.STREAM_STATE_ERROR,
                    kind,
                    "a frame for a stream that this end did not open",
                )
            return self.find(raw)
        if index >= self.max_remote[d]:
            raise _stream_error(
                TransportErrorCode.STREAM_LIMIT_ERROR,
                kind,
                "the peer opened too many streams",
            )
        while self.next_remote[d] <= index:
            var opened = StreamId(id.initiator(), id.dir(), self.next_remote[d])
            self.next_remote[d] += 1
            _ = self._add(opened)
            self.accept_queue.append(opened.value)
        return self.find(raw)

    def _queue(mut self, slot: Int):
        """Put a stream in the send queue, once."""
        if not self.streams[slot].queued:
            self.streams[slot].queued = True
            self.send_queue.append(self.streams[slot].id.value)

    def write(mut self, id: UInt64, data: Span[UInt8, _], fin: Bool) -> Int:
        """Take bytes to send, as far as the flow control credit goes.

        Args:
            id: The stream.
            data: The bytes.
            fin: Whether to end the stream after every byte of `data`.

        Returns:
            The count of bytes taken; -1 when the stream cannot send: it
            is not open, it is receive-only, it ended, or it was reset.
        """
        var slot = self.find(id)
        if slot < 0:
            return -1
        ref s = self.streams[slot]
        if not s.can_send or s.finished or s.reset_code >= 0:
            return -1
        var credit = min(
            s.send_max - s.send.offset, self.peer_max_data - self.written
        )
        var n = min(UInt64(len(data)), credit)
        s.send.write(data[0 : Int(n)])
        self.written += n
        if fin and n == UInt64(len(data)):
            s.finished = True
            s.fin_pending = True
        if s.has_send_work():
            self._queue(slot)
        return Int(n)

    def reset(mut self, id: UInt64, code: UInt64):
        """Abort the send part of a stream with RESET_STREAM.

        Args:
            id: The stream.
            code: The application error code.
        """
        var slot = self.find(id)
        if slot < 0:
            return
        ref s = self.streams[slot]
        if not s.can_send or s.reset_code >= 0 or s.fin_acked:
            return
        s.reset_code = Int64(code)
        s.reset_pending = True
        self._queue(slot)

    def stop(mut self, id: UInt64, code: UInt64):
        """Ask the peer to stop sending on a stream with STOP_SENDING.

        Args:
            id: The stream.
            code: The application error code.
        """
        var slot = self.find(id)
        if slot < 0:
            return
        ref s = self.streams[slot]
        if not s.can_recv or s.stop_code >= 0 or s.recv_done():
            return
        s.stop_code = Int64(code)
        s.stop_pending = True
        self.stop_queue.append(id)

    def release(mut self, id: UInt64):
        """Give up a stream: drop the bytes that come later, and free the
        stream once it is done.

        Args:
            id: The stream.
        """
        var slot = self.find(id)
        if slot < 0:
            return
        self.streams[slot].released = True
        self._drain(slot)
        self._maybe_free(slot)

    def _drain(mut self, slot: Int):
        """Drop the readable bytes of a released stream, and credit them."""
        ref s = self.streams[slot]
        var count = s.recv.readable()
        s.recv.consume(count)
        self._credit(slot, count)

    def _credit(mut self, slot: Int, count: Int):
        """Count bytes as read, and raise the windows when half is used."""
        self.data_read += UInt64(count)
        ref s = self.streams[slot]
        if (
            s.final_size < 0
            and not s.peer_reset
            and s.recv_max - s.recv.bytes_read < self.stream_window // 2
        ):
            s.recv_max = s.recv.bytes_read + self.stream_window
            self.max_stream_data_pending.append(s.id.value)
        if self.local_max_data - self.data_read < self.conn_window // 2:
            self.local_max_data = self.data_read + self.conn_window
            self.max_data_pending = True

    def read(
        mut self, id: UInt64, dest: Pointer[mut=True, UInt8, _], size: Int
    ) -> StreamRead:
        """Read bytes of a stream in order.

        Args:
            id: The stream.
            dest: The buffer.
            size: Its size.

        Returns:
            The count and the state: `DATA`, `WAIT`, `END` after the last
            byte, or `RESET` for a stream that the peer reset or that is
            not open.
        """
        var slot = self.find(id)
        if slot < 0 or not self.streams[slot].can_recv:
            return StreamRead(0, ReadStatus.RESET)
        if self.streams[slot].peer_reset:
            return StreamRead(0, ReadStatus.RESET)
        var n = self.streams[slot].recv.read(dest, size)
        if n > 0:
            self._credit(slot, n)
            return StreamRead(n, ReadStatus.DATA)
        if self.streams[slot].recv_done():
            return StreamRead(0, ReadStatus.END)
        return StreamRead(0, ReadStatus.WAIT)

    def readable(self, id: UInt64) -> Bool:
        """Return True when a read of a stream would not wait.

        Args:
            id: The stream.

        Returns:
            Whether bytes, the end or a reset wait.
        """
        var slot = self.find(id)
        if slot < 0:
            return True
        ref s = self.streams[slot]
        return s.recv.readable() > 0 or s.recv_done()

    def _received(
        mut self, slot: Int, end: UInt64, fin: Bool, kind: FrameType
    ) raises QuicError:
        """Check an end offset against the final size and the limits, and
        count it for the connection."""
        ref s = self.streams[slot]
        if s.final_size >= 0:
            var final = UInt64(s.final_size)
            if end > final or (fin and end != final):
                raise _stream_error(
                    TransportErrorCode.FINAL_SIZE_ERROR,
                    kind,
                    "the final size of a stream changed",
                )
        elif fin:
            if end < s.recv_end:
                raise _stream_error(
                    TransportErrorCode.FINAL_SIZE_ERROR,
                    kind,
                    "the final size is below the received bytes",
                )
            s.final_size = Int64(end)
        if end > s.recv_max:
            raise _stream_error(
                TransportErrorCode.FLOW_CONTROL_ERROR,
                kind,
                "the peer sent above the stream limit",
            )
        if end > s.recv_end:
            self.data_recvd += end - s.recv_end
            s.recv_end = end
            if self.data_recvd > self.local_max_data:
                raise _stream_error(
                    TransportErrorCode.FLOW_CONTROL_ERROR,
                    kind,
                    "the peer sent above the connection limit",
                )

    def on_stream_frame(
        mut self, id: UInt64, offset: UInt64, data: Span[UInt8, _], fin: Bool
    ) raises QuicError:
        """Take the bytes of a STREAM frame.

        Args:
            id: The stream.
            offset: The offset of the first byte.
            data: The bytes.
            fin: Whether the frame ends the stream.

        Raises:
            QuicError: `STREAM_STATE_ERROR`, `STREAM_LIMIT_ERROR`,
                `FLOW_CONTROL_ERROR` or `FINAL_SIZE_ERROR`.
        """
        var kind = FrameType.STREAM
        var slot = self._remote(id, kind)
        if slot < 0:
            return
        if not self.streams[slot].can_recv:
            raise _stream_error(
                TransportErrorCode.STREAM_STATE_ERROR,
                kind,
                "a STREAM frame for a send-only stream",
            )
        self._received(slot, offset + UInt64(len(data)), fin, kind)
        if self.streams[slot].peer_reset:
            return
        self.streams[slot].recv.insert(offset, data)
        if self.streams[slot].released:
            self._drain(slot)
            self._maybe_free(slot)

    def on_reset_stream(
        mut self, id: UInt64, code: UInt64, final_size: UInt64
    ) raises QuicError:
        """Take a RESET_STREAM frame.

        Args:
            id: The stream.
            code: The application error code.
            final_size: The final size.

        Raises:
            QuicError: As `on_stream_frame`.
        """
        var kind = FrameType.RESET_STREAM
        var slot = self._remote(id, kind)
        if slot < 0:
            return
        if not self.streams[slot].can_recv:
            raise _stream_error(
                TransportErrorCode.STREAM_STATE_ERROR,
                kind,
                "a RESET_STREAM frame for a send-only stream",
            )
        self._received(slot, final_size, True, kind)
        ref s = self.streams[slot]
        if s.peer_reset:
            return
        s.peer_reset = True
        s.peer_reset_code = code
        # The bytes that will not be read no longer hold the window.
        var unread = final_size - s.recv.bytes_read
        s.recv = Assembler()
        self._credit(slot, Int(unread))
        self._maybe_free(slot)

    def on_stop_sending(mut self, id: UInt64, code: UInt64) raises QuicError:
        """Take a STOP_SENDING frame: answer with RESET_STREAM.

        Args:
            id: The stream.
            code: The application error code.

        Raises:
            QuicError: `STREAM_STATE_ERROR` for a receive-only stream, or
                as `on_stream_frame`.
        """
        var kind = FrameType.STOP_SENDING
        var slot = self._remote(id, kind)
        if slot < 0:
            return
        if not self.streams[slot].can_send:
            raise _stream_error(
                TransportErrorCode.STREAM_STATE_ERROR,
                kind,
                "a STOP_SENDING frame for a receive-only stream",
            )
        self.reset(id, code)

    def on_max_stream_data(mut self, id: UInt64, value: UInt64) raises QuicError:
        """Take a MAX_STREAM_DATA frame.

        Args:
            id: The stream.
            value: The new send limit.

        Raises:
            QuicError: `STREAM_STATE_ERROR` for a receive-only stream, or
                as `on_stream_frame`.
        """
        var kind = FrameType.MAX_STREAM_DATA
        var slot = self._remote(id, kind)
        if slot < 0:
            return
        if not self.streams[slot].can_send:
            raise _stream_error(
                TransportErrorCode.STREAM_STATE_ERROR,
                kind,
                "a MAX_STREAM_DATA frame for a receive-only stream",
            )
        ref s = self.streams[slot]
        s.send_max = max(s.send_max, value)

    def on_max_streams(mut self, dir: Dir, count: UInt64):
        """Take a MAX_STREAMS frame.

        Args:
            dir: The direction.
            count: The new stream limit of the peer.
        """
        var d = Int(dir.value)
        self.max_local[d] = max(self.max_local[d], count)

    def on_max_data(mut self, value: UInt64):
        """Take a MAX_DATA frame.

        Args:
            value: The new connection send limit.
        """
        self.peer_max_data = max(self.peer_max_data, value)

    def _maybe_free(mut self, slot: Int):
        """Free a stream that is done and released, and raise the limit of
        the peer for a stream that the peer opened."""
        ref s = self.streams[slot]
        if not s.released or not s.send_done() or not s.recv_done():
            return
        var id = s.id
        _ = self._index.pop(id.value, -1)
        self._free.append(slot)
        if id.initiator() != self.side:
            var d = Int(id.dir().value)
            self.max_remote[d] += 1
            self.max_streams_pending[d] = True

    def is_open(self, id: UInt64) -> Bool:
        """Return True while a stream is in the state.

        Args:
            id: The stream.

        Returns:
            Whether it is open.
        """
        return self.find(id) >= 0

    def has_pending(self) -> Bool:
        """Return True when a stream or a flow control frame waits.

        Returns:
            Whether `write_control` or `write_frames` has work.
        """
        return (
            len(self.send_queue) > 0
            or self.has_control()
        )

    def has_control(self) -> Bool:
        """Return True when a flow control frame waits.

        Returns:
            Whether `write_control` has work.
        """
        return (
            self.max_data_pending
            or self.max_streams_pending[0]
            or self.max_streams_pending[1]
            or len(self.max_stream_data_pending) > 0
            or len(self.stop_queue) > 0
        )

    def write_control(
        mut self, mut out: List[UInt8], limit: Int, mut frames: List[SentFrame]
    ):
        """Write the pending MAX_DATA, MAX_STREAMS, MAX_STREAM_DATA and
        STOP_SENDING frames that fit.

        Args:
            out: The packet.
            limit: The offset in `out` that the frames must not pass.
            frames: The records of the packet.
        """
        if self.max_data_pending and len(out) + 9 <= limit:
            self.max_data_pending = False
            write_max_data(out, self.local_max_data)
            frames.append(SentFrame(FrameType.MAX_DATA.value, 0, 0, 0, False, 0))
        for d in range(2):
            if self.max_streams_pending[d] and len(out) + 9 <= limit:
                self.max_streams_pending[d] = False
                write_max_streams(out, Dir(UInt8(d)), self.max_remote[d])
                frames.append(
                    SentFrame(
                        FrameType.MAX_STREAMS_BIDI.value + UInt64(d),
                        0,
                        0,
                        0,
                        False,
                        0,
                    )
                )
        while len(self.max_stream_data_pending) > 0 and len(out) + 17 <= limit:
            var id = self.max_stream_data_pending.pop()
            var slot = self.find(id)
            if slot < 0 or self.streams[slot].recv_done():
                continue
            write_max_stream_data(out, StreamId(id), self.streams[slot].recv_max)
            frames.append(
                SentFrame(FrameType.MAX_STREAM_DATA.value, id, 0, 0, False, 0)
            )
        while len(self.stop_queue) > 0 and len(out) + 17 <= limit:
            var id = self.stop_queue.pop()
            var slot = self.find(id)
            if slot < 0 or not self.streams[slot].stop_pending:
                continue
            ref s = self.streams[slot]
            s.stop_pending = False
            write_stop_sending(out, s.id, UInt64(s.stop_code))
            frames.append(
                SentFrame(
                    FrameType.STOP_SENDING.value,
                    id,
                    0,
                    0,
                    False,
                    UInt64(s.stop_code),
                )
            )

    def write_frames(
        mut self, mut out: List[UInt8], limit: Int, mut frames: List[SentFrame]
    ):
        """Write STREAM and RESET_STREAM frames that fit, in round-robin
        order of the streams.

        Args:
            out: The packet.
            limit: The offset in `out` that the frames must not pass.
            frames: The records of the packet.
        """
        var visits = len(self.send_queue)
        while visits > 0 and len(self.send_queue) > 0:
            visits -= 1
            var room = limit - len(out)
            if room < 32:
                return
            var id = self.send_queue.pop(0)
            var slot = self.find(id)
            if slot < 0:
                continue
            ref s = self.streams[slot]
            s.queued = False
            if s.reset_code >= 0:
                if s.reset_pending:
                    s.reset_pending = False
                    var size = s.send.offset
                    write_reset_stream(out, s.id, UInt64(s.reset_code), size)
                    frames.append(
                        SentFrame(
                            FrameType.RESET_STREAM.value,
                            id,
                            size,
                            0,
                            False,
                            UInt64(s.reset_code),
                        )
                    )
                continue
            # The header has at most a type byte, 8 bytes of id, 8 of
            # offset and 2 of length.
            var range = s.send.poll_transmit(room - 19)
            var length = range.end - range.start
            var fin = s.finished and range.end == s.send.offset and (
                s.fin_pending
            ) and s.send.retransmits.is_empty()
            if length == 0 and not fin:
                continue
            if fin:
                s.fin_pending = False
            write_stream_header(out, s.id, range.start, length, fin, True)
            out.extend(s.send.get(range.start, range.end))
            frames.append(
                SentFrame(
                    FrameType.STREAM.value, id, range.start, length, fin, 0
                )
            )
            if s.has_send_work():
                s.queued = True
                self.send_queue.append(id)

    def on_frame_acked(mut self, frame: SentFrame):
        """Take the acknowledgment of a frame of a stream.

        Args:
            frame: The record.
        """
        var slot = self.find(frame.id)
        if slot < 0:
            return
        ref s = self.streams[slot]
        if frame.kind == FrameType.STREAM.value:
            s.send.ack(frame.offset, frame.offset + frame.length)
            if frame.fin:
                s.fin_acked = True
        elif frame.kind == FrameType.RESET_STREAM.value:
            s.reset_acked = True
        self._maybe_free(slot)

    def on_frame_lost(mut self, frame: SentFrame):
        """Queue again what a lost frame of a stream or of flow control
        carried.

        Args:
            frame: The record.
        """
        if frame.kind == FrameType.MAX_DATA.value:
            self.max_data_pending = True
            return
        if frame.kind == FrameType.MAX_STREAMS_BIDI.value:
            self.max_streams_pending[0] = True
            return
        if frame.kind == FrameType.MAX_STREAMS_UNI.value:
            self.max_streams_pending[1] = True
            return
        var slot = self.find(frame.id)
        if slot < 0:
            return
        ref s = self.streams[slot]
        if frame.kind == FrameType.STREAM.value:
            if s.reset_code >= 0:
                return
            s.send.retransmit(frame.offset, frame.offset + frame.length)
            if frame.fin and not s.fin_acked:
                s.fin_pending = True
            self._queue(slot)
        elif frame.kind == FrameType.RESET_STREAM.value:
            if not s.reset_acked:
                s.reset_pending = True
                self._queue(slot)
        elif frame.kind == FrameType.MAX_STREAM_DATA.value:
            self.max_stream_data_pending.append(frame.id)
        elif frame.kind == FrameType.STOP_SENDING.value:
            if not s.recv_done():
                s.stop_pending = True
                self.stop_queue.append(frame.id)

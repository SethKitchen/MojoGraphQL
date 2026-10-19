# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The HTTP/2 connection state machine of RFC 9113, without I/O.

A `Connection` takes the bytes that arrive with `receive`, and puts the
bytes to send in `out`. It reads frames, keeps the stream states (RFC 9113
section 5.1), flow control (section 5.2), the settings exchange, `PING`
and `GOAWAY`, and checks each message (section 8). A whole request or
response becomes a `MESSAGE` event; a stream that ends early becomes a
`RESET` event. The server and the client drive it, and so can a TLS layer.

A stream error sends `RST_STREAM`. A connection error sends `GOAWAY` and
ends the connection; `error` holds it. The connection keeps each message
whole, so it gives each `DATA` frame back to the peer's window at once.

This module ports h2 v0.4.20 `src/proto/connection.rs`,
`src/proto/settings.rs`, `src/proto/ping_pong.rs`, `src/proto/go_away.rs`,
`src/proto/streams` (`state.rs`, `flow_control.rs`, `recv.rs`,
`send.rs`, `counts.rs` and `store.rs`), and the message checks of
`src/frame/headers.rs`, `src/server.rs` and `src/client.rs`.

Differences from upstream:

- **Whole messages.** h2 gives a request to the application when its
  head arrives, and the application reads the content and releases its
  window. Here a message is ready when its stream ends, and the window goes
  back at once. `max_body_bytes` limits the content; more gives 413.
- **No push, no priority.** The connection sends `SETTINGS_ENABLE_PUSH = 0`
  and refuses `PUSH_PROMISE`, as RFC 9113 allows. It checks `PRIORITY` and
  then ignores it, as h2 does.
- **Rapid reset.** h2 counts the streams that the peer resets before the
  application accepts them. Here a reset of a stream that has no response
  yet counts, and a response sets the count to 0. More than
  `max_remote_resets` gives `GOAWAY` with `ENHANCE_YOUR_CALM`.
- **Self-dependency.** h2 resets a `HEADERS` stream that depends on itself
  before it decodes the block. Here the block is decoded first, so that the
  HPACK state stays in step.
"""

from gql_http.scan import is_host_byte, is_tchar, move_down

from gql_http2.error import H2Error, H2ErrorKind, Reason
from gql_http2.frame import (
    ACK,
    DEFAULT_MAX_FRAME_SIZE,
    DEFAULT_WINDOW_SIZE,
    END_HEADERS,
    END_STREAM,
    FrameHead,
    FrameKind,
    HEAD_SIZE,
    MAX_STREAM_ID,
    MAX_WINDOW_SIZE,
    PREFACE,
    PREFACE_SIZE,
    SHUTDOWN_PING,
    Settings,
    check_goaway,
    check_ping,
    check_priority,
    check_rst_stream,
    check_settings,
    check_window_update,
    data_payload,
    headers_payload,
    read_u31,
    read_u32,
    read_u64,
    write_data,
    write_goaway,
    write_header_block,
    write_ping,
    write_rst_stream,
    write_settings_ack,
    write_window_update,
)
from gql_http2.hpack import Decoder, Encoder, HeaderList, HpackError


@fieldwise_init
struct Role(Equatable, ImplicitlyCopyable, Writable):
    """Which end of a connection an endpoint is."""

    var value: UInt8
    """The role's index; see `is_valid`."""

    comptime CLIENT = Role(0)
    """The endpoint that sends the preface and opens odd streams."""
    comptime SERVER = Role(1)
    """The endpoint that answers requests."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the roles.

        Returns:
            Whether the value is 0 or 1.
        """
        return self.value <= 1

    def write_to(self, mut writer: Some[Writer]):
        """Write `client` or `server`.

        Args:
            writer: The destination.
        """
        if self == Role.CLIENT:
            writer.write("client")
        elif self == Role.SERVER:
            writer.write("server")
        else:
            writer.write("invalid")


@fieldwise_init
struct StreamState(Equatable, ImplicitlyCopyable, Writable):
    """The state of a stream (RFC 9113 section 5.1), without the reserved
    states of push."""

    var value: UInt8
    """The state's index; see `is_valid`."""

    comptime IDLE = StreamState(0)
    """Not opened yet."""
    comptime OPEN = StreamState(1)
    """Both ends can send."""
    comptime HALF_CLOSED_LOCAL = StreamState(2)
    """This endpoint has ended its side; the peer can send."""
    comptime HALF_CLOSED_REMOTE = StreamState(3)
    """The peer has ended its side; this endpoint can send."""
    comptime CLOSED = StreamState(4)
    """Both ends have ended, or the stream was reset."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the states.

        Returns:
            Whether the value is at most 4.
        """
        return self.value <= 4

    def can_receive(self) -> Bool:
        """Return True when the peer can still send on the stream.

        Returns:
            Whether the state is `OPEN` or `HALF_CLOSED_LOCAL`.
        """
        return self == StreamState.OPEN or self == StreamState.HALF_CLOSED_LOCAL

    def can_send(self) -> Bool:
        """Return True when this endpoint can still send on the stream.

        Returns:
            Whether the state is `OPEN` or `HALF_CLOSED_REMOTE`.
        """
        return (
            self == StreamState.OPEN or self == StreamState.HALF_CLOSED_REMOTE
        )

    def write_to(self, mut writer: Some[Writer]):
        """Write the name of the state, such as `open`.

        Args:
            writer: The destination.
        """
        comptime names: Array[StaticString, 5] = [
            "idle",
            "open",
            "half-closed (local)",
            "half-closed (remote)",
            "closed",
        ]
        if self.is_valid():
            writer.write(materialize[names]()[Int(self.value)])
        else:
            writer.write("invalid")


@fieldwise_init
struct EventKind(Equatable, ImplicitlyCopyable, Writable):
    """What happened on a stream."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime MESSAGE = EventKind(0)
    """A whole request or response arrived."""
    comptime RESET = EventKind(1)
    """The stream ended before its message was whole."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the kinds.

        Returns:
            Whether the value is 0 or 1.
        """
        return self.value <= 1

    def write_to(self, mut writer: Some[Writer]):
        """Write `message` or `reset`.

        Args:
            writer: The destination.
        """
        if self == EventKind.MESSAGE:
            writer.write("message")
        elif self == EventKind.RESET:
            writer.write("reset")
        else:
            writer.write("invalid")


@fieldwise_init
struct Event(Copyable, Movable):
    """One thing that happened on a stream."""

    var kind: EventKind
    """What happened."""
    var stream_id: Int
    """The stream."""
    var error: H2Error
    """For `RESET`: why; its kind tells whether the peer reset the stream,
    the peer's `GOAWAY` refused it, or this endpoint reset it."""


struct Config(Copyable, Movable):
    """The limits that a connection advertises and enforces."""

    var max_concurrent_streams: Int
    """The most streams that the peer can open at once; -1 for no limit."""
    var initial_window_size: Int
    """The receive window of each stream."""
    var connection_window_size: Int
    """The receive window of the connection."""
    var max_frame_size: Int
    """The largest frame payload that this endpoint takes."""
    var max_header_list_size: Int
    """The largest header list; a larger request gets 431."""
    var header_table_size: Int
    """The HPACK dynamic table of this endpoint's decoder."""
    var max_body_bytes: Int
    """The largest content of a message; a larger request gets 413."""
    var max_remote_resets: Int
    """The most streams that the peer can reset before their response."""
    var max_empty_data_frames: Int
    """The most empty `DATA` frames without `END_STREAM`."""
    var enable_connect_protocol: Bool
    """Whether a server allows the extended `CONNECT` of RFC 8441."""

    def __init__(out self):
        """Make the defaults: 200 streams, windows of 1 MiB, 16 KiB of
        header list, 16 MiB of content."""
        self.max_concurrent_streams = 200
        self.initial_window_size = 1 << 20
        self.connection_window_size = 1 << 20
        self.max_frame_size = DEFAULT_MAX_FRAME_SIZE
        self.max_header_list_size = 16384
        self.header_table_size = 4096
        self.max_body_bytes = 16 << 20
        self.max_remote_resets = 20
        self.max_empty_data_frames = 100
        self.enable_connect_protocol = False


struct Stream(Movable):
    """The state of one stream. A slot with `id` 0 is free."""

    var id: Int
    """The stream id; 0 for a free slot."""
    var state: StreamState
    """The state."""
    var send_window: Int
    """How much content the peer lets this endpoint send."""
    var recv_window: Int
    """How much content this endpoint lets the peer send."""
    var unacked: Int
    """Received content that no `WINDOW_UPDATE` gave back yet."""
    var headers: HeaderList
    """The header fields of the message, pseudo-header fields first."""
    var body: List[UInt8]
    """The content of the message."""
    var content_length: Int
    """The `content-length` value, or -1."""
    var got_head: Bool
    """Whether the head of the message arrived."""
    var status: Int
    """The `:status` of a response, or 0."""
    var out: List[UInt8]
    """Content that waits for a window."""
    var out_at: Int
    """The first byte of `out` that has not gone out."""
    var end_after_out: Bool
    """Whether `END_STREAM` follows the content in `out`."""
    var answered: Bool
    """Whether this endpoint has sent a head on the stream."""
    var head_request: Bool
    """Whether the request is `HEAD`, so the response has no content."""
    var released: Bool
    """Whether the driver is done with the message; the slot is free once
    the stream closes."""

    def __init__(out self):
        """Make a free slot."""
        self.id = 0
        self.state = StreamState.IDLE
        self.send_window = 0
        self.recv_window = 0
        self.unacked = 0
        self.headers = HeaderList()
        self.body = List[UInt8]()
        self.content_length = -1
        self.got_head = False
        self.status = 0
        self.out = List[UInt8]()
        self.out_at = 0
        self.end_after_out = False
        self.answered = False
        self.head_request = False
        self.released = False

    def reset(mut self, id: Int, send_window: Int, recv_window: Int):
        """Make the slot a new stream, and keep the capacity of its buffers.

        Args:
            id: The stream id.
            send_window: The initial send window.
            recv_window: The initial receive window.
        """
        self.id = id
        self.state = StreamState.OPEN
        self.send_window = send_window
        self.recv_window = recv_window
        self.unacked = 0
        self.headers.clear()
        self.body.clear()
        self.content_length = -1
        self.got_head = False
        self.status = 0
        self.out.clear()
        self.out_at = 0
        self.end_after_out = False
        self.answered = False
        self.head_request = False
        self.released = False

    def pending(self) -> Int:
        """Return the content that waits for a window.

        Returns:
            The count of bytes.
        """
        return len(self.out) - self.out_at


def calc_max_continuation_frames(header_max: Int, frame_max: Int) -> Int:
    """Return the most `CONTINUATION` frames of one header block, as h2
    counts them: enough for the largest header list, a quarter more, and at
    least 5.

    Args:
        header_max: The largest header list.
        frame_max: The largest frame payload.

    Returns:
        The limit.
    """
    var frames = max(header_max // frame_max, 1)
    return max(frames + (frames >> 2), 5)


struct Connection(Movable):
    """One HTTP/2 connection, without I/O: bytes in, events and bytes out."""

    var role: Role
    """Which end this endpoint is."""
    var config: Config
    """The limits of this endpoint."""
    var local: Settings
    """The settings this endpoint sent; they apply when the peer
    acknowledges them."""
    var local_acked: Settings
    """The settings of this endpoint that the peer acknowledged."""
    var remote: Settings
    """The peer's settings."""
    var settings_pending: Bool
    """Whether this endpoint waits for the `ACK` of its settings."""
    var out: List[UInt8]
    """The bytes to send. The driver sends them and clears the list."""
    var events: List[Event]
    """What happened since the driver last cleared the list."""
    var streams: List[Stream]
    """The stream slots; a slot with id 0 is free."""
    var error: Optional[H2Error]
    """The connection error, once one ended the connection."""
    var closed: Bool
    """Whether the connection has ended: no frame is read any more."""
    var goaway_sent: Bool
    """Whether this endpoint sent its final `GOAWAY`."""
    var goaway_received: Bool
    """Whether the peer sent `GOAWAY`."""
    var remote_last_stream: Int
    """The last stream id of the peer's `GOAWAY`."""
    var last_peer_stream: Int
    """The largest stream id that the peer opened."""
    var next_stream_id: Int
    """The id of the next stream that this endpoint opens."""
    var send_window: Int
    """How much content the peer lets this endpoint send on the
    connection."""
    var recv_window: Int
    """How much content this endpoint lets the peer send on the
    connection."""
    var pongs: Int
    """How many `PING` acknowledgements arrived."""
    var decoder: Decoder
    """The HPACK decoder of the peer's header blocks."""
    var encoder: Encoder
    """The HPACK encoder of this endpoint's header blocks."""
    var _input: List[UInt8]
    var _in_start: Int
    var _preface: Bool
    var _first_frame: Bool
    var _block: List[UInt8]
    var _block_stream: Int
    var _block_end_stream: Bool
    var _block_error: Bool
    var _continuations: Int
    var _unacked: Int
    var _empty_frames: Int
    var _remote_resets: Int
    var _shutdown: Int
    var _active: Int
    var _scratch: HeaderList
    var _encoded: List[UInt8]

    def __init__(out self, role: Role, config: Config = Config()):
        """Make a connection that has sent nothing yet; call `start`.

        Args:
            role: Which end this endpoint is.
            config: The limits of this endpoint.
        """
        self.role = role
        self.config = config.copy()
        self.local = Settings()
        # A client turns push off; a server cannot send another value.
        self.local.enable_push = role == Role.SERVER
        self.local.max_concurrent_streams = config.max_concurrent_streams
        self.local.initial_window_size = config.initial_window_size
        self.local.max_frame_size = config.max_frame_size
        self.local.max_header_list_size = config.max_header_list_size
        self.local.header_table_size = config.header_table_size
        self.local.enable_connect_protocol = (
            config.enable_connect_protocol and role == Role.SERVER
        )
        self.local_acked = Settings()
        self.remote = Settings()
        self.settings_pending = False
        self.out = List[UInt8]()
        self.events = List[Event]()
        self.streams = List[Stream]()
        self.error = None
        self.closed = False
        self.goaway_sent = False
        self.goaway_received = False
        self.remote_last_stream = MAX_STREAM_ID
        self.last_peer_stream = 0
        self.next_stream_id = 1 if role == Role.CLIENT else 2
        self.send_window = DEFAULT_WINDOW_SIZE
        self.recv_window = DEFAULT_WINDOW_SIZE
        self.pongs = 0
        self.decoder = Decoder(config.header_table_size)
        self.encoder = Encoder()
        self._input = List[UInt8]()
        self._in_start = 0
        self._preface = role == Role.SERVER
        self._first_frame = True
        self._block = List[UInt8]()
        self._block_stream = 0
        self._block_end_stream = False
        self._block_error = False
        self._continuations = 0
        self._unacked = 0
        self._empty_frames = 0
        self._remote_resets = 0
        self._shutdown = 0
        self._active = 0
        self._scratch = HeaderList()
        self._encoded = List[UInt8]()

    def start(mut self):
        """Append the opening of the connection to `out`: the client
        preface, `SETTINGS`, and a `WINDOW_UPDATE` of the connection window.
        """
        if self.role == Role.CLIENT:
            self.out.extend(StaticString(PREFACE).as_bytes())
        self.local.write(self.out)
        self.settings_pending = True
        var grow = self.config.connection_window_size - DEFAULT_WINDOW_SIZE
        if grow > 0:
            write_window_update(self.out, 0, grow)
            self.recv_window += grow

    def got_settings(self) -> Bool:
        """Return True once the peer's first `SETTINGS` frame arrived: the
        peer speaks HTTP/2.

        Returns:
            Whether the first frame was read.
        """
        return not self._first_frame

    def active_streams(self) -> Int:
        """Return the count of streams that are not closed.

        Returns:
            The count.
        """
        return self._active

    def find(self, stream_id: Int) -> Int:
        """Return the slot of a stream.

        Args:
            stream_id: The stream id.

        Returns:
            The index in `streams`, or -1 when the stream is not active.
        """
        var index = len(self.streams) - 1
        while index >= 0:
            if self.streams[index].id == stream_id:
                return index
            index -= 1
        return -1

    def is_done(self) -> Bool:
        """Return True when the connection can close: it ended, or a
        `GOAWAY` was sent or received and no stream is active.

        Returns:
            Whether the driver can close the transport once `out` is sent.
        """
        if self.closed:
            return True
        return (self.goaway_sent or self.goaway_received) and self._active == 0

    # ------------------------------------------------------------------
    # Reading

    def receive(mut self, data: Span[UInt8, _]):
        """Read bytes from the peer: every whole frame in them, and keep the
        rest for the next call.

        A stream error sends `RST_STREAM` and adds a `RESET` event. A
        connection error sends `GOAWAY`, sets `error` and `closed`, and
        ends the reading.

        Args:
            data: The bytes, in order; they can split frames anywhere.
        """
        if self.closed:
            return
        self._input.extend(data)
        try:
            self._read_frames()
        except e:
            self._fail(e)
        var rest = len(self._input) - self._in_start
        if rest == 0:
            self._input.clear()
        elif self._in_start > 0:
            move_down(self._input.unsafe_ptr(), 0, self._in_start, rest)
            self._input.resize(rest, 0)
        self._in_start = 0

    def _read_frames(mut self) raises H2Error:
        """Read every whole frame of the input."""
        if self._preface:
            var have = len(self._input) - self._in_start
            var expected = StaticString(PREFACE).as_bytes()
            var index = 0
            while index < min(have, PREFACE_SIZE):
                if self._input[self._in_start + index] != expected[index]:
                    raise H2Error.connection(
                        Reason.PROTOCOL_ERROR, "invalid connection preface"
                    )
                index += 1
            if have < PREFACE_SIZE:
                return
            self._in_start += PREFACE_SIZE
            self._preface = False
        # A connection error raises: the loop ends at a partial frame.
        while True:
            var start = self._in_start
            var have = len(self._input) - start
            if have < HEAD_SIZE:
                return
            var address = Int(self._input.unsafe_ptr()) + start
            var head = FrameHead.parse(_at(address))
            if head.length > max(
                self.local.max_frame_size, self.local_acked.max_frame_size
            ):
                raise H2Error.connection(
                    Reason.FRAME_SIZE_ERROR, "frame is larger than allowed"
                )
            if have < HEAD_SIZE + head.length:
                return
            self._in_start += HEAD_SIZE + head.length
            try:
                self._frame(head, _at(address), HEAD_SIZE)
            except e:
                if e.kind != H2ErrorKind.STREAM:
                    raise e^
                self._stream_error(e)

    def _frame(
        mut self,
        head: FrameHead,
        p: Pointer[UInt8, ImmUntrackedOrigin],
        at: Int,
    ) raises H2Error:
        """Handle one frame; its payload is at `p + at`."""
        if self._first_frame:
            if head.kind != FrameKind.SETTINGS or head.has(ACK):
                raise H2Error.connection(
                    Reason.PROTOCOL_ERROR, "the first frame is not SETTINGS"
                )
            self._first_frame = False
        if self._block_stream != 0:
            if (
                head.kind != FrameKind.CONTINUATION
                or head.stream_id != self._block_stream
            ):
                raise H2Error.connection(
                    Reason.PROTOCOL_ERROR, "expected CONTINUATION"
                )
            self._continuation(head, p, at)
            return
        var kind = head.kind
        if kind == FrameKind.DATA:
            self._data(head, p, at)
        elif kind == FrameKind.HEADERS:
            self._headers(head, p, at)
        elif kind == FrameKind.PRIORITY:
            check_priority(head, p, at)
        elif kind == FrameKind.RST_STREAM:
            self._rst_stream(head, p, at)
        elif kind == FrameKind.SETTINGS:
            self._settings(head, p, at)
        elif kind == FrameKind.PUSH_PROMISE:
            raise H2Error.connection(
                Reason.PROTOCOL_ERROR, "PUSH_PROMISE is not allowed"
            )
        elif kind == FrameKind.PING:
            self._ping(head, p, at)
        elif kind == FrameKind.GOAWAY:
            self._goaway(head, p, at)
        elif kind == FrameKind.WINDOW_UPDATE:
            self._window_update(head, p, at)
        elif kind == FrameKind.CONTINUATION:
            raise H2Error.connection(
                Reason.PROTOCOL_ERROR, "CONTINUATION without HEADERS"
            )
        # A frame of an unknown type is ignored (RFC 9113 section 4.1).

    def _settings(
        mut self,
        head: FrameHead,
        p: Pointer[UInt8, ImmUntrackedOrigin],
        at: Int,
    ) raises H2Error:
        """Apply the peer's settings, or the `ACK` of this endpoint's."""
        check_settings(head)
        if head.has(ACK):
            if not self.settings_pending:
                raise H2Error.connection(
                    Reason.PROTOCOL_ERROR, "unexpected SETTINGS ACK"
                )
            self.settings_pending = False
            var delta = (
                self.local.initial_window_size
                - self.local_acked.initial_window_size
            )
            if delta < 0:
                var index = 0
                while index < len(self.streams):
                    if self.streams[index].id != 0:
                        self.streams[index].recv_window += delta
                    index += 1
            if (
                self.local.header_table_size
                != self.local_acked.header_table_size
            ):
                self.decoder.queue_size_update(self.local.header_table_size)
            self.local_acked = self.local.copy()
            return
        var old_window = self.remote.initial_window_size
        self.remote.apply(p, at, head.length, self.role == Role.CLIENT)
        var delta = self.remote.initial_window_size - old_window
        if delta != 0:
            var index = 0
            while index < len(self.streams):
                if self.streams[index].id != 0:
                    var window = self.streams[index].send_window + delta
                    if window > MAX_WINDOW_SIZE:
                        raise H2Error.connection(
                            Reason.FLOW_CONTROL_ERROR,
                            "SETTINGS_INITIAL_WINDOW_SIZE overflows a window",
                        )
                    self.streams[index].send_window = window
                index += 1
        self.encoder.update_max_size(min(self.remote.header_table_size, 4096))
        write_settings_ack(self.out)
        self._flush_all()

    def _ping(
        mut self,
        head: FrameHead,
        p: Pointer[UInt8, ImmUntrackedOrigin],
        at: Int,
    ) raises H2Error:
        """Answer a `PING`, or take the answer to one."""
        check_ping(head)
        var payload = read_u64(p, at)
        if not head.has(ACK):
            write_ping(self.out, payload, True)
            return
        if payload == SHUTDOWN_PING and self._shutdown == 1:
            self._final_goaway(Reason.NO_ERROR)
            return
        self.pongs += 1

    def _goaway(
        mut self,
        head: FrameHead,
        p: Pointer[UInt8, ImmUntrackedOrigin],
        at: Int,
    ) raises H2Error:
        """Take the peer's `GOAWAY`: refuse the streams it did not process."""
        check_goaway(head)
        var last = read_u31(p, at)
        var reason = Reason(UInt32(read_u32(p, at + 4)))
        self.goaway_received = True
        self.remote_last_stream = min(last, self.remote_last_stream)
        var index = 0
        while index < len(self.streams):
            var id = self.streams[index].id
            if id != 0 and self._is_local(id) and id > last:
                self._drop(index)
                self.events.append(
                    Event(
                        EventKind.RESET,
                        id,
                        H2Error(
                            H2ErrorKind.REMOTE_GOAWAY,
                            reason,
                            id,
                            "the peer did not process the stream",
                        ),
                    )
                )
            index += 1

    def _window_update(
        mut self,
        head: FrameHead,
        p: Pointer[UInt8, ImmUntrackedOrigin],
        at: Int,
    ) raises H2Error:
        """Grow a send window, and send what waited for it."""
        check_window_update(head)
        var increment = read_u31(p, at)
        if head.stream_id == 0:
            if increment == 0:
                raise H2Error.connection(
                    Reason.PROTOCOL_ERROR, "WINDOW_UPDATE of 0"
                )
            if self.send_window + increment > MAX_WINDOW_SIZE:
                raise H2Error.connection(
                    Reason.FLOW_CONTROL_ERROR, "connection window overflow"
                )
            self.send_window += increment
            self._flush_all()
            return
        var index = self.find(head.stream_id)
        if index < 0:
            if self._is_idle(head.stream_id):
                raise H2Error.connection(
                    Reason.PROTOCOL_ERROR, "WINDOW_UPDATE on an idle stream"
                )
            return
        if increment == 0:
            raise H2Error.stream(
                head.stream_id, Reason.PROTOCOL_ERROR, "WINDOW_UPDATE of 0"
            )
        if self.streams[index].send_window + increment > MAX_WINDOW_SIZE:
            raise H2Error.stream(
                head.stream_id,
                Reason.FLOW_CONTROL_ERROR,
                "stream window overflow",
            )
        self.streams[index].send_window += increment
        self._flush(index)

    def _rst_stream(
        mut self,
        head: FrameHead,
        p: Pointer[UInt8, ImmUntrackedOrigin],
        at: Int,
    ) raises H2Error:
        """Take the peer's reset of a stream."""
        check_rst_stream(head)
        var reason = Reason(UInt32(read_u32(p, at)))
        var index = self.find(head.stream_id)
        if index < 0:
            if self._is_idle(head.stream_id):
                raise H2Error.connection(
                    Reason.PROTOCOL_ERROR, "RST_STREAM on an idle stream"
                )
            return
        if not self.streams[index].answered:
            self._remote_resets += 1
            if self._remote_resets > self.config.max_remote_resets:
                raise H2Error.connection(
                    Reason.ENHANCE_YOUR_CALM, "too many streams reset"
                )
        self._drop(index)
        self.events.append(
            Event(
                EventKind.RESET,
                head.stream_id,
                H2Error(
                    H2ErrorKind.REMOTE_RESET,
                    reason,
                    head.stream_id,
                    "the peer reset the stream",
                ),
            )
        )

    def _data(
        mut self,
        head: FrameHead,
        p: Pointer[UInt8, ImmUntrackedOrigin],
        at: Int,
    ) raises H2Error:
        """Take content: check the windows, the state and the length."""
        var id = head.stream_id
        if id == 0:
            raise H2Error.connection(Reason.PROTOCOL_ERROR, "DATA on stream 0")
        var bounds = data_payload(head, p, at)
        # The whole payload, padding too, counts against the windows.
        if head.length > self.recv_window:
            raise H2Error.connection(
                Reason.FLOW_CONTROL_ERROR,
                "DATA overflows the connection window",
            )
        self.recv_window -= head.length
        self._unacked += head.length
        if self._unacked >= self.config.connection_window_size // 2:
            write_window_update(self.out, 0, self._unacked)
            self.recv_window += self._unacked
            self._unacked = 0
        var index = self.find(id)
        if index < 0:
            if self._is_idle(id):
                raise H2Error.connection(
                    Reason.PROTOCOL_ERROR, "DATA on an idle stream"
                )
            raise H2Error.stream(
                id, Reason.STREAM_CLOSED, "DATA on a closed stream"
            )
        if not self.streams[index].state.can_receive():
            raise H2Error.stream(
                id, Reason.STREAM_CLOSED, "DATA after the end of the stream"
            )
        if head.length > self.streams[index].recv_window:
            raise H2Error.stream(
                id,
                Reason.FLOW_CONTROL_ERROR,
                "DATA overflows the stream window",
            )
        self.streams[index].recv_window -= head.length
        var size = bounds[1] - bounds[0]
        var end = head.has(END_STREAM)
        if size == 0 and not end:
            self._empty_frames += 1
            if self._empty_frames > self.config.max_empty_data_frames:
                raise H2Error.connection(
                    Reason.ENHANCE_YOUR_CALM, "too many empty DATA frames"
                )
        if len(self.streams[index].body) + size > self.config.max_body_bytes:
            if self.role == Role.SERVER:
                self._reject(index, 413, Reason.CANCEL)
                return
            raise H2Error.stream(
                id, Reason.CANCEL, "the content is larger than allowed"
            )
        self.streams[index].body.extend(
            Span[UInt8, ImmUntrackedOrigin](
                unsafe_ptr=p.unsafe_offset(bounds[0]), length=size
            )
        )
        var expected = self.streams[index].content_length
        if expected >= 0 and len(self.streams[index].body) > expected:
            raise H2Error.stream(
                id, Reason.PROTOCOL_ERROR, "more content than content-length"
            )
        if end:
            self._end_remote(index)
            return
        self.streams[index].unacked += head.length
        if self.streams[index].unacked >= self.config.initial_window_size // 2:
            var amount = self.streams[index].unacked
            write_window_update(self.out, id, amount)
            self.streams[index].recv_window += amount
            self.streams[index].unacked = 0

    def _headers(
        mut self,
        head: FrameHead,
        p: Pointer[UInt8, ImmUntrackedOrigin],
        at: Int,
    ) raises H2Error:
        """Take a `HEADERS` frame: a whole block, or its first fragment."""
        var id = head.stream_id
        if id == 0:
            raise H2Error.connection(
                Reason.PROTOCOL_ERROR, "HEADERS on stream 0"
            )
        var bounds = headers_payload(head, p, at)
        var self_dependent = bounds[2] == id
        var end_stream = head.has(END_STREAM)
        if head.has(END_HEADERS):
            self._block_done(
                id,
                Span[UInt8, ImmUntrackedOrigin](
                    unsafe_ptr=p.unsafe_offset(bounds[0]),
                    length=bounds[1] - bounds[0],
                ),
                end_stream,
                self_dependent,
            )
            return
        self._block.clear()
        self._block.extend(
            Span[UInt8, ImmUntrackedOrigin](
                unsafe_ptr=p.unsafe_offset(bounds[0]),
                length=bounds[1] - bounds[0],
            )
        )
        self._block_stream = id
        self._block_end_stream = end_stream
        self._block_error = self_dependent
        self._continuations = 0
        self._check_block_size()

    def _continuation(
        mut self,
        head: FrameHead,
        p: Pointer[UInt8, ImmUntrackedOrigin],
        at: Int,
    ) raises H2Error:
        """Take more of a header block."""
        self._block.extend(
            Span[UInt8, ImmUntrackedOrigin](
                unsafe_ptr=p.unsafe_offset(at), length=head.length
            )
        )
        self._check_block_size()
        if not head.has(END_HEADERS):
            self._continuations += 1
            var limit = calc_max_continuation_frames(
                self.config.max_header_list_size, self.local.max_frame_size
            )
            if self._continuations > limit:
                raise H2Error.connection(
                    Reason.ENHANCE_YOUR_CALM, "too_many_continuations"
                )
            return
        var id = self._block_stream
        self._block_stream = 0
        self._block_done(
            id,
            Span[UInt8, ImmUntrackedOrigin](
                unsafe_ptr=_at(Int(self._block.unsafe_ptr())),
                length=len(self._block),
            ),
            self._block_end_stream,
            self._block_error,
        )

    def _check_block_size(self) raises H2Error:
        """Refuse a header block much larger than the header list limit."""
        if len(self._block) > 4 * self.config.max_header_list_size:
            raise H2Error.connection(
                Reason.ENHANCE_YOUR_CALM, "the header block is too large"
            )

    def _block_done(
        mut self,
        id: Int,
        block: Span[UInt8, ImmUntrackedOrigin],
        end_stream: Bool,
        self_dependent: Bool,
    ) raises H2Error:
        """Decode a whole header block, and give it to its stream."""
        self._scratch.clear()
        self._scratch.too_large = False
        try:
            self.decoder.decode(
                block, self.config.max_header_list_size, self._scratch
            )
        except e:
            raise H2Error.connection(Reason.COMPRESSION_ERROR, String(e))
        if self_dependent:
            raise H2Error.stream(
                id, Reason.PROTOCOL_ERROR, "stream depends on itself"
            )
        var index = self.find(id)
        if index >= 0:
            if not self.streams[index].state.can_receive():
                raise H2Error.stream(
                    id,
                    Reason.STREAM_CLOSED,
                    "HEADERS after the end of the stream",
                )
            if self.streams[index].got_head:
                self._trailers(index, end_stream)
                return
            self._response_head(index, end_stream)
            return
        if self._is_idle(id) and not self._is_local(id):
            if self.role == Role.SERVER:
                self._request_head(id, end_stream)
                return
            raise H2Error.connection(
                Reason.PROTOCOL_ERROR, "HEADERS on a stream the server opened"
            )
        if self._is_idle(id):
            raise H2Error.connection(
                Reason.PROTOCOL_ERROR, "HEADERS on an idle stream"
            )
        raise H2Error.stream(
            id, Reason.STREAM_CLOSED, "HEADERS on a closed stream"
        )

    def _request_head(mut self, id: Int, end_stream: Bool) raises H2Error:
        """Open a stream for the head of a request."""
        self.last_peer_stream = id
        if self.goaway_sent:
            # A stream above the last id of the final GOAWAY is ignored.
            return
        var limit = self.config.max_concurrent_streams
        if limit >= 0 and self._active >= limit:
            raise H2Error.stream(
                id, Reason.REFUSED_STREAM, "too many concurrent streams"
            )
        var state = (
            StreamState.HALF_CLOSED_REMOTE if end_stream else StreamState.OPEN
        )
        var index = self._open(id, state)
        swap(self.streams[index].headers, self._scratch)
        if self.streams[index].headers.too_large:
            self._reject(index, 431, Reason.PROTOCOL_ERROR)
            return
        self._check_request(index)
        self.streams[index].got_head = True
        if end_stream:
            self._message(index)

    def _response_head(mut self, index: Int, end_stream: Bool) raises H2Error:
        """Take the head of a response, or an informational one."""
        var id = self.streams[index].id
        if self._scratch.too_large:
            raise H2Error.stream(
                id, Reason.PROTOCOL_ERROR, "the response head is too large"
            )
        swap(self.streams[index].headers, self._scratch)
        self._check_response(index)
        if self.streams[index].status < 200:
            if end_stream:
                raise H2Error.stream(
                    id,
                    Reason.PROTOCOL_ERROR,
                    "an informational response ends the stream",
                )
            self.streams[index].headers.clear()
            self.streams[index].status = 0
            return
        self.streams[index].got_head = True
        if end_stream:
            self._end_remote(index)

    def _trailers(mut self, index: Int, end_stream: Bool) raises H2Error:
        """Check trailer fields, and drop them."""
        var id = self.streams[index].id
        if not end_stream:
            raise H2Error.stream(
                id, Reason.PROTOCOL_ERROR, "trailers without END_STREAM"
            )
        if self._scratch.too_large:
            raise H2Error.stream(
                id, Reason.PROTOCOL_ERROR, "the trailers are too large"
            )
        check_trailers(self._scratch, id)
        self._end_remote(index)

    def _check_request(mut self, index: Int) raises H2Error:
        """Check the head of a request, and keep what framing needs."""
        var head = check_request_head(
            self.streams[index].headers,
            self.streams[index].id,
            self.local.enable_connect_protocol,
        )
        self.streams[index].content_length = head.content_length
        self.streams[index].head_request = head.head_request

    def _check_response(mut self, index: Int) raises H2Error:
        """Check the head of a response, and keep its status."""
        var head = check_response_head(
            self.streams[index].headers, self.streams[index].id
        )
        self.streams[index].content_length = head.content_length
        self.streams[index].status = head.status

    # ------------------------------------------------------------------
    # Stream states

    def _is_local(self, id: Int) -> Bool:
        """Return True for an id that this endpoint opens."""
        return (id % 2 == 1) == (self.role == Role.CLIENT)

    def _is_idle(self, id: Int) -> Bool:
        """Return True for an id that no stream has used yet."""
        if self._is_local(id):
            return id >= self.next_stream_id
        return id > self.last_peer_stream

    def _open(mut self, id: Int, state: StreamState) -> Int:
        """Make a stream in a free slot, and return the slot."""
        var index = 0
        while index < len(self.streams) and self.streams[index].id != 0:
            index += 1
        if index == len(self.streams):
            self.streams.append(Stream())
        self.streams[index].reset(
            id,
            self.remote.initial_window_size,
            max(
                self.local.initial_window_size,
                self.local_acked.initial_window_size,
            ),
        )
        self.streams[index].state = state
        self._active += 1
        return index

    def _close(mut self, index: Int):
        """Mark a stream closed; free its slot when the driver is done."""
        self.streams[index].state = StreamState.CLOSED
        self._active -= 1
        if self.streams[index].released:
            self.streams[index].id = 0

    def _drop(mut self, index: Int):
        """Close a stream at once and free its slot."""
        if self.streams[index].state != StreamState.CLOSED:
            self._active -= 1
        self.streams[index].state = StreamState.CLOSED
        self.streams[index].id = 0

    def _end_remote(mut self, index: Int) raises H2Error:
        """The peer ended its side of a stream: the message is whole."""
        if self.streams[index].state == StreamState.OPEN:
            self.streams[index].state = StreamState.HALF_CLOSED_REMOTE
            self._message(index)
            return
        self._message(index)
        self._close(index)

    def _end_local(mut self, index: Int):
        """This endpoint ended its side of a stream."""
        if self.streams[index].state == StreamState.OPEN:
            self.streams[index].state = StreamState.HALF_CLOSED_LOCAL
        else:
            self._close(index)

    def _message(mut self, index: Int) raises H2Error:
        """Check the length of a whole message, and announce it."""
        var id = self.streams[index].id
        var expected = self.streams[index].content_length
        if expected >= 0 and len(self.streams[index].body) != expected:
            raise H2Error.stream(
                id,
                Reason.PROTOCOL_ERROR,
                "content does not match content-length",
            )
        self.events.append(
            Event(
                EventKind.MESSAGE,
                id,
                H2Error(H2ErrorKind.STREAM, Reason.NO_ERROR, id, ""),
            )
        )

    def _reject(
        mut self, index: Int, status: Int, reason: Reason
    ) raises H2Error:
        """Answer a request with an empty error response, such as 431, and
        reset the stream when the peer can still send on it."""
        var id = self.streams[index].id
        var fields = HeaderList()
        fields.add_text(":status", String(status))
        self._encode(fields)
        write_header_block(
            self.out,
            id,
            Span(self._encoded),
            True,
            self.remote.max_frame_size,
        )
        if self.streams[index].state.can_receive():
            write_rst_stream(self.out, id, reason)
        self._drop(index)

    def _stream_error(mut self, error: H2Error):
        """Reset a stream for an error that this endpoint found."""
        write_rst_stream(self.out, error.stream_id, error.reason)
        var index = self.find(error.stream_id)
        if index < 0:
            return
        self._drop(index)
        self.events.append(
            Event(EventKind.RESET, error.stream_id, error.copy())
        )

    def _fail(mut self, error: H2Error):
        """End the connection for an error: send `GOAWAY` with the error."""
        write_goaway(
            self.out,
            self.last_peer_stream,
            error.reason,
            error.message.as_bytes(),
        )
        self.goaway_sent = True
        self.closed = True
        self.error = error.copy()

    # ------------------------------------------------------------------
    # Sending

    def _encode(mut self, fields: HeaderList):
        """Encode a header block into `_encoded`."""
        self._encoded.clear()
        self.encoder.encode(fields, self._encoded)

    def send_headers(
        mut self, stream_id: Int, fields: HeaderList, end_stream: Bool
    ) raises H2Error:
        """Send a head on a stream: the fields of a request or a response.

        Args:
            stream_id: The stream.
            fields: The fields, pseudo-header fields first, names in
                lowercase.
            end_stream: Whether the message has no content.

        Raises:
            H2Error: `USAGE` when the stream is not active or this endpoint
                has ended its side.
        """
        var index = self._sendable(stream_id)
        self._encode(fields)
        write_header_block(
            self.out,
            stream_id,
            Span(self._encoded),
            end_stream,
            self.remote.max_frame_size,
        )
        self.streams[index].answered = True
        if self.role == Role.SERVER:
            self._remote_resets = 0
        if end_stream:
            self._end_local(index)

    def send_data(
        mut self, stream_id: Int, data: Span[UInt8, _], end_stream: Bool
    ) raises H2Error:
        """Send content on a stream, as far as the windows allow; the rest
        goes out when the peer grows them.

        Args:
            stream_id: The stream.
            data: The content.
            end_stream: Whether the content ends the message.

        Raises:
            H2Error: `USAGE` when the stream is not active or this endpoint
                has ended its side.
        """
        var index = self._sendable(stream_id)
        if self.streams[index].end_after_out:
            raise H2Error.usage("the message has ended")
        self.streams[index].out.extend(data)
        self.streams[index].end_after_out = end_stream
        self._flush(index)

    def _sendable(self, stream_id: Int) raises H2Error -> Int:
        """Return the slot of a stream that this endpoint can send on."""
        var index = self.find(stream_id)
        if index < 0 or self.closed:
            raise H2Error.usage("stream " + String(stream_id) + " is not open")
        if not self.streams[index].state.can_send():
            raise H2Error.usage(
                "stream " + String(stream_id) + " has ended its side"
            )
        return index

    def _flush(mut self, index: Int):
        """Send the waiting content of a stream that the windows allow."""
        var id = self.streams[index].id
        while True:
            var rest = self.streams[index].pending()
            var end = self.streams[index].end_after_out
            if rest == 0:
                if end:
                    write_data(
                        self.out, id, Span[UInt8, ImmUntrackedOrigin](), True
                    )
                    self.streams[index].end_after_out = False
                    self._end_local(index)
                return
            var size = min(
                rest,
                self.streams[index].send_window,
                self.send_window,
                self.remote.max_frame_size,
            )
            if size <= 0:
                return
            var last = size == rest
            var start = self.streams[index].out_at
            var address = Int(self.streams[index].out.unsafe_ptr()) + start
            write_data(
                self.out,
                id,
                Span[UInt8, ImmUntrackedOrigin](
                    unsafe_ptr=_at(address), length=size
                ),
                last and end,
            )
            self.streams[index].send_window -= size
            self.send_window -= size
            self.streams[index].out_at += size
            if last:
                self.streams[index].out.clear()
                self.streams[index].out_at = 0
                if end:
                    self.streams[index].end_after_out = False
                    self._end_local(index)
                return

    def _flush_all(mut self):
        """Send the waiting content of every stream that the windows allow."""
        var index = 0
        while index < len(self.streams):
            if (
                self.streams[index].id != 0
                and self.streams[index].pending() > 0
            ):
                self._flush(index)
            index += 1

    def pending_output(self) -> Int:
        """Return the content that waits for a window, over all streams.

        Returns:
            The count of bytes.
        """
        var total = 0
        var index = 0
        while index < len(self.streams):
            if self.streams[index].id != 0:
                total += self.streams[index].pending()
            index += 1
        return total

    def reset_stream(mut self, stream_id: Int, reason: Reason):
        """Reset a stream with `RST_STREAM`, and free its slot. A stream
        that is not active is ignored.

        Args:
            stream_id: The stream.
            reason: The error code.
        """
        var index = self.find(stream_id)
        if index < 0 or self.closed:
            return
        write_rst_stream(self.out, stream_id, reason)
        self._drop(index)

    def release(mut self, stream_id: Int):
        """Tell the connection that the driver is done with a stream's
        message. The slot is free at once when the stream is closed, else
        when it closes.

        Args:
            stream_id: The stream.
        """
        var index = self.find(stream_id)
        if index < 0:
            return
        self.streams[index].released = True
        if self.streams[index].state == StreamState.CLOSED:
            self.streams[index].id = 0

    def open_stream(mut self) raises H2Error -> Int:
        """Open a new stream of this endpoint, for a request.

        Returns:
            The stream id.

        Raises:
            H2Error: `REMOTE_GOAWAY` after the peer's `GOAWAY`; `IO` when the
                connection has ended; `USAGE` when the peer allows no more
                streams now, or the ids are used up.
        """
        if self.closed:
            raise H2Error.io("the connection has ended")
        if self.goaway_received:
            raise H2Error(
                H2ErrorKind.REMOTE_GOAWAY,
                Reason.REFUSED_STREAM,
                0,
                "the peer sent GOAWAY",
            )
        var limit = self.remote.max_concurrent_streams
        if limit >= 0 and self._active >= limit:
            raise H2Error.usage("the peer allows no more streams now")
        var id = self.next_stream_id
        if id > MAX_STREAM_ID:
            raise H2Error.usage("the stream ids are used up")
        self.next_stream_id += 2
        _ = self._open(id, StreamState.OPEN)
        return id

    # ------------------------------------------------------------------
    # Ending

    def begin_shutdown(mut self):
        """Begin a graceful shutdown, as h2 does it.

        A server sends `GOAWAY` with the largest stream id, and a `PING`.
        When the `PING` comes back, it sends `GOAWAY` with the last stream
        that it took, so that no request in flight is lost. A client sends
        its final `GOAWAY` at once. The active streams go on to their end.
        """
        if self._shutdown != 0 or self.closed:
            return
        if self.role == Role.CLIENT:
            self._final_goaway(Reason.NO_ERROR)
            return
        write_goaway(
            self.out,
            MAX_STREAM_ID,
            Reason.NO_ERROR,
            Span[UInt8, ImmUntrackedOrigin](),
        )
        write_ping(self.out, SHUTDOWN_PING, False)
        self._shutdown = 1

    def _final_goaway(mut self, reason: Reason):
        """Send the `GOAWAY` with the last stream that this endpoint took."""
        write_goaway(
            self.out,
            self.last_peer_stream,
            reason,
            Span[UInt8, ImmUntrackedOrigin](),
        )
        self.goaway_sent = True
        self._shutdown = 2

    def abort(mut self, reason: Reason):
        """End the connection at once with `GOAWAY`.

        Args:
            reason: The error code, such as `NO_ERROR`.
        """
        if self.closed:
            return
        self._final_goaway(reason)
        self.closed = True

    # ------------------------------------------------------------------
    # The h2c upgrade (RFC 7540 section 3.2)

    def upgrade(
        mut self, settings: Span[UInt8, _], head_request: Bool
    ) raises H2Error -> Int:
        """Make stream 1 for the request of an HTTP/1.1 upgrade, as a server.

        The settings of the `HTTP2-Settings` field apply as if a `SETTINGS`
        frame brought them; the 101 response acknowledges them. Stream 1 is
        half-closed (remote): the request is whole. Call it before `start`.

        Args:
            settings: The decoded `HTTP2-Settings` value, a `SETTINGS`
                payload.
            head_request: Whether the request is `HEAD`.

        Returns:
            The slot of stream 1.

        Raises:
            H2Error: A connection error for an invalid setting, or a size
                that is not a multiple of 6.
        """
        if len(settings) % 6 != 0:
            raise H2Error.connection(
                Reason.FRAME_SIZE_ERROR,
                "HTTP2-Settings size is not a multiple of 6",
            )
        self.remote.apply(
            _at(Int(settings.unsafe_ptr())), 0, len(settings), False
        )
        self.encoder.update_max_size(min(self.remote.header_table_size, 4096))
        self.last_peer_stream = 1
        var index = self._open(1, StreamState.HALF_CLOSED_REMOTE)
        self.streams[index].got_head = True
        self.streams[index].head_request = head_request
        return index


@always_inline
def _at(address: Int) -> Pointer[UInt8, ImmUntrackedOrigin]:
    """Return a read-only pointer to an address, without an origin."""
    return Pointer[UInt8, ImmUntrackedOrigin](unsafe_from_address=address)


def _eq(bytes: Span[UInt8, _], text: StaticString) -> Bool:
    """Return True when bytes equal a text, byte for byte."""
    var other = text.as_bytes()
    if len(bytes) != len(other):
        return False
    var index = 0
    while index < len(bytes):
        if bytes[index] != other[index]:
            return False
        index += 1
    return True


def _malformed(id: Int, message: String) -> H2Error:
    """Return the stream error of a malformed message (RFC 9113 section
    8.1.1)."""
    return H2Error.stream(id, Reason.PROTOCOL_ERROR, message)


def _parse_length(value: Span[UInt8, _]) -> Int:
    """Return a `content-length` value, or -1 when it is not digits."""
    if len(value) == 0 or len(value) > 15:
        return -1
    var result = 0
    var index = 0
    while index < len(value):
        var byte = value[index]
        if byte < 48 or byte > 57:
            return -1
        result = result * 10 + Int(byte - 48)
        index += 1
    return result


@fieldwise_init
struct MessageHead(ImplicitlyCopyable):
    """What the checks of a head keep for framing."""

    var content_length: Int
    """The `content-length` value, or -1."""
    var status: Int
    """The `:status` of a response, or 0."""
    var head_request: Bool
    """Whether the request is `HEAD`."""


def check_regular_field(
    id: Int, name: Span[UInt8, _], value: Span[UInt8, _], request: Bool
) raises H2Error -> Int:
    """Check a regular field of a message (RFC 9113 section 8.2).

    Args:
        id: The stream, for the error.
        name: The name; it must be a lowercase token.
        value: The value; it must not hold a control byte but HTAB.
        request: Whether the field is in a request, where `te: trailers`
            is allowed.

    Returns:
        The value of a `content-length` field, else -1.

    Raises:
        H2Error: A stream error `PROTOCOL_ERROR` for an invalid name or
            value, a connection-specific field, `te` other than `trailers`,
            or an invalid `content-length`.
    """
    var at = 0
    while at < len(name):
        var byte = name[at]
        if not is_tchar(byte) or (byte >= 65 and byte <= 90):
            raise _malformed(id, "invalid field name")
        at += 1
    if len(name) == 0:
        raise _malformed(id, "empty field name")
    at = 0
    while at < len(value):
        var byte = value[at]
        if (byte < 32 and byte != 9) or byte == 127:
            raise _malformed(id, "invalid field value")
        at += 1
    if (
        _eq(name, "connection")
        or _eq(name, "keep-alive")
        or _eq(name, "proxy-connection")
        or _eq(name, "transfer-encoding")
        or _eq(name, "upgrade")
    ):
        raise _malformed(id, "a connection-specific field")
    if _eq(name, "te") and not (request and _eq(value, "trailers")):
        raise _malformed(id, "te other than trailers")
    if _eq(name, "content-length"):
        var length = _parse_length(value)
        if length < 0:
            raise _malformed(id, "invalid content-length")
        return length
    return -1


def _content_length(id: Int, current: Int, length: Int) raises H2Error -> Int:
    """Merge one `content-length` value into the one found so far."""
    if length < 0:
        return current
    if current >= 0 and current != length:
        raise _malformed(id, "content-length values differ")
    return length


def check_request_head(
    fields: HeaderList, id: Int, connect_protocol: Bool
) raises H2Error -> MessageHead:
    """Check the head of a request (RFC 9113 section 8.3.1).

    Args:
        fields: The fields, as decoded.
        id: The stream, for the error.
        connect_protocol: Whether the extended `CONNECT` of RFC 8441 is
            allowed, with `:protocol`.

    Returns:
        The `content-length` value and whether the method is `HEAD`.

    Raises:
        H2Error: A stream error `PROTOCOL_ERROR` for a malformed request:
            an unknown, repeated or late pseudo-header field, a missing
            `:method`, `:scheme` or `:path`, an empty or invalid `:path`, an
            invalid `:method` or `:authority`, `:protocol` where it is not
            allowed, or an invalid regular field.
    """
    var method = -1
    var scheme = -1
    var authority = -1
    var path = -1
    var protocol = -1
    var length = -1
    var regular = False
    var i = 0
    while i < fields.count():
        var name = fields.name(i)
        if len(name) > 0 and name[0] == 58:
            if regular:
                raise _malformed(id, "a pseudo-header after a regular field")
            if _eq(name, ":method"):
                method = _once(id, method, i)
            elif _eq(name, ":scheme"):
                scheme = _once(id, scheme, i)
            elif _eq(name, ":authority"):
                authority = _once(id, authority, i)
            elif _eq(name, ":path"):
                path = _once(id, path, i)
            elif _eq(name, ":protocol"):
                protocol = _once(id, protocol, i)
            else:
                raise _malformed(id, "an invalid pseudo-header in a request")
        else:
            regular = True
            length = _content_length(
                id, length, check_regular_field(id, name, fields.value(i), True)
            )
        i += 1
    if method < 0:
        raise _malformed(id, "a request without :method")
    var method_value = fields.value(method)
    var at = 0
    while at < len(method_value):
        if not is_tchar(method_value[at]):
            raise _malformed(id, "an invalid :method")
        at += 1
    var connect = _eq(method_value, "CONNECT")
    if protocol >= 0 and not (connect and connect_protocol):
        raise _malformed(id, ":protocol where it is not allowed")
    if connect and protocol < 0:
        if scheme >= 0 or path >= 0:
            raise _malformed(id, "CONNECT with :scheme or :path")
        if authority < 0:
            raise _malformed(id, "CONNECT without :authority")
    else:
        if scheme < 0 or path < 0:
            raise _malformed(id, "a request without :scheme or :path")
        var path_value = fields.value(path)
        if len(path_value) == 0:
            raise _malformed(id, "an empty :path")
        at = 0
        while at < len(path_value):
            var byte = path_value[at]
            if byte <= 32 or byte >= 127:
                raise _malformed(id, "an invalid :path")
            at += 1
    if authority >= 0:
        var value = fields.value(authority)
        at = 0
        while at < len(value):
            if not is_host_byte(value[at]):
                raise _malformed(id, "an invalid :authority")
            at += 1
    return MessageHead(length, 0, _eq(method_value, "HEAD"))


def check_response_head(
    fields: HeaderList, id: Int
) raises H2Error -> MessageHead:
    """Check the head of a response (RFC 9113 section 8.3.2).

    Args:
        fields: The fields, as decoded.
        id: The stream, for the error.

    Returns:
        The `content-length` value and the status.

    Raises:
        H2Error: A stream error `PROTOCOL_ERROR` for a malformed response:
            a pseudo-header field other than one `:status`, a status that is
            not three digits or is 101, or an invalid regular field.
    """
    var status = -1
    var length = -1
    var regular = False
    var i = 0
    while i < fields.count():
        var name = fields.name(i)
        if len(name) > 0 and name[0] == 58:
            if regular or not _eq(name, ":status") or status >= 0:
                raise _malformed(id, "an invalid pseudo-header in a response")
            var value = fields.value(i)
            status = _parse_length(value)
            if len(value) != 3 or status < 100:
                raise _malformed(id, "an invalid :status")
        else:
            regular = True
            length = _content_length(
                id,
                length,
                check_regular_field(id, name, fields.value(i), False),
            )
        i += 1
    if status < 0:
        raise _malformed(id, "a response without :status")
    if status == 101:
        raise _malformed(id, "101 is not allowed in HTTP/2")
    return MessageHead(length, status, False)


def check_trailers(fields: HeaderList, id: Int) raises H2Error:
    """Check the trailer fields of a message (RFC 9113 section 8.1).

    Args:
        fields: The fields, as decoded.
        id: The stream, for the error.

    Raises:
        H2Error: A stream error `PROTOCOL_ERROR` for a pseudo-header field
            or an invalid regular field.
    """
    var i = 0
    while i < fields.count():
        var name = fields.name(i)
        if len(name) > 0 and name[0] == 58:
            raise _malformed(id, "a pseudo-header in trailers")
        _ = check_regular_field(id, name, fields.value(i), False)
        i += 1


def _once(id: Int, seen: Int, index: Int) raises H2Error -> Int:
    """Return the index of a pseudo-header field that must be unique."""
    if seen >= 0:
        raise _malformed(id, "a repeated pseudo-header")
    return index

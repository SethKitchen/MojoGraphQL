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

from gql_http.scan import is_tchar

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
        return (
            self == StreamState.OPEN or self == StreamState.HALF_CLOSED_LOCAL
        )

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

    def skip_preface(mut self):
        """Take the client preface as read already, as after an h2c upgrade
        whose preface the driver checked."""
        self._preface = False

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
            var p = self._input.unsafe_ptr()
            var index = 0
            while index < rest:
                p[index] = p[self._in_start + index]
                index += 1
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
        while not self.closed:
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
        mut self, head: FrameHead, p: Pointer[UInt8, ImmUntrackedOrigin], at: Int
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
        mut self, head: FrameHead, p: Pointer[UInt8, ImmUntrackedOrigin], at: Int
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
        mut self, head: FrameHead, p: Pointer[UInt8, ImmUntrackedOrigin], at: Int
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
        mut self, head: FrameHead, p: Pointer[UInt8, ImmUntrackedOrigin], at: Int
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
        mut self, head: FrameHead, p: Pointer[UInt8, ImmUntrackedOrigin], at: Int
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
        mut self, head: FrameHead, p: Pointer[UInt8, ImmUntrackedOrigin], at: Int
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

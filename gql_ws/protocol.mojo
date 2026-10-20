# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The WebSocket protocol after the handshake (RFC 6455 sections 5 to 7),
without input or output: a `WebSocket` reads the bytes that its caller
gives it, and holds the bytes for its caller to send.

`read` returns one message at a time: text, binary, ping, pong or close.
It joins fragments, checks text as UTF-8 as it arrives, answers a ping
with a pong, and answers a close frame. `send_text`, `send_binary`,
`ping`, `pong` and `close` add frames to the output. A client masks each
frame with a new key.

Limits: `WsConfig.max_frame_size` and `max_message_size` bound what the
peer can send, and `max_write_buffer_size` bounds the output that waits
for the peer. A send that does not fit raises `WRITE_BUFFER_FULL`: that is
the back pressure of a slow peer.

This module ports tungstenite 0.30.0 `src/protocol/mod.rs`
(`WebSocketContext`, `WebSocketState`, `WebSocketConfig`),
`src/protocol/message.rs` (`IncompleteMessage`) and the codec of
`src/protocol/frame/mod.rs` (`FrameCodec::read_frame`, `buffer_frame`),
with their tests.

Differences from upstream:

- **The endpoint fails the connection.** On an error that the peer
  caused, the `WebSocket` adds a close frame with the code of the error
  (1002, 1007 or 1009) to the output, and ends. tungstenite returns the
  error and sends nothing. This is the behavior of the Node `ws`
  receiver, and RFC 6455 section 7.1.7.
- **No error after the closing handshake.** `read` returns False when the
  connection can read no more, and `should_close` tells the caller to
  close the socket. tungstenite raises `ConnectionClosed`.
- **Control frames skip the write limit.** A pong or a close frame is at
  most 131 bytes, and goes into the output even when it is full.
- **A close with code 1005** sends a close frame without a payload, the
  `None` of `close(None)`.
"""

from std.memory import unsafe_memcpy

from gql_http.scan import move_down

from gql_ws.error import WsError, WsErrorKind
from gql_ws.frame import (
    CloseCode,
    HeaderState,
    OpCode,
    apply_mask,
    header_size,
    parse_header,
    random_mask,
    write_header,
)
from gql_ws.utf8 import Utf8Validator, is_utf8


@fieldwise_init
struct Role(Equatable, ImplicitlyCopyable, Writable):
    """The side of a connection, as a type and not a bare integer."""

    var value: UInt8
    """The role's index; see `is_valid`."""

    comptime SERVER = Role(0)
    """The server: it reads masked frames and sends unmasked ones."""
    comptime CLIENT = Role(1)
    """The client: it masks each frame that it sends."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the roles.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 1

    def write_to(self, mut writer: Some[Writer]):
        """Write `server` or `client`.

        Args:
            writer: The destination.
        """
        writer.write("server" if self.value == 0 else "client")


@fieldwise_init
struct WsState(Equatable, ImplicitlyCopyable, Writable):
    """The closing handshake state, as tungstenite `WebSocketState`."""

    var value: UInt8
    """The state's index; see `is_valid`."""

    comptime ACTIVE = WsState(0)
    """The connection is open both ways."""
    comptime CLOSED_BY_US = WsState(1)
    """This endpoint sent a close frame and waits for the reply."""
    comptime CLOSED_BY_PEER = WsState(2)
    """The peer sent a close frame, and this endpoint replied."""
    comptime CLOSE_ACKNOWLEDGED = WsState(3)
    """Both close frames went across."""
    comptime TERMINATED = WsState(4)
    """The connection has ended."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the states.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 4

    def can_read(self) -> Bool:
        """Return True while the peer can still send frames.

        Returns:
            Whether the state is `ACTIVE` or `CLOSED_BY_US`.
        """
        return self.value <= 1

    def write_to(self, mut writer: Some[Writer]):
        """Write the index of the state.

        Args:
            writer: The destination.
        """
        writer.write(self.value)


@fieldwise_init
struct MessageKind(Equatable, ImplicitlyCopyable, Writable):
    """The kind of a message, as a type and not a bare integer."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime TEXT = MessageKind(0)
    """A text message: UTF-8."""
    comptime BINARY = MessageKind(1)
    """A binary message."""
    comptime PING = MessageKind(2)
    """A ping; the endpoint answered it already."""
    comptime PONG = MessageKind(3)
    """A pong."""
    comptime CLOSE = MessageKind(4)
    """A close frame; `Message.code` holds its code."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 4

    def write_to(self, mut writer: Some[Writer]):
        """Write the name of the kind.

        Args:
            writer: The destination.
        """
        comptime names: Array[StaticString, 5] = [
            "text",
            "binary",
            "ping",
            "pong",
            "close",
        ]
        writer.write(materialize[names]()[Int(self.value)])


struct Message(Copyable, Movable):
    """One message. A caller can use one `Message` for many reads, so its
    buffer is allocated once."""

    var kind: MessageKind
    """The kind."""
    var data: List[UInt8]
    """The payload; the reason of a close frame."""
    var code: CloseCode
    """The code of a close frame; `CloseCode.STATUS` when it had none."""

    def __init__(out self):
        """Make an empty text message."""
        self.kind = MessageKind.TEXT
        self.data = List[UInt8]()
        self.code = CloseCode.STATUS

    def text(self) -> StringSlice[origin_of(self.data)]:
        """Return the payload as text.

        Returns:
            The text; the payload of a text message is UTF-8.
        """
        return StringSlice(unsafe_from_utf8=Span(self.data))


@fieldwise_init
struct WsConfig(Copyable, Movable):
    """The limits of a connection, as tungstenite `WebSocketConfig`."""

    var max_message_size: Int
    """The largest message that the peer can send; 64 MiB at first."""
    var max_frame_size: Int
    """The largest frame that the peer can send; 16 MiB at first."""
    var max_write_buffer_size: Int
    """The most output that can wait for the peer; no limit at first."""
    var accept_unmasked_frames: Bool
    """Whether a server reads unmasked frames; False at first."""

    def __init__(out self):
        """Make the default limits of tungstenite."""
        self.max_message_size = 64 << 20
        self.max_frame_size = 16 << 20
        self.max_write_buffer_size = Int.MAX
        self.accept_unmasked_frames = False


def _too_long(size: Int, max_size: Int) -> WsError:
    """Make the error of a message or a frame over its limit."""
    return WsError(
        WsErrorKind.CAPACITY,
        "Message too long: " + String(size) + " > " + String(max_size),
        1009,
        0,
    )


def _invalid_utf8() -> WsError:
    """Make the error of text that is not UTF-8."""
    return WsError(WsErrorKind.UTF8, "invalid UTF-8", 1007, 0)


struct WebSocket(Movable):
    """One end of a WebSocket connection, without input or output.

    Give it the bytes of the socket with `receive`, or with
    `write_pointer`, `space` and `commit`. Call `read` for each message.
    Send the bytes of `output` and call `advance` with the count sent.
    """

    var role: Role
    """The side of the connection."""
    var config: WsConfig
    """The limits."""
    var state: WsState
    """The closing handshake state."""
    var input: List[UInt8]
    """The bytes from the peer; the unread ones start at `_read`."""
    var out: List[UInt8]
    """The bytes for the peer; the unsent ones start at `_sent`."""
    var _read: Int
    var _filled: Int
    var _sent: Int
    var _partial: List[UInt8]
    var _partial_kind: MessageKind
    var _fragmented: Bool
    var _utf8: Utf8Validator

    def __init__(out self, role: Role, config: WsConfig = WsConfig()):
        """Start a connection after the handshake.

        Args:
            role: The side of the connection.
            config: The limits.
        """
        self.role = role
        self.config = config.copy()
        self.state = WsState.ACTIVE
        self.input = List[UInt8]()
        self.out = List[UInt8]()
        self._read = 0
        self._filled = 0
        self._sent = 0
        self._partial = List[UInt8]()
        self._partial_kind = MessageKind.TEXT
        self._fragmented = False
        self._utf8 = Utf8Validator()

    # Input

    def receive(mut self, data: Span[UInt8, _]):
        """Add bytes from the peer.

        Args:
            data: The bytes, in the order of the stream.
        """
        self.reserve(len(data))
        unsafe_memcpy(
            dest=self.input.unsafe_ptr().unsafe_offset(self._filled),
            src=data.unsafe_ptr(),
            count=len(data),
        )
        self._filled += len(data)

    def reserve(mut self, size: Int):
        """Make room for at least `size` more bytes at `write_pointer`.

        Args:
            size: The count of bytes.
        """
        if self._read > 0 and self._read == self._filled:
            self._read = 0
            self._filled = 0
        if len(self.input) - self._filled >= size:
            return
        if self._read > 0:
            var rest = self._filled - self._read
            move_down(self.input.unsafe_ptr(), 0, self._read, rest)
            self._read = 0
            self._filled = rest
        if len(self.input) - self._filled < size:
            self.input.resize(max(len(self.input) * 2, self._filled + size), 0)

    def write_pointer(
        mut self,
    ) -> Pointer[mut=True, UInt8, origin_of(self.input)]:
        """Return where the next bytes from the peer go.

        Returns:
            The pointer; `space` bytes are free there.
        """
        return self.input.unsafe_ptr().unsafe_offset(self._filled)

    def space(self) -> Int:
        """Return the free bytes at `write_pointer`.

        Returns:
            The count.
        """
        return len(self.input) - self._filled

    def commit(mut self, count: Int):
        """Take `count` bytes that the caller wrote at `write_pointer`.

        Args:
            count: The count of bytes.
        """
        self._filled += count

    def buffered(self) -> Int:
        """Return the count of bytes that `read` has not used.

        Returns:
            The count.
        """
        return self._filled - self._read

    # Output

    def pending(self) -> Int:
        """Return the count of bytes that wait to go to the peer.

        Returns:
            The count.
        """
        return len(self.out) - self._sent

    def output(self) -> Pointer[UInt8, origin_of(self.out)]:
        """Return the first byte that waits to go to the peer.

        Returns:
            The pointer; `pending` bytes are there.
        """
        return self.out.unsafe_ptr().unsafe_offset(self._sent)

    def advance(mut self, count: Int):
        """Drop bytes of the output that went to the peer.

        Args:
            count: The count of bytes sent.
        """
        self._sent += count
        if self._sent >= len(self.out):
            self.out.clear()
            self._sent = 0

    def can_read(self) -> Bool:
        """Return True while the peer can send messages.

        Returns:
            Whether no close frame came from the peer.
        """
        return self.state.can_read()

    def can_write(self) -> Bool:
        """Return True while this endpoint can send messages.

        Returns:
            Whether the state is `ACTIVE`.
        """
        return self.state == WsState.ACTIVE

    def should_close(self) -> Bool:
        """Return True when the caller should close the socket, once the
        output has gone out.

        A server closes the TCP connection first after the closing
        handshake (RFC 6455 section 7.1.1); a client closes it once the
        handshake is done, or after a failure.

        Returns:
            Whether the connection has ended.
        """
        if self.state == WsState.TERMINATED:
            return True
        if self.role == Role.SERVER:
            return not self.state.can_read()
        return self.state == WsState.CLOSE_ACKNOWLEDGED

    def peer_closed(mut self) -> Bool:
        """Note that the peer closed the TCP connection.

        Returns:
            True after a closing handshake; False for a reset without one,
            tungstenite `ResetWithoutClosingHandshake`.
        """
        var clean = (
            self.state == WsState.CLOSED_BY_PEER
            or self.state == WsState.CLOSE_ACKNOWLEDGED
        )
        self.state = WsState.TERMINATED
        return clean

    # Reading

    def _fail(mut self, var error: WsError) -> WsError:
        """Fail the connection: send a close frame with the code of the
        error, and end. Return the error to raise."""
        if self.state == WsState.ACTIVE:
            var code = error.close_code
            var payload = List[UInt8]()
            payload.append(UInt8(code >> 8))
            payload.append(UInt8(code & 0xFF))
            self._frame(OpCode.CLOSE, True, payload)
        self.state = WsState.TERMINATED
        return error^

    def read(mut self, mut message: Message) raises WsError -> Bool:
        """Read the next message from the bytes that the peer sent.

        A ping gets its pong in the output at once. A close frame gets its
        reply, as RFC 6455 section 5.5.1 tells.

        Args:
            message: The message to fill; its buffer is used again.

        Returns:
            True with a message; False when the bytes hold no whole message,
            or when the peer can send no more.

        Raises:
            WsError: `ALREADY_CLOSED` after the end; `PROTOCOL`, `UTF8` or
                `CAPACITY` when the peer breaks RFC 6455 or a limit. Then
                the output holds a close frame with the code of the error.
        """
        if self.state == WsState.TERMINATED:
            raise WsError.of(
                WsErrorKind.ALREADY_CLOSED,
                "Trying to work with closed connection",
            )
        while True:
            var data = self.input.unsafe_ptr()
            var header = parse_header(data, self._read, self._filled)
            if header.state == HeaderState.INCOMPLETE:
                return False
            if header.state == HeaderState.INVALID_OPCODE:
                raise self._fail(
                    WsError.protocol(
                        "Encountered invalid opcode: "
                        + String(header.opcode.value)
                    )
                )
            if header.state == HeaderState.INVALID_LENGTH:
                raise self._fail(_too_long(Int.MAX, self.config.max_frame_size))
            var length = Int(header.length)
            if length > self.config.max_frame_size:
                raise self._fail(_too_long(length, self.config.max_frame_size))
            var start = self._read + header.size
            if self._filled - start < length:
                return False
            self._read = start + length
            if not self.state.can_read():
                raise self._fail(
                    WsError.protocol("Remote sent after having closed")
                )
            if header.rsv != 0:
                raise self._fail(WsError.protocol("Reserved bits are non-zero"))
            if self.role == Role.SERVER:
                if header.masked:
                    apply_mask(data, start, length, header.mask)
                elif not self.config.accept_unmasked_frames:
                    raise self._fail(
                        WsError.protocol(
                            "Received an unmasked frame from client"
                        )
                    )
            elif header.masked:
                raise self._fail(
                    WsError.protocol("Received a masked frame from server")
                )
            # The payload stays in `input` while the frame is handled, and
            # only `out` and `_partial` change.
            var payload = Span[UInt8, ImmUntrackedOrigin](
                unsafe_ptr=Pointer[UInt8, ImmUntrackedOrigin](
                    unsafe_from_address=Int(data) + start
                ),
                length=length,
            )
            if header.opcode.is_control():
                return self._control(
                    header.opcode, header.is_final, payload, message
                )
            if self._data(header.opcode, header.is_final, payload, message):
                return True

    def _control(
        mut self,
        opcode: OpCode,
        is_final: Bool,
        payload: Span[UInt8, _],
        mut message: Message,
    ) raises WsError -> Bool:
        """Handle a close, ping or pong frame."""
        if not is_final:
            raise self._fail(WsError.protocol("Fragmented control frame"))
        if len(payload) > 125:
            raise self._fail(
                WsError.protocol(
                    "Control frame too big (payload must be 125 bytes or less)"
                )
            )
        message.data.clear()
        if opcode == OpCode.PING:
            message.kind = MessageKind.PING
            message.data.extend(payload)
            if self.state == WsState.ACTIVE:
                self._frame(OpCode.PONG, True, payload)
            return True
        if opcode == OpCode.PONG:
            message.kind = MessageKind.PONG
            message.data.extend(payload)
            return True
        # The parser refuses the reserved opcodes, so this is a close.
        if len(payload) == 1:
            raise self._fail(WsError.protocol("Invalid close sequence"))
        message.kind = MessageKind.CLOSE
        message.code = CloseCode.STATUS
        if len(payload) >= 2:
            message.code = CloseCode(
                (UInt16(payload[0]) << 8) | UInt16(payload[1])
            )
            if not is_utf8(payload[2:]):
                raise self._fail(_invalid_utf8())
            message.data.extend(payload[2:])
        if self.state == WsState.CLOSED_BY_US:
            self.state = WsState.CLOSE_ACKNOWLEDGED
            return True
        self.state = WsState.CLOSED_BY_PEER
        if len(payload) == 0:
            self._frame(OpCode.CLOSE, True, payload)
        elif message.code.is_allowed():
            self._frame(OpCode.CLOSE, True, payload)
        else:
            var reply = List[UInt8]()
            reply.append(0x03)
            reply.append(0xEA)
            reply.extend(StaticString("Protocol violation").as_bytes())
            self._frame(OpCode.CLOSE, True, reply)
        return True

    def _data(
        mut self,
        opcode: OpCode,
        is_final: Bool,
        payload: Span[UInt8, _],
        mut message: Message,
    ) raises WsError -> Bool:
        """Handle a text, binary or continuation frame; True when a message
        is complete."""
        var limit = self.config.max_message_size
        if opcode == OpCode.CONTINUE:
            if not self._fragmented:
                raise self._fail(
                    WsError.protocol("Continue frame but nothing to continue")
                )
            var size = len(self._partial)
            if len(payload) > limit - size:
                raise self._fail(_too_long(size + len(payload), limit))
            var kind = self._partial_kind
            self._check_text(kind, payload)
            self._partial.extend(payload)
            if not is_final:
                return False
            self._fragmented = False
            self._finish_text(kind)
            message.kind = kind
            message.data.clear()
            message.data.extend(Span(self._partial))
            self._partial.clear()
            return True
        if self._fragmented:
            raise self._fail(
                WsError.protocol(
                    "While waiting for more fragments received: "
                    + opcode.text()
                )
            )
        if len(payload) > limit:
            raise self._fail(_too_long(len(payload), limit))
        var kind = (
            MessageKind.TEXT if opcode == OpCode.TEXT else MessageKind.BINARY
        )
        self._utf8.reset()
        self._check_text(kind, payload)
        if not is_final:
            self._fragmented = True
            self._partial_kind = kind
            self._partial.clear()
            self._partial.extend(payload)
            return False
        self._finish_text(kind)
        message.kind = kind
        message.data.clear()
        message.data.extend(payload)
        return True

    def _check_text(
        mut self, kind: MessageKind, payload: Span[UInt8, _]
    ) raises WsError:
        """Check the bytes of a text message as they arrive."""
        if kind != MessageKind.TEXT:
            return
        if not self._utf8.feed(payload.unsafe_ptr(), 0, len(payload)):
            raise self._fail(_invalid_utf8())

    def _finish_text(mut self, kind: MessageKind) raises WsError:
        """Check that a whole text message ends no sequence early."""
        if kind == MessageKind.TEXT and not self._utf8.is_complete():
            raise self._fail(_invalid_utf8())

    # Writing

    def _frame(
        mut self, opcode: OpCode, is_final: Bool, payload: Span[UInt8, _]
    ):
        """Add a frame to the output, masked when this is a client."""
        var masked = self.role == Role.CLIENT
        var mask: UInt32 = random_mask() if masked else 0
        write_header(self.out, is_final, opcode, len(payload), masked, mask)
        var start = len(self.out)
        self.out.extend(payload)
        if masked:
            apply_mask(self.out.unsafe_ptr(), start, len(payload), mask)

    def _check_send(mut self, size: Int) raises WsError:
        """Refuse a message after the end, after a close, or over the
        write limit."""
        if self.state == WsState.TERMINATED:
            raise WsError.of(
                WsErrorKind.ALREADY_CLOSED,
                "Trying to work with closed connection",
            )
        if self.state != WsState.ACTIVE:
            raise WsError.of(
                WsErrorKind.SEND_AFTER_CLOSING,
                "Sending after closing is not allowed",
            )
        var total = self.pending() + header_size(size, True) + size
        if total > self.config.max_write_buffer_size:
            raise WsError.of(
                WsErrorKind.WRITE_BUFFER_FULL, "Write buffer is full"
            )

    def send_text(mut self, text: StringSlice) raises WsError:
        """Add a text message to the output, in one frame.

        Args:
            text: The text.

        Raises:
            WsError: `ALREADY_CLOSED`, `SEND_AFTER_CLOSING`, or
                `WRITE_BUFFER_FULL` when the output has no room for it.
        """
        self._check_send(text.byte_length())
        self._frame(OpCode.TEXT, True, text.as_bytes())

    def send_binary(mut self, data: Span[UInt8, _]) raises WsError:
        """Add a binary message to the output, in one frame.

        Args:
            data: The bytes.

        Raises:
            WsError: As `send_text`.
        """
        self._check_send(len(data))
        self._frame(OpCode.BINARY, True, data)

    def send_fragment(
        mut self, opcode: OpCode, is_final: Bool, data: Span[UInt8, _]
    ) raises WsError:
        """Add one frame of a fragmented message to the output.

        The first frame has `OpCode.TEXT` or `OpCode.BINARY`, and the next
        ones `OpCode.CONTINUE`. The last one has `is_final`.

        Args:
            opcode: The opcode of the frame.
            is_final: Whether the frame ends the message.
            data: The payload.

        Raises:
            WsError: As `send_text`.
        """
        self._check_send(len(data))
        self._frame(opcode, is_final, data)

    def ping(mut self, data: Span[UInt8, _]) raises WsError:
        """Add a ping to the output.

        Args:
            data: The payload, at most 125 bytes.

        Raises:
            WsError: As `send_text`, and `PROTOCOL` for a payload over 125
                bytes.
        """
        self._control_send(OpCode.PING, data)

    def pong(mut self, data: Span[UInt8, _]) raises WsError:
        """Add an unsolicited pong to the output.

        Args:
            data: The payload, at most 125 bytes.

        Raises:
            WsError: As `ping`.
        """
        self._control_send(OpCode.PONG, data)

    def _control_send(
        mut self, opcode: OpCode, data: Span[UInt8, _]
    ) raises WsError:
        """Send a ping or a pong."""
        if len(data) > 125:
            raise WsError.protocol(
                "Control frame too big (payload must be 125 bytes or less)"
            )
        self._check_send(len(data))
        self._frame(opcode, True, data)

    def close(
        mut self, code: CloseCode = CloseCode.NORMAL, reason: StringSlice = ""
    ) raises WsError:
        """Start the closing handshake: add a close frame to the output.

        A second call does nothing, as tungstenite `close`.

        Args:
            code: The code; `CloseCode.STATUS` sends no code and no reason.
            reason: The reason, at most 123 bytes of UTF-8.

        Raises:
            WsError: `ALREADY_CLOSED` after the end; `PROTOCOL` for a
                reason over 123 bytes.
        """
        if self.state == WsState.TERMINATED:
            raise WsError.of(
                WsErrorKind.ALREADY_CLOSED,
                "Trying to work with closed connection",
            )
        if reason.byte_length() > 123:
            raise WsError.protocol("Close reason too long")
        self.go_away(code, reason)

    def go_away(mut self, code: CloseCode, reason: StringSlice = ""):
        """Start the closing handshake, without errors: as `close`, but it
        does nothing unless the state is `ACTIVE`.

        Args:
            code: The code; `CloseCode.STATUS` sends no code and no reason.
            reason: The reason; the caller keeps it to 123 bytes.
        """
        if self.state != WsState.ACTIVE:
            return
        self.state = WsState.CLOSED_BY_US
        var payload = List[UInt8]()
        if code != CloseCode.STATUS:
            payload.append(UInt8(code.value >> 8))
            payload.append(UInt8(code.value & 0xFF))
            payload.extend(reason.as_bytes())
        self._frame(OpCode.CLOSE, True, payload)

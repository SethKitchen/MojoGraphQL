# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""An HTTP/3 server (RFC 9114) for the `Handler` of `gql_http`.

The server runs on one UDP socket, over the QUIC API of OpenSSL 3.5.

`H3Server` runs one event loop in the calling thread. `poll` waits for a
datagram or a QUIC timer, lets OpenSSL run the network I/O of every
connection, then reads every stream that has bytes:

- A request stream (bidirectional, opened by the client) gets a HEADERS
  frame and DATA frames. At its end the server writes the request as
  HTTP/1.1, parses it with the `RequestReader` of `gql_http`, and calls
  the handler with a `ResponseWriter`. It sends the response as a HEADERS
  frame and a DATA frame, and ends the stream.
- The control stream of the client must start with SETTINGS. The server
  opens its own control stream with SETTINGS at once.
- The QPACK encoder and decoder streams go to the QPACK decoder and
  encoder. The server announces a dynamic table capacity of 0, so it uses
  the static table and literals only.
- A push stream from a client is an `H3_STREAM_CREATION_ERROR`; other
  stream types are read and dropped (RFC 9114 section 6.2.3).

A malformed request resets its stream with `H3_MESSAGE_ERROR`. A request
that `gql_http` refuses gets its error response, such as 431. A
connection error closes the connection with its code.

The writer has no socket here, so `ResponseWriter.flush` keeps the bytes.
Streamed content goes out after the handler returns.

This module ports the stream rules of hyperium/h3 h3-v0.0.8
h3/src/connection.rs and h3/src/server/connection.rs (MIT): the first
frame of the control stream, the unique critical streams, and the frames
that each stream type allows.

Performance: on the default `gql_quic` transport, the round trip is
faster than h3 with quinn. The OpenSSL QUIC stack sends each ACK in a
datagram of its own, so a round trip on that stack is slower.

Differences from upstream: h3 is generic over a QUIC implementation and
async. This server is a poll loop over the `Quic` handles, on `gql_quic`
or on the OpenSSL QUIC API. It sends no GOAWAY at shutdown, and it never
pushes.
"""

from std.memory import ArcPointer

from gql_http.parser import Limits, ParseState, RequestReader
from gql_http.server import Handler, ResponseWriter
from gql_http.socket import IPv4Address, POLLIN, Sys
from gql_http.status import Method
from gql_tls.error import TlsError, TlsErrorKind
from gql_http3.error import H3Error, H3ErrorCode
from gql_http3.frame import (
    FrameType,
    SettingId,
    Settings,
    StreamType,
    parse_frame_head,
    write_frame_header,
)
from gql_http3.message import (
    MessageReader,
    from_http1_response,
    to_http1_request,
    write_message,
)
from gql_http3.qpack_decoder import QpackDecoder
from gql_http3.qpack_encoder import QpackEncoder
from gql_http3.qpack_field import FieldList
from gql_http3.quic import Quic, QuicContext, ReadState
from gql_http3.varint import decode_varint, encode_varint


@fieldwise_init
struct StreamRole(Equatable, ImplicitlyCopyable, Writable):
    """What a QUIC stream carries, as a type and not a bare integer."""

    var value: UInt8
    """The role's index; see `is_valid`."""

    comptime REQUEST = StreamRole(0)
    """A request stream."""
    comptime UNTYPED = StreamRole(1)
    """A unidirectional stream whose type has not arrived."""
    comptime CONTROL = StreamRole(2)
    """The control stream of the peer."""
    comptime ENCODER = StreamRole(3)
    """The QPACK encoder stream of the peer."""
    comptime DECODER = StreamRole(4)
    """The QPACK decoder stream of the peer."""
    comptime IGNORED = StreamRole(5)
    """A stream of an unknown type, read and dropped."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the roles.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 5

    def write_to(self, mut writer: Some[Writer]):
        """Write the name of the role.

        Args:
            writer: The destination.
        """
        comptime names: Array[StaticString, 6] = [
            "request",
            "untyped",
            "control",
            "encoder",
            "decoder",
            "ignored",
        ]
        writer.write(materialize[names]()[Int(min(self.value, 5))])


@fieldwise_init
struct H3Config(Copyable, Movable):
    """How an HTTP/3 server listens and what it allows."""

    var host: IPv4Address
    """The local address."""
    var port: Int
    """The UDP port; 0 lets the system choose one."""
    var limits: Limits
    """The size limits of a request, as for HTTP/1.1."""

    def __init__(out self):
        """Make the default configuration: UDP port 4433 on every address."""
        self.host = IPv4Address.ANY
        self.port = 4433
        self.limits = Limits()


def control_preface(limits: Limits) -> List[UInt8]:
    """Return the start of a control stream: its type and SETTINGS.

    Args:
        limits: The size limits; `max_head_bytes` becomes
            `SETTINGS_MAX_FIELD_SECTION_SIZE`.

    Returns:
        The bytes.
    """
    var payload = List[UInt8]()
    encode_varint(SettingId.MAX_FIELD_SECTION_SIZE.value, payload)
    encode_varint(UInt64(limits.max_head_bytes), payload)
    var out = List[UInt8]()
    encode_varint(StreamType.CONTROL.value, out)
    write_frame_header(out, FrameType.SETTINGS, len(payload))
    out.extend(Span(payload))
    return out^


struct ControlReader(Movable):
    """The control stream of the peer: SETTINGS first, then GOAWAY and
    push frames (RFC 9114 section 6.2.1 and 7.2)."""

    var settings: Settings
    """The SETTINGS of the peer."""
    var has_settings: Bool
    """Whether SETTINGS arrived."""
    var goaway: Bool
    """Whether the peer sent GOAWAY."""
    var _buffer: List[UInt8]

    def __init__(out self):
        """Make a reader before the first frame."""
        self.settings = Settings()
        self.has_settings = False
        self.goaway = False
        self._buffer = List[UInt8]()

    def feed(mut self, data: Span[UInt8, _]) raises H3Error:
        """Take bytes of the control stream, and read every complete frame.

        Args:
            data: The bytes, after the stream type.

        Raises:
            H3Error: `H3_MISSING_SETTINGS` when the first frame is not
                SETTINGS; `H3_FRAME_UNEXPECTED` for a second SETTINGS, or
                for DATA, HEADERS, PUSH_PROMISE or an HTTP/2 frame; the
                errors of `Settings.decode`.
        """
        self._buffer.extend(data)
        var start = 0
        while True:
            var head = parse_frame_head(self._buffer, start)
            if not head.complete() or head.payload_end() > len(self._buffer):
                break
            var type = head.type
            if not self.has_settings and type != FrameType.SETTINGS:
                raise H3Error(
                    H3ErrorCode.H3_MISSING_SETTINGS,
                    "the control stream must start with SETTINGS",
                )
            var payload = Span(self._buffer)[
                head.payload_start : head.payload_end()
            ]
            if type == FrameType.SETTINGS:
                if self.has_settings:
                    raise H3Error(
                        H3ErrorCode.H3_FRAME_UNEXPECTED, "a second SETTINGS"
                    )
                self.settings = Settings.decode(payload)
                self.has_settings = True
            elif type == FrameType.GOAWAY:
                self.goaway = True
            elif (
                type == FrameType.DATA
                or type == FrameType.HEADERS
                or type == FrameType.PUSH_PROMISE
                or type.is_http2_only()
            ):
                raise H3Error(
                    H3ErrorCode.H3_FRAME_UNEXPECTED,
                    "a " + String(type) + " frame on the control stream",
                )
            start = head.payload_end()
        var rest = List[UInt8](Span(self._buffer)[start:])
        self._buffer = rest^


struct _H3Stream(Movable):
    """One QUIC stream of a connection."""

    var ssl: Int
    var id: UInt64
    var role: StreamRole
    var reader: MessageReader
    var control: ControlReader
    var raw: List[UInt8]
    var out: List[UInt8]
    var sent: Int
    var answered: Bool
    var ended: Bool

    def __init__(out self, ssl: Int, id: UInt64, max_body: Int):
        self.ssl = ssl
        self.id = id
        self.role = StreamRole.REQUEST if id & 2 == 0 else StreamRole.UNTYPED
        self.reader = MessageReader(max_body)
        self.control = ControlReader()
        self.raw = List[UInt8]()
        self.out = List[UInt8]()
        self.sent = 0
        self.answered = False
        self.ended = False


struct _H3Connection(Movable):
    """One QUIC connection and its HTTP/3 state."""

    var ssl: Int
    var decoder: QpackDecoder
    var encoder: QpackEncoder
    var control: Int
    var control_out: List[UInt8]
    var streams: List[_H3Stream]
    var has_control: Bool
    var has_encoder: Bool
    var has_decoder: Bool

    def __init__(out self, ssl: Int, max_field_section: Int):
        self.ssl = ssl
        self.decoder = QpackDecoder(0, 0, max_field_section)
        self.encoder = QpackEncoder()
        self.control = 0
        self.control_out = List[UInt8]()
        self.streams = List[_H3Stream]()
        self.has_control = False
        self.has_encoder = False
        self.has_decoder = False


struct H3Server[H: Handler](Movable):
    """One HTTP/3 event loop on a UDP socket.

    Parameters:
        H: The type of the handler.
    """

    var handler: Self.H
    """The handler of every request."""
    var quic: Quic
    """The QUIC functions, and the fault plan of the calls."""
    var context: QuicContext
    """The server context: certificate, key and ALPN `h3`."""
    var config: H3Config
    """The configuration."""
    var sys: Sys
    """The system calls of the loop."""
    var writer: ResponseWriter
    """The response writer; one for every request in turn."""
    var port: Int
    """The local UDP port."""
    var fd: Int
    """The UDP socket."""
    var listener: Int
    """The QUIC listener."""
    var _conns: List[_H3Connection]
    var _reader: RequestReader
    var _buffer: List[UInt8]
    var _request: List[UInt8]
    var _fields: FieldList
    var _body: List[UInt8]
    var _block: List[UInt8]
    var _encoder_out: List[UInt8]
    var _preface: List[UInt8]
    var _second: Int
    var _busy: Bool

    def __init__(
        out self,
        var handler: Self.H,
        var context: QuicContext,
        config: H3Config,
        var sys: Sys = Sys(),
    ) raises TlsError:
        """Open a UDP socket and a QUIC listener on it.

        Args:
            handler: The handler of every request.
            context: A server context from `QuicContext.server`.
            config: The configuration.
            sys: The system calls; tests give one with faults.

        Raises:
            TlsError: `OS` when the socket cannot be opened or bound;
                `CONFIG` when OpenSSL cannot make the listener.
        """
        self.handler = handler^
        self.quic = context.quic.copy()
        self.context = context^
        self.config = config.copy()
        self.sys = sys^
        self.writer = ResponseWriter()
        self.port = 0
        self.fd = -1
        self.listener = 0
        self._conns = List[_H3Connection]()
        self._reader = RequestReader(config.limits)
        self._buffer = List[UInt8](length=65536, fill=0)
        self._request = List[UInt8]()
        self._fields = FieldList()
        self._body = List[UInt8]()
        self._block = List[UInt8]()
        self._encoder_out = List[UInt8]()
        self._preface = control_preface(config.limits)
        self._second = -1
        self._busy = False
        self.fd = self.quic.udp_socket()
        if self.fd < 0:
            raise TlsError(TlsErrorKind.OS, "cannot open a UDP socket", 0)
        var rc = self.sys.bind(self.fd, config.host, config.port)
        if rc < 0:
            self.close()
            raise TlsError.os("bind", -rc)
        self.port = self.sys.local_port(self.fd)
        self.listener = self.quic.listener(self.context.ctx, self.fd)
        if self.listener == 0:
            self.close()
            raise TlsError(
                TlsErrorKind.CONFIG, "cannot make a QUIC listener", 0
            )

    def __deinit__(deinit self):
        """Close every connection, the listener and the socket."""
        self.close()

    def close(mut self):
        """Close every connection at once, the listener and the socket."""
        while len(self._conns) > 0:
            var conn = self._conns.pop()
            self._free(conn, H3ErrorCode.H3_NO_ERROR.value)
        if self.listener != 0:
            self.quic.free(self.listener)
            self.listener = 0
        if self.fd >= 0:
            self.sys.close(self.fd)
            self.fd = -1

    def connections(self) -> Int:
        """Return the count of open connections.

        Returns:
            The count.
        """
        return len(self._conns)

    def _free(mut self, mut conn: _H3Connection, code: UInt64):
        """Free the streams of a connection, close it and free it."""
        while len(conn.streams) > 0:
            var stream = conn.streams.pop()
            self.quic.free(stream.ssl)
        self.quic.free(conn.control)
        self.quic.close_connection(conn.ssl, code)
        # Send the CONNECTION_CLOSE now: I/O happens only in handle_events.
        self.quic.handle_events(conn.ssl)
        self.quic.free(conn.ssl)

    def run(mut self) raises TlsError:
        """Run the loop until `close`; for a dedicated process.

        Raises:
            TlsError: `OS` when `poll` fails.
        """
        while self.fd >= 0:
            _ = self.poll(-1)

    def poll(mut self, timeout_ms: Int) raises TlsError -> Int:
        """Run one turn: wait for a datagram or a timer, then serve.

        Args:
            timeout_ms: The longest wait in milliseconds; -1 waits until a
                datagram or a QUIC timer.

        Returns:
            1 when a datagram arrived, else 0.

        Raises:
            TlsError: `OS` when `poll` fails.
        """
        var wait = timeout_ms
        var timer = self.quic.event_timeout_ms(self.listener)
        if timer >= 0 and (wait < 0 or timer < wait):
            wait = timer
        var ready = self.sys.poll(self.fd, POLLIN, wait)
        if ready < 0 and ready != -4:
            raise TlsError.os("poll", -ready)
        var second = self.sys.wall_seconds()
        if second != self._second:
            self._second = second
            self.writer.set_date(second)
        # Network I/O happens only in handle_events. Serve until a turn
        # finds no work: the socket then holds every datagram that is not
        # read yet, and the next wait sees it.
        self._busy = True
        var check = True
        while self._busy:
            self._busy = False
            self.quic.handle_events(self.listener)
            self._accept()
            var index = 0
            while index < len(self._conns):
                if self._serve(index, check):
                    index += 1
            check = False
        return 1 if ready > 0 else 0

    def _accept(mut self):
        """Accept every new connection, and open its control stream."""
        while True:
            var ssl = self.quic.accept_connection(self.listener)
            if ssl == 0:
                return
            var conn = _H3Connection(ssl, self.config.limits.max_head_bytes)
            conn.control_out.extend(Span(self._preface))
            self._conns.append(conn^)
            self._busy = True

    def _serve(mut self, index: Int, check: Bool) -> Bool:
        """Serve one connection; False after it closed and left the list."""
        if check and self.quic.connection_closed(self._conns[index].ssl):
            var conn = self._conns.pop(index)
            self._free(conn, H3ErrorCode.H3_NO_ERROR.value)
            return False
        if self._conns[index].control == 0:
            if not self.quic.handshake_done(self._conns[index].ssl):
                return True
            # The control stream opens once the handshake has ended.
            self._conns[index].control = self.quic.new_stream(
                self._conns[index].ssl, True
            )
            if self._conns[index].control == 0:
                var conn = self._conns.pop(index)
                self._free(conn, H3ErrorCode.H3_INTERNAL_ERROR.value)
                return False
            self._busy = True
        try:
            self._take_streams(index)
            var at = 0
            while at < len(self._conns[index].streams):
                if self._serve_stream(index, at):
                    at += 1
            self._flush_control(index)
        except e:
            var conn = self._conns.pop(index)
            self._free(conn, e.code.value)
            return False
        return True

    def _take_streams(mut self, index: Int):
        """Accept every new stream of a connection."""
        while True:
            var ssl = self.quic.accept_stream(self._conns[index].ssl)
            if ssl == 0:
                return
            var id = self.quic.stream_id(ssl)
            self._busy = True
            self._conns[index].streams.append(
                _H3Stream(ssl, id, self.config.limits.max_body_bytes)
            )

    def _flush_control(mut self, index: Int) raises H3Error:
        """Write what the control stream can take, and keep the rest."""
        ref conn = self._conns[index]
        if len(conn.control_out) == 0:
            return
        var n = self.quic.write(
            conn.control,
            conn.control_out.unsafe_ptr(),
            len(conn.control_out),
            False,
        )
        if n < 0:
            raise H3Error(
                H3ErrorCode.H3_CLOSED_CRITICAL_STREAM,
                "the control stream failed",
            )
        var rest = List[UInt8](Span(conn.control_out)[n:])
        conn.control_out = rest^

    def _serve_stream(mut self, index: Int, at: Int) raises H3Error -> Bool:
        """Read and answer one stream; False after it left the list."""
        while not self._conns[index].streams[at].ended:
            var result = self.quic.read(
                self._conns[index].streams[at].ssl,
                self._buffer.unsafe_ptr(),
                len(self._buffer),
            )
            if result.state == ReadState.WAIT:
                break
            if result.state == ReadState.DATA:
                var data = List[UInt8](Span(self._buffer)[0 : result.count])
                self._take(index, at, data)
                self._busy = True
                continue
            self._conns[index].streams[at].ended = True
            var role = self._conns[index].streams[at].role
            if role == StreamRole.CONTROL:
                raise H3Error(
                    H3ErrorCode.H3_CLOSED_CRITICAL_STREAM,
                    "the control stream ended",
                )
            if role == StreamRole.REQUEST and result.state == ReadState.END:
                self._answer(index, at)
        ref current = self._conns[index].streams[at]
        if current.sent < len(current.out):
            var n = self.quic.write(
                current.ssl,
                current.out.unsafe_ptr().unsafe_offset(current.sent),
                len(current.out) - current.sent,
                True,
            )
            if n < 0:
                n = len(current.out) - current.sent
            current.sent += n
        var done = current.ended and (
            not current.answered or current.sent >= len(current.out)
        )
        if not done:
            return True
        var gone = self._conns[index].streams.pop(at)
        self.quic.free(gone.ssl)
        return False

    def _take(
        mut self, index: Int, at: Int, data: Span[UInt8, _]
    ) raises H3Error:
        """Give bytes of a stream to the reader of its role."""
        ref conn = self._conns[index]
        ref stream = conn.streams[at]
        if stream.role == StreamRole.UNTYPED:
            stream.raw.extend(data)
            var type = decode_varint(stream.raw, 0)
            if not type.complete():
                return
            var kind = StreamType(type.value)
            if kind == StreamType.CONTROL:
                if conn.has_control:
                    raise H3Error(
                        H3ErrorCode.H3_STREAM_CREATION_ERROR,
                        "a second control stream",
                    )
                conn.has_control = True
                stream.role = StreamRole.CONTROL
            elif kind == StreamType.QPACK_ENCODER:
                if conn.has_encoder:
                    raise H3Error(
                        H3ErrorCode.H3_STREAM_CREATION_ERROR,
                        "a second QPACK encoder stream",
                    )
                conn.has_encoder = True
                stream.role = StreamRole.ENCODER
            elif kind == StreamType.QPACK_DECODER:
                if conn.has_decoder:
                    raise H3Error(
                        H3ErrorCode.H3_STREAM_CREATION_ERROR,
                        "a second QPACK decoder stream",
                    )
                conn.has_decoder = True
                stream.role = StreamRole.DECODER
            elif kind == StreamType.PUSH:
                raise H3Error(
                    H3ErrorCode.H3_STREAM_CREATION_ERROR,
                    "a client cannot open a push stream",
                )
            else:
                stream.role = StreamRole.IGNORED
            var rest = List[UInt8](Span(stream.raw)[type.end :])
            stream.raw.clear()
            self._take(index, at, rest)
        elif stream.role == StreamRole.REQUEST:
            try:
                stream.reader.feed(data, stream.id, conn.decoder)
            except e:
                if e.code == H3ErrorCode.H3_FRAME_UNEXPECTED:
                    raise e^
                self.quic.reset_stream(stream.ssl, e.code.value)
                stream.ended = True
        elif stream.role == StreamRole.CONTROL:
            stream.control.feed(data)
        elif stream.role == StreamRole.ENCODER:
            conn.decoder.on_encoder_stream(data)
        elif stream.role == StreamRole.DECODER:
            conn.encoder.on_decoder_stream(data)

    def _answer(mut self, index: Int, at: Int) raises H3Error:
        """Run the handler for a complete request, and frame its response."""
        ref stream = self._conns[index].streams[at]
        self._request.clear()
        try:
            stream.reader.finish()
            to_http1_request(
                stream.reader.fields, stream.reader.body, self._request
            )
        except e:
            self.quic.reset_stream(stream.ssl, e.code.value)
            return
        var id = stream.id
        self._reader.reset()
        self._reader.reserve(len(self._request))
        var target = self._reader.write_pointer()
        var i = 0
        while i < len(self._request):
            target[unsafe_offset=i] = self._request[i]
            i += 1
        self._reader.commit(len(self._request))
        var parsed = self._reader.next()
        var method = Method.GET
        if parsed.state == ParseState.COMPLETE:
            method = self._reader.request.method
            self.writer.begin(self._reader.request, -1, True)
            try:
                self.handler.handle(self._reader.request, self.writer)
            except:
                self.writer.fail()
            self.writer.finish()
        else:
            self.writer.error(parsed.status)
        from_http1_response(
            self.writer.out,
            method,
            self.config.limits,
            self._fields,
            self._body,
        )
        self.writer.out.clear()
        self._block.clear()
        self._encoder_out.clear()
        _ = self._conns[index].encoder.encode(
            id, self._fields, self._block, self._encoder_out
        )
        ref answered = self._conns[index].streams[at]
        write_message(self._block, self._body, answered.out)
        answered.answered = True


def listen_h3[
    H: Handler
](
    var handler: H,
    cert_file: String,
    key_file: String,
    config: H3Config,
    var quic: Quic,
) raises TlsError -> H3Server[H]:
    """Open an HTTP/3 server on a UDP port.

    Args:
        handler: The handler of every request.
        cert_file: A PEM file with the certificate chain, leaf first.
        key_file: A PEM file with the private key.
        config: The configuration.
        quic: The QUIC functions, from `Quic(OpenSsl())`.

    Returns:
        The server. Its `port` is the UDP port it listens on.

    Raises:
        TlsError: `CONFIG` when a file does not load; `OS` when the socket
            cannot be opened or bound.

    Parameters:
        H: The type of the handler.
    """
    var context = QuicContext.server(quic^, cert_file, key_file)
    return H3Server(handler^, context^, config)

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The server end of one HTTP/2 connection, and the `Transport` that it
runs over.

A `ServerSession` joins a `Connection` to a gql_http `Handler`. Each whole
request becomes a gql_http `Request`, so the handler of an HTTP/1.1 server
serves HTTP/2 unchanged. The `ResponseWriter` that the handler fills
becomes the `HEADERS` and `DATA` frames of the response.

A `Transport` is a byte stream: a plain socket, or a TLS connection after
ALPN chose `h2`. `serve_transport` serves one connection over any
transport until it ends. An event loop can drive a `ServerSession` with
`receive` and `out` instead.

This module ports the request and response parts of h2 v0.4.20
`src/server.rs` (`Connection`, `SendResponse`, the preface handshake) and
the h2c upgrade of RFC 7540 section 3.2.

Differences from upstream:

- **A gql_http handler.** h2 gives the application an `http::Request` and
  a `SendResponse`. Here the request is a gql_http `Request` in HTTP/1.1
  form: `:authority` becomes `host`, the `cookie` fields become one field
  (RFC 9113 section 8.2.3), and `content-length` is the length of the
  content.
- **Streams end at once.** A response that the handler streams with
  `begin_chunked` and `write_chunk` goes out when the handler returns.
- **`close_connection`** begins a graceful shutdown of the connection.
"""

from std.memory import unsafe_memcpy

from gql_http.headers import Headers
from gql_http.parser import Limits, ParseState, Request, RequestReader
from gql_http.scan import lower, move_down
from gql_http.server import Handler, ResponseWriter, format_http_date
from gql_http.socket import EAGAIN, EINTR, POLLIN, POLLOUT, Sys
from gql_http.status import Method, Status

from gql_http2.connection import Config, Connection, EventKind, Role
from gql_http2.error import H2Error, Reason
from gql_http2.frame import read_u32
from gql_http2.hpack import HeaderList


trait Transport(Deinitable, Movable):
    """A byte stream that an HTTP/2 connection runs over.

    The plain socket of `SocketTransport` implements it, and so can a TLS
    connection. Each method returns at once: a transport does not block.
    """

    def read(
        mut self, data: Pointer[UInt8, MutUntrackedOrigin], size: Int
    ) -> Int:
        """Read bytes that have arrived.

        Args:
            data: Where to put them.
            size: The most bytes to read.

        Returns:
            The count of bytes read; 0 when the peer closed the stream;
            `-EAGAIN` when no byte is there now; another negative error
            number when the transport failed.
        """
        ...

    def write(
        mut self, data: Pointer[UInt8, ImmUntrackedOrigin], size: Int
    ) -> Int:
        """Write bytes, as many as the transport takes now.

        Args:
            data: The bytes.
            size: How many.

        Returns:
            The count of bytes written, which can be fewer than `size`;
            `-EAGAIN` when the transport takes none now; another negative
            error number when the transport failed.
        """
        ...

    def close(mut self):
        """Close the transport and its descriptor."""
        ...

    def fd(self) -> Int:
        """Return the descriptor to wait on with `poll`.

        Returns:
            The descriptor, or -1 when the transport has none.
        """
        ...


struct SocketTransport(Transport):
    """A plain, non-blocking socket as a `Transport`: the transport of h2c."""

    var socket: Int
    """The connected socket; -1 once closed."""
    var sys: Sys
    """The system calls; tests give one with faults."""

    def __init__(out self, socket: Int, var sys: Sys = Sys()):
        """Wrap a connected socket.

        Args:
            socket: The socket; the transport closes it.
            sys: The system calls.
        """
        self.socket = socket
        self.sys = sys^

    def read(
        mut self, data: Pointer[UInt8, MutUntrackedOrigin], size: Int
    ) -> Int:
        """Read with `recv`.

        Args:
            data: Where to put the bytes.
            size: The most bytes to read.

        Returns:
            What `recv` returns: a count, 0 at the end, or `-errno`.
        """
        return self.sys.recv(self.socket, data, size)

    def write(
        mut self, data: Pointer[UInt8, ImmUntrackedOrigin], size: Int
    ) -> Int:
        """Write with `send`.

        Args:
            data: The bytes.
            size: How many.

        Returns:
            What `send` returns: a count or `-errno`.
        """
        return self.sys.send(self.socket, data, size)

    def close(mut self):
        """Close the socket once."""
        if self.socket >= 0:
            self.sys.close(self.socket)
            self.socket = -1

    def fd(self) -> Int:
        """Return the socket.

        Returns:
            The descriptor, or -1 once closed.
        """
        return self.socket


def decode_base64url(text: StringSlice) -> Optional[List[UInt8]]:
    """Decode the `token68` of `HTTP2-Settings`: base64url without padding
    (RFC 4648 section 5). A trailing `=` is allowed.

    Args:
        text: The text.

    Returns:
        The bytes, or None for a byte outside the alphabet or a length that
        cannot be base64.
    """
    var bytes = text.as_bytes()
    var end = len(bytes)
    while end > 0 and bytes[end - 1] == 61:
        end -= 1
    if end % 4 == 1:
        return None
    var out = List[UInt8](capacity=end * 3 // 4)
    var bits = 0
    var count = 0
    var index = 0
    while index < end:
        var byte = Int(bytes[index])
        var value = -1
        if byte >= 65 and byte <= 90:
            value = byte - 65
        elif byte >= 97 and byte <= 122:
            value = byte - 71
        elif byte >= 48 and byte <= 57:
            value = byte + 4
        elif byte == 45:
            value = 62
        elif byte == 95:
            value = 63
        if value < 0:
            return None
        bits = ((bits << 6) | value) & 0xFFFF
        count += 6
        if count >= 8:
            count -= 8
            out.append(UInt8((bits >> count) & 0xFF))
        index += 1
    return out^


comptime _SWITCHING = (
    "HTTP/1.1 101 Switching Protocols\r\nConnection: Upgrade\r\n"
    "Upgrade: h2c\r\n\r\n"
)
"""The response that accepts an h2c upgrade."""


def _has_token(value: StringSlice, token: StaticString) -> Bool:
    """Return True when a comma-separated list holds a token, in any case."""
    var bytes = value.as_bytes()
    var word = token.as_bytes()
    var start = 0
    while start <= len(bytes):
        var end = start
        while end < len(bytes) and bytes[end] != 44:
            end += 1
        var a = start
        var b = end
        while a < b and (bytes[a] == 32 or bytes[a] == 9):
            a += 1
        while b > a and (bytes[b - 1] == 32 or bytes[b - 1] == 9):
            b -= 1
        if b - a == len(word):
            var same = True
            var index = 0
            while index < len(word):
                if lower(bytes[a + index]) != word[index]:
                    same = False
                    break
                index += 1
            if same:
                return True
        start = end + 1
    return False


def is_h2c_upgrade(request: Request) -> Bool:
    """Return True for a request that asks for the h2c upgrade (RFC 7540
    section 3.2): `Upgrade: h2c`, one `HTTP2-Settings` field, and both
    names in `Connection`.

    Args:
        request: The HTTP/1.1 request.

    Returns:
        Whether the server can switch the connection to HTTP/2.
    """
    var upgrade = request.header("upgrade")
    var connection = request.header("connection")
    var first = request.find_header("http2-settings")
    if not upgrade or not connection or first < 0:
        return False
    if request.find_header("http2-settings", first + 1) >= 0:
        return False
    return (
        _has_token(upgrade.value(), "h2c")
        and _has_token(connection.value(), "upgrade")
        and _has_token(connection.value(), "http2-settings")
    )


@always_inline
def _view(data: List[UInt8]) -> Span[UInt8, ImmUntrackedOrigin]:
    """Return the bytes of a list without its origin, so that a method of
    the list's owner can read them."""
    return Span[UInt8, ImmUntrackedOrigin](
        unsafe_ptr=Pointer[UInt8, ImmUntrackedOrigin](
            unsafe_from_address=Int(data.unsafe_ptr())
        ),
        length=len(data),
    )


def _is_connection_field(name: Span[UInt8, _]) -> Bool:
    """Return True for a field that HTTP/2 does not allow in a response."""
    var text = StringSlice(unsafe_from_utf8=name)
    return (
        text == "connection"
        or text == "keep-alive"
        or text == "proxy-connection"
        or text == "transfer-encoding"
        or text == "upgrade"
    )


struct ServerSession(Movable):
    """The server end of one HTTP/2 connection, without I/O."""

    var conn: Connection
    """The connection; the driver sends `conn.out`."""
    var reader: RequestReader
    """The reader that turns each request into a gql_http `Request`."""
    var writer: ResponseWriter
    """The writer that the handler fills."""
    var sys: Sys
    """The clock of the `date` field."""
    var _request: List[UInt8]
    var _fields: HeaderList
    var _name: List[UInt8]
    var _body: List[UInt8]
    var _date: String
    var _second: Int

    def __init__(
        out self, config: Config = Config(), limits: Limits = Limits()
    ):
        """Make a session that has sent nothing yet; call `start`.

        Args:
            config: The limits of the connection.
            limits: The limits of each request, as gql_http checks them.
                `require_host` is off: `:authority` is optional in HTTP/2.
        """
        self.conn = Connection(Role.SERVER, config)
        var request_limits = limits
        request_limits.require_host = False
        self.reader = RequestReader(request_limits)
        self.writer = ResponseWriter()
        self.sys = Sys()
        self._request = List[UInt8]()
        self._fields = HeaderList()
        self._name = List[UInt8]()
        self._body = List[UInt8]()
        self._date = String()
        self._second = -1

    def start(mut self):
        """Append the server's `SETTINGS` to `conn.out`."""
        self.conn.start()

    def is_done(self) -> Bool:
        """Return True when the connection can close once `conn.out` is sent.

        Returns:
            Whether the connection has ended.
        """
        return self.conn.is_done()

    def receive[H: Handler](mut self, mut handler: H, data: Span[UInt8, _]):
        """Read bytes from the client, and answer each whole request.

        Args:
            handler: The handler of every request.
            data: The bytes, in order.

        Parameters:
            H: The type of the handler.
        """
        self.conn.receive(data)
        self.dispatch(handler)

    def dispatch[H: Handler](mut self, mut handler: H):
        """Answer the requests of the `MESSAGE` events, and clear the events.

        Args:
            handler: The handler of every request.

        Parameters:
            H: The type of the handler.
        """
        var index = 0
        while index < len(self.conn.events):
            if self.conn.events[index].kind == EventKind.MESSAGE:
                self._serve(handler, self.conn.events[index].stream_id)
            index += 1
        self.conn.events.clear()

    def upgrade[
        H: Handler
    ](mut self, mut handler: H, data: Span[UInt8, _]) -> Int:
        """Take the connection over from HTTP/1.1 with the h2c upgrade.

        `data` starts with a whole request for which `is_h2c_upgrade` is
        True. The session sends 101, its `SETTINGS`, and the response on
        stream 1. The bytes after the request are read as HTTP/2.

        Args:
            handler: The handler of every request.
            data: The bytes read from the connection.

        Parameters:
            H: The type of the handler.

        Returns:
            The size of the request, or -1 when the request is not whole or
            its `HTTP2-Settings` is invalid; then nothing is sent.
        """
        self._load(data)
        var result = self.reader.next()
        if result.state != ParseState.COMPLETE:
            return -1
        var value = self.reader.request.header("http2-settings")
        if not value:
            return -1
        var settings = decode_base64url(value.value())
        if not settings:
            return -1
        var head = self.reader.request.method == Method.HEAD
        try:
            _ = self.conn.upgrade(settings.value(), head)
        except:
            return -1
        self.conn.out.extend(StaticString(_SWITCHING).as_bytes())
        self.conn.start()
        self._handle(handler, 1)
        var size = result.size
        self.receive(handler, data[size:])
        return size

    def _load(mut self, data: Span[UInt8, _]):
        """Put bytes into the reader, in place of what it held."""
        self.reader.reset()
        var count = len(data)
        self.reader.reserve(count)
        unsafe_memcpy(
            dest=self.reader.write_pointer(),
            src=data.unsafe_ptr(),
            count=count,
        )
        self.reader.commit(count)

    def _serve[H: Handler](mut self, mut handler: H, id: Int):
        """Answer the whole request of a stream."""
        var slot = self.conn.find(id)
        if slot < 0:
            return
        self._build(slot)
        self._load(_view(self._request))
        var result = self.reader.next()
        if result.state != ParseState.COMPLETE:
            # The checks of the head keep the request whole, so only a
            # limit of gql_http, such as the content size, refuses it.
            self.writer.status = result.status
            self.writer.headers.clear()
            self._respond(id, Span[UInt8, ImmUntrackedOrigin](), False)
            self.conn.release(id)
            return
        self._handle(handler, id)

    def _handle[H: Handler](mut self, mut handler: H, id: Int):
        """Run the handler on the request in the reader, and send its
        response on a stream."""
        var slot = self.conn.find(id)
        var head_only = self.conn.streams[slot].head_request
        self._tick()
        self.writer.begin(self.reader.request, -1, True)
        var failed = False
        try:
            handler.handle(self.reader.request, self.writer)
        except:
            failed = True
            self.writer.fail()
        if not self.writer.committed():
            self._respond(id, _view(self.writer.body), head_only)
        elif failed:
            # A stream that has begun cannot become a 500.
            self.writer.out.clear()
            self.conn.reset_stream(id, Reason.INTERNAL_ERROR)
        else:
            self.writer.finish()
            self._unchunk()
            self.writer.out.clear()
            # The writer drops the chunks of HEAD: the length is unknown.
            self._respond(id, _view(self._body), head_only, not head_only)
        if not self.writer.keep_alive and not failed:
            self.conn.begin_shutdown()
        self.conn.release(id)
        self.reader.consume()

    def _unchunk(mut self):
        """Put the content of the chunked stream in `writer.out` into
        `_body`. The writer wrote the stream, so it is well formed."""
        self._body.clear()
        var out = Span(self.writer.out)
        # The head ends with the first CR LF CR LF.
        var at = 0
        while read_u32(out.unsafe_ptr(), at) != 0x0D0A0D0A:
            at += 1
        at += 4
        # The stream ends with the chunk of size 0; HEAD has no chunks.
        while at < len(out):
            var size = 0
            while out[at] != 13:
                var byte = Int(out[at])
                size = size * 16 + (
                    byte - 48 if byte <= 57 else (byte | 32) - 87
                )
                at += 1
            at += 2
            if size == 0:
                return
            self._body.extend(out[at : at + size])
            at += size + 2

    def _tick(mut self):
        """Update the `date` value once a second."""
        var second = self.sys.wall_seconds()
        if second != self._second:
            self._second = second
            self._date = format_http_date(second)

    def _build(mut self, slot: Int):
        """Write the request of a stream in HTTP/1.1 form into `_request`."""
        ref fields = self.conn.streams[slot].headers
        var method = -1
        var path = -1
        var authority = -1
        var index = 0
        while index < fields.count():
            var name = StringSlice(unsafe_from_utf8=fields.name(index))
            if name == ":method":
                method = index
            elif name == ":path":
                path = index
            elif name == ":authority":
                authority = index
            index += 1
        self._request.clear()
        self._request.extend(fields.value(method))
        self._request.append(32)
        if path >= 0:
            self._request.extend(fields.value(path))
        else:
            # CONNECT: the target is the authority.
            self._request.extend(fields.value(authority))
        self._request.extend(StaticString(" HTTP/1.1\r\n").as_bytes())
        if authority >= 0:
            self._request.extend(StaticString("host: ").as_bytes())
            self._request.extend(fields.value(authority))
            self._request.extend(StaticString("\r\n").as_bytes())
        var cookies = 0
        index = 0
        while index < fields.count():
            var name = fields.name(index)
            var text = StringSlice(unsafe_from_utf8=name)
            if name[0] == 58:
                pass
            elif text == "cookie":
                cookies += 1
            elif not (
                text == "content-length" or (text == "host" and authority >= 0)
            ):
                self._request.extend(name)
                self._request.extend(StaticString(": ").as_bytes())
                self._request.extend(fields.value(index))
                self._request.extend(StaticString("\r\n").as_bytes())
            index += 1
        if cookies > 0:
            self._request.extend(StaticString("cookie: ").as_bytes())
            var first = True
            index = 0
            while index < fields.count():
                if StringSlice(unsafe_from_utf8=fields.name(index)) == "cookie":
                    if not first:
                        self._request.extend(StaticString("; ").as_bytes())
                    first = False
                    self._request.extend(fields.value(index))
                index += 1
            self._request.extend(StaticString("\r\n").as_bytes())
        ref body = self.conn.streams[slot].body
        if len(body) > 0 or self.conn.streams[slot].content_length >= 0:
            self._request.extend(StaticString("content-length: ").as_bytes())
            self._request.extend(String(len(body)).as_bytes())
            self._request.extend(StaticString("\r\n").as_bytes())
        self._request.extend(StaticString("\r\n").as_bytes())
        self._request.extend(Span(body))

    def _respond(
        mut self,
        id: Int,
        body: Span[UInt8, ImmUntrackedOrigin],
        head_only: Bool,
        length_known: Bool = True,
    ):
        """Send the status and the fields of the writer, and a content, on a
        stream."""
        var status = self.writer.status
        self._fields.clear()
        self._fields.add_text(":status", String(status.code))
        self._fields.add_text("date", self._date)
        var index = 0
        while index < len(self.writer.headers):
            var name = self.writer.headers.name(index).as_bytes()
            self._name.clear()
            var at = 0
            while at < len(name):
                self._name.append(lower(name[at]))
                at += 1
            if not _is_connection_field(Span(self._name)):
                self._fields.add(
                    Span(self._name),
                    self.writer.headers.value(index).as_bytes(),
                )
            index += 1
        var has_body = status.has_body()
        if has_body and length_known:
            self._fields.add_text("content-length", String(len(body)))
        var empty = not has_body or len(body) == 0 or head_only
        try:
            self.conn.send_headers(id, self._fields, empty)
            if not empty:
                self.conn.send_data(id, body, True)
        except:
            # The stream is not open any more: nothing to send.
            pass


def serve_transport[
    H: Handler, T: Transport
](
    mut handler: H,
    mut transport: T,
    config: Config = Config(),
    limits: Limits = Limits(),
    idle_timeout_ms: Int = 5000,
    read_already: List[UInt8] = List[UInt8](),
) raises H2Error:
    """Serve one HTTP/2 connection over a transport until it ends.

    A TLS layer calls it after ALPN chose `h2`; the plain server uses its
    own event loop. The call waits on `transport.fd()` with `poll`, so it
    serves one connection at a time. It closes the transport at the end.

    Args:
        handler: The handler of every request.
        transport: The transport; it starts with the client preface.
        config: The limits of the connection.
        limits: The limits of each request.
        idle_timeout_ms: How long the connection can be quiet, also in the
            middle of a request; then it ends with `GOAWAY`.
        read_already: Bytes that were read from the transport already.

    Raises:
        H2Error: `IO` when the transport fails.

    Parameters:
        H: The type of the handler.
        T: The type of the transport.
    """
    var session = ServerSession(config, limits)
    session.start()
    if len(read_already) > 0:
        session.receive(handler, read_already)
    var buffer = List[UInt8](length=65536, fill=0)
    var sys = Sys()
    try:
        while True:
            write_all(transport, session.conn.out, idle_timeout_ms)
            if session.is_done():
                break
            var n = transport.read(
                Pointer[UInt8, MutUntrackedOrigin](
                    unsafe_from_address=Int(buffer.unsafe_ptr())
                ),
                len(buffer),
            )
            if n == -EAGAIN or n == -EINTR:
                var ready = sys.poll(transport.fd(), POLLIN, idle_timeout_ms)
                if ready == 0:
                    session.conn.abort(Reason.NO_ERROR)
                continue
            if n == 0:
                break
            if n < 0:
                raise H2Error.io("read failed: errno " + String(-n))
            session.receive(handler, Span(buffer)[:n])
    except e:
        transport.close()
        raise e^
    transport.close()


def write_all[
    T: Transport
](mut transport: T, mut out: List[UInt8], timeout_ms: Int) raises H2Error:
    """Write all of `out` to a transport, wait with `poll` when it is full,
    and clear `out`.

    Args:
        transport: The transport.
        out: The bytes; empty at the end.
        timeout_ms: The longest wait for the transport to take more.

    Raises:
        H2Error: `IO` when the transport fails or takes nothing in time.

    Parameters:
        T: The type of the transport.
    """
    var sys = Sys()
    var sent = 0
    while sent < len(out):
        var n = transport.write(
            Pointer[UInt8, ImmUntrackedOrigin](
                unsafe_from_address=Int(out.unsafe_ptr()) + sent
            ),
            len(out) - sent,
        )
        if n == -EAGAIN or n == -EINTR:
            if sys.poll(transport.fd(), POLLOUT, timeout_ms) <= 0:
                raise H2Error.io("write timed out")
            continue
        if n < 0:
            raise H2Error.io("write failed: errno " + String(-n))
        sent += n
    out.clear()

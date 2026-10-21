# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The client end of a WebSocket on an HTTP/2 stream (RFC 8441), over any
`gql_http2` `Transport`.

`H2WebSocket` conforms to the `MessageSocket` of `gql_ws`, so
`TransportClientOf[H2WebSocket[T]]` speaks `graphql-transport-ws` over
HTTP/2. `handshake` waits for the `SETTINGS` of the server, refuses a
server without `SETTINGS_ENABLE_CONNECT_PROTOCOL = 1`, and sends the
extended `CONNECT`. `connect_h2c` opens h2c with prior knowledge on a
`ws://` URL. A TLS transport, after ALPN chose `h2`, goes to `H2WebSocket`
and `handshake` with the scheme `https`.

- **Closing.** The end of the stream is the end of the TCP connection of
  RFC 6455 (RFC 8441 section 6). After the closing handshake the client
  ends its side with `END_STREAM`. A reset is a close without a
  handshake.
- **Back pressure.** A send waits, until `write_timeout_ms`, while the
  stream has content that waits for a window.

This module ports no code. The read and write loop follows `WsClient` of
`gql_ws` (tungstenite 0.30.0 `src/protocol/mod.rs`), and the stream
follows RFC 8441 sections 4 to 6.

Differences from upstream: none; tungstenite has no HTTP/2 transport.
"""

from std.time import perf_counter_ns

from gql_http.socket import EAGAIN, EINTR, POLLIN, POLLOUT, Sys
from gql_http.url import Url
from gql_http2.connection import Config, Connection, EventKind, Role
from gql_http2.error import H2Error
from gql_http2.session import SocketTransport, Transport
from gql_ws.client import ClientConfig, MessageSocket, open_socket, wait_socket
from gql_ws.error import WsError, WsErrorKind
from gql_ws.frame import CloseCode
from gql_ws.graphql_ws import GRAPHQL_TRANSPORT_WS_PROTOCOL
from gql_ws.protocol import Message, Role as WsRole, WebSocket
from gql_ws.transport_client import TransportClientOf

from gql_ws_http2.handshake import client_head, verify_head


comptime H2TransportClient = TransportClientOf[H2WebSocket[SocketTransport]]
"""The `graphql-transport-ws` client on an h2c WebSocket."""


def _now_ms() -> Int:
    """Return a monotonic time in milliseconds."""
    return Int(perf_counter_ns() // 1_000_000)


def _h2(error: H2Error) -> WsError:
    """Make the error of a failed HTTP/2 call."""
    return WsError.of(WsErrorKind.IO, "HTTP/2 error: " + error.message)


struct H2WebSocket[T: Transport](MessageSocket):
    """A WebSocket on one stream of a client HTTP/2 connection.

    Parameters:
        T: The type of the transport.
    """

    var transport: Self.T
    """The transport; the WebSocket closes it."""
    var conn: Connection
    """The HTTP/2 connection state."""
    var ws: WebSocket
    """The protocol state."""
    var stream_id: Int
    """The stream of the WebSocket; 0 before `handshake`."""
    var protocol: String
    """The subprotocol of the server, or empty."""
    var config: ClientConfig
    """The configuration."""
    var sys: Sys
    """The `poll` of the waits."""
    var _open: Bool
    var _ended: Bool
    var _sent_end: Bool
    var _buffer: List[UInt8]

    def __init__(
        out self,
        var transport: Self.T,
        config: ClientConfig = ClientConfig(),
        h2: Config = Config(),
    ):
        """Wrap a connected transport; call `handshake`.

        Args:
            transport: The transport; the WebSocket closes it.
            config: The configuration of the WebSocket.
            h2: The limits of the HTTP/2 connection.
        """
        self.transport = transport^
        self.conn = Connection(Role.CLIENT, h2)
        self.conn.start()
        self.ws = WebSocket(WsRole.CLIENT, config.ws)
        self.stream_id = 0
        self.protocol = String()
        self.config = config.copy()
        self.sys = Sys()
        self._open = False
        self._ended = False
        self._sent_end = False
        self._buffer = List[UInt8](length=65536, fill=0)

    def __deinit__(deinit self):
        """Close the transport."""
        self.transport.close()

    def handshake(
        mut self,
        scheme: StringSlice,
        authority: StringSlice,
        path: StringSlice,
        protocols: List[String] = [],
    ) raises WsError:
        """Send the extended `CONNECT`, and check the answer, within
        `connect_timeout_ms`.

        Args:
            scheme: `http` for h2c, `https` over TLS.
            authority: The host and the port.
            path: The path and the query.
            protocols: The subprotocols to offer.

        Raises:
            WsError: `HANDSHAKE` when the server does not allow the
                extended `CONNECT`, or refuses the WebSocket, with the
                status of the answer; `TIMEOUT` at the deadline; `IO` when
                the transport or the connection fails.
        """
        var deadline = _now_ms() + self.config.connect_timeout_ms
        while not self.conn.got_settings():
            self._step(deadline, "handshake timed out")
            if self._ended:
                raise WsError.of(
                    WsErrorKind.HANDSHAKE, "Handshake not finished"
                )
        if not self.conn.is_extended_connect_protocol_enabled():
            raise WsError.of(
                WsErrorKind.HANDSHAKE,
                "the server does not allow the extended CONNECT",
            )
        try:
            self.stream_id = self.conn.open_stream()
            self.conn.send_headers(
                self.stream_id,
                client_head(scheme, authority, path, protocols),
                False,
            )
        except e:
            raise _h2(e)
        while True:
            var index = self.conn.find(self.stream_id)
            if index >= 0 and self.conn.streams[index].got_head:
                self.protocol = verify_head(
                    self.conn.streams[index].status,
                    self.conn.streams[index].headers,
                    protocols,
                )
                self._open = True
                self._take()
                return
            if self._ended:
                raise WsError.of(
                    WsErrorKind.HANDSHAKE, "Handshake not finished"
                )
            self._step(deadline, "handshake timed out")

    def _write(mut self, deadline: Int) raises WsError:
        """Send the output of the connection, or raise `TIMEOUT`."""
        var sent = 0
        while sent < len(self.conn.out):
            var n = self.transport.write(
                Pointer[UInt8, ImmUntrackedOrigin](
                    unsafe_from_address=Int(self.conn.out.unsafe_ptr()) + sent
                ),
                len(self.conn.out) - sent,
            )
            if n == -EAGAIN or n == -EINTR:
                if not wait_socket(
                    self.sys, self.transport.fd(), POLLOUT, deadline
                ):
                    raise WsError.of(WsErrorKind.TIMEOUT, "send timed out")
                continue
            if n < 0:
                raise WsError.of(
                    WsErrorKind.IO, "send failed: errno " + String(-n)
                )
            sent += n
        self.conn.out.clear()

    def _step(mut self, deadline: Int, message: StaticString) raises WsError:
        """Send the output, then read once; raise `TIMEOUT` at the
        deadline."""
        if not self._fill(deadline):
            raise WsError.of(WsErrorKind.TIMEOUT, message)

    def _fill(mut self, deadline: Int) raises WsError -> Bool:
        """Send the output, then read what arrives; False at the deadline."""
        self._write(_now_ms() + self.config.write_timeout_ms)
        while True:
            var n = self.transport.read(
                Pointer[UInt8, MutUntrackedOrigin](
                    unsafe_from_address=Int(self._buffer.unsafe_ptr())
                ),
                len(self._buffer),
            )
            if n > 0:
                self.conn.receive(Span(self._buffer)[:n])
                self._events()
                return True
            if n == -EAGAIN or n == -EINTR:
                if not wait_socket(
                    self.sys, self.transport.fd(), POLLIN, deadline
                ):
                    return False
                continue
            self._ended = True
            if n < 0:
                raise WsError.of(
                    WsErrorKind.IO, "recv failed: errno " + String(-n)
                )
            return True

    def _events(mut self):
        """Note the end of the stream, and give its content to the
        WebSocket."""
        # The connection has one stream, so each event is of the WebSocket.
        var index = 0
        while index < len(self.conn.events):
            var kind = self.conn.events[index].kind
            if kind == EventKind.MESSAGE or kind == EventKind.RESET:
                self._ended = True
            index += 1
        self.conn.events.clear()
        if self.conn.closed:
            self._ended = True
        if self._open:
            self._take()

    def _take(mut self):
        """Move the content of the stream into the WebSocket."""
        var index = self.conn.find(self.stream_id)
        if index >= 0:
            self.ws.receive(Span(self.conn.streams[index].body))
            self.conn.streams[index].body.clear()

    def flush(mut self) raises WsError:
        """Move the output of the WebSocket into `DATA` frames, and send
        them within `write_timeout_ms`.

        Raises:
            WsError: `TIMEOUT` when the windows stay shut; `IO` when the
                transport or the stream fails.
        """
        var deadline = _now_ms() + self.config.write_timeout_ms
        var total = self.ws.pending()
        # After the closing handshake the end of the stream goes out.
        var end = self.ws.should_close() and not self._sent_end
        if not self._ended and (total > 0 or end):
            try:
                self.conn.send_data(
                    self.stream_id,
                    Span(unsafe_ptr=self.ws.output(), length=total),
                    end,
                )
            except e:
                raise _h2(e)
            self._sent_end = end
        self.ws.advance(total)
        while self._waiting() > 0 and not self._ended:
            self._step(deadline, "send timed out")
        self._write(deadline)

    def _waiting(self) -> Int:
        """Return the content of the stream that waits for a window."""
        var index = self.conn.find(self.stream_id)
        if index < 0:
            return 0
        return self.conn.streams[index].pending()

    def read(
        mut self, mut message: Message, timeout_ms: Int = -1
    ) raises WsError -> Bool:
        """Read the next message.

        A ping gets its pong before the method returns.

        Args:
            message: The message to fill.
            timeout_ms: The longest wait; -1 waits without a limit, and 0
                reads only what has arrived.

        Returns:
            True with a message; False when the timeout passed first.

        Raises:
            WsError: `CLOSED` when the server ended the stream after the
                closing handshake; `PROTOCOL` for a reset or an end
                without it, and the errors of `WebSocket.read`; `IO` when
                the transport fails.
        """
        var deadline = -1 if timeout_ms < 0 else _now_ms() + timeout_ms
        while True:
            var got: Bool
            try:
                got = self.ws.read(message)
            except e:
                # The close frame of the failure goes out first; a failed
                # send raises its own error.
                self.flush()
                raise e^
            self.flush()
            if got:
                return True
            if self._ended:
                var clean = self.ws.peer_closed()
                if clean:
                    raise WsError.of(
                        WsErrorKind.CLOSED, "Connection closed normally"
                    )
                raise WsError.protocol(
                    "Connection reset without closing handshake"
                )
            if not self._fill(deadline):
                return False

    def send_text(mut self, text: StringSlice) raises WsError:
        """Send a text message.

        Args:
            text: The text.

        Raises:
            WsError: The errors of `WebSocket.send_text` and `flush`.
        """
        self.ws.send_text(text)
        self.flush()

    def send_binary(mut self, data: Span[UInt8, _]) raises WsError:
        """Send a binary message.

        Args:
            data: The bytes.

        Raises:
            WsError: The errors of `WebSocket.send_binary` and `flush`.
        """
        self.ws.send_binary(data)
        self.flush()

    def ping(mut self, data: Span[UInt8, _]) raises WsError:
        """Send a ping.

        Args:
            data: The payload, at most 125 bytes.

        Raises:
            WsError: The errors of `WebSocket.ping` and `flush`.
        """
        self.ws.ping(data)
        self.flush()

    def close(
        mut self, code: CloseCode = CloseCode.NORMAL, reason: StringSlice = ""
    ) raises WsError:
        """Send a close frame. Read on until `read` raises `CLOSED`.

        Args:
            code: The code.
            reason: The reason, at most 123 bytes.

        Raises:
            WsError: The errors of `WebSocket.close` and `flush`.
        """
        self.ws.close(code, reason)
        self.flush()


def connect_h2c(
    url: StringSlice,
    protocols: List[String] = [],
    config: ClientConfig = ClientConfig(),
    h2: Config = Config(),
    var sys: Sys = Sys(),
) raises WsError -> H2WebSocket[SocketTransport]:
    """Connect to a `ws://` URL with h2c and prior knowledge, and do the
    extended `CONNECT`.

    Args:
        url: The URL, such as `ws://localhost:4000/graphql`.
        protocols: The subprotocols to offer.
        config: The configuration of the WebSocket.
        h2: The limits of the HTTP/2 connection.
        sys: The system calls; tests give one with faults.

    Returns:
        The WebSocket.

    Raises:
        WsError: `HANDSHAKE` for a bad URL, a `wss://` URL, or a refused
            handshake; the errors of `H2WebSocket.handshake`.
    """
    var parsed: Url
    try:
        parsed = Url.parse(url)
    except e:
        raise WsError.of(WsErrorKind.HANDSHAKE, "URL error: " + e.message)
    if parsed.scheme != "ws":
        raise WsError.of(
            WsErrorKind.HANDSHAKE, "URL error: URL scheme not supported"
        )
    var port = parsed.port if parsed.port >= 0 else 80
    var deadline = _now_ms() + config.connect_timeout_ms
    var fd = open_socket(sys, parsed.host, port, deadline)
    var socket = H2WebSocket[SocketTransport](
        SocketTransport(fd, sys^), config, h2
    )
    var target = parsed.path
    if parsed.query.byte_length() > 0:
        target += "?" + parsed.query
    socket.handshake(
        "http", parsed.host + ":" + String(port), target, protocols
    )
    return socket^


def connect_transport_h2c(
    url: StringSlice,
    connection_params: StringSlice = "",
    ack_timeout_ms: Int = 0,
    config: ClientConfig = ClientConfig(),
) raises WsError -> H2TransportClient:
    """Connect with `connect_h2c`, send `connection_init`, and wait for the
    ack.

    Args:
        url: The `ws://` URL of the server.
        connection_params: The JSON object of the `connection_init`
            payload, or empty.
        ack_timeout_ms: The longest wait for the ack; 0 waits without a
            limit.
        config: The configuration of the WebSocket.

    Returns:
        The client.

    Raises:
        WsError: The errors of `connect_h2c` and of
            `TransportClientOf.start`.
    """
    var socket = connect_h2c(url, [GRAPHQL_TRANSPORT_WS_PROTOCOL], config)
    var client = H2TransportClient(socket^)
    client.start(connection_params, ack_timeout_ms)
    return client^

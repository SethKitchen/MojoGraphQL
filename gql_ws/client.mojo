# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A WebSocket client on a non-blocking socket: connect with the opening
handshake, send messages, and read them with a deadline.

`WsClient.connect` resolves a `ws://` URL, connects, sends the Upgrade
request, and checks the answer. `read` waits for the next message until a
timeout. Each wait is a `poll`, so a client can also read with a timeout
of 0 inside another event loop, on `fd`.

This module ports tungstenite 0.30.0 `src/client.rs` (`connect`,
`client_with_config`, `uri_mode`) and the `WebSocket` read and write loop
of `src/protocol/mod.rs`, with `tests/handshake.rs`,
`tests/connection_reset.rs` and `tests/wss_fails_when_no_tls.rs`.

Differences from upstream: `read` takes a timeout and returns False when
it passes; tungstenite blocks, or returns `WouldBlock`. There is no TLS,
so a `wss://` URL fails, as tungstenite without a TLS feature.
"""

from std.time import perf_counter_ns

from gql_http.error import HttpError
from gql_http.parser import (
    Limits,
    ParseState,
    ResponseHead,
    parse_response_head,
)
from gql_http.socket import (
    EAGAIN,
    EINPROGRESS,
    EINTR,
    POLLIN,
    POLLOUT,
    IPv4Address,
    Sys,
)
from gql_http.url import Url

from gql_ws.error import WsError, WsErrorKind
from gql_ws.frame import CloseCode
from gql_ws.handshake import client_request, generate_key, verify_response
from gql_ws.protocol import Message, Role, WebSocket, WsConfig


@fieldwise_init
struct ClientConfig(Copyable, Movable):
    """The limits and timeouts of a client."""

    var ws: WsConfig
    """The limits of the connection."""
    var connect_timeout_ms: Int
    """The longest wait for the connection and the handshake; 5000 at
    first."""
    var write_timeout_ms: Int
    """The longest wait to send the output; 30000 at first."""
    var headers: String
    """More lines for the Upgrade request, each with its CRLF."""

    def __init__(out self):
        """Make the default configuration."""
        self.ws = WsConfig()
        self.connect_timeout_ms = 5000
        self.write_timeout_ms = 30000
        self.headers = String()


def _now_ms() -> Int:
    """Return a monotonic time in milliseconds."""
    return Int(perf_counter_ns() // 1_000_000)


def _io(message: String, errno: Int) -> WsError:
    """Make the error of a failed socket call."""
    return WsError.of(WsErrorKind.IO, message + ": errno " + String(errno))


trait MessageSocket(Deinitable, Movable):
    """The client end of a WebSocket that carries a protocol such as
    `graphql-transport-ws`: `WsClient`, or a WebSocket on an HTTP/2 or an
    HTTP/3 stream."""

    def read(
        mut self, mut message: Message, timeout_ms: Int
    ) raises WsError -> Bool:
        """Read the next message, and answer a ping.

        Args:
            message: The message to fill.
            timeout_ms: The longest wait; -1 waits without a limit.

        Returns:
            True with a message; False after the timeout.

        Raises:
            WsError: `CLOSED` after the closing handshake, or a failure.
        """
        ...

    def send_text(mut self, text: StringSlice) raises WsError:
        """Send a text message.

        Args:
            text: The text.

        Raises:
            WsError: When the send fails.
        """
        ...

    def close(mut self, code: CloseCode, reason: StringSlice) raises WsError:
        """Start the closing handshake.

        Args:
            code: The code.
            reason: The reason, at most 123 bytes.

        Raises:
            WsError: When the send fails.
        """
        ...


struct WsClient(MessageSocket):
    """A connected WebSocket client."""

    var ws: WebSocket
    """The protocol state."""
    var protocol: String
    """The subprotocol of the server, or empty."""
    var sys: Sys
    """The system calls; tests give one with faults."""
    var config: ClientConfig
    """The configuration."""
    var fd: Int
    """The socket; -1 after `close`."""

    def __init__(out self, fd: Int, var sys: Sys, config: ClientConfig):
        """Wrap a connected socket after its handshake.

        Args:
            fd: The non-blocking socket; the client closes it.
            sys: The system calls.
            config: The configuration.
        """
        self.ws = WebSocket(Role.CLIENT, config.ws)
        self.protocol = String()
        self.sys = sys^
        self.config = config.copy()
        self.fd = fd

    def __deinit__(deinit self):
        """Close the socket when it is open."""
        if self.fd >= 0:
            self.sys.close(self.fd)

    @staticmethod
    def connect(
        url: StringSlice,
        protocols: List[String] = [],
        config: ClientConfig = ClientConfig(),
        var sys: Sys = Sys(),
    ) raises WsError -> WsClient:
        """Connect to a `ws://` URL and do the opening handshake.

        Args:
            url: The URL, such as `ws://localhost:4000/graphql`.
            protocols: The subprotocols to offer.
            config: The configuration.
            sys: The system calls; tests give one with faults.

        Returns:
            The client.

        Raises:
            WsError: `HANDSHAKE` for a bad URL or a refused handshake, with
                the status of the answer; `IO` when the connection fails;
                `TIMEOUT` after `connect_timeout_ms`.
        """
        var parsed: Url
        try:
            parsed = Url.parse(url)
        except e:
            raise WsError.of(WsErrorKind.HANDSHAKE, "URL error: " + e.message)
        if parsed.scheme == "wss":
            raise WsError.of(
                WsErrorKind.HANDSHAKE, "URL error: TLS support not compiled in"
            )
        if parsed.scheme != "ws":
            raise WsError.of(
                WsErrorKind.HANDSHAKE, "URL error: URL scheme not supported"
            )
        var port = parsed.port if parsed.port >= 0 else 80
        var deadline = _now_ms() + config.connect_timeout_ms
        var fd = open_socket(sys, parsed.host, port, deadline)
        var client = WsClient(fd, sys^, config)
        var target = parsed.path
        if parsed.query.byte_length() > 0:
            target += "?" + parsed.query
        var host = parsed.host + ":" + String(port)
        var key = generate_key()
        var request = client_request(
            host, target, key, protocols, config.headers
        )
        client.ws.out.extend(Span(request))
        client._flush_until(deadline)
        client._handshake(key, protocols, deadline)
        return client^

    def _wait(mut self, events: Int, deadline: Int) raises WsError -> Bool:
        """Wait until the socket is ready; False at the deadline."""
        return wait_socket(self.sys, self.fd, events, deadline)

    def _flush_until(mut self, deadline: Int) raises WsError:
        """Send the whole output, or raise `TIMEOUT` at the deadline."""
        while self.ws.pending() > 0:
            var n = self.sys.send(self.fd, self.ws.output(), self.ws.pending())
            if n == -EAGAIN:
                if not self._wait(POLLOUT, deadline):
                    raise WsError.of(WsErrorKind.TIMEOUT, "send timed out")
                continue
            if n == -EINTR:
                continue
            if n < 0:
                raise _io("send failed", -n)
            self.ws.advance(n)

    def flush(mut self) raises WsError:
        """Send the output, within `write_timeout_ms`.

        Raises:
            WsError: `TIMEOUT` when the peer does not read; `IO` when the
                send fails.
        """
        self._flush_until(_now_ms() + self.config.write_timeout_ms)

    def _handshake(
        mut self, key: String, protocols: List[String], deadline: Int
    ) raises WsError:
        """Read and check the answer to the Upgrade request."""
        var data = List[UInt8](length=4096, fill=0)
        var end = 0
        var head = ResponseHead()
        var limits = Limits()
        while True:
            var result = parse_response_head(
                data.unsafe_ptr(), end, limits, head
            )
            if result.state == ParseState.COMPLETE:
                self.protocol = verify_response(
                    data.unsafe_ptr(), head, key, protocols
                )
                self.ws.receive(Span(data)[result.size : end])
                return
            if result.state == ParseState.ERROR:
                raise WsError.of(
                    WsErrorKind.HANDSHAKE, "invalid handshake response"
                )
            if len(data) - end < 1024:
                data.resize(len(data) * 2, 0)
            var n = self.sys.recv(
                self.fd, data.unsafe_ptr().unsafe_offset(end), len(data) - end
            )
            if n == -EAGAIN:
                if not self._wait(POLLIN, deadline):
                    raise WsError.of(WsErrorKind.TIMEOUT, "handshake timed out")
                continue
            if n == -EINTR:
                continue
            if n <= 0:
                raise WsError.of(
                    WsErrorKind.HANDSHAKE, "Handshake not finished"
                )
            end += n

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
            WsError: `CLOSED` when the server closed the connection after
                the closing handshake; `PROTOCOL` for a reset without it,
                and the errors of `WebSocket.read`; `IO` when `recv` fails.
        """
        var deadline = -1 if timeout_ms < 0 else _now_ms() + timeout_ms
        while True:
            var got: Bool
            try:
                got = self.ws.read(message)
            except e:
                # Best effort: the close frame of the failure.
                _ = self.sys.send(self.fd, self.ws.output(), self.ws.pending())
                raise e^
            self.flush()
            if got:
                return True
            self.ws.reserve(16384)
            var n = self.sys.recv(
                self.fd, self.ws.write_pointer(), self.ws.space()
            )
            if n > 0:
                self.ws.commit(n)
                continue
            if n == -EAGAIN:
                if not self._wait(POLLIN, deadline):
                    return False
                continue
            if n == -EINTR:
                continue
            var clean = self.ws.peer_closed()
            if n < 0:
                raise _io("recv failed", -n)
            if clean:
                raise WsError.of(
                    WsErrorKind.CLOSED, "Connection closed normally"
                )
            raise WsError.protocol("Connection reset without closing handshake")

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

    def disconnect(mut self):
        """Close the socket at once, without a closing handshake."""
        if self.fd >= 0:
            self.sys.close(self.fd)
            self.fd = -1


def wait_socket(
    mut sys: Sys, fd: Int, events: Int, deadline: Int
) raises WsError -> Bool:
    """Wait until a socket is ready.

    Args:
        sys: The system calls.
        fd: The socket.
        events: The `poll` events, such as `POLLIN`.
        deadline: The deadline on the clock of `perf_counter_ns`, in
            milliseconds; -1 for none.

    Returns:
        True when the socket is ready; False at the deadline.

    Raises:
        WsError: `IO` when `poll` fails.
    """
    while True:
        var remaining = -1
        if deadline >= 0:
            remaining = deadline - _now_ms()
            if remaining <= 0:
                return False
        var rc = sys.poll(fd, events, remaining)
        if rc > 0:
            return True
        if rc < 0 and rc != -EINTR:
            raise _io("poll failed", -rc)


def open_socket(
    mut sys: Sys, host: StringSlice, port: Int, deadline: Int
) raises WsError -> Int:
    """Resolve a host and connect a non-blocking socket to it.

    Args:
        sys: The system calls.
        host: The host name or address.
        port: The port.
        deadline: The deadline of the connect, as for `wait_socket`.

    Returns:
        The connected socket.

    Raises:
        WsError: `IO` when the name does not resolve or the connect fails;
            `TIMEOUT` at the deadline.
    """
    var address: IPv4Address
    try:
        address = sys.resolve(host)
    except e:
        raise WsError.of(WsErrorKind.IO, e.message)
    var fd = sys.socket()
    if fd < 0:
        raise _io("socket failed", -fd)
    _ = sys.set_no_delay(fd)
    var rc = sys.connect(fd, address, port)
    if rc == -EINPROGRESS:
        var ready: Bool
        try:
            ready = wait_socket(sys, fd, POLLOUT, deadline)
        except e:
            sys.close(fd)
            raise e^
        if not ready:
            sys.close(fd)
            raise WsError.of(WsErrorKind.TIMEOUT, "connect timed out")
        rc = -sys.socket_error(fd)
    if rc != 0:
        sys.close(fd)
        raise _io("cannot connect to " + String(host), -rc)
    return fd

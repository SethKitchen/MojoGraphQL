# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""HTTP/2 over TLS: a `TlsServer` of `gql_tls` that serves `h2` with the
`ServerSession` of `gql_http2`, and HTTP/1.1 on the same port.

`H2Protocol` is the `TlsProtocol` of ALPN `h2`. It keeps one
`ServerSession` for each connection that chose `h2`: the server gives it
the decrypted bytes, and it gives back the frames to send.

`listen_https2` opens the server. Its context offers ALPN `h2` and then
`http/1.1`, the default of `TlsContext.server`. The server chooses the
first of its protocols that the client offers (RFC 7301 section 3.2), so
`h2` is preferred:

- A client that offers `h2` gets HTTP/2.
- A client that offers only `http/1.1`, or no ALPN, gets HTTP/1.1.

One handler serves both protocols. `SharedHandler` gives the two parts of
the server the same handler, so its state is one.

This module ports no code. The behavior follows RFC 9113 section 3.2 and
RFC 7301.

Differences from upstream: none; there is no upstream. These are the
differences from the h2c server of `gql_http2`:

- **Shutdown.** `TlsProtocol` has no shutdown, so a graceful shutdown of
  the server does not send `GOAWAY`. An `h2` connection ends when its
  client closes it, or at `shutdown_timeout_ms`.
- **One process.** `TlsServer` is one event loop. Run one server for each
  core with `reuse_port`.
"""

from std.memory import ArcPointer

from gql_http.parser import Limits, Request
from gql_http.server import Handler, ResponseWriter, ServerConfig
from gql_http.socket import Sys
from gql_http2.connection import Config
from gql_http2.session import ServerSession
from gql_tls.context import TlsContext
from gql_tls.error import TlsError
from gql_tls.server import TlsProtocol, TlsServer, listen_tls

comptime H2 = "h2"
"""The ALPN name of HTTP/2 over TLS (RFC 9113 section 3.2)."""


struct SharedHandler[H: Handler](Copyable, Handler):
    """A handler that its copies share, so that one handler serves HTTP/1.1
    and HTTP/2 in one event loop.

    Parameters:
        H: The type of the handler.
    """

    var shared: ArcPointer[Self.H]
    """The handler."""

    def __init__(out self, var handler: Self.H):
        """Share a handler.

        Args:
            handler: The handler.
        """
        self.shared = ArcPointer(handler^)

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        """Call the shared handler.

        Args:
            request: The request.
            response: The response to fill.

        Raises:
            Error: What the handler raises.
        """
        self.shared[].handle(request, response)


struct H2Protocol[H: Handler](TlsProtocol):
    """The `TlsProtocol` of ALPN `h2`: one HTTP/2 server session for each
    connection.

    Parameters:
        H: The type of the handler.
    """

    var handler: Self.H
    """The handler of every HTTP/2 request."""
    var config: Config
    """The limits of each HTTP/2 connection."""
    var limits: Limits
    """The limits of each request."""
    var _sessions: List[ServerSession]
    var _slots: List[Int]
    var _free: List[Int]

    def __init__(
        out self,
        var handler: Self.H,
        config: Config = Config(),
        limits: Limits = Limits(),
    ):
        """Make the protocol with no connection.

        Args:
            handler: The handler of every HTTP/2 request.
            config: The limits of each HTTP/2 connection.
            limits: The limits of each request.
        """
        self.handler = handler^
        self.config = config.copy()
        self.limits = limits
        self._sessions = List[ServerSession]()
        self._slots = List[Int]()
        self._free = List[Int]()

    def protocol(self) -> String:
        """Return `h2`.

        Returns:
            The ALPN name.
        """
        return H2

    def sessions(self) -> Int:
        """Return the count of open HTTP/2 connections.

        Returns:
            The count.
        """
        return len(self._sessions) - len(self._free)

    def open(mut self, conn: Int, mut out: List[UInt8]):
        """Start a session for a connection, and send its `SETTINGS`.

        Args:
            conn: The id of the connection.
            out: The bytes to send.
        """
        while len(self._slots) <= conn:
            self._slots.append(-1)
        var session = ServerSession(self.config, self.limits)
        session.start()
        var index: Int
        if len(self._free) > 0:
            index = self._free.pop()
            self._sessions[index] = session^
        else:
            index = len(self._sessions)
            self._sessions.append(session^)
        self._slots[conn] = index
        out.extend(Span(self._sessions[index].conn.out))
        self._sessions[index].conn.out.clear()

    def receive(
        mut self, conn: Int, data: List[UInt8], mut out: List[UInt8]
    ) -> Bool:
        """Read the frames of a connection, and answer each whole request.

        Args:
            conn: The id of the connection.
            data: The decrypted bytes.
            out: The frames to send.

        Returns:
            False when the connection has ended, such as after `GOAWAY`.
        """
        var index = self._slots[conn]
        self._sessions[index].receive(self.handler, Span(data))
        out.extend(Span(self._sessions[index].conn.out))
        self._sessions[index].conn.out.clear()
        return not self._sessions[index].is_done()

    def close(mut self, conn: Int):
        """Free the session of a connection that has closed.

        Args:
            conn: The id of the connection.
        """
        self._free.append(self._slots[conn])
        self._slots[conn] = -1


def listen_https2[
    H: Handler
](
    var handler: H,
    var context: TlsContext,
    config: ServerConfig,
    h2: Config = Config(),
    var sys: Sys = Sys(),
) raises TlsError -> TlsServer[SharedHandler[H], H2Protocol[SharedHandler[H]]]:
    """Open a TLS event loop that serves HTTP/2 and HTTP/1.1 with one
    handler.

    Give it a context whose ALPN protocols are `h2` and then `http/1.1`,
    such as `TlsContext.server(openssl, cert_file, key_file)`.

    Args:
        handler: The handler of every request of both protocols.
        context: A server context.
        config: The address, the port, the timeouts and the limits.
        h2: The limits of each HTTP/2 connection.
        sys: The system calls; tests give one with faults.

    Returns:
        The server. Its `port` is the port it listens on, and its
        `handler.shared[]` is the handler.

    Raises:
        TlsError: `OS` when the socket or epoll cannot be opened.

    Parameters:
        H: The type of the handler.
    """
    var shared = SharedHandler(handler^)
    var other = H2Protocol(shared.copy(), h2, config.limits)
    return listen_tls(shared^, context^, config, other^, sys^)

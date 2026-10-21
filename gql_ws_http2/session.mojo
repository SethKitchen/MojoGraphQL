# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The server end of one HTTP/2 connection that carries WebSockets (RFC
8441) and requests, without I/O.

`WsH2Session` wraps the `ServerSession` of `gql_http2`. An extended
`CONNECT` with `:protocol websocket` opens a tunnel: the session answers
200, opens a WebSocket in the `Sockets` of `gql_ws` with `attach`, and
calls the `WsHandler`. The `DATA` frames of the tunnel carry the frames of
the WebSocket both ways, so the frame codec and `graphql-transport-ws` are
those of `gql_ws`. Each other request goes to the gql_http `Handler`.

- **Output.** `flush` moves the output of each WebSocket into `DATA`
  frames. A WebSocket waits while its stream has content that waits for a
  window, so `max_write_buffer_size` is the back pressure of a slow peer.
- **Closing.** The end of the stream is the end of the TCP connection of
  RFC 6455 (RFC 8441 section 6). After the closing handshake the session
  ends its side with `END_STREAM`. An `END_STREAM` of the peer ends the
  WebSocket. A reset is a close without a handshake, 1006.
- **Refusals.** A tunnel that `server_accept` refuses gets its status and
  `END_STREAM`, then `RST_STREAM` with `NO_ERROR`. A tunnel on another path
  than `path` gets 404.

The driver gives each read to `receive`, sends `session.conn.out` and clears it,
calls `flush` after a handler sent on `Sockets` outside `receive`, and
calls `close_all` when the connection ends.

This module ports no code. The behavior follows RFC 8441 sections 4 to 6.

Differences from upstream: none; there is no upstream.
"""

from gql_http.parser import Limits
from gql_http.server import Handler
from gql_http2.connection import Config, Connection, Event, EventKind
from gql_http2.error import Reason
from gql_http2.hpack import HeaderList
from gql_http2.session import ServerSession
from gql_ws.error import WsError, WsErrorKind
from gql_ws.frame import CloseCode
from gql_ws.protocol import Message, MessageKind
from gql_ws.server import Sockets, WsHandler

from gql_ws_http2.handshake import (
    H2Accepted,
    reject_head,
    response_head,
    server_accept,
)


@fieldwise_init
struct Tunnel(ImplicitlyCopyable):
    """A WebSocket on a stream."""

    var stream_id: Int
    """The HTTP/2 stream."""
    var slot: Int
    """The slot of the WebSocket in `Sockets`."""
    var id: Int
    """The id of the WebSocket in `Sockets`."""


struct WsH2Session(Movable):
    """The server end of one HTTP/2 connection with WebSockets."""

    var session: ServerSession
    """The HTTP/2 session of the requests and of the connection."""
    var protocols: List[String]
    """The subprotocols, by preference."""
    var path: String
    """The WebSocket path; empty takes every path."""
    var tunnels: List[Tunnel]
    """The open WebSockets of the connection."""
    var _message: Message
    var _rest: List[Event]

    def __init__(
        out self,
        config: Config = Config(),
        limits: Limits = Limits(),
        protocols: List[String] = [],
        path: String = "",
    ):
        """Make a session that has sent nothing yet; call `start`.

        Args:
            config: The limits of the connection. The session turns
                `enable_connect_protocol` on.
            limits: The limits of each request.
            protocols: The subprotocols, by preference.
            path: The WebSocket path; empty takes every path.
        """
        var h2 = config.copy()
        h2.enable_connect_protocol = True
        self.session = ServerSession(h2, limits)
        self.protocols = protocols.copy()
        self.path = path
        self.tunnels = List[Tunnel]()
        self._message = Message()
        self._rest = List[Event]()

    def start(mut self):
        """Append the server's `SETTINGS`, with
        `SETTINGS_ENABLE_CONNECT_PROTOCOL = 1`, to `session.conn.out`."""
        self.session.start()

    def is_done(self) -> Bool:
        """Return True when the connection can close once `session.conn.out` is
        sent.

        Returns:
            Whether the connection has ended.
        """
        return self.session.is_done()

    def receive[
        H: Handler, W: WsHandler
    ](
        mut self,
        mut http: H,
        mut handler: W,
        mut sockets: Sockets,
        data: Span[UInt8, _],
    ):
        """Read bytes from the client: open and feed the WebSockets, and
        answer each whole request.

        Args:
            http: The handler of the requests.
            handler: The handler of the WebSockets.
            sockets: The WebSockets of the event loop.
            data: The bytes, in order.

        Parameters:
            H: The type of the request handler.
            W: The type of the WebSocket handler.
        """
        self.session.conn.receive(data)
        self._events(handler, sockets)
        self.session.dispatch(http)
        self.flush(handler, sockets)
        if self.session.conn.closed:
            self.close_all(handler, sockets)

    def _events[W: WsHandler](mut self, mut handler: W, mut sockets: Sockets):
        """Take the events of the tunnels, and keep the others for the
        request handler."""
        self._rest.clear()
        var index = 0
        while index < len(self.session.conn.events):
            var event = self.session.conn.events[index].copy()
            index += 1
            var t = self._find(event.stream_id)
            if t >= 0:
                self._tunnel_event(handler, sockets, t, event.kind)
                continue
            var slot = self.session.conn.find(event.stream_id)
            if slot < 0:
                # The stream has gone: a reset, or a request of the handler.
                self._rest.append(event^)
            elif event.kind == EventKind.HEAD:
                self._open(handler, sockets, slot)
            elif self.session.conn.streams[slot].tunnel:
                # A tunnel that ended, or ended at once: drop its content.
                self.session.conn.streams[slot].body.clear()
                if not self.session.conn.streams[slot].answered:
                    self._refuse(
                        event.stream_id,
                        WsError(WsErrorKind.HANDSHAKE, "ended", 0, 400),
                    )
            else:
                self._rest.append(event^)
        swap(self.session.conn.events, self._rest)

    def _find(self, stream_id: Int) -> Int:
        """Return the index of the tunnel of a stream, or -1."""
        var t = 0
        while t < len(self.tunnels):
            if self.tunnels[t].stream_id == stream_id:
                return t
            t += 1
        return -1

    def _open[
        W: WsHandler
    ](mut self, mut handler: W, mut sockets: Sockets, index: Int):
        """Answer the extended `CONNECT` of the stream in a slot, and open
        its WebSocket."""
        var stream_id = self.session.conn.streams[index].id
        var accepted: H2Accepted
        try:
            accepted = server_accept(
                self.session.conn.streams[index].headers, self.protocols
            )
        except e:
            self._refuse(stream_id, e)
            return
        if self.path.byte_length() > 0 and accepted.path != self.path:
            self._refuse(
                stream_id, WsError(WsErrorKind.HANDSHAKE, "Not Found", 0, 404)
            )
            return
        self._head(stream_id, response_head(accepted.protocol), False)
        var slot = sockets.free_slot()
        var id = sockets.attach(slot, accepted.protocol, accepted.path)
        self.tunnels.append(Tunnel(stream_id, slot, id))
        try:
            handler.on_open(sockets, id)
        except:
            sockets.conns[slot].ws.go_away(CloseCode.ERROR)

    def _head(mut self, stream_id: Int, fields: HeaderList, end: Bool):
        """Send a head on a stream that can still send."""
        try:
            self.session.conn.send_headers(stream_id, fields, end)
        except:
            # The stream is not open any more: nothing to send.
            pass

    def _refuse(mut self, stream_id: Int, error: WsError):
        """Answer a refused tunnel, and reset it so that the client sends
        no more."""
        self._head(stream_id, reject_head(error), True)
        self.session.conn.reset_stream(stream_id, Reason.NO_ERROR)

    def _tunnel_event[
        W: WsHandler
    ](mut self, mut handler: W, mut sockets: Sockets, t: Int, kind: EventKind):
        """Give the content of a tunnel to its WebSocket."""
        var slot = self.tunnels[t].slot
        if kind == EventKind.RESET:
            _ = sockets.conns[slot].ws.peer_closed()
            self._finish(handler, sockets, t, False)
            return
        var index = self.session.conn.find(self.tunnels[t].stream_id)
        sockets.conns[slot].ws.receive(
            Span(self.session.conn.streams[index].body)
        )
        self.session.conn.streams[index].body.clear()
        self._process(handler, sockets, t)
        if kind == EventKind.MESSAGE:
            # The end of the stream is the end of the TCP connection.
            _ = sockets.conns[slot].ws.peer_closed()

    def _process[
        W: WsHandler
    ](mut self, mut handler: W, mut sockets: Sockets, t: Int):
        """Read each whole message of a WebSocket, and give it to the
        handler."""
        var slot = self.tunnels[t].slot
        var id = self.tunnels[t].id
        while True:
            var got: Bool
            try:
                got = sockets.conns[slot].ws.read(self._message)
            except:
                # The output holds the close frame of the failure.
                break
            if not got:
                break
            var kind = self._message.kind
            if kind == MessageKind.CLOSE:
                sockets.conns[slot].code = self._message.code.value
                sockets.conns[slot].reason = String(self._message.text())
            elif kind == MessageKind.TEXT or kind == MessageKind.BINARY:
                try:
                    handler.on_message(sockets, id, self._message)
                except:
                    sockets.conns[slot].ws.go_away(CloseCode.ERROR)

    def flush[W: WsHandler](mut self, mut handler: W, mut sockets: Sockets):
        """Move the output of each WebSocket into `DATA` frames, and end
        each WebSocket that has closed.

        Args:
            handler: The handler of the WebSockets, for `on_close`.
            sockets: The WebSockets of the event loop.

        Parameters:
            W: The type of the WebSocket handler.
        """
        var t = 0
        while t < len(self.tunnels):
            if not self._flush(handler, sockets, t):
                t += 1

    def _flush[
        W: WsHandler
    ](mut self, mut handler: W, mut sockets: Sockets, t: Int) -> Bool:
        """Send the output of one WebSocket; True when it ended."""
        var stream_id = self.tunnels[t].stream_id
        var slot = self.tunnels[t].slot
        var index = self.session.conn.find(stream_id)
        var total = sockets.conns[slot].ws.pending()
        if total > 0 and self.session.conn.streams[index].pending() == 0:
            try:
                self.session.conn.send_data(
                    stream_id,
                    Span(
                        unsafe_ptr=sockets.conns[slot].ws.output(),
                        length=total,
                    ),
                    False,
                )
            except:
                # The stream cannot send: the connection has ended.
                pass
            sockets.conns[slot].ws.advance(total)
        if (
            sockets.conns[slot].ws.pending() == 0
            and sockets.conns[slot].ws.should_close()
        ):
            self._finish(handler, sockets, t, True)
            return True
        return False

    def _finish[
        W: WsHandler
    ](mut self, mut handler: W, mut sockets: Sockets, t: Int, end: Bool):
        """End a WebSocket: end its stream, free its slot, and tell the
        handler."""
        var tunnel = self.tunnels[t]
        if end:
            try:
                self.session.conn.send_data(
                    tunnel.stream_id, Span[UInt8, ImmUntrackedOrigin](), True
                )
            except:
                # The stream has ended already.
                pass
            self.session.conn.release(tunnel.stream_id)
        var code = sockets.conns[tunnel.slot].code
        var reason = sockets.conns[tunnel.slot].reason
        sockets.detach(tunnel.slot)
        _ = self.tunnels.pop(t)
        handler.on_close(sockets, tunnel.id, code, reason)

    def close_all[W: WsHandler](mut self, mut handler: W, mut sockets: Sockets):
        """End each WebSocket at once, as a close without a handshake: the
        connection has ended.

        Args:
            handler: The handler of the WebSockets, for `on_close`.
            sockets: The WebSockets of the event loop.

        Parameters:
            W: The type of the WebSocket handler.
        """
        while len(self.tunnels) > 0:
            _ = sockets.conns[self.tunnels[0].slot].ws.peer_closed()
            self._finish(handler, sockets, 0, False)

    def owns(self, slot: Int) -> Bool:
        """Return True when a WebSocket of this connection is in a slot.

        Args:
            slot: The slot in `Sockets`.

        Returns:
            Whether the slot belongs to this connection.
        """
        var t = 0
        while t < len(self.tunnels):
            if self.tunnels[t].slot == slot:
                return True
            t += 1
        return False

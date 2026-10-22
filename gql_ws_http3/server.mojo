# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""An HTTP/3 server for WebSockets over HTTP/3 (RFC 9220): the QUIC loop
of `gql_http3` with the tunnel events of its extended `CONNECT`.

`Server` runs an `H3Server` with `enable_connect`. Each extended `CONNECT`
opens a WebSocket in one `Sockets` of `gql_ws`, so a `WsHandler`, such as
the `graphql-transport-ws` server of `gql_ws`, serves it as it serves the
WebSockets of HTTP/1.1 and HTTP/2. Each other request goes to the
gql_http `Handler` of the `H3Server`.

- **Handshake.** A request that `check_connect` refuses is reset with
  `H3_MESSAGE_ERROR`. A WebSocket that `server_accept` refuses gets its
  status, and the server ends the stream. A WebSocket on another path than
  `path` gets 404.
- **Content.** The DATA frames of the tunnel carry the frames of the
  WebSocket both ways. A WebSocket waits while its stream has content that
  waits for credit.
- **Closing.** After the closing handshake, the server ends its side of
  the stream (FIN). A FIN of the peer is the end of the TCP connection of
  RFC 6455. A reset, or the end of the QUIC connection, is a close without
  a handshake, with code 1006.
- **Turns.** Each `poll` runs the QUIC loop, gives the tunnel events to the
  WebSockets, calls `on_tick`, and sends the output of every WebSocket.
  `wait_ms` of the handler limits the wait.

This module ports no code. It mirrors the h2c loop of `gql_ws_http2`.

Differences from upstream: none; there is no upstream. The `fd` of the
handler does not wake the loop, because the loop waits on its UDP socket
only.
"""

from gql_http.server import Handler
from gql_tls.error import TlsError
from gql_http3.error import H3Error
from gql_http3.frame import write_data_frame, write_headers_frame
from gql_http3.qpack_encoder import QpackEncoder
from gql_http3.qpack_field import FieldList
from gql_http3.quic import Quic, QuicContext
from gql_http3.server import (
    H3Config,
    H3Server,
    TunnelEvent,
    TunnelEventKind,
)
from gql_http2.hpack import HeaderList
from gql_ws.error import WsError, WsErrorKind
from gql_ws.frame import CloseCode
from gql_ws.protocol import Message, MessageKind, WsConfig
from gql_ws.server import Sockets, WsHandler
from gql_ws_http2.handshake import (
    H2Accepted,
    reject_head,
    response_head,
    server_accept,
)

from gql_ws_http3.handshake import check_connect, to_field_list, to_header_list


struct ServerConfig(Copyable, Movable):
    """The configuration of an HTTP/3 server for WebSockets."""

    var h3: H3Config
    """The address, the UDP port and the request limits. The server sets
    `enable_connect`."""
    var ws: WsConfig
    """The limits of each WebSocket."""
    var path: String
    """The path of the WebSocket endpoint; empty takes every path."""
    var protocols: List[String]
    """The subprotocols that the server supports, by preference."""

    def __init__(out self):
        """Make the defaults: every path, no subprotocol."""
        self.h3 = H3Config()
        self.ws = WsConfig()
        self.path = String()
        self.protocols = List[String]()


@fieldwise_init
struct H3WsTunnel(ImplicitlyCopyable):
    """A WebSocket on an HTTP/3 request stream."""

    var stream: Int
    """The handle of the stream in the `H3Server`."""
    var slot: Int
    """The slot of the WebSocket in `Sockets`."""
    var id: Int
    """The id of the WebSocket in `Sockets`."""


struct Server[W: WsHandler, H: Handler](Movable):
    """An HTTP/3 loop that serves WebSockets and requests.

    Parameters:
        W: The type of the WebSocket handler.
        H: The type of the request handler.
    """

    var handler: Self.W
    """The handler of the WebSockets."""
    var h3: H3Server[Self.H]
    """The QUIC loop, with the request handler."""
    var sockets: Sockets
    """The WebSockets."""
    var config: ServerConfig
    """The configuration."""
    var port: Int
    """The local UDP port."""
    var tunnels: List[H3WsTunnel]
    """The open WebSockets."""
    var _encoder: QpackEncoder
    var _block: List[UInt8]
    var _inserts: List[UInt8]
    var _out: List[UInt8]
    var _events: List[TunnelEvent]
    var _message: Message

    def __init__(
        out self,
        var handler: Self.W,
        var http: Self.H,
        var context: QuicContext,
        config: ServerConfig,
    ) raises TlsError:
        """Open the UDP socket and the QUIC listener.

        Args:
            handler: The handler of the WebSockets.
            http: The handler of the other requests.
            context: A server context from `QuicContext.server`.
            config: The configuration.

        Raises:
            TlsError: The errors of `H3Server`.
        """
        var h3_config = config.h3.copy()
        h3_config.enable_connect = True
        self.handler = handler^
        self.h3 = H3Server(http^, context^, h3_config)
        self.sockets = Sockets(config.ws, 30000)
        self.config = config.copy()
        self.port = self.h3.port
        self.tunnels = List[H3WsTunnel]()
        self._encoder = QpackEncoder()
        self._block = List[UInt8]()
        self._inserts = List[UInt8]()
        self._out = List[UInt8]()
        self._events = List[TunnelEvent]()
        self._message = Message()

    def close(mut self):
        """End each WebSocket at once, and close the QUIC loop."""
        self._close_all()
        self.h3.close()

    def poll(mut self, timeout_ms: Int) raises -> Int:
        """Run one turn: the QUIC loop, the tunnel events, `on_tick`, and
        the output of every WebSocket.

        Args:
            timeout_ms: The longest wait in milliseconds; -1 waits until a
                datagram or a QUIC timer. `wait_ms` of the handler can make
                it shorter.

        Returns:
            1 when a datagram arrived, else 0.

        Raises:
            TlsError: `OS` when `poll` fails; the errors of `on_tick`.
        """
        var wait = timeout_ms
        var limit = self.handler.wait_ms()
        if limit >= 0 and (wait < 0 or limit < wait):
            wait = limit
        var ready = self.h3.poll(wait)
        swap(self._events, self.h3.events)
        var index = 0
        while index < len(self._events):
            self._event(index)
            index += 1
        self._events.clear()
        self.handler.on_tick(self.sockets)
        self.sockets.dirty.clear()
        self.flush()
        return ready

    def _find(self, stream: Int) -> Int:
        """Return the index of the WebSocket of a stream, or -1."""
        var t = 0
        while t < len(self.tunnels):
            if self.tunnels[t].stream == stream:
                return t
            t += 1
        return -1

    def _event(mut self, index: Int):
        """Give one tunnel event to its WebSocket."""
        ref event = self._events[index]
        if event.kind == TunnelEventKind.HEAD:
            self._open(index)
            return
        var t = self._find(event.stream)
        if t < 0:
            # A refused tunnel: its content and its end do not matter.
            return
        var slot = self.tunnels[t].slot
        if event.kind == TunnelEventKind.RESET:
            _ = self.sockets.conns[slot].ws.peer_closed()
            self._finish(t, False)
            return
        if event.kind == TunnelEventKind.DATA:
            self.sockets.conns[slot].ws.receive(Span(event.data))
            self._process(t)
            return
        # The end of the stream is the end of the TCP connection.
        _ = self.sockets.conns[slot].ws.peer_closed()

    def _head(mut self, stream: Int, id: UInt64, fields: HeaderList, fin: Bool):
        """Send a HEADERS frame on a tunnel."""
        self._block.clear()
        self._inserts.clear()
        _ = self._encoder.encode(
            id, to_field_list(fields), self._block, self._inserts
        )
        self._out.clear()
        write_headers_frame(self._out, Span(self._block))
        _ = self.h3.send(stream, Span(self._out), fin)

    def _open(mut self, index: Int):
        """Answer the extended `CONNECT` of an event, and open its
        WebSocket."""
        var stream = self._events[index].stream
        var id = self._events[index].id
        var headers: HeaderList
        try:
            check_connect(self._events[index].fields, True)
            headers = to_header_list(self._events[index].fields)
        except e:
            _ = self.h3.reset(stream, e.code.value)
            return
        var accepted: H2Accepted
        try:
            accepted = server_accept(headers, self.config.protocols)
        except e:
            self._head(stream, id, reject_head(e), True)
            return
        if (
            self.config.path.byte_length() > 0
            and accepted.path != self.config.path
        ):
            self._head(
                stream,
                id,
                reject_head(
                    WsError(WsErrorKind.HANDSHAKE, "Not Found", 0, 404)
                ),
                True,
            )
            return
        self._head(stream, id, response_head(accepted.protocol), False)
        var slot = self.sockets.free_slot()
        var ws_id = self.sockets.attach(slot, accepted.protocol, accepted.path)
        self.tunnels.append(H3WsTunnel(stream, slot, ws_id))
        try:
            self.handler.on_open(self.sockets, ws_id)
        except:
            self.sockets.conns[slot].ws.go_away(CloseCode.ERROR)

    def _process(mut self, t: Int):
        """Read each whole message of a WebSocket, and give it to the
        handler."""
        var slot = self.tunnels[t].slot
        var id = self.tunnels[t].id
        while True:
            var got: Bool
            try:
                got = self.sockets.conns[slot].ws.read(self._message)
            except:
                # The output holds the close frame of the failure.
                break
            if not got:
                break
            var kind = self._message.kind
            if kind == MessageKind.CLOSE:
                self.sockets.conns[slot].code = self._message.code.value
                self.sockets.conns[slot].reason = String(self._message.text())
            elif kind == MessageKind.TEXT or kind == MessageKind.BINARY:
                try:
                    self.handler.on_message(self.sockets, id, self._message)
                except:
                    self.sockets.conns[slot].ws.go_away(CloseCode.ERROR)

    def flush(mut self):
        """Move the output of each WebSocket into DATA frames, and end each
        WebSocket that has closed."""
        var t = 0
        while t < len(self.tunnels):
            if not self._flush(t):
                t += 1

    def _flush(mut self, t: Int) -> Bool:
        """Send the output of one WebSocket; True when it ended."""
        var stream = self.tunnels[t].stream
        var slot = self.tunnels[t].slot
        var total = self.sockets.conns[slot].ws.pending()
        if total > 0 and self.h3.pending(stream) == 0:
            self._out.clear()
            write_data_frame(
                self._out,
                Span(
                    unsafe_ptr=self.sockets.conns[slot].ws.output(),
                    length=total,
                ),
            )
            _ = self.h3.send(stream, Span(self._out), False)
            self.sockets.conns[slot].ws.advance(total)
        if (
            self.sockets.conns[slot].ws.pending() == 0
            and self.sockets.conns[slot].ws.should_close()
        ):
            self._finish(t, True)
            return True
        return False

    def _finish(mut self, t: Int, end: Bool):
        """End a WebSocket: end its stream, free its slot, and tell the
        handler."""
        var tunnel = self.tunnels[t]
        if end:
            _ = self.h3.send(
                tunnel.stream, Span[UInt8, ImmUntrackedOrigin](), True
            )
        var code = self.sockets.conns[tunnel.slot].code
        var reason = self.sockets.conns[tunnel.slot].reason
        self.sockets.detach(tunnel.slot)
        _ = self.tunnels.pop(t)
        self.handler.on_close(self.sockets, tunnel.id, code, reason)

    def _close_all(mut self):
        """End each WebSocket at once, as a close without a handshake."""
        while len(self.tunnels) > 0:
            _ = self.sockets.conns[self.tunnels[0].slot].ws.peer_closed()
            self._finish(0, False)


def listen_ws_h3[
    W: WsHandler, H: Handler
](
    var handler: W,
    var http: H,
    cert_file: String,
    key_file: String,
    config: ServerConfig,
    var quic: Quic,
) raises TlsError -> Server[W, H]:
    """Open an HTTP/3 server for WebSockets on a UDP port.

    Args:
        handler: The handler of the WebSockets.
        http: The handler of the other requests.
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
        W: The type of the WebSocket handler.
        H: The type of the request handler.
    """
    var context = QuicContext.server(quic^, cert_file, key_file)
    return Server(handler^, http^, context^, config)

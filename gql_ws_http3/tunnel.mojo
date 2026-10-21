# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A WebSocket on one HTTP/3 request stream (RFC 9220), without I/O.

`H3Tunnel` joins the `MessageReader` of `gql_http3` and the `WebSocket`
of `gql_ws`. A QUIC driver gives it the bytes of the stream, and sends
`out` on the stream:

- **Client.** `request` writes the HEADERS of the extended `CONNECT`.
  When `has_head` is True, `verify` checks the answer and opens the
  WebSocket.
- **Server.** When `has_head` is True, `accept` checks the request,
  writes the answer, and opens the WebSocket, or refuses it with its
  status.
- **Content.** Each DATA frame carries bytes of the WebSocket. `flush`
  moves the output of the WebSocket into DATA frames.

The end of the stream (FIN) is the end of the TCP connection of RFC 6455,
as RFC 9220 section 3 tells; the driver calls `ws.peer_closed()` then.

This module ports no code. The framing follows RFC 9220 and RFC 9114
section 4.1.

Differences from upstream: none; there is no upstream.
"""

from gql_http3.error import H3Error
from gql_http3.frame import write_data_frame, write_headers_frame
from gql_http3.message import MessageReader
from gql_http3.qpack_decoder import QpackDecoder
from gql_http3.qpack_encoder import QpackEncoder
from gql_http3.qpack_field import FieldList
from gql_ws.error import WsError, WsErrorKind
from gql_ws.protocol import Role, WebSocket, WsConfig
from gql_ws_http2.handshake import (
    H2Accepted,
    client_head,
    reject_head,
    response_head,
    server_accept,
    verify_head,
)

from gql_ws_http3.handshake import check_connect, to_field_list, to_header_list


def _status(fields: FieldList) -> Int:
    """Return the `:status` of a response head, or 0."""
    var index = fields.find(":status")
    if index < 0:
        return 0
    var value = fields.value(index)
    var status = 0
    var at = 0
    while at < len(value):
        var digit = Int(value[at]) - 48
        if digit < 0 or digit > 9:
            return 0
        status = status * 10 + digit
        at += 1
    return status


struct H3Tunnel(Movable):
    """A WebSocket on one HTTP/3 request stream."""

    var ws: WebSocket
    """The protocol state."""
    var reader: MessageReader
    """The frames of the stream."""
    var stream_id: UInt64
    """The QUIC stream."""
    var protocol: String
    """The chosen subprotocol, or empty."""
    var path: String
    """The `:path` of the request, on a server."""
    var status: Int
    """The status of the answer: 200 when the WebSocket opened."""
    var open: Bool
    """Whether the WebSocket is open."""
    var out: List[UInt8]
    """The bytes to send on the stream."""
    var _block: List[UInt8]
    var _inserts: List[UInt8]

    def __init__(
        out self,
        role: Role,
        stream_id: UInt64,
        config: WsConfig = WsConfig(),
        max_body: Int = 1 << 24,
    ):
        """Make a tunnel before its handshake.

        Args:
            role: `Role.CLIENT` or `Role.SERVER`.
            stream_id: The QUIC stream.
            config: The limits of the WebSocket.
            max_body: The most content that waits in `reader`.
        """
        self.ws = WebSocket(role, config)
        self.reader = MessageReader(max_body)
        self.stream_id = stream_id
        self.protocol = String()
        self.path = String()
        self.status = 0
        self.open = False
        self.out = List[UInt8]()
        self._block = List[UInt8]()
        self._inserts = List[UInt8]()

    def _head(mut self, mut encoder: QpackEncoder, fields: FieldList):
        """Write a HEADERS frame."""
        self._block.clear()
        _ = encoder.encode(self.stream_id, fields, self._block, self._inserts)
        write_headers_frame(self.out, Span(self._block))

    def request(
        mut self,
        mut encoder: QpackEncoder,
        scheme: StringSlice,
        authority: StringSlice,
        path: StringSlice,
        protocols: List[String] = [],
    ):
        """Write the HEADERS of the extended `CONNECT`, on a client.

        Args:
            encoder: The QPACK encoder of the connection.
            scheme: `https`, as for any HTTP/3 request.
            authority: The host and the port.
            path: The path and the query.
            protocols: The subprotocols to offer.
        """
        self._head(
            encoder,
            to_field_list(client_head(scheme, authority, path, protocols)),
        )

    def receive(
        mut self, data: Span[UInt8, _], mut decoder: QpackDecoder
    ) raises H3Error:
        """Read bytes of the stream, and give the content to an open
        WebSocket.

        Args:
            data: The bytes, in order.
            decoder: The QPACK decoder of the connection.

        Raises:
            H3Error: The errors of `MessageReader.feed`.
        """
        self.reader.feed(data, self.stream_id, decoder)
        if self.open:
            self._take()

    def _take(mut self):
        """Move the content of the DATA frames into the WebSocket."""
        self.ws.receive(Span(self.reader.body))
        self.reader.body.clear()

    def has_head(self) -> Bool:
        """Return True when the head of the peer arrived.

        Returns:
            Whether the HEADERS frame arrived.
        """
        return self.reader.has_headers

    def verify(mut self, protocols: List[String] = []) raises WsError:
        """Check the answer of the server, and open the WebSocket.

        Args:
            protocols: The subprotocols that the client offered.

        Raises:
            WsError: The errors of `verify_head`: `HANDSHAKE` with the
                status for a refusal.
        """
        self.status = _status(self.reader.fields)
        self.protocol = verify_head(
            self.status, to_header_list(self.reader.fields), protocols
        )
        self.open = True
        self._take()

    def accept(
        mut self,
        mut encoder: QpackEncoder,
        protocols: List[String],
        path: StringSlice = "",
        enabled: Bool = True,
    ) raises H3Error -> Bool:
        """Answer the extended `CONNECT`, on a server, and open the
        WebSocket.

        Args:
            encoder: The QPACK encoder of the connection.
            protocols: The subprotocols, by preference.
            path: The WebSocket path; empty takes every path.
            enabled: Whether the server sent
                `SETTINGS_ENABLE_CONNECT_PROTOCOL = 1`.

        Returns:
            True when the WebSocket opened. False when the server refused
            it: `out` holds the answer, and the driver ends the stream.

        Raises:
            H3Error: The errors of `check_connect`: the driver resets the
                stream with `H3_MESSAGE_ERROR`.
        """
        check_connect(self.reader.fields, enabled)
        var accepted: H2Accepted
        try:
            accepted = server_accept(
                to_header_list(self.reader.fields), protocols
            )
        except e:
            self._refuse(encoder, e)
            return False
        if path.byte_length() > 0 and accepted.path != path:
            self._refuse(
                encoder, WsError(WsErrorKind.HANDSHAKE, "Not Found", 0, 404)
            )
            return False
        self.protocol = accepted.protocol
        self.path = accepted.path
        self.status = 200
        self._head(encoder, to_field_list(response_head(self.protocol)))
        self.open = True
        self._take()
        return True

    def _refuse(mut self, mut encoder: QpackEncoder, error: WsError):
        """Write the answer of a refused WebSocket."""
        self.status = error.status
        self._head(encoder, to_field_list(reject_head(error)))

    def flush(mut self):
        """Move the output of the WebSocket into DATA frames in `out`."""
        var total = self.ws.pending()
        if total > 0:
            write_data_frame(
                self.out, Span(unsafe_ptr=self.ws.output(), length=total)
            )
            self.ws.advance(total)

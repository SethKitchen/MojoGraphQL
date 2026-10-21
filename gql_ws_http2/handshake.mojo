# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The WebSocket handshake over HTTP/2 (RFC 8441 section 4): an extended
`CONNECT` with `:protocol websocket`, and its 2xx answer.

`server_accept` checks the head of a request, and chooses a subprotocol.
`response_head` and `reject_head` make the answer. `client_head` makes the
head of a request, and `verify_head` checks the answer. The same checks
serve HTTP/3 (RFC 9220), which uses the same fields.

RFC 8441 drops `Sec-WebSocket-Key`, `Sec-WebSocket-Accept`, `Upgrade` and
`Connection`: the stream is the connection. `Sec-WebSocket-Version` and
`Sec-WebSocket-Protocol` stay as in RFC 6455.

This module ports no code. The checks follow RFC 8441 section 4 and RFC
6455 section 4, with the error texts of tungstenite 0.30.0 where the two
handshakes agree, as `gql_ws.handshake` has them.

Differences from upstream: none; tungstenite has no HTTP/2 handshake.
"""

from gql_http.scan import equals_ignore_case
from gql_http2.hpack import HeaderList
from gql_ws.error import WsError, WsErrorKind


comptime WEBSOCKET_PROTOCOL = "websocket"
"""The `:protocol` value of a WebSocket (RFC 8441 section 4)."""


@fieldwise_init
struct H2Accepted(Movable):
    """What a server keeps of a valid extended `CONNECT`."""

    var path: String
    """The `:path` of the request."""
    var protocol: String
    """The chosen subprotocol, or empty."""


def _error(status: Int, message: String) -> WsError:
    """Make the error of a refused handshake."""
    return WsError(WsErrorKind.HANDSHAKE, message, 0, status)


def _text(fields: HeaderList, index: Int) -> String:
    """Return the value of a field as text."""
    return String(fields.value_text(index))


def _find(fields: HeaderList, name: StaticString, start: Int = 0) -> Int:
    """Return the index of the first field of a name from `start`, or -1."""
    var index = start
    while index < fields.count():
        if equals_ignore_case(fields.name(index), name.as_bytes()):
            return index
        index += 1
    return -1


def offered_protocols(fields: HeaderList) -> List[String]:
    """Return the subprotocols that a client offers, in its order.

    Args:
        fields: The fields of the request head.

    Returns:
        The tokens of every `sec-websocket-protocol` field.
    """
    var out = List[String]()
    var index = _find(fields, "sec-websocket-protocol")
    while index >= 0:
        var parts = _text(fields, index).split(",")
        var at = 0
        while at < len(parts):
            var name = parts[at].strip()
            if name.byte_length() > 0:
                out.append(String(name))
            at += 1
        index = _find(fields, "sec-websocket-protocol", index + 1)
    return out^


def server_accept(
    fields: HeaderList, protocols: List[String]
) raises WsError -> H2Accepted:
    """Check the head of an extended `CONNECT`, and choose a subprotocol.

    The connection checked the pseudo-header fields already (RFC 9113
    section 8.3.1): an extended `CONNECT` has `:scheme`, `:path` and
    `:authority`.

    Args:
        fields: The fields of the request head.
        protocols: The subprotocols that the server supports, by
            preference of the client.

    Returns:
        The path and the subprotocol.

    Raises:
        WsError: `HANDSHAKE` with the status of the answer: 405 for another
            method, 400 for another `:protocol`, and 426 without
            `sec-websocket-version: 13`.
    """
    var method = _find(fields, ":method")
    if method < 0 or _text(fields, method) != "CONNECT":
        raise _error(405, "Unsupported HTTP method used - only CONNECT")
    var protocol = _find(fields, ":protocol")
    if protocol < 0 or not equals_ignore_case(
        fields.value(protocol), StaticString(WEBSOCKET_PROTOCOL).as_bytes()
    ):
        raise _error(400, 'No ":protocol: websocket" pseudo-header')
    var version = _find(fields, "sec-websocket-version")
    if version < 0 or _text(fields, version) != "13":
        raise _error(426, 'No "Sec-WebSocket-Version: 13" header')
    var path = _find(fields, ":path")
    var chosen = String()
    var offered = offered_protocols(fields)
    var at = 0
    while at < len(offered) and chosen.byte_length() == 0:
        if offered[at] in protocols:
            chosen = offered[at]
        at += 1
    return H2Accepted(_text(fields, path) if path >= 0 else String(), chosen^)


def response_head(protocol: StringSlice) -> HeaderList:
    """Make the answer to a valid handshake: `200`, and the subprotocol.

    Args:
        protocol: The chosen subprotocol, or empty.

    Returns:
        The fields of the response head.
    """
    var fields = HeaderList()
    fields.add_text(":status", "200")
    if protocol.byte_length() > 0:
        fields.add_text("sec-websocket-protocol", protocol)
    return fields^


def reject_head(error: WsError) -> HeaderList:
    """Make the answer to a refused handshake. A 426 names the version.

    Args:
        error: The error of `server_accept`.

    Returns:
        The fields of the response head.
    """
    var fields = HeaderList()
    var status = error.status if error.status >= 400 else 400
    fields.add_text(":status", String(status))
    if status == 426:
        fields.add_text("sec-websocket-version", "13")
    return fields^


def client_head(
    scheme: StringSlice,
    authority: StringSlice,
    path: StringSlice,
    protocols: List[String],
) -> HeaderList:
    """Make the head of an extended `CONNECT` for a WebSocket.

    Args:
        scheme: `http` or `https`.
        authority: The host and the port.
        path: The path and the query.
        protocols: The subprotocols to offer, or none.

    Returns:
        The fields of the request head.
    """
    var fields = HeaderList()
    fields.add_text(":method", "CONNECT")
    fields.add_text(":protocol", WEBSOCKET_PROTOCOL)
    fields.add_text(":scheme", scheme)
    fields.add_text(":authority", authority)
    fields.add_text(":path", path)
    fields.add_text("sec-websocket-version", "13")
    if len(protocols) > 0:
        var joined = String()
        var at = 0
        while at < len(protocols):
            if at > 0:
                joined += ", "
            joined += protocols[at]
            at += 1
        fields.add_text("sec-websocket-protocol", joined)
    return fields^


def verify_head(
    status: Int, fields: HeaderList, protocols: List[String]
) raises WsError -> String:
    """Check the answer of a server, as tungstenite checks the subprotocol.

    Args:
        status: The `:status` of the answer.
        fields: The fields of the answer.
        protocols: The subprotocols that the client offered.

    Returns:
        The subprotocol of the server, or empty.

    Raises:
        WsError: `HANDSHAKE` with the status for an answer that is not 2xx,
            and for a subprotocol that the client did not offer.
    """
    if status < 200 or status >= 300:
        raise _error(status, "HTTP error: " + String(status))
    var index = _find(fields, "sec-websocket-protocol")
    if index < 0:
        if len(protocols) > 0:
            raise _error(
                status, "SubProtocol error: Server sent no subprotocol"
            )
        return String()
    var protocol = _text(fields, index)
    if len(protocols) == 0:
        raise _error(
            status,
            (
                "SubProtocol error: Server sent a subprotocol but none was"
                " requested"
            ),
        )
    if not protocol in protocols:
        raise _error(
            status, "SubProtocol error: Server sent an invalid subprotocol"
        )
    return protocol^

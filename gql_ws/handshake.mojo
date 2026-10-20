# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The opening handshake (RFC 6455 section 4): the HTTP/1.1 Upgrade
request of a client, and the `101 Switching Protocols` answer of a server.

A server reads the request with the parser of gql_http, and
`server_response` checks it and makes the answer, with
`Sec-WebSocket-Accept` and the chosen subprotocol. `reject_response`
makes the error answer. A client makes its request with `client_request`
and checks the answer with `verify_response`.

This module ports tungstenite 0.30.0 `src/handshake/mod.rs`
(`derive_accept_key`), `src/handshake/server.rs` (`create_parts`,
`is_valid_sec_websocket_key`, `write_response`) and
`src/handshake/client.rs` (`generate_request`, `generate_key`,
`VerifyData::verify_response`), with their tests.

Differences from upstream:

- **Error answers.** tungstenite returns the error and its caller writes
  the answer. Here `reject_response` writes it, as the Node `ws` server
  does: 405 for a method that is not `GET`, 426 with
  `Sec-WebSocket-Version: 13` for another version (RFC 6455 section 4.4),
  and 400 for the rest. The content is the upstream error text.
- **Subprotocols.** The server chooses the first protocol of the client
  that it supports, as the default `handleProtocols` of `ws`. tungstenite
  leaves the choice to a callback.
- **Connection.** The client accepts a `Connection` value that holds the
  token `Upgrade` (RFC 6455 section 4.1). tungstenite wants the value to
  be `Upgrade`.
- **Bytes after the request** are the first frames of the client, as in
  `ws`. tungstenite refuses them with `JunkAfterRequest`.
"""

from std.random import random_ui64

from gql_http.parser import Request, ResponseHead
from gql_http.scan import equals_ignore_case
from gql_http.status import Method, Status, Version

from gql_ws.error import WsError, WsErrorKind
from gql_ws.sha1 import base64_encode, base64_value, sha1

comptime WS_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
"""The GUID of RFC 6455 section 1.3, appended to the key."""


def accept_key(key: StringSlice) -> String:
    """Return the `Sec-WebSocket-Accept` value for a key, as tungstenite
    `derive_accept_key`.

    Args:
        key: The `Sec-WebSocket-Key` value.

    Returns:
        The base64 of the SHA-1 of the key and the GUID.
    """
    var data = List[UInt8](capacity=key.byte_length() + 36)
    data.extend(key.as_bytes())
    data.extend(StaticString(WS_GUID).as_bytes())
    var digest = sha1(data)
    return base64_encode(Span(digest))


def is_valid_key(key: StringSlice) -> Bool:
    """Return True for a key that is the base64 of 16 bytes, as tungstenite
    `is_valid_sec_websocket_key`.

    Args:
        key: The `Sec-WebSocket-Key` value.

    Returns:
        Whether the key has 24 characters, with `==` padding and no bits
        after the 128 bits.
    """
    var bytes = key.as_bytes()
    if len(bytes) != 24 or bytes[22] != 61 or bytes[23] != 61:
        return False
    var index = 0
    while index < 22:
        if base64_value(bytes[index]) < 0:
            return False
        index += 1
    # The last character holds 2 bits of the key and 4 zero bits.
    return base64_value(bytes[21]) & 15 == 0


def generate_key() -> String:
    """Return a new random key, as tungstenite `generate_key`.

    Returns:
        The base64 of 16 random bytes.
    """
    var data = List[UInt8](capacity=16)
    var high = random_ui64(0, UInt64.MAX)
    var low = random_ui64(0, UInt64.MAX)
    var index = 0
    while index < 8:
        data.append(UInt8((high >> UInt64(index * 8)) & 0xFF))
        index += 1
    index = 0
    while index < 8:
        data.append(UInt8((low >> UInt64(index * 8)) & 0xFF))
        index += 1
    return base64_encode(data)


def has_token(value: StringSlice, token: StringSlice) -> Bool:
    """Return True when a field value holds a token, with ASCII case
    folded. Spaces and commas separate the tokens.

    Args:
        value: The field value.
        token: The token.

    Returns:
        Whether one of the parts is the token.
    """
    var bytes = value.as_bytes()
    var want = token.as_bytes()
    var start = 0
    var index = 0
    while index <= len(bytes):
        if index == len(bytes) or bytes[index] == 32 or bytes[index] == 44:
            if equals_ignore_case(bytes[start:index], want):
                return True
            start = index + 1
        index += 1
    return False


def is_upgrade(request: Request) -> Bool:
    """Return True for a request that asks for a WebSocket: its `Upgrade`
    field is `websocket`.

    Args:
        request: The request.

    Returns:
        Whether the server should answer it with `server_response`.
    """
    var upgrade = request.header("upgrade")
    if not upgrade:
        return False
    return equals_ignore_case(
        upgrade.value().as_bytes(), StaticString("websocket").as_bytes()
    )


def _handshake_error(status: Int, message: String) -> WsError:
    """Make the error of a refused handshake."""
    return WsError(WsErrorKind.HANDSHAKE, message, 0, status)


def offered_protocols(request: Request) -> List[String]:
    """Return the subprotocols that a client offers, in its order.

    Args:
        request: The request.

    Returns:
        The tokens of every `Sec-WebSocket-Protocol` field.
    """
    var out = List[String]()
    var index = request.find_header("sec-websocket-protocol")
    while index >= 0:
        var value = request.header_value(index)
        var parts = value.split(",")
        var at = 0
        while at < len(parts):
            var name = parts[at].strip()
            if name.byte_length() > 0:
                out.append(String(name))
            at += 1
        index = request.find_header("sec-websocket-protocol", index + 1)
    return out^


@fieldwise_init
struct Accepted(Movable):
    """The answer of a server to a valid handshake."""

    var response: List[UInt8]
    """The bytes of the `101` response."""
    var protocol: String
    """The chosen subprotocol, or empty."""


def server_response(
    request: Request, protocols: List[String]
) raises WsError -> Accepted:
    """Check an Upgrade request and make the `101` answer, as tungstenite
    `create_parts` and `write_response`.

    Args:
        request: The request.
        protocols: The subprotocols that the server supports.

    Returns:
        The answer, and the subprotocol that it chose.

    Raises:
        WsError: `HANDSHAKE` with the status of the answer, for a request
            that is not a valid WebSocket handshake.
    """
    if request.method != Method.GET:
        raise _handshake_error(
            405, "Unsupported HTTP method used - only GET is allowed"
        )
    if request.version != Version.HTTP_1_1:
        raise _handshake_error(400, "HTTP version must be 1.1 or higher")
    var connection = request.header("connection")
    if not connection or not has_token(connection.value(), "upgrade"):
        raise _handshake_error(400, 'No "Connection: upgrade" header')
    if not is_upgrade(request):
        raise _handshake_error(400, 'No "Upgrade: websocket" header')
    var version = request.header("sec-websocket-version")
    if not version or version.value() != StaticString("13"):
        raise _handshake_error(426, 'No "Sec-WebSocket-Version: 13" header')
    var key = request.header("sec-websocket-key")
    if not key:
        raise _handshake_error(400, 'No "Sec-WebSocket-Key" header')
    if not is_valid_key(key.value()):
        raise _handshake_error(400, 'Invalid "Sec-WebSocket-Key" header value')
    var chosen = String()
    var offered = offered_protocols(request)
    for name in offered:
        if chosen.byte_length() == 0 and name in protocols:
            chosen = name
    var out = List[UInt8](capacity=160)
    out.extend(
        StaticString(
            "HTTP/1.1 101 Switching Protocols\r\nConnection: Upgrade\r\n"
            "Upgrade: websocket\r\nSec-WebSocket-Accept: "
        ).as_bytes()
    )
    out.extend(accept_key(key.value()).as_bytes())
    if chosen.byte_length() > 0:
        out.extend(StaticString("\r\nSec-WebSocket-Protocol: ").as_bytes())
        out.extend(chosen.as_bytes())
    out.extend(StaticString("\r\n\r\n").as_bytes())
    return Accepted(out^, chosen^)


def reject_response(error: WsError) -> List[UInt8]:
    """Make the answer to a refused handshake: its status, the error text
    as content, and `Connection: close`.

    Args:
        error: A `HANDSHAKE` error of `server_response`.

    Returns:
        The bytes of the response.
    """
    var status = Status(error.status)
    var reason = String(status.reason())
    if error.status == 426:
        reason = "Upgrade Required"
    var out = List[UInt8]()
    var head = (
        "HTTP/1.1 "
        + String(error.status)
        + " "
        + reason
        + "\r\nConnection: close\r\nContent-Type: text/plain\r\n"
    )
    if error.status == 426:
        head += "Sec-WebSocket-Version: 13\r\n"
    head += "Content-Length: " + String(error.message.byte_length())
    head += "\r\n\r\n"
    out.extend(head.as_bytes())
    out.extend(error.message.as_bytes())
    return out^


def client_request(
    host: StringSlice,
    target: StringSlice,
    key: StringSlice,
    protocols: List[String],
    extra: StringSlice = "",
) -> List[UInt8]:
    """Make the Upgrade request of a client, as tungstenite
    `generate_request`.

    Args:
        host: The `Host` value, such as `localhost:4000`.
        target: The path and query, such as `/graphql`.
        key: The `Sec-WebSocket-Key` value, from `generate_key`.
        protocols: The subprotocols to offer; empty offers none.
        extra: More header lines, each with its CRLF.

    Returns:
        The bytes of the request.
    """
    var text = (
        "GET "
        + String(target)
        + " HTTP/1.1\r\nHost: "
        + String(host)
        + "\r\nConnection: Upgrade\r\nUpgrade: websocket\r\n"
        "Sec-WebSocket-Version: 13\r\nSec-WebSocket-Key: "
        + String(key)
        + "\r\n"
    )
    if len(protocols) > 0:
        text += "Sec-WebSocket-Protocol: " + ", ".join(protocols) + "\r\n"
    text += String(extra) + "\r\n"
    return List[UInt8](text.as_bytes())


def _response_header(
    data: Pointer[UInt8, _], head: ResponseHead, name: StringSlice
) -> Optional[String]:
    """Return the value of the first field of a response with a name."""
    var want = name.as_bytes()
    var index = 0
    while index < len(head.fields):
        var field = head.fields[index]
        var field_name = Span[UInt8, ImmUntrackedOrigin](
            unsafe_ptr=Pointer[UInt8, ImmUntrackedOrigin](
                unsafe_from_address=Int(data) + Int(field.name_start)
            ),
            length=Int(field.name_end - field.name_start),
        )
        if equals_ignore_case(field_name, want):
            var value = Span[UInt8, ImmUntrackedOrigin](
                unsafe_ptr=Pointer[UInt8, ImmUntrackedOrigin](
                    unsafe_from_address=Int(data) + Int(field.value_start)
                ),
                length=Int(field.value_end - field.value_start),
            )
            return String(StringSlice(unsafe_from_utf8=value))
        index += 1
    return None


def verify_response(
    data: Pointer[UInt8, _],
    head: ResponseHead,
    key: StringSlice,
    protocols: List[String],
) raises WsError -> String:
    """Check the answer of a server, as tungstenite
    `VerifyData::verify_response`.

    Args:
        data: The bytes of the response head.
        head: The parsed head.
        key: The key that the client sent.
        protocols: The subprotocols that the client offered.

    Returns:
        The subprotocol of the server, or empty.

    Raises:
        WsError: `HANDSHAKE` with the status for an answer that is not
            `101`, and for an answer that breaks RFC 6455 section 4.1.
    """
    if head.status != Status.SWITCHING_PROTOCOLS:
        raise _handshake_error(
            Int(head.status.code),
            "HTTP error: " + String(head.status.code),
        )
    var upgrade = _response_header(data, head, "upgrade")
    if not upgrade or not equals_ignore_case(
        upgrade.value().as_bytes(), StaticString("websocket").as_bytes()
    ):
        raise _handshake_error(101, 'No "Upgrade: websocket" header')
    var connection = _response_header(data, head, "connection")
    if not connection or not has_token(connection.value(), "upgrade"):
        raise _handshake_error(101, 'No "Connection: upgrade" header')
    var accept = _response_header(data, head, "sec-websocket-accept")
    if not accept or accept.value() != accept_key(key):
        raise _handshake_error(
            101, 'Key mismatch in "Sec-WebSocket-Accept" header'
        )
    var protocol = _response_header(data, head, "sec-websocket-protocol")
    if not protocol:
        if len(protocols) > 0:
            raise _handshake_error(
                101, "SubProtocol error: Server sent no subprotocol"
            )
        return String()
    if len(protocols) == 0:
        raise _handshake_error(
            101,
            (
                "SubProtocol error: Server sent a subprotocol but none was"
                " requested"
            ),
        )
    if not protocol.value() in protocols:
        raise _handshake_error(
            101, "SubProtocol error: Server sent an invalid subprotocol"
        )
    return protocol.value()

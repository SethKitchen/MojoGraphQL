# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_ws.handshake`.

Ported from tungstenite 0.30.0 `src/handshake/mod.rs` (`key_conversion`),
`src/handshake/server.rs` (`request_replying`, the
`test_invalid_websocket_key_*` cases), `src/handshake/client.rs`
(`random_keys`, `request_formatting`, `request_formatting_with_host`,
`response_parsing`) and `tests/handshake.rs`.
"""

from gql_http.parser import (
    Limits,
    ParseState,
    Request,
    ResponseHead,
    RequestReader,
    parse_response_head,
)
from gql_ws.error import WsError, WsErrorKind
from gql_ws.handshake import (
    accept_key,
    client_request,
    generate_key,
    has_token,
    is_upgrade,
    is_valid_key,
    offered_protocols,
    reject_response,
    server_response,
    verify_response,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime KEY = "dGhlIHNhbXBsZSBub25jZQ=="
comptime ACCEPT = "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="


def request_text(
    key: StringSlice = KEY,
    extra: StringSlice = "",
    method: StringSlice = "GET",
    version: StringSlice = "HTTP/1.1",
    connection: StringSlice = "Connection: upgrade\r\n",
    upgrade: StringSlice = "Upgrade: websocket\r\n",
    ws_version: StringSlice = "Sec-WebSocket-Version: 13\r\n",
) -> String:
    var text = String(method) + " /script.ws " + String(version)
    text += "\r\nHost: foo.com\r\n" + String(connection) + String(upgrade)
    text += String(ws_version)
    if key.byte_length() > 0:
        text += "Sec-WebSocket-Key: " + String(key) + "\r\n"
    return text + String(extra) + "\r\n"


struct Parsed(Movable):
    var reader: RequestReader

    def __init__(out self, text: String) raises:
        self.reader = RequestReader(Limits())
        self.reader.append(text.as_bytes())
        if self.reader.next().state != ParseState.COMPLETE:
            raise Error("bad request text")

    def request(ref self) -> ref[self.reader.request] Request:
        return self.reader.request


def status_of(text: String, protocols: List[String] = []) raises -> Int:
    var parsed = Parsed(text)
    try:
        _ = server_response(parsed.request(), protocols)
    except e:
        assert_true(e.kind == WsErrorKind.HANDSHAKE)
        return e.status
    return 101


def test_key_conversion() raises:
    # The example of RFC 6455.
    assert_equal(accept_key(KEY), ACCEPT)


def test_request_replying() raises:
    var parsed = Parsed(request_text())
    assert_true(is_upgrade(parsed.request()))
    var accepted = server_response(parsed.request(), [])
    var text = String(unsafe_from_utf8=accepted.response)
    assert_true(text.startswith("HTTP/1.1 101 Switching Protocols\r\n"))
    assert_true("Sec-WebSocket-Accept: " + ACCEPT + "\r\n" in text)
    assert_true(text.endswith("\r\n\r\n"))
    assert_false("Sec-WebSocket-Protocol" in text)
    assert_equal(accepted.protocol, "")


def test_invalid_keys() raises:
    # tungstenite `test_invalid_websocket_key_*`.
    assert_false(is_valid_key(""))
    assert_false(is_valid_key("dGhlIHNhbXBsZSBub25jZQ==AAAAAAAAAA"))
    assert_false(is_valid_key("dGhlIHNhbXBsZSBub25jZQ!!"))
    assert_false(is_valid_key("AAAAAAAAAAAAAAAAAAAAAAAA"))
    assert_false(is_valid_key("AAAAAAAAAAAAAAAAAAAAAA=A"))
    assert_false(is_valid_key("dGhlIHNhbXBsZSBu!25jZQ=="))
    # Bits after the 128 bits of the key.
    assert_false(is_valid_key("dGhlIHNhbXBsZSBub25jZR=="))
    assert_true(is_valid_key(KEY))
    assert_equal(status_of(request_text("AAAAAAAAAAAAAAAAAAAAAAAA")), 400)


def test_refusals() raises:
    assert_equal(status_of(request_text(method="POST")), 405)
    assert_equal(status_of(request_text(version="HTTP/1.0")), 400)
    assert_equal(status_of(request_text(connection="")), 400)
    assert_equal(
        status_of(request_text(connection="Connection: keep-alive\r\n")), 400
    )
    assert_equal(status_of(request_text(upgrade="")), 400)
    assert_equal(status_of(request_text(upgrade="Upgrade: h2c\r\n")), 400)
    assert_equal(status_of(request_text(ws_version="")), 426)
    assert_equal(
        status_of(request_text(ws_version="Sec-WebSocket-Version: 8\r\n")),
        426,
    )
    assert_equal(status_of(request_text("")), 400)
    # Tokens of Connection, as Firefox sends them.
    assert_equal(
        status_of(
            request_text(connection="Connection: keep-alive, Upgrade\r\n")
        ),
        101,
    )
    var plain = Parsed(request_text(upgrade=""))
    assert_false(is_upgrade(plain.request()))


def test_subprotocols() raises:
    var text = request_text(
        extra=(
            "Sec-WebSocket-Protocol: chat, graphql-transport-ws\r\n"
            "Sec-WebSocket-Protocol: other\r\n"
        )
    )
    var parsed = Parsed(text)
    var offered = offered_protocols(parsed.request())
    assert_equal(len(offered), 3)
    assert_equal(offered[2], "other")
    var accepted = server_response(
        parsed.request(), ["other", "graphql-transport-ws"]
    )
    assert_equal(accepted.protocol, "graphql-transport-ws")
    var answer = String(unsafe_from_utf8=accepted.response)
    assert_true(
        "\r\nSec-WebSocket-Protocol: graphql-transport-ws\r\n" in answer
    )
    var none = server_response(parsed.request(), ["mqtt"])
    assert_equal(none.protocol, "")
    var empty = Parsed(request_text(extra="Sec-WebSocket-Protocol: ,\r\n"))
    assert_equal(len(offered_protocols(empty.request())), 0)


def test_has_token() raises:
    assert_true(has_token("Upgrade", "upgrade"))
    assert_true(has_token("keep-alive, Upgrade", "upgrade"))
    assert_true(has_token("keep-alive,upgrade", "UPGRADE"))
    assert_false(has_token("keep-alive", "upgrade"))
    assert_false(has_token("", "upgrade"))


def test_reject_response() raises:
    var e = WsError(WsErrorKind.HANDSHAKE, "No body", 0, 400)
    var text = String(unsafe_from_utf8=reject_response(e))
    assert_true(text.startswith("HTTP/1.1 400 Bad Request\r\n"), text)
    assert_true("Connection: close\r\n" in text)
    assert_true(text.endswith("Content-Length: 7\r\n\r\nNo body"))
    assert_false("Sec-WebSocket-Version" in text)
    var v = WsError(WsErrorKind.HANDSHAKE, "x", 0, 426)
    var upgrade = String(unsafe_from_utf8=reject_response(v))
    assert_true(upgrade.startswith("HTTP/1.1 426 Upgrade Required\r\n"))
    assert_true("Sec-WebSocket-Version: 13\r\n" in upgrade)


def test_random_keys() raises:
    # tungstenite `random_keys`: valid and different.
    var k1 = generate_key()
    var k2 = generate_key()
    assert_true(is_valid_key(k1))
    assert_true(is_valid_key(k2))
    assert_true(k1 != k2)


def test_request_formatting() raises:
    var data = client_request("localhost:4000", "/getCaseCount", KEY, [])
    var text = String(unsafe_from_utf8=data)
    assert_equal(
        text,
        (
            "GET /getCaseCount HTTP/1.1\r\nHost: localhost:4000\r\nConnection:"
            " Upgrade\r\nUpgrade: websocket\r\nSec-WebSocket-Version:"
            " 13\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\r\n"
        ),
    )
    var with_protocols = client_request(
        "h", "/", KEY, ["graphql-transport-ws", "x"], "Origin: o\r\n"
    )
    var other = String(unsafe_from_utf8=with_protocols)
    assert_true(
        other.endswith(
            "Sec-WebSocket-Protocol: graphql-transport-ws, x\r\nOrigin:"
            " o\r\n\r\n"
        )
    )
    # A server reads the request of the client.
    var parsed = Parsed(text)
    assert_equal(status_of(text), 101)
    _ = parsed^


struct Answer(Movable):
    var data: List[UInt8]
    var head: ResponseHead

    def __init__(out self, text: String) raises:
        self.data = List[UInt8](text.as_bytes())
        self.head = ResponseHead()
        var result = parse_response_head(
            self.data.unsafe_ptr(), len(self.data), Limits(), self.head
        )
        if result.state != ParseState.COMPLETE:
            raise Error("bad response text")


def verify(text: String, protocols: List[String] = []) -> String:
    """The protocol, or the error text."""
    try:
        var answer = Answer(text)
        try:
            return verify_response(
                answer.data.unsafe_ptr(), answer.head, KEY, protocols
            )
        except e:
            return "error " + String(e.status) + ": " + e.message
    except:
        return "unparsed"


def good(extra: StringSlice = "") -> String:
    return (
        "HTTP/1.1 101 Switching Protocols\r\nConnection: Upgrade\r\nUpgrade:"
        " websocket\r\nSec-WebSocket-Accept: "
        + ACCEPT
        + "\r\n"
        + String(extra)
        + "\r\n"
    )


def test_response_parsing() raises:
    assert_equal(verify(good()), "")
    assert_equal(
        verify(
            good("Sec-WebSocket-Protocol: graphql-transport-ws\r\n"),
            ["graphql-transport-ws"],
        ),
        "graphql-transport-ws",
    )


def test_response_errors() raises:
    assert_equal(
        verify("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n"),
        "error 404: HTTP error: 404",
    )
    assert_true(
        verify(
            "HTTP/1.1 101 Switching Protocols\r\nConnection: Upgrade\r\n\r\n"
        ).endswith('No "Upgrade: websocket" header')
    )
    assert_true(
        verify(
            "HTTP/1.1 101 Switching Protocols\r\nUpgrade: h2c\r\n\r\n"
        ).endswith('No "Upgrade: websocket" header')
    )
    assert_true(
        verify(
            "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\n\r\n"
        ).endswith('No "Connection: upgrade" header')
    )
    assert_true(
        verify(
            "HTTP/1.1 101 Switching Protocols\r\nUpgrade:"
            " websocket\r\nConnection: close\r\n\r\n"
        ).endswith('No "Connection: upgrade" header')
    )
    assert_true(
        verify(
            "HTTP/1.1 101 Switching Protocols\r\nUpgrade:"
            " websocket\r\nConnection: Upgrade\r\n\r\n"
        ).endswith('Key mismatch in "Sec-WebSocket-Accept" header')
    )
    assert_true(
        verify(
            "HTTP/1.1 101 Switching Protocols\r\nUpgrade:"
            " websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept:"
            " AAAA\r\n\r\n"
        ).endswith('Key mismatch in "Sec-WebSocket-Accept" header')
    )
    assert_true(verify(good(), ["a"]).endswith("Server sent no subprotocol"))
    assert_true(
        verify(good("Sec-WebSocket-Protocol: a\r\n")).endswith(
            "none was requested"
        )
    )
    assert_true(
        verify(good("Sec-WebSocket-Protocol: b\r\n"), ["a"]).endswith(
            "invalid subprotocol"
        )
    )
    assert_equal(verify("HTTP/1.1 101"), "unparsed")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

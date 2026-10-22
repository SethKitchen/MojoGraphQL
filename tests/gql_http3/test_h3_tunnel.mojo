# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of the tunnels of the extended `CONNECT` (RFC 9220) in
`H3Server`, over real QUIC on the loopback address.

The cases follow hyperium/h3 h3-v0.0.8: `enable_extended_connect` of
h3/src/server/builder.rs and h3/src/config.rs sends the setting, and
h3/src/server/request.rs gives a request with `:protocol` to the
application with the `Protocol` extension, with its stream open.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _certs import test_certs
from _h3 import Echo, RawClient, config, request_bytes
from gql_tls.openssl import OpenSsl
from gql_http3.error import H3ErrorCode
from gql_http3.frame import SettingId, write_data_frame, write_headers_frame
from gql_http3.qpack_encoder import QpackEncoder
from gql_http3.qpack_field import FieldList
from gql_http3.quic import Quic, QuicCall, QuicFaults, ReadState
from gql_http3.server import (
    ControlReader,
    H3Server,
    TunnelEventKind,
    control_preface,
    listen_h3,
)


def tunnel_server(max_body: Int = 1 << 20) raises -> H3Server[Echo]:
    var c = config()
    c.enable_connect = True
    c.limits.max_body_bytes = max_body
    var certs = test_certs()
    return listen_h3(Echo(), certs.cert, certs.key, c, Quic(OpenSsl()))


def head_bytes(
    method: StaticString = "CONNECT", protocol: StaticString = "websocket"
) -> List[UInt8]:
    var fields = FieldList()
    if method.byte_length() > 0:
        fields.add_text(":method", method)
    if protocol.byte_length() > 0:
        fields.add_text(":protocol", protocol)
    fields.add_text(":scheme", "https")
    fields.add_text(":authority", "localhost")
    fields.add_text(":path", "/ws")
    var encoder = QpackEncoder()
    var block = List[UInt8]()
    var inserts = List[UInt8]()
    _ = encoder.encode(0, fields, block, inserts)
    var out = List[UInt8]()
    write_headers_frame(out, Span(block))
    return out^


def data_bytes(text: StaticString) -> List[UInt8]:
    var out = List[UInt8]()
    write_data_frame(out, text.as_bytes())
    return out^


def read_some(
    mut client: RawClient, mut server: H3Server[Echo], stream: Int, want: Int
) raises -> Tuple[Int, ReadState]:
    """Read a stream until `want` bytes, its end, or 200 turns."""
    var got = 0
    var turns = 0
    while turns < 200:
        var result = client.quic.read(
            stream, client.buffer.unsafe_ptr(), len(client.buffer)
        )
        if result.state == ReadState.DATA:
            got += result.count
            if got >= want:
                return (got, ReadState.DATA)
            continue
        if result.state != ReadState.WAIT:
            return (got, result.state)
        client.pump(server, 1)
        turns += 1
    return (got, ReadState.WAIT)


def test_settings() raises:
    var reader = ControlReader()
    var on = control_preface(config().limits, True)
    reader.feed(Span(on)[1:])
    assert_equal(
        reader.settings.get_or(SettingId.ENABLE_CONNECT_PROTOCOL, 0), UInt64(1)
    )
    var other = ControlReader()
    var off = control_preface(config().limits)
    other.feed(Span(off)[1:])
    assert_equal(
        other.settings.get_or(SettingId.ENABLE_CONNECT_PROTOCOL, 0), UInt64(0)
    )


def test_head_data_and_end() raises:
    var server = tunnel_server()
    var client = RawClient(server)
    var stream = client.open(False)
    var request = head_bytes()
    request.extend(data_bytes("hello"))
    client.send(stream, request, False)
    client.pump(server, 4)
    assert_equal(len(server.events), 2)
    assert_equal(server.events[0].kind, TunnelEventKind.HEAD)
    var protocol = server.events[0].fields.find(":protocol")
    assert_equal(server.events[0].fields.value_text(protocol), "websocket")
    assert_equal(server.events[1].kind, TunnelEventKind.DATA)
    assert_equal(String(unsafe_from_utf8=server.events[1].data), "hello")
    var handle = server.events[0].stream
    assert_equal(server.events[0].id, client.quic.stream_id(stream))
    server.events.clear()
    # The answer goes out, and the stream stays open.
    assert_true(server.send(handle, Span(data_bytes("world")), False))
    assert_equal(server.pending(handle), 0)
    var got = read_some(client, server, stream, 7)
    assert_equal(got[0], 7)
    # More content from the client, then its end.
    client.send(stream, data_bytes("again"), True)
    client.pump(server, 4)
    assert_equal(len(server.events), 2)
    assert_equal(server.events[0].kind, TunnelEventKind.DATA)
    assert_equal(server.events[1].kind, TunnelEventKind.END)
    server.events.clear()
    # The server ends its side; the stream then leaves the server.
    assert_true(server.send(handle, Span[UInt8, ImmUntrackedOrigin](), True))
    assert_false(server.send(handle, Span(data_bytes("late")), False))
    var end = read_some(client, server, stream, 1)
    assert_equal(end[1], ReadState.END)
    client.pump(server, 2)
    assert_false(server.send(handle, Span(data_bytes("gone")), False))
    assert_equal(server.pending(handle), 0)
    assert_false(server.reset(handle, 0))


def test_head_in_parts_and_plain_requests() raises:
    var server = tunnel_server()
    var client = RawClient(server)
    # The HEADERS of a tunnel arrive in two parts.
    var stream = client.open(False)
    var head = head_bytes()
    client.send(stream, List[UInt8](Span(head)[0:2]), False)
    client.pump(server, 3)
    assert_equal(len(server.events), 0)
    client.send(stream, List[UInt8](Span(head)[2:]), False)
    client.pump(server, 3)
    assert_equal(len(server.events), 1)
    server.events.clear()
    # A request whose content comes after its head is not a tunnel.
    var post = client.open(False)
    var request = request_bytes("/echo", "abc")
    client.send(post, List[UInt8](Span(request)[0:8]), False)
    client.pump(server, 3)
    client.send(post, List[UInt8](Span(request)[8:]), True)
    var answer = client.receive(server, post)
    assert_equal(answer[1], ReadState.END)
    # The whole head of a request, then its content in a later read.
    var late = client.open(False)
    var parts = request_bytes("/echo", "abc")
    var cut = len(parts) - 5
    client.send(late, List[UInt8](Span(parts)[0:cut]), False)
    client.pump(server, 3)
    # A request stream is not a tunnel: send refuses its handle.
    var last = len(server._conns[0].streams) - 1
    var handle = server._conns[0].streams[last].ssl
    assert_false(server.send(handle, List[UInt8](), False))
    client.send(late, List[UInt8](Span(parts)[cut:]), True)
    var reply = client.receive(server, late)
    assert_equal(reply[1], ReadState.END)
    assert_equal(len(server.events), 0)


def test_not_a_tunnel() raises:
    var server = tunnel_server()
    var client = RawClient(server)
    # CONNECT without :protocol, and :protocol with another method, are
    # requests; the rules of whole requests refuse them.
    var plain = client.open(False)
    client.send(plain, head_bytes("CONNECT", ""), True)
    var first = client.receive(server, plain)
    assert_equal(first[1], ReadState.RESET)
    var get = client.open(False)
    client.send(get, head_bytes("GET"), True)
    var second = client.receive(server, get)
    assert_equal(second[1], ReadState.RESET)
    # :protocol without :method.
    var bare = client.open(False)
    client.send(bare, head_bytes(""), True)
    var third = client.receive(server, bare)
    assert_equal(third[1], ReadState.RESET)
    assert_equal(len(server.events), 0)


def test_disabled() raises:
    var certs = test_certs()
    var server = listen_h3(
        Echo(), certs.cert, certs.key, config(), Quic(OpenSsl())
    )
    var client = RawClient(server)
    var stream = client.open(False)
    client.send(stream, head_bytes(), True)
    var got = client.receive(server, stream)
    assert_equal(got[1], ReadState.RESET)
    assert_equal(len(server.events), 0)


def test_peer_reset() raises:
    var server = tunnel_server()
    var client = RawClient(server)
    var stream = client.open(False)
    client.send(stream, head_bytes(), False)
    client.pump(server, 3)
    var handle = server.events[0].stream
    server.events.clear()
    client.quic.reset_stream(stream, H3ErrorCode.H3_REQUEST_CANCELLED.value)
    client.quic.handle_events(client.ssl)
    client.pump(server, 4)
    assert_equal(len(server.events), 1)
    assert_equal(server.events[0].kind, TunnelEventKind.RESET)
    assert_false(server.send(handle, Span(data_bytes("x")), False))


def test_server_reset() raises:
    var server = tunnel_server()
    var client = RawClient(server)
    var stream = client.open(False)
    client.send(stream, head_bytes(), False)
    client.pump(server, 3)
    var handle = server.events[0].stream
    assert_true(server.reset(handle, H3ErrorCode.H3_MESSAGE_ERROR.value))
    var got = read_some(client, server, stream, 1)
    assert_equal(got[1], ReadState.RESET)
    assert_false(server.reset(handle, 0))


def test_content_too_large() raises:
    var server = tunnel_server(8)
    var client = RawClient(server)
    var stream = client.open(False)
    client.send(stream, head_bytes(), False)
    client.pump(server, 3)
    assert_equal(len(server.events), 1)
    assert_equal(server.events[0].kind, TunnelEventKind.HEAD)
    server.events.clear()
    # One DATA frame over the limit resets the tunnel.
    client.send(stream, data_bytes("more than eight bytes"), False)
    client.pump(server, 4)
    assert_equal(len(server.events), 1)
    assert_equal(server.events[0].kind, TunnelEventKind.RESET)
    var got = read_some(client, server, stream, 1)
    assert_equal(got[1], ReadState.RESET)


def test_connection_end_resets() raises:
    var server = tunnel_server()
    var client = RawClient(server)
    var stream = client.open(False)
    client.send(stream, head_bytes(), False)
    client.pump(server, 3)
    server.events.clear()
    server.close()
    assert_equal(len(server.events), 1)
    assert_equal(server.events[0].kind, TunnelEventKind.RESET)
    _ = stream


def test_write_failure_and_credit() raises:
    var server = tunnel_server()
    var client = RawClient(server)
    var stream = client.open(False)
    client.send(stream, head_bytes(), False)
    client.pump(server, 3)
    var handle = server.events[0].stream
    server.quic.faults = QuicFaults(QuicCall.WRITE, 0, 1)
    assert_false(server.send(handle, Span(data_bytes("x")), False))
    # More than the credit of the stream: the rest waits for each poll.
    var big = List[UInt8](length=4 << 20, fill=7)
    assert_true(server.send(handle, Span(big), True))
    assert_true(server.pending(handle) > 0)
    var got = read_some(client, server, stream, len(big))
    assert_equal(got[0], len(big))


def test_kinds() raises:
    assert_true(TunnelEventKind.RESET.is_valid())
    assert_false(TunnelEventKind(4).is_valid())
    assert_equal(String(TunnelEventKind.HEAD), "head")
    assert_equal(String(TunnelEventKind.DATA), "data")
    assert_equal(String(TunnelEventKind.END), "end")
    assert_equal(String(TunnelEventKind(9)), "reset")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

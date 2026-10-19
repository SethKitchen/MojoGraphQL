# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_https2.server.H2Protocol` without TLS: the sessions of
many connections, the reuse of their slots, and the end of a connection.
There is no upstream suite; the cases follow RFC 9113 sections 3.4 and
6.8."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _h2tls import Echo
from gql_http.parser import Limits, Request, RequestReader
from gql_http.server import Handler, ResponseWriter
from gql_http2.connection import Connection, EventKind, Role
from gql_http2.hpack import HeaderList
from gql_https2.server import H2Protocol, SharedHandler


def request(mut client: Connection, path: String) raises:
    var fields = HeaderList()
    fields.add_text(":method", "GET")
    fields.add_text(":scheme", "https")
    fields.add_text(":authority", "localhost")
    fields.add_text(":path", path)
    var id = client.open_stream()
    client.send_headers(id, fields, True)


def exchange(
    mut protocol: H2Protocol[Echo], conn: Int, mut client: Connection
) raises -> Bool:
    """Give the bytes of the client to the protocol, and the answer back."""
    var out = List[UInt8]()
    var keep = protocol.receive(conn, client.out, out)
    client.out.clear()
    client.receive(Span(out))
    return keep


def test_sessions_and_slots() raises:
    var protocol = H2Protocol(Echo())
    var out = List[UInt8]()
    protocol.open(3, out)
    assert_true(len(out) > 0)
    assert_equal(protocol.sessions(), 1)
    var a = Connection(Role.CLIENT)
    a.start()
    a.receive(Span(out))
    request(a, "/one")
    assert_true(exchange(protocol, 3, a))
    assert_equal(len(a.events), 1)
    assert_equal(a.events[0].kind, EventKind.MESSAGE)
    # A second connection gets a second session.
    var second = List[UInt8]()
    protocol.open(1, second)
    assert_equal(protocol.sessions(), 2)
    protocol.close(3)
    assert_equal(protocol.sessions(), 1)
    # A new connection takes the free slot.
    var third = List[UInt8]()
    protocol.open(5, third)
    assert_equal(protocol.sessions(), 2)
    var b = Connection(Role.CLIENT)
    b.start()
    b.receive(Span(third))
    request(b, "/two")
    assert_true(exchange(protocol, 5, b))
    assert_equal(b.events[0].kind, EventKind.MESSAGE)


def test_end_of_a_connection() raises:
    var protocol = H2Protocol(Echo())
    var out = List[UInt8]()
    protocol.open(0, out)
    # Bytes that are not the client preface end the connection.
    var garbage = List[UInt8](StaticString("GET / HTTP/1.1\r\n\r\n").as_bytes())
    var answer = List[UInt8]()
    assert_false(protocol.receive(0, garbage, answer))
    assert_true(len(answer) > 0)
    protocol.close(0)
    assert_equal(protocol.sessions(), 0)


@fieldwise_init
struct Count(Handler):
    var count: Int

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        self.count += 1


def test_shared_state() raises:
    var one = SharedHandler(Count(0))
    var two = one.copy()
    var reader = RequestReader(Limits())
    var text = StaticString("GET / HTTP/1.1\r\nHost: x\r\n\r\n").as_bytes()
    reader.reserve(len(text))
    for index in range(len(text)):
        reader.write_pointer().unsafe_offset(index)[] = text[index]
    reader.commit(len(text))
    _ = reader.next()
    var writer = ResponseWriter()
    one.handle(reader.request, writer)
    two.handle(reader.request, writer)
    assert_equal(one.shared[].count, 2)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

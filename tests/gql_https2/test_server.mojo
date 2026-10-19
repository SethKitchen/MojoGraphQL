# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_https2.server`: HTTP/2 over TLS round trips, the ALPN
preference for `h2`, and HTTP/1.1 on the same port. There is no upstream
suite; the cases follow RFC 9113 section 3.2 and RFC 7301 section 3.2."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _h2tls import Echo, client, config, start_h2
from _tls import client_context, server_context
from gql_http.socket import Sys
from gql_http.status import Status
from gql_http2.client import Protocol
from gql_tls.client import HttpsClient
from gql_https2.server import SharedHandler, listen_https2


def test_h2_round_trip() raises:
    var child = start_h2()
    var c = client()
    var first = c.post(child.url("/graphql"), "application/json", "{}")
    assert_equal(first.protocol, Protocol.HTTP_2)
    assert_equal(first.status, Status.OK)
    assert_equal(first.text(), "/graphql:{}")
    assert_equal(String(first.header("content-type").value()), "text/plain")
    # The second request goes on the same connection.
    var second = c.get(child.url("/again"))
    assert_equal(second.protocol, Protocol.HTTP_2)
    assert_equal(second.text(), "/again:")
    assert_equal(c.connections(), 1)
    # A handler that raises gives 500 on its stream only.
    assert_equal(c.get(child.url("/fail")).status.code, 500)
    assert_equal(c.get(child.url("/after")).text(), "/after:")
    assert_equal(c.connections(), 1)
    child.stop()


def test_h2_is_preferred() raises:
    # The server prefers h2, even when the client lists it last.
    var child = start_h2()
    var c = HttpsClient(client_context(["http/1.1"]))
    assert_equal(c.get(child.url("/one")).text(), "/one:")
    var both = client()
    both.context = client_context(["http/1.1", "h2"])
    assert_equal(both.get(child.url("/two")).protocol, Protocol.HTTP_2)
    child.stop()


def test_http1_when_the_client_offers_only_that() raises:
    var child = start_h2()
    var c = client(offer_h2=False)
    var response = c.get(child.url("/old"))
    assert_equal(response.protocol, Protocol.HTTP_1_1)
    assert_equal(response.text(), "/old:")
    assert_equal(c.connections(), 0)
    assert_true(c.speaks_http1(c.endpoint(child.url("/"))))
    child.stop()


def test_server_without_h2() raises:
    # A context without h2 serves HTTP/1.1 only.
    var child = start_h2(["http/1.1"])
    var c = client()
    assert_equal(c.get(child.url("/x")).protocol, Protocol.HTTP_1_1)
    child.stop()


def test_shared_handler() raises:
    var shared = SharedHandler(Echo())
    var other = shared.copy()
    _ = other
    var server = listen_https2(Echo(), server_context(), config())
    assert_equal(server.other.protocol(), "h2")
    assert_equal(server.other.sessions(), 0)
    assert_false(server.stopped())
    server.close()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

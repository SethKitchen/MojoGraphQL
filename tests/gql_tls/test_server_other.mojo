# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_tls.server`: a `TlsProtocol` after ALPN that fails,
and that answers more than the socket takes at once. There is no upstream
suite; the cases follow RFC 7301."""

from std.testing import TestSuite, assert_equal, assert_true

from _serve import (
    BIG,
    Echo,
    Upper,
    config,
    open_client,
    read_count,
    read_text,
    send_text,
    turns,
)
from _tls import server_context
from gql_http.socket import Sys
from gql_tls.openssl import TlsCall, TlsFaults
from gql_tls.server import listen_tls


def test_open_fails() raises:
    var sys = Sys()
    var server = listen_tls(
        Echo(), server_context(["upper/1"]), config(), Upper(fail_open=True)
    )
    var a = open_client(sys, server, ["upper/1"])
    turns(server, 2)
    assert_equal(server.open_connections, 0)
    sys.close(a.fd)
    # The greeting cannot go out.
    var other = listen_tls(
        Echo(), server_context(["upper/1"]), config(), Upper()
    )
    other.context.openssl.faults = TlsFaults(TlsCall.WRITE, 0, 1)
    var b = open_client(sys, other, ["upper/1"])
    turns(other, 2)
    assert_equal(other.open_connections, 0)
    sys.close(b.fd)


def test_big_greeting_and_answer() raises:
    var sys = Sys()
    var server = listen_tls(
        Echo(), server_context(["upper/1"]), config(), Upper(preface=BIG)
    )
    var client = open_client(sys, server, ["upper/1"], small=True)
    turns(server, 2)
    assert_equal(read_count(server, client, BIG), BIG)
    turns(server, 2)
    send_text(client, "abc")
    assert_true(read_text(server, client, "ABC").find("ABC") >= 0)
    send_text(client, String("a") * 40000)
    assert_equal(read_count(server, client, 40000), 40000)
    send_text(client, "*")
    assert_equal(read_count(server, client, BIG), BIG)
    send_text(client, "x!")
    _ = read_text(server, client, "never")
    assert_equal(server.open_connections, 0)
    assert_equal(server.other.opened, 0)
    sys.close(client.fd)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

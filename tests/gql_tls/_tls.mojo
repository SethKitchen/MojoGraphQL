# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Helpers of the gql_tls suites: loopback socket pairs, contexts, and a
handshake that runs both ends in one thread."""

from _certs import Certs, test_certs
from gql_http.socket import IPv4Address, POLLIN, POLLOUT, Sys
from gql_tls.context import TlsContext
from gql_tls.openssl import OpenSsl
from gql_tls.stream import IoWant, TlsStream


@fieldwise_init
struct Pair(Movable):
    """A listener, and a client end and a server end connected to it."""

    var listener: Int
    var client: Int
    var server: Int

    def close(self, mut sys: Sys):
        """Close all three descriptors."""
        sys.close(self.client)
        sys.close(self.server)
        sys.close(self.listener)


def connect(mut sys: Sys, port: Int) raises -> Int:
    """Start a non-blocking connection to a loopback port."""
    var fd = sys.socket()
    var rc = sys.connect(fd, IPv4Address.LOOPBACK, port)
    if rc < 0 and rc != -115:
        raise Error("connect failed: " + String(rc))
    return fd


def loopback_pair(mut sys: Sys) raises -> Pair:
    """Connect a non-blocking client to a fresh loopback listener."""
    var listener = sys.socket()
    if sys.bind(listener, IPv4Address.LOOPBACK, 0) < 0:
        raise Error("bind failed")
    _ = sys.listen(listener, 16)
    var client = connect(sys, sys.local_port(listener))
    _ = sys.poll(listener, POLLIN, 2000)
    var server = sys.accept(listener)
    if server < 0:
        raise Error("accept failed: " + String(server))
    _ = sys.poll(client, POLLOUT, 2000)
    return Pair(listener, client, server)


def server_context(
    var protocols: List[String] = ["h2", "http/1.1"]
) raises -> TlsContext:
    """A server context with the test certificate."""
    var certs = test_certs()
    return TlsContext.server(OpenSsl(), certs.cert, certs.key, protocols^)


def client_context(
    var protocols: List[String] = ["h2", "http/1.1"]
) raises -> TlsContext:
    """A client context that trusts the test certificate."""
    var certs = test_certs()
    return TlsContext.client(OpenSsl(), protocols^, certs.cert)


def handshake_both(
    mut sys: Sys, mut client: TlsStream, mut server: TlsStream
) raises:
    """Run both handshakes until they are done."""
    var turns = 0
    while turns < 1000:
        var a = client.handshake()
        var b = server.handshake()
        if a == IoWant.NOTHING and b == IoWant.NOTHING:
            return
        if a != IoWant.NOTHING:
            _ = sys.poll(client.fd, a.poll_events(), 10)
        turns += 1
    raise Error("the handshake did not end")

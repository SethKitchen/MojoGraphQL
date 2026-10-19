# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_tls.context`: versions, the ALPN wire form, and each
setting that OpenSSL can refuse. There is no upstream suite; the cases
follow RFC 7301 section 3.1."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _certs import test_certs
from gql_tls.context import (
    TlsContext,
    TlsVersion,
    alpn_wire,
    default_protocols,
)
from gql_tls.error import TlsErrorKind
from gql_tls.openssl import OpenSsl, TlsCall, TlsFaults


def test_versions() raises:
    assert_true(TlsVersion.TLS_1_3.is_valid())
    assert_false(TlsVersion(2).is_valid())
    assert_equal(TlsVersion.TLS_1_2.number(), 0x0303)
    assert_equal(TlsVersion.TLS_1_3.number(), 0x0304)
    assert_equal(String(TlsVersion.TLS_1_2), "TLS 1.2")
    assert_equal(String(TlsVersion.TLS_1_3), "TLS 1.3")


def test_alpn_wire() raises:
    var protocols = default_protocols()
    assert_equal(len(protocols), 2)
    assert_equal(protocols[0], "h2")
    assert_equal(protocols[1], "http/1.1")
    var wire = alpn_wire(protocols)
    assert_equal(len(wire), 12)
    assert_equal(Int(wire[0]), 2)
    assert_equal(Int(wire[3]), 8)
    var empty = False
    try:
        _ = alpn_wire([""])
    except e:
        empty = True
        assert_equal(e.kind, TlsErrorKind.USAGE)
    assert_true(empty)
    var long = False
    try:
        _ = alpn_wire([String("a") * 256])
    except e:
        long = True
        assert_equal(e.kind, TlsErrorKind.USAGE)
    assert_true(long)


def faulty(call: TlsCall) raises -> OpenSsl:
    """An OpenSSL whose first call of one kind fails."""
    var openssl = OpenSsl()
    openssl.faults = TlsFaults(call, 0, 1)
    return openssl^


def server_error(
    var openssl: OpenSsl, cert: String, key: String
) raises -> String:
    """Make a server context, and return the text of its error."""
    try:
        _ = TlsContext.server(openssl^, cert, key)
    except e:
        assert_equal(e.kind, TlsErrorKind.CONFIG)
        return e.message
    return "no error"


def client_error(
    var openssl: OpenSsl, var protocols: List[String] = ["http/1.1"]
) raises -> String:
    """Make a client context, and return the text of its error."""
    try:
        _ = TlsContext.client(openssl^, protocols^)
    except e:
        assert_equal(e.kind, TlsErrorKind.CONFIG)
        return e.message
    return "no error"


def test_server_errors() raises:
    var certs = test_certs()
    assert_equal(
        server_error(faulty(TlsCall.CTX_NEW), certs.cert, certs.key),
        "SSL_CTX_new failed",
    )
    assert_equal(
        server_error(faulty(TlsCall.CTX_CTRL), certs.cert, certs.key),
        "cannot set the oldest TLS version",
    )
    var cert = server_error(OpenSsl(), "/no/such/cert.pem", certs.key)
    assert_true(cert.startswith("cannot load the certificate /no/such"))
    assert_true(cert.find(": ") > 0)
    var key = server_error(OpenSsl(), certs.cert, "/no/such/key.pem")
    assert_true(key.startswith("cannot load the private key"))


def test_server_without_alpn() raises:
    var certs = test_certs()
    var context = TlsContext.server(
        OpenSsl(), certs.cert, certs.key, List[String](), TlsVersion.TLS_1_3
    )
    assert_true(context.is_server)
    assert_equal(len(context.alpn[]), 0)


def test_client_errors() raises:
    assert_equal(
        client_error(faulty(TlsCall.TRUST)), "cannot load the trust store"
    )
    assert_equal(
        client_error(faulty(TlsCall.ALPN)), "cannot set the ALPN protocols"
    )
    var context = TlsContext.client(OpenSsl(), List[String](), verify=False)
    assert_false(context.verify)
    assert_equal(len(context.protocols), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

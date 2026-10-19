# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_tls.openssl` and `gql_tls.error`: the fault plan, the
ALPN choice, the function table and the error kinds. There is no upstream
suite; the ALPN cases follow RFC 7301 section 3.2."""

from std.ffi import external_call
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _certs import test_certs
from gql_http.error import ErrorKind, HttpError
from gql_tls.error import TlsError, TlsErrorKind
from gql_tls.openssl import (
    OpenSsl,
    SSL_ERROR_SYSCALL,
    TlsCall,
    TlsFaults,
    c_string,
    select_protocol,
)


def test_broken_pipe_is_ignored() raises:
    # A write to a closed socket must fail with EPIPE, not end the process.
    _ = external_call["signal", Int](Int32(13), Int(0))
    _ = OpenSsl()
    var previous = external_call["signal", Int](Int32(13), Int(1))
    assert_equal(previous, 1)


def test_call_kinds() raises:
    assert_true(TlsCall.SHUTDOWN.is_valid())
    assert_false(TlsCall(12).is_valid())
    assert_equal(String(TlsCall.READ), "TlsCall(9)")


def test_fault_plan() raises:
    var none = TlsFaults()
    assert_false(none.take(TlsCall.READ))
    var plan = TlsFaults(TlsCall.READ, 1, 2)
    assert_false(plan.take(TlsCall.WRITE))
    assert_false(plan.take(TlsCall.READ))
    assert_true(plan.take(TlsCall.READ))
    assert_true(plan.take(TlsCall.READ))
    assert_false(plan.take(TlsCall.READ))
    var always = TlsFaults(TlsCall.WRITE, 0, -1, SSL_ERROR_SYSCALL, 104)
    assert_true(always.take(TlsCall.WRITE))
    assert_true(always.take(TlsCall.WRITE))
    assert_equal(always.count, -1)
    assert_equal(always.error, SSL_ERROR_SYSCALL)
    assert_equal(always.errno, 104)


def _wire(text: String) -> List[UInt8]:
    """Encode `a,bc` as ALPN wire bytes with a 0 at the end."""
    var out = List[UInt8]()
    for part in text.split(","):
        out.append(UInt8(part.byte_length()))
        out.extend(part.as_bytes())
    out.append(0)
    return out^


def test_select_protocol() raises:
    var server = _wire("h2,http/1.1")
    var client = _wire("http/1.1,h2")
    # The first protocol of the server wins: h2 at offset 9 of the client.
    assert_equal(
        select_protocol(server.unsafe_ptr(), client.unsafe_ptr(), 12), 9
    )
    # Same length, other bytes: no match.
    var other = _wire("h3")
    assert_equal(
        select_protocol(server.unsafe_ptr(), other.unsafe_ptr(), 3), -1
    )
    # A length byte past the end of the client list does not match.
    var bad = List[UInt8]()
    bad.append(2)
    bad.append(104)
    assert_equal(select_protocol(server.unsafe_ptr(), bad.unsafe_ptr(), 2), -1)


def test_c_string_and_errors() raises:
    assert_equal(c_string(0), "")
    var openssl = OpenSsl()
    openssl.clear_errors()
    assert_equal(openssl.last_error(), "")
    var ctx = openssl.ctx_new(True)
    assert_false(openssl.use_certificate_chain(ctx, "/no/such/cert.pem"))
    assert_true(openssl.last_error().byte_length() > 0)
    assert_false(openssl.use_private_key(ctx, "/no/such/key.pem"))
    openssl.clear_errors()
    # A plan for another call leaves this one alone.
    openssl.faults = TlsFaults(TlsCall.READ, 0, 1)
    var other = openssl.ctx_new(False)
    assert_true(other != 0)
    openssl.ctx_free(other)
    openssl.ctx_free(ctx)


def test_functions() raises:
    var openssl = OpenSsl()
    assert_true(openssl.version >= 0x30000000)
    assert_true(openssl.has_function("SSL_new"))
    assert_false(openssl.has_function("SSL_no_such_function"))
    _ = openssl.function[Int]("SSL_new")
    var raised = False
    try:
        _ = openssl.function[Int]("SSL_no_such_function")
    except e:
        raised = True
        assert_equal(e.kind, TlsErrorKind.LIBRARY)
    assert_true(raised)


def test_old_library() raises:
    var raised = False
    try:
        _ = OpenSsl(min_version=0x7FFFFFFFFFFF)
    except e:
        raised = True
        assert_equal(e.kind, TlsErrorKind.LIBRARY)
        assert_true(e.message.find("OpenSSL 3 or newer") >= 0)
    assert_true(raised)


def test_error_kinds() raises:
    assert_true(TlsErrorKind.VERIFY.is_valid())
    assert_false(TlsErrorKind(12).is_valid())
    assert_equal(TlsErrorKind(12).text(), "invalid")
    assert_equal(String(TlsErrorKind.CONFIG), "config")
    var e = TlsError.os("connect", 111)
    assert_equal(e.kind, TlsErrorKind.OS)
    assert_equal(e.errno, 111)
    assert_equal(String(e), "os: connect failed: errno 111")
    var h = TlsError.from_http(HttpError(ErrorKind.LIMIT, "big", 0))
    assert_equal(h.kind, TlsErrorKind.LIMIT)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

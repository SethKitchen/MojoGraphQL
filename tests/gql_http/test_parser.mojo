# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_http.parser`: request heads, framing, chunked content,
pipelining and response heads.

The vectors are written from RFC 9112 and RFC 9110; each group names its
section. They hold the strict choices of this parser too: where the RFC
lets a recipient choose, the parser refuses, because a lenient parse in
front of a strict one is how requests are smuggled.
"""

from gql_http.parser import (
    BodyKind,
    ChunkedDecoder,
    Limits,
    ParseResult,
    ParseState,
    Request,
    RequestReader,
    ResponseHead,
    parse_request_head,
    parse_response_head,
    _ChunkPhase,
    _ReadPhase,
)
from gql_http.status import Method, Status, Version
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime H = "GET / HTTP/1.1\r\nHost: x\r\n"
"""A request line and a `Host` field, before more fields."""


def _code(result: ParseResult) -> Int:
    """Return 0 for COMPLETE, 1 for INCOMPLETE, else the error status."""
    if result.state == ParseState.COMPLETE:
        return 0
    if result.state == ParseState.INCOMPLETE:
        return 1
    return result.status.code


def _head(text: StringSlice, limits: Limits = Limits()) -> Int:
    """Parse a request head directly, without the reader's LF check."""
    var request = Request()
    var bytes = text.as_bytes()
    return _code(
        parse_request_head(bytes.unsafe_ptr(), len(bytes), limits, request)
    )


def _reader(text: StringSlice, limits: Limits = Limits()) -> RequestReader:
    """Return a reader that holds the bytes of `text`."""
    var reader = RequestReader(limits)
    reader.append(text.as_bytes())
    return reader^


def _status(text: StringSlice, limits: Limits = Limits()) -> Int:
    """Return the code of the first `next` of a reader of `text`."""
    var reader = _reader(text, limits)
    return _code(reader.next())


def _bytewise(text: StringSlice, mut reader: RequestReader) -> Int:
    """Feed a reader one byte at a time; return the first final code."""
    var bytes = text.as_bytes()
    var index = 0
    while index < len(bytes):
        reader.append(bytes[index : index + 1])
        var code = _code(reader.next())
        if code != 1:
            return code
        index += 1
    return 1


def test_simple_get() raises:
    var reader = _reader(
        "GET /graphql?query=%7Ba%7D HTTP/1.1\r\nHost: x\r\n\r\n"
    )
    assert_equal(_code(reader.next()), 0)
    ref request = reader.request
    assert_true(request.method == Method.GET)
    assert_equal(request.method_text(), "GET")
    assert_equal(request.target(), "/graphql?query=%7Ba%7D")
    assert_equal(request.path(), "/graphql")
    assert_equal(request.query(), "query=%7Ba%7D")
    assert_true(request.version == Version.HTTP_1_1)
    assert_equal(request.header_count(), 1)
    assert_equal(request.header_name(0), "Host")
    assert_equal(request.header_value(0), "x")
    assert_equal(request.header("HOST").value(), "x")
    assert_false(Bool(request.header("Accept")))
    assert_true(request.keep_alive)
    assert_false(request.chunked)
    assert_equal(request.content_length, -1)
    assert_equal(len(request.body()), 0)


def test_accessors() raises:
    var reader = _reader(
        "OPTIONS * HTTP/1.1\r\nHost: x\r\nA: 1\r\nB:2  \t\r\nA:\t3\r\n\r\n"
    )
    assert_equal(_code(reader.next()), 0)
    ref request = reader.request
    assert_true(request.method == Method.OPTIONS)
    assert_equal(request.path(), "*")
    assert_equal(request.query(), "")
    assert_equal(request.find_header("a"), 1)
    assert_equal(request.find_header("a", 2), 3)
    assert_equal(request.find_header("a", 4), -1)
    assert_equal(request.header("b").value(), "2")
    assert_equal(request.header_value(3), "3")
    var other = _reader("PROPFIND /x? HTTP/1.1\r\nHost: x\r\n\r\n")
    assert_equal(_code(other.next()), 0)
    assert_true(other.request.method == Method.OTHER)
    assert_equal(other.request.method_text(), "PROPFIND")
    assert_equal(other.request.query(), "")


def test_request_line() raises:
    # RFC 9112 section 2.2: empty lines before the request line are skipped.
    assert_equal(_head("\r\n\r\n" + H + "\r\n"), 0)
    assert_equal(_head(""), 1)
    assert_equal(_head("\r"), 1)
    assert_equal(_head("\rGET"), 400)
    assert_equal(_head("\nGET / HTTP/1.1\r\n"), 400)
    # Section 3: one SP between the parts; a token method.
    assert_equal(_head("GET"), 1)
    assert_equal(_head(" / HTTP/1.1\r\n"), 400)
    assert_equal(_head("GE(T / HTTP/1.1\r\n"), 400)
    assert_equal(_head("GET\t/ HTTP/1.1\r\n"), 400)
    # Section 3.2: the target is visible ASCII.
    assert_equal(_head("GET /abc"), 1)
    assert_equal(_head("GET  / HTTP/1.1\r\n"), 400)
    assert_equal(_head("GET /a\x01b HTTP/1.1\r\n"), 400)
    assert_equal(_head("GET /\x7f HTTP/1.1\r\n"), 400)
    assert_equal(_head("GET /\xc3\xa9 HTTP/1.1\r\n"), 400)
    # Section 2.3: the version.
    assert_equal(_head("GET / HTTP/1.1"), 1)
    assert_equal(_head("GET / HT"), 1)
    assert_equal(_head("GET / HTTX"), 400)
    assert_equal(_head("GET / http/1.1\r\n"), 400)
    assert_equal(_head("GET / HTTP/2.0\r\n\r\n"), 505)
    assert_equal(_head("GET / HTTP/0.9\r\n\r\n"), 505)
    assert_equal(_head("GET / HTTP/1.x\r\n"), 400)
    assert_equal(_head("GET / HTTP/x.1\r\n"), 400)
    assert_equal(_head("GET / HTTP/1-1\r\n"), 400)
    assert_equal(_head("GET / HTTP/1.1\rX"), 400)
    assert_equal(_head("GET / HTTP/1.1\nX"), 400)
    assert_equal(_head("GET / HTTP/1.1 \r\n"), 400)


def test_versions() raises:
    var old = _reader("GET / HTTP/1.0\r\n\r\n")
    assert_equal(_code(old.next()), 0)
    assert_true(old.request.version == Version.HTTP_1_0)
    assert_false(old.request.keep_alive)
    var later = _reader("GET / HTTP/1.9\r\nHost: x\r\n\r\n")
    assert_equal(_code(later.next()), 0)
    assert_true(later.request.version == Version.HTTP_1_1)
    assert_true(later.request.keep_alive)


def test_field_lines() raises:
    # RFC 9112 section 5: field lines, and where they can be incomplete.
    assert_equal(_head("GET / HTTP/1.1\r\n"), 1)
    assert_equal(_head("GET / HTTP/1.1\r\nHo"), 1)
    assert_equal(_head("GET / HTTP/1.1\r\nHost: x"), 1)
    assert_equal(_head("GET / HTTP/1.1\r\nHost: x\r"), 1)
    assert_equal(_head(H), 1)
    assert_equal(_head(H + "\r"), 1)
    assert_equal(_head(H + "\rX"), 400)
    # Section 5.2: obs-fold, and white space before the first field.
    assert_equal(_head(H + " folded\r\n\r\n"), 400)
    assert_equal(_head("GET / HTTP/1.1\r\n\tHost: x\r\n\r\n"), 400)
    # Section 5.1: no white space between the name and the colon.
    assert_equal(_head("GET / HTTP/1.1\r\nHost : x\r\n\r\n"), 400)
    assert_equal(_head(H + ": x\r\n\r\n"), 400)
    assert_equal(_head(H + "A(b: x\r\n\r\n"), 400)
    # Section 5.5: no bare LF or CR, NUL, other controls or DEL in a value.
    assert_equal(_head(H + "A: a\nb\r\n\r\n"), 400)
    assert_equal(_head(H + "A: a\rb\r\n\r\n"), 400)
    assert_equal(_head(H + "A: a\x00b\r\n\r\n"), 400)
    assert_equal(_head(H + "A: a\x7fb\r\n\r\n"), 400)
    assert_equal(_head(H + "A: a\x1bb\r\n\r\n"), 400)
    assert_equal(_head(H + "A: tab\there \xc3\xa9\r\n\r\n"), 0)
    assert_equal(_head(H + "A:\r\n\r\n"), 0)


def test_limits() raises:
    var few = Limits()
    few.max_headers = 1
    assert_equal(_head(H + "\r\n", few), 0)
    assert_equal(_head(H + "A: 1\r\n\r\n", few), 431)
    var small = Limits()
    small.max_head_bytes = 32
    assert_equal(_head("GET / HTTP/1.1\r\nHost: x\r\n\r\n", small), 0)
    assert_equal(_head(H + "A-Long-Field: 1234\r\n\r\n", small), 431)
    assert_equal(_head("GET /" + "a" * 40, small), 431)
    assert_equal(_status("GET /" + "a" * 40, small), 431)
    assert_equal(_status("GET /" + "a" * 20, small), 1)
    var tiny = Limits()
    tiny.max_body_bytes = 4
    assert_equal(_status(H + "Content-Length: 4\r\n\r\nabcd", tiny), 0)
    assert_equal(_status(H + "Content-Length: 5\r\n\r\nabcde", tiny), 413)


def test_host() raises:
    # RFC 9112 section 3.2: exactly one valid Host in HTTP/1.1.
    assert_equal(_head("GET / HTTP/1.1\r\n\r\n"), 400)
    var no_host = Limits()
    no_host.require_host = False
    assert_equal(_head("GET / HTTP/1.1\r\n\r\n", no_host), 0)
    assert_equal(_head("GET / HTTP/1.0\r\n\r\n"), 0)
    assert_equal(_head(H + "Host: y\r\n\r\n"), 400)
    assert_equal(_head("GET / HTTP/1.1\r\nHost: a b\r\n\r\n"), 400)
    assert_equal(_head("GET / HTTP/1.1\r\nHost: a/b\r\n\r\n"), 400)
    assert_equal(_head("GET / HTTP/1.1\r\nHost: [::1]:80\r\n\r\n"), 0)
    assert_equal(_head("GET / HTTP/1.1\r\nHost:\r\n\r\n"), 0)
    assert_equal(_head("GET / HTTP/1.1\r\nHOST: x\r\nHoss: y\r\n\r\n"), 0)


def test_expect() raises:
    # RFC 9110 section 10.1.1.
    var reader = _reader(H + "Expect: 100-Continue\r\n\r\n")
    assert_equal(_code(reader.next()), 0)
    assert_true(reader.request.expect_continue)
    assert_equal(_head(H + "Expect: 200-ok\r\n\r\n"), 417)
    assert_equal(_head("GET / HTTP/1.0\r\nExpect: 200-ok\r\n\r\n"), 0)
    assert_equal(_head(H + "Accept: 200-ok\r\n\r\n"), 0)


def _keep_alive(text: StringSlice) raises -> Bool:
    var reader = _reader(text)
    assert_equal(_code(reader.next()), 0)
    return reader.request.keep_alive


def test_connection() raises:
    # RFC 9112 section 9.3.
    assert_true(_keep_alive(H + "\r\n"))
    assert_false(_keep_alive(H + "Connection: close\r\n\r\n"))
    assert_false(_keep_alive(H + "Connection: Upgrade , CLOSE \r\n\r\n"))
    assert_true(_keep_alive(H + "Connection: upgrade,,\r\n\r\n"))
    assert_true(_keep_alive(H + "X-Customer: close\r\n\r\n"))
    assert_false(_keep_alive("GET / HTTP/1.0\r\n\r\n"))
    assert_true(_keep_alive("GET / HTTP/1.0\r\nConnection: keep-alive\r\n\r\n"))
    assert_false(
        _keep_alive("GET / HTTP/1.0\r\nConnection: keep-alive, close\r\n\r\n")
    )


def _framing(text: StringSlice) raises -> Tuple[Int, Bool, Bool]:
    """Return the content length, chunked and keep-alive of a request."""
    var reader = _reader(text)
    assert_equal(_code(reader.next()), 0)
    ref request = reader.request
    return (request.content_length, request.chunked, request.keep_alive)


def test_names_by_word() raises:
    # The framing rules compare names 8 bytes at a time. A name that
    # differs in any of those words is another field.
    assert_equal(_head("GET / HTTP/1.1\r\nHOST: x\r\n\r\n"), 0)
    assert_equal(_head("GET / HTTP/1.1\r\nHosx: x\r\n\r\n"), 400)
    assert_equal(_head(H + "Expecx: 100-continue\r\n\r\n"), 0)
    assert_equal(_head(H + "EXPECT: nothing\r\n\r\n"), 417)
    assert_false(_framing(H + "CONNECTION: close\r\n\r\n")[2])
    assert_true(_framing(H + "Xonnection: close\r\n\r\n")[2])
    assert_true(_framing(H + "Connectiox: close\r\n\r\n")[2])
    assert_equal(_framing(H + "CONTENT-LENGTH: 0\r\n\r\n")[0], 0)
    assert_equal(_framing(H + "Xontent-Length: 5\r\n\r\n")[0], -1)
    assert_equal(_framing(H + "Content-Lengtx: 5\r\n\r\n")[0], -1)
    var chunked = "\r\n\r\n0\r\n\r\n"
    assert_true(_framing(H + "TRANSFER-ENCODING: chunked" + chunked)[1])
    assert_false(_framing(H + "Xransfer-Encoding: chunked" + chunked)[1])
    assert_false(_framing(H + "TransferXEncoding: chunked" + chunked)[1])
    assert_false(_framing(H + "Transfer-Encodinx: chunked" + chunked)[1])
    # Sizes that no rule reads: 9, and more than 17.
    assert_equal(
        _head(H + "sec-ch-ua: x\r\nX-Very-Long-Field-Name: y\r\n\r\n"), 0
    )


def test_connection_options_by_word() raises:
    var old = "GET / HTTP/1.0\r\nConnection: "
    assert_true(_framing(old + "KEEP-ALIVE\r\n\r\n")[2])
    assert_false(_framing(old + "xeep-alive\r\n\r\n")[2])
    assert_false(_framing(old + "keep-alivx\r\n\r\n")[2])
    assert_true(_framing(H + "Connection: other\r\n\r\n")[2])
    assert_false(_framing(H + "Connection: CLOSE\r\n\r\n")[2])


def test_content_length() raises:
    # RFC 9112 section 6.3: 1*DIGIT, one field, no list.
    var reader = _reader(H + "Content-Length: 0005\r\n\r\nhello")
    assert_equal(_code(reader.next()), 0)
    assert_equal(reader.request.content_length, 5)
    assert_equal(String(unsafe_from_utf8=reader.request.body()), "hello")
    assert_equal(_head(H + "Content-Length:\r\n\r\n"), 400)
    assert_equal(_head(H + "Content-Length: abc\r\n\r\n"), 400)
    assert_equal(_head(H + "Content-Length: 1,1\r\n\r\n"), 400)
    assert_equal(_head(H + "Content-Length: -1\r\n\r\n"), 400)
    assert_equal(_head(H + "Content-Length: +1\r\n\r\n"), 400)
    assert_equal(
        _head(H + "Content-Length: 1\r\nContent-Length: 1\r\n\r\n"), 400
    )
    assert_equal(_head(H + "Content-Length: 1234567890123456789\r\n\r\n"), 413)
    assert_equal(_head(H + "Content-Length: 123456789012345678\r\n\r\n"), 413)
    assert_equal(_head(H + "Accept-Charset: x\r\n\r\n"), 0)


def test_transfer_encoding() raises:
    # RFC 9112 sections 6.1 and 6.3: the smuggling defenses.
    comptime TE = "Transfer-Encoding: "
    assert_equal(_head(H + TE + "chunked\r\n\r\n"), 0)
    assert_equal(_head(H + TE + "Chunked\r\n\r\n"), 0)
    assert_equal(_head(H + TE + ", chunked ,\r\n\r\n"), 0)
    assert_equal(_head("GET / HTTP/1.0\r\n" + TE + "chunked\r\n\r\n"), 400)
    assert_equal(_head(H + TE + "chunked\r\nContent-Length: 1\r\n\r\n"), 400)
    assert_equal(
        _head(H + "Content-Length: 1\r\n" + TE + "chunked\r\n\r\n"), 400
    )
    assert_equal(_head(H + TE + "gzip\r\n\r\n"), 400)
    assert_equal(_head(H + TE + "\r\n\r\n"), 400)
    assert_equal(_head(H + TE + "gzip, chunked\r\n\r\n"), 501)
    assert_equal(_head(H + TE + "gzip;level=1, chunked\r\n\r\n"), 501)
    assert_equal(_head(H + TE + "chunked, chunked\r\n\r\n"), 400)
    assert_equal(_head(H + TE + "chunked\r\n" + TE + "chunked\r\n\r\n"), 400)
    assert_equal(_head(H + TE + "chunked, gzip\r\n\r\n"), 400)
    assert_equal(_head(H + TE + "chunked;x=1\r\n\r\n"), 400)
    assert_equal(_head(H + TE + "chunked x\r\n\r\n"), 400)
    assert_equal(_head(H + TE + "@\r\n\r\n"), 400)
    assert_equal(_head(H + "X-Forwarded-Proto: chunked\r\n\r\n"), 0)


def test_length_body() raises:
    var reader = _reader(
        H + "Content-Length: 4\r\nExpect: 100-continue\r\n\r\nab"
    )
    assert_equal(_code(reader.next()), 1)
    assert_true(reader.needs_continue)
    reader.continue_sent = True
    assert_equal(_code(reader.next()), 1)
    assert_false(reader.needs_continue)
    reader.append(StaticString("cdGET").as_bytes())
    assert_equal(_code(reader.next()), 0)
    assert_false(reader.needs_continue)
    assert_equal(String(unsafe_from_utf8=reader.request.body()), "abcd")
    reader.consume()
    assert_equal(reader.buffered(), 3)
    assert_false(reader.continue_sent)


def test_pipelining() raises:
    var reader = _reader(
        "GET /a HTTP/1.1\r\nHost: x\r\n\r\n"
        "POST /b HTTP/1.1\r\nHost: x\r\nContent-Length: 2\r\n\r\nhi"
        "GET /c HTTP/1.1\r\nHost: x\r\n\r\n"
    )
    assert_equal(_code(reader.next()), 0)
    assert_equal(reader.request.target(), "/a")
    reader.consume()
    assert_equal(_code(reader.next()), 0)
    assert_equal(reader.request.target(), "/b")
    assert_equal(String(unsafe_from_utf8=reader.request.body()), "hi")
    reader.consume()
    assert_equal(_code(reader.next()), 0)
    assert_equal(reader.request.target(), "/c")
    assert_equal(len(reader.request.body()), 0)
    reader.consume()
    assert_equal(reader.buffered(), 0)
    assert_equal(_code(reader.next()), 1)


comptime CHUNKED = (
    "POST / HTTP/1.1\r\nHost: a\r\nTransfer-Encoding: chunked\r\n\r\n"
)
"""A request head with a chunked body after it."""


def test_chunked() raises:
    var reader = _reader(
        CHUNKED + "5\r\nhello\r\n6;ext=1\r\n world\r\n0\r\nX-T: 1\r\n\r\nGET"
    )
    assert_equal(_code(reader.next()), 0)
    assert_true(reader.request.chunked)
    assert_equal(String(unsafe_from_utf8=reader.request.body()), "hello world")
    reader.consume()
    assert_equal(reader.buffered(), 3)


def test_chunked_bytewise() raises:
    var reader = RequestReader(Limits(), 16)
    var text = (
        CHUNKED
        + '1a ; name="v"\r\nabcdefghijklmnopqrstuvwxyz\r\n'
        + "A\r\n0123456789\r\n0\r\nT: 1\r\nU:2\r\n\r\n"
    )
    assert_equal(_bytewise(text, reader), 0)
    assert_equal(
        String(unsafe_from_utf8=reader.request.body()),
        "abcdefghijklmnopqrstuvwxyz0123456789",
    )
    var expect = _reader(
        String(
            StaticString(CHUNKED)[
                byte = : StaticString(CHUNKED).byte_length() - 2
            ]
        )
        + "Expect: 100-continue\r\n\r\n5\r\n"
    )
    assert_equal(_code(expect.next()), 1)
    assert_true(expect.needs_continue)


def test_chunk_errors() raises:
    # RFC 9112 section 7.1: chunk-size, extensions, CRLF and trailers.
    assert_equal(_status(CHUNKED + "\r\n"), 400)
    assert_equal(_status(CHUNKED + "\n"), 400)
    assert_equal(_status(CHUNKED + "5\n"), 400)
    assert_equal(_status(CHUNKED + "g\r\n"), 400)
    assert_equal(_status(CHUNKED + ";x\r\n"), 400)
    assert_equal(_status(CHUNKED + "5 \r\n"), 400)
    assert_equal(_status(CHUNKED + "5x\r\n"), 400)
    assert_equal(_status(CHUNKED + "5;\x01\r\n"), 400)
    assert_equal(_status(CHUNKED + "5 ;a\r\nhello\r\n0\r\n\r\n"), 0)
    assert_equal(_status(CHUNKED + "fffffffffffffff\r\n"), 413)
    assert_equal(_status(CHUNKED + "1000000000000000\r\n"), 413)
    assert_equal(_status(CHUNKED + "5\r\nhelloXY"), 400)
    assert_equal(_status(CHUNKED + "5\r\nhello\rX"), 400)
    assert_equal(_status(CHUNKED + "5\r\nhello\r"), 1)
    assert_equal(_status(CHUNKED + "0\r\n\n"), 400)
    assert_equal(_status(CHUNKED + "0\r\nX: 1\n"), 400)
    assert_equal(_status(CHUNKED + "0\r\nbad\r\n\r\n"), 400)
    assert_equal(_status(CHUNKED + "0\r\n: x\r\n\r\n"), 400)
    assert_equal(_status(CHUNKED + "0\r\nX y: 1\r\n\r\n"), 400)
    assert_equal(_status(CHUNKED + "0\r\nX: \x01\r\n\r\n"), 400)
    var lines = Limits()
    lines.max_chunk_line_bytes = 8
    assert_equal(_status(CHUNKED + "5;abcdefgh", lines), 400)
    assert_equal(_status(CHUNKED + "5;abc", lines), 1)
    var small = Limits()
    small.max_body_bytes = 8
    assert_equal(_status(CHUNKED + "5\r\nhello\r\n4\r\n", small), 413)
    var trailer = Limits()
    trailer.max_head_bytes = 80
    assert_equal(_status(CHUNKED + "0\r\nX: " + "a" * 80, trailer), 431)


def test_chunked_decoder() raises:
    var text = String("xx3\r\nabc\r\n0\r\n\r\n")
    var bytes = List[UInt8](text.as_bytes())
    var decoder = ChunkedDecoder()
    decoder.reset(2)
    var result = decoder.feed(bytes.unsafe_ptr(), len(bytes), Limits())
    assert_equal(_code(result), 0)
    assert_equal(result.size, len(bytes))
    assert_equal(decoder.decoded(), 3)
    assert_equal(String(unsafe_from_utf8=Span(bytes)[2:5]), "abc")


def test_reader_buffer() raises:
    var reader = RequestReader(Limits(), 1)
    assert_equal(reader.space(), 16)
    reader.append(
        StaticString("GET / HTTP/1.1\r\nHost: x\r\n\r\nGET /").as_bytes()
    )
    assert_equal(_code(reader.next()), 0)
    reader.consume()
    reader.reserve(8)
    assert_equal(reader.start, 0)
    assert_equal(reader.buffered(), 5)
    var big = String("a") * 300
    reader.append(big.as_bytes())
    assert_true(len(reader.buffer) >= 305)
    reader.reset(16)
    assert_equal(len(reader.buffer), 16)
    assert_equal(reader.buffered(), 0)
    reader.reset(16)
    assert_equal(len(reader.buffer), 16)
    var write = reader.write_pointer()
    write[unsafe_offset=0] = 71
    reader.commit(1)
    assert_equal(reader.buffered(), 1)
    reader.reserve(2)
    assert_equal(reader.buffered(), 1)
    reader.consume()
    reader.start = reader.end
    reader.reserve(4)
    assert_equal(reader.end, 0)


def test_values() raises:
    assert_equal(String(ParseState.COMPLETE), "complete")
    assert_equal(String(ParseState.INCOMPLETE), "incomplete")
    assert_equal(String(ParseState.ERROR), "error")
    assert_true(ParseState.ERROR.is_valid())
    assert_false(ParseState(3).is_valid())
    assert_equal(String(ParseResult.complete(7)), "complete 7")
    assert_equal(String(ParseResult.incomplete()), "incomplete 0")
    assert_equal(String(ParseResult.error(Status.BAD_REQUEST)), "error 400")
    assert_equal(String(BodyKind.CHUNKED), "BodyKind(2)")
    assert_true(BodyKind.CLOSE.is_valid())
    assert_false(BodyKind(4).is_valid())
    var limits = Limits()
    assert_equal(limits.max_head_bytes, 16384)
    assert_equal(limits.max_headers, 100)
    assert_true(_ChunkPhase.TRAILER.is_valid())
    assert_false(_ChunkPhase(4).is_valid())
    assert_true(_ReadPhase.CHUNKED.is_valid())
    assert_false(_ReadPhase(3).is_valid())


def _response(
    text: StringSlice, mut head: ResponseHead, limits: Limits = Limits()
) -> Int:
    var bytes = text.as_bytes()
    return _code(
        parse_response_head(bytes.unsafe_ptr(), len(bytes), limits, head)
    )


def _response_code(text: StringSlice, limits: Limits = Limits()) -> Int:
    var head = ResponseHead()
    return _response(text, head, limits)


def test_response_head() raises:
    var head = ResponseHead()
    var text = "HTTP/1.1 404 Not Found\r\nContent-Length: 3\r\n\r\nabc"
    assert_equal(_response(text, head), 0)
    assert_true(head.status == Status.NOT_FOUND)
    assert_equal(head.head_size, text.byte_length() - 3)
    assert_equal(head.content_length, 3)
    assert_true(head.keep_alive)
    assert_equal(
        String(text[byte = head.reason_start : head.reason_end]), "Not Found"
    )
    assert_true(head.body_kind(Method.GET) == BodyKind.LENGTH)
    assert_true(head.body_kind(Method.HEAD) == BodyKind.NONE)
    assert_equal(_response("HTTP/1.1 204\r\n\r\n", head), 0)
    assert_equal(head.reason_start, head.reason_end)
    assert_true(head.body_kind(Method.GET) == BodyKind.NONE)
    assert_equal(_response("HTTP/1.0 200 OK\r\n\r\n", head), 0)
    assert_true(head.version == Version.HTTP_1_0)
    assert_false(head.keep_alive)
    assert_true(head.body_kind(Method.GET) == BodyKind.CLOSE)
    assert_equal(
        _response("HTTP/1.0 200 OK\r\nConnection: keep-alive\r\n\r\n", head), 0
    )
    assert_true(head.keep_alive)
    assert_equal(
        _response("HTTP/1.1 200 OK\r\nConnection: close\r\n\r\n", head), 0
    )
    assert_false(head.keep_alive)
    assert_equal(_response("HTTP/1.1 200 \r\nX: y\r\n\r\n", head), 0)
    assert_equal(len(head.fields), 1)


def test_response_chunked() raises:
    var head = ResponseHead()
    comptime TE = "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n"
    assert_equal(_response(TE + "\r\n", head), 0)
    assert_true(head.chunked)
    assert_true(head.keep_alive)
    assert_true(head.body_kind(Method.GET) == BodyKind.CHUNKED)
    assert_equal(_response(TE + "Content-Length: 5\r\n\r\n", head), 0)
    assert_true(head.chunked)
    assert_false(head.keep_alive)
    assert_equal(head.content_length, -1)
    assert_equal(
        _response_code("HTTP/1.1 200 OK\r\nTransfer-Encoding: gzip\r\n\r\n"),
        502,
    )
    assert_equal(
        _response_code("HTTP/1.1 200 OK\r\nTransfer-Encoding:\r\n\r\n"), 502
    )
    assert_equal(_response_code(TE + "Transfer-Encoding: chunked\r\n\r\n"), 502)


def test_response_errors() raises:
    assert_equal(_response_code("HTTP/1.1 20"), 1)
    assert_equal(_response_code(""), 1)
    assert_equal(_response_code("XTTP"), 502)
    var small = Limits()
    small.max_head_bytes = 8
    assert_equal(_response_code("HTTP/1.1", small), 502)
    assert_equal(_response_code("HTTP/2.0 200 OK\r\n\r\n"), 502)
    assert_equal(_response_code("HTTP/1.1-200 OK\r\n\r\n"), 502)
    assert_equal(_response_code("HTTP/1.1 2x0 OK\r\n\r\n"), 502)
    assert_equal(_response_code("HTTP/1.1 099 OK\r\n\r\n"), 502)
    assert_equal(_response_code("HTTP/1.1 600 OK\r\n\r\n"), 502)
    assert_equal(_response_code("HTTP/1.1 200X\r\n\r\n"), 502)
    assert_equal(_response_code("HTTP/1.1 200 OK"), 1)
    assert_equal(_response_code("HTTP/1.1 200 OK\r"), 1)
    assert_equal(_response_code("HTTP/1.1 200 OK\nX"), 502)
    assert_equal(_response_code("HTTP/1.1 200 OK\rX"), 502)
    var medium = Limits()
    medium.max_head_bytes = 20
    assert_equal(_response_code("HTTP/1.1 200 OK long reason", medium), 502)
    assert_equal(_response_code("HTTP/1.1 200 OK\r\nX: 1"), 1)
    assert_equal(_response_code("HTTP/1.1 200 OK\r\nX: 1234567", medium), 502)
    assert_equal(_response_code("HTTP/1.1 200 OK\r\nX : 1\r\n\r\n"), 502)
    assert_equal(
        _response_code("HTTP/1.1 200 OK\r\nContent-Length: x\r\n\r\n"), 502
    )
    assert_equal(
        _response_code(
            "HTTP/1.1 200 OK\r\nContent-Length: 1\r\nContent-Length: 1\r\n\r\n"
        ),
        502,
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `gql_http.multipart`. The cases follow meros 1.3
`src/index.test.ts` (MIT): parts in one read and split at every byte, a
preamble and an epilogue, parts without fields, and the bytes that Apollo
Server 4 writes for `@defer`."""

from gql_http.multipart import (
    INCREMENTAL_ACCEPT,
    INCREMENTAL_CONTENT_TYPE,
    JSON_PART_TYPE,
    MultipartDecoder,
    MultipartEncoder,
    MultipartPart,
    _Phase,
    boundary_of,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime APOLLO = (
    "\r\n---\r\ncontent-type: application/json; charset=utf-8\r\n\r\n"
    '{"data":{"a":1},"hasNext":true}'
    "\r\n---\r\ncontent-type: application/json; charset=utf-8\r\n\r\n"
    '{"incremental":[{"data":{"b":2},"path":[]}],"hasNext":false}'
    "\r\n-----\r\n"
)
"""Two parts as Apollo Server 4 writes them."""


def _boundary(content_type: StringSlice) -> String:
    try:
        return boundary_of(content_type)
    except e:
        return String(e)


def test_boundary_of() raises:
    assert_equal(_boundary(INCREMENTAL_CONTENT_TYPE), "-")
    assert_equal(_boundary("Multipart/Mixed ; BOUNDARY=abc"), "abc")
    assert_equal(_boundary('multipart/mixed; x; boundary = "a b" '), "a b")
    assert_equal(_boundary("multipart/mixed; a=1; boundary=z"), "z")
    assert_equal(
        _boundary("application/json"), "protocol: not a multipart/mixed type"
    )
    assert_equal(
        _boundary("multipart/mixed"), "protocol: no multipart boundary"
    )
    assert_equal(
        _boundary('multipart/mixed; boundary=""'),
        "protocol: no multipart boundary",
    )
    assert_equal(
        _boundary("multipart/mixed; boundary=" + String("b") * 71),
        "protocol: no multipart boundary",
    )
    assert_equal(
        INCREMENTAL_ACCEPT,
        "multipart/mixed;deferSpec=20220824, application/json",
    )


def test_encoder() raises:
    var encoder = MultipartEncoder()
    var out = List[UInt8]()
    encoder.part(
        out, StaticString('{"data":{"a":1},"hasNext":true}').as_bytes()
    )
    encoder.part(
        out,
        StaticString(
            '{"incremental":[{"data":{"b":2},"path":[]}],"hasNext":false}'
        ).as_bytes(),
    )
    encoder.end(out)
    encoder.end(out)
    assert_equal(String(unsafe_from_utf8=out), APOLLO)
    assert_equal(encoder.parts, 2)
    var message = String("no error")
    try:
        encoder.part(out, StaticString("{}").as_bytes())
    except e:
        message = String(e)
    assert_equal(message, "usage: the multipart content ended")
    var other = MultipartEncoder("xyz")
    out.clear()
    other.part(out, StaticString("hi").as_bytes(), "text/plain")
    other.end(out)
    assert_equal(
        String(unsafe_from_utf8=out),
        "\r\n--xyz\r\ncontent-type: text/plain\r\n\r\nhi\r\n--xyz--\r\n",
    )
    assert_equal(JSON_PART_TYPE, "application/json; charset=utf-8")


def _decode(
    text: StringSlice, step: Int, boundary: StringSlice = "-"
) raises -> String:
    """Feed a content `step` bytes at a time; describe the parts."""
    var decoder = MultipartDecoder(boundary)
    var bytes = text.as_bytes()
    var out = String()
    var pos = 0
    while pos < len(bytes):
        var end = min(pos + step, len(bytes))
        _ = decoder.feed(bytes[pos:end])
        var parts = decoder.take()
        var i = 0
        while i < len(parts):
            out += "[" + parts[i].content_type + "|" + parts[i].text() + "]"
            i += 1
        pos = end
    decoder.finish()
    return out


def test_decoder() raises:
    var expected = (
        "[application/json; charset=utf-8|"
        + '{"data":{"a":1},"hasNext":true}]'
        + "[application/json; charset=utf-8|"
        + '{"incremental":[{"data":{"b":2},"path":[]}],"hasNext":false}]'
    )
    assert_equal(_decode(APOLLO, 1 << 20), expected)
    var step = 1
    while step <= 7:
        assert_equal(_decode(APOLLO, step), expected)
        step += 1
    # A first delimiter at offset 0, a preamble, padding, an epilogue.
    assert_equal(
        _decode(
            "--b\r\n\r\none\r\n--b  \r\nX: y\r\n\r\ntwo\r\n--b--\r\nend", 3, "b"
        ),
        "[|one][|two]",
    )
    assert_equal(
        _decode(
            (
                "pre\r\namble\r\n--b\r\nNoColon\r\nContent-Type:"
                " t\r\n\r\n\r\n--b--"
            ),
            2,
            "b",
        ),
        "[t|]",
    )


def test_decoder_errors() raises:
    var decoder = MultipartDecoder()
    _ = decoder.feed(StaticString("\r\n---\r\n\r\nab").as_bytes())
    assert_false(decoder.done())
    var message = String("no error")
    try:
        decoder.finish()
    except e:
        message = String(e)
    assert_equal(message, "protocol: the multipart content ended early")
    var small = MultipartDecoder()
    small.max_part_bytes = 4
    message = String("no error")
    try:
        _ = small.feed(StaticString("\r\n---\r\n\r\nabcdef").as_bytes())
    except e:
        message = String(e)
    assert_equal(message, "limit: the part is too large")
    var head = MultipartDecoder()
    head.max_part_bytes = 4
    message = String("no error")
    try:
        _ = head.feed(StaticString("\r\n---\r\nlong-head").as_bytes())
    except e:
        message = String(e)
    assert_equal(message, "limit: the part is too large")
    # Bytes after the close delimiter are dropped.
    var done = MultipartDecoder()
    assert_equal(done.feed(StaticString("\r\n-----").as_bytes()), 0)
    assert_true(done.done())
    assert_equal(
        done.feed(StaticString("\r\n---\r\n\r\nx\r\n---").as_bytes()), 0
    )
    done.finish()


def test_part() raises:
    var part = MultipartPart(
        "a", "b", List[UInt8](StaticString("c").as_bytes())
    )
    assert_equal(part.text(), "c")
    assert_true(_Phase.DONE.is_valid())
    assert_false(_Phase(5).is_valid())


def test_edges() raises:
    # A quote only at the start stays; tabs and blanks are trimmed.
    assert_equal(_boundary('multipart/mixed; boundary="ab'), '"ab')
    assert_equal(_boundary("multipart/mixed;\tboundary=x\t"), "x")
    assert_equal(
        _boundary("multipart/mixed; boundary=   "),
        "protocol: no multipart boundary",
    )
    # Padding that starts with a dash, and a head line that starts with CR.
    assert_equal(
        _decode("\r\n----x\r\n\r\none\r\n---\r\n\rX: y\r\n\r\ntwo\r\n-----", 1),
        "[|one][|two]",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

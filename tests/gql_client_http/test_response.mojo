# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `gql_client_http.response`: Apollo Client 4.3.3 (ae0dfce)
`src/link/http/__tests__/responseIterator.ts` and
`src/link/http/__tests__/parseAndCheckHttpResponse.ts`.

Upstream runs `HttpLink` with a `fetch` mock, and checks what the link
emits. Here the bytes of the response go to `MultipartBodyReader`, and
the text of a JSON response to `parse_and_check_http_response`.

These upstream cases are not ported:

- "throws error if TextDecoder not defined in the environment": Mojo
  has no `TextDecoder`; the reader takes bytes.
- "stream is closed on final boundary" checks that the link cancels the
  reader. The reader takes no more parts after the final boundary, as
  "content after final boundary is ignored" checks.
"""

from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)

from gql_client_http.response import (
    MultipartBodyReader,
    MultipartResult,
    boundary_from_content_type,
    parse_and_check_http_response,
    parse_json_encoding,
)
from gql_json.value import JsonDocument
from gql_json.writer import stringify

comptime BOUNDARY = "gc0p4Jq0M2Yt08jU534c0p"
comptime FIRST = '{"data":{"stub":{"id":"0"}},"hasNext":true}'
comptime SECOND = (
    '{"hasNext":false, "incremental":'
    ' [{"data":{"name":"stubby"},"path":["stub"]}]}'
)
comptime SECOND_JSON = '{"hasNext":false,"incremental":[{"data":{"name":"stubby"},"path":["stub"]}]}'


def _part(
    boundary: StringSlice, content_type: StringSlice, body: StringSlice
) -> String:
    """Return one part, with its delimiter line."""
    return String(
        "--",
        boundary,
        "\r\nContent-Type: ",
        content_type,
        "\r\nContent-Length: 43\r\n\r\n",
        body,
        "\r\n",
    )


def _body(boundary: StringSlice) -> String:
    """Return the body of upstream `bodyCustomBoundary`."""
    return String(
        _part(boundary, "application/json; charset=utf-8", FIRST),
        _part(boundary, "application/json; charset=utf-8", SECOND),
        "--",
        boundary,
        "--",
    )


def _texts(results: List[MultipartResult]) -> List[String]:
    """Return the JSON text of each result."""
    var out = List[String]()
    var index = 0
    while index < len(results):
        out.append(stringify(results[index].result, results[index].result.root))
        index += 1
    return out^


def test_can_handle_whatwg_stream_bodies() raises:
    """Can handle whatwg stream bodies: one chunk for each line."""
    var reader = MultipartBodyReader(
        String("multipart/mixed; boundary=", BOUNDARY), 200
    )
    var body = _body(BOUNDARY)
    var texts = List[String]()
    var start = 0
    var bytes = body.as_bytes()
    var index = 0
    while index < len(bytes):
        if bytes[index] == 10:
            texts.extend(_texts(reader.feed(bytes[start : index + 1])))
            start = index + 1
        index += 1
    texts.extend(_texts(reader.feed(bytes[start:])))
    reader.finish()
    assert_equal(len(texts), 2)
    assert_equal(texts[0], FIRST)
    assert_equal(texts[1], SECOND_JSON)


def test_can_handle_whatwg_stream_bodies_with_arbitrary_splits() raises:
    """Can handle whatwg stream bodies with arbitrary splits."""
    var body = _body(BOUNDARY)
    var bytes = body.as_bytes()
    var size = 1
    while size < 40:
        var reader = MultipartBodyReader(
            String(
                'multipart/mixed;boundary="', BOUNDARY, '";deferSpec=20220824'
            ),
            200,
        )
        var texts = List[String]()
        var start = 0
        while start < len(bytes):
            var end = min(start + size, len(bytes))
            texts.extend(_texts(reader.feed(bytes[start:end])))
            start = end
        reader.finish()
        assert_equal(len(texts), 2)
        assert_equal(texts[1], SECOND_JSON)
        size += 7


def test_preserves_utf8_code_points_split_across_byte_chunks() raises:
    """Preserves UTF-8 code points split across byte chunks."""
    var body = String(
        _part("-", "application/json", '{"data":{"emoji":"\U0001F680 café"}}'),
        "-----",
    )
    var reader = MultipartBodyReader("multipart/mixed", 200)
    var bytes = body.as_bytes()
    var texts = List[String]()
    var index = 0
    while index < len(bytes):
        texts.extend(_texts(reader.feed(bytes[index : index + 1])))
        index += 1
    reader.finish()
    assert_equal(texts[0], '{"data":{"emoji":"\U0001F680 café"}}')


def test_throws_error_on_a_part_that_is_not_json() raises:
    """Throws an error on a part whose content type is not JSON (upstream
    `bodyIncorrectChunkType`)."""
    var reader = MultipartBodyReader("multipart/mixed", 200)
    var body = String(_part("-", "foo/bar; charset=utf-8", FIRST), "-----")
    with assert_raises(
        contains="Unsupported patch content type: application/json is required."
    ):
        _ = reader.feed(body.as_bytes())


def test_should_handle_final_boundary_correctly() raises:
    """Should handle final boundary correctly: the `--` of the close
    delimiter can come in later chunks."""
    var reader = MultipartBodyReader(
        String("multipart/mixed; boundary=", BOUNDARY), 200
    )
    var texts = _texts(
        reader.feed(
            String(
                _part(BOUNDARY, "application/json; charset=utf-8", FIRST),
                "--",
                BOUNDARY,
            ).as_bytes()
        )
    )
    with assert_raises(contains="premature end of multipart body"):
        reader.finish()
    _ = reader.feed("-".as_bytes())
    _ = reader.feed("-".as_bytes())
    reader.finish()
    assert_equal(len(texts), 1)
    assert_equal(texts[0], FIRST)


def test_content_after_final_boundary_is_ignored() raises:
    """Content after final boundary is ignored."""
    var reader = MultipartBodyReader(
        String("multipart/mixed; boundary=", BOUNDARY), 200
    )
    var body = String(
        _part(BOUNDARY, "application/json; charset=utf-8", FIRST),
        "--",
        BOUNDARY,
        "--\r\nContent-Type: application/json; charset=utf-8\r\n\r\n",
        FIRST,
        "\r\n--",
        BOUNDARY,
        "--",
    )
    assert_equal(len(reader.feed(body.as_bytes())), 1)
    assert_equal(len(reader.feed(body.as_bytes())), 0)
    reader.finish()


def test_link_errors_if_stream_is_closed_without_final_boundary() raises:
    """Link errors if stream is closed without final boundary."""
    var reader = MultipartBodyReader(
        String("multipart/mixed; boundary=", BOUNDARY), 200
    )
    _ = reader.feed(
        _part(BOUNDARY, "application/json; charset=utf-8", FIRST).as_bytes()
    )
    with assert_raises(contains="premature end of multipart body"):
        reader.finish()


def test_subscription_payloads() raises:
    """A result of the multipart subscription protocol gives its payload,
    its `errors` are protocol errors, an empty result is skipped, and
    `{"payload": null}` ends the reading."""
    var reader = MultipartBodyReader("multipart/mixed", 200)
    var body = String(
        _part("-", "application/json", "{}"),
        _part("-", "application/json", '{"payload":{"data":{"a":1}}}'),
        _part(
            "-",
            "application/json",
            '{"payload":{"data":{"b":2},"extensions":{"x":1}},"errors":[{"message":"e"}]}',
        ),
        _part(
            "-",
            "application/json",
            '{"payload":{"data":{"c":3}},"errors":null}',
        ),
        _part("-", "application/json", '{"payload":5,"errors":[]}'),
        _part(
            "-",
            "application/json",
            '{"payload":{"data":{"d":4},"extensions":[1]},"errors":[]}',
        ),
        _part("-", "application/json", '{"payload":null}'),
        _part("-", "application/json", '{"data":{"e":5}}'),
    )
    var results = reader.feed(body.as_bytes())
    var texts = _texts(results)
    assert_equal(len(texts), 5)
    assert_equal(texts[0], '{"data":{"a":1}}')
    assert_false(Bool(results[0].protocol_errors))
    assert_equal(texts[1], '{"data":{"b":2},"extensions":{"x":1}}')
    ref errors = results[1].protocol_errors.value()
    assert_equal(stringify(errors, errors.root), '[{"message":"e"}]')
    assert_equal(texts[2], '{"data":{"c":3},"extensions":{}}')
    ref empty = results[2].protocol_errors.value()
    assert_equal(stringify(empty, empty.root), "[]")
    assert_equal(texts[3], '{"extensions":{}}')
    assert_equal(texts[4], '{"data":{"d":4},"extensions":{}}')
    assert_equal(len(reader.feed("more".as_bytes())), 0)
    reader.finish()


def test_results_that_are_not_objects() raises:
    """`Object.keys` decides which results are empty: an empty array or
    string, a number and a boolean are skipped, and `null` throws."""
    var reader = MultipartBodyReader("multipart/mixed", 200)
    var body = String(
        "---\r\nX-Note: no content type\r\n\r\n[]\r\n",
        _part("-", "application/json", '""'),
        _part("-", "application/json", "7"),
        _part("-", "application/json", "true"),
        _part("-", "application/json", "[1]"),
        _part("-", "application/json", '"ab"'),
        "-----",
    )
    var texts = _texts(reader.feed(body.as_bytes()))
    assert_equal(len(texts), 2)
    assert_equal(texts[0], "[1]")
    assert_equal(texts[1], '"ab"')
    var nulls = MultipartBodyReader("multipart/mixed", 200)
    with assert_raises(contains="Cannot convert undefined or null to object"):
        _ = nulls.feed(
            String(_part("-", "application/json", "null"), "-----").as_bytes()
        )


def test_part_errors() raises:
    """A status of 300 or more and a body that is not JSON raise, and so
    does a part over the limit of `MultipartDecoder`."""
    var server = MultipartBodyReader("multipart/mixed", 500)
    with assert_raises(
        contains="Response not successful: Received status code 500"
    ):
        _ = server.feed(
            String(_part("-", "application/json", FIRST), "-----").as_bytes()
        )
    var parse = MultipartBodyReader("multipart/mixed", 200)
    with assert_raises():
        _ = parse.feed(
            String(_part("-", "application/json", "{nope"), "-----").as_bytes()
        )
    var large = MultipartBodyReader("multipart/mixed", 200)
    large.decoder.max_part_bytes = 4
    with assert_raises(contains="too large"):
        _ = large.feed(_part("-", "application/json", FIRST).as_bytes())


def test_boundary_from_content_type() raises:
    """The boundary parameter, as the regular expression of upstream
    reads it."""
    assert_equal(boundary_from_content_type("multipart/mixed"), "-")
    assert_equal(
        boundary_from_content_type(
            'multipart/mixed;boundary="graphql";deferSpec=20220824'
        ),
        "graphql",
    )
    assert_equal(
        boundary_from_content_type("multipart/mixed; boundary='abc' ; x"), "abc"
    )
    assert_equal(
        boundary_from_content_type("multipart/mixed; BOUNDARY=abc "), "abc"
    )
    assert_equal(
        boundary_from_content_type("multipart/mixed; boundary=ab;c"), "ab"
    )
    # A one-byte token needs `.+?`, so the default `-` stays.
    assert_equal(boundary_from_content_type("multipart/mixed; boundary=-"), "-")
    assert_equal(boundary_from_content_type("multipart/mixed; boundary="), "-")
    assert_equal(boundary_from_content_type("multipart/mixed; bound"), "-")
    assert_equal(boundary_from_content_type("multipart/mixed; charset=x"), "-")
    assert_equal(
        boundary_from_content_type("multipart/mixed; boundary=''"), "-"
    )
    assert_equal(
        boundary_from_content_type("multipart/mixed; boundary='ab"), "-"
    )
    assert_equal(
        boundary_from_content_type("multipart/mixed; boundary='ab' x"), "-"
    )
    assert_equal(
        boundary_from_content_type("multipart/mixed; boundary=ab\ncd"), "-"
    )
    assert_equal(
        boundary_from_content_type("multipart/mixed; boundary=ab\rcd"), "-"
    )
    assert_equal(boundary_from_content_type("multipart/mixed;  "), "-")
    # `[^"'].+?` takes the `;` that follows an empty value.
    assert_equal(
        boundary_from_content_type("a; boundary=; boundary=xy"), "; boundary=xy"
    )


def test_throws_a_server_error_when_response_is_over_300() raises:
    """Throws a Server error when response is > 300 with unparsable json."""
    with assert_raises(
        contains="Response not successful: Received status code 400"
    ):
        _ = parse_and_check_http_response(
            "q", 400, "application/json", "this will error"
        )


def test_throws_a_server_parse_error_when_response_is_200() raises:
    """Throws a ServerParse error when response is 200 with unparsable
    json."""
    with assert_raises():
        _ = parse_and_check_http_response(
            "q", 200, "application/json", "this will error"
        )
    with assert_raises():
        _ = parse_and_check_http_response(
            "q", 200, "application/graphql-response+json", "nope"
        )


def test_throws_a_network_error_with_a_status_code_and_result() raises:
    """Throws a network error with a status code and result."""
    with assert_raises(contains="Received status code 403"):
        _ = parse_and_check_http_response(
            "q", 403, "", '{"data":{"stub":{"id":1}}}'
        )


def test_throws_a_server_error_on_incorrect_data() raises:
    """Throws a server error on incorrect data."""
    with assert_raises(
        contains="Server response was malformed for query 'SampleQuery'."
    ):
        _ = parse_and_check_http_response(
            "SampleQuery", 200, "", '{"stub":{"id":1}}'
        )
    with assert_raises(contains="Server response was malformed"):
        _ = parse_and_check_http_response("q", 200, "", "5")


def test_is_able_to_return_a_correct_graphql_result() raises:
    """Is able to return a correct GraphQL result."""
    var result = parse_and_check_http_response(
        "q", 200, "application/json", '{"data":{"stub":{"id":1}}}'
    )
    assert_equal(stringify(result, result.root), '{"data":{"stub":{"id":1}}}')
    var errors = parse_and_check_http_response(
        "q", 500, "application/graphql-response+json", '{"errors":[]}'
    )
    assert_equal(stringify(errors, errors.root), '{"errors":[]}')
    var batch = parse_and_check_http_response("q", 200, "", "[]")
    assert_equal(stringify(batch, batch.root), "[]")
    var direct = parse_json_encoding(299, "{}")
    assert_equal(stringify(direct, direct.root), "{}")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

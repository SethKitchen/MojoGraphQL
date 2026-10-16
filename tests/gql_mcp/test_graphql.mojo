# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_mcp.graphql`.

Port of the tests of Apollo MCP Server 2.0.0
`crates/apollo-mcp-server/src/graphql.rs`. The telemetry, baggage and
`@private` tests are not ported, because those features are not in phase 1.
A stub endpoint in a worker process stands in for mockito.
"""

from _endpoint import start_endpoint
from gql_http.client import Client
from gql_http.headers import Headers
from gql_mcp.graphql import (
    execute_request,
    read_response,
    request_body,
    serde_number,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_raises
from std.testing import assert_true


def _body() -> String:
    return request_body(
        "query MockOp { mockOp { id } }",
        String("mock_operation"),
        '{"arg1":"foobar"}',
    )


def test_calls_graphql_endpoint_with_expected_body_without_pq_extensions() raises:
    var pool = start_endpoint()
    var client = Client()
    var headers = Headers()
    headers.add("content-type", "application/json")
    var url = "http://127.0.0.1:" + String(pool.port) + "/echo"
    var result = execute_request(client, url, headers, _body())
    client.close_idle()
    _ = pool.stop()
    assert_false(result.is_error)
    var text = result.content[0]
    assert_true(text.startswith('{"data":{"target":"/echo",'), text)
    assert_true('"content-type":"application/json",' in text, text)
    assert_true(
        text.endswith(
            '"body":"{\\"variables\\":{\\"arg1\\":\\"foobar\\"},\\"query\\":'
            + '\\"query MockOp { mockOp { id } }\\",\\"extensions\\":'
            + '{\\"clientLibrary\\":{\\"name\\":\\"mcp\\",\\"version\\":'
            + '\\"2.0.0\\"}},\\"operationName\\":\\"mock_operation\\"}"}}'
        )
    )
    assert_equal(result.structured_content.value(), text)


def test_request_body_without_name() raises:
    assert_equal(
        request_body('{ a(b: "c") }', None, "null"),
        '{"variables":null,"query":"{ a(b: \\"c\\") }","extensions":'
        + '{"clientLibrary":{"name":"mcp","version":"2.0.0"}}}',
    )


def test_returns_tool_error_when_gql_server_cannot_be_reached() raises:
    var client = Client()
    var url = "http://127.0.0.1:1/no-server"
    var result = execute_request(client, url, Headers(), _body())
    assert_true(result.is_error)
    assert_equal(
        result.content[0],
        "Failed to send GraphQL request: error sending request for url"
        + " (http://127.0.0.1:1/no-server)",
    )
    var bad = execute_request(client, "nope", Headers(), _body())
    assert_true(bad.content[0].startswith("Failed to send GraphQL request"))


def test_returns_tool_error_when_json_body_cannot_be_parsed() raises:
    var pool = start_endpoint()
    var client = Client()
    var base = "http://127.0.0.1:" + String(pool.port)
    var invalid = execute_request(client, base + "/invalid", Headers(), _body())
    var huge = execute_request(client, base + "/huge", Headers(), _body())
    var errors = execute_request(client, base + "/errors", Headers(), _body())
    var partial = execute_request(client, base + "/partial", Headers(), _body())
    var nulls = execute_request(
        client, base + "/null-errors", Headers(), _body()
    )
    var array = execute_request(client, base + "/array", Headers(), _body())
    var status = execute_request(client, base + "/status", Headers(), _body())
    var numbers = execute_request(client, base + "/numbers", Headers(), _body())
    client.close_idle()
    _ = pool.stop()
    assert_true(invalid.is_error)
    assert_equal(
        invalid.content[0],
        "Failed to read GraphQL response body: error decoding response body",
    )
    assert_true(huge.content[0].startswith("Failed to read GraphQL response"))
    # gql_response_error_are_found_in_call_tool_result
    assert_true(errors.is_error)
    # gql_response_with_errors_and_partial_data_is_flagged_as_error
    assert_true(partial.is_error)
    assert_false(nulls.is_error)
    assert_false(array.is_error)
    assert_equal(array.content[0], "[1]")
    assert_false(status.is_error)
    assert_equal(
        numbers.content[0], '{"a":2.5,"b":100000.0,"c":0,"d":12,"e":null}'
    )


def test_serde_numbers() raises:
    assert_equal(serde_number("12"), "12")
    assert_equal(serde_number("-0"), "0")
    assert_equal(serde_number("1.0"), "1.0")
    assert_equal(serde_number("1e5"), "100000.0")
    assert_equal(serde_number("99999999999999999999"), "1e+20")
    with assert_raises():
        _ = serde_number("-1e400")
    var result = read_response("{}".as_bytes())
    assert_false(result.is_error)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

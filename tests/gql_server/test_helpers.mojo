# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the small helpers of `gql_server`: `HeaderMap.delete`,
`new_http_graphql_head`, `GraphQLRequest.set_extensions`,
`GraphQLResponse.to_json`, `js_string`, `is_bad_user_input_error` and
`remove_suggestions`.

Apollo Server 5.5.1 tests these through whole requests. Each expected
value here is what the upstream JavaScript expression gives in Node.js:
`String(value)` for `js_string`, `isBadUserInputGraphQLError` and the
regular expression of the `DisableSuggestions` plugin.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_true
from gql_json.parser import parse as parse_json
from gql_json.value import NO_NODE as NO_JSON
from gql_language.error import PathSegment
from gql_language.source import SourceLocation
from gql_server.error_normalize import FormattedError
from gql_server.errors import ServerError, set_extension
from gql_execution.value import Values
from gql_server.http_types import (
    HTTPGraphQLRequest,
    HeaderMap,
    new_http_graphql_head,
)
from gql_server.request_pipeline import (
    is_bad_user_input_error,
    js_string,
    remove_suggestions,
)
from gql_server.server import ServerPhase, default_context
from gql_server.types import GraphQLRequest, GraphQLResponse


def test_header_map_delete() raises:
    var headers = HeaderMap()
    headers.set("Content-Type", "a/b")
    headers.set("x-foo", "1")
    assert_true(headers.delete("CONTENT-TYPE"))
    assert_false(headers.delete("content-type"))
    assert_equal(len(headers), 1)
    assert_equal(headers.get("x-foo").value(), "1")


def test_new_http_graphql_head() raises:
    var head = new_http_graphql_head(201)
    assert_equal(head.status, 201)
    assert_equal(len(head.headers), 0)
    assert_equal(new_http_graphql_head().status, 0)


def test_request_extensions() raises:
    var request = GraphQLRequest(String("{ a }"))
    request.set_extensions('{"x": [1, 2]}')
    assert_equal(
        request.json.kind(request.json.find(request.extensions, "x")).value,
        parse_json("[]").kind(0).value,
    )


def test_response_with_errors() raises:
    var response = GraphQLResponse()
    response.has_errors = True
    response.errors.append(FormattedError("a"))
    response.errors.append(FormattedError("b"))
    assert_equal(
        response.to_json(), '{"errors":[{"message":"a"},{"message":"b"}]}'
    )


def _js(json: String) raises -> String:
    var doc = parse_json(json)
    return js_string(doc, doc.root)


def test_js_string() raises:
    assert_equal(_js('"x"'), "x")
    assert_equal(_js("1.50"), "1.5")
    assert_equal(_js("{}"), "[object Object]")
    assert_equal(_js("[1, null, [2, 3], {}]"), "1,,2,3,[object Object]")
    assert_equal(_js("[]"), "")
    assert_equal(_js("true"), "true")
    assert_equal(_js("false"), "false")
    assert_equal(_js("null"), "null")
    var empty = parse_json("{}")
    assert_equal(js_string(empty, NO_JSON), "undefined")


def _input_error(message: String) -> ServerError:
    var error = ServerError(message, "GraphQLError")
    error.locations.append(SourceLocation(1, 7))
    return error^


def test_is_bad_user_input_error() raises:
    assert_true(
        is_bad_user_input_error(
            _input_error('Variable "$x" got invalid value 1; bad')
        )
    )
    assert_true(
        is_bad_user_input_error(_input_error('Variable "$x" has invalid value'))
    )
    assert_true(
        is_bad_user_input_error(
            _input_error('Variable "$x" of required type "Int!" was not')
        )
    )
    assert_true(
        is_bad_user_input_error(
            _input_error('Variable "$x" of non-null type "Int!" must not')
        )
    )
    assert_false(
        is_bad_user_input_error(_input_error('Variable "$x" is unused'))
    )
    assert_false(is_bad_user_input_error(_input_error('Variable "$x')))
    assert_false(is_bad_user_input_error(_input_error("Other message")))
    var coded = _input_error('Variable "$x" has invalid value')
    set_extension(coded.extensions, "code", '"BAD"')
    assert_false(is_bad_user_input_error(coded))
    var no_location = ServerError('Variable "$x" has invalid value')
    assert_false(is_bad_user_input_error(no_location))
    var with_path = _input_error('Variable "$x" has invalid value')
    with_path.path.append(PathSegment.of_key("a"))
    assert_false(is_bad_user_input_error(with_path))


def test_remove_suggestions() raises:
    assert_equal(
        remove_suggestions('Cannot query field "a". Did you mean "b"?'),
        'Cannot query field "a".',
    )
    assert_equal(remove_suggestions('Did you mean "b"?'), "")
    assert_equal(remove_suggestions("No suggestion."), "No suggestion.")
    assert_equal(
        remove_suggestions('Did you mean "b"? No.'), 'Did you mean "b"? No.'
    )
    assert_equal(remove_suggestions("x Did you mean?"), "x Did you mean?")
    assert_equal(remove_suggestions("x.Did you mean b?"), "x.")


def test_server_phase_and_default_context() raises:
    assert_equal(String(ServerPhase(0)), "initialized")
    assert_equal(String(ServerPhase(1)), "started")
    assert_equal(String(ServerPhase(2)), "failed to start")
    assert_equal(String(ServerPhase(3)), "stopped")
    assert_equal(String(ServerPhase(4)), "<invalid>")
    assert_true(ServerPhase(3).is_valid())
    assert_false(ServerPhase(4).is_valid())
    var values = Values()
    var context = default_context(values, HTTPGraphQLRequest("GET"))
    assert_equal(values.length(context), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

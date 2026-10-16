# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of the request checks of `gql_server.run_http_query`, ported from
Apollo Server 5.5.1 `packages/integration-testsuite/src/httpServerTests.ts`
(the `GET` cases, the `POST` member checks and batching) and the checks of
`runHttpQuery.ts`. Every expected response comes from Apollo Server 5.5.1.
"""

from std.testing import TestSuite, assert_equal
from gql_server.plugin import NoPlugin
from gql_server.server import ApolloServer
from _helpers import (
    check,
    error_body,
    http_request,
    json_post,
    make_server,
    options,
    preflight_get,
    run,
)

comptime OK_STRING = '{"data":{"testString":"it works"}}'
"""The result of `{ testString }`."""


def test_get_query_missing() raises:
    var server = make_server()
    check(
        run(server, preflight_get("")),
        400,
        "no-store",
        error_body(
            "GraphQL operations must contain a non-empty `query` or a"
            " `persistedQuery` extension.",
            "BAD_REQUEST",
        ),
    )


def test_get_content_types() raises:
    var server = make_server()
    var expected = error_body(
        "GET requests may not have a content-type header other than"
        " application/json.",
        "BAD_REQUEST",
    )
    for content_type in ["text/plain", "application/graphql", "invalid"]:
        var headers: List[String] = [
            "apollo-require-preflight",
            "t",
            "content-type",
            content_type,
        ]
        check(
            run(server, http_request("GET", "?query={testString}", headers, "")),
            415,
            "",
            expected,
        )
    for content_type in ["application/json", "application/json; charset=utf-8"]:
        var headers: List[String] = [
            "apollo-require-preflight",
            "t",
            "content-type",
            content_type,
        ]
        check(
            run(server, http_request("GET", "?query={testString}", headers, "")),
            0,
            "no-store",
            OK_STRING,
        )


def test_basic_get_request() raises:
    var server = make_server()
    check(run(server, preflight_get("?query={testString}")), 0, "no-store", OK_STRING)
    # A body of a GET is not a batch.
    var headers: List[String] = ["apollo-require-preflight", "t"]
    check(
        run(
            server,
            http_request(
                "GET",
                "?query={testString}",
                headers,
                '[{"query":"{testPerson{firstName}}"}]',
            ),
        ),
        0,
        "no-store",
        OK_STRING,
    )


def test_get_mutation() raises:
    var server = make_server()
    var response = run(
        server, preflight_get("?query=mutation%7BtestMutation(echo:%22x%22)%7D")
    )
    check(
        response,
        405,
        "no-store",
        error_body(
            "GET requests only support query operations, not mutation"
            " operations",
            "BAD_REQUEST",
        ),
    )
    assert_equal(response.headers.get("allow").value(), "POST")


def test_get_search_parameters() raises:
    var server = make_server()
    check(
        run(server, preflight_get("?query={testString}&query={testString}")),
        400,
        "",
        error_body(
            "The 'query' search parameter may only be specified once.",
            "BAD_REQUEST",
        ),
    )
    check(
        run(
            server,
            preflight_get(
                "?query=query%20t($echo:String)%7BtestArgument(echo:$echo)%7D"
                + "&variables=%7B%22echo%22:%22world%22%7D"
            ),
        ),
        0,
        "no-store",
        '{"data":{"testArgument":"hello world"}}',
    )
    check(
        run(server, preflight_get("?query={testString}&variables=%7Bx")),
        400,
        "",
        error_body(
            "The variables search parameter contains invalid JSON.",
            "BAD_REQUEST",
        ),
    )
    check(
        run(server, preflight_get("?query={testString}&variables=[1]")),
        400,
        "",
        error_body(
            "The variables search parameter should contain a JSON-encoded"
            " object.",
            "BAD_REQUEST",
        ),
    )
    check(
        run(server, preflight_get("?query={testString}&extensions=1")),
        400,
        "",
        error_body(
            "The extensions search parameter should contain a JSON-encoded"
            " object.",
            "BAD_REQUEST",
        ),
    )


def _post_error(body: String, message: String) raises:
    var server = make_server()
    check(run(server, json_post(body)), 400, "", error_body(message, "BAD_REQUEST"))


def test_post_member_checks() raises:
    _post_error(
        '{"query":"{ testString }","variables":"{}"}',
        "`variables` in a POST body should be provided as an object, not a"
        " recursively JSON-encoded string.",
    )
    _post_error(
        '{"query":"{ testString }","extensions":"{}"}',
        "`extensions` in a POST body should be provided as an object, not a"
        " recursively JSON-encoded string.",
    )
    _post_error(
        '{"query":"{ testString }","variables":[]}',
        "`variables` in a POST body must be an object if provided.",
    )
    _post_error(
        '{"query":"{ testString }","extensions":5}',
        "`extensions` in a POST body must be an object if provided.",
    )
    _post_error(
        '{"query":"{ testString }","operationName":5}',
        "`operationName` in a POST body must be a string if provided.",
    )


def test_post_query_ast() raises:
    _post_error(
        '{"query":{"kind":"Document","definitions":[]}}',
        "GraphQL queries must be strings. It looks like you're sending the"
        " internal graphql-js representation of a parsed query in your"
        " request instead of a request in the GraphQL query language. You"
        " can convert an AST to a string using the `print` function from"
        " `graphql`, or use a client like `apollo-client` which converts the"
        " internal representation to a string for you.",
    )
    _post_error('{"query":5}', "GraphQL queries must be strings.")
    _post_error('{"query":{"kind":5}}', "GraphQL queries must be strings.")
    _post_error('{"query":{"kind":"Field"}}', "GraphQL queries must be strings.")
    _post_error('{"query":[1]}', "GraphQL queries must be strings.")
    # A falsy `query` counts as missing.
    var server = make_server()
    for body in ['{"query":0}', '{"query":false}', '{"query":null}']:
        assert_equal(run(server, json_post(String(body))).status, 400)


def test_batching_disabled_by_default() raises:
    var server = make_server()
    check(
        run(server, json_post('[{"query":"{ testString }"}]')),
        400,
        "",
        error_body("Operation batching disabled.", "BAD_REQUEST"),
    )


def _batch_server() raises -> ApolloServer[NoPlugin]:
    var opts = options()
    opts.allow_batched_http_requests = True
    return make_server(opts^)


def test_batch_requests() raises:
    var server = _batch_server()
    check(
        run(
            server,
            json_post(
                '[{"query":"{ testString }"},{"query":"query q($echo: String)'
                + ' { testArgument(echo: $echo) }","variables":{"echo":"w"}}]'
            ),
        ),
        0,
        "no-store",
        '[{"data":{"testString":"it works"}}\n,{"data":{"testArgument":'
        + '"hello w"}}\n]',
        final_newline=False,
    )
    check(
        run(server, json_post('[{"query":"{ testString }"}]')),
        0,
        "no-store",
        '[{"data":{"testString":"it works"}}\n]',
        final_newline=False,
    )
    check(run(server, json_post('{"query":"{ testString }"}')), 0, "no-store", OK_STRING)


def test_batch_errors() raises:
    var server = _batch_server()
    check(
        run(server, json_post("[]")),
        400,
        "",
        error_body("No operations found in request.", "BAD_REQUEST"),
    )
    check(
        run(server, json_post('[{"query":"{ testString }"},{"query":"{"},5]')),
        400,
        "",
        error_body(
            "POST body missing, invalid Content-Type, or JSON object has no"
            " keys.",
            "BAD_REQUEST",
        ),
    )


def test_batch_clones_context() raises:
    var server = _batch_server()
    check(
        run(
            server,
            json_post('[{"query":"{ testContext }"},{"query":"{ testContext }"}]'),
        ),
        0,
        "no-store",
        '[{"data":{"testContext":"context works"}}\n,{"data":{"testContext":'
        + '"context works"}}\n]',
        final_newline=False,
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

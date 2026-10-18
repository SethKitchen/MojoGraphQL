# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of the server options over HTTP, ported from Apollo Server 5.5.1
`packages/integration-testsuite/src/apolloServerTests.ts` (CSRF
prevention, `introspection`, `formatError`, `includeStacktraceInError
Responses`, `hideSchemaDetailsFromClientErrors`, the context function)
and `httpServerTests.ts` (`applies formatError if provided`, `sends
internal server error when formatError fails`). Every expected response
comes from Apollo Server 5.5.1.

The upstream stack traces have frames; here `stacktrace` has only the
first line (see `gql_server.error_normalize`).
"""

from std.testing import TestSuite, assert_equal, assert_true
from _helpers import (
    check,
    error_body,
    SDL,
    failing_context,
    resolvers,
    http_request,
    json_post,
    make_server,
    options,
    preflight_get,
    run,
)
from gql_server.error_normalize import FormattedError
from gql_server.errors import ServerError
from gql_server.http_types import HTTPGraphQLResponse
from gql_server.plugin import NoPlugin
from gql_server.server import ApolloServer

comptime OK_STRING = '{"data":{"testString":"it works"}}'
"""The result of `{testString}`."""
comptime CSRF = (
    "This operation has been blocked as a potential Cross-Site Request"
    " Forgery (CSRF). Please either specify a 'content-type' header (with a"
    " type that is not one of application/x-www-form-urlencoded,"
    " multipart/form-data, text/plain) or provide a non-empty value for one"
    " of the following headers: "
)
"""The start of the CSRF message."""


def test_csrf_prevention() raises:
    var server = make_server()
    var blocked = error_body(
        CSRF + "x-apollo-operation-name, apollo-require-preflight\\n",
        "BAD_REQUEST",
    )
    var none = List[String]()
    check(
        run(server, http_request("GET", "?query={testString}", none, "")),
        400,
        "",
        blocked,
    )
    var headers: List[String] = ["content-type", "text/plain"]
    check(
        run(server, http_request("POST", "", headers, "{}")), 400, "", blocked
    )
    headers = [
        "content-type",
        "application/x-www-form-urlencoded; charset=utf-8",
    ]
    check(run(server, http_request("POST", "", headers, "")), 400, "", blocked)
    headers = ["content-type", "multipart/form-data; boundary=x"]
    check(run(server, http_request("POST", "", headers, "")), 400, "", blocked)
    headers = ["apollo-require-preflight", ""]
    check(
        run(server, http_request("GET", "?query={testString}", headers, "")),
        400,
        "",
        blocked,
    )
    headers = ["x-apollo-operation-name", "x"]
    check(
        run(server, http_request("GET", "?query={testString}", headers, "")),
        0,
        "no-store",
        OK_STRING,
    )
    # A content type that is not a MIME type passes the CSRF check.
    headers = ["content-type", "//"]
    assert_equal(
        run(server, http_request("POST", "", headers, "{}")).status, 400
    )


def test_csrf_prevention_options() raises:
    var opts = options()
    opts.csrf_prevention = False
    var open = make_server(opts^)
    var none = List[String]()
    check(
        run(open, http_request("GET", "?query={testString}", none, "")),
        0,
        "no-store",
        OK_STRING,
    )
    opts = options()
    opts.csrf_prevention_request_headers = List[String](["x-custom"])
    var custom = make_server(opts^)
    check(
        run(custom, preflight_get("?query={testString}")),
        400,
        "",
        error_body(CSRF + "x-custom\\n", "BAD_REQUEST"),
    )
    var headers: List[String] = ["x-custom", "1"]
    check(
        run(custom, http_request("GET", "?query={testString}", headers, "")),
        0,
        "no-store",
        OK_STRING,
    )


def test_introspection_disabled() raises:
    var opts = options()
    opts.introspection = False
    var server = make_server(opts^)
    var message = (
        "GraphQL introspection is not allowed by Apollo Server, but the"
        " query contained __schema or __type. To enable introspection, pass"
        " introspection: true to ApolloServer in production"
    )
    check(
        run(
            server, json_post('{"query":"{ __schema { queryType { name } } }"}')
        ),
        400,
        "no-store",
        '{"errors":[{"message":"'
        + message
        + '","locations":[{"line":1,'
        + '"column":3}],"extensions":{"validationErrorCode":'
        + '"INTROSPECTION_DISABLED","code":"GRAPHQL_VALIDATION_FAILED"}}]}',
    )
    check(
        run(
            server,
            json_post(
                '{"query":"{ testString __type(name: \\"QueryType\\") { name'
                ' } }"}'
            ),
        ),
        400,
        "no-store",
        '{"errors":[{"message":"'
        + message
        + '","locations":[{"line":1,'
        + '"column":14}],"extensions":{"validationErrorCode":'
        + '"INTROSPECTION_DISABLED","code":"GRAPHQL_VALIDATION_FAILED"}}]}',
    )
    check(
        run(server, json_post('{"query":"{ testString }"}')),
        0,
        "no-store",
        OK_STRING,
    )


def test_introspection_defaults_to_node_env() raises:
    var opts = options()
    opts.node_env = String("production")
    var server = make_server(opts^)
    assert_equal(
        run(
            server, json_post('{"query":"{ __schema { queryType { name } } }"}')
        ).status,
        400,
    )


def test_stacktrace() raises:
    var opts = options()
    opts.include_stacktrace_in_error_responses = True
    var server = make_server(opts^)
    check(
        run(server, json_post('{"query":"{ testError }"}')),
        0,
        "no-store",
        '{"errors":[{"message":"Secret error message","locations":[{"line":1,'
        + '"column":3}],"path":["testError"],"extensions":{"code":'
        + '"INTERNAL_SERVER_ERROR","stacktrace":["Error: Secret error'
        + ' message"]}}],"data":{"testError":null}}',
    )
    check(
        run(server, json_post("{}")),
        400,
        "",
        '{"errors":[{"message":"POST body missing, invalid Content-Type, or'
        + ' JSON object has no keys.","extensions":{"code":"BAD_REQUEST",'
        + '"stacktrace":["BadRequestError: POST body missing, invalid'
        + ' Content-Type, or JSON object has no keys."]}}]}',
    )


def test_stacktrace_defaults_to_node_env() raises:
    var opts = options()
    opts.node_env = String("development")
    var server = make_server(opts^)
    var response = run(server, json_post('{"query":"{"}'))
    assert_true("GraphQLError: Syntax Error" in response.body)


def hello_format(
    formatted: FormattedError, error: ServerError
) raises -> FormattedError:
    var out = formatted.copy()
    out.message = "Hello"
    out.set_extension("foo", '"bar"')
    return out^


def failing_format(
    formatted: FormattedError, error: ServerError
) raises -> FormattedError:
    raise Error("nope")


def test_format_error() raises:
    var opts = options()
    opts.format_error = hello_format
    var server = make_server(opts^)
    check(
        run(server, json_post('{"query":"{ testError }"}')),
        0,
        "no-store",
        '{"errors":[{"message":"Hello","locations":[{"line":1,"column":3}],'
        + '"path":["testError"],"extensions":{"code":"INTERNAL_SERVER_ERROR",'
        + '"foo":"bar"}}],"data":{"testError":null}}',
    )
    check(
        run(server, json_post("{}")),
        400,
        "",
        '{"errors":[{"message":"Hello","extensions":{"code":"BAD_REQUEST",'
        + '"foo":"bar"}}]}',
    )


def test_format_error_fails() raises:
    var opts = options()
    opts.format_error = failing_format
    var server = make_server(opts^)
    check(
        run(server, json_post('{"query":"{ testError }"}')),
        0,
        "no-store",
        '{"errors":[{"message":"Internal server error","extensions":{"code":'
        + '"INTERNAL_SERVER_ERROR"}}],"data":{"testError":null}}',
    )
    opts = options()
    opts.format_error = failing_format
    opts.include_stacktrace_in_error_responses = True
    var debug = make_server(opts^)
    check(
        run(debug, json_post('{"query":"{ testError }"}')),
        0,
        "no-store",
        '{"errors":[{"message":"nope","extensions":{"code":'
        + '"INTERNAL_SERVER_ERROR","stacktrace":["Error: nope"]}}],"data":'
        + '{"testError":null}}',
    )


def test_context_creation_fails() raises:
    var server = make_server()
    check(
        server.execute_http_graphql_request(
            json_post('{"query":"{ testString }"}'), failing_context
        ),
        500,
        "",
        error_body("Context creation failed: boom", "INTERNAL_SERVER_ERROR"),
    )


def test_hide_schema_details() raises:
    var opts = options()
    opts.hide_schema_details_from_client_errors = True
    var server = make_server(opts^)
    check(
        run(server, json_post('{"query":"{ testStrin }"}')),
        400,
        "no-store",
        '{"errors":[{"message":"Cannot query field \\"testStrin\\" on type'
        + ' \\"QueryType\\".","locations":[{"line":1,"column":3}],'
        + '"extensions":{"code":"GRAPHQL_VALIDATION_FAILED"}}]}',
    )
    check(
        run(server, json_post('{"query":"{ testString }"}')),
        0,
        "no-store",
        OK_STRING,
    )


def _accept(
    accept: String, body: String = '{"query":"{ testString }"}'
) raises -> HTTPGraphQLResponse:
    var server = make_server()
    var headers: List[String] = [
        "content-type",
        "application/json",
        "accept",
        accept,
    ]
    return run(server, http_request("POST", "", headers, body))


def test_content_negotiation() raises:
    comptime GQL = "application/graphql-response+json; charset=utf-8"
    check(
        _accept("application/graphql-response+json"),
        0,
        "no-store",
        OK_STRING,
        GQL,
    )
    check(
        _accept("application/graphql-response+json, application/json"),
        0,
        "no-store",
        OK_STRING,
        GQL,
    )
    check(
        _accept("application/json;q=0.5, application/graphql-response+json"),
        0,
        "no-store",
        OK_STRING,
        GQL,
    )
    check(_accept("*/*"), 0, "no-store", OK_STRING)
    check(_accept(""), 0, "no-store", OK_STRING)
    check(
        _accept(
            "application/json; charset=latin1,"
            " application/graphql-response+json;q=0.1"
        ),
        0,
        "no-store",
        OK_STRING,
        GQL,
    )
    check(
        _accept("application/json; callbackSpec=1.0"),
        0,
        "no-store",
        OK_STRING,
        "application/json; callbackSpec=1.0; charset=utf-8",
    )
    check(
        _accept("application/graphql-response+json", "{}"),
        400,
        "",
        error_body(
            (
                "POST body missing, invalid Content-Type, or JSON object has no"
                " keys."
            ),
            "BAD_REQUEST",
        ),
        GQL,
    )


def test_not_acceptable() raises:
    var expected = error_body(
        (
            "An 'accept' header was provided for this request which does not"
            " accept application/json; charset=utf-8 or"
            " application/graphql-response+json; charset=utf-8"
        ),
        "BAD_REQUEST",
    )
    check(_accept("text/html"), 406, "", expected)
    check(_accept("text/html", '{"query":"{"}'), 406, "", expected)
    check(
        _accept("text/html", "{}"),
        400,
        "",
        error_body(
            (
                "POST body missing, invalid Content-Type, or JSON object has no"
                " keys."
            ),
            "BAD_REQUEST",
        ),
    )


def test_negotiation_memo() raises:
    var server = make_server()
    var headers: List[String] = [
        "content-type",
        "application/json",
        "accept",
        "text/html",
    ]
    var first = run(
        server, http_request("POST", "", headers, '{"query":"{ testString }"}')
    )
    var again = run(
        server, http_request("POST", "", headers, '{"query":"{ testString }"}')
    )
    assert_equal(first.status, 406)
    assert_equal(again.status, 406)
    headers[3] = "application/json"
    assert_equal(
        run(
            server,
            http_request("POST", "", headers, '{"query":"{ testString }"}'),
        ).status,
        0,
    )


def test_landing_page() raises:
    var opts = options()
    opts.landing_page_html = String("<p>hi</p>")
    var server = make_server(opts^)
    var headers: List[String] = [
        "accept",
        "text/html",
        "apollo-require-preflight",
        "t",
    ]
    var response = run(
        server, http_request("GET", "?query={testString}", headers, "")
    )
    assert_equal(response.body, "<p>hi</p>")
    assert_equal(response.headers.get("content-type").value(), "text/html")
    headers = ["accept", "application/json", "apollo-require-preflight", "t"]
    assert_equal(
        run(
            server, http_request("GET", "?query={testString}", headers, "")
        ).body,
        OK_STRING + "\n",
    )
    headers = ["accept", "text/html", "content-type", "application/json"]
    assert_equal(
        run(
            server,
            http_request("POST", "", headers, '{"query":"{testString}"}'),
        ).status,
        406,
    )
    headers = ["accept", "foo/bar", "apollo-require-preflight", "t"]
    assert_equal(
        run(
            server, http_request("GET", "?query={testString}", headers, "")
        ).status,
        406,
    )
    headers = ["accept", "", "apollo-require-preflight", "t"]
    assert_equal(
        run(
            server, http_request("GET", "?query={testString}", headers, "")
        ).status,
        0,
    )
    headers = ["apollo-require-preflight", "t"]
    assert_equal(
        run(
            server, http_request("GET", "?query={testString}", headers, "")
        ).status,
        0,
    )


def test_server_phases() raises:
    var server = ApolloServer.from_type_defs(
        SDL, resolvers(), options(), NoPlugin()
    )
    check(
        run(server, json_post('{"query":"{ testString }"}')),
        500,
        "",
        error_body(
            (
                "You need to call `server.start()` before using your Apollo"
                " Server."
            ),
            "INTERNAL_SERVER_ERROR",
        ),
    )
    server.start()
    check(
        run(server, json_post('{"query":"{ testString }"}')),
        0,
        "no-store",
        OK_STRING,
    )
    server.stop()
    check(
        run(server, json_post('{"query":"{ testString }"}')),
        500,
        "",
        error_body(
            "Cannot execute GraphQL operations after the server has stopped.'",
            "INTERNAL_SERVER_ERROR",
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

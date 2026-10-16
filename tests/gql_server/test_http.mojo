# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `ApolloServer.execute_http_graphql_request`, ported from Apollo
Server 5.5.1 `packages/integration-testsuite/src/httpServerTests.ts`
(`graphqlHTTP`). Every expected status, field and content comes from
Apollo Server 5.5.1 run through `startStandaloneServer`.

The cases of the body parser (malformed JSON, `text/plain`) are in
`test_standalone.mojo`, because the standalone server parses the body.

Upstream cases that are not ported:
- `cache-control` with `@cacheControl` hints and dynamic hints: the cache
  control plugin computes no hints (see `gql_server.cache_policy`).
- `throwing in didResolveOperation` and `formatError` with `instanceof`
  checks, `GraphQLError HTTP extensions are respected and stripped`: a
  Mojo resolver cannot throw a `GraphQLError` with extensions, and Mojo
  has no `instanceof`. The `didResolveOperation` case is in
  `test_plugins.mojo` with a `ServerError`.
- `can handle batch requests in parallel` and `testStringWithDelay`:
  execution is synchronous.
- `can handle Rover introspection request` and `can handle introspection
  request`: introspection itself is tested in `gql_execution`; one
  `__type` query is here.
- `willSendResponse can be equivalent to the old formatResponse function`
  and `passes the context to the resolver`: in `test_plugins.mojo` and
  below.
- The `@defer` cases: incremental delivery is not ported.
- `gateway execution`: there is no gateway.
"""

from std.testing import TestSuite, assert_equal
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


def test_rejects_methods_other_than_post_and_get() raises:
    var server = make_server()
    var headers: List[String] = ["apollo-require-preflight", "t"]
    var response = run(server, http_request("HEAD", "", headers, ""))
    check(
        response,
        405,
        "",
        error_body(
            "Apollo Server supports only GET/POST requests.", "BAD_REQUEST"
        ),
    )
    assert_equal(response.headers.get("allow").value(), "GET, POST")
    headers = ["content-type", "application/json"]
    response = run(server, http_request("PUT", "", headers, '{"query":"{testString}"}'))
    assert_equal(response.status, 405)


def test_post_body_missing() raises:
    var server = make_server()
    var response = run(server, json_post(""))
    check(
        response,
        400,
        "",
        error_body(
            "POST body missing, invalid Content-Type, or JSON object has no"
            " keys.",
            "BAD_REQUEST",
        ),
    )
    response = run(server, json_post("{}"))
    assert_equal(response.status, 400)
    response = run(server, json_post('"x"'))
    assert_equal(response.status, 400)


def test_post_operation_is_empty() raises:
    var server = make_server()
    check(
        run(server, json_post('{"query":""}')),
        400,
        "no-store",
        error_body(
            "GraphQL operations must contain a non-empty `query` or a"
            " `persistedQuery` extension.",
            "BAD_REQUEST",
        ),
    )


def test_parse_failure() raises:
    var server = make_server()
    check(
        run(server, json_post('{"query":"{"}')),
        400,
        "no-store",
        '{"errors":[{"message":"Syntax Error: Expected Name, found <EOF>.",'
        + '"locations":[{"line":1,"column":2}],"extensions":{"code":'
        + '"GRAPHQL_PARSE_FAILED"}}]}',
    )


def test_validation_failure() raises:
    var server = make_server()
    check(
        run(server, json_post('{"query":"{ testStrin }"}')),
        400,
        "no-store",
        '{"errors":[{"message":"Cannot query field \\"testStrin\\" on type'
        + ' \\"QueryType\\". Did you mean \\"testString\\", \\"testError\\",'
        + ' \\"testInt\\", or \\"testPerson\\"?","locations":[{"line":1,'
        + '"column":3}],"extensions":{"code":"GRAPHQL_VALIDATION_FAILED"}}]}',
    )


def test_unknown_operation_name() raises:
    var server = make_server()
    var expected = error_body(
        'Unknown operation named \\"x\\".', "OPERATION_RESOLUTION_FAILURE"
    )
    check(
        run(
            server,
            json_post('{"query":"query q { testString }","operationName":"x"}'),
        ),
        400,
        "no-store",
        expected,
    )
    check(
        run(server, preflight_get("?query=query%20q%7BtestString%7D&operationName=x")),
        400,
        "no-store",
        expected,
    )


def test_multiple_operations_without_name() raises:
    var server = make_server()
    check(
        run(
            server,
            json_post('{"query":"query a { testString } query b { testString }"}'),
        ),
        400,
        "no-store",
        error_body(
            "Must provide operation name if query contains multiple"
            " operations.",
            "OPERATION_RESOLUTION_FAILURE",
        ),
    )


def test_basic_request_and_operation_name() raises:
    var server = make_server()
    check(run(server, json_post('{"query":"{ testString }"}')), 0, "no-store", OK_STRING)
    check(
        run(
            server,
            json_post(
                '{"query":"query test1 { testString } query test2 {'
                + ' testPerson { firstName } }","operationName":"test2"}'
            ),
        ),
        0,
        "no-store",
        '{"data":{"testPerson":{"firstName":"Jane"}}}',
    )
    # `null` members count as missing.
    check(
        run(
            server,
            json_post(
                '{"query":"{ testString }","operationName":null,'
                + '"variables":null,"extensions":null}'
            ),
        ),
        0,
        "no-store",
        OK_STRING,
    )


def test_variables_mutation_context_and_root_value() raises:
    var server = make_server()
    check(
        run(
            server,
            json_post(
                '{"query":"query test($echo: String){ testArgument(echo:'
                + ' $echo) }","variables":{"echo":"world"}}'
            ),
        ),
        0,
        "no-store",
        '{"data":{"testArgument":"hello world"}}',
    )
    check(
        run(server, json_post('{"query":"mutation { testMutation(echo: \\"yay\\") }"}')),
        0,
        "no-store",
        '{"data":{"testMutation":"not really a mutation, but who cares: yay"}}',
    )
    check(
        run(server, json_post('{"query":"{ testContext testRootValue }"}')),
        0,
        "no-store",
        '{"data":{"testContext":"context works","testRootValue":"it also'
        + ' works"}}',
    )


def test_returns_errors() raises:
    var server = make_server()
    check(
        run(server, json_post('{"query":"{ testError testString }"}')),
        0,
        "no-store",
        '{"errors":[{"message":"Secret error message","locations":[{"line":1,'
        + '"column":3}],"path":["testError"],"extensions":{"code":'
        + '"INTERNAL_SERVER_ERROR"}}],"data":{"testError":null,"testString":'
        + '"it works"}}',
    )


def test_variable_coercion_errors() raises:
    var server = make_server()
    check(
        run(
            server,
            json_post(
                '{"query":"query q($n: Int!) { testInt(n: $n) }",'
                + '"variables":{"n":"x"}}'
            ),
        ),
        400,
        "no-store",
        '{"errors":[{"message":"Variable \\"$n\\" got invalid value \\"x\\";'
        + ' Int cannot represent non-integer value: \\"x\\"","locations":'
        + '[{"line":1,"column":9}],"extensions":{"code":"BAD_USER_INPUT"}}]}',
    )
    check(
        run(server, json_post('{"query":"query q($n: Int!) { testInt(n: $n) }"}')),
        400,
        "no-store",
        '{"errors":[{"message":"Variable \\"$n\\" of required type \\"Int!\\"'
        + ' was not provided.","locations":[{"line":1,"column":9}],'
        + '"extensions":{"code":"BAD_USER_INPUT"}}]}',
    )
    var opts = options()
    opts.status400_for_variable_coercion_errors = False
    var lenient = make_server(opts^)
    var response = run(
        lenient,
        json_post(
            '{"query":"query q($n: Int!) { testInt(n: $n) }","variables":'
            + '{"n":"x"}}'
        ),
    )
    assert_equal(response.status, 0)


def test_introspection_request() raises:
    var server = make_server()
    check(
        run(server, json_post('{"query":"{ __type(name: \\"PersonType\\") { name } }"}')),
        0,
        "no-store",
        '{"data":{"__type":{"name":"PersonType"}}}',
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

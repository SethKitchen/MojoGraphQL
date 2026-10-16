# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `gql_server.errors` and `gql_server.error_normalize`, ported
from Apollo Server 5.5.1 `src/__tests__/errors.test.ts`
(`normalizeAndFormatErrors`), with the error classes of
`internalErrorClasses.ts` and the codes of `errors/index.ts`.

Upstream cases that are not ported: `formatError can be used to provide
AS3-compatible extensions` copies the properties of a JavaScript `Error`
object, which a Mojo `Error` does not have.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_true
from gql_language.error import GraphQLError, PathSegment
from gql_language.source import SourceLocation
from gql_server.error_normalize import (
    FormattedError,
    normalize_and_format_errors,
)
from gql_server.errors import (
    ApolloServerErrorCode,
    ApolloServerValidationErrorCode,
    ServerError,
    bad_request_error,
    ensure_graphql_error,
    has_code,
    operation_resolution_error,
    persisted_query_not_found_error,
    persisted_query_not_supported_error,
    syntax_error,
    user_input_error,
    validation_error,
)
from gql_server.http_types import HTTPGraphQLHead


def _with_extensions(extensions: String) raises -> ServerError:
    var error = GraphQLError("message")
    error.extensions = extensions
    return ServerError.from_graphql_error(error)


def _one(var error: ServerError) -> List[ServerError]:
    var out = List[ServerError]()
    out.append(error^)
    return out^


def test_exposes_a_stacktrace_in_debug_mode() raises:
    var error = _with_extensions('{"code":"CODE","key":"value"}')
    var result = normalize_and_format_errors(_one(error^), None, True)
    ref formatted = result.formatted_errors[0]
    assert_equal(formatted.message, "message")
    assert_equal(formatted.extension("key").value(), '"value"')
    assert_equal(formatted.extension("code").value(), '"CODE"')
    assert_equal(formatted.extension("stacktrace").value(), '["GraphQLError: message"]')
    assert_false(Bool(formatted.extension("exception")))


def test_hides_stacktrace_by_default() raises:
    var result = normalize_and_format_errors(_one(ensure_graphql_error(Error("message"))))
    ref formatted = result.formatted_errors[0]
    assert_equal(formatted.extension("code").value(), '"INTERNAL_SERVER_ERROR"')
    assert_false(Bool(formatted.extension("stacktrace")))
    assert_equal(
        formatted.to_json(),
        '{"message":"message","extensions":{"code":"INTERNAL_SERVER_ERROR"}}',
    )


def test_exposes_extensions_and_code() raises:
    var result = normalize_and_format_errors(
        _one(_with_extensions('{"key":"value","code":"CODE"}'))
    )
    assert_equal(
        result.formatted_errors[0].to_json(),
        '{"message":"message","extensions":{"key":"value","code":"CODE"}}',
    )


def keep_format(formatted: FormattedError, error: ServerError) raises -> FormattedError:
    if formatted.extension("code").value() != '"CODE"':
        raise Error("formatError did not see the code")
    if not formatted.extension("stacktrace"):
        raise Error("formatError did not see the stacktrace")
    if error.message != "message":
        raise Error("formatError did not get the error")
    return formatted.copy()


def test_calls_format_error_after_code_and_stacktrace() raises:
    var result = normalize_and_format_errors(
        _one(_with_extensions('{"code":"CODE","key":"value"}')), keep_format, True
    )
    assert_equal(result.formatted_errors[0].message, "message")


def test_formats_native_errors() raises:
    var result = normalize_and_format_errors(_one(ensure_graphql_error(Error("Hello"))))
    assert_equal(result.formatted_errors[0].message, "Hello")


def test_bad_extensions_raise() raises:
    var raised = False
    try:
        _ = _with_extensions("{")
    except:
        raised = True
    assert_true(raised)


def test_http_extensions_are_collected() raises:
    var error = ServerError("e")
    error.http = HTTPGraphQLHead(402)
    error.http.headers.set("erroneous", "indeed")
    var other = ServerError("f")
    other.http.headers.set("felonious", "nah")
    var errors = _one(error^)
    errors.append(other^)
    var result = normalize_and_format_errors(errors)
    assert_equal(result.http_from_errors.status, 402)
    assert_equal(result.http_from_errors.headers.get("erroneous").value(), "indeed")
    assert_equal(result.http_from_errors.headers.get("felonious").value(), "nah")
    assert_false(Bool(result.formatted_errors[0].extension("http")))


def test_error_classes() raises:
    var bad = bad_request_error("x")
    assert_equal(bad.http.status, 400)
    assert_equal(bad.stack, "BadRequestError: x")
    assert_true(has_code(bad, ApolloServerErrorCode.BAD_REQUEST))
    assert_false(has_code(bad, ApolloServerErrorCode.BAD_USER_INPUT))
    assert_false(has_code(ServerError("y"), ApolloServerErrorCode.BAD_REQUEST))
    var parse_error = syntax_error(ServerError("s", "GraphQLError"))
    assert_true(has_code(parse_error, ApolloServerErrorCode.GRAPHQL_PARSE_FAILED))
    assert_equal(parse_error.http.status, 400)
    var invalid = validation_error(_with_extensions('{"validationErrorCode":"X"}'))
    assert_equal(invalid.extensions[0].key, "validationErrorCode")
    assert_equal(invalid.extensions[1].key, "code")
    assert_true(has_code(user_input_error(ServerError("u")), ApolloServerErrorCode.BAD_USER_INPUT))
    var resolution = operation_resolution_error(ServerError("o"))
    assert_equal(resolution.http.status, 400)
    var not_found = persisted_query_not_found_error()
    assert_equal(not_found.http.status, 200)
    assert_equal(
        not_found.http.headers.get("cache-control").value(),
        "private, no-cache, must-revalidate",
    )
    assert_equal(not_found.stack, "PersistedQueryNotFoundError: PersistedQueryNotFound")
    var not_supported = persisted_query_not_supported_error()
    assert_equal(not_supported.message, "PersistedQueryNotSupported")
    var wrapped = ensure_graphql_error(Error("boom"), "Context creation failed: ")
    assert_equal(wrapped.message, "Context creation failed: boom")
    assert_equal(wrapped.stack, "Error: boom")
    assert_equal(String(wrapped), "Context creation failed: boom")


def test_from_graphql_error_keeps_locations_and_path() raises:
    var error = GraphQLError("m")
    error.locations.append(SourceLocation(1, 2))
    error.locations.append(SourceLocation(3, 4))
    error.path.append(PathSegment.of_key("a"))
    error.path.append(PathSegment.of_index(0))
    var result = normalize_and_format_errors(_one(ServerError.from_graphql_error(error)))
    assert_equal(
        result.formatted_errors[0].to_json(),
        '{"message":"m","locations":[{"line":1,"column":2},{"line":3,'
        + '"column":4}],"path":["a",0],"extensions":{"code":'
        + '"INTERNAL_SERVER_ERROR"}}',
    )
    var plain = FormattedError("p")
    assert_equal(plain.to_json(), '{"message":"p"}')
    plain.set_extension("a", "1")
    plain.set_extension("a", "2")
    assert_equal(plain.to_json(), '{"message":"p","extensions":{"a":2}}')


def test_codes() raises:
    assert_equal(String(ApolloServerErrorCode.INTERNAL_SERVER_ERROR), "INTERNAL_SERVER_ERROR")
    assert_equal(ApolloServerErrorCode.GRAPHQL_PARSE_FAILED.text(), "GRAPHQL_PARSE_FAILED")
    assert_equal(ApolloServerErrorCode.GRAPHQL_VALIDATION_FAILED.text(), "GRAPHQL_VALIDATION_FAILED")
    assert_equal(ApolloServerErrorCode.PERSISTED_QUERY_NOT_FOUND.text(), "PERSISTED_QUERY_NOT_FOUND")
    assert_equal(ApolloServerErrorCode.PERSISTED_QUERY_NOT_SUPPORTED.text(), "PERSISTED_QUERY_NOT_SUPPORTED")
    assert_equal(ApolloServerErrorCode.BAD_USER_INPUT.text(), "BAD_USER_INPUT")
    assert_equal(ApolloServerErrorCode.OPERATION_RESOLUTION_FAILURE.text(), "OPERATION_RESOLUTION_FAILURE")
    assert_equal(ApolloServerErrorCode.BAD_REQUEST.text(), "BAD_REQUEST")
    assert_true(ApolloServerErrorCode.BAD_REQUEST.is_valid())
    assert_false(ApolloServerErrorCode(8).is_valid())
    assert_equal(ApolloServerErrorCode(8).text(), "<invalid>")
    assert_equal(
        String(ApolloServerValidationErrorCode.INTROSPECTION_DISABLED),
        "INTROSPECTION_DISABLED",
    )
    assert_equal(
        ApolloServerValidationErrorCode.MAX_RECURSIVE_SELECTIONS_EXCEEDED.text(),
        "MAX_RECURSIVE_SELECTIONS_EXCEEDED",
    )
    assert_true(ApolloServerValidationErrorCode(1).is_valid())
    assert_false(ApolloServerValidationErrorCode(2).is_valid())
    assert_equal(ApolloServerValidationErrorCode(2).text(), "<invalid>")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for GraphQL errors from a subgraph.

The cases follow `GraphQLError` in Hive Router.
"""

from gql_router.graphql_error import (
    ErrorPath,
    ErrorSegment,
    ErrorSegmentKind,
    GraphQLError,
    add_affected_path,
    add_subgraph_name,
    entity_index,
    error_json,
    error_with_code,
    extension_value,
    field_segment,
    graphql_error,
    handle_subgraph_errors,
    http_status_error,
    index_segment,
    normalize_entity_error,
    set_extension,
    status_text,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _path(var segments: List[ErrorSegment]) -> ErrorPath:
    return ErrorPath(segments^)


def test_a_code_and_a_subgraph_name_are_extensions() raises:
    var error = error_with_code("An error occurred", "SOME_ERROR_CODE")
    assert_equal(
        error_json(error),
        (
            '{"message":"An error'
            ' occurred","extensions":{"code":"SOME_ERROR_CODE"}}'
        ),
    )
    var plain = graphql_error("An error occurred")
    add_subgraph_name(plain, "users")
    assert_equal(
        error_json(plain),
        (
            '{"message":"An error'
            ' occurred","extensions":{"code":"DOWNSTREAM_SERVICE_ERROR","service":"users"}}'
        ),
    )
    add_subgraph_name(plain, "books")
    assert_equal(plain.service, "users")
    add_affected_path(plain, "user.friends[0].name")
    assert_equal(
        error_json(plain),
        (
            '{"message":"An error'
            ' occurred","extensions":{"code":"DOWNSTREAM_SERVICE_ERROR","service":"users","affectedPath":"user.friends[0].name"}}'
        ),
    )


def test_an_http_status_names_the_subgraph_and_the_code() raises:
    var error = http_status_error(500, "products")
    assert_equal(
        error_json(error),
        (
            '{"message":"Subgraph \'products\' responded with an invalid HTTP'
            " status code '500 Internal Server"
            ' Error\'","extensions":{"code":"SUBREQUEST_HTTP_ERROR","service":"products","http":{"status":500}}}'
        ),
    )
    assert_equal(status_text(599), "599")
    assert_true(ErrorSegmentKind.FIELD.is_valid())
    assert_false(ErrorSegmentKind(2).is_valid())


def test_extra_keys_are_alphabetical_and_an_entity_path_expands() raises:
    var error = graphql_error("missing")
    set_extension(error, "zeta", '"z"')
    set_extension(error, "alpha", "1")
    assert_equal(extension_value(error, "alpha"), "1")
    assert_equal(
        error_json(error),
        '{"message":"missing","extensions":{"alpha":1,"zeta":"z"}}',
    )
    var segments = List[ErrorSegment]()
    segments.append(field_segment("_entities"))
    segments.append(index_segment(0))
    segments.append(field_segment("name"))
    error.has_path = True
    error.path = _path(segments^)
    assert_equal(entity_index(error.path), 0)
    var indexes = List[Int]()
    indexes.append(0)
    indexes.append(0)
    var user = List[ErrorSegment]()
    user.append(field_segment("user"))
    var friends = List[ErrorSegment]()
    friends.append(field_segment("user"))
    friends.append(field_segment("friends"))
    friends.append(index_segment(1))
    var paths = List[ErrorPath]()
    paths.append(_path(user^))
    paths.append(_path(friends^))
    var expanded = normalize_entity_error(error, indexes^, paths^)
    assert_equal(len(expanded), 2)
    assert_equal(
        error_json(expanded[0]),
        '{"message":"missing","path":["user","name"],"extensions":{"alpha":1,"zeta":"z"}}',
    )
    assert_equal(
        error_json(expanded[1]),
        '{"message":"missing","path":["user","friends",1,"name"],"extensions":{"alpha":1,"zeta":"z"}}',
    )


def test_subgraph_errors_gain_a_service_and_can_expand() raises:
    var errors = List[GraphQLError]()
    errors.append(graphql_error("kept"))
    var incoming = List[GraphQLError]()
    var failed = graphql_error("down")
    var segments = List[ErrorSegment]()
    segments.append(field_segment("_entities"))
    segments.append(index_segment(0))
    segments.append(field_segment("name"))
    failed.has_path = True
    failed.path = ErrorPath(segments^)
    incoming.append(failed^)
    var indexes = List[Int]()
    indexes.append(0)
    var user = List[ErrorSegment]()
    user.append(field_segment("user"))
    var paths = List[ErrorPath]()
    paths.append(ErrorPath(user^))
    handle_subgraph_errors(
        errors, "users", True, "user", incoming^, True, indexes^, paths^
    )
    assert_equal(len(errors), 2)
    assert_equal(errors[0].message, "kept")
    assert_equal(errors[1].service, "users")
    assert_equal(errors[1].code, "DOWNSTREAM_SERVICE_ERROR")
    assert_equal(errors[1].affected_path, "user")
    assert_equal(error_json(errors[1]).find('"user","name"') >= 0, True)
    var quiet = List[GraphQLError]()
    handle_subgraph_errors(
        quiet,
        "books",
        False,
        "",
        List[GraphQLError](),
        False,
        List[Int](),
        List[ErrorPath](),
    )
    assert_equal(len(quiet), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

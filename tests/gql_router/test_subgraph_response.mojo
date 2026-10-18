# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for reading a subgraph response.

The cases follow `SubgraphResponse` in Hive Router.
"""

from gql_json.value import JsonKind
from gql_router.graphql_error import error_json, graphql_error
from gql_router.subgraph_response import (
    CustomScalarPaths,
    raw_text_at,
    read_subgraph_response,
)
from std.testing import TestSuite, assert_equal, assert_true


def _paths(name: String) -> CustomScalarPaths:
    var paths = CustomScalarPaths()
    var segments = List[String]()
    segments.append(name)
    paths.insert_path(segments)
    return paths^


def _failure(text: String) raises -> String:
    try:
        var body = read_subgraph_response(text, CustomScalarPaths())
        _ = body.has_errors
        return String("ok")
    except e:
        return String(e)


def test_errors_without_data_keep_the_extension() raises:
    var body = read_subgraph_response(
        (
            '{"errors":[{"message":"Random error from'
            ' subgraph","extensions":{"statusCode":400}}]}'
        ),
        CustomScalarPaths(),
    )
    assert_equal(body.data.kind(body.data.root), JsonKind.NULL)
    assert_true(body.has_errors)
    assert_equal(len(body.errors), 1)
    assert_equal(
        error_json(body.errors[0]),
        (
            '{"message":"Random error from'
            ' subgraph","extensions":{"statusCode":400}}'
        ),
    )


def test_a_custom_scalar_keeps_the_original_json() raises:
    var body = read_subgraph_response(
        (
            '{"data":{"labels":{"generic.learnMore.button\\t":"Learn'
            ' more"},"plain":{"message":"hello","nested":{"count":1}}},"extensions":{"statusCode":200},"extra":1}'
        ),
        _paths("labels"),
    )
    var labels = body.data.find(body.data.root, "labels")
    var raw = raw_text_at(body, labels)
    assert_true(raw.find("button\\t") >= 0)
    assert_true(raw.find("Learn more") >= 0)
    var plain = body.data.find(body.data.root, "plain")
    var message = body.data.find(plain, "message")
    assert_equal(body.data.string_value(message), "hello")
    var nested = body.data.find(plain, "nested")
    var count = body.data.find(nested, "count")
    assert_equal(Int(body.data.as_int64(count)), 1)
    assert_true(body.has_extensions)
    assert_equal(body.extensions.kind(body.extensions.root), JsonKind.OBJECT)


def test_null_data_without_errors_is_malformed() raises:
    assert_equal(_failure("{}"), "Subgraph returned malformed response")
    assert_equal(_failure('{"data":1,"data":2}'), "duplicate field `data`")
    var body = read_subgraph_response(
        '{"data":{"name":"Ada"}}', CustomScalarPaths()
    )
    body.append_error(graphql_error("later"))
    assert_equal(len(body.errors), 1)
    assert_equal(body.errors[0].message, "later")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

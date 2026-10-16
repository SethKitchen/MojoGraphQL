# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_mcp.custom_scalar_map`.

Ports the tests of Apollo MCP Server 2.0.0 (04e4e6e)
`crates/apollo-mcp-server/src/custom_scalar_map.rs`. A JSON syntax error
has the `gql_json` message, so those tests check the prefix.
"""

from gql_json.value import NO_NODE
from gql_mcp.custom_scalar_map import CustomScalarMap
from std.testing import TestSuite, assert_equal, assert_true


def error_of(text: StringSlice) -> String:
    try:
        _ = CustomScalarMap.parse(text)
    except e:
        return String(e)
    return "no error"


def test_empty_file() raises:
    assert_true(error_of("").startswith("invalid custom_scalar_config: "))


def test_only_spaces() raises:
    assert_true(error_of("    ").startswith("invalid custom_scalar_config: "))


def test_invalid_json() raises:
    assert_true(
        error_of("Hello: }").startswith("invalid custom_scalar_config: ")
    )


def test_invalid_simple_schema() raises:
    assert_equal(
        error_of('{"custom": {"type": "bool"}}'),
        (
            'invalid json schema: "bool" is not valid under any of the'
            " schemas listed in the 'anyOf' keyword"
        ),
    )


def test_invalid_complex_schema() raises:
    assert_equal(
        error_of(
            '{"custom": {"type": "object", "properties": {"test": {"type":'
            ' "obbbject"}}}}'
        ),
        (
            'invalid json schema: "obbbject" is not valid under any of the'
            " schemas listed in the 'anyOf' keyword"
        ),
    )


def test_valid_schema() raises:
    var map = CustomScalarMap.parse(
        '{"simple": {"type": "string"}, "complex": {"type": "object",'
        ' "properties": {"name": {"type": "string"}}}}'
    )
    assert_equal(map.tree.to_string(map.get("simple")), '{"type":"string"}')
    assert_equal(
        map.tree.to_string(map.get("complex")),
        '{"type":"object","properties":{"name":{"type":"string"}}}',
    )
    assert_equal(map.get("missing"), NO_NODE)


def test_meta_schema_checks() raises:
    assert_equal(
        error_of("[]"),
        "invalid custom_scalar_config: invalid type: expected a map",
    )
    assert_equal(
        error_of('{"a": 5}'),
        'invalid json schema: 5 is not of types "boolean", "object"',
    )
    assert_equal(
        error_of('{"a": {"type": ["string", 1]}}'),
        (
            'invalid json schema: ["string",1] is not valid under any of the'
            " schemas listed in the 'anyOf' keyword"
        ),
    )
    _ = CustomScalarMap.parse(
        '{"a": true, "b": {"type": ["string", "null"], "items": [{"type":'
        ' "integer"}], "not": {"type": "array"}, "anyOf": [false],'
        ' "x": {"type": "nope"}}, "c": {"items": {"type": "boolean"}}}'
    )
    assert_true(error_of('{"a": {"not": {"type": 1}}}').endswith("keyword"))
    assert_true(
        error_of('{"a": {"items": [{"type": "x"}]}}').endswith("keyword")
    )


def test_load() raises:
    var map = CustomScalarMap.load("tests/gql_mcp/fixtures/custom_scalars.json")
    assert_equal(map.tree.to_string(map.get("Date")), '{"type":"string"}')
    assert_true(error_of("{}") == "no error")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

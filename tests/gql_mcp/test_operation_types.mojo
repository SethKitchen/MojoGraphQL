# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_mcp.operation`: the JSON Schema of each kind of variable
type, the errors, and custom scalars.

Ported from Apollo MCP Server 2.0.0 (04e4e6e)
`crates/apollo-mcp-server/src/operations/operation.rs` (the tests from
`nullable_named_type` to `custom_scalar_with_map`). The expected JSON is the
upstream `serde_json` text of the tool that each insta snapshot shows.
"""

from _operation_fixtures import make_operation, sorted_json, test_schema
from gql_mcp.custom_scalar_map import CustomScalarMap
from gql_mcp.operation import Operation, RawOperation
from gql_mcp.tool import AnnotationOverrides, MutationMode
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _tool_json(source: String) raises -> String:
    return make_operation(source, test_schema()).tool.to_json()


def _schema_json(source: String) raises -> String:
    var tool = make_operation(source, test_schema()).tool.copy()
    return tool.input_schema.to_string(tool.input_schema.root)


def _error(source: String, path: Optional[String]) raises -> String:
    try:
        _ = Operation.from_raw(
            RawOperation(source, path),
            test_schema(),
            CustomScalarMap(),
            MutationMode.NONE,
            False,
            False,
            True,
            Dict[String, AnnotationOverrides](),
            Dict[String, String](),
        )
    except e:
        return String(e)
    return "no error"


def test_nullable_named_type() raises:
    var source = "query QueryName($id: ID) { id }"
    assert_equal(
        _tool_json(source),
        (
            '{"name":"QueryName","description":"The returned value is optional'
            " and has type"
            ' `String`","inputSchema":{"type":"object","properties":{"id":{"anyOf":[{"type":"string"},{"type":"null"}]}}},"outputSchema":{"type":"object","properties":{"data":{"type":"object","properties":{"id":{"anyOf":[{"type":"string"},{"type":"null"}]}}},"errors":{"type":"array","items":{"type":"object","properties":{"message":{"type":"string"},"locations":{"type":"array","items":{"type":"object","properties":{"line":{"type":"integer"},"column":{"type":"integer"}}}},"path":{"type":"array","items":{"oneOf":[{"type":"string"},{"type":"integer"}]}},"extensions":{"type":"object"}},"required":["message"]}},"extensions":{"type":"object"}}},"annotations":{"readOnlyHint":true,"destructiveHint":false,"idempotentHint":true,"openWorldHint":true}}'
        ),
    )
    var tool = make_operation(source, test_schema()).tool.copy()
    assert_equal(
        sorted_json(tool.input_schema, tool.input_schema.root),
        '{"properties":{"id":{"anyOf":[{"type":"string"},{"type":"null"}]}},"type":"object"}',
    )


def test_variables_with_defaults_expose_default_and_are_optional() raises:
    var operation = make_operation(
        'query QueryName($id: ID = "abc", $flag: Boolean! = true, $limit:'
        + " Int!) { id }",
        test_schema(),
        enable_output_schema=False,
    )
    ref schema = operation.tool.input_schema
    assert_equal(
        schema.to_string(schema.root),
        '{"type":"object","properties":{"id":{"anyOf":[{"type":"string"},{"type":"null"}],"default":"abc"},"flag":{"type":"boolean","default":true},"limit":{"type":"integer"}},"required":["limit"]}',
    )


def test_non_nullable_named_type() raises:
    var source = "query QueryName($id: ID!) { id }"
    assert_equal(
        _tool_json(source),
        (
            '{"name":"QueryName","description":"The returned value is optional'
            " and has type"
            ' `String`","inputSchema":{"type":"object","properties":{"id":{"type":"string"}},"required":["id"]},"outputSchema":{"type":"object","properties":{"data":{"type":"object","properties":{"id":{"anyOf":[{"type":"string"},{"type":"null"}]}}},"errors":{"type":"array","items":{"type":"object","properties":{"message":{"type":"string"},"locations":{"type":"array","items":{"type":"object","properties":{"line":{"type":"integer"},"column":{"type":"integer"}}}},"path":{"type":"array","items":{"oneOf":[{"type":"string"},{"type":"integer"}]}},"extensions":{"type":"object"}},"required":["message"]}},"extensions":{"type":"object"}}},"annotations":{"readOnlyHint":true,"destructiveHint":false,"idempotentHint":true,"openWorldHint":true}}'
        ),
    )
    assert_equal(
        _schema_json(source),
        '{"type":"object","properties":{"id":{"type":"string"}},"required":["id"]}',
    )


def test_non_nullable_list_of_nullable_named_type() raises:
    var source = "query QueryName($id: [ID]!) { id }"
    assert_equal(
        _tool_json(source),
        (
            '{"name":"QueryName","description":"The returned value is optional'
            " and has type"
            ' `String`","inputSchema":{"type":"object","properties":{"id":{"type":"array","items":{"anyOf":[{"type":"string"},{"type":"null"}]}}},"required":["id"]},"outputSchema":{"type":"object","properties":{"data":{"type":"object","properties":{"id":{"anyOf":[{"type":"string"},{"type":"null"}]}}},"errors":{"type":"array","items":{"type":"object","properties":{"message":{"type":"string"},"locations":{"type":"array","items":{"type":"object","properties":{"line":{"type":"integer"},"column":{"type":"integer"}}}},"path":{"type":"array","items":{"oneOf":[{"type":"string"},{"type":"integer"}]}},"extensions":{"type":"object"}},"required":["message"]}},"extensions":{"type":"object"}}},"annotations":{"readOnlyHint":true,"destructiveHint":false,"idempotentHint":true,"openWorldHint":true}}'
        ),
    )
    assert_equal(
        _schema_json(source),
        '{"type":"object","properties":{"id":{"type":"array","items":{"anyOf":[{"type":"string"},{"type":"null"}]}}},"required":["id"]}',
    )


def test_non_nullable_list_of_non_nullable_named_type() raises:
    var source = "query QueryName($id: [ID!]!) { id }"
    assert_equal(
        _tool_json(source),
        (
            '{"name":"QueryName","description":"The returned value is optional'
            " and has type"
            ' `String`","inputSchema":{"type":"object","properties":{"id":{"type":"array","items":{"type":"string"}}},"required":["id"]},"outputSchema":{"type":"object","properties":{"data":{"type":"object","properties":{"id":{"anyOf":[{"type":"string"},{"type":"null"}]}}},"errors":{"type":"array","items":{"type":"object","properties":{"message":{"type":"string"},"locations":{"type":"array","items":{"type":"object","properties":{"line":{"type":"integer"},"column":{"type":"integer"}}}},"path":{"type":"array","items":{"oneOf":[{"type":"string"},{"type":"integer"}]}},"extensions":{"type":"object"}},"required":["message"]}},"extensions":{"type":"object"}}},"annotations":{"readOnlyHint":true,"destructiveHint":false,"idempotentHint":true,"openWorldHint":true}}'
        ),
    )
    assert_equal(
        _schema_json(source),
        '{"type":"object","properties":{"id":{"type":"array","items":{"type":"string"}}},"required":["id"]}',
    )


def test_nullable_list_of_nullable_named_type() raises:
    var source = "query QueryName($id: [ID]) { id }"
    assert_equal(
        _tool_json(source),
        (
            '{"name":"QueryName","description":"The returned value is optional'
            " and has type"
            ' `String`","inputSchema":{"type":"object","properties":{"id":{"anyOf":[{"type":"array","items":{"anyOf":[{"type":"string"},{"type":"null"}]}},{"type":"null"}]}}},"outputSchema":{"type":"object","properties":{"data":{"type":"object","properties":{"id":{"anyOf":[{"type":"string"},{"type":"null"}]}}},"errors":{"type":"array","items":{"type":"object","properties":{"message":{"type":"string"},"locations":{"type":"array","items":{"type":"object","properties":{"line":{"type":"integer"},"column":{"type":"integer"}}}},"path":{"type":"array","items":{"oneOf":[{"type":"string"},{"type":"integer"}]}},"extensions":{"type":"object"}},"required":["message"]}},"extensions":{"type":"object"}}},"annotations":{"readOnlyHint":true,"destructiveHint":false,"idempotentHint":true,"openWorldHint":true}}'
        ),
    )
    assert_equal(
        _schema_json(source),
        '{"type":"object","properties":{"id":{"anyOf":[{"type":"array","items":{"anyOf":[{"type":"string"},{"type":"null"}]}},{"type":"null"}]}}}',
    )


def test_nullable_list_of_non_nullable_named_type() raises:
    var source = "query QueryName($id: [ID!]) { id }"
    assert_equal(
        _tool_json(source),
        (
            '{"name":"QueryName","description":"The returned value is optional'
            " and has type"
            ' `String`","inputSchema":{"type":"object","properties":{"id":{"anyOf":[{"type":"array","items":{"type":"string"}},{"type":"null"}]}}},"outputSchema":{"type":"object","properties":{"data":{"type":"object","properties":{"id":{"anyOf":[{"type":"string"},{"type":"null"}]}}},"errors":{"type":"array","items":{"type":"object","properties":{"message":{"type":"string"},"locations":{"type":"array","items":{"type":"object","properties":{"line":{"type":"integer"},"column":{"type":"integer"}}}},"path":{"type":"array","items":{"oneOf":[{"type":"string"},{"type":"integer"}]}},"extensions":{"type":"object"}},"required":["message"]}},"extensions":{"type":"object"}}},"annotations":{"readOnlyHint":true,"destructiveHint":false,"idempotentHint":true,"openWorldHint":true}}'
        ),
    )
    assert_equal(
        _schema_json(source),
        '{"type":"object","properties":{"id":{"anyOf":[{"type":"array","items":{"type":"string"}},{"type":"null"}]}}}',
    )


def test_nullable_list_of_nullable_lists_of_nullable_named_types() raises:
    var source = "query QueryName($id: [[ID]]) { id }"
    assert_equal(
        _tool_json(source),
        (
            '{"name":"QueryName","description":"The returned value is optional'
            " and has type"
            ' `String`","inputSchema":{"type":"object","properties":{"id":{"anyOf":[{"type":"array","items":{"anyOf":[{"type":"array","items":{"anyOf":[{"type":"string"},{"type":"null"}]}},{"type":"null"}]}},{"type":"null"}]}}},"outputSchema":{"type":"object","properties":{"data":{"type":"object","properties":{"id":{"anyOf":[{"type":"string"},{"type":"null"}]}}},"errors":{"type":"array","items":{"type":"object","properties":{"message":{"type":"string"},"locations":{"type":"array","items":{"type":"object","properties":{"line":{"type":"integer"},"column":{"type":"integer"}}}},"path":{"type":"array","items":{"oneOf":[{"type":"string"},{"type":"integer"}]}},"extensions":{"type":"object"}},"required":["message"]}},"extensions":{"type":"object"}}},"annotations":{"readOnlyHint":true,"destructiveHint":false,"idempotentHint":true,"openWorldHint":true}}'
        ),
    )
    assert_equal(
        _schema_json(source),
        '{"type":"object","properties":{"id":{"anyOf":[{"type":"array","items":{"anyOf":[{"type":"array","items":{"anyOf":[{"type":"string"},{"type":"null"}]}},{"type":"null"}]}},{"type":"null"}]}}}',
    )


def test_nullable_input_object() raises:
    assert_equal(
        _tool_json("query QueryName($id: RealInputObject) { id }"),
        (
            '{"name":"QueryName","description":"The returned value is optional'
            " and has type"
            ' `String`","inputSchema":{"type":"object","properties":{"id":{"anyOf":[{"$ref":"#/definitions/RealInputObject"},{"type":"null"}]}},"definitions":{"RealInputObject":{"type":"object","properties":{"optional":{"description":"optional'
            " is a input field that is"
            ' optional","anyOf":[{"type":"string"},{"type":"null"}]},"required":{"description":"required'
            " is a input field that is"
            ' required","type":"string"}},"required":["required"]}}},"outputSchema":{"type":"object","properties":{"data":{"type":"object","properties":{"id":{"anyOf":[{"type":"string"},{"type":"null"}]}}},"errors":{"type":"array","items":{"type":"object","properties":{"message":{"type":"string"},"locations":{"type":"array","items":{"type":"object","properties":{"line":{"type":"integer"},"column":{"type":"integer"}}}},"path":{"type":"array","items":{"oneOf":[{"type":"string"},{"type":"integer"}]}},"extensions":{"type":"object"}},"required":["message"]}},"extensions":{"type":"object"}}},"annotations":{"readOnlyHint":true,"destructiveHint":false,"idempotentHint":true,"openWorldHint":true}}'
        ),
    )


def test_non_nullable_enum() raises:
    assert_equal(
        _tool_json("query QueryName($id: RealEnum!) { id }"),
        (
            '{"name":"QueryName","description":"The returned value is optional'
            " and has type"
            ' `String`","inputSchema":{"type":"object","properties":{"id":{"$ref":"#/definitions/RealEnum"}},"required":["id"],"definitions":{"RealEnum":{"description":"the'
            " description for the enum\\n\\nValues:\\nENUM_VALUE_1:"
            " ENUM_VALUE_1 is a value\\nENUM_VALUE_2: ENUM_VALUE_2 is a"
            ' value","type":"string","enum":["ENUM_VALUE_1","ENUM_VALUE_2"]}}},"outputSchema":{"type":"object","properties":{"data":{"type":"object","properties":{"id":{"anyOf":[{"type":"string"},{"type":"null"}]}}},"errors":{"type":"array","items":{"type":"object","properties":{"message":{"type":"string"},"locations":{"type":"array","items":{"type":"object","properties":{"line":{"type":"integer"},"column":{"type":"integer"}}}},"path":{"type":"array","items":{"oneOf":[{"type":"string"},{"type":"integer"}]}},"extensions":{"type":"object"}},"required":["message"]}},"extensions":{"type":"object"}}},"annotations":{"readOnlyHint":true,"destructiveHint":false,"idempotentHint":true,"openWorldHint":true}}'
        ),
    )


def test_multiple_operations_should_error() raises:
    assert_equal(
        _error(
            "query QueryName { id } query QueryName { id }",
            String("operation.graphql"),
        ),
        "operation.graphql: Too many operations. Expected 1 but got 2",
    )


def test_unnamed_operations_should_be_skipped() raises:
    var found = Operation.from_raw(
        RawOperation("query { id }", String("operation.graphql")),
        test_schema(),
        CustomScalarMap(),
        MutationMode.NONE,
        False,
        False,
        True,
        Dict[String, AnnotationOverrides](),
        Dict[String, String](),
    )
    assert_false(Bool(found))


def test_no_operations_should_error() raises:
    assert_equal(
        _error("fragment Test on Query { id }", String("operation.graphql")),
        "operation.graphql: No operations defined",
    )


def test_schema_should_error() raises:
    assert_equal(
        _error("type Query { id: String }", None), "No operations defined"
    )


def test_unknown_type_should_be_any() raises:
    assert_equal(
        _tool_json("query QueryName($id: FakeType) { id }"),
        (
            '{"name":"QueryName","description":"The returned value is optional'
            " and has type"
            ' `String`","inputSchema":{"type":"object","properties":{"id":{"anyOf":[{},{"type":"null"}]}}},"outputSchema":{"type":"object","properties":{"data":{"type":"object","properties":{"id":{"anyOf":[{"type":"string"},{"type":"null"}]}}},"errors":{"type":"array","items":{"type":"object","properties":{"message":{"type":"string"},"locations":{"type":"array","items":{"type":"object","properties":{"line":{"type":"integer"},"column":{"type":"integer"}}}},"path":{"type":"array","items":{"oneOf":[{"type":"string"},{"type":"integer"}]}},"extensions":{"type":"object"}},"required":["message"]}},"extensions":{"type":"object"}}},"annotations":{"readOnlyHint":true,"destructiveHint":false,"idempotentHint":true,"openWorldHint":true}}'
        ),
    )


def test_custom_scalar_without_map_should_be_any() raises:
    assert_equal(
        _tool_json("query QueryName($id: RealCustomScalar) { id }"),
        (
            '{"name":"QueryName","description":"The returned value is optional'
            " and has type"
            ' `String`","inputSchema":{"type":"object","properties":{"id":{"anyOf":[{"$ref":"#/definitions/RealCustomScalar"},{"type":"null"}]}},"definitions":{"RealCustomScalar":{"description":"RealCustomScalar'
            ' exists"}}},"outputSchema":{"type":"object","properties":{"data":{"type":"object","properties":{"id":{"anyOf":[{"type":"string"},{"type":"null"}]}}},"errors":{"type":"array","items":{"type":"object","properties":{"message":{"type":"string"},"locations":{"type":"array","items":{"type":"object","properties":{"line":{"type":"integer"},"column":{"type":"integer"}}}},"path":{"type":"array","items":{"oneOf":[{"type":"string"},{"type":"integer"}]}},"extensions":{"type":"object"}},"required":["message"]}},"extensions":{"type":"object"}}},"annotations":{"readOnlyHint":true,"destructiveHint":false,"idempotentHint":true,"openWorldHint":true}}'
        ),
    )


def test_custom_scalar_with_map_but_not_found_should_error() raises:
    var operation = make_operation(
        "query QueryName($id: RealCustomScalar) { id }",
        test_schema(),
        custom_scalars=CustomScalarMap.parse("{}"),
    )
    assert_equal(
        operation.tool.to_json(),
        (
            '{"name":"QueryName","description":"The returned value is optional'
            " and has type"
            ' `String`","inputSchema":{"type":"object","properties":{"id":{"anyOf":[{"$ref":"#/definitions/RealCustomScalar"},{"type":"null"}]}},"definitions":{"RealCustomScalar":{"description":"RealCustomScalar'
            ' exists"}}},"outputSchema":{"type":"object","properties":{"data":{"type":"object","properties":{"id":{"anyOf":[{"type":"string"},{"type":"null"}]}}},"errors":{"type":"array","items":{"type":"object","properties":{"message":{"type":"string"},"locations":{"type":"array","items":{"type":"object","properties":{"line":{"type":"integer"},"column":{"type":"integer"}}}},"path":{"type":"array","items":{"oneOf":[{"type":"string"},{"type":"integer"}]}},"extensions":{"type":"object"}},"required":["message"]}},"extensions":{"type":"object"}}},"annotations":{"readOnlyHint":true,"destructiveHint":false,"idempotentHint":true,"openWorldHint":true}}'
        ),
    )


def test_custom_scalar_with_map() raises:
    var operation = make_operation(
        "query QueryName($id: RealCustomScalar) { id }",
        test_schema(),
        custom_scalars=CustomScalarMap.parse(
            '{ "RealCustomScalar": { "type": "string" }}'
        ),
    )
    assert_equal(
        operation.tool.to_json(),
        (
            '{"name":"QueryName","description":"The returned value is optional'
            " and has type"
            ' `String`","inputSchema":{"type":"object","properties":{"id":{"anyOf":[{"$ref":"#/definitions/RealCustomScalar"},{"type":"null"}]}},"definitions":{"RealCustomScalar":{"description":"RealCustomScalar'
            ' exists","type":"string"}}},"outputSchema":{"type":"object","properties":{"data":{"type":"object","properties":{"id":{"anyOf":[{"type":"string"},{"type":"null"}]}}},"errors":{"type":"array","items":{"type":"object","properties":{"message":{"type":"string"},"locations":{"type":"array","items":{"type":"object","properties":{"line":{"type":"integer"},"column":{"type":"integer"}}}},"path":{"type":"array","items":{"oneOf":[{"type":"string"},{"type":"integer"}]}},"extensions":{"type":"object"}},"required":["message"]}},"extensions":{"type":"object"}}},"annotations":{"readOnlyHint":true,"destructiveHint":false,"idempotentHint":true,"openWorldHint":true}}'
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

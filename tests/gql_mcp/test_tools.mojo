# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the tool calls of `gql_mcp.tools`.

The calls are `introspect`, `search`, `validate` and `execute`.

Ports the tests of Apollo MCP Server 2.0.0
`crates/apollo-mcp-server/src/introspection/tools/introspect.rs`,
`validate.rs` and `execute.rs`; the texts come from the upstream binary.
"""

from _tools_fixture import SEARCH_USER_SNAPSHOT, TOOLS_SCHEMA
from gql_json.parser import parse
from gql_json.value import JsonDocument, NO_NODE
from gql_mcp.builtin_tools import introspect_tool, search_tool
from gql_mcp.schema_index import RootTypes, SchemaIndex
from gql_mcp.call_result import CallToolResult
from gql_mcp.tool import MutationMode
from gql_mcp.tools import ExecuteRequest, prepare_execute, run_introspect
from gql_mcp.tools import run_search, run_validate
from gql_schema.build import build_schema
from gql_schema.definition import Schema
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _args(json: StringSlice) raises -> JsonDocument:
    return parse(json)


def _introspect(
    schema: Schema, json: StringSlice, allow: Bool = False, minify: Bool = False
) raises -> CallToolResult:
    var document = _args(json)
    var node = document.root if String(json) != "null" else NO_NODE
    return run_introspect(schema, document, node, allow, minify)


def _joined(result: CallToolResult) -> String:
    var out = String()
    for text in result.content:
        out += text + "\n"
    return out^


def test_introspect_tool_description_is_not_minified() raises:
    var description = introspect_tool(
        None, None, False, None
    ).description.value()
    assert_true(
        "Get information about a given GraphQL type defined in the schema"
        in description
    )
    assert_true(
        "Instructions: Use this tool to explore the schema" in description
    )
    assert_false("T=type,I=input" in description)
    assert_true("If the search tool is also available" in description)


def test_introspect_tool_description_is_minified_with_an_appropriate_legend() raises:
    var description = introspect_tool(
        None, None, True, None
    ).description.value()
    assert_true("T=type,I=input,E=enum,U=union,F=interface" in description)
    assert_true("s=String,i=Int,f=Float,b=Boolean,d=ID" in description)


def test_introspect_query_depth_1_returns_fields() raises:
    var schema = build_schema(TOOLS_SCHEMA)
    var result = _introspect(schema, '{"type_name":"Query","depth":1}', True)
    assert_false(result.is_error)
    assert_true(len(result.content) > 0)
    assert_true("type Query" in _joined(result))


def test_introspect_mutation_depth_1_returns_fields() raises:
    var schema = build_schema(TOOLS_SCHEMA)
    var result = _introspect(schema, '{"type_name":"Mutation","depth":1}', True)
    assert_true("type Mutation" in _joined(result))


def test_introspect_mutation_depth_1_with_mutations_disabled() raises:
    var schema = build_schema(TOOLS_SCHEMA)
    var result = _introspect(schema, '{"type_name":"Mutation","depth":1}')
    assert_true(len(result.content) > 0)
    assert_true("type Mutation" in _joined(result))


def test_introspect_inputs_and_limits() raises:
    var schema = build_schema(
        "type Query { a: A } type A { b: B, q: Query, mu: Mutation,"
        + " su: Subscription } type B { c: Int }"
        + " type Mutation { m: A } type Subscription { s: A }"
    )
    assert_equal(
        _introspect(schema, '{"type_name":5}').content[0],
        "Invalid input: invalid type: integer `5`, expected a string",
    )
    assert_equal(
        _introspect(schema, "null").content[0],
        "Invalid input: invalid type: null, expected struct Input",
    )
    var missing = _introspect(schema, '{"type_name":"Nope"}')
    assert_false(missing.is_error)
    assert_equal(len(missing.content), 0)
    assert_equal(len(_introspect(schema, '{"type_name":"A"}').content), 1)
    assert_equal(
        len(_introspect(schema, '{"type_name":"A","depth":2}').content), 3
    )
    var all = _introspect(schema, '{"type_name":"A","depth":0}')
    assert_false("type Mutation" in _joined(all))
    assert_false("type Subscription" in _joined(all))
    assert_true("type B" in _joined(all))
    var shown = _introspect(schema, '{"type_name":"A","depth":0}', True)
    assert_true("type Query" in _joined(shown))
    var minified = _introspect(schema, '{"type_name":"B"}', False, True)
    assert_true(minified.content[0].startswith("T:B"), minified.content[0])
    assert_true("type Mutation" in _joined(shown))
    assert_false("type Subscription" in _joined(shown))


def _validate(json: StringSlice) raises -> CallToolResult:
    var schema = build_schema(
        "type Query { id: ID! hello(name: String!): String! }"
    )
    var document = _args(json)
    return run_validate(schema, document, document.root)


def test_validate_valid_query() raises:
    var result = _validate('{"operation":"query Test { id }"}')
    assert_false(result.is_error)
    assert_equal(result.content[0], "Operation is valid")


def test_validate_invalid_graphql_query() raises:
    var result = _validate('{"operation":"query {"}')
    assert_true(result.is_error)
    assert_true(
        result.content[0].startswith("Could not parse GraphQL document: ")
    )


def test_validate_invalid_query_field() raises:
    var result = _validate('{"operation":"query { invalidField }"}')
    assert_true(result.is_error)
    assert_true(
        result.content[0].startswith(
            'Cannot query field "invalidField" on type "Query".'
        ),
        result.content[0],
    )


def test_validate_invalid_argument() raises:
    assert_true(_validate('{"operation":"query { hello }"}').is_error)


def test_validate_inputs() raises:
    assert_equal(
        _validate('{"operation":1}').content[0],
        "Invalid input: invalid type: integer `1`, expected a string",
    )
    assert_equal(
        _validate('{"operation":"subscription S { id }"}').content[0],
        "Invalid operation type",
    )
    # graphql-js 16 has no rule for an operation type that the schema lacks.
    assert_false(_validate('{"operation":"mutation M { id }"}').is_error)


def _execute(
    json: StringSlice, mode: MutationMode = MutationMode.NONE
) raises -> ExecuteRequest:
    var document = _args(json)
    return prepare_execute(document, document.root, mode)


def _execute_error(
    json: StringSlice, mode: MutationMode = MutationMode.NONE
) -> String:
    try:
        _ = _execute(json, mode)
    except e:
        return String(e)
    return "no error"


comptime _GET_USER = "query GetUser($id: ID!) { user(id: $id) { id name } }"


def test_execute_query_with_variables_as_string() raises:
    var request = _execute(
        '{"query":"' + _GET_USER + '","variables":"{\\"id\\":\\"123\\"}"}'
    )
    assert_equal(request.query, _GET_USER)
    assert_equal(request.operation_name.value(), "GetUser")
    assert_equal(request.variables, '{"id":"123"}')


def test_execute_query_with_variables_as_json() raises:
    var request = _execute(
        '{"query":"' + _GET_USER + '","variables":{"id":"123"}}'
    )
    assert_equal(request.operation_name.value(), "GetUser")
    assert_equal(request.variables, '{"id":"123"}')


def test_execute_query_without_variables() raises:
    var request = _execute('{"query":"' + _GET_USER + '"}')
    assert_equal(request.variables, "null")
    assert_equal(
        _execute('{"query":"{ a }","variables":null}').variables, "null"
    )
    assert_equal(_execute('{"query":"{ a }","variables":"5"}').variables, "5")


def test_execute_query_anonymous_operation() raises:
    var request = _execute('{"query":"{ user(id: \\"123\\") { id name } }"}')
    assert_equal(request.query, '{ user(id: "123") { id name } }')
    assert_false(Bool(request.operation_name))


def test_execute_query_err_with_mutation_when_mutation_mode_is_none() raises:
    assert_equal(
        _execute_error('{"query":"mutation MutationName { id }"}'),
        "Invalid operation type",
    )


def test_execute_query_ok_with_mutation_when_mutation_mode_is_all() raises:
    var request = _execute(
        '{"query":"mutation MutationName { id }"}', MutationMode.ALL
    )
    assert_equal(request.operation_name.value(), "MutationName")


def test_execute_query_err_with_subscription_regardless_of_mutation_mode() raises:
    var query = '{"query":"subscription SubscriptionName { id }"}'
    assert_equal(
        _execute_error(query, MutationMode.NONE), "Invalid operation type"
    )
    assert_equal(
        _execute_error(query, MutationMode.EXPLICIT), "Invalid operation type"
    )
    assert_equal(
        _execute_error(query, MutationMode.ALL), "Invalid operation type"
    )


def test_execute_query_invalid_input() raises:
    assert_equal(
        _execute_error('{"nonsense":"whatever"}'),
        "Invalid input: missing field `query`",
    )


def test_execute_query_invalid_variables() raises:
    var message = _execute_error('{"query":"{ a }","variables":"garbage"}')
    assert_true(message.startswith("Invalid variables: "), message)
    assert_equal(
        _execute_error('{"query":"{ a }","variables":5}'),
        "Variables must be a JSON object or string",
    )
    assert_equal(
        _execute_error('{"query":"query A { a } query B { b }"}'),
        "Too many operations. Expected 1 but got 2",
    )


def _search(
    json: StringSlice, allow: Bool, minify: Bool = False
) raises -> CallToolResult:
    var schema = build_schema(TOOLS_SCHEMA)
    var roots = (
        RootTypes.QUERY | RootTypes.MUTATION if allow else RootTypes.QUERY
    )
    var index = SchemaIndex(schema, roots)
    var document = _args(json)
    var node = document.root if String(json) != "null" else NO_NODE
    return run_search(schema, index, document, node, allow, 1, minify)


def _snapshot(result: CallToolResult) -> String:
    var out = String()
    var index = 0
    while index < len(result.content):
        if index > 0:
            out += "\n"
        out += result.content[index]
        index += 1
    return String(out.rstrip())


def test_search_tool() raises:
    var result = _search('{"terms":["User"]}', False)
    assert_false(result.is_error)
    assert_equal(
        _snapshot(result), String(String(SEARCH_USER_SNAPSHOT).rstrip())
    )


def test_referencing_types_are_collected() raises:
    var result = _search('{"terms":["User"]}', True)
    assert_false(result.is_error)
    assert_true("createUser" in _snapshot(result))


def test_search_tool_description_is_not_minified() raises:
    var description = search_tool(False, None).description.value()
    assert_true(
        "Search a GraphQL schema for types matching the provided search terms"
        in description
    )
    assert_true(
        "Instructions: If the introspect tool is also available" in description
    )
    assert_true("Avoid reusing previously searched terms" in description)
    assert_false("T=type,I=input" in description)


def test_tool_description_minified() raises:
    var description = search_tool(True, None).description.value()
    assert_true("T=type,I=input,E=enum,U=union,F=interface" in description)
    assert_true("s=String,i=Int,f=Float,b=Boolean,d=ID" in description)


def test_search_inputs() raises:
    assert_equal(
        _search('{"terms":"x"}', False).content[0],
        'Invalid input: invalid type: string "x", expected a sequence',
    )
    assert_equal(len(_search('{"terms":[]}', False).content), 0)
    var minified = _search('{"terms":["User"]}', False, True)
    assert_true(len(minified.content) > 0)
    assert_false("type User" in _snapshot(minified))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()


def test_coverage_edges() raises:
    var schema = build_schema("type Query")
    var document = _args('{"operation":"{ a }"}')
    var invalid = run_validate(schema, document, document.root)
    assert_true(invalid.is_error)
    assert_true("Query" in invalid.content[0], invalid.content[0])
    var types = build_schema("type Query { a: A } type A { b: Int }")
    var huge = _introspect(
        types, '{"type_name":"Query","depth":18446744073709551615}'
    )
    assert_true("type A" in _joined(huge))

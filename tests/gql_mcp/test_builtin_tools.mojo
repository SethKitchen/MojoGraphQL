# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_mcp.builtin_tools` and `gql_mcp.tool_input`.

Ports the tests of Apollo MCP Server 2.0.0
`crates/apollo-mcp-server/src/introspection/tools/description.rs` and the
annotation test of `introspection/tools/execute.rs`. The expected tool JSON
is the `tools/list` output of the upstream binary, and the input messages
are its `Invalid input` texts.
"""

from gql_json.parser import parse
from gql_json.value import NO_NODE
from gql_mcp.builtin_tools import (
    append_description_hint,
    execute_tool,
    introspect_tool,
    search_tool,
    validate_tool,
)
from gql_mcp.tool import MutationMode
from gql_mcp.tool_input import FieldKind, InputField, check_input
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime _LOOKUP = '"annotations":{"readOnlyHint":true,"destructiveHint":false,"idempotentHint":true,"openWorldHint":false}}'


def test_returns_default_when_hint_is_none() raises:
    assert_equal(append_description_hint("Default", None), "Default")


def test_returns_default_when_hint_is_whitespace() raises:
    assert_equal(
        append_description_hint("Default", String("   \n\t")), "Default"
    )


def test_appends_additional_instructions_when_hint_is_present() raises:
    assert_equal(
        append_description_hint(
            "Default", String("Use carts(where: { status: ACTIVE })")
        ),
        "Default\nHint: Use carts(where: { status: ACTIVE })",
    )


def test_execute_annotations_follow_mutation_mode() raises:
    var none = execute_tool(MutationMode.NONE, None).annotations.value().copy()
    assert_true(none.read_only_hint.value())
    assert_false(none.destructive_hint.value())
    assert_true(none.idempotent_hint.value())
    assert_true(none.open_world_hint.value())
    var explicit = (
        execute_tool(MutationMode.EXPLICIT, None).annotations.value().copy()
    )
    assert_true(explicit.read_only_hint.value())
    var all = execute_tool(MutationMode.ALL, None).annotations.value().copy()
    assert_false(all.read_only_hint.value())
    assert_true(all.destructive_hint.value())
    assert_false(all.idempotent_hint.value())
    assert_true(all.open_world_hint.value())


def test_tool_json_matches_upstream() raises:
    assert_equal(
        execute_tool(MutationMode.NONE, None).to_json(),
        (
            '{"name":"execute","description":"Execute a GraphQL operation. Use'
            " the `introspect` tool to get information about the GraphQL"
            " schema. Always use the schema to create operations - do not try"
            " arbitrary operations. If available, first use the `validate` tool"
            " to validate operations. DO NOT try to execute introspection"
            ' queries.","inputSchema":{"$schema":"http://json-schema.org/draft-07/schema#","title":"Input","description":"Input'
            " for the execute"
            ' tool.","type":"object","properties":{"query":{"description":"The'
            " GraphQL"
            ' operation","type":"string"},"variables":{"description":"The'
            " variable values represented as"
            ' JSON","type":"string","default":null}},"required":["query"]},"annotations":{"readOnlyHint":true,"destructiveHint":false,"idempotentHint":true,"openWorldHint":true}}'
        ),
    )
    assert_equal(
        introspect_tool(String("Query"), None, False, None).to_json(),
        '{"name":"introspect","description":"Get information about a given'
        " GraphQL type defined in the schema. Instructions: Use this tool to"
        " explore the schema by providing specific type names. Start with the"
        " root query (Query) or mutation (Mutation) types to discover available"
        " fields. If the search tool is also available, use this tool first to"
        " get the fields, then use the search tool with relevant field return"
        " types and argument input types (ignore default GraphQL scalars) as"
        " search"
        ' terms.","inputSchema":{"$schema":"http://json-schema.org/draft-07/schema#","title":"Input","description":"Input'
        " for the introspect"
        ' tool.","type":"object","properties":{"type_name":{"description":"The'
        " name of the type to get information"
        ' about.","type":"string"},"depth":{"description":"How far to recurse'
        " the type hierarchy. Use 0 for no limit. Defaults to"
        ' 1.","type":"integer","format":"uint","minimum":0,"default":1}},"required":["type_name"]},'
        + _LOOKUP,
    )
    assert_equal(
        search_tool(False, None).to_json(),
        '{"name":"search","description":"Search a GraphQL schema for types'
        " matching the provided search terms. Returns complete type definitions"
        " including all related types needed to construct GraphQL operations."
        " Instructions: If the introspect tool is also available, you can"
        " discover type names by using the introspect tool starting from the"
        " root Query or Mutation types. Avoid reusing previously searched terms"
        " for more efficient"
        ' exploration.","inputSchema":{"$schema":"http://json-schema.org/draft-07/schema#","title":"Input","description":"Input'
        " for the search"
        ' tool.","type":"object","properties":{"terms":{"description":"The'
        " search"
        ' terms","type":"array","items":{"type":"string"}}},"required":["terms"]},'
        + _LOOKUP,
    )
    assert_equal(
        validate_tool(None).to_json(),
        '{"name":"validate","description":"Validates a GraphQL operation'
        " against the schema. Use the `introspect` tool first to get"
        " information about the GraphQL schema. Operations should be validated"
        " prior to calling the `execute`"
        ' tool.","inputSchema":{"$schema":"http://json-schema.org/draft-07/schema#","title":"Input","description":"Input'
        " for the validate"
        ' tool","type":"object","properties":{"operation":{"description":"The'
        ' GraphQL operation","type":"string"}},"required":["operation"]},'
        + _LOOKUP,
    )


def test_minified_descriptions() raises:
    var legend = "T=type,I=input,E=enum,U=union,F=interface;s=String,i=Int,f=Float,b=Boolean,d=ID;@D=deprecated;!=required,[]=list,<>=implements"
    assert_equal(
        introspect_tool(None, None, True, None).description.value(),
        "Get GraphQL type information - " + legend + ";",
    )
    assert_true(
        search_tool(True, String("h"))
        .description.value()
        .endswith("exploration. - " + legend + "\nHint: h")
    )
    assert_true(
        "root query (Q) or mutation (M) types"
        in introspect_tool(
            String("Q"), String("M"), False, None
        ).description.value()
    )


def _message(arguments: StringSlice) raises -> String:
    var fields = List[InputField]()
    fields.append(InputField("type_name", FieldKind.STRING, True))
    fields.append(InputField("depth", FieldKind.USIZE, False))
    fields.append(InputField("terms", FieldKind.STRINGS, False))
    fields.append(InputField("variables", FieldKind.ANY, False))
    var document = parse(arguments)
    var node = document.root
    if arguments == "null":
        node = NO_NODE
    try:
        check_input(document, node, fields)
    except e:
        return String(e)
    return "ok"


def test_input_messages() raises:
    assert_equal(_message("null"), "invalid type: null, expected struct Input")
    assert_equal(
        _message("[1]"), "invalid type: sequence, expected struct Input"
    )
    assert_equal(_message("{}"), "missing field `type_name`")
    assert_equal(_message('{"type_name":"Q","extra":1}'), "ok")
    assert_equal(
        _message('{"type_name":"Q","type_name":"R"}'),
        "duplicate field `type_name`",
    )
    assert_equal(
        _message('{"type_name":5}'),
        "invalid type: integer `5`, expected a string",
    )
    assert_equal(
        _message('{"type_name":null}'), "invalid type: null, expected a string"
    )
    assert_equal(
        _message('{"type_name":true}'),
        "invalid type: boolean `true`, expected a string",
    )
    assert_equal(
        _message('{"type_name":false}'),
        "invalid type: boolean `false`, expected a string",
    )
    assert_equal(
        _message('{"type_name":{}}'), "invalid type: map, expected a string"
    )
    assert_equal(
        _message('{"depth":-1,"type_name":5}'),
        "invalid value: integer `-1`, expected usize",
    )
    assert_equal(
        _message('{"type_name":"Q","depth":1.5}'),
        "invalid type: floating point `1.5`, expected usize",
    )
    assert_equal(
        _message('{"type_name":"Q","depth":"2"}'),
        'invalid type: string "2", expected usize',
    )
    assert_equal(_message('{"type_name":"Q","depth":2,"variables":[]}'), "ok")
    assert_equal(
        _message('{"type_name":"Q","terms":"x"}'),
        'invalid type: string "x", expected a sequence',
    )
    assert_equal(
        _message('{"type_name":"Q","terms":["a",1]}'),
        "invalid type: integer `1`, expected a string",
    )
    assert_equal(_message('{"type_name":"Q","terms":[]}'), "ok")
    assert_equal(
        _message('{"type_name":["\\"q\\\\\\n\\r\\t\\u00e9"]}'),
        "invalid type: sequence, expected a string",
    )
    assert_equal(
        _message('{"depth":"\\"q\\\\\\n\\r\\t\\u00e9"}'),
        'invalid type: string "\\"q\\\\\\n\\r\\té", expected usize',
    )
    assert_equal(
        _message('{"depth":""}'), 'invalid type: string "", expected usize'
    )
    assert_true(FieldKind.ANY.is_valid())
    assert_false(FieldKind(4).is_valid())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

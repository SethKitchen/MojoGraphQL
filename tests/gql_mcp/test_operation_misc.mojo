# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_mcp.operation`: input object lists, operation types and
mutation modes, the character count, description overrides, the text sent
without descriptions and `@private`, and annotation overrides.

Ported from Apollo MCP Server 2.0.0 (04e4e6e)
`crates/apollo-mcp-server/src/operations/operation.rs` (the tests from
`nullable_list_of_nullable_input_objects` to the end). The expected JSON is
the upstream `serde_json` text of each insta snapshot. The tests that check
`private_fields` check `has_private_fields`: the field tree is phase 2.
"""

from _operation_fixtures import (
    json_text,
    make_operation,
    sorted_json,
    test_schema,
)
from gql_mcp.custom_scalar_map import CustomScalarMap
from gql_mcp.json_tree import JsonTree
from gql_mcp.operation import Operation, RawOperation, tool_character_length
from gql_mcp.tool import (
    AnnotationOverrides,
    MutationMode,
    Tool,
    ToolAnnotations,
)
from gql_schema.build import build_schema
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _from_raw(
    source: String,
    mode: MutationMode = MutationMode.NONE,
    annotations: Dict[String, AnnotationOverrides] = Dict[
        String, AnnotationOverrides
    ](),
    descriptions: Dict[String, String] = Dict[String, String](),
    output: Bool = True,
) raises -> Optional[Operation]:
    return Operation.from_raw(
        RawOperation(source, None),
        test_schema(),
        CustomScalarMap(),
        mode,
        False,
        False,
        output,
        annotations,
        descriptions,
    )


def _description(
    source: String, descriptions: Dict[String, String] = Dict[String, String]()
) raises -> String:
    var found = _from_raw(source, descriptions=descriptions, output=False)
    return found.value().tool.description.value()


def _with(schema_sdl: String, source: String) raises -> Operation:
    return make_operation(
        source, build_schema(schema_sdl), mode=MutationMode.ALL
    )


def test_nullable_list_of_nullable_input_objects() raises:
    var source = "query QueryName($objects: [RealInputObject]) { id }"
    var tool = make_operation(source, test_schema()).tool.copy()
    assert_equal(
        tool.to_json(),
        (
            '{"name":"QueryName","description":"The returned value is optional'
            " and has type"
            ' `String`","inputSchema":{"type":"object","properties":{"objects":{"anyOf":[{"type":"array","items":{"anyOf":[{"$ref":"#/definitions/RealInputObject"},{"type":"null"}]}},{"type":"null"}]}},"definitions":{"RealInputObject":{"type":"object","properties":{"optional":{"description":"optional'
            " is a input field that is"
            ' optional","anyOf":[{"type":"string"},{"type":"null"}]},"required":{"description":"required'
            " is a input field that is"
            ' required","type":"string"}},"required":["required"]}}},"outputSchema":{"type":"object","properties":{"data":{"type":"object","properties":{"id":{"anyOf":[{"type":"string"},{"type":"null"}]}}},"errors":{"type":"array","items":{"type":"object","properties":{"message":{"type":"string"},"locations":{"type":"array","items":{"type":"object","properties":{"line":{"type":"integer"},"column":{"type":"integer"}}}},"path":{"type":"array","items":{"oneOf":[{"type":"string"},{"type":"integer"}]}},"extensions":{"type":"object"}},"required":["message"]}},"extensions":{"type":"object"}}},"annotations":{"readOnlyHint":true,"destructiveHint":false,"idempotentHint":true,"openWorldHint":true}}'
        ),
    )
    assert_equal(
        sorted_json(tool.input_schema, tool.input_schema.root),
        (
            '{"definitions":{"RealInputObject":{"properties":{"optional":{"anyOf":[{"type":"string"},{"type":"null"}],"description":"optional'
            " is a input field that is"
            ' optional"},"required":{"description":"required is a input field'
            " that is"
            ' required","type":"string"}},"required":["required"],"type":"object"}},"properties":{"objects":{"anyOf":[{"items":{"anyOf":[{"$ref":"#/definitions/RealInputObject"},{"type":"null"}]},"type":"array"},{"type":"null"}]}},"type":"object"}'
        ),
    )


def test_non_nullable_list_of_non_nullable_input_objects() raises:
    var source = "query QueryName($objects: [RealInputObject!]!) { id }"
    var tool = make_operation(source, test_schema()).tool.copy()
    assert_equal(
        tool.to_json(),
        (
            '{"name":"QueryName","description":"The returned value is optional'
            " and has type"
            ' `String`","inputSchema":{"type":"object","properties":{"objects":{"type":"array","items":{"$ref":"#/definitions/RealInputObject"}}},"required":["objects"],"definitions":{"RealInputObject":{"type":"object","properties":{"optional":{"description":"optional'
            " is a input field that is"
            ' optional","anyOf":[{"type":"string"},{"type":"null"}]},"required":{"description":"required'
            " is a input field that is"
            ' required","type":"string"}},"required":["required"]}}},"outputSchema":{"type":"object","properties":{"data":{"type":"object","properties":{"id":{"anyOf":[{"type":"string"},{"type":"null"}]}}},"errors":{"type":"array","items":{"type":"object","properties":{"message":{"type":"string"},"locations":{"type":"array","items":{"type":"object","properties":{"line":{"type":"integer"},"column":{"type":"integer"}}}},"path":{"type":"array","items":{"oneOf":[{"type":"string"},{"type":"integer"}]}},"extensions":{"type":"object"}},"required":["message"]}},"extensions":{"type":"object"}}},"annotations":{"readOnlyHint":true,"destructiveHint":false,"idempotentHint":true,"openWorldHint":true}}'
        ),
    )
    assert_equal(
        sorted_json(tool.input_schema, tool.input_schema.root),
        (
            '{"definitions":{"RealInputObject":{"properties":{"optional":{"anyOf":[{"type":"string"},{"type":"null"}],"description":"optional'
            " is a input field that is"
            ' optional"},"required":{"description":"required is a input field'
            " that is"
            ' required","type":"string"}},"required":["required"],"type":"object"}},"properties":{"objects":{"items":{"$ref":"#/definitions/RealInputObject"},"type":"array"}},"required":["objects"],"type":"object"}'
        ),
    )


def test_subscriptions() raises:
    assert_false(Bool(_from_raw("subscription SubscriptionName { id }")))


def test_mutation_mode_none() raises:
    assert_false(Bool(_from_raw("mutation MutationName { id }")))


def _mutation_json() raises -> String:
    var query = make_operation(
        "query QueryName { id }", test_schema()
    ).tool.copy()
    ref output = query.output_schema.value()
    return (
        '{"name":"MutationName","description":"The returned value is optional'
        + ' and has type `String`","inputSchema":{"type":"object","properties":'
        + '{}},"outputSchema":'
        + output.to_string(output.root)
        + ',"annotations":{"readOnlyHint":false,"destructiveHint":true,'
        + '"openWorldHint":true}}'
    )


def test_mutation_mode_explicit() raises:
    var tool = (
        _from_raw("mutation MutationName { id }", MutationMode.EXPLICIT)
        .value()
        .tool.copy()
    )
    assert_equal(tool.to_json(), _mutation_json())


def test_mutation_mode_all() raises:
    var tool = (
        _from_raw("mutation MutationName { id }", MutationMode.ALL)
        .value()
        .tool.copy()
    )
    assert_equal(tool.to_json(), _mutation_json())


def test_no_variables() raises:
    var tool = make_operation(
        "query QueryName { id }", test_schema()
    ).tool.copy()
    assert_equal(
        tool.to_json(),
        (
            '{"name":"QueryName","description":"The returned value is optional'
            " and has type"
            ' `String`","inputSchema":{"type":"object","properties":{}},"outputSchema":{"type":"object","properties":{"data":{"type":"object","properties":{"id":{"anyOf":[{"type":"string"},{"type":"null"}]}}},"errors":{"type":"array","items":{"type":"object","properties":{"message":{"type":"string"},"locations":{"type":"array","items":{"type":"object","properties":{"line":{"type":"integer"},"column":{"type":"integer"}}}},"path":{"type":"array","items":{"oneOf":[{"type":"string"},{"type":"integer"}]}},"extensions":{"type":"object"}},"required":["message"]}},"extensions":{"type":"object"}}},"annotations":{"readOnlyHint":true,"destructiveHint":false,"idempotentHint":true,"openWorldHint":true}}'
        ),
    )
    assert_equal(
        tool.input_schema.to_string(tool.input_schema.root),
        '{"type":"object","properties":{}}',
    )


def _schema(json: String) raises -> JsonTree:
    from gql_json.parser import parse

    var document = parse(json)
    var tree = JsonTree()
    tree.root = tree.add_document(document, document.root)
    return tree^


comptime _INPUT = '{"type":"object","properties":{"id":{"type":"string"}}}'
comptime _INPUT_PRETTY = """{
  "type": "object",
  "properties": {
    "id": {
      "type": "string"
    }
  }
}"""


def test_tool_character_length_without_output_schema() raises:
    var tool = Tool(
        "test_tool", String("A test tool description"), _schema(_INPUT)
    )
    assert_equal(
        tool_character_length(tool),
        "test_tool".byte_length()
        + "A test tool description".byte_length()
        + _INPUT_PRETTY.byte_length(),
    )


def test_tool_character_length_with_output_schema() raises:
    var tool = Tool(
        "test_tool", String("A test tool description"), _schema(_INPUT)
    )
    tool.output_schema = _schema(
        '{"type":"object","properties":{"data":{"type":"object","properties":'
        + '{"result":{"type":"string"}}}}}'
    )
    var output_pretty = """{
  "type": "object",
  "properties": {
    "data": {
      "type": "object",
      "properties": {
        "result": {
          "type": "string"
        }
      }
    }
  }
}"""
    assert_equal(
        tool_character_length(tool),
        "test_tool".byte_length()
        + "A test tool description".byte_length()
        + _INPUT_PRETTY.byte_length()
        + output_pretty.byte_length(),
    )


def test_tool_character_length_output_schema_adds_to_total() raises:
    var without = Tool(
        "test_tool",
        String("A test tool description"),
        _schema('{"type":"object"}'),
    )
    var with_output = without.copy()
    with_output.output_schema = _schema(
        '{"type":"object","properties":{"data":{"type":"string"}}}'
    )
    var expected = """{
  "type": "object",
  "properties": {
    "data": {
      "type": "string"
    }
  }
}"""
    assert_equal(
        tool_character_length(with_output) - tool_character_length(without),
        expected.byte_length(),
    )
    without.description = None
    assert_equal(
        tool_character_length(without),
        "test_tool".byte_length() + '{\n  "type": "object"\n}'.byte_length(),
    )


def test_explicit_description_overrides_auto_generated() raises:
    var overrides = Dict[String, String]()
    overrides["QueryName"] = "My custom tool description from PQ manifest"
    assert_equal(
        _description("query QueryName($id: ID) { id }", overrides),
        "My custom tool description from PQ manifest",
    )


def test_no_explicit_description_falls_back_to_auto_generated() raises:
    var description = _description("query QueryName($id: ID) { id }")
    assert_true(description.byte_length() > 0)


def test_explicit_description_overrides_comments() raises:
    var overrides = Dict[String, String]()
    overrides["QueryName"] = "Override from manifest"
    assert_equal(
        _description(
            "# Comment-based description\nquery QueryName($id: ID) { id }",
            overrides,
        ),
        "Override from manifest",
    )


def test_operation_description_becomes_tool_description() raises:
    assert_equal(
        _description(
            '"""Look up a thing by ID"""\nquery QueryName($id: ID) { id }'
        ),
        "Look up a thing by ID",
    )


def test_multiline_operation_description_is_dedented() raises:
    assert_equal(
        _description(
            '"""\n    Look up a thing\n    by its ID\n"""\nquery QueryName($id:'
            + " ID) { id }"
        ),
        "Look up a thing\nby its ID",
    )


def test_operation_description_overrides_comments() raises:
    assert_equal(
        _description(
            '# Comment-based description\n"""Spec description"""\nquery'
            + " QueryName($id: ID) { id }"
        ),
        "Spec description",
    )


def test_explicit_description_overrides_operation_description() raises:
    var overrides = Dict[String, String]()
    overrides["QueryName"] = "Override from manifest"
    assert_equal(
        _description(
            '"""Spec description"""\nquery QueryName($id: ID) { id }', overrides
        ),
        "Override from manifest",
    )


def test_blank_operation_description_falls_back_to_comments() raises:
    assert_equal(
        _description(
            '# Comment-based description\n"""   """\nquery QueryName($id: ID) {'
            + " id }"
        ),
        "Comment-based description",
    )


def test_operation_with_descriptions_sends_text_without_them() raises:
    var operation = (
        _from_raw(
            (
                '"""Look up a thing"""\nquery QueryName("""The ID""" $id: ID) {'
                " id }"
            ),
            output=False,
        )
        .value()
        .copy()
    )
    assert_equal(
        operation.stripped_source_text.value(),
        json_text('"query QueryName($id: ID) { id }"'),
    )
    assert_equal(operation.query(), "query QueryName($id: ID) { id }")


def test_operation_with_private_field_and_description_sends_text_without_either() raises:
    var operation = _with(
        "type Query { fieldA: String, fieldB: String }",
        '"""Look up fields"""\nquery TestOp { fieldA fieldB @private }',
    )
    assert_equal(
        operation.stripped_source_text.value(),
        json_text('"query TestOp { fieldA fieldB }"'),
    )


def test_operation_without_private_has_no_stripped_text() raises:
    var operation = make_operation(
        "query TestOp { id }", test_schema(), mode=MutationMode.ALL
    )
    assert_false(Bool(operation.stripped_source_text))
    assert_false(operation.has_private_fields)


def test_operation_with_private_has_stripped_text() raises:
    var operation = _with(
        "type Query { fieldA: String, fieldB: String, fieldC: String }",
        "query TestOp { fieldA fieldB @private fieldC }",
    )
    assert_true(Bool(operation.stripped_source_text))
    assert_true(operation.has_private_fields)


def test_stripped_text_does_not_contain_private_directive() raises:
    var operation = _with(
        "type Query { fieldA: String, fieldB: String, fieldC: String }",
        "query TestOp { fieldA fieldB @private fieldC }",
    )
    var stripped = operation.stripped_source_text.value()
    assert_false("@private" in stripped)
    assert_true("fieldB" in stripped)


def test_operation_method_returns_stripped_text_when_private() raises:
    var operation = _with(
        "type Query { fieldA: String, fieldB: String }",
        "query TestOp { fieldA fieldB @private }",
    )
    assert_false("@private" in operation.query())


def test_operation_method_returns_original_text_when_no_private() raises:
    var operation = make_operation(
        "query TestOp { id }", test_schema(), mode=MutationMode.ALL
    )
    assert_equal(operation.query(), "query TestOp { id }")


def test_stripped_text_includes_fragment_definitions() raises:
    var operation = _with(
        """
            type Query { user: User }
            type User { name: String, email: String }
            """,
        """
            query GetUser { user { ...UserFields } }
            fragment UserFields on User { name email @private }
        """,
    )
    var stripped = operation.stripped_source_text.value()
    assert_true("fragment UserFields" in stripped)
    assert_false("@private" in stripped)
    assert_true(operation.has_private_fields)


def _annotations(
    overrides: Dict[String, AnnotationOverrides],
) raises -> ToolAnnotations:
    var found = _from_raw("query GetId { id }", annotations=overrides)
    return found.value().tool.annotations.value().copy()


def test_annotation_overrides_merge_with_auto_detected_for_query() raises:
    var overrides = Dict[String, AnnotationOverrides]()
    overrides["GetId"] = AnnotationOverrides(None, None, None, True, False)
    var ann = _annotations(overrides)
    assert_true(ann.read_only_hint.value())
    assert_false(ann.destructive_hint.value())
    assert_true(ann.idempotent_hint.value())
    assert_false(ann.open_world_hint.value())
    assert_false(Bool(ann.title))


def test_annotation_overrides_can_flip_auto_detected_hints() raises:
    var overrides = Dict[String, AnnotationOverrides]()
    overrides["GetId"] = AnnotationOverrides(None, False, True, None, None)
    var ann = _annotations(overrides)
    assert_false(ann.read_only_hint.value())
    assert_true(ann.destructive_hint.value())


def test_annotation_overrides_set_title() raises:
    var overrides = Dict[String, AnnotationOverrides]()
    overrides["GetId"] = AnnotationOverrides(
        String("My Tool Title"), None, None, None, None
    )
    assert_equal(_annotations(overrides).title.value(), "My Tool Title")


def test_no_annotation_overrides_keeps_auto_detected() raises:
    var ann = _annotations(Dict[String, AnnotationOverrides]())
    assert_true(ann.read_only_hint.value())
    assert_false(ann.destructive_hint.value())
    assert_true(ann.idempotent_hint.value())
    assert_true(ann.open_world_hint.value())
    assert_false(Bool(ann.title))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

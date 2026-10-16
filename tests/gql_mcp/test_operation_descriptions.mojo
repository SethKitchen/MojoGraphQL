# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_mcp.operation`: tool descriptions, variable descriptions
from the schema, the operation text and its comments, and fixed variables.

Ported from Apollo MCP Server 2.0.0 (04e4e6e)
`crates/apollo-mcp-server/src/operations/operation.rs` (the tests from
`tool_description` to `input_schema_include_properties_field_even_when_
operation_has_no_input_args`). The expected JSON and text are the upstream
values that each insta snapshot shows.
"""

from _operation_fixtures import (
    json_text,
    make_operation,
    sorted_json,
    test_schema,
)
from gql_mcp.custom_scalar_map import CustomScalarMap
from gql_mcp.json_tree import JsonTree
from gql_mcp.operation import Operation, RawOperation
from gql_mcp.tool import AnnotationOverrides, MutationMode
from gql_schema.build import build_schema
from std.testing import TestSuite, assert_equal, assert_false, assert_true


comptime ABZ_SCHEMA = '''
type Query {
  """
  Get a list of A
  """
  a(input: String!): [A]!

  """
  Get a B
  """
  b: B

  """
  Get a Z
  """
  z: Z
}

"""
A
"""
type A {
  c: String
  d: D
}

"""
B
"""
type B {
  d: D
  u: U
}

"""
D
"""
type D {
  e: E
  f: String
  g: String
}

"""
E
"""
enum E {
  """
  one
  """
  ONE
  """
  two
  """
  TWO
}

"""
F
"""
scalar F

"""
U
"""
union U = M | W

"""
M
"""
type M {
  m: Int
}

"""
W
"""
type W {
  w: Int
}

"""
Z
"""
type Z {
  z: Int
  zz: Int
  zzz: Int
}
'''

comptime ABZ_OPERATION = """
            query GetABZ($state: String!) {
              a(input: $input) {
                d {
                  e
                }
              }
              b {
                d {
                  ...JustF
                }
                u {
                  ... on M {
                    m
                  }
                  ... on W {
                    w
                  }
                }
              }
              z {
                ...JustZZZ
              }
            }

            fragment JustF on D {
              f
            }

            fragment JustZZZ on Z {
              zzz
            }
            """


def _description(
    source: String,
    disable_type: Bool = False,
    disable_schema: Bool = False,
) raises -> String:
    var operation = make_operation(
        source,
        test_schema(),
        disable_type_description=disable_type,
        disable_schema_description=disable_schema,
    )
    return operation.tool.description.value()


def _properties(source: String) raises -> String:
    var tool = make_operation(source, test_schema()).tool.copy()
    return sorted_json(tool.input_schema, tool.input_schema.root)


def _variable_description(source: String) raises -> String:
    var tool = make_operation(source, test_schema()).tool.copy()
    ref schema = tool.input_schema
    var properties = schema.find(schema.root, "properties")
    return schema.text(
        schema.find(schema.find(properties, "idArg"), "description")
    )


def test_tool_description() raises:
    var operation = make_operation(ABZ_OPERATION, build_schema(ABZ_SCHEMA))
    assert_equal(
        operation.tool.description.value(),
        json_text(
            '"Get a list of A\\nThe returned value is an array of type'
            " `A`\\n---\\nGet a B\\nThe returned value is optional and has type"
            " `B`\\n---\\nGet a Z\\nThe returned value is optional and has type"
            ' `Z`\\n---\\n\\"\\"\\"A\\"\\"\\"\\ntype A {\\n  d:'
            ' D\\n}\\n\\n\\"\\"\\"B\\"\\"\\"\\ntype B {\\n  d: D\\n  u:'
            ' U\\n}\\n\\n\\"\\"\\"D\\"\\"\\"\\ntype D {\\n  e: E\\n  f:'
            ' String\\n}\\n\\n\\"\\"\\"E\\"\\"\\"\\nenum E {\\n '
            ' \\"\\"\\"one\\"\\"\\"\\n  ONE\\n  \\"\\"\\"two\\"\\"\\"\\n '
            ' TWO\\n}\\n\\n\\"\\"\\"U\\"\\"\\"\\nunion U = M |'
            ' W\\n\\n\\"\\"\\"M\\"\\"\\"\\ntype M {\\n  m:'
            ' Int\\n}\\n\\n\\"\\"\\"W\\"\\"\\"\\ntype W {\\n  w:'
            ' Int\\n}\\n\\n\\"\\"\\"Z\\"\\"\\"\\ntype Z {\\n  zzz: Int\\n}\\n"'
        ),
    )


def test_tool_comment_description() raises:
    var source = """
            # Overridden tool #description
            query GetABZ($state: String!) {
              b {
                d {
                  f
                }
              }
            }
            """
    assert_equal(
        _description(source), json_text('"Overridden tool #description"')
    )


def test_tool_empty_comment_description() raises:
    var source = """
            #

            #
            query GetABZ($state: String!) {
              id
            }
            """
    assert_equal(
        _description(source),
        json_text('"The returned value is optional and has type `String`"'),
    )


def test_no_schema_description() raises:
    assert_equal(
        _description("query GetABZ($state: String!) { id enum }", False, True),
        json_text(
            '"The returned value is optional and has type `String`\\n---\\nThe'
            ' returned value is optional and has type `RealEnum`"'
        ),
    )


def test_no_type_description() raises:
    assert_equal(
        _description("query GetABZ($state: String!) { id enum }", True, False),
        json_text(
            '"---\\n\\"\\"\\"the description for the enum\\"\\"\\"\\nenum'
            ' RealEnum {\\n  \\"\\"\\"ENUM_VALUE_1 is a value\\"\\"\\"\\n '
            ' ENUM_VALUE_1\\n  \\"\\"\\"ENUM_VALUE_2 is a value\\"\\"\\"\\n '
            ' ENUM_VALUE_2\\n}\\n"'
        ),
    )


def test_no_type_description_or_schema_description() raises:
    assert_equal(
        _description("query GetABZ($state: String!) { id enum }", True, True),
        "",
    )


def test_recursive_inputs() raises:
    var schema = build_schema(
        '''
                """the filter input"""
                input Filter {
                """the filter.field field"""
                    field: String
                    """the filter.filter field"""
                    filter: Filter
                }
                type Query {
                """the Query.field field"""
                  field(
                    """the filter argument"""
                    filter: Filter
                  ): String
                }
            '''
    )
    var operation = make_operation(
        """query Test($filter: Filter){
                field(filter: $filter) {
                    id
                }
            }""",
        schema,
        disable_type_description=True,
        disable_schema_description=True,
    )
    assert_equal(
        operation.tool.to_json(),
        (
            '{"name":"Test","description":"","inputSchema":{"type":"object","properties":{"filter":{"description":"the'
            " filter"
            ' argument","anyOf":[{"$ref":"#/definitions/Filter"},{"type":"null"}]}},"definitions":{"Filter":{"description":"the'
            " filter"
            ' input","type":"object","properties":{"field":{"description":"the'
            " filter.field"
            ' field","anyOf":[{"type":"string"},{"type":"null"}]},"filter":{"description":"the'
            " filter.filter"
            ' field","anyOf":[{"$ref":"#/definitions/Filter"},{"type":"null"}]}}}}},"outputSchema":{"type":"object","properties":{"data":{"type":"object","properties":{"field":{"description":"the'
            " Query.field"
            ' field","anyOf":[{"type":"string"},{"type":"null"}]}}},"errors":{"type":"array","items":{"type":"object","properties":{"message":{"type":"string"},"locations":{"type":"array","items":{"type":"object","properties":{"line":{"type":"integer"},"column":{"type":"integer"}}}},"path":{"type":"array","items":{"oneOf":[{"type":"string"},{"type":"integer"}]}},"extensions":{"type":"object"}},"required":["message"]}},"extensions":{"type":"object"}}},"annotations":{"readOnlyHint":true,"destructiveHint":false,"idempotentHint":true,"openWorldHint":true}}'
        ),
    )


def test_with_variable_overrides() raises:
    var raw = RawOperation(
        "query QueryName($id: ID, $name: String) { id }", None
    )
    var fixed = JsonTree()
    fixed.root = fixed.add_object()
    fixed.set(fixed.root, "id", fixed.add_string("v"))
    raw.variables = fixed^
    var found = Operation.from_raw(
        raw^,
        test_schema(),
        CustomScalarMap(),
        MutationMode.NONE,
        False,
        False,
        True,
        Dict[String, AnnotationOverrides](),
        Dict[String, String](),
    )
    assert_equal(
        found.value().tool.to_json(),
        (
            '{"name":"QueryName","description":"The returned value is optional'
            " and has type"
            ' `String`","inputSchema":{"type":"object","properties":{"name":{"anyOf":[{"type":"string"},{"type":"null"}]}}},"outputSchema":{"type":"object","properties":{"data":{"type":"object","properties":{"id":{"anyOf":[{"type":"string"},{"type":"null"}]}}},"errors":{"type":"array","items":{"type":"object","properties":{"message":{"type":"string"},"locations":{"type":"array","items":{"type":"object","properties":{"line":{"type":"integer"},"column":{"type":"integer"}}}},"path":{"type":"array","items":{"oneOf":[{"type":"string"},{"type":"integer"}]}},"extensions":{"type":"object"}},"required":["message"]}},"extensions":{"type":"object"}}},"annotations":{"readOnlyHint":true,"destructiveHint":false,"idempotentHint":true,"openWorldHint":true}}'
        ),
    )


def test_input_schema_includes_variable_descriptions() raises:
    assert_equal(
        _properties(
            "query QueryName($idArg: ID) { customQuery(id: $idArg) { id } }"
        ),
        (
            '{"properties":{"idArg":{"anyOf":[{"type":"string"},{"type":"null"}],"description":"id'
            ' description"}},"type":"object"}'
        ),
    )


def test_input_schema_includes_joined_variable_descriptions_if_multiple() raises:
    assert_equal(
        _properties(
            "query QueryName($idArg: ID, $flag: Boolean) { customQuery(id:"
            + " $idArg, flag: $flag) { id @skip(if: $flag) } }"
        ),
        (
            '{"properties":{"flag":{"anyOf":[{"type":"boolean"},{"type":"null"}],"description":"Skipped'
            " when true.#a"
            ' flag"},"idArg":{"anyOf":[{"type":"string"},{"type":"null"}],"description":"id'
            ' description"}},"type":"object"}'
        ),
    )


def test_input_schema_includes_directive_variable_descriptions() raises:
    var tool = make_operation(
        "query QueryName($idArg: ID, $skipArg: Boolean) { customQuery(id:"
        + " $idArg) { id @skip(if: $skipArg) } }",
        test_schema(),
    ).tool.copy()
    assert_equal(
        tool.input_schema.to_string(tool.input_schema.root),
        (
            '{"type":"object","properties":{"idArg":{"description":"id'
            ' description","anyOf":[{"type":"string"},{"type":"null"}]},"skipArg":{"description":"Skipped'
            ' when true.","anyOf":[{"type":"boolean"},{"type":"null"}]}}}'
        ),
    )


def test_operation_name_with_named_query() raises:
    var operation = make_operation(
        "query GetUser($id: ID!) { user(id: $id) { name email } }",
        test_schema(),
    )
    assert_equal(operation.name, "GetUser")


def test_operation_name_with_named_mutation() raises:
    var operation = make_operation(
        "mutation CreateUser($input: UserInput!) { createUser(input: $input) {"
        + " id name } }",
        test_schema(),
        mode=MutationMode.EXPLICIT,
    )
    assert_equal(operation.name, "CreateUser")


def test_operation_variable_comments_override_schema_descriptions() raises:
    assert_equal(
        _properties(
            "# operation description\nquery QueryName(# id comment"
            + " override\n$idArg: ID) { customQuery(id: $idArg) { id } }"
        ),
        (
            '{"properties":{"idArg":{"anyOf":[{"type":"string"},{"type":"null"}],"description":"id'
            ' comment override"}},"type":"object"}'
        ),
    )


def test_operation_variable_comment_override_supports_multiline_comments() raises:
    assert_equal(
        _properties(
            "# operation description\nquery QueryName(# id comment override\n"
            + " # multi-line comment \n$idArg: ID) { customQuery(id: $idArg) {"
            + " id } }"
        ),
        (
            '{"properties":{"idArg":{"anyOf":[{"type":"string"},{"type":"null"}],"description":"id'
            ' comment override\\n multi-line comment"}},"type":"object"}'
        ),
    )


def test_operation_variable_descriptions_override_schema_descriptions() raises:
    assert_equal(
        _variable_description(
            'query QueryName("""Spec description""" $idArg: ID) {'
            + " customQuery(id: $idArg) { id } }"
        ),
        "Spec description",
    )


def test_operation_variable_descriptions_override_variable_comments() raises:
    assert_equal(
        _variable_description(
            'query QueryName(# id comment override\n"""Spec description"""'
            + " $idArg: ID) { customQuery(id: $idArg) { id } }"
        ),
        "Spec description",
    )


def test_blank_operation_variable_description_falls_back_to_variable_comment() raises:
    assert_equal(
        _variable_description(
            'query QueryName(# id comment override\n"""   """ $idArg: ID) {'
            + " customQuery(id: $idArg) { id } }"
        ),
        "id comment override",
    )


def test_comment_with_parens_has_comments_extracted_correctly() raises:
    assert_equal(
        _properties(
            "query QueryName # a comment (with parens)\n(# id comment"
            + " override\n # multi-line comment \n$idArg: ID) {"
            + " customQuery(id: $idArg) { id } }"
        ),
        (
            '{"properties":{"idArg":{"anyOf":[{"type":"string"},{"type":"null"}],"description":"id'
            ' comment override\\n multi-line comment"}},"type":"object"}'
        ),
    )


def test_multiline_comment_with_odd_spacing_and_parens_has_comments_extracted_correctly() raises:
    assert_equal(
        _properties(
            "#  operation comment\n\nquery QueryName # a comment \n#     extra"
            + " space\n\n\n#  blank lines (with parens)\n\n# another"
            " (paren)\n(#"
            + " id comment override\n # multi-line comment \n$idArg: ID\n, \n#"
            + " a flag\n$flag: Boolean) { customQuery(id: $idArg, skip: $flag)"
            + " { id } }"
        ),
        (
            '{"properties":{"flag":{"anyOf":[{"type":"boolean"},{"type":"null"}],"description":"a'
            ' flag"},"idArg":{"anyOf":[{"type":"string"},{"type":"null"}],"description":"id'
            ' comment override\\n multi-line comment"}},"type":"object"}'
        ),
    )


def test_operation_with_no_variables_is_handled_properly() raises:
    assert_equal(
        _properties('query QueryName { customQuery(id: "123") { id } }'),
        '{"properties":{},"type":"object"}',
    )


def test_commas_between_variables_are_ignored() raises:
    assert_equal(
        _properties(
            "query QueryName(# id arg\n $idArg: ID,,\n,,\n # a flag\n $flag:"
            + " Boolean,  ,,) { customQuery(id: $idArg, flag: $flag) { id } }"
        ),
        (
            '{"properties":{"flag":{"anyOf":[{"type":"boolean"},{"type":"null"}],"description":"a'
            ' flag"},"idArg":{"anyOf":[{"type":"string"},{"type":"null"}],"description":"id'
            ' arg"}},"type":"object"}'
        ),
    )


def test_input_schema_include_properties_field_even_when_operation_has_no_input_args() raises:
    assert_equal(
        _properties("query TestOp { testOp { id } }"),
        '{"properties":{},"type":"object"}',
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

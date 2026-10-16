# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Shared fixtures of the `gql_mcp.operation` tests: the `SCHEMA` of the
tests of Apollo MCP Server 2.0.0 `operations/operation.rs`, and helpers
that make a tool and print JSON as the upstream assertions do."""

from gql_json.parser import parse as parse_json
from gql_json.value import JsonKind
from gql_mcp.custom_scalar_map import CustomScalarMap
from gql_mcp.json_tree import JsonTree
from gql_mcp.operation import Operation, RawOperation
from gql_mcp.tool import AnnotationOverrides, MutationMode
from gql_schema.build import build_schema
from gql_schema.definition import Schema


comptime SCHEMA_SDL = '''
    type Query {
        id: String
        enum: RealEnum
        customQuery(""" id description """ id: ID!, """ a flag """ flag: Boolean): OutputType
        testOp: OpResponse
    }
    type Mutation {id: String }

    """
    RealCustomScalar exists
    """
    scalar RealCustomScalar
    input RealInputObject {
        """
        optional is a input field that is optional
        """
        optional: String

        """
        required is a input field that is required
        """
        required: String!
    }

    type OpResponse {
      id: String
    }

    """
    the description for the enum
    """
    enum RealEnum {
        """
        ENUM_VALUE_1 is a value
        """
        ENUM_VALUE_1

        """
        ENUM_VALUE_2 is a value
        """
        ENUM_VALUE_2
    }

    """
    custom output type
    """
    type OutputType {
        id: ID!
    }
'''
"""The schema of the upstream tests."""


def test_schema() raises -> Schema:
    """Build the schema of the upstream tests.

    Returns:
        The schema.

    Raises:
        Error: Never; the SDL is valid.
    """
    return build_schema(SCHEMA_SDL)


def make_operation(
    source: String,
    schema: Schema,
    mode: MutationMode = MutationMode.NONE,
    disable_type_description: Bool = False,
    disable_schema_description: Bool = False,
    enable_output_schema: Bool = True,
    custom_scalars: CustomScalarMap = CustomScalarMap(),
) raises -> Operation:
    """Make the operation of a source text, as the upstream tests do.

    Args:
        source: The GraphQL text.
        schema: The schema.
        mode: The mutation mode.
        disable_type_description: Upstream `disable_type_description`.
        disable_schema_description: Upstream `disable_schema_description`.
        enable_output_schema: Upstream `enable_output_schema`.
        custom_scalars: The custom scalar map.

    Returns:
        The operation.

    Raises:
        Error: When the text gives no operation.
    """
    var found = Operation.from_raw(
        RawOperation(source, None),
        schema,
        custom_scalars,
        mode,
        disable_type_description,
        disable_schema_description,
        enable_output_schema,
        Dict[String, AnnotationOverrides](),
        Dict[String, String](),
    )
    if not found:
        raise Error("no operation")
    return found.take()


def json_text(json: String) raises -> String:
    """Decode a JSON string literal.

    Args:
        json: The literal, quotes included.

    Returns:
        The decoded text.

    Raises:
        Error: When the literal is not valid JSON.
    """
    var document = parse_json(json)
    return document.string_value(document.root)


def sorted_json(tree: JsonTree, node: Int) -> String:
    """Return the JSON text of a value with every object's keys sorted, as
    the upstream `to_sorted_json!` macro.

    Args:
        tree: The tree.
        node: The value.

    Returns:
        The text.
    """
    var copy = JsonTree()
    copy.root = copy.copy_from(tree, node)
    var index = 0
    while index < len(copy.nodes):
        if copy.nodes[index].kind == JsonKind.OBJECT:
            ref value = copy.nodes[index]
            var count = len(value.keys)
            var i = 1
            while i < count:
                var j = i
                while j > 0 and value.keys[j] < value.keys[j - 1]:
                    value.keys.swap_elements(j, j - 1)
                    value.items.swap_elements(j, j - 1)
                    j -= 1
                i += 1
        index += 1
    return copy.to_string(copy.root)

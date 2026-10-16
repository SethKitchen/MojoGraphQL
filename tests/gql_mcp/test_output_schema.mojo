# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_mcp.output_schema`.

Ports the tests of Apollo MCP Server 2.0.0 (04e4e6e)
`crates/apollo-mcp-server/src/operations/schema_walker/output.rs` that do
not use `@private`. The upstream checks two of them with the `jsonschema`
validator; here each case compares the whole schema with the upstream's
output. `fixtures/output_cases.txt` holds the cases (SDL, `----`, the
operation; `====` between cases), and `fixtures/output_expected.txt` the
upstream `serde_json::to_value` text of each, one line each, from a dump
test added to a copy of `output.rs` that uses the custom scalar map
`{"Mapped": {"type": "string", "description": "mapped"}, "Yes": true}`.
"""

from gql_language.ast import Role
from gql_language.parser import parse
from gql_mcp.custom_scalar_map import CustomScalarMap
from gql_mcp.json_tree import JsonTree
from gql_mcp.output_schema import selection_set_to_schema
from gql_schema.build import BuildOptions, build_schema
from std.pathlib import Path
from std.testing import TestSuite, assert_equal


def output_of(sdl: StringSlice, query: StringSlice) raises -> String:
    var options = BuildOptions()
    options.assume_valid_sdl = True
    var schema = build_schema(sdl, options)
    var document = parse(query)
    var operation = document.definitions()[0]
    var scalars = CustomScalarMap.parse(
        '{"Mapped": {"type": "string", "description": "mapped"}, "Yes": true}'
    )
    var tree = JsonTree()
    var root = selection_set_to_schema(
        tree,
        schema,
        document,
        document.child(operation, Role.SELECTION_SET),
        schema.root_type(document.operation(operation).value),
        scalars,
    )
    tree.order_schema(root)
    return tree.to_string(root)


def check_case(index: Int) raises:
    var cases = Path("tests/gql_mcp/fixtures/output_cases.txt").read_text()
    var expected = Path(
        "tests/gql_mcp/fixtures/output_expected.txt"
    ).read_text()
    var one = String(cases.split("\n====\n")[index])
    var parts = one.split("\n----\n")
    assert_equal(
        output_of(parts[0], parts[1]),
        String(expected.splitlines()[index]),
    )


def test_simple_query_output_schema() raises:
    check_case(0)


def test_nested_object_output_schema() raises:
    check_case(1)


def test_output_schema_accepts_null_for_unmapped_custom_scalar() raises:
    check_case(2)


def test_output_schema_accepts_union_member_matching_several_fragments() raises:
    check_case(3)


def test_abstract_types_fragments_and_duplicates() raises:
    check_case(4)


def test_mutation_scalars_and_lists() raises:
    check_case(5)


def test_fields_on_unions_and_repeated_keys() raises:
    check_case(6)


def test_input_object_in_output_position() raises:
    # A schema that SDL validation refuses: the upstream gives `{}`.
    assert_equal(
        output_of("input In { a: Int } type Query { i: In }", "{ i }"),
        String(
            '{"type":"object","properties":{"data":{"type":"object",'
            + '"properties":{"i":{"anyOf":[{},{"type":"null"}]}}},"errors":'
        )
        + _ERRORS
        + ',"extensions":{"type":"object"}}}',
    )


comptime _ERRORS = (
    '{"type":"array","items":{"type":"object","properties":{"message":'
    + '{"type":"string"},"locations":{"type":"array","items":{"type":'
    + '"object","properties":{"line":{"type":"integer"},"column":{"type":'
    + '"integer"}}}},"path":{"type":"array","items":{"oneOf":[{"type":'
    + '"string"},{"type":"integer"}]}},"extensions":{"type":"object"}},'
    + '"required":["message"]}}'
)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

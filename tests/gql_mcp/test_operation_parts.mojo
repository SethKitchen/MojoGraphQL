# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the parts of `gql_mcp.operation`: `operation_defs`, the
comment matchers, `OperationError`, and the `variables` and `headers` of
upstream `Executable for Operation`.

The error test is ported from Apollo MCP Server 2.0.0 (04e4e6e)
`crates/apollo-mcp-server/src/errors.rs`. The other cases check
`operations/operation.rs` paths that its tests do not reach.
"""

from _operation_fixtures import make_operation, test_schema
from gql_json.parser import parse as parse_json
from gql_language.parser import parse
from gql_mcp.json_tree import JsonTree
from gql_mcp.operation import (
    Operation,
    OperationError,
    OperationErrorKind,
    extract_and_format_comments,
    find_opening_parens_offset,
    operation_defs,
    operation_name,
    variable_description_overrides,
)
from gql_mcp.tool import MutationMode
from gql_schema.build import build_schema
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_operation_error_manifest_display() raises:
    var error = OperationError(
        OperationErrorKind.MANIFEST, "connection refused", None, 0
    )
    assert_equal(
        String(error),
        "Error fetching persisted-query manifest: connection refused",
    )


def test_operation_error_display() raises:
    assert_equal(
        String(OperationError(OperationErrorKind.INTERNAL, "x", None, 0)),
        "Internal error: x",
    )
    assert_equal(
        String(OperationError(OperationErrorKind.JSON, "y", None, 0)),
        "Invalid JSON: y",
    )
    assert_equal(
        String(OperationError(OperationErrorKind.FILE, "gone", None, 0)), "gone"
    )
    assert_true(OperationErrorKind.MANIFEST.is_valid())
    assert_false(OperationErrorKind(8).is_valid())


def _defs_error(source: String) raises -> String:
    try:
        _ = operation_defs(source, True, None)
    except e:
        return String(e)
    return "no error"


def test_operation_defs() raises:
    assert_true(
        _defs_error("query {").startswith(
            "Could not parse GraphQL document: Syntax Error:"
        )
    )
    assert_equal(
        _defs_error("query A { a } query B { b } query C { c }"),
        "Too many operations. Expected 1 but got 3",
    )
    var found = operation_defs(
        "# one\nfragment F on Q { a }\n# two\nquery A { ...F }", True, None
    )
    assert_equal(found.value().comments.value(), "\n# two\n")
    assert_false(Bool(operation_defs("mutation M { a }", False, None)))
    assert_true(Bool(operation_defs("mutation M { a }", True, None)))


def test_operation_name() raises:
    var document = parse('"desc" query ($a: Int) { a }')
    var operation = document.definitions()[0]
    var message = String("no error")
    try:
        _ = operation_name(document, operation, String("file.graphql"))
    except e:
        message = String(e)
    assert_equal(
        message,
        'file.graphql: Operation is missing its required name: "desc"'
        + " query($a: Int) { a }",
    )
    var named = parse("query Named { a }")
    assert_equal(operation_name(named, named.definitions()[0], None), "Named")


def test_find_opening_parens_offset() raises:
    var text = String("query Q\n  # c\n  ($a: Int) { a }")
    var document = parse(text)
    var operation = document.definitions()[0]
    assert_equal(
        find_opening_parens_offset(text, document, operation).value(), 17
    )
    var plain = String("query Q { a(b: 1) }")
    var other = parse(plain)
    assert_equal(
        find_opening_parens_offset(
            plain, other, other.definitions()[0]
        ).value(),
        0,
    )
    var anonymous = String("{ a }")
    var shorthand = parse(anonymous)
    assert_false(
        Bool(
            find_opening_parens_offset(
                anonymous, shorthand, shorthand.definitions()[0]
            )
        )
    )


def test_extract_and_format_comments() raises:
    assert_false(Bool(extract_and_format_comments(None)))
    assert_false(Bool(extract_and_format_comments(String(" \n "))))
    assert_equal(
        extract_and_format_comments(String("  ,# a\n\n  # b # c\nx")).value(),
        "a\n b # c\nx",
    )


def _arguments(json: String) raises -> JsonTree:
    var document = parse_json(json)
    var tree = JsonTree()
    tree.root = tree.add_document(document, document.root)
    return tree^


def _variables_error(operation: Operation, json: String) raises -> String:
    var input = _arguments(json)
    try:
        _ = operation.variables(input, input.root)
    except e:
        return String(e)
    return "no error"


def test_variables_and_headers() raises:
    var operation = make_operation("query Q($a: Int) { id }", test_schema())
    var input = _arguments('{"a":1}')
    var plain = operation.variables(input, input.root)
    assert_equal(plain.to_string(plain.root), '{"a":1}')
    var fixed = JsonTree()
    fixed.root = fixed.add_object()
    fixed.set(fixed.root, "b", fixed.add_int(2))
    operation.raw.variables = fixed^
    var merged = operation.variables(input, input.root)
    assert_equal(merged.to_string(merged.root), '{"a":1,"b":2}')
    var none = _arguments("null")
    var only = operation.variables(none, none.root)
    assert_equal(only.to_string(only.root), '{"b":2}')
    assert_equal(
        _variables_error(operation, "[1]"),
        "Variables must be a JSON object or null",
    )
    assert_equal(
        _variables_error(operation, '{"b":3}'),
        "Parameter 'b' conflicts with operation-defined variable",
    )
    var defaults = List[Tuple[String, String]]()
    defaults.append(("Content-Type", "application/json"))
    defaults.append(("X-A", "1"))
    assert_equal(len(operation.headers(defaults)), 2)
    operation.raw.headers.append(("x-a", "2"))
    operation.raw.headers.append(("X-B", "3"))
    var headers = operation.headers(defaults)
    assert_equal(len(headers), 3)
    assert_equal(headers[1][0], "x-a")
    assert_equal(headers[1][1], "2")
    assert_equal(headers[2][1], "3")


def test_variable_descriptions_of_anonymous_operation() raises:
    var text = String("query (# a comment\n$a: Int) { a }")
    var document = parse(text)
    var overrides = variable_description_overrides(
        text, document, document.definitions()[0]
    )
    assert_equal(len(overrides), 0)


def test_description_without_root_type() raises:
    var schema = build_schema("type Query { id: String }")
    var mutation = make_operation(
        "mutation M($a: Int) { id }", schema, mode=MutationMode.EXPLICIT
    )
    assert_equal(mutation.tool.description.value(), "")
    assert_false(Bool(mutation.tool.output_schema))
    var spread = make_operation(
        "query Q { ...F id } fragment F on Query { id }", schema
    )
    assert_equal(
        spread.tool.description.value(),
        "The returned value is optional and has type `String`",
    )


def test_description_leaves_out_inputs_and_query() raises:
    var schema = build_schema(
        "type Query { id: String } input In { a: Int } type Mutation { q(i:"
        + " In): Query }"
    )
    var operation = make_operation(
        "mutation M($i: In) { q(i: $i) { id } }",
        schema,
        mode=MutationMode.EXPLICIT,
    )
    assert_equal(
        operation.tool.description.value(),
        "The returned value is optional and has type `Query`",
    )


def test_private_through_fragments() raises:
    var schema = build_schema("type Query { id: String }")
    var operation = make_operation(
        "query Q { ...Missing ...F ...F } fragment F on Query { id @private }",
        schema,
    )
    assert_true(operation.has_private_fields)
    assert_equal(
        operation.query(),
        "query Q { ...Missing ...F ...F } fragment F on Query { id }",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

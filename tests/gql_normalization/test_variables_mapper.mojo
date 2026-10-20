# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests ported from graphql-go-tools v2 `v2/pkg/astnormalization`:
`TestVariablesMapper` of `variables_mapper_test.go`.

Each case normalizes the operation as upstream does, with
`NormalizeNamedOperation`, then `VariablesNormalizer`, then the mapper. The
mapping is written as `new=old` pairs, in the order of the new names.
"""

from _norm import printed, schema_of
from gql_language.parser import parse
from gql_language.printer import print_ast
from gql_normalization.normalize import (
    NormalizerOptions,
    OperationNormalizer,
    VariablesNormalizer,
)
from gql_normalization.variables_mapper import VariablesMapper, mapping_name
from std.collections import Dict
from std.testing import TestSuite, assert_equal

comptime DEFINITION = """
	  type Object {
		id: ID!
		name: String!
		echo(value: String!): String!
		echoTwo(value: String!): String!
		copy(input: InputObject!): Object!
	  }

	  input InputObject {
		id: ID!
		name: String!
	  }

	  type Query {
		object(id: ID!): Object
	  }

	  type Mutation {
		updateObject(name: String!, files: [Upload!]): Object!
		uploadFile(file: Upload!): Object!
	  }

	  type Subscription {
		subscribe(id: ID!): Object!
	  }

	  scalar Upload"""
"""The definition of `TestVariablesMapper`. Upstream does not declare
`Upload`, and its definition is not validated; `build_schema` needs the
declaration."""


def rendered(mapping: Dict[String, String]) raises -> String:
    """Write a mapping as `new=old` pairs in the order of the new names.

    Args:
        mapping: The mapping of the mapper.

    Returns:
        The pairs, each one followed by a space.

    Raises:
        Error: If a new name is not in the order of `mapping_name`.
    """
    var out = String()
    var index = 0
    while index < len(mapping):
        var name = mapping_name(index)
        out += name + "=" + mapping[name] + " "
        index += 1
    return out^


def run(input: StringSlice, output: StringSlice, expected: StringSlice) raises:
    """Normalize, map, and compare the operation and the mapping.

    Args:
        input: The operation.
        output: The expected operation.
        expected: The expected mapping, as `rendered` writes it.

    Raises:
        Error: If an output differs.
    """
    var options = NormalizerOptions()
    options.remove_not_matching_operation_definitions = True
    options.inline_fragment_spreads = True
    options.remove_fragment_definitions = True
    options.remove_unused_variables = True
    var schema = schema_of(DEFINITION)
    var document = parse(input)
    var name = String(document.name(document.first_child(document.root)))
    var variables = String()
    OperationNormalizer(options).normalize_named_operation(
        document, schema, name, variables
    )
    _ = VariablesNormalizer().normalize_operation(document, schema, variables)
    var mapping = VariablesMapper().normalize_operation(document, schema)
    assert_equal(print_ast(document), printed(output))
    assert_equal(rendered(mapping), String(expected))


def test_1_1_simple_external_variable_query() raises:
    run(
        "query MyQuery($varOne: ID!) { object(id: $varOne) { name } }",
        "query MyQuery($a: ID!) { object(id: $a) { name } }",
        "a=varOne ",
    )


def test_1_2_simple_external_variable_mutation() raises:
    run(
        (
            "mutation MyMutation($varOne: String!) { updateObject(name:"
            " $varOne) { name } }"
        ),
        "mutation MyMutation($a: String!) { updateObject(name: $a) { name } }",
        "a=varOne ",
    )


def test_1_3_simple_external_variable_subscription() raises:
    run(
        (
            "subscription MySubscription($varOne: ID!) { subscribe(id:"
            " $varOne) { name } }"
        ),
        "subscription MySubscription($a: ID!) { subscribe(id: $a) { name } }",
        "a=varOne ",
    )


def test_2_simple_inline_variable() raises:
    run(
        'query MyQuery { object(id: "abc123") { name } }',
        "query MyQuery($a: ID!) { object(id: $a) { name } }",
        "a=a ",
    )


def test_3_1_colliding_external_variable() raises:
    run(
        "query MyQuery($a: ID!) { object(id: $a) { name } }",
        "query MyQuery($a: ID!) { object(id: $a) { name } }",
        "a=a ",
    )


def test_3_2_colliding_external_variable_used_in_2_places() raises:
    run(
        "query MyQuery($a: String!) { echo(id: $a) echoTwo(id: $a) }",
        "query MyQuery($a: String!) { echo(id: $a) echoTwo(id: $a) }",
        "a=a ",
    )


def test_3_3_colliding_external_variable_along_with_inline_values() raises:
    run(
        (
            'query MyQuery($a: String!) { object(id: 1) { echo(value: "Hello'
            ' World") echoTwo(value: $a) } }'
        ),
        (
            "query MyQuery($a: ID!, $b: String!, $c: String!) { object(id: $a)"
            " { echo(value: $b) echoTwo(value: $c) } }"
        ),
        "a=b b=c c=a ",
    )


def test_3_4_colliding_external_variables() raises:
    run(
        (
            "query MyQuery($b: String!, $e: String! $c: ID!) { object(id: $c)"
            " { echo(value: $e) echoTwo(value: $b) } }"
        ),
        (
            "query MyQuery($a: ID!, $b: String!, $c: String!) { object(id: $a)"
            " { echo(value: $b) echoTwo(value: $c) } }"
        ),
        "a=c b=e c=b ",
    )


def test_3_5_all_inline_values() raises:
    run(
        (
            'query MyQuery { object(id: 1) { echo(value: "Hello")'
            ' echoTwo(value: "World") } }'
        ),
        (
            "query MyQuery($a: ID!, $b: String!, $c: String!){ object(id: $a)"
            " { echo(value: $b) echoTwo(value: $c) } }"
        ),
        "a=a b=b c=c ",
    )


def test_4_inline_variable_and_external_variable() raises:
    run(
        (
            "query MyQuery($varOne: ID!) { object(id: $varOne) { name"
            ' echo(value: "Hello World!") } }'
        ),
        (
            "query MyQuery($a: ID! $b: String!) { object(id: $a) { name"
            " echo(value: $b) } }"
        ),
        "a=varOne b=a ",
    )


def test_5_1_multiple_external_variables() raises:
    run(
        (
            "query MyQuery($varOne: ID! $varTwo: String!) { object(id:"
            " $varOne) { name echo(value: $varTwo) } }"
        ),
        (
            "query MyQuery($a: ID! $b: String!) { object(id: $a) { name"
            " echo(value: $b) } }"
        ),
        "a=varOne b=varTwo ",
    )


def test_6_multiple_colliding_external_variables() raises:
    run(
        (
            "query MyQuery($a: String! $b: ID!) { object(id: $b) { echo(value:"
            " $a) name } }"
        ),
        (
            "query MyQuery($a: ID! $b: String!) { object(id: $a) { echo(value:"
            " $b) name } }"
        ),
        "a=b b=a ",
    )


def test_7_multiple_inline_variables() raises:
    run(
        (
            'query MyQuery { object(id: "abc123") { echo(value: "Hello'
            ' World!") name } }'
        ),
        (
            "query MyQuery($a: ID! $b: String!) { object(id: $a) { echo(value:"
            " $b) name } }"
        ),
        "a=a b=b ",
    )


def test_8_inline_variable_with_multiple_colliding_external_variables() raises:
    run(
        (
            "query MyQuery($a: ID! $b: String! ) { object(id: $a) { name"
            ' copy(input: { id: "abc123", name: "MyObject"}), echo(value: $b)'
            " } }"
        ),
        (
            "query MyQuery($a: ID! $b: InputObject! $c: String!) { object(id:"
            " $a) { name copy(input: $b), echo(value: $c) } }"
        ),
        "a=a b=c c=b ",
    )


def test_9_inline_variable_with_multiple_colliding_external_variables() raises:
    run(
        (
            "query MyQuery($a: ID! $b: String! $c: String! ) { object(id: $a)"
            ' { name copy(input: { id: "abc123", name: $b}) echo(value: $c) }'
            " }"
        ),
        (
            "query MyQuery($a: ID! $b: InputObject! $c: String! ) { object(id:"
            " $a) { name copy(input: $b) echo(value: $c) } }"
        ),
        "a=a b=d c=c ",
    )


def test_10_colliding_external_variable_with_multiple_inline_variables() raises:
    run(
        (
            "query MyQuery($a: ID!) { object(id: $a) { name copy(input: { id:"
            ' "abc123", name: "MyObject" }) echo(value: "Hello World") } }'
        ),
        (
            "query MyQuery($a: ID! $b: InputObject! $c: String! ) { object(id:"
            " $a) { name copy(input: $b) echo(value: $c) } }"
        ),
        "a=a b=b c=c ",
    )


def test_11_reused_external_variable() raises:
    run(
        (
            "query MyQuery($varOne: String!) { object(id: 1) { echo(value:"
            " $varOne) echoTwo(value: $varOne) } }"
        ),
        (
            "query MyQuery($a: ID!, $b: String!) { object(id: $a) {"
            " echo(value: $b) echoTwo(value: $b) } }"
        ),
        "a=a b=varOne ",
    )


def test_12_reused_inline_value() raises:
    run(
        (
            "query MyQuery { object(id: 1) { echo(value: 12) echoTwo(value: 12)"
            " } }"
        ),
        (
            "query MyQuery ($a: ID!, $b: String!) { object(id: $a) {"
            " echo(value: $b) echoTwo(value: $b) } }"
        ),
        "a=a b=b ",
    )


def test_13_mutation_with_file_uploads() raises:
    run(
        (
            "mutation MyMutation($varOne: String! $files: [Upload!]) {"
            " updateObject(name: $varOne, files: $files) { name } }"
        ),
        (
            "mutation MyMutation($a: String!, $files: [Upload!]) {"
            " updateObject(name: $a, files: $files) { name } }"
        ),
        "a=varOne ",
    )


def test_13_mutation_with_file_uploads_reverse_order() raises:
    run(
        (
            "mutation MyMutation($files: [Upload!] $varOne: String!) {"
            " updateObject(name: $varOne, files: $files) { name } }"
        ),
        (
            "mutation MyMutation($a: String!, $files: [Upload!]) {"
            " updateObject(name: $a, files: $files) { name } }"
        ),
        "a=varOne ",
    )


def test_13_mutation_with_single_file_upload() raises:
    run(
        (
            "mutation MyMutation($file: Upload!) { uploadFile(files: $file) {"
            " name } }"
        ),
        (
            "mutation MyMutation($file: Upload!) { uploadFile(files: $file) {"
            " name } }"
        ),
        "",
    )


def mapped(
    input: StringSlice, output: StringSlice, expected: StringSlice
) raises:
    """Run only the mapper, and compare the operation and the mapping.

    Args:
        input: The document.
        output: The expected document.
        expected: The expected mapping, as `rendered` writes it.

    Raises:
        Error: If an output differs.
    """
    var schema = schema_of(DEFINITION)
    var document = parse(input)
    var mapping = VariablesMapper().normalize_operation(document, schema)
    assert_equal(print_ast(document), printed(output))
    assert_equal(rendered(mapping), String(expected))


def test_extra_directives_fragments_and_undefined_variables() raises:
    # Checked against upstream: a fragment definition keeps its variables.
    mapped(
        (
            "query Q($a: Int, $b: Int) @dir(x: $b) { f(x: 1, y: $c, z: $b)"
            " @include(if: $a) ...F } fragment F on Query { g(x: $a) } scalar"
            " S"
        ),
        (
            "query Q($a: Int, $b: Int) @dir(x: $a) { f(x: 1, y: $c, z: $a)"
            " @include(if: $b) ...F } fragment F on Query { g(x: $a) } scalar"
            " S"
        ),
        "a=b b=a ",
    )


def test_extra_two_operations_share_a_variable_name() raises:
    # Checked against upstream: only the definition of the first use
    # changes, and only the last operation is sorted.
    mapped(
        (
            "query A($x: Int) { f(a: $x) } query B($x: Int, $u: Upload) { f(a:"
            " $x, b: $u) }"
        ),
        (
            "query A($a: Int) { f(a: $a) } query B($u: Upload, $x: Int) { f(a:"
            " $a, b: $u) }"
        ),
        "a=x ",
    )


def test_extra_no_operation() raises:
    mapped(
        "fragment F on Query { g(x: $a) }",
        "fragment F on Query { g(x: $a) }",
        "",
    )


def test_extra_mapping_names() raises:
    assert_equal(mapping_name(0), "a")
    assert_equal(mapping_name(25), "z")
    assert_equal(mapping_name(26), "aa")
    assert_equal(mapping_name(53), "bbb")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

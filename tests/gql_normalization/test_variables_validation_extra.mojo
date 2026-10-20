# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_normalization.variables_validation` that upstream
`variablesvalidation_test.go` does not have. They pin the upstream behavior
of `variablesvalidation.go` on the paths that the upstream suite does not
reach: variables that are not an object, documents with fragments,
`@inaccessible` enum values, custom scalars, and the error of a later
variable replacing the error of an earlier one.
"""

from _vv_helpers import expect_hidden, expect_shown, remap, run_test
from gql_normalization.variables_validation import _PathItemKind
from std.testing import TestSuite, assert_false, assert_true


def test_variables_that_are_not_an_object() raises:
    """A JSON `null` has no members, so a required variable is missing."""
    expect_hidden(
        "type Query { hello(arg: String!): String }",
        "query Foo($bar: String!) { hello(arg: $bar) }",
        "null",
        'Variable "$bar" of required type "String!" was not provided.',
    )


def test_variables_that_are_not_json() raises:
    """Text that is not JSON raises the parse error."""
    var raised = False
    try:
        _ = run_test(
            "type Query { hello: String }", "query { hello }", "{", None
        )
    except:
        raised = True
    assert_true(raised)


def test_fragment_definitions_are_skipped() raises:
    """Only the operations have variable definitions."""
    expect_hidden(
        "type Query { hello(arg: String!): String }",
        "query Foo($bar: String!) { ...F } fragment F on Query { hello }",
        "{}",
        'Variable "$bar" of required type "String!" was not provided.',
    )


def test_operation_without_variables() raises:
    """An operation without variable definitions is valid."""
    expect_hidden("type Query { hello: String }", "{ hello }", '{"bar":1}', "")


def test_mapping_without_the_variable() raises:
    """A variables map without the name keeps the operation name."""
    expect_hidden(
        "type Query { hello(arg: String!): String }",
        "query Foo($bar: String!) { hello(arg: $bar) }",
        '{"bar":1}',
        (
            'Variable "$bar" got invalid value; String cannot represent a non'
            " string value"
        ),
        remap("other", "bazz"),
    )


def test_required_upload_variable_provided_with_null() raises:
    """A `null` is valid for a variable of type `Upload!`."""
    expect_hidden(
        "scalar Upload type Query { hello(file: Upload!): String }",
        "query Foo($file: Upload!) { hello(file: $file) }",
        '{"file":null}',
        "",
    )


def test_required_list_input_field_provided_with_null() raises:
    """A `null` for an input field of type `[String]!` is not provided."""
    expect_hidden(
        "input Foo { bar: [String]! } type Query { hello(arg: Foo): String }",
        "query Foo($input: Foo) { hello(arg: $input) }",
        '{"input":{"bar":null}}',
        (
            'Variable "$input" got invalid value; Field "bar" of required type'
            ' "[String]!" was not provided.'
        ),
    )


comptime OPTIONAL_FOO = (
    "input Foo { bar: String } type Query { hello(a: Foo, b: Foo, c: String):"
    " String }"
)
"""The schema with an optional input object."""


def test_first_nested_error_stops_later_nested_checks() raises:
    """After an error, the named type checks of later variables stop."""
    expect_shown(
        OPTIONAL_FOO,
        "query Foo($a: Foo, $b: Foo) { hello(a: $a, b: $b) }",
        '{"a":{"bar":1},"b":{"bar":2}}',
        (
            'Variable "$a" got invalid value 1 at "a.bar"; String cannot'
            " represent a non string value: 1"
        ),
    )


def test_later_required_error_replaces_earlier_error() raises:
    """A missing required variable replaces an earlier error, as upstream
    sets `v.err` again."""
    expect_hidden(
        OPTIONAL_FOO,
        "query Foo($a: Foo, $c: String!) { hello(a: $a, c: $c) }",
        '{"a":{"bar":1}}',
        'Variable "$c" of required type "String!" was not provided.',
    )


def test_variable_of_unknown_type() raises:
    """A type that the schema does not define takes any value."""
    expect_hidden(
        "type Query { hello: String }",
        "query Foo($x: Unknown) { hello }",
        '{"x":1}',
        "",
    )


def test_variable_of_output_type() raises:
    """An output type takes any value: upstream checks only input types."""
    expect_hidden(
        "type Query { hello: String }",
        "query Foo($x: Query) { hello }",
        '{"x":1}',
        "",
    )


def test_custom_scalar_takes_any_value() raises:
    """A custom scalar takes any value."""
    expect_hidden(
        "scalar Baz type Query { hello(arg: Baz!): String }",
        "query Foo($bar: Baz!) { hello(arg: $bar) }",
        '{"bar":{"any":[1]}}',
        "",
    )


comptime HIDDEN_ENUM = (
    "directive @inaccessible on ENUM_VALUE enum Foo { BAR @inaccessible BAZ"
    " @deprecated QUX } type Query { hello(arg: Foo): String }"
)
"""The schema with an `@inaccessible` enum value."""
comptime HIDDEN_QUERY = "query Foo($bar: Foo) { hello(arg: $bar) }"
"""The operation that takes `$bar: Foo`."""


def test_inaccessible_enum_value_does_not_exist() raises:
    """An `@inaccessible` enum value does not exist."""
    expect_shown(
        HIDDEN_ENUM,
        HIDDEN_QUERY,
        '{"bar":"BAR"}',
        (
            'Variable "$bar" got invalid value "BAR"; Value "BAR" does not'
            ' exist in "Foo" enum.'
        ),
    )


def test_enum_value_with_other_directive_exists() raises:
    """An enum value with another directive exists."""
    expect_hidden(HIDDEN_ENUM, HIDDEN_QUERY, '{"bar":"BAZ"}', "")
    expect_hidden(HIDDEN_ENUM, HIDDEN_QUERY, '{"bar":"QUX"}', "")


def test_path_item_kind_is_valid() raises:
    """The path item kinds are valid, and other values are not."""
    assert_true(_PathItemKind.OBJECT.is_valid())
    assert_true(_PathItemKind.ARRAY.is_valid())
    assert_false(_PathItemKind(2).is_valid())
    assert_false(_PathItemKind.OBJECT == _PathItemKind.ARRAY)


def main() raises:
    """Run the suite."""
    TestSuite.discover_tests[__functions_in_module()]().run()

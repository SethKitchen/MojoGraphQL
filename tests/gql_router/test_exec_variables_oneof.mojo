# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Input coercion of OneOf input objects (spec §3.10.1) for JSON
variables: exactly one field must be given, and its value must not be
`null`.

Port of Hive Router `1a29df9`
`bin/router/src/executor/variables/tests/oneof.rs`. Upstream marks no test
`#[ignore]`. The defaults helper `test_one_of_with_default` is
`nullable_one_of_with_default` here, so that the suite does not run it.

**Differences from upstream.** `gql_validation` follows graphql-js
`VariablesInAllowedPositionRule`: it refuses a nullable variable in a
OneOf field only when the parent input type is not wrapped in non-null.
graphql-tools also refuses it under `OneOfTestInput!`. So
`nullable_variable_in_oneof_literal_is_rejected_by_validation` and
`defaulted_nullable_variable_in_oneof_literal_is_rejected_by_validation`
use the argument `fieldWithOneOfObjectInput(input: TestOneOfInputObject)`
in place of `test(input: OneOfTestInput!)`.
"""

from _variables_harness import Harness
from std.testing import TestSuite

comptime ONE_OF = (
    "query ($input: OneOfTestInput!) { test(input: $input) { a b } }"
)
comptime INT_ONE_OF = "query ($input: IntOneOf) { intOneOf(input: $input) }"
comptime ONE_OF_LIST = (
    "query ($input: [OneOfTestInput!]) { oneOfList(input: $input) }"
)
comptime ONE_OF_HOLDER = (
    "query ($input: OneOfHolder) { oneOfHolder(input: $input) }"
)
comptime RECURSIVE_ONE_OF = (
    "query ($input: RecursiveOneOf) { recursiveOneOf(input: $input) }"
)


def one_of_error(type_name: String) -> String:
    """The OneOf reason for a type."""
    return String(
        'Within OneOf Input Object type "',
        type_name,
        (
            '", exactly one field must be specified, and the value for that'
            " field must be non-null."
        ),
    )


def rejects(
    mut h: Harness,
    operation: String,
    variables: String,
    path: String,
    reason: String,
) raises:
    """Assert a rejection of `$input` at a path."""
    h.assert_rejected(
        operation,
        variables,
        String('Variable "$input" has invalid value', path, ": ", reason),
    )


def accepts(mut h: Harness, operation: String, variables: String) raises:
    """Assert that the variables are accepted and kept."""
    h.assert_coerced(operation, variables, variables)


# --- valid values -----------------------------------------------------


def test_accepts_oneof_with_single_string_member() raises:
    var h = Harness()
    accepts(h, ONE_OF, '{"input":{"a":"abc"}}')


def test_accepts_oneof_with_single_int_member() raises:
    var h = Harness()
    accepts(h, ONE_OF, '{"input":{"b":123}}')


def test_accepts_oneof_with_falsy_non_null_member() raises:
    var h = Harness()
    accepts(h, ONE_OF, '{"input":{"b":0}}')
    accepts(h, ONE_OF, '{"input":{"a":""}}')


def test_accepts_explicit_null_for_nullable_oneof_variable_with_default() raises:
    var h = Harness()
    accepts(
        h,
        (
            'query ($input: OneOfTestInput = {a: "abc"}) { test(input: $input)'
            " { a b } }"
        ),
        '{"input":null}',
    )


def test_does_not_apply_oneof_rule_to_regular_input_object() raises:
    var h = Harness()
    accepts(
        h,
        "query ($input: ExampleInputObject) { exampleInput(input: $input) }",
        '{"input":{"a":"abc","b":1}}',
    )


# --- count and null ---------------------------------------------------


def test_rejects_oneof_with_no_fields() raises:
    var h = Harness()
    rejects(h, ONE_OF, '{"input":{}}', "", one_of_error("OneOfTestInput"))


def test_rejects_oneof_with_two_non_null_fields() raises:
    var h = Harness()
    rejects(
        h,
        ONE_OF,
        '{"input":{"a":"abc","b":123}}',
        "",
        one_of_error("OneOfTestInput"),
    )


def test_rejects_oneof_with_additional_null_field() raises:
    var h = Harness()
    rejects(
        h,
        ONE_OF,
        '{"input":{"a":"abc","b":null}}',
        "",
        one_of_error("OneOfTestInput"),
    )


def test_rejects_oneof_with_null_field_listed_first() raises:
    var h = Harness()
    rejects(
        h,
        ONE_OF,
        '{"input":{"b":null,"a":"abc"}}',
        "",
        one_of_error("OneOfTestInput"),
    )


def test_rejects_oneof_with_all_fields_null() raises:
    var h = Harness()
    rejects(
        h,
        ONE_OF,
        '{"input":{"a":null,"b":null}}',
        "",
        one_of_error("OneOfTestInput"),
    )


def test_rejects_oneof_with_two_invalid_members() raises:
    var h = Harness()
    rejects(
        h,
        ONE_OF,
        '{"input":{"a":456,"b":"xyz"}}',
        "",
        one_of_error("OneOfTestInput"),
    )


def test_rejects_oneof_with_single_null_member() raises:
    var h = Harness()
    rejects(
        h,
        ONE_OF,
        '{"input":{"a":null}}',
        " at .a",
        one_of_error("OneOfTestInput"),
    )


# --- member values and unknown fields ---------------------------------


def test_rejects_oneof_member_of_wrong_type() raises:
    var h = Harness()
    rejects(
        h,
        INT_ONE_OF,
        '{"input":{"foo":1.5}}',
        " at .foo",
        "Int cannot represent non-integer value: 1.5",
    )


def test_rejects_non_object_for_oneof() raises:
    var h = Harness()
    rejects(
        h,
        INT_ONE_OF,
        '{"input":123}',
        "",
        'Expected value of type "IntOneOf" to be an object, found: 123.',
    )


def test_rejects_array_for_non_list_oneof() raises:
    var h = Harness()
    rejects(
        h,
        ONE_OF,
        '{"input":[{"a":"abc"}]}',
        "",
        (
            'Expected value of type "OneOfTestInput" to be an object, found:'
            ' [{ a: "abc" }].'
        ),
    )


def test_rejects_unknown_field_next_to_valid_member() raises:
    var h = Harness()
    rejects(
        h,
        INT_ONE_OF,
        '{"input":{"foo":123,"unknownField":123}}',
        "",
        one_of_error("IntOneOf"),
    )


def test_rejects_oneof_with_only_unknown_field() raises:
    var h = Harness()
    rejects(
        h,
        INT_ONE_OF,
        '{"input":{"bart":123}}',
        "",
        (
            'Expected value of type "IntOneOf" not to include unknown field'
            ' "bart", found: { bart: 123 }.'
        ),
    )


# --- nested -----------------------------------------------------------


def test_accepts_list_of_valid_oneofs() raises:
    var h = Harness()
    accepts(h, ONE_OF_LIST, '{"input":[{"a":"abc"},{"b":1}]}')


def test_rejects_list_item_with_two_oneof_fields() raises:
    var h = Harness()
    rejects(
        h,
        ONE_OF_LIST,
        '{"input":[{"a":"x"},{"a":"x","b":1}]}',
        " at [1]",
        one_of_error("OneOfTestInput"),
    )


def test_rejects_list_item_with_null_oneof_member() raises:
    var h = Harness()
    rejects(
        h,
        ONE_OF_LIST,
        '{"input":[{"a":null}]}',
        " at [0].a",
        one_of_error("OneOfTestInput"),
    )


def test_accepts_single_oneof_for_list_type_unwrapped() raises:
    var h = Harness()
    accepts(h, ONE_OF_LIST, '{"input":{"a":"abc"}}')


def test_rejects_single_empty_oneof_for_list_type() raises:
    var h = Harness()
    rejects(h, ONE_OF_LIST, '{"input":{}}', "", one_of_error("OneOfTestInput"))


def test_accepts_oneof_nested_in_input_object() raises:
    var h = Harness()
    accepts(h, ONE_OF_HOLDER, '{"input":{"one":{"a":"abc"},"many":[{"b":1}]}}')


def test_accepts_null_for_nullable_nested_oneof_field() raises:
    var h = Harness()
    accepts(h, ONE_OF_HOLDER, '{"input":{"one":null,"name":"x"}}')


def test_rejects_nested_oneof_with_two_fields() raises:
    var h = Harness()
    rejects(
        h,
        ONE_OF_HOLDER,
        '{"input":{"one":{"a":"abc","b":1}}}',
        " at .one",
        one_of_error("OneOfTestInput"),
    )


def test_rejects_nested_oneof_with_null_member() raises:
    var h = Harness()
    rejects(
        h,
        ONE_OF_HOLDER,
        '{"input":{"one":{"a":null}}}',
        " at .one.a",
        one_of_error("OneOfTestInput"),
    )


def test_rejects_empty_oneof_in_nested_list() raises:
    var h = Harness()
    rejects(
        h,
        ONE_OF_HOLDER,
        '{"input":{"many":[{"a":"x"},{}]}}',
        " at .many[1]",
        one_of_error("OneOfTestInput"),
    )


def test_accepts_recursive_oneof_with_empty_list_member() raises:
    var h = Harness()
    accepts(h, RECURSIVE_ONE_OF, '{"input":{"not":{"and":[]}}}')


def test_rejects_invalid_oneof_deep_in_recursive_oneof() raises:
    var h = Harness()
    rejects(
        h,
        RECURSIVE_ONE_OF,
        '{"input":{"and":[{"leaf":1},{"not":{}}]}}',
        " at .and[1].not",
        one_of_error("RecursiveOneOf"),
    )


def test_many_invalid_oneof_items_yield_one_request_error() raises:
    var items = String("{}")
    for _ in range(999):
        items += ",{}"
    var h = Harness()
    rejects(
        h,
        ONE_OF_LIST,
        String('{"input":[', items, "]}"),
        " at [0]",
        one_of_error("OneOfTestInput"),
    )


# --- defaults ---------------------------------------------------------


def one_of_with_default(default: String) -> String:
    """An operation with a `OneOfTestInput!` default."""
    return String(
        "query ($input: OneOfTestInput! = ",
        default,
        ") { test(input: $input) { a b } }",
    )


def nullable_one_of_with_default(default: String) -> String:
    """An operation with a `TestOneOfInputObject` default."""
    return String(
        "query ($input: TestOneOfInputObject = ",
        default,
        ") { fieldWithOneOfObjectInput(input: $input) }",
    )


def test_accepts_good_oneof_default() raises:
    var h = Harness()
    h.assert_coerced(
        one_of_with_default('{a: "abc"}'), "{}", '{"input":{"a":"abc"}}'
    )


def test_accepts_good_oneof_default_for_second_member() raises:
    var h = Harness()
    h.assert_coerced(
        nullable_one_of_with_default('{b: "def"}'),
        "{}",
        '{"input":{"b":"def"}}',
    )


def test_oneof_default_with_two_fields_is_rejected_by_validation() raises:
    var h = Harness()
    h.assert_rejected_by_validation(
        one_of_with_default('{a: "abc", b: 123}'), "ValuesOfCorrectType"
    )


def test_oneof_default_with_additional_null_field_is_rejected_by_validation() raises:
    var h = Harness()
    h.assert_rejected_by_validation(
        nullable_one_of_with_default('{a: "abc", b: null}'),
        "ValuesOfCorrectType",
    )


def test_oneof_default_with_single_null_member_is_rejected_by_validation() raises:
    var h = Harness()
    h.assert_rejected_by_validation(
        nullable_one_of_with_default("{a: null}"), "ValuesOfCorrectType"
    )


def test_empty_oneof_default_is_rejected_by_validation() raises:
    var h = Harness()
    h.assert_rejected_by_validation(
        nullable_one_of_with_default("{}"), "ValuesOfCorrectType"
    )


def test_oneof_default_with_unknown_field_is_rejected_by_validation() raises:
    var h = Harness()
    h.assert_rejected_by_validation(
        nullable_one_of_with_default('{a: "abc", c: "def"}'),
        "ValuesOfCorrectType",
    )


# --- literals ---------------------------------------------------------


def test_oneof_literal_with_two_fields_is_rejected_by_validation() raises:
    var h = Harness()
    h.assert_rejected_by_validation(
        '{ test(input: {a: "abc", b: 123}) { a b } }', "ValuesOfCorrectType"
    )


def test_oneof_literal_with_null_field_is_rejected_by_validation() raises:
    var h = Harness()
    h.assert_rejected_by_validation(
        "{ test(input: {a: null}) { a b } }", "ValuesOfCorrectType"
    )


def test_nullable_variable_in_oneof_literal_is_rejected_by_validation() raises:
    var h = Harness()
    # `fieldWithOneOfObjectInput` in place of `test`; see the module docstring.
    h.assert_rejected_by_validation(
        "query ($a: String) { fieldWithOneOfObjectInput(input: {a: $a}) }",
        "VariablesInAllowedPosition",
    )


def test_defaulted_nullable_variable_in_oneof_literal_is_rejected_by_validation() raises:
    # `fieldWithOneOfObjectInput` in place of `test`; see the module docstring.
    var h = Harness()
    h.assert_rejected_by_validation(
        (
            'query ($a: String = "abc") { fieldWithOneOfObjectInput(input: {a:'
            " $a}) }"
        ),
        "VariablesInAllowedPosition",
    )


# --- variables in literals --------------------------------------------

comptime NON_NULL = "query ($a: String!) { test(input: {a: $a}) { a b } }"


def test_forwards_non_null_variable_in_oneof_literal() raises:
    var h = Harness()
    h.assert_coerced(NON_NULL, '{"a":"abc"}', '{"a":"abc"}')


def test_rejects_null_for_non_null_variable_in_oneof_literal() raises:
    var h = Harness()
    h.assert_rejected(
        NON_NULL,
        '{"a":null}',
        (
            'Variable "$a" has invalid value: Expected value of non-null type'
            ' "String!" not to be null.'
        ),
    )


def test_rejects_missing_non_null_variable_in_oneof_literal() raises:
    var h = Harness()
    h.assert_rejected(
        NON_NULL,
        "{}",
        (
            'Variable "$a" has invalid value: Expected a value of non-null'
            ' type "String!" to be provided.'
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

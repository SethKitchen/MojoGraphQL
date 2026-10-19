# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Input coercion of lists (spec §3.11) and non-null types (spec §3.12)
for JSON variables.

Port of Hive Router `1a29df9`
`bin/router/src/executor/variables/tests/lists.rs`. Upstream marks no test
`#[ignore]`. The `nullability_matrix` helpers `accepts` and `rejects` are
`matrix_accepts` and `matrix_rejects` here.
"""

from _variables_harness import Harness
from std.testing import TestSuite


def operation(variable_type: String) -> String:
    """`query ($value: <variable_type>) { fieldWithNullableStringInput }`."""
    return String(
        "query ($value: ", variable_type, ") { fieldWithNullableStringInput }"
    )


def variables(value: String) -> String:
    """`{"value":<value>}`."""
    return String('{"value":', value, "}")


def accepts(mut h: Harness, variable_type: String, value: String) raises:
    """Assert that `$value` of a type is accepted and kept."""
    h.assert_coerced(
        operation(variable_type), variables(value), variables(value)
    )


def rejects(
    mut h: Harness,
    variable_type: String,
    value: String,
    path: String,
    reason: String,
) raises:
    """Assert that `$value` of a type is rejected at a path."""
    h.assert_rejected(
        operation(variable_type),
        variables(value),
        String('Variable "$value" has invalid value', path, ": ", reason),
    )


# --- non-null ---------------------------------------------------------


def test_non_null_returns_no_error_for_non_null_value() raises:
    var h = Harness()
    accepts(h, "Int!", "1")


def test_non_null_value_is_coerced_by_the_wrapped_type() raises:
    var h = Harness()
    rejects(h, "Int!", '"1"', "", 'Int cannot represent non-integer value: "1"')


def test_non_null_list_variable_missing() raises:
    var h = Harness()
    h.assert_rejected(
        "query ($input: [String]!) { nnList(input: $input) }",
        "{}",
        (
            'Variable "$input" has invalid value: Expected a value of non-null'
            ' type "[String]!" to be provided.'
        ),
    )


# --- spec non-null examples -------------------------------------------


def test_spec_non_null_argument_cannot_be_omitted() raises:
    var h = Harness()
    h.assert_rejected_by_validation(
        "{ withNonNullArg }", "ProvidedRequiredArguments"
    )


def test_spec_null_literal_for_non_null_argument() raises:
    var h = Harness()
    h.assert_rejected_by_validation(
        "{ withNonNullArg(cannotBeNull: null) }", "ValuesOfCorrectType"
    )


def test_spec_nullable_variable_for_non_null_argument() raises:
    var h = Harness()
    h.assert_rejected_by_validation(
        (
            "query withNullableVariable($var: String) {"
            " withNonNullArg(cannotBeNull: $var) }"
        ),
        "VariablesInAllowedPosition",
    )


# --- nullability matrix -----------------------------------------------

comptime LIST = "query ($input: [String]) { list(input: $input) }"
comptime NN_LIST = "query ($input: [String]!) { nnList(input: $input) }"
comptime LIST_NN = "query ($input: [String!]) { listNN(input: $input) }"
comptime NN_LIST_NN = "query ($input: [String!]!) { nnListNN(input: $input) }"


def input(value: String) -> String:
    """`{"input":<value>}`."""
    return String('{"input":', value, "}")


def matrix_accepts(mut h: Harness, operation: String, value: String) raises:
    """Assert that `$input` is accepted and kept."""
    h.assert_coerced(operation, input(value), input(value))


def matrix_rejects(
    mut h: Harness,
    operation: String,
    value: String,
    path: String,
    reason: String,
) raises:
    """Assert that `$input` is rejected at a path."""
    h.assert_rejected(
        operation,
        input(value),
        String('Variable "$input" has invalid value', path, ": ", reason),
    )


def test_allows_lists_to_be_null() raises:
    var h = Harness()
    matrix_accepts(h, LIST, "null")


def test_allows_lists_to_contain_values() raises:
    var h = Harness()
    matrix_accepts(h, LIST, '["A"]')


def test_allows_lists_to_contain_null() raises:
    var h = Harness()
    matrix_accepts(h, LIST, '["A",null,"B"]')


def test_does_not_allow_non_null_lists_to_be_null() raises:
    var h = Harness()
    matrix_rejects(
        h,
        NN_LIST,
        "null",
        "",
        'Expected value of non-null type "[String]!" not to be null.',
    )


def test_allows_non_null_lists_to_contain_values() raises:
    var h = Harness()
    matrix_accepts(h, NN_LIST, '["A"]')


def test_allows_non_null_lists_to_contain_null() raises:
    var h = Harness()
    matrix_accepts(h, NN_LIST, '["A",null,"B"]')


def test_allows_lists_of_non_nulls_to_be_null() raises:
    var h = Harness()
    matrix_accepts(h, LIST_NN, "null")


def test_allows_lists_of_non_nulls_to_contain_values() raises:
    var h = Harness()
    matrix_accepts(h, LIST_NN, '["A"]')


def test_does_not_allow_lists_of_non_nulls_to_contain_null() raises:
    var h = Harness()
    matrix_rejects(
        h,
        LIST_NN,
        '["A",null,"B"]',
        " at [1]",
        'Expected value of non-null type "String!" not to be null.',
    )


def test_does_not_allow_non_null_lists_of_non_nulls_to_be_null() raises:
    var h = Harness()
    matrix_rejects(
        h,
        NN_LIST_NN,
        "null",
        "",
        'Expected value of non-null type "[String!]!" not to be null.',
    )


def test_allows_non_null_lists_of_non_nulls_to_contain_values() raises:
    var h = Harness()
    matrix_accepts(h, NN_LIST_NN, '["A"]')


def test_does_not_allow_non_null_lists_of_non_nulls_to_contain_null() raises:
    var h = Harness()
    matrix_rejects(
        h,
        NN_LIST_NN,
        '["A",null,"B"]',
        " at [1]",
        'Expected value of non-null type "String!" not to be null.',
    )


def test_list_of_non_null_rejects_a_null_first_item() raises:
    var h = Harness()
    rejects(
        h,
        "[Int!]",
        "[null]",
        " at [0]",
        'Expected value of non-null type "Int!" not to be null.',
    )


def test_non_null_list_accepts_an_empty_list() raises:
    var h = Harness()
    matrix_accepts(h, NN_LIST, "[]")


def test_non_null_list_of_non_null_accepts_an_empty_list() raises:
    var h = Harness()
    matrix_accepts(h, NN_LIST_NN, "[]")


def test_non_null_list_of_non_null_accepts_a_single_value() raises:
    var h = Harness()
    matrix_accepts(h, NN_LIST_NN, '"A"')


# --- list coercion ----------------------------------------------------


def test_list_returns_no_error_for_a_valid_input() raises:
    var h = Harness()
    accepts(h, "[Int]", "[1,2,3]")


def test_list_returns_an_error_for_an_invalid_input() raises:
    var h = Harness()
    rejects(
        h,
        "[Int]",
        '[1,"b",true,4]',
        " at [1]",
        'Int cannot represent non-integer value: "b"',
    )


def test_list_accepts_a_non_list_value() raises:
    var h = Harness()
    accepts(h, "[Int]", "42")


def test_list_returns_an_error_for_a_non_list_invalid_value() raises:
    var h = Harness()
    rejects(
        h,
        "[Int]",
        '"INVALID"',
        "",
        'Int cannot represent non-integer value: "INVALID"',
    )


def test_list_returns_null_for_a_null_value() raises:
    var h = Harness()
    accepts(h, "[Int]", "null")


def test_list_accepts_an_empty_list() raises:
    var h = Harness()
    accepts(h, "[Int]", "[]")


def test_list_of_string_accepts_a_single_string() raises:
    var h = Harness()
    accepts(h, "[String]", '"AB"')


def test_list_of_string_rejects_a_single_number() raises:
    var h = Harness()
    rejects(
        h,
        "[String]",
        "123",
        "",
        "String cannot represent a non string value: 123",
    )


def test_list_rejects_an_object_as_a_single_item() raises:
    var h = Harness()
    rejects(
        h,
        "[Int]",
        '{"length":1}',
        "",
        "Int cannot represent non-integer value: { length: 1 }",
    )


def test_list_rejects_a_list_as_an_item() raises:
    var h = Harness()
    rejects(
        h,
        "[Int]",
        "[[1]]",
        " at [0]",
        "Int cannot represent non-integer value: [1]",
    )


def test_non_list_type_rejects_a_list() raises:
    var h = Harness()
    rejects(h, "Int", "[1]", "", "Int cannot represent non-integer value: [1]")


# --- nested lists -----------------------------------------------------


def test_nested_list_returns_no_error_for_a_valid_input() raises:
    var h = Harness()
    accepts(h, "[[Int]]", "[[1],[2,3]]")


def test_nested_list_accepts_a_non_list_value() raises:
    var h = Harness()
    accepts(h, "[[Int]]", "42")


def test_nested_list_returns_null_for_a_null_value() raises:
    var h = Harness()
    accepts(h, "[[Int]]", "null")


def test_nested_list_accepts_nested_non_list_values() raises:
    var h = Harness()
    accepts(h, "[[Int]]", "[1,2,3]")


def test_nested_list_accepts_nested_null_values() raises:
    var h = Harness()
    accepts(h, "[[Int]]", "[42,[null],null]")


def test_nested_list_keeps_a_null_item_null() raises:
    var h = Harness()
    accepts(h, "[[Int]]", "[1,null,3]")


def test_nested_list_rejects_an_incorrect_item_value() raises:
    var h = Harness()
    rejects(
        h,
        "[[Int]]",
        '[[1],["b"]]',
        " at [1][0]",
        'Int cannot represent non-integer value: "b"',
    )


def test_nested_list_wrapped_item_error_has_no_inner_index() raises:
    var h = Harness()
    rejects(
        h,
        "[[Int]]",
        '[1,"b"]',
        " at [1]",
        'Int cannot represent non-integer value: "b"',
    )


def test_nested_list_rejects_a_non_list_invalid_value() raises:
    var h = Harness()
    rejects(
        h, "[[Int]]", '"b"', "", 'Int cannot represent non-integer value: "b"'
    )


def test_nested_list_accepts_an_empty_inner_list() raises:
    var h = Harness()
    accepts(h, "[[Int]]", "[[]]")


# --- nested lists with non-null ---------------------------------------


def test_nested_list_of_non_null_rejects_a_null_item() raises:
    var h = Harness()
    rejects(
        h,
        "[[Int!]]",
        "[[1],[null]]",
        " at [1][0]",
        'Expected value of non-null type "Int!" not to be null.',
    )


def test_nested_list_of_non_null_allows_a_null_inner_list() raises:
    var h = Harness()
    accepts(h, "[[Int!]]", "[[1],null]")


def test_nested_list_of_non_null_wraps_items_and_allows_null() raises:
    var h = Harness()
    accepts(h, "[[Int!]]", "[1,null]")


def test_list_of_non_null_lists_rejects_a_null_inner_list() raises:
    var h = Harness()
    rejects(
        h,
        "[[Int]!]",
        "[[1],null]",
        " at [1]",
        'Expected value of non-null type "[Int]!" not to be null.',
    )


def test_list_of_non_null_lists_allows_null_items() raises:
    var h = Harness()
    accepts(h, "[[Int]!]", "[[null]]")


def test_fully_non_null_nested_list_accepts_an_empty_inner_list() raises:
    var h = Harness()
    accepts(h, "[[Int!]!]!", "[[]]")


def test_fully_non_null_nested_list_accepts_a_scalar() raises:
    var h = Harness()
    accepts(h, "[[Int!]!]!", "1")


def test_fully_non_null_nested_list_rejects_a_null_inner_list() raises:
    var h = Harness()
    rejects(
        h,
        "[[Int!]!]!",
        "[1,[2],null]",
        " at [2]",
        'Expected value of non-null type "[Int!]!" not to be null.',
    )


def test_fully_non_null_nested_list_rejects_null() raises:
    var h = Harness()
    rejects(
        h,
        "[[Int!]!]!",
        "null",
        "",
        'Expected value of non-null type "[[Int!]!]!" not to be null.',
    )


# --- defaults ---------------------------------------------------------


def test_list_default_single_value_is_inserted_as_is() raises:
    var h = Harness()
    h.assert_coerced(operation("[Int] = 1"), "{}", '{"value":1}')


def test_non_null_list_default_with_null_item_is_rejected_by_validation() raises:
    var h = Harness()
    h.assert_rejected_by_validation(
        "query ($value: [Int!]! = [1, null]) { fieldWithNullableStringInput }",
        "ValuesOfCorrectType",
    )


# --- large inputs -----------------------------------------------------


def ints(first: Int, count: Int) -> String:
    """`first,first+1,...` with `count` integers."""
    var out = String()
    for n in range(first, first + count):
        if n > first:
            out += ","
        out += String(n)
    return out^


def test_large_list_of_valid_items_is_forwarded_unchanged() raises:
    var value = String("[", ints(0, 100_000), "]")
    var h = Harness()
    h.assert_forwarded(operation("[Int]"), variables(value), variables(value))


def test_large_list_of_nulls_yields_one_error() raises:
    var value = String("[null")
    for _ in range(99_999):
        value += ",null"
    value += "]"
    var h = Harness()
    rejects(
        h,
        "[Int!]",
        value,
        " at [0]",
        'Expected value of non-null type "Int!" not to be null.',
    )


def test_large_list_reports_the_last_index() raises:
    var value = String("[", ints(0, 99_999), ',"x"]')
    var h = Harness()
    rejects(
        h,
        "[Int]",
        value,
        " at [99999]",
        'Int cannot represent non-integer value: "x"',
    )


def test_invalid_item_message_is_bounded() raises:
    var value = String("[[", ints(1, 100_000), "]]")
    var h = Harness()
    rejects(
        h,
        "[Int]",
        value,
        " at [0]",
        (
            "Int cannot represent non-integer value: [1, 2, 3, 4, 5, 6, 7, 8,"
            " 9, 10, ... 99990 more items]"
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

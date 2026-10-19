# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The `CoerceVariableValues` algorithm itself (spec §6.1.2), independent
of the value types.

Port of Hive Router `1a29df9`
`bin/router/src/executor/variables/tests/variable_level.rs`. Upstream
marks no test `#[ignore]`.
"""

from _variables_harness import Harness
from std.testing import TestSuite

comptime NULLABLE = "query ($v: Int) { int(input: $v) }"
comptime NULLABLE_WITH_DEFAULT = "query ($v: Int = 5) { int(input: $v) }"
comptime NULLABLE_WITH_NULL_DEFAULT = (
    "query ($v: Int = null) { int(input: $v) }"
)
comptime NON_NULL = "query ($v: Int!) { int(input: $v) }"
comptime NON_NULL_WITH_DEFAULT = "query ($v: Int! = 5) { int(input: $v) }"
comptime NON_NULL_WITH_NULL_DEFAULT = (
    "query ($v: Int! = null) { int(input: $v) }"
)
comptime DEFAULTED_IN_NON_NULL_ARGUMENT = (
    'query ($v: String = "default") { fieldWithNonNullableStringInput(input:'
    " $v) }"
)

comptime NOT_PROVIDED = (
    'Variable "$v" has invalid value: Expected a value of non-null type'
    ' "Int!" to be provided.'
)
comptime NOT_NULL = (
    'Variable "$v" has invalid value: Expected value of non-null type "Int!"'
    " not to be null."
)


# --- decision table ---------------------------------------------------


def test_nullable_absent_has_no_entry() raises:
    var h = Harness()
    h.assert_coerced(NULLABLE, "{}", "{}")


def test_nullable_null_is_null() raises:
    var h = Harness()
    h.assert_coerced(NULLABLE, '{"v":null}', '{"v":null}')


def test_nullable_value_is_kept() raises:
    var h = Harness()
    h.assert_coerced(NULLABLE, '{"v":1}', '{"v":1}')


def test_nullable_with_default_absent_uses_default() raises:
    var h = Harness()
    h.assert_coerced(NULLABLE_WITH_DEFAULT, "{}", '{"v":5}')


def test_nullable_with_default_null_is_null() raises:
    var h = Harness()
    h.assert_coerced(NULLABLE_WITH_DEFAULT, '{"v":null}', '{"v":null}')


def test_nullable_with_default_value_beats_default() raises:
    var h = Harness()
    h.assert_coerced(NULLABLE_WITH_DEFAULT, '{"v":1}', '{"v":1}')


def test_null_default_absent_is_null() raises:
    var h = Harness()
    h.assert_coerced(NULLABLE_WITH_NULL_DEFAULT, "{}", '{"v":null}')


def test_null_with_null_default_is_null() raises:
    var h = Harness()
    h.assert_coerced(NULLABLE_WITH_NULL_DEFAULT, '{"v":null}', '{"v":null}')


def test_value_with_null_default_is_kept() raises:
    var h = Harness()
    h.assert_coerced(NULLABLE_WITH_NULL_DEFAULT, '{"v":1}', '{"v":1}')


def test_non_null_absent_is_rejected() raises:
    var h = Harness()
    h.assert_rejected(NON_NULL, "{}", NOT_PROVIDED)


def test_non_null_null_is_rejected() raises:
    var h = Harness()
    h.assert_rejected(NON_NULL, '{"v":null}', NOT_NULL)


def test_non_null_value_is_kept() raises:
    var h = Harness()
    h.assert_coerced(NON_NULL, '{"v":1}', '{"v":1}')


def test_non_null_with_default_absent_uses_default() raises:
    var h = Harness()
    h.assert_coerced(NON_NULL_WITH_DEFAULT, "{}", '{"v":5}')


def test_non_null_with_default_null_is_rejected() raises:
    var h = Harness()
    h.assert_rejected(NON_NULL_WITH_DEFAULT, '{"v":null}', NOT_NULL)


def test_value_beats_non_null_default() raises:
    var h = Harness()
    h.assert_coerced(NON_NULL_WITH_DEFAULT, '{"v":7}', '{"v":7}')


def test_non_null_variable_with_null_default_is_rejected_by_validation() raises:
    var h = Harness()
    h.assert_rejected_by_validation(
        NON_NULL_WITH_NULL_DEFAULT, "ValuesOfCorrectType"
    )


def test_non_null_with_null_default_absent_is_rejected() raises:
    var h = Harness()
    h.assert_rejected(
        NON_NULL_WITH_NULL_DEFAULT,
        "{}",
        (
            'Variable "$v" has invalid default value: Expected value of'
            ' non-null type "Int!" not to be null.'
        ),
    )


def test_non_null_with_null_default_null_is_rejected() raises:
    var h = Harness()
    h.assert_rejected(NON_NULL_WITH_NULL_DEFAULT, '{"v":null}', NOT_NULL)


def test_non_null_with_null_default_value_is_kept() raises:
    var h = Harness()
    h.assert_coerced(NON_NULL_WITH_NULL_DEFAULT, '{"v":1}', '{"v":1}')


def test_defaulted_variable_in_non_null_argument_absent_uses_default() raises:
    var h = Harness()
    h.assert_coerced(DEFAULTED_IN_NON_NULL_ARGUMENT, "{}", '{"v":"default"}')


def test_defaulted_variable_in_non_null_argument_null_is_kept() raises:
    var h = Harness()
    h.assert_coerced(DEFAULTED_IN_NON_NULL_ARGUMENT, '{"v":null}', '{"v":null}')


def test_defaulted_variable_in_non_null_argument_value_is_kept() raises:
    var h = Harness()
    h.assert_coerced(DEFAULTED_IN_NON_NULL_ARGUMENT, '{"v":"a"}', '{"v":"a"}')


# --- defaults ---------------------------------------------------------


def test_input_object_default_is_kept_as_written() raises:
    var h = Harness()
    h.assert_coerced(
        "query ($v: DefaultSevenInput = {}) { defaultSeven(input: $v) }",
        "{}",
        '{"v":{}}',
    )


def test_invalid_default_is_ignored_when_a_value_is_provided() raises:
    var h = Harness()
    h.assert_coerced(
        "query ($v: String = 123) { fieldWithNullableStringInput(input: $v) }",
        '{"v":"x"}',
        '{"v":"x"}',
    )


def test_invalid_default_is_rejected_when_used() raises:
    var h = Harness()
    h.assert_rejected(
        "query ($v: Int = [1]) { int(input: $v) }",
        "{}",
        (
            'Variable "$v" has invalid default value: Int cannot represent'
            " non-integer value: [1]"
        ),
    )


# --- definitions ------------------------------------------------------


def test_unused_variable_is_still_coerced() raises:
    var h = Harness()
    h.assert_rejected(
        (
            "query ($v: String, $unused: String!) {"
            " fieldWithNullableStringInput(input: $v) }"
        ),
        "{}",
        (
            'Variable "$unused" has invalid value: Expected a value of'
            ' non-null type "String!" to be provided.'
        ),
    )


def test_variable_names_are_case_sensitive() raises:
    var h = Harness()
    h.assert_rejected(
        "query ($v: String!) { fieldWithNonNullableStringInput(input: $v) }",
        '{"V":"a"}',
        (
            'Variable "$v" has invalid value: Expected a value of non-null'
            ' type "String!" to be provided.'
        ),
    )


def test_duplicate_definitions_are_rejected_by_validation() raises:
    var h = Harness()
    h.assert_rejected_by_validation(
        "query ($v: Int, $v: Int = 5) { int(input: $v) }",
        "UniqueVariableNames",
    )


def test_does_not_expose_prototype_variable_names_when_omitted() raises:
    var h = Harness()
    h.assert_coerced(
        (
            "query ($toString: String) { fieldWithNullableStringInput(input:"
            " $toString) }"
        ),
        "{}",
        "{}",
    )


def test_still_returns_provided_variables_with_colliding_names() raises:
    var h = Harness()
    h.assert_coerced(
        (
            "query ($toString: String) { fieldWithNullableStringInput(input:"
            " $toString) }"
        ),
        '{"toString":"value"}',
        '{"toString":"value"}',
    )


def test_prototype_named_required_variable_absent_is_rejected() raises:
    var h = Harness()
    h.assert_rejected(
        (
            "query ($constructor: String!) {"
            " fieldWithNonNullableStringInput(input: $constructor) }"
        ),
        "{}",
        (
            'Variable "$constructor" has invalid value: Expected a value of'
            ' non-null type "String!" to be provided.'
        ),
    )


# --- first error ------------------------------------------------------

comptime TWO_REQUIRED = (
    "query ($a: String!, $b: String!) { a:"
    " fieldWithNonNullableStringInput(input: $a) b:"
    " fieldWithNonNullableStringInput(input: $b) }"
)


def test_first_error_in_definition_order() raises:
    var h = Harness()
    h.assert_rejected(
        TWO_REQUIRED,
        '{"b":null}',
        (
            'Variable "$a" has invalid value: Expected a value of non-null'
            ' type "String!" to be provided.'
        ),
    )


def test_second_variable_invalid() raises:
    var h = Harness()
    h.assert_rejected(
        TWO_REQUIRED,
        '{"a":"x","b":null}',
        (
            'Variable "$b" has invalid value: Expected value of non-null type'
            ' "String!" not to be null.'
        ),
    )


def test_definition_order_not_json_key_order() raises:
    var h = Harness()
    h.assert_rejected(
        TWO_REQUIRED,
        '{"b":null,"a":null}',
        (
            'Variable "$a" has invalid value: Expected value of non-null type'
            ' "String!" not to be null.'
        ),
    )


def test_return_first_error_in_value_order() raises:
    var h = Harness()
    h.assert_rejected(
        "query ($input: [String!]) { listNN(input: $input) }",
        '{"input":[0,1,2]}',
        (
            'Variable "$input" has invalid value at [0]: String cannot'
            " represent a non string value: 0"
        ),
    )


# --- definition syntax ------------------------------------------------

comptime DESCRIBED = (
    'query ("doc" $v: String!) { fieldWithNonNullableStringInput(input: $v) }'
)


def test_described_variable_absent_is_rejected() raises:
    var h = Harness()
    h.assert_rejected(
        DESCRIBED,
        "{}",
        (
            'Variable "$v" has invalid value: Expected a value of non-null'
            ' type "String!" to be provided.'
        ),
    )


def test_described_variable_value_is_kept() raises:
    var h = Harness()
    h.assert_coerced(DESCRIBED, '{"v":"a"}', '{"v":"a"}')


def test_does_not_allow_invalid_types_to_be_used_as_values() raises:
    var h = Harness()
    h.assert_rejected_by_validation(
        "query ($input: Query!) { fieldWithObjectInput(input: $input) }",
        "VariablesAreInputTypes",
    )


def test_does_not_allow_unknown_types_to_be_used_as_values() raises:
    var h = Harness()
    h.assert_rejected_by_validation(
        "query ($input: UnknownType!) { fieldWithObjectInput(input: $input) }",
        "KnownTypeNames",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

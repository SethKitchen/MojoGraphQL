# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Input coercion of the built-in scalars (spec §3.5) and custom scalars,
for JSON variables.

Port of Hive Router `1a29df9`
`bin/router/src/executor/variables/tests/scalars.rs`. Upstream marks no
test `#[ignore]`.

**Differences from upstream.** The `gql_json` parser accepts `1e309`,
`-1e309` and the 309-digit integer `2 ** 1024`, as `JSON.parse` does, where
`sonic_rs` refuses them. So `float_rejects_overflow_at_json_parse` and
`float_rejects_309_digit_integer_at_json_parse` assert that coercion
refuses them, as graphql-js `GraphQLFloat` does:
`Float cannot represent non numeric value: Infinity`.
"""

from _variables_harness import Harness, assert_invalid_json
from std.testing import TestSuite


def operation(variable_type: String, field: String) -> String:
    """`query ($v: <variable_type>) { <field>(input: $v) }`."""
    return String("query ($v: ", variable_type, ") { ", field, "(input: $v) }")


def variables(value: String) -> String:
    """`{"v":<value>}`."""
    return String('{"v":', value, "}")


def accepts(mut h: Harness, operation: String, value: String) raises:
    """Assert that `$v` given the JSON `value` is accepted and kept."""
    h.assert_coerced(operation, variables(value), variables(value))


def rejects(
    mut h: Harness, operation: String, value: String, reason: String
) raises:
    """Assert that `$v` given the JSON `value` is rejected with `reason`."""
    h.assert_rejected(
        operation,
        variables(value),
        String('Variable "$v" has invalid value: ', reason),
    )


# --- int --------------------------------------------------------------


def int_op() -> String:
    return operation("Int", "int")


def test_int_accepts_small_integers() raises:
    var h = Harness()
    for value in ["1", "0", "-1"]:
        accepts(h, int_op(), value)


def test_int_accepts_32_bit_bounds() raises:
    var h = Harness()
    for value in ["2147483647", "-2147483648"]:
        accepts(h, int_op(), value)


def test_int_rejects_2_pow_31() raises:
    var h = Harness()
    rejects(
        h,
        int_op(),
        "2147483648",
        "Int cannot represent non 32-bit signed integer value: 2147483648",
    )


def test_int_rejects_below_minus_2_pow_31() raises:
    var h = Harness()
    rejects(
        h,
        int_op(),
        "-2147483649",
        "Int cannot represent non 32-bit signed integer value: -2147483649",
    )


def test_int_rejects_9876504321() raises:
    var h = Harness()
    rejects(
        h,
        int_op(),
        "9876504321",
        "Int cannot represent non 32-bit signed integer value: 9876504321",
    )


def test_int_rejects_minus_9876504321() raises:
    var h = Harness()
    rejects(
        h,
        int_op(),
        "-9876504321",
        "Int cannot represent non 32-bit signed integer value: -9876504321",
    )


def test_int_rejects_i64_max() raises:
    var h = Harness()
    rejects(
        h,
        int_op(),
        "9223372036854775807",
        (
            "Int cannot represent non 32-bit signed integer value:"
            " 9223372036854775807"
        ),
    )


def test_int_rejects_integer_above_i64() raises:
    var h = Harness()
    rejects(
        h,
        int_op(),
        "9223372036854775808",
        (
            "Int cannot represent non 32-bit signed integer value:"
            " 9223372036854775808"
        ),
    )


def test_int_rejects_integer_above_u64() raises:
    var h = Harness()
    rejects(
        h,
        int_op(),
        "18446744073709551616",
        "Int cannot represent non-integer value: 18446744073709552000.0",
    )


def test_int_rejects_json_floats() raises:
    var h = Harness()
    var values = [
        "1.0",
        "1e3",
        "1.5e1",
        "-0",
        "2147483648.0",
        "1.0000000000000001",
    ]
    var printed = ["1.0", "1000.0", "15.0", "0.0", "2147483648.0", "1.0"]
    for index in range(len(values)):
        rejects(
            h,
            int_op(),
            String(values[index]),
            String("Int cannot represent non-integer value: ", printed[index]),
        )


def test_int_rejects_0_1() raises:
    var h = Harness()
    rejects(h, int_op(), "0.1", "Int cannot represent non-integer value: 0.1")


def test_int_rejects_1_5() raises:
    var h = Harness()
    rejects(h, int_op(), "1.5", "Int cannot represent non-integer value: 1.5")


def test_int_rejects_numeric_string() raises:
    var h = Harness()
    rejects(
        h, int_op(), '"123"', 'Int cannot represent non-integer value: "123"'
    )


def test_int_rejects_empty_string() raises:
    var h = Harness()
    rejects(h, int_op(), '""', 'Int cannot represent non-integer value: ""')


def test_int_rejects_false() raises:
    var h = Harness()
    rejects(
        h, int_op(), "false", "Int cannot represent non-integer value: false"
    )


def test_int_rejects_true() raises:
    var h = Harness()
    rejects(h, int_op(), "true", "Int cannot represent non-integer value: true")


def test_int_rejects_list() raises:
    var h = Harness()
    rejects(h, int_op(), "[1]", "Int cannot represent non-integer value: [1]")


def test_int_rejects_object() raises:
    var h = Harness()
    rejects(
        h,
        int_op(),
        '{"value":1}',
        "Int cannot represent non-integer value: { value: 1 }",
    )


def test_int_error_truncates_deep_object() raises:
    var h = Harness()
    rejects(
        h,
        int_op(),
        '{"a":{"b":{"c":1}}}',
        "Int cannot represent non-integer value: { a: { b: [Object] } }",
    )


# --- float ------------------------------------------------------------


def float_op() -> String:
    return operation("Float", "float")


def test_float_accepts_integers() raises:
    var h = Harness()
    for value in ["1", "0", "-1"]:
        accepts(h, float_op(), value)


def test_float_accepts_fractional_values() raises:
    var h = Harness()
    for value in ["0.1", "3.141592653589793"]:
        h.assert_forwarded(float_op(), variables(value), variables(value))


def test_float_accepts_2_pow_53() raises:
    var h = Harness()
    h.assert_forwarded(
        float_op(), variables("9007199254740992"), variables("9007199254740992")
    )


def test_float_accepts_2_pow_53_plus_1() raises:
    var h = Harness()
    h.assert_forwarded(
        float_op(), variables("9007199254740993"), variables("9007199254740993")
    )


def test_float_accepts_integers_above_i64() raises:
    var h = Harness()
    for value in ["9223372036854775808", "18446744073709551615"]:
        accepts(h, float_op(), value)


def test_float_accepts_integer_above_u64() raises:
    var h = Harness()
    accepts(h, float_op(), "18446744073709551616")


def test_float_accepts_extreme_finite_values() raises:
    var h = Harness()
    for value in [
        "1e308",
        "1.7976931348623157e308",
        "-1.7976931348623157e308",
        "5e-324",
    ]:
        accepts(h, float_op(), value)


def test_float_accepts_underflow_to_zero() raises:
    var h = Harness()
    h.assert_coerced(float_op(), variables("1e-400"), variables("0.0"))


def test_float_rejects_overflow_at_json_parse() raises:
    # `gql_json` accepts the text, as `JSON.parse` does; coercion refuses it.
    var h = Harness()
    rejects(
        h,
        float_op(),
        "1e309",
        "Float cannot represent non numeric value: Infinity",
    )
    rejects(
        h,
        float_op(),
        "-1e309",
        "Float cannot represent non numeric value: -Infinity",
    )


def test_float_rejects_309_digit_integer_at_json_parse() raises:
    # `gql_json` accepts the text, as `JSON.parse` does; coercion refuses it.
    var two_pow_1024 = String(
        "17976931348623159077293051907890247336179769789423065727343008115",
        "77326758055009631327084773224075360211201138798713933576587897688",
        "14416622492847430639474124377767893424865485276302219601246094119",
        "45308295208500576883815068234246288147391311054083723716335051068",
        "4586298239947245938479716304835356329624224137216",
    )
    var h = Harness()
    rejects(
        h,
        float_op(),
        two_pow_1024,
        "Float cannot represent non numeric value: Infinity",
    )


def test_float_rejects_nan_and_infinity_tokens() raises:
    for value in ["NaN", "Infinity", "-Infinity"]:
        assert_invalid_json(variables(value))


def test_float_rejects_empty_string() raises:
    var h = Harness()
    rejects(h, float_op(), '""', 'Float cannot represent non numeric value: ""')


def test_float_rejects_numeric_string() raises:
    var h = Harness()
    rejects(
        h,
        float_op(),
        '"123"',
        'Float cannot represent non numeric value: "123"',
    )


def test_float_rejects_decimal_string() raises:
    var h = Harness()
    rejects(
        h,
        float_op(),
        '"123.5"',
        'Float cannot represent non numeric value: "123.5"',
    )


def test_float_rejects_nan_string() raises:
    var h = Harness()
    rejects(
        h,
        float_op(),
        '"NaN"',
        'Float cannot represent non numeric value: "NaN"',
    )


def test_float_rejects_false() raises:
    var h = Harness()
    rejects(
        h,
        float_op(),
        "false",
        "Float cannot represent non numeric value: false",
    )


def test_float_rejects_true() raises:
    var h = Harness()
    rejects(
        h, float_op(), "true", "Float cannot represent non numeric value: true"
    )


def test_float_rejects_list() raises:
    var h = Harness()
    rejects(
        h,
        float_op(),
        "[0.1]",
        "Float cannot represent non numeric value: [0.1]",
    )


def test_float_rejects_object() raises:
    var h = Harness()
    rejects(
        h,
        float_op(),
        '{"value":0.1}',
        "Float cannot represent non numeric value: { value: 0.1 }",
    )


# --- string -----------------------------------------------------------


def string_op() -> String:
    return operation("String", "fieldWithNullableStringInput")


def test_string_accepts_empty_string() raises:
    var h = Harness()
    accepts(h, string_op(), '""')


def test_string_accepts_unicode_and_escapes() raises:
    var h = Harness()
    h.assert_coerced(string_op(), '{"v":"héllo 世界 😀"}', '{"v":"héllo 世界 😀"}')
    h.assert_coerced(string_op(), '{"v":"é😀"}', '{"v":"é😀"}')


def test_string_forwards_quotes_and_control_chars_escaped() raises:
    var h = Harness()
    h.assert_forwarded(
        string_op(),
        '{"v":"a\\"b\\\\c\\u0000\\n"}',
        '{"v":"a\\"b\\\\c\\u0000\\n"}',
    )


def test_string_rejects_lone_surrogate_at_json_parse() raises:
    assert_invalid_json('{"v":"\\uD800"}')


def test_string_rejects_integer() raises:
    var h = Harness()
    rejects(
        h, string_op(), "1", "String cannot represent a non string value: 1"
    )


def test_string_rejects_false() raises:
    var h = Harness()
    rejects(
        h,
        string_op(),
        "false",
        "String cannot represent a non string value: false",
    )


def test_string_rejects_list() raises:
    var h = Harness()
    rejects(
        h,
        string_op(),
        '["foo"]',
        'String cannot represent a non string value: ["foo"]',
    )


def test_string_rejects_object() raises:
    var h = Harness()
    rejects(
        h,
        string_op(),
        '{"value":"foo"}',
        'String cannot represent a non string value: { value: "foo" }',
    )


def test_reports_error_for_array_passed_into_string_input() raises:
    var h = Harness()
    h.assert_rejected(
        (
            "query ($value: String!) { fieldWithNonNullableStringInput(input:"
            " $value) }"
        ),
        '{"value":[1,2,3]}',
        (
            'Variable "$value" has invalid value: String cannot represent a'
            " non string value: [1, 2, 3]"
        ),
    )


def test_string_error_bounds_large_array() raises:
    var zeros = String("[0")
    for _ in range(999):
        zeros += ",0"
    zeros += "]"
    var h = Harness()
    rejects(
        h,
        string_op(),
        zeros,
        (
            "String cannot represent a non string value: [0, 0, 0, 0, 0, 0,"
            " 0, 0, 0, 0, ... 990 more items]"
        ),
    )


# --- boolean ----------------------------------------------------------


def boolean_op() -> String:
    return operation("Boolean", "boolean")


def test_boolean_accepts_true_and_false() raises:
    var h = Harness()
    for value in ["true", "false"]:
        accepts(h, boolean_op(), value)


def test_boolean_rejects_0() raises:
    var h = Harness()
    rejects(
        h, boolean_op(), "0", "Boolean cannot represent a non boolean value: 0"
    )


def test_boolean_rejects_1() raises:
    var h = Harness()
    rejects(
        h, boolean_op(), "1", "Boolean cannot represent a non boolean value: 1"
    )


def test_boolean_rejects_empty_string() raises:
    var h = Harness()
    rejects(
        h,
        boolean_op(),
        '""',
        'Boolean cannot represent a non boolean value: ""',
    )


def test_boolean_rejects_string_false() raises:
    var h = Harness()
    rejects(
        h,
        boolean_op(),
        '"false"',
        'Boolean cannot represent a non boolean value: "false"',
    )


def test_boolean_rejects_string_true() raises:
    var h = Harness()
    rejects(
        h,
        boolean_op(),
        '"true"',
        'Boolean cannot represent a non boolean value: "true"',
    )


def test_boolean_rejects_list() raises:
    var h = Harness()
    rejects(
        h,
        boolean_op(),
        "[false]",
        "Boolean cannot represent a non boolean value: [false]",
    )


def test_boolean_rejects_object() raises:
    var h = Harness()
    rejects(
        h,
        boolean_op(),
        '{"value":false}',
        "Boolean cannot represent a non boolean value: { value: false }",
    )


# --- id ---------------------------------------------------------------


def id_op() -> String:
    return operation("ID", "id")


def test_id_accepts_strings() raises:
    var h = Harness()
    for value in ['""', '"1"', '"foo"']:
        accepts(h, id_op(), value)


def test_id_accepts_small_integers() raises:
    var h = Harness()
    for value in ["1", "0", "-1"]:
        accepts(h, id_op(), value)


def test_id_accepts_max_safe_integers() raises:
    var h = Harness()
    for value in ["9007199254740991", "-9007199254740991"]:
        accepts(h, id_op(), value)


def test_id_forwards_big_integers_with_exact_digits() raises:
    var h = Harness()
    for value in ["90071992547409910", "12345678901234567890"]:
        h.assert_forwarded(id_op(), variables(value), variables(value))


def test_id_rejects_json_floats() raises:
    var h = Harness()
    rejects(h, id_op(), "4.0", "ID cannot represent value: 4.0")
    rejects(h, id_op(), "1e3", "ID cannot represent value: 1000.0")


def test_id_rejects_4_5() raises:
    var h = Harness()
    rejects(h, id_op(), "4.5", "ID cannot represent value: 4.5")


def test_id_rejects_0_1() raises:
    var h = Harness()
    rejects(h, id_op(), "0.1", "ID cannot represent value: 0.1")


def test_id_rejects_false() raises:
    var h = Harness()
    rejects(h, id_op(), "false", "ID cannot represent value: false")


def test_id_rejects_list() raises:
    var h = Harness()
    rejects(h, id_op(), '["1"]', 'ID cannot represent value: ["1"]')


def test_id_rejects_object() raises:
    var h = Harness()
    rejects(
        h, id_op(), '{"value":"1"}', 'ID cannot represent value: { value: "1" }'
    )


# --- custom scalars ---------------------------------------------------


def custom_op() -> String:
    return operation("JSONScalar", "fieldWithJSONScalarInput")


def test_allows_custom_scalars_with_non_embedded_variables() raises:
    var h = Harness()
    h.assert_coerced(
        (
            "query ($input: JSONScalar) { fieldWithJSONScalarInput(input:"
            " $input) }"
        ),
        '{"input":{"a":"foo","b":["bar"],"c":"baz"}}',
        '{"input":{"a":"foo","b":["bar"],"c":"baz"}}',
    )


def test_custom_scalar_accepts_object() raises:
    var h = Harness()
    accepts(h, custom_op(), '{"value":1}')


def test_custom_scalar_accepts_object_with_null_member() raises:
    var h = Harness()
    accepts(h, custom_op(), '{"value":null}')


def test_custom_scalar_accepts_any_json() raises:
    var h = Harness()
    for value in ["1", "1.5", '"x"', "true", '[1,"a",null]', "[]", "{}"]:
        accepts(h, custom_op(), value)


# --- null and omitted -------------------------------------------------

comptime NULLABLE_STRING = (
    "query ($value: String) { fieldWithNullableStringInput(input: $value) }"
)
comptime NON_NULL_STRING = (
    "query ($value: String!) { fieldWithNonNullableStringInput(input: $value) }"
)


def test_allows_nullable_inputs_to_be_omitted_in_a_variable() raises:
    var h = Harness()
    h.assert_coerced(NULLABLE_STRING, "{}", "{}")


def test_allows_nullable_inputs_to_be_set_to_null_in_a_variable() raises:
    var h = Harness()
    h.assert_coerced(NULLABLE_STRING, '{"value":null}', '{"value":null}')


def test_allows_nullable_inputs_to_be_set_to_a_value_in_a_variable() raises:
    var h = Harness()
    h.assert_coerced(NULLABLE_STRING, '{"value":"a"}', '{"value":"a"}')


def test_allows_non_nullable_inputs_to_be_set_to_a_value_in_a_variable() raises:
    var h = Harness()
    h.assert_coerced(NON_NULL_STRING, '{"value":"a"}', '{"value":"a"}')


def test_does_not_allow_non_nullable_inputs_to_be_omitted_in_a_variable() raises:
    var h = Harness()
    h.assert_rejected(
        NON_NULL_STRING,
        "{}",
        (
            'Variable "$value" has invalid value: Expected a value of non-null'
            ' type "String!" to be provided.'
        ),
    )


def test_does_not_allow_non_nullable_inputs_to_be_set_to_null_in_a_variable() raises:
    var h = Harness()
    h.assert_rejected(
        NON_NULL_STRING,
        '{"value":null}',
        (
            'Variable "$value" has invalid value: Expected value of non-null'
            ' type "String!" not to be null.'
        ),
    )


def check_scalar(scalar: String, field: String) raises:
    """For each scalar: `T!` refuses `null` and an omitted value; `T`
    accepts both."""
    var h = Harness()
    var non_null = operation(scalar + "!", field)
    rejects(
        h,
        non_null,
        "null",
        String(
            'Expected value of non-null type "', scalar, '!" not to be null.'
        ),
    )
    h.assert_rejected(
        non_null,
        "{}",
        String(
            (
                'Variable "$v" has invalid value: Expected a value of non-null'
                ' type "'
            ),
            scalar,
            '!" to be provided.',
        ),
    )
    var nullable = operation(scalar, field)
    accepts(h, nullable, "null")
    h.assert_coerced(nullable, "{}", "{}")


def test_int_null_and_omitted() raises:
    check_scalar("Int", "int")


def test_float_null_and_omitted() raises:
    check_scalar("Float", "float")


def test_boolean_null_and_omitted() raises:
    check_scalar("Boolean", "boolean")


def test_id_null_and_omitted() raises:
    check_scalar("ID", "id")


def test_custom_scalar_null_and_omitted() raises:
    check_scalar("JSONScalar", "fieldWithJSONScalarInput")


# --- defaults ---------------------------------------------------------


def test_allows_non_nullable_variable_to_be_omitted_given_a_default() raises:
    var h = Harness()
    h.assert_coerced(
        (
            'query ($value: String! = "default") {'
            " fieldWithNullableStringInput(input: $value) }"
        ),
        "{}",
        '{"value":"default"}',
    )


def test_allows_non_nullable_inputs_to_be_omitted_given_a_default() raises:
    var h = Harness()
    h.assert_coerced(
        (
            'query ($value: String = "default") {'
            " fieldWithNonNullableStringInput(input: $value) }"
        ),
        "{}",
        '{"value":"default"}',
    )


def test_id_integer_default_used_when_omitted() raises:
    var h = Harness()
    h.assert_coerced("query ($v: ID = 1) { id(input: $v) }", "{}", '{"v":1}')


def test_float_integer_default_used_when_omitted() raises:
    var h = Harness()
    h.assert_coerced(
        "query ($v: Float = 1) { float(input: $v) }", "{}", '{"v":1}'
    )


def test_int_out_of_range_default_is_rejected_by_validation() raises:
    var h = Harness()
    h.assert_rejected_by_validation(
        "query ($v: Int = 2147483648) { int(input: $v) }",
        "ValuesOfCorrectType",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

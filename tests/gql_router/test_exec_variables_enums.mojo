# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Input coercion of enums (spec §3.9) for JSON variables. An enum value
is sent as a JSON string that holds the value's name.

Port of Hive Router `1a29df9`
`bin/router/src/executor/variables/tests/enums.rs`. Upstream marks no test
`#[ignore]`.
"""

from _variables_harness import Harness
from std.testing import TestSuite


def operation(variable_type: String, field: String) -> String:
    """`query ($value: <variable_type>) { <field>(input: $value) }`."""
    return String(
        "query ($value: ", variable_type, ") { ", field, "(input: $value) }"
    )


def variables(value: String) -> String:
    """`{"value":<value>}`."""
    return String('{"value":', value, "}")


def accepts(mut h: Harness, operation: String, value: String) raises:
    """Assert that `$value` given the JSON `value` is accepted and kept."""
    h.assert_coerced(operation, variables(value), variables(value))


def rejects_at(
    mut h: Harness,
    operation: String,
    value: String,
    path: String,
    reason: String,
) raises:
    """Assert a rejection at a path inside the value."""
    h.assert_rejected(
        operation,
        variables(value),
        String('Variable "$value" has invalid value', path, ": ", reason),
    )


def rejects(
    mut h: Harness, operation: String, value: String, reason: String
) raises:
    """Assert a rejection of the value itself."""
    rejects_at(h, operation, value, "", reason)


def color() -> String:
    return operation("Color", "color")


# --- valid names ------------------------------------------------------


def test_returns_no_error_for_a_known_enum_name_foo() raises:
    var h = Harness()
    accepts(h, operation("FooBarEnum", "fooBar"), '"FOO"')


def test_returns_no_error_for_a_known_enum_name_bar() raises:
    var h = Harness()
    accepts(h, operation("FooBarEnum", "fooBar"), '"BAR"')


def test_accepts_json_string_as_enum_variable() raises:
    var h = Harness()
    h.assert_coerced(
        "query ($color: Color!) { colorEnum(fromEnum: $color) }",
        '{"color":"BLUE"}',
        '{"color":"BLUE"}',
    )


def test_enum_value_may_have_an_internal_value_of_0() raises:
    var h = Harness()
    accepts(h, color(), '"RED"')


def test_allows_custom_enum_values_as_inputs() raises:
    var h = Harness()
    for name in [
        "NULL",
        "UNDEFINED",
        "NAN",
        "FALSE",
        "CUSTOM",
        "DEFAULT_VALUE",
    ]:
        accepts(
            h,
            operation("TestEnum", "fieldWithEnumInput"),
            String('"', name, '"'),
        )


def test_allows_non_nullable_inputs_to_have_null_as_enum_custom_value() raises:
    var h = Harness()
    accepts(
        h, operation("TestEnum!", "fieldWithNonNullableEnumInput"), '"NULL"'
    )


def test_deprecated_enum_value_is_accepted() raises:
    var h = Harness()
    accepts(h, color(), '"OLD_BLUE"')


def test_enum_inputs_may_be_nullable() raises:
    var h = Harness()
    h.assert_coerced(color(), "{}", "{}")


def test_nullable_enum_explicit_null_is_forwarded() raises:
    var h = Harness()
    accepts(h, color(), "null")


# --- unknown names ----------------------------------------------------


def test_returns_an_error_for_unknown_enum_value() raises:
    var h = Harness()
    rejects(
        h,
        operation("FooBarEnum", "fooBar"),
        '"UNKNOWN"',
        'Value "UNKNOWN" does not exist in "FooBarEnum" enum.',
    )


def test_returns_an_error_for_misspelled_enum_value() raises:
    var h = Harness()
    rejects(
        h,
        operation("FooBarEnum", "fooBar"),
        '"foo"',
        'Value "foo" does not exist in "FooBarEnum" enum.',
    )


def test_does_not_accept_values_with_incorrect_casing() raises:
    var h = Harness()
    rejects(
        h, color(), '"green"', 'Value "green" does not exist in "Color" enum.'
    )


def test_does_not_accept_values_not_in_the_enum() raises:
    var h = Harness()
    rejects(
        h,
        color(),
        '"GREENISH"',
        'Value "GREENISH" does not exist in "Color" enum.',
    )


def test_value_of_another_enum_is_rejected() raises:
    var h = Harness()
    rejects(h, color(), '"FOO"', 'Value "FOO" does not exist in "Color" enum.')


def test_string_null_is_not_enum_value_null() raises:
    var h = Harness()
    rejects(
        h,
        operation("TestEnum", "fieldWithEnumInput"),
        '"null"',
        'Value "null" does not exist in "TestEnum" enum.',
    )


def test_string_false_is_not_enum_value_false() raises:
    var h = Harness()
    rejects(
        h,
        operation("TestEnum", "fieldWithEnumInput"),
        '"false"',
        'Value "false" does not exist in "TestEnum" enum.',
    )


def test_enum_name_whitespace_is_not_trimmed() raises:
    var h = Harness()
    rejects(
        h, color(), '"RED "', 'Value "RED " does not exist in "Color" enum.'
    )


def test_enum_name_homoglyph_is_rejected() raises:
    # The middle letter is U+0415 CYRILLIC CAPITAL LETTER IE.
    var h = Harness()
    rejects(
        h,
        color(),
        '"RЕD"',
        'Value "RЕD" does not exist in "Color" enum.',
    )


def test_empty_string_is_rejected() raises:
    var h = Harness()
    rejects(h, color(), '""', 'Value "" does not exist in "Color" enum.')


def test_unknown_name_is_echoed_raw() raises:
    var h = Harness()
    rejects(
        h, color(), '"RED\\""', 'Value "RED"" does not exist in "Color" enum.'
    )


def test_numeric_string_is_rejected() raises:
    var h = Harness()
    rejects(h, color(), '"2"', 'Value "2" does not exist in "Color" enum.')


# --- non-string values ------------------------------------------------


def test_returns_an_error_for_incorrect_value_type_number() raises:
    var h = Harness()
    rejects(
        h,
        operation("FooBarEnum", "fooBar"),
        "123",
        'Enum "FooBarEnum" cannot represent non-string value: 123.',
    )


def test_returns_an_error_for_incorrect_value_type_object() raises:
    var h = Harness()
    rejects(
        h,
        operation("FooBarEnum", "fooBar"),
        '{"field":"value"}',
        (
            'Enum "FooBarEnum" cannot represent non-string value: { field:'
            ' "value" }.'
        ),
    )


def test_does_not_accept_internal_value_as_enum_variable() raises:
    var h = Harness()
    h.assert_rejected(
        "query ($color: Color!) { colorEnum(fromEnum: $color) }",
        '{"color":2}',
        (
            'Variable "$color" has invalid value: Enum "Color" cannot'
            " represent non-string value: 2."
        ),
    )


def test_boolean_is_rejected() raises:
    var h = Harness()
    rejects(
        h,
        color(),
        "true",
        'Enum "Color" cannot represent non-string value: true.',
    )


def test_boolean_false_is_not_enum_value_false() raises:
    var h = Harness()
    rejects(
        h,
        operation("TestEnum", "fieldWithEnumInput"),
        "false",
        'Enum "TestEnum" cannot represent non-string value: false.',
    )


def test_json_null_for_non_null_enum() raises:
    var h = Harness()
    rejects(
        h,
        operation("TestEnum!", "fieldWithNonNullableEnumInput"),
        "null",
        'Expected value of non-null type "TestEnum!" not to be null.',
    )


def test_array_for_non_list_enum() raises:
    var h = Harness()
    rejects(
        h,
        color(),
        '["RED"]',
        'Enum "Color" cannot represent non-string value: ["RED"].',
    )


# --- lists ------------------------------------------------------------


def colors() -> String:
    return operation("[Color]", "colors")


def test_list_of_enum_names() raises:
    var h = Harness()
    accepts(h, colors(), '["RED","BLUE"]')


def test_single_enum_name_for_list() raises:
    var h = Harness()
    accepts(h, colors(), '"RED"')


def test_list_item_unknown_name() raises:
    var h = Harness()
    rejects_at(
        h,
        colors(),
        '["RED","PURPLE"]',
        " at [1]",
        'Value "PURPLE" does not exist in "Color" enum.',
    )


def test_single_unknown_name_for_list_has_no_index() raises:
    var h = Harness()
    rejects(
        h,
        colors(),
        '"PURPLE"',
        'Value "PURPLE" does not exist in "Color" enum.',
    )


def test_list_item_non_string() raises:
    var h = Harness()
    rejects_at(
        h,
        colors(),
        '["RED",1]',
        " at [1]",
        'Enum "Color" cannot represent non-string value: 1.',
    )


def test_nested_array_item_for_list_of_enum() raises:
    var h = Harness()
    rejects_at(
        h,
        colors(),
        '[["RED"]]',
        " at [0]",
        'Enum "Color" cannot represent non-string value: ["RED"].',
    )


def test_null_item_in_nullable_enum_list() raises:
    var h = Harness()
    accepts(h, colors(), '["RED",null]')


def test_null_item_in_non_null_enum_list() raises:
    var h = Harness()
    rejects_at(
        h,
        operation("[Color!]", "colorsNN"),
        '["RED",null]',
        " at [1]",
        'Expected value of non-null type "Color!" not to be null.',
    )


def test_nested_enum_list_wraps_items() raises:
    var h = Harness()
    accepts(h, operation("[[Color]]", "nestedColors"), '["RED","BLUE"]')


def test_nested_enum_list_inner_wrong_case() raises:
    var h = Harness()
    rejects_at(
        h,
        operation("[[Color]]", "nestedColors"),
        '[["RED"],["red"]]',
        " at [1][0]",
        'Value "red" does not exist in "Color" enum.',
    )


def test_enum_list_many_bad_items_reports_first() raises:
    var h = Harness()
    rejects_at(
        h,
        colors(),
        '["PURPLE","ORANGE"]',
        " at [0]",
        'Value "PURPLE" does not exist in "Color" enum.',
    )


# --- in input objects -------------------------------------------------


def color_input() -> String:
    return operation("ColorInput", "colorInput")


def test_enum_fields_in_input_object_are_accepted() raises:
    var h = Harness()
    accepts(h, color_input(), '{"color":"RED","colors":["GREEN"]}')


def test_enum_field_unknown_name() raises:
    var h = Harness()
    rejects_at(
        h,
        color_input(),
        '{"color":"PURPLE"}',
        " at .color",
        'Value "PURPLE" does not exist in "Color" enum.',
    )


def test_enum_field_non_string() raises:
    var h = Harness()
    rejects_at(
        h,
        color_input(),
        '{"color":1}',
        " at .color",
        'Enum "Color" cannot represent non-string value: 1.',
    )


def test_enum_list_field_bad_item() raises:
    var h = Harness()
    rejects_at(
        h,
        color_input(),
        '{"colors":["RED","red"]}',
        " at .colors[1]",
        'Value "red" does not exist in "Color" enum.',
    )


# --- defaults ---------------------------------------------------------


def test_enum_literal_default_is_inserted() raises:
    var h = Harness()
    h.assert_coerced(
        "query ($value: Color = RED) { color(input: $value) }",
        "{}",
        '{"value":"RED"}',
    )


def test_enum_default_named_null_is_inserted_as_string() raises:
    var h = Harness()
    h.assert_coerced(
        (
            "query ($value: TestEnum! = NULL) {"
            " fieldWithNonNullableEnumInput(input: $value) }"
        ),
        "{}",
        '{"value":"NULL"}',
    )


def test_null_keyword_default_is_not_enum_null() raises:
    var h = Harness()
    h.assert_coerced(
        "query ($value: TestEnum = null) { fieldWithEnumInput(input: $value) }",
        "{}",
        '{"value":null}',
    )


def test_single_enum_default_for_list() raises:
    var h = Harness()
    h.assert_coerced(
        "query ($value: [Color] = RED) { colors(input: $value) }",
        "{}",
        '{"value":"RED"}',
    )


def test_string_literal_default_is_rejected_by_validation() raises:
    var h = Harness()
    h.assert_rejected_by_validation(
        'query ($value: Color = "RED") { color(input: $value) }',
        "ValuesOfCorrectType",
    )


def test_boolean_literal_default_is_rejected_by_validation() raises:
    var h = Harness()
    h.assert_rejected_by_validation(
        "query ($value: Color = true) { color(input: $value) }",
        "ValuesOfCorrectType",
    )


def test_int_literal_default_is_rejected_by_validation() raises:
    var h = Harness()
    h.assert_rejected_by_validation(
        "query ($value: Color = 3) { color(input: $value) }",
        "ValuesOfCorrectType",
    )


def test_unknown_enum_literal_default_is_rejected_by_validation() raises:
    var h = Harness()
    h.assert_rejected_by_validation(
        "query ($value: Color = PURPLE) { color(input: $value) }",
        "ValuesOfCorrectType",
    )


def test_unknown_enum_item_in_non_null_list_default_is_rejected_by_validation() raises:
    var h = Harness()
    h.assert_rejected_by_validation(
        "query ($value: [Color]! = [PURPLE]) { colors(input: $value) }",
        "ValuesOfCorrectType",
    )


def test_list_literal_default_for_enum_is_rejected_by_validation() raises:
    var h = Harness()
    h.assert_rejected_by_validation(
        "query ($value: Color = [RED]) { color(input: $value) }",
        "ValuesOfCorrectType",
    )


# --- operation types --------------------------------------------------

comptime MUTATION = "mutation ($color: Color!) { favoriteEnum(color: $color) }"
comptime SUBSCRIPTION = (
    "subscription ($color: Color!) { subscribeToEnum(color: $color) }"
)


def test_accepts_enum_literals_as_input_arguments_to_mutations() raises:
    var h = Harness()
    h.assert_coerced(MUTATION, '{"color":"GREEN"}', '{"color":"GREEN"}')


def test_accepts_enum_literals_as_input_arguments_to_subscriptions() raises:
    var h = Harness()
    h.assert_coerced(SUBSCRIPTION, '{"color":"GREEN"}', '{"color":"GREEN"}')


def test_rejects_invalid_enum_variable_on_mutation() raises:
    var h = Harness()
    h.assert_rejected(
        MUTATION,
        '{"color":"PURPLE"}',
        (
            'Variable "$color" has invalid value: Value "PURPLE" does not'
            ' exist in "Color" enum.'
        ),
    )


def test_rejects_invalid_enum_variable_on_subscription() raises:
    var h = Harness()
    h.assert_rejected(
        SUBSCRIPTION,
        '{"color":"PURPLE"}',
        (
            'Variable "$color" has invalid value: Value "PURPLE" does not'
            ' exist in "Color" enum.'
        ),
    )


# --- variable position ------------------------------------------------


def test_does_not_accept_string_variables_as_enum_input() raises:
    var h = Harness()
    h.assert_rejected_by_validation(
        "query ($color: String!) { colorEnum(fromEnum: $color) }",
        "VariablesInAllowedPosition",
    )


def test_does_not_accept_internal_value_variable_as_enum_input() raises:
    var h = Harness()
    h.assert_rejected_by_validation(
        "query ($color: Int!) { colorEnum(fromEnum: $color) }",
        "VariablesInAllowedPosition",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

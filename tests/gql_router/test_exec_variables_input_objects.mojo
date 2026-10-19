# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Input coercion of input objects (spec §3.10) for JSON variables.

Port of Hive Router `1a29df9`
`bin/router/src/executor/variables/tests/input_objects.rs`. Upstream marks
no test `#[ignore]`.
"""

from _variables_harness import Harness
from std.testing import TestSuite

comptime TEST_INPUT = (
    "query ($input: TestInputObject) { fieldWithObjectInput(input: $input) }"
)
comptime NESTED_INPUT = (
    "query ($input: TestNestedInputObject) {"
    " fieldWithNestedInputObject(input: $input) }"
)
comptime INT_INPUT = "query ($v: IntInputObject) { intInput(input: $v) }"
comptime EXAMPLE_INPUT = (
    "query ($var: ExampleInputObject) { exampleInput(input: $var) }"
)
comptime DEFAULTED_REQUIRED = (
    "query ($v: DefaultedRequired) { defaultedRequired(input: $v) }"
)
comptime WRAPPERS = "query ($v: Wrappers) { wrappers(input: $v) }"
comptime NN_LIST_FIELD = "query ($v: NNListField) { nnListField(input: $v) }"
comptime LENGTH_OBJECTS = (
    "query ($v: [LengthObject]) { lengthObjects(input: $v) }"
)
comptime FILTER = "query ($f: Filter) { filter(input: $f) }"


def rejects(
    mut h: Harness,
    operation: String,
    variables: String,
    name: String,
    path: String,
    reason: String,
) raises:
    """Assert a rejection of `$name` at a path."""
    h.assert_rejected(
        operation,
        variables,
        String('Variable "$', name, '" has invalid value', path, ": ", reason),
    )


def accepts(mut h: Harness, operation: String, variables: String) raises:
    """Assert that the variables are accepted and kept."""
    h.assert_coerced(operation, variables, variables)


# --- non-object values ------------------------------------------------


def test_errors_on_incorrect_type() raises:
    var h = Harness()
    rejects(
        h,
        TEST_INPUT,
        '{"input":"foo bar"}',
        "input",
        "",
        (
            'Expected value of type "TestInputObject" to be an object, found:'
            ' "foo bar".'
        ),
    )


def test_input_object_rejects_number() raises:
    var h = Harness()
    rejects(
        h,
        INT_INPUT,
        '{"v":123}',
        "v",
        "",
        'Expected value of type "IntInputObject" to be an object, found: 123.',
    )


def test_input_object_rejects_array() raises:
    var h = Harness()
    rejects(
        h,
        INT_INPUT,
        '{"v":[{"foo":123},{"bar":456}]}',
        "v",
        "",
        (
            'Expected value of type "IntInputObject" to be an object, found:'
            " [{ foo: 123 }, { bar: 456 }]."
        ),
    )


def test_input_object_rejects_boolean() raises:
    var h = Harness()
    rejects(
        h,
        INT_INPUT,
        '{"v":true}',
        "v",
        "",
        'Expected value of type "IntInputObject" to be an object, found: true.',
    )


def test_input_object_rejects_empty_list() raises:
    var h = Harness()
    rejects(
        h,
        INT_INPUT,
        '{"v":[]}',
        "v",
        "",
        'Expected value of type "IntInputObject" to be an object, found: [].',
    )


def test_nested_input_object_rejects_array() raises:
    var h = Harness()
    rejects(
        h,
        INT_INPUT,
        '{"v":{"foo":123,"nested":[{"foo":123},{"bar":456}]}}',
        "v",
        " at .nested",
        (
            'Expected value of type "IntInputObject" to be an object, found:'
            " [{ foo: 123 }, { bar: 456 }]."
        ),
    )


def test_nested_deep_object_rejects_list() raises:
    var h = Harness()
    rejects(
        h,
        INT_INPUT,
        '{"v":{"foo":1,"deepObject":[1,2,3]}}',
        "v",
        " at .deepObject",
        (
            'Expected value of type "DeepObject" to be an object, found: [1,'
            " 2, 3]."
        ),
    )


# --- required fields and defaults -------------------------------------


def test_errors_on_omission_of_nested_non_null() raises:
    var h = Harness()
    rejects(
        h,
        TEST_INPUT,
        '{"input":{"a":"foo","b":"bar"}}',
        "input",
        "",
        (
            'Expected value of type "TestInputObject" to include required'
            ' field "c", found: { a: "foo", b: "bar" }.'
        ),
    )


def test_returns_error_for_a_missing_required_field() raises:
    var h = Harness()
    rejects(
        h,
        INT_INPUT,
        '{"v":{"bar":123}}',
        "v",
        "",
        (
            'Expected value of type "IntInputObject" to include required field'
            ' "foo", found: { bar: 123 }.'
        ),
    )


def test_empty_object_missing_required_field() raises:
    var h = Harness()
    rejects(
        h,
        TEST_INPUT,
        '{"input":{}}',
        "input",
        "",
        (
            'Expected value of type "TestInputObject" to include required'
            ' field "c", found: {}.'
        ),
    )


def test_missing_non_null_nested_object_field() raises:
    var h = Harness()
    rejects(
        h,
        NESTED_INPUT,
        '{"input":{"nb":"x"}}',
        "input",
        "",
        (
            'Expected value of type "TestNestedInputObject" to include'
            ' required field "na", found: { nb: "x" }.'
        ),
    )


def test_returns_no_error_for_a_valid_input() raises:
    var h = Harness()
    accepts(h, INT_INPUT, '{"v":{"foo":123}}')


def test_field_default_valid_input_value() raises:
    var h = Harness()
    accepts(
        h,
        "query ($v: DefaultSevenInput) { defaultSeven(input: $v) }",
        '{"v":{"foo":5}}',
    )


def test_field_default_omitted_not_injected() raises:
    var h = Harness()
    accepts(
        h,
        "query ($v: DefaultSevenInput) { defaultSeven(input: $v) }",
        '{"v":{}}',
    )


def test_null_field_default_omitted_not_injected() raises:
    var h = Harness()
    accepts(
        h,
        "query ($v: DefaultNullInput) { defaultNull(input: $v) }",
        '{"v":{}}',
    )


def test_explicit_null_beats_field_default() raises:
    var h = Harness()
    accepts(
        h,
        "query ($v: DefaultSevenInput) { defaultSeven(input: $v) }",
        '{"v":{"foo":null}}',
    )


def test_non_null_field_with_default_may_be_omitted() raises:
    var h = Harness()
    accepts(h, DEFAULTED_REQUIRED, '{"v":{}}')
    accepts(h, DEFAULTED_REQUIRED, '{"v":{"y":"s"}}')


def test_non_null_field_with_default_rejects_null() raises:
    var h = Harness()
    rejects(
        h,
        DEFAULTED_REQUIRED,
        '{"v":{"x":null}}',
        "v",
        " at .x",
        'Expected value of non-null type "Int!" not to be null.',
    )


def test_field_with_default_type_checked_when_present() raises:
    var h = Harness()
    rejects(
        h,
        DEFAULTED_REQUIRED,
        '{"v":{"x":"5"}}',
        "v",
        " at .x",
        'Int cannot represent non-integer value: "5"',
    )


# --- explicit null fields ---------------------------------------------


def test_errors_on_null_for_nested_non_null() raises:
    var h = Harness()
    rejects(
        h,
        TEST_INPUT,
        '{"input":{"a":"foo","b":"bar","c":null}}',
        "input",
        " at .c",
        'Expected value of non-null type "String!" not to be null.',
    )


def test_explicit_null_for_nullable_fields_kept() raises:
    var h = Harness()
    accepts(h, TEST_INPUT, '{"input":{"a":null,"b":null,"c":"baz","d":null}}')


def test_null_for_nullable_nested_object() raises:
    var h = Harness()
    accepts(h, INT_INPUT, '{"v":{"foo":1,"nested":null}}')


def test_null_for_non_null_nested_object() raises:
    var h = Harness()
    rejects(
        h,
        NESTED_INPUT,
        '{"input":{"na":null,"nb":"x"}}',
        "input",
        " at .na",
        'Expected value of non-null type "TestInputObject!" not to be null.',
    )


# --- unknown fields ---------------------------------------------------


def test_errors_on_addition_of_unknown_input_field() raises:
    var h = Harness()
    rejects(
        h,
        TEST_INPUT,
        '{"input":{"a":"foo","b":"bar","c":"baz","extra":"dog"}}',
        "input",
        "",
        (
            'Expected value of type "TestInputObject" not to include unknown'
            ' field "extra", found: { a: "foo", b: "bar", c: "baz", extra:'
            ' "dog" }.'
        ),
    )


def test_returns_error_for_an_unknown_field() raises:
    var h = Harness()
    rejects(
        h,
        INT_INPUT,
        '{"v":{"foo":123,"unknownField":123}}',
        "v",
        "",
        (
            'Expected value of type "IntInputObject" not to include unknown'
            ' field "unknownField", found: { foo: 123, unknownField: 123 }.'
        ),
    )


def test_returns_error_for_a_misspelled_field() raises:
    var h = Harness()
    rejects(
        h,
        INT_INPUT,
        '{"v":{"foo":123,"bart":123}}',
        "v",
        "",
        (
            'Expected value of type "IntInputObject" not to include unknown'
            ' field "bart", found: { foo: 123, bart: 123 }.'
        ),
    )


def test_unknown_field_with_null_value() raises:
    var h = Harness()
    rejects(
        h,
        INT_INPUT,
        '{"v":{"foo":123,"unknownField":null}}',
        "v",
        "",
        (
            'Expected value of type "IntInputObject" not to include unknown'
            ' field "unknownField", found: { foo: 123, unknownField: null }.'
        ),
    )


def test_field_names_are_case_sensitive() raises:
    var h = Harness()
    rejects(
        h,
        TEST_INPUT,
        '{"input":{"A":"foo","c":"baz"}}',
        "input",
        "",
        (
            'Expected value of type "TestInputObject" not to include unknown'
            ' field "A", found: { A: "foo", c: "baz" }.'
        ),
    )


def test_unknown_field_in_nested_object() raises:
    var h = Harness()
    rejects(
        h,
        NESTED_INPUT,
        '{"input":{"na":{"c":"x","extra":1},"nb":"y"}}',
        "input",
        " at .na",
        (
            'Expected value of type "TestInputObject" not to include unknown'
            ' field "extra", found: { c: "x", extra: 1 }.'
        ),
    )


def test_proto_key_is_unknown_field() raises:
    var h = Harness()
    rejects(
        h,
        TEST_INPUT,
        '{"input":{"c":"x","__proto__":{"a":1}}}',
        "input",
        "",
        (
            'Expected value of type "TestInputObject" not to include unknown'
            ' field "__proto__", found: { c: "x", __proto__: { a: 1 } }.'
        ),
    )


# --- nested fields ----------------------------------------------------


def test_errors_on_deep_nested_errors_and_with_many_errors() raises:
    var h = Harness()
    rejects(
        h,
        NESTED_INPUT,
        '{"input":{"na":{"a":"foo"}}}',
        "input",
        " at .na",
        (
            'Expected value of type "TestInputObject" to include required'
            ' field "c", found: { a: "foo" }.'
        ),
    )


def test_nested_field_scalar_type_checked() raises:
    var h = Harness()
    rejects(
        h,
        INT_INPUT,
        '{"v":{"foo":123,"nested":{"foo":"x"}}}',
        "v",
        " at .nested.foo",
        'Int cannot represent non-integer value: "x"',
    )


def test_returns_an_error_for_an_invalid_field() raises:
    var h = Harness()
    rejects(
        h,
        INT_INPUT,
        '{"v":{"foo":1.5}}',
        "v",
        " at .foo",
        "Int cannot represent non-integer value: 1.5",
    )


def test_executes_with_complex_scalar_input() raises:
    var h = Harness()
    for d in ['"ExternalValue"', '{"unknown":1}', "[1]"]:
        accepts(h, TEST_INPUT, String('{"input":{"c":"foo","d":', d, "}}"))


# --- recursive types --------------------------------------------------


def test_recursive_input_moderately_deep_valid() raises:
    var value = String('{"name":"x"}')
    for _ in range(10):
        value = String('{"and":[', value, "]}")
    var h = Harness()
    accepts(h, FILTER, String('{"f":', value, "}"))


def test_recursive_input_invalid_leaf_path() raises:
    var h = Harness()
    rejects(
        h,
        FILTER,
        '{"f":{"and":[{"and":[{"name":1}]}]}}',
        "f",
        " at .and[0].and[0].name",
        "String cannot represent a non string value: 1",
    )


def test_recursive_input_null_item() raises:
    var h = Harness()
    rejects(
        h,
        FILTER,
        '{"f":{"and":[{"and":[{"name":"a"},null]}]}}',
        "f",
        " at .and[0].and[1]",
        'Expected value of non-null type "Filter!" not to be null.',
    )


def test_recursive_self_nested_missing_required() raises:
    var h = Harness()
    rejects(
        h,
        INT_INPUT,
        '{"v":{"foo":1,"nested":{"foo":2,"nested":{"bar":3}}}}',
        "v",
        " at .nested.nested",
        (
            'Expected value of type "IntInputObject" to include required field'
            ' "foo", found: { bar: 3 }.'
        ),
    )


def test_found_value_truncated_at_depth_two() raises:
    var h = Harness()
    rejects(
        h,
        INT_INPUT,
        '{"v":{"nested":{"nested":{"foo":1}}}}',
        "v",
        "",
        (
            'Expected value of type "IntInputObject" to include required field'
            ' "foo", found: { nested: { nested: [Object] } }.'
        ),
    )


# --- field wrappers ---------------------------------------------------


def test_executes_with_complex_input() raises:
    var h = Harness()
    accepts(h, TEST_INPUT, '{"input":{"a":"foo","b":["bar"],"c":"baz"}}')


def test_properly_parses_single_value_to_list() raises:
    var h = Harness()
    accepts(h, TEST_INPUT, '{"input":{"a":"foo","b":"bar","c":"baz"}}')


def test_list_field_nullable_items() raises:
    var h = Harness()
    accepts(h, TEST_INPUT, '{"input":{"b":["bar",null],"c":"baz"}}')


def test_list_field_item_type_checked() raises:
    var h = Harness()
    rejects(
        h,
        TEST_INPUT,
        '{"input":{"b":["bar",1],"c":"baz"}}',
        "input",
        " at .b[1]",
        "String cannot represent a non string value: 1",
    )


def test_list_field_single_value_type_checked() raises:
    var h = Harness()
    rejects(
        h,
        TEST_INPUT,
        '{"input":{"b":1,"c":"baz"}}',
        "input",
        " at .b",
        "String cannot represent a non string value: 1",
    )


def test_non_null_item_list_field_single_value() raises:
    var h = Harness()
    accepts(h, WRAPPERS, '{"v":{"list":1}}')


def test_non_null_item_list_field_null_item() raises:
    var h = Harness()
    rejects(
        h,
        WRAPPERS,
        '{"v":{"list":[1,null]}}',
        "v",
        " at .list[1]",
        'Expected value of non-null type "Int!" not to be null.',
    )


def test_nullable_list_field_null_or_empty() raises:
    var h = Harness()
    accepts(h, WRAPPERS, '{"v":{"list":null}}')
    accepts(h, WRAPPERS, '{"v":{"list":[]}}')


def test_list_of_objects_field_required_field_in_item() raises:
    var h = Harness()
    rejects(
        h,
        WRAPPERS,
        '{"v":{"nested":[{"b":1},{"a":"x"}]}}',
        "v",
        " at .nested[1]",
        (
            'Expected value of type "ExampleInputObject" to include required'
            ' field "b", found: { a: "x" }.'
        ),
    )


def test_list_of_objects_field_item_field_type() raises:
    var h = Harness()
    rejects(
        h,
        WRAPPERS,
        '{"v":{"nested":[{"b":1},{"b":"2"}]}}',
        "v",
        " at .nested[1].b",
        'Int cannot represent non-integer value: "2"',
    )


def test_list_of_objects_field_null_item() raises:
    var h = Harness()
    rejects(
        h,
        WRAPPERS,
        '{"v":{"nested":[{"b":1},null]}}',
        "v",
        " at .nested[1]",
        'Expected value of non-null type "ExampleInputObject!" not to be null.',
    )


def test_list_of_objects_field_single_object() raises:
    var h = Harness()
    accepts(h, WRAPPERS, '{"v":{"nested":{"b":1}}}')


def test_nested_object_field_null_for_non_null() raises:
    var h = Harness()
    rejects(
        h,
        WRAPPERS,
        '{"v":{"inner":{"b":null}}}',
        "v",
        " at .inner.b",
        'Expected value of non-null type "Int!" not to be null.',
    )


def test_non_null_list_field_accepts_empty_null_item_single() raises:
    var h = Harness()
    for items in ["[]", "[null]", '"x"']:
        accepts(h, NN_LIST_FIELD, String('{"v":{"items":', items, "}}"))


def test_non_null_list_field_rejects_null() raises:
    var h = Harness()
    rejects(
        h,
        NN_LIST_FIELD,
        '{"v":{"items":null}}',
        "v",
        " at .items",
        'Expected value of non-null type "[String]!" not to be null.',
    )


def test_non_null_list_field_required() raises:
    var h = Harness()
    rejects(
        h,
        NN_LIST_FIELD,
        '{"v":{}}',
        "v",
        "",
        (
            'Expected value of type "NNListField" to include required field'
            ' "items", found: {}.'
        ),
    )


# --- in lists ---------------------------------------------------------


def test_list_of_input_objects_item_field_invalid() raises:
    var h = Harness()
    rejects(
        h,
        LENGTH_OBJECTS,
        '{"v":[{"length":1},{"length":"x"}]}',
        "v",
        " at [1].length",
        'Int cannot represent non-integer value: "x"',
    )


def test_list_of_input_objects_non_object_item() raises:
    var h = Harness()
    rejects(
        h,
        LENGTH_OBJECTS,
        '{"v":[{"length":1},"x"]}',
        "v",
        " at [1]",
        'Expected value of type "LengthObject" to be an object, found: "x".',
    )


def test_list_of_input_objects_unknown_field_in_item() raises:
    var h = Harness()
    rejects(
        h,
        LENGTH_OBJECTS,
        '{"v":[{"length":1},{"len":2}]}',
        "v",
        " at [1]",
        (
            'Expected value of type "LengthObject" not to include unknown'
            ' field "len", found: { len: 2 }.'
        ),
    )


def test_unknown_field_in_list_field_item() raises:
    var h = Harness()
    rejects(
        h,
        WRAPPERS,
        '{"v":{"nested":[{"b":1},{"b":2,"x":1}]}}',
        "v",
        " at .nested[1]",
        (
            'Expected value of type "ExampleInputObject" not to include'
            ' unknown field "x", found: { b: 2, x: 1 }.'
        ),
    )


def test_list_of_input_objects_single_object() raises:
    var h = Harness()
    accepts(h, LENGTH_OBJECTS, '{"v":{"length":1}}')


def test_list_of_input_objects_null_item() raises:
    var h = Harness()
    accepts(h, LENGTH_OBJECTS, '{"v":[{"length":1},null]}')


def test_many_invalid_items_one_request_error() raises:
    var items = String('{"length":"x"}')
    for _ in range(99):
        items += ',{"length":"x"}'
    var h = Harness()
    rejects(
        h,
        LENGTH_OBJECTS,
        String('{"v":[', items, "]}"),
        "v",
        " at [0].length",
        'Int cannot represent non-integer value: "x"',
    )


# --- error order ------------------------------------------------------


def test_returns_multiple_errors_for_multiple_invalid_fields() raises:
    var h = Harness()
    rejects(
        h,
        INT_INPUT,
        '{"v":{"foo":"abc","bar":"def"}}',
        "v",
        " at .foo",
        'Int cannot represent non-integer value: "abc"',
    )


def test_first_error_independent_of_key_order() raises:
    var h = Harness()
    rejects(
        h,
        INT_INPUT,
        '{"v":{"bar":"def","foo":"abc"}}',
        "v",
        " at .foo",
        'Int cannot represent non-integer value: "abc"',
    )


def test_defined_field_errors_before_unknown_keys() raises:
    var h = Harness()
    rejects(
        h,
        INT_INPUT,
        '{"v":{"extra":1,"foo":"abc"}}',
        "v",
        " at .foo",
        'Int cannot represent non-integer value: "abc"',
    )


def test_missing_required_reported_before_unknown_key() raises:
    var h = Harness()
    rejects(
        h,
        EXAMPLE_INPUT,
        '{"var":{"B":123}}',
        "var",
        "",
        (
            'Expected value of type "ExampleInputObject" to include required'
            ' field "b", found: { B: 123 }.'
        ),
    )


def test_key_order_does_not_matter() raises:
    var h = Harness()
    accepts(h, TEST_INPUT, '{"input":{"c":"baz","b":["bar"],"a":"foo"}}')


# --- spec examples ----------------------------------------------------


def test_spec_3_10_all_fields() raises:
    var h = Harness()
    accepts(h, EXAMPLE_INPUT, '{"var":{"a":"abc","b":123}}')


def test_spec_3_10_explicit_null_kept() raises:
    var h = Harness()
    accepts(h, EXAMPLE_INPUT, '{"var":{"a":null,"b":123}}')


def test_spec_3_10_absent_field_not_injected() raises:
    var h = Harness()
    accepts(h, EXAMPLE_INPUT, '{"var":{"b":123}}')


def test_spec_3_10_string_not_object() raises:
    var h = Harness()
    rejects(
        h,
        EXAMPLE_INPUT,
        '{"var":"abc123"}',
        "var",
        "",
        (
            'Expected value of type "ExampleInputObject" to be an object,'
            ' found: "abc123".'
        ),
    )


def test_spec_3_10_wrong_field_type() raises:
    var h = Harness()
    rejects(
        h,
        EXAMPLE_INPUT,
        '{"var":{"a":"abc","b":"123"}}',
        "var",
        " at .b",
        'Int cannot represent non-integer value: "123"',
    )


def test_spec_3_10_missing_required_field() raises:
    var h = Harness()
    rejects(
        h,
        EXAMPLE_INPUT,
        '{"var":{"a":"abc"}}',
        "var",
        "",
        (
            'Expected value of type "ExampleInputObject" to include required'
            ' field "b", found: { a: "abc" }.'
        ),
    )


def test_spec_3_10_null_for_non_null_field() raises:
    var h = Harness()
    rejects(
        h,
        EXAMPLE_INPUT,
        '{"var":{"a":"abc","b":null}}',
        "var",
        " at .b",
        'Expected value of non-null type "Int!" not to be null.',
    )


def test_spec_3_10_unexpected_field() raises:
    var h = Harness()
    rejects(
        h,
        EXAMPLE_INPUT,
        '{"var":{"b":123,"c":"xyz"}}',
        "var",
        "",
        (
            'Expected value of type "ExampleInputObject" not to include'
            ' unknown field "c", found: { b: 123, c: "xyz" }.'
        ),
    )


# --- variables in literals --------------------------------------------

comptime IN_LITERAL = (
    "query q($input: String) { fieldWithObjectInput(input: { a: $input, c:"
    ' "baz" }) }'
)
comptime NON_NULL_IN_LITERAL = (
    "query ($var: Int!) { exampleInput(input: {b: $var}) }"
)


def test_preserves_explicit_null_variables_within_input_object_literals() raises:
    var h = Harness()
    accepts(h, IN_LITERAL, '{"input":null}')


def test_absent_variable_within_input_object_literal() raises:
    var h = Harness()
    h.assert_coerced(IN_LITERAL, "{}", "{}")


def test_spec_3_10_non_null_variable_in_literal() raises:
    var h = Harness()
    accepts(h, NON_NULL_IN_LITERAL, '{"var":123}')


def test_spec_3_10_non_null_variable_absent() raises:
    var h = Harness()
    h.assert_rejected(
        NON_NULL_IN_LITERAL,
        "{}",
        (
            'Variable "$var" has invalid value: Expected a value of non-null'
            ' type "Int!" to be provided.'
        ),
    )


def test_spec_3_10_non_null_variable_null() raises:
    var h = Harness()
    rejects(
        h,
        NON_NULL_IN_LITERAL,
        '{"var":null}',
        "var",
        "",
        'Expected value of non-null type "Int!" not to be null.',
    )


def test_spec_3_10_defaulted_variable_null_forwarded() raises:
    var h = Harness()
    accepts(
        h,
        "query ($var: Int = 1) { exampleInput(input: {b: $var}) }",
        '{"var":null}',
    )


def test_allows_missing_variables_in_an_optional_field() raises:
    var h = Harness()
    h.assert_coerced(
        "query ($x: Int) { defaultedRequired(input: {x: $x}) }", "{}", "{}"
    )


# --- defaults ---------------------------------------------------------


def test_uses_default_value_when_not_provided() raises:
    var h = Harness()
    h.assert_coerced(
        (
            'query ($input: TestInputObject = {a: "foo", b: ["bar"], c: "baz"})'
            " { fieldWithObjectInput(input: $input) }"
        ),
        "{}",
        '{"input":{"a":"foo","b":["bar"],"c":"baz"}}',
    )


def test_reports_invalid_default_values_is_rejected_by_validation() raises:
    var h = Harness()
    h.assert_rejected_by_validation(
        (
            "query ($input: String = 123) { fieldWithNullableStringInput(input:"
            " $input) }"
        ),
        "ValuesOfCorrectType",
    )


def test_unknown_field_in_default_is_rejected_by_validation() raises:
    var h = Harness()
    h.assert_rejected_by_validation(
        (
            'query ($input: TestInputObject = { c: "ok", aa: "x" }) {'
            " fieldWithObjectInput(input: $input) }"
        ),
        "ValuesOfCorrectType",
    )


def test_list_default_for_input_object_is_rejected_by_validation() raises:
    var h = Harness()
    h.assert_rejected_by_validation(
        (
            "query ($input: TestInputObject = []) { fieldWithObjectInput(input:"
            " $input) }"
        ),
        "ValuesOfCorrectType",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

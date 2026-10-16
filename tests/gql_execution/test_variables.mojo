# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_execution.values` and `gql_execution.coerce`, ported
from graphql-js 16.14.2 `src/execution/__tests__/variables-test.ts`.

Every execution of the upstream file is ported, with the same query and
the same variable values. The schema is the SDL form of the upstream
schema, and each field returns `inspect(args.input)` when the argument is
set. The expected results are those of graphql-js 16.14.2 with that SDL
schema.

The SDL form differs from the upstream schema in these ways, which change
the results of six cases:

- `ComplexScalar` and `FaultyScalar` are scalars from SDL: `parseValue`
  is the identity and `parseLiteral` is `valueFromASTUntyped`, so they
  neither turn `SerializedValue` into `DeserializedValue` nor throw
  (`properly runs parseLiteral on complex scalar types`, `executes with
  complex scalar input`, and both `errors on faulty scalar type input`).
- The values of `TestEnum` are their names, not `null`, `NaN`, `false` and
  `"custom value"` (`allows custom enum values as inputs`, `allows
  non-nullable inputs to have null as enum custom value`).
"""

from std.testing import TestSuite, assert_equal
from _helpers import json_value, run_query
from gql_execution.execute import ExecutionArgs, ResolveInfo
from gql_execution.value import UNDEFINED, Values, inspect
from gql_execution.values import get_variable_values
from gql_language.parser import parse
from gql_schema.build import build_schema

comptime SDL = """
scalar ComplexScalar
scalar FaultyScalar
input TestInputObject {
  a: String
  b: [String]
  c: String!
  d: ComplexScalar
  e: FaultyScalar
}
input TestNestedInputObject {
  na: TestInputObject!
  nb: String!
}
enum TestEnum {
  NULL
  UNDEFINED
  NAN
  FALSE
  CUSTOM
  DEFAULT_VALUE
}
type TestType {
  fieldWithEnumInput(input: TestEnum): String
  fieldWithNonNullableEnumInput(input: TestEnum!): String
  fieldWithObjectInput(input: TestInputObject): String
  fieldWithNullableStringInput(input: String): String
  fieldWithNonNullableStringInput(input: String!): String
  fieldWithDefaultArgumentValue(input: String = "Hello World"): String
  fieldWithNonNullableStringInputAndDefaultArgumentValue(input: String! = "Hello World"): String
  fieldWithNestedInputObject(input: TestNestedInputObject = "Hello World"): String
  list(input: [String]): String
  nnList(input: [String]!): String
  listNN(input: [String!]): String
  nnListNN(input: [String!]!): String
}
schema { query: TestType }
"""


def show_input(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    var input = values.member(args, "input")
    if input == UNDEFINED:
        return UNDEFINED
    return values.add_string(inspect(values, input))


def check(query: String, variables: String, expected: String) raises:
    var schema = build_schema(SDL)
    var args = ExecutionArgs()
    args.resolvers.field_resolver(show_input)
    if variables != "":
        args.variable_values = json_value(args.values, variables)
    assert_equal(run_query(schema, query, args), expected)


def _limit(max_errors: Int) raises -> String:
    var schema = build_schema(SDL)
    var document = parse(
        """
      query ($input: [String!]) {
        listNN(input: $input)
      }
    """
    )
    var values = Values()
    var inputs = json_value(values, '{"input": [0, 1, 2]}')
    var result = get_variable_values(
        schema, document, document.definitions()[0], values, inputs, max_errors
    )
    var out = String("")
    for ref error in result.errors:
        out += error.to_json() + "\n"
    return out^


def _invalid(value: Int) -> String:
    return (
        '{"message":"Variable \\"$input\\" got invalid value '
        + String(value)
        + ' at \\"input['
        + String(value)
        + ']\\"; String cannot represent a non string value: '
        + String(value)
        + '","locations":[{"line":2,"column":14}]}\n'
    )


def test_return_all_errors_by_default() raises:
    assert_equal(_limit(50), _invalid(0) + _invalid(1) + _invalid(2))


def test_when_max_errors_is_equal_to_number_of_errors() raises:
    assert_equal(_limit(3), _invalid(0) + _invalid(1) + _invalid(2))


def test_when_max_errors_is_less_than_number_of_errors() raises:
    assert_equal(
        _limit(2),
        _invalid(0)
        + _invalid(1)
        + '{"message":"Too many errors processing variables, error limit'
        ' reached. Execution aborted."}\n',
    )


def test_handles_objects_and_nullability_using_inline_structs_executes_with_complex_input() raises:
    check(
        """
          {
            fieldWithObjectInput(input: {a: "foo", b: ["bar"], c: "baz"})
          }
        """,
        "",
        (
            '{"data":{"fieldWithObjectInput":"{ a: \\"foo\\", b: [\\"bar\\"], c'
            ': \\"baz\\" }"}}'
        ),
    )


def test_handles_objects_and_nullability_using_inline_structs_properly_parses_single_value_to_list() raises:
    check(
        """
          {
            fieldWithObjectInput(input: {a: "foo", b: "bar", c: "baz"})
          }
        """,
        "",
        (
            '{"data":{"fieldWithObjectInput":"{ a: \\"foo\\", b: [\\"bar\\"], c'
            ': \\"baz\\" }"}}'
        ),
    )


def test_handles_objects_and_nullability_using_inline_structs_properly_parses_null_value_to_null() raises:
    check(
        """
          {
            fieldWithObjectInput(input: {a: null, b: null, c: "C", d: null})
          }
        """,
        "",
        (
            '{"data":{"fieldWithObjectInput":"{ a: null, b: null, c: \\"C\\", d'
            ': null }"}}'
        ),
    )


def test_handles_objects_and_nullability_using_inline_structs_properly_parses_null_value_in_list() raises:
    check(
        """
          {
            fieldWithObjectInput(input: {b: ["A",null,"C"], c: "C"})
          }
        """,
        "",
        (
            '{"data":{"fieldWithObjectInput":"{ b: [\\"A\\", null, \\"C\\"], c:'
            ' \\"C\\" }"}}'
        ),
    )


def test_handles_objects_and_nullability_using_inline_structs_does_not_use_incorrect_value() raises:
    check(
        """
          {
            fieldWithObjectInput(input: ["foo", "bar", "baz"])
          }
        """,
        "",
        (
            '{"errors":[{"message":"Argument \\"input\\" has invalid value [\\"'
            'foo\\", \\"bar\\", \\"baz\\"].","locations":[{"line":3,"column":41'
            '}],"path":["fieldWithObjectInput"]}],"data":{"fieldWithObjectInput'
            '":null}}'
        ),
    )


def test_handles_objects_and_nullability_using_inline_structs_properly_runs_parseliteral_on_complex_scalar_types() raises:
    check(
        """
          {
            fieldWithObjectInput(input: {c: "foo", d: "SerializedValue"})
          }
        """,
        "",
        (
            '{"data":{"fieldWithObjectInput":"{ c: \\"foo\\", d: \\"SerializedV'
            'alue\\" }"}}'
        ),
    )


def test_handles_objects_and_nullability_errors_on_faulty_scalar_type_input() raises:
    check(
        """
        {
          fieldWithObjectInput(input: {c: "foo", e: "bar"})
        }
      """,
        "",
        '{"data":{"fieldWithObjectInput":"{ c: \\"foo\\", e: \\"bar\\" }"}}',
    )


def test_handles_objects_and_nullability_using_variables_executes_with_complex_input() raises:
    check(
        """
        query ($input: TestInputObject) {
          fieldWithObjectInput(input: $input)
        }
      """,
        '{"input":{"a":"foo","b":["bar"],"c":"baz"}}',
        (
            '{"data":{"fieldWithObjectInput":"{ a: \\"foo\\", b: [\\"bar\\"], c'
            ': \\"baz\\" }"}}'
        ),
    )


def test_handles_objects_and_nullability_using_variables_uses_undefined_when_variable_not_provided() raises:
    check(
        """
          query q($input: String) {
            fieldWithNullableStringInput(input: $input)
          }""",
        "{}",
        '{"data":{"fieldWithNullableStringInput":null}}',
    )


def test_handles_objects_and_nullability_using_variables_uses_null_when_variable_provided_explicit_null_value() raises:
    check(
        """
          query q($input: String) {
            fieldWithNullableStringInput(input: $input)
          }""",
        '{"input":null}',
        '{"data":{"fieldWithNullableStringInput":"null"}}',
    )


def test_handles_objects_and_nullability_using_variables_uses_default_value_when_not_provided() raises:
    check(
        """
          query ($input: TestInputObject = {a: "foo", b: ["bar"], c: "baz"}) {
            fieldWithObjectInput(input: $input)
          }
        """,
        "",
        (
            '{"data":{"fieldWithObjectInput":"{ a: \\"foo\\", b: [\\"bar\\"], c'
            ': \\"baz\\" }"}}'
        ),
    )


def test_handles_objects_and_nullability_using_variables_does_not_use_default_value_when_provided() raises:
    check(
        """
            query q($input: String = "Default value") {
              fieldWithNullableStringInput(input: $input)
            }
          """,
        '{"input":"Variable value"}',
        '{"data":{"fieldWithNullableStringInput":"\\"Variable value\\""}}',
    )


def test_handles_objects_and_nullability_using_variables_uses_explicit_null_value_instead_of_default_value() raises:
    check(
        """
          query q($input: String = "Default value") {
            fieldWithNullableStringInput(input: $input)
          }""",
        '{"input":null}',
        '{"data":{"fieldWithNullableStringInput":"null"}}',
    )


def test_handles_objects_and_nullability_using_variables_uses_null_default_value_when_not_provided() raises:
    check(
        """
          query q($input: String = null) {
            fieldWithNullableStringInput(input: $input)
          }""",
        "{}",
        '{"data":{"fieldWithNullableStringInput":"null"}}',
    )


def test_handles_objects_and_nullability_using_variables_properly_parses_single_value_to_list() raises:
    check(
        """
        query ($input: TestInputObject) {
          fieldWithObjectInput(input: $input)
        }
      """,
        '{"input":{"a":"foo","b":"bar","c":"baz"}}',
        (
            '{"data":{"fieldWithObjectInput":"{ a: \\"foo\\", b: [\\"bar\\"], c'
            ': \\"baz\\" }"}}'
        ),
    )


def test_handles_objects_and_nullability_using_variables_executes_with_complex_scalar_input() raises:
    check(
        """
        query ($input: TestInputObject) {
          fieldWithObjectInput(input: $input)
        }
      """,
        '{"input":{"c":"foo","d":"SerializedValue"}}',
        (
            '{"data":{"fieldWithObjectInput":"{ c: \\"foo\\", d: \\"SerializedV'
            'alue\\" }"}}'
        ),
    )


def test_handles_objects_and_nullability_using_variables_errors_on_faulty_scalar_type_input() raises:
    check(
        """
        query ($input: TestInputObject) {
          fieldWithObjectInput(input: $input)
        }
      """,
        '{"input":{"c":"foo","e":"SerializedValue"}}',
        (
            '{"data":{"fieldWithObjectInput":"{ c: \\"foo\\", e: \\"SerializedV'
            'alue\\" }"}}'
        ),
    )


def test_handles_objects_and_nullability_using_variables_errors_on_null_for_nested_non_null() raises:
    check(
        """
        query ($input: TestInputObject) {
          fieldWithObjectInput(input: $input)
        }
      """,
        '{"input":{"a":"foo","b":"bar","c":null}}',
        (
            '{"errors":[{"message":"Variable \\"$input\\" got invalid value nul'
            'l at \\"input.c\\"; Expected non-nullable type \\"String!\\" not t'
            'o be null.","locations":[{"line":2,"column":16}]}]}'
        ),
    )


def test_handles_objects_and_nullability_using_variables_errors_on_incorrect_type() raises:
    check(
        """
        query ($input: TestInputObject) {
          fieldWithObjectInput(input: $input)
        }
      """,
        '{"input":"foo bar"}',
        (
            '{"errors":[{"message":"Variable \\"$input\\" got invalid value \\"'
            'foo bar\\"; Expected type \\"TestInputObject\\" to be an object.",'
            '"locations":[{"line":2,"column":16}]}]}'
        ),
    )


def test_handles_objects_and_nullability_using_variables_errors_on_omission_of_nested_non_null() raises:
    check(
        """
        query ($input: TestInputObject) {
          fieldWithObjectInput(input: $input)
        }
      """,
        '{"input":{"a":"foo","b":"bar"}}',
        (
            '{"errors":[{"message":"Variable \\"$input\\" got invalid value { a'
            ': \\"foo\\", b: \\"bar\\" }; Field \\"c\\" of required type \\"Str'
            'ing!\\" was not provided.","locations":[{"line":2,"column":16}]}]}'
        ),
    )


def test_handles_objects_and_nullability_using_variables_errors_on_deep_nested_errors_and_with_many_errors() raises:
    check(
        """
          query ($input: TestNestedInputObject) {
            fieldWithNestedObjectInput(input: $input)
          }
        """,
        '{"input":{"na":{"a":"foo"}}}',
        (
            '{"errors":[{"message":"Variable \\"$input\\" got invalid value { a'
            ': \\"foo\\" } at \\"input.na\\"; Field \\"c\\" of required type \\'
            '"String!\\" was not provided.","locations":[{"line":2,"column":18}'
            ']},{"message":"Variable \\"$input\\" got invalid value { na: { a: '
            '\\"foo\\" } }; Field \\"nb\\" of required type \\"String!\\" was n'
            'ot provided.","locations":[{"line":2,"column":18}]}]}'
        ),
    )


def test_handles_objects_and_nullability_using_variables_errors_on_addition_of_unknown_input_field() raises:
    check(
        """
        query ($input: TestInputObject) {
          fieldWithObjectInput(input: $input)
        }
      """,
        '{"input":{"a":"foo","b":"bar","c":"baz","extra":"dog"}}',
        (
            '{"errors":[{"message":"Variable \\"$input\\" got invalid value { a'
            ': \\"foo\\", b: \\"bar\\", c: \\"baz\\", extra: \\"dog\\" }; Field'
            ' \\"extra\\" is not defined by type \\"TestInputObject\\".","locat'
            'ions":[{"line":2,"column":16}]}]}'
        ),
    )


def test_handles_custom_enum_values_allows_custom_enum_values_as_inputs() raises:
    check(
        """
        {
          null: fieldWithEnumInput(input: NULL)
          NaN: fieldWithEnumInput(input: NAN)
          false: fieldWithEnumInput(input: FALSE)
          customValue: fieldWithEnumInput(input: CUSTOM)
          defaultValue: fieldWithEnumInput(input: DEFAULT_VALUE)
        }
      """,
        "",
        (
            '{"data":{"null":"\\"NULL\\"","NaN":"\\"NAN\\"","false":"\\"FALSE\\'
            '"","customValue":"\\"CUSTOM\\"","defaultValue":"\\"DEFAULT_VALUE\\'
            '""}}'
        ),
    )


def test_handles_custom_enum_values_allows_non_nullable_inputs_to_have_null_as_enum_custom_value() raises:
    check(
        """
        {
          fieldWithNonNullableEnumInput(input: NULL)
        }
      """,
        "",
        '{"data":{"fieldWithNonNullableEnumInput":"\\"NULL\\""}}',
    )


def test_handles_nullable_scalars_allows_nullable_inputs_to_be_omitted() raises:
    check(
        """
        {
          fieldWithNullableStringInput
        }
      """,
        "",
        '{"data":{"fieldWithNullableStringInput":null}}',
    )


def test_handles_nullable_scalars_allows_nullable_inputs_to_be_omitted_in_a_variable() raises:
    check(
        """
        query ($value: String) {
          fieldWithNullableStringInput(input: $value)
        }
      """,
        "",
        '{"data":{"fieldWithNullableStringInput":null}}',
    )


def test_handles_nullable_scalars_allows_nullable_inputs_to_be_omitted_in_an_unlisted_variable() raises:
    check(
        """
        query {
          fieldWithNullableStringInput(input: $value)
        }
      """,
        "",
        '{"data":{"fieldWithNullableStringInput":null}}',
    )


def test_handles_nullable_scalars_allows_nullable_inputs_to_be_set_to_null_in_a_variable() raises:
    check(
        """
        query ($value: String) {
          fieldWithNullableStringInput(input: $value)
        }
      """,
        '{"value":null}',
        '{"data":{"fieldWithNullableStringInput":"null"}}',
    )


def test_handles_nullable_scalars_allows_nullable_inputs_to_be_set_to_a_value_in_a_variable() raises:
    check(
        """
        query ($value: String) {
          fieldWithNullableStringInput(input: $value)
        }
      """,
        '{"value":"a"}',
        '{"data":{"fieldWithNullableStringInput":"\\"a\\""}}',
    )


def test_handles_nullable_scalars_allows_nullable_inputs_to_be_set_to_a_value_directly() raises:
    check(
        """
        {
          fieldWithNullableStringInput(input: "a")
        }
      """,
        "",
        '{"data":{"fieldWithNullableStringInput":"\\"a\\""}}',
    )


def test_handles_non_nullable_scalars_allows_non_nullable_variable_to_be_omitted_given_a_default() raises:
    check(
        """
        query ($value: String! = "default") {
          fieldWithNullableStringInput(input: $value)
        }
      """,
        "",
        '{"data":{"fieldWithNullableStringInput":"\\"default\\""}}',
    )


def test_handles_non_nullable_scalars_allows_non_nullable_inputs_to_be_omitted_given_a_default() raises:
    check(
        """
        query ($value: String = "default") {
          fieldWithNonNullableStringInput(input: $value)
        }
      """,
        "",
        '{"data":{"fieldWithNonNullableStringInput":"\\"default\\""}}',
    )


def test_handles_non_nullable_scalars_does_not_allow_non_nullable_inputs_to_be_omitted_in_a_variable() raises:
    check(
        """
        query ($value: String!) {
          fieldWithNonNullableStringInput(input: $value)
        }
      """,
        "",
        (
            '{"errors":[{"message":"Variable \\"$value\\" of required type \\"S'
            'tring!\\" was not provided.","locations":[{"line":2,"column":16}]}'
            "]}"
        ),
    )


def test_handles_non_nullable_scalars_does_not_allow_non_nullable_inputs_to_be_set_to_null_in_a_variable() raises:
    check(
        """
        query ($value: String!) {
          fieldWithNonNullableStringInput(input: $value)
        }
      """,
        '{"value":null}',
        (
            '{"errors":[{"message":"Variable \\"$value\\" of non-null type \\"S'
            'tring!\\" must not be null.","locations":[{"line":2,"column":16}]}'
            "]}"
        ),
    )


def test_handles_non_nullable_scalars_allows_non_nullable_inputs_to_be_set_to_a_value_in_a_variable() raises:
    check(
        """
        query ($value: String!) {
          fieldWithNonNullableStringInput(input: $value)
        }
      """,
        '{"value":"a"}',
        '{"data":{"fieldWithNonNullableStringInput":"\\"a\\""}}',
    )


def test_handles_non_nullable_scalars_allows_non_nullable_inputs_to_be_set_to_a_value_directly() raises:
    check(
        """
        {
          fieldWithNonNullableStringInput(input: "a")
        }
      """,
        "",
        '{"data":{"fieldWithNonNullableStringInput":"\\"a\\""}}',
    )


def test_handles_non_nullable_scalars_reports_error_for_missing_non_nullable_inputs() raises:
    check(
        """{ fieldWithNonNullableStringInput }""",
        "",
        (
            '{"errors":[{"message":"Argument \\"input\\" of required type \\"St'
            'ring!\\" was not provided.","locations":[{"line":1,"column":3}],"p'
            'ath":["fieldWithNonNullableStringInput"]}],"data":{"fieldWithNonNu'
            'llableStringInput":null}}'
        ),
    )


def test_handles_non_nullable_scalars_reports_error_for_array_passed_into_string_input() raises:
    check(
        """
        query ($value: String!) {
          fieldWithNonNullableStringInput(input: $value)
        }
      """,
        '{"value":[1,2,3]}',
        (
            '{"errors":[{"message":"Variable \\"$value\\" got invalid value [1,'
            ' 2, 3]; String cannot represent a non string value: [1, 2, 3]","lo'
            'cations":[{"line":2,"column":16}]}]}'
        ),
    )


def test_handles_non_nullable_scalars_reports_error_for_non_provided_variables_for_non_nullable_inputs() raises:
    check(
        """
        {
          fieldWithNonNullableStringInput(input: $foo)
        }
      """,
        "",
        (
            '{"errors":[{"message":"Argument \\"input\\" of required type \\"St'
            'ring!\\" was provided the variable \\"$foo\\" which was not provid'
            'ed a runtime value.","locations":[{"line":3,"column":50}],"path":['
            '"fieldWithNonNullableStringInput"]}],"data":{"fieldWithNonNullable'
            'StringInput":null}}'
        ),
    )


def test_handles_lists_and_nullability_allows_lists_to_be_null() raises:
    check(
        """
        query ($input: [String]) {
          list(input: $input)
        }
      """,
        '{"input":null}',
        '{"data":{"list":"null"}}',
    )


def test_handles_lists_and_nullability_allows_lists_to_contain_values() raises:
    check(
        """
        query ($input: [String]) {
          list(input: $input)
        }
      """,
        '{"input":["A"]}',
        '{"data":{"list":"[\\"A\\"]"}}',
    )


def test_handles_lists_and_nullability_allows_lists_to_contain_null() raises:
    check(
        """
        query ($input: [String]) {
          list(input: $input)
        }
      """,
        '{"input":["A",null,"B"]}',
        '{"data":{"list":"[\\"A\\", null, \\"B\\"]"}}',
    )


def test_handles_lists_and_nullability_does_not_allow_non_null_lists_to_be_null() raises:
    check(
        """
        query ($input: [String]!) {
          nnList(input: $input)
        }
      """,
        '{"input":null}',
        (
            '{"errors":[{"message":"Variable \\"$input\\" of non-null type \\"['
            'String]!\\" must not be null.","locations":[{"line":2,"column":16}'
            "]}]}"
        ),
    )


def test_handles_lists_and_nullability_allows_non_null_lists_to_contain_values() raises:
    check(
        """
        query ($input: [String]!) {
          nnList(input: $input)
        }
      """,
        '{"input":["A"]}',
        '{"data":{"nnList":"[\\"A\\"]"}}',
    )


def test_handles_lists_and_nullability_allows_non_null_lists_to_contain_null() raises:
    check(
        """
        query ($input: [String]!) {
          nnList(input: $input)
        }
      """,
        '{"input":["A",null,"B"]}',
        '{"data":{"nnList":"[\\"A\\", null, \\"B\\"]"}}',
    )


def test_handles_lists_and_nullability_allows_lists_of_non_nulls_to_be_null() raises:
    check(
        """
        query ($input: [String!]) {
          listNN(input: $input)
        }
      """,
        '{"input":null}',
        '{"data":{"listNN":"null"}}',
    )


def test_handles_lists_and_nullability_allows_lists_of_non_nulls_to_contain_values() raises:
    check(
        """
        query ($input: [String!]) {
          listNN(input: $input)
        }
      """,
        '{"input":["A"]}',
        '{"data":{"listNN":"[\\"A\\"]"}}',
    )


def test_handles_lists_and_nullability_does_not_allow_lists_of_non_nulls_to_contain_null() raises:
    check(
        """
        query ($input: [String!]) {
          listNN(input: $input)
        }
      """,
        '{"input":["A",null,"B"]}',
        (
            '{"errors":[{"message":"Variable \\"$input\\" got invalid value nul'
            'l at \\"input[1]\\"; Expected non-nullable type \\"String!\\" not '
            'to be null.","locations":[{"line":2,"column":16}]}]}'
        ),
    )


def test_handles_lists_and_nullability_does_not_allow_non_null_lists_of_non_nulls_to_be_null() raises:
    check(
        """
        query ($input: [String!]!) {
          nnListNN(input: $input)
        }
      """,
        '{"input":null}',
        (
            '{"errors":[{"message":"Variable \\"$input\\" of non-null type \\"['
            'String!]!\\" must not be null.","locations":[{"line":2,"column":16'
            "}]}]}"
        ),
    )


def test_handles_lists_and_nullability_allows_non_null_lists_of_non_nulls_to_contain_values() raises:
    check(
        """
        query ($input: [String!]!) {
          nnListNN(input: $input)
        }
      """,
        '{"input":["A"]}',
        '{"data":{"nnListNN":"[\\"A\\"]"}}',
    )


def test_handles_lists_and_nullability_does_not_allow_non_null_lists_of_non_nulls_to_contain_null() raises:
    check(
        """
        query ($input: [String!]!) {
          nnListNN(input: $input)
        }
      """,
        '{"input":["A",null,"B"]}',
        (
            '{"errors":[{"message":"Variable \\"$input\\" got invalid value nul'
            'l at \\"input[1]\\"; Expected non-nullable type \\"String!\\" not '
            'to be null.","locations":[{"line":2,"column":16}]}]}'
        ),
    )


def test_handles_lists_and_nullability_does_not_allow_invalid_types_to_be_used_as_values() raises:
    check(
        """
        query ($input: TestType!) {
          fieldWithObjectInput(input: $input)
        }
      """,
        '{"input":{"list":["A","B"]}}',
        (
            '{"errors":[{"message":"Variable \\"$input\\" expected value of typ'
            'e \\"TestType!\\" which cannot be used as an input type.","locatio'
            'ns":[{"line":2,"column":24}]}]}'
        ),
    )


def test_handles_lists_and_nullability_does_not_allow_unknown_types_to_be_used_as_values() raises:
    check(
        """
        query ($input: UnknownType!) {
          fieldWithObjectInput(input: $input)
        }
      """,
        '{"input":"WhoKnows"}',
        (
            '{"errors":[{"message":"Variable \\"$input\\" expected value of typ'
            'e \\"UnknownType!\\" which cannot be used as an input type.","loca'
            'tions":[{"line":2,"column":24}]}]}'
        ),
    )


def test_execute_uses_argument_default_values_when_no_argument_provided() raises:
    check(
        """{ fieldWithDefaultArgumentValue }""",
        "",
        '{"data":{"fieldWithDefaultArgumentValue":"\\"Hello World\\""}}',
    )


def test_execute_uses_argument_default_values_when_omitted_variable_provided() raises:
    check(
        """
        query ($optional: String) {
          fieldWithDefaultArgumentValue(input: $optional)
        }
      """,
        "",
        '{"data":{"fieldWithDefaultArgumentValue":"\\"Hello World\\""}}',
    )


def test_execute_uses_argument_default_values_not_when_argument_cannot_be_coerced() raises:
    check(
        """
        {
          fieldWithDefaultArgumentValue(input: WRONG_TYPE)
        }
      """,
        "",
        (
            '{"errors":[{"message":"Argument \\"input\\" has invalid value WRON'
            'G_TYPE.","locations":[{"line":3,"column":48}],"path":["fieldWithDe'
            'faultArgumentValue"]}],"data":{"fieldWithDefaultArgumentValue":nul'
            "l}}"
        ),
    )


def test_execute_uses_argument_default_values_when_no_runtime_value_is_provided_to_a_non_null_argument() raises:
    check(
        """
        query optionalVariable($optional: String) {
          fieldWithNonNullableStringInputAndDefaultArgumentValue(input: $optional)
        }
      """,
        "",
        (
            '{"data":{"fieldWithNonNullableStringInputAndDefaultArgumentValue":'
            '"\\"Hello World\\""}}'
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests ported from graphql-go-tools v2
`v2/pkg/astnormalization/inject_input_default_values_test.go`."""

from _norm import *
from _norm_fixtures import *
from std.testing import TestSuite


def test_should_not_change() raises:
    run_vars(
        inject_defaults_pass,
        TEST_INPUT_DEFAULT_SCHEMA,
        """
			mutation testDefaultValueSimple($a: SimpleTestInput!) {
  				testDefaultValueSimple(data: $a)
			}""",
        """
			mutation testDefaultValueSimple($a: SimpleTestInput!) {
  				testDefaultValueSimple(data: $a)
			}""",
        """{"a":{"firstField":"test","secondField":2}}""",
        """{"a":{"firstField":"test","secondField":2}}""",
    )


def test_simple_default_value_extract() raises:
    run_vars(
        inject_defaults_pass,
        TEST_INPUT_DEFAULT_SCHEMA,
        """
			mutation testDefaultValueSimple($a: SimpleTestInput!) {
  				testDefaultValueSimple(data: $a)
			}""",
        """
			mutation testDefaultValueSimple($a: SimpleTestInput!) {
  				testDefaultValueSimple(data: $a)
			}""",
        """{"a":{"firstField":"test"}}""",
        """{"a":{"firstField":"test","secondField":1}}""",
    )


def test_simple_default_value_nullable_extract() raises:
    run_vars(
        extract_pass,
        TEST_INPUT_DEFAULT_SCHEMA,
        """
			mutation{
  				testDefaultValueSimpleNull(data: {firstField: "test"})
			}""",
        """
			mutation($a: LowerLevelInput) {
  				testDefaultValueSimpleNull(data: $a)
			}""",
        "",
        """{"a":{"firstField":"test","secondField":"ValueOne"}}""",
        [inject_defaults_pass],
    )


def test_nested_input_field_with_default_values() raises:
    run_vars(
        inject_defaults_pass,
        TEST_INPUT_DEFAULT_SCHEMA,
        """
			mutation testNestedInputField($a: InputWithNestedField) {
			  testNestedInputField(data: $a)
			}""",
        """
			mutation testNestedInputField($a: InputWithNestedField) {
  				testNestedInputField(data: $a)
			}""",
        """{"a":{"nested":{}}}""",
        """{"a":{"nested":{"secondField":"ValueOne"}}}""",
    )


def test_multiple_variables_for_operation() raises:
    run_vars(
        inject_defaults_pass,
        TEST_INPUT_DEFAULT_SCHEMA,
        """
			mutation combinedMutation($a: SimpleTestInput, $b: InputWithNestedField) {
  				testDefaultValueSimple(data: $a)
  				testNestedInputField(data: $b)
			}""",
        """
			mutation combinedMutation($a: SimpleTestInput, $b: InputWithNestedField) {
  				testDefaultValueSimple(data: $a)
  				testNestedInputField(data: $b)
			}""",
        """{"b":{"nested":{}},"a":{"firstField":"test"}}""",
        """{"b":{"nested":{"secondField":"ValueOne"}},"a":{"firstField":"test","secondField":1}}""",
    )


def test_default_field_object_is_partial() raises:
    run_vars(
        inject_defaults_pass,
        TEST_INPUT_DEFAULT_SCHEMA,
        """
			mutation($a: InputWithDefaultFieldsNested){
				mutationNestedMissing(in: $a)
			}""",
        """
			mutation($a: InputWithDefaultFieldsNested){
				mutationNestedMissing(in: $a)
			}""",
        """{"a":{"first":"test"}}""",
        """{"a":{"first":"test","nested":{"firstField":0,"secondField":"ValueOne"}}}""",
    )


def test_variable_for_input_field_as_object_is_partial() raises:
    run_vars(
        inject_defaults_pass,
        TEST_INPUT_DEFAULT_SCHEMA,
        """
			mutation($a: InputWithDefaultFieldsNested){
				mutationNestedMissing(in: $a)
			}""",
        """
			mutation($a: InputWithDefaultFieldsNested){
				mutationNestedMissing(in: $a)
			}""",
        """{"a":{"first":"test","nested":{"firstField":1}}}""",
        """{"a":{"first":"test","nested":{"firstField":1,"secondField":"ValueOne"}}}""",
    )


def test_run_with_extract_variables() raises:
    run_vars(
        extract_pass,
        TEST_INPUT_DEFAULT_SCHEMA,
        """
		mutation {
  			testNestedInputField(data: { nested: { firstField: 1 } })
		}""",
        """
		mutation($a: InputWithNestedField!) {
  				testNestedInputField(data: $a)
		}""",
        "",
        """{"a":{"nested":{"firstField":1,"secondField":"ValueOne"}}}""",
        [inject_defaults_pass],
    )


def test_list_default_value() raises:
    run_vars(
        inject_defaults_pass,
        TEST_INPUT_DEFAULT_SCHEMA,
        """
			mutation mutationWithListInput($a: InputHasList) {
			  mutationWithListInput(data: $a)
			}""",
        """
			mutation mutationWithListInput($a: InputHasList) {
			  mutationWithListInput(data: $a)
			}
""",
        """{"a":{}}""",
        """{"a":{"firstList":[{"firstField":1,"secondField":"ValueOne"},{"firstField":1,"secondField":"ValueOne"}]}}""",
    )


def test_list_object_partial_value() raises:
    run_vars(
        inject_defaults_pass,
        TEST_INPUT_DEFAULT_SCHEMA,
        """
			mutation mutationWithListInput($a: InputHasList) {
			  mutationWithListInput(data: $a)
			}""",
        """
			mutation mutationWithListInput($a: InputHasList) {
			  mutationWithListInput(data: $a)
			}
""",
        """{"a":{"firstList":[{"firstField":10}]}}""",
        """{"a":{"firstList":[{"firstField":10,"secondField":"ValueOne"}]}}""",
    )


def test_nested_list_default_value() raises:
    run_vars(
        inject_defaults_pass,
        TEST_INPUT_DEFAULT_SCHEMA,
        """
			mutation mutationWithMultiNestedInput($a: MultiNestedInput) {
			  mutationWithMultiNestedInput(data: $a)
			}""",
        """
			mutation mutationWithMultiNestedInput($a: MultiNestedInput) {
			  mutationWithMultiNestedInput(data: $a)
			}
""",
        """{"a":{}}""",
        """{"a":{"nested":[[{"firstField":1,"secondField":"ValueOne"}]]}}""",
    )


def test_complex_nested_list_partial_in_variable() raises:
    run_vars(
        inject_defaults_pass,
        TEST_INPUT_DEFAULT_SCHEMA,
        """
			mutation mutationComplexNestedListInput($a: ComplexNestedListInput) {
			  mutationComplexNestedListInput(data: $a)
			}""",
        """
			mutation mutationComplexNestedListInput($a: ComplexNestedListInput) {
			  mutationComplexNestedListInput(data: $a)
			}
""",
        """{"a":{"nested":[[[{"firstField":2}]]]}}""",
        """{"a":{"nested":[[[{"firstField":2,"secondField":"ValueOne"}]]]}}""",
    )


def test_simple_list_nested_input() raises:
    run_vars(
        inject_defaults_pass,
        TEST_INPUT_DEFAULT_SCHEMA,
        """
			mutation mutationSimpleInputList($a: [SimpleTestInput]) {
			  mutationSimpleInputList(data: $a)
			}""",
        """
			mutation mutationSimpleInputList($a: [SimpleTestInput]) {
			  mutationSimpleInputList(data: $a)
			}""",
        """{"a":[{"thirdField":1}]}""",
        """{"a":[{"thirdField":1,"firstField":"firstField","secondField":1}]}""",
    )


def test_simple_list_nested_input_with_more_than_2_elements() raises:
    run_vars(
        inject_defaults_pass,
        TEST_INPUT_DEFAULT_SCHEMA,
        """
			mutation mutationSimpleInputList($a: [SimpleTestInput]) {
			  mutationSimpleInputList(data: $a)
			}""",
        """
			mutation mutationSimpleInputList($a: [SimpleTestInput]) {
			  mutationSimpleInputList(data: $a)
		}""",
        """{"a":[{"thirdField":1}, {"thirdField":2}, {"thirdField":3}]}""",
        """{"a":[{"thirdField":1,"firstField":"firstField","secondField":1}, {"thirdField":2,"firstField":"firstField","secondField":1}, {"thirdField":3,"firstField":"firstField","secondField":1}]}""",
    )


def test_simple_list_double_nested_input_with_more_than_2_elements() raises:
    run_vars(
        inject_defaults_pass,
        TEST_INPUT_DEFAULT_SCHEMA,
        """
			mutation mutationSimpleInputListDoubleNested($a: [[SimpleTestInput]]) {
			  mutationSimpleInputListDoubleNested(data: $a)
			}""",
        """
			mutation mutationSimpleInputListDoubleNested($a: [[SimpleTestInput]]) {
			  mutationSimpleInputListDoubleNested(data: $a)
		}""",
        """{"a":[[{"thirdField":1}, {"thirdField":2}, {"thirdField":3}],[{"thirdField":4}, {"thirdField":5}],[{"thirdField":6}]]}""",
        """{"a":[[{"thirdField":1,"firstField":"firstField","secondField":1}, {"thirdField":2,"firstField":"firstField","secondField":1}, {"thirdField":3,"firstField":"firstField","secondField":1}],[{"thirdField":4,"firstField":"firstField","secondField":1}, {"thirdField":5,"firstField":"firstField","secondField":1}],[{"thirdField":6,"firstField":"firstField","secondField":1}]]}""",
    )


def test_use_custom_scalar_variable() raises:
    run_vars(
        inject_defaults_pass,
        TEST_INPUT_DEFAULT_SCHEMA,
        """
			mutation mutationUseCustomScalar($a: CustomScalar) {
			  mutationUseCustomScalar(in: $a)
			}""",
        """
			mutation mutationUseCustomScalar($a: CustomScalar) {
			  mutationUseCustomScalar(in: $a)
			}""",
        """{"a":{}}""",
        """{"a":{}}""",
    )


def test_custom_scalar_variable_list() raises:
    run_vars(
        inject_defaults_pass,
        TEST_INPUT_DEFAULT_SCHEMA,
        """
			mutation mutationUseCustomScalarList($a: [CustomScalar!]) {
			  mutationUseCustomScalarList(in: $a)
			}""",
        """
			mutation mutationUseCustomScalarList($a: [CustomScalar!]) {
			  mutationUseCustomScalarList(in: $a)
			}""",
        """{"a":[{"test": "testval"}]}""",
        """{"a":[{"test": "testval"}]}""",
    )


def test_null_default_value_for_object_and_list_fields() raises:
    run_vars(
        extract_pass,
        TEST_INPUT_DEFAULT_SCHEMA,
        """
			mutation TestDefaults($data: NullDefaultForObjectAndListField!) {
  				testNullDefaultValuesForObjectAndList(data: $data)
			}""",
        """
			mutation TestDefaults($data: NullDefaultForObjectAndListField!) {
  				testNullDefaultValuesForObjectAndList(data: $data)
			}""",
        """{"data":{"other":"value"}}""",
        """{"data":{"other":"value","nested":null,"nestedList":null}}""",
        [inject_defaults_pass],
    )


def test_null_default_value_for_scalar_fields() raises:
    run_vars(
        extract_pass,
        TEST_INPUT_DEFAULT_SCHEMA,
        """
			mutation{
  				testNullDefaultValueForFields(data: {})
			}""",
        """
			mutation($a: NullDefaultFields!) {
  				testNullDefaultValueForFields(data: $a)
			}""",
        "",
        """{"a":{"a":null,"b":null}}""",
        [inject_defaults_pass],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

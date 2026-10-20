# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests ported from graphql-go-tools v2
`v2/pkg/astnormalization/input_coercion_for_list_test.go`."""

from _norm import *
from _norm_fixtures import *
from std.testing import TestSuite


def test_convert_integer_to_list_of_integer() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
			query {
			  charactersByIds(ids: 1) {
				id
				name
			  }
			}""",
        """
			query ($a: [Int]){
			  charactersByIds(ids: $a) {
				id
				name
			  }
			}""",
        """{}""",
        """{"a":[1]}""",
        [coercion_pass],
    )


def test_strings_list_variants_convert_string_to_list_of_strings() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
				query {
				  charactersByStringIds(ids: "id") {
					id
					name
				  }
				}""",
        """
				query ($a: [String]){
				  charactersByStringIds(ids: $a) {
					id
					name
				  }
				}""",
        """{}""",
        """{"a":["id"]}""",
        [coercion_pass],
    )


def test_strings_list_variants_convert_string_id_to_list_of_id() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
				query {
				  charactersByIdScalarIds(ids: "id") {
					id
					name
				  }
				}""",
        """
				query ($a: [ID]){
				  charactersByIdScalarIds(ids: $a) {
					id
					name
				  }
				}""",
        """{}""",
        """{"a":["id"]}""",
        [coercion_pass],
    )


def test_strings_list_variants_convert_int_id_to_list_of_id() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
				query Q {
				  charactersByIdScalarIds(ids: 1) {
					id
					name
				  }
				}""",
        """
				query Q ($a: [ID]){
				  charactersByIdScalarIds(ids: $a) {
					id
					name
				  }
				}""",
        """{}""",
        """{"a":[1]}""",
        [coercion_pass],
    )


def test_input_with_nested_scalar_list_query() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
				query Q {
					inputWithNestedScalar(input: {
						stringList: "str",
						intList: 1
					}) 
				}""",
        """
				query Q($a: InputWithNestedScalarList) {
					inputWithNestedScalar(input: $a) 
				}""",
        """{}""",
        """{"a":{"stringList":["str"],"intList":[1]}}""",
        [coercion_pass],
    )


def test_input_with_nested_scalar_list_query_with_null_values() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
				query Q {
					inputWithNestedScalar(input: {
						stringList: null,
						intList: null
					}) 
				}""",
        """
				query Q($a: InputWithNestedScalarList) {
					inputWithNestedScalar(input: $a) 
				}""",
        """{}""",
        """{"a":{"stringList":null,"intList":null}}""",
        [coercion_pass],
    )


def test_input_with_nested_scalar_list_mutation() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
				mutation Mutate {
					mutate(input: {
						stringList: "str"
					}) 
				}""",
        """
				mutation Mutate($a: InputWithNestedScalarList) {
					mutate(input: $a) 
				}""",
        """{}""",
        """{"a":{"stringList":["str"]}}""",
        [coercion_pass],
    )


def test_input_with_nested_scalar_list_mutation_with_list_of_inputs_with_nested_list_fields() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
				mutation Mutate {
					mutateWithList(input: {
						stringList: "str"
					}) 
				}""",
        """
				mutation Mutate($a: [InputWithNestedScalarList]) {
					mutateWithList(input: $a) 
				}""",
        """{}""",
        """{"a":[{"stringList":["str"]}]}""",
        [coercion_pass],
    )


def test_input_with_nested_scalar_list_mutation_should_coerse_each_nested_field_of_element_of_a_list() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
				mutation Mutate {
					mutateWithList(input: [
						{stringList: "str"},
						{intList: 1}
					]) 
				}""",
        """
				mutation Mutate($a: [InputWithNestedScalarList]) {
					mutateWithList(input: $a) 
				}""",
        """{}""",
        """{"a":[{"stringList":["str"]},{"intList":[1]}]}""",
        [coercion_pass],
    )


def test_input_with_nested_scalar_list_mutation_list_items_as_variables() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
				mutation Mutate($a: InputWithNestedScalarList, $b: InputWithNestedScalarList) {
					mutateWithList(input: [
						$a,
						$b
					])
				}""",
        """
				mutation Mutate($a: InputWithNestedScalarList, $b: InputWithNestedScalarList, $c: [InputWithNestedScalarList]){
					mutateWithList(input: $c)
				}""",
        """{"a":{"stringList":"str"},"b":{"intList":1}}""",
        """{"c":[{"stringList":["str"]},{"intList":[1]}],"a":{"stringList":["str"]},"b":{"intList":[1]}}""",
        [coercion_pass],
    )


def test_input_with_nested_scalar_list_mutation_list_items_as_variables_with_additional_variables() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
				mutation Mutate($a: InputWithNestedScalarList, $b: InputWithNestedScalarList) {
					mutateWithList(input: [
						$a,
						$b,
						{stringList: "str2"},
						{intList: 1}
					])
				}""",
        """
				mutation Mutate($a: InputWithNestedScalarList, $b: InputWithNestedScalarList, $c: [InputWithNestedScalarList]){
					mutateWithList(input: $c)
				}""",
        """{"a":{"stringList":"str"},"b":{"intList":1}}""",
        """{"c":[{"stringList":["str"]},{"intList":[1]},{"stringList":["str2"]},{"intList":[1]}],"a":{"stringList":["str"]},"b":{"intList":[1]}}""",
        [coercion_pass],
    )


def test_input_with_nested_scalar_list_mutation_nested() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
				mutation Mutate {
					mutateNested(input: {
						nested: {
							stringList: "str"
						}
					}) 
				}""",
        """
				mutation Mutate($a: Nested) {
					mutateNested(input: $a) 
				}""",
        """{}""",
        """{"a":{"nested":{"stringList":["str"]}}}""",
        [coercion_pass],
    )


def test_input_with_nested_scalar_list_mutation_deep_nested() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
				mutation Mutate {
					mutateDeepNested(input: {
						deepNested: {
							nested: {
								stringList: "str"
							}
						}
					}) 
				}""",
        """
				mutation Mutate($a: DeepNested) {
					mutateDeepNested(input: $a) 
				}""",
        """{}""",
        """{"a":{"deepNested":{"nested":{"stringList":["str"]}}}}""",
        [coercion_pass],
    )


def test_input_with_nested_scalar_list_mutation_deep_nested_in_extreme_list() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
				mutation Mutate {
					mutateNestedExtremeList(input: {
						nested: {
							stringList: "str"
						}
					}) 
				}""",
        """
				mutation Mutate($a: ExtremeNesting) {
					mutateNestedExtremeList(input: $a) 
				}""",
        """{}""",
        """{"a":{"nested":[[[[[{"stringList":["str"]}]]]]]}}""",
        [coercion_pass],
    )


def test_input_with_nested_scalar_list_mutation_multi_arg() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
				mutation Mutate {
					mutateMultiArg(arg1: {stringList: "str"}, arg2: {intList: 1})
				}""",
        """
				mutation Mutate($a: InputWithNestedScalarList, $b: InputWithNestedScalarList) {
					mutateMultiArg(arg1: $a, arg2: $b) 
				}""",
        """{}""",
        """{"b":{"intList":[1]},"a":{"stringList":["str"]}}""",
        [coercion_pass],
    )


def test_list_of_integers() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
			query {
			  charactersByIds(ids: [1, 2, 3]) {
				id
				name
			  }
			}""",
        """
			query ($a: [Int]){
			  charactersByIds(ids: $a) {
				id
				name
			  }
			}""",
        """{}""",
        """{"a":[1,2,3]}""",
        [coercion_pass],
    )


def test_nested_list_of_integers() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
			query {
			  nestedList(ids: [[1], [2, 3]]) {
				id
				name
			  }
			}""",
        """
			query ($a: [[Int]]) {
			  nestedList(ids: $a) {
				id
				name
			  }
			}""",
        """{}""",
        """{"a":[[1],[2,3]]}""",
        [coercion_pass],
    )


def test_list_of_integers_with_null_value() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
			query {
			  charactersByIds(ids: null) {
				id
				name
			  }
			}""",
        """
			query ($a: [Int]){
			  charactersByIds(ids: $a) {
				id
				name
			  }
			}""",
        """{}""",
        """{"a":null}""",
        [coercion_pass],
    )


def test_nested_list_with_null_value() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
			query {
			  nestedList(ids: null) {
				id
				name
			  }
			}""",
        """
			query ($a: [[Int]]){
			  nestedList(ids: $a) {
				id
				name
			  }
			}""",
        """{}""",
        """{"a":null}""",
        [coercion_pass],
    )


def test_convert_integer_to_nested_list_of_integer() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
			query {
			  nestedList(ids: 1) {
				id
				name
			  }
			}""",
        """
			query ($a: [[Int]]){
			  nestedList(ids: $a) {
				id
				name
			  }
			}""",
        """{}""",
        """{"a":[[1]]}""",
        [coercion_pass],
    )


def test_integer_argument_without_modification() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
			query {
			  characterById(id: 1) {
				id
				name
			  }
			}""",
        """
			query ($a: Int) {
			  characterById(id: $a) {
				id
				name
			  }
			}""",
        """{}""",
        """{"a":1}""",
    )


def test_non_null_integer_argument_without_modification() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
			query {
			  characterByIdNonNullInteger(id: 1) {
				id
				name
			  }
			}""",
        """
			query ($a: Int!){
			  characterByIdNonNullInteger(id: $a) {
				id
				name
			  }
			}""",
        """{}""",
        """{"a":1}""",
        [coercion_pass],
    )


def test_do_not_modify_null_as_argument() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
			query {
			  characterByIdNonNullInteger(id: null) {
				id
				name
			  }
			}""",
        """
			query ($a: Int!){
			  characterByIdNonNullInteger(id: $a) {
				id
				name
			  }
			}""",
        """{}""",
        """{"a":null}""",
        [coercion_pass],
    )


def test_convert_object_type_to_list_of_object_type() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
			query {
			  charactersByInputs(inputs: { foo: "bar" }) {
				id
				name
			  }
			}""",
        """
			query ($a: [Input]){
			  charactersByInputs(inputs: $a) {
				id
				name
			  }
			}""",
        """{}""",
        """{"a":[{"foo":"bar"}]}""",
        [coercion_pass],
    )


def test_list_of_object_type_to_list_of_object_type_remains_unchanged() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
			query {
			  charactersByInputs(inputs: [{ foo: "bar" },{ foo: "bazz" }]) {
				id
				name
			  }
			}""",
        """
			query ($a: [Input]){
			  charactersByInputs(inputs: $a) {
				id
				name
			  }
			}""",
        """{}""",
        """{"a":[{"foo":"bar"},{"foo":"bazz"}]}""",
        [coercion_pass],
    )


def test_object_type_definition() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
			query {
			  characterByInput(input: { foo: "bar" }) {
				id
				name
			  }
			}""",
        """
			query ($a: Input){
			  characterByInput(input: $a) {
				id
				name
			  }
			}""",
        """{}""",
        """{"a":{"foo":"bar"}}""",
        [coercion_pass],
    )


def test_handle_non_existent_variable() raises:
    run_vars(
        coercion_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
			query ($ids: [[Int]]) {
			  nestedList(ids: $ids) {
				id
				name
			  }
			}""",
        """
			query ($ids: [[Int]]) {
			  nestedList(ids: $ids) {
				id
				name
			  }
			}""",
        """{"foo": "bar"}""",
        """{"foo": "bar"}""",
    )


def test_convert_integer_to_list_of_integer_non_null_list() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
			query {
			  charactersByIdsNonNull(ids: 1) {
				id
				name
			  }
			}""",
        """
			query ($a: [Int]!){
			  charactersByIdsNonNull(ids: $a) {
				id
				name
			  }
			}""",
        """{}""",
        """{"a":[1]}""",
        [coercion_pass],
    )


def test_convert_integer_to_list_of_integer_non_null_integer() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
			query {
			  charactersByIdsNonNullInteger(ids: 1) {
				id
				name
			  }
			}""",
        """
			query ($a: [Int!]!){
			  charactersByIdsNonNullInteger(ids: $a) {
				id
				name
			  }
			}""",
        """{}""",
        """{"a":[1]}""",
        [coercion_pass],
    )


def test_send_list_of_integers_as_argument_non_null_integer() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
			query {
			  charactersByIdsNonNullInteger(ids: [1]) {
				id
				name
			  }
			}""",
        """
			query ($a: [Int!]!) {
			  charactersByIdsNonNullInteger(ids: $a) {
				id
				name
			  }
			}""",
        """{}""",
        """{"a":[1]}""",
        [coercion_pass],
    )


def test_send_list_of_integers_as_argument_non_null_list() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
			query {
			  charactersByIdsNonNull(ids: [1]) {
				id
				name
			  }
			}""",
        """
			query ($a: [Int]!) {
			  charactersByIdsNonNull(ids: $a) {
				id
				name
			  }
			}""",
        """{}""",
        """{"a":[1]}""",
        [coercion_pass],
    )


def test_convert_integer_to_nested_list_of_integer_non_null_nested_list() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
			query {
			  nestedListNonNull(ids: 1) {
				id
				name
			  }
			}""",
        """
			query ($a: [[Int!]!]!){
			  nestedListNonNull(ids: $a) {
				id
				name
			  }
			}""",
        """{}""",
        """{"a":[[1]]}""",
        [coercion_pass],
    )


def test_convert_integer_to_nested_list_of_integer_non_null_inner_list() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
			query {
			  innerListNonNull(ids: 1) {
				id
				name
			  }
			}""",
        """
			query ($a: [[Int]!]){
			  innerListNonNull(ids: $a) {
				id
				name
			  }
			}""",
        """{}""",
        """{"a":[[1]]}""",
        [coercion_pass],
    )


def test_send_list_of_integers_as_variable_input() raises:
    run_vars(
        coercion_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
			query ($ids: [[Int]]) {
			  nestedList(ids: $ids) {
				id
				name
			  }
			}""",
        """
			query ($ids: [[Int]]) {
			  nestedList(ids: $ids) {
				id
				name
			  }
			}""",
        """{"ids":[1]}""",
        """{"ids":[[1]]}""",
    )


def test_send_inline_null_to_characters_by_ids_non_null() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
			query {
			  charactersByIdsNonNull(ids: null) {
				id
				name
			  }
			}""",
        """
			query ($a: [Int]!){
			  charactersByIdsNonNull(ids: $a) {
				id
				name
			  }
			}""",
        """{}""",
        """{"a":null}""",
        [coercion_pass],
    )


def test_send_inline_null_to_nested_list_non_null() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
			query {
			  nestedListNonNull(ids: null) {
				id
				name
			  }
			}""",
        """
			query ($a: [[Int!]!]!){
			  nestedListNonNull(ids: $a) {
				id
				name
			  }
			}""",
        """{}""",
        """{"a":null}""",
        [coercion_pass],
    )


def test_send_inline_null_to_characters_by_ids_non_null_integer() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
			query {
			  charactersByIdsNonNullInteger(ids: null) {
				id
				name
			  }
			}""",
        """
			query ($a: [Int!]!){
			  charactersByIdsNonNullInteger(ids: $a) {
				id
				name
			  }
			}""",
        """{}""",
        """{"a":null}""",
        [coercion_pass],
    )


def test_nested_variants_nested_variables() raises:
    run_vars(
        coercion_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
				query ($input: InputWithList) {
				  inputWithList(input: $input) {
					id
					name
				  }
				}""",
        """
				query ($input: InputWithList) {
				  inputWithList(input: $input) {
					id
					name
				  }
				}""",
        """{"input":{"list":{"foo":"bar","list":{"foo":"bar2","list":{"nested":{"foo":"bar3","list":{"foo":"bar4"}}}}}}}""",
        """{"input":{"list":[{"foo":"bar","list":[{"foo":"bar2","list":[{"nested":{"foo":"bar3","list":[{"foo":"bar4"}]}}]}]}]}}""",
    )


def test_nested_variants_nested_variables_non_null() raises:
    run_vars(
        coercion_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
				query ($input: InputWithListNonNull) {
				  inputWithListNonNull(input: $input) {
					id
					name
				  }
				}""",
        """
				query ($input: InputWithListNonNull) {
				  inputWithListNonNull(input: $input) {
					id
					name
				  }
				}""",
        """{"input":{"list":{"foo":"bar","list":{"foo":"bar2","list":{"nested":{"foo":"bar3","list":{"foo":"bar4"}}}}}}}""",
        """{"input":{"list":[{"foo":"bar","list":[{"foo":"bar2","list":[{"nested":{"foo":"bar3","list":[{"foo":"bar4"}]}}]}]}]}}""",
    )


def test_nested_variants_nested_variables_list() raises:
    run_vars(
        coercion_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
				query ($input: InputWithListNestedList) {
				  inputWithListNestedList(input: $input) {
					id
					name
				  }
				}""",
        """
				query ($input: InputWithListNestedList) {
				  inputWithListNestedList(input: $input) {
					id
					name
				  }
				}""",
        """{"input":{"doubleList":{"foo":"bar","list":{"foo":"bar2","list":{"nested":{"foo":"bar3","list":{"foo":"bar4"}}}}}}}""",
        """{"input":{"doubleList":[[{"foo":"bar","list":[{"foo":"bar2","list":[{"nested":{"foo":"bar3","list":[{"foo":"bar4"}]}}]}]}]]}}""",
    )


def test_nested_variants_nested_test_with_inline_values() raises:
    run_vars(
        extract_pass,
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
				query Foo {
				  inputWithList(input: {list:{foo:"bar",list:{foo:"bar2",list:{nested:{foo:"bar3",list:{foo:"bar4"}}}}}}) {
					id
					name
				  }
				}""",
        """
				query Foo($a: InputWithList) {
				  inputWithList(input: $a) {
					id
					name
				  }
				}""",
        """{}""",
        """{"a":{"list":[{"foo":"bar","list":[{"foo":"bar2","list":[{"nested":{"foo":"bar3","list":[{"foo":"bar4"}]}}]}]}]}}""",
        [coercion_pass],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

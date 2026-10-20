# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests ported from graphql-go-tools v2
`v2/pkg/astnormalization/variables_default_value_extraction_test.go`."""

from _norm import *
from _norm_fixtures import *
from std.testing import TestSuite


def test_field_argument_default_value_no_value_provided() raises:
    run_vars(
        default_values_pass,
        VARIABLES_DEFAULT_VALUE_EXTRACTION_DEFINITION,
        """
				mutation simple {
			  		simple
				}""",
        """
				mutation simple {
					simple
				}""",
        """""",
        """""",
    )


def test_field_argument_default_value_value_provided() raises:
    run_vars(
        default_values_pass,
        VARIABLES_DEFAULT_VALUE_EXTRACTION_DEFINITION,
        """
				mutation simple {
					simple(input: "bazz")
				}""",
        """
				mutation simple {
					simple(input: "bazz")
				}""",
        """""",
        """""",
    )


def test_field_argument_default_value_mixed() raises:
    run_vars(
        default_values_pass,
        VARIABLES_DEFAULT_VALUE_EXTRACTION_DEFINITION,
        """
				mutation simple($a: String) {
			  		mixed(a: $a, b: "bar")
				}""",
        """
				mutation simple($a: String) {
			  		mixed(a: $a, b: "bar")
				}""",
        """{"a":"aaa"}""",
        """{"a":"aaa"}""",
    )


def test_variable_with_default_value_no_value_provided() raises:
    run_vars(
        default_values_pass,
        VARIABLES_DEFAULT_VALUE_EXTRACTION_DEFINITION,
        """
				mutation simple($in: String = "bar" ) {
					simple(input: $in)
				}""",
        """
				mutation simple($in: String) {
			  		simple(input: $in)
				}""",
        """""",
        """{"in":"bar"}""",
    )


def test_variable_with_default_value_value_provided() raises:
    run_vars(
        default_values_pass,
        VARIABLES_DEFAULT_VALUE_EXTRACTION_DEFINITION,
        """
				mutation simple($in: String = "bar" ) {
			  		simple(input: $in)
				}""",
        """
				mutation simple($in: String) {
			  		simple(input: $in)
				}""",
        """{"in":"foo"}""",
        """{"in":"foo"}""",
    )


def test_variable_with_default_value_multiple_variables_with_default_values_vars_inside_object_and_lists() raises:
    run_vars(
        default_values_pass,
        VARIABLES_DEFAULT_VALUE_EXTRACTION_DEFINITION,
        """
					query q(
						$nullable: String = "a",
						$notNullable: String = "b",
						$strIntolist: String = "1",
						$strIntolistOfNonNull: String = "2"
						$strIntolistNonNullItemNullable: String = "3",
						$strIntolistNonNullItemNotNull: String = "4"
					) {
						complex(input: {
							NotNullable: $notNullable,
							Nullable: $nullable,
							list: [$strIntolist],
							listOfNonNull: [$strIntolistOfNonNull],
							listNonNullItemNullable: [$strIntolistNonNullItemNullable],
							listNonNullItemNotNull: [$strIntolistNonNullItemNotNull],
						})
					}""",
        """
					query q(
						$nullable: String,
						$notNullable: String!,
						$strIntolist: String,
						$strIntolistOfNonNull: String!
						$strIntolistNonNullItemNullable: String,
						$strIntolistNonNullItemNotNull: String!
					) {
						complex(input: {
							NotNullable: $notNullable,
							Nullable: $nullable,
							list: [$strIntolist],
							listOfNonNull: [$strIntolistOfNonNull],
							listNonNullItemNullable: [$strIntolistNonNullItemNullable],
							listNonNullItemNotNull: [$strIntolistNonNullItemNotNull],
						})
					}""",
        """""",
        """{"strIntolistNonNullItemNotNull":"4","strIntolistNonNullItemNullable":"3","strIntolistOfNonNull":"2","strIntolist":"1","notNullable":"b","nullable":"a"}""",
    )


def test_variable_with_default_value_multiple_variables_with_default_values_vars_as_lists() raises:
    run_vars(
        default_values_pass,
        VARIABLES_DEFAULT_VALUE_EXTRACTION_DEFINITION,
        """
					query q(
						$nullable: String = "a",
						$notNullable: String = "b",
						$list: [String] = ["1"],
						$listOfNonNull: [String!] = ["2"]
						$listNonNullItemNullable: [String] = ["3"],
						$listNonNullItemNotNull: [String!] = ["4"]
					) {
						complex(input: {
							NotNullable: $notNullable,
							Nullable: $nullable,
							list: $list,
							listOfNonNull: $listOfNonNull
							listNonNullItemNullable: $listNonNullItemNullable,
							listNonNullItemNotNull: $listNonNullItemNotNull,
						})
					}""",
        """
					query q(
						$nullable: String,
						$notNullable: String!,
						$list: [String],
						$listOfNonNull: [String!]
						$listNonNullItemNullable: [String]!,
						$listNonNullItemNotNull: [String!]!
					) {
						complex(input: {
							NotNullable: $notNullable,
							Nullable: $nullable,
							list: $list,
							listOfNonNull: $listOfNonNull
							listNonNullItemNullable: $listNonNullItemNullable,
							listNonNullItemNotNull: $listNonNullItemNotNull,
						})
					}""",
        """""",
        """{"listNonNullItemNotNull":["4"],"listNonNullItemNullable":["3"],"listOfNonNull":["2"],"list":["1"],"notNullable":"b","nullable":"a"}""",
    )


def test_variable_with_default_value_variables_in_lists_object_in_list() raises:
    run_vars(
        default_values_pass,
        VARIABLES_DEFAULT_VALUE_EXTRACTION_DEFINITION,
        """
					query q(
						$nullable: String = "a",
						$notNullable: String = "b",
					) {
						objectInList(input: [{NotNullable: $notNullable, Nullable: $nullable}])
					}""",
        """
					query q(
						$nullable: String,
						$notNullable: String!,
					) {
						objectInList(input: [{NotNullable: $notNullable, Nullable: $nullable}])
					}""",
        """""",
        """{"notNullable":"b","nullable":"a"}""",
    )


def test_variable_with_default_value_variables_in_lists_object_in_nested_list() raises:
    run_vars(
        default_values_pass,
        VARIABLES_DEFAULT_VALUE_EXTRACTION_DEFINITION,
        """
					query q(
						$nullable: String = "a",
						$notNullable: String = "b",
					) {
						objectInNestedList(input: [[{NotNullable: $notNullable, Nullable: $nullable}]])
					}""",
        """
					query q(
						$nullable: String,
						$notNullable: String!,
					) {
						objectInNestedList(input: [[{NotNullable: $notNullable, Nullable: $nullable}]])
					}""",
        """""",
        """{"notNullable":"b","nullable":"a"}""",
    )


def test_variable_with_default_value_variables_in_lists_not_nullable_string_in_nested_list() raises:
    run_vars(
        default_values_pass,
        VARIABLES_DEFAULT_VALUE_EXTRACTION_DEFINITION,
        """
					query q(
						$notNullable: String = "foo",
					) {
						stringInNestedList(input: [["a", $notNullable]])
					}""",
        """
					query q(
						$notNullable: String!,
					) {
						stringInNestedList(input: [["a", $notNullable]])
					}""",
        """""",
        """{"notNullable":"foo"}""",
    )


def test_variable_with_default_value_variables_in_lists_nullable_string_in_nested_list() raises:
    run_vars(
        default_values_pass,
        VARIABLES_DEFAULT_VALUE_EXTRACTION_DEFINITION,
        """
					query q(
						$nullable: String = "foo",
					) {
						nullableStringInNestedList(input: [["a", null, $nullable]])
					}""",
        """
					query q(
						$nullable: String,
					) {
						nullableStringInNestedList(input: [["a", null, $nullable]])
					}""",
        """""",
        """{"nullable":"foo"}""",
    )


def test_mixed_nullable_and_not_nullable_variables() raises:
    run_vars(
        default_values_pass,
        VARIABLES_DEFAULT_VALUE_EXTRACTION_DEFINITION,
        """
			query q(
				$nullable: String = "a",
				$notNullable: String = "b",
			) {
				mixedArgs(a: $nullable, b: $notNullable)
			}""",
        """
			query q(
				$nullable: String,
				$notNullable: String!,
			) {
				mixedArgs(a: $nullable, b: $notNullable)
			}""",
        """""",
        """{"notNullable":"b","nullable":"a"}""",
    )


def test_mixed_default_values_of_field_args_and_variables() raises:
    run_vars(
        default_values_pass,
        VARIABLES_DEFAULT_VALUE_EXTRACTION_DEFINITION,
        """
			mutation simple($a: String = "bar", $b: String = "bazz") {
				mixed(a: $a, b: $b)
			}""",
        """
			mutation simple($a: String, $b: String) {
				mixed(a: $a, b: $b)
			}""",
        """{"a":"aaa"}""",
        """{"b":"bazz","a":"aaa"}""",
    )


def test_variable_with_null_default_value() raises:
    run_vars(
        default_values_pass,
        VARIABLES_DEFAULT_VALUE_EXTRACTION_DEFINITION,
        """
			query q($data: ComplexInput = null) {
				complex(input: $data)
			}""",
        """
			query q($data: ComplexInput) {
				complex(input: $data)
			}""",
        """""",
        """{"data":null}""",
    )


def test_variables_used_in_position_expecting_non_null_value_not_nullable_int_with_default_value() raises:
    run_vars(
        default_values_pass,
        VARIABLES_DEFAULT_VALUE_EXTRACTION_DEFINITION,
        """
			 query q(
				 $input: Int = 4,
			 ) {
				 notNullableInt(input: $input)
			 }""",
        """
			 query q(
				 $input: Int!,
			 ) {
				 notNullableInt(input: $input)
			 }""",
        """""",
        """{"input":4}""",
    )


def test_variables_used_in_position_expecting_non_null_value_not_nullable_int_with_default_value_and_variable_value_exists() raises:
    run_vars(
        default_values_pass,
        VARIABLES_DEFAULT_VALUE_EXTRACTION_DEFINITION,
        """
			 query q(
				 $input: Int = 4,
			 ) {
				 notNullableInt(input: $input)
			 }""",
        """
			 query q(
				 $input: Int!,
			 ) {
				 notNullableInt(input: $input)
			 }""",
        """{"input":6}""",
        """{"input":6}""",
    )


def test_variables_used_in_position_expecting_non_null_value_nullable_string_with_default_value() raises:
    run_vars(
        default_values_pass,
        VARIABLES_DEFAULT_VALUE_EXTRACTION_DEFINITION,
        """
			 query q(
				 $input: String = "DefaultInOperation",
			 ) {
				 notNullableString(input: $input)
			 }""",
        """
			 query q(
				 $input: String!,
			 ) {
				 notNullableString(input: $input)
			 }""",
        """""",
        """{"input":"DefaultInOperation"}""",
    )


def test_variables_used_in_position_expecting_non_null_value_not_nullable_string_with_default_value() raises:
    run_vars(
        default_values_pass,
        VARIABLES_DEFAULT_VALUE_EXTRACTION_DEFINITION,
        """
			 query q(
				 $input: String! = "DefaultInOperation",
			 ) {
				 notNullableString(input: $input)
			 }""",
        """
			 query q(
				 $input: String!,
			 ) {
				 notNullableString(input: $input)
			 }""",
        """""",
        """{"input":"DefaultInOperation"}""",
    )


def test_variables_used_in_position_expecting_non_null_value_not_nullable_string_with_default_value_and_variable_value_exists() raises:
    run_vars(
        default_values_pass,
        VARIABLES_DEFAULT_VALUE_EXTRACTION_DEFINITION,
        """
			 query q(
				 $input: String = "DefaultInOperation",
			 ) {
				 notNullableString(input: $input)
			 }""",
        """
			 query q(
				 $input: String!,
			 ) {
				 notNullableString(input: $input)
			 }""",
        """{"input":"ValueInVariable"}""",
        """{"input":"ValueInVariable"}""",
    )


def test_variables_used_in_directive_argument_expecting_non_null_value_nullable_boolean_with_default_value_and_variable_value_exists() raises:
    run_vars(
        default_values_pass,
        VARIABLES_DEFAULT_VALUE_EXTRACTION_DEFINITION,
        """
			 query q(
				 $flag: Boolean = false,
			 ) {
				 withoutArguments @skip(if: $flag)
			 }""",
        """
			 query q(
				 $flag: Boolean!,
			 ) {
				 withoutArguments @skip(if: $flag)
			 }""",
        """{"flag":true}""",
        """{"flag":true}""",
    )


def test_variables_used_in_directive_argument_expecting_non_null_value_nullable_boolean_used_twice() raises:
    run_vars(
        default_values_pass,
        VARIABLES_DEFAULT_VALUE_EXTRACTION_DEFINITION,
        """
			 query q(
				 $flag: Boolean = false,
			 ) {
				 withoutArguments @skip(if: $flag) @include(if: $flag)
			 }""",
        """
			 query q(
				 $flag: Boolean!,
			 ) {
				 withoutArguments @skip(if: $flag) @include(if: $flag)
			 }""",
        """{"flag":true}""",
        """{"flag":true}""",
    )


def test_variables_used_in_directive_argument_expecting_non_null_value_not_nullable_boolean_with_default_value_and_variable_value_exists() raises:
    run_vars(
        default_values_pass,
        VARIABLES_DEFAULT_VALUE_EXTRACTION_DEFINITION,
        """
			 query q(
				 $flag: Boolean! = false,
			 ) {
				 withoutArguments @skip(if: $flag)
			 }""",
        """
			 query q(
				 $flag: Boolean!,
			 ) {
				 withoutArguments @skip(if: $flag)
			 }""",
        """{"flag":true}""",
        """{"flag":true}""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

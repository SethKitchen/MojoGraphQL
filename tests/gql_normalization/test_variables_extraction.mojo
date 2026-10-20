# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests ported from graphql-go-tools v2
`v2/pkg/astnormalization/variables_extraction_test.go`."""

from _norm import *
from _norm_fixtures import *
from std.testing import TestSuite


def test_simple_http_bin_example() raises:
    run_vars(
        extract_pass,
        VARIABLES_EXTRACTION_DEFINITION,
        """
			mutation HttpBinPost {
			  httpBinPost(input: {foo: "bar"}){
				headers {
				  userAgent
				}
				data {
				  foo
				}
			  }
			}""",
        """
			mutation HttpBinPost($a: HttpBinPostInput){
			  httpBinPost(input: $a){
				headers {
				  userAgent
				}
				data {
				  foo
				}
			  }
			}""",
        """""",
        """{"a":{"foo":"bar"}}""",
    )


def test_enum() raises:
    run_vars(
        extract_pass,
        FORUM_EXAMPLE_SCHEMA,
        """
			mutation EnumOperation {
			  useEnum(simpleEnum: Foo)
			}""",
        """
			mutation EnumOperation($a: SimpleEnum) {
			  useEnum(simpleEnum: $a)
			}""",
        """""",
        """{"a":"Foo"}""",
    )


def test_variables_in_argument() raises:
    run_vars(
        extract_pass,
        VARIABLES_EXTRACTION_DEFINITION,
        """
			mutation HttpBinPost($foo: String!) {
			  httpBinPost(input: {foo: $foo}){
				headers {
				  userAgent
				}
				data {
				  foo
				}
			  }
			}""",
        """
			mutation HttpBinPost($foo: String! $a: HttpBinPostInput) {
			  httpBinPost(input: $a){
				headers {
				  userAgent
				}
				data {
				  foo
				}
			  }
			}""",
        """{"foo":"bar"}""",
        """{"a":{"foo":"bar"},"foo":"bar"}""",
    )


def test_multiple_queries() raises:
    run_vars_pre(
        extract_pass,
        FORUM_EXAMPLE_SCHEMA,
        """
			mutation Register {
			  createUser(input: {user: {id: "jens" username: "jens"}}){
				user {
				  id
				  username
				}
			  }
			}
			mutation CreatePost {
			  createPost(input: {post: {authorId: "jens" title: "my post" body: "my body"}}){
				post {
				  id
				  title
				  body
				  userByAuthorId {
					username
				  }
				}
			  }
			}""",
        """
			mutation Register($a: CreateUserInput) {
			  createUser(input: $a){
				user {
				  id
				  username
				}
			  }
			}""",
        """""",
        """{"a":{"user":{"id":"jens","username":"jens"}}}""",
        [remove_register_pass],
    )


def test_values_on_directives_should_be_ignored() raises:
    run_vars(
        extract_pass,
        FORUM_EXAMPLE_SCHEMA,
        """
			mutation Register($a: CreateUserInput @foo(name: "bar")) {
			  createUser(input: $a){
				user {
				  id
				  username
				}
			  }
			}""",
        """
			mutation Register($a: CreateUserInput @foo(name: "bar")) {
			  createUser(input: $a){
				user {
				  id
				  username
				}
			  }
			}""",
        """""",
        """""",
    )


def test_complex_nesting() raises:
    run_vars(
        extract_pass,
        AUTH_SCHEMA,
        """
			mutation Login ($phoneNumber: String!) {
				Login: postPasswordlessStart(
					postPasswordlessStartInput: {
						applicationId: "123"
						loginId: $phoneNumber
					}
				) {
					code
				}
			}""",
        """
			mutation Login($phoneNumber: String!, $a: postPasswordlessStartInput){
				Login: postPasswordlessStart(postPasswordlessStartInput: $a){
					code
				}
			}""",
        """{"phoneNumber":456}""",
        """{"a":{"applicationId":"123","loginId":456},"phoneNumber":456}""",
    )


def test_complex_nesting_with_existing_variable() raises:
    run_vars(
        extract_pass,
        AUTH_SCHEMA,
        """
			mutation Login ($phoneNumber: String!) {
				Login: postPasswordlessStart(
					postPasswordlessStartInput: {
						applicationId: "123"
						loginId: $phoneNumber
					}
				) {
					code
				}
			}""",
        """
			mutation Login($phoneNumber: String!, $a: postPasswordlessStartInput){
				Login: postPasswordlessStart(postPasswordlessStartInput: $a){
					code
				}
			}""",
        """{"phoneNumber":"456"}""",
        """{"a":{"applicationId":"123","loginId":"456"},"phoneNumber":"456"}""",
    )


def test_complex_nesting_with_deep_nesting() raises:
    run_vars(
        extract_pass,
        AUTH_SCHEMA,
        """
			mutation Login ($phoneNumber: String!) {
				Login: postPasswordlessStart(
					postPasswordlessStartInput: {
						nested: {
							applicationId: "123"
							loginId: $phoneNumber
						}
					}
				) {
					code
				}
			}""",
        """
			mutation Login($phoneNumber: String!, $a: postPasswordlessStartInput){
				Login: postPasswordlessStart(postPasswordlessStartInput: $a){
					code
				}
			}""",
        """{"phoneNumber":"456"}""",
        """{"a":{"nested":{"applicationId":"123","loginId":"456"}},"phoneNumber":"456"}""",
    )


def test_complex_nesting_with_deep_nesting_and_lists() raises:
    run_vars(
        extract_pass,
        AUTH_SCHEMA,
        """
			mutation Login ($phoneNumber: String!) {
				Login: postPasswordlessStartList(
					postPasswordlessStartInput: [{
						nested: {
							applicationId: "123"
							loginId: $phoneNumber
						}
					}]
				) {
					code
				}
			}""",
        """
			mutation Login($phoneNumber: String!, $a: [postPasswordlessStartInput]){
				Login: postPasswordlessStartList(postPasswordlessStartInput: $a){
					code
				}
			}""",
        """{"phoneNumber":"456"}""",
        """{"a":[{"nested":{"applicationId":"123","loginId":"456"}}],"phoneNumber":"456"}""",
    )


def test_complex_nesting_with_variable_in_list() raises:
    run_vars(
        extract_pass,
        AUTH_SCHEMA,
        """
			mutation Login ($input: postPasswordlessStartInput!) {
				Login: postPasswordlessStartList(
					postPasswordlessStartInput: [$input]
				) {
					code
				}
			}""",
        """
			mutation Login($input: postPasswordlessStartInput!, $a: [postPasswordlessStartInput]){
				Login: postPasswordlessStartList(postPasswordlessStartInput: $a){
					code
				}
			}""",
        """{"input":{"applicationId":"1"}}""",
        """{"a":[{"applicationId":"1"}],"input":{"applicationId":"1"}}""",
    )


def test_nested_inline_string() raises:
    run_vars(
        extract_pass,
        NEXUS_SCHEMA,
        """
			mutation Draw ($drawDate: AWSDate!, $play: PlayInput!) {
				AddTicket: addCartItem(
					item: {
						drawDate: $drawDate
						fractional: false
						play: $play
						quantity: 1
						regionGameId: "lucky7|UAE"
					}
				) {
					id
				}
			}""",
        """
			mutation Draw($drawDate: AWSDate!, $play: PlayInput!, $a: AddCartItemInput!){
				AddTicket: addCartItem(item: $a){
					id
				}
			}""",
        """{"drawDate":"today","play":{"pick":["123"]}}""",
        """{"a":{"drawDate":"today","fractional":false,"play":{"pick":["123"]},"quantity":1,"regionGameId":"lucky7|UAE"},"drawDate":"today","play":{"pick":["123"]}}""",
    )


def test_same_string() raises:
    run_vars(
        extract_pass,
        SAME_VARIABLE_EXTRACTION,
        """
			mutation Foo {
				foo(input: {string: "foo"})
				foo(input: {string: "foo"})
			}""",
        """
			mutation Foo($a: FooInput) {
				foo(input: $a)
				foo(input: $a)
			}""",
        """{}""",
        """{"a":{"string":"foo"}}""",
    )


def test_same_string_arg() raises:
    run_vars(
        extract_pass,
        SAME_VARIABLE_EXTRACTION,
        """
			mutation Foo {
				bar(string: "foo")
				bar(string: "foo")
			}""",
        """
			mutation Foo($a: String) {
				bar(string: $a)
				bar(string: $a)
			}""",
        """{}""",
        """{"a":"foo"}""",
    )


def test_same_string_arg_with_user_variables() raises:
    run_vars(
        extract_pass,
        SAME_VARIABLE_EXTRACTION,
        """
			mutation Foo ($another: String) {
				another: bar(string: $another)
				bar(string: "foo")
				bar(string: "foo")
			}""",
        """
			mutation Foo($another: String $a: String) {
				another: bar(string: $another)
				bar(string: $a)
				bar(string: $a)
			}""",
        """{"another":"foo"}""",
        """{"a":"foo","another":"foo"}""",
    )


def test_same_int_arg() raises:
    run_vars(
        extract_pass,
        SAME_VARIABLE_EXTRACTION,
        """
			mutation Foo {
				baz(int: 1)
				baz(int: 1)
			}""",
        """
			mutation Foo($a: Int) {
				baz(int: $a)
				baz(int: $a)
			}""",
        """{}""",
        """{"a":1}""",
    )


def test_same_strings() raises:
    run_vars(
        extract_pass,
        SAME_VARIABLE_EXTRACTION,
        """
			mutation Foo {
				foo(input: {strings: ["foo", "bar"]})
				foo(input: {strings: ["foo", "bar"]})
			}""",
        """
			mutation Foo($a: FooInput) {
				foo(input: $a)
				foo(input: $a)
			}""",
        """{}""",
        """{"a":{"strings":["foo","bar"]}}""",
    )


def test_same_int() raises:
    run_vars(
        extract_pass,
        SAME_VARIABLE_EXTRACTION,
        """
			mutation Foo {
				foo(input: {int: 1})
				foo(input: {int: 1})
			}""",
        """
			mutation Foo($a: FooInput) {
				foo(input: $a)
				foo(input: $a)
			}""",
        """{}""",
        """{"a":{"int":1}}""",
    )


def test_same_ints() raises:
    run_vars(
        extract_pass,
        SAME_VARIABLE_EXTRACTION,
        """
			mutation Foo {
				foo(input: {ints: [1, 2]})
				foo(input: {ints: [1, 2]})
			}""",
        """
			mutation Foo($a: FooInput) {
				foo(input: $a)
				foo(input: $a)
			}""",
        """{}""",
        """{"a":{"ints":[1,2]}}""",
    )


def test_same_float() raises:
    run_vars(
        extract_pass,
        SAME_VARIABLE_EXTRACTION,
        """
			mutation Foo {
				foo(input: {float: 1.1})
				foo(input: {float: 1.1})
			}""",
        """
			mutation Foo($a: FooInput) {
				foo(input: $a)
				foo(input: $a)
			}""",
        """{}""",
        """{"a":{"float":1.1}}""",
    )


def test_same_floats() raises:
    run_vars(
        extract_pass,
        SAME_VARIABLE_EXTRACTION,
        """
			mutation Foo {
				foo(input: {floats: [1.1, 2.2]})
				foo(input: {floats: [1.1, 2.2]})
			}""",
        """
			mutation Foo($a: FooInput) {
				foo(input: $a)
				foo(input: $a)
			}""",
        """{}""",
        """{"a":{"floats":[1.1,2.2]}}""",
    )


def test_same_boolean() raises:
    run_vars(
        extract_pass,
        SAME_VARIABLE_EXTRACTION,
        """
			mutation Foo {
				foo(input: {boolean: true})
				foo(input: {boolean: true})
			}""",
        """
			mutation Foo($a: FooInput) {
				foo(input: $a)
				foo(input: $a)
			}""",
        """{}""",
        """{"a":{"boolean":true}}""",
    )


def test_same_booleans() raises:
    run_vars(
        extract_pass,
        SAME_VARIABLE_EXTRACTION,
        """
			mutation Foo {
				foo(input: {booleans: [true, false]})
				foo(input: {booleans: [true, false]})
			}""",
        """
			mutation Foo($a: FooInput) {
				foo(input: $a)
				foo(input: $a)
			}""",
        """{}""",
        """{"a":{"booleans":[true,false]}}""",
    )


def test_same_id() raises:
    run_vars(
        extract_pass,
        SAME_VARIABLE_EXTRACTION,
        """
			mutation Foo {
				foo(input: {id: "foo"})
				foo(input: {id: "foo"})
			}""",
        """
			mutation Foo($a: FooInput) {
				foo(input: $a)
				foo(input: $a)
			}""",
        """{}""",
        """{"a":{"id":"foo"}}""",
    )


def test_same_ids() raises:
    run_vars(
        extract_pass,
        SAME_VARIABLE_EXTRACTION,
        """
			mutation Foo {
				foo(input: {ids: ["foo", "bar"]})
				foo(input: {ids: ["foo", "bar"]})
			}""",
        """
			mutation Foo($a: FooInput) {
				foo(input: $a)
				foo(input: $a)
			}""",
        """{}""",
        """{"a":{"ids":["foo","bar"]}}""",
    )


def test_same_enum() raises:
    run_vars(
        extract_pass,
        SAME_VARIABLE_EXTRACTION,
        """
			mutation Foo {
				foo(input: {enum: Foo})
				foo(input: {enum: Foo})
			}""",
        """
			mutation Foo($a: FooInput) {
				foo(input: $a)
				foo(input: $a)
			}""",
        """{}""",
        """{"a":{"enum":"Foo"}}""",
    )


def test_same_enums() raises:
    run_vars(
        extract_pass,
        SAME_VARIABLE_EXTRACTION,
        """
			mutation Foo {
				foo(input: {enums: [Foo, Bar]})
				foo(input: {enums: [Foo, Bar]})
			}""",
        """
			mutation Foo($a: FooInput) {
				foo(input: $a)
				foo(input: $a)
			}""",
        """{}""",
        """{"a":{"enums":["Foo","Bar"]}}""",
    )


def test_same_input() raises:
    run_vars(
        extract_pass,
        SAME_VARIABLE_EXTRACTION,
        """
			mutation Foo {
				foo(input: {input: {string: "foo"}})
				foo(input: {input: {string: "foo"}})
			}""",
        """
			mutation Foo($a: FooInput) {
				foo(input: $a)
				foo(input: $a)
			}""",
        """{}""",
        """{"a":{"input":{"string":"foo"}}}""",
    )


def test_same_inputs() raises:
    run_vars(
        extract_pass,
        SAME_VARIABLE_EXTRACTION,
        """
			mutation Foo {
				foo(
					input: {
						inputs: [
							{string: "foo"}
							{string: "bar"}
						]
					}
				)
				foo(
					input: {
						inputs: [
							{string: "foo"}
							{string: "bar"}
						]
					}
				)
			}""",
        """
			mutation Foo($a: FooInput) {
				foo(
					input: $a
				)
				foo(
					input: $a
				)
			}""",
        """{}""",
        """{"a":{"inputs":[{"string":"foo"},{"string":"bar"}]}}""",
    )


def test_same_custom_scalar() raises:
    run_vars(
        extract_pass,
        SAME_VARIABLE_EXTRACTION,
        """
			mutation Foo {
				foo(input: {customScalar: "foo"})
				foo(input: {customScalar: "foo"})
			}""",
        """
			mutation Foo($a: FooInput) {
				foo(input: $a)
				foo(input: $a)
			}""",
        """{}""",
        """{"a":{"customScalar":"foo"}}""",
    )


def test_same_custom_scalars() raises:
    run_vars(
        extract_pass,
        SAME_VARIABLE_EXTRACTION,
        """
			mutation Foo {
				foo(input: {customScalars: ["foo", "bar"]})
				foo(input: {customScalars: ["foo", "bar"]})
			}""",
        """
			mutation Foo($a: FooInput) {
				foo(input: $a)
				foo(input: $a)
			}""",
        """{}""",
        """{"a":{"customScalars":["foo","bar"]}}""",
    )


def test_ignore_user_variables_same_string() raises:
    run_vars(
        extract_pass,
        SAME_VARIABLE_EXTRACTION,
        """
			mutation Foo($fromUser: MyInput!) {
				another: foo(input: $fromUser)
				foo(input: {string: "foo"})
				foo(input: {string: "foo"})
			}""",
        """
			mutation Foo($fromUser: MyInput! $a: FooInput) {
				another: foo(input: $fromUser)
				foo(input: $a)
				foo(input: $a)
			}""",
        """{"fromUser":{"string":"foo"}}""",
        """{"a":{"string":"foo"},"fromUser":{"string":"foo"}}""",
    )


def test_don_t_re_use_same_input_of_different_type() raises:
    run_vars(
        extract_pass,
        SAME_VARIABLE_EXTRACTION,
        """
			mutation Foo {
				foo(input: {string: "foo"})
				bat(input: {string: "foo"})
			}""",
        """
			mutation Foo($a: FooInput $b: SimilarMyInput) {
				foo(input: $a)
				bat(input: $b)
			}""",
        """{}""",
        """{"b":{"string":"foo"},"a":{"string":"foo"}}""",
    )


def test_don_t_re_use_same_nested_input_of_different_type() raises:
    run_vars(
        extract_pass,
        SAME_VARIABLE_EXTRACTION,
        """
			mutation Foo {
				foo(input: {input: {string: "foo"}})
				bat(input: {input: {string: "foo"}})
			}""",
        """
			mutation Foo($a: FooInput $b: SimilarMyInput) {
				foo(input: $a)
				bat(input: $b)
			}""",
        """{}""",
        """{"b":{"input":{"string":"foo"}},"a":{"input":{"string":"foo"}}}""",
    )


def test_file_uploads_arg_has_inline_object_value_with_upload_passed_via_variable() raises:
    run_vars_pre(
        extract_pass,
        """scalar Upload input Input {f: Upload!} type Mutation { hello(arg: Input!): String }""",
        """mutation Foo($i: Upload!) { hello(arg: {f: $i}) }""",
        """mutation Foo($i: Upload!, $a: Input!){hello(arg: $a)}""",
        """{"i":null}""",
        """{"a":{"f":null},"i":null}""",
        [],
    )


def test_file_uploads_arg_has_inline_objects_with_variables_which_have_nested_file_uploads() raises:
    run_vars_pre(
        extract_pass,
        """
					scalar Upload
					input Input {list: [Upload!]! value: Upload!}
					input Input2 {oneList: [Input!]! one: Input!}
					input Input3 {twoList: [Input2!]! two: Input2!}
					type Mutation { hello(arg: Input3!): String }""",
        """mutation Foo($varOne: [Input2!]! $varTwo: Input2!) { hello(arg: {twoList: $varOne two: $varTwo}) }""",
        """mutation Foo($varOne: [Input2!]!, $varTwo: Input2!, $a: Input3!){hello(arg: $a)}""",
        """{"varOne":[{"oneList":[{"list":[null,null],"value":null}],"one":{"list":[null],"value":null}}],"varTwo":{"oneList":[{"list":[null,null],"value":null}],"one":{"list":[null],"value":null}}}""",
        """{"a":{"twoList":[{"oneList":[{"list":[null,null],"value":null}],"one":{"list":[null],"value":null}}],"two":{"oneList":[{"list":[null,null],"value":null}],"one":{"list":[null],"value":null}}},"varOne":[{"oneList":[{"list":[null,null],"value":null}],"one":{"list":[null],"value":null}}],"varTwo":{"oneList":[{"list":[null,null],"value":null}],"one":{"list":[null],"value":null}}}""",
        [],
    )


def test_file_uploads_arg_of_type_upload() raises:
    run_vars_pre(
        extract_pass,
        """scalar Upload type Query { hello(arg: Upload!): String }""",
        """query Foo($bar: Upload!) { hello(arg: $bar) }""",
        """query Foo($bar: Upload!) { hello(arg: $bar) }""",
        """{"bar": null}""",
        """{"bar": null}""",
        [],
    )


def test_file_uploads_arg_has_nested_upload_in_a_variable() raises:
    run_vars_pre(
        extract_pass,
        """scalar Upload input Input {f: Upload!} type Mutation { hello(arg: Input!): String }""",
        """mutation Foo($i: Input!) { hello(arg: $i) }""",
        """mutation Foo($i: Input!) { hello(arg: $i) }""",
        """{"i":{"f":null}}""",
        """{"i":{"f":null}}""",
        [],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

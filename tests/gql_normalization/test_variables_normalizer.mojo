# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests ported from graphql-go-tools v2 `v2/pkg/astnormalization`:
`TestVariablesNormalizer` of `astnormalization_test.go`, and
`uploads/upload_finder_test.go`.

The upload finder test of upstream calls the finder on each field argument
with a walker. `find` does the same for the fields of the operation. The
variables of the last upload test are on one line; the finder reads the
JSON in place, so the white space of upstream would only move the offsets.
"""

from _norm import schema_of
from _norm_fixtures import VARIABLES_EXTRACTION_DEFINITION
from gql_language.ast import Kind, NO_NODE, Role
from gql_language.parser import parse
from gql_normalization.go_printer import print_compact
from gql_normalization.normalize import VariablesNormalizer
from gql_normalization.schema_lookup import root_type
from gql_normalization.uploads import UploadFinder, UploadPathMapping
from std.testing import TestSuite, assert_equal

comptime UPLOAD_SCHEMA = """
			scalar Upload
			input Input {list: [Upload!]! value: Upload!}
			input Input2 {oneList: [Input!]! one: Input!}
			input Input3 {twoList: [Input2!]! two: Input2!}
			type Mutation { hello(arg: Input3!): String }
		"""
"""The schema of the "file uploads" tests."""

comptime NESTED_VARIABLES = (
    '{"varOne":[{"oneList":[{"list":[null,null],"value":null}],"one":{"list":'
    '[null],"value":null}}],"varTwo":{"oneList":[{"list":[null,null],"value":'
    'null}],"one":{"list":[null],"value":null}}}'
)
"""The variables of the "file uploads" tests."""


def lines(mappings: List[UploadPathMapping]) -> String:
    """Write each mapping on a line.

    Args:
        mappings: The mappings.

    Returns:
        `name original new` per line.
    """
    var out = String()
    for ref item in mappings:
        out += String(item) + "\n"
    return out^


def find(
    schema_text: StringSlice, operation: StringSlice, variables: StringSlice
) raises -> String:
    """Find the uploads of each argument of the root fields: upstream
    `runTest` of `upload_finder_test.go`.

    Args:
        schema_text: The SDL.
        operation: The operation.
        variables: The variables JSON.

    Returns:
        The mappings, one per line.

    Raises:
        Error: If a text does not parse.
    """
    var schema = schema_of(schema_text)
    var document = parse(operation)
    var finder = UploadFinder()
    var found = List[UploadPathMapping]()
    var definition = document.first_child(document.root)
    var root = root_type(schema, document, definition)
    var field = document.child(
        document.child(definition, Role.SELECTION_SET), Role.SELECTION
    )
    while field != NO_NODE:
        var field_def = schema.field_named(root, document.name(field))
        var argument = document.child(field, Role.ARGUMENT)
        while argument != NO_NODE and field_def >= 0:
            var input = schema.argument_named(
                field_def, document.name(argument)
            )
            if input >= 0:
                found.extend(
                    finder.find_uploads(
                        document,
                        schema,
                        variables,
                        argument,
                        schema.input_values[input].type,
                    )
                )
            argument = document.next_with_role(argument)
        field = document.next_with_role(field)
    return lines(found)


def test_http_bin_post() raises:
    var schema = schema_of(VARIABLES_EXTRACTION_DEFINITION)
    var document = parse(
        """
			mutation HttpBinPost($foo: String! = "bar" $bar: String! $bazz: String){
			  httpBinPost(input: {foo: $foo bar: $bazz}){
				headers {
				  userAgent
				}
				data {
				  foo
				}
			  }
			}
		"""
    )
    var variables = String("{}")
    _ = VariablesNormalizer().normalize_operation(document, schema, variables)
    assert_equal(
        print_compact(document),
        (
            "mutation HttpBinPost($bar: String!, $a:"
            " HttpBinPostInput){httpBinPost(input: $a){headers {userAgent} data"
            " {foo}}}"
        ),
    )
    assert_equal(variables, '{"a":{"foo":"bar"}}')


def test_file_uploads() raises:
    var schema = schema_of(UPLOAD_SCHEMA)
    var document = parse(
        "mutation Foo($varOne: [Input2!]! $varTwo: Input2!) { hello(arg:"
        " {twoList: $varOne two: $varTwo}) }"
    )
    var variables = String(NESTED_VARIABLES)
    var uploads = VariablesNormalizer().normalize_operation(
        document, schema, variables
    )
    assert_equal(
        print_compact(document), "mutation Foo($a: Input3!){hello(arg: $a)}"
    )
    assert_equal(
        variables,
        '{"a":{"twoList":[{"oneList":[{"list":[null,null],"value":null}],"one":{"list":[null],"value":null}}],"two":{"oneList":[{"list":[null,null],"value":null}],"one":{"list":[null],"value":null}}}}',
    )
    assert_equal(
        lines(uploads),
        "a variables.varOne.0.oneList.0.list.0"
        " variables.a.twoList.0.oneList.0.list.0\n"
        + "a variables.varOne.0.oneList.0.list.1"
        " variables.a.twoList.0.oneList.0.list.1\n"
        + "a variables.varOne.0.oneList.0.value"
        " variables.a.twoList.0.oneList.0.value\n"
        + "a variables.varOne.0.one.list.0 variables.a.twoList.0.one.list.0\n"
        + "a variables.varOne.0.one.value variables.a.twoList.0.one.value\n"
        + "a variables.varTwo.oneList.0.list.0"
        " variables.a.two.oneList.0.list.0\n"
        + "a variables.varTwo.oneList.0.list.1"
        " variables.a.two.oneList.0.list.1\n"
        + "a variables.varTwo.oneList.0.value variables.a.two.oneList.0.value\n"
        + "a variables.varTwo.one.list.0 variables.a.two.one.list.0\n"
        + "a variables.varTwo.one.value variables.a.two.one.value\n",
    )


def test_no_uploads_in_a_query() raises:
    assert_equal(
        find(
            "type Query { hello(arg: String!): String }",
            "query Foo($bar: String!) { hello }",
            "{}",
        ),
        "",
    )


def test_top_level_variable_arg_of_type_upload() raises:
    assert_equal(
        find(
            "scalar Upload type Query { hello(arg: Upload!): String }",
            "query Foo($bar: Upload!) { hello(arg: $bar) }",
            '{"bar": null}',
        ),
        "bar variables.bar \n",
    )


def test_top_level_variable_arg_has_nested_upload() raises:
    assert_equal(
        find(
            (
                "scalar Upload input Input {f: Upload!} type Mutation {"
                " hello(arg: Input!): String }"
            ),
            "mutation Foo($i: Input!) { hello(arg: $i) }",
            '{"i":{"f":null}}',
        ),
        "i variables.i.f \n",
    )


def test_top_level_variable_arg_has_nested_uploads() raises:
    assert_equal(
        find(
            (
                "scalar Upload input Input {f: Upload! f2: Upload!} type"
                " Mutation { hello(arg: Input!): String }"
            ),
            "mutation Foo($i: Input!) { hello(arg: $i) }",
            '{"i":{"f":null,"f2":null}}',
        ),
        "i variables.i.f \ni variables.i.f2 \n",
    )


def test_top_level_variable_arg_has_nested_uploads_in_a_list() raises:
    assert_equal(
        find(
            (
                "scalar Upload input Input {f: [Upload!]! f2: [Upload!]!} type"
                " Mutation { hello(arg: Input!): String }"
            ),
            "mutation Foo($i: Input!) { hello(arg: $i) }",
            '{"i":{"f":[null],"f2":[null,null,null]}}',
        ),
        "i variables.i.f.0 \ni variables.i.f2.0 \ni variables.i.f2.1 \n"
        + "i variables.i.f2.2 \n",
    )


def test_inline_object_value_with_upload_passed_via_variable() raises:
    assert_equal(
        find(
            (
                "scalar Upload input Input {f: Upload!} type Mutation {"
                " hello(arg: Input!): String }"
            ),
            "mutation Foo($i: Upload!) { hello(arg: {f: $i}) }",
            '{"i":null}',
        ),
        "i variables.i f\n",
    )


def test_inline_objects_with_variables_which_have_nested_file_uploads() raises:
    assert_equal(
        find(
            UPLOAD_SCHEMA,
            (
                "mutation Foo($varOne: [Input2!]! $varTwo: Input2!) {"
                " hello(arg: {twoList: $varOne two: $varTwo}) }"
            ),
            NESTED_VARIABLES,
        ),
        "varOne variables.varOne.0.oneList.0.list.0"
        " twoList.0.oneList.0.list.0\n"
        + "varOne variables.varOne.0.oneList.0.list.1"
        " twoList.0.oneList.0.list.1\n"
        + "varOne variables.varOne.0.oneList.0.value"
        " twoList.0.oneList.0.value\n"
        + "varOne variables.varOne.0.one.list.0 twoList.0.one.list.0\n"
        + "varOne variables.varOne.0.one.value twoList.0.one.value\n"
        + "varTwo variables.varTwo.oneList.0.list.0 two.oneList.0.list.0\n"
        + "varTwo variables.varTwo.oneList.0.list.1 two.oneList.0.list.1\n"
        + "varTwo variables.varTwo.oneList.0.value two.oneList.0.value\n"
        + "varTwo variables.varTwo.one.list.0 two.one.list.0\n"
        + "varTwo variables.varTwo.one.value two.one.value\n",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

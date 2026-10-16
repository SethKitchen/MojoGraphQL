# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests beyond upstream for the directive, argument and value rules: they
cover the type definitions, directive definitions and extensions that an
executable validation also walks, the directives that the document defines,
the meta fields, long argument lists and the 32-bit range of `Int`.

The expected errors come from graphql-js 16.14.2 `validate` with the same
schema, document and rule.
"""

from _harness import (
    expect_errors,
    expect_errors_with_schema,
    expect_valid,
    expect_valid_with_schema,
    format_errors,
    schema_of,
    test_schema,
)
from gql_language.parser import ParseOptions, parse
from gql_validation.rules import ValidationRule
from gql_validation.validate import validate
from std.testing import TestSuite, assert_equal


def expect_experimental_errors(
    rule: ValidationRule, query: String, expected: List[String]
) raises:
    """Check the errors of one rule over a document that can have
    directives on directive definitions.

    Args:
        rule: The rule.
        query: The document.
        expected: The formatted errors, in order.

    Raises:
        Error: When the errors differ.
    """
    var options = ParseOptions()
    options.experimental_directives_on_directive_definitions = True
    var document = parse(query, options)
    var want = String("")
    for index in range(len(expected)):
        if index > 0:
            want += "\n"
        want += expected[index]
    assert_equal(format_errors(validate(test_schema(), document, [rule])), want)


def test_known_directives_on_type_system_locations() raises:
    expect_errors(
        ValidationRule.KNOWN_DIRECTIVES,
        (
            "directive @d on FIELD\n"
            "schema @d { query: QueryRoot }\n"
            "extend schema @d\n"
            "scalar S @d\n"
            "extend scalar S @d\n"
            "type O @d { f(a: Int @d): Int @d }\n"
            "extend type O @d\n"
            "interface I @d\n"
            "extend interface I @d\n"
            "union U @d\n"
            "extend union U @d\n"
            "enum E @d { V @d }\n"
            "extend enum E @d\n"
            "input In @d { f: Int @d }\n"
            "extend input In @d { g: Int @d }\n"
            "directive @x(a: Int @d) on FIELD\n"
            "{ dog @d }"
        ),
        [
            'Directive "@d" may not be used on SCHEMA. (2:8)',
            'Directive "@d" may not be used on SCHEMA. (3:15)',
            'Directive "@d" may not be used on SCALAR. (4:10)',
            'Directive "@d" may not be used on SCALAR. (5:17)',
            'Directive "@d" may not be used on OBJECT. (6:8)',
            'Directive "@d" may not be used on ARGUMENT_DEFINITION. (6:22)',
            'Directive "@d" may not be used on FIELD_DEFINITION. (6:31)',
            'Directive "@d" may not be used on OBJECT. (7:15)',
            'Directive "@d" may not be used on INTERFACE. (8:13)',
            'Directive "@d" may not be used on INTERFACE. (9:20)',
            'Directive "@d" may not be used on UNION. (10:9)',
            'Directive "@d" may not be used on UNION. (11:16)',
            'Directive "@d" may not be used on ENUM. (12:8)',
            'Directive "@d" may not be used on ENUM_VALUE. (12:15)',
            'Directive "@d" may not be used on ENUM. (13:15)',
            'Directive "@d" may not be used on INPUT_OBJECT. (14:10)',
            'Directive "@d" may not be used on INPUT_FIELD_DEFINITION. (14:22)',
            'Directive "@d" may not be used on INPUT_OBJECT. (15:17)',
            'Directive "@d" may not be used on ARGUMENT_DEFINITION. (15:29)',
            'Directive "@d" may not be used on ARGUMENT_DEFINITION. (16:21)',
        ],
    )


def test_known_directives_on_directive_definitions() raises:
    expect_experimental_errors(
        ValidationRule.KNOWN_DIRECTIVES,
        (
            "directive @d on FIELD\n"
            "directive @y @d on FIELD\n"
            "extend directive @y @d"
        ),
        [
            'Directive "@d" may not be used on DIRECTIVE_DEFINITION. (2:14)',
            'Directive "@d" may not be used on DIRECTIVE_DEFINITION. (3:21)',
        ],
    )


def test_known_directives_defined_in_document() raises:
    expect_experimental_errors(
        ValidationRule.KNOWN_DIRECTIVES,
        (
            "directive @d on DIRECTIVE_DEFINITION\n"
            "directive @y @d on FIELD\n"
            "extend directive @y @d\n"
            "{ dog @d }"
        ),
        ['Directive "@d" may not be used on FIELD. (4:7)'],
    )


def test_unique_directives_on_type_system_locations() raises:
    expect_experimental_errors(
        ValidationRule.UNIQUE_DIRECTIVES_PER_LOCATION,
        (
            "directive @d on FIELD | OBJECT | SCHEMA | DIRECTIVE_DEFINITION\n"
            "directive @r repeatable on FIELD | OBJECT\n"
            "schema @d { query: QueryRoot }\n"
            "extend schema @d\n"
            "type O @d @r\n"
            "extend type O @d @r\n"
            "type P @d\n"
            "directive @y @d on FIELD\n"
            "extend directive @y @d\n"
            "directive @z @d on FIELD\n"
            "{ dog @d @r @r }"
        ),
        [
            (
                'The directive "@d" can only be used once at this location.'
                " (3:8, 4:15)"
            ),
            (
                'The directive "@d" can only be used once at this location.'
                " (5:8, 6:15)"
            ),
            (
                'The directive "@d" can only be used once at this location.'
                " (8:14, 9:21)"
            ),
        ],
    )


def test_unique_directives_document_makes_repeatable() raises:
    expect_valid(
        ValidationRule.UNIQUE_DIRECTIVES_PER_LOCATION,
        "directive @onField repeatable on FIELD\n{ dog @onField @onField }",
    )


def test_known_argument_names_of_document_directives() raises:
    expect_errors(
        ValidationRule.KNOWN_ARGUMENT_NAMES,
        (
            "directive @d(arg: Int, other: String) on FIELD\n"
            "directive @n on FIELD\n"
            '{ dog @d(other: "a", arg: 1, ar: 2) @n(a: 1) @unknown(a: 1) }'
        ),
        [
            (
                'Unknown argument "ar" on directive "@d". Did you mean "arg"?'
                " (3:30)"
            ),
            'Unknown argument "a" on directive "@n". (3:40)',
        ],
    )


def test_known_argument_names_of_meta_fields() raises:
    expect_errors(
        ValidationRule.KNOWN_ARGUMENT_NAMES,
        (
            "{ __typename(x: 1) __schema(x: 1) { queryType { name } }"
            ' __type(name: "Dog", nam: "a") { name } }'
        ),
        [
            'Unknown argument "x" on field "QueryRoot.__typename". (1:14)',
            'Unknown argument "x" on field "QueryRoot.__schema". (1:29)',
            (
                'Unknown argument "nam" on field "QueryRoot.__type". Did you'
                ' mean "name"? (1:78)'
            ),
        ],
    )


def test_unique_argument_names_of_a_long_list() raises:
    expect_errors(
        ValidationRule.UNIQUE_ARGUMENT_NAMES,
        (
            "{ dog @onField(a: 1, b: 2, c: 3, a: 4, d: 5, e: 6, f: 7, g: 8, a:"
            " 9) }"
        ),
        ['There can be only one argument named "a". (1:16, 1:34, 1:64)'],
    )


def test_provided_arguments_of_document_directives() raises:
    expect_errors(
        ValidationRule.PROVIDED_REQUIRED_ARGUMENTS,
        (
            "directive @d(a: Int!, b: Int! = 1, c: Int, a: String!, e: Int!)"
            " on FIELD\n"
            "directive @n on FIELD\n"
            "{ dog @d(e: 1) @n @onField @include @unknown"
            ' { name @d(a: "x", e: 1) } }'
        ),
        [
            (
                'Directive "@d" argument "a" of type "String!" is required,'
                " but it was not provided. (3:7)"
            ),
            (
                'Directive "@include" argument "if" of type "Boolean!" is'
                " required, but it was not provided. (3:28)"
            ),
        ],
    )


def test_provided_arguments_of_schema_directive_with_defaults() raises:
    var schema = schema_of(
        "type Query { f: Int }\n"
        "directive @opt(a: Int, b: Int! = 1, c: Int!) on FIELD"
    )
    var rule = ValidationRule.PROVIDED_REQUIRED_ARGUMENTS
    expect_errors_with_schema(
        schema,
        rule,
        "{ f @opt }",
        [
            (
                'Directive "@opt" argument "c" of type "Int!" is required,'
                " but it was not provided. (1:5)"
            ),
        ],
    )
    expect_valid_with_schema(schema, rule, "{ f @opt(c: 1) }")


def test_provided_arguments_of_meta_fields() raises:
    expect_errors(
        ValidationRule.PROVIDED_REQUIRED_ARGUMENTS,
        '{ __typename __type { name } t: __type(name: "Dog") { name } }',
        [
            (
                'Field "__type" argument "name" of type "String!" is required,'
                " but it was not provided. (1:14)"
            ),
        ],
    )


def test_int_at_the_edges_of_the_32_bit_range() raises:
    expect_errors(
        ValidationRule.VALUES_OF_CORRECT_TYPE,
        (
            "{ complicatedArgs { a: intArgField(intArg: 2147483647)"
            " b: intArgField(intArg: 2147483648)"
            " c: intArgField(intArg: -2147483648)"
            " d: intArgField(intArg: -2147483649) } }"
        ),
        [
            (
                "Int cannot represent non 32-bit signed integer value:"
                " 2147483648 (1:79)"
            ),
            (
                "Int cannot represent non 32-bit signed integer value:"
                " -2147483649 (1:150)"
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

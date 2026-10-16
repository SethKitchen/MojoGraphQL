# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_schema.sdl_validation` as a whole: `validate_sdl`,
`assert_valid_sdl` and `assert_valid_sdl_extension` of graphql-js 16.14.2
`src/validation/validate.ts`, with all the rules at once.

graphql-js has no test of its own for these functions; its rule tests run
one rule each. These tests check the order of errors across rules, several
documents, and the cases the rule tests do not reach.
"""

from _sdl_harness import (
    ALL_RULES,
    expect_sdl,
    expect_valid_sdl,
    format_errors,
    parse_sdl,
)
from gql_language.ast import Document
from gql_schema.build import build_schema
from gql_schema.sdl_validation import (
    SDLRule,
    assert_valid_sdl,
    assert_valid_sdl_extension,
    specified_sdl_rules,
    validate_sdl,
    validate_sdl_with_rules,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def documents_of(first: String, second: String = "") raises -> List[Document]:
    """Parse one or two SDL documents."""
    var documents = List[Document]()
    documents.append(parse_sdl(first))
    if second != "":
        documents.append(parse_sdl(second))
    return documents^


def test_rules_are_in_graphql_js_order() raises:
    var rules = specified_sdl_rules()
    assert_equal(len(rules), 15)
    var names = String("")
    for rule in rules:
        names += String(rule) + " "
    assert_equal(
        names,
        (
            "LoneSchemaDefinitionRule UniqueOperationTypesRule"
            " UniqueTypeNamesRule UniqueEnumValueNamesRule"
            " UniqueFieldDefinitionNamesRule"
            " UniqueArgumentDefinitionNamesRule UniqueDirectiveNamesRule"
            " KnownTypeNamesRule KnownDirectivesRule"
            " UniqueDirectivesPerLocationRule PossibleTypeExtensionsRule"
            " KnownArgumentNamesOnDirectivesRule UniqueArgumentNamesRule"
            " UniqueInputFieldNamesRule"
            " ProvidedRequiredArgumentsOnDirectivesRule "
        ),
    )


def test_an_invalid_rule_has_no_name() raises:
    assert_true(SDLRule.PROVIDED_REQUIRED_ARGUMENTS_ON_DIRECTIVES.is_valid())
    assert_false(SDLRule(15).is_valid())
    assert_equal(String(SDLRule(15)), "<invalid>")


def test_errors_of_all_rules_come_in_visit_order() raises:
    expect_sdl(
        ALL_RULES,
        """type Query {
  a: Unknown @unknown
}
type Query
extend type Missing @skip
directive @d(x: Int, x: Int) on FIELD
""",
        [
            'Unknown type "Unknown". (2:6)',
            'Unknown directive "@unknown". (2:14)',
            'There can be only one type named "Query". (1:6, 4:6)',
            'Cannot extend type "Missing" because it is not defined. (5:13)',
            'Directive "@skip" may not be used on OBJECT. (5:21)',
            (
                'Directive "@skip" argument "if" of type "Boolean!" is'
                " required, but it was not provided. (5:21)"
            ),
            'Argument "@d(x:)" can only be defined once. (6:14, 6:22)',
        ],
    )


def test_valid_sdl_has_no_errors() raises:
    var errors = validate_sdl(documents_of("type Query { a: String }"))
    assert_equal(len(errors), 0)


def test_no_document_has_no_errors() raises:
    assert_equal(len(validate_sdl(List[Document]())), 0)


def test_no_rule_finds_no_error() raises:
    var errors = validate_sdl_with_rules(
        documents_of("type A type A"), List[SDLRule]()
    )
    assert_equal(len(errors), 0)


def test_documents_are_checked_as_one() raises:
    var errors = validate_sdl(documents_of("type A", "\n  type A"))
    assert_equal(
        format_errors(errors),
        'There can be only one type named "A". (1:6, 2:8)',
    )
    assert_equal(len(errors[0].locations), 2)


def test_validate_sdl_extends_a_schema() raises:
    var schema = build_schema("type Query { a: Int }")
    var errors = validate_sdl(
        documents_of("extend type Query { b: Int }"), schema
    )
    assert_equal(len(errors), 0)
    errors = validate_sdl(documents_of("extend type Query { a: Int }"), schema)
    assert_equal(
        format_errors(errors),
        (
            'Field "Query.a" already exists in the schema. It cannot also be'
            " defined in this type extension. (1:21)"
        ),
    )


def test_assert_valid_sdl_passes_valid_sdl() raises:
    assert_valid_sdl(documents_of("type Query { a: String }"))


def test_assert_valid_sdl_joins_the_messages() raises:
    var message = String("")
    try:
        assert_valid_sdl(documents_of("type A type A scalar S @unknown"))
    except error:
        message = String(error)
    assert_equal(
        message,
        (
            'There can be only one type named "A".\n\nUnknown directive'
            ' "@unknown".'
        ),
    )


def test_assert_valid_sdl_extension() raises:
    var schema = build_schema("type Query { a: Int }")
    assert_valid_sdl_extension(documents_of("type Other"), schema)
    var message = String("")
    try:
        assert_valid_sdl_extension(documents_of("type Query"), schema)
    except error:
        message = String(error)
    assert_equal(
        message,
        (
            'Type "Query" already exists in the schema. It cannot also be'
            " defined in this type definition."
        ),
    )


def test_directives_on_directive_definitions_and_extensions() raises:
    expect_sdl(
        SDLRule.KNOWN_DIRECTIVES,
        """directive @onDir on DIRECTIVE_DEFINITION
directive @a @onDir @skip on FIELD
extend directive @a @onDir @include
""",
        [
            'Directive "@skip" may not be used on DIRECTIVE_DEFINITION. (2:21)',
            (
                'Directive "@include" may not be used on'
                " DIRECTIVE_DEFINITION. (3:28)"
            ),
        ],
        experimental=True,
    )


def test_a_field_of_an_input_extension_is_an_argument_definition() raises:
    # graphql-js looks for an input object definition only.
    expect_sdl(
        SDLRule.KNOWN_DIRECTIVES,
        """directive @f on INPUT_FIELD_DEFINITION
input I { a: Int @f }
extend input I { b: Int @f }
""",
        ['Directive "@f" may not be used on ARGUMENT_DEFINITION. (3:25)'],
    )


def test_the_last_required_argument_of_a_name_wins() raises:
    expect_sdl(
        SDLRule.PROVIDED_REQUIRED_ARGUMENTS_ON_DIRECTIVES,
        """directive @d(a: Int!, a: [String!]!, b: Int! = 1, c: Int!) on FIELD_DEFINITION
type Query { f: Int @d(b: 2) }
""",
        [
            (
                'Directive "@d" argument "a" of type "[String!]!" is'
                " required, but it was not provided. (2:21)"
            ),
            (
                'Directive "@d" argument "c" of type "Int!" is required,'
                " but it was not provided. (2:21)"
            ),
        ],
    )


def test_unknown_argument_of_a_directive_without_arguments() raises:
    expect_sdl(
        SDLRule.KNOWN_ARGUMENT_NAMES_ON_DIRECTIVES,
        "input I @oneOf(x: 1) { a: Int }",
        ['Unknown argument "x" on directive "@oneOf". (1:16)'],
    )


def test_all_rules_pass_a_valid_extension() raises:
    expect_valid_sdl(
        ALL_RULES,
        "extend type Query { b: Int }",
        schema_sdl="type Query { a: Int }",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

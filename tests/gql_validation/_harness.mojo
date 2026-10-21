# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Test helpers for validation, ported from graphql-js 16.14.2
`src/validation/__tests__/harness.ts`: `testSchema`,
`expectValidationErrors` and `expectValidationErrorsWithSchema`.

An error prints as `message (line:column, line:column)`, one error per line,
so a test compares the messages, the locations and the order at once.
"""

from gql_language.ast import Document
from gql_language.error import GraphQLError
from gql_language.parser import ParseOptions, parse
from gql_schema.build import BuildOptions, build_schema
from gql_schema.definition import Schema
from gql_validation.rules import ValidationRule, specified_rules
from gql_validation.validate import ValidationOptions, validate
from std.testing import assert_equal

comptime ALL_RULES = ValidationRule(255)
"""Run every specified rule, as `validate` does by default."""

comptime TEST_SCHEMA = """
  interface Mammal {
    mother: Mammal
    father: Mammal
  }

  interface Pet {
    name(surname: Boolean): String
  }

  interface Canine implements Mammal {
    name(surname: Boolean): String
    mother: Canine
    father: Canine
  }

  enum DogCommand {
    SIT
    HEEL
    DOWN
  }

  type Dog implements Pet & Mammal & Canine {
    name(surname: Boolean): String
    nickname: String
    barkVolume: Int
    barks: Boolean
    doesKnowCommand(dogCommand: DogCommand): Boolean
    isHouseTrained(atOtherHomes: Boolean = true): Boolean
    isAtLocation(x: Int, y: Int): Boolean
    mother: Dog
    father: Dog
  }

  type Cat implements Pet {
    name(surname: Boolean): String
    nickname: String
    meows: Boolean
    meowsVolume: Int
    furColor: FurColor
  }

  union CatOrDog = Cat | Dog

  type Human {
    name(surname: Boolean): String
    pets: [Pet]
    relatives: [Human]
  }

  enum FurColor {
    BROWN
    BLACK
    TAN
    SPOTTED
    NO_FUR
    UNKNOWN
  }

  input ComplexInput {
    requiredField: Boolean!
    nonNullField: Boolean! = false
    intField: Int
    stringField: String
    booleanField: Boolean
    stringListField: [String]
  }

  input OneOfInput @oneOf {
    stringField: String
    intField: Int
  }

  type ComplicatedArgs {
    # TODO List
    # TODO Coercion
    # TODO NotNulls
    intArgField(intArg: Int): String
    nonNullIntArgField(nonNullIntArg: Int!): String
    stringArgField(stringArg: String): String
    booleanArgField(booleanArg: Boolean): String
    enumArgField(enumArg: FurColor): String
    floatArgField(floatArg: Float): String
    idArgField(idArg: ID): String
    stringListArgField(stringListArg: [String]): String
    stringListNonNullArgField(stringListNonNullArg: [String!]): String
    complexArgField(complexArg: ComplexInput): String
    oneOfArgField(oneOfArg: OneOfInput): String
    multipleReqs(req1: Int!, req2: Int!): String
    nonNullFieldWithDefault(arg: Int! = 0): String
    multipleOpts(opt1: Int = 0, opt2: Int = 0): String
    multipleOptAndReq(req1: Int!, req2: Int!, opt1: Int = 0, opt2: Int = 0): String
  }

  type QueryRoot {
    human(id: ID): Human
    dog: Dog
    cat: Cat
    pet: Pet
    catOrDog: CatOrDog
    complicatedArgs: ComplicatedArgs
  }

  schema {
    query: QueryRoot
  }

  directive @onField on FIELD
"""
"""The SDL of graphql-js `testSchema`."""


def test_schema() raises -> Schema:
    """Build graphql-js `testSchema`.

    Returns:
        The schema.

    Raises:
        Error: Never; the SDL is valid.
    """
    return build_schema(TEST_SCHEMA)


comptime DEFER_STREAM_SDL = """
  directive @defer(if: Boolean! = true, label: String) on FRAGMENT_SPREAD | INLINE_FRAGMENT

  directive @stream(initialCount: Int! = 0, if: Boolean! = true, label: String) on FIELD
"""
"""The SDL of graphql-js v17.0.2 `GraphQLDeferDirective` and
`GraphQLStreamDirective`, which are not specified directives."""


def incremental_test_schema() raises -> Schema:
    """Build graphql-js v17.0.2 `testSchema`, with `@defer` and `@stream`.

    The 17 schema differs from the 16 schema in two places:
    `Human.relatives` is `[Human]!`, and `Dog` has the field
    `distanceFrom(loc: GeoPoint): Float` of the scalar `GeoPoint`. The
    `@defer` and `@stream` rules do not need the directives in the schema,
    but a client schema defines them.

    Returns:
        The schema.

    Raises:
        Error: Never; the SDL is valid.
    """
    var sdl = (
        String(TEST_SCHEMA)
        .replace("relatives: [Human]\n", "relatives: [Human]!\n")
        .replace(
            "  type Dog implements",
            "  scalar GeoPoint\n\n  type Dog implements",
        )
        .replace(
            "    isAtLocation(x: Int, y: Int): Boolean\n",
            (
                "    isAtLocation(x: Int, y: Int): Boolean\n"
                "    distanceFrom(loc: GeoPoint): Float\n"
            ),
        )
    )
    return build_schema(sdl + DEFER_STREAM_SDL)


def schema_of(sdl: String) raises -> Schema:
    """Build a schema from SDL, as graphql-js `buildSchema`.

    Args:
        sdl: The SDL.

    Returns:
        The schema.

    Raises:
        Error: When the SDL is not valid.
    """
    return build_schema(sdl)


def format_errors(errors: List[GraphQLError]) -> String:
    """Return errors as `message (line:column, ...)` lines.

    Args:
        errors: The errors.

    Returns:
        One line per error.
    """
    var out = String("")
    for index in range(len(errors)):
        if index > 0:
            out += "\n"
        out += errors[index].message + " ("
        ref locations = errors[index].locations
        for at in range(len(locations)):
            if at > 0:
                out += ", "
            out += (
                String(locations[at].line) + ":" + String(locations[at].column)
            )
        out += ")"
    return out^


def parse_query(
    query: String, legacy_fragment_variables: Bool = False
) raises -> Document:
    """Parse a document, with a plain `Error` on failure.

    Args:
        query: The GraphQL text.
        legacy_fragment_variables: graphql-js `allowLegacyFragmentVariables`.

    Returns:
        The document.

    Raises:
        Error: A syntax error.
    """
    var options = ParseOptions()
    options.allow_legacy_fragment_variables = legacy_fragment_variables
    try:
        return parse(query, options)
    except error:
        raise Error(String(error))


def errors_with_schema(
    schema: Schema,
    rule: ValidationRule,
    query: String,
    legacy_fragment_variables: Bool = False,
) raises -> String:
    """Run one rule, or all, over a document, as graphql-js
    `expectValidationErrorsWithSchema`.

    Args:
        schema: The schema.
        rule: The rule, or `ALL_RULES`.
        query: The document.
        legacy_fragment_variables: Parse variables on fragments.

    Returns:
        The errors, formatted by `format_errors`.

    Raises:
        Error: A syntax error.
    """
    var rules = List[ValidationRule]()
    if rule == ALL_RULES:
        rules = specified_rules()
    else:
        rules.append(rule)
    var document = parse_query(query, legacy_fragment_variables)
    return format_errors(validate(schema, document, rules))


def _joined(expected: List[String]) -> String:
    """Join expected error lines."""
    var want = String("")
    for index in range(len(expected)):
        if index > 0:
            want += "\n"
        want += expected[index]
    return want^


def expect_errors_with_schema(
    schema: Schema,
    rule: ValidationRule,
    query: String,
    expected: List[String],
    legacy_fragment_variables: Bool = False,
) raises:
    """Check the errors of one rule over a document and a schema.

    Args:
        schema: The schema.
        rule: The rule, or `ALL_RULES`.
        query: The document.
        expected: The formatted errors, in order.
        legacy_fragment_variables: Parse variables on fragments.

    Raises:
        Error: When the errors differ.
    """
    assert_equal(
        errors_with_schema(schema, rule, query, legacy_fragment_variables),
        _joined(expected),
    )


def expect_valid_with_schema(
    schema: Schema,
    rule: ValidationRule,
    query: String,
    legacy_fragment_variables: Bool = False,
) raises:
    """Check that one rule finds no error in a document.

    Args:
        schema: The schema.
        rule: The rule, or `ALL_RULES`.
        query: The document.
        legacy_fragment_variables: Parse variables on fragments.

    Raises:
        Error: When there is an error.
    """
    assert_equal(
        errors_with_schema(schema, rule, query, legacy_fragment_variables), ""
    )


def expect_errors(
    rule: ValidationRule,
    query: String,
    expected: List[String],
    legacy_fragment_variables: Bool = False,
) raises:
    """Check the errors of one rule over a document, against `testSchema`,
    as graphql-js `expectValidationErrors`.

    Args:
        rule: The rule, or `ALL_RULES`.
        query: The document.
        expected: The formatted errors, in order.
        legacy_fragment_variables: Parse variables on fragments.

    Raises:
        Error: When the errors differ.
    """
    expect_errors_with_schema(
        test_schema(), rule, query, expected, legacy_fragment_variables
    )


def expect_valid(
    rule: ValidationRule, query: String, legacy_fragment_variables: Bool = False
) raises:
    """Check that one rule finds no error in a document, against
    `testSchema`.

    Args:
        rule: The rule, or `ALL_RULES`.
        query: The document.
        legacy_fragment_variables: Parse variables on fragments.

    Raises:
        Error: When there is an error.
    """
    expect_valid_with_schema(
        test_schema(), rule, query, legacy_fragment_variables
    )

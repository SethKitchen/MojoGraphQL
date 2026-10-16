# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Test helpers for SDL validation: graphql-js test
`expectSDLValidationErrors`.

An error prints as `message (line:column, line:column)`, one error per line,
so a test compares the messages, the locations and the order at once.
"""

from gql_language.ast import Document
from gql_language.error import GraphQLError
from gql_language.parser import ParseOptions, parse
from gql_schema.build import build_schema
from gql_schema.sdl_validation import (
    SDLRule,
    specified_sdl_rules,
    validate_sdl_with_rules,
)
from std.testing import assert_equal

comptime ALL_RULES = SDLRule(255)
"""Run every specified rule, as `validate_sdl` does."""


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


def parse_sdl(sdl: String, experimental: Bool = False) raises -> Document:
    """Parse SDL, with directives on directive definitions when asked.

    Args:
        sdl: The SDL.
        experimental: graphql-js `experimentalDirectivesOnDirectiveDefinitions`.

    Returns:
        The document.

    Raises:
        Error: A syntax error.
    """
    var options = ParseOptions()
    options.experimental_directives_on_directive_definitions = experimental
    try:
        return parse(sdl, options)
    except error:
        raise Error(String(error))


def sdl_errors(
    rule: SDLRule,
    sdl: String,
    schema_sdl: String = "",
    experimental: Bool = False,
) raises -> String:
    """Run one rule, or all, over SDL, as graphql-js
    `expectSDLValidationErrors`.

    Args:
        rule: The rule, or `ALL_RULES`.
        sdl: The SDL to check.
        schema_sdl: The SDL of the schema to extend; empty for none.
        experimental: Parse directives on directive definitions.

    Returns:
        The errors, formatted by `format_errors`.

    Raises:
        Error: A syntax error, or a schema that does not build.
    """
    var rules = List[SDLRule]()
    if rule == ALL_RULES:
        rules = specified_sdl_rules()
    else:
        rules.append(rule)
    var documents = List[Document]()
    documents.append(parse_sdl(sdl, experimental))
    if schema_sdl == "":
        return format_errors(validate_sdl_with_rules(documents, rules^))
    var schema = build_schema(schema_sdl)
    return format_errors(validate_sdl_with_rules(documents, schema, rules^))


def expect_sdl(
    rule: SDLRule,
    sdl: String,
    expected: List[String],
    schema_sdl: String = "",
    experimental: Bool = False,
) raises:
    """Check the errors of one rule, or all, over SDL.

    Args:
        rule: The rule, or `ALL_RULES`.
        sdl: The SDL to check.
        expected: The formatted errors, in order.
        schema_sdl: The SDL of the schema to extend; empty for none.
        experimental: Parse directives on directive definitions.

    Raises:
        Error: When the errors differ.
    """
    var want = String("")
    for index in range(len(expected)):
        if index > 0:
            want += "\n"
        want += expected[index]
    assert_equal(sdl_errors(rule, sdl, schema_sdl, experimental), want)


def expect_valid_sdl(
    rule: SDLRule,
    sdl: String,
    schema_sdl: String = "",
    experimental: Bool = False,
) raises:
    """Check that one rule, or all, finds no error in SDL.

    Args:
        rule: The rule, or `ALL_RULES`.
        sdl: The SDL to check.
        schema_sdl: The SDL of the schema to extend; empty for none.
        experimental: Parse directives on directive definitions.

    Raises:
        Error: When there is an error.
    """
    assert_equal(sdl_errors(rule, sdl, schema_sdl, experimental), "")

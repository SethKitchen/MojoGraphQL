# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_validation.validate`, ported from graphql-js 16.14.2
`src/validation/__tests__/validation-test.ts`.

Not ported, because the port has no such input: `rejects invalid
documents` (a Mojo document cannot be null), `Deprecated: validates using a
custom TypeInfo` (the `getFieldDefFn` hook is not ported), `validates using
a custom rule` and `passthrough exceptions from rules` (a rule is a value,
not a function).
"""

from _harness import (
    ALL_RULES,
    expect_errors,
    expect_valid,
    expect_valid_with_schema,
    format_errors,
    parse_query,
    schema_of,
    test_schema,
)
from gql_language.error import print_source_location
from gql_validation.rules import ValidationRule, specified_rules
from gql_validation.validate import ValidationOptions, validate
from std.testing import TestSuite, assert_equal, assert_true


def test_validates_queries() raises:
    expect_valid(
        ALL_RULES,
        """
      query {
        human {
          pets {
            ... on Cat {
              meowsVolume
            }
            ... on Dog {
              barkVolume
            }
          }
        }
      }
    """,
    )


def test_detects_unknown_fields() raises:
    expect_errors(
        ALL_RULES,
        """
      {
        unknown
      }
    """,
        ['Cannot query field "unknown" on type "QueryRoot". (3:9)'],
    )


comptime _THREE_UNKNOWN = """
    {
      firstUnknownField
      secondUnknownField
      thirdUnknownField
    }
  """


def _limited(max_errors: Int) raises -> String:
    var options = ValidationOptions()
    options.max_errors = max_errors
    var document = parse_query(_THREE_UNKNOWN)
    return format_errors(
        validate(test_schema(), document, specified_rules(), options)
    )


def test_max_errors_equal_to_the_number_of_errors() raises:
    assert_equal(
        _limited(3),
        (
            'Cannot query field "firstUnknownField" on type "QueryRoot".'
            ' (3:7)\nCannot query field "secondUnknownField" on type'
            ' "QueryRoot". (4:7)\nCannot query field "thirdUnknownField" on'
            ' type "QueryRoot". (5:7)'
        ),
    )


def test_max_errors_less_than_the_number_of_errors() raises:
    assert_equal(
        _limited(2),
        (
            'Cannot query field "firstUnknownField" on type "QueryRoot".'
            ' (3:7)\nCannot query field "secondUnknownField" on type'
            ' "QueryRoot". (4:7)\nToo many validation errors, error limit'
            " reached. Validation aborted. ()"
        ),
    )


def test_descriptions_of_operation_and_variables() raises:
    var schema = schema_of("type Query { field(a: Int, b: String): String }")
    expect_valid_with_schema(
        schema,
        ALL_RULES,
        '''
        "Operation description"
        query myQuery(
          "Variable a description"
          $a: Int,
          """Variable b\\nmultiline description"""
          $b: String
        ) {
          field(a: $a, b: $b)
        }
      ''',
    )


# --- beyond upstream ----------------------------------------------------------


def test_invalid_schema_raises() raises:
    var schema = schema_of("type Query { a: String } type Other")
    var raised = False
    try:
        _ = validate(schema, parse_query("{ a }"))
    except error:
        raised = True
        assert_equal(
            String(error), "Type Other must define one or more fields."
        )
    assert_true(raised)


def test_assume_valid_schema_skips_the_schema_check() raises:
    var schema = schema_of("type Query { a: String } type Other")
    var options = ValidationOptions()
    options.assume_valid_schema = True
    var errors = validate(
        schema, parse_query("{ a b }"), specified_rules(), options
    )
    assert_equal(
        format_errors(errors),
        'Cannot query field "b" on type "Query". Did you mean "a"? (1:5)',
    )


def test_a_rule_twice_runs_once() raises:
    var rules: List[ValidationRule] = [
        ValidationRule.UNIQUE_OPERATION_NAMES,
        ValidationRule.UNIQUE_OPERATION_NAMES,
        ValidationRule(200),
    ]
    var errors = validate(
        test_schema(), parse_query("query A { dog { name } }"), rules
    )
    assert_equal(len(errors), 0)


def _expect_same_excerpt(text: String) raises:
    """Check that each error of a long source prints the excerpt that
    `print_source_location` gives for the whole source."""
    var document = parse_query(text)
    var errors = validate(test_schema(), document)
    assert_true(len(errors) > 0)
    for ref error in errors:
        var want = error.message
        for location in error.locations:
            want += "\n\n" + print_source_location(document.source, location)
        assert_equal(String(error), want)


def test_error_excerpt_matches_a_long_source() raises:
    # Comments make the source long, with no nodes to check.
    var padding = "# " + "x" * 300 + "\n"
    var text = padding * 20 + "{\n  dog { name }\n  unknown\n}\n" + padding
    _expect_same_excerpt(text)
    _expect_same_excerpt(padding * 20 + "{ unknown }")


def test_error_excerpt_matches_a_long_line() raises:
    # Spaces make the line long; the errors are at several columns.
    var line = (
        "{" + " " * 5000 + "unknown" + " " * 90 + "other" + " " * 3000 + "}"
    )
    _expect_same_excerpt(line)
    _expect_same_excerpt("{ unknown" + " " * 5000 + "}")
    _expect_same_excerpt("{" + " " * 4100 + "unknown\r\n}")
    _expect_same_excerpt(
        "{"
        + " " * 4100
        + 'dog(x: "'
        + "\u00e9\u4e2d\U0001F600" * 30
        + '") { name } unknown }'
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

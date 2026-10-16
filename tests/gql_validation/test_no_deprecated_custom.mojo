# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for NoDeprecatedCustomRule, ported from graphql-js 16.14.2
`src/validation/__tests__/NoDeprecatedCustomRule-test.ts`.

Every upstream case is ported. Three titles occur in both the `no
deprecated arguments on fields` and the `no deprecated arguments on
directives` blocks, so those tests start with `arguments_on_fields_` or
`arguments_on_directives_`.
"""

from _harness import (
    expect_errors_with_schema,
    expect_valid_with_schema,
    schema_of,
)
from gql_validation.rules import ValidationRule
from std.testing import TestSuite

comptime RULE = ValidationRule.NO_DEPRECATED_CUSTOM
"""The rule under test."""

comptime FIELDS_SDL = """
      type Query {
        normalField: String
        deprecatedField: String @deprecated(reason: "Some field reason.")
      }
    """
"""The schema of the `no deprecated fields` block."""

comptime FIELD_ARGUMENTS_SDL = """
      type Query {
        someField(
          normalArg: String,
          deprecatedArg: String @deprecated(reason: "Some arg reason."),
        ): String
      }
    """
"""The schema of the `no deprecated arguments on fields` block."""

comptime DIRECTIVE_ARGUMENTS_SDL = """
      type Query {
        someField: String
      }

      directive @someDirective(
        normalArg: String,
        deprecatedArg: String @deprecated(reason: "Some arg reason."),
      ) on FIELD
    """
"""The schema of the `no deprecated arguments on directives` block."""

comptime INPUT_FIELDS_SDL = """
      input InputType {
        normalField: String
        deprecatedField: String @deprecated(reason: "Some input field reason.")
      }

      type Query {
        someField(someArg: InputType): String
      }

      directive @someDirective(someArg: InputType) on FIELD
    """
"""The schema of the `no deprecated input fields` block."""

comptime ENUM_VALUES_SDL = """
      enum EnumType {
        NORMAL_VALUE
        DEPRECATED_VALUE @deprecated(reason: "Some enum reason.")
      }

      type Query {
        someField(enumArg: EnumType): String
      }
    """
"""The schema of the `no deprecated enum values` block."""


# --- no deprecated fields ---------------------------------------------------


def test_ignores_fields_that_are_not_deprecated() raises:
    expect_valid_with_schema(
        schema_of(FIELDS_SDL),
        RULE,
        """
        {
          normalField
        }
      """,
    )


def test_ignores_unknown_fields() raises:
    expect_valid_with_schema(
        schema_of(FIELDS_SDL),
        RULE,
        """
        {
          unknownField
        }

        fragment UnknownFragment on UnknownType {
          deprecatedField
        }
      """,
    )


def test_reports_error_when_a_deprecated_field_is_selected() raises:
    expect_errors_with_schema(
        schema_of(FIELDS_SDL),
        RULE,
        """
        {
          deprecatedField
        }

        fragment QueryFragment on Query {
          deprecatedField
        }
      """,
        [
            (
                "The field Query.deprecatedField is deprecated. Some field"
                " reason. (3:11)"
            ),
            (
                "The field Query.deprecatedField is deprecated. Some field"
                " reason. (7:11)"
            ),
        ],
    )


# --- no deprecated arguments on fields --------------------------------------


def test_arguments_on_fields_ignores_arguments_that_are_not_deprecated() raises:
    expect_valid_with_schema(
        schema_of(FIELD_ARGUMENTS_SDL),
        RULE,
        """
        {
          normalField(normalArg: "")
        }
      """,
    )


def test_arguments_on_fields_ignores_unknown_arguments() raises:
    expect_valid_with_schema(
        schema_of(FIELD_ARGUMENTS_SDL),
        RULE,
        """
        {
          someField(unknownArg: "")
          unknownField(deprecatedArg: "")
        }
      """,
    )


def test_arguments_on_fields_reports_error_when_a_deprecated_argument_is_used() raises:
    expect_errors_with_schema(
        schema_of(FIELD_ARGUMENTS_SDL),
        RULE,
        """
        {
          someField(deprecatedArg: "")
        }
      """,
        [
            'Field "Query.someField" argument "deprecatedArg" is deprecated.'
            " Some arg reason. (3:21)"
        ],
    )


# --- no deprecated arguments on directives ----------------------------------


def test_arguments_on_directives_ignores_arguments_that_are_not_deprecated() raises:
    expect_valid_with_schema(
        schema_of(DIRECTIVE_ARGUMENTS_SDL),
        RULE,
        """
        {
          someField @someDirective(normalArg: "")
        }
      """,
    )


def test_arguments_on_directives_ignores_unknown_arguments() raises:
    expect_valid_with_schema(
        schema_of(DIRECTIVE_ARGUMENTS_SDL),
        RULE,
        """
        {
          someField @someDirective(unknownArg: "")
          someField @unknownDirective(deprecatedArg: "")
        }
      """,
    )


def test_arguments_on_directives_reports_error_when_a_deprecated_argument_is_used() raises:
    expect_errors_with_schema(
        schema_of(DIRECTIVE_ARGUMENTS_SDL),
        RULE,
        """
        {
          someField @someDirective(deprecatedArg: "")
        }
      """,
        [
            'Directive "@someDirective" argument "deprecatedArg" is'
            " deprecated. Some arg reason. (3:36)"
        ],
    )


# --- no deprecated input fields ---------------------------------------------


def test_ignores_input_fields_that_are_not_deprecated() raises:
    expect_valid_with_schema(
        schema_of(INPUT_FIELDS_SDL),
        RULE,
        """
        {
          someField(
            someArg: { normalField: "" }
          ) @someDirective(someArg: { normalField: "" })
        }
      """,
    )


def test_ignores_unknown_input_fields() raises:
    expect_valid_with_schema(
        schema_of(INPUT_FIELDS_SDL),
        RULE,
        """
        {
          someField(
            someArg: { unknownField: "" }
          )

          someField(
            unknownArg: { unknownField: "" }
          )

          unknownField(
            unknownArg: { unknownField: "" }
          )
        }
      """,
    )


def test_reports_error_when_a_deprecated_input_field_is_used() raises:
    expect_errors_with_schema(
        schema_of(INPUT_FIELDS_SDL),
        RULE,
        """
        {
          someField(
            someArg: { deprecatedField: "" }
          ) @someDirective(someArg: { deprecatedField: "" })
        }
      """,
        [
            (
                "The input field InputType.deprecatedField is deprecated."
                " Some input field reason. (4:24)"
            ),
            (
                "The input field InputType.deprecatedField is deprecated."
                " Some input field reason. (5:39)"
            ),
        ],
    )


# --- no deprecated enum values ----------------------------------------------


def test_ignores_enum_values_that_are_not_deprecated() raises:
    expect_valid_with_schema(
        schema_of(ENUM_VALUES_SDL),
        RULE,
        """
        {
          normalField(enumArg: NORMAL_VALUE)
        }
      """,
    )


def test_ignores_unknown_enum_values() raises:
    expect_valid_with_schema(
        schema_of(ENUM_VALUES_SDL),
        RULE,
        """
        query (
          $unknownValue: EnumType = UNKNOWN_VALUE
          $unknownType: UnknownType = UNKNOWN_VALUE
        ) {
          someField(enumArg: UNKNOWN_VALUE)
          someField(unknownArg: UNKNOWN_VALUE)
          unknownField(unknownArg: UNKNOWN_VALUE)
        }

        fragment SomeFragment on Query {
          someField(enumArg: UNKNOWN_VALUE)
        }
      """,
    )


def test_reports_error_when_a_deprecated_enum_value_is_used() raises:
    expect_errors_with_schema(
        schema_of(ENUM_VALUES_SDL),
        RULE,
        """
        query (
          $variable: EnumType = DEPRECATED_VALUE
        ) {
          someField(enumArg: DEPRECATED_VALUE)
        }
      """,
        [
            (
                'The enum value "EnumType.DEPRECATED_VALUE" is deprecated.'
                " Some enum reason. (3:33)"
            ),
            (
                'The enum value "EnumType.DEPRECATED_VALUE" is deprecated.'
                " Some enum reason. (5:30)"
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

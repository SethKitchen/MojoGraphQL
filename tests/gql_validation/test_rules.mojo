# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_validation.rules`, beyond upstream: the rule names and the
rule lists of graphql-js 16.14.2 `src/validation/specifiedRules.ts`."""

from gql_validation.rules import (
    ValidationRule,
    recommended_rules,
    specified_rules,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_specified_rules_in_order() raises:
    var rules = specified_rules()
    assert_equal(len(rules), 27)
    assert_equal(String(rules[0]), "ExecutableDefinitionsRule")
    assert_equal(String(rules[24]), "OverlappingFieldsCanBeMergedRule")
    assert_equal(String(rules[26]), "MaxIntrospectionDepthRule")


def test_recommended_rules() raises:
    var rules = recommended_rules()
    assert_equal(len(rules), 1)
    assert_true(rules[0] == ValidationRule.MAX_INTROSPECTION_DEPTH)


def test_custom_and_invalid_rules() raises:
    assert_equal(
        ValidationRule.NO_SCHEMA_INTROSPECTION_CUSTOM.text(),
        "NoSchemaIntrospectionCustomRule",
    )
    assert_true(ValidationRule.NO_DEPRECATED_CUSTOM.is_valid())
    assert_false(ValidationRule(29).is_valid())
    assert_equal(ValidationRule(29).text(), "<invalid>")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_normalization.variables_validation`, ported from
graphql-go-tools v2 `pkg/variablesvalidation/variablesvalidation_test.go`
`TestVariablesValidation` / "oneOf input objects". Each docstring is the
upstream subtest path.
"""

from _vv_helpers import run_test, run_test_with_variables_content_enabled
from std.testing import TestSuite, assert_equal, assert_true

comptime CAT_DOG = """
    input PetInput @oneOf {
        cat: String, dog: String
    }
    type Query {
        pet(input: PetInput!): String
    }"""
"""The upstream `catDogSchema`."""
comptime PET_QUERY = "query($input: PetInput!) { pet(input: $input) }"
"""The operation that takes `$input: PetInput!`."""
comptime SEARCH = """
    input PetInput @oneOf { cat: String, dog: String }
    input SearchInput @oneOf { byName: String, byPet: PetInput }
    type Query { search(input: SearchInput!): String }
"""
"""The schema with a nested `@oneOf` input."""
comptime SEARCH_QUERY = "query($input: SearchInput!) { search(input: $input) }"
"""The operation that takes `$input: SearchInput!`."""
comptime PETS = """
    input PetInput @oneOf { cat: String, dog: String }
    type Query { pets(input: [PetInput!]!): String }"""
"""The schema with a list of `@oneOf` inputs."""
comptime PETS_QUERY = "query($input: [PetInput!]!) { pets(input: $input) }"
"""The operation that takes `$input: [PetInput!]!`."""
comptime SEARCH_LISTS = """
    input SearchInput @oneOf { names: [String!], ids: [ID!] }
    type Query { search(input: SearchInput!): String }"""
"""The schema with `@oneOf` list fields."""


def expect_contains(got: String, want: String) raises:
    """Assert that a message contains a text, as `assert.Contains`."""
    assert_true(want in got, got)


def test_valid_cases_exactly_one_field_provided() raises:
    """Valid cases / exactly one field provided."""
    assert_equal(
        run_test(CAT_DOG, PET_QUERY, '{"input": {"cat": "Fluffy"}}'), ""
    )


def test_valid_cases_exactly_one_field_provided_different_field() raises:
    """Valid cases / exactly one field provided - different field."""
    assert_equal(run_test(CAT_DOG, PET_QUERY, '{"input": {"dog": "Rex"}}'), "")


def test_valid_cases_exactly_one_field_provided_via_nested_var() raises:
    """Valid cases / exactly one field provided - via nested var."""
    assert_equal(
        run_test(
            CAT_DOG,
            "query($s: String) { pet(input: {cat: $s} ) }",
            '{"s": "Rex"}',
        ),
        "",
    )


def test_valid_cases_exactly_one_field_with_complex_type() raises:
    """Valid cases / exactly one field with complex type."""
    assert_equal(
        run_test(
            (
                "input CatInput { name: String! } input PetInput @oneOf { cat:"
                " CatInput, dog: String } type Query { pet(input: PetInput!):"
                " String }"
            ),
            PET_QUERY,
            '{"input": {"cat": {"name": "Fluffy"}}}',
        ),
        "",
    )


def test_invalid_cases_no_fields_provided() raises:
    """Invalid cases / no fields provided."""
    expect_contains(
        run_test(CAT_DOG, PET_QUERY, '{"input": {}}'),
        (
            'OneOf input object "PetInput" must have exactly one field'
            " provided, but 0 fields were provided"
        ),
    )


def test_invalid_cases_multiple_fields_provided() raises:
    """Invalid cases / multiple fields provided."""
    expect_contains(
        run_test(
            CAT_DOG, PET_QUERY, '{"input": {"cat": "Fluffy", "dog": "Rex"}}'
        ),
        (
            'OneOf input object "PetInput" must have exactly one field'
            " provided, but 2 fields were provided"
        ),
    )


def test_invalid_cases_multiple_fields_with_one_null() raises:
    """Invalid cases / multiple fields with one null."""
    expect_contains(
        run_test(
            CAT_DOG, PET_QUERY, '{"input": {"cat": "Fluffy", "dog": null}}'
        ),
        (
            'Variable "$input" got invalid value; OneOf input object "PetInput"'
            " must have exactly one field provided, but 2 fields were provided"
        ),
    )


def test_invalid_cases_one_field_provided_but_null() raises:
    """Invalid cases / one field provided but null."""
    expect_contains(
        run_test(CAT_DOG, PET_QUERY, '{"input": {"dog": null}}'),
        (
            'Variable "$input" got invalid value; OneOf input object "PetInput"'
            ' field "dog" value must be non-null'
        ),
    )


def test_invalid_cases_all_fields_null() raises:
    """Invalid cases / all fields null."""
    expect_contains(
        run_test(CAT_DOG, PET_QUERY, '{"input": {"cat": null, "dog": null}}'),
        (
            'Variable "$input" got invalid value; OneOf input object "PetInput"'
            " must have exactly one field provided, but 2 fields were provided"
        ),
    )


def test_nested_one_of_input_objects_valid_nested_one_of() raises:
    """Nested oneOf input objects / valid nested oneOf."""
    assert_equal(
        run_test(
            SEARCH, SEARCH_QUERY, '{"input": {"byPet": {"cat": "Fluffy"}}}'
        ),
        "",
    )


def test_nested_one_of_input_objects_invalid_nested_one_of_inner_violation() raises:
    """Nested oneOf input objects / invalid nested oneOf - inner violation."""
    expect_contains(
        run_test(
            SEARCH,
            SEARCH_QUERY,
            '{"input": {"byPet": {"cat": "Fluffy", "dog": "Rex"}}}',
        ),
        (
            'Variable "$input" got invalid value at "input.byPet"; OneOf input'
            ' object "PetInput" must have exactly one field provided, but 2'
            " fields were provided"
        ),
    )


def test_nested_one_of_input_objects_invalid_nested_one_of_outer_violation() raises:
    """Nested oneOf input objects / invalid nested oneOf - outer violation."""
    expect_contains(
        run_test(
            SEARCH,
            SEARCH_QUERY,
            '{"input": {"byName": "Fluffy", "byPet": {"cat": "Fluffy"}}}',
        ),
        (
            'Variable "$input" got invalid value; OneOf input object'
            ' "SearchInput" must have exactly one field provided, but 2 fields'
            " were provided"
        ),
    )


def test_one_of_with_lists_valid_list_of_one_of() raises:
    """OneOf with lists / valid list of oneOf."""
    assert_equal(
        run_test(
            PETS, PETS_QUERY, '{"input": [{"cat": "Fluffy"}, {"dog": "Rex"}]}'
        ),
        "",
    )


def test_one_of_with_lists_invalid_list_of_one_of_one_element_violates() raises:
    """OneOf with lists / invalid list of oneOf - one element violates."""
    expect_contains(
        run_test(
            PETS,
            PETS_QUERY,
            '{"input": [{"cat": "Fluffy"}, {"cat": "Whiskers", "dog": "Rex"}]}',
        ),
        (
            'Variable "$input" got invalid value at "input.[1]"; OneOf input'
            ' object "PetInput" must have exactly one field provided, but 2'
            " fields were provided"
        ),
    )


def test_one_of_with_lists_one_of_field_is_list() raises:
    """OneOf with lists / oneOf field is list."""
    assert_equal(
        run_test(
            SEARCH_LISTS,
            SEARCH_QUERY,
            '{"input": {"names": ["Fluffy", "Rex"]}}',
        ),
        "",
    )


def test_one_of_with_lists_one_of_field_is_an_empty_list() raises:
    """OneOf with lists / oneOf field is an empty list."""
    assert_equal(
        run_test(SEARCH_LISTS, SEARCH_QUERY, '{"input": {"names": []}}'), ""
    )


def test_one_of_with_variables_content_enabled_multiple_fields_error_with_content() raises:
    """OneOf with variables content enabled / multiple fields error with
    content."""
    expect_contains(
        run_test_with_variables_content_enabled(
            (
                "input PetInput @oneOf { cat: String, dog: String } type Query"
                " { pet(input: PetInput!): String }"
            ),
            PET_QUERY,
            '{"input": {"cat": "Fluffy", "dog": "Rex"}}',
        ),
        (
            'Variable "$input" got invalid value {"cat":"Fluffy","dog":"Rex"};'
            ' OneOf input object "PetInput" must have exactly one field'
            " provided, but 2 fields were provided"
        ),
    )


def test_one_of_with_variables_content_enabled_nested_one_of_error_shows_the_value() raises:
    """OneOf with variables content enabled / nested oneOf error shows the
    value."""
    expect_contains(
        run_test_with_variables_content_enabled(
            """
            input PetInput @oneOf { cat: String, dog: String }
            input SearchInput { pets: [PetInput!] }
            type Query { search(input: SearchInput!): String }
            """,
            SEARCH_QUERY,
            '{"input": {"pets": [{"cat": "Fluffy"}, {"cat": null}]}}',
        ),
        (
            'Variable "$input" got invalid value {"cat":null} at'
            ' "input.pets.[1]"; OneOf input object "PetInput" field "cat" value'
            " must be non-null"
        ),
    )


def main() raises:
    """Run the suite."""
    TestSuite.discover_tests[__functions_in_module()]().run()

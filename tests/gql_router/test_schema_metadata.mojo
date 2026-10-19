# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the schema facts of the executor, `gql_router.schema_metadata`.

The cases follow `SchemaMetadata` and `PossibleTypes` of Hive Router
`1a29df9` `bin/router/src/executor/introspection/schema.rs`: the root
types, the fields of each type, the enum values, and the possible types of
each abstract type. The schemas here have empty definitions, which a
consumer schema does not have, so that each read also works on nothing.
"""

from gql_language.ast import Document
from gql_language.parser import parse
from gql_router.schema_metadata import PossibleTypes, schema_metadata
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_an_empty_document_has_the_default_roots() raises:
    var metadata = schema_metadata(Document())
    assert_equal(metadata.query_type_name, "")
    assert_equal(len(metadata.type_fields), 0)
    assert_true("String" in metadata.scalar_types)


def test_empty_definitions() raises:
    var metadata = schema_metadata(
        parse(
            "type Query { a: A } type A type A enum E input In union U"
            + " union V = U interface J interface I implements J"
            + " type T implements I { id: ID }"
        )
    )
    assert_equal(metadata.query_type_name, "Query")
    assert_false(metadata.has_type_fields("Missing"))
    assert_equal(metadata.field_type("A", "missing"), "")
    assert_equal(metadata.field_type("Query", "a"), "A")
    assert_equal(len(metadata.enum_values["E"]), 0)
    assert_equal(len(metadata.input_objects["In"].fields), 0)
    assert_equal(len(metadata.possible_types.map["U"]), 0)
    assert_equal(len(metadata.possible_types.map["V"]), 1)
    assert_true("T" in metadata.possible_types.map["J"])


def test_possible_types() raises:
    var metadata = schema_metadata(
        parse("type Query { a: I } interface I type T implements I")
    )
    ref possible = metadata.possible_types
    assert_true(possible.entity_satisfies_type_condition("T", "I"))
    assert_true(possible.entity_satisfies_type_condition("T", "T"))
    assert_false(possible.entity_satisfies_type_condition("Query", "I"))
    assert_false(possible.entity_satisfies_type_condition("T", "Other"))
    assert_true("T" in possible.get_possible_types("I"))
    var alone = possible.get_possible_types("Query")
    assert_equal(len(alone), 1)
    assert_true("Query" in alone)
    assert_equal(len(PossibleTypes().get_possible_types("X")), 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

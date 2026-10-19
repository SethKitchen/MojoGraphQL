# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for orphan extensions and schema extensions.

Port of apollo-compiler 1.33.0 (`b7eee5c`) `tests/extensions.rs`. The calls
to `validate` are left out: validation is not part of this port yet.
"""

from gql_language.ast import OperationType
from gql_language.names import NOT_FOUND
from gql_compiler.from_ast import SchemaBuilder
from gql_compiler.schema import BuildError, Schema, TypeKind
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _messages(errors: List[BuildError]) -> String:
    var text = String()
    for error in errors:
        text += error.message()
        text += "\n"
    return text


def _adopting(text: StringSlice) raises -> SchemaBuilder:
    var builder = SchemaBuilder().adopt_orphan_extensions()
    builder.parse(text)
    return builder^


comptime ORPHANS = """
    extend schema @dir { query: Q }
    extend type Obj @dir { foo: String }
    extend interface I @dir { foo: String }
    extend union U @dir = Obj
    extend enum E @dir { FOO, BAR }
    extend input Input @dir { bar: String }
    directive @dir on SCHEMA | SCALAR | OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT
    type Q { x: Int }
"""


def test_orphan_extensions() raises:
    var builder = SchemaBuilder()
    builder.parse(ORPHANS)
    var result = builder^.build_inner()
    assert_equal(
        result[0].count_directives(result[0].schema_directives, "dir"), 0
    )
    assert_equal(result[0].get_type("Obj"), NOT_FOUND)
    var errors = _messages(result[1])
    assert_true("schema extension without a schema definition" in errors)
    assert_true("type extension for undefined type `Obj`" in errors)

    var schema = _adopting(ORPHANS).build()
    assert_equal(schema.count_directives(schema.schema_directives, "dir"), 1)
    var obj = schema.get_type("Obj")
    assert_equal(
        schema.count_directives(schema.types[obj].directives, "dir"), 1
    )
    assert_true(schema.types[schema.get_type("U")].kind == TypeKind.UNION)
    assert_equal(schema.member_count(schema.get_type("E")), 2)


def test_orphan_extensions_schema_with_default_query_name() raises:
    var schema = _adopting(
        "extend schema { query: Query }\ntype Query { x: Int }"
    ).build()
    assert_equal(
        schema.root_operation(OperationType.QUERY).value().type_name, "Query"
    )


def test_orphan_extensions_schema_def_with_extensions() raises:
    var schema = _adopting(
        """
        extend schema { query: Query }
        extend schema { subscription: S }
        schema { mutation: Mutation }
        type Query { x: Int }
        type Mutation { y: Int }
        type S { z: Int }
        """
    ).build()
    assert_equal(
        schema.root_operation(OperationType.QUERY).value().type_name, "Query"
    )
    assert_equal(
        schema.root_operation(OperationType.MUTATION).value().type_name,
        "Mutation",
    )
    assert_equal(
        schema.root_operation(OperationType.SUBSCRIPTION).value().type_name, "S"
    )


def test_invalid_orphan_extensions_schema_def_with_duplicate_root_operation() raises:
    var result = _adopting(
        """
        extend schema { query: Query }
        extend schema { subscription: S }
        schema { mutation: Mutation, query: AnotherQuery }
        type Query { x: Int }
        type Mutation { y: Int }
        type S { z: Int }
        type AnotherQuery { a: String }
        """
    ).build_inner()
    assert_true(
        "duplicate definitions for the `query` root operation type"
        in _messages(result[1])
    )


def test_orphan_schema_extension_with_root_type_disables_implicit_root_types() raises:
    var schema = _adopting(
        """
        extend schema { query: Query }
        type Query { viruses: [Virus] }
        type Virus { mutations: [Mutation] }
        type Mutation { something: String }
        """
    ).build()
    assert_false(Bool(schema.root_operation(OperationType.MUTATION)))


def test_orphan_schema_extension_without_root_type_enables_implicit_root_types() raises:
    var schema = _adopting(
        """
        directive @something on SCHEMA
        extend schema @something
        type Query { field: Int }
        """
    ).build()
    assert_true(Bool(schema.root_operation(OperationType.QUERY)))


def test_orphan_schema_extension_with_directive_application() raises:
    var schema = _adopting(
        """
        directive @something on SCHEMA
        extend schema @something { query: Query }
        type Query { field: Int }
        """
    ).build()
    assert_true(Bool(schema.root_operation(OperationType.QUERY)))


def test_orphan_extensions_kind_mismatch() raises:
    var result = _adopting(
        """
        extend type T @dir
        extend interface T @dir
        directive @dir repeatable on SCHEMA | OBJECT
        """
    ).build_inner()
    var t = result[0].get_type("T")
    assert_true(result[0].types[t].kind == TypeKind.OBJECT)
    assert_equal(
        result[0].count_directives(result[0].types[t].directives, "dir"), 1
    )
    assert_true(
        "adding an interface type extension, but `T` is an object type"
        in _messages(result[1])
    )


def test_orphan_extension_preserves_source_location() raises:
    var schema = _adopting(
        "extend type T { foo: String }\ntype Query { x: Int }"
    ).build()
    var t = schema.get_type("T")
    assert_true(schema.types[t].definition.node >= 0)
    assert_equal(schema.types[t].definition.source, 1)


def test_extend_implicit_schema() raises:
    var builder = SchemaBuilder()
    builder.parse(
        """
        type Query { field: Int }
        extend schema @dir
        directive @dir on SCHEMA
        """
    )
    var schema = builder^.build()
    assert_equal(schema.count_directives(schema.schema_directives, "dir"), 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

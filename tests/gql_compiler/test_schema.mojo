# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `Schema` and `SchemaBuilder`.

Ports `test_default_root_op_name_ignored_with_explicit_schema_def` and
`handles_implicit_root_types` from apollo-compiler 1.33.0 (`b7eee5c`)
`tests/schema.rs`. The other tests check each `BuildError` of
`src/schema/from_ast.rs`, with the messages of `src/schema/mod.rs`.
"""

from gql_language.ast import OperationType
from gql_language.names import NOT_FOUND
from gql_language.parser import ParseOptions, parse
from gql_compiler.from_ast import SchemaBuilder
from gql_compiler.schema import (
    BuildError,
    BuildErrorKind,
    Component,
    DEFINITION_ORIGIN,
    Schema,
    TypeKind,
    definition_kind,
)
from gql_language.ast import Kind
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)


def _errors(text: StringSlice) raises -> List[String]:
    var builder = SchemaBuilder()
    builder.parse(text)
    var result = builder^.build_inner()
    var out = List[String]()
    for error in result[1]:
        out.append(error.message())
    return out^


def _build(text: StringSlice) raises -> Schema:
    var builder = SchemaBuilder()
    builder.parse(text)
    return builder^.build()


def test_default_root_op_name_ignored_with_explicit_schema_def() raises:
    var schema = _build(
        """
        schema { query: Query }
        type Query { viruses: [Virus!] }
        type Virus { name: String! knownMutations: [Mutation!]! }
        type Mutation { name: String! geneSequence: String! }
        """
    )
    assert_false(Bool(schema.root_operation(OperationType.MUTATION)))
    assert_equal(
        schema.root_operation(OperationType.QUERY).value().type_name, "Query"
    )


def test_handles_implicit_root_types() raises:
    var builder = SchemaBuilder().adopt_orphan_extensions()
    builder.parse(
        "extend type Query { foo: String }\nextend type Mutation { bar:"
        " String }"
    )
    var schema = builder^.build()
    assert_true(Bool(schema.root_operation(OperationType.QUERY)))
    assert_true(Bool(schema.root_operation(OperationType.MUTATION)))
    var root = schema.root_operation(OperationType.QUERY).value()
    assert_equal(root.component.node, -1)


def test_built_in_types() raises:
    var schema = SchemaBuilder().build()
    assert_true(schema.get_type("__Schema") != NOT_FOUND)
    assert_true(schema.is_built_in(schema.get_type("String")))
    assert_true(schema.get_directive_definition("deprecated") != NOT_FOUND)
    assert_equal(schema.get_directive_definition("nope"), NOT_FOUND)
    assert_equal(len(schema.sources), 1)
    assert_false(Bool(schema.root_operation(OperationType.QUERY)))


def test_types_keep_definition_order_and_members() raises:
    var schema = _build(
        """
        type Query { a: Int b: Int c: Int }
        enum E { X Y }
        union U = Query
        input I { f: Int }
        scalar S
        interface N { id: ID }
        type Obj implements N { id: ID }
        """
    )
    var query = schema.get_type("Query")
    assert_false(schema.is_built_in(query))
    assert_equal(String(schema.type_name(query)), "Query")
    assert_equal(schema.member_count(query), 3)
    assert_equal(schema.find_member(query, "b"), 1)
    assert_equal(schema.find_member(query, "z"), NOT_FOUND)
    assert_equal(String(schema.component_name(schema.member(query, 2))), "c")
    assert_true(schema.types[schema.get_type("E")].kind == TypeKind.ENUM)
    assert_true(schema.types[schema.get_type("U")].kind == TypeKind.UNION)
    assert_true(
        schema.types[schema.get_type("I")].kind == TypeKind.INPUT_OBJECT
    )
    assert_true(schema.types[schema.get_type("S")].kind == TypeKind.SCALAR)
    assert_true(schema.types[schema.get_type("N")].kind == TypeKind.INTERFACE)
    var obj = schema.get_type("Obj")
    assert_equal(Int(schema.types[obj].interfaces.count), 1)


def test_many_members_are_hashed() raises:
    var fields = String()
    for index in range(20):
        fields += String(" f", index, ": Int")
    var schema = _build(String("type Query {", fields, " }"))
    var query = schema.get_type("Query")
    assert_equal(schema.member_count(query), 20)
    assert_equal(schema.find_member(query, "f0"), 0)
    assert_equal(schema.find_member(query, "f19"), 19)
    assert_equal(schema.find_member(query, "f20"), NOT_FOUND)
    var errors = _errors(String("type Query {", fields, " f3: Int f12: Int }"))
    assert_equal(len(errors), 2)
    assert_equal(
        errors[0],
        "duplicate definitions for the `f3` field of object type `Query`",
    )


def test_extension_moves_members_to_the_end() raises:
    var schema = _build(
        """
        type A { a1: Int }
        type B { b1: Int }
        extend type A @x { a2: Int }
        directive @x on OBJECT
        """
    )
    var a = schema.get_type("A")
    assert_equal(schema.member_count(a), 2)
    assert_equal(String(schema.component_name(schema.member(a, 0))), "a1")
    assert_equal(String(schema.component_name(schema.member(a, 1))), "a2")
    assert_equal(schema.count_directives(schema.types[a].directives, "x"), 1)
    assert_equal(schema.member(a, 1).origin, 0)
    assert_equal(schema.member(a, 0).origin, DEFINITION_ORIGIN)
    var b = schema.get_type("B")
    assert_equal(String(schema.component_name(schema.member(b, 0))), "b1")


def test_extension_before_definition_waits() raises:
    var schema = _build("extend type Q { b: Int }\ntype Q { a: Int }")
    var q = schema.get_type("Q")
    assert_equal(schema.member_count(q), 2)
    assert_equal(String(schema.component_name(schema.member(q, 1))), "b")


def test_executable_definitions_are_errors() raises:
    var errors = _errors(
        "type Query { a: Int }\nquery { a }\nfragment F on Query { a }"
    )
    assert_equal(len(errors), 2)
    assert_equal(
        errors[0], "a schema document must not contain an operation definition"
    )
    assert_equal(
        errors[1], "a schema document must not contain a fragment definition"
    )
    var options = ParseOptions()
    options.experimental_directives_on_directive_definitions = True
    var builder = SchemaBuilder()
    builder.add_ast(
        parse("directive @d on FIELD\nextend directive @d @d", options)
    )
    var result = builder^.build_inner()
    assert_equal(
        result[1][0].message(),
        "a schema document must not contain a directive extension",
    )


def test_definition_collisions() raises:
    var errors = _errors(
        """
        schema { query: Query }
        schema { query: Query }
        type Query { a: Int }
        type Query { b: Int }
        scalar String
        directive @d on FIELD
        directive @d on FIELD
        directive @skip(if: Boolean!) on FIELD
        directive @skip(if: Boolean!) on FIELD
        """
    )
    assert_equal(len(errors), 5)
    assert_equal(errors[0], "must not have multiple `schema` definitions")
    assert_equal(
        errors[1], "the type `Query` is defined multiple times in the schema"
    )
    assert_equal(errors[2], "built-in scalar definitions must be omitted")
    assert_equal(
        errors[3], "the directive `@d` is defined multiple times in the schema"
    )
    assert_equal(
        errors[4],
        "the directive `@skip` is defined multiple times in the schema",
    )


def test_redefined_built_in_object_is_a_collision() raises:
    var errors = _errors("type __Schema { a: Int }")
    assert_equal(
        errors[0], "the type `__Schema` is defined multiple times in the schema"
    )


def test_ignore_builtin_redefinitions() raises:
    var builder = SchemaBuilder().ignore_builtin_redefinitions_on()
    builder.parse(
        "scalar String\ntype __Schema { a: Int }\ntype Query { a: String }"
    )
    var schema = builder^.build()
    assert_true(schema.is_built_in(schema.get_type("String")))


def test_duplicate_root_operation_and_interfaces() raises:
    var errors = _errors(
        """
        schema { query: Query query: Query }
        interface I { a: Int }
        interface J implements I & I { a: Int }
        type Query implements I & I { a: Int }
        """
    )
    assert_equal(len(errors), 3)
    assert_equal(
        errors[0], "duplicate definitions for the `query` root operation type"
    )
    assert_equal(
        errors[1],
        "interface type `J` implements interface `I` more than once",
    )
    assert_equal(
        errors[2], "object type `Query` implements interface `I` more than once"
    )


def test_duplicate_root_operations_name_each_type() raises:
    var errors = _errors(
        """
        schema { mutation: M mutation: M subscription: S subscription: S }
        type M { a: Int }
        type S { a: Int }
        """
    )
    assert_equal(
        errors[0],
        "duplicate definitions for the `mutation` root operation type",
    )
    assert_equal(
        errors[1],
        "duplicate definitions for the `subscription` root operation type",
    )


def test_member_collisions() raises:
    var errors = _errors(
        """
        type Query { a: Int a: Int }
        interface I { b: Int b: Int }
        enum E { X X }
        union U = Query | Query
        input In { c: Int c: Int }
        """
    )
    assert_equal(len(errors), 5)
    assert_equal(
        errors[0],
        "duplicate definitions for the `a` field of object type `Query`",
    )
    assert_equal(
        errors[1],
        "duplicate definitions for the `b` field of interface type `I`",
    )
    assert_equal(
        errors[2], "duplicate definitions for the `X` value of enum type `E`"
    )
    assert_equal(
        errors[3],
        "duplicate definitions for the `Query` member of union type `U`",
    )
    assert_equal(
        errors[4],
        "duplicate definitions for the `c` field of input object type `In`",
    )


def test_orphans_without_adoption() raises:
    var builder = SchemaBuilder()
    builder.parse(
        "extend type Missing { a: Int }\nextend scalar Gone @d\nextend type"
        " Missing { b: Int }"
    )
    assert_equal(len(builder.iter_orphan_extension_types()), 2)
    var result = builder^.build_inner()
    assert_equal(len(result[1]), 3)
    assert_equal(
        result[1][0].message(), "type extension for undefined type `Missing`"
    )
    assert_equal(
        result[1][2].message(), "type extension for undefined type `Gone`"
    )


def test_orphan_names_skip_adopted_definitions() raises:
    var builder = SchemaBuilder()
    builder.parse("extend type T { a: Int }\ntype T { b: Int }")
    assert_equal(len(builder.iter_orphan_extension_types()), 0)


def test_orphan_schema_extension_with_explicit_definition() raises:
    var schema = _build(
        "extend schema @d\nschema { query: Q }\ntype Q { a: Int }\ndirective @d"
        " on SCHEMA"
    )
    assert_equal(schema.count_directives(schema.schema_directives, "d"), 1)
    assert_equal(schema.count_directives(schema.schema_directives, "e"), 0)


def test_orphan_schema_extension_extends_implicit_roots() raises:
    var schema = _build(
        "extend schema { mutation: M }\ntype Query { a: Int }\ntype M { a:"
        " Int }"
    )
    assert_equal(
        schema.root_operation(OperationType.MUTATION).value().type_name, "M"
    )


def test_adopted_orphan_kind_mismatch_and_roots() raises:
    var builder = SchemaBuilder().adopt_orphan_extensions()
    builder.parse(
        "extend schema { query: Q }\nextend type Q { a: Int }\nextend enum Q"
        " { V }"
    )
    var result = builder^.build_inner()
    assert_equal(len(result[1]), 1)
    assert_equal(
        result[1][0].message(),
        "adding an enum type extension, but `Q` is an object type",
    )


def test_adoption_with_no_roots_and_no_query() raises:
    var builder = SchemaBuilder().adopt_orphan_extensions()
    builder.parse(
        "extend schema @d\ndirective @d on SCHEMA\ninterface Query { a: Int }"
    )
    var schema = builder^.build()
    assert_false(Bool(schema.root_operation(OperationType.QUERY)))


def test_build_raises_with_every_message() raises:
    var builder = SchemaBuilder()
    builder.parse(
        "type Query { a: Int a: Int }\nextend type Missing { b: Int }"
    )
    with assert_raises(contains="type extension for undefined type `Missing`"):
        _ = builder^.build()
    var other = SchemaBuilder()
    other.parse("type Query { a: Int a: Int }")
    with assert_raises(contains="field of object type `Query`"):
        _ = other^.build()


def test_extension_of_wrong_kind() raises:
    var errors = _errors(
        """
        type Query { a: Int }
        extend scalar Query @d
        extend interface Query { b: Int }
        extend union Query = Query
        extend input Query { c: Int }
        extend type Query { d: Int }
        scalar S
        extend type S { e: Int }
        directive @d on SCALAR
        """
    )
    assert_equal(len(errors), 5)
    assert_equal(
        errors[0],
        "adding a scalar type extension, but `Query` is an object type",
    )
    assert_equal(
        errors[1],
        "adding an interface type extension, but `Query` is an object type",
    )
    assert_equal(
        errors[2],
        "adding a union type extension, but `Query` is an object type",
    )
    assert_equal(
        errors[3],
        "adding an input object type extension, but `Query` is an object type",
    )
    assert_equal(
        errors[4], "adding an object type extension, but `S` is a scalar type"
    )


def test_schema_extension_after_definition() raises:
    var schema = _build(
        '"The schema." schema { query: Q }\nextend schema @d { mutation: M }\n'
        + "type Q { a: Int }\ntype M { a: Int }\ndirective @d on SCHEMA"
    )
    assert_equal(schema.count_directives(schema.schema_directives, "d"), 1)
    var mutation = schema.root_operation(OperationType.MUTATION).value()
    assert_equal(mutation.type_name, "M")
    assert_equal(mutation.component.origin, 0)


def test_duplicate_user_types() raises:
    var errors = _errors("scalar X\nscalar X\ntype Query { a: X }")
    assert_equal(
        errors[0], "the type `X` is defined multiple times in the schema"
    )
    var builder = SchemaBuilder().ignore_builtin_redefinitions_on()
    builder.parse("type Q { a: Int }\ntype Q { b: Int }")
    var result = builder^.build_inner()
    assert_equal(
        result[1][0].message(),
        "the type `Q` is defined multiple times in the schema",
    )


def test_distinct_interfaces() raises:
    var schema = _build(
        "interface I { a: Int }\ninterface J { a: Int }\n"
        + "type Query implements I & J { a: Int }"
    )
    assert_equal(
        Int(schema.types[schema.get_type("Query")].interfaces.count), 2
    )


def test_adopted_schema_extension_with_mutation_or_subscription() raises:
    var mutation = SchemaBuilder().adopt_orphan_extensions()
    mutation.parse(
        "extend schema { mutation: M }\ntype M { a: Int }\ntype Query { a:"
        " Int }"
    )
    var with_mutation = mutation^.build()
    assert_false(Bool(with_mutation.root_operation(OperationType.QUERY)))
    var subscription = SchemaBuilder().adopt_orphan_extensions()
    subscription.parse(
        "extend schema { subscription: S }\ntype S { a: Int }\ntype Query { a:"
        " Int }"
    )
    var with_subscription = subscription^.build()
    assert_false(Bool(with_subscription.root_operation(OperationType.QUERY)))


def test_type_kind() raises:
    assert_true(TypeKind.SCALAR.is_valid())
    assert_true(TypeKind.INPUT_OBJECT.is_valid())
    assert_false(TypeKind(6).is_valid())
    assert_equal(TypeKind.ENUM.describe(), "an enum type")
    assert_equal(TypeKind.UNION.describe(), "a union type")
    assert_equal(TypeKind.INTERFACE.describe(), "an interface type")
    assert_equal(TypeKind.INPUT_OBJECT.describe(), "an input object type")
    assert_equal(TypeKind.SCALAR.describe(), "a scalar type")
    assert_equal(TypeKind.ENUM.describe_extension(), "an enum type extension")
    assert_equal(String(TypeKind.OBJECT), "an object type")


def test_definition_kind() raises:
    assert_equal(definition_kind(Kind.SCALAR_TYPE_DEFINITION), 0)
    assert_equal(definition_kind(Kind.OBJECT_TYPE_DEFINITION), 1)
    assert_equal(definition_kind(Kind.INTERFACE_TYPE_DEFINITION), 2)
    assert_equal(definition_kind(Kind.UNION_TYPE_DEFINITION), 3)
    assert_equal(definition_kind(Kind.ENUM_TYPE_DEFINITION), 4)
    assert_equal(definition_kind(Kind.INPUT_OBJECT_TYPE_DEFINITION), 5)
    assert_equal(definition_kind(Kind.SCALAR_TYPE_EXTENSION), 0)
    assert_equal(definition_kind(Kind.INPUT_OBJECT_TYPE_EXTENSION), 5)
    assert_equal(definition_kind(Kind.TYPE_COORDINATE), -1)
    assert_equal(definition_kind(Kind.DIRECTIVE_DEFINITION), -1)


def test_build_error_kind() raises:
    assert_true(BuildErrorKind.MEMBER_NAME_COLLISION.is_valid())
    assert_false(BuildErrorKind(11).is_valid())
    assert_equal(String(BuildErrorKind(3)), "BuildErrorKind(3)")
    var error = BuildError(
        BuildErrorKind.ORPHAN_SCHEMA_EXTENSION,
        Component(1, 2, DEFINITION_ORIGIN),
        "",
        TypeKind.SCALAR,
        "",
        "",
    )
    assert_equal(String(error), "schema extension without a schema definition")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

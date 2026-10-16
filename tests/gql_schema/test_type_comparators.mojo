# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_schema.type_comparators`, ported from graphql-js 16.14.2
`src/utilities/__tests__/typeComparators-test.ts`.

The upstream schemas are made with the graphql-js constructors; here they
are built from the same types in SDL. The tests after the upstream ones are
Mojo tests: `doTypesOverlap` has no upstream test file, and a type index out
of range is the graphql-js `undefined`.
"""

from gql_schema.build import build_schema
from gql_schema.definition import NO_TYPE, Schema, TypeRef
from gql_schema.type_comparators import (
    do_types_overlap,
    is_equal_type,
    is_type_sub_type_of,
)
from std.testing import TestSuite, assert_false, assert_true


def named(schema: Schema, name: String) -> TypeRef:
    """Return a named type of a schema as a reference."""
    return TypeRef.of(schema.type_named(name))


def scalars() raises -> Schema:
    """Return a schema whose type map has Int, Float and String."""
    return build_schema("type Query { a: Int, b: Float, c: String }")


# --- isEqualType -------------------------------------------------------------


def test_same_reference_are_equal() raises:
    var schema = scalars()
    assert_true(is_equal_type(named(schema, "String"), named(schema, "String")))


def test_int_and_float_are_not_equal() raises:
    var schema = scalars()
    assert_false(is_equal_type(named(schema, "Int"), named(schema, "Float")))


def test_lists_of_same_type_are_equal() raises:
    var schema = scalars()
    var int_type = named(schema, "Int")
    assert_true(is_equal_type(int_type.list_of(), int_type.list_of()))


def test_lists_is_not_equal_to_item() raises:
    var schema = scalars()
    var int_type = named(schema, "Int")
    assert_false(is_equal_type(int_type.list_of(), int_type))


def test_non_null_of_same_type_are_equal() raises:
    var schema = scalars()
    var int_type = named(schema, "Int")
    assert_true(is_equal_type(int_type.non_null(), int_type.non_null()))


def test_non_null_is_not_equal_to_nullable() raises:
    var schema = scalars()
    var int_type = named(schema, "Int")
    assert_false(is_equal_type(int_type.non_null(), int_type))


# --- isTypeSubTypeOf ---------------------------------------------------------


def test_same_reference_is_subtype() raises:
    var schema = scalars()
    var string_type = named(schema, "String")
    assert_true(is_type_sub_type_of(schema, string_type, string_type))


def test_int_is_not_subtype_of_float() raises:
    var schema = scalars()
    assert_false(
        is_type_sub_type_of(
            schema, named(schema, "Int"), named(schema, "Float")
        )
    )


def test_non_null_is_subtype_of_nullable() raises:
    var schema = scalars()
    var int_type = named(schema, "Int")
    assert_true(is_type_sub_type_of(schema, int_type.non_null(), int_type))


def test_nullable_is_not_subtype_of_non_null() raises:
    var schema = scalars()
    var int_type = named(schema, "Int")
    assert_false(is_type_sub_type_of(schema, int_type, int_type.non_null()))


def test_item_is_not_subtype_of_list() raises:
    var schema = scalars()
    var int_type = named(schema, "Int")
    assert_false(is_type_sub_type_of(schema, int_type, int_type.list_of()))


def test_list_is_not_subtype_of_item() raises:
    var schema = scalars()
    var int_type = named(schema, "Int")
    assert_false(is_type_sub_type_of(schema, int_type.list_of(), int_type))


def test_member_is_subtype_of_union() raises:
    var schema = build_schema(
        """
type Object { field: String }
union Union = Object
type Query { field: Union }
"""
    )
    assert_true(
        is_type_sub_type_of(
            schema, named(schema, "Object"), named(schema, "Union")
        )
    )


def test_implementing_object_is_subtype_of_interface() raises:
    var schema = build_schema(
        """
interface Interface { field: String }
type Object implements Interface { field: String }
type Query { field: Object }
"""
    )
    assert_true(
        is_type_sub_type_of(
            schema, named(schema, "Object"), named(schema, "Interface")
        )
    )


def test_implementing_interface_is_subtype_of_interface() raises:
    var schema = build_schema(
        """
interface Interface { field: String }
interface Interface2 implements Interface { field: String }
type Object implements Interface2 & Interface { field: String }
type Query { field: Object }
"""
    )
    assert_true(
        is_type_sub_type_of(
            schema, named(schema, "Interface2"), named(schema, "Interface")
        )
    )


# --- Mojo tests --------------------------------------------------------------

comptime ABSTRACT_SDL = """
interface Named { name: String }
interface Other { name: String }
type Dog implements Named { name: String }
type Cat implements Named { name: String }
type Rock { name: String }
union Pet = Dog | Cat
union Pebble = Rock
union Empty
interface Lonely { name: String }
type Query { pet: Pet, pebble: Pebble, empty: Empty, named: Named,
  other: Other, lonely: Lonely }
"""


def test_wrapped_subtypes() raises:
    var schema = build_schema(ABSTRACT_SDL)
    var dog = named(schema, "Dog")
    var pet = named(schema, "Pet")
    assert_true(
        is_type_sub_type_of(schema, dog.non_null().list_of(), pet.list_of())
    )
    assert_true(is_type_sub_type_of(schema, dog.non_null(), pet.non_null()))
    assert_false(
        is_type_sub_type_of(schema, dog.list_of(), pet.list_of().non_null())
    )


def test_non_subtypes_of_abstract_types() raises:
    var schema = build_schema(ABSTRACT_SDL)
    var named_type = named(schema, "Named")
    # A scalar is no subtype of an interface.
    assert_false(
        is_type_sub_type_of(schema, named(schema, "String"), named_type)
    )
    # An object that does not implement the interface.
    assert_false(is_type_sub_type_of(schema, named(schema, "Rock"), named_type))
    # An interface that does not implement the interface.
    assert_false(
        is_type_sub_type_of(schema, named(schema, "Other"), named_type)
    )
    # An object that is no member of the union.
    assert_false(
        is_type_sub_type_of(schema, named(schema, "Rock"), named(schema, "Pet"))
    )


def test_undefined_is_no_subtype() raises:
    var schema = build_schema(ABSTRACT_SDL)
    var named_type = named(schema, "Named")
    assert_false(is_type_sub_type_of(schema, TypeRef.of(NO_TYPE), named_type))
    assert_false(
        is_type_sub_type_of(schema, TypeRef.of(len(schema.types)), named_type)
    )
    assert_false(is_type_sub_type_of(schema, named_type, TypeRef.of(NO_TYPE)))
    assert_true(
        is_type_sub_type_of(schema, TypeRef.of(NO_TYPE), TypeRef.of(NO_TYPE))
    )


def test_do_types_overlap() raises:
    var schema = build_schema(ABSTRACT_SDL)
    var dog = schema.type_named("Dog")
    var cat = schema.type_named("Cat")
    var rock = schema.type_named("Rock")
    var pet = schema.type_named("Pet")
    var pebble = schema.type_named("Pebble")
    var empty = schema.type_named("Empty")
    var named_type = schema.type_named("Named")
    var lonely = schema.type_named("Lonely")
    # Equal types overlap.
    assert_true(do_types_overlap(schema, dog, dog))
    # Two objects do not.
    assert_false(do_types_overlap(schema, dog, cat))
    # Two abstract types with a common possible type.
    assert_true(do_types_overlap(schema, named_type, pet))
    assert_true(do_types_overlap(schema, pet, named_type))
    # Two abstract types with no common possible type.
    assert_false(do_types_overlap(schema, pet, pebble))
    # Abstract types with no possible type.
    assert_false(do_types_overlap(schema, empty, pet))
    assert_false(do_types_overlap(schema, lonely, named_type))
    # An abstract type and an object.
    assert_true(do_types_overlap(schema, pet, dog))
    assert_false(do_types_overlap(schema, pet, rock))
    assert_true(do_types_overlap(schema, named_type, cat))
    assert_true(do_types_overlap(schema, dog, named_type))
    assert_false(do_types_overlap(schema, rock, pet))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_schema.validate`, ported from graphql-js 16.14.2
`src/type/__tests__/validation-test.ts`.

`expect_errors` is `expectJSON(validateSchema(schema)).toDeepEqual(...)`:
it compares the errors' JSON, messages and locations, byte for byte.

**How the upstream schemas are made here.**

- A `buildSchema` case is the same SDL, with the same lines and columns.
- An `extendSchema` case builds from several documents at once: the base
  SDL, then each extension. Each document keeps its own source, so the
  locations are the upstream locations.
- A case that makes its schema with the graphql-js constructors
  (`new GraphQLObjectType(...)`) builds the same types from SDL with
  `assume_valid_sdl`, then removes every AST node reference with
  `strip_ast`. A constructed type has no `astNode`, so the upstream errors
  have no locations, and here too.
- A constructor case that gives a type as `undefined` sets a `TypeRef` or a
  type list entry to `NO_TYPE`, which is the graphql-js `undefined`.
- "rejects a Schema whose directives have empty locations" sets the
  directive's `locations` to 0; SDL needs at least one location.

**Deferred upstream cases.**

- "rejects a Schema whose types are incorrectly typed", "rejects a Schema
  whose directives are incorrectly typed" and the four "rejects a non-type
  value as ... type" cases (`Number`): they put JavaScript values that are
  not GraphQL types or directives into a schema. A Mojo schema holds only
  `NamedType` and `DirectiveDef` values, so these values cannot exist.
- In "rejects a Union type with non-Object members types", the members
  `new GraphQLNonNull(SomeObjectType)` and `new GraphQLList(SomeObjectType)`:
  a union member is a type index, which has no list or non-null wrapper.
  The other five members are tested.
- The second `manualSchema2` of "rejects an Object type with missing
  fields" gives its fields as a thunk. Mojo has no thunks; the case is the
  same as `manualSchema`.

The tests after "assertValidSchema" are Mojo tests. They cover type
indices out of range, which graphql-js cannot have, and branches that the
upstream suite does not reach.
"""

from _validate_helpers import (
    build_documents,
    error,
    errors_json,
    expect_errors,
    expect_valid,
    strip_ast,
)
from gql_schema.build import BuildOptions, build_schema
from gql_schema.definition import NO_TYPE, Schema, TypeKind, TypeRef
from gql_schema.validate import assert_valid_schema, validate_schema
from std.testing import TestSuite, assert_equal

comptime SOME_SDL = """
  scalar SomeScalar

  interface SomeInterface { f: SomeObject }

  type SomeObject implements SomeInterface { f: SomeObject }

  union SomeUnion = SomeObject

  enum SomeEnum { ONLY }

  input SomeInputObject { val: String = "hello" }

  directive @SomeDirective on QUERY
"""


def constructed(sdl: String) raises -> Schema:
    """Build a schema with no AST nodes, as the graphql-js constructors do."""
    var options = BuildOptions()
    options.assume_valid_sdl = True
    var schema = build_schema(sdl, options)
    strip_ast(schema)
    return schema^


def with_modifiers(name: String) -> List[String]:
    """Return a type and its wrappers, as `withModifiers`."""
    return [name, "[" + name + "]", name + "!", "[" + name + "]!"]


def all_with_modifiers(names: List[String]) -> List[String]:
    """Return each type with its wrappers."""
    var out = List[String]()
    for ref name in names:
        out.extend(with_modifiers(name))
    return out^


def output_types() -> List[String]:
    """Return `outputTypes`."""
    return all_with_modifiers(
        [
            "String",
            "SomeScalar",
            "SomeEnum",
            "SomeObject",
            "SomeUnion",
            "SomeInterface",
        ]
    )


def not_output_types() -> List[String]:
    """Return `notOutputTypes`."""
    return with_modifiers("SomeInputObject")


def input_types() -> List[String]:
    """Return `inputTypes`."""
    return all_with_modifiers(
        ["String", "SomeScalar", "SomeEnum", "SomeInputObject"]
    )


def not_input_types() -> List[String]:
    """Return `notInputTypes`."""
    return all_with_modifiers(["SomeObject", "SomeUnion", "SomeInterface"])


def no_type() -> TypeRef:
    """Return the graphql-js `undefined` as a type."""
    return TypeRef.of(NO_TYPE)


# --- Type System: A Schema must have Object root types ----------------------


def test_accepts_a_schema_whose_query_type_is_an_object_type() raises:
    var schema = build_schema(
        """
      type Query {
        test: String
      }
    """
    )
    expect_valid(schema)

    var schema_with_def = build_schema(
        """
      schema {
        query: QueryRoot
      }

      type QueryRoot {
        test: String
      }
    """
    )
    expect_valid(schema_with_def)


def test_accepts_a_schema_whose_query_and_mutation_types_are_object_types() raises:
    var schema = build_schema(
        """
      type Query {
        test: String
      }

      type Mutation {
        test: String
      }
    """
    )
    expect_valid(schema)

    var schema_with_def = build_schema(
        """
      schema {
        query: QueryRoot
        mutation: MutationRoot
      }

      type QueryRoot {
        test: String
      }

      type MutationRoot {
        test: String
      }
    """
    )
    expect_valid(schema_with_def)


def test_accepts_a_schema_whose_query_and_subscription_types_are_object_types() raises:
    var schema = build_schema(
        """
      type Query {
        test: String
      }

      type Subscription {
        test: String
      }
    """
    )
    expect_valid(schema)

    var schema_with_def = build_schema(
        """
      schema {
        query: QueryRoot
        subscription: SubscriptionRoot
      }

      type QueryRoot {
        test: String
      }

      type SubscriptionRoot {
        test: String
      }
    """
    )
    expect_valid(schema_with_def)


def test_rejects_a_schema_without_a_query_type() raises:
    var schema = build_schema(
        """
      type Mutation {
        test: String
      }
    """
    )
    expect_errors(schema, [error("Query root type must be provided.")])

    var schema_with_def = build_schema(
        """
      schema {
        mutation: MutationRoot
      }

      type MutationRoot {
        test: String
      }
    """
    )
    expect_errors(
        schema_with_def, [error("Query root type must be provided.", "2:7")]
    )


def test_rejects_a_schema_whose_query_root_type_is_not_an_object_type() raises:
    var schema = build_schema(
        """
      input Query {
        test: String
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                "Query root type must be Object type, it cannot be Query.",
                "2:7",
            )
        ],
    )

    var schema_with_def = build_schema(
        """
      schema {
        query: SomeInputObject
      }

      input SomeInputObject {
        test: String
      }
    """
    )
    expect_errors(
        schema_with_def,
        [
            error(
                (
                    "Query root type must be Object type, it cannot be"
                    " SomeInputObject."
                ),
                "3:16",
            )
        ],
    )


def test_rejects_a_schema_whose_mutation_type_is_an_input_type() raises:
    var schema = build_schema(
        """
      type Query {
        field: String
      }

      input Mutation {
        test: String
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Mutation root type must be Object type if provided, it"
                    " cannot be Mutation."
                ),
                "6:7",
            )
        ],
    )

    var schema_with_def = build_schema(
        """
      schema {
        query: Query
        mutation: SomeInputObject
      }

      type Query {
        field: String
      }

      input SomeInputObject {
        test: String
      }
    """
    )
    expect_errors(
        schema_with_def,
        [
            error(
                (
                    "Mutation root type must be Object type if provided, it"
                    " cannot be SomeInputObject."
                ),
                "4:19",
            )
        ],
    )


def test_rejects_a_schema_whose_subscription_type_is_an_input_type() raises:
    var schema = build_schema(
        """
      type Query {
        field: String
      }

      input Subscription {
        test: String
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Subscription root type must be Object type if provided, it"
                    " cannot be Subscription."
                ),
                "6:7",
            )
        ],
    )

    var schema_with_def = build_schema(
        """
      schema {
        query: Query
        subscription: SomeInputObject
      }

      type Query {
        field: String
      }

      input SomeInputObject {
        test: String
      }
    """
    )
    expect_errors(
        schema_with_def,
        [
            error(
                (
                    "Subscription root type must be Object type if provided, it"
                    " cannot be SomeInputObject."
                ),
                "4:23",
            )
        ],
    )


def test_rejects_a_schema_extended_with_invalid_root_types() raises:
    var schema = build_documents(
        [
            """
      input SomeInputObject {
        test: String
      }
    """,
            """
        extend schema {
          query: SomeInputObject
        }
      """,
            """
        extend schema {
          mutation: SomeInputObject
        }
      """,
            """
        extend schema {
          subscription: SomeInputObject
        }
      """,
        ]
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Query root type must be Object type, it cannot be"
                    " SomeInputObject."
                ),
                "3:18",
            ),
            error(
                (
                    "Mutation root type must be Object type if provided, it"
                    " cannot be SomeInputObject."
                ),
                "3:21",
            ),
            error(
                (
                    "Subscription root type must be Object type if provided, it"
                    " cannot be SomeInputObject."
                ),
                "3:25",
            ),
        ],
    )


def test_rejects_a_schema_whose_directives_have_empty_locations() raises:
    var schema = constructed(
        "type Query { f: String }\ndirective @BadDirective on QUERY"
    )
    schema.directives[schema.directive_named("BadDirective")].locations = 0
    expect_errors(
        schema,
        [error("Directive @BadDirective must include 1 or more locations.")],
    )


# --- Type System: Objects must have fields -----------------------------------


def test_accepts_an_object_type_with_fields_object() raises:
    var schema = build_schema(
        """
      type Query {
        field: SomeObject
      }

      type SomeObject {
        field: String
      }
    """
    )
    expect_valid(schema)


def test_rejects_an_object_type_with_missing_fields() raises:
    var schema = build_schema(
        """
      type Query {
        test: IncompleteObject
      }

      type IncompleteObject
    """
    )
    expect_errors(
        schema,
        [error("Type IncompleteObject must define one or more fields.", "6:7")],
    )

    var manual_schema = constructed(
        "type Query { f: IncompleteObject }\ntype IncompleteObject"
    )
    expect_errors(
        manual_schema,
        [error("Type IncompleteObject must define one or more fields.")],
    )


def test_rejects_an_object_type_with_incorrectly_named_fields() raises:
    var schema = constructed(
        "type Query { f: SomeObject }\ntype SomeObject { __badName: String }"
    )
    expect_errors(
        schema,
        [
            error(
                'Name "__badName" must not begin with "__", which is reserved'
                " by GraphQL introspection."
            )
        ],
    )


# --- Type System: Fields args must be properly named -------------------------


def test_accepts_field_args_with_valid_names() raises:
    var schema = constructed(
        "type Query { f: SomeObject }\n"
        "type SomeObject { goodField(goodArg: String): String }"
    )
    expect_valid(schema)


def test_rejects_field_arg_with_invalid_names() raises:
    var schema = constructed(
        "type Query { f: SomeObject }\n"
        "type SomeObject { badField(__badName: String): String }"
    )
    expect_errors(
        schema,
        [
            error(
                'Name "__badName" must not begin with "__", which is reserved'
                " by GraphQL introspection."
            )
        ],
    )


# --- Type System: Union types must be valid ----------------------------------


def test_accepts_a_union_type_with_member_types() raises:
    var schema = build_schema(
        """
      type Query {
        test: GoodUnion
      }

      type TypeA {
        field: String
      }

      type TypeB {
        field: String
      }

      union GoodUnion =
        | TypeA
        | TypeB
    """
    )
    expect_valid(schema)


def test_rejects_a_union_type_with_empty_types() raises:
    var schema = build_documents(
        [
            """
      type Query {
        test: BadUnion
      }

      union BadUnion
    """,
            """
        directive @test on UNION

        extend union BadUnion @test
      """,
        ]
    )
    expect_errors(
        schema,
        [
            error(
                "Union type BadUnion must define one or more member types.",
                "6:7 4:9",
            )
        ],
    )


comptime DUPLICATED_UNION_SDL = """
      type Query {
        test: BadUnion
      }

      type TypeA {
        field: String
      }

      type TypeB {
        field: String
      }

      union BadUnion =
        | TypeA
        | TypeB
        | TypeA
    """


def test_rejects_a_union_type_with_duplicated_member_type() raises:
    var schema = build_schema(DUPLICATED_UNION_SDL)
    expect_errors(
        schema,
        [
            error(
                "Union type BadUnion can only include type TypeA once.",
                "15:11 17:11",
            )
        ],
    )

    var extended = build_documents(
        [DUPLICATED_UNION_SDL, "extend union BadUnion = TypeB"]
    )
    expect_errors(
        extended,
        [
            error(
                "Union type BadUnion can only include type TypeA once.",
                "15:11 17:11",
            ),
            error(
                "Union type BadUnion can only include type TypeB once.",
                "16:11 1:25",
            ),
        ],
    )


def test_rejects_a_union_type_with_non_object_members_types() raises:
    var schema = build_documents(
        [
            """
      type Query {
        test: BadUnion
      }

      type TypeA {
        field: String
      }

      type TypeB {
        field: String
      }

      union BadUnion =
        | TypeA
        | String
        | TypeB
    """,
            "extend union BadUnion = Int",
        ]
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Union type BadUnion can only include Object types, it"
                    " cannot include String."
                ),
                "16:11",
            ),
            error(
                (
                    "Union type BadUnion can only include Object types, it"
                    " cannot include Int."
                ),
                "1:25",
            ),
        ],
    )

    var bad_union_member_types: List[String] = [
        "String",
        "SomeInterface",
        "SomeUnion",
        "SomeEnum",
        "SomeInputObject",
    ]
    for ref member_type in bad_union_member_types:
        var bad_schema = constructed(
            "type Query { f: BadUnion }\nunion BadUnion = "
            + member_type
            + SOME_SDL
        )
        expect_errors(
            bad_schema,
            [
                error(
                    "Union type BadUnion can only include Object types, it"
                    " cannot include "
                    + member_type
                    + "."
                )
            ],
        )


# --- Type System: Input Objects must have fields -----------------------------


def test_accepts_an_input_object_type_with_fields() raises:
    var schema = build_schema(
        """
      type Query {
        field(arg: SomeInputObject): String
      }

      input SomeInputObject {
        field: String
      }
    """
    )
    expect_valid(schema)


def test_rejects_an_input_object_type_with_missing_fields() raises:
    var schema = build_documents(
        [
            """
      type Query {
        field(arg: SomeInputObject): String
      }

      input SomeInputObject
    """,
            """
        directive @test on INPUT_OBJECT

        extend input SomeInputObject @test
      """,
        ]
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Input Object type SomeInputObject must define one or more"
                    " fields."
                ),
                "6:7 4:9",
            )
        ],
    )


def test_accepts_an_input_object_with_breakable_circular_reference() raises:
    var schema = build_schema(
        """
      type Query {
        field(arg: SomeInputObject): String
      }

      input SomeInputObject {
        self: SomeInputObject
        arrayOfSelf: [SomeInputObject]
        nonNullArrayOfSelf: [SomeInputObject]!
        nonNullArrayOfNonNullSelf: [SomeInputObject!]!
        intermediateSelf: AnotherInputObject
      }

      input AnotherInputObject {
        parent: SomeInputObject
      }
    """
    )
    expect_valid(schema)


def test_rejects_an_input_object_with_non_breakable_circular_reference() raises:
    var schema = build_schema(
        """
      type Query {
        field(arg: SomeInputObject): String
      }

      input SomeInputObject {
        nonNullSelf: SomeInputObject!
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    'Cannot reference Input Object "SomeInputObject" within'
                    " itself through a series of non-null fields:"
                    ' "nonNullSelf".'
                ),
                "7:9",
            )
        ],
    )


def test_rejects_input_objects_with_non_breakable_circular_reference_spread_across_them() raises:
    var schema = build_schema(
        """
      type Query {
        field(arg: SomeInputObject): String
      }

      input SomeInputObject {
        startLoop: AnotherInputObject!
      }

      input AnotherInputObject {
        nextInLoop: YetAnotherInputObject!
      }

      input YetAnotherInputObject {
        closeLoop: SomeInputObject!
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    'Cannot reference Input Object "SomeInputObject" within'
                    " itself through a series of non-null fields:"
                    ' "startLoop.nextInLoop.closeLoop".'
                ),
                "7:9 11:9 15:9",
            )
        ],
    )


def test_rejects_input_objects_with_multiple_non_breakable_circular_reference() raises:
    var schema = build_schema(
        """
      type Query {
        field(arg: SomeInputObject): String
      }

      input SomeInputObject {
        startLoop: AnotherInputObject!
      }

      input AnotherInputObject {
        closeLoop: SomeInputObject!
        startSecondLoop: YetAnotherInputObject!
      }

      input YetAnotherInputObject {
        closeSecondLoop: AnotherInputObject!
        nonNullSelf: YetAnotherInputObject!
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    'Cannot reference Input Object "SomeInputObject" within'
                    " itself through a series of non-null fields:"
                    ' "startLoop.closeLoop".'
                ),
                "7:9 11:9",
            ),
            error(
                (
                    'Cannot reference Input Object "AnotherInputObject" within'
                    " itself through a series of non-null fields:"
                    ' "startSecondLoop.closeSecondLoop".'
                ),
                "12:9 16:9",
            ),
            error(
                (
                    'Cannot reference Input Object "YetAnotherInputObject"'
                    " within itself through a series of non-null fields:"
                    ' "nonNullSelf".'
                ),
                "17:9",
            ),
        ],
    )


def test_rejects_an_input_object_type_with_incorrectly_typed_fields() raises:
    var schema = build_schema(
        """
      type Query {
        field(arg: SomeInputObject): String
      }

      type SomeObject {
        field: String
      }

      union SomeUnion = SomeObject

      input SomeInputObject {
        badObject: SomeObject
        badUnion: SomeUnion
        goodInputObject: SomeInputObject
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "The type of SomeInputObject.badObject must be Input Type"
                    " but got: SomeObject."
                ),
                "13:20",
            ),
            error(
                (
                    "The type of SomeInputObject.badUnion must be Input Type"
                    " but got: SomeUnion."
                ),
                "14:19",
            ),
        ],
    )


def test_rejects_an_input_object_type_with_required_argument_that_is_deprecated() raises:
    var schema = build_schema(
        """
      type Query {
        field(arg: SomeInputObject): String
      }

      input SomeInputObject {
        badField: String! @deprecated
        optionalField: String @deprecated
        anotherOptionalField: String! = "" @deprecated
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Required input field SomeInputObject.badField cannot be"
                    " deprecated."
                ),
                "7:27 7:19",
            )
        ],
    )


# --- Type System: Enum types must be well defined ----------------------------


def test_rejects_an_enum_type_without_values() raises:
    var schema = build_documents(
        [
            """
      type Query {
        field: SomeEnum
      }

      enum SomeEnum
    """,
            """
        directive @test on ENUM

        extend enum SomeEnum @test
      """,
        ]
    )
    expect_errors(
        schema,
        [
            error(
                "Enum type SomeEnum must define one or more values.",
                "6:7 4:9",
            )
        ],
    )


def test_rejects_an_enum_type_with_incorrectly_named_values() raises:
    var schema = constructed(
        "type Query { f: SomeEnum }\nenum SomeEnum { __badName }"
    )
    expect_errors(
        schema,
        [
            error(
                'Name "__badName" must not begin with "__", which is reserved'
                " by GraphQL introspection."
            )
        ],
    )


# --- Type System: Object fields must have output types -----------------------


def schema_with_object_field(type: String) raises -> Schema:
    """Return `schemaWithObjectField({ type })`."""
    return constructed(
        "type Query { f: BadObject }\ntype BadObject { badField: "
        + type
        + " }"
        + SOME_SDL
    )


def test_accepts_an_output_type_as_an_object_field_type() raises:
    for type in output_types():
        expect_valid(schema_with_object_field(type))


def test_rejects_an_empty_object_field_type() raises:
    var schema = schema_with_object_field("String")
    var field = schema.field_named(schema.type_named("BadObject"), "badField")
    schema.fields[field].type = no_type()
    expect_errors(
        schema,
        [
            error(
                "The type of BadObject.badField must be Output Type but got:"
                " undefined."
            )
        ],
    )


def test_rejects_a_non_output_type_as_an_object_field_type() raises:
    for type in not_output_types():
        expect_errors(
            schema_with_object_field(type),
            [
                error(
                    "The type of BadObject.badField must be Output Type but"
                    " got: "
                    + type
                    + "."
                )
            ],
        )


def test_rejects_with_relevant_locations_for_a_non_output_type_as_an_object_field_type() raises:
    var schema = build_schema(
        """
      type Query {
        field: [SomeInputObject]
      }

      input SomeInputObject {
        field: String
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "The type of Query.field must be Output Type but got:"
                    " [SomeInputObject]."
                ),
                "3:16",
            )
        ],
    )


# --- Type System: Objects can only implement unique interfaces ---------------


def test_rejects_an_object_implementing_a_non_type_value() raises:
    var schema = constructed(
        "schema { query: BadObject }\n"
        "interface SomeInterface { f: String }\n"
        "type BadObject implements SomeInterface { f: String }"
    )
    var bad_object = schema.type_named("BadObject")
    schema.type_lists[Int(schema.types[bad_object].interfaces.start)] = NO_TYPE
    expect_errors(
        schema,
        [
            error(
                "Type BadObject must only implement Interface types, it cannot"
                " implement undefined."
            )
        ],
    )


def test_rejects_an_object_implementing_a_non_interface_type() raises:
    var schema = build_schema(
        """
      type Query {
        test: BadObject
      }

      input SomeInputObject {
        field: String
      }

      type BadObject implements SomeInputObject {
        field: String
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Type BadObject must only implement Interface types, it"
                    " cannot implement SomeInputObject."
                ),
                "10:33",
            )
        ],
    )


def test_rejects_an_object_implementing_the_same_interface_twice() raises:
    var schema = build_schema(
        """
      type Query {
        test: AnotherObject
      }

      interface AnotherInterface {
        field: String
      }

      type AnotherObject implements AnotherInterface & AnotherInterface {
        field: String
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                "Type AnotherObject can only implement AnotherInterface once.",
                "10:37 10:56",
            )
        ],
    )


def test_rejects_an_object_implementing_the_same_interface_twice_due_to_extension() raises:
    var extended_schema = build_documents(
        [
            """
      type Query {
        test: AnotherObject
      }

      interface AnotherInterface {
        field: String
      }

      type AnotherObject implements AnotherInterface {
        field: String
      }
    """,
            "extend type AnotherObject implements AnotherInterface",
        ]
    )
    expect_errors(
        extended_schema,
        [
            error(
                "Type AnotherObject can only implement AnotherInterface once.",
                "10:37 1:38",
            )
        ],
    )


# --- Type System: Interface extensions should be valid -----------------------

comptime ANOTHER_SDL = """
      type Query {
        test: AnotherObject
      }

      interface AnotherInterface {
        field: String
      }

      type AnotherObject implements AnotherInterface {
        field: String
      }
    """


def test_rejects_an_object_implementing_the_extended_interface_due_to_missing_field() raises:
    var extended_schema = build_documents(
        [
            ANOTHER_SDL,
            """
        extend interface AnotherInterface {
          newField: String
        }

        extend type AnotherObject {
          differentNewField: String
        }
      """,
        ]
    )
    expect_errors(
        extended_schema,
        [
            error(
                (
                    "Interface field AnotherInterface.newField expected but"
                    " AnotherObject does not provide it."
                ),
                "3:11 10:7 6:9",
            )
        ],
    )


def test_rejects_an_object_implementing_the_extended_interface_due_to_missing_field_args() raises:
    var extended_schema = build_documents(
        [
            ANOTHER_SDL,
            """
        extend interface AnotherInterface {
          newField(test: Boolean): String
        }

        extend type AnotherObject {
          newField: String
        }
      """,
        ]
    )
    expect_errors(
        extended_schema,
        [
            error(
                (
                    "Interface field argument AnotherInterface.newField(test:)"
                    " expected but AnotherObject.newField does not provide it."
                ),
                "3:20 7:11",
            )
        ],
    )


def test_rejects_objects_implementing_the_extended_interface_due_to_mismatching_interface_type() raises:
    var extended_schema = build_documents(
        [
            ANOTHER_SDL,
            """
        extend interface AnotherInterface {
          newInterfaceField: NewInterface
        }

        interface NewInterface {
          newField: String
        }

        interface MismatchingInterface {
          newField: String
        }

        extend type AnotherObject {
          newInterfaceField: MismatchingInterface
        }

        # Required to prevent unused interface errors
        type DummyObject implements NewInterface & MismatchingInterface {
          newField: String
        }
      """,
        ]
    )
    expect_errors(
        extended_schema,
        [
            error(
                (
                    "Interface field AnotherInterface.newInterfaceField expects"
                    " type NewInterface but AnotherObject.newInterfaceField is"
                    " type MismatchingInterface."
                ),
                "3:30 15:30",
            )
        ],
    )


# --- Type System: Interface fields must have output types --------------------


def schema_with_interface_field(type: String) raises -> Schema:
    """Return `schemaWithInterfaceField({ type })`."""
    return constructed(
        "type BadImplementing implements BadInterface { badField: "
        + type
        + " }\ninterface BadInterface { badField: "
        + type
        + " }\ntype Query { f: BadInterface }"
        + SOME_SDL
    )


def test_accepts_an_output_type_as_an_interface_field_type() raises:
    for type in output_types():
        expect_valid(schema_with_interface_field(type))


def test_rejects_an_empty_interface_field_type() raises:
    var schema = schema_with_interface_field("String")
    var implementing = schema.type_named("BadImplementing")
    var iface = schema.type_named("BadInterface")
    schema.fields[schema.field_named(implementing, "badField")].type = no_type()
    schema.fields[schema.field_named(iface, "badField")].type = no_type()
    expect_errors(
        schema,
        [
            error(
                "The type of BadImplementing.badField must be Output Type but"
                " got: undefined."
            ),
            error(
                "The type of BadInterface.badField must be Output Type but"
                " got: undefined."
            ),
        ],
    )


def test_rejects_a_non_output_type_as_an_interface_field_type() raises:
    for type in not_output_types():
        expect_errors(
            schema_with_interface_field(type),
            [
                error(
                    "The type of BadImplementing.badField must be Output Type"
                    " but got: "
                    + type
                    + "."
                ),
                error(
                    "The type of BadInterface.badField must be Output Type but"
                    " got: "
                    + type
                    + "."
                ),
            ],
        )


def test_rejects_a_non_output_type_as_an_interface_field_type_with_locations() raises:
    var schema = build_schema(
        """
      type Query {
        test: SomeInterface
      }

      interface SomeInterface {
        field: SomeInputObject
      }

      input SomeInputObject {
        foo: String
      }

      type SomeObject implements SomeInterface {
        field: SomeInputObject
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "The type of SomeInterface.field must be Output Type but"
                    " got: SomeInputObject."
                ),
                "7:16",
            ),
            error(
                (
                    "The type of SomeObject.field must be Output Type but got:"
                    " SomeInputObject."
                ),
                "15:16",
            ),
        ],
    )


def test_accepts_an_interface_not_implemented_by_at_least_one_object() raises:
    var schema = build_schema(
        """
      type Query {
        test: SomeInterface
      }

      interface SomeInterface {
        foo: String
      }
    """
    )
    expect_valid(schema)


# --- Type System: Arguments must have input types ----------------------------


def schema_with_arg(type: String) raises -> Schema:
    """Return `schemaWithArg({ type })`."""
    return constructed(
        "type Query { f: BadObject }\ntype BadObject { badField(badArg: "
        + type
        + "): String }\ndirective @BadDirective(badArg: "
        + type
        + ") on QUERY"
        + SOME_SDL
    )


def test_accepts_an_input_type_as_a_field_arg_type() raises:
    for type in input_types():
        expect_valid(schema_with_arg(type))


def test_rejects_an_empty_field_arg_type() raises:
    var schema = schema_with_arg("String")
    var field = schema.field_named(schema.type_named("BadObject"), "badField")
    var directive = schema.directive_named("BadDirective")
    schema.input_values[schema.argument_named(field, "badArg")].type = no_type()
    schema.input_values[
        schema.directive_argument_named(directive, "badArg")
    ].type = no_type()
    expect_errors(
        schema,
        [
            error(
                "The type of @BadDirective(badArg:) must be Input Type but got:"
                " undefined."
            ),
            error(
                "The type of BadObject.badField(badArg:) must be Input Type but"
                " got: undefined."
            ),
        ],
    )


def test_rejects_a_non_input_type_as_a_field_arg_type() raises:
    for type in not_input_types():
        expect_errors(
            schema_with_arg(type),
            [
                error(
                    "The type of @BadDirective(badArg:) must be Input Type but"
                    " got: "
                    + type
                    + "."
                ),
                error(
                    "The type of BadObject.badField(badArg:) must be Input Type"
                    " but got: "
                    + type
                    + "."
                ),
            ],
        )


def test_rejects_a_required_argument_that_is_deprecated() raises:
    var schema = build_schema(
        """
      directive @BadDirective(
        badArg: String! @deprecated
        optionalArg: String @deprecated
        anotherOptionalArg: String! = "" @deprecated
      ) on FIELD

      type Query {
        test(
          badArg: String! @deprecated
          optionalArg: String @deprecated
          anotherOptionalArg: String! = "" @deprecated
        ): String
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Required argument @BadDirective(badArg:) cannot be"
                    " deprecated."
                ),
                "3:25 3:17",
            ),
            error(
                "Required argument Query.test(badArg:) cannot be deprecated.",
                "10:27 10:19",
            ),
        ],
    )


def test_rejects_a_non_input_type_as_a_field_arg_with_locations() raises:
    var schema = build_schema(
        """
      type Query {
        test(arg: SomeObject): String
      }

      type SomeObject {
        foo: String
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "The type of Query.test(arg:) must be Input Type but got:"
                    " SomeObject."
                ),
                "3:19",
            )
        ],
    )


# --- Type System: Input Object fields must have input types ------------------


def schema_with_input_field(type: String) raises -> Schema:
    """Return `schemaWithInputField({ type })`."""
    return constructed(
        "type Query { f(badArg: BadInputObject): String }\n"
        "input BadInputObject { badField: "
        + type
        + " }"
        + SOME_SDL
    )


def test_accepts_an_input_type_as_an_input_field_type() raises:
    for type in input_types():
        expect_valid(schema_with_input_field(type))


def test_rejects_an_empty_input_field_type() raises:
    var schema = schema_with_input_field("String")
    var field = schema.input_field_named(
        schema.type_named("BadInputObject"), "badField"
    )
    schema.input_values[field].type = no_type()
    expect_errors(
        schema,
        [
            error(
                "The type of BadInputObject.badField must be Input Type but"
                " got: undefined."
            )
        ],
    )


def test_rejects_a_non_input_type_as_an_input_field_type() raises:
    for type in not_input_types():
        expect_errors(
            schema_with_input_field(type),
            [
                error(
                    "The type of BadInputObject.badField must be Input Type"
                    " but got: "
                    + type
                    + "."
                )
            ],
        )


def test_rejects_a_non_input_type_as_an_input_object_field_with_locations() raises:
    var schema = build_schema(
        """
      type Query {
        test(arg: SomeInputObject): String
      }

      input SomeInputObject {
        foo: SomeObject
      }

      type SomeObject {
        bar: String
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "The type of SomeInputObject.foo must be Input Type but"
                    " got: SomeObject."
                ),
                "7:14",
            )
        ],
    )


# --- Type System: OneOf Input Object fields must be nullable -----------------


def test_rejects_non_nullable_fields() raises:
    var schema = build_schema(
        """
      type Query {
        test(arg: SomeInputObject): String
      }

      input SomeInputObject @oneOf {
        a: String
        b: String!
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                "OneOf input field SomeInputObject.b must be nullable.", "8:12"
            )
        ],
    )


def test_rejects_fields_with_default_values() raises:
    var schema = build_schema(
        """
      type Query {
        test(arg: SomeInputObject): String
      }

      input SomeInputObject @oneOf {
        a: String
        b: String = "foo"
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "OneOf input field SomeInputObject.b cannot have a default"
                    " value."
                ),
                "8:9",
            )
        ],
    )


# --- Objects must adhere to Interface they implement -------------------------


def test_accepts_an_object_which_implements_an_interface() raises:
    var schema = build_schema(
        """
      type Query {
        test: AnotherObject
      }

      interface AnotherInterface {
        field(input: String): String
      }

      type AnotherObject implements AnotherInterface {
        field(input: String): String
      }
    """
    )
    expect_valid(schema)


def test_accepts_an_object_which_implements_an_interface_along_with_more_fields() raises:
    var schema = build_schema(
        """
      type Query {
        test: AnotherObject
      }

      interface AnotherInterface {
        field(input: String): String
      }

      type AnotherObject implements AnotherInterface {
        field(input: String): String
        anotherField: String
      }
    """
    )
    expect_valid(schema)


def test_accepts_an_object_which_implements_an_interface_field_along_with_additional_optional_arguments() raises:
    var schema = build_schema(
        """
      type Query {
        test: AnotherObject
      }

      interface AnotherInterface {
        field(input: String): String
      }

      type AnotherObject implements AnotherInterface {
        field(input: String, anotherInput: String): String
      }
    """
    )
    expect_valid(schema)


def test_rejects_an_object_missing_an_interface_field() raises:
    var schema = build_schema(
        """
      type Query {
        test: AnotherObject
      }

      interface AnotherInterface {
        field(input: String): String
      }

      type AnotherObject implements AnotherInterface {
        anotherField: String
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Interface field AnotherInterface.field expected but"
                    " AnotherObject does not provide it."
                ),
                "7:9 10:7",
            )
        ],
    )


def test_rejects_an_object_with_an_incorrectly_typed_interface_field() raises:
    var schema = build_schema(
        """
      type Query {
        test: AnotherObject
      }

      interface AnotherInterface {
        field(input: String): String
      }

      type AnotherObject implements AnotherInterface {
        field(input: String): Int
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Interface field AnotherInterface.field expects type String"
                    " but AnotherObject.field is type Int."
                ),
                "7:31 11:31",
            )
        ],
    )


def test_rejects_an_object_with_a_differently_typed_interface_field() raises:
    var schema = build_schema(
        """
      type Query {
        test: AnotherObject
      }

      type A { foo: String }
      type B { foo: String }

      interface AnotherInterface {
        field: A
      }

      type AnotherObject implements AnotherInterface {
        field: B
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Interface field AnotherInterface.field expects type A but"
                    " AnotherObject.field is type B."
                ),
                "10:16 14:16",
            )
        ],
    )


def test_accepts_an_object_with_a_subtyped_interface_field_interface() raises:
    var schema = build_schema(
        """
      type Query {
        test: AnotherObject
      }

      interface AnotherInterface {
        field: AnotherInterface
      }

      type AnotherObject implements AnotherInterface {
        field: AnotherObject
      }
    """
    )
    expect_valid(schema)


def test_accepts_an_object_with_a_subtyped_interface_field_union() raises:
    var schema = build_schema(
        """
      type Query {
        test: AnotherObject
      }

      type SomeObject {
        field: String
      }

      union SomeUnionType = SomeObject

      interface AnotherInterface {
        field: SomeUnionType
      }

      type AnotherObject implements AnotherInterface {
        field: SomeObject
      }
    """
    )
    expect_valid(schema)


def test_rejects_an_object_missing_an_interface_argument() raises:
    var schema = build_schema(
        """
      type Query {
        test: AnotherObject
      }

      interface AnotherInterface {
        field(input: String): String
      }

      type AnotherObject implements AnotherInterface {
        field: String
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Interface field argument AnotherInterface.field(input:)"
                    " expected but AnotherObject.field does not provide it."
                ),
                "7:15 11:9",
            )
        ],
    )


def test_rejects_an_object_with_an_incorrectly_typed_interface_argument() raises:
    var schema = build_schema(
        """
      type Query {
        test: AnotherObject
      }

      interface AnotherInterface {
        field(input: String): String
      }

      type AnotherObject implements AnotherInterface {
        field(input: Int): String
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Interface field argument AnotherInterface.field(input:)"
                    " expects type String but AnotherObject.field(input:) is"
                    " type Int."
                ),
                "7:22 11:22",
            )
        ],
    )


def test_rejects_an_object_with_both_an_incorrectly_typed_field_and_argument() raises:
    var schema = build_schema(
        """
      type Query {
        test: AnotherObject
      }

      interface AnotherInterface {
        field(input: String): String
      }

      type AnotherObject implements AnotherInterface {
        field(input: Int): Int
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Interface field AnotherInterface.field expects type String"
                    " but AnotherObject.field is type Int."
                ),
                "7:31 11:28",
            ),
            error(
                (
                    "Interface field argument AnotherInterface.field(input:)"
                    " expects type String but AnotherObject.field(input:) is"
                    " type Int."
                ),
                "7:22 11:22",
            ),
        ],
    )


def test_rejects_an_object_which_implements_an_interface_field_along_with_additional_required_arguments() raises:
    var schema = build_schema(
        """
      type Query {
        test: AnotherObject
      }

      interface AnotherInterface {
        field(baseArg: String): String
      }

      type AnotherObject implements AnotherInterface {
        field(
          baseArg: String,
          requiredArg: String!
          optionalArg1: String,
          optionalArg2: String = "",
        ): String
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Object field AnotherObject.field includes required"
                    " argument requiredArg that is missing from the Interface"
                    " field AnotherInterface.field."
                ),
                "13:11 7:9",
            )
        ],
    )


def test_accepts_an_object_with_an_equivalently_wrapped_interface_field_type() raises:
    var schema = build_schema(
        """
      type Query {
        test: AnotherObject
      }

      interface AnotherInterface {
        field: [String]!
      }

      type AnotherObject implements AnotherInterface {
        field: [String]!
      }
    """
    )
    expect_valid(schema)


def test_rejects_an_object_with_a_non_list_interface_field_list_type() raises:
    var schema = build_schema(
        """
      type Query {
        test: AnotherObject
      }

      interface AnotherInterface {
        field: [String]
      }

      type AnotherObject implements AnotherInterface {
        field: String
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Interface field AnotherInterface.field expects type"
                    " [String] but AnotherObject.field is type String."
                ),
                "7:16 11:16",
            )
        ],
    )


def test_rejects_an_object_with_a_list_interface_field_non_list_type() raises:
    var schema = build_schema(
        """
      type Query {
        test: AnotherObject
      }

      interface AnotherInterface {
        field: String
      }

      type AnotherObject implements AnotherInterface {
        field: [String]
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Interface field AnotherInterface.field expects type String"
                    " but AnotherObject.field is type [String]."
                ),
                "7:16 11:16",
            )
        ],
    )


def test_accepts_an_object_with_a_subset_non_null_interface_field_type() raises:
    var schema = build_schema(
        """
      type Query {
        test: AnotherObject
      }

      interface AnotherInterface {
        field: String
      }

      type AnotherObject implements AnotherInterface {
        field: String!
      }
    """
    )
    expect_valid(schema)


def test_rejects_an_object_with_a_superset_nullable_interface_field_type() raises:
    var schema = build_schema(
        """
      type Query {
        test: AnotherObject
      }

      interface AnotherInterface {
        field: String!
      }

      type AnotherObject implements AnotherInterface {
        field: String
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Interface field AnotherInterface.field expects type"
                    " String! but AnotherObject.field is type String."
                ),
                "7:16 11:16",
            )
        ],
    )


def test_rejects_an_object_missing_a_transitive_interface() raises:
    var schema = build_schema(
        """
      type Query {
        test: AnotherObject
      }

      interface SuperInterface {
        field: String!
      }

      interface AnotherInterface implements SuperInterface {
        field: String!
      }

      type AnotherObject implements AnotherInterface {
        field: String!
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Type AnotherObject must implement SuperInterface because"
                    " it is implemented by AnotherInterface."
                ),
                "10:45 14:37",
            )
        ],
    )


# --- Interfaces must adhere to Interface they implement ----------------------


def test_accepts_an_interface_which_implements_an_interface() raises:
    var schema = build_schema(
        """
      type Query {
        test: ChildInterface
      }

      interface ParentInterface {
        field(input: String): String
      }

      interface ChildInterface implements ParentInterface {
        field(input: String): String
      }
    """
    )
    expect_valid(schema)


def test_accepts_an_interface_which_implements_an_interface_along_with_more_fields() raises:
    var schema = build_schema(
        """
      type Query {
        test: ChildInterface
      }

      interface ParentInterface {
        field(input: String): String
      }

      interface ChildInterface implements ParentInterface {
        field(input: String): String
        anotherField: String
      }
    """
    )
    expect_valid(schema)


def test_accepts_an_interface_which_implements_an_interface_field_along_with_additional_optional_arguments() raises:
    var schema = build_schema(
        """
      type Query {
        test: ChildInterface
      }

      interface ParentInterface {
        field(input: String): String
      }

      interface ChildInterface implements ParentInterface {
        field(input: String, anotherInput: String): String
      }
    """
    )
    expect_valid(schema)


def test_rejects_an_interface_missing_an_interface_field() raises:
    var schema = build_schema(
        """
      type Query {
        test: ChildInterface
      }

      interface ParentInterface {
        field(input: String): String
      }

      interface ChildInterface implements ParentInterface {
        anotherField: String
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Interface field ParentInterface.field expected but"
                    " ChildInterface does not provide it."
                ),
                "7:9 10:7",
            )
        ],
    )


def test_rejects_an_interface_with_an_incorrectly_typed_interface_field() raises:
    var schema = build_schema(
        """
      type Query {
        test: ChildInterface
      }

      interface ParentInterface {
        field(input: String): String
      }

      interface ChildInterface implements ParentInterface {
        field(input: String): Int
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Interface field ParentInterface.field expects type String"
                    " but ChildInterface.field is type Int."
                ),
                "7:31 11:31",
            )
        ],
    )


def test_rejects_an_interface_with_a_differently_typed_interface_field() raises:
    var schema = build_schema(
        """
      type Query {
        test: ChildInterface
      }

      type A { foo: String }
      type B { foo: String }

      interface ParentInterface {
        field: A
      }

      interface ChildInterface implements ParentInterface {
        field: B
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Interface field ParentInterface.field expects type A but"
                    " ChildInterface.field is type B."
                ),
                "10:16 14:16",
            )
        ],
    )


def test_accepts_an_interface_with_a_subtyped_interface_field_interface() raises:
    var schema = build_schema(
        """
      type Query {
        test: ChildInterface
      }

      interface ParentInterface {
        field: ParentInterface
      }

      interface ChildInterface implements ParentInterface {
        field: ChildInterface
      }
    """
    )
    expect_valid(schema)


def test_accepts_an_interface_with_a_subtyped_interface_field_union() raises:
    var schema = build_schema(
        """
      type Query {
        test: ChildInterface
      }

      type SomeObject {
        field: String
      }

      union SomeUnionType = SomeObject

      interface ParentInterface {
        field: SomeUnionType
      }

      interface ChildInterface implements ParentInterface {
        field: SomeObject
      }
    """
    )
    expect_valid(schema)


def test_rejects_an_interface_implementing_a_non_interface_type() raises:
    var schema = build_schema(
        """
      type Query {
        field: String
      }

      input SomeInputObject {
        field: String
      }

      interface BadInterface implements SomeInputObject {
        field: String
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Type BadInterface must only implement Interface types, it"
                    " cannot implement SomeInputObject."
                ),
                "10:41",
            )
        ],
    )


def test_rejects_an_interface_missing_an_interface_argument() raises:
    var schema = build_schema(
        """
      type Query {
        test: ChildInterface
      }

      interface ParentInterface {
        field(input: String): String
      }

      interface ChildInterface implements ParentInterface {
        field: String
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Interface field argument ParentInterface.field(input:)"
                    " expected but ChildInterface.field does not provide it."
                ),
                "7:15 11:9",
            )
        ],
    )


def test_rejects_an_interface_with_an_incorrectly_typed_interface_argument() raises:
    var schema = build_schema(
        """
      type Query {
        test: ChildInterface
      }

      interface ParentInterface {
        field(input: String): String
      }

      interface ChildInterface implements ParentInterface {
        field(input: Int): String
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Interface field argument ParentInterface.field(input:)"
                    " expects type String but ChildInterface.field(input:) is"
                    " type Int."
                ),
                "7:22 11:22",
            )
        ],
    )


def test_rejects_an_interface_with_both_an_incorrectly_typed_field_and_argument() raises:
    var schema = build_schema(
        """
      type Query {
        test: ChildInterface
      }

      interface ParentInterface {
        field(input: String): String
      }

      interface ChildInterface implements ParentInterface {
        field(input: Int): Int
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Interface field ParentInterface.field expects type String"
                    " but ChildInterface.field is type Int."
                ),
                "7:31 11:28",
            ),
            error(
                (
                    "Interface field argument ParentInterface.field(input:)"
                    " expects type String but ChildInterface.field(input:) is"
                    " type Int."
                ),
                "7:22 11:22",
            ),
        ],
    )


def test_rejects_an_interface_which_implements_an_interface_field_along_with_additional_required_arguments() raises:
    var schema = build_schema(
        """
      type Query {
        test: ChildInterface
      }

      interface ParentInterface {
        field(baseArg: String): String
      }

      interface ChildInterface implements ParentInterface {
        field(
          baseArg: String,
          requiredArg: String!
          optionalArg1: String,
          optionalArg2: String = "",
        ): String
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Object field ChildInterface.field includes required"
                    " argument requiredArg that is missing from the Interface"
                    " field ParentInterface.field."
                ),
                "13:11 7:9",
            )
        ],
    )


def test_accepts_an_interface_with_an_equivalently_wrapped_interface_field_type() raises:
    var schema = build_schema(
        """
      type Query {
        test: ChildInterface
      }

      interface ParentInterface {
        field: [String]!
      }

      interface ChildInterface implements ParentInterface {
        field: [String]!
      }
    """
    )
    expect_valid(schema)


def test_rejects_an_interface_with_a_non_list_interface_field_list_type() raises:
    var schema = build_schema(
        """
      type Query {
        test: ChildInterface
      }

      interface ParentInterface {
        field: [String]
      }

      interface ChildInterface implements ParentInterface {
        field: String
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Interface field ParentInterface.field expects type"
                    " [String] but ChildInterface.field is type String."
                ),
                "7:16 11:16",
            )
        ],
    )


def test_rejects_an_interface_with_a_list_interface_field_non_list_type() raises:
    var schema = build_schema(
        """
      type Query {
        test: ChildInterface
      }

      interface ParentInterface {
        field: String
      }

      interface ChildInterface implements ParentInterface {
        field: [String]
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Interface field ParentInterface.field expects type String"
                    " but ChildInterface.field is type [String]."
                ),
                "7:16 11:16",
            )
        ],
    )


def test_accepts_an_interface_with_a_subset_non_null_interface_field_type() raises:
    var schema = build_schema(
        """
      type Query {
        test: ChildInterface
      }

      interface ParentInterface {
        field: String
      }

      interface ChildInterface implements ParentInterface {
        field: String!
      }
    """
    )
    expect_valid(schema)


def test_rejects_an_interface_with_a_superset_nullable_interface_field_type() raises:
    var schema = build_schema(
        """
      type Query {
        test: ChildInterface
      }

      interface ParentInterface {
        field: String!
      }

      interface ChildInterface implements ParentInterface {
        field: String
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Interface field ParentInterface.field expects type String!"
                    " but ChildInterface.field is type String."
                ),
                "7:16 11:16",
            )
        ],
    )


def test_rejects_an_object_missing_a_transitive_interface_of_an_interface() raises:
    # Upstream names this case "rejects an Object missing a transitive
    # interface" too; a Mojo test needs a unique name.
    var schema = build_schema(
        """
      type Query {
        test: ChildInterface
      }

      interface SuperInterface {
        field: String!
      }

      interface ParentInterface implements SuperInterface {
        field: String!
      }

      interface ChildInterface implements ParentInterface {
        field: String!
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Type ChildInterface must implement SuperInterface because"
                    " it is implemented by ParentInterface."
                ),
                "10:44 14:43",
            )
        ],
    )


def test_rejects_a_self_reference_interface() raises:
    var schema = build_schema(
        """
      type Query {
        test: FooInterface
      }

      interface FooInterface implements FooInterface {
        field: String
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Type FooInterface cannot implement itself because it would"
                    " create a circular reference."
                ),
                "6:41",
            )
        ],
    )


def test_rejects_a_circular_interface_implementation() raises:
    var schema = build_schema(
        """
      type Query {
        test: FooInterface
      }

      interface FooInterface implements BarInterface {
        field: String
      }

      interface BarInterface implements FooInterface {
        field: String
      }
    """
    )
    expect_errors(
        schema,
        [
            error(
                (
                    "Type FooInterface cannot implement BarInterface because it"
                    " would create a circular reference."
                ),
                "10:41 6:41",
            ),
            error(
                (
                    "Type BarInterface cannot implement FooInterface because it"
                    " would create a circular reference."
                ),
                "6:41 10:41",
            ),
        ],
    )


# --- assertValidSchema -------------------------------------------------------


def test_does_not_throw_on_valid_schemas() raises:
    var schema = build_schema(
        """
      type Query {
        foo: String
      }
    """
    )
    assert_valid_schema(schema)


def test_combines_multiple_errors() raises:
    var schema = build_schema("type SomeType")
    var message = String("")
    try:
        assert_valid_schema(schema)
    except e:
        message = String(e)
    assert_equal(
        message,
        (
            "Query root type must be provided.\n\nType SomeType must define one"
            " or more fields."
        ),
    )


# --- Mojo tests --------------------------------------------------------------


def test_type_index_out_of_range_is_undefined() raises:
    var schema = schema_with_object_field("String")
    var field = schema.field_named(schema.type_named("BadObject"), "badField")
    schema.fields[field].type = TypeRef.of(len(schema.types))
    expect_errors(
        schema,
        [
            error(
                "The type of BadObject.badField must be Output Type but got:"
                " undefined."
            )
        ],
    )


def test_query_type_out_of_range_is_not_provided() raises:
    var schema = constructed("type Query { f: String }")
    schema.query_type = Int32(len(schema.types))
    expect_errors(schema, [error("Query root type must be provided.")])


def test_rejects_a_type_map_entry_that_is_not_a_type() raises:
    var schema = constructed("type Query { f: String }\nscalar Odd")
    schema.type_map.append(NO_TYPE)
    schema.types[schema.type_named("Odd")].kind = TypeKind(9)
    expect_errors(
        schema,
        [
            error("Expected GraphQL named type but got: Odd."),
            error("Expected GraphQL named type but got: undefined."),
        ],
    )


def test_rejects_a_union_member_that_is_not_a_type() raises:
    var schema = constructed(
        "type Query { f: BadUnion }\ntype A { f: String }\nunion BadUnion = A"
    )
    var union = schema.type_named("BadUnion")
    schema.type_lists[Int(schema.types[union].members.start)] = NO_TYPE
    expect_errors(
        schema,
        [
            error(
                "Union type BadUnion can only include Object types, it cannot"
                " include undefined."
            )
        ],
    )


def test_rejects_types_with_names_that_start_with_two_underscores() raises:
    var schema = build_schema(
        """
type Query { f(a: __In): __Out }
type __Out { f: String }
input __In { f: String }
directive @__dir(__arg: String) on QUERY
"""
    )
    var reserved = String(
        '" must not begin with "__", which is reserved by GraphQL'
        " introspection."
    )
    expect_errors(
        schema,
        [
            error('Name "__dir' + reserved, "5:1"),
            error('Name "__arg' + reserved, "5:18"),
            error('Name "__Out' + reserved, "3:1"),
            error('Name "__In' + reserved, "4:1"),
        ],
    )


def test_locates_a_root_type_of_a_described_schema() raises:
    var schema = build_schema(
        """
"Described"
schema @a { query: In }
directive @a on SCHEMA
input In { f: String }
"""
    )
    expect_errors(
        schema,
        [
            error(
                "Query root type must be Object type, it cannot be In.",
                "3:20",
            )
        ],
    )


def test_finds_the_deprecated_directive_after_another_directive() raises:
    var schema = build_schema(
        """
directive @a on ARGUMENT_DEFINITION
type Query { f(x: String! @a @deprecated): String }
"""
    )
    expect_errors(
        schema,
        [
            error(
                "Required argument Query.f(x:) cannot be deprecated.",
                "3:30 3:19",
            )
        ],
    )


def test_locates_a_deprecated_argument_without_the_directive() raises:
    var schema = build_schema("type Query { f(x: String!): String }")
    var field = schema.field_named(schema.type_named("Query"), "f")
    var arg = schema.argument_named(field, "x")
    schema.input_values[arg].is_deprecated = True
    expect_errors(
        schema,
        [error("Required argument Query.f(x:) cannot be deprecated.", "1:19")],
    )


def test_rejects_a_deprecated_required_argument_without_ast() raises:
    var schema = constructed("type Query { f(x: String! @deprecated): String }")
    expect_errors(
        schema,
        [error("Required argument Query.f(x:) cannot be deprecated.")],
    )


def test_accepts_an_object_that_implements_a_transitive_interface() raises:
    var schema = build_schema(
        """
interface Super { f: String }
interface Parent implements Super { f: String }
type Query implements Parent & Super { f: String }
"""
    )
    expect_valid(schema)


def test_accepts_a_required_argument_that_the_interface_has() raises:
    var schema = build_schema(
        """
interface I { f(a: String!): String }
type Query implements I { f(a: String!): String }
"""
    )
    expect_valid(schema)


def test_accepts_an_input_object_reached_twice_without_a_cycle() raises:
    var schema = build_schema(
        """
type Query { f(a: A): String }
input A { b: B!, c: B! }
input B { f: String }
"""
    )
    expect_valid(schema)


def test_validates_each_call_again() raises:
    var schema = build_schema("type Query { f: String }")
    expect_valid(schema)
    schema.query_type = NO_TYPE
    assert_equal(len(validate_schema(schema)), 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

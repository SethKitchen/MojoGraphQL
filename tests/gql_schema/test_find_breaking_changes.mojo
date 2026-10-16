# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_schema.find_breaking_changes`, ported from graphql-js
16.14.2 `src/utilities/__tests__/findBreakingChanges-test.ts`.

Each change is compared as `TYPE: description`. graphql-js makes the
schemas of "a directive was implicitly removed" with the `GraphQLSchema`
constructor and a list of directives without `@deprecated`. A schema here
is built from SDL, which always adds the specified directives, so the test
removes `@deprecated` from the list of a built schema. More tests cover
defaults that are not valid for their type, and the names of the change
types.
"""

from _helpers import dedent
from gql_language.ast import Document
from gql_schema.build import build_ast_schema, build_schema
from gql_schema.definition import Schema
from gql_schema.find_breaking_changes import (
    BreakingChangeType,
    DangerousChangeType,
    find_breaking_changes,
    find_dangerous_changes,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def breaking(old_schema: Schema, new_schema: Schema) raises -> String:
    """Return the breaking changes, one `TYPE: description` per line."""
    var out = String("")
    for change in find_breaking_changes(old_schema, new_schema):
        out += String(change) + "\n"
    return out^


def dangerous(old_schema: Schema, new_schema: Schema) raises -> String:
    """Return the dangerous changes, one `TYPE: description` per line."""
    var out = String("")
    for change in find_dangerous_changes(old_schema, new_schema):
        out += String(change) + "\n"
    return out^


def expect_breaking(old_sdl: String, new_sdl: String, expected: String) raises:
    """Assert the breaking changes between two schemas built from SDL."""
    assert_equal(
        breaking(build_schema(old_sdl), build_schema(new_sdl)), expected
    )


def expect_dangerous(old_sdl: String, new_sdl: String, expected: String) raises:
    """Assert the dangerous changes between two schemas built from SDL."""
    assert_equal(
        dangerous(build_schema(old_sdl), build_schema(new_sdl)), expected
    )


def lines(text: String) -> String:
    """Return dedented text with a line break after the last line."""
    return dedent(text) + "\n"


def test_detects_type_removed_or_not() raises:
    var old_schema = build_schema(
        """
      type Type1
      type Type2
    """
    )
    var new_schema = build_schema("type Type2")
    assert_equal(
        breaking(old_schema, new_schema), "TYPE_REMOVED: Type1 was removed.\n"
    )
    assert_equal(breaking(old_schema, old_schema), "")


def test_detects_standard_scalar_removed() raises:
    var old_schema = build_schema("type Query { foo: Float }")
    var new_schema = build_schema("type Query { foo: String }")
    assert_equal(
        breaking(old_schema, new_schema),
        lines(
            """
            TYPE_REMOVED: Standard scalar Float was removed because it is not referenced anymore.
            FIELD_CHANGED_KIND: Query.foo changed type from Float to String.
            """
        ),
    )
    assert_equal(breaking(old_schema, old_schema), "")


def test_detects_type_changed_kind() raises:
    expect_breaking(
        """
      scalar TypeWasScalarBecomesEnum
      interface TypeWasInterfaceBecomesUnion
      type TypeWasObjectBecomesInputObject
    """,
        """
      enum TypeWasScalarBecomesEnum
      union TypeWasInterfaceBecomesUnion
      input TypeWasObjectBecomesInputObject
    """,
        lines(
            """
            TYPE_CHANGED_KIND: TypeWasScalarBecomesEnum changed from a Scalar type to an Enum type.
            TYPE_CHANGED_KIND: TypeWasInterfaceBecomesUnion changed from an Interface type to a Union type.
            TYPE_CHANGED_KIND: TypeWasObjectBecomesInputObject changed from an Object type to an Input type.
            """
        ),
    )


def test_detects_field_deleted_or_changed_type() raises:
    expect_breaking(
        """
      type TypeA
      type TypeB

      interface Type1 {
        field1: TypeA
        field2: String
        field3: String
        field4: TypeA
        field6: String
        field7: [String]
        field8: Int
        field9: Int!
        field10: [Int]!
        field11: Int
        field12: [Int]
        field13: [Int!]
        field14: [Int]
        field15: [[Int]]
        field16: Int!
        field17: [Int]
        field18: [[Int!]!]
      }
    """,
        """
      type TypeA
      type TypeB

      interface Type1 {
        field1: TypeA
        field3: Boolean
        field4: TypeB
        field5: String
        field6: [String]
        field7: String
        field8: Int!
        field9: Int
        field10: [Int]
        field11: [Int]!
        field12: [Int!]
        field13: [Int]
        field14: [[Int]]
        field15: [Int]
        field16: [Int]!
        field17: [Int]!
        field18: [[Int!]]
      }
    """,
        lines(
            """
            FIELD_REMOVED: Type1.field2 was removed.
            FIELD_CHANGED_KIND: Type1.field3 changed type from String to Boolean.
            FIELD_CHANGED_KIND: Type1.field4 changed type from TypeA to TypeB.
            FIELD_CHANGED_KIND: Type1.field6 changed type from String to [String].
            FIELD_CHANGED_KIND: Type1.field7 changed type from [String] to String.
            FIELD_CHANGED_KIND: Type1.field9 changed type from Int! to Int.
            FIELD_CHANGED_KIND: Type1.field10 changed type from [Int]! to [Int].
            FIELD_CHANGED_KIND: Type1.field11 changed type from Int to [Int]!.
            FIELD_CHANGED_KIND: Type1.field13 changed type from [Int!] to [Int].
            FIELD_CHANGED_KIND: Type1.field14 changed type from [Int] to [[Int]].
            FIELD_CHANGED_KIND: Type1.field15 changed type from [[Int]] to [Int].
            FIELD_CHANGED_KIND: Type1.field16 changed type from Int! to [Int]!.
            FIELD_CHANGED_KIND: Type1.field18 changed type from [[Int!]!] to [[Int!]].
            """
        ),
    )


def test_detects_input_fields_changed_kind_or_removed() raises:
    expect_breaking(
        """
      input InputType1 {
        field1: String
        field2: Boolean
        field3: [String]
        field4: String!
        field5: String
        field6: [Int]
        field7: [Int]!
        field8: Int
        field9: [Int]
        field10: [Int!]
        field11: [Int]
        field12: [[Int]]
        field13: Int!
        field14: [[Int]!]
        field15: [[Int]!]
      }
    """,
        """
      input InputType1 {
        field1: Int
        field3: String
        field4: String
        field5: String!
        field6: [Int]!
        field7: [Int]
        field8: [Int]!
        field9: [Int!]
        field10: [Int]
        field11: [[Int]]
        field12: [Int]
        field13: [Int]!
        field14: [[Int]]
        field15: [[Int!]!]
      }
    """,
        lines(
            """
            FIELD_REMOVED: InputType1.field2 was removed.
            FIELD_CHANGED_KIND: InputType1.field1 changed type from String to Int.
            FIELD_CHANGED_KIND: InputType1.field3 changed type from [String] to String.
            FIELD_CHANGED_KIND: InputType1.field5 changed type from String to String!.
            FIELD_CHANGED_KIND: InputType1.field6 changed type from [Int] to [Int]!.
            FIELD_CHANGED_KIND: InputType1.field8 changed type from Int to [Int]!.
            FIELD_CHANGED_KIND: InputType1.field9 changed type from [Int] to [Int!].
            FIELD_CHANGED_KIND: InputType1.field11 changed type from [Int] to [[Int]].
            FIELD_CHANGED_KIND: InputType1.field12 changed type from [[Int]] to [Int].
            FIELD_CHANGED_KIND: InputType1.field13 changed type from Int! to [Int]!.
            FIELD_CHANGED_KIND: InputType1.field15 changed type from [[Int]!] to [[Int!]!].
            """
        ),
    )


def test_detects_required_input_field_added() raises:
    expect_breaking(
        """
      input InputType1 {
        field1: String
      }
    """,
        """
      input InputType1 {
        field1: String
        requiredField: Int!
        optionalField1: Boolean
        optionalField2: Boolean! = false
      }
    """,
        (
            "REQUIRED_INPUT_FIELD_ADDED: A required field requiredField on"
            " input type InputType1 was added.\n"
        ),
    )


def test_detects_type_removed_from_union() raises:
    expect_breaking(
        """
      type Type1
      type Type2
      type Type3

      union UnionType1 = Type1 | Type2
    """,
        """
      type Type1
      type Type2
      type Type3

      union UnionType1 = Type1 | Type3
    """,
        (
            "TYPE_REMOVED_FROM_UNION: Type2 was removed from union type"
            " UnionType1.\n"
        ),
    )


def test_detects_value_removed_from_enum() raises:
    expect_breaking(
        """
      enum EnumType1 {
        VALUE0
        VALUE1
        VALUE2
      }
    """,
        """
      enum EnumType1 {
        VALUE0
        VALUE2
        VALUE3
      }
    """,
        (
            "VALUE_REMOVED_FROM_ENUM: VALUE1 was removed from enum type"
            " EnumType1.\n"
        ),
    )


def test_detects_field_argument_removed() raises:
    expect_breaking(
        """
      interface Interface1 {
        field1(arg1: Boolean, objectArg: String): String
      }

      type Type1 {
        field1(name: String): String
      }
    """,
        """
      interface Interface1 {
        field1: String
      }

      type Type1 {
        field1: String
      }
    """,
        lines(
            """
            ARG_REMOVED: Interface1.field1 arg arg1 was removed.
            ARG_REMOVED: Interface1.field1 arg objectArg was removed.
            ARG_REMOVED: Type1.field1 arg name was removed.
            """
        ),
    )


def test_detects_field_argument_changed_type() raises:
    expect_breaking(
        """
      type Type1 {
        field1(
          arg1: String
          arg2: String
          arg3: [String]
          arg4: String
          arg5: String!
          arg6: String!
          arg7: [Int]!
          arg8: Int
          arg9: [Int]
          arg10: [Int!]
          arg11: [Int]
          arg12: [[Int]]
          arg13: Int!
          arg14: [[Int]!]
          arg15: [[Int]!]
        ): String
      }
    """,
        """
      type Type1 {
        field1(
          arg1: Int
          arg2: [String]
          arg3: String
          arg4: String!
          arg5: Int
          arg6: Int!
          arg7: [Int]
          arg8: [Int]!
          arg9: [Int!]
          arg10: [Int]
          arg11: [[Int]]
          arg12: [Int]
          arg13: [Int]!
          arg14: [[Int]]
          arg15: [[Int!]!]
         ): String
      }
    """,
        lines(
            """
            ARG_CHANGED_KIND: Type1.field1 arg arg1 has changed type from String to Int.
            ARG_CHANGED_KIND: Type1.field1 arg arg2 has changed type from String to [String].
            ARG_CHANGED_KIND: Type1.field1 arg arg3 has changed type from [String] to String.
            ARG_CHANGED_KIND: Type1.field1 arg arg4 has changed type from String to String!.
            ARG_CHANGED_KIND: Type1.field1 arg arg5 has changed type from String! to Int.
            ARG_CHANGED_KIND: Type1.field1 arg arg6 has changed type from String! to Int!.
            ARG_CHANGED_KIND: Type1.field1 arg arg8 has changed type from Int to [Int]!.
            ARG_CHANGED_KIND: Type1.field1 arg arg9 has changed type from [Int] to [Int!].
            ARG_CHANGED_KIND: Type1.field1 arg arg11 has changed type from [Int] to [[Int]].
            ARG_CHANGED_KIND: Type1.field1 arg arg12 has changed type from [[Int]] to [Int].
            ARG_CHANGED_KIND: Type1.field1 arg arg13 has changed type from Int! to [Int]!.
            ARG_CHANGED_KIND: Type1.field1 arg arg15 has changed type from [[Int]!] to [[Int!]!].
            """
        ),
    )


def test_detects_required_field_argument_added() raises:
    expect_breaking(
        """
      type Type1 {
        field1(arg1: String): String
      }
    """,
        """
      type Type1 {
        field1(
          arg1: String,
          newRequiredArg: String!
          newOptionalArg1: Int
          newOptionalArg2: Int! = 0
        ): String
      }
    """,
        (
            "REQUIRED_ARG_ADDED: A required arg newRequiredArg on Type1.field1"
            " was added.\n"
        ),
    )


def test_does_not_flag_args_with_same_type_signature() raises:
    var sdl = """
      input InputType1 {
        field1: String
      }

      type Type1 {
        field1(arg1: Int!, arg2: InputType1): Int
      }
    """
    expect_breaking(sdl, sdl, "")


def test_args_moving_away_from_non_null_are_not_breaking() raises:
    expect_breaking(
        "type Type1 { field1(name: String!): String }",
        "type Type1 { field1(name: String): String }",
        "",
    )


def test_detects_interfaces_removed_from_types() raises:
    expect_breaking(
        """
      interface Interface1

      type Type1 implements Interface1
    """,
        """
      interface Interface1

      type Type1
    """,
        (
            "IMPLEMENTED_INTERFACE_REMOVED: Type1 no longer implements"
            " interface Interface1.\n"
        ),
    )


def test_detects_interfaces_removed_from_interfaces() raises:
    expect_breaking(
        """
      interface Interface1

      interface Interface2 implements Interface1
    """,
        """
      interface Interface1

      interface Interface2
    """,
        (
            "IMPLEMENTED_INTERFACE_REMOVED: Interface2 no longer implements"
            " interface Interface1.\n"
        ),
    )


def test_ignores_changes_in_order_of_interfaces() raises:
    expect_breaking(
        """
      interface FirstInterface
      interface SecondInterface

      type Type1 implements FirstInterface & SecondInterface
    """,
        """
      interface FirstInterface
      interface SecondInterface

      type Type1 implements SecondInterface & FirstInterface
    """,
        "",
    )


def test_detects_all_breaking_changes() raises:
    expect_breaking(
        """
      directive @DirectiveThatIsRemoved on FIELD_DEFINITION

      directive @DirectiveThatRemovesArg(arg1: String) on FIELD_DEFINITION

      directive @NonNullDirectiveAdded on FIELD_DEFINITION

      directive @DirectiveThatWasRepeatable repeatable on FIELD_DEFINITION

      directive @DirectiveName on FIELD_DEFINITION | QUERY

      type ArgThatChanges {
        field1(id: Float): String
      }

      enum EnumTypeThatLosesAValue {
        VALUE0
        VALUE1
        VALUE2
      }

      interface Interface1
      type TypeThatLooseInterface1 implements Interface1

      type TypeInUnion1
      type TypeInUnion2
      union UnionTypeThatLosesAType = TypeInUnion1 | TypeInUnion2

      type TypeThatChangesType

      type TypeThatGetsRemoved

      interface TypeThatHasBreakingFieldChanges {
        field1: String
        field2: String
      }
    """,
        """
      directive @DirectiveThatRemovesArg on FIELD_DEFINITION

      directive @NonNullDirectiveAdded(arg1: Boolean!) on FIELD_DEFINITION

      directive @DirectiveThatWasRepeatable on FIELD_DEFINITION

      directive @DirectiveName on FIELD_DEFINITION

      type ArgThatChanges {
        field1(id: String): String
      }

      enum EnumTypeThatLosesAValue {
        VALUE1
        VALUE2
      }

      interface Interface1
      type TypeThatLooseInterface1

      type TypeInUnion1
      type TypeInUnion2
      union UnionTypeThatLosesAType = TypeInUnion1

      interface TypeThatChangesType

      interface TypeThatHasBreakingFieldChanges {
        field2: Boolean
      }
    """,
        lines(
            """
            TYPE_REMOVED: Standard scalar Float was removed because it is not referenced anymore.
            TYPE_REMOVED: TypeThatGetsRemoved was removed.
            ARG_CHANGED_KIND: ArgThatChanges.field1 arg id has changed type from Float to String.
            VALUE_REMOVED_FROM_ENUM: VALUE0 was removed from enum type EnumTypeThatLosesAValue.
            IMPLEMENTED_INTERFACE_REMOVED: TypeThatLooseInterface1 no longer implements interface Interface1.
            TYPE_REMOVED_FROM_UNION: TypeInUnion2 was removed from union type UnionTypeThatLosesAType.
            TYPE_CHANGED_KIND: TypeThatChangesType changed from an Object type to an Interface type.
            FIELD_REMOVED: TypeThatHasBreakingFieldChanges.field1 was removed.
            FIELD_CHANGED_KIND: TypeThatHasBreakingFieldChanges.field2 changed type from String to Boolean.
            DIRECTIVE_REMOVED: DirectiveThatIsRemoved was removed.
            DIRECTIVE_ARG_REMOVED: arg1 was removed from DirectiveThatRemovesArg.
            REQUIRED_DIRECTIVE_ARG_ADDED: A required arg arg1 on directive NonNullDirectiveAdded was added.
            DIRECTIVE_REPEATABLE_REMOVED: Repeatable flag was removed from DirectiveThatWasRepeatable.
            DIRECTIVE_LOCATION_REMOVED: QUERY was removed from DirectiveName.
            """
        ),
    )


def test_detects_directive_explicitly_removed() raises:
    expect_breaking(
        """
      directive @DirectiveThatIsRemoved on FIELD_DEFINITION
      directive @DirectiveThatStays on FIELD_DEFINITION
    """,
        "directive @DirectiveThatStays on FIELD_DEFINITION",
        "DIRECTIVE_REMOVED: DirectiveThatIsRemoved was removed.\n",
    )


def test_detects_directive_implicitly_removed() raises:
    var old_schema = build_ast_schema(List[Document]())
    var new_schema = old_schema.copy()
    var index = 0
    while new_schema.directives[index].name != "deprecated":
        index += 1
    _ = new_schema.directives.pop(index)
    assert_equal(
        breaking(old_schema, new_schema),
        "DIRECTIVE_REMOVED: deprecated was removed.\n",
    )


def test_detects_directive_argument_removed() raises:
    expect_breaking(
        "directive @DirectiveWithArg(arg1: String) on FIELD_DEFINITION",
        "directive @DirectiveWithArg on FIELD_DEFINITION",
        "DIRECTIVE_ARG_REMOVED: arg1 was removed from DirectiveWithArg.\n",
    )


def test_detects_optional_directive_argument_added() raises:
    expect_breaking(
        "directive @DirectiveName on FIELD_DEFINITION",
        """
      directive @DirectiveName(
        newRequiredArg: String!
        newOptionalArg1: Int
        newOptionalArg2: Int! = 0
      ) on FIELD_DEFINITION
    """,
        (
            "REQUIRED_DIRECTIVE_ARG_ADDED: A required arg newRequiredArg on"
            " directive DirectiveName was added.\n"
        ),
    )


def test_detects_removal_of_repeatable_flag() raises:
    expect_breaking(
        "directive @DirectiveName repeatable on OBJECT",
        "directive @DirectiveName on OBJECT",
        (
            "DIRECTIVE_REPEATABLE_REMOVED: Repeatable flag was removed from"
            " DirectiveName.\n"
        ),
    )


def test_keeps_repeatable_flag() raises:
    expect_breaking(
        "directive @DirectiveName repeatable on OBJECT",
        "directive @DirectiveName repeatable on OBJECT",
        "",
    )


def test_breaking_changes_are_not_dangerous() raises:
    expect_dangerous("type Type1 type Type2", "type Type2", "")


def test_detects_locations_removed_from_directive() raises:
    expect_breaking(
        "directive @DirectiveName on FIELD_DEFINITION | QUERY",
        "directive @DirectiveName on FIELD_DEFINITION",
        "DIRECTIVE_LOCATION_REMOVED: QUERY was removed from DirectiveName.\n",
    )


def test_detects_default_value_changed_on_argument() raises:
    var old_sdl = """
      input Input1 {
        innerInputArray: [Input2]
      }

      input Input2 {
        arrayField: [Int]
      }

      type Type1 {
        field1(
          withDefaultValue: String = "TO BE DELETED"
          stringArg: String = "test"
          emptyArray: [Int!] = []
          valueArray: [[String]] = [["a", "b"], ["c"]]
          complexObject: Input1 = {
            innerInputArray: [{ arrayField: [1, 2, 3] }]
          }
        ): String
      }
    """
    var old_schema = build_schema(old_sdl)
    var copy_of_old_schema = build_schema(old_sdl)
    assert_equal(dangerous(old_schema, copy_of_old_schema), "")
    var new_schema = build_schema(
        """
      input Input1 {
        innerInputArray: [Input2]
      }

      input Input2 {
        arrayField: [Int]
      }

      type Type1 {
        field1(
          withDefaultValue: String
          stringArg: String = "Test"
          emptyArray: [Int!] = [7]
          valueArray: [[String]] = [["b", "a"], ["d"]]
          complexObject: Input1 = {
            innerInputArray: [{ arrayField: [3, 2, 1] }]
          }
        ): String
      }
    """
    )
    assert_equal(
        dangerous(old_schema, new_schema),
        lines(
            """
            ARG_DEFAULT_VALUE_CHANGE: Type1.field1 arg withDefaultValue defaultValue was removed.
            ARG_DEFAULT_VALUE_CHANGE: Type1.field1 arg stringArg has changed defaultValue from "test" to "Test".
            ARG_DEFAULT_VALUE_CHANGE: Type1.field1 arg emptyArray has changed defaultValue from [] to [7].
            ARG_DEFAULT_VALUE_CHANGE: Type1.field1 arg valueArray has changed defaultValue from [["a", "b"], ["c"]] to [["b", "a"], ["d"]].
            ARG_DEFAULT_VALUE_CHANGE: Type1.field1 arg complexObject has changed defaultValue from {innerInputArray: [{arrayField: [1, 2, 3]}]} to {innerInputArray: [{arrayField: [3, 2, 1]}]}.
            """
        ),
    )


def test_ignores_field_order_of_default_value() raises:
    expect_dangerous(
        """
      input Input1 {
        a: String
        b: String
        c: String
      }

      type Type1 {
        field1(
          arg1: Input1 = { a: "a", b: "b", c: "c" }
        ): String
      }
    """,
        """
      input Input1 {
        a: String
        b: String
        c: String
      }

      type Type1 {
        field1(
          arg1: Input1 = { c: "c", b: "b", a: "a" }
        ): String
      }
    """,
        "",
    )


def test_ignores_field_definition_order() raises:
    expect_dangerous(
        """
      input Input1 {
        a: String
        b: String
        c: String
      }

      type Type1 {
        field1(
          arg1: Input1 = { a: "a", b: "b", c: "c" }
        ): String
      }
    """,
        """
      input Input1 {
        c: String
        b: String
        a: String
      }

      type Type1 {
        field1(
          arg1: Input1 = { a: "a", b: "b", c: "c" }
        ): String
      }
    """,
        "",
    )


def test_detects_value_added_to_enum() raises:
    expect_dangerous(
        "enum EnumType1 { VALUE0 VALUE1 }",
        "enum EnumType1 { VALUE0 VALUE1 VALUE2 }",
        "VALUE_ADDED_TO_ENUM: VALUE2 was added to enum type EnumType1.\n",
    )


def test_detects_interfaces_added_to_types() raises:
    expect_dangerous(
        """
      interface OldInterface
      interface NewInterface

      type Type1 implements OldInterface
    """,
        """
      interface OldInterface
      interface NewInterface

      type Type1 implements OldInterface & NewInterface
    """,
        (
            "IMPLEMENTED_INTERFACE_ADDED: NewInterface added to interfaces"
            " implemented by Type1.\n"
        ),
    )


def test_detects_interfaces_added_to_interfaces() raises:
    expect_dangerous(
        """
      interface OldInterface
      interface NewInterface

      interface Interface1 implements OldInterface
    """,
        """
      interface OldInterface
      interface NewInterface

      interface Interface1 implements OldInterface & NewInterface
    """,
        (
            "IMPLEMENTED_INTERFACE_ADDED: NewInterface added to interfaces"
            " implemented by Interface1.\n"
        ),
    )


def test_detects_type_added_to_union() raises:
    expect_dangerous(
        """
      type Type1
      type Type2

      union UnionType1 = Type1
    """,
        """
      type Type1
      type Type2

      union UnionType1 = Type1 | Type2
    """,
        "TYPE_ADDED_TO_UNION: Type2 was added to union type UnionType1.\n",
    )


def test_detects_optional_field_added_to_input() raises:
    expect_dangerous(
        "input InputType1 { field1: String }",
        "input InputType1 { field1: String field2: Int }",
        (
            "OPTIONAL_INPUT_FIELD_ADDED: An optional field field2 on input type"
            " InputType1 was added.\n"
        ),
    )


def test_finds_all_dangerous_changes() raises:
    expect_dangerous(
        """
      enum EnumType1 {
        VALUE0
        VALUE1
      }

      type Type1 {
        field1(argThatChangesDefaultValue: String = "test"): String
      }

      interface Interface1
      type TypeThatGainsInterface1

      type TypeInUnion1
      union UnionTypeThatGainsAType = TypeInUnion1
    """,
        """
      enum EnumType1 {
        VALUE0
        VALUE1
        VALUE2
      }

      type Type1 {
        field1(argThatChangesDefaultValue: String = "Test"): String
      }

      interface Interface1
      type TypeThatGainsInterface1 implements Interface1

      type TypeInUnion1
      type TypeInUnion2
      union UnionTypeThatGainsAType = TypeInUnion1 | TypeInUnion2
    """,
        lines(
            """
            VALUE_ADDED_TO_ENUM: VALUE2 was added to enum type EnumType1.
            ARG_DEFAULT_VALUE_CHANGE: Type1.field1 arg argThatChangesDefaultValue has changed defaultValue from "test" to "Test".
            IMPLEMENTED_INTERFACE_ADDED: Interface1 added to interfaces implemented by TypeThatGainsInterface1.
            TYPE_ADDED_TO_UNION: TypeInUnion2 was added to union type UnionTypeThatGainsAType.
            """
        ),
    )


def test_detects_optional_field_argument_added() raises:
    expect_dangerous(
        "type Type1 { field1(arg1: String): String }",
        "type Type1 { field1(arg1: String, arg2: String): String }",
        "OPTIONAL_ARG_ADDED: An optional arg arg2 on Type1.field1 was added.\n",
    )


def test_invalid_default_counts_as_none() raises:
    # graphql-js keeps `undefined` for a default that is not valid for the
    # type, so the argument is required, and no default was there before.
    expect_breaking(
        "type Type1 { field1: String }",
        'type Type1 { field1(arg1: Int! = "x"): String }',
        "REQUIRED_ARG_ADDED: A required arg arg1 on Type1.field1 was added.\n",
    )
    expect_dangerous(
        'type Type1 { field1(arg1: Int = "x"): String }',
        "type Type1 { field1(arg1: Int = 1): String }",
        "",
    )


def test_change_type_names() raises:
    assert_equal(BreakingChangeType.TYPE_REMOVED.text(), "TYPE_REMOVED")
    assert_equal(
        BreakingChangeType.DIRECTIVE_LOCATION_REMOVED.text(),
        "DIRECTIVE_LOCATION_REMOVED",
    )
    assert_true(BreakingChangeType.DIRECTIVE_LOCATION_REMOVED.is_valid())
    assert_false(BreakingChangeType(16).is_valid())
    assert_equal(BreakingChangeType(16).text(), "<invalid>")
    assert_equal(
        DangerousChangeType.ARG_DEFAULT_VALUE_CHANGE.text(),
        "ARG_DEFAULT_VALUE_CHANGE",
    )
    assert_true(DangerousChangeType.ARG_DEFAULT_VALUE_CHANGE.is_valid())
    assert_false(DangerousChangeType(6).is_valid())
    assert_equal(DangerousChangeType(6).text(), "<invalid>")
    assert_equal(
        String(DangerousChangeType.VALUE_ADDED_TO_ENUM), "VALUE_ADDED_TO_ENUM"
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

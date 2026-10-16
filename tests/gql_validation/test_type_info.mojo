# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_validation.type_info`, ported from graphql-js 16.14.2
`src/utilities/__tests__/TypeInfo-test.ts`.

graphql-js wraps a visitor with `visitWithTypeInfo`. These tests walk the
document themselves and call `TypeInfo.enter` before the visitor and
`TypeInfo.leave` after it, which is what `visitWithTypeInfo` does.

Not ported: `can be Object.toStringified` (no JavaScript string tag),
`provide exact same arguments to wrapped visitor` (`visitWithTypeInfo` is
not ported) and `maintains type info during edit` (`gql_language` has no
editing visitor).
"""

from gql_language.ast import NO_NODE, Document, Kind
from gql_language.parser import parse, parse_value
from gql_schema.build import BuildOptions, build_schema
from gql_schema.definition import NO_TYPE, Schema, TypeRef
from gql_validation.type_info import (
    NO_ARGUMENT,
    NO_FIELD,
    NO_TYPE_REF,
    SCHEMA_META_FIELD,
    TYPE_META_FIELD,
    TYPE_NAME_META_ARGUMENT,
    TYPENAME_META_FIELD,
    TypeInfo,
    has_default_value,
    is_defined,
    type_from_ast,
    type_kind,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime TEST_SCHEMA = """
  interface Pet {
    name: String
  }

  type Dog implements Pet {
    name: String
  }

  type Cat implements Pet {
    name: String
  }

  type Human {
    name: String
    pets: [Pet]
  }

  type Alien {
    name(surname: Boolean): String
  }

  type QueryRoot {
    human(id: ID): Human
    alien: Alien
  }

  schema {
    query: QueryRoot
  }
"""


def _type(schema: Schema, type: TypeRef) -> String:
    """graphql-js `String(type)`, or `null` for `undefined`."""
    if not is_defined(type):
        return String("null")
    return schema.type_name(type)


def _parent(schema: Schema, type: Int) -> String:
    """graphql-js `String(parentType)`, or `null` for `undefined`."""
    if type == NO_TYPE:
        return String("null")
    return schema.types[type].name


def _row(
    schema: Schema,
    document: Document,
    info: TypeInfo,
    event: String,
    node: Int,
    columns: Int,
) -> String:
    """One visited row: the event, the kind, a name's value, and the
    types."""
    var kind = document.kind(node)
    var out = event + " " + String(kind.text())
    if kind == Kind.NAME:
        out += " " + String(document.text(node))
    else:
        out += " null"
    if columns == 3:
        out += " " + _parent(schema, info.get_parent_type())
        out += " " + _type(schema, info.get_type())
        out += " " + _type(schema, info.get_input_type())
    elif columns == 2:
        out += " " + _parent(schema, info.get_parent_type())
        out += " " + _type(schema, info.get_type())
    else:
        out += " " + _type(schema, info.get_input_type())
    return out^


def _visit(
    schema: Schema,
    document: Document,
    root: Int,
    mut info: TypeInfo,
    columns: Int,
) -> List[String]:
    """Walk a subtree with a `TypeInfo`, as `visitWithTypeInfo` does, and
    list a row on entry to and exit from each node."""
    var rows = List[String]()
    var path: List[Int] = [root]
    info.enter(schema, document, root)
    rows.append(_row(schema, document, info, "enter", root, columns))
    var current = document.first_child(root)
    while len(path) > 0:
        if current != NO_NODE:
            path.append(current)
            info.enter(schema, document, current)
            rows.append(_row(schema, document, info, "enter", current, columns))
            current = document.first_child(current)
        else:
            var done = path.pop()
            rows.append(_row(schema, document, info, "leave", done, columns))
            info.leave(document, done)
            current = document.next_sibling(done) if len(path) > 0 else NO_NODE
    return rows^


def _expect_rows(rows: List[String], expected: List[String]) raises:
    var got = String("")
    for ref row in rows:
        got += row + "\n"
    var want = String("")
    for ref row in expected:
        want += row + "\n"
    assert_equal(got, want)


def test_allow_all_methods_to_be_called_before_entering_any_node() raises:
    var schema = build_schema("type Query { a: String }")
    var info = TypeInfo(schema)
    assert_false(is_defined(info.get_type()))
    assert_equal(info.get_parent_type(), NO_TYPE)
    assert_false(is_defined(info.get_input_type()))
    assert_false(is_defined(info.get_parent_input_type()))
    assert_equal(info.get_field_def(), NO_FIELD)
    assert_equal(info.get_default_value(), -1)
    assert_equal(info.get_directive(), NO_TYPE)
    assert_equal(info.get_argument(), NO_ARGUMENT)
    assert_equal(info.get_enum_value(), NO_TYPE)


def test_supports_different_operation_types() raises:
    var schema = build_schema(
        """
      schema {
        query: QueryRoot
        mutation: MutationRoot
        subscription: SubscriptionRoot
      }

      type QueryRoot {
        foo: String
      }

      type MutationRoot {
        bar: String
      }

      type SubscriptionRoot {
        baz: String
      }
    """
    )
    var document = parse(
        """
      query { foo }
      mutation { bar }
      subscription { baz }
    """
    )
    var info = TypeInfo(schema)
    var rows = _visit(schema, document, document.root, info, 3)
    var roots = List[String]()
    for ref row in rows:
        if row.startswith("enter OperationDefinition"):
            roots.append(row)
    _expect_rows(
        roots,
        [
            "enter OperationDefinition null null QueryRoot null",
            "enter OperationDefinition null null MutationRoot null",
            "enter OperationDefinition null null SubscriptionRoot null",
        ],
    )


def test_maintains_type_info_during_visit() raises:
    var schema = build_schema(TEST_SCHEMA)
    var document = parse(
        "{ human(id: 4) { name, pets { ... { name } }, unknown } }"
    )
    var info = TypeInfo(schema)
    _expect_rows(
        _visit(schema, document, document.root, info, 3),
        [
            "enter Document null null null null",
            "enter OperationDefinition null null QueryRoot null",
            "enter SelectionSet null QueryRoot QueryRoot null",
            "enter Field null QueryRoot Human null",
            "enter Name human QueryRoot Human null",
            "leave Name human QueryRoot Human null",
            "enter Argument null QueryRoot Human ID",
            "enter Name id QueryRoot Human ID",
            "leave Name id QueryRoot Human ID",
            "enter IntValue null QueryRoot Human ID",
            "leave IntValue null QueryRoot Human ID",
            "leave Argument null QueryRoot Human ID",
            "enter SelectionSet null Human Human null",
            "enter Field null Human String null",
            "enter Name name Human String null",
            "leave Name name Human String null",
            "leave Field null Human String null",
            "enter Field null Human [Pet] null",
            "enter Name pets Human [Pet] null",
            "leave Name pets Human [Pet] null",
            "enter SelectionSet null Pet [Pet] null",
            "enter InlineFragment null Pet Pet null",
            "enter SelectionSet null Pet Pet null",
            "enter Field null Pet String null",
            "enter Name name Pet String null",
            "leave Name name Pet String null",
            "leave Field null Pet String null",
            "leave SelectionSet null Pet Pet null",
            "leave InlineFragment null Pet Pet null",
            "leave SelectionSet null Pet [Pet] null",
            "leave Field null Human [Pet] null",
            "enter Field null Human null null",
            "enter Name unknown Human null null",
            "leave Name unknown Human null null",
            "leave Field null Human null null",
            "leave SelectionSet null Human Human null",
            "leave Field null QueryRoot Human null",
            "leave SelectionSet null QueryRoot QueryRoot null",
            "leave OperationDefinition null null QueryRoot null",
            "leave Document null null null null",
        ],
    )


def test_supports_traversals_of_input_values() raises:
    var schema = build_schema(
        """
      input ComplexInput {
        stringListField: [String]
      }
    """
    )
    var document = parse_value('{ stringListField: ["foo"] }')
    var complex = schema.type_named("ComplexInput")
    var info = TypeInfo(schema, TypeRef.of(complex))
    _expect_rows(
        _visit(schema, document, document.root, info, 1),
        [
            "enter ObjectValue null ComplexInput",
            "enter ObjectField null [String]",
            "enter Name stringListField [String]",
            "leave Name stringListField [String]",
            "enter ListValue null String",
            "enter StringValue null String",
            "leave StringValue null String",
            "leave ListValue null String",
            "leave ObjectField null [String]",
            "leave ObjectValue null ComplexInput",
        ],
    )


def test_supports_traversals_of_selection_sets() raises:
    var schema = build_schema(TEST_SCHEMA)
    var human = schema.type_named("Human")
    var info = TypeInfo(schema, TypeRef.of(human))
    var document = parse("{ name, pets { name } }")
    var operation = document.first_child(document.root)
    var selection_set = document.first_child(operation)
    _expect_rows(
        _visit(schema, document, selection_set, info, 2),
        [
            "enter SelectionSet null Human Human",
            "enter Field null Human String",
            "enter Name name Human String",
            "leave Name name Human String",
            "leave Field null Human String",
            "enter Field null Human [Pet]",
            "enter Name pets Human [Pet]",
            "leave Name pets Human [Pet]",
            "enter SelectionSet null Pet [Pet]",
            "enter Field null Pet String",
            "enter Name name Pet String",
            "leave Name name Pet String",
            "leave Field null Pet String",
            "leave SelectionSet null Pet [Pet]",
            "leave Field null Human [Pet]",
            "leave SelectionSet null Human Human",
        ],
    )


# --- beyond upstream ----------------------------------------------------------


def test_meta_fields_and_their_types() raises:
    var schema = build_schema(TEST_SCHEMA)
    var info = TypeInfo(schema)
    var query = Int(schema.query_type)
    var human = schema.type_named("Human")
    var pet = schema.type_named("Pet")
    assert_equal(info.field_def(schema, query, "__schema"), SCHEMA_META_FIELD)
    assert_equal(info.field_def(schema, query, "__type"), TYPE_META_FIELD)
    assert_equal(info.field_def(schema, pet, "__typename"), TYPENAME_META_FIELD)
    assert_equal(info.field_def(schema, human, "__schema"), NO_FIELD)
    assert_equal(info.field_def(schema, human, "__type"), NO_FIELD)
    assert_equal(info.field_def(schema, human, "__other"), NO_FIELD)
    assert_equal(info.field_def(schema, human, "__"), NO_FIELD)
    assert_equal(
        schema.type_name(info.field_type(schema, TYPENAME_META_FIELD)),
        "String!",
    )
    assert_equal(
        schema.type_name(info.field_type(schema, SCHEMA_META_FIELD)),
        "__Schema!",
    )
    assert_equal(
        schema.type_name(info.field_type(schema, TYPE_META_FIELD)), "__Type"
    )
    assert_equal(
        schema.type_name(info.argument_type(schema, TYPE_NAME_META_ARGUMENT)),
        "String!",
    )


def test_initial_types_of_each_kind() raises:
    var schema = build_schema(TEST_SCHEMA)
    var info = TypeInfo(schema, NO_TYPE_REF)
    assert_false(is_defined(info.get_type()))
    var list = TypeRef.of(schema.type_named("Pet")).list_of()
    info = TypeInfo(schema, list)
    assert_equal(schema.type_name(info.get_type()), "[Pet]")
    assert_equal(info.get_parent_type(), NO_TYPE)
    info = TypeInfo(schema, TypeRef.of(schema.type_named("String")))
    assert_equal(schema.type_name(info.get_type()), "String")
    assert_equal(schema.type_name(info.get_input_type()), "String")


def test_type_from_ast_and_kinds() raises:
    var schema = build_schema(TEST_SCHEMA)
    var document = parse("query ($a: [ID!]!, $b: Missing) { alien { name } }")
    var operation = document.first_child(document.root)
    var definition = document.first_child(operation)
    var type_node = document.next_sibling(document.first_child(definition))
    assert_equal(
        schema.type_name(type_from_ast(schema, document, type_node)), "[ID!]!"
    )
    var second = document.next_sibling(definition)
    var missing = document.next_sibling(document.first_child(second))
    assert_false(is_defined(type_from_ast(schema, document, missing)))
    assert_false(type_kind(schema, NO_TYPE_REF).is_valid())


def test_arguments_directives_and_enum_values() raises:
    var schema = build_schema(
        """
      enum Color { RED GREEN }
      input Filter { color: Color = RED, flag: Boolean, bad: Int = "x" }
      type Query {
        list(filter: Filter, colors: [Color], plain: Int): String
        __type: String
      }
    """
    )
    var document = parse(
        """
      {
        list(filter: { color: GREEN, flag: true, missing: 1 }, colors: [RED, BLUE], plain: BLUE, none: 1)
          @include(if: true) @unknown(x: 1)
        __type(name: "Query", other: 1)
      }
    """
    )
    var info = TypeInfo(schema)
    var rows = List[String]()
    var path: List[Int] = [document.root]
    info.enter(schema, document, document.root)
    var current = document.first_child(document.root)
    while len(path) > 0:
        if current != NO_NODE:
            path.append(current)
            info.enter(schema, document, current)
            var kind = document.kind(current)
            if kind == Kind.ARGUMENT or kind == Kind.OBJECT_FIELD:
                var holder = info.get_default_value()
                rows.append(
                    String(document.name(current))
                    + " argument="
                    + String(info.get_argument())
                    + " default="
                    + String(has_default_value(schema, holder))
                    + " directive="
                    + String(info.get_directive() != NO_TYPE)
                )
            elif kind == Kind.ENUM:
                rows.append(
                    String(document.text(current))
                    + " enum="
                    + String(info.get_enum_value() != NO_TYPE)
                )
            current = document.first_child(current)
        else:
            var done = path.pop()
            info.leave(document, done)
            current = document.next_sibling(done) if len(path) > 0 else NO_NODE
    var list_field = schema.field_named(Int(schema.query_type), "list")
    var filter = Int(schema.fields[list_field].arguments.start)
    var colors = filter + 1
    var plain = filter + 2
    var color_field = schema.input_field_named(
        schema.type_named("Filter"), "color"
    )
    var flag_field = color_field + 1
    var bad_field = color_field + 2
    assert_true(has_default_value(schema, color_field))
    assert_false(has_default_value(schema, flag_field))
    assert_false(has_default_value(schema, bad_field))
    _expect_rows(
        rows,
        [
            "filter argument="
            + String(filter)
            + " default=False directive=False",
            "color argument="
            + String(filter)
            + " default=True directive=False",
            "GREEN enum=True",
            "flag argument="
            + String(filter)
            + " default=False directive=False",
            "missing argument="
            + String(filter)
            + " default=False directive=False",
            "colors argument="
            + String(colors)
            + " default=False directive=False",
            "RED enum=True",
            "BLUE enum=False",
            "plain argument="
            + String(plain)
            + " default=False directive=False",
            "BLUE enum=False",
            "none argument=-1 default=False directive=False",
            "if argument="
            + String(
                schema.directive_argument_named(
                    schema.directive_named("include"), "if"
                )
            )
            + " default=False directive=True",
            "x argument=-1 default=False directive=False",
            "name argument=-2 default=False directive=False",
            "other argument=-1 default=False directive=False",
        ],
    )


def test_an_empty_schema_and_unusual_roots() raises:
    # A schema with no types: the meta fields have no types.
    var empty = Schema()
    var info = TypeInfo(empty)
    assert_false(is_defined(info.field_type(empty, TYPENAME_META_FIELD)))
    # A root type that is not an object type gives no type.
    var options = BuildOptions()
    options.assume_valid = True
    var schema = build_schema(
        "schema { query: I } interface I { a: String }", options
    )
    var document = parse("{ a }")
    var walk = TypeInfo(schema)
    walk.enter(schema, document, document.root)
    var operation = document.first_child(document.root)
    walk.enter(schema, document, operation)
    assert_false(is_defined(walk.get_type()))
    # `__typename` is a meta field only on a composite type.
    var string = schema.type_named("String")
    assert_equal(walk.field_def(schema, string, "__typename"), NO_FIELD)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

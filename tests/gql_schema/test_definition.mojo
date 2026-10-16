# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_schema.definition`: type kinds, type references, and the
schema lookups and relations.

graphql-js tests these parts of `type/definition.ts` and `type/schema.ts`
with its type constructors, in `definition-test.ts` and `schema-test.ts`.
This module builds the schemas from SDL and checks the same behavior:
`isInputType`, `isOutputType`, `isLeafType`, `isCompositeType`,
`isAbstractType`, `getNullableType`, `getNamedType`, `getPossibleTypes`,
`isSubType`, `getType` and the field and argument lookups.
"""

from gql_language.ast import Document
from gql_language.directive_location import DirectiveLocation
from gql_language.parser import parse
from gql_schema.build import build_ast_schema, build_schema
from gql_schema.definition import (
    NO_TYPE,
    AstRef,
    DirectiveDef,
    TypeKind,
    TypeRef,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_type_kind_text() raises:
    var kinds: List[TypeKind] = [
        TypeKind.SCALAR,
        TypeKind.OBJECT,
        TypeKind.INTERFACE,
        TypeKind.UNION,
        TypeKind.ENUM,
        TypeKind.INPUT_OBJECT,
        TypeKind(6),
    ]
    var texts: List[String] = [
        "SCALAR",
        "OBJECT",
        "INTERFACE",
        "UNION",
        "ENUM",
        "INPUT_OBJECT",
        "<invalid>",
    ]
    for index in range(len(kinds)):
        assert_equal(String(kinds[index].text()), texts[index])
        assert_equal(String(kinds[index]), texts[index])
        assert_equal(kinds[index].is_valid(), index < 6)


def test_type_kind_predicates() raises:
    # Columns: input, output, leaf, composite, abstract, has fields.
    var kinds: List[TypeKind] = [
        TypeKind.SCALAR,
        TypeKind.OBJECT,
        TypeKind.INTERFACE,
        TypeKind.UNION,
        TypeKind.ENUM,
        TypeKind.INPUT_OBJECT,
    ]
    var expected: List[String] = [
        "111000",
        "010101",
        "010111",
        "010110",
        "111000",
        "100000",
    ]
    for index in range(len(kinds)):
        var kind = kinds[index]
        var bits = String("")
        var flags: List[Bool] = [
            kind.is_input(),
            kind.is_output(),
            kind.is_leaf(),
            kind.is_composite(),
            kind.is_abstract(),
            kind.has_fields(),
        ]
        for flag in flags:
            bits += "1" if flag else "0"
        assert_equal(bits, expected[index])


def test_type_ref_wrappers() raises:
    var named = TypeRef.of(3)
    assert_false(named.is_wrapped())
    assert_true(named.of_type() == named)
    assert_true(named.nullable() == named)
    var list = named.non_null().list_of()
    var outer = list.non_null()
    assert_true(outer.is_non_null())
    assert_false(outer.is_list())
    assert_true(outer.nullable() == list)
    assert_true(list.is_list())
    assert_true(list.nullable() == list)
    assert_true(list.of_type() == named.non_null())
    assert_true(outer.unwrapped() == named)
    assert_false(outer == list)


def test_directive_allows() raises:
    var directive = DirectiveDef("foo")
    directive.locations = UInt32(1) << UInt32(DirectiveLocation.FIELD.value)
    assert_true(directive.allows(DirectiveLocation.FIELD))
    assert_false(directive.allows(DirectiveLocation.QUERY))


def many(prefix: String, suffix: String, count: Int) -> String:
    """Return `count` lines `prefix<i>suffix`."""
    var out = String("")
    for index in range(count):
        out += "  " + prefix + String(index) + suffix + "\n"
    return out^


def test_lookups_with_many_members() raises:
    # Twenty members put each owner's names in a name table.
    var schema = build_schema(
        "type Query {\n"
        + many("f", ": String", 20)
        + "  wide("
        + many("a", ": Int", 20)
        + "  ): String\n}\n"
        + "enum Wide {\n"
        + many("V", "", 20)
        + "}\n"
        + "input WideInput {\n"
        + many("i", ": Int", 20)
        + "}\n"
        + "directive @wide(\n"
        + many("d", ": Int", 20)
        + ") on FIELD\n"
    )
    var query = schema.type_named("Query")
    assert_equal(schema.fields[schema.field_named(query, "f19")].name, "f19")
    assert_equal(schema.field_named(query, "nope"), NO_TYPE)
    var wide = schema.field_named(query, "wide")
    assert_equal(
        schema.input_values[schema.argument_named(wide, "a17")].name, "a17"
    )
    assert_equal(schema.argument_named(wide, "nope"), NO_TYPE)
    var enum_type = schema.type_named("Wide")
    assert_equal(
        schema.enum_values[schema.enum_value_named(enum_type, "V12")].name,
        "V12",
    )
    assert_equal(schema.enum_value_named(enum_type, "nope"), NO_TYPE)
    var input = schema.type_named("WideInput")
    assert_equal(
        schema.input_values[schema.input_field_named(input, "i3")].name, "i3"
    )
    assert_equal(schema.input_field_named(input, "nope"), NO_TYPE)
    var directive = schema.directive_named("wide")
    assert_equal(
        schema.input_values[
            schema.directive_argument_named(directive, "d9")
        ].name,
        "d9",
    )
    assert_equal(schema.directive_argument_named(directive, "nope"), NO_TYPE)


def test_lookups_of_the_wrong_kind() raises:
    var schema = build_schema(
        "type Query {\n  a: Int\n}\nenum E {\n  A\n}\ninput I {\n  a: Int\n}"
    )
    var query = schema.type_named("Query")
    var enum_type = schema.type_named("E")
    var input = schema.type_named("I")
    assert_equal(schema.field_named(enum_type, "A"), NO_TYPE)
    assert_equal(schema.input_field_named(query, "a"), NO_TYPE)
    assert_equal(schema.enum_value_named(input, "a"), NO_TYPE)
    assert_equal(schema.enum_value_named(enum_type, "B"), NO_TYPE)
    assert_equal(schema.type_named("Missing"), NO_TYPE)


def test_register_type_name_twice() raises:
    var schema = build_schema("type Query")
    var count = len(schema.type_map)
    assert_false(schema.register_type_name(schema.type_named("Query")))
    assert_equal(len(schema.type_map), count)


def test_relations() raises:
    var schema = build_schema(
        """
      schema {
        query: Query
        mutation: Query
      }

      type Query implements Node & Named {
        id: ID
        name: String
      }

      type Other implements Node {
        id: ID
      }

      interface Node {
        id: ID
      }

      interface Named implements Node {
        id: ID
        name: String
      }

      union Any = Query | Other
    """
    )
    var query = schema.type_named("Query")
    var other = schema.type_named("Other")
    var node = schema.type_named("Node")
    var named = schema.type_named("Named")
    var any = schema.type_named("Any")
    assert_equal(schema.root_type(0), query)
    assert_equal(schema.root_type(1), query)
    assert_equal(schema.root_type(2), NO_TYPE)
    var possible = schema.possible_types(any)
    assert_equal(len(possible), 2)
    assert_equal(possible[1], other)
    var objects = schema.possible_types(node)
    assert_equal(len(objects), 2)
    assert_equal(len(schema.possible_types(query)), 0)
    assert_true(schema.is_possible_type(any, query))
    assert_true(schema.is_possible_type(node, other))
    assert_false(schema.is_possible_type(named, other))
    assert_true(schema.is_sub_type(node, named))
    assert_false(schema.is_sub_type(any, node))
    assert_false(schema.is_sub_type(query, other))
    var interfaces = schema.interfaces_of(query)
    assert_equal(len(interfaces), 2)
    assert_equal(interfaces[0], node)
    var fields = schema.field_indices(query)
    assert_equal(len(fields), 2)
    assert_equal(schema.fields[fields[1]].name, "name")
    assert_equal(len(schema.interfaces_of(any)), 0)
    assert_equal(len(schema.field_indices(any)), 0)


def test_type_name_and_descriptions() raises:
    var schema = build_schema('type Query {\n  "Ok"\n  a: [Int!]!\n}')
    var query = schema.type_named("Query")
    ref field = schema.fields[schema.field_named(query, "a")]
    assert_equal(schema.type_name(field.type), "[Int!]!")
    assert_equal(schema.description_text(field.description), "Ok")
    assert_equal(schema.description_text(AstRef.NONE), "")


def test_take_documents() raises:
    var documents = List[Document]()
    documents.append(parse("type Query"))
    documents.append(parse("type Other"))
    var schema = build_ast_schema(documents^)
    var back = schema^.take_documents()
    assert_equal(len(back), 2)
    assert_equal(String(back[1].name(back[1].definitions()[0])), "Other")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_language.ast` and `gql_language.directive_location`.

The kind predicates follow graphql-js 16.14.2 `language/predicates.ts`; the
cases come from `src/language/__tests__/predicates-test.ts`. The accessors
and the builder are this port's own API.
"""

from _ast_dump import dump, dump_root
from gql_language.ast import (
    FLAG_BLOCK,
    NO_NODE,
    Document,
    Kind,
    OperationType,
    Role,
)
from gql_language.directive_location import DirectiveLocation
from gql_language.parser import parse, parse_type
from gql_language.printer import print_ast, print_node
from gql_language.source import SourceLocation
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _accepts(kind: Kind, predicate: Int) -> Bool:
    """Apply predicate number `predicate` to a kind."""
    if predicate == 0:
        return kind.is_executable_definition()
    if predicate == 1:
        return kind.is_selection()
    if predicate == 2:
        return kind.is_value()
    if predicate == 3:
        return kind.is_type()
    if predicate == 4:
        return kind.is_type_system_definition()
    if predicate == 5:
        return kind.is_type_definition()
    if predicate == 6:
        return kind.is_type_system_extension()
    if predicate == 7:
        return kind.is_type_extension()
    return kind.is_schema_coordinate()


def kinds_where(predicate: Int) -> List[String]:
    """Return the names of the kinds a predicate accepts."""
    var out = List[String]()
    for value in range(49):
        var kind = Kind(UInt8(value))
        if _accepts(kind, predicate):
            out.append(String(kind.text()))
    return out^


def joined(names: List[String]) -> String:
    """Join names with commas."""
    var out = String("")
    for index in range(len(names)):
        if index > 0:
            out += ","
        out += names[index]
    return out^


def test_is_executable_definition_node() raises:
    assert_equal(
        joined(kinds_where(0)),
        "OperationDefinition,FragmentDefinition",
    )


def test_is_selection_node() raises:
    assert_equal(
        joined(kinds_where(1)),
        "Field,FragmentSpread,InlineFragment",
    )


def test_is_value_node() raises:
    assert_equal(
        joined(kinds_where(2)),
        "Variable,IntValue,FloatValue,StringValue,BooleanValue,NullValue,"
        + "EnumValue,ListValue,ObjectValue",
    )


def test_is_type_node() raises:
    assert_equal(joined(kinds_where(3)), "NamedType,ListType,NonNullType")


def test_is_type_system_definition_node() raises:
    assert_equal(
        joined(kinds_where(4)),
        "SchemaDefinition,ScalarTypeDefinition,ObjectTypeDefinition,"
        + "InterfaceTypeDefinition,UnionTypeDefinition,EnumTypeDefinition,"
        + "InputObjectTypeDefinition,DirectiveDefinition",
    )


def test_is_type_definition_node() raises:
    assert_equal(
        joined(kinds_where(5)),
        "ScalarTypeDefinition,ObjectTypeDefinition,InterfaceTypeDefinition,"
        + "UnionTypeDefinition,EnumTypeDefinition,InputObjectTypeDefinition",
    )


def test_is_type_system_extension_node() raises:
    assert_equal(
        joined(kinds_where(6)),
        "SchemaExtension,DirectiveExtension,ScalarTypeExtension,"
        + "ObjectTypeExtension,InterfaceTypeExtension,UnionTypeExtension,"
        + "EnumTypeExtension,InputObjectTypeExtension",
    )


def test_is_type_extension_node() raises:
    assert_equal(
        joined(kinds_where(7)),
        "ScalarTypeExtension,ObjectTypeExtension,InterfaceTypeExtension,"
        + "UnionTypeExtension,EnumTypeExtension,InputObjectTypeExtension",
    )


def test_is_schema_coordinate_node() raises:
    assert_equal(
        joined(kinds_where(8)),
        "TypeCoordinate,MemberCoordinate,ArgumentCoordinate,"
        + "DirectiveCoordinate,DirectiveArgumentCoordinate",
    )


def test_kind_role_and_operation_names() raises:
    assert_true(Kind.FIELD.is_valid())
    assert_false(Kind(49).is_valid())
    assert_equal(String(Kind(49).text()), "<invalid>")
    assert_equal(String(Kind.FIELD), "Field")
    assert_true(Role.SELECTION.is_valid())
    assert_false(Role(25).is_valid())
    assert_equal(String(Role(25).text()), "<invalid>")
    assert_equal(String(Role.SELECTION_SET), "selectionSet")
    assert_equal(String(Role.LIST_ITEM), "values")
    assert_true(OperationType.SUBSCRIPTION.is_valid())
    assert_false(OperationType(3).is_valid())
    assert_equal(String(OperationType(3).text()), "<invalid>")
    assert_equal(String(OperationType.MUTATION), "mutation")
    assert_equal(String(OperationType.QUERY), "query")
    assert_equal(String(OperationType.SUBSCRIPTION), "subscription")


def test_directive_locations() raises:
    assert_equal(DirectiveLocation.from_name("QUERY"), 0)
    assert_equal(DirectiveLocation.from_name("DIRECTIVE_DEFINITION"), 19)
    assert_equal(DirectiveLocation.from_name("NOPE"), -1)
    assert_true(DirectiveLocation.FIELD.is_valid())
    assert_false(DirectiveLocation(20).is_valid())
    assert_equal(String(DirectiveLocation(20).text()), "<invalid>")
    assert_equal(String(DirectiveLocation.INPUT_OBJECT), "INPUT_OBJECT")
    assert_true(DirectiveLocation.VARIABLE_DEFINITION.is_executable())
    assert_false(DirectiveLocation.SCHEMA.is_executable())


def test_accessors() raises:
    var document = parse(
        '"Op"\nquery Q($a: Int) { a: b(x: 1, y: 2) c }\n'
        + "directive @d repeatable on FIELD"
    )
    var definitions = document.definitions()
    assert_equal(len(definitions), 2)
    var operation = definitions[0]
    assert_equal(document.kind(operation), Kind.OPERATION_DEFINITION)
    assert_equal(document.role(operation), Role.DEFINITION)
    assert_equal(document.operation(operation), OperationType.QUERY)
    assert_equal(String(document.name(operation)), "Q")
    assert_true(document.has_description(operation))
    assert_equal(document.description(operation), "Op")
    assert_equal(document.location(operation), SourceLocation(1, 1))
    var selections = document.child(operation, Role.SELECTION_SET)
    var fields = document.children(selections, Role.SELECTION)
    assert_equal(len(fields), 2)
    assert_equal(document.count(fields[0], Role.ARGUMENT), 2)
    assert_equal(document.count(fields[0], Role.DIRECTIVE), 0)
    var first = document.child(fields[0], Role.ARGUMENT)
    var second = document.next_with_role(first)
    assert_equal(String(document.name(second)), "y")
    assert_equal(document.next_with_role(second), NO_NODE)
    assert_true(document.has_text(document.child(fields[0], Role.ALIAS), "a"))
    assert_false(document.has_text(document.child(fields[0], Role.NAME), "a"))
    assert_equal(document.child(fields[1], Role.ARGUMENT), NO_NODE)
    assert_equal(String(document.name(selections)), "")
    assert_false(document.has_description(fields[1]))
    assert_equal(document.description(fields[1]), "")
    var directive = definitions[1]
    assert_true(document.is_repeatable(directive))
    assert_false(document.is_repeatable(operation))
    var variable = document.child(operation, Role.VARIABLE_DEFINITION)
    assert_equal(
        String(document.named_type(document.child(variable, Role.TYPE))),
        "Int",
    )
    var wrapped = parse_type("[[Foo!]]!")
    assert_equal(String(wrapped.named_type(wrapped.root)), "Foo")


def test_builder_makes_printable_documents() raises:
    var document = Document()
    var operation = document.add_child(
        document.root,
        Kind.OPERATION_DEFINITION,
        Role.DEFINITION,
        OperationType.MUTATION.value,
    )
    _ = document.add_name(operation, Role.NAME, "Like")
    var selections = document.add_child(
        operation, Kind.SELECTION_SET, Role.SELECTION_SET
    )
    var field = document.add_child(selections, Kind.FIELD, Role.SELECTION)
    _ = document.add_name(field, Role.NAME, "like")
    var argument = document.add_child(field, Kind.ARGUMENT, Role.ARGUMENT)
    _ = document.add_name(argument, Role.NAME, "story")
    var value = document.add_text(Kind.STRING, Role.VALUE, 'a "b"')
    document.append_child(argument, value)
    var description = document.add_text(
        Kind.STRING, Role.DESCRIPTION, "Say\nso", FLAG_BLOCK
    )
    # Appended last, but printed first: the printer reads by role, as
    # graphql-js reads the `description` property.
    document.append_child(operation, description)
    assert_equal(document.string_value(value), 'a "b"')
    assert_equal(document.description(operation), "Say\nso")
    assert_equal(
        print_ast(document),
        '"""\nSay\nso\n"""\nmutation Like {\n  like(story: "a \\"b\\"")\n}',
    )


def test_copy_subtree_keeps_text_and_flags() raises:
    var source = parse(
        'query { a(s: "x\\ny", b: """\n  z\n""", t: true, e: E, f: 1.5, i: 2)'
        + " @skip(if: false) { b } }"
    )
    var copy = Document()
    var operation = source.definitions()[0]
    var node = copy.copy_subtree(source, operation, Role.DEFINITION)
    copy.append_child(copy.root, node)
    assert_equal(print_ast(copy), print_ast(source))
    assert_equal(dump(copy, node, False), dump(source, operation, False))


def test_print_node_of_an_invalid_kind_is_empty() raises:
    var document = Document()
    var node = document.add(Kind(99), Role.ROOT)
    assert_equal(print_node(document, node), "")


def test_dump_shows_flags() raises:
    var document = parse("{ a(b: true, c: false) }")
    assert_true("BooleanValue 7..11 true" in dump_root(document))
    assert_true("BooleanValue 16..21 false" in dump_root(document))


def test_role_lookups_skip_other_roles() raises:
    var document = parse("{ a: b(x: 1) @d }")
    var selections = document.child(
        document.definitions()[0], Role.SELECTION_SET
    )
    var field = document.child(selections, Role.SELECTION)
    var alias = document.child(field, Role.ALIAS)
    assert_equal(document.next_with_role(alias), NO_NODE)
    assert_equal(len(document.children(field, Role.DIRECTIVE)), 1)
    assert_equal(String(SourceLocation(1, 2)), "1:2")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

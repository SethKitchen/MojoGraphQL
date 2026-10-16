# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the type system grammar of `gql_language.parser`, ported from
graphql-js 16.14.2 `src/language/__tests__/schema-parser-test.ts`.

The `experimentalDirectivesOnDirectiveDefinitions` tests at the end are
not in that file; they cover the option graphql-js 16.14.2 adds.
"""

from _ast_dump import dedent, dump, dump_root
from _fixtures import KITCHEN_SINK_SDL
from gql_language.ast import Role
from gql_language.parser import ParseOptions, parse
from gql_language.source import SourceLocation
from std.testing import TestSuite, assert_equal


def expect_syntax_error(
    text: StringSlice, message: String, line: Int, column: Int
) raises:
    """Assert that parsing a text fails with a message at a location."""
    try:
        _ = parse(text)
    except error:
        assert_equal(error.message, message)
        assert_equal(len(error.locations), 1)
        assert_equal(error.locations[0], SourceLocation(line, column))
        return
    raise Error("expected a syntax error for: " + String(text))


def expect_tree(text: StringSlice, expected: String) raises:
    """Assert the dump of a parsed document."""
    assert_equal(dump_root(parse(text)), expected)


def description_of(text: StringSlice) raises -> String:
    """Return the dump of the first definition's description."""
    var document = parse(text)
    var definition = document.definitions()[0]
    return dump(document, document.child(definition, Role.DESCRIPTION))


def test_simple_type() raises:
    expect_tree(
        dedent("\n      type Hello {\n        world: String\n      }\n    "),
        """Document 0..30
  definitions: ObjectTypeDefinition 0..30
    name: Name 5..10 "Hello"
    fields: FieldDefinition 15..28
      name: Name 15..20 "world"
      type: NamedType 22..28
        name: Name 22..28 "String"
""",
    )


def test_parses_type_with_description_string() raises:
    assert_equal(
        description_of(
            dedent(
                '\n      "Description"\n      type Hello {\n        world:'
                " String\n      }\n    "
            )
        ),
        'description: StringValue 0..13 "Description"\n',
    )


def test_parses_type_with_description_multi_line_string() raises:
    assert_equal(
        description_of(
            dedent(
                '''
      """
      Description
      """
      # Even with comments between them
      type Hello {
        world: String
      }
    '''
            )
        ),
        'description: StringValue 0..19 "Description" block\n',
    )


def test_parses_schema_with_description_string() raises:
    assert_equal(
        description_of(
            dedent(
                '\n      "Description"\n      schema {\n        query: Foo\n   '
                "   }\n    "
            )
        ),
        'description: StringValue 0..13 "Description"\n',
    )


def test_description_followed_by_something_other_than_type_system_definition_throws() raises:
    expect_syntax_error(
        '"Description" 1', 'Syntax Error: Unexpected Int "1".', 1, 15
    )


def test_simple_extension() raises:
    expect_tree(
        dedent(
            "\n      extend type Hello {\n        world: String\n      }\n    "
        ),
        """Document 0..37
  definitions: ObjectTypeExtension 0..37
    name: Name 12..17 "Hello"
    fields: FieldDefinition 22..35
      name: Name 22..27 "world"
      type: NamedType 29..35
        name: Name 29..35 "String"
""",
    )


def test_object_extension_without_fields() raises:
    expect_tree(
        "extend type Hello implements Greeting",
        """Document 0..37
  definitions: ObjectTypeExtension 0..37
    name: Name 12..17 "Hello"
    interfaces: NamedType 29..37
      name: Name 29..37 "Greeting"
""",
    )


def test_interface_extension_without_fields() raises:
    expect_tree(
        "extend interface Hello implements Greeting",
        """Document 0..42
  definitions: InterfaceTypeExtension 0..42
    name: Name 17..22 "Hello"
    interfaces: NamedType 34..42
      name: Name 34..42 "Greeting"
""",
    )


def test_object_extension_without_fields_followed_by_extension() raises:
    expect_tree(
        (
            "\n      extend type Hello implements Greeting\n\n      extend type"
            " Hello implements SecondGreeting\n    "
        ),
        """Document 0..100
  definitions: ObjectTypeExtension 7..44
    name: Name 19..24 "Hello"
    interfaces: NamedType 36..44
      name: Name 36..44 "Greeting"
  definitions: ObjectTypeExtension 52..95
    name: Name 64..69 "Hello"
    interfaces: NamedType 81..95
      name: Name 81..95 "SecondGreeting"
""",
    )


def test_extension_without_anything_throws() raises:
    expect_syntax_error(
        "extend scalar Hello", "Syntax Error: Unexpected <EOF>.", 1, 20
    )
    expect_syntax_error(
        "extend type Hello", "Syntax Error: Unexpected <EOF>.", 1, 18
    )
    expect_syntax_error(
        "extend interface Hello", "Syntax Error: Unexpected <EOF>.", 1, 23
    )
    expect_syntax_error(
        "extend union Hello", "Syntax Error: Unexpected <EOF>.", 1, 19
    )
    expect_syntax_error(
        "extend enum Hello", "Syntax Error: Unexpected <EOF>.", 1, 18
    )
    expect_syntax_error(
        "extend input Hello", "Syntax Error: Unexpected <EOF>.", 1, 19
    )


def test_interface_extension_without_fields_followed_by_extension() raises:
    expect_tree(
        (
            "\n      extend interface Hello implements Greeting\n\n      extend"
            " interface Hello implements SecondGreeting\n    "
        ),
        """Document 0..110
  definitions: InterfaceTypeExtension 7..49
    name: Name 24..29 "Hello"
    interfaces: NamedType 41..49
      name: Name 41..49 "Greeting"
  definitions: InterfaceTypeExtension 57..105
    name: Name 74..79 "Hello"
    interfaces: NamedType 91..105
      name: Name 91..105 "SecondGreeting"
""",
    )


def test_object_extension_do_not_include_descriptions() raises:
    expect_syntax_error(
        (
            '\n      "Description"\n      extend type Hello {\n        world:'
            " String\n      }\n    "
        ),
        (
            "Syntax Error: Unexpected description, only GraphQL definitions"
            " support descriptions."
        ),
        2,
        7,
    )
    expect_syntax_error(
        (
            '\n      extend "Description" type Hello {\n        world: String\n'
            "      }\n    "
        ),
        'Syntax Error: Unexpected String "Description".',
        2,
        14,
    )


def test_interface_extension_do_not_include_descriptions() raises:
    expect_syntax_error(
        (
            '\n      "Description"\n      extend interface Hello {\n       '
            " world: String\n      }\n    "
        ),
        (
            "Syntax Error: Unexpected description, only GraphQL definitions"
            " support descriptions."
        ),
        2,
        7,
    )
    expect_syntax_error(
        (
            '\n      extend "Description" interface Hello {\n        world:'
            " String\n      }\n    "
        ),
        'Syntax Error: Unexpected String "Description".',
        2,
        14,
    )


def test_schema_extension() raises:
    expect_tree(
        "\n      extend schema {\n        mutation: Mutation\n      }",
        """Document 0..57
  definitions: SchemaExtension 7..57
    operationTypes: OperationTypeDefinition 31..49 mutation
      type: NamedType 41..49
        name: Name 41..49 "Mutation"
""",
    )


def test_schema_extension_with_two_operation_types() raises:
    expect_tree(
        "extend schema { query: Q mutation: M }",
        """Document 0..38
  definitions: SchemaExtension 0..38
    operationTypes: OperationTypeDefinition 16..24 query
      type: NamedType 23..24
        name: Name 23..24 "Q"
    operationTypes: OperationTypeDefinition 25..36 mutation
      type: NamedType 35..36
        name: Name 35..36 "M"
""",
    )


def test_schema_extension_with_only_directives() raises:
    expect_tree(
        "extend schema @directive",
        """Document 0..24
  definitions: SchemaExtension 0..24
    directives: Directive 14..24
      name: Name 15..24 "directive"
""",
    )


def test_schema_extension_without_anything_throws() raises:
    expect_syntax_error(
        "extend schema", "Syntax Error: Unexpected <EOF>.", 1, 14
    )


def test_schema_extension_with_invalid_operation_type_throws() raises:
    expect_syntax_error(
        "extend schema { unknown: SomeType }",
        'Syntax Error: Unexpected Name "unknown".',
        1,
        17,
    )


def test_simple_non_null_type() raises:
    expect_tree(
        dedent("\n      type Hello {\n        world: String!\n      }\n    "),
        """Document 0..31
  definitions: ObjectTypeDefinition 0..31
    name: Name 5..10 "Hello"
    fields: FieldDefinition 15..29
      name: Name 15..20 "world"
      type: NonNullType 22..29
        type: NamedType 22..28
          name: Name 22..28 "String"
""",
    )


def test_simple_interface_inheriting_interface() raises:
    expect_tree(
        "interface Hello implements World { field: String }",
        """Document 0..50
  definitions: InterfaceTypeDefinition 0..50
    name: Name 10..15 "Hello"
    interfaces: NamedType 27..32
      name: Name 27..32 "World"
    fields: FieldDefinition 35..48
      name: Name 35..40 "field"
      type: NamedType 42..48
        name: Name 42..48 "String"
""",
    )


def test_simple_type_inheriting_interface() raises:
    expect_tree(
        "type Hello implements World { field: String }",
        """Document 0..45
  definitions: ObjectTypeDefinition 0..45
    name: Name 5..10 "Hello"
    interfaces: NamedType 22..27
      name: Name 22..27 "World"
    fields: FieldDefinition 30..43
      name: Name 30..35 "field"
      type: NamedType 37..43
        name: Name 37..43 "String"
""",
    )


def test_simple_type_inheriting_multiple_interfaces() raises:
    expect_tree(
        "type Hello implements Wo & rld { field: String }",
        """Document 0..48
  definitions: ObjectTypeDefinition 0..48
    name: Name 5..10 "Hello"
    interfaces: NamedType 22..24
      name: Name 22..24 "Wo"
    interfaces: NamedType 27..30
      name: Name 27..30 "rld"
    fields: FieldDefinition 33..46
      name: Name 33..38 "field"
      type: NamedType 40..46
        name: Name 40..46 "String"
""",
    )


def test_simple_interface_inheriting_multiple_interfaces() raises:
    expect_tree(
        "interface Hello implements Wo & rld { field: String }",
        """Document 0..53
  definitions: InterfaceTypeDefinition 0..53
    name: Name 10..15 "Hello"
    interfaces: NamedType 27..29
      name: Name 27..29 "Wo"
    interfaces: NamedType 32..35
      name: Name 32..35 "rld"
    fields: FieldDefinition 38..51
      name: Name 38..43 "field"
      type: NamedType 45..51
        name: Name 45..51 "String"
""",
    )


def test_simple_type_inheriting_multiple_interfaces_with_leading_ampersand() raises:
    expect_tree(
        "type Hello implements & Wo & rld { field: String }",
        """Document 0..50
  definitions: ObjectTypeDefinition 0..50
    name: Name 5..10 "Hello"
    interfaces: NamedType 24..26
      name: Name 24..26 "Wo"
    interfaces: NamedType 29..32
      name: Name 29..32 "rld"
    fields: FieldDefinition 35..48
      name: Name 35..40 "field"
      type: NamedType 42..48
        name: Name 42..48 "String"
""",
    )


def test_simple_interface_inheriting_multiple_interfaces_with_leading_ampersand() raises:
    expect_tree(
        "interface Hello implements & Wo & rld { field: String }",
        """Document 0..55
  definitions: InterfaceTypeDefinition 0..55
    name: Name 10..15 "Hello"
    interfaces: NamedType 29..31
      name: Name 29..31 "Wo"
    interfaces: NamedType 34..37
      name: Name 34..37 "rld"
    fields: FieldDefinition 40..53
      name: Name 40..45 "field"
      type: NamedType 47..53
        name: Name 47..53 "String"
""",
    )


def test_single_value_enum() raises:
    expect_tree(
        "enum Hello { WORLD }",
        """Document 0..20
  definitions: EnumTypeDefinition 0..20
    name: Name 5..10 "Hello"
    values: EnumValueDefinition 13..18
      name: Name 13..18 "WORLD"
""",
    )


def test_double_value_enum() raises:
    expect_tree(
        "enum Hello { WO, RLD }",
        """Document 0..22
  definitions: EnumTypeDefinition 0..22
    name: Name 5..10 "Hello"
    values: EnumValueDefinition 13..15
      name: Name 13..15 "WO"
    values: EnumValueDefinition 17..20
      name: Name 17..20 "RLD"
""",
    )


def test_simple_interface() raises:
    expect_tree(
        dedent(
            "\n      interface Hello {\n        world: String\n      }\n    "
        ),
        """Document 0..35
  definitions: InterfaceTypeDefinition 0..35
    name: Name 10..15 "Hello"
    fields: FieldDefinition 20..33
      name: Name 20..25 "world"
      type: NamedType 27..33
        name: Name 27..33 "String"
""",
    )


def test_simple_field_with_arg() raises:
    expect_tree(
        dedent(
            "\n      type Hello {\n        world(flag: Boolean): String\n     "
            " }\n    "
        ),
        """Document 0..45
  definitions: ObjectTypeDefinition 0..45
    name: Name 5..10 "Hello"
    fields: FieldDefinition 15..43
      name: Name 15..20 "world"
      arguments: InputValueDefinition 21..34
        name: Name 21..25 "flag"
        type: NamedType 27..34
          name: Name 27..34 "Boolean"
      type: NamedType 37..43
        name: Name 37..43 "String"
""",
    )


def test_simple_field_with_arg_with_default_value() raises:
    expect_tree(
        dedent(
            "\n      type Hello {\n        world(flag: Boolean = true):"
            " String\n      }\n    "
        ),
        """Document 0..52
  definitions: ObjectTypeDefinition 0..52
    name: Name 5..10 "Hello"
    fields: FieldDefinition 15..50
      name: Name 15..20 "world"
      arguments: InputValueDefinition 21..41
        name: Name 21..25 "flag"
        type: NamedType 27..34
          name: Name 27..34 "Boolean"
        defaultValue: BooleanValue 37..41 true
      type: NamedType 44..50
        name: Name 44..50 "String"
""",
    )


def test_simple_field_with_list_arg() raises:
    expect_tree(
        dedent(
            "\n      type Hello {\n        world(things: [String]): String\n "
            "     }\n    "
        ),
        """Document 0..48
  definitions: ObjectTypeDefinition 0..48
    name: Name 5..10 "Hello"
    fields: FieldDefinition 15..46
      name: Name 15..20 "world"
      arguments: InputValueDefinition 21..37
        name: Name 21..27 "things"
        type: ListType 29..37
          type: NamedType 30..36
            name: Name 30..36 "String"
      type: NamedType 40..46
        name: Name 40..46 "String"
""",
    )


def test_simple_field_with_two_args() raises:
    expect_tree(
        dedent(
            "\n      type Hello {\n        world(argOne: Boolean, argTwo:"
            " Int): String\n      }\n    "
        ),
        """Document 0..60
  definitions: ObjectTypeDefinition 0..60
    name: Name 5..10 "Hello"
    fields: FieldDefinition 15..58
      name: Name 15..20 "world"
      arguments: InputValueDefinition 21..36
        name: Name 21..27 "argOne"
        type: NamedType 29..36
          name: Name 29..36 "Boolean"
      arguments: InputValueDefinition 38..49
        name: Name 38..44 "argTwo"
        type: NamedType 46..49
          name: Name 46..49 "Int"
      type: NamedType 52..58
        name: Name 52..58 "String"
""",
    )


def test_simple_union() raises:
    expect_tree(
        "union Hello = World",
        """Document 0..19
  definitions: UnionTypeDefinition 0..19
    name: Name 6..11 "Hello"
    types: NamedType 14..19
      name: Name 14..19 "World"
""",
    )


def test_union_with_two_types() raises:
    expect_tree(
        "union Hello = Wo | Rld",
        """Document 0..22
  definitions: UnionTypeDefinition 0..22
    name: Name 6..11 "Hello"
    types: NamedType 14..16
      name: Name 14..16 "Wo"
    types: NamedType 19..22
      name: Name 19..22 "Rld"
""",
    )


def test_union_with_two_types_and_leading_pipe() raises:
    expect_tree(
        "union Hello = | Wo | Rld",
        """Document 0..24
  definitions: UnionTypeDefinition 0..24
    name: Name 6..11 "Hello"
    types: NamedType 16..18
      name: Name 16..18 "Wo"
    types: NamedType 21..24
      name: Name 21..24 "Rld"
""",
    )


def test_union_fails_with_no_types() raises:
    expect_syntax_error(
        "union Hello = |", "Syntax Error: Expected Name, found <EOF>.", 1, 16
    )


def test_union_fails_with_leading_double_pipe() raises:
    expect_syntax_error(
        "union Hello = || Wo | Rld",
        'Syntax Error: Expected Name, found "|".',
        1,
        16,
    )


def test_union_fails_with_double_pipe() raises:
    expect_syntax_error(
        "union Hello = Wo || Rld",
        'Syntax Error: Expected Name, found "|".',
        1,
        19,
    )


def test_union_fails_with_trailing_pipe() raises:
    expect_syntax_error(
        "union Hello = | Wo | Rld |",
        "Syntax Error: Expected Name, found <EOF>.",
        1,
        27,
    )


def test_scalar() raises:
    expect_tree(
        "scalar Hello",
        """Document 0..12
  definitions: ScalarTypeDefinition 0..12
    name: Name 7..12 "Hello"
""",
    )


def test_simple_input_object() raises:
    expect_tree(
        "\ninput Hello {\n  world: String\n}",
        """Document 0..32
  definitions: InputObjectTypeDefinition 1..32
    name: Name 7..12 "Hello"
    fields: InputValueDefinition 17..30
      name: Name 17..22 "world"
      type: NamedType 24..30
        name: Name 24..30 "String"
""",
    )


def test_simple_input_object_with_args_should_fail() raises:
    expect_syntax_error(
        "\n      input Hello {\n        world(foo: Int): String\n      }\n    ",
        'Syntax Error: Expected ":", found "(".',
        3,
        14,
    )


def test_directive_definition() raises:
    expect_tree(
        "directive @foo on OBJECT | INTERFACE",
        """Document 0..36
  definitions: DirectiveDefinition 0..36
    name: Name 11..14 "foo"
    locations: Name 18..24 "OBJECT"
    locations: Name 27..36 "INTERFACE"
""",
    )


def test_repeatable_directive_definition() raises:
    expect_tree(
        "directive @foo repeatable on OBJECT | INTERFACE",
        """Document 0..47
  definitions: DirectiveDefinition 0..47 repeatable
    name: Name 11..14 "foo"
    locations: Name 29..35 "OBJECT"
    locations: Name 38..47 "INTERFACE"
""",
    )


def test_directive_definition_extensions_require_the_experimental_flag() raises:
    expect_syntax_error(
        "extend directive @foo @bar",
        'Syntax Error: Unexpected Name "directive".',
        1,
        8,
    )


def test_directive_with_incorrect_locations() raises:
    expect_syntax_error(
        "directive @foo on FIELD | INCORRECT_LOCATION",
        'Syntax Error: Unexpected Name "INCORRECT_LOCATION".',
        1,
        27,
    )


def test_parses_kitchen_sink_schema() raises:
    _ = parse(KITCHEN_SINK_SDL)


def test_experimental_directives_on_directive_definitions() raises:
    var options = ParseOptions()
    options.experimental_directives_on_directive_definitions = True
    assert_equal(
        dump_root(parse("extend directive @foo @bar", options)),
        """Document 0..26
  definitions: DirectiveExtension 0..26
    name: Name 18..21 "foo"
    directives: Directive 22..26
      name: Name 23..26 "bar"
""",
    )
    assert_equal(
        dump_root(parse("directive @foo @bar on FIELD", options)),
        """Document 0..28
  definitions: DirectiveDefinition 0..28
    name: Name 11..14 "foo"
    directives: Directive 15..19
      name: Name 16..19 "bar"
    locations: Name 23..28 "FIELD"
""",
    )
    try:
        _ = parse("extend directive @foo", options)
    except error:
        assert_equal(error.message, "Syntax Error: Unexpected <EOF>.")
        return
    raise Error("expected an error")


def test_extension_keyword_errors() raises:
    expect_syntax_error("extend 1", 'Syntax Error: Unexpected Int "1".', 1, 8)
    expect_syntax_error(
        "extend foo", 'Syntax Error: Unexpected Name "foo".', 1, 8
    )
    expect_syntax_error(
        '"d" extend',
        (
            "Syntax Error: Unexpected description, only GraphQL"
            " definitions support descriptions."
        ),
        1,
        1,
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

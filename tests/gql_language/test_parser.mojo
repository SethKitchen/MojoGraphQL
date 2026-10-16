# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_language.parser`, ported from graphql-js 16.14.2
`src/language/__tests__/parser-test.ts`.

An `expectJSON(...).toDeepEqual(...)` there is a `dump` comparison here; see
`_ast_dump`. graphql-js tests of JavaScript object identity, such as
`loc.source` and `Object.prototype.toString`, have no Mojo meaning and are
not ported. The `noLocation` option is not ported: every node has a range.
"""

from _ast_dump import dedent, dump, dump_root
from _fixtures import KITCHEN_SINK_QUERY
from gql_language.ast import Kind, Role
from gql_language.error import GraphQLError
from gql_language.parser import (
    ParseOptions,
    parse,
    parse_const_value,
    parse_schema_coordinate,
    parse_type,
    parse_value,
)
from gql_language.source import Source, SourceLocation
from std.testing import TestSuite, assert_equal, assert_true


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


def expect_error_message(
    text: StringSlice, options: ParseOptions, message: String
) raises:
    """Assert that parsing a text with options fails with a message."""
    try:
        _ = parse(text, options)
    except error:
        assert_equal(error.message, message)
        return
    raise Error("expected a syntax error for: " + String(text))


def test_parse_provides_useful_errors() raises:
    try:
        _ = parse("{")
    except error:
        assert_equal(error.message, "Syntax Error: Expected Name, found <EOF>.")
        assert_equal(error.locations[0], SourceLocation(1, 2))
        assert_equal(
            String(error),
            "Syntax Error: Expected Name, found <EOF>.\n\n"
            + "GraphQL request:1:2\n"
            + "1 | {\n"
            + "  |  ^",
        )
    expect_syntax_error(
        "\n      { ...MissingOn }\n      fragment MissingOn Type\n    ",
        'Syntax Error: Expected "on", found Name "Type".',
        3,
        26,
    )
    expect_syntax_error(
        "{ field: {} }", 'Syntax Error: Expected Name, found "{".', 1, 10
    )
    expect_syntax_error(
        "notAnOperation Foo { field }",
        'Syntax Error: Unexpected Name "notAnOperation".',
        1,
        1,
    )
    expect_syntax_error("...", 'Syntax Error: Unexpected "...".', 1, 1)
    expect_syntax_error(
        '{ ""', 'Syntax Error: Expected Name, found String "".', 1, 3
    )


def test_parse_provides_useful_error_when_using_source() raises:
    try:
        _ = parse(Source("query", "MyQuery.graphql"))
    except error:
        assert_equal(
            String(error),
            'Syntax Error: Expected "{", found <EOF>.\n\n'
            + "MyQuery.graphql:1:6\n"
            + "1 | query\n"
            + "  |      ^",
        )
        return
    raise Error("expected an error")


def test_exposes_the_token_count() raises:
    assert_equal(parse("{ foo }").token_count, 3)
    assert_equal(parse('{ foo(bar: "baz") }').token_count, 8)


def test_limit_maximum_number_of_tokens() raises:
    var options = ParseOptions()
    options.max_tokens = 3
    _ = parse("{ foo }", options)
    options.max_tokens = 2
    expect_error_message(
        "{ foo }",
        options,
        "Syntax Error: Document contains more that 2 tokens. Parsing aborted.",
    )
    options.max_tokens = 8
    _ = parse('{ foo(bar: "baz") }', options)
    options.max_tokens = 7
    expect_error_message(
        '{ foo(bar: "baz") }',
        options,
        "Syntax Error: Document contains more that 7 tokens. Parsing aborted.",
    )


def test_parses_variable_inline_values() raises:
    _ = parse("{ field(complex: { a: { b: [ $var ] } }) }")


def test_parses_constant_default_values() raises:
    expect_syntax_error(
        "query Foo($x: Complex = { a: { b: [ $var ] } }) { field }",
        'Syntax Error: Unexpected variable "$var" in constant value.',
        1,
        37,
    )


def test_parses_variable_definition_directives() raises:
    _ = parse("query Foo($x: Boolean = false @bar) { field }")


def test_does_not_accept_fragments_named_on() raises:
    expect_syntax_error(
        "fragment on on on { on }", 'Syntax Error: Unexpected Name "on".', 1, 10
    )


def test_does_not_accept_fragments_spread_of_on() raises:
    expect_syntax_error(
        "{ ...on }", 'Syntax Error: Expected Name, found "}".', 1, 9
    )


def test_does_not_allow_true_false_or_null_as_enum_value() raises:
    expect_syntax_error(
        "enum Test { VALID, true }",
        (
            'Syntax Error: Name "true" is reserved and cannot be used for an'
            " enum value."
        ),
        1,
        20,
    )
    expect_syntax_error(
        "enum Test { VALID, false }",
        (
            'Syntax Error: Name "false" is reserved and cannot be used for an'
            " enum value."
        ),
        1,
        20,
    )
    expect_syntax_error(
        "enum Test { VALID, null }",
        (
            'Syntax Error: Name "null" is reserved and cannot be used for an'
            " enum value."
        ),
        1,
        20,
    )


def test_parses_multi_byte_characters() raises:
    var document = parse(
        "\n      # This comment has a ਊ multi-byte character.\n"
        + '      { field(arg: "Has a ਊ multi-byte character.") }\n    '
    )
    var operation = document.definitions()[0]
    var selections = document.child(operation, Role.SELECTION_SET)
    var field = document.child(selections, Role.SELECTION)
    var argument = document.child(field, Role.ARGUMENT)
    var value = document.child(argument, Role.VALUE)
    assert_equal(document.string_value(value), "Has a ਊ multi-byte character.")


def test_parses_kitchen_sink() raises:
    _ = parse(KITCHEN_SINK_QUERY)


def test_allows_non_keywords_anywhere_a_name_is_allowed() raises:
    var keywords: List[String] = [
        "on",
        "fragment",
        "query",
        "mutation",
        "subscription",
        "true",
        "false",
    ]
    for ref keyword in keywords:
        var fragment = keyword
        if keyword == "on":
            fragment = String("a")
        var text = (
            "query "
            + keyword
            + " {\n  ... "
            + fragment
            + "\n  ... on "
            + keyword
            + " { field }\n}\nfragment "
            + fragment
            + " on Type {\n  "
            + keyword
            + "("
            + keyword
            + ": $"
            + keyword
            + ")\n    @"
            + keyword
            + "("
            + keyword
            + ": "
            + keyword
            + ")\n}\n"
        )
        _ = parse(text)


def test_parses_anonymous_mutation_operations() raises:
    _ = parse("\n      mutation {\n        mutationField\n      }\n    ")


def test_parses_anonymous_subscription_operations() raises:
    _ = parse(
        "\n      subscription {\n        subscriptionField\n      }\n    "
    )


def test_parses_named_mutation_operations() raises:
    _ = parse("\n      mutation Foo {\n        mutationField\n      }\n    ")


def test_parses_named_subscription_operations() raises:
    _ = parse(
        "\n      subscription Foo {\n        subscriptionField\n      }\n    "
    )


def test_creates_ast() raises:
    var document = parse(
        dedent(
            """
      {
        node(id: 4) {
          id,
          name
        }
      }
    """
        )
    )
    assert_equal(
        dump_root(document),
        """Document 0..40
  definitions: OperationDefinition 0..40 query
    selectionSet: SelectionSet 0..40
      selections: Field 4..38
        name: Name 4..8 "node"
        arguments: Argument 9..14
          name: Name 9..11 "id"
          value: IntValue 13..14 "4"
        selectionSet: SelectionSet 16..38
          selections: Field 22..24
            name: Name 22..24 "id"
          selections: Field 30..34
            name: Name 30..34 "name"
""",
    )


def test_creates_ast_from_nameless_query_without_variables() raises:
    var document = parse(
        dedent(
            """
      query {
        node {
          id
        }
      }
    """
        )
    )
    assert_equal(
        dump_root(document),
        """Document 0..29
  definitions: OperationDefinition 0..29 query
    selectionSet: SelectionSet 6..29
      selections: Field 10..27
        name: Name 10..14 "node"
        selectionSet: SelectionSet 15..27
          selections: Field 21..23
            name: Name 21..23 "id"
""",
    )


def test_creates_ast_from_nameless_query_with_description() raises:
    var document = parse(
        dedent(
            """
      "Description"
      query {
        node {
          id
        }
      }
    """
        )
    )
    assert_equal(
        dump_root(document),
        """Document 0..43
  definitions: OperationDefinition 0..43 query
    description: StringValue 0..13 "Description"
    selectionSet: SelectionSet 20..43
      selections: Field 24..41
        name: Name 24..28 "node"
        selectionSet: SelectionSet 29..41
          selections: Field 35..37
            name: Name 35..37 "id"
""",
    )


def test_legacy_allows_parsing_fragment_defined_variables() raises:
    var text = "fragment a($v: Boolean = false) on t { f(v: $v) }"
    var options = ParseOptions()
    options.allow_legacy_fragment_variables = True
    _ = parse(text, options)
    var raised = False
    try:
        _ = parse(text)
    except error:
        raised = error.message.startswith("Syntax Error")
    assert_true(raised)


def test_document_location_spans_the_source() raises:
    var document = parse("{ id }")
    assert_equal(document.start(document.root), 0)
    assert_equal(document.end(document.root), 6)


def test_parse_value_parses_null_value() raises:
    assert_equal(dump_root(parse_value("null")), "NullValue 0..4\n")


def test_parse_value_parses_list_values() raises:
    assert_equal(
        dump_root(parse_value('[123 "abc"]')),
        """ListValue 0..11
  values: IntValue 1..4 "123"
  values: StringValue 5..10 "abc"
""",
    )


def test_parse_value_parses_block_strings() raises:
    assert_equal(
        dump_root(parse_value('["""long""" "short"]')),
        """ListValue 0..20
  values: StringValue 1..11 "long" block
  values: StringValue 12..19 "short"
""",
    )


def test_parse_value_allows_variables() raises:
    assert_equal(
        dump_root(parse_value("{ field: $var }")),
        """ObjectValue 0..15
  fields: ObjectField 2..13
    name: Name 2..7 "field"
    value: Variable 9..13
      name: Name 10..13 "var"
""",
    )


def expect_value_error(
    text: StringSlice, is_const: Bool, message: String, column: Int
) raises:
    """Assert that parsing a value fails on line 1."""
    try:
        if is_const:
            _ = parse_const_value(text)
        else:
            _ = parse_value(text)
    except error:
        assert_equal(error.message, message)
        assert_equal(error.locations[0], SourceLocation(1, column))
        return
    raise Error("expected an error for: " + String(text))


def test_parse_value_correct_message_for_incomplete_variable() raises:
    expect_value_error(
        "$", False, "Syntax Error: Expected Name, found <EOF>.", 2
    )


def test_parse_value_correct_message_for_unexpected_token() raises:
    expect_value_error(":", False, 'Syntax Error: Unexpected ":".', 1)


def test_parse_const_value_parses_values() raises:
    assert_equal(
        dump_root(parse_const_value('[123 "abc"]')),
        """ListValue 0..11
  values: IntValue 1..4 "123"
  values: StringValue 5..10 "abc"
""",
    )


def test_parse_const_value_does_not_allow_variables() raises:
    expect_value_error(
        "{ field: $var }",
        True,
        'Syntax Error: Unexpected variable "$var" in constant value.',
        10,
    )


def test_parse_const_value_correct_message_for_unexpected_token() raises:
    expect_value_error("$", True, 'Syntax Error: Unexpected "$".', 1)


def test_parse_type_parses_well_known_types() raises:
    assert_equal(
        dump_root(parse_type("String")),
        'NamedType 0..6\n  name: Name 0..6 "String"\n',
    )


def test_parse_type_parses_custom_types() raises:
    assert_equal(
        dump_root(parse_type("MyType")),
        'NamedType 0..6\n  name: Name 0..6 "MyType"\n',
    )


def test_parse_type_parses_list_types() raises:
    assert_equal(
        dump_root(parse_type("[MyType]")),
        """ListType 0..8
  type: NamedType 1..7
    name: Name 1..7 "MyType"
""",
    )


def test_parse_type_parses_non_null_types() raises:
    assert_equal(
        dump_root(parse_type("MyType!")),
        """NonNullType 0..7
  type: NamedType 0..6
    name: Name 0..6 "MyType"
""",
    )


def test_parse_type_parses_nested_types() raises:
    assert_equal(
        dump_root(parse_type("[MyType!]")),
        """ListType 0..9
  type: NonNullType 1..8
    type: NamedType 1..7
      name: Name 1..7 "MyType"
""",
    )


def test_parse_schema_coordinate_parses_name() raises:
    assert_equal(
        dump_root(parse_schema_coordinate("MyType")),
        'TypeCoordinate 0..6\n  name: Name 0..6 "MyType"\n',
    )


def test_parse_schema_coordinate_parses_member() raises:
    assert_equal(
        dump_root(parse_schema_coordinate("MyType.field")),
        """MemberCoordinate 0..12
  name: Name 0..6 "MyType"
  memberName: Name 7..12 "field"
""",
    )


def expect_coordinate_error(
    text: StringSlice, message: String, column: Int
) raises:
    """Assert that parsing a schema coordinate fails on line 1."""
    try:
        _ = parse_schema_coordinate(text)
    except error:
        assert_equal(error.message, message)
        assert_equal(error.locations[0], SourceLocation(1, column))
        return
    raise Error("expected an error for: " + String(text))


def test_parse_schema_coordinate_rejects_name_name_name() raises:
    expect_coordinate_error(
        "MyType.field.deep", 'Syntax Error: Expected <EOF>, found ".".', 13
    )


def test_parse_schema_coordinate_parses_argument() raises:
    assert_equal(
        dump_root(parse_schema_coordinate("MyType.field(arg:)")),
        """ArgumentCoordinate 0..18
  name: Name 0..6 "MyType"
  fieldName: Name 7..12 "field"
  argumentName: Name 13..16 "arg"
""",
    )


def test_parse_schema_coordinate_rejects_argument_value() raises:
    expect_coordinate_error(
        "MyType.field(arg: value)", 'Syntax Error: Invalid character: " ".', 18
    )


def test_parse_schema_coordinate_parses_directive() raises:
    assert_equal(
        dump_root(parse_schema_coordinate("@myDirective")),
        'DirectiveCoordinate 0..12\n  name: Name 1..12 "myDirective"\n',
    )


def test_parse_schema_coordinate_parses_directive_argument() raises:
    assert_equal(
        dump_root(parse_schema_coordinate("@myDirective(arg:)")),
        """DirectiveArgumentCoordinate 0..18
  name: Name 1..12 "myDirective"
  argumentName: Name 13..16 "arg"
""",
    )


def test_parse_schema_coordinate_parses_meta_names() raises:
    assert_equal(
        dump_root(parse_schema_coordinate("__Type")),
        'TypeCoordinate 0..6\n  name: Name 0..6 "__Type"\n',
    )
    assert_equal(
        dump_root(parse_schema_coordinate("Type.__metafield")),
        """MemberCoordinate 0..16
  name: Name 0..4 "Type"
  memberName: Name 5..16 "__metafield"
""",
    )
    assert_equal(
        dump_root(parse_schema_coordinate("Type.__metafield(arg:)")),
        """ArgumentCoordinate 0..22
  name: Name 0..4 "Type"
  fieldName: Name 5..16 "__metafield"
  argumentName: Name 17..20 "arg"
""",
    )


def test_parse_schema_coordinate_rejects_directive_member() raises:
    expect_coordinate_error(
        "@myDirective.field", 'Syntax Error: Expected <EOF>, found ".".', 13
    )


def test_parse_schema_coordinate_more_errors() raises:
    expect_coordinate_error("", "Syntax Error: Expected Name, found <EOF>.", 1)
    expect_coordinate_error(
        "Type(arg:)", 'Syntax Error: Expected <EOF>, found "(".', 5
    )
    expect_coordinate_error(
        "@dir(arg)", 'Syntax Error: Expected ":", found ")".', 9
    )
    expect_coordinate_error(
        "@dir(arg:", 'Syntax Error: Expected ")", found <EOF>.', 10
    )
    expect_coordinate_error("1", 'Syntax Error: Invalid character: "1".', 1)


def test_parses_operation_with_description_and_variable_descriptions() raises:
    var document = parse(
        dedent(
            '''
        "Operation description"
        query myQuery(
          "Variable a description"
          $a: Int,
          """Variable b\nmultiline description"""
          $b: String
        ) {
          field(a: $a, b: $b)
        }
      '''
        )
    )
    var operation = document.definitions()[0]
    assert_equal(document.kind(operation), Kind.OPERATION_DEFINITION)
    assert_equal(
        dump(document, operation),
        """definitions: OperationDefinition 0..158 query
  description: StringValue 0..23 "Operation description"
  name: Name 30..37 "myQuery"
  variableDefinitions: VariableDefinition 41..75
    description: StringValue 41..65 "Variable a description"
    variable: Variable 68..70
      name: Name 69..70 "a"
    type: NamedType 72..75
      name: Name 72..75 "Int"
  variableDefinitions: VariableDefinition 79..130
    description: StringValue 79..117 "Variable b\\nmultiline description" block
    variable: Variable 120..122
      name: Name 121..122 "b"
    type: NamedType 124..130
      name: Name 124..130 "String"
  selectionSet: SelectionSet 133..158
    selections: Field 137..156
      name: Name 137..142 "field"
      arguments: Argument 143..148
        name: Name 143..144 "a"
        value: Variable 146..148
          name: Name 147..148 "a"
      arguments: Argument 150..155
        name: Name 150..151 "b"
        value: Variable 153..155
          name: Name 154..155 "b"
""",
    )


def test_descriptions_on_a_short_hand_query_produce_a_sensible_error() raises:
    expect_syntax_error(
        '"""Invalid"""\n        { __typename }',
        (
            "Syntax Error: Unexpected description, descriptions are not"
            " supported on shorthand queries."
        ),
        1,
        1,
    )


def test_parses_variable_definition_with_description_default_and_directives() raises:
    var document = parse(
        dedent(
            """
        query (
          "desc"
          $foo: Int = 42 @dir
        ) {
          field(foo: $foo)
        }
      """
        )
    )
    var operation = document.definitions()[0]
    var definition = document.child(operation, Role.VARIABLE_DEFINITION)
    assert_equal(
        dump(document, definition),
        """variableDefinitions: VariableDefinition 10..38
  description: StringValue 10..16 "desc"
  variable: Variable 19..23
    name: Name 20..23 "foo"
  type: NamedType 25..28
    name: Name 25..28 "Int"
  defaultValue: IntValue 31..33 "42"
  directives: Directive 34..38
    name: Name 35..38 "dir"
""",
    )


def test_parses_fragment_with_variable_description_legacy() raises:
    var options = ParseOptions()
    options.allow_legacy_fragment_variables = True
    var document = parse(
        'fragment Foo("desc" $foo: Int) on Bar { baz }', options
    )
    var fragment = document.definitions()[0]
    var definition = document.child(fragment, Role.VARIABLE_DEFINITION)
    assert_equal(
        dump(document, definition),
        """variableDefinitions: VariableDefinition 13..29
  description: StringValue 13..19 "desc"
  variable: Variable 20..24
    name: Name 21..24 "foo"
  type: NamedType 26..29
    name: Name 26..29 "Int"
""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

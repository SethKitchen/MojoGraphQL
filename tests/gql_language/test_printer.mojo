# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_language.printer` and `gql_language.block_string`, ported
from graphql-js 16.14.2 `src/language/__tests__/printer-test.ts`,
`schema-printer-test.ts`, `blockString-test.ts`, `printString-test.ts` and
`printLocation-test.ts`.

graphql-js prints any object with a `kind`; the "Invalid AST Node" tests
check a JavaScript object without one, which a `Document` cannot hold, and
are not ported. A minimal AST is built with the `Document` builder.
"""

from _ast_dump import dedent, shape
from _fixtures import KITCHEN_SINK_QUERY, KITCHEN_SINK_SDL
from gql_language.ast import Document, Kind, Role
from gql_language.block_string import (
    is_printable_as_block_string,
    print_block_string,
    print_string,
    utf16_count,
)
from gql_language.error import print_source_location
from gql_language.lexer import dedent_block_string_lines
from gql_language.parser import ParseOptions, parse, parse_schema_coordinate
from gql_language.printer import print_ast, print_node
from gql_language.source import Source, SourceLocation
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def printed(text: StringSlice) raises -> String:
    """Return a text parsed and printed."""
    return print_ast(parse(text))


def test_prints_minimal_ast() raises:
    var document = Document()
    var field = document.add(Kind.FIELD, Role.ROOT)
    _ = document.add_name(field, Role.NAME, "foo")
    assert_equal(print_node(document, field), "foo")
    var scalar = document.add(Kind.SCALAR_TYPE_DEFINITION, Role.ROOT)
    _ = document.add_name(scalar, Role.NAME, "foo")
    assert_equal(print_node(document, scalar), "scalar foo")


def test_correctly_prints_non_query_operations_without_name() raises:
    assert_equal(
        printed("query { id, name }"),
        dedent("\n      {\n        id\n        name\n      }\n    "),
    )
    assert_equal(
        printed("mutation { id, name }"),
        dedent("\n      mutation {\n        id\n        name\n      }\n    "),
    )
    assert_equal(
        printed("query ($foo: TestType) @testDirective { id, name }"),
        "query ($foo: TestType) @testDirective {\n  id\n  name\n}",
    )
    assert_equal(
        printed("mutation ($foo: TestType) @testDirective { id, name }"),
        "mutation ($foo: TestType) @testDirective {\n  id\n  name\n}",
    )


def test_prints_query_with_variable_directives() raises:
    assert_equal(
        printed(
            "query ($foo: TestType = {a: 123} @testDirective(if: true) @test)"
            " { id }"
        ),
        (
            "query ($foo: TestType = {a: 123} @testDirective(if: true) @test)"
            " {\n  id\n}"
        ),
    )


def test_keeps_arguments_on_one_line_if_line_is_short() raises:
    assert_equal(
        printed("{trip(wheelchair:false arriveBy:false){dateTime}}"),
        "{\n  trip(wheelchair: false, arriveBy: false) {\n    dateTime\n  }\n}",
    )


def test_puts_arguments_on_multiple_lines_if_line_is_long() raises:
    assert_equal(
        printed(
            "{trip(wheelchair:false arriveBy:false"
            " includePlannedCancellations:true"
            " transitDistanceReluctance:2000){dateTime}}"
        ),
        dedent(
            """
      {
        trip(
          wheelchair: false
          arriveBy: false
          includePlannedCancellations: true
          transitDistanceReluctance: 2000
        ) {
          dateTime
        }
      }
    """
        ),
    )


def test_legacy_prints_fragment_with_variable_directives() raises:
    var options = ParseOptions()
    options.allow_legacy_fragment_variables = True
    assert_equal(
        print_ast(
            parse(
                (
                    "fragment Foo($foo: TestType @test) on TestType"
                    " @testDirective { id }"
                ),
                options,
            )
        ),
        (
            "fragment Foo($foo: TestType @test) on TestType @testDirective {\n "
            " id\n}"
        ),
    )


def test_experimental_prints_directives_on_directives() raises:
    var options = ParseOptions()
    options.experimental_directives_on_directive_definitions = True
    assert_equal(
        print_ast(
            parse(
                (
                    "\n      directive @foo @bar on FIELD_DEFINITION\n     "
                    " extend directive @foo @baz\n      "
                ),
                options,
            )
        ),
        "directive @foo @bar on FIELD_DEFINITION\n\nextend directive @foo @baz",
    )


def test_legacy_correctly_prints_fragment_defined_variables() raises:
    var options = ParseOptions()
    options.allow_legacy_fragment_variables = True
    assert_equal(
        print_ast(
            parse(
                (
                    "\n        fragment Foo($a: ComplexType, $b: Boolean ="
                    " false) on TestType {\n          id\n        }\n      "
                ),
                options,
            )
        ),
        (
            "fragment Foo($a: ComplexType, $b: Boolean = false) on TestType {\n"
            "  id\n}"
        ),
    )


def test_prints_fragment() raises:
    assert_equal(
        printed('"Fragment description" fragment Foo on Bar { baz }'),
        '"Fragment description"\nfragment Foo on Bar {\n  baz\n}',
    )


def test_prints_kitchen_sink_without_altering_ast() raises:
    var document = parse(KITCHEN_SINK_QUERY)
    var before = shape(document)
    var text = print_ast(document)
    assert_equal(shape(parse(text)), before)
    assert_equal(shape(document), before)
    assert_equal(
        text,
        dedent(
            '''
      "Query description"
      query queryName(
      "Very complex variable"
      $foo: ComplexType
      $site: Site = MOBILE
      ) @onQuery {
        whoever123is: node(id: [123, 456]) {
          id
          ... on User @onInlineFragment {
            field2 {
              id
              alias: field1(first: 10, after: $foo) @include(if: $foo) {
                id
                ...frag @onFragmentSpread
              }
            }
          }
          ... @skip(unless: $foo) {
            id
          }
          ... {
            id
          }
        }
      }

      mutation likeStory @onMutation {
        like(story: 123) @onField {
          story {
            id @onField
          }
        }
      }

      subscription StoryLikeSubscription($input: StoryLikeSubscribeInput @onVariableDefinition) @onSubscription {
        storyLikeSubscribe(input: $input) {
          story {
            likers {
              count
            }
            likeSentence {
              text
            }
          }
        }
      }

      """Fragment description"""
      fragment frag on Friend @onFragmentDefinition {
        foo(
          size: $size
          bar: $b
          obj: {key: "value", block: """
          block string uses \\"""
          """}
        )
      }

      {
        unnamed(truthy: true, falsy: false, nullish: null)
        query
      }

      {
        __typename
      }
    '''
        ),
    )


def test_prints_schema_coordinates() raises:
    var coordinates: List[String] = [
        "Name",
        "Name.field",
        "Name.field(arg:)",
        "@name",
        "@name(arg:)",
        "__Type",
        "Type.__metafield",
        "Type.__metafield(arg:)",
    ]
    for ref coordinate in coordinates:
        assert_equal(print_ast(parse_schema_coordinate(coordinate)), coordinate)


def expect_coordinate_error(text: StringSlice, message: String) raises:
    """Assert that a schema coordinate fails to parse."""
    try:
        _ = parse_schema_coordinate(text)
    except error:
        assert_equal(error.message, message)
        return
    raise Error("expected an error for: " + String(text))


def test_throws_syntax_error_for_ignored_tokens_in_schema_coordinates() raises:
    expect_coordinate_error(
        "# foo\nName", 'Syntax Error: Invalid character: "#".'
    )
    expect_coordinate_error(
        "\nName", "Syntax Error: Invalid character: U+000A."
    )
    expect_coordinate_error(
        "Name .field", 'Syntax Error: Invalid character: " ".'
    )


def test_sdl_prints_kitchen_sink_without_altering_ast() raises:
    var document = parse(KITCHEN_SINK_SDL)
    var before = shape(document)
    var text = print_ast(document)
    assert_equal(shape(parse(text)), before)
    assert_equal(shape(document), before)
    assert_equal(
        text,
        dedent(
            '''
      """This is a description of the schema as a whole."""
      schema {
        query: QueryType
        mutation: MutationType
      }

      """
      This is a description
      of the `Foo` type.
      """
      type Foo implements Bar & Baz & Two {
        "Description of the `one` field."
        one: Type
        """This is a description of the `two` field."""
        two(
          """This is a description of the `argument` argument."""
          argument: InputType!
        ): Type
        """This is a description of the `three` field."""
        three(argument: InputType, other: String): Int
        four(argument: String = "string"): String
        five(argument: [String] = ["string", "string"]): String
        six(argument: InputType = {key: "value"}): Type
        seven(argument: Int = null): Type
        eight(argument: OneOfInputType): Type
      }

      type AnnotatedObject @onObject(arg: "value") {
        annotatedField(arg: Type = "default" @onArgumentDefinition): Type @onField
      }

      type UndefinedType

      extend type Foo {
        seven(argument: [String]): Type
      }

      extend type Foo @onType

      interface Bar {
        one: Type
        four(argument: String = "string"): String
      }

      interface AnnotatedInterface @onInterface {
        annotatedField(arg: Type @onArgumentDefinition): Type @onField
      }

      interface UndefinedInterface

      extend interface Bar implements Two {
        two(argument: InputType!): Type
      }

      extend interface Bar @onInterface

      interface Baz implements Bar & Two {
        one: Type
        two(argument: InputType!): Type
        four(argument: String = "string"): String
      }

      union Feed = Story | Article | Advert

      union AnnotatedUnion @onUnion = A | B

      union AnnotatedUnionTwo @onUnion = A | B

      union UndefinedUnion

      extend union Feed = Photo | Video

      extend union Feed @onUnion

      scalar CustomScalar

      scalar AnnotatedScalar @onScalar

      extend scalar CustomScalar @onScalar

      enum Site {
        """This is a description of the `DESKTOP` value"""
        DESKTOP
        """This is a description of the `MOBILE` value"""
        MOBILE
        "This is a description of the `WEB` value"
        WEB
      }

      enum AnnotatedEnum @onEnum {
        ANNOTATED_VALUE @onEnumValue
        OTHER_VALUE
      }

      enum UndefinedEnum

      extend enum Site {
        VR
      }

      extend enum Site @onEnum

      input InputType {
        key: String!
        answer: Int = 42
      }

      input OneOfInputType @oneOf {
        string: String
        int: Int
      }

      input AnnotatedInput @onInputObject {
        annotatedField: Type @onInputFieldDefinition
      }

      input UndefinedInput

      extend input InputType {
        other: Float = 1.23e4 @onInputFieldDefinition
      }

      extend input InputType @onInputObject

      """This is a description of the `@skip` directive"""
      directive @skip(
        """This is a description of the `if` argument"""
        if: Boolean! @onArgumentDefinition
      ) on FIELD | FRAGMENT_SPREAD | INLINE_FRAGMENT

      directive @include(if: Boolean!) on FIELD | FRAGMENT_SPREAD | INLINE_FRAGMENT

      directive @include2(if: Boolean!) on FIELD | FRAGMENT_SPREAD | INLINE_FRAGMENT

      directive @myRepeatableDir(name: String!) repeatable on OBJECT | INTERFACE

      extend schema @onSchema

      extend schema @onSchema {
        subscription: SubscriptionType
      }
    '''
        ),
    )


def expect_dedent(var lines: List[String], expected: List[String]) raises:
    """Assert graphql-js `dedentBlockStringLines`."""
    var got = dedent_block_string_lines(lines)
    assert_equal(len(got), len(expected))
    for index in range(len(expected)):
        assert_equal(got[index], expected[index])


def test_dedent_handles_empty_string() raises:
    expect_dedent([""], [])
    expect_dedent(List[String](), [])


def test_dedent_does_not_dedent_first_line() raises:
    expect_dedent(["  a"], ["  a"])
    expect_dedent([" a", "  b"], [" a", "b"])


def test_dedent_removes_minimal_indentation_length() raises:
    expect_dedent(["", " a", "  b"], ["a", " b"])
    expect_dedent(["", "  a", " b"], [" a", "b"])
    expect_dedent(["", "  a", " b", "c"], ["  a", " b", "c"])


def test_dedent_both_tab_and_space_as_single_character() raises:
    expect_dedent(["", "\ta", "          b"], ["a", "         b"])
    expect_dedent(["", "\t a", "          b"], ["a", "        b"])
    expect_dedent(["", " \t a", "          b"], ["a", "       b"])


def test_dedent_do_not_take_empty_lines_into_account() raises:
    expect_dedent(["a", "", " b"], ["a", "", "b"])
    expect_dedent(["a", " ", "  b"], ["a", "", "b"])


def test_dedent_removes_uniform_indentation_from_a_string() raises:
    expect_dedent(
        ["", "    Hello,", "      World!", "", "    Yours,", "      GraphQL."],
        ["Hello,", "  World!", "", "Yours,", "  GraphQL."],
    )


def test_dedent_removes_empty_leading_and_trailing_lines() raises:
    expect_dedent(
        [
            "",
            "",
            "    Hello,",
            "      World!",
            "",
            "    Yours,",
            "      GraphQL.",
            "",
            "",
        ],
        ["Hello,", "  World!", "", "Yours,", "  GraphQL."],
    )


def test_dedent_removes_blank_leading_and_trailing_lines() raises:
    expect_dedent(
        [
            "  ",
            "        ",
            "    Hello,",
            "      World!",
            "",
            "    Yours,",
            "      GraphQL.",
            "        ",
            "  ",
        ],
        ["Hello,", "  World!", "", "Yours,", "  GraphQL."],
    )


def test_dedent_retains_indentation_from_first_line() raises:
    expect_dedent(
        ["    Hello,", "      World!", "", "    Yours,", "      GraphQL."],
        ["    Hello,", "  World!", "", "Yours,", "  GraphQL."],
    )


def test_dedent_does_not_alter_trailing_spaces() raises:
    expect_dedent(
        [
            "               ",
            "    Hello,     ",
            "      World!   ",
            "               ",
            "    Yours,     ",
            "      GraphQL. ",
            "               ",
        ],
        [
            "Hello,     ",
            "  World!   ",
            "           ",
            "Yours,     ",
            "  GraphQL. ",
        ],
    )


def test_is_printable_accepts_valid_strings() raises:
    assert_true(is_printable_as_block_string(""))
    assert_true(is_printable_as_block_string(" a"))
    assert_true(is_printable_as_block_string('\t"\n"'))
    assert_false(is_printable_as_block_string('\t"\n \n\t"'))


def test_is_printable_rejects_strings_with_only_whitespace() raises:
    var texts: List[String] = [" ", "\t", "\t ", " \t"]
    for ref text in texts:
        assert_false(is_printable_as_block_string(text))


def test_is_printable_rejects_strings_with_non_printable_characters() raises:
    var texts: List[String] = [
        "\x00",
        "a\x00b",
        "\x08",
        "\x0b",
        "\x0c",
        "\x0e",
        "\x0f",
    ]
    for ref text in texts:
        assert_false(is_printable_as_block_string(text))
    assert_true(is_printable_as_block_string("\x10"))


def test_is_printable_rejects_strings_with_only_empty_lines() raises:
    var texts: List[String] = ["\n", "\n\n", "\n\n\n", " \n  \n", "\t\n\t\t\n"]
    for ref text in texts:
        assert_false(is_printable_as_block_string(text))


def test_is_printable_rejects_strings_with_carriage_return() raises:
    var texts: List[String] = ["\r", "\n\r", "\r\n", "a\rb"]
    for ref text in texts:
        assert_false(is_printable_as_block_string(text))


def test_is_printable_rejects_strings_with_leading_empty_lines() raises:
    var texts: List[String] = ["\na", " \na", "\t\na", "\n\na"]
    for ref text in texts:
        assert_false(is_printable_as_block_string(text))


def test_is_printable_rejects_strings_with_trailing_empty_lines() raises:
    var texts: List[String] = ["a\n", "a\n ", "a\n\t", "a\n\n"]
    for ref text in texts:
        assert_false(is_printable_as_block_string(text))
    assert_true(is_printable_as_block_string("a\u00e9\nb"))


def expect_block_string(
    text: StringSlice, readable: String, minimize: String
) raises:
    """Assert graphql-js `printBlockString` in both modes."""
    assert_equal(print_block_string(text), readable)
    assert_equal(print_block_string(text, minimize=True), minimize)


def test_block_string_does_not_escape_characters() raises:
    var text = '" \\ / \x08 \x0c \n \r \t'
    expect_block_string(text, '"""\n' + text + '\n"""', '"""\n' + text + '"""')


def test_block_string_by_default_prints_as_single_line() raises:
    expect_block_string("one liner", '"""one liner"""', '"""one liner"""')


def test_block_string_ending_with_triple_quotation_is_multi_line() raises:
    expect_block_string(
        'triple quotation """',
        '"""\ntriple quotation \\"""\n"""',
        '"""triple quotation \\""""""',
    )


def test_block_string_single_line_with_leading_space() raises:
    expect_block_string(
        "    space-led string",
        '"""    space-led string"""',
        '"""    space-led string"""',
    )


def test_block_string_single_line_with_leading_space_and_trailing_quotation() raises:
    expect_block_string(
        '    space-led value "quoted string"',
        '"""    space-led value "quoted string"\n"""',
        '"""    space-led value "quoted string"\n"""',
    )


def test_block_string_single_line_with_trailing_backslash() raises:
    expect_block_string(
        "backslash \\",
        '"""\nbackslash \\\n"""',
        '"""backslash \\\n"""',
    )


def test_block_string_multi_line_with_internal_indent() raises:
    expect_block_string(
        "no indent\n with indent",
        '"""\nno indent\n with indent\n"""',
        '"""\nno indent\n with indent"""',
    )


def test_block_string_with_a_first_line_indentation() raises:
    var text = "    first  \n  line     \nindentation\n     string"
    expect_block_string(
        text,
        '"""\n    first  \n  line     \nindentation\n     string\n"""',
        '"""    first  \n  line     \nindentation\n     string"""',
    )


def test_block_string_long_and_crlf_lines() raises:
    var long = String("x") * 71
    assert_equal(print_block_string(long), '"""\n' + long + '\n"""')
    assert_equal(print_block_string("a\r\nb"), '"""\na\r\nb\n"""')
    assert_equal(print_block_string(""), '""""""')


def test_block_string_edge_layouts() raises:
    # A carriage return at the very end is its own line break.
    assert_equal(print_block_string("a\r"), '"""\na\r\n"""')
    # An empty line between two lines does not force a leading break.
    assert_equal(print_block_string("a\n\nb"), '"""\na\n\nb\n"""')
    # Four quotes: graphql-js escapes the first three, so the escaped
    # value does not end in an escaped triple quote.
    assert_equal(print_block_string('""""'), '"""\n\\""""\n"""')
    assert_equal(print_block_string('x"""'), '"""\nx\\"""\n"""')


def test_utf16_count_counts_surrogate_pairs() raises:
    assert_equal(utf16_count("aé\U0001f600".as_bytes()), 4)
    assert_equal(utf16_count("".as_bytes()), 0)


def test_print_string_prints_a_simple_string() raises:
    assert_equal(print_string("hello world"), '"hello world"')


def test_print_string_escapes_quotes() raises:
    assert_equal(print_string('"hello world"'), '"\\"hello world\\""')


def test_print_string_does_not_escape_single_quote() raises:
    assert_equal(print_string("who's test"), '"who\'s test"')


def test_print_string_escapes_backslashes() raises:
    assert_equal(print_string("escape: \\"), '"escape: \\\\"')


def test_print_string_escapes_well_known_control_chars() raises:
    assert_equal(print_string("\x08\x0c\n\r\t"), '"\\b\\f\\n\\r\\t"')


def test_print_string_escapes_zero_byte() raises:
    assert_equal(print_string("\x00"), '"\\u0000"')


def test_print_string_does_not_escape_space() raises:
    assert_equal(print_string(" "), '" "')


def test_print_string_does_not_escape_non_ascii_character() raises:
    assert_equal(print_string("\u21bb"), '"\u21bb"')


def test_print_string_does_not_escape_supplementary_character() raises:
    assert_equal(print_string("\U0001f600"), '"\U0001f600"')


def test_print_string_escapes_all_control_chars() raises:
    var text = String("")
    for code in range(0xA0):
        text += chr(code)
    var expected = (
        '"\\u0000\\u0001\\u0002\\u0003\\u0004\\u0005\\u0006\\u0007'
        + "\\b\\t\\n\\u000B\\f\\r\\u000E\\u000F"
        + "\\u0010\\u0011\\u0012\\u0013\\u0014\\u0015\\u0016\\u0017"
        + "\\u0018\\u0019\\u001A\\u001B\\u001C\\u001D\\u001E\\u001F"
        + " !\\\"#$%&'()*+,-./0123456789:;<=>?"
        + "@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\\\]^_"
        + "`abcdefghijklmnopqrstuvwxyz{|}~\\u007F"
        + "\\u0080\\u0081\\u0082\\u0083\\u0084\\u0085\\u0086\\u0087"
        + "\\u0088\\u0089\\u008A\\u008B\\u008C\\u008D\\u008E\\u008F"
        + "\\u0090\\u0091\\u0092\\u0093\\u0094\\u0095\\u0096\\u0097"
        + '\\u0098\\u0099\\u009A\\u009B\\u009C\\u009D\\u009E\\u009F"'
    )
    assert_equal(print_string(text), expected)
    assert_equal(print_string("\u00a0\u0800"), '"\u00a0\u0800"')


def test_print_source_location_prints_minified_documents() raises:
    var body = String(
        "query SomeMinifiedQueryWithErrorInside($foo:String!=FIRST_ERROR_HERE"
        "$bar:String){someField(foo:$foo bar:$bar baz:SECOND_ERROR_HERE)"
        "{fieldA fieldB{fieldC fieldD...on THIRD_ERROR_HERE}}}"
    )
    var source = Source(body)
    assert_equal(
        print_source_location(
            source, SourceLocation(1, body.find("FIRST_ERROR_HERE") + 1)
        ),
        "GraphQL request:1:53\n"
        + "1 | query SomeMinifiedQueryWithErrorInside($foo:String!="
        + "FIRST_ERROR_HERE$bar:String)\n"
        + "  |                                                     ^\n"
        + "  | {someField(foo:$foo bar:$bar baz:SECOND_ERROR_HERE){fieldA"
        + " fieldB{fieldC fieldD.",
    )
    assert_equal(
        print_source_location(
            source, SourceLocation(1, body.find("SECOND_ERROR_HERE") + 1)
        ),
        "GraphQL request:1:114\n"
        + "1 | query SomeMinifiedQueryWithErrorInside($foo:String!="
        + "FIRST_ERROR_HERE$bar:String)\n"
        + "  | {someField(foo:$foo bar:$bar baz:SECOND_ERROR_HERE){fieldA"
        + " fieldB{fieldC fieldD.\n"
        + "  |                                  ^\n"
        + "  | ..on THIRD_ERROR_HERE}}}",
    )
    assert_equal(
        print_source_location(
            source, SourceLocation(1, body.find("THIRD_ERROR_HERE") + 1)
        ),
        "GraphQL request:1:166\n"
        + "1 | query SomeMinifiedQueryWithErrorInside($foo:String!="
        + "FIRST_ERROR_HERE$bar:String)\n"
        + "  | {someField(foo:$foo bar:$bar baz:SECOND_ERROR_HERE){fieldA"
        + " fieldB{fieldC fieldD.\n"
        + "  | ..on THIRD_ERROR_HERE}}}\n"
        + "  |      ^",
    )


def test_print_source_location_prints_single_digit_line_number() raises:
    assert_equal(
        print_source_location(
            Source("*", "Test", SourceLocation(9, 1)), SourceLocation(1, 1)
        ),
        "Test:9:1\n9 | *\n  | ^",
    )


def test_print_source_location_prints_line_numbers_with_correct_padding() raises:
    assert_equal(
        print_source_location(
            Source("*\n", "Test", SourceLocation(9, 1)), SourceLocation(1, 1)
        ),
        "Test:9:1\n 9 | *\n   | ^\n10 |",
    )


def test_print_source_location_long_line_with_wide_characters() raises:
    # A pair is kept in the earlier piece; see the module docstring.
    var line = String("\U0001f600") * 70
    var text = print_source_location(Source(line), SourceLocation(1, 1))
    assert_true(text.startswith("GraphQL request:1:1\n1 | "))
    assert_true(text.endswith("  | " + String("\U0001f600") * 30))


def test_print_source_location_out_of_range_line() raises:
    assert_equal(
        print_source_location(Source("a"), SourceLocation(3, 1)),
        "GraphQL request:3:1\n3 |\n  | ^",
    )


def test_empty_parts_are_dropped() raises:
    var document = Document()
    var directive = document.add(Kind.DIRECTIVE, Role.ROOT)
    _ = document.add_name(directive, Role.NAME, "d")
    document.append_child(directive, document.add(Kind(99), Role.ARGUMENT))
    var argument = document.add_child(directive, Kind.ARGUMENT, Role.ARGUMENT)
    _ = document.add_name(argument, Role.NAME, "x")
    document.append_child(
        argument, document.add_text(Kind.INT, Role.VALUE, "1")
    )
    document.append_child(directive, document.add(Kind(99), Role.ARGUMENT))
    assert_equal(print_node(document, directive), "@d(x: 1)")
    var selections = document.add(Kind.SELECTION_SET, Role.ROOT)
    document.append_child(selections, document.add(Kind(99), Role.SELECTION))
    var field = document.add_child(selections, Kind.FIELD, Role.SELECTION)
    _ = document.add_name(field, Role.NAME, "f")
    document.append_child(selections, document.add(Kind(99), Role.SELECTION))
    assert_equal(print_node(document, selections), "{\n  f\n}")
    assert_equal(print_node(document, document.add(Kind(99), Role.ROOT)), "")


def test_block_string_quotes_and_line_starts() raises:
    # Two quotes that do not make three, and a quote near the end.
    assert_equal(
        printed('"""a ""b "c" d"e"""\nscalar S'),
        '"""a ""b "c" d"e"""\nscalar S',
    )
    # A trailing quote forces the multi-line form, as in graphql-js.
    assert_equal(print_block_string('a""b"'), '"""\na""b"\n"""')
    # A line that starts with a carriage return is an empty line.
    assert_equal(print_block_string("a\n\rb"), '"""\na\n\rb\n"""')


def test_indents_multi_line_arguments_inside_blocks() raises:
    assert_equal(
        printed('{ a(b: """x\ny""") }'),
        '{\n  a(b: """\n  x\n  y\n  """)\n}',
    )
    assert_equal(print_block_string('a""b'), '"""a""b"""')


def test_block_strings_from_source() raises:
    # A backslash takes the decoding path; a lone quote stays as it is.
    assert_equal(
        printed('"""a \\""" and "b" """\nscalar S'),
        '"""a \\""" and "b" """\nscalar S',
    )
    # Tabs indent, and a later line indented more than the others keeps
    # the extra indent.
    assert_equal(
        printed('"""\n\ta\n\tb\n"""\nscalar S'), '"""\na\nb\n"""\nscalar S'
    )
    assert_equal(
        printed('"""\n  first\n  a\n    b\n"""\nscalar S'),
        '"""\nfirst\na\n  b\n"""\nscalar S',
    )
    # Only blank lines: the value is empty.
    assert_equal(printed('"""   \n  """\nscalar S'), '""""""\nscalar S')
    # Carriage returns end lines too, alone or before a line feed.
    assert_equal(
        printed('"""\r\n  a\r\n  b\r\n"""\nscalar S'),
        '"""\na\nb\n"""\nscalar S',
    )
    assert_equal(
        printed('"""\r  a\r  b\r"""\nscalar S'), '"""\na\nb\n"""\nscalar S'
    )
    # Two quotes that are not three, after an escaped triple quote.
    assert_equal(
        printed('"""\\""" ""x """\nscalar S'), '"""\\""" ""x """\nscalar S'
    )
    # A long line that starts with a space gets no leading line break.
    var long = "  " + String("x") * 80
    assert_equal(
        printed('"""' + long + '"""\nscalar S'),
        '"""' + long + '\n"""\nscalar S',
    )


def test_nodes_printed_on_their_own() raises:
    var document = parse("{ f(a: 1) }")
    var selections = document.child(
        document.definitions()[0], Role.SELECTION_SET
    )
    var field = document.child(selections, Role.SELECTION)
    assert_equal(print_node(document, field), "f(a: 1)")
    assert_equal(print_node(document, document.child(field, Role.NAME)), "f")
    var built = Document()
    var directive = built.add(Kind.DIRECTIVE, Role.ROOT)
    _ = built.add_name(directive, Role.NAME, "d")
    built.append_child(directive, built.add(Kind(99), Role.ARGUMENT))
    assert_equal(print_node(built, directive), "@d")
    var empty = built.add(Kind.SELECTION_SET, Role.ROOT)
    assert_equal(print_node(built, empty), "")
    var hollow = built.add(Kind.SELECTION_SET, Role.ROOT)
    built.append_child(hollow, built.add(Kind(99), Role.SELECTION))
    assert_equal(print_node(built, hollow), "")
    assert_equal(print_string("a\x7f"), '"a\\u007F"')


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

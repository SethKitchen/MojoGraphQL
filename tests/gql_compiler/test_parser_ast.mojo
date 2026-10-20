# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the limits of the recovering parser and the AST it recovers.

Port of apollo-parser 0.8.6 (apollo-rs `b7eee5c`) `src/parser/mod.rs`
tests: `limited_mid_node`, `multiple_limits`, `syntax_errors_and_limits`,
`tree_with_syntax_errors`, `token_limit`, `recursion_limit` and
`no_infinite_loop`. The tree dump of `syntax_errors_and_limits` is a CST
dump, and is not compared. `parse_field_set` is not ported, because
`parse_selection_set` is not. The last tests check the AST that each
recovery leaves, as apollo-compiler `from_cst` converts it, and that the
entry points of gql_compiler record the syntax errors as diagnostics.
"""

from gql_compiler.diagnostics import Diagnostic, DiagnosticKind, DiagnosticList
from gql_compiler.from_ast import SchemaBuilder
from gql_compiler.parser import SyntaxTree, parse_recovering
from gql_compiler.validation import (
    parse_and_validate_executable,
    parse_and_validate_schema,
    validate_standalone_executable,
)
from gql_language.ast import Kind
from gql_language.printer import print_ast
from std.testing import TestSuite, assert_equal, assert_true

comptime _LIMIT = "token limit reached, aborting lexing"
"""The message of the token limit."""


def _errors(tree: SyntaxTree) -> String:
    """Return the errors of a parse, one `Debug` line each."""
    var out = String()
    for error in tree.errors:
        out += String(error, "\n")
    return out^


def _parse(text: String, limit: Int = Int.MAX, depth: Int = 500) -> SyntaxTree:
    """Parse with a token limit and a recursion limit."""
    return parse_recovering(text, "t.graphql", depth, limit)


def _kinds(tree: SyntaxTree) -> List[Kind]:
    """Return the kind of each definition."""
    var out = List[Kind]()
    for definition in tree.document.definitions():
        out.append(tree.document.kind(definition))
    return out^


def test_limited_mid_node() raises:
    var source = (
        "\n            type Query {\n                field(arg1: Int, arg2:"
        " Int, arg3: Int, arg4: Int, arg5: Int, arg6: Int): Int\n           "
        " }\n        "
    )
    assert_equal(
        _errors(_parse(source, 18)), String('ERROR@65:65 "', _LIMIT, '" \n')
    )


def test_multiple_limits() raises:
    var source = (
        "\n            query {\n                a {\n                    a"
        " {\n                        a {\n                           "
        " a\n                        }\n                    }\n          "
        "      }\n            }\n        "
    )
    assert_equal(
        _errors(_parse(source, 22, 10)),
        String('ERROR@170:170 "', _LIMIT, '" \n'),
    )
    assert_equal(
        _errors(_parse(source, 200, 3)),
        'ERROR@121:121 "parser recursion limit reached" \n',
    )


def test_syntax_errors_and_limits() raises:
    var source = (
        "\n            type Query {\n                field(arg1: Int,"
        " missing_arg): Int\n                # limit reached here\n        "
        "        field2: !String\n            } and then some garbage\n    "
        "    "
    )
    assert_equal(
        _errors(_parse(source, 22)),
        String(
            'ERROR@70:71 "expected a Name" )\n',
            'ERROR@113:113 "',
            _LIMIT,
            '" \n',
        ),
    )


def test_tree_with_syntax_errors() raises:
    var source = (
        "\n            garbage type Query implements X {\n               "
        " field(arg: Int): Int\n            } garbage :,, (|) interface X"
        " {}\n        "
    )
    var kinds = _kinds(_parse(source))
    assert_equal(len(kinds), 2)
    assert_true(kinds[0] == Kind.OBJECT_TYPE_DEFINITION)
    assert_true(kinds[1] == Kind.INTERFACE_TYPE_DEFINITION)


def test_token_limit() raises:
    var tree = _parse("type Query { a a a a a a a a a }", 100)
    assert_equal(tree.token_high, 26)
    assert_equal(tree.document.token_count, 26)


def _deep(count: Int) -> List[String]:
    """Return the `deep` documents of upstream `recursion_limit`."""
    var out = List[String]()
    out.append(
        String(
            "type O { field: ",
            _repeat("[", count),
            "Int",
            _repeat("]", count),
            " }",
        )
    )
    out.append(
        String(
            "type O { field(arg: T = ",
            _repeat("[", count),
            "0",
            _repeat("]", count),
            "): Int }",
        )
    )
    out.append(
        String(
            "type O { field(arg: T = ",
            _repeat("{f: ", count),
            "0",
            _repeat("}", count),
            "): Int }",
        )
    )
    out.append(
        String(
            "query { ", _repeat("f { ", count), "f ", _repeat("}", count), "}"
        )
    )
    return out^


def _wide(count: Int) -> List[String]:
    """Return the `wide` documents of upstream `recursion_limit`."""
    var out = List[String]()
    out.append(_repeat("directive @d on FIELD ", count))
    out.append(String("scalar Url", _repeat(" @d", count)))
    out.append(String("schema {", _repeat(" query: Q", count), " }"))
    out.append(String("type O implements", _repeat(" & I", count)))
    out.append(String("type O {", _repeat(" f: T", count), "}"))
    out.append(String("enum E {", _repeat(" V", count), "}"))
    out.append(String("union U = ", _repeat(" | T", count)))
    out.append(String("input In {", _repeat(" f: T", count), "}"))
    out.append(
        String(
            "type O { field(arg: T = {", _repeat(" f: 0", count), " }): Int }"
        )
    )
    out.append(
        String("type O { field(arg: T = [", _repeat(" 0,", count), " ]): Int }")
    )
    out.append(String("type O { field(", _repeat("a: T ", count), "): Int }"))
    out.append(String("query {", _repeat(" f", count), " }"))
    out.append(String("query { f(", _repeat(" a: 0", count), ") }"))
    out.append(String("query Q(", _repeat(" $v: Int", count), " ) { f }"))
    return out^


def test_recursion_limit() raises:
    for count in [2, 498, 25000]:
        for ref text in _wide(count):
            assert_equal(len(_parse(text).errors), 0, text)
    for count in [2, 498]:
        for ref text in _deep(count):
            assert_equal(len(_parse(text).errors), 0, text)
    for ref text in _deep(25000):
        var tree = _parse(text)
        assert_equal(len(tree.errors), 1)
        assert_true("recursion limit reached" in tree.errors[0].message)
        assert_equal(tree.recursion_high, 501)


def test_no_infinite_loop() raises:
    _ = _parse("{ ...", 3)


def _repeat(text: StringSlice, count: Int) -> String:
    """Return `count` copies of a text."""
    var out = String(capacity_bytes=text.byte_length() * count)
    var index = 0
    while index < count:
        out += text
        index += 1
    return out^


comptime _KITCHEN = (
    '"d" directive @a("x" b: [Int!]! = [1] @k) repeatable on | FIELD | QUERY\n'
    'directive @c on QUERY "s" schema @d { query: Q mutation: M }\n'
    '"d" scalar S @d "d" type T implements & I & J @d {\n'
    '  "f" f(a: Int = 1): [T!]! @d g: Int }\n'
    '"d" interface I implements J @d { f: Int } "d" union U @d = | A | B\n'
    '"d" enum E @d { "v" V @d W } "d" input In @d { "a" a: Int = 2 @d }\n'
    "extend schema @d { query: Q } extend scalar S @d\n"
    "extend type T implements I @d { f: Int }\n"
    "extend interface I implements J @d { f: Int } extend union U @d = A\n"
    "extend enum E @d { X } extend input In @d { b: Int }\n"
    'query Q($v: [Int] = [1, 2.5, "s", """b""", true, false, null, E, {a: 1}]'
    " @d) @d {\n"
    "  a: f(x: $v, y: {z: [$v]}) @d(if: true) {\n"
    "    ...F @d ... on T @d { g } ... @d { g } ... { g } }\n"
    "}\n"
    "mutation { m } subscription S { s } { a } fragment F on T @d { f }\n"
)
"""Every rule of the grammar, without errors."""

comptime _BROKEN = (
    "schema { foo: Query query Q mutation: [M] } query { a: } { f() g(a)"
    " h(a: ) i @ j(a: [}]) } { ... on T } { ... on { a } } { ...  }"
    " query ($a) { a } type T { f(a: [Int] = [$v, 1]): Int h(a: O = {a: )})"
    ': Int } type T { f: []! g: [Int h: [!] } directive a on FIELD "x"'
    ' directive @b FIELD directive @c on | FIELD | "x" extend schema'
    " extend foo fragment on on T { a } fragment G on { a } enum E {"
    ' "d" true } input In { a } "d", type T { a: Int } extend'
)
"""Most of the recoveries of the grammar."""


def _sweep_tokens(text: String) raises:
    """Parse a text with every token limit up to its token count.

    Before the count, the last error must be the token limit: no parser
    error follows it. At the count, no limit is reached.
    """
    var count = _parse(text).token_high
    var limit = 0
    while limit <= count:
        var tree = _parse(text, limit)
        var last = len(tree.errors) - 1
        if limit < count:
            assert_true(tree.errors[last].is_limit(), String(limit))
            assert_equal(tree.errors[last].message, _LIMIT)
            assert_equal(tree.token_high, limit)
        else:
            assert_true(last < 0 or not tree.errors[last].is_limit())
        limit += 1


def test_every_token_limit() raises:
    _sweep_tokens(_KITCHEN)
    _sweep_tokens(_BROKEN)
    assert_equal(len(_parse(_KITCHEN).errors), 0, _errors(_parse(_KITCHEN)))


def test_every_recursion_limit() raises:
    for ref text in _deep(3):
        var needed = _parse(text).recursion_high
        var depth = 0
        while depth < needed:
            var tree = _parse(text, Int.MAX, depth)
            assert_equal(len(tree.errors), 1, text)
            assert_equal(
                tree.errors[0].message, "parser recursion limit reached"
            )
            assert_equal(tree.recursion_high, depth + 1)
            depth += 1
        assert_equal(len(_parse(text, Int.MAX, needed).errors), 0)
    # The limit inside a list of a list value, and of a list type.
    var tree = _parse("type O { f(a: T = [[[0]]]): [[[Int]]] }", Int.MAX, 1)
    assert_equal(len(tree.errors), 1)


def _recover(text: String) -> String:
    """Return the errors of a parse, then the printed AST."""
    var tree = _parse(text)
    return String(_errors(tree), "--\n", print_ast(tree.document))


def test_recover_root_operations() raises:
    # An unknown operation type, a missing colon, and a list type: each
    # root operation is dropped, and the list ends the schema.
    assert_equal(
        _recover("schema { foo: Query query Q mutation: [M] }"),
        (
            "ERROR@9:12 \"expected either a 'mutation', a 'query', or a"
            " 'subscription'\" foo\n"
            'ERROR@26:27 "expected a Name Type" Q\n'
            "ERROR@26:27 \"expected either a 'mutation', a 'query', or a"
            " 'subscription'\" Q\n"
            'ERROR@28:36 "expected a Name Type" mutation\n'
            'ERROR@38:39 "expected R_CURLY, got [" [\n'
            'ERROR@38:39 "expected a StringValue, Name or OperationDefinition"'
            " [\n"
            'ERROR@39:40 "expected definition" M\n'
            'ERROR@40:41 "expected a StringValue, Name or OperationDefinition"'
            " ]\n"
            'ERROR@42:43 "expected a StringValue, Name or OperationDefinition"'
            " }\n--\nschema"
        ),
    )


def test_recover_fields_and_arguments() raises:
    var text = "query { a: } { f() g(a) h(a: ) i @ j(a: [}]) }"
    assert_equal(
        _recover(text),
        (
            'ERROR@11:12 "expected a Name" }\n'
            'ERROR@17:18 "expected an Argument" )\n'
            'ERROR@29:30 "expected a valid Value" )\n'
            'ERROR@41:42 "expected a valid Value" }\n'
            "--\n{\n  f\n  g\n  h\n  i @j(a: [])\n}"
        ),
    )
    # The first operation stays, with no selection.
    assert_equal(len(_kinds(_parse(text))), 2)


def test_recover_fragments() raises:
    assert_equal(
        _recover("{ ... on T } { ... on { a } } { ...  } { ... @d { a } }"),
        (
            'ERROR@11:12 "expected Selection Set" }\n'
            'ERROR@22:23 "expected a Name in Type Condition" {\n'
            'ERROR@32:35 "expected an Inline Fragment or a Fragment Spread"'
            " ...\n--\n{\n  ... @d {\n    a\n  }\n}"
        ),
    )
    var text = (
        "fragment on on T { a } fragment F T { a } fragment G on { a }"
        " fragment H on T"
    )
    assert_equal(
        _recover(text),
        (
            "ERROR@9:11 \"Fragment Name cannot be 'on'\" on\n"
            'ERROR@15:16 "expected a Selection Set" T\n'
            'ERROR@15:16 "expected definition" T\n'
            "ERROR@34:35 \"expected 'on'\" T\n"
            'ERROR@56:57 "expected a Name in Type Condition" {\n'
            'ERROR@77:77 "expected a Selection Set" EOF\n'
            "--\n{\n  a\n}\n\nfragment F on T {\n  a\n}"
        ),
    )


def test_recover_variables_and_values() raises:
    assert_equal(
        _recover(
            "query () { a } query ($a) { a } query ($a: ) { a }"
            " query ($a: Int = $b) { a }"
        ),
        (
            'ERROR@7:8 "expected a Variable Definition" )\n'
            'ERROR@24:25 "expected a Name" )\n'
            'ERROR@43:44 "expected a Type" )\n'
            'ERROR@68:69 "unexpected variable value in a Const context" $\n'
            "--\n{\n  a\n}\n\n{\n  a\n}\n\n{\n  a\n}\n\n"
            "query ($a: Int = $b) {\n  a\n}"
        ),
    )
    assert_equal(
        _recover(
            "type T { f(a: [Int] = [$v, 1]): Int g(a: Int = ): Int"
            " h(a: O = {a}): Int i(a: O = {a: )}): Int }"
        ),
        (
            'ERROR@23:24 "unexpected variable value in a Const context" $\n'
            'ERROR@27:28 "expected a Name" 1\n'
            'ERROR@47:48 "expected a valid Value" )\n'
            'ERROR@86:87 "expected a valid Value" )\n'
            "--\ntype T {\n  f(a: [Int] = [1]): Int\n  g: Int\n"
            "  h(a: O = {}): Int\n  i(a: O = {}): Int\n}"
        ),
    )
    assert_equal(
        _recover('{ f(a: "", b: """block""", c: "str") }'),
        '--\n{\n  f(a: "", b: """block""", c: "str")\n}',
    )


def test_recover_types() raises:
    assert_equal(
        _recover("type T { f: []! g: [Int h: [!] }"),
        (
            'ERROR@13:14 "expected item type" ]\n'
            'ERROR@14:15 "expected R_BRACK, got !" !\n'
            'ERROR@24:25 "expected R_BRACK, got h" h\n'
            'ERROR@28:29 "expected item type" !\n'
            "--\ntype T {\n  g: [Int]\n}"
        ),
    )


def test_recover_directive_definitions() raises:
    assert_equal(
        _recover(
            "directive a on FIELD directive @b FIELD directive @c on | FIELD |"
            ' "x" directive @d on'
        ),
        (
            'ERROR@10:11 "expected @ symbol" a\n'
            'ERROR@34:39 "expected Directive Locations" FIELD\n'
            'ERROR@66:69 "expected Directive Location" "x"\n'
            'ERROR@85:85 "expected valid Directive Location" EOF\n'
            "--\ndirective @a on FIELD\n\ndirective @b on FIELD\n\n"
            'directive @c on FIELD\n\n"x"\ndirective @d on '
        ),
    )


def test_recover_schema_and_extensions() raises:
    assert_equal(
        _recover(
            "schema @d schema {} extend schema extend schema {}"
            " extend schema { query: Q }"
        ),
        (
            'ERROR@18:19 "expected Root Operation Type Definition" }\n'
            'ERROR@34:40 "expected directives or Root Operation Type'
            ' Definition" extend\n'
            'ERROR@51:57 "expected directives or Root Operation Type'
            ' Definition" extend\n'
            "--\nschema @d\n\nschema\n\nextend schema\n\nextend schema\n\n"
            "extend schema {\n  query: Q\n}"
        ),
    )
    assert_equal(
        _recover(
            "extend scalar S extend type T extend interface I extend union U"
            " extend enum E extend input In extend foo"
        ),
        (
            'ERROR@16:22 "expected Directives" extend\n'
            'ERROR@30:36 "expected an Implements Interface, Directives or a'
            ' Fields Definition" extend\n'
            'ERROR@49:55 "exptected an Implements Interfaces, Directives, or a'
            ' Fields Definition" extend\n'
            'ERROR@64:70 "expected Directives or Union Member Types" extend\n'
            'ERROR@78:84 "expected Directive or Enum Values Definition"'
            " extend\n"
            'ERROR@94:100 "expected Directives or an Input Fields Definition"'
            " extend\n"
            'ERROR@94:100 "Invalid Type System Extension. This extension'
            ' cannot be applied." extend\n'
            'ERROR@101:104 "expected definition" foo\n'
            "--\nextend scalar S\n\nextend type T\n\nextend interface I\n\n"
            "extend union U\n\nextend enum E\n\nextend input In"
        ),
    )


def test_recover_type_definitions() raises:
    assert_equal(
        _recover(
            'type T implements & A & B {} enum E { "d" true null V @d }'
            " input In { a }"
        ),
        (
            'ERROR@27:28 "expected Field Definition" }\n'
            'ERROR@42:46 "invalid Enum Value" true\n'
            'ERROR@47:51 "invalid Enum Value" null\n'
            'ERROR@72:73 "expected a Name" }\n'
            '--\ntype T implements A & B\n\nenum E {\n  "d"\n  true\n'
            "  null\n  V @d\n}\n\ninput In"
        ),
    )
    assert_equal(
        _recover('"desc" query { a } "d", type T { a: Int } extend'),
        (
            'ERROR@0:6 "expected an Operation Type or a Selection Set"'
            ' "desc"\n'
            'ERROR@19:22 "expected definition" "d"\n'
            'ERROR@42:48 "Invalid Type System Extension. This extension'
            ' cannot be applied." extend\n'
            "--\n{\n  a\n}\n\ntype T {\n  a: Int\n}"
        ),
    )


def test_recover_edge_cases() raises:
    # Comments do not count when the parser looks ahead.
    assert_equal(
        _recover("{ a # c\n : b ... # d\n F }"),
        "--\n{\n  a: b\n  ...F\n}",
    )
    assert_equal(
        _recover("directive @a on FIELD | FOO enum E { false }"),
        (
            # The location is not taken, so the document skips it.
            'ERROR@24:27 "expected valid Directive Location" FOO\n'
            'ERROR@24:27 "expected definition" FOO\n'
            'ERROR@37:42 "invalid Enum Value" false\n'
            "--\ndirective @a on FIELD\n\nenum E {\n  false\n}"
        ),
    )
    # The recursion limit when the token limit has ended the stream.
    assert_equal(
        _errors(_parse("{ a }", 1, 0)), String('ERROR@1:1 "', _LIMIT, '" \n')
    )


def test_entry_points_record_syntax_errors() raises:
    var schema = parse_and_validate_schema("type Query { a: Int", "s.graphql")
    assert_equal(
        String(schema[1]),
        (
            "Error: syntax error: expected R_CURLY, got EOF\n╭─["
            " s.graphql:1:20 ]\n"
        ),
    )
    assert_equal(
        String(validate_standalone_executable("{ a ", "q.graphql")),
        "Error: syntax error: expected R_CURLY, got EOF\n╭─[ q.graphql:1:5 ]\n",
    )
    var executable = parse_and_validate_executable(
        schema[0], "{ a(x: ) }", "e.graphql"
    )
    assert_equal(
        String(executable[1]),
        "Error: syntax error: expected a valid Value\n╭─[ e.graphql:1:8 ]\n",
    )
    # A schema builder keeps the errors, and `build` raises with them.
    var builder = SchemaBuilder()
    builder.parse("type { a: Int }", "b.graphql")
    builder.parse(String("type Q { f: ", _repeat("[", 501), "Int }"))
    assert_equal(len(builder.syntax_errors), 2)
    assert_equal(builder.syntax_errors[0].source, 1)
    assert_equal(builder.syntax_errors[1].source, 2)
    var message = String()
    try:
        _ = builder^.build()
    except e:
        message = String(e)
    assert_equal(
        message, "syntax error: expected a name\nparser recursion limit reached"
    )


def test_locate_at_the_end() raises:
    var list = DiagnosticList()
    var one = list.file("one.graphql")
    var two = list.file("two.graphql")
    var three = list.file("three.graphql")
    list.push(Diagnostic(DiagnosticKind.SYNTAX_ERROR, one, 0, "empty"))
    list.push(Diagnostic(DiagnosticKind.SYNTAX_ERROR, two, 2, "no newline"))
    list.push(Diagnostic(DiagnosticKind.SYNTAX_ERROR, three, 4, "crlf"))
    list.sort()
    list.locate(one, _parse("").document)
    list.locate(two, _parse("ab").document)
    list.locate(three, _parse("ab\r\n").document)
    assert_equal(
        String(list),
        (
            "Error: syntax error: empty\n╭─[ one.graphql:1:1 ]\n"
            "Error: syntax error: no newline\n╭─[ two.graphql:1:3 ]\n"
            "Error: syntax error: crlf\n╭─[ three.graphql:1:5 ]\n"
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

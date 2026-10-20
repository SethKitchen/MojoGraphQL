# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the validation entry points and the diagnostics.

Port of apollo-compiler 1.33.0 (`b7eee5c`) `tests/validation/mod.rs`. A
test checks the `Error:` line and the `╭─[ file:line:column ]` line of each
diagnostic. Upstream checks the JSON form and the line and column range;
the JSON form is not ported.
"""

from gql_compiler.diagnostics import Diagnostic, DiagnosticKind, DiagnosticList
from gql_compiler.validation import (
    parse_and_validate_executable,
    parse_and_validate_schema,
    validate_executable,
    validate_schema,
    validate_standalone_executable,
)
from gql_compiler.executable import ExecutableDocument
from gql_compiler.schema import Schema
from gql_language.ast import Document, Node
from gql_language.source import Source
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _schema(sdl: String) raises -> Schema:
    """Parse and validate a schema that must be valid."""
    var result = parse_and_validate_schema(sdl, "schema.graphql")
    assert_true(result[1].is_empty(), String(result[1]))
    var schema = Schema()
    swap(schema, result[0])
    return schema^


def _query(schema: Schema, query: String) raises -> String:
    """Validate a query, and write its diagnostics."""
    return String(
        parse_and_validate_executable(schema, query, "query.graphql")[1]
    )


def test_executable_and_type_system_definitions() raises:
    var schema = _schema("\ntype Query {\n    name: String\n}\n")
    assert_equal(
        _query(
            schema, "\nfragment q on Query { name }\nquery {\n    ...q\n}\n"
        ),
        "",
    )


def test_executable_definition_does_not_contain_type_system_definitions() raises:
    var schema = _schema("\ntype Query {\n    name: String\n}\n")
    assert_equal(
        _query(
            schema,
            (
                "\ntype Object {\n    notAllowed: Boolean!\n}\nfragment q on"
                " Query { name }\nquery {\n    ...q\n}\n"
            ),
        ),
        (
            "Error: an executable document must not contain an object type"
            " definition\n╭─[ query.graphql:2:1 ]\n"
        ),
    )


def test_executable_definition_with_cycles_do_not_overflow_stack() raises:
    var schema = _schema("\ntype Query {\n    name: String\n}\n")
    var got = _query(
        schema, "\n{\n    ...q\n}\nfragment q on Query {\n    ...q\n}\n"
    )
    assert_true("`q` fragment cannot reference itself" in got, got)


def test_executable_definition_with_nested_cycles_do_not_overflow_stack() raises:
    var schema = _schema(
        "\ntype Query {\n    obj: TestObject\n}\n\ntype TestObject {\n   "
        " name: String\n}\n"
    )
    assert_equal(
        _query(
            schema,
            (
                "\n{\n    obj {\n        ...q\n    }\n}\n\nfragment q on"
                " TestObject {\n    ...q\n}\n"
            ),
        ),
        (
            "Error: `q` fragment cannot reference itself\n╭─["
            " query.graphql:8:1 ]\n"
        ),
    )


def test_validation_without_type_system() raises:
    assert_equal(
        String(
            validate_standalone_executable(
                "{ obj { name nickname } }", "valid.graphql"
            )
        ),
        "",
    )
    assert_equal(
        String(
            validate_standalone_executable(
                (
                    "\n            fragment A on Type { a }\n            query"
                    " { b }\n        "
                ),
                "dupe_frag.graphql",
            )
        ),
        (
            "Error: fragment `A` must be used in an operation\n╭─["
            " dupe_frag.graphql:2:13 ]\n"
        ),
    )
    assert_equal(
        String(
            validate_standalone_executable(
                (
                    "\n            fragment A on Type { a }\n           "
                    " fragment A on Type { b }\n            query { ...A }\n   "
                    "     "
                ),
                "dupe_frag.graphql",
            )
        ),
        (
            "Error: the fragment `A` is defined multiple times in the"
            " document\n╭─[ dupe_frag.graphql:3:22 ]\n"
        ),
    )
    assert_equal(
        String(
            validate_standalone_executable("{ ...A }", "unknown_frag.graphql")
        ),
        (
            "Error: cannot find fragment `A` in this document\n╭─["
            " unknown_frag.graphql:1:3 ]\n"
        ),
    )


def test_validate_variable_usage_without_type_system() raises:
    var input = (
        "\n    query nullableStringArg($nonNullableVar: String!,"
        " $nonNullableList: [String!]!, $nonNullableListList: [[Int!]!]) {\n "
        "     arguments {\n        nullableString(nullableString:"
        " $nonNullableVar)\n        nullableList(nullableList:"
        " $nonNullableList)\n        nullableListList(nullableListList:"
        " $nonNullableListList)\n      }\n    }\n    "
    )
    assert_equal(
        String(validate_standalone_executable(input, "query.graphql")), ""
    )


def test_json_location_with_multibyte() raises:
    var schema = _schema(
        "\ntype Query {\n    obj: TestObject\n}\n\ntype TestObject {\n   "
        " name: String\n}\n"
    )
    assert_equal(
        _query(
            schema,
            (
                "\n{\n    # กรุงเทพมหานคร อมรรัตนโกสินทร์\n    obj { ...q }\n  "
                "  # City of angels\n}\n"
            ),
        ),
        (
            "Error: cannot find fragment `q` in this document\n╭─["
            " query.graphql:4:11 ]\n"
        ),
    )


def test_missing_fragment_in_standalone_validation() raises:
    var input = (
        "\n        query {\n            company {\n                user {\n "
        "                 ...UserFragment\n                }\n               "
        " ...CompanyFragment\n            }\n        }\n        fragment"
        " UserFragment on User {\n            id\n            name\n       "
        " }\n    "
    )
    var got = String(validate_standalone_executable(input, "query.graphql"))
    assert_true(
        "cannot find fragment `CompanyFragment` in this document" in got, got
    )


def _message(kind: UInt8) -> String:
    """Return the message of a kind with the fields a to f."""
    return Diagnostic(
        DiagnosticKind(kind), -1, 0, "a", "b", "c", "d", "e", "f"
    ).message()


def test_diagnostic_messages() raises:
    var expected: List[String] = [
        "the variable `$a` is declared multiple times",
        "the argument `a` is provided multiple times",
        "the value `a` is defined multiple times",
        "the argument `a` is not supported by `b`",
        "cannot find type `a` in this document",
        "cannot find directive `@a` in this document",
        "variable `$a` is not defined",
        "cannot find fragment `a` in this document",
        "value `a` does not exist on `b`",
        "field `a` does not exist on `b`",
        "type `a` does not satisfy interface `b`: missing field `c`",
        (
            "interface field `b.c` expects type `d` but `a.c` of type `e` is"
            " not a proper subtype"
        ),
        (
            "interface field `b.c` expects argument `d` but `a.c` does not"
            " provide it"
        ),
        (
            "interface field `b.c` expects argument `d` of type `e` but `a.c`"
            " provides type `f`"
        ),
        "`a.c` has extra required argument `d` not present in interface `b.c`",
        "the required argument `a` is not provided",
        "the required field `a` is not provided",
        (
            "interface `a` declares that it implements `b`, but to do so it"
            " must also implement `c`"
        ),
        "`a` field must return an output type",
        "`a` field must be of an input type",
        "`$a` variable must be of an input type",
        "missing query root operation type in schema definition",
        "unused variable: `$a`",
        "`a` field must return an object type",
        "the same type `a` must not be used for multiple root operation types",
        "union member `a` must be an object type",
        "a directive is not supported for b location",
        "expected value of type a, found b",
        "int cannot represent non 32-bit signed integer value",
        "float cannot represent non-finite 64-bit floating point value",
        "non-repeatable directive a can only be used once per location",
        "interface, union and object types must have a subselection set",
        "fragment `a` must have a composite type in its type condition",
        "fragment `a` with type condition `c` cannot be applied to `b`",
        "fragment `a` must be used in an operation",
        "variable `$a` of type `b` cannot be used for argument `c` of type `d`",
        "`a` directive definition cannot reference itself",
        "interface a cannot implement itself",
        "`a` input object cannot reference itself",
        "`a` fragment cannot reference itself",
        "`a` contains too much nesting",
        "too much recursion",
        "`a` has no fields",
        "`a` has no enum values",
        "`a` has no member types",
        "`a` has no input values",
        (
            "b cannot be named `a` as names starting with two underscores are"
            " reserved"
        ),
        "subscription `a` can only have one root field",
        "subscription `a` can not have an introspection field as a root field",
        "subscription `a` can not specify @skip or @include on root fields",
        "`@defer` label `a` is not unique within the document",
        "`@defer` label argument must be a static String, not a variable",
        "`@defer` is not allowed on root selections of a operations",
        (
            "`@defer` in a subscription operation must be disabled with an `if`"
            " argument"
        ),
        "operation must not select different types using the same name `a`",
        (
            "operation must not provide conflicting field arguments for the"
            " same name `a`"
        ),
        "cannot select different fields into the same alias `a`",
        "a",
        "a",
        "syntax error: a",
        "too much recursion",
        "a",
    ]
    var kind = 0
    while kind < len(expected):
        assert_true(DiagnosticKind(UInt8(kind)).is_valid())
        assert_equal(_message(UInt8(kind)), expected[kind], String(kind))
        kind += 1
    assert_false(DiagnosticKind(62).is_valid())
    assert_equal(String(DiagnosticKind(3)), "DiagnosticKind(3)")
    var inline = Diagnostic(DiagnosticKind.INVALID_FRAGMENT_TARGET, -1, 0)
    assert_equal(
        inline.message(),
        "inline fragment must have a composite type in its type condition",
    )
    var anonymous = Diagnostic(
        DiagnosticKind.SUBSCRIPTION_USES_MULTIPLE_FIELDS, -1, 0
    )
    assert_equal(
        anonymous.message(),
        "anonymous subscription can only have one root field",
    )


def test_diagnostic_list_sort_and_locate() raises:
    var list = DiagnosticList()
    assert_true(list.is_empty())
    list.sort()
    var first = list.file("one.graphql")
    var second = list.file("two.graphql")
    assert_equal(list.file("one.graphql"), first)
    list.push(Diagnostic(DiagnosticKind.SYNTAX_ERROR, second, 2, "x"))
    list.push(Diagnostic(DiagnosticKind.SYNTAX_ERROR, first, 9, "late"))
    list.push(Diagnostic(DiagnosticKind.SYNTAX_ERROR, first, 1, "early"))
    list.push(Diagnostic(DiagnosticKind.RECURSION_LIMIT_ERROR, -1, 0))
    list.push(Diagnostic(DiagnosticKind.SYNTAX_ERROR, first, 1, "tie"))
    var third = list.file("three.graphql")
    list.push(Diagnostic(DiagnosticKind.SYNTAX_ERROR, third, 9, "end"))
    list.sort()
    assert_equal(len(list), 6)
    var document = parse_document_text("a\r\nb\rcé d")
    list.locate(first, document)
    list.locate(second, parse_document_text("xyz"))
    list.locate(third, parse_document_text("ab\r"))
    assert_equal(
        String(list),
        (
            "Error: too much recursion\n"
            "Error: syntax error: early\n╭─[ one.graphql:1:2 ]\n"
            "Error: syntax error: tie\n╭─[ one.graphql:1:2 ]\n"
            "Error: syntax error: late\n╭─[ one.graphql:3:4 ]\n"
            "Error: syntax error: x\n╭─[ two.graphql:1:3 ]\n"
            # Ariadne starts no line after the final `\r`.
            "Error: syntax error: end\n╭─[ three.graphql:1:4 ]\n"
        ),
    )


def test_validate_schema() raises:
    var schema = _schema("type Query { a: Int }")
    assert_true(validate_schema(schema).is_empty())


def parse_document_text(text: String) -> Document:
    """Return a document that holds only a source text."""
    return Document(Source(text), List[Node](), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()


def test_validate_executable() raises:
    var schema = _schema("type Query { a: Int }")
    var built = ExecutableDocument.parse(schema, "query Q($v: Int) { a }")
    assert_equal(
        String(validate_executable(schema, built[0])),
        "Error: unused variable: `$v`\n╭─[ GraphQL request:1:9 ]\n",
    )

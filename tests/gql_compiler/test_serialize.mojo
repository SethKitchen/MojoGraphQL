# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the schema and type system serializer.

Port of apollo-compiler 1.33.0 (`b7eee5c`) `tests/schema.rs`
`test_schema_reserialize`, and of `tests/snapshot_tests.rs`
`serialize_and_reparse_ast` for the fixtures of
`test_data/serializer/` that hold only type system definitions. The
fixtures are in `_serializer_fixtures.mojo`.
"""

from gql_compiler.from_ast import SchemaBuilder
from gql_compiler.schema import Schema
from gql_compiler.serialize import (
    State,
    can_be_block_string,
    serialize_document,
    serialize_schema,
    serialize_string_value,
    serialize_value,
)
from gql_language.ast import Kind, Role
from gql_language.parser import parse, parse_value
from std.os import listdir
from std.os.path import exists
from std.pathlib import Path

from _serializer_fixtures import (
    serializer_cases,
    serializer_input,
    serializer_output,
)
from std.testing import TestSuite, assert_equal, assert_raises, assert_true


def _schema(text: StringSlice) raises -> Schema:
    var builder = SchemaBuilder()
    builder.parse(text)
    return builder^.build()


def test_schema_reserialize() raises:
    var input = """
        extend type Query {
            withArg(arg: Boolean): String @deprecated,
        }

        type Query {
            int: Int,
        }

        extend type Query implements Inter

        interface Inter {
            string: String
        }

        extend type Query @customDirective

        extend type Query {
            string: String,
        }

        directive @customDirective on OBJECT
    """
    var expected = """directive @customDirective on OBJECT

type Query {
  int: Int
}

extend type Query @customDirective

extend type Query implements Inter

extend type Query {
  withArg(arg: Boolean): String @deprecated
}

extend type Query {
  string: String
}

interface Inter {
  string: String
}
"""
    assert_equal(_schema(input).to_string(), expected)


comptime FIXTURES = "tests/gql_compiler/serializer_fixtures/"
"""The fixture files, from the repository root."""


def _document(text: StringSlice) raises -> String:
    var document = parse(text)
    return serialize_document(document)


def test_serialize_and_reparse_ast() raises:
    var paths = serializer_cases()
    assert_equal(len(paths), 74)
    for index in range(len(paths)):
        var serialized = _document(serializer_input(index))
        assert_equal(serialized, serializer_output(index), paths[index])
        assert_equal(_document(serialized), serialized, paths[index])


def test_serializer_fixtures_are_current() raises:
    if not exists(FIXTURES):
        return
    var paths = List[String]()
    for directory in ["diagnostics", "ok"]:
        var entries = listdir(FIXTURES + "input/" + directory)
        sort(entries)
        for ref entry in entries:
            paths.append(String(directory, "/", entry))
    var embedded = serializer_cases()
    assert_equal(len(embedded), len(paths))
    for index in range(len(paths)):
        assert_equal(embedded[index], paths[index])
        var input = Path(FIXTURES + "input/" + paths[index]).read_text()
        var output = Path(FIXTURES + "output/" + paths[index]).read_text()
        assert_equal(serializer_input(index), input, paths[index])
        assert_equal(serializer_output(index), output, paths[index])
    assert_equal(serializer_input(len(paths)), "")
    assert_equal(serializer_output(len(paths)), "")


def test_document_rejects_executable_definitions() raises:
    with assert_raises(contains="only type system definitions"):
        _ = _document("type Query { a: Int } query { a }")


def test_no_indent() raises:
    var document = parse(
        '"Q" type Query implements I @a(x: [1, 2]) {'
        ' "F" f("A" x: Int = 1 @d, y: [Int!]!): String }'
        " schema { query: Query } enum E { A }"
    )
    assert_equal(
        serialize_document(document, newlines=False),
        (
            '"Q" type Query implements I @a(x: [1, 2]) {'
            ' "F" f("A" x: Int = 1 @d, y: [Int!]!): String }'
            " schema { query: Query } enum E { A }"
        ),
    )
    assert_equal(SchemaBuilder().build().serialize(newlines=False), "")


def test_indent_prefix() raises:
    var document = parse("type Query { a(x: [Int] = [1]): Int }")
    assert_equal(
        serialize_document(
            document, indent_prefix="\t", initial_indent_level=1
        ),
        "type Query {\n\t\ta(x: [Int] = [1]): Int\n\t}\n",
    )
    document = parse("input I { a: [Int] = [1, 2] }")
    assert_equal(
        serialize_document(document),
        "input I {\n  a: [Int] = [\n    1,\n    2,\n  ]\n}\n",
    )


def test_quoted_strings() raises:
    var document = parse_value('"a\\b\\f\\n\\r\\t\\"\\\\\\u0001\\u001F"')
    assert_equal(
        serialize_value(document, document.root),
        '"a\\b\\f\\n\\r\t\\"\\\\\\u0001\\u001F"',
    )
    document = parse_value('"plain"')
    assert_equal(serialize_value(document, document.root), '"plain"')
    document = parse_value('"two\\nlines"')
    assert_equal(
        serialize_value(document, document.root), '"""\ntwo\nlines\n"""'
    )
    assert_equal(
        serialize_value(document, document.root, newlines=False),
        '"two\\nlines"',
    )


def test_values() raises:
    var document = parse_value(
        '[$v, null, true, false, E, 1, -2.5e3, "s", {a: $v, b: []}, {}]'
    )
    assert_equal(
        serialize_value(document, document.root, newlines=False),
        '[$v, null, true, false, E, 1, -2.5e3, "s", {a: $v, b: []}, {}]',
    )
    assert_equal(
        serialize_value(document, document.root, initial_indent_level=1),
        (
            "[\n    $v,\n    null,\n    true,\n    false,\n    E,\n    1,\n"
            '    -2.5e3,\n    "s",\n    {\n      a: $v,\n      b: [],\n    },\n'
            "    {},\n  ]"
        ),
    )


def _description(text: StringSlice) raises -> String:
    return _document(String(text, " scalar S"))


def test_descriptions() raises:
    assert_equal(_description('"short"'), '"""short"""\nscalar S\n')
    assert_equal(_description('""'), '""\nscalar S\n')
    assert_equal(_description('"   indented"'), '"   indented"\nscalar S\n')
    assert_equal(_description('"a\\n "'), '"a\\n "\nscalar S\n')
    assert_equal(_description('" \\na"'), '" \\na"\nscalar S\n')
    assert_equal(_description('"  a\\n  b"'), '"  a\\n  b"\nscalar S\n')
    assert_equal(_description('"a\\n  b"'), '"""\na\n  b\n"""\nscalar S\n')
    assert_equal(_description('"a\\n\\nb"'), '"""\na\n\nb\n"""\nscalar S\n')
    assert_equal(_description('"a\\r\\nb"'), '"a\\r\\nb"\nscalar S\n')
    assert_equal(
        _description('"say \\"hi\\""'), '"""\nsay "hi"\n"""\nscalar S\n'
    )
    assert_equal(_description('"back\\\\"'), '"""\nback\\\n"""\nscalar S\n')
    assert_equal(
        _description('"x\\"\\"\\"y\\"\\"\\"z"'),
        '"""x\\"""y\\"""z"""\nscalar S\n',
    )
    var long = String("0123456789") * 8
    assert_equal(
        _description(String('"', long, '"')),
        String('"""\n', long, '\n"""\nscalar S\n'),
    )
    assert_equal(
        _document('type Q { "a\\nb" f: Int }'),
        'type Q {\n  """\n  a\n  b\n  """\n  f: Int\n}\n',
    )


def test_implicit_schema_definition() raises:
    assert_equal(_schema("type Query { a: Int }").to_string(), _query())
    assert_equal(
        _schema("schema { query: Query } type Query { a: Int }").to_string(),
        _query(),
    )
    assert_equal(
        _schema(
            "schema { query: Query } type Query { a: Int } scalar Mutation"
        ).to_string(),
        _query() + "\nscalar Mutation\n",
    )


def _query() -> String:
    return "type Query {\n  a: Int\n}\n"


def test_explicit_schema_definition() raises:
    assert_equal(
        _schema("schema { query: Q } type Q { a: Int }").to_string(),
        "schema {\n  query: Q\n}\n\ntype Q {\n  a: Int\n}\n",
    )
    assert_equal(
        _schema("schema { query: Q } type Q { a: Int } type Query").to_string(),
        "schema {\n  query: Q\n}\n\ntype Q {\n  a: Int\n}\n\ntype Query\n",
    )
    assert_equal(
        _schema(
            "schema { query: Query } type Query { a: Int } type Mutation"
        ).to_string(),
        "schema {\n  query: Query\n}\n\n" + _query() + "\ntype Mutation\n",
    )
    assert_equal(
        _schema(
            "schema { query: Query mutation: Mutation }"
            " type Query { a: Int } interface Mutation"
        ).to_string(),
        "schema {\n  query: Query\n  mutation: Mutation\n}\n\n"
        + _query()
        + "\ninterface Mutation\n",
    )
    assert_equal(
        _schema('"S" schema { query: Query } type Query { a: Int }').serialize(
            newlines=False
        ),
        '"S" schema { query: Query } type Query { a: Int }',
    )


def test_schema_extensions() raises:
    var schema = _schema(
        "schema @a { query: Query } type Query { a: Int }"
        " extend schema @b extend schema { mutation: M subscription: S }"
        " type M type S directive @a on SCHEMA directive @b on SCHEMA"
    )
    assert_equal(
        schema.to_string(),
        "schema @a {\n  query: Query\n}\n\nextend schema @b\n\n"
        "extend schema {\n  mutation: M\n  subscription: S\n}\n\n"
        "directive @a on SCHEMA\n\ndirective @b on SCHEMA\n\n"
        + _query()
        + "\ntype M\n\ntype S\n",
    )
    # An extension of the implicit definition makes it explicit.
    assert_equal(
        _schema(
            "type Query { a: Int } extend schema @d directive @d on SCHEMA"
        ).to_string(),
        "schema {\n  query: Query\n}\n\nextend schema @d\n\n"
        "directive @d on SCHEMA\n\n"
        + _query(),
    )
    var builder = SchemaBuilder().adopt_orphan_extensions()
    builder.parse("extend schema { query: Q } type Q { a: Int }")
    assert_equal(
        builder^.build().to_string(),
        "extend schema {\n  query: Q\n}\n\ntype Q {\n  a: Int\n}\n",
    )


def test_type_extensions() raises:
    var schema = _schema(
        "type Query { a: Int } extend scalar Int @d"
        " directive @d on SCALAR | OBJECT | UNION | ENUM | INPUT_OBJECT"
        " | INTERFACE"
        " directive @deprecated(reason: String) on FIELD_DEFINITION"
        " interface I { a: Int } extend interface I implements J @d"
        " interface J { a: Int } union U extend union U @d = Query | X"
        " type X { a: Int } enum E { A } extend enum E { B }"
        " input In { a: Int } extend input In @d { b: Int = 1 }"
    )
    assert_equal(
        schema.to_string(),
        # A redefined built-in directive keeps the built-in's place, as an
        # `IndexMap` insert does upstream.
        "directive @deprecated(reason: String) on FIELD_DEFINITION\n\n"
        "directive @d on SCALAR | OBJECT | UNION | ENUM | INPUT_OBJECT"
        " | INTERFACE\n\n"
        "extend scalar Int @d\n\n"
        + _query()
        + "\ninterface I {\n  a: Int\n}\n\n"
        "extend interface I implements J @d\n\n"
        "interface J {\n  a: Int\n}\n\nunion U\n\n"
        "extend union U @d = Query | X\n\ntype X {\n  a: Int\n}\n\n"
        "enum E {\n  A\n}\n\nextend enum E {\n  B\n}\n\n"
        "input In {\n  a: Int\n}\n\nextend input In @d {\n  b: Int = 1\n}\n",
    )


def test_serialize_schema_arguments() raises:
    var schema = _schema(
        'type Query { "D" a("x" x: Int, y: Int @d): Int @d(r: "s") }'
        " directive @d(r: String) repeatable on FIELD_DEFINITION"
        " | ARGUMENT_DEFINITION"
    )
    assert_equal(
        serialize_schema(schema),
        (
            "directive @d(r: String) repeatable on FIELD_DEFINITION"
            " | ARGUMENT_DEFINITION\n\ntype Query {\n  "
            '"""D"""\n  a(\n    """x"""\n    x: Int,\n    y: Int @d,\n  ): Int'
            ' @d(r: "s")\n}\n'
        ),
    )
    assert_equal(
        serialize_schema(schema, indent_prefix="    ", initial_indent_level=1),
        (
            "directive @d(r: String) repeatable on FIELD_DEFINITION"
            " | ARGUMENT_DEFINITION\n\n    type Query {\n        "
            '"""D"""\n        a(\n            """x"""\n            x: Int,\n'
            '            y: Int @d,\n        ): Int @d(r: "s")\n    }\n'
        ),
    )


def test_block_strings_from_source() raises:
    assert_equal(_description('""""""'), '""\nscalar S\n')
    assert_equal(_description('"""   """'), '""\nscalar S\n')
    assert_equal(_description('"""  a"""'), '"  a"\nscalar S\n')
    assert_equal(_description('"""\n  a\n"""'), '"""a"""\nscalar S\n')
    # The common indent of the lines after the first is removed.
    assert_equal(_description('"""a\n  b"""'), '"""\na\nb\n"""\nscalar S\n')
    assert_equal(
        _description('"""a\n  b\n    c"""'), '"""\na\nb\n  c\n"""\nscalar S\n'
    )
    assert_equal(
        _description('"""a\r\nb\rc"""'), '"""\na\nb\nc\n"""\nscalar S\n'
    )
    assert_equal(
        _description('"""say "hi"\n"""'), '"""\nsay "hi"\n"""\nscalar S\n'
    )
    assert_equal(
        _description('"""\n  a\n\n  b\n"""'), '"""\na\n\nb\n"""\nscalar S\n'
    )
    assert_equal(_description('"x\\"\\"y"'), '"""x""y"""\nscalar S\n')


def test_string_helpers() raises:
    assert_true(can_be_block_string("a\n  b"))
    assert_true(not can_be_block_string("  a\n  b"))
    var state = State("  ", True, 0)
    serialize_string_value(state, True, "a")
    serialize_string_value(state, False, "a")
    assert_equal(state^.finish(), '"""a""""a"')
    var document = parse_value('"a\\"b\\u0041"')
    assert_equal(serialize_value(document, document.root), '"a\\"bA"')
    var node = document.add_text(Kind.STRING, Role.ROOT, "a\nb")
    assert_equal(serialize_value(document, node), '"""\na\nb\n"""')
    var long = String("0123456789") * 30
    document = parse_value(String('["', long, '", "', long, '"]'))
    assert_equal(
        serialize_value(document, document.root, newlines=False),
        String('["', long, '", "', long, '"]'),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_mcp.serialize`.

apollo-compiler 2.0.0-beta.1 `src/ast/serialize.rs` has no tests of its
own for these forms. The expected texts are the output of the Apollo MCP
Server 2.0.0 (04e4e6e) `introspect` tool
(`crates/apollo-mcp-server/src/introspection/tools/introspect.rs`), which
prints `ExtendedType::serialize().to_string()`, for the schema of
`_serialize_fixture.mojo` with `depth: 1`.
"""

from gql_language.ast import OperationType
from gql_language.parser import parse
from gql_schema.build import build_schema
from gql_schema.definition import Schema
from gql_mcp.serialize import (
    SdlWriter,
    can_be_block_string,
    serialize_type,
    write_string_value,
)
from gql_mcp.tree_shake import DepthLimit, SchemaTreeShaker
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _serialize_fixture import feature_sdl


def _introspect(schema: Schema, name: String) raises -> String:
    """The text of the `introspect` tool for one type with depth 1."""
    var shaker = SchemaTreeShaker(schema)
    shaker.retain_type(
        schema, schema.type_named(name), None, DepthLimit.limited(1)
    )
    var shaken = shaker.shaken(schema)
    assert_equal(shaken.type_count(), 1)
    return shaken.serialize_type(schema, 0)


def test_object_type() raises:
    var schema = build_schema(feature_sdl())
    assert_equal(
        _introspect(schema, "Root"),
        '"""A short one"""\n'
        + 'type Root implements Node & Named @tag(name: "root", extra: [3,'
        + " 4]) {\n"
        + '  """\n'
        + "  This is a description that is definitely longer than seventy"
        + " characters in total length.\n"
        + '  """\n'
        + "  id: ID!\n"
        + "  name: String\n"
        + '  """\n'
        + '  Ends with a quote "x"\n'
        + '  """\n'
        + "  quoted: String\n"
        + '  """Has a triple \\""" quote inside"""\n'
        + "  triple: String\n"
        + '  "  leading space line"\n'
        + "  spaced: String\n"
        + '  "has\\rcarriage"\n'
        + "  cr: String\n"
        + '  """\n'
        + "  ends with backslash \\\n"
        + '  """\n'
        + "  slash: String\n"
        + '  """\n'
        + "  Line one\n"
        + "    Line two indented\n"
        + "\n"
        + "  Line four\n"
        + '  """\n'
        + "  multi: String\n"
        + '  "\\n  starts blank"\n'
        + "  blank: String\n"
        + '  "  a\\n  b"\n'
        + "  indented: String\n"
        + '  plain(a: Int, b: [String!]! = ["x", "y"], c: Point = {x: 1, y:'
        + " 2.5}): Int\n"
        + "  described(\n"
        + '    """arg desc"""\n'
        + "    a: Int = 1,\n"
        + '    b: Color = RED @tag(name: "b"),\n'
        + "  ): [Root!]\n"
        + "  noDesc(\n"
        + '    a: Int @deprecated(reason: "old"),\n'
        + "  ): Boolean @deprecated\n"
        + '  defaults(s: String = "a\\nb", e: [Int] = [], o: Point = {}, n:'
        + " Int = null, f: Boolean = false, t: Boolean = true, nested:"
        + ' [[Int]] = [[1], [2, 3]]): String @tag(name: "x\ty\\u0001z")\n'
        + "  shape: Shape\n"
        + "  search: Result\n"
        + "}\n",
    )


def test_input_object_type() raises:
    var schema = build_schema(feature_sdl())
    assert_equal(
        _introspect(schema, "Point"),
        'input Point @tag(name: "p") {\n'
        + '  """x coord"""\n'
        + '  x: Int = 0 @tag(name: "px")\n'
        + "  y: Float\n"
        + "  list: [Int] = [\n"
        + "    1,\n"
        + "    2,\n"
        + "  ]\n"
        + "  obj: Inner = {\n"
        + "    a: [\n"
        + "      1,\n"
        + "      2,\n"
        + "    ],\n"
        + "    b: {\n"
        + '      c: """\n'
        + "      d\n"
        + "      e\n"
        + '      """,\n'
        + "    },\n"
        + "  }\n"
        + "}\n",
    )
    assert_equal(
        _introspect(schema, "Inner"),
        "input Inner {\n  a: [Int]\n  b: Deep\n}\n",
    )


def test_other_types() raises:
    var schema = build_schema(feature_sdl())
    assert_equal(
        _introspect(schema, "Shape"),
        'scalar Shape @specifiedBy(url: "https://example.com/shape")\n',
    )
    assert_equal(
        _introspect(schema, "Result"), 'union Result @tag(name: "u")\n'
    )
    assert_equal(
        _introspect(schema, "Named"),
        (
            'interface Named implements Node @tag(name: "i") {\n  id: ID!\n '
            " name: String\n}\n"
        ),
    )
    assert_equal(
        _introspect(schema, "Color"),
        (
            'enum Color @tag(name: "e") {\n  """red one"""\n  RED\n  GREEN'
            ' @deprecated(reason: "no\\nmore")\n  BLUE @tag(name: "b")\n}\n'
        ),
    )
    assert_equal(
        _introspect(schema, "Mutation"),
        "type Mutation {\n  doIt(input: Point): Int\n}\n",
    )
    assert_equal(
        serialize_type(schema, schema.type_named("Result")),
        'union Result @tag(name: "u") = Root | Mutation\n',
    )


def test_whole_shaken_schema() raises:
    var schema = build_schema(feature_sdl())
    var shaker = SchemaTreeShaker(schema)
    shaker.retain_type(
        schema, schema.type_named("Color"), None, DepthLimit.limited(1)
    )
    shaker.retain_operation_type(
        schema, OperationType.QUERY, DepthLimit.limited(1)
    )
    var text = shaker.shaken(schema).to_string(schema)
    assert_true(
        text.startswith(
            '"""The schema description"""\nschema @link(url: "x") {\n  query:'
            + " Root\n}\n\ndirective @tag(\n"
            + '  """The tag name"""\n'
            + "  name: String!,\n"
            + "  extra: [Int] = [\n"
            + "    1,\n"
            + "    2,\n"
            + "  ],\n"
            + ") repeatable on FIELD_DEFINITION | OBJECT | ARGUMENT_DEFINITION"
            + " | INPUT_FIELD_DEFINITION | ENUM_VALUE | SCALAR | INTERFACE |"
            + " UNION | ENUM | INPUT_OBJECT\n\n"
            + '"""A short one"""\ntype Root'
        )
    )
    assert_true(
        text.endswith(
            '\n}\n\nenum Color @tag(name: "e") {\n'
            + '  """red one"""\n  RED\n  GREEN @deprecated(reason:'
            ' "no\\nmore")\n'
            + '  BLUE @tag(name: "b")\n}\n'
        )
    )


def test_string_values() raises:
    var writer = SdlWriter()
    write_string_value(writer, False, "plain")
    writer.write(" ")
    write_string_value(writer, False, "two\nlines")
    writer.write(" ")
    write_string_value(writer, True, "\x08\x0c\x1f\x7f é")
    writer.newlines = False
    writer.write(" ")
    write_string_value(writer, True, "one\ntwo")
    assert_equal(
        writer^.take(),
        '"plain" """\ntwo\nlines\n""" """\x08\x0c\x1f\x7f é""" "one\\ntwo"',
    )
    var quoted = SdlWriter()
    write_string_value(quoted, False, "")
    write_string_value(quoted, False, '\x08\x0c"\\\x1b\x0a\x09')
    assert_equal(quoted^.take(), '"""\\b\\f\\"\\\\\\u001B\\n\t"')
    assert_false(can_be_block_string("a\r"))
    assert_false(can_be_block_string(" \nb"))
    assert_false(can_be_block_string("a\n\t"))
    assert_false(can_be_block_string("  a\n\n  b"))
    assert_true(can_be_block_string("a\n  b"))
    assert_true(can_be_block_string("  a\nb"))


def test_directive_and_empty_definitions() raises:
    var schema = build_schema(
        "directive @plain on FIELD_DEFINITION\n"
        + "directive @args(a: Int) on FIELD | QUERY\n"
        + "type Query { a: Int @plain }\n"
        + "type Empty\nenum None\ninput Nothing\nunion Nobody\n"
    )
    var shaker = SchemaTreeShaker(schema)
    for name in ["Query", "Empty", "None", "Nothing", "Nobody"]:
        shaker.retain_type(
            schema, schema.type_named(name), None, DepthLimit.UNLIMITED
        )
    var document = parse("query Q { a @args(a: 1) }")
    shaker.retain_operation(
        schema, document, document.definitions()[0], DepthLimit.UNLIMITED
    )
    assert_equal(
        shaker.shaken(schema).to_string(schema),
        "directive @plain on FIELD_DEFINITION\n\ndirective @args(a: Int) on"
        " FIELD |"
        + " QUERY\n\ntype Query {\n  a: Int @plain\n}\n\ntype Empty\n\nenum"
        + " None\n\ninput Nothing\n\nunion Nobody\n",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

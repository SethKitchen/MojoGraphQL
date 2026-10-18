# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the SDL encoder of `rover graph introspect` and its layout.

The cases follow Rover `crates/rover-client/src/operations/graph/
introspect/schema.rs` and the serializer tests of apollo-compiler 1.33.0
`src/ast/serialize.rs`. The whole-schema case is in `test_introspect.mojo`,
against the output of Rover itself.
"""

from gql_json.parser import parse
from gql_seamstress.encode import encode_schema, type_reference
from gql_seamstress.serialize import Serializer, can_be_block_string
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _string(text: String, is_description: Bool) -> String:
    var out = Serializer()
    out.string_value(text, is_description)
    return out^.take()


def test_string_values() raises:
    assert_equal(_string('a"b\\c\td', False), '"a\\"b\\\\c\td"')
    assert_equal(
        _string("\x08\x0c\r\x01\x1f", False), '"\\b\\f\\r\\u0001\\u001F"'
    )
    assert_equal(_string("one\ntwo", False), '"""\none\ntwo\n"""')
    assert_equal(_string("short", True), '"""short"""')
    assert_equal(_string('has """ quotes', True), '"""has \\""" quotes"""')
    assert_equal(_string("x" * 71, True), '"""\n' + "x" * 71 + '\n"""')
    assert_equal(_string('ends with "', True), '"""\nends with "\n"""')
    assert_equal(_string("ends with \\", True), '"""\nends with \\\n"""')
    assert_equal(_string('a\n\nb """', True), '"""\na\n\nb \\"""\n"""')
    assert_equal(_string("a\r\nb", True), '"a\\r\\nb"')
    assert_equal(_string(" ", True), '" "')
    assert_equal(_string("", False), '""')
    var single = Serializer()
    single.newlines = False
    single.string_value("one\ntwo", True)
    assert_equal(single^.take(), '"one\\ntwo"')


def test_can_be_block_string() raises:
    assert_true(can_be_block_string("a\n  b"))
    assert_false(can_be_block_string("a\rb"))
    assert_false(can_be_block_string("\na"))
    assert_false(can_be_block_string("a\n "))
    assert_false(can_be_block_string("  a\n  b"))
    assert_true(can_be_block_string("a\n\n\tb"))
    assert_true(can_be_block_string(" a\nb"))
    assert_false(can_be_block_string("\ta\n\n\tb"))


def test_serializer_lines() raises:
    var out = Serializer()
    out.write("{")
    out.indent(True)
    out.write("a")
    out.new_line_or_space()
    out.write("b")
    out.dedent(True)
    out.write("}")
    out.description(None)
    assert_equal(out^.take(), "{\n  a\n  b\n}")
    var flat = Serializer()
    flat.newlines = False
    flat.write("{")
    flat.indent(True)
    flat.write("a")
    flat.indent(False)
    flat.dedent(False)
    flat.dedent(True)
    flat.write("}")
    assert_equal(flat^.take(), "{ a }")


def _encode(schema: String) raises -> String:
    var document = parse('{"__schema":' + schema + "}")
    return encode_schema(document, document.root)


def _error(schema: String) raises -> String:
    try:
        _ = _encode(schema)
    except e:
        return String(e)
    raise Error("no error for " + schema)


comptime _NAMED = '{"kind":"SCALAR","name":"String"}'


def test_schema_definitions() raises:
    assert_equal(
        _encode('{"queryType":{"name":"Query"},"types":[],"directives":[]}'), ""
    )
    assert_equal(
        _encode('{"queryType":{"name":"Root"}}'), "schema {\n  query: Root\n}\n"
    )
    assert_equal(
        _encode(
            '{"queryType":{"name":"Q"},"mutationType":{"name":"M"},"subscriptionType":{}}'
        ),
        "schema {\n  query: Q\n  mutation: M\n  subscription: \n}\n",
    )
    assert_equal(
        _encode(
            '{"queryType":null,"mutationType":null,"subscriptionType":{"name":"S"}}'
        ),
        "schema {\n  subscription: S\n}\n",
    )
    assert_equal(_encode('{"queryType":{"name":null}}'), "")
    assert_equal(_encode('{"types":[]}'), "")
    assert_equal(
        _encode('{"queryType":{"name":"Q"},"mutationType":{"name":"M"}}'),
        "schema {\n  query: Q\n  mutation: M\n}\n",
    )
    var empty = parse("{}")
    try:
        _ = encode_schema(empty, empty.root)
        raise Error("no error")
    except e:
        assert_equal(String(e), "Schema not found in Introspection Result.")
    assert_equal(_error("null"), "Schema not found in Introspection Result.")


def test_types() raises:
    var types = (
        '[{"kind":"OBJECT","name":"NoFields","fields":null},'
        '{"kind":"INTERFACE","name":"NoFields2"},'
        '{"kind":"INPUT_OBJECT","name":"NoInput","inputFields":null},'
        '{"kind":"WHAT","name":"Odd"},{"kind":"OBJECT","name":null,"fields":[]},'
        '{"kind":"SCALAR","name":"__Type"},'
        '{"kind":"UNION","name":"Empty"},'
        '{"kind":"ENUM","name":"Bare","enumValues":null},'
        '{"kind":"OBJECT","name":"Empty2","fields":[],"interfaces":null},'
        '{"kind":"INTERFACE","name":"I","description":"Two\\nlines",'
        '"interfaces":[{"kind":"INTERFACE","name":"J"},{"kind":"INTERFACE","name":"K"}],'
        '"fields":[{"name":"f","args":[{"name":"a","type":'
        + _NAMED
        + ',"defaultValue":""},'
        '{"name":"b","type":{"kind":"LIST","ofType":{"kind":"NON_NULL","ofType":{"kind":"NON_NULL","ofType":'
        + _NAMED
        + '}}},"defaultValue":"[\\"x\\"]"}],'
        '"type":{"kind":"NON_NULL","ofType":{"kind":"LIST","ofType":'
        + _NAMED
        + '}},"isDeprecated":true}]},'
        '{"kind":"ENUM","name":"E","enumValues":[{"name":"A","isDeprecated":true,"deprecationReason":"why'
        ' \\"x\\""}]},'
        '{"kind":"INPUT_OBJECT","name":"In","inputFields":[{"name":"x","description":"d","type":'
        + _NAMED
        + "}]}]"
    )
    var directives = (
        '[{"name":"skip"},{"name":"include"},{"name":"deprecated"},'
        '{"name":"d","locations":["FIELD","VARIABLE_DEFINITION",5,"QUERY"],"args":[]},'
        '{"name":"e","args":null,"locations":null}]'
    )
    assert_equal(
        _encode(
            '{"queryType":{"name":"Query"},"types":'
            + types
            + ',"directives":'
            + directives
            + "}"
        ),
        (
            'type Empty2\n\n"""\nTwo\nlines\n"""\ninterface I implements J & K'
            ' {\n  f(a: String, b: [String!] = ["x"]): [String]!'
            " @deprecated\n}\n\nunion Empty\n\nenum Bare\n\nenum E {\n  A"
            ' @deprecated(reason: "why \\"x\\"")\n}\n\ninput In {\n  """d"""\n '
            " x: String\n}\n\ndirective @d on FIELD | QUERY\n\ndirective @e\n"
        ),
    )


def test_type_reference_errors() raises:
    var document = parse(
        '[{"name":"x"},{"kind":"LIST"},{"kind":"NON_NULL","ofType":5},{"kind":"SCALAR"},{"kind":"FOO","name":"x"}]'
    )
    var items = document.children(document.root)
    var messages: List[String] = [
        "Unknown type kind: null",
        "a LIST type has no ofType",
        "a NON_NULL type has no ofType",
        "a named type has no name",
        "Unknown type kind: FOO",
    ]
    for index in range(len(items)):
        try:
            _ = type_reference(document, items[index])
            raise Error("no error")
        except e:
            assert_equal(String(e), messages[index])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

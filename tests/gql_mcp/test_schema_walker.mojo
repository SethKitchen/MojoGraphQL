# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_mcp.schema_walker`.

Ports the tests of Apollo MCP Server 2.0.0 (04e4e6e)
`crates/apollo-mcp-server/src/operations/schema_walker.rs` and
`operations/schema_walker/name.rs`. The upstream compares
`serde_json::Value`s, so the tests compare JSON without regard to member
order.
"""

from gql_json.parser import parse as parse_json
from gql_json.value import NO_NODE
from gql_language.ast import Document, Role
from gql_language.parser import parse
from gql_mcp.custom_scalar_map import CustomScalarMap
from gql_mcp.json_tree import JsonTree
from gql_mcp.schema_walker import (
    ast_type_ref,
    graphql_value_to_json,
    ryu_text,
    type_to_schema,
)
from gql_schema.build import build_schema
from gql_schema.definition import Schema, TypeRef
from std.testing import TestSuite, assert_equal, assert_true

comptime SDL = """
    scalar BigInt

    enum Status {
        OPEN
        CLOSED
    }

    input Filter {
        status: Status = OPEN
        limit: Int! = 20
        tags: [String!]
        name: String!
    }

    type Query {
        things(filter: Filter): String
    }
"""


@fieldwise_init
struct Converted(Movable):
    var tree: JsonTree
    var schema: Int
    var definitions: Int


def convert(
    definition: String,
    description: Optional[String] = None,
    sdl: StringSlice = SDL,
    scalars: CustomScalarMap = CustomScalarMap(),
) raises -> Converted:
    """Run `type_to_schema` for the one variable of `query Q(...)`."""
    var schema = build_schema(sdl)
    var document = parse("query Q(" + definition + ") { things }")
    var operation = document.definitions()[0]
    var variable = document.child(operation, Role.VARIABLE_DEFINITION)
    var tree = JsonTree()
    var definitions = tree.add_object()
    var node = type_to_schema(
        tree,
        definitions,
        schema,
        ast_type_ref(schema, document, document.child(variable, Role.TYPE)),
        scalars,
        description,
        document,
        document.child(variable, Role.DEFAULT_VALUE),
    )
    return Converted(tree^, node, definitions)


def assert_json(tree: JsonTree, node: Int, expected: StringSlice) raises:
    """Assert that a value equals JSON text, members in any order."""
    var document = parse_json(expected)
    var other = JsonTree()
    other.root = other.add_document(document, document.root)
    if not tree.equals(node, other, other.root):
        assert_equal(tree.to_string(node), other.to_string(other.root))


def default_of(definition: String) raises -> String:
    var converted = convert(definition)
    var found = converted.tree.find(converted.schema, "default")
    if found == NO_NODE:
        return "none"
    return converted.tree.to_string(found)


def test_nullable_named_type_allows_null() raises:
    var c = convert("$v: String")
    assert_json(
        c.tree, c.schema, '{"anyOf": [{"type": "string"}, {"type": "null"}]}'
    )


def test_non_null_named_type_is_bare() raises:
    var c = convert("$v: String!")
    assert_json(c.tree, c.schema, '{"type": "string"}')


def test_nullable_list_of_nullable_items_allows_null_at_both_levels() raises:
    var c = convert("$v: [Int]")
    assert_json(
        c.tree,
        c.schema,
        '{"anyOf": [{"type": "array", "items": {"anyOf": [{"type":'
        + ' "integer"}, {"type": "null"}]}}, {"type": "null"}]}',
    )


def test_non_null_list_of_non_null_items_is_bare() raises:
    var c = convert("$v: [Int!]!")
    assert_json(
        c.tree, c.schema, '{"type": "array", "items": {"type": "integer"}}'
    )


def test_description_is_attached_to_the_outermost_schema() raises:
    var c = convert("$v: [Int]", String("Some numbers"))
    assert_json(
        c.tree,
        c.schema,
        '{"description": "Some numbers", "anyOf": [{"type": "array", "items":'
        + ' {"anyOf": [{"type": "integer"}, {"type": "null"}]}}, {"type":'
        + ' "null"}]}',
    )


def test_nullable_reference_wraps_the_ref() raises:
    var c = convert("$v: Status")
    assert_json(
        c.tree,
        c.schema,
        '{"anyOf": [{"$ref": "#/definitions/Status"}, {"type": "null"}]}',
    )


def test_default_value_is_emitted_as_json() raises:
    assert_equal(default_of("$v: Int = 10"), "10")
    assert_equal(default_of("$v: Float = 1.5"), "1.5")
    assert_equal(default_of('$v: String = "x"'), '"x"')
    assert_equal(default_of("$v: Boolean = false"), "false")
    assert_equal(default_of("$v: Status = OPEN"), '"OPEN"')
    assert_equal(default_of("$v: [Int] = [1, 2]"), "[1,2]")
    assert_equal(
        default_of('$v: Filter = { name: "n", limit: 5 }'),
        '{"name":"n","limit":5}',
    )


def test_explicit_null_default_is_emitted_as_json_null() raises:
    assert_equal(default_of("$v: String = null"), "null")


def test_integer_default_outside_i64_is_omitted() raises:
    assert_equal(default_of("$v: BigInt = 12345678901234567890123"), "none")


def test_float_default_outside_f64_is_omitted() raises:
    assert_equal(default_of("$v: Float = 1e999"), "none")


def test_variable_default_has_no_json_representation() raises:
    assert_equal(value_json("$other"), "none")


def test_single_value_default_for_list_type_is_coerced_to_a_list() raises:
    assert_equal(default_of("$v: [Int!]! = 1"), "[1]")
    assert_equal(default_of("$v: [[Int]] = 1"), "[[1]]")
    assert_equal(default_of("$v: [Int] = [1, 2]"), "[1,2]")


def test_int_default_for_id_is_emitted_as_a_string() raises:
    assert_equal(default_of("$v: ID = 123"), '"123"')


def test_input_object_default_coerces_fields_against_their_declared_types() raises:
    assert_equal(
        default_of('$v: Filter = { name: "n", tags: "a" }'),
        '{"name":"n","tags":["a"]}',
    )


def test_no_default_value_means_no_default_keyword() raises:
    assert_equal(default_of("$v: Int"), "none")


def test_input_field_default_value_is_emitted() raises:
    var c = convert("$v: Filter!")
    var filter = c.tree.find(c.definitions, "Filter")
    var status = c.tree.find(c.tree.find(filter, "properties"), "status")
    assert_equal(c.tree.to_string(c.tree.find(status, "default")), '"OPEN"')


def test_input_field_with_default_value_is_not_required() raises:
    var c = convert("$v: Filter!")
    var filter = c.tree.find(c.definitions, "Filter")
    assert_equal(c.tree.to_string(c.tree.find(filter, "required")), '["name"]')


def test_int_maps_to_integer() raises:
    var c = convert("$v: Int!", sdl="type Query { things: String }")
    assert_json(c.tree, c.schema, '{"type": "integer"}')


def test_float_maps_to_number() raises:
    var c = convert("$v: Float!", sdl="type Query { things: String }")
    assert_json(c.tree, c.schema, '{"type": "number"}')


def value_json(
    value: String, type_text: String = "", sdl: StringSlice = SDL
) raises -> String:
    """Convert the literal of `things(filter: <value>)` against the type of
    `$t: <type_text>`, or without a type."""
    var schema = build_schema(sdl)
    var source = "query Q"
    if type_text != "":
        source += "($t: " + type_text + ")"
    var document = parse(source + " { things(filter: " + value + ") }")
    var operation = document.definitions()[0]
    var type = Optional[TypeRef](None)
    if type_text != "":
        var variable = document.child(operation, Role.VARIABLE_DEFINITION)
        type = ast_type_ref(
            schema, document, document.child(variable, Role.TYPE)
        )
    var selections = document.child(operation, Role.SELECTION_SET)
    var field = document.child(selections, Role.SELECTION)
    var argument = document.child(field, Role.ARGUMENT)
    var tree = JsonTree()
    var node = graphql_value_to_json(
        tree, document, document.child(argument, Role.VALUE), type, schema
    )
    if node == NO_NODE:
        return "none"
    return tree.to_string(node)


def test_values_without_json() raises:
    assert_equal(value_json("[1, $x]", "[Int]"), "none")
    assert_equal(value_json("$x", "[Int]"), "none")
    assert_equal(value_json("{name: $x}", "Filter"), "none")
    assert_equal(value_json("9223372036854775808"), "none")
    assert_equal(value_json("99999999999999999999", "[Int]"), "none")


def test_values_by_shape() raises:
    assert_equal(value_json("{a: 1, b: [2.50], a: 3}"), '{"a":3,"b":[2.5]}')
    assert_equal(value_json("{a: 1}", "Int"), '{"a":1}')
    assert_equal(value_json("{a: 1}", "Status"), '{"a":1}')
    assert_equal(
        value_json("{nope: 1, tags: 2}", "Filter"), '{"nope":1,"tags":[2]}'
    )
    assert_equal(value_json("5", "Nope"), "5")
    assert_equal(
        value_json("-9223372036854775808", "Int"), "-9223372036854775808"
    )
    assert_equal(value_json("[1]", "[ID]"), '["1"]')
    assert_equal(value_json("1.0", "Float"), "1.0")


def test_ryu_text() raises:
    assert_equal(ryu_text(1.0), "1.0")
    assert_equal(ryu_text(-0.0), "-0.0")
    assert_equal(ryu_text(0.0), "0.0")
    assert_equal(ryu_text(100.0), "100.0")
    assert_equal(ryu_text(1.5), "1.5")
    assert_equal(ryu_text(-1.5), "-1.5")
    assert_equal(ryu_text(0.5), "0.5")
    assert_equal(ryu_text(0.0001), "0.0001")
    assert_equal(ryu_text(0.00001), "0.00001")
    assert_equal(ryu_text(1.5e-7), "1.5e-7")
    assert_equal(ryu_text(1e-6), "1e-6")
    assert_equal(ryu_text(1e16), "1e+16")
    assert_equal(ryu_text(1e15), "1000000000000000.0")
    assert_equal(ryu_text(1e17), "1e+17")
    assert_equal(ryu_text(1.2345e20), "1.2345e+20")
    assert_equal(ryu_text(1e21), "1e+21")
    assert_equal(ryu_text(1.2345e25), "1.2345e+25")
    assert_equal(ryu_text(1234567890123456.7), "1234567890123456.8")
    assert_equal(ryu_text(123456.789), "123456.789")


comptime SCALARS_SDL = """
    "Big integers"
    scalar BigInt
    scalar Plain
    scalar Truthy
    scalar Falsy
    scalar Numbered
    "Its own"
    scalar Described
    "An enum"
    enum Mood {
        "Happy mood"
        HAPPY
        SAD
    }
    input Many {
        a: BigInt
        b: Plain
        c: Truthy
        d: Falsy
        e: Numbered
        h: Described
        r1: Int!
        r2: Int!
        f: Mood
        g: Mood
        self: Many
        list: [Many!]! = []
    }
    type Query { things(many: Many): String }
"""


def test_custom_scalars_and_shared_definitions() raises:
    var scalars = CustomScalarMap.parse(
        '{"BigInt": {"type": "string"}, "Truthy": true, "Falsy": false,'
        + ' "Described": {"description": "own"},'
        + ' "Numbered": {"description": 5}, "Unused": {"description": "u"}}'
    )
    var c = convert("$v: Many!", None, SCALARS_SDL, scalars)
    assert_json(c.tree, c.schema, '{"$ref": "#/definitions/Many"}')
    assert_json(
        c.tree,
        c.definitions,
        """{
        "BigInt": {"type": "string", "description": "Big integers"},
        "Plain": true,
        "Truthy": true,
        "Falsy": false,
        "Numbered": {"description": 5},
        "Described": {"description": "own"},
        "Mood": {"type": "string", "enum": ["HAPPY", "SAD"],
            "description": "An enum\\n\\nValues:\\nHAPPY: Happy mood\\nSAD: "},
        "Many": {"type": "object", "properties": {
            "a": {"anyOf": [{"$ref": "#/definitions/BigInt"}, {"type": "null"}]},
            "b": {"anyOf": [{"$ref": "#/definitions/Plain"}, {"type": "null"}]},
            "c": {"anyOf": [{"$ref": "#/definitions/Truthy"}, {"type": "null"}]},
            "d": {"anyOf": [{"$ref": "#/definitions/Falsy"}, {"type": "null"}]},
            "e": {"anyOf": [{"$ref": "#/definitions/Numbered"}, {"type": "null"}]},
            "h": {"anyOf": [{"$ref": "#/definitions/Described"}, {"type": "null"}]},
            "r1": {"type": "integer"},
            "r2": {"type": "integer"},
            "f": {"anyOf": [{"$ref": "#/definitions/Mood"}, {"type": "null"}]},
            "g": {"anyOf": [{"$ref": "#/definitions/Mood"}, {"type": "null"}]},
            "self": {"anyOf": [{"$ref": "#/definitions/Many"}, {"type": "null"}]},
            "list": {"type": "array", "items": {"$ref": "#/definitions/Many"},
                "default": []}}, "required": ["r1", "r2"]}
        }""",
    )


def test_descriptions_of_boolean_schemas() raises:
    var scalars = CustomScalarMap.parse('{"Truthy": true, "Falsy": false}')
    var sdl = String(
        '"T" scalar Truthy "F" scalar Falsy input I { t: Truthy, f: Falsy }'
        + " type Query { things(i: I): String }"
    )
    var c = convert("$v: I", None, sdl, scalars)
    assert_json(
        c.tree,
        c.tree.find(c.definitions, "Truthy"),
        '{"description": "T"}',
    )
    assert_json(
        c.tree,
        c.tree.find(c.definitions, "Falsy"),
        '{"not": {}, "description": "F"}',
    )


def test_types_outside_the_input_types() raises:
    var c = convert("$v: Nope", String("d"))
    assert_json(
        c.tree,
        c.schema,
        '{"anyOf": [{}, {"type": "null"}], "description": "d"}',
    )
    var d = convert("$v: Query!")
    assert_json(d.tree, d.schema, "{}")
    assert_equal(d.tree.length(d.definitions), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

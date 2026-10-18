# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of the introspection fixtures of Rover 1.0.0 (`39a041a`).

Port of the tests of `crates/rover-client/src/operations/graph/introspect/`
`schema.rs`, `introspection_json.rs` and `introspection_parity.rs`, and of
`src/command/graph/introspect.rs`. The fixtures are the upstream
`crates/rover-client/src/operations/graph/introspect/fixtures/` files.
`<name>.sdl.graphql` is the expected SDL of `<name>.json`, from the
`indoc!` text of the upstream test. The suite reads the fixtures from
`_fixture_data.mojo`, because `make coverage` copies only Mojo files.

`format_plain_returns_sdl` is not ported: upstream returns the SDL that
it got, and the introspection snapshots of `test_introspect.mojo` check
the plain output.
"""

from _fixture_data import fixture_text
from gql_json.parser import parse as parse_json
from gql_json.value import JsonDocument, JsonKind, NO_NODE
from gql_json.writer import stringify
from gql_schema.build import build_schema
from gql_schema.validate import assert_valid_schema
from gql_seamstress.encode import encode_schema
from gql_seamstress.introspection_json import sdl_to_introspection_json
from gql_seamstress.output import success_json
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime SIMPLE_SDL = """
        type Query {
            hello: String
        }
    """
"""The SDL of the upstream `top_level_shape` test."""


def _encode(name: String) raises -> String:
    var document = parse_json(fixture_text(name + ".json"))
    return encode_schema(document, document.find(document.root, "data"))


def test_it_builds_simple_schema() raises:
    assert_equal(_encode("simple"), fixture_text("simple.sdl.graphql"))


def test_it_builds_swapi_schema() raises:
    assert_equal(_encode("swapi"), fixture_text("swapi.sdl.graphql"))


def test_it_builds_schema_with_interfaces() raises:
    assert_equal(_encode("interfaces"), fixture_text("interfaces.sdl.graphql"))


def test_deprecated_reason_with_quotes_is_escaped() raises:
    var document = parse_json(
        '{"__schema":{"queryType":{"name":"Query"},"types":[{"kind":"OBJECT",'
        '"name":"Query","fields":[{"name":"value","args":[],"type":{"kind":'
        '"SCALAR","name":"String"},"isDeprecated":true,"deprecationReason":'
        '"use \\"valueV2.data\\""}],"interfaces":[]}],"directives":[]}}'
    )
    var sdl = encode_schema(document, document.root)
    assert_true(
        sdl.find('@deprecated(reason: "use \\"valueV2.data\\"")') >= 0, sdl
    )


def _validated_sdl(document: JsonDocument) raises -> String:
    """Encode an introspection result and validate the SDL, as upstream
    `introspection_json_to_validated_sdl`."""
    var sdl = encode_schema(document, document.root)
    assert_valid_schema(build_schema(sdl))
    return sdl^


def test_top_level_shape() raises:
    var result = parse_json(sdl_to_introspection_json(SIMPLE_SDL))
    var root = result.root
    var schema = result.find(root, "__schema")
    assert_true(schema != NO_NODE)
    assert_equal(result.find(root, "data"), NO_NODE)
    assert_equal(result.find(root, "errors"), NO_NODE)
    assert_true(result.find(schema, "queryType") != NO_NODE)
    assert_true(result.find(schema, "directives") != NO_NODE)
    var kinds = List[String]()
    for item in result.children(result.find(schema, "types")):
        var kind = result.string_value(result.find(item, "kind"))
        assert_equal(kind, kind.upper())
        kinds.append(kind^)
    assert_true("OBJECT" in kinds)
    assert_true("SCALAR" in kinds)


def _items(document: JsonDocument, node: Int, key: String) -> List[Int]:
    """Return the members of an array member; empty when it is missing."""
    var found = document.find(node, key)
    if found == NO_NODE or document.kind(found) != JsonKind.ARRAY:
        return List[Int]()
    return document.children(found)


def _name(document: JsonDocument, node: Int) -> String:
    return document.string_value(document.find(node, "name"))


def _names(document: JsonDocument, node: Int, key: String) -> List[String]:
    """Return the sorted names of an array member, as upstream `names_set`."""
    var out = List[String]()
    for item in _items(document, node, key):
        out.append(_name(document, item))
    sort(out)
    return out^


def _named(document: JsonDocument, node: Int, key: String, name: String) -> Int:
    """Return the member of an array member with a name, or `NO_NODE`."""
    for item in _items(document, node, key):
        if _name(document, item) == name:
            return item
    return NO_NODE


def _type_ref(document: JsonDocument, node: Int) -> String:
    """Return a type reference without its extra members, as upstream
    `normalize_type_ref`."""
    if node == NO_NODE or document.kind(node) == JsonKind.NULL:
        return "null"
    var out = stringify(document, document.find(node, "kind")) + ":"
    out += stringify(document, document.find(node, "name"))
    var of_type = document.find(node, "ofType")
    if of_type != NO_NODE and document.kind(of_type) != JsonKind.NULL:
        out += "(" + _type_ref(document, of_type) + ")"
    return out^


def _compare_typed(
    actual: JsonDocument,
    a: Int,
    reference: JsonDocument,
    r: Int,
    key: String,
    context: String,
) raises:
    """Compare the names and the type references of `fields`, `args` or
    `inputFields`, as upstream `compare_fields` and `compare_args`."""
    var names = _names(reference, r, key)
    assert_equal(_names(actual, a, key), names, key + " on " + context)
    for ref name in names:
        var mine = _named(actual, a, key, name)
        var theirs = _named(reference, r, key, name)
        assert_equal(
            _type_ref(actual, actual.find(mine, "type")),
            _type_ref(reference, reference.find(theirs, "type")),
            context + "." + name,
        )
        if key == "fields":
            _compare_typed(
                actual, mine, reference, theirs, "args", context + "." + name
            )


def _structural_parity(actual: JsonDocument, reference: JsonDocument) raises:
    """Assert the upstream `assert_structural_parity`."""
    var a = actual.find(actual.root, "__schema")
    var r = reference.find(reference.root, "__schema")
    assert_equal(
        stringify(actual, actual.find(actual.find(a, "queryType"), "name")),
        stringify(
            reference, reference.find(reference.find(r, "queryType"), "name")
        ),
    )
    for key in ["mutationType", "subscriptionType"]:
        assert_equal(
            stringify(actual, actual.find(a, key)),
            stringify(reference, reference.find(r, key)),
            key,
        )
    var names = _names(reference, r, "types")
    assert_equal(_names(actual, a, "types"), names)
    for ref name in names:
        if name.startswith("__"):
            continue
        var mine = _named(actual, a, "types", name)
        var theirs = _named(reference, r, "types", name)
        assert_equal(
            stringify(actual, actual.find(mine, "kind")),
            stringify(reference, reference.find(theirs, "kind")),
            "kind for " + name,
        )
        for key in ["fields", "inputFields"]:
            _compare_typed(actual, mine, reference, theirs, key, name)
        for key in ["enumValues", "interfaces", "possibleTypes"]:
            assert_equal(
                _names(actual, mine, key),
                _names(reference, theirs, key),
                key + " on " + name,
            )
    for directive in _items(reference, r, "directives"):
        var name = _name(reference, directive)
        var mine = _named(actual, a, "directives", name)
        assert_true(mine != NO_NODE, "missing directive @" + name)
        var locations = List[String]()
        for item in _items(actual, mine, "locations"):
            locations.append(actual.string_value(item))
        for item in _items(reference, directive, "locations"):
            assert_true(reference.string_value(item) in locations, name)
        _compare_typed(actual, mine, reference, directive, "args", "@" + name)


def _swapi() raises -> JsonDocument:
    return parse_json(sdl_to_introspection_json(fixture_text("swapi.graphql")))


def test_swapi_structural_parity_with_legacy_introspection_from_schema() raises:
    var reference = parse_json(fixture_text("swapi-introspection.json"))
    _structural_parity(_swapi(), reference)


def test_swapi_introspection_json_round_trips_through_sdl_to_valid_schema() raises:
    assert_true(_validated_sdl(_swapi()).find("type Root {") >= 0)


def test_swapi_reference_introspection_json_round_trips_through_sdl_to_valid_schema() raises:
    var reference = parse_json(fixture_text("swapi-introspection.json"))
    assert_true(_validated_sdl(reference).find("type Root {") >= 0)


def test_format_json_returns_introspection_object() raises:
    var result = _swapi()
    var schema = result.find(result.root, "__schema")
    assert_equal(result.kind(schema), JsonKind.OBJECT)
    assert_equal(result.find(result.root, "data"), NO_NODE)
    assert_equal(result.find(result.root, "errors"), NO_NODE)


def test_format_json_envelope_exposes_schema_under_data() raises:
    var text = sdl_to_introspection_json(fixture_text("swapi.graphql"))
    var envelope = parse_json(success_json('"introspection_response":' + text))
    var data = envelope.find(envelope.root, "data")
    var response = envelope.find(data, "introspection_response")
    var result = parse_json(text)
    assert_equal(
        stringify(envelope, envelope.find(response, "__schema")),
        stringify(result, result.find(result.root, "__schema")),
    )
    assert_false(envelope.find(data, "success") == NO_NODE)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

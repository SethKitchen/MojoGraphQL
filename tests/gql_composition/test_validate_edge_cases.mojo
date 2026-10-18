# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Edge cases of `gql_composition.validate`, `state_visitor` and `helpers`.

Upstream has no test file for these cases. The expected errors are those of
Hive Federation Composition v0.27.0 `validate` in Node.js on the same
subgraphs, and the expected ids are the `join__Graph` values of its
`composeServices`. The `@cacheTag` case is a feature of this port that Hive
v0.27.0 does not have.
"""

from _harness import check, sg
from gql_composition.validate import Subgraph, constant_case, id_less
from std.testing import TestSuite, assert_equal, assert_false, assert_true


comptime _V23 = (
    'extend schema @link(url: "https://specs.apollo.dev/federation/v2.3",'
    ' import: ["@key", "@external", "@provides", "@interfaceObject",'
    ' "@composeDirective"])\n'
)


def _one(sdl: String, expected: List[String]) raises:
    check([sg("a", sdl)], expected)


def test_constant_case() raises:
    assert_equal(constant_case("é"), "_")
    assert_equal(constant_case("a😀b"), "A__B")
    assert_equal(constant_case("XMLHttp"), "XML_HTTP")
    assert_equal(constant_case("ab"), "AB")
    assert_equal(constant_case("a-b"), "A_B")
    assert_equal(constant_case("1a"), "1A")
    assert_equal(constant_case("v2Users"), "V2_USERS")
    assert_equal(constant_case("aB"), "A_B")
    assert_equal(constant_case(""), "")


def test_no_subgraphs() raises:
    check(
        List[Subgraph](),
        [
            (
                "[NO_QUERIES] No queries found in any subgraph: a supergraph"
                " must have a query root type."
            ),
        ],
    )


def test_id_less() raises:
    assert_true(id_less("A", "AB"))
    assert_false(id_less("AB", "A"))
    assert_true(id_less("A_B", "AB"))
    assert_true(id_less("_1A_", "A"))
    assert_false(id_less("A", "A"))


def _named(names: List[String]) raises -> List[Subgraph]:
    var out = List[Subgraph]()
    for index in range(len(names)):
        out.append(
            sg(names[index], "type Query { f" + String(index) + ": Int }\n")
        )
    return out^


def test_subgraph_ids() raises:
    check(
        _named(
            [
                "é",
                "a😀b",
                "XMLHttp",
                "ab",
                "a",
                "1a",
                "x",
                "a-b",
                "a_b",
                "a.b",
            ]
        ),
        [],
    )
    check(_named(["", "q"]), [])


def test_duplicate_subgraph_names() raises:
    check(_named(["a", "a"]), ["THROWS A subgraph named a already exists"])


def _version(version: String, expected: List[String]) raises:
    _one(
        'extend schema @link(url: "https://specs.apollo.dev/federation/v2.3")'
        + ' @link(url: "https://example.com/foo/'
        + version
        + '")\ntype Query { a: Int }\n',
        expected,
    )


def test_link_versions() raises:
    for version in ["V1.0", "v123", "v12x"]:
        _version(
            version,
            [
                "[INVALID_LINK_IDENTIFIER] [a] Expected a version string (of"
                + " the form v1.2), got "
                + version
            ],
        )
    _version("x1.0", [])


def test_interface_object_twice() raises:
    _one(
        _V23
        + 'type Query @interfaceObject @key(fields: "id") { id: ID! }\n'
        + "type Query { b: Int }\n",
        [
            '[INVALID_GRAPHQL] [a] There can be only one type named "Query".',
            (
                "[INVALID_GRAPHQL] [a] Query root type must be Object type, it"
                " cannot be Query."
            ),
        ],
    )
    _one(
        _V23
        + "type Query { a: Int }\ninterface I { x: Int }\n"
        + 'type T @interfaceObject @key(fields: "id") { id: ID! }\n'
        + "type T implements I { x: Int }\n",
        ['[INVALID_GRAPHQL] [a] There can be only one type named "T".'],
    )
    _one(
        _V23
        + "type Query { a: Int }\ninterface I { x: Int }\n"
        + 'type T @interfaceObject @key(fields: "id") { id: ID! }\n'
        + "extend type T implements I { x: Int }\n",
        [
            (
                '[INTERFACE_OBJECT_USAGE_ERROR] Type "T" is declared with'
                " @interfaceObject in all the subgraphs in which is is defined"
            ),
        ],
    )
    _one(
        _V23
        + "type Query { a: Int }\n"
        + '"desc" type T @interfaceObject @key(fields: "id") { id: ID! }\n'
        + "type T { b: Int }\n",
        ['[INVALID_GRAPHQL] [a] There can be only one type named "T".'],
    )


def test_scalars_and_enums() raises:
    _one("scalar String\ntype Query { a: String }\n", [])
    _one(
        (
            "scalar S\nextend scalar S @specifiedBy(url:"
            ' "https://example.com")\ntype Query { a: S }\n'
        ),
        [],
    )
    _one("scalar S @specifiedBy\ntype Query { a: S }\n", [])
    _one("scalar S @specifiedBy(url: 1)\ntype Query { a: S }\n", [])
    _one(
        (
            'enum E { A }\nextend enum E { B @deprecated "d" C }\ntype Query {'
            " a: E }\n"
        ),
        [],
    )
    _one(
        "enum E @deprecated { A }\ntype Query { a: E }\n",
        [
            (
                '[INVALID_GRAPHQL] [a] Directive "@deprecated" may not be used'
                " on ENUM."
            ),
        ],
    )


def test_fed_v1_root_extensions() raises:
    var sdl = String(
        "extend type Mutation { m: Int }\nextend type Subscription { s: Int }\n"
    )
    check(
        [
            sg("a", "type Query { a: Int }\n" + sdl),
            sg("b", "type Query { b: Int }\n" + sdl),
        ],
        [
            (
                "[INVALID_FIELD_SHARING] Fields on root level subscription"
                " object cannot be marked as shareable"
            ),
        ],
    )


def _one_of(definition: String, expected: List[String]) raises:
    _one(
        definition + "input I @oneOf { a: Int }\ntype Query { a(i: I): Int }\n",
        expected,
    )


def test_one_of_definitions() raises:
    _one_of("scalar oneOf\n", [])
    _one_of("directive @oneOf on INPUT_OBJECT | OBJECT\n", [])
    _one_of(
        "directive @oneOf on OBJECT\n",
        [
            (
                '[INVALID_GRAPHQL] [a] Directive "@oneOf" may not be used on'
                " INPUT_OBJECT."
            ),
        ],
    )
    _one_of("directive @oneOf repeatable on INPUT_OBJECT\n", [])
    _one_of("directive @oneOf(x: Int) on INPUT_OBJECT\n", [])
    _one_of("directive @oneOf on INPUT_OBJECT\n", [])


def test_composed_directives_on_extensions() raises:
    _one(
        String(_V23).replace(
            "])\n",
            '])  @link(url: "https://myspecs.dev/my/v1.0", import: ["@my"])'
            + ' @composeDirective(name: "@my")\n',
        )
        + "directive @my on OBJECT | ENUM | SCALAR | ENUM_VALUE\n"
        + "type Query { a: Int }\n"
        + 'type T @interfaceObject @key(fields: "id") { id: ID! }\n'
        + "type T @my { b: Int }\nenum E { A }\n"
        + "extend enum E @my { B @my }\nscalar S\nextend scalar S @my\n"
        + "type U { e: E s: S }\n",
        ['[INVALID_GRAPHQL] [a] There can be only one type named "T".'],
    )
    _one('enum E { A }\nextend enum E { "d" B }\ntype Query { a: E }\n', [])


def test_key_fragments() raises:
    for fields in ["id ...F", "id ... { id }", "id ... on Unknown { id }"]:
        _one(
            _V23
            + 'type Query { t: T }\ntype T @key(fields: "'
            + fields
            + '") { id: ID! }\n',
            [],
        )
    _one(
        _V23
        + 'type Query { t: T }\ntype T @key(fields: "o") { id: ID! o: O }\n'
        + "type O { a: Int }\n",
        [],
    )


def test_provides_key_and_union_fields() raises:
    _one(
        _V23
        + 'type Query { t: T @provides(fields: "x") }\n'
        + 'type T @key(fields: "nope") { id: ID! x: Int @external }\n',
        [
            (
                '[KEY_INVALID_FIELDS] [a] On type "T", for @key(fields:'
                ' "nope"): Cannot query field "nope" on type "T" (the field'
                " should either be added to this subgraph or, if it should not"
                " be resolved by this subgraph, you need to add it to this"
                " subgraph with @external)."
            ),
        ],
    )
    var provides = String(
        'type Query { t: T @provides(fields: "u { __typename }") }\n'
        'type T @key(fields: "id") { id: ID! u: U @external }\n'
    )
    _one(
        _V23 + provides + "union U\n",
        [
            (
                "[INVALID_GRAPHQL] [a] Union type U must define one or more"
                " member types."
            ),
        ],
    )
    _one(
        _V23 + provides + "scalar S\nunion U = S\n",
        [
            (
                "[INVALID_GRAPHQL] [a] Union type U can only include Object"
                " types, it cannot include S."
            ),
        ],
    )


def _key_definition(resolvable: String, expected: List[String]) raises:
    _one(
        'extend schema @link(url: "https://specs.apollo.dev/federation/v2.3",'
        + ' import: ["@key"])\ndirective @key(fields: FieldSet!, resolvable: '
        + resolvable
        + ") repeatable on OBJECT | INTERFACE\nscalar FieldSet\n"
        + 'type Query { t: T }\ntype T @key(fields: "id") { id: ID! }\n',
        expected,
    )


def test_key_definition_defaults() raises:
    comptime prefix = (
        '[DIRECTIVE_DEFINITION_INVALID] [a] Invalid definition for directive "'
        + '@key": argument "resolvable" should have default value true but'
        + " found default value "
    )
    comptime twice = (
        '[INVALID_GRAPHQL] [a] There can be only one directive named "@key".'
    )
    _key_definition("String", [prefix + "null", twice])
    _key_definition("Boolean = false", [prefix + "false", twice])
    _key_definition("Boolean = 1", ["THROWS Expected a Boolean"])


def test_cache_tag_definition() raises:
    _one(
        (
            "extend schema @link(url:"
            ' "https://specs.apollo.dev/federation/v2.12", import:'
            ' ["@cacheTag"])\ndirective @cacheTag(format: String!) repeatable'
            " on FIELD_DEFINITION | OBJECT\ntype Query { a: Int }\n"
        ),
        [
            (
                "[INVALID_GRAPHQL] [a] There can be only one directive named"
                ' "@cacheTag".'
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the federation `v2.14` and `v2.15` composition checks.

Upstream has no test file for this. The rules are the public Apollo
GraphOS page "Federation versions". Hive Federation Composition v0.27.0
does not have them. Below `v2.14` and `v2.15`, the expected errors are
those of Hive v0.27.0 `composeServices` in Node.js.
"""

from gql_composition.later_versions import (
    GraphFacts,
    check_version_2_14_and_2_15,
)
from gql_composition.compose import compose_subgraphs
from gql_composition.error_code import ErrorCode
from gql_composition.validate import Subgraph
from _harness import check, sg
from std.testing import TestSuite, assert_equal, assert_true


def _fed2(body: String) -> String:
    """Return a federation 2.3 subgraph that can use `@interfaceObject`."""
    return (
        "extend schema @link(url:"
        ' "https://specs.apollo.dev/federation/v2.3", import: ["@key",'
        ' "@interfaceObject"])\n'
        + body
    )


def _fed_at(version: String, body: String) -> String:
    """Return a subgraph at a federation version that can use
    `@interfaceObject`."""
    return (
        'extend schema @link(url: "https://specs.apollo.dev/federation/'
        + version
        + '", import: ["@key", "@interfaceObject"])\n'
        + body
    )


def test_an_empty_state_list_has_no_queries() raises:
    # Hive `composeServices([])` reports `NO_QUERIES` only.
    var facts = List[GraphFacts]()
    var errors = check_version_2_14_and_2_15(facts)
    assert_equal(len(errors), 1)
    assert_true(errors[0].code == ErrorCode.NO_QUERIES)


def _key_on_an_interface_object(version: String) raises -> List[Subgraph]:
    """Return a Federation 1 `@key` interface and two `@interfaceObject`
    types with the same name, at one federation version."""
    return [
        sg(
            "legacy",
            (
                "type Query { product: Product }\n"
                'interface Product @key(fields: "id") { id: ID! }\n'
                'interface Local @key(fields: "id") { id: ID! }\n'
            ),
        ),
        sg(
            "a",
            _fed_at(
                version,
                (
                    "type Query { product: Product }\n"
                    'type Product @key(fields: "id") @interfaceObject'
                    " { id: ID! }\n"
                ),
            ),
        ),
        sg(
            "b",
            _fed_at(
                version,
                (
                    "type Query { product: Product }\n"
                    'type Product @key(fields: "id") @interfaceObject'
                    " { id: ID! name: String }\n"
                ),
            ),
        ),
    ]


def test_before_2_14_a_federation_1_key_follows_hive() raises:
    # Hive v0.27.0 reports only the sharing error at v2.3.
    check(
        _key_on_an_interface_object("v2.3"),
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.product" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "a", "b" and "legacy" and defined as non-shareable'
                ' in subgraphs "a" and "b"'
            ),
        ],
    )


def test_federation_1_key_on_an_interface_object_name() raises:
    check(
        _key_on_an_interface_object("v2.14"),
        [
            (
                "[INTERFACE_OBJECT_USAGE_ERROR] [legacy] Federation 1 subgraph"
                ' "legacy" defines @key on interface "Product", and subgraph'
                ' "a" defines @interfaceObject on "Product".'
            ),
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.product" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "a", "b" and "legacy" and defined as non-shareable'
                ' in subgraphs "a" and "b"'
            ),
        ],
    )


def test_federation_1_can_share_a_graph_with_another_interface_object() raises:
    # No Federation 1 conflict. Hive v0.27.0 reports only that no subgraph
    # defines the `Product` interface.
    check(
        [
            sg(
                "legacy",
                (
                    "type Query { user: User }\n"
                    'type User @key(fields: "id") { id: ID! }\n'
                ),
            ),
            sg(
                "products",
                _fed2(
                    "type Query { product: Product }\n"
                    'type Product @key(fields: "id") @interfaceObject'
                    " { id: ID! }\n"
                ),
            ),
        ],
        [
            (
                '[INTERFACE_OBJECT_USAGE_ERROR] Type "Product" is declared'
                " with @interfaceObject in all the subgraphs in which is is"
                " defined"
            ),
        ],
    )


def test_federation_1_interface_without_key_can_share_the_name() raises:
    check(
        [
            sg(
                "legacy",
                (
                    "type Query { product: Product }\n"
                    "interface Product { id: ID! }\n"
                    'type Book implements Product @key(fields: "id")'
                    " { id: ID! title: String }\n"
                ),
            ),
            sg(
                "products",
                _fed2(
                    "type Query { product: Product }\n"
                    'type Product @key(fields: "id") @interfaceObject'
                    " { id: ID! }\n"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.product" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "legacy" and "products" and defined as'
                ' non-shareable in subgraph "products"'
            ),
        ],
    )


def test_an_interface_cannot_implement_an_interface_object() raises:
    check(
        [
            sg(
                "products",
                _fed_at(
                    "v2.15",
                    (
                        "type Query { product: Product }\n"
                        'type Product @key(fields: "id") @interfaceObject'
                        " { id: ID! }\n"
                    ),
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.15", import:'
                    ' ["@key"])\n'
                    "type Query { review: Special }\n"
                    "interface Other { id: ID! }\n"
                    "interface Product { id: ID! }\n"
                    "interface Special implements Other & Product { id: ID! }\n"
                    'type Book implements Product @key(fields: "id")'
                    " { id: ID! }\n"
                ),
            ),
        ],
        [
            '[INTERFACE_OBJECT_USAGE_ERROR] [reviews] Interface "Special"'
            ' cannot implement @interfaceObject type "Product" from subgraph'
            ' "products".'
        ],
    )


def test_a_subgraph_error_hides_the_later_check() raises:
    check(
        [
            sg(
                "products",
                _fed2(
                    "type Query { product: Product }\n"
                    'type Product @key(fields: "id") @interfaceObject'
                    " { id: ID! }\n"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n'
                    "type Query { a: Int }\n"
                    "type Query { b: Int }\n"
                    "interface Product { id: ID! }\n"
                    "interface Special implements Product { id: ID! }\n"
                ),
            ),
        ],
        [
            "[INVALID_GRAPHQL] [reviews] There can be only one type named"
            ' "Query".'
        ],
    )


def test_a_custom_spec_on_another_domain_is_valid() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.15", import:'
                    ' ["@key"]) @link(url: "https://example.com/other/v1.0")\n'
                    "type Query { a: Int }\n"
                ),
            )
        ],
        [],
    )


def test_a_custom_spec_cannot_use_the_apollo_domain() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.15", import:'
                    ' ["@key"]) @link(url:'
                    ' "https://specs.apollo.dev/other/v1.0")\n'
                    "type Query { a: Int }\n"
                ),
            )
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Custom specification"
            ' "https://specs.apollo.dev/other" cannot use the'
            " https://specs.apollo.dev domain."
        ],
    )


def _apollo_domain_link(federation: String, url: String) -> String:
    """Return a subgraph with a federation link and one more link."""
    return (
        'extend schema @link(url: "https://specs.apollo.dev/federation/'
        + federation
        + '", import: ["@key"]) @link(url: "'
        + url
        + '")\ntype Query { a: Int }\n'
    )


def test_before_2_15_a_custom_spec_on_the_apollo_domain_is_valid() raises:
    # Hive v0.27.0 composes the same subgraph at v2.9 with no errors.
    var other = String("https://specs.apollo.dev/other/v1.0")
    check([sg("a", _apollo_domain_link("v2.9", other))], [])
    check([sg("a", _apollo_domain_link("v2.14", other))], [])


def test_an_apollo_spec_can_use_the_apollo_domain() raises:
    var cost = String("https://specs.apollo.dev/cost/v0.1")
    check([sg("a", _apollo_domain_link("v2.15", cost))], [])


def test_a_link_without_a_feature_name_is_not_a_custom_spec() raises:
    var bare = String("https://specs.apollo.dev/v1.0")
    check([sg("a", _apollo_domain_link("v2.15", bare))], [])


def _fed(imports: String) -> String:
    """Return a federation 2.9 schema that imports the given names."""
    return (
        "extend schema @link(url:"
        ' "https://specs.apollo.dev/federation/v2.9", import: ['
        + imports
        + "])\ntype Query { a: Int }\n"
    )


def test_one_query_root_is_enough() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\ntype User @key(fields: "id") { id: ID! }\n'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\ntype Query { user: User }\n'
                    'type User @key(fields: "id") { id: ID! }\n'
                ),
            ),
        ],
        [],
    )


def test_matching_cost_import_names_are_valid() raises:
    check(
        [
            sg("a", _fed('"@key", "@cost", "@listSize"')),
            sg("b", _fed('"@key", "@cost", "@listSize"')),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.a" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "a" and "b" and defined as non-shareable in all of'
                " them"
            ),
        ],
    )


def test_a_key_alias_does_not_mismatch() raises:
    check(
        [
            sg("a", _fed('"@key", "@cost"')),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' [{name: "@key", as: "@id"}, "@cost"])\n'
                    "type Query { a: Int }\n"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.a" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "a" and "b" and defined as non-shareable in all of'
                " them"
            ),
        ],
    )


def test_cost_import_names_must_match() raises:
    check(
        [
            sg("a", _fed('"@key", {name: "@cost", as: "@price"}')),
            sg("b", _fed('"@key", "@cost"')),
        ],
        [
            (
                '[LINK_IMPORT_NAME_MISMATCH] The import name "@cost" is'
                " imported with mismatched name between subgraphs: it is"
                ' imported as  "@price" in subgraph "a" and  "@cost" in'
                ' subgraph "b"'
            ),
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.a" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "a" and "b" and defined as non-shareable in all of'
                " them"
            ),
        ],
    )


def test_list_size_and_cost_mismatches_keep_import_order() raises:
    check(
        [
            sg(
                "a",
                _fed(
                    '"@key", {name: "@listSize", as: "@size"}, {name:'
                    ' "@cost", as: "@weight"}'
                ),
            ),
            sg("b", _fed('"@key", "@cost", "@listSize"')),
        ],
        [
            (
                '[LINK_IMPORT_NAME_MISMATCH] The import name "@listSize" is'
                " imported with mismatched name between subgraphs: it is"
                ' imported as  "@size" in subgraph "a" and  "@listSize" in'
                ' subgraph "b"'
            ),
            (
                '[LINK_IMPORT_NAME_MISMATCH] The import name "@cost" is'
                " imported with mismatched name between subgraphs: it is"
                ' imported as  "@weight" in subgraph "a" and  "@cost" in'
                ' subgraph "b"'
            ),
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.a" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "a" and "b" and defined as non-shareable in all of'
                " them"
            ),
        ],
    )


def test_three_cost_aliases() raises:
    check(
        [
            sg("a", _fed('"@key", {name: "@cost", as: "@price"}')),
            sg("b", _fed('"@key", {name: "@cost", as: "@fee"}')),
            sg("c", _fed('"@key", "@cost"')),
        ],
        [
            (
                '[LINK_IMPORT_NAME_MISMATCH] The import name "@cost" is'
                " imported with mismatched name between subgraphs: it is"
                ' imported as  "@price" in subgraph "a",  "@fee" in subgraph'
                ' "b", and  "@cost" in subgraph "c"'
            ),
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.a" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "a", "b" and "c" and defined as non-shareable in'
                " all of them"
            ),
        ],
    )


def test_one_alias_shared_by_two_subgraphs() raises:
    check(
        [
            sg("a", _fed('"@key", {name: "@cost", as: "@price"}')),
            sg("b", _fed('"@key", {name: "@cost", as: "@price"}')),
            sg("c", _fed('"@key", "@cost"')),
        ],
        [
            (
                '[LINK_IMPORT_NAME_MISMATCH] The import name "@cost" is'
                " imported with mismatched name between subgraphs: it is"
                ' imported as  "@price" in subgraphs "a" and "b" and  "@cost"'
                ' in subgraph "c"'
            ),
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.a" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "a", "b" and "c" and defined as non-shareable in'
                " all of them"
            ),
        ],
    )


def test_one_alias_shared_by_three_subgraphs() raises:
    check(
        [
            sg("a", _fed('"@key", {name: "@cost", as: "@price"}')),
            sg("b", _fed('"@key", {name: "@cost", as: "@price"}')),
            sg("c", _fed('"@key", {name: "@cost", as: "@price"}')),
            sg("d", _fed('"@key", "@cost"')),
        ],
        [
            (
                '[LINK_IMPORT_NAME_MISMATCH] The import name "@cost" is'
                " imported with mismatched name between subgraphs: it is"
                ' imported as  "@price" in subgraphs "a", "b" and "c" and '
                ' "@cost" in subgraph "d"'
            ),
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.a" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "a", "b", "c" and "d" and defined as non-shareable'
                " in all of them"
            ),
        ],
    )


def test_at_2_14_a_federation_1_interface_without_key_is_valid() raises:
    # At `v2.3` Hive reports only a `SATISFIABILITY_ERROR`, which
    # `compose_subgraphs` does not run. The `v2.14` check needs a `@key`.
    check(
        [
            sg(
                "legacy",
                (
                    "type Query { product: Product }\n"
                    "interface Product { id: ID! }\n"
                    'type Book implements Product @key(fields: "id")'
                    " { id: ID! title: String }\n"
                ),
            ),
            sg(
                "products",
                _fed_at(
                    "v2.14",
                    (
                        "type Query { other: Product }\n"
                        'type Product @key(fields: "id") @interfaceObject'
                        " { id: ID! }\n"
                    ),
                ),
            ),
        ],
        [],
    )


def test_the_printer_keeps_an_empty_argument_description() raises:
    # The expected block is the supergraph of Hive v0.27.0 `composeServices`.
    var result = compose_subgraphs(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { a("" x: Int): Int }\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    var block = (
        'type Query @join__type(graph: A) {\n  a("""\n  \n  """\n  x: Int):'
        " Int\n}"
    )
    if block not in result.supergraph_sdl:
        print(result.supergraph_sdl)
    assert_true(block in result.supergraph_sdl)


def test_the_printer_escapes_tags_and_reasons() raises:
    # The expected block is the supergraph of Hive v0.27.0 `composeServices`.
    var result = compose_subgraphs(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@tag"])\ntype Query {\n  a("d" x: Int'
                    ' @tag(name: "q\\\\r\\tt\\rz\\u000bw\\u001fv")): Int'
                    ' @deprecated(reason: "x\\\\y\\tz\\rw\\u000c\\u0001")\n}\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    var block = (
        'type Query @join__type(graph: A) {\n  a("""\n  d\n  """\n  x: Int'
        ' @tag(name: "q\\\\r\\tt\\rz\\u000bw\\u001fv")): Int'
        ' @deprecated(reason: "x\\\\y\\tz\\rw\\f\\u0001")\n}'
    )
    if block not in result.supergraph_sdl:
        print(result.supergraph_sdl)
    assert_true(block in result.supergraph_sdl)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

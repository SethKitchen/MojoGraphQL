# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Entity representation tests.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/executor/projection/request.rs`. Upstream compares pretty
`insta` snapshots; these tests compare the same JSON on one line.
"""

from gql_json.parser import parse as parse_json
from gql_router.entity_keys import EntityKeys, KeysByType
from gql_router.exec_requires import project_requires, requires_hash
from gql_router.normalize import selection_set_from_text
from gql_router.planner import Planner
from gql_router.schema_metadata import PossibleTypes
from gql_router.store import Store
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime NONE_TEXT = "<none>"
"""What `_project` returns when nothing is written."""


def _project(
    requires: String,
    entity: String,
    keys: KeysByType = KeysByType(),
    has_keys: Bool = False,
) raises -> String:
    var store = Store()
    var set = selection_set_from_text(store, "{ " + requires + " }")
    var document = parse_json(entity)
    var buffer = List[UInt8]()
    var projected = project_requires(
        store,
        PossibleTypes(),
        set,
        document,
        document.root,
        buffer,
        True,
        "",
        False,
        False,
        keys,
        has_keys,
    )
    if not projected:
        return NONE_TEXT
    return String(unsafe_from_utf8=buffer^)


def _keys(type_name: String, var fields: List[String]) -> KeysByType:
    var keys = KeysByType()
    keys.add(type_name, fields^)
    return keys^


def test_project_requires_preserves_aliases_at_each_depth() raises:
    assert_equal(
        _project(
            "key: id nested { renamed: value } ... on Product { code: upc }",
            '{"__typename":"Product","id":"original","key":"fallback",'
            + '"nested":{"renamed":2},"upc":"123"}',
        ),
        '{"__typename":"Product","key":"original","nested":{"renamed":2},'
        + '"code":"123"}',
    )


def test_project_requires_variants() raises:
    assert_equal(
        _project(
            "contactOptions id",
            '{"__typename":"Ad","contactOptions":null,"id":"1"}',
        ),
        '{"__typename":"Ad","contactOptions":null,"id":"1"}',
    )
    assert_equal(
        _project(
            "id contactOptions",
            '{"__typename":"Ad","contactOptions":null,"id":"1"}',
        ),
        '{"__typename":"Ad","id":"1","contactOptions":null}',
    )
    assert_equal(
        _project("contactOptions id", '{"__typename":"Ad","id":"1"}'),
        '{"__typename":"Ad","id":"1"}',
    )
    assert_equal(
        _project(
            "branch { contactOptions { email } } id",
            '{"__typename":"Ad","branch":{"contactOptions":{}},"id":"1"}',
        ),
        '{"__typename":"Ad","id":"1"}',
    )
    assert_equal(
        _project(
            "branch { contactOptions { email user { id name } } } id",
            '{"__typename":"Ad","branch":{"__typename":"Branch",'
            + '"contactOptions":null},"id":"1"}',
        ),
        '{"__typename":"Ad","branch":{"__typename":"Branch",'
        + '"contactOptions":null},"id":"1"}',
    )
    assert_equal(_project("contactOptions", "{}"), NONE_TEXT)


def test_project_requires_typename_key() raises:
    assert_equal(
        _project("__typename", '{"__typename":"CatalogEntry","sku":"S"}'),
        '{"__typename":"CatalogEntry"}',
    )
    assert_equal(
        _project("__typename id", '{"__typename":"CatalogEntry","id":"1"}'),
        '{"__typename":"CatalogEntry","id":"1"}',
    )
    assert_equal(
        _project("id __typename", '{"__typename":"CatalogEntry","id":"1"}'),
        '{"__typename":"CatalogEntry","id":"1"}',
    )


def test_project_requires_object_of_none_of_the_fragment_types() raises:
    var requires = String(
        "... on Listing { __typename pet { __typename ... on Dog { tricks }"
        + " ... on Cat { whiskers } } id }"
    )
    assert_equal(
        _project(
            requires,
            '{"__typename":"Listing","id":"l3","pet":{"__typename":"Bird",'
            + '"id":"b1"}}',
        ),
        '{"__typename":"Listing","pet":{"__typename":"Bird"},"id":"l3"}',
    )
    assert_equal(
        _project(
            "... on Shelter { __typename pets { __typename ... on Dog { tricks"
            + " } ... on Cat { whiskers } } id }",
            '{"__typename":"Shelter","id":"s1","pets":[{"__typename":"Cat",'
            + '"id":"c1","whiskers":12},{"__typename":"Bird","id":"b1"},'
            + '{"__typename":"Dog","id":"d1","tricks":3}]}',
        ),
        '{"__typename":"Shelter","pets":[{"__typename":"Cat","whiskers":12},'
        + '{"__typename":"Bird"},{"__typename":"Dog","tricks":3}],"id":"s1"}',
    )
    assert_equal(
        _project(
            requires,
            '{"__typename":"Listing","id":"l1","pet":{"__typename":"Cat",'
            + '"id":"c1"}}',
        ),
        '{"__typename":"Listing","id":"l1"}',
    )
    assert_equal(
        _project(
            "... on Book { __typename id }", '{"__typename":"Book","upc":"b3"}'
        ),
        NONE_TEXT,
    )


def test_project_requires_object_of_none_of_the_fragment_types_without_typename() raises:
    assert_equal(
        _project(
            "... on Listing { __typename pet { ... on Dog { tricks } ... on Cat"
            + " { whiskers } } id }",
            '{"__typename":"Listing","id":"l3","pet":{"__typename":"Bird",'
            + '"id":"b1"}}',
        ),
        '{"__typename":"Listing","pet":{"__typename":"Bird"},"id":"l3"}',
    )
    assert_equal(
        _project(
            "... on Shelter { __typename pets { ... on Dog { tricks } ... on"
            + " Cat { whiskers } } id }",
            '{"__typename":"Shelter","id":"s1","pets":[{"__typename":"Cat",'
            + '"id":"c1","whiskers":12},{"__typename":"Bird","id":"b1"},'
            + '{"__typename":"Dog","id":"d1","tricks":3}]}',
        ),
        '{"__typename":"Shelter","pets":[{"__typename":"Cat","whiskers":12},'
        + '{"__typename":"Bird"},{"__typename":"Dog","tricks":3}],"id":"s1"}',
    )
    assert_equal(
        _project(
            "... on Cat { __typename id }", '{"__typename":"Dog","id":"d1"}'
        ),
        NONE_TEXT,
    )


def test_project_requires_missing_requires_field_is_null() raises:
    assert_equal(
        _project(
            "... on FavoritesPage { __typename petCount }",
            '{"__typename":"FavoritesPage"}',
            _keys("FavoritesPage", List[String]()),
            True,
        ),
        '{"__typename":"FavoritesPage","petCount":null}',
    )
    assert_equal(
        _project(
            "... on FavoritesPage { __typename id petCount }",
            '{"__typename":"FavoritesPage","id":"p1"}',
            _keys("FavoritesPage", ["id"]),
            True,
        ),
        '{"__typename":"FavoritesPage","id":"p1","petCount":null}',
    )


comptime ALTERNATIVE_KEYS = """
enum join__Graph {
  CONTENT @join__graph(name: "content", url: "")
  SEARCH @join__graph(name: "search", url: "")
}
type Query @join__type(graph: CONTENT) {
  favoritesPage: FavoritesPage @join__field(graph: CONTENT)
}
type FavoritesPage
  @join__type(graph: CONTENT, key: "id")
  @join__type(graph: SEARCH, key: "id")
  @join__type(graph: SEARCH, key: "petCount") {
  id: ID!
  petCount: Int @join__field(graph: CONTENT) @join__field(graph: SEARCH, external: true)
  placeholder: String @join__field(graph: SEARCH, requires: "petCount")
}
"""
"""The supergraph of `project_requires_missing_alternative_key_field_is_null`."""


def test_project_requires_missing_alternative_key_field_is_null() raises:
    var planner = Planner(ALTERNATIVE_KEYS)
    var entity_keys = EntityKeys.new(planner.store, planner.state)
    var keys = entity_keys.of_subgraph("search").value().copy()
    assert_equal(len(keys.get("FavoritesPage").value()), 2)
    assert_false(entity_keys.of_subgraph("missing"))
    assert_equal(
        _project(
            "... on FavoritesPage { __typename id petCount }",
            '{"__typename":"FavoritesPage","id":"p1"}',
            keys,
            True,
        ),
        '{"__typename":"FavoritesPage","id":"p1","petCount":null}',
    )


def test_project_requires_missing_key_field_leaves_entity_out() raises:
    assert_equal(
        _project(
            "... on Book { __typename id }",
            '{"__typename":"Book","upc":"b3"}',
            _keys("Book", ["id"]),
            True,
        ),
        NONE_TEXT,
    )


def test_project_requires_missing_key_field_leaves_entity_out_with_other_fields() raises:
    var requires = String("... on Product { __typename upc price weight }")
    var keys = _keys("Product", ["upc"])
    assert_equal(
        _project(requires, '{"__typename":"Product"}', keys, True), NONE_TEXT
    )
    assert_equal(
        _project(requires, '{"__typename":"Product","price":899}', keys, True),
        NONE_TEXT,
    )
    assert_equal(
        _project(
            requires,
            '[{"__typename":"Product","upc":"1","price":899,"weight":100},'
            + '{"__typename":"Product","price":899},'
            + '{"__typename":"Product","upc":"2"}]',
            keys,
            True,
        ),
        '[{"__typename":"Product","upc":"1","price":899,"weight":100},'
        + '{"__typename":"Product","upc":"2","price":null,"weight":null}]',
    )


def _hash(requires: String, entity: String) raises -> UInt64:
    var store = Store()
    var set = selection_set_from_text(store, "{ " + requires + " }")
    var document = parse_json(entity)
    return requires_hash(store, PossibleTypes(), set, document, document.root)


def test_requires_hash_ignores_fields_outside_the_selection() raises:
    var requires = String("__typename id ... on User { name } items { id }")
    var base = _hash(
        requires,
        '{"__typename":"User","id":"1","name":"a","extra":1,"items":[{"id":1}]}',
    )
    assert_equal(
        base,
        _hash(
            requires,
            '{"__typename":"User","extra":2,"id":"1","name":"a","items":[{"id":1,"x":2}]}',
        ),
    )
    assert_true(
        base
        != _hash(
            requires,
            '{"__typename":"User","id":"2","name":"a","items":[{"id":1}]}',
        )
    )
    # A fragment of another type, and an object without `__typename`.
    assert_true(
        _hash(requires, '{"__typename":"Admin","id":"1","name":"a"}')
        != _hash(requires, '{"id":"1","name":"a"}')
    )
    assert_equal(_hash("id", '"\\u0041"'), _hash("id", '"A"'))
    assert_true(
        _hash("id", "[true, false, null, 1.5]") != _hash("id", "[true]")
    )


def test_project_requires_edge_values() raises:
    # A null item of a list is left out of the list.
    assert_equal(
        _project("items { id }", '{"items":[{"id":1},null,{"id":2}]}'),
        '{"items":[{"id":1},{"id":2}]}',
    )
    # A leaf with an object value is written whole.
    assert_equal(_project("meta", '{"meta":{"a":[1]}}'), '{"meta":{"a":[1]}}')
    # Without `__typename`, a fragment applies, and known keys do not
    # look the type up.
    assert_equal(
        _project(
            "... on Product { upc }",
            '{"upc":"1"}',
            _keys("Product", ["upc"]),
            True,
        ),
        '{"upc":"1"}',
    )
    # An escaped `__typename` is decoded to find the keys of its type.
    assert_equal(
        _project(
            "__typename upc",
            '{"__typename":"Pro\\u0064uct","upc":"1"}',
            _keys("Product", ["upc"]),
            True,
        ),
        '{"__typename":"Pro\\u0064uct","upc":"1"}',
    )
    # A nested object that writes nothing, after another field, is left
    # out without undoing the parent.
    assert_equal(
        _project("upc nested { id }", '{"upc":"1","nested":{}}'),
        '{"upc":"1"}',
    )


def test_requires_hash_looks_the_type_up_once() raises:
    var requires = String("... on User { id } ... on User { name }")
    assert_equal(
        _hash(requires, '{"__typename":"User","id":"1","name":"a"}'),
        _hash(requires, '{"__typename":"User","name":"a","id":"1"}'),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

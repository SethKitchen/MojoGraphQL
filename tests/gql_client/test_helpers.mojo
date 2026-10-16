# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Apollo Client 4.3.3 `src/cache/inmemory/__tests__/helpers.ts`,
and tests of `gql_client.helpers`.

The one upstream case, "defaultNormalizedCacheFactory should return an
EntityStore", checks a class; here it checks that a cache restored from a
seed extracts the seed. The other cases test the helpers of
`src/utilities` that the cache uses. They have no upstream test file; the
expected values are the Node.js output of Apollo Client 4.3.3, run with
`--conditions=development`, which gives the development messages.
"""

from gql_client.cache import InMemoryCache
from gql_client.helpers import (
    add_typename_to_document,
    check_document,
    field_name_from_store_name,
    get_fragment_query_document,
    get_store_key_name,
    is_added_typename,
    name_prefix_length,
    should_include,
)
from gql_client.values import Member, NO_VALUE, UNDEFINED_VALUE, Values
from gql_language.ast import NO_NODE, Role
from gql_language.printer import print_ast
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)

from _helpers import assert_extract, gql, json


def test_restore_gives_an_entity_store_of_the_seed() raises:
    var cache = InMemoryCache()
    var seed = (
        '{"ROOT_QUERY": {"__typename": "Query", "a": {"__ref": "T:1"}},'
        ' "T:1": {"__typename": "T", "id": 1}}'
    )
    cache.restore(json(seed))
    assert_extract(cache, seed)


def test_field_name_from_store_name() raises:
    assert_equal(field_name_from_store_name('book({"id":1})'), "book")
    assert_equal(field_name_from_store_name("books:abc"), "books")
    assert_equal(field_name_from_store_name("_a1"), "_a1")
    assert_equal(field_name_from_store_name("1abc"), "1abc")
    assert_equal(field_name_from_store_name(""), "")
    assert_equal(name_prefix_length("ab-c"), 2)


def _object(mut values: Values, text: StringSlice) raises -> Int:
    """Add a JSON object to an arena."""
    var document = json(text)
    return values.from_json(document, document.root)


def test_get_store_key_name_with_a_connection_filter() raises:
    var values = Values()
    var args = _object(values, '{"b": 1, "a": 2}')
    var directives = _object(
        values, '{"connection": {"key": "k", "filter": ["b", "c"]}}'
    )
    assert_equal(
        get_store_key_name("f", values, args, directives), 'k({"b":1})'
    )
    var other = _object(values, '{"x": 1}')
    directives = _object(
        values, '{"connection": {"key": "k", "filter": ["c"]}}'
    )
    assert_equal(get_store_key_name("f", values, other, directives), "k")
    directives = _object(values, '{"connection": {"key": "k", "filter": []}}')
    assert_equal(get_store_key_name("f", values, other, directives), "k")
    directives = _object(values, '{"connection": {"key": "k"}}')
    assert_equal(get_store_key_name("f", values, NO_VALUE, directives), "f")


def test_get_store_key_name_with_unknown_directives() raises:
    var values = Values()
    var directives = _object(
        values,
        '{"foo": {}, "bar": {"z": 1, "a": [2]}, "include": {"if": true}}',
    )
    var empty = _object(values, "{}")
    assert_equal(
        get_store_key_name("f", values, empty, directives),
        'f@foo@bar({"a":[2],"z":1})',
    )
    var members = List[Member]()
    members.append(
        Member(Int32(values.names.intern("a")), Int32(UNDEFINED_VALUE))
    )
    var undefined = values.add_object(members)
    assert_equal(get_store_key_name("f", values, undefined, NO_VALUE), "f")


def test_get_fragment_query_document_refuses_operations() raises:
    with assert_raises(
        contains=(
            "Found a query operation named 'Q'. No operations are allowed"
            " when using a fragment as a query. Only fragments are allowed."
        )
    ):
        _ = get_fragment_query_document(gql("query Q { a }"))
    with assert_raises(
        contains=(
            "Found a mutation operation. No operations are allowed when using"
            " a fragment as a query. Only fragments are allowed."
        )
    ):
        _ = get_fragment_query_document(gql("mutation { a }"))
    with assert_raises(
        contains=(
            "Found 2 fragments. `fragmentName` must be provided when there is"
            " not exactly 1 fragment."
        )
    ):
        _ = get_fragment_query_document(
            gql("fragment A on T { a } fragment B on T { b }")
        )
    var named = get_fragment_query_document(
        gql("fragment A on T { a } fragment B on T { b }"), "B"
    )
    assert_true(print_ast(named).endswith("{\n  ...B\n}"))


def _include(text: StringSlice, variables: StringSlice) raises -> Bool:
    """Run `shouldInclude` on the first selection of a query."""
    var document = gql(text)
    var values = Values()
    var vars = _object(values, variables)
    var operation = document.first_child(document.root)
    var selection = document.first_child(
        document.child(operation, Role.SELECTION_SET)
    )
    return should_include(document, selection, values, vars)


def test_should_include_refuses_invalid_directives() raises:
    with assert_raises(
        contains="Incorrect number of arguments for the @skip directive."
    ):
        _ = _include("{ a @skip }", "{}")
    with assert_raises(contains="Invalid argument for the @skip directive."):
        _ = _include("{ a @skip(x: true) }", "{}")
    with assert_raises(
        contains=(
            "Argument for the @skip directive must be a variable or a boolean"
            " value."
        )
    ):
        _ = _include("{ a @skip(if: 1) }", "{}")
    with assert_raises(
        contains="Invalid variable referenced in @skip directive."
    ):
        _ = _include("{ a @skip(if: $v) }", "{}")


def test_should_include_uses_javascript_truth() raises:
    assert_false(_include("{ a @include(if: $v) }", '{"v": 0}'))
    assert_true(_include("{ a @skip(if: $v) @include(if: true) }", '{"v": ""}'))
    assert_false(_include("{ a @skip(if: true) @include(if: $missing) }", "{}"))
    assert_true(_include("{ a @deprecated }", "{}"))


def test_add_typename_to_document() raises:
    var document = add_typename_to_document(
        gql(
            'query { a { b { __x } c @export(as: "y") { d } ... on T { e } } }'
            " fragment F on T { g }"
        )
    )
    assert_equal(
        print_ast(document),
        (
            '{\n  a {\n    b {\n      __x\n    }\n    c @export(as: "y") {\n   '
            "   d\n    }\n    ... on T {\n      e\n      __typename\n    }\n   "
            " __typename\n  }\n}\n\nfragment F on T {\n  g\n  __typename\n}"
        ),
    )
    var operation = document.first_child(document.root)
    var a = document.first_child(document.child(operation, Role.SELECTION_SET))
    assert_false(is_added_typename(document, a))
    var last = document.first_child(document.child(a, Role.SELECTION_SET))
    var current = last
    while current != NO_NODE:
        last = current
        current = document.next_sibling(current)
    assert_true(is_added_typename(document, last))


def test_check_document_refuses_what_the_cache_cannot_use() raises:
    with assert_raises(
        contains=(
            "Schema type definitions not allowed in queries. Found:"
            ' "ObjectTypeDefinition"'
        )
    ):
        check_document(gql("type T { a: Int } query { a }"))
    with assert_raises(
        contains="Ambiguous GraphQL document: contains 2 operations"
    ):
        check_document(gql("query { a } query { b }"))
    with assert_raises(
        contains=(
            "`__typename` is a forbidden field alias name in the selection set"
            ' for field `a.b` in query "Q".'
        )
    ):
        check_document(gql("query Q { a { __typename: b } }"))
    with assert_raises(
        contains=(
            "`__ac_y` is a forbidden field alias name in the selection set for"
            ' field `x.b` in query "(anonymous)".'
        )
    ):
        check_document(gql("query { x: a { __ac_y: b } }"))
    with assert_raises(
        contains=(
            "`__ac_` is a forbidden field alias name in the selection set for"
            ' field `a.b.c` in mutation "M".'
        )
    ):
        check_document(gql("mutation M { a { b { __ac_: c } } }"))
    check_document(gql("query { a { __typename: __typename } }"))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

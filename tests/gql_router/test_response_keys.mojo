# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the response keys of planner fields.

Port of the tests in Hive Router `1a29df9`
`bin/router/src/query_planner/planner/fetch/response_keys.rs`.
"""

from gql_router.normalize import selection_set_from_text
from gql_router.merge_path import MergePath
from gql_router.response_keys import ResponseKeys, place_of
from gql_router.selection_set import set_text
from gql_router.selection_tools import read_as_written
from gql_router.store import Store
from std.testing import TestSuite, assert_equal


def _keys(mut store: Store, client: String) raises -> ResponseKeys:
    return ResponseKeys.from_operation(
        store, selection_set_from_text(store, client)
    )


def test_same_value_keeps_the_name_another_one_gets_an_alias() raises:
    var store = Store()
    var keys = _keys(store, '{ me { price(currency: "GBP") } }')
    var me: List[Int] = [store.sym("me")]
    var gbp = keys.output(
        store, me, selection_set_from_text(store, '{ price(currency: "GBP") }')
    )
    var eur = keys.output(
        store, me, selection_set_from_text(store, '{ price(currency: "EUR") }')
    )
    var eur_read = keys.input(
        store,
        me,
        selection_set_from_text(
            store, '{ ... on Cat { price(currency: "EUR") } }'
        ),
    )
    assert_equal(set_text(store, gbp), '{price(currency: "GBP")}')
    assert_equal(
        set_text(store, eur), '{_internal_qp_alias_0: price(currency: "EUR")}'
    )
    assert_equal(
        set_text(store, eur_read),
        '{...on Cat{price: _internal_qp_alias_0(currency: "EUR")}}',
    )


def test_every_occupant_counts() raises:
    var store = Store()
    var keys = _keys(
        store,
        (
            "{ things { _internal_qp_alias_0: id ... on A {"
            ' price(currency: "GBP") } ... on B { price(currency: "USD") } } }'
        ),
    )
    var things: List[Int] = [store.sym("things")]
    var gbp = keys.output(
        store,
        things,
        selection_set_from_text(store, '{ price(currency: "GBP") }'),
    )
    assert_equal(
        set_text(store, gbp), '{_internal_qp_alias_1: price(currency: "GBP")}'
    )


def test_a_read_turns_back_into_the_write() raises:
    var store = Store()
    var keys = _keys(store, '{ me { price(currency: "GBP") } }')
    var me: List[Int] = [store.sym("me")]
    var written = keys.output(
        store,
        me,
        selection_set_from_text(
            store, '{ ... on Cat { price(currency: "EUR") } }'
        ),
    )
    var read = keys.input(
        store,
        me,
        selection_set_from_text(
            store, '{ ... on Cat { price(currency: "EUR") } }'
        ),
    )
    read_as_written(store, read)
    assert_equal(set_text(store, read), set_text(store, written))


def test_nested_places_follow_the_key() raises:
    var store = Store()
    var keys = _keys(store, '{ me { team(role: "user") { name } } }')
    var me: List[Int] = [store.sym("me")]
    var admin = keys.output(
        store,
        me,
        selection_set_from_text(store, '{ team(role: "admin") { name } }'),
    )
    assert_equal(
        set_text(store, admin),
        '{_internal_qp_alias_0: team(role: "admin"){name}}',
    )
    var nested: List[Int] = [store.sym("me"), store.sym("_internal_qp_alias_0")]
    assert_equal(
        set_text(
            store,
            keys.output(
                store, nested, selection_set_from_text(store, "{ name }")
            ),
        ),
        "{name}",
    )


def test_fragment_spreads_are_copied_as_they_are() raises:
    var store = Store()
    var keys = _keys(store, "{ me { a } ...Client }")
    var me: List[Int] = [store.sym("me")]
    var mapped = keys.output(
        store, me, selection_set_from_text(store, "{ a ...Rest }")
    )
    assert_equal(set_text(store, mapped), "{a ...Rest}")


def test_place_of_an_empty_path_is_the_root() raises:
    assert_equal(len(place_of(MergePath())), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

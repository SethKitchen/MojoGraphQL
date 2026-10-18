# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Query plan tests of `@requires` aliases under interfaces, type
conditions and `@include`.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/query_planner/tests/requires_alias_scopes.rs`. A
`@requires` reads `price(currency: "EUR")` while the client asks for
`price(currency: "GBP")` on the same objects, so one of them gets an
internal alias. The tests check where the plan reads and writes it.

Upstream checks the `shop` operation with the `graphql_tools`
`OverlappingFieldsCanBeMerged` rule. This port has no validation package
in its closure, so `overlapping_fields_errors` checks the same rule for the
types of upstream `SHOP_SCHEMA`.
"""

from _alias_scopes import (
    by_service,
    contains,
    joined,
    key_clashes,
    overlapping_fields_errors,
    plan_fetches,
    root_fetch,
    selections_with_key,
    wrong_price_reads,
)
from _fixtures import (
    requires_alias_entity_calls,
    requires_alias_entity_interface,
    requires_alias_interface_object,
    requires_alias_object_field,
    requires_alias_two_requirements,
)
from std.testing import TestSuite, assert_equal, assert_true


def _all_in(conditions: List[String], within: List[String]) -> Bool:
    """Return True if every condition is in a list."""
    for condition in conditions:
        if not contains(within, condition):
            return False
    return True


def test_requires_alias_is_read_only_where_it_is_fetched() raises:
    var fetches = plan_fetches(
        requires_alias_interface_object.sdl(),
        """
        query($x: Boolean!, $y: Boolean!) {
          things {
            ... on Node @include(if: $x) { price(currency: "GBP") eur }
            ... on Node @include(if: $y) { ... on Cat { eur } }
          }
        }
        """,
    )
    var shop = by_service(fetches, "shop")
    var readers = by_service(fetches, "pricing")
    assert_equal(
        len(readers), 2, "expected a pricing fetch under $x and one under $y"
    )
    # The one under `$x` reads the alias fetched under `$x`, which is right.
    var wrong = List[String]()
    for ref reader in readers:
        assert_true(
            len(reader.price_reads) > 0, "the representation reads a price"
        )
        var key = reader.price_reads[0].key
        # Any `shop` fetch sent whenever the reader is, with the EUR price
        # under that key.
        var fetched_when_sent = False
        for ref fetch in shop:
            if not _all_in(fetch.conditions, reader.conditions):
                continue
            for s in selections_with_key(fetch.operation, key):
                if s.arguments == 'currency: "EUR"' and _all_in(
                    s.includes, reader.conditions
                ):
                    fetched_when_sent = True
        if not fetched_when_sent:
            wrong.append(
                "representations sent under ["
                + joined(reader.conditions, ", ")
                + "] read `"
                + key
                + "`, but `shop` fetches it under other conditions"
            )
    var operations = List[String]()
    for ref fetch in shop:
        operations.append(fetch.operation)
    assert_true(
        len(wrong) == 0,
        joined(wrong, "\n") + "\n" + joined(operations, "\n"),
    )


def test_requires_alias_keeps_shop_operation_valid_across_interface_and_object() raises:
    var queries: List[String] = [
        """
        query($x: Boolean!) {
          things {
            ... on Node @include(if: $x) { price(currency: "GBP") eur }
            ... on Cat { eur }
          }
        }
        """,
        """
        query($x: Boolean!, $y: Boolean!) {
          things {
            ... on Node @include(if: $x) { price(currency: "GBP") eur }
            ... on Node @include(if: $y) { ... on Cat { eur } }
          }
        }
        """,
    ]
    for query in queries:
        var fetches = plan_fetches(requires_alias_interface_object.sdl(), query)
        var shop = root_fetch(fetches, "shop")
        var errors = overlapping_fields_errors(shop.operation)
        assert_true(
            len(errors) == 0,
            "`shop` operation doesn't validate: "
            + joined(errors, "; ")
            + "\n"
            + shop.operation,
        )


def test_requires_alias_reaches_readers_batched_for_many_types() raises:
    var fetches = plan_fetches(
        requires_alias_entity_interface.sdl(),
        """
        {
          things {
            price(currency: "GBP")
            ... on Cat { eur }
            ... on Dog { eur }
          }
        }
        """,
    )
    var shop = root_fetch(fetches, "shop")
    var readers = by_service(fetches, "pricing")
    assert_true(len(readers) > 0, "expected pricing fetches")
    for ref reader in readers:
        for ref entry in reader.price_reads:
            var values = List[String]()
            for s in selections_with_key(shop.operation, entry.key):
                if s.applies_to(entry.type_name):
                    values.append(s.arguments)
            var right = len(values) > 0
            for value in values:
                if value != 'currency: "EUR"':
                    right = False
            assert_true(
                right,
                "`"
                + entry.type_name
                + "` representations read `"
                + entry.key
                + "`, which `shop` fetches as ["
                + joined(values, "; ")
                + "]:\n"
                + shop.operation,
            )


def _assert_no_wrong_reads(sdl: String, queries: List[String]) raises:
    """Plan each query and assert that every `price` reader gets its
    price."""
    for query in queries:
        var wrong = wrong_price_reads(plan_fetches(sdl, query))
        assert_true(len(wrong) == 0, query + "\n" + joined(wrong, "\n"))


def _assert_no_clashes(sdl: String, queries: List[String]) raises:
    """Plan each query and assert that no two fetches write one key at one
    place with different arguments."""
    for query in queries:
        var clashes = key_clashes(plan_fetches(sdl, query))
        assert_true(len(clashes) == 0, query + "\n" + joined(clashes, "\n"))


def test_requires_alias_reaches_readers_inside_type_fragments() raises:
    _assert_no_wrong_reads(
        requires_alias_two_requirements.sdl(),
        [
            '{ things { price(currency: "USD") eur ... on Cat { gbp } } }',
            "{ things { ... on Cat { gbp } eur } }",
            '{ things { ... on Cat { price(currency: "USD") gbp } eur } }',
        ],
    )


def test_requires_alias_names_stay_unique_across_merges() raises:
    _assert_no_wrong_reads(
        requires_alias_two_requirements.sdl(),
        [
            (
                "query($x: Boolean!) { things { ... on Node @include(if: $x)"
                ' { price(currency: "USD") eur ... on Cat { gbp } } } }'
            ),
            (
                "query($x: Boolean!) { things { ... on Node @include(if: $x)"
                ' { price(currency: "USD") ... on Cat { gbp } eur } } }'
            ),
            (
                "query($x: Boolean!) { things { ... on Node @include(if: $x)"
                ' { ... on Cat { gbp } price(currency: "USD") eur } } }'
            ),
        ],
    )


def test_requires_alias_keeps_response_keys_apart_across_fetches() raises:
    _assert_no_clashes(
        requires_alias_object_field.sdl(),
        [
            # Both in one fetch, the admin team is aliased. This one is right.
            '{ me { team(role: "user") { name } label } }',
            (
                'query($x: Boolean!) { me { team(role: "user") { name } label'
                " @include(if: $x) } }"
            ),
            (
                'query($x: Boolean!) { me { team(role: "user") @include(if:'
                " $x) { name } label } }"
            ),
            """
        query($x: Boolean!, $y: Boolean!) {
          me {
            ... on User @include(if: $x) { team(role: "user") { name } label }
            ... on User @include(if: $y) { label }
          }
        }
        """,
        ],
    )


def test_requires_alias_keeps_response_keys_apart_when_the_parent_repeats() raises:
    _assert_no_clashes(
        requires_alias_object_field.sdl(),
        [
            (
                'query($x: Boolean!) { me { team(role: "user") { name } } me'
                " @include(if: $x) { label } }"
            ),
            (
                "query($x: Boolean!) { me @include(if: $x) { team(role:"
                ' "user") { name } } me { label } }'
            ),
            (
                "query($x: Boolean!, $y: Boolean!) { me @include(if: $x) {"
                ' team(role: "user") { name } } me @include(if: $y) { label } }'
            ),
            (
                "query($x: Boolean!, $y: Boolean!) { me @include(if: $x) {"
                ' team(role: "user") { name } label } me @include(if: $y) {'
                " label } }"
            ),
            (
                "query($x: Boolean!, $y: Boolean!) { ... @include(if: $x) { me"
                ' { team(role: "user") { name } } } ... @include(if: $y) { me'
                " { label } } }"
            ),
        ],
    )


def test_requires_alias_keeps_response_keys_apart_across_entity_calls() raises:
    var queries: List[String] = [
        # All in one call, EUR and GBP get aliases. This one is right.
        '{ things { price(currency: "USD") eur gbp } }',
        (
            'query($x: Boolean!) { things { price(currency: "USD") eur'
            " @include(if: $x) } }"
        ),
        (
            'query($x: Boolean!) { things { price(currency: "USD")'
            " @include(if: $x) eur } }"
        ),
        (
            'query($x: Boolean!) { things { price(currency: "USD") ...'
            " @include(if: $x) { eur gbp } } }"
        ),
        (
            "query($x: Boolean!) { things { ... @include(if: $x) {"
            ' price(currency: "USD") } eur gbp } }'
        ),
        "query($x: Boolean!) { things { ... @include(if: $x) { gbp } eur } }",
    ]
    for query in queries:
        var fetches = plan_fetches(requires_alias_entity_calls.sdl(), query)
        var wrong = key_clashes(fetches)
        wrong.extend(wrong_price_reads(fetches))
        assert_true(len(wrong) == 0, query + "\n" + joined(wrong, "\n"))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

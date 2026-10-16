# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Apollo Client 4.3.3 `src/cache/inmemory/__tests__/roundtrip.ts`.

Each case writes a result with `write_query`, reads it back with
`read_query`, and compares the two in any key order. Then it writes the
field `oyez` and reads again, as upstream `storeRoundtrip` does. The
cache has `possibleTypes: { Character: ["Jedi", "Droid"] }`.

Upstream checks that are not ported:

- In `storeRoundtrip`: that a second read gives the identical (`===`)
  result, that the result is deeply frozen, and that the subtrees of the
  result keep their identity after the `oyez` write. A Mojo read builds a
  new `JsonDocument`; there is no result cache and no object identity.
- In "with GraphQLJSON scalar type": that the written data is not frozen.
- The console checks of `spyOnConsole` and `withError`: the cache prints
  no development warnings.
"""

from gql_client.cache import InMemoryCache, InMemoryCacheConfig
from std.testing import TestSuite

from _helpers import assert_read, gql, json, write


def _roundtrip(
    query: StringSlice,
    result: StringSlice,
    variables: StringSlice = "{}",
    expected: StringSlice = "",
) raises:
    """Write a result, read it back, write `oyez`, and read it again."""
    var config = InMemoryCacheConfig()
    var subtypes: List[String] = ["Jedi", "Droid"]
    config.possible_types["Character"] = subtypes^
    var cache = InMemoryCache(config)
    var document = gql(query)
    _ = cache.write_query(document, json(result), json(variables))
    var want = String(expected) if expected.byte_length() > 0 else String(
        result
    )
    assert_read(cache, document, want, variables)
    _ = write(cache, "{ oyez }", '{"oyez": 1234}')
    assert_read(cache, document, want, variables)


def test_real_graphql_result() raises:
    _roundtrip(
        '{ people_one(id: "1") { name } }',
        '{"people_one": {"name": "Luke Skywalker"}}',
    )


def test_multidimensional_array() raises:
    _roundtrip(
        "{ rows { value } }",
        (
            '{"rows": [[{"value": 1}, {"value": 2}], [{"value": 3}, {"value":'
            " 4}]]}"
        ),
    )


def test_array_with_null_values() raises:
    _roundtrip("{ list { value } }", '{"list": [null, {"value": 1}]}')


def test_enum_arguments() raises:
    _roundtrip(
        "{ hero(episode: JEDI) { name } }",
        '{"hero": {"name": "Luke Skywalker"}}',
    )


def test_with_an_alias() raises:
    _roundtrip(
        (
            '{ luke: people_one(id: "1") { name } vader: people_one(id: "4") {'
            " name } }"
        ),
        (
            '{"luke": {"name": "Luke Skywalker"}, "vader": {"name": "Darth'
            ' Vader"}}'
        ),
    )


def test_with_variables() raises:
    _roundtrip(
        (
            "{ luke: people_one(id: $lukeId) { name } vader: people_one(id:"
            " $vaderId) { name } }"
        ),
        (
            '{"luke": {"name": "Luke Skywalker"}, "vader": {"name": "Darth'
            ' Vader"}}'
        ),
        '{"lukeId": "1", "vaderId": "4"}',
    )


def test_with_a_json_scalar() raises:
    _roundtrip(
        "{ updateClub { uid name settings } }",
        (
            '{"updateClub": {"uid": "1d7f836018fc11e68d809dfee940f657", "name":'
            ' "Eple", "settings": {"name": "eple", "currency": "AFN",'
            ' "calendarStretch": 2, "defaultPreAllocationPeriod": 1,'
            ' "confirmationEmailCopy": null, "emailDomains": null}}}'
        ),
    )


def test_skip_directive_true() raises:
    _roundtrip("query { fortuneCookie @skip(if: true) }", "{}", "{}", "{}")


def test_include_directive_false() raises:
    _roundtrip("query { fortuneCookie @include(if: false) }", "{}", "{}", "{}")


def test_skip_directive_false() raises:
    _roundtrip(
        "query { fortuneCookie @skip(if: false) }",
        '{"fortuneCookie": "live long and prosper"}',
    )


def test_fragments_on_null_fields() raises:
    _roundtrip("query { field { ... on Obj { stuff } } }", '{"field": null}')


def test_basic_inline_fragments() raises:
    _roundtrip(
        "query { field { __typename ... on Obj { stuff } } }",
        '{"field": {"__typename": "Obj", "stuff": "Result"}}',
    )


def test_two_of_the_same_inline_fragment_types() raises:
    _roundtrip(
        (
            "query { all_people { __typename name ... on Jedi { side } ... on"
            " Jedi { rank } } }"
        ),
        (
            '{"all_people": [{"__typename": "Jedi", "name": "Luke Skywalker",'
            ' "side": "bright"}]}'
        ),
        "{}",
        "null",
    )


def test_interface_with_non_matching_inline_fragments() raises:
    _roundtrip(
        "query { dark_forces { __typename name ... on Droid { model } } }",
        (
            '{"dark_forces": [{"__typename": "Droid", "name": "8t88", "model":'
            ' "88"}, {"__typename": "Darth", "name": "Anakin Skywalker"}]}'
        ),
    )


def test_union_types_with_spread_fragments() raises:
    _roundtrip(
        (
            "fragment jediFragment on Jedi { side } fragment droidFragment on"
            " Droid { model } query { all_people { __typename name"
            " ...jediFragment ...droidFragment } }"
        ),
        (
            '{"all_people": [{"__typename": "Jedi", "name": "Luke Skywalker",'
            ' "side": "bright"}, {"__typename": "Droid", "name": "R2D2",'
            ' "model": "astromech"}]}'
        ),
    )


def test_fragment_on_the_actual_interface() raises:
    _roundtrip(
        (
            "fragment jediFragment on Character { side } fragment droidFragment"
            " on Droid { model } query { all_people { name __typename"
            " ...jediFragment ...droidFragment } }"
        ),
        (
            '{"all_people": [{"__typename": "Jedi", "name": "Luke Skywalker",'
            ' "side": "bright"}, {"__typename": "Droid", "name": "R2D2",'
            ' "model": "astromech", "side": "bright"}]}'
        ),
    )


def test_two_of_the_same_spread_fragment_types() raises:
    _roundtrip(
        (
            "fragment jediSide on Jedi { side } fragment jediRank on Jedi {"
            " rank } query { all_people { __typename name ...jediSide"
            " ...jediRank } }"
        ),
        (
            '{"all_people": [{"__typename": "Jedi", "name": "Luke Skywalker",'
            ' "side": "bright"}]}'
        ),
        "{}",
        "null",
    )


def test_include_and_skip_with_inline_fragments() raises:
    _roundtrip(
        (
            "query { person { name __typename ... on Jedi @include(if: true) {"
            " side } ... on Droid @skip(if: true) { model } } }"
        ),
        (
            '{"person": {"__typename": "Jedi", "name": "Luke Skywalker",'
            ' "side": "bright"}}'
        ),
    )


def test_include_and_skip_with_spread_fragments() raises:
    _roundtrip(
        (
            "fragment jediFragment on Jedi { side } fragment droidFragment on"
            " Droid { model } query { person { name __typename ...jediFragment"
            " @include(if: true) ...droidFragment @skip(if: true) } }"
        ),
        (
            '{"person": {"__typename": "Jedi", "name": "Luke Skywalker",'
            ' "side": "bright"}}'
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

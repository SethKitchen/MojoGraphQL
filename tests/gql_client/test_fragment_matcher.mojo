# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Apollo Client 4.3.3 `src/cache/inmemory/__tests__/fragmentMatcher.ts`.

`policies.fragmentMatches(fragment, typename)` is
`cache.policies.fragment_matches(typeCondition, typename, False)`. The
snapshot of "can infer fuzzy subtypes heuristically" is the Node.js output
of Apollo Client 4.3.3.

Upstream cases that are not ported:

- The `Inferring subtype %s of supertype %s` warnings of "can infer fuzzy
  subtypes heuristically": the cache prints no warnings. The rest of the
  case is ported.
"""

from std.collections import Dict

from gql_client.cache import InMemoryCache, InMemoryCacheConfig
from std.testing import TestSuite, assert_equal

from _helpers import assert_extract_exact, assert_read, gql, json


def _animal_cache() raises -> InMemoryCache:
    """A cache with `possibleTypes: { Animal: ["Cat", "Dog"] }`."""
    var config = InMemoryCacheConfig()
    var animal: List[String] = ["Cat", "Dog"]
    config.possible_types["Animal"] = animal^
    return InMemoryCache(config)


def test_matches_exact_types_with_or_without_possible_types() raises:
    var query = gql(
        "query AnimalNames { animals { id name ...CatDetails } } fragment"
        " CatDetails on Cat { livesLeft killsToday }"
    )
    var data = (
        '{"animals": [{"__typename": "Cat", "id": 1, "name": "Felix",'
        ' "livesLeft": 8, "killsToday": 2}, {"__typename": "Dog", "id": 2,'
        ' "name": "Baxter"}]}'
    )
    var without = InMemoryCache()
    _ = without.write_query(query, json(data))
    assert_read(without, query, data)
    var with_types = _animal_cache()
    _ = with_types.write_query(query, json(data))
    assert_read(with_types, query, data)


def test_matches_interface_subtypes() raises:
    var cache = _animal_cache()
    var query = gql(
        "query BestFriend { bestFriend { id ...AnimalName } } fragment"
        " AnimalName on Animal { name }"
    )
    var data = (
        '{"bestFriend": {"__typename": "Dog", "id": 2, "name": "Beckett"}}'
    )
    _ = cache.write_query(query, json(data))
    assert_read(cache, query, data)


def test_matches_union_member_types() raises:
    var config = InMemoryCacheConfig()
    var status: List[String] = ["PASSING", "FAILING", "SKIPPED"]
    config.possible_types["Status"] = status^
    var cache = InMemoryCache(config)
    var query = gql(
        "query { testResults { id output { ... on Status { stdout } ... on"
        " FAILING { stderr } } } }"
    )
    var data = (
        '{"testResults": [{"__typename": "TestResult", "id": 123, "output":'
        ' {"__typename": "PASSING", "stdout": "ok!"}}, {"__typename":'
        ' "TestResult", "id": 456, "output": {"__typename": "FAILING",'
        ' "stdout": "", "stderr": "oh no"}}]}'
    )
    _ = cache.write_query(query, json(data))
    assert_read(cache, query, data)


def test_matches_indirect_subtypes_while_avoiding_cycles() raises:
    var config = InMemoryCacheConfig()
    var animal: List[String] = ["Animal", "Bug", "Mammal"]
    var bug: List[String] = ["Ant", "Spider", "RolyPoly"]
    var mammal: List[String] = ["Dog", "Cat", "Human"]
    var cat: List[String] = ["Calico", "Siamese", "Sphynx", "Tabby"]
    config.possible_types["Animal"] = animal^
    config.possible_types["Bug"] = bug^
    config.possible_types["Mammal"] = mammal^
    config.possible_types["Cat"] = cat^
    var cache = InMemoryCache(config)
    var query = gql(
        "query { animals { ... on Mammal { hasFur bodyTemperature } ... on Bug"
        " { isVenomous } } }"
    )
    var data = (
        '{"animals": [{"__typename": "Sphynx", "hasFur": false,'
        ' "bodyTemperature": 99}, {"__typename": "Dog", "hasFur": true,'
        ' "bodyTemperature": 102}, {"__typename": "Spider", "isVenomous":'
        ' "maybe"}]}'
    )
    _ = cache.write_query(query, json(data))
    assert_read(cache, query, data)


def test_matches_against_the_root_query() raises:
    var cache = InMemoryCache()
    var query = gql(
        "query AllPeople { people { id name } ...PeopleTypes } fragment"
        ' PeopleTypes on Query { __type(name: "Person") { name kind } }'
    )
    var data = (
        '{"people": [{"__typename": "Person", "id": 123, "name": "Ben"}],'
        ' "__type": {"__typename": "__Type", "name": "Person", "kind":'
        ' "OBJECT"}}'
    )
    _ = cache.write_query(query, json(data))
    assert_read(cache, query, data)


def _check_types(
    mut cache: InMemoryCache,
    supertype: StringSlice,
    subtypes: StringSlice,
    expected: StringSlice,
) raises:
    """Check `fragmentMatches` of one type condition for some types.

    `subtypes` holds one type per character, or `TooLong`; `expected`
    holds `1` or `0` for each.
    """
    var names = List[String]()
    for part in subtypes.split(" "):
        names.append(String(part))
    var flags = expected.as_bytes()
    var index = 0
    while index < len(names):
        var matched = cache.policies.fragment_matches(
            supertype, names[index], False
        )
        assert_equal(
            String(supertype, " ", names[index], " ", matched),
            String(
                supertype,
                " ",
                names[index],
                " ",
                flags[index] == UInt8(ord("1")),
            ),
        )
        index += 1


def test_infers_fuzzy_subtypes_heuristically() raises:
    var config = InMemoryCacheConfig()
    var a: List[String] = ["B", "C"]
    var b: List[String] = ["D"]
    var c: List[String] = ["[E-Z]"]
    config.possible_types["A"] = a^
    config.possible_types["B"] = b^
    config.possible_types["C"] = c^
    var cache = InMemoryCache(config)
    var types = "A B C D E F G"
    _check_types(cache, "A", types, "1111000")
    _check_types(cache, "B", types, "0101000")
    _check_types(cache, "C", types, "0010000")
    _check_types(cache, "D", types, "0001000")
    _check_types(cache, "E", types, "0000100")
    _check_types(cache, "F", types, "0000010")
    var fragments = (
        " fragment FragA on A { a } fragment FragB on B { b } fragment FragC"
        " on C { c } fragment FragD on D { d } fragment FragE on E { e }"
        " fragment FragF on F { f }"
    )
    var query = gql("query { objects { ...FragC } }" + fragments)
    _ = cache.write_query(
        query,
        json(
            '{"objects": [{"__typename": "E", "c": "ce"}, {"__typename": "F",'
            ' "c": "cf"}, {"__typename": "G", "c": "cg"}, {"__typename":'
            ' "TooLong", "c": "nope"}, {"__typename": "H", "h": "not c"}]}'
        ),
    )
    types = "A B C D E F G H"
    _check_types(cache, "A", types, "11111110")
    _check_types(cache, "B", types, "01010000")
    _check_types(cache, "C", types, "00101110")
    _check_types(cache, "D", types, "00010000")
    _check_types(cache, "E", types, "00001000")
    _check_types(cache, "F", types, "00000100")
    assert_extract_exact(
        cache,
        '{"ROOT_QUERY":{"__typename":"Query","objects":[{"__typename":"E","c":"ce"},{"__typename":"F","c":"cf"},{"__typename":"G","c":"cg"},{"__typename":"TooLong"},{"__typename":"H"}]}}',
    )
    var more = Dict[String, List[String]]()
    var too_long: List[String] = ["TooLong"]
    more["C"] = too_long^
    cache.policies.add_possible_types(more)
    types = "A B C D E F G TooLong H"
    _check_types(cache, "A", types, "111111110")
    _check_types(cache, "B", types, "010100000")
    _check_types(cache, "C", types, "001011110")
    _check_types(cache, "D", types, "000100000")
    _check_types(cache, "E", types, "000010000")
    _check_types(cache, "F", types, "000001000")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

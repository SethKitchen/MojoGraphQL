# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Compile and run generated code.

`_generated_starwars.mojo` is the output of `compile` for
`fixtures/golden/schema.graphqls` and `fixtures/golden/operations.graphql`.
`test_golden_is_current` checks that the generator still writes exactly
that module, so the suite compiles the current output, and the other tests
run it: they read responses, and write variables and input objects.

This suite has no upstream counterpart: the upstream tests compile the
generated Kotlin in `CodegenTest.kt` and run it in the integration tests,
in Kotlin.
"""

from std.pathlib import Path
from std.testing import TestSuite, assert_equal, assert_false, assert_raises
from std.testing import assert_true

from gql_json.parser import parse
from gql_json.writer import JsonWriter

from gql_codegen.compiler import CodegenDocument, build_codegen_schema, compile
from gql_codegen.issues import serialize
from gql_codegen.sha256 import sha256_hex

from _fixtures import read
from _generated_starwars import (
    ColorInput,
    CreateReviewMutation,
    CreateReviewMutation_Variables,
    DeferredQuery,
    DeferredQuery_Variables,
    Episode,
    HeroQuery,
    HeroQuery_Variables,
    ReviewInput,
    SearchQuery,
    SearchQuery_Variables,
)

comptime GOLDEN = "tests/gql_codegen/fixtures/golden/"
"""The schema and the operations of the generated module."""


def test_golden_is_current() raises:
    var schema = build_codegen_schema(read("golden/schema.graphqls"))
    var documents = List[CodegenDocument]()
    documents.append(
        CodegenDocument(
            "operations.graphql",
            read("golden/operations.graphql"),
        )
    )
    var result = compile(schema, documents)
    assert_equal(serialize(result.errors), "")
    assert_equal(serialize(result.warnings), "")
    assert_equal(
        result.source,
        Path("tests/gql_codegen/_generated_starwars.mojo").read_text(),
    )
    var ids = result.operation_ids()
    assert_equal(ids[0], String(HeroQuery.OPERATION_ID))
    assert_equal(result.operation_names()[3], "DeferredQuery")


def test_operation_constants() raises:
    assert_equal(String(HeroQuery.OPERATION_NAME), "Hero")
    assert_equal(
        String(HeroQuery.OPERATION_ID),
        sha256_hex(String(HeroQuery.OPERATION_DOCUMENT)),
    )
    assert_true(
        String(HeroQuery.OPERATION_DOCUMENT).endswith(
            "fragment CharacterAppearances on Character { appearsIn }"
        )
    )
    assert_true(
        String(SearchQuery.OPERATION_DOCUMENT).startswith(
            "query Search($text: String!, $verbose: Boolean! = false ) {"
        )
    )


def test_read_a_droid() raises:
    var document = parse(
        '{"hero": {"__typename": "Droid", "name": "R2-D2", "id": 2001,'
        ' "friends": [{"name": "Luke"}, null], "primaryFunction":'
        ' "Astromech", "appearsIn": ["NEWHOPE", "JEDI", "FUTURE"]}}'
    )
    var data = HeroQuery.parse_data(document, 0, HeroQuery_Variables())
    var hero = data.hero.value().copy()
    assert_equal(hero.__typename, "Droid")
    assert_equal(hero.name.value(), "R2-D2")
    assert_equal(hero.id, "2001")
    var friends = hero.friends.value().copy()
    assert_equal(len(friends), 2)
    assert_equal(friends[0].value().name, "Luke")
    assert_false(friends[1])
    assert_equal(hero.onDroid.value().primaryFunction.value(), "Astromech")
    assert_false(hero.onHuman)
    var appears = hero.characterAppearances.appearsIn.copy()
    assert_true(appears[0].value() == Episode.NEWHOPE)
    assert_true(appears[1].value() == Episode.JEDI)
    assert_true(appears[2].value() == Episode.UNKNOWN__)


def test_read_a_human() raises:
    var document = parse(
        '{"hero": {"__typename": "Human", "id": "1000", "height": 1.72,'
        ' "birthDate": "1951-09-25", "appearsIn": []}}'
    )
    var data = HeroQuery.parse_data(document, 0, HeroQuery_Variables())
    var hero = data.hero.value().copy()
    assert_false(hero.name)
    assert_false(hero.friends)
    assert_false(hero.onDroid)
    var human = hero.onHuman.value().copy()
    assert_equal(human.height.value(), 1.72)
    # A custom scalar is the JSON text of its value.
    assert_equal(human.birthDate.value(), '"1951-09-25"')


def test_read_no_hero() raises:
    var document = parse('{"hero": null}')
    var data = HeroQuery.parse_data(document, 0, HeroQuery_Variables())
    assert_false(data.hero)


def test_read_refuses_a_bad_response() raises:
    var variables = HeroQuery_Variables()
    var missing = parse('{"hero": {"__typename": "Droid", "appearsIn": []}}')
    with assert_raises(contains="missing field id"):
        _ = HeroQuery.parse_data(missing, 0, variables)
    var null = parse(
        '{"hero": {"__typename": "Droid", "id": null, "appearsIn": []}}'
    )
    with assert_raises(contains="null for the non-null field id"):
        _ = HeroQuery.parse_data(null, 0, variables)
    var number = parse('{"hero": 3}')
    with assert_raises(contains="expected an object"):
        _ = HeroQuery.parse_data(number, 0, variables)
    var not_list = parse(
        '{"hero": {"__typename": "Droid", "id": "1", "appearsIn": 3}}'
    )
    with assert_raises(contains="expected a list"):
        _ = HeroQuery.parse_data(not_list, 0, variables)
    var not_string = parse('{"hero": {"__typename": 1}}')
    with assert_raises(contains="expected a string"):
        _ = HeroQuery.parse_data(not_string, 0, variables)


def test_read_a_search() raises:
    var document = parse(
        '{"search": [{"__typename": "Human", "name": "Leia", "mass": 49},'
        ' {"__typename": "Droid", "name": "C-3PO"}], "matrix": [[1, 2],'
        " null]}"
    )
    var data = SearchQuery.parse_data(
        document, 0, SearchQuery_Variables("leia")
    )
    assert_equal(len(data.search), 2)
    assert_equal(data.search[0].onHuman.value().name, "Leia")
    assert_equal(data.search[0].onHuman.value().mass.value(), 49.0)
    assert_false(data.search[0].onDroid)
    assert_equal(data.search[1].onDroid.value().name, "C-3PO")
    var matrix = data.matrix.value().copy()
    assert_equal(matrix[0].value()[1], 2)
    assert_false(matrix[1])
    var fraction = parse('{"search": [], "matrix": [[1.5]]}')
    with assert_raises(contains="expected an integer"):
        _ = SearchQuery.parse_data(fraction, 0, SearchQuery_Variables("x"))


def test_read_a_deferred_fragment() raises:
    var variables = DeferredQuery_Variables()
    var data = DeferredQuery.parse_data(
        parse(
            '{"hero": {"__typename": "Droid", "id": "1", "primaryFunction":'
            ' "Protocol"}}'
        ),
        0,
        variables,
    )
    assert_equal(
        data.hero.value().onDroid.value().primaryFunction.value(),
        "Protocol",
    )
    # A deferred fragment that does not read yet is absent.
    data = DeferredQuery.parse_data(
        parse(
            '{"hero": {"__typename": "Droid", "id": "1", "primaryFunction": 3}}'
        ),
        0,
        variables,
    )
    assert_false(data.hero.value().onDroid)


def test_read_a_mutation() raises:
    var review = ReviewInput(5)
    var data = CreateReviewMutation.parse_data(
        parse(
            '{"createReview": {"stars": 5, "commentary": null, "from": "fan"}}'
        ),
        0,
        CreateReviewMutation_Variables(review),
    )
    var created = data.createReview.value().copy()
    assert_equal(created.stars, 5)
    assert_false(created.commentary)
    assert_equal(created.from_.value(), "fan")


def written(variables: HeroQuery_Variables, defaults: Bool) raises -> String:
    """Write variables as JSON."""
    var writer = JsonWriter()
    variables.write_json(writer, defaults)
    return writer^.take_string()


def test_write_variables() raises:
    assert_equal(written(HeroQuery_Variables(), False), "{}")
    assert_equal(
        written(HeroQuery_Variables(), True),
        '{"withFriends":true,"skipName":false}',
    )
    var variables = HeroQuery_Variables(
        episode=Optional[Episode](Episode.JEDI),
        withFriends=False,
        skipName=Optional[Bool](None),
    )
    assert_equal(
        written(variables, True),
        '{"episode":"JEDI","withFriends":false,"skipName":null}',
    )
    variables = HeroQuery_Variables(
        episode=Optional[Episode](None), skipName=Optional[Bool](True)
    )
    assert_equal(written(variables, False), '{"episode":null,"skipName":true}')


def test_false_variables() raises:
    # An absent variable with the default `false` is false.
    assert_equal(len(HeroQuery_Variables().false_variables()), 1)
    var variables = HeroQuery_Variables(
        withFriends=False, skipName=Optional[Bool](False)
    )
    var names = variables.false_variables()
    assert_equal(len(names), 2)
    assert_equal(names[0], "withFriends")
    assert_equal(names[1], "skipName")
    var true_names = HeroQuery_Variables(
        withFriends=True, skipName=Optional[Bool](True)
    ).false_variables()
    assert_equal(len(true_names), 0)
    assert_equal(len(SearchQuery_Variables("x").false_variables()), 1)
    assert_equal(
        len(SearchQuery_Variables("x", verbose=True).false_variables()), 0
    )


def test_write_input_objects() raises:
    var tags = List[String]()
    tags.append("classic")
    var episodes = List[Optional[Episode]]()
    episodes.append(Episode.EMPIRE)
    episodes.append(None)
    var review = ReviewInput(
        4,
        commentary=Optional[String]("Good"),
        favoriteColor=Optional[ColorInput](ColorInput(1, 2)),
        tags=Optional[List[String]](tags^),
        episodes=Optional[List[Optional[Episode]]](episodes^),
        when=Optional[String]('"1980-05-21"'),
        isFan=Optional[Bool](None),
    )
    var writer = JsonWriter()
    CreateReviewMutation_Variables(
        review, episode=Optional[Episode](Episode.EMPIRE)
    ).write_json(writer)
    assert_equal(
        writer^.take_string(),
        (
            '{"episode":"EMPIRE","review":{"stars":4,"commentary":"Good",'
            '"favoriteColor":{"green":1,"blue":2},"tags":["classic"],'
            '"episodes":["EMPIRE",null],"when":"1980-05-21","isFan":null}}'
        ),
    )
    var empty = JsonWriter()
    var nulls = ReviewInput(
        1,
        commentary=Optional[String](None),
        favoriteColor=Optional[ColorInput](None),
        tags=Optional[List[String]](None),
        episodes=Optional[List[Optional[Episode]]](None),
        when=Optional[String](None),
    )
    nulls.write_json(empty)
    assert_equal(
        empty^.take_string(),
        (
            '{"stars":1,"commentary":null,"favoriteColor":null,"tags":null,'
            '"episodes":null,"when":null}'
        ),
    )
    var color = JsonWriter()
    ColorInput(3, 4, red=Optional[Int](5)).write_json(color)
    assert_equal(color^.take_string(), '{"red":5,"green":3,"blue":4}')


def test_enum() raises:
    assert_true(Episode.safe_value_of("EMPIRE") == Episode.EMPIRE)
    assert_true(Episode.safe_value_of("NEWHOPE") == Episode.NEWHOPE)
    assert_true(Episode.safe_value_of("SITH") == Episode.UNKNOWN__)
    assert_equal(Episode.JEDI.raw_value(), "JEDI")
    assert_true(Episode.JEDI.is_valid())
    assert_false(Episode.UNKNOWN__.is_valid())
    assert_equal(String(Episode.NEWHOPE), "NEWHOPE")
    assert_equal(String(Episode.UNKNOWN__), "UNKNOWN__")
    with assert_raises(contains="the value of Episode is not known"):
        _ = Episode.UNKNOWN__.raw_value()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

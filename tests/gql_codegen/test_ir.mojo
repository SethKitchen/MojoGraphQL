# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The IR of the Apollo Kotlin compiler tests.

Port of the language-independent part of Apollo Kotlin
`libraries/apollo-compiler/src/test/kotlin/com/apollographql/apollo/
compiler/CodegenTest.kt`:

- `used-coordinates.json.expected`: the types and arguments that the
  operations use, which `CodegenTest` writes from `IrOperations
  .usedCoordinates`, for every supported fixture.
- The `operationBased` models: the nested data classes of the expected
  Kotlin output, with their property names and types. Each model prints
  as `Name { property: Type, ... }`, its models indented below it.
"""

from std.testing import TestSuite, assert_equal, assert_true

from gql_codegen.ir import IrOperations
from gql_codegen.issues import serialize

from _fixtures import (
    has,
    compile_fixture,
    fixture_schema,
    fixtures,
    is_unsupported,
    read,
    uses_data_builders,
)


def _dump_model(ir: IrOperations, root: Int, mut out: String):
    """Print a model and its models, depth first."""
    var models: List[Int] = [root]
    var depths: List[Int] = [0]
    while len(models) > 0:
        var model = models.pop()
        var depth = depths.pop()
        ref found = ir.models[model]
        for _ in range(depth):
            out += "  "
        out += found.model_name + " {"
        for index in range(len(found.properties)):
            ref property = found.properties[index]
            out += " " if index == 0 else ", "
            var type = property.info.type.text()
            if property.info.type.model != "":
                type = type.replace(property.info.type.model, "Model")
            out += property.info.response_name + ": " + type
        out += " }\n"
        for index in range(len(found.models) - 1, -1, -1):
            models.append(found.models[index])
            depths.append(depth + 1)


def dump(fixture: String) raises -> String:
    """Compile a fixture and print the models of its operations.

    Args:
        fixture: The fixture's name.

    Returns:
        The models, one per line.

    Raises:
        Error: When the fixture does not compile.
    """
    var result = compile_fixture(fixture, fixture_schema(fixture))
    assert_equal(serialize(result.errors), "", fixture)
    var out = String("")
    for ref fragment in result.ir.fragments:
        _dump_model(result.ir, fragment.data_model, out)
    for ref operation in result.ir.operations:
        _dump_model(result.ir, operation.data_model, out)
    return out^


def check_coordinates(part: Int, parts: Int) raises:
    """Check the used coordinates of one part of the fixtures.

    Args:
        part: Which part, from 0.
        parts: How many parts there are.

    Raises:
        Error: When the coordinates differ from upstream.
    """
    var all = fixtures()
    var checked = 0
    for index in range(
        len(all) * part // parts, len(all) * (part + 1) // parts
    ):
        var fixture = all[index]
        if is_unsupported(fixture) or uses_data_builders(fixture):
            continue
        var path = fixture + "/used-coordinates.json.expected"
        if not has(path):
            continue
        var result = compile_fixture(fixture, fixture_schema(fixture))
        assert_equal(serialize(result.errors), "", fixture)
        assert_equal(
            result.ir.used_coordinates.to_json(),
            String(read(path).rstrip("\n")),
            fixture,
        )
        checked += 1
    assert_true(checked > 0)


def test_used_coordinates_part_1() raises:
    check_coordinates(0, 3)


def test_used_coordinates_part_2() raises:
    check_coordinates(1, 3)


def test_used_coordinates_part_3() raises:
    check_coordinates(2, 3)


def test_models_hero_name() raises:
    # hero_name/kotlin/operationBased/hero_name/TestQuery.kt.expected
    assert_equal(
        dump("hero_name"),
        (
            "Data { hero: Model }\n"
            "  Hero { __typename: String!, name: String!, birthDate: Date!,"
            " onDroid: Model }\n"
            "    OnDroid { primaryFunction: String }\n"
        ),
    )


def test_models_inline_fragment_with_include_directive() raises:
    assert_equal(
        dump("inline_fragment_with_include_directive"),
        (
            "Data { hero: Model }\n"
            "  Hero { __typename: String!, id: ID!, onHuman: Model, onDroid:"
            " Model, onCharacter: Model }\n"
            "    OnHuman { name: String!, homePlanet: String }\n"
            "    OnDroid { name: String!, primaryFunction: String }\n"
            "    OnCharacter { name: String! }\n"
        ),
    )


def test_models_fragment_spread_with_include_directive() raises:
    # Each spread with a condition is nullable; the fragments have their
    # own models.
    assert_equal(
        dump("fragment_spread_with_include_directive"),
        (
            "HeroDetails { name: String! }\n"
            "HumanDetails { homePlanet: String }\n"
            "DroidDetails { primaryFunction: String }\n"
            "OtherDroidDetails { id: ID! }\n"
            "Data { hero: Model, getBoolean: Boolean }\n"
            "  Hero { __typename: String!, id: ID!, heroDetails: Model,"
            " humanDetails: Model, droidDetails: Model, otherDroidDetails:"
            " Model }\n"
        ),
    )


def test_models_fragments_with_defer_and_include_directives() raises:
    # Two inline fragments on one type are named after their conditions:
    # `If` and the variables, or `Defer` and the label.
    var models = dump("fragments_with_defer_and_include_directives")
    assert_true(
        "  Hero { __typename: String!, onDroidDeferD_first: Model,"
        " onDroidDeferD_second: Model }\n"
        in models
    )
    assert_true(
        "  Hero { __typename: String!, onDroidIfCond1: Model,"
        " onDroidIfNotCond2: Model, onDroidDeferE_first: Model,"
        " onDroidDeferE_second: Model, onDroidDeferE_third: Model,"
        " onDroidDeferE_fourth: Model }\n"
        in models
    )
    # `@defer(if: false)` is always read, so `onCharacter` is not null.
    assert_true(
        "  Hero { __typename: String!, onCharacter: Model!,"
        " onCharacterDeferF_second: Model, onCharacterDeferF_third:"
        " Model }\n"
        in models
    )
    assert_true(
        "  Hero { __typename: String!, characterDetails: Model,"
        " characterDetails2: Model, characterDetails3: Model }\n"
        in models
    )


def test_models_union_inline_fragments() raises:
    # A list field's model is named after the singular: friends, Friend.
    assert_equal(
        dump("union_inline_fragments"),
        (
            "Data { search: [Model] }\n"
            "  Search { __typename: String!, onCharacter: Model, onStarship:"
            " Model }\n"
            "    OnCharacter { id: ID!, name: String!, friends: [Model] }\n"
            "      Friend { __typename: String!, onCharacter: Model!, onHuman:"
            " Model, onDroid: Model }\n"
            "        OnCharacter { name: String! }\n"
            "        OnHuman { homePlanet: String, friends: [Model] }\n"
            "          Friend { __typename: String!, onCharacter: Model! }\n"
            "            OnCharacter { firstAppearsIn: Episode! }\n"
            "        OnDroid { primaryFunction: String, friends: [Model] }\n"
            "          Friend { id: ID! }\n"
            "    OnStarship { name: String! }\n"
        ),
    )


def test_models_inline_fragments_with_friends() raises:
    assert_equal(
        dump("inline_fragments_with_friends"),
        (
            "Data { hero: Model }\n"
            "  Hero { __typename: String!, name: String!, onHuman: Model,"
            " onDroid: Model }\n"
            "    OnHuman { height: Float, friends: [Model] }\n"
            "      Friend { appearsIn: [Episode]! }\n"
            "    OnDroid { primaryFunction: String, friends: [Model] }\n"
            "      Friend { id: ID! }\n"
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

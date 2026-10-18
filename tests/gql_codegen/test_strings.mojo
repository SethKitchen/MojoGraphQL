# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The string helpers of the code generator.

Apollo Kotlin has no test file for `Strings.kt` and `Inflector.kt`; their
behavior shows in the model names of `CodegenTest.kt`. These tests check
each singularization rule of `Inflector.kt`, the `QueryDocumentMinifier`
regular expression, and the escapes of `gqlstrings.kt`
`encodeToGraphQLSingleQuoted`, one case per branch.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from gql_codegen.sha256 import sha256_hex
from gql_codegen.strings import (
    capitalize_first_letter,
    decapitalize_first_letter,
    encode_single_quoted,
    escape_mojo_keyword,
    is_first_letter_upper_case,
    minify,
    singularize,
    upper_camel_case,
)


def test_capitalize() raises:
    assert_equal(capitalize_first_letter("hero"), "Hero")
    assert_equal(capitalize_first_letter("__typename"), "__Typename")
    assert_equal(capitalize_first_letter("Hero"), "Hero")
    assert_equal(capitalize_first_letter("_1"), "_1")
    assert_equal(decapitalize_first_letter("HeroDetails"), "heroDetails")
    assert_equal(decapitalize_first_letter("__Type"), "__type")
    assert_equal(decapitalize_first_letter("hero"), "hero")
    assert_equal(decapitalize_first_letter("_1"), "_1")
    assert_equal(upper_camel_case(["hero", "friend"]), "HeroFriend")


def test_first_letter_upper_case() raises:
    assert_true(is_first_letter_upper_case("Horse"))
    assert_true(is_first_letter_upper_case("__Horse"))
    assert_false(is_first_letter_upper_case("_horse"))
    # Upstream counts a name without a letter as capitalized.
    assert_true(is_first_letter_upper_case("__"))


def check(word: String, singular: String) raises:
    """Check one singularization."""
    assert_equal(singularize(word), singular, word)


def test_singularize_rules() raises:
    # One word per rule of `singularizationRules`, from the last rule.
    check("databases", "database")
    check("quizzes", "quiz")
    check("matrices", "matrix")
    check("vertices", "vertex")
    check("indices", "index")
    check("aliases", "alias")
    check("statuses", "status")
    check("alias", "alias")
    check("status", "status")
    check("octopi", "octopus")
    check("viri", "virus")
    check("octopus", "octopus")
    check("virus", "virus")
    check("axes", "axis")
    check("axis", "axis")
    check("crises", "crisis")
    check("testes", "testis")
    check("crisis", "crisis")
    check("testis", "testis")
    check("shoes", "shoe")
    check("heroes", "hero")
    check("buses", "bus")
    check("bus", "bus")
    check("mice", "mouse")
    check("lice", "louse")
    check("boxes", "box")
    check("matches", "match")
    check("classes", "class")
    check("wishes", "wish")
    check("movies", "movie")
    check("series", "series")
    check("categories", "category")
    check("soliloquies", "soliloquy")
    check("wolves", "wolf")
    check("halves", "half")
    check("natives", "native")
    check("archives", "archive")
    check("knives", "knife")
    check("analyses", "analysis")
    check("analysis", "analysis")
    check("data", "data")
    check("strata", "stratum")
    check("criteria", "criterium")
    check("class", "class")
    check("friends", "friend")
    check("hero", "hero")


def test_singularize_edges() raises:
    # The rules that look at the letter before a suffix, when it is not
    # there or does not match.
    check("ies", "ie")
    check("pies", "py")
    check("ves", "ve")
    check("chives", "chive")
    check("offs", "off")
    check("a", "a")
    check("Pa", "Pa")
    check("reviews", "review")
    check("taxa", "taxa")
    check("ox", "ox")
    check("oxen", "oxen")
    check("abus", "abus")
    check("maxes", "max")
    check("analysises", "analysise")
    check("Lice", "Louse")
    check("blice", "blice")
    check("taxis", "taxi")


def test_singularize_more_edges() raises:
    check("", "")
    check("miniseries", "miniseries")
    check("toies", "toie")
    check("scarves", "scarf")
    check("fves", "fve")
    assert_equal(capitalize_first_letter(""), "")
    assert_equal(decapitalize_first_letter(""), "")
    assert_true(is_first_letter_upper_case(""))
    assert_equal(upper_camel_case(List[String]()), "")


def test_singularize_word_lists() raises:
    check("equipment", "equipment")
    check("Information", "Information")
    check("people", "person")
    check("People", "Person")
    check("men", "man")
    check("children", "child")
    check("sexes", "sex")
    check("moves", "move")
    check("zombies", "zombie")
    check("geese", "goose")
    check("Data", "Data")


def test_minify() raises:
    assert_equal(
        minify("query A {\n  hero {\n    name\n  }\n}"),
        "query A { hero { name } }",
    )
    assert_equal(minify("a\n\nb"), "a  b")
    assert_equal(minify("a\t \r\x0b\x0cb"), "a    b")
    assert_equal(minify("a    b"), "a b")
    assert_equal(minify(""), "")


def test_encode_single_quoted() raises:
    assert_equal(encode_single_quoted('a"b\\c'), 'a\\"b\\\\c')
    assert_equal(encode_single_quoted("\x08\x0c\n\r\t"), "\\b\\f\\n\\r\\t")
    assert_equal(encode_single_quoted("\x01\x1f\x7f"), "\\u0001\\u001f\\u007f")
    assert_equal(encode_single_quoted("\u0080\u009f"), "\\u0080\\u009f")
    assert_equal(encode_single_quoted("é "), "é ")
    assert_equal(encode_single_quoted("plain"), "plain")


def test_escape_mojo_keyword() raises:
    assert_equal(escape_mojo_keyword("from"), "from_")
    assert_equal(escape_mojo_keyword("yield"), "yield_")
    assert_equal(escape_mojo_keyword("False"), "False_")
    assert_equal(escape_mojo_keyword("name"), "name")


def test_sha256() raises:
    assert_equal(
        sha256_hex(""),
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    )
    assert_equal(
        sha256_hex(
            "query TestQuery { hero { __typename name birthDate ... on Droid"
            " { primaryFunction } } }"
        ),
        "17e30561f6043a4c67f3de02bc6c76798edb2d584095975a2f75862222ef4912",
    )
    # 64 bytes: the padding takes a second block.
    assert_equal(
        sha256_hex(
            "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmno"
        ),
        "2ff100b36c386c65a1afc462ad53e25479bec9498ed00aa5a04de584bc25301b",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

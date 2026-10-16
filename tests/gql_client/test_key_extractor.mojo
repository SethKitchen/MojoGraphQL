# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Apollo Client 4.3.3 `src/cache/inmemory/__tests__/key-extractor.ts`.

A specifier is given as its JSON text to `KeySpecifier.parse`. The upstream
check that `getSpecifierPaths` caches its result (`toBe`) is object
identity, which a Mojo value does not have; the paths are checked by value.
The cases of `KeySpecifier.from_paths` and of the refused specifiers have
no upstream counterpart.
"""

from gql_client.key_extractor import (
    KeySpecifier,
    collect_specifier_paths,
    extract_key_path,
)
from gql_client.values import Values
from std.testing import TestSuite, assert_equal, assert_raises

from _helpers import json


def _paths_text(specifier: KeySpecifier) -> String:
    """Return the paths as text, such as `a.b|a.c|d`."""
    var out = String("")
    var index = 0
    while index < len(specifier.paths):
        if index > 0:
            out += "|"
        out += ".".join(specifier.paths[index])
        index += 1
    return out^


def _check_paths(text: StringSlice, expected: StringSlice) raises:
    """Check the paths of a specifier."""
    assert_equal(_paths_text(KeySpecifier.parse(text)), String(expected))


def test_get_specifier_paths_works_for_various_specifiers() raises:
    _check_paths("[]", "")
    _check_paths('["a"]', "a")
    _check_paths('["a", "b", "c"]', "a|b|c")
    _check_paths('["a", ["b", "c"], "d"]', "a.b|a.c|d")
    _check_paths('["a", "b", ["c"], "d"]', "a|b.c|d")
    _check_paths(
        '["a", "b", ["c", ["d", ["e", "f"], "g"]]]', "a|b.c.d.e|b.c.d.f|b.c.g"
    )


def _collect(text: StringSlice) raises -> String:
    """Return `JSON.stringify(collectSpecifierPaths(specifier, extract))`
    for the object of the upstream case."""
    var values = Values()
    var data = json(
        '{"a": 123, "b": {"d": {"f": 567, "e": 456}, "c": 234, "g": 678},'
        ' "h": 789}'
    )
    var object = values.from_json(data, data.root)
    var specifier = KeySpecifier.parse(text)
    var extracted = List[Int]()
    for ref path in specifier.paths:
        extracted.append(extract_key_path(values, object, path))
    return values.stringify(
        collect_specifier_paths(values, specifier.paths, extracted)
    )


def test_collect_specifier_paths_works_for_various_specifiers() raises:
    assert_equal(_collect("[]"), "{}")
    assert_equal(_collect('["a", "h"]'), '{"a":123,"h":789}')
    assert_equal(_collect('["h", "a", "bogus"]'), '{"h":789,"a":123}')
    assert_equal(_collect('["b", ["d", ["e"]]]'), '{"b":{"d":{"e":456}}}')
    assert_equal(
        _collect('["b", ["d", ["e"]], "a"]'), '{"b":{"d":{"e":456}},"a":123}'
    )
    assert_equal(
        _collect('["b", ["g", "d"], "a"]'),
        '{"b":{"g":678,"d":{"e":456,"f":567}},"a":123}',
    )
    assert_equal(
        _collect('["b", "a"]'),
        '{"b":{"c":234,"d":{"e":456,"f":567},"g":678},"a":123}',
    )


def test_extract_key_path_handles_arrays() raises:
    var values = Values()
    var data = json(
        '{"extra": "read about it elsewhere", "array": [{"value": 1, "a":'
        ' "should be first"}, {"value": 2, "x": "should come after value"},'
        ' {"z": "should come last", "value": 3}], "more": "another word for'
        ' extra"}'
    )
    var object = values.from_json(data, data.root)
    var path: List[String] = ["array", "value"]
    assert_equal(
        values.stringify(extract_key_path(values, object, path)), "[1,2,3]"
    )
    var specifier = KeySpecifier.parse('["array", ["value", "a", "x", "z"]]')
    var extracted = List[Int]()
    for ref inner in specifier.paths:
        assert_equal(len(inner), 2)
        assert_equal(inner[0], "array")
        extracted.append(extract_key_path(values, object, inner))
    # `undefined` items stringify as `null`, as `JSON.stringify` writes
    # them.
    assert_equal(
        values.stringify(
            collect_specifier_paths(values, specifier.paths, extracted)
        ),
        (
            '{"array":{"value":[1,2,3],"a":["should be'
            ' first",null,null],"x":[null,"should come after'
            ' value",null],"z":[null,null,"should come last"]}}'
        ),
    )
    var underspecified: List[String] = ["array"]
    var found = extract_key_path(values, object, underspecified)
    var text = values.stringify(found)
    assert_equal(
        text,
        (
            '[{"a":"should be first","value":1},{"value":2,"x":"should come'
            ' after value"},{"value":3,"z":"should come last"}]'
        ),
    )
    var array = values.get(object, "array")
    assert_equal(text, values.canonical_stringify(array))
    assert_equal(values.equal(found, array), True)


def test_from_paths_matches_the_specifier_text() raises:
    var paths: List[String] = ["title", "author.name"]
    var specifier = KeySpecifier.from_paths(paths)
    assert_equal(_paths_text(specifier), "title|author.name")
    assert_equal(specifier.text, '["title","author",["name"]]')
    assert_equal(
        KeySpecifier.parse('["title", "author", ["name"]]').text,
        '["title","author",["name"]]',
    )
    var bad: List[String] = ["a..b"]
    with assert_raises(contains="Invalid key specifier path: a..b"):
        _ = KeySpecifier.from_paths(bad)


def test_parse_refuses_what_is_not_a_specifier() raises:
    with assert_raises(contains="Invalid key specifier"):
        _ = KeySpecifier.parse("[")
    with assert_raises(contains="A key specifier must be an array"):
        _ = KeySpecifier.parse('"a"')
    with assert_raises(contains="A key specifier holds only names and arrays"):
        _ = KeySpecifier.parse('["a", 1]')


def test_parse_reads_an_array_that_follows_no_name() raises:
    # `getSpecifierPaths` adds the paths of such an array as they are.
    var leading = KeySpecifier.parse('[["a"]]')
    assert_equal(len(leading.paths), 1)
    assert_equal(leading.paths[0][0], "a")
    var mixed = KeySpecifier.parse('["x", ["a"], ["b", "c"]]')
    assert_equal(len(mixed.paths), 3)
    assert_equal(".".join(mixed.paths[0]), "x.a")
    assert_equal(".".join(mixed.paths[1]), "b")
    assert_equal(".".join(mixed.paths[2]), "c")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

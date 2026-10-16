# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Round trips: `stringify(parse(text))` against Node.js 22.14.0
`JSON.stringify(JSON.parse(text))`.

The inputs are the `y_` files of the JSONTestSuite and the files of
`fixtures/roundtrip/`. Node.js wrote `fixtures/expected/` (compact) and
`fixtures/expected-pretty/` (`JSON.stringify(value, null, 2)`) once; see
`fixtures/README.md`.

Two `y_` files differ by design. `JSON.parse` keeps one member for a
duplicated key; `gql_json` keeps every member in source order (see the
`gql_json.value` differences). Their own tests below check the
`gql_json` output.
"""

from std.testing import TestSuite, assert_equal, assert_true

from _fixtures import fixture_names, must_parse, read_fixture
from gql_json.parser import parse_bytes
from gql_json.value import JsonDocument
from gql_json.writer import stringify, stringify_bytes

comptime DUPLICATE_KEYS: Array[StaticString, 2] = [
    "y_object_duplicated_key.json",
    "y_object_duplicated_key_and_value.json",
]
"""The `y_` files whose output differs from `JSON.parse` by design."""


def _source(name: String) raises -> List[UInt8]:
    if name.startswith("y_"):
        return read_fixture("test_parsing/" + name)
    return read_fixture("roundtrip/" + name)


def _is_exception(name: String) -> Bool:
    var names = materialize[DUPLICATE_KEYS]()
    return name == names[0] or name == names[1]


def _document(name: String) raises -> JsonDocument:
    try:
        return parse_bytes(_source(name))
    except e:
        raise Error(String(name, ": ", e))


def _compare(directory: String, indent: Int) raises:
    var count = 0
    for name in fixture_names(directory):
        if _is_exception(name):
            continue
        var document = _document(name)
        var expected = read_fixture(directory + "/" + name)
        var got = stringify_bytes(document, document.root, indent)
        if got != expected:
            raise Error(
                String(
                    name,
                    ": got ",
                    String(unsafe_from_utf8=got),
                    " expected ",
                    String(unsafe_from_utf8=expected),
                )
            )
        count += 1
    assert_true(count >= 100)


def test_compact_output_matches_node() raises:
    _compare("expected", 0)


def test_pretty_output_matches_node() raises:
    _compare("expected-pretty", 2)


def test_duplicate_keys_are_all_kept() raises:
    var document = _document("y_object_duplicated_key.json")
    assert_equal(stringify(document, document.root), '{"a":"b","a":"c"}')
    var same = _document("y_object_duplicated_key_and_value.json")
    assert_equal(stringify(same, same.root), '{"a":"b","a":"b"}')
    # A lookup finds the last member, the one JSON.parse keeps.
    var found = document.find(document.root, "a")
    assert_equal(document.string_value(found), "c")


def test_stringify_and_stringify_bytes_agree() raises:
    var document = must_parse('{"k": [1, "two", 3.5]}')
    var text = stringify(document, document.root, 4)
    var bytes = stringify_bytes(document, document.root, 4)
    assert_equal(text, String(unsafe_from_utf8=bytes))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

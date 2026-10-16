# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Smoke tests of `InMemoryCache`, against Apollo Client 4.3.3 output."""

from gql_client.cache import InMemoryCache
from gql_json.parser import parse as parse_json
from gql_json.writer import stringify
from gql_language.parser import parse
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_write_extract_read() raises:
    var cache = InMemoryCache()
    var query = parse(
        "query { a(x: 1, b: {z: 2, y: [1,2]}) { __typename id name } list {"
        " id __typename value } plain { k } }"
    )
    var data = parse_json(
        '{"a": {"__typename": "T", "id": 1, "name": "n"}, "list": [{"id": 2,'
        ' "__typename": "U", "value": 1.5e21}], "plain": {"k": "x"}}'
    )
    _ = cache.write_query(query, data)
    assert_equal(
        cache.extract(),
        '{"T:1":{"__typename":"T","id":1,"name":"n"},"U:2":{"__typename":"U","id":2,"value":1.5e+21},"ROOT_QUERY":{"__typename":"Query","a({\\"b\\":{\\"y\\":[1,2],\\"z\\":2},\\"x\\":1})":{"__ref":"T:1"},"list":[{"__ref":"U:2"}],"plain":{"k":"x"}}}',
    )
    var result = cache.read_query(query)
    assert_true(Bool(result))
    var document = result.value().copy()
    assert_equal(
        stringify(document, document.root),
        '{"a":{"__typename":"T","id":1,"name":"n"},"list":[{"__typename":"U","id":2,"value":1.5e+21}],"plain":{"k":"x"}}',
    )
    var diff = cache.diff(
        parse("{ a(x:1, b:{z:2,y:[1,2]}) { id missing } nope }")
    )
    assert_false(diff.complete)
    assert_true(Bool(diff.missing))
    assert_equal(
        diff.missing.value().message,
        "Can't find field 'missing' on T:1 object",
    )
    ref tree = diff.missing.value().missing
    assert_equal(
        stringify(tree, tree.root),
        (
            '{"a":{"missing":"Can\'t find field \'missing\' on T:1'
            ' object"},"nope":"Can\'t find field \'nope\' on ROOT_QUERY'
            ' object"}'
        ),
    )
    var partial = diff.result.value().copy()
    assert_equal(
        stringify(partial, partial.root), '{"a":{"__typename":"T","id":1}}'
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

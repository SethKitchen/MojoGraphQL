# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Helpers of the gql_client tests.

Upstream compares values with `toEqual`, which does not look at the order
of keys. `same_json` compares two JSON texts the same way: it sorts the
keys of both. `assert_extract` compares `cache.extract()` with that rule,
and `assert_extract_exact` compares the bytes.
"""

from gql_client.cache import InMemoryCache
from gql_client.values import Values
from gql_json.parser import parse as parse_json
from gql_json.value import JsonDocument, NO_NODE
from gql_json.writer import stringify
from gql_language.ast import Document
from gql_language.parser import parse
from std.testing import assert_equal


def gql(text: StringSlice) raises -> Document:
    """Parse a GraphQL document, with a plain `Error` on failure."""
    try:
        return parse(text)
    except e:
        raise Error(String(e))


def json(text: StringSlice) raises -> JsonDocument:
    """Parse a JSON text, with a plain `Error` on failure."""
    try:
        return parse_json(text)
    except e:
        raise Error(String(e))


def canonical(text: StringSlice) raises -> String:
    """Return a JSON text with the keys of every object sorted."""
    var document = json(text)
    var values = Values()
    return values.canonical_stringify(values.from_json(document, document.root))


def text_of(document: JsonDocument) -> String:
    """Return the JSON text of a document's root."""
    return stringify(document, document.root)


def assert_json(document: JsonDocument, expected: StringSlice) raises:
    """Assert that a document equals a JSON text, in any key order."""
    assert_equal(canonical(text_of(document)), canonical(expected))


def assert_extract(mut cache: InMemoryCache, expected: StringSlice) raises:
    """Assert that `extract` equals a JSON text, in any key order."""
    assert_equal(canonical(cache.extract()), canonical(expected))


def assert_extract_exact(
    mut cache: InMemoryCache, expected: StringSlice
) raises:
    """Assert that `extract` is exactly a JSON text."""
    assert_equal(cache.extract(), String(expected))


def read_text(
    mut cache: InMemoryCache,
    query: Document,
    variables: StringSlice = "{}",
    id: StringSlice = "ROOT_QUERY",
) raises -> String:
    """Return the `readQuery` result as JSON text, or `null`."""
    var result = cache.read_query(query, json(variables), id)
    if not result:
        return "null"
    return text_of(result.value())


def assert_read(
    mut cache: InMemoryCache,
    query: Document,
    expected: StringSlice,
    variables: StringSlice = "{}",
    id: StringSlice = "ROOT_QUERY",
) raises:
    """Assert that `readQuery` gives a JSON text, in any key order."""
    var text = read_text(cache, query, variables, id)
    if expected == "null" or text == "null":
        assert_equal(text, String(expected))
    else:
        assert_equal(canonical(text), canonical(expected))


def write(
    mut cache: InMemoryCache,
    query: StringSlice,
    data: StringSlice,
    variables: StringSlice = "{}",
) raises -> String:
    """Write a query result given as texts; return the written id."""
    return cache.write_query(gql(query), json(data), json(variables))


def raises_message(message: StringSlice, expected: StringSlice) raises:
    """Assert that an error message is the expected one."""
    assert_equal(String(message), String(expected))


def assert_read_exact(
    mut cache: InMemoryCache,
    query: Document,
    expected: StringSlice,
    variables: StringSlice = "{}",
    id: StringSlice = "ROOT_QUERY",
) raises:
    """Assert that `readQuery` gives exactly a JSON text."""
    assert_equal(read_text(cache, query, variables, id), String(expected))

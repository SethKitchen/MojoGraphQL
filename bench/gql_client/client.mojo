# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The InMemoryCache workloads, against Apollo Client 4.3.3.

The workloads are the ones of `bench/baselines/js-client/bench.mjs`, on
the fixture `client-items-1000.json`: 1000 `Item` entities, each with an
`Author` entity and an embedded `Stats` object. Apollo Client publishes no
runtime benchmark of its cache at 4.3.3, so these workloads are the
project's own.

- `client/write-new-items-1000`: a new cache, then `writeQuery`.
- `client/write-merge-items-1000`: `writeQuery` of the same data into a
  cache that holds it.
- `client/read-items-1000`: `readQuery` of the 1000 items.
- `client/diff-partial-items-1000`: `diff` of a query with a field that
  no item has, so each item reports a missing field.
- `client/extract-items-1000`: the JSON text of `extract()`.
- `client/restore-items-1000`: `restore` from that JSON text.
- `client/read-fragment`: `readFragment` of one item.
- `client/identify`: `identify` of one object.
"""

from gql_client.cache import InMemoryCache
from gql_json.value import JsonDocument
from gql_language.ast import Document

from _harness import Workload, document, fixture_json, measure

comptime QUERY = (
    "query Items { items { id title price inStock tags author { id name }"
    " stats { views likes } } }"
)
"""The query of the fixture."""
comptime PARTIAL_QUERY = (
    "query Items { items { id title price inStock tags rating author { id"
    " name } stats { views likes } } }"
)
"""The query with the field `rating`, which no item has."""
comptime FRAGMENT = (
    "fragment ItemFields on Item { id title price author { name } }"
)
"""The fragment of `client/read-fragment`."""


def _filled(query: Document, data: JsonDocument) raises -> InMemoryCache:
    """Return a cache that holds the fixture."""
    var cache = InMemoryCache()
    _ = cache.write_query(query, data)
    return cache^


struct WriteNew(Movable, Workload):
    """`new InMemoryCache()` and `writeQuery` of the fixture."""

    var query: Document
    """The query."""
    var data: JsonDocument
    """The fixture."""

    def __init__(out self) raises:
        """Parse the query and the fixture.

        Raises:
            Error: If a parse fails.
        """
        self.query = document(QUERY)
        self.data = fixture_json("client-items-1000.json")

    def run(mut self) raises -> Int:
        """Write into a new cache.

        Returns:
            The length of the written id.

        Raises:
            Error: If the write fails.
        """
        var cache = InMemoryCache()
        return cache.write_query(self.query, self.data).byte_length()


struct WriteMerge(Movable, Workload):
    """`writeQuery` of the fixture into a cache that holds it."""

    var query: Document
    """The query."""
    var data: JsonDocument
    """The fixture."""
    var cache: InMemoryCache
    """The cache."""

    def __init__(out self) raises:
        """Fill the cache.

        Raises:
            Error: If a parse or the first write fails.
        """
        self.query = document(QUERY)
        self.data = fixture_json("client-items-1000.json")
        self.cache = _filled(self.query, self.data)

    def run(mut self) raises -> Int:
        """Write again.

        Returns:
            The length of the written id.

        Raises:
            Error: If the write fails.
        """
        return self.cache.write_query(self.query, self.data).byte_length()


struct Read(Movable, Workload):
    """`readQuery` of the fixture's query."""

    var query: Document
    """The query."""
    var cache: InMemoryCache
    """The cache."""

    def __init__(out self) raises:
        """Fill the cache.

        Raises:
            Error: If a parse or the write fails.
        """
        self.query = document(QUERY)
        self.cache = _filled(self.query, fixture_json("client-items-1000.json"))

    def run(mut self) raises -> Int:
        """Read.

        Returns:
            The number of nodes of the result.

        Raises:
            Error: If the read fails.
        """
        var result = self.cache.read_query(self.query)
        return len(result.value().nodes)


struct DiffPartial(Movable, Workload):
    """`diff` of a query with a field that no item has."""

    var query: Document
    """The partial query."""
    var cache: InMemoryCache
    """The cache."""

    def __init__(out self) raises:
        """Fill the cache.

        Raises:
            Error: If a parse or the write fails.
        """
        self.query = document(PARTIAL_QUERY)
        self.cache = _filled(
            document(QUERY), fixture_json("client-items-1000.json")
        )

    def run(mut self) raises -> Int:
        """Diff.

        Returns:
            The length of the missing field message.

        Raises:
            Error: If the diff fails.
        """
        var diff = self.cache.diff(self.query)
        return diff.missing.value().message.byte_length()


struct Extract(Movable, Workload):
    """The JSON text of `extract()`."""

    var cache: InMemoryCache
    """The cache."""

    def __init__(out self) raises:
        """Fill the cache.

        Raises:
            Error: If a parse or the write fails.
        """
        self.cache = _filled(
            document(QUERY), fixture_json("client-items-1000.json")
        )

    def run(mut self) raises -> Int:
        """Extract.

        Returns:
            The length of the text.

        Raises:
            Error: Never.
        """
        return self.cache.extract().byte_length()


struct Restore(Movable, Workload):
    """`restore` from the JSON text of `extract()`."""

    var text: String
    """The extracted text."""
    var cache: InMemoryCache
    """The cache that restores."""

    def __init__(out self) raises:
        """Extract the text once.

        Raises:
            Error: If a parse or the write fails.
        """
        var filled = _filled(
            document(QUERY), fixture_json("client-items-1000.json")
        )
        self.text = filled.extract()
        self.cache = InMemoryCache()

    def run(mut self) raises -> Int:
        """Restore.

        Returns:
            1.

        Raises:
            Error: If the text is not valid.
        """
        self.cache.restore_text(self.text)
        return 1


struct ReadFragment(Movable, Workload):
    """`readFragment` of one item."""

    var fragment: Document
    """The fragment."""
    var cache: InMemoryCache
    """The cache."""

    def __init__(out self) raises:
        """Fill the cache.

        Raises:
            Error: If a parse or the write fails.
        """
        self.fragment = document(FRAGMENT)
        self.cache = _filled(
            document(QUERY), fixture_json("client-items-1000.json")
        )

    def run(mut self) raises -> Int:
        """Read the fragment.

        Returns:
            The number of nodes of the result.

        Raises:
            Error: If the read fails.
        """
        var result = self.cache.read_fragment(self.fragment, "Item:500")
        return len(result.value().nodes)


struct Identify(Movable, Workload):
    """`identify` of one object."""

    var object: JsonDocument
    """The object."""
    var cache: InMemoryCache
    """The cache."""

    def __init__(out self) raises:
        """Parse the object.

        Raises:
            Error: If the object is not JSON.
        """
        from gql_json.parser import parse as parse_json

        self.object = parse_json(
            '{"__typename": "Item", "id": "500", "title": "Item number 500"}'
        )
        self.cache = InMemoryCache()

    def run(mut self) raises -> Int:
        """Identify.

        Returns:
            The length of the id.

        Raises:
            Error: Never.
        """
        return self.cache.identify(self.object).value().byte_length()


def main() raises:
    """Run the workloads."""
    measure("client/write-new-items-1000", WriteNew())
    measure("client/write-merge-items-1000", WriteMerge())
    measure("client/read-items-1000", Read())
    measure("client/diff-partial-items-1000", DiffPartial())
    measure("client/extract-items-1000", Extract())
    measure("client/restore-items-1000", Restore())
    measure("client/read-fragment", ReadFragment())
    measure("client/identify", Identify())

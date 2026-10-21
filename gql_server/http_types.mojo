# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The HTTP types of the server: header maps, heads, requests and
responses.

Port of Apollo Server 5.5.1 `utils/HeaderMap.ts`, `externalTypes/http.ts`,
and `newHTTPGraphQLHead` and `mergeHTTPGraphQLHead` of `runHttpQuery.ts`.

**Differences from upstream.**
- `HTTPGraphQLHead.status` is `0` where upstream has `undefined`. Upstream
  ignores a status of `0` too.
- `HTTPGraphQLRequest.body` is a `JsonDocument`. A document with no root
  is the `undefined` body of upstream.
- A `chunked` body is its first chunk in `body`, and the
  `IncrementalResults` that make the later chunks. The server writes each
  later chunk from them; upstream holds an async iterator of strings.
"""

from std.memory import ArcPointer

from gql_json.value import JsonDocument
from gql_server.incremental import IncrementalResults


def _lower(byte: UInt8) -> UInt8:
    return byte + 32 if byte >= 65 and byte <= 90 else byte


def lower_ascii(text: StringSlice) -> String:
    """Return text with the ASCII capital letters in lowercase.

    Args:
        text: The text, such as a header name.

    Returns:
        The lowercase text.
    """
    var bytes = text.as_bytes()
    var out = List[UInt8](capacity=len(bytes))
    var index = 0
    while index < len(bytes):
        out.append(_lower(bytes[index]))
        index += 1
    return String(unsafe_from_utf8=out)


struct HeaderMap(Copyable, Movable, Sized):
    """A map of HTTP header fields with lowercase names, in insertion
    order: upstream `HeaderMap`."""

    var names: List[String]
    """The lowercase names."""
    var values: List[String]
    """The values, by the position of their names."""

    def __init__(out self):
        """Make an empty map."""
        self.names = List[String]()
        self.values = List[String]()

    def find(self, name: StringSlice) -> Int:
        """Return the position of a field.

        Args:
            name: The name, in any case.

        Returns:
            The position, or -1 when the map has no such field.
        """
        var wanted = name.as_bytes()
        var index = 0
        while index < len(self.names):
            var have = self.names[index].as_bytes()
            if len(have) == len(wanted):
                var at = 0
                while at < len(have) and have[at] == _lower(wanted[at]):
                    at += 1
                if at == len(have):
                    return index
            index += 1
        return -1

    def set(mut self, name: StringSlice, value: StringSlice):
        """Set a field. A field that exists keeps its position, as a
        JavaScript `Map` does.

        Args:
            name: The name, in any case.
            value: The value.
        """
        var index = self.find(name)
        if index >= 0:
            self.values[index] = String(value)
            return
        self.names.append(lower_ascii(name))
        self.values.append(String(value))

    def get(self, name: StringSlice) -> Optional[String]:
        """Return the value of a field.

        Args:
            name: The name, in any case.

        Returns:
            The value, or None when the map has no such field.
        """
        var index = self.find(name)
        if index < 0:
            return None
        return self.values[index].copy()

    def has(self, name: StringSlice) -> Bool:
        """Return True if the map has a field.

        Args:
            name: The name, in any case.

        Returns:
            Whether the field is in the map.
        """
        return self.find(name) >= 0

    def delete(mut self, name: StringSlice) -> Bool:
        """Remove a field.

        Args:
            name: The name, in any case.

        Returns:
            Whether the field was in the map.
        """
        var index = self.find(name)
        if index < 0:
            return False
        _ = self.names.pop(index)
        _ = self.values.pop(index)
        return True

    def __len__(self) -> Int:
        """Return the count of fields.

        Returns:
            The count.
        """
        return len(self.names)


struct HTTPGraphQLHead(Copyable, Movable):
    """The status and the header fields of a response: upstream
    `HTTPGraphQLHead`."""

    var status: Int
    """The status code, or `0` when it is not set."""
    var headers: HeaderMap
    """The header fields."""

    def __init__(out self, status: Int = 0):
        """Make a head, as `newHTTPGraphQLHead(status)`.

        Args:
            status: The status code, or `0` for none.
        """
        self.status = status
        self.headers = HeaderMap()


def new_http_graphql_head(status: Int = 0) -> HTTPGraphQLHead:
    """Make a head with no fields: upstream `newHTTPGraphQLHead`.

    Args:
        status: The status code, or `0` for none.

    Returns:
        The head.
    """
    return HTTPGraphQLHead(status)


def merge_http_graphql_head(
    mut target: HTTPGraphQLHead, source: HTTPGraphQLHead
):
    """Copy the status and the fields of one head into another: upstream
    `mergeHTTPGraphQLHead`.

    Args:
        target: The head to update.
        source: The head to copy; a status of `0` is not copied.
    """
    if source.status != 0:
        target.status = source.status
    var index = 0
    while index < len(source.headers):
        target.headers.set(
            source.headers.names[index], source.headers.values[index]
        )
        index += 1


struct HTTPGraphQLRequest(Copyable, Movable):
    """An HTTP request for the server: upstream `HTTPGraphQLRequest`."""

    var method: String
    """The method in uppercase, such as `POST`."""
    var headers: HeaderMap
    """The header fields."""
    var search: String
    """The query string with its `?`, or empty."""
    var body: JsonDocument
    """The parsed JSON content; no root when there is none."""

    def __init__(out self, method: StringSlice):
        """Make a request with no fields, no query string and no content.

        Args:
            method: The method in uppercase.
        """
        self.method = String(method)
        self.headers = HeaderMap()
        self.search = String("")
        self.body = JsonDocument()


struct HTTPGraphQLResponse(Movable):
    """An HTTP response of the server: upstream `HTTPGraphQLResponse` with
    a complete body."""

    var status: Int
    """The status code, or `0` for 200."""
    var headers: HeaderMap
    """The header fields."""
    var body: String
    """The content; for a `chunked` body, its first chunk."""
    var chunks: Optional[ArcPointer[IncrementalResults]]
    """For a `chunked` body: the results that make the later chunks."""

    def __init__(out self, var head: HTTPGraphQLHead, var body: String):
        """Make a response.

        Args:
            head: The status and the fields.
            body: The content.
        """
        self.status = head.status
        self.headers = HeaderMap()
        swap(self.headers, head.headers)
        self.body = body^
        self.chunks = None

    def is_chunked(self) -> Bool:
        """Return True for a `chunked` body: upstream
        `body.kind === 'chunked'`.

        Returns:
            Whether chunks follow `body`.
        """
        return Bool(self.chunks)

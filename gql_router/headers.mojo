# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""HTTP response headers for the router.

Port of `append_vary` in Hive Router `1a29df9`
`bin/router/src/http_utils/headers.rs`.

A `Vary` token that is already present, ignoring ASCII case, is left
alone. A new token is appended after a comma and a space.
"""


struct HeaderMap:
    """A list of HTTP headers. Lookup ignores ASCII case in the name."""

    var _names: List[String]
    """Header names, in insertion order."""
    var _values: List[String]
    """Header values, parallel to `_names`."""

    def __init__(out self):
        """Start an empty header map."""
        self._names = List[String]()
        self._values = List[String]()

    def get(self, name: String) -> Optional[String]:
        """Return the last value of a header.

        Args:
            name: The header name.

        Returns:
            The value, or none when the header is absent.
        """
        var found = -1
        for index in range(len(self._names)):
            if _same_name(self._names[index], name):
                found = index
        if found < 0:
            return None
        return String(self._values[found])

    def insert(mut self, name: String, value: String):
        """Set a header, replacing an existing name.

        Args:
            name: The header name.
            value: The header value.
        """
        for index in range(len(self._names)):
            if _same_name(self._names[index], name):
                self._values[index] = value
                return
        self._names.append(name)
        self._values.append(value)

    def append_value(mut self, name: String, value: String):
        """Add a header value without replacing an existing name.

        Args:
            name: The header name.
            value: The header value.
        """
        self._names.append(name)
        self._values.append(value)

    def remove(mut self, name: String):
        """Remove every value of a header.

        Args:
            name: The header name.
        """
        var names = List[String]()
        var values = List[String]()
        for index in range(len(self._names)):
            if _same_name(self._names[index], name):
                continue
            names.append(String(self._names[index]))
            values.append(String(self._values[index]))
        self._names = names^
        self._values = values^

    def values_of(self, name: String) -> List[String]:
        """Return every value of a header, in insertion order.

        Args:
            name: The header name.

        Returns:
            The values. Empty when the header is absent.
        """
        var values = List[String]()
        for index in range(len(self._names)):
            if _same_name(self._names[index], name):
                values.append(String(self._values[index]))
        return values^

    def joined(self) -> String:
        """Return the headers as `name: value`, separated by ` | `.

        Returns:
            The header text, in insertion order.
        """
        var text = String("")
        var limit = len(self._names)
        if len(self._values) < limit:
            limit = len(self._values)
        for index in range(limit):
            if index > 0:
                text += " | "
            text += self._names[index]
            text += ": "
            text += self._values[index]
        return text^


def append_vary(mut headers: HeaderMap, token: String):
    """Add a token to the `Vary` header when it is not already there.

    Args:
        headers: The response headers.
        token: One `Vary` token, such as `Accept`.
    """
    var existing = headers.get("vary")
    if existing:
        var text = existing.value()
        if _has_token(text, token):
            return
        if text.byte_length() == 0:
            headers.insert("vary", token)
        else:
            headers.insert("vary", text + ", " + token)
        return
    headers.insert("vary", token)


def _same_name(left: String, right: String) -> Bool:
    """Return True when two header names match, ignoring ASCII case.

    Args:
        left: One header name.
        right: The other header name.

    Returns:
        Whether the names are equal.
    """
    if left.byte_length() != right.byte_length():
        return False
    var a = left.as_bytes()
    var b = right.as_bytes()
    for index in range(len(a)):
        if _lower(a[index]) != _lower(b[index]):
            return False
    return True


def _lower(byte: UInt8) -> UInt8:
    """Return the ASCII lowercase of a byte.

    Args:
        byte: One byte.

    Returns:
        The lowercase byte.
    """
    if byte >= 65 and byte <= 90:
        return byte + 32
    return byte


def _has_token(header: String, token: String) -> Bool:
    """Return True when a comma-separated header already holds a token.

    Args:
        header: The current header value.
        token: The token to find.

    Returns:
        Whether a trimmed item equals `token`, ignoring ASCII case.
    """
    var bytes = header.as_bytes()
    var start = 0
    var index = 0
    while index <= len(bytes):
        var boundary = index == len(bytes) or bytes[index] == 44
        if boundary:
            var item = String(header[byte=start:index])
            var trimmed = _trim(item)
            if _same_name(trimmed, token):
                return True
            start = index + 1
        index += 1
    return False


def _trim(text: String) -> String:
    """Drop ASCII spaces from both ends of a token.

    Args:
        text: One comma-separated item.

    Returns:
        The item without leading or trailing spaces.
    """
    var bytes = text.as_bytes()
    var start = 0
    var end = len(bytes)
    while start < end and bytes[start] == 32:
        start += 1
    while end > start and bytes[end - 1] == 32:
        end -= 1
    return String(text[byte=start:end])

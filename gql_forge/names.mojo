# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Names and URLs that Forge accepts.

An organization slug, a graph ref and a variant name use the same rules:
they start with an ASCII letter, and they have only ASCII letters, digits,
`_` and `-`. An endpoint URL starts with `http://` or `https://` and has
a host.

Differences from upstream: none; there is no upstream.
"""

from gql_http.random import random_u64
from gql_language.scan import string_from_utf8


def is_valid_slug(name: StringSlice) -> Bool:
    """Return True for an organization, graph or variant name.

    Args:
        name: The slug.

    Returns:
        Whether it starts with a letter, has only letters, digits, `_`
        and `-`, and has at most 64 bytes.
    """
    var bytes = name.as_bytes()
    if len(bytes) == 0 or len(bytes) > 64:
        return False
    for index in range(len(bytes)):
        var byte = bytes[index]
        var letter = (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122)
        if index == 0 and not letter:
            return False
        var digit = byte >= 48 and byte <= 57
        if not (letter or digit or byte == 95 or byte == 45):
            return False
    return True


def is_valid_endpoint_url(url: StringSlice) -> Bool:
    """Return True for a customer graph URL that Forge can record.

    Live pulls use `http://` only. A customer can still register
    `https://` and upload SDL.

    Args:
        url: The URL.

    Returns:
        Whether it starts with `http://` or `https://` and has a host.
    """
    if url.startswith("http://"):
        return url.byte_length() > 7
    if url.startswith("https://"):
        return url.byte_length() > 8
    return False


def is_http_endpoint(url: StringSlice) -> Bool:
    """Return True when Forge can pull the schema over `gql_http`.

    Args:
        url: The URL.

    Returns:
        Whether it starts with `http://` and has a host.
    """
    return url.startswith("http://") and url.byte_length() > 7


def slug_error(kind: StringSlice, name: StringSlice) -> String:
    """Return the error for a slug that is not valid.

    Args:
        kind: `organization`, `graph` or `variant`.
        name: The slug.

    Returns:
        One sentence that names the value and the rule.
    """
    return (
        "Invalid "
        + String(kind)
        + " name '"
        + String(name)
        + "': it must start with a letter and have only letters, digits, '_'"
        " and '-'."
    )


def endpoint_error(url: StringSlice) -> String:
    """Return the error for an endpoint URL that is not valid.

    Args:
        url: The URL.

    Returns:
        One sentence that names the value and the rule.
    """
    return (
        "Invalid endpoint URL '"
        + String(url)
        + "': it must start with http:// or https://."
    )


def ascii_lower(text: StringSlice) -> String:
    """Return ASCII letters in lowercase. Other bytes stay the same.

    Args:
        text: The text.

    Returns:
        The folded text.
    """
    var bytes = List[UInt8](capacity=text.byte_length())
    for byte in text.as_bytes():
        if byte >= 65 and byte <= 90:
            bytes.append(byte + 32)
        else:
            bytes.append(byte)
    return string_from_utf8(Span(bytes))


def contains_folded(haystack: StringSlice, needle: StringSlice) -> Bool:
    """Return True when `haystack` holds `needle`, ASCII case folded.

    Args:
        haystack: The text to search.
        needle: The text to find. An empty needle is never found.

    Returns:
        Whether the needle occurs.
    """
    if needle.byte_length() == 0:
        return False
    return ascii_lower(haystack).find(ascii_lower(needle)) >= 0


def hex16(value: UInt64) -> String:
    """Write a 64-bit value as 16 lowercase hex digits.

    Args:
        value: The value.

    Returns:
        Sixteen hex digits, most significant first.
    """
    comptime digits = "0123456789abcdef"
    var table = digits.as_bytes()
    var out = List[UInt8](capacity=16)
    var shift = 60
    while shift >= 0:
        out.append(table[Int((value >> UInt64(shift)) & 15)])
        shift -= 4
    return string_from_utf8(Span(out))


def make_ingest_token() -> String:
    """Make a bearer token that a customer router sends with telemetry.

    The token holds 128 random bits from the operating system, so nobody
    can derive it from the names of the variant.

    Returns:
        `frg_` and 32 hex digits.
    """
    return "frg_" + hex16(random_u64()) + hex16(random_u64())


def tokens_equal(given: StringSlice, expected: StringSlice) -> Bool:
    """Compare a token with the expected token in constant time.

    The time depends on the lengths only, not on the first byte that
    differs, so a client cannot find the token one byte at a time.

    Args:
        given: The token that the client sent.
        expected: The token that Forge issued.

    Returns:
        Whether the two tokens have the same bytes.
    """
    var left = given.as_bytes()
    var right = expected.as_bytes()
    var diff = len(left) ^ len(right)
    for index in range(min(len(left), len(right))):
        diff |= Int(left[index] ^ right[index])
    return diff == 0


def sort_strings(mut names: List[String]):
    """Sort strings in place, by unsigned byte order.

    Args:
        names: The list.
    """
    var i = 1
    while i < len(names):
        var j = i
        while j > 0 and _less(names[j], names[j - 1]):
            var tmp = names[j].copy()
            names[j] = names[j - 1].copy()
            names[j - 1] = tmp^
            j -= 1
        i += 1


def _less(left: StringSlice, right: StringSlice) -> Bool:
    """Return True when `left` is before `right` in byte order.

    Args:
        left: The first string.
        right: The second string.

    Returns:
        Whether `left` is strictly less than `right`.
    """
    var a = left.as_bytes()
    var b = right.as_bytes()
    var n = min(len(a), len(b))
    var index = 0
    while index < n:
        if a[index] < b[index]:
            return True
        if a[index] > b[index]:
            return False
        index += 1
    return len(a) < len(b)

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The QPACK static table (RFC 9204 Appendix A): 99 fields, indexed from 0.

The encoder looks up each field that it sends. `static_find` hashes the
name into a table of 256 slots that is built at compile time, and compares
the name once. The entries that share a name are linked, so the exact match
of the value walks only those entries.

This module ports `h3/src/qpack/static_.rs` of hyperium/h3 h3-v0.0.8
(22c1aa3), MIT.

Differences from upstream: upstream matches each pair with a `match` on
byte strings, and returns an `Option`. Here `static_find` returns the exact
match and the first entry with the name at once, or -1, from one hash.
"""

from std.builtin.globals import global_constant

comptime STATIC_TABLE_SIZE = 99
"""The number of entries."""

comptime _NAMES: Array[StaticString, 99] = [
    ":authority",
    ":path",
    "age",
    "content-disposition",
    "content-length",
    "cookie",
    "date",
    "etag",
    "if-modified-since",
    "if-none-match",
    "last-modified",
    "link",
    "location",
    "referer",
    "set-cookie",
    ":method",
    ":method",
    ":method",
    ":method",
    ":method",
    ":method",
    ":method",
    ":scheme",
    ":scheme",
    ":status",
    ":status",
    ":status",
    ":status",
    ":status",
    "accept",
    "accept",
    "accept-encoding",
    "accept-ranges",
    "access-control-allow-headers",
    "access-control-allow-headers",
    "access-control-allow-origin",
    "cache-control",
    "cache-control",
    "cache-control",
    "cache-control",
    "cache-control",
    "cache-control",
    "content-encoding",
    "content-encoding",
    "content-type",
    "content-type",
    "content-type",
    "content-type",
    "content-type",
    "content-type",
    "content-type",
    "content-type",
    "content-type",
    "content-type",
    "content-type",
    "range",
    "strict-transport-security",
    "strict-transport-security",
    "strict-transport-security",
    "vary",
    "vary",
    "x-content-type-options",
    "x-xss-protection",
    ":status",
    ":status",
    ":status",
    ":status",
    ":status",
    ":status",
    ":status",
    ":status",
    ":status",
    "accept-language",
    "access-control-allow-credentials",
    "access-control-allow-credentials",
    "access-control-allow-headers",
    "access-control-allow-methods",
    "access-control-allow-methods",
    "access-control-allow-methods",
    "access-control-expose-headers",
    "access-control-request-headers",
    "access-control-request-method",
    "access-control-request-method",
    "alt-svc",
    "authorization",
    "content-security-policy",
    "early-data",
    "expect-ct",
    "forwarded",
    "if-range",
    "origin",
    "purpose",
    "server",
    "timing-allow-origin",
    "upgrade-insecure-requests",
    "user-agent",
    "x-forwarded-for",
    "x-frame-options",
    "x-frame-options",
]
"""The name of each entry."""

comptime _VALUES: Array[StaticString, 99] = [
    "",
    "/",
    "0",
    "",
    "0",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "CONNECT",
    "DELETE",
    "GET",
    "HEAD",
    "OPTIONS",
    "POST",
    "PUT",
    "http",
    "https",
    "103",
    "200",
    "304",
    "404",
    "503",
    "*/*",
    "application/dns-message",
    "gzip, deflate, br",
    "bytes",
    "cache-control",
    "content-type",
    "*",
    "max-age=0",
    "max-age=2592000",
    "max-age=604800",
    "no-cache",
    "no-store",
    "public, max-age=31536000",
    "br",
    "gzip",
    "application/dns-message",
    "application/javascript",
    "application/json",
    "application/x-www-form-urlencoded",
    "image/gif",
    "image/jpeg",
    "image/png",
    "text/css",
    "text/html; charset=utf-8",
    "text/plain",
    "text/plain;charset=utf-8",
    "bytes=0-",
    "max-age=31536000",
    "max-age=31536000; includesubdomains",
    "max-age=31536000; includesubdomains; preload",
    "accept-encoding",
    "origin",
    "nosniff",
    "1; mode=block",
    "100",
    "204",
    "206",
    "302",
    "400",
    "403",
    "421",
    "425",
    "500",
    "",
    "FALSE",
    "TRUE",
    "*",
    "get",
    "get, post, options",
    "options",
    "content-length",
    "content-type",
    "get",
    "post",
    "clear",
    "",
    "script-src 'none'; object-src 'none'; base-uri 'none'",
    "1",
    "",
    "",
    "",
    "",
    "prefetch",
    "",
    "*",
    "1",
    "",
    "",
    "deny",
    "sameorigin",
]
"""The value of each entry."""


@always_inline
def _hash(p: Pointer[UInt8, _], n: Int) -> Int:
    """Return the slot of a name of `n` bytes, `n` at least 1."""
    var mixed = n * 31 + Int(p[unsafe_offset=0]) * 7
    mixed += Int(p[unsafe_offset=n - 1]) * 3 + Int(p[unsafe_offset=n >> 1])
    return mixed & 255


def _build_slots() -> Array[Int8, 256]:
    """Return the hash slots: the first entry of each name, or -1."""
    var names = materialize[_NAMES]()
    var slots = Array[Int8, 256](fill=-1)
    var index = 0
    while index < STATIC_TABLE_SIZE:
        var name = names[index]
        var seen = False
        var j = 0
        while j < index:
            if names[j] == name:
                seen = True
            j += 1
        if not seen:
            var slot = _hash(name.unsafe_ptr(), name.byte_length())
            while slots[slot] >= 0:
                slot = (slot + 1) & 255
            slots[slot] = Int8(index)
        index += 1
    return slots^


def _build_next() -> Array[Int8, 99]:
    """Return, for each entry, the next entry with the same name, or -1."""
    var names = materialize[_NAMES]()
    var next = Array[Int8, 99](fill=-1)
    var index = 0
    while index < STATIC_TABLE_SIZE:
        var j = index + 1
        while j < STATIC_TABLE_SIZE:
            if names[j] == names[index]:
                next[index] = Int8(j)
                break
            j += 1
        index += 1
    return next^


comptime _SLOTS = _build_slots()
"""The hash slots of the names."""
comptime _NEXT = _build_next()
"""The links between the entries of one name."""


@fieldwise_init
struct StaticMatch(ImplicitlyCopyable, Writable):
    """The result of `static_find`."""

    var exact: Int
    """The entry with the name and the value, or -1."""
    var name: Int
    """The first entry with the name, or -1."""

    def write_to(self, mut writer: Some[Writer]):
        """Write both indexes.

        Args:
            writer: The destination.
        """
        writer.write("exact ", self.exact, " name ", self.name)


def static_name(index: Int) -> StaticString:
    """Return the name of an entry.

    Args:
        index: The index, from 0 to 98.

    Returns:
        The name.
    """
    ref names = global_constant[_NAMES]()
    return names[index]


def static_value(index: Int) -> StaticString:
    """Return the value of an entry.

    Args:
        index: The index, from 0 to 98.

    Returns:
        The value.
    """
    ref values = global_constant[_VALUES]()
    return values[index]


@always_inline
def _same(a: Span[UInt8, _], b: StaticString) -> Bool:
    """Compare bytes to a static string."""
    return StringSlice(unsafe_from_utf8=a) == b


@always_inline
def static_find_name(name: Span[UInt8, _]) -> Int:
    """Return the first entry with a name.

    Args:
        name: The name, in lowercase.

    Returns:
        The index, or -1.
    """
    var n = len(name)
    if n == 0:
        return -1
    ref names = global_constant[_NAMES]()
    ref slots = global_constant[_SLOTS]()
    var slot = _hash(name.unsafe_ptr(), n)
    while True:
        var index = Int(slots[slot])
        if index < 0:
            return -1
        if _same(name, names[index]):
            return index
        slot = (slot + 1) & 255


@always_inline
def static_find(name: Span[UInt8, _], value: Span[UInt8, _]) -> StaticMatch:
    """Return the entry with a name and a value, and the first with the name.

    Args:
        name: The name, in lowercase.
        value: The value.

    Returns:
        The two indexes; each is -1 when there is no such entry.
    """
    var first = static_find_name(name)
    if first < 0:
        return StaticMatch(-1, -1)
    ref values = global_constant[_VALUES]()
    ref next = global_constant[_NEXT]()
    var index = first
    while index >= 0:
        if _same(value, values[index]):
            return StaticMatch(index, first)
        index = Int(next[index])
    return StaticMatch(-1, first)

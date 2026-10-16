# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Percent-decoding, query strings and URLs.

`percent_decode` follows RFC 3986 section 2.1. `parse_query` reads
`application/x-www-form-urlencoded`, as the WHATWG URL standard defines it:
`&` separates pairs, the first `=` separates a name from its value, and `+`
is a space. `Url.parse` reads an absolute `http` URL of RFC 3986:
`scheme://[userinfo@]host[:port][/path][?query][#fragment]`.

This module ports no code.

Differences from upstream: none; there is no upstream. Unlike the WHATWG
parser, `percent_decode` refuses a `%` that two hexadecimal digits do not
follow, and a result that is not UTF-8, so a server can answer 400.
"""

from gql_http.error import ErrorKind, HttpError
from gql_http.scan import lower


def _invalid(message: String) -> HttpError:
    """Make a `PROTOCOL` error."""
    return HttpError(ErrorKind.PROTOCOL, message, 0)


def _hex(byte: UInt8) -> Int:
    """Return the value of a hexadecimal digit, or -1."""
    if byte >= 48 and byte <= 57:
        return Int(byte) - 48
    var folded = lower(byte)
    if folded >= 97 and folded <= 102:
        return Int(folded) - 87
    return -1


def percent_decode(
    text: StringSlice, plus_is_space: Bool = False
) raises HttpError -> String:
    """Decode `%XX` escapes.

    Args:
        text: The encoded text.
        plus_is_space: Whether `+` stands for a space, as in a form.

    Returns:
        The decoded text.

    Raises:
        HttpError: `PROTOCOL` for a `%` without two hexadecimal digits, or
            for decoded bytes that are not UTF-8.
    """
    var bytes = text.as_bytes()
    var n = len(bytes)
    var out = List[UInt8](capacity=n)
    var index = 0
    while index < n:
        var byte = bytes[index]
        if byte == 37:
            if index + 2 >= n:
                raise _invalid("truncated percent escape")
            var high = _hex(bytes[index + 1])
            var low = _hex(bytes[index + 2])
            if high < 0 or low < 0:
                raise _invalid("invalid percent escape")
            out.append(UInt8(high * 16 + low))
            index += 3
            continue
        if byte == 43 and plus_is_space:
            out.append(32)
        else:
            out.append(byte)
        index += 1
    try:
        return String(StringSlice(from_utf8=Span(out)))
    except:
        raise _invalid("percent escapes decode to invalid UTF-8")


@fieldwise_init
struct QueryParam(Copyable, Movable):
    """One `name=value` pair of a query string, decoded."""

    var name: String
    """The decoded name."""
    var value: String
    """The decoded value; empty when the pair has no `=`."""


def parse_query(query: StringSlice) raises HttpError -> List[QueryParam]:
    """Read a query string or a form body into its pairs.

    Empty pairs, as in `a=1&&b=2`, are skipped.

    Args:
        query: The text after `?`, without the `?`.

    Returns:
        The pairs, in order. A name can occur more than once.

    Raises:
        HttpError: `PROTOCOL` for an invalid percent escape.
    """
    var out = List[QueryParam]()
    var rest = query
    while rest.byte_length() > 0:
        var amp = rest.find("&")
        var pair = rest
        if amp < 0:
            rest = rest[byte = rest.byte_length() :]
        else:
            pair = rest[byte=:amp]
            rest = rest[byte = amp + 1 :]
        if pair.byte_length() == 0:
            continue
        var equals = pair.find("=")
        if equals < 0:
            out.append(QueryParam(percent_decode(pair, True), String()))
        else:
            out.append(
                QueryParam(
                    percent_decode(pair[byte=:equals], True),
                    percent_decode(pair[byte = equals + 1 :], True),
                )
            )
    return out^


def query_value(
    params: List[QueryParam], name: StringSlice
) -> Optional[String]:
    """Return the value of the first pair with a name.

    Args:
        params: The pairs that `parse_query` returned.
        name: The decoded name; case matters.

    Returns:
        The value, or None.
    """
    for ref param in params:
        if param.name == name:
            return param.value.copy()
    return None


@fieldwise_init
struct Url(Copyable, Movable, Writable):
    """The parts of an absolute URL. The text of each part stays encoded."""

    var scheme: String
    """The scheme, in lowercase, such as `http`."""
    var userinfo: String
    """The text before `@` in the authority, or empty."""
    var host: String
    """The host, in lowercase; an IPv6 literal keeps its brackets."""
    var port: Int
    """The port; the default of the scheme when the URL has none: 80 for
    `http`, 443 for `https`, else -1."""
    var path: String
    """The path; `/` when the URL has none."""
    var query: String
    """The text after `?`, without the `?`, or empty."""
    var fragment: String
    """The text after `#`, without the `#`, or empty."""

    @staticmethod
    def parse(text: StringSlice) raises HttpError -> Url:
        """Read an absolute URL.

        Args:
            text: The URL, such as `http://localhost:4000/graphql?x=1`.

        Returns:
            Its parts.

        Raises:
            HttpError: `PROTOCOL` for a URL without a scheme or a host, a
                port that is not a number from 0 to 65535, or white space or
                control bytes.
        """
        var bytes = text.as_bytes()
        for byte in bytes:
            if byte <= 32 or byte == 127:
                raise _invalid("a URL cannot hold white space or controls")
        var colon = text.find("://")
        if colon <= 0:
            raise _invalid("expected scheme://")
        var scheme = String(text[byte=:colon]).lower()
        var scheme_bytes = scheme.as_bytes()
        var position = 0
        while position < len(scheme_bytes):
            if not _is_scheme_byte(scheme_bytes[position]):
                raise _invalid("invalid scheme")
            position += 1
        var rest = text[byte = colon + 3 :]
        var authority_end = rest.byte_length()
        for index in range(rest.byte_length()):
            var byte = rest.as_bytes()[index]
            if byte == 47 or byte == 63 or byte == 35:
                authority_end = index
                break
        var authority = rest[byte=:authority_end]
        var tail = rest[byte=authority_end:]
        var userinfo = String()
        var at = authority.rfind("@")
        if at >= 0:
            userinfo = String(authority[byte=:at])
            authority = authority[byte = at + 1 :]
        var host_end = authority.byte_length()
        if authority.startswith("["):
            var close = authority.find("]")
            if close < 0:
                raise _invalid("unterminated IPv6 literal")
            host_end = close + 1
        else:
            var port_colon = authority.find(":")
            if port_colon >= 0:
                host_end = port_colon
        var host = String(authority[byte=:host_end]).lower()
        if host.byte_length() == 0:
            raise _invalid("a URL needs a host")
        var port = 80 if scheme == "http" else (
            443 if scheme == "https" else -1
        )
        var after_host = authority[byte=host_end:]
        if after_host.byte_length() > 0:
            if not after_host.startswith(":"):
                raise _invalid("invalid text after the host")
            var digits = after_host[byte=1:]
            if digits.byte_length() > 0:
                port = _port(digits)
        var fragment = String()
        var hash = tail.find("#")
        if hash >= 0:
            fragment = String(tail[byte = hash + 1 :])
            tail = tail[byte=:hash]
        var query = String()
        var mark = tail.find("?")
        if mark >= 0:
            query = String(tail[byte = mark + 1 :])
            tail = tail[byte=:mark]
        var path = String(tail) if tail.byte_length() > 0 else String("/")
        return Url(scheme^, userinfo^, host^, port, path^, query^, fragment^)

    def target(self) -> String:
        """Return the request target in origin form: the path and query.

        Returns:
            Such as `/graphql?x=1`.
        """
        if self.query.byte_length() == 0:
            return self.path.copy()
        return self.path + "?" + self.query

    def authority(self) -> String:
        """Return the host, and the port when it is not the default.

        Returns:
            A `Host` header value, such as `localhost:4000`.
        """
        var default = (self.scheme == "http" and self.port == 80) or (
            self.scheme == "https" and self.port == 443
        )
        if default or self.port < 0:
            return self.host.copy()
        return self.host + ":" + String(self.port)

    def write_to(self, mut writer: Some[Writer]):
        """Write the URL without its userinfo.

        Args:
            writer: The destination.
        """
        writer.write(self.scheme, "://", self.authority(), self.target())
        if self.fragment.byte_length() > 0:
            writer.write("#", self.fragment)


def _is_scheme_byte(byte: UInt8) -> Bool:
    """Return True for a letter, a digit, `+`, `-` or `.`."""
    var letter = lower(byte) >= 97 and lower(byte) <= 122
    var digit = byte >= 48 and byte <= 57
    return letter or digit or byte == 43 or byte == 45 or byte == 46


def _port(digits: StringSlice) raises HttpError -> Int:
    """Read a port number: at most five digits, at most 65535."""
    var bytes = digits.as_bytes()
    if len(bytes) > 5:
        raise _invalid("invalid port")
    var value = 0
    var index = 0
    while index < len(bytes):
        var byte = bytes[index]
        if byte < 48 or byte > 57:
            raise _invalid("invalid port")
        value = value * 10 + Int(byte) - 48
        index += 1
    if value > 65535:
        raise _invalid("invalid port")
    return value

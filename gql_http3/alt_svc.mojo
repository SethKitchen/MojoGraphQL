# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""HTTP Alternative Services (RFC 7838): how a TCP server announces its
HTTP/3 port, and how a client remembers it.

`AltSvc` wraps a `Handler`: each response gets
`Alt-Svc: h3=":<port>"; ma=<seconds>`. Put it around the handler of the
HTTP/1.1 and HTTPS servers, so that clients learn the UDP port of the
`H3Server`.

`parse_alt_svc` reads an `Alt-Svc` value and gives its `h3` alternative.
`AltSvcCache` keeps one per origin until `ma` runs out; the value `clear`
removes it.

This module ports no code. The behavior follows RFC 7838 sections 3
and 3.1, and RFC 9114 section 3.1.1.

Differences from upstream: none; there is no upstream.
"""

from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter


struct AltSvc[H: Handler](Handler):
    """A handler that announces an HTTP/3 port, then runs another handler.

    Parameters:
        H: The type of the handler.
    """

    var inner: Self.H
    """The handler of every request."""
    var value: String
    """The `Alt-Svc` value, such as `h3=":4433"; ma=86400`."""

    def __init__(out self, var inner: Self.H, port: Int, max_age: Int = 86400):
        """Announce HTTP/3 on a UDP port of the same host.

        Args:
            inner: The handler of every request.
            port: The UDP port of the HTTP/3 server.
            max_age: How long a client can remember it, in seconds.
        """
        self.inner = inner^
        self.value = 'h3=":' + String(port) + '"; ma=' + String(max_age)

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        """Add the `Alt-Svc` field, then run the handler.

        Args:
            request: The request.
            response: The response.

        Raises:
            Error: The errors of the handler.
        """
        response.add_header("Alt-Svc", self.value)
        self.inner.handle(request, response)


@fieldwise_init
struct AltService(Copyable, Movable, Writable):
    """An HTTP/3 alternative of an origin."""

    var host: String
    """The host; empty for the host of the origin."""
    var port: Int
    """The UDP port."""
    var max_age: Int
    """How long it is fresh, in seconds."""

    def write_to(self, mut writer: Some[Writer]):
        """Write the alternative as an `Alt-Svc` entry.

        Args:
            writer: The destination.
        """
        writer.write('h3="', self.host, ":", self.port, '"; ma=', self.max_age)


def _number(text: StringSlice) -> Int:
    """Read decimal digits; -1 when there are none or another byte."""
    var bytes = text.as_bytes()
    if len(bytes) == 0 or len(bytes) > 9:
        return -1
    var value = 0
    var index = 0
    while index < len(bytes):
        var byte = bytes[index]
        if byte < 48 or byte > 57:
            return -1
        value = value * 10 + Int(byte - 48)
        index += 1
    return value


def parse_alt_svc(value: StringSlice) -> Optional[AltService]:
    """Find the first `h3` alternative of an `Alt-Svc` value.

    Args:
        value: The value, such as `h3=":443"; ma=3600, h2=":443"`.

    Returns:
        The alternative, or None when it has none. `clear` gives one with
        port 0 and `max_age` 0.
    """
    var text = value.strip(" \t")
    if text == "clear":
        return AltService(String(), 0, 0)
    # split gives at least one entry, so the loop never runs zero times.
    for entry in text.split(","):  # pragma: no branch
        var parts = entry.split(";")
        var first = parts[0].strip(" \t")
        if not first.startswith('h3="') or not first.endswith('"'):
            continue
        var authority = first[byte = 4 : first.byte_length() - 1]
        var colon = authority.rfind(":")
        if colon < 0:
            continue
        var port = _number(authority[byte = colon + 1 :])
        if port <= 0 or port > 65535:
            continue
        var max_age = 86400
        var index = 1
        while index < len(parts):
            var parameter = parts[index].strip(" \t")
            if parameter.startswith("ma="):
                var seconds = _number(parameter[byte=3:])
                if seconds >= 0:
                    max_age = seconds
            index += 1
        return AltService(String(authority[byte=:colon]), port, max_age)
    return None


@fieldwise_init
struct _Entry(Copyable, Movable):
    var origin: String
    var service: AltService
    var expires: Int


struct AltSvcCache(Movable, Sized):
    """The HTTP/3 alternatives that servers announced, by origin."""

    var _entries: List[_Entry]

    def __init__(out self):
        """Make an empty cache."""
        self._entries = List[_Entry]()

    def __len__(self) -> Int:
        """Return the count of origins.

        Returns:
            The count.
        """
        return len(self._entries)

    def remember(mut self, origin: String, value: StringSlice, now: Int):
        """Take the `Alt-Svc` value of a response from an origin.

        Args:
            origin: The origin, such as `localhost:4443`.
            value: The `Alt-Svc` value.
            now: The time, in seconds.
        """
        var service = parse_alt_svc(value)
        if not service:
            return
        self.forget(origin)
        var found = service.value().copy()
        if found.port > 0 and found.max_age > 0:
            self._entries.append(
                _Entry(origin, found^, now + service.value().max_age)
            )

    def lookup(mut self, origin: String, now: Int) -> Optional[AltService]:
        """Return the fresh HTTP/3 alternative of an origin.

        Args:
            origin: The origin.
            now: The time, in seconds.

        Returns:
            The alternative, or None. A stale one is removed.
        """
        var index = 0
        while index < len(self._entries):
            if self._entries[index].origin == origin:
                if self._entries[index].expires > now:
                    return self._entries[index].service.copy()
                _ = self._entries.pop(index)
                return None
            index += 1
        return None

    def forget(mut self, origin: String):
        """Remove the alternative of an origin, such as after a failure.

        Args:
            origin: The origin.
        """
        var index = 0
        while index < len(self._entries):
            if self._entries[index].origin == origin:
                _ = self._entries.pop(index)
                return
            index += 1

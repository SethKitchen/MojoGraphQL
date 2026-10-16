# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Status codes, methods and protocol versions, as types.

The status codes and reason phrases are those of RFC 9110 section 15. The
methods are those of RFC 9110 section 9 and RFC 5789 (`PATCH`).

This module ports no code. It follows the registries of the RFCs.

Differences from upstream: none; there is no upstream.
"""


@fieldwise_init
struct Status(Equatable, ImplicitlyCopyable, Writable):
    """An HTTP status code, as a type and not a bare integer."""

    var code: Int
    """The three-digit code; see `is_valid`."""

    comptime CONTINUE = Status(100)
    """100 Continue."""
    comptime SWITCHING_PROTOCOLS = Status(101)
    """101 Switching Protocols."""
    comptime OK = Status(200)
    """200 OK."""
    comptime CREATED = Status(201)
    """201 Created."""
    comptime ACCEPTED = Status(202)
    """202 Accepted."""
    comptime NO_CONTENT = Status(204)
    """204 No Content."""
    comptime MOVED_PERMANENTLY = Status(301)
    """301 Moved Permanently."""
    comptime FOUND = Status(302)
    """302 Found."""
    comptime SEE_OTHER = Status(303)
    """303 See Other."""
    comptime NOT_MODIFIED = Status(304)
    """304 Not Modified."""
    comptime TEMPORARY_REDIRECT = Status(307)
    """307 Temporary Redirect."""
    comptime PERMANENT_REDIRECT = Status(308)
    """308 Permanent Redirect."""
    comptime BAD_REQUEST = Status(400)
    """400 Bad Request."""
    comptime UNAUTHORIZED = Status(401)
    """401 Unauthorized."""
    comptime FORBIDDEN = Status(403)
    """403 Forbidden."""
    comptime NOT_FOUND = Status(404)
    """404 Not Found."""
    comptime METHOD_NOT_ALLOWED = Status(405)
    """405 Method Not Allowed."""
    comptime NOT_ACCEPTABLE = Status(406)
    """406 Not Acceptable."""
    comptime REQUEST_TIMEOUT = Status(408)
    """408 Request Timeout."""
    comptime CONFLICT = Status(409)
    """409 Conflict."""
    comptime LENGTH_REQUIRED = Status(411)
    """411 Length Required."""
    comptime CONTENT_TOO_LARGE = Status(413)
    """413 Content Too Large."""
    comptime URI_TOO_LONG = Status(414)
    """414 URI Too Long."""
    comptime UNSUPPORTED_MEDIA_TYPE = Status(415)
    """415 Unsupported Media Type."""
    comptime EXPECTATION_FAILED = Status(417)
    """417 Expectation Failed."""
    comptime UNPROCESSABLE_CONTENT = Status(422)
    """422 Unprocessable Content."""
    comptime TOO_MANY_REQUESTS = Status(429)
    """429 Too Many Requests."""
    comptime REQUEST_HEADER_FIELDS_TOO_LARGE = Status(431)
    """431 Request Header Fields Too Large."""
    comptime INTERNAL_SERVER_ERROR = Status(500)
    """500 Internal Server Error."""
    comptime NOT_IMPLEMENTED = Status(501)
    """501 Not Implemented."""
    comptime BAD_GATEWAY = Status(502)
    """502 Bad Gateway."""
    comptime SERVICE_UNAVAILABLE = Status(503)
    """503 Service Unavailable."""
    comptime GATEWAY_TIMEOUT = Status(504)
    """504 Gateway Timeout."""
    comptime HTTP_VERSION_NOT_SUPPORTED = Status(505)
    """505 HTTP Version Not Supported."""

    def is_valid(self) -> Bool:
        """Return True for a code that RFC 9110 allows: 100 to 599.

        Returns:
            Whether the code is in range.
        """
        return self.code >= 100 and self.code <= 599

    def is_informational(self) -> Bool:
        """Return True for a 1xx code.

        Returns:
            Whether the code is 100 to 199.
        """
        return self.code >= 100 and self.code <= 199

    def has_body(self) -> Bool:
        """Return True when a response with this code can have content.

        RFC 9112 section 6.3: a 1xx, 204 or 304 response has no content.

        Returns:
            Whether the response can carry a body.
        """
        return (
            not self.is_informational()
            and self.code != 204
            and (self.code != 304)
        )

    def reason(self) -> StaticString:
        """Return the reason phrase of RFC 9110 section 15.

        Returns:
            The phrase, such as `Not Found`, or an empty string for a code
            that the RFC does not name.
        """
        var code = self.code
        if code < 300:
            if code == 100:
                return "Continue"
            if code == 101:
                return "Switching Protocols"
            if code == 200:
                return "OK"
            if code == 201:
                return "Created"
            if code == 202:
                return "Accepted"
            if code == 204:
                return "No Content"
            return ""
        if code < 400:
            if code == 301:
                return "Moved Permanently"
            if code == 302:
                return "Found"
            if code == 303:
                return "See Other"
            if code == 304:
                return "Not Modified"
            if code == 307:
                return "Temporary Redirect"
            if code == 308:
                return "Permanent Redirect"
            return ""
        if code < 500:
            return _reason_4xx(code)
        if code == 500:
            return "Internal Server Error"
        if code == 501:
            return "Not Implemented"
        if code == 502:
            return "Bad Gateway"
        if code == 503:
            return "Service Unavailable"
        if code == 504:
            return "Gateway Timeout"
        if code == 505:
            return "HTTP Version Not Supported"
        return ""

    def write_to(self, mut writer: Some[Writer]):
        """Write the code and its reason phrase, such as `404 Not Found`.

        Args:
            writer: The destination.
        """
        writer.write(self.code, " ", self.reason())


def _reason_4xx(code: Int) -> StaticString:
    """Return the reason phrase of a 4xx code, or an empty string."""
    if code == 400:
        return "Bad Request"
    if code == 401:
        return "Unauthorized"
    if code == 403:
        return "Forbidden"
    if code == 404:
        return "Not Found"
    if code == 405:
        return "Method Not Allowed"
    if code == 406:
        return "Not Acceptable"
    if code == 408:
        return "Request Timeout"
    if code == 409:
        return "Conflict"
    if code == 411:
        return "Length Required"
    if code == 413:
        return "Content Too Large"
    if code == 414:
        return "URI Too Long"
    if code == 415:
        return "Unsupported Media Type"
    if code == 417:
        return "Expectation Failed"
    if code == 422:
        return "Unprocessable Content"
    if code == 429:
        return "Too Many Requests"
    if code == 431:
        return "Request Header Fields Too Large"
    return ""


@fieldwise_init
struct Method(Equatable, ImplicitlyCopyable, Writable):
    """A request method, as a type and not a bare integer.

    `OTHER` stands for any other token. `Request.method_text` gives the
    text of an `OTHER` method.
    """

    var value: UInt8
    """The method's index; see `is_valid`."""

    comptime GET = Method(0)
    """`GET`."""
    comptime HEAD = Method(1)
    """`HEAD`."""
    comptime POST = Method(2)
    """`POST`."""
    comptime PUT = Method(3)
    """`PUT`."""
    comptime DELETE = Method(4)
    """`DELETE`."""
    comptime CONNECT = Method(5)
    """`CONNECT`."""
    comptime OPTIONS = Method(6)
    """`OPTIONS`."""
    comptime TRACE = Method(7)
    """`TRACE`."""
    comptime PATCH = Method(8)
    """`PATCH`."""
    comptime OTHER = Method(9)
    """An extension method."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the methods.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 9

    def is_idempotent(self) -> Bool:
        """Return True for an idempotent method of RFC 9110 section 9.2.2.

        Returns:
            Whether a client can send the request again after a failure:
            `GET`, `HEAD`, `PUT`, `DELETE`, `OPTIONS` and `TRACE`.
        """
        var v = self.value
        return v == 0 or v == 1 or v == 3 or v == 4 or v == 6 or v == 7

    def text(self) -> StaticString:
        """Return the method name.

        Returns:
            The name, such as `GET`; `OTHER` and invalid values give an
            empty string.
        """
        comptime names: Array[StaticString, 10] = [
            "GET",
            "HEAD",
            "POST",
            "PUT",
            "DELETE",
            "CONNECT",
            "OPTIONS",
            "TRACE",
            "PATCH",
            "",
        ]
        if not self.is_valid():
            return ""
        return materialize[names]()[Int(self.value)]

    @staticmethod
    def from_bytes(data: Span[UInt8, _]) -> Method:
        """Return the method that a token names, with case kept.

        Methods are case-sensitive (RFC 9110 section 9.1).

        Args:
            data: The method token.

        Returns:
            The method, or `OTHER` for any other token.
        """
        var n = len(data)
        var p = data.unsafe_ptr()
        if n == 3:
            if _same(p, "GET"):
                return Method.GET
            return Method.PUT if _same(p, "PUT") else Method.OTHER
        if n == 4:
            return _method4(p)
        if n == 5:
            return _method5(p)
        if n == 6:
            return Method.DELETE if _same(p, "DELETE") else Method.OTHER
        if n == 7:
            if _same(p, "OPTIONS"):
                return Method.OPTIONS
            return Method.CONNECT if _same(p, "CONNECT") else Method.OTHER
        return Method.OTHER

    def write_to(self, mut writer: Some[Writer]):
        """Write the method name.

        Args:
            writer: The destination.
        """
        writer.write(self.text())


def _same(p: Pointer[UInt8, _], word: StaticString) -> Bool:
    """Compare the bytes at `p` with a word of the same length."""
    var w = word.unsafe_ptr()
    var index = 0
    while index < word.byte_length():
        if p[unsafe_offset=index] != w[unsafe_offset=index]:
            return False
        index += 1
    return True


def _method4(p: Pointer[UInt8, _]) -> Method:
    """Return the four-byte method at `p`."""
    if _same(p, "POST"):
        return Method.POST
    return Method.HEAD if _same(p, "HEAD") else Method.OTHER


def _method5(p: Pointer[UInt8, _]) -> Method:
    """Return the five-byte method at `p`."""
    if _same(p, "PATCH"):
        return Method.PATCH
    return Method.TRACE if _same(p, "TRACE") else Method.OTHER


@fieldwise_init
struct Version(Equatable, ImplicitlyCopyable, Writable):
    """An HTTP/1 protocol version, as a type and not a bare integer."""

    var minor: UInt8
    """The minor version: 0 or 1."""

    comptime HTTP_1_0 = Version(0)
    """HTTP/1.0."""
    comptime HTTP_1_1 = Version(1)
    """HTTP/1.1."""

    def is_valid(self) -> Bool:
        """Return True for HTTP/1.0 and HTTP/1.1.

        Returns:
            Whether the minor version is 0 or 1.
        """
        return self.minor <= 1

    def text(self) -> StaticString:
        """Return the protocol name of the version.

        Returns:
            `HTTP/1.0`, or `HTTP/1.1` for every other minor version.
        """
        return "HTTP/1.0" if self.minor == 0 else "HTTP/1.1"

    def write_to(self, mut writer: Some[Writer]):
        """Write the protocol name of the version.

        Args:
            writer: The destination.
        """
        writer.write(self.text())

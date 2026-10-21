# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The response mode of a request, from its `Accept` header.

Port of `SingleContentType`, `StreamContentType`, `ResponseMode` and
`RequestAccepts::negotiate` of Hive Router `1a29df9`
`bin/router/src/pipeline/header.rs`, with the `Accept` parser and
`Accept::negotiate` of headers-accept 0.3.0 (MIT) that upstream calls.

The media ranges are sorted by specificity, then by `q`, and the sort is
stable. For each type that the router can send, in the router's order,
the first range that matches gives its quality. The type with the best
quality wins, then the one whose range comes first, then the one the
router lists first. A `q` of 0 refuses a type. The `boundary` parameter
of `multipart/mixed` is removed first, because the server picks the
boundary.

**Differences from upstream.** There is no Laboratory, so a browser
`Accept` header negotiates as when upstream turns the Laboratory off. The
media type parser is a small one: a type, a subtype with an optional
`+suffix`, and parameters with token or quoted values.
"""

from gql_router.pipeline import PipelineError, client_error


@fieldwise_init
struct SingleContentType(Equatable, ImplicitlyCopyable, Writable):
    """A content type for one response, as upstream `SingleContentType`."""

    var value: UInt8
    """The index; see `is_valid`."""

    comptime JSON = SingleContentType(0)
    """`application/json`."""
    comptime GRAPHQL_RESPONSE_JSON = SingleContentType(1)
    """`application/graphql-response+json`."""

    def is_valid(self) -> Bool:
        """Tell if the index names a content type.

        Returns:
            True for the two types.
        """
        return self.value <= 1

    def write_to(self, mut writer: Some[Writer]):
        """Write the media type.

        Args:
            writer: The destination.
        """
        if self == SingleContentType.JSON:
            writer.write("application/json")
        else:
            writer.write("application/graphql-response+json")


@fieldwise_init
struct StreamContentType(Equatable, ImplicitlyCopyable, Writable):
    """A content type for a stream, as upstream `StreamContentType`."""

    var value: UInt8
    """The index; see `is_valid`."""

    comptime INCREMENTAL_DELIVERY = StreamContentType(0)
    """`multipart/mixed`: GraphQL incremental delivery."""
    comptime SSE = StreamContentType(1)
    """`text/event-stream`: GraphQL over SSE, distinct connections."""
    comptime APOLLO_MULTIPART_HTTP = StreamContentType(2)
    """`multipart/mixed;subscriptionSpec="1.0"`: Apollo multipart HTTP."""

    def is_valid(self) -> Bool:
        """Tell if the index names a content type.

        Returns:
            True for the three types.
        """
        return self.value <= 2

    def write_to(self, mut writer: Some[Writer]):
        """Write the media type, as upstream `strum` names it.

        Args:
            writer: The destination.
        """
        if self == StreamContentType.INCREMENTAL_DELIVERY:
            writer.write("multipart/mixed")
        elif self == StreamContentType.SSE:
            writer.write("text/event-stream")
        else:
            writer.write('multipart/mixed;subscriptionSpec="1.0"')


@fieldwise_init
struct ResponseMode(Equatable, ImplicitlyCopyable, Writable):
    """What a client accepts, as upstream `ResponseMode`."""

    var has_single: Bool
    """Whether the client accepts one response."""
    var single: SingleContentType
    """The type of one response, when `has_single`."""
    var has_stream: Bool
    """Whether the client accepts a stream."""
    var stream: StreamContentType
    """The type of a stream, when `has_stream`."""

    def __eq__(self, other: Self) -> Bool:
        """Compare two modes; a type that is not accepted is ignored.

        Args:
            other: The other mode.

        Returns:
            True when both accept the same types.
        """
        if self.has_single != other.has_single:
            return False
        if self.has_stream != other.has_stream:
            return False
        if self.has_single and self.single != other.single:
            return False
        return not self.has_stream or self.stream == other.stream

    @staticmethod
    def json() -> ResponseMode:
        """Return the mode of an error before the negotiation.

        Returns:
            `SingleOnly(application/json)`.
        """
        return ResponseMode(
            True,
            SingleContentType.JSON,
            False,
            StreamContentType.INCREMENTAL_DELIVERY,
        )

    def can_single(self) -> Bool:
        """Tell if one response is accepted.

        Returns:
            True for `SingleOnly` and `Dual`.
        """
        return self.has_single

    def can_stream(self) -> Bool:
        """Tell if a stream is accepted.

        Returns:
            True for `StreamOnly` and `Dual`.
        """
        return self.has_stream

    def stream_only(self) -> Bool:
        """Tell if only a stream is accepted.

        Returns:
            True for `StreamOnly`.
        """
        return self.has_stream and not self.has_single

    def prefer_status_ok_for_errors(self) -> Bool:
        """Tell if an error answers 200, as upstream.

        Returns:
            True when the single type is `application/json`.
        """
        return self.has_single and self.single == SingleContentType.JSON

    def write_to(self, mut writer: Some[Writer]):
        """Write the mode as upstream `Debug` names it.

        Args:
            writer: The destination.
        """
        if self.has_single and self.has_stream:
            writer.write("Dual(", self.single, ", ", self.stream, ")")
        elif self.has_single:
            writer.write("SingleOnly(", self.single, ")")
        else:
            writer.write("StreamOnly(", self.stream, ")")


struct MediaRange(Copyable, Movable):
    """One media range of an `Accept` header, or one type the router
    sends."""

    var type: String
    """The type, in lower case; `*` for any."""
    var subtype: String
    """The subtype without its suffix, in lower case; `*` for any."""
    var suffix: String
    """The suffix after `+`, in lower case, or empty."""
    var names: List[String]
    """The parameter names except `q`, in lower case."""
    var values: List[String]
    """The parameter values without quotes, parallel to `names`."""
    var quality: Int
    """The `q` parameter in thousandths; 1000 when it is missing or bad."""

    def __init__(out self):
        """Make an empty range."""
        self.type = String()
        self.subtype = String()
        self.suffix = String()
        self.names = List[String]()
        self.values = List[String]()
        self.quality = 1000

    def specificity(self) -> Int:
        """Return the specificity, as headers-accept `parse_specificity`.

        Returns:
            One for a type that is not `*`, one for a subtype that is not
            `*`, and one for each parameter except `q`.
        """
        var count = len(self.names)
        if self.type != "*":
            count += 1
        if self.subtype != "*":
            count += 1
        return count

    def param(self, name: StringSlice) -> Int:
        """Find a parameter.

        Args:
            name: The name, in lower case.

        Returns:
            Its index, or -1.
        """
        var index = 0
        while index < len(self.names):
            if self.names[index] == name:
                return index
            index += 1
        return -1

    def matches(self, available: MediaRange) -> Bool:
        """Tell if this range accepts a type, as headers-accept
        `MediaRange == MediaType`.

        Args:
            available: The type that the router can send.

        Returns:
            True for `*/*`, for `type/*` of the same type, and for the same
            type, subtype and suffix with the same parameters.
        """
        if self.type == "*":
            return True
        if self.type != available.type:
            return False
        if self.subtype == "*":
            return True
        if self.subtype != available.subtype:
            return False
        if self.suffix != available.suffix:
            return False
        if len(self.names) != len(available.names):
            return False
        for index in range(len(self.names)):
            var other = available.param(self.names[index])
            if other < 0 or available.values[other] != self.values[index]:
                return False
        return True


def _lower(text: StringSlice) -> String:
    """Return the text with ASCII letters in lower case."""
    return String(text).lower()


def _is_token(text: StringSlice) -> Bool:
    """Tell if the text is a non-empty RFC 9110 token."""
    var bytes = text.as_bytes()
    if len(bytes) == 0:
        return False
    var index = 0
    while index < len(bytes):
        var byte = bytes[index]
        index += 1
        var ok = (
            (byte >= 48 and byte <= 57)
            or (byte >= 65 and byte <= 90)
            or (byte >= 97 and byte <= 122)
            or StringSlice("!#$%&'*+-.^_`|~").find(chr(Int(byte))) >= 0
        )
        if not ok:
            return False
    return True


def _quality(text: String) -> Int:
    """Read a `q` value in thousandths, as headers-accept `QValue`; -1 for
    a bad value."""
    if text == "0":
        return 0
    if text == "1":
        return 1000
    var bytes = text.as_bytes()
    if len(bytes) < 2 or len(bytes) > 5 or bytes[1] != UInt8(ord(".")):
        return -1
    var number = 0
    for index in range(2, len(bytes)):
        if bytes[index] < 48 or bytes[index] > 57:
            return -1
        number = number * 10 + Int(bytes[index] - 48)
    for _ in range(len(bytes), 5):
        number *= 10
    if bytes[0] == UInt8(ord("1")) and number == 0:
        return 1000
    if bytes[0] == UInt8(ord("0")):
        return number
    return -1


def parse_media_range(text: StringSlice) raises -> MediaRange:
    """Parse one media type or range, as mediatype `MediaTypeBuf`.

    Args:
        text: Such as `multipart/mixed; boundary="-"; q=0.5`.

    Returns:
        The range. A bad `q` is 1000, as headers-accept reads it.

    Raises:
        Error: When the text is not a media type.
    """
    var parts = List[String]()
    var current = String()
    var quoted = False
    var escaped = False
    for byte in text.as_bytes():
        var c = chr(Int(byte))
        if escaped:
            escaped = False
        elif quoted and byte == UInt8(ord("\\")):
            escaped = True
            continue
        elif byte == UInt8(ord('"')):
            quoted = not quoted
        elif byte == UInt8(ord(";")) and not quoted:
            parts.append(current)
            current = String()
            continue
        current += c
    if quoted:
        raise Error("unterminated quoted string")
    parts.append(current)
    var media = MediaRange()
    var head = String(parts[0].strip())
    var slash = head.find("/")
    if slash < 0:
        raise Error("missing subtype")
    media.type = _lower(head[byte=:slash])
    var subtype = _lower(head[byte = slash + 1 :])
    var plus = subtype.find("+")
    if plus >= 0:
        media.suffix = String(subtype[byte = plus + 1 :])
        var base = String(subtype[byte=:plus])
        subtype = base^
        if not _is_token(media.suffix):
            raise Error("bad suffix")
    media.subtype = subtype
    if not _is_token(media.type) or not _is_token(media.subtype):
        raise Error("bad type")
    for index in range(1, len(parts)):
        var param = String(parts[index].strip())
        var equals = param.find("=")
        if equals <= 0:
            raise Error("bad parameter")
        var name = _lower(param[byte=:equals].strip())
        var value = String(param[byte = equals + 1 :].strip())
        if (
            value.byte_length() >= 2
            and value.startswith('"')
            and value.endswith('"')
        ):
            var inner = String(value[byte = 1 : value.byte_length() - 1])
            value = inner^
        elif not _is_token(value):
            raise Error("bad parameter value")
        if not _is_token(name):
            raise Error("bad parameter name")
        if name == "q":
            var quality = _quality(value)
            media.quality = 1000 if quality < 0 else quality
        else:
            media.names.append(name^)
            media.values.append(value^)
    return media^


def parse_accept(header: StringSlice) raises -> List[MediaRange]:
    """Parse an `Accept` header and sort its ranges, as headers-accept
    `Accept::parse`.

    Args:
        header: The header value. Commas in quotes do not split.

    Returns:
        The ranges, the most specific first, then the highest `q`; equal
        ranges keep their order.

    Raises:
        Error: When a range is not a media type.
    """
    var out = List[MediaRange]()
    var start = 0
    var quoted = False
    var bytes = header.as_bytes()
    var index = 0
    while index <= len(bytes):
        var end = index == len(bytes)
        if not end and quoted and bytes[index] == UInt8(ord("\\")):
            index = min(index + 2, len(bytes))
            continue
        if not end and bytes[index] == UInt8(ord('"')):
            quoted = not quoted
        if end or (bytes[index] == UInt8(ord(",")) and not quoted):
            var segment = String(header[byte=start:index].strip())
            if segment.byte_length() > 0:
                out.append(parse_media_range(segment))
            start = index + 1
        index += 1
    # A stable insertion sort by (specificity, quality), descending.
    for position in range(1, len(out)):
        var moving = position
        while moving > 0 and _before(out[moving], out[moving - 1]):
            out.swap_elements(moving, moving - 1)
            moving -= 1
    return out^


def _before(a: MediaRange, b: MediaRange) -> Bool:
    """Tell if `a` sorts strictly before `b`."""
    if a.specificity() != b.specificity():
        return a.specificity() > b.specificity()
    return a.quality > b.quality


def negotiate_types(
    accept: List[MediaRange], available: List[MediaRange]
) -> Int:
    """Pick the best type, as headers-accept `Accept::negotiate`.

    Args:
        accept: The sorted ranges of the client.
        available: The types the router can send, in its order.

    Returns:
        The index of the best type in `available`, or -1 when the client
        accepts none.
    """
    var best = -1
    var best_quality = 0
    var best_range = 0
    # The router always has a type to offer.
    var given = -1
    while given + 1 < len(available):
        given += 1
        var matched = -1
        for parsed in range(len(accept)):
            if accept[parsed].matches(available[given]):
                matched = parsed
                break
        if matched < 0 or accept[matched].quality == 0:
            continue
        var quality = accept[matched].quality
        if (
            best < 0
            or quality > best_quality
            or (quality == best_quality and matched < best_range)
        ):
            best = given
            best_quality = quality
            best_range = matched
    return best


def _type(
    type: String, subtype: String, suffix: String = "", spec: Bool = False
) -> MediaRange:
    """Make a type that the router sends."""
    var media = MediaRange()
    media.type = type
    media.subtype = subtype
    media.suffix = suffix
    if spec:
        media.names.append("subscriptionspec")
        media.values.append("1.0")
    return media^


def negotiate(accept_header: StringSlice) raises PipelineError -> ResponseMode:
    """Agree on a response mode, as upstream `RequestAccepts::negotiate`.

    Args:
        accept_header: The `Accept` header; empty is `*/*`.

    Returns:
        The single type and the stream type that the client accepts.

    Raises:
        PipelineError: `INVALID_HEADER` (400) for a bad header, and
            `UNSUPPORTED_CONTENT_TYPE` (415) when the client accepts no
            type of the router.
    """
    var header = String(accept_header)
    if header.byte_length() == 0:
        header = "*/*"
    var accept: List[MediaRange]
    try:
        accept = parse_accept(header)
    except:
        raise client_error(
            "Header 'accept' has invalid value", "INVALID_HEADER", 400
        )
    for ref media in accept:
        if media.type == "multipart" and media.subtype == "mixed":
            var at = media.param("boundary")
            if at >= 0:
                _ = media.names.pop(at)
                _ = media.values.pop(at)
    var single = negotiate_types(
        accept,
        [
            _type("application", "json"),
            _type("application", "graphql-response", "json"),
        ],
    )
    var stream = negotiate_types(
        accept,
        [
            _type("multipart", "mixed"),
            _type("text", "event-stream"),
            _type("multipart", "mixed", spec=True),
        ],
    )
    if single < 0 and stream < 0:
        raise client_error(
            "Content-Type header is not supported",
            "UNSUPPORTED_CONTENT_TYPE",
            415,
        )
    return ResponseMode(
        single >= 0,
        SingleContentType(UInt8(max(single, 0))),
        stream >= 0,
        StreamContentType(UInt8(max(stream, 0))),
    )

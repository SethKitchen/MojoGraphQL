# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Header fields to send, media types, and `Accept` lists.

`Headers` holds fields in their wire form, `Name: value` and CRLF, so a
message copies them with one copy. `parse_media_type` reads a
`Content-Type` value (RFC 9110 section 8.3.1). `parse_accept` and
`accept_quality` read an `Accept` value (RFC 9110 section 12.5.1). The
GraphQL over HTTP rules that use them belong to `gql_server`.

This module ports no code. It follows RFC 9110.

Differences from upstream: none; there is no upstream.
"""

from gql_http.error import ErrorKind, HttpError
from gql_http.scan import equals_ignore_case, is_field_byte, is_tchar, lower


def is_token(text: StringSlice) -> Bool:
    """Return True for a non-empty token of RFC 9110 section 5.6.2.

    Args:
        text: The text.

    Returns:
        Whether every byte is a `tchar`, and there is at least one.
    """
    var bytes = text.as_bytes()
    var index = 0
    while index < len(bytes):
        if not is_tchar(bytes[index]):
            return False
        index += 1
    return len(bytes) > 0


def is_field_value(text: StringSlice) -> Bool:
    """Return True for text that can be a field value: no CR, LF or NUL.

    Args:
        text: The text.

    Returns:
        Whether every byte is VCHAR, obs-text, SP or HTAB.
    """
    for byte in text.as_bytes():
        if not is_field_byte(byte):
            return False
    return True


def _usage(message: String) -> HttpError:
    """Make a `USAGE` error."""
    return HttpError(ErrorKind.USAGE, message, 0)


struct Headers(Copyable, Movable, Sized):
    """Header fields in wire form: `Name: value` and CRLF, each.

    `add` checks each name and value, so a caller cannot split a message
    with a CR or an LF.
    """

    var data: List[UInt8]
    """The fields as they go on the wire."""
    var _offsets: List[Int]

    def __init__(out self):
        """Make an empty list of fields."""
        self.data = List[UInt8]()
        self._offsets = List[Int]()

    def __len__(self) -> Int:
        """Return the number of fields.

        Returns:
            The count.
        """
        return len(self._offsets) // 3

    def add(mut self, name: StringSlice, value: StringSlice) raises HttpError:
        """Add a field at the end. A name can occur more than once.

        Args:
            name: The field name, a token.
            value: The field value, without CR, LF or NUL. White space at
                its ends is removed.

        Raises:
            HttpError: `USAGE` for a name that is not a token, or a value
                that a field cannot hold.
        """
        if not is_token(name):
            raise _usage("invalid header name: " + String(name))
        var trimmed = value.strip(" \t")
        if not is_field_value(trimmed):
            raise _usage("invalid value for header " + String(name))
        self._offsets.append(len(self.data))
        self.data.extend(name.as_bytes())
        self._offsets.append(len(self.data) + 2)
        self.data.extend(StaticString(": ").as_bytes())
        self.data.extend(trimmed.as_bytes())
        self._offsets.append(len(self.data))
        self.data.extend(StaticString("\r\n").as_bytes())

    def set(mut self, name: StringSlice, value: StringSlice) raises HttpError:
        """Replace every field with a name by one field.

        Args:
            name: The field name, in any case.
            value: The field value.

        Raises:
            HttpError: `USAGE` for an invalid name or value.
        """
        self.remove(name)
        self.add(name, value)

    def remove(mut self, name: StringSlice):
        """Remove every field with a name, case folded.

        Args:
            name: The field name, in any case.
        """
        var kept = Headers()
        var index = 0
        while index < len(self):
            if not equals_ignore_case(
                self.name(index).as_bytes(), name.as_bytes()
            ):
                # The fields were checked when they were added.
                kept._append_checked(self.name(index), self.value(index))
            index += 1
        self = kept^

    def _append_checked(mut self, name: StringSlice, value: StringSlice):
        """Add a field that `add` has already checked."""
        self._offsets.append(len(self.data))
        self.data.extend(name.as_bytes())
        self._offsets.append(len(self.data) + 2)
        self.data.extend(StaticString(": ").as_bytes())
        self.data.extend(value.as_bytes())
        self._offsets.append(len(self.data))
        self.data.extend(StaticString("\r\n").as_bytes())

    def name(self, index: Int) -> StringSlice[origin_of(self.data)]:
        """Return the name of a field.

        Args:
            index: The field's index, from 0 to `len(self) - 1`.

        Returns:
            The name, case kept.
        """
        var start = self._offsets[index * 3]
        var end = self._offsets[index * 3 + 1] - 2
        return StringSlice(unsafe_from_utf8=Span(self.data)[start:end])

    def value(self, index: Int) -> StringSlice[origin_of(self.data)]:
        """Return the value of a field.

        Args:
            index: The field's index, from 0 to `len(self) - 1`.

        Returns:
            The value.
        """
        var start = self._offsets[index * 3 + 1]
        var end = self._offsets[index * 3 + 2]
        return StringSlice(unsafe_from_utf8=Span(self.data)[start:end])

    def find(self, name: StringSlice) -> Int:
        """Return the index of the first field with a name, case folded.

        Args:
            name: The field name, in any case.

        Returns:
            The index, or -1.
        """
        var index = 0
        while index < len(self):
            if equals_ignore_case(self.name(index).as_bytes(), name.as_bytes()):
                return index
            index += 1
        return -1

    def get(
        self, name: StringSlice
    ) -> Optional[StringSlice[origin_of(self.data)]]:
        """Return the value of the first field with a name, case folded.

        Args:
            name: The field name, in any case.

        Returns:
            The value, or None.
        """
        var index = self.find(name)
        if index < 0:
            return None
        return self.value(index)

    def clear(mut self):
        """Remove every field, and keep the capacity."""
        self.data.clear()
        self._offsets.clear()


@fieldwise_init
struct Parameter(Copyable, Movable):
    """One parameter of a media type, such as `charset=utf-8`."""

    var name: String
    """The name, in lowercase."""
    var value: String
    """The value, without quotes and escapes; case kept."""


@fieldwise_init
struct MediaType(Copyable, Movable, Writable):
    """A media type: `type/subtype` and its parameters."""

    var type: String
    """The type, in lowercase, such as `application`; `*` in a range."""
    var subtype: String
    """The subtype, in lowercase, such as `json`; `*` in a range."""
    var parameters: List[Parameter]
    """The parameters, in order."""

    def parameter(self, name: StringSlice) -> Optional[String]:
        """Return the value of a parameter, by its name in any case.

        Args:
            name: The parameter name.

        Returns:
            The value, or None.
        """
        for ref parameter in self.parameters:
            if equals_ignore_case(parameter.name.as_bytes(), name.as_bytes()):
                return parameter.value.copy()
        return None

    def essence(self) -> String:
        """Return `type/subtype`, without parameters.

        Returns:
            The essence, in lowercase.
        """
        return self.type + "/" + self.subtype

    def write_to(self, mut writer: Some[Writer]):
        """Write `type/subtype` and the parameters, `; name=value` each.

        Args:
            writer: The destination.
        """
        writer.write(self.type, "/", self.subtype)
        for ref parameter in self.parameters:
            writer.write(";", parameter.name, "=", parameter.value)


struct _Cursor:
    """A position in the bytes of a header value."""

    var bytes: List[UInt8]
    var index: Int

    def __init__(out self, text: StringSlice):
        self.bytes = List[UInt8](text.as_bytes())
        self.index = 0

    def done(self) -> Bool:
        return self.index >= len(self.bytes)

    def peek(self) -> UInt8:
        return self.bytes[self.index]

    def skip_ows(mut self):
        while not self.done():
            var byte = self.peek()
            if byte != 32 and byte != 9:
                return
            self.index += 1

    def token(mut self) -> String:
        """Read a token, in lowercase; empty if none is here."""
        var out = String()
        while not self.done():
            var byte = self.peek()
            if not is_tchar(byte):
                break
            out += chr(Int(lower(byte)))
            self.index += 1
        return out^

    def value(mut self) raises HttpError -> String:
        """Read a token or a quoted string, case kept."""
        if self.done() or self.peek() != 34:
            var out = String()
            while not self.done():
                var byte = self.peek()
                if not is_tchar(byte):
                    break
                out += chr(Int(byte))
                self.index += 1
            if out.byte_length() == 0:
                raise _usage("expected a parameter value")
            return out^
        self.index += 1
        var bytes = List[UInt8]()
        while True:
            if self.done():
                raise _usage("unterminated quoted string")
            var byte = self.peek()
            self.index += 1
            if byte == 34:
                break
            if byte == 92:
                if self.done():
                    raise _usage("unterminated quoted string")
                byte = self.peek()
                self.index += 1
            if not is_field_byte(byte):
                raise _usage("invalid byte in a quoted string")
            bytes.append(byte)
        return String(unsafe_from_utf8=bytes)


def _media_type(mut cursor: _Cursor) raises HttpError -> MediaType:
    """Read `type/subtype *(OWS ";" OWS parameter)` up to a comma or the
    end."""
    cursor.skip_ows()
    var type = cursor.token()
    if type.byte_length() == 0 or cursor.done() or cursor.peek() != 47:
        raise _usage("expected type/subtype")
    cursor.index += 1
    var subtype = cursor.token()
    if subtype.byte_length() == 0:
        raise _usage("expected type/subtype")
    var parameters = List[Parameter]()
    while True:
        cursor.skip_ows()
        if cursor.done() or cursor.peek() == 44:
            break
        if cursor.peek() != 59:
            raise _usage("expected ; before a parameter")
        cursor.index += 1
        cursor.skip_ows()
        if cursor.done() or cursor.peek() == 44:
            break
        var name = cursor.token()
        if name.byte_length() == 0 or cursor.done() or cursor.peek() != 61:
            raise _usage("expected name=value")
        cursor.index += 1
        var value = cursor.value()
        parameters.append(Parameter(name^, value^))
    return MediaType(type^, subtype^, parameters^)


def parse_media_type(text: StringSlice) raises HttpError -> MediaType:
    """Read a media type, such as `application/json; charset=utf-8`.

    The type, the subtype and the parameter names are case-insensitive, so
    they come back in lowercase. A parameter value is a token or a quoted
    string.

    Args:
        text: A `Content-Type` value.

    Returns:
        The media type.

    Raises:
        HttpError: `USAGE` when the text is not a media type.
    """
    var cursor = _Cursor(text)
    var media = _media_type(cursor)
    if not cursor.done():
        raise _usage("unexpected text after the media type")
    return media^


@fieldwise_init
struct MediaRange(Copyable, Movable):
    """One element of an `Accept` list: a media range and its weight."""

    var media: MediaType
    """The range; `type` or `subtype` can be `*`. `q` is not a parameter."""
    var quality: Int
    """The weight `q`, times 1000: 0 to 1000."""

    def matches(self, type: StringSlice, subtype: StringSlice) -> Bool:
        """Return True when the range covers a media type.

        Args:
            type: The type, in any case.
            subtype: The subtype, in any case.

        Returns:
            Whether the range is `*/*`, `type/*` or `type/subtype`.
        """
        if self.media.type == "*":
            return True
        if not equals_ignore_case(self.media.type.as_bytes(), type.as_bytes()):
            return False
        if self.media.subtype == "*":
            return True
        return equals_ignore_case(
            self.media.subtype.as_bytes(), subtype.as_bytes()
        )

    def specificity(self) -> Int:
        """Return how specific the range is.

        Returns:
            0 for `*/*`, 1 for `type/*`, 2 for `type/subtype`, plus 1 per
            parameter.
        """
        if self.media.type == "*":
            return 0
        if self.media.subtype == "*":
            return 1
        return 2 + len(self.media.parameters)


def _quality(text: StringSlice) -> Int:
    """Read a `qvalue` of RFC 9110 section 12.4.2, times 1000, or -1."""
    var bytes = text.as_bytes()
    var n = len(bytes)
    if n == 0 or n > 5 or (bytes[0] != 48 and bytes[0] != 49):
        return -1
    var whole = Int(bytes[0]) - 48
    if n == 1:
        return whole * 1000
    if bytes[1] != 46:
        return -1
    var value = 0
    var scale = 100
    var index = 2
    while index < n:
        var byte = bytes[index]
        if byte < 48 or byte > 57:
            return -1
        value += (Int(byte) - 48) * scale
        scale //= 10
        index += 1
    if whole == 1 and value != 0:
        return -1
    return whole * 1000 + value


def parse_accept(text: StringSlice) -> List[MediaRange]:
    """Read an `Accept` value into its media ranges.

    An element that is not a media range, or has an invalid `q`, is
    dropped, as RFC 9110 lets a recipient do. The `q` parameter and the
    parameters after it (accept extensions) are not media type parameters.

    Args:
        text: The `Accept` value.

    Returns:
        The ranges, in the order of the text.
    """
    var out = List[MediaRange]()
    var cursor = _Cursor(text)
    while not cursor.done():
        try:
            var media = _media_type(cursor)
            var quality = 1000
            var kept = List[Parameter]()
            var after_q = False
            for ref parameter in media.parameters:
                if after_q:
                    continue
                if parameter.name == "q":
                    quality = _quality(parameter.value)
                    after_q = True
                else:
                    kept.append(parameter.copy())
            if quality >= 0:
                media.parameters = kept^
                out.append(MediaRange(media^, quality))
        except:
            # Skip to the next element.
            while not cursor.done() and cursor.peek() != 44:
                cursor.index += 1
        if not cursor.done():
            cursor.index += 1
    return out^


def accept_quality(
    accept: StringSlice, type: StringSlice, subtype: StringSlice
) -> Int:
    """Return how much an `Accept` value wants a media type.

    The most specific range that covers the type gives its weight (RFC
    9110 section 12.5.1). An empty `Accept` value accepts everything.

    Args:
        accept: The `Accept` value.
        type: The type, such as `application`.
        subtype: The subtype, such as `graphql-response+json`.

    Returns:
        The weight times 1000: 0 to 1000. 0 means "not acceptable",
        either from `q=0` or because no range covers the type.
    """
    var ranges = parse_accept(accept)
    if len(ranges) == 0:
        return 0 if accept.strip(" \t").byte_length() > 0 else 1000
    var best = -1
    var quality = 0
    var index = 0
    while index < len(ranges):
        ref media_range = ranges[index]
        if media_range.matches(type, subtype):
            var specificity = media_range.specificity()
            if specificity > best:
                best = specificity
                quality = media_range.quality
        index += 1
    return quality

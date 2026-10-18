# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Media types: the content negotiation and the `Content-Type` checks of
Apollo Server.

Apollo Server 5.5.1 uses three MIT packages for this, and this module
ports the parts it calls:

- `negotiator` 1.1.0 `lib/mediaType.js` and `lib/accept.js`:
  `new Negotiator({headers: {accept}}).mediaType(available)` is
  `preferred_media_type(accept, available)`.
- `content-type` 2.1.0 `parse`, which `negotiator` uses to read the
  `Accept` ranges and the available types.
- `whatwg-mimetype` 4.0.0 `MIMEType.parse(text).essence`, which
  `runHttpQuery.ts` and `preventCsrf.ts` use: `mime_essence(text)`.

**Differences from upstream.** The text is UTF-8, and the parsers work on
bytes. JavaScript works on UTF-16 code units. The results differ only for
text outside ASCII, where both parsers treat each unit as opaque.
"""

from std.math import isnan, nan

from gql_json.number import read_float64
from gql_server.http_types import lower_ascii


struct _Param(Copyable, Movable):
    var key: String
    var value: String

    def __init__(out self, key: String, value: String):
        self.key = key
        self.value = value


struct _Parsed(Copyable, Movable):
    var type: String
    var index: Int
    var params: List[_Param]

    def __init__(out self, var type: String, index: Int):
        self.type = type^
        self.index = index
        self.params = List[_Param]()

    def param(self, key: String) -> Optional[String]:
        for ref param in self.params:
            if param.key == key:
                return param.value.copy()
        return None


def _is_ows(byte: UInt8) -> Bool:
    return byte == 32 or byte == 9


def _skip_ows(text: Span[UInt8, _], var index: Int) -> Int:
    while index < len(text) and _is_ows(text[index]):
        index += 1
    return index


def _trailing_ows(text: Span[UInt8, _], start: Int, var end: Int) -> Int:
    while end > start and _is_ows(text[end - 1]):
        end -= 1
    return end


def _skip_value(text: Span[UInt8, _], var index: Int, stop: Int) -> Int:
    while index < len(text):
        var code = Int(text[index])
        if code == 59 or code == stop:
            break
        index += 1
    return index


def _text(text: Span[UInt8, _], start: Int, end: Int) -> String:
    return String(unsafe_from_utf8=text[start:end])


def _parse(text: Span[UInt8, _], comma: Bool, start: Int) -> _Parsed:
    """Port of `content-type` 2.1.0 `parse(header, {comma, start})`."""
    var stop = 44 if comma else 65536
    var size = len(text)
    var index = _skip_ows(text, start)
    var value_start = index
    index = _skip_value(text, index, stop)
    var value_end = _trailing_ows(text, value_start, index)
    var out = _Parsed(lower_ascii(_text(text, value_start, value_end)), 0)
    while index < size:
        if Int(text[index]) == stop:
            break
        index = _skip_ows(text, index + 1)
        var key_start = index
        var stopped = False
        while index < size:
            var code = Int(text[index])
            if code == stop:
                stopped = True
                break
            if code == 59:
                break
            if code == 61:
                var key = lower_ascii(
                    _text(
                        text, key_start, _trailing_ows(text, key_start, index)
                    )
                )
                index = _skip_ows(text, index + 1)
                if index < size and text[index] == 34:
                    index += 1
                    var value = List[UInt8]()
                    while index < size:
                        var byte = text[index]
                        index += 1
                        if byte == 34:
                            index = _skip_value(text, index, stop)
                            if not out.param(key):
                                out.params.append(
                                    _Param(key, String(unsafe_from_utf8=value))
                                )
                            break
                        if byte == 92 and index < size:
                            value.append(text[index])
                            index += 1
                            continue
                        value.append(byte)
                    break
                var param_start = index
                index = _skip_value(text, index, stop)
                if not out.param(key):
                    var param_end = _trailing_ows(text, param_start, index)
                    out.params.append(
                        _Param(key, _text(text, param_start, param_end))
                    )
                break
            index += 1
        if stopped:
            break
    out.index = index
    return out^


def _is_digit(text: Span[UInt8, _], index: Int) -> Bool:
    return index < len(text) and text[index] >= 48 and text[index] <= 57


def _digits(text: Span[UInt8, _], var index: Int) -> Int:
    while _is_digit(text, index):
        index += 1
    return index


def parse_float(text: StringSlice) -> Float64:
    """Read the number at the start of text, as JavaScript `parseFloat`.

    Args:
        text: The text, such as the `q` parameter of a media range.

    Returns:
        The number of the longest prefix that is a decimal literal, after
        white space; NaN when there is none.
    """
    var bytes = text.as_bytes()
    var start = 0
    while start < len(bytes) and (
        bytes[start] == 32 or (bytes[start] >= 9 and bytes[start] <= 13)
    ):
        start += 1
    var index = start
    if index < len(bytes) and (bytes[index] == 43 or bytes[index] == 45):
        index += 1
    if StringSlice(unsafe_from_utf8=bytes[index:]).startswith("Infinity"):
        var infinity = Float64.MAX * 2.0
        return -infinity if bytes[start] == 45 else infinity
    # The prefix becomes JSON number text: a sign, digits without leading
    # zeros, a fraction and an exponent.
    var json = List[UInt8]()
    if start < len(bytes) and bytes[start] == 45:
        json.append(45)
    var mantissa = index
    while index < len(bytes) and bytes[index] == 48:
        index += 1
    var integer = index
    index = _digits(bytes, index)
    if index == integer:
        json.append(48)
    json.extend(bytes[integer:index])
    var whole = index > mantissa
    if index < len(bytes) and bytes[index] == 46:
        var fraction = _digits(bytes, index + 1)
        if fraction > index + 1:
            json.extend(bytes[index:fraction])
            whole = True
        if whole:
            index = fraction
    if not whole:
        return nan[DType.float64]()
    if index < len(bytes) and (bytes[index] == 101 or bytes[index] == 69):
        var exponent = index + 1
        if exponent < len(bytes) and (
            bytes[exponent] == 43 or bytes[exponent] == 45
        ):
            exponent += 1
        if _is_digit(bytes, exponent):
            json.append(101)
            json.extend(bytes[index + 1 : _digits(bytes, exponent)])
    return read_float64(json)


struct _Range(Copyable, Movable):
    """A media range of `Accept`: negotiator `formatMediaType`."""

    var type: String
    var subtype: String
    var params: List[_Param]
    var q: Float64
    var i: Int

    def __init__(out self, var parsed: _Parsed, i: Int, slash: Int):
        var bytes = parsed.type.as_bytes()
        self.type = _text(bytes, 0, slash)
        self.subtype = _text(bytes, slash + 1, len(bytes))
        self.q = 1.0
        self.i = i
        self.params = List[_Param]()
        for ref param in parsed.params:
            if param.key == "q":
                # A `q` of "" is falsy in JavaScript: the weight stays 1.
                if param.value.byte_length() > 0:
                    self.q = parse_float(param.value)
            else:
                self.params.append(param.copy())


def _format(var parsed: _Parsed, i: Int) -> Optional[_Range]:
    var slash = parsed.type.find("/")
    if slash < 0:
        return None
    return _Range(parsed^, i, slash)


def _parse_accept(header: StringSlice) -> List[_Range]:
    """Port of negotiator `parseAccept` and `lib/accept.js`."""
    var bytes = header.as_bytes()
    var out = List[_Range]()
    var index = 0
    var position = 0
    while index < len(bytes):
        var start = _skip_ows(bytes, index)
        var parsed = _parse(bytes, True, start)
        # The type keeps the case of the header.
        parsed.type = _text(bytes, start, start + parsed.type.byte_length())
        index = parsed.index + 1
        var range = _format(parsed^, position)
        position += 1
        if range:
            out.append(range.take())
    return out^


@fieldwise_init
struct _Priority(Copyable, Movable):
    var i: Int
    var o: Int
    var q: Float64
    var s: Int


def _js_or(a: Float64, b: Float64) -> Float64:
    """JavaScript `a || b` for numbers: 0 and NaN are falsy."""
    return a if a != 0 and not isnan(a) else b


def _lower_byte(byte: UInt8) -> UInt8:
    return byte + 32 if byte >= 65 and byte <= 90 else byte


def _same_ignore_case(a: String, b: String) -> Bool:
    """ASCII case-insensitive equality, without a copy."""
    var x = a.as_bytes()
    var y = b.as_bytes()
    if len(x) != len(y):
        return False
    var index = 0
    while index < len(x) and _lower_byte(x[index]) == _lower_byte(y[index]):
        index += 1
    return index == len(x)


def _available(type: StringSlice) -> _Range:
    """An available type, parsed as negotiator `specify` parses it. It has
    a `/`."""
    var parsed = _parse(type.as_bytes(), False, 0)
    var slash = parsed.type.find("/")
    return _Range(parsed^, 0, slash)


def _specify(p: _Range, spec: _Range, index: Int) -> Optional[_Priority]:
    """Port of negotiator `specify`."""
    var s = 0
    if _same_ignore_case(spec.type, p.type):
        s |= 4
    elif spec.type != "*":
        return None
    if _same_ignore_case(spec.subtype, p.subtype):
        s |= 2
    elif spec.subtype != "*":
        return None
    for ref param in spec.params:
        if param.value == "*":
            continue
        var mine = String("")
        for ref other in p.params:
            if other.key == param.key:
                mine = other.value.copy()
                break
        if not _same_ignore_case(param.value, mine):
            return None
    if len(spec.params) > 0:
        s |= 1
    return _Priority(index, spec.i, spec.q, s)


def _priority(p: _Range, accepted: List[_Range], index: Int) -> _Priority:
    """Port of negotiator `getMediaTypePriority`."""
    var priority = _Priority(index, -1, 0.0, 0)
    for ref spec in accepted:
        var found = _specify(p, spec, index)
        if not found:
            continue
        ref candidate = found.value()
        var order = _js_or(
            Float64(priority.s - candidate.s),
            _js_or(priority.q - candidate.q, Float64(priority.o - candidate.o)),
        )
        if order < 0:
            priority = candidate.copy()
    return priority^


def _before(a: _Priority, b: _Priority) -> Bool:
    """Whether `a` sorts before `b`: negotiator `compareSpecs` < 0."""
    if a.q != b.q:
        return a.q > b.q
    if a.s != b.s:
        return a.s > b.s
    if a.o != b.o:
        return a.o < b.o
    return a.i < b.i


def preferred_media_type(
    accept: Optional[String], available: List[String]
) -> Optional[String]:
    """Return the available media type that `Accept` prefers: negotiator
    `mediaType(available)`.

    Args:
        accept: The `Accept` value; None stands for `*/*`.
        available: The media types to choose from, best first. Each one
            has a `/`.

    Returns:
        The first type of the highest weight, specificity and order, or
        None when `Accept` takes none of them.
    """
    var accepts = _parse_accept(accept.value() if accept else String("*/*"))
    var best = Optional[_Priority](None)
    var index = 0
    while index < len(available):
        var priority = _priority(_available(available[index]), accepts, index)
        if priority.q > 0 and (not best or _before(priority, best.value())):
            best = priority^
        index += 1
    if not best:
        return None
    return available[best.value().i].copy()


def _is_http_whitespace(byte: UInt8) -> Bool:
    return byte == 32 or byte == 9 or byte == 10 or byte == 13


def _is_token(text: Span[UInt8, _]) -> Bool:
    """Whether text is a non-empty run of HTTP token code points."""
    if len(text) == 0:
        return False
    var index = 0
    while index < len(text):
        var b = text[index]
        var alnum = (
            (b >= 48 and b <= 57)
            or (b >= 65 and b <= 90)
            or (b >= 97 and b <= 122)
        )
        if not alnum:
            var symbols = StaticString("!#$%&'*+-.^_`|~").as_bytes()
            var at = 0
            while at < len(symbols) and symbols[at] != b:
                at += 1
            if at == len(symbols):
                return False
        index += 1
    return True


def mime_essence(text: StringSlice) -> Optional[String]:
    """Parse a MIME type and return its essence: whatwg-mimetype
    `MIMEType.parse(text)?.essence`.

    Args:
        text: The text, such as a `Content-Type` value.

    Returns:
        The type and the subtype in lowercase, such as `application/json`,
        or None when the text is not a MIME type. The parameters cannot
        make it fail.
    """
    var bytes = text.as_bytes()
    var start = 0
    var end = len(bytes)
    while start < end and _is_http_whitespace(bytes[start]):
        start += 1
    while end > start and _is_http_whitespace(bytes[end - 1]):
        end -= 1
    var slash = start
    while slash < end and bytes[slash] != 47:
        slash += 1
    if slash >= end or not _is_token(bytes[start:slash]):
        return None
    var semicolon = slash + 1
    while semicolon < end and bytes[semicolon] != 59:
        semicolon += 1
    var subtype_end = semicolon
    while subtype_end > slash + 1 and _is_http_whitespace(
        bytes[subtype_end - 1]
    ):
        subtype_end -= 1
    if not _is_token(bytes[slash + 1 : subtype_end]):
        return None
    return lower_ascii(_text(bytes, start, subtype_end))


def media_type_parameter(
    text: StringSlice, name: StringSlice
) -> Optional[String]:
    """Return a parameter of a media type, as `content-type` 2.1.0 `parse`
    reads it.

    Args:
        text: The media type, such as `application/json; charset=UTF-8`.
        name: The parameter name, in lowercase.

    Returns:
        The value of the first parameter with the name, or None.
    """
    return _parse(text.as_bytes(), False, 0).param(String(name))

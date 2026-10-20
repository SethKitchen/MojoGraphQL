# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The raw edits of the variables JSON that the normalization passes make.

graphql-go-tools keeps the variables of a request as JSON bytes, and edits
them with `jsonparser` and `sjson`. Only the members of the top-level object
are read and written. These functions give the same bytes:

- `top_level_member` is `jsonparser.Get(variables, name)`: the raw value.
- `set_raw` is `sjson.SetRawBytes(variables, name, value)`.
- `delete_member` is `sjson.DeleteBytes(variables, name)`.

The text must be valid JSON. A key that has an escape does not match.
"""


@fieldwise_init
struct Member(ImplicitlyCopyable, Movable):
    """One member of the top-level object of a JSON text."""

    var key_start: Int
    """The offset of the opening quote of the key."""
    var key_end: Int
    """The offset after the closing quote of the key."""
    var value_start: Int
    """The offset of the first byte of the value."""
    var value_end: Int
    """The offset after the last byte of the value."""

    def key(self, text: StringSlice) -> StringSlice[text.origin]:
        """Return the key, without the quotes.

        Args:
            text: The JSON text.

        Returns:
            The raw key.
        """
        return text[byte = self.key_start + 1 : self.key_end - 1]

    def value(self, text: StringSlice) -> StringSlice[text.origin]:
        """Return the raw value.

        Args:
            text: The JSON text.

        Returns:
            The value, as it is in the text.
        """
        return text[byte = self.value_start : self.value_end]

    def is_string(self, text: StringSlice) -> Bool:
        """Return True if the value is a string.

        Args:
            text: The JSON text.

        Returns:
            Whether the value starts with a quote.
        """
        return text.as_bytes()[self.value_start] == UInt8(ord('"'))


def _skip_space(data: Span[UInt8, _], position: Int) -> Int:
    """Return the offset of the first byte that is not white space."""
    var at = position
    while at < len(data) and (
        data[at] == UInt8(ord(" "))
        or data[at] == UInt8(ord("\n"))
        or data[at] == UInt8(ord("\r"))
        or data[at] == UInt8(ord("\t"))
    ):
        at += 1
    return at


def _string_end(data: Span[UInt8, _], position: Int) -> Int:
    """Return the offset after a string that starts at `position`."""
    var at = position + 1
    while at < len(data):
        var byte = data[at]
        if byte == UInt8(ord("\\")):
            at += 2
            continue
        at += 1
        if byte == UInt8(ord('"')):
            break
    return at


def value_end(data: Span[UInt8, _], position: Int) -> Int:
    """Return the offset after the JSON value that starts at `position`.

    Args:
        data: The JSON text.
        position: The offset of the first byte of the value.

    Returns:
        The offset after the value.
    """
    var first = data[position]
    if first == UInt8(ord('"')):
        return _string_end(data, position)
    if first == UInt8(ord("{")) or first == UInt8(ord("[")):
        var depth = 0
        var at = position
        while at < len(data):
            var byte = data[at]
            if byte == UInt8(ord('"')):
                at = _string_end(data, at)
                continue
            if byte == UInt8(ord("{")) or byte == UInt8(ord("[")):
                depth += 1
            elif byte == UInt8(ord("}")) or byte == UInt8(ord("]")):
                depth -= 1
                if depth == 0:
                    return at + 1
            at += 1
        return at
    var at = position
    while at < len(data):
        var byte = data[at]
        if (
            byte == UInt8(ord(","))
            or byte == UInt8(ord("}"))
            or byte == UInt8(ord("]"))
            or byte == UInt8(ord(" "))
            or byte == UInt8(ord("\n"))
            or byte == UInt8(ord("\r"))
            or byte == UInt8(ord("\t"))
        ):
            break
        at += 1
    return at


def members(text: StringSlice) -> List[Member]:
    """Return the members of the top-level object of a JSON text.

    Args:
        text: The JSON text.

    Returns:
        The members in order; empty when the text is not an object.
    """
    var out = List[Member]()
    var data = text.as_bytes()
    var at = _skip_space(data, 0)
    if at >= len(data) or data[at] != UInt8(ord("{")):
        return out^
    at = _skip_space(data, at + 1)
    while at < len(data) and data[at] == UInt8(ord('"')):
        var key_start = at
        var key_end = _string_end(data, at)
        at = _skip_space(data, key_end)
        at = _skip_space(data, at + 1)
        var start = at
        var end = value_end(data, at)
        out.append(Member(key_start, key_end, start, end))
        at = _skip_space(data, end)
        if at < len(data) and data[at] == UInt8(ord(",")):
            at = _skip_space(data, at + 1)
    return out^


def top_level_member(text: StringSlice, name: StringSlice) -> Int:
    """Return the index of the last top-level member with a key, or -1.

    `jsonparser.Get` returns the first match; a JSON object with two equal
    keys is not valid for a request, so the two agree on valid input.

    Args:
        text: The JSON text.
        name: The key.

    Returns:
        The index in `members(text)`, or -1.
    """
    var found = members(text)
    var index = 0
    while index < len(found):
        if found[index].key(text) == name:
            return index
        index += 1
    return -1


def _replace_member(
    text: String, found: List[Member], name: StringSlice, raw: StringSlice
) -> Int:
    """Return the index of the member with a key, or -1."""
    var index = 0
    while index < len(found):
        if found[index].key(text) == name:
            return index
        index += 1
    return -1


def _with_value(text: String, member: Member, raw: StringSlice) -> String:
    """Return the text with the value of a member replaced."""
    return (
        String(text[byte = : member.value_start])
        + String(raw)
        + String(text[byte = member.value_end :])
    )


def set_raw(text: String, name: StringSlice, raw: StringSlice) -> String:
    """Set a top-level member to a raw JSON value: `sjson.SetRawBytes` of
    sjson v1.0.4, the version that the graphql-go-tools workspace pins.

    A member that exists gets the new value in place. A new member goes at
    the start of the object. A text that is not an object becomes a new
    object.

    Args:
        text: The JSON text.
        name: The key.
        raw: The value, as JSON text.

    Returns:
        The new JSON text.
    """
    var found = members(text)
    var index = _replace_member(text, found, name, raw)
    if index >= 0:
        return _with_value(text, found[index], raw)
    var entry = '"' + String(name) + '":' + String(raw)
    var data = text.as_bytes()
    var open = _skip_space(data, 0)
    if open >= len(data) or data[open] != UInt8(ord("{")):
        return "{" + entry + "}"
    if len(found) > 0:
        entry += ","
    return "{" + entry + String(text[byte = open + 1 :])


def jsonparser_set(text: String, name: StringSlice, raw: StringSlice) -> String:
    """Set a member of an object to a raw JSON value: `jsonparser.Set`.

    A member that exists gets the new value in place. A new member goes at
    the end of the object.

    Args:
        text: A JSON object.
        name: The key.
        raw: The value, as JSON text.

    Returns:
        The new JSON text.
    """
    var found = members(text)
    var index = _replace_member(text, found, name, raw)
    if index >= 0:
        return _with_value(text, found[index], raw)
    var data = text.as_bytes()
    var close = len(data) - 1
    while data[close] != UInt8(ord("}")):
        close -= 1
    var entry = '"' + String(name) + '":' + String(raw)
    if len(found) > 0:
        entry = "," + entry
    return String(text[byte=:close]) + entry + String(text[byte=close:])


def delete_member(text: String, name: StringSlice) -> String:
    """Delete a top-level member: `sjson.DeleteBytes` of sjson v1.0.4.

    A member after the first goes with the comma before it. The first
    member goes with the white space and the comma after it.

    Args:
        text: The JSON text.
        name: The key.

    Returns:
        The new JSON text; the same text when no member has the key.
    """
    var found = members(text)
    var index = _replace_member(text, found, name, "")
    if index < 0:
        return text
    var data = text.as_bytes()
    var start = found[index].key_start
    var end = found[index].value_end
    if index > 0:
        while data[start] != UInt8(ord(",")):
            start -= 1
    else:
        var after = _skip_space(data, end)
        if after < len(data) and data[after] == UInt8(ord(",")):
            end = after + 1
    return String(text[byte=:start]) + String(text[byte=end:])


def json_kind(text: StringSlice) -> UInt8:
    """Return the first byte of a JSON value, which names its kind.

    Args:
        text: A JSON value; white space before it is skipped.

    Returns:
        `{`, `[`, `"`, `n` for null, `t` or `f` for a boolean, or the first
        byte of a number; 0 for an empty text.
    """
    var data = text.as_bytes()
    var at = _skip_space(data, 0)
    if at >= len(data):
        return 0
    return data[at]


def elements(text: StringSlice) -> List[Tuple[Int, Int]]:
    """Return the byte ranges of the elements of a JSON array.

    Args:
        text: A JSON array.

    Returns:
        The start and end of each element, in order; empty when the text
        is not an array.
    """
    var out = List[Tuple[Int, Int]]()
    var data = text.as_bytes()
    var at = _skip_space(data, 0)
    if at >= len(data) or data[at] != UInt8(ord("[")):
        return out^
    at = _skip_space(data, at + 1)
    while at < len(data) and data[at] != UInt8(ord("]")):
        var end = value_end(data, at)
        out.append((at, end))
        at = _skip_space(data, end)
        if at < len(data) and data[at] == UInt8(ord(",")):
            at = _skip_space(data, at + 1)
    return out^


def set_path(text: String, path: List[String], raw: StringSlice) -> String:
    """Set the value at a path of keys and indexes: `sjson.SetRawBytes` with
    a dotted path.

    A key that is missing from an object is added at its end. An index of
    an array that is out of range leaves the text unchanged.

    Args:
        text: The JSON text.
        path: The keys of objects and the indexes of arrays, outermost
            first.
        raw: The new value, as JSON text.

    Returns:
        The new JSON text.
    """
    return _set_path(text, path, 0, raw)


def _parse_index(text: StringSlice) -> Int:
    """Return a decimal index, or -1 for a text that is not one."""
    var data = text.as_bytes()
    if len(data) == 0:
        return -1
    var total = 0
    var at = 0
    while at < len(data):
        var byte = data[at]
        if byte < UInt8(ord("0")) or byte > UInt8(ord("9")):
            return -1
        total = total * 10 + Int(byte - UInt8(ord("0")))
        at += 1
    return total


def _set_path(
    text: String, path: List[String], depth: Int, raw: StringSlice
) -> String:
    """Set the value at `path[depth:]` inside `text`."""
    if depth == len(path):
        return String(raw)
    if json_kind(text) == UInt8(ord("[")):
        var index = _parse_index(path[depth])
        var items = elements(text)
        if index < 0 or index >= len(items):
            return text
        var start = items[index][0]
        var end = items[index][1]
        return (
            String(text[byte=:start])
            + _set_path(String(text[byte=start:end]), path, depth + 1, raw)
            + String(text[byte=end:])
        )
    var found = members(text)
    var index = 0
    while index < len(found):
        if found[index].key(text) == path[depth]:
            var start = found[index].value_start
            var end = found[index].value_end
            return (
                String(text[byte=:start])
                + _set_path(String(text[byte=start:end]), path, depth + 1, raw)
                + String(text[byte=end:])
            )
        index += 1
    return set_raw(text, path[depth], _set_path("", path, depth + 1, raw))

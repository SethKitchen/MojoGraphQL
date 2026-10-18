# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The scalars and flow collections of the YAML reader.

A plain scalar is resolved with the YAML 1.2 core schema, as serde_yaml
resolves it: `null`, `~` and an empty value are null, `true` and `false`
are booleans, and a decimal integer is a number. Every other plain scalar
is a string. A quoted scalar is always a string.
"""

from gql_json.value import JsonDocument, append_codepoint

comptime _SPACE = UInt8(ord(" "))
comptime _TAB = UInt8(ord("\t"))
comptime _HASH = UInt8(ord("#"))
comptime _DQUOTE = UInt8(ord('"'))
comptime _SQUOTE = UInt8(ord("'"))
comptime _BACKSLASH = UInt8(ord("\\"))


def yaml_error(line: Int, message: String) -> Error:
    """Make the error of a YAML text that the reader does not accept.

    Args:
        line: The 1-based line of the problem.
        message: What is wrong.

    Returns:
        The error, such as `line 3: a tab is not indentation`.
    """
    return Error("line " + String(line) + ": " + message)


def strip_comment(text: StringSlice) -> String:
    """Remove a comment and the trailing white space from a line.

    A `#` starts a comment at the start of the line, or after a space or
    a tab, when it is not inside a quoted scalar.

    Args:
        text: The line, without its line break.

    Returns:
        The line before the comment, with no trailing white space.
    """
    var bytes = text.as_bytes()
    var quote = UInt8(0)
    var end = len(bytes)
    var index = 0
    while index < len(bytes):
        var byte = bytes[index]
        if quote != 0:
            if quote == _DQUOTE and byte == _BACKSLASH:
                index += 1
            elif byte == quote:
                quote = 0
        elif byte == _DQUOTE or byte == _SQUOTE:
            quote = byte
        elif byte == _HASH and (
            index == 0 or bytes[index - 1] == _SPACE or bytes[index - 1] == _TAB
        ):
            end = index
            break
        index += 1
    while end > 0 and (bytes[end - 1] == _SPACE or bytes[end - 1] == _TAB):
        end -= 1
    return String(text[byte=:end])


def _hex(byte: UInt8) -> Int:
    """Return the value of a hexadecimal digit, or -1."""
    if byte >= 48 and byte <= 57:
        return Int(byte) - 48
    if byte >= 97 and byte <= 102:
        return Int(byte) - 87
    if byte >= 65 and byte <= 70:
        return Int(byte) - 55
    return -1


def _escape(
    text: StringSlice, at: Int, line: Int, mut out: String
) raises -> Int:
    """Append the character of the escape at `at`, after the backslash.

    Returns:
        The index after the escape.
    """
    var bytes = text.as_bytes()
    if at >= len(bytes):
        raise yaml_error(line, "a double-quoted scalar is not closed")
    var byte = bytes[at]
    var simple: List[String] = ["n", "t", "r", "0", '"', "\\", "/", " "]
    var means: List[String] = ["\n", "\t", "\r", "\x00", '"', "\\", "/", " "]
    var index = 0
    while index < len(simple):
        if byte == simple[index].as_bytes()[0]:
            out += means[index]
            return at + 1
        index += 1
    var width: Int
    if byte == UInt8(ord("x")):
        width = 2
    elif byte == UInt8(ord("u")):
        width = 4
    elif byte == UInt8(ord("U")):
        width = 8
    else:
        raise yaml_error(line, "an unknown escape in a double-quoted scalar")
    var code = 0
    var offset = 0
    while offset < width:
        var digit = (
            _hex(bytes[at + 1 + offset]) if at + 1 + offset < len(bytes) else -1
        )
        if digit < 0:
            raise yaml_error(line, "an invalid hexadecimal escape")
        code = code * 16 + digit
        offset += 1
    if code > 0x10FFFF or (code >= 0xD800 and code <= 0xDFFF):
        raise yaml_error(line, "an escape is not a Unicode scalar value")
    var utf8 = List[UInt8]()
    append_codepoint(utf8, code)
    out += String(unsafe_from_utf8=utf8)
    return at + 1 + width


def read_quoted(
    text: StringSlice, start: Int, line: Int
) raises -> Tuple[String, Int]:
    """Read a single-quoted or double-quoted scalar.

    Args:
        text: The line.
        start: The index of the opening quote.
        line: The 1-based line, for errors.

    Returns:
        The value, and the index after the closing quote.

    Raises:
        Error: For a scalar that is not closed on its line, or an unknown
            escape.
    """
    var bytes = text.as_bytes()
    var quote = bytes[start]
    var out = String()
    var index = start + 1
    var run = index
    while index < len(bytes):
        var byte = bytes[index]
        if byte == quote:
            out += String(text[byte=run:index])
            if (
                quote == _SQUOTE
                and index + 1 < len(bytes)
                and bytes[index + 1] == _SQUOTE
            ):
                out += "'"
                index += 2
                run = index
                continue
            return (out^, index + 1)
        if quote == _DQUOTE and byte == _BACKSLASH:
            out += String(text[byte=run:index])
            index = _escape(text, index + 1, line, out)
            run = index
            continue
        index += 1
    raise yaml_error(line, "a quoted scalar is not closed")


def _is_integer(text: StringSlice) -> Bool:
    """Return True for a decimal integer with an optional sign; the text
    is not empty."""
    var bytes = text.as_bytes()
    var index = 0
    if bytes[0] == UInt8(ord("-")) or bytes[0] == UInt8(ord("+")):
        index = 1
    if index >= len(bytes) or len(bytes) - index > 18:
        return False
    while index < len(bytes):
        if bytes[index] < 48 or bytes[index] > 57:
            return False
        index += 1
    return True


def _integer(text: StringSlice) -> Int64:
    """Return the value of a text that `_is_integer` accepts."""
    var bytes = text.as_bytes()
    var value = Int64(0)
    var start = 1 if bytes[0] < 48 else 0
    var index = start
    while index < len(bytes):
        value = value * 10 + Int64(bytes[index]) - 48
        index += 1
    return -value if bytes[0] == UInt8(ord("-")) else value


def add_plain(mut document: JsonDocument, text: StringSlice) -> Int:
    """Add a plain scalar, resolved with the YAML 1.2 core schema.

    Args:
        document: The document that receives the value.
        text: The scalar, without surrounding white space.

    Returns:
        The node: null, a boolean, a number or a string.
    """
    var words: List[String] = [
        "",
        "~",
        "null",
        "Null",
        "NULL",
        "true",
        "True",
        "TRUE",
        "false",
        "False",
        "FALSE",
    ]
    var index = 0
    while index < len(words):
        if text == words[index]:
            if index < 5:
                return document.add_null()
            return document.add_bool(index < 8)
        index += 1
    if _is_integer(text):
        return document.add_int(_integer(text))
    return document.add_string(text)

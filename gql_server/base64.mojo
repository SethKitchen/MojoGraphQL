# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Base64, for the `ftv1` extension of the inline trace plugin.

Apollo Server 5.5.1 `plugin/inlineTrace/index.ts` writes the trace as
`Buffer.from(bytes).toString('base64')`. This module implements the
base64 alphabet with padding of RFC 4648 section 4, and ports no code.

**Differences from upstream.** `base64_decode` is strict: it refuses a
character outside the alphabet and a length that is not a multiple of
four. Node.js `Buffer.from(text, 'base64')` skips such characters.
"""

comptime _ALPHABET = (
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
)
"""The 64 characters, by value."""


def base64_encode(bytes: Span[UInt8, _]) -> String:
    """Return the base64 text of bytes, with `=` padding.

    Args:
        bytes: The bytes.

    Returns:
        The text, as Node.js `buffer.toString('base64')` writes it.
    """
    var alphabet = _ALPHABET.as_bytes()
    var out = List[UInt8](capacity=(len(bytes) + 2) // 3 * 4)
    var index = 0
    while index + 3 <= len(bytes):
        var block = (
            (UInt32(bytes[index]) << 16)
            | (UInt32(bytes[index + 1]) << 8)
            | UInt32(bytes[index + 2])
        )
        out.append(alphabet[Int((block >> 18) & 63)])
        out.append(alphabet[Int((block >> 12) & 63)])
        out.append(alphabet[Int((block >> 6) & 63)])
        out.append(alphabet[Int(block & 63)])
        index += 3
    var rest = len(bytes) - index
    if rest > 0:
        var block = UInt32(bytes[index]) << 16
        if rest == 2:
            block |= UInt32(bytes[index + 1]) << 8
        out.append(alphabet[Int((block >> 18) & 63)])
        out.append(alphabet[Int((block >> 12) & 63)])
        out.append(alphabet[Int((block >> 6) & 63)] if rest == 2 else 61)
        out.append(61)
    return String(unsafe_from_utf8=out)


def _value(byte: UInt8) raises -> UInt32:
    """Return the value of a base64 character."""
    if byte >= 65 and byte <= 90:
        return UInt32(byte - 65)
    if byte >= 97 and byte <= 122:
        return UInt32(byte - 71)
    if byte >= 48 and byte <= 57:
        return UInt32(byte + 4)
    if byte == 43:
        return 62
    if byte == 47:
        return 63
    raise Error("Invalid base64 character: " + String(Int(byte)))


def base64_decode(text: StringSlice) raises -> List[UInt8]:
    """Return the bytes of base64 text with `=` padding.

    Args:
        text: The text.

    Returns:
        The bytes.

    Raises:
        Error: When the length is not a multiple of four, or a character
            is not in the alphabet or is padding before the end.
    """
    var bytes = text.as_bytes()
    if len(bytes) % 4 != 0:
        raise Error("Invalid base64 length: " + String(len(bytes)))
    var out = List[UInt8](capacity=len(bytes) // 4 * 3)
    var index = 0
    while index < len(bytes):
        var last = index + 4 == len(bytes)
        var pad = 0
        if last and bytes[index + 3] == 61:
            pad = 2 if bytes[index + 2] == 61 else 1
        var block = (_value(bytes[index]) << 18) | (
            _value(bytes[index + 1]) << 12
        )
        if pad < 2:
            block |= _value(bytes[index + 2]) << 6
        if pad < 1:
            block |= _value(bytes[index + 3])
        out.append(UInt8((block >> 16) & 255))
        if pad < 2:
            out.append(UInt8((block >> 8) & 255))
        if pad < 1:
            out.append(UInt8(block & 255))
        index += 4
    return out^

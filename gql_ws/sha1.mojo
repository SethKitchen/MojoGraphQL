# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""SHA-1 (FIPS 180-4) and base64 (RFC 4648 section 4), for the
`Sec-WebSocket-Accept` value of the opening handshake (RFC 6455 section
4.2.2).

The handshake uses SHA-1 only to show that the server read the key. It is
not a security function here, so this module has no constant-time code.

This module ports no code. tungstenite 0.30.0 takes SHA-1 from the `sha1`
crate and base64 from `data_encoding`.

Differences from upstream: none; the behavior is that of FIPS 180-4 and
RFC 4648.
"""

comptime _ALPHABET = (
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
)
"""The 64 characters of base64, by value."""


def _rotl(value: UInt32, shift: Int) -> UInt32:
    """Rotate 32 bits to the left."""
    return (value << UInt32(shift)) | (value >> UInt32(32 - shift))


def _word(block: Pointer[UInt8, _], index: Int) -> UInt32:
    """Read a big-endian 32-bit word of a block."""
    var at = index * 4
    return (
        (UInt32(block[unsafe_offset=at]) << 24)
        | (UInt32(block[unsafe_offset=at + 1]) << 16)
        | (UInt32(block[unsafe_offset=at + 2]) << 8)
        | UInt32(block[unsafe_offset=at + 3])
    )


def _compress(mut state: Array[UInt32, 5], block: Pointer[UInt8, _]):
    """Run the 80 rounds of SHA-1 on one 64-byte block."""
    var w = Array[UInt32, 80](fill=0)
    var t = 0
    while t < 16:
        w[t] = _word(block, t)
        t += 1
    while t < 80:
        w[t] = _rotl(w[t - 3] ^ w[t - 8] ^ w[t - 14] ^ w[t - 16], 1)
        t += 1
    var a = state[0]
    var b = state[1]
    var c = state[2]
    var d = state[3]
    var e = state[4]
    t = 0
    while t < 80:
        var f: UInt32
        var k: UInt32
        if t < 20:
            f = (b & c) | (~b & d)
            k = 0x5A827999
        elif t < 40:
            f = b ^ c ^ d
            k = 0x6ED9EBA1
        elif t < 60:
            f = (b & c) | (b & d) | (c & d)
            k = 0x8F1BBCDC
        else:
            f = b ^ c ^ d
            k = 0xCA62C1D6
        var temp = _rotl(a, 5) + f + e + k + w[t]
        e = d
        d = c
        c = _rotl(b, 30)
        b = a
        a = temp
        t += 1
    state[0] += a
    state[1] += b
    state[2] += c
    state[3] += d
    state[4] += e


def sha1(data: Span[UInt8, _]) -> Array[UInt8, 20]:
    """Return the SHA-1 digest of bytes.

    Args:
        data: The bytes.

    Returns:
        The 20 bytes of the digest.
    """
    var state: Array[UInt32, 5] = [
        0x67452301,
        0xEFCDAB89,
        0x98BADCFE,
        0x10325476,
        0xC3D2E1F0,
    ]
    var size = len(data)
    var whole = size - size % 64
    var offset = 0
    while offset < whole:
        _compress(state, data.unsafe_ptr().unsafe_offset(offset))
        offset += 64
    # The tail, the 0x80 byte, zeros and the bit length: one or two blocks.
    var tail = Array[UInt8, 128](fill=0)
    var rest = size - whole
    var index = 0
    while index < rest:
        tail[index] = data[whole + index]
        index += 1
    tail[rest] = 0x80
    var blocks = 1 if rest < 56 else 2
    var end = blocks * 64
    var bits = UInt64(size) * 8
    index = 0
    while index < 8:
        tail[end - 1 - index] = UInt8((bits >> UInt64(index * 8)) & 0xFF)
        index += 1
    var pointer = tail.unsafe_ptr()
    _compress(state, pointer)
    if blocks == 2:
        _compress(state, pointer.unsafe_offset(64))
    var out = Array[UInt8, 20](fill=0)
    index = 0
    while index < 5:
        out[index * 4] = UInt8(state[index] >> 24)
        out[index * 4 + 1] = UInt8((state[index] >> 16) & 0xFF)
        out[index * 4 + 2] = UInt8((state[index] >> 8) & 0xFF)
        out[index * 4 + 3] = UInt8(state[index] & 0xFF)
        index += 1
    return out^


def base64_encode(data: Span[UInt8, _]) -> String:
    """Return the base64 text of bytes, with `=` padding.

    Args:
        data: The bytes.

    Returns:
        The text.
    """
    var alphabet = _ALPHABET.as_bytes()
    var out = List[UInt8](capacity=(len(data) + 2) // 3 * 4)
    var index = 0
    while index + 3 <= len(data):
        var block = (
            (UInt32(data[index]) << 16)
            | (UInt32(data[index + 1]) << 8)
            | UInt32(data[index + 2])
        )
        out.append(alphabet[Int((block >> 18) & 63)])
        out.append(alphabet[Int((block >> 12) & 63)])
        out.append(alphabet[Int((block >> 6) & 63)])
        out.append(alphabet[Int(block & 63)])
        index += 3
    var rest = len(data) - index
    if rest > 0:
        var block = UInt32(data[index]) << 16
        if rest == 2:
            block |= UInt32(data[index + 1]) << 8
        out.append(alphabet[Int((block >> 18) & 63)])
        out.append(alphabet[Int((block >> 12) & 63)])
        out.append(alphabet[Int((block >> 6) & 63)] if rest == 2 else 61)
        out.append(61)
    return String(unsafe_from_utf8=out^)


def base64_value(byte: UInt8) -> Int:
    """Return the value of a base64 character.

    Args:
        byte: The character.

    Returns:
        The value, 0 to 63, or -1 for a byte outside the alphabet.
    """
    if byte >= 65 and byte <= 90:
        return Int(byte) - 65
    if byte >= 97 and byte <= 122:
        return Int(byte) - 71
    if byte >= 48 and byte <= 57:
        return Int(byte) + 4
    if byte == 43:
        return 62
    if byte == 47:
        return 63
    return -1

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""SHA-256, for the query hashes of the server.

Apollo Server 5.5.1 `requestPipeline.ts` `computeQueryHash` is
`createHash('sha256').update(query).digest('hex')`. This module implements
SHA-256 from FIPS 180-4, and ports no code.

**Differences from upstream.** None: the hash of the UTF-8 bytes of a
query is the same.
"""

comptime _K: Array[UInt32, 64] = [
    0x428A2F98, 0x71374491, 0xB5C0FBCF, 0xE9B5DBA5,
    0x3956C25B, 0x59F111F1, 0x923F82A4, 0xAB1C5ED5,
    0xD807AA98, 0x12835B01, 0x243185BE, 0x550C7DC3,
    0x72BE5D74, 0x80DEB1FE, 0x9BDC06A7, 0xC19BF174,
    0xE49B69C1, 0xEFBE4786, 0x0FC19DC6, 0x240CA1CC,
    0x2DE92C6F, 0x4A7484AA, 0x5CB0A9DC, 0x76F988DA,
    0x983E5152, 0xA831C66D, 0xB00327C8, 0xBF597FC7,
    0xC6E00BF3, 0xD5A79147, 0x06CA6351, 0x14292967,
    0x27B70A85, 0x2E1B2138, 0x4D2C6DFC, 0x53380D13,
    0x650A7354, 0x766A0ABB, 0x81C2C92E, 0x92722C85,
    0xA2BFE8A1, 0xA81A664B, 0xC24B8B70, 0xC76C51A3,
    0xD192E819, 0xD6990624, 0xF40E3585, 0x106AA070,
    0x19A4C116, 0x1E376C08, 0x2748774C, 0x34B0BCB5,
    0x391C0CB3, 0x4ED8AA4A, 0x5B9CCA4F, 0x682E6FF3,
    0x748F82EE, 0x78A5636F, 0x84C87814, 0x8CC70208,
    0x90BEFFFA, 0xA4506CEB, 0xBEF9A3F7, 0xC67178F2,
]


@always_inline
def _rotr(x: UInt32, n: UInt32) -> UInt32:
    return (x >> n) | (x << (32 - n))


def sha256(data: Span[UInt8, _]) -> List[UInt8]:
    """Return the SHA-256 digest of bytes.

    Args:
        data: The bytes.

    Returns:
        The 32 bytes of the digest.
    """
    var k_array = materialize[_K]()
    var k = k_array.unsafe_ptr()
    var h: List[UInt32] = [
        0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A,
        0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19,
    ]
    # The message, the 0x80 byte, zeros, and the bit length in 8 bytes.
    var message = List[UInt8](capacity=len(data) + 72)
    message.extend(data)
    message.append(0x80)
    while len(message) % 64 != 56:
        message.append(0)
    var bits = UInt64(len(data)) * 8
    var shift = 56
    while shift >= 0:
        message.append(UInt8((bits >> UInt64(shift)) & 0xFF))
        shift -= 8
    var w_list = List[UInt32](length=64, fill=0)
    var w = w_list.unsafe_ptr()
    var m = message.unsafe_ptr()
    var block = 0
    while block < len(message):
        var t = 0
        while t < 16:
            var at = block + t * 4
            w[unsafe_offset=t] = (
                (UInt32(m[unsafe_offset=at]) << 24)
                | (UInt32(m[unsafe_offset=at + 1]) << 16)
                | (UInt32(m[unsafe_offset=at + 2]) << 8)
                | UInt32(m[unsafe_offset=at + 3])
            )
            t += 1
        while t < 64:
            var s0 = _rotr(w[unsafe_offset=t - 15], 7) ^ _rotr(w[unsafe_offset=t - 15], 18) ^ (w[unsafe_offset=t - 15] >> 3)
            var s1 = _rotr(w[unsafe_offset=t - 2], 17) ^ _rotr(w[unsafe_offset=t - 2], 19) ^ (w[unsafe_offset=t - 2] >> 10)
            w[unsafe_offset=t] = w[unsafe_offset=t - 16] + s0 + w[unsafe_offset=t - 7] + s1
            t += 1
        var a = h[0]
        var b = h[1]
        var c = h[2]
        var d = h[3]
        var e = h[4]
        var f = h[5]
        var g = h[6]
        var hh = h[7]
        t = 0
        while t < 64:
            var s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25)
            var choice = (e & f) ^ (~e & g)
            var temp1 = hh + s1 + choice + k[unsafe_offset=t] + w[unsafe_offset=t]
            var s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22)
            var majority = (a & b) ^ (a & c) ^ (b & c)
            var temp2 = s0 + majority
            hh = g
            g = f
            f = e
            e = d + temp1
            d = c
            c = b
            b = a
            a = temp1 + temp2
            t += 1
        h[0] += a
        h[1] += b
        h[2] += c
        h[3] += d
        h[4] += e
        h[5] += f
        h[6] += g
        h[7] += hh
        block += 64
    var out = List[UInt8](capacity=32)
    var index = 0
    while index < 8:
        var word = h[index]
        out.append(UInt8(word >> 24))
        out.append(UInt8((word >> 16) & 0xFF))
        out.append(UInt8((word >> 8) & 0xFF))
        out.append(UInt8(word & 0xFF))
        index += 1
    return out^


def sha256_hex(text: StringSlice) -> String:
    """Return the SHA-256 digest of the UTF-8 bytes of text, in lowercase
    hexadecimal: Node `createHash('sha256').update(text).digest('hex')`.

    Args:
        text: The text, such as a query.

    Returns:
        The 64 hexadecimal digits.
    """
    var digest = sha256(text.as_bytes())
    var digits = StaticString("0123456789abcdef").as_bytes()
    var out = List[UInt8](capacity=64)
    var index = 0
    while index < 32:
        out.append(digits[Int(digest[index] >> 4)])
        out.append(digits[Int(digest[index] & 15)])
        index += 1
    return String(unsafe_from_utf8=out)

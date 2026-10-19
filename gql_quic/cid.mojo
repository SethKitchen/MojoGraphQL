# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Connection IDs and stateless reset tokens (RFC 9000 sections 5.1 and
10.3).

A `ConnectionId` holds up to 20 bytes inline, in a 32-byte vector, so it
has no heap storage, it copies cheaply, it compares in one vector
operation, and it can be a `Dict` key. A `ResetToken` holds 16 bytes
inline, and compares in constant time. `random` makes either one from the
bytes of the kernel's `getrandom`.

This module ports quinn-proto 0.11.19 (8192ed3) quinn-proto/src/shared.rs
(`ConnectionId`), quinn-proto/src/cid_generator.rs
(`RandomConnectionIdGenerator`) and the `ResetToken` of
quinn-proto/src/token.rs (MIT OR Apache-2.0, used under MIT).

Differences from upstream: `ConnectionId.random` stands for
`RandomConnectionIdGenerator.generate_cid`, and takes the length in place
of a generator object. The hashed generator is not ported. A connection ID
made from more than 20 bytes keeps the first 20; upstream asserts in debug
builds. `ResetToken.random` stands for the HMAC of upstream's
`ResetToken::new`: the endpoint keeps the token that it issued.
"""

from std.ffi import external_call
from std.hashlib import Hasher
from std.memory import unsafe_memcpy

comptime MAX_CID_SIZE = 20
"""The largest connection ID, in bytes (RFC 9000 section 17.2)."""
comptime RESET_TOKEN_SIZE = 16
"""The size of a stateless reset token, in bytes."""

comptime _CidBytes = SIMD[DType.uint8, 32]
"""The storage of a connection ID: 20 bytes and 12 bytes of 0."""
comptime _TokenBytes = SIMD[DType.uint8, RESET_TOKEN_SIZE]
"""The storage of a reset token."""


def fill_random(ptr: Pointer[mut=True, UInt8, _], n: Int):
    """Fill bytes with random bytes from the kernel's `getrandom`.

    It calls `getrandom` again until all the bytes are set. A call that
    fails, such as one that a signal stops, sets no bytes.

    Args:
        ptr: The first byte.
        n: The number of bytes.
    """
    var filled = 0
    while filled < n:
        var got = external_call["getrandom", Int](
            ptr.unsafe_offset(filled), n - filled, UInt32(0)
        )
        filled += max(got, 0)


@always_inline
def _hex_digit(nibble: UInt8) -> UInt8:
    """Return the lowercase hexadecimal digit of a nibble."""
    return nibble + 48 + (nibble // 10) * 39


def _write_hex(mut writer: Some[Writer], data: Span[UInt8, _]):
    """Write up to 20 bytes as lowercase hexadecimal, two digits a byte."""
    var buf = _CidBytes(0).join(_CidBytes(0))
    var n = len(data)
    var p = Pointer(to=buf).unsafe_bitcast[UInt8]()
    for i in range(n):
        p[unsafe_offset=2 * i] = _hex_digit(data[i] >> 4)
        p[unsafe_offset=2 * i + 1] = _hex_digit(data[i] & 0xF)
    writer.write(
        StringSlice(
            unsafe_from_utf8=Span[UInt8, origin_of(buf)](
                unsafe_ptr=p, length=2 * n
            )
        )
    )


struct ConnectionId(Equatable, Hashable, ImplicitlyCopyable, Sized, Writable):
    """A connection ID of 0 to 20 bytes."""

    var _bytes: _CidBytes
    """The bytes; the bytes after the length are 0."""
    var _len: Int
    """The length, from 0 to `MAX_CID_SIZE`."""

    def __init__(out self):
        """Make an empty connection ID."""
        self._bytes = _CidBytes(0)
        self._len = 0

    def __init__(out self, data: Span[UInt8, _]):
        """Make a connection ID from bytes.

        Args:
            data: The bytes. Only the first `MAX_CID_SIZE` are kept.
        """
        self._bytes = _CidBytes(0)
        self._len = min(len(data), MAX_CID_SIZE)
        unsafe_memcpy(
            dest=Pointer(to=self._bytes).unsafe_bitcast[UInt8](),
            src=data.unsafe_ptr(),
            count=self._len,
        )

    @staticmethod
    def random(length: Int) -> ConnectionId:
        """Make a connection ID of random bytes.

        Args:
            length: The length, from 0 to `MAX_CID_SIZE`; a larger length
                gives `MAX_CID_SIZE` bytes.

        Returns:
            The connection ID.
        """
        var cid = ConnectionId()
        cid._len = min(max(length, 0), MAX_CID_SIZE)
        fill_random(Pointer(to=cid._bytes).unsafe_bitcast[UInt8](), cid._len)
        return cid

    @always_inline
    def len(self) -> Int:
        """Return the length.

        Returns:
            The number of bytes, from 0 to 20.
        """
        return self._len

    @always_inline
    def __len__(self) -> Int:
        """Return the length.

        Returns:
            The number of bytes, from 0 to 20.
        """
        return self._len

    @always_inline
    def __getitem__(self, index: Int) -> UInt8:
        """Return one byte.

        Args:
            index: An offset below `len()`.

        Returns:
            The byte.
        """
        return self._bytes[index]

    @always_inline
    def bytes(ref self) -> Span[UInt8, origin_of(self._bytes)]:
        """Return the bytes.

        Returns:
            A span of `len()` bytes.
        """
        return Span[UInt8, origin_of(self._bytes)](
            unsafe_ptr=Pointer(to=self._bytes).unsafe_bitcast[UInt8](),
            length=self._len,
        )

    @always_inline
    def __eq__(self, other: ConnectionId) -> Bool:
        """Return True when two connection IDs have the same bytes.

        Args:
            other: The other connection ID.

        Returns:
            Whether the lengths and the bytes are equal.
        """
        return self._len == other._len and self._bytes == other._bytes

    def __hash__[H: Hasher](self, mut hasher: H):
        """Hash the length and the bytes.

        Parameters:
            H: The hasher type.

        Args:
            hasher: The hasher.
        """
        self._len.__hash__(hasher)
        hasher.update(self.bytes())

    def encode_long(self, mut out: List[UInt8]):
        """Append the length byte and the bytes, as a long header does.

        Args:
            out: The destination.
        """
        out.append(UInt8(self._len))
        out.extend(self.bytes())

    def write_to(self, mut writer: Some[Writer]):
        """Write the bytes in lowercase hexadecimal, as upstream.

        Args:
            writer: The destination.
        """
        _write_hex(writer, self.bytes())


struct ResetToken(Equatable, ImplicitlyCopyable, Writable):
    """A stateless reset token of 16 bytes (RFC 9000 section 10.3)."""

    var _bytes: _TokenBytes
    """The bytes."""

    def __init__(out self):
        """Make a token of zero bytes."""
        self._bytes = _TokenBytes(0)

    def __init__(out self, data: Span[UInt8, _]):
        """Make a token from bytes.

        Args:
            data: At least `RESET_TOKEN_SIZE` bytes; only the first 16 are
                kept, and a shorter span leaves the other bytes 0.
        """
        self._bytes = _TokenBytes(0)
        unsafe_memcpy(
            dest=Pointer(to=self._bytes).unsafe_bitcast[UInt8](),
            src=data.unsafe_ptr(),
            count=min(len(data), RESET_TOKEN_SIZE),
        )

    @staticmethod
    def random() -> ResetToken:
        """Make a token of random bytes.

        Returns:
            The token.
        """
        var token = ResetToken()
        fill_random(
            Pointer(to=token._bytes).unsafe_bitcast[UInt8](), RESET_TOKEN_SIZE
        )
        return token

    @always_inline
    def __getitem__(self, index: Int) -> UInt8:
        """Return one byte.

        Args:
            index: An offset below `RESET_TOKEN_SIZE`.

        Returns:
            The byte.
        """
        return self._bytes[index]

    @always_inline
    def bytes(ref self) -> Span[UInt8, origin_of(self._bytes)]:
        """Return the bytes.

        Returns:
            A span of 16 bytes.
        """
        return Span[UInt8, origin_of(self._bytes)](
            unsafe_ptr=Pointer(to=self._bytes).unsafe_bitcast[UInt8](),
            length=RESET_TOKEN_SIZE,
        )

    def __eq__(self, other: ResetToken) -> Bool:
        """Compare two tokens in constant time, as upstream.

        Args:
            other: The other token.

        Returns:
            Whether the bytes are equal.
        """
        return (self._bytes ^ other._bytes).reduce_or() == 0

    def write_to(self, mut writer: Some[Writer]):
        """Write the bytes in lowercase hexadecimal, as upstream.

        Args:
            writer: The destination.
        """
        _write_hex(writer, self.bytes())

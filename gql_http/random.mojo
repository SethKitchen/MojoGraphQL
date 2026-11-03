# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Random bytes from the operating system, for values that must not be
predictable.

Use these functions for session ids, tokens and masking keys. Do not use
`std.random` for them. `std.random` has a fixed seed, so each process
gets the same sequence of numbers.

The bytes come from `getentropy`. Linux (glibc 2.25 and later) and macOS
have it. It gives at most 256 bytes in one call, so a larger request
calls it again. A call that fails sets no bytes, and the function tries
again.

The projects that the ports follow seed `Math.random` or `rand` again in
each process, so their values differ from run to run. The ports use these
functions to keep that behavior.

Differences from upstream: none; there is no upstream.
"""

from std.ffi import external_call

comptime ENTROPY_CALL_MAX = 256
"""The largest number of bytes that one `getentropy` call gives."""


def random_bytes(count: Int) -> List[UInt8]:
    """Return random bytes from the operating system.

    Args:
        count: The number of bytes.

    Returns:
        `count` bytes from `getentropy`.
    """
    var out = List[UInt8](length=count, fill=0)
    var filled = 0
    while filled < count:
        var chunk = min(count - filled, ENTROPY_CALL_MAX)
        var rc = external_call["getentropy", Int32](
            out.unsafe_ptr().unsafe_offset(filled), chunk
        )
        filled += chunk * Int(rc == 0)
    return out^


def random_u64() -> UInt64:
    """Return 64 random bits from the operating system.

    Returns:
        The bits, from `getentropy`.
    """
    var bytes = random_bytes(8)
    var value = UInt64(0)
    var index = 0
    while index < 8:
        value = (value << 8) | UInt64(bytes[index])
        index += 1
    return value

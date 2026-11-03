# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Bearer tokens (RFC 6750) in the `Authorization` header.

Compare a token that a client sent with `tokens_equal`, not with `==`.
`==` stops at the first byte that differs, so its time tells a client how
much of a guess is correct.

Differences from upstream: none; there is no upstream.
"""

from gql_http.scan import equals_ignore_case


def tokens_equal(given: StringSlice, expected: StringSlice) -> Bool:
    """Compare a token with the expected token in constant time.

    The time depends on the lengths only, not on the first byte that
    differs, so a client cannot find the token one byte at a time.

    Args:
        given: The token that the client sent.
        expected: The token that the server issued.

    Returns:
        Whether the two tokens have the same bytes.
    """
    var left = given.as_bytes()
    var right = expected.as_bytes()
    var diff = len(left) ^ len(right)
    for index in range(min(len(left), len(right))):
        diff |= Int(left[index] ^ right[index])
    return diff == 0


def bearer_token(authorization: Optional[String]) -> Optional[String]:
    """Read the token of a `Bearer` value of the `Authorization` header.

    The scheme is case-insensitive (RFC 9110 section 11.1), so
    `bearer abc` has the token `abc` too.

    Args:
        authorization: The header value, when there is one.

    Returns:
        The text after `Bearer `, or none for another scheme or no header.
    """
    if not authorization:
        return None
    var value = authorization.value().copy()
    var bytes = value.as_bytes()
    if len(bytes) < 7 or not equals_ignore_case(
        bytes[:7], StaticString("Bearer ").as_bytes()
    ):
        return None
    return String(value[byte=7:])


def bearer_matches(authorization: Optional[String], token: StringSlice) -> Bool:
    """Return True when an `Authorization` value is `Bearer <token>`.

    Args:
        authorization: The header value, when there is one.
        token: The token that the server expects.

    Returns:
        Whether the value has the `Bearer` scheme and the token. The
        tokens compare in constant time.
    """
    var given = bearer_token(authorization)
    if not given:
        return False
    return tokens_equal(given.value(), token)

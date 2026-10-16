# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Cache hints and the cache policy of a response.

Port of Apollo Server 5.5.1 `cachePolicy.ts` (`newCachePolicy`), the
`CacheHint` and `CachePolicy` types of `@apollo/cache-control-types`
1.0.3, and the `cache-control` response field that `willSendResponse` of
`plugin/cacheControl/index.ts` writes.

**Differences from upstream.** The cache control plugin is built into the
server, as upstream installs it by default. It computes no hints from
`@cacheControl` directives or from resolvers, because `gql_execution` has
no `willResolveField` hook. A plugin can restrict
`GraphQLRequestContext.overall_cache_policy`, and the server writes the
`cache-control` field from it, as upstream does.
"""


@fieldwise_init
struct CacheScope(Equatable, ImplicitlyCopyable, Writable):
    """The scope of a cache hint: `PUBLIC` or `PRIVATE`."""

    var value: UInt8
    """The index of the scope; see `is_valid`."""

    comptime PUBLIC = CacheScope(0)
    """A shared cache can keep the response."""
    comptime PRIVATE = CacheScope(1)
    """Only the cache of one user can keep the response."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the two scopes.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 1

    def text(self) -> StaticString:
        """Return the scope, such as `PUBLIC`.

        Returns:
            The scope, or `<invalid>`.
        """
        if self.value == 0:
            return "PUBLIC"
        if self.value == 1:
            return "PRIVATE"
        return "<invalid>"

    def write_to(self, mut writer: Some[Writer]):
        """Write the scope.

        Args:
            writer: The destination.
        """
        writer.write(self.text())


@fieldwise_init
struct CacheHint(Copyable, ImplicitlyCopyable, Movable):
    """A cache hint: upstream `CacheHint`. Each part can be missing."""

    var max_age: Optional[Int]
    """The most seconds that a cache can keep the response."""
    var scope: Optional[CacheScope]
    """The scope."""


struct CachePolicy(Copyable, ImplicitlyCopyable, Movable):
    """The cache policy of a response: upstream `CachePolicy`."""

    var max_age: Optional[Int]
    """The most seconds that a cache can keep the response."""
    var scope: Optional[CacheScope]
    """The scope."""

    def __init__(out self):
        """Make an uncacheable policy, as `newCachePolicy()`."""
        self.max_age = None
        self.scope = None

    def restrict(mut self, hint: CacheHint):
        """Make the policy at least as strict as a hint: the lower
        `max_age`, and `PRIVATE` once any hint is private.

        Args:
            hint: The hint.
        """
        if hint.max_age and (
            not self.max_age or hint.max_age.value() < self.max_age.value()
        ):
            self.max_age = hint.max_age
        if hint.scope and not (
            self.scope and self.scope.value() == CacheScope.PRIVATE
        ):
            self.scope = hint.scope

    def replace(mut self, hint: CacheHint):
        """Set each part that the hint has.

        Args:
            hint: The hint.
        """
        if hint.max_age:
            self.max_age = hint.max_age
        if hint.scope:
            self.scope = hint.scope

    def policy_if_cacheable(self) -> Optional[CacheHint]:
        """Return the policy when a cache can keep the response.

        Returns:
            The `max_age` and the scope (`PUBLIC` when it is not set), or
            None when `max_age` is missing or 0.
        """
        if not self.max_age or self.max_age.value() == 0:
            return None
        return CacheHint(
            self.max_age, self.scope.or_else(CacheScope.PUBLIC)
        )


@fieldwise_init
struct CalculateHttpHeaders(Equatable, ImplicitlyCopyable, Writable):
    """The `calculateHttpHeaders` option of the cache control plugin."""

    var value: UInt8
    """The index of the mode; see `is_valid`."""

    comptime OFF = CalculateHttpHeaders(0)
    """`false`: the server writes no `cache-control` field."""
    comptime ON = CalculateHttpHeaders(1)
    """`true`, the default: `max-age=N, public` or `no-store`."""
    comptime IF_CACHEABLE = CalculateHttpHeaders(2)
    """`'if-cacheable'`: only the `max-age` form, never `no-store`."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the three modes.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 2

    def write_to(self, mut writer: Some[Writer]):
        """Write the mode as upstream writes the option.

        Args:
            writer: The destination.
        """
        if self.value == 0:
            writer.write("false")
        elif self.value == 1:
            writer.write("true")
        elif self.value == 2:
            writer.write("if-cacheable")
        else:
            writer.write("<invalid>")


def _parse_cacheable(header: String) -> Optional[CacheHint]:
    """Match `max-age=N, public` or `max-age=N, private`."""
    if not header.startswith("max-age="):
        return None
    var bytes = header.as_bytes()
    var index = 8
    var age = 0
    while index < len(bytes) and bytes[index] >= 48 and bytes[index] <= 57:
        age = age * 10 + Int(bytes[index]) - 48
        index += 1
    if index == 8:
        return None
    var rest = String(unsafe_from_utf8=bytes[index:])
    if rest == ", public":
        return CacheHint(age, CacheScope.PUBLIC)
    if rest == ", private":
        return CacheHint(age, CacheScope.PRIVATE)
    return None


def cache_control_header(
    existing: Optional[String],
    overall: CachePolicy,
    single_without_errors: Bool,
    mode: CalculateHttpHeaders,
) -> Optional[String]:
    """Return the `cache-control` field that the cache control plugin
    writes in `willSendResponse`.

    Args:
        existing: The `cache-control` field that the response has.
        overall: The overall cache policy of the request.
        single_without_errors: Whether the response is one result with no
            `errors`.
        mode: The `calculateHttpHeaders` option.

    Returns:
        The new value, or None to keep the field as it is.
    """
    if mode == CalculateHttpHeaders.OFF:
        return None
    var policy = CachePolicy()
    policy.replace(CacheHint(overall.max_age, overall.scope))
    var uncacheable = False
    if existing and existing.value().byte_length() > 0:
        ref text = existing.value()
        uncacheable = text == "no-store"
        if not uncacheable:
            var hint = _parse_cacheable(text)
            if not hint:
                return None
            policy.restrict(hint.value())
    var cacheable = policy.policy_if_cacheable()
    if cacheable and not uncacheable and single_without_errors:
        ref hint = cacheable.value()
        var scope = String(hint.scope.value().text()).lower()
        return "max-age=" + String(hint.max_age.value()) + ", " + scope
    if mode != CalculateHttpHeaders.IF_CACHEABLE:
        return String("no-store")
    return None

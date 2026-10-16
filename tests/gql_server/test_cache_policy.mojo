# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `gql_server.cache_policy`, ported from Apollo Server 5.5.1
`src/__tests__/cachePolicy.test.ts` (`newCachePolicy`), with the
`cache-control` field that `plugin/cacheControl/index.ts` writes, as the
`cache-control` cases of `httpServerTests.ts` check it: `cache-control set
to no-store without any hints`, `cache-control not set without any hints
with if-cacheable`, `contains private cacheControl Headers when scoped`,
`runs when cache-control is disabled`. A plugin gives the hint, as a
resolver gives a dynamic hint upstream.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_true
from _helpers import SDL, json_post, options, resolvers, context
from gql_server.cache_policy import (
    CacheHint,
    CachePolicy,
    CacheScope,
    CalculateHttpHeaders,
    cache_control_header,
)
from gql_server.plugin import ServerPlugin
from gql_server.server import ApolloServer
from gql_server.types import GraphQLRequestContext


def _hint(max_age: Optional[Int], scope: Optional[CacheScope] = None) -> CacheHint:
    return CacheHint(max_age, scope)


def test_starts_uncacheable() raises:
    var policy = CachePolicy()
    assert_false(Bool(policy.max_age))
    assert_false(Bool(policy.scope))
    assert_false(Bool(policy.policy_if_cacheable()))


def test_lowest_max_age() raises:
    var policy = CachePolicy()
    policy.restrict(_hint(10))
    policy.restrict(_hint(20))
    assert_equal(policy.max_age.value(), 10)
    policy = CachePolicy()
    policy.restrict(_hint(20))
    policy.restrict(_hint(10))
    assert_equal(policy.max_age.value(), 10)
    policy = CachePolicy()
    policy.restrict(_hint(120))
    policy.restrict(_hint(0))
    policy.restrict(_hint(20))
    assert_equal(policy.max_age.value(), 0)
    policy = CachePolicy()
    policy.restrict(_hint(0))
    policy.restrict(_hint(20))
    assert_equal(policy.max_age.value(), 0)
    policy.restrict(_hint(None))
    assert_equal(policy.max_age.value(), 0)
    assert_false(Bool(policy.scope))


def test_private_scope_wins() raises:
    var policy = CachePolicy()
    policy.restrict(_hint(10, CacheScope.PUBLIC))
    policy.restrict(_hint(10, CacheScope.PRIVATE))
    policy.restrict(_hint(10, CacheScope.PUBLIC))
    assert_true(policy.scope.value() == CacheScope.PRIVATE)


def test_policy_if_cacheable() raises:
    var policy = CachePolicy()
    policy.restrict(_hint(None, CacheScope.PRIVATE))
    assert_false(Bool(policy.policy_if_cacheable()))
    policy.restrict(_hint(10))
    var cacheable = policy.policy_if_cacheable().value()
    assert_equal(cacheable.max_age.value(), 10)
    assert_true(cacheable.scope.value() == CacheScope.PRIVATE)
    policy.restrict(_hint(0))
    assert_false(Bool(policy.policy_if_cacheable()))
    policy = CachePolicy()
    policy.restrict(_hint(5))
    assert_true(policy.policy_if_cacheable().value().scope.value() == CacheScope.PUBLIC)


def test_replace() raises:
    var policy = CachePolicy()
    policy.restrict(_hint(10, CacheScope.PRIVATE))
    policy.replace(_hint(20, CacheScope.PUBLIC))
    assert_equal(policy.max_age.value(), 20)
    assert_true(policy.scope.value() == CacheScope.PUBLIC)
    policy.replace(_hint(None))
    assert_equal(policy.max_age.value(), 20)


def test_types() raises:
    assert_equal(String(CacheScope.PUBLIC), "PUBLIC")
    assert_equal(String(CacheScope.PRIVATE), "PRIVATE")
    assert_equal(String(CacheScope(2)), "<invalid>")
    assert_true(CacheScope.PRIVATE.is_valid())
    assert_false(CacheScope(2).is_valid())
    assert_equal(String(CalculateHttpHeaders.OFF), "false")
    assert_equal(String(CalculateHttpHeaders.ON), "true")
    assert_equal(String(CalculateHttpHeaders.IF_CACHEABLE), "if-cacheable")
    assert_equal(String(CalculateHttpHeaders(3)), "<invalid>")
    assert_true(CalculateHttpHeaders.IF_CACHEABLE.is_valid())
    assert_false(CalculateHttpHeaders(3).is_valid())


def _header(
    existing: Optional[String],
    max_age: Optional[Int],
    single_without_errors: Bool = True,
    mode: CalculateHttpHeaders = CalculateHttpHeaders.ON,
) -> String:
    var policy = CachePolicy()
    policy.restrict(_hint(max_age))
    return cache_control_header(existing, policy, single_without_errors, mode).or_else("<none>")


def test_cache_control_header() raises:
    assert_equal(_header(None, None), "no-store")
    assert_equal(_header(String(""), None), "no-store")
    assert_equal(_header(None, 10), "max-age=10, public")
    assert_equal(_header(None, 10, False), "no-store")
    assert_equal(_header(None, None, True, CalculateHttpHeaders.IF_CACHEABLE), "<none>")
    assert_equal(_header(None, 10, True, CalculateHttpHeaders.IF_CACHEABLE), "max-age=10, public")
    assert_equal(_header(None, 10, True, CalculateHttpHeaders.OFF), "<none>")
    assert_equal(_header(String("no-store"), 10), "no-store")
    assert_equal(_header(String("max-age=5, private"), 10), "max-age=5, private")
    assert_equal(_header(String("max-age=50, public"), 10), "max-age=10, public")
    assert_equal(_header(String("private, no-cache, must-revalidate"), 10), "<none>")
    assert_equal(_header(String("max-age=x"), 10), "<none>")
    assert_equal(_header(String("max-age=5, shared"), 10), "<none>")


struct Hinter(ServerPlugin):
    """Gives a cache hint, as a resolver gives a dynamic hint upstream."""

    var hint: CacheHint

    def __init__(out self, hint: CacheHint):
        self.hint = hint

    def did_resolve_source(mut self, mut ctx: GraphQLRequestContext) raises:
        ctx.overall_cache_policy.restrict(self.hint)


def _served(
    hint: CacheHint, mode: CalculateHttpHeaders, body: String = '{"query":"{ testString }"}'
) raises -> String:
    var opts = options()
    opts.calculate_http_headers = mode
    var server = ApolloServer[Hinter].from_type_defs(SDL, resolvers(), opts^, Hinter(hint))
    server.start()
    var response = server.execute_http_graphql_request(json_post(body), context)
    return response.headers.get("cache-control").or_else("<none>")


def test_cache_control_over_http() raises:
    assert_equal(_served(_hint(None), CalculateHttpHeaders.ON), "no-store")
    assert_equal(_served(_hint(None), CalculateHttpHeaders.IF_CACHEABLE), "<none>")
    assert_equal(_served(_hint(11), CalculateHttpHeaders.ON), "max-age=11, public")
    assert_equal(
        _served(_hint(11, CacheScope.PRIVATE), CalculateHttpHeaders.ON),
        "max-age=11, private",
    )
    assert_equal(_served(_hint(11), CalculateHttpHeaders.OFF), "<none>")
    assert_equal(
        _served(_hint(11), CalculateHttpHeaders.ON, '{"query":"{ testError }"}'),
        "no-store",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

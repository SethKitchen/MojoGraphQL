# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of automatic persisted queries, ported from Apollo Server 5.5.1
`packages/integration-testsuite/src/httpServerTests.ts` (`Persisted
Queries`, `returns PersistedQueryNotSupported`, `returns
PersistedQueryNotFound`). Every expected response comes from Apollo Server
5.5.1.

Upstream cases that are not ported: `when ttlSeconds is set, passes ttl
to the apq cache set call` and its pair spy on a custom cache, which is
not an option; `test_lru.mojo` tests the time to live.
"""

from std.testing import TestSuite, assert_equal, assert_true
from _helpers import (
    check,
    error_body,
    json_post,
    make_server,
    options,
    preflight_get,
    run,
)
from gql_server.sha256 import sha256_hex

comptime HASH = "c9249f0e3e3d70411aa80001fdeae3ee8f59057bb59ca0df53a8cdf9fb82ca2b"
"""The SHA-256 of `{testString}`."""
comptime OK_STRING = '{"data":{"testString":"it works"}}'
"""The result of `{testString}`."""
comptime PRIVATE = "private, no-cache, must-revalidate"
"""The `cache-control` field of the persisted query errors."""


def _extensions(version: String, hash: String) -> String:
    return (
        '{"persistedQuery":{"version":' + version + ',"sha256Hash":"' + hash + '"}}'
    )


def test_hash_is_sha256() raises:
    assert_equal(sha256_hex("{testString}"), HASH)


def test_not_found_then_found() raises:
    var server = make_server()
    var lookup = '{"extensions":' + _extensions("1", HASH) + "}"
    var not_found = error_body("PersistedQueryNotFound", "PERSISTED_QUERY_NOT_FOUND")
    check(run(server, json_post(lookup)), 200, PRIVATE, not_found)
    var get = "?extensions=%7B%22persistedQuery%22:%7B%22version%22:1,%22sha256Hash%22:%22" + HASH + "%22%7D%7D"
    check(run(server, preflight_get(get)), 200, PRIVATE, not_found)
    var register = (
        '{"query":"{testString}","extensions":' + _extensions("1", HASH) + "}"
    )
    check(run(server, json_post(register)), 0, "no-store", OK_STRING)
    check(run(server, json_post(lookup)), 0, "no-store", OK_STRING)
    check(run(server, preflight_get(get)), 0, "no-store", OK_STRING)


def test_hash_mismatch() raises:
    var server = make_server()
    check(
        run(
            server,
            json_post('{"query":"{testString}","extensions":' + _extensions("1", "abc") + "}"),
        ),
        400,
        "no-store",
        error_body("provided sha does not match query", "INTERNAL_SERVER_ERROR"),
    )
    # A hash that is not a string never matches.
    check(
        run(
            server,
            json_post(
                '{"query":"{testString}","extensions":{"persistedQuery":'
                + '{"version":1,"sha256Hash":5}}}'
            ),
        ),
        400,
        "no-store",
        error_body("provided sha does not match query", "INTERNAL_SERVER_ERROR"),
    )


def test_unsupported_versions() raises:
    var server = make_server()
    var expected = error_body(
        "Unsupported persisted query version", "INTERNAL_SERVER_ERROR"
    )
    for extensions in [
        '{"persistedQuery":{"sha256Hash":"abc"}}',
        '{"persistedQuery":{"version":2,"sha256Hash":"abc"}}',
        '{"persistedQuery":{"version":"1","sha256Hash":"abc"}}',
        '{"persistedQuery":true}',
    ]:
        check(
            run(
                server,
                json_post('{"query":"{testString}","extensions":' + String(extensions) + "}"),
            ),
            400,
            "no-store",
            expected,
        )


def test_falsy_persisted_query_is_ignored() raises:
    var server = make_server()
    for value in ["false", "0", '""', "null"]:
        check(
            run(
                server,
                json_post(
                    '{"query":"{testString}","extensions":{"persistedQuery":'
                    + String(value)
                    + "}}"
                ),
            ),
            0,
            "no-store",
            OK_STRING,
        )


def test_not_supported() raises:
    var opts = options()
    opts.persisted_queries = False
    var server = make_server(opts^)
    var expected = error_body(
        "PersistedQueryNotSupported", "PERSISTED_QUERY_NOT_SUPPORTED"
    )
    check(
        run(server, json_post('{"extensions":' + _extensions("1", "abc") + "}")),
        200,
        PRIVATE,
        expected,
    )
    check(
        run(
            server,
            preflight_get(
                "?extensions=%7B%22persistedQuery%22:%7B%22version%22:1,"
                + "%22sha256Hash%22:%22abc%22%7D%7D"
            ),
        ),
        200,
        PRIVATE,
        expected,
    )


def test_batched_persisted_queries() raises:
    var opts = options()
    opts.allow_batched_http_requests = True
    var server = make_server(opts^)
    var response = run(
        server,
        json_post(
            '[{"extensions":' + _extensions("1", HASH) + '},{"query":"{testString}"}]'
        ),
    )
    assert_equal(response.status, 200)
    assert_equal(response.headers.get("cache-control").value(), PRIVATE)
    assert_true(response.body.startswith('[{"errors":[{"message":"PersistedQueryNotFound"'))


def test_empty_registered_query_is_not_found() raises:
    var server = make_server()
    var empty = sha256_hex("")
    var register = '{"query":"","extensions":' + _extensions("1", empty) + "}"
    # An empty query passes the hash check and is stored.
    _ = run(server, json_post(register))
    check(
        run(server, json_post('{"extensions":' + _extensions("1", empty) + "}")),
        200,
        PRIVATE,
        error_body("PersistedQueryNotFound", "PERSISTED_QUERY_NOT_FOUND"),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

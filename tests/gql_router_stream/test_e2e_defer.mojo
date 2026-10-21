# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""End-to-end `@defer` through the router: the initial payload, then the
deferred fields, as `multipart/mixed`, as SSE, and as one response.

Hive Router `1a29df9` has no `@defer` execution and no test of it. The
payloads follow the incremental delivery RFC and graphql-js
17.0.0-alpha.14 `defer-test.ts`.
"""

from _client import post
from _e2e import start_router, start_subgraphs
from std.testing import TestSuite, assert_equal

comptime QUERY = '{ topProducts { upc ... @defer(label: "late") { name } } }'
comptime INITIAL = (
    '{"data":{"topProducts":[{"upc":"1"}]},"pending":[{"id":"0","path":'
    + '["topProducts",0],"label":"late"}],"hasNext":true}'
)
comptime LATER = (
    '{"hasNext":false,"incremental":[{"id":"0","data":{"name":"Table"}}],'
    + '"completed":[{"id":"0"}]}'
)


def test_defer_over_multipart_sse_and_json() raises:
    var subgraphs = start_subgraphs()
    var router = start_router(subgraphs.port, "{}")
    var multipart = post(router.port, QUERY, "multipart/mixed")
    var sse = post(router.port, QUERY, "text/event-stream")
    var single = post(router.port, QUERY, "application/json")
    var inactive = post(
        router.port,
        "{ topProducts { upc ... @defer(if: false) { name } } }",
        "multipart/mixed",
    )
    router.stop()
    subgraphs.stop()
    var head = "---\r\nContent-Type: application/json\r\n\r\n"
    assert_equal(multipart.content_type, 'multipart/mixed;boundary="-"')
    assert_equal(
        multipart.body,
        head + INITIAL + "\r\n" + head + LATER + "\r\n-----",
    )
    assert_equal(
        sse.body,
        "event: next\ndata: "
        + INITIAL
        + "\n\nevent: next\ndata: "
        + LATER
        + "\n\nevent: complete\n\n",
    )
    assert_equal(single.content_type, "application/json")
    assert_equal(
        single.body, '{"data":{"topProducts":[{"upc":"1","name":"Table"}]}}'
    )
    assert_equal(
        inactive.body,
        head
        + '{"data":{"topProducts":[{"upc":"1","name":"Table"}]}}'
        + "\r\n-----",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

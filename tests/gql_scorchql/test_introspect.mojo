# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the subgraph SDL query, `gql_scorchql.introspect`.

The `_service { sdl }` query is the one of the Apollo Federation subgraph
specification. ScorchQL has no upstream test suite to port.
"""

from _fixtures import FakeSubgraphs, PRODUCTS_SDL, loopback
from gql_http.client import Client
from gql_http.server import start_workers
from gql_scorchql.introspect import (
    SERVICE_QUERY,
    fetch_subgraph_sdl,
    read_service_sdl,
)
from std.testing import TestSuite, assert_equal, assert_raises


def _body(text: StringSlice) -> List[UInt8]:
    return List[UInt8](text.as_bytes())


def test_the_query() raises:
    assert_equal(
        SERVICE_QUERY,
        '{"query":"query SubgraphIntrospectQuery { _service { sdl } }"}',
    )


def test_read_service_sdl() raises:
    assert_equal(
        read_service_sdl(
            200, _body('{"data":{"_service":{"sdl":"type Query { a: Int }"}}}')
        ),
        "type Query { a: Int }",
    )
    assert_equal(
        read_service_sdl(
            299, _body('{"data":{"_service":{"sdl":"x"}},"errors":[]}')
        ),
        "x",
    )


def test_read_service_sdl_errors() raises:
    with assert_raises(contains="answered HTTP 500"):
        _ = read_service_sdl(500, _body("{}"))
    with assert_raises(contains="answered HTTP 199"):
        _ = read_service_sdl(199, _body("{}"))
    with assert_raises(contains="answered HTTP 300"):
        _ = read_service_sdl(300, _body("{}"))
    with assert_raises():
        _ = read_service_sdl(200, _body("not json"))
    with assert_raises(contains="not a JSON object"):
        _ = read_service_sdl(200, _body("[]"))
    with assert_raises(contains="the subgraph answered: no"):
        _ = read_service_sdl(200, _body('{"errors":[{"message":"no"}]}'))
    var missing = "has no data._service.sdl"
    with assert_raises(contains=missing):
        _ = read_service_sdl(200, _body('{"errors":[{"code":1}]}'))
    with assert_raises(contains=missing):
        _ = read_service_sdl(200, _body('{"errors":[1]}'))
    with assert_raises(contains=missing):
        _ = read_service_sdl(200, _body('{"errors":{}}'))
    with assert_raises(contains=missing):
        _ = read_service_sdl(200, _body('{"errors":[{"message":2}]}'))
    with assert_raises(contains=missing):
        _ = read_service_sdl(200, _body('{"data":null}'))
    with assert_raises(contains=missing):
        _ = read_service_sdl(200, _body('{"data":{"_service":null}}'))
    with assert_raises(contains=missing):
        _ = read_service_sdl(200, _body('{"data":{"_service":{}}}'))
    with assert_raises(contains=missing):
        _ = read_service_sdl(200, _body('{"data":{"_service":{"sdl":1}}}'))


def test_fetch_subgraph_sdl() raises:
    var pool = start_workers(FakeSubgraphs(), loopback())
    var base = "http://127.0.0.1:" + String(pool.port)
    var client = Client()
    assert_equal(fetch_subgraph_sdl(client, base + "/products"), PRODUCTS_SDL)
    with assert_raises(contains="down for repair"):
        _ = fetch_subgraph_sdl(client, base + "/broken")
    client.close_idle()
    assert_equal(pool.stop(), 0)
    with assert_raises(contains="cannot connect"):
        _ = fetch_subgraph_sdl(client, "http://127.0.0.1:9/")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

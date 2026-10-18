# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `seamstress subgraph introspect` and `seamstress graph introspect`.

Each command runs against the stub endpoint of `_endpoint.mojo`, and its
output must equal what Rover 1.0.0 prints for the same endpoint
(`_snapshots.mojo`). The fallback cases port the tests of Rover
`crates/rover-client/src/operations/graph/introspect/runner.rs`.
"""

from _endpoint import start_endpoint
from _snapshots import snapshots
from gql_http.client import Client
from gql_seamstress.cli import run_seamstress
from gql_seamstress.config import Header
from gql_seamstress.introspect import fetch_graph_sdl, fetch_subgraph_sdl
from gql_seamstress.introspect import graph_introspect
from gql_seamstress.output import OutputFormat
from std.testing import TestSuite, assert_equal, assert_true


def _run(command: String, url: String, format: String) raises -> List[String]:
    var args: List[String] = [
        command,
        "introspect",
        url,
        "--format",
        format,
        "-H",
        "x-token:abc",
        "--header",
        "X-Two: b c",
    ]
    var out = run_seamstress(args)
    return [out.stdout, out.stderr, String(out.exit_code) + "\n"]


def test_snapshots() raises:
    var pool = start_endpoint()
    var base = "http://127.0.0.1:" + String(pool.port) + "/"
    var expected = snapshots()
    var cases: List[String] = [
        "subgraph:subgraph/products",
        "subgraph:headers",
        "subgraph:no-service",
        "subgraph:partial",
        "subgraph:null",
        "subgraph:no-data",
        "subgraph:invalid",
        "subgraph:unauthorized",
        "subgraph:status",
        "graph:graph",
        "graph:partial",
        "graph:null",
        "graph:no-data",
        "graph:invalid",
        "graph:status",
        "graph:no-service",
        "subgraph:no-service-partial",
        "subgraph:empty-data",
        "subgraph:too-large",
        "subgraph:errors-null",
        "subgraph:errors-empty",
        "subgraph:invalid-credentials",
        "subgraph:array",
        "graph:small",
        "graph:too-large",
        "graph:data-null",
        "graph:array",
    ]
    for ref item in cases:
        var colon = item.find(":")
        var command = String(item[byte=:colon])
        var path = String(item[byte = colon + 1 :])
        var name = command + "-" + path.replace("/", "_")
        for format in ["plain", "json"]:
            var got = _run(command, base + path, format)
            var key = name + "." + format
            assert_equal(got[0], expected[key + ".out"], key + ".out")
            assert_equal(got[1], expected[key + ".err"], key + ".err")
            assert_equal(got[2], expected[key + ".rc"], key + ".rc")
    _ = pool.stop()


def test_legacy_fallback() raises:
    var pool = start_endpoint()
    var base = "http://127.0.0.1:" + String(pool.port) + "/"
    var expected = snapshots()
    var fallback = _run("graph", base + "legacy", "plain")
    assert_equal(fallback[0], expected["graph-graph.plain.out"])
    assert_equal(fallback[2], "0\n")
    var args: List[String] = [
        "graph",
        "introspect",
        base + "graph",
        "--legacy-introspection-query",
    ]
    assert_equal(run_seamstress(args).stdout, expected["graph-graph.plain.out"])
    var refused: List[String] = [
        "graph",
        "introspect",
        base + "legacy",
        "--legacy-introspection-query",
        "--format=json",
    ]
    assert_equal(
        run_seamstress(refused).stdout, expected["graph-graph.json.out"]
    )
    _ = pool.stop()


def test_connection_refused() raises:
    var out = run_seamstress(["subgraph", "introspect", "http://127.0.0.1:1/x"])
    assert_equal(
        out.stderr,
        (
            "error: Service error\n\nCaused by:\n    0: Upstream service"
            " error\n    1: Connect error\n"
        ),
    )
    assert_equal(out.exit_code, 1)


def test_edge_responses() raises:
    var pool = start_endpoint()
    var base = "http://127.0.0.1:" + String(pool.port) + "/"
    var client = Client()
    var headers = List[Header]()
    var number = fetch_subgraph_sdl(client, base + "sdl-number", headers)
    assert_equal(
        number.error.value().message, "No introspection response available."
    )
    var missing = fetch_subgraph_sdl(client, base + "service-no-sdl", headers)
    assert_equal(
        missing.error.value().message, "No introspection response available."
    )
    var array = fetch_subgraph_sdl(client, base + "array", headers)
    assert_equal(
        array.error.value().causes[0],
        (
            "Deserialization error: the response (HTTP 200 OK) had a data error"
            " at line 1, column 2"
        ),
    )
    var null_data = fetch_graph_sdl(client, base + "data-null", headers, False)
    assert_equal(null_data.error.value().causes[0], "No data field provided")
    var odd = fetch_graph_sdl(client, base + "errors-odd", headers, False)
    assert_equal(
        odd.error.value().causes[0], "Data was returned, but with errors: "
    )
    var bad = fetch_graph_sdl(client, base + "bad-kind", headers, False)
    assert_equal(bad.error.value().message, "Unknown type kind: WHAT")
    assert_equal(bad.error.value().code, "E011")
    var typed: List[Header] = [
        Header("Content-Type", "application/json; charset=utf-8")
    ]
    var ok = fetch_subgraph_sdl(client, base + "subgraph/products", typed)
    assert_true(ok.sdl.startswith("extend schema"))
    var invalid: List[Header] = [Header("bad name", "x")]
    var refused = fetch_subgraph_sdl(
        client, base + "subgraph/products", invalid
    )
    assert_equal(refused.error.value().causes[0], "Upstream service error")
    assert_true(refused.error.value().causes[1] != "Connect error")
    var unknown = graph_introspect(
        base + "unknown-type", headers, False, OutputFormat.JSON
    )
    assert_equal(unknown.error.value().code, "E011")
    _ = pool.stop()


def test_invalid_credentials() raises:
    # Port of `test_invalid_credentials_with_null_data` and
    # `test_invalid_credentials_with_partial_data` of Rover
    # `crates/rover-graphql/src/lib.rs`.
    var pool = start_endpoint()
    var base = "http://127.0.0.1:" + String(pool.port) + "/"
    var client = Client()
    var headers = List[Header]()
    for prefix in ["creds/", "creds-partial/"]:
        for number in range(4):
            var url = base + prefix + String(number)
            var got = fetch_graph_sdl(client, url, headers, False)
            var cause = got.error.value().causes[0]
            assert_true(
                cause.startswith("Invalid credentials provided. See"), url
            )
    _ = pool.stop()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

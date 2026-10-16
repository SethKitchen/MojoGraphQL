# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_mcp.operation_source`.

`test_deduplication_of_overlapping_paths` is ported from Apollo MCP Server
2.0.0 (04e4e6e) `crates/apollo-mcp-server/src/operations/operation_source.rs`.
Its manifest tests and the collection tests of `operations/raw_operation.rs`
are phase 2, with those sources.
"""

from std.os import makedirs, remove, rmdir, listdir
from std.time import perf_counter_ns
from gql_mcp.operation_source import load_operations
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _directory(name: String) raises -> String:
    var path = "/tmp/gql_mcp_source_" + name + "_" + String(perf_counter_ns())
    makedirs(path)
    return path^


def _clean(directory: String) raises:
    for name in listdir(directory):
        remove(directory + "/" + name)
    rmdir(directory)


def _write(path: String, text: String) raises:
    with open(path, "w") as file:
        file.write(text)


def test_deduplication_of_overlapping_paths() raises:
    var directory = _directory("dedup")
    var file = directory + "/TestOperation.graphql"
    _write(file, "query TestOperation { __typename }\n")
    var paths = List[String]()
    paths.append(directory)
    paths.append(file)
    var operations = load_operations(paths)
    assert_equal(len(operations), 1)
    assert_true(
        operations[0].source_path.value().endswith("TestOperation.graphql")
    )
    _clean(directory)


def test_directory_and_files() raises:
    var directory = _directory("dir")
    _write(directory + "/b.graphql", "query B { b }")
    _write(directory + "/a.graphql", "query A { a }")
    _write(directory + "/empty.graphql", "  \n ")
    _write(directory + "/notes.txt", "query N { n }")
    var single = directory + "/notes.txt"
    var blank = directory + "/empty.graphql"
    var paths = List[String]()
    paths.append(directory)
    paths.append(single)
    paths.append(blank)
    var operations = load_operations(paths)
    assert_equal(len(operations), 3)
    assert_equal(operations[0].source_text, "query A { a }")
    assert_equal(operations[1].source_text, "query B { b }")
    assert_equal(operations[2].source_text, "query N { n }")
    assert_equal(len(load_operations(List[String]())), 0)
    _clean(directory)


def test_unreadable_paths() raises:
    var directory = _directory("bad")
    var paths = List[String]()
    paths.append(directory + "/missing.graphql")
    var failed = String("no error")
    try:
        _ = load_operations(paths)
    except e:
        failed = e.source_path.value()
    assert_equal(failed, directory + "/missing.graphql")
    var only = List[String]()
    only.append("/root")
    assert_equal(len(load_operations(only)), 0)
    rmdir(directory)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_forge.cli`."""

from std.os import setenv, unsetenv

from gql_forge.cli import (
    USAGE,
    VERSION,
    default_options,
    forge_config,
    parse_cli,
    parse_host,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _list(
    a: String, b: String = "", c: String = "", d: String = ""
) -> List[String]:
    var out = List[String]()
    out.append(a)
    if b.byte_length() > 0:
        out.append(b)
    if c.byte_length() > 0:
        out.append(c)
    if d.byte_length() > 0:
        out.append(d)
    return out^


def test_parse_cli() raises:
    assert_true(parse_cli(_list("--help")).help)
    assert_true(parse_cli(_list("-h")).help)
    assert_true(parse_cli(_list("--version")).version)
    assert_true(parse_cli(_list("-V")).version)
    assert_true("--advertise-ip" in USAGE)
    assert_true("starts no graph" in USAGE)
    assert_true("-V" in USAGE)
    assert_true(parse_cli(_list("serve")).error.find("Unknown argument") >= 0)
    assert_true(parse_cli(_list("--port")).error.find("Missing value") >= 0)
    assert_true(parse_cli(_list("--nope", "1")).error.find("Unknown flag") >= 0)
    assert_true(parse_cli(_list("--port", "x")).error.find("Invalid port") >= 0)
    assert_true(
        parse_cli(_list("--workers", "x")).error.find("Invalid workers") >= 0
    )
    assert_true(
        parse_cli(_list("--pull-timeout", "x")).error.find(
            "Invalid pull timeout"
        )
        >= 0
    )
    var args = List[String]()
    args.append("--data=.cache/f")
    args.append("--host")
    args.append("127.0.0.1")
    args.append("--port=4101")
    args.append("--workers")
    args.append("2")
    args.append("--title")
    args.append("Lab")
    args.append("--token")
    args.append("secret")
    args.append("--advertise-ip")
    args.append("203.0.113.10")
    args.append("--pull-timeout")
    args.append("1000")
    var ok = parse_cli(args)
    assert_equal(ok.error, "")
    assert_equal(ok.data_directory, ".cache/f")
    assert_equal(ok.host, "127.0.0.1")
    assert_equal(ok.port, 4101)
    assert_equal(ok.workers, 2)
    assert_equal(ok.title, "Lab")
    assert_true(ok.token)
    assert_equal(ok.advertise_ip, "203.0.113.10")
    var config = forge_config(ok)
    assert_equal(config.title, "Lab")
    assert_true(config.admin_token)
    var bare = forge_config(parse_cli(List[String]()))
    assert_false(bare.admin_token)
    _ = default_options()
    _ = USAGE
    _ = VERSION
    _ = setenv("FORGE_TOKEN", "from-env")
    var env = default_options()
    assert_true(env.token)
    _ = unsetenv("FORGE_TOKEN")


def test_parse_host() raises:
    assert_true(parse_host("127.0.0.1"))
    assert_true(parse_host("0.0.0.0"))
    assert_false(parse_host("localhost"))
    assert_false(parse_host("1.2.3"))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

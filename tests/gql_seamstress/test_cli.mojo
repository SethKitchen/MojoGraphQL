# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the command line of the offline Rover commands.

The usage errors are what Rover 1.0.0 (clap) writes for the same
arguments. The header cases port `parse_header` of Rover
`src/utils/parsers.rs`.
"""

from gql_seamstress.cli import HELP, VERSION, parse_header, run_seamstress
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _stderr(args: List[String]) raises -> String:
    var out = run_seamstress(args)
    assert_equal(out.exit_code, 2)
    return out.stderr


def test_required_arguments() raises:
    assert_equal(
        _stderr(["supergraph", "compose"]),
        (
            "error: the following required arguments were not provided:\n "
            " <--config <SUPERGRAPH_YAML>|--graph-ref <GRAPH_REF>>\n\nUsage:"
            " seamstress supergraph compose <--config"
            " <SUPERGRAPH_YAML>|--graph-ref <GRAPH_REF>>\n\nFor more"
            " information, try '--help'.\n"
        ),
    )
    assert_equal(
        _stderr(["graph", "introspect"]),
        (
            "error: the following required arguments were not provided:\n "
            " <ENDPOINT>\n\nUsage: seamstress graph introspect"
            " <ENDPOINT>\n\nFor more information, try '--help'.\n"
        ),
    )


def test_invalid_values() raises:
    assert_equal(
        _stderr(["graph", "introspect", "notaurl"]),
        (
            "error: invalid value 'notaurl' for '<ENDPOINT>': relative URL"
            " without a base\n\nFor more information, try '--help'.\n"
        ),
    )
    assert_equal(
        _stderr(["subgraph", "introspect", "http://x", "-H", "bad"]),
        (
            "error: invalid value 'bad' for '--header <KEY:VALUE>': Could not"
            ' parse "key:value" pair for provided header: "bad". Headers'
            " must be provided in key:value pairs, with quotes around the pair"
            " if there are any spaces in the key or value.\n\nFor more"
            " information, try '--help'.\n"
        ),
    )
    assert_equal(
        _stderr(["graph", "introspect", "http://x", "--format", "xml"]),
        (
            "error: invalid value 'xml' for '--format <FORMAT_KIND>'\n "
            " [possible values: plain, json]\n\nFor more information, try"
            " '--help'.\n"
        ),
    )
    assert_equal(
        _stderr(
            [
                "supergraph",
                "compose",
                "--config",
                "a",
                "--federation-version",
                "9",
            ]
        ),
        (
            "error: invalid value '9' for '--federation-version"
            " <FEDERATION_VERSION>': Specified version `9` is not supported."
            " You can specify '2', '3', or a fully qualified version prefixed"
            " with an '=', like: =2.0.0\n\nFor more information, try"
            " '--help'.\n"
        ),
    )


def test_unexpected_arguments() raises:
    assert_equal(
        _stderr(["graph", "introspect", "http://x", "--bogus"]),
        (
            "error: unexpected argument '--bogus' found\n\n  tip: to pass"
            " '--bogus' as a value, use '-- --bogus'\n\nUsage: seamstress graph"
            " introspect <ENDPOINT>\n\nFor more information, try '--help'.\n"
        ),
    )
    assert_equal(
        _stderr(["subgraph", "introspect", "http://x", "http://y"]),
        (
            "error: unexpected argument 'http://y' found\n\nUsage: seamstress"
            " subgraph introspect <ENDPOINT>\n\nFor more information, try"
            " '--help'.\n"
        ),
    )
    assert_true(
        _stderr(
            [
                "subgraph",
                "introspect",
                "http://x",
                "--legacy-introspection-query",
            ]
        ).startswith(
            "error: unexpected argument '--legacy-introspection-query'"
        )
    )
    assert_true(
        _stderr(["graph", "introspect", "http://x", "--watch"]).startswith(
            "error: unexpected argument '--watch'"
        )
    )
    assert_true(
        _stderr(["supergraph", "compose", "--graph-ref", "g@v"]).startswith(
            "error: unexpected argument '--graph-ref'"
        )
    )
    assert_equal(
        _stderr(["subgraph", "fetch"]),
        (
            "error: unrecognized subcommand 'fetch'\n\nUsage: seamstress"
            " [OPTIONS] <COMMAND>\n\nFor more information, try '--help'.\n"
        ),
    )
    assert_true(
        _stderr(["graph", "introspect", "http://x", "--header"]).startswith(
            "error: unexpected argument '--header'"
        )
    )
    assert_true(
        _stderr(["supergraph", "x"]).startswith(
            "error: unrecognized subcommand 'x'"
        )
    )
    assert_true(
        _stderr(["dev"]).startswith("error: unrecognized subcommand 'dev'")
    )
    assert_true(
        _stderr(["graph"]).startswith("error: unrecognized subcommand 'graph'")
    )


def test_help_and_version() raises:
    var empty = run_seamstress(List[String]())
    assert_equal(empty.stderr, HELP)
    assert_equal(empty.exit_code, 2)
    for flag in ["--help", "-h", "help"]:
        var out = run_seamstress([flag])
        assert_equal(out.stdout, HELP)
        assert_equal(out.exit_code, 0)
    for flag in ["--version", "-V"]:
        assert_equal(run_seamstress([flag]).stdout, VERSION + "\n")


def test_global_options() raises:
    var args: List[String] = [
        "--log",
        "debug",
        "-l",
        "info",
        "--profile",
        "p",
        "--no-color",
        "--skip-update-check",
        "--insecure-accept-invalid-certs",
        "--format=plain",
        "graph",
        "introspect",
        "--format",
        "json",
        "-o",
        "/tmp/gql_seamstress_cli_out.json",
        "--output=/tmp/gql_seamstress_cli_out.json",
        "http://127.0.0.1:1/",
    ]
    var out = run_seamstress(args)
    assert_equal(out.exit_code, 1)
    assert_equal(
        out.stderr,
        "Error JSON was printed to /tmp/gql_seamstress_cli_out.json\n",
    )
    var compose = run_seamstress(
        [
            "supergraph",
            "compose",
            "--config=/tmp/gql_seamstress_cli_missing.yaml",
            "--elv2-license",
            "accept",
            "--skip-update",
        ]
    )
    assert_equal(compose.exit_code, 1)
    assert_true(
        compose.stderr.find("Failed to load the supergraph config") >= 0
    )


def test_parse_header() raises:
    var header = parse_header("Authorization: Bearer a:b ")
    assert_equal(header.value().name, "Authorization")
    assert_equal(header.value().value, "Bearer a:b")
    assert_false(parse_header("no-colon").__bool__())
    assert_equal(parse_header(":x").value().name, "")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

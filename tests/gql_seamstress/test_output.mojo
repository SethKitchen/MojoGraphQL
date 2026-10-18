# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the output of a command: text, errors and the JSON envelope.

Ported from Rover `src/command/supergraph/compose/output.rs` (the
`ComposeOutput` tests), `src/command/output.rs` (`introspection_json`) and
`src/error/mod.rs` (`json_output_surfaces_the_anyhow_cause_chain`). The
expected texts are what Rover 1.0.0 prints.
"""

from std.os import remove
from gql_seamstress.output import CommandOutput, CommandResult, OutputFormat
from gql_seamstress.output import RoverError, json_string, success_json
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_formats() raises:
    assert_true(OutputFormat.JSON.is_valid())
    assert_false(OutputFormat(2).is_valid())
    assert_equal(String(OutputFormat.PLAIN), "plain")
    assert_equal(String(OutputFormat.JSON), "json")
    assert_equal(String(OutputFormat(5)), "<invalid>")


def test_introspection_json() raises:
    assert_equal(
        success_json(
            '"introspection_response":'
            + json_string(
                "i cant believe its not a real introspection response"
            )
        ),
        (
            '{"json_version":"1","data":{"introspection_response":"i cant'
            " believe its not a real introspection"
            ' response","success":true},"error":null}'
        ),
    )
    assert_equal(
        success_json(""),
        '{"json_version":"1","data":{"success":true},"error":null}',
    )
    assert_equal(json_string('a"\n\x01'), '"a\\"\\n\\u0001"')


def test_error_text() raises:
    var plain = RoverError.of("Schema not found in Introspection Result.")
    plain.code = "E011"
    assert_equal(
        plain.text(), "error[E011]: Schema not found in Introspection Result.\n"
    )
    var one = RoverError.of("Service error")
    one.causes.append("No data field provided")
    assert_equal(
        one.text(),
        "error: Service error\n\nCaused by:\n    No data field provided\n",
    )
    var two = RoverError.of("Failed to load the supergraph config")
    two.causes.append("Failed to deserialise the supergraph config")
    two.causes.append("line 1\nline 2")
    assert_equal(
        two.text(),
        (
            "error: Failed to load the supergraph config\n\nCaused by:\n    0:"
            " Failed to deserialise the supergraph config\n    1: line 1\n     "
            "  line 2\n"
        ),
    )
    var many = RoverError.of("m")
    for index in range(12):
        many.causes.append(String(index))
    assert_true(many.text().find("\n   10: 10\n") >= 0)
    var suggested = RoverError.of("x")
    suggested.causes.append("A: a\n")
    suggested.suggestions.append("Try again.")
    assert_equal(
        suggested.text(),
        "error: x\n\nCaused by:\n    A: a\n    \n        Try again.\n",
    )


def test_error_json() raises:
    var error = RoverError.of("Error resolving subgraphs")
    error.causes.append("Unable to resolve subgraphs.\nfilms: gone")
    error.data = '"plugins":[]'
    assert_equal(
        error.json(),
        (
            '{"json_version":"1","data":{"plugins":[],"success":false},"error":{"message":"Error'
            ' resolving subgraphs","causes":["Unable to resolve'
            ' subgraphs.\\nfilms: gone"],"code":null}}'
        ),
    )
    var coded = RoverError.of("Schema not found in Introspection Result.")
    coded.code = "E011"
    assert_equal(
        coded.json(),
        (
            '{"json_version":"1","data":{"success":false},"error":{"message":"Schema'
            ' not found in Introspection Result.","code":"E011"}}'
        ),
    )
    var build = RoverError.of(
        "Encountered 1 build error while trying to build a supergraph."
    )
    build.code = "E029"
    build.details = '{"build_errors":[]}'
    assert_equal(
        build.json(),
        (
            '{"json_version":"1","data":{"success":false},"error":{"details":{"build_errors":[]},"code":"E029","message":"Encountered'
            ' 1 build error while trying to build a supergraph."}}'
        ),
    )


def _schema() -> CommandResult:
    return CommandResult(
        None,
        "type Query { hello: String }",
        '"core_schema":'
        + json_string("type Query { hello: String }")
        + ',"hints":[],"federation_version":"=2.9.3","plugins":[]',
        "Supergraph Schema",
        "merging supergraph schema files\n",
    )


def test_compose_output() raises:
    var text = _schema().render(OutputFormat.PLAIN, None)
    assert_equal(text.stdout, "type Query { hello: String }\n")
    assert_equal(text.stderr, "merging supergraph schema files\n")
    assert_equal(text.exit_code, 0)
    var json = _schema().render(OutputFormat.JSON, None)
    assert_equal(
        json.stdout,
        (
            '{"json_version":"1","data":{"core_schema":"type Query { hello:'
            " String"
            ' }","hints":[],"federation_version":"=2.9.3","plugins":[],"success":true},"error":null}\n'
        ),
    )
    var empty = CommandResult(None, "", "", "", "")
    assert_equal(empty.render(OutputFormat.PLAIN, None).stdout, "\n")


def _read(path: String) raises -> String:
    with open(path, "r") as file:
        return file.read()


def test_output_file() raises:
    var path = String("/tmp/gql_seamstress_test_output.txt")
    var written = _schema().render(OutputFormat.PLAIN, path)
    assert_equal(written.stdout, "")
    assert_equal(
        written.stderr,
        "merging supergraph schema files\nSupergraph Schema was printed to "
        + path
        + "\n",
    )
    assert_equal(_read(path), "type Query { hello: String }")
    var unnamed = CommandResult(None, "x", "", "", "").render(
        OutputFormat.JSON, path
    )
    assert_equal(unnamed.stderr, "The output was printed to " + path + "\n")
    assert_equal(
        _read(path), '{"json_version":"1","data":{"success":true},"error":null}'
    )
    var failure = CommandResult.failure(RoverError.of("boom"), "first\n")
    var error_file = failure.render(OutputFormat.JSON, path)
    assert_equal(
        error_file.stderr, "first\nError JSON was printed to " + path + "\n"
    )
    assert_equal(error_file.exit_code, 1)
    assert_equal(_read(path), RoverError.of("boom").json())
    remove(path)
    var plain = failure.render(OutputFormat.PLAIN, path)
    assert_equal(plain.stderr, "first\nerror: boom\n")
    var json = failure.render(OutputFormat.JSON, None)
    assert_equal(json.stdout, RoverError.of("boom").json() + "\n")
    assert_equal(json.stderr, "first\n")
    try:
        _ = _schema().render(
            OutputFormat.PLAIN, String("/nonexistent/dir/out.txt")
        )
        raise Error("wrote into a missing directory")
    except e:
        assert_true(String(e) != "wrote into a missing directory")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

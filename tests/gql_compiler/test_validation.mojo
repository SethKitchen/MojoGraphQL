# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for validation, over the upstream fixtures.

Port of apollo-compiler 1.33.0 (`b7eee5c`) `tests/snapshot_tests.rs`
`validation`. A case of `test_data/ok/` must have no diagnostic. For a
case of `test_data/diagnostics/`, the `Error:` lines and the
`╭─[ file:line:column ]` lines must be the lines of the upstream `.txt`
file, in order. The fixtures are in `_validation_fixtures.mojo`.
"""

from gql_compiler.validation import (
    parse_and_validate_schema,
    parse_mixed_validate,
    validate_standalone_executable,
)
from std.os import listdir
from std.os.path import exists
from std.pathlib import Path
from std.testing import TestSuite, assert_equal, assert_true

from _validation_fixtures import (
    validation_cases,
    validation_expected,
    validation_input,
)

comptime FIXTURES = "tests/gql_compiler/validation_fixtures/"
"""The fixture files, from the repository root."""


def _file_name(path: String) -> String:
    """Return the file name of a case path."""
    var slash = path.find("/")
    return String(path[byte = slash + 1 :])


def run_case(index: Int, path: String) -> String:
    """Validate one case as `snapshot_tests.rs` does, and write the
    `Error:` and `╭─[` lines.

    Args:
        index: The case.
        path: The path of the case, from `validation_cases`.

    Returns:
        The lines, or `syntax error` when the document does not parse.
    """
    var name = _file_name(path)
    var text = validation_input(index)
    try:
        if "type_system_document" in name:
            return String(parse_and_validate_schema(text, name)[1])
        if "executable_document" in name:
            return String(validate_standalone_executable(text, name))
        return String(parse_mixed_validate(text, name)[2])
    except:
        return String("syntax error\n")


def _check(start: Int, end: Int, known: List[String]) raises -> Int:
    """Run the cases in a range, and return how many pass.

    A case that fails must be in `known`, and a case in `known` must fail.
    """
    var paths = validation_cases()
    var passed = 0
    var index = start
    while index < min(end, len(paths)):
        var got = run_case(index, paths[index])
        var ok = got == validation_expected(index)
        var listed = paths[index] in known
        if ok:
            passed += 1
        assert_true(ok != listed, String(paths[index], "\n", got))
        index += 1
    return passed


def known_failures() -> List[String]:
    """Return the cases that cannot pass, as Compiler.md lists them."""
    var out: List[String] = [
        # gql_language raises at the first syntax error. apollo-parser
        # recovers, reports each error with its own message, and the
        # document is still built and validated.
        "diagnostics/0011_syntactic_errors_from_parser.graphql",
        "diagnostics/0017_schema_with_unspecified_scalar.graphql",
        "diagnostics/0018_schema_with_specified_scalar_missing_values.graphql",
        "diagnostics/0020_enum_values_with_uncapitalised_values.graphql",
        "diagnostics/0062_root_operation_with_list.graphql",
        "diagnostics/0111_const_value.graphql",
    ]
    return out^


def test_validation_fixtures_0() raises:
    _ = _check(0, 30, known_failures())


def test_validation_fixtures_1() raises:
    _ = _check(30, 60, known_failures())


def test_validation_fixtures_2() raises:
    _ = _check(60, 90, known_failures())


def test_validation_fixtures_3() raises:
    _ = _check(90, 120, known_failures())


def test_validation_fixtures_4() raises:
    _ = _check(120, 150, known_failures())


def test_validation_fixtures_5() raises:
    _ = _check(150, 176, known_failures())


def test_validation_fixtures_are_current() raises:
    if not exists(FIXTURES):
        return
    var embedded = validation_cases()
    assert_equal(len(embedded), 176)
    var index = 0
    for directory in ["diagnostics", "ok"]:
        var entries = listdir(FIXTURES + directory)
        sort(entries)
        for ref entry in entries:
            if entry.endswith(".graphql"):
                var path = String(directory, "/", entry)
                assert_equal(embedded[index], path)
                assert_equal(
                    validation_input(index),
                    Path(FIXTURES + path).read_text(),
                    path,
                )
                index += 1
    assert_equal(index, len(embedded))
    assert_equal(validation_input(index), "")
    assert_equal(validation_expected(index), "")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

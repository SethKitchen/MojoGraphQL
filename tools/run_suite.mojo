# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Build one test suite with warnings as errors, run it, and fail every test
that takes too long.

    run_suite <mojo> <seconds> <suite.mojo> [mojo flags...]

The suite is built to `.cache/bin/`, run with a private `TMPDIR`, and its
output printed. It fails when:

- the build fails or warns;
- the suite exits non-zero, or runs longer than the limit multiplied by the
  number of tests, plus one limit for startup: a hang;
- a test takes longer than the limit. A slow test means a slow library:
  make the library faster, not the test smaller;
- the output has no single complete `TestSuite` header and summary, or the
  summary reports a failure.
"""

from std.pathlib import Path
from std.subprocess import run
from std.sys import argv


def shell(command: String) raises -> Tuple[Int, String]:
    """Run a shell command; return its exit status and combined output.

    Args:
        command: The command, for `/bin/sh`.

    Returns:
        The exit status and the output without the Crashpad warning.

    Raises:
        Error: If the command cannot be started.
    """
    var out = run("(" + command + ") 2>&1; echo __rc=$?")
    var lines = out.splitlines()
    var status = 1
    var text = String("")
    for index in range(len(lines)):
        var line = lines[index]
        if index == len(lines) - 1 and line.startswith("__rc="):
            status = Int(String(line[byte=5:]))
            continue
        if "Crashpad" in line:
            continue
        text += line + "\n"
    return (status, text^)


def quote(text: String) -> String:
    """Quote text for the shell.

    Args:
        text: Any text.

    Returns:
        The text in single quotes.
    """
    return "'" + text.replace("'", "'\"'\"'") + "'"


def count_tests(source: String) -> Int:
    """Return how many `def test_` functions a suite defines.

    Args:
        source: The suite's text.

    Returns:
        The count.
    """
    var count = 0
    for line in source.splitlines():
        if line.startswith("def test_"):
            count += 1
    return count


def _milliseconds(line: StringSlice) -> Float64:
    """Return the time in `PASS [ 12.5 ] name`, or -1."""
    var open = line.find("[")
    var close = line.find("]")
    if open < 0 or close < open:
        return -1
    try:
        return Float64(String(line[byte = open + 1 : close].strip()))
    except:
        return -1


def check_results(output: String, seconds: Float64) -> List[String]:
    """Return the problems with a suite's output.

    Args:
        output: What the suite printed.
        seconds: The limit for one test.

    Returns:
        One message per problem; empty for a clean run.
    """
    var problems = List[String]()
    var headers = 0
    var summaries = 0
    var results = 0
    for raw in output.splitlines():
        var line = String(raw.strip())
        if line.startswith("Running ") and " tests for " in line:
            headers += 1
        elif line.startswith("Running 1 test for "):
            headers += 1
        elif line.startswith("Summary ["):
            summaries += 1
            if not " 0 failed" in line:
                problems.append("the summary reports failed tests")
        elif (
            line.startswith("PASS [")
            or line.startswith("FAIL [")
            or line.startswith("SKIP [")
        ):
            results += 1
            if line.startswith("FAIL ["):
                problems.append("a test failed: " + line)
            var took = _milliseconds(line)
            if took / 1000.0 > seconds:
                problems.append(
                    "a test took "
                    + String(took / 1000.0)
                    + "s, over the "
                    + String(seconds)
                    + "s limit: "
                    + line
                )
    if headers != 1 or summaries != 1:
        problems.append("expected one complete TestSuite header and summary")
    if results == 0:
        problems.append("the suite reported no tests")
    return problems^


def main() raises:
    """Build and run one suite."""
    var args = argv()
    if len(args) < 4:
        raise Error("usage: run_suite <mojo> <seconds> <suite> [flags...]")
    var mojo = String(args[1])
    var seconds = Float64(String(args[2]))
    var suite = String(args[3])
    var flags = String("")
    for index in range(4, len(args)):
        flags += " " + quote(String(args[index]))
    var binary = ".cache/bin/" + suite.replace("/", "__").removesuffix(".mojo")
    var built = shell(
        "mkdir -p .cache/bin && "
        + quote(mojo)
        + " build"
        + flags
        + " --Werror -o "
        + quote(binary)
        + " "
        + quote(suite)
    )
    if built[0] != 0:
        print(built[1], end="")
        raise Error("BUILD FAILED: " + suite)
    var tests = count_tests(Path(suite).read_text())
    var budget = Int(seconds * Float64(max(tests, 1) + 1)) + 1
    var ran = shell(
        "dir=$(mktemp -d) && TMPDIR=$dir MOJOGRAPHQL_TEST_TMPDIR=$dir timeout "
        + String(budget)
        + " "
        + quote(binary)
        + ' < /dev/null; rc=$?; rm -rf "$dir" '
        + quote(binary)
        + "; exit $rc"
    )
    print(ran[1], end="")
    if ran[0] == 124:
        raise Error(
            suite
            + ": stopped after "
            + String(budget)
            + "s. A test hangs or is slower than "
            + String(seconds)
            + "s."
        )
    var problems = check_results(ran[1], seconds)
    for ref problem in problems:
        print(suite + ": " + problem)
    if ran[0] != 0 or len(problems) > 0:
        raise Error("FAILED: " + suite)

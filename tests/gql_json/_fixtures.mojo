# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Find and read the files in `tests/gql_json/fixtures/`.

`make test` runs a suite from the repository root. `make coverage` runs it
from `coverage/build/<package>/`, three levels down, where only the Mojo
files are copied. Both find the same fixture directory.
"""

from std.os import listdir
from std.os.path import exists
from std.pathlib import Path

from gql_json.error import JsonError
from gql_json.parser import parse, parse_bytes
from gql_json.value import JsonDocument


def fixture_dir() -> String:
    """Return the fixture directory, with a trailing slash.

    Returns:
        The path from the current directory.
    """
    var prefix = String("")
    # `make coverage` runs a suite a few levels below the repository root.
    while not exists(prefix + "tests/gql_json/fixtures") and (
        prefix.byte_length() < 12
    ):
        prefix += "../"
    return prefix + "tests/gql_json/fixtures/"


def read_fixture(name: String) raises -> List[UInt8]:
    """Return the bytes of a fixture file.

    Args:
        name: The path under the fixture directory.

    Returns:
        The bytes, unchanged.

    Raises:
        Error: If the file cannot be read.
    """
    return Path(fixture_dir() + name).read_bytes()


def fixture_names(directory: String) raises -> List[String]:
    """Return the names of the files in a fixture directory, sorted.

    Args:
        directory: The directory under the fixture directory.

    Returns:
        The file names.

    Raises:
        Error: If the directory cannot be listed.
    """
    var names = listdir(fixture_dir() + directory)
    sort(names)
    return names^


def parse_or_message(var bytes: List[UInt8]) -> Tuple[Bool, String]:
    """Parse bytes and report the result as data.

    Args:
        bytes: The JSON text.

    Returns:
        True and an empty string, or False and the error text.
    """
    try:
        _ = parse_bytes(bytes^)
        return (True, String(""))
    except e:
        return (False, String(e))


def must_parse(text: StringSlice) raises -> JsonDocument:
    """Parse text that must be valid JSON.

    Args:
        text: The JSON text.

    Returns:
        The document.

    Raises:
        Error: If the text is not valid JSON.
    """
    try:
        return parse(text)
    except e:
        raise Error(String(e))


def parse_error(text: StringSlice, max_depth: Int = 1000) raises -> JsonError:
    """Return the error that parsing invalid JSON raises.

    Args:
        text: The JSON text.
        max_depth: The depth limit.

    Returns:
        The error.

    Raises:
        Error: If the text parses.
    """
    try:
        _ = parse(text, max_depth)
    except e:
        return e^
    raise Error(String("expected a parse error for: ", text))

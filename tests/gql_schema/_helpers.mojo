# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Test helpers for gql_schema: graphql-js test `dedent`."""


def dedent(text: String) -> String:
    """Strip a template's indent, as graphql-js test `dedent`.

    Leading line breaks and trailing white space go; then the indent of the
    first line is removed from every line that starts with it.

    Args:
        text: The text, often a triple-quoted Mojo string.

    Returns:
        The dedented text.
    """
    var bytes = text.as_bytes()
    var start = 0
    while start < len(bytes) and bytes[start] == 10:
        start += 1
    var end = len(bytes)
    while end > start and (
        bytes[end - 1] == 32 or bytes[end - 1] == 9 or bytes[end - 1] == 10
    ):
        end -= 1
    var trimmed = String(unsafe_from_utf8=bytes[start:end])
    var indent = 0
    var trimmed_bytes = trimmed.as_bytes()
    while indent < len(trimmed_bytes) and (
        trimmed_bytes[indent] == 32 or trimmed_bytes[indent] == 9
    ):
        indent += 1
    var prefix = String(unsafe_from_utf8=trimmed_bytes[0:indent])
    var out = String("")
    var lines = trimmed.split("\n")
    for index in range(len(lines)):
        if index > 0:
            out += "\n"
        var line = String(lines[index])
        if indent > 0 and line.startswith(prefix):
            out += String(line[byte=indent:])
        else:
            out += line
    return out^

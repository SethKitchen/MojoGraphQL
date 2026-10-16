# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Helpers for the `gql_composition` tests.

Each case is the input of one upstream `composeServices` call. The
expected errors are those of the subgraph phase of Hive Federation
Composition v0.27.0 `validate` in Node.js on the same subgraphs, as
`[<code>] <message>` lines; `THROWS <message>` when it throws.
"""

from gql_language.parser import parse
from gql_composition.validate import Subgraph, validate_subgraphs
from std.testing import assert_equal


def sg(name: String, sdl: String) raises -> Subgraph:
    """Parse a subgraph.

    Args:
        name: The subgraph's name.
        sdl: Its SDL.

    Returns:
        The subgraph, without a URL.

    Raises:
        Error: If the SDL does not parse.
    """
    return Subgraph(name, None, parse(sdl))


def errors_of(subgraphs: List[Subgraph]) -> List[String]:
    """Validate subgraphs and print each error as `[<code>] <message>`.

    Args:
        subgraphs: The subgraphs.

    Returns:
        The printed errors, or `THROWS <message>` when validation raises.
    """
    var out = List[String]()
    try:
        for ref error in validate_subgraphs(subgraphs):
            out.append(String(error))
    except error:
        out = [String("THROWS ") + String(error)]
    return out^


def check(subgraphs: List[Subgraph], expected: List[String]) raises:
    """Assert the errors of subgraphs.

    Args:
        subgraphs: The subgraphs.
        expected: The printed errors that upstream returns.

    Raises:
        Error: If the errors differ.
    """
    var got = errors_of(subgraphs)
    var message = String("got:\n") + String("\n").join(got)
    assert_equal(len(got), len(expected), message)
    for index in range(len(expected)):
        assert_equal(got[index], expected[index], message)

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Helpers of the incremental handler tests: feed recorded payloads to a
handler and compare each result with the result of Apollo Client 4.3.3.

A step is one call of upstream `isIncrementalResult` or `handle`, in the
order of the upstream test.
"""

from std.testing import assert_equal

from gql_client.incremental import (
    Defer20220824Handler,
    GraphQL17Alpha9Handler,
)
from gql_json.parser import parse as parse_json
from gql_json.value import JsonDocument

comptime UNDEFINED = "undefined"
"""The `cache_data` of a step that passes `undefined`."""


@fieldwise_init
struct Step(Copyable, Movable):
    """One call of the upstream test."""

    var is_check: Bool
    """True for `isIncrementalResult`, False for `handle`."""
    var cache: String
    """The JSON of `cacheData`, or `UNDEFINED`."""
    var chunk: String
    """The JSON of the payload."""
    var result: String
    """The JSON of the result of `handle`."""
    var flag: Bool
    """The result of `isIncrementalResult`, or `hasNext` after `handle`."""
    var stream_info: Bool
    """Whether the result has the stream information."""


def is_step(chunk: String, value: Bool) -> Step:
    """Make a step of `isIncrementalResult`.

    Args:
        chunk: The JSON of the result.
        value: The expected answer.

    Returns:
        The step.
    """
    return Step(True, String(UNDEFINED), chunk, String(), value, False)


def handle_step(
    cache: String,
    chunk: String,
    result: String,
    has_next: Bool,
    stream_info: Bool,
) -> Step:
    """Make a step of `handle`.

    Args:
        cache: The JSON of `cacheData`, or `UNDEFINED`.
        chunk: The JSON of the payload.
        result: The JSON of the expected result.
        has_next: The expected `hasNext` after the call.
        stream_info: Whether the result has the stream information.

    Returns:
        The step.
    """
    return Step(False, cache, chunk, result, has_next, stream_info)


def _cache(step: Step) raises -> Optional[JsonDocument]:
    """Return the `cache_data` of a step."""
    if step.cache == UNDEFINED:
        return None
    return parse_json(step.cache)


def run_graphql17(steps: List[Step]) raises:
    """Run the steps with one `GraphQL17Alpha9Handler` request.

    Args:
        steps: The steps.

    Raises:
        Error: When a result differs.
    """
    var handler = GraphQL17Alpha9Handler()
    var request = handler.start_request()
    var index = 0
    while index < len(steps):
        ref step = steps[index]
        index += 1
        var chunk = parse_json(step.chunk)
        if step.is_check:
            assert_equal(handler.is_incremental_result(chunk), step.flag)
            continue
        var result = request.handle(_cache(step), chunk)
        assert_equal(request.stringify(result), step.result)
        assert_equal(request.has_next, step.flag)
        assert_equal(result.has_stream_info, step.stream_info)


def run_defer20220824(steps: List[Step]) raises:
    """Run the steps with one `Defer20220824Handler` request.

    Args:
        steps: The steps.

    Raises:
        Error: When a result differs.
    """
    var handler = Defer20220824Handler()
    var request = handler.start_request()
    var index = 0
    while index < len(steps):
        ref step = steps[index]
        index += 1
        var chunk = parse_json(step.chunk)
        if step.is_check:
            assert_equal(handler.is_incremental_result(chunk), step.flag)
            continue
        var result = request.handle(_cache(step), chunk)
        assert_equal(request.stringify(result), step.result)
        assert_equal(request.has_next, step.flag)
        assert_equal(result.has_stream_info, step.stream_info)

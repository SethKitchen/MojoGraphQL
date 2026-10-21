# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `GraphQL17Alpha9Handler` with `@stream`: Apollo Client 4.3.3
(ae0dfce) `src/incremental/handlers/__tests__/graphql17Alpha9/stream.test.ts`.

Each case has the payloads and the results of the upstream case. They
were recorded from the upstream test itself, run in Node.js with Apollo
Client 4.3.3 and graphql 17.0.0-alpha.9, the versions of the upstream
test. Each step is one call of `isIncrementalResult` or `handle`, in the
order of the upstream test, and the result must have the same JSON.
`stream_info` tells when upstream puts the stream information in
`extensions`.

These upstream cases are not here:

- The cases that upstream skips with `it.skip`: upstream says that they
  are not interesting from a client perspective.
- "GraphQL17Alpha9Handler can be used with `ApolloClient`": it runs
  `ApolloClient` with a link. `test_query_info.mojo` ports its cache
  writes.
"""

from std.testing import TestSuite

from _incremental_helpers import UNDEFINED, handle_step, is_step, run_graphql17


def test_can_stream_a_list_field() raises:
    """Can stream a list field."""
    run_graphql17(
        [
            is_step(
                '{"data":{"scalarList":["apple"]},"pending":[{"id":"0","path":["scalarList"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"scalarList":["apple"]},"pending":[{"id":"0","path":["scalarList"]}],"hasNext":true}',
                result='{"data":{"scalarList":["apple"]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"id":"0","items":["banana","coconut"]}],"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"incremental":[{"id":"0","items":["banana","coconut"]}],"completed":[{"id":"0"}]}',
                result='{"data":{"scalarList":["apple","banana","coconut"]},"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_can_use_default_value_of_initialcount() raises:
    """Can use default value of initialCount."""
    run_graphql17(
        [
            is_step(
                '{"data":{"scalarList":[]},"pending":[{"id":"0","path":["scalarList"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"scalarList":[]},"pending":[{"id":"0","path":["scalarList"]}],"hasNext":true}',
                result='{"data":{"scalarList":[]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"id":"0","items":["apple","banana","coconut"]}],"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"incremental":[{"id":"0","items":["apple","banana","coconut"]}],"completed":[{"id":"0"}]}',
                result='{"data":{"scalarList":["apple","banana","coconut"]},"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_does_not_disable_stream_with_null_if_argument() raises:
    """Does not disable stream with null if argument."""
    run_graphql17(
        [
            is_step(
                '{"data":{"scalarList":["apple","banana"]},"pending":[{"id":"0","path":["scalarList"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"scalarList":["apple","banana"]},"pending":[{"id":"0","path":["scalarList"]}],"hasNext":true}',
                result=(
                    '{"data":{"scalarList":["apple","banana"]},"extensions":{}}'
                ),
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"id":"0","items":["coconut"]}],"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"incremental":[{"id":"0","items":["coconut"]}],"completed":[{"id":"0"}]}',
                result='{"data":{"scalarList":["apple","banana","coconut"]},"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_can_stream_multi_dimensional_lists() raises:
    """Can stream multi-dimensional lists."""
    run_graphql17(
        [
            is_step(
                '{"data":{"scalarListList":[["apple","apple","apple"]]},"pending":[{"id":"0","path":["scalarListList"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"scalarListList":[["apple","apple","apple"]]},"pending":[{"id":"0","path":["scalarListList"]}],"hasNext":true}',
                result='{"data":{"scalarListList":[["apple","apple","apple"]]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"id":"0","items":[["banana","banana","banana"],["coconut","coconut","coconut"]]}],"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"incremental":[{"id":"0","items":[["banana","banana","banana"],["coconut","coconut","coconut"]]}],"completed":[{"id":"0"}]}',
                result='{"data":{"scalarListList":[["apple","apple","apple"],["banana","banana","banana"],["coconut","coconut","coconut"]]},"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_can_stream_a_field_that_returns_a_list_of_promises() raises:
    """Can stream a field that returns a list of promises."""
    run_graphql17(
        [
            is_step(
                '{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"id":"0","items":[{"name":"Leia","id":"3"}]}],"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"incremental":[{"id":"0","items":[{"name":"Leia","id":"3"}]}],"completed":[{"id":"0"}]}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"},{"name":"Leia","id":"3"}]},"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_can_stream_in_correct_order_with_lists_of_promises() raises:
    """Can stream in correct order with lists of promises."""
    run_graphql17(
        [
            is_step(
                '{"data":{"friendList":[]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"friendList":[]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                result='{"data":{"friendList":[]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"name":"Luke","id":"1"}]}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"name":"Luke","id":"1"}]}]}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"name":"Han","id":"2"}]}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"name":"Han","id":"2"}]}]}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"id":"0","items":[{"name":"Leia","id":"3"}]}],"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"incremental":[{"id":"0","items":[{"name":"Leia","id":"3"}]}],"completed":[{"id":"0"}]}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"},{"name":"Leia","id":"3"}]},"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_does_not_execute_early_if_not_specified() raises:
    """Does not execute early if not specified."""
    run_graphql17(
        [
            is_step(
                '{"data":{"friendList":[]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"friendList":[]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                result='{"data":{"friendList":[]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"id":"1"}]}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"id":"1"}]}]}',
                result='{"data":{"friendList":[{"id":"1"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"id":"2"}]}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"id":"2"}]}]}',
                result='{"data":{"friendList":[{"id":"1"},{"id":"2"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"id":"0","items":[{"id":"3"}]}],"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"incremental":[{"id":"0","items":[{"id":"3"}]}],"completed":[{"id":"0"}]}',
                result='{"data":{"friendList":[{"id":"1"},{"id":"2"},{"id":"3"}]},"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_executes_early_if_specified() raises:
    """Executes early if specified."""
    run_graphql17(
        [
            is_step(
                '{"data":{"friendList":[]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"friendList":[]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                result='{"data":{"friendList":[]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"id":"0","items":[{"id":"1"},{"id":"2"},{"id":"3"}]}],"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"incremental":[{"id":"0","items":[{"id":"1"},{"id":"2"},{"id":"3"}]}],"completed":[{"id":"0"}]}',
                result='{"data":{"friendList":[{"id":"1"},{"id":"2"},{"id":"3"}]},"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_can_stream_a_field_that_returns_a_list_with_nested_promises() raises:
    """Can stream a field that returns a list with nested promises."""
    run_graphql17(
        [
            is_step(
                '{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"id":"0","items":[{"name":"Leia","id":"3"}]}],"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"incremental":[{"id":"0","items":[{"name":"Leia","id":"3"}]}],"completed":[{"id":"0"}]}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"},{"name":"Leia","id":"3"}]},"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_handles_rejections_in_a_field_that_returns_a_list_of_promises_before_initialcount_is_reached() raises:
    """Handles rejections in a field that returns a list of promises before initialCount is reached.
    """
    run_graphql17(
        [
            is_step(
                '{"errors":[{"message":"bad","path":["friendList",1]}],"data":{"friendList":[{"name":"Luke","id":"1"},null]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"errors":[{"message":"bad","path":["friendList",1]}],"data":{"friendList":[{"name":"Luke","id":"1"},null]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},null]},"errors":[{"message":"bad","path":["friendList",1]}],"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"id":"0","items":[{"name":"Leia","id":"3"}]}],"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"incremental":[{"id":"0","items":[{"name":"Leia","id":"3"}]}],"completed":[{"id":"0"}]}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},null,{"name":"Leia","id":"3"}]},"errors":[{"message":"bad","path":["friendList",1]}],"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_handles_rejections_in_a_field_that_returns_a_list_of_promises_after_initialcount_is_reached() raises:
    """Handles rejections in a field that returns a list of promises after initialCount is reached.
    """
    run_graphql17(
        [
            is_step(
                '{"data":{"friendList":[{"name":"Luke","id":"1"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"friendList":[{"name":"Luke","id":"1"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":true,"incremental":[{"id":"0","items":[null],"errors":[{"message":"bad","path":["friendList",1]}]}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"incremental":[{"id":"0","items":[null],"errors":[{"message":"bad","path":["friendList",1]}]}]}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},null]},"errors":[{"message":"bad","path":["friendList",1]}],"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"id":"0","items":[{"name":"Leia","id":"3"}]}],"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"incremental":[{"id":"0","items":[{"name":"Leia","id":"3"}]}],"completed":[{"id":"0"}]}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},null,{"name":"Leia","id":"3"}]},"errors":[{"message":"bad","path":["friendList",1]}],"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_can_stream_a_field_that_returns_an_async_iterable() raises:
    """Can stream a field that returns an async iterable."""
    run_graphql17(
        [
            is_step(
                '{"data":{"friendList":[]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"friendList":[]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                result='{"data":{"friendList":[]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"name":"Luke","id":"1"}]}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"name":"Luke","id":"1"}]}]}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"name":"Han","id":"2"}]}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"name":"Han","id":"2"}]}]}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"name":"Leia","id":"3"}]}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"name":"Leia","id":"3"}]}]}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"},{"name":"Leia","id":"3"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"completed":[{"id":"0"}]}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"},{"name":"Leia","id":"3"}]},"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_can_stream_a_field_that_returns_an_async_iterable_using_a_non_zero_initialcount() raises:
    """Can stream a field that returns an async iterable, using a non-zero initialCount.
    """
    run_graphql17(
        [
            is_step(
                '{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"name":"Leia","id":"3"}]}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"name":"Leia","id":"3"}]}]}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"},{"name":"Leia","id":"3"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"completed":[{"id":"0"}]}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"},{"name":"Leia","id":"3"}]},"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_does_not_execute_early_if_not_specified_when_streaming_from_an_async_iterable() raises:
    """Does not execute early if not specified, when streaming from an async iterable.
    """
    run_graphql17(
        [
            is_step(
                '{"data":{"friendList":[]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"friendList":[]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                result='{"data":{"friendList":[]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"id":"1"}]}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"id":"1"}]}]}',
                result='{"data":{"friendList":[{"id":"1"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"id":"2"}]}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"id":"2"}]}]}',
                result='{"data":{"friendList":[{"id":"1"},{"id":"2"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"id":"3"}]}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"id":"3"}]}]}',
                result='{"data":{"friendList":[{"id":"1"},{"id":"2"},{"id":"3"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"completed":[{"id":"0"}]}',
                result='{"data":{"friendList":[{"id":"1"},{"id":"2"},{"id":"3"}]},"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_executes_early_if_specified_when_streaming_from_an_async_iterable() raises:
    """Executes early if specified when streaming from an async iterable."""
    run_graphql17(
        [
            is_step(
                '{"data":{"friendList":[]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"friendList":[]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                result='{"data":{"friendList":[]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"id":"0","items":[{"id":"1"},{"id":"2"},{"id":"3"}]}],"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"incremental":[{"id":"0","items":[{"id":"1"},{"id":"2"},{"id":"3"}]}],"completed":[{"id":"0"}]}',
                result='{"data":{"friendList":[{"id":"1"},{"id":"2"},{"id":"3"}]},"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_can_handle_concurrent_calls_to_next_without_waiting() raises:
    """Can handle concurrent calls to .next() without waiting."""
    run_graphql17(
        [
            is_step(
                '{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"name":"Leia","id":"3"}]}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"name":"Leia","id":"3"}]}]}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"},{"name":"Leia","id":"3"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"completed":[{"id":"0"}]}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"},{"name":"Leia","id":"3"}]},"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_handles_error_thrown_in_async_iterable_after_initialcount_is_reached() raises:
    """Handles error thrown in async iterable after initialCount is reached."""
    run_graphql17(
        [
            is_step(
                '{"data":{"friendList":[{"name":"Luke","id":"1"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"friendList":[{"name":"Luke","id":"1"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"bad","path":["friendList"]}]}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"bad","path":["friendList"]}]}]}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"}]},"errors":[{"message":"bad","path":["friendList"]}],"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_handles_null_returned_in_non_null_list_items_after_initialcount_is_reached() raises:
    """Handles null returned in non-null list items after initialCount is reached.
    """
    run_graphql17(
        [
            is_step(
                '{"data":{"nonNullFriendList":[{"name":"Luke"}]},"pending":[{"id":"0","path":["nonNullFriendList"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"nonNullFriendList":[{"name":"Luke"}]},"pending":[{"id":"0","path":["nonNullFriendList"]}],"hasNext":true}',
                result='{"data":{"nonNullFriendList":[{"name":"Luke"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                (
                    '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' Query.nonNullFriendList.","path":["nonNullFriendList",1]}]}]}'
                ),
                True,
            ),
            handle_step(
                UNDEFINED,
                (
                    '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' Query.nonNullFriendList.","path":["nonNullFriendList",1]}]}]}'
                ),
                result=(
                    '{"data":{"nonNullFriendList":[{"name":"Luke"}]},"errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' Query.nonNullFriendList.","path":["nonNullFriendList",1]}],"extensions":{}}'
                ),
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_handles_errors_thrown_by_completevalue_after_initialcount_is_reached() raises:
    """Handles errors thrown by completeValue after initialCount is reached."""
    run_graphql17(
        [
            is_step(
                '{"data":{"scalarList":["Luke"]},"pending":[{"id":"0","path":["scalarList"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"scalarList":["Luke"]},"pending":[{"id":"0","path":["scalarList"]}],"hasNext":true}',
                result='{"data":{"scalarList":["Luke"]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                (
                    '{"hasNext":false,"incremental":[{"id":"0","items":[null],"errors":[{"message":"String'
                    " cannot represent value:"
                    ' {}","path":["scalarList",1]}]}],"completed":[{"id":"0"}]}'
                ),
                True,
            ),
            handle_step(
                UNDEFINED,
                (
                    '{"hasNext":false,"incremental":[{"id":"0","items":[null],"errors":[{"message":"String'
                    " cannot represent value:"
                    ' {}","path":["scalarList",1]}]}],"completed":[{"id":"0"}]}'
                ),
                result=(
                    '{"data":{"scalarList":["Luke",null]},"errors":[{"message":"String'
                    " cannot represent value:"
                    ' {}","path":["scalarList",1]}],"extensions":{}}'
                ),
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_handles_async_errors_thrown_by_completevalue_after_initialcount_is_reached() raises:
    """Handles async errors thrown by completeValue after initialCount is reached.
    """
    run_graphql17(
        [
            is_step(
                '{"data":{"friendList":[{"nonNullName":"Luke"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"friendList":[{"nonNullName":"Luke"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                result='{"data":{"friendList":[{"nonNullName":"Luke"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":true,"incremental":[{"id":"0","items":[null],"errors":[{"message":"Oops","path":["friendList",1,"nonNullName"]}]}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"incremental":[{"id":"0","items":[null],"errors":[{"message":"Oops","path":["friendList",1,"nonNullName"]}]}]}',
                result='{"data":{"friendList":[{"nonNullName":"Luke"},null]},"errors":[{"message":"Oops","path":["friendList",1,"nonNullName"]}],"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"id":"0","items":[{"nonNullName":"Han"}]}],"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"incremental":[{"id":"0","items":[{"nonNullName":"Han"}]}],"completed":[{"id":"0"}]}',
                result='{"data":{"friendList":[{"nonNullName":"Luke"},null,{"nonNullName":"Han"}]},"errors":[{"message":"Oops","path":["friendList",1,"nonNullName"]}],"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_handles_async_errors_thrown_by_completevalue_after_initialcount_is_reached_for_a_non_nullable_list() raises:
    """Handles async errors thrown by completeValue after initialCount is reached for a non-nullable list.
    """
    run_graphql17(
        [
            is_step(
                '{"data":{"nonNullFriendList":[{"nonNullName":"Luke"}]},"pending":[{"id":"0","path":["nonNullFriendList"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"nonNullFriendList":[{"nonNullName":"Luke"}]},"pending":[{"id":"0","path":["nonNullFriendList"]}],"hasNext":true}',
                result='{"data":{"nonNullFriendList":[{"nonNullName":"Luke"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"Oops","path":["nonNullFriendList",1,"nonNullName"]}]}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"Oops","path":["nonNullFriendList",1,"nonNullName"]}]}]}',
                result='{"data":{"nonNullFriendList":[{"nonNullName":"Luke"}]},"errors":[{"message":"Oops","path":["nonNullFriendList",1,"nonNullName"]}],"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_handles_async_errors_thrown_by_completevalue_after_initialcount_is_reached_from_async_iterable() raises:
    """Handles async errors thrown by completeValue after initialCount is reached from async iterable.
    """
    run_graphql17(
        [
            is_step(
                '{"data":{"friendList":[{"nonNullName":"Luke"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"friendList":[{"nonNullName":"Luke"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                result='{"data":{"friendList":[{"nonNullName":"Luke"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":true,"incremental":[{"id":"0","items":[null],"errors":[{"message":"Oops","path":["friendList",1,"nonNullName"]}]}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"incremental":[{"id":"0","items":[null],"errors":[{"message":"Oops","path":["friendList",1,"nonNullName"]}]}]}',
                result='{"data":{"friendList":[{"nonNullName":"Luke"},null]},"errors":[{"message":"Oops","path":["friendList",1,"nonNullName"]}],"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"nonNullName":"Han"}]}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"nonNullName":"Han"}]}]}',
                result='{"data":{"friendList":[{"nonNullName":"Luke"},null,{"nonNullName":"Han"}]},"errors":[{"message":"Oops","path":["friendList",1,"nonNullName"]}],"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"completed":[{"id":"0"}]}',
                result='{"data":{"friendList":[{"nonNullName":"Luke"},null,{"nonNullName":"Han"}]},"errors":[{"message":"Oops","path":["friendList",1,"nonNullName"]}],"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_does_not_filter_payloads_when_null_error_is_in_a_different_path() raises:
    """Does not filter payloads when null error is in a different path."""
    run_graphql17(
        [
            is_step(
                '{"data":{"otherNestedObject":{},"nestedObject":{"nestedFriendList":[]}},"pending":[{"id":"0","path":["otherNestedObject"]},{"id":"1","path":["nestedObject","nestedFriendList"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"otherNestedObject":{},"nestedObject":{"nestedFriendList":[]}},"pending":[{"id":"0","path":["otherNestedObject"]},{"id":"1","path":["nestedObject","nestedFriendList"]}],"hasNext":true}',
                result='{"data":{"otherNestedObject":{},"nestedObject":{"nestedFriendList":[]}},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":true,"incremental":[{"id":"1","items":[{"name":"Luke"}]},{"data":{"scalarField":null},"errors":[{"message":"Oops","path":["otherNestedObject","scalarField"]}],"id":"0"}],"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"incremental":[{"id":"1","items":[{"name":"Luke"}]},{"data":{"scalarField":null},"errors":[{"message":"Oops","path":["otherNestedObject","scalarField"]}],"id":"0"}],"completed":[{"id":"0"}]}',
                result='{"data":{"otherNestedObject":{"scalarField":null},"nestedObject":{"nestedFriendList":[{"name":"Luke"}]}},"errors":[{"message":"Oops","path":["otherNestedObject","scalarField"]}],"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"completed":[{"id":"1"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"completed":[{"id":"1"}]}',
                result='{"data":{"otherNestedObject":{"scalarField":null},"nestedObject":{"nestedFriendList":[{"name":"Luke"}]}},"errors":[{"message":"Oops","path":["otherNestedObject","scalarField"]}],"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_filters_stream_payloads_that_are_nulled_in_a_deferred_payload() raises:
    """Filters stream payloads that are nulled in a deferred payload."""
    run_graphql17(
        [
            is_step(
                '{"data":{"nestedObject":{}},"pending":[{"id":"0","path":["nestedObject"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"nestedObject":{}},"pending":[{"id":"0","path":["nestedObject"]}],"hasNext":true}',
                result='{"data":{"nestedObject":{}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                (
                    '{"hasNext":false,"incremental":[{"data":{"deeperNestedObject":null},"errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' DeeperNestedObject.nonNullScalarField.","path":["nestedObject","deeperNestedObject","nonNullScalarField"]}],"id":"0"}],"completed":[{"id":"0"}]}'
                ),
                True,
            ),
            handle_step(
                UNDEFINED,
                (
                    '{"hasNext":false,"incremental":[{"data":{"deeperNestedObject":null},"errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' DeeperNestedObject.nonNullScalarField.","path":["nestedObject","deeperNestedObject","nonNullScalarField"]}],"id":"0"}],"completed":[{"id":"0"}]}'
                ),
                result=(
                    '{"data":{"nestedObject":{"deeperNestedObject":null}},"errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' DeeperNestedObject.nonNullScalarField.","path":["nestedObject","deeperNestedObject","nonNullScalarField"]}]}'
                ),
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_filters_defer_payloads_that_are_nulled_in_a_stream_response() raises:
    """Filters defer payloads that are nulled in a stream response."""
    run_graphql17(
        [
            is_step(
                '{"data":{"friendList":[]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"friendList":[]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                result='{"data":{"friendList":[]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                (
                    '{"hasNext":true,"incremental":[{"id":"0","items":[null],"errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' Friend.nonNullName.","path":["friendList",0,"nonNullName"]}]}]}'
                ),
                True,
            ),
            handle_step(
                UNDEFINED,
                (
                    '{"hasNext":true,"incremental":[{"id":"0","items":[null],"errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' Friend.nonNullName.","path":["friendList",0,"nonNullName"]}]}]}'
                ),
                result=(
                    '{"data":{"friendList":[null]},"errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' Friend.nonNullName.","path":["friendList",0,"nonNullName"]}],"extensions":{}}'
                ),
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"completed":[{"id":"0"}]}',
                result=(
                    '{"data":{"friendList":[null]},"errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' Friend.nonNullName.","path":["friendList",0,"nonNullName"]}],"extensions":{}}'
                ),
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_handles_promises_returned_by_completevalue_after_initialcount_is_reached() raises:
    """Handles promises returned by completeValue after initialCount is reached.
    """
    run_graphql17(
        [
            is_step(
                '{"data":{"friendList":[{"id":"1","name":"Luke"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"friendList":[{"id":"1","name":"Luke"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                result='{"data":{"friendList":[{"id":"1","name":"Luke"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"id":"2","name":"Han"}]}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"id":"2","name":"Han"}]}]}',
                result='{"data":{"friendList":[{"id":"1","name":"Luke"},{"id":"2","name":"Han"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"id":"3","name":"Leia"}]}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"id":"3","name":"Leia"}]}]}',
                result='{"data":{"friendList":[{"id":"1","name":"Luke"},{"id":"2","name":"Han"},{"id":"3","name":"Leia"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"completed":[{"id":"0"}]}',
                result='{"data":{"friendList":[{"id":"1","name":"Luke"},{"id":"2","name":"Han"},{"id":"3","name":"Leia"}]},"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_handles_overlapping_deferred_and_non_deferred_streams() raises:
    """Handles overlapping deferred and non-deferred streams."""
    run_graphql17(
        [
            is_step(
                '{"data":{"nestedObject":{"nestedFriendList":[]}},"pending":[{"id":"0","path":["nestedObject","nestedFriendList"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"nestedObject":{"nestedFriendList":[]}},"pending":[{"id":"0","path":["nestedObject","nestedFriendList"]}],"hasNext":true}',
                result='{"data":{"nestedObject":{"nestedFriendList":[]}},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"id":"1","name":"Luke"}]}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"id":"1","name":"Luke"}]}]}',
                result='{"data":{"nestedObject":{"nestedFriendList":[{"id":"1","name":"Luke"}]}},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"id":"2","name":"Han"}]}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"incremental":[{"id":"0","items":[{"id":"2","name":"Han"}]}]}',
                result='{"data":{"nestedObject":{"nestedFriendList":[{"id":"1","name":"Luke"},{"id":"2","name":"Han"}]}},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"completed":[{"id":"0"}]}',
                result='{"data":{"nestedObject":{"nestedFriendList":[{"id":"1","name":"Luke"},{"id":"2","name":"Han"}]}},"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_returns_payloads_in_correct_order_when_parent_deferred_fragment_resolves_slower_than_stream() raises:
    """Returns payloads in correct order when parent deferred fragment resolves slower than stream.
    """
    run_graphql17(
        [
            is_step(
                '{"data":{"nestedObject":{}},"pending":[{"id":"0","path":["nestedObject"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"nestedObject":{}},"pending":[{"id":"0","path":["nestedObject"]}],"hasNext":true}',
                result='{"data":{"nestedObject":{}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":true,"pending":[{"id":"1","path":["nestedObject","nestedFriendList"]}],"incremental":[{"data":{"scalarField":"slow","nestedFriendList":[]},"id":"0"}],"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"pending":[{"id":"1","path":["nestedObject","nestedFriendList"]}],"incremental":[{"data":{"scalarField":"slow","nestedFriendList":[]},"id":"0"}],"completed":[{"id":"0"}]}',
                result='{"data":{"nestedObject":{"scalarField":"slow","nestedFriendList":[]}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":true,"incremental":[{"id":"1","items":[{"name":"Luke"}]}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"incremental":[{"id":"1","items":[{"name":"Luke"}]}]}',
                result='{"data":{"nestedObject":{"scalarField":"slow","nestedFriendList":[{"name":"Luke"}]}},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":true,"incremental":[{"id":"1","items":[{"name":"Han"}]}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"incremental":[{"id":"1","items":[{"name":"Han"}]}]}',
                result='{"data":{"nestedObject":{"scalarField":"slow","nestedFriendList":[{"name":"Luke"},{"name":"Han"}]}},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"completed":[{"id":"1"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"completed":[{"id":"1"}]}',
                result='{"data":{"nestedObject":{"scalarField":"slow","nestedFriendList":[{"name":"Luke"},{"name":"Han"}]}},"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_returns_payloads_in_correct_order_when_parent_deferred_fragment_resolves_slower_than_stream_with_0_initialcount() raises:
    """Returns payloads in correct order when parent deferred fragment resolves slower than stream with > 0 initialCount.
    """
    run_graphql17(
        [
            is_step(
                '{"data":{"nestedObject":{}},"pending":[{"id":"0","path":["nestedObject"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"nestedObject":{}},"pending":[{"id":"0","path":["nestedObject"]}],"hasNext":true}',
                result='{"data":{"nestedObject":{}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":true,"pending":[{"id":"1","path":["nestedObject","nestedFriendList"]}],"incremental":[{"data":{"scalarField":"slow","nestedFriendList":[{"name":"Luke"}]},"id":"0"}],"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"pending":[{"id":"1","path":["nestedObject","nestedFriendList"]}],"incremental":[{"data":{"scalarField":"slow","nestedFriendList":[{"name":"Luke"}]},"id":"0"}],"completed":[{"id":"0"}]}',
                result='{"data":{"nestedObject":{"scalarField":"slow","nestedFriendList":[{"name":"Luke"}]}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":true,"incremental":[{"id":"1","items":[{"name":"Han"}]}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"incremental":[{"id":"1","items":[{"name":"Han"}]}]}',
                result='{"data":{"nestedObject":{"scalarField":"slow","nestedFriendList":[{"name":"Luke"},{"name":"Han"}]}},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"completed":[{"id":"1"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"completed":[{"id":"1"}]}',
                result='{"data":{"nestedObject":{"scalarField":"slow","nestedFriendList":[{"name":"Luke"},{"name":"Han"}]}},"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_can_defer_fields_that_are_resolved_after_async_iterable_is_complete() raises:
    """Can @defer fields that are resolved after async iterable is complete."""
    run_graphql17(
        [
            is_step(
                '{"data":{"friendList":[]},"pending":[{"id":"0","path":["friendList"],"label":"stream-label"}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"friendList":[]},"pending":[{"id":"0","path":["friendList"],"label":"stream-label"}],"hasNext":true}',
                result='{"data":{"friendList":[]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":true,"pending":[{"id":"1","path":["friendList",0],"label":"DeferName"}],"incremental":[{"id":"0","items":[{"id":"1"}]},{"data":{"name":"Luke"},"id":"1"}],"completed":[{"id":"1"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"pending":[{"id":"1","path":["friendList",0],"label":"DeferName"}],"incremental":[{"id":"0","items":[{"id":"1"}]},{"data":{"name":"Luke"},"id":"1"}],"completed":[{"id":"1"}]}',
                result='{"data":{"friendList":[{"id":"1","name":"Luke"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":true,"pending":[{"id":"2","path":["friendList",1],"label":"DeferName"}],"incremental":[{"id":"0","items":[{"id":"2"}]}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"pending":[{"id":"2","path":["friendList",1],"label":"DeferName"}],"incremental":[{"id":"0","items":[{"id":"2"}]}]}',
                result='{"data":{"friendList":[{"id":"1","name":"Luke"},{"id":"2"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":true,"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"completed":[{"id":"0"}]}',
                result='{"data":{"friendList":[{"id":"1","name":"Luke"},{"id":"2"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"data":{"name":"Han"},"id":"2"}],"completed":[{"id":"2"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"incremental":[{"data":{"name":"Han"},"id":"2"}],"completed":[{"id":"2"}]}',
                result='{"data":{"friendList":[{"id":"1","name":"Luke"},{"id":"2","name":"Han"}]},"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_can_defer_fields_that_are_resolved_before_async_iterable_is_complete() raises:
    """Can @defer fields that are resolved before async iterable is complete."""
    run_graphql17(
        [
            is_step(
                '{"data":{"friendList":[{"id":"1"}]},"pending":[{"id":"0","path":["friendList",0],"label":"DeferName"},{"id":"1","path":["friendList"],"label":"stream-label"}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"friendList":[{"id":"1"}]},"pending":[{"id":"0","path":["friendList",0],"label":"DeferName"},{"id":"1","path":["friendList"],"label":"stream-label"}],"hasNext":true}',
                result='{"data":{"friendList":[{"id":"1"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":true,"incremental":[{"data":{"name":"Luke"},"id":"0"}],"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"incremental":[{"data":{"name":"Luke"},"id":"0"}],"completed":[{"id":"0"}]}',
                result='{"data":{"friendList":[{"id":"1","name":"Luke"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":true,"pending":[{"id":"2","path":["friendList",1],"label":"DeferName"}],"incremental":[{"id":"1","items":[{"id":"2"}]}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"pending":[{"id":"2","path":["friendList",1],"label":"DeferName"}],"incremental":[{"id":"1","items":[{"id":"2"}]}]}',
                result='{"data":{"friendList":[{"id":"1","name":"Luke"},{"id":"2"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":true,"incremental":[{"data":{"name":"Han"},"id":"2"}],"completed":[{"id":"2"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"incremental":[{"data":{"name":"Han"},"id":"2"}],"completed":[{"id":"2"}]}',
                result='{"data":{"friendList":[{"id":"1","name":"Luke"},{"id":"2","name":"Han"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"completed":[{"id":"1"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"completed":[{"id":"1"}]}',
                result='{"data":{"friendList":[{"id":"1","name":"Luke"},{"id":"2","name":"Han"}]},"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_properly_merges_streamed_data_into_cache_data() raises:
    """Properly merges streamed data into cache data."""
    run_graphql17(
        [
            is_step(
                '{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                (
                    '{"friendList":[{"name":"Luke'
                    ' Cached","id":"1"},{"name":"Han'
                    ' Cached","id":"2"},{"name":"Leia Cached","id":"3"}]}'
                ),
                '{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"id":"0","items":[{"name":"Leia","id":"3"}]}],"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                '{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]}',
                '{"hasNext":false,"incremental":[{"id":"0","items":[{"name":"Leia","id":"3"}]}],"completed":[{"id":"0"}]}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"},{"name":"Leia","id":"3"}]},"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_properly_merges_streamed_data_into_partial_cache_data() raises:
    """Properly merges streamed data into partial cache data."""
    run_graphql17(
        [
            is_step(
                '{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                '{"friendList":[{"id":"1"},{"id":"2"},{"id":"3"}]}',
                '{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                result='{"data":{"friendList":[{"id":"1","name":"Luke"},{"id":"2","name":"Han"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"id":"0","items":[{"name":"Leia","id":"3"}]}],"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                '{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]}',
                '{"hasNext":false,"incremental":[{"id":"0","items":[{"name":"Leia","id":"3"}]}],"completed":[{"id":"0"}]}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"},{"name":"Leia","id":"3"}]},"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_properly_merges_streamed_data_into_list_with_fewer_items() raises:
    """Properly merges streamed data into list with fewer items."""
    run_graphql17(
        [
            is_step(
                '{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                '{"friendList":[{"id":"1","name":"Luke Cached"}]}',
                '{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                result='{"data":{"friendList":[{"id":"1","name":"Luke"},{"name":"Han","id":"2"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"id":"0","items":[{"name":"Leia","id":"3"}]}],"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                '{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]}',
                '{"hasNext":false,"incremental":[{"id":"0","items":[{"name":"Leia","id":"3"}]}],"completed":[{"id":"0"}]}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"},{"name":"Leia","id":"3"}]},"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_properly_merges_streamed_data_into_list_with_more_items() raises:
    """Properly merges streamed data into list with more items."""
    run_graphql17(
        [
            is_step(
                '{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                (
                    '{"friendList":[{"name":"Luke'
                    ' Cached","id":"1"},{"name":"Han'
                    ' Cached","id":"2"},{"name":"Leia'
                    ' Cached","id":"3"},{"name":"Chewbacca Cached","id":"4"}]}'
                ),
                '{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"id":"0","items":[{"name":"Leia","id":"3"}]}],"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                '{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]}',
                '{"hasNext":false,"incremental":[{"id":"0","items":[{"name":"Leia","id":"3"}]}],"completed":[{"id":"0"}]}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"},{"name":"Leia","id":"3"}]},"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_truncates_cache_data_to_the_streamed_items_when_the_stream_completes_with_errors() raises:
    """Truncates cache data to the streamed items when the stream completes with errors.
    """
    run_graphql17(
        [
            is_step(
                '{"data":{"nonNullFriendList":[{"name":"Luke","id":"1"}]},"pending":[{"id":"0","path":["nonNullFriendList"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                (
                    '{"nonNullFriendList":[{"name":"Luke'
                    ' Cached","id":"1"},{"name":"Han'
                    ' Cached","id":"2"},{"name":"Leia Cached","id":"3"}]}'
                ),
                '{"data":{"nonNullFriendList":[{"name":"Luke","id":"1"}]},"pending":[{"id":"0","path":["nonNullFriendList"]}],"hasNext":true}',
                result='{"data":{"nonNullFriendList":[{"name":"Luke","id":"1"}]},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                (
                    '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' Query.nonNullFriendList.","path":["nonNullFriendList",1]}]}]}'
                ),
                True,
            ),
            handle_step(
                (
                    '{"nonNullFriendList":[{"name":"Luke","id":"1"},{"name":"Han'
                    ' Cached","id":"2"},{"name":"Leia Cached","id":"3"}]}'
                ),
                (
                    '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' Query.nonNullFriendList.","path":["nonNullFriendList",1]}]}]}'
                ),
                result=(
                    '{"data":{"nonNullFriendList":[{"name":"Luke","id":"1"}]},"errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' Query.nonNullFriendList.","path":["nonNullFriendList",1]}],"extensions":{}}'
                ),
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def test_properly_merges_cache_data_when_list_is_included_in_deferred_chunk() raises:
    """Properly merges cache data when list is included in deferred chunk."""
    run_graphql17(
        [
            is_step(
                '{"data":{"nestedObject":{}},"pending":[{"id":"0","path":["nestedObject"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                (
                    '{"nestedObject":{"scalarField":"cached","nestedFriendList":[{"name":"Luke'
                    ' Cached"},{"name":"Han Cached"}]}}'
                ),
                '{"data":{"nestedObject":{}},"pending":[{"id":"0","path":["nestedObject"]}],"hasNext":true}',
                result=(
                    '{"data":{"nestedObject":{"scalarField":"cached","nestedFriendList":[{"name":"Luke'
                    ' Cached"},{"name":"Han Cached"}]}}}'
                ),
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":true,"pending":[{"id":"1","path":["nestedObject","nestedFriendList"]}],"incremental":[{"data":{"scalarField":"slow","nestedFriendList":[]},"id":"0"}],"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                (
                    '{"nestedObject":{"scalarField":"cached","nestedFriendList":[{"name":"Luke'
                    ' Cached"},{"name":"Han Cached"}]}}'
                ),
                '{"hasNext":true,"pending":[{"id":"1","path":["nestedObject","nestedFriendList"]}],"incremental":[{"data":{"scalarField":"slow","nestedFriendList":[]},"id":"0"}],"completed":[{"id":"0"}]}',
                result='{"data":{"nestedObject":{"scalarField":"slow","nestedFriendList":[]}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":true,"incremental":[{"id":"1","items":[{"name":"Luke"}]}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"incremental":[{"id":"1","items":[{"name":"Luke"}]}]}',
                result='{"data":{"nestedObject":{"scalarField":"slow","nestedFriendList":[{"name":"Luke"}]}},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":true,"incremental":[{"id":"1","items":[{"name":"Han"}]}]}',
                True,
            ),
            handle_step(
                '{"nestedObject":{"scalarField":"slow","nestedFriendList":[{"name":"Luke"}]}}',
                '{"hasNext":true,"incremental":[{"id":"1","items":[{"name":"Han"}]}]}',
                result='{"data":{"nestedObject":{"scalarField":"slow","nestedFriendList":[{"name":"Luke"},{"name":"Han"}]}},"extensions":{}}',
                has_next=True,
                stream_info=True,
            ),
            is_step(
                '{"hasNext":false,"completed":[{"id":"1"}]}',
                True,
            ),
            handle_step(
                '{"nestedObject":{"scalarField":"slow","nestedFriendList":[{"name":"Luke"},{"name":"Han"}]}}',
                '{"hasNext":false,"completed":[{"id":"1"}]}',
                result='{"data":{"nestedObject":{"scalarField":"slow","nestedFriendList":[{"name":"Luke"},{"name":"Han"}]}},"extensions":{}}',
                has_next=False,
                stream_info=True,
            ),
        ]
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

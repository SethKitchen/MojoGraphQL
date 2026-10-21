# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `Defer20220824Handler` with `@stream`: Apollo Client 4.3.3
(ae0dfce) `src/incremental/handlers/__tests__/defer20220824/stream.test.ts`.

Each case has the payloads and the results of the upstream case. They
were recorded from the upstream test itself, run in Node.js with Apollo
Client 4.3.3 and graphql 17.0.0-alpha.2, the versions of the upstream
test. Each step is one call of `isIncrementalResult` or `handle`, in the
order of the upstream test, and the result must have the same JSON.

These upstream cases are not here:

- The cases that upstream skips with `it.skip`.
- "Defer20220824Handler can be used with `ApolloClient`": it runs
  `ApolloClient` with a link. `test_query_info.mojo` ports its cache
  writes.
"""

from std.testing import TestSuite

from _incremental_helpers import (
    UNDEFINED,
    handle_step,
    is_step,
    run_defer20220824,
)


def test_can_stream_a_list_field() raises:
    """Can stream a list field."""
    run_defer20220824(
        [
            is_step(
                '{"data":{"scalarList":["apple"]},"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"scalarList":["apple"]},"hasNext":true}',
                result='{"data":{"scalarList":["apple"]}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"items":["banana"],"path":["scalarList",1]},{"items":["coconut"],"path":["scalarList",2]}],"hasNext":false}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"items":["banana"],"path":["scalarList",1]},{"items":["coconut"],"path":["scalarList",2]}],"hasNext":false}',
                result='{"data":{"scalarList":["apple","banana","coconut"]}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_can_use_default_value_of_initialcount() raises:
    """Can use default value of initialCount."""
    run_defer20220824(
        [
            is_step(
                '{"data":{"scalarList":[]},"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"scalarList":[]},"hasNext":true}',
                result='{"data":{"scalarList":[]}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"items":["apple"],"path":["scalarList",0]},{"items":["banana"],"path":["scalarList",1]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"items":["apple"],"path":["scalarList",0]},{"items":["banana"],"path":["scalarList",1]}],"hasNext":true}',
                result='{"data":{"scalarList":["apple","banana"]}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"items":["coconut"],"path":["scalarList",2]}],"hasNext":false}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"items":["coconut"],"path":["scalarList",2]}],"hasNext":false}',
                result='{"data":{"scalarList":["apple","banana","coconut"]}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_does_not_disable_stream_with_null_if_argument() raises:
    """Does not disable stream with null if argument."""
    run_defer20220824(
        [
            is_step(
                '{"data":{"scalarList":["apple","banana"]},"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"scalarList":["apple","banana"]},"hasNext":true}',
                result='{"data":{"scalarList":["apple","banana"]}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"items":["coconut"],"path":["scalarList",2]}],"hasNext":false}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"items":["coconut"],"path":["scalarList",2]}],"hasNext":false}',
                result='{"data":{"scalarList":["apple","banana","coconut"]}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_can_stream_multi_dimensional_lists() raises:
    """Can stream multi-dimensional lists."""
    run_defer20220824(
        [
            is_step(
                '{"data":{"scalarListList":[["apple","apple","apple"]]},"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"scalarListList":[["apple","apple","apple"]]},"hasNext":true}',
                result=(
                    '{"data":{"scalarListList":[["apple","apple","apple"]]}}'
                ),
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"items":[["banana","banana","banana"]],"path":["scalarListList",1]},{"items":[["coconut","coconut","coconut"]],"path":["scalarListList",2]}],"hasNext":false}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"items":[["banana","banana","banana"]],"path":["scalarListList",1]},{"items":[["coconut","coconut","coconut"]],"path":["scalarListList",2]}],"hasNext":false}',
                result='{"data":{"scalarListList":[["apple","apple","apple"],["banana","banana","banana"],["coconut","coconut","coconut"]]}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_can_stream_a_field_that_returns_a_list_of_promises() raises:
    """Can stream a field that returns a list of promises."""
    run_defer20220824(
        [
            is_step(
                '{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"hasNext":true}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"items":[{"name":"Leia","id":"3"}],"path":["friendList",2]}],"hasNext":false}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"items":[{"name":"Leia","id":"3"}],"path":["friendList",2]}],"hasNext":false}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"},{"name":"Leia","id":"3"}]}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_can_stream_in_correct_order_with_lists_of_promises() raises:
    """Can stream in correct order with lists of promises."""
    run_defer20220824(
        [
            is_step(
                '{"data":{"friendList":[]},"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"friendList":[]},"hasNext":true}',
                result='{"data":{"friendList":[]}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"items":[{"name":"Luke","id":"1"}],"path":["friendList",0]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"items":[{"name":"Luke","id":"1"}],"path":["friendList",0]}],"hasNext":true}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"}]}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"items":[{"name":"Han","id":"2"}],"path":["friendList",1]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"items":[{"name":"Han","id":"2"}],"path":["friendList",1]}],"hasNext":true}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"items":[{"name":"Leia","id":"3"}],"path":["friendList",2]}],"hasNext":false}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"items":[{"name":"Leia","id":"3"}],"path":["friendList",2]}],"hasNext":false}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"},{"name":"Leia","id":"3"}]}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_handles_rejections_in_a_field_that_returns_a_list_of_promises_before_initialcount_is_reached() raises:
    """Handles rejections in a field that returns a list of promises before initialCount is reached.
    """
    run_defer20220824(
        [
            is_step(
                '{"errors":[{"message":"bad","path":["friendList",1]}],"data":{"friendList":[{"name":"Luke","id":"1"},null]},"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"errors":[{"message":"bad","path":["friendList",1]}],"data":{"friendList":[{"name":"Luke","id":"1"},null]},"hasNext":true}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},null]},"errors":[{"message":"bad","path":["friendList",1]}]}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"items":[{"name":"Leia","id":"3"}],"path":["friendList",2]}],"hasNext":false}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"items":[{"name":"Leia","id":"3"}],"path":["friendList",2]}],"hasNext":false}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},null,{"name":"Leia","id":"3"}]},"errors":[{"message":"bad","path":["friendList",1]}]}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_handles_rejections_in_a_field_that_returns_a_list_of_promises_after_initialcount_is_reached() raises:
    """Handles rejections in a field that returns a list of promises after initialCount is reached.
    """
    run_defer20220824(
        [
            is_step(
                '{"data":{"friendList":[{"name":"Luke","id":"1"}]},"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"friendList":[{"name":"Luke","id":"1"}]},"hasNext":true}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"}]}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"items":[null],"path":["friendList",1],"errors":[{"message":"bad","path":["friendList",1]}]},{"items":[{"name":"Leia","id":"3"}],"path":["friendList",2]}],"hasNext":false}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"items":[null],"path":["friendList",1],"errors":[{"message":"bad","path":["friendList",1]}]},{"items":[{"name":"Leia","id":"3"}],"path":["friendList",2]}],"hasNext":false}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},null,{"name":"Leia","id":"3"}]},"errors":[{"message":"bad","path":["friendList",1]}]}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_can_stream_a_field_that_returns_an_async_iterable() raises:
    """Can stream a field that returns an async iterable."""
    run_defer20220824(
        [
            is_step(
                '{"data":{"friendList":[]},"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"friendList":[]},"hasNext":true}',
                result='{"data":{"friendList":[]}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"items":[{"name":"Luke","id":"1"}],"path":["friendList",0]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"items":[{"name":"Luke","id":"1"}],"path":["friendList",0]}],"hasNext":true}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"}]}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"items":[{"name":"Han","id":"2"}],"path":["friendList",1]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"items":[{"name":"Han","id":"2"}],"path":["friendList",1]}],"hasNext":true}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"items":[{"name":"Leia","id":"3"}],"path":["friendList",2]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"items":[{"name":"Leia","id":"3"}],"path":["friendList",2]}],"hasNext":true}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"},{"name":"Leia","id":"3"}]}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":false}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"},{"name":"Leia","id":"3"}]}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_can_stream_a_field_that_returns_an_async_iterable_using_a_non_zero_initialcount() raises:
    """Can stream a field that returns an async iterable, using a non-zero initialCount.
    """
    run_defer20220824(
        [
            is_step(
                '{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"hasNext":true}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"items":[{"name":"Leia","id":"3"}],"path":["friendList",2]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"items":[{"name":"Leia","id":"3"}],"path":["friendList",2]}],"hasNext":true}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"},{"name":"Leia","id":"3"}]}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":false}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"},{"name":"Leia","id":"3"}]}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_handles_error_thrown_in_async_iterable_after_initialcount_is_reached() raises:
    """Handles error thrown in async iterable after initialCount is reached."""
    run_defer20220824(
        [
            is_step(
                '{"data":{"friendList":[{"name":"Luke","id":"1"}]},"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"friendList":[{"name":"Luke","id":"1"}]},"hasNext":true}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"}]}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"items":[null],"path":["friendList",1],"errors":[{"message":"bad","path":["friendList",1]}]}],"hasNext":false}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"items":[null],"path":["friendList",1],"errors":[{"message":"bad","path":["friendList",1]}]}],"hasNext":false}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},null]},"errors":[{"message":"bad","path":["friendList",1]}]}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_handles_null_returned_in_non_null_list_items_after_initialcount_is_reached() raises:
    """Handles null returned in non-null list items after initialCount is reached.
    """
    run_defer20220824(
        [
            is_step(
                '{"data":{"nonNullFriendList":[{"name":"Luke"}]},"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"nonNullFriendList":[{"name":"Luke"}]},"hasNext":true}',
                result='{"data":{"nonNullFriendList":[{"name":"Luke"}]}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                (
                    '{"incremental":[{"items":null,"path":["nonNullFriendList",1],"errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' Query.nonNullFriendList.","path":["nonNullFriendList",1]}]}],"hasNext":false}'
                ),
                True,
            ),
            handle_step(
                UNDEFINED,
                (
                    '{"incremental":[{"items":null,"path":["nonNullFriendList",1],"errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' Query.nonNullFriendList.","path":["nonNullFriendList",1]}]}],"hasNext":false}'
                ),
                result=(
                    '{"data":{"nonNullFriendList":[{"name":"Luke"}]},"errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' Query.nonNullFriendList.","path":["nonNullFriendList",1]}]}'
                ),
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_handles_errors_thrown_by_completevalue_after_initialcount_is_reached() raises:
    """Handles errors thrown by completeValue after initialCount is reached."""
    run_defer20220824(
        [
            is_step(
                '{"data":{"scalarList":["Luke"]},"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"scalarList":["Luke"]},"hasNext":true}',
                result='{"data":{"scalarList":["Luke"]}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                (
                    '{"incremental":[{"items":[null],"path":["scalarList",1],"errors":[{"message":"String'
                    " cannot represent value:"
                    ' {}","path":["scalarList",1]}]}],"hasNext":false}'
                ),
                True,
            ),
            handle_step(
                UNDEFINED,
                (
                    '{"incremental":[{"items":[null],"path":["scalarList",1],"errors":[{"message":"String'
                    " cannot represent value:"
                    ' {}","path":["scalarList",1]}]}],"hasNext":false}'
                ),
                result=(
                    '{"data":{"scalarList":["Luke",null]},"errors":[{"message":"String'
                    ' cannot represent value: {}","path":["scalarList",1]}]}'
                ),
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_handles_async_errors_thrown_by_completevalue_after_initialcount_is_reached() raises:
    """Handles async errors thrown by completeValue after initialCount is reached.
    """
    run_defer20220824(
        [
            is_step(
                '{"data":{"nonNullFriendList":[{"nonNullName":"Luke"}]},"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"nonNullFriendList":[{"nonNullName":"Luke"}]},"hasNext":true}',
                result=(
                    '{"data":{"nonNullFriendList":[{"nonNullName":"Luke"}]}}'
                ),
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"items":null,"path":["nonNullFriendList",1],"errors":[{"message":"Oops","path":["nonNullFriendList",1,"nonNullName"]}]}],"hasNext":false}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"items":null,"path":["nonNullFriendList",1],"errors":[{"message":"Oops","path":["nonNullFriendList",1,"nonNullName"]}]}],"hasNext":false}',
                result='{"data":{"nonNullFriendList":[{"nonNullName":"Luke"}]},"errors":[{"message":"Oops","path":["nonNullFriendList",1,"nonNullName"]}]}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_handles_async_errors_thrown_by_completevalue_after_initialcount_is_reached_from_async_iterable() raises:
    """Handles async errors thrown by completeValue after initialCount is reached from async iterable.
    """
    run_defer20220824(
        [
            is_step(
                '{"data":{"friendList":[{"nonNullName":"Luke"}]},"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"friendList":[{"nonNullName":"Luke"}]},"hasNext":true}',
                result='{"data":{"friendList":[{"nonNullName":"Luke"}]}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"items":[null],"path":["friendList",1],"errors":[{"message":"Oops","path":["friendList",1,"nonNullName"]}]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"items":[null],"path":["friendList",1],"errors":[{"message":"Oops","path":["friendList",1,"nonNullName"]}]}],"hasNext":true}',
                result='{"data":{"friendList":[{"nonNullName":"Luke"},null]},"errors":[{"message":"Oops","path":["friendList",1,"nonNullName"]}]}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"items":[{"nonNullName":"Han"}],"path":["friendList",2]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"items":[{"nonNullName":"Han"}],"path":["friendList",2]}],"hasNext":true}',
                result='{"data":{"friendList":[{"nonNullName":"Luke"},null,{"nonNullName":"Han"}]},"errors":[{"message":"Oops","path":["friendList",1,"nonNullName"]}]}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":false}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false}',
                result='{"data":{"friendList":[{"nonNullName":"Luke"},null,{"nonNullName":"Han"}]},"errors":[{"message":"Oops","path":["friendList",1,"nonNullName"]}]}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_does_not_filter_payloads_when_null_error_is_in_a_different_path() raises:
    """Does not filter payloads when null error is in a different path."""
    run_defer20220824(
        [
            is_step(
                '{"data":{"otherNestedObject":{},"nestedObject":{"nestedFriendList":[]}},"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"otherNestedObject":{},"nestedObject":{"nestedFriendList":[]}},"hasNext":true}',
                result='{"data":{"otherNestedObject":{},"nestedObject":{"nestedFriendList":[]}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"data":{"scalarField":null},"path":["otherNestedObject"],"errors":[{"message":"Oops","path":["otherNestedObject","scalarField"]}]},{"items":[{"name":"Luke"}],"path":["nestedObject","nestedFriendList",0]}],"hasNext":false}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"data":{"scalarField":null},"path":["otherNestedObject"],"errors":[{"message":"Oops","path":["otherNestedObject","scalarField"]}]},{"items":[{"name":"Luke"}],"path":["nestedObject","nestedFriendList",0]}],"hasNext":false}',
                result='{"data":{"otherNestedObject":{"scalarField":null},"nestedObject":{"nestedFriendList":[{"name":"Luke"}]}},"errors":[{"message":"Oops","path":["otherNestedObject","scalarField"]}]}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_filters_stream_payloads_that_are_nulled_in_a_deferred_payload() raises:
    """Filters stream payloads that are nulled in a deferred payload."""
    run_defer20220824(
        [
            is_step(
                '{"data":{"nestedObject":{}},"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"nestedObject":{}},"hasNext":true}',
                result='{"data":{"nestedObject":{}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                (
                    '{"incremental":[{"data":{"deeperNestedObject":null},"path":["nestedObject"],"errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' DeeperNestedObject.nonNullScalarField.","path":["nestedObject","deeperNestedObject","nonNullScalarField"]}]}],"hasNext":false}'
                ),
                True,
            ),
            handle_step(
                UNDEFINED,
                (
                    '{"incremental":[{"data":{"deeperNestedObject":null},"path":["nestedObject"],"errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' DeeperNestedObject.nonNullScalarField.","path":["nestedObject","deeperNestedObject","nonNullScalarField"]}]}],"hasNext":false}'
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
    run_defer20220824(
        [
            is_step(
                '{"data":{"friendList":[]},"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"friendList":[]},"hasNext":true}',
                result='{"data":{"friendList":[]}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                (
                    '{"incremental":[{"items":[null],"path":["friendList",0],"errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' Friend.nonNullName.","path":["friendList",0,"nonNullName"]}]}],"hasNext":true}'
                ),
                True,
            ),
            handle_step(
                UNDEFINED,
                (
                    '{"incremental":[{"items":[null],"path":["friendList",0],"errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' Friend.nonNullName.","path":["friendList",0,"nonNullName"]}]}],"hasNext":true}'
                ),
                result=(
                    '{"data":{"friendList":[null]},"errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' Friend.nonNullName.","path":["friendList",0,"nonNullName"]}]}'
                ),
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":false}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false}',
                result=(
                    '{"data":{"friendList":[null]},"errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' Friend.nonNullName.","path":["friendList",0,"nonNullName"]}]}'
                ),
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_handles_promises_returned_by_completevalue_after_initialcount_is_reached() raises:
    """Handles promises returned by completeValue after initialCount is reached.
    """
    run_defer20220824(
        [
            is_step(
                '{"data":{"friendList":[{"id":"1","name":"Luke"}]},"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"friendList":[{"id":"1","name":"Luke"}]},"hasNext":true}',
                result='{"data":{"friendList":[{"id":"1","name":"Luke"}]}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"items":[{"id":"2","name":"Han"}],"path":["friendList",1]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"items":[{"id":"2","name":"Han"}],"path":["friendList",1]}],"hasNext":true}',
                result='{"data":{"friendList":[{"id":"1","name":"Luke"},{"id":"2","name":"Han"}]}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"items":[{"id":"3","name":"Leia"}],"path":["friendList",2]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"items":[{"id":"3","name":"Leia"}],"path":["friendList",2]}],"hasNext":true}',
                result='{"data":{"friendList":[{"id":"1","name":"Luke"},{"id":"2","name":"Han"},{"id":"3","name":"Leia"}]}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":false}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false}',
                result='{"data":{"friendList":[{"id":"1","name":"Luke"},{"id":"2","name":"Han"},{"id":"3","name":"Leia"}]}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_returns_payloads_in_correct_order_when_parent_deferred_fragment_resolves_slower_than_stream() raises:
    """Returns payloads in correct order when parent deferred fragment resolves slower than stream.
    """
    run_defer20220824(
        [
            is_step(
                '{"data":{"nestedObject":{}},"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"nestedObject":{}},"hasNext":true}',
                result='{"data":{"nestedObject":{}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"data":{"scalarField":"slow","nestedFriendList":[]},"path":["nestedObject"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"data":{"scalarField":"slow","nestedFriendList":[]},"path":["nestedObject"]}],"hasNext":true}',
                result='{"data":{"nestedObject":{"scalarField":"slow","nestedFriendList":[]}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"items":[{"name":"Luke"}],"path":["nestedObject","nestedFriendList",0]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"items":[{"name":"Luke"}],"path":["nestedObject","nestedFriendList",0]}],"hasNext":true}',
                result='{"data":{"nestedObject":{"scalarField":"slow","nestedFriendList":[{"name":"Luke"}]}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"items":[{"name":"Han"}],"path":["nestedObject","nestedFriendList",1]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"items":[{"name":"Han"}],"path":["nestedObject","nestedFriendList",1]}],"hasNext":true}',
                result='{"data":{"nestedObject":{"scalarField":"slow","nestedFriendList":[{"name":"Luke"},{"name":"Han"}]}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":false}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false}',
                result='{"data":{"nestedObject":{"scalarField":"slow","nestedFriendList":[{"name":"Luke"},{"name":"Han"}]}}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_can_defer_fields_that_are_resolved_after_async_iterable_is_complete() raises:
    """Can @defer fields that are resolved after async iterable is complete."""
    run_defer20220824(
        [
            is_step(
                '{"data":{"friendList":[{"id":"1"}]},"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"friendList":[{"id":"1"}]},"hasNext":true}',
                result='{"data":{"friendList":[{"id":"1"}]}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"data":{"name":"Luke"},"path":["friendList",0],"label":"DeferName"},{"items":[{"id":"2"}],"path":["friendList",1],"label":"stream-label"}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"data":{"name":"Luke"},"path":["friendList",0],"label":"DeferName"},{"items":[{"id":"2"}],"path":["friendList",1],"label":"stream-label"}],"hasNext":true}',
                result='{"data":{"friendList":[{"id":"1","name":"Luke"},{"id":"2"}]}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"data":{"name":"Han"},"path":["friendList",1],"label":"DeferName"}],"hasNext":false}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"data":{"name":"Han"},"path":["friendList",1],"label":"DeferName"}],"hasNext":false}',
                result='{"data":{"friendList":[{"id":"1","name":"Luke"},{"id":"2","name":"Han"}]}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_properly_merges_streamed_data_into_cache_data() raises:
    """Properly merges streamed data into cache data."""
    run_defer20220824(
        [
            is_step(
                '{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"hasNext":true}',
                True,
            ),
            handle_step(
                (
                    '{"friendList":[{"name":"Luke'
                    ' Cached","id":"1"},{"name":"Han'
                    ' Cached","id":"2"},{"name":"Leia Cached","id":"3"}]}'
                ),
                '{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"hasNext":true}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"items":[{"name":"Leia","id":"3"}],"path":["friendList",2]}],"hasNext":false}',
                True,
            ),
            handle_step(
                '{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]}',
                '{"incremental":[{"items":[{"name":"Leia","id":"3"}],"path":["friendList",2]}],"hasNext":false}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"},{"name":"Leia","id":"3"}]}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_properly_merges_streamed_data_into_partial_cache_data() raises:
    """Properly merges streamed data into partial cache data."""
    run_defer20220824(
        [
            is_step(
                '{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"hasNext":true}',
                True,
            ),
            handle_step(
                '{"friendList":[{"id":"1"},{"id":"2"},{"id":"3"}]}',
                '{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"hasNext":true}',
                result='{"data":{"friendList":[{"id":"1","name":"Luke"},{"id":"2","name":"Han"}]}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"items":[{"name":"Leia","id":"3"}],"path":["friendList",2]}],"hasNext":false}',
                True,
            ),
            handle_step(
                '{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]}',
                '{"incremental":[{"items":[{"name":"Leia","id":"3"}],"path":["friendList",2]}],"hasNext":false}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"},{"name":"Leia","id":"3"}]}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_properly_merges_streamed_data_into_list_with_fewer_items() raises:
    """Properly merges streamed data into list with fewer items."""
    run_defer20220824(
        [
            is_step(
                '{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"hasNext":true}',
                True,
            ),
            handle_step(
                '{"friendList":[{"id":"1","name":"Luke Cached"}]}',
                '{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"hasNext":true}',
                result='{"data":{"friendList":[{"id":"1","name":"Luke"},{"name":"Han","id":"2"}]}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"items":[{"name":"Leia","id":"3"}],"path":["friendList",2]}],"hasNext":false}',
                True,
            ),
            handle_step(
                '{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]}',
                '{"incremental":[{"items":[{"name":"Leia","id":"3"}],"path":["friendList",2]}],"hasNext":false}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"},{"name":"Leia","id":"3"}]}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_properly_merges_streamed_data_into_list_with_more_items() raises:
    """Properly merges streamed data into list with more items."""
    run_defer20220824(
        [
            is_step(
                '{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"hasNext":true}',
                True,
            ),
            handle_step(
                (
                    '{"friendList":[{"name":"Luke'
                    ' Cached","id":"1"},{"name":"Han'
                    ' Cached","id":"2"},{"name":"Leia'
                    ' Cached","id":"3"},{"name":"Chewbacca Cached","id":"4"}]}'
                ),
                '{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]},"hasNext":true}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"items":[{"name":"Leia","id":"3"}],"path":["friendList",2]}],"hasNext":false}',
                True,
            ),
            handle_step(
                '{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"}]}',
                '{"incremental":[{"items":[{"name":"Leia","id":"3"}],"path":["friendList",2]}],"hasNext":false}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"},{"name":"Leia","id":"3"}]}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_properly_merges_cache_data_when_list_is_included_in_deferred_chunk() raises:
    """Properly merges cache data when list is included in deferred chunk."""
    run_defer20220824(
        [
            is_step(
                '{"data":{"nestedObject":{}},"hasNext":true}',
                True,
            ),
            handle_step(
                (
                    '{"nestedObject":{"scalarField":"cached","nestedFriendList":[{"name":"Luke'
                    ' Cached"},{"name":"Han Cached"}]}}'
                ),
                '{"data":{"nestedObject":{}},"hasNext":true}',
                result=(
                    '{"data":{"nestedObject":{"scalarField":"cached","nestedFriendList":[{"name":"Luke'
                    ' Cached"},{"name":"Han Cached"}]}}}'
                ),
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"data":{"scalarField":"slow","nestedFriendList":[]},"path":["nestedObject"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                (
                    '{"nestedObject":{"scalarField":"cached","nestedFriendList":[{"name":"Luke'
                    ' Cached"},{"name":"Han Cached"}]}}'
                ),
                '{"incremental":[{"data":{"scalarField":"slow","nestedFriendList":[]},"path":["nestedObject"]}],"hasNext":true}',
                result='{"data":{"nestedObject":{"scalarField":"slow","nestedFriendList":[]}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"items":[{"name":"Luke"}],"path":["nestedObject","nestedFriendList",0]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"items":[{"name":"Luke"}],"path":["nestedObject","nestedFriendList",0]}],"hasNext":true}',
                result='{"data":{"nestedObject":{"scalarField":"slow","nestedFriendList":[{"name":"Luke"}]}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"items":[{"name":"Han"}],"path":["nestedObject","nestedFriendList",1]}],"hasNext":true}',
                True,
            ),
            handle_step(
                '{"nestedObject":{"scalarField":"slow","nestedFriendList":[{"name":"Luke"}]}}',
                '{"incremental":[{"items":[{"name":"Han"}],"path":["nestedObject","nestedFriendList",1]}],"hasNext":true}',
                result='{"data":{"nestedObject":{"scalarField":"slow","nestedFriendList":[{"name":"Luke"},{"name":"Han"}]}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":false}',
                True,
            ),
            handle_step(
                '{"nestedObject":{"scalarField":"slow","nestedFriendList":[{"name":"Luke"},{"name":"Han"}]}}',
                '{"hasNext":false}',
                result='{"data":{"nestedObject":{"scalarField":"slow","nestedFriendList":[{"name":"Luke"},{"name":"Han"}]}}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_handles_streams_with_more_than_one_item_in_a_chunk() raises:
    """Handles streams with more than one item in a chunk."""
    run_defer20220824(
        [
            handle_step(
                UNDEFINED,
                '{"data":{"friendList":[{"name":"Luke","id":"1"}]},"hasNext":true}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"}]}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"items":[{"name":"Han","id":"2"},{"name":"Leia","id":"3"}],"path":["friendList",1]}],"hasNext":false}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"items":[{"name":"Han","id":"2"},{"name":"Leia","id":"3"}],"path":["friendList",1]}],"hasNext":false}',
                result='{"data":{"friendList":[{"name":"Luke","id":"1"},{"name":"Han","id":"2"},{"name":"Leia","id":"3"}]}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

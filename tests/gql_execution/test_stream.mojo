# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `@stream`: graphql-js v17.0.2 (71606d73)
`src/execution/incremental/__tests__/stream-test.ts`.

Each case has the upstream operation and the upstream root value, made
synchronous as in `test_defer.mojo`. An async iterable becomes the marker
`{"__stream": "[...]", "__error": message}`: `throwing_resolver` makes it
a `ListStream` event stream, which ends with the error when there is one.
The expected payloads are the output of graphql-js v17.0.2, run
in Node.js with a synchronous generator in the place of the marker. Each
item of a `ListStream` is ready, so the event stream gives the payloads of
the list.

These upstream cases are not ported:

- "Can handle concurrent calls to .next() without waiting", "Re-promotes a
  completed stream when a slower sibling defer resolves later", "Returns
  payloads in correct order when parent deferred fragment resolves slower
  than stream", "Can @defer fields that are resolved after async iterable
  is complete" and "Can @defer fields that are resolved before async
  iterable is complete": they hold promises open to order the payloads.
  Synchronous execution has one order.
- "Cancels async stream items when null bubbles past the stream" and
  "Returns iterator and ignores errors when stream payloads are filtered":
  they check the `return()` of an iterator that upstream filters.
  `test_incremental_streams.mojo` checks that a filtered event stream is
  closed.
- "limits stream batches to the default capacity (100)": it reads the
  batches with a hand-driven iterator. `test_incremental_streams.mojo`
  checks the capacity with the same list.
- "Does not call `return` on an exhausted sync iterator", the cases of
  `return()`, `throw()` and `Symbol.asyncDispose`, and the cases of the
  abort signal: they spy on the iterator. `test_incremental_cancel.mojo`
  ports them with a `ProbeStream`, and lists the cases that it does not
  port.
"""

from std.testing import TestSuite

from gql_schema.build import build_schema

from _incremental import expect

comptime _SDL = """
type Friend { id: ID name: String nonNullName: String! }
type DeeperNestedObject {
  nonNullScalarField: String!
  deeperNestedFriendList: [Friend]
}
type NestedObject {
  scalarField: String
  nonNullScalarField: String!
  nestedFriendList: [Friend]
  deeperNestedObject: DeeperNestedObject
}
type Query {
  scalarList: [String]
  scalarListList: [[String]]
  friendList: [Friend]
  nonNullFriendList: [Friend!]
  nestedObject: NestedObject
}
"""


def _expect(query: String, root: String, expected: List[String]) raises:
    """Check the payloads of an operation against the upstream schema.
    The schema does not define `@stream`, as upstream."""
    expect(build_schema(_SDL), query, root, expected)


def test_can_stream_a_list_field() raises:
    """Can stream a list field."""
    _expect(
        "{ scalarList @stream(initialCount: 1) }",
        '{"scalarList":["apple","banana","coconut"]}',
        [
            '{"data":{"scalarList":["apple"]},"pending":[{"id":"0","path":["scalarList"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","items":["banana","coconut"]}],"completed":[{"id":"0"}]}',
        ],
    )


def test_can_use_default_value_of_initialcount() raises:
    """Can use default value of initialCount."""
    _expect(
        "{ scalarList @stream }",
        '{"scalarList":["apple","banana","coconut"]}',
        [
            '{"data":{"scalarList":[]},"pending":[{"id":"0","path":["scalarList"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","items":["apple","banana","coconut"]}],"completed":[{"id":"0"}]}',
        ],
    )


def test_negative_values_of_initialcount_throw_field_errors() raises:
    """Negative values of initialCount throw field errors."""
    _expect(
        "{ scalarList @stream(initialCount: -2) }",
        '{"scalarList":["apple","banana","coconut"]}',
        [
            (
                '{"errors":[{"message":"initialCount must be a positive'
                ' integer","locations":[{"line":1,"column":3}],"path":["scalarList"]}],"data":{"scalarList":null}}'
            ),
        ],
    )


def test_returns_label_from_stream_directive() raises:
    """Returns label from stream directive."""
    _expect(
        '{ scalarList @stream(initialCount: 1, label: "scalar-stream") }',
        '{"scalarList":["apple","banana","coconut"]}',
        [
            '{"data":{"scalarList":["apple"]},"pending":[{"id":"0","path":["scalarList"],"label":"scalar-stream"}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","items":["banana","coconut"]}],"completed":[{"id":"0"}]}',
        ],
    )


def test_treats_null_stream_label_the_same_as_no_label() raises:
    """Treats null stream label the same as no label."""
    _expect(
        "{ scalarList @stream(initialCount: 1, label: null) }",
        '{"scalarList":["apple","banana","coconut"]}',
        [
            '{"data":{"scalarList":["apple"]},"pending":[{"id":"0","path":["scalarList"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","items":["banana","coconut"]}],"completed":[{"id":"0"}]}',
        ],
    )


def test_can_disable_stream_using_if_argument() raises:
    """Can disable @stream using if argument."""
    _expect(
        "{ scalarList @stream(initialCount: 0, if: false) }",
        '{"scalarList":["apple","banana","coconut"]}',
        [
            '{"data":{"scalarList":["apple","banana","coconut"]}}',
        ],
    )


def test_does_not_disable_stream_with_null_if_argument() raises:
    """Does not disable stream with null if argument."""
    _expect(
        (
            "query ($shouldStream: Boolean) { scalarList @stream(initialCount:"
            " 2, if: $shouldStream) }"
        ),
        '{"scalarList":["apple","banana","coconut"]}',
        [
            '{"data":{"scalarList":["apple","banana"]},"pending":[{"id":"0","path":["scalarList"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","items":["coconut"]}],"completed":[{"id":"0"}]}',
        ],
    )


def test_can_stream_multi_dimensional_lists() raises:
    """Can stream multi-dimensional lists."""
    _expect(
        "{ scalarListList @stream(initialCount: 1) }",
        '{"scalarListList":[["apple","apple","apple"],["banana","banana","banana"],["coconut","coconut","coconut"]]}',
        [
            '{"data":{"scalarListList":[["apple","apple","apple"]]},"pending":[{"id":"0","path":["scalarListList"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","items":[["banana","banana","banana"],["coconut","coconut","coconut"]]}],"completed":[{"id":"0"}]}',
        ],
    )


def test_can_stream_a_field_that_returns_a_list_of_promises() raises:
    """Can stream a field that returns a list of promises."""
    _expect(
        (
            "\n      query {\n        friendList @stream(initialCount: 2) {\n  "
            "        name\n          id\n        }\n      }\n    "
        ),
        '{"friendList":[{"name":"Han","id":2},{"name":"Leia","id":3},{"name":"C-3PO","id":4}]}',
        [
            '{"data":{"friendList":[{"name":"Han","id":"2"},{"name":"Leia","id":"3"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","items":[{"name":"C-3PO","id":"4"}]}],"completed":[{"id":"0"}]}',
        ],
    )


def test_can_stream_in_correct_order_with_lists_of_promises() raises:
    """Can stream in correct order with lists of promises."""
    _expect(
        (
            "\n      query {\n        friendList @stream(initialCount: 0) {\n  "
            "        name\n          id\n        }\n      }\n    "
        ),
        '{"friendList":[{"name":"Han","id":2},{"name":"Leia","id":3},{"name":"C-3PO","id":4}]}',
        [
            '{"data":{"friendList":[]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","items":[{"name":"Han","id":"2"},{"name":"Leia","id":"3"},{"name":"C-3PO","id":"4"}]}],"completed":[{"id":"0"}]}',
        ],
    )


def test_does_not_execute_early_if_not_specified() raises:
    """Does not execute early if not specified."""
    _expect(
        (
            "\n      query {\n        friendList @stream(initialCount: 0) {\n  "
            "        id\n        }\n      }\n    "
        ),
        '{"friendList":[{"id":2},{"id":3},{"id":4}]}',
        [
            '{"data":{"friendList":[]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","items":[{"id":"2"},{"id":"3"},{"id":"4"}]}],"completed":[{"id":"0"}]}',
        ],
    )


def test_executes_early_if_specified() raises:
    """Executes early if specified."""
    _expect(
        (
            "\n      query {\n        friendList @stream(initialCount: 0) {\n  "
            "        id\n        }\n      }\n    "
        ),
        '{"friendList":[{"id":2},{"id":3},{"id":4}]}',
        [
            '{"data":{"friendList":[]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","items":[{"id":"2"},{"id":"3"},{"id":"4"}]}],"completed":[{"id":"0"}]}',
        ],
    )


def test_can_stream_a_field_that_returns_a_list_with_nested_promises() raises:
    """Can stream a field that returns a list with nested promises."""
    _expect(
        (
            "\n      query {\n        friendList @stream(initialCount: 2) {\n  "
            "        name\n          id\n        }\n      }\n    "
        ),
        '{"friendList":[{"name":"Han","id":2},{"name":"Leia","id":3},{"name":"C-3PO","id":4}]}',
        [
            '{"data":{"friendList":[{"name":"Han","id":"2"},{"name":"Leia","id":"3"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","items":[{"name":"C-3PO","id":"4"}]}],"completed":[{"id":"0"}]}',
        ],
    )


def test_handles_rejections_in_a_field_that_returns_a_list_of_promises_before_i() raises:
    """Handles rejections in a field that returns a list of promises before initialCount is reached.
    """
    _expect(
        (
            "\n      query {\n        friendList @stream(initialCount: 2) {\n  "
            "        name\n          id\n        }\n      }\n    "
        ),
        '{"friendList":[{"name":"Han","id":2},{"__throw":"bad"},{"name":"C-3PO","id":4}]}',
        [
            '{"data":{"friendList":[{"name":"Han","id":"2"},{"name":null,"id":null}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","items":[{"name":"C-3PO","id":"4"}]}],"completed":[{"id":"0"}]}',
        ],
    )


def test_handles_rejections_in_a_field_that_returns_a_list_of_promises_after_in() raises:
    """Handles rejections in a field that returns a list of promises after initialCount is reached.
    """
    _expect(
        (
            "\n      query {\n        friendList @stream(initialCount: 1) {\n  "
            "        name\n          id\n        }\n      }\n    "
        ),
        '{"friendList":[{"name":"Han","id":2},{"__throw":"bad"},{"name":"C-3PO","id":4}]}',
        [
            '{"data":{"friendList":[{"name":"Han","id":"2"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","items":[{"name":null,"id":null},{"name":"C-3PO","id":"4"}]}],"completed":[{"id":"0"}]}',
        ],
    )


def test_can_stream_a_field_that_returns_an_async_iterable() raises:
    """Can stream a field that returns an async iterable."""
    _expect(
        (
            "\n      query {\n        friendList @stream {\n          name\n   "
            "       id\n        }\n      }\n    "
        ),
        '{"friendList":{"__stream":"[{\\"name\\":\\"Han\\",\\"id\\":2},{\\"name\\":\\"Leia\\",\\"id\\":3},{\\"name\\":\\"C-3PO\\",\\"id\\":4}]"}}',
        [
            '{"data":{"friendList":[]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","items":[{"name":"Han","id":"2"},{"name":"Leia","id":"3"},{"name":"C-3PO","id":"4"}]}],"completed":[{"id":"0"}]}',
        ],
    )


def test_can_stream_multi_dimensional_lists_from_async_iterable() raises:
    """Can stream multi-dimensional lists from async iterable."""
    _expect(
        "{ scalarListList @stream(initialCount: 1) }",
        (
            '{"scalarListList":{"__stream":"[]","__error":"innerList is not'
            ' defined"}}'
        ),
        [
            (
                '{"errors":[{"message":"innerList is not'
                ' defined","locations":[{"line":1,"column":3}],"path":["scalarListList"]}],"data":{"scalarListList":null}}'
            ),
        ],
    )


def test_can_stream_a_field_that_returns_an_async_iterable_using_a_non_zero_ini() raises:
    """Can stream a field that returns an async iterable, using a non-zero initialCount.
    """
    _expect(
        (
            "\n      query {\n        friendList @stream(initialCount: 2) {\n  "
            "        name\n          id\n        }\n      }\n    "
        ),
        '{"friendList":{"__stream":"[{\\"name\\":\\"Han\\",\\"id\\":2},{\\"name\\":\\"Leia\\",\\"id\\":3},{\\"name\\":\\"C-3PO\\",\\"id\\":4}]"}}',
        [
            '{"data":{"friendList":[{"name":"Han","id":"2"},{"name":"Leia","id":"3"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","items":[{"name":"C-3PO","id":"4"}]}],"completed":[{"id":"0"}]}',
        ],
    )


def test_negative_values_of_initialcount_throw_field_errors_on_a_field_that_ret() raises:
    """Negative values of initialCount throw field errors on a field that returns an async iterable.
    """
    _expect(
        (
            "\n      query {\n        friendList @stream(initialCount: -2) {\n "
            "         name\n          id\n        }\n      }\n    "
        ),
        '{"friendList":{"__stream":"[]"}}',
        [
            (
                '{"errors":[{"message":"initialCount must be a positive'
                ' integer","locations":[{"line":3,"column":9}],"path":["friendList"]}],"data":{"friendList":null}}'
            ),
        ],
    )


def test_does_not_execute_early_if_not_specified_when_streaming_from_an_async_i() raises:
    """Does not execute early if not specified, when streaming from an async iterable.
    """
    _expect(
        (
            "\n      query {\n        friendList @stream(initialCount: 0) {\n  "
            "        id\n        }\n      }\n    "
        ),
        (
            '{"friendList":{"__stream":"[]","__error":"slowFriend is not'
            ' defined"}}'
        ),
        [
            '{"data":{"friendList":[]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
            (
                '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"slowFriend'
                " is not"
                ' defined","locations":[{"line":3,"column":9}],"path":["friendList"]}]}]}'
            ),
        ],
    )


def test_executes_early_if_specified_when_streaming_from_an_async_iterable() raises:
    """Executes early if specified when streaming from an async iterable."""
    _expect(
        (
            "\n      query {\n        friendList @stream(initialCount: 0) {\n  "
            "        id\n        }\n      }\n    "
        ),
        (
            '{"friendList":{"__stream":"[]","__error":"slowFriend is not'
            ' defined"}}'
        ),
        [
            '{"data":{"friendList":[]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
            (
                '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"slowFriend'
                " is not"
                ' defined","locations":[{"line":3,"column":9}],"path":["friendList"]}]}]}'
            ),
        ],
    )


def test_handles_error_thrown_in_async_iterable_before_initialcount_is_reached() raises:
    """Handles error thrown in async iterable before initialCount is reached."""
    _expect(
        (
            "\n      query {\n        friendList @stream(initialCount: 2) {\n  "
            "        name\n          id\n        }\n      }\n    "
        ),
        '{"friendList":{"__stream":"[{\\"name\\":\\"Han\\",\\"id\\":2}]","__error":"bad"}}',
        [
            '{"errors":[{"message":"bad","locations":[{"line":3,"column":9}],"path":["friendList"]}],"data":{"friendList":null}}',
        ],
    )


def test_handles_error_thrown_in_async_iterable_after_initialcount_is_reached() raises:
    """Handles error thrown in async iterable after initialCount is reached."""
    _expect(
        (
            "\n      query {\n        friendList @stream(initialCount: 1) {\n  "
            "        name\n          id\n        }\n      }\n    "
        ),
        '{"friendList":{"__stream":"[{\\"name\\":\\"Han\\",\\"id\\":2}]","__error":"bad"}}',
        [
            '{"data":{"friendList":[{"name":"Han","id":"2"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
            '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"bad","locations":[{"line":3,"column":9}],"path":["friendList"]}]}]}',
        ],
    )


def test_handles_null_returned_in_non_null_list_items_after_initialcount_is_rea() raises:
    """Handles null returned in non-null list items after initialCount is reached.
    """
    _expect(
        (
            "\n      query {\n        nonNullFriendList @stream(initialCount:"
            " 1) {\n          name\n        }\n      }\n    "
        ),
        '{"nonNullFriendList":[{"name":"Han","id":2},null,{"name":"Leia","id":3}]}',
        [
            '{"data":{"nonNullFriendList":[{"name":"Han"}]},"pending":[{"id":"0","path":["nonNullFriendList"]}],"hasNext":true}',
            (
                '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"Cannot'
                " return null for non-nullable field"
                ' Query.nonNullFriendList.","locations":[{"line":3,"column":9}],"path":["nonNullFriendList",1]}]}]}'
            ),
        ],
    )


def test_handles_null_returned_in_non_null_async_iterable_list_items_after_init() raises:
    """Handles null returned in non-null async iterable list items after initialCount is reached.
    """
    _expect(
        (
            "\n      query {\n        nonNullFriendList @stream(initialCount:"
            " 1) {\n          name\n        }\n      }\n    "
        ),
        '{"nonNullFriendList":{"__stream":"[{\\"name\\":\\"Han\\",\\"id\\":2},null]","__error":"Oops"}}',
        [
            '{"data":{"nonNullFriendList":[{"name":"Han"}]},"pending":[{"id":"0","path":["nonNullFriendList"]}],"hasNext":true}',
            (
                '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"Cannot'
                " return null for non-nullable field"
                ' Query.nonNullFriendList.","locations":[{"line":3,"column":9}],"path":["nonNullFriendList",1]}]}]}'
            ),
        ],
    )


def test_handles_errors_thrown_by_completevalue_after_initialcount_is_reached() raises:
    """Handles errors thrown by completeValue after initialCount is reached."""
    _expect(
        (
            "\n      query {\n        scalarList @stream(initialCount: 1)\n    "
            "  }\n    "
        ),
        '{"scalarList":["Han",{}]}',
        [
            '{"data":{"scalarList":["Han"]},"pending":[{"id":"0","path":["scalarList"]}],"hasNext":true}',
            (
                '{"hasNext":false,"incremental":[{"id":"0","items":[null],"errors":[{"message":"String'
                " cannot represent value:"
                ' {}","locations":[{"line":3,"column":9}],"path":["scalarList",1]}]}],"completed":[{"id":"0"}]}'
            ),
        ],
    )


def test_handles_async_errors_thrown_by_completevalue_after_initialcount_is_rea() raises:
    """Handles async errors thrown by completeValue after initialCount is reached.
    """
    _expect(
        (
            "\n      query {\n        friendList @stream(initialCount: 1) {\n  "
            "        nonNullName\n        }\n      }\n    "
        ),
        '{"friendList":[{"nonNullName":"Han"},{"nonNullName":{"__throw":"Oops"}},{"nonNullName":"Leia"}]}',
        [
            '{"data":{"friendList":[{"nonNullName":"Han"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","items":[null,{"nonNullName":"Leia"}],"errors":[{"message":"Oops","locations":[{"line":4,"column":11}],"path":["friendList",1,"nonNullName"]}]}],"completed":[{"id":"0"}]}',
        ],
    )


def test_handles_nested_async_errors_thrown_by_completevalue_after_initialcount() raises:
    """Handles nested async errors thrown by completeValue after initialCount is reached.
    """
    _expect(
        (
            "\n      query {\n        friendList @stream(initialCount: 1) {\n  "
            "        nonNullName\n        }\n      }\n    "
        ),
        '{"friendList":[{"nonNullName":"Han"},{"nonNullName":{"__throw":"Oops"}},{"nonNullName":"Leia"}]}',
        [
            '{"data":{"friendList":[{"nonNullName":"Han"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","items":[null,{"nonNullName":"Leia"}],"errors":[{"message":"Oops","locations":[{"line":4,"column":11}],"path":["friendList",1,"nonNullName"]}]}],"completed":[{"id":"0"}]}',
        ],
    )


def test_handles_async_errors_thrown_by_completevalue_after_initialcount_is_rea_2() raises:
    """Handles async errors thrown by completeValue after initialCount is reached for a non-nullable list.
    """
    _expect(
        (
            "\n      query {\n        nonNullFriendList @stream(initialCount:"
            " 1) {\n          nonNullName\n        }\n      }\n    "
        ),
        '{"nonNullFriendList":[{"nonNullName":"Han"},{"nonNullName":{"__throw":"Oops"}},{"nonNullName":"Leia"}]}',
        [
            '{"data":{"nonNullFriendList":[{"nonNullName":"Han"}]},"pending":[{"id":"0","path":["nonNullFriendList"]}],"hasNext":true}',
            '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"Oops","locations":[{"line":4,"column":11}],"path":["nonNullFriendList",1,"nonNullName"]}]}]}',
        ],
    )


def test_handles_nested_async_errors_thrown_by_completevalue_after_initialcount_2() raises:
    """Handles nested async errors thrown by completeValue after initialCount is reached for a non-nullable list.
    """
    _expect(
        (
            "\n      query {\n        nonNullFriendList @stream(initialCount:"
            " 1) {\n          nonNullName\n        }\n      }\n    "
        ),
        '{"nonNullFriendList":[{"nonNullName":"Han"},{"nonNullName":{"__throw":"Oops"}},{"nonNullName":"Leia"}]}',
        [
            '{"data":{"nonNullFriendList":[{"nonNullName":"Han"}]},"pending":[{"id":"0","path":["nonNullFriendList"]}],"hasNext":true}',
            '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"Oops","locations":[{"line":4,"column":11}],"path":["nonNullFriendList",1,"nonNullName"]}]}]}',
        ],
    )


def test_handles_async_errors_thrown_by_completevalue_after_initialcount_is_rea_2_2() raises:
    """Handles async errors thrown by completeValue after initialCount is reached from async iterable.
    """
    _expect(
        (
            "\n      query {\n        friendList @stream(initialCount: 1) {\n  "
            "        nonNullName\n        }\n      }\n    "
        ),
        '{"friendList":{"__stream":"[{\\"nonNullName\\":\\"Han\\"},{\\"nonNullName\\":{\\"__throw\\":\\"Oops\\"}},{\\"nonNullName\\":\\"Leia\\"}]"}}',
        [
            '{"data":{"friendList":[{"nonNullName":"Han"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","items":[null,{"nonNullName":"Leia"}],"errors":[{"message":"Oops","locations":[{"line":4,"column":11}],"path":["friendList",1,"nonNullName"]}]}],"completed":[{"id":"0"}]}',
        ],
    )


def test_handles_async_errors_thrown_by_completevalue_after_initialcount_is_rea_2_2_2() raises:
    """Handles async errors thrown by completeValue after initialCount is reached from async generator for a non-nullable list.
    """
    _expect(
        (
            "\n      query {\n        nonNullFriendList @stream(initialCount:"
            " 1) {\n          nonNullName\n        }\n      }\n    "
        ),
        '{"nonNullFriendList":{"__stream":"[{\\"nonNullName\\":\\"Han\\"},{\\"nonNullName\\":{\\"__throw\\":\\"Oops\\"}}]"}}',
        [
            '{"data":{"nonNullFriendList":[{"nonNullName":"Han"}]},"pending":[{"id":"0","path":["nonNullFriendList"]}],"hasNext":true}',
            '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"Oops","locations":[{"line":4,"column":11}],"path":["nonNullFriendList",1,"nonNullName"]}]}]}',
        ],
    )


def test_handles_async_errors_thrown_by_completevalue_after_initialcount_is_rea_2_2_2_2() raises:
    """Handles async errors thrown by completeValue after initialCount is reached from async iterable for a non-nullable list when the async iterable does not provide a return method) .
    """
    _expect(
        (
            "\n      query {\n        nonNullFriendList @stream(initialCount:"
            " 1) {\n          nonNullName\n        }\n      }\n    "
        ),
        (
            '{"nonNullFriendList":{"__stream":"[]","__error":"count is not'
            ' defined"}}'
        ),
        [
            (
                '{"errors":[{"message":"count is not'
                ' defined","locations":[{"line":3,"column":9}],"path":["nonNullFriendList"]}],"data":{"nonNullFriendList":null}}'
            ),
        ],
    )


def test_handles_async_errors_thrown_by_completevalue_after_initialcount_is_rea_2_2_2_2_2() raises:
    """Handles async errors thrown by completeValue after initialCount is reached from async iterable for a non-nullable list when the async iterable provides concurrent next/return methods and has a slow return .
    """
    _expect(
        (
            "\n      query {\n        nonNullFriendList @stream(initialCount:"
            " 1) {\n          nonNullName\n        }\n      }\n    "
        ),
        (
            '{"nonNullFriendList":{"__stream":"[]","__error":"returned is not'
            ' defined"}}'
        ),
        [
            (
                '{"errors":[{"message":"returned is not'
                ' defined","locations":[{"line":3,"column":9}],"path":["nonNullFriendList"]}],"data":{"nonNullFriendList":null}}'
            ),
        ],
    )


def test_filters_payloads_that_are_nulled() raises:
    """Filters payloads that are nulled."""
    _expect(
        (
            "\n      query {\n        nestedObject {\n         "
            " nonNullScalarField\n          nestedFriendList"
            " @stream(initialCount: 0) {\n            name\n          }\n      "
            "  }\n      }\n    "
        ),
        '{"nestedObject":{"nonNullScalarField":null,"nestedFriendList":{"__stream":"[{\\"name\\":\\"Han\\",\\"id\\":2}]"}}}',
        [
            (
                '{"errors":[{"message":"Cannot return null for non-nullable'
                " field"
                ' NestedObject.nonNullScalarField.","locations":[{"line":4,"column":11}],"path":["nestedObject","nonNullScalarField"]}],"data":{"nestedObject":null}}'
            ),
        ],
    )


def test_filters_payloads_that_are_nulled_by_a_later_synchronous_error() raises:
    """Filters payloads that are nulled by a later synchronous error."""
    _expect(
        (
            "\n      query {\n        nestedObject {\n         "
            " nestedFriendList @stream(initialCount: 0) {\n            name\n  "
            "        }\n          nonNullScalarField\n        }\n      }\n    "
        ),
        '{"nestedObject":{"nestedFriendList":{"__stream":"[{\\"name\\":\\"Han\\",\\"id\\":2}]"},"nonNullScalarField":null}}',
        [
            (
                '{"errors":[{"message":"Cannot return null for non-nullable'
                " field"
                ' NestedObject.nonNullScalarField.","locations":[{"line":7,"column":11}],"path":["nestedObject","nonNullScalarField"]}],"data":{"nestedObject":null}}'
            ),
        ],
    )


def test_does_not_filter_payloads_when_null_error_is_in_a_different_path() raises:
    """Does not filter payloads when null error is in a different path."""
    _expect(
        (
            "\n      query {\n        otherNestedObject: nestedObject {\n      "
            "    ... @defer {\n            scalarField\n          }\n       "
            " }\n        nestedObject {\n          nestedFriendList"
            " @stream(initialCount: 0) {\n            name\n          }\n      "
            "  }\n      }\n    "
        ),
        '{"nestedObject":{"scalarField":{"__throw":"Oops"},"nestedFriendList":{"__stream":"[{\\"name\\":\\"Han\\",\\"id\\":2}]"}}}',
        [
            '{"data":{"otherNestedObject":{},"nestedObject":{"nestedFriendList":[]}},"pending":[{"id":"0","path":["otherNestedObject"]},{"id":"1","path":["nestedObject","nestedFriendList"]}],"hasNext":true}',
            '{"hasNext":true,"incremental":[{"id":"0","data":{"scalarField":null},"errors":[{"message":"Oops","locations":[{"line":5,"column":13}],"path":["otherNestedObject","scalarField"]}]}],"completed":[{"id":"0"}]}',
            '{"hasNext":false,"incremental":[{"id":"1","items":[{"name":"Han"}]}],"completed":[{"id":"1"}]}',
        ],
    )


def test_filters_stream_payloads_that_are_nulled_in_a_deferred_payload() raises:
    """Filters stream payloads that are nulled in a deferred payload."""
    _expect(
        (
            "\n      query {\n        nestedObject {\n          ... @defer {\n "
            "           deeperNestedObject {\n             "
            " nonNullScalarField\n              deeperNestedFriendList"
            " @stream(initialCount: 0) {\n                name\n             "
            " }\n            }\n          }\n        }\n      }\n    "
        ),
        '{"nestedObject":{"deeperNestedObject":{"nonNullScalarField":null,"deeperNestedFriendList":{"__stream":"[{\\"name\\":\\"Han\\",\\"id\\":2}]"}}}}',
        [
            '{"data":{"nestedObject":{}},"pending":[{"id":"0","path":["nestedObject"]}],"hasNext":true}',
            (
                '{"hasNext":false,"incremental":[{"id":"0","data":{"deeperNestedObject":null},"errors":[{"message":"Cannot'
                " return null for non-nullable field"
                ' DeeperNestedObject.nonNullScalarField.","locations":[{"line":6,"column":15}],"path":["nestedObject","deeperNestedObject","nonNullScalarField"]}]}],"completed":[{"id":"0"}]}'
            ),
        ],
    )


def test_filters_defer_payloads_that_are_nulled_in_a_stream_response() raises:
    """Filters defer payloads that are nulled in a stream response."""
    _expect(
        (
            "\n    query {\n      friendList @stream(initialCount: 0) {\n      "
            "  nonNullName\n        ... @defer {\n          name\n        }\n  "
            "    }\n    }\n  "
        ),
        '{"friendList":{"__stream":"[{\\"name\\":\\"Han\\",\\"nonNullName\\":null}]"}}',
        [
            '{"data":{"friendList":[]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
            (
                '{"hasNext":false,"incremental":[{"id":"0","items":[null],"errors":[{"message":"Cannot'
                " return null for non-nullable field"
                ' Friend.nonNullName.","locations":[{"line":4,"column":9}],"path":["friendList",0,"nonNullName"]}]}],"completed":[{"id":"0"}]}'
            ),
        ],
    )


def test_handles_promises_returned_by_completevalue_after_initialcount_is_reach() raises:
    """Handles promises returned by completeValue after initialCount is reached.
    """
    _expect(
        (
            "\n      query {\n        friendList @stream(initialCount: 1) {\n  "
            "        id\n          name\n        }\n      }\n    "
        ),
        '{"friendList":{"__stream":"[{\\"name\\":\\"Han\\",\\"id\\":2},{\\"name\\":\\"Leia\\",\\"id\\":3},{\\"id\\":4,\\"name\\":\\"C-3PO\\"}]"}}',
        [
            '{"data":{"friendList":[{"id":"2","name":"Han"}]},"pending":[{"id":"0","path":["friendList"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","items":[{"id":"3","name":"Leia"},{"id":"4","name":"C-3PO"}]}],"completed":[{"id":"0"}]}',
        ],
    )


def test_handles_overlapping_deferred_and_non_deferred_streams() raises:
    """Handles overlapping deferred and non-deferred streams."""
    _expect(
        (
            "\n      query {\n        nestedObject {\n         "
            " nestedFriendList @stream(initialCount: 0) {\n            id\n    "
            "      }\n        }\n        nestedObject {\n          ... @defer"
            " {\n            nestedFriendList @stream(initialCount: 0) {\n     "
            "         id\n              name\n              ... @defer {\n     "
            "           innerName: name\n              }\n            }\n      "
            "    }\n        }\n      }\n    "
        ),
        '{"nestedObject":{"nestedFriendList":{"__stream":"[{\\"name\\":\\"Han\\",\\"id\\":2},{\\"name\\":\\"Leia\\",\\"id\\":3}]"}}}',
        [
            '{"data":{"nestedObject":{"nestedFriendList":[]}},"pending":[{"id":"0","path":["nestedObject","nestedFriendList"]}],"hasNext":true}',
            '{"hasNext":false,"pending":[{"id":"1","path":["nestedObject","nestedFriendList",0]},{"id":"2","path":["nestedObject","nestedFriendList",1]}],"incremental":[{"id":"0","items":[{"id":"2","name":"Han"},{"id":"3","name":"Leia"}]},{"id":"1","data":{"innerName":"Han"}},{"id":"2","data":{"innerName":"Leia"}}],"completed":[{"id":"0"},{"id":"1"},{"id":"2"}]}',
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

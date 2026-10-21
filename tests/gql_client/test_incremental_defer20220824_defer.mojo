# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `Defer20220824Handler` with `@defer`: Apollo Client 4.3.3
(ae0dfce) `src/incremental/handlers/__tests__/defer20220824/defer.test.ts`.

Each case has the payloads and the results of the upstream case. They
were recorded from the upstream test itself, run in Node.js with Apollo
Client 4.3.3 and graphql 17.0.0-alpha.2, the versions of the upstream
test. Each step is one call of `isIncrementalResult` or `handle`, in the
order of the upstream test, and the result must have the same JSON.

These upstream cases are not here: "Defer20220824Handler can be used with
`ApolloClient`", "merges cache updates that happen concurrently",
"returns error on initial result", "stream that returns an error but
continues to stream", "handles final chunk of { hasNext: false }
correctly in usage with Apollo Client" and "ignores `data` property added
to subsequent chunks by misbehaving servers". They run `ApolloClient`
with a link. `test_query_info.mojo` ports their cache writes.
"""

from std.testing import TestSuite

from _incremental_helpers import (
    UNDEFINED,
    handle_step,
    is_step,
    run_defer20220824,
)


def test_can_defer_fragments_containing_scalar_types() raises:
    """Can defer fragments containing scalar types."""
    run_defer20220824(
        [
            is_step(
                '{"data":{"hero":{"id":"1"}},"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"hero":{"id":"1"}},"hasNext":true}',
                result='{"data":{"hero":{"id":"1"}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"data":{"id":"1","name":"Luke"},"path":["hero"]}],"hasNext":false}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"data":{"id":"1","name":"Luke"},"path":["hero"]}],"hasNext":false}',
                result='{"data":{"hero":{"id":"1","name":"Luke"}}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_can_disable_defer_using_if_argument() raises:
    """Can disable defer using if argument."""
    run_defer20220824(
        [
            is_step(
                '{"data":{"hero":{"id":"1","name":"Luke"}}}',
                False,
            ),
        ]
    )


def test_can_defer_fragments_on_the_top_level_query_field() raises:
    """Can defer fragments on the top level Query field."""
    run_defer20220824(
        [
            is_step(
                '{"data":{},"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{},"hasNext":true}',
                result='{"data":{}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"data":{"hero":{"id":"1"}},"path":[],"label":"DeferQuery"}],"hasNext":false}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"data":{"hero":{"id":"1"}},"path":[],"label":"DeferQuery"}],"hasNext":false}',
                result='{"data":{"hero":{"id":"1"}}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_can_defer_fragments_with_errors_on_the_top_level_query_field() raises:
    """Can defer fragments with errors on the top level Query field."""
    run_defer20220824(
        [
            is_step(
                '{"data":{},"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{},"hasNext":true}',
                result='{"data":{}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"data":{"hero":{"errorField":null}},"path":[],"label":"DeferQuery","errors":[{"message":"bad","path":["hero","errorField"]}]}],"hasNext":false}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"data":{"hero":{"errorField":null}},"path":[],"label":"DeferQuery","errors":[{"message":"bad","path":["hero","errorField"]}]}],"hasNext":false}',
                result='{"data":{"hero":{"errorField":null}},"errors":[{"message":"bad","path":["hero","errorField"]}]}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_can_defer_a_fragment_within_an_already_deferred_fragment() raises:
    """Can defer a fragment within an already deferred fragment."""
    run_defer20220824(
        [
            is_step(
                '{"data":{"hero":{"id":"1"}},"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"hero":{"id":"1"}},"hasNext":true}',
                result='{"data":{"hero":{"id":"1"}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"data":{"friends":[{"name":"Han"},{"name":"Leia"},{"name":"C-3PO"}]},"path":["hero"],"label":"DeferNested"},{"data":{"name":"Luke"},"path":["hero"],"label":"DeferTop"}],"hasNext":false}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"data":{"friends":[{"name":"Han"},{"name":"Leia"},{"name":"C-3PO"}]},"path":["hero"],"label":"DeferNested"},{"data":{"name":"Luke"},"path":["hero"],"label":"DeferTop"}],"hasNext":false}',
                result='{"data":{"hero":{"id":"1","friends":[{"name":"Han"},{"name":"Leia"},{"name":"C-3PO"}],"name":"Luke"}}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_can_defer_a_fragment_that_is_also_not_deferred_deferred_fragment_is_first() raises:
    """Can defer a fragment that is also not deferred, deferred fragment is first.
    """
    run_defer20220824(
        [
            is_step(
                '{"data":{"hero":{"id":"1","name":"Luke"}},"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"hero":{"id":"1","name":"Luke"}},"hasNext":true}',
                result='{"data":{"hero":{"id":"1","name":"Luke"}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"data":{"name":"Luke"},"path":["hero"],"label":"DeferTop"}],"hasNext":false}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"data":{"name":"Luke"},"path":["hero"],"label":"DeferTop"}],"hasNext":false}',
                result='{"data":{"hero":{"id":"1","name":"Luke"}}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_handles_errors_thrown_in_deferred_fragments() raises:
    """Handles errors thrown in deferred fragments."""
    run_defer20220824(
        [
            is_step(
                '{"data":{"hero":{"id":"1"}},"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"hero":{"id":"1"}},"hasNext":true}',
                result='{"data":{"hero":{"id":"1"}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"data":{"errorField":null},"path":["hero"],"errors":[{"message":"bad","path":["hero","errorField"]}]}],"hasNext":false}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"data":{"errorField":null},"path":["hero"],"errors":[{"message":"bad","path":["hero","errorField"]}]}],"hasNext":false}',
                result='{"data":{"hero":{"id":"1","errorField":null}},"errors":[{"message":"bad","path":["hero","errorField"]}]}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_handles_non_nullable_errors_thrown_in_deferred_fragments() raises:
    """Handles non-nullable errors thrown in deferred fragments."""
    run_defer20220824(
        [
            is_step(
                '{"data":{"hero":{"id":"1"}},"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"hero":{"id":"1"}},"hasNext":true}',
                result='{"data":{"hero":{"id":"1"}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                (
                    '{"incremental":[{"data":null,"path":["hero"],"errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' Hero.nonNullErrorField.","path":["hero","nonNullErrorField"]}]}],"hasNext":false}'
                ),
                True,
            ),
            handle_step(
                UNDEFINED,
                (
                    '{"incremental":[{"data":null,"path":["hero"],"errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' Hero.nonNullErrorField.","path":["hero","nonNullErrorField"]}]}],"hasNext":false}'
                ),
                result=(
                    '{"data":{"hero":{"id":"1"}},"errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' Hero.nonNullErrorField.","path":["hero","nonNullErrorField"]}]}'
                ),
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_handles_non_nullable_errors_thrown_outside_deferred_fragments() raises:
    """Handles non-nullable errors thrown outside deferred fragments."""
    run_defer20220824(
        [
            is_step(
                (
                    '{"errors":[{"message":"Cannot return null for non-nullable'
                    " field"
                    ' Hero.nonNullErrorField.","path":["hero","nonNullErrorField"]}],"data":{"hero":null}}'
                ),
                False,
            ),
        ]
    )


def test_returns_payloads_in_correct_order() raises:
    """Returns payloads in correct order."""
    run_defer20220824(
        [
            is_step(
                '{"data":{"hero":{"id":"1"}},"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"hero":{"id":"1"}},"hasNext":true}',
                result='{"data":{"hero":{"id":"1"}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"data":{"slowField":"slow","friends":[{},{},{}]},"path":["hero"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"data":{"slowField":"slow","friends":[{},{},{}]},"path":["hero"]}],"hasNext":true}',
                result='{"data":{"hero":{"id":"1","slowField":"slow","friends":[{},{},{}]}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"incremental":[{"data":{"name":"Han"},"path":["hero","friends",0]},{"data":{"name":"Leia"},"path":["hero","friends",1]},{"data":{"name":"C-3PO"},"path":["hero","friends",2]}],"hasNext":false}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"incremental":[{"data":{"name":"Han"},"path":["hero","friends",0]},{"data":{"name":"Leia"},"path":["hero","friends",1]},{"data":{"name":"C-3PO"},"path":["hero","friends",2]}],"hasNext":false}',
                result='{"data":{"hero":{"id":"1","slowField":"slow","friends":[{"name":"Han"},{"name":"Leia"},{"name":"C-3PO"}]}}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

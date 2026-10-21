# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `GraphQL17Alpha9Handler` with `@defer`: Apollo Client 4.3.3
(ae0dfce) `src/incremental/handlers/__tests__/graphql17Alpha9/defer.test.ts`.

Each case has the payloads and the results of the upstream case. They
were recorded from the upstream test itself, run in Node.js with Apollo
Client 4.3.3 and graphql 17.0.0-alpha.9, the versions of the upstream
test. Each step is one call of `isIncrementalResult` or `handle`, in the
order of the upstream test, and the result must have the same JSON.

These upstream cases are not here:

- The cases that upstream skips with `it.skip`: upstream says that they
  are not interesting from a client perspective.
- "GraphQL17Alpha9Handler can be used with `ApolloClient`", "merges cache
  updates that happen concurrently", "returns error on initial result",
  "stream that returns an error but continues to stream", "handles final
  chunk of { hasNext: false } correctly in usage with Apollo Client" and
  "ignores `data` property added to subsequent chunks by misbehaving
  servers": they run `ApolloClient` with a link. `test_query_info.mojo`
  ports the cache writes of these cases.
"""

from std.testing import TestSuite

from _incremental_helpers import UNDEFINED, handle_step, is_step, run_graphql17


def test_can_defer_fragments_containing_scalar_types() raises:
    """Can defer fragments containing scalar types."""
    run_graphql17(
        [
            is_step(
                '{"data":{"hero":{"id":"1"}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"hero":{"id":"1"}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
                result='{"data":{"hero":{"id":"1"}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"data":{"name":"Luke"},"id":"0"}],"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"incremental":[{"data":{"name":"Luke"},"id":"0"}],"completed":[{"id":"0"}]}',
                result='{"data":{"hero":{"id":"1","name":"Luke"}}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_can_disable_defer_using_if_argument() raises:
    """Can disable defer using if argument."""
    run_graphql17(
        [
            is_step(
                '{"data":{"hero":{"id":"1","name":"Luke"}}}',
                False,
            ),
        ]
    )


def test_can_defer_fragments_on_the_top_level_query_field() raises:
    """Can defer fragments on the top level Query field."""
    run_graphql17(
        [
            is_step(
                '{"data":{},"pending":[{"id":"0","path":[],"label":"DeferQuery"}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{},"pending":[{"id":"0","path":[],"label":"DeferQuery"}],"hasNext":true}',
                result='{"data":{}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"data":{"hero":{"id":"1"}},"id":"0"}],"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"incremental":[{"data":{"hero":{"id":"1"}},"id":"0"}],"completed":[{"id":"0"}]}',
                result='{"data":{"hero":{"id":"1"}}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_can_defer_fragments_with_errors_on_the_top_level_query_field() raises:
    """Can defer fragments with errors on the top level Query field."""
    run_graphql17(
        [
            is_step(
                '{"data":{},"pending":[{"id":"0","path":[],"label":"DeferQuery"}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{},"pending":[{"id":"0","path":[],"label":"DeferQuery"}],"hasNext":true}',
                result='{"data":{}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"data":{"hero":{"name":null}},"errors":[{"message":"bad","path":["hero","name"]}],"id":"0"}],"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"incremental":[{"data":{"hero":{"name":null}},"errors":[{"message":"bad","path":["hero","name"]}],"id":"0"}],"completed":[{"id":"0"}]}',
                result='{"data":{"hero":{"name":null}},"errors":[{"message":"bad","path":["hero","name"]}]}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_can_defer_a_fragment_within_an_already_deferred_fragment() raises:
    """Can defer a fragment within an already deferred fragment."""
    run_graphql17(
        [
            is_step(
                '{"data":{"hero":{}},"pending":[{"id":"0","path":["hero"],"label":"DeferTop"}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"hero":{}},"pending":[{"id":"0","path":["hero"],"label":"DeferTop"}],"hasNext":true}',
                result='{"data":{"hero":{}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":false,"pending":[{"id":"1","path":["hero"],"label":"DeferNested"}],"incremental":[{"data":{"id":"1"},"id":"0"},{"data":{"friends":[{"name":"Han"},{"name":"Leia"},{"name":"C-3PO"}]},"id":"1"}],"completed":[{"id":"0"},{"id":"1"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"pending":[{"id":"1","path":["hero"],"label":"DeferNested"}],"incremental":[{"data":{"id":"1"},"id":"0"},{"data":{"friends":[{"name":"Han"},{"name":"Leia"},{"name":"C-3PO"}]},"id":"1"}],"completed":[{"id":"0"},{"id":"1"}]}',
                result='{"data":{"hero":{"id":"1","friends":[{"name":"Han"},{"name":"Leia"},{"name":"C-3PO"}]}}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_can_defer_an_inline_fragment() raises:
    """Can defer an inline fragment."""
    run_graphql17(
        [
            is_step(
                '{"data":{"hero":{"id":"1"}},"pending":[{"id":"0","path":["hero"],"label":"InlineDeferred"}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"hero":{"id":"1"}},"pending":[{"id":"0","path":["hero"],"label":"InlineDeferred"}],"hasNext":true}',
                result='{"data":{"hero":{"id":"1"}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"data":{"name":"Luke"},"id":"0"}],"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"incremental":[{"data":{"name":"Luke"},"id":"0"}],"completed":[{"id":"0"}]}',
                result='{"data":{"hero":{"id":"1","name":"Luke"}}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_emits_children_of_empty_defer_fragments() raises:
    """Emits children of empty defer fragments."""
    run_graphql17(
        [
            is_step(
                '{"data":{"hero":{}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"hero":{}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
                result='{"data":{"hero":{}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"data":{"name":"Luke"},"id":"0"}],"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"incremental":[{"data":{"name":"Luke"},"id":"0"}],"completed":[{"id":"0"}]}',
                result='{"data":{"hero":{"name":"Luke"}}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_can_separately_emit_defer_fragments_with_different_labels_with_varying_fields() raises:
    """Can separately emit defer fragments with different labels with varying fields.
    """
    run_graphql17(
        [
            is_step(
                '{"data":{"hero":{}},"pending":[{"id":"0","path":["hero"],"label":"DeferID"},{"id":"1","path":["hero"],"label":"DeferName"}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"hero":{}},"pending":[{"id":"0","path":["hero"],"label":"DeferID"},{"id":"1","path":["hero"],"label":"DeferName"}],"hasNext":true}',
                result='{"data":{"hero":{}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"data":{"id":"1"},"id":"0"},{"data":{"name":"Luke"},"id":"1"}],"completed":[{"id":"0"},{"id":"1"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"incremental":[{"data":{"id":"1"},"id":"0"},{"data":{"name":"Luke"},"id":"1"}],"completed":[{"id":"0"},{"id":"1"}]}',
                result='{"data":{"hero":{"id":"1","name":"Luke"}}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_separately_emits_defer_fragments_with_different_labels_with_varying_subfields() raises:
    """Separately emits defer fragments with different labels with varying subfields.
    """
    run_graphql17(
        [
            is_step(
                '{"data":{},"pending":[{"id":"0","path":[],"label":"DeferID"},{"id":"1","path":[],"label":"DeferName"}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{},"pending":[{"id":"0","path":[],"label":"DeferID"},{"id":"1","path":[],"label":"DeferName"}],"hasNext":true}',
                result='{"data":{}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"data":{"hero":{}},"id":"0"},{"data":{"id":"1"},"id":"0","subPath":["hero"]},{"data":{"name":"Luke"},"id":"1","subPath":["hero"]}],"completed":[{"id":"0"},{"id":"1"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"incremental":[{"data":{"hero":{}},"id":"0"},{"data":{"id":"1"},"id":"0","subPath":["hero"]},{"data":{"name":"Luke"},"id":"1","subPath":["hero"]}],"completed":[{"id":"0"},{"id":"1"}]}',
                result='{"data":{"hero":{"id":"1","name":"Luke"}}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_separately_emits_defer_fragments_with_varying_subfields_of_same_priorities_but_different_level_of_defers() raises:
    """Separately emits defer fragments with varying subfields of same priorities but different level of defers.
    """
    run_graphql17(
        [
            is_step(
                '{"data":{"hero":{}},"pending":[{"id":"0","path":["hero"],"label":"DeferID"},{"id":"1","path":[],"label":"DeferName"}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"hero":{}},"pending":[{"id":"0","path":["hero"],"label":"DeferID"},{"id":"1","path":[],"label":"DeferName"}],"hasNext":true}',
                result='{"data":{"hero":{}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"data":{"id":"1"},"id":"0"},{"data":{"name":"Luke"},"id":"1","subPath":["hero"]}],"completed":[{"id":"0"},{"id":"1"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"incremental":[{"data":{"id":"1"},"id":"0"},{"data":{"name":"Luke"},"id":"1","subPath":["hero"]}],"completed":[{"id":"0"},{"id":"1"}]}',
                result='{"data":{"hero":{"id":"1","name":"Luke"}}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_separately_emits_nested_defer_fragments_with_varying_subfields_of_same_priorities_but_different_level_of_defers() raises:
    """Separately emits nested defer fragments with varying subfields of same priorities but different level of defers.
    """
    run_graphql17(
        [
            is_step(
                '{"data":{},"pending":[{"id":"0","path":[],"label":"DeferName"}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{},"pending":[{"id":"0","path":[],"label":"DeferName"}],"hasNext":true}',
                result='{"data":{}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":false,"pending":[{"id":"1","path":["hero"],"label":"DeferID"}],"incremental":[{"data":{"hero":{"name":"Luke"}},"id":"0"},{"data":{"id":"1"},"id":"1"}],"completed":[{"id":"0"},{"id":"1"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"pending":[{"id":"1","path":["hero"],"label":"DeferID"}],"incremental":[{"data":{"hero":{"name":"Luke"}},"id":"0"},{"data":{"id":"1"},"id":"1"}],"completed":[{"id":"0"},{"id":"1"}]}',
                result='{"data":{"hero":{"name":"Luke","id":"1"}}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_initiates_deferred_grouped_field_sets_only_if_they_have_been_released_as_pending() raises:
    """Initiates deferred grouped field sets only if they have been released as pending.
    """
    run_graphql17(
        [
            is_step(
                '{"data":{},"pending":[{"id":"0","path":[]},{"id":"1","path":[]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{},"pending":[{"id":"0","path":[]},{"id":"1","path":[]}],"hasNext":true}',
                result='{"data":{}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":true,"pending":[{"id":"2","path":["a"]}],"incremental":[{"data":{"a":{}},"id":"0"},{"data":{"b":{}},"id":"2"},{"data":{"c":{"d":"d"}},"id":"2","subPath":["b"]}],"completed":[{"id":"0"},{"id":"2"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"pending":[{"id":"2","path":["a"]}],"incremental":[{"data":{"a":{}},"id":"0"},{"data":{"b":{}},"id":"2"},{"data":{"c":{"d":"d"}},"id":"2","subPath":["b"]}],"completed":[{"id":"0"},{"id":"2"}]}',
                result='{"data":{"a":{"b":{"c":{"d":"d"}}}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":false,"pending":[{"id":"3","path":["a"]}],"incremental":[{"data":{"someField":"someField"},"id":"1","subPath":["a"]},{"data":{"e":{"f":"f"}},"id":"3","subPath":["b"]}],"completed":[{"id":"1"},{"id":"3"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"pending":[{"id":"3","path":["a"]}],"incremental":[{"data":{"someField":"someField"},"id":"1","subPath":["a"]},{"data":{"e":{"f":"f"}},"id":"3","subPath":["b"]}],"completed":[{"id":"1"},{"id":"3"}]}',
                result='{"data":{"a":{"b":{"c":{"d":"d"},"e":{"f":"f"}},"someField":"someField"}}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_initiates_unique_deferred_grouped_field_sets_after_those_that_are_common_to_sibling_defers() raises:
    """Initiates unique deferred grouped field sets after those that are common to sibling defers.
    """
    run_graphql17(
        [
            is_step(
                '{"data":{},"pending":[{"id":"0","path":[]},{"id":"1","path":[]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{},"pending":[{"id":"0","path":[]},{"id":"1","path":[]}],"hasNext":true}',
                result='{"data":{}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":true,"pending":[{"id":"2","path":["a"]},{"id":"3","path":["a"]}],"incremental":[{"data":{"a":{}},"id":"0"}],"completed":[{"id":"0"},{"id":"1"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"pending":[{"id":"2","path":["a"]},{"id":"3","path":["a"]}],"incremental":[{"data":{"a":{}},"id":"0"}],"completed":[{"id":"0"},{"id":"1"}]}',
                result='{"data":{"a":{}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"data":{"b":{"c":{"d":"d"}}},"id":"2"},{"data":{"e":{"f":"f"}},"id":"3","subPath":["b"]}],"completed":[{"id":"2"},{"id":"3"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"incremental":[{"data":{"b":{"c":{"d":"d"}}},"id":"2"},{"data":{"e":{"f":"f"}},"id":"3","subPath":["b"]}],"completed":[{"id":"2"},{"id":"3"}]}',
                result='{"data":{"a":{"b":{"c":{"d":"d"},"e":{"f":"f"}}}}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_can_deduplicate_multiple_defers_on_the_same_object() raises:
    """Can deduplicate multiple defers on the same object."""
    run_graphql17(
        [
            is_step(
                '{"data":{"hero":{"friends":[{},{},{}]}},"pending":[{"id":"0","path":["hero","friends",0]},{"id":"1","path":["hero","friends",1]},{"id":"2","path":["hero","friends",2]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"hero":{"friends":[{},{},{}]}},"pending":[{"id":"0","path":["hero","friends",0]},{"id":"1","path":["hero","friends",1]},{"id":"2","path":["hero","friends",2]}],"hasNext":true}',
                result='{"data":{"hero":{"friends":[{},{},{}]}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"data":{"id":"2","name":"Han"},"id":"0"},{"data":{"id":"3","name":"Leia"},"id":"1"},{"data":{"id":"4","name":"C-3PO"},"id":"2"}],"completed":[{"id":"0"},{"id":"1"},{"id":"2"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"incremental":[{"data":{"id":"2","name":"Han"},"id":"0"},{"data":{"id":"3","name":"Leia"},"id":"1"},{"data":{"id":"4","name":"C-3PO"},"id":"2"}],"completed":[{"id":"0"},{"id":"1"},{"id":"2"}]}',
                result='{"data":{"hero":{"friends":[{"id":"2","name":"Han"},{"id":"3","name":"Leia"},{"id":"4","name":"C-3PO"}]}}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_deduplicates_fields_present_in_the_initial_payload() raises:
    """Deduplicates fields present in the initial payload."""
    run_graphql17(
        [
            is_step(
                '{"data":{"hero":{"nestedObject":{"deeperObject":{"foo":"foo"}},"anotherNestedObject":{"deeperObject":{"foo":"foo"}}}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"hero":{"nestedObject":{"deeperObject":{"foo":"foo"}},"anotherNestedObject":{"deeperObject":{"foo":"foo"}}}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
                result='{"data":{"hero":{"nestedObject":{"deeperObject":{"foo":"foo"}},"anotherNestedObject":{"deeperObject":{"foo":"foo"}}}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"data":{"bar":"bar"},"id":"0","subPath":["nestedObject","deeperObject"]}],"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"incremental":[{"data":{"bar":"bar"},"id":"0","subPath":["nestedObject","deeperObject"]}],"completed":[{"id":"0"}]}',
                result='{"data":{"hero":{"nestedObject":{"deeperObject":{"foo":"foo","bar":"bar"}},"anotherNestedObject":{"deeperObject":{"foo":"foo"}}}}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_deduplicates_fields_present_in_a_parent_defer_payload() raises:
    """Deduplicates fields present in a parent defer payload."""
    run_graphql17(
        [
            is_step(
                '{"data":{"hero":{}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"hero":{}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
                result='{"data":{"hero":{}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":false,"pending":[{"id":"1","path":["hero","nestedObject","deeperObject"]}],"incremental":[{"data":{"nestedObject":{"deeperObject":{"foo":"foo"}}},"id":"0"},{"data":{"bar":"bar"},"id":"1"}],"completed":[{"id":"0"},{"id":"1"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"pending":[{"id":"1","path":["hero","nestedObject","deeperObject"]}],"incremental":[{"data":{"nestedObject":{"deeperObject":{"foo":"foo"}}},"id":"0"},{"data":{"bar":"bar"},"id":"1"}],"completed":[{"id":"0"},{"id":"1"}]}',
                result='{"data":{"hero":{"nestedObject":{"deeperObject":{"foo":"foo","bar":"bar"}}}}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_deduplicates_fields_with_deferred_fragments_at_multiple_levels() raises:
    """Deduplicates fields with deferred fragments at multiple levels."""
    run_graphql17(
        [
            is_step(
                '{"data":{"hero":{"nestedObject":{"deeperObject":{"foo":"foo"}}}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"hero":{"nestedObject":{"deeperObject":{"foo":"foo"}}}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
                result='{"data":{"hero":{"nestedObject":{"deeperObject":{"foo":"foo"}}}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":false,"pending":[{"id":"1","path":["hero","nestedObject"]},{"id":"2","path":["hero","nestedObject","deeperObject"]}],"incremental":[{"data":{"bar":"bar"},"id":"0","subPath":["nestedObject","deeperObject"]},{"data":{"baz":"baz"},"id":"1","subPath":["deeperObject"]},{"data":{"bak":"bak"},"id":"2"}],"completed":[{"id":"0"},{"id":"1"},{"id":"2"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"pending":[{"id":"1","path":["hero","nestedObject"]},{"id":"2","path":["hero","nestedObject","deeperObject"]}],"incremental":[{"data":{"bar":"bar"},"id":"0","subPath":["nestedObject","deeperObject"]},{"data":{"baz":"baz"},"id":"1","subPath":["deeperObject"]},{"data":{"bak":"bak"},"id":"2"}],"completed":[{"id":"0"},{"id":"1"},{"id":"2"}]}',
                result='{"data":{"hero":{"nestedObject":{"deeperObject":{"foo":"foo","bar":"bar","baz":"baz","bak":"bak"}}}}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_deduplicates_multiple_fields_from_deferred_fragments_from_different_branches_occurring_at_the_same_level() raises:
    """Deduplicates multiple fields from deferred fragments from different branches occurring at the same level.
    """
    run_graphql17(
        [
            is_step(
                '{"data":{"hero":{"nestedObject":{"deeperObject":{}}}},"pending":[{"id":"0","path":["hero","nestedObject","deeperObject"]},{"id":"1","path":["hero","nestedObject","deeperObject"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"hero":{"nestedObject":{"deeperObject":{}}}},"pending":[{"id":"0","path":["hero","nestedObject","deeperObject"]},{"id":"1","path":["hero","nestedObject","deeperObject"]}],"hasNext":true}',
                result='{"data":{"hero":{"nestedObject":{"deeperObject":{}}}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"data":{"foo":"foo"},"id":"0"},{"data":{"bar":"bar"},"id":"1"}],"completed":[{"id":"0"},{"id":"1"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"incremental":[{"data":{"foo":"foo"},"id":"0"},{"data":{"bar":"bar"},"id":"1"}],"completed":[{"id":"0"},{"id":"1"}]}',
                result='{"data":{"hero":{"nestedObject":{"deeperObject":{"foo":"foo","bar":"bar"}}}}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_deduplicate_fields_with_deferred_fragments_in_different_branches_at_multiple_non_overlapping_levels() raises:
    """Deduplicate fields with deferred fragments in different branches at multiple non-overlapping levels.
    """
    run_graphql17(
        [
            is_step(
                '{"data":{"a":{"b":{"c":{"d":"d"}}}},"pending":[{"id":"0","path":["a","b"]},{"id":"1","path":[]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"a":{"b":{"c":{"d":"d"}}}},"pending":[{"id":"0","path":["a","b"]},{"id":"1","path":[]}],"hasNext":true}',
                result='{"data":{"a":{"b":{"c":{"d":"d"}}}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"data":{"e":{"f":"f"}},"id":"0"},{"data":{"g":{"h":"h"}},"id":"1"}],"completed":[{"id":"0"},{"id":"1"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"incremental":[{"data":{"e":{"f":"f"}},"id":"0"},{"data":{"g":{"h":"h"}},"id":"1"}],"completed":[{"id":"0"},{"id":"1"}]}',
                result='{"data":{"a":{"b":{"c":{"d":"d"},"e":{"f":"f"}}},"g":{"h":"h"}}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_correctly_bundles_varying_subfields_into_incremental_data_records_unique_by_defer_combination_ignoring_fields_in_a_fragment_masked_by_a_parent_defer() raises:
    """Correctly bundles varying subfields into incremental data records unique by defer combination, ignoring fields in a fragment masked by a parent defer.
    """
    run_graphql17(
        [
            is_step(
                '{"data":{},"pending":[{"id":"0","path":[]},{"id":"1","path":[]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{},"pending":[{"id":"0","path":[]},{"id":"1","path":[]}],"hasNext":true}',
                result='{"data":{}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"data":{"hero":{}},"id":"0"},{"data":{"id":"1"},"id":"0","subPath":["hero"]},{"data":{"name":"Luke","shouldBeWithNameDespiteAdditionalDefer":"Luke"},"id":"1","subPath":["hero"]}],"completed":[{"id":"0"},{"id":"1"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"incremental":[{"data":{"hero":{}},"id":"0"},{"data":{"id":"1"},"id":"0","subPath":["hero"]},{"data":{"name":"Luke","shouldBeWithNameDespiteAdditionalDefer":"Luke"},"id":"1","subPath":["hero"]}],"completed":[{"id":"0"},{"id":"1"}]}',
                result='{"data":{"hero":{"id":"1","name":"Luke","shouldBeWithNameDespiteAdditionalDefer":"Luke"}}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_nulls_cross_defer_boundaries_null_first() raises:
    """Nulls cross defer boundaries, null first."""
    run_graphql17(
        [
            is_step(
                '{"data":{"a":{}},"pending":[{"id":"0","path":[]},{"id":"1","path":["a"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"a":{}},"pending":[{"id":"0","path":[]},{"id":"1","path":["a"]}],"hasNext":true}',
                result='{"data":{"a":{}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                (
                    '{"hasNext":false,"incremental":[{"data":{"b":{"c":{}}},"id":"1"},{"data":{"d":"d"},"id":"1","subPath":["b","c"]}],"completed":[{"id":"0","errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' c.nonNullErrorField.","path":["a","b","c","nonNullErrorField"]}]},{"id":"1"}]}'
                ),
                True,
            ),
            handle_step(
                UNDEFINED,
                (
                    '{"hasNext":false,"incremental":[{"data":{"b":{"c":{}}},"id":"1"},{"data":{"d":"d"},"id":"1","subPath":["b","c"]}],"completed":[{"id":"0","errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' c.nonNullErrorField.","path":["a","b","c","nonNullErrorField"]}]},{"id":"1"}]}'
                ),
                result=(
                    '{"data":{"a":{"b":{"c":{"d":"d"}}}},"errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' c.nonNullErrorField.","path":["a","b","c","nonNullErrorField"]}]}'
                ),
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_nulls_cross_defer_boundaries_value_first() raises:
    """Nulls cross defer boundaries, value first."""
    run_graphql17(
        [
            is_step(
                '{"data":{"a":{}},"pending":[{"id":"0","path":[]},{"id":"1","path":["a"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"a":{}},"pending":[{"id":"0","path":[]},{"id":"1","path":["a"]}],"hasNext":true}',
                result='{"data":{"a":{}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                (
                    '{"hasNext":false,"incremental":[{"data":{"b":{"c":{}}},"id":"1"},{"data":{"d":"d"},"id":"0","subPath":["a","b","c"]}],"completed":[{"id":"0"},{"id":"1","errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' c.nonNullErrorField.","path":["a","b","c","nonNullErrorField"]}]}]}'
                ),
                True,
            ),
            handle_step(
                UNDEFINED,
                (
                    '{"hasNext":false,"incremental":[{"data":{"b":{"c":{}}},"id":"1"},{"data":{"d":"d"},"id":"0","subPath":["a","b","c"]}],"completed":[{"id":"0"},{"id":"1","errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' c.nonNullErrorField.","path":["a","b","c","nonNullErrorField"]}]}]}'
                ),
                result=(
                    '{"data":{"a":{"b":{"c":{"d":"d"}}}},"errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' c.nonNullErrorField.","path":["a","b","c","nonNullErrorField"]}]}'
                ),
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_handles_multiple_erroring_deferred_grouped_field_sets() raises:
    """Handles multiple erroring deferred grouped field sets."""
    run_graphql17(
        [
            is_step(
                '{"data":{},"pending":[{"id":"0","path":[]},{"id":"1","path":[]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{},"pending":[{"id":"0","path":[]},{"id":"1","path":[]}],"hasNext":true}',
                result='{"data":{}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                (
                    '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' c.nonNullErrorField.","path":["a","b","c","someError"]}]},{"id":"1","errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' c.nonNullErrorField.","path":["a","b","c","anotherError"]}]}]}'
                ),
                True,
            ),
            handle_step(
                UNDEFINED,
                (
                    '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' c.nonNullErrorField.","path":["a","b","c","someError"]}]},{"id":"1","errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' c.nonNullErrorField.","path":["a","b","c","anotherError"]}]}]}'
                ),
                result=(
                    '{"data":{},"errors":[{"message":"Cannot return null for'
                    " non-nullable field"
                    ' c.nonNullErrorField.","path":["a","b","c","someError"]},{"message":"Cannot'
                    " return null for non-nullable field"
                    ' c.nonNullErrorField.","path":["a","b","c","anotherError"]}]}'
                ),
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_handles_multiple_erroring_deferred_grouped_field_sets_for_the_same_fragment() raises:
    """Handles multiple erroring deferred grouped field sets for the same fragment.
    """
    run_graphql17(
        [
            is_step(
                '{"data":{},"pending":[{"id":"0","path":[]},{"id":"1","path":[]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{},"pending":[{"id":"0","path":[]},{"id":"1","path":[]}],"hasNext":true}',
                result='{"data":{}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                (
                    '{"hasNext":false,"incremental":[{"data":{"a":{"b":{"someC":{},"anotherC":{}}}},"id":"0"},{"data":{"d":"d"},"id":"0","subPath":["a","b","someC"]},{"data":{"d":"d"},"id":"0","subPath":["a","b","anotherC"]}],"completed":[{"id":"1","errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' c.nonNullErrorField.","path":["a","b","someC","someError"]}]},{"id":"0"}]}'
                ),
                True,
            ),
            handle_step(
                UNDEFINED,
                (
                    '{"hasNext":false,"incremental":[{"data":{"a":{"b":{"someC":{},"anotherC":{}}}},"id":"0"},{"data":{"d":"d"},"id":"0","subPath":["a","b","someC"]},{"data":{"d":"d"},"id":"0","subPath":["a","b","anotherC"]}],"completed":[{"id":"1","errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' c.nonNullErrorField.","path":["a","b","someC","someError"]}]},{"id":"0"}]}'
                ),
                result=(
                    '{"data":{"a":{"b":{"someC":{"d":"d"},"anotherC":{"d":"d"}}}},"errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' c.nonNullErrorField.","path":["a","b","someC","someError"]}]}'
                ),
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_filters_a_payload_with_a_null_that_cannot_be_merged() raises:
    """Filters a payload with a null that cannot be merged."""
    run_graphql17(
        [
            is_step(
                '{"data":{"a":{}},"pending":[{"id":"0","path":[]},{"id":"1","path":["a"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"a":{}},"pending":[{"id":"0","path":[]},{"id":"1","path":["a"]}],"hasNext":true}',
                result='{"data":{"a":{}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":true,"incremental":[{"data":{"b":{"c":{}}},"id":"1"},{"data":{"d":"d"},"id":"1","subPath":["b","c"]}],"completed":[{"id":"1"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":true,"incremental":[{"data":{"b":{"c":{}}},"id":"1"},{"data":{"d":"d"},"id":"1","subPath":["b","c"]}],"completed":[{"id":"1"}]}',
                result='{"data":{"a":{"b":{"c":{"d":"d"}}}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                (
                    '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' c.nonNullErrorField.","path":["a","b","c","nonNullErrorField"]}]}]}'
                ),
                True,
            ),
            handle_step(
                UNDEFINED,
                (
                    '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' c.nonNullErrorField.","path":["a","b","c","nonNullErrorField"]}]}]}'
                ),
                result=(
                    '{"data":{"a":{"b":{"c":{"d":"d"}}}},"errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' c.nonNullErrorField.","path":["a","b","c","nonNullErrorField"]}]}'
                ),
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_cancels_deferred_fields_when_deferred_result_exhibits_null_bubbling() raises:
    """Cancels deferred fields when deferred result exhibits null bubbling."""
    run_graphql17(
        [
            is_step(
                '{"data":{},"pending":[{"id":"0","path":[]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{},"pending":[{"id":"0","path":[]}],"hasNext":true}',
                result='{"data":{}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                (
                    '{"hasNext":false,"incremental":[{"data":{"hero":null},"errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' Hero.nonNullName.","path":["hero","nonNullName"]}],"id":"0"}],"completed":[{"id":"0"}]}'
                ),
                True,
            ),
            handle_step(
                UNDEFINED,
                (
                    '{"hasNext":false,"incremental":[{"data":{"hero":null},"errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' Hero.nonNullName.","path":["hero","nonNullName"]}],"id":"0"}],"completed":[{"id":"0"}]}'
                ),
                result=(
                    '{"data":{"hero":null},"errors":[{"message":"Cannot return'
                    " null for non-nullable field"
                    ' Hero.nonNullName.","path":["hero","nonNullName"]}]}'
                ),
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_does_not_deduplicate_list_fields_with_non_overlapping_fields() raises:
    """Does not deduplicate list fields with non-overlapping fields."""
    run_graphql17(
        [
            is_step(
                '{"data":{"hero":{"friends":[{"name":"Han"},{"name":"Leia"},{"name":"C-3PO"}]}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"hero":{"friends":[{"name":"Han"},{"name":"Leia"},{"name":"C-3PO"}]}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
                result='{"data":{"hero":{"friends":[{"name":"Han"},{"name":"Leia"},{"name":"C-3PO"}]}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"data":{"id":"2"},"id":"0","subPath":["friends",0]},{"data":{"id":"3"},"id":"0","subPath":["friends",1]},{"data":{"id":"4"},"id":"0","subPath":["friends",2]}],"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"incremental":[{"data":{"id":"2"},"id":"0","subPath":["friends",0]},{"data":{"id":"3"},"id":"0","subPath":["friends",1]},{"data":{"id":"4"},"id":"0","subPath":["friends",2]}],"completed":[{"id":"0"}]}',
                result='{"data":{"hero":{"friends":[{"name":"Han","id":"2"},{"name":"Leia","id":"3"},{"name":"C-3PO","id":"4"}]}}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_handles_errors_thrown_in_deferred_fragments() raises:
    """Handles errors thrown in deferred fragments."""
    run_graphql17(
        [
            is_step(
                '{"data":{"hero":{"id":"1"}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"hero":{"id":"1"}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
                result='{"data":{"hero":{"id":"1"}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"data":{"name":null},"errors":[{"message":"bad","path":["hero","name"]}],"id":"0"}],"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"incremental":[{"data":{"name":null},"errors":[{"message":"bad","path":["hero","name"]}],"id":"0"}],"completed":[{"id":"0"}]}',
                result='{"data":{"hero":{"id":"1","name":null}},"errors":[{"message":"bad","path":["hero","name"]}]}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_handles_non_nullable_errors_thrown_in_deferred_fragments() raises:
    """Handles non-nullable errors thrown in deferred fragments."""
    run_graphql17(
        [
            is_step(
                '{"data":{"hero":{"id":"1"}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"hero":{"id":"1"}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
                result='{"data":{"hero":{"id":"1"}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                (
                    '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' Hero.nonNullName.","path":["hero","nonNullName"]}]}]}'
                ),
                True,
            ),
            handle_step(
                UNDEFINED,
                (
                    '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' Hero.nonNullName.","path":["hero","nonNullName"]}]}]}'
                ),
                result=(
                    '{"data":{"hero":{"id":"1"}},"errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' Hero.nonNullName.","path":["hero","nonNullName"]}]}'
                ),
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_handles_async_non_nullable_errors_thrown_in_deferred_fragments() raises:
    """Handles async non-nullable errors thrown in deferred fragments."""
    run_graphql17(
        [
            is_step(
                '{"data":{"hero":{"id":"1"}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"hero":{"id":"1"}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
                result='{"data":{"hero":{"id":"1"}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                (
                    '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' Hero.nonNullName.","path":["hero","nonNullName"]}]}]}'
                ),
                True,
            ),
            handle_step(
                UNDEFINED,
                (
                    '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' Hero.nonNullName.","path":["hero","nonNullName"]}]}]}'
                ),
                result=(
                    '{"data":{"hero":{"id":"1"}},"errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' Hero.nonNullName.","path":["hero","nonNullName"]}]}'
                ),
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_returns_payloads_in_correct_order() raises:
    """Returns payloads in correct order."""
    run_graphql17(
        [
            is_step(
                '{"data":{"hero":{"id":"1"}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"hero":{"id":"1"}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
                result='{"data":{"hero":{"id":"1"}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":false,"pending":[{"id":"1","path":["hero","friends",0]},{"id":"2","path":["hero","friends",1]},{"id":"3","path":["hero","friends",2]}],"incremental":[{"data":{"name":"slow","friends":[{},{},{}]},"id":"0"},{"data":{"name":"Han"},"id":"1"},{"data":{"name":"Leia"},"id":"2"},{"data":{"name":"C-3PO"},"id":"3"}],"completed":[{"id":"0"},{"id":"1"},{"id":"2"},{"id":"3"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"pending":[{"id":"1","path":["hero","friends",0]},{"id":"2","path":["hero","friends",1]},{"id":"3","path":["hero","friends",2]}],"incremental":[{"data":{"name":"slow","friends":[{},{},{}]},"id":"0"},{"data":{"name":"Han"},"id":"1"},{"data":{"name":"Leia"},"id":"2"},{"data":{"name":"C-3PO"},"id":"3"}],"completed":[{"id":"0"},{"id":"1"},{"id":"2"},{"id":"3"}]}',
                result='{"data":{"hero":{"id":"1","name":"slow","friends":[{"name":"Han"},{"name":"Leia"},{"name":"C-3PO"}]}}}',
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def test_handles_an_incremental_payload_for_a_defer_id_that_already_completed_with_errors() raises:
    """Handles an incremental payload for a defer id that already completed with errors.
    """
    run_graphql17(
        [
            is_step(
                '{"data":{"hero":{}},"pending":[{"id":"0","path":[],"label":"outer"},{"id":"1","path":["hero"],"label":"inner"}],"hasNext":true}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"data":{"hero":{}},"pending":[{"id":"0","path":[],"label":"outer"},{"id":"1","path":["hero"],"label":"inner"}],"hasNext":true}',
                result='{"data":{"hero":{}}}',
                has_next=True,
                stream_info=False,
            ),
            is_step(
                (
                    '{"hasNext":true,"completed":[{"id":"1","errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' Hero.nonNullName.","path":["hero","nonNullName"]}]}]}'
                ),
                True,
            ),
            handle_step(
                UNDEFINED,
                (
                    '{"hasNext":true,"completed":[{"id":"1","errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' Hero.nonNullName.","path":["hero","nonNullName"]}]}]}'
                ),
                result=(
                    '{"data":{"hero":{}},"errors":[{"message":"Cannot return'
                    " null for non-nullable field"
                    ' Hero.nonNullName.","path":["hero","nonNullName"]}]}'
                ),
                has_next=True,
                stream_info=False,
            ),
            is_step(
                '{"hasNext":false,"incremental":[{"data":{"name":"Luke"},"id":"1"}],"completed":[{"id":"0"}]}',
                True,
            ),
            handle_step(
                UNDEFINED,
                '{"hasNext":false,"incremental":[{"data":{"name":"Luke"},"id":"1"}],"completed":[{"id":"0"}]}',
                result=(
                    '{"data":{"hero":{"name":"Luke"}},"errors":[{"message":"Cannot'
                    " return null for non-nullable field"
                    ' Hero.nonNullName.","path":["hero","nonNullName"]}]}'
                ),
                has_next=False,
                stream_info=False,
            ),
        ]
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

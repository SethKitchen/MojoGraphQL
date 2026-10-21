# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `@defer`: graphql-js v17.0.2 (71606d73)
`src/execution/incremental/__tests__/defer-test.ts`.

Each case has the upstream operation and the upstream root value, made
synchronous: a resolver function is its value, a promise is the value it
resolves to, an async generator is the list of its items, and a resolver
that throws is the property `{"__throw": message}`, which
`throwing_resolver` raises. The expected payloads are the output of
graphql-js v17.0.2 itself, run in Node.js on the same synchronous
root value. With synchronous resolvers, graphql-js delivers the work of
one tick in one payload, so a case can have fewer payloads than upstream
expects with promises.

"Does execute deferred fragments early when specified" checks the
payloads with `enable_early_execution`. Upstream also checks the order of
an async resolver and a deferred resolver; synchronous resolvers have one
order. `test_incremental_cancel.mojo` checks when the deferred fields
execute, and ports the cases of the abort signal.

These upstream cases are not ported:

- "Initiates deferred grouped field sets only if they have been released
  as pending" and "Initiates unique deferred grouped field sets after those
  that are common to sibling defers": they hold promises open to see when
  an execution group starts. With synchronous execution each group starts
  when it is released, as the other cases show.
"""

from std.testing import TestSuite

from gql_schema.build import build_schema

from _incremental import expect

comptime _SDL = """
type Friend { id: ID name: String nonNullName: String! }
type DeeperObject { foo: String bar: String baz: String bak: String }
type NestedObject { deeperObject: DeeperObject name: String }
type AnotherNestedObject { deeperObject: DeeperObject }
type c { d: String nonNullErrorField: String! }
type e { f: String }
type b { c: c e: e }
type a { b: b someField: String nonNullErrorField: String! }
type g { h: String }
type Hero {
  id: ID
  name: String
  nonNullName: String!
  friends: [Friend]
  nestedObject: NestedObject
  anotherNestedObject: AnotherNestedObject
}
type Query { hero: Hero a: a g: g }
"""


def _expect(
    query: String, root: String, expected: List[String], early: Bool = False
) raises:
    """Check the payloads of an operation against the upstream schema.
    The schema does not define `@defer`, as upstream."""
    expect(build_schema(_SDL), query, root, expected, early)


def test_can_defer_fragments_containing_scalar_types() raises:
    """Can defer fragments containing scalar types."""
    _expect(
        (
            "\n      query HeroNameQuery {\n        hero {\n          id\n     "
            "     ...NameFragment @defer\n        }\n      }\n      fragment"
            " NameFragment on Hero {\n        name\n      }\n    "
        ),
        '{"hero":{"name":"Luke","id":1}}',
        [
            '{"data":{"hero":{"id":"1"}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","data":{"name":"Luke"}}],"completed":[{"id":"0"}]}',
        ],
    )


def test_returns_label_from_defer_directive() raises:
    """Returns label from defer directive."""
    _expect(
        (
            "\n      query HeroNameQuery {\n        hero {\n          id\n     "
            '     ...NameFragment @defer(label: "defer-label")\n        }\n    '
            "  }\n      fragment NameFragment on Hero {\n        name\n     "
            " }\n    "
        ),
        '{"hero":{"name":"Luke","id":1}}',
        [
            '{"data":{"hero":{"id":"1"}},"pending":[{"id":"0","path":["hero"],"label":"defer-label"}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","data":{"name":"Luke"}}],"completed":[{"id":"0"}]}',
        ],
    )


def test_treats_null_defer_label_the_same_as_no_label() raises:
    """Treats null defer label the same as no label."""
    _expect(
        (
            "\n      query HeroNameQuery {\n        hero {\n          id\n     "
            "     ...NameFragment @defer(label: null)\n        }\n      }\n    "
            "  fragment NameFragment on Hero {\n        name\n      }\n    "
        ),
        '{"hero":{"name":"Luke","id":1}}',
        [
            '{"data":{"hero":{"id":"1"}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","data":{"name":"Luke"}}],"completed":[{"id":"0"}]}',
        ],
    )


def test_can_disable_defer_using_if_argument() raises:
    """Can disable defer using if argument."""
    _expect(
        (
            "\n      query HeroNameQuery {\n        hero {\n          id\n     "
            "     ...NameFragment @defer(if: false)\n        }\n      }\n     "
            " fragment NameFragment on Hero {\n        name\n      }\n    "
        ),
        '{"hero":{"name":"Luke","id":1}}',
        [
            '{"data":{"hero":{"id":"1","name":"Luke"}}}',
        ],
    )


def test_does_not_disable_defer_with_null_if_argument() raises:
    """Does not disable defer with null if argument."""
    _expect(
        (
            "\n      query HeroNameQuery($shouldDefer: Boolean) {\n        hero"
            " {\n          id\n          ...NameFragment @defer(if:"
            " $shouldDefer)\n        }\n      }\n      fragment NameFragment on"
            " Hero {\n        name\n      }\n    "
        ),
        '{"hero":{"name":"Luke","id":1}}',
        [
            '{"data":{"hero":{"id":"1"}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","data":{"name":"Luke"}}],"completed":[{"id":"0"}]}',
        ],
    )


def test_does_not_execute_deferred_fragments_early_when_not_specified() raises:
    """Does not execute deferred fragments early when not specified."""
    _expect(
        (
            "\n      query HeroNameQuery {\n        hero {\n          id\n     "
            "     ...NameFragment @defer\n        }\n      }\n      fragment"
            " NameFragment on Hero {\n        name\n      }\n    "
        ),
        '{"hero":{"name":"Luke","id":1}}',
        [
            '{"data":{"hero":{"id":"1"}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","data":{"name":"Luke"}}],"completed":[{"id":"0"}]}',
        ],
    )


def test_does_execute_deferred_fragments_early_when_specified() raises:
    """Does execute deferred fragments early when specified."""
    _expect(
        (
            "\n      query HeroNameQuery {\n        hero {\n          id\n     "
            "     ...NameFragment @defer\n        }\n      }\n      fragment"
            " NameFragment on Hero {\n        name\n      }\n    "
        ),
        '{"hero":{"name":"Luke","id":1}}',
        [
            '{"data":{"hero":{"id":"1"}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","data":{"name":"Luke"}}],"completed":[{"id":"0"}]}',
        ],
        early=True,
    )


def test_can_defer_fragments_on_the_top_level_query_field() raises:
    """Can defer fragments on the top level Query field."""
    _expect(
        (
            "\n      query HeroNameQuery {\n        ...QueryFragment"
            ' @defer(label: "DeferQuery")\n      }\n      fragment'
            " QueryFragment on Query {\n        hero {\n          id\n       "
            " }\n      }\n    "
        ),
        '{"hero":{"name":"Luke","id":1}}',
        [
            '{"data":{},"pending":[{"id":"0","path":[],"label":"DeferQuery"}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","data":{"hero":{"id":"1"}}}],"completed":[{"id":"0"}]}',
        ],
    )


def test_can_defer_fragments_with_errors_on_the_top_level_query_field() raises:
    """Can defer fragments with errors on the top level Query field."""
    _expect(
        (
            "\n      query HeroNameQuery {\n        ...QueryFragment"
            ' @defer(label: "DeferQuery")\n      }\n      fragment'
            " QueryFragment on Query {\n        hero {\n          name\n       "
            " }\n      }\n    "
        ),
        '{"hero":{"name":{"__throw":"bad"},"id":1}}',
        [
            '{"data":{},"pending":[{"id":"0","path":[],"label":"DeferQuery"}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","data":{"hero":{"name":null}},"errors":[{"message":"bad","locations":[{"line":7,"column":11}],"path":["hero","name"]}]}],"completed":[{"id":"0"}]}',
        ],
    )


def test_can_defer_a_fragment_within_an_already_deferred_fragment() raises:
    """Can defer a fragment within an already deferred fragment."""
    _expect(
        (
            "\n      query HeroNameQuery {\n        hero {\n         "
            ' ...TopFragment @defer(label: "DeferTop")\n        }\n      }\n   '
            "   fragment TopFragment on Hero {\n        id\n       "
            ' ...NestedFragment @defer(label: "DeferNested")\n      }\n     '
            " fragment NestedFragment on Hero {\n        friends {\n         "
            " name\n        }\n      }\n    "
        ),
        '{"hero":{"name":"Luke","id":1}}',
        [
            '{"data":{"hero":{}},"pending":[{"id":"0","path":["hero"],"label":"DeferTop"}],"hasNext":true}',
            '{"hasNext":false,"pending":[{"id":"1","path":["hero"],"label":"DeferNested"}],"incremental":[{"id":"0","data":{"id":"1"}},{"id":"1","data":{"friends":null}}],"completed":[{"id":"0"},{"id":"1"}]}',
        ],
    )


def test_can_defer_a_fragment_that_is_also_not_deferred_deferred_fragment_is_fi() raises:
    """Can defer a fragment that is also not deferred, deferred fragment is first.
    """
    _expect(
        (
            "\n      query HeroNameQuery {\n        hero {\n         "
            ' ...TopFragment @defer(label: "DeferTop")\n         '
            " ...TopFragment\n        }\n      }\n      fragment TopFragment on"
            " Hero {\n        name\n      }\n    "
        ),
        '{"hero":{"name":"Luke","id":1}}',
        [
            '{"data":{"hero":{"name":"Luke"}}}',
        ],
    )


def test_can_defer_a_fragment_that_is_also_not_deferred_non_deferred_fragment_i() raises:
    """Can defer a fragment that is also not deferred, non-deferred fragment is first.
    """
    _expect(
        (
            "\n      query HeroNameQuery {\n        hero {\n         "
            " ...TopFragment\n          ...TopFragment @defer(label:"
            ' "DeferTop")\n        }\n      }\n      fragment TopFragment on'
            " Hero {\n        name\n      }\n    "
        ),
        '{"hero":{"name":"Luke","id":1}}',
        [
            '{"data":{"hero":{"name":"Luke"}}}',
        ],
    )


def test_can_defer_an_inline_fragment() raises:
    """Can defer an inline fragment."""
    _expect(
        (
            "\n      query HeroNameQuery {\n        hero {\n          id\n     "
            '     ... on Hero @defer(label: "InlineDeferred") {\n           '
            " name\n          }\n        }\n      }\n    "
        ),
        '{"hero":{"name":"Luke","id":1}}',
        [
            '{"data":{"hero":{"id":"1"}},"pending":[{"id":"0","path":["hero"],"label":"InlineDeferred"}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","data":{"name":"Luke"}}],"completed":[{"id":"0"}]}',
        ],
    )


def test_does_not_emit_empty_defer_fragments() raises:
    """Does not emit empty defer fragments."""
    _expect(
        (
            "\n      query HeroNameQuery {\n        hero {\n          ..."
            " @defer {\n            name @skip(if: true)\n          }\n       "
            " }\n      }\n      fragment TopFragment on Hero {\n        name\n "
            "     }\n    "
        ),
        '{"hero":{"name":"Luke","id":1}}',
        [
            '{"data":{"hero":{}}}',
        ],
    )


def test_emits_children_of_empty_defer_fragments() raises:
    """Emits children of empty defer fragments."""
    _expect(
        (
            "\n      query HeroNameQuery {\n        hero {\n          ..."
            " @defer {\n            ... @defer {\n              name\n         "
            "   }\n          }\n        }\n      }\n    "
        ),
        '{"hero":{"name":"Luke","id":1}}',
        [
            '{"data":{"hero":{}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","data":{"name":"Luke"}}],"completed":[{"id":"0"}]}',
        ],
    )


def test_can_separately_emit_defer_fragments_with_different_labels_with_varying() raises:
    """Can separately emit defer fragments with different labels with varying fields.
    """
    _expect(
        (
            "\n      query HeroNameQuery {\n        hero {\n          ..."
            ' @defer(label: "DeferID") {\n            id\n          }\n        '
            '  ... @defer(label: "DeferName") {\n            name\n         '
            " }\n        }\n      }\n    "
        ),
        '{"hero":{"name":"Luke","id":1}}',
        [
            '{"data":{"hero":{}},"pending":[{"id":"0","path":["hero"],"label":"DeferID"},{"id":"1","path":["hero"],"label":"DeferName"}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","data":{"id":"1"}},{"id":"1","data":{"name":"Luke"}}],"completed":[{"id":"0"},{"id":"1"}]}',
        ],
    )


def test_separately_emits_defer_fragments_with_different_labels_with_varying_su() raises:
    """Separately emits defer fragments with different labels with varying subfields.
    """
    _expect(
        (
            "\n      query HeroNameQuery {\n        ... @defer(label:"
            ' "DeferID") {\n          hero {\n            id\n          }\n    '
            '    }\n        ... @defer(label: "DeferName") {\n          hero'
            " {\n            name\n          }\n        }\n      }\n    "
        ),
        '{"hero":{"name":"Luke","id":1}}',
        [
            '{"data":{},"pending":[{"id":"0","path":[],"label":"DeferID"},{"id":"1","path":[],"label":"DeferName"}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","data":{"hero":{}}},{"id":"0","data":{"id":"1"},"subPath":["hero"]},{"id":"1","data":{"name":"Luke"},"subPath":["hero"]}],"completed":[{"id":"0"},{"id":"1"}]}',
        ],
    )


def test_separately_emits_defer_fragments_with_different_labels_with_varying_su_2() raises:
    """Separately emits defer fragments with different labels with varying subfields that return promises.
    """
    _expect(
        (
            "\n      query HeroNameQuery {\n        ... @defer(label:"
            ' "DeferID") {\n          hero {\n            id\n          }\n    '
            '    }\n        ... @defer(label: "DeferName") {\n          hero'
            " {\n            name\n          }\n        }\n      }\n    "
        ),
        '{"hero":{"id":"1","name":"Luke"}}',
        [
            '{"data":{},"pending":[{"id":"0","path":[],"label":"DeferID"},{"id":"1","path":[],"label":"DeferName"}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","data":{"hero":{}}},{"id":"0","data":{"id":"1"},"subPath":["hero"]},{"id":"1","data":{"name":"Luke"},"subPath":["hero"]}],"completed":[{"id":"0"},{"id":"1"}]}',
        ],
    )


def test_separately_emits_defer_fragments_with_varying_subfields_of_same_priori() raises:
    """Separately emits defer fragments with varying subfields of same priorities but different level of defers.
    """
    _expect(
        (
            "\n      query HeroNameQuery {\n        hero {\n          ..."
            ' @defer(label: "DeferID") {\n            id\n          }\n       '
            ' }\n        ... @defer(label: "DeferName") {\n          hero {\n  '
            "          name\n          }\n        }\n      }\n    "
        ),
        '{"hero":{"name":"Luke","id":1}}',
        [
            '{"data":{"hero":{}},"pending":[{"id":"0","path":["hero"],"label":"DeferID"},{"id":"1","path":[],"label":"DeferName"}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","data":{"id":"1"}},{"id":"1","data":{"name":"Luke"},"subPath":["hero"]}],"completed":[{"id":"0"},{"id":"1"}]}',
        ],
    )


def test_separately_emits_nested_defer_fragments_with_varying_subfields_of_same() raises:
    """Separately emits nested defer fragments with varying subfields of same priorities but different level of defers.
    """
    _expect(
        (
            "\n      query HeroNameQuery {\n        ... @defer(label:"
            ' "DeferName") {\n          hero {\n            name\n           '
            ' ... @defer(label: "DeferID") {\n              id\n            }\n'
            "          }\n        }\n      }\n    "
        ),
        '{"hero":{"name":"Luke","id":1}}',
        [
            '{"data":{},"pending":[{"id":"0","path":[],"label":"DeferName"}],"hasNext":true}',
            '{"hasNext":false,"pending":[{"id":"1","path":["hero"],"label":"DeferID"}],"incremental":[{"id":"0","data":{"hero":{"name":"Luke"}}},{"id":"1","data":{"id":"1"}}],"completed":[{"id":"0"},{"id":"1"}]}',
        ],
    )


def test_can_deduplicate_multiple_defers_on_the_same_object() raises:
    """Can deduplicate multiple defers on the same object."""
    _expect(
        (
            "\n      query {\n        hero {\n          friends {\n           "
            " ... @defer {\n              ...FriendFrag\n              ..."
            " @defer {\n                ...FriendFrag\n                ..."
            " @defer {\n                  ...FriendFrag\n                  ..."
            " @defer {\n                    ...FriendFrag\n                 "
            " }\n                }\n              }\n            }\n         "
            " }\n        }\n      }\n\n      fragment FriendFrag on Friend {\n "
            "       id\n        name\n      }\n    "
        ),
        '{"hero":{"name":"Luke","id":1}}',
        [
            '{"data":{"hero":{"friends":null}}}',
        ],
    )


def test_deduplicates_fields_present_in_the_initial_payload() raises:
    """Deduplicates fields present in the initial payload."""
    _expect(
        (
            "\n      query {\n        hero {\n          nestedObject {\n       "
            "     deeperObject {\n              foo\n            }\n         "
            " }\n          anotherNestedObject {\n            deeperObject {\n "
            "             foo\n            }\n          }\n          ... @defer"
            " {\n            nestedObject {\n              deeperObject {\n    "
            "            bar\n              }\n            }\n           "
            " anotherNestedObject {\n              deeperObject {\n            "
            "    foo\n              }\n            }\n          }\n        }\n "
            "     }\n    "
        ),
        '{"hero":{"nestedObject":{"deeperObject":{"foo":"foo","bar":"bar"}},"anotherNestedObject":{"deeperObject":{"foo":"foo"}}}}',
        [
            '{"data":{"hero":{"nestedObject":{"deeperObject":{"foo":"foo"}},"anotherNestedObject":{"deeperObject":{"foo":"foo"}}}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","data":{"bar":"bar"},"subPath":["nestedObject","deeperObject"]}],"completed":[{"id":"0"}]}',
        ],
    )


def test_deduplicates_fields_present_in_a_parent_defer_payload() raises:
    """Deduplicates fields present in a parent defer payload."""
    _expect(
        (
            "\n      query {\n        hero {\n          ... @defer {\n         "
            "   nestedObject {\n              deeperObject {\n               "
            " foo\n                ... @defer {\n                  foo\n       "
            "           bar\n                }\n              }\n           "
            " }\n          }\n        }\n      }\n    "
        ),
        '{"hero":{"nestedObject":{"deeperObject":{"foo":"foo","bar":"bar"}}}}',
        [
            '{"data":{"hero":{}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
            '{"hasNext":false,"pending":[{"id":"1","path":["hero","nestedObject","deeperObject"]}],"incremental":[{"id":"0","data":{"nestedObject":{"deeperObject":{"foo":"foo"}}}},{"id":"1","data":{"bar":"bar"}}],"completed":[{"id":"0"},{"id":"1"}]}',
        ],
    )


def test_deduplicates_fields_with_deferred_fragments_at_multiple_levels() raises:
    """Deduplicates fields with deferred fragments at multiple levels."""
    _expect(
        (
            "\n      query {\n        hero {\n          nestedObject {\n       "
            "     deeperObject {\n              foo\n            }\n         "
            " }\n          ... @defer {\n            nestedObject {\n          "
            "    deeperObject {\n                foo\n                bar\n    "
            "          }\n              ... @defer {\n               "
            " deeperObject {\n                  foo\n                  bar\n   "
            "               baz\n                  ... @defer {\n              "
            "      foo\n                    bar\n                    baz\n     "
            "               bak\n                  }\n                }\n      "
            "        }\n            }\n          }\n        }\n      }\n    "
        ),
        '{"hero":{"nestedObject":{"deeperObject":{"foo":"foo","bar":"bar","baz":"baz","bak":"bak"}}}}',
        [
            '{"data":{"hero":{"nestedObject":{"deeperObject":{"foo":"foo"}}}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
            '{"hasNext":false,"pending":[{"id":"1","path":["hero","nestedObject"]},{"id":"2","path":["hero","nestedObject","deeperObject"]}],"incremental":[{"id":"0","data":{"bar":"bar"},"subPath":["nestedObject","deeperObject"]},{"id":"1","data":{"baz":"baz"},"subPath":["deeperObject"]},{"id":"2","data":{"bak":"bak"}}],"completed":[{"id":"0"},{"id":"1"},{"id":"2"}]}',
        ],
    )


def test_deduplicates_multiple_fields_from_deferred_fragments_from_different_br() raises:
    """Deduplicates multiple fields from deferred fragments from different branches occurring at the same level.
    """
    _expect(
        (
            "\n      query {\n        hero {\n          nestedObject {\n       "
            "     deeperObject {\n              ... @defer {\n               "
            " foo\n              }\n            }\n          }\n          ..."
            " @defer {\n            nestedObject {\n              deeperObject"
            " {\n                ... @defer {\n                  foo\n         "
            "         bar\n                }\n              }\n            }\n "
            "         }\n        }\n      }\n    "
        ),
        '{"hero":{"nestedObject":{"deeperObject":{"foo":"foo","bar":"bar"}}}}',
        [
            '{"data":{"hero":{"nestedObject":{"deeperObject":{}}}},"pending":[{"id":"0","path":["hero","nestedObject","deeperObject"]},{"id":"1","path":["hero","nestedObject","deeperObject"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","data":{"foo":"foo"}},{"id":"1","data":{"bar":"bar"}}],"completed":[{"id":"0"},{"id":"1"}]}',
        ],
    )


def test_deduplicate_fields_with_deferred_fragments_in_different_branches_at_mu() raises:
    """Deduplicate fields with deferred fragments in different branches at multiple non-overlapping levels.
    """
    _expect(
        (
            "\n      query {\n        a {\n          b {\n            c {\n    "
            "          d\n            }\n            ... @defer {\n            "
            "  e {\n                f\n              }\n            }\n        "
            "  }\n        }\n        ... @defer {\n          a {\n            b"
            " {\n              e {\n                f\n              }\n       "
            "     }\n          }\n          g {\n            h\n          }\n  "
            "      }\n      }\n    "
        ),
        '{"a":{"b":{"c":{"d":"d"},"e":{"f":"f"}}},"g":{"h":"h"}}',
        [
            '{"data":{"a":{"b":{"c":{"d":"d"}}}},"pending":[{"id":"0","path":["a","b"]},{"id":"1","path":[]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","data":{"e":{"f":"f"}}},{"id":"1","data":{"g":{"h":"h"}}}],"completed":[{"id":"0"},{"id":"1"}]}',
        ],
    )


def test_correctly_bundles_varying_subfields_into_incremental_data_records_uniq() raises:
    """Correctly bundles varying subfields into incremental data records unique by defer combination, ignoring fields in a fragment masked by a parent defer.
    """
    _expect(
        (
            "\n      query HeroNameQuery {\n        ... @defer {\n         "
            " hero {\n            id\n          }\n        }\n        ..."
            " @defer {\n          hero {\n            name\n           "
            " shouldBeWithNameDespiteAdditionalDefer: name\n            ..."
            " @defer {\n              shouldBeWithNameDespiteAdditionalDefer:"
            " name\n            }\n          }\n        }\n      }\n    "
        ),
        '{"hero":{"name":"Luke","id":1}}',
        [
            '{"data":{},"pending":[{"id":"0","path":[]},{"id":"1","path":[]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","data":{"hero":{}}},{"id":"0","data":{"id":"1"},"subPath":["hero"]},{"id":"1","data":{"name":"Luke","shouldBeWithNameDespiteAdditionalDefer":"Luke"},"subPath":["hero"]}],"completed":[{"id":"0"},{"id":"1"}]}',
        ],
    )


def test_nulls_cross_defer_boundaries_null_first() raises:
    """Nulls cross defer boundaries, null first."""
    _expect(
        (
            "\n      query {\n        ... @defer {\n          a {\n           "
            " someField\n            b {\n              c {\n               "
            " nonNullErrorField\n              }\n            }\n          }\n "
            "       }\n        a {\n          ... @defer {\n            b {\n  "
            "            c {\n                d\n              }\n           "
            " }\n          }\n        }\n      }\n    "
        ),
        '{"a":{"b":{"c":{"d":"d"}},"someField":"someField"}}',
        [
            '{"data":{"a":{}},"pending":[{"id":"0","path":["a"]},{"id":"1","path":[]}],"hasNext":true}',
            (
                '{"hasNext":false,"incremental":[{"id":"0","data":{"b":{"c":{}}}},{"id":"0","data":{"d":"d"},"subPath":["b","c"]}],"completed":[{"id":"1","errors":[{"message":"Cannot'
                " return null for non-nullable field"
                ' c.nonNullErrorField.","locations":[{"line":8,"column":17}],"path":["a","b","c","nonNullErrorField"]}]},{"id":"0"}]}'
            ),
        ],
    )


def test_nulls_cross_defer_boundaries_value_first() raises:
    """Nulls cross defer boundaries, value first."""
    _expect(
        (
            "\n      query {\n        ... @defer {\n          a {\n           "
            " b {\n              c {\n                d\n              }\n     "
            "       }\n          }\n        }\n        a {\n          ..."
            " @defer {\n            someField\n            b {\n              c"
            " {\n                nonNullErrorField\n              }\n          "
            "  }\n          }\n        }\n      }\n    "
        ),
        '{"a":{"b":{"c":{"d":"d"},"nonNullErrorFIeld":null},"someField":"someField"}}',
        [
            '{"data":{"a":{}},"pending":[{"id":"0","path":["a"]},{"id":"1","path":[]}],"hasNext":true}',
            (
                '{"hasNext":false,"incremental":[{"id":"0","data":{"b":{"c":{}}}},{"id":"1","data":{"d":"d"},"subPath":["a","b","c"]}],"completed":[{"id":"1"},{"id":"0","errors":[{"message":"Cannot'
                " return null for non-nullable field"
                ' c.nonNullErrorField.","locations":[{"line":17,"column":17}],"path":["a","b","c","nonNullErrorField"]}]}]}'
            ),
        ],
    )


def test_nulls_cross_defer_boundaries_failed_fragment_with_slower_shared_child_() raises:
    """Nulls cross defer boundaries, failed fragment with slower shared child execution groups.
    """
    _expect(
        (
            "\n      query {\n        ... @defer {\n          a {\n           "
            " someField\n            nonNullErrorField\n            b {\n      "
            "        c {\n                d\n              }\n            }\n  "
            "        }\n        }\n        a {\n          ... @defer {\n       "
            "     someField\n            b {\n              e {\n              "
            "  f\n              }\n            }\n          }\n        }\n     "
            " }\n    "
        ),
        '{"a":{"b":{"c":{"d":"d"},"e":{"f":"f"}},"someField":"someField"}}',
        [
            '{"data":{"a":{}},"pending":[{"id":"0","path":["a"]},{"id":"1","path":[]}],"hasNext":true}',
            (
                '{"hasNext":false,"incremental":[{"id":"0","data":{"someField":"someField","b":{}}},{"id":"0","data":{"e":{"f":"f"}},"subPath":["b"]}],"completed":[{"id":"1","errors":[{"message":"Cannot'
                " return null for non-nullable field"
                ' a.nonNullErrorField.","locations":[{"line":6,"column":13}],"path":["a","nonNullErrorField"]}]},{"id":"0"}]}'
            ),
        ],
    )


def test_handles_cancelling_child_deferred_fragments_if_parent_fragment_fails() raises:
    """Handles cancelling child deferred fragments if parent fragment fails."""
    _expect(
        (
            "\n      query {\n        ... @defer {\n          a {\n           "
            " someField\n            b {\n              c {\n               "
            " nonNullErrorField\n              }\n            }\n          }\n "
            "         ... @defer {\n            a {\n              someField\n "
            "           }\n          }\n        }\n        a {\n          ..."
            " @defer {\n            b {\n              c {\n                d\n"
            "              }\n            }\n          }\n        }\n     "
            " }\n    "
        ),
        '{"a":{"b":{"c":{"d":"d"}},"someField":"someField"}}',
        [
            '{"data":{"a":{}},"pending":[{"id":"0","path":["a"]},{"id":"1","path":[]}],"hasNext":true}',
            (
                '{"hasNext":false,"incremental":[{"id":"0","data":{"b":{"c":{}}}},{"id":"0","data":{"d":"d"},"subPath":["b","c"]}],"completed":[{"id":"1","errors":[{"message":"Cannot'
                " return null for non-nullable field"
                ' c.nonNullErrorField.","locations":[{"line":8,"column":17}],"path":["a","b","c","nonNullErrorField"]}]},{"id":"0"}]}'
            ),
        ],
    )


def test_handles_multiple_erroring_deferred_grouped_field_sets() raises:
    """Handles multiple erroring deferred grouped field sets."""
    _expect(
        (
            "\n      query {\n        ... @defer {\n          a {\n           "
            " b {\n              c {\n                someError:"
            " nonNullErrorField\n              }\n            }\n          }\n "
            "       }\n        ... @defer {\n          a {\n            b {\n  "
            "            c {\n                anotherError: nonNullErrorField\n"
            "              }\n            }\n          }\n        }\n     "
            " }\n    "
        ),
        '{"a":{"b":{"c":{"nonNullErrorField":null}}}}',
        [
            '{"data":{},"pending":[{"id":"0","path":[]},{"id":"1","path":[]}],"hasNext":true}',
            (
                '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"Cannot'
                " return null for non-nullable field"
                ' c.nonNullErrorField.","locations":[{"line":7,"column":17}],"path":["a","b","c","someError"]}]},{"id":"1","errors":[{"message":"Cannot'
                " return null for non-nullable field"
                ' c.nonNullErrorField.","locations":[{"line":16,"column":17}],"path":["a","b","c","anotherError"]}]}]}'
            ),
        ],
    )


def test_handles_multiple_erroring_deferred_grouped_field_sets_for_the_same_fra() raises:
    """Handles multiple erroring deferred grouped field sets for the same fragment.
    """
    _expect(
        (
            "\n      query {\n        ... @defer {\n          a {\n           "
            " b {\n              someC: c {\n                d: d\n            "
            "  }\n              anotherC: c {\n                d: d\n          "
            "    }\n            }\n          }\n        }\n        ... @defer"
            " {\n          a {\n            b {\n              someC: c {\n    "
            "            someError: nonNullErrorField\n              }\n       "
            "       anotherC: c {\n                anotherError:"
            " nonNullErrorField\n              }\n            }\n          }\n "
            "       }\n      }\n    "
        ),
        '{"a":{"b":{"c":{"d":"d","nonNullErrorField":null}}}}',
        [
            '{"data":{},"pending":[{"id":"0","path":[]},{"id":"1","path":[]}],"hasNext":true}',
            (
                '{"hasNext":false,"incremental":[{"id":"0","data":{"a":{"b":{"someC":{},"anotherC":{}}}}},{"id":"0","data":{"d":"d"},"subPath":["a","b","someC"]},{"id":"0","data":{"d":"d"},"subPath":["a","b","anotherC"]}],"completed":[{"id":"1","errors":[{"message":"Cannot'
                " return null for non-nullable field"
                ' c.nonNullErrorField.","locations":[{"line":19,"column":17}],"path":["a","b","someC","someError"]}]},{"id":"0"}]}'
            ),
        ],
    )


def test_filters_a_payload_with_a_null_that_cannot_be_merged() raises:
    """Filters a payload with a null that cannot be merged."""
    _expect(
        (
            "\n      query {\n        ... @defer {\n          a {\n           "
            " someField\n            b {\n              c {\n               "
            " nonNullErrorField\n              }\n            }\n          }\n "
            "       }\n        a {\n          ... @defer {\n            b {\n  "
            "            c {\n                d\n              }\n           "
            " }\n          }\n        }\n      }\n    "
        ),
        '{"a":{"b":{"c":{"d":"d","nonNullErrorField":null}},"someField":"someField"}}',
        [
            '{"data":{"a":{}},"pending":[{"id":"0","path":["a"]},{"id":"1","path":[]}],"hasNext":true}',
            (
                '{"hasNext":false,"incremental":[{"id":"0","data":{"b":{"c":{}}}},{"id":"0","data":{"d":"d"},"subPath":["b","c"]}],"completed":[{"id":"1","errors":[{"message":"Cannot'
                " return null for non-nullable field"
                ' c.nonNullErrorField.","locations":[{"line":8,"column":17}],"path":["a","b","c","nonNullErrorField"]}]},{"id":"0"}]}'
            ),
        ],
    )


def test_cancels_deferred_fields_when_initial_result_exhibits_null_bubbling_can() raises:
    """Cancels deferred fields when initial result exhibits null bubbling cancelling the defer.
    """
    _expect(
        (
            "\n      query {\n        hero {\n          nonNullName\n         "
            " ... @defer {\n            name\n          }\n        }\n     "
            " }\n    "
        ),
        '{"hero":{"name":"Luke","id":1,"nonNullName":null}}',
        [
            (
                '{"errors":[{"message":"Cannot return null for non-nullable'
                " field"
                ' Hero.nonNullName.","locations":[{"line":4,"column":11}],"path":["hero","nonNullName"]}],"data":{"hero":null}}'
            ),
        ],
    )


def test_cancels_deferred_fields_when_initial_result_exhibits_null_bubbling_can_2() raises:
    """Cancels deferred fields when initial result exhibits null bubbling cancelling new fields.
    """
    _expect(
        (
            "\n      query {\n        hero {\n          nonNullName\n       "
            " }\n        ... @defer {\n          hero {\n            name\n    "
            "      }\n        }\n      }\n    "
        ),
        '{"hero":{"name":"Luke","id":1,"nonNullName":null}}',
        [
            (
                '{"errors":[{"message":"Cannot return null for non-nullable'
                " field"
                ' Hero.nonNullName.","locations":[{"line":4,"column":11}],"path":["hero","nonNullName"]}],"data":{"hero":null}}'
            ),
        ],
    )


def test_keeps_deferred_work_outside_nulled_error_paths() raises:
    """Keeps deferred work outside nulled error paths."""
    _expect(
        (
            "\n      query {\n        a {\n          ... @defer {\n           "
            " someField\n          }\n          nonNullErrorField\n        }\n "
            "       g {\n          ... @defer {\n            h\n          }\n  "
            "      }\n      }\n    "
        ),
        '{"a":{"someField":"someField","nonNullErrorField":null},"g":{"h":"value"}}',
        [
            (
                '{"errors":[{"message":"Cannot return null for non-nullable'
                " field"
                ' a.nonNullErrorField.","locations":[{"line":7,"column":11}],"path":["a","nonNullErrorField"]}],"data":{"a":null,"g":{}},"pending":[{"id":"0","path":["g"]}],"hasNext":true}'
            ),
            '{"hasNext":false,"incremental":[{"id":"0","data":{"h":"value"}}],"completed":[{"id":"0"}]}',
        ],
    )


def test_cancels_deferred_fields_when_deferred_result_exhibits_null_bubbling() raises:
    """Cancels deferred fields when deferred result exhibits null bubbling."""
    _expect(
        (
            "\n      query {\n        ... @defer {\n          hero {\n         "
            "   nonNullName\n            name\n          }\n        }\n     "
            " }\n    "
        ),
        '{"hero":{"name":"Luke","id":1,"nonNullName":null}}',
        [
            '{"data":{},"pending":[{"id":"0","path":[]}],"hasNext":true}',
            (
                '{"hasNext":false,"incremental":[{"id":"0","data":{"hero":null},"errors":[{"message":"Cannot'
                " return null for non-nullable field"
                ' Hero.nonNullName.","locations":[{"line":5,"column":13}],"path":["hero","nonNullName"]}]}],"completed":[{"id":"0"}]}'
            ),
        ],
    )


def test_deduplicates_list_fields() raises:
    """Deduplicates list fields."""
    _expect(
        (
            "\n      query {\n        hero {\n          friends {\n           "
            " name\n          }\n          ... @defer {\n            friends"
            " {\n              name\n            }\n          }\n        }\n   "
            "   }\n    "
        ),
        '{"hero":{"name":"Luke","id":1}}',
        [
            '{"data":{"hero":{"friends":null}}}',
        ],
    )


def test_deduplicates_async_iterable_list_fields() raises:
    """Deduplicates async iterable list fields."""
    _expect(
        (
            "\n      query {\n        hero {\n          friends {\n           "
            " name\n          }\n          ... @defer {\n            friends"
            " {\n              name\n            }\n          }\n        }\n   "
            "   }\n    "
        ),
        '{"hero":{"name":"Luke","id":1,"friends":{"__stream":"[{\\"name\\":\\"Han\\",\\"id\\":2}]"}}}',
        [
            '{"data":{"hero":{"friends":[{"name":"Han"}]}}}',
        ],
    )


def test_deduplicates_empty_async_iterable_list_fields() raises:
    """Deduplicates empty async iterable list fields."""
    _expect(
        (
            "\n      query {\n        hero {\n          friends {\n           "
            " name\n          }\n          ... @defer {\n            friends"
            " {\n              name\n            }\n          }\n        }\n   "
            "   }\n    "
        ),
        '{"hero":{"name":"Luke","id":1,"friends":{"__stream":"[]"}}}',
        [
            '{"data":{"hero":{"friends":[]}}}',
        ],
    )


def test_does_not_deduplicate_list_fields_with_non_overlapping_fields() raises:
    """Does not deduplicate list fields with non-overlapping fields."""
    _expect(
        (
            "\n      query {\n        hero {\n          friends {\n           "
            " name\n          }\n          ... @defer {\n            friends"
            " {\n              id\n            }\n          }\n        }\n     "
            " }\n    "
        ),
        '{"hero":{"name":"Luke","id":1}}',
        [
            '{"data":{"hero":{"friends":null}}}',
        ],
    )


def test_deduplicates_list_fields_that_return_empty_lists() raises:
    """Deduplicates list fields that return empty lists."""
    _expect(
        (
            "\n      query {\n        hero {\n          friends {\n           "
            " name\n          }\n          ... @defer {\n            friends"
            " {\n              name\n            }\n          }\n        }\n   "
            "   }\n    "
        ),
        '{"hero":{"name":"Luke","id":1,"friends":[]}}',
        [
            '{"data":{"hero":{"friends":[]}}}',
        ],
    )


def test_deduplicates_null_object_fields() raises:
    """Deduplicates null object fields."""
    _expect(
        (
            "\n      query {\n        hero {\n          nestedObject {\n       "
            "     name\n          }\n          ... @defer {\n           "
            " nestedObject {\n              name\n            }\n          }\n "
            "       }\n      }\n    "
        ),
        '{"hero":{"name":"Luke","id":1,"nestedObject":null}}',
        [
            '{"data":{"hero":{"nestedObject":null}}}',
        ],
    )


def test_deduplicates_promise_object_fields() raises:
    """Deduplicates promise object fields."""
    _expect(
        (
            "\n      query {\n        hero {\n          nestedObject {\n       "
            "     name\n          }\n          ... @defer {\n           "
            " nestedObject {\n              name\n            }\n          }\n "
            "       }\n      }\n    "
        ),
        '{"hero":{"nestedObject":{"name":"foo"}}}',
        [
            '{"data":{"hero":{"nestedObject":{"name":"foo"}}}}',
        ],
    )


def test_handles_errors_thrown_in_deferred_fragments() raises:
    """Handles errors thrown in deferred fragments."""
    _expect(
        (
            "\n      query HeroNameQuery {\n        hero {\n          id\n     "
            "     ...NameFragment @defer\n        }\n      }\n      fragment"
            " NameFragment on Hero {\n        name\n      }\n    "
        ),
        '{"hero":{"name":{"__throw":"bad"},"id":1}}',
        [
            '{"data":{"hero":{"id":"1"}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","data":{"name":null},"errors":[{"message":"bad","locations":[{"line":9,"column":9}],"path":["hero","name"]}]}],"completed":[{"id":"0"}]}',
        ],
    )


def test_handles_non_nullable_errors_thrown_in_deferred_fragments() raises:
    """Handles non-nullable errors thrown in deferred fragments."""
    _expect(
        (
            "\n      query HeroNameQuery {\n        hero {\n          id\n     "
            "     ...NameFragment @defer\n        }\n      }\n      fragment"
            " NameFragment on Hero {\n        nonNullName\n      }\n    "
        ),
        '{"hero":{"name":"Luke","id":1,"nonNullName":null}}',
        [
            '{"data":{"hero":{"id":"1"}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
            (
                '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"Cannot'
                " return null for non-nullable field"
                ' Hero.nonNullName.","locations":[{"line":9,"column":9}],"path":["hero","nonNullName"]}]}]}'
            ),
        ],
    )


def test_handles_non_nullable_errors_thrown_outside_deferred_fragments() raises:
    """Handles non-nullable errors thrown outside deferred fragments."""
    _expect(
        (
            "\n      query HeroNameQuery {\n        hero {\n         "
            " nonNullName\n          ...NameFragment @defer\n        }\n     "
            " }\n      fragment NameFragment on Hero {\n        id\n     "
            " }\n    "
        ),
        '{"hero":{"name":"Luke","id":1,"nonNullName":null}}',
        [
            (
                '{"errors":[{"message":"Cannot return null for non-nullable'
                " field"
                ' Hero.nonNullName.","locations":[{"line":4,"column":11}],"path":["hero","nonNullName"]}],"data":{"hero":null}}'
            ),
        ],
    )


def test_handles_async_non_nullable_errors_thrown_in_deferred_fragments() raises:
    """Handles async non-nullable errors thrown in deferred fragments."""
    _expect(
        (
            "\n      query HeroNameQuery {\n        hero {\n          id\n     "
            "     ...NameFragment @defer\n        }\n      }\n      fragment"
            " NameFragment on Hero {\n        nonNullName\n      }\n    "
        ),
        '{"hero":{"name":"Luke","id":1,"nonNullName":null}}',
        [
            '{"data":{"hero":{"id":"1"}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
            (
                '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":"Cannot'
                " return null for non-nullable field"
                ' Hero.nonNullName.","locations":[{"line":9,"column":9}],"path":["hero","nonNullName"]}]}]}'
            ),
        ],
    )


def test_returns_payloads_in_correct_order() raises:
    """Returns payloads in correct order."""
    _expect(
        (
            "\n      query HeroNameQuery {\n        hero {\n          id\n     "
            "     ...NameFragment @defer\n        }\n      }\n      fragment"
            " NameFragment on Hero {\n        name\n        friends {\n        "
            "  ...NestedFragment @defer\n        }\n      }\n      fragment"
            " NestedFragment on Friend {\n        name\n      }\n    "
        ),
        '{"hero":{"name":"slow","id":1}}',
        [
            '{"data":{"hero":{"id":"1"}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","data":{"name":"slow","friends":null}}],"completed":[{"id":"0"}]}',
        ],
    )


def test_returns_payloads_from_synchronous_data_in_correct_order() raises:
    """Returns payloads from synchronous data in correct order."""
    _expect(
        (
            "\n      query HeroNameQuery {\n        hero {\n          id\n     "
            "     ...NameFragment @defer\n        }\n      }\n      fragment"
            " NameFragment on Hero {\n        name\n        friends {\n        "
            "  ...NestedFragment @defer\n        }\n      }\n      fragment"
            " NestedFragment on Friend {\n        name\n      }\n    "
        ),
        '{"hero":{"name":"Luke","id":1}}',
        [
            '{"data":{"hero":{"id":"1"}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}',
            '{"hasNext":false,"incremental":[{"id":"0","data":{"name":"Luke","friends":null}}],"completed":[{"id":"0"}]}',
        ],
    )


def test_filters_deferred_payloads_when_a_list_item_returned_by_an_async_iterab() raises:
    """Filters deferred payloads when a list item returned by an async iterable is nulled.
    """
    _expect(
        (
            "\n      query {\n        hero {\n          friends {\n           "
            " nonNullName\n            ...NameFragment @defer\n          }\n   "
            "     }\n      }\n      fragment NameFragment on Friend {\n       "
            " name\n      }\n    "
        ),
        '{"hero":{"name":"Luke","id":1,"friends":{"__stream":"[{\\"name\\":\\"Han\\",\\"id\\":2,\\"nonNullName\\":null}]"}}}',
        [
            (
                '{"errors":[{"message":"Cannot return null for non-nullable'
                " field"
                ' Friend.nonNullName.","locations":[{"line":5,"column":13}],"path":["hero","friends",0,"nonNullName"]}],"data":{"hero":{"friends":[null]}}}'
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Projection plan snapshot tests.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/executor/projection/plan/merge.rs`. Each test prints the
merged projection plan and compares it with the upstream `insta`
snapshot.
"""

from _exec_harness import projection_plan_text
from _fixtures.projection_schemas import schema_1, schema_2
from std.testing import TestSuite, assert_equal


def test_child_scopes_covering_all_outputs_are_pruned() raises:
    var sdl = String(
        """
type Query { node: Node }
interface Node { id: ID!, item: Item }
type A implements Node { id: ID!, item: Item }
type B implements Node { id: ID!, item: Item }
type Item { id: ID! }
"""
    )
    var rendered = projection_plan_text(
        sdl,
        (
            "query Example { node { ... on A { item { id } } ... on B { item {"
            " id } } } }"
        ),
    )
    assert_equal(rendered.count("type guard"), 2)
    assert_equal("id" in rendered, True)


def test_simple_concrete_mixed_fields_defs() raises:
    assert_equal(
        projection_plan_text(
            schema_1(),
            "{ concrete { id test someEnum inner { inner } } }",
        ),
        """concrete: {
  selections:
    id: {
    }
    test: {
    }
    someEnum: {
      conditions: EnumValues(TEST)
    }
    inner: {
      selections:
        inner: {
        }
    }
}""",
    )


def test_inline_fragment_on_concrete_type_with_dups() raises:
    assert_equal(
        projection_plan_text(
            schema_1(),
            """{
  concrete {
    ... on ConcreteType { id inner { inner } }
    test
    someEnum
    inner { inner }
  }
}""",
        ),
        """concrete: {
  selections:
    id: {
    }
    inner: {
      selections:
        inner: {
        }
    }
    test: {
    }
    someEnum: {
      conditions: EnumValues(TEST)
    }
}""",
    )


def test_union_disjoint_fragments_kept_per_type() raises:
    assert_equal(
        projection_plan_text(
            schema_1(),
            """{
  search {
    __typename
    ... on Article { meta { title wordCount } }
    ... on Video { meta { title arch } }
  }
}""",
        ),
        """search: {
  conditions: FieldType(OneOf(Article, SearchResult, Video))
  selections:
    __typename: {
    }
    meta: {
      type guard: Exact(Article)
      selections:
        title: {
        }
        wordCount: {
        }
    }
    meta: {
      type guard: Exact(Video)
      selections:
        title: {
        }
        arch: {
        }
    }
}""",
    )


def test_interface_overlapping_guard_splits_per_type() raises:
    assert_equal(
        projection_plan_text(
            schema_1(),
            "{ feed { meta { title } ... on Article { meta { wordCount } } } }",
        ),
        """feed: {
  conditions: FieldType(OneOf(Article, Content, Photo, Video))
  selections:
    meta: {
      type guard: Exact(Article)
      selections:
        title: {
        }
        wordCount: {
        }
    }
    meta: {
      type guard: Exact(Photo)
      selections:
        title: {
        }
    }
    meta: {
      type guard: Exact(Video)
      selections:
        title: {
        }
    }
}""",
    )


def test_same_guard_fragments_merge_into_one() raises:
    assert_equal(
        projection_plan_text(
            schema_1(),
            """{
  search {
    ... on Article { meta { title } }
    ... on Article { meta { title } }
  }
}""",
        ),
        """search: {
  conditions: FieldType(OneOf(Article, SearchResult, Video))
  selections:
    meta: {
      type guard: Exact(Article)
      selections:
        title: {
        }
    }
}""",
    )


def test_field_order_when_grouping_with_fragments() raises:
    assert_equal(
        projection_plan_text(
            schema_2(),
            (
                "query FieldOrder { animal { name id ... on Dog { id nickname"
                " } } }"
            ),
        ),
        """animal: {
  conditions: FieldType(OneOf(Animal, Cat, Dog, Pet))
  selections:
    name: {
    }
    id: {
      type guard: Exact(Cat)
    }
    id: {
      type guard: Exact(Dog)
    }
    nickname: {
      type guard: Exact(Dog)
    }
}""",
    )


def test_multiple_aliases() raises:
    assert_equal(
        projection_plan_text(
            schema_2(),
            """query AliasFanout {
  pet {
    ... on Dog {
      kg: weight(unit: KG)
      lb: weight(unit: LB)
      g:  weight(unit: G)
    }
    ... on Cat {
      kg: weight(unit: KG)
    }
  }
}""",
        ),
        """pet: {
  conditions: FieldType(OneOf(Cat, Dog, Pet))
  selections:
    kg (alias for weight) {
      type guard: Exact(Dog)
    }
    kg (alias for weight) {
      type guard: Exact(Cat)
    }
    lb (alias for weight) {
      type guard: Exact(Dog)
    }
    g (alias for weight) {
      type guard: Exact(Dog)
    }
}""",
    )


def test_nested_redundant_fragments() raises:
    assert_equal(
        projection_plan_text(
            schema_2(),
            """query M_IdentityConditions {
  pet { ... on Pet { ... on Pet { name ... on Animal { id } } } }
}""",
        ),
        """pet: {
  conditions: FieldType(OneOf(Cat, Dog, Pet))
  selections:
    name: {
    }
    id: {
      type guard: Exact(Cat)
    }
    id: {
      type guard: Exact(Dog)
    }
}""",
    )


def test_directive_on_named_fragment_spread_with_field_merged_across_two_fragments() raises:
    assert_equal(
        projection_plan_text(
            schema_2(),
            """query SpreadDirective($withName: Boolean!, $deep: Boolean!) {
  node {
    id
    ...AnimalBits @include(if: $withName)
    ... on Dog @skip(if: $deep) { nickname }
  }
}
fragment AnimalBits on Animal {
  name
  ... on Dog { nickname }
}""",
        ),
        """node: {
  conditions: FieldType(OneOf(Animal, Cat, Dog, Node, Owner, Pet, Robot))
  selections:
    id: {
    }
    name: {
      type guard: Exact(Cat)
      conditions: Include(if: $withName)
    }
    name: {
      type guard: Exact(Dog)
      conditions: Include(if: $withName)
    }
    nickname: {
      type guard: Exact(Dog)
      conditions: (Include(if: $withName) OR Skip(if: $deep))
    }
}""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

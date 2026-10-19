# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Projection plan cases beyond the upstream snapshots.

Covers Hive Router `1a29df9`
`bin/router/src/executor/projection/plan/`: `ir.rs` (type sets and
conditions), `collect.rs` (`Collector`), `merge.rs` (`Merger`),
`tables.rs` and `display.rs`. Upstream has no test for most of these
cases. The plan tests print the plan of a normalized operation on a small
supergraph. The condition tests call `ProjectionTables` directly, for the
combinations that a normalized operation does not make.
"""

from _exec_harness import projection_plan_text
from _fixtures.projection_schemas import schema_2
from gql_router.exec_projection_plan import (
    ALWAYS,
    NO_SET,
    CondKind,
    ProjField,
    ProjectionPlan,
    ProjectionTables,
)
from gql_router.schema_metadata import FieldNullability
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_true,
)


def _prelude() -> String:
    """Return the `@link` and `@join__*` definitions."""
    return String(
        """schema
  @link(url: "https://specs.apollo.dev/link/v1.0")
  @link(url: "https://specs.apollo.dev/join/v0.3", for: EXECUTION) {
  query: Query
  mutation: Mutation
  subscription: Subscription
}

directive @join__enumValue(graph: join__Graph!) repeatable on ENUM_VALUE

directive @join__graph(name: String!, url: String!) on ENUM_VALUE

directive @join__field(
  graph: join__Graph
  requires: join__FieldSet
  provides: join__FieldSet
  type: String
  external: Boolean
  override: String
  usedOverridden: Boolean
) repeatable on FIELD_DEFINITION | INPUT_FIELD_DEFINITION

directive @join__implements(
  graph: join__Graph!
  interface: String!
) repeatable on OBJECT | INTERFACE

directive @join__type(
  graph: join__Graph!
  key: join__FieldSet
  extension: Boolean! = false
  resolvable: Boolean! = true
  isInterfaceObject: Boolean! = false
) repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT | SCALAR

directive @join__unionMember(
  graph: join__Graph!
  member: String!
) repeatable on UNION

scalar join__FieldSet

directive @link(
  url: String
  as: String
  for: link__Purpose
  import: [link__Import]
) repeatable on SCHEMA

scalar link__Import

enum link__Purpose {
  SECURITY
  EXECUTION
}

enum join__Graph {
  LOCAL @join__graph(name: "local", url: "")
}
"""
    )


def _sdl() -> String:
    """Return a supergraph with covariant fields, an interface without
    object types, an interface without implementations, an enum without
    values and a union without members."""
    return _prelude() + String(
        """
type Query @join__type(graph: LOCAL) {
  node: Node
  thing: Thing
  lonely: Lonely
  empty: Empty
  user: User
  extra: Extra
}

type Mutation @join__type(graph: LOCAL) {
  ping: Int
}

type Subscription @join__type(graph: LOCAL) {
  tick: Int
}

interface Node @join__type(graph: LOCAL) {
  id: ID!
  item: Item
}

interface Thing @join__type(graph: LOCAL) {
  id: ID!
}

type A implements Node & Thing
  @join__type(graph: LOCAL)
  @join__implements(graph: LOCAL, interface: "Node")
  @join__implements(graph: LOCAL, interface: "Thing") {
  id: ID!
  item: ItemX
  a: Int
}

type B implements Node & Thing
  @join__type(graph: LOCAL)
  @join__implements(graph: LOCAL, interface: "Node")
  @join__implements(graph: LOCAL, interface: "Thing") {
  id: ID!
  item: ItemB
}

type D implements Thing
  @join__type(graph: LOCAL)
  @join__implements(graph: LOCAL, interface: "Thing") {
  id: ID!
  item: Item
}

interface Item @join__type(graph: LOCAL) {
  id: ID!
}

interface ItemX implements Item
  @join__type(graph: LOCAL)
  @join__implements(graph: LOCAL, interface: "Item") {
  id: ID!
}

type ItemA implements ItemX & Item
  @join__type(graph: LOCAL)
  @join__implements(graph: LOCAL, interface: "ItemX")
  @join__implements(graph: LOCAL, interface: "Item") {
  id: ID!
}

type ItemB implements Item
  @join__type(graph: LOCAL)
  @join__implements(graph: LOCAL, interface: "Item") {
  id: ID!
}

interface Lonely @join__type(graph: LOCAL) {
  id: ID!
}

interface Sub implements Lonely
  @join__type(graph: LOCAL)
  @join__implements(graph: LOCAL, interface: "Lonely") {
  id: ID!
}

interface Empty @join__type(graph: LOCAL) {
  id: ID!
  user: User
}

type User @join__type(graph: LOCAL) {
  id: ID!
}

enum Nothing @join__type(graph: LOCAL)

union NoMember @join__type(graph: LOCAL)

type Extra @join__type(graph: LOCAL) {
  nothing: Nothing
  none: NoMember
}
"""
    )


comptime _VARIABLES = "query($y: Boolean!, $z: Boolean!) "
"""The variable definitions of the operations with directives."""


def _plan(query: String) raises -> String:
    """Return the plan text of an operation on `_sdl`."""
    return projection_plan_text(_sdl(), query)


# --- plans of normalized operations ---------------------------------------


def test_mutation_and_subscription_roots() raises:
    assert_equal(_plan("mutation { ping }"), "ping: {\n}")
    assert_equal(_plan("subscription { tick }"), "tick: {\n}")


def test_introspection_fields_are_left_out() raises:
    var user = String("user: {\n  selections:\n    id: {\n    }\n}")
    assert_equal(_plan("{ __schema { queryType { name } } user { id } }"), user)
    assert_equal(_plan("{ __schema { queryType { name } } }"), "")
    assert_equal(
        _plan(
            _VARIABLES
            + "{ ... on Query @include(if: $y) { __schema { queryType { name"
            " } } }"
            + " user { id } }"
        ),
        user,
    )


def test_field_with_only_skipped_children_has_empty_selections() raises:
    assert_equal(
        _plan("{ user { id @skip(if: true) } }"), "user: {\n  selections:\n}"
    )
    assert_equal(
        _plan("{ node { ... on A { item { id @skip(if: true) } } } }"),
        """node: {
  conditions: FieldType(OneOf(A, B, Node))
  selections:
    item: {
      type guard: Exact(A)
      conditions: FieldType(OneOf(ItemA, ItemX))
      selections:
    }
}""",
    )


def test_interface_without_implementations() raises:
    assert_equal(
        _plan("{ empty { id user { id } } }"),
        """empty: {
  conditions: FieldType(Exact(Empty))
  selections:
    id: {
    }
    user: {
      selections:
        id: {
        }
    }
}""",
    )


def test_enum_without_values_and_union_without_members() raises:
    assert_equal(
        _plan("{ extra { nothing } }"),
        """extra: {
  selections:
    nothing: {
      conditions: EnumValues()
    }
}""",
    )
    assert_equal(
        _plan(
            _VARIABLES
            + "{ extra { none { __typename"
            + " ... on NoMember @include(if: $y) { __typename } } } }"
        ),
        """extra: {
  selections:
    none: {
      conditions: FieldType(Exact(NoMember))
      selections:
    }
}""",
    )


def test_include_on_a_field_reaches_its_fragment_fields() raises:
    assert_equal(
        _plan(_VARIABLES + "{ node @include(if: $y) { ... on A { a } } }"),
        """node: {
  conditions: (FieldType(OneOf(A, B, Node)) AND Include(if: $y))
  selections:
    a: {
      type guard: Exact(A)
      conditions: Include(if: $y)
    }
}""",
    )


def test_fragment_directive_is_inherited_by_children() raises:
    assert_equal(
        _plan(
            _VARIABLES
            + "{ node { ... on A @include(if: $y) { item { id } } } }"
        ),
        """node: {
  conditions: FieldType(OneOf(A, B, Node))
  selections:
    item: {
      type guard: Exact(A)
      conditions: (Include(if: $y) AND FieldType(OneOf(ItemA, ItemX)))
      selections:
        id: {
          type guard: OneOf(ItemA, ItemX)
          conditions: Include(if: $y)
        }
    }
}""",
    )


def test_merged_child_keeps_either_directive() raises:
    assert_equal(
        _plan(
            _VARIABLES
            + "{ thing { ... on D { item {"
            + " ... on ItemA @include(if: $y) { id }"
            + " ... on ItemA @skip(if: $z) { id } } } } }"
        ),
        """thing: {
  conditions: FieldType(OneOf(A, B, D, Thing))
  selections:
    item: {
      type guard: Exact(D)
      conditions: FieldType(OneOf(Item, ItemA, ItemB, ItemX))
      selections:
        id: {
          type guard: Exact(ItemA)
          conditions: (Include(if: $y) OR Skip(if: $z))
        }
    }
}""",
    )


def test_unconditional_variant_absorbs_conditional_one() raises:
    var expected = String(
        """node: {
  conditions: FieldType(OneOf(A, B, Node))
  selections:
    id: {
      type guard: Exact(A)
    }
    id: {
      type guard: Exact(B)
    }
}"""
    )
    assert_equal(
        _plan(_VARIABLES + "{ node { id ... on A @include(if: $y) { id } } }"),
        expected,
    )
    # The variant with a multi-type scope comes first.
    assert_equal(
        _plan(
            _VARIABLES + "{ node { ... on Node @include(if: $y) { id } id } }"
        ),
        expected,
    )


def test_two_ambiguous_keys_share_the_object_types() raises:
    assert_equal(
        _plan(
            _VARIABLES
            + "{ node { id item { id }"
            + " ... on A @include(if: $y) { id item { id } } } }"
        ),
        """node: {
  conditions: FieldType(OneOf(A, B, Node))
  selections:
    id: {
      type guard: Exact(A)
    }
    id: {
      type guard: Exact(B)
    }
    item: {
      type guard: Exact(A)
      conditions: (FieldType(OneOf(Item, ItemA, ItemB, ItemX)) OR (Include(if: $y) AND FieldType(OneOf(ItemA, ItemX))))
      selections:
        id: {
          type guard: Exact(ItemA)
        }
    }
    item: {
      type guard: Exact(B)
      conditions: FieldType(OneOf(Item, ItemA, ItemB, ItemX))
      selections:
        id: {
        }
    }
}""",
    )


def test_mixed_outputs_resolve_to_the_declared_type() raises:
    assert_equal(
        _plan(
            _VARIABLES
            + "{ node { ... on Node @include(if: $y) { item { id } } } }"
        ),
        """node: {
  conditions: FieldType(OneOf(A, B, Node))
  selections:
    item: {
      type guard: OneOf(A, B, Node)
      conditions: (Include(if: $y) AND FieldType(OneOf(Item, ItemA, ItemB, ItemX)))
      selections:
        id: {
          type guard: OneOf(Item, ItemA, ItemB, ItemX)
          conditions: Include(if: $y)
        }
    }
}""",
    )


def test_mismatched_shapes_keep_the_kept_value() raises:
    # The router does not validate operations, so one response key can
    # name a field with children and a leaf field.
    assert_equal(
        _plan(
            _VARIABLES
            + "{ node { x: item { id } ... on A @include(if: $y) { x: id } } }"
        ),
        """node: {
  conditions: FieldType(OneOf(A, B, Node))
  selections:
    x (alias for item) {
      type guard: Exact(A)
      conditions: (FieldType(OneOf(Item, ItemA, ItemB, ItemX)) OR Include(if: $y))
      selections:
        id: {
        }
    }
    x (alias for item) {
      type guard: Exact(B)
      conditions: FieldType(OneOf(Item, ItemA, ItemB, ItemX))
      selections:
        id: {
        }
    }
}""",
    )
    assert_equal(
        projection_plan_text(
            schema_2(),
            "{ animal { ... on Dog { x: bestFriend { name } } x: name } }",
        ),
        """animal: {
  conditions: FieldType(OneOf(Animal, Cat, Dog, Pet))
  selections:
    x (alias for name) {
      type guard: Exact(Cat)
    }
    x (alias for bestFriend) {
      type guard: Exact(Dog)
      selections:
        name: {
          type guard: OneOf(Animal, Cat, Dog, Pet)
        }
    }
}""",
    )


def test_interface_without_object_types_drops_ambiguous_fields() raises:
    assert_equal(
        _plan(
            _VARIABLES
            + "{ lonely { id ... on Lonely @include(if: $y) { id } } }"
        ),
        """lonely: {
  conditions: FieldType(OneOf(Lonely, Sub))
  selections:
}""",
    )


# --- type sets and conditions ---------------------------------------------


def test_cond_kind_is_valid() raises:
    assert_true(CondKind.ALWAYS.is_valid())
    assert_true(CondKind.AND.is_valid())
    assert_false(CondKind(8).is_valid())


def test_intern_sorted_sorts_and_drops_repeats() raises:
    var tables = ProjectionTables()
    var ab = tables.intern_sorted(["b", "a", "b"])
    assert_equal(len(tables.sets[ab]), 2)
    assert_equal(tables.sets[ab][0], "a")
    assert_equal(tables.sets[ab][1], "b")
    assert_equal(tables.intern_sorted(["a", "b"]), ab)
    var empty = tables.intern_sorted(List[String]())
    assert_equal(len(tables.sets[empty]), 0)
    assert_true(tables.exact("a") != ab)


def test_is_subset_of() raises:
    var tables = ProjectionTables()
    var a = tables.exact("a")
    var ab = tables.intern_sorted(["a", "b"])
    var empty = tables.intern_sorted(List[String]())
    assert_true(tables.is_subset_of(a, ab))
    assert_false(tables.is_subset_of(ab, a))
    assert_true(tables.is_subset_of(empty, a))


def test_union_and_intersect() raises:
    var tables = ProjectionTables()
    var ab = tables.intern_sorted(["a", "b"])
    var bc = tables.intern_sorted(["b", "c"])
    var empty = tables.intern_sorted(List[String]())
    assert_equal(tables.union(ab, ab), ab)
    assert_equal(tables.union(ab, bc), tables.intern_sorted(["a", "b", "c"]))
    assert_equal(tables.intersect(ab, ab), ab)
    assert_equal(tables.intersect(ab, bc), tables.exact("b"))
    assert_equal(tables.intersect(empty, ab), empty)


def test_or_of_conditions() raises:
    var tables = ProjectionTables()
    var ab = tables.intern_sorted(["a", "b"])
    var bc = tables.intern_sorted(["b", "c"])
    var x = tables.variable_cond(CondKind.INCLUDE_IF, "x")
    var y = tables.variable_cond(CondKind.SKIP_IF, "y")
    assert_equal(tables.or_(x, x), x)
    assert_equal(tables.or_(ALWAYS, x), ALWAYS)
    assert_equal(tables.or_(x, ALWAYS), ALWAYS)
    var pab = tables.set_cond(CondKind.PARENT_TYPE, ab)
    var pbc = tables.set_cond(CondKind.PARENT_TYPE, bc)
    assert_equal(
        tables.or_(pab, pbc),
        tables.set_cond(CondKind.PARENT_TYPE, tables.union(ab, bc)),
    )
    assert_equal(
        tables.and_(pab, pbc),
        tables.set_cond(CondKind.PARENT_TYPE, tables.exact("b")),
    )
    assert_true(tables.conds[tables.or_(x, y)].kind == CondKind.OR)


def test_inherited_by_child_keeps_variable_checks() raises:
    var tables = ProjectionTables()
    var pab = tables.set_cond(
        CondKind.PARENT_TYPE, tables.intern_sorted(["a", "b"])
    )
    var x = tables.variable_cond(CondKind.INCLUDE_IF, "x")
    var y = tables.variable_cond(CondKind.SKIP_IF, "y")
    assert_equal(tables.inherited_by_child(tables.and_(pab, x)), x)
    var either = tables.or_(x, y)
    assert_equal(tables.inherited_by_child(either), either)
    assert_equal(tables.inherited_by_child(y), y)
    assert_equal(tables.inherited_by_child(pab), ALWAYS)


def test_without_redundant_parent_scope() raises:
    var tables = ProjectionTables()
    var a = tables.exact("a")
    var pab = tables.set_cond(
        CondKind.PARENT_TYPE, tables.intern_sorted(["a", "b"])
    )
    var pbc = tables.set_cond(
        CondKind.PARENT_TYPE, tables.intern_sorted(["b", "c"])
    )
    var x = tables.variable_cond(CondKind.INCLUDE_IF, "x")
    var y = tables.variable_cond(CondKind.SKIP_IF, "y")
    assert_equal(tables.without_redundant_parent_scope(x, NO_SET), x)
    assert_equal(
        tables.without_redundant_parent_scope(tables.and_(pab, x), a), x
    )
    assert_equal(
        tables.without_redundant_parent_scope(
            tables.or_(tables.and_(pab, x), y), a
        ),
        tables.or_(x, y),
    )
    assert_equal(tables.without_redundant_parent_scope(pbc, a), pbc)


def test_parent_type_set() raises:
    var tables = ProjectionTables()
    var ab = tables.intern_sorted(["a", "b"])
    var bc = tables.intern_sorted(["b", "c"])
    var pab = tables.set_cond(CondKind.PARENT_TYPE, ab)
    var pbc = tables.set_cond(CondKind.PARENT_TYPE, bc)
    var x = tables.variable_cond(CondKind.INCLUDE_IF, "x")
    var y = tables.variable_cond(CondKind.SKIP_IF, "y")
    assert_equal(tables.parent_type_set(pab), ab)
    assert_equal(tables.parent_type_set(x), NO_SET)
    assert_equal(tables.parent_type_set(tables.and_(x, pab)), ab)
    assert_equal(tables.parent_type_set(tables.and_(pab, x)), ab)
    assert_equal(
        tables.parent_type_set(tables.and_(tables.and_(pab, x), pbc)),
        tables.exact("b"),
    )
    assert_equal(
        tables.parent_type_set(
            tables.or_(tables.and_(pab, x), tables.and_(pbc, y))
        ),
        tables.union(ab, bc),
    )


# --- display --------------------------------------------------------------


def test_text_writes_a_parent_type_condition() raises:
    var plan = ProjectionPlan()
    assert_true(plan.is_empty())
    var ab = plan.tables.intern_sorted(["B", "A"])
    var condition = plan.tables.and_(
        plan.tables.set_cond(CondKind.PARENT_TYPE, ab),
        plan.tables.set_cond(CondKind.PARENT_TYPE, plan.tables.exact("A")),
    )
    var either = plan.tables.or_(
        plan.tables.set_cond(CondKind.PARENT_TYPE, ab),
        plan.tables.variable_cond(CondKind.SKIP_IF, "s"),
    )
    plan.fields.append(
        ProjField(
            "f",
            "f",
            False,
            FieldNullability.type_name(),
            NO_SET,
            condition,
            False,
            List[Int](),
        )
    )
    plan.fields.append(
        ProjField(
            "g",
            "g",
            False,
            FieldNullability.type_name(),
            NO_SET,
            either,
            False,
            List[Int](),
        )
    )
    plan.roots.append(0)
    plan.roots.append(1)
    assert_false(plan.is_empty())
    assert_equal(
        plan.text(),
        "f: {\n  conditions: ParentType(Exact(A))\n}\n"
        + "g: {\n  conditions: (ParentType(OneOf(A, B)) OR Skip(if: $s))\n}\n",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

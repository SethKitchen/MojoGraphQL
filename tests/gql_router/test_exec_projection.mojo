# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Response projection tests.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/executor/projection/response.rs` and
`bin/router/src/executor/projection/plan/collect.rs`.

`authorization_rewrite_nulls_single_abstract_variant` is not ported: it
tests `ProjectionPlan::rewrite`, which this port does not have.
"""

from _exec_harness import metadata_of, project
from gql_router.exec_projection_plan import ProjectionPlan
from gql_router.planner import Planner
from gql_router.schema_metadata import SHAPE_LIST, SHAPE_NON_NULL
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_project_scalars_with_object_value() raises:
    var sdl = String(
        """type Query { metadatas: [Metadata!]! }
scalar JSON
type Metadata { id: ID!, timestamp: String!, data: JSON }"""
    )
    var data = String(
        """{
  "__typename": "Query",
  "metadatas": [
    {
      "__typename": "Metadata",
      "id": "meta1",
      "timestamp": "2024-01-01T00:00:00Z",
      "data": { "float": 41.5, "int": -42, "str": "value1", "unsigned": 123 }
    },
    { "__typename": "Metadata", "id": "meta2", "data": null }
  ]
}"""
    )
    assert_equal(
        project(sdl, "query GetMetadata { metadatas { id data } }", data),
        '{"data":{"metadatas":[{"id":"meta1","data":{"float":41.5,"int":-42,'
        + '"str":"value1","unsigned":123}},{"id":"meta2","data":null}]}}',
    )


def test_duplicate_selections_in_merged_plans() raises:
    var sdl = String(
        """interface Node { id: ID! }
type A implements Node { id: ID, children: [AChild] }
type B implements Node { id: ID!, children: [BChild] }
type AChild { id: ID }
type BChild { id: ID }
type Container { node: Node }
type Query { nodes: [Container] }"""
    )
    var data = String(
        '{"__typename":"Query","nodes":[{"node":{"__typename":"A","children":[]}},'
        + '{"node":{"__typename":"B","children":[{"id":"b_child_1"}]}}]}'
    )
    assert_equal(
        project(
            sdl,
            "query { nodes { node { ... on A { children { id } } ... on B {"
            + " children { id } } } } }",
            data,
        ),
        '{"data":{"nodes":[{"node":{"children":[]}},{"node":{"children":'
        + '[{"id":"b_child_1"}]}}]}}',
    )


def test_unconditional_overlap_survives_false_directive_at_execution() raises:
    var sdl = String(
        """interface Node { id: ID! }
type User implements Node { id: ID!, name: String }
type Query { node: Node }"""
    )
    assert_equal(
        project(
            sdl,
            "query Example($show: Boolean!) { node { ... on User { label: name"
            + " @include(if: $show) } ... on User { label: name } } }",
            '{"node":{"__typename":"User","label":"Ada"}}',
            '{"show":false}',
        ),
        '{"data":{"node":{"label":"Ada"}}}',
    )


comptime MATRIX = """type Query {
  strict: [[Foo!]!]!
  nullable: [[Foo]]
  boundary: [[Foo!]!]
  mixed: [Foo!]!
}
type Foo { name: String!, nick: String }"""
"""The schema of the nullability matrix."""


def _shape_of(field: String) raises -> List[UInt8]:
    var planner = Planner(MATRIX)
    var operation = planner.normalize("query { " + field + " { name nick } }")
    var built = ProjectionPlan.from_operation(
        planner.store, operation, metadata_of(MATRIX)
    )
    assert_equal(len(built[1].roots), 1)
    return built[1].fields[built[1].roots[0]].nullability.shape.copy()


def _case(field: String, input: String, expected: String) raises:
    assert_equal(
        project(
            MATRIX,
            "query { " + field + " { name nick } }",
            '{"__typename":"Query","' + field + '":' + input + "}",
        ),
        expected,
    )


def test_nested_list_nullability_matrix() raises:
    comptime NN_LIST = SHAPE_LIST | SHAPE_NON_NULL
    assert_true(_shape_of("strict") == [NN_LIST, NN_LIST, SHAPE_NON_NULL])
    assert_true(_shape_of("nullable") == [SHAPE_LIST, SHAPE_LIST, UInt8(0)])
    assert_true(_shape_of("boundary") == [SHAPE_LIST, NN_LIST, SHAPE_NON_NULL])
    assert_true(_shape_of("mixed") == [NN_LIST, SHAPE_NON_NULL])
    var valid = String('{"__typename":"Foo","name":"a","nick":"b"}')
    var nick_null = String('{"__typename":"Foo","name":"a","nick":null}')
    var name_null = String('{"__typename":"Foo","name":null,"nick":"b"}')
    _case(
        "strict",
        "[[" + valid + "]]",
        '{"data":{"strict":[[{"name":"a","nick":"b"}]]}}',
    )
    _case(
        "strict",
        "[[" + nick_null + "]]",
        '{"data":{"strict":[[{"name":"a","nick":null}]]}}',
    )
    _case("strict", "[[" + name_null + "]]", '{"data":null}')
    _case("strict", "[[null]]", '{"data":null}')
    _case("strict", "[null]", '{"data":null}')
    _case("strict", "null", '{"data":null}')
    _case("strict", "[[" + valid + ",null]]", '{"data":null}')
    _case("strict", "[[" + valid + "],null]", '{"data":null}')
    _case(
        "nullable",
        "[[" + valid + "]]",
        '{"data":{"nullable":[[{"name":"a","nick":"b"}]]}}',
    )
    _case(
        "nullable",
        "[[" + nick_null + "]]",
        '{"data":{"nullable":[[{"name":"a","nick":null}]]}}',
    )
    _case("nullable", "[[" + name_null + "]]", '{"data":{"nullable":[[null]]}}')
    _case("nullable", "[[null]]", '{"data":{"nullable":[[null]]}}')
    _case(
        "nullable",
        "[[" + valid + "],null]",
        '{"data":{"nullable":[[{"name":"a","nick":"b"}],null]}}',
    )
    _case("nullable", "null", '{"data":{"nullable":null}}')
    _case("boundary", "[[" + name_null + "]]", '{"data":{"boundary":null}}')
    _case("boundary", "[null]", '{"data":{"boundary":null}}')
    _case(
        "mixed",
        "[" + valid + "]",
        '{"data":{"mixed":[{"name":"a","nick":"b"}]}}',
    )
    _case(
        "mixed",
        "[" + nick_null + "]",
        '{"data":{"mixed":[{"name":"a","nick":null}]}}',
    )
    _case("mixed", "[" + name_null + "]", '{"data":null}')
    _case("mixed", "[null]", '{"data":null}')
    _case("mixed", "null", '{"data":null}')
    _case("mixed", "[" + valid + ",null]", '{"data":null}')


comptime USERS = """type Query { strictUser: User!, nullableUser: User }
type User { id: ID!, email: String! }"""
"""The schema of `missing_non_null_field_bubbles`."""


def test_missing_non_null_field_bubbles() raises:
    assert_equal(
        project(
            USERS,
            "query { strictUser { id email } }",
            '{"__typename":"Query","strictUser":{"__typename":"User","id":"1"}}',
        ),
        '{"data":null}',
    )
    assert_equal(
        project(
            USERS,
            "query { nullableUser { id email } }",
            '{"__typename":"Query","nullableUser":{"__typename":"User","id":"1"}}',
        ),
        '{"data":{"nullableUser":null}}',
    )
    assert_equal(
        project(
            USERS,
            "query { strictUser { id email } }",
            '{"__typename":"Query","strictUser":{"__typename":"User","id":"1",'
            + '"email":"a@x.test"}}',
        ),
        '{"data":{"strictUser":{"id":"1","email":"a@x.test"}}}',
    )


def test_empty_projection_returns_empty_data_object() raises:
    var sdl = String("type Query { foo: String }")
    var planner = Planner(sdl)
    var static_op = planner.normalize("query { foo @skip(if: true) }")
    var static_plan = ProjectionPlan.from_operation(
        planner.store, static_op, metadata_of(sdl)
    )
    assert_true(static_plan[1].is_empty())
    var query = String("query Example($skip: Boolean!) { foo @skip(if: $skip) }")
    var variable_op = planner.normalize(query)
    var variable_plan = ProjectionPlan.from_operation(
        planner.store, variable_op, metadata_of(sdl)
    )
    assert_false(variable_plan[1].is_empty())
    assert_equal(
        project(sdl, "query { foo @skip(if: true) }", '{"__typename":"Query"}'),
        '{"data":{}}',
    )
    assert_equal(
        project(sdl, query, '{"__typename":"Query","foo":"x"}', '{"skip":true}'),
        '{"data":{}}',
    )


def test_covariant_overrides_resolve_to_the_declared_parent_type() raises:
    var sdl = String(
        """interface Node { id: ID!, item: Item }
type A implements Node { id: ID!, item: ItemA }
type B implements Node { id: ID!, item: ItemB }
interface Item { id: ID! }
type ItemA implements Item { id: ID! }
type ItemB implements Item { id: ID! }
type Query { node: Node }"""
    )
    var schema = metadata_of(sdl)
    var plan = ProjectionPlan()
    var node_types = plan._type_set(schema, "Node")
    assert_true(len(plan.tables.sets[node_types]) > 1)
    assert_equal(
        plan._child_parent_type(schema, "Node", node_types, "item"), "Item"
    )
    assert_equal(plan._child_parent_type(schema, "Node", node_types, "id"), "ID")


def test_nested_unguarded_merge_resolves_under_the_field_output_type() raises:
    var sdl = String(
        """interface Node { id: ID!, item: Item }
type A implements Node { id: ID!, item: Item }
type B implements Node { id: ID!, item: Item }
type Item { id: ID!, sub: Sub }
interface Sub { id: ID!, name: String }
type X implements Sub { id: ID!, name: String }
type Y implements Sub { id: ID!, name: String }
type Query { node: Node }"""
    )
    var query = String(
        "query Example { node { item { sub { name } } ... on A { item { sub {"
        + " ... on X { name } } } } } }"
    )
    var expected = String('{"data":{"node":{"item":{"sub":{"name":"sub-name"}}}}}')
    var pairs: List[String] = ["A", "X", "A", "Y", "B", "X"]
    var index = 0
    while index < len(pairs):
        var data = (
            '{"node":{"__typename":"'
            + pairs[index]
            + '","item":{"sub":{"__typename":"'
            + pairs[index + 1]
            + '","name":"sub-name"}}}}'
        )
        assert_equal(project(sdl, query, data), expected)
        index += 2


def test_nested_fragment_keeps_its_own_type_under_a_conditional_parent_fragment() raises:
    var sdl = String(
        """interface Node { id: ID! }
type Cat implements Node { id: ID! }
type Dog implements Node { id: ID! }
type Query { things: [Node!]! }"""
    )
    assert_equal(
        project(
            sdl,
            "query($y: Boolean!) { things { ... on Node @include(if: $y) { ..."
            + " on Cat { id } } } }",
            '{"things":[{"__typename":"Cat","id":"c1"},{"__typename":"Dog",'
            + '"id":"d1"}]}',
            '{"y":true}',
        ),
        '{"data":{"things":[{"id":"c1"},{}]}}',
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""More response projection cases: conditions, abstract types, enums,
`__typename` and null bubbling.

The cases follow `Projector::project_selection_set`, `evaluate` and
`resolve_type_name` of Hive Router `1a29df9`
`bin/router/src/executor/projection/response.rs`, beside the ported tests
in `test_exec_projection.mojo`.
"""

from _exec_harness import metadata_of, project, variables_of
from gql_json.parser import parse as parse_json
from gql_json.value import NO_NODE, JsonDocument
from gql_router.exec_projection import Outcome, project_by_operation
from gql_router.exec_projection_plan import ProjectionPlan
from gql_router.graphql_error import GraphQLError, graphql_error
from gql_router.planner import Planner
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime SDL = """type Query { user: User, node: Node, color: Color, colors: [Color!],
  grid: [[Int]], strict: Strict, list: [User!] }
interface Node { id: ID! }
type User implements Node { id: ID!, name: String, best: User }
type Bot implements Node { id: ID!, model: String }
type Strict { must: String! }
enum Color { RED GREEN }"""
"""A schema with an interface, an enum and non-null fields."""


def test_include_and_skip_follow_the_variables() raises:
    var query = String(
        "query($a: Boolean!) { user { id @include(if: $a) name @skip(if: $a) } }"
    )
    var data = String('{"user":{"id":"1","name":"Ada"}}')
    assert_equal(
        project(SDL, query, data, '{"a":true}'),
        '{"data":{"user":{"id":"1"}}}',
    )
    assert_equal(
        project(SDL, query, data, '{"a":false}'),
        '{"data":{"user":{"name":"Ada"}}}',
    )


def test_fragments_on_abstract_types_select_by_typename() raises:
    var query = String(
        "{ node { id ... on User { name } ... on Bot { model } } }"
    )
    assert_equal(
        project(SDL, query, '{"node":{"__typename":"Bot","id":"b","model":"x"}}'),
        '{"data":{"node":{"id":"b","model":"x"}}}',
    )
    assert_equal(
        project(
            SDL, query, '{"node":{"__typename":"User","id":"u","name":"n"}}'
        ),
        '{"data":{"node":{"id":"u","name":"n"}}}',
    )


def test_an_unknown_enum_value_is_null_with_an_error() raises:
    var out = project(SDL, "{ color colors }", '{"color":"BLUE","colors":["RED"]}')
    assert_equal(
        out,
        '{"data":{"color":null,"colors":["RED"]},"errors":[{"message":'
        + '"Value is not a valid enum value"}]}',
    )
    var bubbled = project(SDL, "{ colors }", '{"colors":["RED","BLUE"]}')
    # As upstream, the enum check reads a string value, not a list.
    assert_equal(bubbled, '{"data":{"colors":["RED","BLUE"]}}')


def test_typename_comes_from_the_data_or_the_schema() raises:
    assert_equal(
        project(
            SDL,
            "{ __typename user { __typename best { __typename } } }",
            '{"user":{"best":{"__typename":"User"}}}',
        ),
        '{"data":{"__typename":"Query","user":{"__typename":"User",'
        + '"best":{"__typename":"User"}}}}',
    )


def test_nulls_bubble_to_the_nearest_nullable_parent() raises:
    assert_equal(
        project(SDL, "{ strict { must } }", '{"strict":{"must":null}}'),
        '{"data":{"strict":null}}',
    )
    assert_equal(
        project(SDL, "{ strict { must } }", '{"strict":{}}'),
        '{"data":{"strict":null}}',
    )
    assert_equal(
        project(SDL, "{ list { id } }", '{"list":[{"id":"1"},null]}'),
        '{"data":{"list":null}}',
    )
    assert_equal(
        project(SDL, "{ grid }", '{"grid":[[1,null],[]]}'),
        '{"data":{"grid":[[1,null],[]]}}',
    )
    assert_equal(project(SDL, "{ user { id } }", "null"), '{"data":null}')
    assert_equal(
        project(SDL, "{ user { id } }", '{"user":{}}'),
        '{"data":{"user":null}}',
    )


def test_values_of_another_shape() raises:
    assert_equal(
        project(SDL, "{ user { id } list { id } }", '{"user":"x","list":{}}'),
        '{"data":{"user":"x","list":null}}',
    )
    assert_equal(
        project(SDL, "{ user { name } }", '{"user":{"name":true}}'),
        '{"data":{"user":{"name":true}}}',
    )


comptime PEERS = """type Query { nodes: [Node], node: Node, color: Color }
interface Node { id: ID!, peer: Node }
type User implements Node { id: ID!, name: String, peer: Node }
type Bot implements Node { id: ID! }
enum Color { RED }"""
"""A schema whose `Bot` lacks a field of its interface."""


def test_combined_conditions() raises:
    var query = String(
        "query($a: Boolean!, $b: Boolean!) { color @include(if: $a)"
        + " node { ... on User @include(if: $a) { id }"
        + " ... on User @include(if: $b) { id } } }"
    )
    var data = String('{"color":"RED","node":{"__typename":"User","id":"1"}}')
    assert_equal(
        project(PEERS, query, data, '{"a":true,"b":false}'),
        '{"data":{"color":"RED","node":{"id":"1"}}}',
    )
    assert_equal(
        project(PEERS, query, data, '{"a":false,"b":true}'),
        '{"data":{"node":{"id":"1"}}}',
    )
    assert_equal(
        project(PEERS, query, data, '{"a":false,"b":false}'),
        '{"data":{"node":{}}}',
    )


def test_a_missing_abstract_field_is_null() raises:
    assert_equal(
        project(PEERS, "{ node { id } }", "{}"), '{"data":{"node":null}}'
    )


def test_an_escaped_member_key_is_decoded() raises:
    assert_equal(
        project(PEERS, "{ color }", '{"c\\u006flor":"RED"}'),
        '{"data":{"color":"RED"}}',
    )


def test_a_type_that_the_schema_lacks_fails_the_projection() raises:
    var query = String("{ nodes { peer { ... on User { name } } } }")
    var failed = False
    try:
        _ = project(
            PEERS,
            query,
            '{"nodes":[{"__typename":"Ghost","peer":{"name":"x"}},'
            + '{"__typename":"Bot","peer":{"name":"y"}}]}',
        )
    except error:
        failed = True
        assert_equal(String(error), "Type 'Ghost' not found in schema")
    assert_true(failed)
    failed = False
    try:
        _ = project(
            PEERS, query, '{"nodes":[{"__typename":"Bot","peer":{"name":"y"}}]}'
        )
    except error:
        failed = True
        assert_equal(
            String(error), "Field 'peer' not found on type 'Bot' in schema"
        )
    assert_true(failed)


def test_a_nested_field_checks_its_parent_type() raises:
    var query = String("{ node { ... on User { peer { id } } } }")
    assert_equal(
        project(
            PEERS,
            query,
            '{"node":{"__typename":"User","peer":{"__typename":"Bot","id":"1"}}}',
        ),
        '{"data":{"node":{"peer":{"id":"1"}}}}',
    )
    assert_equal(
        project(
            PEERS,
            query,
            '{"node":{"__typename":"User","peer":{"__typename":"Ghost","id":"1"}}}',
        ),
        '{"data":{"node":{"peer":null}}}',
    )


def test_hints_follow_the_member_order() raises:
    assert_equal(
        project(
            SDL,
            "{ list { id name } }",
            '{"list":[{"id":"1","name":"a"},{"name":"b","id":"2"}]}',
        ),
        '{"data":{"list":[{"id":"1","name":"a"},{"id":"2","name":"b"}]}}',
    )


def test_an_unknown_enum_in_a_non_null_field_bubbles() raises:
    var out = project(
        "type Query { s: S } type S { c: C! } enum C { A }",
        "{ s { c } }",
        '{"s":{"c":"B"}}',
    )
    assert_equal(
        out,
        '{"data":{"s":null},"errors":[{"message":'
        + '"Value is not a valid enum value"}]}',
    )


def test_a_wide_object_grows_the_member_stack() raises:
    var data = String('{"user":{')
    for index in range(300):
        data += '"k' + String(index) + '":0,'
    data += '"id":"1"}}'
    assert_equal(project(SDL, "{ user { id } }", data), '{"data":{"user":{"id":"1"}}}')


def test_outcomes_are_valid() raises:
    assert_true(Outcome.INVALID_ENUM_VALUE.is_valid())
    assert_false(Outcome(5).is_valid())


def test_errors_null_data_and_a_small_buffer() raises:
    var planner = Planner(SDL)
    var operation = planner.normalize("{ user { id name } }")
    var metadata = metadata_of(SDL)
    var built = ProjectionPlan.from_operation(planner.store, operation, metadata)
    var errors = List[GraphQLError]()
    errors.append(graphql_error("a"))
    errors.append(graphql_error("b"))
    var empty = JsonDocument()
    var out = project_by_operation(
        empty,
        NO_NODE,
        errors^,
        built[0],
        built[1],
        variables_of(""),
        0,
        metadata,
    )
    assert_equal(
        String(unsafe_from_utf8=out^),
        '{"data":null,"errors":[{"message":"a"},{"message":"b"}]}',
    )
    var long_name = String("n") * 200
    var document = parse_json(
        '{"user":{"id":"' + long_name + '","name":"' + long_name + '"}}'
    )
    var grown = project_by_operation(
        document,
        document.root,
        List[GraphQLError](),
        built[0],
        built[1],
        variables_of(""),
        0,
        metadata,
    )
    assert_equal(len(grown), 437)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

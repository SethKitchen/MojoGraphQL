# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Plan execution cases for batch fetches, root re-entry and output
rewrites.

The cases follow `prepare_job_future`, `prepare_root_reentry_fetch_job`,
`process_job_result`, `partition_batch_errors_by_alias`,
`merge_batch_alias_entities` and `prepare_batch_fetch_job_state` of Hive
Router `1a29df9` `bin/router/src/executor/execution/plan.rs`, beside the
ported tests in `test_exec_plan.mojo`. The subgraphs answer in the same
process.
"""

from _exec_harness import run_router, variables_of
from _fixtures import child_type_mismatch, root_reentry, simple_requires
from gql_json.value import NO_NODE, JsonDocument
from gql_router.exec_http import CannedTransport
from gql_router.graphql_error import GraphQLError
from gql_router.pipeline import Router, RouterSchema
from gql_router.plan_nodes import FlattenNodePath, PlanNode, PlanNodeKind
from std.testing import TestSuite, assert_equal, assert_true

comptime MUTATION = "mutation{doSomething{query{__typename}}}"
"""The query that the router sends to `two`."""
comptime REENTRY = "{user(id: 1){name}}"
"""The root re-entry query that the router sends to `one`."""
comptime ACCOUNTS = (
    "{accounts{__typename ...on User{id} ...on Admin{_internal_qp_alias_0:"
    " id}}}"
)
"""A root query of `child_type_mismatch` with an output rewrite."""
comptime USERS = "{users{__typename id}}"
"""The query that the router sends to `a` for `users`."""
comptime SIMILAR = (
    "query($representations:[_Any!]!){_entities(representations:"
    " $representations){...on User{similarAccounts{__typename ...on"
    " User{id} ...on Admin{_internal_qp_alias_0: id}}}}}"
)
"""An entity query of `child_type_mismatch` with an output rewrite."""
comptime TWO_USERS = (
    "{u1: users{...a} u2: users{...a}}\n\nfragment a on User {__typename id}\n"
)
"""The query that the router sends to `a` for two aliased `users`."""
comptime BATCH = (
    "query($__batch_reps_0:[_Any!]!, $__batch_reps_1:[_Any!]!){_e0:"
    " _entities(representations: $__batch_reps_0){...on User{name}} _e1:"
    " _entities(representations: $__batch_reps_1){...on"
    " User{similarAccounts{__typename ...on User{id} ...on"
    " Admin{_internal_qp_alias_0: id}}}}}"
)
"""The batch query that the router sends to `b`."""
comptime BATCH_QUERY = (
    "{ u1: users { id similarAccounts { ... on User { id } ... on Admin { id"
    " } } } u2: users { id name } }"
)
"""A client operation of `child_type_mismatch` that plans a batch."""
comptime SIMILAR_QUERY = (
    "{ users { id similarAccounts { ... on User { id } ... on Admin { id }"
    " } } }"
)
"""A client operation of `child_type_mismatch` that plans a flatten."""


def test_a_root_reentry_merges_at_its_path() raises:
    var transport = CannedTransport()
    transport.add(
        "two",
        MUTATION,
        '{"data":{"doSomething":{"query":{"__typename":"Query"}}}}',
    )
    transport.add(
        "one",
        REENTRY,
        '{"data":{"user":{"name":"Ada"}},"errors":[{"message":"slow"}]}',
    )
    assert_equal(
        run_router(
            root_reentry.sdl(),
            transport^,
            "mutation { doSomething { query { user(id: 1) { name } } } }",
        ),
        '200 {"data":{"doSomething":{"query":{"user":{"name":"Ada"}}}},'
        + '"errors":[{"message":"slow","extensions":{"code":"DOWNSTREAM_SERVICE_ERROR","service":"one",'
        + '"affectedPath":"doSomething.query"}}]}',
    )


def test_a_root_reentry_without_targets() raises:
    var transport = CannedTransport()
    transport.add("two", MUTATION, '{"data":{"doSomething":null}}')
    transport.add("one", REENTRY, '{"data":{"user":{"name":"Ada"}}}')
    assert_equal(
        run_router(
            root_reentry.sdl(),
            transport^,
            "mutation { doSomething { query { user(id: 1) { name } } } }",
        ),
        '200 {"data":null}',
    )


def test_a_root_fetch_applies_its_output_rewrites() raises:
    var transport = CannedTransport()
    transport.add(
        "b",
        ACCOUNTS,
        '{"data":{"accounts":[{"__typename":"Admin",'
        + '"_internal_qp_alias_0":"9"},{"__typename":"User","id":"2"}]}}',
    )
    assert_equal(
        run_router(
            child_type_mismatch.sdl(),
            transport^,
            "{ accounts { ... on User { id } ... on Admin { id } } }",
        ),
        '200 {"data":{"accounts":[{"id":"9"},{"id":"2"}]}}',
    )


def _similar(entities: String) -> CannedTransport:
    var transport = CannedTransport()
    transport.add(
        "a", USERS, '{"data":{"users":[{"__typename":"User","id":"1"}]}}'
    )
    transport.add("b", SIMILAR, entities)
    return transport^


def test_flatten_entities_apply_their_output_rewrites() raises:
    assert_equal(
        run_router(
            child_type_mismatch.sdl(),
            _similar(
                '{"data":{"_entities":[{"similarAccounts":[{"__typename":'
                + '"Admin","_internal_qp_alias_0":"9"},{"__typename":"User",'
                + '"id":"2"}]}]}}'
            ),
            SIMILAR_QUERY,
        ),
        '200 {"data":{"users":[{"id":"1","similarAccounts":[{"id":"9"},'
        + '{"id":"2"}]}]}}',
    )
    # No entity comes back, so the rewrites have nothing to change.
    assert_equal(
        run_router(
            child_type_mismatch.sdl(),
            _similar('{"data":{"_entities":[]}}'),
            SIMILAR_QUERY,
        ),
        '200 {"data":null}',
    )


def _batch(u1: String, u2: String, entities: String) -> CannedTransport:
    var transport = CannedTransport(True)
    transport.add("a", TWO_USERS, '{"data":{"u1":' + u1 + ',"u2":' + u2 + "}}")
    transport.add("b", BATCH, entities)
    return transport^


comptime USER_1 = '[{"__typename":"User","id":"1"}]'
"""One user."""
comptime USER_2 = '[{"__typename":"User","id":"2"}]'
"""Another user."""


def test_a_batch_applies_alias_output_rewrites() raises:
    assert_equal(
        run_router(
            child_type_mismatch.sdl(),
            _batch(
                USER_1,
                USER_2,
                '{"data":{"_e0":[{"name":"Bo"}],"_e1":[{"similarAccounts":'
                + '[{"__typename":"Admin","_internal_qp_alias_0":"9"}]}]}}',
            ),
            BATCH_QUERY,
        ),
        '200 {"data":{"u1":[{"id":"1","similarAccounts":[{"id":"9"}]}],'
        + '"u2":[{"id":"2","name":"Bo"}]}}',
    )


def test_batch_errors_split_by_alias() raises:
    var out = run_router(
        child_type_mismatch.sdl(),
        _batch(
            USER_1,
            USER_2,
            '{"data":{"_e0":[{"name":"Bo"}],"_e1":[{"similarAccounts":[]}]},'
            + '"errors":[{"message":"alias","path":["_e1",0,"similarAccounts"]},'
            + '{"message":"none"},{"message":"other","path":["x"]},'
            + '{"message":"index","path":[0]},{"message":"empty","path":[]}]}',
        ),
        BATCH_QUERY,
    )
    assert_equal(
        out,
        '200 {"data":{"u1":[{"id":"1","similarAccounts":[]}],'
        + '"u2":[{"id":"2","name":"Bo"}]},"errors":[{"message":"alias",'
        + '"path":["u1",0,"similarAccounts"],"extensions":{"code":'
        + '"DOWNSTREAM_SERVICE_ERROR","service":"b","affectedPath":"u1.@"}},'
        + '{"message":"none","extensions":{"code":"DOWNSTREAM_SERVICE_ERROR",'
        + '"service":"b"}},{"message":"other","path":["x"],"extensions":'
        + '{"code":"DOWNSTREAM_SERVICE_ERROR","service":"b"}},{"message":'
        + '"index","path":[0],"extensions":{"code":"DOWNSTREAM_SERVICE_ERROR",'
        + '"service":"b"}},{"message":"empty","path":[],"extensions":{"code":'
        + '"DOWNSTREAM_SERVICE_ERROR","service":"b"}}]}',
    )


def test_a_batch_alias_without_entities() raises:
    # `u1` sends no representation, but the subgraph still answers `_e1`.
    assert_equal(
        run_router(
            child_type_mismatch.sdl(),
            _batch("[]", USER_2, '{"data":{"_e0":[{"name":"Bo"}],"_e1":[]}}'),
            BATCH_QUERY,
        ),
        '200 {"data":{"u1":[],"u2":[{"id":"2","name":"Bo"}]}}',
    )
    # The answer lacks `_e0`, so `u2` gets no `name`.
    assert_equal(
        run_router(
            child_type_mismatch.sdl(),
            _batch(USER_1, USER_2, '{"data":{"_e1":[{"similarAccounts":[]}]}}'),
            BATCH_QUERY,
        ),
        '200 {"data":{"u1":[{"id":"1","similarAccounts":[]}],"u2":[{"id":"2",'
        + '"name":null}]}}',
    )


def test_a_batch_without_representations_sends_nothing() raises:
    var router = Router(
        RouterSchema(child_type_mismatch.sdl()), _batch("[]", "[]", "{}")
    )
    var response = router.execute(
        BATCH_QUERY, None, JsonDocument(), NO_NODE, False, True
    )
    assert_equal(
        String(unsafe_from_utf8=response.body), '{"data":{"u1":[],"u2":[]}}'
    )
    assert_equal(len(router.executor.transport.requests), 1)


def _run_plan(
    mut router: Router[CannedTransport], variables: String
) raises -> String:
    router.executor.transport.reset()
    var output = router.executor.execute(
        router.schema.planner.store,
        router.slots[0].plan,
        router.schema.metadata,
        router.schema.keys,
        variables_of(variables),
        router.slots[0].projection,
        router.slots[0].root_type_name,
        JsonDocument(),
        NO_NODE,
        List[GraphQLError](),
    )
    return String(unsafe_from_utf8=output^.take_body())


def test_a_repeated_merge_path_reuses_its_representations() raises:
    var router = Router(
        RouterSchema(child_type_mismatch.sdl()),
        _batch(
            USER_1,
            USER_2,
            '{"data":{"_e0":[{"name":"Bo"}],"_e1":[{"similarAccounts":[]}]},'
            + '"errors":[{"message":"e","path":["_e0",0,"name"]}]}',
        ),
    )
    _ = router.execute(BATCH_QUERY, None, JsonDocument(), NO_NODE, False, True)
    ref plan = router.slots[0].plan
    var batch = plan.nodes[plan.node].nodes[1]
    assert_true(plan.nodes[batch].kind == PlanNodeKind.BATCH_FETCH)
    ref alias = plan.batches[plan.nodes[batch].fetch].aliases[0]
    var path = alias.merge_paths[0].copy()
    alias.merge_paths.append(path^)
    # Both paths reach the same user, so its error has two paths and no
    # affected path, as upstream with more than one merge path.
    assert_equal(
        _run_plan(router, ""),
        '{"data":{"u1":[{"id":"1","similarAccounts":[]}],"u2":[{"id":"2",'
        + '"name":"Bo"}]},"errors":[{"message":"e","path":["u2",0,"name"],'
        + '"extensions":{"code":"DOWNSTREAM_SERVICE_ERROR","service":"b"}},'
        + '{"message":"e","path":["u2",0,"name"],"extensions":{"code":'
        + '"DOWNSTREAM_SERVICE_ERROR","service":"b"}}]}',
    )


def test_a_flatten_over_a_non_fetch_node_sends_nothing() raises:
    var router = Router(RouterSchema(simple_requires.sdl()), CannedTransport())
    _ = router.execute(
        "{ products { upc } }", None, JsonDocument(), NO_NODE, False, True
    )
    ref plan = router.slots[0].plan
    var empty = plan.add_list(PlanNodeKind.SEQUENCE, List[Int]())
    plan.node = plan.add_flatten(FlattenNodePath(), empty)
    assert_equal(_run_plan(router, ""), '{"data":{"products":null}}')


def test_a_defer_node_raises() raises:
    var router = Router(RouterSchema(simple_requires.sdl()), CannedTransport())
    _ = router.execute(
        "{ products { upc } }", None, JsonDocument(), NO_NODE, False, True
    )
    ref plan = router.slots[0].plan
    plan.node = plan.add(PlanNode.of(PlanNodeKind.DEFER))
    var failed = False
    try:
        _ = _run_plan(router, "")
    except error:
        failed = True
        assert_equal(
            String(error), "Subscriptions and @defer are not supported"
        )
    assert_true(failed)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

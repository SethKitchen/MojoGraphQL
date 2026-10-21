# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of the subscription steps of the router.

Follows the subscription part of Hive Router `1a29df9`
`bin/router/src/executor/execution/plan.rs` `execute_query_plan`: the
`Subscription` node is the root, or the first node of a root `Sequence`;
the rest of the sequence runs for each event. The subgraphs answer in the
same process.
"""

from _stream_supergraph import sdl
from gql_json.value import NO_NODE, JsonDocument
from gql_router.ast import NONE
from gql_router.exec_http import CannedTransport
from gql_router.exec_plan import subscription_node, subscription_rest
from gql_router.pipeline import Router, RouterSchema, failure_body
from gql_router.plan_nodes import PlanNode, PlanNodeKind, QueryPlan
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime ENTITIES = (
    "query($representations:[_Any!]!){_entities(representations:"
    " $representations){...on Product{name}}}"
)
comptime SUBSCRIPTION = (
    "subscription { reviewAdded { id body product { upc name } } }"
)
comptime EVENT = (
    '{"data":{"reviewAdded":{"id":"1","body":"Review 1","product":'
    + '{"__typename":"Product","upc":"1"}}}}'
)


def _plan(kinds: List[PlanNodeKind], sequence: Bool) -> QueryPlan:
    """Return a plan of nodes of `kinds`, in a root sequence or alone."""
    var plan = QueryPlan()
    var children = List[Int]()
    for kind in kinds:
        children.append(plan.add(PlanNode.of(kind)))
    if not sequence:
        plan.node = children[0]
        return plan^
    var root = PlanNode.of(PlanNodeKind.SEQUENCE)
    root.nodes = children^
    plan.node = plan.add(root^)
    return plan^


def test_the_subscription_node_of_a_plan() raises:
    assert_equal(subscription_node(QueryPlan()), NONE)
    assert_equal(len(subscription_rest(QueryPlan())), 0)
    var alone = _plan([PlanNodeKind.SUBSCRIPTION], False)
    assert_equal(subscription_node(alone), alone.node)
    assert_equal(len(subscription_rest(alone)), 0)
    var first = _plan(
        [PlanNodeKind.SUBSCRIPTION, PlanNodeKind.FLATTEN, PlanNodeKind.FETCH],
        True,
    )
    assert_equal(subscription_node(first), 0)
    var rest = subscription_rest(first)
    assert_equal(len(rest), 2)
    assert_equal(rest[0], 1)
    assert_equal(rest[1], 2)
    # Only a `Subscription` node first in the root sequence counts.
    var later = _plan([PlanNodeKind.FETCH, PlanNodeKind.SUBSCRIPTION], True)
    assert_equal(subscription_node(later), NONE)
    assert_equal(subscription_node(_plan([], True)), NONE)
    assert_equal(subscription_node(_plan([PlanNodeKind.FETCH], False)), NONE)


def _router() raises -> Router[CannedTransport]:
    var transport = CannedTransport()
    transport.add(
        "products", ENTITIES, '{"data":{"_entities":[{"name":"Table"}]}}'
    )
    return Router(RouterSchema(sdl("http://x")), transport^)


def test_a_subscription_through_the_router() raises:
    var router = _router()
    var prepared = router.prepare_request(
        SUBSCRIPTION, None, JsonDocument(), NO_NODE, False, True
    )
    assert_true(prepared.is_subscription())
    var start = router.subscription_start(prepared)
    assert_equal(start.subgraph, "reviews")
    assert_equal(
        String(unsafe_from_utf8=Span(start.body)),
        '{"query":"subscription{reviewAdded{id body product{__typename'
        + ' upc}}}"}',
    )
    var body = router.subscription_event(
        prepared.slot, prepared.variables, List[UInt8](EVENT.as_bytes())
    )
    assert_equal(
        String(unsafe_from_utf8=Span(body)),
        '{"data":{"reviewAdded":{"id":"1","body":"Review 1","product":'
        + '{"upc":"1","name":"Table"}}}}',
    )
    # A subscription that needs no entity fetch runs no node per event.
    var alone = router.prepare_request(
        "subscription { reviewAdded { id } }",
        None,
        JsonDocument(),
        NO_NODE,
        False,
        True,
    )
    var own = router.subscription_event(
        alone.slot,
        alone.variables,
        List[UInt8]('{"data":{"reviewAdded":{"id":"2"}}}'.as_bytes()),
    )
    assert_equal(
        String(unsafe_from_utf8=Span(own)),
        '{"data":{"reviewAdded":{"id":"2"}}}',
    )
    # An event without data still projects the selection.
    var errors = router.subscription_event(
        prepared.slot,
        prepared.variables,
        List[UInt8]('{"errors":[{"message":"x"}]}'.as_bytes()),
    )
    assert_true(
        String(unsafe_from_utf8=Span(errors)).startswith('{"data":'),
        String(unsafe_from_utf8=Span(errors)),
    )


def test_a_subscription_that_cannot_stream() raises:
    var router = _router()
    var message = String("no error")
    try:
        _ = router.prepare_request(
            SUBSCRIPTION, None, JsonDocument(), NO_NODE, False, False
        )
    except error:
        message = String(error.body())
    assert_true("SUBSCRIPTIONS_NOT_SUPPORTED" in message, message)
    # A query has no `Subscription` node to start.
    var query = router.prepare_request(
        "{ topProducts { upc } }", None, JsonDocument(), NO_NODE, False, True
    )
    assert_false(query.is_subscription())
    message = "no error"
    try:
        _ = router.subscription_start(query)
    except error:
        message = String(error.body())
    assert_true("PLAN_EXECUTION_FAILED" in message, message)


def test_a_pinned_slot_is_not_reused() raises:
    var router = _router()
    var first = router.prepare_request(
        SUBSCRIPTION, None, JsonDocument(), NO_NODE, False, True
    )
    router.pin(first.slot)
    var other = router.prepare_request(
        "{ topProducts { upc } }", None, JsonDocument(), NO_NODE, False, True
    )
    assert_true(other.slot != first.slot)
    router.unpin(first.slot)


def test_a_document_derived_from_a_valid_one() raises:
    var router = _router()
    var prepared = router.prepare_request(
        "{ topProducts { upc } }", None, JsonDocument(), NO_NODE, False, True
    )
    var derived = router.prepare_coerced(
        "{ topProducts { upc name } }", None, prepared.variables, False
    )
    assert_false(derived.is_subscription())
    assert_true(derived.slot != prepared.slot)


def test_the_body_of_a_failed_event() raises:
    assert_equal(
        String(unsafe_from_utf8=Span(failure_body("m", "C"))),
        '{"errors":[{"message":"m","extensions":{"code":"C"}}]}',
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

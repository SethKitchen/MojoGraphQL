# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the order a query plan runs its fetches.

The cases follow `execute_plan_node` in Hive Router.
"""

from gql_router.ast import NONE
from gql_router.federation_spec import OperationKind
from gql_router.fetch_operation import (
    FetchDocument,
    FragmentDefinition,
    PlanningFetchOperation,
)
from gql_router.normalize import selection_set_from_text
from gql_router.operation import OperationDefinition
from gql_router.plan_execute import execution_order
from gql_router.plan_nodes import (
    FetchNode,
    FlattenNodePath,
    PlanNode,
    PlanNodeKind,
    QueryPlan,
)
from gql_router.store import Store
from std.testing import TestSuite, assert_equal


def _document(mut store: Store, query: String) raises -> FetchDocument:
    var set = selection_set_from_text(store, query)
    return FetchDocument(
        OperationDefinition(OperationKind.QUERY, set),
        List[FragmentDefinition](),
    )


def _fetch(
    mut plan: QueryPlan, mut store: Store, service: String
) raises -> Int:
    return plan.add_fetch(
        FetchNode(
            1,
            store.sym(service),
            OperationKind.QUERY,
            PlanningFetchOperation(_document(store, "{ a }"), store),
            NONE,
        )
    )


def test_a_sequence_runs_before_a_parallel_group() raises:
    var store = Store()
    var plan = QueryPlan()
    var books = _fetch(plan, store, "books")
    var users = _fetch(plan, store, "users")
    var reviews = _fetch(plan, store, "reviews")
    var side = plan.add_list(PlanNodeKind.PARALLEL, _ids(users, reviews))
    plan.node = plan.add_list(PlanNodeKind.SEQUENCE, _ids(books, side))
    assert_equal(
        execution_order(plan, store, False, List[String](), List[String]()),
        "books users reviews",
    )


def test_a_condition_runs_one_branch() raises:
    var store = Store()
    var plan = QueryPlan()
    var books = _fetch(plan, store, "books")
    var users = _fetch(plan, store, "users")
    var show = store.sym("show")
    plan.node = plan.add_condition(show, books, users)
    var names = List[String]()
    names.append("show")
    var yes = List[String]()
    yes.append("true")
    assert_equal(execution_order(plan, store, True, names, yes^), "books")
    var no = List[String]()
    no.append("false")
    assert_equal(execution_order(plan, store, True, names, no^), "users")
    assert_equal(
        execution_order(plan, store, False, List[String](), List[String]()), ""
    )


def test_a_flatten_runs_its_fetch_and_a_defer_runs_nothing() raises:
    var store = Store()
    var plan = QueryPlan()
    var books = _fetch(plan, store, "books")
    plan.node = plan.add_flatten(FlattenNodePath(), books)
    assert_equal(
        execution_order(plan, store, False, List[String](), List[String]()),
        "books",
    )
    var deferred = QueryPlan()
    deferred.node = deferred.add(PlanNode.of(PlanNodeKind.DEFER))
    assert_equal(
        execution_order(deferred, store, False, List[String](), List[String]()),
        "",
    )


def _ids(first: Int, second: Int) -> List[Int]:
    var nodes = List[Int]()
    nodes.append(first)
    nodes.append(second)
    return nodes^


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

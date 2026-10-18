# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Record the fetches a query plan runs.

Port of the dispatch in `execute_plan_node` in Hive Router `1a29df9`
`bin/router/src/executor/execution/plan.rs`.

A sequence runs its children in order. A parallel node runs its children
in source order here; upstream runs them at the same time. A condition
uses `condition_target`. A flatten node runs its child. A fetch or a
batch fetch is recorded by its subgraph name.

**Differences from upstream.** This function does not send the fetches.
It records the subgraph names. Parallel children are recorded in source
order. A subscription or a defer node records nothing.
"""

from gql_router.ast import NONE
from gql_router.fetch_variables import condition_target
from gql_router.plan_nodes import PlanNodeKind, QueryPlan
from gql_router.store import Store


def execution_order(
    plan: QueryPlan,
    store: Store,
    has_values: Bool,
    names: List[String],
    values: List[String],
) -> String:
    """Return the subgraphs a plan fetches, in run order.

    Args:
        plan: The query plan.
        store: The store with the subgraph names.
        has_values: True when the request has a variable map.
        names: The request variable names.
        values: The JSON text of each variable, parallel to `names`.

    Returns:
        The subgraph names, separated by spaces. `*` is a fetch with no
        subgraph. Empty when the plan has no root.
    """
    var text = String("")
    if plan.node == NONE:
        return text^
    var stack = List[Int]()
    stack.append(plan.node)
    var wrote = False
    while len(stack) > 0:
        var node = stack.pop()
        if node < 0 or node >= len(plan.nodes):
            continue
        var kind = plan.nodes[node].kind
        if kind == PlanNodeKind.SEQUENCE or kind == PlanNodeKind.PARALLEL:
            var index = len(plan.nodes[node].nodes)
            while index > 0:
                index -= 1
                stack.append(plan.nodes[node].nodes[index])
            continue
        if kind == PlanNodeKind.CONDITION:
            var next = condition_target(
                has_values,
                names,
                values,
                store.name(plan.nodes[node].condition),
                plan.nodes[node].if_clause,
                plan.nodes[node].else_clause,
            )
            if next != NONE:
                stack.append(next)
            continue
        if kind == PlanNodeKind.FLATTEN:
            if plan.nodes[node].node != NONE:
                stack.append(plan.nodes[node].node)
            continue
        if kind == PlanNodeKind.FETCH or kind == PlanNodeKind.BATCH_FETCH:
            if wrote:
                text += " "
            wrote = True
            text += _service(plan, store, node)
    return text^


def _service(plan: QueryPlan, store: Store, node: Int) -> String:
    """Return the subgraph name of a fetch node.

    Args:
        plan: The query plan.
        store: The store with the subgraph names.
        node: A fetch or batch-fetch node.

    Returns:
        The subgraph name, or `*` when it is absent.
    """
    var service = NONE
    var fetch = plan.nodes[node].fetch
    if plan.nodes[node].kind == PlanNodeKind.BATCH_FETCH:
        if fetch >= 0 and fetch < len(plan.batches):
            service = plan.batches[fetch].service_name
    elif fetch >= 0 and fetch < len(plan.fetches):
        service = plan.fetches[fetch].service_name
    if service == NONE:
        return String("*")
    return String(store.name(service))

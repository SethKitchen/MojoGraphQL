# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The query plan of a fetch graph.

Port of Hive Router `1a29df9`
`bin/router/src/query_planner/planner/query_plan.rs`: the fetch steps run
in waves. A wave holds every step whose parents have run. One step is a
node of the sequence; more steps are a `Parallel` node.

**Differences from upstream.** There is no cancellation token: a plan
cannot be cancelled while it is built. Upstream panics on an in-degree
error; this port raises `Error` with the same text.
"""

from gql_router.ast import NONE
from gql_router.fetch_step import FetchGraph
from gql_router.plan_nodes import (
    PlanNodeKind,
    QueryPlan,
    plan_node_from_fetch_step,
)
from gql_router.query_plan_optimize import (
    optimize_root_node,
    optimize_top_level_sequence,
)
from gql_router.store import Store
from gql_router.supergraph_state import SupergraphState


struct InDegree(Movable):
    """The parents of each step that have not run yet, as upstream
    `InDegree`."""

    var state: List[Int]
    """The in-degree of each step slot, or `NONE` for a step the root
    does not reach."""

    def __init__(out self, fetch_graph: FetchGraph) raises:
        """Count the parents of each step the root reaches, without the
        root itself.

        Args:
            fetch_graph: The fetch graph.

        Raises:
            Error: `Root fetch is missing` when the graph has no root.
        """
        var root_index = fetch_graph.root_index
        if root_index == NONE:
            raise Error("Root fetch is missing")
        self.state = List[Int](length=len(fetch_graph.alive), fill=NONE)
        var order = fetch_graph.bfs_order(root_index)
        var index = 0
        while index < len(order):
            var step = order[index]
            index += 1
            var count = 0
            for parent in fetch_graph.parent_steps(step):
                if parent != root_index:
                    count += 1
            self.state[step] = count

    def mark_as_processed(mut self, fetch_graph: FetchGraph, index: Int) raises:
        """Count one parent less for each child of a step, as upstream
        `mark_as_processed`.

        Args:
            fetch_graph: The fetch graph.
            index: The step that ran.

        Raises:
            Error: When a child has no record, or no parent left.
        """
        for child in fetch_graph.child_steps(index):
            var current = self.state[child]
            if current == NONE:
                raise Error(
                    "Attempt to decrease an in-degree of a non-existing step"
                )
            if current == 0:
                raise Error("In-degree was 0")
            self.state[child] = current - 1

    def is_fulfilled(self, child_index: Int) raises -> Bool:
        """Return True if every parent of a step has run, as upstream
        `is_fulfilled`.

        Args:
            child_index: The step.

        Returns:
            Whether its in-degree is 0.

        Raises:
            Error: `In-degree record missing` for a step with no record.
        """
        if self.state[child_index] == NONE:
            raise Error("In-degree record missing")
        return self.state[child_index] == 0


def build_query_plan_from_fetch_graph(
    mut store: Store, fetch_graph: FetchGraph, state: SupergraphState
) raises -> QueryPlan:
    """Build the query plan of an optimized fetch graph, as upstream
    `build_query_plan_from_fetch_graph`.

    Args:
        store: The store with the selections.
        fetch_graph: The fetch graph.
        state: The supergraph.

    Returns:
        The plan, after the sequence and batch rewrites.

    Raises:
        Error: The upstream `QueryPlanError` texts, such as `Root fetch is
            missing`, `Failed to build a plan` and `Internal Error: Cycle
            detected`.
    """
    var root_index = fetch_graph.root_index
    if root_index == NONE:
        raise Error("Root fetch is missing")
    var in_degrees = InDegree(fetch_graph)
    var queue = List[Int]()
    var head = 0
    var planned_nodes_count = 0
    for child_index in fetch_graph.child_steps(root_index):
        if in_degrees.is_fulfilled(child_index):
            queue.append(child_index)
        else:
            raise Error(
                "Internal Error: Root's child ("
                + String(child_index)
                + ") has more than one parent"
            )
    var plan = QueryPlan()
    var overall_plan_sequence = List[Int]()
    while head < len(queue):
        var current_wave_nodes = List[Int]()
        # The children come from the edges, and only a live step has edges,
        # so upstream's `Missing FetchStep` cannot happen here.
        var wave_end = len(queue)
        while head < wave_end:
            var step_index = queue[head]
            head += 1
            current_wave_nodes.append(
                plan_node_from_fetch_step(
                    store, plan, fetch_graph.steps[step_index], state
                )
            )
            planned_nodes_count += 1
            in_degrees.mark_as_processed(fetch_graph, step_index)
            for child_index in fetch_graph.child_steps(step_index):
                if child_index == root_index:
                    raise Error(
                        "Internal Error: Visited child step is a root step."
                        " It should not happen"
                    )
                if in_degrees.is_fulfilled(child_index):
                    queue.append(child_index)
        if len(current_wave_nodes) == 1:
            overall_plan_sequence.append(current_wave_nodes[0])
        else:
            overall_plan_sequence.append(
                plan.add_list(PlanNodeKind.PARALLEL, current_wave_nodes^)
            )
    var total_fetch_nodes = 0
    var indices = fetch_graph.step_indices()
    var at = 0
    while at < len(indices):
        if indices[at] != root_index:
            total_fetch_nodes += 1
        at += 1
    if planned_nodes_count != total_fetch_nodes:
        raise Error("Internal Error: Cycle detected")
    # An empty sequence means no step was planned, and the check above then
    # proves there is none, so upstream's `Plan is empty, but graph
    # reported task nodes` cannot happen here.
    if len(overall_plan_sequence) == 0:
        raise Error("Failed to build a plan")
    overall_plan_sequence = optimize_top_level_sequence(
        plan, overall_plan_sequence
    )
    var root_node: Int
    if len(overall_plan_sequence) == 1:
        root_node = overall_plan_sequence[0]
    else:
        root_node = plan.add_list(PlanNodeKind.SEQUENCE, overall_plan_sequence^)
    plan.node = optimize_root_node(store, plan, root_node, state)
    return plan^

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The query planner: from a normalized operation to a query plan.

Port of Hive Router `1a29df9` `bin/router/src/query_planner/planner/mod.rs`
(`Planner`, `plan_from_normalized_operation`) and of the test kit of
`query_planner/tests/testkit.rs`.

`Planner` reads a supergraph once: its state and its graph. `plan` runs
the five steps of upstream `plan_from_normalized_operation`: walk the
operation, find the best combination of paths, build the fetch graph,
optimize it, and build the query plan.

**Differences from upstream.** Upstream builds the plan from an owned
fetch graph and frees every intermediate value on return. This port keeps
the paths and trees of a plan in a `PlanSpace` that the next plan reuses,
and the selections in the planner's `Store`; `mark` and `rollback` drop the
selections of a plan once it is no longer needed.
"""

from gql_language.parser import parse
from gql_router.ast import ItemKind
from gql_router.best import find_best_combination
from gql_router.fetch_graph import (
    add_variables_to_fetch_steps,
    build_fetch_graph,
)
from gql_router.fetch_optimize import optimize_fetch_graph_with_subgraphs
from gql_router.fetch_step import QueryPlannerOptions
from gql_router.subgraph_state import SubgraphState, decompose_all
from gql_router.graph import Graph, PlannerOverrideContext, build_graph
from gql_router.normalize import normalize_operation
from gql_router.operation import OperationDefinition
from gql_router.query_plan import QueryPlan, build_query_plan_from_fetch_graph
from gql_router.store import Store
from gql_router.supergraph_state import SupergraphState, new_supergraph_state
from gql_router.walker import Walker, requirement_ids


struct Planner(Movable):
    """A supergraph, read once, and the state to plan its operations, as
    upstream `Planner`."""

    var store: Store
    """The symbols and selections."""
    var state: SupergraphState
    """The supergraph state."""
    var graph: Graph
    """The planner graph."""
    var subgraphs: List[SubgraphState]
    """The state of each subgraph, as upstream `subgraphs_state`."""
    var walker: Walker
    """The walk state, reused by each plan."""
    var options: QueryPlannerOptions
    """The planner options."""

    def __init__(
        out self,
        sdl: String,
        options: QueryPlannerOptions = QueryPlannerOptions.default(),
    ) raises:
        """Read a supergraph SDL, as upstream `Planner::new_from_supergraph`.

        Args:
            sdl: The supergraph SDL.
            options: The planner options.

        Raises:
            Error: When the SDL does not parse, or the graph cannot be built.
        """
        self.store = Store()
        self.state = new_supergraph_state(self.store, parse(sdl))
        self.graph = build_graph(self.store, self.state)
        self.subgraphs = decompose_all(self.state)
        var typename = self.store.add_item(
            ItemKind.FIELD, self.store.sym("__typename")
        )
        self.walker = Walker(requirement_ids(self.graph, self.store), typename)
        self.options = options.copy()

    def normalize(
        mut self, query: String, operation_name: Optional[String] = None
    ) raises -> OperationDefinition:
        """Parse and normalize an operation, as upstream
        `normalize_operation`.

        Args:
            query: The operation document.
            operation_name: The operation to plan; the first when absent.

        Returns:
            The normalized operation.

        Raises:
            Error: When the document does not parse or normalize.
        """
        return normalize_operation(
            self.store, self.state, parse(query), operation_name
        )

    def plan(
        mut self,
        operation: OperationDefinition,
        ctx: PlannerOverrideContext = PlannerOverrideContext.default(),
    ) raises -> QueryPlan:
        """Plan a normalized operation, as upstream
        `plan_from_normalized_operation`.

        Args:
            operation: The normalized operation.
            ctx: The override context of the request.

        Returns:
            The query plan.

        Raises:
            Error: When a selection has no path, or a step fails.
        """
        self.walker.space.reset()
        var resolved = self.walker.walk_operation(
            self.graph,
            self.store,
            self.state,
            ctx,
            operation.kind,
            operation.selection_set,
        )
        var tree = find_best_combination(
            self.walker.space, self.graph, resolved
        )
        var fetch_graph = build_fetch_graph(
            self.store,
            self.graph,
            self.state,
            ctx,
            self.walker.space,
            tree,
            operation,
        )
        optimize_fetch_graph_with_subgraphs(
            self.store, self.state, self.subgraphs, fetch_graph, self.options
        )
        fetch_graph.collect_variable_usages(self.store)
        add_variables_to_fetch_steps(
            fetch_graph, operation.variables, operation.has_variables
        )
        return build_query_plan_from_fetch_graph(
            self.store, fetch_graph, self.state
        )

    def plan_text(
        mut self,
        query: String,
        operation_name: Optional[String] = None,
        ctx: PlannerOverrideContext = PlannerOverrideContext.default(),
    ) raises -> String:
        """Normalize and plan an operation, and print the plan, as the
        upstream test kit `build_query_plan`.

        Args:
            query: The operation document.
            operation_name: The operation to plan; the first when absent.
            ctx: The override context of the request.

        Returns:
            The query plan, as upstream `Display`.

        Raises:
            Error: When any step fails.
        """
        var operation = self.normalize(query, operation_name)
        var plan = self.plan(operation, ctx)
        return plan.text(self.store)

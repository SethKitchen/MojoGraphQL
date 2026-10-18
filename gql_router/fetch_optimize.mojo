# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The fetch graph optimizer.

Port of Hive Router `1a29df9`
`bin/router/src/query_planner/planner/fetch/optimize/mod.rs`,
`FetchGraph::optimize`. The passes are in `fetch_optimize_merge`,
`fetch_optimize_batch`, `fetch_optimize_types` and `fetch_optimize_fold`.

The passes run in upstream order: mutation fields become a sequence, then
the merge passes run again and again until the graph stops changing, and
last, the fields of other shapes under one response key get aliases.

**Differences from upstream.** Upstream checks a cancellation token on
each round. This port has no cancellation. Upstream reads the subgraphs
from `SupergraphState::subgraphs_state`; `optimize_fetch_graph` cuts them
out of the supergraph once, and `optimize_fetch_graph_with_subgraphs`
takes them from the caller.
"""

from gql_router.fetch_optimize_batch import batch_multi_type
from gql_router.fetch_optimize_fold import (
    fold_concrete_selections_to_interfaces,
)
from gql_router.fetch_optimize_merge import (
    deduplicate_and_prune_fetch_steps,
    merge_children_with_parents,
    merge_leafs,
    merge_passthrough_child,
    merge_siblings,
    turn_mutations_into_sequence,
)
from gql_router.fetch_optimize_types import (
    fix_conflicting_type_mismatches,
    normalize_selection_sets,
)
from gql_router.fetch_optimize_utils import edge_count
from gql_router.fetch_step import FetchGraph, QueryPlannerOptions
from gql_router.store import Store
from gql_router.subgraph_state import SubgraphState, decompose_all
from gql_router.supergraph_state import SupergraphState


def optimize_fetch_graph_with_subgraphs(
    mut store: Store,
    state: SupergraphState,
    subgraphs: List[SubgraphState],
    mut fetch_graph: FetchGraph,
    options: QueryPlannerOptions,
) raises:
    """Optimize a fetch graph, as upstream `FetchGraph::optimize`, with the
    subgraph states given.

    Args:
        store: The store.
        state: The supergraph.
        subgraphs: The subgraph states, in the order of `subgraph_names`,
            as `decompose_all` returns them.
        fetch_graph: The fetch graph; it must have its root index.
        options: The planner options.

    Raises:
        Error: With the upstream `FetchGraphError` text, when a pass fails.
    """
    turn_mutations_into_sequence(fetch_graph)
    while True:
        var node_count_before = fetch_graph.step_count
        var edge_count_before = edge_count(fetch_graph)

        merge_passthrough_child(store, fetch_graph)
        merge_children_with_parents(store, fetch_graph)
        merge_siblings(store, fetch_graph)
        merge_leafs(store, fetch_graph)
        deduplicate_and_prune_fetch_steps(store, fetch_graph)
        batch_multi_type(store, state, fetch_graph)
        normalize_selection_sets(store, state, fetch_graph)
        var abstract_type_converted = fold_concrete_selections_to_interfaces(
            store, state, subgraphs, fetch_graph, options
        )

        if (
            node_count_before == fetch_graph.step_count
            and edge_count_before == edge_count(fetch_graph)
            and not abstract_type_converted
        ):
            break
    fix_conflicting_type_mismatches(store, state, subgraphs, fetch_graph)


def optimize_fetch_graph(
    mut store: Store,
    state: SupergraphState,
    mut fetch_graph: FetchGraph,
    options: QueryPlannerOptions,
) raises:
    """Optimize a fetch graph, as upstream `FetchGraph::optimize`.

    Args:
        store: The store.
        state: The supergraph.
        fetch_graph: The fetch graph; it must have its root index.
        options: The planner options.

    Raises:
        Error: With the upstream `FetchGraphError` text, when a pass fails.
    """
    var subgraphs = decompose_all(state)
    optimize_fetch_graph_with_subgraphs(
        store, state, subgraphs, fetch_graph, options
    )

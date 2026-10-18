# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The query plan test kit, as Hive Router `1a29df9`
`bin/router/src/query_planner/tests/testkit.rs`.

`_plan` builds the planner of a supergraph, normalizes and plans one
operation, and returns the plan as upstream `Display`.
"""

from gql_router.fetch_step import QueryPlannerOptions
from gql_router.graph import PlannerOverrideContext
from gql_router.planner import Planner


def _plan(
    sdl: String,
    query: String,
    ctx: PlannerOverrideContext = PlannerOverrideContext.default(),
    options: QueryPlannerOptions = QueryPlannerOptions.default(),
) raises -> String:
    """Plan an operation, as upstream `build_query_plan`.

    Args:
        sdl: The supergraph SDL.
        query: The operation document.
        ctx: The override context.
        options: The planner options.

    Returns:
        The query plan text, without the trailing newline.

    Raises:
        Error: When planning fails.
    """
    var planner = Planner(sdl, options)
    # `insta` drops the trailing newline of a snapshot.
    return String(planner.plan_text(query, None, ctx).rstrip("\n"))

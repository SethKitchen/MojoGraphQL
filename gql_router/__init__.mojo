# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""gql_router: a port of the MIT Hive Router `1a29df9`.

The main part is the query planner of `bin/router/src/query_planner`.
`gql_router.planner.Planner` reads a supergraph SDL once. Then it
normalizes and plans each operation. `Planner.plan_text` prints the plan
as upstream `Display`.

The planner runs these steps, one module each:

- `gql_router.supergraph_state` and `gql_router.subgraph_state` read the
  supergraph and its `@join__*` directives.
- `gql_router.graph` builds the planner graph of types, fields and moves.
- `gql_router.normalize` normalizes the operation.
- `gql_router.walker` finds the paths of each field, and
  `gql_router.best` finds the best combination of paths.
- `gql_router.fetch_graph` builds the fetch graph, and
  `gql_router.fetch_optimize` optimizes it.
- `gql_router.query_plan` and `gql_router.plan_nodes` make the query plan.

The other modules port other parts of Hive Router:

- `gql_router.cache` is the operation cache of `cache_state.rs` and
  `config/cache.rs`.
- `gql_router.headers` appends `Vary` tokens, as `http_utils/headers.rs`.
- `gql_router.header_rules` copies, inserts, and removes subgraph request
  headers, as `executor/headers/request.rs`.
- `gql_router.response_headers` propagates subgraph response headers, as
  `executor/headers/response.rs`.
- `gql_router.authorization`, `gql_router.policies`,
  `gql_router.auth_filter` and `gql_router.null_bubble` port
  `pipeline/authorization/` and `executor/operation_filter.rs`.
- `gql_router.error_mask` masks a subgraph error, as
  `executor/execution/error_masking.rs`.
- `gql_router.operation_name` builds the operation name sent to a
  subgraph, as `executor/execution/operation_name.rs`.
- `gql_router.rewrite` applies a fetch rewrite to a JSON value, as
  `executor/execution/rewrites.rs`.
- `gql_router.response_merge` merges one JSON response into another, as
  `executor/response/merge.rs`.
- `gql_router.graphql_error` is a subgraph GraphQL error, as
  `executor/response/graphql_error.rs`. `handle_subgraph_errors` attaches
  those errors, as `ExecutionContext::handle_errors`.
- `gql_router.response_storage` keeps response bodies until they merge, as
  `executor/response/storage.rs`.
- `gql_router.subgraph_response` reads a subgraph response, as
  `executor/response/subgraph_response.rs`.
- `gql_router.fetch_variables` keeps the variables a fetch uses and
  chooses a condition branch, as `executor/execution/plan.rs`.
- `gql_router.plan_execute` lists the fetches a plan runs, in that same
  dispatch order.
- `gql_router.response_path` merges a fetch into the response at a path,
  as `executor/utils/traverse.rs`.
- `gql_router.batch_alias` splits a batch response into alias errors and
  entity arrays, then merges each entity back, as
  `executor/execution/plan.rs`.

`apollo-router-workspace/` is excluded.
"""

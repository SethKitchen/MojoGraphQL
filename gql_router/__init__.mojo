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
- `gql_router.graphql_error` is a subgraph GraphQL error, as
  `executor/response/graphql_error.rs`. `handle_subgraph_errors` attaches
  those errors, as `ExecutionContext::handle_errors`.

The executor ports `bin/router/src/executor` and `bin/router/src/pipeline`:

- `gql_router.pipeline` runs a request: `RouterSchema` reads a supergraph
  and `Router.execute` parses, normalizes, coerces, plans, executes and
  projects, as `pipeline/mod.rs`.
- `gql_router.exec_plan` runs a query plan against the subgraphs, as
  `executor/execution/plan.rs`. `gql_router.exec_http` builds the
  subgraph requests and holds the transports.
- `gql_router.exec_projection_plan` and `gql_router.exec_projection`
  write the client response, as `executor/projection`.
- `gql_router.exec_variables` coerces the request variables, as
  `executor/variables`.
- `gql_router.exec_value`, `gql_router.exec_traverse`,
  `gql_router.exec_rewrites`, `gql_router.exec_requires` and
  `gql_router.exec_subgraph_response` work on the response arena, as
  `executor/response` and `executor/utils`.
- `gql_router.consumer_schema`, `gql_router.schema_metadata`,
  `gql_router.entity_keys`, `gql_router.exec_partition` and
  `gql_router.exec_introspection` hold the schema facts the executor uses.

`apollo-router-workspace/` is excluded.
"""

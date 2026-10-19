<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Router

`gql_router` ports the query planner of Hive Router commit `1a29df9` (MIT), its executor, its request pipeline, and some other parts of the router. It depends on `gql_language`, `gql_json` and `gql_http`. `apollo-router-workspace/` is excluded.

## Modules

| Module | Contents |
| --- | --- |
| `gql_router.planner` | `Planner` |
| `gql_router.plan_nodes` | `QueryPlan`, `PlanNode`, `PlanNodeKind`, `FetchNode`, `BatchFetchNode`, `EntityBatchAlias`, `FlattenNodePath`, `PathSegment`, `PathSegmentKind` |
| `gql_router.graph` | `Graph`, `Node`, `Edge`, `NodeKind`, `EdgeKind`, `PlannerOverrideContext`, `build_graph` |
| `gql_router.fetch_step` | `QueryPlannerOptions`, `FetchGraph`, `FetchStepData`, `FetchStepKind`, `FetchRewrite` |
| `gql_router.supergraph_state` | `SupergraphState`, `SupergraphDefinition`, `SupergraphField`, `DefinitionKind`, `new_supergraph_state` |
| `gql_router.subgraph_state` | `SubgraphState`, `decompose_from_supergraph`, `decompose_all` |
| `gql_router.normalize` | `normalize_operation`, `normalize_field_set`, `selection_set_from_text`, `RootTypes` |
| `gql_router.walker` | `Walker`, `ResolvedOperation`, `find_best_paths`, `pick_shared_paths`, `BestPathTracker` |
| `gql_router.best` | `find_best_combination` |
| `gql_router.fetch_graph` | `build_fetch_graph`, `FetchGraphBuilder`, `add_variables_to_fetch_steps` |
| `gql_router.fetch_optimize` | `optimize_fetch_graph`, `optimize_fetch_graph_with_subgraphs` |
| `gql_router.query_plan` | `build_query_plan_from_fetch_graph` |
| `gql_router.store` | `Store` |
| `gql_router.cache` | `OperationCache`, `CacheLimits`, `CacheConfig`, `CacheOverride`, `cache_config_from_json` |
| `gql_router.headers` | `HeaderMap`, `append_vary` |
| `gql_router.authorization` | `authorization_allows`, `element_authorized` |
| `gql_router.policies` | `collect_required_policies` |
| `gql_router.auth_filter` | `authorize_fields` |
| `gql_router.null_bubble` | `bubble_null_removals` |
| `gql_router.graphql_error` | `GraphQLError`, `error_json`, `http_status_error`, `normalize_entity_error` |
| `gql_router.pipeline` | `RouterSchema`, `Router`, `RouterResponse`, `PipelineError`, `PipelineErrorKind` |
| `gql_router.router_server` | `RouterHandler`, `serve_graphql`, `HttpAnswer`, `GraphQLParams`, `read_get_params`, `read_post_params` |
| `gql_router.exec_plan` | `Executor`, `PlanExecutionOutput`, `select_fetch_variables`, `condition_target` |
| `gql_router.exec_http` | `SubgraphTransport`, `HttpTransport`, `CannedTransport`, `build_request_body` |
| `gql_router.exec_projection_plan` | `ProjectionPlan` |
| `gql_router.exec_projection` | `project_by_operation` |
| `gql_router.exec_variables` | `CoerceVariablesPayload`, `collect_variables` |
| `gql_router.exec_value` | `deep_merge`, `copy_value`, `object_get`, `write_value` and the other arena helpers |
| `gql_router.exec_traverse` | `traverse`, `TraverseTargets` |
| `gql_router.exec_rewrites` | `apply_rewrite` |
| `gql_router.exec_requires` | `project_requires`, `requires_hash` |
| `gql_router.exec_subgraph_response` | `read_subgraph_response`, `SubgraphResponse` |
| `gql_router.consumer_schema` | `ConsumerSchema` |
| `gql_router.schema_metadata` | `SchemaMetadata`, `PossibleTypes`, `schema_metadata` |
| `gql_router.entity_keys` | `EntityKeys`, `KeysByType` |
| `gql_router.exec_partition` | `partition_operation` |
| `gql_router.exec_introspection` | `resolve_introspection` |

The other modules are internal steps of the planner: `ast`, `federation_spec`, `operation`, `selection_set`, `selection_tools`, `merge_path`, `response_keys`, `query_tree`, `mismatch_finder`, `fetch_operation`, `minification`, `query_plan_optimize`, and the `fetch_optimize_*` passes.

## Planner

`Planner(sdl, options)` reads a supergraph SDL once. It builds the supergraph state, the state of each subgraph, and the planner graph. A bad supergraph raises `Error`.

`normalize(query, operation_name)` parses and normalizes one operation, as upstream `normalize_operation`. Without a name, it takes the first operation. `plan(operation, ctx)` plans a normalized operation and returns a `QueryPlan`. `plan_text(query, operation_name, ctx)` does both steps and returns the plan as upstream `Display`.

`plan` runs these steps in order:

1. The walker finds the paths of each field through the graph.
2. `find_best_combination` picks the cheapest combination of paths.
3. `build_fetch_graph` makes one fetch step per subgraph call.
4. `optimize_fetch_graph_with_subgraphs` merges, folds and orders the steps.
5. `build_query_plan_from_fetch_graph` makes the plan nodes.

A field with no path raises `Error`. A cycle in the fetch graph raises `Error`. Upstream panics in some of these cases.

The planner keeps its selections in one `Store`. The paths and trees of a plan stay in a space that the next plan reuses.

## Planner graph

`build_graph` makes the graph that the walker searches. A node is a type in one subgraph, or a root of the supergraph. Its name is `Type/subgraph`. An edge is a move. The outgoing edges of a node are visited newest first, as upstream `petgraph`.

### Root entrypoints

A subgraph entrypoint links a supergraph root to the root type of each subgraph that resolves a root field. Query, mutation, and subscription have separate roots. A field that returns a root type adds a reentry move into the root of another subgraph.

### Field moves

A field move goes from a type to the type of one of its fields, in the same subgraph. A field with `@requires` keeps its requirement on the edge. A union field points at one tail per member in that subgraph.

### Interface moves

An abstract move goes from an interface to each object type that implements it in the same subgraph. The label is the object name.

### Entity moves

An entity move goes from a type in one subgraph to the same type in another subgraph. It needs a resolvable `@key` in the target, and it keeps that key as its requirement. An `@interfaceObject` adds a type move to each object that implements the interface.

### Provides copies

A field with `@provides` points at a copy of the target node. The copy also has edges for the fields that the `@provides` selection gives. When the selection adds nothing, the field keeps the plain node. A copy is found by its name, so two paths with the same provided selection share one copy.

### Path cost

A field move costs 1. Every other move costs 1000. A requirement adds the cost of its selection. `find_best_paths` keeps the paths of the lowest cost. On a tie, `pick_shared_paths` keeps the path whose edges the most leaves use.

## Planner options and overrides

`QueryPlannerOptions.default()` turns every experiment off. `experimental_abstract_type_folding` folds the fragments of object types into a shared interface.

`PlannerOverrideContext` holds the request values for progressive `@override`. `default()` has no flags and the percentage 0. `from_percentage(value)` sets the request percentage, from 0 to 100. `from_flag(flag)` sets one active custom label.

A percentage label selects the new field when the request percentage is below the label. A custom label selects the new field when its flag is active.

## Query plan

`QueryPlan` keeps its nodes in one arena. A node refers to its children by index. `QueryPlan.node` is the root, or `NONE` for an empty plan. A fetch node keeps its data in `fetches`, and a batch fetch node in `batches`.

The node kinds are `Fetch`, `BatchFetch`, `Sequence`, `Parallel`, `Flatten`, `Condition`, `Subscription` and `Defer`. A `Condition` node has the variable, an `if` branch and an `else` branch. A `Flatten` node has a path of fields, lists and type conditions.

`text(store)` prints the plan as upstream `Display`. The tests compare this text with the upstream snapshots byte for byte. `into_executable()` returns the executable form of the plan. That form prints each operation on one line.

A batch fetch sends several entity calls to one subgraph in one request. Each call has an alias, such as `_e0`, and its own representations variable, such as `__batch_reps_0`.

## Differences from upstream

- A plan has one type with an `executable` flag. Upstream uses a type parameter.
- A plan has no JSON form. `custom_scalar_paths` and the operation hash are not kept, because only the executor and the JSON form read them.
- There is no cancellation token. A plan cannot be canceled while it is built.
- The graph reads the supergraph definitions in source order. Upstream uses `HashMap` order. Node and edge indices are the same on every run.
- The supergraph state reads only what the planner uses. `@authenticated`, `@requiresScopes`, `@policy`, `@cost` and `@listSize` are not read into it.
- Selection sets are identified by a canonical key, not by a 64-bit hash.
- `find_best_combination` leaves out the branch and bound search of upstream. That search always stops at its root, because the greedy plan never costs more than its bound. The plan is the same.
- Upstream checks some states that the fetch graph builder never makes, such as an edge of the wrong kind. This port leaves those checks out. Upstream `rewrite_root_output` is also left out, because a step at the root has only the root type.
- Upstream panics on a bad `percent(...)` label, a missing type or field, and an in-degree error. This port raises `Error` with the same text.

The module docstrings give each difference in full.

## Tests

The tests in `tests/gql_router/test_plan_*.mojo` port the snapshot tests of upstream `bin/router/src/query_planner/tests/`. They use the upstream fixtures from `bin/router/fixture/`, one module each in `tests/gql_router/_fixtures/`.

`generated.rs` is not ported. It needs the random operation generator of `bin/differential`. `preparing_a_plan_preserves_its_wire_form` in `mod.rs` is not ported, because this port has no JSON form of a plan.

`requires_alias_scopes.rs` reads the JSON form of a plan. Its port walks the plan arena for the same fields. Upstream checks one operation with the `graphql_tools` rule `OverlappingFieldsCanBeMerged`. The port checks the same rule for the types of the upstream test schema.

The executor tests port the unit tests of upstream `bin/router/src/executor/`. The `test_exec_variables_*.mojo` suites port `variables/tests/`. The projection suites port `projection/`. `test_exec_value.mojo` and `test_exec_subgraph_response.mojo` port `response/`. `test_exec_traverse.mojo` ports `utils/traverse.rs`. `test_exec_requires.mojo` and `test_exec_plan.mojo` port `execution/plan.rs`.

`test_pipeline.mojo` runs the upstream benchmark operation through `Router.execute` with the canned responses of the `hive-router/execute` benchmark. The response must equal the upstream `expected_response.json` byte for byte. `test_router_server.mojo` serves the router and two subgraphs over HTTP on the loopback interface.

## Operation cache

`OperationCache` stores string values with an entry limit and two expiry times. The default limit is 1000 entries. A limit of zero stores nothing. A time to live of zero is unset. A time to idle of zero is unset. An entry expires on the earlier of the two times.

The caller passes the current time in milliseconds. When the cache is full, the oldest inserted entry is removed. Upstream uses TinyLFU. This port removes the oldest inserted key.

`default_cache_config` sets parsing, validation, normalization, and query plans to that default. It also sets plugin supergraph runtimes to 10. `cache_config_from_json` reads a JSON object. `{}` is the default. A duration uses `ms`, `s`, `m`, or `h`, as in `30m`. An unknown field is an error.

`CacheOverride` replaces one dimension and leaves the others inherited. A time of zero disables an inherited expiry. `disable` sets the maximum to zero.

## Vary

`append_vary` adds one token to the `Vary` header. A token that is already present is left in place. The comparison ignores ASCII case. An empty value is replaced by the token. Otherwise the token is appended after a comma and a space.

## Authorization

`authorization_allows` checks `@authenticated`, `@requiresScopes`, and `@policy`. JWT rules apply only when enforcement is on. `@policy` always applies. Groups are an OR of AND lists. An empty group matches. No groups does not match.

An element with no rule is allowed. `collect_required_policies` returns policy names in the order they are first seen. The result is empty when authorization is off or the schema has no `@policy`.

`authorize_fields` removes a field the request cannot see. In reject mode, one denied field rejects the operation. An authenticated request is unchanged when the schema has no scopes and no policies. A parent type with no authorization rules keeps its fields.

## Null bubbling

`bubble_null_removals` removes a denied field and each non-null ancestor. The walk stops at the first field whose type can be null. That nullable field is removed. Its parent stays. `__typename` is never removed. A child must have a higher index than its parent.

A non-null field at the operation root is removed. It does not reject the whole operation.


## Serve the router over HTTP

1. Read the supergraph once: `var schema = RouterSchema(sdl)`.
2. Make a transport to the subgraphs: `HttpTransport(schema.subgraph_names, schema.subgraph_urls)`.
3. Make the router: `var router = Router(schema^, transport^)`.
4. Serve it: `start_workers(RouterHandler(router^), config)`, with a `gql_http.server.ServerConfig`.

The handler answers `/graphql`. Give a second argument to `RouterHandler` to use another path. Each other path answers `404`.

## Pipeline

`Router.execute(query, operation_name, variables, variables_root, is_get, prefer_ok)` runs one request, as upstream `execute_pipeline`. It returns a `RouterResponse` with the status and the JSON body.

The steps are these:

1. `prepare` parses and normalizes the operation, and builds its projection plan. It also splits off the introspection part.
2. A subscription answers `415`. A mutation over `GET` answers `405`.
3. `collect_variables` coerces the variables. A bad value answers `BAD_USER_INPUT`.
4. The planner plans the downstream part. This occurs once for each cached operation.
5. `resolve_introspection` answers the introspection part.
6. `Executor.execute` runs the plan and projects the response.

The operation cache keeps the normalized operation, its projection plan and its query plan. The key is the operation name and the document. `CacheLimits` sets the size and the lifetimes.

A `PipelineError` gives the status and the body of a failed request, as upstream `PipelineError`. A client error keeps its message. An internal error shows `Internal server error`. When `prefer_ok` is set, a parse error and a coercion error answer `200`, because the response type is `application/json`.

## HTTP requests

`serve_graphql` decodes a request, as upstream `execution_request.rs`. A `GET` reads `query`, `operationName` and `variables` from the query string. A `POST` reads them from a JSON body. The `Content-Type` of a `POST` must contain `application/json`.

| Problem | Status | Code |
| --- | --- | --- |
| Another method | 405 | `METHOD_NOT_ALLOWED` |
| No `Content-Type` on a `POST` | 406 | `MISSING_CONTENT_TYPE_HEADER` |
| A `Content-Type` that is not JSON | 415 | `UNSUPPORTED_CONTENT_TYPE` |
| A bad percent escape | 400 | `UNPROCESSABLE_QUERY_PARAMS` |
| A body that is not one JSON object, a repeated member, or a member of the wrong type | 400 | `BAD_REQUEST` |
| `variables` that is not an object or `null` | 400 | `BAD_REQUEST` |
| No `query` | 400 | `MISSING_QUERY_PARAM` |

The response type is `application/graphql-response+json` when the `Accept` header names it before `application/json` and `*/*`. Otherwise it is `application/json`.

## Executor

`Executor[T].execute` runs a query plan through a `SubgraphTransport`, as upstream `execute_query_plan`. A sequence runs its children in order. A parallel node prepares each child from the same data. Then it starts each request, and then it reads and merges each response. A condition node runs the branch that its variable selects. A subscription node and a defer node raise `Error`.

A fetch sends the variables that it uses, and merges its data at the root. A flatten fetch walks its path, writes one representation for each different entity, and merges each returned entity back into each value that sent it. A batch fetch does the same for each alias. The merge uses the values that the prepare step found, so the path is walked once. When the subgraph returns errors, the merge walks the path again to get the error paths.

`HttpTransport` sends each request with `gql_http.client`, over keep-alive connections. Each request in flight has its own connection, so the requests of a parallel node overlap. The slowest subgraph sets the time of the node. `CannedTransport` answers in the same process with fixed responses, for tests and benchmarks.

A failed request, an empty body, a bad content type and a malformed body each add an error with the subgraph name, as upstream. A status that is not 2xx adds `SUBREQUEST_HTTP_ERROR`.

## Subgraph responses

`read_subgraph_response` reads `data`, `errors` and `extensions`, as upstream `SubgraphResponse`. Any other member is ignored. A repeated member, a member of the wrong type, or `null` data without `errors` is malformed. The data goes into the response arena.

Each error object is read as upstream `GraphQLError`. `message` must be a string. `locations` and `path` can be `null` or missing.

A location must have an integer `line` and `column` that are not negative. A path index must not be negative. `extensions` must be an object. In it, `code` and `service` must be strings, and `affectedPath` must be a string or `null`. A repeated member is malformed at each level.

`error_json` writes a GraphQL error. `handle_subgraph_errors` adds the subgraph name and the affected path. An `_entities` error moves to the path of each value that sent that entity.

## Projection

`ProjectionPlan.from_operation` merges the fields of the operation once, as upstream `ProjectionPlan`. `project_by_operation` writes the client response from it, as upstream `project_by_operation`.

A field is written under its response key, in query order. A `null` in a non-null position makes the parent `null`. At the root, `data` becomes `null`. An unknown enum value becomes `null` with the error `Value is not a valid enum value`.

## Performance

The executor works on one JSON arena, `gql_json.value.JsonDocument`. Strings and numbers keep the text that the subgraph sent, so they are copied and not decoded.

The recursive walks take a small handle of pointers, not the inputs themselves. LLVM gives a recursive function the fields of a read-only struct argument as separate arguments, so a large argument costs many stores on each call.

The projection builds a table for the plan once per request: the `"key":` bytes and the flags of each field. Each field remembers the position where it was found last. The next object of the same field tries that position first.

`bench/gql_router/execute.mojo` measures `hive-router/execute` against upstream `execute_query_plan` in `bench/baselines/rust-router`.

## Differences from upstream in the executor

- One operation cache keeps the parse, normalization and plan results. Upstream keeps three caches.
- A parallel node merges its responses in plan order. Upstream merges each response when it arrives. So the errors are in plan order.
- A transport has no tasks. `start` sends a request, and `finish` reads the oldest response.
- Operations are not validated against the schema.
- There are no plugins, coprocessors, persisted documents, demand control, CSRF prevention, CORS, request decompression, subscriptions, SSE, WebSocket or multipart responses.
- Header propagation, error masking and operation name forwarding are not ported.
- The representation hash folds eight bytes per multiply. Upstream uses XXH3. Equal representations still have equal hashes.
- The projection keeps one position hint for each plan field during the whole walk. Upstream keeps the hints for each list.
- The projection has no parent type check. Collection removes each parent type check from a real plan, in upstream too. Some fallbacks of the projection plan that a normalized operation cannot reach are not ported.
- `extensions` are not written to the client response.

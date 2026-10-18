<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Router

`gql_router` ports the query planner of Hive Router commit `1a29df9` (MIT), and some other parts of the router. It depends on `gql_language` and `gql_json`. `apollo-router-workspace/` is excluded.

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
| `gql_router.error_mask` | `mask_error`, `MaskedError`, `MaskPlanKind` |
| `gql_router.operation_name` | `subgraph_operation_name`, `operation_forward`, `ForwardKind` |
| `gql_router.rewrite` | `apply_fetch_rewrite`, `entity_satisfies`, `PossibleTypes` |
| `gql_router.response_merge` | `deep_merge` |
| `gql_router.graphql_error` | `GraphQLError`, `error_json`, `http_status_error`, `normalize_entity_error` |
| `gql_router.response_storage` | `ResponseStorage` |
| `gql_router.subgraph_response` | `read_subgraph_response`, `CustomScalarPaths`, `SubgraphResponse` |
| `gql_router.fetch_variables` | `select_fetch_variables`, `condition_target`, `batch_variable_payloads` |
| `gql_router.plan_execute` | `execution_order` |
| `gql_router.response_path` | `visit_response_path`, `merge_fetch_data` |
| `gql_router.batch_alias` | `partition_batch_errors`, `collect_batch_entities`, `merge_alias_entities` |
| `gql_router.header_rules` | `apply_request_headers`, `HeaderRule`, `HeaderRuleKind` |
| `gql_router.response_headers` | `apply_response_headers`, `ResponseAggregator`, `HeaderAggregateKind` |

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

## Error masking

`mask_error` hides a subgraph error. It runs only when the error names a service. A subgraph can turn message masking on or off. The default applies when the subgraph is not listed.

An allow list keeps `code`, `service`, `affectedPath`, and the named extension keys. A deny list removes those names. Other extension keys stay in their original order.

## Operation name

`subgraph_operation_name` sends the client operation name to a subgraph. The name is the client name, two underscores, and the fetch step id. The subgraph name is not part of that text. A subgraph can be left out.

`All` sends the name to every subgraph. An empty exclusion list means `All`. `Only` sends it to the listed subgraphs. An empty list sends nothing.

## Fetch rewrites

`apply_fetch_rewrite` changes one JSON value. A key renamer changes a field name at the end of a path. A value setter replaces the value there with a string. An array uses the same path for each item.

A type condition passes when `__typename` is absent or that type is in the set. A concrete type also passes when it is a member of the abstract type. A missing field stays in place.

## Response merge

`deep_merge` copies fields from one JSON value into another. A null source leaves the target as it is. Two objects share keys and append new keys in source order. Two arrays merge item by item.

A source value of another kind replaces the target. A shorter array keeps the target's extra items. An empty source object keeps the target.

## Subgraph errors

`error_json` writes a GraphQL error. Empty locations and empty extensions are left out. `service` is the subgraph name. Extra extension keys are written in alphabetical order.

`http_status_error` reports a failed subgraph response. The code is `SUBREQUEST_HTTP_ERROR`. A path that starts with `_entities` and an index expands onto each path of that entity.

`ResponseStorage.estimate_size` is the total number of response bytes plus 20 percent.

`handle_subgraph_errors` adds the subgraph name and the affected path. An `_entities` error expands when entity paths are given. Errors that were already recorded stay in front.

## Subgraph response

`read_subgraph_response` reads `data`, `errors`, and `extensions`. Any other field is ignored. Missing `data` is null. Null `data` with no `errors` is malformed.

A custom-scalar path keeps the original JSON text of that value. An array uses the same path for each item. `append_error` adds an error after the body is read.

## Fetch variables

`select_fetch_variables` keeps the variables a fetch uses. A variable that is not in the request is left out. No usage list means the fetch gets no variables.

`condition_target` runs the `if` branch when the variable is boolean `true`. Any other value runs the `else` branch. A missing variable runs neither branch.

`batch_variable_payloads` keeps the first representations payload of each variable name. A later alias with that name does not replace it. An empty payload is `[]`.

## Plan execution

`execution_order` lists the subgraphs a plan fetches. A sequence runs its children in order. A parallel node lists its children in source order. A condition runs one branch.

A flatten node runs its child fetch. A missing variable runs neither condition branch. A defer node adds no fetch.

## Response path

`visit_response_path` finds every value at a path. A field steps into that object field. `@` steps into each list item. A type condition stays on the object when the type matches.

`merge_fetch_data` deep-merges a fetch into each visited value. An empty path merges at the root. A missing field leaves the response unchanged.

## Batch aliases

`partition_batch_errors` sends an error to the alias named by its first path step. That step is rewritten to `_entities`. An error with no alias stays unmatched.

`collect_batch_entities` takes each alias array off the response. A field that is not an array is removed and not returned.

`merge_alias_entities` puts each entity back on the visited value. A negative index skips that value. When the alias has errors, the visit path is kept for that entity index.

## Request headers

`apply_request_headers` builds the headers for one subgraph. Global rules run first. Rules for that subgraph run after them. A hop-by-hop header is skipped.

A propagate rule copies the named client headers. It uses the default only when none of those names are present. `set-cookie` is appended as a separate field.

## Response headers

`apply_response_headers` adds subgraph headers to the client response. Global rules run first. Rules for that subgraph run after them. `content-type` and hop-by-hop headers are skipped.

The first rule to set a header chooses `first`, `last`, or `append`. Appended values are joined with a comma and a space. `set-cookie` stays a separate field.

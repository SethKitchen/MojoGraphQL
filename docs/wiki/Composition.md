<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Composition

`gql_composition` validates Apollo Federation subgraphs. It is phase 1 of a port of Hive Federation Composition v0.27.0 (`6272ad8`, MIT, The Guild), and it needs only `gql_language`. Phase 1 is the subgraph phase of upstream `validate`: it finds the errors of each subgraph. It does not compose a supergraph.

## Validate subgraphs

`gql_composition.validate.validate_subgraphs` runs the subgraph phase on a list of subgraphs. The messages, the codes and the order of the errors are the same as in upstream.

| Function | Upstream | Result |
| --- | --- | --- |
| `validate_subgraphs(subgraphs)` | the subgraph phase of `validate(subgraphs)` in `src/validate.ts` | `List[CompositionError]` |
| `Subgraph(name, url, type_defs)` | `ServiceDefinition` | A subgraph with a parsed `Document` |

The result is empty when every subgraph is valid. The steps are the upstream steps:

1. Give each subgraph an id, and sort the subgraphs by id (`buildGraphList`).
2. Check the `@link` directives of each subgraph (`validateSubgraphCore`). When a subgraph has a `@link` error, the result is the `@link` errors of all subgraphs, and the next steps do not run.
3. Find the federation version of each subgraph (`detectFederationVersion`).
4. Walk each subgraph with the state builder and the federation rules, check the state (`validateSubgraphState`), and walk the full document with the GraphQL rules (`validateSubgraph`).

`validate_subgraphs` raises an `Error` where upstream throws. That is the case for two subgraphs with the same name, a `@link` without `url`, or a `@fromContext` selection that does not parse.

```mojo
from gql_language.parser import parse
from gql_composition.validate import Subgraph, validate_subgraphs

var sdl = String("type Query { a: String }\ntype Query { b: String }")
for error in validate_subgraphs([Subgraph("users", None, parse(sdl))]):
    print(error)  # [INVALID_GRAPHQL] [users] There can be only one type named "Query".
```

`CompositionError` has three fields:

| Field | Upstream | Value |
| --- | --- | --- |
| `message` | `message` | The message, with the `[<subgraph>] ` prefix |
| `code` | `extensions.code` | An `ErrorCode`, such as `ErrorCode.INVALID_GRAPHQL` |
| `subgraph_name` | `extensions.subgraphName` | The name of the subgraph |

`String(error)` gives `[<code>] <message>`.

## Federation versions

The version table is `VERSION_NAMES` in `gql_composition.version`. A subgraph without a federation `@link` is `v1.0`. The table is data, so a new version is one new row.

| Version | New definitions | Source |
| --- | --- | --- |
| `v1.0` | `@key`, `@requires`, `@provides`, `@external`, `@extends`, `@override`, `_FieldSet`, and `@tag` and `@inaccessible` | Hive v0.27.0 |
| `v2.0` | `@shareable`, `@inaccessible`, `@tag`, `FieldSet` | Hive v0.27.0 |
| `v2.1` | `@composeDirective` | Hive v0.27.0 |
| `v2.2` | none | Hive v0.27.0 |
| `v2.3` | `@interfaceObject` | Hive v0.27.0 |
| `v2.4` | none | Hive v0.27.0 |
| `v2.5` | `@authenticated`, `@requiresScopes` | Hive v0.27.0 |
| `v2.6` | `@policy` | Hive v0.27.0 |
| `v2.7` | `@override(label:)` | Hive v0.27.0 |
| `v2.8` | `@context`, `@fromContext`, `@cost`, `@listSize` | Hive v0.27.0 |
| `v2.9` | none | Hive v0.27.0 |
| `v2.10`, `v2.11` | none | Apollo GraphOS page "Federation versions" |
| `v2.12` | `@cacheTag(format: String!) repeatable on FIELD_DEFINITION \| OBJECT` | Apollo GraphOS page "Federation versions" |
| `v2.13`, `v2.14`, `v2.15` | none | Apollo GraphOS page "Federation versions" |

The page is apollographql.com/docs/graphos/schema-design/federated-schemas/reference/versions. The pages specs.apollo.dev/federation/v2.10 and later do not exist. A version above `v2.15` gives `UNKNOWN_FEDERATION_LINK_VERSION`.

## Rules

The federation rules run in the upstream order of `federationRules`. The GraphQL rules run after them, in the upstream order of `graphqlRules`.

| Module | Upstream files |
| --- | --- |
| `rules_basic` | `reserved-subgraph-name-rule.ts`, `known-federation-directive-rule.ts`, `elements/field-set.ts`, `query-root-type-inaccessible-rule.ts`, `known-type-names-rule.ts`, `known-root-type-rule.ts`, `root-type-used-rule.ts` |
| `rules_marks` | `elements/inaccessible.ts`, `elements/tag.ts` |
| `rules_auth` | `elements/authenticated.ts`, `elements/policy.ts`, `elements/requires-scopes.ts` |
| `rules_elements` | `elements/cost.ts`, `interface-object.ts`, `extends.ts`, `shareable.ts`, `external.ts`, `override.ts`, `context.ts`, `compose-directive.ts` |
| `rules_from_context` | `elements/from-context.ts` |
| `rules_list_size` | `elements/list-size.ts` |
| `rules_field_sets` | `elements/key.ts`, `elements/provides.ts`, `elements/requires.ts` |
| `rules_graphql` | the 15 GraphQL rules, such as `known-directives-rule.ts` and `unique-type-names-rule.ts` |
| `validate_state` | `validate-state.ts` |

## Differences from upstream

- Upstream compares versions with `parseFloat`. This port keeps a version as `major * 100 + minor`, so `v2.10` is above `v2.9`. Upstream v0.27.0 does not know `v2.10` to `v2.15`.
- The subgraphs are sorted by id with a comparison that agrees with `localeCompare` for the ids that `constantCase` makes.
- The specified directives of the GraphQL rules are those of graphql-js 16.14.2.
- Some upstream branches cannot run, and this port does not have them. The module docstrings list them.

## Tests

The tests are in `tests/gql_composition/`. Each `test_*.mojo` file is a port of one upstream file of `__tests__`, for the Guild implementation. The subgraph files (`__tests__/subgraph/**`) are ported in full. From the other files, the tests have the cases whose subgraph phase fails. The expected errors come from upstream `validate` in Node.js on the same subgraphs. `test_versions.mojo` tests the version table.

## Benchmarks

`bench/gql_composition/hive.mojo` validates the subgraphs of the upstream benchmark fixtures: the `basicServices` of `benchmark.ts`, `stars-stuff`, `dgs` and `huge-schema`. The baseline is `bench/baselines/js-composition/bench.mjs`, which runs the same subgraph phase of Hive Federation Composition 0.27.0 in Node.js.

## Not yet ported

Phase 2 must port these upstream files:

- Supergraph composition: `src/compose.ts`, `src/supergraph/state.ts`, `src/supergraph/composition/*.ts` (`ast`, `common`, `directive`, `enum-type`, `input-object-type`, `interface-type`, `object-type`, `scalar-type`, `union-type`, `visitor`), `src/specifications/join.ts`, `src/graphql/supergraph-spec.ts`.
- Supergraph validation: `src/supergraph/validation/validate-supergraph.ts`, `validation-context.ts`, and the 33 rules in `src/supergraph/validation/rules/`.
- Satisfiability: `src/supergraph/validation/rules/satisfiablity-rule.ts` and `satisfiablity/*.ts` (`constants`, `contexts`, `edge`, `errors`, `finder`, `graph`, `helpers`, `move-validator`, `moves`, `node`, `operation-path`, `selection`, `supergraph`, `walker`).
- Cost: the supergraph part of `@cost` and `@listSize`, in `supergraph/composition` and `list-size-slicing-arguments-rule.ts`.
- Contracts: `src/contracts/*.ts` (`add-inaccessible-to-unreachable-types`, `reachable-type-filter`, `schema-contract`, `tag-extraction`).
- Public schema and helpers: `src/graphql/transform-supergraph-to-public-schema.ts`, `contains-supergraph-spec.ts`, `sort-sdl.ts`, `src/utils/dependency-graph.ts`, `src/utils/link/*.ts` (the public link API).
- The `v2.14` and `v2.15` changes to composition behavior that the Apollo GraphOS page lists, because they are in the supergraph phase.

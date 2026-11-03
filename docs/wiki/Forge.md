<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Forge

`gql_forge` is Forge: a control plane for supergraphs that you already host. Forge does not run those graphs. You register the ScorchQL or router URL, and you allowlist the Forge IP or you upload SDL. [How to run Forge](How-to-run-Forge) tells you how to start it.

The product value is telemetry, analytics, comparison of graphs between environments, and an analyst that reads that evidence.

## Modules

| Module | Contents |
| --- | --- |
| `gql_forge.names` | `is_valid_slug`, `is_valid_endpoint_url`, `is_http_endpoint`, `make_ingest_token`, `tokens_equal` |
| `gql_forge.store` | `Store`, `StoreLock`, file helpers, JSON object readers |
| `gql_forge.catalog` | `Catalog`, `Organization`, `Graph`, `Variant` |
| `gql_forge.schema_view` | `schema_index_json`, `type_ref_text`, `write_user_types` |
| `gql_forge.pull` | `pull_variant`, `upload_schema`, `read_introspection_sdl` |
| `gql_forge.compare` | `compare_variants`, `compare_schemas`, `field_names` |
| `gql_forge.telemetry` | `ingest_event`, `insights_json`, `percentile` |
| `gql_forge.analyze` | `analyze`, `analyze_type`, `classify_question` |
| `gql_forge.page` | `forge_page`, `PAGE_HTML` |
| `gql_forge.server` | `Forge`, `ForgeConfig`, `serve_forge` |
| `gql_forge.cli` | `parse_cli`, `forge_config`, `USAGE` |

`bin/forge.mojo` is the `forge` program. A start with no extra flags serves only the control plane. It starts no graph. `make forge` builds it into `dist/`.

## Catalog

A catalog is a directory that every worker process shares:

| Path | Contents |
| --- | --- |
| `orgs/<slug>.json` | One organization |
| `graphs/<org>/<ref>.json` | One graph |
| `variants/<org>/<graph>/<name>.json` | One environment and its customer URL |
| `schemas/<org>/<graph>/<variant>/<rev>.graphql` | One schema snapshot |
| `telemetry/<org>/<graph>/<variant>.json` | Operation roll-ups |

A graph is a supergraph that the customer already hosts. A variant is one environment of that graph, such as `prod` or `staging`.

Forge writes each file to a temporary name and then renames it. Each worker process uses its own temporary names. A request that changes the catalog holds `Store.lock`, an advisory `flock` on the directory, so two workers do not lose a change. A pull holds the lock only after the customer graph answers.

## HTTP API

`Forge` is a `gql_http` handler. It answers these requests:

| Method and path | Answer |
| --- | --- |
| `GET /` | The Forge site |
| `GET /health` | `{"status":"pass"}` |
| `GET /forge/state` | Organizations, graphs and variants |
| `POST /forge/orgs` | Create `{slug, name}` |
| `POST /forge/graphs` | Create `{org, ref, name, description}` |
| `POST /forge/variants` | Create `{org, graph, name, endpointUrl}` |
| `PATCH /forge/variants` | Change `{org, graph, name}` to a new `endpointUrl` or `pullToken` |
| `DELETE /forge/variants` | Remove `{org, graph, name}` |
| `POST /forge/schema` | Store uploaded SDL |
| `POST /forge/pull` | Pull SDL from an `http://` endpoint |
| `GET /forge/schema` | The current SDL snapshot of a variant |
| `GET /forge/schema-index` | Types and fields for the explorer |
| `GET /forge/compare` | Breaking, dangerous and additive changes |
| `POST /forge/telemetry` | One operation event |
| `GET /forge/insights` | Request counts and percentiles |
| `GET /forge/operations` | The recent events of a variant |
| `POST /forge/analyze` | An analyst answer |

When `ForgeConfig.admin_token` is set, catalog routes need `Authorization: Bearer <token>`. Telemetry accepts the variant ingest token or the admin token.

Each variant gets its ingest token when Forge creates it. The token is `frg_` and 128 random bits from the operating system, so nobody can make it from the names. Forge compares tokens in constant time.

A live pull uses `gql_http`. It can reach `http://` only. Upload SDL for `https://` endpoints.

## Site

The site is one HTML page in `PAGE_HTML`. It loads nothing from other hosts. It has seven views:

| View | Contents |
| --- | --- |
| Overview | Variants, last pull, endpoint |
| Schema | Type list and field details |
| Compare | Diff of two environments |
| Insights | Request counts, errors and p95 |
| Operations | Recent ingested events |
| Analyst | Answers from stored evidence |
| Connect | Register a URL, upload SDL, copy the ingest token |

The Connect view states that Forge does not host the graph. The customer keeps the ScorchQL or router process.

## Analyst

`analyze` classifies the question, then reads the catalog, the schema snapshots and the telemetry. It does not call a remote model. Intents are health, compare, latency, errors, type, operations and connect.

## Limits

- Forge does not serve GraphQL operations to clients.
- Forge does not compose subgraphs. ScorchQL does that on the customer side.
- A schema pull over TLS is not in this package.

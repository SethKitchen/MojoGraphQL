<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Compatibility

The `products` subgraph of MojoGraphQL passes every check of the Apollo Federation subgraph compatibility suite. The suite is [apollographql/apollo-federation-subgraph-compatibility](https://github.com/apollographql/apollo-federation-subgraph-compatibility) at `f9520a4` (MIT).

`gql_subgraph` builds the subgraph, and `gql_server` serves it. The Mojo port of the checks is the gate. It is `tests/gql_subgraph/test_compatibility.mojo`, and `make test PKG=gql_subgraph` runs it.

## Checks

Each row is one test of `packages/compatibility/src/tests/`. "Required" is the `required` flag of the suite's `testRunner.ts`.

| Column of the suite | Jest test | Required | Mojo tests | Result |
| --- | --- | --- | --- | --- |
| `_service` | `introspection` | Yes | `test_introspection` | Pass |
| `@key (single)` | `@key single` | Yes | `test_key_single_applies_on_user`, `test_key_single_resolves_user` | Pass |
| `@key (multi)` | `@key multiple` | No | `test_key_multiple_applies_on_deprecated_product`, `test_key_multiple_resolves_deprecated_product` | Pass |
| `@key (composite)` | `@key composite` | No | `test_key_composite_applies_on_product_research`, `test_key_composite_resolves_product_research` | Pass |
| `repeatable @key` | `repeatable @key` | No | `test_repeatable_key_applies_on_product`, `test_repeatable_key_resolves_product` | Pass |
| `@requires` | `@requires` | No | `test_requires_in_service_sdl`, `test_requires_computes_from_field_set` | Pass, through `_entities` |
| `@provides` | `@provides` | No | `test_provides_in_service_sdl`, `test_provides_returns_locally_computed_field` | Pass |
| `federated tracing` | `ftv1` | No | `test_ftv1`, `test_ftv1_tree_of_the_products_schema` | Pass, through `gql_server` |
| `@link` | `@link` | Yes | `test_link` | Pass |
| `@shareable` | `@shareable` | No | `test_shareable_in_service_sdl`, `test_shareable_resolves_product_dimension` | Pass |
| `@tag` | `@tag` | No | `test_tag` | Pass |
| `@override` | `@override` | No | `test_override_in_service_sdl`, `test_override_returns_overridden_user_name` | Pass |
| `@inaccessible` | `@inaccessible` | No | `test_inaccessible_in_service_sdl`, `test_inaccessible_field_queried_directly` | Pass |
| `@composeDirective` | `@composeDirective` | No | `test_compose_directive` | Pass |
| `@interfaceObject` | `@interfaceObject` | No | `test_interface_object_in_service_sdl`, `test_interface_object_returns_new_fields` | Pass, through `_entities` |

The `@external` and `@extends` checks of `COMPATIBILITY.md` have no jest test of their own. The `@requires`, `@provides` and `_service` tests cover them.

The suite has other Mojo tests. `test_compare_schemas_reports_differences` checks the port of `compareSchemas`. The last four tests query the other data and resolvers of the apollo-server implementation.

## How the Mojo tests differ from the jest tests

- **Requests.** The jest tests send each request over HTTP. The Mojo tests run each request with `SubgraphSchema.execute`, except the `ftv1` tests, which send an HTTP request to `gql_server`. The same requests give the same results over HTTP from `bench/compat/products.mojo`.
- **Results.** The jest tests check a subset of each result with `toMatchObject`. The Mojo tests check the full JSON result.
- **Regular expressions.** Mojo has no regular expressions. `matches` in `tests/gql_subgraph/_compat.mojo` finds each part of a pattern in order, as `a.*b` does. `<a|b>` is an alternative, and `<a|>` is an optional part.
- **Router tests.** Four jest tests query the router, which queries `products` and the `users` and `inventory` subgraphs. Each Mojo test sends the `_entities` request that the router sends to `products`.

| Jest test | Request to the router | Request to `products` in the Mojo test |
| --- | --- | --- |
| `@requires` | `product(id) { createdBy { averageProductsCreatedPerYear email } }` | `_entities` for a `User` with `email`, `totalProductsCreated: 1337` and `yearsOfEmployment: 10` |
| `@shareable` | `product(id) { dimensions { size weight } }` | The same query: `products` resolves all of it |
| `@override` | `product(id) { createdBy { name } }` | The same query: `products` resolves `name` |
| `@interfaceObject` | `inventory(id) { deprecatedProducts { sku reason } }` | `_entities` for an `Inventory` with `id: "apollo-oss"` |

Each router test can be expressed as a request to `products`.

## ftv1

`gql_server` serves inline traces for a subgraph schema, as Apollo Server does. A request with the `apollo-federation-include-trace: ftv1` header gets `extensions.ftv1`: the base64 of the protocol buffer `Trace` of the request. The [Server](Server) page tells how the inline trace plugin works.

The jest test sends `query { __typename }` and checks only that `extensions.ftv1` is a string. The Mojo tests also decode the trace and check its tree:

- `test_ftv1` sends the jest request. The trace has only the root node, because Apollo Server does not trace the meta field `__typename`.
- `test_ftv1_tree_of_the_products_schema` sends `{ product(id: "apollo-federation") { id sku } }`. The tree has the `product` node, with the `id` and `sku` nodes as its children. Each node has its type, its parent type and the times of its resolver.

The `ftv1` tests import `gql_server`. `packages.toml` lists `gql_server` in the `test_depends` of `gql_subgraph`, so only the tests can import it. The `gql_subgraph` library does not need `gql_server`.

## Run the products subgraph

`bench/compat/products.mojo` serves the `products` subgraph on port 4001, as `implementations/apollo-server/index.js` does. Set `PRODUCTS_PORT` to use a different port. Run it from the repository root:

```bash
.venv/bin/mojo run -I . -I tests/gql_subgraph bench/compat/products.mojo
```

The schema, the data and the resolvers are in `tests/gql_subgraph/_products.mojo`. The tests and the server use the same module.

The server is a `gql_server` standalone server with a plugin. The plugin calls `SubgraphSchema.attach` in `execution_did_start`, so `_service` and `_entities` resolve in the server.

## The official suite

The official suite cannot run against the Mojo server in this project. Its runner starts a supergraph in one of two ways:

- `docker compose`, with the Apollo Router image.
- `pm2`, with `rover dev`, which downloads and runs the Apollo Router.

The Apollo Router has the Elastic License 2.0, which this project does not use. `gql_router` cannot serve a supergraph yet. Thus the Mojo port of the checks is the gate.

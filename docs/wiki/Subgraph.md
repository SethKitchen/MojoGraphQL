<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Subgraph

`gql_subgraph` builds an executable Apollo Federation subgraph from SDL. It is a port of `@apollo/subgraph` 2.14.4 (`b95c124`): `buildSubgraphSchema`, `printSubgraphSchema` and the `_entities` resolver. It needs `gql_language`, `gql_schema`, `gql_execution` and `gql_json`.

`@apollo/subgraph` calls `buildSubgraph` of `@apollo/federation-internals`. That package has the Elastic License 2.0, so this port does not read it. The port implements `buildSubgraph` from the public federation specifications, with Hive Federation Composition v0.27.0 (MIT) as the reference. The output and the error messages come from `@apollo/subgraph` 2.14.4, run as a black box.

| Module | Contents | Upstream source |
| --- | --- | --- |
| `gql_subgraph.build_subgraph_schema` | `build_subgraph_schema`, `SchemaModule`, `SubgraphResolvers`, `SubgraphSchema` | `buildSubgraphSchema.ts`, `schema-helper/buildSchemaFromSDL.ts` |
| `gql_subgraph.print_subgraph_schema` | `print_subgraph_schema` | `printSubgraphSchema.ts` |
| `gql_subgraph.entities` | `entities_resolver`, `ReferenceResolver`, `ReferenceResolvers` | `types.ts` |
| `gql_subgraph.subgraph` | `build_subgraph`, `locale_compare` | `buildSubgraph`, from the specifications |
| `gql_subgraph.link` | `read_links`, `LinkInfo` | The link specification v1.0 |
| `gql_subgraph.spec` | `FederationVersion` and the definitions of each federation version | The federation v2.x specifications |
| `gql_subgraph.model`, `printer`, `sdl_printer` | The model of the SDL, and its printer | `printSchema`, from its output |

```mojo
from gql_execution.execute import ExecutionArgs
from gql_language.parser import parse
from gql_subgraph.build_subgraph_schema import build_subgraph_schema
from gql_subgraph.print_subgraph_schema import print_subgraph_schema

var subgraph = build_subgraph_schema(parse(
    'extend schema @link(url: "https://specs.apollo.dev/federation/v2.3",'
    ' import: ["@key"])'
    ' type Query { me: User } type User @key(fields: "id") { id: ID! }'
))
var args = ExecutionArgs()
print(subgraph.execute(parse("{ _service { sdl } }"), args).to_json())
print(print_subgraph_schema(subgraph))
```

## Build a subgraph schema

| Function | Upstream call |
| --- | --- |
| `build_subgraph_schema(document)` | `buildSubgraphSchema(typeDefs)` |
| `build_subgraph_schema(modules)` | `buildSubgraphSchema([{ typeDefs, resolvers }, ...])` |
| `build_subgraph_schema(documents, resolvers)` | `buildSubgraphSchema({ typeDefs: [...], resolvers })` |

The SDL of the modules is joined, as graphql-js `concatAST` joins it. The resolvers of each module are added in order, so a later module wins.

The result is a `SubgraphSchema`. It has these fields:

- `schema`: the executable `gql_schema` schema, with the federation types and fields.
- `resolvers`: the resolvers of `_service`, `_entities` and `_Entity`, then those of each module.
- `sdl`: the text of `_service.sdl`.

`SubgraphSchema.execute(document, args)` executes an operation. It does not validate the operation, and it does not read `args.resolvers`.

The resolvers of `_service` and `_entities` find the subgraph through a handle in the arena of the operation. `execute` adds the handle. When another executor runs the operation with `schema` and `resolvers.resolvers`, call `SubgraphSchema.attach(values)` on the arena of each operation. A `gql_server` plugin can call it in `execution_did_start`. [Compatibility](Compatibility) shows such a server.

## What federation adds

- For federation 1: the definitions of `@key`, `@requires`, `@provides`, `@external`, `@tag` and `@extends`, and `scalar _FieldSet`.
- For federation 2: the `@link` definition and its types, and each directive and type of the linked version. A name that is not imported gets the `federation__` prefix, or the prefix of the `as` argument.
- `scalar _Any`, `type _Service`, and `union _Entity` of each object type with a `@key`. The members are in the order of JavaScript `localeCompare`.
- `_entities(representations: [_Any!]!): [_Entity]!` when there is an entity, and `_service: _Service!`, on the query root type.

The supported versions are federation 1 and federation 2.0 to 2.15.

## Resolvers

`SubgraphResolvers` holds the resolver map of a module:

| Method | Upstream key |
| --- | --- |
| `field(type_name, field_name, resolve)` | A field resolver |
| `subscribe(type_name, field_name, subscribe)` | The `subscribe` key of a subscription field |
| `resolve_type(type_name, resolve)` | `__resolveType` |
| `is_type_of(type_name, check)` | `__isTypeOf` |
| `resolve_reference(type_name, resolve)` | `__resolveReference` |

A `ReferenceResolver` gets the arena, the representation, the context value and the `ResolveInfo`. It returns the entity, `null`, or an error value. The resolver gives the entity the `__typename` of its type. For an interface entity, the interface's `resolveType`, or the `__typename` of the value, gives the object type.

## Subscriptions and incremental delivery

A `subscribe` function returns the source event stream: a value that `Values.add_stream` made, such as the iterator of a `gql_stream` `PubSub`. `SubgraphSchema.subscribe(document, args)` runs a subscription, as graphql-js `subscribe` runs the schema of upstream. Each event of the stream gives one result. With no `subscribe` function, the call raises `Subscription field must return Async Iterable. Received: undefined.`, as graphql-js 16 does.

`SubgraphSchema.execute_incrementally(document, args)` runs `@defer` and `@stream`, as graphql-js 17 `experimentalExecuteIncrementally` runs the schema of upstream. The schema must define the directives. `@apollo/subgraph` adds nothing for them.

## Print a subgraph

`print_subgraph_schema(subgraph)` prints the SDL without what federation adds. It leaves out the federation definitions, the definitions of the graphql-js directives, `_entities`, `_service`, and the `@link` to the link specification.

## Differences from @apollo/subgraph

- **Federation checks.** Only the checks that a GraphQL schema needs run. These are the type, directive and `@link` checks, the graphql-js SDL rules and the schema validation. The checks of field sets, `@external`, `@requires`, `@provides`, `@shareable`, `@override` and the other federation directives do not run. Use [Composition](Composition) to validate a subgraph.
- **Resolver maps.** A `GraphQLScalarType` and the internal values of an enum cannot be given. A `subscribe` function returns a `gql_stream` event stream, not an async iterator.
- **Execution.** Execution is synchronous. A `__resolveReference` that raises fails the whole `_entities` field. One that returns an error value fails its item only, as a rejected promise does.
- **Errors.** An error message has no source excerpt. A value in a message is written as graphql-js `inspect` writes it, not as Node.js `util.inspect`.
- **Links.** Only the federation and link specifications can be linked. The link specification cannot be renamed, and its `import` argument is ignored.
- **Malformed links.** A `url` or an `as` that is not a string is ignored, and an `import` that is not a list is ignored. Upstream fails with a JavaScript `TypeError` or reads a string as a list of characters.
- **Schema definitions.** A second `schema` definition is an error, as the graphql-js rule `LoneSchemaDefinition` says. Upstream accepts it.
- **Version 2.15.** `@apollo/subgraph` 2.14.4 refuses `v2.15`. The specification of `v2.15` adds no directives or types, so this port accepts it.
- **Not ported.** `buildFederatedSchema`, the deprecated name, and `@cacheControl` hints.

## Tests

The tests are in `tests/gql_subgraph/`. They port `src/__tests__/buildSubgraphSchema.test.ts` and `src/__tests__/printSubgraphSchema.test.ts`. In `test_subscriptions.mojo`, the subscription of upstream runs, and each result is that of graphql-js `subscribe` in Node.js. The other cases compare the output of each path with `@apollo/subgraph` 2.14.4 in Node.js.

## Benchmarks

`bench/gql_subgraph/subgraph.mojo` runs against `@apollo/subgraph` 2.14.4 in `bench/baselines/js-subgraph/`. Both use `bench/fixtures/subgraph-catalog.graphql`, a federation 2.3 subgraph of 24 types.

| Workload | What it times |
| --- | --- |
| `subgraph/build-catalog` | Parse the SDL and build the subgraph schema |
| `subgraph/print-catalog` | `print_subgraph_schema` of the built schema |
| `subgraph/service-sdl` | Execute `{ _service { sdl } }` |
| `subgraph/entities-100` | Execute `_entities` with 100 representations and a `__resolveReference` |

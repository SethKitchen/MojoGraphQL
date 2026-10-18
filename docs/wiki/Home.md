<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# MojoGraphQL

MojoGraphQL is a GraphQL library in Mojo. It ports MIT licensed GraphQL projects, and each port must be faster than its upstream. Each part is a separate package, so you use only the parts that you need.

## How-to guides

- [How to install](How-to-install): install the toolchain and run the checks.
- [How to pick packages](How-to-pick-packages): build and use only the packages that you need.
- [How to add a feature](How-to-add-a-feature): port a part of an upstream project.
- [How to write documentation](How-to-write-documentation): the writing rules for this wiki.

## Reference

- [Language](Language): the `gql_language` package, which is the lexer, parser and printer.
- [Json](Json): the `gql_json` package, which is the JSON parser, document and writer.
- [Execution](Execution): the `gql_execution` package: execute operations, introspection and `buildClientSchema`.
- [Http](Http): the `gql_http` package, which is the HTTP/1.1 server, client and parser.
- [Validation](Validation): the `gql_validation` package, which checks an executable document against a schema.
- [Client](Client): the `gql_client` package, which is the normalized cache of a GraphQL client.
- [Composition](Composition): the `gql_composition` package, which validates Apollo Federation subgraphs.
- [Router](Router): the `gql_router` package, which ports the Hive Router query planner.
- [Subgraph](Subgraph): the `gql_subgraph` package, which builds an executable Apollo Federation subgraph.
- [Server](Server): the `gql_server` package, which is the Apollo Server port and its standalone HTTP server.
- [Mcp](Mcp): the `gql_mcp` package, which is the Model Context Protocol server of Apollo MCP Server.
- [Seamstress](Seamstress): the `gql_seamstress` package and its `seamstress` program, a port of the local commands of Apollo Rover: `supergraph compose`, `subgraph introspect` and `graph introspect`.
- [Codegen](Codegen): the `gql_codegen` package, which writes Mojo models for operations, as the Apollo Kotlin compiler writes Kotlin.
- [Compatibility](Compatibility): the result of each check of the Apollo Federation subgraph compatibility suite.
- [Coverage tool](Coverage-tool): what `make coverage` measures, and how.

## Explanation

- [Benchmarks](Benchmarks): how the project measures speed against the upstream libraries.

## Packages

The [README checklist](https://github.com/SethKitchen/MojoGraphQL#features) shows the status of each package.

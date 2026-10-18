<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Mcp

`gql_mcp` is a Model Context Protocol server that exposes GraphQL operations as tools. It is a port of the core of Apollo MCP Server 2.0.0 (`04e4e6e`). It needs `gql_language`, `gql_json`, `gql_schema`, `gql_validation` and `gql_http`.

| Module | Contents | Apollo MCP Server source |
| --- | --- | --- |
| `gql_mcp.server` | `McpServer`, `ServerConfig`: the MCP lifecycle and the tool calls | `server/states/running.rs` |
| `gql_mcp.stdio`, `http_transport` | The stdio and Streamable HTTP transports | `server/states/starting.rs` |
| `gql_mcp.jsonrpc` | JSON-RPC 2.0 messages | The MCP specification; `rmcp` is Apache-2.0 only, and is not read |
| `gql_mcp.operation`, `operation_source` | Operations as tools, from files | `operations/` |
| `gql_mcp.schema_walker`, `output_schema` | The JSON Schemas of the variables and of the result | `operations/schema_walker/` |
| `gql_mcp.tree_shake` | The schema tree shaker | `schema_tree_shake.rs` |
| `gql_mcp.schema_index`, `text_analysis`, `stemmer` | The search index of the schema | `crates/apollo-schema-index` |
| `gql_mcp.tools`, `builtin_tools` | The `introspect`, `search`, `execute` and `validate` tools | `introspection/tools/` |
| `gql_mcp.custom_scalar_map` | The JSON Schemas of custom scalars | `custom_scalar_map.rs` |

## Server

`McpServer(config, schema, operations)` makes a tool of each operation, and the built-in tools that `config` turns on. The schema must be valid, as the `Valid<Schema>` of upstream. The server answers `initialize`, `tools/list` and `tools/call`. An operation tool sends its operation to `config.endpoint` over HTTP, and returns the result as structured content.

## Built-in tools

| Tool | What it does |
| --- | --- |
| `introspect` | The SDL of a type and of the types around it, to a depth |
| `search` | The types of the schema that match some terms |
| `execute` | Sends an operation to the endpoint |
| `validate` | Checks an operation against the schema |

## Differences from Apollo MCP Server

- **Phase 1.** There is no authentication, no Rhai hooks, no apps, no prompts, no telemetry, no GraphOS registry or uplink, no hot reload and no `@private` fields. The configuration is a struct, not a YAML file.
- **Protocol.** The sessionless protocol 2026-07-28 is not ported. A `notifications/initialized` before `initialize` is ignored, where upstream ends the stdio session.
- **HTTP.** A stream has `Content-Length` and ends after the reply. There is no CORS, no host validation and no health check.
- **Operations.** The files are read once, in a fixed order. An operation that does not load is left out, and its error goes in `load_errors`.
- **Search.** The index adds the types in the order of the walk, so the order is the same on each run. Upstream uses the order of a Rust `HashMap`.
- **Messages.** A JSON error has the `gql_json` message, and a file error the message of the Mojo standard library.

Each module docstring lists its differences in full.

## Tests

The tests are in `tests/gql_mcp/`. They port the unit tests of the ported files of `crates/apollo-mcp-server/src` and of `crates/apollo-schema-index`. The expected output of the schema walker comes from upstream.

## Benchmarks

`bench/gql_mcp/` runs against Apollo MCP Server 2.0.0 in `bench/baselines/rust-mcp/`. The server workloads run both servers over stdio under the same Mojo driver, with the GitHub schema and 200 operations. The two servers give the same answers.

| Workload | What it times |
| --- | --- |
| `mcp/tools-list-200` | `tools/list` of 204 tools with output schemas |
| `mcp/call-operation` | `tools/call` of an operation, through a stub endpoint |
| `mcp/call-search` | `tools/call` of `search` with two terms |
| `mcp/call-introspect` | `tools/call` of `introspect` of `Repository` |
| `mcp/call-validate` | `tools/call` of `validate` of an operation |
| `mcp/tool-from-operation-large` | The tool of one large operation, in process |

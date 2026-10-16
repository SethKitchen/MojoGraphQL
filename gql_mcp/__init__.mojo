# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The `gql_mcp` package: a Model Context Protocol server that exposes GraphQL
operations as tools.

A port of Apollo MCP Server 2.0.0. JSON-RPC 2.0 messages and the MCP
lifecycle (`gql_mcp.jsonrpc`, `gql_mcp.server`), the stdio and Streamable
HTTP transports, operations as tools with JSON Schemas of their variables
and their results (`gql_mcp.operation`, `gql_mcp.schema_walker`,
`gql_mcp.output_schema`), the schema tree shaker (`gql_mcp.tree_shake`), the
schema search index (`gql_mcp.schema_index`), and the `introspect`,
`search`, `execute` and `validate` tools. See the Mcp page of the wiki.
"""

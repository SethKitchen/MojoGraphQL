# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""gql_scorchql: ScorchQL, a federated GraphQL gateway with an explorer.

ScorchQL joins the other packages into one gateway program:

- `gql_scorchql.registry` keeps the published subgraphs in a directory,
  and composes them with `gql_composition` on each publish.
- `gql_scorchql.introspect` reads the SDL of a running subgraph through
  `_service { sdl }`.
- `gql_scorchql.gateway` serves the supergraph with `gql_router_stream`,
  the explorer, and the registry endpoints over HTTP, SSE, multipart and
  `graphql-transport-ws` WebSocket. Each worker reloads its router when
  the registry revision changes.
- `gql_scorchql.explorer` is the web page of the explorer.
- `gql_scorchql.cli` reads the command line of the `scorchql` program.

`bin/scorchql.mojo` is the program. ScorchQL is original work: it ports no
upstream project.
"""

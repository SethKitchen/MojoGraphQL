# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""seamstress: the local, offline commands of Apollo Rover.

seamstress is a port of the MIT parts of Apollo Rover 1.0.0 (`39a041a`)
that work without GraphOS: `seamstress supergraph compose`, `seamstress
subgraph introspect` and `seamstress graph introspect`. The subcommands
and the flags are the Rover ones, so seamstress can replace `rover` for
these commands. The supergraph configuration format is the one of
`apollo-federation-types` 0.18.0-rc.1 (MIT). Composition runs
`gql_composition`, the Hive Federation Composition port, and never the
Elastic licensed `supergraph` binary. It needs `gql_language`,
`gql_json`, `gql_schema`, `gql_execution`, `gql_http` and
`gql_composition`.
"""

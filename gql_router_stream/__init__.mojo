# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""gql_router_stream: subscriptions and streamed `@defer` for gql_router.

Port of the streaming parts of Hive Router `1a29df9`: the subscription
configuration, the response mode negotiation, the SSE and multipart
response streams, the subgraph streams over HTTP and WebSocket, and the
execution of a subscription plan for each event. The package is apart
from `gql_router`, so that a router without subscriptions does not need
`gql_ws` and `gql_stream`.
"""

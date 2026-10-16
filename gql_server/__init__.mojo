# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A GraphQL server: the request pipeline, the HTTP handling and a
standalone HTTP server.

Port of Apollo Server 5.5.1 `packages/server/src`: `ApolloServer.ts`,
`requestPipeline.ts`, `runHttpQuery.ts`, `httpBatching.ts`,
`preventCsrf.ts`, `errorNormalize.ts`, `internalErrorClasses.ts`,
`errors/`, `cachePolicy.ts`, the header part of the cache control plugin
and `standalone/`. See the Server page of the wiki.
"""

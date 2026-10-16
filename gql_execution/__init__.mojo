# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""GraphQL execution: run an operation against a schema with resolvers,
and introspection.

Port of graphql-js 16.14.2 `src/execution`, `src/type/introspection.ts`
and the introspection utilities of `src/utilities`. See the Execution page
of the wiki.
"""

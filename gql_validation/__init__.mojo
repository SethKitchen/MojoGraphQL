# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""GraphQL validation: check an executable document against a schema.

Port of graphql-js 16.14.2 `src/validation` and
`src/utilities/TypeInfo.ts`. The four `@defer` and `@stream` rules of
`gql_validation.rules_incremental` are a port of graphql-js v17.0.2.

**Differences from upstream.** graphql-js v17.0.2 puts the `@defer`
and `@stream` rules in `specifiedRules`. Here they are not in
`specified_rules()`. Add `incremental_rules()` to the rule list to use
them.
"""

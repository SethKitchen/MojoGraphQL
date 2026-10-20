# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""gql_normalization: operation tooling of graphql-go-tools v2.

- `gql_normalization.normalize`: operation normalization, as
  `v2/pkg/astnormalization` `NormalizeOperation` and
  `NormalizeNamedOperation`.
- `gql_normalization.minify`: operation minification, as `v2/pkg/astminify`.
- `gql_normalization.variables_validation`: validation of the variables JSON
  of a request, as `v2/pkg/variablesvalidation`.

The passes edit a `gql_language` `Document` in place, against a `gql_schema`
`Schema`. See the Normalization page of the wiki.
"""

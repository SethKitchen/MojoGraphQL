# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""gql_compiler: a port of apollo-compiler, the semantic layer of
apollo-rs.

`gql_compiler.schema` holds the `Schema` model, and `gql_compiler.from_ast`
builds it from gql_language documents with `SchemaBuilder`. A schema keeps
its documents and points into them, so a build copies no AST data.
"""

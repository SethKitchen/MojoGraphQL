# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Code generation: Mojo models for GraphQL operations.

Port of Apollo Kotlin `apollo-compiler` (afe947c, 5.2.1-SNAPSHOT; the
benchmark runs the published 5.2.0), with the `operationBased` models.
`compiler.compile` validates the operation documents against a schema,
builds the IR, and writes one Mojo module with each operation, its
document and id, its variables and its data models.
"""

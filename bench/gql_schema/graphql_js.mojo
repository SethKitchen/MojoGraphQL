# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The graphql-js 16.14.2 `benchmark/` schema workloads.

- `buildASTSchema-benchmark.js`, "Build Schema from AST": the GitHub schema
  is parsed once, outside the timer, and only
  `buildASTSchema(schemaAST, { assumeValid: true })` is timed.
- `validateSDL-benchmark.js`, "Validate SDL Document": `validateSDL` of the
  parsed GitHub schema.
"""

from _harness import BuildAstSchema, ValidateSdl, fixture, measure


def main() raises:
    """Run the graphql-js workloads."""
    measure(
        "graphql-js/build-ast-schema",
        BuildAstSchema(fixture("github-schema.graphql")),
    )
    measure(
        "graphql-js/validate-sdl", ValidateSdl(fixture("github-schema.graphql"))
    )

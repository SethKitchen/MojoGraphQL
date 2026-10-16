# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The graphql-js 16.14.2 `benchmark/` validation workloads.

Both build the GitHub schema with `buildSchema(bigSchemaSDL, { assumeValid:
true })` and parse the document outside the timer. Only `validate(schema,
queryAST)` is timed.

- `validateGQL-benchmark.js`, "Validate Introspection Query": the document
  is `getIntrospectionQuery()`.
- `validateInvalidGQL-benchmark.js`, "Validate Invalid Query": the document
  has unknown fields, an unknown type and an unknown fragment.
"""

from _harness import Validate, assumed_valid_schema, fixture, measure

comptime INVALID_QUERY = """
  {
    unknownField
    ... on unknownType {
      anotherUnknownField
      ...unknownFragment
    }
  }

  fragment TestFragment on anotherUnknownType {
    yetAnotherUnknownField
  }
"""
"""The document of `validateInvalidGQL-benchmark.js`."""


def main() raises:
    """Run the graphql-js workloads."""
    var sdl = fixture("github-schema.graphql")
    measure(
        "graphql-js/validate-introspection-query",
        Validate(
            assumed_valid_schema(sdl),
            fixture("graphql-js-introspection-query.graphql"),
        ),
    )
    measure(
        "graphql-js/validate-invalid-query",
        Validate(assumed_valid_schema(sdl), INVALID_QUERY),
    )

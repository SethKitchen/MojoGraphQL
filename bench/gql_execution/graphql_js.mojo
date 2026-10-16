# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The graphql-js 16.14.2 `benchmark/` execution workloads.

- `introspectionFromSchema-benchmark.js`, "Execute Introspection Query":
  the GitHub schema is built with `assumeValid: true` and the
  `getIntrospectionQuery()` document is parsed outside the timer. Only
  `executeSync({ schema, document })` is timed.
- `repeated-fields-benchmark.js`, "Many repeated fields": `{ hello hello
  ... }` with 250 `hello` fields on `type Query { hello: String! }`.
  Upstream times `graphqlSync`, which parses, validates and executes.
  Validation is the `gql_validation` package, which `gql_execution` does
  not depend on, so this workload times parse and execute, and the
  baseline times graphql-js `parse` and `executeSync` the same way.
- `buildClientSchema-benchmark.js`, "Build Schema from Introspection":
  the GitHub introspection result is parsed outside the timer, and only
  `buildClientSchema(result.data, { assumeValid: true })` is timed.
"""

from _harness import BuildClientSchema, Execute, ParseExecute, fixture, measure


def main() raises:
    """Run the graphql-js workloads."""
    measure(
        "graphql-js/execute-introspection-query",
        Execute(
            fixture("github-schema.graphql"),
            fixture("graphql-js-introspection-query.graphql"),
        ),
    )
    measure(
        "graphql-js/repeated-fields-parse-execute",
        ParseExecute(
            "type Query { hello: String! }",
            "{ " + "hello " * 250 + "}",
        ),
    )
    measure(
        "graphql-js/build-client-schema",
        BuildClientSchema(fixture("github-schema.json")),
    )

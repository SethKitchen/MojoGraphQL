# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The graphql-js 16.14.2 `benchmark/` workloads.

- `parser-benchmark.js`, "Parse introspection query":
  `parse(getIntrospectionQuery())`.
- `printer-benchmark.js`, "Print kitchen sink document": the document is
  parsed once, outside the timer, and only `print(document)` is timed.
"""

from _harness import Parse, Print, fixture, measure


def main() raises:
    """Run the graphql-js workloads."""
    measure(
        "graphql-js/parse-introspection-query",
        Parse(fixture("graphql-js-introspection-query.graphql")),
    )
    measure(
        "graphql-js/print-kitchen-sink", Print(fixture("kitchen-sink.graphql"))
    )

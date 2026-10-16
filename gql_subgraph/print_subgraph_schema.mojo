# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Print a subgraph schema without what federation adds, as
`printSubgraphSchema`.

Port of `@apollo/subgraph` 2.14.4 `src/printSubgraphSchema.ts` (MIT).
Upstream turns the graphql-js schema back into SDL, builds the subgraph
again with `@apollo/federation-internals` (Elastic licensed, not read), and
prints it with its `toString`. This port prints the model that
`build_subgraph_schema` kept, with the types in the order of the
executable schema, as upstream reads them from the graphql-js type map.

**Differences from upstream.**

- `print_subgraph_schema` takes a `SubgraphSchema`, not any schema.
- `printIntrospectionSchema`, `printType` and `printBlockString`, which
  `src/index.ts` does not export, are not ported.
"""

from gql_subgraph.build_subgraph_schema import SubgraphSchema
from gql_subgraph.printer import PrintMode, print_model


def print_subgraph_schema(subgraph: SubgraphSchema) -> String:
    """Print the SDL of a subgraph without the federation definitions, the
    `_entities` and `_service` fields, and the `@link` to the link
    specification.

    Args:
        subgraph: The subgraph schema.

    Returns:
        The SDL, with no line break at the end.
    """
    return print_model(subgraph.model, PrintMode.SUBGRAPH, subgraph.order)

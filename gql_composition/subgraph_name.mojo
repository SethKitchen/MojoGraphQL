# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A subgraph id must not start with `__`.

Port of `SubgraphNameRule` of Hive Federation Composition v0.27.0
`src/supergraph/validation/rules/subgraph-name-rule.ts`.

The id is the constant-case form of the subgraph name. `__` is reserved
for GraphQL introspection.
"""

from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.later_versions import GraphFacts


def check_subgraph_names(facts: List[GraphFacts]) -> List[CompositionError]:
    """Report a subgraph id that starts with `__`.

    Args:
        facts: The subgraphs, in id order, after a clean subgraph phase.

    Returns:
        The `INVALID_GRAPHQL` errors for reserved ids.
    """
    var errors = List[CompositionError]()
    var index = 0
    while index < len(facts):
        var graph_id = String(facts[index].graph_id)
        index += 1
        if not graph_id.startswith("__"):
            continue
        errors.append(
            CompositionError(
                'Name "'
                + graph_id
                + '" must not begin with "__", which is reserved by GraphQL'
                " introspection.",
                ErrorCode.INVALID_GRAPHQL,
                None,
            )
        )
    return errors^

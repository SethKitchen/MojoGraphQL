# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""An interface cannot be an `@interfaceObject` in every subgraph.

Port of `InterfaceObjectUsageErrorRule` of Hive Federation Composition
v0.27.0 `src/supergraph/validation/rules/interface-object-usage-error.ts`.

The message keeps upstream's wording, including "is is defined".
"""

from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.later_versions import GraphFacts
from gql_composition.merged import type_names
from gql_composition.state import TypeKind


def check_interface_object_usage(
    facts: List[GraphFacts], mut found: List[String]
) -> List[CompositionError]:
    """Report an interface that is an `@interfaceObject` everywhere.

    Args:
        facts: The subgraphs, in id order, after a clean subgraph phase.
        found: Receives the interface name for each error, in the same
            order.

    Returns:
        The `INTERFACE_OBJECT_USAGE_ERROR` errors.
    """
    var errors = List[CompositionError]()
    var names = type_names(facts, TypeKind.INTERFACE)
    for index in range(len(names)):
        var name = String(names[index])
        if not _all_interface_objects(facts, name):
            continue
        found.append(name)
        errors.append(
            CompositionError(
                'Type "'
                + name
                + '" is declared with @interfaceObject in all the subgraphs in'
                " which is is defined",
                ErrorCode.INTERFACE_OBJECT_USAGE_ERROR,
                None,
            )
        )
    return errors^


def _all_interface_objects(facts: List[GraphFacts], name: String) -> Bool:
    """Return True when every definition is an `@interfaceObject`.

    Args:
        facts: The subgraphs, in id order.
        name: The interface name.

    Returns:
        Whether Hive reports the interface. The name comes from a
        subgraph, so some subgraph defines it.
    """
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find_kind(name, TypeKind.INTERFACE)
        if type_at == -1:
            continue
        if not graph.types[type_at].is_interface_object:
            return False
    return True

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""An object extension needs a type definition in some subgraph.

Port of `ExtensionWithBaseRule` of Hive Federation Composition v0.27.0
`src/supergraph/validation/rules/extension-with-base.ts`.

`Query`, `Mutation` and `Subscription` are skipped. A Federation 1
`@extends` type is not a definition. When every subgraph is Federation 1
and every one uses `@extends`, Hive reports nothing.
"""

from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.later_versions import GraphFacts, TypeFacts
from gql_composition.merged import type_names
from gql_composition.state import ExtensionType, TypeKind


def check_extension_with_no_base(
    facts: List[GraphFacts], mut found: List[String]
) -> List[CompositionError]:
    """Report an object that is only an extension.

    Args:
        facts: The subgraphs, in id order, after a clean subgraph phase.
        found: Receives the type name for each error, in the same
            order.

    Returns:
        The `EXTENSION_WITH_NO_BASE` errors, in first-seen type order.
    """
    var names = type_names(facts, TypeKind.OBJECT)
    var errors = List[CompositionError]()
    var name_index = 0
    while name_index < len(names):
        var name = String(names[name_index])
        name_index += 1
        if name == "Query" or name == "Mutation" or name == "Subscription":
            continue
        var count = 0
        var all_fed1_extends = True
        var has_definition = False
        var graph_names = List[String]()
        var graph_index = 0
        while graph_index < len(facts):
            ref graph = facts[graph_index]
            graph_index += 1
            var at = graph.find_kind(name, TypeKind.OBJECT)
            if at == -1:
                continue
            ref type = graph.types[at]
            count += 1
            graph_names.append(String(graph.graph_name))
            if _counts_as_definition(graph, type):
                has_definition = True
            if (
                graph.version_number != 100
                or type.extension_type != ExtensionType.EXTENDS
            ):
                all_fed1_extends = False
        if has_definition:
            continue
        if count > 1 and all_fed1_extends:
            continue
        var name_at = 0
        while name_at < len(graph_names):
            found.append(String(name))
            errors.append(
                CompositionError(
                    "["
                    + graph_names[name_at]
                    + '] Type "'
                    + name
                    + '" is an extension type, but there is no type'
                    + ' definition for "'
                    + name
                    + '" in any subgraph.',
                    ErrorCode.EXTENSION_WITH_NO_BASE,
                    None,
                )
            )
            name_at += 1
    return errors^


def _counts_as_definition(graph: GraphFacts, type: TypeFacts) -> Bool:
    """Return True when Hive treats the type as a definition.

    Args:
        graph: The subgraph that owns the type.
        type: The object type.

    Returns:
        Whether `isDefinition` is true in `object-type.ts`.
    """
    if not type.is_definition:
        return False
    if (
        graph.version_number == 100
        and type.extension_type == ExtensionType.EXTENDS
    ):
        return False
    return True

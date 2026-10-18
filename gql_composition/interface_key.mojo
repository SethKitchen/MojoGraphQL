# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""An interface `@key` needs every implementation type in that subgraph.

Port of `InterfaceKeyMissingImplementationTypeRule` of Hive Federation
Composition v0.27.0
`src/supergraph/validation/rules/interface-key-missing-implementation-type.ts`.

The rule skips an `@interfaceObject` interface. It also skips a subgraph
older than federation `v2.3` when it decides whether any subgraph is
missing an implementation. The reported key is the first `@key`.
"""

from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.later_versions import GraphFacts
from gql_composition.merged import append_new, contains, type_names
from gql_composition.state import TypeKind


def check_interface_key(
    facts: List[GraphFacts], mut found: List[String]
) -> List[CompositionError]:
    """Report a keyed interface that a subgraph does not fully implement.

    Args:
        facts: The subgraphs, in id order, after a clean subgraph phase.
        found: Receives the interface name for each error, in the same
            order.

    Returns:
        The `INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE` errors.
    """
    var errors = List[CompositionError]()
    var names = type_names(facts, TypeKind.INTERFACE)
    for index in range(len(names)):
        _check_interface(facts, String(names[index]), errors, found)
    return errors^


def _check_interface(
    facts: List[GraphFacts],
    interface_name: String,
    mut errors: List[CompositionError],
    mut found: List[String],
):
    """Append the errors for one interface.

    Args:
        facts: The subgraphs, in id order.
        interface_name: The interface.
        errors: The errors to append.
        found: Receives the interface name for each error.
    """
    if not _is_entity(facts, interface_name):
        return
    if _has_interface_object(facts, interface_name):
        return
    if not _some_subgraph_has_no_implementation(facts, interface_name):
        return
    var merged = _merged_implementers(facts, interface_name)
    sort(merged)
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find_kind(interface_name, TypeKind.INTERFACE)
        if type_at == -1:
            continue
        ref type = graph.types[type_at]
        if len(type.keys) == 0:
            continue
        var missing = _missing(merged, type.implemented_by)
        found.append(String(interface_name))
        errors.append(
            CompositionError(
                _message(
                    graph.graph_name,
                    interface_name,
                    type.keys[0],
                    missing,
                ),
                ErrorCode.INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE,
                None,
            )
        )


def _some_subgraph_has_no_implementation(
    facts: List[GraphFacts], interface_name: String
) -> Bool:
    """Return True when a `v2.3` subgraph has a key and no implementer.

    Args:
        facts: The subgraphs, in id order.
        interface_name: The interface.

    Returns:
        Whether Hive sets `someSubgraphsAreMissingImplementation`.
    """
    # The caller has already returned when a subgraph uses
    # `@interfaceObject`, so `isInterfaceObject` is false here.
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find_kind(interface_name, TypeKind.INTERFACE)
        if type_at == -1:
            continue
        ref type = graph.types[type_at]
        if graph.version_number < 203:
            continue
        if len(type.keys) == 0:
            continue
        if len(type.implemented_by) == 0:
            return True
    return False


def _message(
    graph_name: String,
    interface_name: String,
    key_fields: String,
    missing: List[String],
) -> String:
    """Return one Hive message.

    Args:
        graph_name: The subgraph name.
        interface_name: The interface.
        key_fields: The first `@key` field set.
        missing: The implementation types that subgraph does not define,
            sorted.

    Returns:
        The error message, including the `[subgraph]` prefix.
    """
    var word = String("type")
    var pronoun = String("it")
    if len(missing) > 1:
        word = "types"
        pronoun = "them"
    return (
        "["
        + graph_name
        + '] Interface type "'
        + interface_name
        + '" has a resolvable key (@key(fields: "'
        + key_fields
        + '")) in subgraph "'
        + graph_name
        + '" but that subgraph is missing some of the supergraph implementation'
        ' types of "'
        + interface_name
        + '". Subgraph "'
        + graph_name
        + '" should define '
        + word
        + " "
        + _join_and(missing)
        + " (and have "
        + pronoun
        + ' implement "'
        + interface_name
        + '").'
    )


def _join_and(names: List[String]) -> String:
    """Quote names the way Hive's `joinWithAnd` does.

    Args:
        names: The type names, already sorted.

    Returns:
        Such as `"A"`, `"A" and "B"`, or `"A", "B" and "C"`.
    """
    var count = len(names)
    if count == 0:
        return String('""')
    if count == 1:
        return '"' + names[0] + '"'
    if count == 2:
        return '"' + names[0] + '" and "' + names[1] + '"'
    var head = '"' + names[0] + '"'
    var index = 1
    var last = count - 1
    while index < last:
        head += ', "' + names[index] + '"'
        index += 1
    return head + ' and "' + names[last] + '"'


def _missing(merged: List[String], local: List[String]) -> List[String]:
    """Return merged implementers that one subgraph does not define.

    Args:
        merged: Every implementer, sorted.
        local: The implementers in one subgraph.

    Returns:
        The names from `merged` that are not in `local`, in sorted order.
    """
    var names = List[String]()
    for index in range(len(merged)):
        if not contains(local, merged[index]):
            names.append(String(merged[index]))
    return names^


def _merged_implementers(
    facts: List[GraphFacts], interface_name: String
) -> List[String]:
    """Return every object that implements an interface.

    Args:
        facts: The subgraphs, in id order.
        interface_name: The interface.

    Returns:
        The object names, once each, before sorting.
    """
    var names = List[String]()
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find_kind(interface_name, TypeKind.INTERFACE)
        if type_at == -1:
            continue
        ref local = graph.types[type_at].implemented_by
        for index in range(len(local)):
            append_new(names, local[index])
    return names^


def _is_entity(facts: List[GraphFacts], interface_name: String) -> Bool:
    """Return True when any subgraph gives the interface a `@key`.

    Args:
        facts: The subgraphs, in id order.
        interface_name: The interface.

    Returns:
        Whether the merged interface is an entity.
    """
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find_kind(interface_name, TypeKind.INTERFACE)
        if type_at == -1:
            continue
        if len(graph.types[type_at].keys) > 0:
            return True
    return False


def _has_interface_object(
    facts: List[GraphFacts], interface_name: String
) -> Bool:
    """Return True when any subgraph uses `@interfaceObject`.

    Args:
        facts: The subgraphs, in id order.
        interface_name: The interface.

    Returns:
        Whether the merged interface has an `@interfaceObject`.
    """
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find_kind(interface_name, TypeKind.INTERFACE)
        if type_at == -1:
            continue
        if graph.types[type_at].is_interface_object:
            return True
    return False

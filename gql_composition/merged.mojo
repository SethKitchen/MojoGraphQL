# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Lookups over the facts of all subgraphs, for the supergraph rules.

Upstream merges the subgraphs into one supergraph state with maps, and
each rule of `src/supergraph/validation/rules/` reads that state. The
rules of this port read the `GraphFacts` of each subgraph. These helpers
give the merged names in first-seen order, the order of the upstream
maps, and find a type or a field in one subgraph by name.
"""

from std.collections import Dict
from gql_composition.later_versions import GraphFacts
from gql_composition.state import TypeKind


struct NameList(Movable):
    """Names in first-seen order, each once."""

    var names: List[String]
    """The names, in the order they were first added."""
    var seen: Dict[String, Bool]
    """The names in `names`."""

    def __init__(out self):
        """Create an empty list."""
        self.names = List[String]()
        self.seen = Dict[String, Bool]()

    def add(mut self, name: String):
        """Add a name that is not already present.

        Args:
            name: The name.
        """
        if name in self.seen:
            return
        self.seen[name] = True
        self.names.append(name)


def append_new(mut names: List[String], name: String):
    """Append a name to a short list when it is not already present.

    Args:
        names: The names so far.
        name: The name to append.
    """
    for index in range(len(names)):
        if names[index] == name:
            return
    names.append(name)


def contains(names: List[String], name: String) -> Bool:
    """Return True when a short list has a name.

    Args:
        names: The names.
        name: The name to find.

    Returns:
        Whether the name is present.
    """
    for index in range(len(names)):
        if names[index] == name:
            return True
    return False


def type_names(facts: List[GraphFacts], kind: TypeKind) -> List[String]:
    """Return the type names of one kind, in first-seen order.

    Args:
        facts: The subgraphs, in id order.
        kind: The kind.

    Returns:
        The names, once each.
    """
    var names = NameList()
    var graph_index = 0
    while graph_index < len(facts):
        ref types = facts[graph_index].types
        var type_index = 0
        while type_index < len(types):
            if types[type_index].kind == kind:
                names.add(types[type_index].name)
            type_index += 1
        graph_index += 1
    return names.names.copy()


def field_names(
    facts: List[GraphFacts], type_name: String, kind: TypeKind
) -> List[String]:
    """Return the fields of one type, in first-seen order.

    Args:
        facts: The subgraphs, in id order.
        type_name: The type name.
        kind: The kind of the type.

    Returns:
        The field names, once each.
    """
    var names = NameList()
    var graph_index = 0
    while graph_index < len(facts):
        var at = facts[graph_index].find_kind(type_name, kind)
        if at != -1:
            ref fields = facts[graph_index].types[at].fields
            var field_index = 0
            while field_index < len(fields):
                names.add(fields[field_index].name)
                field_index += 1
        graph_index += 1
    return names.names.copy()


def arg_names(
    facts: List[GraphFacts],
    type_name: String,
    kind: TypeKind,
    field_name: String,
) -> List[String]:
    """Return the arguments of one field, in first-seen order.

    Args:
        facts: The subgraphs, in id order.
        type_name: The type name.
        kind: The kind of the type.
        field_name: The field name.

    Returns:
        The argument names, once each.
    """
    var names = NameList()
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var at = graph.find_kind(type_name, kind)
        if at == -1:
            continue
        var field = graph.types[at].find_field(field_name)
        if field == -1:
            continue
        ref args = graph.types[at].fields[field].arg_facts
        for arg_index in range(len(args)):
            names.add(args[arg_index].name)
    return names.names.copy()


def has_field(
    facts: List[GraphFacts],
    type_name: String,
    kind: TypeKind,
    field_name: String,
) -> Bool:
    """Return True when any subgraph defines a field of a type.

    Args:
        facts: The subgraphs, in id order.
        type_name: The type name.
        kind: The kind of the type.
        field_name: The field name.

    Returns:
        Whether a subgraph has the field.
    """
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        var at = graph.find_kind(type_name, kind)
        if at != -1 and graph.types[at].find_field(field_name) != -1:
            return True
        graph_index += 1
    return False


def subgraph_place(names: List[String]) -> String:
    """Return the `subgraph` or `subgraphs` list of a Hive message.

    Args:
        names: The subgraph names.

    Returns:
        Such as `subgraph "users"` or `subgraphs "a", "b"`.
    """
    var plural = String("")
    if len(names) > 1:
        plural = "s"
    return "subgraph" + plural + ' "' + String('", "').join(names) + '"'


def and_list(names: List[String]) -> String:
    """Quote names with Hive's `andList` and an Oxford comma.

    Args:
        names: The names. The list must not be empty.

    Returns:
        Such as `"a"`, `"a" and "b"` or `"a", "b", and "c"`.
    """
    var last = len(names) - 1
    if last == 0:
        return '"' + names[0] + '"'
    var head = '"' + names[0]
    var index = 1
    while index < last:
        head += '", "' + names[index]
        index += 1
    if last == 1:
        return head + '" and "' + names[last] + '"'
    return head + '", and "' + names[last] + '"'

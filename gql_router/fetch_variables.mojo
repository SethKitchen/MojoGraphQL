# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Choose the variables and the condition branch of one fetch.

Port of `select_fetch_variables` and `condition_node_by_variables` in
Hive Router `1a29df9` `bin/router/src/executor/execution/plan.rs`.

A fetch receives only the variables named in its usage list. A name
that the request does not provide is left out. No usage list means the
fetch receives no variables. A condition runs its `if` branch only when
the variable is the boolean `true`. Any other value runs the `else`
branch. A missing variable runs neither branch.
"""

from gql_json.parser import parse
from gql_json.value import JsonKind
from gql_router.ast import NONE


@fieldwise_init
struct FetchVariables(Copyable, Movable):
    """The variables sent with one fetch."""

    var present: Bool
    """True when a usage list selected variables. False when there is no list."""
    var names: List[String]
    """The variable names, in alphabetical order."""
    var values: List[String]
    """The JSON text of each variable, parallel to `names`."""


def select_fetch_variables(
    has_values: Bool,
    names: List[String],
    values: List[String],
    has_usages: Bool,
    usages: List[String],
) -> FetchVariables:
    """Keep the variables a fetch uses.

    Args:
        has_values: True when the request has a variable map.
        names: The request variable names.
        values: The JSON text of each request variable, parallel to `names`.
        has_usages: True when the fetch lists the variables it uses.
        usages: Those variable names.

    Returns:
        The selected variables. `present` is false when the request has no
        variable map or the fetch has no usage list.
    """
    if not has_values or not has_usages:
        return FetchVariables(False, List[String](), List[String]())
    var selected_names = List[String]()
    var selected_values = List[String]()
    for index in range(len(usages)):
        var place = _index(names, values, usages[index])
        if place < 0:
            continue
        if _listed(selected_names, usages[index]):
            continue
        selected_names.append(String(usages[index]))
        selected_values.append(String(values[place]))
    _sort_pairs(selected_names, selected_values)
    return FetchVariables(True, selected_names^, selected_values^)


@fieldwise_init
struct BatchAliasPayload(Copyable, Movable):
    """One alias in a batch fetch."""

    var alias: String
    """The alias, such as `_e0`."""
    var variable: String
    """The representations variable name."""
    var representations: String
    """The representations JSON. Empty means an empty array."""


@fieldwise_init
struct BatchPayloads(Copyable, Movable):
    """The representation variables of a batch, with shared names kept once."""

    var names: List[String]
    """The variable names, in first-seen order."""
    var values: List[String]
    """The JSON of each variable, parallel to `names`."""


def batch_variable_payloads(aliases: List[BatchAliasPayload]) -> BatchPayloads:
    """Keep one representations payload for each variable name.

    Args:
        aliases: The batch aliases, in order.

    Returns:
        The first payload of each variable name. A later alias with the
        same name does not replace it. An empty payload is `[]`.
    """
    var names = List[String]()
    var values = List[String]()
    for index in range(len(aliases)):
        if _listed(names, aliases[index].variable):
            continue
        names.append(String(aliases[index].variable))
        var payload = String(aliases[index].representations)
        if payload.byte_length() == 0:
            payload = String("[]")
        values.append(payload^)
    return BatchPayloads(names^, values^)


def condition_target(
    has_values: Bool,
    names: List[String],
    values: List[String],
    variable: String,
    if_clause: Int,
    else_clause: Int,
) -> Int:
    """Choose the node a condition runs.

    Args:
        has_values: True when the request has a variable map.
        names: The request variable names.
        values: The JSON text of each request variable, parallel to `names`.
        variable: The condition variable name.
        if_clause: The node for boolean `true`, or `NONE`.
        else_clause: The node for every other value, or `NONE`.

    Returns:
        The chosen node. `NONE` when the variable map or the variable is
        absent, or the chosen branch is `NONE`.
    """
    if not has_values:
        return NONE
    var place = _index(names, values, variable)
    if place < 0:
        return NONE
    if _is_true(values[place]):
        return if_clause
    return else_clause


def _index(names: List[String], values: List[String], name: String) -> Int:
    """Return the index of a variable.

    Args:
        names: The variable names.
        values: The variable values. The search stops at the shorter list.
        name: The variable to find.

    Returns:
        The index. `-1` when the name is absent.
    """
    var limit = len(names)
    if len(values) < limit:
        limit = len(values)
    for index in range(limit):
        if names[index] == name:
            return index
    return -1


def _is_true(text: String) -> Bool:
    """Return True when JSON text is the boolean `true`.

    Args:
        text: One JSON value.

    Returns:
        Whether the value is boolean `true`. Invalid JSON is false.
    """
    try:
        var document = parse(text)
        return document.kind(
            document.root
        ) == JsonKind.BOOLEAN and document.bool_value(document.root)
    except e:
        _ = String(e)
        return False


def _listed(names: List[String], name: String) -> Bool:
    """Return True when a name is present.

    Args:
        names: The names.
        name: The candidate.

    Returns:
        Whether `name` is present.
    """
    for index in range(len(names)):
        if names[index] == name:
            return True
    return False


def _sort_pairs(mut names: List[String], mut values: List[String]):
    """Sort variable pairs by name.

    Args:
        names: The variable names.
        values: The variable values, parallel to `names`.
    """
    var index = 1
    var limit = len(names)
    if len(values) < limit:
        limit = len(values)
    while index < limit:
        var name = String(names[index])
        var value = String(values[index])
        var cursor = index
        while cursor > 0 and names[cursor - 1] > name:
            names[cursor] = String(names[cursor - 1])
            values[cursor] = String(values[cursor - 1])
            cursor -= 1
        names[cursor] = name^
        values[cursor] = value^
        index += 1

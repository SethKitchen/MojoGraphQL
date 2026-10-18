# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Field and directive arguments must agree across subgraphs.

Port of `FieldArgumentsOfTheSameTypeRule` of Hive Federation Composition
v0.27.0 `src/supergraph/validation/rules/field-arguments-of-the-same-type-rule.ts`.

A non-null argument is compatible with the same nullable type. A
directive argument is checked only when the directive can apply to an
executable location and every subgraph defines that argument.
"""

from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.later_versions import GraphFacts
from gql_composition.merged import (
    and_list,
    append_new,
    arg_names,
    field_names,
    subgraph_place,
    type_names,
)
from gql_composition.state import TypeKind


@fieldwise_init
struct _Site(Movable):
    """One subgraph's type for an argument."""

    var graph_name: String
    """The subgraph name."""
    var type_text: String
    """The printed type in that subgraph."""


@fieldwise_init
struct _Group(Movable):
    """One normalized argument type and the subgraphs that use it."""

    var type_text: String
    """The normalized type."""
    var graphs: List[String]
    """The subgraph names, in id order."""


def check_field_arguments(
    facts: List[GraphFacts], mut found: List[String]
) -> List[CompositionError]:
    """Report arguments whose types are incompatible across subgraphs.

    Args:
        facts: The subgraphs, in id order, after a clean subgraph phase.
        found: Receives `Type.field` for each object-field error, and
            `@` plus the directive name for each directive error.

    Returns:
        The `FIELD_ARGUMENT_TYPE_MISMATCH` errors. Object fields come
        before directives.
    """
    var errors = List[CompositionError]()
    _object_arguments(facts, errors, found)
    _directive_arguments(facts, errors, found)
    return errors^


def _object_arguments(
    facts: List[GraphFacts],
    mut errors: List[CompositionError],
    mut found: List[String],
):
    """Append object-field argument errors, in Hive's visitor order.

    Args:
        facts: The subgraphs, in id order.
        errors: The errors to append.
        found: Receives `Type.field` for each error.
    """
    var all_type_names = type_names(facts, TypeKind.OBJECT)
    var type_index = 0
    while type_index < len(all_type_names):
        var type_name = String(all_type_names[type_index])
        type_index += 1
        var all_field_names = field_names(facts, type_name, TypeKind.OBJECT)
        var field_index = 0
        while field_index < len(all_field_names):
            var field_name = String(all_field_names[field_index])
            field_index += 1
            var all_arg_names = arg_names(
                facts, type_name, TypeKind.OBJECT, field_name
            )
            for arg_index in range(len(all_arg_names)):
                var arg_name = String(all_arg_names[arg_index])
                var sites = _object_sites(
                    facts, type_name, field_name, arg_name
                )
                _report_object(
                    errors, found, type_name, field_name, arg_name, sites
                )


def _directive_arguments(
    facts: List[GraphFacts],
    mut errors: List[CompositionError],
    mut found: List[String],
):
    """Append directive argument errors.

    Args:
        facts: The subgraphs, in id order.
        errors: The errors to append.
        found: Receives `@` plus the directive name for each error.
    """
    var names = _directive_names(facts)
    var graph_count = len(facts)
    for name_index in range(len(names)):
        var name = String(names[name_index])
        if not _any_executable(facts, name):
            continue
        var all_arg_names = _directive_arg_names(facts, name)
        for arg_index in range(len(all_arg_names)):
            var arg_name = String(all_arg_names[arg_index])
            var sites = _directive_sites(facts, name, arg_name)
            if len(sites) != graph_count:
                continue
            _report_directive(errors, found, name, arg_name, sites)


def _report_object(
    mut errors: List[CompositionError],
    mut found: List[String],
    type_name: String,
    field_name: String,
    arg_name: String,
    sites: List[_Site],
):
    """Append one object-argument error when the normalized types differ.

    Args:
        errors: The errors to append.
        found: Receives `Type.field` when an error is appended.
        type_name: The parent type.
        field_name: The field.
        arg_name: The argument.
        sites: The subgraphs that define the argument, in id order. The
            argument name comes from a subgraph, so it is not empty.
    """
    var groups = _normalized_groups(sites)
    if len(groups) < 2:
        return
    found.append(type_name + "." + field_name)
    errors.append(
        CompositionError(
            'Type of argument "'
            + type_name
            + "."
            + field_name
            + "("
            + arg_name
            + ':)" is incompatible across subgraphs: it has '
            + _join_field_groups(groups),
            ErrorCode.FIELD_ARGUMENT_TYPE_MISMATCH,
            None,
        )
    )


def _report_directive(
    mut errors: List[CompositionError],
    mut found: List[String],
    name: String,
    arg_name: String,
    sites: List[_Site],
):
    """Append one directive-argument error when the raw types differ.

    Args:
        errors: The errors to append.
        found: Receives `@` plus the directive name when an error is
            appended.
        name: The directive name, without `@`.
        arg_name: The argument.
        sites: Every subgraph, in id order.
    """
    var groups = _raw_groups(sites)
    if len(groups) < 2:
        return
    found.append("@" + name)
    errors.append(
        CompositionError(
            'Type of argument "@'
            + name
            + "("
            + arg_name
            + ':)" is incompatible across subgraphs: it has '
            + _join_directive_groups(groups),
            ErrorCode.FIELD_ARGUMENT_TYPE_MISMATCH,
            None,
        )
    )


def _normalized_groups(sites: List[_Site]) -> List[_Group]:
    """Group argument sites the way Hive normalizes output types.

    Args:
        sites: The subgraphs, in id order. Must not be empty.

    Returns:
        The groups, in first-seen order.
    """
    var super_type = String(sites[0].type_text)
    for index in range(1, len(sites)):
        if sites[index].type_text.endswith("!"):
            super_type = String(sites[index].type_text)
    var groups = List[_Group]()
    var index = 0
    while index < len(sites):
        ref site = sites[index]
        _add_group(
            groups,
            _normalize(super_type, site.type_text),
            site.graph_name,
        )
        index += 1
    return groups^


def _raw_groups(sites: List[_Site]) -> List[_Group]:
    """Group directive arguments by their printed type.

    Args:
        sites: The subgraphs, in id order.

    Returns:
        The groups, in first-seen order.
    """
    var groups = List[_Group]()
    var index = 0
    while index < len(sites):
        ref site = sites[index]
        _add_group(groups, site.type_text, site.graph_name)
        index += 1
    return groups^


def _normalize(super_type: String, local: String) -> String:
    """Return the type Hive uses to group one subgraph's argument.

    Args:
        super_type: The merged argument type.
        local: The argument type in one subgraph.

    Returns:
        The local type, or the local type with `!` added when the merged
        type is non-null and the names match.
    """
    var super_base = _strip_one_bang(super_type)
    var local_base = _strip_one_bang(local)
    if super_base != local_base:
        return local
    if not super_type.endswith("!"):
        return local
    if local.endswith("!"):
        return local
    return local + "!"


def _strip_one_bang(text: String) -> String:
    """Drop one trailing `!`.

    Args:
        text: A printed type.

    Returns:
        The type without a trailing `!`.
    """
    if not text.endswith("!"):
        return text
    var end = text.byte_length() - 1
    return String(text[byte=0:end])


def _add_group(mut groups: List[_Group], type_text: String, graph_name: String):
    """Add a subgraph to the group for a type, or start that group.

    Args:
        groups: The groups so far.
        type_text: The normalized or raw type.
        graph_name: The subgraph name.
    """
    for index in range(len(groups)):
        if groups[index].type_text == type_text:
            groups[index].graphs.append(String(graph_name))
            return
    var graphs = List[String]()
    graphs.append(String(graph_name))
    groups.append(_Group(String(type_text), graphs^))


def _join_field_groups(groups: List[_Group]) -> String:
    """Join object-argument groups with Hive's `but` and `and`.

    Args:
        groups: At least two groups.

    Returns:
        The text after `it has `.
    """
    var message = _field_group(groups[0]) + " but " + _field_group(groups[1])
    for index in range(2, len(groups)):
        message += " and " + _field_group(groups[index])
    return message


def _field_group(group: _Group) -> String:
    """Return one object-argument group, as Hive prints it.

    Args:
        group: The type and its subgraphs.

    Returns:
        Such as `type "String!" in subgraph "feed"`.
    """
    return 'type "' + group.type_text + '" in ' + subgraph_place(group.graphs)


def _join_directive_groups(groups: List[_Group]) -> String:
    """Join directive-argument groups with Hive's `but` and `and`.

    Args:
        groups: At least two groups.

    Returns:
        The text after `it has `.
    """
    var message = (
        _directive_group(groups[0]) + " but " + _directive_group(groups[1])
    )
    for index in range(2, len(groups)):
        message += " and " + _directive_group(groups[index])
    return message


def _directive_group(group: _Group) -> String:
    """Return one directive-argument group, as Hive prints it.

    Args:
        group: The type and its subgraphs.

    Returns:
        Such as `type "Int" in subgraph "a"`.
    """
    var plural = String("")
    if len(group.graphs) > 1:
        plural = "s"
    return (
        'type "'
        + group.type_text
        + '" in subgraph'
        + plural
        + " "
        + and_list(group.graphs)
    )


def _object_sites(
    facts: List[GraphFacts],
    type_name: String,
    field_name: String,
    arg_name: String,
) -> List[_Site]:
    """Return each subgraph's type for one object-field argument.

    Args:
        facts: The subgraphs, in id order.
        type_name: The object type.
        field_name: The field.
        arg_name: The argument.

    Returns:
        The sites that define the argument.
    """
    var sites = List[_Site]()
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find_kind(type_name, TypeKind.OBJECT)
        if type_at == -1:
            continue
        var field = graph.types[type_at].find_field(field_name)
        if field == -1:
            continue
        ref args = graph.types[type_at].fields[field].arg_facts
        for arg_index in range(len(args)):
            if args[arg_index].name != arg_name:
                continue
            sites.append(
                _Site(
                    String(graph.graph_name), String(args[arg_index].type_text)
                )
            )
    return sites^


def _directive_names(facts: List[GraphFacts]) -> List[String]:
    """Return directive names in first-seen order.

    Args:
        facts: The subgraphs, in id order.

    Returns:
        The names, once each.
    """
    var names = List[String]()
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        for directive_index in range(len(graph.directives)):
            append_new(names, graph.directives[directive_index].name)
        graph_index += 1
    return names^


def _any_executable(facts: List[GraphFacts], name: String) -> Bool:
    """Return True when any subgraph can apply the directive to an executable location.

    Args:
        facts: The subgraphs, in id order.
        name: The directive name.

    Returns:
        Whether the merged directive is executable.
    """
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        for directive_index in range(len(graph.directives)):
            ref directive = graph.directives[directive_index]
            if directive.name == name and directive.executable:
                return True
    return False


def _directive_arg_names(facts: List[GraphFacts], name: String) -> List[String]:
    """Return the arguments of one directive, in first-seen order.

    Args:
        facts: The subgraphs, in id order.
        name: The directive name.

    Returns:
        The argument names, once each.
    """
    var names = List[String]()
    var graph_index = 0
    while graph_index < len(facts):
        var found = _find_directive(facts[graph_index], name)
        if found != -1:
            ref args = facts[graph_index].directives[found].args
            for arg_index in range(len(args)):
                append_new(names, args[arg_index].name)
        graph_index += 1
    return names^


def _directive_sites(
    facts: List[GraphFacts], name: String, arg_name: String
) -> List[_Site]:
    """Return each subgraph's type for one directive argument.

    Args:
        facts: The subgraphs, in id order.
        name: The directive name.
        arg_name: The argument.

    Returns:
        The sites that define the argument.
    """
    var sites = List[_Site]()
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var found = _find_directive(graph, name)
        if found == -1:
            continue
        ref args = graph.directives[found].args
        var arg_index = 0
        while arg_index < len(args):
            if args[arg_index].name == arg_name:
                sites.append(
                    _Site(
                        String(graph.graph_name),
                        String(args[arg_index].type_text),
                    )
                )
            arg_index += 1
    return sites^


def _find_directive(graph: GraphFacts, name: String) -> Int:
    """Return the index of a directive, or -1.

    Args:
        graph: One subgraph.
        name: The directive name.

    Returns:
        The index in `graph.directives`, or -1.
    """
    var index = 0
    while index < len(graph.directives):
        if graph.directives[index].name == name:
            return index
        index += 1
    return -1

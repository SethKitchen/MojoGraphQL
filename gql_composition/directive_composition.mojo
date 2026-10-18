# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Composed directives must agree across subgraphs.

Port of `DirectiveCompositionRule` of Hive Federation Composition
v0.27.0 `src/supergraph/validation/rules/directive-composition-rule.ts`.

A core feature keeps one major version. A composed directive keeps one
applied name and one feature identity. A directive used in more than one
subgraph needs one shared location, unless it is executable and not
composed. The location error has no code.

The link checks read only the links that the supergraph state keeps: a
link that is not the federation link and that imports a directive. The
location check reads only a composed or an executable directive
definition, as upstream `directiveBuilder` does.
"""

from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.later_versions import ArgFact, DirectiveFact, GraphFacts
from gql_composition.merged import append_new, contains, subgraph_place
from gql_composition.link import ImportKind, Link


@fieldwise_init
struct _Group(Movable):
    """One applied name and the subgraphs that use it."""

    var applied: String
    """The applied directive name."""
    var graphs: List[String]
    """The subgraph names, in first-seen order."""


@fieldwise_init
struct _Original(Movable):
    """One imported directive and its applied names."""

    var name: String
    """The original directive name."""
    var groups: List[_Group]
    """The applied names, in first-seen order."""


@fieldwise_init
struct _Identity(Movable):
    """One applied name and the feature identities that provide it."""

    var name: String
    """The applied directive name."""
    var identities: List[String]
    """The feature identities, in first-seen order."""


def check_directive_composition(
    facts: List[GraphFacts],
    mut link_errors: List[CompositionError],
    mut location_errors: List[CompositionError],
):
    """Report composed directives that disagree across subgraphs.

    Args:
        facts: The subgraphs, in id order, after a clean subgraph phase.
        link_errors: Receives the link errors, before field errors.
        location_errors: Receives the location errors, after field errors.
    """
    var majors = List[String]()
    var major_numbers = List[Int]()
    var originals = List[_Original]()
    var identities = List[_Identity]()
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        for link_index in range(len(graph.links)):
            ref link = graph.links[link_index]
            if not _is_composed_link(link):
                continue
            _check_major(
                link.identity, link.version, majors, major_numbers, link_errors
            )
            # A composed link imports at least one directive.
            var import_index = 0
            while import_index < len(link.imports):
                ref item = link.imports[import_index]
                import_index += 1
                if item.kind != ImportKind.DIRECTIVE:
                    continue
                var applied = String(item.name)
                if item.alias:
                    applied = String(item.alias.value())
                _add_name(originals, item.name, applied, graph.graph_name)
                _add_identity(identities, applied, link.identity)
    _report_names(originals, link_errors)
    _report_identities(identities, link_errors)
    _report_locations(facts, location_errors)


def _is_composed_link(link: Link) -> Bool:
    """Return True for a link that the supergraph state keeps.

    Upstream `createSubgraphStateBuilder` keeps a link when it is not the
    federation link and when it imports at least one directive.

    Args:
        link: A parsed `@link`.

    Returns:
        Whether the link takes part in the directive checks.
    """
    if link.is_federation():
        return False
    for index in range(len(link.imports)):
        if link.imports[index].kind == ImportKind.DIRECTIVE:
            return True
    return False


def _check_major(
    identity: String,
    version: Optional[String],
    mut majors: List[String],
    mut numbers: List[Int],
    mut errors: List[CompositionError],
):
    """Report a core feature whose major version changes.

    Args:
        identity: The feature identity.
        version: The feature version, if any.
        majors: The identities seen so far.
        numbers: The first major version of each identity.
        errors: The errors to append.
    """
    if not version:
        return
    var major = _major(version.value())
    for index in range(len(majors)):
        if majors[index] != identity:
            continue
        if numbers[index] != major:
            errors.append(
                CompositionError(
                    'Core feature "'
                    + identity
                    + '" requested to be merged has major version mismatch'
                    " across subgraphs",
                    ErrorCode.DIRECTIVE_COMPOSITION_ERROR,
                    None,
                )
            )
        return
    majors.append(String(identity))
    numbers.append(major)


def _report_names(
    originals: List[_Original], mut errors: List[CompositionError]
):
    """Report a directive imported under more than one name.

    Args:
        originals: The imported directives.
        errors: The errors to append.
    """
    for index in range(len(originals)):
        ref groups = originals[index].groups
        if len(groups) < 2:
            continue
        var message = (
            'Composed directive "'
            + originals[index].name
            + '" has incompatible name across subgraphs: it has '
            + _group_text(groups[0])
            + " but "
            + _group_text(groups[1])
        )
        for group_index in range(2, len(groups)):
            message += " and " + _group_text(groups[group_index])
        message += (
            ". Composed directive must have the same name across all subgraphs."
        )
        errors.append(
            CompositionError(
                message, ErrorCode.DIRECTIVE_COMPOSITION_ERROR, None
            )
        )


def _report_identities(
    identities: List[_Identity], mut errors: List[CompositionError]
):
    """Report a directive linked by more than one feature.

    Args:
        identities: The applied names.
        errors: The errors to append.
    """
    for index in range(len(identities)):
        if len(identities[index].identities) < 2:
            continue
        errors.append(
            CompositionError(
                'Composed directive "'
                + identities[index].name
                + '" is not linked by the same core feature in every subgraph',
                ErrorCode.DIRECTIVE_COMPOSITION_ERROR,
                None,
            )
        )


def _report_locations(
    facts: List[GraphFacts], mut errors: List[CompositionError]
):
    """Report a directive with no location common to every subgraph.

    Args:
        facts: The subgraphs, in id order.
        errors: The errors to append.
    """
    var names = _directive_names(facts)
    for index in range(len(names)):
        var name = String(names[index])
        var sites = _sites(facts, name)
        if len(sites) < 2:
            continue
        var executable = False
        var composed = False
        var site_index = 0
        while site_index < len(sites):
            if sites[site_index].executable:
                executable = True
            if sites[site_index].composed:
                composed = True
            site_index += 1
        if executable and not composed:
            continue
        if _shares_location(sites):
            continue
        errors.append(
            CompositionError(
                'Directive "@'
                + name
                + '" has no shared locations between subgraphs',
                ErrorCode.NONE,
                None,
            )
        )


def _group_text(group: _Group) -> String:
    """Return one applied-name group.

    Args:
        group: The applied name and its subgraphs.

    Returns:
        Such as `name "@lower" in subgraph "b"`.
    """
    return 'name "' + group.applied + '" in ' + subgraph_place(group.graphs)


def _add_name(
    mut originals: List[_Original],
    original_name: String,
    applied: String,
    graph_name: String,
):
    """Record one applied name of an imported directive.

    Args:
        originals: The directives so far.
        original_name: The name in the feature.
        applied: The name in the subgraph.
        graph_name: The subgraph name.
    """
    for index in range(len(originals)):
        if originals[index].name != original_name:
            continue
        ref groups = originals[index].groups
        var group_index = 0
        while group_index < len(groups):
            if groups[group_index].applied == applied:
                ref graphs = groups[group_index].graphs
                append_new(graphs, graph_name)
                return
            group_index += 1
        var graphs = List[String]()
        graphs.append(String(graph_name))
        groups.append(_Group(String(applied), graphs^))
        return
    var graphs = List[String]()
    graphs.append(String(graph_name))
    var groups = List[_Group]()
    groups.append(_Group(String(applied), graphs^))
    originals.append(_Original(String(original_name), groups^))


def _add_identity(
    mut identities: List[_Identity], applied: String, identity: String
):
    """Record one feature identity for an applied directive name.

    Args:
        identities: The applied names so far.
        applied: The name in the subgraph.
        identity: The feature identity.
    """
    for index in range(len(identities)):
        if identities[index].name != applied:
            continue
        ref values = identities[index].identities
        append_new(values, identity)
        return
    var values = List[String]()
    values.append(String(identity))
    identities.append(_Identity(String(applied), values^))


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
        ref directives = facts[graph_index].directives
        for index in range(len(directives)):
            append_new(names, directives[index].name)
        graph_index += 1
    return names^


def _sites(facts: List[GraphFacts], name: String) -> List[DirectiveFact]:
    """Return each subgraph's definition of a directive.

    Args:
        facts: The subgraphs, in id order.
        name: The directive name.

    Returns:
        The definitions that upstream `directiveBuilder` keeps: a
        composed or an executable directive. Copying a fact moves its
        lists, so the caller owns the result.
    """
    var sites = List[DirectiveFact]()
    var graph_index = 0
    while graph_index < len(facts):
        ref directives = facts[graph_index].directives
        graph_index += 1
        for index in range(len(directives)):
            if directives[index].name != name:
                continue
            if directives[index].composed or directives[index].executable:
                sites.append(
                    DirectiveFact(
                        String(directives[index].name),
                        directives[index].executable,
                        _copy_args(directives[index]),
                        _copy_locations(directives[index]),
                        directives[index].composed,
                        directives[index].repeatable,
                    )
                )
    return sites^


def _copy_args(directive: DirectiveFact) -> List[ArgFact]:
    """Copy the arguments of a directive.

    Args:
        directive: One directive definition.

    Returns:
        The arguments. This copy is unused by the location check.
    """
    _ = directive
    return List[ArgFact]()


def _copy_locations(directive: DirectiveFact) -> List[String]:
    """Copy the locations of a directive.

    Args:
        directive: One directive definition.

    Returns:
        The locations.
    """
    return directive.locations.copy()


def _shares_location(sites: List[DirectiveFact]) -> Bool:
    """Return True when one location is present in every definition.

    Args:
        sites: The directive definitions.

    Returns:
        Whether the subgraphs share a location.
    """
    # A directive definition has at least one location, and the caller
    # passes at least two definitions.
    ref first = sites[0].locations
    var index = 0
    while index < len(first):
        var location = String(first[index])
        index += 1
        var shared = True
        var site_index = 1
        while site_index < len(sites):
            if not contains(sites[site_index].locations, location):
                shared = False
            site_index += 1
        if shared:
            return True
    return False


def _major(version: String) -> Int:
    """Return the major number of a feature version.

    Args:
        version: A version such as `v2.3`. The link check of the subgraph
            phase already accepts only `v`, digits, `.` and a digit.

    Returns:
        The major number. `v2.3` is 2.
    """
    var bytes = version.as_bytes()
    var number = 0
    var index = 1
    while bytes[index] != 46:
        number = number * 10 + Int(bytes[index] - 48)
        index += 1
    return number

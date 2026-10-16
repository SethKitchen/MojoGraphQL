# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The rules about fragments.

Port of graphql-js 16.14.2 `validation/rules/FragmentsOnCompositeTypesRule.ts`,
`UniqueFragmentNamesRule.ts`, `KnownFragmentNamesRule.ts`,
`NoUnusedFragmentsRule.ts`, `PossibleFragmentSpreadsRule.ts` and
`NoFragmentCyclesRule.ts`.

Each function is the handler of one rule for one node kind, and the walk of
`gql_validation.validate` calls it.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_language.printer import print_node
from gql_schema.definition import NO_TYPE, Schema
from gql_schema.names import NOT_FOUND
from gql_schema.type_comparators import do_types_overlap
from gql_validation.state import Walk
from gql_validation.type_info import is_defined, type_from_ast


def _composite_or_none(
    schema: Schema, document: Document, condition: Int
) -> Int:
    """Return the composite type a type condition names, or `NO_TYPE`."""
    var type = Int(type_from_ast(schema, document, condition).named)
    if type >= 0 and schema.types[type].kind.is_composite():
        return type
    return NO_TYPE


def fragments_on_composite_types(
    mut walk: Walk, schema: Schema, document: Document, node: Int
):
    """FragmentsOnCompositeTypesRule, on an `InlineFragment` or a
    `FragmentDefinition`.

    Args:
        walk: The walk.
        schema: The schema.
        document: The document.
        node: The fragment.
    """
    var condition = document.child(node, Role.TYPE_CONDITION)
    if condition == NO_NODE:
        return
    var type = type_from_ast(schema, document, condition)
    if (
        not is_defined(type)
        or schema.types[Int(type.named)].kind.is_composite()
    ):
        return
    var subject = String("Fragment")
    if document.kind(node) == Kind.FRAGMENT_DEFINITION:
        subject += ' "' + String(document.name(node)) + '"'
    walk.ctx.report_error(
        document,
        subject
        + ' cannot condition on non composite type "'
        + print_node(document, condition)
        + '".',
        condition,
    )


def unique_fragment_names(mut walk: Walk, document: Document, node: Int):
    """UniqueFragmentNamesRule, on a `FragmentDefinition`.

    Args:
        walk: The walk.
        document: The document.
        node: The fragment.
    """
    var name = document.child(node, Role.NAME)
    var text = document.text(name)
    var known = walk.fragment_names.find_or_insert(-1, text, name)
    if known != NOT_FOUND:
        walk.ctx.report_error_nodes(
            document,
            'There can be only one fragment named "' + String(text) + '".',
            [known, name],
        )


def known_fragment_names(mut walk: Walk, document: Document, node: Int):
    """KnownFragmentNamesRule, on a `FragmentSpread`.

    Args:
        walk: The walk.
        document: The document.
        node: The spread.
    """
    var name = document.child(node, Role.NAME)
    if walk.ctx.get_fragment(document, document.text(name)) == NO_NODE:
        walk.ctx.report_error(
            document,
            'Unknown fragment "' + String(document.text(name)) + '".',
            name,
        )


def no_unused_fragments(mut walk: Walk, document: Document):
    """NoUnusedFragmentsRule, on exit from the `Document`.

    Args:
        walk: The walk.
        document: The document.
    """
    var used = List[Bool]()
    for operation in walk.operation_defs:
        var slot = walk.ctx.referenced_index(document, operation)
        var index = 0
        while index < len(walk.ctx._referenced_lists[slot]):
            var fragment = Int(walk.ctx._referenced_lists[slot][index])
            index += 1
            var id = walk.ctx.fragment_id(document.name(fragment))
            while len(used) <= id:
                used.append(False)
            used[id] = True
    for fragment in walk.fragment_defs:
        var name = document.name(fragment)
        var id = walk.ctx.fragment_id(name)
        if id < len(used) and used[id]:
            continue
        walk.ctx.report_error(
            document,
            'Fragment "' + String(name) + '" is never used.',
            fragment,
        )


def _cannot_spread(
    mut walk: Walk,
    schema: Schema,
    document: Document,
    node: Int,
    subject: String,
    parent: Int,
    type: Int,
):
    """Report a fragment whose type cannot overlap its parent type."""
    walk.ctx.report_error(
        document,
        subject
        + ' cannot be spread here as objects of type "'
        + schema.types[parent].name
        + '" can never be of type "'
        + schema.types[type].name
        + '".',
        node,
    )


def possible_inline_fragment(
    mut walk: Walk, schema: Schema, document: Document, node: Int
):
    """PossibleFragmentSpreadsRule, on an `InlineFragment`.

    Args:
        walk: The walk.
        schema: The schema.
        document: The document.
        node: The inline fragment.
    """
    var type = walk.ctx.type_info.get_type()
    var parent = walk.ctx.type_info.get_parent_type()
    if (
        not is_defined(type)
        or not schema.types[Int(type.named)].kind.is_composite()
        or parent == NO_TYPE
    ):
        return
    var named = Int(type.named)
    if not do_types_overlap(schema, named, parent):
        _cannot_spread(walk, schema, document, node, "Fragment", parent, named)


def possible_fragment_spread(
    mut walk: Walk, schema: Schema, document: Document, node: Int
):
    """PossibleFragmentSpreadsRule, on a `FragmentSpread`.

    Args:
        walk: The walk.
        schema: The schema.
        document: The document.
        node: The spread.
    """
    var name = document.name(node)
    var fragment = walk.ctx.get_fragment(document, name)
    if fragment == NO_NODE:
        return
    var type = _composite_or_none(
        schema, document, document.child(fragment, Role.TYPE_CONDITION)
    )
    var parent = walk.ctx.type_info.get_parent_type()
    if type == NO_TYPE or parent == NO_TYPE:
        return
    if not do_types_overlap(schema, type, parent):
        _cannot_spread(
            walk,
            schema,
            document,
            node,
            'Fragment "' + String(name) + '"',
            parent,
            type,
        )


# --- NoFragmentCyclesRule ---------------------------------------------------


def _grow_to(mut walk: Walk, id: Int):
    """Make the per-fragment lists of the cycle check hold an id."""
    while len(walk.visited_fragments) <= id:
        walk.visited_fragments.append(False)
        walk.spread_path_index.append(-1)


def no_fragment_cycles(mut walk: Walk, document: Document, node: Int):
    """NoFragmentCyclesRule, on a `FragmentDefinition`.

    Args:
        walk: The walk.
        document: The document.
        node: The fragment.
    """
    _detect_cycles(walk, document, node)


def _detect_cycles(mut walk: Walk, document: Document, fragment: Int):
    """graphql-js `detectCycleRecursive`: follow the spreads of a fragment
    depth first, and report each spread that closes a cycle."""
    var id = walk.ctx.fragment_id(document.name(fragment))
    _grow_to(walk, id)
    if walk.visited_fragments[id]:
        return
    walk.visited_fragments[id] = True
    var slot = walk.ctx.spreads_index(
        document, document.child(fragment, Role.SELECTION_SET)
    )
    if len(walk.ctx._spread_lists[slot]) == 0:
        return
    walk.spread_path_index[id] = len(walk.spread_path)
    var index = 0
    while index < len(walk.ctx._spread_lists[slot]):
        var spread = Int(walk.ctx._spread_lists[slot][index])
        index += 1
        _follow_spread(walk, document, spread)
    walk.spread_path_index[id] = -1


def _follow_spread(mut walk: Walk, document: Document, spread: Int):
    """Follow one spread of `_detect_cycles`."""
    var name = document.name(spread)
    var id = walk.ctx.fragment_id(name)
    _grow_to(walk, id)
    var cycle_index = walk.spread_path_index[id]
    walk.spread_path.append(spread)
    if cycle_index < 0:
        var target = walk.ctx.fragment_by_id(document, id)
        if target != NO_NODE:
            _detect_cycles(walk, document, target)
    else:
        var cycle = List[Int]()
        var via = String("")
        var at = cycle_index
        while at < len(walk.spread_path):
            cycle.append(walk.spread_path[at])
            if at < len(walk.spread_path) - 1:
                if via != "":
                    via += ", "
                via += '"' + String(document.name(walk.spread_path[at])) + '"'
            at += 1
        var message = (
            'Cannot spread fragment "' + String(name) + '" within itself'
        )
        if via != "":
            message += " via " + via
        walk.ctx.report_error_nodes(document, message + ".", cycle)
    _ = walk.spread_path.pop()

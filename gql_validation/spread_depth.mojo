# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The depth of the chains of fragment spreads in a document.

`validate` refuses a document whose fragment spreads chain deeper than
`MAX_SPREAD_DEPTH`, before any rule runs. Several rules, such as
`OverlappingFieldsCanBeMergedRule`, and the planners after validation
follow a spread into its fragment with a call. A chain of 20000
fragments, each with one spread of the next, is a valid document of
about 800 KB, and it overflows the stack.

This module follows the spreads with its own stack, so its depth does not
grow with the chain. A cycle adds no depth here: `NoFragmentCyclesRule`
reports it.

Differences from upstream: graphql-js has no such limit. There a chain
that deep overflows the stack with a `RangeError` that the caller can
catch. Mojo has no catchable stack overflow.
"""

from std.collections import Dict

from gql_language.ast import NO_NODE, Document, Kind

comptime MAX_SPREAD_DEPTH = 500
"""The longest chain of definitions, an operation and the fragments that
it spreads in turn, that `validate` accepts."""

comptime _UNKNOWN = -1
"""The depth of a definition that the search has not reached."""
comptime _OPEN = -2
"""The depth of a definition on the stack of the search: a spread of it
now closes a cycle."""


def _spreads_of(
    document: Document, definition: Int, fragments: Dict[String, Int]
) -> List[Int]:
    """Return the positions of the fragments that a definition spreads."""
    var out = List[Int]()
    var stack = List[Int]()
    stack.append(document.first_child(definition))
    while len(stack) > 0:
        var node = stack.pop()
        if node == NO_NODE:
            continue
        stack.append(document.next_sibling(node))
        if document.kind(node) == Kind.FRAGMENT_SPREAD:
            var target = fragments.get(String(document.name(node)))
            if target:
                out.append(target.value())
            continue
        stack.append(document.first_child(node))
    return out^


def deepest_spread_chain(document: Document) -> Tuple[Int, Int]:
    """Measure the longest chain of fragment spreads.

    Args:
        document: The executable document.

    Returns:
        The count of definitions in the longest chain, and the definition
        that starts it; `(0, NO_NODE)` for a document with no definition.
    """
    var definitions = document.definitions()
    var fragments = Dict[String, Int]()
    for index in range(len(definitions)):
        var node = definitions[index]
        if document.kind(node) == Kind.FRAGMENT_DEFINITION:
            fragments[String(document.name(node))] = index
    var spreads = List[List[Int]]()
    for index in range(len(definitions)):
        spreads.append(_spreads_of(document, definitions[index], fragments))
    var depth = List[Int](length=len(definitions), fill=_UNKNOWN)
    var deepest = 0
    var at = NO_NODE
    for start in range(len(definitions)):
        if depth[start] != _UNKNOWN:
            continue
        # A depth-first search with its own stack: each entry is a
        # definition and the index of its next spread.
        var stack = List[Int]()
        var next = List[Int]()
        stack.append(start)
        next.append(0)
        depth[start] = _OPEN
        while len(stack) > 0:
            var top = stack[len(stack) - 1]
            var index = next[len(next) - 1]
            if index < len(spreads[top]):
                next[len(next) - 1] = index + 1
                var target = spreads[top][index]
                if depth[target] == _UNKNOWN:
                    depth[target] = _OPEN
                    stack.append(target)
                    next.append(0)
                continue
            var longest = 0
            for target in spreads[top]:
                longest = max(longest, depth[target])
            depth[top] = longest + 1
            _ = stack.pop()
            _ = next.pop()
        if depth[start] > deepest:
            deepest = depth[start]
            at = definitions[start]
    return (deepest, at)

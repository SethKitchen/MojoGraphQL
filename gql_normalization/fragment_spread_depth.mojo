# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The depth of each fragment spread: graphql-go-tools v2
`astnormalization/fragmentspread_depth.go`, `FragmentSpreadDepth`.

The depth of a node is the depth of the upstream walker: an operation or
a fragment definition is at depth 1, and each selection set, field,
fragment spread and inline fragment is one deeper than its parent. A spread
in a fragment definition also gets the depth of the first spread of that
fragment, as `nestedDepthCalc` adds it.

Differences from upstream:

- `get` takes no definition. The walker of upstream reads it only to know
  the enclosing types, which the depths do not use.
- A fragment that spreads itself, directly or not, raises an `Error`.
  Upstream recurses without end.
"""

from gql_language.ast import Document, Kind, NO_NODE, Role


@fieldwise_init
struct Depth(Copyable, ImplicitlyCopyable, Movable):
    """The depth of one fragment spread: upstream `Depth`."""

    var spread_ref: Int
    """The fragment spread node: `SpreadRef`."""
    var depth: Int
    """The depth of the spread, with the depth of its fragment for a nested
    spread: `Depth`."""
    var spread_name: String
    """The name of the spread fragment: `SpreadName`."""
    var is_nested: Bool
    """The spread is in a fragment definition: `isNested`."""
    var parent_fragment_name: String
    """The name of that fragment definition: `parentFragmentName`."""


struct Depths(Copyable, Movable, Sized):
    """The depths of the spreads of a document, in document order: upstream
    `Depths`."""

    var items: List[Depth]
    """The depths."""

    def __init__(out self):
        """Make an empty list."""
        self.items = List[Depth]()

    def __len__(self) -> Int:
        """Return the number of depths.

        Returns:
            The length.
        """
        return len(self.items)

    def __getitem__(self, index: Int) -> Depth:
        """Return one depth.

        Args:
            index: The position.

        Returns:
            The depth.
        """
        return self.items[index]

    def clear(mut self):
        """Remove every depth, and keep the memory: `depths[:0]`."""
        self.items.clear()

    def by_ref(self, spread_ref: Int) -> Optional[Int]:
        """Return the depth of a spread node: `ByRef`.

        Args:
            spread_ref: The fragment spread node.

        Returns:
            The depth, or `None` when the node has none.
        """
        var index = 0
        while index < len(self.items):
            if self.items[index].spread_ref == spread_ref:
                return self.items[index].depth
            index += 1
        return None


def _collect(
    document: Document,
    node: Int,
    depth: Int,
    parent: StringSlice,
    nested: Bool,
    mut depths: Depths,
):
    """Add the spreads under a selection set at `depth`."""
    var selection = document.child(node, Role.SELECTION)
    while selection != NO_NODE:
        var kind = document.kind(selection)
        if kind == Kind.FRAGMENT_SPREAD:
            depths.items.append(
                Depth(
                    selection,
                    depth + 1,
                    String(document.name(selection)),
                    nested,
                    String(parent),
                )
            )
        else:
            var selection_set = document.child(selection, Role.SELECTION_SET)
            if selection_set != NO_NODE:
                _collect(
                    document, selection_set, depth + 2, parent, nested, depths
                )
        selection = document.next_with_role(selection)


def _nested_depth(depths: Depths, index: Int) raises -> Int:
    """Return the depth of a spread with the depths of its fragments:
    `calculateNestedDepth` and `depthForFragment`, without recursion."""
    var total = 0
    var current = index
    var steps = 0
    while True:
        ref item = depths.items[current]
        total += item.depth
        if not item.is_nested:
            return total
        var found = -1
        var position = 0
        while position < len(depths.items):
            if depths.items[position].spread_name == item.parent_fragment_name:
                found = position
                break
            position += 1
        if found < 0:
            return total
        steps += 1
        if steps > len(depths.items):
            raise Error(
                "fragment spread depth: fragment "
                + item.parent_fragment_name
                + " spreads itself"
            )
        current = found


struct FragmentSpreadDepth(Copyable, Movable):
    """Finds the depth of each fragment spread: upstream
    `FragmentSpreadDepth`. One calculator can serve many documents."""

    def __init__(out self):
        """Make a calculator."""
        pass

    def get(self, operation: Document, mut depths: Depths) raises:
        """Append the depth of each fragment spread of a document: `Get`.

        As upstream, a depth is set in place in order, so a nested spread
        adds the depth of a fragment that is already set.

        Args:
            operation: The executable document.
            depths: The list that gets the depths; clear it first to reuse
                it.

        Raises:
            Error: When a fragment spreads itself.
        """
        var definition = operation.first_child(operation.root)
        while definition != NO_NODE:
            var kind = operation.kind(definition)
            var selection_set = operation.child(definition, Role.SELECTION_SET)
            if kind == Kind.OPERATION_DEFINITION:
                _collect(operation, selection_set, 2, "", False, depths)
            elif kind == Kind.FRAGMENT_DEFINITION:
                _collect(
                    operation,
                    selection_set,
                    2,
                    operation.name(definition),
                    True,
                    depths,
                )
            definition = operation.next_sibling(definition)
        var index = 0
        while index < len(depths.items):
            depths.items[index].depth = _nested_depth(depths, index)
            index += 1

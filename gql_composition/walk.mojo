# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A depth-first walk of definitions, and the type definition that the walk
is in.

Port of `TypeNodeInfo` of Hive Federation Composition v0.27.0
`src/graphql/type-node-info.ts`. The walk is the graphql-js `visit` order:
each node is entered, then its children, then it is left.

**Differences from upstream.** Upstream walks with the graphql-js visitor
and passes the ancestors to each visitor. `Walker` keeps the path of
entered nodes; `parent()` is the node that holds the current node.
"""

from gql_language.ast import NO_NODE, Document, Kind


struct Walker(Movable):
    """A cursor that enters and leaves each node of some definitions, in
    graphql-js `visit` order."""

    var definitions: List[Int]
    """The top-level nodes to walk, in order."""
    var index: Int
    """The position of the current top-level node in `definitions`."""
    var node: Int
    """The current node, or `NO_NODE` after the walk."""
    var entering: Bool
    """True when the walk enters `node`, False when it leaves it."""
    var path: List[Int]
    """The entered nodes that hold `node`, from the top."""

    def __init__(out self, var definitions: List[Int]):
        """Start a walk; call `next` for the first event.

        Args:
            definitions: The top-level nodes, in order.
        """
        self.definitions = definitions^
        self.index = -1
        self.node = NO_NODE
        self.entering = False
        self.path = List[Int]()

    def next(mut self, document: Document) -> Bool:
        """Move to the next event.

        Args:
            document: The document that holds the nodes.

        Returns:
            False when the walk is over.
        """
        if self.entering:
            var child = document.first_child(self.node)
            if child != NO_NODE:
                self.path.append(self.node)
                self.node = child
                return True
            self.entering = False
            return True
        if len(self.path) == 0:
            self.index += 1
            if self.index >= len(self.definitions):
                self.node = NO_NODE
                return False
            self.node = self.definitions[self.index]
            self.entering = True
            return True
        var sibling = document.next_sibling(self.node)
        if sibling != NO_NODE:
            self.node = sibling
            self.entering = True
            return True
        self.node = self.path.pop()
        return True

    def parent(self) -> Int:
        """Return the node that holds the current node.

        Returns:
            The parent, or `NO_NODE` for a top-level node.
        """
        if len(self.path) == 0:
            return NO_NODE
        return self.path[len(self.path) - 1]


def is_type_or_directive_definition(kind: Kind) -> Bool:
    """Return True for the kinds that `TypeNodeInfo` tracks as the type.

    Args:
        kind: A node kind.

    Returns:
        Whether it is a type definition, a type extension or a directive
        definition.
    """
    return (
        kind.is_type_definition()
        or kind.is_type_extension()
        or kind == Kind.DIRECTIVE_DEFINITION
    )


struct TypeNodeInfo(ImplicitlyCopyable):
    """The type, field, argument and enum value that a walk is in, as
    upstream `TypeNodeInfo`."""

    var type_def: Int
    """The type definition, type extension or directive definition, or
    `NO_NODE`."""
    var field_def: Int
    """The field, or the input value of a type or directive, or
    `NO_NODE`."""
    var arg_def: Int
    """The argument of the field, or `NO_NODE`."""
    var value_def: Int
    """The enum value, or `NO_NODE`."""

    def __init__(out self):
        """Start outside of every definition."""
        self.type_def = NO_NODE
        self.field_def = NO_NODE
        self.arg_def = NO_NODE
        self.value_def = NO_NODE

    def enter(mut self, document: Document, node: Int):
        """Update on entry to a node, as upstream `enter`.

        Args:
            document: The document that holds the node.
            node: The node.
        """
        var kind = document.kind(node)
        if is_type_or_directive_definition(kind):
            self.type_def = node
        elif kind == Kind.ENUM_VALUE_DEFINITION:
            self.value_def = node
        elif kind == Kind.FIELD_DEFINITION:
            self.field_def = node
        elif kind == Kind.INPUT_VALUE_DEFINITION:
            if self.field_def != NO_NODE:
                self.arg_def = node
            else:
                self.field_def = node

    def leave(mut self, document: Document, node: Int):
        """Update on exit from a node, as upstream `leave`.

        Args:
            document: The document that holds the node.
            node: The node.
        """
        var kind = document.kind(node)
        if is_type_or_directive_definition(kind):
            self.type_def = NO_NODE
        elif kind == Kind.FIELD_DEFINITION:
            self.field_def = NO_NODE
        elif kind == Kind.ENUM_VALUE_DEFINITION:
            self.value_def = NO_NODE
        elif kind == Kind.INPUT_VALUE_DEFINITION:
            if self.arg_def != NO_NODE:
                self.arg_def = NO_NODE
            else:
                self.field_def = NO_NODE

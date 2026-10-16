# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Walk an AST depth first, calling a visitor on entry to and exit from each
node.

Port of graphql-js 16.14.2 `language/visitor.ts`: `visit`, `BREAK`, and
`visitInParallel`.

A visitor is a struct that conforms to `Visitor`. Its `enter` and `leave`
methods get the document, the node, and a `VisitPath` that holds the chain
of ancestors and the graphql-js `key` of each one: the property name, or the
index in a list property. `enter` returns `VisitAction.SKIP` to skip the
node's children (and its `leave`, as graphql-js does for `false`), and
either method returns `VisitAction.BREAK` to stop the walk.

**Differences from graphql-js.**

- The walk does not edit. In graphql-js a visitor can return a node or
  `null` to replace or remove the current node, and `visit` returns the
  edited copy. Here a document is changed with its builder methods.
- graphql-js passes the array that holds a list item as its `parent`. Here
  `VisitPath.parent` is always the node, and `VisitPath.index` says whether
  the node is a list item.
- A walk visits children in their stored order. For a parsed document that
  is the order of graphql-js `QueryDocumentKeys`.
- `ParallelVisitor` joins two visitors; nest it for more. graphql-js
  `visitInParallel` takes an array.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role


@fieldwise_init
struct VisitAction(Equatable, ImplicitlyCopyable, Writable):
    """What a visitor asks the walk to do next."""

    var value: UInt8
    """The action's index; see `is_valid`."""

    comptime CONTINUE = VisitAction(0)
    """Go on: graphql-js `undefined`."""
    comptime SKIP = VisitAction(1)
    """Skip the node's children and its `leave`: graphql-js `false`."""
    comptime BREAK = VisitAction(2)
    """Stop the walk: graphql-js `BREAK`."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the three actions.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 2

    def write_to(self, mut writer: Some[Writer]):
        """Write the action's name.

        Args:
            writer: The destination.
        """
        if self == VisitAction.CONTINUE:
            writer.write("CONTINUE")
        elif self == VisitAction.SKIP:
            writer.write("SKIP")
        elif self == VisitAction.BREAK:
            writer.write("BREAK")
        else:
            writer.write("<invalid>")


struct VisitPath(Movable):
    """The nodes from the root of a walk down to the current node."""

    var nodes: List[Int]
    """The node indices, the root first and the current node last."""
    var indices: List[Int]
    """For each node, its index in its parent's list property, or -1."""

    def __init__(out self):
        """Start with an empty path."""
        self.nodes = List[Int]()
        self.indices = List[Int]()

    def depth(self) -> Int:
        """Return how many ancestors the current node has.

        Returns:
            Zero for the root of the walk.
        """
        return len(self.nodes) - 1

    def node(self) -> Int:
        """Return the current node.

        Returns:
            Its index.
        """
        return self.nodes[len(self.nodes) - 1]

    def parent(self) -> Int:
        """Return the current node's parent.

        Returns:
            The parent's index, or `NO_NODE` at the root of the walk.
        """
        if len(self.nodes) < 2:
            return NO_NODE
        return self.nodes[len(self.nodes) - 2]

    def index(self) -> Int:
        """Return the current node's index in its parent's list property.

        Returns:
            The index, or -1 when the node fills a single-value property.
        """
        return self.indices[len(self.indices) - 1]

    def keys(self, document: Document) -> List[String]:
        """Return the path as graphql-js `path`: property names and list
        indices, from the root of the walk down.

        Args:
            document: The document walked.

        Returns:
            For each node below the root, its property name, and then its
            index when it is a list item.
        """
        var out = List[String]()
        for position in range(1, len(self.nodes)):
            out.append(String(document.role(self.nodes[position]).text()))
            if self.indices[position] >= 0:
                out.append(String(self.indices[position]))
        return out^


trait Visitor:
    """Called by `visit` on entry to and exit from each node."""

    def enter(
        mut self, document: Document, node: Int, path: VisitPath
    ) raises -> VisitAction:
        """Visit a node before its children.

        Args:
            document: The document walked.
            node: The node.
            path: The node and its ancestors.

        Returns:
            `CONTINUE`, `SKIP` the children, or `BREAK` the walk.

        Raises:
            Error: When the visitor fails; the walk stops.
        """
        ...

    def leave(
        mut self, document: Document, node: Int, path: VisitPath
    ) raises -> VisitAction:
        """Visit a node after its children.

        Args:
            document: The document walked.
            node: The node.
            path: The node and its ancestors.

        Returns:
            `CONTINUE`, or `BREAK` the walk; `SKIP` acts as `CONTINUE`.

        Raises:
            Error: When the visitor fails; the walk stops.
        """
        ...


def is_list_role(role: Role) -> Bool:
    """Return True for a role whose graphql-js property holds an array.

    Args:
        role: The role.

    Returns:
        Whether the property is a list, such as `selections`.
    """
    return (
        role == Role.DEFINITION
        or role == Role.VARIABLE_DEFINITION
        or role == Role.DIRECTIVE
        or role == Role.ARGUMENT
        or role == Role.FIELD
        or role == Role.SELECTION
        or role == Role.INTERFACE
        or role == Role.MEMBER_TYPE
        or role == Role.ENUM_VALUE
        or role == Role.OPERATION_TYPE
        or role == Role.LOCATION
        or role == Role.LIST_ITEM
    )


@fieldwise_init
struct _Frame(ImplicitlyCopyable, Movable):
    """A node being walked, and where its children stand."""

    var node: Int
    var next: Int
    var last_role: Role
    var run: Int


def visit[
    V: Visitor
](document: Document, mut visitor: V, root: Int = NO_NODE) raises:
    """Walk a document depth first, as graphql-js `visit`.

    Parameters:
        V: The visitor's type.

    Args:
        document: The document.
        visitor: Called on entry to and exit from each node.
        root: The node to start at; the document's root by default.

    Raises:
        Error: When the visitor raises.
    """
    var start = root
    if start == NO_NODE:
        start = document.root
    var path = VisitPath()
    path.nodes.append(start)
    path.indices.append(-1)
    var action = visitor.enter(document, start, path)
    if action != VisitAction.CONTINUE:
        return
    var frames: List[_Frame] = [
        _Frame(start, document.first_child(start), Role.ROOT, -1)
    ]
    while len(frames) > 0:
        var top = len(frames) - 1
        var child = frames[top].next
        if child == NO_NODE:
            var node = frames[top].node
            _ = frames.pop()
            action = visitor.leave(document, node, path)
            _ = path.nodes.pop()
            _ = path.indices.pop()
            if action == VisitAction.BREAK:
                return
            continue
        frames[top].next = document.next_sibling(child)
        var role = document.role(child)
        var index = -1
        if is_list_role(role):
            if role == frames[top].last_role:
                index = frames[top].run + 1
            else:
                index = _index_among(document, frames[top].node, child)
            frames[top].last_role = role
            frames[top].run = index
        path.nodes.append(child)
        path.indices.append(index)
        action = visitor.enter(document, child, path)
        if action == VisitAction.BREAK:
            return
        if action == VisitAction.SKIP:
            _ = path.nodes.pop()
            _ = path.indices.pop()
            continue
        frames.append(_Frame(child, document.first_child(child), Role.ROOT, -1))


def _index_among(document: Document, parent: Int, child: Int) -> Int:
    """Return how many earlier children of `parent` share `child`'s role."""
    var role = document.role(child)
    var count = 0
    var current = document.first_child(parent)
    while current != child:
        if document.role(current) == role:
            count += 1
        current = document.next_sibling(current)
    return count


comptime _ACTIVE = -1
comptime _BROKEN = -2


struct ParallelVisitor[
    A: Visitor & Movable & Deinitable, B: Visitor & Movable & Deinitable
](Movable, Visitor):
    """Two visitors walked together, as graphql-js `visitInParallel`.

    Each one skips and breaks on its own: when `first` skips a node, `second`
    still visits its children, and when `first` breaks, `second` goes on.

    Parameters:
        A: The type of the visitor called first.
        B: The type of the visitor called second.
    """

    var first: Self.A
    """The visitor called first at each node."""
    var second: Self.B
    """The visitor called second at each node."""
    var _first_state: Int
    var _second_state: Int

    def __init__(out self, var first: Self.A, var second: Self.B):
        """Join two visitors.

        Args:
            first: The visitor called first at each node.
            second: The visitor called second at each node.
        """
        self.first = first^
        self.second = second^
        self._first_state = _ACTIVE
        self._second_state = _ACTIVE

    def enter(
        mut self, document: Document, node: Int, path: VisitPath
    ) raises -> VisitAction:
        """Enter a node in each visitor that is neither skipping nor broken.

        Args:
            document: The document walked.
            node: The node.
            path: The node and its ancestors.

        Returns:
            `BREAK` when both visitors broke, else `CONTINUE`.

        Raises:
            Error: When a visitor raises.
        """
        if self._first_state == _ACTIVE:
            self._first_state = _after_enter(
                self.first.enter(document, node, path), node
            )
        if self._second_state == _ACTIVE:
            self._second_state = _after_enter(
                self.second.enter(document, node, path), node
            )
        return self._combined()

    def leave(
        mut self, document: Document, node: Int, path: VisitPath
    ) raises -> VisitAction:
        """Leave a node in each active visitor; end a skip that it began.

        Args:
            document: The document walked.
            node: The node.
            path: The node and its ancestors.

        Returns:
            `BREAK` when both visitors broke, else `CONTINUE`.

        Raises:
            Error: When a visitor raises.
        """
        if self._first_state == _ACTIVE:
            if self.first.leave(document, node, path) == VisitAction.BREAK:
                self._first_state = _BROKEN
        elif self._first_state == node:
            self._first_state = _ACTIVE
        if self._second_state == _ACTIVE:
            if self.second.leave(document, node, path) == VisitAction.BREAK:
                self._second_state = _BROKEN
        elif self._second_state == node:
            self._second_state = _ACTIVE
        return self._combined()

    def _combined(self) -> VisitAction:
        """Return `BREAK` once neither visitor will be called again."""
        if self._first_state == _BROKEN and self._second_state == _BROKEN:
            return VisitAction.BREAK
        return VisitAction.CONTINUE


@always_inline
def _after_enter(action: VisitAction, node: Int) -> Int:
    """Return a member's state after its `enter` returned `action`."""
    if action == VisitAction.SKIP:
        return node
    if action == VisitAction.BREAK:
        return _BROKEN
    return _ACTIVE

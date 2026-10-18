# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Operation paths and query trees of the query planner.

Port of Hive Router `1a29df9` `bin/router/src/query_planner/planner/`:
`walker/path.rs`, `tree/query_tree.rs` and `tree/query_tree_node.rs`.

**One arena per plan.** Upstream links path segments and tree nodes with
`Rc`. This port keeps them in the lists of a `PlanSpace`, by index. A tree
node never changes once it is made: a merge makes a new node, as
`Rc::make_mut` does for a shared node. So a node can cache its cost, and
`reset` drops everything a plan made.
"""

from gql_router.ast import NONE, Cond
from gql_router.graph import EdgeKind, Graph
from gql_router.store import Store


@fieldwise_init
struct PathSegment(Copyable, Movable):
    """One edge of a path, as upstream `PathSegment`."""

    var prev: Int
    """The previous segment, or `NONE` for the first."""
    var edge: Int
    """The edge."""
    var tail: Int
    """The edge's tail node."""
    var cumulative_cost: Int
    """The cost of the path up to and with this edge."""
    var requirement_tree: Int
    """The query tree of the edge's requirements, or `NONE`."""
    var has_attributes: Bool
    """Whether the segment was made for a field (upstream
    `selection_attributes` is `Some`)."""
    var alias: Int
    """The field alias, or `NONE`."""
    var args: Int
    """The field's interned arguments, or `NONE`."""
    var cond: Cond
    """The `@skip`/`@include` condition."""


@fieldwise_init
struct UnionContext(Copyable, Movable):
    """The union field a path resolves, as upstream `UnionContext`."""

    var parent_type_name: Int
    """The type that owns the field."""
    var field_name: Int
    """The field that returns the union."""
    var graph_id: Int
    """The subgraph name, as a symbol."""
    var member_name: Int
    """The member the path is on."""
    var possible_members: List[Int]
    """The members the path can resolve."""

    def can_resolve_member(self, member: Int) -> Bool:
        """Return True if the path can resolve a member.

        Args:
            member: The member, as a symbol.

        Returns:
            Whether it is one of `possible_members`.
        """
        for known in self.possible_members:
            if known == member:
                return True
        return False


@fieldwise_init
struct OperationPath(ImplicitlyCopyable, Movable):
    """A path through the graph, as upstream `OperationPath`."""

    var root_node: Int
    """The node the path starts at."""
    var last_segment: Int
    """The last segment, or `NONE` for an empty path."""
    var cost: Int
    """The cost of the path."""
    var union_context: Int
    """The union context, an index into `PlanSpace.unions`, or `NONE`."""


@fieldwise_init
struct TreeNode(Copyable, Movable):
    """One node of a query tree, as upstream `QueryTreeNode`."""

    var node_index: Int
    """The graph node."""
    var edge_from_parent: Int
    """The edge from the parent, or `NONE` for a root."""
    var requirements: List[Int]
    """The requirement trees."""
    var children: List[Int]
    """The child trees."""
    var has_attributes: Bool
    """Whether the node was made for a field."""
    var alias: Int
    """The field alias, or `NONE`."""
    var args: Int
    """The field's interned arguments, or `NONE`."""
    var cond: Cond
    """The `@skip`/`@include` condition."""
    var mutation_field_position: Int
    """The position of a root mutation field, or `NONE`."""
    var cost: Int
    """The cost of the tree below and with this node."""


comptime CROSS_SUBGRAPH_COST = 1000
"""The cost of each entrypoint and each requirement in a tree."""
comptime FIELD_COST = 1
"""The cost of each tree node."""


struct PlanSpace(Movable):
    """The paths, union contexts and trees of one plan."""

    var segments: List[PathSegment]
    """Every path segment."""
    var unions: List[UnionContext]
    """Every union context."""
    var trees: List[TreeNode]
    """Every query tree node."""

    def __init__(out self):
        """Start an empty space."""
        self.segments = List[PathSegment]()
        self.unions = List[UnionContext]()
        self.trees = List[TreeNode]()

    def reset(mut self):
        """Drop everything, and keep the memory for the next plan."""
        self.segments.clear()
        self.unions.clear()
        self.trees.clear()

    # --- paths ----------------------------------------------------------

    def tail(self, path: OperationPath) -> Int:
        """Return the node a path ends at.

        Args:
            path: The path.

        Returns:
            The tail of the last segment, or the root node.
        """
        if path.last_segment == NONE:
            return path.root_node
        return self.segments[path.last_segment].tail

    def new_entrypoint(
        mut self, graph: Graph, store: Store, edge: Int
    ) -> OperationPath:
        """Return the path of one entrypoint edge, as upstream
        `OperationPath::new_entrypoint`.

        Args:
            graph: The graph.
            store: The store with the requirements.
            edge: The entrypoint edge.

        Returns:
            The path.
        """
        ref found = graph.edges[edge]
        var cost = found.cost(store)
        self.segments.append(
            PathSegment(
                NONE,
                edge,
                found.tail,
                cost,
                NONE,
                False,
                NONE,
                NONE,
                Cond.none(),
            )
        )
        return OperationPath(found.head, len(self.segments) - 1, cost, NONE)

    def advance(
        mut self,
        graph: Graph,
        store: Store,
        path: OperationPath,
        edge: Int,
        requirement: Int,
        field: Int,
        cond: Cond,
    ) -> OperationPath:
        """Return a path one edge longer, as upstream `advance`.

        Args:
            graph: The graph.
            store: The store with the selections.
            path: The path.
            edge: The edge.
            requirement: The requirement tree, or `NONE`.
            field: The target field item, or `NONE` for a type target.
            cond: The condition of a type target.

        Returns:
            The new path.
        """
        ref found = graph.edges[edge]
        var cost = path.cost + found.cost(store)
        var alias = NONE
        var args = NONE
        var segment_cond = cond
        if field != NONE:
            ref item = store.items[field]
            alias = item.alias
            args = item.args
            segment_cond = Cond(item.skip, item.include)
        self.segments.append(
            PathSegment(
                path.last_segment,
                edge,
                found.tail,
                cost,
                requirement,
                field != NONE,
                alias,
                args,
                segment_cond,
            )
        )
        var union_context = path.union_context
        if found.kind == EdgeKind.FIELD_MOVE:
            union_context = NONE
            ref tail = graph.nodes[found.tail]
            if tail.is_union_members():
                self.unions.append(
                    UnionContext(
                        tail.union_type,
                        tail.union_field,
                        tail.subgraph,
                        tail.union_object,
                        tail.possible_members.copy(),
                    )
                )
                union_context = len(self.unions) - 1
        elif found.kind == EdgeKind.ABSTRACT_MOVE:
            if path.union_context != NONE:
                var narrowed = self.unions[path.union_context].copy()
                narrowed.member_name = found.name
                narrowed.possible_members = [found.name]
                self.unions.append(narrowed^)
                union_context = len(self.unions) - 1
        elif (
            found.kind == EdgeKind.ENTITY_MOVE
            or found.kind == EdgeKind.INTERFACE_OBJECT_TYPE_MOVE
            or found.kind == EdgeKind.REENTRY_MOVE
        ):
            union_context = NONE
        return OperationPath(
            path.root_node, len(self.segments) - 1, cost, union_context
        )

    def can_resolve_union_member(
        self, path: OperationPath, member: Int
    ) -> Bool:
        """Return True if a path is not limited to other union members.

        Args:
            path: The path.
            member: The member, as a symbol.

        Returns:
            Whether the path has no union context, or the member is in it.
        """
        if path.union_context == NONE:
            return True
        return self.unions[path.union_context].can_resolve_member(member)

    def segments_of(self, path: OperationPath) -> List[Int]:
        """Return the segments of a path, first to last.

        Args:
            path: The path.

        Returns:
            The segment indices.
        """
        var out = List[Int]()
        var current = path.last_segment
        while current != NONE:
            out.append(current)
            current = self.segments[current].prev
        out.reverse()
        return out^

    def edges_of(self, path: OperationPath) -> List[Int]:
        """Return the edges of a path, first to last.

        Args:
            path: The path.

        Returns:
            The edge indices.
        """
        var out = List[Int]()
        var current = path.last_segment
        while current != NONE:
            out.append(self.segments[current].edge)
            current = self.segments[current].prev
        out.reverse()
        return out^

    def path_text(
        self, graph: Graph, store: Store, path: OperationPath
    ) -> String:
        """Return a path as upstream `pretty_print`.

        Args:
            graph: The graph.
            store: The store with the names.
            path: The path.

        Returns:
            The root node name for an empty path, or the edges.
        """
        var edges = self.edges_of(path)
        if len(edges) == 0:
            return graph.node_name(store, path.root_node)
        var out = graph.edge_text(store, edges[0], False)
        var index = 1
        while index < len(edges):
            out += " "
            out += graph.edge_text(store, edges[index], True)
            index += 1
        return out^

    def requirement_continuation(
        mut self, source: OperationPath, target: OperationPath
    ) -> OperationPath:
        """Return the part of `target` after it leaves `source`, as
        upstream `build_requirement_continuation_path`.

        Args:
            source: The path the requirement check started from.
            target: A path that satisfies part of the requirement.

        Returns:
            The divergent suffix of `target`, with costs relative to the
            divergence point and the union context of `target`.
        """
        var source_segments = self.segments_of(source)
        var target_segments = self.segments_of(target)
        var common = NONE
        var length = min(len(source_segments), len(target_segments))
        for index in range(length):
            if (
                self.segments[source_segments[index]].edge
                == self.segments[target_segments[index]].edge
            ):
                common = index
            else:
                break
        var root = source.root_node
        var offset = 0
        if common != NONE:
            root = self.segments[target_segments[common]].tail
            offset = self.segments[target_segments[common]].cumulative_cost
        var previous = NONE
        for index in range(common + 1, len(target_segments)):
            var copy = self.segments[target_segments[index]].copy()
            copy.prev = previous
            copy.cumulative_cost -= offset
            self.segments.append(copy^)
            previous = len(self.segments) - 1
        var cost = 0
        if previous != NONE:
            cost = self.segments[previous].cumulative_cost
        return OperationPath(root, previous, cost, target.union_context)

    # --- trees ----------------------------------------------------------

    def add_tree(mut self, graph: Graph, var node: TreeNode) -> Int:
        """Add a tree node, with its cost.

        Args:
            graph: The graph.
            node: The node.

        Returns:
            Its index.
        """
        var cost = FIELD_COST
        for child in node.children:
            ref found = self.trees[child]
            if (
                found.edge_from_parent != NONE
                and graph.edges[found.edge_from_parent].kind
                == EdgeKind.SUBGRAPH_ENTRYPOINT
            ):
                cost += CROSS_SUBGRAPH_COST
            cost += found.cost
        for requirement in node.requirements:
            cost += CROSS_SUBGRAPH_COST + self.trees[requirement].cost
        node.cost = cost
        self.trees.append(node^)
        return len(self.trees) - 1

    def trees_equal(self, a: Int, b: Int) -> Bool:
        """Return True if two tree nodes match, as upstream `PartialEq`.

        Args:
            a: A node.
            b: Another node.

        Returns:
            Whether the graph node, the edge, the field attributes, the
            mutation position and the condition are equal.
        """
        ref left = self.trees[a]
        ref right = self.trees[b]
        return (
            left.node_index == right.node_index
            and left.edge_from_parent == right.edge_from_parent
            and left.has_attributes == right.has_attributes
            and left.alias == right.alias
            and left.args == right.args
            and left.mutation_field_position == right.mutation_field_position
            and left.cond == right.cond
        )

    def merge(mut self, graph: Graph, target: Int, source: Int) -> Int:
        """Return a node with the children and requirements of two nodes
        merged, as upstream `merge_nodes`.

        Args:
            graph: The graph.
            target: The node merged into.
            source: The node merged from.

        Returns:
            The new node.
        """
        if (
            len(self.trees[source].children) == 0
            and len(self.trees[source].requirements) == 0
        ):
            return target
        var node = self.trees[target].copy()
        var children = self.trees[source].children.copy()
        var requirements = self.trees[source].requirements.copy()
        self._merge_list(graph, node.children, children)
        self._merge_list(graph, node.requirements, requirements)
        return self.add_tree(graph, node^)

    def _merge_list(
        mut self, graph: Graph, mut target: List[Int], source: List[Int]
    ):
        """Merge each source node into the first matching target node, or
        add it, as upstream `merge_query_tree_node_list`."""
        for source_node in source:
            var matched = False
            for index in range(len(target)):
                if self.trees_equal(target[index], source_node):
                    target[index] = self.merge(
                        graph, target[index], source_node
                    )
                    matched = True
                    break
            if not matched:
                target.append(source_node)

    def tree_from_path(
        mut self,
        graph: Graph,
        path: OperationPath,
        mutation_field_position: Int,
    ) -> Int:
        """Return the query tree of one path, as upstream
        `QueryTree::from_path`.

        Args:
            graph: The graph.
            path: The path.
            mutation_field_position: The root mutation field position, or
                `NONE`.

        Returns:
            The root tree node.
        """
        var segments = self.segments_of(path)
        var child = NONE
        var index = len(segments) - 1
        while index >= 0:
            var segment = self.segments[segments[index]].copy()
            var requirements = List[Int]()
            if segment.requirement_tree != NONE:
                requirements.append(segment.requirement_tree)
            var children = List[Int]()
            if child != NONE:
                children.append(child)
            child = self.add_tree(
                graph,
                TreeNode(
                    graph.edges[segment.edge].tail,
                    segment.edge,
                    requirements^,
                    children^,
                    segment.has_attributes,
                    segment.alias,
                    segment.args,
                    segment.cond,
                    mutation_field_position if index == 0 else NONE,
                    0,
                ),
            )
            index -= 1
        var root_children = List[Int]()
        if child != NONE:
            root_children.append(child)
        return self.add_tree(
            graph,
            TreeNode(
                path.root_node,
                NONE,
                List[Int](),
                root_children^,
                False,
                NONE,
                NONE,
                Cond.none(),
                NONE,
                0,
            ),
        )

    def tree_from_paths(
        mut self,
        graph: Graph,
        paths: List[OperationPath],
        mutation_field_position: Int,
    ) -> Int:
        """Return the merged query tree of paths, as upstream
        `QueryTreeNode::from_paths`.

        Args:
            graph: The graph.
            paths: The paths.
            mutation_field_position: The root mutation field position, or
                `NONE`.

        Returns:
            The root tree node, or `NONE` when there are no paths.
        """
        if len(paths) == 0:
            return NONE
        var root = self.tree_from_path(graph, paths[0], mutation_field_position)
        for index in range(1, len(paths)):
            root = self.merge(
                graph,
                root,
                self.tree_from_path(
                    graph, paths[index], mutation_field_position
                ),
            )
        return root

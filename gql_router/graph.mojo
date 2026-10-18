# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The query planner graph.

Port of Hive Router `1a29df9` `bin/router/src/query_planner/graph/`:
`mod.rs`, `node.rs`, `edge.rs`, `provided.rs` and `error.rs`, and
`FederationRules` of `federation_spec/mod.rs`.

A node is a type in one subgraph, or a root of the supergraph. An edge is
a move: a field, an entity call by `@key`, an abstract move to an object
type, a subgraph entrypoint, a root reentry, or a type move of an
`@interfaceObject`. A `@provides` path gets its own copies of the nodes it
goes through.

The graph keeps the adjacency of upstream `petgraph`: the outgoing edges
of a node are visited newest first, and removing an edge moves the last
edge into its index.

**Differences from upstream.** Upstream iterates the supergraph
definitions in `HashMap` order. This port iterates them in source order,
so node and edge indices are the same on every run.
"""

from gql_router.ast import NONE, ItemKind
from gql_router.federation_spec import (
    JoinFieldDirective,
    OperationKind,
    OverrideLabel,
    PERCENTAGE_SCALE_FACTOR,
)
from gql_router.normalize import normalize_field_set
from gql_router.selection_set import set_cost, set_text
from gql_router.store import Store
from gql_router.supergraph_state import (
    DefinitionKind,
    SupergraphDefinition,
    SupergraphField,
    SupergraphState,
)


@fieldwise_init
struct NodeKind(Equatable, ImplicitlyCopyable, Movable):
    """The kind of a graph node, as upstream `Node`."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime QUERY_ROOT = NodeKind(0)
    """The query root of the supergraph."""
    comptime MUTATION_ROOT = NodeKind(1)
    """The mutation root of the supergraph."""
    comptime SUBSCRIPTION_ROOT = NodeKind(2)
    """The subscription root of the supergraph."""
    comptime SUBGRAPH_TYPE = NodeKind(3)
    """A type in one subgraph."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the four kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 3


@fieldwise_init
struct Specialization(Equatable, ImplicitlyCopyable, Movable):
    """The specialization of a subgraph type, as upstream
    `SubgraphTypeSpecialization`."""

    var value: UInt8
    """The specialization's index; see `is_valid`."""

    comptime NONE = Specialization(0)
    """A plain type."""
    comptime ROOT = Specialization(1)
    """The root type of a subgraph, an entrypoint."""
    comptime UNION_MEMBERS = Specialization(2)
    """The tail of a union field that holds the members one subgraph
    resolves."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the three kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 2


struct Node(Copyable, Movable):
    """One node of the graph, as upstream `Node`."""

    var kind: NodeKind
    """What the node is."""
    var name: Int
    """The type name, as a symbol."""
    var subgraph: Int
    """The subgraph name, as a symbol, or `NONE` for a root."""
    var subgraph_index: Int
    """The subgraph's index in `SupergraphState.subgraph_names`."""
    var is_interface_object: Bool
    """Whether the type is an `@interfaceObject` in the subgraph."""
    var specialization: Specialization
    """Whether the node is an entrypoint or a union member tail."""
    var union_type: Int
    """For a union member tail: the type that owns the field."""
    var union_field: Int
    """For a union member tail: the field that returns the union."""
    var union_object: Int
    """For a union member tail: the member."""
    var possible_members: List[Int]
    """For a union member tail: every member the field reaches here."""
    var provided: String
    """What a `@provides` path makes available, such as `{sku}`, or empty
    for a node that is not a copy."""

    def __init__(out self, kind: NodeKind, name: Int, subgraph: Int):
        """Start a plain node.

        Args:
            kind: The node kind.
            name: The type name, as a symbol.
            subgraph: The subgraph name, as a symbol, or `NONE`.
        """
        self.kind = kind
        self.name = name
        self.subgraph = subgraph
        self.subgraph_index = 0
        self.is_interface_object = False
        self.specialization = Specialization.NONE
        self.union_type = NONE
        self.union_field = NONE
        self.union_object = NONE
        self.possible_members = List[Int]()
        self.provided = String()

    @staticmethod
    def subgraph_type(
        name: Int, subgraph: Int, is_interface_object: Bool
    ) -> Node:
        """Return a plain subgraph type, as upstream `Node::new_node`.

        Args:
            name: The type name, as a symbol.
            subgraph: The subgraph name, as a symbol.
            is_interface_object: Whether it is an `@interfaceObject`.

        Returns:
            The node.
        """
        var node = Node(NodeKind.SUBGRAPH_TYPE, name, subgraph)
        node.is_interface_object = is_interface_object
        return node^

    def is_using_provides(self) -> Bool:
        """Return True for a copy of a `@provides` path.

        Returns:
            Whether `provided` is set.
        """
        return self.provided.byte_length() > 0

    def is_union_members(self) -> Bool:
        """Return True for a union member tail.

        Returns:
            Whether the specialization is `UNION_MEMBERS`.
        """
        return self.specialization == Specialization.UNION_MEMBERS

    def plain_display_name(self, store: Store) -> String:
        """Return `Type/subgraph`.

        Args:
            store: The store with the names.

        Returns:
            The name.
        """
        return store.name(self.name) + "/" + store.name(self.subgraph)

    def display_name(self, store: Store) -> String:
        """Return the node name, as upstream `display_name`. Two nodes with
        the same name are the same node.

        Args:
            store: The store with the names.

        Returns:
            Such as `root(Query)`, `User/accounts`,
            `Media/a for Query.media:Book`, or `User/a{name}`.
        """
        if self.kind != NodeKind.SUBGRAPH_TYPE:
            return "root(" + store.name(self.name) + ")"
        var out = self.plain_display_name(store)
        if self.specialization == Specialization.UNION_MEMBERS:
            out += " for "
            out += store.name(self.union_type)
            out += "."
            out += store.name(self.union_field)
            out += ":"
            out += store.name(self.union_object)
        out += self.provided
        return out^


@fieldwise_init
struct EdgeKind(Equatable, ImplicitlyCopyable, Movable):
    """The kind of a graph edge, as upstream `Edge`."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime SUBGRAPH_ENTRYPOINT = EdgeKind(0)
    """From a supergraph root to the root type of a subgraph."""
    comptime FIELD_MOVE = EdgeKind(1)
    """A field."""
    comptime REENTRY_MOVE = EdgeKind(2)
    """A field that returns a root type, into another subgraph's root."""
    comptime ENTITY_MOVE = EdgeKind(3)
    """An entity call by `@key`."""
    comptime ABSTRACT_MOVE = EdgeKind(4)
    """From an abstract type to an object type, `join__implements`."""
    comptime SELFIE = EdgeKind(5)
    """A type condition on the same type."""
    comptime INTERFACE_OBJECT_TYPE_MOVE = EdgeKind(6)
    """From an `@interfaceObject` to an object type, by an entity call."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the seven kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 6


struct Edge(Copyable, Movable):
    """One edge of the graph, as upstream `Edge`."""

    var kind: EdgeKind
    """What the edge is."""
    var head: Int
    """The node the edge leaves."""
    var tail: Int
    """The node the edge enters."""
    var next_out: Int
    """The next outgoing edge of `head`, or `NONE`."""
    var next_in: Int
    """The next incoming edge of `tail`, or `NONE`."""
    var name: Int
    """The field name, the abstract or selfie type, the entrypoint's
    subgraph name, or the object type of an interface object move."""
    var type_name: Int
    """The type that owns a field or reentry move."""
    var key: String
    """The `@key` of an entity move."""
    var requirement_type: Int
    """The type of the requirements, or `NONE` for none."""
    var requirements: Int
    """The requirements: a key, a `@requires`, or `__typename`; a `ROOT`
    item, or `NONE`."""
    var is_leaf: Bool
    """Whether a field move returns a scalar."""
    var is_list: Bool
    """Whether a field or reentry move returns a list."""
    var is_interface: Bool
    """Whether an entity move is to an interface entity."""
    var operation_kind: OperationKind
    """The operation kind of an entrypoint."""
    var join_field: Optional[JoinFieldDirective]
    """The `@join__field` of a field move."""
    var override_from: Int
    """The subgraph name a field move overrides, as a symbol, or `NONE`."""
    var override_label: Optional[OverrideLabel]
    """The label of that override."""
    var overridden_by: Int
    """The subgraph name that overrides a field move, or `NONE`."""
    var overridden_label: Optional[OverrideLabel]
    """The label of that override."""

    def __init__(out self, kind: EdgeKind, name: Int):
        """Start an edge with no requirements.

        Args:
            kind: The edge kind.
            name: The edge name, as a symbol.
        """
        self.kind = kind
        self.head = NONE
        self.tail = NONE
        self.next_out = NONE
        self.next_in = NONE
        self.name = name
        self.type_name = NONE
        self.key = String()
        self.requirement_type = NONE
        self.requirements = NONE
        self.is_leaf = False
        self.is_list = False
        self.is_interface = False
        self.operation_kind = OperationKind.QUERY
        self.join_field = None
        self.override_from = NONE
        self.override_label = None
        self.overridden_by = NONE
        self.overridden_label = None

    def has_requirements(self) -> Bool:
        """Return True if the edge has requirements.

        Returns:
            Whether `requirements` is set.
        """
        return self.requirements != NONE

    def cost(self, store: Store) -> Int:
        """Return the cost of the move, as upstream `Edge::cost`.

        Args:
            store: The store with the requirements.

        Returns:
            1 for a field move and 1000 for any other move, plus the cost
            of the requirements.
        """
        var cost = 1 if self.kind == EdgeKind.FIELD_MOVE else 1000
        if self.requirements != NONE:
            cost += set_cost(store, self.requirements)
        return cost

    def same_as(self, store: Store, other: Edge) -> Bool:
        """Return True if two edges are equal, as upstream `Edge` equality.

        Args:
            store: The store with the selections.
            other: Another edge.

        Returns:
            Whether the edges are equal. A selfie equals no edge.
        """
        if self.kind != other.kind or self.kind == EdgeKind.SELFIE:
            return False
        if self.kind == EdgeKind.ENTITY_MOVE:
            return self.key == other.key
        if self.kind == EdgeKind.FIELD_MOVE:
            return (
                self.name == other.name
                and self.type_name == other.type_name
                and self.is_leaf == other.is_leaf
                and self.is_list == other.is_list
                and self.override_from == other.override_from
                and self.overridden_by == other.overridden_by
                and (self.requirements == NONE) == (other.requirements == NONE)
            )
        if self.kind == EdgeKind.REENTRY_MOVE:
            return (
                self.name == other.name
                and self.type_name == other.type_name
                and self.is_list == other.is_list
            )
        return self.name == other.name

    def display_name(self, store: Store) -> String:
        """Return the edge name, as upstream `Edge::display_name`.

        Args:
            store: The store with the names.

        Returns:
            The field name, the key, the type, or `selfie`.
        """
        if self.kind == EdgeKind.ENTITY_MOVE:
            return self.key
        if self.kind == EdgeKind.SELFIE:
            return "selfie"
        return store.name(self.name)

    def text(self, store: Store) -> String:
        """Return the edge as upstream `Display`.

        Args:
            store: The store with the names.

        Returns:
            Such as `name`, `🔑🧩{id}` or `🔁 me`.
        """
        var out = String()
        if self.kind == EdgeKind.ENTITY_MOVE:
            out += "🔑"
        elif self.kind == EdgeKind.ABSTRACT_MOVE:
            out += "🔮"
        elif self.kind == EdgeKind.SELFIE:
            out += "🤳"
        elif self.kind == EdgeKind.INTERFACE_OBJECT_TYPE_MOVE:
            out += "🔎 "
            out += store.name(self.name)
        elif self.kind == EdgeKind.REENTRY_MOVE:
            out += "🔁 "
            out += store.name(self.name)
        else:
            out += store.name(self.name)
        if self.requirements != NONE:
            out += "🧩"
            out += set_text(store, self.requirements)
        return out^

    def debug_text(self, store: Store) -> String:
        """Return the edge as upstream `Debug`.

        Args:
            store: The store with the names.

        Returns:
            Such as `author @requires(secret) @provides`, `🔑 id` or
            `🚪 subgraph(a)`.
        """
        if self.kind == EdgeKind.SUBGRAPH_ENTRYPOINT:
            return "🚪 subgraph(" + store.name(self.name) + ")"
        if self.kind == EdgeKind.REENTRY_MOVE:
            return "🔁 " + store.name(self.name)
        if self.kind == EdgeKind.ENTITY_MOVE:
            return "🔑 " + self.key
        if self.kind == EdgeKind.ABSTRACT_MOVE:
            return "🔮 " + store.name(self.name)
        if self.kind == EdgeKind.SELFIE:
            return "🤳"
        if self.kind == EdgeKind.INTERFACE_OBJECT_TYPE_MOVE:
            return "🔎 " + store.name(self.name)
        var out = store.name(self.name)
        if self.join_field:
            ref join_field = self.join_field.value()
            if join_field.requires:
                out += " @requires(" + join_field.requires.value() + ")"
            if join_field.provides:
                out += " @provides"
            if join_field.external:
                out += " @external"
            if join_field.override_value:
                out += " @override(from: " + join_field.override_value.value()
                if join_field.override_label:
                    ref label = join_field.override_label.value()
                    out += ", label: "
                    if label.is_percent:
                        out += String(label.percent // PERCENTAGE_SCALE_FACTOR)
                        out += "%"
                    else:
                        out += store.name(label.custom)
                out += ")"
        return out^


@fieldwise_init
struct PlannerOverrideContext(Copyable, Movable):
    """The request's override flags, as upstream `PlannerOverrideContext`."""

    var active_flags: List[String]
    """The active custom labels."""
    var request_percentage_value: UInt64
    """The request's percentage times `PERCENTAGE_SCALE_FACTOR`."""

    @staticmethod
    def default() -> PlannerOverrideContext:
        """Return a context with no flags and percentage 0.

        Returns:
            The context.
        """
        return PlannerOverrideContext(List[String](), 0)

    @staticmethod
    def from_percentage(value: Float64) -> PlannerOverrideContext:
        """Return a context for a request percentage.

        Args:
            value: The percentage, 0 to 100.

        Returns:
            The context.
        """
        return PlannerOverrideContext(
            List[String](), UInt64(value * Float64(PERCENTAGE_SCALE_FACTOR))
        )

    @staticmethod
    def from_flag(flag: String) -> PlannerOverrideContext:
        """Return a context with one active flag.

        Args:
            flag: The flag.

        Returns:
            The context.
        """
        return PlannerOverrideContext([flag], 0)

    def is_flag_active(self, flag: String) -> Bool:
        """Return True if a flag is active.

        Args:
            flag: The flag.

        Returns:
            Whether the flag is in `active_flags`.
        """
        for active in self.active_flags:
            if active == flag:
                return True
        return False

    def is_in_range(self, percentage: UInt64) -> Bool:
        """Return True if the request falls under a percentage.

        Args:
            percentage: The label's percentage, scaled.

        Returns:
            Whether the request value is less than the percentage.
        """
        return self.request_percentage_value < percentage


def _check_progressive(
    store: Store,
    label: OverrideLabel,
    ctx: PlannerOverrideContext,
    is_overriding_field: Bool,
) -> Bool:
    """Return upstream `check_progressive_override`."""
    if label.is_percent:
        return is_overriding_field == ctx.is_in_range(label.percent)
    return is_overriding_field == ctx.is_flag_active(store.name(label.custom))


def satisfies_override_rules(
    store: Store, edge: Edge, ctx: PlannerOverrideContext
) -> Bool:
    """Return True if a field move is resolvable for a request, as upstream
    `FieldMove::satisfies_override_rules`.

    Args:
        store: The store with the labels.
        edge: A field move.
        ctx: The request's override context.

    Returns:
        Whether the field stays resolvable on this edge.
    """
    if edge.overridden_by != NONE and edge.overridden_label:
        return _check_progressive(
            store, edge.overridden_label.value(), ctx, False
        )
    if edge.overridden_by != NONE:
        return False
    if edge.override_label:
        return _check_progressive(store, edge.override_label.value(), ctx, True)
    return True


# --- Provided ------------------------------------------------------------


@fieldwise_init
struct ProvidedNode(Copyable, Movable):
    """One tree of fields and type conditions, as upstream `Provided`."""

    var field_names: List[Int]
    """The provided fields, as symbols, sorted by name."""
    var field_children: List[Int]
    """What each field provides below it."""
    var type_names: List[Int]
    """The type conditions, as symbols, sorted by name."""
    var type_children: List[Int]
    """What each type condition provides."""


struct ProvidedPool(Movable):
    """Every `Provided` tree, by id. A tree never changes once it is made;
    a merge makes a new one. Id 0 is the empty tree."""

    var nodes: List[ProvidedNode]
    """The trees."""

    def __init__(out self):
        """Start with the empty tree."""
        self.nodes = List[ProvidedNode]()
        self.nodes.append(
            ProvidedNode(List[Int](), List[Int](), List[Int](), List[Int]())
        )

    def is_empty(self, id: Int) -> Bool:
        """Return True if a tree provides nothing.

        Args:
            id: The tree.

        Returns:
            Whether it has no field and no type condition.
        """
        ref node = self.nodes[id]
        return len(node.field_names) == 0 and len(node.type_names) == 0

    def field_child(self, id: Int, name: Int) -> Int:
        """Return what a tree provides below a field.

        Args:
            id: The tree.
            name: The field name, as a symbol.

        Returns:
            The subtree, or `NONE` when the field is not provided.
        """
        ref node = self.nodes[id]
        for index in range(len(node.field_names)):
            if node.field_names[index] == name:
                return node.field_children[index]
        return NONE

    def type_child(self, id: Int, name: Int) -> Int:
        """Return what a tree provides on a type condition.

        Args:
            id: The tree.
            name: The type name, as a symbol.

        Returns:
            The subtree, or `NONE` when there is no such condition.
        """
        ref node = self.nodes[id]
        for index in range(len(node.type_names)):
            if node.type_names[index] == name:
                return node.type_children[index]
        return NONE

    def _add(mut self, var node: ProvidedNode) -> Int:
        """Add a tree and return its id."""
        self.nodes.append(node^)
        return len(self.nodes) - 1

    def with_entry(
        mut self,
        store: Store,
        id: Int,
        name: Int,
        below: Int,
        on_type: Bool,
    ) -> Int:
        """Return a tree with one more field or type condition, merged into
        an existing entry of that name.

        Args:
            store: The store with the names.
            id: The tree.
            name: The field or type name, as a symbol.
            below: What it provides.
            on_type: Whether the entry is a type condition.

        Returns:
            The new tree.
        """
        var node = self.nodes[id].copy()
        if on_type:
            self._put(store, node.type_names, node.type_children, name, below)
        else:
            self._put(store, node.field_names, node.field_children, name, below)
        return self._add(node^)

    def _put(
        mut self,
        store: Store,
        mut names: List[Int],
        mut children: List[Int],
        name: Int,
        below: Int,
    ):
        """Merge one entry into sorted lists of names and subtrees."""
        for index in range(len(names)):
            if names[index] == name:
                children[index] = self.merge(store, children[index], below)
                return
        var at = len(names)
        while at > 0 and store.less(name, names[at - 1]):
            at -= 1
        names.insert(at, name)
        children.insert(at, below)

    def without_type(mut self, id: Int, name: Int) -> Int:
        """Return a tree without one of its type conditions.

        Args:
            id: The tree.
            name: The type name, as a symbol. The tree must have it.

        Returns:
            The new tree.
        """
        var node = self.nodes[id].copy()
        var index = 0
        while node.type_names[index] != name:
            index += 1
        _ = node.type_names.pop(index)
        _ = node.type_children.pop(index)
        return self._add(node^)

    def merge(mut self, store: Store, a: Int, b: Int) -> Int:
        """Return the union of two trees, as upstream `Provided::merge`.

        Args:
            store: The store with the names.
            a: A tree.
            b: Another tree.

        Returns:
            The merged tree.
        """
        if self.is_empty(b):
            return a
        if self.is_empty(a):
            return b
        var out = a
        var other = self.nodes[b].copy()
        for index in range(len(other.field_names)):
            out = self.with_entry(
                store,
                out,
                other.field_names[index],
                other.field_children[index],
                False,
            )
        for index in range(len(other.type_names)):
            out = self.with_entry(
                store,
                out,
                other.type_names[index],
                other.type_children[index],
                True,
            )
        return out

    def from_set(mut self, store: Store, set: Int) raises -> Int:
        """Read a normalized `@provides` selection set, as upstream
        `Provided::from_selection_set`.

        Args:
            store: The store with the selections.
            set: The selection set.

        Returns:
            The tree. `__typename` is left out: every node resolves it.

        Raises:
            Error: On a fragment spread or an inline fragment without a
                type condition.
        """
        var out = 0
        var child = store.items[set].first
        while child != NONE:
            ref item = store.items[child]
            if item.kind == ItemKind.FIELD:
                if store.name(item.name) != "__typename":
                    out = self.with_entry(
                        store,
                        out,
                        item.name,
                        self.from_set(store, child),
                        False,
                    )
            elif item.kind == ItemKind.FRAGMENT:
                if item.name == NONE:
                    raise Error(
                        "Inline fragment without type condition detected"
                    )
                out = self.with_entry(
                    store, out, item.name, self.from_set(store, child), True
                )
            else:
                raise Error(
                    "Fragment spread detected. Expected either a Field or an"
                    " Inline Fragment"
                )
            child = store.items[child].next
        return out

    def text(self, store: Store, id: Int) -> String:
        """Return a tree as upstream `Display`.

        Args:
            store: The store with the names.
            id: The tree.

        Returns:
            Such as `{sku product{name} ...on Book{isbn}}`.
        """
        var out = String("{")
        ref node = self.nodes[id]
        var first = True
        for index in range(len(node.field_names)):
            if not first:
                out += " "
            first = False
            out += store.name(node.field_names[index])
            if not self.is_empty(node.field_children[index]):
                out += self.text(store, node.field_children[index])
        for index in range(len(node.type_names)):
            if not first:
                out += " "
            first = False
            out += "...on "
            out += store.name(node.type_names[index])
            if not self.is_empty(node.type_children[index]):
                out += self.text(store, node.type_children[index])
        out += "}"
        return out^


# --- the graph -----------------------------------------------------------


struct Graph(Movable):
    """The query planner graph, as upstream `Graph`."""

    var nodes: List[Node]
    """Every node, by index."""
    var edges: List[Edge]
    """Every edge, by index."""
    var first_out: List[Int]
    """The newest outgoing edge of each node, or `NONE`."""
    var first_in: List[Int]
    """The newest incoming edge of each node, or `NONE`."""
    var node_ids: Dict[String, Int]
    """The index of each node, by display name."""
    var query_root: Int
    """The query root node."""
    var mutation_root: Int
    """The mutation root node, or `NONE`."""
    var subscription_root: Int
    """The subscription root node, or `NONE`."""

    def __init__(out self):
        """Start an empty graph."""
        self.nodes = List[Node]()
        self.edges = List[Edge]()
        self.first_out = List[Int]()
        self.first_in = List[Int]()
        self.node_ids = Dict[String, Int]()
        self.query_root = NONE
        self.mutation_root = NONE
        self.subscription_root = NONE

    def add_node(mut self, var node: Node) -> Int:
        """Add a node.

        Args:
            node: The node.

        Returns:
            Its index.
        """
        self.nodes.append(node^)
        self.first_out.append(NONE)
        self.first_in.append(NONE)
        return len(self.nodes) - 1

    def upsert_node(mut self, store: Store, var node: Node) -> Int:
        """Return the node with the same display name, adding it when new.

        Args:
            store: The store with the names.
            node: The node.

        Returns:
            Its index.
        """
        var name = node.display_name(store)
        var found = self.node_ids.get(name)
        if found:
            return found.value()
        var index = self.add_node(node^)
        self.node_ids[name^] = index
        return index

    def find_node(self, name: String) -> Int:
        """Return a node by display name.

        Args:
            name: The display name.

        Returns:
            Its index, or `NONE`.
        """
        var found = self.node_ids.get(name)
        if found:
            return found.value()
        return NONE

    def add_edge(mut self, head: Int, tail: Int, var edge: Edge) -> Int:
        """Add an edge in front of the edge lists of its ends.

        Args:
            head: The node the edge leaves.
            tail: The node the edge enters.
            edge: The edge.

        Returns:
            Its index.
        """
        var index = len(self.edges)
        edge.head = head
        edge.tail = tail
        edge.next_out = self.first_out[head]
        edge.next_in = self.first_in[tail]
        self.edges.append(edge^)
        self.first_out[head] = index
        self.first_in[tail] = index
        return index

    def upsert_edge(
        mut self, store: Store, head: Int, tail: Int, var edge: Edge
    ) -> Int:
        """Return an equal edge between the same nodes, adding it when new.

        Args:
            store: The store with the selections.
            head: The node the edge leaves.
            tail: The node the edge enters.
            edge: The edge.

        Returns:
            Its index.
        """
        var existing = self.first_out[head]
        while existing != NONE:
            if self.edges[existing].tail == tail and self.edges[
                existing
            ].same_as(store, edge):
                return existing
            existing = self.edges[existing].next_out
        return self.add_edge(head, tail, edge^)

    def _relink(mut self, edge: Int, replacement_out: Int, replacement_in: Int):
        """Replace the links to an edge in its two lists."""
        var head = self.edges[edge].head
        var tail = self.edges[edge].tail
        if self.first_out[head] == edge:
            self.first_out[head] = replacement_out
        else:
            var at = self.first_out[head]
            while self.edges[at].next_out != edge:
                at = self.edges[at].next_out
            self.edges[at].next_out = replacement_out
        if self.first_in[tail] == edge:
            self.first_in[tail] = replacement_in
        else:
            var at = self.first_in[tail]
            while self.edges[at].next_in != edge:
                at = self.edges[at].next_in
            self.edges[at].next_in = replacement_in

    def remove_edge(mut self, edge: Int) -> Edge:
        """Remove an edge, as `petgraph` `remove_edge`: the last edge moves
        into the freed index and keeps its place in its lists.

        Args:
            edge: The edge.

        Returns:
            The removed edge.
        """
        self._relink(edge, self.edges[edge].next_out, self.edges[edge].next_in)
        var last = len(self.edges) - 1
        if edge != last:
            self._relink(last, edge, edge)
            self.edges.swap_elements(edge, last)
        var removed = self.edges.pop()
        removed.next_out = NONE
        removed.next_in = NONE
        return removed^

    def edges_from(self, node: Int) -> List[Int]:
        """Return the outgoing edges of a node, newest first.

        Args:
            node: The node.

        Returns:
            The edge indices.
        """
        var out = List[Int]()
        var edge = self.first_out[node]
        while edge != NONE:
            out.append(edge)
            edge = self.edges[edge].next_out
        return out^

    def edges_to(self, node: Int) -> List[Int]:
        """Return the incoming edges of a node, newest first.

        Args:
            node: The node.

        Returns:
            The edge indices.
        """
        var out = List[Int]()
        var edge = self.first_in[node]
        while edge != NONE:
            out.append(edge)
            edge = self.edges[edge].next_in
        return out^

    def node_name(self, store: Store, node: Int) -> String:
        """Return a node's display name.

        Args:
            store: The store with the names.
            node: The node.

        Returns:
            The name, as upstream `pretty_print_node`.
        """
        return self.nodes[node].display_name(store)

    def edge_text(
        self, store: Store, edge: Int, without_source: Bool
    ) -> String:
        """Return an edge with its ends, as upstream `pretty_print_edge`.

        Args:
            store: The store with the names.
            edge: The edge.
            without_source: Whether to leave out the head.

        Returns:
            Such as `User/a -(name)- String/a`.
        """
        ref found = self.edges[edge]
        var out = String()
        if not without_source:
            out += self.node_name(store, found.head)
            out += " "
        out += "-("
        out += found.text(store)
        out += ")- "
        out += self.node_name(store, found.tail)
        return out^

    def entrypoints(self, kind: OperationKind) raises -> List[Int]:
        """Return the entrypoint edges of a root, by edge index, as upstream
        `get_entrypoints`.

        Args:
            kind: The operation kind.

        Returns:
            The edges from the root, in index order.

        Raises:
            Error: When the supergraph has no root of that kind.
        """
        var root = self.query_root
        if kind == OperationKind.MUTATION:
            root = self.mutation_root
        elif kind == OperationKind.SUBSCRIPTION:
            root = self.subscription_root
        if root == NONE:
            raise Error("Missing root type " + String(kind.as_str()))
        var out = self.edges_from(root)
        sort(out)
        return out^


# --- FederationRules -----------------------------------------------------


struct _FieldSets(Movable):
    """The normalized field sets of the supergraph, parsed once each."""

    var sets: Dict[String, Int]
    """The `ROOT` item of each field set, by type, graph and text."""

    def __init__(out self):
        """Start with no field sets."""
        self.sets = Dict[String, Int]()

    def parse(
        mut self,
        mut store: Store,
        state: SupergraphState,
        graph_id: Int,
        type_name: Int,
        fields: String,
    ) raises -> Int:
        """Return a normalized field set, as upstream
        `FederationRules::parse_key`.

        Args:
            store: The store.
            state: The supergraph.
            graph_id: The subgraph, as a graph id symbol.
            type_name: The type the field set selects from.
            fields: The field set text.

        Returns:
            The selection set, a `ROOT` item.

        Raises:
            Error: When the field set does not normalize.
        """
        var key = String(type_name) + " " + String(graph_id) + " " + fields
        var found = self.sets.get(key)
        if found:
            return found.value()
        var set: Int
        try:
            set = normalize_field_set(store, state, type_name, graph_id, fields)
        except e:
            raise Error("Normalization error: " + String(e))
        self.sets[key^] = set
        return set


def field_availability(
    state: SupergraphState, definition: Int, field: Int, graph_id: Int
) -> Int:
    """Return how a subgraph resolves a field, as upstream
    `check_field_subgraph_availability`.

    Args:
        state: The supergraph.
        definition: The parent type's index.
        field: The field's index in the parent.
        graph_id: The subgraph, as a graph id symbol.

    Returns:
        The index of the field's `@join__field` for the subgraph; `-2` when
        the field has none and its type is in the subgraph; `NONE` when the
        subgraph does not resolve it.
    """
    ref parent = state.definitions[definition]
    ref join_fields = parent.fields[field].join_field
    if len(join_fields) == 0:
        if parent.is_defined_in_subgraph(graph_id):
            return -2
        return NONE
    var index = 0
    while index < len(join_fields):
        if join_fields[index].graph_id == graph_id:
            return index
        index += 1
    return NONE


# --- building ------------------------------------------------------------


def _root_of(graph: Graph, kind: Int) raises -> Int:
    """Return the root node of an operation kind value."""
    var root = graph.query_root
    if kind == Int(OperationKind.MUTATION.value):
        root = graph.mutation_root
    elif kind == Int(OperationKind.SUBSCRIPTION.value):
        root = graph.subscription_root
    if root == NONE:
        raise Error(
            "Unexpected missing root type "
            + String(OperationKind(UInt8(kind)).as_str())
        )
    return root


def _plain(
    mut graph: Graph,
    store: Store,
    state: SupergraphState,
    type_name: Int,
    graph_id: Int,
) raises -> Int:
    """Upsert the plain node of a type in a subgraph."""
    return graph.upsert_node(
        store,
        Node.subgraph_type(
            type_name,
            state.resolve_graph_id(graph_id),
            state.is_interface_object_in_subgraph(type_name, graph_id),
        ),
    )


def _field_move(
    store: Store,
    name: Int,
    type_name: Int,
    is_leaf: Bool,
    is_list: Bool,
) -> Edge:
    """Return a field move with no `@join__field`."""
    var edge = Edge(EdgeKind.FIELD_MOVE, name)
    edge.type_name = type_name
    edge.is_leaf = is_leaf
    edge.is_list = is_list
    return edge^


def build_graph(mut store: Store, state: SupergraphState) raises -> Graph:
    """Build the planner graph of a supergraph, as upstream
    `Graph::graph_from_supergraph_state`.

    Args:
        store: The store with the names; field sets are added to it.
        state: The supergraph.

    Returns:
        The graph.

    Raises:
        Error: When a root type, a subgraph or a field is missing, or a
            field set does not normalize.
    """
    var graph = Graph()
    var field_sets = _FieldSets()
    var pool = ProvidedPool()
    graph.query_root = graph.upsert_node(
        store, Node(NodeKind.QUERY_ROOT, state.query_type, NONE)
    )
    if state.mutation_type != NONE:
        graph.mutation_root = graph.upsert_node(
            store, Node(NodeKind.MUTATION_ROOT, state.mutation_type, NONE)
        )
    if state.subscription_type != NONE:
        graph.subscription_root = graph.upsert_node(
            store,
            Node(NodeKind.SUBSCRIPTION_ROOT, state.subscription_type, NONE),
        )
    _link_root_edges(graph, store, state)
    var provides = _build_field_edges(graph, store, state, field_sets, pool)
    _build_interface_implementation_edges(graph, store, state)
    _build_entity_reference_edges(graph, store, state, field_sets)
    _build_provides_edges(graph, store, state, pool, provides)
    # Each subgraph type node names a subgraph of the state, so upstream's
    # "Subgraph not found" error cannot happen.
    var index = 0
    while index < len(graph.nodes):
        if graph.nodes[index].kind == NodeKind.SUBGRAPH_TYPE:
            graph.nodes[index].subgraph_index = state.subgraph_index(
                graph.nodes[index].subgraph
            )
        index += 1
    return graph^


def _link_root_edges(
    mut graph: Graph, store: Store, state: SupergraphState
) raises:
    """Add an entrypoint from each root to each subgraph that resolves a
    root field, as upstream `link_root_edges`."""
    var index = 0
    while index < len(state.definitions):
        ref definition = state.definitions[index]
        index += 1
        if definition.root_type == NONE:
            continue
        var graph_ids = definition.subgraphs(store)
        var at = 0
        while at < len(graph_ids):
            var graph_id = graph_ids[at]
            at += 1
            var available = False
            var field = 0
            while field < len(definition.fields):
                if (
                    field_availability(state, index - 1, field, graph_id)
                    != NONE
                ):
                    available = True
                    break
                field += 1
            if not available:
                continue
            var head = _root_of(graph, definition.root_type)
            var subgraph = state.resolve_graph_id(graph_id)
            var node = Node.subgraph_type(definition.name, subgraph, False)
            node.specialization = Specialization.ROOT
            var tail = graph.upsert_node(store, node^)
            var edge = Edge(EdgeKind.SUBGRAPH_ENTRYPOINT, subgraph)
            edge.operation_kind = OperationKind(UInt8(definition.root_type))
            _ = graph.upsert_edge(store, head, tail, edge^)


def _build_interface_implementation_edges(
    mut graph: Graph, store: Store, state: SupergraphState
) raises:
    """Add an abstract move from each interface to each object type that
    implements it in a subgraph."""
    var index = 0
    while index < len(state.definitions):
        ref definition = state.definitions[index]
        index += 1
        if definition.kind != DefinitionKind.OBJECT:
            continue
        for implements in definition.join_implements:
            var subgraph = state.resolve_graph_id(implements.graph_id)
            var tail = graph.upsert_node(
                store, Node.subgraph_type(definition.name, subgraph, False)
            )
            var head = graph.upsert_node(
                store,
                Node.subgraph_type(implements.interface, subgraph, False),
            )
            _ = graph.upsert_edge(
                store, head, tail, Edge(EdgeKind.ABSTRACT_MOVE, definition.name)
            )


def _create_field_move(
    mut store: Store,
    name: Int,
    type_name: Int,
    is_leaf: Bool,
    is_list: Bool,
    join_field: Optional[JoinFieldDirective],
    requirement_type: Int,
    requirements: Int,
    overridden_by: Int,
    overridden_label: Optional[OverrideLabel],
) -> Edge:
    """Return a field move, as upstream `Edge::create_field_move`."""
    var edge = _field_move(store, name, type_name, is_leaf, is_list)
    if join_field:
        ref found = join_field.value()
        if found.override_value:
            edge.override_from = store.sym(found.override_value.value())
        if found.override_label:
            edge.override_label = found.override_label.value().copy()
    edge.join_field = join_field.copy()
    edge.requirement_type = requirement_type
    edge.requirements = requirements
    edge.overridden_by = overridden_by
    edge.overridden_label = overridden_label.copy()
    return edge^


def _union_members_for_field(
    store: Store,
    state: SupergraphState,
    field: SupergraphField,
    union: Int,
    graph_id: Int,
) -> List[Int]:
    """Return the union members a field reaches in a subgraph, sorted, as
    upstream `members_for_field_in_graph`."""
    var field_type = field.field_type.inner_type()
    for join_field in field.join_field:
        if join_field.graph_id == graph_id:
            if join_field.type_in_graph:
                var in_graph = join_field.type_in_graph.value().inner_type()
                if in_graph != field_type:
                    return [in_graph]
            break
    var members = List[Int]()
    ref union_members = state.definitions[union].union_members
    var index = 0
    while index < len(union_members):
        ref member = union_members[index]
        index += 1
        if member.graph == graph_id:
            var seen = False
            for known in members:
                if known == member.member:
                    seen = True
            if not seen:
                var at = len(members)
                while at > 0 and store.less(member.member, members[at - 1]):
                    at -= 1
                members.insert(at, member.member)
    return members^


def _build_field_edges(
    mut graph: Graph,
    mut store: Store,
    state: SupergraphState,
    mut field_sets: _FieldSets,
    mut pool: ProvidedPool,
) raises -> Dict[Int, Int]:
    """Add the field moves of every type in every subgraph, as upstream
    `build_field_edges`.

    Returns:
        The `@provides` tree of each field edge that has one.
    """
    var provides = Dict[Int, Int]()
    var string_type = store.sym("String")
    var typename = store.sym("__typename")
    var index = 0
    while index < len(state.definitions):
        ref definition = state.definitions[index]
        var graph_ids = definition.subgraphs(store)
        var at = 0
        while at < len(graph_ids):
            var graph_id = graph_ids[at]
            at += 1
            var subgraph = state.resolve_graph_id(graph_id)
            var is_interface_object = False
            # A type is in a subgraph by one of its `@join__type`s.
            var join = 0
            while join < len(definition.join_types):
                ref join_type = definition.join_types[join]
                join += 1
                if (
                    join_type.graph_id == graph_id
                    and join_type.is_interface_object
                ):
                    is_interface_object = True
            if definition.kind.is_composite() and not is_interface_object:
                var typename_head = graph.upsert_node(
                    store, Node.subgraph_type(definition.name, subgraph, False)
                )
                var typename_tail = graph.upsert_node(
                    store, Node.subgraph_type(string_type, subgraph, False)
                )
                _ = graph.upsert_edge(
                    store,
                    typename_head,
                    typename_tail,
                    _field_move(store, typename, definition.name, True, False),
                )
            var head = _plain(graph, store, state, definition.name, graph_id)
            _ = graph.upsert_edge(
                store, head, head, Edge(EdgeKind.SELFIE, definition.name)
            )
            for field_index in range(len(definition.fields)):
                _add_field_edges(
                    graph,
                    store,
                    state,
                    field_sets,
                    pool,
                    provides,
                    index,
                    field_index,
                    graph_id,
                )
        index += 1
    return provides^


def _add_field_edges(
    mut graph: Graph,
    mut store: Store,
    state: SupergraphState,
    mut field_sets: _FieldSets,
    mut pool: ProvidedPool,
    mut provides: Dict[Int, Int],
    definition_index: Int,
    field_index: Int,
    graph_id: Int,
) raises:
    """Add the edges of one field in one subgraph."""
    ref definition = state.definitions[definition_index]
    ref field = definition.fields[field_index]
    var available = field_availability(
        state, definition_index, field_index, graph_id
    )
    if available == NONE:
        return
    var subgraph = state.resolve_graph_id(graph_id)
    var target = field.field_type.inner_type()
    var overridden_by = NONE
    var overridden_label = Optional[OverrideLabel](None)
    for join_field in field.join_field:
        if (
            join_field.override_value
            and join_field.override_value.value() == store.name(subgraph)
        ):
            overridden_by = state.resolve_graph_id(join_field.graph_id)
            if join_field.override_label:
                overridden_label = join_field.override_label.value().copy()
            break
    var join_field = Optional[JoinFieldDirective](None)
    if available >= 0:
        join_field = field.join_field[available].copy()
    var requirement_type = NONE
    var requirements = NONE
    var provided = NONE
    if join_field:
        ref found = join_field.value()
        if found.external and not found.requires:
            return
        if found.requires:
            requirement_type = definition.name
            requirements = field_sets.parse(
                store,
                state,
                found.graph_id,
                definition.name,
                found.requires.value(),
            )
        # `available` is the `@join__field` of this subgraph, so its graph
        # is set.
        if found.provides:
            provided = pool.from_set(
                store,
                field_sets.parse(
                    store, state, found.graph_id, target, found.provides.value()
                ),
            )
    var is_leaf = state.is_scalar_type(target)
    var is_list = field.field_type.is_list()
    var target_definition = state.definition(target)
    if (
        target_definition != NONE
        and state.definitions[target_definition].kind == DefinitionKind.UNION
    ):
        var head = _plain(graph, store, state, definition.name, graph_id)
        var members = _union_members_for_field(
            store, state, field, target_definition, graph_id
        )
        var at = 0
        while at < len(members):
            var member = members[at]
            at += 1
            var node = Node.subgraph_type(
                target,
                subgraph,
                state.is_interface_object_in_subgraph(target, graph_id),
            )
            node.specialization = Specialization.UNION_MEMBERS
            node.union_type = definition.name
            node.union_field = field.name
            node.union_object = member
            node.possible_members = members.copy()
            var tail = graph.upsert_node(store, node^)
            var abstract_tail = _plain(graph, store, state, member, graph_id)
            var typename_tail = graph.upsert_node(
                store, Node.subgraph_type(store.sym("String"), subgraph, False)
            )
            _ = graph.upsert_edge(
                store,
                tail,
                typename_tail,
                _field_move(
                    store, store.sym("__typename"), target, True, False
                ),
            )
            var edge = graph.upsert_edge(
                store,
                head,
                tail,
                _create_field_move(
                    store,
                    field.name,
                    definition.name,
                    is_leaf,
                    is_list,
                    join_field,
                    requirement_type,
                    requirements,
                    overridden_by,
                    overridden_label,
                ),
            )
            if provided != NONE:
                provides[edge] = provided
            _ = graph.upsert_edge(
                store, tail, abstract_tail, Edge(EdgeKind.ABSTRACT_MOVE, member)
            )
        return
    var head = _plain(graph, store, state, definition.name, graph_id)
    var tail = _plain(graph, store, state, target, graph_id)
    var edge = graph.upsert_edge(
        store,
        head,
        tail,
        _create_field_move(
            store,
            field.name,
            definition.name,
            is_leaf,
            is_list,
            join_field,
            requirement_type,
            requirements,
            overridden_by,
            overridden_label,
        ),
    )
    if provided != NONE:
        provides[edge] = provided
    var root_kind = state.maybe_root_type(target)
    if root_kind == NONE:
        return
    # The root of `target` exists, and `_link_root_edges` gave it its
    # entrypoints, so this does not raise and the list is not empty.
    var entrypoints = graph.entrypoints(OperationKind(UInt8(root_kind)))
    var at = 0
    while at < len(entrypoints):
        var target_node = graph.edges[entrypoints[at]].tail
        at += 1
        if graph.nodes[target_node].subgraph == subgraph:
            continue
        var reentry = Edge(EdgeKind.REENTRY_MOVE, field.name)
        reentry.type_name = definition.name
        reentry.is_list = is_list
        _ = graph.upsert_edge(store, head, target_node, reentry^)


def _entity_move(
    key: String, type_name: Int, set: Int, is_interface: Bool
) -> Edge:
    """Return an entity move, as upstream `Edge::create_entity_move`."""
    var edge = Edge(EdgeKind.ENTITY_MOVE, NONE)
    edge.key = key
    edge.requirement_type = type_name
    edge.requirements = set
    edge.is_interface = is_interface
    return edge^


def _build_entity_reference_edges(
    mut graph: Graph,
    mut store: Store,
    state: SupergraphState,
    mut field_sets: _FieldSets,
) raises:
    """Add the entity moves by `@key`, and the moves of each
    `@interfaceObject`, as upstream `build_entity_reference_edges`."""
    var index = 0
    while index < len(state.definitions):
        ref definition = state.definitions[index]
        index += 1
        var is_interface = definition.is_interface_type()
        for join_type1 in definition.join_types:
            var head = graph.upsert_node(
                store,
                Node.subgraph_type(
                    definition.name,
                    state.resolve_graph_id(join_type1.graph_id),
                    join_type1.is_interface_object,
                ),
            )
            # `join_type1` itself is in the list.
            var second = 0
            while second < len(definition.join_types):
                ref join_type2 = definition.join_types[second]
                second += 1
                if join_type1.graph_id != join_type2.graph_id:
                    if join_type2.resolvable and join_type2.key:
                        var tail = graph.upsert_node(
                            store,
                            Node.subgraph_type(
                                definition.name,
                                state.resolve_graph_id(join_type2.graph_id),
                                join_type2.is_interface_object,
                            ),
                        )
                        var key = join_type2.key.value()
                        var set = field_sets.parse(
                            store,
                            state,
                            join_type2.graph_id,
                            definition.name,
                            key,
                        )
                        _ = graph.upsert_edge(
                            store,
                            head,
                            tail,
                            _entity_move(
                                key, definition.name, set, is_interface
                            ),
                        )
                elif join_type1.resolvable and join_type1.key:
                    var key = join_type1.key.value()
                    var set = field_sets.parse(
                        store, state, join_type1.graph_id, definition.name, key
                    )
                    _ = graph.upsert_edge(
                        store,
                        head,
                        head,
                        _entity_move(key, definition.name, set, is_interface),
                    )
            if (
                not join_type1.is_interface_object
                or not join_type1.resolvable
                or not join_type1.key
            ):
                continue
            _interface_object_moves(
                graph,
                store,
                state,
                field_sets,
                index - 1,
                join_type1.graph_id,
                join_type1.key.value(),
            )


def _interface_object_moves(
    mut graph: Graph,
    mut store: Store,
    state: SupergraphState,
    mut field_sets: _FieldSets,
    definition_index: Int,
    graph_id: Int,
    key: String,
) raises:
    """Add the type moves and entity moves of an `@interfaceObject`."""
    ref definition = state.definitions[definition_index]
    var name = definition.name
    var tail = graph.upsert_node(
        store, Node.subgraph_type(name, state.resolve_graph_id(graph_id), True)
    )
    var typename_set = field_sets.parse(
        store, state, graph_id, name, "__typename"
    )
    var other = 0
    while other < len(state.definitions):
        ref object = state.definitions[other]
        other += 1
        if object.kind != DefinitionKind.OBJECT:
            continue
        var implements = False
        for join_implements in object.join_implements:
            if join_implements.interface == name:
                implements = True
        if not implements:
            continue
        var type_move = Edge(EdgeKind.INTERFACE_OBJECT_TYPE_MOVE, object.name)
        type_move.requirement_type = name
        type_move.requirements = typename_set
        _ = graph.upsert_edge(store, tail, tail, type_move^)
        var key_set = field_sets.parse(store, state, graph_id, name, key)
        # An object with `@join__implements` has a `@join__type`.
        var at = 0
        while at < len(object.join_types):
            ref join_type2 = object.join_types[at]
            at += 1
            if join_type2.graph_id == graph_id:
                continue
            var head = graph.upsert_node(
                store,
                Node.subgraph_type(
                    object.name,
                    state.resolve_graph_id(join_type2.graph_id),
                    join_type2.is_interface_object,
                ),
            )
            _ = graph.upsert_edge(
                store,
                head,
                tail,
                _entity_move(
                    key, name, key_set, definition.is_interface_type()
                ),
            )


# --- @provides copies ----------------------------------------------------


def _field_definition(
    store: Store, state: SupergraphState, type_name: Int, field_name: Int
) raises -> Tuple[Int, Int]:
    """Return the definition and field indices of a field, or raise."""
    var definition = state.definition(type_name)
    if definition == NONE:
        raise Error(
            "Definition with name '" + store.name(type_name) + "' was not found"
        )
    var field = state.definitions[definition].field_index(field_name)
    if field == NONE:
        raise Error(
            "Field named '"
            + store.name(field_name)
            + "' was not found in definition name '"
            + store.name(type_name)
            + "'"
        )
    return (definition, field)


def _targets(graph: Graph, node: Int, kind: EdgeKind, name: Int) -> List[Int]:
    """Return the tails of the field or abstract moves of one name."""
    var out = List[Int]()
    var edge = graph.first_out[node]
    while edge != NONE:
        ref found = graph.edges[edge]
        if found.kind == kind and found.name == name:
            out.append(found.tail)
        edge = found.next_out
    return out^


def _build_provides_edges(
    mut graph: Graph,
    mut store: Store,
    state: SupergraphState,
    mut pool: ProvidedPool,
    provides: Dict[Int, Int],
) raises:
    """Point each `@provides` field at the copies of its path, as upstream
    `build_provides_edges`."""
    var keys = List[String]()
    var edges = List[Int]()
    var graphs = List[Int]()
    for entry in provides.items():
        var edge = entry.key
        ref found = graph.edges[edge]
        var key = (
            graph.node_name(store, found.head)
            + " "
            + store.name(found.name)
            + " "
            + graph.node_name(store, found.tail)
        )
        # Upstream also orders equal keys by edge index. The entries come in
        # edge order, so inserting after an equal key does the same.
        var at = len(keys)
        while at > 0 and key < keys[at - 1]:
            at -= 1
        keys.insert(at, key^)
        edges.insert(at, edge)
        graphs.insert(at, found.join_field.value().graph_id)
    var copies = Dict[String, Int]()
    var redirect_edges = List[Int]()
    var redirect_copies = List[Int]()
    for index in range(len(edges)):
        var edge = edges[index]
        var target = graph.edges[edge].tail
        var copy = _provided_node(
            graph,
            store,
            state,
            pool,
            provides,
            copies,
            target,
            provides[edge],
            graphs[index],
        )
        if copy != target:
            var at = len(redirect_edges)
            while at > 0 and edge > redirect_edges[at - 1]:
                at -= 1
            redirect_edges.insert(at, edge)
            redirect_copies.insert(at, copy)
    for index in range(len(redirect_edges)):
        var head = graph.edges[redirect_edges[index]].head
        var weight = graph.remove_edge(redirect_edges[index])
        _ = graph.add_edge(head, redirect_copies[index], weight^)


def _provided_node(
    mut graph: Graph,
    mut store: Store,
    state: SupergraphState,
    mut pool: ProvidedPool,
    provides: Dict[Int, Int],
    mut copies: Dict[String, Int],
    original: Int,
    var provided: Int,
    graph_id: Int,
) raises -> Int:
    """Return the node for `original` with `provided` on it: `original`
    when that adds nothing, its copy otherwise."""
    provided = _prune_provided(
        graph, store, state, pool, original, provided, graph_id
    )
    if pool.is_empty(provided):
        return original
    var text = pool.text(store, provided)
    var key = String(original) + text
    var found = copies.get(key)
    if found:
        return found.value()
    var copy_node = graph.nodes[original].copy()
    copy_node.provided = text
    var copy = graph.upsert_node(store, copy_node^)
    copies[key^] = copy
    # A node with something to provide is a composite type, which has at
    # least its selfie.
    var out_edges = graph.edges_from(original)
    var next_edge = 0
    while next_edge < len(out_edges):
        var edge_index = out_edges[next_edge]
        next_edge += 1
        var edge = graph.edges[edge_index].copy()
        var target = edge.tail
        if edge.kind == EdgeKind.FIELD_MOVE:
            var below = pool.field_child(provided, edge.name)
            if below == NONE:
                below = 0
            var own = provides.get(edge_index)
            if own:
                below = pool.merge(store, below, own.value())
            target = _provided_node(
                graph,
                store,
                state,
                pool,
                provides,
                copies,
                target,
                below,
                graph_id,
            )
        elif edge.kind == EdgeKind.ABSTRACT_MOVE:
            var below = pool.type_child(provided, edge.name)
            if below == NONE:
                below = 0
            target = _provided_node(
                graph,
                store,
                state,
                pool,
                provides,
                copies,
                target,
                below,
                graph_id,
            )
        elif edge.kind == EdgeKind.SELFIE:
            # A selfie always loops on its node.
            target = copy
        _ = graph.add_edge(copy, target, edge^)
    var type_name = graph.nodes[original].name
    var subgraph = state.resolve_graph_id(graph_id)
    var node = pool.nodes[provided].copy()
    for index in range(len(node.field_names)):
        var field_name = node.field_names[index]
        if len(_targets(graph, original, EdgeKind.FIELD_MOVE, field_name)) > 0:
            continue
        var at = _field_definition(store, state, type_name, field_name)
        ref field = state.definitions[at[0]].fields[at[1]]
        var return_type = field.field_type.inner_type()
        var plain = graph.upsert_node(
            store,
            Node.subgraph_type(
                return_type,
                subgraph,
                state.is_interface_object_in_subgraph(return_type, graph_id),
            ),
        )
        var target = _provided_node(
            graph,
            store,
            state,
            pool,
            provides,
            copies,
            plain,
            node.field_children[index],
            graph_id,
        )
        _ = graph.add_edge(
            copy,
            target,
            _field_move(
                store,
                field_name,
                type_name,
                state.is_scalar_type(return_type),
                field.field_type.is_list(),
            ),
        )
    for index in range(len(node.type_names)):
        var on_type = node.type_names[index]
        if len(_targets(graph, original, EdgeKind.ABSTRACT_MOVE, on_type)) > 0:
            continue
        var plain = graph.upsert_node(
            store,
            Node.subgraph_type(
                on_type,
                subgraph,
                state.is_interface_object_in_subgraph(on_type, graph_id),
            ),
        )
        var target = _provided_node(
            graph,
            store,
            state,
            pool,
            provides,
            copies,
            plain,
            node.type_children[index],
            graph_id,
        )
        _ = graph.add_edge(copy, target, Edge(EdgeKind.ABSTRACT_MOVE, on_type))
    return copy


def _prune_provided(
    graph: Graph,
    store: Store,
    state: SupergraphState,
    mut pool: ProvidedPool,
    node: Int,
    var provided: Int,
    graph_id: Int,
) raises -> Int:
    """Drop what a node has anyway, and fold `... on T` into the fields on
    a `T`, as upstream `prune_provided`."""
    if pool.is_empty(provided):
        return provided
    var type_name = graph.nodes[node].name
    while True:
        var same_type = pool.type_child(provided, type_name)
        if same_type == NONE:
            break
        provided = pool.without_type(provided, type_name)
        provided = pool.merge(store, provided, same_type)
    var pruned = 0
    var tree = pool.nodes[provided].copy()
    for index in range(len(tree.field_names)):
        var field_name = tree.field_names[index]
        var below = tree.field_children[index]
        var targets = _targets(graph, node, EdgeKind.FIELD_MOVE, field_name)
        if len(targets) == 0:
            var plain = NONE
            if not pool.is_empty(below):
                plain = _plain_node_of_field(
                    graph, store, state, node, field_name, graph_id
                )
            if plain != NONE:
                below = _prune_provided(
                    graph, store, state, pool, plain, below, graph_id
                )
            pruned = pool.with_entry(store, pruned, field_name, below, False)
            continue
        var kept = 0
        var at = 0
        while at < len(targets):
            kept = pool.merge(
                store,
                kept,
                _prune_provided(
                    graph, store, state, pool, targets[at], below, graph_id
                ),
            )
            at += 1
        if not pool.is_empty(kept):
            pruned = pool.with_entry(store, pruned, field_name, kept, False)
    for index in range(len(tree.type_names)):
        var on_type = tree.type_names[index]
        var below = tree.type_children[index]
        var members = _targets(graph, node, EdgeKind.ABSTRACT_MOVE, on_type)
        if len(members) == 0:
            if graph.nodes[node].is_union_members():
                continue
            var plain = graph.find_node(
                Node.subgraph_type(
                    on_type,
                    state.resolve_graph_id(graph_id),
                    state.is_interface_object_in_subgraph(on_type, graph_id),
                ).display_name(store)
            )
            if plain != NONE:
                below = _prune_provided(
                    graph, store, state, pool, plain, below, graph_id
                )
            pruned = pool.with_entry(store, pruned, on_type, below, True)
            continue
        var kept = 0
        var at = 0
        while at < len(members):
            kept = pool.merge(
                store,
                kept,
                _prune_provided(
                    graph, store, state, pool, members[at], below, graph_id
                ),
            )
            at += 1
        if not pool.is_empty(kept):
            pruned = pool.with_entry(store, pruned, on_type, kept, True)
    return pruned


def _plain_node_of_field(
    graph: Graph,
    store: Store,
    state: SupergraphState,
    node: Int,
    field_name: Int,
    graph_id: Int,
) raises -> Int:
    """Return the plain node an `@external` field leads to, or `NONE` when
    it is not in the graph."""
    var at = _field_definition(store, state, graph.nodes[node].name, field_name)
    var return_type = (
        state.definitions[at[0]].fields[at[1]].field_type.inner_type()
    )
    return graph.find_node(
        Node.subgraph_type(
            return_type,
            state.resolve_graph_id(graph_id),
            state.is_interface_object_in_subgraph(return_type, graph_id),
        ).display_name(store)
    )

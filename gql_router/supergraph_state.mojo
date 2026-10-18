# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The supergraph, read once for the query planner.

Port of Hive Router `1a29df9`
`bin/router/src/query_planner/state/supergraph_state.rs`.

`new_supergraph_state` reads a supergraph SDL document: every object,
interface, union, enum, scalar and input object, with their join
directives, the subgraphs of `join__Graph`, and the root types. Names are
symbols of the planner `Store`. Definitions keep their source order;
upstream keeps them in a `HashMap`, whose order is random, so no result of
the planner depends on it.

**Differences from upstream.** Upstream also reads `@authenticated`,
`@requiresScopes`, `@policy`, `@cost` and `@listSize` into the state, for
the executor. This port reads only what the query planner uses.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_router.ast import NONE
from gql_router.federation_spec import (
    JoinFieldDirective,
    JoinImplementsDirective,
    JoinTypeDirective,
    JoinUnionMemberDirective,
    OperationKind,
    TypeNode,
    parse_join_enum_value,
    parse_join_field,
    parse_join_graph,
    parse_join_implements,
    parse_join_type,
    parse_join_union_member,
    type_node_from_ast,
)
from gql_router.store import Store


@fieldwise_init
struct DefinitionKind(Equatable, ImplicitlyCopyable, Movable):
    """The kind of a supergraph definition."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime OBJECT = DefinitionKind(0)
    """An object type."""
    comptime INTERFACE = DefinitionKind(1)
    """An interface type."""
    comptime UNION = DefinitionKind(2)
    """A union type."""
    comptime ENUM = DefinitionKind(3)
    """An enum type."""
    comptime SCALAR = DefinitionKind(4)
    """A scalar type."""
    comptime INPUT_OBJECT = DefinitionKind(5)
    """An input object type."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the six kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 5

    def is_composite(self) -> Bool:
        """Return True for an object, an interface or a union.

        Returns:
            Whether the kind is composite.
        """
        return self.value <= 2


@fieldwise_init
struct SupergraphField(Copyable, Movable):
    """One field of an object, an interface or an input object."""

    var name: Int
    """The field name, as a symbol."""
    var field_type: TypeNode
    """The return type."""
    var inaccessible: Bool
    """Whether the field has `@inaccessible`."""
    var join_field: List[JoinFieldDirective]
    """The `@join__field` directives, sorted by graph id."""
    var resolvable_in: List[Int]
    """The subgraphs that resolve the field, as sorted indices into
    `SupergraphState.subgraph_names`."""


@fieldwise_init
struct EnumValue(Copyable, Movable):
    """One enum value and the graphs of its `@join__enumValue`."""

    var name: Int
    """The value, as a symbol."""
    var graphs: List[Int]
    """The graph ids, as symbols, sorted."""


struct SupergraphDefinition(Copyable, Movable):
    """One type of the supergraph, as upstream `SupergraphDefinition`."""

    var kind: DefinitionKind
    """What the type is."""
    var name: Int
    """The type name, as a symbol."""
    var fields: List[SupergraphField]
    """The fields of an object, an interface or an input object."""
    var join_types: List[JoinTypeDirective]
    """The `@join__type` directives, sorted by graph id."""
    var join_implements: List[JoinImplementsDirective]
    """The `@join__implements` directives, sorted by graph id."""
    var root_type: Int
    """The `OperationKind` value of a root type, or `NONE`."""
    var union_types: List[Int]
    """The members of a union, in source order."""
    var union_members: List[JoinUnionMemberDirective]
    """The `@join__unionMember` directives, sorted by graph."""
    var enum_values: List[EnumValue]
    """The values of an enum."""

    def __init__(out self, kind: DefinitionKind, name: Int):
        """Start a definition with no fields and no directives.

        Args:
            kind: The kind.
            name: The type name, as a symbol.
        """
        self.kind = kind
        self.name = name
        self.fields = List[SupergraphField]()
        self.join_types = List[JoinTypeDirective]()
        self.join_implements = List[JoinImplementsDirective]()
        self.root_type = NONE
        self.union_types = List[Int]()
        self.union_members = List[JoinUnionMemberDirective]()
        self.enum_values = List[EnumValue]()

    def is_composite_type(self) -> Bool:
        """Return True for an object, an interface or a union.

        Returns:
            Whether the type is composite.
        """
        return self.kind.is_composite()

    def is_interface_type(self) -> Bool:
        """Return True for an interface.

        Returns:
            Whether the type is an interface.
        """
        return self.kind == DefinitionKind.INTERFACE

    def is_defined_in_subgraph(self, graph_id: Int) -> Bool:
        """Return True if a `@join__type` names a graph.

        Args:
            graph_id: The graph id, as a symbol.

        Returns:
            Whether the type is in that subgraph.
        """
        for join_type in self.join_types:
            if join_type.graph_id == graph_id:
                return True
        return False

    def subgraphs(self, store: Store) -> List[Int]:
        """Return the graph ids of the `@join__type` directives, sorted.

        Args:
            store: The store with the names.

        Returns:
            The graph ids, as symbols, sorted by name.
        """
        # `join_types` is sorted by graph id already.
        var out = List[Int]()
        for join_type in self.join_types:
            out.append(join_type.graph_id)
        return out^

    def field_index(self, name: Int) -> Int:
        """Return the position of a field.

        Args:
            name: The field name, as a symbol.

        Returns:
            Its index in `fields`, or `NONE`.
        """
        for index in range(len(self.fields)):
            if self.fields[index].name == name:
                return index
        return NONE


struct SupergraphState(Movable):
    """The supergraph, as upstream `SupergraphState`."""

    var definitions: List[SupergraphDefinition]
    """Every definition, in source order."""
    var definition_ids: Dict[Int, Int]
    """The index of each definition, by type name symbol."""
    var field_ids: Dict[Int, Int]
    """The index of each field in its definition, by type and field."""
    var known_subgraphs: Dict[Int, Int]
    """The subgraph name of each graph id, as symbols."""
    var graph_ids: Dict[Int, Int]
    """The graph id of each subgraph name, as symbols."""
    var subgraph_names: List[Int]
    """The subgraph names, sorted. A subgraph's index is its position."""
    var subgraph_endpoints: Dict[Int, String]
    """The URL of each subgraph, by name symbol."""
    var known_scalars: List[Int]
    """Every scalar, the built-in ones included."""
    var query_type: Int
    """The query root type."""
    var mutation_type: Int
    """The mutation root type, or `NONE`."""
    var subscription_type: Int
    """The subscription root type, or `NONE`."""
    var interface_object_graphs: Dict[Int, List[Int]]
    """The graph ids that hold each interface as an `@interfaceObject`."""
    var interface_to_object_types: Dict[Int, List[Int]]
    """The object types that implement each interface, sorted by name."""
    var override_flags: List[Int]
    """Every custom `@override` label."""
    var override_percentages: List[UInt64]
    """Every percentage `@override` label."""

    def __init__(out self):
        """Start an empty state."""
        self.definitions = List[SupergraphDefinition]()
        self.definition_ids = Dict[Int, Int]()
        self.field_ids = Dict[Int, Int]()
        self.known_subgraphs = Dict[Int, Int]()
        self.graph_ids = Dict[Int, Int]()
        self.subgraph_names = List[Int]()
        self.subgraph_endpoints = Dict[Int, String]()
        self.known_scalars = List[Int]()
        self.query_type = NONE
        self.mutation_type = NONE
        self.subscription_type = NONE
        self.interface_object_graphs = Dict[Int, List[Int]]()
        self.interface_to_object_types = Dict[Int, List[Int]]()
        self.override_flags = List[Int]()
        self.override_percentages = List[UInt64]()

    def definition(self, name: Int) -> Int:
        """Return the index of a definition.

        Args:
            name: The type name, as a symbol.

        Returns:
            The index in `definitions`, or `NONE`.
        """
        var found = self.definition_ids.get(name)
        if found:
            return found.value()
        return NONE

    def field(self, type_name: Int, field_name: Int) -> Int:
        """Return the index of a field in its definition.

        Args:
            type_name: The type, as a symbol.
            field_name: The field, as a symbol.

        Returns:
            The index in the definition's `fields`, or `NONE`.
        """
        var found = self.field_ids.get(_field_key(type_name, field_name))
        if found:
            return found.value()
        return NONE

    def resolve_graph_id(self, graph_id: Int) raises -> Int:
        """Return the subgraph name of a graph id.

        Args:
            graph_id: The `join__Graph` value, as a symbol.

        Returns:
            The subgraph name, as a symbol.

        Raises:
            Error: When the graph id is not known.
        """
        var found = self.known_subgraphs.get(graph_id)
        if found:
            return found.value()
        raise Error("Subgraph not found")

    def subgraph_index(self, subgraph_name: Int) -> Int:
        """Return a subgraph's position in `subgraph_names`.

        Args:
            subgraph_name: The subgraph name, as a symbol.

        Returns:
            The index, or `NONE`.
        """
        for index in range(len(self.subgraph_names)):
            if self.subgraph_names[index] == subgraph_name:
                return index
        return NONE

    def maybe_root_type(self, type_name: Int) -> Int:
        """Return the operation kind of a root type.

        Args:
            type_name: The type, as a symbol.

        Returns:
            The `OperationKind` value, or `NONE` for another type.
        """
        if type_name == self.query_type:
            return Int(OperationKind.QUERY.value)
        if type_name != NONE and type_name == self.mutation_type:
            return Int(OperationKind.MUTATION.value)
        if type_name != NONE and type_name == self.subscription_type:
            return Int(OperationKind.SUBSCRIPTION.value)
        return NONE

    def root_type_name(self, kind: OperationKind) raises -> Int:
        """Return the root type of an operation kind.

        Args:
            kind: The operation kind.

        Returns:
            The root type, as a symbol.

        Raises:
            Error: When the supergraph has no such root type.
        """
        if kind == OperationKind.MUTATION:
            if self.mutation_type == NONE:
                raise Error(
                    "Root type not found for operation kind: 'mutation'"
                )
            return self.mutation_type
        if kind == OperationKind.SUBSCRIPTION:
            if self.subscription_type == NONE:
                raise Error(
                    "Root type not found for operation kind: 'subscription'"
                )
            return self.subscription_type
        return self.query_type

    def is_scalar_type(self, type_name: Int) -> Bool:
        """Return True if a type is a scalar, built-in or custom.

        Args:
            type_name: The type, as a symbol.

        Returns:
            Whether it is a scalar.
        """
        for scalar in self.known_scalars:
            if scalar == type_name:
                return True
        return False

    def is_interface_object_in_subgraph(
        self, type_name: Int, graph_id: Int
    ) -> Bool:
        """Return True if a type is an `@interfaceObject` in a subgraph.

        Args:
            type_name: The interface, as a symbol.
            graph_id: The graph id, as a symbol.

        Returns:
            Whether the subgraph holds the interface as an object.
        """
        var found = self.interface_object_graphs.get(type_name)
        if not found:
            return False
        # A known interface has at least one graph.
        ref graphs = found.value()
        var index = 0
        while index < len(graphs):
            if graphs[index] == graph_id:
                return True
            index += 1
        return False

    def interface_members(self, interface_name: Int) -> List[Int]:
        """Return the object types that implement an interface.

        Args:
            interface_name: The interface, as a symbol.

        Returns:
            The object types, sorted by name; empty when there are none.
        """
        var found = self.interface_to_object_types.get(interface_name)
        if found:
            return found.value().copy()
        return List[Int]()

    def has_interface_members(self, interface_name: Int) -> Bool:
        """Return True if the interface has an entry of implementations.

        Args:
            interface_name: The interface, as a symbol.

        Returns:
            Whether `interface_to_object_types` knows the interface.
        """
        return interface_name in self.interface_to_object_types

    def field_return_type_name(
        self, store: Store, type_name: Int, field_name: Int
    ) -> Int:
        """Return the named return type of a field, as upstream
        `field_return_type_name`.

        Args:
            store: The store with the names.
            type_name: The type, as a symbol.
            field_name: The field, as a symbol.

        Returns:
            The return type, as a symbol; `String` for `__typename`;
            `NONE` when the field is unknown.
        """
        if store.name(field_name) == "__typename":
            return store.find_sym("String")
        var definition = self.definition(type_name)
        if definition == NONE:
            return NONE
        var field = self.field(type_name, field_name)
        if field == NONE:
            return NONE
        return self.definitions[definition].fields[field].field_type.name

    def subgraph_exists_by_name(self, store: Store, name: StringSlice) -> Bool:
        """Return True if a subgraph has a name.

        Args:
            store: The store with the names.
            name: The subgraph name.

        Returns:
            Whether a subgraph has that name.
        """
        var symbol = store.find_sym(name)
        return symbol != NONE and symbol in self.subgraph_endpoints


def _field_key(type_name: Int, field_name: Int) -> Int:
    """Pack a type and a field symbol into one key."""
    return (type_name << 32) | field_name


def _directives(document: Document, node: Int, name: StringSlice) -> List[Int]:
    """Return the directives of a node with a name, in source order."""
    var out = List[Int]()
    var directive = document.child(node, Role.DIRECTIVE)
    while directive != NO_NODE:
        if document.name(directive) == name:
            out.append(directive)
        directive = document.next_with_role(directive)
    return out^


def _join_types(
    mut store: Store, document: Document, node: Int
) -> List[JoinTypeDirective]:
    """Read the `@join__type` directives of a node, sorted by graph id."""
    var out = List[JoinTypeDirective]()
    for directive in _directives(document, node, "join__type"):
        var parsed = parse_join_type(store, document, directive)
        var at = len(out)
        while at > 0 and store.less(parsed.graph_id, out[at - 1].graph_id):
            at -= 1
        out.insert(at, parsed^)
    return out^


def _join_fields(
    mut store: Store, document: Document, node: Int
) raises -> List[JoinFieldDirective]:
    """Read the `@join__field` directives of a node, sorted by graph id.

    A directive without a graph sorts first, as `None` does upstream.
    """
    var out = List[JoinFieldDirective]()
    for directive in _directives(document, node, "join__field"):
        var parsed = parse_join_field(store, document, directive)
        var at = len(out)
        while at > 0 and _graph_less(
            store, parsed.graph_id, out[at - 1].graph_id
        ):
            at -= 1
        out.insert(at, parsed^)
    return out^


def _graph_less(store: Store, a: Int, b: Int) -> Bool:
    """Order optional graph ids: none first, then by name."""
    if a == NONE:
        return b != NONE
    if b == NONE:
        return False
    return store.less(a, b)


def _fields(
    mut store: Store, document: Document, node: Int
) raises -> List[SupergraphField]:
    """Read the fields of an object, an interface or an input object."""
    var out = List[SupergraphField]()
    var field = document.child(node, Role.FIELD)
    while field != NO_NODE:
        var name = store.sym(document.name(field))
        var field_type = type_node_from_ast(
            store, document, document.child(field, Role.TYPE)
        )
        out.append(
            SupergraphField(
                name,
                field_type^,
                len(_directives(document, field, "inaccessible")) > 0,
                _join_fields(store, document, field),
                List[Int](),
            )
        )
        field = document.next_with_role(field)
    return out^


def _definition_kind(kind: Kind) -> Int:
    """Return the `DefinitionKind` value of a type definition node kind."""
    if kind == Kind.OBJECT_TYPE_DEFINITION:
        return Int(DefinitionKind.OBJECT.value)
    if kind == Kind.INTERFACE_TYPE_DEFINITION:
        return Int(DefinitionKind.INTERFACE.value)
    if kind == Kind.UNION_TYPE_DEFINITION:
        return Int(DefinitionKind.UNION.value)
    if kind == Kind.ENUM_TYPE_DEFINITION:
        return Int(DefinitionKind.ENUM.value)
    if kind == Kind.SCALAR_TYPE_DEFINITION:
        return Int(DefinitionKind.SCALAR.value)
    if kind == Kind.INPUT_OBJECT_TYPE_DEFINITION:
        return Int(DefinitionKind.INPUT_OBJECT.value)
    return NONE


def _root_types(mut store: Store, document: Document) -> Tuple[Int, Int, Int]:
    """Return the query, mutation and subscription types of a document.

    The schema definition names them. Without one, they are the object
    types named `Query`, `Mutation` and `Subscription`.
    """
    var query = NONE
    var mutation = NONE
    var subscription = NONE
    var found_schema = False
    for definition in document.definitions():
        if document.kind(definition) != Kind.SCHEMA_DEFINITION:
            continue
        found_schema = True
        var operation = document.child(definition, Role.OPERATION_TYPE)
        while operation != NO_NODE:
            var type_name = store.sym(
                document.named_type(document.child(operation, Role.TYPE))
            )
            var kind = document.operation(operation)
            if kind.value == 0:
                query = type_name
            elif kind.value == 1:
                mutation = type_name
            else:
                subscription = type_name
            operation = document.next_with_role(operation)
        break
    if found_schema:
        if query == NONE:
            query = store.sym("Query")
        return (query, mutation, subscription)
    query = store.sym("Query")
    for definition in document.definitions():
        if document.kind(definition) != Kind.OBJECT_TYPE_DEFINITION:
            continue
        var name = document.name(definition)
        if name == "Mutation":
            mutation = store.sym(name)
        elif name == "Subscription":
            subscription = store.sym(name)
    return (query, mutation, subscription)


def new_supergraph_state(
    mut store: Store, document: Document
) raises -> SupergraphState:
    """Read a supergraph SDL document, as upstream `SupergraphState::new`.

    Args:
        store: The store for the names.
        document: The parsed supergraph SDL.

    Returns:
        The state.

    Raises:
        Error: When a join directive has a bad argument.
    """
    var state = SupergraphState()
    var roots = _root_types(store, document)
    state.query_type = roots[0]
    state.mutation_type = roots[1]
    state.subscription_type = roots[2]
    _read_subgraphs(store, document, state)
    _read_definitions(store, document, state)
    _fill_resolvable_in(store, state)
    _index_interfaces(store, state)
    _read_overrides(state)
    return state^


def _read_subgraphs(
    mut store: Store, document: Document, mut state: SupergraphState
):
    """Read the subgraphs of `join__Graph`, and sort their names."""
    for definition in document.definitions():
        if (
            document.kind(definition) != Kind.ENUM_TYPE_DEFINITION
            or String(document.name(definition)) != "join__Graph"
        ):
            continue
        var value = document.child(definition, Role.ENUM_VALUE)
        while value != NO_NODE:
            var graph_id = store.sym(document.name(value))
            # Upstream sorts the directives by name and takes the first.
            var best = Tuple[String, String]("", "")
            var has_best = False
            for directive in _directives(document, value, "join__graph"):
                var parsed = parse_join_graph(document, directive)
                if not has_best or parsed[0] < best[0]:
                    best = parsed^
                    has_best = True
            if has_best:
                var name = store.sym(best[0])
                state.known_subgraphs[graph_id] = name
                state.graph_ids[name] = graph_id
                state.subgraph_endpoints[name] = best[1]
                var at = len(state.subgraph_names)
                var seen = False
                for known in state.subgraph_names:
                    if known == name:
                        seen = True
                if not seen:
                    while at > 0 and store.less(
                        name, state.subgraph_names[at - 1]
                    ):
                        at -= 1
                    state.subgraph_names.insert(at, name)
            value = document.next_with_role(value)
        break


def _read_definitions(
    mut store: Store, document: Document, mut state: SupergraphState
) raises:
    """Read every type definition, and the known scalars."""
    for definition in document.definitions():
        var kind_value = _definition_kind(document.kind(definition))
        if kind_value == NONE:
            continue
        var kind = DefinitionKind(UInt8(kind_value))
        var name = store.sym(document.name(definition))
        var parsed = SupergraphDefinition(kind, name)
        parsed.join_types = _join_types(store, document, definition)
        if (
            kind == DefinitionKind.OBJECT
            or kind == DefinitionKind.INTERFACE
            or kind == DefinitionKind.INPUT_OBJECT
        ):
            parsed.fields = _fields(store, document, definition)
        if kind == DefinitionKind.OBJECT or kind == DefinitionKind.INTERFACE:
            for directive in _directives(
                document, definition, "join__implements"
            ):
                var implements = parse_join_implements(
                    store, document, directive
                )
                var at = len(parsed.join_implements)
                while at > 0 and store.less(
                    implements.graph_id,
                    parsed.join_implements[at - 1].graph_id,
                ):
                    at -= 1
                parsed.join_implements.insert(at, implements^)
        if kind == DefinitionKind.OBJECT:
            parsed.root_type = state.maybe_root_type(name)
        if kind == DefinitionKind.UNION:
            var member = document.child(definition, Role.MEMBER_TYPE)
            while member != NO_NODE:
                parsed.union_types.append(store.sym(document.name(member)))
                member = document.next_with_role(member)
            for directive in _directives(
                document, definition, "join__unionMember"
            ):
                var union_member = parse_join_union_member(
                    store, document, directive
                )
                var at = len(parsed.union_members)
                while at > 0 and store.less(
                    union_member.graph, parsed.union_members[at - 1].graph
                ):
                    at -= 1
                parsed.union_members.insert(at, union_member^)
        if kind == DefinitionKind.ENUM:
            var value = document.child(definition, Role.ENUM_VALUE)
            while value != NO_NODE:
                var graphs = List[Int]()
                for directive in _directives(
                    document, value, "join__enumValue"
                ):
                    var graph = parse_join_enum_value(
                        store, document, directive
                    )
                    var at = len(graphs)
                    while at > 0 and store.less(graph, graphs[at - 1]):
                        at -= 1
                    graphs.insert(at, graph)
                parsed.enum_values.append(
                    EnumValue(store.sym(document.name(value)), graphs^)
                )
                value = document.next_with_role(value)
        if kind == DefinitionKind.SCALAR:
            state.known_scalars.append(name)
        var existing = state.definition(name)
        var index = len(state.definitions)
        if existing != NONE:
            index = existing
            state.definitions[index] = parsed^
        else:
            state.definitions.append(parsed^)
            state.definition_ids[name] = index
        ref stored = state.definitions[index]
        # Upstream `fields()` is empty for an input object.
        if stored.kind == DefinitionKind.INPUT_OBJECT:
            continue
        for field_index in range(len(stored.fields)):
            state.field_ids[
                _field_key(name, stored.fields[field_index].name)
            ] = field_index
    var builtins: List[StaticString] = [
        "String",
        "Int",
        "Float",
        "Boolean",
        "ID",
    ]
    var at = 0
    while at < len(builtins):
        var symbol = store.sym(builtins[at])
        at += 1
        if not state.is_scalar_type(symbol):
            state.known_scalars.append(symbol)


def _fill_resolvable_in(store: Store, mut state: SupergraphState):
    """Work out which subgraphs resolve each field, as upstream
    `fill_resolvable_in`."""
    for index in range(len(state.definitions)):
        var kind = state.definitions[index].kind
        if kind != DefinitionKind.OBJECT and kind != DefinitionKind.INTERFACE:
            continue
        for field_index in range(len(state.definitions[index].fields)):
            var indices = List[Int]()
            ref field = state.definitions[index].fields[field_index]
            if len(field.join_field) == 0:
                for join_type in state.definitions[index].join_types:
                    _add_subgraph_index(state, indices, join_type.graph_id)
            else:
                var at = 0
                while at < len(field.join_field):
                    ref join_field = field.join_field[at]
                    at += 1
                    if (
                        join_field.external
                        or join_field.used_overridden
                        or join_field.override_label
                        or join_field.graph_id == NONE
                    ):
                        continue
                    _add_subgraph_index(state, indices, join_field.graph_id)
            sort(indices)
            state.definitions[index].fields[field_index].resolvable_in = (
                indices^
            )


def _add_subgraph_index(
    state: SupergraphState, mut indices: List[Int], graph_id: Int
):
    """Add the subgraph index of a graph id to a list, once."""
    var name = state.known_subgraphs.get(graph_id)
    if not name:
        return
    # Every known subgraph name is in `subgraph_names`.
    var index = state.subgraph_index(name.value())
    for known in indices:
        if known == index:
            return
    indices.append(index)


def _index_interfaces(store: Store, mut state: SupergraphState) raises:
    """Build the `@interfaceObject` and implementation maps."""
    for index in range(len(state.definitions)):
        ref definition = state.definitions[index]
        if definition.kind == DefinitionKind.INTERFACE:
            for join_type in definition.join_types:
                if not join_type.is_interface_object:
                    continue
                if definition.name not in state.interface_object_graphs:
                    state.interface_object_graphs[definition.name] = List[Int]()
                state.interface_object_graphs[definition.name].append(
                    join_type.graph_id
                )
        if definition.kind != DefinitionKind.OBJECT:
            continue
        for implements in definition.join_implements:
            if implements.interface not in state.interface_to_object_types:
                state.interface_to_object_types[implements.interface] = List[
                    Int
                ]()
            ref members = state.interface_to_object_types[implements.interface]
            var seen = False
            for member in members:
                if member == definition.name:
                    seen = True
            if seen:
                continue
            var at = len(members)
            while at > 0 and store.less(definition.name, members[at - 1]):
                at -= 1
            members.insert(at, definition.name)


def _read_overrides(mut state: SupergraphState):
    """Collect every progressive `@override` label."""
    for definition in state.definitions:
        for field in definition.fields:
            for join_field in field.join_field:
                if not join_field.override_label:
                    continue
                var label = join_field.override_label.value().copy()
                if label.is_percent:
                    if label.percent not in state.override_percentages:
                        state.override_percentages.append(label.percent)
                elif label.custom not in state.override_flags:
                    state.override_flags.append(label.custom)

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""One subgraph, cut out of the supergraph.

Port of Hive Router `1a29df9`
`bin/router/src/query_planner/state/subgraph_state.rs`.

`decompose_from_supergraph` keeps the types that a `@join__type` puts in
the subgraph, and the fields that have no `@join__field` or one for the
subgraph. Input objects are left out, as upstream.
"""

from gql_router.ast import NONE
from gql_router.federation_spec import (
    JoinFieldDirective,
    JoinTypeDirective,
    TypeNode,
)
from gql_router.store import Store
from gql_router.supergraph_state import (
    DefinitionKind,
    SupergraphDefinition,
    SupergraphState,
)


@fieldwise_init
struct SubgraphField(Copyable, Movable):
    """One field of a subgraph type, as upstream `SubgraphField`."""

    var name: Int
    """The field name, as a symbol."""
    var field_type: TypeNode
    """The supergraph return type."""
    var is_list: Bool
    """Whether the return type is a list."""
    var join_field: Optional[JoinFieldDirective]
    """The `@join__field` of this subgraph, if any."""


struct SubgraphDefinition(Copyable, Movable):
    """One type of a subgraph, as upstream `SubgraphDefinition`."""

    var kind: DefinitionKind
    """What the type is."""
    var name: Int
    """The type name, as a symbol."""
    var fields: List[SubgraphField]
    """The fields of an object or an interface."""
    var join_types: List[JoinTypeDirective]
    """The `@join__type` directives of this subgraph."""
    var types: List[Int]
    """The union members, or the enum values, of this subgraph."""

    def __init__(out self, kind: DefinitionKind, name: Int):
        """Start a definition.

        Args:
            kind: The kind.
            name: The type name, as a symbol.
        """
        self.kind = kind
        self.name = name
        self.fields = List[SubgraphField]()
        self.join_types = List[JoinTypeDirective]()
        self.types = List[Int]()

    def is_object_type(self) -> Bool:
        """Return True for an object type.

        Returns:
            Whether the type is an object.
        """
        return self.kind == DefinitionKind.OBJECT

    def is_interface_type(self) -> Bool:
        """Return True for an interface type.

        Returns:
            Whether the type is an interface.
        """
        return self.kind == DefinitionKind.INTERFACE

    def is_entity_type(self) -> Bool:
        """Return True for an object with a resolvable `@key`.

        Returns:
            Whether the type is an entity in this subgraph.
        """
        if self.kind != DefinitionKind.OBJECT:
            return False
        # A subgraph type has at least one `@join__type` of its graph.
        var index = 0
        while index < len(self.join_types):
            ref join_type = self.join_types[index]
            if join_type.resolvable and join_type.key:
                return True
            index += 1
        return False

    def field(self, name: Int) -> Int:
        """Return the position of a field.

        Args:
            name: The field name, as a symbol.

        Returns:
            The index in `fields`, or `NONE`.
        """
        var index = 0
        while index < len(self.fields):
            if self.fields[index].name == name:
                return index
            index += 1
        return NONE


struct SubgraphState(Movable):
    """One subgraph, as upstream `SubgraphState`."""

    var graph_id: Int
    """The `join__Graph` value, as a symbol."""
    var definitions: List[SubgraphDefinition]
    """The types of the subgraph."""
    var definition_ids: Dict[Int, Int]
    """The index of each definition, by type name symbol."""
    var entity_type_names: List[Int]
    """The entity types of the subgraph."""

    def __init__(out self, graph_id: Int):
        """Start an empty subgraph.

        Args:
            graph_id: The graph id, as a symbol.
        """
        self.graph_id = graph_id
        self.definitions = List[SubgraphDefinition]()
        self.definition_ids = Dict[Int, Int]()
        self.entity_type_names = List[Int]()

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


def decompose_from_supergraph(
    supergraph: SupergraphState, graph_id: Int
) -> SubgraphState:
    """Cut one subgraph out of the supergraph.

    Args:
        supergraph: The supergraph.
        graph_id: The subgraph's graph id, as a symbol.

    Returns:
        The subgraph's types and fields.
    """
    var state = SubgraphState(graph_id)
    var next = 0
    while next < len(supergraph.definitions):
        ref definition = supergraph.definitions[next]
        next += 1
        var relevant = List[JoinTypeDirective]()
        for join_type in definition.join_types:
            if join_type.graph_id == graph_id:
                relevant.append(join_type.copy())
        if len(relevant) == 0:
            continue
        var kind = definition.kind
        var out = SubgraphDefinition(kind, definition.name)
        out.join_types = relevant^
        if kind == DefinitionKind.OBJECT or kind == DefinitionKind.INTERFACE:
            # An object or an interface has at least one field.
            var field_index = 0
            while field_index < len(definition.fields):
                ref field = definition.fields[field_index]
                field_index += 1
                var own = Optional[JoinFieldDirective](None)
                for join_field in field.join_field:
                    if join_field.graph_id == graph_id:
                        own = join_field.copy()
                        break
                if len(field.join_field) == 0 or own:
                    out.fields.append(
                        SubgraphField(
                            field.name,
                            field.field_type.copy(),
                            field.field_type.is_list(),
                            own^,
                        )
                    )
            if len(out.fields) == 0:
                continue
        elif kind == DefinitionKind.ENUM:
            # An enum has at least one value.
            var value_index = 0
            while value_index < len(definition.enum_values):
                ref value = definition.enum_values[value_index]
                value_index += 1
                var graph_index = 0
                while graph_index < len(value.graphs):
                    if value.graphs[graph_index] == graph_id:
                        out.types.append(value.name)
                        break
                    graph_index += 1
            if len(out.types) == 0:
                continue
        elif kind == DefinitionKind.UNION:
            # A union has at least one member.
            var member_index = 0
            while member_index < len(definition.union_members):
                ref member = definition.union_members[member_index]
                member_index += 1
                if member.graph == graph_id and member.member not in out.types:
                    out.types.append(member.member)
            if len(out.types) == 0:
                continue
        elif kind == DefinitionKind.INPUT_OBJECT:
            continue
        if out.is_entity_type():
            state.entity_type_names.append(definition.name)
        state.definition_ids[definition.name] = len(state.definitions)
        state.definitions.append(out^)
    return state^


def decompose_all(supergraph: SupergraphState) -> List[SubgraphState]:
    """Cut every subgraph out of the supergraph.

    Args:
        supergraph: The supergraph.

    Returns:
        One state per subgraph, in the order of `subgraph_names`.
    """
    var out = List[SubgraphState]()
    var index = 0
    while index < len(supergraph.subgraph_names):
        var graph_id = supergraph.graph_ids.get(
            supergraph.subgraph_names[index]
        )
        out.append(decompose_from_supergraph(supergraph, graph_id.value()))
        index += 1
    return out^

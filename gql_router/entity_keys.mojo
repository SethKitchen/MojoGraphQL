# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The resolvable `@key`s of each subgraph, by entity type.

Port of `EntityKeys`, `KeysByType`, `TypeKeys` and `KeyFields` of Hive
Router `1a29df9` `bin/router/src/query_planner/state/entity_keys.rs`.

A key is the list of its top-level fields, without `__typename`: `id` and
`org` for `@key(fields: "id org { id }")`. A key of `__typename` alone has
no fields. The executor reads the keys when it writes an entity
representation: an entity without one complete key is left out.

**Differences from upstream.** Upstream fills the keys while it builds the
supergraph state. This port builds them from the state afterwards, with
`EntityKeys.new`, because the state does not keep them.
"""

from gql_router.ast import ItemKind, NONE
from gql_router.normalize import normalize_field_set
from gql_router.store import Store
from gql_router.supergraph_state import SupergraphState


struct KeysByType(Copyable, Movable):
    """The keys of each entity type in one subgraph, as upstream
    `KeysByType`."""

    var types: List[String]
    """The entity types, in first-seen order."""
    var keys: List[List[List[String]]]
    """The keys of each type, parallel to `types`; each key is its list of
    field names."""

    def __init__(out self):
        """Start with no types."""
        self.types = List[String]()
        self.keys = List[List[List[String]]]()

    def index_of(self, type_name: StringSlice) -> Int:
        """Return the position of a type, with no copy of the name.

        Args:
            type_name: The entity type.

        Returns:
            The index in `keys`, or -1 when the type is not an entity of
            the subgraph.
        """
        var index = 0
        while index < len(self.types):
            if self.types[index] == type_name:
                return index
            index += 1
        return -1

    def get(self, type_name: String) -> Optional[List[List[String]]]:
        """Return the keys of a type.

        Args:
            type_name: The entity type.

        Returns:
            The keys, or None when the type is not an entity of the
            subgraph.
        """
        var index = self.index_of(type_name)
        if index < 0:
            return None
        return self.keys[index].copy()

    def add(mut self, type_name: String, var fields: List[String]):
        """Add one key of a type.

        Args:
            type_name: The entity type.
            fields: The top-level fields of the key.
        """
        var index = self.index_of(type_name)
        if index < 0:
            self.types.append(type_name)
            self.keys.append(List[List[String]]())
            index = len(self.types) - 1
        self.keys[index].append(fields^)


struct EntityKeys(Copyable, Movable):
    """The resolvable keys of every subgraph, as upstream `EntityKeys`."""

    var names: List[String]
    """The subgraphs that have entities, after an empty name at index 0."""
    var subgraphs: List[KeysByType]
    """The keys of each subgraph, parallel to `names`; index 0 holds no
    keys, for a subgraph without entities."""

    def __init__(out self):
        """Start with no subgraphs, as upstream `EntityKeys::default`."""
        self.names = [""]
        self.subgraphs = List[KeysByType]()
        self.subgraphs.append(KeysByType())

    def index_of(self, subgraph: StringSlice) -> Int:
        """Return the position of a subgraph.

        Args:
            subgraph: The subgraph name.

        Returns:
            The index in `subgraphs`, or 0, the entry with no keys, when
            the subgraph has no entity.
        """
        var index = 1
        while index < len(self.names):
            if self.names[index] == subgraph:
                return index
            index += 1
        return 0

    @staticmethod
    def new(mut store: Store, state: SupergraphState) raises -> EntityKeys:
        """Read the resolvable keys of a supergraph, as upstream
        `EntityKeys::new`.

        Args:
            store: The planner store; the key selections are added to it.
            state: The supergraph state.

        Returns:
            The keys.

        Raises:
            Error: When a key field set does not normalize, or a type
                names a graph that the supergraph does not have.
        """
        var out = EntityKeys()
        var position = 0
        while position < len(state.definitions):
            ref definition = state.definitions[position]
            position += 1
            var type_name = String(store.name(definition.name))
            for join_type in definition.join_types:
                if not join_type.resolvable or not join_type.key:
                    continue
                var subgraph = state.resolve_graph_id(join_type.graph_id)
                var set = normalize_field_set(
                    store,
                    state,
                    definition.name,
                    join_type.graph_id,
                    join_type.key.value(),
                )
                var fields = key_fields_of(store, set)
                var name = String(store.name(subgraph))
                var index = out.index_of(name)
                if index == 0:
                    out.names.append(name)
                    out.subgraphs.append(KeysByType())
                    index = len(out.names) - 1
                out.subgraphs[index].add(type_name, fields^)
        return out^

    def of_subgraph(self, subgraph: String) -> Optional[KeysByType]:
        """Return the keys of one subgraph, as upstream `of_subgraph`.

        Args:
            subgraph: The subgraph name.

        Returns:
            Its keys by type, or None when it has no entity.
        """
        var index = self.index_of(subgraph)
        if index == 0:
            return None
        return self.subgraphs[index].copy()


def key_fields_of(store: Store, set: Int) -> List[String]:
    """Return the top-level field names of a key field set.

    `__typename` and inline fragments are not key fields.

    Args:
        store: The store with the selection set.
        set: The normalized key field set.

    Returns:
        The field names, in order.
    """
    var fields = List[String]()
    var child = store.items[set].first
    while child != NONE:
        ref item = store.items[child]
        if item.kind == ItemKind.FIELD and store.name(item.name) != "__typename":
            fields.append(String(store.name(item.name)))
        child = item.next
    return fields^

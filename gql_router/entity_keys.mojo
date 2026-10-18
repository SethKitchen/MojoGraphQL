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

    var keys: Dict[String, List[List[String]]]
    """The keys of each type; each key is its list of field names."""

    def __init__(out self):
        """Start with no types."""
        self.keys = Dict[String, List[List[String]]]()

    def get(self, type_name: String) -> Optional[List[List[String]]]:
        """Return the keys of a type.

        Args:
            type_name: The entity type.

        Returns:
            The keys, or None when the type is not an entity of the
            subgraph.
        """
        return self.keys.get(type_name)

    def add(mut self, type_name: String, var fields: List[String]):
        """Add one key of a type.

        Args:
            type_name: The entity type.
            fields: The top-level fields of the key.
        """
        var found = self.keys.get(type_name)
        var list = List[List[String]]()
        if found:
            list = found.value().copy()
        list.append(fields^)
        self.keys[type_name] = list^


struct EntityKeys(Copyable, Movable):
    """The resolvable keys of every subgraph, as upstream `EntityKeys`."""

    var subgraphs: Dict[String, KeysByType]
    """The keys of each subgraph, by subgraph name."""

    def __init__(out self):
        """Start with no subgraphs, as upstream `EntityKeys::default`."""
        self.subgraphs = Dict[String, KeysByType]()

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
            Error: When a key field set does not normalize.
        """
        var out = EntityKeys()
        for definition in state.definitions:
            var type_name = String(store.name(definition.name))
            for join_type in definition.join_types:
                if not join_type.resolvable or not join_type.key:
                    continue
                var subgraph = state.known_subgraphs.get(join_type.graph_id)
                if not subgraph:
                    continue
                var set = normalize_field_set(
                    store,
                    state,
                    definition.name,
                    join_type.graph_id,
                    join_type.key.value(),
                )
                var fields = List[String]()
                var child = store.items[set].first
                while child != NONE:
                    var item = store.items[child]
                    if (
                        item.kind == ItemKind.FIELD
                        and store.name(item.name) != "__typename"
                    ):
                        fields.append(String(store.name(item.name)))
                    child = item.next
                var name = String(store.name(subgraph.value()))
                var keys = out.subgraphs.get(name)
                var by_type = KeysByType()
                if keys:
                    by_type = keys.value().copy()
                by_type.add(type_name, fields^)
                out.subgraphs[name] = by_type^
        return out^

    def of_subgraph(self, subgraph: String) -> Optional[KeysByType]:
        """Return the keys of one subgraph, as upstream `of_subgraph`.

        Args:
            subgraph: The subgraph name.

        Returns:
            Its keys by type, or None when it has no entity.
        """
        return self.subgraphs.get(subgraph)

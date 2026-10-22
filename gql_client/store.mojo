# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The entity store: the normalized objects of the cache, by id, and its
optimistic layers.

Port of the data and layer parts of Apollo Client 4.3.3
`src/cache/inmemory/entityStore.ts`: `EntityStore`, its `Root` subclass,
and `Layer`. An entity is a `StoreObject`: a list of `Member`s, each a
store field name and a value of the `Values` arena.

The store keeps its entities in a list, by the interned entity id, so a
`Reference` finds its entity without a hash lookup.

The parts of `EntityStore` that need the policies, such as `modify`,
`evict` and `toReference`, are in `gql_client.cache`.

Differences from upstream:

- There is no result cache, so there are no dependencies to dirty.
- A member in `Root` never holds `undefined`: a merge that gives
  `undefined` removes the member. In an optimistic `Layer`, a deleted
  field is kept with `NO_VALUE` so that it shadows the parent layer.
"""
from std.collections import Dict

from gql_client.values import Member, NO_VALUE, Values


struct Entry(Copyable, Movable):
    """One entity of the store or of a layer."""

    var present: Bool
    """Whether the entity exists."""
    var deleted: Bool
    """In an optimistic layer: whether the entity was evicted (`false` in
    upstream `Layer`)."""
    var seq: Int
    """When the entity was added: the order of `extract`."""
    var members: List[Member]
    """The fields, in the order they were added."""

    def __init__(out self):
        """Make an absent entry."""
        self.present = False
        self.deleted = False
        self.seq = 0
        self.members = List[Member]()


def member_index(members: List[Member], name: Int) -> Int:
    """Return the position of a store field name in an entity.

    Args:
        members: The entity's members.
        name: The interned store field name.

    Returns:
        The position, or -1.
    """
    var data = members.unsafe_ptr()
    var count = len(members)
    var index = 0
    while index < count:
        if Int(data[unsafe_offset=index].name) == name:
            return index
        index += 1
    return -1


def member_value(members: List[Member], name: Int) -> Int:
    """Return the value of a store field name in an entity.

    Args:
        members: The entity's members.
        name: The interned store field name.

    Returns:
        The value, or `NO_VALUE`.
    """
    var index = member_index(members, name)
    if index < 0:
        return NO_VALUE
    return Int(members[index].value)


def merge_members(
    mut values: Values, mut existing: List[Member], incoming: List[Member]
) -> Bool:
    """Merge incoming fields into a root entity, as `EntityStore.merge`
    does.

    Each incoming field replaces the existing field, unless the two values
    are deeply equal (`storeObjectReconciler`). A new field goes at the end.
    A field whose new value is `undefined` is removed.

    Args:
        values: The arena.
        existing: The entity's members; they change in place.
        incoming: The incoming members.

    Returns:
        Whether a member changed.
    """
    var changed = False
    var index = 0
    while index < len(incoming):
        var name = Int(incoming[index].name)
        var value = Int(incoming[index].value)
        var position = member_index(existing, name)
        if position < 0:
            # A field that is not there is never deleted: a deletion comes
            # only from `modify`, for a field that the entity has.
            existing.append(incoming[index])
            changed = True
        elif value == NO_VALUE:
            _ = existing.pop(position)
            changed = True
        elif not values.equal(Int(existing[position].value), value):
            existing[position].value = Int32(value)
            changed = True
        index += 1
    return changed


struct Layer(Copyable, Movable):
    """One optimistic layer on top of the store: upstream `EntityStore.Layer`.
    """

    var id: String
    """The transaction id of the layer."""
    var entries: List[Entry]
    """The entities modified or deleted in this layer, by interned id."""
    var order: List[Int]
    """The ids added in this layer, in order."""
    var order_seq: List[Int]
    """The `seq` of each id in `order`."""
    var next_seq: Int
    """The `seq` of the next added entity in this layer."""
    var root_ids: Dict[String, Int]
    """The retain counts added in this layer."""

    def __init__(out self, id: String):
        """Make an empty layer.

        Args:
            id: The transaction id.
        """
        self.id = id
        self.entries = List[Entry]()
        self.order = List[Int]()
        self.order_seq = List[Int]()
        self.next_seq = 0
        self.root_ids = Dict[String, Int]()

    def ensure(mut self, id: Int):
        """Make room in the layer for an id.

        Args:
            id: The interned id.
        """
        while len(self.entries) <= id:
            self.entries.append(Entry())


struct EntityStore(Movable):
    """The root store of the entities, and any active optimistic layers."""

    var entries: List[Entry]
    """The root entities, by interned id."""
    var order: List[Int]
    """The ids in the order they were added, with `order_seq`."""
    var order_seq: List[Int]
    """The `seq` that each id of `order` had when it was added."""
    var next_seq: Int
    """The `seq` of the next added entity."""
    var root_ids: Dict[String, Int]
    """The retain counts of the root, as `EntityStore.rootIds`."""
    var layers: List[Layer]
    """The optimistic layers, from oldest to top (`optimisticData`)."""
    var write_to_root: Bool
    """When True, writes and mutations bypass `layers` and go to the root."""
    var _in_optimistic: Int
    """How many nested optimistic transactions are running now."""

    def __init__(out self):
        """Make an empty store."""
        self.entries = List[Entry]()
        self.order = List[Int]()
        self.order_seq = List[Int]()
        self.next_seq = 0
        self.root_ids = Dict[String, Int]()
        self.layers = List[Layer]()
        self.write_to_root = False
        self._in_optimistic = 0

    def use_layers(self, optimistic: Bool = True) -> Bool:
        """Return True when an operation should read or write the
        optimistic layers.

        Args:
            optimistic: Whether optimistic data is requested.

        Returns:
            True when `optimistic` is True, `write_to_root` is False, and
            at least one layer exists.
        """
        return optimistic and not self.write_to_root and len(self.layers) > 0

    @always_inline
    def present(self, id: Int, optimistic: Bool = True) -> Bool:
        """Return True when the store has an entity.

        Args:
            id: The interned id.
            optimistic: Whether to check the optimistic layers first.

        Returns:
            Whether the store has the entity.
        """
        if self.use_layers(optimistic):
            var depth = len(self.layers) - 1
            while depth >= 0:
                ref layer = self.layers[depth]
                if id < len(layer.entries):
                    ref entry = layer.entries[id]
                    if entry.deleted:
                        return False
                    if entry.present:
                        return True
                depth -= 1
        return (
            id < len(self.entries)
            and self.entries.unsafe_ptr()[unsafe_offset=id].present
        )

    def get_field(self, id: Int, name: Int, optimistic: Bool = True) -> Int:
        """Return a field of an entity across the layers and the root.

        Args:
            id: The interned entity id.
            name: The interned store field name.
            optimistic: Whether to read from the optimistic layers first.

        Returns:
            The value, or `NO_VALUE`.
        """
        if self.use_layers(optimistic):
            var depth = len(self.layers) - 1
            while depth >= 0:
                ref layer = self.layers[depth]
                if id < len(layer.entries):
                    ref entry = layer.entries[id]
                    if entry.deleted:
                        return NO_VALUE
                    if entry.present:
                        var pos = member_index(entry.members, name)
                        if pos >= 0:
                            return Int(entry.members[pos].value)
                depth -= 1
        if id < len(self.entries) and self.entries[id].present:
            return member_value(self.entries[id].members, name)
        return NO_VALUE

    def members_of(self, id: Int, optimistic: Bool = True) -> List[Member]:
        """Return the effective members of an entity across the layers and
        the root, in field order, without deleted (`NO_VALUE`) fields.

        Args:
            id: The interned entity id.
            optimistic: Whether to include the optimistic layers.

        Returns:
            The effective members.
        """
        if not self.use_layers(optimistic):
            if id < len(self.entries) and self.entries[id].present:
                return self.entries[id].members.copy()
            return List[Member]()
        var stop = -1
        var depth = len(self.layers) - 1
        while depth >= 0:
            ref layer = self.layers[depth]
            if id < len(layer.entries) and layer.entries[id].deleted:
                stop = depth
                break
            depth -= 1
        var out = List[Member]()
        if stop < 0 and id < len(self.entries) and self.entries[id].present:
            out = self.entries[id].members.copy()
        var start_layer = 0 if stop < 0 else stop + 1
        var idx = start_layer
        while idx < len(self.layers):
            ref layer = self.layers[idx]
            if id < len(layer.entries) and layer.entries[id].present:
                for ref m in layer.entries[id].members:
                    var name = Int(m.name)
                    var val = Int(m.value)
                    var pos = member_index(out, name)
                    if val == NO_VALUE:
                        if pos >= 0:
                            _ = out.pop(pos)
                    elif pos < 0:
                        out.append(m)
                    else:
                        out[pos].value = m.value
            idx += 1
        return out^

    def ensure(mut self, id: Int):
        """Make room in the root for an id.

        Args:
            id: The interned id.
        """
        while len(self.entries) <= id:
            self.entries.append(Entry())

    def add(mut self, id: Int, var members: List[Member]):
        """Set the members of an entity in the active store or layer, and
        add it if it is new.

        Args:
            id: The interned id.
            members: The new members.
        """
        if self.use_layers():
            ref top = self.layers[len(self.layers) - 1]
            top.ensure(id)
            ref entry = top.entries[id]
            entry.deleted = False
            if not entry.present:
                entry.present = True
                entry.seq = top.next_seq
                top.order.append(id)
                top.order_seq.append(top.next_seq)
                top.next_seq += 1
            entry.members = members^
            return
        self.ensure(id)
        ref entry = self.entries[id]
        if not entry.present:
            entry.present = True
            entry.seq = self.next_seq
            self.order.append(id)
            self.order_seq.append(self.next_seq)
            self.next_seq += 1
        entry.members = members^

    def merge_into(
        mut self, mut values: Values, id: Int, var incoming: List[Member]
    ):
        """Merge incoming members into the active store or top layer.

        Args:
            values: The arena.
            id: The interned id.
            incoming: The incoming fields.
        """
        if self.use_layers():
            ref top = self.layers[len(self.layers) - 1]
            top.ensure(id)
            ref entry = top.entries[id]
            entry.deleted = False
            if not entry.present:
                entry.present = True
                entry.seq = top.next_seq
                top.order.append(id)
                top.order_seq.append(top.next_seq)
                top.next_seq += 1
            var index = 0
            while index < len(incoming):
                var name = Int(incoming[index].name)
                var value = Int(incoming[index].value)
                var pos = member_index(entry.members, name)
                if pos < 0:
                    entry.members.append(incoming[index])
                else:
                    entry.members[pos].value = Int32(value)
                index += 1
            return
        if self.present(id, False):
            _ = merge_members(values, self.entries[id].members, incoming)
            return
        self.add(id, incoming^)

    def remove(mut self, id: Int):
        """Remove an entity from the active store or mark it deleted in
        the top optimistic layer.

        Args:
            id: The interned id of an entity that the store has.
        """
        if self.use_layers():
            ref top = self.layers[len(self.layers) - 1]
            top.ensure(id)
            top.entries[id].present = False
            top.entries[id].deleted = True
            top.entries[id].members = List[Member]()
            return
        self.entries[id].present = False
        self.entries[id].members = List[Member]()

    def ids_in_order(mut self, optimistic: Bool = True) -> List[Int]:
        """Return the ids of the entities in the order they were added.

        Args:
            optimistic: Whether to include the optimistic layers.

        Returns:
            The ids, as `Object.keys(data)` gives them before ECMAScript
            moves the keys that are array indices.
        """
        var out = List[Int]()
        var keep_ids = List[Int]()
        var keep_seq = List[Int]()
        var index = 0
        while index < len(self.order):
            var id = self.order[index]
            ref entry = self.entries[id]
            if entry.present and entry.seq == self.order_seq[index]:
                keep_ids.append(id)
                keep_seq.append(self.order_seq[index])
                if not self.use_layers(optimistic) or self.present(id, True):
                    out.append(id)
            index += 1
        self.order = keep_ids^
        self.order_seq = keep_seq^
        if self.use_layers(optimistic):
            var seen = Dict[Int, Bool]()
            for id in out:
                seen[id] = True
            var depth = 0
            while depth < len(self.layers):
                ref layer = self.layers[depth]
                var i = 0
                while i < len(layer.order):
                    var id = layer.order[i]
                    if (
                        id not in seen
                        and self.present(id, True)
                        and len(self.members_of(id, True)) > 0
                    ):
                        seen[id] = True
                        out.append(id)
                    i += 1
                depth += 1
        return out^

    def retain(mut self, root_id: String) -> Int:
        """Count one more hold on a root id, as `EntityStore.retain`.

        Args:
            root_id: The id.

        Returns:
            The total count across the root and any active layers.
        """
        if self.use_layers():
            ref top = self.layers[len(self.layers) - 1]
            top.root_ids[root_id] = top.root_ids.get(root_id, 0) + 1
            return self.retain_count(root_id, True)
        var count = self.root_ids.get(root_id, 0) + 1
        self.root_ids[root_id] = count
        return count

    def release(mut self, root_id: String) -> Int:
        """Count one less hold on a root id, as `EntityStore.release`.

        Args:
            root_id: The id.

        Returns:
            The new count; 0 when the id had no hold.
        """
        if self.use_layers():
            var depth = len(self.layers) - 1
            while depth >= 0:
                var c = self.layers[depth].root_ids.get(root_id, 0)
                if c > 0:
                    c -= 1
                    if c == 0:
                        _ = self.layers[depth].root_ids.pop(root_id, 0)
                    else:
                        self.layers[depth].root_ids[root_id] = c
                    return self.retain_count(root_id, True)
                depth -= 1
        var count = self.root_ids.get(root_id, 0)
        if count <= 0:
            return 0
        count -= 1
        if count == 0:
            _ = self.root_ids.pop(root_id, 0)
        else:
            self.root_ids[root_id] = count
        return self.retain_count(root_id, self.use_layers())

    def retain_count(self, root_id: String, optimistic: Bool = True) -> Int:
        """Return the retain count of a root id.

        Args:
            root_id: The id.
            optimistic: Whether to sum across the optimistic layers.

        Returns:
            The hold count.
        """
        var total = self.root_ids.get(root_id, 0)
        if self.use_layers(optimistic):
            for ref layer in self.layers:
                total += layer.root_ids.get(root_id, 0)
        return total

    def retained_root_ids(self, optimistic: Bool = True) -> List[String]:
        """Return the retained root ids in insertion order.

        Args:
            optimistic: Whether to include the optimistic layers.

        Returns:
            The retained ids with count > 0.
        """
        var out = List[String]()
        var seen = Dict[String, Bool]()
        for entry in self.root_ids.items():
            if entry.value > 0:
                seen[entry.key] = True
                out.append(entry.key)
        if self.use_layers(optimistic):
            for ref layer in self.layers:
                for entry in layer.root_ids.items():
                    if entry.value > 0 and entry.key not in seen:
                        seen[entry.key] = True
                        out.append(entry.key)
        return out^

    def push_layer(mut self, id: String):
        """Push a new optimistic layer with `id`.

        Args:
            id: The transaction id.
        """
        self.layers.append(Layer(id))

    def remove_layer(mut self, id: String) -> Bool:
        """Remove an optimistic layer by id, as `removeLayer`.

        Args:
            id: The transaction id to remove.

        Returns:
            Whether a layer with `id` was found and removed.
        """
        var index = 0
        while index < len(self.layers):
            if self.layers[index].id == id:
                _ = self.layers.pop(index)
                return True
            index += 1
        return False

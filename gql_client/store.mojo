# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The entity store: the normalized objects of the cache, by id.

Port of the data part of Apollo Client 4.3.3
`src/cache/inmemory/entityStore.ts`: `EntityStore` and its `Root`
subclass. An entity is a `StoreObject`: a list of `Member`s, each a store
field name and a value of the `Values` arena.

The store keeps its entities in a list, by the interned entity id, so a
`Reference` finds its entity without a hash lookup.

The parts of `EntityStore` that need the policies, such as `modify`,
`evict` and `toReference`, are in `gql_client.cache`.

Differences from upstream:

- There is no result cache, so there are no dependencies to dirty.
- The optimistic layers (`Layer` and `Stump`) are not ported.
- A member never holds `undefined`: a merge that gives `undefined` removes
  the member.
"""
from std.collections import Dict

from gql_client.values import Member, NO_VALUE, Values


struct Entry(Copyable, Movable):
    """One entity of the store."""

    var present: Bool
    """Whether the entity exists."""
    var seq: Int
    """When the entity was added: the order of `extract`."""
    var members: List[Member]
    """The fields, in the order they were added."""

    def __init__(out self):
        """Make an absent entry."""
        self.present = False
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
    """Merge incoming fields into an entity, as `EntityStore.merge` does.

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


struct EntityStore(Movable):
    """The root store of the entities."""

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

    def __init__(out self):
        """Make an empty store."""
        self.entries = List[Entry]()
        self.order = List[Int]()
        self.order_seq = List[Int]()
        self.next_seq = 0
        self.root_ids = Dict[String, Int]()

    @always_inline
    def present(self, id: Int) -> Bool:
        """Return True when the root has an entity.

        Args:
            id: The interned id.

        Returns:
            Whether the root store has it.
        """
        return (
            id < len(self.entries)
            and self.entries.unsafe_ptr()[unsafe_offset=id].present
        )

    def ensure(mut self, id: Int):
        """Make room in the root for an id.

        Args:
            id: The interned id.
        """
        while len(self.entries) <= id:
            self.entries.append(Entry())

    def add(mut self, id: Int, var members: List[Member]):
        """Set the members of a root entity, and add it if it is new.

        Args:
            id: The interned id.
            members: The new members.
        """
        self.ensure(id)
        ref entry = self.entries[id]
        if not entry.present:
            entry.present = True
            entry.seq = self.next_seq
            self.order.append(id)
            self.order_seq.append(self.next_seq)
            self.next_seq += 1
        entry.members = members^

    def remove(mut self, id: Int):
        """Remove a root entity.

        Args:
            id: The interned id of an entity that the root has.
        """
        self.entries[id].present = False
        self.entries[id].members = List[Member]()

    def ids_in_order(mut self) -> List[Int]:
        """Return the ids of the root entities in the order they were added.

        The order list drops the ids that are stale.

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
                out.append(id)
                keep_ids.append(id)
                keep_seq.append(self.order_seq[index])
            index += 1
        self.order = keep_ids^
        self.order_seq = keep_seq^
        return out^

    def retain(mut self, root_id: String) -> Int:
        """Count one more hold on a root id, as `EntityStore.retain`.

        Args:
            root_id: The id.

        Returns:
            The new count.
        """
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
        var count = self.root_ids.get(root_id, 0)
        if count <= 0:
            return 0
        count -= 1
        if count == 0:
            _ = self.root_ids.pop(root_id, 0)
        else:
            self.root_ids[root_id] = count
        return count

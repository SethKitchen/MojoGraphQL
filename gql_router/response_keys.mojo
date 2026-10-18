# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Response keys for the fields the planner adds on its own.

Port of Hive Router `1a29df9`
`bin/router/src/query_planner/planner/fetch/response_keys.rs`.

A key belongs to a place in the response, not to a fetch or a fragment.
A place is the response keys from the root, without lists, type
conditions or conditions. A planner field gets its key once, for the
whole operation, from everything the client and other planner fields use
at that place. The client's fields keep their keys.

A place is a list of key symbols. A signature is a field name and its
interned argument map, so two equal signatures have equal ids.
"""

from gql_router.ast import NONE, ItemKind
from gql_router.merge_path import MergePath, SegmentKind
from gql_router.store import Store


@fieldwise_init
struct Signature(Equatable, ImplicitlyCopyable, Movable):
    """A field name and its arguments, as upstream `Signature`."""

    var name: Int
    """The field name, as a symbol."""
    var args: Int
    """The interned argument map, or `NONE`."""


@fieldwise_init
struct _Place(Copyable, Movable):
    """The keys at one place, as upstream `Place`."""

    var occupant_keys: List[Int]
    """Each key something writes here, as a symbol."""
    var occupants: List[List[Signature]]
    """Who writes each key in `occupant_keys`."""
    var picked_signatures: List[Signature]
    """The planner fields that got a key so far."""
    var picked_keys: List[Int]
    """The key each of `picked_signatures` got."""

    def occupant_index(self, key: Int) -> Int:
        """Return the position of a key in `occupant_keys`."""
        for index in range(len(self.occupant_keys)):
            if self.occupant_keys[index] == key:
                return index
        return NONE

    def occupy(mut self, key: Int, signature: Signature):
        """Record one more writer of a key."""
        var index = self.occupant_index(key)
        if index == NONE:
            self.occupant_keys.append(key)
            self.occupants.append([signature])
        else:
            self.occupants[index].append(signature)


def _place_text(place: List[Int]) -> String:
    """Return the map key of a place."""
    var out = String()
    for key in place:
        out += String(key)
        out += ","
    return out^


struct ResponseKeys(Copyable, Movable):
    """The keys of the planner's own fields, as upstream `ResponseKeys`."""

    var place_ids: Dict[String, Int]
    """The index in `places` of each place, by its text."""
    var places: List[_Place]
    """Every place seen so far."""

    def __init__(out self):
        """Start with no place."""
        self.place_ids = Dict[String, Int]()
        self.places = List[_Place]()

    @staticmethod
    def from_operation(store: Store, selection_set: Int) -> ResponseKeys:
        """Return the keys the client's operation uses.

        Args:
            store: The store with the selections.
            selection_set: The root selection set of the operation.

        Returns:
            The response keys.
        """
        var keys = ResponseKeys()
        var place = List[Int]()
        keys._take_client_keys(store, place, selection_set)
        return keys^

    def _place(mut self, place: List[Int]) -> Int:
        """Return the index of a place, adding it when new."""
        var text = _place_text(place)
        var found = self.place_ids.get(text)
        if found:
            return found.value()
        self.places.append(
            _Place(
                List[Int](),
                List[List[Signature]](),
                List[Signature](),
                List[Int](),
            )
        )
        var index = len(self.places) - 1
        self.place_ids[text^] = index
        return index

    def _take_client_keys(
        mut self, store: Store, mut place: List[Int], selection_set: Int
    ):
        """Record each client field at its place, recursively."""
        var child = store.items[selection_set].first
        while child != NONE:
            var item = store.items[child]
            if item.kind == ItemKind.FIELD:
                var key = store.response_key(child)
                var index = self._place(place)
                self.places[index].occupy(key, Signature(item.name, item.args))
                place.append(key)
                self._take_client_keys(store, place, child)
                _ = place.pop()
            elif item.kind == ItemKind.FRAGMENT:
                self._take_client_keys(store, place, child)
            child = item.next

    def wire_key(
        mut self, mut store: Store, place: List[Int], field: Int
    ) -> Int:
        """Return the key a field goes under at a place, as upstream
        `wire_key`.

        Args:
            store: The store with the selections.
            place: The place, as key symbols.
            field: The field item.

        Returns:
            The field's own name, unless something else writes that key
            there; then the first `_internal_qp_alias_N` nobody uses there.
        """
        return self.wire_key_of(
            store, place, store.items[field].name, store.items[field].args
        )

    def wire_key_of(
        mut self, mut store: Store, place: List[Int], name: Int, args: Int
    ) -> Int:
        """Return the key of a field given by name and arguments, as
        upstream `wire_key` of a field with no selections.

        Args:
            store: The store with the names.
            place: The place, as key symbols.
            name: The field name, as a symbol.
            args: The interned argument map, or `NONE`.

        Returns:
            The key, as a symbol.
        """
        if store.name(name) == "__typename":
            return name
        var signature = Signature(name, args)
        var index = self._place(place)
        ref found = self.places[index]
        for at in range(len(found.picked_signatures)):
            if found.picked_signatures[at] == signature:
                return found.picked_keys[at]
        var name_is_free = True
        var occupant = found.occupant_index(name)
        if occupant != NONE:
            # An occupant has at least one writer.
            ref writers = found.occupants[occupant]
            var writer = 0
            while writer < len(writers):
                if writers[writer] != signature:
                    name_is_free = False
                    break
                writer += 1
        var key = name
        if not name_is_free:
            var counter = 0
            while True:
                var alias = store.sym("_internal_qp_alias_" + String(counter))
                if self.places[index].occupant_index(alias) == NONE:
                    key = alias
                    break
                counter += 1
        self.places[index].occupy(key, signature)
        self.places[index].picked_signatures.append(signature)
        self.places[index].picked_keys.append(key)
        return key

    def output(
        mut self, mut store: Store, place: List[Int], selection_set: Int
    ) -> Int:
        """Return a set the way a fetch writes it at a place:
        `_internal_qp_alias_0: price`, as upstream `output`.

        Args:
            store: The store with the selections.
            place: The place, as key symbols.
            selection_set: The set.

        Returns:
            A new `ROOT` set.
        """
        return self._map(store, place, selection_set, False)

    def input(
        mut self, mut store: Store, place: List[Int], selection_set: Int
    ) -> Int:
        """Return a set the way a representation reads it at a place:
        `price: _internal_qp_alias_0`, as upstream `input`.

        Args:
            store: The store with the selections.
            place: The place, as key symbols.
            selection_set: The set.

        Returns:
            A new `ROOT` set.
        """
        return self._map(store, place, selection_set, True)

    def _map(
        mut self,
        mut store: Store,
        place: List[Int],
        selection_set: Int,
        is_input: Bool,
    ) -> Int:
        """Copy a set with each field under its key, as upstream `map`."""
        var out = store.new_set()
        for child in store.children(selection_set):
            var item = store.items[child]
            if item.kind == ItemKind.FIELD:
                var key = self.wire_key(store, place, child)
                var nested = place.copy()
                nested.append(key)
                var mapped = self._map(store, nested, child, is_input)
                var copy = store.add_item(
                    item.kind,
                    item.name,
                    item.alias,
                    item.args,
                    item.skip,
                    item.include,
                    item.omit,
                )
                store.items[copy].directives = item.directives
                store.set_children(copy, store.children(mapped))
                if key != item.name:
                    if is_input:
                        store.items[copy].alias = item.name
                        store.items[copy].name = key
                    else:
                        store.items[copy].alias = key
                store.append(out, copy)
            elif item.kind == ItemKind.FRAGMENT:
                var mapped = self._map(store, place, child, is_input)
                var copy = store.add_item(
                    item.kind,
                    item.name,
                    item.alias,
                    item.args,
                    item.skip,
                    item.include,
                    item.omit,
                )
                store.items[copy].directives = item.directives
                store.set_children(copy, store.children(mapped))
                store.append(out, copy)
            else:
                store.append(out, store.copy_item(child))
        return out


def place_of(path: MergePath) -> List[Int]:
    """Return the place a path points at: its response keys, as upstream
    `place_of`.

    Args:
        path: The response path.

    Returns:
        The response key of each field segment, as symbols.
    """
    var out = List[Int]()
    for segment in path.segments:
        if segment.kind == SegmentKind.FIELD:
            out.append(segment.response_key())
    return out^

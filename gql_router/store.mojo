# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The store that holds every symbol, value, argument map and selection.

See `gql_router.ast` for the model. The store is the arena of the query
planner: the supergraph state, the graph and every plan keep their
selections here, by index.
"""

from gql_router.ast import (
    NONE,
    Args,
    Directive,
    Item,
    ItemKind,
    Value,
    ValueKind,
    _rust_float_text,
    write_graphql_string,
)


struct Store(Movable):
    """Symbols, values, argument maps and selection items."""

    var names: List[String]
    """The text of each symbol."""
    var name_ids: Dict[String, Int]
    """The symbol of each text."""
    var values: List[Value]
    """Every argument value."""
    var args: List[Args]
    """Every interned argument map."""
    var args_ids: Dict[String, Int]
    """The id of each argument map, by its canonical key."""
    var items: List[Item]
    """Every selection item."""
    var type_sets: List[List[Int]]
    """Every interned set of type names, each sorted by name."""
    var type_set_ids: Dict[String, Int]
    """The id of each type set, by its names joined with `|`."""
    var directives: List[Directive]
    """Every interned directive."""
    var directive_ids: Dict[String, Int]
    """The id of each directive, by its text."""
    var directive_lists: List[List[Int]]
    """Every interned directive list, in source order."""
    var directive_list_ids: Dict[String, Int]
    """The id of each directive list, by its directive ids."""

    def __init__(out self):
        """Start an empty store."""
        self.names = List[String]()
        self.name_ids = Dict[String, Int]()
        self.values = List[Value]()
        self.args = List[Args]()
        self.args_ids = Dict[String, Int]()
        self.items = List[Item]()
        self.type_sets = List[List[Int]]()
        self.type_set_ids = Dict[String, Int]()
        self.directives = List[Directive]()
        self.directive_ids = Dict[String, Int]()
        self.directive_lists = List[List[Int]]()
        self.directive_list_ids = Dict[String, Int]()

    # --- directives -----------------------------------------------------

    def directive(mut self, name: Int, args: Int) -> Int:
        """Intern one directive.

        Args:
            name: The directive name, as a symbol.
            args: The interned argument map, or `NONE`.

        Returns:
            The directive's id. Two directives with the same name and the
            same arguments have the same id.
        """
        var key = String(name) + ":" + String(args)
        var found = self.directive_ids.get(key)
        if found:
            return found.value()
        var if_variable = NONE
        var if_boolean = NONE
        var value = self.arg_value(args, self.sym("if"))
        if value != NONE:
            var kind = self.values[value].kind
            if kind == ValueKind.VARIABLE:
                if_variable = self.values[value].text
            elif kind == ValueKind.BOOLEAN:
                if_boolean = Int(self.values[value].number)
        var id = len(self.directives)
        self.directives.append(Directive(name, args, if_variable, if_boolean))
        self.directive_ids[key^] = id
        return id

    def directive_list(mut self, ids: List[Int]) -> Int:
        """Intern a list of directives, in order.

        Args:
            ids: The directive ids.

        Returns:
            The list's id, or `NONE` for an empty list.
        """
        if len(ids) == 0:
            return NONE
        var key = String()
        var index = 0
        while index < len(ids):
            key += String(ids[index])
            key += ","
            index += 1
        var found = self.directive_list_ids.get(key)
        if found:
            return found.value()
        var id = len(self.directive_lists)
        self.directive_lists.append(ids.copy())
        self.directive_list_ids[key^] = id
        return id

    def directive_items(self, list: Int) -> List[Int]:
        """Return the directives of an interned list.

        Args:
            list: The list's id, or `NONE`.

        Returns:
            The directive ids, in order; empty for `NONE`.
        """
        if list == NONE:
            return List[Int]()
        return self.directive_lists[list].copy()

    # --- type sets ------------------------------------------------------

    def type_set(mut self, types: List[Int]) -> Int:
        """Intern a set of type names, as upstream `BTreeSet<String>`.

        Args:
            types: The type names, as symbols, in any order.

        Returns:
            The set's id.
        """
        var sorted = List[Int]()
        for name in types:
            var seen = False
            for known in sorted:
                if known == name:
                    seen = True
                    break
            if seen:
                continue
            var at = len(sorted)
            while at > 0 and self.less(name, sorted[at - 1]):
                at -= 1
            sorted.insert(at, name)
        var key = String()
        for index in range(len(sorted)):
            if index > 0:
                key += "|"
            key += self.names[sorted[index]]
        var found = self.type_set_ids.get(key)
        if found:
            return found.value()
        var id = len(self.type_sets)
        self.type_sets.append(sorted^)
        self.type_set_ids[key^] = id
        return id

    def single_type_set(mut self, name: Int) -> Int:
        """Intern the set that holds one type name.

        Args:
            name: The type name, as a symbol.

        Returns:
            The set's id.
        """
        return self.type_set([name])

    # --- symbols --------------------------------------------------------

    def sym(mut self, text: StringSlice) -> Int:
        """Return the symbol of a text, adding it when it is new.

        Args:
            text: The text.

        Returns:
            Its symbol.
        """
        var key = String(text)
        var found = self.name_ids.get(key)
        if found:
            return found.value()
        var id = len(self.names)
        self.names.append(key)
        self.name_ids[key^] = id
        return id

    def find_sym(self, text: StringSlice) -> Int:
        """Return the symbol of a text, or `NONE` when it is not known.

        Args:
            text: The text.

        Returns:
            Its symbol, or `NONE`.
        """
        var found = self.name_ids.get(String(text))
        if found:
            return found.value()
        return NONE

    def name(ref self, id: Int) -> ref[self.names[0]] String:
        """Return the text of a symbol.

        Args:
            id: The symbol.

        Returns:
            Its text.
        """
        return self.names[id]

    def less(self, a: Int, b: Int) -> Bool:
        """Return True if the text of one symbol sorts before another.

        Args:
            a: A symbol.
            b: Another symbol.

        Returns:
            Whether `a`'s text is less than `b`'s, byte by byte.
        """
        return self.names[a] < self.names[b]

    # --- values ---------------------------------------------------------

    def add_value(mut self, kind: ValueKind) -> Int:
        """Add an empty value of a kind.

        Args:
            kind: The kind.

        Returns:
            The value's index.
        """
        self.values.append(Value(kind, 0, 0.0, NONE, NONE, NONE, NONE))
        return len(self.values) - 1

    def value_text(self, id: Int) -> String:
        """Return a value as upstream `Value` `Display`.

        Args:
            id: The value.

        Returns:
            Such as `$id`, `"x"`, `[1, 2]` or `{a: 1}`.
        """
        var out = String()
        self.write_value(out, id, False)
        return out^

    def write_value(self, mut out: String, id: Int, tag_floats: Bool):
        """Write a value as upstream `Display`.

        Args:
            out: The destination.
            id: The value.
            tag_floats: Mark floats, so that `1.0` and `1` differ.
        """
        var value = self.values[id]
        var kind = value.kind
        if kind == ValueKind.VARIABLE:
            out += "$"
            out += self.names[value.text]
        elif kind == ValueKind.INT:
            out += String(value.number)
        elif kind == ValueKind.FLOAT:
            out += _rust_float_text(value.real)
            if tag_floats:
                out += "f"
        elif kind == ValueKind.STRING:
            write_graphql_string(out, self.names[value.text])
        elif kind == ValueKind.BOOLEAN:
            out += "true" if value.number != 0 else "false"
        elif kind == ValueKind.NULL:
            out += "null"
        elif kind == ValueKind.ENUM:
            out += self.names[value.text]
        elif kind == ValueKind.LIST:
            out += "["
            var member = value.first
            while member != NONE:
                if member != value.first:
                    out += ", "
                self.write_value(out, member, tag_floats)
                member = self.values[member].next
            out += "]"
        else:
            out += "{"
            var members = self.object_members(id)
            for index in range(len(members)):
                if index > 0:
                    out += ", "
                out += self.names[self.values[members[index]].key]
                out += ": "
                self.write_value(out, members[index], tag_floats)
            out += "}"

    def object_members(self, id: Int) -> List[Int]:
        """Return the members of an object value, sorted by field name.

        A later member with the same name replaces an earlier one, as a
        `BTreeMap` insert does.

        Args:
            id: The object value.

        Returns:
            The member values.
        """
        var out = List[Int]()
        var member = self.values[id].first
        while member != NONE:
            var key = self.values[member].key
            var replaced = False
            for index in range(len(out)):
                if self.values[out[index]].key == key:
                    out[index] = member
                    replaced = True
                    break
            if not replaced:
                var at = len(out)
                while at > 0 and self.less(key, self.values[out[at - 1]].key):
                    at -= 1
                out.insert(at, member)
            member = self.values[member].next
        return out^

    def collect_variables(self, id: Int, mut out: List[Int]):
        """Add the variables a value uses to a list, once each.

        Args:
            id: The value.
            out: The variables found so far, as symbols.
        """
        var value = self.values[id]
        if value.kind == ValueKind.VARIABLE:
            for known in out:
                if known == value.text:
                    return
            out.append(value.text)
            return
        var member = value.first
        while member != NONE:
            self.collect_variables(member, out)
            member = self.values[member].next

    # --- argument maps --------------------------------------------------

    def intern_args(mut self, names: List[Int], values: List[Int]) -> Int:
        """Intern an argument map. A later name replaces an earlier one.

        Args:
            names: The argument names, as symbols, in any order.
            values: The value of each name.

        Returns:
            The map's id, or `NONE` when there are no arguments.
        """
        if len(names) == 0:
            return NONE
        var sorted_names = List[Int]()
        var sorted_values = List[Int]()
        var next = 0
        while next < len(names):
            var index = next
            next += 1
            var name = names[index]
            var replaced = False
            for at in range(len(sorted_names)):
                if sorted_names[at] == name:
                    sorted_values[at] = values[index]
                    replaced = True
                    break
            if replaced:
                continue
            var at = len(sorted_names)
            while at > 0 and self.less(name, sorted_names[at - 1]):
                at -= 1
            sorted_names.insert(at, name)
            sorted_values.insert(at, values[index])
        var text = String()
        var key = String()
        var variables = List[Int]()
        var index = 0
        while index < len(sorted_names):
            if index > 0:
                text += ", "
                key += ", "
            text += self.names[sorted_names[index]]
            text += ": "
            self.write_value(text, sorted_values[index], False)
            key += self.names[sorted_names[index]]
            key += ": "
            self.write_value(key, sorted_values[index], True)
            self.collect_variables(sorted_values[index], variables)
            index += 1
        var found = self.args_ids.get(key)
        if found:
            return found.value()
        # Variables in name order, as a `BTreeSet<String>`.
        var ordered = List[Int]()
        for variable in variables:
            var at = len(ordered)
            while at > 0 and self.less(variable, ordered[at - 1]):
                at -= 1
            ordered.insert(at, variable)
        var id = len(self.args)
        self.args.append(Args(sorted_names^, sorted_values^, text^, ordered^))
        self.args_ids[key^] = id
        return id

    def arg_value(self, args: Int, name: Int) -> Int:
        """Return the value of one argument of a map.

        Args:
            args: The map, or `NONE`.
            name: The argument name, as a symbol.

        Returns:
            The value, or `NONE` when the map has no such argument.
        """
        if args == NONE:
            return NONE
        ref entry = self.args[args]
        var index = 0
        while index < len(entry.names):
            if entry.names[index] == name:
                return entry.values[index]
            index += 1
        return NONE

    # --- items ----------------------------------------------------------

    def add_item(
        mut self,
        kind: ItemKind,
        name: Int = NONE,
        alias: Int = NONE,
        args: Int = NONE,
        skip: Int = NONE,
        include: Int = NONE,
        omit: Bool = False,
    ) -> Int:
        """Add an item with no children and no parent.

        Args:
            kind: The item kind.
            name: The field name, type condition or spread name.
            alias: The field alias.
            args: The argument map.
            skip: The `@skip(if:)` variable.
            include: The `@include(if:)` variable.
            omit: Upstream `omit_from_response`.

        Returns:
            The item's index.
        """
        self.items.append(
            Item(
                kind,
                omit,
                name,
                alias,
                args,
                skip,
                include,
                NONE,
                NONE,
                NONE,
                NONE,
            )
        )
        return len(self.items) - 1

    def new_set(mut self) -> Int:
        """Add an empty selection set that no item owns.

        Returns:
            The set's index.
        """
        return self.add_item(ItemKind.ROOT)

    def append(mut self, parent: Int, child: Int):
        """Make an item the last child of a set.

        Args:
            parent: The set.
            child: An item with no parent.
        """
        var last = self.items[parent].last
        if last == NONE:
            self.items[parent].first = child
        else:
            self.items[last].next = child
        self.items[parent].last = child

    def prepend(mut self, parent: Int, child: Int):
        """Make an item the first child of a set.

        Args:
            parent: The set.
            child: An item with no parent.
        """
        self.items[child].next = self.items[parent].first
        self.items[parent].first = child
        if self.items[parent].last == NONE:
            self.items[parent].last = child

    def clear(mut self, parent: Int):
        """Drop every child of a set.

        Args:
            parent: The set.
        """
        self.items[parent].first = NONE
        self.items[parent].last = NONE

    def set_children(mut self, parent: Int, children: List[Int]):
        """Replace the children of a set.

        Args:
            parent: The set.
            children: The new children, in order. Their `next` links are
                rewritten.
        """
        self.clear(parent)
        for child in children:
            self.items[child].next = NONE
            self.append(parent, child)

    def children(self, parent: Int) -> List[Int]:
        """Return the children of a set, in order.

        Args:
            parent: The set.

        Returns:
            The child items.
        """
        var out = List[Int]()
        var child = self.items[parent].first
        while child != NONE:
            out.append(child)
            child = self.items[child].next
        return out^

    def count(self, parent: Int) -> Int:
        """Return how many children a set has.

        Args:
            parent: The set.

        Returns:
            The number of children.
        """
        var total = 0
        var child = self.items[parent].first
        while child != NONE:
            total += 1
            child = self.items[child].next
        return total

    def is_empty(self, parent: Int) -> Bool:
        """Return True if a set has no children.

        Args:
            parent: The set.

        Returns:
            Whether the set is empty.
        """
        return self.items[parent].first == NONE

    def copy_item(mut self, item: Int) -> Int:
        """Copy an item and everything below it.

        Args:
            item: The item.

        Returns:
            The copy, with no parent.
        """
        var copy = self._copy_one(item)
        # Pairs of (original, copy) whose children are still to copy.
        var stack: List[Int] = [item, copy]
        while len(stack) > 0:
            var target = stack.pop()
            var original = stack.pop()
            var child = self.items[original].first
            while child != NONE:
                var child_copy = self._copy_one(child)
                self.append(target, child_copy)
                if self.items[child].first != NONE:
                    stack.append(child)
                    stack.append(child_copy)
                child = self.items[child].next
        return copy

    def _copy_one(mut self, item: Int) -> Int:
        """Copy one item without its children."""
        var found = self.items[item]
        var copy = self.add_item(
            found.kind,
            found.name,
            found.alias,
            found.args,
            found.skip,
            found.include,
            found.omit,
        )
        self.items[copy].directives = found.directives
        return copy

    def copy_set(mut self, set: Int) -> Int:
        """Copy the children of a set into a new `ROOT` set.

        Args:
            set: The set.

        Returns:
            The new set.
        """
        var out = self.copy_item(set)
        self.items[out].kind = ItemKind.ROOT
        self.items[out].name = NONE
        self.items[out].alias = NONE
        self.items[out].args = NONE
        self.items[out].skip = NONE
        self.items[out].include = NONE
        self.items[out].omit = False
        return out

    def mark(self) -> Int:
        """Return the current end of the items, for `rollback`.

        Returns:
            The number of items.
        """
        return len(self.items)

    def rollback(mut self, mark: Int):
        """Drop every item added after a mark.

        Args:
            mark: A value of `mark`.
        """
        self.items.shrink(mark)

    def response_key(self, item: Int) -> Int:
        """Return a field's alias, or its name when it has none.

        Args:
            item: A field.

        Returns:
            The upstream `selection_identifier`, as a symbol.
        """
        var found = self.items[item]
        return found.alias if found.alias != NONE else found.name

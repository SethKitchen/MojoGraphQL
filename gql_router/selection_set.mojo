# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Selection set algorithms: print, compare, merge and find by path.

Port of Hive Router `1a29df9` `bin/router/src/query_planner/ast/`:
`selection_set.rs`, `selection_item.rs`, `semantic_eq.rs` and the
pretty printer of `utils/pretty_display.rs`.

Every function takes the `Store` and the index of a set: a field, an
inline fragment or a `ROOT` item. Upstream has three equalities, and so
does this port: `items_equal` is `SelectionItem` `PartialEq` (names and
nested selections only), `fields_equal` is `FieldSelection` `PartialEq`
(name, alias and arguments), and `semantic_eq` compares everything.
"""

from gql_router.ast import NONE, Cond, ItemKind
from gql_router.merge_path import MergePath, Segment, SegmentKind
from gql_router.store import Store


def is_field(store: Store, item: Int) -> Bool:
    """Return True if an item is a field.

    Args:
        store: The store.
        item: The item.

    Returns:
        Whether it is a field.
    """
    return store.items[item].kind == ItemKind.FIELD


# --- printing ---------------------------------------------------------------


def set_text(store: Store, set: Int) -> String:
    """Return a selection set as upstream `Display`: `{a b{c}}`.

    Args:
        store: The store.
        set: The set.

    Returns:
        The text; empty for an empty set.
    """
    var out = String()
    write_set(store, out, set)
    return out^


def write_set(store: Store, mut out: String, set: Int):
    """Write a selection set as upstream `Display`.

    Args:
        store: The store.
        out: The destination.
        set: The set.
    """
    var child = store.items[set].first
    if child == NONE:
        return
    out += "{"
    while child != NONE:
        if child != store.items[set].first:
            out += " "
        write_item(store, out, child)
        child = store.items[child].next
    out += "}"


def write_item(store: Store, mut out: String, item: Int):
    """Write one selection item as upstream `Display`.

    Args:
        store: The store.
        out: The destination.
        item: The item.
    """
    var found = store.items[item]
    if found.kind == ItemKind.SPREAD:
        out += "..."
        out += store.name(found.name)
        return
    if found.kind == ItemKind.FRAGMENT:
        out += "...on "
        out += store.name(found.name)
    else:
        if found.alias != NONE:
            out += store.name(found.alias)
            out += ": "
        out += store.name(found.name)
        if found.args != NONE:
            out += "("
            out += store.args[found.args].text
            out += ")"
    if found.skip != NONE:
        out += " @skip(if: $"
        out += store.name(found.skip)
        out += ")"
    if found.include != NONE:
        out += " @include(if: $"
        out += store.name(found.include)
        out += ")"
    write_set(store, out, item)


def write_indent(mut out: String, depth: Int):
    """Write the indentation of a depth: two spaces per level.

    Args:
        out: The destination.
        depth: The depth.
    """
    for _ in range(depth):
        out += "  "


def pretty_set(store: Store, mut out: String, set: Int, depth: Int):
    """Write a selection set as upstream `PrettyDisplay`, one item a line.

    Args:
        store: The store.
        out: The destination.
        set: The set.
        depth: The indentation depth of the items.
    """
    var child = store.items[set].first
    while child != NONE:
        pretty_item(store, out, child, depth)
        child = store.items[child].next


def pretty_item(store: Store, mut out: String, item: Int, depth: Int):
    """Write one item as upstream `PrettyDisplay`.

    Args:
        store: The store.
        out: The destination.
        item: The item.
        depth: The indentation depth.
    """
    var found = store.items[item]
    write_indent(out, depth)
    if found.kind == ItemKind.SPREAD:
        out += "..."
        out += store.name(found.name)
        out += "\n"
        return
    if found.kind == ItemKind.FRAGMENT:
        out += "... on "
        out += store.name(found.name)
        out += " "
        if found.skip != NONE:
            out += "@skip(if: $"
            out += store.name(found.skip)
            out += ") "
        if found.include != NONE:
            out += "@include(if: $"
            out += store.name(found.include)
            out += ") "
        out += "{\n"
        pretty_set(store, out, item, depth + 1)
        write_indent(out, depth)
        out += "}\n"
        return
    if found.alias != NONE:
        out += store.name(found.alias)
        out += ": "
    out += store.name(found.name)
    if found.args != NONE:
        out += "("
        out += store.args[found.args].text
        out += ")"
    if found.skip != NONE:
        out += " @skip(if: $"
        out += store.name(found.skip)
        out += ")"
    if found.include != NONE:
        out += " @include(if: $"
        out += store.name(found.include)
        out += ")"
    if found.first == NONE:
        out += "\n"
        return
    out += " {\n"
    pretty_set(store, out, item, depth + 1)
    write_indent(out, depth)
    out += "}\n"


# --- measures ---------------------------------------------------------------


def set_cost(store: Store, set: Int) -> Int:
    """Return upstream `SelectionSet::cost`: one, plus each item's cost.

    Args:
        store: The store.
        set: The set.

    Returns:
        The cost.
    """
    var cost = 1
    var child = store.items[set].first
    while child != NONE:
        cost += item_cost(store, child)
        child = store.items[child].next
    return cost


def item_cost(store: Store, item: Int) -> Int:
    """Return upstream `SelectionItem::cost`: one, plus each child's cost.

    Args:
        store: The store.
        item: The item.

    Returns:
        The cost.
    """
    # Each item below counts one, so the cost is the size of the subtree.
    var cost = 0
    var stack: List[Int] = [item]
    while len(stack) > 0:
        cost += 1
        var child = store.items[stack.pop()].first
        while child != NONE:
            stack.append(child)
            child = store.items[child].next
    return cost


def _insert_sorted(store: Store, mut out: List[Int], name: Int):
    """Insert a symbol into a list sorted by name, once."""
    for known in out:
        if known == name:
            return
    var at = len(out)
    while at > 0 and store.less(name, out[at - 1]):
        at -= 1
    out.insert(at, name)


def variable_usages(store: Store, set: Int, mut out: List[Int]):
    """Add the variables a selection set uses, as a sorted set of symbols.

    Args:
        store: The store.
        set: The set.
        out: The variables found so far, sorted by name.
    """
    var stack: List[Int] = [set]
    while len(stack) > 0:
        var child = store.items[stack.pop()].first
        while child != NONE:
            var found = store.items[child]
            if found.args != NONE:
                for variable in store.args[found.args].variables:
                    _insert_sorted(store, out, variable)
            if found.include != NONE:
                _insert_sorted(store, out, found.include)
            if found.skip != NONE:
                _insert_sorted(store, out, found.skip)
            stack.append(child)
            child = found.next


# --- equality ---------------------------------------------------------------


def fields_equal(store: Store, a: Int, b: Int) -> Bool:
    """Return upstream `FieldSelection` `PartialEq`: name, alias, arguments.

    Args:
        store: The store.
        a: A field.
        b: Another field.

    Returns:
        Whether the two fields are equal.
    """
    var x = store.items[a]
    var y = store.items[b]
    return x.name == y.name and x.alias == y.alias and x.args == y.args


def items_equal(store: Store, a: Int, b: Int) -> Bool:
    """Return upstream `SelectionItem` `PartialEq`.

    A field compares its name and nested selections, an inline fragment its
    type condition and nested selections. A spread is never equal.

    Args:
        store: The store.
        a: An item.
        b: Another item.

    Returns:
        Whether the two items are equal.
    """
    var x = store.items[a]
    var y = store.items[b]
    if x.kind != y.kind or x.kind == ItemKind.SPREAD:
        return False
    if x.name != y.name:
        return False
    return sets_equal(store, a, b)


def sets_equal(store: Store, a: Int, b: Int) -> Bool:
    """Return upstream `SelectionSet` `PartialEq`: items equal in order.

    Args:
        store: The store.
        a: A set.
        b: Another set.

    Returns:
        Whether the two sets are equal.
    """
    var x = store.items[a].first
    var y = store.items[b].first
    while x != NONE and y != NONE:
        if not items_equal(store, x, y):
            return False
        x = store.items[x].next
        y = store.items[y].next
    return x == NONE and y == NONE


def semantic_eq(store: Store, a: Int, b: Int) -> Bool:
    """Return upstream `SemanticEq` of two sets: equal in any order.

    Args:
        store: The store.
        a: A set.
        b: Another set.

    Returns:
        Whether each item of one set matches its own item of the other.
    """
    var left = store.children(a)
    var right = store.children(b)
    if len(left) != len(right):
        return False
    var matched = List[Bool](length=len(right), fill=False)
    for item in left:
        var found = False
        var index = 0
        while index < len(right):
            if not matched[index] and _item_semantic_eq(
                store, item, right[index]
            ):
                matched[index] = True
                found = True
                break
            index += 1
        if not found:
            return False
    return True


def _item_semantic_eq(store: Store, a: Int, b: Int) -> Bool:
    """Return upstream `SemanticEq` of two items."""
    var x = store.items[a]
    var y = store.items[b]
    if x.kind != y.kind or x.name != y.name:
        return False
    if x.kind == ItemKind.SPREAD:
        return True
    if x.skip != y.skip or x.include != y.include:
        return False
    if x.kind == ItemKind.FIELD and (
        x.alias != y.alias or x.args != y.args or x.omit != y.omit
    ):
        return False
    return semantic_eq(store, a, b)


def items_are_subset_of(store: Store, source: Int, target: Int) -> Bool:
    """Return upstream `selection_items_are_subset_of`.

    Every item of `target` must have an item of `source` that gives the
    same value: the same field, arguments and conditions, and the same
    nested selections or more.

    Args:
        store: The store.
        source: The set that has the values.
        target: The set that asks for them.

    Returns:
        Whether `source` covers `target`.
    """
    var wanted = store.items[target].first
    while wanted != NONE:
        var covered = False
        var have = store.items[source].first
        while have != NONE:
            if _item_is_subset_of(store, have, wanted):
                covered = True
                break
            have = store.items[have].next
        if not covered:
            return False
        wanted = store.items[wanted].next
    return True


def _item_is_subset_of(store: Store, source: Int, target: Int) -> Bool:
    """Return upstream `selection_item_is_subset_of`."""
    var x = store.items[source]
    var y = store.items[target]
    if x.kind != y.kind or x.kind == ItemKind.SPREAD:
        return False
    if x.skip != y.skip or x.include != y.include:
        return False
    if x.kind == ItemKind.FIELD:
        if not fields_equal(store, source, target):
            return False
        if (x.first == NONE) != (y.first == NONE):
            return False
    elif x.name != y.name:
        return False
    return items_are_subset_of(store, source, target)


# --- merging and paths ------------------------------------------------------


def merge_selection_set(
    mut store: Store, target: Int, source: Int, as_first: Bool
) raises:
    """Merge a copy of `source` into `target`, as upstream
    `merge_selection_set`.

    Args:
        store: The store.
        target: The set that receives the items.
        source: The set to merge.
        as_first: Put the new items before the existing ones.

    Raises:
        Error: When a field of `source` would share a response key with a
            different field or other arguments in `target`: upstream
            `ResponseKeyConflict`.
    """
    var pending = List[Int]()
    var item = store.items[source].first
    while item != NONE:
        var found = False
        var source_item = store.items[item]
        var existing = store.items[target].first
        while existing != NONE:
            var target_item = store.items[existing]
            if (
                source_item.kind == ItemKind.FIELD
                and target_item.kind == ItemKind.FIELD
            ):
                if store.response_key(item) == store.response_key(
                    existing
                ) and (
                    source_item.name != target_item.name
                    or source_item.args != target_item.args
                ):
                    raise Error(
                        "Response key '"
                        + store.name(store.response_key(item))
                        + "' would hold two different fields"
                    )
                if (
                    fields_equal(store, item, existing)
                    and source_item.skip == target_item.skip
                    and source_item.include == target_item.include
                ):
                    found = True
                    if target_item.name == store.find_sym("__typename"):
                        store.items[existing].omit = (
                            target_item.omit and source_item.omit
                        )
                    merge_selection_set(store, existing, item, as_first)
                    break
            elif (
                source_item.kind == ItemKind.FRAGMENT
                and target_item.kind == ItemKind.FRAGMENT
                and source_item.name == target_item.name
                and source_item.skip == target_item.skip
                and source_item.include == target_item.include
            ):
                found = True
                merge_selection_set(store, existing, item, as_first)
                break
            existing = store.items[existing].next
        if not found:
            pending.append(store.copy_item(item))
        item = store.items[item].next
    if as_first:
        var index = len(pending) - 1
        while index >= 0:
            store.prepend(target, pending[index])
            index -= 1
    else:
        for copy in pending:
            store.append(target, copy)


def segment_selects(store: Store, segment: Segment, item: Int) -> Bool:
    """Return True if a path step points at an item, as upstream
    `segment_selects`.

    Args:
        store: The store.
        segment: The step.
        item: The item.

    Returns:
        Whether the step selects the item.
    """
    var found = store.items[item]
    if segment.kind == SegmentKind.TYPE_CONDITION:
        if found.kind != ItemKind.FRAGMENT:
            return False
        ref names = store.type_sets[segment.types]
        var index = 0
        while index < len(names) and names[index] != found.name:
            index += 1
        return index < len(names) and segment.cond == Cond(
            found.skip, found.include
        )
    if segment.kind == SegmentKind.FIELD and found.kind == ItemKind.FIELD:
        return (
            store.response_key(item) == segment.response_key()
            and found.args == segment.args
            and segment.cond == Cond(found.skip, found.include)
        )
    return False


def find_by_path(store: Store, root: Int, path: MergePath) -> Int:
    """Return the set at a path, as upstream `find_selection_set_by_path`.

    List steps are skipped.

    Args:
        store: The store.
        root: The set to start from.
        path: The path.

    Returns:
        The field or fragment the path ends at, `root` for an empty path,
        or `NONE` when a step selects nothing.
    """
    var current = root
    for segment in path.segments:
        if segment.kind == SegmentKind.LIST:
            continue
        var child = store.items[current].first
        var next = NONE
        while child != NONE:
            if segment_selects(store, segment, child):
                next = child
                break
            child = store.items[child].next
        if next == NONE:
            return NONE
        current = next
    return current


def find_arguments_conflicts(
    store: Store, source: Int, other: Int
) -> List[Tuple[Int, Int]]:
    """Return upstream `find_arguments_conflicts`.

    Args:
        store: The store.
        source: A set.
        other: Another set.

    Returns:
        Pairs of (index in `source`, index in `other`) of fields with one
        response key and other arguments.
    """
    var out = List[Tuple[Int, Int]]()
    var other_items = store.children(other)
    var source_items = store.children(source)
    for index in range(len(other_items)):
        var other_item = other_items[index]
        if not is_field(store, other_item):
            continue
        var key = store.response_key(other_item)
        var args = store.items[other_item].args
        for self_index in range(len(source_items)):
            var self_item = source_items[self_index]
            if (
                is_field(store, self_item)
                and store.response_key(self_item) == key
                and store.items[self_item].args != args
            ):
                out.append((self_index, index))
                break
    return out^


def fields_through_fragments(store: Store, set: Int, mut out: List[Int]):
    """Add the fields of a set and of its inline fragments, at any depth.

    Args:
        store: The store.
        set: The set.
        out: The fields found so far.
    """
    var child = store.items[set].first
    while child != NONE:
        var kind = store.items[child].kind
        if kind == ItemKind.FIELD:
            out.append(child)
        elif kind == ItemKind.FRAGMENT:
            fields_through_fragments(store, child, out)
        child = store.items[child].next


def response_keys_conflict(store: Store, a: Int, b: Int) -> Bool:
    """Return upstream `response_keys_conflict`.

    Args:
        store: The store.
        a: A set.
        b: Another set.

    Returns:
        Whether a response key would hold two values when both sets are in
        one selection set.
    """
    var left = List[Int]()
    var right = List[Int]()
    fields_through_fragments(store, a, left)
    fields_through_fragments(store, b, right)
    for x in left:
        for y in right:
            if store.response_key(x) != store.response_key(y):
                continue
            if (
                store.items[x].name != store.items[y].name
                or store.items[x].args != store.items[y].args
                or response_keys_conflict(store, x, y)
            ):
                return True
    return False


def strip_for_plan_input(mut store: Store, set: Int) -> Int:
    """Return a copy without field arguments and field conditions, as
    upstream `strip_for_plan_input`.

    Args:
        store: The store.
        set: The set.

    Returns:
        A new `ROOT` set.
    """
    var out = store.copy_set(set)
    _strip(store, out)
    return out


def _strip(mut store: Store, set: Int):
    """Strip arguments and conditions of the fields below a set."""
    var stack: List[Int] = [set]
    while len(stack) > 0:
        var child = store.items[stack.pop()].first
        while child != NONE:
            if store.items[child].kind == ItemKind.FIELD:
                store.items[child].args = NONE
                store.items[child].skip = NONE
                store.items[child].include = NONE
            stack.append(child)
            child = store.items[child].next


def entities_field(store: Store, set: Int) -> Int:
    """Return the `_entities` field of a set, as upstream `entities_field`.

    Args:
        store: The store.
        set: The set.

    Returns:
        The first field named `_entities`, or `NONE`.
    """
    var name = store.find_sym("_entities")
    var child = store.items[set].first
    while child != NONE:
        if is_field(store, child) and store.items[child].name == name:
            return child
        child = store.items[child].next
    return NONE


def fields_of_same_type(store: Store, set: Int, type_name: Int) -> List[Int]:
    """Return upstream `iter_fields_and_fragments_of_same_type`.

    The fields of the set, and of its inline fragments on `type_name`, at
    any depth, in order.

    Args:
        store: The store.
        set: The set.
        type_name: The type, as a symbol.

    Returns:
        The fields.
    """
    var out = List[Int]()
    _fields_of_same_type(store, set, type_name, out)
    return out^


def _fields_of_same_type(
    store: Store, set: Int, type_name: Int, mut out: List[Int]
):
    """Collect upstream `iter_fields_and_fragments_of_same_type`."""
    var child = store.items[set].first
    while child != NONE:
        var found = store.items[child]
        if found.kind == ItemKind.FIELD:
            out.append(child)
        elif found.kind == ItemKind.FRAGMENT and found.name == type_name:
            _fields_of_same_type(store, child, type_name, out)
        child = found.next

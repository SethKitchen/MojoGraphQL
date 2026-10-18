# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The split of an operation into a part for the subgraphs and a part for
introspection.

Port of Hive Router `1a29df9`
`bin/router/src/executor/introspection/partition.rs`.

`partition_operation` walks the selections of a normalized operation. A
field whose name starts with `__`, other than `__typename`, goes to the
introspection part, at any depth. The router resolves that part itself.
All other selections go to the downstream part, which the subgraphs
resolve. A field or an inline fragment that has selections of both kinds
goes to both parts, each with its own selections. A fragment spread goes
to the downstream part.

The introspection part keeps only the variable definitions that it uses:
in arguments, and in `@skip` and `@include` conditions.

**Differences from upstream.** Upstream consumes the operation and moves
its selections. This port builds new items in the store and leaves the
items of the input operation as they are. Upstream returns
`Option<OperationDefinition>` for the introspection part; this port always
returns an operation and sets `has_introspection` to False when its
selection set is empty.
"""

from gql_router.ast import NONE, ItemKind
from gql_router.operation import OperationDefinition, VariableDefinition
from gql_router.store import Store


struct PartitionedOperation(Movable):
    """An operation split into a part for the subgraphs and a part for the
    router, as upstream `PartitionedOperation`."""

    var downstream_operation: OperationDefinition
    """The part that the subgraphs resolve."""
    var introspection_operation: OperationDefinition
    """The part that the router resolves. Its selection set is empty when
    `has_introspection` is False."""
    var has_introspection: Bool
    """False when upstream `introspection_operation` is `None`."""

    def __init__(
        out self,
        var downstream_operation: OperationDefinition,
        var introspection_operation: OperationDefinition,
        has_introspection: Bool,
    ):
        """Wrap the two parts.

        Args:
            downstream_operation: The part for the subgraphs.
            introspection_operation: The part for the router.
            has_introspection: Whether the router part has selections.
        """
        self.downstream_operation = downstream_operation^
        self.introspection_operation = introspection_operation^
        self.has_introspection = has_introspection


def _new_like(mut store: Store, item: Int) -> Int:
    """Add a copy of one item, without its children and its parent."""
    var found = store.items[item]
    var copy = store.add_item(
        found.kind,
        found.name,
        found.alias,
        found.args,
        found.skip,
        found.include,
        found.omit,
    )
    store.items[copy].directives = found.directives
    return copy


def _is_introspection_field(store: Store, item: Int) -> Bool:
    """Return True for a field whose name starts with `__`, other than
    `__typename`."""
    ref name = store.name(store.items[item].name)
    if not name.startswith("__"):
        return False
    return name != "__typename"


def partition_selection_set(
    mut store: Store, source: Int, downstream: Int, introspection: Int
):
    """Split the children of a set, as upstream `partition_selection_set`.

    Args:
        store: The store with the selections.
        source: The set, field or fragment whose children are split.
        downstream: The set that gets the selections for the subgraphs.
        introspection: The set that gets the introspection selections.
    """
    var child = store.items[source].first
    while child != NONE:
        var kind = store.items[child].kind
        if kind == ItemKind.SPREAD:
            store.append(downstream, _new_like(store, child))
        elif kind == ItemKind.FIELD and _is_introspection_field(store, child):
            store.append(introspection, store.copy_item(child))
        else:
            var down = _new_like(store, child)
            var intro = _new_like(store, child)
            partition_selection_set(store, child, down, intro)
            var need_down = not store.is_empty(down)
            if kind == ItemKind.FIELD and store.is_empty(child):
                # A leaf field goes downstream.
                need_down = True
            if need_down:
                store.append(downstream, down)
            if not store.is_empty(intro):
                store.append(introspection, intro)
        child = store.items[child].next


def _add_variable(mut used: List[Int], name: Int):
    """Add a variable to a list, once."""
    if name == NONE:
        return
    var index = 0
    while index < len(used):
        if used[index] == name:
            return
        index += 1
    used.append(name)


def variable_usages(store: Store, set: Int, mut used: List[Int]):
    """Add the variables that the selections of a set use to a list, as
    upstream `SelectionSet::variable_usages`.

    Args:
        store: The store with the selections.
        set: The set, field or fragment.
        used: The variables found so far, as symbols.
    """
    # The items still to visit, each with its next siblings.
    var stack: List[Int] = [store.items[set].first]
    while len(stack) > 0:
        var child = stack.pop()
        if child == NONE:
            continue
        var item = store.items[child]
        if item.args != NONE:
            ref variables = store.args[item.args].variables
            var index = 0
            while index < len(variables):
                _add_variable(used, variables[index])
                index += 1
        _add_variable(used, item.include)
        _add_variable(used, item.skip)
        stack.append(item.next)
        stack.append(item.first)


def partition_operation(
    mut store: Store, operation: OperationDefinition
) -> PartitionedOperation:
    """Split an operation into a part for the subgraphs and a part for the
    router, as upstream `partition_operation`.

    Args:
        store: The store with the selections. New items are added to it.
        operation: The normalized operation. Its items do not change.

    Returns:
        The two parts. The downstream part keeps every variable
        definition. The introspection part keeps the definitions that it
        uses.
    """
    var downstream_set = store.new_set()
    var introspection_set = store.new_set()
    partition_selection_set(
        store, operation.selection_set, downstream_set, introspection_set
    )
    var downstream = OperationDefinition(operation.kind, downstream_set)
    downstream.name = operation.name
    downstream.variables = operation.variables.copy()
    downstream.has_variables = operation.has_variables
    var introspection = OperationDefinition(operation.kind, introspection_set)
    introspection.name = operation.name
    introspection.has_variables = operation.has_variables
    var used = List[Int]()
    variable_usages(store, introspection_set, used)
    var index = 0
    while index < len(operation.variables):
        var definition = operation.variables[index].copy()
        var position = 0
        while position < len(used):
            if used[position] == definition.name:
                introspection.variables.append(definition.copy())
            position += 1
        index += 1
    return PartitionedOperation(
        downstream^, introspection^, not store.is_empty(introspection_set)
    )

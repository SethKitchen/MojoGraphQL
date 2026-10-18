# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The operation that the query planner plans.

Port of Hive Router `1a29df9` `bin/router/src/query_planner/ast/`
`operation.rs` and `value.rs`: `OperationDefinition`,
`VariableDefinition`, and the conversion of a parsed value into a planner
`Value`.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_router.ast import NONE, ValueKind
from gql_router.federation_spec import OperationKind, TypeNode
from gql_router.selection_set import write_set
from gql_router.store import Store


@fieldwise_init
struct VariableDefinition(Copyable, Movable):
    """One variable of an operation, as upstream `VariableDefinition`."""

    var name: Int
    """The variable name, as a symbol."""
    var variable_type: TypeNode
    """The variable type."""
    var default_value: Int
    """The default value, or `NONE`."""

    def can_merge(self, store: Store, other: Self) -> Bool:
        """Return True if two definitions of a variable agree.

        Args:
            store: The store with the values.
            other: Another definition.

        Returns:
            Whether the name, the type and the default value are equal.
        """
        if self.name != other.name:
            return False
        if self.variable_type != other.variable_type:
            return False
        return values_equal(store, self.default_value, other.default_value)

    def write(self, store: Store, mut out: String):
        """Write the definition as upstream `Display`: `$id:ID!=1`.

        Args:
            store: The store with the names and values.
            out: The destination.
        """
        out += "$"
        out += store.name(self.name)
        out += ":"
        out += self.variable_type.text(store)
        if self.default_value != NONE:
            out += "="
            store.write_value(out, self.default_value, False)


def values_equal(store: Store, a: Int, b: Int) -> Bool:
    """Return True if two values are equal, as upstream `Value` equality.

    Args:
        store: The store with the values.
        a: A value, or `NONE`.
        b: Another value, or `NONE`.

    Returns:
        Whether both are `NONE`, or both are equal values. An `Int` never
        equals a `Float`.
    """
    if a == NONE or b == NONE:
        return a == b
    var left = String()
    var right = String()
    store.write_value(left, a, True)
    store.write_value(right, b, True)
    return left == right


struct OperationDefinition(Copyable, Movable):
    """A normalized operation, as upstream `OperationDefinition`."""

    var name: Int
    """The operation name, as a symbol, or `NONE`."""
    var kind: OperationKind
    """The operation kind."""
    var selection_set: Int
    """The root selection set, a `ROOT` item."""
    var variables: List[VariableDefinition]
    """The variable definitions."""
    var has_variables: Bool
    """False when upstream `variable_definitions` is `None`."""

    def __init__(out self, kind: OperationKind, selection_set: Int):
        """Start an anonymous operation with no variables.

        Args:
            kind: The operation kind.
            selection_set: The root selection set.
        """
        self.name = NONE
        self.kind = kind
        self.selection_set = selection_set
        self.variables = List[VariableDefinition]()
        self.has_variables = False

    def text(self, store: Store) -> String:
        """Return the operation as upstream `Display`.

        Args:
            store: The store with the selections.

        Returns:
            The short form `{...}` for an anonymous query without
            variables; `kind name (vars){...}` otherwise.
        """
        var out = String()
        var anonymous = self.name == NONE or store.name(self.name) == ""
        if (
            self.kind == OperationKind.QUERY
            and anonymous
            and len(self.variables) == 0
        ):
            write_set(store, out, self.selection_set)
            return out^
        out += self.kind.as_str()
        if self.name != NONE:
            out += " "
            out += store.name(self.name)
            out += " "
        if len(self.variables) > 0:
            out += "("
            var index = 0
            while index < len(self.variables):
                if index > 0:
                    out += ", "
                self.variables[index].write(store, out)
                index += 1
            out += ")"
        write_set(store, out, self.selection_set)
        return out^


def value_from_ast(
    mut store: Store, document: Document, node: Int
) raises -> Int:
    """Add a parsed value to the store, as upstream `Value::from`.

    Args:
        store: The store.
        document: The document that holds the value.
        node: A value node.

    Returns:
        The value's index.

    Raises:
        Error: When an integer is out of the `i64` range.
    """
    var kind = document.kind(node)
    if kind == Kind.VARIABLE:
        var id = store.add_value(ValueKind.VARIABLE)
        store.values[id].text = store.sym(document.name(node))
        return id
    if kind == Kind.INT:
        var id = store.add_value(ValueKind.INT)
        try:
            store.values[id].number = Int64(atol(document.text(node)))
        except:
            raise Error("GraphQL integer value out of i64 range")
        return id
    if kind == Kind.FLOAT:
        var id = store.add_value(ValueKind.FLOAT)
        store.values[id].real = atof(document.text(node))
        return id
    if kind == Kind.STRING:
        var id = store.add_value(ValueKind.STRING)
        store.values[id].text = store.sym(document.string_value(node))
        return id
    if kind == Kind.BOOLEAN:
        var id = store.add_value(ValueKind.BOOLEAN)
        store.values[id].number = 1 if document.boolean_value(node) else 0
        return id
    if kind == Kind.NULL:
        return store.add_value(ValueKind.NULL)
    if kind == Kind.ENUM:
        var id = store.add_value(ValueKind.ENUM)
        store.values[id].text = store.sym(document.text(node))
        return id
    if kind == Kind.LIST:
        var id = store.add_value(ValueKind.LIST)
        var last = NONE
        var item = document.first_child(node)
        while item != NO_NODE:
            var member = value_from_ast(store, document, item)
            if last == NONE:
                store.values[id].first = member
            else:
                store.values[last].next = member
            last = member
            item = document.next_sibling(item)
        return id
    var id = store.add_value(ValueKind.OBJECT)
    var last = NONE
    var field = document.child(node, Role.FIELD)
    while field != NO_NODE:
        var member = value_from_ast(
            store, document, document.child(field, Role.VALUE)
        )
        store.values[member].key = store.sym(document.name(field))
        if last == NONE:
            store.values[id].first = member
        else:
            store.values[last].next = member
        last = member
        field = document.next_with_role(field)
    return id

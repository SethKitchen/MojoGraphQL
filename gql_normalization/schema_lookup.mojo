# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The lookups of the definition that the normalization passes make.

graphql-go-tools walks an operation with `astvisitor.Walker`, which keeps
`EnclosingTypeDefinition`: the type of the selection set being walked. The
passes here walk with an enclosing type index into `Schema.types`, or
`NO_TYPE` where the walker has `ast.InvalidNode`. These functions compute
it as the walker does, and answer the type questions of
`ast.Document` (`NodeImplementsInterface`, `NodeIsUnionMember`,
`InterfacesIntersect`, ...).
"""

from gql_language.ast import Document, Kind, NO_NODE, Role
from gql_schema.definition import Schema, TypeKind

comptime NO_TYPE = -1
"""No type: graphql-go-tools `ast.InvalidNode`."""


def unknown_type(name: StringSlice) -> Error:
    """Return the error of an unknown type: `ErrTypeUndefined`.

    Args:
        name: The type name.

    Returns:
        The error `Unknown type "<name>".`.
    """
    return Error('Unknown type "', name, '".')


@always_inline
def root_type(schema: Schema, document: Document, operation: Int) raises -> Int:
    """Return the root type of an operation definition.

    Args:
        schema: The schema.
        document: The operation document.
        operation: An `OperationDefinition` node.

    Returns:
        The index of the root type.

    Raises:
        Error: `ErrOperationTypeUndefined` when the schema has no root type
            for the operation type.
    """
    var kind = document.operation(operation)
    var type = schema.root_type(kind.value)
    if type < 0:
        # `MergeDefinitionWithBaseSchema` takes a type with the default
        # name for a root that the schema definition leaves out.
        type = schema.type_named(
            "Query" if kind.value
            == 0 else ("Mutation" if kind.value == 1 else "Subscription")
        )
    if type < 0:
        raise Error(
            "operation type ",
            kind.text(),
            " is not defined; did you forget to merge the base schema?",
        )
    return type


@always_inline
def type_condition(
    schema: Schema, document: Document, node: Int, enclosing: Int
) raises -> Int:
    """Return the type that a fragment selects on.

    Args:
        schema: The schema.
        document: The operation document.
        node: An `InlineFragment` or a `FragmentDefinition`.
        enclosing: The enclosing type, kept for an inline fragment without
            a type condition.

    Returns:
        The index of the type.

    Raises:
        Error: `Unknown type "<name>".` when the schema has no such type.
    """
    var condition = document.child(node, Role.TYPE_CONDITION)
    if condition == NO_NODE:
        return enclosing
    var name = document.name(condition)
    var type = schema.type_named(name)
    if type < 0:
        raise unknown_type(name)
    return type


@always_inline
def type_condition_name(
    document: Document, node: Int
) -> StringSlice[origin_of(document.source.bytes)]:
    """Return the type condition of a fragment, or empty.

    Args:
        document: The operation document.
        node: An `InlineFragment` or a `FragmentDefinition`.

    Returns:
        The name of the type condition, or an empty slice.
    """
    var condition = document.child(node, Role.TYPE_CONDITION)
    if condition == NO_NODE:
        return StringSlice[origin_of(document.source.bytes)]()
    return document.name(condition)


@always_inline
def field_type(
    schema: Schema, document: Document, enclosing: Int, field: Int
) -> Int:
    """Return the named type of a field, as the walker resolves it.

    `__typename` is `String`. A field that the enclosing type does not
    define has `NO_TYPE`.

    Args:
        schema: The schema.
        document: The operation document.
        enclosing: The enclosing type, or `NO_TYPE`.
        field: A `Field` node.

    Returns:
        The index of the field's named type, or `NO_TYPE`.
    """
    var name = document.name(field)
    var out = NO_TYPE
    if name == "__typename":
        out = schema.type_named("String")
    if enclosing == NO_TYPE:
        return out
    var definition = schema.field_named(enclosing, name)
    if definition >= 0:
        return Int(schema.fields[definition].type.named)
    if enclosing == Int(schema.query_type):
        if name == "__schema":
            return schema.type_named("__Schema")
        if name == "__type":
            return schema.type_named("__Type")
    return out


@always_inline
def field_definition(
    schema: Schema, document: Document, enclosing: Int, field: Int
) -> Int:
    """Return the definition of a field in its enclosing type, or -1.

    Args:
        schema: The schema.
        document: The operation document.
        enclosing: The enclosing type, or `NO_TYPE`.
        field: A `Field` node.

    Returns:
        The index in `Schema.fields`, or -1.
    """
    if enclosing == NO_TYPE:
        return -1
    return schema.field_named(enclosing, document.name(field))


@always_inline
def declares_interface(schema: Schema, type: Int, interface: Int) -> Bool:
    """Return True if a type lists an interface after `implements`:
    `NodeImplementsInterface`.

    Args:
        schema: The schema.
        type: An object or an interface; not `NO_TYPE`.
        interface: An interface.

    Returns:
        Whether the type declares the interface.
    """
    var span = schema.types[type].interfaces
    var index = Int(span.start)
    while index < span.end():
        if Int(schema.type_lists[index]) == interface:
            return True
        index += 1
    return False


@always_inline
def has_fields_of(schema: Schema, type: Int, interface: Int) -> Bool:
    """Return True if a type has a field of each name of an interface:
    `NodeImplementsInterfaceFields`.

    Args:
        schema: The schema.
        type: An object or an interface.
        interface: An interface.

    Returns:
        Whether every field name of the interface is a field of the type.
    """
    var span = schema.types[interface].fields
    var index = Int(span.start)
    while index < span.end():
        if schema.field_named(type, schema.fields[index].name) < 0:
            return False
        index += 1
    return True


@always_inline
def is_member(schema: Schema, type: Int, union: Int) -> Bool:
    """Return True if a type is a member of a union: `NodeIsUnionMember`.

    Args:
        schema: The schema.
        type: A type, or `NO_TYPE`.
        union: A union.

    Returns:
        Whether the union lists the type.
    """
    var span = schema.types[union].members
    var index = Int(span.start)
    while index < span.end():
        if Int(schema.type_lists[index]) == type:
            return True
        index += 1
    return False


def interfaces_intersect(schema: Schema, left: Int, right: Int) -> Bool:
    """Return True if an object implements both interfaces:
    `InterfacesIntersect`.

    Args:
        schema: The schema.
        left: An interface.
        right: An interface.

    Returns:
        Whether one object type declares both.
    """
    var lefts = schema.possible_types(left)
    var rights = schema.possible_types(right)
    var index = 0
    while index < len(rights):
        if rights[index] in lefts:
            return True
        index += 1
    return False


def union_intersects_interface(
    schema: Schema, union: Int, interface: Int
) -> Bool:
    """Return True if an object member of a union declares an interface:
    `UnionNodeIntersectsInterfaceNode`.

    Args:
        schema: The schema.
        union: A union.
        interface: An interface.

    Returns:
        Whether a member declares the interface.
    """
    var span = schema.types[union].members
    var index = Int(span.start)
    while index < span.end():
        var member = Int(schema.type_lists[index])
        if declares_interface(schema, member, interface):
            return True
        index += 1
    return False

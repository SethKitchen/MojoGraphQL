# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The type relations that the code generator asks of a schema.

Port of Apollo Kotlin `apollo-ast` `Schema.kt` `possibleTypes`,
`implementedTypes`, `isTypeASubTypeOf` and `isTypeASuperTypeOf`, and of
`definitionFromScope` for the fields of a selection, over the
`gql_schema` arenas.

**Differences from upstream.** None for a valid schema. Upstream walks the
interfaces that an interface implements again; a valid schema lists each
of them, so `gql_schema` `is_sub_type` gives the same answer.
"""

from gql_schema.definition import NO_TYPE, Schema, TypeKind, TypeRef


def is_sub_type_of(schema: Schema, type: Int, super_type: Int) -> Bool:
    """Return True when a type is a super type, or implements it, or is a
    member of it, as Apollo `isTypeASubTypeOf`.

    Args:
        schema: The schema.
        type: The type's index.
        super_type: The possible super type's index.

    Returns:
        Whether `super_type` is among the types that `type` implements,
        itself included.
    """
    if type == super_type:
        return True
    if not schema.types[super_type].kind.is_abstract():
        return False
    return schema.is_sub_type(super_type, type)


def possible_types(schema: Schema, type: Int) -> List[Int]:
    """Return the object types that a type condition can match, as Apollo
    `possibleTypes`.

    Args:
        schema: The schema.
        type: The type's index: an object, an interface or a union.

    Returns:
        The object itself, or the objects of an abstract type.
    """
    if schema.types[type].kind.is_abstract():
        return schema.possible_types(type)
    return [type]


def field_type(schema: Schema, parent: Int, name: StringSlice) -> TypeRef:
    """Return the type of a field of a type, meta fields included, as
    Apollo `definitionFromScope`.

    Args:
        schema: The schema.
        parent: The parent type's index, or `NO_TYPE`.
        name: The field's name.

    Returns:
        The type, or a reference to `NO_TYPE` when the field is unknown.
    """
    if parent == NO_TYPE:
        return TypeRef.of(NO_TYPE)
    if name == "__typename":
        return TypeRef.of(schema.type_named("String")).non_null()
    if parent == Int(schema.query_type):
        if name == "__schema":
            return TypeRef.of(schema.type_named("__Schema")).non_null()
        if name == "__type":
            return TypeRef.of(schema.type_named("__Type"))
    if not schema.types[parent].kind.has_fields():
        return TypeRef.of(NO_TYPE)
    var field = schema.field_named(parent, name)
    if field == NO_TYPE:
        return TypeRef.of(NO_TYPE)
    return schema.fields[field].type


def is_abstract(schema: Schema, type: Int) -> Bool:
    """Return True for an interface or a union, as Apollo `isAbstract`.

    Args:
        schema: The schema.
        type: The type's index.

    Returns:
        Whether the type is abstract.
    """
    return schema.types[type].kind.is_abstract()


def is_object(schema: Schema, type: Int) -> Bool:
    """Return True for an object type.

    Args:
        schema: The schema.
        type: The type's index.

    Returns:
        Whether the type is an object type.
    """
    return schema.types[type].kind == TypeKind.OBJECT

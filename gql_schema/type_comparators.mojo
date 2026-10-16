# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Compare GraphQL types: equal, subtype, overlap.

Port of graphql-js 16.14.2 `utilities/typeComparators.ts` (`isEqualType`,
`isTypeSubTypeOf`, `doTypesOverlap`).

A type is a `TypeRef`, so a wrapped type is a value and not an object.
`is_equal_type` compares the values; that is the graphql-js recursion over
the wrappers, done at once. A `TypeRef` whose named index is out of range is
the graphql-js `undefined`: it equals only itself, and it is not a subtype
of a named type.

**Differences from graphql-js.**

- `schema.isSubType` builds a map of every abstract type's possible types.
  Here an interface's subtype is found in the subtype's own interface list,
  and a union's in its member list. The answer is the same, and no map is
  built.
"""

from gql_schema.definition import Schema, TypeKind, TypeRef


@always_inline
def _kind(schema: Schema, type: Int) -> TypeKind:
    """Return a type's kind, or an invalid kind for an index out of range."""
    if type < 0 or type >= len(schema.types):
        return TypeKind(255)
    return schema.types[type].kind


def _in_list(schema: Schema, start: Int32, count: Int32, type: Int) -> Bool:
    """Return True if a run of `schema.type_lists` holds a type."""
    var index = Int(start)
    var end = index + Int(count)
    var items = schema.type_lists.unsafe_ptr()
    while index < end:
        if Int(items[unsafe_offset=index]) == type:
            return True
        index += 1
    return False


def _is_sub_type(schema: Schema, abstract: Int, maybe_sub: Int) -> Bool:
    """Return the graphql-js `schema.isSubType` for an abstract type."""
    ref named = schema.types[abstract]
    if named.kind == TypeKind.UNION:
        return _in_list(
            schema, named.members.start, named.members.count, maybe_sub
        )
    ref sub = schema.types[maybe_sub]
    return _in_list(
        schema, sub.interfaces.start, sub.interfaces.count, abstract
    )


def is_equal_type(type_a: TypeRef, type_b: TypeRef) -> Bool:
    """Return True if two types are equal (invariant), as graphql-js
    `isEqualType`.

    Args:
        type_a: The first type.
        type_b: The second type.

    Returns:
        Whether the named types and every wrapper are the same.
    """
    return type_a == type_b


def is_type_sub_type_of(
    schema: Schema, maybe_sub_type: TypeRef, super_type: TypeRef
) -> Bool:
    """Return True if a type is equal to or a subtype of a super type
    (covariant), as graphql-js `isTypeSubTypeOf`.

    Args:
        schema: The schema that holds both types.
        maybe_sub_type: The possible subtype.
        super_type: The possible super type.

    Returns:
        Whether a value of `maybe_sub_type` is a valid `super_type` value.
    """
    var sub = maybe_sub_type
    var sup = super_type
    while not (sub == sup):
        if sup.is_non_null():
            # A non-null super type needs a non-null subtype.
            if not sub.is_non_null():
                return False
            sub = sub.of_type()
            sup = sup.of_type()
        elif sub.is_non_null():
            # A nullable super type takes a non-null or a nullable subtype.
            sub = sub.of_type()
        elif sup.is_list():
            # A list super type needs a list subtype.
            if not sub.is_list():
                return False
            sub = sub.of_type()
            sup = sup.of_type()
        elif sub.is_list():
            return False
        else:
            var sub_kind = _kind(schema, Int(sub.named))
            return (
                _kind(schema, Int(sup.named)).is_abstract()
                and (
                    sub_kind == TypeKind.INTERFACE
                    or sub_kind == TypeKind.OBJECT
                )
                and _is_sub_type(schema, Int(sup.named), Int(sub.named))
            )
    return True


def do_types_overlap(schema: Schema, type_a: Int, type_b: Int) -> Bool:
    """Return True if two composite types can be the same object type, as
    graphql-js `doTypesOverlap`.

    Args:
        schema: The schema that holds both types.
        type_a: The first composite type's index.
        type_b: The second composite type's index.

    Returns:
        Whether the sets of possible object types of the two types
        intersect. The function is commutative.
    """
    if type_a == type_b:
        return True
    var b_is_abstract = schema.types[type_b].kind.is_abstract()
    if schema.types[type_a].kind.is_abstract():
        if b_is_abstract:
            # Both are abstract: look for a common possible type.
            var possible = schema.possible_types(type_a)
            var index = 0
            while index < len(possible):
                if _is_sub_type(schema, type_b, possible[index]):
                    return True
                index += 1
            return False
        return _is_sub_type(schema, type_a, type_b)
    if b_is_abstract:
        return _is_sub_type(schema, type_b, type_a)
    return False

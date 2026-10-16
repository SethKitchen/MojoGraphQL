# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Find the schema type that a type reference node names.

Port of graphql-js 16.14.2 `utilities/typeFromAST.ts`.

**Differences from upstream.** The result is a `TypeRef`, and an empty
`Optional` takes the place of `undefined`. graphql-js recurses into the
wrappers; this port walks down to the named type and wraps it on the way
back, which gives the same type.
"""

from gql_language.ast import Document, Kind, Role
from gql_schema.definition import NO_TYPE, Schema, TypeRef


def type_from_ast(
    schema: Schema, document: Document, node: Int
) -> Optional[TypeRef]:
    """Return the type that a type node names, as graphql-js `typeFromAST`.

    Args:
        schema: The schema to look the named type up in.
        document: The document that holds the node.
        node: A `NamedType`, `ListType` or `NonNullType` node.

    Returns:
        The type with its list and non-null wrappers, or none when the
        schema has no type with the name.
    """
    var wrappers = List[Kind]()
    var current = node
    while document.kind(current) != Kind.NAMED_TYPE:
        wrappers.append(document.kind(current))
        current = document.child(current, Role.TYPE)
    var named = schema.type_named(document.name(current))
    if named == NO_TYPE:
        return None
    var type = TypeRef.of(named)
    var index = len(wrappers) - 1
    while index >= 0:
        if wrappers[index] == Kind.LIST_TYPE:
            type = type.list_of()
        else:
            type = type.non_null()
        index -= 1
    return type

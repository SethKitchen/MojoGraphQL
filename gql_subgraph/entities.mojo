# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Resolve the representations of `Query._entities`.

Port of `@apollo/subgraph` 2.14.4 `src/types.ts` (MIT):
`entitiesResolver`, `withResolvedType`, `ensureValidRuntimeType` and
`maybeAddTypeNameToPossibleReturn`, with the messages of upstream.

For each representation, `entities_resolver` finds the object or interface
type that `__typename` names, calls its `__resolveReference`, and gives the
result the `__typename` of the type. For an interface, it finds the object
type of the result with the interface's `resolveType`, or as graphql-js
`defaultTypeResolver` does, and calls the `__resolveReference` of that
object type when the interface has none.

**Differences from upstream.**

- Execution is synchronous. A `__resolveReference` that raises fails the
  whole `_entities` field, as a JavaScript one that throws does; one that
  returns an error value fails its item only, as a rejected promise does.
  An error of the interface steps fails its item, as upstream.
- `@cacheControl` hints are not applied: there is no Apollo Server cache
  control.
- The value in `must resolve to an Object type at runtime with value X`
  is written as graphql-js `inspect` writes it, not as Node.js
  `util.inspect`.
"""

from gql_execution.execute import (
    IsTypeOf,
    ResolveInfo,
    Resolvers,
    TypeResolver,
)
from gql_execution.value import UNDEFINED, ValueKind, Values, inspect
from gql_schema.definition import NO_TYPE, Schema, TypeKind

comptime ReferenceResolver = def(
    mut values: Values, reference: Int, context: Int, info: ResolveInfo
) raises thin -> Int
"""A `__resolveReference` function, `GraphQLReferenceResolver`: it gets a
representation and returns the entity, `null`, or an error value."""


struct ReferenceResolvers(Copyable, Movable):
    """The `__resolveReference` function of each type that has one."""

    var type_names: List[String]
    """The object or interface type of each function."""
    var functions: List[ReferenceResolver]
    """Each function."""

    def __init__(out self):
        """Start with no functions."""
        self.type_names = List[String]()
        self.functions = List[ReferenceResolver]()

    def add(mut self, type_name: String, resolve: ReferenceResolver):
        """Set the `__resolveReference` of a type; a later one wins.

        Args:
            type_name: The object or interface type.
            resolve: The function.
        """
        self.type_names.append(type_name)
        self.functions.append(resolve)

    def find(self, type_name: StringSlice) -> Int:
        """Return the index of the function of a type.

        Args:
            type_name: The type.

        Returns:
            The index of the last function for the type, or -1.
        """
        var index = len(self.type_names) - 1
        while index >= 0 and self.type_names[index] != type_name:
            index -= 1
        return index


def _js_string(values: Values, value: Int) -> String:
    """Return a value as JavaScript template literal text."""
    var kind = values.kind(value)
    if kind == ValueKind.STRING:
        return String(values.string(value))
    if kind == ValueKind.UNDEFINED:
        return String("undefined")
    if kind == ValueKind.OBJECT:
        return String("[object Object]")
    return inspect(values, value)


def add_typename(mut values: Values, value: Int, typename: String) -> Int:
    """Give an object the `__typename` of its type, as upstream
    `maybeAddTypeNameToPossibleReturn`.

    Args:
        values: The arena.
        value: The value that a `__resolveReference` returned.
        typename: The type's name.

    Returns:
        The value; an object gets the `__typename` property.
    """
    if values.kind(value) == ValueKind.OBJECT:
        values.set(value, "__typename", values.add_string(typename))
    return value


def _last(names: List[String], name: StringSlice) -> Int:
    """Return the index of the last occurrence of a name, or -1."""
    var index = len(names) - 1
    while index >= 0 and names[index] != name:
        index -= 1
    return index


def _runtime_type(
    schema: Schema,
    resolvers: Resolvers,
    mut values: Values,
    value: Int,
    info: ResolveInfo,
    abstract: Int,
) raises -> Int:
    """Return the name of the object type of a value of an interface: its
    `resolveType`, or graphql-js `defaultTypeResolver`."""
    ref name = schema.types[abstract].name
    var custom = _last(resolvers.type_names, name)
    if custom >= 0:
        return resolvers.type_functions[custom](values, value, info, abstract)
    if values.kind(value) == ValueKind.OBJECT:
        var typename = values.get(value, "__typename")
        if values.kind(typename) == ValueKind.STRING:
            return typename
    var possible = schema.possible_types(abstract)
    var index = 0
    while index < len(possible):
        ref object = schema.types[possible[index]].name
        var check = _last(resolvers.object_names, object)
        if check >= 0 and resolvers.object_functions[check](
            values, value, info
        ):
            return values.add_string(object)
        index += 1
    return UNDEFINED


def _ensure_valid_runtime_type(
    schema: Schema, values: Values, runtime: Int, abstract: Int, result: Int
) raises -> Int:
    """Return the object type that a type resolver named, as upstream
    `ensureValidRuntimeType`."""
    var name = '"' + schema.types[abstract].name + '"'
    var kind = values.kind(runtime)
    if kind == ValueKind.UNDEFINED or kind == ValueKind.NULL:
        raise Error(
            "Abstract type "
            + name
            + " `__resolveReference` method must resolve to an Object type at"
            ' runtime. Either the object returned by "'
            + schema.types[abstract].name
            + '.__resolveReference" must include a valid `__typename` field,'
            " or the "
            + name
            + ' type should provide a "resolveType" function or each possible'
            ' type should provide an "isTypeOf" function.'
        )
    if kind != ValueKind.STRING:
        raise Error(
            "Abstract type "
            + name
            + " `__resolveReference` method must resolve to an Object type at"
            " runtime with value "
            + inspect(values, result)
            + ', received "'
            + inspect(values, runtime)
            + '".'
        )
    var runtime_name = String(values.string(runtime))
    var type = schema.type_named(runtime_name)
    if type == NO_TYPE:
        raise Error(
            "Abstract type "
            + name
            + ' `__resolveReference` method resolved to a type "'
            + runtime_name
            + '" that does not exist inside the schema.'
        )
    if schema.types[type].kind != TypeKind.OBJECT:
        raise Error(
            "Abstract type "
            + name
            + ' `__resolveReference` method resolved to a non-object type "'
            + runtime_name
            + '".'
        )
    if not schema.is_sub_type(abstract, type):
        raise Error(
            'Runtime Object type "'
            + runtime_name
            + '" `__resolveReference` method is not a possible type for '
            + name
            + "."
        )
    return type


def _interface_entity(
    schema: Schema,
    resolvers: Resolvers,
    references: ReferenceResolvers,
    mut values: Values,
    result: Int,
    info: ResolveInfo,
    abstract: Int,
    resolved: Bool,
) raises -> Int:
    """Finish an entity of an interface, as upstream `withResolvedType`."""
    var kind = values.kind(result)
    if kind == ValueKind.NULL:
        return result
    var runtime = _runtime_type(
        schema, resolvers, values, result, info, abstract
    )
    var type = _ensure_valid_runtime_type(
        schema, values, runtime, abstract, result
    )
    var name = schema.types[type].name
    var entity = add_typename(values, result, name)
    var own = references.find(name)
    if not resolved and own >= 0:
        entity = references.functions[own](
            values, entity, info.context_value, info
        )
        entity = add_typename(values, entity, name)
    return entity


def _entity(
    schema: Schema,
    resolvers: Resolvers,
    references: ReferenceResolvers,
    mut values: Values,
    reference: Int,
    info: ResolveInfo,
) raises -> Int:
    """Resolve one representation."""
    var typename = values.get(reference, "__typename")
    var name = _js_string(values, typename)
    var type = NO_TYPE
    if values.kind(typename) == ValueKind.STRING:
        type = schema.type_named(name)
    var kind = TypeKind.SCALAR
    if type != NO_TYPE:
        kind = schema.types[type].kind
    if kind != TypeKind.OBJECT and kind != TypeKind.INTERFACE:
        raise Error(
            'The _entities resolver tried to load an entity for type "'
            + name
            + '", but no object or interface type of that name was found in'
            " the schema"
        )
    var own = references.find(name)
    var result = reference
    if own >= 0:
        result = references.functions[own](
            values, reference, info.context_value, info
        )
    if kind == TypeKind.OBJECT:
        return add_typename(values, result, name)
    try:
        return _interface_entity(
            schema, resolvers, references, values, result, info, type, own >= 0
        )
    except error:
        return values.add_error(String(error))


def entities_resolver(
    schema: Schema,
    resolvers: Resolvers,
    references: ReferenceResolvers,
    mut values: Values,
    args: Int,
    info: ResolveInfo,
) raises -> Int:
    """Resolve the `representations` of `Query._entities`, as upstream
    `entitiesResolver`.

    Args:
        schema: The executable schema.
        resolvers: The resolvers: the `resolveType` and `isTypeOf`
            functions are read.
        references: The `__resolveReference` functions.
        values: The arena.
        args: The arguments of the field: an object with `representations`.
        info: The field; its context value goes to `__resolveReference`.

    Returns:
        A list with the entity of each representation, in order: an object
        with `__typename`, `null`, or an error value for an item that
        fails.

    Raises:
        Error: The message of upstream for a `__typename` that names no
            object or interface type, or the error of a
            `__resolveReference` of the type that `__typename` names.
    """
    var representations = values.get(args, "representations")
    var out = values.add_list()
    var item = values.first(representations)
    while item != UNDEFINED:
        var reference = values.copy(item)
        var entity = _entity(
            schema, resolvers, references, values, reference, info
        )
        values.append(out, entity)
        item = values.next(item)
    return out

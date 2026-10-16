# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Input coercion: variable values and literals to the values that
resolvers read.

Port of graphql-js 16.14.2 `utilities/coerceInputValue.ts`,
`utilities/valueFromAST.ts`, `utilities/valueFromASTUntyped.ts`,
`utilities/typeFromAST.ts`, `jsutils/printPathArray.ts`, and the
`parseValue` and `parseLiteral` functions of `type/scalars.ts` and of
`GraphQLEnumType` in `type/definition.ts`.

`coerce_input_value` coerces a value of a `Values` arena, such as a
variable value from a request, to an input type. `value_from_ast` coerces
a literal, with the coerced variable values. Both add their result to the
same arena.

**Differences from upstream.**

- A custom scalar always behaves as one built from SDL: `parseValue` is
  the identity, and `parseLiteral` is `valueFromASTUntyped`. An enum
  value's internal value is its name.
- `coerce_input_value_with` returns the errors in a list instead of
  calling `onError` for each. The errors and their order are the same.
- A handle and an error value count as JavaScript objects with no
  properties, as a class instance with no fields does.
"""

from std.math import trunc
from gql_json.number import read_float64
from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_language.error import GraphQLError, PathSegment
from gql_schema.definition import NO_TYPE, Schema, TypeKind, TypeRef
from gql_schema.suggestions import did_you_mean, suggestion_list
from gql_execution.value import UNDEFINED, ValueKind, Values, inspect
from gql_schema.values import js_number_to_string

comptime MAX_INT: Float64 = 2147483647
"""The graphql-js `GRAPHQL_MAX_INT`."""
comptime MIN_INT: Float64 = -2147483648
"""The graphql-js `GRAPHQL_MIN_INT`."""


@fieldwise_init
struct ScalarKind(Equatable, ImplicitlyCopyable):
    """Which coercion functions a scalar type has."""

    var value: Int8
    """The index; see `is_valid`."""

    comptime INT = ScalarKind(0)
    """The built-in `Int`."""
    comptime FLOAT = ScalarKind(1)
    """The built-in `Float`."""
    comptime STRING = ScalarKind(2)
    """The built-in `String`."""
    comptime BOOLEAN = ScalarKind(3)
    """The built-in `Boolean`."""
    comptime ID = ScalarKind(4)
    """The built-in `ID`."""
    comptime CUSTOM = ScalarKind(5)
    """A scalar from SDL: the identity, and `valueFromASTUntyped`."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the six kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value >= 0 and self.value <= 5


def scalar_kind(schema: Schema, type: Int) -> ScalarKind:
    """Return the coercion functions of a scalar type.

    Args:
        schema: The schema.
        type: A scalar type's index.

    Returns:
        The built-in scalar, or `CUSTOM`.
    """
    ref named = schema.types[type]
    if not named.is_builtin:
        return ScalarKind.CUSTOM
    if named.name == "Int":
        return ScalarKind.INT
    if named.name == "Float":
        return ScalarKind.FLOAT
    if named.name == "String":
        return ScalarKind.STRING
    if named.name == "Boolean":
        return ScalarKind.BOOLEAN
    return ScalarKind.ID


def is_integer(value: Float64) -> Bool:
    """Return True for a finite number with no fraction, as
    `Number.isInteger`.

    Args:
        value: The number.

    Returns:
        Whether the number is an integer.
    """
    return value - value == 0 and trunc(value) == value


def type_from_ast(schema: Schema, document: Document, node: Int) -> TypeRef:
    """Return the type that a type node names, as graphql-js `typeFromAST`.

    Args:
        schema: The schema.
        document: The document that holds the node.
        node: A `NamedType`, `ListType` or `NonNullType` node.

    Returns:
        The type; its `named` is `NO_TYPE` when the schema has no such
        type.
    """
    var kind = document.kind(node)
    if kind == Kind.NAMED_TYPE:
        return TypeRef.of(schema.type_named(document.name(node)))
    var inner = type_from_ast(schema, document, document.first_child(node))
    if inner.named == NO_TYPE:
        return inner
    if kind == Kind.LIST_TYPE:
        return inner.list_of()
    return inner.non_null()


def print_path_array(path: List[PathSegment]) -> String:
    """Return a path as graphql-js `printPathArray` writes it.

    Args:
        path: The keys and indices.

    Returns:
        Such as `.a[0].b`.
    """
    var out = String("")
    for ref segment in path:
        if segment.is_index():
            out += "[" + String(segment.index) + "]"
        else:
            out += "." + segment.key
    return out^


@fieldwise_init
struct CoercionError(Copyable, Movable):
    """One error of `coerce_input_value_with`: the arguments of graphql-js
    `onError`."""

    var path: List[PathSegment]
    """Where in the input value the error is."""
    var invalid_value: Int
    """The value that is not valid, in the arena."""
    var message: String
    """The message of the error."""


def _slot(mut values: Values, value: Int) -> Int:
    """Return a value that a container can hold: `undefined` as a node."""
    if value == UNDEFINED:
        return values.add_undefined()
    return value


def default_input_value(
    schema: Schema, mut values: Values, input_value: Int
) raises -> Int:
    """Return an argument's or input field's default value, as graphql-js
    `defaultValue`: the literal coerced with no variables.

    Args:
        schema: The schema.
        values: Where to add the value.
        input_value: The input value's index in `schema.input_values`.

    Returns:
        The value's index, or `UNDEFINED` when there is no default or it
        is not valid for the type.

    Raises:
        Error: As `value_from_ast` raises.
    """
    ref definition = schema.input_values[input_value]
    if not definition.has_default():
        return UNDEFINED
    var at = definition.default_value
    return value_from_ast(
        schema,
        schema.documents[Int(at.document)],
        Int(at.node),
        definition.type,
        values,
        UNDEFINED,
    )


def coerce_input_value(
    schema: Schema, mut values: Values, value: Int, type: TypeRef
) raises -> Int:
    """Coerce a value to an input type, as graphql-js `coerceInputValue`
    does with its default `onError`.

    Args:
        schema: The schema the type is in.
        values: The arena of the value, where the result goes too.
        value: The value's index, or `UNDEFINED`.
        type: The input type.

    Returns:
        The coerced value's index.

    Raises:
        Error: For the first invalid part of the value, such as `Invalid
            value "x" at "value.a": Int cannot represent non-integer
            value: "x"`; or as `value_from_ast` raises.
    """
    var errors = List[CoercionError]()
    var out = coerce_input_value_with(schema, values, value, type, errors)
    if len(errors) == 0:
        return out
    ref first = errors[0]
    var prefix = "Invalid value " + inspect(values, first.invalid_value)
    if len(first.path) > 0:
        prefix += ' at "value' + print_path_array(first.path) + '"'
    raise Error(prefix + ": " + first.message)


def coerce_input_value_with(
    schema: Schema,
    mut values: Values,
    value: Int,
    type: TypeRef,
    mut errors: List[CoercionError],
) raises -> Int:
    """Coerce a value to an input type, and collect each error, as graphql-js
    `coerceInputValue` with an `onError` that does not throw.

    Args:
        schema: The schema the type is in.
        values: The arena of the value, where the result goes too.
        value: The value's index, or `UNDEFINED`.
        type: The input type.
        errors: Where each error goes, in the graphql-js order.

    Returns:
        The coerced value's index; `UNDEFINED` where a part is invalid.

    Raises:
        Error: As `value_from_ast` raises for a default value.
    """
    var path = List[PathSegment]()
    return _coerce(schema, values, value, type, errors, path)


def _coerce(
    schema: Schema,
    mut values: Values,
    value: Int,
    type: TypeRef,
    mut errors: List[CoercionError],
    mut path: List[PathSegment],
) raises -> Int:
    """Return graphql-js `coerceInputValueImpl`."""
    if type.is_non_null():
        if not values.is_nullish(value):
            return _coerce(schema, values, value, type.of_type(), errors, path)
        errors.append(
            CoercionError(
                path.copy(),
                value,
                'Expected non-nullable type "'
                + schema.type_name(type)
                + '" not to be null.',
            )
        )
        return UNDEFINED
    if values.is_nullish(value):
        return values.add_null()
    var kind = values.kind(value)
    if type.is_list():
        var item_type = type.of_type()
        var out = values.add_list()
        if kind != ValueKind.LIST:
            var single = _coerce(schema, values, value, item_type, errors, path)
            var slot = _slot(values, single)
            values.append(out, slot)
            return out
        var item = values.first(value)
        var index = 0
        while item != UNDEFINED:
            path.append(PathSegment.of_index(index))
            var coerced = _coerce(schema, values, item, item_type, errors, path)
            _ = path.pop()
            var slot = _slot(values, coerced)
            values.append(out, slot)
            item = values.next(item)
            index += 1
        return out
    var named = Int(type.named)
    if schema.types[named].kind == TypeKind.INPUT_OBJECT:
        return _coerce_object(schema, values, value, named, errors, path)
    try:
        return parse_value(schema, values, value, named)
    except e:
        errors.append(CoercionError(path.copy(), value, String(e)))
        return UNDEFINED


def _coerce_object(
    schema: Schema,
    mut values: Values,
    value: Int,
    type: Int,
    mut errors: List[CoercionError],
    mut path: List[PathSegment],
) raises -> Int:
    """Return graphql-js `coerceInputValueImpl` for an input object type."""
    ref named = schema.types[type]
    var kind = values.kind(value)
    if kind.value <= ValueKind.LIST.value:
        errors.append(
            CoercionError(
                path.copy(),
                value,
                'Expected type "' + named.name + '" to be an object.',
            )
        )
        return UNDEFINED
    var out = values.add_object()
    var span = named.input_fields
    var index = Int(span.start) - 1
    while index + 1 < span.end():
        index += 1
        ref field = schema.input_values[index]
        var field_value = values.get(value, field.name)
        if values.kind(field_value) == ValueKind.UNDEFINED:
            var default = default_input_value(schema, values, index)
            if default != UNDEFINED:
                values.add_member(out, field.name, default)
            elif field.type.is_non_null():
                errors.append(
                    CoercionError(
                        path.copy(),
                        value,
                        'Field "'
                        + field.name
                        + '" of required type "'
                        + schema.type_name(field.type)
                        + '" was not provided.',
                    )
                )
            continue
        path.append(PathSegment.of_key(field.name))
        var coerced = _coerce(
            schema, values, field_value, field.type, errors, path
        )
        _ = path.pop()
        var slot = _slot(values, coerced)
        values.add_member(out, field.name, slot)
    var member = values.first(value) if kind == ValueKind.OBJECT else UNDEFINED
    while member != UNDEFINED:
        var key = String(values.key(member))
        if schema.input_field_named(type, key) == NO_TYPE:
            var names = List[String]()
            var position = Int(span.start) - 1
            while position + 1 < span.end():
                position += 1
                names.append(schema.input_values[position].name)
            errors.append(
                CoercionError(
                    path.copy(),
                    value,
                    'Field "'
                    + key
                    + '" is not defined by type "'
                    + named.name
                    + '".'
                    + did_you_mean(suggestion_list(key, names)),
                )
            )
        member = values.next(member)
    if named.is_one_of:
        if values.length(out) != 1:
            errors.append(
                CoercionError(
                    path.copy(),
                    value,
                    'Exactly one key must be specified for OneOf type "'
                    + named.name
                    + '".',
                )
            )
        var first = values.first(out)
        if first != UNDEFINED and values.kind(first) == ValueKind.NULL:
            var key = String(values.key(first))
            var at = path.copy()
            at.append(PathSegment.of_key(key))
            errors.append(
                CoercionError(
                    at^, first, 'Field "' + key + '" must be non-null.'
                )
            )
    return out


def _did_you_mean_enum_value(schema: Schema, type: Int, text: String) -> String:
    """Return graphql-js `didYouMeanEnumValue`."""
    ref named = schema.types[type]
    var names = List[String]()
    var index = Int(named.enum_values.start) - 1
    while index + 1 < named.enum_values.end():
        index += 1
        names.append(schema.enum_values[index].name)
    return did_you_mean("the enum value", suggestion_list(text, names))


def parse_value(
    schema: Schema, mut values: Values, value: Int, type: Int
) raises -> Int:
    """Coerce a value to a scalar or an enum type, as graphql-js
    `parseValue`.

    Args:
        schema: The schema the type is in.
        values: The arena of the value, where the result goes too.
        value: The value's index; not `null` or `undefined`.
        type: The scalar or enum type's index.

    Returns:
        The coerced value's index.

    Raises:
        Error: The graphql-js message, such as `Int cannot represent
            non-integer value: "1"`.
    """
    var kind = values.kind(value)
    ref named = schema.types[type]
    if named.kind == TypeKind.ENUM:
        if kind != ValueKind.STRING:
            var shown = inspect(values, value)
            raise Error(
                'Enum "'
                + named.name
                + '" cannot represent non-string value: '
                + shown
                + "."
                + _did_you_mean_enum_value(schema, type, shown)
            )
        var text = String(values.string(value))
        if schema.enum_value_named(type, text) == NO_TYPE:
            raise Error(
                'Value "'
                + text
                + '" does not exist in "'
                + named.name
                + '" enum.'
                + _did_you_mean_enum_value(schema, type, text)
            )
        return values.copy(value)
    var scalar = scalar_kind(schema, type)
    if scalar == ScalarKind.CUSTOM:
        return values.copy(value)
    var is_number = kind == ValueKind.NUMBER
    var number = values.number(value) if is_number else Float64(0)
    if scalar == ScalarKind.INT:
        if not is_number or not is_integer(number):
            raise Error(
                "Int cannot represent non-integer value: "
                + inspect(values, value)
            )
        if number > MAX_INT or number < MIN_INT:
            raise Error(
                "Int cannot represent non 32-bit signed integer value: "
                + js_number_to_string(number)
            )
        return values.copy(value)
    if scalar == ScalarKind.FLOAT:
        if not is_number or number - number != 0:
            raise Error(
                "Float cannot represent non numeric value: "
                + inspect(values, value)
            )
        return values.copy(value)
    if scalar == ScalarKind.STRING:
        if kind != ValueKind.STRING:
            raise Error(
                "String cannot represent a non string value: "
                + inspect(values, value)
            )
        return values.copy(value)
    if scalar == ScalarKind.BOOLEAN:
        if kind != ValueKind.BOOLEAN:
            raise Error(
                "Boolean cannot represent a non boolean value: "
                + inspect(values, value)
            )
        return values.copy(value)
    if kind == ValueKind.STRING:
        return values.copy(value)
    if is_number and is_integer(number):
        return values.add_string(js_number_to_string(number))
    raise Error("ID cannot represent value: " + inspect(values, value))


def _variable(
    document: Document, node: Int, values: Values, variables: Int
) -> Int:
    """Return the value of a variable node, or `UNDEFINED` when it has
    none: graphql-js `variables[name]`."""
    var name = document.name(node)
    var member = UNDEFINED
    if variables != UNDEFINED:
        member = values.member(variables, name)
    if values.kind(member) == ValueKind.UNDEFINED:
        return UNDEFINED
    return member


def is_missing_variable(
    document: Document, node: Int, values: Values, variables: Int
) -> Bool:
    """Return True for a variable with no value, as graphql-js
    `isMissingVariable`.

    Args:
        document: The document that holds the node.
        node: A value node.
        values: The arena of the variable values.
        variables: The coerced variable values, or `UNDEFINED`.

    Returns:
        Whether the node is a variable that has no value.
    """
    return (
        document.kind(node) == Kind.VARIABLE
        and _variable(document, node, values, variables) == UNDEFINED
    )


def value_from_ast(
    schema: Schema,
    document: Document,
    node: Int,
    type: TypeRef,
    mut values: Values,
    variables: Int,
) raises -> Int:
    """Coerce a literal to an input type, as graphql-js `valueFromAST`.

    Args:
        schema: The schema the type is in.
        document: The document that holds the literal.
        node: The literal's node.
        type: The input type.
        values: Where the result goes; the variable values are there too.
        variables: The coerced variable values, an object, or `UNDEFINED`.

    Returns:
        The value's index, or `UNDEFINED` when the literal is not valid
        for the type.

    Raises:
        Error: `Unexpected input type: X` when the literal reaches a type
            that is not an input type, as the graphql-js invariant does.
    """
    var kind = document.kind(node)
    if kind == Kind.VARIABLE:
        var found = _variable(document, node, values, variables)
        if found == UNDEFINED:
            return UNDEFINED
        if values.kind(found) == ValueKind.NULL and type.is_non_null():
            return UNDEFINED
        return values.copy(found)
    if type.is_non_null():
        if kind == Kind.NULL:
            return UNDEFINED
        return value_from_ast(
            schema, document, node, type.of_type(), values, variables
        )
    if kind == Kind.NULL:
        return values.add_null()
    if type.is_list():
        var item_type = type.of_type()
        if kind != Kind.LIST:
            var single = value_from_ast(
                schema, document, node, item_type, values, variables
            )
            if single == UNDEFINED:
                return UNDEFINED
            var wrapped = values.add_list()
            values.append(wrapped, single)
            return wrapped
        var list = values.add_list()
        var item = document.child(node, Role.LIST_ITEM)
        while item != NO_NODE:
            if is_missing_variable(document, item, values, variables):
                if item_type.is_non_null():
                    return UNDEFINED
                var null_item = values.add_null()
                values.append(list, null_item)
            else:
                var coerced = value_from_ast(
                    schema, document, item, item_type, values, variables
                )
                if coerced == UNDEFINED:
                    return UNDEFINED
                values.append(list, coerced)
            item = document.next_with_role(item)
        return list
    var named = Int(type.named)
    var named_kind = schema.types[named].kind
    if named_kind == TypeKind.INPUT_OBJECT:
        return _object_from_ast(
            schema, document, node, named, values, variables
        )
    if not named_kind.is_leaf():
        raise Error("Unexpected input type: " + schema.types[named].name)
    return _parse_literal(schema, document, node, named, values, variables)


def _object_from_ast(
    schema: Schema,
    document: Document,
    node: Int,
    type: Int,
    mut values: Values,
    variables: Int,
) raises -> Int:
    """Return graphql-js `valueFromAST` for an input object type."""
    if document.kind(node) != Kind.OBJECT:
        return UNDEFINED
    var out = values.add_object()
    ref named = schema.types[type]
    var index = Int(named.input_fields.start) - 1
    while index + 1 < named.input_fields.end():
        index += 1
        ref field = schema.input_values[index]
        # keyMap keeps the last field with a name.
        var value_node = NO_NODE
        var candidate = document.child(node, Role.FIELD)
        while candidate != NO_NODE:
            if document.name(candidate) == field.name:
                value_node = document.child(candidate, Role.VALUE)
            candidate = document.next_with_role(candidate)
        if value_node == NO_NODE or is_missing_variable(
            document, value_node, values, variables
        ):
            var default = default_input_value(schema, values, index)
            if default != UNDEFINED:
                values.add_member(out, field.name, default)
            elif field.type.is_non_null():
                return UNDEFINED
            continue
        var coerced = value_from_ast(
            schema, document, value_node, field.type, values, variables
        )
        if coerced == UNDEFINED:
            return UNDEFINED
        values.add_member(out, field.name, coerced)
    if named.is_one_of:
        if values.length(out) != 1:
            return UNDEFINED
        if values.kind(values.first(out)) == ValueKind.NULL:
            return UNDEFINED
    return out


def _parse_literal(
    schema: Schema,
    document: Document,
    node: Int,
    type: Int,
    mut values: Values,
    variables: Int,
) -> Int:
    """Return graphql-js `parseLiteral` of a scalar or an enum type, or
    `UNDEFINED` where it throws."""
    var kind = document.kind(node)
    if schema.types[type].kind == TypeKind.ENUM:
        if kind != Kind.ENUM:
            return UNDEFINED
        var name = document.text(node)
        if schema.enum_value_named(type, name) == NO_TYPE:
            return UNDEFINED
        return values.add_string(name)
    var scalar = scalar_kind(schema, type)
    if scalar == ScalarKind.CUSTOM:
        return value_from_ast_untyped(document, node, values, variables)
    if scalar == ScalarKind.INT:
        if kind != Kind.INT:
            return UNDEFINED
        var number = read_float64(document.text(node).as_bytes())
        if number > MAX_INT or number < MIN_INT:
            return UNDEFINED
        return values.add_number(number)
    if scalar == ScalarKind.FLOAT:
        if kind != Kind.INT and kind != Kind.FLOAT:
            return UNDEFINED
        return values.add_number(read_float64(document.text(node).as_bytes()))
    if scalar == ScalarKind.STRING:
        if kind != Kind.STRING:
            return UNDEFINED
        return values.add_string(document.string_value(node))
    if scalar == ScalarKind.BOOLEAN:
        if kind != Kind.BOOLEAN:
            return UNDEFINED
        return values.add_bool(document.boolean_value(node))
    if kind == Kind.STRING:
        return values.add_string(document.string_value(node))
    if kind == Kind.INT:
        return values.add_string(document.text(node))
    return UNDEFINED


def value_from_ast_untyped(
    document: Document, node: Int, mut values: Values, variables: Int
) -> Int:
    """Coerce a literal with no type, as graphql-js `valueFromASTUntyped`.

    An object literal that repeats a field keeps the field's first
    position and its last value, as a JavaScript object does.

    Args:
        document: The document that holds the literal.
        node: The literal's node.
        values: Where the result goes; the variable values are there too.
        variables: The coerced variable values, an object, or `UNDEFINED`.

    Returns:
        The value's index; `UNDEFINED` for a variable with no value.
    """
    var kind = document.kind(node)
    if kind == Kind.NULL:
        return values.add_null()
    if kind == Kind.INT or kind == Kind.FLOAT:
        return values.add_number(read_float64(document.text(node).as_bytes()))
    if kind == Kind.STRING:
        return values.add_string(document.string_value(node))
    if kind == Kind.ENUM:
        return values.add_string(document.text(node))
    if kind == Kind.BOOLEAN:
        return values.add_bool(document.boolean_value(node))
    if kind == Kind.VARIABLE:
        return values.copy(_variable(document, node, values, variables))
    var is_list = kind == Kind.LIST
    var out = values.add_list() if is_list else values.add_object()
    var role = Role.LIST_ITEM if is_list else Role.FIELD
    var child = document.child(node, role)
    while child != NO_NODE:
        var value_node = child if is_list else document.child(child, Role.VALUE)
        var item = _slot(
            values,
            _untyped_item(document, value_node, values, variables),
        )
        if is_list:
            values.append(out, item)
        else:
            values.set(out, document.name(child), item)
        child = document.next_with_role(child)
    return out


def _untyped_item(
    document: Document, node: Int, mut values: Values, variables: Int
) -> Int:
    """Coerce a nested literal with no type; mutual recursion with
    `value_from_ast_untyped`."""
    return value_from_ast_untyped(document, node, values, variables)

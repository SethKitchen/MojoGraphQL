# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Variable values, argument values and directive values of an operation.

Port of graphql-js 16.14.2 `execution/values.ts`: `getVariableValues`,
`getArgumentValues` and `getDirectiveValues`, with the same messages,
locations and order of errors.

**Differences from upstream.**

- The inputs are an object of a `Values` arena, not a JavaScript object.
  `Values.add_json` makes one from the JSON of a request.
- `get_variable_values` coerces every variable and then keeps the first
  `max_errors` errors and the error `Too many errors processing
  variables, error limit reached. Execution aborted.`. graphql-js stops at
  that error; coercion has no side effects, so the result is the same.
- An argument is an argument of a field or of a directive, named by an
  `ArgumentOwner`, not by the field or directive object.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_language.error import GraphQLError
from gql_language.printer import print_node
from gql_schema.definition import NO_TYPE, Range, Schema, TypeRef
from gql_execution.coerce import (
    CoercionError,
    coerce_input_value_with,
    default_input_value,
    print_path_array,
    type_from_ast,
    value_from_ast,
)
from gql_execution.value import UNDEFINED, ValueKind, Values, inspect

comptime DEFAULT_MAX_ERRORS = 50
"""The graphql-js `maxCoercionErrors` when the option is not set."""


@fieldwise_init
struct CoercedVariables(Movable):
    """The result of `get_variable_values`: the values, or the errors."""

    var coerced: Int
    """The object of coerced values, or `UNDEFINED` when there are
    errors."""
    var errors: List[GraphQLError]
    """The errors; empty when the values are valid."""


def _error_at(document: Document, node: Int, message: String) -> GraphQLError:
    """Return an error located at a node, as `{ nodes: node }`."""
    return GraphQLError(message, document.source, [document.start(node)])


def get_variable_values(
    schema: Schema,
    document: Document,
    operation: Int,
    mut values: Values,
    inputs: Int,
    max_errors: Int = DEFAULT_MAX_ERRORS,
) raises -> CoercedVariables:
    """Coerce the variable values of an operation, as graphql-js
    `getVariableValues`.

    Args:
        schema: The schema.
        document: The document that holds the operation.
        operation: The `OperationDefinition` node.
        values: The arena of the inputs, where the result goes too.
        inputs: An object of raw variable values, or `UNDEFINED` for none.
        max_errors: How many errors to keep before coercion stops.

    Returns:
        The coerced values, in the order of the variable definitions; or
        the errors.

    Raises:
        Error: As `value_from_ast` raises for a default value.
    """
    var errors = List[GraphQLError]()
    var coerced = values.add_object()
    var definition = document.child(operation, Role.VARIABLE_DEFINITION)
    while definition != NO_NODE:
        _coerce_variable(
            schema, document, definition, values, inputs, coerced, errors
        )
        definition = document.next_with_role(definition)
    if len(errors) == 0:
        return CoercedVariables(coerced, errors^)
    if len(errors) > max_errors:
        errors.resize(max_errors, GraphQLError(""))
        errors.append(
            GraphQLError(
                "Too many errors processing variables, error limit"
                " reached. Execution aborted."
            )
        )
    return CoercedVariables(UNDEFINED, errors^)


def _coerce_variable(
    schema: Schema,
    document: Document,
    definition: Int,
    mut values: Values,
    inputs: Int,
    coerced: Int,
    mut errors: List[GraphQLError],
) raises:
    """Coerce one variable, as the loop body of graphql-js
    `coerceVariableValues`."""
    var variable = document.child(definition, Role.VARIABLE)
    var name = String(document.name(variable))
    var type_node = document.child(definition, Role.TYPE)
    var type = type_from_ast(schema, document, type_node)
    if (
        type.named == NO_TYPE
        or not schema.types[Int(type.named)].kind.is_input()
    ):
        errors.append(
            _error_at(
                document,
                type_node,
                'Variable "$'
                + name
                + '" expected value of type "'
                + print_node(document, type_node)
                + '" which cannot be used as an input type.',
            )
        )
        return
    var member = UNDEFINED
    if inputs != UNDEFINED:
        member = values.member(inputs, name)
    if member == UNDEFINED:
        var default = document.child(definition, Role.DEFAULT_VALUE)
        if default != NO_NODE:
            var value = value_from_ast(
                schema, document, default, type, values, UNDEFINED
            )
            if value == UNDEFINED:
                value = values.add_undefined()
            values.add_member(coerced, name, value)
        elif type.is_non_null():
            errors.append(
                _error_at(
                    document,
                    definition,
                    'Variable "$'
                    + name
                    + '" of required type "'
                    + schema.type_name(type)
                    + '" was not provided.',
                )
            )
        return
    if values.kind(member) == ValueKind.NULL and type.is_non_null():
        errors.append(
            _error_at(
                document,
                definition,
                'Variable "$'
                + name
                + '" of non-null type "'
                + schema.type_name(type)
                + '" must not be null.',
            )
        )
        return
    var problems = List[CoercionError]()
    var value = coerce_input_value_with(schema, values, member, type, problems)
    for ref problem in problems:
        var prefix = (
            'Variable "$'
            + name
            + '" got invalid value '
            + inspect(values, problem.invalid_value)
        )
        if len(problem.path) > 0:
            prefix += ' at "' + name + print_path_array(problem.path) + '"'
        errors.append(
            _error_at(document, definition, prefix + "; " + problem.message)
        )
    if value == UNDEFINED:
        value = values.add_undefined()
    values.add_member(coerced, name, value)


@fieldwise_init
struct ArgumentOwner(Equatable, ImplicitlyCopyable):
    """What an argument list belongs to: a field or a directive."""

    var value: UInt8
    """The kind; see `is_valid`."""

    comptime FIELD = ArgumentOwner(0)
    """A field: an index into `Schema.fields`."""
    comptime DIRECTIVE = ArgumentOwner(1)
    """A directive: an index into `Schema.directives`."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the two owners.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 1


def _wrap(var error: Error) -> GraphQLError:
    """Return an `Error` as a `GraphQLError` with no location."""
    return GraphQLError(String(error))


def get_argument_values(
    schema: Schema,
    owner: ArgumentOwner,
    definition: Int,
    document: Document,
    node: Int,
    mut values: Values,
    variables: Int,
) raises GraphQLError -> Int:
    """Coerce the arguments of a field or directive node, as graphql-js
    `getArgumentValues`.

    Args:
        schema: The schema.
        owner: Whether `definition` is a field or a directive.
        definition: The field's or directive's index.
        document: The document that holds the node.
        node: The `Field` or `Directive` node.
        values: Where the result goes; the variable values are there too.
        variables: The coerced variable values, or `UNDEFINED`.

    Returns:
        An object of the coerced argument values, in definition order.

    Raises:
        GraphQLError: The graphql-js message, such as `Argument "a" of
            required type "Int!" was not provided.`, located at the node
            or at the argument's value. `Unexpected input type: X` has no
            location.
    """
    var span: Range
    if owner == ArgumentOwner.FIELD:
        span = schema.fields[definition].arguments
    else:
        span = schema.directives[definition].arguments
    var out = values.add_object()
    for index in range(Int(span.start), span.end()):
        ref definition = schema.input_values[index]
        coerce_argument(
            schema,
            definition.name,
            definition.type,
            index,
            document,
            node,
            values,
            variables,
            out,
        )
    return out


def _default(
    schema: Schema, mut values: Values, argument: Int
) raises GraphQLError -> Int:
    """Return `default_input_value`, with its error as a `GraphQLError`;
    `UNDEFINED` for `NO_TYPE`."""
    if argument == NO_TYPE:
        return UNDEFINED
    try:
        return default_input_value(schema, values, argument)
    except e:
        raise _wrap(e^)


def _from_ast(
    schema: Schema,
    document: Document,
    node: Int,
    type: TypeRef,
    mut values: Values,
    variables: Int,
) raises GraphQLError -> Int:
    """Return `value_from_ast`, with its error as a `GraphQLError`."""
    try:
        return value_from_ast(schema, document, node, type, values, variables)
    except e:
        raise _wrap(e^)


def _required(schema: Schema, name: String, type: TypeRef) -> String:
    """Return the start of the messages of a missing required argument."""
    return (
        'Argument "'
        + name
        + '" of required type "'
        + schema.type_name(type)
        + '" '
    )


def coerce_argument(
    schema: Schema,
    name: String,
    type: TypeRef,
    argument: Int,
    document: Document,
    node: Int,
    mut values: Values,
    variables: Int,
    target: Int,
) raises GraphQLError:
    """Coerce one argument of a node, as the loop body of graphql-js
    `getArgumentValues`, and set it on an object.

    Args:
        schema: The schema.
        name: The argument's name.
        type: The argument's type.
        argument: The argument's index in `schema.input_values`, for its
            default value; or `NO_TYPE` for an argument with no default,
            such as the `name` of `__type`.
        document: The document that holds the node.
        node: The `Field` or `Directive` node.
        values: Where the result goes; the variable values are there too.
        variables: The coerced variable values, or `UNDEFINED`.
        target: The object that gets the value, when there is one.

    Raises:
        GraphQLError: As `get_argument_values` raises.
    """
    # keyMap keeps the last argument node with a name.
    var argument_node = NO_NODE
    var candidate = document.child(node, Role.ARGUMENT)
    while candidate != NO_NODE:
        if document.name(candidate) == name:
            argument_node = candidate
        candidate = document.next_with_role(candidate)
    if argument_node == NO_NODE:
        var default = _default(schema, values, argument)
        if default != UNDEFINED:
            values.add_member(target, name, default)
        elif type.is_non_null():
            raise _error_at(
                document,
                node,
                _required(schema, name, type) + "was not provided.",
            )
        return
    var value_node = document.child(argument_node, Role.VALUE)
    var is_null = document.kind(value_node) == Kind.NULL
    if document.kind(value_node) == Kind.VARIABLE:
        var variable = String(document.name(value_node))
        var member = UNDEFINED
        if variables != UNDEFINED:
            member = values.member(variables, variable)
        if member == UNDEFINED:
            var default = _default(schema, values, argument)
            if default != UNDEFINED:
                values.add_member(target, name, default)
            elif type.is_non_null():
                raise _error_at(
                    document,
                    value_node,
                    _required(schema, name, type)
                    + 'was provided the variable "$'
                    + variable
                    + '" which was not provided a runtime value.',
                )
            return
        is_null = values.is_nullish(member)
    if is_null and type.is_non_null():
        raise _error_at(
            document,
            value_node,
            'Argument "'
            + name
            + '" of non-null type "'
            + schema.type_name(type)
            + '" must not be null.',
        )
    var coerced = _from_ast(
        schema, document, value_node, type, values, variables
    )
    if coerced == UNDEFINED:
        raise _error_at(
            document,
            value_node,
            'Argument "'
            + name
            + '" has invalid value '
            + print_node(document, value_node)
            + ".",
        )
    values.add_member(target, name, coerced)


def get_directive_values(
    schema: Schema,
    directive: Int,
    document: Document,
    node: Int,
    mut values: Values,
    variables: Int,
) raises GraphQLError -> Int:
    """Coerce the arguments of the first use of a directive on a node, as
    graphql-js `getDirectiveValues`.

    Args:
        schema: The schema.
        directive: The directive's index.
        document: The document that holds the node.
        node: A node that can have directives.
        values: Where the result goes; the variable values are there too.
        variables: The coerced variable values, or `UNDEFINED`.

    Returns:
        An object of the argument values, or `UNDEFINED` when the node
        does not use the directive.

    Raises:
        GraphQLError: As `get_argument_values` raises.
    """
    var name = schema.directives[directive].name
    var current = document.child(node, Role.DIRECTIVE)
    while current != NO_NODE:
        if document.name(current) == name:
            return get_argument_values(
                schema,
                ArgumentOwner.DIRECTIVE,
                directive,
                document,
                current,
                values,
                variables,
            )
        current = document.next_with_role(current)
    return UNDEFINED

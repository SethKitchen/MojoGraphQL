# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The variable passes of graphql-go-tools v2 `astnormalization`.

| Function | Upstream file |
| --- | --- |
| `extract_variables` | `variables_extraction.go` |
| `input_coercion_for_list` | `input_coercion_for_list.go` |
| `extract_variables_default_value` | `variables_default_value_extraction.go` |
| `inject_input_field_defaults` | `inject_input_default_values.go` |
| `variables_processing` | the three above on one walker, as the `variablesProcessing` stage |

The variables are JSON text. The passes edit it as `sjson` and
`jsonparser` do, so the bytes are the same as upstream.

Differences from upstream:

- File uploads (`uploads.UploadFinder` and the upload path mapping that
  `NormalizeNamedOperationWithResult` returns) are not ported.
- `inject_input_field_defaults` reads a variable value that is a JSON
  string with its quotes. Upstream reads it without them, which matters
  only for a string where an input object or a list must be.
"""

from gql_language.ast import Document, Kind, NO_NODE, Role
from gql_schema.definition import Schema, TypeKind, TypeRef

from gql_normalization.edit import insert_after, previous_sibling, remove_child
from gql_normalization.schema_lookup import (
    NO_TYPE,
    field_definition,
    field_type,
    root_type,
    type_condition,
)
from gql_normalization.values import (
    add_type_node,
    contains_variable,
    is_list,
    is_non_null,
    list_or_name,
    list_wraps,
    type_ref_of,
    unwrap,
    value_to_json,
)
from gql_normalization.variables_json import (
    elements,
    json_kind,
    jsonparser_set,
    members,
    set_path,
    set_raw,
    top_level_member,
)

comptime _ALPHABET = "abcdefghijklmnopqrstuvwxyz"
"""The letters of the generated variable names."""


def _variable_definition(
    document: Document, operation: Int, name: StringSlice
) -> Int:
    """Return the variable definition of an operation with a name, or
    `NO_NODE`: `VariableDefinitionByNameAndOperation`."""
    var variable = document.child(operation, Role.VARIABLE_DEFINITION)
    while variable != NO_NODE:
        if document.name(document.child(variable, Role.VARIABLE)) == name:
            return variable
        variable = document.next_with_role(variable)
    return NO_NODE


def unused_variable_name(document: Document, operation: Int) -> String:
    """Return the first name of `a` to `z`, then `aa` to `zz`, and so on,
    that no variable of an operation has:
    `GenerateUnusedVariableDefinitionName`.

    Args:
        document: The operation document.
        operation: An `OperationDefinition` node.

    Returns:
        The name.
    """
    var length = 1
    while True:
        var letter = 0
        while letter < 26:
            var name = String()
            var count = 0
            while count < length:
                name += _ALPHABET[byte = letter : letter + 1]
                count += 1
            if _variable_definition(document, operation, name) == NO_NODE:
                return name^
            letter += 1
        length += 1


def _set_value(mut document: Document, argument: Int, name: StringSlice):
    """Replace the value of an argument with a variable."""
    var old = document.child(argument, Role.VALUE)
    var previous = previous_sibling(document, argument, old)
    remove_child(document, argument, old)
    var variable = document.add(Kind.VARIABLE, Role.VALUE)
    _ = document.add_name(variable, Role.NAME, name)
    insert_after(document, argument, previous, variable)


def add_variable_definition(
    mut document: Document,
    schema: Schema,
    operation: Int,
    name: StringSlice,
    type: TypeRef,
):
    """Add `$name: Type` after the variable definitions of an operation.

    Args:
        document: The operation document.
        schema: The schema, for the type name.
        operation: An `OperationDefinition` node.
        name: The variable name.
        type: The type.
    """
    var definition = document.add(
        Kind.VARIABLE_DEFINITION, Role.VARIABLE_DEFINITION
    )
    var variable = document.add_child(definition, Kind.VARIABLE, Role.VARIABLE)
    _ = document.add_name(variable, Role.NAME, name)
    document.append_child(definition, add_type_node(document, schema, type))
    var previous = document.child(operation, Role.NAME)
    var current = document.child(operation, Role.VARIABLE_DEFINITION)
    while current != NO_NODE:
        previous = current
        current = document.next_with_role(current)
    insert_after(document, operation, previous, definition)


struct _Extraction(Movable):
    """The state of `variablesExtractionVisitor`."""

    var names: List[String]
    """The names of the extracted variables."""
    var types: List[TypeRef]
    """The type of each extracted variable."""

    def __init__(out self):
        self.names = List[String]()
        self.types = List[TypeRef]()


def _existing(
    document: Document,
    state: _Extraction,
    variables: String,
    operation: Int,
    json: String,
    type: TypeRef,
) -> String:
    """Return an extracted variable of the same type and value, or empty:
    `variableExists`."""
    var found = String()
    for member in members(variables):
        var key = member.key(variables)
        var extracted = False
        var index = 0
        while index < len(state.names):
            if state.names[index] == key and state.types[index] == type:
                extracted = True
            index += 1
        if extracted and member.value(variables) == json:
            found = String(key)
    if (
        found.byte_length() > 0
        and _variable_definition(document, operation, found) == NO_NODE
    ):
        return String()
    return found^


def _extract_set(
    mut document: Document,
    schema: Schema,
    mut variables: String,
    mut state: _Extraction,
    operation: Int,
    selection_set: Int,
    enclosing: Int,
) raises:
    """Extract the argument values of the fields under a selection set."""
    var selection = document.first_child(selection_set)
    while selection != NO_NODE:
        var kind = document.kind(selection)
        if kind == Kind.FIELD:
            var definition = field_definition(
                schema, document, enclosing, selection
            )
            for argument in document.children(selection, Role.ARGUMENT):
                if definition < 0:
                    break
                var input = schema.argument_named(
                    definition, document.name(argument)
                )
                if input < 0:
                    continue
                var value = document.child(argument, Role.VALUE)
                if document.kind(value) == Kind.VARIABLE:
                    continue
                var json = value_to_json(document, value, variables)
                var type = schema.input_values[input].type
                var name = _existing(
                    document, state, variables, operation, json, type
                )
                if name.byte_length() == 0:
                    name = unused_variable_name(document, operation)
                    variables = set_raw(variables, name, json)
                    state.names.append(name)
                    state.types.append(type)
                    _set_value(document, argument, name)
                    add_variable_definition(
                        document, schema, operation, name, type
                    )
                else:
                    _set_value(document, argument, name)
            var inner = document.child(selection, Role.SELECTION_SET)
            if inner != NO_NODE:
                _extract_set(
                    document,
                    schema,
                    variables,
                    state,
                    operation,
                    inner,
                    field_type(schema, document, enclosing, selection),
                )
        elif kind == Kind.INLINE_FRAGMENT:
            var type = type_condition(schema, document, selection, enclosing)
            _extract_set(
                document,
                schema,
                variables,
                state,
                operation,
                document.child(selection, Role.SELECTION_SET),
                type,
            )
        selection = document.next_sibling(selection)


def extract_variables(
    mut document: Document, schema: Schema, mut variables: String
) raises:
    """Move each argument literal of the operations into a new variable:
    `extractVariables`.

    The variables are named `a`, `b`, and so on, after the names that the
    operation has. A literal equal to one already extracted for the same
    type reuses its variable. Directive arguments and arguments in fragment
    definitions stay.

    Args:
        document: The operation document.
        schema: The schema.
        variables: The variables JSON; it gets the extracted values.

    Raises:
        Error: `Unknown type "<name>".`, as the walker of upstream.
    """
    var state = _Extraction()
    var pending_1 = document.first_child(document.root)
    while pending_1 != NO_NODE:
        var operation = pending_1
        pending_1 = document.next_sibling(operation)
        if document.kind(operation) != Kind.OPERATION_DEFINITION:
            continue
        _extract_set(
            document,
            schema,
            variables,
            state,
            operation,
            document.child(operation, Role.SELECTION_SET),
            root_type(schema, document, operation),
        )


def _is_scalar_or_enum(schema: Schema, type: TypeRef) -> Bool:
    """Return True if the named type of a type is a scalar or an enum:
    `isScalarTypeOrExtension`."""
    if type.named < 0:
        return False
    var kind = schema.types[Int(type.named)].kind
    return kind == TypeKind.SCALAR or kind == TypeKind.ENUM


def _with(path: List[String], key: StringSlice) -> List[String]:
    """Return a path with one more key."""
    var out = path.copy()
    out.append(String(key))
    return out^


struct _Processing(Movable):
    """The state of the `variablesProcessing` stage."""

    var variables: String
    """The variables JSON."""
    var non_null: List[String]
    """The variables used where a non-null type is expected:
    `variablesNamesUsedInPositionsExpectingNonNullType`."""
    var with_defaults: List[Int]
    """The variable definitions that had a default value."""

    def __init__(out self, var variables: String):
        self.variables = variables^
        self.non_null = List[String]()
        self.with_defaults = List[Int]()


def _coerce_list(
    schema: Schema,
    mut state: _Processing,
    type: TypeRef,
    value: String,
    path: List[String],
):
    """`processTypeKindList`: wrap a value that is not an array in as many
    arrays as the type has lists."""
    var kind = json_kind(value)
    if kind == UInt8(ord("[")):
        _coerce_array(schema, state, unwrap(type), value, path)
        return
    if kind == UInt8(ord("n")):
        return
    var data = String()
    var depth = list_wraps(type)
    var count = 0
    while count < depth:
        data += "["
        count += 1
    data += value
    count = 0
    while count < depth:
        data += "]"
        count += 1
    state.variables = set_path(state.variables, path, data)
    _coerce_array(schema, state, unwrap(type), data, path)


def _coerce_array(
    schema: Schema,
    mut state: _Processing,
    item: TypeRef,
    value: String,
    path: List[String],
):
    """`walkJsonArray`: coerce each element of an array."""
    var index = 0
    for span in elements(value):
        var element = String(value[byte = span[0] : span[1]])
        var inner = _with(path, String(index))
        var type = list_or_name(item)
        if type.depth > 0:
            _coerce_list(schema, state, type, element, inner)
        else:
            _coerce_named(schema, state, type, element, inner)
        index += 1


def _coerce_named(
    schema: Schema,
    mut state: _Processing,
    type: TypeRef,
    value: String,
    path: List[String],
):
    """`processTypeKindNamed` and `walkJsonObject`: coerce each field of an
    input object."""
    if json_kind(value) != UInt8(ord("{")) or type.named < 0:
        return
    # A type that is not an input object has no input fields to match.
    var named = Int(type.named)
    for member in members(value):
        var key = member.key(value)
        var field = schema.input_field_named(named, key)
        if field < 0:
            continue
        var inner = _with(path, key)
        var field_type = list_or_name(schema.input_values[field].type)
        var element = String(member.value(value))
        if field_type.depth > 0:
            _coerce_list(schema, state, field_type, element, inner)
        else:
            _coerce_named(schema, state, field_type, element, inner)


def _coerce(
    schema: Schema,
    document: Document,
    mut state: _Processing,
    variable: Int,
):
    """`inputCoercionForListVisitor.EnterVariableDefinition`."""
    var name = document.name(document.child(variable, Role.VARIABLE))
    var index = top_level_member(state.variables, name)
    if index < 0:
        return
    var value = String(members(state.variables)[index].value(state.variables))
    var type = type_ref_of(
        schema, document, document.child(variable, Role.TYPE)
    )
    var path: List[String] = [String(name)]
    var resolved = list_or_name(type)
    if resolved.depth > 0:
        _coerce_list(schema, state, resolved, value, path)
    else:
        _coerce_named(schema, state, type, value, path)


def _extract_default(
    schema: Schema,
    mut document: Document,
    mut state: _Processing,
    variable: Int,
):
    """`variablesDefaultValueExtractionVisitor.EnterVariableDefinition`."""
    var default = document.child(variable, Role.DEFAULT_VALUE)
    if default == NO_NODE:
        return
    var name = String(document.name(document.child(variable, Role.VARIABLE)))
    var json = value_to_json(document, default, state.variables)
    remove_child(document, variable, default)
    state.with_defaults.append(variable)
    if top_level_member(state.variables, name) >= 0:
        return
    var type = type_ref_of(
        schema, document, document.child(variable, Role.TYPE)
    )
    if is_list(type) and not json.startswith("["):
        var count = list_wraps(type)
        while count > 0:
            json = "[" + json + "]"
            count -= 1
    state.variables = set_raw(state.variables, name, json)


def _default_json(schema: Schema, input: Int) -> String:
    """Return the default value of an input value of the schema as JSON."""
    var at = schema.input_values[input].default_value
    return value_to_json(
        schema.documents[Int(at.document)], Int(at.node), String()
    )


def _inject_fields(
    schema: Schema, type: Int, value: String
) -> Tuple[String, Bool]:
    """`recursiveInjectInputFields`: add the default of each missing field
    of an input object."""
    var out = value
    var replaced = False
    var span = schema.types[type].input_fields
    var input = Int(span.start)
    while input < span.end():
        ref definition = schema.input_values[input]
        var has_default = definition.default_value.exists()
        var index = top_level_member(value, definition.name)
        var exists = index >= 0
        if not _is_scalar_or_enum(schema, definition.type):
            if exists or has_default:
                var use = String(
                    members(value)[index].value(value)
                ) if exists else _default_json(schema, input)
                var result = _process_input(schema, definition.type, use)
                if not exists or result[1]:
                    out = jsonparser_set(out, definition.name, result[0])
                    replaced = True
        elif has_default and not exists:
            out = jsonparser_set(
                out, definition.name, _default_json(schema, input)
            )
            replaced = True
        input += 1
    return (out^, replaced)


def _process_input(
    schema: Schema, type: TypeRef, value: String
) -> Tuple[String, Bool]:
    """`processObjectOrListInput`: inject the defaults into an input object
    or a list of them."""
    if type.named < 0:
        return (value, False)
    # The callers leave out the scalars and the enums. An object, an
    # interface or a union has no input fields, so nothing is injected.
    var named = Int(type.named)
    var kind = json_kind(value)
    if kind == UInt8(ord("n")):
        return (value, True)
    var field_is_list = is_list(type)
    var value_is_list = kind == UInt8(ord("["))
    if field_is_list and value_is_list:
        var list = list_or_name(type)
        var list_of_list = is_list(unwrap(list))
        var out = value
        var replaced = False
        var index = 0
        for span in elements(value):
            var element = String(value[byte = span[0] : span[1]])
            var element_kind = json_kind(element)
            var result: Tuple[String, Bool]
            if list_of_list and element_kind == UInt8(ord("[")):
                result = _process_input(schema, unwrap(list), element)
            elif not list_of_list and element_kind == UInt8(ord("{")):
                result = _inject_fields(schema, named, element)
            else:
                continue
            if result[1]:
                out = set_path(out, [String(index)], result[0])
                replaced = True
            index += 1
        return (out^, replaced)
    if not field_is_list and not value_is_list:
        return _inject_fields(schema, named, value)
    return (value, False)


def _inject(
    schema: Schema, document: Document, mut state: _Processing, variable: Int
):
    """`inputFieldDefaultInjectionVisitor.EnterVariableDefinition`."""
    var name = document.name(document.child(variable, Role.VARIABLE))
    var index = top_level_member(state.variables, name)
    if index < 0:
        return
    var type = type_ref_of(
        schema, document, document.child(variable, Role.TYPE)
    )
    if _is_scalar_or_enum(schema, type):
        return
    var value = String(members(state.variables)[index].value(state.variables))
    var result = _process_input(schema, type, value)
    if result[1]:
        state.variables = jsonparser_set(state.variables, name, result[0])


def _traverse(
    schema: Schema,
    document: Document,
    mut state: _Processing,
    value: Int,
    type: TypeRef,
):
    """`traverseValue`: note each variable in a position of a non-null
    type."""
    var kind = document.kind(value)
    if kind == Kind.VARIABLE:
        if is_non_null(type):
            state.non_null.append(String(document.name(value)))
    elif kind == Kind.LIST:
        if not is_list(type):
            return
        var list = unwrap(type) if is_non_null(type) else type
        var item = document.first_child(value)
        while item != NO_NODE:
            if contains_variable(document, item):
                _traverse(schema, document, state, item, unwrap(list))
            item = document.next_sibling(item)
    else:
        # Only a variable, a list or an object holds a variable.
        var field = document.first_child(value)
        while field != NO_NODE:
            var input = schema.input_field_named(
                Int(type.named), document.name(field)
            )
            var inner = document.child(field, Role.VALUE)
            if input >= 0 and contains_variable(document, inner):
                _traverse(
                    schema,
                    document,
                    state,
                    inner,
                    schema.input_values[input].type,
                )
            field = document.next_sibling(field)


def _directive_positions(
    schema: Schema, document: Document, mut state: _Processing, node: Int
):
    """Note the variables of the directive arguments of a node."""
    for directive in document.children(node, Role.DIRECTIVE):
        var definition = schema.directive_named(document.name(directive))
        for argument in document.children(directive, Role.ARGUMENT):
            var value = document.child(argument, Role.VALUE)
            if definition < 0 or not contains_variable(document, value):
                continue
            var input = schema.directive_argument_named(
                definition, document.name(argument)
            )
            if input >= 0:
                _traverse(
                    schema,
                    document,
                    state,
                    value,
                    schema.input_values[input].type,
                )


def _positions(
    schema: Schema,
    document: Document,
    mut state: _Processing,
    selection_set: Int,
    enclosing: Int,
    in_operation: Bool,
) raises:
    """`EnterField` and `EnterArgument` of the default value extraction:
    note the variables in non-null positions under a selection set."""
    var selection = document.first_child(selection_set)
    while selection != NO_NODE:
        var kind = document.kind(selection)
        var type = enclosing
        if kind == Kind.FIELD:
            var definition = field_definition(
                schema, document, enclosing, selection
            )
            if definition >= 0:
                var span = schema.fields[definition].arguments
                var input = Int(span.start)
                while input < span.end():
                    for argument in document.children(selection, Role.ARGUMENT):
                        var value = document.child(argument, Role.VALUE)
                        if document.name(argument) == schema.input_values[
                            input
                        ].name and contains_variable(document, value):
                            _traverse(
                                schema,
                                document,
                                state,
                                value,
                                schema.input_values[input].type,
                            )
                            break
                    input += 1
            type = field_type(schema, document, enclosing, selection)
        elif kind == Kind.INLINE_FRAGMENT:
            type = type_condition(schema, document, selection, enclosing)
        if in_operation:
            _directive_positions(schema, document, state, selection)
        var inner = document.child(selection, Role.SELECTION_SET)
        if inner != NO_NODE:
            _positions(schema, document, state, inner, type, in_operation)
        selection = document.next_sibling(selection)


def _make_non_null(
    mut document: Document, schema: Schema, mut state: _Processing
):
    """`LeaveOperationDefinition`: make each variable with a default value
    non-null where a non-null type uses it."""
    for variable in state.with_defaults:
        var type = document.child(variable, Role.TYPE)
        if document.kind(type) == Kind.NON_NULL_TYPE:
            continue
        var name = String(
            document.name(document.child(variable, Role.VARIABLE))
        )
        var used = False
        for other in state.non_null:
            if other == name:
                used = True
        if not used:
            continue
        var previous = previous_sibling(document, variable, type)
        remove_child(document, variable, type)
        var wrapper = document.add(Kind.NON_NULL_TYPE, Role.TYPE)
        document.append_child(wrapper, type)
        insert_after(document, variable, previous, wrapper)


def _process(
    mut document: Document,
    schema: Schema,
    mut variables: String,
    coerce: Bool,
    defaults: Bool,
    inject: Bool,
) raises:
    """Run the enabled visitors of the `variablesProcessing` stage, in the
    order of their registration."""
    var state = _Processing(variables)
    var pending_2 = document.first_child(document.root)
    while pending_2 != NO_NODE:
        var definition = pending_2
        pending_2 = document.next_sibling(definition)
        var kind = document.kind(definition)
        if kind == Kind.OPERATION_DEFINITION:
            var type = root_type(schema, document, definition)
            for variable in document.children(
                definition, Role.VARIABLE_DEFINITION
            ):
                if coerce:
                    _coerce(schema, document, state, variable)
                if defaults:
                    _extract_default(schema, document, state, variable)
                if inject:
                    _inject(schema, document, state, variable)
            if defaults:
                for variable in document.children(
                    definition, Role.VARIABLE_DEFINITION
                ):
                    _directive_positions(schema, document, state, variable)
                _directive_positions(schema, document, state, definition)
                _positions(
                    schema,
                    document,
                    state,
                    document.child(definition, Role.SELECTION_SET),
                    type,
                    True,
                )
                _make_non_null(document, schema, state)
        elif defaults and kind == Kind.FRAGMENT_DEFINITION:
            _positions(
                schema,
                document,
                state,
                document.child(definition, Role.SELECTION_SET),
                type_condition(schema, document, definition, NO_TYPE),
                False,
            )
    variables = state.variables.copy()


def input_coercion_for_list(
    mut document: Document, schema: Schema, mut variables: String
) raises:
    """Wrap each variable value that is not a list, where the type is a list,
    in as many lists as the type has: `inputCoercionForList`.

    Fields of input objects in the values are coerced too.

    Args:
        document: The operation document.
        schema: The schema.
        variables: The variables JSON, edited in place.

    Raises:
        Error: `Unknown type "<name>".`, as the walker of upstream.
    """
    _process(document, schema, variables, True, False, False)


def extract_variables_default_value(
    mut document: Document, schema: Schema, mut variables: String
) raises:
    """Move the default value of each variable definition into the
    variables, unless the variables have a value: `extractVariablesDefaultValue`.

    A variable that had a default value and is used where a non-null type
    is expected becomes non-null.

    Args:
        document: The operation document.
        schema: The schema.
        variables: The variables JSON, edited in place.

    Raises:
        Error: `Unknown type "<name>".`, as the walker of upstream.
    """
    _process(document, schema, variables, False, True, False)


def inject_input_field_defaults(
    mut document: Document, schema: Schema, mut variables: String
) raises:
    """Add the default value of each input object field that a variable
    value does not have: `injectInputFieldDefaults`.

    Args:
        document: The operation document.
        schema: The schema.
        variables: The variables JSON, edited in place.

    Raises:
        Error: `Unknown type "<name>".`, as the walker of upstream.
    """
    _process(document, schema, variables, False, False, True)


def variables_processing(
    mut document: Document, schema: Schema, mut variables: String
) raises:
    """Run the list coercion, the default value extraction and the default
    injection on one walk, as the `variablesProcessing` stage does.

    Args:
        document: The operation document.
        schema: The schema.
        variables: The variables JSON, edited in place.

    Raises:
        Error: `Unknown type "<name>".`, as the walker of upstream.
    """
    _process(document, schema, variables, True, True, True)

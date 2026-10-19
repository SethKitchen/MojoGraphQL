# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The rules about directives, arguments and values.

Port of graphql-js 16.14.2 `validation/rules/KnownDirectivesRule.ts`,
`UniqueDirectivesPerLocationRule.ts`, `KnownArgumentNamesRule.ts`,
`UniqueArgumentNamesRule.ts`, `ValuesOfCorrectTypeRule.ts`,
`ProvidedRequiredArgumentsRule.ts` and `UniqueInputFieldNamesRule.ts`.

Each function is the handler of one rule for one node kind, and the walk of
`gql_validation.validate` calls it. A directive defined in the document
replaces a schema directive with the same name, as in graphql-js.

**Difference from graphql-js.** `ValuesOfCorrectTypeRule` checks a literal
of a built-in scalar or an enum type without coercing it when the literal
is plainly valid, such as a short `Int`. Otherwise it coerces the literal as
graphql-js `parseLiteral` does, and reports the same error.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_language.directive_location import DirectiveLocation
from gql_language.printer import print_node
from gql_schema.definition import NO_TYPE, Schema, TypeKind, TypeRef
from gql_language.names import NOT_FOUND, NameTable
from gql_schema.suggestions import did_you_mean, suggestion_list
from gql_schema.values import JsValues, parse_literal
from gql_validation.state import Walk
from gql_validation.type_info import (
    NO_ARGUMENT,
    NO_FIELD,
    SCHEMA_META_FIELD,
    TYPE_META_FIELD,
    TYPENAME_META_FIELD,
    has_default_value,
    is_defined,
)


def field_name(schema: Schema, field: Int) -> String:
    """Return the name of a field, meta fields included.

    Args:
        schema: The schema of the field.
        field: A field index, or a meta field.

    Returns:
        The name, such as `__typename`.
    """
    if field >= 0:
        return schema.fields[field].name
    if field == TYPENAME_META_FIELD:
        return String("__typename")
    if field == SCHEMA_META_FIELD:
        return String("__schema")
    return String("__type")


def _location_of(document: Document, applied: Int, owner: Int) -> Int:
    """Return graphql-js `getDirectiveLocationForASTPath`: the location of
    a directive on a node, given the node and the node above it."""
    var kind = document.kind(applied)
    if kind == Kind.OPERATION_DEFINITION:
        # QUERY, MUTATION and SUBSCRIPTION have the operation's index.
        return Int(document.operation(applied).value)
    if kind == Kind.FIELD:
        return Int(DirectiveLocation.FIELD.value)
    if kind == Kind.FRAGMENT_SPREAD:
        return Int(DirectiveLocation.FRAGMENT_SPREAD.value)
    if kind == Kind.INLINE_FRAGMENT:
        return Int(DirectiveLocation.INLINE_FRAGMENT.value)
    if kind == Kind.FRAGMENT_DEFINITION:
        return Int(DirectiveLocation.FRAGMENT_DEFINITION.value)
    if kind == Kind.VARIABLE_DEFINITION:
        return Int(DirectiveLocation.VARIABLE_DEFINITION.value)
    if kind == Kind.SCHEMA_DEFINITION or kind == Kind.SCHEMA_EXTENSION:
        return Int(DirectiveLocation.SCHEMA.value)
    if (
        kind == Kind.SCALAR_TYPE_DEFINITION
        or kind == Kind.SCALAR_TYPE_EXTENSION
    ):
        return Int(DirectiveLocation.SCALAR.value)
    if (
        kind == Kind.OBJECT_TYPE_DEFINITION
        or kind == Kind.OBJECT_TYPE_EXTENSION
    ):
        return Int(DirectiveLocation.OBJECT.value)
    if kind == Kind.FIELD_DEFINITION:
        return Int(DirectiveLocation.FIELD_DEFINITION.value)
    if (
        kind == Kind.INTERFACE_TYPE_DEFINITION
        or kind == Kind.INTERFACE_TYPE_EXTENSION
    ):
        return Int(DirectiveLocation.INTERFACE.value)
    if kind == Kind.UNION_TYPE_DEFINITION or kind == Kind.UNION_TYPE_EXTENSION:
        return Int(DirectiveLocation.UNION.value)
    if kind == Kind.ENUM_TYPE_DEFINITION or kind == Kind.ENUM_TYPE_EXTENSION:
        return Int(DirectiveLocation.ENUM.value)
    if kind == Kind.ENUM_VALUE_DEFINITION:
        return Int(DirectiveLocation.ENUM_VALUE.value)
    if (
        kind == Kind.INPUT_OBJECT_TYPE_DEFINITION
        or kind == Kind.INPUT_OBJECT_TYPE_EXTENSION
    ):
        return Int(DirectiveLocation.INPUT_OBJECT.value)
    if kind == Kind.INPUT_VALUE_DEFINITION:
        if document.kind(owner) == Kind.INPUT_OBJECT_TYPE_DEFINITION:
            return Int(DirectiveLocation.INPUT_FIELD_DEFINITION.value)
        return Int(DirectiveLocation.ARGUMENT_DEFINITION.value)
    return Int(DirectiveLocation.DIRECTIVE_DEFINITION.value)


def _doc_locations(document: Document, definition: Int) -> UInt32:
    """Return the location bits of a directive definition of the
    document."""
    var bits = UInt32(0)
    var location = document.child(definition, Role.LOCATION)
    while location != NO_NODE:
        var index = DirectiveLocation.from_name(document.text(location))
        bits |= UInt32(1) << UInt32(index)
        location = document.next_with_role(location)
    return bits


def known_directives(
    mut walk: Walk, schema: Schema, document: Document, node: Int
):
    """KnownDirectivesRule, on a `Directive`.

    Args:
        walk: The walk.
        schema: The schema.
        document: The document.
        node: The directive.
    """
    var name = document.name(node)
    var locations: UInt32
    var definition = walk.doc_directive(name)
    if definition != NO_NODE:
        locations = _doc_locations(document, definition)
    else:
        var directive = schema.directive_named(name)
        if directive == NO_TYPE:
            walk.ctx.report_error(
                document, 'Unknown directive "@' + String(name) + '".', node
            )
            return
        locations = schema.directives[directive].locations
    var depth = len(walk.ctx.path)
    var location = _location_of(
        document, walk.ctx.path[depth - 2], walk.ctx.path[depth - 3]
    )
    if locations & (UInt32(1) << UInt32(location)) == 0:
        walk.ctx.report_error(
            document,
            'Directive "@'
            + String(name)
            + '" may not be used on '
            + DirectiveLocation(UInt8(location)).text()
            + ".",
            node,
        )


def _is_unique_directive(
    walk: Walk, schema: Schema, document: Document, name: StringSlice
) -> Bool:
    """Return True for a known directive that is not repeatable."""
    var definition = walk.doc_directive(name)
    if definition != NO_NODE:
        return not document.is_repeatable(definition)
    var directive = schema.directive_named(name)
    return (
        directive != NO_TYPE and not schema.directives[directive].is_repeatable
    )


def unique_directives_per_location(
    mut walk: Walk, schema: Schema, document: Document, node: Int
):
    """UniqueDirectivesPerLocationRule, on a node that can have
    directives.

    Args:
        walk: The walk.
        schema: The schema.
        document: The document.
        node: The node.
    """
    var directive = document.child(node, Role.DIRECTIVE)
    if directive == NO_NODE:
        return
    var kind = document.kind(node)
    var owner = node
    if kind == Kind.SCHEMA_DEFINITION or kind == Kind.SCHEMA_EXTENSION:
        owner = -3
    elif kind.is_type_definition() or kind.is_type_extension():
        owner = -10 - 2 * _scope(walk, -1, document.name(node))
    elif kind == Kind.DIRECTIVE_DEFINITION or kind == Kind.DIRECTIVE_EXTENSION:
        owner = -11 - 2 * _scope(walk, -2, document.name(node))
    while directive != NO_NODE:
        var name = document.name(directive)
        if _is_unique_directive(walk, schema, document, name):
            var seen = walk.seen_directives.find_or_insert(
                owner, name, directive
            )
            if seen != NOT_FOUND:
                walk.ctx.report_error_nodes(
                    document,
                    'The directive "@'
                    + String(name)
                    + '" can only be used once at this location.',
                    [seen, directive],
                )
        directive = document.next_with_role(directive)


def _scope(mut walk: Walk, kind: Int, name: StringSlice) -> Int:
    """Return the id of a type or directive name's directive scope."""
    var id = walk.directive_scopes.__len__()
    var found = walk.directive_scopes.find_or_insert(kind, name, id)
    if found != NOT_FOUND:
        return found
    return id


def _doc_has_argument(
    document: Document, definition: Int, name: StringSlice
) -> Bool:
    """Return True if a directive definition of the document has an
    argument."""
    var argument = document.child(definition, Role.ARGUMENT)
    while argument != NO_NODE:
        if document.name(argument) == name:
            return True
        argument = document.next_with_role(argument)
    return False


def known_directive_arguments(
    mut walk: Walk, schema: Schema, document: Document, node: Int
):
    """KnownArgumentNamesRule, on a `Directive`.

    Args:
        walk: The walk.
        schema: The schema.
        document: The document.
        node: The directive.
    """
    var argument = document.child(node, Role.ARGUMENT)
    if argument == NO_NODE:
        return
    var name = document.name(node)
    var definition = walk.doc_directive(name)
    var directive = NO_TYPE
    if definition == NO_NODE:
        directive = schema.directive_named(name)
        if directive == NO_TYPE:
            return
    while argument != NO_NODE:
        var argument_name = document.name(argument)
        var known: Bool
        if definition != NO_NODE:
            known = _doc_has_argument(document, definition, argument_name)
        else:
            known = (
                schema.directive_argument_named(directive, argument_name)
                != NO_TYPE
            )
        if not known:
            var names = List[String]()
            if definition != NO_NODE:
                var item = document.child(definition, Role.ARGUMENT)
                while item != NO_NODE:
                    names.append(String(document.name(item)))
                    item = document.next_with_role(item)
            else:
                ref span = schema.directives[directive].arguments
                for index in range(Int(span.start), span.end()):
                    names.append(schema.input_values[index].name)
            walk.ctx.report_error(
                document,
                'Unknown argument "'
                + String(argument_name)
                + '" on directive "@'
                + String(name)
                + '".'
                + did_you_mean(suggestion_list(argument_name, names)),
                argument,
            )
        argument = document.next_with_role(argument)


def _field_argument_names(schema: Schema, field: Int) -> List[String]:
    """Return the argument names of a field, meta fields included."""
    var names = List[String]()
    if field >= 0:
        ref span = schema.fields[field].arguments
        for index in range(Int(span.start), span.end()):
            names.append(schema.input_values[index].name)
    elif field == TYPE_META_FIELD:
        names.append(String("name"))
    return names^


def known_argument_names(
    mut walk: Walk, schema: Schema, document: Document, node: Int
):
    """KnownArgumentNamesRule, on an `Argument`.

    The rule skips the arguments of a directive, as graphql-js does when
    its `Directive` handler returns `false`.

    Args:
        walk: The walk.
        schema: The schema.
        document: The document.
        node: The argument.
    """
    if document.kind(walk.parent()) == Kind.DIRECTIVE:
        return
    var field = walk.ctx.type_info.get_field_def()
    # `TypeInfo` finds a field only in a parent type, so a known field has
    # a parent type: the graphql-js `parentType` test is always True here.
    var parent = walk.ctx.type_info.get_parent_type()
    if walk.ctx.type_info.get_argument() != NO_ARGUMENT or field == NO_FIELD:
        return
    var name = document.name(node)
    walk.ctx.report_error(
        document,
        'Unknown argument "'
        + String(name)
        + '" on field "'
        + schema.types[parent].name
        + "."
        + field_name(schema, field)
        + '".'
        + did_you_mean(
            suggestion_list(name, _field_argument_names(schema, field))
        ),
        node,
    )


comptime _SCAN_LIMIT = 8
"""Up to this many arguments, `unique_argument_names` compares each pair
instead of building a table."""


def unique_argument_names(mut walk: Walk, document: Document, node: Int):
    """UniqueArgumentNamesRule, on a `Field` or a `Directive`.

    Args:
        walk: The walk.
        document: The document.
        node: The field or directive.
    """
    var first = document.child(node, Role.ARGUMENT)
    if first == NO_NODE:
        return
    var arguments = List[Int]()
    var current = first
    while current != NO_NODE:
        arguments.append(current)
        current = document.next_with_role(current)
    var count = len(arguments)
    if count < 2:
        return
    var groups = List[List[Int]]()
    # `while` loops: each loop below has at least one iteration.
    if count <= _SCAN_LIMIT:
        var index = 0
        while index < count:
            var name = document.name(arguments[index])
            var earlier = False
            for before in range(index):
                if document.name(arguments[before]) == name:
                    earlier = True
            if not earlier:
                var group: List[Int] = [
                    document.child(arguments[index], Role.NAME)
                ]
                for after in range(index + 1, count):
                    if document.name(arguments[after]) == name:
                        group.append(
                            document.child(arguments[after], Role.NAME)
                        )
                groups.append(group^)
            index += 1
    else:
        var table = NameTable(capacity=count)
        var index = 0
        while index < count:
            var name = document.child(arguments[index], Role.NAME)
            var group = table.find_or_insert(
                -1, document.text(name), len(groups)
            )
            if group == NOT_FOUND:
                groups.append([name])
            else:
                groups[group].append(name)
            index += 1
    var at = 0
    while at < len(groups):
        ref group = groups[at]
        if len(group) > 1:
            walk.ctx.report_error_nodes(
                document,
                'There can be only one argument named "'
                + String(document.text(group[0]))
                + '".',
                group,
            )
        at += 1


def _is_provided(document: Document, node: Int, name: StringSlice) -> Bool:
    """Return True if a field or directive node has an argument."""
    var argument = document.child(node, Role.ARGUMENT)
    while argument != NO_NODE:
        if document.name(argument) == name:
            return True
        argument = document.next_with_role(argument)
    return False


def provided_directive_arguments(
    mut walk: Walk, schema: Schema, document: Document, node: Int
) raises:
    """ProvidedRequiredArgumentsRule, on exit from a `Directive`.

    Args:
        walk: The walk.
        schema: The schema.
        document: The document.
        node: The directive.

    Raises:
        Error: When a default value reaches an output type.
    """
    var name = document.name(node)
    var definition = walk.doc_directive(name)
    if definition != NO_NODE:
        _provided_doc_arguments(walk, document, node, definition)
        return
    var directive = schema.directive_named(name)
    if directive == NO_TYPE:
        return
    ref span = schema.directives[directive].arguments
    for index in range(Int(span.start), span.end()):
        ref argument = schema.input_values[index]
        if not argument.type.is_non_null() or has_default_value(schema, index):
            continue
        if _is_provided(document, node, argument.name):
            continue
        walk.ctx.report_error(
            document,
            'Directive "@'
            + String(name)
            + '" argument "'
            + argument.name
            + '" of type "'
            + schema.type_name(argument.type)
            + '" is required, but it was not provided.',
            node,
        )


def _provided_doc_arguments(
    mut walk: Walk, document: Document, node: Int, definition: Int
):
    """ProvidedRequiredArgumentsRule for a directive that the document
    defines: each argument with a non-null type and no default value."""
    var required = List[Int]()
    var argument = document.child(definition, Role.ARGUMENT)
    while argument != NO_NODE:
        var type = document.child(argument, Role.TYPE)
        if (
            document.kind(type) == Kind.NON_NULL_TYPE
            and document.child(argument, Role.DEFAULT_VALUE) == NO_NODE
        ):
            # graphql-js `keyMap`: the first position, the last node.
            var name = document.name(argument)
            var at = 0
            while at < len(required) and document.name(required[at]) != name:
                at += 1
            if at == len(required):
                required.append(argument)
            else:
                required[at] = argument
        argument = document.next_with_role(argument)
    for item in required:
        var name = document.name(item)
        if _is_provided(document, node, name):
            continue
        walk.ctx.report_error(
            document,
            'Directive "@'
            + String(document.name(node))
            + '" argument "'
            + String(name)
            + '" of type "'
            + print_node(document, document.child(item, Role.TYPE))
            + '" is required, but it was not provided.',
            node,
        )


def provided_field_arguments(
    mut walk: Walk, schema: Schema, document: Document, node: Int
) raises:
    """ProvidedRequiredArgumentsRule, on exit from a `Field`.

    Args:
        walk: The walk.
        schema: The schema.
        document: The document.
        node: The field.

    Raises:
        Error: When a default value reaches an output type.
    """
    var field = walk.ctx.type_info.get_field_def()
    if field == NO_FIELD:
        return
    if field < 0:
        if field == TYPE_META_FIELD and not _is_provided(
            document, node, "name"
        ):
            walk.ctx.report_error(
                document,
                (
                    'Field "__type" argument "name" of type "String!" is'
                    " required, but it was not provided."
                ),
                node,
            )
        return
    ref span = schema.fields[field].arguments
    for index in range(Int(span.start), span.end()):
        ref argument = schema.input_values[index]
        if not argument.type.is_non_null() or has_default_value(schema, index):
            continue
        if _is_provided(document, node, argument.name):
            continue
        walk.ctx.report_error(
            document,
            'Field "'
            + schema.fields[field].name
            + '" argument "'
            + argument.name
            + '" of type "'
            + schema.type_name(argument.type)
            + '" is required, but it was not provided.',
            node,
        )


# --- ValuesOfCorrectTypeRule ------------------------------------------------


def _expected(
    mut walk: Walk,
    schema: Schema,
    document: Document,
    node: Int,
    type: TypeRef,
):
    """Report `Expected value of type "T", found <value>.`"""
    walk.ctx.report_error(
        document,
        'Expected value of type "'
        + schema.type_name(type)
        + '", found '
        + print_node(document, node)
        + ".",
        node,
    )


def _plainly_valid(
    schema: Schema, document: Document, node: Int, type: Int
) -> Bool:
    """Return True for a literal that a built-in scalar or an enum type
    takes for certain, so that no coercion is needed."""
    ref named = schema.types[type]
    var kind = document.kind(node)
    if named.kind == TypeKind.ENUM:
        return (
            kind == Kind.ENUM
            and schema.enum_value_named(type, document.text(node)) != NO_TYPE
        )
    if not named.is_builtin:
        # A custom scalar takes any literal, as `valueFromASTUntyped`.
        return True
    if named.name == "String":
        return kind == Kind.STRING
    if named.name == "Boolean":
        return kind == Kind.BOOLEAN
    if named.name == "Float":
        return kind == Kind.INT or kind == Kind.FLOAT
    if named.name == "ID":
        return kind == Kind.STRING or kind == Kind.INT
    # Int: a literal in the 32-bit range.
    return kind == Kind.INT and _fits_int32(document.text(node))


def _fits_int32(text: StringSlice) -> Bool:
    """Return True if the text of an `IntValue` is in the 32-bit range, as
    graphql-js `parseInt` and its range check decide."""
    var bytes = text.as_bytes()
    var negative = bytes[0] == 45
    var digits = len(bytes) - 1 if negative else len(bytes)
    if digits <= 9:
        return True
    if digits > 10:
        return False
    var value = 0
    var index = len(bytes) - 10
    while index < len(bytes):
        value = value * 10 + Int(bytes[index]) - 48
        index += 1
    return value <= (2147483648 if negative else 2147483647)


def is_valid_value_node(
    mut walk: Walk, schema: Schema, document: Document, node: Int
):
    """ValuesOfCorrectTypeRule `isValidValueNode`: check a literal against
    the input type of its position.

    Args:
        walk: The walk.
        schema: The schema.
        document: The document.
        node: The literal.
    """
    var location_type = walk.ctx.type_info.get_input_type()
    if not is_defined(location_type):
        return
    var type = Int(location_type.named)
    if not schema.types[type].kind.is_leaf():
        _expected(walk, schema, document, node, location_type)
        return
    if _plainly_valid(schema, document, node, type):
        return
    ref named = schema.types[type]
    if (
        named.is_builtin
        and named.name == "Int"
        and document.kind(node) == Kind.INT
    ):
        # graphql-js reads a long literal as a large number. The message is
        # made here, because `parse_literal` cannot read 20 or more digits.
        walk.ctx.report_error(
            document,
            "Int cannot represent non 32-bit signed integer value: "
            + String(document.text(node)),
            node,
        )
        return
    var values = JsValues()
    try:
        _ = parse_literal(schema, document, node, type, values)
    except error:
        walk.ctx.keep_error(error^)


def list_value(
    mut walk: Walk, schema: Schema, document: Document, node: Int
) -> Bool:
    """ValuesOfCorrectTypeRule, on a `ListValue`.

    Args:
        walk: The walk.
        schema: The schema.
        document: The document.
        node: The list.

    Returns:
        True when the rule skips the list's items, as graphql-js
        `return false`.
    """
    if walk.ctx.type_info.get_parent_input_type().nullable().is_list():
        return False
    is_valid_value_node(walk, schema, document, node)
    return True


def object_value(
    mut walk: Walk, schema: Schema, document: Document, node: Int
) raises -> Bool:
    """ValuesOfCorrectTypeRule, on an `ObjectValue`.

    Args:
        walk: The walk.
        schema: The schema.
        document: The document.
        node: The object.

    Returns:
        True when the rule skips the object's fields, as graphql-js
        `return false`.

    Raises:
        Error: When a default value reaches an output type.
    """
    var type = Int(walk.ctx.type_info.get_input_type().named)
    if type < 0 or schema.types[type].kind != TypeKind.INPUT_OBJECT:
        is_valid_value_node(walk, schema, document, node)
        return True
    ref named = schema.types[type]
    # A `while` loop: a valid schema has no input object without fields.
    var index = Int(named.input_fields.start)
    while index < named.input_fields.end():
        ref field = schema.input_values[index]
        if (
            field.type.is_non_null()
            and not has_default_value(schema, index)
            and _object_field(document, node, field.name) == NO_NODE
        ):
            walk.ctx.report_error(
                document,
                'Field "'
                + named.name
                + "."
                + field.name
                + '" of required type "'
                + schema.type_name(field.type)
                + '" was not provided.',
                node,
            )
        index += 1
    if named.is_one_of:
        _one_of(walk, document, node, named.name)
    return False


def _object_field(document: Document, node: Int, name: StringSlice) -> Int:
    """Return the last field of an object value with a name, as graphql-js
    `keyMap` keeps it, or `NO_NODE`."""
    var found = NO_NODE
    var field = document.child(node, Role.FIELD)
    while field != NO_NODE:
        if document.name(field) == name:
            found = field
        field = document.next_with_role(field)
    return found


def _one_of(mut walk: Walk, document: Document, node: Int, type: String):
    """ValuesOfCorrectTypeRule `validateOneOfInputObject`."""
    var first = document.child(node, Role.FIELD)
    var single = first != NO_NODE
    var field = first
    while single and field != NO_NODE:
        if document.name(field) != document.name(first):
            single = False
        field = document.next_with_role(field)
    if not single:
        walk.ctx.report_error(
            document,
            'OneOf Input Object "' + type + '" must specify exactly one key.',
            node,
        )
        return
    var name = document.name(first)
    var value = document.child(_object_field(document, node, name), Role.VALUE)
    if document.kind(value) == Kind.NULL:
        walk.ctx.report_error(
            document,
            'Field "' + type + "." + String(name) + '" must be non-null.',
            node,
        )


def object_field(mut walk: Walk, schema: Schema, document: Document, node: Int):
    """ValuesOfCorrectTypeRule, on an `ObjectField`.

    Args:
        walk: The walk.
        schema: The schema.
        document: The document.
        node: The object field.
    """
    if is_defined(walk.ctx.type_info.get_input_type()):
        return
    # `object_value` skips the fields of an object that is not in an input
    # object position, so the parent type here is always an input object:
    # the graphql-js `isInputObjectType(parentType)` test is always True.
    var parent = Int(walk.ctx.type_info.get_parent_input_type().named)
    var name = document.name(node)
    var names = List[String]()
    ref named = schema.types[parent]
    # A `while` loop: a valid schema has no input object without fields.
    var index = Int(named.input_fields.start)
    while index < named.input_fields.end():
        names.append(schema.input_values[index].name)
        index += 1
    walk.ctx.report_error(
        document,
        'Field "'
        + String(name)
        + '" is not defined by type "'
        + named.name
        + '".'
        + did_you_mean(suggestion_list(name, names)),
        node,
    )


def null_value(mut walk: Walk, schema: Schema, document: Document, node: Int):
    """ValuesOfCorrectTypeRule, on a `NullValue`.

    Args:
        walk: The walk.
        schema: The schema.
        document: The document.
        node: The null literal.
    """
    var type = walk.ctx.type_info.get_input_type()
    if type.is_non_null():
        _expected(walk, schema, document, node, type)


def unique_input_field_names(mut walk: Walk, document: Document, node: Int):
    """UniqueInputFieldNamesRule, on an `ObjectField`.

    Args:
        walk: The walk.
        document: The document.
        node: The object field.
    """
    var name = document.child(node, Role.NAME)
    var text = document.text(name)
    var known = walk.input_field_names.find_or_insert(walk.parent(), text, name)
    if known != NOT_FOUND:
        walk.ctx.report_error_nodes(
            document,
            'There can be only one input field named "' + String(text) + '".',
            [known, name],
        )

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The rules about definitions, operations and variables.

Port of graphql-js 16.14.2 `validation/rules/ExecutableDefinitionsRule.ts`,
`UniqueOperationNamesRule.ts`, `LoneAnonymousOperationRule.ts`,
`SingleFieldSubscriptionsRule.ts` (with the `collectFields` of
`execution/collectFields.ts` and the `@skip` and `@include` arguments of
`execution/values.ts`), `VariablesAreInputTypesRule.ts`,
`UniqueVariableNamesRule.ts`, `NoUndefinedVariablesRule.ts`,
`NoUnusedVariablesRule.ts` and `VariablesInAllowedPositionRule.ts`.

Each function is the handler of one rule for one node kind, and the walk of
`gql_validation.validate` calls it.

**Difference from graphql-js.** `SingleFieldSubscriptionsRule` evaluates
`@skip` and `@include` with no variable values, as graphql-js does. When
graphql-js throws there, for a missing or invalid `if` argument, `validate`
raises an `Error` with the same message; the error has no location.
"""

from gql_language.ast import NO_NODE, Document, Kind, OperationType, Role
from gql_language.printer import print_node
from gql_schema.definition import NO_TYPE, Schema, TypeKind, TypeRef
from gql_language.names import NOT_FOUND, NameTable
from gql_schema.type_comparators import is_type_sub_type_of
from gql_validation.state import Walk
from gql_validation.type_info import (
    has_default_value,
    is_defined,
    type_from_ast,
)


def executable_definitions(mut walk: Walk, document: Document):
    """ExecutableDefinitionsRule, on the `Document`.

    Args:
        walk: The walk.
        document: The document.
    """
    var current = document.first_child(document.root)
    while current != NO_NODE:
        var kind = document.kind(current)
        if not kind.is_executable_definition():
            var name: String
            if kind == Kind.SCHEMA_DEFINITION or kind == Kind.SCHEMA_EXTENSION:
                name = "schema"
            else:
                name = '"' + String(document.name(current)) + '"'
            walk.ctx.report_error(
                document,
                "The " + name + " definition is not executable.",
                current,
            )
        current = document.next_sibling(current)


def unique_operation_names(mut walk: Walk, document: Document, node: Int):
    """UniqueOperationNamesRule, on an `OperationDefinition`.

    Args:
        walk: The walk.
        document: The document.
        node: The operation.
    """
    var name = document.child(node, Role.NAME)
    if name == NO_NODE:
        return
    var text = document.text(name)
    var known = walk.operation_names.find_or_insert(-1, text, name)
    if known != NOT_FOUND:
        walk.ctx.report_error_nodes(
            document,
            'There can be only one operation named "' + String(text) + '".',
            [known, name],
        )


def count_operations(mut walk: Walk, document: Document):
    """LoneAnonymousOperationRule, on the `Document`.

    Args:
        walk: The walk.
        document: The document.
    """
    var count = 0
    var current = document.first_child(document.root)
    while current != NO_NODE:
        if document.kind(current) == Kind.OPERATION_DEFINITION:
            count += 1
        current = document.next_sibling(current)
    walk.operation_count = count


def lone_anonymous_operation(mut walk: Walk, document: Document, node: Int):
    """LoneAnonymousOperationRule, on an `OperationDefinition`.

    Args:
        walk: The walk.
        document: The document.
        node: The operation.
    """
    if document.child(node, Role.NAME) == NO_NODE and walk.operation_count > 1:
        walk.ctx.report_error(
            document,
            "This anonymous operation must be the only defined operation.",
            node,
        )


# --- SingleFieldSubscriptionsRule -------------------------------------------


struct _Collected(Movable):
    """The fields of `collectFields`, grouped by response key in the order
    of the first field of each group."""

    var keys: NameTable
    var groups: List[List[Int]]
    var visited: NameTable

    def __init__(out self):
        self.keys = NameTable()
        self.groups = List[List[Int]]()
        self.visited = NameTable()


def _if_argument(document: Document, directive: Int) raises -> Bool:
    """Return the `if` argument of `@skip` or `@include`, as graphql-js
    `getDirectiveValues` gives it with no variable values."""
    var value = NO_NODE
    var argument = document.child(directive, Role.ARGUMENT)
    while argument != NO_NODE:
        if document.name(argument) == "if":
            value = document.child(argument, Role.VALUE)
        argument = document.next_with_role(argument)
    if value == NO_NODE:
        raise Error(
            'Argument "if" of required type "Boolean!" was not provided.'
        )
    var kind = document.kind(value)
    if kind == Kind.VARIABLE:
        raise Error(
            'Argument "if" of required type "Boolean!" was provided the'
            ' variable "$'
            + String(document.name(value))
            + '" which was not provided a runtime value.'
        )
    if kind == Kind.NULL:
        raise Error(
            'Argument "if" of non-null type "Boolean!" must not be null.'
        )
    if kind != Kind.BOOLEAN:
        raise Error(
            'Argument "if" has invalid value '
            + print_node(document, value)
            + "."
        )
    return document.boolean_value(value)


def _should_include(document: Document, node: Int) raises -> Bool:
    """Return graphql-js `shouldIncludeNode` with no variable values."""
    var skip = NO_NODE
    var include = NO_NODE
    var directive = document.child(node, Role.DIRECTIVE)
    while directive != NO_NODE:
        var name = document.name(directive)
        if name == "skip" and skip == NO_NODE:
            skip = directive
        elif name == "include" and include == NO_NODE:
            include = directive
        directive = document.next_with_role(directive)
    if skip != NO_NODE and _if_argument(document, skip):
        return False
    if include != NO_NODE and not _if_argument(document, include):
        return False
    return True


def _condition_matches(
    schema: Schema, document: Document, fragment: Int, type: Int
) -> Bool:
    """Return graphql-js `doesFragmentConditionMatch`."""
    var condition = document.child(fragment, Role.TYPE_CONDITION)
    if condition == NO_NODE:
        return True
    var conditional = Int(type_from_ast(schema, document, condition).named)
    if conditional == type:
        return True
    if conditional >= 0 and schema.types[conditional].kind.is_abstract():
        return schema.is_sub_type(conditional, type)
    return False


def _collect_fields(
    mut walk: Walk,
    schema: Schema,
    document: Document,
    type: Int,
    selection_set: Int,
    mut out: _Collected,
) raises:
    """Group the fields of a selection set by response key, as graphql-js
    `collectFieldsImpl`."""
    var selection = document.child(selection_set, Role.SELECTION)
    while selection != NO_NODE:
        var kind = document.kind(selection)
        if kind == Kind.FIELD:
            if _should_include(document, selection):
                var key = document.child(selection, Role.ALIAS)
                if key == NO_NODE:
                    key = document.child(selection, Role.NAME)
                var group = out.keys.find_or_insert(
                    -1, document.text(key), len(out.groups)
                )
                if group == NOT_FOUND:
                    out.groups.append([selection])
                else:
                    out.groups[group].append(selection)
        elif kind == Kind.INLINE_FRAGMENT:
            if _should_include(document, selection) and _condition_matches(
                schema, document, selection, type
            ):
                _collect_fields(
                    walk,
                    schema,
                    document,
                    type,
                    document.child(selection, Role.SELECTION_SET),
                    out,
                )
        else:
            var name = document.name(selection)
            if out.visited.find(-1, name) == NOT_FOUND and _should_include(
                document, selection
            ):
                _ = out.visited.insert(-1, name, 0)
                var fragment = walk.ctx.get_fragment(document, name)
                if fragment != NO_NODE and _condition_matches(
                    schema, document, fragment, type
                ):
                    _collect_fields(
                        walk,
                        schema,
                        document,
                        type,
                        document.child(fragment, Role.SELECTION_SET),
                        out,
                    )
        selection = document.next_with_role(selection)


def single_field_subscriptions(
    mut walk: Walk, schema: Schema, document: Document, node: Int
) raises:
    """SingleFieldSubscriptionsRule, on an `OperationDefinition`.

    Args:
        walk: The walk.
        schema: The schema.
        document: The document.
        node: The operation.

    Raises:
        Error: When `@skip` or `@include` has a missing or invalid `if`.
    """
    if document.operation(node) != OperationType.SUBSCRIPTION:
        return
    var subscription = Int(schema.subscription_type)
    if subscription == NO_TYPE:
        return
    var name = document.child(node, Role.NAME)
    var fields = _Collected()
    _collect_fields(
        walk,
        schema,
        document,
        subscription,
        document.child(node, Role.SELECTION_SET),
        fields,
    )
    if len(fields.groups) > 1:
        var extra = List[Int]()
        var index = 1
        while index < len(fields.groups):
            extra.extend(Span(fields.groups[index]))
            index += 1
        var message: String
        if name != NO_NODE:
            message = (
                'Subscription "'
                + String(document.text(name))
                + '" must select only one top level field.'
            )
        else:
            message = (
                "Anonymous Subscription must select only one top level field."
            )
        walk.ctx.report_error_nodes(document, message, extra)
    for ref group in fields.groups:
        if document.name(group[0]).startswith("__"):
            var message: String
            if name != NO_NODE:
                message = (
                    'Subscription "'
                    + String(document.text(name))
                    + '" must not select an introspection top level field.'
                )
            else:
                message = (
                    "Anonymous Subscription must not select an introspection"
                    " top level field."
                )
            walk.ctx.report_error_nodes(document, message, group)


# --- variables --------------------------------------------------------------


def variables_are_input_types(
    mut walk: Walk, schema: Schema, document: Document, node: Int
):
    """VariablesAreInputTypesRule, on a `VariableDefinition`.

    Args:
        walk: The walk.
        schema: The schema.
        document: The document.
        node: The variable definition.
    """
    var type_node = document.child(node, Role.TYPE)
    var type = type_from_ast(schema, document, type_node)
    if is_defined(type) and not schema.types[Int(type.named)].kind.is_input():
        var variable = document.child(node, Role.VARIABLE)
        walk.ctx.report_error(
            document,
            'Variable "$'
            + String(document.name(variable))
            + '" cannot be non-input type "'
            + print_node(document, type_node)
            + '".',
            type_node,
        )


def unique_variable_names(mut walk: Walk, document: Document, node: Int):
    """UniqueVariableNamesRule, on an `OperationDefinition`.

    Args:
        walk: The walk.
        document: The document.
        node: The operation.
    """
    var definition = document.child(node, Role.VARIABLE_DEFINITION)
    if definition == NO_NODE:
        return
    var groups = NameTable()
    var names = List[List[Int]]()
    while definition != NO_NODE:
        var name = document.child(
            document.child(definition, Role.VARIABLE), Role.NAME
        )
        var group = groups.find_or_insert(-1, document.text(name), len(names))
        if group == NOT_FOUND:
            names.append([name])
        else:
            names[group].append(name)
        definition = document.next_with_role(definition)
    # The operation has a variable definition, so `names` is not empty.
    var at = 0
    while at < len(names):
        ref group = names[at]
        at += 1
        if len(group) > 1:
            walk.ctx.report_error_nodes(
                document,
                'There can be only one variable named "$'
                + String(document.text(group[0]))
                + '".',
                group,
            )


def _variable_name(
    document: Document, definition: Int
) -> StringSlice[origin_of(document.source.bytes)]:
    """Return the name of the variable of a variable definition."""
    return document.name(document.child(definition, Role.VARIABLE))


def define_variable(mut walk: Walk, document: Document, node: Int):
    """NoUndefinedVariablesRule, on a `VariableDefinition`.

    Args:
        walk: The walk.
        document: The document.
        node: The variable definition.
    """
    walk.defined_variables.assign(
        walk.definition(), _variable_name(document, node), 0
    )


def no_undefined_variables(
    mut walk: Walk, schema: Schema, document: Document, node: Int
):
    """NoUndefinedVariablesRule, on exit from an `OperationDefinition`.

    Args:
        walk: The walk.
        schema: The schema.
        document: The document.
        node: The operation.
    """
    var slot = walk.ctx.recursive_usages_index(schema, document, node)
    var name = document.child(node, Role.NAME)
    var index = 0
    while index < len(walk.ctx._recursive_lists[slot]):
        var usage = walk.ctx._recursive_lists[slot][index].node
        index += 1
        var variable = document.name(usage)
        if walk.defined_variables.find(node, variable) != NOT_FOUND:
            continue
        var message = 'Variable "$' + String(variable) + '" is not defined'
        if name != NO_NODE:
            message += ' by operation "' + String(document.text(name)) + '"'
        walk.ctx.report_error_nodes(document, message + ".", [usage, node])


def start_operation_variables(mut walk: Walk):
    """NoUnusedVariablesRule, on entry to an `OperationDefinition`.

    Args:
        walk: The walk.
    """
    walk.variable_defs.clear()


def add_variable_definition(mut walk: Walk, node: Int):
    """NoUnusedVariablesRule, on a `VariableDefinition`.

    Args:
        walk: The walk.
        node: The variable definition.
    """
    walk.variable_defs.append(node)


def no_unused_variables(
    mut walk: Walk, schema: Schema, document: Document, node: Int
):
    """NoUnusedVariablesRule, on exit from an `OperationDefinition`.

    Args:
        walk: The walk.
        schema: The schema.
        document: The document.
        node: The operation.
    """
    if len(walk.variable_defs) == 0:
        return
    var slot = walk.ctx.recursive_usages_index(schema, document, node)
    for ref usage in walk.ctx._recursive_lists[slot]:
        walk.used_variables.assign(node, document.name(usage.node), 0)
    var name = document.child(node, Role.NAME)
    var index = 0
    while index < len(walk.variable_defs):
        var definition = walk.variable_defs[index]
        index += 1
        var variable = _variable_name(document, definition)
        if walk.used_variables.find(node, variable) != NOT_FOUND:
            continue
        var message = 'Variable "$' + String(variable) + '" is never used'
        if name != NO_NODE:
            message += ' in operation "' + String(document.text(name)) + '"'
        walk.ctx.report_error(document, message + ".", definition)


def remember_variable_definition(mut walk: Walk, document: Document, node: Int):
    """VariablesInAllowedPositionRule, on a `VariableDefinition`.

    Args:
        walk: The walk.
        document: The document.
        node: The variable definition.
    """
    walk.variable_def_nodes.assign(
        walk.definition(), _variable_name(document, node), node
    )


def _allowed_variable_usage(
    schema: Schema,
    var_type: TypeRef,
    var_default: Int,
    var_default_kind: Kind,
    location_type: TypeRef,
    location_default: Int,
) raises -> Bool:
    """Return graphql-js `allowedVariableUsage`."""
    if location_type.is_non_null() and not var_type.is_non_null():
        var has_non_null_default = (
            var_default != NO_NODE and var_default_kind != Kind.NULL
        )
        if not has_non_null_default and not has_default_value(
            schema, location_default
        ):
            return False
        return is_type_sub_type_of(schema, var_type, location_type.of_type())
    return is_type_sub_type_of(schema, var_type, location_type)


def variables_in_allowed_position(
    mut walk: Walk, schema: Schema, document: Document, node: Int
) raises:
    """VariablesInAllowedPositionRule, on exit from an
    `OperationDefinition`.

    Args:
        walk: The walk.
        schema: The schema.
        document: The document.
        node: The operation.

    Raises:
        Error: When a default value reaches an output type.
    """
    var slot = walk.ctx.recursive_usages_index(schema, document, node)
    var index = 0
    while index < len(walk.ctx._recursive_lists[slot]):
        var usage = walk.ctx._recursive_lists[slot][index]
        index += 1
        var variable = document.name(usage.node)
        var definition = walk.variable_def_nodes.find(node, variable)
        if definition == NOT_FOUND or not is_defined(usage.type):
            continue
        var var_type = type_from_ast(
            schema, document, document.child(definition, Role.TYPE)
        )
        if not is_defined(var_type):
            continue
        var default = document.child(definition, Role.DEFAULT_VALUE)
        var default_kind = Kind.NULL
        if default != NO_NODE:
            default_kind = document.kind(default)
        if not _allowed_variable_usage(
            schema,
            var_type,
            default,
            default_kind,
            usage.type,
            usage.default_value,
        ):
            walk.ctx.report_error_nodes(
                document,
                'Variable "$'
                + String(variable)
                + '" of type "'
                + schema.type_name(var_type)
                + '" used in position expecting type "'
                + schema.type_name(usage.type)
                + '".',
                [definition, usage.node],
            )
        var parent = usage.parent_type
        if (
            is_defined(parent)
            and not parent.is_wrapped()
            and schema.types[Int(parent.named)].kind == TypeKind.INPUT_OBJECT
            and schema.types[Int(parent.named)].is_one_of
            and not var_type.is_non_null()
        ):
            walk.ctx.report_error_nodes(
                document,
                'Variable "$'
                + String(variable)
                + '" is of type "'
                + schema.type_name(var_type)
                + '" but must be non-nullable to be used for OneOf Input'
                ' Object "'
                + schema.types[Int(parent.named)].name
                + '".',
                [definition, usage.node],
            )

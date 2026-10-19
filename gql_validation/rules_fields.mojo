# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The rules about types and fields.

Port of graphql-js 16.14.2 `validation/rules/KnownTypeNamesRule.ts`,
`ScalarLeafsRule.ts`, `FieldsOnCorrectTypeRule.ts`,
`MaxIntrospectionDepthRule.ts`, and the custom rules
`custom/NoDeprecatedCustomRule.ts` and
`custom/NoSchemaIntrospectionCustomRule.ts`.

Each function is the handler of one rule for one node kind, and the walk of
`gql_validation.validate` calls it.

The comparison that `FieldsOnCorrectTypeRule` sorts its suggested types
with is not transitive: an interface comes before the types that implement
it, and other types come in name order. So the order depends on the sort.
graphql-js runs on V8, whose `Array.prototype.sort` finds the first run and
then does a binary insertion sort, for up to 64 items. `_v8_sort` is that
algorithm, so the suggestions come in the graphql-js order.

**Difference from graphql-js.** For more than 64 suggested types, V8 also
merges runs. `_v8_sort` keeps the binary insertion sort, which gives the
same order when the comparisons agree with one total order.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_schema.builtins import INTROSPECTION_TYPE_NAMES, SPECIFIED_SCALAR_NAMES
from gql_schema.definition import NO_TYPE, Schema, TypeKind
from gql_language.names import NOT_FOUND
from gql_schema.suggestions import did_you_mean, natural_compare
from gql_validation.state import Walk
from gql_validation.suggest import Suggester
from gql_validation.type_info import NO_FIELD, is_defined


def _is_standard_type_name(name: StringSlice) -> Bool:
    """Return True for a specified scalar or an introspection type."""
    comptime count = len(SPECIFIED_SCALAR_NAMES)
    var index = 0
    while index < count:
        if name == materialize[SPECIFIED_SCALAR_NAMES]()[index]:
            return True
        index += 1
    return _is_introspection_type_name(name)


def _is_introspection_type_name(name: StringSlice) -> Bool:
    """Return True for the name of an introspection type."""
    comptime count = len(INTROSPECTION_TYPE_NAMES)
    var index = 0
    while index < count:
        if name == materialize[INTROSPECTION_TYPE_NAMES]()[index]:
            return True
        index += 1
    return False


def known_type_names(
    mut walk: Walk, schema: Schema, document: Document, node: Int
):
    """KnownTypeNamesRule, on a `NamedType`.

    Args:
        walk: The walk.
        schema: The schema.
        document: The document.
        node: The named type.
    """
    var name = document.name(node)
    if schema.type_named(name) != NO_TYPE:
        return
    if walk.defined_types.find(-1, name) != NOT_FOUND:
        return
    var definition = document.kind(walk.definition())
    var is_sdl = (
        definition.is_type_system_definition()
        or definition.is_type_system_extension()
    )
    if is_sdl and _is_standard_type_name(name):
        return
    var suggester = Suggester(name)
    if is_sdl:
        comptime scalars = len(SPECIFIED_SCALAR_NAMES)
        comptime introspection = len(INTROSPECTION_TYPE_NAMES)
        var index = 0
        while index < scalars:
            suggester.consider(materialize[SPECIFIED_SCALAR_NAMES]()[index])
            index += 1
        index = 0
        while index < introspection:
            suggester.consider(materialize[INTROSPECTION_TYPE_NAMES]()[index])
            index += 1
    # A schema always has the introspection types, so this loop runs.
    var at = 0
    while at < len(schema.type_map):
        suggester.consider(schema.types[Int(schema.type_map[at])].name)
        at += 1
    for ref defined in walk.defined_type_names:
        suggester.consider(defined)
    walk.ctx.report_error(
        document,
        'Unknown type "'
        + String(name)
        + '".'
        + did_you_mean(suggester^.take()),
        node,
    )


def scalar_leafs(mut walk: Walk, schema: Schema, document: Document, node: Int):
    """ScalarLeafsRule, on a `Field`.

    Args:
        walk: The walk.
        schema: The schema.
        document: The document.
        node: The field.
    """
    var type = walk.ctx.type_info.get_type()
    if not is_defined(type):
        return
    var selection_set = document.child(node, Role.SELECTION_SET)
    if schema.types[Int(type.named)].kind.is_leaf():
        if selection_set != NO_NODE:
            walk.ctx.report_error(
                document,
                'Field "'
                + String(document.name(node))
                + '" must not have a selection since type "'
                + schema.type_name(type)
                + '" has no subfields.',
                selection_set,
            )
    elif selection_set == NO_NODE:
        var name = String(document.name(node))
        walk.ctx.report_error(
            document,
            'Field "'
            + name
            + '" of type "'
            + schema.type_name(type)
            + '" must have a selection of subfields. Did you mean "'
            + name
            + ' { ... }"?',
            node,
        )
    elif document.child(selection_set, Role.SELECTION) == NO_NODE:
        walk.ctx.report_error(
            document,
            'Field "'
            + String(document.name(node))
            + '" of type "'
            + schema.type_name(type)
            + '" must have at least one field selected.',
            node,
        )


def _suggested_type_names(
    schema: Schema, type: Int, field: StringSlice
) -> List[String]:
    """Return graphql-js `getSuggestedTypeNames`: the types of an abstract
    type that have a field, the most used first."""
    var types = List[Int]()
    var usage = List[Int]()
    if not schema.types[type].kind.is_abstract():
        return List[String]()
    for possible in schema.possible_types(type):
        if schema.field_named(possible, field) == NO_TYPE:
            continue
        _count_type(types, usage, possible, True)
        for interface in schema.interfaces_of(possible):
            if schema.field_named(interface, field) == NO_TYPE:
                continue
            _count_type(types, usage, interface, False)
    var order = List[Int]()
    for index in range(len(types)):
        order.append(index)
    _v8_sort(schema, types, usage, order)
    var out = List[String]()
    for index in order:
        out.append(schema.types[types[index]].name)
    return out^


def _count_type(
    mut types: List[Int], mut usage: List[Int], type: Int, reset: Bool
):
    """Add a type to the suggestion set, and count one more use of it; an
    object type's count is set to one, as graphql-js does."""
    var index = 0
    while index < len(types) and types[index] != type:
        index += 1
    if index == len(types):
        types.append(type)
        usage.append(0)
    if reset:
        usage[index] = 1
    else:
        usage[index] += 1


def _v8_sort(
    schema: Schema, types: List[Int], usage: List[Int], mut order: List[Int]
):
    """Sort as V8 `Array.prototype.sort` sorts up to 64 items: find the run
    at the start, reverse it when it descends, then insert each later item
    with a binary search."""
    var count = len(order)
    if count < 2:
        return
    # graphql-js passes (a, b) to the comparison as V8 calls it.
    var run = 2
    var descending = _compare(schema, types, usage, order[1], order[0]) < 0
    while run < count:
        var step = _compare(schema, types, usage, order[run], order[run - 1])
        # The run ends at the first step in the other direction.
        if (step < 0) != descending:
            break
        run += 1
    if descending:
        _reverse(order, run)
    var start = run
    while start < count:
        var pivot = order[start]
        var left = 0
        var right = start
        while left < right:
            var middle = left + ((right - left) >> 1)
            if _compare(schema, types, usage, pivot, order[middle]) < 0:
                right = middle
            else:
                left = middle + 1
        var at = start
        while at > left:
            order[at] = order[at - 1]
            at -= 1
        order[left] = pivot
        start += 1


def _reverse(mut order: List[Int], count: Int):
    """Reverse the first `count` items."""
    var low = 0
    var high = count - 1
    while low < high:
        var item = order[low]
        order[low] = order[high]
        order[high] = item
        low += 1
        high -= 1


def _compare(
    schema: Schema, types: List[Int], usage: List[Int], a: Int, b: Int
) -> Int:
    """The comparison of graphql-js `getSuggestedTypeNames`."""
    var difference = usage[b] - usage[a]
    if difference != 0:
        return difference
    var type_a = types[a]
    var type_b = types[b]
    if schema.types[type_a].kind == TypeKind.INTERFACE and schema.is_sub_type(
        type_a, type_b
    ):
        return -1
    if schema.types[type_b].kind == TypeKind.INTERFACE and schema.is_sub_type(
        type_b, type_a
    ):
        return 1
    return natural_compare(schema.types[type_a].name, schema.types[type_b].name)


def fields_on_correct_type(
    mut walk: Walk, schema: Schema, document: Document, node: Int
):
    """FieldsOnCorrectTypeRule, on a `Field`.

    Args:
        walk: The walk.
        schema: The schema.
        document: The document.
        node: The field.
    """
    var parent = walk.ctx.type_info.get_parent_type()
    if parent == NO_TYPE or walk.ctx.type_info.get_field_def() != NO_FIELD:
        return
    var name = document.name(node)
    var suggestion = did_you_mean(
        "to use an inline fragment on",
        _suggested_type_names(schema, parent, name),
    )
    if suggestion == "":
        var suggester = Suggester(name)
        if schema.types[parent].kind.has_fields():
            ref span = schema.types[parent].fields
            # A valid schema gives each type with fields at least one.
            var field = Int(span.start)
            while field < span.end():
                suggester.consider(schema.fields[field].name)
                field += 1
        suggestion = did_you_mean(suggester^.take())
    walk.ctx.report_error(
        document,
        'Cannot query field "'
        + String(name)
        + '" on type "'
        + schema.types[parent].name
        + '".'
        + suggestion,
        node,
    )


# --- MaxIntrospectionDepthRule ----------------------------------------------

comptime _MAX_LISTS_DEPTH = 3


def _is_list_field(name: StringSlice) -> Bool:
    """Return True for an introspection field that returns a list of
    types or fields."""
    return (
        name == "fields"
        or name == "interfaces"
        or name == "possibleTypes"
        or name == "inputFields"
    )


def _is_meta_root(name: StringSlice) -> Bool:
    """Return True for `__schema` and `__type`."""
    return name == "__schema" or name == "__type"


def _check_depth(
    mut walk: Walk,
    document: Document,
    node: Int,
    mut visited: List[Bool],
    depth: Int,
) -> Bool:
    """graphql-js `checkDepth`: return True when the introspection lists
    under a node nest too deep."""
    var kind = document.kind(node)
    if kind == Kind.FRAGMENT_SPREAD:
        var id = walk.ctx.fragment_id(document.name(node))
        while len(visited) <= id:
            visited.append(False)
        if visited[id]:
            return False
        var fragment = walk.ctx.fragment_by_id(document, id)
        if fragment == NO_NODE:
            return False
        visited[id] = True
        var found = _check_selections(walk, document, fragment, visited, depth)
        visited[id] = False
        return found
    var level = depth
    if kind == Kind.FIELD and _is_list_field(document.name(node)):
        level += 1
        if level >= _MAX_LISTS_DEPTH:
            return True
    return _check_selections(walk, document, node, visited, level)


def _check_selections(
    mut walk: Walk,
    document: Document,
    node: Int,
    mut visited: List[Bool],
    depth: Int,
) -> Bool:
    """Check each selection of a node's selection set, if it has one."""
    var selection_set = document.child(node, Role.SELECTION_SET)
    if selection_set == NO_NODE:
        return False
    var child = document.child(selection_set, Role.SELECTION)
    while child != NO_NODE:
        if _check_depth(walk, document, child, visited, depth):
            return True
        child = document.next_with_role(child)
    return False


def max_introspection_depth(
    mut walk: Walk, document: Document, node: Int
) -> Bool:
    """MaxIntrospectionDepthRule, on a `Field`.

    Args:
        walk: The walk.
        document: The document.
        node: The field.

    Returns:
        True when the rule skips the field's subtree, as graphql-js
        `return false`.
    """
    if not _is_meta_root(document.name(node)):
        return False
    var visited = List[Bool]()
    if not _check_depth(walk, document, node, visited, 0):
        return False
    walk.ctx.report_error(
        document, String("Maximum introspection depth exceeded"), node
    )
    return True


# --- custom rules -------------------------------------------------------------


def no_deprecated_field(
    mut walk: Walk, schema: Schema, document: Document, node: Int
):
    """NoDeprecatedCustomRule, on a `Field`.

    Args:
        walk: The walk.
        schema: The schema.
        document: The document.
        node: The field.
    """
    var field = walk.ctx.type_info.get_field_def()
    if field < 0 or not schema.fields[field].is_deprecated:
        return
    var parent = walk.ctx.type_info.get_parent_type()
    walk.ctx.report_error(
        document,
        "The field "
        + schema.types[parent].name
        + "."
        + schema.fields[field].name
        + " is deprecated. "
        + schema.fields[field].deprecation_reason,
        node,
    )


def no_deprecated_argument(
    mut walk: Walk, schema: Schema, document: Document, node: Int
):
    """NoDeprecatedCustomRule, on an `Argument`.

    Args:
        walk: The walk.
        schema: The schema.
        document: The document.
        node: The argument.
    """
    var argument = walk.ctx.type_info.get_argument()
    if argument < 0 or not schema.input_values[argument].is_deprecated:
        return
    ref value = schema.input_values[argument]
    var directive = walk.ctx.type_info.get_directive()
    if directive != NO_TYPE:
        walk.ctx.report_error(
            document,
            'Directive "@'
            + schema.directives[directive].name
            + '" argument "'
            + value.name
            + '" is deprecated. '
            + value.deprecation_reason,
            node,
        )
        return
    var parent = walk.ctx.type_info.get_parent_type()
    var field = walk.ctx.type_info.get_field_def()
    walk.ctx.report_error(
        document,
        'Field "'
        + schema.types[parent].name
        + "."
        + schema.fields[field].name
        + '" argument "'
        + value.name
        + '" is deprecated. '
        + value.deprecation_reason,
        node,
    )


def no_deprecated_input_field(
    mut walk: Walk, schema: Schema, document: Document, node: Int
):
    """NoDeprecatedCustomRule, on an `ObjectField`.

    Args:
        walk: The walk.
        schema: The schema.
        document: The document.
        node: The object field.
    """
    var object = Int(walk.ctx.type_info.get_parent_input_type().named)
    if object < 0 or schema.types[object].kind != TypeKind.INPUT_OBJECT:
        return
    var field = schema.input_field_named(object, document.name(node))
    if field == NO_TYPE or not schema.input_values[field].is_deprecated:
        return
    walk.ctx.report_error(
        document,
        "The input field "
        + schema.types[object].name
        + "."
        + schema.input_values[field].name
        + " is deprecated. "
        + schema.input_values[field].deprecation_reason,
        node,
    )


def no_deprecated_enum_value(
    mut walk: Walk, schema: Schema, document: Document, node: Int
):
    """NoDeprecatedCustomRule, on an `EnumValue`.

    Args:
        walk: The walk.
        schema: The schema.
        document: The document.
        node: The enum value.
    """
    var value = walk.ctx.type_info.get_enum_value()
    if value == NO_TYPE or not schema.enum_values[value].is_deprecated:
        return
    var type = Int(walk.ctx.type_info.get_input_type().named)
    walk.ctx.report_error(
        document,
        'The enum value "'
        + schema.types[type].name
        + "."
        + schema.enum_values[value].name
        + '" is deprecated. '
        + schema.enum_values[value].deprecation_reason,
        node,
    )


def no_schema_introspection(
    mut walk: Walk, schema: Schema, document: Document, node: Int
):
    """NoSchemaIntrospectionCustomRule, on a `Field`.

    Args:
        walk: The walk.
        schema: The schema.
        document: The document.
        node: The field.
    """
    var type = walk.ctx.type_info.get_type()
    if not is_defined(type) or not _is_introspection_type_name(
        schema.types[Int(type.named)].name
    ):
        return
    walk.ctx.report_error(
        document,
        "GraphQL introspection has been disabled, but the requested query"
        ' contained the field "'
        + String(document.name(node))
        + '".',
        node,
    )

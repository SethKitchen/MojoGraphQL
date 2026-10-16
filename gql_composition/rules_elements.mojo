# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The federation rules of the single directives.

Port of these files of Hive Federation Composition v0.27.0
`src/subgraph/validation/rules/elements/`: `cost.ts`,
`interface-object.ts`, `extends.ts`, `shareable.ts`, `external.ts`,
`override.ts`, `context.ts` and `compose-directive.ts`, and of
`isValidContextName` of `src/subgraph/context.ts`.

**Differences from upstream.** A `@cost` weight outside the range of `Int`
is clamped to that range. Upstream keeps a JavaScript number.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_composition.context import SubgraphContext
from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.helpers import argument_value
from gql_composition.printer import print_node
from gql_composition.state import TypeKind, ExtensionType
from gql_composition.state_visitor import set_object_extension


def _is_object(kind: Kind) -> Bool:
    """Return True for an object type definition or extension."""
    return (
        kind == Kind.OBJECT_TYPE_DEFINITION
        or kind == Kind.OBJECT_TYPE_EXTENSION
    )


def _is_interface(kind: Kind) -> Bool:
    """Return True for an interface type definition or extension."""
    return (
        kind == Kind.INTERFACE_TYPE_DEFINITION
        or kind == Kind.INTERFACE_TYPE_EXTENSION
    )


def parse_int(text: StringSlice) -> Int:
    """Return the value of an `IntValue`, clamped to the range of `Int`.

    Args:
        text: The digits, with an optional `-`.

    Returns:
        The value.
    """
    var bytes = text.as_bytes()
    var negative = len(bytes) > 0 and bytes[0] == 45
    var value = 0
    var index = 1 if negative else 0
    while index < len(bytes):
        var digit = Int(bytes[index]) - 48
        if value > (Int.MAX - digit) // 10:
            return Int.MIN if negative else Int.MAX
        value = value * 10 + digit
        index += 1
    return -value if negative else value


def enter_cost(mut context: SubgraphContext, node: Int, parent: Int) raises:
    """Record a `@cost` weight, as upstream `CostRule`.

    Args:
        context: The context.
        node: The directive.
        parent: The annotated node.

    Raises:
        Error: The upstream error for a missing or non-integer `weight`.
    """
    var weight_node = argument_value(context.document, node, "weight")
    if weight_node == NO_NODE:
        raise Error('Expected @cost to have a "weight" argument')
    if context.document.kind(weight_node) != Kind.INT:
        raise Error('Expected "@cost(weight:)" to be of type Int')
    var weight = parse_int(context.document.text(weight_node))
    context.state.specs.cost = True
    context.state.specs.cost_name = String(context.document.name(node))
    var kind = context.document.kind(parent)
    var name = String(context.document.name(parent))
    if kind == Kind.FIELD_DEFINITION or kind == Kind.INPUT_VALUE_DEFINITION:
        _cost_on_value(context, kind, name, weight)
    elif _is_object(kind):
        if not context.state.is_interface_object(name):
            var index = context.state.object_type(name)
            context.state.types[index].cost = weight
    elif (
        kind == Kind.SCALAR_TYPE_DEFINITION
        or kind == Kind.SCALAR_TYPE_EXTENSION
    ):
        var index = context.state.get_or_create(
            TypeKind.SCALAR, name, "a scalar type"
        )
        context.state.types[index].cost = weight
    elif kind == Kind.ENUM_TYPE_DEFINITION or kind == Kind.ENUM_TYPE_EXTENSION:
        var index = context.state.get_or_create(
            TypeKind.ENUM, name, "an enum type"
        )
        context.state.types[index].cost = weight


def _cost_on_value(
    mut context: SubgraphContext, kind: Kind, name: String, weight: Int
) raises:
    """Record a `@cost` weight on a field or an input value."""
    var type_def = context.info.type_def
    var type_kind = context.document.kind(type_def)
    var type_name = String(context.document.name(type_def))
    if kind == Kind.FIELD_DEFINITION:
        if _is_interface(type_kind):
            context.report(
                '@cost cannot be applied to interface "'
                + type_name
                + "."
                + name
                + '"',
                ErrorCode.COST_APPLIED_TO_INTERFACE_FIELD,
            )
            return
        var at = context.state.entity_field(type_name, name)
        context.state.types[at.type].fields[at.field].cost = weight
    elif kind == Kind.INPUT_VALUE_DEFINITION:
        var field_name = String(context.document.name(context.info.field_def))
        if (
            type_kind == Kind.INPUT_OBJECT_TYPE_DEFINITION
            or type_kind == Kind.INPUT_OBJECT_TYPE_EXTENSION
        ):
            var at = context.state.input_value_at(
                TypeKind.INPUT_OBJECT, type_name, field_name
            )
            context.state.types[at.type].input_fields[at.field].cost = weight
        elif _is_object(type_kind):
            var at = context.state.entity_field(type_name, field_name)
            var arg = context.state.arg_index(at, name)
            context.state.types[at.type].fields[at.field].args[
                arg
            ].cost = weight
        elif _is_interface(type_kind):
            context.report(
                '@cost cannot be applied to interface "'
                + type_name
                + "."
                + field_name
                + '" argument "'
                + name
                + '"',
                ErrorCode.COST_APPLIED_TO_INTERFACE_FIELD,
            )


def _fields_of(document: Document, node: Int) -> List[Int]:
    """Return the field definitions of one type node."""
    var out = List[Int]()
    var child = document.first_child(node)
    while child != NO_NODE:
        if document.role(child) == Role.FIELD:
            out.append(child)
        child = document.next_sibling(child)
    return out^


def _has_directive_named(
    document: Document, node: Int, name: StringSlice
) -> Bool:
    """Return True if a node has a directive with a name."""
    var child = document.first_child(node)
    while child != NO_NODE:
        if (
            document.role(child) == Role.DIRECTIVE
            and document.name(child) == name
        ):
            return True
        child = document.next_sibling(child)
    return False


def enter_interface_object(mut context: SubgraphContext):
    """Check an `@interfaceObject`, as upstream `InterfaceObjectRules`.

    Args:
        context: The context.
    """
    if context.version.below(203):
        context.report(
            (
                "@interfaceObject is not yet supported. See"
                " https://github.com/graphql-hive/federation-composition/issues/7"
            ),
            ErrorCode.UNSUPPORTED_FEATURE,
        )
        return
    var type_def = context.info.type_def
    if type_def == NO_NODE or not _is_object(context.document.kind(type_def)):
        return
    if not _has_directive_named(context.document, type_def, "key"):
        context.report(
            "The @interfaceObject directive can only be applied to entity"
            ' types but type "'
            + String(context.document.name(type_def))
            + '" has no @key in this subgraph.',
            ErrorCode.INTERFACE_OBJECT_USAGE_ERROR,
        )


def enter_extends(mut context: SubgraphContext) raises:
    """Mark a type with `@extends` as an extension, as upstream
    `ExtendsRules`.

    Args:
        context: The context.

    Raises:
        Error: When the state has a conflict of kinds.
    """
    var type_def = context.info.type_def
    if type_def == NO_NODE:
        return
    var kind = context.document.kind(type_def)
    var name = String(context.document.name(type_def))
    if kind == Kind.OBJECT_TYPE_DEFINITION:
        set_object_extension(context, name, ExtensionType.EXTENDS)
    elif kind == Kind.INTERFACE_TYPE_DEFINITION:
        var index = context.state.interface_type(name)
        context.state.types[index].extension = True
    else:
        return
    for field in _fields_of(context.document, type_def):
        context.mark_as_used(
            False,
            kind == Kind.INTERFACE_TYPE_DEFINITION,
            name,
            String(context.document.name(field)),
        )


def enter_shareable(mut context: SubgraphContext, node: Int) raises:
    """Mark a type or field as shareable, as upstream `ShareableRules`.

    Args:
        context: The context.
        node: The directive.

    Raises:
        Error: When the state has a conflict of kinds.
    """
    var type_def = context.info.type_def
    if type_def == NO_NODE:
        return
    var kind = context.document.kind(type_def)
    var name = String(context.document.name(type_def))
    var field_def = context.info.field_def
    if _is_object(kind) and not context.state.is_interface_object(name):
        if field_def != NO_NODE:
            var at = context.state.object_field(
                name, String(context.document.name(field_def))
            )
            context.state.types[at.type].fields[at.field].shareable = True
        else:
            var index = context.state.object_type(name)
            context.state.types[index].shareable = True
            for field in _fields_of(context.document, type_def):
                var at = context.state.object_field(
                    name, String(context.document.name(field))
                )
                context.state.types[at.type].fields[at.field].shareable = True
    if field_def != NO_NODE and _is_interface(kind):
        context.report(
            'Invalid use of @shareable on field "'
            + name
            + "."
            + String(context.document.name(field_def))
            + '": only object type fields can be marked with @shareable',
            ErrorCode.INVALID_SHAREABLE_USAGE,
        )


def enter_external(mut context: SubgraphContext) raises:
    """Mark fields as `@external`, as upstream `ExternalRules`.

    Args:
        context: The context.

    Raises:
        Error: When the state has a conflict of kinds.
    """
    var type_def = context.info.type_def
    if type_def == NO_NODE or not _is_object(context.document.kind(type_def)):
        return
    var name = String(context.document.name(type_def))
    var field_def = context.info.field_def
    var fields = List[Int]()
    if field_def != NO_NODE:
        if context.document.kind(field_def) != Kind.FIELD_DEFINITION:
            return
        fields.append(field_def)
    elif context.version.at_least(200):
        fields = _fields_of(context.document, type_def)
    for field in fields:
        var field_name = String(context.document.name(field))
        context.marked_as_external.add(name + "." + field_name)
        var conflicts = List[Int]()
        var child = context.document.first_child(field)
        while child != NO_NODE:
            if context.document.role(child) == Role.DIRECTIVE:
                var directive_name = context.document.name(child)
                if context.is_available_directive(
                    "tag", directive_name
                ) or context.is_available_directive(
                    "inaccessible", directive_name
                ):
                    conflicts.append(child)
            child = context.document.next_sibling(child)
        if len(conflicts) > 0 and context.version.at_least(200):
            for directive in conflicts:
                context.report(
                    "Cannot apply merged directive "
                    + print_node(context.document, directive).strip()
                    + ' to external field "'
                    + name
                    + "."
                    + field_name
                    + '"',
                    ErrorCode.MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL,
                )
        else:
            var at = context.state.entity_field(name, field_name)
            context.state.types[at.type].fields[at.field].external = True


def _is_label_char(byte: UInt8) -> Bool:
    """Return True for a byte that an override label can hold after its
    first letter."""
    return (
        (byte >= 65 and byte <= 90)
        or (byte >= 97 and byte <= 122)
        or (byte >= 48 and byte <= 57)
        or byte == 95
        or byte == 45
        or byte == 58
        or byte == 46
        or byte == 47
    )


def _is_percent(text: String) -> Bool:
    """Return True for `percent(x)` with x from 0 to 100, as upstream
    `labelPercentRegex`."""
    var bytes = text.as_bytes()
    var size = len(bytes)
    var inner = String(text[byte = 8 : size - 1])
    var digits = inner.as_bytes()
    var index = 0
    while index < len(digits) and digits[index] >= 48 and digits[index] <= 57:
        index += 1
    if index == 0 or index > 3:
        return False
    var whole = String(inner[byte=:index])
    if index == 3 and whole != "100":
        return False
    if index == len(digits):
        return True
    if digits[index] != 46:
        return False
    var fraction = len(digits) - index - 1
    if fraction < 1 or fraction > 8:
        return False
    for position in range(index + 1, len(digits)):
        var digit = digits[position]
        if digit < 48 or digit > 57 or (index == 3 and digit != 48):
            return False
    return True


def is_valid_label(document: Document, value: Int) -> Bool:
    """Return True for a valid `@override(label:)`, as upstream
    `isValidLabel`.

    Args:
        document: The document.
        value: The value of the `label` argument.

    Returns:
        Whether it is a string that is `percent(x)` for x from 0 to 100,
        or a letter and then letters, digits, `_`, `-`, `:`, `.` and `/`.
    """
    if document.kind(value) != Kind.STRING:
        return False
    var text = document.string_value(value)
    if text.startswith("percent(+") or text.startswith("percent(-"):
        return False
    if text.startswith("percent(") and text.endswith(")"):
        return _is_percent(text)
    var bytes = text.as_bytes()
    if len(bytes) == 0 or not (
        (bytes[0] >= 65 and bytes[0] <= 90)
        or (bytes[0] >= 97 and bytes[0] <= 122)
    ):
        return False
    for index in range(1, len(bytes)):
        if not _is_label_char(bytes[index]):
            return False
    return True


def enter_override(mut context: SubgraphContext, node: Int) raises:
    """Check and record `@override`, as upstream `OverrideRules`.

    Args:
        context: The context.
        node: The directive.

    Raises:
        Error: When the state has a conflict of kinds.
    """
    var type_def = context.info.type_def
    var field_def = context.info.field_def
    if field_def == NO_NODE or type_def == NO_NODE:
        return
    var kind = context.document.kind(type_def)
    var coordinate = (
        String(context.document.name(type_def))
        + "."
        + String(context.document.name(field_def))
    )
    var subgraph = context.name
    if _is_interface(kind) and context.version.at_least(203):
        context.report(
            '@override cannot be used on field "'
            + coordinate
            + '" on subgraph "'
            + subgraph
            + '": @override is not supported on interface type fields.',
            ErrorCode.OVERRIDE_ON_INTERFACE,
        )
        return
    var label = argument_value(context.document, node, "label")
    if (
        label != NO_NODE
        and context.version.at_least(207)
        and not is_valid_label(context.document, label)
    ):
        context.report(
            "Invalid @override label "
            + print_node(context.document, label)
            + ' on field "'
            + coordinate
            + '" on subgraph "'
            + subgraph
            + '": labels must start with a letter and after that may contain'
            " alphanumerics, underscores, minuses, colons, periods, or"
            ' slashes. Alternatively, labels may be of the form "percent(x)"'
            " where x is a float between 0-100 inclusive.",
            ErrorCode.OVERRIDE_LABEL_INVALID,
        )
        return
    if label != NO_NODE and context.document.kind(label) != Kind.STRING:
        return
    var source = argument_value(context.document, node, "from")
    if source == NO_NODE or context.document.kind(source) != Kind.STRING:
        return
    var child = context.document.first_child(field_def)
    while child != NO_NODE:
        if context.document.role(
            child
        ) == Role.DIRECTIVE and context.is_available_directive(
            "external", context.document.name(child)
        ):
            context.report(
                '@override cannot be used on field "'
                + coordinate
                + '" on subgraph "'
                + subgraph
                + '" since "'
                + coordinate
                + '" on "'
                + subgraph
                + '" is marked with directive "@'
                + String(context.document.name(child))
                + '"',
                ErrorCode.OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE,
            )
        child = context.document.next_sibling(child)
    var source_name = context.document.string_value(source)
    if source_name == subgraph:
        context.report(
            'Source and destination subgraphs "'
            + source_name
            + '" are the same for overridden field "'
            + coordinate
            + '"',
            ErrorCode.OVERRIDE_FROM_SELF_ERROR,
        )
    var label_value = Optional[String](None)
    if label != NO_NODE:
        label_value = context.document.string_value(label)
    var at = context.state.owner_field(
        String(context.document.name(type_def)),
        String(context.document.name(field_def)),
        not _is_object(kind),
    )
    ref field = context.state.types[at.type].fields[at.field]
    field.override = source_name
    field.override_label = label_value^


def is_valid_context_name(name: String) -> Bool:
    """Return True for a context name of ASCII letters and digits that
    starts with a letter, as upstream `isValidContextName`.

    Args:
        name: The name.

    Returns:
        Whether the name is valid.
    """
    var bytes = name.as_bytes()
    if len(bytes) == 0:
        return False
    for index in range(len(bytes)):
        var byte = bytes[index]
        var letter = (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122)
        var digit = byte >= 48 and byte <= 57
        if not letter and (index == 0 or not digit):
            return False
    return True


def enter_context(mut context: SubgraphContext, node: Int) raises:
    """Record a `@context`, as upstream `ContextDirectiveRules`.

    Args:
        context: The context.
        node: The directive.

    Raises:
        Error: When the state has a conflict of kinds.
    """
    context.state.specs.context = True
    var type_def = context.info.type_def
    if type_def == NO_NODE:
        return
    var kind = context.document.kind(type_def)
    var is_union = (
        kind == Kind.UNION_TYPE_DEFINITION or kind == Kind.UNION_TYPE_EXTENSION
    )
    if not _is_object(kind) and not _is_interface(kind) and not is_union:
        return
    var value = argument_value(context.document, node, "name")
    if value == NO_NODE or context.document.kind(value) != Kind.STRING:
        return
    var name = context.document.string_value(value)
    if not is_valid_context_name(name):
        context.report(
            'Context name "'
            + name
            + '" is invalid. It should have only alphanumeric characters.',
            ErrorCode.CONTEXT_NAME_INVALID,
        )
    var type_name = String(context.document.name(type_def))
    var index: Int
    if is_union:
        index = context.state.get_or_create(
            TypeKind.UNION, type_name, "a union type"
        )
    elif _is_interface(kind) or context.state.is_interface_object(type_name):
        index = context.state.interface_type(type_name)
    else:
        index = context.state.object_type(type_name)
    context.state.types[index].contexts.add(name)


def enter_compose_directive(mut context: SubgraphContext, node: Int) raises:
    """Record a `@composeDirective`, as upstream `ComposeDirectiveRules`.

    Args:
        context: The context.
        node: The directive.

    Raises:
        Error: When the state has a conflict of kinds.
    """
    if not context.version.at_least(201):
        return
    var value = argument_value(context.document, node, "name")
    if value == NO_NODE or context.document.kind(value) != Kind.STRING:
        return
    var name = context.document.string_value(value)
    if name.startswith("@"):
        var stripped = String(name[byte=1:])
        name = stripped^
    var subgraph = context.name
    var matching = False
    for definition in context.definitions:
        if (
            context.document.kind(definition) == Kind.DIRECTIVE_DEFINITION
            and context.document.name(definition) == name
        ):
            matching = True
            break
    if not matching:
        context.errors.append(
            CompositionError(
                "Could not find matching directive definition for argument to"
                ' @composeDirective "@'
                + name
                + '" in subgraph "'
                + subgraph
                + '".',
                ErrorCode.DIRECTIVE_COMPOSITION_ERROR,
                subgraph,
            )
        )
        return
    var linked = False
    for ref link in context.state.links:
        for ref item in link.imports:
            if item.kind.value != 0:
                continue
            var local = item.alias.value() if item.alias else item.name
            if local.startswith("@"):
                var stripped = String(local[byte=1:])
                local = stripped^
            if local == name:
                linked = True
    if not linked:
        context.errors.append(
            CompositionError(
                'Directive "@'
                + name
                + '" in subgraph "'
                + subgraph
                + '" cannot be composed because it is not a member of a core'
                " feature",
                ErrorCode.DIRECTIVE_COMPOSITION_ERROR,
                subgraph,
            )
        )
        return
    var index = context.state.get_or_create(
        TypeKind.DIRECTIVE, name, "a directive"
    )
    context.state.types[index].composed = True
    context.state.composed_directives.add(name)

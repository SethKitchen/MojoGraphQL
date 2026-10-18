# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The `@fromContext` rules.

Port of Hive Federation Composition v0.27.0
`src/subgraph/validation/rules/elements/from-context.ts`, and of
`parseContextReference` of `src/subgraph/context.ts`.

**Differences from upstream.** Upstream compiles the selection into its
own tree; this port checks the parsed selection and then reads its nodes.
Upstream reports "no selection is made" when the selection has no fields;
the parser of `parseFields` cannot give such a selection, so this port
does not have that branch. Types are printed type strings, such as
`[Int!]`.
"""

from std.collections import Dict
from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_composition.context import SubgraphContext
from gql_composition.error_code import ErrorCode
from gql_composition.helpers import (
    argument_value,
    parse_fields,
    selection_set_of,
)
from gql_composition.rules_graphql import print_type_node
from gql_composition.state import FromContext
from gql_composition.validate_state import strip_list, strip_non_null


def _is_ignored(byte: UInt8) -> Bool:
    """Return True for a byte of an ignored token other than a comment."""
    return (
        byte == UInt8(ord(" "))
        or byte == UInt8(ord("\t"))
        or byte == UInt8(ord("\n"))
        or byte == UInt8(ord("\r"))
        or byte == UInt8(ord(","))
    )


def _skip_ignored(text: String, start: Int) -> Int:
    """Skip whitespace, commas, byte order marks and comments, as upstream
    `skipIgnoredTokens`."""
    var bytes = text.as_bytes()
    var position = start
    while position < len(bytes):
        var byte = bytes[position]
        if _is_ignored(byte):
            position += 1
        elif byte == 0xEF and text[byte = position : position + 3] == chr(
            0xFEFF
        ):
            position += 3
        elif byte == UInt8(ord("#")):
            position += 1
            while (
                position < len(bytes)
                and bytes[position] != UInt8(ord("\n"))
                and bytes[position] != UInt8(ord("\r"))
            ):
                position += 1
        else:
            break
    return position


def _is_letter(byte: UInt8) -> Bool:
    """Return True for an ASCII letter."""
    return (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122)


def _is_name_continue(byte: UInt8) -> Bool:
    """Return True for a byte that can continue a name."""
    return _is_letter(byte) or byte == 95 or (byte >= 48 and byte <= 57)


def parse_context_reference(text: String) -> Optional[FromContext]:
    """Split the value of `@fromContext(field:)` into the context name and
    the selection, as upstream `parseContextReference`.

    Args:
        text: Such as `$userCtx { id }`.

    Returns:
        The context and the rest of the text, or None when the text does
        not start with `$` and a name.
    """
    var bytes = text.as_bytes()
    var position = _skip_ignored(text, 0)
    if position >= len(bytes) or bytes[position] != UInt8(ord("$")):
        return None
    position = _skip_ignored(text, position + 1)
    if position >= len(bytes) or not (
        _is_letter(bytes[position]) or bytes[position] == 95
    ):
        return None
    var start = position
    position += 1
    while position < len(bytes) and _is_name_continue(bytes[position]):
        position += 1
    return FromContext(
        String(text[byte=start:position]), String(text[byte=position:])
    )


def _nullable(type: String) -> String:
    """Drop a top-level non-null, as upstream `nullableType`."""
    if type.endswith("!"):
        return strip_non_null(type)
    return type


def _wrap_lists(field_type: String, resolved: String) -> String:
    """Put the list wrappers of a field type around a resolved type, as
    upstream `wrapListModifiers`."""
    var type = _nullable(field_type)
    var depth = 0
    while type.endswith("]"):
        type = _nullable(strip_list(type))
        depth += 1
    var out = resolved
    while depth > 0:
        out = "[" + out + "]"
        depth -= 1
    return out^


def _matches(select_type: String, arg_type: String) -> Bool:
    """Return True when a selected type satisfies an argument type, as
    upstream `matchesArgType`."""
    var select = select_type
    var arg = arg_type
    while True:
        if arg.endswith("!"):
            if not select.endswith("!"):
                return False
            select = strip_non_null(select)
            arg = strip_non_null(arg)
        elif select.endswith("!"):
            select = strip_non_null(select)
        elif arg.endswith("]"):
            if not select.endswith("]"):
                return False
            select = strip_list(select)
            arg = strip_list(arg)
        else:
            return not select.endswith("]") and select == arg


def _invalid_selection(document: Document, selection_set: Int) raises -> String:
    """Return why a selection set cannot select a context value, as
    upstream `compileContextValues`; empty when it can."""
    var selection = document.first_child(selection_set)
    while selection != NO_NODE:
        var kind = document.kind(selection)
        if kind == Kind.FRAGMENT_SPREAD:
            return String("fragment spread is not allowed")
        if (
            kind == Kind.FIELD
            and document.child(selection, Role.ALIAS) != NO_NODE
        ):
            return String("aliases are not allowed in the selection")
        if document.child(selection, Role.DIRECTIVE) != NO_NODE:
            return String("directives are not allowed in the selection")
        var nested = document.child(selection, Role.SELECTION_SET)
        if nested != NO_NODE:
            var reason = _invalid_selection(document, nested)
            if reason.byte_length() > 0:
                return reason
        selection = document.next_sibling(selection)
    return String("")


def _type_condition(document: Document, fragment: Int) -> String:
    """Return the type condition of an inline fragment, or empty."""
    var condition = document.child(fragment, Role.TYPE_CONDITION)
    if condition == NO_NODE:
        return String("")
    return String(document.name(condition))


def _layout_error(document: Document, selection_set: Int) raises -> String:
    """Return why a selection is not a direct or a conditional selection,
    as upstream `parseContextSelection`; empty when it is one."""
    var reason = _invalid_selection(document, selection_set)
    if reason.byte_length() > 0:
        return reason
    var first = document.first_child(selection_set)
    if document.kind(first) == Kind.FIELD:
        if document.next_sibling(first) != NO_NODE:
            return String("multiple selections are made")
        return String("")
    var names = Dict[String, Bool]()
    var count = 0
    var selection = first
    while selection != NO_NODE:
        if document.kind(selection) == Kind.FIELD:
            return String("multiple fields could be selected")
        var condition = _type_condition(document, selection)
        if condition.byte_length() == 0:
            return String("inline fragments must have type conditions")
        names[condition] = True
        count += 1
        selection = document.next_sibling(selection)
    if len(names) != count:
        return String("type conditions have same name")
    return String("")


comptime _OBJECT = 0
comptime _INTERFACE = 1
comptime _UNION = 2


@fieldwise_init
struct _Selectable(ImplicitlyCopyable):
    """A type that a selection can select from, as upstream
    `SelectableType`; `index` is -1 for an unknown type."""

    var kind: Int
    """`_OBJECT`, `_INTERFACE` or `_UNION`."""
    var index: Int
    """The index in `merged`, or in `union_names` for a union."""


comptime _RESOLVED = 0
comptime _UNRESOLVED = 1
comptime _UNKNOWN_FIELD = 2
comptime _INTERFACE_OBJECT = 3


@fieldwise_init
struct _Result(Copyable):
    """The type of a selection, as upstream `SelectionTypeResult`."""

    var kind: Int
    var type: String
    """The printed type of a resolved selection."""
    var owner: String
    """The type of an unknown field, or the `@interfaceObject` type."""
    var field: String
    """The unknown field."""


def _resolved(type: String) -> _Result:
    """Return a resolved result."""
    return _Result(_RESOLVED, type, String(""), String(""))


def _unresolved() -> _Result:
    """Return an unresolved result."""
    return _Result(_UNRESOLVED, String(""), String(""), String(""))


def _selectable(context: SubgraphContext, name: StringSlice) -> _Selectable:
    """Find a type by name, as upstream `buildSelectableType`."""
    var merged = context.merged_type(name)
    if merged != -1:
        if context.merged[merged].is_interface():
            return _Selectable(_INTERFACE, merged)
        return _Selectable(_OBJECT, merged)
    return _Selectable(_UNION, context.union_type(name))


def _name_of(context: SubgraphContext, type: _Selectable) -> String:
    """Return the name of a known selectable type."""
    if type.kind == _UNION:
        return context.union_names[type.index]
    return context.merged[type.index].name


def _field_definition(
    context: SubgraphContext, type: _Selectable, name: StringSlice
) -> Int:
    """Find a field of an object or interface type, or of an interface of
    an object type, as upstream `getFieldDefinition`."""
    ref merged = context.merged[type.index]
    var field = merged.find_field(context.document, name)
    if field != NO_NODE or type.kind != _OBJECT:
        return field
    for interface in merged.interfaces:
        var found = _selectable(context, context.document.name(interface))
        if found.kind == _INTERFACE:
            var interface_field = context.merged[found.index].find_field(
                context.document, name
            )
            if interface_field != NO_NODE:
                return interface_field
    return NO_NODE


def _is_interface_object(context: SubgraphContext, type: _Selectable) -> Bool:
    """Return True for an object type with `@interfaceObject`."""
    if type.kind != _OBJECT:
        return False
    for directive in context.merged[type.index].directives:
        if context.is_available_directive(
            "interfaceObject", context.document.name(directive)
        ):
            return True
    return False


def _field_type(document: Document, field: Int) -> String:
    """Return the printed type of a field definition."""
    return print_type_node(document, document.child(field, Role.TYPE))


def _named(type: String) -> String:
    """Return the named type of a printed type."""
    var bytes = type.as_bytes()
    var start = 0
    var end = len(bytes)
    while bytes[start] == UInt8(ord("[")):
        start += 1
    while bytes[end - 1] == UInt8(ord("]")) or bytes[end - 1] == UInt8(
        ord("!")
    ):
        end -= 1
    return String(type[byte=start:end])


def _resolve_selected(
    mut context: SubgraphContext,
    current: _Selectable,
    document: Document,
    selection_set: Int,
) raises -> _Result:
    """Return the type that a selection set selects from a type, as
    upstream `resolveSelectedType`."""
    if _is_interface_object(context, current):
        return _Result(
            _INTERFACE_OBJECT,
            String(""),
            _name_of(context, current),
            String(""),
        )
    var resolved = String("")
    var selection = document.first_child(selection_set)
    while selection != NO_NODE:
        var next = _resolve_selection(context, current, document, selection)
        if next.kind != _RESOLVED:
            return next^
        if resolved.byte_length() == 0:
            resolved = next.type
        elif not _matches(resolved, next.type) or not _matches(
            next.type, resolved
        ):
            return _unresolved()
        selection = document.next_sibling(selection)
    return _resolved(resolved)


def _resolve_selection(
    mut context: SubgraphContext,
    current: _Selectable,
    document: Document,
    selection: Int,
) raises -> _Result:
    """Return the type that one selection selects, as upstream
    `resolveSelectionType`."""
    var nested_set = document.child(selection, Role.SELECTION_SET)
    if document.kind(selection) == Kind.INLINE_FRAGMENT:
        var condition = _type_condition(document, selection)
        if condition.byte_length() == 0:
            return _unresolved()
        var fragment_type = _selectable(context, condition)
        if fragment_type.index == -1:
            return _unresolved()
        return _resolve_selected(context, fragment_type, document, nested_set)
    var name = String(document.name(selection))
    if name == "__typename":
        return _resolved(String("String!"))
    if current.kind == _UNION:
        return _unresolved()
    var owner = _name_of(context, current)
    var field = _field_definition(context, current, name)
    if field == NO_NODE:
        return _Result(_UNKNOWN_FIELD, String(""), owner, name)
    context.mark_as_used(True, current.kind == _INTERFACE, owner, name)
    var field_type = _field_type(context.document, field)
    if nested_set == NO_NODE:
        return _resolved(_nullable(field_type))
    var child = _selectable(context, _named(field_type))
    if child.index == -1:
        return _unresolved()
    var nested = _resolve_selected(context, child, document, nested_set)
    if nested.kind != _RESOLVED:
        return nested^
    return _resolved(_wrap_lists(field_type, nested.type))


struct _Checker:
    """Reports the errors of one `@fromContext` selection."""

    var name: String
    """The context name."""
    var coordinate: String
    """The argument, as upstream `argCoordinate`."""
    var arg_type: String
    """The printed type of the argument."""

    def __init__(out self, name: String, coordinate: String, arg_type: String):
        self.name = name
        self.coordinate = coordinate
        self.arg_type = arg_type

    def invalid(self, mut context: SubgraphContext, reason: String):
        """Report an invalid selection, as upstream
        `reportInvalidSelection`."""
        context.report(
            'Context "'
            + self.name
            + '" is used in "'
            + self.coordinate
            + '" but the selection is invalid: '
            + reason,
            ErrorCode.CONTEXT_INVALID_SELECTION,
        )

    def check(self, mut context: SubgraphContext, result: _Result) -> Bool:
        """Check a selected type, as upstream `validateSelectedType`."""
        if result.kind == _UNKNOWN_FIELD:
            context.report(
                'Context "'
                + self.name
                + '" is used in "'
                + self.coordinate
                + '" but the selection is invalid for type '
                + result.owner
                + '. Error: Cannot query field "'
                + result.field
                + '" on type "'
                + result.owner
                + '".',
                ErrorCode.CONTEXT_INVALID_SELECTION,
            )
            return False
        if result.kind == _INTERFACE_OBJECT:
            self.invalid(
                context,
                'One of the types in the selection is an interfaceObject: "'
                + result.owner
                + '"',
            )
            return False
        if result.kind == _UNRESOLVED:
            self.invalid(
                context,
                'the type of the selection does not match the expected type "'
                + self.arg_type
                + '"',
            )
            return False
        if not _matches(result.type, self.arg_type):
            self.invalid(
                context,
                'the type of the selection "'
                + result.type
                + '" does not match the expected type "'
                + self.arg_type
                + '"',
            )
            return False
        return True

    def check_conditional(
        self,
        mut context: SubgraphContext,
        owner: _Selectable,
        document: Document,
        selection_set: Int,
        mut touched: Dict[String, Bool],
    ) raises -> Bool:
        """Check the branches of a conditional selection, as upstream
        `validateConditionalSelections`."""
        var runtime = _runtime_types(context, owner)
        var applicable = False
        var fragment = document.first_child(selection_set)
        while fragment != NO_NODE:
            var branch = _type_condition(document, fragment)
            var fragment_set = document.child(fragment, Role.SELECTION_SET)
            fragment = document.next_sibling(fragment)
            if branch not in runtime:
                continue
            applicable = True
            touched[branch] = True
            var branch_type = _selectable(context, branch)
            if branch_type.index == -1 or branch_type.kind != _OBJECT:
                self.invalid(context, "type conditions must be an object type")
                return False
            if not self.check(
                context,
                _resolve_selected(context, branch_type, document, fragment_set),
            ):
                return False
        if not applicable:
            self.invalid(
                context,
                'no type condition matches the location "'
                + _name_of(context, owner)
                + '"',
            )
            return False
        return True


def _runtime_types(
    context: SubgraphContext, owner: _Selectable
) -> Dict[String, Bool]:
    """Return the object types that a type can be at runtime, as upstream
    `runtimeSetFor`."""
    var out = Dict[String, Bool]()
    if owner.kind == _OBJECT:
        out[context.merged[owner.index].name] = True
    elif owner.kind == _UNION:
        # A union has at least one member.
        ref members = context.union_members[owner.index].items
        var index = 0
        while index < len(members):
            out[members[index]] = True
            index += 1
    else:
        # The interface itself is one of the merged types.
        var name = context.merged[owner.index].name
        var index = 0
        while index < len(context.merged):
            ref candidate = context.merged[index]
            index += 1
            if candidate.is_object() and candidate.implements(
                context.document, name
            ):
                out[candidate.name] = True
    return out^


def _validate_selection(
    mut context: SubgraphContext,
    owners: List[String],
    checker: _Checker,
    selection: String,
) raises:
    """Check the selection of a context value, as upstream
    `validateSelection`."""
    var document: Document
    try:
        document = parse_fields(selection)
    except error:
        raise Error(error.message)
    var selection_set = selection_set_of(document)
    var reason = _layout_error(document, selection_set)
    if reason.byte_length() > 0:
        checker.invalid(context, reason)
        return
    var direct = (
        document.kind(document.first_child(selection_set)) == Kind.FIELD
    )
    var touched = Dict[String, Bool]()
    var position = 0
    while position < len(owners):
        var owner = _selectable(context, owners[position])
        position += 1
        var valid: Bool
        if direct:
            valid = checker.check(
                context,
                _resolve_selected(context, owner, document, selection_set),
            )
        else:
            valid = checker.check_conditional(
                context, owner, document, selection_set, touched
            )
        if not valid:
            return
    if direct:
        return
    var fragment = document.first_child(selection_set)
    while fragment != NO_NODE:
        var condition = _type_condition(document, fragment)
        if condition not in touched:
            checker.invalid(
                context, 'type condition "' + condition + '" is never used.'
            )
            return
        fragment = document.next_sibling(fragment)


def _context_name(context: SubgraphContext, directive: Int) -> String:
    """Return the name of a federation `@context`, or empty, as upstream
    `readContextDirectiveName`."""
    if not context.is_available_directive(
        "context", context.document.name(directive)
    ):
        return String("")
    var value = argument_value(context.document, directive, "name")
    if value == NO_NODE or context.document.kind(value) != Kind.STRING:
        return String("")
    return context.document.string_value(value)


def index_context_owners(
    context: SubgraphContext,
) raises -> Dict[String, List[String]]:
    """Return the types that set each context, as upstream
    `indexContextOwners`.

    Args:
        context: The context.

    Returns:
        The names of the object, interface and union types that set each
        context, in order.

    Raises:
        Error: Never; each name that it reads is in the dictionary.
    """
    var owners = Dict[String, List[String]]()
    var directives = List[Int]()
    var names = List[String]()
    for ref merged in context.merged:
        for directive in merged.directives:
            directives.append(directive)
            names.append(merged.name)
    for definition in context.definitions:
        var kind = context.document.kind(definition)
        if (
            kind != Kind.UNION_TYPE_DEFINITION
            and kind != Kind.UNION_TYPE_EXTENSION
        ):
            continue
        var child = context.document.first_child(definition)
        while child != NO_NODE:
            if context.document.role(child) == Role.DIRECTIVE:
                directives.append(child)
                names.append(String(context.document.name(definition)))
            child = context.document.next_sibling(child)
    for index in range(len(directives)):
        var name = _context_name(context, directives[index])
        if name.byte_length() == 0:
            continue
        if name not in owners:
            owners[name] = List[String]()
        owners[name].append(names[index])
    return owners^


def _has_resolvable_key(context: SubgraphContext, merged: Int) -> Bool:
    """Return True when an object type has a resolvable `@key`."""
    for directive in context.merged[merged].directives:
        if not context.is_available_directive(
            "key", context.document.name(directive)
        ):
            continue
        var resolvable = argument_value(
            context.document, directive, "resolvable"
        )
        if (
            resolvable == NO_NODE
            or context.document.kind(resolvable) != Kind.BOOLEAN
            or context.document.boolean_value(resolvable)
        ):
            return True
    return False


def enter_from_context(
    mut context: SubgraphContext,
    node: Int,
    owners: Dict[String, List[String]],
) raises:
    """Check a `@fromContext`, as upstream `FromContextDirectiveRules`.

    Args:
        context: The context.
        node: The directive.
        owners: The result of `index_context_owners`.

    Raises:
        Error: The syntax error of the selection, as upstream throws it.
    """
    context.state.specs.context = True
    var type_def = context.info.type_def
    var field_def = context.info.field_def
    var argument = context.info.arg_def
    var on_directive = (
        type_def != NO_NODE
        and context.document.kind(type_def) == Kind.DIRECTIVE_DEFINITION
    )
    if on_directive:
        argument = field_def
    if type_def == NO_NODE or field_def == NO_NODE or argument == NO_NODE:
        return
    var type_name = String(context.document.name(type_def))
    var field_name = String(context.document.name(field_def))
    var argument_name = String(context.document.name(argument))
    if on_directive:
        context.report(
            '@fromContext argument cannot be used on a directive definition "@'
            + type_name
            + "("
            + argument_name
            + ':)".',
            ErrorCode.CONTEXT_NOT_SET,
        )
        return
    var coordinate = type_name + "." + field_name + "(" + argument_name + ":)"
    var kind = context.document.kind(type_def)
    if (
        kind != Kind.OBJECT_TYPE_DEFINITION
        and kind != Kind.OBJECT_TYPE_EXTENSION
    ):
        context.report(
            "@fromContext argument cannot be used on a field that exists on"
            ' an abstract type "'
            + coordinate
            + '".',
            ErrorCode.CONTEXT_NOT_SET,
        )
        return
    var merged = context.merged_type(type_name)
    for interface in context.merged[merged].interfaces.copy():
        var interface_name = String(context.document.name(interface))
        var found = context.merged_type(interface_name)
        # A subgraph that implements an object type raises before the rules
        # run, so a found type is an interface.
        if (
            found != -1
            and context.merged[found].find_field(context.document, field_name)
            != NO_NODE
        ):
            context.report(
                "@fromContext argument cannot be used on a field"
                ' implementing an interface field "'
                + interface_name
                + "."
                + field_name
                + '".',
                ErrorCode.CONTEXT_NOT_SET,
            )
    if context.document.child(argument, Role.DEFAULT_VALUE) != NO_NODE:
        context.report(
            '@fromContext arguments may not have a default value: "'
            + coordinate
            + '".',
            ErrorCode.CONTEXT_NOT_SET,
        )
    var value = argument_value(context.document, node, "field")
    if value == NO_NODE or context.document.kind(value) != Kind.STRING:
        return
    var text = context.document.string_value(value)
    var reference = parse_context_reference(text)
    if not reference or reference.value().selection.byte_length() == 0:
        context.report(
            '@fromContext argument does not reference a context "'
            + text
            + '".',
            ErrorCode.NO_CONTEXT_IN_SELECTION,
        )
        return
    var name = reference.value().context
    var selection = reference.value().selection
    var context_owners = owners.get(name)
    if not context_owners:
        context.report(
            'Context "'
            + name
            + '" is used at location "'
            + coordinate
            + '" but is never set.',
            ErrorCode.CONTEXT_NOT_SET,
        )
        return
    var checker = _Checker(
        name,
        coordinate,
        print_type_node(
            context.document, context.document.child(argument, Role.TYPE)
        ),
    )
    _validate_selection(context, context_owners.value(), checker, selection)
    if not _has_resolvable_key(context, merged):
        context.report(
            'Object "'
            + type_name
            + '" has no resolvable key but has a field with a contextual'
            " argument.",
            ErrorCode.CONTEXT_NO_RESOLVABLE_KEY,
        )
    var at = context.state.object_field(type_name, field_name)
    ref field = context.state.types[at.type].fields[at.field]
    field.args[field.arg(argument_name)].from_context = FromContext(
        name, selection
    )

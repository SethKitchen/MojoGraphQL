# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The rules of the field set directives: `@key`, `@provides` and
`@requires`.

Port of Hive Federation Composition v0.27.0
`src/subgraph/validation/rules/elements/key.ts`, `provides.ts` and
`requires.ts`. The callbacks that each rule gives `visitFields` are one
`FieldSetHandler` here, with the rule as its mode.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_language.error import GraphQLError
from gql_composition.context import SubgraphContext
from gql_composition.error_code import ErrorCode
from gql_composition.helpers import (
    FieldsHandler,
    ON_ARGUMENTS,
    ON_DIRECTIVE,
    ON_EXTERNAL_FIELD,
    ON_FIELD,
    ON_INTERFACE_TYPE,
    ON_MISSING_SELECTION_SET,
    ON_NON_EXTERNAL_FIELD,
    ON_UNKNOWN_FIELD,
    fields_argument,
    named_type_node,
    parse_fields,
    selection_set_of,
    visit_fields,
)
from gql_composition.printer import print_node
from gql_composition.state import Key, StringSet

comptime _KEY = 0
comptime _PROVIDES = 1
comptime _REQUIRES = 2
comptime _KEY_MATCH = 3


struct _FieldSetHandler(FieldsHandler, Movable):
    """The `visitFields` callbacks of one rule."""

    var mode: Int
    var prefix: String
    var type_name: String
    var field: String
    var valid: Bool
    var used: StringSet
    var from_extension: Bool

    def __init__(
        out self, mode: Int, prefix: String, type_name: String, field: String
    ):
        self.mode = mode
        self.prefix = prefix
        self.type_name = type_name
        self.field = field
        self.valid = True
        self.used = StringSet()
        self.from_extension = False

    def mask(self) -> Int:
        if self.mode == _KEY:
            return (
                ON_FIELD
                | ON_UNKNOWN_FIELD
                | ON_DIRECTIVE
                | ON_ARGUMENTS
                | ON_INTERFACE_TYPE
            )
        if self.mode == _PROVIDES:
            return (
                ON_FIELD
                | ON_MISSING_SELECTION_SET
                | ON_UNKNOWN_FIELD
                | ON_DIRECTIVE
                | ON_ARGUMENTS
                | ON_NON_EXTERNAL_FIELD
                | ON_EXTERNAL_FIELD
            )
        if self.mode == _REQUIRES:
            return (
                ON_FIELD
                | ON_UNKNOWN_FIELD
                | ON_DIRECTIVE
                | ON_NON_EXTERNAL_FIELD
            )
        return ON_FIELD

    def _rule(self) -> String:
        if self.mode == _KEY:
            return String("key")
        if self.mode == _PROVIDES:
            return String("provides")
        return String("requires")

    def on_field(
        mut self, mut context: SubgraphContext, type: Int, field: String
    ) raises:
        var name = context.merged[type].name
        var is_object = context.merged[type].is_object()
        if self.mode == _KEY:
            if name == self.type_name:
                self.used.add(field)
            context.marked_as_key_field.add(name + "." + field)
        elif self.mode == _KEY_MATCH:
            if name == self.type_name and field == self.field and is_object:
                self.from_extension = self.from_extension or _is_extension(
                    context, type
                )
        elif is_object and not context.state.is_interface_object(name):
            var at = context.state.object_field(name, field)
            if self.mode == _PROVIDES:
                context.state.types[at.type].fields[at.field].provided = True
            else:
                context.state.types[at.type].fields[at.field].required = True

    def on_other(
        mut self,
        mut context: SubgraphContext,
        event: Int,
        type: Int,
        field: String,
        detail: String,
    ) raises:
        var rule = self._rule()
        if event == ON_DIRECTIVE:
            self.valid = False
            if detail == "known":
                var code = ErrorCode.KEY_DIRECTIVE_IN_FIELDS_ARG
                if self.mode == _PROVIDES:
                    code = ErrorCode.PROVIDES_DIRECTIVE_IN_FIELDS_ARG
                elif self.mode == _REQUIRES:
                    code = ErrorCode.REQUIRES_DIRECTIVE_IN_FIELDS_ARG
                context.report(
                    self.prefix
                    + "cannot have directive applications in the @"
                    + rule
                    + "(fields:) argument but found @"
                    + field
                    + ".",
                    code,
                )
            else:
                var tail = String("")
                if self.mode != _KEY:
                    tail = " in selection"
                context.report(
                    self.prefix + 'Unknown directive "@' + field + '"' + tail,
                    self._invalid_fields(),
                )
            return
        var owner = context.merged[type].name
        if event == ON_EXTERNAL_FIELD:
            _check_external_key(context, self, type, field)
            return
        if event == ON_NON_EXTERNAL_FIELD:
            if context.version.above(100):
                self.valid = False
                var code = ErrorCode.PROVIDES_FIELDS_MISSING_EXTERNAL
                if self.mode == _REQUIRES:
                    code = ErrorCode.REQUIRES_FIELDS_MISSING_EXTERNAL
                context.report(
                    self.prefix
                    + 'field "'
                    + owner
                    + "."
                    + field
                    + '" should not be part of a @'
                    + rule
                    + " since it is already provided by this subgraph (it is"
                    " not marked @external)",
                    code,
                )
            return
        self.valid = False
        if event == ON_UNKNOWN_FIELD:
            var hint = String(
                " (if the field is defined in another subgraph, you need to"
                " add it to this subgraph with @external)."
            )
            if self.mode == _KEY:
                hint = (
                    " (the field should either be added to this subgraph or,"
                    " if it should not be resolved by this subgraph, you need"
                    " to add it to this subgraph with @external)."
                )
            context.report(
                self.prefix
                + 'Cannot query field "'
                + field
                + '" on type "'
                + owner
                + '"'
                + hint,
                self._invalid_fields(),
            )
        elif event == ON_ARGUMENTS:
            var code = ErrorCode.KEY_FIELDS_HAS_ARGS
            if self.mode == _PROVIDES:
                code = ErrorCode.PROVIDES_FIELDS_HAS_ARGS
            context.report(
                self.prefix
                + "field "
                + owner
                + "."
                + field
                + " cannot be included because it has arguments (fields with"
                " argument are not allowed in @"
                + rule
                + ")",
                code,
            )
        elif event == ON_INTERFACE_TYPE:
            context.report(
                self.prefix
                + 'field "'
                + owner
                + "."
                + field
                + '" is a Interface type which is not allowed in @key',
                ErrorCode.KEY_FIELDS_SELECT_INVALID_TYPE,
            )
        else:
            context.report(
                self.prefix
                + 'Invalid empty selection set for field "'
                + owner
                + "."
                + field
                + '" of non-leaf type '
                + detail,
                ErrorCode.PROVIDES_INVALID_FIELDS,
            )

    def _invalid_fields(self) -> ErrorCode:
        if self.mode == _KEY:
            return ErrorCode.KEY_INVALID_FIELDS
        if self.mode == _PROVIDES:
            return ErrorCode.PROVIDES_INVALID_FIELDS
        return ErrorCode.REQUIRES_INVALID_FIELDS


def _is_extension(context: SubgraphContext, type: Int) -> Bool:
    """Return True for a merged type that is an extension or has
    `@extends`."""
    ref merged = context.merged[type]
    if merged.kind == Kind.OBJECT_TYPE_EXTENSION:
        return True
    # The type has the `@key` that selects the field.
    var index = 0
    while index < len(merged.directives):
        if context.is_available_directive(
            "extends", context.document.name(merged.directives[index])
        ):
            return True
        index += 1
    return False


def _normalized_fields(document: Document, value: Int) -> String:
    """Return a `fields` string, or a list of strings joined by spaces."""
    if document.kind(value) == Kind.STRING:
        return document.string_value(value)
    var parts = List[String]()
    var item = document.first_child(value)
    while item != NO_NODE:
        parts.append(document.string_value(item))
        item = document.next_sibling(item)
    return String(" ").join(parts)


def _is_string_list(document: Document, value: Int) -> Bool:
    """Return True for a list value whose items are all strings."""
    if document.kind(value) != Kind.LIST:
        return False
    var item = document.first_child(value)
    while item != NO_NODE:
        if document.kind(item) != Kind.STRING:
            return False
        item = document.next_sibling(item)
    return True


def _resolvable(document: Document, directive: Int) -> Bool:
    """Return the first boolean `resolvable` argument, or True."""
    var argument = document.first_child(directive)
    while argument != NO_NODE:
        if (
            document.role(argument) == Role.ARGUMENT
            and document.name(argument) == "resolvable"
        ):
            var value = document.child(argument, Role.VALUE)
            if document.kind(value) == Kind.BOOLEAN:
                return document.boolean_value(value)
        argument = document.next_sibling(argument)
    return True


def enter_key(mut context: SubgraphContext, node: Int) raises:
    """Check and record a `@key`, as upstream `KeyRules`.

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
    var on_object = (
        kind == Kind.OBJECT_TYPE_DEFINITION
        or kind == Kind.OBJECT_TYPE_EXTENSION
    )
    var on_interface = (
        kind == Kind.INTERFACE_TYPE_DEFINITION
        or kind == Kind.INTERFACE_TYPE_EXTENSION
        or (on_object and context.state.is_interface_object(name))
    )
    if not on_object and not on_interface:
        return
    if (
        on_interface
        and context.version.above(100)
        and context.version.below(203)
    ):
        context.report(
            'Cannot use @key on interface "'
            + name
            + '": @key is not yet supported on interfaces',
            ErrorCode.KEY_UNSUPPORTED_ON_INTERFACE,
        )
        return
    var argument = fields_argument(context.document, node)
    if argument == NO_NODE:
        return
    var value = context.document.child(argument, Role.VALUE)
    var printed = print_node(context.document, value)
    var prefix = 'On type "' + name + '", for @key(fields: ' + printed + "): "
    if context.document.kind(value) != Kind.STRING and (
        context.version.above(100)
        or not _is_string_list(context.document, value)
    ):
        context.report(
            prefix + 'Invalid value for argument "fields": must be a string.',
            ErrorCode.KEY_INVALID_FIELDS_TYPE,
        )
        return
    var normalized = _normalized_fields(context.document, value)
    var fields: Document
    try:
        fields = parse_fields(normalized)
    except error:
        context.report(prefix + error.message, ErrorCode.KEY_INVALID_FIELDS)
        return
    var handler = _FieldSetHandler(_KEY, prefix, name, "")
    visit_fields(
        context,
        handler,
        fields,
        selection_set_of(fields),
        context.merged_type(name),
        handler.mask(),
    )
    if on_interface:
        _check_implementations(context, handler, printed, name, normalized)
    if not handler.valid:
        return
    var index: Int
    if on_interface:
        index = context.state.interface_type(name)
    else:
        index = context.state.object_type(name)
    ref type = context.state.types[index]
    type.keys.append(Key(normalized, _resolvable(context.document, node)))
    # A valid key selects at least one field of its type.
    var position = 0
    while position < len(handler.used.items):
        type.fields_used_as_keys.add(handler.used.items[position])
        position += 1


def _check_implementations(
    mut context: SubgraphContext,
    mut handler: _FieldSetHandler,
    printed: String,
    name: String,
    expected: String,
):
    """Report each object type that implements the interface without the
    same `@key`."""
    if not context.version.above(100):
        return
    var missing = List[String]()
    # The interface itself is one of the merged types.
    var position = 0
    while position < len(context.merged):
        ref merged = context.merged[position]
        position += 1
        if not merged.is_object() or not merged.implements(
            context.document, name
        ):
            continue
        var found = False
        for directive in merged.directives:
            if not context.is_available_directive(
                "key", context.document.name(directive)
            ):
                continue
            var argument = fields_argument(context.document, directive)
            if argument == NO_NODE:
                continue
            var value = context.document.child(argument, Role.VALUE)
            if (
                context.document.kind(value) == Kind.STRING
                and context.document.string_value(value) == expected
            ):
                found = True
        if not found:
            missing.append(merged.name)
    for ref type_name in missing:
        handler.valid = False
        context.report(
            "Key @key(fields: "
            + printed
            + ') on interface type "'
            + name
            + '" is missing on implementation type "'
            + type_name
            + '".',
            ErrorCode.INTERFACE_KEY_NOT_ON_IMPLEMENTATION,
        )


def _string_fields(document: Document, directive: Int) -> Int:
    """Return the value of the first `fields` argument that is a string,
    or `NO_NODE`."""
    var argument = document.first_child(directive)
    while argument != NO_NODE:
        if (
            document.role(argument) == Role.ARGUMENT
            and document.name(argument) == "fields"
        ):
            var value = document.child(argument, Role.VALUE)
            if document.kind(value) == Kind.STRING:
                return value
        argument = document.next_sibling(argument)
    return NO_NODE


def _check_external_key(
    mut context: SubgraphContext,
    mut handler: _FieldSetHandler,
    type: Int,
    field: String,
) raises:
    """Report an `@external` field of `@provides` that a key of an
    extension type selects, as the upstream `interceptExternalField`."""
    var keys = List[Int]()
    for directive in context.merged[type].directives:
        if context.is_available_directive(
            "key", context.document.name(directive)
        ):
            keys.append(directive)
    var name = context.merged[type].name
    var from_extension = False
    for key in keys:
        if from_extension:
            break
        var value = _string_fields(context.document, key)
        if value == NO_NODE:
            continue
        var fields: Document
        try:
            fields = parse_fields(context.document.string_value(value))
        except error:
            raise Error(error.message)
        var matcher = _FieldSetHandler(_KEY_MATCH, "", name, field)
        visit_fields(
            context,
            matcher,
            fields,
            selection_set_of(fields),
            type,
            matcher.mask(),
        )
        from_extension = matcher.from_extension
    if from_extension and context.version.at_least(200):
        handler.valid = False
        context.report(
            handler.prefix
            + 'field "'
            + name
            + "."
            + field
            + '" should not be part of a @provides since it is already'
            ' "effectively" provided by this subgraph (while it is marked'
            " @external, it is a @key field of an extension type, which are"
            " not internally considered external for historical/backward"
            " compatibility reasons)",
            ErrorCode.PROVIDES_FIELDS_MISSING_EXTERNAL,
        )


def _field_set_prefix(
    context: SubgraphContext, coordinate: String, rule: String, value: Int
) -> String:
    """Return the `On field "T.f", for @rule(fields: ...): ` prefix."""
    return (
        'On field "'
        + coordinate
        + '", for @'
        + rule
        + "(fields: "
        + print_node(context.document, value)
        + "): "
    )


def enter_provides(mut context: SubgraphContext, node: Int) raises:
    """Check and record a `@provides`, as upstream `ProvidesRules`.

    Args:
        context: The context.
        node: The directive.

    Raises:
        Error: When the state has a conflict of kinds, or when a key of the
            target type does not parse.
    """
    var type_def = context.info.type_def
    var field_def = context.info.field_def
    if type_def == NO_NODE or field_def == NO_NODE:
        return
    var type_node = context.document.child(field_def, Role.TYPE)
    var output = String(
        context.document.name(named_type_node(context.document, type_node))
    )
    var target = context.merged_type(output)
    if target == -1:
        var union = context.union_type(output)
        if union != -1:
            var members = context.union_members[union].items.copy()
            # A union has at least one member.
            var position = 0
            while position < len(members):
                _provides_on(
                    context, node, context.merged_type(members[position])
                )
                position += 1
            return
    _provides_on(context, node, target)


def _provides_on(mut context: SubgraphContext, node: Int, target: Int) raises:
    """Check a `@provides` against one target type, as the upstream
    `processTargetType`."""
    var type_def = context.info.type_def
    var field_def = context.info.field_def
    var type_name = String(context.document.name(type_def))
    var field_name = String(context.document.name(field_def))
    var coordinate = type_name + "." + field_name
    var kind = context.document.kind(type_def)
    if target == -1:
        context.report(
            'Invalid @provides directive on field "'
            + coordinate
            + '": field has type "'
            + print_node(
                context.document, context.document.child(field_def, Role.TYPE)
            )
            + '" which is not a Composite Type',
            ErrorCode.PROVIDES_ON_NON_OBJECT_FIELD,
        )
        return
    if (
        kind == Kind.INTERFACE_TYPE_DEFINITION
        or kind == Kind.INTERFACE_TYPE_EXTENSION
    ):
        context.report(
            'Cannot use @provides on field "'
            + coordinate
            + '" of parent type "'
            + type_name
            + '": @provides is not yet supported within interfaces',
            ErrorCode.PROVIDES_UNSUPPORTED_ON_INTERFACE,
        )
        return
    var argument = fields_argument(context.document, node)
    if argument == NO_NODE:
        return
    var value = context.document.child(argument, Role.VALUE)
    var prefix = _field_set_prefix(context, coordinate, "provides", value)
    if context.document.kind(value) != Kind.STRING:
        context.report(
            prefix + 'Invalid value for argument "fields": must be a string.',
            ErrorCode.PROVIDES_INVALID_FIELDS_TYPE,
        )
        return
    var text = context.document.string_value(value)
    var fields: Document
    try:
        fields = parse_fields(text)
    except error:
        context.report(
            prefix + error.message, ErrorCode.PROVIDES_INVALID_FIELDS
        )
        return
    var handler = _FieldSetHandler(_PROVIDES, prefix, "", "")
    visit_fields(
        context,
        handler,
        fields,
        selection_set_of(fields),
        target,
        handler.mask(),
    )
    if handler.valid and not context.state.is_interface_object(type_name):
        var at = context.state.object_field(type_name, field_name)
        context.state.types[at.type].fields[at.field].provides = text


def enter_requires(mut context: SubgraphContext, node: Int) raises:
    """Check and record a `@requires`, as upstream `RequiresRules`.

    Args:
        context: The context.
        node: The directive.

    Raises:
        Error: When the state has a conflict of kinds.
    """
    var type_def = context.info.type_def
    var field_def = context.info.field_def
    if type_def == NO_NODE or field_def == NO_NODE:
        return
    var type_name = String(context.document.name(type_def))
    var field_name = String(context.document.name(field_def))
    var coordinate = type_name + "." + field_name
    var kind = context.document.kind(type_def)
    var on_interface = (
        kind == Kind.INTERFACE_TYPE_DEFINITION
        or kind == Kind.INTERFACE_TYPE_EXTENSION
    )
    if on_interface:
        context.report(
            'Cannot use @requires on field "'
            + coordinate
            + '" of parent type "'
            + type_name
            + '": @requires is not yet supported within interfaces',
            ErrorCode.REQUIRES_UNSUPPORTED_ON_INTERFACE,
        )
        return
    var argument = fields_argument(context.document, node)
    if argument == NO_NODE:
        return
    var value = context.document.child(argument, Role.VALUE)
    var prefix = _field_set_prefix(context, coordinate, "requires", value)
    var value_kind = context.document.kind(value)
    if value_kind != Kind.STRING and value_kind != Kind.ENUM:
        context.report(
            prefix + 'Invalid value for argument "fields": must be a string.',
            ErrorCode.REQUIRES_INVALID_FIELDS_TYPE,
        )
        return
    var text: String
    if value_kind == Kind.STRING:
        text = context.document.string_value(value)
    else:
        text = String(context.document.text(value))
    var fields: Document
    try:
        fields = parse_fields(text)
    except error:
        context.report(
            prefix + error.message, ErrorCode.REQUIRES_INVALID_FIELDS
        )
        return
    # A field definition is in an object type or in an interface type, and
    # the interface case returned above.
    var handler = _FieldSetHandler(_REQUIRES, prefix, "", "")
    visit_fields(
        context,
        handler,
        fields,
        selection_set_of(fields),
        context.merged_type(type_name),
        handler.mask(),
    )
    if handler.valid:
        var at = context.state.entity_field(type_name, field_name)
        context.state.types[at.type].fields[at.field].requires = text

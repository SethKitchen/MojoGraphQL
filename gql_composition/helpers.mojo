# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Helpers of the subgraph rules: field sets and directive definitions.

Port of Hive Federation Composition v0.27.0 `src/subgraph/helpers.ts`:
`visitFields`, `parseFields`, `getFieldsArgument`, `printOutputType`,
`namedTypeFromTypeNode` and `validateDirectiveAgainstOriginal`.

**Differences from upstream.** Upstream `visitFields` takes optional
callbacks. This port takes a `FieldsHandler`, whose `mask` says which
callbacks it has, as upstream checks which callbacks are given.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_language.error import GraphQLError
from gql_language.parser import parse
from gql_composition.context import SubgraphContext
from gql_composition.error_code import ErrorCode
from gql_composition.printer import print_node

comptime ON_FIELD = 1
"""The `interceptField` callback."""
comptime ON_UNKNOWN_FIELD = 2
"""The `interceptUnknownField` callback."""
comptime ON_DIRECTIVE = 4
"""The `interceptDirective` callback."""
comptime ON_ARGUMENTS = 8
"""The `interceptArguments` callback."""
comptime ON_INTERFACE_TYPE = 16
"""The `interceptInterfaceType` callback."""
comptime ON_EXTERNAL_FIELD = 32
"""The `interceptExternalField` callback."""
comptime ON_NON_EXTERNAL_FIELD = 64
"""The `interceptNonExternalField` callback."""
comptime ON_MISSING_SELECTION_SET = 128
"""The `interceptFieldWithMissingSelectionSet` callback."""


trait FieldsHandler:
    """The callbacks of `visit_fields`. Each one gets the merged type of the
    selection and the name of the field."""

    def mask(self) -> Int:
        """Return the callbacks that the handler has, as `ON_*` bits.

        Returns:
            The bits.
        """
        ...

    def on_field(
        mut self, mut context: SubgraphContext, type: Int, field: String
    ) raises:
        """Handle a known field, as `interceptField`.

        Args:
            context: The context.
            type: The merged type, an index into `context.merged`.
            field: The name of the field.

        Raises:
            Error: When the state has a conflict of kinds.
        """
        ...

    def on_other(
        mut self,
        mut context: SubgraphContext,
        event: Int,
        type: Int,
        field: String,
        detail: String,
    ) raises:
        """Handle every other callback.

        Args:
            context: The context.
            event: The `ON_*` bit of the callback.
            type: The merged type, or -1 for `ON_DIRECTIVE`.
            field: The name of the field, or of the directive.
            detail: `known` or empty for `ON_DIRECTIVE`; the printed output
                type for `ON_MISSING_SELECTION_SET`.

        Raises:
            Error: When the state has a conflict of kinds.
        """
        ...


def named_type_node(document: Document, node: Int) -> Int:
    """Return the `NamedType` under the list and non-null wrappers, as
    upstream `namedTypeFromTypeNode`.

    Args:
        document: The document.
        node: A type reference.

    Returns:
        The `NamedType` node.
    """
    var current = node
    while document.kind(current) != Kind.NAMED_TYPE:
        current = document.first_child(current)
    return current


def fields_argument(document: Document, directive: Int) -> Int:
    """Return the first `fields` argument of a directive, as upstream
    `getFieldsArgument`.

    Args:
        document: The document.
        directive: The directive.

    Returns:
        The `Argument` node, or `NO_NODE`.
    """
    var argument = document.first_child(directive)
    while argument != NO_NODE:
        if (
            document.role(argument) == Role.ARGUMENT
            and document.name(argument) == "fields"
        ):
            return argument
        argument = document.next_sibling(argument)
    return NO_NODE


def parse_fields(fields: String) raises GraphQLError -> Document:
    """Parse a field set, as upstream `parseFields`.

    Args:
        fields: Such as `id name` or `{ id }`.

    Returns:
        A document whose first definition is an operation; its selection
        set holds the fields.

    Raises:
        GraphQLError: The syntax error of the field set.
    """
    if fields.strip().startswith("{"):
        return parse("query " + fields)
    return parse("query { " + fields + " }")


def selection_set_of(document: Document) -> Int:
    """Return the selection set of the first definition of a field set
    document.

    Args:
        document: A document from `parse_fields`.

    Returns:
        The `SelectionSet` node.
    """
    return document.child(
        document.first_child(document.root), Role.SELECTION_SET
    )


def _has_external(context: SubgraphContext, directives: List[Int]) -> Bool:
    """Return True if a directive of a list is the federation
    `@external`."""
    for directive in directives:
        if context.is_available_directive(
            "external", context.document.name(directive)
        ):
            return True
    return False


def _directives_of(document: Document, node: Int) -> List[Int]:
    """Return the directive children of a node."""
    var out = List[Int]()
    var child = document.first_child(node)
    while child != NO_NODE:
        if document.role(child) == Role.DIRECTIVE:
            out.append(child)
        child = document.next_sibling(child)
    return out^


def visit_fields[
    H: FieldsHandler
](
    mut context: SubgraphContext,
    mut handler: H,
    fields: Document,
    selection_set: Int,
    type: Int,
    mask: Int,
) raises:
    """Walk a field set over a merged type, as upstream `visitFields`.

    Parameters:
        H: The type of the callbacks.

    Args:
        context: The context.
        handler: The callbacks.
        fields: The parsed field set.
        selection_set: A selection set of `fields`.
        type: The merged type, an index into `context.merged`.
        mask: The callbacks to call, as `ON_*` bits.

    Raises:
        Error: When the state has a conflict of kinds.
    """
    var selection = fields.first_child(selection_set)
    while selection != NO_NODE:
        var kind = fields.kind(selection)
        if kind == Kind.FRAGMENT_SPREAD:
            selection = fields.next_sibling(selection)
            continue
        if kind == Kind.INLINE_FRAGMENT:
            var condition = fields.child(selection, Role.TYPE_CONDITION)
            if condition != NO_NODE:
                var inner = context.merged_type(fields.name(condition))
                if inner != -1:
                    visit_fields(
                        context,
                        handler,
                        fields,
                        fields.child(selection, Role.SELECTION_SET),
                        inner,
                        mask
                        & (ON_ARGUMENTS | ON_UNKNOWN_FIELD | ON_INTERFACE_TYPE),
                    )
            selection = fields.next_sibling(selection)
            continue
        var name = String(fields.name(selection))
        if name == "__typename":
            selection = fields.next_sibling(selection)
            continue
        var type_name = context.merged[type].name
        var is_interface = context.merged[type].is_interface()
        var field_def = context.merged[type].find_field(context.document, name)
        if field_def == NO_NODE:
            if mask & ON_UNKNOWN_FIELD != 0:
                handler.on_other(context, ON_UNKNOWN_FIELD, type, name, "")
            break
        if mask & ON_DIRECTIVE != 0:
            for directive in _directives_of(fields, selection):
                var directive_name = String(fields.name(directive))
                var known = directive_name in context.directive_definitions
                handler.on_other(
                    context,
                    ON_DIRECTIVE,
                    -1,
                    directive_name,
                    String("known") if known else String(""),
                )
        context.mark_as_used(True, is_interface, type_name, name)
        if mask & ON_FIELD != 0:
            handler.on_field(context, type, name)
        ref document = context.document
        if (
            document.child(field_def, Role.ARGUMENT) != NO_NODE
            and mask & ON_ARGUMENTS != 0
        ):
            handler.on_other(context, ON_ARGUMENTS, type, name, "")
            selection = fields.next_sibling(selection)
            continue
        var output = String(
            document.name(
                named_type_node(document, document.child(field_def, Role.TYPE))
            )
        )
        if mask & (ON_EXTERNAL_FIELD | ON_NON_EXTERNAL_FIELD) != 0:
            if context.is_leaf_type(output):
                var external = _has_external(
                    context, _directives_of(context.document, field_def)
                ) or _has_external(context, context.merged[type].directives)
                if external and mask & ON_EXTERNAL_FIELD != 0:
                    handler.on_other(context, ON_EXTERNAL_FIELD, type, name, "")
                elif not external and mask & ON_NON_EXTERNAL_FIELD != 0:
                    handler.on_other(
                        context, ON_NON_EXTERNAL_FIELD, type, name, ""
                    )
        var inner = context.merged_type(output)
        if inner != -1:
            _visit_inner(
                context,
                handler,
                fields,
                selection,
                field_def,
                type,
                inner,
                mask,
            )
        else:
            var union = context.union_type(output)
            if union != -1:
                var members = context.union_members[union].items.copy()
                for member in members:
                    var member_type = context.merged_type(member)
                    if member_type != -1:
                        _visit_inner(
                            context,
                            handler,
                            fields,
                            selection,
                            field_def,
                            type,
                            member_type,
                            mask,
                        )
        selection = fields.next_sibling(selection)


def _visit_inner[
    H: FieldsHandler
](
    mut context: SubgraphContext,
    mut handler: H,
    fields: Document,
    selection: Int,
    field_def: Int,
    type: Int,
    inner: Int,
    mask: Int,
) raises:
    """Visit the selection of a field over one possible type, as the
    upstream `handleInnerSelection`."""
    var name = String(fields.name(selection))
    if mask & ON_INTERFACE_TYPE != 0 and context.merged[inner].is_interface():
        handler.on_other(context, ON_INTERFACE_TYPE, type, name, "")
    var inner_selection = fields.child(selection, Role.SELECTION_SET)
    if inner_selection == NO_NODE:
        if mask & ON_MISSING_SELECTION_SET != 0:
            handler.on_other(
                context,
                ON_MISSING_SELECTION_SET,
                type,
                name,
                print_node(
                    context.document,
                    context.document.child(field_def, Role.TYPE),
                ),
            )
        return
    visit_fields(
        context,
        handler,
        fields,
        inner_selection,
        inner,
        mask & ~ON_NON_EXTERNAL_FIELD,
    )


def _field_set_types(v2: Bool) -> List[String]:
    """Return the field set types that upstream accepts in a definition."""
    if v2:
        return [
            String("FieldSet!"),
            String("federation__FieldSet!"),
            String("_FieldSet!"),
            String("[String!]!"),
        ]
    return [String("_FieldSet!"), String("String"), String("String!")]


def _spec_field_set_types(v2: Bool) -> List[String]:
    """Return the field set types that upstream finds in the
    specification."""
    if v2:
        return _field_set_types(True)
    return [String("_FieldSet!"), String("FieldSet!"), String("String")]


def _holds(items: List[String], item: String) -> Bool:
    """Return True if a list holds a string."""
    for ref existing in items:
        if existing == item:
            return True
    return False


def validate_directive_against_original(
    mut context: SubgraphContext, definition: Int, spec_name: String
) raises:
    """Compare a directive definition of the subgraph with the federation
    directive that it replaces, as upstream
    `validateDirectiveAgainstOriginal`.

    Args:
        context: The context.
        definition: A `DirectiveDefinition` of the subgraph.
        spec_name: The name of the federation directive, such as `key`.

    Raises:
        Error: `Expected a Boolean` for a non-boolean default value of a
            boolean argument, as upstream throws.
    """
    ref document = context.document
    var provided_name = String(document.name(definition))
    if not context.is_available_directive(spec_name, provided_name):
        return
    var v2 = context.version.at_least(200)
    var original = -1
    for index in range(len(context.known.directives)):
        if context.is_available_directive(
            spec_name, context.known.directives[index].name
        ):
            original = index
            break
    if original == -1:
        raise Error("Federation directive @" + spec_name + " not found")
    var prefix = 'Invalid definition for directive "@' + spec_name + '": '
    var messages = List[String]()
    var arguments = context.known.directives[original].arguments.copy()
    for ref argument in arguments:
        var provided = NO_NODE
        var child = document.first_child(definition)
        while child != NO_NODE:
            if (
                document.role(child) == Role.ARGUMENT
                and document.name(child) == argument.name
            ):
                provided = child
            child = document.next_sibling(child)
        if argument.non_null and provided == NO_NODE:
            messages.append(
                prefix + 'missing required argument "' + argument.name + '"'
            )
        if provided == NO_NODE:
            continue
        var provided_type = print_node(
            document, document.child(provided, Role.TYPE)
        )
        if (
            argument.type != provided_type
            and provided_type != "String!"
            and _holds(_spec_field_set_types(v2), argument.type)
        ):
            var allowed = _field_set_types(v2)
            var accepted = _holds(allowed, provided_type)
            for ref item in allowed:
                if "[" + item + "]!" == provided_type:
                    accepted = True
            if not accepted:
                messages.append(
                    prefix
                    + 'argument "'
                    + argument.name
                    + '" should have type "'
                    + argument.type
                    + '" but found type "'
                    + provided_type
                    + '"'
                )
        if argument.type == "Boolean" and argument.boolean_default != -1:
            var provided_value = -1
            var default = document.child(provided, Role.DEFAULT_VALUE)
            if default != NO_NODE:
                if document.kind(default) != Kind.BOOLEAN:
                    raise Error("Expected a Boolean")
                provided_value = Int(document.boolean_value(default))
            if provided_value != argument.boolean_default:
                var shown = String("null")
                if provided_value != -1:
                    shown = String("true") if provided_value == 1 else String(
                        "false"
                    )
                messages.append(
                    prefix
                    + 'argument "'
                    + argument.name
                    + '" should have default value true but found default'
                    + " value "
                    + shown
                )
    var expected = context.known.directives[original].locations.copy()
    var found = List[String]()
    var overlap = False
    var location = document.first_child(definition)
    while location != NO_NODE:
        if document.role(location) == Role.LOCATION:
            var text = String(document.text(location))
            if _holds(expected, text):
                overlap = True
            found.append(text^)
        location = document.next_sibling(location)
    if not overlap:
        messages.append(
            prefix
            + '"@'
            + spec_name
            + '" should have locations '
            + String(", ").join(expected)
            + ", but found (non-subset) "
            + String(", ").join(found)
        )
    if len(messages) == 0:
        context.replacements.add(provided_name)
        return
    for ref message in messages:
        context.report(message, ErrorCode.DIRECTIVE_DEFINITION_INVALID)


def argument_value(
    document: Document, directive: Int, name: StringSlice
) -> Int:
    """Return the value of the first argument with a name, as upstream
    `node.arguments?.find((arg) => arg.name.value === name)?.value`.

    Args:
        document: The document.
        directive: A directive or field.
        name: The name of the argument.

    Returns:
        The value node, or `NO_NODE`.
    """
    var argument = document.first_child(directive)
    while argument != NO_NODE:
        if (
            document.role(argument) == Role.ARGUMENT
            and document.name(argument) == name
        ):
            return document.child(argument, Role.VALUE)
        argument = document.next_sibling(argument)
    return NO_NODE

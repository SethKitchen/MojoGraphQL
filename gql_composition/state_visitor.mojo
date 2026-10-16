# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The visitor that builds the state of a subgraph during the walk.

Port of the `visitor` of `createSubgraphStateBuilder` in Hive Federation
Composition v0.27.0 `src/subgraph/state.ts`.

**Differences from upstream.** Upstream visits every `StringValue` and
compares its parent with the definitions. This port reads only the strings
with the `DESCRIPTION` role, which are the ones upstream keeps.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_composition.context import SubgraphContext
from gql_composition.federation_spec import is_specified_scalar
from gql_composition.helpers import argument_value, named_type_node
from gql_composition.printer import print_node
from gql_composition.state import (
    Deprecated,
    Description,
    ExtensionType,
    RootKind,
    TypeKind,
)
from gql_composition.version import FederationVersion


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


def _is_input_object(kind: Kind) -> Bool:
    """Return True for an input object type definition or extension."""
    return (
        kind == Kind.INPUT_OBJECT_TYPE_DEFINITION
        or kind == Kind.INPUT_OBJECT_TYPE_EXTENSION
    )


def _set_enum_reference(
    mut context: SubgraphContext,
    enum_name: String,
    coordinate: String,
    input: Bool,
) raises:
    """Record that an enum type is used at a schema coordinate, as upstream
    `setReferencedByInputType` and `setReferencedByOutputType`."""
    var index = context.state.get_or_create(
        TypeKind.ENUM, enum_name, "an enum type"
    )
    ref type = context.state.types[index]
    if input:
        type.referenced_by_input_type = True
        type.input_type_references.add(coordinate)
    else:
        type.referenced_by_output_type = True
        type.output_type_references.add(coordinate)


def enter_field_definition(mut context: SubgraphContext, node: Int) raises:
    """Add a field to the state, as the upstream `FieldDefinition` visitor.

    Args:
        context: The context.
        node: The `FieldDefinition`.

    Raises:
        Error: When the state has a conflict of kinds.
    """
    ref document = context.document
    var type_def = context.info.type_def
    var type_kind = document.kind(type_def)
    var type_name = String(document.name(type_def))
    var field_name = String(document.name(node))
    var type_node = document.child(node, Role.TYPE)
    var printed = print_node(document, type_node)
    var output = String(document.name(named_type_node(document, type_node)))
    var is_leaf = (
        is_specified_scalar(output)
        or output in context.state.enum_names
        or output in context.state.scalar_names
    )
    if output in context.state.enum_names:
        _set_enum_reference(
            context, output, type_name + "." + field_name, False
        )
    if _is_interface(type_kind) or context.state.is_interface_object(type_name):
        var at = context.state.interface_field(type_name, field_name)
        ref field = context.state.types[at.type].fields[at.field]
        field.type = printed
        field.used = True
        if is_leaf:
            field.is_leaf = True
        return
    var at = context.state.object_field(type_name, field_name)
    ref field = context.state.types[at.type].fields[at.field]
    field.type = printed
    if is_leaf:
        field.is_leaf = True
    if type_kind == Kind.OBJECT_TYPE_EXTENSION:
        field.extension = True
    if context.version == FederationVersion.V1_0 and (
        type_kind == Kind.OBJECT_TYPE_DEFINITION
        or type_name == context.state.expected_roots[0]
        or type_name == context.state.expected_roots[1]
        or type_name == context.state.expected_roots[2]
    ):
        field.shareable = True


def enter_input_value_definition(
    mut context: SubgraphContext, node: Int
) raises:
    """Add an input field or a field argument to the state, as the
    upstream `InputValueDefinition` visitor.

    Args:
        context: The context.
        node: The `InputValueDefinition`.

    Raises:
        Error: When the state has a conflict of kinds.
    """
    var type_def = context.info.type_def
    var field_def = context.info.field_def
    if type_def == NO_NODE:
        return
    ref document = context.document
    var type_kind = document.kind(type_def)
    var type_name = String(document.name(type_def))
    var name = String(document.name(node))
    var type_node = document.child(node, Role.TYPE)
    var printed = print_node(document, type_node)
    var output = String(document.name(named_type_node(document, type_node)))
    var references_enum = output in context.state.enum_names
    var kind = context.state.argument_kind(output)
    var default_node = document.child(node, Role.DEFAULT_VALUE)
    var default = Optional[String](None)
    if default_node != NO_NODE:
        default = print_node(document, default_node)
    if _is_input_object(type_kind):
        var at = context.state.input_value_at(
            TypeKind.INPUT_OBJECT, type_name, name
        )
        ref field = context.state.types[at.type].input_fields[at.field]
        field.type = printed
        field.kind = kind
        if references_enum:
            _set_enum_reference(context, output, type_name + "." + name, True)
        if default:
            context.state.types[at.type].input_fields[
                at.field
            ].default_value = default
        return
    if field_def == NO_NODE or (
        not _is_object(type_kind) and not _is_interface(type_kind)
    ):
        return
    var field_name = String(document.name(field_def))
    var at = context.state.owner_field(
        type_name, field_name, _is_interface(type_kind)
    )
    var arg = context.state.arg_index(at, name)
    ref argument = context.state.types[at.type].fields[at.field].args[arg]
    argument.type = printed
    argument.kind = kind
    if default:
        argument.default_value = default
    if references_enum and _is_object(type_kind):
        _set_enum_reference(
            context,
            output,
            type_name + "." + field_name + "(" + name + ":)",
            True,
        )


def _add_interfaces(
    mut context: SubgraphContext, node: Int, type_name: String, as_object: Bool
) raises:
    """Add the implemented interfaces of a type, as upstream
    `setInterface`."""
    ref document = context.document
    var child = document.first_child(node)
    while child != NO_NODE:
        if document.role(child) == Role.INTERFACE:
            var interface_name = String(document.name(child))
            if as_object and not context.state.is_interface_object(type_name):
                var index = context.state.object_type(type_name)
                context.state.types[index].interfaces.add(interface_name)
                var interface = context.state.interface_type(interface_name)
                context.state.types[interface].implemented_by.add(type_name)
            else:
                var index = context.state.interface_type(type_name)
                context.state.types[index].interfaces.add(interface_name)
        child = document.next_sibling(child)


def _set_roots(mut context: SubgraphContext, type_name: String):
    """Set the root type that a type name is, as the upstream object type
    visitors."""
    var renamed = context.state.rename_object_type(type_name)
    if type_name == context.state.expected_roots[0]:
        context.state.set_root(RootKind.QUERY, renamed)
    elif type_name == context.state.expected_roots[1]:
        context.state.set_root(RootKind.MUTATION, renamed)
    elif type_name == context.state.expected_roots[2]:
        context.state.set_root(RootKind.SUBSCRIPTION, renamed)


def _has_interface_object_directive(document: Document, node: Int) -> Bool:
    """Return True if a type has a directive named `interfaceObject`, as
    upstream `hasInterfaceObjectDirective`."""
    var child = document.first_child(node)
    while child != NO_NODE:
        if (
            document.role(child) == Role.DIRECTIVE
            and document.name(child) == "interfaceObject"
        ):
            return True
        child = document.next_sibling(child)
    return False


def enter_type_definition(mut context: SubgraphContext, node: Int) raises:
    """Add a type definition or extension to the state, as the upstream
    type visitors.

    Args:
        context: The context.
        node: A type definition or extension.

    Raises:
        Error: When the state has a conflict of kinds.
    """
    var kind = context.document.kind(node)
    var name = String(context.document.name(node))
    if kind == Kind.OBJECT_TYPE_DEFINITION:
        if _has_interface_object_directive(context.document, node):
            var index = context.state.interface_type(name)
            context.state.types[index].is_definition = True
            context.state.types[index].is_interface_object = True
            _add_interfaces(context, node, name, False)
            return
        if context.state.is_interface_object(name):
            context.state.types[
                context.state.interface_type(name)
            ].is_definition = True
        else:
            context.state.types[
                context.state.object_type(name)
            ].is_definition = True
        _set_roots(context, name)
        _add_interfaces(context, node, name, True)
    elif kind == Kind.OBJECT_TYPE_EXTENSION:
        _set_roots(context, name)
        set_object_extension(context, name, ExtensionType.EXTEND)
        _add_interfaces(context, node, name, True)
    elif kind == Kind.INTERFACE_TYPE_DEFINITION:
        context.state.types[
            context.state.interface_type(name)
        ].is_definition = True
        _add_interfaces(context, node, name, False)
    elif kind == Kind.INTERFACE_TYPE_EXTENSION:
        if context.state.version != FederationVersion.V1_0:
            context.state.types[
                context.state.interface_type(name)
            ].extension = True
        _add_interfaces(context, node, name, False)
    elif (
        kind == Kind.UNION_TYPE_DEFINITION or kind == Kind.UNION_TYPE_EXTENSION
    ):
        var index = context.state.get_or_create(
            TypeKind.UNION, name, "a union type"
        )
        if kind == Kind.UNION_TYPE_DEFINITION:
            context.state.types[index].is_definition = True
        var member = context.document.first_child(node)
        while member != NO_NODE:
            if context.document.role(member) == Role.MEMBER_TYPE:
                var member_name = String(context.document.name(member))
                context.state.types[index].members.add(member_name)
            member = context.document.next_sibling(member)
    elif kind == Kind.ENUM_TYPE_DEFINITION:
        var index = context.state.get_or_create(
            TypeKind.ENUM, name, "an enum type"
        )
        context.state.types[index].is_definition = True
    elif kind == Kind.INPUT_OBJECT_TYPE_DEFINITION:
        var index = context.state.get_or_create(
            TypeKind.INPUT_OBJECT, name, "an input object type"
        )
        context.state.types[index].is_definition = True
    elif kind == Kind.SCALAR_TYPE_DEFINITION and not is_specified_scalar(name):
        _ = context.state.get_or_create(TypeKind.SCALAR, name, "a scalar type")


def set_object_extension(
    mut context: SubgraphContext, name: String, extension: ExtensionType
) raises:
    """Mark an object type as an extension, as upstream
    `objectType.setExtension`; an `@interfaceObject` marks its interface.

    Args:
        context: The context.
        name: The name of the type.
        extension: `EXTENDS` for `@extends`, `EXTEND` for `extend type`.

    Raises:
        Error: When the state has a conflict of kinds.
    """
    ref state = context.state
    if state.is_interface_object(name):
        state.types[state.interface_type(name)].extension = True
        return
    var index = state.object_type(name)
    state.types[index].extension = True
    if state.types[index].extension_type != ExtensionType.EXTENDS:
        state.types[index].extension_type = extension


def enter_enum_value_definition(mut context: SubgraphContext, node: Int) raises:
    """Add an enum value to the state, as the upstream
    `EnumValueDefinition` visitor.

    Args:
        context: The context.
        node: The `EnumValueDefinition`.

    Raises:
        Error: When the state has a conflict of kinds.
    """
    var type_def = context.info.type_def
    _ = context.state.enum_value_at(
        String(context.document.name(type_def)),
        String(context.document.name(node)),
    )


def enter_directive_definition(mut context: SubgraphContext, node: Int) raises:
    """Add a directive definition to the state, as the upstream
    `DirectiveDefinition` visitor.

    Args:
        context: The context.
        node: The `DirectiveDefinition`.

    Raises:
        Error: When the state has a conflict of kinds.
    """
    ref document = context.document
    var name = String(document.name(node))
    ref state = context.state
    if document.is_repeatable(node):
        var index = state.get_or_create(TypeKind.DIRECTIVE, name, "a directive")
        state.types[index].repeatable = True
    var child = document.first_child(node)
    while child != NO_NODE:
        var role = document.role(child)
        if role == Role.LOCATION:
            var index = state.get_or_create(
                TypeKind.DIRECTIVE, name, "a directive"
            )
            state.types[index].locations.add(String(document.text(child)))
        elif role == Role.ARGUMENT:
            var type_node = document.child(child, Role.TYPE)
            var at = state.input_value_at(
                TypeKind.DIRECTIVE, name, String(document.name(child))
            )
            ref argument = state.types[at.type].input_fields[at.field]
            argument.type = print_node(document, type_node)
            argument.kind = state.argument_kind(
                String(document.name(named_type_node(document, type_node)))
            )
            var default = document.child(child, Role.DEFAULT_VALUE)
            if default != NO_NODE:
                argument.default_value = print_node(document, default)
        child = document.next_sibling(child)


def enter_description(
    mut context: SubgraphContext, node: Int, parent: Int
) raises:
    """Set a description in the state, as the upstream `StringValue`
    visitor.

    Args:
        context: The context.
        node: A `StringValue` with the `DESCRIPTION` role.
        parent: The node that it describes.

    Raises:
        Error: When the state has a conflict of kinds.
    """
    var parent_kind = context.document.kind(parent)
    var description = Description(
        context.document.string_value(node), context.document.is_block(node)
    )
    if (
        parent_kind == Kind.SCALAR_TYPE_DEFINITION
        or parent_kind == Kind.SCALAR_TYPE_EXTENSION
    ):
        var name = String(context.document.name(parent))
        var index = context.state.get_or_create(
            TypeKind.SCALAR, name, "a scalar type"
        )
        context.state.types[index].description = description^
        return
    var type_def = context.info.type_def
    if type_def == NO_NODE:
        return
    var kind = context.document.kind(type_def)
    var type_name = String(context.document.name(type_def))
    var parent_name = String(context.document.name(parent))
    if _is_object(kind) or _is_interface(kind):
        var interface = _is_interface(kind)
        var arg_def = context.info.arg_def
        var field_def = context.info.field_def
        if arg_def != NO_NODE and arg_def == parent:
            var field_name = String(context.document.name(field_def))
            var at = context.state.owner_field(type_name, field_name, interface)
            var arg = context.state.arg_index(at, parent_name)
            context.state.types[at.type].fields[at.field].args[
                arg
            ].description = (description^)
        elif field_def != NO_NODE and field_def == parent:
            var at = context.state.owner_field(
                type_name, parent_name, interface
            )
            context.state.types[at.type].fields[at.field].description = (
                description^
            )
        elif type_def == parent:
            var index: Int
            if interface or context.state.is_interface_object(type_name):
                index = context.state.interface_type(type_name)
            else:
                index = context.state.object_type(type_name)
            context.state.types[index].description = description^
    elif _is_input_object(kind):
        if (
            context.info.field_def != NO_NODE
            and context.info.field_def == parent
        ):
            var at = context.state.input_value_at(
                TypeKind.INPUT_OBJECT, type_name, parent_name
            )
            context.state.types[at.type].input_fields[at.field].description = (
                description^
            )
        elif type_def == parent:
            var index = context.state.get_or_create(
                TypeKind.INPUT_OBJECT, type_name, "an input object type"
            )
            context.state.types[index].description = description^
    elif kind == Kind.ENUM_TYPE_DEFINITION or kind == Kind.ENUM_TYPE_EXTENSION:
        if parent_kind == Kind.ENUM_VALUE_DEFINITION:
            var at = context.state.enum_value_at(type_name, parent_name)
            context.state.types[at.type].values[at.field].description = (
                description^
            )
        elif type_def == parent:
            var index = context.state.get_or_create(
                TypeKind.ENUM, type_name, "an enum type"
            )
            context.state.types[index].description = description^
    elif (
        kind == Kind.UNION_TYPE_DEFINITION or kind == Kind.UNION_TYPE_EXTENSION
    ):
        if type_def == parent:
            var index = context.state.get_or_create(
                TypeKind.UNION, type_name, "a union type"
            )
            context.state.types[index].description = description^


def enter_directive(mut context: SubgraphContext, node: Int) raises:
    """Record a directive in the state, as the upstream `Directive`
    visitor: a composed directive, `@specifiedBy`, `@deprecated` and
    `@oneOf`.

    Args:
        context: The context.
        node: The `Directive`.

    Raises:
        Error: When the state has a conflict of kinds.
    """
    var name = String(context.document.name(node))
    var type_def = context.info.type_def
    if type_def == NO_NODE:
        return
    var kind = context.document.kind(type_def)
    var type_name = String(context.document.name(type_def))
    var field_def = context.info.field_def
    var field_name = String("")
    if field_def != NO_NODE:
        field_name = String(context.document.name(field_def))
    if context.state.composed_directives.contains(name):
        _add_composed(context, node, kind, type_name, field_name)
    elif name == "specifiedBy":
        if (
            kind == Kind.SCALAR_TYPE_DEFINITION
            or kind == Kind.SCALAR_TYPE_EXTENSION
        ):
            var url = argument_value(context.document, node, "url")
            if url != NO_NODE and context.document.kind(url) == Kind.STRING:
                var index = context.state.get_or_create(
                    TypeKind.SCALAR, type_name, "a scalar type"
                )
                context.state.types[
                    index
                ].specified_by = context.document.string_value(url)
    elif name == "deprecated":
        var reason_node = argument_value(context.document, node, "reason")
        var reason = Optional[String](None)
        if (
            reason_node != NO_NODE
            and context.document.kind(reason_node) == Kind.STRING
        ):
            reason = context.document.string_value(reason_node)
        _set_deprecated(context, kind, type_name, field_name, reason^)
    elif name == "oneOf" and _is_input_object(kind):
        _set_one_of(context, type_name)


def _set_deprecated(
    mut context: SubgraphContext,
    kind: Kind,
    type_name: String,
    field_name: String,
    var reason: Optional[String],
) raises:
    """Set `@deprecated` on what the walk is in."""
    var deprecated = Deprecated(reason^)
    if kind == Kind.ENUM_TYPE_DEFINITION or kind == Kind.ENUM_TYPE_EXTENSION:
        var value_def = context.info.value_def
        if value_def == NO_NODE:
            return
        var at = context.state.enum_value_at(
            type_name, String(context.document.name(value_def))
        )
        context.state.types[at.type].values[at.field].deprecated = deprecated^
        return
    if field_name.byte_length() == 0:
        return
    if _is_input_object(kind):
        var at = context.state.input_value_at(
            TypeKind.INPUT_OBJECT, type_name, field_name
        )
        context.state.types[at.type].input_fields[at.field].deprecated = (
            deprecated^
        )
        return
    if not _is_object(kind) and not _is_interface(kind):
        return
    var at = context.state.owner_field(
        type_name, field_name, _is_interface(kind)
    )
    var arg_def = context.info.arg_def
    if arg_def != NO_NODE:
        var arg = context.state.arg_index(
            at, String(context.document.name(arg_def))
        )
        context.state.types[at.type].fields[at.field].args[arg].deprecated = (
            deprecated^
        )
        return
    context.state.types[at.type].fields[at.field].deprecated = deprecated^


def _set_one_of(mut context: SubgraphContext, type_name: String) raises:
    """Mark an input object type as `@oneOf`, as upstream `setOneOf`."""
    var existing = context.state.find_type("oneOf")
    if existing == -1:
        var index = context.state.get_or_create(
            TypeKind.DIRECTIVE, "oneOf", "a directive"
        )
        context.state.types[index].locations.add("INPUT_OBJECT")
        context.state.types[index].composed = True
    else:
        ref directive = context.state.types[existing]
        if not (
            directive.kind == TypeKind.DIRECTIVE
            and len(directive.locations) == 1
            and directive.locations.contains("INPUT_OBJECT")
            and not directive.repeatable
            and len(directive.input_fields) == 0
        ):
            return
        directive.composed = True
    var input = context.state.get_or_create(
        TypeKind.INPUT_OBJECT, type_name, "an input object type"
    )
    context.state.types[input].is_one_of = True


def _add_composed(
    mut context: SubgraphContext,
    node: Int,
    kind: Kind,
    type_name: String,
    field_name: String,
) raises:
    """Keep a composed directive on what the walk is in."""
    var arg_def = context.info.arg_def
    var value_def = context.info.value_def
    if _is_object(kind) or _is_interface(kind):
        var interface = _is_interface(kind)
        if field_name.byte_length() == 0:
            var index: Int
            if interface or context.state.is_interface_object(type_name):
                index = context.state.interface_type(type_name)
            else:
                index = context.state.object_type(type_name)
            context.state.types[index].directives.append(node)
            return
        var at = context.state.owner_field(type_name, field_name, interface)
        if arg_def != NO_NODE:
            var arg = context.state.arg_index(
                at, String(context.document.name(arg_def))
            )
            context.state.types[at.type].fields[at.field].args[
                arg
            ].directives.append(node)
            return
        context.state.types[at.type].fields[at.field].directives.append(node)
    elif _is_input_object(kind) or kind == Kind.DIRECTIVE_DEFINITION:
        var owner = TypeKind.INPUT_OBJECT
        if kind == Kind.DIRECTIVE_DEFINITION:
            owner = TypeKind.DIRECTIVE
        if field_name.byte_length() > 0:
            var at = context.state.input_value_at(owner, type_name, field_name)
            context.state.types[at.type].input_fields[
                at.field
            ].directives.append(node)
        elif owner == TypeKind.INPUT_OBJECT:
            var index = context.state.get_or_create(
                owner, type_name, "an input object type"
            )
            context.state.types[index].directives.append(node)
    elif kind == Kind.ENUM_TYPE_DEFINITION or kind == Kind.ENUM_TYPE_EXTENSION:
        if value_def != NO_NODE:
            var at = context.state.enum_value_at(
                type_name, String(context.document.name(value_def))
            )
            context.state.types[at.type].values[at.field].directives.append(
                node
            )
            return
        var index = context.state.get_or_create(
            TypeKind.ENUM, type_name, "an enum type"
        )
        context.state.types[index].directives.append(node)
    else:
        var what: StaticString = "a union type"
        var owner = TypeKind.UNION
        if (
            kind == Kind.SCALAR_TYPE_DEFINITION
            or kind == Kind.SCALAR_TYPE_EXTENSION
        ):
            what = "a scalar type"
            owner = TypeKind.SCALAR
        var index = context.state.get_or_create(owner, type_name, what)
        context.state.types[index].directives.append(node)

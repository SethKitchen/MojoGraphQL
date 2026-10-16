# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The federation rules that mark what a directive annotates.

Port of `elements/inaccessible.ts` and `elements/tag.ts` of Hive Federation
Composition v0.27.0 `src/subgraph/validation/rules/`. Each one records the
directive in the state of the annotated type, field, argument or enum
value.
"""

from gql_language.ast import NO_NODE, Kind, Role
from gql_composition.context import SubgraphContext
from gql_composition.helpers import argument_value
from gql_composition.state import TypeKind


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


def _mark_input_value(
    mut context: SubgraphContext, parent: Int, tag: Optional[String]
) raises:
    """Mark an input value: an input field, an argument of a field or of a
    directive."""
    var type_def = context.info.type_def
    var kind = context.document.kind(type_def)
    var type_name = String(context.document.name(type_def))
    var name = String(context.document.name(parent))
    if _is_input_object(kind) or kind == Kind.DIRECTIVE_DEFINITION:
        var owner = TypeKind.DIRECTIVE
        if _is_input_object(kind):
            owner = TypeKind.INPUT_OBJECT
        var at = context.state.input_value_at(owner, type_name, name)
        ref value = context.state.types[at.type].input_fields[at.field]
        if tag:
            value.tags.add(tag.value())
        else:
            value.inaccessible = True
        return
    if not _is_object(kind) and not _is_interface(kind):
        return
    var field_name = String(context.document.name(context.info.field_def))
    var at = context.state.owner_field(
        type_name, field_name, _is_interface(kind)
    )
    var arg = context.state.arg_index(at, name)
    ref value = context.state.types[at.type].fields[at.field].args[arg]
    if tag:
        value.tags.add(tag.value())
    else:
        value.inaccessible = True


def _mark_field(
    mut context: SubgraphContext, parent: Int, tag: Optional[String]
) raises:
    """Mark a field of an object or interface type."""
    var type_def = context.info.type_def
    var kind = context.document.kind(type_def)
    var type_name = String(context.document.name(type_def))
    var interface = _is_interface(kind)
    if tag and context.state.is_interface_object(type_name):
        interface = True
    var at = context.state.owner_field(
        type_name, String(context.document.name(parent)), interface
    )
    ref field = context.state.types[at.type].fields[at.field]
    if tag:
        field.tags.add(tag.value())
    else:
        field.inaccessible = True


def _mark(
    mut context: SubgraphContext, parent: Int, tag: Optional[String]
) raises:
    """Mark what a directive annotates, as the `switch (parent.kind)` of
    upstream `InaccessibleRules` and `TagRules`."""
    var kind = context.document.kind(parent)
    if kind == Kind.FIELD_DEFINITION:
        _mark_field(context, parent, tag)
        return
    if kind == Kind.INPUT_VALUE_DEFINITION:
        _mark_input_value(context, parent, tag)
        return
    var name = String(context.document.name(parent))
    if kind == Kind.ENUM_VALUE_DEFINITION:
        var at = context.state.enum_value_at(
            String(context.document.name(context.info.type_def)), name
        )
        ref value = context.state.types[at.type].values[at.field]
        if tag:
            value.tags.add(tag.value())
        else:
            value.inaccessible = True
        return
    var index = -1
    if _is_object(kind):
        if context.state.is_interface_object(name):
            index = context.state.interface_type(name)
        else:
            index = context.state.object_type(name)
    elif _is_interface(kind):
        index = context.state.interface_type(name)
    elif (
        kind == Kind.SCALAR_TYPE_DEFINITION
        or kind == Kind.SCALAR_TYPE_EXTENSION
    ):
        index = context.state.get_or_create(
            TypeKind.SCALAR, name, "a scalar type"
        )
    elif (
        kind == Kind.UNION_TYPE_DEFINITION or kind == Kind.UNION_TYPE_EXTENSION
    ):
        index = context.state.get_or_create(
            TypeKind.UNION, name, "a union type"
        )
    elif _is_input_object(kind):
        index = context.state.get_or_create(
            TypeKind.INPUT_OBJECT, name, "an input object type"
        )
        if not tag:
            for ref field in context.state.types[index].input_fields:
                field.inaccessible = True
    elif kind == Kind.ENUM_TYPE_DEFINITION or kind == Kind.ENUM_TYPE_EXTENSION:
        index = context.state.get_or_create(TypeKind.ENUM, name, "an enum type")
    if index == -1:
        return
    ref type = context.state.types[index]
    if tag:
        type.tags.add(tag.value())
    else:
        type.inaccessible = True


def enter_inaccessible(mut context: SubgraphContext, parent: Int) raises:
    """Mark the node that `@inaccessible` annotates, as upstream
    `InaccessibleRules`.

    Args:
        context: The context.
        parent: The annotated node.

    Raises:
        Error: When the state has a conflict of kinds.
    """
    _mark(context, parent, None)
    context.state.specs.inaccessible = True


def enter_tag(mut context: SubgraphContext, node: Int, parent: Int) raises:
    """Add the name of a `@tag` to the node that it annotates, as upstream
    `TagRules`.

    Args:
        context: The context.
        node: The `@tag` directive.
        parent: The annotated node.

    Raises:
        Error: When the state has a conflict of kinds.
    """
    var name = argument_value(context.document, node, "name")
    if name == NO_NODE or context.document.kind(name) != Kind.STRING:
        return
    _mark(context, parent, context.document.string_value(name))
    context.state.specs.tag = True

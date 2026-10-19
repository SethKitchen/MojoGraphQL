# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Schema validation of apollo-compiler.

Port of apollo-compiler 1.33.0 (`b7eee5c`) `src/schema/validation.rs`,
`src/validation/schema.rs`, `src/validation/object.rs`,
`src/validation/interface.rs`, `src/validation/union_.rs`,
`src/validation/enum_.rs`, `src/validation/input_object.rs`,
`src/validation/scalar.rs`, the definition part of
`src/validation/directive.rs` and the definition part of
`src/validation/field.rs`, under the MIT arm of its MIT OR Apache-2.0
license.

The checks run in the upstream order. Each diagnostic has the location
that upstream gives it: the start of the same node.

**Differences from upstream.**

- Upstream `validate_schema` removes the definitions of the built-in
  scalars that the schema does not use, and adds the ones that it uses
  but does not define (`BuiltInScalars`). This port does not change the
  schema: validation takes the schema as read-only. The built-in document
  defines every built-in scalar, so a reference to one always finds a
  definition, and the upstream branch for an undefined built-in scalar
  is not needed.
"""

from gql_language.ast import Document, Kind, NO_NODE, Role
from gql_language.directive_location import DirectiveLocation
from gql_compiler.diagnostics import Diagnostic, DiagnosticKind, DiagnosticList
from gql_compiler.schema import Members, Schema, TypeKind
from gql_compiler.validate_common import (
    is_non_null,
    type_string,
    validate_directive,
    validate_directives,
)


def validate_schema_into(
    schema: Schema, files: List[Int], mut list: DiagnosticList
):
    """Validate a schema: upstream `validate_schema`.

    Args:
        schema: The schema.
        files: The rank in `list` of each document of `schema.sources`.
        list: The list to add the diagnostics to.
    """
    _validate_schema_definition(schema, files, list)
    _validate_directive_definitions(schema, files, list)
    var index = 0
    while index < len(schema.types):
        var definition = schema.types[index].definition
        var kind = schema.types[index].kind
        ref document = schema.sources[Int(definition.source)]
        _validate_type_system_name(
            schema,
            files,
            Int(definition.source),
            document.child(Int(definition.node), Role.NAME),
            String(kind.describe()),
            list,
        )
        if kind == TypeKind.SCALAR:
            _validate_scalar_definition(schema, files, index, list)
        elif kind == TypeKind.OBJECT:
            _validate_object_type_definition(schema, files, index, list)
        elif kind == TypeKind.INTERFACE:
            _validate_interface_definition(schema, files, index, list)
        elif kind == TypeKind.UNION:
            _validate_union_definition(schema, files, index, list)
        elif kind == TypeKind.ENUM:
            _validate_enum_definition(schema, files, index, list)
        else:
            _validate_input_object_definition(schema, files, index, list)
        index += 1


def _push(
    schema: Schema,
    files: List[Int],
    mut list: DiagnosticList,
    kind: DiagnosticKind,
    source: Int,
    node: Int,
    a: String = String(),
    b: String = String(),
    c: String = String(),
    d: String = String(),
    e: String = String(),
    f: String = String(),
):
    """Add a diagnostic at the start of a node of a source.

    Args:
        schema: The schema.
        files: The rank of each source in `list`.
        list: The list to add the diagnostic to.
        kind: The kind of the diagnostic.
        source: The index of the document in `schema.sources`.
        node: The node whose start is the location.
        a: The first text field.
        b: The second text field.
        c: The third text field.
        d: The fourth text field.
        e: The fifth text field.
        f: The sixth text field.
    """
    list.push(
        Diagnostic(
            kind,
            files[source],
            schema.sources[source].start(node),
            a,
            b,
            c,
            d,
            e,
            f,
        )
    )


def _validate_type_system_name(
    schema: Schema,
    files: List[Int],
    source: Int,
    name: Int,
    describe: String,
    mut list: DiagnosticList,
):
    """Report a name that starts with `__` outside the built-in document:
    upstream `validate_type_system_name`.

    Args:
        schema: The schema.
        files: The rank of each source in `list`.
        source: The index of the document of the name.
        name: The `Name` node.
        describe: What the name names, as "an object type".
        list: The list to add the diagnostics to.
    """
    if source == 0:
        return
    var text = schema.sources[source].text(name)
    if text.startswith("__"):
        _push(
            schema,
            files,
            list,
            DiagnosticKind.RESERVED_NAME,
            source,
            name,
            String(text),
            describe,
        )


def _validate_directive_run(
    schema: Schema,
    files: List[Int],
    members: Members,
    location: DirectiveLocation,
    mut list: DiagnosticList,
):
    """Validate the directives of a type, which its definition and its
    extensions apply: upstream `validate_directives` on `iter_ast()`.

    Args:
        schema: The schema.
        files: The rank of each source in `list`.
        members: The run of `Directive` components.
        location: Where the directives are applied.
        list: The list to add the diagnostics to.
    """
    var seen = List[String]()
    var position = 0
    while position < Int(members.count):
        var component = schema.components[Int(members.start) + position]
        ref document = schema.sources[Int(component.source)]
        validate_directive(
            schema,
            document,
            Int(component.node),
            location,
            files[Int(component.source)],
            seen,
            list,
            document,
            NO_NODE,
        )
        position += 1


def _validate_schema_definition(
    schema: Schema, files: List[Int], mut list: DiagnosticList
):
    """Validate the schema definition: upstream
    `validate_schema_definition`.

    Args:
        schema: The schema.
        files: The rank of each source in `list`.
        list: The list to add the diagnostics to.
    """
    if not schema.roots[0]:
        var definition = schema.schema_definition
        if Int(definition.node) == NO_NODE:
            list.push(
                Diagnostic(DiagnosticKind.QUERY_ROOT_OPERATION_TYPE, -1, 0)
            )
        else:
            _push(
                schema,
                files,
                list,
                DiagnosticKind.QUERY_ROOT_OPERATION_TYPE,
                Int(definition.source),
                Int(definition.node),
            )
    _validate_root_operation_definitions(schema, files, list)
    _validate_directive_run(
        schema, files, schema.schema_directives, DirectiveLocation.SCHEMA, list
    )


def _validate_root_operation_definitions(
    schema: Schema, files: List[Int], mut list: DiagnosticList
):
    """Report a root operation type that is not an object type, or that
    another root operation also uses: upstream
    `validate_root_operation_definitions`.

    Args:
        schema: The schema.
        files: The rank of each source in `list`.
        list: The list to add the diagnostics to.
    """
    var seen = List[String]()
    var operation = 0
    while operation < 3:
        if schema.roots[operation]:
            var root = schema.roots[operation].value()
            var source = Int(root.component.source)
            var node = Int(root.component.node)
            var index = schema.get_type(root.type_name)
            if index < 0:
                _push(
                    schema,
                    files,
                    list,
                    DiagnosticKind.UNDEFINED_DEFINITION,
                    source,
                    node,
                    root.type_name,
                )
            elif schema.types[index].kind != TypeKind.OBJECT:
                _push(
                    schema,
                    files,
                    list,
                    DiagnosticKind.ROOT_OPERATION_OBJECT_TYPE,
                    source,
                    node,
                    root.type_name,
                    String(schema.types[index].kind.describe()),
                )
            if root.type_name in seen:
                _push(
                    schema,
                    files,
                    list,
                    DiagnosticKind.DUPLICATE_ROOT_OPERATION_TYPE,
                    source,
                    node,
                    root.type_name,
                )
            else:
                seen.append(root.type_name)
        operation += 1


def _push_empty(
    schema: Schema,
    files: List[Int],
    index: Int,
    kind: DiagnosticKind,
    mut list: DiagnosticList,
):
    """Report a type with no members at its definition: upstream
    `EmptyFieldSet`, `EmptyValueSet`, `EmptyMemberSet` and
    `EmptyInputValueSet`.

    Args:
        schema: The schema.
        files: The rank of each source in `list`.
        index: The type's index in `schema.types`.
        kind: The kind of the diagnostic.
        list: The list to add the diagnostics to.
    """
    if schema.member_count(index) == 0:
        var definition = schema.types[index].definition
        _push(
            schema,
            files,
            list,
            kind,
            Int(definition.source),
            Int(definition.node),
            String(schema.type_name(index)),
        )


def _inner_named_type(document: Document, node: Int) -> Int:
    """Return the `NamedType` node at the bottom of a type reference.

    Args:
        document: The document of the type.
        node: A `NamedType`, `ListType` or `NonNullType` node.

    Returns:
        The `NamedType` node.
    """
    var current = node
    while document.kind(current) != Kind.NAMED_TYPE:
        current = document.first_child(current)
    return current


def _validate_scalar_definition(
    schema: Schema, files: List[Int], index: Int, mut list: DiagnosticList
):
    """Validate a scalar type: upstream `validate_scalar_definition`.

    Args:
        schema: The schema.
        files: The rank of each source in `list`.
        index: The type's index in `schema.types`.
        list: The list to add the diagnostics to.
    """
    if not schema.is_built_in(index):
        _validate_directive_run(
            schema,
            files,
            schema.types[index].directives,
            DirectiveLocation.SCALAR,
            list,
        )


def _validate_union_definition(
    schema: Schema, files: List[Int], index: Int, mut list: DiagnosticList
):
    """Validate a union type: upstream `validate_union_definition`.

    Args:
        schema: The schema.
        files: The rank of each source in `list`.
        index: The type's index in `schema.types`.
        list: The list to add the diagnostics to.
    """
    _validate_directive_run(
        schema,
        files,
        schema.types[index].directives,
        DirectiveLocation.UNION,
        list,
    )
    var position = 0
    while position < schema.member_count(index):
        var member = schema.member(index, position)
        var name = String(schema.component_name(member))
        var target = schema.get_type(name)
        if target < 0:
            _push(
                schema,
                files,
                list,
                DiagnosticKind.UNDEFINED_DEFINITION,
                Int(member.source),
                Int(member.node),
                name,
            )
        elif schema.types[target].kind != TypeKind.OBJECT:
            _push(
                schema,
                files,
                list,
                DiagnosticKind.UNION_MEMBER_OBJECT_TYPE,
                Int(member.source),
                Int(member.node),
                name,
            )
        position += 1
    _push_empty(schema, files, index, DiagnosticKind.EMPTY_MEMBER_SET, list)


def _validate_enum_definition(
    schema: Schema, files: List[Int], index: Int, mut list: DiagnosticList
):
    """Validate an enum type: upstream `validate_enum_definition` and
    `validate_enum_value`.

    Args:
        schema: The schema.
        files: The rank of each source in `list`.
        index: The type's index in `schema.types`.
        list: The list to add the diagnostics to.
    """
    _validate_directive_run(
        schema,
        files,
        schema.types[index].directives,
        DirectiveLocation.ENUM,
        list,
    )
    var position = 0
    while position < schema.member_count(index):
        var value = schema.member(index, position)
        var source = Int(value.source)
        ref document = schema.sources[source]
        _validate_type_system_name(
            schema,
            files,
            source,
            document.child(Int(value.node), Role.NAME),
            "an enum value",
            list,
        )
        validate_directives(
            schema,
            document,
            Int(value.node),
            DirectiveLocation.ENUM_VALUE,
            files[source],
            list,
            document,
            NO_NODE,
        )
        position += 1
    _push_empty(schema, files, index, DiagnosticKind.EMPTY_VALUE_SET, list)


def _get_interface(schema: Schema, name: StringSlice) -> Int:
    """Return the index of an interface type: upstream `get_interface`.

    Args:
        schema: The schema.
        name: The type name.

    Returns:
        The index in `schema.types`, or -1 when no interface type has the
        name.
    """
    var index = schema.get_type(name)
    if index >= 0 and schema.types[index].kind == TypeKind.INTERFACE:
        return index
    return -1


def _implements(schema: Schema, index: Int, name: StringSlice) -> Bool:
    """Return True when a type declares that it implements an interface.

    Args:
        schema: The schema.
        index: The type's index in `schema.types`.
        name: The interface name.

    Returns:
        Whether `name` is in the type's `implements_interfaces`.
    """
    var interfaces = schema.types[index].interfaces
    var position = 0
    while position < Int(interfaces.count):
        var component = schema.components[Int(interfaces.start) + position]
        if schema.component_name(component) == name:
            return True
        position += 1
    return False


def _validate_object_type_definition(
    schema: Schema, files: List[Int], index: Int, mut list: DiagnosticList
):
    """Validate an object type: upstream `validate_object_type_definition`.

    Args:
        schema: The schema.
        files: The rank of each source in `list`.
        index: The type's index in `schema.types`.
        list: The list to add the diagnostics to.
    """
    _validate_directive_run(
        schema,
        files,
        schema.types[index].directives,
        DirectiveLocation.OBJECT,
        list,
    )
    _validate_field_definitions(schema, files, index, list)
    _push_empty(schema, files, index, DiagnosticKind.EMPTY_FIELD_SET, list)
    _validate_implementor(schema, files, index, list)


def _validate_interface_definition(
    schema: Schema, files: List[Int], index: Int, mut list: DiagnosticList
):
    """Validate an interface type: upstream `validate_interface_definition`.

    Args:
        schema: The schema.
        files: The rank of each source in `list`.
        index: The type's index in `schema.types`.
        list: The list to add the diagnostics to.
    """
    _validate_directive_run(
        schema,
        files,
        schema.types[index].directives,
        DirectiveLocation.INTERFACE,
        list,
    )
    var name = String(schema.type_name(index))
    var interfaces = schema.types[index].interfaces
    var position = 0
    while position < Int(interfaces.count):
        var component = schema.components[Int(interfaces.start) + position]
        if schema.component_name(component) == name:
            _push(
                schema,
                files,
                list,
                DiagnosticKind.RECURSIVE_INTERFACE_DEFINITION,
                Int(component.source),
                Int(component.node),
                name,
            )
        position += 1
    _validate_field_definitions(schema, files, index, list)
    _push_empty(schema, files, index, DiagnosticKind.EMPTY_FIELD_SET, list)
    _validate_implementor(schema, files, index, list)


def _validate_implementor(
    schema: Schema, files: List[Int], index: Int, mut list: DiagnosticList
):
    """Validate the interfaces that an object or an interface type
    implements: the part that upstream `validate_object_type_definition`
    and `validate_interface_definition` share.

    Args:
        schema: The schema.
        files: The rank of each source in `list`.
        index: The type's index in `schema.types`.
        list: The list to add the diagnostics to.
    """
    _validate_implements_interfaces(schema, files, index, list)
    var definition = schema.types[index].definition
    var name = String(schema.type_name(index))
    var interfaces = schema.types[index].interfaces
    var position = 0
    while position < Int(interfaces.count):
        var component = schema.components[Int(interfaces.start) + position]
        var interface_name = String(schema.component_name(component))
        var interface = _get_interface(schema, interface_name)
        if interface >= 0:
            var field = 0
            while field < schema.member_count(interface):
                var field_name = String(
                    schema.component_name(schema.member(interface, field))
                )
                if schema.find_member(index, field_name) < 0:
                    _push(
                        schema,
                        files,
                        list,
                        DiagnosticKind.MISSING_INTERFACE_FIELD,
                        Int(definition.source),
                        Int(definition.node),
                        name,
                        interface_name,
                        field_name,
                    )
                field += 1
        position += 1
    _validate_implementation_field_types(schema, files, index, list)
    _validate_implementation_field_arguments(schema, files, index, list)


def _validate_implements_interfaces(
    schema: Schema, files: List[Int], index: Int, mut list: DiagnosticList
):
    """Report an undefined interface, and an interface that an implemented
    interface implements but the type does not: upstream
    `validate_implements_interfaces`.

    Args:
        schema: The schema.
        files: The rank of each source in `list`.
        index: The type's index in `schema.types`.
        list: The list to add the diagnostics to.
    """
    var interfaces = schema.types[index].interfaces
    var position = 0
    while position < Int(interfaces.count):
        var component = schema.components[Int(interfaces.start) + position]
        var interface_name = String(schema.component_name(component))
        if _get_interface(schema, interface_name) < 0:
            _push(
                schema,
                files,
                list,
                DiagnosticKind.UNDEFINED_DEFINITION,
                Int(component.source),
                Int(component.node),
                interface_name,
            )
        position += 1
    var definition = schema.types[index].definition
    var name = String(schema.type_name(index))
    position = 0
    while position < Int(interfaces.count):
        var component = schema.components[Int(interfaces.start) + position]
        var via = String(schema.component_name(component))
        var interface = _get_interface(schema, via)
        if interface >= 0:
            var transitive = schema.types[interface].interfaces
            var item = 0
            while item < Int(transitive.count):
                var missing = String(
                    schema.component_name(
                        schema.components[Int(transitive.start) + item]
                    )
                )
                if not _implements(schema, index, missing):
                    _push(
                        schema,
                        files,
                        list,
                        DiagnosticKind.TRANSITIVE_IMPLEMENTED_INTERFACES,
                        Int(definition.source),
                        Int(definition.node),
                        name,
                        via,
                        missing,
                    )
                item += 1
        position += 1


def _is_subtype(
    schema: Schema, abstract_type: StringSlice, maybe_subtype: StringSlice
) -> Bool:
    """Return True when a type is a subtype of an abstract type: upstream
    `Schema::is_subtype`.

    Args:
        schema: The schema.
        abstract_type: An interface or a union type name.
        maybe_subtype: The possible subtype's name.

    Returns:
        Whether `maybe_subtype` implements the interface, or is a member
        of the union.
    """
    var index = schema.get_type(abstract_type)
    if index < 0:
        return False
    var kind = schema.types[index].kind
    if kind == TypeKind.INTERFACE:
        var subtype = schema.get_type(maybe_subtype)
        if subtype < 0:
            return False
        var subtype_kind = schema.types[subtype].kind
        if subtype_kind != TypeKind.OBJECT and (
            subtype_kind != TypeKind.INTERFACE
        ):
            return False
        return _implements(schema, subtype, abstract_type)
    if kind == TypeKind.UNION:
        return schema.find_member(index, maybe_subtype) >= 0
    return False


def _is_valid_implementation_field_type(
    schema: Schema,
    interface_document: Document,
    interface_type: Int,
    impl_document: Document,
    impl_type: Int,
) -> Bool:
    """Return True when a field type can implement an interface field
    type: upstream `is_valid_implementation_field_type`.

    Args:
        schema: The schema.
        interface_document: The document of the interface field.
        interface_type: The interface field's type reference.
        impl_document: The document of the implementing field.
        impl_type: The implementing field's type reference.

    Returns:
        Whether the type is a valid implementation.
    """
    var interface_node = interface_type
    var impl_node = impl_type
    if is_non_null(interface_document, interface_node):
        if not is_non_null(impl_document, impl_node):
            return False
        interface_node = interface_document.first_child(interface_node)
    if is_non_null(impl_document, impl_node):
        impl_node = impl_document.first_child(impl_node)
    var interface_kind = interface_document.kind(interface_node)
    var impl_kind = impl_document.kind(impl_node)
    if interface_kind == Kind.NAMED_TYPE and impl_kind == Kind.NAMED_TYPE:
        var interface_name = interface_document.name(interface_node)
        var impl_name = impl_document.name(impl_node)
        return interface_name == impl_name or _is_subtype(
            schema, interface_name, impl_name
        )
    if interface_kind == Kind.LIST_TYPE and impl_kind == Kind.LIST_TYPE:
        return _is_valid_implementation_field_type(
            schema,
            interface_document,
            interface_document.first_child(interface_node),
            impl_document,
            impl_document.first_child(impl_node),
        )
    return False


def _find_input_value(document: Document, owner: Int, name: StringSlice) -> Int:
    """Return the argument definition of a field by name.

    Args:
        document: The document of the field.
        owner: A `FieldDefinition` node.
        name: The argument name.

    Returns:
        The `InputValueDefinition` node, or `NO_NODE`.
    """
    var child = document.first_child(owner)
    while child != NO_NODE:
        if document.role(child) == Role.ARGUMENT and (
            document.name(child) == name
        ):
            return child
        child = document.next_sibling(child)
    return NO_NODE


def _validate_implementation_field_types(
    schema: Schema, files: List[Int], index: Int, mut list: DiagnosticList
):
    """Report a field whose type is not a subtype of the type of the
    interface field: upstream `validate_implementation_field_types`.

    Args:
        schema: The schema.
        files: The rank of each source in `list`.
        index: The type's index in `schema.types`.
        list: The list to add the diagnostics to.
    """
    var name = String(schema.type_name(index))
    var interfaces = schema.types[index].interfaces
    var position = 0
    while position < Int(interfaces.count):
        var component = schema.components[Int(interfaces.start) + position]
        var interface_name = String(schema.component_name(component))
        var interface = _get_interface(schema, interface_name)
        position += 1
        if interface < 0:
            continue
        var field = 0
        while field < schema.member_count(interface):
            var interface_field = schema.member(interface, field)
            field += 1
            var field_name = String(schema.component_name(interface_field))
            var found = schema.find_member(index, field_name)
            if found < 0:
                continue
            var impl_field = schema.member(index, found)
            ref interface_document = schema.sources[Int(interface_field.source)]
            ref impl_document = schema.sources[Int(impl_field.source)]
            var interface_type = interface_document.child(
                Int(interface_field.node), Role.TYPE
            )
            var impl_type = impl_document.child(Int(impl_field.node), Role.TYPE)
            if not _is_valid_implementation_field_type(
                schema,
                interface_document,
                interface_type,
                impl_document,
                impl_type,
            ):
                _push(
                    schema,
                    files,
                    list,
                    DiagnosticKind.INVALID_IMPLEMENTATION_FIELD_TYPE,
                    Int(impl_field.source),
                    Int(impl_field.node),
                    name,
                    interface_name,
                    field_name,
                    type_string(interface_document, interface_type),
                    type_string(impl_document, impl_type),
                )


def _validate_implementation_field_arguments(
    schema: Schema, files: List[Int], index: Int, mut list: DiagnosticList
):
    """Report a missing or mistyped argument of an implementing field, and
    an extra required one: upstream
    `validate_implementation_field_arguments`.

    Args:
        schema: The schema.
        files: The rank of each source in `list`.
        index: The type's index in `schema.types`.
        list: The list to add the diagnostics to.
    """
    var name = String(schema.type_name(index))
    var interfaces = schema.types[index].interfaces
    var position = 0
    while position < Int(interfaces.count):
        var component = schema.components[Int(interfaces.start) + position]
        var interface_name = String(schema.component_name(component))
        var interface = _get_interface(schema, interface_name)
        position += 1
        if interface < 0:
            continue
        var field = 0
        while field < schema.member_count(interface):
            var interface_field = schema.member(interface, field)
            field += 1
            var field_name = String(schema.component_name(interface_field))
            var found = schema.find_member(index, field_name)
            if found < 0:
                continue
            var impl_field = schema.member(index, found)
            var impl_source = Int(impl_field.source)
            ref interface_document = schema.sources[Int(interface_field.source)]
            ref impl_document = schema.sources[impl_source]
            var argument = interface_document.first_child(
                Int(interface_field.node)
            )
            while argument != NO_NODE:
                if interface_document.role(argument) == Role.ARGUMENT:
                    var argument_name = String(
                        interface_document.name(argument)
                    )
                    var impl_argument = _find_input_value(
                        impl_document, Int(impl_field.node), argument_name
                    )
                    if impl_argument == NO_NODE:
                        _push(
                            schema,
                            files,
                            list,
                            DiagnosticKind.MISSING_INTERFACE_FIELD_ARGUMENT,
                            impl_source,
                            Int(impl_field.node),
                            name,
                            interface_name,
                            field_name,
                            argument_name,
                        )
                    else:
                        var interface_type = type_string(
                            interface_document,
                            interface_document.child(argument, Role.TYPE),
                        )
                        var impl_type = type_string(
                            impl_document,
                            impl_document.child(impl_argument, Role.TYPE),
                        )
                        if interface_type != impl_type:
                            _push(
                                schema,
                                files,
                                list,
                                DiagnosticKind.INVALID_IMPLEMENTATION_FIELD_ARGUMENT_TYPE,
                                impl_source,
                                impl_argument,
                                name,
                                interface_name,
                                field_name,
                                argument_name,
                                interface_type,
                                impl_type,
                            )
                argument = interface_document.next_sibling(argument)
            var extra = impl_document.first_child(Int(impl_field.node))
            while extra != NO_NODE:
                if impl_document.role(extra) == Role.ARGUMENT:
                    var extra_name = impl_document.name(extra)
                    if _find_input_value(
                        interface_document,
                        Int(interface_field.node),
                        extra_name,
                    ) == NO_NODE and _is_required_argument(
                        impl_document, extra
                    ):
                        _push(
                            schema,
                            files,
                            list,
                            DiagnosticKind.EXTRA_REQUIRED_IMPLEMENTATION_FIELD_ARGUMENT,
                            impl_source,
                            extra,
                            name,
                            interface_name,
                            field_name,
                            String(extra_name),
                        )
                extra = impl_document.next_sibling(extra)


def _is_required_argument(document: Document, node: Int) -> Bool:
    """Return True for an argument of a non-null type with no default
    value: upstream `is_required_argument`.

    Args:
        document: The document of the argument.
        node: An `InputValueDefinition` node.

    Returns:
        Whether the argument is required.
    """
    return is_non_null(document, document.child(node, Role.TYPE)) and (
        document.child(node, Role.DEFAULT_VALUE) == NO_NODE
    )


def _validate_field_definitions(
    schema: Schema, files: List[Int], index: Int, mut list: DiagnosticList
):
    """Validate the fields of an object or an interface type: upstream
    `validate_field_definitions` and `validate_field_definition`.

    Args:
        schema: The schema.
        files: The rank of each source in `list`.
        index: The type's index in `schema.types`.
        list: The list to add the diagnostics to.
    """
    var position = 0
    while position < schema.member_count(index):
        var field = schema.member(index, position)
        var source = Int(field.source)
        var node = Int(field.node)
        ref document = schema.sources[source]
        _validate_type_system_name(
            schema,
            files,
            source,
            document.child(node, Role.NAME),
            "a field",
            list,
        )
        validate_directives(
            schema,
            document,
            node,
            DirectiveLocation.FIELD_DEFINITION,
            files[source],
            list,
            document,
            NO_NODE,
        )
        _validate_argument_definitions(schema, files, source, node, list)
        var named = _inner_named_type(document, document.child(node, Role.TYPE))
        var type_name = document.name(named)
        var target = schema.get_type(type_name)
        if target < 0:
            _push(
                schema,
                files,
                list,
                DiagnosticKind.UNDEFINED_DEFINITION,
                source,
                named,
                String(type_name),
            )
        elif schema.types[target].kind == TypeKind.INPUT_OBJECT:
            _push(
                schema,
                files,
                list,
                DiagnosticKind.OUTPUT_TYPE,
                source,
                node,
                String(document.name(node)),
            )
        position += 1


def _validate_argument_definitions(
    schema: Schema,
    files: List[Int],
    source: Int,
    owner: Int,
    mut list: DiagnosticList,
):
    """Validate the argument definitions of a field or a directive:
    upstream `validate_argument_definitions`.

    Args:
        schema: The schema.
        files: The rank of each source in `list`.
        source: The index of the document of the owner.
        owner: A `FieldDefinition` or `DirectiveDefinition` node.
        list: The list to add the diagnostics to.
    """
    ref document = schema.sources[source]
    var arguments = document.children(owner, Role.ARGUMENT)
    var position = 0
    while position < len(arguments):
        _validate_input_value_definition(
            schema,
            files,
            source,
            arguments[position],
            DirectiveLocation.ARGUMENT_DEFINITION,
            "an argument",
            list,
        )
        position += 1
    var names = List[String]()
    var nodes = List[Int]()
    position = 0
    while position < len(arguments):
        var name = String(document.name(arguments[position]))
        var previous = 0
        while previous < len(names) and names[previous] != name:
            previous += 1
        if previous < len(names):
            _push(
                schema,
                files,
                list,
                DiagnosticKind.UNIQUE_INPUT_VALUE,
                source,
                nodes[previous],
                name,
            )
        else:
            names.append(name)
            nodes.append(arguments[position])
        position += 1


def _validate_input_value_definition(
    schema: Schema,
    files: List[Int],
    source: Int,
    node: Int,
    location: DirectiveLocation,
    describe: String,
    mut list: DiagnosticList,
):
    """Validate one input value definition: the loop body of upstream
    `validate_input_value_definitions`.

    Args:
        schema: The schema.
        files: The rank of each source in `list`.
        source: The index of the document of the input value.
        node: An `InputValueDefinition` node.
        location: Where its directives are applied.
        describe: What the input value is, as "an argument".
        list: The list to add the diagnostics to.
    """
    ref document = schema.sources[source]
    _validate_type_system_name(
        schema, files, source, document.child(node, Role.NAME), describe, list
    )
    validate_directives(
        schema,
        document,
        node,
        location,
        files[source],
        list,
        document,
        NO_NODE,
    )
    var named = _inner_named_type(document, document.child(node, Role.TYPE))
    var type_name = document.name(named)
    var target = schema.get_type(type_name)
    if target < 0:
        _push(
            schema,
            files,
            list,
            DiagnosticKind.UNDEFINED_DEFINITION,
            source,
            named,
            String(type_name),
        )
    else:
        var kind = schema.types[target].kind
        if (
            kind == TypeKind.OBJECT
            or kind == TypeKind.INTERFACE
            or kind == TypeKind.UNION
        ):
            _push(
                schema,
                files,
                list,
                DiagnosticKind.INPUT_TYPE,
                source,
                node,
                String(document.name(node)),
            )


comptime _OK = 0
"""A recursion search found no cycle."""
comptime _RECURSED = 1
"""A recursion search came back to its root: upstream
`CycleError::Recursed`."""
comptime _LIMIT = 2
"""A recursion search went too deep: upstream `CycleError::Limit`."""
comptime _RECURSION_LIMIT = 32
"""The most names on a recursion stack: upstream
`DEFAULT_RECURSION_LIMIT`."""


def _find_recursive_input_object(
    schema: Schema, index: Int, mut stack: List[String]
) -> Int:
    """Search the non-null input fields of an input object type for a
    path back to the root of the stack: upstream
    `FindRecursiveInputValue::input_object_definition`.

    Args:
        schema: The schema.
        index: The input object type's index in `schema.types`.
        stack: The type names on the path, root first.

    Returns:
        `_OK`, `_RECURSED` or `_LIMIT`.
    """
    var position = 0
    while position < schema.member_count(index):
        var field = schema.member(index, position)
        position += 1
        ref document = schema.sources[Int(field.source)]
        var ty = document.child(Int(field.node), Role.TYPE)
        if not is_non_null(document, ty):
            continue
        var inner = document.first_child(ty)
        if document.kind(inner) != Kind.NAMED_TYPE:
            continue
        var name = String(document.name(inner))
        if name in stack:
            if stack[0] == name:
                return _RECURSED
            continue
        var target = schema.get_type(name)
        if target < 0 or schema.types[target].kind != TypeKind.INPUT_OBJECT:
            continue
        stack.append(name)
        if len(stack) > _RECURSION_LIMIT:
            return _LIMIT
        var status = _find_recursive_input_object(schema, target, stack)
        _ = stack.pop()
        if status != _OK:
            return status
    return _OK


def _validate_input_object_definition(
    schema: Schema, files: List[Int], index: Int, mut list: DiagnosticList
):
    """Validate an input object type: upstream
    `validate_input_object_definition`.

    Args:
        schema: The schema.
        files: The rank of each source in `list`.
        index: The type's index in `schema.types`.
        list: The list to add the diagnostics to.
    """
    _validate_directive_run(
        schema,
        files,
        schema.types[index].directives,
        DirectiveLocation.INPUT_OBJECT,
        list,
    )
    var name = String(schema.type_name(index))
    var definition = schema.types[index].definition
    var stack = List[String]()
    stack.append(name)
    var status = _find_recursive_input_object(schema, index, stack)
    if status == _RECURSED:
        _push(
            schema,
            files,
            list,
            DiagnosticKind.RECURSIVE_INPUT_OBJECT_DEFINITION,
            Int(definition.source),
            Int(definition.node),
            name,
        )
    elif status == _LIMIT:
        _push(
            schema,
            files,
            list,
            DiagnosticKind.DEEPLY_NESTED_TYPE,
            Int(definition.source),
            Int(definition.node),
            name,
            "input object",
        )
    var position = 0
    while position < schema.member_count(index):
        var field = schema.member(index, position)
        _validate_input_value_definition(
            schema,
            files,
            Int(field.source),
            Int(field.node),
            DirectiveLocation.INPUT_FIELD_DEFINITION,
            "an input object field",
            list,
        )
        position += 1
    _push_empty(
        schema, files, index, DiagnosticKind.EMPTY_INPUT_VALUE_SET, list
    )


def _recursive_directive(
    schema: Schema,
    document: Document,
    directive: Int,
    mut directives: List[String],
    mut types: List[String],
) -> Int:
    """Follow one directive application: upstream
    `FindRecursiveDirective::directive`.

    Args:
        schema: The schema.
        document: The document of the directive.
        directive: A `Directive` node.
        directives: The directive names on the path, root first.
        types: The type names on the path.

    Returns:
        `_OK`, `_RECURSED` or `_LIMIT`.
    """
    var name = String(document.name(directive))
    if name in directives:
        if directives[0] == name:
            return _RECURSED
        return _OK
    var definition = schema.get_directive_definition(name)
    if definition < 0:
        return _OK
    directives.append(name)
    if len(directives) > _RECURSION_LIMIT:
        return _LIMIT
    var status = _recursive_directive_definition(
        schema, definition, directives, types
    )
    _ = directives.pop()
    return status


def _recursive_directive_children(
    schema: Schema,
    document: Document,
    owner: Int,
    mut directives: List[String],
    mut types: List[String],
) -> Int:
    """Follow the `Directive` children of a node.

    Args:
        schema: The schema.
        document: The document of the node.
        owner: An `InputValueDefinition` or `EnumValueDefinition` node.
        directives: The directive names on the path, root first.
        types: The type names on the path.

    Returns:
        `_OK`, `_RECURSED` or `_LIMIT`.
    """
    var child = document.first_child(owner)
    while child != NO_NODE:
        if document.role(child) == Role.DIRECTIVE:
            var status = _recursive_directive(
                schema, document, child, directives, types
            )
            if status != _OK:
                return status
        child = document.next_sibling(child)
    return _OK


def _recursive_directive_definition(
    schema: Schema,
    definition: Int,
    mut directives: List[String],
    mut types: List[String],
) -> Int:
    """Follow the arguments of a directive definition: upstream
    `FindRecursiveDirective::directive_definition`.

    Args:
        schema: The schema.
        definition: The index in `schema.directive_definitions`.
        directives: The directive names on the path, root first.
        types: The type names on the path.

    Returns:
        `_OK`, `_RECURSED` or `_LIMIT`.
    """
    var source = Int(schema.directive_definitions[definition].source)
    var node = Int(schema.directive_definitions[definition].node)
    ref document = schema.sources[source]
    var child = document.first_child(node)
    while child != NO_NODE:
        if document.role(child) == Role.ARGUMENT:
            var status = _recursive_input_value(
                schema, document, child, directives, types
            )
            if status != _OK:
                return status
        child = document.next_sibling(child)
    return _OK


def _recursive_input_value(
    schema: Schema,
    document: Document,
    node: Int,
    mut directives: List[String],
    mut types: List[String],
) -> Int:
    """Follow the directives and the type of an input value: upstream
    `FindRecursiveDirective::input_value`.

    Args:
        schema: The schema.
        document: The document of the input value.
        node: An `InputValueDefinition` node.
        directives: The directive names on the path, root first.
        types: The type names on the path.

    Returns:
        `_OK`, `_RECURSED` or `_LIMIT`.
    """
    var status = _recursive_directive_children(
        schema, document, node, directives, types
    )
    if status != _OK:
        return status
    var name = String(document.named_type(document.child(node, Role.TYPE)))
    var index = schema.get_type(name)
    if index < 0 or name in types:
        return _OK
    if schema.is_built_in(index):
        return _recursive_type(schema, index, directives, types)
    types.append(name)
    if len(types) > _RECURSION_LIMIT:
        return _LIMIT
    status = _recursive_type(schema, index, directives, types)
    _ = types.pop()
    return status


def _recursive_type(
    schema: Schema,
    index: Int,
    mut directives: List[String],
    mut types: List[String],
) -> Int:
    """Follow the directives of a type, and of its enum values or input
    fields: upstream `FindRecursiveDirective::type_definition`.

    Args:
        schema: The schema.
        index: The type's index in `schema.types`.
        directives: The directive names on the path, root first.
        types: The type names on the path.

    Returns:
        `_OK`, `_RECURSED` or `_LIMIT`.
    """
    var run = schema.types[index].directives
    var position = 0
    while position < Int(run.count):
        var component = schema.components[Int(run.start) + position]
        var status = _recursive_directive(
            schema,
            schema.sources[Int(component.source)],
            Int(component.node),
            directives,
            types,
        )
        if status != _OK:
            return status
        position += 1
    var kind = schema.types[index].kind
    if kind != TypeKind.ENUM and kind != TypeKind.INPUT_OBJECT:
        return _OK
    position = 0
    while position < schema.member_count(index):
        var member = schema.member(index, position)
        ref document = schema.sources[Int(member.source)]
        var status: Int
        if kind == TypeKind.ENUM:
            status = _recursive_directive_children(
                schema, document, Int(member.node), directives, types
            )
        else:
            status = _recursive_input_value(
                schema, document, Int(member.node), directives, types
            )
        if status != _OK:
            return status
        position += 1
    return _OK


def _validate_directive_definitions(
    schema: Schema, files: List[Int], mut list: DiagnosticList
):
    """Validate each directive definition: upstream
    `validate_directive_definitions` and `validate_directive_definition`.

    Args:
        schema: The schema.
        files: The rank of each source in `list`.
        list: The list to add the diagnostics to.
    """
    var definition = 0
    while definition < len(schema.directive_definitions):
        var source = Int(schema.directive_definitions[definition].source)
        var node = Int(schema.directive_definitions[definition].node)
        ref document = schema.sources[source]
        _validate_type_system_name(
            schema,
            files,
            source,
            document.child(node, Role.NAME),
            "a directive definition",
            list,
        )
        _validate_argument_definitions(schema, files, source, node, list)
        var name = String(document.name(node))
        var directives = List[String]()
        directives.append(name)
        var types = List[String]()
        var status = _recursive_directive_definition(
            schema, definition, directives, types
        )
        if status == _RECURSED:
            _push(
                schema,
                files,
                list,
                DiagnosticKind.RECURSIVE_DIRECTIVE_DEFINITION,
                source,
                node,
                name,
            )
        elif status == _LIMIT:
            _push(
                schema,
                files,
                list,
                DiagnosticKind.DEEPLY_NESTED_TYPE,
                source,
                node,
                name,
                "directive",
            )
        definition += 1

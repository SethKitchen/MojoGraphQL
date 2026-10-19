# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The validation of directives, arguments and values, which both schema
and executable validation use.

Port of apollo-compiler 1.33.0 (`b7eee5c`) `src/validation/argument.rs`,
`src/validation/value.rs`, the `validate_directives` function of
`src/validation/directive.rs` and the `validate_variable_usage` function of
`src/validation/variable.rs`, under the MIT arm of its MIT OR Apache-2.0
license.

A type reference is a `NamedType`, `ListType` or `NonNullType` node of a
document. The variable definitions of an operation are the
`VariableDefinition` children of an operation node in `var_document`.
`operation` is `NO_NODE` where there are none, as in a schema.

**Differences from upstream.**

- `validate_arguments` finds a repeated argument by a scan when a node
  has 8 arguments or fewer, and by a `NameTable` above that. Upstream
  always hashes.
- A directive, an argument and a value are nodes of a document, and a
  type is a type reference node. Upstream keeps `Node` pointers.
"""

from gql_language.ast import Document, Kind, NO_NODE, Role
from gql_language.directive_location import DirectiveLocation
from gql_language.names import NameTable
from gql_compiler.diagnostics import Diagnostic, DiagnosticKind, DiagnosticList
from gql_compiler.schema import Schema, TypeKind


def type_string(document: Document, node: Int) -> String:
    """Return a type reference as upstream `ast::Type` displays it.

    Args:
        document: The document of the type.
        node: A `NamedType`, `ListType` or `NonNullType` node.

    Returns:
        The type, as `[Int!]!`.
    """
    var kind = document.kind(node)
    if kind == Kind.NAMED_TYPE:
        return String(document.name(node))
    var inner = type_string(document, document.first_child(node))
    if kind == Kind.LIST_TYPE:
        return String("[", inner, "]")
    return inner + "!"


def is_non_null(document: Document, node: Int) -> Bool:
    """Return True for a `NonNullType` node.

    Args:
        document: The document of the type.
        node: A type reference node.

    Returns:
        Whether the type is non-null.
    """
    return document.kind(node) == Kind.NON_NULL_TYPE


def item_type(document: Document, node: Int) -> Int:
    """Return the item type of a list type: upstream `Type::item_type`.

    Args:
        document: The document of the type.
        node: A type reference node.

    Returns:
        The inner type of a list or a non-null list, or the node itself.
    """
    var current = node
    if document.kind(current) == Kind.NON_NULL_TYPE:
        current = document.first_child(current)
    if document.kind(current) == Kind.LIST_TYPE:
        return document.first_child(current)
    return node


def is_list(document: Document, node: Int) -> Bool:
    """Return True for a list or a non-null list: upstream `Type::is_list`.

    Args:
        document: The document of the type.
        node: A type reference node.

    Returns:
        Whether the type is a list.
    """
    var current = node
    if document.kind(current) == Kind.NON_NULL_TYPE:
        current = document.first_child(current)
    return document.kind(current) == Kind.LIST_TYPE


def is_assignable_to(
    document: Document,
    node: Int,
    target_document: Document,
    target: Int,
    target_nullable: Bool = False,
) -> Bool:
    """Return True when a value of one type can be used where another is
    expected: upstream `Type::is_assignable_to`.

    Args:
        document: The document of the type.
        node: The type reference to assign.
        target_document: The document of the target type.
        target: The target type reference.
        target_nullable: Whether to read the target without its outer
            non-null wrapper: upstream `nullable()`.

    Returns:
        Whether `node` is assignable to `target`.
    """
    var t = target
    var t_non_null = target_document.kind(t) == Kind.NON_NULL_TYPE
    if t_non_null:
        t = target_document.first_child(t)
        if target_nullable:
            t_non_null = False
    var s = node
    var s_non_null = document.kind(s) == Kind.NON_NULL_TYPE
    if s_non_null:
        s = document.first_child(s)
    if t_non_null and not s_non_null:
        return False
    var t_list = target_document.kind(t) == Kind.LIST_TYPE
    var s_list = document.kind(s) == Kind.LIST_TYPE
    if t_list != s_list:
        return False
    if t_list:
        return is_assignable_to(
            document,
            document.first_child(s),
            target_document,
            target_document.first_child(t),
        )
    return document.name(s) == target_document.name(t)


def _has_argument(
    document: Document, owner: Int, name: StringSlice, before: Int
) -> Bool:
    """Return True when an argument before `before` has the name."""
    var child = document.first_child(owner)
    while child != before:
        if (
            document.role(child) == Role.ARGUMENT
            and document.name(child) == name
        ):
            return True
        child = document.next_sibling(child)
    return False


def validate_arguments(
    document: Document, owner: Int, file: Int, mut list: DiagnosticList
):
    """Report each argument that is given more than once: upstream
    `validate_arguments`.

    Args:
        document: The document of the arguments.
        owner: A field or directive node with `Argument` children.
        file: The rank of the document's file in `list`.
        list: The list to add the diagnostics to.
    """
    var total = document.count(owner, Role.ARGUMENT)
    if total < 2:
        return
    # A long argument list is checked with a hash, a short one by a scan.
    var table = NameTable(capacity=total if total > 8 else 1)
    var child = document.first_child(owner)
    var count = 0
    while child != NO_NODE:
        if document.role(child) == Role.ARGUMENT:
            var repeated: Bool
            if total > 8:
                repeated = not table.insert(0, document.name(child), count)
            else:
                repeated = count > 0 and _has_argument(
                    document, owner, document.name(child), child
                )
            if repeated:
                list.push(
                    Diagnostic(
                        DiagnosticKind.UNIQUE_ARGUMENT,
                        file,
                        document.start(child),
                        String(document.name(child)),
                    )
                )
            count += 1
        child = document.next_sibling(child)


def find_argument(document: Document, owner: Int, name: StringSlice) -> Int:
    """Return the first `Argument` child of a node with a name.

    Args:
        document: The document of the node.
        owner: A field or directive node.
        name: The argument name.

    Returns:
        The argument node, or `NO_NODE`.
    """
    var child = document.first_child(owner)
    while child != NO_NODE:
        if (
            document.role(child) == Role.ARGUMENT
            and document.name(child) == name
        ):
            return child
        child = document.next_sibling(child)
    return NO_NODE


def is_required(document: Document, definition: Int) -> Bool:
    """Return True for an input value with a non-null type and no default:
    upstream `InputValueDefinition::is_required`.

    Args:
        document: The document of the definition.
        definition: An `InputValueDefinition` node.

    Returns:
        Whether a value must be given.
    """
    return (
        is_non_null(document, document.child(definition, Role.TYPE))
        and document.child(definition, Role.DEFAULT_VALUE) == NO_NODE
    )


def find_variable(
    var_document: Document, operation: Int, name: StringSlice
) -> Int:
    """Return the variable definition of an operation with a name.

    Args:
        var_document: The document of the operation.
        operation: An operation node.
        name: The variable name, without `$`.

    Returns:
        The `VariableDefinition` node, or `NO_NODE`.
    """
    # A caller with no operation passes `NO_NODE` only for const values,
    # which hold no variable, so this is never called then.
    var child = var_document.first_child(operation)
    while child != NO_NODE:
        if var_document.role(child) == Role.VARIABLE_DEFINITION:
            var variable = var_document.child(child, Role.VARIABLE)
            if var_document.name(variable) == name:
                return child
        child = var_document.next_sibling(child)
    return NO_NODE


def _has_location(
    document: Document, definition: Int, location: DirectiveLocation
) -> Bool:
    """Return True when a directive definition lists a location."""
    var text = location.text()
    var child = document.first_child(definition)
    while child != NO_NODE:
        if (
            document.role(child) == Role.LOCATION
            and document.text(child) == text
        ):
            return True
        child = document.next_sibling(child)
    return False


def validate_directive(
    schema: Schema,
    document: Document,
    directive: Int,
    location: DirectiveLocation,
    file: Int,
    mut seen: List[String],
    mut list: DiagnosticList,
    var_document: Document,
    operation: Int,
):
    """Validate one directive application: the loop body of upstream
    `validate_directives`.

    Args:
        schema: The schema.
        document: The document of the directive.
        directive: A `Directive` node.
        location: Where the directive is applied.
        file: The rank of the document's file in `list`.
        seen: The directive names already applied at this location. The
            name is added.
        list: The list to add the diagnostics to.
        var_document: The document of the operation.
        operation: The operation whose variables are in scope, or
            `NO_NODE`.
    """
    validate_arguments(document, directive, file, list)
    var name = document.name(directive)
    var index = schema.get_directive_definition(name)
    var at = document.start(directive)
    var repeated = False
    for ref previous in seen:
        if previous == name:
            repeated = True
    if repeated:
        var repeatable = True
        if index >= 0:
            ref definition = schema.directive_definitions[index]
            repeatable = schema.sources[Int(definition.source)].is_repeatable(
                Int(definition.node)
            )
        if not repeatable:
            list.push(
                Diagnostic(
                    DiagnosticKind.UNIQUE_DIRECTIVE, file, at, String(name)
                )
            )
    else:
        seen.append(String(name))
    if index < 0:
        list.push(
            Diagnostic(
                DiagnosticKind.UNDEFINED_DIRECTIVE, file, at, String(name)
            )
        )
        return
    ref definition = schema.directive_definitions[index]
    ref def_document = schema.sources[Int(definition.source)]
    var def_node = Int(definition.node)
    if not _has_location(def_document, def_node, location):
        list.push(
            Diagnostic(
                DiagnosticKind.UNSUPPORTED_LOCATION,
                file,
                at,
                String(name),
                String(location.text()),
            )
        )
    var child = document.first_child(directive)
    while child != NO_NODE:
        if document.role(child) == Role.ARGUMENT:
            var input_value = find_argument(
                def_document, def_node, document.name(child)
            )
            if input_value == NO_NODE:
                list.push(
                    Diagnostic(
                        DiagnosticKind.UNDEFINED_ARGUMENT,
                        file,
                        document.start(child),
                        String(document.name(child)),
                        String("@", name),
                    )
                )
            elif validate_variable_usage(
                def_document,
                input_value,
                document,
                child,
                file,
                list,
                var_document,
                operation,
            ):
                value_of_correct_type(
                    schema,
                    def_document,
                    def_document.child(input_value, Role.TYPE),
                    document,
                    document.child(child, Role.VALUE),
                    file,
                    list,
                    var_document,
                    operation,
                )
        child = document.next_sibling(child)
    var arg_def = def_document.first_child(def_node)
    while arg_def != NO_NODE:
        if def_document.role(arg_def) == Role.ARGUMENT and is_required(
            def_document, arg_def
        ):
            var argument = find_argument(
                document, directive, def_document.name(arg_def)
            )
            if (
                argument == NO_NODE
                or document.kind(document.child(argument, Role.VALUE))
                == Kind.NULL
            ):
                list.push(
                    Diagnostic(
                        DiagnosticKind.REQUIRED_ARGUMENT,
                        file,
                        at,
                        String(
                            "@",
                            def_document.name(def_node),
                            "(",
                            def_document.name(arg_def),
                            ":)",
                        ),
                    )
                )
        arg_def = def_document.next_sibling(arg_def)


def validate_directives(
    schema: Schema,
    document: Document,
    owner: Int,
    location: DirectiveLocation,
    file: Int,
    mut list: DiagnosticList,
    var_document: Document,
    operation: Int,
):
    """Validate the `Directive` children of a node: upstream
    `validate_directives`.

    Args:
        schema: The schema.
        document: The document of the node.
        owner: The node with `Directive` children.
        location: Where the directives are applied.
        file: The rank of the document's file in `list`.
        list: The list to add the diagnostics to.
        var_document: The document of the operation.
        operation: The operation whose variables are in scope, or
            `NO_NODE`.
    """
    var seen = List[String]()
    var child = document.first_child(owner)
    while child != NO_NODE:
        if document.role(child) == Role.DIRECTIVE:
            validate_directive(
                schema,
                document,
                child,
                location,
                file,
                seen,
                list,
                var_document,
                operation,
            )
        child = document.next_sibling(child)


def describe_value(kind: Kind) -> StaticString:
    """Return how upstream `Value::describe` names a value.

    Args:
        kind: The kind of a value node.

    Returns:
        The description, as `an integer`.
    """
    if kind == Kind.NULL:
        return "null"
    if kind == Kind.ENUM:
        return "an enum"
    if kind == Kind.VARIABLE:
        return "a variable"
    if kind == Kind.STRING:
        return "a string"
    if kind == Kind.FLOAT:
        return "a float"
    if kind == Kind.INT:
        return "an integer"
    if kind == Kind.BOOLEAN:
        return "a boolean"
    if kind == Kind.LIST:
        return "a list"
    return "an input object"


def int_fits_i32(text: StringSlice) -> Bool:
    """Return True when an integer literal fits a 32-bit signed integer:
    upstream `IntValue::try_to_i32`.

    Args:
        text: An integer literal, as `-12`.

    Returns:
        Whether it is in the `i32` range.
    """
    var bytes = text.as_bytes()
    var negative = len(bytes) > 0 and bytes[0] == UInt8(ord("-"))
    var index = 1 if negative else 0
    var magnitude = 0
    while index < len(bytes):
        magnitude = magnitude * 10 + Int(bytes[index] - UInt8(ord("0")))
        if magnitude > 2147483648:
            return False
        index += 1
    return magnitude < 2147483648 or negative


def float_is_finite(text: StringSlice) -> Bool:
    """Return True when a number literal is a finite 64-bit float: upstream
    `try_to_f64`.

    Args:
        text: An integer or float literal.

    Returns:
        Whether it does not overflow to infinity.
    """
    try:
        var value = atof(text)
        return (
            value <= 1.7976931348623157e308 and value >= -1.7976931348623157e308
        )
    except:
        return False


def _unsupported(
    type_document: Document,
    type_node: Int,
    document: Document,
    value: Int,
    file: Int,
    mut list: DiagnosticList,
):
    """Report `UnsupportedValueType`."""
    list.push(
        Diagnostic(
            DiagnosticKind.UNSUPPORTED_VALUE_TYPE,
            file,
            document.start(value),
            type_string(type_document, type_node),
            String(describe_value(document.kind(value))),
        )
    )


def value_of_correct_type(
    schema: Schema,
    type_document: Document,
    type_node: Int,
    document: Document,
    value: Int,
    file: Int,
    mut list: DiagnosticList,
    var_document: Document,
    operation: Int,
):
    """Report a value that the type does not accept: upstream
    `value_of_correct_type`.

    Args:
        schema: The schema.
        type_document: The document of the type.
        type_node: The expected type reference.
        document: The document of the value.
        value: A value node.
        file: The rank of the value's file in `list`.
        list: The list to add the diagnostics to.
        var_document: The document of the operation.
        operation: The operation whose variables are in scope, or
            `NO_NODE`.
    """
    var named = type_document.named_type(type_node)
    var index = schema.get_type(named)
    if index < 0:
        return
    var kind = schema.types[index].kind
    var scalar = kind == TypeKind.SCALAR
    var custom = scalar and not schema.is_built_in(index)
    var value_kind = document.kind(value)
    var ok = True
    if value_kind == Kind.INT:
        if not scalar:
            ok = False
        elif custom or named == "ID":
            pass
        elif named == "Int":
            if not int_fits_i32(document.text(value)):
                list.push(
                    Diagnostic(
                        DiagnosticKind.INT_COERCION_ERROR,
                        file,
                        document.start(value),
                        String(document.text(value)),
                    )
                )
        elif named == "Float":
            if not float_is_finite(document.text(value)):
                list.push(
                    Diagnostic(
                        DiagnosticKind.FLOAT_COERCION_ERROR,
                        file,
                        document.start(value),
                        String(document.text(value)),
                    )
                )
        else:
            ok = False
    elif value_kind == Kind.FLOAT:
        if custom:
            pass
        elif scalar and named == "Float":
            if not float_is_finite(document.text(value)):
                list.push(
                    Diagnostic(
                        DiagnosticKind.FLOAT_COERCION_ERROR,
                        file,
                        document.start(value),
                        String(document.text(value)),
                    )
                )
        else:
            ok = False
    elif value_kind == Kind.STRING:
        ok = scalar and (custom or named == "String" or named == "ID")
    elif value_kind == Kind.BOOLEAN:
        ok = scalar and (custom or named == "Boolean")
    elif value_kind == Kind.NULL:
        ok = not is_non_null(type_document, type_node)
    elif value_kind == Kind.VARIABLE:
        var variable = find_variable(
            var_document, operation, document.name(value)
        )
        if variable == NO_NODE:
            list.push(
                Diagnostic(
                    DiagnosticKind.UNDEFINED_VARIABLE,
                    file,
                    document.start(value),
                    String(document.name(value)),
                )
            )
        elif (
            kind == TypeKind.OBJECT
            or kind == TypeKind.INTERFACE
            or kind == TypeKind.UNION
        ):
            ok = False
        else:
            ok = (
                var_document.named_type(var_document.child(variable, Role.TYPE))
                == named
            )
    elif value_kind == Kind.ENUM:
        if custom:
            pass
        elif kind == TypeKind.ENUM:
            if schema.find_member(index, document.text(value)) < 0:
                list.push(
                    Diagnostic(
                        DiagnosticKind.UNDEFINED_ENUM_VALUE,
                        file,
                        document.start(value),
                        String(document.text(value)),
                        String(named),
                    )
                )
        else:
            ok = False
    elif value_kind == Kind.LIST:
        if not (is_list(type_document, type_node) or custom):
            ok = False
        else:
            var item = item_type(type_document, type_node)
            if (
                kind == TypeKind.SCALAR
                or kind == TypeKind.ENUM
                or kind == TypeKind.INPUT_OBJECT
            ):
                var child = document.first_child(value)
                while child != NO_NODE:
                    value_of_correct_type(
                        schema,
                        type_document,
                        item,
                        document,
                        child,
                        file,
                        list,
                        var_document,
                        operation,
                    )
                    child = document.next_sibling(child)
            else:
                _unsupported(type_document, item, document, value, file, list)
    elif custom:
        pass
    elif kind == TypeKind.INPUT_OBJECT:
        _input_object(
            schema,
            index,
            document,
            value,
            file,
            list,
            var_document,
            operation,
        )
    else:
        ok = False
    if not ok:
        _unsupported(type_document, type_node, document, value, file, list)


def _object_field(document: Document, value: Int, name: StringSlice) -> Int:
    """Return the first field of an object value with a name, or
    `NO_NODE`."""
    var child = document.first_child(value)
    while child != NO_NODE:
        if document.name(child) == name:
            return child
        child = document.next_sibling(child)
    return NO_NODE


def _input_object(
    schema: Schema,
    index: Int,
    document: Document,
    value: Int,
    file: Int,
    mut list: DiagnosticList,
    var_document: Document,
    operation: Int,
):
    """Validate an object value for an input object type."""
    var child = document.first_child(value)
    while child != NO_NODE:
        if schema.find_member(index, document.name(child)) < 0:
            list.push(
                Diagnostic(
                    DiagnosticKind.UNDEFINED_INPUT_VALUE,
                    file,
                    document.start(document.child(child, Role.VALUE)),
                    String(document.name(child)),
                    String(schema.type_name(index)),
                )
            )
            break
        child = document.next_sibling(child)
    var count = schema.member_count(index)
    var position = 0
    while position < count:
        var member = schema.member(index, position)
        ref field_document = schema.sources[Int(member.source)]
        var field = Int(member.node)
        var field_type = field_document.child(field, Role.TYPE)
        var used = _object_field(document, value, field_document.name(field))
        var used_value = NO_NODE
        if used != NO_NODE:
            used_value = document.child(used, Role.VALUE)
        if is_required(field_document, field) and (
            used == NO_NODE or document.kind(used_value) == Kind.NULL
        ):
            list.push(
                Diagnostic(
                    DiagnosticKind.REQUIRED_FIELD,
                    file,
                    document.start(value),
                    String(
                        schema.type_name(index), ".", field_document.name(field)
                    ),
                )
            )
        if used != NO_NODE:
            value_of_correct_type(
                schema,
                field_document,
                field_type,
                document,
                used_value,
                file,
                list,
                var_document,
                operation,
            )
        position += 1


def validate_variable_usage(
    definition_document: Document,
    definition: Int,
    document: Document,
    argument: Int,
    file: Int,
    mut list: DiagnosticList,
    var_document: Document,
    operation: Int,
) -> Bool:
    """Report a variable whose type cannot be used for an argument:
    upstream `validate_variable_usage`.

    Args:
        definition_document: The document of the argument definition.
        definition: An `InputValueDefinition` node.
        document: The document of the argument.
        argument: An `Argument` node.
        file: The rank of the argument's file in `list`.
        list: The list to add the diagnostics to.
        var_document: The document of the operation.
        operation: The operation whose variables are in scope, or
            `NO_NODE`.

    Returns:
        False when a diagnostic was added: upstream `Err(())`.
    """
    var value = document.child(argument, Role.VALUE)
    if document.kind(value) != Kind.VARIABLE:
        return True
    var variable = find_variable(var_document, operation, document.name(value))
    if variable == NO_NODE:
        return True
    var variable_type = var_document.child(variable, Role.TYPE)
    var location_type = definition_document.child(definition, Role.TYPE)
    var allowed: Bool
    if is_non_null(definition_document, location_type) and not is_non_null(
        var_document, variable_type
    ):
        var has_default = (
            var_document.child(variable, Role.DEFAULT_VALUE) != NO_NODE
            or definition_document.child(definition, Role.DEFAULT_VALUE)
            != NO_NODE
        )
        allowed = has_default and is_assignable_to(
            var_document,
            variable_type,
            definition_document,
            location_type,
            target_nullable=True,
        )
    else:
        allowed = is_assignable_to(
            var_document, variable_type, definition_document, location_type
        )
    if not allowed:
        list.push(
            Diagnostic(
                DiagnosticKind.DISALLOWED_VARIABLE_USAGE,
                file,
                document.start(argument),
                String(document.name(value)),
                type_string(var_document, variable_type),
                String(document.name(argument)),
                type_string(definition_document, location_type),
            )
        )
        return False
    return True

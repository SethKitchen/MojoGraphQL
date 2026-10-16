# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Validate a schema: the "Type Validation" rules of the specification's
"Type System" section.

Port of graphql-js 16.14.2 `type/validate.ts` (`validateSchema`,
`assertValidSchema`). The rules run in the graphql-js order: the root
types, the directives, then each type of the type map, in type map order.
The messages and the locations are the graphql-js messages and locations.

A type index or a `TypeRef` whose named index is out of range is the
graphql-js `undefined`. It shows as `undefined` in a message, as graphql-js
shows a missing type, and it is never an input or an output type.

**Differences from graphql-js.**

- graphql-js keeps the errors on the schema (`__validationErrors`) and
  returns them again on the next call. A Mojo schema is a value that the
  caller can change, so `validate_schema` runs the rules on each call. Keep
  the result to validate once.
- graphql-js first checks that each type and directive is a GraphQL object
  (`Expected GraphQL named type but got: ...`). The arenas hold only types
  and directives, so that error comes only from a type map index out of
  range (`undefined`) or a type with an invalid `TypeKind` (its name).
"""

from gql_language.ast import NO_NODE, OperationType, Role
from gql_language.error import GraphQLError
from gql_schema.definition import (
    AstRef,
    InputValueDef,
    Range,
    Schema,
    TypeKind,
    TypeRef,
)
from gql_schema.errors import schema_error
from gql_schema.type_comparators import is_equal_type, is_type_sub_type_of


# --- types out of range -----------------------------------------------------


@always_inline
def _is_type(schema: Schema, type: Int) -> Bool:
    """Return True if an index names a type of the schema."""
    return type >= 0 and type < len(schema.types)


def _kind(schema: Schema, type: Int) -> TypeKind:
    """Return a type's kind, or an invalid kind for an index out of range."""
    if not _is_type(schema, type):
        return TypeKind(255)
    return schema.types[type].kind


def _name(schema: Schema, type: Int) -> String:
    """Return a named type as graphql-js `inspect` writes it."""
    if not _is_type(schema, type):
        return String("undefined")
    return schema.types[type].name


def _text(schema: Schema, type: TypeRef) -> String:
    """Return a type reference as graphql-js `inspect` writes it."""
    if not _is_type(schema, Int(type.named)):
        return String("undefined")
    return schema.type_name(type)


def _is_input(schema: Schema, type: TypeRef) -> Bool:
    """Return the graphql-js `isInputType`."""
    return _kind(schema, Int(type.named)).is_input()


def _is_output(schema: Schema, type: TypeRef) -> Bool:
    """Return the graphql-js `isOutputType`."""
    return _kind(schema, Int(type.named)).is_output()


def _is_required(value: InputValueDef) -> Bool:
    """Return the graphql-js `isRequiredArgument` and
    `isRequiredInputField`."""
    return value.type.is_non_null() and not value.has_default()


# --- nodes ------------------------------------------------------------------


def _type_node(schema: Schema, at: AstRef) -> AstRef:
    """Return the `type` child of a definition node, as `astNode?.type`."""
    if not at.exists():
        return AstRef.NONE
    ref document = schema.documents[Int(at.document)]
    return AstRef(at.document, Int32(document.child(Int(at.node), Role.TYPE)))


def _deprecated_node(schema: Schema, at: AstRef) -> AstRef:
    """Return the `@deprecated` directive of a definition node, as
    `getDeprecatedDirectiveNode`."""
    if not at.exists():
        return AstRef.NONE
    ref document = schema.documents[Int(at.document)]
    var current = document.first_child(Int(at.node))
    while current != NO_NODE:
        if (
            document.role(current) == Role.DIRECTIVE
            and document.name(current) == "deprecated"
        ):
            return AstRef(at.document, Int32(current))
        current = document.next_sibling(current)
    return AstRef.NONE


def _type_nodes(schema: Schema, type: Int) -> List[AstRef]:
    """Return a type's definition node and its extension nodes, as
    `[type.astNode, ...type.extensionASTNodes]`."""
    ref named = schema.types[type]
    var out: List[AstRef] = [named.definition]
    var index = Int(named.extensions.start)
    while index < named.extensions.end():
        out.append(schema.ast_refs[index])
        index += 1
    return out^


def _collect_named(
    schema: Schema, at: AstRef, role: Role, name: String, mut out: List[AstRef]
):
    """Append the children of a node that have a role and name a type."""
    if not at.exists():
        return
    ref document = schema.documents[Int(at.document)]
    var current = document.first_child(Int(at.node))
    while current != NO_NODE:
        if document.role(current) == role and document.name(current) == name:
            out.append(AstRef(at.document, Int32(current)))
        current = document.next_sibling(current)


def _named_type_nodes(
    schema: Schema, type: Int, role: Role, name: String
) -> List[AstRef]:
    """Return the named type nodes with a name among a type's interfaces or
    union members, as `getAllImplementsInterfaceNodes` and
    `getUnionMemberTypeNodes`."""
    var out = List[AstRef]()
    ref named = schema.types[type]
    _collect_named(schema, named.definition, role, name, out)
    var index = Int(named.extensions.start)
    while index < named.extensions.end():
        _collect_named(schema, schema.ast_refs[index], role, name, out)
        index += 1
    return out^


def _operation_in(
    schema: Schema, at: AstRef, operation: OperationType
) -> AstRef:
    """Return the type node of a schema node's operation type definition
    for an operation, or none."""
    if not at.exists():
        return AstRef.NONE
    ref document = schema.documents[Int(at.document)]
    var current = document.first_child(Int(at.node))
    while current != NO_NODE:
        if (
            document.role(current) == Role.OPERATION_TYPE
            and document.operation(current) == operation
        ):
            return AstRef(
                at.document, Int32(document.child(current, Role.TYPE))
            )
        current = document.next_sibling(current)
    return AstRef.NONE


def _root_node(schema: Schema, operation: OperationType, type: Int) -> AstRef:
    """Return the type node of the first operation type definition for an
    operation, in `schema` then in `extend schema`, as
    `getOperationTypeNode`; else the root type's definition."""
    var found = _operation_in(schema, schema.schema_definition, operation)
    ref span = schema.schema_extensions
    var index = Int(span.start)
    while not found.exists() and index < span.end():
        found = _operation_in(schema, schema.ast_refs[index], operation)
        index += 1
    if found.exists():
        return found
    return schema.types[type].definition


# --- the rules --------------------------------------------------------------


struct _Context:
    """The errors found so far, and the scratch state of the rules."""

    var errors: List[GraphQLError]
    """The errors, in the order found."""
    var seen: List[Int32]
    """For each type, the stamp of the last type whose interfaces or
    members included it."""
    var visited: List[Bool]
    """For each type, whether the cycle search reached it."""
    var path_index: List[Int]
    """For each type on the cycle search path, its position; -1 for
    others."""

    def __init__(out self, types: Int):
        """Start with no errors.

        Args:
            types: How many types the schema has.
        """
        self.errors = List[GraphQLError]()
        self.seen = List[Int32](length=types, fill=0)
        self.visited = List[Bool](length=types, fill=False)
        self.path_index = List[Int](length=types, fill=-1)

    def report(
        mut self, message: String, schema: Schema, var nodes: List[AstRef]
    ):
        """Add an error located at nodes, as `reportError`.

        Args:
            message: The description.
            schema: The schema whose documents hold the nodes.
            nodes: The nodes; references that name no node are skipped.
        """
        self.errors.append(schema_error(message, schema, nodes))

    def take_errors(deinit self) -> List[GraphQLError]:
        """End the context and return its errors.

        Returns:
            The errors, in the order found.
        """
        return self.errors^


def _validate_name(
    mut context: _Context, schema: Schema, name: String, at: AstRef
):
    """Report a name that starts with `__`, as `validateName`."""
    if name.startswith("__"):
        context.report(
            'Name "'
            + name
            + '" must not begin with "__", which is reserved by GraphQL'
            " introspection.",
            schema,
            [at],
        )


def _validate_root_types(mut context: _Context, schema: Schema):
    """Check that the root types are object types, as `validateRootTypes`."""
    var query = Int(schema.query_type)
    if not _is_type(schema, query):
        context.report(
            "Query root type must be provided.",
            schema,
            [schema.schema_definition],
        )
    elif schema.types[query].kind != TypeKind.OBJECT:
        context.report(
            "Query root type must be Object type, it cannot be "
            + schema.types[query].name
            + ".",
            schema,
            [_root_node(schema, OperationType.QUERY, query)],
        )
    var mutation = Int(schema.mutation_type)
    if (
        _is_type(schema, mutation)
        and schema.types[mutation].kind != TypeKind.OBJECT
    ):
        context.report(
            "Mutation root type must be Object type if provided, it cannot be "
            + schema.types[mutation].name
            + ".",
            schema,
            [_root_node(schema, OperationType.MUTATION, mutation)],
        )
    var subscription = Int(schema.subscription_type)
    if (
        _is_type(schema, subscription)
        and schema.types[subscription].kind != TypeKind.OBJECT
    ):
        context.report(
            "Subscription root type must be Object type if provided, it"
            " cannot be "
            + schema.types[subscription].name
            + ".",
            schema,
            [_root_node(schema, OperationType.SUBSCRIPTION, subscription)],
        )


def _validate_directives(mut context: _Context, schema: Schema):
    """Check the directives' names, locations and arguments, as
    `validateDirectives`."""
    var directive_index = 0
    while directive_index < len(schema.directives):
        ref directive = schema.directives[directive_index]
        directive_index += 1
        _validate_name(context, schema, directive.name, directive.definition)
        if directive.locations == 0:
            context.report(
                "Directive @"
                + directive.name
                + " must include 1 or more locations.",
                schema,
                [directive.definition],
            )
        var index = Int(directive.arguments.start)
        while index < directive.arguments.end():
            ref arg = schema.input_values[index]
            index += 1
            _validate_name(context, schema, arg.name, arg.definition)
            if not _is_input(schema, arg.type):
                context.report(
                    "The type of @"
                    + directive.name
                    + "("
                    + arg.name
                    + ":) must be Input Type but got: "
                    + _text(schema, arg.type)
                    + ".",
                    schema,
                    [arg.definition],
                )
            if _is_required(arg) and arg.is_deprecated:
                context.report(
                    "Required argument @"
                    + directive.name
                    + "("
                    + arg.name
                    + ":) cannot be deprecated.",
                    schema,
                    [
                        _deprecated_node(schema, arg.definition),
                        _type_node(schema, arg.definition),
                    ],
                )


def _validate_fields(mut context: _Context, schema: Schema, type: Int):
    """Check the fields of an object or interface type, as
    `validateFields`."""
    ref named = schema.types[type]
    if named.fields.count == 0:
        context.report(
            "Type " + named.name + " must define one or more fields.",
            schema,
            _type_nodes(schema, type),
        )
    var field_index = Int(named.fields.start)
    while field_index < named.fields.end():
        ref field = schema.fields[field_index]
        field_index += 1
        _validate_name(context, schema, field.name, field.definition)
        if not _is_output(schema, field.type):
            context.report(
                "The type of "
                + named.name
                + "."
                + field.name
                + " must be Output Type but got: "
                + _text(schema, field.type)
                + ".",
                schema,
                [_type_node(schema, field.definition)],
            )
        var index = Int(field.arguments.start)
        while index < field.arguments.end():
            ref arg = schema.input_values[index]
            index += 1
            _validate_name(context, schema, arg.name, arg.definition)
            if not _is_input(schema, arg.type):
                context.report(
                    "The type of "
                    + named.name
                    + "."
                    + field.name
                    + "("
                    + arg.name
                    + ":) must be Input Type but got: "
                    + _text(schema, arg.type)
                    + ".",
                    schema,
                    [_type_node(schema, arg.definition)],
                )
            if _is_required(arg) and arg.is_deprecated:
                context.report(
                    "Required argument "
                    + named.name
                    + "."
                    + field.name
                    + "("
                    + arg.name
                    + ":) cannot be deprecated.",
                    schema,
                    [
                        _deprecated_node(schema, arg.definition),
                        _type_node(schema, arg.definition),
                    ],
                )


def _implements_nodes(schema: Schema, type: Int, iface: Int) -> List[AstRef]:
    """Return the nodes where a type names an interface, as
    `getAllImplementsInterfaceNodes`."""
    return _named_type_nodes(schema, type, Role.INTERFACE, _name(schema, iface))


def _includes(schema: Schema, span: Range, type: Int) -> Bool:
    """Return True if a run of `schema.type_lists` holds a type."""
    var index = Int(span.start)
    while index < span.end():
        if Int(schema.type_lists[index]) == type:
            return True
        index += 1
    return False


def _validate_ancestors(
    mut context: _Context, schema: Schema, type: Int, iface: Int
):
    """Check that a type implements the interfaces of an interface it
    implements, as `validateTypeImplementsAncestors`."""
    ref named = schema.types[type]
    ref parent = schema.types[iface]
    var index = Int(parent.interfaces.start)
    while index < parent.interfaces.end():
        var transitive = Int(schema.type_lists[index])
        index += 1
        if _includes(schema, named.interfaces, transitive):
            continue
        var message: String
        if transitive == type:
            message = (
                "Type "
                + named.name
                + " cannot implement "
                + parent.name
                + " because it would create a circular reference."
            )
        else:
            message = (
                "Type "
                + named.name
                + " must implement "
                + _name(schema, transitive)
                + " because it is implemented by "
                + parent.name
                + "."
            )
        var nodes = _implements_nodes(schema, iface, transitive)
        nodes.extend(_implements_nodes(schema, type, iface))
        context.report(message, schema, nodes^)


def _validate_field_arguments(
    mut context: _Context,
    schema: Schema,
    type: Int,
    iface: Int,
    type_field_index: Int,
    iface_field_index: Int,
):
    """Check that a field has the arguments of the interface field it
    implements, and no other required argument."""
    ref named = schema.types[type]
    ref parent = schema.types[iface]
    ref type_field = schema.fields[type_field_index]
    ref iface_field = schema.fields[iface_field_index]
    var index = Int(iface_field.arguments.start)
    while index < iface_field.arguments.end():
        ref iface_arg = schema.input_values[index]
        index += 1
        var type_arg_index = schema.argument_named(
            type_field_index, iface_arg.name
        )
        if type_arg_index < 0:
            context.report(
                "Interface field argument "
                + parent.name
                + "."
                + iface_field.name
                + "("
                + iface_arg.name
                + ":) expected but "
                + named.name
                + "."
                + iface_field.name
                + " does not provide it.",
                schema,
                [iface_arg.definition, type_field.definition],
            )
            continue
        ref type_arg = schema.input_values[type_arg_index]
        if not is_equal_type(iface_arg.type, type_arg.type):
            context.report(
                "Interface field argument "
                + parent.name
                + "."
                + iface_field.name
                + "("
                + iface_arg.name
                + ":) expects type "
                + _text(schema, iface_arg.type)
                + " but "
                + named.name
                + "."
                + iface_field.name
                + "("
                + iface_arg.name
                + ":) is type "
                + _text(schema, type_arg.type)
                + ".",
                schema,
                [
                    _type_node(schema, iface_arg.definition),
                    _type_node(schema, type_arg.definition),
                ],
            )
    index = Int(type_field.arguments.start)
    while index < type_field.arguments.end():
        ref type_arg = schema.input_values[index]
        index += 1
        if not _is_required(type_arg):
            continue
        if schema.argument_named(iface_field_index, type_arg.name) >= 0:
            continue
        context.report(
            "Object field "
            + named.name
            + "."
            + iface_field.name
            + " includes required argument "
            + type_arg.name
            + " that is missing from the Interface field "
            + parent.name
            + "."
            + iface_field.name
            + ".",
            schema,
            [type_arg.definition, iface_field.definition],
        )


def _validate_implements(
    mut context: _Context, schema: Schema, type: Int, iface: Int
):
    """Check that a type has the fields and arguments of an interface, as
    `validateTypeImplementsInterface`."""
    ref named = schema.types[type]
    ref parent = schema.types[iface]
    var iface_field_index = Int(parent.fields.start)
    while iface_field_index < parent.fields.end():
        ref iface_field = schema.fields[iface_field_index]
        iface_field_index += 1
        var type_field_index = schema.field_named(type, iface_field.name)
        if type_field_index < 0:
            var nodes: List[AstRef] = [iface_field.definition]
            nodes.extend(_type_nodes(schema, type))
            context.report(
                "Interface field "
                + parent.name
                + "."
                + iface_field.name
                + " expected but "
                + named.name
                + " does not provide it.",
                schema,
                nodes^,
            )
            continue
        ref type_field = schema.fields[type_field_index]
        if not is_type_sub_type_of(schema, type_field.type, iface_field.type):
            context.report(
                "Interface field "
                + parent.name
                + "."
                + iface_field.name
                + " expects type "
                + _text(schema, iface_field.type)
                + " but "
                + named.name
                + "."
                + iface_field.name
                + " is type "
                + _text(schema, type_field.type)
                + ".",
                schema,
                [
                    _type_node(schema, iface_field.definition),
                    _type_node(schema, type_field.definition),
                ],
            )
        _validate_field_arguments(
            context,
            schema,
            type,
            iface,
            type_field_index,
            iface_field_index - 1,
        )


def _validate_interfaces(mut context: _Context, schema: Schema, type: Int):
    """Check the interfaces an object or interface type implements, as
    `validateInterfaces`."""
    ref named = schema.types[type]
    var stamp = Int32(type + 1)
    var index = Int(named.interfaces.start)
    while index < named.interfaces.end():
        var iface = Int(schema.type_lists[index])
        index += 1
        if _kind(schema, iface) != TypeKind.INTERFACE:
            context.report(
                "Type "
                + named.name
                + " must only implement Interface types, it cannot implement "
                + _name(schema, iface)
                + ".",
                schema,
                _implements_nodes(schema, type, iface),
            )
            continue
        if iface == type:
            context.report(
                "Type "
                + named.name
                + " cannot implement itself because it would create a"
                " circular reference.",
                schema,
                _implements_nodes(schema, type, iface),
            )
            continue
        if context.seen[iface] == stamp:
            context.report(
                "Type "
                + named.name
                + " can only implement "
                + schema.types[iface].name
                + " once.",
                schema,
                _implements_nodes(schema, type, iface),
            )
            continue
        context.seen[iface] = stamp
        _validate_ancestors(context, schema, type, iface)
        _validate_implements(context, schema, type, iface)


def _validate_union_members(mut context: _Context, schema: Schema, type: Int):
    """Check a union's member types, as `validateUnionMembers`."""
    ref named = schema.types[type]
    if named.members.count == 0:
        context.report(
            "Union type "
            + named.name
            + " must define one or more member types.",
            schema,
            _type_nodes(schema, type),
        )
    var stamp = Int32(type + 1)
    var index = Int(named.members.start)
    while index < named.members.end():
        var member = Int(schema.type_lists[index])
        index += 1
        var is_type = _is_type(schema, member)
        var member_name = _name(schema, member)
        if is_type and context.seen[member] == stamp:
            context.report(
                "Union type "
                + named.name
                + " can only include type "
                + member_name
                + " once.",
                schema,
                _named_type_nodes(schema, type, Role.MEMBER_TYPE, member_name),
            )
            continue
        if is_type:
            context.seen[member] = stamp
        if _kind(schema, member) != TypeKind.OBJECT:
            context.report(
                "Union type "
                + named.name
                + " can only include Object types, it cannot include "
                + member_name
                + ".",
                schema,
                _named_type_nodes(schema, type, Role.MEMBER_TYPE, member_name),
            )


def _validate_enum_values(mut context: _Context, schema: Schema, type: Int):
    """Check an enum's values, as `validateEnumValues`."""
    ref named = schema.types[type]
    if named.enum_values.count == 0:
        context.report(
            "Enum type " + named.name + " must define one or more values.",
            schema,
            _type_nodes(schema, type),
        )
    var index = Int(named.enum_values.start)
    while index < named.enum_values.end():
        ref value = schema.enum_values[index]
        index += 1
        _validate_name(context, schema, value.name, value.definition)


def _validate_input_fields(mut context: _Context, schema: Schema, type: Int):
    """Check an input object's fields, as `validateInputFields` and
    `validateOneOfInputObjectField`."""
    ref named = schema.types[type]
    if named.input_fields.count == 0:
        context.report(
            "Input Object type "
            + named.name
            + " must define one or more fields.",
            schema,
            _type_nodes(schema, type),
        )
    var index = Int(named.input_fields.start)
    while index < named.input_fields.end():
        ref field = schema.input_values[index]
        index += 1
        _validate_name(context, schema, field.name, field.definition)
        if not _is_input(schema, field.type):
            context.report(
                "The type of "
                + named.name
                + "."
                + field.name
                + " must be Input Type but got: "
                + _text(schema, field.type)
                + ".",
                schema,
                [_type_node(schema, field.definition)],
            )
        if _is_required(field) and field.is_deprecated:
            context.report(
                "Required input field "
                + named.name
                + "."
                + field.name
                + " cannot be deprecated.",
                schema,
                [
                    _deprecated_node(schema, field.definition),
                    _type_node(schema, field.definition),
                ],
            )
        if not named.is_one_of:
            continue
        if field.type.is_non_null():
            context.report(
                "OneOf input field "
                + named.name
                + "."
                + field.name
                + " must be nullable.",
                schema,
                [_type_node(schema, field.definition)],
            )
        if field.has_default():
            context.report(
                "OneOf input field "
                + named.name
                + "."
                + field.name
                + " cannot have a default value.",
                schema,
                [field.definition],
            )


@fieldwise_init
struct _Frame(ImplicitlyCopyable, Movable):
    """An input object on the cycle search path, and its next field."""

    var type: Int
    """The input object's index."""
    var next: Int
    """The index in `Schema.input_values` of the next field to visit."""
    var end: Int
    """The index after its last field."""


def _non_null_input_object(schema: Schema, type: TypeRef) -> Int:
    """Return the input object that an `X!` field type names, or -1."""
    if not type.is_non_null():
        return -1
    var inner = type.of_type()
    if inner.is_wrapped():
        return -1
    if _kind(schema, Int(inner.named)) != TypeKind.INPUT_OBJECT:
        return -1
    return Int(inner.named)


def _report_cycle(
    mut context: _Context, schema: Schema, target: Int, path: List[Int]
):
    """Report the cycle that the last field of a path closes at a type."""
    var cycle = context.path_index[target]
    var text = String("")
    var nodes = List[AstRef]()
    var position = cycle
    while position < len(path):
        ref value = schema.input_values[path[position]]
        if position > cycle:
            text += "."
        text += value.name
        nodes.append(value.definition)
        position += 1
    context.report(
        'Cannot reference Input Object "'
        + schema.types[target].name
        + '" within itself through a series of non-null fields: "'
        + text
        + '".',
        schema,
        nodes^,
    )


def _enter(
    mut context: _Context,
    schema: Schema,
    type: Int,
    depth: Int,
    mut frames: List[_Frame],
):
    """Put an input object on the cycle search path."""
    context.visited[type] = True
    context.path_index[type] = depth
    ref fields = schema.types[type].input_fields
    frames.append(_Frame(type, Int(fields.start), fields.end()))


def _validate_input_cycles(mut context: _Context, schema: Schema, start: Int):
    """Report each cycle of non-null input object fields that a depth first
    search from an input object finds, as the
    `createInputObjectCircularRefsValidator` search does.

    The search goes on after a cycle, to find all the cycles. A type that an
    earlier search reached is not searched again.
    """
    if context.visited[start]:
        return
    var frames = List[_Frame]()
    var path = List[Int]()
    _enter(context, schema, start, 0, frames)
    while len(frames) > 0:
        var frame = frames[len(frames) - 1]
        if frame.next == frame.end:
            context.path_index[frame.type] = -1
            _ = frames.pop()
            # The field that led to the type leaves the path with it.
            if len(path) > 0:
                _ = path.pop()
            continue
        frames[len(frames) - 1].next = frame.next + 1
        var field = frame.next
        var target = _non_null_input_object(
            schema, schema.input_values[field].type
        )
        if target < 0:
            continue
        path.append(field)
        if context.path_index[target] >= 0:
            _report_cycle(context, schema, target, path)
            _ = path.pop()
        elif context.visited[target]:
            _ = path.pop()
        else:
            _enter(context, schema, target, len(path), frames)


def _validate_types(mut context: _Context, schema: Schema):
    """Check each type of the type map, as `validateTypes`."""
    var position = 0
    while position < len(schema.type_map):
        var type = Int(schema.type_map[position])
        position += 1
        if not _kind(schema, type).is_valid():
            context.report(
                "Expected GraphQL named type but got: "
                + _name(schema, type)
                + ".",
                schema,
                [],
            )
            continue
        ref named = schema.types[type]
        # The introspection types opt out; no specified scalar has a name
        # that starts with `__`.
        if not named.is_builtin:
            _validate_name(context, schema, named.name, named.definition)
        var kind = named.kind
        if kind.has_fields():
            _validate_fields(context, schema, type)
            _validate_interfaces(context, schema, type)
        elif kind == TypeKind.UNION:
            _validate_union_members(context, schema, type)
        elif kind == TypeKind.ENUM:
            _validate_enum_values(context, schema, type)
        elif kind == TypeKind.INPUT_OBJECT:
            _validate_input_fields(context, schema, type)
            _validate_input_cycles(context, schema, type)


def validate_schema(schema: Schema) -> List[GraphQLError]:
    """Return the schema's validation errors, as graphql-js
    `validateSchema`.

    Args:
        schema: The schema to check.

    Returns:
        The errors, in graphql-js order; empty for a valid schema.
    """
    var context = _Context(len(schema.types))
    _validate_root_types(context, schema)
    _validate_directives(context, schema)
    _validate_types(context, schema)
    return context^.take_errors()


def assert_valid_schema(schema: Schema) raises:
    """Raise when a schema is not valid, as graphql-js `assertValidSchema`.

    Args:
        schema: The schema to check.

    Raises:
        Error: The messages of all the validation errors, with a blank line
            between two messages.
    """
    var errors = validate_schema(schema)
    if len(errors) == 0:
        return
    var text = errors[0].message
    var index = 1
    while index < len(errors):
        text += "\n\n" + errors[index].message
        index += 1
    raise Error(text)

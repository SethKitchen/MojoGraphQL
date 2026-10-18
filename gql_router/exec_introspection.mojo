# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The router's own resolver of introspection fields.

Port of Hive Router `1a29df9`
`bin/router/src/executor/introspection/resolve.rs`.

`resolve_introspection` resolves the introspection part of an operation
(see `gql_router.exec_partition`) against the consumer schema (see
`gql_router.consumer_schema`). It writes the result into a `JsonDocument`
and returns the node of the data object. Each key is the response key of
its field: the alias, or the name. The keys are in selection order. The
members of an inline fragment are added in place, without a check of its
type condition, as upstream. A fragment spread adds nothing.

The root fields are `__schema`, `__type(name:)` and `__typename`. The
resolver knows every field of `__Schema`, `__Type`, `__Field`,
`__InputValue`, `__EnumValue` and `__Directive`. An unknown field is
`null`. `fields` and `enumValues` read `includeDeprecated` from a literal
or from a variable. `args` and `inputFields` give every value, as
upstream. `__Schema.description` is always `null`, and `ofType` of a named
type is `null`. `defaultValue` is the printed default value.

**Differences from upstream.**

- `__schema { types }` lists the types in document order, each name once
  (the first definition). Upstream reads a `HashMap`, so its order is not
  fixed.
- `possibleTypes` lists the types in document order. Upstream reads a
  `HashSet`.
- A type reference to a type that the schema does not define, and a
  missing query type, give `null`. Upstream panics.
- `defaultValue` is graphql-js `print` text. Upstream uses `graphql_tools`
  `Display`, which is the same for the values that a schema uses.

Upstream also ignores inline fragments directly in `__schema`; this port
keeps that behavior.
"""

from gql_json.value import JsonDocument, JsonKind
from gql_language.ast import NO_NODE, Document, Kind, OperationType, Role
from gql_language.printer import print_node
from gql_router.ast import NONE, ItemKind, ValueKind
from gql_router.exec_variables import CoerceVariablesPayload
from gql_router.federation_spec import OperationKind
from gql_router.operation import OperationDefinition
from gql_router.schema_metadata import SchemaMetadata
from gql_router.store import Store


struct _Index(Movable):
    """The type and directive definitions of a schema, as upstream
    `type_map` and `definitions`."""

    var types: Dict[String, Int]
    """The definition of each type name: the first one."""
    var order: List[Int]
    """The type definitions, in document order, one for each name."""
    var directives: List[Int]
    """The directive definitions, in document order."""

    def __init__(out self, schema: Document):
        """Read the definitions of a schema."""
        self.types = Dict[String, Int]()
        self.order = List[Int]()
        self.directives = List[Int]()
        var definition = schema.first_child(schema.root)
        while definition != NO_NODE:
            var kind = schema.kind(definition)
            if kind == Kind.DIRECTIVE_DEFINITION:
                self.directives.append(definition)
            elif kind.is_type_definition():
                var name = String(schema.name(definition))
                if name not in self.types:
                    self.types[name] = definition
                    self.order.append(definition)
            definition = schema.next_sibling(definition)

    def find(self, name: StringSlice) -> Int:
        """Return the definition of a type, or `NO_NODE`."""
        var found = self.types.get(String(name))
        if found:
            return found.value()
        return NO_NODE


def _fields(store: Store, item: Int, flatten: Bool) -> List[Int]:
    """Return the fields that a selection selects, in order.

    The members of an inline fragment are added in place when `flatten`
    is True, and skipped when it is False. A fragment spread is skipped.
    """
    var out = List[Int]()
    # The items still to visit, each followed by its next siblings.
    var stack: List[Int] = [store.items[item].first]
    while len(stack) > 0:
        var child = stack.pop()
        if child == NONE:
            continue
        var found = store.items[child]
        stack.append(found.next)
        if found.kind == ItemKind.FIELD:
            out.append(child)
        elif found.kind == ItemKind.FRAGMENT and flatten:
            stack.append(found.first)
    return out^


def _member(
    mut out: JsonDocument, object: Int, store: Store, item: Int, value: Int
):
    """Add a value to an object under the response key of a field."""
    out.add_member(object, store.name(store.response_key(item)), value)


def _field_name(store: Store, item: Int) -> String:
    """Return the name of a field."""
    return store.name(store.items[item].name)


def _directive(schema: Document, node: Int, name: StringSlice) -> Int:
    """Return the first directive of a definition with a name, or
    `NO_NODE`."""
    var child = schema.first_child(node)
    while child != NO_NODE:
        if schema.kind(child) == Kind.DIRECTIVE and schema.name(child) == name:
            return child
        child = schema.next_sibling(child)
    return NO_NODE


def _directive_string(
    schema: Document,
    node: Int,
    directive_name: StringSlice,
    argument_name: StringSlice,
) -> Int:
    """Return the string value of an argument of a directive, as upstream
    `get_deprecation_reason` and `get_specified_by_url`.

    Returns:
        The `StringValue` node, or `NO_NODE` when the directive, the
        argument or a string value is absent.
    """
    var directive = _directive(schema, node, directive_name)
    if directive == NO_NODE:
        return NO_NODE
    var argument = schema.child(directive, Role.ARGUMENT)
    while argument != NO_NODE:
        if schema.name(argument) == argument_name:
            var value = schema.child(argument, Role.VALUE)
            if schema.kind(value) == Kind.STRING:
                return value
            return NO_NODE
        argument = schema.next_with_role(argument)
    return NO_NODE


def _string_or_null(mut out: JsonDocument, schema: Document, node: Int) -> Int:
    """Add the decoded text of a `StringValue` node, or `null` for
    `NO_NODE`."""
    if node == NO_NODE:
        return out.add_null()
    return out.add_string(schema.string_value(node))


def _description(mut out: JsonDocument, schema: Document, node: Int) -> Int:
    """Add the description of a definition, or `null`."""
    return _string_or_null(out, schema, schema.child(node, Role.DESCRIPTION))


def _is_deprecated(schema: Document, node: Int) -> Bool:
    """Return True if a definition has `@deprecated`."""
    return _directive(schema, node, "deprecated") != NO_NODE


def _deprecation_reason(
    mut out: JsonDocument, schema: Document, node: Int
) -> Int:
    """Add the `reason` of `@deprecated`, or `null`."""
    return _string_or_null(
        out, schema, _directive_string(schema, node, "deprecated", "reason")
    )


def _include_deprecated(
    store: Store, variables: CoerceVariablesPayload, item: Int
) -> Bool:
    """Return the `includeDeprecated` argument of a field, or False."""
    var value = store.arg_value(
        store.items[item].args, store.find_sym("includeDeprecated")
    )
    if value == NONE:
        return False
    var found = store.values[value]
    if found.kind == ValueKind.BOOLEAN:
        return found.number != 0
    if found.kind == ValueKind.VARIABLE:
        return variables.bool_value(store.name(found.text)) == 1
    return False


def _kind_text(kind: Kind) -> StaticString:
    """Return the `__TypeKind` of a type definition, as upstream
    `kind_to_str`."""
    if kind == Kind.SCALAR_TYPE_DEFINITION:
        return "SCALAR"
    if kind == Kind.OBJECT_TYPE_DEFINITION:
        return "OBJECT"
    if kind == Kind.INTERFACE_TYPE_DEFINITION:
        return "INTERFACE"
    if kind == Kind.UNION_TYPE_DEFINITION:
        return "UNION"
    if kind == Kind.ENUM_TYPE_DEFINITION:
        return "ENUM"
    return "INPUT_OBJECT"


def _operation_type(kind: OperationKind) -> OperationType:
    """Return the operation type of an operation kind."""
    if kind == OperationKind.MUTATION:
        return OperationType.MUTATION
    if kind == OperationKind.SUBSCRIPTION:
        return OperationType.SUBSCRIPTION
    return OperationType.QUERY


def _resolve_type(
    store: Store,
    schema: Document,
    index: _Index,
    metadata: SchemaMetadata,
    variables: CoerceVariablesPayload,
    mut out: JsonDocument,
    type_ref: Int,
    item: Int,
) -> Int:
    """Resolve a type reference, as upstream `resolve_type`."""
    var kind = schema.kind(type_ref)
    if kind == Kind.NAMED_TYPE:
        var definition = index.find(schema.name(type_ref))
        if definition == NO_NODE:
            return out.add_null()
        return _resolve_type_definition(
            store, schema, index, metadata, variables, out, definition, item
        )
    var object = out.add_object()
    var wrapper: StaticString = "LIST"
    if kind == Kind.NON_NULL_TYPE:
        wrapper = "NON_NULL"
    var fields = _fields(store, item, True)
    var at = 0
    while at < len(fields):
        var field = fields[at]
        var name = _field_name(store, field)
        var value: Int
        if name == "kind":
            value = out.add_string(wrapper)
        elif name == "ofType":
            value = _resolve_type(
                store,
                schema,
                index,
                metadata,
                variables,
                out,
                schema.first_child(type_ref),
                field,
            )
        elif name == "__typename":
            value = out.add_string("__Type")
        else:
            value = out.add_null()
        _member(out, object, store, field, value)
        at += 1
    return object


def _resolve_input_value(
    store: Store,
    schema: Document,
    index: _Index,
    metadata: SchemaMetadata,
    variables: CoerceVariablesPayload,
    mut out: JsonDocument,
    node: Int,
    item: Int,
) -> Int:
    """Resolve an argument or an input field, as upstream
    `resolve_input_value`."""
    var object = out.add_object()
    var fields = _fields(store, item, True)
    var at = 0
    while at < len(fields):
        var field = fields[at]
        var name = _field_name(store, field)
        var value: Int
        if name == "name":
            value = out.add_string(schema.name(node))
        elif name == "description":
            value = _description(out, schema, node)
        elif name == "type":
            value = _resolve_type(
                store,
                schema,
                index,
                metadata,
                variables,
                out,
                schema.child(node, Role.TYPE),
                field,
            )
        elif name == "defaultValue":
            var default_value = schema.child(node, Role.DEFAULT_VALUE)
            if default_value == NO_NODE:
                value = out.add_null()
            else:
                value = out.add_string(print_node(schema, default_value))
        elif name == "isDeprecated":
            value = out.add_bool(_is_deprecated(schema, node))
        elif name == "deprecationReason":
            value = _deprecation_reason(out, schema, node)
        elif name == "__typename":
            value = out.add_string("__InputValue")
        else:
            value = out.add_null()
        _member(out, object, store, field, value)
        at += 1
    return object


def _resolve_input_values(
    store: Store,
    schema: Document,
    index: _Index,
    metadata: SchemaMetadata,
    variables: CoerceVariablesPayload,
    mut out: JsonDocument,
    node: Int,
    role: Role,
    item: Int,
) -> Int:
    """Resolve every argument or input field of a definition."""
    var array = out.add_array()
    var child = schema.child(node, role)
    while child != NO_NODE:
        out.append(
            array,
            _resolve_input_value(
                store, schema, index, metadata, variables, out, child, item
            ),
        )
        child = schema.next_with_role(child)
    return array


def _resolve_field(
    store: Store,
    schema: Document,
    index: _Index,
    metadata: SchemaMetadata,
    variables: CoerceVariablesPayload,
    mut out: JsonDocument,
    node: Int,
    item: Int,
) -> Int:
    """Resolve a field definition, as upstream `resolve_field`."""
    var object = out.add_object()
    var fields = _fields(store, item, True)
    var at = 0
    while at < len(fields):
        var field = fields[at]
        var name = _field_name(store, field)
        var value: Int
        if name == "name":
            value = out.add_string(schema.name(node))
        elif name == "description":
            value = _description(out, schema, node)
        elif name == "args":
            value = _resolve_input_values(
                store,
                schema,
                index,
                metadata,
                variables,
                out,
                node,
                Role.ARGUMENT,
                field,
            )
        elif name == "type":
            value = _resolve_type(
                store,
                schema,
                index,
                metadata,
                variables,
                out,
                schema.child(node, Role.TYPE),
                field,
            )
        elif name == "isDeprecated":
            value = out.add_bool(_is_deprecated(schema, node))
        elif name == "deprecationReason":
            value = _deprecation_reason(out, schema, node)
        elif name == "__typename":
            value = out.add_string("__Field")
        else:
            value = out.add_null()
        _member(out, object, store, field, value)
        at += 1
    return object


def _resolve_enum_value(
    store: Store, schema: Document, mut out: JsonDocument, node: Int, item: Int
) -> Int:
    """Resolve an enum value, as upstream `resolve_enum_value`."""
    var object = out.add_object()
    var fields = _fields(store, item, True)
    var at = 0
    while at < len(fields):
        var field = fields[at]
        var name = _field_name(store, field)
        var value: Int
        if name == "name":
            value = out.add_string(schema.name(node))
        elif name == "description":
            value = _description(out, schema, node)
        elif name == "isDeprecated":
            value = out.add_bool(_is_deprecated(schema, node))
        elif name == "deprecationReason":
            value = _deprecation_reason(out, schema, node)
        elif name == "__typename":
            value = out.add_string("__EnumValue")
        else:
            value = out.add_null()
        _member(out, object, store, field, value)
        at += 1
    return object


def _resolve_type_fields(
    store: Store,
    schema: Document,
    index: _Index,
    metadata: SchemaMetadata,
    variables: CoerceVariablesPayload,
    mut out: JsonDocument,
    definition: Int,
    item: Int,
) -> Int:
    """Resolve `fields` of an object or interface type."""
    var include_deprecated = _include_deprecated(store, variables, item)
    var array = out.add_array()
    var child = schema.child(definition, Role.FIELD)
    while child != NO_NODE:
        var keep = not schema.name(child).startswith("__")
        if keep and not include_deprecated:
            keep = not _is_deprecated(schema, child)
        if keep:
            out.append(
                array,
                _resolve_field(
                    store, schema, index, metadata, variables, out, child, item
                ),
            )
        child = schema.next_with_role(child)
    return array


def _resolve_enum_values(
    store: Store,
    schema: Document,
    variables: CoerceVariablesPayload,
    mut out: JsonDocument,
    definition: Int,
    item: Int,
) -> Int:
    """Resolve `enumValues` of an enum type."""
    var include_deprecated = _include_deprecated(store, variables, item)
    var array = out.add_array()
    var child = schema.child(definition, Role.ENUM_VALUE)
    while child != NO_NODE:
        if include_deprecated or not _is_deprecated(schema, child):
            out.append(
                array, _resolve_enum_value(store, schema, out, child, item)
            )
        child = schema.next_with_role(child)
    return array


def _resolve_interfaces(
    store: Store,
    schema: Document,
    index: _Index,
    metadata: SchemaMetadata,
    variables: CoerceVariablesPayload,
    mut out: JsonDocument,
    definition: Int,
    item: Int,
) -> Int:
    """Resolve `interfaces` of an object type: each interface that the
    schema defines."""
    var array = out.add_array()
    var child = schema.child(definition, Role.INTERFACE)
    while child != NO_NODE:
        var interface = index.find(schema.name(child))
        if interface != NO_NODE:
            out.append(
                array,
                _resolve_type_definition(
                    store,
                    schema,
                    index,
                    metadata,
                    variables,
                    out,
                    interface,
                    item,
                ),
            )
        child = schema.next_with_role(child)
    return array


def _resolve_possible_types(
    store: Store,
    schema: Document,
    index: _Index,
    metadata: SchemaMetadata,
    variables: CoerceVariablesPayload,
    mut out: JsonDocument,
    definition: Int,
    item: Int,
) -> Int:
    """Resolve `possibleTypes` of an interface or union type, in document
    order, without the type itself."""
    var name = String(schema.name(definition))
    var possible = metadata.possible_types.get_possible_types(name)
    var array = out.add_array()
    var at = 0
    while at < len(index.order):
        var candidate = index.order[at]
        var candidate_name = String(schema.name(candidate))
        if candidate_name != name and candidate_name in possible:
            out.append(
                array,
                _resolve_type_definition(
                    store,
                    schema,
                    index,
                    metadata,
                    variables,
                    out,
                    candidate,
                    item,
                ),
            )
        at += 1
    return array


def _resolve_type_definition(
    store: Store,
    schema: Document,
    index: _Index,
    metadata: SchemaMetadata,
    variables: CoerceVariablesPayload,
    mut out: JsonDocument,
    definition: Int,
    item: Int,
) -> Int:
    """Resolve a type definition, as upstream `resolve_type_definition`."""
    var kind = schema.kind(definition)
    var object = out.add_object()
    var fields = _fields(store, item, True)
    var at = 0
    while at < len(fields):
        var field = fields[at]
        var name = _field_name(store, field)
        var value = NO_NODE
        if name == "kind":
            value = out.add_string(_kind_text(kind))
        elif name == "name":
            value = out.add_string(schema.name(definition))
        elif name == "description":
            value = _description(out, schema, definition)
        elif name == "specifiedByURL":
            if kind == Kind.SCALAR_TYPE_DEFINITION:
                value = _string_or_null(
                    out,
                    schema,
                    _directive_string(schema, definition, "specifiedBy", "url"),
                )
        elif name == "isOneOf":
            if kind == Kind.INPUT_OBJECT_TYPE_DEFINITION:
                value = out.add_bool(
                    _directive(schema, definition, "oneOf") != NO_NODE
                )
        elif name == "fields":
            if (
                kind == Kind.OBJECT_TYPE_DEFINITION
                or kind == Kind.INTERFACE_TYPE_DEFINITION
            ):
                value = _resolve_type_fields(
                    store,
                    schema,
                    index,
                    metadata,
                    variables,
                    out,
                    definition,
                    field,
                )
        elif name == "interfaces":
            if kind == Kind.OBJECT_TYPE_DEFINITION:
                value = _resolve_interfaces(
                    store,
                    schema,
                    index,
                    metadata,
                    variables,
                    out,
                    definition,
                    field,
                )
        elif name == "possibleTypes":
            if (
                kind == Kind.INTERFACE_TYPE_DEFINITION
                or kind == Kind.UNION_TYPE_DEFINITION
            ):
                value = _resolve_possible_types(
                    store,
                    schema,
                    index,
                    metadata,
                    variables,
                    out,
                    definition,
                    field,
                )
        elif name == "enumValues":
            if kind == Kind.ENUM_TYPE_DEFINITION:
                value = _resolve_enum_values(
                    store, schema, variables, out, definition, field
                )
        elif name == "inputFields":
            if kind == Kind.INPUT_OBJECT_TYPE_DEFINITION:
                value = _resolve_input_values(
                    store,
                    schema,
                    index,
                    metadata,
                    variables,
                    out,
                    definition,
                    Role.FIELD,
                    field,
                )
        elif name == "__typename":
            value = out.add_string("__Type")
        if value == NO_NODE:
            # An unknown field, `ofType`, or a field of another kind.
            value = out.add_null()
        _member(out, object, store, field, value)
        at += 1
    return object


def _resolve_directive(
    store: Store,
    schema: Document,
    index: _Index,
    metadata: SchemaMetadata,
    variables: CoerceVariablesPayload,
    mut out: JsonDocument,
    node: Int,
    item: Int,
) -> Int:
    """Resolve a directive definition, as upstream `resolve_directive`."""
    var object = out.add_object()
    var fields = _fields(store, item, True)
    var at = 0
    while at < len(fields):
        var field = fields[at]
        var name = _field_name(store, field)
        var value: Int
        if name == "name":
            value = out.add_string(schema.name(node))
        elif name == "description":
            value = _description(out, schema, node)
        elif name == "locations":
            value = out.add_array()
            var location = schema.child(node, Role.LOCATION)
            while location != NO_NODE:
                out.append(value, out.add_string(schema.text(location)))
                location = schema.next_with_role(location)
        elif name == "args":
            value = _resolve_input_values(
                store,
                schema,
                index,
                metadata,
                variables,
                out,
                node,
                Role.ARGUMENT,
                field,
            )
        elif name == "isRepeatable":
            value = out.add_bool(schema.is_repeatable(node))
        elif name == "__typename":
            value = out.add_string("__Directive")
        else:
            value = out.add_null()
        _member(out, object, store, field, value)
        at += 1
    return object


def _resolve_root_type(
    store: Store,
    schema: Document,
    index: _Index,
    metadata: SchemaMetadata,
    variables: CoerceVariablesPayload,
    mut out: JsonDocument,
    name: StringSlice,
    item: Int,
) -> Int:
    """Resolve a type by name, or `null` when the schema lacks it."""
    var definition = index.find(name)
    if definition == NO_NODE:
        return out.add_null()
    return _resolve_type_definition(
        store, schema, index, metadata, variables, out, definition, item
    )


def _resolve_schema(
    store: Store,
    schema: Document,
    index: _Index,
    metadata: SchemaMetadata,
    variables: CoerceVariablesPayload,
    mut out: JsonDocument,
    item: Int,
) -> Int:
    """Resolve `__schema`, as upstream `resolve_schema_selections`.

    Only the direct fields count; an inline fragment adds nothing, as
    upstream.
    """
    var object = out.add_object()
    var fields = _fields(store, item, False)
    var at = 0
    while at < len(fields):
        var field = fields[at]
        var name = _field_name(store, field)
        var value: Int
        if name == "types":
            value = out.add_array()
            var position = 0
            while position < len(index.order):
                out.append(
                    value,
                    _resolve_type_definition(
                        store,
                        schema,
                        index,
                        metadata,
                        variables,
                        out,
                        index.order[position],
                        field,
                    ),
                )
                position += 1
        elif name == "queryType":
            value = _resolve_root_type(
                store,
                schema,
                index,
                metadata,
                variables,
                out,
                metadata.query_type_name,
                field,
            )
        elif name == "mutationType":
            value = _resolve_root_type(
                store,
                schema,
                index,
                metadata,
                variables,
                out,
                metadata.mutation_type_name,
                field,
            )
        elif name == "subscriptionType":
            value = _resolve_root_type(
                store,
                schema,
                index,
                metadata,
                variables,
                out,
                metadata.subscription_type_name,
                field,
            )
        elif name == "directives":
            value = out.add_array()
            var position = 0
            while position < len(index.directives):
                out.append(
                    value,
                    _resolve_directive(
                        store,
                        schema,
                        index,
                        metadata,
                        variables,
                        out,
                        index.directives[position],
                        field,
                    ),
                )
                position += 1
        elif name == "__typename":
            value = out.add_string("__Schema")
        else:
            # `description` and unknown fields.
            value = out.add_null()
        _member(out, object, store, field, value)
        at += 1
    return object


def _type_name_argument(
    store: Store, variables: CoerceVariablesPayload, item: Int
) -> Optional[String]:
    """Return the `name` argument of `__type`, from a literal or from a
    variable, or None."""
    var value = store.arg_value(store.items[item].args, store.find_sym("name"))
    if value == NONE:
        return None
    var found = store.values[value]
    if found.kind == ValueKind.STRING:
        return String(store.name(found.text))
    if found.kind == ValueKind.VARIABLE:
        var node = variables.variable(store.name(found.text))
        if node == NO_NODE:
            return None
        if variables.document.kind(node) == JsonKind.STRING:
            return variables.document.string_value(node)
    return None


def resolve_introspection(
    store: Store,
    operation: OperationDefinition,
    schema: Document,
    metadata: SchemaMetadata,
    variables: CoerceVariablesPayload,
    mut out: JsonDocument,
) -> Int:
    """Resolve the introspection part of an operation, as upstream
    `resolve_introspection`.

    Args:
        store: The store with the selections of the operation.
        operation: The introspection part of a normalized operation.
        schema: The consumer schema.
        metadata: The metadata of the consumer schema.
        variables: The coerced variables of the request.
        out: The document that gets the result.

    Returns:
        The node of the data object in `out`. Its keys are the response
        keys of the root fields, in selection order.
    """
    var index = _Index(schema)
    var root_type_name = metadata.root_type_name(
        _operation_type(operation.kind)
    )
    var data = out.add_object()
    var fields = _fields(store, operation.selection_set, True)
    var at = 0
    while at < len(fields):
        var field = fields[at]
        var name = _field_name(store, field)
        var value: Int
        if name == "__schema":
            value = _resolve_schema(
                store, schema, index, metadata, variables, out, field
            )
        elif name == "__type":
            var type_name = _type_name_argument(store, variables, field)
            if type_name:
                value = _resolve_root_type(
                    store,
                    schema,
                    index,
                    metadata,
                    variables,
                    out,
                    type_name.value(),
                    field,
                )
            else:
                value = out.add_null()
        elif name == "__typename":
            value = out.add_string(root_type_name)
        else:
            value = out.add_null()
        _member(out, data, store, field, value)
        at += 1
    return data

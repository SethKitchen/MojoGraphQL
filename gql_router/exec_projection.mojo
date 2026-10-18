# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Write the client response from the merged data and a projection plan.

Port of `project_by_operation` and `Projector` of Hive Router `1a29df9`
`bin/router/src/executor/projection/response.rs`.

The projector walks the plan in query order. It writes each field that its
conditions allow, under its response key. A `null` in a non-null position
makes the parent `null`; at the root, `data` becomes `null`. An enum value
that the schema does not know becomes `null` with the error `Value is not a
valid enum value`. `__typename` is the type of its parent.

**Differences from upstream.** Upstream caches the position of each field
across the objects of a list; this port uses the same cursor search
without that cache. `extensions` are not written. Numbers and strings keep
their source text, see `gql_router.exec_value`. A missing type or field in
the schema raises `Error` with the upstream `ProjectionError` text.
"""

from gql_json.value import NO_NODE, JsonDocument, JsonKind
from gql_router.exec_projection_plan import (
    ALWAYS,
    NO_SET,
    CondKind,
    ProjectionPlan,
)
from gql_router.exec_value import (
    object_get_from,
    string_text,
    typename_node,
    write_value,
)
from gql_router.exec_variables import CoerceVariablesPayload
from gql_router.graphql_error import GraphQLError, error_json, graphql_error
from gql_router.schema_metadata import SHAPE_LIST, SHAPE_NON_NULL, SchemaMetadata


@fieldwise_init
struct Outcome(Equatable, ImplicitlyCopyable, Movable):
    """The result of a condition, as upstream `ConditionFailure`."""

    var value: UInt8
    """The outcome's index; see `is_valid`."""

    comptime OK = Outcome(0)
    """The condition holds."""
    comptime SKIP = Outcome(1)
    """A variable check fails: leave the field out."""
    comptime INVALID_PARENT_TYPE = Outcome(2)
    """The parent is of another type: leave the field out."""
    comptime INVALID_FIELD_TYPE = Outcome(3)
    """The value is of another type: write `null`."""
    comptime INVALID_ENUM_VALUE = Outcome(4)
    """The enum value is unknown: write `null` and an error."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the five outcomes.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 4


@fieldwise_init
struct _TypeCell(Copyable, Movable):
    """A type name that is known or resolved when needed, as upstream
    `TypeName`."""

    var resolved: Bool
    """Whether `name` holds the type."""
    var name: String
    """The type name, once resolved."""
    var field: Int
    """The plan field whose value the object is."""
    var data: Int
    """The object."""
    var parent: Int
    """The cell of the parent object."""


struct _Projector(Movable):
    """The output of one projection."""

    var buffer: List[UInt8]
    """The response bytes."""
    var errors: List[GraphQLError]
    """The errors of the response."""
    var cells: List[_TypeCell]
    """The type names of the objects on the walk, as a stack."""

    def __init__(out self, var errors: List[GraphQLError], capacity: Int):
        """Start a projection.

        Args:
            errors: The errors so far.
            capacity: The expected size of the response.
        """
        self.buffer = List[UInt8](capacity=capacity)
        self.errors = errors^
        self.cells = List[_TypeCell]()

    def take_buffer(deinit self) -> List[UInt8]:
        """Return the response bytes.

        Returns:
            The bytes written so far.
        """
        return self.buffer^


@always_inline
def _put(mut buffer: List[UInt8], text: StringSlice):
    """Append text to a buffer."""
    buffer.extend(text.as_bytes())


def project_by_operation(
    document: JsonDocument,
    data: Int,
    var errors: List[GraphQLError],
    operation_type_name: String,
    plan: ProjectionPlan,
    variables: CoerceVariablesPayload,
    response_size_estimate: Int,
    schema: SchemaMetadata,
) raises -> List[UInt8]:
    """Write the client response, as upstream `project_by_operation`.

    Args:
        document: The response data arena.
        data: The data object, or `NO_NODE` for `null`.
        errors: The errors of the response.
        operation_type_name: The root type of the operation.
        plan: The projection plan.
        variables: The coerced variables.
        response_size_estimate: The expected size, to reserve space.
        schema: The metadata of the consumer schema.

    Returns:
        The response: `{"data":...}` and `errors` when there are some.

    Raises:
        Error: When the schema lacks a type or a field that the plan needs.
    """
    var out = _Projector(errors^, response_size_estimate + 64)
    _put(out.buffer, '{"data":')
    if data != NO_NODE and document.kind(data) == JsonKind.OBJECT:
        var checkpoint = len(out.buffer)
        out.cells.append(_TypeCell(True, operation_type_name, -1, data, -1))
        var first = True
        var propagate = _project_object_fields(
            out, document, plan, schema, variables, data, plan.roots, 0, first
        )
        if propagate:
            out.buffer.resize(checkpoint, 0)
            _put(out.buffer, "null")
        elif not first:
            out.buffer.append(UInt8(ord("}")))
        else:
            _put(out.buffer, "{}")
    else:
        _put(out.buffer, "null")
    if len(out.errors) > 0:
        _put(out.buffer, ',"errors":[')
        var index = 0
        while index < len(out.errors):
            if index > 0:
                out.buffer.append(UInt8(ord(",")))
            _put(out.buffer, error_json(out.errors[index]))
            index += 1
        out.buffer.append(UInt8(ord("]")))
    out.buffer.append(UInt8(ord("}")))
    return out^.take_buffer()


def _type_name(
    mut out: _Projector,
    document: JsonDocument,
    plan: ProjectionPlan,
    schema: SchemaMetadata,
    cell: Int,
) raises -> String:
    """Return the type of the object of a cell, resolved once."""
    if out.cells[cell].resolved:
        return out.cells[cell].name
    var name = _resolve_type_name(
        out,
        document,
        plan,
        schema,
        out.cells[cell].field,
        out.cells[cell].data,
        out.cells[cell].parent,
    )
    out.cells[cell].name = name
    out.cells[cell].resolved = True
    return name^


def _resolve_type_name(
    mut out: _Projector,
    document: JsonDocument,
    plan: ProjectionPlan,
    schema: SchemaMetadata,
    field: Int,
    value: Int,
    parent: Int,
) raises -> String:
    """Return the type of a field value, as upstream `resolve_type_name`."""
    ref record = plan.fields[field]
    if record.is_typename:
        return String("String")
    if value != NO_NODE:
        var found = typename_node(document, value)
        if found != NO_NODE:
            return string_text(document, found)
    var parent_name = _type_name(out, document, plan, schema, parent)
    var fields = schema.type_fields.get(parent_name)
    if not fields:
        raise Error("Type '" + parent_name + "' not found in schema")
    var info = fields.value().get(record.field_name)
    if not info:
        raise Error(
            "Field '"
            + record.field_name
            + "' not found on type '"
            + parent_name
            + "' in schema"
        )
    return info.value().output_type_name


def _evaluate(
    mut out: _Projector,
    document: JsonDocument,
    plan: ProjectionPlan,
    schema: SchemaMetadata,
    variables: CoerceVariablesPayload,
    cond: Int,
    field: Int,
    value: Int,
    parent: Int,
) raises -> Outcome:
    """Check a condition, as upstream `evaluate`."""
    ref node = plan.tables.conds[cond]
    var kind = node.kind
    if kind == CondKind.INCLUDE_IF:
        if variables.bool_value(node.variable) == 1:
            return Outcome.OK
        return Outcome.SKIP
    if kind == CondKind.SKIP_IF:
        if variables.bool_value(node.variable) == 1:
            return Outcome.SKIP
        return Outcome.OK
    if kind == CondKind.PARENT_TYPE:
        var parent_name = _type_name(out, document, plan, schema, parent)
        if plan.tables.matches(node.set, parent_name):
            return Outcome.OK
        return Outcome.INVALID_PARENT_TYPE
    if kind == CondKind.FIELD_TYPE:
        var field_type = _resolve_type_name(
            out, document, plan, schema, field, value, parent
        )
        if plan.tables.matches(node.set, field_type):
            return Outcome.OK
        return Outcome.INVALID_FIELD_TYPE
    if kind == CondKind.ENUM_VALUES:
        if value == NO_NODE or document.kind(value) != JsonKind.STRING:
            return Outcome.OK
        if plan.tables.matches(node.set, string_text(document, value)):
            return Outcome.OK
        return Outcome.INVALID_ENUM_VALUE
    var left = _evaluate(
        out, document, plan, schema, variables, node.left, field, value, parent
    )
    if kind == CondKind.AND and left != Outcome.OK:
        return left
    if kind == CondKind.OR and left == Outcome.OK:
        return left
    return _evaluate(
        out, document, plan, schema, variables, node.right, field, value, parent
    )


def _write_key(mut buffer: List[UInt8], mut first: Bool, key: String):
    """Open the object or write a comma, then the key, as upstream
    `write_key`."""
    if first:
        buffer.append(UInt8(ord("{")))
    else:
        buffer.append(UInt8(ord(",")))
    first = False
    buffer.append(UInt8(ord('"')))
    _put(buffer, key)
    buffer.append(UInt8(ord('"')))
    buffer.append(UInt8(ord(":")))


def _project_object_fields(
    mut out: _Projector,
    document: JsonDocument,
    plan: ProjectionPlan,
    schema: SchemaMetadata,
    variables: CoerceVariablesPayload,
    object: Int,
    fields: List[Int],
    parent: Int,
    mut first: Bool,
) raises -> Bool:
    """Write the fields of an object, as upstream `project_object_fields`.

    Returns True when a `null` must bubble to the parent.
    """
    var cursor = document.first(object)
    for index in fields:
        ref field = plan.fields[index]
        if field.parent_scope != NO_SET:
            var parent_name = _type_name(out, document, plan, schema, parent)
            if not plan.tables.matches(field.parent_scope, parent_name):
                continue
        var value = object_get_from(document, object, field.response_key, cursor)
        var outcome = Outcome.OK
        if field.condition != ALWAYS:
            outcome = _evaluate(
                out,
                document,
                plan,
                schema,
                variables,
                field.condition,
                index,
                value,
                parent,
            )
        if outcome == Outcome.SKIP or outcome == Outcome.INVALID_PARENT_TYPE:
            continue
        _write_key(out.buffer, first, field.response_key)
        if outcome != Outcome.OK:
            _put(out.buffer, "null")
            if outcome == Outcome.INVALID_ENUM_VALUE:
                out.errors.append(graphql_error("Value is not a valid enum value"))
            if field.is_non_null():
                return True
            continue
        var propagate: Bool
        if field.is_typename:
            var parent_name = _type_name(out, document, plan, schema, parent)
            out.buffer.append(UInt8(ord('"')))
            _put(out.buffer, parent_name)
            out.buffer.append(UInt8(ord('"')))
            propagate = False
        elif value == NO_NODE:
            _put(out.buffer, "null")
            propagate = True
        else:
            var shape = -1
            if document.kind(value) == JsonKind.ARRAY:
                shape = 0
            propagate = _project_value(
                out, document, plan, schema, variables, value, index, parent, shape
            )
        if propagate and field.is_non_null():
            return True
    return False


def _project_value(
    mut out: _Projector,
    document: JsonDocument,
    plan: ProjectionPlan,
    schema: SchemaMetadata,
    variables: CoerceVariablesPayload,
    data: Int,
    field: Int,
    parent: Int,
    shape: Int,
) raises -> Bool:
    """Write one value of a field, as upstream `project_value`.

    `shape` is the level of the field type the value is at, or -1 when it
    is unknown. Returns True when the value is `null`.
    """
    var kind = document.kind(data)
    if kind == JsonKind.ARRAY:
        ref levels = plan.fields[field].nullability.shape
        var item_shape = shape
        var item_non_null = False
        if shape >= 0 and levels[shape] & SHAPE_LIST != 0:
            item_shape = shape + 1
            item_non_null = levels[item_shape] & SHAPE_NON_NULL != 0
        var checkpoint = len(out.buffer)
        out.buffer.append(UInt8(ord("[")))
        var item = document.first(data)
        var first = True
        while item != NO_NODE:
            if not first:
                out.buffer.append(UInt8(ord(",")))
            first = False
            var propagate = _project_value(
                out, document, plan, schema, variables, item, field, parent, item_shape
            )
            if propagate and item_non_null:
                out.buffer.resize(checkpoint, 0)
                _put(out.buffer, "null")
                return True
            item = document.next(item)
        out.buffer.append(UInt8(ord("]")))
        return False
    if kind == JsonKind.OBJECT and plan.fields[field].has_children:
        var checkpoint = len(out.buffer)
        out.cells.append(_TypeCell(False, String(), field, data, parent))
        var cell = len(out.cells) - 1
        var first = True
        var propagate = _project_object_fields(
            out,
            document,
            plan,
            schema,
            variables,
            data,
            plan.fields[field].children,
            cell,
            first,
        )
        _ = out.cells.pop()
        if propagate:
            out.buffer.resize(checkpoint, 0)
            _put(out.buffer, "null")
            return True
        if not first:
            out.buffer.append(UInt8(ord("}")))
        else:
            _put(out.buffer, "{}")
        return False
    if kind == JsonKind.NULL:
        _put(out.buffer, "null")
        return True
    write_value(document, data, out.buffer)
    return False

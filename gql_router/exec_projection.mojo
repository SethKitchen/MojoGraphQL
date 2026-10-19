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

The walk is one struct, `_Projector`, that holds a pointer to each input.
The recursive steps are its methods, so each call passes one pointer and
not the fields of every input. The output buffer is reserved once, from the
size of the subgraph responses.

**Differences from upstream.** `extensions` are not written. Numbers and
strings keep their source text, see `gql_router.exec_value`. A missing type
or field in the schema raises `Error` with the upstream `ProjectionError`
text.
"""

from std.memory import unsafe_memcpy

from gql_json.value import (
    FLAG_DECODED,
    FLAG_KEY_ESCAPED,
    NO_NODE,
    JsonDocument,
    JsonKind,
)
from gql_router.exec_projection_plan import (
    ALWAYS,
    NO_SET,
    CondKind,
    ProjectionPlan,
)
from gql_router.exec_value import (
    bytes_equal,
    append_text,
    key_is,
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


comptime _NON_NULL: UInt8 = 1
"""The field bit of a non-null field: a `null` bubbles to the parent."""
comptime _TYPENAME: UInt8 = 2
"""The field bit of `__typename`."""
comptime _CHILDREN: UInt8 = 4
"""The field bit of a field with child fields."""
comptime _CHECKED: UInt8 = 8
"""The field bit of a field with a parent scope or a condition."""


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
    var state = _Output(
        plan,
        errors^,
        response_size_estimate + response_size_estimate // 4 + 64,
    )
    var out = _Projector(
        document,
        plan,
        schema,
        variables,
        Pointer(to=state).unsafe_origin_cast[MutUntrackedOrigin](),
    )
    out.put('{"data":')
    if data != NO_NODE and document.kind(data) == JsonKind.OBJECT:
        var checkpoint = len(state.buffer)
        state.cells.append(_TypeCell(True, operation_type_name, -1, data, -1))
        var first = True
        var propagate = out.object_fields(data, plan.roots, 0, first)
        if propagate:
            state.buffer.resize(checkpoint, 0)
            out.put("null")
        elif not first:
            out.byte(UInt8(ord("}")))
        else:
            out.put("{}")
    else:
        out.put("null")
    if len(state.errors) > 0:
        out.put(',"errors":[')
        var index = 0
        while index < len(state.errors):
            if index > 0:
                out.byte(UInt8(ord(",")))
            out.put(error_json(state.errors[index]))
            index += 1
        out.byte(UInt8(ord("]")))
    out.byte(UInt8(ord("}")))
    if state.failure.byte_length() > 0:
        raise Error(state.failure)
    return state^.take_buffer()


struct _Output(Movable):
    """The output of one projection and the stacks of its walk."""

    var buffer: List[UInt8]
    """The response bytes."""
    var errors: List[GraphQLError]
    """The errors of the response."""
    var cells: List[_TypeCell]
    """The type names of the objects on the walk, as a stack."""
    var members: List[Int]
    """The members of the objects on the walk, as a stack."""
    var hints: List[Int]
    """The rank where each plan field was last found in its object, or -1,
    as upstream `indexes` but kept for the whole walk."""
    var failure: String
    """The first failure, or empty; the projection raises it at the end."""
    var keys: List[UInt8]
    """For each plan field, `"key":`, one after the other."""
    var key_starts: List[Int]
    """Where the `"key":` of each plan field starts in `keys`."""
    var bits: List[UInt8]
    """The `_NON_NULL`, `_TYPENAME`, `_CHILDREN` and `_CHECKED` bits of
    each plan field."""

    def __init__(
        out self,
        plan: ProjectionPlan,
        var errors: List[GraphQLError],
        capacity: Int,
    ):
        """Start an empty output, with the field table of a plan.

        Args:
            plan: The projection plan.
            errors: The errors so far.
            capacity: The expected size of the response.
        """
        self.buffer = List[UInt8](capacity=capacity)
        self.errors = errors^
        self.cells = List[_TypeCell](capacity=32)
        self.members = List[Int](capacity=256)
        self.hints = List[Int](length=len(plan.fields), fill=-1)
        self.failure = String()
        var count = len(plan.fields)
        self.keys = List[UInt8](capacity=count * 12)
        self.key_starts = List[Int](capacity=count + 1)
        self.bits = List[UInt8](capacity=count)
        for ref field in plan.fields:
            self.key_starts.append(len(self.keys))
            self.keys.append(UInt8(ord('"')))
            append_text(self.keys, field.response_key)
            self.keys.append(UInt8(ord('"')))
            self.keys.append(UInt8(ord(":")))
            var bits: UInt8 = 0
            if field.is_non_null():
                bits |= _NON_NULL
            if field.is_typename:
                bits |= _TYPENAME
            if field.has_children:
                bits |= _CHILDREN
            if field.parent_scope != NO_SET or field.condition != ALWAYS:
                bits |= _CHECKED
            self.bits.append(bits)
        self.key_starts.append(len(self.keys))
        # Padding, so that a key copy can load 16 bytes at once.
        self.keys.resize(len(self.keys) + 16, 0)

    def take_buffer(deinit self) -> List[UInt8]:
        """Return the response bytes.

        Returns:
            The bytes written so far.
        """
        return self.buffer^


@fieldwise_init
struct _Projector[
    d: Origin[mut=False],
    p: Origin[mut=False],
    s: Origin[mut=False],
    v: Origin[mut=False],
](ImplicitlyCopyable):
    """The inputs of one projection and a pointer to its output.

    The walk methods take this handle, which is five pointers, and not the
    output itself. A recursive method whose `self` is a large struct gets
    the struct's fields as arguments on every call.
    """

    var document: Pointer[JsonDocument, Self.d]
    """The response data arena."""
    var plan: Pointer[ProjectionPlan, Self.p]
    """The projection plan."""
    var schema: Pointer[SchemaMetadata, Self.s]
    """The metadata of the consumer schema."""
    var variables: Pointer[CoerceVariablesPayload, Self.v]
    """The coerced variables."""
    var out: Pointer[_Output, MutUntrackedOrigin]
    """The output."""

    def __init__(
        out self,
        ref[Self.d] document: JsonDocument,
        ref[Self.p] plan: ProjectionPlan,
        ref[Self.s] schema: SchemaMetadata,
        ref[Self.v] variables: CoerceVariablesPayload,
        out_state: Pointer[_Output, MutUntrackedOrigin],
    ):
        """Start a projection.

        Args:
            document: The response data arena.
            plan: The projection plan.
            schema: The metadata of the consumer schema.
            variables: The coerced variables.
            out_state: The output.
        """
        self.document = Pointer(to=document)
        self.plan = Pointer(to=plan)
        self.schema = Pointer(to=schema)
        self.variables = Pointer(to=variables)
        self.out = out_state

    @always_inline
    def put(self, text: StringSlice):
        """Append text to the response.

        Args:
            text: The text.
        """
        append_text(self.out[].buffer, text)

    @always_inline
    def byte(self, value: UInt8):
        """Append one byte to the response.

        Args:
            value: The byte.
        """
        self.out[].buffer.append(value)

    def fail(self, message: String):
        """Record the first projection failure.

        Args:
            message: The upstream `ProjectionError` text.
        """
        if self.out[].failure.byte_length() == 0:
            self.out[].failure = message

    @always_inline
    def write_key(self, mut first: Bool, field: Int):
        """Open the object or write a comma, then the key, as upstream
        `write_key`.

        Args:
            first: Whether the object is still empty; set to False.
            field: The plan field.
        """
        ref out = self.out[]
        var start = out.key_starts.unsafe_get(field)
        var length = out.key_starts.unsafe_get(field + 1) - start
        var size = len(out.buffer)
        if size + length + 17 > out.buffer.capacity():
            out.buffer.reserve(max(out.buffer.capacity() * 2, size + length + 17))
        var target = out.buffer.unsafe_ptr().unsafe_offset(size)
        target[] = UInt8(ord("{")) if first else UInt8(ord(","))
        first = False
        var source = out.keys.unsafe_ptr().unsafe_offset(start)
        if length > 16:
            unsafe_memcpy(dest=target.unsafe_offset(1), src=source, count=length)
        else:
            # `keys` is padded and the buffer has room: copy 16 bytes.
            target.unsafe_offset(1).unsafe_store(
                source.unsafe_load[width=16]()
            )
        out.buffer._len = size + length + 1

    @always_inline
    def key_matches(self, member: Int, field: Int) -> Bool:
        """Return True if a member has the response key of a plan field.

        Args:
            member: The member node.
            field: The plan field.

        Returns:
            Whether the decoded key equals the response key.
        """
        ref out = self.out[]
        var start = out.key_starts.unsafe_get(field) + 1
        var length = out.key_starts.unsafe_get(field + 1) - start - 2
        var node = self.document[].nodes.unsafe_ptr().unsafe_offset(member)
        if node[].flags & FLAG_KEY_ESCAPED != 0:
            return key_is(
                self.document[], member, self.plan[].fields[field].response_key
            )
        var key_start = Int(node[].key_start)
        if Int(node[].key_end) - key_start != length:
            return False
        return bytes_equal(
            self.document[].bytes.unsafe_ptr().unsafe_offset(key_start),
            out.keys.unsafe_ptr().unsafe_offset(start),
            length,
        )

    @always_inline
    def write_scalar(self, data: Int, kind: JsonKind):
        """Write a value that the walk does not enter.

        A number, or a string whose source text is kept, is copied as it
        is, with one reserve. Any other value goes to `write_value`.

        Args:
            data: The value.
            kind: Its kind.
        """
        var node = self.document[].nodes.unsafe_ptr()[unsafe_offset=data]
        var string = kind == JsonKind.STRING and node.flags & FLAG_DECODED == 0
        if not string and kind != JsonKind.NUMBER:
            write_value(self.document[], data, self.out[].buffer)
            return
        var start = Int(node.start)
        var length = Int(node.end) - start
        ref buffer = self.out[].buffer
        var size = len(buffer)
        var needed = size + length + 18
        if needed > buffer.capacity():
            buffer.reserve(max(buffer.capacity() * 2, needed))
        var target = buffer.unsafe_ptr().unsafe_offset(size)
        var source = self.document[].bytes.unsafe_ptr().unsafe_offset(start)
        if string:
            target[] = UInt8(ord('"'))
            target = target.unsafe_offset(1)
        if length > 16:
            unsafe_memcpy(dest=target, src=source, count=length)
        elif start + 16 <= len(self.document[].bytes):
            # 16 readable bytes at `source` and room at `target`.
            target.unsafe_store(source.unsafe_load[width=16]())
        else:
            var index = 0
            while index < length:
                target[unsafe_offset=index] = source[unsafe_offset=index]
                index += 1
        if string:
            target[unsafe_offset=length] = UInt8(ord('"'))
            size += 2
        buffer._len = size + length

    def type_name(self, cell: Int) -> String:
        """Return the type of the object of a cell, resolved once.

        Args:
            cell: The cell.

        Returns:
            The type name.
        """
        if self.out[].cells[cell].resolved:
            return self.out[].cells[cell].name
        var name = self.resolve_type_name(
            self.out[].cells[cell].field, self.out[].cells[cell].data, self.out[].cells[cell].parent
        )
        self.out[].cells[cell].name = name
        self.out[].cells[cell].resolved = True
        return name^

    def resolve_type_name(self, field: Int, value: Int, parent: Int) -> String:
        """Return the type of a field value, as upstream `resolve_type_name`.

        Args:
            field: The plan field.
            value: The value, or `NO_NODE`.
            parent: The cell of the parent object.

        Returns:
            The type name, or empty after a failure.
        """
        # The field is an object field or a field of an abstract type, so
        # it is never `__typename`.
        ref record = self.plan[].fields[field]
        if value != NO_NODE:
            var found = typename_node(self.document[], value)
            if found != NO_NODE:
                return string_text(self.document[], found)
        var parent_name = self.type_name(parent)
        if not self.schema[].has_type_fields(parent_name):
            self.fail("Type '" + parent_name + "' not found in schema")
            return String()
        var output = self.schema[].field_type(parent_name, record.field_name)
        if output.byte_length() == 0:
            self.fail(
                "Field '"
                + record.field_name
                + "' not found on type '"
                + parent_name
                + "' in schema"
            )
        return output^

    def evaluate(
        self, cond: Int, field: Int, value: Int, parent: Int
    ) -> Outcome:
        """Check a condition, as upstream `evaluate`.

        Args:
            cond: The condition.
            field: The plan field.
            value: The value of the field, or `NO_NODE`.
            parent: The cell of the parent object.

        Returns:
            The outcome.
        """
        ref node = self.plan[].tables.conds[cond]
        var kind = node.kind
        if kind == CondKind.INCLUDE_IF:
            if self.variables[].bool_value(node.variable) == 1:
                return Outcome.OK
            return Outcome.SKIP
        if kind == CondKind.SKIP_IF:
            if self.variables[].bool_value(node.variable) == 1:
                return Outcome.SKIP
            return Outcome.OK
        if kind == CondKind.PARENT_TYPE:
            var parent_name = self.type_name(parent)
            if self.plan[].tables.matches(node.set, parent_name):
                return Outcome.OK
            return Outcome.INVALID_PARENT_TYPE
        if kind == CondKind.FIELD_TYPE:
            var field_type = self.resolve_type_name(field, value, parent)
            if self.plan[].tables.matches(node.set, field_type):
                return Outcome.OK
            return Outcome.INVALID_FIELD_TYPE
        if kind == CondKind.ENUM_VALUES:
            if value == NO_NODE or self.document[].kind(value) != JsonKind.STRING:
                return Outcome.OK
            if self.plan[].tables.matches(
                node.set, string_text(self.document[], value)
            ):
                return Outcome.OK
            return Outcome.INVALID_ENUM_VALUE
        var left = self.evaluate(node.left, field, value, parent)
        if kind == CondKind.AND and left != Outcome.OK:
            return left
        if kind == CondKind.OR and left == Outcome.OK:
            return left
        return self.evaluate(node.right, field, value, parent)

    def object_fields(
        self,
        object: Int,
        fields: List[Int],
        parent: Int,
        mut first: Bool,
    ) -> Bool:
        """Write the fields of an object, as upstream `project_object_fields`.

        The members of the object go on the member stack once.

        Args:
            object: The object.
            fields: The plan fields to write.
            parent: The cell of the object.
            first: Whether the object is still empty.

        Returns:
            True when a `null` must bubble to the parent.
        """
        var base = len(self.out[].members)
        var count = self.document[].length(object)
        if base + count > self.out[].members.capacity():
            self.out[].members.reserve(max(self.out[].members.capacity() * 2, base + count))
        var slots = self.out[].members.unsafe_ptr()
        var member = self.document[].first(object)
        var rank = 0
        while member != NO_NODE:
            slots[unsafe_offset = base + rank] = member
            rank += 1
            member = self.document[].next(member)
        self.out[].members._len = base + rank
        var propagate = self.project_members(base, fields, parent, first)
        self.out[].members._len = base
        return propagate

    def find_member(self, base: Int, field: Int, mut cursor: Int) -> Int:
        """Find a member of the object on top of the member stack, as
        upstream `find_field`: the hint first, then from the cursor, then
        from the start.

        Args:
            base: Where the members of the object start on the stack.
            field: The plan field whose response key to find.
            cursor: The rank after the last member found; updated.

        Returns:
            The member node, or `NO_NODE`.
        """
        var count = len(self.out[].members) - base
        var slots = self.out[].members.unsafe_ptr().unsafe_offset(base)
        var hint = self.out[].hints.unsafe_get(field)
        if (
            hint >= 0
            and hint < count
            and self.key_matches(slots[unsafe_offset=hint], field)
        ):
            cursor = hint + 1
            return slots[unsafe_offset=hint]
        var start = min(cursor, count)
        var found = -1
        var rank = start
        while rank < count:
            if self.key_matches(slots[unsafe_offset=rank], field):
                found = rank
                break
            rank += 1
        if found < 0:
            rank = 0
            while rank < start:
                if self.key_matches(slots[unsafe_offset=rank], field):
                    found = rank
                    break
                rank += 1
        if found < 0:
            return NO_NODE
        self.out[].hints.unsafe_set(field, found)
        cursor = found + 1
        return slots[unsafe_offset=found]

    def project_members(
        self,
        base: Int,
        fields: List[Int],
        parent: Int,
        mut first: Bool,
    ) -> Bool:
        """Write the fields of the object on top of the member stack.

        Args:
            base: Where the members of the object start on the stack.
            fields: The plan fields to write.
            parent: The cell of the object.
            first: Whether the object is still empty.

        Returns:
            True when a `null` must bubble to the parent.
        """
        var cursor = 0
        var bits_table = self.out[].bits.unsafe_ptr()
        for index in fields:
            var bits = bits_table[unsafe_offset=index]
            var outcome = Outcome.OK
            var value: Int
            if bits & _CHECKED == 0:
                value = self.find_member(base, index, cursor)
            else:
                ref field = self.plan[].fields[index]
                if field.parent_scope != NO_SET:
                    var parent_name = self.type_name(parent)
                    if not self.plan[].tables.matches(
                        field.parent_scope, parent_name
                    ):
                        continue
                value = self.find_member(base, index, cursor)
                if field.condition != ALWAYS:
                    outcome = self.evaluate(
                        field.condition, index, value, parent
                    )
                if (
                    outcome == Outcome.SKIP
                    or outcome == Outcome.INVALID_PARENT_TYPE
                ):
                    continue
            self.write_key(first, index)
            if outcome != Outcome.OK:
                self.put("null")
                if outcome == Outcome.INVALID_ENUM_VALUE:
                    self.out[].errors.append(
                        graphql_error("Value is not a valid enum value")
                    )
                if bits & _NON_NULL != 0:
                    return True
                continue
            var propagate: Bool
            if bits & _TYPENAME != 0:
                var parent_name = self.type_name(parent)
                self.byte(UInt8(ord('"')))
                self.put(parent_name)
                self.byte(UInt8(ord('"')))
                propagate = False
            elif value == NO_NODE:
                self.put("null")
                propagate = True
            else:
                var kind = self.document[].kind(value)
                if kind == JsonKind.STRING or kind == JsonKind.NUMBER:
                    self.write_scalar(value, kind)
                    propagate = False
                else:
                    var shape = -1
                    if kind == JsonKind.ARRAY:
                        shape = 0
                    propagate = self.project_value(
                        value, index, parent, shape
                    )
            if propagate and bits & _NON_NULL != 0:
                return True
        return False

    def project_value(
        self, data: Int, field: Int, parent: Int, shape: Int
    ) -> Bool:
        """Write one value of a field, as upstream `project_value`.

        Args:
            data: The value.
            field: The plan field.
            parent: The cell of the parent object.
            shape: The level of the field type the value is at, or -1 when
                it is unknown.

        Returns:
            True when the value is `null`.
        """
        var kind = self.document[].kind(data)
        ref record = self.plan[].fields[field]
        if kind == JsonKind.ARRAY:
            ref levels = record.nullability.shape
            var item_shape = shape
            var item_non_null = False
            # An array is projected at a level of its field type: shape >= 0.
            if levels[shape] & SHAPE_LIST != 0:
                item_shape = shape + 1
                item_non_null = levels[item_shape] & SHAPE_NON_NULL != 0
            var checkpoint = len(self.out[].buffer)
            self.byte(UInt8(ord("[")))
            var item = self.document[].first(data)
            var first = True
            var propagate = False
            while item != NO_NODE:
                if not first:
                    self.byte(UInt8(ord(",")))
                first = False
                var item_null = self.project_value(
                    item, field, parent, item_shape
                )
                if item_null and item_non_null:
                    propagate = True
                    break
                item = self.document[].next(item)
            if propagate:
                self.out[].buffer.resize(checkpoint, 0)
                self.put("null")
                return True
            self.byte(UInt8(ord("]")))
            return False
        if kind == JsonKind.OBJECT and record.has_children:
            var checkpoint = len(self.out[].buffer)
            self.out[].cells.append(_TypeCell(False, String(), field, data, parent))
            var cell = len(self.out[].cells) - 1
            var first = True
            var propagate = self.object_fields(
                data, record.children, cell, first
            )
            _ = self.out[].cells.pop()
            if propagate:
                self.out[].buffer.resize(checkpoint, 0)
                self.put("null")
                return True
            if not first:
                self.byte(UInt8(ord("}")))
            else:
                self.put("{}")
            return False
        if kind == JsonKind.NULL:
            self.put("null")
            return True
        self.write_scalar(data, kind)
        return False

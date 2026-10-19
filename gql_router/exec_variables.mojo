# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The runtime coercion of the variable values of a request, and the
coerced values.

Port of `CoerceVariablesPayload` of Hive Router `1a29df9`
`bin/router/src/executor/execution/plan.rs`, and of
`bin/router/src/executor/variables/mod.rs`: `VariableCoercionError`,
`InvalidValueReason`, `PathSegment`, `ValuePath`, `InvalidValue`,
`collect_variables` and `validate_runtime_value` (spec "Coercing Variable
Values"). The messages follow graphql-js.

The values live in one `JsonDocument`. `variable(name)` returns the node of
a value, or `NO_NODE`. `is_some` is False when the request has no variable
map, as upstream `variables_map` is `None`.

`collect_variables` takes the parsed `variables` document of the request.
A value that passes is kept as its node, so its source text is what goes
to the subgraphs. A default value becomes new nodes of the same document.

**Differences from upstream.**

- Upstream keeps a `HashMap`. This port keeps the names in insertion
  order, so the order of the variables that a fetch sends is the order of
  its variable usages.
- A type is a name and a shape with `%` for the name, as
  `gql_router.federation_spec.TypeNode`, not a recursive `TypeNode`.
- `validate_runtime_value` is public, and it raises `InvalidValue` where
  upstream returns `Result<(), InvalidValue>`.
- Upstream reads the numbers with `sonic_rs`. This port reads the number
  text: a number is an integer when its text has no fraction and no
  exponent and it fits in `i64` or `u64`, and `-0` is a float, as
  `sonic_rs` reads them.
- The `gql_json` parser accepts a number that is too large for an `f64`,
  such as `1e309`, as `JSON.parse` does. `sonic_rs` refuses it. So `Float`
  refuses a number that is not finite, as graphql-js `GraphQLFloat` does,
  with the reason `Float cannot represent non numeric value: Infinity`.
  An error message prints such a number as `Infinity` or `-Infinity`, as
  graphql-js `inspect` does.
- A message prints a float of value zero as `0.0`.
- A `Float` default value is written as Rust `f64` `Display` with `.0`
  when it has no fraction, such as `1000.0`, where `sonic_rs` can write an
  exponent. The value is the same.
"""

from std.math import floor

from gql_json.value import NO_NODE, JsonDocument, JsonKind
from gql_json.writer import write_string
from gql_router.ast import NONE, ValueKind, _rust_float_text
from gql_router.operation import OperationDefinition
from gql_router.schema_metadata import InputObjectInfo, SchemaMetadata
from gql_router.store import Store


struct CoerceVariablesPayload(Copyable, Movable):
    """The coerced variables, as upstream `CoerceVariablesPayload`."""

    var document: JsonDocument
    """The document that holds every value."""
    var names: List[String]
    """The variable names, in insertion order."""
    var values: List[Int]
    """The node of each value in `document`, parallel to `names`."""
    var is_some: Bool
    """False when there is no variable map, as upstream `None`."""

    def __init__(out self):
        """Start with no variable map."""
        self.document = JsonDocument()
        self.names = List[String]()
        self.values = List[Int]()
        self.is_some = False

    def insert(mut self, name: String, node: Int):
        """Add a variable, or replace its value.

        Args:
            name: The variable name.
            node: The node of the value in `document`.
        """
        self.is_some = True
        var index = 0
        while index < len(self.names):
            if self.names[index] == name:
                self.values[index] = node
                return
            index += 1
        self.names.append(name)
        self.values.append(node)

    def variable(self, name: StringSlice) -> Int:
        """Return the value of a variable.

        Args:
            name: The variable name.

        Returns:
            The node of the value, or `NO_NODE` when it is absent.
        """
        var index = 0
        while index < len(self.names):
            if self.names[index] == name:
                return self.values[index]
            index += 1
        return NO_NODE

    def bool_value(self, name: StringSlice) -> Int:
        """Return a boolean variable, as upstream `as_bool`.

        Args:
            name: The variable name.

        Returns:
            1 for `true`, 0 for `false`, and -1 when the variable is absent
            or not a boolean.
        """
        var node = self.variable(name)
        if node == NO_NODE or self.document.kind(node) != JsonKind.BOOLEAN:
            return -1
        return 1 if self.document.bool_value(node) else 0

    def variable_equals_true(self, name: StringSlice) -> Bool:
        """Return True if a variable is the boolean `true`.

        Args:
            name: The variable name.

        Returns:
            Whether the value is `true`.
        """
        return self.bool_value(name) == 1


@fieldwise_init
struct VariableCoercionErrorKind(Equatable, ImplicitlyCopyable, Movable):
    """The kind of a `VariableCoercionError`, as the upstream enum arms."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime INVALID_VALUE = VariableCoercionErrorKind(0)
    """The value of the request is not valid: `InvalidValue`."""
    comptime INVALID_DEFAULT_VALUE = VariableCoercionErrorKind(1)
    """The default value is not valid: `InvalidDefaultValue`."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the two kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 1


@fieldwise_init
struct InvalidValueReasonKind(Equatable, ImplicitlyCopyable, Movable):
    """The kind of an `InvalidValueReason`, as the upstream enum arms."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime MISSING_NON_NULL_VALUE = InvalidValueReasonKind(0)
    """No value for a non-null type: `MissingNonNullValue`."""
    comptime UNEXPECTED_NULL = InvalidValueReasonKind(1)
    """`null` for a non-null type: `UnexpectedNull`."""
    comptime INVALID_ENUM_VALUE = InvalidValueReasonKind(2)
    """A string that is not an enum value: `InvalidEnumValue`."""
    comptime EXPECTED_ENUM_STRING = InvalidValueReasonKind(3)
    """A value for an enum that is not a string: `ExpectedEnumString`."""
    comptime EXPECTED_STRING = InvalidValueReasonKind(4)
    """A value for `String` that is not a string: `ExpectedString`."""
    comptime EXPECTED_ID = InvalidValueReasonKind(5)
    """A value for `ID` that is not a string or an integer: `ExpectedId`."""
    comptime EXPECTED_INTEGER = InvalidValueReasonKind(6)
    """A value for `Int` that is not an integer: `ExpectedInteger`."""
    comptime INTEGER_OUT_OF_RANGE = InvalidValueReasonKind(7)
    """An integer for `Int` outside 32 bits: `IntegerOutOfRange`."""
    comptime EXPECTED_FLOAT = InvalidValueReasonKind(8)
    """A value for `Float` that is not a number: `ExpectedFloat`."""
    comptime EXPECTED_BOOLEAN = InvalidValueReasonKind(9)
    """A value for `Boolean` that is not a boolean: `ExpectedBoolean`."""
    comptime EXPECTED_OBJECT = InvalidValueReasonKind(10)
    """A value for an input object that is not an object:
    `ExpectedObject`."""
    comptime MISSING_REQUIRED_FIELD = InvalidValueReasonKind(11)
    """An object without a required field: `MissingRequiredField`."""
    comptime INVALID_ONE_OF = InvalidValueReasonKind(12)
    """A OneOf object without exactly one non-null field: `InvalidOneOf`."""
    comptime UNKNOWN_FIELD = InvalidValueReasonKind(13)
    """An object with a field that the type does not define:
    `UnknownField`."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the fourteen kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 13


@fieldwise_init
struct InvalidValueReason(Copyable, Equatable, Movable, Writable):
    """Why a value cannot be coerced to its type, as upstream
    `InvalidValueReason`. It writes the graphql-js message."""

    var kind: InvalidValueReasonKind
    """The reason."""
    var type_name: String
    """The type, for the kinds that name one; else empty."""
    var value: String
    """The value as graphql-js `inspect` prints it, or the enum string;
    else empty."""
    var field_name: String
    """The field, for `MISSING_REQUIRED_FIELD` and `UNKNOWN_FIELD`; else
    empty."""

    def write_to(self, mut writer: Some[Writer]):
        """Write the message, as upstream `Display`.

        Args:
            writer: The destination.
        """
        var kind = self.kind
        if kind == InvalidValueReasonKind.MISSING_NON_NULL_VALUE:
            writer.write(
                'Expected a value of non-null type "',
                self.type_name,
                '" to be provided.',
            )
        elif kind == InvalidValueReasonKind.UNEXPECTED_NULL:
            writer.write(
                'Expected value of non-null type "',
                self.type_name,
                '" not to be null.',
            )
        elif kind == InvalidValueReasonKind.INVALID_ENUM_VALUE:
            writer.write(
                'Value "',
                self.value,
                '" does not exist in "',
                self.type_name,
                '" enum.',
            )
        elif kind == InvalidValueReasonKind.EXPECTED_ENUM_STRING:
            writer.write(
                'Enum "',
                self.type_name,
                '" cannot represent non-string value: ',
                self.value,
                ".",
            )
        elif kind == InvalidValueReasonKind.EXPECTED_STRING:
            writer.write(
                "String cannot represent a non string value: ", self.value
            )
        elif kind == InvalidValueReasonKind.EXPECTED_ID:
            writer.write("ID cannot represent value: ", self.value)
        elif kind == InvalidValueReasonKind.EXPECTED_INTEGER:
            writer.write("Int cannot represent non-integer value: ", self.value)
        elif kind == InvalidValueReasonKind.INTEGER_OUT_OF_RANGE:
            writer.write(
                "Int cannot represent non 32-bit signed integer value: ",
                self.value,
            )
        elif kind == InvalidValueReasonKind.EXPECTED_FLOAT:
            writer.write(
                "Float cannot represent non numeric value: ", self.value
            )
        elif kind == InvalidValueReasonKind.EXPECTED_BOOLEAN:
            writer.write(
                "Boolean cannot represent a non boolean value: ", self.value
            )
        elif kind == InvalidValueReasonKind.EXPECTED_OBJECT:
            writer.write(
                'Expected value of type "',
                self.type_name,
                '" to be an object, found: ',
                self.value,
                ".",
            )
        elif kind == InvalidValueReasonKind.MISSING_REQUIRED_FIELD:
            writer.write(
                'Expected value of type "',
                self.type_name,
                '" to include required field "',
                self.field_name,
                '", found: ',
                self.value,
                ".",
            )
        elif kind == InvalidValueReasonKind.INVALID_ONE_OF:
            writer.write(
                'Within OneOf Input Object type "',
                self.type_name,
                (
                    '", exactly one field must be specified, and the value'
                    " for that field must be non-null."
                ),
            )
        else:
            writer.write(
                'Expected value of type "',
                self.type_name,
                '" not to include unknown field "',
                self.field_name,
                '", found: ',
                self.value,
                ".",
            )


def _reason(
    kind: InvalidValueReasonKind,
    type_name: String = String(),
    value: String = String(),
    field_name: String = String(),
) -> InvalidValueReason:
    """Make a reason; the unused texts stay empty."""
    return InvalidValueReason(kind, type_name, value, field_name)


@fieldwise_init
struct PathSegmentKind(Equatable, ImplicitlyCopyable, Movable):
    """The kind of a `PathSegment`, as the upstream enum arms."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime INDEX = PathSegmentKind(0)
    """A list index: `Index`."""
    comptime FIELD = PathSegmentKind(1)
    """An input object field: `Field`."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the two kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 1


@fieldwise_init
struct PathSegment(Copyable, Equatable, Movable, Writable):
    """A step into a variable's value: a list index or an input object
    field, as upstream `PathSegment`."""

    var kind: PathSegmentKind
    """Whether the step is an index or a field."""
    var index: Int
    """The list index, for `INDEX`; else 0."""
    var name: String
    """The field name, for `FIELD`; else empty."""

    @staticmethod
    def at_index(index: Int) -> PathSegment:
        """Make a list index step, as upstream `PathSegment::Index`.

        Args:
            index: The index.

        Returns:
            The step.
        """
        return PathSegment(PathSegmentKind.INDEX, index, String())

    @staticmethod
    def field(name: String) -> PathSegment:
        """Make a field step, as upstream `PathSegment::Field`.

        Args:
            name: The field name.

        Returns:
            The step.
        """
        return PathSegment(PathSegmentKind.FIELD, 0, name)

    def write_to(self, mut writer: Some[Writer]):
        """Write the step as graphql-js does: `[0]` or `.name`.

        Args:
            writer: The destination.
        """
        if self.kind == PathSegmentKind.INDEX:
            writer.write("[", self.index, "]")
        else:
            writer.write(".", self.name)


struct ValuePath(Copyable, Defaultable, Equatable, Movable, Writable):
    """Where the invalid value is inside a variable's value, from the
    outside in, as upstream `ValuePath`.

    It writes nothing for the variable itself, and ` at .a[0].b` for a
    value inside it, as graphql-js does.
    """

    var segments: List[PathSegment]
    """The steps, from the outside in."""

    def __init__(out self):
        """Make the path of the variable itself."""
        self.segments = List[PathSegment]()

    def __init__(out self, var segments: List[PathSegment]):
        """Make a path from its steps.

        Args:
            segments: The steps, from the outside in.
        """
        self.segments = segments^

    def write_to(self, mut writer: Some[Writer]):
        """Write the path, as upstream `Display`.

        Args:
            writer: The destination.
        """
        if len(self.segments) == 0:
            return
        writer.write(" at ")
        var index = 0
        while index < len(self.segments):
            writer.write(self.segments[index])
            index += 1


struct InvalidValue(Copyable, Movable, Writable):
    """An invalid value that `validate_runtime_value` finds, as upstream
    `InvalidValue`.

    The path grows while the error goes up, so it holds the innermost step
    first.
    """

    var reversed_path: List[PathSegment]
    """The steps, from the inside out."""
    var reason: InvalidValueReason
    """Why the value is not valid."""

    def __init__(out self, var reason: InvalidValueReason):
        """Make an error at the value itself.

        Args:
            reason: Why the value is not valid.
        """
        self.reversed_path = List[PathSegment]()
        self.reason = reason^

    def path(self) -> ValuePath:
        """Return the path from the outside in, as upstream `path`.

        Returns:
            The path.
        """
        var segments = List[PathSegment](capacity=len(self.reversed_path))
        var index = len(self.reversed_path)
        while index > 0:
            index -= 1
            segments.append(self.reversed_path[index].copy())
        return ValuePath(segments^)

    def write_to(self, mut writer: Some[Writer]):
        """Write the reason and the path, such as
        `Int cannot represent non-integer value: 1.5 at [0]`.

        Args:
            writer: The destination.
        """
        writer.write(self.reason, self.path())


struct VariableCoercionError(Copyable, Movable, Writable):
    """A request error of the coercion of the variable values, as
    upstream `VariableCoercionError`. It writes the graphql-js message."""

    var kind: VariableCoercionErrorKind
    """Whether the request value or the default value is not valid."""
    var name: String
    """The variable name, without `$`."""
    var path: ValuePath
    """Where the invalid value is inside the variable's value."""
    var reason: InvalidValueReason
    """Why the value is not valid."""

    def __init__(
        out self,
        kind: VariableCoercionErrorKind,
        name: String,
        var path: ValuePath,
        var reason: InvalidValueReason,
    ):
        """Make an error.

        Args:
            kind: The kind.
            name: The variable name, without `$`.
            path: Where the invalid value is.
            reason: Why the value is not valid.
        """
        self.kind = kind
        self.name = name
        self.path = path^
        self.reason = reason^

    def write_to(self, mut writer: Some[Writer]):
        """Write the message, as upstream `Display`, such as
        `Variable "$v" has invalid value at [0]: ...`.

        Args:
            writer: The destination.
        """
        writer.write('Variable "$', self.name, '" has invalid ')
        if self.kind == VariableCoercionErrorKind.INVALID_DEFAULT_VALUE:
            writer.write("default ")
        writer.write("value", self.path, ": ", self.reason)


def collect_variables(
    store: Store,
    operation: OperationDefinition,
    var variables: JsonDocument,
    root: Int,
    metadata: SchemaMetadata,
) raises VariableCoercionError -> CoerceVariablesPayload:
    """Coerce the variable values of a request, as upstream
    `collect_variables`.

    Each variable takes the value of the request, or else its default
    value. A value that passes is kept as its node. A default value
    becomes new nodes of the document. A variable with no value and no
    default is absent, unless its type is non-null.

    Args:
        store: The store with the names and the default values.
        operation: The normalized operation.
        variables: The parsed `variables` of the request. The payload takes
            it.
        root: The object node of `variables`, or `NO_NODE` when the request
            has none.
        metadata: The schema metadata, for the enums and the input objects.

    Returns:
        The coerced values. `is_some` is False when there are no values,
        as upstream `Ok(None)`.

    Raises:
        VariableCoercionError: When a value or a default value is not
            valid for its type, or when a non-null variable has no value.
    """
    var payload = CoerceVariablesPayload()
    payload.document = variables^
    var index = 0
    while index < len(operation.variables):
        ref definition = operation.variables[index]
        index += 1
        var name = store.name(definition.name)
        var type_name = store.name(definition.variable_type.name)
        ref shape = definition.variable_type.shape
        var invalid = InvalidValue(
            _reason(InvalidValueReasonKind.UNEXPECTED_NULL)
        )
        var node = NO_NODE
        # Upstream removes a value from the map when a definition takes it.
        if root != NO_NODE and payload.variable(name) == NO_NODE:
            node = payload.document.find(root, name)
        if node != NO_NODE:
            if not _validate(
                payload.document,
                node,
                type_name,
                shape,
                0,
                shape.byte_length(),
                metadata,
                invalid,
            ):
                raise VariableCoercionError(
                    VariableCoercionErrorKind.INVALID_VALUE,
                    name,
                    invalid.path(),
                    invalid.reason.copy(),
                )
            payload.insert(name, node)
            continue
        if definition.default_value != NONE:
            node = _default_node(
                payload.document, store, definition.default_value
            )
            if not _validate(
                payload.document,
                node,
                type_name,
                shape,
                0,
                shape.byte_length(),
                metadata,
                invalid,
            ):
                raise VariableCoercionError(
                    VariableCoercionErrorKind.INVALID_DEFAULT_VALUE,
                    name,
                    invalid.path(),
                    invalid.reason.copy(),
                )
            payload.insert(name, node)
            continue
        if shape.endswith("!"):
            raise VariableCoercionError(
                VariableCoercionErrorKind.INVALID_VALUE,
                name,
                ValuePath(),
                _reason(
                    InvalidValueReasonKind.MISSING_NON_NULL_VALUE,
                    definition.variable_type.text(store),
                ),
            )
    return payload^


def _default_node(mut document: JsonDocument, store: Store, id: Int) -> Int:
    """Add a default value to a document, as upstream
    `From<&Value> for sonic_rs::Value`; return its node."""
    var value = store.values[id]
    var kind = value.kind
    if kind == ValueKind.INT:
        return document.add_int(value.number)
    if kind == ValueKind.FLOAT:
        return _float_node(document, value.real)
    if kind == ValueKind.STRING:
        return document.add_string(store.names[value.text])
    if kind == ValueKind.ENUM:
        return document.add_string(store.names[value.text])
    if kind == ValueKind.BOOLEAN:
        return document.add_bool(value.number != 0)
    if kind == ValueKind.LIST:
        var list = document.add_array()
        var member = value.first
        while member != NONE:
            var child = _default_node(document, store, member)
            document.append(list, child)
            member = store.values[member].next
        return list
    if kind == ValueKind.OBJECT:
        var object = document.add_object()
        var members = store.object_members(id)
        var index = 0
        while index < len(members):
            var child = _default_node(document, store, members[index])
            document.add_member(
                object, store.names[store.values[members[index]].key], child
            )
            index += 1
        return object
    # `null`, and a variable, which upstream also makes `null`.
    return document.add_null()


def _float_node(mut document: JsonDocument, real: Float64) -> Int:
    """Add a float that stays a float: `1.0`, not `1`. A value that is not
    finite becomes `null`, as upstream `new_f64` gives `None`."""
    var text = _rust_float_text(real)
    if "." not in text:
        text += ".0"
    try:
        return document.add_number(text)
    except:
        # `inf.0`, `-inf.0` and `NaN.0` are not JSON numbers.
        return document.add_null()


def validate_runtime_value(
    document: JsonDocument,
    node: Int,
    type_name: String,
    shape: String,
    metadata: SchemaMetadata,
) raises InvalidValue:
    """Check a value against a type, as upstream `validate_runtime_value`.

    `null` passes for a nullable type. A value that is not a list passes
    for a list type when it passes for the item type. A custom scalar
    takes any value.

    Args:
        document: The document with the value.
        node: The value.
        type_name: The named type, such as `Int`.
        shape: The wrappers around `%`, such as `[%!]!`.
        metadata: The schema metadata, for the enums and the input objects.

    Raises:
        InvalidValue: When the value is not valid for the type.
    """
    var invalid = InvalidValue(_reason(InvalidValueReasonKind.UNEXPECTED_NULL))
    if not _validate(
        document,
        node,
        type_name,
        shape,
        0,
        shape.byte_length(),
        metadata,
        invalid,
    ):
        raise invalid^


def _validate(
    document: JsonDocument,
    node: Int,
    type_name: String,
    shape: String,
    start: Int,
    end: Int,
    metadata: SchemaMetadata,
    mut invalid: InvalidValue,
) -> Bool:
    """Check a value against the type `shape[start:end]`; on an error, set
    `invalid` and return False."""
    var bytes = shape.as_bytes()
    var kind = document.kind(node)
    var non_null = bytes[end - 1] == UInt8(ord("!"))
    if kind == JsonKind.NULL:
        if non_null:
            invalid = InvalidValue(
                _reason(
                    InvalidValueReasonKind.UNEXPECTED_NULL,
                    String(shape[byte=start:end]).replace("%", type_name),
                )
            )
            return False
        return True
    if non_null:
        return _validate(
            document, node, type_name, shape, start, end - 1, metadata, invalid
        )
    if bytes[start] != UInt8(ord("[")):
        return _validate_named(document, node, type_name, metadata, invalid)
    if kind != JsonKind.ARRAY:
        return _validate(
            document,
            node,
            type_name,
            shape,
            start + 1,
            end - 1,
            metadata,
            invalid,
        )
    var item = document.first(node)
    var index = 0
    while item != NO_NODE:
        if not _validate(
            document,
            item,
            type_name,
            shape,
            start + 1,
            end - 1,
            metadata,
            invalid,
        ):
            invalid.reversed_path.append(PathSegment.at_index(index))
            return False
        item = document.next(item)
        index += 1
    return True


def _validate_named(
    document: JsonDocument,
    node: Int,
    type_name: String,
    metadata: SchemaMetadata,
    mut invalid: InvalidValue,
) -> Bool:
    """Check a value that is not `null` against a named type."""
    var enum_values = metadata.enum_values.get(type_name)
    if enum_values:
        if document.kind(node) != JsonKind.STRING:
            invalid = InvalidValue(
                _reason(
                    InvalidValueReasonKind.EXPECTED_ENUM_STRING,
                    type_name,
                    _inspect(document, node),
                )
            )
            return False
        var text = document.string_value(node)
        if text not in enum_values.value():
            invalid = InvalidValue(
                _reason(
                    InvalidValueReasonKind.INVALID_ENUM_VALUE, type_name, text
                )
            )
            return False
        return True
    var input_object = metadata.input_objects.get(type_name)
    if input_object:
        return _validate_input_object(
            document, node, type_name, input_object.value(), metadata, invalid
        )
    return _validate_scalar(document, node, type_name, invalid)


def _validate_input_object(
    document: JsonDocument,
    node: Int,
    type_name: String,
    info: InputObjectInfo,
    metadata: SchemaMetadata,
    mut invalid: InvalidValue,
) -> Bool:
    """Check an input object value in the graphql-js order: the OneOf
    count, the defined fields in schema order, then the unknown keys."""
    if document.kind(node) != JsonKind.OBJECT:
        invalid = InvalidValue(
            _reason(
                InvalidValueReasonKind.EXPECTED_OBJECT,
                type_name,
                _inspect(document, node),
            )
        )
        return False
    if info.is_one_of:
        var first = document.first(node)
        if first == NO_NODE or document.next(first) != NO_NODE:
            invalid = InvalidValue(
                _reason(InvalidValueReasonKind.INVALID_ONE_OF, type_name)
            )
            return False
        if document.kind(first) == JsonKind.NULL:
            invalid = InvalidValue(
                _reason(InvalidValueReasonKind.INVALID_ONE_OF, type_name)
            )
            invalid.reversed_path.append(PathSegment.field(document.key(first)))
            return False
    var index = 0
    while index < len(info.fields):
        ref field = info.fields[index]
        index += 1
        var member = document.find(node, field.name)
        if member != NO_NODE:
            if not _validate(
                document,
                member,
                field.type_name,
                field.shape,
                0,
                field.shape.byte_length(),
                metadata,
                invalid,
            ):
                invalid.reversed_path.append(PathSegment.field(field.name))
                return False
            continue
        # A field is required only when it is non-null and has no default.
        if field.shape.endswith("!") and not field.has_default:
            invalid = InvalidValue(
                _reason(
                    InvalidValueReasonKind.MISSING_REQUIRED_FIELD,
                    type_name,
                    _inspect(document, node),
                    field.name,
                )
            )
            return False
    var member = document.first(node)
    while member != NO_NODE:
        if not _defines(info, document, member):
            invalid = InvalidValue(
                _reason(
                    InvalidValueReasonKind.UNKNOWN_FIELD,
                    type_name,
                    _inspect(document, node),
                    document.key(member),
                )
            )
            return False
        member = document.next(member)
    return True


def _defines(
    info: InputObjectInfo, document: JsonDocument, member: Int
) -> Bool:
    """Return True if an input object type defines the key of a member."""
    var index = 0
    while index < len(info.fields):
        if document.key_equals(member, info.fields[index].name):
            return True
        index += 1
    return False


def _validate_scalar(
    document: JsonDocument,
    node: Int,
    name: String,
    mut invalid: InvalidValue,
) -> Bool:
    """Check a value that is not `null` against a built-in scalar. Int and
    ID take only numbers written as integers: `1.0` and `1e3` are floats.
    """
    var kind = document.kind(node)
    if name == "String":
        if kind == JsonKind.STRING:
            return True
        return _fail(
            invalid, InvalidValueReasonKind.EXPECTED_STRING, document, node
        )
    if name == "Boolean":
        if kind == JsonKind.BOOLEAN:
            return True
        return _fail(
            invalid, InvalidValueReasonKind.EXPECTED_BOOLEAN, document, node
        )
    if name == "Float":
        if kind == JsonKind.NUMBER and _is_finite(document.as_float64(node)):
            return True
        return _fail(
            invalid, InvalidValueReasonKind.EXPECTED_FLOAT, document, node
        )
    if name == "ID":
        if kind == JsonKind.STRING:
            return True
        if kind == JsonKind.NUMBER and _number_class(document, node) != _FLOAT:
            return True
        return _fail(
            invalid, InvalidValueReasonKind.EXPECTED_ID, document, node
        )
    if name == "Int":
        if kind != JsonKind.NUMBER:
            return _fail(
                invalid, InvalidValueReasonKind.EXPECTED_INTEGER, document, node
            )
        var number_class = _number_class(document, node)
        if number_class == _FLOAT:
            return _fail(
                invalid, InvalidValueReasonKind.EXPECTED_INTEGER, document, node
            )
        if number_class == _I64 and _fits_int32(document.text(node).as_bytes()):
            return True
        return _fail(
            invalid, InvalidValueReasonKind.INTEGER_OUT_OF_RANGE, document, node
        )
    # Custom scalars.
    return True


def _fail(
    mut invalid: InvalidValue,
    kind: InvalidValueReasonKind,
    document: JsonDocument,
    node: Int,
) -> Bool:
    """Set a scalar error with the inspected value; return False."""
    invalid = InvalidValue(_reason(kind, String(), _inspect(document, node)))
    return False


comptime _FLOAT = 0
"""A number that `sonic_rs` reads as an `f64`."""
comptime _I64 = 1
"""An integer in the `i64` range."""
comptime _U64 = 2
"""An integer above `i64` and in the `u64` range."""

comptime _ZERO = UInt8(ord("0"))
"""The digit `0`."""
comptime _NINE = UInt8(ord("9"))
"""The digit `9`."""
comptime _MINUS = UInt8(ord("-"))
"""The sign `-`."""


def _number_class(document: JsonDocument, node: Int) -> Int:
    """Return how `sonic_rs` reads a JSON number: `_I64`, `_U64` or
    `_FLOAT`. A fraction or an exponent makes a float, and so do `-0` and
    an integer outside `i64` and `u64`."""
    var text = document.text(node).as_bytes()
    var start = 1 if text[0] == _MINUS else 0
    var index = start
    while index < len(text):
        if text[index] < _ZERO or text[index] > _NINE:
            return _FLOAT
        index += 1
    if start == 1:
        # JSON has no leading zeros, so `-0` is the only text here.
        if text[1] == _ZERO:
            return _FLOAT
        if _not_above(text, 1, "9223372036854775808"):
            return _I64
        return _FLOAT
    if _not_above(text, 0, "9223372036854775807"):
        return _I64
    if _not_above(text, 0, "18446744073709551615"):
        return _U64
    return _FLOAT


def _not_above(text: Span[UInt8, _], start: Int, limit: StaticString) -> Bool:
    """Return True if the digits `text[start:]`, with no leading zeros, are
    at most the digits of `limit`."""
    var digits = len(text) - start
    var limit_bytes = limit.as_bytes()
    if digits != len(limit_bytes):
        return digits < len(limit_bytes)
    var index = 0
    while index < digits:
        var byte = text[start + index]
        var bound = limit_bytes[index]
        if byte != bound:
            return byte < bound
        index += 1
    return True


def _fits_int32(text: Span[UInt8, _]) -> Bool:
    """Return True if an integer text is in the 32-bit signed range."""
    if text[0] == _MINUS:
        return _not_above(text, 1, "2147483648")
    return _not_above(text, 0, "2147483647")


def _is_finite(value: Float64) -> Bool:
    """Return True if a float is not NaN and not an infinity."""
    return value - value == 0.0


comptime _MAX_INSPECT_LIST_ITEMS = 10
"""graphql-js `inspect` prints at most this many list items."""
comptime _MAX_INSPECT_DEPTH = 2
"""graphql-js `inspect` prints `[Array]` and `[Object]` at this depth."""


def _inspect(document: JsonDocument, node: Int) -> String:
    """Print a value as graphql-js `inspect` does, for a message."""
    var out = String()
    _write_inspected(out, document, node, 0)
    return out^


def _write_inspected(
    mut out: String, document: JsonDocument, node: Int, depth: Int
):
    """Append the `inspect` text of a value at a nesting depth."""
    var kind = document.kind(node)
    if kind == JsonKind.NULL:
        out += "null"
    elif kind == JsonKind.BOOLEAN:
        out += "true" if document.bool_value(node) else "false"
    elif kind == JsonKind.NUMBER:
        _write_number(out, document, node)
    elif kind == JsonKind.STRING:
        var bytes = List[UInt8]()
        write_string(bytes, document.string_value(node).as_bytes())
        out += String(unsafe_from_utf8=bytes^)
    elif kind == JsonKind.ARRAY:
        var item = document.first(node)
        if item == NO_NODE:
            out += "[]"
        elif depth >= _MAX_INSPECT_DEPTH:
            out += "[Array]"
        else:
            out += "["
            var index = 0
            while item != NO_NODE and index < _MAX_INSPECT_LIST_ITEMS:
                if index > 0:
                    out += ", "
                _write_inspected(out, document, item, depth + 1)
                item = document.next(item)
                index += 1
            var remaining = document.length(node) - index
            if remaining == 1:
                out += ", ... 1 more item"
            elif remaining > 1:
                out += String(", ... ", remaining, " more items")
            out += "]"
    else:
        var member = document.first(node)
        if member == NO_NODE:
            out += "{}"
        elif depth >= _MAX_INSPECT_DEPTH:
            out += "[Object]"
        else:
            out += "{ "
            var index = 0
            while member != NO_NODE:
                if index > 0:
                    out += ", "
                out += document.key(member)
                out += ": "
                _write_inspected(out, document, member, depth + 1)
                member = document.next(member)
                index += 1
            out += " }"


def _write_number(mut out: String, document: JsonDocument, node: Int):
    """Append a number as upstream `write_inspected` does: an integer as
    its digits, and a float without a fraction with `.0`."""
    if _number_class(document, node) != _FLOAT:
        out += document.text(node)
        return
    var value = document.as_float64(node)
    if not _is_finite(value):
        out += "-Infinity" if value < 0.0 else "Infinity"
        return
    if value == 0.0:
        out += "0.0"
        return
    out += _rust_float_text(value)
    if floor(value) == value:
        out += ".0"

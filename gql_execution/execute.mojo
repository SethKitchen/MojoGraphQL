# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Execute a GraphQL operation against a schema, with resolvers.

Port of graphql-js 16.14.2 `execution/execute.ts`: `execute`,
`executeSync`, `buildExecutionContext`, `executeOperation`,
`executeFields`, `executeField`, `completeValue` and its list, leaf,
abstract and object cases, `defaultFieldResolver`, `defaultTypeResolver`
and `getFieldDef`; the meta fields `__typename`, `__schema` and `__type`
and the resolvers of `type/introspection.ts`; the `serialize` functions of
`type/scalars.ts` and of `GraphQLEnumType`; and `error/locatedError.ts`.

**Resolvers.** graphql-js resolvers are JavaScript functions. Here a
resolver is a Mojo function that `Resolvers` registers for a type and a
field. It reads its `source` and `args` in a `Values` arena and returns a
value of the same arena:

    def resolve(
        mut values: Values, source: Int, args: Int, info: ResolveInfo
    ) raises -> Int

A field with no resolver uses graphql-js `defaultFieldResolver`: the
property of the source object with the field's name. `Resolvers` also
holds the `resolveType` of an abstract type, the `isTypeOf` of an object
type, and the `fieldResolver` and `typeResolver` defaults of graphql-js
`ExecutionArgs`.

**Results.** `ExecutionResult.data` is a `JsonDocument`, and `to_json`
gives the text of graphql-js `JSON.stringify(result)`: the same keys, in
the same order, and the same errors with their locations and paths.

**Differences from upstream.**

- Execution is synchronous: there are no promises. `execute` is
  `executeSync`. A subscription operation executes as graphql-js `execute`
  executes it; `gql_execution.subscribe` has `subscribe`, which uses
  `prepare`, `execute_subscription` and `resolve_source_event` here.
- `Resolvers.subscribe` and `subscribe_field_resolver` are the `subscribe`
  of a field and `subscribeFieldResolver`. A `subscribe` function is a
  `FieldResolver` that returns a value of `Values.add_stream`.
- A resolver raises an `Error`, which gives the message of the field
  error, or returns an error value. It cannot raise a `GraphQLError` with
  extensions.
- `execute` raises the `assertValidSchema` error unless
  `ExecutionArgs.assume_valid_schema` is set. graphql-js keeps the result
  of schema validation on the schema; a Mojo schema does not, so a server
  validates it once and sets the flag.
- graphql-js `CollectedErrors` drops an error under a path that is already
  null. That happens only when promises settle after a sibling fails, so
  synchronous execution never drops an error, and this port does not keep
  the positions.
- An error of execution has no source excerpt: `String(error)` is the
  message. graphql-js prints the excerpt only in `toString`, and the JSON
  of a response has no excerpt.
- A meta field and an introspection field always use their own resolver.
  An introspection type used by a schema field, with a source that is not
  an introspection handle, uses the default field resolver.
- `ExecutionArgs.field_timing` is an addition for the Apollo Server
  inline trace plugin. Apollo Server wraps each field resolver of the
  schema to call `willResolveField` before it and the returned function
  after it. Here execution records a `FieldTiming` for each field that
  Apollo Server wraps: the fields of the object types whose names do not
  start with `__`. The timings are in `ExecutionResult.field_timings`, in
  the order that the resolvers started. When `field_timing` is False,
  execution records nothing and the result is the same.
"""

from gql_json.value import FLAG_KEY_DECODED, JsonDocument, JsonKind
from gql_json.value import NO_NODE as NO_JSON
from gql_json.writer import stringify
from gql_language.ast import NO_NODE, Document, Kind, OperationType, Role
from gql_language.error import GraphQLError, PathSegment
from gql_language.source import Source, SourceLocation
from std.math import inf, nan
from gql_json.number import read_float64
from gql_schema.definition import (
    NO_TYPE,
    AstRef,
    Range,
    Schema,
    TypeKind,
    TypeRef,
)
from gql_schema.validate import assert_valid_schema
from gql_execution.coerce import (
    MAX_INT,
    MIN_INT,
    ScalarKind,
    is_integer,
    scalar_kind,
)
from gql_execution.collect_fields import FieldCollector, FieldGroup, FieldPlan
from gql_execution.value import UNDEFINED, ValueKind, Values, inspect
from gql_execution.values import (
    DEFAULT_MAX_ERRORS,
    ArgumentOwner,
    coerce_argument,
    get_argument_values,
    get_variable_values,
)
from gql_schema.values import js_number_to_string, print_default
from std.time import perf_counter_ns

comptime FieldResolver = def(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises thin -> Int
"""A field resolver, graphql-js `GraphQLFieldResolver`: it reads the
source and the arguments in the arena, and returns a value there, or
`UNDEFINED`."""

comptime TypeResolver = def(
    mut values: Values, value: Int, info: ResolveInfo, abstract_type: Int
) raises thin -> Int
"""A type resolver, graphql-js `GraphQLTypeResolver`: it returns the name
of the object type of a value as a string value, or another value for the
graphql-js errors."""

comptime IsTypeOf = def(
    mut values: Values, value: Int, info: ResolveInfo
) raises thin -> Bool
"""An `isTypeOf` function, graphql-js `GraphQLIsTypeOfFn`."""


def default_field_resolver(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """Return the property of the source with the field's name, as
    graphql-js `defaultFieldResolver`.

    Args:
        values: The arena.
        source: The source value.
        args: The argument values; not read.
        info: The field; `field_name` is read.

    Returns:
        The property, or `UNDEFINED` when the source is not an object or
        has no such property.

    Raises:
        Error: Never; a field resolver can raise.
    """
    return values.get(source, info.field_name)


struct Resolvers(Copyable, Movable):
    """The resolvers of a schema: graphql-js `resolve`, `resolveType`,
    `isTypeOf`, and the `fieldResolver` and `typeResolver` of
    `ExecutionArgs`."""

    var field_types: List[String]
    """The type of each field resolver."""
    var field_names: List[String]
    """The field of each field resolver."""
    var field_functions: List[FieldResolver]
    """Each field resolver."""
    var type_names: List[String]
    """The abstract type of each type resolver."""
    var type_functions: List[TypeResolver]
    """Each type resolver."""
    var object_names: List[String]
    """The object type of each `isTypeOf` function."""
    var object_functions: List[IsTypeOf]
    """Each `isTypeOf` function."""
    var default_field: FieldResolver
    """The resolver of a field with none: graphql-js `fieldResolver`."""
    var default_type: List[TypeResolver]
    """The type resolver of the abstract types with none, graphql-js
    `typeResolver`, when there is one; graphql-js `defaultTypeResolver`
    otherwise."""
    var has_default_field: Bool
    """Whether `default_field` is not graphql-js `defaultFieldResolver`."""
    var subscribe_types: List[String]
    """The type of each `subscribe` function."""
    var subscribe_names: List[String]
    """The field of each `subscribe` function."""
    var subscribe_functions: List[FieldResolver]
    """Each `subscribe` function of a field."""
    var default_subscribe: FieldResolver
    """The `subscribe` of a field with none: graphql-js
    `subscribeFieldResolver`, `defaultFieldResolver` by default."""

    def __init__(out self):
        """Start with no resolvers: every field uses the default."""
        self.field_types = List[String]()
        self.field_names = List[String]()
        self.field_functions = List[FieldResolver]()
        self.type_names = List[String]()
        self.type_functions = List[TypeResolver]()
        self.object_names = List[String]()
        self.object_functions = List[IsTypeOf]()
        self.default_field = default_field_resolver
        self.default_type = List[TypeResolver]()
        self.has_default_field = False
        self.subscribe_types = List[String]()
        self.subscribe_names = List[String]()
        self.subscribe_functions = List[FieldResolver]()
        self.default_subscribe = default_field_resolver

    def subscribe(
        mut self, type_name: String, field_name: String, resolve: FieldResolver
    ):
        """Set the `subscribe` function of a subscription field.

        It returns the source event stream: a value that
        `Values.add_stream` made. Another value is an error of `subscribe`.

        Args:
            type_name: The subscription type, such as `Subscription`.
            field_name: The field.
            resolve: The function.
        """
        self.subscribe_types.append(type_name)
        self.subscribe_names.append(field_name)
        self.subscribe_functions.append(resolve)

    def subscribe_field_resolver(mut self, resolve: FieldResolver):
        """Set the `subscribe` of the fields with none, as graphql-js
        `ExecutionArgs.subscribeFieldResolver`.

        Args:
            resolve: The function.
        """
        self.default_subscribe = resolve

    def subscribe_function(
        self, type_name: StringSlice, field_name: StringSlice
    ) -> FieldResolver:
        """Return the `subscribe` of a field, or the default.

        Args:
            type_name: The subscription type.
            field_name: The field.

        Returns:
            The function.
        """
        var index = len(self.subscribe_functions) - 1
        while index >= 0:
            if (
                self.subscribe_types[index] == type_name
                and self.subscribe_names[index] == field_name
            ):
                return self.subscribe_functions[index]
            index -= 1
        return self.default_subscribe

    def field(
        mut self, type_name: String, field_name: String, resolve: FieldResolver
    ):
        """Set the resolver of a field, as graphql-js `resolve`.

        Args:
            type_name: The object or interface type, such as `Query`.
            field_name: The field.
            resolve: The resolver.
        """
        self.field_types.append(type_name)
        self.field_names.append(field_name)
        self.field_functions.append(resolve)

    def type_resolver(mut self, type_name: String, resolve: TypeResolver):
        """Set the `resolveType` of an interface or union type.

        Args:
            type_name: The abstract type.
            resolve: The type resolver.
        """
        self.type_names.append(type_name)
        self.type_functions.append(resolve)

    def is_type_of(mut self, type_name: String, check: IsTypeOf):
        """Set the `isTypeOf` of an object type.

        Args:
            type_name: The object type.
            check: The function.
        """
        self.object_names.append(type_name)
        self.object_functions.append(check)

    def field_resolver(mut self, resolve: FieldResolver):
        """Set the resolver of the fields with none, as graphql-js
        `ExecutionArgs.fieldResolver`.

        Args:
            resolve: The resolver.
        """
        self.default_field = resolve
        self.has_default_field = True

    def default_type_resolver(mut self, resolve: TypeResolver):
        """Set the type resolver of the abstract types with none, as
        graphql-js `ExecutionArgs.typeResolver`.

        Args:
            resolve: The type resolver.
        """
        self.default_type.clear()
        self.default_type.append(resolve)


struct ResolveInfo(Copyable, Movable):
    """What a resolver knows of the field it resolves: graphql-js
    `GraphQLResolveInfo`."""

    var field_name: String
    """The field's name."""
    var field: Int
    """The field's index in `Schema.fields`, or a negative number for a
    meta field."""
    var field_nodes: List[Int]
    """The `Field` nodes of the response key, in document order."""
    var return_type: TypeRef
    """The field's type."""
    var parent_type: Int
    """The object type whose field this is."""
    var path: List[PathSegment]
    """The response path of the field, or of the list item."""
    var operation: Int
    """The `OperationDefinition` node."""
    var root_value: Int
    """The root value."""
    var context_value: Int
    """The context value: graphql-js `contextValue`."""
    var variable_values: Int
    """The coerced variable values: an object."""

    def __init__(out self):
        """Make an empty info, for a resolver called outside execution."""
        self.field_name = String("")
        self.field = NO_TYPE
        self.field_nodes = List[Int]()
        self.return_type = TypeRef.of(NO_TYPE)
        self.parent_type = NO_TYPE
        self.path = List[PathSegment]()
        self.operation = NO_NODE
        self.root_value = UNDEFINED
        self.context_value = UNDEFINED
        self.variable_values = UNDEFINED


struct FieldTiming(Copyable, Movable):
    """The resolver of one field and its times: what the Apollo Server
    `willResolveField` hook gets, and when its end function runs."""

    var path: List[PathSegment]
    """The response path of the field."""
    var field_name: String
    """The field's name; the last key of `path` is its response key."""
    var return_type: TypeRef
    """The field's type."""
    var parent_type: Int
    """The object type whose field this is."""
    var start_ns: Int
    """The `perf_counter_ns` before the resolver."""
    var end_ns: Int
    """The `perf_counter_ns` after the resolver returned or raised."""

    def __init__(
        out self,
        var path: List[PathSegment],
        field_name: String,
        return_type: TypeRef,
        parent_type: Int,
        start_ns: Int,
    ):
        """Record the start of a resolver.

        Args:
            path: The response path.
            field_name: The field's name.
            return_type: The field's type.
            parent_type: The object type.
            start_ns: The `perf_counter_ns` before the resolver.
        """
        self.path = path^
        self.field_name = field_name
        self.return_type = return_type
        self.parent_type = parent_type
        self.start_ns = start_ns
        self.end_ns = start_ns


struct ExecutionArgs(Movable):
    """The inputs of an execution, as graphql-js `ExecutionArgs`, with the
    arena of their values."""

    var values: Values
    """The arena of the root value, the context, the variables, and every
    value that the resolvers make. It outlives the execution."""
    var root_value: Int
    """The root value: graphql-js `rootValue`."""
    var context_value: Int
    """The context value: graphql-js `contextValue`."""
    var variable_values: Int
    """The raw variable values, an object, or `UNDEFINED`."""
    var operation_name: Optional[String]
    """The operation to run: graphql-js `operationName`."""
    var resolvers: Resolvers
    """The resolvers."""
    var max_coercion_errors: Int
    """The graphql-js `options.maxCoercionErrors`."""
    var assume_valid_schema: Bool
    """Skip `assertValidSchema`, for a schema that is known to be valid."""
    var field_timing: Bool
    """Record a `FieldTiming` for each resolved field, for the Apollo
    Server `willResolveField` hook."""

    def __init__(out self):
        """Start with no values and no resolvers."""
        self.values = Values()
        self.root_value = UNDEFINED
        self.context_value = UNDEFINED
        self.variable_values = UNDEFINED
        self.operation_name = None
        self.resolvers = Resolvers()
        self.max_coercion_errors = DEFAULT_MAX_ERRORS
        self.assume_valid_schema = False
        self.field_timing = False


struct ExecutionResult(Movable):
    """The result of an execution: graphql-js `ExecutionResult`."""

    var data: JsonDocument
    """The data. Its root is an object, `null`, or `NO_NODE` when the
    result has no `data` key."""
    var errors: List[GraphQLError]
    """The errors, in the order they happened."""
    var field_timings: List[FieldTiming]
    """The timings of the resolved fields when
    `ExecutionArgs.field_timing` is set; empty otherwise."""

    def __init__(
        out self, var data: JsonDocument, var errors: List[GraphQLError]
    ):
        """Make a result.

        Args:
            data: The data document.
            errors: The errors.
        """
        self.data = data^
        self.errors = errors^
        self.field_timings = List[FieldTiming]()

    def take_data(deinit self) -> JsonDocument:
        """End the result and return its data.

        Returns:
            The data document.
        """
        return self.data^

    def has_data(self) -> Bool:
        """Return True if the result has a `data` key.

        Returns:
            Whether `data` has a root.
        """
        return self.data.root != NO_JSON

    def to_json(self) -> String:
        """Return the result as graphql-js `JSON.stringify(result)` writes
        it.

        Returns:
            Such as `{"errors":[...],"data":{...}}`, or `{"data":{...}}`
            when there is no error.
        """
        var out = String("{")
        if len(self.errors) > 0:
            out += '"errors":['
            var index = 0
            while index < len(self.errors):
                if index > 0:
                    out += ","
                out += self.errors[index].to_json()
                index += 1
            out += "]"
        if self.has_data():
            if len(self.errors) > 0:
                out += ","
            out += '"data":' + stringify(self.data, self.data.root)
        return out + "}"


comptime TAG_SCHEMA = -1
"""The handle tag of the schema, the source of `__Schema` fields."""
comptime TAG_TYPE = -2
"""The handle tag of a type: the id is the named type, the first extra
number the wrapper depth, the second the wrapper bits of `TypeRef`."""
comptime TAG_FIELD = -3
"""The handle tag of a field: the id is its index in `Schema.fields`."""
comptime TAG_INPUT_VALUE = -4
"""The handle tag of an argument or input field."""
comptime TAG_ENUM_VALUE = -5
"""The handle tag of an enum value."""
comptime TAG_DIRECTIVE = -6
"""The handle tag of a directive."""

comptime META_TYPENAME = -2
"""The field index that stands for `__typename`."""
comptime META_SCHEMA = -3
"""The field index that stands for `__schema`."""
comptime META_TYPE = -4
"""The field index that stands for `__type`."""
comptime _UNKNOWN = -5
comptime _SKIP = -2


@fieldwise_init
struct _GroupCache(ImplicitlyCopyable, Movable):
    """What the executor keeps for one field group of the collector, in
    one list so that an execution makes one allocation for all of it."""

    var key: Int64
    """The response key in the result bytes, start and end, or -1."""
    var field: Int32
    """The field of `_field_def`, or `_UNKNOWN`."""
    var args: Int32
    """The coerced arguments of an introspection field, or `_UNKNOWN`."""
    var sub_type: Int32
    """The first type whose subfields were collected, or `_UNKNOWN`."""
    var sub_plan: Int32
    """The plan of the subfields of `sub_type`."""

    @staticmethod
    def empty() -> _GroupCache:
        """Return the entry of a group that has nothing kept."""
        return _GroupCache(
            -1, Int32(_UNKNOWN), Int32(_UNKNOWN), Int32(_UNKNOWN), 0
        )


comptime _VALUE: Int32 = 0


struct _Cursor(Movable):
    """The line and column of byte offsets of a source, found in one pass
    when the offsets ascend: graphql-js `getLocation` for each field node
    of an error."""

    var index: Int
    var line: Int
    var units: Int

    def __init__(out self):
        """Start at the first byte."""
        self.index = 0
        self.line = 1
        self.units = 0

    def advance(mut self, source: Source, position: Int) -> SourceLocation:
        """Return the location of an offset, as `Source.get_location` does."""
        if position < self.index:
            self.index = 0
            self.line = 1
            self.units = 0
        var data = source.bytes.unsafe_ptr()
        var stop = min(position, source.length)
        while self.index < stop:
            var byte = data[unsafe_offset=self.index]
            if byte == 10 or byte == 13:
                self.line += 1
                self.units = 0
                if byte == 13 and data[unsafe_offset=self.index + 1] == 10:
                    self.index += 1
            elif byte & 0xC0 != 0x80:
                self.units += 2 if byte >= 0xF0 else 1
            self.index += 1
        return SourceLocation(self.line, self.units + 1)


@fieldwise_init
struct _Source(ImplicitlyCopyable):
    """The source of the fields of an object: a value of the arena, or an
    introspection element."""

    var tag: Int32
    """`_VALUE` for a value of the arena; a negative `TAG_` otherwise."""
    var id: Int
    """The value's index, or the element's index."""
    var first: Int32
    """A type's wrapper depth."""
    var second: Int32
    """A type's wrapper bits."""

    @staticmethod
    def value(index: Int) -> _Source:
        """Return the source of a value of the arena."""
        return _Source(_VALUE, index, 0, 0)

    @staticmethod
    def type(ref_: TypeRef) -> _Source:
        """Return the source of a type."""
        return _Source(
            Int32(TAG_TYPE),
            Int(ref_.named),
            Int32(ref_.depth),
            Int32(ref_.bits),
        )

    def type_ref(self) -> TypeRef:
        """Return the type of a type source."""
        return TypeRef(Int32(self.id), UInt8(self.first), UInt32(self.second))


struct _Executor[
    s: Origin[mut=False], d: Origin[mut=False], r: Origin[mut=False]
](Movable):
    """The state of one execution: graphql-js `ExecutionContext`."""

    var schema: Pointer[Schema, Self.s]
    var document: Pointer[Document, Self.d]
    var resolvers: Pointer[Resolvers, Self.r]
    var values: Values
    var data: JsonDocument
    var errors: List[GraphQLError]
    var collector: FieldCollector
    var variables: Int
    var root_value: Int
    var context_value: Int
    var operation: Int
    var path: List[Int32]
    var subfields: Dict[Int, Int]
    var cache: List[_GroupCache]
    # The resolver of each field and type, by index, or empty when there
    # are no resolvers of that kind: see `_slot`.
    var field_resolvers: List[Int32]
    var type_resolvers: List[Int32]
    var type_checks: List[Int32]
    var custom_default: Bool
    var intro_types: Array[Int, 6]
    var intro_starts: List[Int]
    var intro_codes: List[Int8]
    var string_type: Int
    # `ExecutionArgs.field_timing`, and the timings it records.
    var field_timing: Bool
    var field_timings: List[FieldTiming]

    def __init__(
        out self,
        ref[Self.s] schema: Schema,
        ref[Self.d] document: Document,
        ref[Self.r] resolvers: Resolvers,
        var values: Values,
    ):
        """Start an execution."""
        self.schema = Pointer(to=schema)
        self.document = Pointer(to=document)
        self.resolvers = Pointer(to=resolvers)
        self.values = values^
        self.data = JsonDocument()
        self.data.nodes.reserve(32)
        self.data.bytes.reserve(512)
        self.errors = List[GraphQLError]()
        self.collector = FieldCollector(schema, document)
        self.variables = UNDEFINED
        self.root_value = UNDEFINED
        self.context_value = UNDEFINED
        self.operation = NO_NODE
        self.path = List[Int32](capacity=32)
        self.subfields = Dict[Int, Int]()
        self.cache = List[_GroupCache]()
        self.field_resolvers = List[Int32]()
        self.type_resolvers = List[Int32]()
        self.type_checks = List[Int32]()
        self.custom_default = False
        self.intro_types = Array[Int, 6](fill=NO_TYPE)
        self.intro_starts = List[Int]()
        self.intro_codes = List[Int8]()
        self.string_type = schema.type_named("String")
        self.field_timing = False
        self.field_timings = List[FieldTiming]()
        self._bind(schema, resolvers)
        self._index_introspection(schema)

    def _bind(mut self, schema: Schema, resolvers: Resolvers):
        """Find the schema element of each resolver; a resolver of an
        element the schema does not have is not used. A table is made only
        for a kind of resolver that there is."""
        if len(resolvers.field_functions) > 0:
            self.field_resolvers = List[Int32](
                length=len(schema.fields), fill=-1
            )
        if len(resolvers.type_functions) > 0:
            self.type_resolvers = List[Int32](length=len(schema.types), fill=-1)
        if len(resolvers.object_functions) > 0:
            self.type_checks = List[Int32](length=len(schema.types), fill=-1)
        var index = 0
        while index < len(resolvers.field_functions):
            var type = schema.type_named(resolvers.field_types[index])
            if type != NO_TYPE:
                var field = schema.field_named(
                    type, resolvers.field_names[index]
                )
                if field != NO_TYPE:
                    self.field_resolvers[field] = Int32(index)
            index += 1
        index = 0
        while index < len(resolvers.type_functions):
            var type = schema.type_named(resolvers.type_names[index])
            if type != NO_TYPE:
                self.type_resolvers[type] = Int32(index)
            index += 1
        index = 0
        while index < len(resolvers.object_functions):
            var type = schema.type_named(resolvers.object_names[index])
            if type != NO_TYPE:
                self.type_checks[type] = Int32(index)
            index += 1

    def _index_introspection(mut self, schema: Schema):
        """Find the six introspection types. Their resolver codes are found
        when an operation first reads an introspection field, so an
        operation without introspection does not pay for them."""
        comptime names: Array[StaticString, 6] = [
            "__Schema",
            "__Type",
            "__Field",
            "__InputValue",
            "__EnumValue",
            "__Directive",
        ]
        var which = 0
        while which < 6:
            self.intro_types[which] = schema.type_named(
                materialize[names]()[which]
            )
            which += 1

    def _index_introspection_codes(mut self):
        """Give each field of the introspection types its resolver code."""
        ref schema = self.schema[]
        var which = 0
        while which < 6:
            var span = schema.types[self.intro_types[which]].fields
            self.intro_starts.append(len(self.intro_codes) - Int(span.start))
            var field = Int(span.start)
            while field < span.end():
                self.intro_codes.append(
                    Int8(_intro_code(which, schema.fields[field].name))
                )
                field += 1
            which += 1

    # --- bookkeeping ----------------------------------------------------

    def _sync_groups(mut self):
        """Give each new group of the collector its cache entries."""
        var count = len(self.collector.groups)
        if len(self.cache) < count:
            self.cache.resize(count, _GroupCache.empty())

    def _field_def(mut self, parent: Int, group: Int) -> Int:
        """Return graphql-js `getFieldDef` for a group of a plan of the
        parent type: a field index, a `META_` index, or `NO_TYPE`. A plan
        belongs to one type, so the result is kept per group."""
        var cached = Int(self.cache.unsafe_ptr()[unsafe_offset=group].field)
        if cached != _UNKNOWN:
            return cached
        ref schema = self.schema[]
        var node = self.collector.node(Int(self.collector.group(group).start))
        var name = self.document[].name(node)
        var field: Int
        if name == "__typename":
            field = META_TYPENAME
        elif name == "__schema" and parent == Int(schema.query_type):
            field = META_SCHEMA
        elif name == "__type" and parent == Int(schema.query_type):
            field = META_TYPE
        else:
            field = schema.field_named(parent, name)
        self.cache[group].field = Int32(field)
        return field

    def _field_name(self, field: Int) -> String:
        """Return the name of a field; a meta field never reaches a message
        or a resolver."""
        return self.schema[].fields[field].name

    def _return_type(self, field: Int) -> TypeRef:
        """Return the type of a field or a meta field."""
        if field == META_TYPENAME:
            return TypeRef.of(self.string_type).non_null()
        if field == META_SCHEMA:
            return TypeRef.of(self.intro_types[0]).non_null()
        if field == META_TYPE:
            return TypeRef.of(self.intro_types[1])
        return self.schema[].fields[field].type

    def _add_member(mut self, object: Int, group: Int, child: Int):
        """Make a value the last member of a result object, under the
        group's response key. The key's text is written once per group."""
        var key = self.cache.unsafe_ptr()[unsafe_offset=group].key
        if key < 0:
            var start = len(self.data.bytes)
            var node = Int(self.collector.group(group).key)
            self.data.bytes.extend(self.document[].text(node).as_bytes())
            key = (Int64(start) << 32) | Int64(len(self.data.bytes))
            self.cache[group].key = key
        ref member = self.data.nodes[child]
        member.key_start = Int32(key >> 32)
        member.key_end = Int32(key & 0xFFFFFFFF)
        member.flags |= FLAG_KEY_DECODED
        self.data.append(object, child)

    def _path_list(self, depth: Int) -> List[PathSegment]:
        """Return the response path of the first `depth` path entries."""
        var out = List[PathSegment](capacity=depth)
        var index = 0
        while index < depth:
            var entry = Int(self.path[index])
            if entry < 0:
                out.append(PathSegment.of_index(-entry - 1))
            else:
                var node = Int(self.collector.group(entry).key)
                out.append(
                    PathSegment.of_key(String(self.document[].text(node)))
                )
            index += 1
        return out^

    def _locate(
        self, var error: GraphQLError, group: Int, depth: Int
    ) -> GraphQLError:
        """Return graphql-js `locatedError`: an error with a path stays as
        it is; another gets the path, and the locations of the field nodes
        when it has none."""
        if len(error.path) > 0:
            return error^
        if len(error.locations) == 0:
            var found = self.collector.group(group)
            ref source = self.document[].source
            var cursor = _Cursor()
            var index = Int(found.start)
            while index < Int(found.start + found.count):
                error.locations.append(
                    cursor.advance(
                        source,
                        self.document[].start(self.collector.node(index)),
                    )
                )
                index += 1
        error.path = self._path_list(depth)
        return error^

    def _handle_error(
        mut self, var error: GraphQLError, group: Int, type: TypeRef, depth: Int
    ) raises GraphQLError -> Int:
        """Return graphql-js `handleFieldError`: a non-null type passes
        the error up; another type records it and becomes `null`."""
        var located = self._locate(error^, group, depth)
        if type.is_non_null():
            raise located^
        self.path.resize(depth, 0)
        self.errors.append(located^)
        return self.data.add_null()

    def _info(
        self, parent: Int, field: Int, group: Int, type: TypeRef
    ) -> ResolveInfo:
        """Return graphql-js `buildResolveInfo` for the current path."""
        var info = ResolveInfo()
        info.field_name = self._field_name(field)
        info.field = field
        var found = self.collector.group(group)
        var index = Int(found.start)
        while index < Int(found.start + found.count):
            info.field_nodes.append(self.collector.node(index))
            index += 1
        info.return_type = type
        info.parent_type = parent
        info.path = self._path_list(len(self.path))
        info.operation = self.operation
        info.root_value = self.root_value
        info.context_value = self.context_value
        info.variable_values = self.variables
        return info^

    def _subfields(mut self, type: Int, group: Int) raises GraphQLError -> Int:
        """Return graphql-js `collectSubfields`, memoized on the type and
        the group. The plan of the first type of a group is kept with the
        group; the plans of other types, for an abstract type, in a map."""
        var entry = self.cache.unsafe_ptr()[unsafe_offset=group]
        var first = Int(entry.sub_type)
        if first == type:
            return Int(entry.sub_plan)
        var key = (type << 32) | group
        if first != _UNKNOWN:
            var known = self.subfields.get(key, -1)
            if known >= 0:
                return known
        var plan = self.collector.collect_subfields(
            self.schema[],
            self.document[],
            self.values,
            self.variables,
            type,
            group,
        )
        self._sync_groups()
        if first == _UNKNOWN:
            self.cache[group].sub_type = Int32(type)
            self.cache[group].sub_plan = Int32(plan)
        else:
            self.subfields[key] = plan
        return plan

    # --- execution ------------------------------------------------------

    def execute_fields(
        mut self, parent: Int, source: _Source, plan: Int
    ) raises GraphQLError -> Int:
        """Return graphql-js `executeFields`: the result object of a plan;
        it raises the located error of a non-null field that failed."""
        var object = self.data.add_object()
        var found = self.collector.plan(plan)
        var group = Int(found.start)
        var end = group + Int(found.count)
        while group < end:
            self.path.append(Int32(group))
            var result = self._execute_field(parent, source, group)
            _ = self.path.pop()
            if result != _SKIP:
                self._add_member(object, group, result)
            group += 1
        return object

    def _execute_field(
        mut self, parent: Int, source: _Source, group: Int
    ) raises GraphQLError -> Int:
        """Return graphql-js `executeField`: the result, or `_SKIP` for a
        field the type does not have."""
        var field = self._field_def(parent, group)
        if field == NO_TYPE:
            return _SKIP
        var type = self._return_type(field)
        var depth = len(self.path)
        try:
            return self._resolve_field(parent, source, group, field, type)
        except e:
            return self._handle_error(e^, group, type, depth)

    def _resolve_field(
        mut self,
        parent: Int,
        source: _Source,
        group: Int,
        field: Int,
        type: TypeRef,
    ) raises GraphQLError -> Int:
        """Resolve a field and complete its value."""
        if field < 0:
            return self._meta_field(parent, group, field)
        if source.tag != _VALUE:
            return self._introspect(
                self._intro_field_code(parent, field), source, group, field
            )
        var node = self.collector.node(Int(self.collector.group(group).start))
        var source_value = source.id
        var resolver = _slot(self.field_resolvers, field)
        var result: Int
        if self.field_timing:
            result = self._timed_resolve(
                parent, source_value, node, group, field, type, resolver
            )
        elif resolver < 0 and not self.custom_default:
            if self.schema[].fields[field].arguments.count > 0:
                _ = get_argument_values(
                    self.schema[],
                    ArgumentOwner.FIELD,
                    field,
                    self.document[],
                    node,
                    self.values,
                    self.variables,
                )
            result = self.values.get(
                source_value, self.schema[].fields[field].name
            )
        else:
            var args = get_argument_values(
                self.schema[],
                ArgumentOwner.FIELD,
                field,
                self.document[],
                node,
                self.values,
                self.variables,
            )
            var info = self._info(parent, field, group, type)
            result = self._call_field(resolver, source_value, args, info)
        return self._complete_value(type, group, parent, field, result)

    @no_inline
    def _timed_resolve(
        mut self,
        parent: Int,
        source: Int,
        node: Int,
        group: Int,
        field: Int,
        type: TypeRef,
        resolver: Int,
    ) raises GraphQLError -> Int:
        """Resolve a field as `_resolve_field` does, and record its
        `FieldTiming`. The arguments are coerced first, as graphql-js
        `executeField` coerces them before it calls the resolver that
        Apollo Server wraps."""
        var args = get_argument_values(
            self.schema[],
            ArgumentOwner.FIELD,
            field,
            self.document[],
            node,
            self.values,
            self.variables,
        )
        var info = self._info(parent, field, group, type)
        if self.schema[].types[parent].name.startswith("__"):
            return self._call_field(resolver, source, args, info)
        var at = len(self.field_timings)
        self.field_timings.append(
            FieldTiming(
                info.path.copy(),
                info.field_name,
                type,
                parent,
                Int(perf_counter_ns()),
            )
        )
        try:
            var result = self._call_field(resolver, source, args, info)
            self.field_timings[at].end_ns = Int(perf_counter_ns())
            return result
        except e:
            self.field_timings[at].end_ns = Int(perf_counter_ns())
            raise e^

    def _call_field(
        mut self, resolver: Int, source: Int, args: Int, info: ResolveInfo
    ) raises GraphQLError -> Int:
        """Call a field resolver; its `Error` becomes a `GraphQLError`."""
        try:
            if resolver < 0:
                return self.resolvers[].default_field(
                    self.values, source, args, info
                )
            return self.resolvers[].field_functions[resolver](
                self.values, source, args, info
            )
        except e:
            raise GraphQLError(String(e))

    # --- completion -----------------------------------------------------

    def _complete_value(
        mut self,
        type: TypeRef,
        group: Int,
        parent: Int,
        field: Int,
        result: Int,
    ) raises GraphQLError -> Int:
        """Return graphql-js `completeValue`."""
        var kind = self.values.kind(result)
        if kind == ValueKind.ERROR:
            raise GraphQLError(String(self.values.string(result)))
        if type.is_non_null():
            var completed = self._complete_value(
                type.of_type(), group, parent, field, result
            )
            if self.data.kind(completed) == JsonKind.NULL:
                raise GraphQLError(
                    "Cannot return null for non-nullable field "
                    + self.schema[].types[parent].name
                    + "."
                    + self._field_name(field)
                    + "."
                )
            return completed
        if kind == ValueKind.UNDEFINED or kind == ValueKind.NULL:
            return self.data.add_null()
        if type.is_list():
            return self._complete_list(type, group, parent, field, result)
        var named = Int(type.named)
        var named_kind = self.schema[].types[named].kind
        if named_kind.is_leaf():
            return self._serialize(named, result)
        if named_kind.is_abstract():
            return self._complete_abstract(named, group, parent, field, result)
        return self._complete_object(named, group, parent, field, result)

    def _complete_list(
        mut self,
        type: TypeRef,
        group: Int,
        parent: Int,
        field: Int,
        result: Int,
    ) raises GraphQLError -> Int:
        """Return graphql-js `completeListValue`."""
        if self.values.kind(result) != ValueKind.LIST:
            raise GraphQLError(
                'Expected Iterable, but did not find one for field "'
                + self.schema[].types[parent].name
                + "."
                + self._field_name(field)
                + '".'
            )
        var item_type = type.of_type()
        var list = self.data.add_array()
        var item = self.values.first(result)
        var index = 0
        while item != UNDEFINED:
            self.path.append(Int32(-index - 1))
            var depth = len(self.path)
            var completed: Int
            try:
                completed = self._complete_value(
                    item_type, group, parent, field, item
                )
            except e:
                completed = self._handle_error(e^, group, item_type, depth)
            _ = self.path.pop()
            self.data.append(list, completed)
            item = self.values.next(item)
            index += 1
        return list

    def _serialize(mut self, type: Int, result: Int) raises GraphQLError -> Int:
        """Return graphql-js `completeLeafValue`: the `serialize` of a
        scalar or an enum type."""
        ref named = self.schema[].types[type]
        var kind = self.values.kind(result)
        if named.kind == TypeKind.ENUM:
            if (
                kind == ValueKind.STRING
                and self.schema[].enum_value_named(
                    type, self.values.string(result)
                )
                != NO_TYPE
            ):
                return self.data.add_string(self.values.string(result))
            raise GraphQLError(
                'Enum "'
                + named.name
                + '" cannot represent value: '
                + inspect(self.values, result)
            )
        var scalar = scalar_kind(self.schema[], type)
        if scalar == ScalarKind.CUSTOM:
            return self._json_copy(result)
        var is_number = kind == ValueKind.NUMBER
        var number = self.values.number(result) if is_number else Float64(0)
        var finite = is_number and number - number == 0
        if scalar == ScalarKind.STRING:
            if kind == ValueKind.STRING:
                return self.data.add_string(self.values.string(result))
            if kind == ValueKind.BOOLEAN:
                return self.data.add_string(
                    "true" if self.values.bool_value(result) else "false"
                )
            if finite:
                return self.data.add_string(js_number_to_string(number))
            raise GraphQLError(
                "String cannot represent value: " + inspect(self.values, result)
            )
        if scalar == ScalarKind.BOOLEAN:
            if kind == ValueKind.BOOLEAN:
                return self.data.add_bool(self.values.bool_value(result))
            if finite:
                return self.data.add_bool(number != 0)
            raise GraphQLError(
                "Boolean cannot represent a non boolean value: "
                + inspect(self.values, result)
            )
        if scalar == ScalarKind.ID:
            if kind == ValueKind.STRING:
                return self.data.add_string(self.values.string(result))
            if is_number and is_integer(number):
                return self.data.add_string(js_number_to_string(number))
            raise GraphQLError(
                "ID cannot represent value: " + inspect(self.values, result)
            )
        number = _to_number(self.values, result)
        if scalar == ScalarKind.FLOAT:
            if number - number != 0:
                raise GraphQLError(
                    "Float cannot represent non numeric value: "
                    + inspect(self.values, result)
                )
            return self.data.add_float(number)
        if not is_integer(number):
            raise GraphQLError(
                "Int cannot represent non-integer value: "
                + inspect(self.values, result)
            )
        if number > MAX_INT or number < MIN_INT:
            raise GraphQLError(
                "Int cannot represent non 32-bit signed integer value: "
                + inspect(self.values, result)
            )
        return self.data.add_int(Int64(number))

    def _json_copy(mut self, value: Int) -> Int:
        """Return a value as `JSON.stringify` writes it: the result of a
        custom scalar, which serializes as the identity."""
        var kind = self.values.kind(value)
        if kind == ValueKind.BOOLEAN:
            return self.data.add_bool(self.values.bool_value(value))
        if kind == ValueKind.NUMBER:
            return self.data.add_float(self.values.number(value))
        if kind == ValueKind.STRING:
            return self.data.add_string(self.values.string(value))
        if kind == ValueKind.LIST:
            var list = self.data.add_array()
            var item = self.values.first(value)
            while item != UNDEFINED:
                var copied = self._json_item(item)
                self.data.append(list, copied)
                item = self.values.next(item)
            return list
        if kind.value < ValueKind.BOOLEAN.value:
            return self.data.add_null()
        var object = self.data.add_object()
        var member = (
            self.values.first(value) if kind == ValueKind.OBJECT else UNDEFINED
        )
        while member != UNDEFINED:
            if self.values.kind(member) != ValueKind.UNDEFINED:
                var copied = self._json_item(member)
                self.data.add_member(object, self.values.key(member), copied)
            member = self.values.next(member)
        return object

    def _json_item(mut self, value: Int) -> Int:
        """Copy a nested value; mutual recursion with `_json_copy`."""
        return self._json_copy(value)

    def _complete_abstract(
        mut self,
        type: Int,
        group: Int,
        parent: Int,
        field: Int,
        result: Int,
    ) raises GraphQLError -> Int:
        """Return graphql-js `completeAbstractValue`."""
        var info = self._info(parent, field, group, self._return_type(field))
        var runtime = self._resolve_type(type, result, info)
        var object = self._runtime_type(type, runtime, parent, field, result)
        return self._complete_object(object, group, parent, field, result)

    def _resolve_type(
        mut self, type: Int, value: Int, info: ResolveInfo
    ) raises GraphQLError -> Int:
        """Call the type resolver of an abstract type, or graphql-js
        `defaultTypeResolver`."""
        var resolver = _slot(self.type_resolvers, type)
        try:
            if resolver >= 0:
                return self.resolvers[].type_functions[resolver](
                    self.values, value, info, type
                )
            if len(self.resolvers[].default_type) > 0:
                return self.resolvers[].default_type[0](
                    self.values, value, info, type
                )
            var name = self.values.get(value, "__typename")
            if self.values.kind(name) == ValueKind.STRING:
                return name
            for possible in self.schema[].possible_types(type):
                var check = _slot(self.type_checks, possible)
                if check >= 0 and self.resolvers[].object_functions[check](
                    self.values, value, info
                ):
                    return self.values.add_string(
                        self.schema[].types[possible].name
                    )
            return UNDEFINED
        except e:
            raise GraphQLError(String(e))

    def _runtime_type(
        mut self,
        type: Int,
        runtime: Int,
        parent: Int,
        field: Int,
        result: Int,
    ) raises GraphQLError -> Int:
        """Return graphql-js `ensureValidRuntimeType`."""
        ref schema = self.schema[]
        ref name = schema.types[type].name
        var at = schema.types[parent].name + "." + self._field_name(field)
        var kind = self.values.kind(runtime)
        if kind == ValueKind.UNDEFINED or kind == ValueKind.NULL:
            raise GraphQLError(
                'Abstract type "'
                + name
                + '" must resolve to an Object type at runtime for field "'
                + at
                + '". Either the "'
                + name
                + '" type should provide a "resolveType" function or each'
                ' possible type should provide an "isTypeOf" function.'
            )
        if kind != ValueKind.STRING:
            raise GraphQLError(
                'Abstract type "'
                + name
                + '" must resolve to an Object type at runtime for field "'
                + at
                + '" with value '
                + inspect(self.values, result)
                + ', received "'
                + inspect(self.values, runtime)
                + '".'
            )
        var runtime_name = String(self.values.string(runtime))
        var object = schema.type_named(runtime_name)
        if object == NO_TYPE:
            raise GraphQLError(
                'Abstract type "'
                + name
                + '" was resolved to a type "'
                + runtime_name
                + '" that does not exist inside the schema.'
            )
        if schema.types[object].kind != TypeKind.OBJECT:
            raise GraphQLError(
                'Abstract type "'
                + name
                + '" was resolved to a non-object type "'
                + runtime_name
                + '".'
            )
        if not schema.is_sub_type(type, object):
            raise GraphQLError(
                'Runtime Object type "'
                + runtime_name
                + '" is not a possible type for "'
                + name
                + '".'
            )
        return object

    def _complete_object(
        mut self, type: Int, group: Int, parent: Int, field: Int, result: Int
    ) raises GraphQLError -> Int:
        """Return graphql-js `completeObjectValue`."""
        var plan = self._subfields(type, group)
        var check = _slot(self.type_checks, type)
        if check >= 0:
            var info = self._info(
                parent, field, group, self._return_type(field)
            )
            var matches: Bool
            try:
                matches = self.resolvers[].object_functions[check](
                    self.values, result, info
                )
            except e:
                raise GraphQLError(String(e))
            if not matches:
                raise GraphQLError(
                    'Expected value of type "'
                    + self.schema[].types[type].name
                    + '" but got: '
                    + inspect(self.values, result)
                    + "."
                )
        return self.execute_fields(type, _Source.value(result), plan)

    # --- meta fields and introspection ----------------------------------

    def _meta_field(
        mut self, parent: Int, group: Int, field: Int
    ) raises GraphQLError -> Int:
        """Resolve and complete `__typename`, `__schema` or `__type`."""
        if field == META_TYPENAME:
            return self.data.add_string(self.schema[].types[parent].name)
        if field == META_SCHEMA:
            return self._intro_object(
                0, group, _Source(Int32(TAG_SCHEMA), 0, 0, 0)
            )
        var node = self.collector.node(Int(self.collector.group(group).start))
        var args = self.values.add_object()
        coerce_argument(
            self.schema[],
            String("name"),
            TypeRef.of(self.string_type).non_null(),
            NO_TYPE,
            self.document[],
            node,
            self.values,
            self.variables,
            args,
        )
        var name = self.values.get(args, "name")
        var type = self.schema[].type_named(self.values.string(name))
        if type == NO_TYPE:
            return self.data.add_null()
        return self._intro_object(1, group, _Source.type(TypeRef.of(type)))

    def _intro_object(
        mut self, which: Int, group: Int, source: _Source
    ) raises GraphQLError -> Int:
        """Complete an introspection object of one of the six types."""
        var type = self.intro_types[which]
        var plan = self._subfields(type, group)
        return self.execute_fields(type, source, plan)

    def _intro_item(
        mut self, list: Int, which: Int, group: Int, index: Int, source: _Source
    ) raises GraphQLError:
        """Complete an item of an introspection list; an error gets the
        item's path, as graphql-js `completeListValue` gives it."""
        self.path.append(Int32(-index - 1))
        var depth = len(self.path)
        var item: Int
        try:
            item = self._intro_object(which, group, source)
        except e:
            raise self._locate(e^, group, depth)
        _ = self.path.pop()
        self.data.append(list, item)

    def _intro_type_or_null(
        mut self, type: Int, group: Int
    ) raises GraphQLError -> Int:
        """Complete a root type: a `__Type`, or `null` for none."""
        if type == NO_TYPE:
            return self.data.add_null()
        return self._intro_object(1, group, _Source.type(TypeRef.of(type)))

    def _intro_field_code(mut self, parent: Int, field: Int) -> Int:
        """Return the introspection resolver code of a field of an
        introspection type."""
        if len(self.intro_codes) == 0:
            self._index_introspection_codes()
        var which = 0
        while self.intro_types[which] != parent:
            which += 1
        return Int(self.intro_codes[self.intro_starts[which] + field])

    def _include_deprecated(
        mut self, group: Int, field: Int
    ) raises GraphQLError -> Bool:
        """Return the `includeDeprecated` argument of an introspection
        field; the coerced arguments are kept per group."""
        var args = Int(self.cache[group].args)
        if args == _UNKNOWN:
            var node = self.collector.node(
                Int(self.collector.group(group).start)
            )
            args = get_argument_values(
                self.schema[],
                ArgumentOwner.FIELD,
                field,
                self.document[],
                node,
                self.values,
                self.variables,
            )
            self.cache[group].args = Int32(args)
        var flag = self.values.get(args, "includeDeprecated")
        return self.values.kind(
            flag
        ) == ValueKind.BOOLEAN and self.values.bool_value(flag)

    def _text_or_null(mut self, present: Bool, text: StringSlice) -> Int:
        """Return a string, or `null`."""
        if present:
            return self.data.add_string(text)
        return self.data.add_null()

    def _description(mut self, at: AstRef) -> Int:
        """Return a decoded description, or `null`."""
        if not at.exists():
            return self.data.add_null()
        return self.data.add_string(self.schema[].description_text(at))

    def _introspect(
        mut self, code: Int, source: _Source, group: Int, field: Int
    ) raises GraphQLError -> Int:
        """Resolve and complete a field of an introspection type, as the
        resolvers of graphql-js `type/introspection.ts`."""
        if code < 20:
            return self._intro_schema(code, group, field)
        if code < 40:
            return self._intro_type(code, source.type_ref(), group, field)
        if code < 60:
            return self._intro_field(code, source.id, group, field)
        if code < 80:
            return self._intro_input_value(code, source.id, group)
        if code < 100:
            return self._intro_enum_value(code, source.id)
        return self._intro_directive(code, source.id, group, field)

    def _intro_schema(
        mut self, code: Int, group: Int, field: Int
    ) raises GraphQLError -> Int:
        """Resolve a field of `__Schema`."""
        ref schema = self.schema[]
        if code == 1:
            return self._description(schema.description)
        if code == 2:
            var list = self.data.add_array()
            var index = 0
            while index < len(schema.type_map):
                var type = Int(schema.type_map[index])
                self._intro_item(
                    list, 1, group, index, _Source.type(TypeRef.of(type))
                )
                index += 1
            return list
        if code == 3:
            return self._intro_type_or_null(Int(schema.query_type), group)
        if code == 4:
            return self._intro_type_or_null(Int(schema.mutation_type), group)
        if code == 5:
            return self._intro_type_or_null(
                Int(schema.subscription_type), group
            )
        var include = self._include_deprecated(group, field)
        var list = self.data.add_array()
        var position = 0
        var index = 0
        while index < len(schema.directives):
            if include or not schema.directives[index].is_deprecated:
                self._intro_item(
                    list,
                    5,
                    group,
                    position,
                    _Source(Int32(TAG_DIRECTIVE), index, 0, 0),
                )
                position += 1
            index += 1
        return list

    def _intro_type(
        mut self, code: Int, type: TypeRef, group: Int, field: Int
    ) raises GraphQLError -> Int:
        """Resolve a field of `__Type`."""
        ref schema = self.schema[]
        var wrapped = type.is_wrapped()
        ref named = schema.types[Int(type.named)]
        if code == 21:
            if not wrapped:
                return self.data.add_string(named.kind.text())
            return self.data.add_string(
                "NON_NULL" if type.is_non_null() else "LIST"
            )
        if code == 30:
            if not wrapped:
                return self.data.add_null()
            return self._intro_object(1, group, _Source.type(type.of_type()))
        if wrapped:
            return self.data.add_null()
        if code == 22:
            return self.data.add_string(named.name)
        if code == 23:
            return self._description(named.description)
        if code == 24:
            return self._text_or_null(
                named.kind == TypeKind.SCALAR and named.has_specified_by_url,
                named.specified_by_url,
            )
        if code == 26 or code == 27:
            var is_interfaces = code == 26
            if is_interfaces and not named.kind.has_fields():
                return self.data.add_null()
            if not is_interfaces and not named.kind.is_abstract():
                return self.data.add_null()
            var types: List[Int]
            if is_interfaces:
                types = schema.interfaces_of(Int(type.named))
            else:
                types = schema.possible_types(Int(type.named))
            var list = self.data.add_array()
            var index = 0
            while index < len(types):
                self._intro_item(
                    list,
                    1,
                    group,
                    index,
                    _Source.type(TypeRef.of(types[index])),
                )
                index += 1
            return list
        if code == 31:
            if named.kind != TypeKind.INPUT_OBJECT:
                return self.data.add_null()
            return self.data.add_bool(named.is_one_of)
        return self._intro_members(
            code, named.kind, Int(type.named), group, field
        )

    def _intro_members(
        mut self, code: Int, kind: TypeKind, type: Int, group: Int, field: Int
    ) raises GraphQLError -> Int:
        """Resolve `fields`, `enumValues` or `inputFields` of `__Type`."""
        ref schema = self.schema[]
        ref named = schema.types[type]
        var which: Int
        var tag: Int
        var span: Range
        if code == 25:
            if not kind.has_fields():
                return self.data.add_null()
            which = 2
            tag = TAG_FIELD
            span = named.fields
        elif code == 28:
            if kind != TypeKind.ENUM:
                return self.data.add_null()
            which = 4
            tag = TAG_ENUM_VALUE
            span = named.enum_values
        else:
            if kind != TypeKind.INPUT_OBJECT:
                return self.data.add_null()
            which = 3
            tag = TAG_INPUT_VALUE
            span = named.input_fields
        var include = self._include_deprecated(group, field)
        var list = self.data.add_array()
        var position = 0
        var index = Int(span.start)
        while index < span.end():
            var deprecated: Bool
            if which == 2:
                deprecated = schema.fields[index].is_deprecated
            elif which == 4:
                deprecated = schema.enum_values[index].is_deprecated
            else:
                deprecated = schema.input_values[index].is_deprecated
            if include or not deprecated:
                self._intro_item(
                    list,
                    which,
                    group,
                    position,
                    _Source(Int32(tag), index, 0, 0),
                )
                position += 1
            index += 1
        return list

    def _intro_args(
        mut self, span: Range, group: Int, field: Int
    ) raises GraphQLError -> Int:
        """Resolve `args` of `__Field` or `__Directive`."""
        var include = self._include_deprecated(group, field)
        var list = self.data.add_array()
        var position = 0
        var index = Int(span.start)
        while index < span.end():
            if include or not self.schema[].input_values[index].is_deprecated:
                self._intro_item(
                    list,
                    3,
                    group,
                    position,
                    _Source(Int32(TAG_INPUT_VALUE), index, 0, 0),
                )
                position += 1
            index += 1
        return list

    def _intro_field(
        mut self, code: Int, index: Int, group: Int, field: Int
    ) raises GraphQLError -> Int:
        """Resolve a field of `__Field`."""
        ref definition = self.schema[].fields[index]
        if code == 41:
            return self.data.add_string(definition.name)
        if code == 42:
            return self._description(definition.description)
        if code == 43:
            return self._intro_args(definition.arguments, group, field)
        if code == 44:
            return self._intro_object(1, group, _Source.type(definition.type))
        if code == 45:
            return self.data.add_bool(definition.is_deprecated)
        return self._text_or_null(
            definition.is_deprecated, definition.deprecation_reason
        )

    def _intro_input_value(
        mut self, code: Int, index: Int, group: Int
    ) raises GraphQLError -> Int:
        """Resolve a field of `__InputValue`."""
        ref definition = self.schema[].input_values[index]
        if code == 61:
            return self.data.add_string(definition.name)
        if code == 62:
            return self._description(definition.description)
        if code == 63:
            return self._intro_object(1, group, _Source.type(definition.type))
        if code == 64:
            var printed: Optional[String]
            try:
                printed = print_default(self.schema[], index)
            except e:
                raise GraphQLError(String(e))
            if printed:
                return self.data.add_string(printed.value())
            return self.data.add_null()
        if code == 65:
            return self.data.add_bool(definition.is_deprecated)
        return self._text_or_null(
            definition.is_deprecated, definition.deprecation_reason
        )

    def _intro_enum_value(mut self, code: Int, index: Int) -> Int:
        """Resolve a field of `__EnumValue`."""
        ref definition = self.schema[].enum_values[index]
        if code == 81:
            return self.data.add_string(definition.name)
        if code == 82:
            return self._description(definition.description)
        if code == 83:
            return self.data.add_bool(definition.is_deprecated)
        return self._text_or_null(
            definition.is_deprecated, definition.deprecation_reason
        )

    def _intro_directive(
        mut self, code: Int, index: Int, group: Int, field: Int
    ) raises GraphQLError -> Int:
        """Resolve a field of `__Directive`."""
        ref definition = self.schema[].directives[index]
        if code == 101:
            return self.data.add_string(definition.name)
        if code == 102:
            return self._description(definition.description)
        if code == 103:
            return self.data.add_bool(definition.is_repeatable)
        if code == 104:
            var list = self.data.add_array()
            var at = definition.definition
            ref document = self.schema[].documents[Int(at.document)]
            var location = document.child(Int(at.node), Role.LOCATION)
            while location != NO_NODE:
                var text = self.data.add_string(document.text(location))
                self.data.append(list, text)
                location = document.next_with_role(location)
            return list
        if code == 105:
            return self._intro_args(definition.arguments, group, field)
        if code == 106:
            return self.data.add_bool(definition.is_deprecated)
        return self._text_or_null(
            definition.is_deprecated, definition.deprecation_reason
        )

    # --- the operation --------------------------------------------------

    def run(
        mut self,
        operation_name: Optional[String],
        root_value: Int,
        context_value: Int,
        variable_values: Int,
        max_errors: Int,
    ) raises -> ExecutionResult:
        """Return graphql-js `execute` after the argument checks."""
        var early = self.prepare(operation_name, variable_values, max_errors)
        if early:
            return early.take()
        self.root_value = root_value
        self.context_value = context_value
        try:
            self.data.root = self._execute_operation(self.operation)
        except e:
            self.errors.append(e^)
            self.data.root = self.data.add_null()
        var data = JsonDocument()
        swap(data, self.data)
        var errors = List[GraphQLError]()
        swap(errors, self.errors)
        var result = ExecutionResult(data^, errors^)
        swap(result.field_timings, self.field_timings)
        return result^

    def prepare(
        mut self,
        operation_name: Optional[String],
        variable_values: Int,
        max_errors: Int,
    ) raises -> Optional[ExecutionResult]:
        """Return the errors of graphql-js `buildExecutionContext`, or None
        after it set the operation and the coerced variables."""
        ref document = self.document[]
        var operation = NO_NODE
        var definition = document.child(document.root, Role.DEFINITION)
        while definition != NO_NODE:
            if document.kind(definition) == Kind.OPERATION_DEFINITION:
                if not operation_name:
                    if operation != NO_NODE:
                        return self._only_errors(
                            GraphQLError(
                                "Must provide operation name if query"
                                " contains multiple operations."
                            )
                        )
                    operation = definition
                elif (
                    document.child(definition, Role.NAME) != NO_NODE
                    and document.name(definition) == operation_name.value()
                ):
                    operation = definition
            definition = document.next_with_role(definition)
        if operation == NO_NODE:
            if operation_name:
                return self._only_errors(
                    GraphQLError(
                        'Unknown operation named "'
                        + operation_name.value()
                        + '".'
                    )
                )
            return self._only_errors(GraphQLError("Must provide an operation."))
        var inputs = variable_values
        if self.values.is_nullish(inputs):
            inputs = UNDEFINED
        var coerced = get_variable_values(
            self.schema[],
            document,
            operation,
            self.values,
            inputs,
            max_errors,
        )
        if len(coerced.errors) > 0:
            var data = JsonDocument()
            data.root = NO_JSON
            var errors = List[GraphQLError]()
            swap(errors, coerced.errors)
            return ExecutionResult(data^, errors^)
        self.variables = coerced.coerced
        self.operation = operation
        return None

    def execute_subscription(
        mut self, root_value: Int, context_value: Int
    ) raises GraphQLError -> Int:
        """Return graphql-js `executeSubscription` after `prepare`: the
        value that the `subscribe` function of the first root field
        returns. Its errors are located at the field."""
        ref document = self.document[]
        self.root_value = root_value
        self.context_value = context_value
        var operation = self.operation
        var root = self.schema[].root_type(OperationType.SUBSCRIPTION.value)
        if root == NO_TYPE:
            raise GraphQLError(
                "Schema is not configured to execute subscription operation.",
                document.source,
                [document.start(operation)],
            )
        var plan = self.collector.collect_fields(
            self.schema[],
            document,
            self.values,
            self.variables,
            root,
            document.child(operation, Role.SELECTION_SET),
        )
        self._sync_groups()
        var group = Int(self.collector.plan(plan).start)
        var field = self._field_def(root, group)
        if field == NO_TYPE or field < 0:
            var node = self.collector.node(
                Int(self.collector.group(group).start)
            )
            raise self._locate(
                GraphQLError(
                    'The subscription field "'
                    + String(document.name(node))
                    + '" is not defined.'
                ),
                group,
                0,
            )
        var type = self._return_type(field)
        self.path.append(Int32(group))
        try:
            var node = self.collector.node(
                Int(self.collector.group(group).start)
            )
            var args = get_argument_values(
                self.schema[],
                ArgumentOwner.FIELD,
                field,
                document,
                node,
                self.values,
                self.variables,
            )
            var info = self._info(root, field, group, type)
            var resolve = self.resolvers[].subscribe_function(
                self.schema[].types[root].name, info.field_name
            )
            var stream: Int
            try:
                stream = resolve(self.values, root_value, args, info)
            except e:
                raise GraphQLError(String(e))
            if self.values.kind(stream) == ValueKind.ERROR:
                raise GraphQLError(String(self.values.string(stream)))
            return stream
        except e:
            raise self._locate(e^, group, 1)

    def _only_errors(self, var error: GraphQLError) -> ExecutionResult:
        """Return a result with one error and no `data` key."""
        var data = JsonDocument()
        data.root = NO_JSON
        var errors = List[GraphQLError]()
        errors.append(error^)
        return ExecutionResult(data^, errors^)

    def _execute_operation(mut self, operation: Int) raises GraphQLError -> Int:
        """Return graphql-js `executeOperation`."""
        ref document = self.document[]
        var type = document.operation(operation)
        var root = self.schema[].root_type(type.value)
        if root == NO_TYPE:
            raise GraphQLError(
                "Schema is not configured to execute "
                + String(type.text())
                + " operation.",
                document.source,
                [document.start(operation)],
            )
        var plan = self.collector.collect_fields(
            self.schema[],
            document,
            self.values,
            self.variables,
            root,
            document.child(operation, Role.SELECTION_SET),
        )
        self._sync_groups()
        return self.execute_fields(root, _Source.value(self.root_value), plan)


def execute(
    schema: Schema, document: Document, mut args: ExecutionArgs
) raises -> ExecutionResult:
    """Execute an operation of a document, as graphql-js `executeSync`.

    Args:
        schema: The schema.
        document: The document; execution does not validate it.
        args: The root value, the context, the variables, the operation
            name, the resolvers and the options, with their arena. The
            values that the resolvers add stay in `args.values`.

    Returns:
        The result: the data and the errors.

    Raises:
        Error: The graphql-js `assertValidSchema` error, unless
            `args.assume_valid_schema` is set; or `Variables must be
            provided as an Object where each property is a variable
            value. Perhaps look to see if an unparsed JSON string was
            provided.` for variable values that are not an object.
    """
    var resolvers = Resolvers()
    swap(resolvers, args.resolvers)
    var result: ExecutionResult
    try:
        result = execute_with_resolvers(schema, document, resolvers, args)
    except e:
        swap(resolvers, args.resolvers)
        raise e^
    swap(resolvers, args.resolvers)
    return result^


def execute_with_resolvers(
    schema: Schema,
    document: Document,
    resolvers: Resolvers,
    mut args: ExecutionArgs,
) raises -> ExecutionResult:
    """Execute an operation with resolvers that the caller keeps, as
    `execute` does with `args.resolvers`. A program that runs many
    operations with one set of resolvers does not copy them for each.

    Args:
        schema: The schema.
        document: The document; execution does not validate it.
        resolvers: The resolvers; `args.resolvers` is not read.
        args: The other inputs, as `execute` takes them.

    Returns:
        The result: the data and the errors.

    Raises:
        Error: As `execute` raises.
    """
    if not args.assume_valid_schema:
        assert_valid_schema(schema)
    var kind = args.values.kind(args.variable_values)
    if kind.value > ValueKind.NULL.value and kind.value < ValueKind.LIST.value:
        raise Error(
            "Variables must be provided as an Object where each property is"
            " a variable value. Perhaps look to see if an unparsed JSON"
            " string was provided."
        )
    var values = Values(capacity=0)
    swap(values, args.values)
    var executor = _Executor(schema, document, resolvers, values^)
    executor.custom_default = resolvers.has_default_field
    executor.field_timing = args.field_timing
    var result: ExecutionResult
    try:
        result = executor.run(
            args.operation_name,
            args.root_value,
            args.context_value,
            args.variable_values,
            args.max_coercion_errors,
        )
    except e:
        swap(args.values, executor.values)
        raise e^
    swap(args.values, executor.values)
    return result^


def assert_valid_execution_arguments(
    schema: Schema, args: ExecutionArgs
) raises:
    """Raise as graphql-js `assertValidExecutionArguments` throws.

    Args:
        schema: The schema; validated unless `args.assume_valid_schema`.
        args: The inputs; `variable_values` must be an object or nullish.

    Raises:
        Error: The `assertValidSchema` error, or the error of variable
            values that are not an object.
    """
    if not args.assume_valid_schema:
        assert_valid_schema(schema)
    var kind = args.values.kind(args.variable_values)
    if kind.value > ValueKind.NULL.value and kind.value < ValueKind.LIST.value:
        raise Error(
            "Variables must be provided as an Object where each property is"
            " a variable value. Perhaps look to see if an unparsed JSON"
            " string was provided."
        )


def resolve_source_event(
    schema: Schema,
    document: Document,
    resolvers: Resolvers,
    mut args: ExecutionArgs,
    mut errors: List[GraphQLError],
) raises -> Int:
    """Run graphql-js `buildExecutionContext` and `executeSubscription`:
    call the `subscribe` function of the first root field.

    `gql_execution.subscribe` builds `createSourceEventStream` on it.

    Args:
        schema: The schema.
        document: The document.
        resolvers: The resolvers; `args.resolvers` is not read.
        args: The other inputs; the value stays in `args.values`.
        errors: Gets the errors of the operation, of the variables, or of
            `subscribe`, each located at the field.

    Returns:
        What `subscribe` returned, or `UNDEFINED` when `errors` is not
        empty.

    Raises:
        Error: As `assert_valid_execution_arguments` raises.
    """
    assert_valid_execution_arguments(schema, args)
    var values = Values(capacity=0)
    swap(values, args.values)
    var executor = _Executor(schema, document, resolvers, values^)
    var value = UNDEFINED
    var early: Optional[ExecutionResult]
    try:
        early = executor.prepare(
            args.operation_name, args.variable_values, args.max_coercion_errors
        )
    except e:
        swap(args.values, executor.values)
        raise e^
    if early:
        swap(errors, early.value().errors)
    else:
        try:
            value = executor.execute_subscription(
                args.root_value, args.context_value
            )
        except e:
            errors.append(e^)
    swap(args.values, executor.values)
    return value


def execute(schema: Schema, document: Document) raises -> ExecutionResult:
    """Execute a document with no root value, variables or resolvers.

    Args:
        schema: The schema.
        document: The document.

    Returns:
        The result.

    Raises:
        Error: As `execute` raises.
    """
    var args = ExecutionArgs()
    return execute(schema, document, args)


def execute_sync(
    schema: Schema, document: Document, mut args: ExecutionArgs
) raises -> ExecutionResult:
    """Execute an operation, as graphql-js `executeSync`. Execution is
    always synchronous, so this is `execute`.

    Args:
        schema: The schema.
        document: The document.
        args: As `execute` takes them.

    Returns:
        The result.

    Raises:
        Error: As `execute` raises.
    """
    return execute(schema, document, args)


def _to_number(values: Values, value: Int) -> Float64:
    """Return the number that `Int` and `Float` serialize: a boolean is 1
    or 0, a nonempty string is `Number(string)`, and any other value that
    is not a number is NaN."""
    var kind = values.kind(value)
    if kind == ValueKind.NUMBER:
        return values.number(value)
    if kind == ValueKind.BOOLEAN:
        return 1 if values.bool_value(value) else 0
    if kind == ValueKind.STRING and values.string(value).byte_length() > 0:
        return js_number(values.string(value))
    return nan[DType.float64]()


def _is_js_space(bytes: Span[UInt8, _], at: Int) -> Int:
    """Return the length of the ECMAScript white space or line terminator
    at a position, or 0."""
    var byte = bytes[at]
    if byte == 32 or (byte >= 9 and byte <= 13):
        return 1
    var rest = len(bytes) - at
    if byte == 0xC2 and bytes[at + 1] == 0xA0:
        return 2
    if rest < 3:
        return 0
    var code = (
        (Int(byte) << 16) | (Int(bytes[at + 1]) << 8) | Int(bytes[at + 2])
    )
    if (
        code == 0xE19A80
        or (code >= 0xE28080 and code <= 0xE2808A)
        or code == 0xE280A8
        or code == 0xE280A9
        or code == 0xE280AF
        or code == 0xE2819F
        or code == 0xE38080
        or code == 0xEFBBBF
    ):
        return 3
    return 0


def js_number(text: StringSlice) -> Float64:
    """Convert a string to a number, as ECMAScript `Number(string)`.

    Args:
        text: The string.

    Returns:
        The number: 0 for white space only, `Infinity` for `Infinity`, the
        value of a decimal, `0x`, `0o` or `0b` literal, and NaN for any
        other text.
    """
    var bytes = text.as_bytes()
    var start = 0
    var end = len(bytes)
    while start < end:
        var width = _is_js_space(bytes, start)
        if width == 0:
            break
        start += width
    while end > start:
        var back = end - 1
        while back > start and bytes[back] & 0xC0 == 0x80:
            back -= 1
        if _is_js_space(bytes, back) == 0:
            break
        end = back
    if start == end:
        return 0
    var body = StringSlice(unsafe_from_utf8=bytes[start:end])
    if body == "Infinity" or body == "+Infinity":
        return inf[DType.float64]()
    if body == "-Infinity":
        return -inf[DType.float64]()
    var digits = body.as_bytes()
    if len(digits) > 2 and digits[0] == 48:
        var radix_letter = digits[1] | 0x20
        var radix = 0
        if radix_letter == 120:
            radix = 16
        elif radix_letter == 111:
            radix = 8
        elif radix_letter == 98:
            radix = 2
        if radix > 0:
            return _radix_number(digits[2:], radix)
    return _decimal_number(digits)


def _radix_number(digits: Span[UInt8, _], radix: Int) -> Float64:
    """Return the value of `0x`, `0o` or `0b` digits, or NaN."""
    var value: Float64 = 0
    var index = 0
    while index < len(digits):
        var byte = digits[index]
        index += 1
        var digit = 99
        if byte >= 48 and byte <= 57:
            digit = Int(byte) - 48
        elif (byte | 0x20) >= 97 and (byte | 0x20) <= 102:
            digit = Int(byte | 0x20) - 87
        if digit >= radix:
            return nan[DType.float64]()
        value = value * Float64(radix) + Float64(digit)
    return value


def _decimal_number(text: Span[UInt8, _]) -> Float64:
    """Return the value of an ECMAScript `StrDecimalLiteral`, or NaN."""
    var size = len(text)
    var index = 0
    var out = List[UInt8](capacity=size + 2)
    if text[0] == 45 or text[0] == 43:
        if text[0] == 45:
            out.append(45)
        index = 1
    var int_start = index
    while index < size and text[index] >= 48 and text[index] <= 57:
        index += 1
    var int_end = index
    var frac_start = index
    var frac_end = index
    if index < size and text[index] == 46:
        index += 1
        frac_start = index
        while index < size and text[index] >= 48 and text[index] <= 57:
            index += 1
        frac_end = index
    if int_end == int_start and frac_end == frac_start:
        return nan[DType.float64]()
    var lead = int_start
    while lead < int_end - 1 and text[lead] == 48:
        lead += 1
    if lead == int_end:
        out.append(48)
    else:
        out.extend(text[lead:int_end])
    if frac_end > frac_start:
        out.append(46)
        out.extend(text[frac_start:frac_end])
    if index < size and (text[index] | 0x20) == 101:
        out.append(101)
        index += 1
        if index < size and (text[index] == 43 or text[index] == 45):
            out.append(text[index])
            index += 1
        var exponent_start = index
        while index < size and text[index] >= 48 and text[index] <= 57:
            out.append(text[index])
            index += 1
        if index == exponent_start:
            return nan[DType.float64]()
    if index != size:
        return nan[DType.float64]()
    return read_float64(Span(out))


comptime _CODES = (
    "description types queryType mutationType subscriptionType directives|"
    "kind name description specifiedByURL fields interfaces possibleTypes"
    " enumValues inputFields ofType isOneOf|"
    "name description args type isDeprecated deprecationReason|"
    "name description type defaultValue isDeprecated deprecationReason|"
    "name description isDeprecated deprecationReason|"
    "name description isRepeatable locations args isDeprecated"
    " deprecationReason"
)
"""The fields of the six introspection types, in the order of `_intro_code`:
type `t` field `f` (from 0) has code `20 * t + f + 1`."""


def _slot(table: List[Int32], index: Int) -> Int:
    """Return the resolver of a field or a type from a table of the
    executor, or -1 when the table is empty: there are no resolvers of
    that kind."""
    if len(table) == 0:
        return -1
    return Int(table.unsafe_ptr()[unsafe_offset=index])


def _intro_code(which: Int, name: StringSlice) -> Int:
    """Return the resolver code of a field of an introspection type: `20 *
    which + position + 1`. Every field of the six types is in `_CODES`: an
    extension of an introspection type does not change the built-in type.
    """
    var words = StringSlice(_CODES).split("|")[which].split(" ")
    var position = 0
    while words[position] != name:
        position += 1
    return 20 * which + position + 1

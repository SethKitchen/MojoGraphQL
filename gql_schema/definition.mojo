# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The GraphQL type system: a schema, its named types, fields, arguments,
enum values and directives.

Port of the data model of graphql-js 16.14.2 `type/definition.ts`,
`type/directives.ts` and `type/schema.ts`.

**Arenas, not objects.** A `Schema` keeps each kind of element in one list:
`types`, `fields`, `input_values` (arguments and input fields), `enum_values`
and `directives`. A type names its fields as a range of `fields`, a field
names its arguments as a range of `input_values`, and so on. A type
reference is a `TypeRef`: the index of a named type and its list and
non-null wrappers, packed in two integers.

Every element can point back at the SDL it came from with an `AstRef`: an
index into `Schema.documents` and a node index. Applied directives are kept
the same way, so a federation subgraph can read `@key` and `@external`.

**Differences from graphql-js.**

- A schema holds no resolvers and no scalar coercion functions; execution
  attaches those. A custom scalar is a name, a description and a
  `specifiedByURL`.
- `extensions` (arbitrary JavaScript data) are not kept.
"""

from gql_language.ast import NO_NODE, Document
from gql_language.directive_location import DirectiveLocation
from gql_language.names import NOT_FOUND, NameTable


@fieldwise_init
struct TypeKind(Equatable, ImplicitlyCopyable, Writable):
    """The kind of a named type, as graphql-js `__TypeKind` names it."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime SCALAR = TypeKind(0)
    """A scalar type."""
    comptime OBJECT = TypeKind(1)
    """An object type."""
    comptime INTERFACE = TypeKind(2)
    """An interface type."""
    comptime UNION = TypeKind(3)
    """A union type."""
    comptime ENUM = TypeKind(4)
    """An enum type."""
    comptime INPUT_OBJECT = TypeKind(5)
    """An input object type."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the six kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 5

    def text(self) -> StaticString:
        """Return the `__TypeKind` value, such as `INPUT_OBJECT`.

        Returns:
            The name, or `<invalid>`.
        """
        if self == TypeKind.SCALAR:
            return "SCALAR"
        if self == TypeKind.OBJECT:
            return "OBJECT"
        if self == TypeKind.INTERFACE:
            return "INTERFACE"
        if self == TypeKind.UNION:
            return "UNION"
        if self == TypeKind.ENUM:
            return "ENUM"
        if self == TypeKind.INPUT_OBJECT:
            return "INPUT_OBJECT"
        return "<invalid>"

    def is_input(self) -> Bool:
        """Return True for a kind an input can have: scalar, enum, input
        object.

        Returns:
            Whether the kind is a graphql-js input type.
        """
        return (
            self == TypeKind.SCALAR
            or self == TypeKind.ENUM
            or self == TypeKind.INPUT_OBJECT
        )

    def is_output(self) -> Bool:
        """Return True for any kind but input object.

        Returns:
            Whether the kind is a graphql-js output type.
        """
        return self.is_valid() and self != TypeKind.INPUT_OBJECT

    def is_leaf(self) -> Bool:
        """Return True for a scalar or an enum.

        Returns:
            Whether the kind is a graphql-js leaf type.
        """
        return self == TypeKind.SCALAR or self == TypeKind.ENUM

    def is_composite(self) -> Bool:
        """Return True for an object, an interface or a union.

        Returns:
            Whether the kind is a graphql-js composite type.
        """
        return (
            self == TypeKind.OBJECT
            or self == TypeKind.INTERFACE
            or self == TypeKind.UNION
        )

    def is_abstract(self) -> Bool:
        """Return True for an interface or a union.

        Returns:
            Whether the kind is a graphql-js abstract type.
        """
        return self == TypeKind.INTERFACE or self == TypeKind.UNION

    def has_fields(self) -> Bool:
        """Return True for an object or an interface.

        Returns:
            Whether the type has output fields.
        """
        return self == TypeKind.OBJECT or self == TypeKind.INTERFACE

    def write_to(self, mut writer: Some[Writer]):
        """Write the `__TypeKind` value.

        Args:
            writer: The destination.
        """
        writer.write(self.text())


comptime NO_TYPE = -1
"""The index that names no type, field, value or directive."""
comptime HASHED_MEMBERS = 16
"""The member count from which an owner's members are in a name table.

A type with fewer fields, input fields or enum values, and a field or
directive with fewer arguments, is searched one member at a time: the
members are next to each other, so a short scan is faster than a hash and
costs nothing to build."""
comptime _MAX_DEPTH = 31


@fieldwise_init
struct TypeRef(Equatable, ImplicitlyCopyable, Movable):
    """A type as a field or an argument uses it: a named type, wrapped in
    lists and non-nulls.

    `bits` holds one bit per wrapper, the outermost in bit 0: 1 for a list,
    0 for a non-null. `[Int!]!` is non-null, list, non-null, `Int`: depth
    3, bits 0b010.
    """

    var named: Int32
    """The named type's index in `Schema.types`, or `NO_TYPE`."""
    var depth: UInt8
    """How many wrappers there are."""
    var bits: UInt32
    """The wrappers, the outermost in bit 0."""

    @staticmethod
    def of(named: Int) -> TypeRef:
        """Return a reference to a named type, unwrapped.

        Args:
            named: The type's index.

        Returns:
            The reference.
        """
        return TypeRef(Int32(named), 0, 0)

    def __eq__(self, other: TypeRef) -> Bool:
        """Return True if two references name the same type the same way.

        Args:
            other: The other reference.

        Returns:
            Whether the named type and every wrapper agree.
        """
        return (
            self.named == other.named
            and self.depth == other.depth
            and self.bits == other.bits
        )

    def is_wrapped(self) -> Bool:
        """Return True for a list or a non-null.

        Returns:
            Whether any wrapper is left.
        """
        return self.depth > 0

    def is_non_null(self) -> Bool:
        """Return True if the outermost wrapper is a non-null.

        Returns:
            The graphql-js `isNonNullType`.
        """
        return self.depth > 0 and self.bits & 1 == 0

    def is_list(self) -> Bool:
        """Return True if the outermost wrapper is a list.

        Returns:
            The graphql-js `isListType`.
        """
        return self.depth > 0 and self.bits & 1 == 1

    def of_type(self) -> TypeRef:
        """Return the type inside the outermost wrapper.

        Returns:
            The graphql-js `ofType`; an unwrapped reference for a named type.
        """
        if self.depth == 0:
            return self
        return TypeRef(self.named, self.depth - 1, self.bits >> 1)

    def nullable(self) -> TypeRef:
        """Return the type without an outermost non-null.

        Returns:
            The graphql-js `getNullableType`.
        """
        if self.is_non_null():
            return self.of_type()
        return self

    def list_of(self) -> TypeRef:
        """Return this type wrapped in a list.

        Returns:
            The graphql-js `new GraphQLList(type)`.
        """
        return TypeRef(self.named, self.depth + 1, (self.bits << 1) | 1)

    def non_null(self) -> TypeRef:
        """Return this type wrapped in a non-null.

        Returns:
            The graphql-js `new GraphQLNonNull(type)`.
        """
        return TypeRef(self.named, self.depth + 1, self.bits << 1)

    def unwrapped(self) -> TypeRef:
        """Return the named type with no wrapper.

        Returns:
            The graphql-js `getNamedType`, as a reference.
        """
        return TypeRef(self.named, 0, 0)


@fieldwise_init
struct AstRef(Equatable, ImplicitlyCopyable, Movable):
    """A node of one of a schema's documents."""

    var document: Int32
    """The index in `Schema.documents`, or -1."""
    var node: Int32
    """The node's index in that document, or `NO_NODE`."""

    comptime NONE = AstRef(-1, -1)
    """No node."""

    def exists(self) -> Bool:
        """Return True if this names a node.

        Returns:
            Whether the reference is set.
        """
        return self.document >= 0 and self.node >= 0


@fieldwise_init
struct Range(ImplicitlyCopyable, Movable):
    """A run of consecutive entries of one of a schema's lists."""

    var start: Int32
    """The first entry."""
    var count: Int32
    """How many entries."""

    comptime EMPTY = Range(0, 0)
    """No entries."""

    def end(self) -> Int:
        """Return the index after the last entry.

        Returns:
            `start + count`.
        """
        return Int(self.start) + Int(self.count)


struct NamedType(Copyable, Movable):
    """A scalar, object, interface, union, enum or input object type."""

    var name: String
    """The type's name."""
    var kind: TypeKind
    """What the type is."""
    var description: AstRef
    """The description's `StringValue` node, or `AstRef.NONE`; an empty
    description counts. `Schema.description_text` decodes it."""
    var specified_by_url: String
    """A scalar's `@specifiedBy` URL; see `has_specified_by_url`."""
    var has_specified_by_url: Bool
    """Whether a scalar has a `@specifiedBy` URL."""
    var is_one_of: Bool
    """An input object marked `@oneOf`."""
    var is_builtin: Bool
    """A specified scalar or an introspection type."""
    var fields: Range
    """An object's or interface's entries in `Schema.fields`."""
    var input_fields: Range
    """An input object's entries in `Schema.input_values`."""
    var enum_values: Range
    """An enum's entries in `Schema.enum_values`."""
    var interfaces: Range
    """The interfaces it implements, as entries of `Schema.type_lists`."""
    var members: Range
    """A union's member types, as entries of `Schema.type_lists`."""
    var directives: Range
    """Its applied directives, as entries of `Schema.applied`."""
    var definition: AstRef
    """The definition node, graphql-js `astNode`."""
    var extensions: Range
    """Its extension nodes, as entries of `Schema.ast_refs`."""

    def __init__(out self, var name: String, kind: TypeKind):
        """Start a type with no members.

        Args:
            name: The name.
            kind: The kind.
        """
        self.name = name^
        self.kind = kind
        self.description = AstRef.NONE
        self.specified_by_url = String("")
        self.has_specified_by_url = False
        self.is_one_of = False
        self.is_builtin = False
        self.fields = Range.EMPTY
        self.input_fields = Range.EMPTY
        self.enum_values = Range.EMPTY
        self.interfaces = Range.EMPTY
        self.members = Range.EMPTY
        self.directives = Range.EMPTY
        self.definition = AstRef.NONE
        self.extensions = Range.EMPTY


struct FieldDef(Copyable, Movable):
    """A field of an object or an interface type."""

    var name: String
    """The field's name."""
    var owner: Int32
    """The type that declares it."""
    var type: TypeRef
    """The field's type."""
    var description: AstRef
    """The description's `StringValue` node, or `AstRef.NONE`; an empty
    description counts. `Schema.description_text` decodes it."""
    var deprecation_reason: String
    """Why it is deprecated; see `is_deprecated`."""
    var is_deprecated: Bool
    """Whether `@deprecated` is applied."""
    var arguments: Range
    """Its arguments, as entries of `Schema.input_values`."""
    var directives: Range
    """Its applied directives, as entries of `Schema.applied`."""
    var definition: AstRef
    """The definition node."""

    def __init__(out self, var name: String, owner: Int, type: TypeRef):
        """Start a field with no arguments.

        Args:
            name: The name.
            owner: The type that declares it.
            type: Its type.
        """
        self.name = name^
        self.owner = Int32(owner)
        self.type = type
        self.description = AstRef.NONE
        self.deprecation_reason = String("")
        self.is_deprecated = False
        self.arguments = Range.EMPTY
        self.directives = Range.EMPTY
        self.definition = AstRef.NONE


struct InputValueDef(Copyable, Movable):
    """An argument of a field or a directive, or a field of an input object."""

    var name: String
    """The name."""
    var type: TypeRef
    """The input type."""
    var description: AstRef
    """The description's `StringValue` node, or `AstRef.NONE`; an empty
    description counts. `Schema.description_text` decodes it."""
    var default_value: AstRef
    """The default value literal, or none."""
    var deprecation_reason: String
    """Why it is deprecated; see `is_deprecated`."""
    var is_deprecated: Bool
    """Whether `@deprecated` is applied."""
    var directives: Range
    """Its applied directives, as entries of `Schema.applied`."""
    var definition: AstRef
    """The definition node."""

    def __init__(out self, var name: String, type: TypeRef):
        """Start an input value with no default.

        Args:
            name: The name.
            type: Its type.
        """
        self.name = name^
        self.type = type
        self.description = AstRef.NONE
        self.default_value = AstRef.NONE
        self.deprecation_reason = String("")
        self.is_deprecated = False
        self.directives = Range.EMPTY
        self.definition = AstRef.NONE

    def has_default(self) -> Bool:
        """Return True if a default value is set.

        Returns:
            Whether `default_value` names a literal.
        """
        return self.default_value.exists()


struct EnumValueDef(Copyable, Movable):
    """A value of an enum type."""

    var name: String
    """The value's name."""
    var description: AstRef
    """The description's `StringValue` node, or `AstRef.NONE`; an empty
    description counts. `Schema.description_text` decodes it."""
    var deprecation_reason: String
    """Why it is deprecated; see `is_deprecated`."""
    var is_deprecated: Bool
    """Whether `@deprecated` is applied."""
    var directives: Range
    """Its applied directives, as entries of `Schema.applied`."""
    var definition: AstRef
    """The definition node."""

    def __init__(out self, var name: String):
        """Start an enum value.

        Args:
            name: The name.
        """
        self.name = name^
        self.description = AstRef.NONE
        self.deprecation_reason = String("")
        self.is_deprecated = False
        self.directives = Range.EMPTY
        self.definition = AstRef.NONE


struct DirectiveDef(Copyable, Movable):
    """A directive that the schema defines."""

    var name: String
    """The name, without `@`."""
    var description: AstRef
    """The description's `StringValue` node, or `AstRef.NONE`; an empty
    description counts. `Schema.description_text` decodes it."""
    var locations: UInt32
    """One bit per `DirectiveLocation` value where it can appear."""
    var arguments: Range
    """Its arguments, as entries of `Schema.input_values`."""
    var is_repeatable: Bool
    """Whether it can appear more than once at one place."""
    var deprecation_reason: String
    """Why it is deprecated; see `is_deprecated`."""
    var is_deprecated: Bool
    """Whether `@deprecated` is applied to the definition."""
    var is_builtin: Bool
    """One of the specified directives."""
    var definition: AstRef
    """The definition node."""
    var extensions: Range
    """The `extend directive` nodes, as entries of `Schema.ast_refs`."""

    def __init__(out self, var name: String):
        """Start a directive with no locations.

        Args:
            name: The name, without `@`.
        """
        self.name = name^
        self.description = AstRef.NONE
        self.locations = 0
        self.arguments = Range.EMPTY
        self.is_repeatable = False
        self.deprecation_reason = String("")
        self.is_deprecated = False
        self.is_builtin = False
        self.definition = AstRef.NONE
        self.extensions = Range.EMPTY

    def allows(self, location: DirectiveLocation) -> Bool:
        """Return True if the directive can appear at a location.

        Args:
            location: The location.

        Returns:
            Whether the location's bit is set.
        """
        return self.locations & (UInt32(1) << UInt32(location.value)) != 0


struct Schema(Copyable, Movable):
    """A GraphQL schema: graphql-js `GraphQLSchema`."""

    var documents: List[Document]
    """The SDL documents the schema was built from; the built-ins first."""
    var types: List[NamedType]
    """Every named type, in creation order."""
    var type_map: List[Int32]
    """The types of graphql-js `getTypeMap()`, in its order."""
    var fields: List[FieldDef]
    """Every field of every object and interface."""
    var input_values: List[InputValueDef]
    """Every argument and input field."""
    var enum_values: List[EnumValueDef]
    """Every enum value."""
    var type_lists: List[Int32]
    """Interfaces, union members, and implementations, as type indices."""
    var directives: List[DirectiveDef]
    """The directives, in graphql-js `getDirectives()` order."""
    var applied: List[AstRef]
    """Applied directive nodes."""
    var ast_refs: List[AstRef]
    """Extension nodes."""
    var query_type: Int32
    """The query root type, or `NO_TYPE`."""
    var mutation_type: Int32
    """The mutation root type, or `NO_TYPE`."""
    var subscription_type: Int32
    """The subscription root type, or `NO_TYPE`."""
    var description: AstRef
    """The description's `StringValue` node, or `AstRef.NONE`; an empty
    description counts. `Schema.description_text` decodes it."""
    var schema_directives: Range
    """Directives applied to the schema, as entries of `applied`."""
    var schema_definition: AstRef
    """The `schema` definition node."""
    var schema_extensions: Range
    """The `extend schema` nodes, as entries of `ast_refs`."""
    var implementing_objects: List[Range]
    """For each type, the objects that implement it, in `type_lists`."""
    var implementing_interfaces: List[Range]
    """For each type, the interfaces that implement it, in `type_lists`."""
    var _type_names: NameTable
    var _member_names: NameTable
    var _argument_names: NameTable
    var _directive_names: NameTable

    def __init__(out self):
        """Start an empty schema."""
        self.documents = List[Document]()
        self.types = List[NamedType]()
        self.type_map = List[Int32]()
        self.fields = List[FieldDef]()
        self.input_values = List[InputValueDef]()
        self.enum_values = List[EnumValueDef]()
        self.type_lists = List[Int32]()
        self.directives = List[DirectiveDef]()
        self.applied = List[AstRef]()
        self.ast_refs = List[AstRef]()
        self.query_type = NO_TYPE
        self.mutation_type = NO_TYPE
        self.subscription_type = NO_TYPE
        self.description = AstRef.NONE
        self.schema_directives = Range.EMPTY
        self.schema_definition = AstRef.NONE
        self.schema_extensions = Range.EMPTY
        self.implementing_objects = List[Range]()
        self.implementing_interfaces = List[Range]()
        self._type_names = NameTable()
        self._member_names = NameTable()
        self._argument_names = NameTable()
        self._directive_names = NameTable()

    def take_documents(deinit self) -> List[Document]:
        """End the schema and return the documents it was built from.

        A schema owns its documents, so a caller that builds again from the
        same documents takes them back instead of copying them.

        Returns:
            The SDL documents, in order, without the built-in SDL.
        """
        var documents = self.documents^
        _ = documents.pop(0)
        return documents^

    def description_text(self, at: AstRef) -> String:
        """Return a description, decoded, as graphql-js `description`.

        Args:
            at: A `description` field: a `StringValue` node, or
                `AstRef.NONE`.

        Returns:
            The decoded text, or empty when there is no description.
        """
        if not at.exists():
            return String("")
        return self.documents[Int(at.document)].string_value(Int(at.node))

    def reserve(mut self, nodes: Int, definitions: Int):
        """Make room for a schema built from documents, so the lists and
        name tables do not grow while it is built.

        Args:
            nodes: The number of AST nodes in the documents.
            definitions: The number of definitions in the documents.
        """
        self.types.reserve(definitions + 16)
        self.fields.reserve(nodes // 8)
        self.input_values.reserve(nodes // 8)
        self.applied.reserve(nodes // 16)
        self.type_lists.reserve(nodes // 16)
        self._type_names = NameTable(capacity=definitions + 16)
        self._member_names = NameTable(capacity=nodes // 64)
        self._argument_names = NameTable(capacity=nodes // 256)

    # --- lookups ----------------------------------------------------------

    def type_named(self, name: StringSlice) -> Int:
        """Return the type with a name, as graphql-js `getType`.

        Args:
            name: The type's name.

        Returns:
            The type's index, or `NO_TYPE` when the type map has none.
        """
        return self._type_names.find(-1, name)

    def field_named(self, type: Int, name: StringSlice) -> Int:
        """Return a field of an object or interface type by name.

        Args:
            type: The type's index.
            name: The field's name.

        Returns:
            The field's index, or `NO_TYPE` when the type has none.
        """
        if not self.types[type].kind.has_fields():
            return NO_TYPE
        var span = self.types[type].fields
        if span.count < HASHED_MEMBERS:
            var fields = self.fields.unsafe_ptr()
            for index in range(Int(span.start), span.end()):
                if fields[unsafe_offset=index].name == name:
                    return index
            return NO_TYPE
        return self._member_names.find(type, name)

    def input_field_named(self, type: Int, name: StringSlice) -> Int:
        """Return a field of an input object type by name.

        Args:
            type: The type's index.
            name: The field's name.

        Returns:
            The input value's index, or `NO_TYPE` when the type has none.
        """
        if self.types[type].kind != TypeKind.INPUT_OBJECT:
            return NO_TYPE
        return self._input_value_named(
            self.types[type].input_fields, type, name, False
        )

    def enum_value_named(self, type: Int, name: StringSlice) -> Int:
        """Return a value of an enum type by name.

        Args:
            type: The type's index.
            name: The value's name.

        Returns:
            The enum value's index, or `NO_TYPE` when the type has none.
        """
        if self.types[type].kind != TypeKind.ENUM:
            return NO_TYPE
        var span = self.types[type].enum_values
        if span.count < HASHED_MEMBERS:
            var values = self.enum_values.unsafe_ptr()
            for index in range(Int(span.start), span.end()):
                if values[unsafe_offset=index].name == name:
                    return index
            return NO_TYPE
        return self._member_names.find(type, name)

    def argument_named(self, field: Int, name: StringSlice) -> Int:
        """Return an argument of a field by name.

        Args:
            field: The field's index.
            name: The argument's name.

        Returns:
            The input value's index, or `NO_TYPE` when there is none.
        """
        return self._input_value_named(
            self.fields[field].arguments, field, name, True
        )

    def _input_value_named(
        self, span: Range, key: Int, name: StringSlice, by_argument: Bool
    ) -> Int:
        """Find an input value by name in a span: a scan for a short span,
        a name table for a long one."""
        if span.count < HASHED_MEMBERS:
            var values = self.input_values.unsafe_ptr()
            for index in range(Int(span.start), span.end()):
                if values[unsafe_offset=index].name == name:
                    return index
            return NO_TYPE
        if by_argument:
            return self._argument_names.find(key, name)
        return self._member_names.find(key, name)

    def directive_named(self, name: StringSlice) -> Int:
        """Return a directive by name, as graphql-js `getDirective`.

        Args:
            name: The name, without `@`.

        Returns:
            The directive's index, or `NO_TYPE` when there is none.
        """
        return self._directive_names.find(-1, name)

    def directive_argument_named(
        self, directive: Int, name: StringSlice
    ) -> Int:
        """Return an argument of a directive by name.

        Args:
            directive: The directive's index.
            name: The argument's name.

        Returns:
            The input value's index, or `NO_TYPE` when there is none.
        """
        return self._input_value_named(
            self.directives[directive].arguments, -2 - directive, name, True
        )

    # --- registration, used by the builder --------------------------------

    def register_type_name(mut self, type: Int) -> Bool:
        """Put a type in the name table and the type map.

        Args:
            type: The type's index.

        Returns:
            False when another type has the name already.
        """
        if not self._type_names.insert(-1, self.types[type].name, type):
            return False
        self.type_map.append(Int32(type))
        return True

    def register_directive_name(mut self, directive: Int) -> Bool:
        """Put a directive in the name table.

        Args:
            directive: The directive's index.

        Returns:
            False when another directive has the name already.
        """
        return self._directive_names.insert(
            -1, self.directives[directive].name, directive
        )

    # --- relations --------------------------------------------------------

    def root_type(self, operation: UInt8) -> Int:
        """Return the root type for an operation type.

        Args:
            operation: 0 query, 1 mutation, 2 subscription.

        Returns:
            The type's index, or `NO_TYPE`.
        """
        if operation == 0:
            return Int(self.query_type)
        if operation == 1:
            return Int(self.mutation_type)
        return Int(self.subscription_type)

    def type_name(self, type: TypeRef) -> String:
        """Return a type reference as SDL writes it, such as `[Int!]!`.

        Args:
            type: The reference.

        Returns:
            The graphql-js `String(type)`.
        """
        var out = String(self.types[Int(type.named)].name)
        var depth = Int(type.depth)
        var level = depth - 1
        while level >= 0:
            if (type.bits >> UInt32(level)) & 1 == 1:
                out = "[" + out + "]"
            else:
                out += "!"
            level -= 1
        return out^

    def possible_types(self, type: Int) -> List[Int]:
        """Return the object types an abstract type can be.

        Args:
            type: The type's index.

        Returns:
            The graphql-js `getPossibleTypes`: a union's members, or the objects
            that implement an interface; empty for any other kind.
        """
        var out = List[Int]()
        ref named = self.types[type]
        var span = Range.EMPTY
        if named.kind == TypeKind.UNION:
            span = named.members
        elif named.kind == TypeKind.INTERFACE:
            span = self.implementing_objects[type]
        for index in range(Int(span.start), span.end()):
            out.append(Int(self.type_lists[index]))
        return out^

    def is_possible_type(self, abstract: Int, object: Int) -> Bool:
        """Return True if an object type is a possible type of an abstract
        type.

        Args:
            abstract: The abstract type's index.
            object: The object type's index.

        Returns:
            The graphql-js `isSubType` for an object.
        """
        return self.is_sub_type(abstract, object)

    def is_sub_type(self, abstract: Int, maybe_sub: Int) -> Bool:
        """Return True if a type is an implementation or member of another.

        Args:
            abstract: The union or interface's index.
            maybe_sub: The object or interface's index.

        Returns:
            The graphql-js `isSubType`: a union member, or an object or
            interface that implements the interface.
        """
        ref named = self.types[abstract]
        var span = Range.EMPTY
        if named.kind == TypeKind.UNION:
            if self.types[maybe_sub].kind != TypeKind.OBJECT:
                return False
            span = named.members
        elif named.kind == TypeKind.INTERFACE:
            if self.types[maybe_sub].kind == TypeKind.INTERFACE:
                span = self.implementing_interfaces[abstract]
            else:
                span = self.implementing_objects[abstract]
        for index in range(Int(span.start), span.end()):
            if Int(self.type_lists[index]) == maybe_sub:
                return True
        return False

    def interfaces_of(self, type: Int) -> List[Int]:
        """Return the interfaces a type implements, in declaration order.

        Args:
            type: The type's index.

        Returns:
            The interfaces' indices.
        """
        var out = List[Int]()
        ref span = self.types[type].interfaces
        for index in range(Int(span.start), span.end()):
            out.append(Int(self.type_lists[index]))
        return out^

    def field_indices(self, type: Int) -> List[Int]:
        """Return the fields of an object or interface type, in order.

        Args:
            type: The type's index.

        Returns:
            The fields' indices.
        """
        var out = List[Int]()
        ref span = self.types[type].fields
        for index in range(Int(span.start), span.end()):
            out.append(index)
        return out^

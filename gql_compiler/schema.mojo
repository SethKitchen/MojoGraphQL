# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The schema model of apollo-compiler.

Port of apollo-compiler 1.33.0 (`b7eee5c`) `src/schema/mod.rs`,
`src/schema/component.rs` and `src/schema/from_ast.rs`, under the MIT arm
of its MIT OR Apache-2.0 license.

A `Schema` keeps the documents it was built from, as apollo-compiler keeps
`Node` pointers into its AST. A type, a field, a directive and a root
operation are each a `Component`: a document index, a node index and an
origin. Nothing is copied out of the AST. A type is not resolved, and the
types keep their definition order.

**Differences from upstream.**

- A `Component` names an AST node by index instead of holding a reference
  counted pointer. `Schema.document(component)` reads it.
- `SchemaBuilder.add_ast` takes the document by value. apollo-compiler
  shares it through `Arc`.
- apollo-compiler keeps its built-in types in a static `OnceLock`. Mojo has
  no globals, so `SchemaBuilder.built_in()` returns a builder with the
  built-in types. A caller can keep it and copy it for each build, which
  is what `SchemaBuilder::new` does upstream.
- A field, a value and a member are found by a scan when a type has fewer
  than 8 of them, and by a hash above that. Upstream always hashes.
- The GraphQL 2025 directive extension, which apollo-parser does not parse,
  is reported as `BuildError.EXECUTABLE_DEFINITION` would be, with the
  description "a directive extension".
"""

from gql_language.ast import Document, Kind, NO_NODE, OperationType, Role
from gql_language.names import NOT_FOUND, NameTable
from gql_language.source import SourceLocation

comptime HASHED_MEMBERS = 8
"""A member list of this many or more is indexed by a hash."""

comptime DEFINITION_ORIGIN = Int32(-1)
"""The origin of a component of a type's definition."""


struct TypeKind(Equatable, ImplicitlyCopyable, Writable):
    """The variant of an `ExtendedType`."""

    var value: UInt8
    """The variant's index; see `is_valid`."""

    comptime SCALAR = TypeKind(0)
    """`ExtendedType::Scalar`."""
    comptime OBJECT = TypeKind(1)
    """`ExtendedType::Object`."""
    comptime INTERFACE = TypeKind(2)
    """`ExtendedType::Interface`."""
    comptime UNION = TypeKind(3)
    """`ExtendedType::Union`."""
    comptime ENUM = TypeKind(4)
    """`ExtendedType::Enum`."""
    comptime INPUT_OBJECT = TypeKind(5)
    """`ExtendedType::InputObject`."""

    @always_inline
    def __init__(out self, value: UInt8):
        """Make a type kind from its index.

        Args:
            value: The index.
        """
        self.value = value

    def is_valid(self) -> Bool:
        """Return True for one of the six variants.

        Returns:
            Whether the index names a variant.
        """
        return self.value <= 5

    def describe(self) -> StaticString:
        """Return the upstream `describe` text of a definition.

        Returns:
            Such as "an object type".
        """
        if self == TypeKind.SCALAR:
            return "a scalar type"
        if self == TypeKind.OBJECT:
            return "an object type"
        if self == TypeKind.INTERFACE:
            return "an interface type"
        if self == TypeKind.UNION:
            return "a union type"
        if self == TypeKind.ENUM:
            return "an enum type"
        return "an input object type"

    def describe_extension(self) -> StaticString:
        """Return the upstream `describe` text of an extension.

        Returns:
            Such as "an object type extension".
        """
        if self == TypeKind.SCALAR:
            return "a scalar type extension"
        if self == TypeKind.OBJECT:
            return "an object type extension"
        if self == TypeKind.INTERFACE:
            return "an interface type extension"
        if self == TypeKind.UNION:
            return "a union type extension"
        if self == TypeKind.ENUM:
            return "an enum type extension"
        return "an input object type extension"

    def write_to(self, mut writer: Some[Writer]):
        """Write the description of a definition.

        Args:
            writer: The writer.
        """
        writer.write(self.describe())


def definition_kind(kind: Kind) -> Int:
    """Return the `TypeKind` index of a type definition or extension.

    Args:
        kind: An AST node kind.

    Returns:
        0 to 5, or -1 when the kind is not a type definition or extension.
    """
    var value = Int(kind.value)
    if value >= Int(Kind.SCALAR_TYPE_EXTENSION.value):
        if value <= Int(Kind.INPUT_OBJECT_TYPE_EXTENSION.value):
            return value - Int(Kind.SCALAR_TYPE_EXTENSION.value)
        return -1
    if kind == Kind.SCALAR_TYPE_DEFINITION:
        return 0
    if kind == Kind.OBJECT_TYPE_DEFINITION:
        return 1
    if kind == Kind.INTERFACE_TYPE_DEFINITION:
        return 2
    if kind == Kind.UNION_TYPE_DEFINITION:
        return 3
    if kind == Kind.ENUM_TYPE_DEFINITION:
        return 4
    if kind == Kind.INPUT_OBJECT_TYPE_DEFINITION:
        return 5
    return -1


@fieldwise_init
struct Component(Equatable, ImplicitlyCopyable, Movable):
    """A part of the schema and where it came from: upstream `Component`
    and `ComponentName`."""

    var source: Int32
    """The index of the document in `Schema.sources`."""
    var node: Int32
    """The AST node, or `NO_NODE` for an implicit root operation."""
    var origin: Int32
    """`DEFINITION_ORIGIN`, or the index of the extension in
    `Schema.extensions`: upstream `ComponentOrigin`."""


@fieldwise_init
struct Members(ImplicitlyCopyable, Movable):
    """A run of components in `Schema.components`."""

    var start: Int32
    """The first component."""
    var count: Int32
    """How many components follow it."""


@fieldwise_init
struct ExtendedType(Copyable, Movable):
    """A type of the schema: upstream `ExtendedType`."""

    var kind: TypeKind
    """The variant."""
    var definition: Component
    """The definition, or the first extension of an adopted orphan."""
    var directives: Members
    """The directives of the definition and of its extensions."""
    var interfaces: Members
    """The `implements` names of an object or an interface type."""
    var members: Members
    """The fields, the enum values, the union members or the input
    fields."""


@fieldwise_init
struct DirectiveDefinition(ImplicitlyCopyable, Movable):
    """A directive definition: upstream `Node<DirectiveDefinition>`."""

    var source: Int32
    """The index of the document in `Schema.sources`."""
    var node: Int32
    """The `DirectiveDefinition` node."""


@fieldwise_init
struct RootOperation(ImplicitlyCopyable, Movable):
    """A root operation of the schema definition."""

    var component: Component
    """Its `NamedType` node, or `NO_NODE` when it is implicit."""
    var type_name: String
    """The object type's name."""


struct BuildErrorKind(Equatable, ImplicitlyCopyable, Writable):
    """A variant of upstream `BuildError`."""

    var value: UInt8
    """The variant's index; see `is_valid`."""

    comptime EXECUTABLE_DEFINITION = BuildErrorKind(0)
    """`ExecutableDefinition`."""
    comptime SCHEMA_DEFINITION_COLLISION = BuildErrorKind(1)
    """`SchemaDefinitionCollision`."""
    comptime DIRECTIVE_DEFINITION_COLLISION = BuildErrorKind(2)
    """`DirectiveDefinitionCollision`."""
    comptime TYPE_DEFINITION_COLLISION = BuildErrorKind(3)
    """`TypeDefinitionCollision`."""
    comptime BUILT_IN_SCALAR_TYPE_REDEFINITION = BuildErrorKind(4)
    """`BuiltInScalarTypeRedefinition`."""
    comptime ORPHAN_SCHEMA_EXTENSION = BuildErrorKind(5)
    """`OrphanSchemaExtension`."""
    comptime ORPHAN_TYPE_EXTENSION = BuildErrorKind(6)
    """`OrphanTypeExtension`."""
    comptime TYPE_EXTENSION_KIND_MISMATCH = BuildErrorKind(7)
    """`TypeExtensionKindMismatch`."""
    comptime DUPLICATE_ROOT_OPERATION = BuildErrorKind(8)
    """`DuplicateRootOperation`."""
    comptime DUPLICATE_IMPLEMENTS_INTERFACE = BuildErrorKind(9)
    """`DuplicateImplementsInterfaceInObject` and `...InInterface`."""
    comptime MEMBER_NAME_COLLISION = BuildErrorKind(10)
    """`ObjectFieldNameCollision`, `InterfaceFieldNameCollision`,
    `EnumValueNameCollision`, `UnionMemberNameCollision` and
    `InputFieldNameCollision`."""

    @always_inline
    def __init__(out self, value: UInt8):
        """Make an error kind from its index.

        Args:
            value: The index.
        """
        self.value = value

    def is_valid(self) -> Bool:
        """Return True for one of the variants.

        Returns:
            Whether the index names a variant.
        """
        return self.value <= 10

    def write_to(self, mut writer: Some[Writer]):
        """Write the index.

        Args:
            writer: The writer.
        """
        writer.write("BuildErrorKind(", self.value, ")")


@fieldwise_init
struct BuildError(Copyable, Movable, Writable):
    """One error of a schema build: upstream `BuildError` and its
    location."""

    var kind: BuildErrorKind
    """The variant."""
    var location: Component
    """The node the error points at."""
    var name: String
    """The type, directive or member name, or the operation type."""
    var type_kind: TypeKind
    """The kind of the type that a member or an extension belongs to."""
    var describe: String
    """The `describe` text of the definition or extension involved."""
    var type_name: String
    """The type that a member, an interface or an extension belongs to."""

    def message(self) -> String:
        """Return the upstream message.

        Returns:
            The text of the upstream `#[error(...)]` attribute.
        """
        var kind = self.kind
        if kind == BuildErrorKind.EXECUTABLE_DEFINITION:
            return String("a schema document must not contain ", self.describe)
        if kind == BuildErrorKind.SCHEMA_DEFINITION_COLLISION:
            return "must not have multiple `schema` definitions"
        if kind == BuildErrorKind.DIRECTIVE_DEFINITION_COLLISION:
            return String(
                "the directive `@",
                self.name,
                "` is defined multiple times in the schema",
            )
        if kind == BuildErrorKind.TYPE_DEFINITION_COLLISION:
            return String(
                "the type `",
                self.name,
                "` is defined multiple times in the schema",
            )
        if kind == BuildErrorKind.BUILT_IN_SCALAR_TYPE_REDEFINITION:
            return "built-in scalar definitions must be omitted"
        if kind == BuildErrorKind.ORPHAN_SCHEMA_EXTENSION:
            return "schema extension without a schema definition"
        if kind == BuildErrorKind.ORPHAN_TYPE_EXTENSION:
            return String("type extension for undefined type `", self.name, "`")
        if kind == BuildErrorKind.TYPE_EXTENSION_KIND_MISMATCH:
            return String(
                "adding ",
                self.describe,
                ", but `",
                self.name,
                "` is ",
                self.type_kind.describe(),
            )
        if kind == BuildErrorKind.DUPLICATE_ROOT_OPERATION:
            return String(
                "duplicate definitions for the `",
                self.name,
                "` root operation type",
            )
        if kind == BuildErrorKind.DUPLICATE_IMPLEMENTS_INTERFACE:
            var owner = (
                "object" if self.type_kind == TypeKind.OBJECT else "interface"
            )
            return String(
                owner,
                " type `",
                self.type_name,
                "` implements interface `",
                self.name,
                "` more than once",
            )
        var member = "field"
        if self.type_kind == TypeKind.ENUM:
            member = "value"
        elif self.type_kind == TypeKind.UNION:
            member = "member"
        var owner = "object type"
        if self.type_kind == TypeKind.INTERFACE:
            owner = "interface type"
        elif self.type_kind == TypeKind.ENUM:
            owner = "enum type"
        elif self.type_kind == TypeKind.UNION:
            owner = "union type"
        elif self.type_kind == TypeKind.INPUT_OBJECT:
            owner = "input object type"
        return String(
            "duplicate definitions for the `",
            self.name,
            "` ",
            member,
            " of ",
            owner,
            " `",
            self.type_name,
            "`",
        )

    def write_to(self, mut writer: Some[Writer]):
        """Write the message.

        Args:
            writer: The writer.
        """
        writer.write(self.message())


struct Schema(Copyable, Movable):
    """A GraphQL schema: upstream `Schema`."""

    var sources: List[Document]
    """The documents the schema was built from. The first one holds the
    built-in types."""
    var types: List[ExtendedType]
    """The types, in definition order: upstream `types`."""
    var directive_definitions: List[DirectiveDefinition]
    """The directive definitions, in definition order."""
    var components: List[Component]
    """The storage of every `Members` run."""
    var extensions: List[Component]
    """The extensions that components came from: upstream `ExtensionId`."""
    var names: NameTable
    """Types under owner -1, directives under owner -2, and the members
    of a type with many members under the type's index."""
    var schema_definition: Component
    """The `schema` definition, or `NO_NODE` when it is implicit."""
    var schema_directives: Members
    """The directives of the `schema` definition and its extensions."""
    var roots: List[Optional[RootOperation]]
    """The query, mutation and subscription root operations."""

    def __init__(out self):
        """Make an empty schema with no sources."""
        self.sources = List[Document]()
        self.types = List[ExtendedType]()
        self.directive_definitions = List[DirectiveDefinition]()
        self.components = List[Component]()
        self.extensions = List[Component]()
        self.names = NameTable(capacity=64)
        self.schema_definition = Component(0, Int32(NO_NODE), DEFINITION_ORIGIN)
        self.schema_directives = Members(0, 0)
        self.roots = List[Optional[RootOperation]](length=3, fill=None)

    def node_name(
        self, source: Int, node: Int
    ) -> StringSlice[origin_of(self.sources)]:
        """Return the name of a node in one of the sources.

        Args:
            source: The index of the document.
            node: A definition, an extension, a member or a `NamedType`;
                each has a `name` child.

        Returns:
            A view of the name.
        """
        ref document = self.sources[source]
        return rebind[StringSlice[origin_of(self.sources)]](
            document.text(document.child(node, Role.NAME))
        )

    def component_name(
        self, component: Component
    ) -> StringSlice[origin_of(self.sources)]:
        """Return the name of a component.

        Args:
            component: A type, a member, a directive or a root operation.

        Returns:
            A view of its name.
        """
        return self.node_name(Int(component.source), Int(component.node))

    def type_name(self, index: Int) -> StringSlice[origin_of(self.sources)]:
        """Return the name of a type.

        Args:
            index: The type's index in `types`.

        Returns:
            A view of the name.
        """
        return self.component_name(self.types[index].definition)

    def get_type(self, name: StringSlice) -> Int:
        """Return the index of a type: upstream `types.get`.

        Args:
            name: The type's name.

        Returns:
            The index in `types`, or `NOT_FOUND`.
        """
        return self.names.find(-1, name)

    def get_directive_definition(self, name: StringSlice) -> Int:
        """Return the index of a directive definition.

        Args:
            name: The directive's name, without `@`.

        Returns:
            The index in `directive_definitions`, or `NOT_FOUND`.
        """
        return self.names.find(-2, name)

    def is_built_in(self, index: Int) -> Bool:
        """Return True for a built-in type: upstream `is_built_in`.

        Args:
            index: The type's index in `types`.

        Returns:
            Whether its definition is in the built-in document.
        """
        return self.types[index].definition.source == 0

    def member(self, type_index: Int, position: Int) -> Component:
        """Return one member of a type.

        Args:
            type_index: The type's index in `types`.
            position: The member's position, from 0.

        Returns:
            The field, the enum value, the union member or the input field.
        """
        var members = self.types[type_index].members
        return self.components[Int(members.start) + position]

    def member_count(self, type_index: Int) -> Int:
        """Return how many members a type has.

        Args:
            type_index: The type's index in `types`.

        Returns:
            The number of fields, values, union members or input fields.
        """
        return Int(self.types[type_index].members.count)

    def find_member(self, type_index: Int, name: StringSlice) -> Int:
        """Return the position of a member by name: upstream `fields.get`,
        `values.get` and `members.get`.

        Args:
            type_index: The type's index in `types`.
            name: The member's name.

        Returns:
            Its position, or `NOT_FOUND`.
        """
        var members = self.types[type_index].members
        if Int(members.count) >= HASHED_MEMBERS:
            return self.names.find(type_index, name)
        var position = 0
        while position < Int(members.count):
            if (
                self.component_name(
                    self.components[Int(members.start) + position]
                )
                == name
            ):
                return position
            position += 1
        return NOT_FOUND

    def count_directives(self, members: Members, name: StringSlice) -> Int:
        """Return how many directives of a run have a name: upstream
        `DirectiveList::get_all(name).count()`.

        Args:
            members: A run of directives.
            name: The directive name, without `@`.

        Returns:
            The count.
        """
        var count = 0
        var position = 0
        while position < Int(members.count):
            var directive = self.components[Int(members.start) + position]
            if self.component_name(directive) == name:
                count += 1
            position += 1
        return count

    def root_operation(
        self, operation: OperationType
    ) -> Optional[RootOperation]:
        """Return a root operation of the schema definition.

        Args:
            operation: Query, mutation or subscription.

        Returns:
            The root operation, if any.
        """
        return self.roots[Int(operation.value)]

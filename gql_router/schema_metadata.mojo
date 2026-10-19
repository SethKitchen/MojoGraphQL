# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The schema facts that the executor reads.

Port of `SchemaMetadata`, `PossibleTypes`, `FieldNullability`,
`FieldTypeInfo`, `InputObjectInfo` and `InputFieldInfo` of Hive Router
`1a29df9` `bin/router/src/executor/introspection/schema.rs`, and of
`SchemaWithMetadata for ConsumerSchema`.

`schema_metadata(document)` reads the consumer schema. It records the
fields of each object and interface type, the members of each enum, the
possible types of each abstract type, the input objects, and the root
types.

**Differences from upstream.** A type reference of an input field is a
`name` and a `shape`, as `gql_router.federation_spec.TypeNode`, not a
`TypeNode` of the supergraph state. `FieldNullability` keeps the flags of
each level in one list of bytes, the form that the upstream projection
plan makes with `intern_shape`. A missing root type is the empty string,
not `None`. The entity keys are not part of the metadata: the executor
takes `gql_router.entity_keys.EntityKeys` from the supergraph state.
"""

from std.collections import Set

from gql_language.ast import NO_NODE, Document, Kind, OperationType, Role

comptime SHAPE_LIST: UInt8 = 1
"""A level of a type that is a list."""
comptime SHAPE_NON_NULL: UInt8 = 2
"""A level of a type that is non-null."""


struct FieldNullability(Copyable, Equatable, Movable):
    """The list and non-null levels of a field type, from the outside in,
    as upstream `FieldNullability`."""

    var shape: List[UInt8]
    """One byte of `SHAPE_LIST` and `SHAPE_NON_NULL` flags per level."""

    def __init__(out self, var shape: List[UInt8]):
        """Wrap the flags of each level.

        Args:
            shape: The flags, from the outside in; the last level is the
                named type.
        """
        self.shape = shape^

    @staticmethod
    def type_name() -> FieldNullability:
        """Return the shape of `__typename`, `String!`.

        Returns:
            A non-null leaf.
        """
        return FieldNullability([SHAPE_NON_NULL])

    def is_non_null(self) -> Bool:
        """Return True if the outer level is non-null.

        Returns:
            Whether a `null` at this level bubbles to the parent.
        """
        return self.shape[0] & SHAPE_NON_NULL != 0


@fieldwise_init
struct FieldTypeInfo(Copyable, Movable):
    """The output type of one field, as upstream `FieldTypeInfo`."""

    var output_type_name: String
    """The named type under the wrappers."""
    var nullability: FieldNullability
    """The levels of the type."""


@fieldwise_init
struct InputFieldInfo(Copyable, Movable):
    """One field of an input object type, as upstream `InputFieldInfo`."""

    var name: String
    """The field name."""
    var type_name: String
    """The named type under the wrappers."""
    var shape: String
    """The wrappers around `%`, such as `[%!]!`."""
    var has_default: Bool
    """Whether the field has a default value."""


@fieldwise_init
struct InputObjectInfo(Copyable, Movable):
    """One input object type, as upstream `InputObjectInfo`."""

    var fields: List[InputFieldInfo]
    """The fields, in schema order."""
    var is_one_of: Bool
    """Whether the type has `@oneOf`."""


struct PossibleTypes(Copyable, Movable):
    """The object types of each abstract type, as upstream
    `PossibleTypes`."""

    var map: Dict[String, Set[String]]
    """The possible types of each interface and union."""

    def __init__(out self):
        """Start with no abstract types."""
        self.map = Dict[String, Set[String]]()

    def entity_satisfies_type_condition(
        self, type_name: StringSlice, type_condition: StringSlice
    ) -> Bool:
        """Return True if an object of a type matches a type condition.

        Args:
            type_name: The type of the object.
            type_condition: The type of the condition.

        Returns:
            Whether the names are equal, or the object type is a possible
            type of the condition.
        """
        if type_name == type_condition:
            return True
        var found = self.map.get(String(type_condition))
        if found:
            return String(type_name) in found.value()
        return False

    def get_possible_types(self, type_name: String) -> Set[String]:
        """Return the possible types of a type, with the type itself.

        Args:
            type_name: The type.

        Returns:
            The set of names.
        """
        var out = Set[String]()
        var found = self.map.get(type_name)
        if found:
            out = found.value().copy()
        out.add(type_name)
        return out^


struct SchemaMetadata(Copyable, Movable):
    """The facts of the consumer schema, as upstream `SchemaMetadata`."""

    var possible_types: PossibleTypes
    """The possible types of each abstract type."""
    var enum_values: Dict[String, Set[String]]
    """The values of each enum type."""
    var type_fields: Dict[String, Dict[String, FieldTypeInfo]]
    """The fields of each object and interface type."""
    var field_types: Dict[String, FieldTypeInfo]
    """Each field of `type_fields`, by `Type.field`."""
    var object_types: Set[String]
    """The object types."""
    var scalar_types: Set[String]
    """The scalar types, the five built-in ones included."""
    var union_types: Set[String]
    """The union types."""
    var interface_types: Set[String]
    """The interface types."""
    var input_objects: Dict[String, InputObjectInfo]
    """The input object types."""
    var query_type_name: String
    """The query root type, or empty."""
    var mutation_type_name: String
    """The mutation root type, or empty."""
    var subscription_type_name: String
    """The subscription root type, or empty."""

    def __init__(out self):
        """Start an empty schema, as upstream `SchemaMetadata::default`."""
        self.possible_types = PossibleTypes()
        self.enum_values = Dict[String, Set[String]]()
        self.type_fields = Dict[String, Dict[String, FieldTypeInfo]]()
        self.field_types = Dict[String, FieldTypeInfo]()
        self.object_types = Set[String]()
        self.scalar_types = Set[String]()
        self.union_types = Set[String]()
        self.interface_types = Set[String]()
        self.input_objects = Dict[String, InputObjectInfo]()
        self.query_type_name = String()
        self.mutation_type_name = String()
        self.subscription_type_name = String()

    def is_object_type(self, name: String) -> Bool:
        """Return True if a type is an object type.

        Args:
            name: The type name.

        Returns:
            Whether the schema defines it as an object type.
        """
        return name in self.object_types

    def is_scalar_type(self, name: String) -> Bool:
        """Return True if a type is a scalar type.

        Args:
            name: The type name.

        Returns:
            Whether the type is a scalar.
        """
        return name in self.scalar_types

    def is_union_type(self, name: String) -> Bool:
        """Return True if a type is a union type.

        Args:
            name: The type name.

        Returns:
            Whether the type is a union.
        """
        return name in self.union_types

    def is_interface_type(self, name: String) -> Bool:
        """Return True if a type is an interface type.

        Args:
            name: The type name.

        Returns:
            Whether the type is an interface.
        """
        return name in self.interface_types

    def field_type(self, type_name: String, field_name: String) -> String:
        """Return the output type of a field.

        Args:
            type_name: The parent type.
            field_name: The field.

        Returns:
            The named output type, or empty when the type or the field is
            not in the schema.
        """
        var info = self.field_types.get(type_name + "." + field_name)
        if not info:
            return String()
        return info.value().output_type_name

    def has_type_fields(self, type_name: String) -> Bool:
        """Return True if the schema has the fields of a type.

        Args:
            type_name: The type name.

        Returns:
            Whether the type is an object or an interface type.
        """
        return type_name in self.type_fields

    def root_type_name(self, kind: OperationType) -> String:
        """Return the root type of an operation type.

        Args:
            kind: The operation type.

        Returns:
            The root type name, or empty.
        """
        if kind == OperationType.MUTATION:
            return self.mutation_type_name
        if kind == OperationType.SUBSCRIPTION:
            return self.subscription_type_name
        return self.query_type_name


def nullability_of(document: Document, node: Int) -> FieldNullability:
    """Read the levels of a type reference.

    Args:
        document: The schema document.
        node: A `NamedType`, `ListType` or `NonNullType` node.

    Returns:
        The flags of each level.
    """
    var shape = List[UInt8]()
    var current = node
    var flags: UInt8 = 0
    while document.kind(current) != Kind.NAMED_TYPE:
        if document.kind(current) == Kind.NON_NULL_TYPE:
            flags |= SHAPE_NON_NULL
        else:
            shape.append(flags | SHAPE_LIST)
            flags = 0
        current = document.first_child(current)
    shape.append(flags)
    return FieldNullability(shape^)


def _named_type(document: Document, node: Int) -> String:
    """Return the named type under the wrappers of a type reference."""
    var current = node
    while document.kind(current) != Kind.NAMED_TYPE:
        current = document.first_child(current)
    return String(document.name(current))


def _shape(document: Document, node: Int) -> String:
    """Return the wrappers of a type reference around `%`."""
    var prefix = String()
    var suffix = String()
    var current = node
    while document.kind(current) != Kind.NAMED_TYPE:
        if document.kind(current) == Kind.LIST_TYPE:
            prefix += "["
            suffix = "]" + suffix
        else:
            suffix = "!" + suffix
        current = document.first_child(current)
    return prefix + "%" + suffix


def _fields_of(document: Document, node: Int) -> Dict[String, FieldTypeInfo]:
    """Read the field definitions of an object or interface type."""
    var fields = Dict[String, FieldTypeInfo]()
    for field in document.children(node, Role.FIELD):
        var type_ref = document.child(field, Role.TYPE)
        fields[String(document.name(field))] = FieldTypeInfo(
            _named_type(document, type_ref), nullability_of(document, type_ref)
        )
    return fields^


def _has_directive(document: Document, node: Int, name: StringSlice) -> Bool:
    """Return True if a definition has a directive with a name."""
    for directive in document.children(node, Role.DIRECTIVE):
        if document.name(directive) == name:
            return True
    return False


struct _FirstPossible(Movable):
    """The members of each abstract type before the second level is added,
    as upstream `first_possible_types`, in first-seen order."""

    var names: List[String]
    """The abstract types."""
    var index: Dict[String, Int]
    """The position of each abstract type in `names`."""
    var members: List[List[String]]
    """The members of each type, parallel to `names`."""

    def __init__(out self):
        """Start with no types."""
        self.names = List[String]()
        self.index = Dict[String, Int]()
        self.members = List[List[String]]()

    def slot(mut self, name: String) -> Int:
        """Return the position of a type, and add it when it is new."""
        var found = self.index.get(name)
        if found:
            return found.value()
        self.index[name] = len(self.names)
        self.names.append(name)
        self.members.append(List[String]())
        return len(self.names) - 1

    def push(mut self, interface: String, member: String):
        """Append a member to the members of a type."""
        self.members[self.slot(interface)].append(member)

    def set(mut self, union: String, var members: List[String]):
        """Replace the members of a type."""
        self.members[self.slot(union)] = members^


def _root_name(
    document: Document, kind: OperationType, default_name: StringSlice
) -> String:
    """Return a root type, as `graphql_tools` `root_type_name`."""
    var fallback = String()
    for definition in document.definitions():
        var node_kind = document.kind(definition)
        if node_kind == Kind.SCHEMA_DEFINITION:
            var operations = document.children(definition, Role.OPERATION_TYPE)
            var index = 0
            while index < len(operations):
                var operation = operations[index]
                if document.operation(operation) == kind:
                    return _named_type(
                        document, document.child(operation, Role.TYPE)
                    )
                index += 1
        elif (
            node_kind == Kind.OBJECT_TYPE_DEFINITION
            and fallback.byte_length() == 0
            and document.name(definition) == default_name
        ):
            fallback = String(default_name)
    return fallback^


def schema_metadata(document: Document) -> SchemaMetadata:
    """Read the metadata of a consumer schema, as upstream
    `ConsumerSchema::schema_metadata`.

    Args:
        document: The consumer schema.

    Returns:
        The metadata.
    """
    var out = SchemaMetadata()
    var builtins: List[String] = ["Boolean", "Float", "Int", "ID", "String"]
    var builtin = 0
    while builtin < len(builtins):
        out.scalar_types.add(builtins[builtin])
        builtin += 1
    var first = _FirstPossible()
    for definition in document.definitions():
        var kind = document.kind(definition)
        var name = String(document.name(definition))
        if kind == Kind.ENUM_TYPE_DEFINITION:
            var values = Set[String]()
            for value in document.children(definition, Role.ENUM_VALUE):
                values.add(String(document.name(value)))
            out.enum_values[name] = values^
        elif kind == Kind.OBJECT_TYPE_DEFINITION:
            out.object_types.add(name)
            var fields = _fields_of(document, definition)
            var existing = out.type_fields.get(name)
            if existing:
                var merged = existing.value().copy()
                for entry in fields.items():
                    merged[entry.key] = entry.value.copy()
                fields = merged^
            out.type_fields[name] = fields^
            for interface in document.children(definition, Role.INTERFACE):
                first.push(String(document.name(interface)), name)
        elif kind == Kind.INTERFACE_TYPE_DEFINITION:
            out.interface_types.add(name)
            out.type_fields[name] = _fields_of(document, definition)
            for interface in document.children(definition, Role.INTERFACE):
                first.push(String(document.name(interface)), name)
        elif kind == Kind.UNION_TYPE_DEFINITION:
            out.union_types.add(name)
            var members = List[String]()
            for member in document.children(definition, Role.MEMBER_TYPE):
                members.append(String(document.name(member)))
            first.set(name, members^)
        elif kind == Kind.SCALAR_TYPE_DEFINITION:
            out.scalar_types.add(name)
        elif kind == Kind.INPUT_OBJECT_TYPE_DEFINITION:
            var fields = List[InputFieldInfo]()
            for field in document.children(definition, Role.FIELD):
                var type_ref = document.child(field, Role.TYPE)
                fields.append(
                    InputFieldInfo(
                        String(document.name(field)),
                        _named_type(document, type_ref),
                        _shape(document, type_ref),
                        document.child(field, Role.DEFAULT_VALUE) != NO_NODE,
                    )
                )
            out.input_objects[name] = InputObjectInfo(
                fields^, _has_directive(document, definition, "oneOf")
            )
    out.query_type_name = _root_name(document, OperationType.QUERY, "Query")
    out.mutation_type_name = _root_name(
        document, OperationType.MUTATION, "Mutation"
    )
    out.subscription_type_name = _root_name(
        document, OperationType.SUBSCRIPTION, "Subscription"
    )
    var slot = 0
    while slot < len(first.names):
        var possible = Set[String]()
        for member in first.members[slot]:
            possible.add(member)
            var nested = first.index.get(member)
            if nested:
                for inner in first.members[nested.value()]:
                    possible.add(inner)
        out.possible_types.map[first.names[slot]] = possible^
        slot += 1
    for entry in out.type_fields.items():
        for field in entry.value.items():
            out.field_types[entry.key + "." + field.key] = field.value.copy()
    return out^

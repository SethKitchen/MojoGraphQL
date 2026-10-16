# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The GraphQL abstract syntax tree, kept in one arena.

Port of the node kinds of graphql-js 16.14.2 `language/kinds.ts` and
`language/ast.ts`.

**One arena, not a tree of objects.** Every node of a document is a fixed
24-byte `Node` in one `List`. A node names its first child, its last child
and its next sibling by index. Each child carries a `Role`: the field of its
parent that it fills, as the graphql-js property name does. So a `Field`
node has children with the roles `ALIAS`, `NAME`, `ARGUMENT`, `DIRECTIVE`
and `SELECTION_SET`, in that order. A list property, such as
`arguments`, is the run of children with that role.

A parsed node's text is a byte range of the source: a name, a number and an
enum value cost no allocation. A node that a program builds keeps its text
after the end of the source bytes, with the `FLAG_EXTRA` flag set.

The children are in source order, which is also the order of graphql-js
`QueryDocumentKeys`. A visit in child order is a graphql-js visit.
"""

from gql_language.lexer import block_string_value
from gql_language.lexer import string_value as decode_string_value
from gql_language.source import Source, SourceLocation


@fieldwise_init
struct Kind(Equatable, ImplicitlyCopyable, Writable):
    """The kind of an AST node, as graphql-js `Kind`."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime NAME = Kind(0)
    """A `Name` node."""
    comptime DOCUMENT = Kind(1)
    """A `Document` node."""
    comptime OPERATION_DEFINITION = Kind(2)
    """A `OperationDefinition` node."""
    comptime VARIABLE_DEFINITION = Kind(3)
    """A `VariableDefinition` node."""
    comptime SELECTION_SET = Kind(4)
    """A `SelectionSet` node."""
    comptime FIELD = Kind(5)
    """A `Field` node."""
    comptime ARGUMENT = Kind(6)
    """A `Argument` node."""
    comptime FRAGMENT_SPREAD = Kind(7)
    """A `FragmentSpread` node."""
    comptime INLINE_FRAGMENT = Kind(8)
    """A `InlineFragment` node."""
    comptime FRAGMENT_DEFINITION = Kind(9)
    """A `FragmentDefinition` node."""
    comptime VARIABLE = Kind(10)
    """A `Variable` node."""
    comptime INT = Kind(11)
    """A `IntValue` node."""
    comptime FLOAT = Kind(12)
    """A `FloatValue` node."""
    comptime STRING = Kind(13)
    """A `StringValue` node."""
    comptime BOOLEAN = Kind(14)
    """A `BooleanValue` node."""
    comptime NULL = Kind(15)
    """A `NullValue` node."""
    comptime ENUM = Kind(16)
    """A `EnumValue` node."""
    comptime LIST = Kind(17)
    """A `ListValue` node."""
    comptime OBJECT = Kind(18)
    """A `ObjectValue` node."""
    comptime OBJECT_FIELD = Kind(19)
    """A `ObjectField` node."""
    comptime DIRECTIVE = Kind(20)
    """A `Directive` node."""
    comptime NAMED_TYPE = Kind(21)
    """A `NamedType` node."""
    comptime LIST_TYPE = Kind(22)
    """A `ListType` node."""
    comptime NON_NULL_TYPE = Kind(23)
    """A `NonNullType` node."""
    comptime SCHEMA_DEFINITION = Kind(24)
    """A `SchemaDefinition` node."""
    comptime OPERATION_TYPE_DEFINITION = Kind(25)
    """A `OperationTypeDefinition` node."""
    comptime SCALAR_TYPE_DEFINITION = Kind(26)
    """A `ScalarTypeDefinition` node."""
    comptime OBJECT_TYPE_DEFINITION = Kind(27)
    """A `ObjectTypeDefinition` node."""
    comptime FIELD_DEFINITION = Kind(28)
    """A `FieldDefinition` node."""
    comptime INPUT_VALUE_DEFINITION = Kind(29)
    """A `InputValueDefinition` node."""
    comptime INTERFACE_TYPE_DEFINITION = Kind(30)
    """A `InterfaceTypeDefinition` node."""
    comptime UNION_TYPE_DEFINITION = Kind(31)
    """A `UnionTypeDefinition` node."""
    comptime ENUM_TYPE_DEFINITION = Kind(32)
    """A `EnumTypeDefinition` node."""
    comptime ENUM_VALUE_DEFINITION = Kind(33)
    """A `EnumValueDefinition` node."""
    comptime INPUT_OBJECT_TYPE_DEFINITION = Kind(34)
    """A `InputObjectTypeDefinition` node."""
    comptime DIRECTIVE_DEFINITION = Kind(35)
    """A `DirectiveDefinition` node."""
    comptime SCHEMA_EXTENSION = Kind(36)
    """A `SchemaExtension` node."""
    comptime DIRECTIVE_EXTENSION = Kind(37)
    """A `DirectiveExtension` node."""
    comptime SCALAR_TYPE_EXTENSION = Kind(38)
    """A `ScalarTypeExtension` node."""
    comptime OBJECT_TYPE_EXTENSION = Kind(39)
    """A `ObjectTypeExtension` node."""
    comptime INTERFACE_TYPE_EXTENSION = Kind(40)
    """A `InterfaceTypeExtension` node."""
    comptime UNION_TYPE_EXTENSION = Kind(41)
    """A `UnionTypeExtension` node."""
    comptime ENUM_TYPE_EXTENSION = Kind(42)
    """A `EnumTypeExtension` node."""
    comptime INPUT_OBJECT_TYPE_EXTENSION = Kind(43)
    """A `InputObjectTypeExtension` node."""
    comptime TYPE_COORDINATE = Kind(44)
    """A `TypeCoordinate` node."""
    comptime MEMBER_COORDINATE = Kind(45)
    """A `MemberCoordinate` node."""
    comptime ARGUMENT_COORDINATE = Kind(46)
    """A `ArgumentCoordinate` node."""
    comptime DIRECTIVE_COORDINATE = Kind(47)
    """A `DirectiveCoordinate` node."""
    comptime DIRECTIVE_ARGUMENT_COORDINATE = Kind(48)
    """A `DirectiveArgumentCoordinate` node."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the 49 kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 48

    def text(self) -> StaticString:
        """Return the graphql-js `Kind` string, such as `Field`.

        Returns:
            The kind's name, or `<invalid>`.
        """
        comptime names: Array[StaticString, 49] = [
            "Name",
            "Document",
            "OperationDefinition",
            "VariableDefinition",
            "SelectionSet",
            "Field",
            "Argument",
            "FragmentSpread",
            "InlineFragment",
            "FragmentDefinition",
            "Variable",
            "IntValue",
            "FloatValue",
            "StringValue",
            "BooleanValue",
            "NullValue",
            "EnumValue",
            "ListValue",
            "ObjectValue",
            "ObjectField",
            "Directive",
            "NamedType",
            "ListType",
            "NonNullType",
            "SchemaDefinition",
            "OperationTypeDefinition",
            "ScalarTypeDefinition",
            "ObjectTypeDefinition",
            "FieldDefinition",
            "InputValueDefinition",
            "InterfaceTypeDefinition",
            "UnionTypeDefinition",
            "EnumTypeDefinition",
            "EnumValueDefinition",
            "InputObjectTypeDefinition",
            "DirectiveDefinition",
            "SchemaExtension",
            "DirectiveExtension",
            "ScalarTypeExtension",
            "ObjectTypeExtension",
            "InterfaceTypeExtension",
            "UnionTypeExtension",
            "EnumTypeExtension",
            "InputObjectTypeExtension",
            "TypeCoordinate",
            "MemberCoordinate",
            "ArgumentCoordinate",
            "DirectiveCoordinate",
            "DirectiveArgumentCoordinate",
        ]
        if not self.is_valid():
            return "<invalid>"
        return materialize[names]()[Int(self.value)]

    def is_type_definition(self) -> Bool:
        """Return True for the six type definition kinds.

        Returns:
            Whether the kind defines a named type.
        """
        return (
            self == Kind.SCALAR_TYPE_DEFINITION
            or self == Kind.OBJECT_TYPE_DEFINITION
            or self == Kind.INTERFACE_TYPE_DEFINITION
            or self == Kind.UNION_TYPE_DEFINITION
            or self == Kind.ENUM_TYPE_DEFINITION
            or self == Kind.INPUT_OBJECT_TYPE_DEFINITION
        )

    def is_type_extension(self) -> Bool:
        """Return True for the six type extension kinds.

        Returns:
            Whether the kind extends a named type.
        """
        return (
            self == Kind.SCALAR_TYPE_EXTENSION
            or self == Kind.OBJECT_TYPE_EXTENSION
            or self == Kind.INTERFACE_TYPE_EXTENSION
            or self == Kind.UNION_TYPE_EXTENSION
            or self == Kind.ENUM_TYPE_EXTENSION
            or self == Kind.INPUT_OBJECT_TYPE_EXTENSION
        )

    def is_executable_definition(self) -> Bool:
        """Return True for an operation or a fragment definition.

        Returns:
            Whether the kind is an executable definition.
        """
        return (
            self == Kind.OPERATION_DEFINITION
            or self == Kind.FRAGMENT_DEFINITION
        )

    def is_type_system_definition(self) -> Bool:
        """Return True for a schema, type or directive definition.

        Returns:
            Whether the kind is a type system definition.
        """
        return (
            self == Kind.SCHEMA_DEFINITION
            or self.is_type_definition()
            or self == Kind.DIRECTIVE_DEFINITION
        )

    def is_type_system_extension(self) -> Bool:
        """Return True for a schema, type or directive extension.

        Returns:
            Whether the kind is a type system extension.
        """
        return (
            self == Kind.SCHEMA_EXTENSION
            or self.is_type_extension()
            or self == Kind.DIRECTIVE_EXTENSION
        )

    def is_value(self) -> Bool:
        """Return True for a value literal or a variable.

        Returns:
            Whether the kind is a graphql-js `ValueNode`.
        """
        return self.value >= Kind.VARIABLE.value and self.value <= 18

    def is_type(self) -> Bool:
        """Return True for a named, list or non-null type reference.

        Returns:
            Whether the kind is a graphql-js `TypeNode`.
        """
        return (
            self == Kind.NAMED_TYPE
            or self == Kind.LIST_TYPE
            or self == Kind.NON_NULL_TYPE
        )

    def is_selection(self) -> Bool:
        """Return True for a field, a fragment spread or an inline fragment.

        Returns:
            Whether the kind is a graphql-js `SelectionNode`.
        """
        return (
            self == Kind.FIELD
            or self == Kind.FRAGMENT_SPREAD
            or self == Kind.INLINE_FRAGMENT
        )

    def is_schema_coordinate(self) -> Bool:
        """Return True for the five schema coordinate kinds.

        Returns:
            Whether the kind is a graphql-js `SchemaCoordinateNode`.
        """
        return self.value >= 44 and self.value <= 48

    def write_to(self, mut writer: Some[Writer]):
        """Write the graphql-js `Kind` string.

        Args:
            writer: The destination.
        """
        writer.write(self.text())


@fieldwise_init
struct Role(Equatable, ImplicitlyCopyable, Writable):
    """The property of its parent that a node fills."""

    var value: UInt8
    """The role's index; see `is_valid`."""

    comptime ROOT = Role(0)
    """The root of a document."""
    comptime DEFINITION = Role(1)
    """Fills the `definitions` property."""
    comptime DESCRIPTION = Role(2)
    """Fills the `description` property."""
    comptime NAME = Role(3)
    """Fills the `name` property."""
    comptime ALIAS = Role(4)
    """Fills the `alias` property."""
    comptime VARIABLE_DEFINITION = Role(5)
    """Fills the `variableDefinitions` property."""
    comptime VARIABLE = Role(6)
    """Fills the `variable` property."""
    comptime TYPE = Role(7)
    """Fills the `type` property."""
    comptime DEFAULT_VALUE = Role(8)
    """Fills the `defaultValue` property."""
    comptime DIRECTIVE = Role(9)
    """Fills the `directives` property."""
    comptime ARGUMENT = Role(10)
    """Fills the `arguments` property."""
    comptime VALUE = Role(11)
    """Fills the `value` property."""
    comptime FIELD = Role(12)
    """Fills the `fields` property."""
    comptime SELECTION_SET = Role(13)
    """Fills the `selectionSet` property."""
    comptime SELECTION = Role(14)
    """Fills the `selections` property."""
    comptime TYPE_CONDITION = Role(15)
    """Fills the `typeCondition` property."""
    comptime INTERFACE = Role(16)
    """Fills the `interfaces` property."""
    comptime MEMBER_TYPE = Role(17)
    """Fills the `types` property."""
    comptime ENUM_VALUE = Role(18)
    """Fills the `values` property."""
    comptime OPERATION_TYPE = Role(19)
    """Fills the `operationTypes` property."""
    comptime LOCATION = Role(20)
    """Fills the `locations` property."""
    comptime MEMBER_NAME = Role(21)
    """Fills the `memberName` property."""
    comptime ARGUMENT_NAME = Role(22)
    """Fills the `argumentName` property."""
    comptime FIELD_NAME = Role(23)
    """Fills the `fieldName` property."""
    comptime LIST_ITEM = Role(24)
    """Fills the `values` property of a `ListValue`."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the roles.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 24

    def text(self) -> StaticString:
        """Return the graphql-js property name of the role.

        Returns:
            Such as `selectionSet`, or `<invalid>`.
        """
        comptime names: Array[StaticString, 25] = [
            "root",
            "definitions",
            "description",
            "name",
            "alias",
            "variableDefinitions",
            "variable",
            "type",
            "defaultValue",
            "directives",
            "arguments",
            "value",
            "fields",
            "selectionSet",
            "selections",
            "typeCondition",
            "interfaces",
            "types",
            "values",
            "operationTypes",
            "locations",
            "memberName",
            "argumentName",
            "fieldName",
            "values",
        ]
        if not self.is_valid():
            return "<invalid>"
        return materialize[names]()[Int(self.value)]

    def write_to(self, mut writer: Some[Writer]):
        """Write the graphql-js property name.

        Args:
            writer: The destination.
        """
        writer.write(self.text())


@fieldwise_init
struct OperationType(Equatable, ImplicitlyCopyable, Writable):
    """The type of an operation: query, mutation or subscription."""

    var value: UInt8
    """The type's index; see `is_valid`."""

    comptime QUERY = OperationType(0)
    """A `query` operation."""
    comptime MUTATION = OperationType(1)
    """A `mutation` operation."""
    comptime SUBSCRIPTION = OperationType(2)
    """A `subscription` operation."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the three types.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 2

    def text(self) -> StaticString:
        """Return the keyword: `query`, `mutation` or `subscription`.

        Returns:
            The keyword, or `<invalid>`.
        """
        if self == OperationType.QUERY:
            return "query"
        if self == OperationType.MUTATION:
            return "mutation"
        if self == OperationType.SUBSCRIPTION:
            return "subscription"
        return "<invalid>"

    def write_to(self, mut writer: Some[Writer]):
        """Write the keyword.

        Args:
            writer: The destination.
        """
        writer.write(self.text())


# Node flags. The low bits depend on the kind.
comptime FLAG_BLOCK: UInt8 = 1
"""A `StringValue` written as a block string."""
comptime FLAG_TRUE: UInt8 = 1
"""A `BooleanValue` that is true."""
comptime FLAG_REPEATABLE: UInt8 = 1
"""A `DirectiveDefinition` marked `repeatable`."""
comptime FLAG_EXTRA: UInt8 = 128
"""The node's text was added by a program, after the source bytes, and is
already decoded."""
comptime NO_NODE = -1
"""The index that names no node."""


@always_inline
def role_bit(role: Role) -> UInt32:
    """Return a role's bit in `Node.roles`.

    Args:
        role: The role.

    Returns:
        `1 << role`.
    """
    return UInt32(1) << UInt32(role.value)


@fieldwise_init
struct Node(ImplicitlyCopyable, Movable):
    """One AST node: its kind, role, flags, range and links."""

    var kind: Kind
    """What the node is."""
    var role: Role
    """The property of its parent that it fills."""
    var flags: UInt8
    """Kind-specific bits, and `FLAG_EXTRA`."""
    var start: Int32
    """The byte offset where the node starts, as graphql-js `loc.start`."""
    var end: Int32
    """The byte offset after the node, as graphql-js `loc.end`."""
    var first: Int32
    """The first child, or `NO_NODE`."""
    var last: Int32
    """The last child, or `NO_NODE`."""
    var next: Int32
    """The next sibling, or `NO_NODE`."""
    var roles: UInt32
    """One bit per `Role` that a child has, so a lookup of a property the
    node lacks needs no scan. The parser and the builder keep it exact: a
    bit is set when a child with the role is added, and a child's role
    changes only together with its parent's bits."""


struct Document(Copyable, Movable):
    """A parsed or built GraphQL document: its source and its nodes."""

    var source: Source
    """The source the nodes were parsed from."""
    var nodes: List[Node]
    """Every node, in preorder for a parsed document."""
    var root: Int
    """The index of the root node: the `Document`, or a parsed value."""
    var token_count: Int
    """How many tokens the parser read, as graphql-js `tokenCount`."""

    def __init__(
        out self, var source: Source, var nodes: List[Node], root: Int
    ):
        """Wrap parsed nodes.

        Args:
            source: The source.
            nodes: The nodes.
            root: The root node's index.
        """
        self.source = source^
        self.nodes = nodes^
        self.root = root
        self.token_count = 0

    def __init__(out self):
        """Start an empty document whose root is a `Document` node."""
        self.source = Source("")
        self.nodes = List[Node]()
        self.root = 0
        self.token_count = 0
        _ = self.add(Kind.DOCUMENT, Role.ROOT)

    # --- reading --------------------------------------------------------
    #
    # Every reader takes a node index that this document gave out. The
    # index is not checked again: a reader runs once per node in every walk.

    @always_inline
    def _node(self, node: Int) -> Node:
        """Return a copy of a node, without a bounds check."""
        return self.nodes.unsafe_ptr()[unsafe_offset=node]

    @always_inline
    def kind(self, node: Int) -> Kind:
        """Return a node's kind.

        Args:
            node: The node's index.

        Returns:
            Its kind.
        """
        return self._node(node).kind

    @always_inline
    def role(self, node: Int) -> Role:
        """Return the property of its parent that a node fills.

        Args:
            node: The node's index.

        Returns:
            Its role.
        """
        return self._node(node).role

    @always_inline
    def first_child(self, node: Int) -> Int:
        """Return a node's first child.

        Args:
            node: The node's index.

        Returns:
            The child's index, or `NO_NODE`.
        """
        return Int(self._node(node).first)

    @always_inline
    def next_sibling(self, node: Int) -> Int:
        """Return a node's next sibling.

        Args:
            node: The node's index.

        Returns:
            The sibling's index, or `NO_NODE`.
        """
        return Int(self._node(node).next)

    @always_inline
    def start(self, node: Int) -> Int:
        """Return the byte offset where a node starts.

        Args:
            node: The node's index.

        Returns:
            The graphql-js `loc.start`.
        """
        return Int(self._node(node).start)

    @always_inline
    def end(self, node: Int) -> Int:
        """Return the byte offset after a node.

        Args:
            node: The node's index.

        Returns:
            The graphql-js `loc.end`.
        """
        return Int(self._node(node).end)

    def location(self, node: Int) -> SourceLocation:
        """Return the line and column where a node starts.

        Args:
            node: The node's index.

        Returns:
            The one-based location in the source.
        """
        return self.source.get_location(self.start(node))

    def child(self, node: Int, role: Role) -> Int:
        """Return the first child of a node with a role.

        Args:
            node: The parent's index.
            role: The property to find.

        Returns:
            The child's index, or `NO_NODE`.
        """
        var found = self._node(node)
        if found.roles & role_bit(role) == 0:
            return NO_NODE
        # The bit is exact, so a child with the role is there.
        var current = Int(found.first)
        while self._node(current).role != role:
            current = Int(self._node(current).next)
        return current

    def next_with_role(self, node: Int) -> Int:
        """Return the next sibling that has the same role as a node.

        Args:
            node: A child's index.

        Returns:
            The sibling's index, or `NO_NODE`.
        """
        var role = self._node(node).role
        var current = Int(self._node(node).next)
        while current != NO_NODE:
            if self._node(current).role == role:
                return current
            current = Int(self._node(current).next)
        return NO_NODE

    def children(self, node: Int, role: Role) -> List[Int]:
        """Return the children of a node with a role, in order.

        Args:
            node: The parent's index.
            role: The property to list.

        Returns:
            The children's indices; empty when there are none.
        """
        var out = List[Int]()
        var current = Int(self._node(node).first)
        while current != NO_NODE:
            if self._node(current).role == role:
                out.append(current)
            current = Int(self._node(current).next)
        return out^

    def count(self, node: Int, role: Role) -> Int:
        """Return how many children of a node have a role.

        Args:
            node: The parent's index.
            role: The property to count.

        Returns:
            The count.
        """
        var total = 0
        var current = Int(self._node(node).first)
        while current != NO_NODE:
            if self._node(current).role == role:
                total += 1
            current = Int(self._node(current).next)
        return total

    def text(self, node: Int) -> StringSlice[origin_of(self.source.bytes)]:
        """Return a node's own text.

        That is the value of a `Name`, an `IntValue`, a `FloatValue` and an
        `EnumValue`. A `StringValue` gives its source text, quotes and
        escapes included, or its decoded value when a program added it.

        Args:
            node: The node's index.

        Returns:
            A view of the text.
        """
        var found = self._node(node)
        return StringSlice(
            unsafe_from_utf8=Span(self.source.bytes)[
                Int(found.start) : Int(found.end)
            ]
        )

    def name(self, node: Int) -> StringSlice[origin_of(self.source.bytes)]:
        """Return the text of a node's `name` child.

        Args:
            node: The parent's index.

        Returns:
            The name, or empty when the node has none.
        """
        var found = self.child(node, Role.NAME)
        if found == NO_NODE:
            return StringSlice(unsafe_from_utf8=Span(self.source.bytes)[0:0])
        return self.text(found)

    def has_text(self, node: Int, text: StringSlice) -> Bool:
        """Return True if a node's own text equals some text.

        Args:
            node: The node's index.
            text: The text to compare.

        Returns:
            Whether the bytes are equal.
        """
        return self.text(node) == text

    def operation(self, node: Int) -> OperationType:
        """Return the operation type of an operation or operation type
        definition.

        Args:
            node: The node's index.

        Returns:
            Its operation type.
        """
        return OperationType(self._node(node).flags & 3)

    def is_block(self, node: Int) -> Bool:
        """Return True if a `StringValue` is a block string.

        Args:
            node: The node's index.

        Returns:
            The graphql-js `block`.
        """
        return self._node(node).flags & FLAG_BLOCK != 0

    def boolean_value(self, node: Int) -> Bool:
        """Return the value of a `BooleanValue`.

        Args:
            node: The node's index.

        Returns:
            The graphql-js `value`.
        """
        return self._node(node).flags & FLAG_TRUE != 0

    def is_repeatable(self, node: Int) -> Bool:
        """Return True if a `DirectiveDefinition` is repeatable.

        Args:
            node: The node's index.

        Returns:
            The graphql-js `repeatable`.
        """
        return self._node(node).flags & FLAG_REPEATABLE != 0

    def string_value(self, node: Int) -> String:
        """Return the decoded value of a `StringValue`.

        Args:
            node: The node's index.

        Returns:
            The graphql-js `value`: escapes decoded, a block string dedented.
        """
        var found = self._node(node)
        if found.flags & FLAG_EXTRA != 0:
            return String(self.text(node))
        if found.flags & FLAG_BLOCK != 0:
            return block_string_value(
                self.source, Int(found.start), Int(found.end)
            )
        return decode_string_value(
            self.source, Int(found.start), Int(found.end)
        )

    def description(self, node: Int) -> String:
        """Return the decoded `description` of a definition.

        Args:
            node: The definition's index.

        Returns:
            The description, or empty when there is none.
        """
        var found = self.child(node, Role.DESCRIPTION)
        if found == NO_NODE:
            return String("")
        return self.string_value(found)

    def has_description(self, node: Int) -> Bool:
        """Return True if a definition has a description.

        Args:
            node: The definition's index.

        Returns:
            Whether a `description` child exists.
        """
        return self.child(node, Role.DESCRIPTION) != NO_NODE

    def definitions(self) -> List[Int]:
        """Return the definitions of the root `Document` node.

        Returns:
            Their indices, in order.
        """
        return self.children(self.root, Role.DEFINITION)

    def named_type(
        self, node: Int
    ) -> StringSlice[origin_of(self.source.bytes)]:
        """Return the name at the bottom of a type reference.

        Args:
            node: A `NamedType`, `ListType` or `NonNullType`.

        Returns:
            The named type's name, under any list and non-null wrappers.
        """
        var current = node
        while self._node(current).kind != Kind.NAMED_TYPE:
            current = Int(self._node(current).first)
        return self.name(current)

    # --- building -------------------------------------------------------

    def add(mut self, kind: Kind, role: Role, flags: UInt8 = 0) -> Int:
        """Add a node that has no children and no parent yet.

        Args:
            kind: The node's kind.
            role: The property of its future parent that it fills.
            flags: The kind-specific bits.

        Returns:
            The new node's index.
        """
        self.nodes.append(
            Node(kind, role, flags, 0, 0, NO_NODE, NO_NODE, NO_NODE, 0)
        )
        return len(self.nodes) - 1

    def add_text(
        mut self, kind: Kind, role: Role, text: StringSlice, flags: UInt8 = 0
    ) -> Int:
        """Add a node whose text a program supplies.

        Args:
            kind: The node's kind: a name, a number, an enum or a string.
            role: The property of its future parent that it fills.
            text: The node's text; the decoded value for a string.
            flags: The kind-specific bits.

        Returns:
            The new node's index.
        """
        var start = len(self.source.bytes)
        self.source.bytes.extend(text.as_bytes())
        self.nodes.append(
            Node(
                kind,
                role,
                flags | FLAG_EXTRA,
                Int32(start),
                Int32(len(self.source.bytes)),
                NO_NODE,
                NO_NODE,
                NO_NODE,
                0,
            )
        )
        return len(self.nodes) - 1

    def append_child(mut self, parent: Int, child: Int):
        """Make a node the last child of another.

        Args:
            parent: The parent's index.
            child: The child's index; it must have no parent.
        """
        var last = Int(self.nodes[parent].last)
        if last == NO_NODE:
            self.nodes[parent].first = Int32(child)
        else:
            self.nodes[last].next = Int32(child)
        self.nodes[parent].last = Int32(child)
        self.nodes[parent].roles |= role_bit(self.nodes[child].role)

    def add_child(
        mut self, parent: Int, kind: Kind, role: Role, flags: UInt8 = 0
    ) -> Int:
        """Add a node as the last child of another.

        Args:
            parent: The parent's index.
            kind: The new node's kind.
            role: The property of the parent that it fills.
            flags: The kind-specific bits.

        Returns:
            The new node's index.
        """
        var node = self.add(kind, role, flags)
        self.append_child(parent, node)
        return node

    def add_name(mut self, parent: Int, role: Role, text: StringSlice) -> Int:
        """Add a `Name` node as the last child of another.

        Args:
            parent: The parent's index.
            role: The property of the parent that it fills, such as `NAME`.
            text: The name.

        Returns:
            The new node's index.
        """
        var node = self.add_text(Kind.NAME, role, text)
        self.append_child(parent, node)
        return node

    def copy_subtree(mut self, other: Document, node: Int, role: Role) -> Int:
        """Copy a node and its descendants from another document.

        Text is copied after this document's source bytes, so the copy
        does not need the other document's source.

        Args:
            other: The document to copy from.
            node: The node to copy.
            role: The role the copy fills in its future parent.

        Returns:
            The copy's index; it has no parent.
        """
        var root = self._copy_node(other, node, role)
        # Pairs of (node in `other`, its copy), visited depth first. A
        # parent's children are pushed last first, so they are copied, and
        # appended to the parent's copy, in order.
        var stack: List[Int] = [node, root]
        while len(stack) > 0:
            var copy = stack.pop()
            var original = stack.pop()
            var children = List[Int]()
            var current = other.first_child(original)
            while current != NO_NODE:
                children.append(current)
                current = other.next_sibling(current)
            var copies = List[Int](capacity=len(children))
            for ref child in children:
                var child_copy = self._copy_node(
                    other, child, other.role(child)
                )
                self.append_child(copy, child_copy)
                copies.append(child_copy)
            for index in range(len(children) - 1, -1, -1):
                stack.append(children[index])
                stack.append(copies[index])
        return root

    def _copy_node(mut self, other: Document, node: Int, role: Role) -> Int:
        """Copy one node, with its text and flags but not its children."""
        ref found = other.nodes[node]
        var kind = found.kind
        if (
            kind == Kind.NAME
            or kind == Kind.INT
            or kind == Kind.FLOAT
            or kind == Kind.ENUM
        ):
            return self.add_text(kind, role, other.text(node))
        if kind == Kind.STRING:
            return self.add_text(
                kind,
                role,
                other.string_value(node),
                found.flags & FLAG_BLOCK,
            )
        return self.add(kind, role, found.flags & ~FLAG_EXTRA)

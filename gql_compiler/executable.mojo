# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The executable document model of apollo-compiler.

Port of apollo-compiler 1.33.0 (`b7eee5c`) `src/executable/mod.rs` and
`src/executable/from_ast.rs`, under the MIT arm of its MIT OR Apache-2.0
license.

An `ExecutableDocument` keeps the documents it was built from, as a
`Schema` does. An operation, a fragment and a selection point into them
by a document index and a node index. Nothing is copied out of the AST.
A field selection also holds its field definition, as a `Component` of
the schema.

The selection sets are in one list, and the selections of each set are a
run in one other list. A set is complete before its parent, so a parent
comes after its children in `selection_sets`.

**Differences from upstream.**

- An operation, a fragment and a selection name an AST node by index
  instead of holding a reference counted pointer.
- The builder takes the schema in each `add_ast` call. apollo-compiler
  keeps a reference to it in the builder.
- A schema is always given. apollo-compiler can build without one, for
  `validate_standalone_executable`.
- The type of a selection set is the index of the type in
  `Schema.types`, or `NOT_FOUND` when an invalid schema names an
  undefined type. Upstream keeps the type's name.
- A meta field (`__typename`, `__schema` or `__type`) has a `MetaField`
  kind and no `Component`. Upstream keeps a static field definition.
- A build error has no `SelectionPath`. Its message is the same.
- `root_fields` and `all_fields` return a `List`. Upstream returns a lazy
  iterator.
- `parse` raises on a syntax error. Upstream records it in the
  diagnostics.
- A GraphQL 2025 directive extension is reported as
  `BuildErrorKind.TYPE_SYSTEM_DEFINITION`, with the description "a
  directive extension".
"""

from gql_language.ast import Document, Kind, NO_NODE, OperationType, Role
from gql_language.names import NOT_FOUND, NameTable
from gql_language.parser import parse
from gql_compiler.schema import Component, DEFINITION_ORIGIN, Schema, TypeKind

comptime NO_SELECTION_SET = Int32(-1)
"""The selection set of a fragment spread, which has none."""

comptime _OPERATIONS = -1
"""The `NameTable` owner of the named operations."""

comptime _FRAGMENTS = -2
"""The `NameTable` owner of the fragments."""


struct SelectionKind(Equatable, ImplicitlyCopyable, Writable):
    """A variant of upstream `Selection`."""

    var value: UInt8
    """The variant's index; see `is_valid`."""

    comptime FIELD = SelectionKind(0)
    """`Selection::Field`."""
    comptime FRAGMENT_SPREAD = SelectionKind(1)
    """`Selection::FragmentSpread`."""
    comptime INLINE_FRAGMENT = SelectionKind(2)
    """`Selection::InlineFragment`."""

    @always_inline
    def __init__(out self, value: UInt8):
        """Make a selection kind from its index.

        Args:
            value: The index.
        """
        self.value = value

    def is_valid(self) -> Bool:
        """Return True for one of the variants.

        Returns:
            Whether the index names a variant.
        """
        return self.value <= 2

    def write_to(self, mut writer: Some[Writer]):
        """Write the index.

        Args:
            writer: The writer.
        """
        writer.write("SelectionKind(", self.value, ")")


struct MetaField(Equatable, ImplicitlyCopyable, Writable):
    """A meta field of upstream `MetaFieldDefinitions`, or none."""

    var value: UInt8
    """The field's index; see `is_valid`."""

    comptime NONE = MetaField(0)
    """A field that the schema defines."""
    comptime TYPENAME = MetaField(1)
    """`__typename: String!`."""
    comptime SCHEMA = MetaField(2)
    """`__schema: __Schema!`."""
    comptime TYPE = MetaField(3)
    """`__type(name: String!): __Type`."""

    @always_inline
    def __init__(out self, value: UInt8):
        """Make a meta field from its index.

        Args:
            value: The index.
        """
        self.value = value

    def is_valid(self) -> Bool:
        """Return True for one of the fields, or for none.

        Returns:
            Whether the index names a field.
        """
        return self.value <= 3

    def type_name(self) -> StaticString:
        """Return the name of the field's type.

        Returns:
            `String`, `__Schema` or `__Type`, or empty for none.
        """
        if self == MetaField.TYPENAME:
            return "String"
        if self == MetaField.SCHEMA:
            return "__Schema"
        if self == MetaField.TYPE:
            return "__Type"
        return ""

    def write_to(self, mut writer: Some[Writer]):
        """Write the index.

        Args:
            writer: The writer.
        """
        writer.write("MetaField(", self.value, ")")


@fieldwise_init
struct Selection(ImplicitlyCopyable, Movable):
    """A field, a fragment spread or an inline fragment: upstream
    `Selection`."""

    var kind: SelectionKind
    """The variant."""
    var source: Int32
    """The index of the document in `ExecutableDocument.sources`."""
    var node: Int32
    """The `Field`, `FragmentSpread` or `InlineFragment` node."""
    var definition: Component
    """The field definition in the schema. Its node is `NO_NODE` for a
    meta field and for a selection that is not a field."""
    var meta: MetaField
    """The meta field, or `MetaField.NONE`."""
    var selection_set: Int32
    """The index in `ExecutableDocument.selection_sets`, or
    `NO_SELECTION_SET` for a fragment spread."""


@fieldwise_init
struct SelectionSet(ImplicitlyCopyable, Movable):
    """A selection set and its type: upstream `SelectionSet`."""

    var ty: Int32
    """The index of the type in `Schema.types`, or `NOT_FOUND`."""
    var start: Int32
    """The first selection in `ExecutableDocument.selections`."""
    var count: Int32
    """How many selections follow it."""


@fieldwise_init
struct Operation(ImplicitlyCopyable, Movable):
    """An operation: upstream `Operation`."""

    var source: Int32
    """The index of the document in `ExecutableDocument.sources`."""
    var node: Int32
    """The `OperationDefinition` node."""
    var operation_type: OperationType
    """Query, mutation or subscription."""
    var selection_set: Int32
    """The index in `ExecutableDocument.selection_sets`."""


@fieldwise_init
struct Fragment(ImplicitlyCopyable, Movable):
    """A named fragment: upstream `Fragment`."""

    var source: Int32
    """The index of the document in `ExecutableDocument.sources`."""
    var node: Int32
    """The `FragmentDefinition` node."""
    var selection_set: Int32
    """The index in `ExecutableDocument.selection_sets`. Its type is the
    type condition."""


struct BuildErrorKind(Equatable, ImplicitlyCopyable, Writable):
    """A variant of upstream executable `BuildError` that `from_ast`
    emits."""

    var value: UInt8
    """The variant's index; see `is_valid`."""

    comptime TYPE_SYSTEM_DEFINITION = BuildErrorKind(0)
    """`TypeSystemDefinition`."""
    comptime AMBIGUOUS_ANONYMOUS_OPERATION = BuildErrorKind(1)
    """`AmbiguousAnonymousOperation`."""
    comptime OPERATION_NAME_COLLISION = BuildErrorKind(2)
    """`OperationNameCollision`."""
    comptime FRAGMENT_NAME_COLLISION = BuildErrorKind(3)
    """`FragmentNameCollision`."""
    comptime UNDEFINED_ROOT_OPERATION = BuildErrorKind(4)
    """`UndefinedRootOperation`."""
    comptime UNDEFINED_TYPE_IN_NAMED_FRAGMENT_TYPE_CONDITION = BuildErrorKind(5)
    """`UndefinedTypeInNamedFragmentTypeCondition`."""
    comptime UNDEFINED_TYPE_IN_INLINE_FRAGMENT_TYPE_CONDITION = BuildErrorKind(
        6
    )
    """`UndefinedTypeInInlineFragmentTypeCondition`."""
    comptime SUBSELECTION_ON_SCALAR_TYPE = BuildErrorKind(7)
    """`SubselectionOnScalarType`."""
    comptime SUBSELECTION_ON_ENUM_TYPE = BuildErrorKind(8)
    """`SubselectionOnEnumType`."""
    comptime UNDEFINED_FIELD = BuildErrorKind(9)
    """`UndefinedField`."""

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
        return self.value <= 9

    def write_to(self, mut writer: Some[Writer]):
        """Write the index.

        Args:
            writer: The writer.
        """
        writer.write("BuildErrorKind(", self.value, ")")


@fieldwise_init
struct BuildError(Copyable, Movable, Writable):
    """One error of an executable document build: upstream executable
    `BuildError` and its location."""

    var kind: BuildErrorKind
    """The variant."""
    var source: Int32
    """The index of the document in `ExecutableDocument.sources`."""
    var node: Int32
    """The node the error points at."""
    var name: String
    """The operation, fragment or field name, or the operation type."""
    var type_name: String
    """The type that the error names."""
    var describe: String
    """The `describe` text of a type system definition."""

    def message(self) -> String:
        """Return the upstream message.

        Returns:
            The text of the upstream `#[error(...)]` attribute.
        """
        var kind = self.kind
        if kind == BuildErrorKind.TYPE_SYSTEM_DEFINITION:
            return String(
                "an executable document must not contain ", self.describe
            )
        if kind == BuildErrorKind.AMBIGUOUS_ANONYMOUS_OPERATION:
            return (
                "anonymous operation cannot be selected when the document"
                " contains other operations"
            )
        if kind == BuildErrorKind.OPERATION_NAME_COLLISION:
            return String(
                "the operation `",
                self.name,
                "` is defined multiple times in the document",
            )
        if kind == BuildErrorKind.FRAGMENT_NAME_COLLISION:
            return String(
                "the fragment `",
                self.name,
                "` is defined multiple times in the document",
            )
        if kind == BuildErrorKind.UNDEFINED_ROOT_OPERATION:
            return String(
                "`", self.name, "` root operation type is not defined"
            )
        if (
            kind
            == BuildErrorKind.UNDEFINED_TYPE_IN_NAMED_FRAGMENT_TYPE_CONDITION
        ):
            return String(
                "type condition `",
                self.type_name,
                "` of fragment `",
                self.name,
                "` is not a type defined in the schema",
            )
        if (
            kind
            == BuildErrorKind.UNDEFINED_TYPE_IN_INLINE_FRAGMENT_TYPE_CONDITION
        ):
            return String(
                "type condition `",
                self.type_name,
                "` of inline fragment is not a type defined in the schema",
            )
        if kind == BuildErrorKind.SUBSELECTION_ON_SCALAR_TYPE:
            return String(
                "field selection of scalar type `",
                self.type_name,
                "` must not have subselections",
            )
        if kind == BuildErrorKind.SUBSELECTION_ON_ENUM_TYPE:
            return String(
                "field selection of enum type `",
                self.type_name,
                "` must not have subselections",
            )
        return String(
            "type `",
            self.type_name,
            "` does not have a field `",
            self.name,
            "`",
        )

    def write_to(self, mut writer: Some[Writer]):
        """Write the message.

        Args:
            writer: The writer.
        """
        writer.write(self.message())


def _operation_name(operation: OperationType) -> String:
    """Return upstream `OperationType::name`.

    Args:
        operation: The operation type.

    Returns:
        `query`, `mutation` or `subscription`.
    """
    if operation == OperationType.MUTATION:
        return "mutation"
    if operation == OperationType.SUBSCRIPTION:
        return "subscription"
    return "query"


def _describe(kind: Kind) -> String:
    """Return upstream `Definition::describe` for a type system definition.

    Args:
        kind: The definition's kind.

    Returns:
        The description, such as "an object type definition".
    """
    if kind == Kind.DIRECTIVE_DEFINITION:
        return "a directive definition"
    if kind == Kind.SCALAR_TYPE_DEFINITION:
        return "a scalar type definition"
    if kind == Kind.OBJECT_TYPE_DEFINITION:
        return "an object type definition"
    if kind == Kind.INTERFACE_TYPE_DEFINITION:
        return "an interface type definition"
    if kind == Kind.UNION_TYPE_DEFINITION:
        return "a union type definition"
    if kind == Kind.ENUM_TYPE_DEFINITION:
        return "an enum type definition"
    if kind == Kind.INPUT_OBJECT_TYPE_DEFINITION:
        return "an input object type definition"
    if kind == Kind.SCHEMA_DEFINITION:
        return "a schema definition"
    if kind == Kind.SCHEMA_EXTENSION:
        return "a schema extension"
    if kind == Kind.SCALAR_TYPE_EXTENSION:
        return "a scalar type extension"
    if kind == Kind.OBJECT_TYPE_EXTENSION:
        return "an object type extension"
    if kind == Kind.INTERFACE_TYPE_EXTENSION:
        return "an interface type extension"
    if kind == Kind.UNION_TYPE_EXTENSION:
        return "a union type extension"
    if kind == Kind.ENUM_TYPE_EXTENSION:
        return "an enum type extension"
    if kind == Kind.INPUT_OBJECT_TYPE_EXTENSION:
        return "an input object type extension"
    return "a directive extension"


struct ExecutableDocument(Copyable, Movable):
    """Operations and fragments, built against a schema: upstream
    `ExecutableDocument`."""

    var sources: List[Document]
    """The documents the operations and the fragments came from."""
    var operations: List[Operation]
    """The anonymous operation and the named operations, in definition
    order: upstream `operations.anonymous` and `operations.named`."""
    var anonymous: Int
    """The index of the anonymous operation in `operations`, or
    `NOT_FOUND`."""
    var fragments: List[Fragment]
    """The named fragments, in definition order: upstream `fragments`."""
    var selection_sets: List[SelectionSet]
    """Every selection set. A child set comes before its parent."""
    var selections: List[Selection]
    """The storage of the selections of every set."""
    var names: NameTable
    """The named operations under owner -1, and the fragments under
    owner -2."""

    def __init__(out self):
        """Make an empty document with no sources."""
        self.sources = List[Document]()
        self.operations = List[Operation]()
        self.anonymous = NOT_FOUND
        self.fragments = List[Fragment]()
        self.selection_sets = List[SelectionSet]()
        self.selections = List[Selection]()
        self.names = NameTable(capacity=16)

    @staticmethod
    def from_ast(
        schema: Schema, var document: Document
    ) -> Tuple[ExecutableDocument, List[BuildError]]:
        """Build a document from an AST: upstream `from_ast`.

        Args:
            schema: The schema to build against.
            document: An executable document. It is moved in, and its type
                system definitions are errors.

        Returns:
            The document, and the errors of the build.
        """
        var builder = ExecutableDocumentBuilder()
        builder.add_ast(schema, document^)
        return builder^.build()

    @staticmethod
    def parse(
        schema: Schema, text: StringSlice
    ) raises -> Tuple[ExecutableDocument, List[BuildError]]:
        """Parse and build a document: upstream `parse`.

        Args:
            schema: The schema to build against.
            text: The executable document text.

        Returns:
            The document, and the errors of the build.

        Raises:
            GraphQLError: If the text is not a valid document. Upstream
                records syntax errors in the diagnostics instead.
        """
        return ExecutableDocument.from_ast(schema, parse(text))

    def node_name(
        self, source: Int, node: Int
    ) -> StringSlice[origin_of(self.sources)]:
        """Return the name of a node in one of the sources.

        Args:
            source: The index of the document.
            node: A node with a `name` child.

        Returns:
            A view of the name, or empty when the node has none.
        """
        return rebind[StringSlice[origin_of(self.sources)]](
            self.sources[source].name(node)
        )

    def operation_name(
        self, operation: Operation
    ) -> StringSlice[origin_of(self.sources)]:
        """Return the name of an operation.

        Args:
            operation: An operation of this document.

        Returns:
            A view of the name, or empty for the anonymous operation.
        """
        return self.node_name(Int(operation.source), Int(operation.node))

    def fragment_name(
        self, fragment: Fragment
    ) -> StringSlice[origin_of(self.sources)]:
        """Return the name of a fragment.

        Args:
            fragment: A fragment of this document.

        Returns:
            A view of the name.
        """
        return self.node_name(Int(fragment.source), Int(fragment.node))

    def named_operation_count(self) -> Int:
        """Return how many named operations the document has.

        Returns:
            The size of upstream `operations.named`.
        """
        if self.anonymous == NOT_FOUND:
            return len(self.operations)
        return len(self.operations) - 1

    def get_operation(self, name: Optional[String]) raises -> Operation:
        """Return the operation to run: upstream `operations.get`.

        Args:
            name: The requested `operationName`, or None.

        Returns:
            The named operation, or the only operation when no name is
            requested.

        Raises:
            Error: If there is no operation of that name, or if no name is
                requested and the document has more or fewer than one
                operation.
        """
        if name:
            var index = self.names.find(_OPERATIONS, name.value())
            if index == NOT_FOUND:
                raise Error("No operation named '", name.value(), "'")
            return self.operations[index]
        if len(self.operations) != 1:
            raise Error(
                "Ambiguous request: multiple operations but no specified"
                " `operationName`"
            )
        return self.operations[0]

    def get_fragment(self, name: StringSlice) -> Int:
        """Return the index of a fragment: upstream `fragments.get`.

        Args:
            name: The fragment's name.

        Returns:
            The index in `fragments`, or `NOT_FOUND`.
        """
        return self.names.find(_FRAGMENTS, name)

    def selection_count(self, selection_set: Int) -> Int:
        """Return how many selections a set has.

        Args:
            selection_set: The index in `selection_sets`.

        Returns:
            The number of selections.
        """
        return Int(self.selection_sets[selection_set].count)

    def selection(self, selection_set: Int, position: Int) -> Selection:
        """Return one selection of a set.

        Args:
            selection_set: The index in `selection_sets`.
            position: The selection's position, from 0.

        Returns:
            The field, the fragment spread or the inline fragment.
        """
        return self.selections[
            Int(self.selection_sets[selection_set].start) + position
        ]

    def selection_name(
        self, selection: Selection
    ) -> StringSlice[origin_of(self.sources)]:
        """Return the name of a field or of a spread fragment.

        Args:
            selection: A selection of this document.

        Returns:
            The field name or the fragment name, or empty for an inline
            fragment.
        """
        return self.node_name(Int(selection.source), Int(selection.node))

    def response_key(
        self, selection: Selection
    ) -> StringSlice[origin_of(self.sources)]:
        """Return the response key of a field: upstream
        `Field::response_key`.

        Args:
            selection: A field selection of this document.

        Returns:
            The alias, or the name when the field has no alias.
        """
        ref document = self.sources[Int(selection.source)]
        var alias = document.child(Int(selection.node), Role.ALIAS)
        if alias == NO_NODE:
            return self.selection_name(selection)
        return rebind[StringSlice[origin_of(self.sources)]](
            document.text(alias)
        )

    def type_condition(
        self, selection: Selection
    ) -> StringSlice[origin_of(self.sources)]:
        """Return the type condition of an inline fragment.

        Args:
            selection: An inline fragment of this document.

        Returns:
            The type condition, or empty when it has none.
        """
        ref document = self.sources[Int(selection.source)]
        var condition = document.child(Int(selection.node), Role.TYPE_CONDITION)
        if condition == NO_NODE:
            # An inline fragment has no `name` child, so this is empty.
            return self.selection_name(selection)
        return rebind[StringSlice[origin_of(self.sources)]](
            document.name(condition)
        )

    def root_fields(self, selection_set: Int) -> List[Selection]:
        """Return the fields at the root of the response: upstream
        `SelectionSet::root_fields`.

        Args:
            selection_set: The index in `selection_sets`.

        Returns:
            The fields, through inline fragments and fragment spreads but
            not through field subselections. A named fragment is walked
            once, and an undefined one is skipped.
        """
        return self._fields(selection_set, False)

    def all_fields(self, selection_set: Int) -> List[Selection]:
        """Return every field selection: upstream
        `SelectionSet::all_fields`.

        Args:
            selection_set: The index in `selection_sets`.

        Returns:
            The fields, depth first, with each field before its
            subselections. A named fragment is walked once, and an
            undefined one is skipped.
        """
        return self._fields(selection_set, True)

    def is_introspection(self, operation: Operation) -> Bool:
        """Return True for a query that selects only meta fields: upstream
        `Operation::is_introspection`.

        Args:
            operation: An operation of this document.

        Returns:
            Whether it is a query and each root field is `__type`,
            `__schema` or `__typename`.
        """
        if operation.operation_type != OperationType.QUERY:
            return False
        var fields = self.root_fields(Int(operation.selection_set))
        var index = 0
        while index < len(fields):
            if fields[index].meta == MetaField.NONE:
                return False
            index += 1
        return True

    def _fields(self, selection_set: Int, deep: Bool) -> List[Selection]:
        """Walk the fields of a set, as upstream `root_fields` and
        `all_fields` do."""
        var out = List[Selection]()
        var seen = List[Bool](length=len(self.fragments), fill=False)
        var sets = List[Int]()
        var positions = List[Int]()
        sets.append(selection_set)
        positions.append(0)
        while len(sets) > 0:
            var top = len(sets) - 1
            var current = sets[top]
            var position = positions[top]
            if position == self.selection_count(current):
                _ = sets.pop()
                _ = positions.pop()
                continue
            positions[top] = position + 1
            var selection = self.selection(current, position)
            var next = NOT_FOUND
            if selection.kind == SelectionKind.FIELD:
                out.append(selection)
                if deep:
                    next = Int(selection.selection_set)
            elif selection.kind == SelectionKind.INLINE_FRAGMENT:
                next = Int(selection.selection_set)
            else:
                var fragment = self.get_fragment(self.selection_name(selection))
                if fragment != NOT_FOUND and not seen[fragment]:
                    seen[fragment] = True
                    next = Int(self.fragments[fragment].selection_set)
            if next != NOT_FOUND:
                sets.append(next)
                positions.append(0)
        return out^


struct ExecutableDocumentBuilder(Movable):
    """Build an `ExecutableDocument` from one or more AST documents:
    upstream `ExecutableDocumentBuilder`."""

    var document: ExecutableDocument
    """The document being built."""
    var errors: List[BuildError]
    """The errors so far: upstream `DiagnosticList`."""
    var multiple_anonymous: Bool
    """Whether a second anonymous operation was seen."""
    var _stack: List[Selection]
    """The selections of the sets that are not complete yet."""
    var _query_type: Int
    """The index of the query root type in the current schema."""
    var standalone: Bool
    """Whether to build with no schema, as upstream does for
    `validate_standalone_executable`: an operation and a fragment are kept
    when their type is not defined, and their selection sets have the
    type `NOT_FOUND`."""

    def __init__(out self, standalone: Bool = False):
        """Make a builder with an empty document.

        Args:
            standalone: Whether to build with no schema.
        """
        self.document = ExecutableDocument()
        self.errors = List[BuildError]()
        self.multiple_anonymous = False
        self._stack = List[Selection]()
        self._query_type = NOT_FOUND
        self.standalone = standalone

    def parse(mut self, schema: Schema, text: StringSlice) raises:
        """Parse a document and add it: upstream `parse`.

        Args:
            schema: The schema to build against.
            text: The executable document text.

        Raises:
            GraphQLError: If the text is not a valid document. Upstream
                records syntax errors in the diagnostics instead.
        """
        self.add_ast(schema, parse(text))

    def add_ast(
        mut self,
        schema: Schema,
        var document: Document,
        type_system_definitions_are_errors: Bool = True,
    ):
        """Add an AST document: upstream `add_ast_document`.

        Args:
            schema: The schema to build against.
            document: An executable document. It is moved in.
            type_system_definitions_are_errors: Whether a type system
                definition is a `TYPE_SYSTEM_DEFINITION` error.
        """
        var source = len(self.document.sources)
        self._query_type = NOT_FOUND
        var query = schema.root_operation(OperationType.QUERY)
        if query:
            self._query_type = schema.get_type(query.value().type_name)
        var nodes = len(document.nodes)
        self.document.selections.reserve(
            len(self.document.selections) + nodes // 4
        )
        self.document.selection_sets.reserve(
            len(self.document.selection_sets) + nodes // 8
        )
        var definition = document.first_child(document.root)
        while definition != NO_NODE:
            var kind = document.kind(definition)
            if kind == Kind.OPERATION_DEFINITION:
                self._add_operation(schema, document, source, definition)
            elif kind == Kind.FRAGMENT_DEFINITION:
                self._add_fragment(schema, document, source, definition)
            elif type_system_definitions_are_errors:
                self._error(
                    BuildErrorKind.TYPE_SYSTEM_DEFINITION,
                    source,
                    definition,
                    describe=_describe(kind),
                )
            definition = document.next_sibling(definition)
        self.document.sources.append(document^)

    def build(var self) -> Tuple[ExecutableDocument, List[BuildError]]:
        """Return the document and the errors: upstream `build`.

        Returns:
            The document built from every added AST document, and the
            errors of the build.
        """
        var document = ExecutableDocument()
        swap(document, self.document)
        var errors = List[BuildError]()
        swap(errors, self.errors)
        return (document^, errors^)

    def _error(
        mut self,
        kind: BuildErrorKind,
        source: Int,
        node: Int,
        name: String = "",
        type_name: String = "",
        describe: String = "",
    ):
        """Record an error."""
        self.errors.append(
            BuildError(
                kind, Int32(source), Int32(node), name, type_name, describe
            )
        )

    def _error_at_anonymous(mut self):
        """Record an ambiguity at the anonymous operation."""
        var operation = self.document.operations[self.document.anonymous]
        self._error(
            BuildErrorKind.AMBIGUOUS_ANONYMOUS_OPERATION,
            Int(operation.source),
            Int(operation.node),
        )

    def _add_operation(
        mut self, schema: Schema, document: Document, source: Int, node: Int
    ):
        """Add an operation definition."""
        var name_node = document.child(node, Role.NAME)
        if name_node != NO_NODE:
            var name = document.text(name_node)
            if self.document.anonymous != NOT_FOUND:
                self._error_at_anonymous()
            if self.document.names.find(_OPERATIONS, name) != NOT_FOUND:
                self._error(
                    BuildErrorKind.OPERATION_NAME_COLLISION,
                    source,
                    name_node,
                    name=String(name),
                )
                return
            var index = self._operation(schema, document, source, node)
            if index != NOT_FOUND:
                _ = self.document.names.insert(_OPERATIONS, name, index)
        elif self.document.anonymous != NOT_FOUND:
            if not self.multiple_anonymous:
                self.multiple_anonymous = True
                self._error_at_anonymous()
            self._error(
                BuildErrorKind.AMBIGUOUS_ANONYMOUS_OPERATION, source, node
            )
        elif len(self.document.operations) > 0:
            self._error(
                BuildErrorKind.AMBIGUOUS_ANONYMOUS_OPERATION, source, node
            )
        else:
            var index = self._operation(schema, document, source, node)
            if index != NOT_FOUND:
                self.document.anonymous = index

    def _operation(
        mut self, schema: Schema, document: Document, source: Int, node: Int
    ) -> Int:
        """Build an operation: upstream `Operation::from_ast`. Return its
        index, or `NOT_FOUND` when its root operation is not defined."""
        var operation_type = document.operation(node)
        var root = schema.root_operation(operation_type)
        if not root and self.standalone:
            var no_type = self._selection_set(
                schema,
                document,
                source,
                NOT_FOUND,
                document.child(node, Role.SELECTION_SET),
            )
            self.document.operations.append(
                Operation(Int32(source), Int32(node), operation_type, no_type)
            )
            return len(self.document.operations) - 1
        if not root:
            self._error(
                BuildErrorKind.UNDEFINED_ROOT_OPERATION,
                source,
                node,
                name=_operation_name(operation_type),
            )
            return NOT_FOUND
        var selection_set = self._selection_set(
            schema,
            document,
            source,
            schema.get_type(root.value().type_name),
            document.child(node, Role.SELECTION_SET),
        )
        self.document.operations.append(
            Operation(Int32(source), Int32(node), operation_type, selection_set)
        )
        return len(self.document.operations) - 1

    def _add_fragment(
        mut self, schema: Schema, document: Document, source: Int, node: Int
    ):
        """Add a fragment definition: upstream `Fragment::from_ast`."""
        var name_node = document.child(node, Role.NAME)
        var name = document.text(name_node)
        if self.document.names.find(_FRAGMENTS, name) != NOT_FOUND:
            self._error(
                BuildErrorKind.FRAGMENT_NAME_COLLISION,
                source,
                name_node,
                name=String(name),
            )
            return
        var condition = document.child(node, Role.TYPE_CONDITION)
        var type_name = document.name(condition)
        var ty = schema.get_type(type_name)
        if ty == NOT_FOUND and not self.standalone:
            self._error(
                BuildErrorKind.UNDEFINED_TYPE_IN_NAMED_FRAGMENT_TYPE_CONDITION,
                source,
                condition,
                name=String(name),
                type_name=String(type_name),
            )
            return
        var selection_set = self._selection_set(
            schema,
            document,
            source,
            ty,
            document.child(node, Role.SELECTION_SET),
        )
        self.document.fragments.append(
            Fragment(Int32(source), Int32(node), selection_set)
        )
        _ = self.document.names.insert(
            _FRAGMENTS, name, len(self.document.fragments) - 1
        )

    def _selection_set(
        mut self,
        schema: Schema,
        document: Document,
        source: Int,
        ty: Int,
        node: Int,
    ) -> Int32:
        """Build a selection set: upstream `SelectionSet::extend_from_ast`.
        Return its index."""
        var base = len(self._stack)
        var selection = NO_NODE
        if node != NO_NODE:
            selection = document.first_child(node)
        while selection != NO_NODE:
            var kind = document.kind(selection)
            if kind == Kind.FIELD:
                self._field(schema, document, source, ty, selection)
            elif kind == Kind.FRAGMENT_SPREAD:
                self._stack.append(
                    Selection(
                        SelectionKind.FRAGMENT_SPREAD,
                        Int32(source),
                        Int32(selection),
                        _no_definition(),
                        MetaField.NONE,
                        NO_SELECTION_SET,
                    )
                )
            else:
                self._inline_fragment(schema, document, source, ty, selection)
            selection = document.next_sibling(selection)
        var start = len(self.document.selections)
        var position = base
        while position < len(self._stack):
            self.document.selections.append(self._stack[position])
            position += 1
        while len(self._stack) > base:
            _ = self._stack.pop()
        self.document.selection_sets.append(
            SelectionSet(
                Int32(ty),
                Int32(start),
                Int32(len(self.document.selections) - start),
            )
        )
        return Int32(len(self.document.selection_sets) - 1)

    def _field(
        mut self,
        schema: Schema,
        document: Document,
        source: Int,
        ty: Int,
        node: Int,
    ):
        """Add a field selection, or record why it has none."""
        if ty == NOT_FOUND:
            # The schema names an undefined type. Upstream records no
            # error for this here: it is a schema error.
            return
        var name_node = document.child(node, Role.NAME)
        var name = document.text(name_node)
        var kind = schema.types[ty].kind
        var definition = _no_definition()
        var meta = MetaField.NONE
        if kind == TypeKind.OBJECT or kind == TypeKind.INTERFACE:
            var position = schema.find_member(ty, name)
            if position != NOT_FOUND:
                definition = schema.member(ty, position)
        var field_type: Int
        if definition.node != Int32(NO_NODE):
            ref field_source = schema.sources[Int(definition.source)]
            field_type = schema.get_type(
                field_source.named_type(
                    field_source.child(Int(definition.node), Role.TYPE)
                )
            )
        else:
            if name == "__typename" and (
                kind == TypeKind.OBJECT
                or kind == TypeKind.INTERFACE
                or kind == TypeKind.UNION
            ):
                meta = MetaField.TYPENAME
            elif ty == self._query_type:
                if name == "__schema":
                    meta = MetaField.SCHEMA
                elif name == "__type":
                    meta = MetaField.TYPE
            if meta == MetaField.NONE:
                self._error(
                    BuildErrorKind.UNDEFINED_FIELD,
                    source,
                    name_node,
                    name=String(name),
                    type_name=String(schema.type_name(ty)),
                )
                return
            field_type = schema.get_type(meta.type_name())
        var set_node = document.child(node, Role.SELECTION_SET)
        if set_node != NO_NODE and field_type != NOT_FOUND:
            var field_kind = schema.types[field_type].kind
            if field_kind == TypeKind.SCALAR:
                self._error(
                    BuildErrorKind.SUBSELECTION_ON_SCALAR_TYPE,
                    source,
                    node,
                    type_name=String(schema.type_name(field_type)),
                )
                return
            if field_kind == TypeKind.ENUM:
                self._error(
                    BuildErrorKind.SUBSELECTION_ON_ENUM_TYPE,
                    source,
                    node,
                    type_name=String(schema.type_name(field_type)),
                )
                return
        var selection_set = self._selection_set(
            schema, document, source, field_type, set_node
        )
        self._stack.append(
            Selection(
                SelectionKind.FIELD,
                Int32(source),
                Int32(node),
                definition,
                meta,
                selection_set,
            )
        )

    def _inline_fragment(
        mut self,
        schema: Schema,
        document: Document,
        source: Int,
        ty: Int,
        node: Int,
    ):
        """Add an inline fragment, or record that its type condition is
        not defined."""
        var inner = ty
        var condition = document.child(node, Role.TYPE_CONDITION)
        if condition != NO_NODE:
            var type_name = document.name(condition)
            inner = schema.get_type(type_name)
            if inner == NOT_FOUND:
                self._error(
                    BuildErrorKind.UNDEFINED_TYPE_IN_INLINE_FRAGMENT_TYPE_CONDITION,
                    source,
                    condition,
                    type_name=String(type_name),
                )
                return
        var selection_set = self._selection_set(
            schema,
            document,
            source,
            inner,
            document.child(node, Role.SELECTION_SET),
        )
        self._stack.append(
            Selection(
                SelectionKind.INLINE_FRAGMENT,
                Int32(source),
                Int32(node),
                _no_definition(),
                MetaField.NONE,
                selection_set,
            )
        )


def _no_definition() -> Component:
    """Return the field definition of a selection that has none.

    Returns:
        A component whose node is `NO_NODE`.
    """
    return Component(0, Int32(NO_NODE), DEFINITION_ORIGIN)

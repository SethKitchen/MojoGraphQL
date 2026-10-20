# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Build a `Schema` from AST documents: upstream `SchemaBuilder`.

Port of apollo-compiler 1.33.0 (`b7eee5c`) `src/schema/from_ast.rs`, under
the MIT arm of its MIT OR Apache-2.0 license. The module docstring of
`gql_compiler.schema` lists the differences from upstream.

The first definition of a type, a directive or a member wins. A later one
is a `BuildError`, as upstream `collect_sticky` makes it. An extension of a
type that is not defined yet waits as an orphan until its definition comes.
"""

from gql_language.ast import Document, Kind, NO_NODE, OperationType, Role
from gql_language.names import NOT_FOUND
from gql_language.parser import parse
from gql_compiler.built_in import BUILT_IN_TYPES
from gql_compiler.parser import SourceSyntaxError, parse_recovering
from gql_compiler.schema import (
    BuildError,
    BuildErrorKind,
    Component,
    DEFINITION_ORIGIN,
    DirectiveDefinition,
    ExtendedType,
    HASHED_MEMBERS,
    Members,
    RootOperation,
    Schema,
    TypeKind,
    definition_kind,
)

comptime _ORPHANS = -3
"""The `NameTable` owner of the orphan type extensions."""


def _member_role(kind: TypeKind) -> Role:
    """Return the role of a type's members in the AST.

    Args:
        kind: The type's kind.

    Returns:
        `ENUM_VALUE`, `MEMBER_TYPE`, or `FIELD`.
    """
    if kind == TypeKind.ENUM:
        return Role.ENUM_VALUE
    if kind == TypeKind.UNION:
        return Role.MEMBER_TYPE
    return Role.FIELD


def _operation_name(operation: OperationType) -> String:
    """Return upstream `OperationType::name`.

    Args:
        operation: The operation type.

    Returns:
        "query", "mutation" or "subscription".
    """
    if operation == OperationType.QUERY:
        return "query"
    if operation == OperationType.MUTATION:
        return "mutation"
    return "subscription"


struct SchemaBuilder(Copyable, Movable):
    """Collects AST documents into a `Schema`: upstream `SchemaBuilder`."""

    var adopt_orphans: Bool
    """Whether orphan extensions extend an empty definition:
    upstream `adopt_orphan_extensions`."""
    var ignore_builtin_redefinitions: Bool
    """Whether a redefinition of a built-in type is ignored."""
    var schema: Schema
    """The schema being built."""
    var schema_definition_found: Bool
    """Whether a `schema` definition was added."""
    var orphan_schema_extensions: List[Component]
    """Schema extensions seen before any `schema` definition."""
    var orphans: List[List[Component]]
    """The orphan type extensions of each name, in order of first use."""
    var orphan_names: List[String]
    """The name of each entry of `orphans`."""
    var errors: List[BuildError]
    """The errors so far: upstream `DiagnosticList`."""
    var syntax_errors: List[SourceSyntaxError]
    """The syntax errors of the documents that `parse` added."""

    def __init__(out self) raises:
        """Make a builder that has the built-in types: upstream `new`.

        Raises:
            GraphQLError: Never in practice; see `built_in`.
        """
        self = SchemaBuilder.built_in()

    def __init__(out self, *, empty: Bool):
        """Make a builder with no types at all.

        Args:
            empty: Ignored; it selects this constructor.
        """
        self.adopt_orphans = False
        self.ignore_builtin_redefinitions = False
        self.schema = Schema()
        self.schema_definition_found = False
        self.orphan_schema_extensions = List[Component]()
        self.orphans = List[List[Component]]()
        self.orphan_names = List[String]()
        self.errors = List[BuildError]()
        self.syntax_errors = List[SourceSyntaxError]()

    @staticmethod
    def built_in() raises -> SchemaBuilder:
        """Return a builder with only the built-in types: upstream
        `built_in`. Keep it and copy it to build many schemas.

        Returns:
            The builder.

        Raises:
            GraphQLError: Never in practice: the built-in text is valid.
                Upstream asserts it.
        """
        var builder = SchemaBuilder(empty=True)
        builder.add_ast(parse(BUILT_IN_TYPES))
        return builder^

    def adopt_orphan_extensions(var self) -> SchemaBuilder:
        """Accept orphan extensions as if they extend an empty definition.

        Returns:
            The builder.
        """
        self.adopt_orphans = True
        return self^

    def ignore_builtin_redefinitions_on(var self) -> SchemaBuilder:
        """Ignore redefinitions of built-in types: upstream
        `ignore_builtin_redefinitions`.

        Returns:
            The builder.
        """
        self.ignore_builtin_redefinitions = True
        return self^

    def _error(
        mut self,
        kind: BuildErrorKind,
        source: Int,
        node: Int,
        name: String = "",
        type_kind: TypeKind = TypeKind.SCALAR,
        describe: String = "",
        type_name: String = "",
    ):
        """Record an error."""
        self.errors.append(
            BuildError(
                kind,
                Component(Int32(source), Int32(node), DEFINITION_ORIGIN),
                name,
                type_kind,
                describe,
                type_name,
            )
        )

    def parse(mut self, text: StringSlice, name: String = "GraphQL request"):
        """Parse a document with the recovering parser and add it:
        upstream `parse`.

        A syntax error does not stop the parse. It is kept in
        `syntax_errors`, and the recovered document is added.

        Args:
            text: The schema text.
            name: The file name of the document, for diagnostics.
        """
        var tree = parse_recovering(text, name)
        var source = len(self.schema.sources)
        for ref error in tree.errors:
            self.syntax_errors.append(SourceSyntaxError(source, error.copy()))
        self.add_ast(tree.take_document())

    def add_ast(
        mut self,
        var document: Document,
        executable_definitions_are_errors: Bool = True,
    ):
        """Add an AST document: upstream `add_ast`.

        Args:
            document: A schema document.
            executable_definitions_are_errors: Whether an operation or a
                fragment is an `EXECUTABLE_DEFINITION` error. A mixed
                document, as upstream `parse_mixed_validate` reads, passes
                False.
        """
        var source = len(self.schema.sources)
        self.schema.sources.append(document^)
        # About one node in eight is a type, a field or a directive. Room
        # for them up front saves the growth steps.
        var nodes = len(self.schema.sources[source].nodes)
        self.schema.components.reserve(len(self.schema.components) + nodes // 4)
        self.schema.types.reserve(len(self.schema.types) + nodes // 64)
        self.schema.names.reserve(nodes // 16)
        var root = self.schema.sources[source].root
        var definition = self.schema.sources[source].first_child(root)
        while definition != NO_NODE:
            self._add_definition(
                source, definition, executable_definitions_are_errors
            )
            definition = self.schema.sources[source].next_sibling(definition)

    def _add_definition(
        mut self, source: Int, node: Int, executable_are_errors: Bool
    ):
        """Add one top-level definition."""
        var kind = self.schema.sources[source].kind(node)
        var type_kind = definition_kind(kind)
        if type_kind >= 0:
            if kind.is_type_extension():
                self._add_type_extension(
                    source, node, TypeKind(UInt8(type_kind))
                )
            else:
                self._add_type_definition(
                    source, node, TypeKind(UInt8(type_kind))
                )
        elif kind == Kind.DIRECTIVE_DEFINITION:
            self._add_directive_definition(source, node)
        elif kind == Kind.SCHEMA_DEFINITION:
            if self.schema_definition_found:
                self._error(
                    BuildErrorKind.SCHEMA_DEFINITION_COLLISION, source, node
                )
            else:
                self.schema_definition_found = True
                self.schema.schema_definition = Component(
                    Int32(source), Int32(node), DEFINITION_ORIGIN
                )
                self._extend_schema(source, node, DEFINITION_ORIGIN)
                var pending = self.orphan_schema_extensions^
                self.orphan_schema_extensions = List[Component]()
                var index = 0
                while index < len(pending):
                    self._extend_schema_with(pending[index])
                    index += 1
        elif kind == Kind.SCHEMA_EXTENSION:
            var extension = Component(
                Int32(source), Int32(node), DEFINITION_ORIGIN
            )
            if self.schema_definition_found:
                self._extend_schema_with(extension)
            else:
                self.orphan_schema_extensions.append(extension)
        elif kind.is_executable_definition() and not executable_are_errors:
            pass
        else:
            var describe = "a directive extension"
            if kind == Kind.OPERATION_DEFINITION:
                describe = "an operation definition"
            elif kind == Kind.FRAGMENT_DEFINITION:
                describe = "a fragment definition"
            self._error(
                BuildErrorKind.EXECUTABLE_DEFINITION,
                source,
                node,
                describe=describe,
            )

    def _origin(mut self, source: Int, node: Int) -> Int32:
        """Register an extension and return its origin."""
        self.schema.extensions.append(
            Component(Int32(source), Int32(node), DEFINITION_ORIGIN)
        )
        return Int32(len(self.schema.extensions) - 1)

    def _extend_schema_with(mut self, extension: Component):
        """Apply a schema extension to the schema definition."""
        var source = Int(extension.source)
        var node = Int(extension.node)
        self._extend_schema(source, node, self._origin(source, node))

    def _extend_schema(mut self, source: Int, node: Int, origin: Int32):
        """Add the directives and root operations of a `schema` definition
        or extension: upstream `extend_ast` and `add_root_operations`."""
        var child = self.schema.sources[source].first_child(node)
        while child != NO_NODE:
            var role = self.schema.sources[source].role(child)
            if role == Role.DIRECTIVE:
                self.schema_directives_append(
                    Component(Int32(source), Int32(child), origin)
                )
            elif role == Role.OPERATION_TYPE:
                var operation = self.schema.sources[source].operation(child)
                var named = self.schema.sources[source].child(child, Role.TYPE)
                var slot = Int(operation.value)
                if self.schema.roots[slot]:
                    self._error(
                        BuildErrorKind.DUPLICATE_ROOT_OPERATION,
                        source,
                        child,
                        name=_operation_name(operation),
                    )
                else:
                    self.schema.roots[slot] = RootOperation(
                        Component(Int32(source), Int32(named), origin),
                        String(self.schema.node_name(source, named)),
                    )
            child = self.schema.sources[source].next_sibling(child)

    def schema_directives_append(mut self, component: Component):
        """Append a directive to the `schema` definition.

        Args:
            component: The directive.
        """
        _append(
            self.schema.components, self.schema.schema_directives, component
        )

    def _add_directive_definition(mut self, source: Int, node: Int):
        """Add a directive definition. A built-in one can be redefined
        once, as upstream allows."""
        var name = self.schema.node_name(source, node)
        var count = len(self.schema.directive_definitions)
        var previous = self.schema.names.find_or_insert(-2, name, count)
        if previous == NOT_FOUND:
            self.schema.directive_definitions.append(
                DirectiveDefinition(Int32(source), Int32(node))
            )
        elif self.schema.directive_definitions[previous].source == 0:
            self.schema.directive_definitions[previous] = DirectiveDefinition(
                Int32(source), Int32(node)
            )
        else:
            self._error(
                BuildErrorKind.DIRECTIVE_DEFINITION_COLLISION,
                source,
                node,
                name=String(name),
            )

    def _add_type_definition(mut self, source: Int, node: Int, kind: TypeKind):
        """Add a type definition and the orphan extensions waiting for it:
        upstream `type_definition!`."""
        var name = self.schema.node_name(source, node)
        var index = len(self.schema.types)
        var previous = self.schema.names.find_or_insert(-1, name, index)
        if previous != NOT_FOUND:
            var built_in = self.schema.is_built_in(previous)
            if self.ignore_builtin_redefinitions and built_in:
                return
            if kind == TypeKind.SCALAR and built_in:
                self._error(
                    BuildErrorKind.BUILT_IN_SCALAR_TYPE_REDEFINITION,
                    source,
                    node,
                )
            else:
                self._error(
                    BuildErrorKind.TYPE_DEFINITION_COLLISION,
                    source,
                    node,
                    name=String(name),
                )
            return
        self.schema.types.append(
            ExtendedType(
                kind,
                Component(Int32(source), Int32(node), DEFINITION_ORIGIN),
                Members(Int32(len(self.schema.components)), 0),
                Members(Int32(len(self.schema.components)), 0),
                Members(Int32(len(self.schema.components)), 0),
            )
        )
        self._extend_type(index, source, node, DEFINITION_ORIGIN)
        if len(self.orphans) == 0:
            return
        var orphan = self.schema.names.find(_ORPHANS, name)
        if orphan == NOT_FOUND:
            return
        var pending = List[Component]()
        swap(pending, self.orphans[orphan])
        var position = 0
        while position < len(pending):
            self._apply_extension(index, pending[position])
            position += 1

    def _add_type_extension(mut self, source: Int, node: Int, kind: TypeKind):
        """Apply a type extension, or keep it as an orphan: upstream
        `type_extension!`."""
        var name = self.schema.node_name(source, node)
        var index = self.schema.get_type(name)
        var extension = Component(Int32(source), Int32(node), DEFINITION_ORIGIN)
        if index != NOT_FOUND:
            self._apply_extension(index, extension)
            return
        var count = len(self.orphans)
        var orphan = self.schema.names.find_or_insert(_ORPHANS, name, count)
        if orphan == NOT_FOUND:
            self.orphans.append([extension])
            self.orphan_names.append(String(name))
        else:
            self.orphans[orphan].append(extension)

    def _apply_extension(mut self, index: Int, extension: Component):
        """Extend a type, or report an extension of another kind."""
        var source = Int(extension.source)
        var node = Int(extension.node)
        var kind = TypeKind(
            UInt8(definition_kind(self.schema.sources[source].kind(node)))
        )
        var type_kind = self.schema.types[index].kind
        if kind != type_kind:
            self._error(
                BuildErrorKind.TYPE_EXTENSION_KIND_MISMATCH,
                source,
                node,
                name=String(self.schema.type_name(index)),
                type_kind=type_kind,
                describe=String(kind.describe_extension()),
            )
            return
        self._extend_type(index, source, node, self._origin(source, node))

    def _extend_type(
        mut self, index: Int, source: Int, node: Int, origin: Int32
    ):
        """Add the directives, interfaces and members of a definition or an
        extension: upstream `from_ast` and `extend_ast`."""
        var kind = self.schema.types[index].kind
        var member_role = _member_role(kind)
        var child = self.schema.sources[source].first_child(node)
        while child != NO_NODE:
            var role = self.schema.sources[source].role(child)
            var component = Component(Int32(source), Int32(child), origin)
            if role == member_role:
                self._add_member(index, component)
            elif role == Role.DIRECTIVE:
                _append(
                    self.schema.components,
                    self.schema.types[index].directives,
                    component,
                )
            elif role == Role.INTERFACE:
                self._add_interface(index, component)
            child = self.schema.sources[source].next_sibling(child)

    def _add_interface(mut self, index: Int, component: Component):
        """Add an `implements` name unless it is there: upstream
        `extend_sticky_set`."""
        var name = self.schema.component_name(component)
        var interfaces = self.schema.types[index].interfaces
        var position = 0
        while position < Int(interfaces.count):
            var other = self.schema.components[Int(interfaces.start) + position]
            if self.schema.component_name(other) == name:
                self._error(
                    BuildErrorKind.DUPLICATE_IMPLEMENTS_INTERFACE,
                    Int(component.source),
                    Int(component.node),
                    name=String(name),
                    type_kind=TypeKind(self.schema.types[index].kind.value),
                    type_name=String(self.schema.type_name(index)),
                )
                return
            position += 1
        _append(
            self.schema.components,
            self.schema.types[index].interfaces,
            component,
        )

    def _add_member(mut self, index: Int, component: Component):
        """Add a field, value or union member unless one with its name is
        there: upstream `extend_sticky`."""
        var name = self.schema.component_name(component)
        var members = self.schema.types[index].members
        var count = Int(members.count)
        var duplicate = False
        if count >= HASHED_MEMBERS:
            duplicate = not self.schema.names.insert(index, name, count)
        else:
            var position = 0
            while position < count:
                var other = self.schema.components[
                    Int(members.start) + position
                ]
                if self.schema.component_name(other) == name:
                    duplicate = True
                    break
                position += 1
        if duplicate:
            self._error(
                BuildErrorKind.MEMBER_NAME_COLLISION,
                Int(component.source),
                Int(component.node),
                name=String(name),
                type_kind=TypeKind(self.schema.types[index].kind.value),
                type_name=String(self.schema.type_name(index)),
            )
            return
        _append(
            self.schema.components, self.schema.types[index].members, component
        )
        if count + 1 == HASHED_MEMBERS:
            var start = Int(self.schema.types[index].members.start)
            var position = 0
            while position < HASHED_MEMBERS:
                _ = self.schema.names.insert(
                    index,
                    self.schema.component_name(
                        self.schema.components[start + position]
                    ),
                    position,
                )
                position += 1

    def iter_orphan_extension_types(self) -> List[String]:
        """Return the names of the types that have orphan extensions.

        Returns:
            The names, in order of first use.
        """
        var names = List[String]()
        var index = 0
        while index < len(self.orphans):
            if len(self.orphans[index]) > 0:
                names.append(self.orphan_names[index])
            index += 1
        return names^

    def build_inner(var self) -> Tuple[Schema, List[BuildError]]:
        """Finish the schema, with the errors: upstream `build_inner`.

        Returns:
            The schema and the errors.
        """
        self._finish()
        var schema = Schema()
        swap(schema, self.schema)
        var errors = List[BuildError]()
        swap(errors, self.errors)
        return (schema^, errors^)

    def build(var self) raises -> Schema:
        """Finish the schema: upstream `build`.

        Returns:
            The schema.

        Raises:
            Error: With the messages of the syntax errors and of the build
                errors, one per line, when there is any.
        """
        self._finish()
        if len(self.errors) > 0 or len(self.syntax_errors) > 0:
            var lines = List[String]()
            for ref syntax in self.syntax_errors:
                if syntax.error.is_limit():
                    lines.append(syntax.error.message.copy())
                else:
                    lines.append(String("syntax error: ", syntax.error.message))
            for ref error in self.errors:
                lines.append(error.message())
            raise Error("\n".join(lines))
        var schema = Schema()
        swap(schema, self.schema)
        return schema^

    def _finish(mut self):
        """Adopt or report orphans and add the implicit root types."""
        var index = 0
        while index < len(self.orphans):
            if len(self.orphans[index]) > 0:
                if self.adopt_orphans:
                    self._adopt(index)
                else:
                    var position = 0
                    while position < len(self.orphans[index]):
                        var extension = self.orphans[index][position]
                        self._error(
                            BuildErrorKind.ORPHAN_TYPE_EXTENSION,
                            Int(extension.source),
                            Int(extension.node),
                            name=self.orphan_names[index].copy(),
                        )
                        position += 1
            index += 1
        if not self.schema_definition_found:
            var pending = self.orphan_schema_extensions^
            self.orphan_schema_extensions = List[Component]()
            if self.adopt_orphans:
                var position = 0
                while position < len(pending):
                    self._extend_schema_with(pending[position])
                    position += 1
                if (
                    not self.schema.roots[0]
                    and not self.schema.roots[1]
                    and not self.schema.roots[2]
                ):
                    _ = self._add_implicit_root_types()
            elif self._add_implicit_root_types():
                var position = 0
                while position < len(pending):
                    self._extend_schema_with(pending[position])
                    position += 1
            else:
                var position = 0
                while position < len(pending):
                    self._error(
                        BuildErrorKind.ORPHAN_SCHEMA_EXTENSION,
                        Int(pending[position].source),
                        Int(pending[position].node),
                    )
                    position += 1

    def _adopt(mut self, orphan: Int):
        """Make a type from orphan extensions: upstream
        `adopt_type_extensions`."""
        var first = self.orphans[orphan][0]
        var kind = TypeKind(
            UInt8(
                definition_kind(
                    self.schema.sources[Int(first.source)].kind(Int(first.node))
                )
            )
        )
        var index = len(self.schema.types)
        _ = self.schema.names.insert(-1, self.orphan_names[orphan], index)
        self.schema.types.append(
            ExtendedType(
                kind,
                first,
                Members(Int32(len(self.schema.components)), 0),
                Members(Int32(len(self.schema.components)), 0),
                Members(Int32(len(self.schema.components)), 0),
            )
        )
        var pending = List[Component]()
        swap(pending, self.orphans[orphan])
        var position = 0
        while position < len(pending):
            self._apply_extension(index, pending[position])
            position += 1

    def _add_implicit_root_types(mut self) -> Bool:
        """Use `Query`, `Mutation` and `Subscription` object types as the
        root operations: upstream `add_implicit_root_types`."""
        var found = False
        var defaults: List[StaticString] = ["Query", "Mutation", "Subscription"]
        var slot = 0
        while slot < 3:
            var index = self.schema.get_type(defaults[slot])
            if (
                index != NOT_FOUND
                and self.schema.types[index].kind == TypeKind.OBJECT
            ):
                self.schema.roots[slot] = RootOperation(
                    Component(0, Int32(NO_NODE), DEFINITION_ORIGIN),
                    String(defaults[slot]),
                )
                found = True
            slot += 1
        return found


def _append(
    mut components: List[Component], mut members: Members, component: Component
):
    """Append a component to a run, moving the run to the end of the list
    first when another run follows it.

    Args:
        components: The storage of every run.
        members: The run.
        component: The component to append.
    """
    var end = Int(members.start) + Int(members.count)
    if end != len(components):
        var start = len(components)
        var position = 0
        while position < Int(members.count):
            components.append(components[Int(members.start) + position])
            position += 1
        members.start = Int32(start)
    components.append(component)
    members.count += 1

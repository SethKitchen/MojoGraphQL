# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tree shaking of a GraphQL schema: keep only the types that an operation
or a type needs.

Port of Apollo MCP Server 2.0.0 (04e4e6e)
`crates/apollo-mcp-server/src/schema_tree_shake.rs`. `SchemaTreeShaker`
marks the types, the fields and the directives that an operation selects,
or that a type references up to a depth. It also collects the schema
descriptions of the arguments that operation variables fill. `shaken`
returns the marked part of the schema as a `ShakenSchema`, whose types
print as apollo-compiler prints the types of the shaken schema.

Differences from upstream:

- The upstream builds a new apollo-compiler `Schema` from the kept
  definitions, and validates it. `ShakenSchema` is a view of the original
  schema: the kept types, and for each type the kept fields and union
  members. Its text is the text of the upstream schema, and it does not
  report validation errors, which the upstream drops too
  (`unwrap_or_else(|schema| schema.partial)`).
- `retain_type` takes the name of one field instead of a selection set,
  which is the only selection set that the upstream callers pass.
- A `gql_schema.Schema` resolves every type reference when it is built, so
  the upstream branches that log a type that is not found do not exist.
- The upstream logs; this module does not.
"""

from std.collections import Dict

from gql_language.ast import Document, Kind, NO_NODE, OperationType, Role
from gql_schema.definition import NO_TYPE, Range, Schema, TypeKind
from gql_mcp.minify import minify_type_with
from gql_mcp.serialize import (
    type_members,
    union_members,
    SdlWriter,
    serialize_type_with,
    write_directive_definition,
    write_schema_definition,
    write_type,
)


struct DepthLimit(Equatable, ImplicitlyCopyable):
    """How deep a tree shaker follows type references, as upstream
    `DepthLimit`."""

    var depth: Int
    """The levels left, or -1 for no limit."""

    comptime UNLIMITED = DepthLimit(-1)
    """No limit."""

    def __init__(out self, depth: Int):
        """Make a limit.

        Args:
            depth: The levels, or -1 for no limit.
        """
        self.depth = depth

    @staticmethod
    def limited(depth: Int) -> DepthLimit:
        """Return a limit of some levels, as upstream `Limited(depth)`.

        Args:
            depth: The levels; 0 keeps nothing.

        Returns:
            The limit.
        """
        return DepthLimit(depth)

    def is_valid(self) -> Bool:
        """Return whether the limit is a level count or no limit.

        Returns:
            True when `depth` is -1 or more.
        """
        return self.depth >= -1

    def is_unlimited(self) -> Bool:
        """Return whether there is no limit.

        Returns:
            True for `UNLIMITED`.
        """
        return self.depth < 0

    def reached(self) -> Bool:
        """Return whether no level is left.

        Returns:
            True for a limit of 0.
        """
        return self.depth == 0

    def decrement(self) -> DepthLimit:
        """Return the limit one level down.

        Returns:
            The same limit when there is no limit, else one level less, but
            not less than 0.
        """
        if self.is_unlimited():
            return self
        return DepthLimit(max(self.depth - 1, 0))


def _selections(document: Document, node: Int) -> List[Int]:
    """The selections of a node's selection set; empty when it has none."""
    var set = document.child(node, Role.SELECTION_SET)
    if set == NO_NODE:
        return List[Int]()
    return document.children(set, Role.SELECTION)


def _variable_arguments(document: Document, node: Int) -> Dict[String, String]:
    """Map each argument whose value is a variable to the variable's name,
    as upstream `build_argument_name_to_value_map`."""
    var out = Dict[String, String]()
    for argument in document.children(node, Role.ARGUMENT):
        var value = document.child(argument, Role.VALUE)
        if document.kind(value) == Kind.VARIABLE:
            out[String(document.name(argument))] = String(document.name(value))
    return out^


def _type_condition(document: Document, node: Int) -> String:
    """The type condition of a fragment, or empty when it has none."""
    var condition = document.child(node, Role.TYPE_CONDITION)
    if condition == NO_NODE:
        return String()
    return String(document.name(condition))


struct SchemaTreeShaker(Movable):
    """The marks of a tree shaking of one schema, as upstream
    `SchemaTreeShaker`. Each method takes the schema that `__init__` took."""

    var _retained: List[Bool]
    """For each type, whether it is kept."""
    var _has_filter: List[Bool]
    """For each type, whether only some of its fields are kept."""
    var _filter: List[List[String]]
    """For each type, the names of the fields that are kept."""
    var _directives: List[Bool]
    """For each directive, whether it is kept."""
    var _operations: List[OperationType]
    """The operation types kept, in order."""
    var _fragments: Dict[String, Int]
    """The fragment definitions of the last operation's document."""
    var _descriptions: Dict[String, List[String]]
    """For each variable, the descriptions of the arguments it fills."""

    def __init__(out self, schema: Schema):
        """Start a shaking that keeps nothing.

        Args:
            schema: The schema.
        """
        var types = len(schema.types)
        self._retained = List[Bool](length=types, fill=False)
        self._has_filter = List[Bool](length=types, fill=False)
        self._filter = List[List[String]](length=types, fill=List[String]())
        self._directives = List[Bool](length=len(schema.directives), fill=False)
        self._operations = List[OperationType]()
        self._fragments = Dict[String, Int]()
        self._descriptions = Dict[String, List[String]]()

    def argument_descriptions(self) -> Dict[String, List[String]]:
        """Return the argument descriptions of the variables, as upstream
        `argument_descriptions`.

        Returns:
            For each variable that fills an argument with a description,
            the trimmed descriptions, in the order the shaking found them.
        """
        return self._descriptions.copy()

    def retain_operation_type(
        mut self,
        schema: Schema,
        operation: OperationType,
        depth: DepthLimit,
    ):
        """Keep the root type of an operation type and what it references.

        Args:
            schema: The schema.
            operation: The operation type.
            depth: How deep to follow references.
        """
        self._operations.append(operation)
        var root = schema.root_type(operation.value)
        if root != NO_TYPE:
            self._retain_type(schema, Document(), root, None, depth)

    def retain_type(
        mut self,
        schema: Schema,
        type: Int,
        field_name: Optional[String],
        depth: DepthLimit,
    ):
        """Keep a type, and what it references up to a depth.

        Args:
            schema: The schema.
            type: The type's index.
            field_name: The one field to keep, or `None` for all of them.
            depth: How deep to follow references.
        """
        if not field_name:
            self._retain_type(schema, Document(), type, None, depth)
            return
        var document = Document()
        var field = document.add(Kind.FIELD, Role.SELECTION)
        _ = document.add_name(field, Role.NAME, field_name.value())
        var selections = List[Int]()
        selections.append(field)
        self._retain_type(schema, document, type, selections^, depth)

    def retain_operation(
        mut self,
        schema: Schema,
        document: Document,
        operation: Int,
        depth: DepthLimit,
    ):
        """Keep what an operation selects, and the types of its arguments.

        The operation does not need to be valid for the schema: a field or
        a fragment type that the schema does not have keeps nothing.

        Args:
            schema: The schema.
            document: The executable document.
            operation: The `OperationDefinition` node.
            depth: How deep to follow references.
        """
        self._fragments = Dict[String, Int]()
        # The document has the operation, so it has a definition.
        var definitions = document.definitions()
        var index = 0
        while index < len(definitions):
            var definition = definitions[index]
            if document.kind(definition) == Kind.FRAGMENT_DEFINITION:
                self._fragments[String(document.name(definition))] = definition
            index += 1
        var kind = document.operation(operation)
        self._operations.append(kind)
        var root = schema.root_type(kind.value)
        if root != NO_TYPE:
            self._retain_type(
                schema, document, root, _selections(document, operation), depth
            )

    def _retain_type(
        mut self,
        schema: Schema,
        document: Document,
        type: Int,
        selections: Optional[List[Int]],
        depth: DepthLimit,
    ):
        """Keep a type and what it references, as upstream `retain_type`."""
        if depth.reached():
            return
        var selected = List[Int]()
        if selections:
            self._retain_fragments(schema, document, selections.value(), depth)
            for selection in selections.value():
                if document.kind(
                    selection
                ) == Kind.FIELD and not document.has_text(
                    document.child(selection, Role.NAME), "__typename"
                ):
                    selected.append(selection)
        if self._retained[type] and not selections and depth.is_unlimited():
            return
        self._retained[type] = True
        if selections:
            self._has_filter[type] = True
            for field in selected:
                self._filter[type].append(String(document.name(field)))
        ref named = schema.types[type]
        self._retain_applied(schema, document, named.directives, depth)
        var kind = named.kind
        if kind.has_fields():
            if selections:
                for field in selected:
                    self._retain_selected_field(
                        schema, document, type, field, depth
                    )
            else:
                ref span = schema.types[type].fields
                for field in range(Int(span.start), span.end()):
                    self._retain_field(
                        schema,
                        document,
                        field,
                        Dict[String, String](),
                        None,
                        depth,
                    )
        elif kind == TypeKind.UNION:
            self._retain_union(schema, document, type, selections, depth)
        elif kind == TypeKind.ENUM:
            ref values = schema.types[type].enum_values
            for value in range(Int(values.start), values.end()):
                self._retain_applied(
                    schema,
                    document,
                    schema.enum_values[value].directives,
                    depth,
                )
        elif kind == TypeKind.INPUT_OBJECT:
            ref fields = schema.types[type].input_fields
            for field in range(Int(fields.start), fields.end()):
                ref input = schema.input_values[field]
                self._retain_reference(
                    schema, document, Int(input.type.named), depth
                )
                self._retain_applied(schema, document, input.directives, depth)

    def _retain_reference(
        mut self,
        schema: Schema,
        document: Document,
        type: Int,
        depth: DepthLimit,
    ):
        """Keep a referenced type, without a selection, one level down."""
        self._retain_type(schema, document, type, None, depth.decrement())

    def _retain_applied(
        mut self,
        schema: Schema,
        document: Document,
        directives: Range,
        depth: DepthLimit,
    ):
        """Keep the definitions of the directives applied to a definition."""
        for index in range(Int(directives.start), directives.end()):
            var at = schema.applied[index]
            self._retain_directive(
                schema,
                document,
                String(schema.documents[Int(at.document)].name(Int(at.node))),
                depth,
            )

    def _retain_directive(
        mut self,
        schema: Schema,
        document: Document,
        name: String,
        depth: DepthLimit,
    ):
        """Keep a directive definition and the types of its arguments, as
        upstream `retain_directive`."""
        var directive = schema.directive_named(name)
        if directive == NO_TYPE:
            return
        self._directives[directive] = True
        ref arguments = schema.directives[directive].arguments
        for argument in range(Int(arguments.start), arguments.end()):
            self._retain_reference(
                schema,
                document,
                Int(schema.input_values[argument].type.named),
                depth,
            )

    def _retain_selected_field(
        mut self,
        schema: Schema,
        document: Document,
        type: Int,
        selection: Int,
        depth: DepthLimit,
    ):
        """Keep a selected field of an object or interface: its type with the
        field's selections, its arguments' types, and its directives."""
        var is_object = schema.types[type].kind == TypeKind.OBJECT
        var field = schema.field_named(type, document.name(selection))
        var arguments = Dict[String, String]()
        if is_object:
            arguments = _variable_arguments(document, selection)
        if field != NO_TYPE:
            self._retain_field(
                schema,
                document,
                field,
                arguments,
                _selections(document, selection),
                depth,
            )
        for directive in document.children(selection, Role.DIRECTIVE):
            var name = String(document.name(directive))
            var definition = schema.directive_named(name)
            if is_object and definition != NO_TYPE:
                self._describe_arguments(
                    schema,
                    schema.directives[definition].arguments,
                    _variable_arguments(document, directive),
                )
            self._retain_directive(schema, document, name, depth)

    def _retain_field(
        mut self,
        schema: Schema,
        document: Document,
        field: Int,
        arguments: Dict[String, String],
        selections: Optional[List[Int]],
        depth: DepthLimit,
    ):
        """Keep a field's type, its arguments' types and the definitions of
        its directives, and collect its argument descriptions."""
        ref definition = schema.fields[field]
        self._retain_type(
            schema,
            document,
            Int(definition.type.named),
            selections,
            depth.decrement(),
        )
        var span = definition.arguments
        for argument in range(Int(span.start), span.end()):
            self._describe_argument(schema, argument, arguments)
            self._retain_reference(
                schema,
                document,
                Int(schema.input_values[argument].type.named),
                depth,
            )
        self._retain_applied(
            schema, document, schema.fields[field].directives, depth
        )

    def _describe_arguments(
        mut self,
        schema: Schema,
        span: Range,
        arguments: Dict[String, String],
    ):
        """Collect the descriptions of the arguments of a directive."""
        for argument in range(Int(span.start), span.end()):
            self._describe_argument(schema, argument, arguments)

    def _describe_argument(
        mut self,
        schema: Schema,
        argument: Int,
        arguments: Dict[String, String],
    ):
        """Collect an argument's description for the variable that fills it,
        as upstream `retain_argument_descriptions`."""
        ref definition = schema.input_values[argument]
        var variable = arguments.get(definition.name)
        if not variable or not definition.description.exists():
            return
        var text = String(
            schema.description_text(definition.description).strip()
        )
        if text.byte_length() == 0:
            return
        var found = self._descriptions.get(variable.value())
        var texts = found^.or_else(List[String]())
        texts.append(text^)
        self._descriptions[variable.value()] = texts^

    def _retain_union(
        mut self,
        schema: Schema,
        document: Document,
        type: Int,
        selections: Optional[List[Int]],
        depth: DepthLimit,
    ):
        """Keep the members of a union, each with the selections that apply
        to it."""
        ref span = schema.types[type].members
        for index in range(Int(span.start), span.end()):
            var member = Int(schema.type_lists[index])
            if not selections:
                self._retain_type(
                    schema, document, member, None, depth.decrement()
                )
                continue
            var kept = List[Int]()
            for selection in selections.value():
                if self._applies(schema, document, selection, member):
                    kept.append(selection)
            if len(kept) > 0:
                self._retain_type(
                    schema, document, member, kept^, depth.decrement()
                )

    def _applies(
        self, schema: Schema, document: Document, selection: Int, member: Int
    ) -> Bool:
        """Whether a selection of a union applies to one of its members."""
        var kind = document.kind(selection)
        if kind == Kind.FIELD:
            return True
        ref name = schema.types[member].name
        if kind == Kind.FRAGMENT_SPREAD:
            var fragment = self._fragments.get(String(document.name(selection)))
            return (
                fragment and _type_condition(document, fragment.value()) == name
            )
        var condition = _type_condition(document, selection)
        return condition.byte_length() == 0 or condition == name

    def _retain_fragments(
        mut self,
        schema: Schema,
        document: Document,
        selections: List[Int],
        depth: DepthLimit,
    ):
        """Keep the type conditions of the fragments of a selection set, with
        the fragments' selections, as upstream `retain_fragments`."""
        for selection in selections:
            var kind = document.kind(selection)
            if kind == Kind.FIELD:
                var nested = _selections(document, selection)
                if len(nested) > 0:
                    self._retain_nested(schema, document, nested, depth)
                continue
            var fragment = selection
            if kind == Kind.FRAGMENT_SPREAD:
                var found = self._fragments.get(
                    String(document.name(selection))
                )
                if not found:
                    continue
                fragment = found.value()
            var target = schema.type_named(_type_condition(document, fragment))
            if target != NO_TYPE:
                self._retain_type(
                    schema,
                    document,
                    target,
                    _selections(document, fragment),
                    depth,
                )

    def _retain_nested(
        mut self,
        schema: Schema,
        document: Document,
        selections: List[Int],
        depth: DepthLimit,
    ):
        """Keep the fragments under a field, one level down."""
        self._retain_fragments(schema, document, selections, depth.decrement())

    def shaken(self, schema: Schema) -> ShakenSchema:
        """Return the kept part of the schema, as upstream `shaken`.

        Args:
            schema: The schema.

        Returns:
            The kept types, fields, union members, directives and root
            operations.
        """
        var out = ShakenSchema()
        for operation in self._operations:
            var root = schema.root_type(operation.value)
            if root != NO_TYPE and operation.text() not in out._operations:
                out._operations.append(operation.text())
                out._roots.append(root)
        # A schema always has the built-in directives and types, so these
        # loops are `while` loops.
        var directive = 0
        while directive < len(schema.directives):
            if (
                self._directives[directive]
                and not schema.directives[directive].is_builtin
            ):
                out._directives.append(directive)
            directive += 1
        var type = -1
        while type + 1 < len(schema.types):
            type += 1
            ref named = schema.types[type]
            if named.is_builtin or not self._retained[type]:
                continue
            var members = type_members(schema, type)
            if self._has_filter[type] and named.kind != TypeKind.ENUM:
                var kept = List[Int]()
                for member in members:
                    if (
                        _member_name(schema, named.kind, member)
                        in self._filter[type]
                    ):
                        kept.append(member)
                members = kept^
            var unions = List[Int]()
            for member in union_members(schema, type):
                if self._retained[member]:
                    unions.append(member)
            out._types.append(type)
            out._members.append(members^)
            out._unions.append(unions^)
        return out^


def _member_name(schema: Schema, kind: TypeKind, member: Int) -> String:
    """The name of a field or an input field."""
    if kind == TypeKind.INPUT_OBJECT:
        return schema.input_values[member].name.copy()
    return schema.fields[member].name.copy()


struct ShakenSchema(Copyable, Movable):
    """The kept part of a schema: upstream `shaken()`, the schema of the kept
    definitions. Its types are in the order of the schema's definitions."""

    var _types: List[Int]
    """The kept types that are not built in, as schema type indices."""
    var _members: List[List[Int]]
    """For each kept type, the kept fields, input fields or enum values."""
    var _unions: List[List[Int]]
    """For each kept type, the kept union members."""
    var _directives: List[Int]
    """The kept directives that are not built in."""
    var _operations: List[StaticString]
    """The kept root operation keywords, in order."""
    var _roots: List[Int]
    """The root type of each kept operation."""

    def __init__(out self):
        """Make an empty shaken schema."""
        self._types = List[Int]()
        self._members = List[List[Int]]()
        self._unions = List[List[Int]]()
        self._directives = List[Int]()
        self._operations = List[StaticString]()
        self._roots = List[Int]()

    def type_count(self) -> Int:
        """Return the number of kept types that are not built in.

        Returns:
            The count.
        """
        return len(self._types)

    def type_index(self, i: Int) -> Int:
        """Return a kept type.

        Args:
            i: The position, from 0, in definition order.

        Returns:
            The type's index in the schema.
        """
        return self._types[i]

    def has_type(self, schema: Schema, name: StringSlice) -> Bool:
        """Return whether a type that is not built in is kept.

        Args:
            schema: The schema.
            name: The type's name.

        Returns:
            True when the type is kept.
        """
        for type in self._types:
            if schema.types[type].name == name:
                return True
        return False

    def serialize_type(self, schema: Schema, i: Int) -> String:
        """Return the SDL text of a kept type, with its kept members, as
        apollo-compiler `ExtendedType::serialize().to_string()`.

        Args:
            schema: The schema.
            i: The position of the type.

        Returns:
            The definition and a line break.
        """
        return serialize_type_with(
            schema, self._types[i], self._members[i], self._unions[i]
        )

    def minify_type(self, schema: Schema, i: Int) -> String:
        """Return the minified text of a kept type, as upstream
        `MinifyExt::minify`.

        Args:
            schema: The schema.
            i: The position of the type.

        Returns:
            The minified definition.
        """
        return minify_type_with(
            schema, self._types[i], self._members[i], self._unions[i]
        )

    def _is_implicit(self, schema: Schema) -> Bool:
        """Whether apollo-compiler leaves out the schema definition: there is
        no root operation, or each root type is the default one."""
        if len(self._operations) == 0:
            return True
        if schema.description.exists() or schema.schema_directives.count > 0:
            return False
        var keywords: List[StaticString] = ["query", "mutation", "subscription"]
        var defaults: List[StaticString] = ["Query", "Mutation", "Subscription"]
        var index = 0
        while index < 3:
            var expected = String()
            if self._is_object(schema, defaults[index]):
                expected = String(defaults[index])
            var actual = String()
            var at = 0
            while at < len(self._operations):
                if self._operations[at] == keywords[index]:
                    actual = schema.types[self._roots[at]].name.copy()
                at += 1
            if actual != expected:
                return False
            index += 1
        return True

    def _is_object(self, schema: Schema, name: StaticString) -> Bool:
        """Whether a kept type with a name is an object type."""
        for type in self._types:
            if schema.types[type].name == name:
                return schema.types[type].kind == TypeKind.OBJECT
        return False

    def to_string(self, schema: Schema) -> String:
        """Return the SDL text of the shaken schema, as apollo-compiler
        `Schema::to_string`: the schema definition when it is not implicit,
        the directive definitions, then the types.

        Args:
            schema: The schema.

        Returns:
            The definitions, with an empty line between two of them and a
            line break at the end; empty when nothing is kept.
        """
        var writer = SdlWriter()
        var first = True
        if not self._is_implicit(schema):
            write_schema_definition(
                writer, schema, self._operations, self._roots
            )
            first = False
        for directive in self._directives:
            if not first:
                writer.write("\n\n")
            write_directive_definition(writer, schema, directive)
            first = False
        for i in range(len(self._types)):
            if not first:
                writer.write("\n\n")
            write_type(
                writer,
                schema,
                self._types[i],
                self._members[i],
                self._unions[i],
            )
            first = False
        if not first:
            writer.write("\n")
        return writer^.take()

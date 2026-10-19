# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Executable document validation of apollo-compiler.

Port of apollo-compiler 1.33.0 (`b7eee5c`) `src/executable/validation.rs`,
`src/validation/operation.rs`, `src/validation/fragment.rs`,
`src/validation/selection.rs`, `src/validation/variable.rs`, the
`validate_field` and `validate_leaf_field_selection` functions of
`src/validation/field.rs` and the validation contexts and recursion
limits of `src/validation/mod.rs`, under the MIT arm of its MIT OR
Apache-2.0 license.

**Differences from upstream.**

- The checks of `validate_with_or_without_schema` walk the AST, with the
  type of each selection set found as the builder finds it. Upstream
  walks the executable document. The nodes that the builder drops (an
  undefined field, a subselection of a leaf type, an undefined type
  condition) are skipped, as upstream does not have them.
- The checks of `validate_with_schema` (subscriptions and field merging)
  walk the executable document, as upstream does.
- Without a schema, the standalone builder keeps each operation and
  fragment, with selection sets of the type `NOT_FOUND`. The standalone
  checks find the operations and the fragments in the AST, with the
  builder's rules for name collisions.
- The meta fields (`__typename`, `__schema` and `__type`) take their
  definitions from a small document that this module builds, as
  upstream takes them from static definitions.
- Field merging compares the list and non-null wrappers of two types
  as a code of 2 bits for each level. Two types with more than 31
  levels of wrappers can compare as the same shape.
"""

from std.hashlib import Hasher

from gql_language.ast import Document, Kind, NO_NODE, OperationType, Role
from gql_language.directive_location import DirectiveLocation
from gql_language.names import NOT_FOUND, NameTable
from gql_compiler.diagnostics import Diagnostic, DiagnosticKind, DiagnosticList
from gql_compiler.executable import (
    ExecutableDocument,
    MetaField,
    NO_SELECTION_SET,
    SelectionKind,
)
from gql_compiler.schema import Component, DEFINITION_ORIGIN, Schema, TypeKind
from gql_compiler.validate_common import (
    find_argument,
    is_required,
    validate_arguments,
    validate_directives,
    validate_variable_usage,
    value_of_correct_type,
)

comptime DEFAULT_RECURSION_LIMIT = 32
"""The default depth limit of a recursive walk: upstream
`DEFAULT_RECURSION_LIMIT`."""

comptime WALK_LIMIT = 500
"""The depth limit of a walk of selections: upstream
`DepthCounter::new().with_limit(500)`."""

comptime FRAGMENT_CYCLE_LIMIT = 100
"""The depth limit of the fragment cycle search: upstream
`RecursionStack::with_limit(100)`."""

comptime FIELD_DEPTH_LIMIT = 128
"""The depth limit of field merging: upstream `FIELD_DEPTH_LIMIT`."""


@fieldwise_init
struct _Set(ImplicitlyCopyable, Movable):
    """A selection set: in the executable document when `model` is not
    `NOT_FOUND`, else in the AST."""

    var source: Int
    """The index of the document in `ExecutableDocument.sources`."""
    var node: Int
    """The `SelectionSet` node, or `NO_NODE`."""
    var model: Int
    """The index in `ExecutableDocument.selection_sets`, or `NOT_FOUND`."""
    var ty: Int
    """The index of the type in `Schema.types`, or `NOT_FOUND`."""


@fieldwise_init
struct _Sel(ImplicitlyCopyable, Movable):
    """A selection of a `_Set`."""

    var kind: SelectionKind
    """The variant."""
    var source: Int
    """The index of the document in `ExecutableDocument.sources`."""
    var node: Int
    """The `Field`, `FragmentSpread` or `InlineFragment` node."""
    var definition: Component
    """The field definition, or `NO_NODE`."""
    var meta: MetaField
    """The meta field, or `MetaField.NONE`."""
    var set: _Set
    """The subselections."""


@fieldwise_init
struct _Op(ImplicitlyCopyable, Movable):
    """An operation to validate."""

    var source: Int
    """The index of the document."""
    var node: Int
    """The `OperationDefinition` node."""
    var operation_type: OperationType
    """Query, mutation or subscription."""
    var set: _Set
    """The selection set."""


@fieldwise_init
struct _Frag(ImplicitlyCopyable, Movable):
    """A fragment definition to validate."""

    var source: Int
    """The index of the document."""
    var node: Int
    """The `FragmentDefinition` node."""
    var set: _Set
    """The selection set. Its type is the type condition."""


def _no_definition() -> Component:
    """Return the definition of a selection that has none."""
    return Component(Int32(0), Int32(NO_NODE), DEFINITION_ORIGIN)


struct _Context(Movable):
    """The state of the validation: upstream `ExecutableValidationContext`
    and `OperationValidationContext`."""

    var standalone: Bool
    """Whether there is no schema."""
    var files: List[Int]
    """The rank of each document in the diagnostic list."""
    var ops: List[_Op]
    """The operations."""
    var frags: List[_Frag]
    """The fragments."""
    var names: NameTable
    """The fragment names, under owner 0, without a schema."""
    var implementers: List[List[Int]]
    """The object types that implement each interface, once computed."""
    var validated: List[Bool]
    """The fragments that the current operation has validated."""
    var var_source: Int
    """The document of the current operation."""
    var operation: Int
    """The current operation node, whose variables are in scope."""

    def __init__(
        out self,
        document: ExecutableDocument,
        files: List[Int],
        standalone: Bool,
    ):
        """Collect the operations and the fragments.

        Args:
            document: The executable document.
            files: The rank of each document in the diagnostic list.
            standalone: Whether there is no schema.
        """
        self.standalone = standalone
        self.files = files.copy()
        self.ops = List[_Op]()
        self.frags = List[_Frag]()
        self.names = NameTable()
        self.implementers = List[List[Int]]()
        self.validated = List[Bool]()
        self.var_source = 0
        self.operation = NO_NODE
        if not standalone:
            var index = 0
            while index < len(document.operations):
                var op = document.operations[index]
                self.ops.append(
                    _Op(
                        Int(op.source),
                        Int(op.node),
                        op.operation_type,
                        _model_set(document, op.selection_set),
                    )
                )
                index += 1
            index = 0
            while index < len(document.fragments):
                var fragment = document.fragments[index]
                self.frags.append(
                    _Frag(
                        Int(fragment.source),
                        Int(fragment.node),
                        _model_set(document, fragment.selection_set),
                    )
                )
                index += 1
            return
        self._collect(document)

    def _collect(mut self, document: ExecutableDocument):
        """Find the operations and fragments in the AST, as the builder
        keeps them."""
        var operations = NameTable()
        var anonymous = False
        var source = 0
        while source < len(document.sources):
            ref ast = document.sources[source]
            var definitions = ast.definitions()
            var position = 0
            while position < len(definitions):
                var node = definitions[position]
                position += 1
                var kind = ast.kind(node)
                var set = _Set(
                    source,
                    ast.child(node, Role.SELECTION_SET),
                    NOT_FOUND,
                    NOT_FOUND,
                )
                if kind == Kind.FRAGMENT_DEFINITION:
                    if self.names.insert(0, ast.name(node), len(self.frags)):
                        self.frags.append(_Frag(source, node, set))
                    continue
                if kind != Kind.OPERATION_DEFINITION:
                    continue
                if ast.child(node, Role.NAME) != NO_NODE:
                    if not operations.insert(0, ast.name(node), 0):
                        continue
                elif anonymous or len(self.ops) > 0:
                    continue
                else:
                    anonymous = True
                self.ops.append(_Op(source, node, ast.operation(node), set))
            source += 1

    def fragment(self, document: ExecutableDocument, name: StringSlice) -> Int:
        """Return the index of a fragment by name.

        Args:
            document: The executable document.
            name: The fragment name.

        Returns:
            The index in `frags`, or `NOT_FOUND`.
        """
        if self.standalone:
            return self.names.find(0, name)
        return document.get_fragment(name)


def _model_set(document: ExecutableDocument, index: Int32) -> _Set:
    """Return a selection set of the executable document as a `_Set`."""
    return _Set(
        0, NO_NODE, Int(index), Int(document.selection_sets[Int(index)].ty)
    )


def _selections(document: ExecutableDocument, set: _Set) -> List[_Sel]:
    """Return the selections of a set."""
    var out = List[_Sel]()
    if set.model != NOT_FOUND:
        ref model = document.selection_sets[set.model]
        var position = 0
        while position < Int(model.count):
            var s = document.selections[Int(model.start) + position]
            var child = _Set(Int(s.source), NO_NODE, NOT_FOUND, NOT_FOUND)
            if s.selection_set != NO_SELECTION_SET:
                child = _model_set(document, s.selection_set)
            out.append(
                _Sel(
                    s.kind,
                    Int(s.source),
                    Int(s.node),
                    s.definition,
                    s.meta,
                    child,
                )
            )
            position += 1
        return out^
    ref ast = document.sources[set.source]
    var node = NO_NODE
    if set.node != NO_NODE:
        node = ast.first_child(set.node)
    while node != NO_NODE:
        var kind = ast.kind(node)
        var selection_kind = SelectionKind.INLINE_FRAGMENT
        if kind == Kind.FIELD:
            selection_kind = SelectionKind.FIELD
        elif kind == Kind.FRAGMENT_SPREAD:
            selection_kind = SelectionKind.FRAGMENT_SPREAD
        out.append(
            _Sel(
                selection_kind,
                set.source,
                node,
                _no_definition(),
                MetaField.NONE,
                _Set(
                    set.source,
                    ast.child(node, Role.SELECTION_SET),
                    NOT_FOUND,
                    NOT_FOUND,
                ),
            )
        )
        node = ast.next_sibling(node)
    return out^


struct _Meta(Movable):
    """The definitions of the meta fields: upstream `TYPENAME_FIELD`,
    `SCHEMA_FIELD` and `TYPE_FIELD`."""

    var document: Document
    """The document of the definitions."""
    var typename: Int
    """`__typename: String!`."""
    var schema: Int
    """`__schema: __Schema!`."""
    var type: Int
    """`__type(name: String!): __Type`."""

    def __init__(out self):
        """Build the definitions."""
        self.document = Document()
        self.typename = 0
        self.schema = 0
        self.type = 0
        self.typename = self._field("__typename", "String", True)
        self.schema = self._field("__schema", "__Schema", True)
        self.type = self._field("__type", "__Type", False)
        var argument = self.document.add_child(
            self.type, Kind.INPUT_VALUE_DEFINITION, Role.ARGUMENT
        )
        _ = self.document.add_name(argument, Role.NAME, "name")
        self._type(argument, "String", True)

    def _field(
        mut self, name: StaticString, type_name: StaticString, non_null: Bool
    ) -> Int:
        """Add a field definition."""
        var node = self.document.add_child(
            self.document.root, Kind.FIELD_DEFINITION, Role.DEFINITION
        )
        _ = self.document.add_name(node, Role.NAME, name)
        self._type(node, type_name, non_null)
        return node

    def _type(mut self, parent: Int, name: StaticString, non_null: Bool):
        """Add a type reference."""
        var holder = parent
        if non_null:
            holder = self.document.add_child(
                parent, Kind.NON_NULL_TYPE, Role.TYPE
            )
        var named = self.document.add_child(holder, Kind.NAMED_TYPE, Role.TYPE)
        _ = self.document.add_name(named, Role.NAME, name)

    def node(self, meta: MetaField) -> Int:
        """Return the definition of a meta field.

        Args:
            meta: `TYPENAME`, `SCHEMA` or `TYPE`.

        Returns:
            The `FieldDefinition` node.
        """
        if meta == MetaField.TYPENAME:
            return self.typename
        if meta == MetaField.SCHEMA:
            return self.schema
        return self.type


def validate_executable_into(
    schema: Schema,
    document: ExecutableDocument,
    files: List[Int],
    mut list: DiagnosticList,
    standalone: Bool = False,
):
    """Validate an executable document: upstream
    `validate_executable_document`.

    Args:
        schema: The schema.
        document: The executable document.
        files: The rank in `list` of each document of `document.sources`.
        list: The list to add the diagnostics to.
        standalone: Whether to validate with no schema, as upstream
            `validate_standalone_executable` does: only the checks of
            `validate_with_or_without_schema` run, with `schema` None.
    """
    var meta = _Meta()
    var ctx = _Context(document, files, standalone)
    # validate_with_or_without_schema
    var index = 0
    while index < len(ctx.ops):
        _validate_operation(schema, document, meta, ctx, list, index)
        index += 1
    _validate_fragments_used(document, ctx, list)
    _validate_defer(document, ctx, list)
    if standalone:
        return
    # validate_with_schema
    var merger = _FieldsInSetCanMerge(schema, document, meta)
    index = 0
    while index < len(ctx.ops):
        _validate_subscription(document, ctx, list, ctx.ops[index])
        merger.validate_operation(
            schema,
            document,
            ctx.files,
            Int(document.operations[index].selection_set),
            ctx.files[ctx.ops[index].source],
            document.sources[ctx.ops[index].source].start(ctx.ops[index].node),
            list,
        )
        index += 1


def _directives(
    schema: Schema,
    document: ExecutableDocument,
    ctx: _Context,
    source: Int,
    owner: Int,
    location: DirectiveLocation,
    mut list: DiagnosticList,
    operation: Int,
):
    """Validate the directives of a node: upstream `validate_directives`.
    Without a schema, only the arguments are checked."""
    ref ast = document.sources[source]
    if ast.child(owner, Role.DIRECTIVE) == NO_NODE:
        return
    var file = ctx.files[source]
    if ctx.standalone:
        var child = ast.first_child(owner)
        while child != NO_NODE:
            if ast.role(child) == Role.DIRECTIVE:
                validate_arguments(ast, child, file, list)
            child = ast.next_sibling(child)
        return
    validate_directives(
        schema,
        ast,
        owner,
        location,
        file,
        list,
        document.sources[ctx.var_source],
        operation,
    )


def _validate_operation(
    schema: Schema,
    document: ExecutableDocument,
    meta: _Meta,
    mut ctx: _Context,
    mut list: DiagnosticList,
    index: Int,
):
    """Validate one operation: upstream `validate_operation`."""
    var op = ctx.ops[index]
    ctx.var_source = op.source
    ctx.operation = op.node
    ctx.validated = List[Bool](length=len(ctx.frags), fill=False)
    _directives(
        schema,
        document,
        ctx,
        op.source,
        op.node,
        DirectiveLocation(op.operation_type.value),
        list,
        op.node,
    )
    _validate_variable_definitions(schema, document, ctx, list, op)
    _validate_unused_variables(document, ctx, list, op)
    _validate_selection_set(schema, document, meta, ctx, list, op.set)


def _validate_variable_definitions(
    schema: Schema,
    document: ExecutableDocument,
    ctx: _Context,
    mut list: DiagnosticList,
    op: _Op,
):
    """Validate the variable definitions of an operation: upstream
    `validate_variable_definitions`."""
    ref ast = document.sources[op.source]
    var file = ctx.files[op.source]
    var seen = NameTable()
    var child = ast.first_child(op.node)
    while child != NO_NODE:
        if ast.role(child) == Role.VARIABLE_DEFINITION:
            _directives(
                schema,
                document,
                ctx,
                op.source,
                child,
                DirectiveLocation.VARIABLE_DEFINITION,
                list,
                NO_NODE,
            )
            var name = ast.name(ast.child(child, Role.VARIABLE))
            var at = ast.start(child)
            if not ctx.standalone:
                var ty = ast.child(child, Role.TYPE)
                var inner = ast.named_type(ty)
                var index = schema.get_type(inner)
                if index == NOT_FOUND:
                    list.push(
                        Diagnostic(
                            DiagnosticKind.UNDEFINED_DEFINITION,
                            file,
                            at,
                            String(inner),
                        )
                    )
                elif _is_input(schema.types[index].kind):
                    var default = ast.child(child, Role.DEFAULT_VALUE)
                    if default != NO_NODE:
                        value_of_correct_type(
                            schema,
                            ast,
                            ty,
                            ast,
                            default,
                            file,
                            list,
                            ast,
                            NO_NODE,
                        )
                else:
                    list.push(
                        Diagnostic(
                            DiagnosticKind.VARIABLE_INPUT_TYPE,
                            file,
                            at,
                            String(name),
                        )
                    )
            if not seen.insert(0, name, 0):
                list.push(
                    Diagnostic(
                        DiagnosticKind.UNIQUE_VARIABLE, file, at, String(name)
                    )
                )
        child = ast.next_sibling(child)


def _is_input(kind: TypeKind) -> Bool:
    """Return True for a scalar, an enum or an input object type."""
    return (
        kind == TypeKind.SCALAR
        or kind == TypeKind.ENUM
        or kind == TypeKind.INPUT_OBJECT
    )


def _is_composite(schema: Schema, ty: Int) -> Bool:
    """Return True for an object, an interface or a union type."""
    var kind = schema.types[ty].kind
    return (
        kind == TypeKind.OBJECT
        or kind == TypeKind.INTERFACE
        or kind == TypeKind.UNION
    )


def _walk(
    document: ExecutableDocument,
    ctx: _Context,
    set: _Set,
    deep: Bool,
    mut out: List[_Sel],
    mut seen: List[Bool],
    depth: Int,
) -> Bool:
    """Add each selection of a set to `out`, through inline fragments and
    each named fragment once: upstream `walk_selections` and, when `deep`
    is True, `walk_selections_with_deduped_fragments`. Return False when
    the depth passes `WALK_LIMIT`."""
    var selections = _selections(document, set)
    var position = 0
    while position < len(selections):
        var s = selections[position]
        position += 1
        out.append(s)
        var next = s.set
        if s.kind == SelectionKind.FIELD:
            if not deep:
                continue
        elif s.kind == SelectionKind.FRAGMENT_SPREAD:
            var target = ctx.fragment(
                document, document.sources[s.source].name(s.node)
            )
            if target == NOT_FOUND or seen[target]:
                continue
            seen[target] = True
            next = ctx.frags[target].set
        if depth + 1 > WALK_LIMIT:
            return False
        if not _walk(document, ctx, next, deep, out, seen, depth + 1):
            return False
    return True


def _mark_variables(
    ast: Document,
    owner: Int,
    arguments: Bool,
    names: NameTable,
    mut used: List[Bool],
):
    """Mark the variables in the directives of a node, and in its
    arguments when `arguments` is True: upstream `variables_in_directives`
    and `variables_in_arguments`."""
    var stack = List[Int]()
    var child = ast.first_child(owner)
    while child != NO_NODE:
        var role = ast.role(child)
        if role == Role.DIRECTIVE or (arguments and role == Role.ARGUMENT):
            stack.append(child)
        child = ast.next_sibling(child)
    while len(stack) > 0:
        var current = stack.pop()
        if ast.kind(current) == Kind.VARIABLE:
            var index = names.find(0, ast.name(current))
            if index != NOT_FOUND:
                used[index] = True
        var inner = ast.first_child(current)
        while inner != NO_NODE:
            stack.append(inner)
            inner = ast.next_sibling(inner)


def _validate_unused_variables(
    document: ExecutableDocument,
    ctx: _Context,
    mut list: DiagnosticList,
    op: _Op,
):
    """Report each variable that the operation does not use: upstream
    `validate_unused_variables`."""
    ref ast = document.sources[op.source]
    var file = ctx.files[op.source]
    var table = NameTable()
    var names = List[String]()
    var offsets = List[Int]()
    var child = ast.first_child(op.node)
    while child != NO_NODE:
        if ast.role(child) == Role.VARIABLE_DEFINITION:
            var name = ast.name(ast.child(child, Role.VARIABLE))
            var index = table.find_or_insert(0, name, len(names))
            if index == NOT_FOUND:
                names.append(String(name))
                offsets.append(ast.start(child))
            else:
                # A later definition replaces the location, as upstream
                # collects the definitions into a map.
                offsets[index] = ast.start(child)
        child = ast.next_sibling(child)
    var used = List[Bool](length=len(names), fill=False)
    _mark_variables(ast, op.node, False, table, used)
    var out = List[_Sel]()
    var seen = List[Bool](length=len(ctx.frags), fill=False)
    if not _walk(document, ctx, op.set, True, out, seen, 0):
        list.push(Diagnostic(DiagnosticKind.RECURSION_ERROR, -1, 0))
        return
    var position = 0
    while position < len(out):
        var s = out[position]
        position += 1
        ref selection_ast = document.sources[s.source]
        _mark_variables(
            selection_ast,
            s.node,
            s.kind == SelectionKind.FIELD,
            table,
            used,
        )
        if s.kind == SelectionKind.FRAGMENT_SPREAD:
            var target = ctx.fragment(document, selection_ast.name(s.node))
            if target != NOT_FOUND:
                var fragment = ctx.frags[target]
                _mark_variables(
                    document.sources[fragment.source],
                    fragment.node,
                    False,
                    table,
                    used,
                )
    var index = 0
    while index < len(names):
        if not used[index]:
            list.push(
                Diagnostic(
                    DiagnosticKind.UNUSED_VARIABLE,
                    file,
                    offsets[index],
                    names[index],
                )
            )
        index += 1


def _validate_fragments_used(
    document: ExecutableDocument, ctx: _Context, mut list: DiagnosticList
):
    """Report each fragment that no operation uses: upstream
    `validate_fragments_used`."""
    var used = List[Bool](length=len(ctx.frags), fill=False)
    var index = 0
    while index < len(ctx.ops):
        var out = List[_Sel]()
        var seen = List[Bool](length=len(ctx.frags), fill=False)
        if not _walk(document, ctx, ctx.ops[index].set, True, out, seen, 0):
            list.push(Diagnostic(DiagnosticKind.RECURSION_LIMIT_ERROR, -1, 0))
            return
        var fragment = 0
        while fragment < len(seen):
            if seen[fragment]:
                used[fragment] = True
            fragment += 1
        index += 1
    index = 0
    while index < len(ctx.frags):
        if not used[index]:
            var fragment = ctx.frags[index]
            ref ast = document.sources[fragment.source]
            list.push(
                Diagnostic(
                    DiagnosticKind.UNUSED_FRAGMENT,
                    ctx.files[fragment.source],
                    ast.start(fragment.node),
                    String(ast.name(fragment.node)),
                )
            )
        index += 1


def _validate_subscription(
    document: ExecutableDocument,
    ctx: _Context,
    mut list: DiagnosticList,
    op: _Op,
):
    """Validate the root fields of a subscription: upstream
    `validate_subscription`."""
    if op.operation_type != OperationType.SUBSCRIPTION:
        return
    var name = String(document.sources[op.source].name(op.node))
    var out = List[_Sel]()
    var seen = List[Bool](length=len(ctx.frags), fill=False)
    var walked = _walk(document, ctx, op.set, False, out, seen, 0)
    var fields = 0
    var position = 0
    while position < len(out):
        var s = out[position]
        position += 1
        ref ast = document.sources[s.source]
        var file = ctx.files[s.source]
        if s.kind == SelectionKind.FIELD:
            fields += 1
            var field = ast.name(s.node)
            if (
                field == "__type"
                or field == "__schema"
                or field == "__typename"
            ):
                list.push(
                    Diagnostic(
                        DiagnosticKind.SUBSCRIPTION_USES_INTROSPECTION,
                        file,
                        ast.start(s.node),
                        name,
                    )
                )
        var child = ast.first_child(s.node)
        while child != NO_NODE:
            if ast.role(child) == Role.DIRECTIVE:
                var directive = ast.name(child)
                if directive == "skip" or directive == "include":
                    list.push(
                        Diagnostic(
                            DiagnosticKind.SUBSCRIPTION_USES_CONDITIONAL_SELECTION,
                            file,
                            ast.start(child),
                            name,
                        )
                    )
                    break
            child = ast.next_sibling(child)
    if not walked:
        list.push(Diagnostic(DiagnosticKind.RECURSION_ERROR, -1, 0))
        return
    if fields > 1:
        list.push(
            Diagnostic(
                DiagnosticKind.SUBSCRIPTION_USES_MULTIPLE_FIELDS,
                ctx.files[op.source],
                document.sources[op.source].start(op.node),
                name,
            )
        )


def _validate_defer(
    document: ExecutableDocument, ctx: _Context, mut list: DiagnosticList
):
    """Validate the `@defer` directives: upstream `validate_defer`."""
    var labels = NameTable()
    var index = 0
    while index < len(ctx.ops):
        _ = _defer_labels(document, ctx, list, ctx.ops[index].set, labels, 0)
        index += 1
    index = 0
    while index < len(ctx.frags):
        _ = _defer_labels(document, ctx, list, ctx.frags[index].set, labels, 0)
        index += 1
    index = 0
    while index < len(ctx.ops):
        var op = ctx.ops[index]
        index += 1
        if op.operation_type == OperationType.QUERY:
            continue
        var visited = List[Bool](length=len(ctx.frags), fill=False)
        _ = _forbid_defer_on_root(
            document, ctx, list, op.set, op.operation_type, visited, 0
        )
        if op.operation_type == OperationType.SUBSCRIPTION:
            visited = List[Bool](length=len(ctx.frags), fill=False)
            _ = _forbid_unconditional_defer(
                document, ctx, list, op.set, visited, 0
            )


def _defer_labels(
    document: ExecutableDocument,
    ctx: _Context,
    mut list: DiagnosticList,
    set: _Set,
    mut labels: NameTable,
    depth: Int,
) -> Bool:
    """Check the labels of the `@defer` directives in a set, not through
    fragment spreads: upstream `walk_defers_in_selection_set` and
    `check_defer_label`. Return False when the depth passes
    `WALK_LIMIT`."""
    var selections = _selections(document, set)
    var position = 0
    while position < len(selections):
        var s = selections[position]
        position += 1
        ref ast = document.sources[s.source]
        var file = ctx.files[s.source]
        var child = ast.first_child(s.node)
        while child != NO_NODE:
            if ast.role(child) == Role.DIRECTIVE and ast.name(child) == "defer":
                var argument = find_argument(ast, child, "label")
                if argument != NO_NODE:
                    var value = ast.child(argument, Role.VALUE)
                    var kind = ast.kind(value)
                    if kind == Kind.VARIABLE:
                        list.push(
                            Diagnostic(
                                DiagnosticKind.DEFER_LABEL_MUST_NOT_BE_VARIABLE,
                                file,
                                ast.start(value),
                            )
                        )
                    elif kind == Kind.STRING:
                        var label = ast.string_value(value)
                        if not labels.insert(0, label, 0):
                            list.push(
                                Diagnostic(
                                    DiagnosticKind.DUPLICATE_DEFER_LABEL,
                                    file,
                                    ast.start(value),
                                    label,
                                )
                            )
            child = ast.next_sibling(child)
        if s.kind == SelectionKind.FRAGMENT_SPREAD:
            continue
        if depth + 1 > WALK_LIMIT:
            return False
        if not _defer_labels(document, ctx, list, s.set, labels, depth + 1):
            return False
    return True


def _spread_target(
    document: ExecutableDocument,
    ctx: _Context,
    s: _Sel,
    mut visited: List[Bool],
) -> Int:
    """Return the fragment of a spread on its first visit, else
    `NOT_FOUND`."""
    var target = ctx.fragment(document, document.sources[s.source].name(s.node))
    if target == NOT_FOUND or visited[target]:
        return NOT_FOUND
    visited[target] = True
    return target


def _forbid_defer_on_root(
    document: ExecutableDocument,
    ctx: _Context,
    mut list: DiagnosticList,
    set: _Set,
    operation_type: OperationType,
    mut visited: List[Bool],
    depth: Int,
) -> Bool:
    """Report `@defer` on the root selections of a mutation or a
    subscription: upstream `forbid_defer_on_root`."""
    var selections = _selections(document, set)
    var position = 0
    while position < len(selections):
        var s = selections[position]
        position += 1
        if s.kind == SelectionKind.FIELD:
            continue
        ref ast = document.sources[s.source]
        var child = ast.first_child(s.node)
        while child != NO_NODE:
            if ast.role(child) == Role.DIRECTIVE and ast.name(child) == "defer":
                list.push(
                    Diagnostic(
                        DiagnosticKind.DEFER_ON_ROOT_SELECTION,
                        ctx.files[s.source],
                        ast.start(child),
                        _operation_type_name(operation_type),
                    )
                )
            child = ast.next_sibling(child)
        var next = s.set
        if s.kind == SelectionKind.FRAGMENT_SPREAD:
            var target = _spread_target(document, ctx, s, visited)
            if target == NOT_FOUND:
                continue
            next = ctx.frags[target].set
        if depth + 1 > WALK_LIMIT:
            return False
        if not _forbid_defer_on_root(
            document, ctx, list, next, operation_type, visited, depth + 1
        ):
            return False
    return True


def _operation_type_name(operation_type: OperationType) -> String:
    """Return "mutation" or "subscription"."""
    if operation_type == OperationType.MUTATION:
        return "mutation"
    return "subscription"


def _forbid_unconditional_defer(
    document: ExecutableDocument,
    ctx: _Context,
    mut list: DiagnosticList,
    set: _Set,
    mut visited: List[Bool],
    depth: Int,
) -> Bool:
    """Report `@defer` in a subscription that cannot be disabled: upstream
    `forbid_unconditional_defer`."""
    var selections = _selections(document, set)
    var position = 0
    while position < len(selections):
        var s = selections[position]
        position += 1
        ref ast = document.sources[s.source]
        if _may_be_excluded(ast, s.node):
            continue
        var child = ast.first_child(s.node)
        while child != NO_NODE:
            if (
                ast.role(child) == Role.DIRECTIVE
                and ast.name(child) == "defer"
                and not _can_be_disabled(ast, child)
            ):
                list.push(
                    Diagnostic(
                        DiagnosticKind.DEFER_IN_SUBSCRIPTION_MUST_BE_CONDITIONAL,
                        ctx.files[s.source],
                        ast.start(child),
                    )
                )
            child = ast.next_sibling(child)
        var next = s.set
        if s.kind == SelectionKind.FRAGMENT_SPREAD:
            var target = _spread_target(document, ctx, s, visited)
            if target == NOT_FOUND:
                continue
            next = ctx.frags[target].set
        if depth + 1 > WALK_LIMIT:
            return False
        if not _forbid_unconditional_defer(
            document, ctx, list, next, visited, depth + 1
        ):
            return False
    return True


def _if_value(ast: Document, directive: Int) -> Int:
    """Return the value of the `if` argument of a directive, or
    `NO_NODE`."""
    var argument = find_argument(ast, directive, "if")
    if argument == NO_NODE:
        return NO_NODE
    return ast.child(argument, Role.VALUE)


def _is_boolean(ast: Document, value: Int, expected: Bool) -> Bool:
    """Return True for a Boolean literal with a value."""
    return (
        value != NO_NODE
        and ast.kind(value) == Kind.BOOLEAN
        and ast.boolean_value(value) == expected
    )


def _may_be_excluded(ast: Document, node: Int) -> Bool:
    """Return True when `@skip` or `@include` can exclude a selection:
    upstream `selection_may_be_excluded`."""
    var child = ast.first_child(node)
    while child != NO_NODE:
        if ast.role(child) == Role.DIRECTIVE:
            var name = ast.name(child)
            if name == "skip":
                if not _is_boolean(ast, _if_value(ast, child), False):
                    return True
            elif name == "include":
                if not _is_boolean(ast, _if_value(ast, child), True):
                    return True
        child = ast.next_sibling(child)
    return False


def _can_be_disabled(ast: Document, directive: Int) -> Bool:
    """Return True when the `if` argument of `@defer` is `false` or a
    variable: upstream `defer_can_be_disabled`."""
    var value = _if_value(ast, directive)
    if value != NO_NODE and ast.kind(value) == Kind.VARIABLE:
        return True
    return _is_boolean(ast, value, False)


def _validate_selection_set(
    schema: Schema,
    document: ExecutableDocument,
    meta: _Meta,
    mut ctx: _Context,
    mut list: DiagnosticList,
    set: _Set,
):
    """Validate each selection of a set: upstream
    `validate_selection_set`. The type of the set is `set.ty`, which is
    `NOT_FOUND` for an undefined type or without a schema."""
    var selections = _selections(document, set)
    var position = 0
    while position < len(selections):
        var s = selections[position]
        position += 1
        if s.kind == SelectionKind.FIELD:
            _validate_field(schema, document, meta, ctx, list, set.ty, s)
        elif s.kind == SelectionKind.FRAGMENT_SPREAD:
            _validate_fragment_spread(
                schema, document, meta, ctx, list, set.ty, s
            )
        else:
            _validate_inline_fragment(
                schema, document, meta, ctx, list, set.ty, s
            )


def _validate_field(
    schema: Schema,
    document: ExecutableDocument,
    meta: _Meta,
    mut ctx: _Context,
    mut list: DiagnosticList,
    against: Int,
    s: _Sel,
):
    """Validate a field: upstream `validate_field`."""
    ref ast = document.sources[s.source]
    _directives(
        schema,
        document,
        ctx,
        s.source,
        s.node,
        DirectiveLocation.FIELD,
        list,
        ctx.operation,
    )
    if ast.child(s.node, Role.ARGUMENT) != NO_NODE:
        validate_arguments(ast, s.node, ctx.files[s.source], list)
    if ctx.standalone:
        _validate_selection_set(schema, document, meta, ctx, list, s.set)
        return
    # The builder keeps a field only with a definition or a meta field.
    if s.meta == MetaField.NONE:
        _validate_field_definition(
            schema,
            document,
            meta,
            ctx,
            list,
            against,
            s,
            schema.sources[Int(s.definition.source)],
            Int(s.definition.node),
        )
    else:
        _validate_field_definition(
            schema,
            document,
            meta,
            ctx,
            list,
            against,
            s,
            meta.document,
            meta.node(s.meta),
        )


def _validate_field_definition(
    schema: Schema,
    document: ExecutableDocument,
    meta: _Meta,
    mut ctx: _Context,
    mut list: DiagnosticList,
    against: Int,
    s: _Sel,
    def_document: Document,
    definition: Int,
):
    """Validate the arguments and the subselections of a field against
    its definition: the `type_field` branch of upstream
    `validate_field`. This runs for each field, so the checks of the
    arguments are in other functions, called only when there are
    arguments."""
    ref ast = document.sources[s.source]
    if ast.child(s.node, Role.ARGUMENT) != NO_NODE:
        _validate_field_arguments(
            schema, document, ctx, list, against, s, def_document, definition
        )
    if def_document.child(definition, Role.ARGUMENT) != NO_NODE:
        _validate_required_arguments(
            schema, document, ctx, list, against, s, def_document, definition
        )
    # validate_leaf_field_selection
    var ty = s.set.ty
    var count = document.selection_count(s.set.model)
    if ty != NOT_FOUND and count == 0 and _is_composite(schema, ty):
        _missing_subselection(schema, document, ctx, list, against, s)
        return
    if count > 0:
        _validate_selection_set(schema, document, meta, ctx, list, s.set)


def _validate_field_arguments(
    schema: Schema,
    document: ExecutableDocument,
    ctx: _Context,
    mut list: DiagnosticList,
    against: Int,
    s: _Sel,
    def_document: Document,
    definition: Int,
):
    """Validate each argument of a field against its definition."""
    ref ast = document.sources[s.source]
    ref var_document = document.sources[ctx.var_source]
    var file = ctx.files[s.source]
    var child = ast.first_child(s.node)
    while child != NO_NODE:
        if ast.role(child) == Role.ARGUMENT:
            var name = ast.name(child)
            var input = find_argument(def_document, definition, name)
            if input == NO_NODE:
                list.push(
                    Diagnostic(
                        DiagnosticKind.UNDEFINED_ARGUMENT,
                        file,
                        ast.start(child),
                        String(name),
                        _coordinate(schema, against, ast, s.node),
                    )
                )
            elif validate_variable_usage(
                def_document,
                input,
                ast,
                child,
                file,
                list,
                var_document,
                ctx.operation,
            ):
                value_of_correct_type(
                    schema,
                    def_document,
                    def_document.child(input, Role.TYPE),
                    ast,
                    ast.child(child, Role.VALUE),
                    file,
                    list,
                    var_document,
                    ctx.operation,
                )
        child = ast.next_sibling(child)


def _validate_required_arguments(
    schema: Schema,
    document: ExecutableDocument,
    ctx: _Context,
    mut list: DiagnosticList,
    against: Int,
    s: _Sel,
    def_document: Document,
    definition: Int,
):
    """Report each required argument that a field does not give."""
    ref ast = document.sources[s.source]
    var input = def_document.first_child(definition)
    while input != NO_NODE:
        if def_document.role(input) == Role.ARGUMENT and is_required(
            def_document, input
        ):
            var name = def_document.name(input)
            var given = find_argument(ast, s.node, name)
            if (
                given == NO_NODE
                or ast.kind(ast.child(given, Role.VALUE)) == Kind.NULL
            ):
                list.push(
                    Diagnostic(
                        DiagnosticKind.REQUIRED_ARGUMENT,
                        ctx.files[s.source],
                        ast.start(s.node),
                        String(
                            _coordinate(schema, against, ast, s.node),
                            "(",
                            name,
                            ":)",
                        ),
                    )
                )
        input = def_document.next_sibling(input)


def _missing_subselection(
    schema: Schema,
    document: ExecutableDocument,
    ctx: _Context,
    mut list: DiagnosticList,
    against: Int,
    s: _Sel,
):
    """Report a field of a composite type with no subselection."""
    ref ast = document.sources[s.source]
    list.push(
        Diagnostic(
            DiagnosticKind.MISSING_SUBSELECTION,
            ctx.files[s.source],
            ast.start(s.node),
            _coordinate(schema, against, ast, s.node),
            String(schema.types[s.set.ty].kind.describe()),
        )
    )


def _coordinate(schema: Schema, ty: Int, ast: Document, field: Int) -> String:
    """Return the coordinate `Type.field` of a field selection."""
    return String(schema.type_name(ty), ".", ast.name(field))


def _possible_types(schema: Schema, mut ctx: _Context, ty: Int) -> List[Int]:
    """Return the object types of a type: upstream `get_possible_types`."""
    var out = List[Int]()
    var kind = schema.types[ty].kind
    if kind == TypeKind.OBJECT:
        out.append(ty)
    elif kind == TypeKind.INTERFACE:
        if len(ctx.implementers) == 0:
            ctx.implementers = _implementers(schema)
        out = ctx.implementers[ty].copy()
    elif kind == TypeKind.UNION:
        var position = 0
        while position < schema.member_count(ty):
            out.append(
                schema.get_type(
                    schema.component_name(schema.member(ty, position))
                )
            )
            position += 1
    return out^


def _implementers(schema: Schema) -> List[List[Int]]:
    """Return the object types that implement each interface: upstream
    `Schema::implementers_map`."""
    var out = List[List[Int]](length=len(schema.types), fill=List[Int]())
    var ty = 0
    while ty < len(schema.types):
        ref extended = schema.types[ty]
        if extended.kind == TypeKind.OBJECT:
            var position = 0
            while position < Int(extended.interfaces.count):
                var interface = schema.get_type(
                    schema.component_name(
                        schema.components[
                            Int(extended.interfaces.start) + position
                        ]
                    )
                )
                if interface != NOT_FOUND:
                    out[interface].append(ty)
                position += 1
        ty += 1
    return out^


def _validate_spread_type(
    schema: Schema,
    document: ExecutableDocument,
    mut ctx: _Context,
    mut list: DiagnosticList,
    against: Int,
    condition: Int,
    s: _Sel,
    name: String,
):
    """Report a fragment that cannot apply to the type of its set:
    upstream `validate_fragment_spread_type`."""
    if against == NOT_FOUND or condition == against:
        return
    var parents = _possible_types(schema, ctx, against)
    var conditions = _possible_types(schema, ctx, condition)
    var position = 0
    while position < len(parents):
        if parents[position] in conditions:
            return
        position += 1
    list.push(
        Diagnostic(
            DiagnosticKind.INVALID_FRAGMENT_SPREAD,
            ctx.files[s.source],
            document.sources[s.source].start(s.node),
            name,
            String(schema.type_name(against)),
            String(schema.type_name(condition)),
        )
    )


def _validate_inline_fragment(
    schema: Schema,
    document: ExecutableDocument,
    meta: _Meta,
    mut ctx: _Context,
    mut list: DiagnosticList,
    against: Int,
    s: _Sel,
):
    """Validate an inline fragment: upstream `validate_inline_fragment`."""
    ref ast = document.sources[s.source]
    _directives(
        schema,
        document,
        ctx,
        s.source,
        s.node,
        DirectiveLocation.INLINE_FRAGMENT,
        list,
        ctx.operation,
    )
    var condition = ast.child(s.node, Role.TYPE_CONDITION)
    if not ctx.standalone and condition != NO_NODE:
        # The builder keeps an inline fragment only with a defined type
        # condition, which is the type of its set.
        if not _is_composite(schema, s.set.ty):
            list.push(
                Diagnostic(
                    DiagnosticKind.INVALID_FRAGMENT_TARGET,
                    ctx.files[s.source],
                    ast.start(s.node),
                    String(),
                    String(ast.name(condition)),
                )
            )
            return
        _validate_spread_type(
            schema, document, ctx, list, against, s.set.ty, s, String()
        )
    _validate_selection_set(schema, document, meta, ctx, list, s.set)


def _validate_fragment_spread(
    schema: Schema,
    document: ExecutableDocument,
    meta: _Meta,
    mut ctx: _Context,
    mut list: DiagnosticList,
    against: Int,
    s: _Sel,
):
    """Validate a fragment spread: upstream `validate_fragment_spread`."""
    ref ast = document.sources[s.source]
    _directives(
        schema,
        document,
        ctx,
        s.source,
        s.node,
        DirectiveLocation.FRAGMENT_SPREAD,
        list,
        ctx.operation,
    )
    var name = ast.name(s.node)
    var target = ctx.fragment(document, name)
    if target == NOT_FOUND:
        list.push(
            Diagnostic(
                DiagnosticKind.UNDEFINED_FRAGMENT,
                ctx.files[s.source],
                ast.start(s.node),
                String(name),
            )
        )
        return
    if not ctx.standalone:
        _validate_spread_type(
            schema,
            document,
            ctx,
            list,
            against,
            ctx.frags[target].set.ty,
            s,
            String(name),
        )
    if not ctx.validated[target]:
        ctx.validated[target] = True
        _validate_fragment_definition(schema, document, meta, ctx, list, target)


def _validate_fragment_definition(
    schema: Schema,
    document: ExecutableDocument,
    meta: _Meta,
    mut ctx: _Context,
    mut list: DiagnosticList,
    index: Int,
):
    """Validate a fragment definition: upstream
    `validate_fragment_definition`."""
    var fragment = ctx.frags[index]
    ref ast = document.sources[fragment.source]
    var file = ctx.files[fragment.source]
    _directives(
        schema,
        document,
        ctx,
        fragment.source,
        fragment.node,
        DirectiveLocation.FRAGMENT_DEFINITION,
        list,
        ctx.operation,
    )
    var has_type_error = False
    if not ctx.standalone and not _is_composite(schema, fragment.set.ty):
        list.push(
            Diagnostic(
                DiagnosticKind.INVALID_FRAGMENT_TARGET,
                file,
                ast.start(fragment.node),
                String(ast.name(fragment.node)),
                String(ast.name(ast.child(fragment.node, Role.TYPE_CONDITION))),
            )
        )
        has_type_error = True
    var on_path = List[Bool](length=len(ctx.frags), fill=False)
    var seen = List[Bool](length=len(ctx.frags), fill=False)
    on_path[index] = True
    var cycle = _detect_fragment_cycles(
        document, ctx, fragment.set, index, on_path, seen, 1
    )
    if cycle == _RECURSED:
        list.push(
            Diagnostic(
                DiagnosticKind.RECURSIVE_FRAGMENT_DEFINITION,
                file,
                ast.start(fragment.node),
                String(ast.name(fragment.node)),
            )
        )
    elif cycle == _LIMIT:
        list.push(
            Diagnostic(
                DiagnosticKind.DEEPLY_NESTED_TYPE,
                file,
                ast.start(fragment.node),
                String(ast.name(fragment.node)),
            )
        )
    if not has_type_error and cycle == _NO_CYCLE:
        _validate_selection_set(schema, document, meta, ctx, list, fragment.set)


comptime _NO_CYCLE = 0
"""`detect_fragment_cycles` returned `Ok`."""

comptime _RECURSED = 1
"""`detect_fragment_cycles` returned `CycleError::Recursed`."""

comptime _LIMIT = 2
"""`detect_fragment_cycles` returned `CycleError::Limit`."""


def _detect_fragment_cycles(
    document: ExecutableDocument,
    ctx: _Context,
    set: _Set,
    root: Int,
    mut on_path: List[Bool],
    mut seen: List[Bool],
    length: Int,
) -> Int:
    """Search a set for a spread of the root fragment: the inner function
    of upstream `validate_fragment_cycles`. `length` is the number of
    fragments on the path."""
    var selections = _selections(document, set)
    var position = 0
    while position < len(selections):
        var s = selections[position]
        position += 1
        if s.kind != SelectionKind.FRAGMENT_SPREAD:
            var inner = _detect_fragment_cycles(
                document, ctx, s.set, root, on_path, seen, length
            )
            if inner != _NO_CYCLE:
                return inner
            continue
        var target = ctx.fragment(
            document, document.sources[s.source].name(s.node)
        )
        if target == NOT_FOUND:
            continue
        if on_path[target]:
            if target == root:
                return _RECURSED
            continue
        if seen[target]:
            continue
        seen[target] = True
        if length + 1 > FRAGMENT_CYCLE_LIMIT:
            return _LIMIT
        on_path[target] = True
        var result = _detect_fragment_cycles(
            document,
            ctx,
            ctx.frags[target].set,
            root,
            on_path,
            seen,
            length + 1,
        )
        on_path[target] = False
        if result != _NO_CYCLE:
            return result
    return _NO_CYCLE


def _shape(document: Document, node: Int) -> Int:
    """Return the list and non-null wrappers of a type reference as a
    code: 2 bits for each level, under a leading 1 bit."""
    var code = 1
    var current = node
    while document.kind(current) != Kind.NAMED_TYPE:
        var bits = 2
        if document.kind(current) == Kind.LIST_TYPE:
            bits = 1
        code = (code << 2) | bits
        current = document.first_child(current)
    return code


def _same_value(
    left_document: Document,
    left: Int,
    right_document: Document,
    right: Int,
) -> Bool:
    """Return True when two values are the same: upstream `same_value`."""
    var kind = left_document.kind(left)
    if kind != right_document.kind(right):
        return False
    if kind == Kind.NULL:
        return True
    if kind == Kind.VARIABLE:
        return left_document.name(left) == right_document.name(right)
    if kind == Kind.STRING:
        return left_document.string_value(left) == right_document.string_value(
            right
        )
    if kind == Kind.LIST:
        var a = left_document.first_child(left)
        var b = right_document.first_child(right)
        while a != NO_NODE and b != NO_NODE:
            if not _same_value(left_document, a, right_document, b):
                return False
            a = left_document.next_sibling(a)
            b = right_document.next_sibling(b)
        return True
    if kind == Kind.OBJECT:
        if left_document.count(left, Role.FIELD) != right_document.count(
            right, Role.FIELD
        ):
            return False
        var field = left_document.first_child(left)
        while field != NO_NODE:
            var other = right_document.first_child(right)
            while other != NO_NODE and right_document.name(
                other
            ) != left_document.name(field):
                other = right_document.next_sibling(other)
            if other == NO_NODE or not _same_value(
                left_document,
                left_document.child(field, Role.VALUE),
                right_document,
                right_document.child(other, Role.VALUE),
            ):
                return False
            field = left_document.next_sibling(field)
        return True
    # An enum, an Int, a Float or a Boolean compares by its text.
    return left_document.text(left) == right_document.text(right)


struct _FieldsInSetCanMerge(Movable):
    """The field merging check: upstream `FieldsInSetCanMerge`.

    A field selection is its index in `ExecutableDocument.selections`. A
    merged set is a run of `items`, found again by its content, as
    upstream caches `MergedFieldSet` by its slice of fields.
    """

    var parent: List[Int32]
    """The type of the set of each selection."""
    var key: List[Int32]
    """The response key of each field, as a number."""
    var name: List[Int32]
    """The name of each field, as a number."""
    var shape: List[Int]
    """The wrappers of the type of each field; see `_shape`."""
    var base: List[Int32]
    """The named type of each field, or `NOT_FOUND`."""
    var spread: List[Int32]
    """The fragment of each fragment spread, or `NOT_FOUND`."""
    var seen_fragment: List[Bool]
    """The fragments that the current expansion has walked."""
    var items: List[Int32]
    """The fields of every merged set."""
    var starts: List[Int]
    """The first item of each merged set."""
    var counts: List[Int]
    """How many items each merged set has."""
    var chain: List[Int]
    """The previous merged set with the same hash, or -1."""
    var table: Dict[_Key, Int]
    """The last merged set with each hash."""
    var shape_done: List[Bool]
    """Upstream `same_response_shape_guard`."""
    var parents_done: List[Bool]
    """Upstream `same_for_common_parents_guard`."""
    var by_name: List[Int]
    """The first group in `groups` of each merged set, by response key,
    or -1 before it is computed: upstream `grouped_by_output_names`."""
    var by_name_count: List[Int]
    """How many groups by response key."""
    var by_parent: List[Int]
    """The first group by common parents, or -1: upstream
    `grouped_by_common_parents`."""
    var by_parent_count: List[Int]
    """How many groups by common parents."""
    var groups: List[Int]
    """Merged sets, in runs."""
    var slot: List[Int]
    """A group for each response key or type while grouping, else -1."""
    var current: Int
    """The current depth: upstream `LimitTracker.current`."""
    var high: Int
    """The highest depth: upstream `LimitTracker.high`."""

    def __init__(
        out self, schema: Schema, document: ExecutableDocument, meta: _Meta
    ):
        """Index the fields of a document.

        Args:
            schema: The schema.
            document: The executable document.
            meta: The meta field definitions.
        """
        var count = len(document.selections)
        self.parent = List[Int32](length=count, fill=Int32(NOT_FOUND))
        self.key = List[Int32](length=count, fill=Int32(NOT_FOUND))
        self.name = List[Int32](length=count, fill=Int32(NOT_FOUND))
        self.shape = List[Int](length=count, fill=0)
        self.base = List[Int32](length=count, fill=Int32(NOT_FOUND))
        self.spread = List[Int32](length=count, fill=Int32(NOT_FOUND))
        self.items = List[Int32]()
        self.starts = List[Int]()
        self.counts = List[Int]()
        self.chain = List[Int]()
        self.table = Dict[_Key, Int]()
        self.shape_done = List[Bool]()
        self.parents_done = List[Bool]()
        self.by_name = List[Int]()
        self.by_name_count = List[Int]()
        self.by_parent = List[Int]()
        self.by_parent_count = List[Int]()
        self.groups = List[Int]()
        self.current = 0
        self.high = 0
        var set = 0
        while set < len(document.selection_sets):
            ref model = document.selection_sets[set]
            var position = 0
            while position < Int(model.count):
                self.parent[Int(model.start) + position] = model.ty
                position += 1
            set += 1
        var names = NameTable(capacity=64)
        var keys = 0
        var fields = 0
        var index = 0
        while index < count:
            var s = document.selections[index]
            if s.kind == SelectionKind.FRAGMENT_SPREAD:
                self.spread[index] = Int32(
                    document.get_fragment(document.selection_name(s))
                )
            elif s.kind == SelectionKind.FIELD:
                var found = names.find_or_insert(
                    0, document.response_key(s), keys
                )
                if found == NOT_FOUND:
                    found = keys
                    keys += 1
                self.key[index] = Int32(found)
                found = names.find_or_insert(
                    1, document.selection_name(s), fields
                )
                if found == NOT_FOUND:
                    found = fields
                    fields += 1
                self.name[index] = Int32(found)
                if s.meta == MetaField.NONE:
                    ref source = schema.sources[Int(s.definition.source)]
                    var ty = source.child(Int(s.definition.node), Role.TYPE)
                    self.shape[index] = _shape(source, ty)
                    self.base[index] = Int32(
                        schema.get_type(source.named_type(ty))
                    )
                else:
                    ref source = meta.document
                    var ty = source.child(meta.node(s.meta), Role.TYPE)
                    self.shape[index] = _shape(source, ty)
                    self.base[index] = Int32(
                        schema.get_type(source.named_type(ty))
                    )
            index += 1
        var slots = keys
        if len(schema.types) > slots:
            slots = len(schema.types)
        self.slot = List[Int](length=slots, fill=-1)
        self.seen_fragment = List[Bool](
            length=len(document.fragments), fill=False
        )

    def validate_operation(
        mut self,
        schema: Schema,
        document: ExecutableDocument,
        files: List[Int],
        set: Int,
        file: Int,
        offset: Int,
        mut list: DiagnosticList,
    ):
        """Check that the fields of an operation can merge: upstream
        `FieldsInSetCanMerge::validate_operation`.

        Args:
            schema: The schema.
            document: The executable document.
            files: The rank of each document in `list`.
            set: The selection set of the operation.
            file: The rank of the operation's document.
            offset: The start of the operation.
            list: The list to add the diagnostics to.
        """
        var sets = List[Int]()
        sets.append(set)
        var id = self._expand(document, sets)
        self._shape_by_name(schema, document, files, id, list)
        self._parents_by_name(schema, document, files, id, list)
        if self.high > FIELD_DEPTH_LIMIT:
            list.push(
                Diagnostic(DiagnosticKind.RECURSION_LIMIT_ERROR, file, offset)
            )

    def _enter(mut self) -> Bool:
        """Go one level deeper: upstream `LimitTracker::check_and_increment`.
        Return True, and stay, when that passes the limit."""
        self.current += 1
        if self.current > self.high:
            self.high = self.current
        if self.current > FIELD_DEPTH_LIMIT:
            self.current -= 1
            return True
        return False

    def _lookup(mut self, var items: List[Int32]) -> Int:
        """Return the merged set with some fields, made on first use:
        upstream `FieldsInSetCanMerge::lookup`."""
        var key = _Key(items.copy())
        var found = self.table.find(key)
        if found:
            return found.value()
        var id = len(self.starts)
        self.starts.append(len(self.items))
        self.counts.append(len(items))
        self.items.extend(items^)
        self.table[key^] = id
        self.shape_done.append(False)
        self.parents_done.append(False)
        self.by_name.append(-1)
        self.by_name_count.append(0)
        self.by_parent.append(-1)
        self.by_parent_count.append(0)
        return id

    def _expand(mut self, document: ExecutableDocument, sets: List[Int]) -> Int:
        """Return the merged set of the fields of some selection sets,
        through fragments: upstream `expand_selections`."""
        var out = List[Int32]()
        var queue = sets.copy()
        var touched = List[Int]()
        var head = 0
        while head < len(queue):
            ref model = document.selection_sets[queue[head]]
            head += 1
            var position = Int(model.start)
            var end = position + Int(model.count)
            while position < end:
                ref s = document.selections[position]
                if s.kind == SelectionKind.FIELD:
                    out.append(Int32(position))
                elif s.kind == SelectionKind.INLINE_FRAGMENT:
                    queue.append(Int(s.selection_set))
                else:
                    var fragment = Int(self.spread[position])
                    if (
                        fragment != NOT_FOUND
                        and not self.seen_fragment[fragment]
                    ):
                        self.seen_fragment[fragment] = True
                        touched.append(fragment)
                        queue.append(
                            Int(document.fragments[fragment].selection_set)
                        )
                position += 1
        var index = 0
        while index < len(touched):
            self.seen_fragment[touched[index]] = False
            index += 1
        return self._lookup(out^)

    def _nested(self, document: ExecutableDocument, group: Int) -> List[Int]:
        """Return the non-empty subselections of the fields of a set."""
        var out = List[Int]()
        var start = self.starts[group]
        var position = 0
        while position < self.counts[group]:
            var set = Int(
                document.selections[
                    Int(self.items[start + position])
                ].selection_set
            )
            if document.selection_count(set) > 0:
                out.append(set)
            position += 1
        return out^

    def _group_by_name(mut self, id: Int):
        """Group the fields of a set by response key, in order of first
        use: upstream `group_by_output_name`."""
        if self.by_name[id] != -1:
            return
        var start = self.starts[id]
        var count = self.counts[id]
        var order = List[Int]()
        var sizes = List[Int]()
        var position = 0
        while position < count:
            var key = Int(self.key[Int(self.items[start + position])])
            if self.slot[key] == -1:
                self.slot[key] = len(order)
                order.append(key)
                sizes.append(0)
            sizes[self.slot[key]] += 1
            position += 1
        var offsets = List[Int](length=len(order), fill=0)
        var total = 0
        var group = 0
        while group < len(order):
            offsets[group] = total
            total += sizes[group]
            group += 1
        var sorted = List[Int32](length=count, fill=Int32(0))
        position = 0
        while position < count:
            var item = self.items[start + position]
            var slot = self.slot[Int(self.key[Int(item)])]
            sorted[offsets[slot]] = item
            offsets[slot] += 1
            position += 1
        var ids = List[Int]()
        total = 0
        group = 0
        while group < len(order):
            self.slot[order[group]] = -1
            var items = List[Int32](capacity=sizes[group])
            position = 0
            while position < sizes[group]:
                items.append(sorted[total + position])
                position += 1
            total += sizes[group]
            ids.append(self._lookup(items^))
            group += 1
        self.by_name[id] = len(self.groups)
        self.by_name_count[id] = len(ids)
        self.groups.extend(ids^)

    def _group_by_parents(mut self, schema: Schema, id: Int):
        """Group the fields of a set by their object parent type, with the
        fields of abstract parents in each group: upstream
        `group_by_common_parents`."""
        var start = self.starts[id]
        var abstract = List[Int32]()
        var order = List[Int]()
        var concrete = List[List[Int32]]()
        var position = 0
        while position < self.counts[id]:
            var item = self.items[start + position]
            position += 1
            # The builder keeps a field only on an object, an interface or
            # a union type.
            var ty = Int(self.parent[Int(item)])
            if schema.types[ty].kind != TypeKind.OBJECT:
                abstract.append(item)
                continue
            if self.slot[ty] == -1:
                self.slot[ty] = len(order)
                order.append(ty)
                concrete.append(List[Int32]())
            concrete[self.slot[ty]].append(item)
        var ids = List[Int]()
        if len(order) == 0:
            ids.append(self._lookup(abstract^))
        else:
            var group = 0
            while group < len(order):
                self.slot[order[group]] = -1
                var items = concrete[group].copy()
                items.extend(abstract.copy())
                ids.append(self._lookup(items^))
                group += 1
        self.by_parent[id] = len(self.groups)
        self.by_parent_count[id] = len(ids)
        self.groups.extend(ids^)

    def _shape_by_name(
        mut self,
        schema: Schema,
        document: ExecutableDocument,
        files: List[Int],
        id: Int,
        mut list: DiagnosticList,
    ):
        """Check that the fields of each response key have the same type
        shape: upstream `MergedFieldSet::same_response_shape_by_name`."""
        if self.shape_done[id]:
            return
        self.shape_done[id] = True
        self._group_by_name(id)
        var position = 0
        while position < self.by_name_count[id]:
            var group = self.groups[self.by_name[id] + position]
            position += 1
            var start = self.starts[group]
            var a = Int(self.items[start])
            var other = 1
            while other < self.counts[group]:
                var b = Int(self.items[start + other])
                other += 1
                if not self._same_shape(schema, a, b):
                    self._push(
                        document,
                        files,
                        DiagnosticKind.CONFLICTING_FIELD_TYPE,
                        a,
                        b,
                        list,
                    )
            var nested = self._nested(document, group)
            if len(nested) > 0:
                var merged = self._expand(document, nested)
                if not self._enter():
                    self._shape_by_name(schema, document, files, merged, list)
                    self.current -= 1

    def _parents_by_name(
        mut self,
        schema: Schema,
        document: ExecutableDocument,
        files: List[Int],
        id: Int,
        mut list: DiagnosticList,
    ):
        """Check that the fields of each response key and common parent
        have the same name and arguments: upstream
        `MergedFieldSet::same_for_common_parents_by_name`."""
        if self.parents_done[id]:
            return
        self.parents_done[id] = True
        self._group_by_name(id)
        var position = 0
        while position < self.by_name_count[id]:
            var by_name = self.groups[self.by_name[id] + position]
            position += 1
            self._group_by_parents(schema, by_name)
            var parent = 0
            while parent < self.by_parent_count[by_name]:
                var group = self.groups[self.by_parent[by_name] + parent]
                parent += 1
                var start = self.starts[group]
                var other = 1
                while other < self.counts[group]:
                    self._same_name_and_arguments(
                        document,
                        files,
                        Int(self.items[start]),
                        Int(self.items[start + other]),
                        list,
                    )
                    other += 1
                var nested = self._nested(document, group)
                if len(nested) > 0:
                    var merged = self._expand(document, nested)
                    if not self._enter():
                        self._parents_by_name(
                            schema, document, files, merged, list
                        )
                        self.current -= 1

    def _same_shape(self, schema: Schema, a: Int, b: Int) -> Bool:
        """Return True when two fields have types of the same shape:
        upstream `same_output_type_shape`."""
        if self.shape[a] != self.shape[b]:
            return False
        var type_a = Int(self.base[a])
        var type_b = Int(self.base[b])
        if type_a == NOT_FOUND or type_b == NOT_FOUND:
            return True
        if _is_leaf(schema.types[type_a].kind) and _is_leaf(
            schema.types[type_b].kind
        ):
            return type_a == type_b
        return _is_composite(schema, type_a) and _is_composite(schema, type_b)

    def _same_name_and_arguments(
        self,
        document: ExecutableDocument,
        files: List[Int],
        a: Int,
        b: Int,
        mut list: DiagnosticList,
    ):
        """Report two fields with different names or arguments: upstream
        `same_name_and_arguments`."""
        if self.name[a] != self.name[b]:
            self._push(
                document,
                files,
                DiagnosticKind.CONFLICTING_FIELD_NAME,
                a,
                b,
                list,
            )
            return
        ref sa = document.selections[a]
        ref sb = document.selections[b]
        ref da = document.sources[Int(sa.source)]
        ref db = document.sources[Int(sb.source)]
        var na = Int(sa.node)
        var nb = Int(sb.node)
        var self_args = _ArgumentLookup(da, na)
        var other_args = _ArgumentLookup(db, nb)
        var argument = da.first_child(na)
        while argument != NO_NODE:
            if da.role(argument) == Role.ARGUMENT:
                var other = other_args.by_name(db, nb, da.name(argument))
                if other == NO_NODE or not _same_value(
                    da,
                    da.child(argument, Role.VALUE),
                    db,
                    db.child(other, Role.VALUE),
                ):
                    self._push(
                        document,
                        files,
                        DiagnosticKind.CONFLICTING_FIELD_ARGUMENT,
                        a,
                        b,
                        list,
                    )
                    return
            argument = da.next_sibling(argument)
        argument = db.first_child(nb)
        while argument != NO_NODE:
            if (
                db.role(argument) == Role.ARGUMENT
                and self_args.by_name(da, na, db.name(argument)) == NO_NODE
            ):
                self._push(
                    document,
                    files,
                    DiagnosticKind.CONFLICTING_FIELD_ARGUMENT,
                    a,
                    b,
                    list,
                )
                return
            argument = db.next_sibling(argument)

    def _push(
        self,
        document: ExecutableDocument,
        files: List[Int],
        kind: DiagnosticKind,
        a: Int,
        b: Int,
        mut list: DiagnosticList,
    ):
        """Report a conflict at the second field. The alias is the response
        key of the first field, or the name of the second field for an
        argument conflict, as upstream."""
        ref sa = document.selections[a]
        ref sb = document.selections[b]
        var alias = String(document.response_key(sa))
        if kind == DiagnosticKind.CONFLICTING_FIELD_ARGUMENT:
            alias = String(document.selection_name(sb))
        list.push(
            Diagnostic(
                kind,
                files[Int(sb.source)],
                document.sources[Int(sb.source)].start(Int(sb.node)),
                alias,
            )
        )


comptime _ARGUMENT_MAP_SIZE = 20
"""Above this many arguments, `_ArgumentLookup` hashes the names, as
upstream `ArgumentLookup` does."""


struct _ArgumentLookup(Movable):
    """The arguments of a field, found by name: upstream
    `ArgumentLookup`. A short list is searched in order, with no
    allocation."""

    var names: Optional[NameTable]
    """The first `Argument` node of each name, under owner 0, for a list
    of more than `_ARGUMENT_MAP_SIZE` arguments."""

    def __init__(out self, document: Document, field: Int):
        """Index the arguments of a field when there are many.

        Args:
            document: The document of the field.
            field: A `Field` node.
        """
        self.names = None
        if document.count(field, Role.ARGUMENT) <= _ARGUMENT_MAP_SIZE:
            return
        var names = NameTable(capacity=64)
        var child = document.first_child(field)
        while child != NO_NODE:
            if document.role(child) == Role.ARGUMENT:
                # The first argument with a name wins, as in a search.
                _ = names.insert(0, document.name(child), child)
            child = document.next_sibling(child)
        self.names = names^

    def by_name(self, document: Document, field: Int, name: StringSlice) -> Int:
        """Return the first argument with a name.

        Args:
            document: The document of the field.
            field: The `Field` node.
            name: The argument name.

        Returns:
            The `Argument` node, or `NO_NODE`.
        """
        if self.names:
            # `NOT_FOUND` is `NO_NODE`.
            return self.names.value().find(0, name)
        return find_argument(document, field, name)


def _is_leaf(kind: TypeKind) -> Bool:
    """Return True for a scalar or an enum type."""
    return kind == TypeKind.SCALAR or kind == TypeKind.ENUM


struct _Key(Copyable, Equatable, Hashable, Movable):
    """The fields of a merged set, as a key of `_FieldsInSetCanMerge.table`."""

    var items: List[Int32]
    """The fields."""

    def __init__(out self, var items: List[Int32]):
        """Make a key.

        Args:
            items: The fields.
        """
        self.items = items^

    def __eq__(self, other: Self) -> Bool:
        """Return True for the same fields in the same order.

        Args:
            other: The other key.

        Returns:
            Whether the fields are equal.
        """
        return self.items == other.items

    def __hash__[H: Hasher](self, mut hasher: H):
        """Hash the fields.

        Parameters:
            H: The hasher type.

        Args:
            hasher: The hasher.
        """
        var position = 0
        while position < len(self.items):
            self.items[position].__hash__(hasher)
            position += 1

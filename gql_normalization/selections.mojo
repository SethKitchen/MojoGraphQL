# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The selection passes of graphql-go-tools v2 `astnormalization`.

Each function is one visitor of upstream, and edits the operation document
in place:

| Function | Upstream file |
| --- | --- |
| `remove_operation_definitions` | `operation_definition_removal.go` |
| `directive_include_skip` | `directive_include_skip.go`, with `preventFragmentCycles` and `detectVariableUsage` of `astnormalization.go` and `variables_unused_deletion.go` |
| `fragment_spread_inline` | `fragment_spread_inlining.go` |
| `remove_self_aliasing` | `remove_self_aliasing.go` |
| `inline_selections_from_inline_fragments` | `inline_selections_from_inline_fragments.go` |
| `merge_inline_fragment_selections` | `inline_fragment_selection_merging.go` |
| `remove_fragment_definitions` | `fragment_definition_removal.go` |
| `deduplicate_fields` | `field_deduplication.go` |
| `delete_unused_variables` | `variables_unused_deletion.go` |

A pass that edits a selection set starts the selection set again after
each edit, as the walker does after `RevisitNode`.

Differences from upstream:

- The walker of upstream reads a directive list while a visitor removes a
  directive from it, so it can skip the directive after a removed one. Here
  each directive is read once, in order.

The `@defer` stages are in `gql_normalization.defer`. The merges here keep
the winning `@__defer_internal` with `merge_fields_defer`.
"""

from gql_language.ast import Document, FLAG_TRUE, Kind, NO_NODE, Role

from gql_normalization.edit import (
    arguments_equal,
    clone,
    directives_equal,
    insert_after,
    merge_fields_defer,
    move_children,
    previous_sibling,
    remove_child,
    splice,
    text_equal,
)
from gql_normalization.schema_lookup import (
    NO_TYPE,
    declares_interface,
    field_type,
    has_fields_of,
    interfaces_intersect,
    is_member,
    root_type,
    type_condition,
    type_condition_name,
    union_intersects_interface,
)
from gql_normalization.variables_json import (
    delete_member,
    members,
    top_level_member,
)
from gql_schema.definition import Schema, TypeKind

comptime INTERNAL_TYPENAME = "__internal_typename"
"""The alias of the `__typename` placeholder: upstream
`literal.INTERNAL_TYPENAME`."""

comptime SetVisitor = def(
    mut document: Document, schema: Schema, selection_set: Int, enclosing: Int
) raises thin -> None
"""A pass over one selection set, given its enclosing type."""


@always_inline
def _index_of(names: List[String], name: StringSlice) -> Int:
    """Return the index of a name in a list, or -1."""
    var index = 0
    while index < len(names):
        if names[index] == name:
            return index
        index += 1
    return -1


@always_inline
def _is_empty(document: Document, node: Int) -> Bool:
    """Return True if a node has no child."""
    return document.first_child(node) == NO_NODE


def add_typename_placeholder(mut document: Document, selection_set: Int):
    """Add `__internal_typename: __typename` to a selection set:
    `addInternalTypeNamePlaceholder`.

    Args:
        document: The operation document.
        selection_set: The selection set.
    """
    var field = document.add_child(selection_set, Kind.FIELD, Role.SELECTION)
    _ = document.add_name(field, Role.ALIAS, INTERNAL_TYPENAME)
    _ = document.add_name(field, Role.NAME, "__typename")


def remove_operation_definitions(mut document: Document, name: StringSlice):
    """Remove each operation whose name is not `name`:
    `removeOperationDefinitions`.

    Args:
        document: The operation document.
        name: The name of the operation to keep; empty keeps only the
            anonymous operations.
    """
    var root = document.root
    var current = document.first_child(root)
    while current != NO_NODE:
        var definition = current
        current = document.next_sibling(definition)
        if document.kind(definition) != Kind.OPERATION_DEFINITION:
            continue
        if document.name(definition) != name:
            remove_child(document, root, definition)


def variable_boolean(
    document: Document, variables: String, name: StringSlice
) -> Tuple[Bool, Bool]:
    """Return the boolean value of a variable: `GetVariableBooleanValue`.

    Args:
        document: The operation document.
        variables: The variables JSON.
        name: The variable name.

    Returns:
        The value, and whether it is known: from a boolean member of the
        variables, or from the default value of a variable definition.
    """
    var index = top_level_member(variables, name)
    if index >= 0:
        var value = members(variables)[index].value(variables)
        if value == "true":
            return (True, True)
        if value == "false":
            return (False, True)
    var pending_1 = document.first_child(document.root)
    while pending_1 != NO_NODE:
        var definition = pending_1
        pending_1 = document.next_sibling(definition)
        if document.kind(definition) != Kind.OPERATION_DEFINITION:
            continue
        var variable = document.child(definition, Role.VARIABLE_DEFINITION)
        while variable != NO_NODE:
            if document.name(document.child(variable, Role.VARIABLE)) == name:
                var default = document.child(variable, Role.DEFAULT_VALUE)
                if default != NO_NODE:
                    return (
                        document.kind(default) == Kind.BOOLEAN
                        and document.boolean_value(default),
                        True,
                    )
            variable = document.next_with_role(variable)
    return (False, False)


@always_inline
def _condition(
    document: Document, variables: String, directive: Int
) -> Tuple[Bool, Bool]:
    """Return the `if` argument of `@include` or `@skip`, and whether it is
    known."""
    var argument = document.child(directive, Role.ARGUMENT)
    if argument == NO_NODE or document.next_with_role(argument) != NO_NODE:
        return (False, False)
    if not document.name(argument) == "if":
        return (False, False)
    var value = document.child(argument, Role.VALUE)
    var kind = document.kind(value)
    if kind == Kind.BOOLEAN:
        return (document.boolean_value(value), True)
    if kind == Kind.VARIABLE:
        return variable_boolean(document, variables, document.name(value))
    return (False, False)


def directive_condition(
    document: Document, variables: String, directive: Int
) -> Tuple[Bool, Bool]:
    """Return the `if` argument of an `@include` or `@skip` directive:
    `GetBooleanValue` of its only argument.

    Args:
        document: The operation document.
        variables: The variables JSON.
        directive: The directive.

    Returns:
        The value, and whether it is known: the directive has one argument,
        `if`, with a boolean or a variable of a known boolean value.
    """
    return _condition(document, variables, directive)


def _add_variables(document: Document, value: Int, mut names: List[String]):
    """Add each variable in a value to a list, once."""
    var kind = document.kind(value)
    if kind == Kind.VARIABLE:
        var name = String(document.name(value))
        if name not in names:
            names.append(name^)
    elif kind == Kind.LIST:
        var item = document.first_child(value)
        while item != NO_NODE:
            _add_variables(document, item, names)
            item = document.next_sibling(item)
    elif kind == Kind.OBJECT:
        var field = document.first_child(value)
        while field != NO_NODE:
            _add_variables(document, document.child(field, Role.VALUE), names)
            field = document.next_sibling(field)


@always_inline
def _argument_variables(document: Document, node: Int, mut names: List[String]):
    """Add each variable in the arguments of a node to a list."""
    var argument = document.child(node, Role.ARGUMENT)
    while argument != NO_NODE:
        _add_variables(document, document.child(argument, Role.VALUE), names)
        argument = document.next_with_role(argument)


struct _IncludeSkip(Movable):
    """The state of the first walk: `directiveIncludeSkipVisitor`,
    `fragmentCycleVisitor` and `variableUsageDetector`."""

    var keep_nodes: Bool
    """Remove the directives, and keep the nodes they would remove."""
    var used: List[String]
    """The variables in an argument anywhere in the document."""
    var has_defer: Bool
    """Whether a directive of the walk is `@defer`."""

    def __init__(out self, keep_nodes: Bool):
        self.keep_nodes = keep_nodes
        self.used = List[String]()
        self.has_defer = False


@always_inline
def _directives(
    mut document: Document,
    mut state: _IncludeSkip,
    variables: String,
    node: Int,
    parent: Int,
):
    """Apply the `@include` and `@skip` directives of a node.

    `parent` is the selection set of the node, or `NO_NODE` for a node that
    is not a selection.
    """
    var removed = False
    var current = document.child(node, Role.DIRECTIVE)
    while current != NO_NODE:
        var directive = current
        current = document.next_with_role(directive)
        _argument_variables(document, directive, state.used)
        var name = document.name(directive)
        var is_skip = name == "skip"
        if not is_skip and not name == "include":
            if name == "defer":
                state.has_defer = True
            continue
        var condition = _condition(document, variables, directive)
        if not condition[1]:
            continue
        var drop = condition[0] if is_skip else not condition[0]
        if state.keep_nodes or not drop:
            remove_child(document, node, directive)
            continue
        if parent == NO_NODE or removed:
            continue
        removed = True
        remove_child(document, parent, node)
        if _is_empty(document, parent):
            add_typename_placeholder(document, parent)


def _include_skip_set(
    mut document: Document,
    schema: Schema,
    mut state: _IncludeSkip,
    variables: String,
    selection_set: Int,
    enclosing: Int,
) raises:
    """Walk a selection set in the first stage.

    No visitor of the stage reads the enclosing type, so only the type
    conditions are looked up, for the errors of the walker.
    """
    var current = document.first_child(selection_set)
    while current != NO_NODE:
        var selection = current
        current = document.next_sibling(selection)
        var kind = document.kind(selection)
        if kind == Kind.FIELD:
            _argument_variables(document, selection, state.used)
            _directives(document, state, variables, selection, selection_set)
            var inner = document.child(selection, Role.SELECTION_SET)
            if inner != NO_NODE:
                _include_skip_set(
                    document,
                    schema,
                    state,
                    variables,
                    inner,
                    NO_TYPE,
                )
        elif kind == Kind.INLINE_FRAGMENT:
            var type = type_condition(schema, document, selection, enclosing)
            _directives(document, state, variables, selection, selection_set)
            _include_skip_set(
                document,
                schema,
                state,
                variables,
                document.child(selection, Role.SELECTION_SET),
                type,
            )
        else:
            _directives(document, state, variables, selection, selection_set)


def _spreads_under(document: Document, node: Int, mut out: List[Int]):
    """Add each fragment spread under a node, in walk order."""
    var current = document.first_child(node)
    while current != NO_NODE:
        var kind = document.kind(current)
        if kind == Kind.FRAGMENT_SPREAD:
            out.append(current)
        elif kind == Kind.SELECTION_SET or kind.is_selection():
            _spreads_under(document, current, out)
        current = document.next_sibling(current)


def _has_spread(document: Document, selection_set: Int) -> Bool:
    """Return True if a fragment spread is under a selection set."""
    var current = document.first_child(selection_set)
    while current != NO_NODE:
        if document.kind(current) == Kind.FRAGMENT_SPREAD:
            return True
        var inner = document.child(current, Role.SELECTION_SET)
        if inner != NO_NODE and _has_spread(document, inner):
            return True
        current = document.next_sibling(current)
    return False


def _spread_closes(document: Document, selection_set: Int) -> Bool:
    """Return True if a spread under a selection set names a fragment that
    has a spread: only then can a cycle pass through the set."""
    var current = document.first_child(selection_set)
    while current != NO_NODE:
        if document.kind(current) == Kind.FRAGMENT_SPREAD:
            var target = _fragment_definition(document, document.name(current))
            if target != NO_NODE and _has_spread(
                document, document.child(target, Role.SELECTION_SET)
            ):
                return True
        else:
            var inner = document.child(current, Role.SELECTION_SET)
            if inner != NO_NODE and _spread_closes(document, inner):
                return True
        current = document.next_sibling(current)
    return False


def _find_cycle(
    document: Document,
    fragments: List[Int],
    spreads: List[List[Int]],
    fragment: Int,
    mut visited: List[Bool],
    mut stack: List[Bool],
) -> Int:
    """Return the fragment that closes a cycle through `fragment`, or -1:
    `detectFragmentCycle`. The fragments are indexes into `fragments`."""
    if stack[fragment]:
        return fragment
    if visited[fragment]:
        return -1
    visited[fragment] = True
    stack[fragment] = True
    for spread in spreads[fragment]:
        var name = document.name(spread)
        var next = 0
        while (
            next < len(fragments) and not document.name(fragments[next]) == name
        ):
            next += 1
        if next < len(fragments):
            var found = _find_cycle(
                document, fragments, spreads, next, visited, stack
            )
            if found >= 0:
                return found
    stack[fragment] = False
    return -1


def _cycle(document: Document) -> Int:
    """Return the fragment definition that closes a fragment cycle, or
    `NO_NODE`: `fragmentCycleVisitor`. The walk of upstream reads the
    spreads before any removal, so this runs before the removals."""
    var possible = False
    var definition = document.first_child(document.root)
    while definition != NO_NODE and not possible:
        possible = document.kind(
            definition
        ) == Kind.FRAGMENT_DEFINITION and _spread_closes(
            document, document.child(definition, Role.SELECTION_SET)
        )
        definition = document.next_sibling(definition)
    if not possible:
        return NO_NODE
    var fragments = List[Int]()
    var spreads = List[List[Int]]()
    definition = document.first_child(document.root)
    while definition != NO_NODE:
        if document.kind(definition) == Kind.FRAGMENT_DEFINITION:
            fragments.append(definition)
            var under = List[Int]()
            _spreads_under(document, definition, under)
            spreads.append(under^)
        definition = document.next_sibling(definition)
    var visited = List[Bool](length=len(fragments), fill=False)
    var stack = List[Bool](length=len(fragments), fill=False)
    var start = 0
    while start < len(fragments):
        if len(spreads[start]) > 0:
            var found = _find_cycle(
                document, fragments, spreads, start, visited, stack
            )
            if found >= 0:
                return fragments[found]
        start += 1
    return NO_NODE


def directive_include_skip(
    mut document: Document,
    schema: Schema,
    variables: String,
    keep_nodes: Bool,
) raises -> List[String]:
    """Remove the selections that `@include` and `@skip` exclude, and the
    directives that keep their selection: `directiveIncludeSkipKeepNodes`.

    The same walk refuses a fragment cycle (`preventFragmentCycles`) and
    collects the variables that an argument uses (`detectVariableUsage`). A
    selection set that loses every selection gets the placeholder
    `__internal_typename: __typename`. The walk checks each root type and
    type condition, so the later passes do not need to.

    Args:
        document: The operation document.
        schema: The schema.
        variables: The variables JSON, for an `if: $variable`.
        keep_nodes: Remove each `@include` and `@skip` with a known
            condition, and keep its selection (`WithIgnoreSkipInclude`).

    Returns:
        The variables that the arguments use, before the removal: the ones
        that `delete_unused_variables` can delete.

    Raises:
        Error: `Unknown type "<name>".` for an unknown root or fragment
            type, or `fragment spread: <name> forms fragment cycle`.
    """
    return directive_include_skip_with_defer(
        document, schema, variables, keep_nodes
    )[0].copy()


def directive_include_skip_with_defer(
    mut document: Document,
    schema: Schema,
    variables: String,
    keep_nodes: Bool,
) raises -> Tuple[List[String], Bool]:
    """Run `directive_include_skip`, and also tell whether the document has
    a `@defer` directive.

    Without a `@defer`, the `@defer` stages change nothing, so the
    normalizer skips them. The walk reads each directive name already, so
    the check costs one comparison for each directive.

    Args:
        document: The operation document.
        schema: The schema.
        variables: The variables JSON, for an `if: $variable`.
        keep_nodes: See `directive_include_skip`.

    Returns:
        The variables that the arguments use, and whether a directive of an
        operation or a fragment definition is `@defer`.

    Raises:
        Error: As `directive_include_skip`.
    """
    var cycle = _cycle(document)
    var state = _IncludeSkip(keep_nodes)
    var definition = document.first_child(document.root)
    while definition != NO_NODE:
        var kind = document.kind(definition)
        if kind == Kind.OPERATION_DEFINITION:
            var type = root_type(schema, document, definition)
            var variable = document.child(definition, Role.VARIABLE_DEFINITION)
            while variable != NO_NODE:
                _directives(document, state, variables, variable, NO_NODE)
                variable = document.next_with_role(variable)
            _directives(document, state, variables, definition, NO_NODE)
            _include_skip_set(
                document,
                schema,
                state,
                variables,
                document.child(definition, Role.SELECTION_SET),
                type,
            )
        elif kind == Kind.FRAGMENT_DEFINITION:
            var type = type_condition(schema, document, definition, NO_TYPE)
            _directives(document, state, variables, definition, NO_NODE)
            _include_skip_set(
                document,
                schema,
                state,
                variables,
                document.child(definition, Role.SELECTION_SET),
                type,
            )
        definition = document.next_sibling(definition)
    if cycle != NO_NODE:
        raise Error(
            "fragment spread: ", document.name(cycle), " forms fragment cycle"
        )
    var used = List[String]()
    swap(used, state.used)
    return (used^, state.has_defer)


@always_inline
def _fragment_definition(document: Document, name: StringSlice) -> Int:
    """Return the first fragment definition with a name, or `NO_NODE`."""
    var pending_4 = document.first_child(document.root)
    while pending_4 != NO_NODE:
        var definition = pending_4
        pending_4 = document.next_sibling(definition)
        if (
            document.kind(definition) == Kind.FRAGMENT_DEFINITION
            and document.name(definition) == name
        ):
            return definition
    return NO_NODE


@always_inline
def _can_inline_spread(schema: Schema, enclosing: Int, fragment: Int) -> Bool:
    """Return True if a fragment of type `fragment` can replace a spread in
    a selection set of type `enclosing`: the cases of
    `replaceFragmentSpread`."""
    if enclosing == NO_TYPE:
        return False
    if enclosing == fragment:
        return True
    var outer = schema.types[enclosing].kind
    var inner = schema.types[fragment].kind
    if inner == TypeKind.INTERFACE:
        if outer == TypeKind.OBJECT:
            if declares_interface(
                schema, enclosing, fragment
            ) and has_fields_of(schema, enclosing, fragment):
                return True
        elif outer == TypeKind.INTERFACE:
            if interfaces_intersect(schema, fragment, enclosing):
                return True
        elif outer == TypeKind.UNION:
            if union_intersects_interface(schema, enclosing, fragment):
                return True
    if inner == TypeKind.UNION and is_member(schema, enclosing, fragment):
        return True
    if outer == TypeKind.INTERFACE:
        if declares_interface(schema, fragment, enclosing) and has_fields_of(
            schema, fragment, enclosing
        ):
            return True
        if inner == TypeKind.UNION and union_intersects_interface(
            schema, fragment, enclosing
        ):
            return True
    if outer == TypeKind.UNION and is_member(schema, fragment, enclosing):
        return True
    return False


def _inline_spread(
    mut document: Document,
    selection_set: Int,
    spread: Int,
    definition: Int,
):
    """Replace a spread with an inline fragment that copies the fragment:
    `ReplaceFragmentSpreadWithInlineFragment`."""
    var inline = document.add(Kind.INLINE_FRAGMENT, Role.SELECTION)
    document.append_child(
        inline, clone(document, document.child(definition, Role.TYPE_CONDITION))
    )
    for directive in document.children(spread, Role.DIRECTIVE):
        document.append_child(inline, clone(document, directive))
    document.append_child(
        inline, clone(document, document.child(definition, Role.SELECTION_SET))
    )
    var previous = previous_sibling(document, selection_set, spread)
    remove_child(document, selection_set, spread)
    insert_after(document, selection_set, previous, inline)


def _spread_inline_set(
    mut document: Document,
    schema: Schema,
    selection_set: Int,
    enclosing: Int,
) raises:
    """Inline the spreads of a selection set, then walk its selections."""
    var changed = True
    while changed:
        changed = False
        var selection = document.first_child(selection_set)
        while selection != NO_NODE:
            if document.kind(selection) == Kind.FRAGMENT_SPREAD:
                var name = document.name(selection)
                var definition = _fragment_definition(document, name)
                if definition == NO_NODE:
                    raise Error("fragment: ", name, " undefined")
                var type = type_condition(schema, document, definition, NO_TYPE)
                if _can_inline_spread(schema, enclosing, type):
                    _inline_spread(
                        document, selection_set, selection, definition
                    )
                    changed = True
                    break
            selection = document.next_sibling(selection)
    _walk_children[_spread_inline_set](
        document, schema, selection_set, enclosing
    )


@always_inline
def _walk_children[
    visit: SetVisitor, typed: Bool = True
](
    mut document: Document, schema: Schema, selection_set: Int, enclosing: Int
) raises:
    """Run `visit` on the selection set of each field and inline fragment
    of a selection set, with its enclosing type."""
    var selection = document.first_child(selection_set)
    while selection != NO_NODE:
        var kind = document.kind(selection)
        if kind == Kind.FIELD:
            var inner = document.child(selection, Role.SELECTION_SET)
            if inner != NO_NODE:
                var type = NO_TYPE
                comptime if typed:
                    type = field_type(schema, document, enclosing, selection)
                visit(document, schema, inner, type)
        elif kind == Kind.INLINE_FRAGMENT:
            var type = NO_TYPE
            comptime if typed:
                type = type_condition(schema, document, selection, enclosing)
            visit(
                document,
                schema,
                document.child(selection, Role.SELECTION_SET),
                type,
            )
        selection = document.next_sibling(selection)


@always_inline
def _walk_operations[
    visit: SetVisitor, typed: Bool = True
](mut document: Document, schema: Schema, fragments: Bool) raises:
    """Run `visit` on the selection set of each operation, and of each
    fragment definition when `fragments` is True."""
    var pending_5 = document.first_child(document.root)
    while pending_5 != NO_NODE:
        var definition = pending_5
        pending_5 = document.next_sibling(definition)
        var kind = document.kind(definition)
        if kind == Kind.OPERATION_DEFINITION:
            visit(
                document,
                schema,
                document.child(definition, Role.SELECTION_SET),
                root_type(schema, document, definition) if typed else NO_TYPE,
            )
        elif fragments and kind == Kind.FRAGMENT_DEFINITION:
            visit(
                document,
                schema,
                document.child(definition, Role.SELECTION_SET),
                type_condition(
                    schema, document, definition, NO_TYPE
                ) if typed else NO_TYPE,
            )


def fragment_spread_inline(mut document: Document, schema: Schema) raises:
    """Replace each fragment spread in the operations with an inline
    fragment that copies the fragment: `fragmentSpreadInline`.

    A spread whose fragment type cannot apply to the enclosing type stays,
    for validation to report.

    Args:
        document: The operation document.
        schema: The schema.

    Raises:
        Error: `fragment: <name> undefined` for a spread of an unknown
            fragment, or `Unknown type "<name>".`.
    """
    _walk_operations[_spread_inline_set](document, schema, False)


def operations_have_spread(document: Document) -> Bool:
    """Return True if a fragment spread is in an operation.

    After `directive_include_skip`, which checks each type condition,
    `fragment_spread_inline` changes nothing and raises nothing in a
    document without one, so the normalizer skips it.

    Args:
        document: The operation document.

    Returns:
        Whether a selection set of an operation has a fragment spread.
    """
    var definition = document.first_child(document.root)
    while definition != NO_NODE:
        if document.kind(
            definition
        ) == Kind.OPERATION_DEFINITION and _has_spread(
            document, document.child(definition, Role.SELECTION_SET)
        ):
            return True
        definition = document.next_sibling(definition)
    return False


@always_inline
def _self_aliasing_here(
    mut document: Document, schema: Schema, selection_set: Int, enclosing: Int
) raises:
    """Remove the self aliases of the fields of a selection set."""
    var selection = document.first_child(selection_set)
    while selection != NO_NODE:
        if document.kind(selection) == Kind.FIELD:
            var alias = document.child(selection, Role.ALIAS)
            if alias != NO_NODE and text_equal(
                document, alias, document.child(selection, Role.NAME)
            ):
                remove_child(document, selection, alias)
        selection = document.next_sibling(selection)


def _self_aliasing_set(
    mut document: Document, schema: Schema, selection_set: Int, enclosing: Int
) raises:
    """Run the pass on a selection set and the sets under it."""
    _self_aliasing_here(document, schema, selection_set, enclosing)
    _walk_children[_self_aliasing_set, False](
        document, schema, selection_set, enclosing
    )


def remove_self_aliasing(mut document: Document, schema: Schema) raises:
    """Remove each alias that equals its field name: `removeSelfAliasing`.

    Args:
        document: The operation document.
        schema: The schema.

    Raises:
        Error: `Unknown type "<name>".`, as the walker of upstream.
    """
    _walk_operations[_self_aliasing_set, False](document, schema, True)


@always_inline
def _could_inline(
    document: Document, schema: Schema, fragment: Int, enclosing: Int
) -> Bool:
    """Return True if the selections of an inline fragment can replace it:
    `couldInline`."""
    if document.child(fragment, Role.DIRECTIVE) != NO_NODE:
        return False
    var condition = type_condition_name(document, fragment)
    if condition.byte_length() == 0:
        return True
    if enclosing == NO_TYPE:
        return False
    if condition == schema.types[enclosing].name:
        return True
    if not _object_implements(schema, enclosing, condition):
        return False
    var selection = document.first_child(
        document.child(fragment, Role.SELECTION_SET)
    )
    while selection != NO_NODE:
        if document.kind(selection) == Kind.INLINE_FRAGMENT:
            var nested = type_condition_name(document, selection)
            if not (
                nested == schema.types[enclosing].name
                or _object_implements(schema, enclosing, nested)
            ):
                return False
        selection = document.next_sibling(selection)
    return True


@always_inline
def _object_implements(
    schema: Schema, type: Int, interface: StringSlice
) -> Bool:
    """Return True if an object type declares an interface by name:
    `TypeDefinitionContainsImplementsInterface`."""
    if schema.types[type].kind != TypeKind.OBJECT:
        return False
    var named = schema.type_named(interface)
    return named >= 0 and declares_interface(schema, type, named)


@always_inline
def _inline_selections_here(
    mut document: Document, schema: Schema, selection_set: Int, enclosing: Int
) raises:
    """Inline the selections of the inline fragments of a selection set."""
    var changed = True
    while changed:
        changed = False
        var selection = document.first_child(selection_set)
        while selection != NO_NODE:
            if document.kind(
                selection
            ) == Kind.INLINE_FRAGMENT and _could_inline(
                document, schema, selection, enclosing
            ):
                splice(
                    document,
                    selection_set,
                    selection,
                    document.child(selection, Role.SELECTION_SET),
                )
                changed = True
                break
            selection = document.next_sibling(selection)


def _inline_selections_set(
    mut document: Document, schema: Schema, selection_set: Int, enclosing: Int
) raises:
    """Run the pass on a selection set and the sets under it."""
    _inline_selections_here(document, schema, selection_set, enclosing)
    _walk_children[_inline_selections_set](
        document, schema, selection_set, enclosing
    )


def inline_selections_from_inline_fragments(
    mut document: Document, schema: Schema
) raises:
    """Replace each inline fragment that applies to every object of its
    enclosing type with its selections:
    `inlineSelectionsFromInlineFragments`.

    Args:
        document: The operation document.
        schema: The schema.

    Raises:
        Error: `Unknown type "<name>".`, as the walker of upstream.
    """
    _walk_operations[_inline_selections_set](document, schema, True)


@always_inline
def _can_merge(document: Document, left: Int, right: Int) -> Bool:
    """Return True if two selections of one kind merge:
    `fragmentsCanBeMerged`, or `fieldsHaveSelections` and
    `fieldsCanMerge`."""
    if document.kind(left) == Kind.INLINE_FRAGMENT:
        if not type_condition_name(document, left) == type_condition_name(
            document, right
        ):
            return False
        return directives_equal(document, left, right)
    if (
        document.child(left, Role.SELECTION_SET) == NO_NODE
        or document.child(right, Role.SELECTION_SET) == NO_NODE
    ):
        return False
    if not text_equal(
        document,
        document.child(left, Role.NAME),
        document.child(right, Role.NAME),
    ):
        return False
    if not text_equal(
        document,
        document.child(left, Role.ALIAS),
        document.child(right, Role.ALIAS),
    ):
        return False
    return directives_equal(document, left, right)


@always_inline
def _merge_here(
    mut document: Document, schema: Schema, selection_set: Int, enclosing: Int
) raises:
    """Merge the inline fragments and the fields of a selection set."""
    var changed = True
    while changed:
        changed = False
        var left = document.first_child(selection_set)
        while left != NO_NODE and not changed:
            var kind = document.kind(left)
            if kind == Kind.INLINE_FRAGMENT or kind == Kind.FIELD:
                var right = document.next_sibling(left)
                while right != NO_NODE:
                    if document.kind(right) == kind and _can_merge(
                        document, left, right
                    ):
                        move_children(
                            document,
                            document.child(left, Role.SELECTION_SET),
                            document.child(right, Role.SELECTION_SET),
                        )
                        if kind == Kind.FIELD:
                            merge_fields_defer(document, left, right)
                        remove_child(document, selection_set, right)
                        changed = True
                        break
                    right = document.next_sibling(right)
            left = document.next_sibling(left)


def _merge_set(
    mut document: Document, schema: Schema, selection_set: Int, enclosing: Int
) raises:
    """Run the pass on a selection set and the sets under it."""
    _merge_here(document, schema, selection_set, enclosing)
    _walk_children[_merge_set, False](
        document, schema, selection_set, enclosing
    )


def merge_inline_fragment_selections(
    mut document: Document, schema: Schema
) raises:
    """Merge the inline fragments with the same type condition and
    directives, and the fields with the same name, alias and directives
    that have selections: `mergeInlineFragmentSelections`.

    Args:
        document: The operation document.
        schema: The schema.

    Raises:
        Error: `Unknown type "<name>".`, as the walker of upstream.
    """
    _walk_operations[_merge_set, False](document, schema, True)


def _collect_spreads(
    document: Document, selection_set: Int, mut names: List[String]
):
    """Add the name of each fragment spread under a selection set."""
    var selection = document.first_child(selection_set)
    while selection != NO_NODE:
        if document.kind(selection) == Kind.FRAGMENT_SPREAD:
            var name = String(document.name(selection))
            if name not in names:
                names.append(name^)
        else:
            var inner = document.child(selection, Role.SELECTION_SET)
            if inner != NO_NODE:
                _collect_spreads(document, inner, names)
        selection = document.next_sibling(selection)


def remove_fragment_definitions(mut document: Document):
    """Remove each fragment definition that no operation spreads:
    `removeFragmentDefinitions`.

    A spread inside a fragment definition does not count.

    Args:
        document: The operation document.
    """
    var used = List[String]()
    var pending_6 = document.first_child(document.root)
    while pending_6 != NO_NODE:
        var definition = pending_6
        pending_6 = document.next_sibling(definition)
        if document.kind(definition) == Kind.OPERATION_DEFINITION:
            _collect_spreads(
                document, document.child(definition, Role.SELECTION_SET), used
            )
    var root = document.root
    var current = document.first_child(root)
    while current != NO_NODE:
        var definition = current
        current = document.next_sibling(definition)
        if document.kind(definition) == Kind.FRAGMENT_DEFINITION:
            if _index_of(used, document.name(definition)) < 0:
                remove_child(document, root, definition)


@always_inline
def _fields_equal_flat(document: Document, left: Int, right: Int) -> Bool:
    """Return True if two fields without selections are equal:
    `FieldsAreEqualFlat` with directive equality."""
    return (
        text_equal(
            document,
            document.child(left, Role.NAME),
            document.child(right, Role.NAME),
        )
        and text_equal(
            document,
            document.child(left, Role.ALIAS),
            document.child(right, Role.ALIAS),
        )
        and arguments_equal(document, left, right)
        and directives_equal(document, left, right)
    )


@always_inline
def _is_leaf_field(document: Document, node: Int) -> Bool:
    """Return True if a selection is a field without a selection set."""
    return (
        document.kind(node) == Kind.FIELD
        and document.child(node, Role.SELECTION_SET) == NO_NODE
    )


@always_inline
def _deduplicate_here(
    mut document: Document, schema: Schema, selection_set: Int, enclosing: Int
) raises:
    """Remove the duplicate leaf fields of a selection set."""
    var changed = True
    while changed:
        changed = False
        var left = document.first_child(selection_set)
        while left != NO_NODE and not changed:
            if _is_leaf_field(document, left):
                var right = document.next_sibling(left)
                while right != NO_NODE:
                    if _is_leaf_field(document, right) and _fields_equal_flat(
                        document, left, right
                    ):
                        merge_fields_defer(document, left, right)
                        remove_child(document, selection_set, right)
                        changed = True
                        break
                    right = document.next_sibling(right)
            left = document.next_sibling(left)


def _deduplicate_set(
    mut document: Document, schema: Schema, selection_set: Int, enclosing: Int
) raises:
    """Run the pass on a selection set and the sets under it."""
    _deduplicate_here(document, schema, selection_set, enclosing)
    _walk_children[_deduplicate_set, False](
        document, schema, selection_set, enclosing
    )


def deduplicate_fields(mut document: Document, schema: Schema) raises:
    """Remove each leaf field that equals an earlier one in its selection
    set: `deduplicateFields`.

    Args:
        document: The operation document.
        schema: The schema.

    Raises:
        Error: `Unknown type "<name>".`, as the walker of upstream.
    """
    _walk_operations[_deduplicate_set, False](document, schema, True)


def _other_set(
    mut document: Document, schema: Schema, selection_set: Int, enclosing: Int
) raises:
    """Inline the inline fragments, then remove the self aliases, of a
    selection set and the sets under it."""
    _inline_selections_here(document, schema, selection_set, enclosing)
    _self_aliasing_here(document, schema, selection_set, enclosing)
    _walk_children[_other_set](document, schema, selection_set, enclosing)


def inline_selections_and_remove_self_aliasing(
    mut document: Document, schema: Schema
) raises:
    """Run `inline_selections_from_inline_fragments` and
    `remove_self_aliasing` on one walk, as the upstream stage `Other` does.

    Args:
        document: The operation document.
        schema: The schema.

    Raises:
        Error: `Unknown type "<name>".`, as the walker of upstream.
    """
    _walk_operations[_other_set](document, schema, True)


def _cleanup_set(
    mut document: Document, schema: Schema, selection_set: Int, enclosing: Int
) raises:
    """Merge, then deduplicate, a selection set and the sets under it."""
    _merge_here(document, schema, selection_set, enclosing)
    _deduplicate_here(document, schema, selection_set, enclosing)
    _walk_children[_cleanup_set, False](
        document, schema, selection_set, enclosing
    )


def merge_and_deduplicate(mut document: Document, schema: Schema) raises:
    """Run `merge_inline_fragment_selections` and `deduplicate_fields` on
    one walk.

    The result is the same as the two passes in turn: a merge in a
    selection set changes only the selections of that set and of the sets
    under it, and the deduplication of a set reads only its own selections.

    Args:
        document: The operation document.
        schema: The schema.

    Raises:
        Error: Never; the signature matches the other passes.
    """
    _walk_operations[_cleanup_set, False](document, schema, True)


def merge_inline_and_deduplicate_set(
    mut document: Document, schema: Schema, selection_set: Int, enclosing: Int
) raises:
    """Run `merge_inline_fragment_selections`,
    `inline_selections_from_inline_fragments` and `deduplicate_fields` on
    one walk of a selection set and the sets under it.

    The walk enters each selection set in document order, and runs the
    three passes on it in turn, as the walker of
    `NewAbstractFieldNormalizer` does with its three visitors.

    Args:
        document: The operation document.
        schema: The schema.
        selection_set: The `SelectionSet` node.
        enclosing: The enclosing type of the selection set, or `NO_TYPE`.

    Raises:
        Error: `Unknown type "<name>".`, as the walker of upstream.
    """
    _merge_here(document, schema, selection_set, enclosing)
    _inline_selections_here(document, schema, selection_set, enclosing)
    _deduplicate_here(document, schema, selection_set, enclosing)
    _walk_children[merge_inline_and_deduplicate_set](
        document, schema, selection_set, enclosing
    )


def _used_in_set(document: Document, node: Int, mut names: List[String]):
    """Add the variables of every argument under a node, in walk order."""
    var current = document.first_child(node)
    while current != NO_NODE:
        var kind = document.kind(current)
        if kind == Kind.ARGUMENT:
            _add_variables(document, document.child(current, Role.VALUE), names)
        elif (
            kind == Kind.FIELD
            or kind == Kind.DIRECTIVE
            or kind == Kind.SELECTION_SET
            or kind == Kind.INLINE_FRAGMENT
            or kind == Kind.FRAGMENT_SPREAD
            or kind == Kind.VARIABLE_DEFINITION
        ):
            _used_in_set(document, current, names)
        current = document.next_sibling(current)


def detect_variable_usage(document: Document) -> List[String]:
    """Return the variables that an argument uses, anywhere in the
    document: `detectVariableUsage` on a walker of its own.

    Args:
        document: The operation document.

    Returns:
        The names, once each, for `delete_unused_variables`.
    """
    var names = List[String]()
    var definition = document.first_child(document.root)
    while definition != NO_NODE:
        _used_in_set(document, definition, names)
        definition = document.next_sibling(definition)
    return names^


def delete_unused_variables(
    mut document: Document, mut variables: String, safe: List[String]
):
    """Remove the variable definitions that no argument uses, with their
    values: `deleteUnusedVariables`.

    Only a variable in `safe` goes: one that an argument used before the
    first stage removed selections. A variable that nothing ever used stays,
    for validation to report.

    Args:
        document: The operation document.
        variables: The variables JSON; the deleted variables leave it.
        safe: The variables that `directive_include_skip` returned.
    """
    var used = List[String]()
    var pending_7 = document.first_child(document.root)
    while pending_7 != NO_NODE:
        var definition = pending_7
        pending_7 = document.next_sibling(definition)
        _used_in_set(document, definition, used)
        if document.kind(definition) != Kind.OPERATION_DEFINITION:
            continue
        for variable in document.children(definition, Role.VARIABLE_DEFINITION):
            var name = String(
                document.name(document.child(variable, Role.VARIABLE))
            )
            if _index_of(used, name) >= 0 or _index_of(safe, name) < 0:
                continue
            variables = delete_member(variables, name)
            remove_child(document, definition, variable)

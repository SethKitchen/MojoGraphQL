# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The `@defer` stages of graphql-go-tools v2 `astnormalization`.

| Function | Upstream file |
| --- | --- |
| `defer_expand_into_internal` | `defer_expand_into_internal.go` |
| `defer_ensure_typename` | `defer_ensure_typename.go` |
| `defer_align_typename_scope` | `defer_align_typename_scope.go` |
| `defer_populate_parent_ids` | `defer_populate_parent_ids.go` |
| `add_defer_internal_directive` | `ast.Document.AddDeferInternalDirectiveToField` |

`defer_expand_into_internal` removes `@defer` from each inline fragment of
the operations. When the defer is on, it puts
`@__defer_internal(id: <id>, label: <label>, parentDeferId: <parent>)` on
each field under the fragment. The other stages correct these directives
after the field merging. `gql_normalization.edit.merge_fields_defer` is
`MergeFieldsDefer`.

Each stage walks the selection sets of the document in order, as the
walker of upstream does, and edits the document in place.

Differences from upstream:

- Upstream reads the `label` argument as the raw content between the
  quotes. Here it is the decoded string value, and the printer escapes it
  again. A label without an escape sequence prints the same.
- A `label` that is not a string literal, such as a variable, gives no
  label. Upstream reads the string value at the index of that value, which
  is an unrelated string of the document.
- The `ignore` flag of `deferExpandIntoInternalVisitor` has no counterpart:
  upstream never sets it, and `disabled` has the same effect.
"""

from std.collections import Set

from gql_language.ast import Document, Kind, NO_NODE, Role

from gql_normalization.edit import (
    DEFER_INTERNAL,
    insert_after,
    previous_sibling,
    remove_child,
)
from gql_normalization.selections import (
    add_typename_placeholder,
    variable_boolean,
)

comptime DEFER = "defer"
"""The name of the `@defer` directive: upstream `literal.DEFER`."""

comptime PARENT_DEFER_ID = "parentDeferId"
"""The argument of `@__defer_internal` that names the parent defer."""


# --- directive and argument helpers -------------------------------------


@always_inline
def _directive(document: Document, node: Int, name: StringSlice) -> Int:
    """Return the first directive of a node with a name, or `NO_NODE`:
    `HasDirectiveByNameBytes`."""
    var directive = document.child(node, Role.DIRECTIVE)
    while directive != NO_NODE:
        if document.name(directive) == name:
            return directive
        directive = document.next_with_role(directive)
    return NO_NODE


@always_inline
def _argument(document: Document, directive: Int, name: StringSlice) -> Int:
    """Return the first argument of a directive with a name, or `NO_NODE`."""
    var argument = document.child(directive, Role.ARGUMENT)
    while argument != NO_NODE:
        if document.name(argument) == name:
            return argument
        argument = document.next_with_role(argument)
    return NO_NODE


@always_inline
def _value(document: Document, directive: Int, name: StringSlice) -> Int:
    """Return the value of the first argument with a name, or `NO_NODE`:
    `DirectiveArgumentValueByName`."""
    var argument = _argument(document, directive, name)
    if argument == NO_NODE:
        return NO_NODE
    return document.child(argument, Role.VALUE)


def _int_value(document: Document, value: Int) -> Int:
    """Return the integer of an `IntValue` with no sign: `IntValueAsInt`.
    The defer ids are positive."""
    var digits = document.text(value).as_bytes()
    var total = 0
    var at = 0
    while at < len(digits):
        total = total * 10 + Int(digits[at]) - ord("0")
        at += 1
    return total


@always_inline
def _is_int(document: Document, value: Int) -> Bool:
    """Return True if a value node is an `IntValue`."""
    return value != NO_NODE and document.kind(value) == Kind.INT


@fieldwise_init
struct DeferInfo(Copyable, Movable):
    """The `@__defer_internal` of a field: upstream `FieldDeferInfo`."""

    var id: Int
    """The defer id; 0 when the field has no valid directive."""
    var label: String
    """The `label` argument, or empty."""
    var parent: Int
    """The `parentDeferId` argument, or 0."""
    var directive: Int
    """The directive node, or `NO_NODE`."""


def field_defer_id(document: Document, field: Int) -> Tuple[Int, Int]:
    """Return the defer id of a field and its `@__defer_internal`:
    `FieldInternalDeferIDWithDirectiveRef`.

    Args:
        document: The operation document.
        field: The field.

    Returns:
        The id and the directive, or `(0, NO_NODE)` when the field has no
        `@__defer_internal` with an integer `id`.
    """
    var directive = _directive(document, field, DEFER_INTERNAL)
    if directive == NO_NODE:
        return (0, NO_NODE)
    var id = _value(document, directive, "id")
    if not _is_int(document, id):
        return (0, NO_NODE)
    return (_int_value(document, id), directive)


def field_defer_info(document: Document, field: Int) -> DeferInfo:
    """Return the `@__defer_internal` of a field: `FieldDeferInfo`.

    Args:
        document: The operation document.
        field: The field.

    Returns:
        The id, label and parent; the id is 0 when the field has no
        `@__defer_internal` with a nonzero integer `id`.
    """
    var found = field_defer_id(document, field)
    if found[0] == 0:
        return DeferInfo(0, String(), 0, NO_NODE)
    var directive = found[1]
    var label = String()
    var label_value = _value(document, directive, "label")
    if label_value != NO_NODE and document.kind(label_value) == Kind.STRING:
        label = document.string_value(label_value)
    var parent = 0
    var parent_value = _value(document, directive, PARENT_DEFER_ID)
    if _is_int(document, parent_value):
        parent = _int_value(document, parent_value)
    return DeferInfo(found[0], label^, parent, directive)


def _add_int_argument(
    mut document: Document, directive: Int, name: StringSlice, value: Int
):
    """Add `name: value` as the last argument of a directive:
    `AddIntArgument`."""
    var argument = document.add_child(directive, Kind.ARGUMENT, Role.ARGUMENT)
    _ = document.add_name(argument, Role.NAME, name)
    var number = document.add_text(Kind.INT, Role.VALUE, String(value))
    document.append_child(argument, number)


def add_defer_internal_directive(
    mut document: Document, field: Int, id: Int, label: String, parent: Int
):
    """Add `@__defer_internal(id: id, label: label, parentDeferId: parent)`
    after the other directives of a field: upstream
    `AddDeferInternalDirectiveToField`.

    Args:
        document: The operation document.
        field: The field.
        id: The defer id; 0 adds nothing.
        label: The label; empty for none.
        parent: The parent defer id; 0 for none.
    """
    if id == 0:
        return
    var directive = document.add(Kind.DIRECTIVE, Role.DIRECTIVE)
    _ = document.add_name(directive, Role.NAME, DEFER_INTERNAL)
    _add_int_argument(document, directive, "id", id)
    if label != "":
        var argument = document.add_child(
            directive, Kind.ARGUMENT, Role.ARGUMENT
        )
        _ = document.add_name(argument, Role.NAME, "label")
        var text = document.add_text(Kind.STRING, Role.VALUE, label)
        document.append_child(argument, text)
    if parent != 0:
        _add_int_argument(document, directive, PARENT_DEFER_ID, parent)
    var last = Int(document.nodes[field].last)
    if document.role(last) == Role.SELECTION_SET:
        last = previous_sibling(document, field, last)
    insert_after(document, field, last, directive)


# --- the walk ------------------------------------------------------------


trait _Visitor(Movable):
    """The callbacks of one stage, in the order of the upstream walker."""

    def enter_owner(
        mut self, mut document: Document, node: Int, variables: String
    ):
        """Enter a field or an inline fragment."""
        ...

    def enter_set(mut self, mut document: Document, node: Int):
        """Enter a selection set, before its selections."""
        ...

    def leave_owner(mut self, mut document: Document, node: Int):
        """Leave a field or an inline fragment."""
        ...


def _walk[
    V: _Visitor
](mut document: Document, mut visitor: V, fragments: Bool, variables: String,):
    """Walk the selection sets of each operation, and of each fragment
    definition when `fragments` is True, in document order.

    A selection that `enter_set` adds to its set is walked too, as
    upstream copies the selections after the enter visitors run.
    """
    var owners = List[Int]()
    var cursors = List[Int]()
    var definition = document.first_child(document.root)
    while definition != NO_NODE:
        var kind = document.kind(definition)
        if kind == Kind.OPERATION_DEFINITION or (
            fragments and kind == Kind.FRAGMENT_DEFINITION
        ):
            var root = document.child(definition, Role.SELECTION_SET)
            visitor.enter_set(document, root)
            owners.append(NO_NODE)
            cursors.append(document.first_child(root))
            while len(cursors) > 0:
                var current = cursors[len(cursors) - 1]
                if current == NO_NODE:
                    _ = cursors.pop()
                    var owner = owners.pop()
                    if owner != NO_NODE:
                        visitor.leave_owner(document, owner)
                    continue
                cursors[len(cursors) - 1] = document.next_sibling(current)
                var selection = document.kind(current)
                if selection == Kind.FRAGMENT_SPREAD:
                    continue
                visitor.enter_owner(document, current, variables)
                var inner = document.child(current, Role.SELECTION_SET)
                if inner == NO_NODE:
                    visitor.leave_owner(document, current)
                    continue
                visitor.enter_set(document, inner)
                owners.append(current)
                cursors.append(document.first_child(inner))
        definition = document.next_sibling(definition)


@always_inline
def _has_field(document: Document, selection_set: Int) -> Bool:
    """Return True if a selection set has a field selection:
    `SelectionSetFieldSelections` is not empty."""
    var selection = document.first_child(selection_set)
    while selection != NO_NODE:
        if document.kind(selection) == Kind.FIELD:
            return True
        selection = document.next_sibling(selection)
    return False


# --- defer_expand_into_internal ------------------------------------------


@fieldwise_init
struct _Defer(Copyable, Movable):
    """An active `@defer`: upstream `deferInfo`."""

    var parent: Int
    """The id of the enclosing defer, or 0."""
    var id: Int
    """The defer id."""
    var label: String
    """The label, or empty."""
    var fragment: Int
    """The inline fragment."""


struct _Expand(_Visitor):
    """The state of `deferExpandIntoInternalVisitor`."""

    var defers: List[_Defer]
    """The active defers, innermost last."""
    var current: Int
    """The last defer id given out."""
    var disabled: Bool
    """Remove `@defer` without expanding it."""

    def __init__(out self, disabled: Bool):
        """Start with no defer."""
        self.defers = List[_Defer]()
        self.current = 0
        self.disabled = disabled

    def enter_owner(
        mut self, mut document: Document, node: Int, variables: String
    ):
        """Remove `@defer` from an inline fragment, and start a defer when
        it is on and the fragment has a field: `EnterInlineFragment`."""
        if document.kind(node) != Kind.INLINE_FRAGMENT:
            return
        var directive = _directive(document, node, DEFER)
        if directive == NO_NODE:
            return
        var enabled = True
        var condition = _value(document, directive, "if")
        if condition != NO_NODE:
            var kind = document.kind(condition)
            if kind == Kind.BOOLEAN:
                enabled = document.boolean_value(condition)
            elif kind == Kind.VARIABLE:
                var known = variable_boolean(
                    document, variables, document.name(condition)
                )
                enabled = known[1] and known[0]
            else:
                enabled = False
        remove_child(document, node, directive)
        if not enabled or self.disabled:
            return
        if not _has_field(document, document.child(node, Role.SELECTION_SET)):
            return
        var label = String()
        var label_value = _value(document, directive, "label")
        if label_value != NO_NODE and document.kind(label_value) == Kind.STRING:
            label = document.string_value(label_value)
        self.current += 1
        var parent = 0
        if len(self.defers) > 0:
            parent = self.defers[len(self.defers) - 1].id
        self.defers.append(_Defer(parent, self.current, label^, node))

    def enter_set(mut self, mut document: Document, node: Int):
        """Put the innermost defer on each field of a selection set:
        `EnterSelectionSet`."""
        if len(self.defers) == 0:
            return
        ref top = self.defers[len(self.defers) - 1]
        var selection = document.first_child(node)
        while selection != NO_NODE:
            if document.kind(selection) == Kind.FIELD:
                add_defer_internal_directive(
                    document, selection, top.id, top.label, top.parent
                )
            selection = document.next_sibling(selection)

    def leave_owner(mut self, mut document: Document, node: Int):
        """End the defer of an inline fragment: `LeaveInlineFragment`."""
        if (
            len(self.defers) > 0
            and self.defers[len(self.defers) - 1].fragment == node
        ):
            _ = self.defers.pop()


def defer_expand_into_internal(
    mut document: Document, variables: String, disabled: Bool
) -> Bool:
    """Remove `@defer` from each inline fragment of the operations, and put
    `@__defer_internal` on each field under a deferred fragment:
    `deferExpandIntoInternalWithDisabled`.

    A defer is off when its `if` argument is `false`, or a variable that is
    not `true` in the variables or in its default value. A fragment without
    a field of its own starts no defer. Each defer gets the next id, in
    document order, and the id of the enclosing defer as its parent.

    Args:
        document: The operation document.
        variables: The variables JSON.
        disabled: Remove `@defer` and expand nothing: upstream without
            `WithEnableDefer`.

    Returns:
        Whether a defer was expanded: `hasDefers`.
    """
    var visitor = _Expand(disabled)
    _walk(document, visitor, False, variables)
    return visitor.current > 0


# --- defer_ensure_typename -----------------------------------------------


struct _Fields(_Visitor):
    """The fields that enclose the current node, outermost first: the
    field entries of the upstream `Ancestors`."""

    var fields: List[Int]
    """The enclosing fields."""

    def __init__(out self):
        """Start outside of any field."""
        self.fields = List[Int]()

    def enter_owner(
        mut self, mut document: Document, node: Int, variables: String
    ):
        """Push a field."""
        if document.kind(node) == Kind.FIELD:
            self.fields.append(node)

    def enter_set(mut self, mut document: Document, node: Int):
        """Add a `__typename` placeholder when each field of a nested
        selection set is deferred: `deferEnsureTypename`."""
        if len(self.fields) == 0:
            return
        var parent = 0
        var index = len(self.fields)
        while index > 0:
            index -= 1
            var found = field_defer_id(document, self.fields[index])
            if found[1] != NO_NODE:
                parent = found[0]
                break
        var any_field = False
        var intersection = False
        var selection = document.first_child(node)
        while selection != NO_NODE:
            if document.kind(selection) == Kind.FIELD:
                any_field = True
                var directive = _directive(document, selection, DEFER_INTERNAL)
                if directive == NO_NODE:
                    return
                if parent != 0 and not intersection:
                    var id = _value(document, directive, "id")
                    if _is_int(document, id) and _int_value(document, id) == (
                        parent
                    ):
                        intersection = True
            selection = document.next_sibling(selection)
        if not any_field or intersection:
            return
        add_typename_placeholder(document, node)
        if parent != 0:
            add_defer_internal_directive(
                document, Int(document.nodes[node].last), parent, String(), 0
            )

    def leave_owner(mut self, mut document: Document, node: Int):
        """Pop a field."""
        if document.kind(node) == Kind.FIELD:
            _ = self.fields.pop()


def defer_ensure_typename(mut document: Document):
    """Add `__internal_typename: __typename` to each nested selection set
    whose fields are all deferred: `deferEnsureTypename`.

    The placeholder keeps the selection set from going empty in the plan.
    When the nearest deferred enclosing field has a defer id that no field
    of the set shares, the placeholder gets that id.

    Args:
        document: The operation document.
    """
    var visitor = _Fields()
    _walk(document, visitor, True, String())


# --- defer_align_typename_scope ------------------------------------------


struct _Align(_Visitor):
    """The state of `deferAlignTypenameScopeVisitor`."""

    var fields: List[Int]
    """The enclosing fields, outermost first."""

    def __init__(out self):
        """Start outside of any field."""
        self.fields = List[Int]()

    def enter_owner(
        mut self, mut document: Document, node: Int, variables: String
    ):
        """Give a deferred `__typename` the defer of its enclosing field:
        `EnterField`."""
        if document.kind(node) != Kind.FIELD:
            return
        self._align(document, node)
        self.fields.append(node)

    def _align(mut self, mut document: Document, field: Int):
        """Align one field."""
        if not document.name(field) == "__typename":
            return
        var found = field_defer_id(document, field)
        if found[1] == NO_NODE:
            return
        var enclosing = DeferInfo(0, String(), 0, NO_NODE)
        if len(self.fields) > 0:
            enclosing = field_defer_info(
                document, self.fields[len(self.fields) - 1]
            )
        if enclosing.id != 0 and enclosing.id == found[0]:
            return
        remove_child(document, field, found[1])
        add_defer_internal_directive(
            document, field, enclosing.id, enclosing.label, enclosing.parent
        )

    def enter_set(mut self, mut document: Document, node: Int):
        """Do nothing."""
        pass

    def leave_owner(mut self, mut document: Document, node: Int):
        """Pop a field."""
        if document.kind(node) == Kind.FIELD:
            _ = self.fields.pop()


def defer_align_typename_scope(mut document: Document):
    """Give each deferred `__typename` the defer scope of the object that it
    describes: `deferAlignTypenameScope`.

    Under a field without a defer, or at the root, the `__typename` loses
    `@__defer_internal`. Under a deferred field with another id, it gets the
    id, label and parent of that field.

    Args:
        document: The operation document.
    """
    var visitor = _Align()
    _walk(document, visitor, True, String())


# --- defer_populate_parent_ids -------------------------------------------


struct _Live(_Visitor):
    """The defer ids of the fields of the operations:
    `collectExistingDeferIds`."""

    var ids: Set[Int]
    """The ids found."""

    def __init__(out self):
        """Start with no id."""
        self.ids = Set[Int]()

    def enter_owner(
        mut self, mut document: Document, node: Int, variables: String
    ):
        """Record the defer id of a field."""
        if document.kind(node) != Kind.FIELD:
            return
        var found = field_defer_id(document, node)
        if found[1] != NO_NODE:
            self.ids.add(found[0])

    def enter_set(mut self, mut document: Document, node: Int):
        """Do nothing."""
        pass

    def leave_owner(mut self, mut document: Document, node: Int):
        """Do nothing."""
        pass


def _remove_parent(mut document: Document, directive: Int):
    """Remove the first `parentDeferId` argument of a directive:
    `removeParentDeferID`."""
    var argument = _argument(document, directive, PARENT_DEFER_ID)
    if argument != NO_NODE:
        remove_child(document, directive, argument)


def _set_parent(mut document: Document, directive: Int, parent: Int):
    """Make `parentDeferId: parent` the last argument of a directive:
    `setParentDeferID`."""
    _remove_parent(document, directive)
    _add_int_argument(document, directive, PARENT_DEFER_ID, parent)


struct _Parents(_Visitor):
    """The state of `deferPopulateParentIdsVisitor`."""

    var live: Set[Int]
    """The defer ids in the operations when the stage starts."""
    var ids: List[Int]
    """The ids of the enclosing deferred fields, outermost first."""
    var fields: List[Int]
    """The enclosing deferred fields, outermost first."""

    def __init__(out self, var live: Set[Int]):
        """Start outside of any deferred field."""
        self.live = live^
        self.ids = List[Int]()
        self.fields = List[Int]()

    def enter_owner(
        mut self, mut document: Document, node: Int, variables: String
    ):
        """Add, keep or repair the `parentDeferId` of a deferred field:
        `EnterField`."""
        if document.kind(node) != Kind.FIELD:
            return
        var found = field_defer_id(document, node)
        if found[1] == NO_NODE:
            return
        var id = found[0]
        var directive = found[1]
        var parent = _value(document, directive, PARENT_DEFER_ID)
        if parent == NO_NODE:
            if len(self.ids) > 0 and self.ids[len(self.ids) - 1] != id:
                _set_parent(document, directive, self.ids[len(self.ids) - 1])
        elif document.kind(parent) == Kind.INT:
            if _int_value(document, parent) not in self.live:
                var enclosing = self._nearest(id)
                if enclosing != 0:
                    _set_parent(document, directive, enclosing)
                else:
                    _remove_parent(document, directive)
        self.ids.append(id)
        self.fields.append(node)

    def _nearest(self, id: Int) -> Int:
        """Return the nearest enclosing defer id other than `id`, or 0:
        `nearestEnclosingDeferID`."""
        var index = len(self.ids)
        while index > 0:
            index -= 1
            if self.ids[index] != id:
                return self.ids[index]
        return 0

    def enter_set(mut self, mut document: Document, node: Int):
        """Do nothing."""
        pass

    def leave_owner(mut self, mut document: Document, node: Int):
        """Pop a deferred field: `LeaveField`."""
        if len(self.fields) > 0 and self.fields[len(self.fields) - 1] == node:
            _ = self.fields.pop()
            _ = self.ids.pop()


def defer_populate_parent_ids(mut document: Document):
    """Set the `parentDeferId` of each `@__defer_internal` after the field
    merging: `deferPopulateParentIds`.

    A field without a parent gets the id of the nearest deferred enclosing
    field. A parent that no field of the operations has any more is
    repaired to the nearest enclosing defer with another id, or removed.

    Args:
        document: The operation document.
    """
    var live = _Live()
    _walk(document, live, False, String())
    var visitor = _Parents(live.ids.copy())
    _walk(document, visitor, True, String())

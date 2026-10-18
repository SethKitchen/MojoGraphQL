# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Add `__typename` to the selection sets that need it, before validation.

Port of Apollo Kotlin `apollo-compiler`
`internal/ApolloExecutableDocumentTransform.kt` `addRequiredFields`, for
the `addTypename` modes. A selection set that needs `__typename` loses every
field named `__typename`, with its alias and its directives, and gets one
`__typename` field first, so that a parser reads it first.

The transform changes the parsed document in place: it adds the new
fields after the other nodes and relinks the siblings. Every parsed node
keeps its source range, so a validation error still points at the
source.

**Differences from upstream.**

- Key fields (`@typePolicy`) are not added: `gql_codegen` does not port
  the Apollo cache directives.
- Upstream puts the operations before the fragments in the document that
  it validates. This transform keeps the source order, so validation
  errors come in source order.
- A fragment cycle or an unknown type condition stops the
  `ifPolymorphic` walk, where upstream overflows the stack or fails.
  Validation then reports the error.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_schema.definition import NO_TYPE, Schema

from gql_codegen.options import AddTypename
from gql_codegen.schema_util import field_type, is_abstract, is_sub_type_of


struct _Fragments(Movable):
    """The fragment definitions of a document, by name."""

    var names: List[String]
    """The names, in source order."""
    var nodes: List[Int]
    """The definition nodes, in the same order."""

    def __init__(out self, document: Document):
        """Collect the fragment definitions.

        Args:
            document: The document.
        """
        self.names = List[String]()
        self.nodes = List[Int]()
        for definition in document.definitions():
            if document.kind(definition) == Kind.FRAGMENT_DEFINITION:
                self.names.append(String(document.name(definition)))
                self.nodes.append(definition)

    def find(self, name: StringSlice) -> Int:
        """Return the first fragment definition with a name.

        Args:
            name: The fragment's name.

        Returns:
            The node, or `NO_NODE`.
        """
        for index in range(len(self.names)):
            if self.names[index] == name:
                return self.nodes[index]
        return NO_NODE


def _type_condition(
    document: Document, schema: Schema, node: Int, parent: Int
) -> Int:
    """Return the type of an inline fragment or a fragment definition, or
    the parent type when an inline fragment has no type condition."""
    var condition = document.child(node, Role.TYPE_CONDITION)
    if condition == NO_NODE:
        return parent
    return schema.type_named(document.name(condition))


def _is_polymorphic(
    document: Document,
    schema: Schema,
    fragments: _Fragments,
    selection_set: Int,
    root: Int,
    mut path: List[String],
) -> Bool:
    """Return True when a fragment can match another type than `root`, as
    upstream `List<GQLSelection>.isPolymorphic`."""
    var current = document.first_child(selection_set)
    while current != NO_NODE:
        var kind = document.kind(current)
        if kind == Kind.INLINE_FRAGMENT:
            var condition = _type_condition(document, schema, current, root)
            if condition != NO_TYPE:
                if not is_sub_type_of(schema, root, condition):
                    return True
                if _is_polymorphic(
                    document,
                    schema,
                    fragments,
                    document.child(current, Role.SELECTION_SET),
                    root,
                    path,
                ):
                    return True
        elif kind == Kind.FRAGMENT_SPREAD:
            var name = String(document.name(current))
            var definition = fragments.find(name)
            if definition != NO_NODE and not name in path:
                var condition = _type_condition(
                    document, schema, definition, NO_TYPE
                )
                if condition != NO_TYPE:
                    if not is_sub_type_of(schema, root, condition):
                        return True
                    path.append(name)
                    var found = _is_polymorphic(
                        document,
                        schema,
                        fragments,
                        document.child(definition, Role.SELECTION_SET),
                        root,
                        path,
                    )
                    _ = path.pop()
                    if found:
                        return True
        current = document.next_sibling(current)
    return False


def _requires_typename(
    document: Document,
    schema: Schema,
    fragments: _Fragments,
    mode: AddTypename,
    selection_set: Int,
    parent: Int,
    is_root: Bool,
) -> Bool:
    """Return True when a selection set needs `__typename` in a mode."""
    if mode == AddTypename.IF_FRAGMENTS:
        var current = document.first_child(selection_set)
        while current != NO_NODE:
            var kind = document.kind(current)
            if kind == Kind.INLINE_FRAGMENT or kind == Kind.FRAGMENT_SPREAD:
                return True
            current = document.next_sibling(current)
        return False
    if not is_root or parent == NO_TYPE:
        return False
    if mode == AddTypename.IF_POLYMORPHIC:
        var path = List[String]()
        return _is_polymorphic(
            document, schema, fragments, selection_set, parent, path
        )
    if mode == AddTypename.IF_ABSTRACT:
        return is_abstract(schema, parent)
    return True


def _put_typename_first(mut document: Document, selection_set: Int):
    """Unlink every `__typename` field of a selection set, and put a new
    `__typename` field first."""
    var previous = NO_NODE
    var current = document.first_child(selection_set)
    while current != NO_NODE:
        var following = document.next_sibling(current)
        if (
            document.kind(current) == Kind.FIELD
            and document.name(current) == "__typename"
        ):
            if previous == NO_NODE:
                document.nodes[selection_set].first = Int32(following)
            else:
                document.nodes[previous].next = Int32(following)
            if Int(document.nodes[selection_set].last) == current:
                document.nodes[selection_set].last = Int32(previous)
        else:
            previous = current
        current = following
    var field = document.add(Kind.FIELD, Role.SELECTION)
    _ = document.add_name(field, Role.NAME, "__typename")
    var first = Int(document.nodes[selection_set].first)
    document.nodes[field].next = Int32(first)
    document.nodes[selection_set].first = Int32(field)
    if first == NO_NODE:
        document.nodes[selection_set].last = Int32(field)


def _add_to_selection_set(
    mut document: Document,
    schema: Schema,
    fragments: _Fragments,
    mode: AddTypename,
    selection_set: Int,
    parent: Int,
    is_root: Bool,
):
    """Add `__typename` to a selection set and to the selection sets in
    it, as upstream `List<GQLSelection>.addRequiredFields`."""
    if document.first_child(selection_set) == NO_NODE:
        return
    var requires = _requires_typename(
        document, schema, fragments, mode, selection_set, parent, is_root
    )
    var children = List[Int]()
    var current = document.first_child(selection_set)
    while current != NO_NODE:
        children.append(current)
        current = document.next_sibling(current)
    # The selection set is not empty here.
    for ref child in children:  # pragma: no branch
        var kind = document.kind(child)
        if kind == Kind.INLINE_FRAGMENT:
            _add_to_selection_set(
                document,
                schema,
                fragments,
                mode,
                document.child(child, Role.SELECTION_SET),
                _type_condition(document, schema, child, parent),
                False,
            )
        elif kind == Kind.FIELD:
            var inner = document.child(child, Role.SELECTION_SET)
            if inner == NO_NODE:
                continue
            var type = field_type(schema, parent, document.name(child))
            if Int(type.named) == NO_TYPE:
                continue
            _add_to_selection_set(
                document,
                schema,
                fragments,
                mode,
                inner,
                Int(type.named),
                True,
            )
    if requires:
        _put_typename_first(document, selection_set)


def add_required_fields(
    mut document: Document, schema: Schema, mode: AddTypename
):
    """Add `__typename` to each operation and fragment of a document, as
    Apollo `ApolloExecutableDocumentTransform.transform`.

    An operation's own selection set is not a root, so only `ifFragments`
    can add `__typename` there. A fragment's selection set is a root,
    because a fragment can be read from the cache on its own.

    Args:
        document: The executable document; changed in place.
        schema: The schema.
        mode: When to add `__typename`.
    """
    var fragments = _Fragments(document)
    for definition in document.definitions():
        var kind = document.kind(definition)
        var selection_set = document.child(definition, Role.SELECTION_SET)
        if kind == Kind.OPERATION_DEFINITION:
            var root = schema.root_type(document.operation(definition).value)
            _add_to_selection_set(
                document, schema, fragments, mode, selection_set, root, False
            )
        elif kind == Kind.FRAGMENT_DEFINITION:
            var condition = _type_condition(
                document, schema, definition, NO_TYPE
            )
            _add_to_selection_set(
                document,
                schema,
                fragments,
                mode,
                selection_set,
                condition,
                True,
            )

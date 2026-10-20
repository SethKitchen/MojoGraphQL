# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The normalization of one field: graphql-go-tools v2 `astnormalization`
`abstract_field_normalizer.go`.

`AbstractFieldNormalizer` runs `merge_inline_fragment_selections`,
`inline_selections_from_inline_fragments` and `deduplicate_fields` on the
selection sets under one field, and on no other selection set. The query
planner of upstream uses it after it rewrites the selections of a field of
an abstract type.

The walk goes through the operations and the fragment definitions in
document order, until it leaves the field. Thus an inline fragment with an
unknown type before the field is an error, as in upstream.

Differences from upstream:

- `normalize` takes the operation and the schema. Upstream
  `NewAbstractFieldNormalizer` keeps pointers to the two documents. A Mojo
  struct does not keep a reference to a document that it does not own.
- An error raises `Error`, in place of an `operationreport.Report`.
"""

from gql_language.ast import Document, Kind, NO_NODE, Role
from gql_schema.definition import Schema

from gql_normalization.schema_lookup import (
    NO_TYPE,
    field_type,
    root_type,
    type_condition,
)
from gql_normalization.selections import merge_inline_and_deduplicate_set


def _find_set(
    mut document: Document,
    schema: Schema,
    selection_set: Int,
    enclosing: Int,
    target: Int,
) raises -> Bool:
    """Walk a selection set until the target field, and normalize the
    selection set of that field. Return True when the walk found it."""
    var selection = document.first_child(selection_set)
    while selection != NO_NODE:
        var kind = document.kind(selection)
        if kind == Kind.FIELD:
            var inner = document.child(selection, Role.SELECTION_SET)
            if selection == target:
                if inner != NO_NODE:
                    merge_inline_and_deduplicate_set(
                        document,
                        schema,
                        inner,
                        field_type(schema, document, enclosing, selection),
                    )
                return True
            if inner != NO_NODE and _find_set(
                document,
                schema,
                inner,
                field_type(schema, document, enclosing, selection),
                target,
            ):
                return True
        elif kind == Kind.INLINE_FRAGMENT:
            if _find_set(
                document,
                schema,
                document.child(selection, Role.SELECTION_SET),
                type_condition(schema, document, selection, enclosing),
                target,
            ):
                return True
        selection = document.next_sibling(selection)
    return False


struct AbstractFieldNormalizer(Copyable, Movable):
    """Normalizes the selections under one field: upstream
    `AbstractFieldNormalizer`."""

    var target_field_ref: Int
    """The `Field` node to normalize: `targetFieldRef`."""

    def __init__(out self, field_ref: Int):
        """Make the normalizer of `NewAbstractFieldNormalizer`.

        Args:
            field_ref: The `Field` node of the operation to normalize.
        """
        self.target_field_ref = field_ref

    def normalize(self, mut operation: Document, schema: Schema) raises:
        """Merge the inline fragments and the fields, inline the inline
        fragments, and remove the duplicate fields, under the target field:
        `Normalize`.

        A target that is not a field of the document changes nothing.

        Args:
            operation: The operation document, changed in place.
            schema: The schema.

        Raises:
            Error: `Unknown type "<name>".` for an inline fragment or a
                fragment definition with an unknown type, before the target
                field or under it.
        """
        var definition = operation.first_child(operation.root)
        while definition != NO_NODE:
            var kind = operation.kind(definition)
            if not (
                kind == Kind.OPERATION_DEFINITION
                or kind == Kind.FRAGMENT_DEFINITION
            ):
                definition = operation.next_sibling(definition)
                continue
            var enclosing: Int
            if kind == Kind.OPERATION_DEFINITION:
                enclosing = root_type(schema, operation, definition)
            else:
                enclosing = type_condition(
                    schema, operation, definition, NO_TYPE
                )
            if _find_set(
                operation,
                schema,
                operation.child(definition, Role.SELECTION_SET),
                enclosing,
                self.target_field_ref,
            ):
                return
            definition = operation.next_sibling(definition)

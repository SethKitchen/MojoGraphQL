# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Find the operation of a document that a request selects.

Port of graphql-js 16.14.2 `utilities/getOperationAST.ts`.

**Differences from upstream.** The result is a node index, and `NO_NODE`
takes the place of `null`. An absent operation name is an empty
`Optional`, as `null` and `undefined` are in graphql-js.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role


def get_operation_ast(
    document: Document, operation_name: Optional[String] = None
) -> Int:
    """Return an operation of a document, as graphql-js `getOperationAST`.

    Without a name, the document must have exactly one operation.

    Args:
        document: The document.
        operation_name: The name of the operation to select, or none.

    Returns:
        The `OperationDefinition` node, or `NO_NODE` when no operation has
        the name, or when there is no name and the document does not have
        exactly one operation.
    """
    var operation = NO_NODE
    var definition = document.first_child(document.root)
    while definition != NO_NODE:
        if document.kind(definition) == Kind.OPERATION_DEFINITION:
            if not operation_name:
                # Without a name, a second operation makes the choice
                # ambiguous.
                if operation != NO_NODE:
                    return NO_NODE
                operation = definition
            elif (
                document.child(definition, Role.NAME) != NO_NODE
                and document.name(definition) == operation_name.value()
            ):
                # An anonymous operation has no name, so even an empty
                # name does not select it.
                return definition
        definition = document.next_sibling(definition)
    return operation

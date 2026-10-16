# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Join the definitions of several documents into one document.

Port of graphql-js 16.14.2 `utilities/concatAST.ts`.

**Differences from upstream.** graphql-js puts the same definition objects
in a new list. A `Document` is one arena, so this port copies each
definition and its descendants into the new document. The copy has no
source locations, as graphql-js gives the new document no `loc`.
"""

from gql_language.ast import NO_NODE, Document, Role


def concat_ast(documents: List[Document]) -> Document:
    """Return one document with the definitions of all the documents, as
    graphql-js `concatAST`.

    Args:
        documents: The documents, presumably each from a different file.

    Returns:
        A new document whose root has every definition, in order.
    """
    var out = Document()
    var index = 0
    while index < len(documents):
        ref document = documents[index]
        var definition = document.first_child(document.root)
        while definition != NO_NODE:
            var copy = out.copy_subtree(document, definition, Role.DEFINITION)
            out.append_child(out.root, copy)
            definition = document.next_sibling(definition)
        index += 1
    return out^

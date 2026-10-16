# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Descriptions on executable definitions, of the GraphQL September 2025
specification.

Port of Apollo MCP Server 2.0.0 (04e4e6e)
`crates/apollo-mcp-server/src/operations/executable_descriptions.rs`.

Differences from upstream: `strip_executable_descriptions` does not change
the document, because a `gql_language.Document` is an arena that a program
does not edit in place. It returns whether the document has a description
to remove, and `gql_mcp.executable_print.print_document` with
`strip_descriptions` leaves the descriptions out of the text.
"""

from gql_language.ast import Document, Kind, NO_NODE, Role


def non_blank_description(description: Optional[String]) -> Optional[String]:
    """Return a description's text without the white space around it, or
    nothing when it is blank, so that the next description source applies.

    Args:
        description: The decoded description, if any.

    Returns:
        The trimmed text, or `None` for a missing or blank description.
    """
    if not description:
        return None
    var trimmed = String(description.value().strip())
    if trimmed.byte_length() == 0:
        return None
    return trimmed^


def node_description(document: Document, node: Int) -> Optional[String]:
    """Return the decoded description of a definition, if it has one.

    Args:
        document: The document.
        node: An operation, variable or fragment definition.

    Returns:
        The description, or `None`.
    """
    if document.has_description(node):
        return document.description(node)
    return None


def strip_executable_descriptions(document: Document) -> Bool:
    """Return whether an operation, a variable or a fragment of the document
    has a description that the text sent to the endpoint must not keep.

    Servers whose parsers predate the September 2025 specification, such
    as the Apollo Router, refuse documents that describe executable
    definitions.

    Args:
        document: The document.

    Returns:
        Whether a description would be removed.
    """
    var definitions = document.definitions()
    var index = 0
    while index < len(definitions):
        var definition = definitions[index]
        index += 1
        var kind = document.kind(definition)
        if kind == Kind.OPERATION_DEFINITION:
            if document.has_description(definition):
                return True
            var variable = document.child(definition, Role.VARIABLE_DEFINITION)
            while variable != NO_NODE:
                if document.has_description(variable):
                    return True
                variable = document.next_with_role(variable)
        elif kind == Kind.FRAGMENT_DEFINITION:
            if document.has_description(definition):
                return True
    return False

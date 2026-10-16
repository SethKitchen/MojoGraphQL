# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Errors located at schema nodes.

graphql-js builds a `GraphQLError` from AST nodes: the error's locations
are where the nodes start, each in its own source. A schema's nodes can
come from several documents, so `error_at` takes `AstRef`s.
"""

from gql_language.ast import Document
from gql_language.error import GraphQLError, print_source_location
from gql_schema.definition import AstRef, Schema


def error_at(
    message: String, documents: List[Document], nodes: List[AstRef]
) -> GraphQLError:
    """Return an error located at nodes, as `new GraphQLError(message,
    { nodes })`.

    Args:
        message: The description.
        documents: The documents the references point into.
        nodes: The nodes; references that name no node are skipped.

    Returns:
        The error, with one location and one source excerpt per node.
    """
    var error = GraphQLError(message)
    for ref at in nodes:
        if not at.exists():
            continue
        ref document = documents[Int(at.document)]
        var location = document.location(Int(at.node))
        error.locations.append(location)
        error.excerpt += "\n\n" + print_source_location(
            document.source, location
        )
    return error^


def schema_error(
    message: String, schema: Schema, nodes: List[AstRef]
) -> GraphQLError:
    """Return an error located at nodes of a schema's documents.

    Args:
        message: The description.
        schema: The schema whose documents hold the nodes.
        nodes: The nodes.

    Returns:
        The error, with its locations.
    """
    return error_at(message, schema.documents, nodes)

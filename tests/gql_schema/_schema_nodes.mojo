# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Test helpers that print a schema's AST nodes, as graphql-js tests
`expectASTNode`, `expectExtensionASTNodes` and `expectSchemaChanges`."""

from gql_language.parser import parse
from gql_language.printer import print_node
from gql_schema.definition import AstRef, Range, Schema
from gql_schema.print import print_schema


def ast_node(schema: Schema, at: AstRef) -> String:
    """Print one node of a schema's documents, as `expectASTNode`.

    Args:
        schema: The schema.
        at: The node.

    Returns:
        The printed node.
    """
    return print_node(schema.documents[Int(at.document)], Int(at.node))


def extension_nodes(schema: Schema, span: Range) -> String:
    """Print extension nodes, as `expectExtensionASTNodes`.

    Args:
        schema: The schema.
        span: The nodes, as entries of `schema.ast_refs`.

    Returns:
        The printed nodes, with a blank line between two nodes.
    """
    var out = String("")
    for index in range(Int(span.start), span.end()):
        if index > Int(span.start):
            out += "\n\n"
        out += ast_node(schema, schema.ast_refs[index])
    return out^


def printed_definitions(sdl: String) raises -> List[String]:
    """Parse SDL and print each definition.

    Args:
        sdl: The SDL.

    Returns:
        One printed definition per definition, in order.

    Raises:
        Error: A syntax error.
    """
    var document = parse(sdl)
    var out = List[String]()
    for definition in document.definitions():
        out.append(print_node(document, definition))
    return out^


def schema_changes(schema: Schema, extended: Schema) raises -> String:
    """Print the definitions of an extended schema that the original
    schema does not have, as `expectSchemaChanges`.

    Args:
        schema: The original schema.
        extended: The extended schema.

    Returns:
        The new or changed definitions, with a blank line between two.

    Raises:
        Error: When a schema cannot be printed.
    """
    var old = printed_definitions(print_schema(schema))
    var out = String("")
    for ref definition in printed_definitions(print_schema(extended)):
        var found = False
        for ref other in old:
            if other == definition:
                found = True
        if found:
            continue
        if out != "":
            out += "\n\n"
        out += definition
    return out^

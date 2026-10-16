# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Helpers of the gql_subgraph tests: build a subgraph from SDL, query
it, and print its types."""

from std.testing import assert_equal
from gql_execution.execute import ExecutionArgs
from gql_execution.value import Values
from gql_json.parser import parse as parse_json
from gql_language.ast import Document
from gql_language.error import quote_json_string
from gql_language.parser import parse
from gql_schema.print import print_type
from gql_subgraph.build_subgraph_schema import (
    SubgraphSchema,
    build_subgraph_schema,
)


def sdl_document(sdl: String) raises -> Document:
    """Parse SDL, as `gql` does.

    Args:
        sdl: The SDL text.

    Returns:
        The document.

    Raises:
        Error: A syntax error.
    """
    return parse(sdl)


def subgraph(sdl: String) raises -> SubgraphSchema:
    """Build a subgraph schema from SDL with no resolvers.

    Args:
        sdl: The SDL text.

    Returns:
        The subgraph schema.

    Raises:
        Error: As `build_subgraph_schema` raises.
    """
    return build_subgraph_schema(sdl_document(sdl))


def build_error(sdl: String) raises -> String:
    """Return the message of the error that building a subgraph raises.

    Args:
        sdl: The SDL text.

    Returns:
        The message, or `no error`.

    Raises:
        Error: A syntax error.
    """
    var document = sdl_document(sdl)
    try:
        _ = build_subgraph_schema(document^)
    except error:
        return String(error)
    return String("no error")


def run(
    schema: SubgraphSchema, query: String, variables: String = ""
) raises -> String:
    """Execute a query against a subgraph and return the JSON result.

    Args:
        schema: The subgraph schema.
        query: The query text.
        variables: The JSON of the variable values, or empty for none.

    Returns:
        The JSON text of the result.

    Raises:
        Error: As `parse` and `SubgraphSchema.execute` raise.
    """
    var args = ExecutionArgs()
    if variables != "":
        var json = parse_json(variables)
        args.variable_values = args.values.add_json(json, json.root)
    return schema.execute(sdl_document(query), args).to_json()


def assert_service_sdl(schema: SubgraphSchema, expected: String) raises:
    """Check that `{ _service { sdl } }` gives some SDL.

    Args:
        schema: The subgraph schema.
        expected: The SDL.

    Raises:
        Error: When the result differs.
    """
    assert_equal(schema.sdl, expected)
    assert_equal(
        run(schema, "query GetServiceDetails { _service { sdl } }"),
        '{"data":{"_service":{"sdl":' + quote_json_string(expected) + "}}}",
    )


def type_sdl(schema: SubgraphSchema, name: String) raises -> String:
    """Print a type of the executable schema, as graphql-js `printType`.

    Args:
        schema: The subgraph schema.
        name: The type's name.

    Returns:
        The SDL of the type.

    Raises:
        Error: As `print_type` raises.
    """
    return print_type(schema.schema, schema.schema.type_named(name))

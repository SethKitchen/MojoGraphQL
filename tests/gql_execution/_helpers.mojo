# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Helpers of the gql_execution tests: run a query and get the JSON text
of its result, as graphql-js `JSON.stringify(result)` gives it."""

from gql_execution.execute import ExecutionArgs, execute
from gql_execution.value import UNDEFINED, Values
from gql_json.parser import parse as parse_json
from gql_language.parser import parse
from gql_schema.build import build_schema
from gql_schema.definition import Schema


def json_value(mut values: Values, text: String) raises -> Int:
    """Add a value from its JSON text.

    Args:
        values: The arena.
        text: The JSON text.

    Returns:
        The value's index.

    Raises:
        Error: For text that is not JSON.
    """
    var document = parse_json(text)
    return values.add_json(document, document.root)


def run_query(
    schema: Schema, query: String, mut args: ExecutionArgs
) raises -> String:
    """Parse a query, execute it and return the JSON of the result.

    Args:
        schema: The schema.
        query: The query text.
        args: The execution arguments.

    Returns:
        The JSON text of the result.

    Raises:
        Error: As `parse` and `execute` raise.
    """
    var document = parse(query)
    return execute(schema, document, args).to_json()


def run(
    sdl: String,
    query: String,
    root: String = "",
    variables: String = "",
) raises -> String:
    """Build a schema, execute a query with no resolvers, and return the
    JSON of the result.

    Args:
        sdl: The schema's SDL.
        query: The query text.
        root: The JSON of the root value, or empty for none.
        variables: The JSON of the variable values, or empty for none.

    Returns:
        The JSON text of the result.

    Raises:
        Error: As `build_schema`, `parse` and `execute` raise.
    """
    var schema = build_schema(sdl)
    var args = ExecutionArgs()
    if root != "":
        args.root_value = json_value(args.values, root)
    if variables != "":
        args.variable_values = json_value(args.values, variables)
    return run_query(schema, query, args)

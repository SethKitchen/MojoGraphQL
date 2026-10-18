# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The introspection JSON of an SDL, for `graph introspect --format json`.

Port of `sdl_to_introspection_json` of Rover `crates/rover-client/src/
operations/graph/introspect/introspection_json.rs`. Upstream builds the
schema with apollo-compiler and runs the Rover introspection query on it.
This port builds it with `gql_schema` and runs the same query with
`gql_execution`. The result keeps the apollo-compiler order and content:

- the types are the eight introspection types of apollo-compiler, the
  specified scalars in use, then the types of the SDL in their order;
- the directives are the `@skip`, `@include` and `@deprecated` of
  apollo-compiler, `@specifiedBy`, then the other directives of the SDL
  in their order.
"""

from gql_execution.execute import execute
from gql_json.value import JsonDocument, NO_NODE
from gql_json.writer import stringify
from gql_language.ast import Document, Kind
from gql_language.parser import parse
from gql_seamstress.introspection_types import DEPRECATED_JSON, INCLUDE_JSON
from gql_seamstress.introspection_types import (
    INTROSPECTION_TYPES_JSON,
    SKIP_JSON,
)
from gql_seamstress.introspection_types import SPECIFIEDBY_JSON
from gql_seamstress.queries import GRAPH_INTROSPECT_QUERY
from gql_schema.build import build_ast_schema

comptime _SCALARS: List[String] = ["Int", "Float", "String", "Boolean", "ID"]
"""The specified scalars, in apollo-compiler order."""


def _find_named(document: JsonDocument, items: List[Int], name: String) -> Int:
    """Return the item with a `name`, or `NO_NODE`.

    Every type and directive of an introspection result has a name.
    """
    var index = 0
    while index < len(items):
        if document.string_value(document.find(items[index], "name")) == name:
            return items[index]
        index += 1
    return NO_NODE


def _sdl_names(sdl: Document) -> Tuple[List[String], List[String]]:
    """Return the type names and the directive names of an SDL, in order."""
    var types = List[String]()
    var directives = List[String]()
    var definitions = sdl.definitions()
    var index = 0
    while index < len(definitions):
        var definition = definitions[index]
        index += 1
        var kind = sdl.kind(definition)
        if kind == Kind.DIRECTIVE_DEFINITION:
            directives.append(String(sdl.name(definition)))
        elif kind != Kind.SCHEMA_DEFINITION:
            types.append(String(sdl.name(definition)))
    return (types^, directives^)


def sdl_to_introspection_json(sdl: StringSlice) raises -> String:
    """Return the `{"__schema": ...}` object of an SDL, as upstream
    `sdl_to_introspection_json`.

    Args:
        sdl: The SDL that `encode_schema` printed.

    Returns:
        The JSON text of the introspection result, on one line.

    Raises:
        Error: A syntax error or a schema error of the SDL.
    """
    var document = parse(sdl)
    var names = _sdl_names(document)
    var documents = List[Document]()
    documents.append(document^)
    var schema = build_ast_schema(documents^)
    var data = execute(schema, parse(GRAPH_INTROSPECT_QUERY)).take_data()
    var root = data.find(data.root, "__schema")
    var types = data.children(data.find(root, "types"))
    var parts = List[String]()
    parts.append(INTROSPECTION_TYPES_JSON)
    var scalars = materialize[_SCALARS]()
    # The five specified scalars; apollo-compiler lists those in use.
    var index = 0
    while index < len(scalars):
        var found = _find_named(data, types, scalars[index])
        if found != NO_NODE:
            parts.append(stringify(data, found))
        index += 1
    index = 0
    while index < len(names[0]):
        parts.append(stringify(data, _find_named(data, types, names[0][index])))
        index += 1
    var directives = data.children(data.find(root, "directives"))
    var directive_parts: List[String] = [
        SKIP_JSON,
        INCLUDE_JSON,
        DEPRECATED_JSON,
    ]
    if not "specifiedBy" in names[1]:
        directive_parts.append(SPECIFIEDBY_JSON)
    else:
        directive_parts.append(
            stringify(data, _find_named(data, directives, "specifiedBy"))
        )
    for ref name in names[1]:
        if name == "specifiedBy":
            continue
        directive_parts.append(
            stringify(data, _find_named(data, directives, name))
        )
    var out = String('{"__schema":{')
    out += '"queryType":' + stringify(data, data.find(root, "queryType")) + ","
    out += (
        '"mutationType":'
        + stringify(data, data.find(root, "mutationType"))
        + ","
    )
    out += (
        '"subscriptionType":'
        + stringify(data, data.find(root, "subscriptionType"))
        + ","
    )
    out += '"types":[' + String(",").join(parts) + "],"
    out += '"directives":[' + String(",").join(directive_parts) + "]}}"
    return out^

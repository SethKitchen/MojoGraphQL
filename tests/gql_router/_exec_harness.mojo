# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The executor test kit.

`projection_plan_text` builds the projection plan of an operation and
prints it, as the `plan` helper of Hive Router `1a29df9`
`bin/router/src/executor/projection/plan/merge.rs`. `project` projects
response data, as the `project` helper of `projection/response.rs`.
"""

from gql_json.parser import parse as parse_json
from gql_json.value import NO_NODE, JsonDocument
from gql_router.exec_http import CannedTransport
from gql_router.pipeline import Router, RouterSchema
from gql_language.parser import parse
from gql_router.exec_projection import project_by_operation
from gql_router.exec_projection_plan import ProjectionPlan
from gql_router.exec_variables import CoerceVariablesPayload
from gql_router.graphql_error import GraphQLError
from gql_router.planner import Planner
from gql_router.schema_metadata import SchemaMetadata, schema_metadata


def run_router(
    sdl: String,
    var transport: CannedTransport,
    query: String,
    variables: String = "",
    is_get: Bool = False,
    prefer_ok: Bool = True,
    operation_name: Optional[String] = None,
) raises -> String:
    """Run one request through a router with canned subgraphs.

    Args:
        sdl: The supergraph SDL.
        transport: The canned subgraph responses.
        query: The operation.
        variables: The variables JSON object, or empty.
        is_get: Whether the request is a `GET`.
        prefer_ok: Whether the response type is `application/json`.
        operation_name: The operation to run.

    Returns:
        The status, a space, and the body.

    Raises:
        Error: When the supergraph does not load.
    """
    var router = Router(RouterSchema(sdl), transport^)
    var document = JsonDocument()
    var root = NO_NODE
    if variables.byte_length() > 0:
        document = parse_json(variables)
        root = document.root
    var response = router.execute(
        query, operation_name, document^, root, is_get, prefer_ok
    )
    return (
        String(response.status) + " " + String(unsafe_from_utf8=response.body)
    )


def metadata_of(sdl: String) raises -> SchemaMetadata:
    """Return the metadata of a supergraph.

    Args:
        sdl: The supergraph SDL.

    Returns:
        The metadata.

    Raises:
        Error: When the SDL does not parse.
    """
    return schema_metadata(parse(sdl))


def projection_plan_text(sdl: String, query: String) raises -> String:
    """Plan the projection of an operation and print it.

    Args:
        sdl: The supergraph SDL.
        query: The operation.

    Returns:
        The plan text, without the trailing newline.

    Raises:
        Error: When a step fails.
    """
    var planner = Planner(sdl)
    var operation = planner.normalize(query)
    var built = ProjectionPlan.from_operation(
        planner.store, operation, metadata_of(sdl)
    )
    return String(built[1].text().rstrip("\n"))


def variables_of(text: String) raises -> CoerceVariablesPayload:
    """Read a JSON object as coerced variables.

    Args:
        text: A JSON object, or empty for no variables.

    Returns:
        The variables.

    Raises:
        Error: When the JSON does not parse.
    """
    var payload = CoerceVariablesPayload()
    if text.byte_length() == 0:
        return payload^
    payload.document = parse_json(text)
    var child = payload.document.first(payload.document.root)
    while child != -1:
        payload.insert(payload.document.key(child), child)
        child = payload.document.next(child)
    return payload^


def project(
    sdl: String, query: String, data: String, variables: String = ""
) raises -> String:
    """Project response data by an operation.

    Args:
        sdl: The supergraph SDL.
        query: The operation.
        data: The response data, a JSON value.
        variables: The variables, a JSON object, or empty.

    Returns:
        The response text.

    Raises:
        Error: When a step fails.
    """
    var planner = Planner(sdl)
    var operation = planner.normalize(query)
    var metadata = metadata_of(sdl)
    var built = ProjectionPlan.from_operation(
        planner.store, operation, metadata
    )
    var document = parse_json(data)
    var out = project_by_operation(
        document,
        document.root,
        List[GraphQLError](),
        built[0],
        built[1],
        variables_of(variables),
        1024,
        metadata,
    )
    return String(unsafe_from_utf8=out)

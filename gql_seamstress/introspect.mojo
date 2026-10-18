# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""`seamstress subgraph introspect` and `seamstress graph introspect`.

Port of Rover `src/command/subgraph/introspect.rs`,
`src/command/graph/introspect.rs`, and of the runners and services of
`crates/rover-client/src/operations/subgraph/introspect` and
`graph/introspect`. A graph is introspected with the modern query first.
When the server refuses it, with an error that names `__InputValue`,
`includeDeprecated`, `isDeprecated` or `deprecationReason`, or with HTTP
422, the legacy query runs.

**Differences from upstream.** Rover 1.0.0 converts a legacy response
with `serde_json::to_value`, which writes the `__schema` key, and then
looks for `schema`. The conversion then fails for every legacy response,
with ``failed to convert legacy introspection response: missing field
`isDeprecated` ``. This port reads a legacy response as the conversion
intends: an argument or input field without `isDeprecated` is not
deprecated. `--watch` is not supported.
"""

from gql_http.client import Client
from gql_json.value import JsonDocument, JsonKind, NO_NODE
from gql_seamstress.config import Header
from gql_seamstress.encode import encode_schema
from gql_seamstress.graphql_client import GraphQLResponse, graphql_request
from gql_seamstress.introspection_json import sdl_to_introspection_json
from gql_seamstress.output import (
    CommandResult,
    OutputFormat,
    RoverError,
    json_string,
)
from gql_seamstress.queries import GRAPH_INTROSPECT_LEGACY_QUERY
from gql_seamstress.queries import GRAPH_INTROSPECT_LEGACY_QUERY_NAME
from gql_seamstress.queries import (
    GRAPH_INTROSPECT_QUERY,
    GRAPH_INTROSPECT_QUERY_NAME,
)
from gql_seamstress.queries import SUBGRAPH_INTROSPECT_QUERY
from gql_seamstress.queries import SUBGRAPH_INTROSPECT_QUERY_NAME

comptime USE_FEDERATED_GRAPH = (
    "Try running the command on a valid federated graph, or use the"
    " appropriate `seamstress graph` command instead of `seamstress subgraph`."
)
"""The text of Rover `RoverErrorSuggestion::UseFederatedGraph`."""


def introspection_error(message: String) -> RoverError:
    """Return Rover `RoverClientError::IntrospectionError`.

    Args:
        message: The message.

    Returns:
        The error, with the code `E011`.
    """
    var error = RoverError.of(message)
    error.code = "E011"
    return error^


@fieldwise_init
struct Fetched(Movable):
    """An SDL, or the error that stopped the request."""

    var sdl: String
    """The SDL; empty when there is an error."""
    var error: Optional[RoverError]
    """The error, or None."""


def fetch_subgraph_sdl(
    mut client: Client, url: StringSlice, headers: List[Header]
) -> Fetched:
    """Run the `_service { sdl }` query, as the upstream subgraph
    introspection service.

    Args:
        client: The HTTP client.
        url: The subgraph endpoint.
        headers: The extra header fields.

    Returns:
        The SDL, or the error.
    """
    var response = graphql_request(
        client,
        url,
        SUBGRAPH_INTROSPECT_QUERY,
        SUBGRAPH_INTROSPECT_QUERY_NAME,
        headers,
    )
    if response.error:
        var error = response.error.take()
        if error.causes[0].find("Cannot query field") >= 0:
            var refused = RoverError.of(
                "This endpoint doesn't support subgraph introspection via the"
                " Query._service field"
            )
            refused.code = "E007"
            refused.suggestions.append(USE_FEDERATED_GRAPH)
            return Fetched("", refused^)
        return Fetched("", error^)
    ref document = response.document
    var service = document.find(response.data, "_service")
    if service == NO_NODE or document.kind(service) != JsonKind.OBJECT:
        return Fetched(
            "", introspection_error("No introspection response available.")
        )
    var sdl = document.find(service, "sdl")
    if sdl == NO_NODE or document.kind(sdl) != JsonKind.STRING:
        return Fetched(
            "", introspection_error("No introspection response available.")
        )
    return Fetched(document.string_value(sdl), None)


def _falls_back(response: GraphQLResponse) -> Bool:
    """Return True when the server seems to predate the October 2021
    introspection fields, as upstream `should_fall_back_to_legacy`."""
    var markers: List[String] = [
        "__InputValue",
        "includeDeprecated",
        "isDeprecated",
        "deprecationReason",
    ]
    for ref message in response.messages:
        var index = 0
        while index < len(markers):
            if message.find(markers[index]) >= 0:
                return True
            index += 1
    var cause = response.error.value().causes[0]
    return response.status == 422 and cause.startswith("Deserialization error")


def fetch_graph_sdl(
    mut client: Client, url: StringSlice, headers: List[Header], legacy: Bool
) -> Fetched:
    """Introspect a graph and encode it as SDL, as upstream
    `graph::introspect::run`.

    Args:
        client: The HTTP client.
        url: The graph endpoint.
        headers: The extra header fields.
        legacy: Send only the legacy query, as
            `--legacy-introspection-query`.

    Returns:
        The SDL, or the error.
    """
    var response: GraphQLResponse
    if legacy:
        response = graphql_request(
            client,
            url,
            GRAPH_INTROSPECT_LEGACY_QUERY,
            GRAPH_INTROSPECT_LEGACY_QUERY_NAME,
            headers,
        )
    else:
        response = graphql_request(
            client,
            url,
            GRAPH_INTROSPECT_QUERY,
            GRAPH_INTROSPECT_QUERY_NAME,
            headers,
        )
        if response.error and _falls_back(response):
            response = graphql_request(
                client,
                url,
                GRAPH_INTROSPECT_LEGACY_QUERY,
                GRAPH_INTROSPECT_LEGACY_QUERY_NAME,
                headers,
            )
    if response.error:
        return Fetched("", response.error.take())
    try:
        return Fetched(encode_schema(response.document, response.data), None)
    except e:
        return Fetched("", introspection_error(String(e)))


def subgraph_introspect(
    url: StringSlice, headers: List[Header], format: OutputFormat
) -> CommandResult:
    """Run `seamstress subgraph introspect`.

    Args:
        url: The subgraph endpoint.
        headers: The `--header` fields.
        format: The `--format`.

    Returns:
        The SDL that the subgraph reports, or the error.
    """
    var client = Client()
    var fetched = fetch_subgraph_sdl(client, url, headers)
    if fetched.error:
        return CommandResult.failure(fetched.error.take())
    var members = '"introspection_response":' + json_string(fetched.sdl)
    return CommandResult(
        None, fetched.sdl, members, "Introspection Response", ""
    )


def graph_introspect(
    url: StringSlice, headers: List[Header], legacy: Bool, format: OutputFormat
) -> CommandResult:
    """Run `seamstress graph introspect`.

    With `--format json`, the SDL is introspected again, and the result is
    the `{"__schema": ...}` object, as upstream `sdl_to_introspection_json`.

    Args:
        url: The graph endpoint.
        headers: The `--header` fields.
        legacy: The `--legacy-introspection-query` flag.
        format: The `--format`.

    Returns:
        The SDL of the graph, or the error.
    """
    var client = Client()
    var fetched = fetch_graph_sdl(client, url, headers, legacy)
    if fetched.error:
        return CommandResult.failure(fetched.error.take())
    if format == OutputFormat.JSON:
        try:
            var json = sdl_to_introspection_json(fetched.sdl)
            return CommandResult(
                None,
                "",
                '"introspection_response":' + json,
                "Introspection Response",
                "",
            )
        except e:
            return CommandResult.failure(introspection_error(String(e)))
    return CommandResult(None, fetched.sdl, "", "Introspection Response", "")

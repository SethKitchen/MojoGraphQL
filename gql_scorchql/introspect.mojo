# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Read the SDL of a running subgraph.

`fetch_subgraph_sdl` sends `{ _service { sdl } }` to a subgraph, as the
Apollo Federation subgraph specification defines, and returns the SDL.
`read_service_sdl` reads the response body, so that a test can call it
without a socket.

Differences from upstream: none; there is no upstream.
"""

from gql_http.client import Client
from gql_json.parser import parse_bytes
from gql_json.value import JsonKind

comptime SERVICE_QUERY = (
    '{"query":"query SubgraphIntrospectQuery { _service { sdl } }"}'
)
"""The request body of the subgraph SDL query."""


def read_service_sdl(status: Int, var body: List[UInt8]) raises -> String:
    """Read the SDL from the response to the `_service { sdl }` query.

    Args:
        status: The HTTP status code of the response.
        body: The response body.

    Returns:
        The value of `data._service.sdl`.

    Raises:
        Error: For a status that is not 2xx, a body that is not JSON, a
            GraphQL error, or a response without the SDL.
    """
    if status < 200 or status > 299:
        raise Error("the subgraph answered HTTP " + String(status))
    var document = parse_bytes(body^)
    var root = document.root
    if document.kind(root) != JsonKind.OBJECT:
        raise Error("the subgraph response is not a JSON object")
    var errors = document.find(root, "errors")
    if errors >= 0 and document.kind(errors) == JsonKind.ARRAY:
        var first = document.first(errors)
        if first >= 0 and document.kind(first) == JsonKind.OBJECT:
            var message = document.find(first, "message")
            if message >= 0 and document.kind(message) == JsonKind.STRING:
                raise Error(
                    "the subgraph answered: " + document.string_value(message)
                )
    var node = document.find(root, "data")
    for key in ["_service", "sdl"]:
        if node < 0 or document.kind(node) != JsonKind.OBJECT:
            node = -1
            break
        node = document.find(node, key)
    if node < 0 or document.kind(node) != JsonKind.STRING:
        raise Error(
            "the subgraph response has no data._service.sdl; is it a"
            " federation subgraph?"
        )
    return document.string_value(node)


def fetch_subgraph_sdl(mut client: Client, url: StringSlice) raises -> String:
    """Send the `_service { sdl }` query to a subgraph.

    Args:
        client: The HTTP client.
        url: The routing URL of the subgraph.

    Returns:
        The subgraph SDL.

    Raises:
        Error: When the request fails, or as `read_service_sdl` raises.
    """
    var response = client.post(url, "application/json", SERVICE_QUERY)
    return read_service_sdl(
        Int(response.status.code), List[UInt8](response.body())
    )

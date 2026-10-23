# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Send a GraphQL operation to the endpoint, and make the tool result.

Port of Apollo MCP Server 2.0.0 (04e4e6e)
`crates/apollo-mcp-server/src/graphql.rs`, `Executable::execute`. The
request is a `POST` with the JSON body `{"variables", "query",
"extensions": {"clientLibrary": {"name": "mcp", "version": "2.0.0"}},
"operationName"}`, in that order, and `operationName` only when the
operation has a name. The response is any JSON document, whatever its HTTP
status. It is an error result when it has an `errors` member that is not
`null`.

The result text is the response as `serde_json` writes it again: compact,
members in their order, a repeated key in the place of its first
occurrence with its last value, and a number that is not an `i64` or a
`u64` in the `ryu` layout (`1e5` is `100000.0`).

Differences from upstream:

- The texts of transport errors are the reqwest texts that the upstream
  shows for a failed exchange, but `gql_http` and reqwest fail in different
  cases. The text is always `error sending request for url (<url>)`.
- No telemetry, no `@private` filtering (phase 2), and no Rhai hooks.
- The client has no TLS, so the endpoint must be `http`.
"""

from std.math import isinf

from gql_http.client import Client
from gql_http.headers import Headers
from gql_http.status import Method
from gql_json.number import read_float64
from gql_json.parser import parse
from gql_json.value import JsonDocument, JsonKind, NO_NODE
from gql_json.writer import write_string
from gql_mcp.call_result import CallToolResult
from gql_mcp.json_tree import JsonTree
from gql_mcp.jsonrpc import is_integer_id
from gql_mcp.schema_walker import ryu_text

comptime CLIENT_NAME = "mcp"
"""The `clientLibrary.name` of each request."""
comptime CLIENT_VERSION = "2.0.0"
"""The `clientLibrary.version` of each request: the upstream version."""


def request_body(
    query: StringSlice,
    operation_name: Optional[String],
    variables: StringSlice,
) -> String:
    """Return the JSON body of a GraphQL request.

    Args:
        query: The operation text.
        operation_name: The operation name, when the operation has one.
        variables: The JSON text of the variables, such as `null`.

    Returns:
        The JSON text.
    """
    var out = List[UInt8](capacity=query.byte_length() + 160)
    out.extend('{"variables":'.as_bytes())
    out.extend(variables.as_bytes())
    out.extend(',"query":'.as_bytes())
    write_string(out, query.as_bytes())
    out.extend(',"extensions":{"clientLibrary":{"name":"'.as_bytes())
    out.extend(CLIENT_NAME.as_bytes())
    out.extend('","version":"'.as_bytes())
    out.extend(CLIENT_VERSION.as_bytes())
    out.extend('"}}'.as_bytes())
    if operation_name:
        out.extend(',"operationName":'.as_bytes())
        write_string(out, operation_name.value().as_bytes())
    out.append(UInt8(ord("}")))
    return String(unsafe_from_utf8=out)


def serde_number(text: StringSlice) raises -> String:
    """Return a JSON number as `serde_json` writes it after it reads it.

    Args:
        text: Valid JSON number text.

    Returns:
        The text of an `i64` or a `u64` without change (but `-0` is `0`), or
        the `ryu` text of the nearest `f64`.

    Raises:
        Error: When the number is too large for an `f64`, as `serde_json`
            refuses it.
    """
    if is_integer_id(text):
        if text == "-0":
            return String("0")
        return String(text)
    var value = read_float64(text.as_bytes())
    if isinf(value):
        raise Error("number out of range")
    return ryu_text(value)


def normalized_json(document: JsonDocument, node: Int) raises -> JsonTree:
    """Copy a JSON value as `serde_json` reads it into a `Value`: a repeated
    key keeps its first place and its last value, and each number is in
    the text of `serde_number`.

    Args:
        document: The document.
        node: The value.

    Returns:
        The tree; its root is the copy.

    Raises:
        Error: For a number too large for an `f64`.
    """
    var tree = JsonTree()
    tree.root = tree.add_document(document, node)
    var index = 0
    while index < len(tree.nodes):
        if tree.nodes[index].kind == JsonKind.NUMBER:
            tree.nodes[index].text = serde_number(tree.nodes[index].text)
        index += 1
    return tree^


def _read_json(body: Span[UInt8, _]) raises -> JsonTree:
    """Parse and normalize response content."""
    var document = parse(StringSlice(unsafe_from_utf8=body))
    return normalized_json(document, document.root)


def read_response(body: Span[UInt8, _]) -> CallToolResult:
    """Make the tool result of a GraphQL response body.

    Args:
        body: The response content.

    Returns:
        A structured result, which is an error when the response has
        `errors` that are not `null`; or the error text
        `Failed to read GraphQL response body: error decoding response body`
        when the content is not JSON.
    """
    var tree: JsonTree
    try:
        tree = _read_json(body)
    except:
        return CallToolResult.error(
            "Failed to read GraphQL response body: error decoding response body"
        )
    var is_error = False
    if tree.kind(tree.root) == JsonKind.OBJECT:
        var errors = tree.find(tree.root, "errors")
        is_error = errors != NO_NODE and tree.kind(errors) != JsonKind.NULL
    return CallToolResult.structured(tree.to_string(tree.root), is_error)


def execute_request(
    mut client: Client,
    url: StringSlice,
    headers: Headers,
    body: StringSlice,
) -> CallToolResult:
    """Post a GraphQL request body to the endpoint, and make the result.

    Args:
        client: The HTTP client; it keeps its connections for the next
            request.
        url: The endpoint URL.
        headers: The header fields of the request.
        body: The JSON body, from `request_body`.

    Returns:
        The result of `read_response`, or the error text
        `Failed to send GraphQL request: error sending request for url
        (<url>)` when the exchange fails.
    """
    try:
        var endpoint = client.endpoint(url)
        var target = endpoint.target.copy()
        var response = client.send(
            endpoint, Method.POST, target, headers, body.as_bytes()
        )
        return read_response(response.body())
    except:
        return CallToolResult.error(
            "Failed to send GraphQL request: error sending request for url ("
            + String(url)
            + ")"
        )

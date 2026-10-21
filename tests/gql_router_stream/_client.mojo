# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The clients of the end-to-end suites: HTTP streams and
`graphql-transport-ws`."""

from gql_http.client import Client
from gql_http.headers import Headers
from gql_http.status import Method
from gql_json.writer import write_string
from gql_ws.transport_client import ClientEvent, TransportClient
from gql_ws.graphql_ws import MessageType


@fieldwise_init
struct Answer(Movable):
    """A whole response."""

    var status: Int
    var content_type: String
    var body: String


def graphql_body(query: String, variables: String = "") -> List[UInt8]:
    """Write a GraphQL request body."""
    var out = List[UInt8]()
    out.extend('{"query":'.as_bytes())
    write_string(out, query.as_bytes())
    if variables.byte_length() > 0:
        out.extend(',"variables":'.as_bytes())
        out.extend(variables.as_bytes())
    out.append(UInt8(ord("}")))
    return out^


def post(
    port: Int,
    query: String,
    accept: String,
    variables: String = "",
    limit: Int = -1,
) raises -> Answer:
    """POST a request to the router and read the whole streamed body, or
    `limit` bytes of it."""
    var client = Client()
    client.config.timeout_ms = 4000
    var endpoint = client.endpoint(
        "http://127.0.0.1:" + String(port) + "/graphql"
    )
    var headers = Headers()
    headers.add("content-type", "application/json")
    if accept.byte_length() > 0:
        headers.add("accept", accept)
    var body = graphql_body(query, variables)
    var target = endpoint.target
    var pending = client.start(
        endpoint, Method.POST, target, headers, Span(body)
    )
    var stream = client.stream(pending^)
    var status = stream.response.status.code
    var content_type = String()
    var found = stream.response.header("content-type")
    if found:
        content_type = String(found.value())
    var out = List[UInt8]()
    while limit < 0 or len(out) < limit:
        if not client.read_body(stream, out):
            break
    client.close_stream(stream)
    return Answer(status, content_type^, String(unsafe_from_utf8=Span(out)))


def ws_url(port: Int) -> String:
    """The WebSocket URL of the router."""
    return "ws://127.0.0.1:" + String(port) + "/graphql"


def ws_results(
    mut client: TransportClient, id: String, count: Int = -1
) raises -> List[String]:
    """Read the `next` payloads of an operation until it completes, or
    until `count` payloads."""
    var out = List[String]()
    var event = ClientEvent()
    while count < 0 or len(out) < count:
        if not client.next(event, 4000):
            raise Error("no message in time")
        if event.id != id:
            continue
        if event.type == MessageType.NEXT:
            out.append(event.payload)
        elif event.type == MessageType.ERROR:
            out.append("error:" + event.payload)
            break
        else:
            break
    return out^


def sse_of(payloads: List[String]) -> String:
    """The SSE body of some results and `complete`."""
    var out = String()
    for payload in payloads:
        out += "event: next\ndata: " + payload + "\n\n"
    return out + "event: complete\n\n"


def names_of_reviews(names: List[String]) -> List[String]:
    """The results of `{ reviewAdded { id product { name } } }`."""
    var out = List[String]()
    for index in range(len(names)):
        out.append(
            '{"data":{"reviewAdded":{"id":"'
            + String(index + 1)
            + '","product":{"name":"'
            + names[index]
            + '"}}}}'
        )
    return out^


def names() -> List[String]:
    """The product name of each review."""
    return [
        "Table",
        "Table",
        "Table",
        "Table",
        "Couch",
        "Couch",
        "Couch",
        "Couch",
        "Glass",
        "Chair",
        "Chair",
    ]

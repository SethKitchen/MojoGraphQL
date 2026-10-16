# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The requests, the responses and the request context of the server.

Port of Apollo Server 5.5.1 `externalTypes/graphql.ts` (`GraphQLRequest`,
`GraphQLResponse`, `GraphQLRequestMetrics`, `GraphQLRequestContext`) and
`orderExecutionResultFields` and `prettyJSONStringify` of
`runHttpQuery.ts`.

**Differences from upstream.**
- The variables and the extensions of a request are nodes of
  `GraphQLRequest.json`, a `JsonDocument`.
- The context value is a value of the `Values` arena of the request
  context, as `gql_execution` resolvers read it.
- The request context has no `logger`, `cache` or `schema`; a plugin
  holds what it needs.
- A response has one result. Incremental delivery is not ported.
"""

from std.memory import ArcPointer

from gql_execution.value import UNDEFINED, Values
from gql_json.parser import parse as parse_json
from gql_json.value import NO_NODE as NO_JSON
from gql_json.value import JsonDocument
from gql_json.writer import stringify
from gql_language.ast import NO_NODE, Document
from gql_server.cache_policy import CachePolicy
from gql_server.error_normalize import FormattedError
from gql_server.errors import ServerError
from gql_server.http_types import HTTPGraphQLHead, HTTPGraphQLRequest


struct GraphQLRequest(Copyable, Movable):
    """A GraphQL request: upstream `GraphQLRequest`."""

    var query: Optional[String]
    """The operation text."""
    var operation_name: Optional[String]
    """The name of the operation to run."""
    var json: JsonDocument
    """The document that holds `variables` and `extensions`."""
    var variables: Int
    """The variable values, an object node of `json`, or `NO_JSON`."""
    var extensions: Int
    """The extensions, an object node of `json`, or `NO_JSON`."""
    var http: Optional[HTTPGraphQLRequest]
    """The HTTP request, without its content, or None in process."""

    def __init__(out self, query: Optional[String] = None):
        """Make a request.

        Args:
            query: The operation text.
        """
        self.query = query
        self.operation_name = None
        self.json = JsonDocument()
        self.variables = NO_JSON
        self.extensions = NO_JSON
        self.http = None

    def set_variables(mut self, text: StringSlice) raises:
        """Set the variable values from JSON text.

        Args:
            text: A JSON value; upstream takes an object.

        Raises:
            JsonError: When the text is not JSON.
        """
        var parsed = parse_json(text)
        self.variables = self.json.add_copy(parsed, parsed.root)

    def set_extensions(mut self, text: StringSlice) raises:
        """Set the extensions from JSON text.

        Args:
            text: A JSON value; upstream takes an object.

        Raises:
            JsonError: When the text is not JSON.
        """
        var parsed = parse_json(text)
        self.extensions = self.json.add_copy(parsed, parsed.root)


def pretty_json_stringify(var text: String) -> String:
    """Add the newline of upstream `prettyJSONStringify` to JSON text.

    Args:
        text: The JSON text of a result.

    Returns:
        The text and `\\n`.
    """
    text += "\n"
    return text^


struct GraphQLResponse(Copyable, Movable):
    """A GraphQL response: upstream `GraphQLResponse` with a `single`
    body."""

    var http: HTTPGraphQLHead
    """The status and the fields of the HTTP response."""
    var data: JsonDocument
    """The data; no root when the result has no `data` key."""
    var errors: List[FormattedError]
    """The errors."""
    var has_errors: Bool
    """Whether the result has an `errors` key."""
    var extensions: Optional[String]
    """The JSON text of the `extensions` of the result, if any."""

    def __init__(out self, var http: HTTPGraphQLHead = HTTPGraphQLHead()):
        """Make a response with no result.

        Args:
            http: The status and the fields.
        """
        self.http = http^
        self.data = JsonDocument()
        self.errors = List[FormattedError]()
        self.has_errors = False
        self.extensions = None

    def has_data(self) -> Bool:
        """Return True if the result has a `data` key.

        Returns:
            Whether `data` has a root.
        """
        return self.data.root != NO_JSON

    def to_json(self) -> String:
        """Return the result as JSON, with `errors` first, as upstream
        `orderExecutionResultFields` and `JSON.stringify` write it.

        Returns:
            Such as `{"errors":[...],"data":{...}}`.
        """
        var out = String("{")
        if self.has_errors:
            out += '"errors":['
            var index = 0
            while index < len(self.errors):
                if index > 0:
                    out += ","
                out += self.errors[index].to_json()
                index += 1
            out += "]"
        if self.has_data():
            out += "," if self.has_errors else ""
            out += '"data":' + stringify(self.data, self.data.root)
        if self.extensions:
            out += "," if out.byte_length() > 1 else ""
            out += '"extensions":' + self.extensions.value()
        return out + "}"


@fieldwise_init
struct GraphQLRequestMetrics(Copyable, ImplicitlyCopyable, Movable):
    """What the pipeline found out about a request: the persisted query
    parts of upstream `GraphQLRequestMetrics`."""

    var persisted_query_hit: Bool
    """Whether the query text came from the persisted query cache."""
    var persisted_query_register: Bool
    """Whether the request stores its query in the cache."""


struct GraphQLRequestContext(Movable):
    """The state of one request in the pipeline: upstream
    `GraphQLRequestContext`. Each plugin hook gets it."""

    var request: GraphQLRequest
    """The request."""
    var response: GraphQLResponse
    """The response that the pipeline builds."""
    var values: Values
    """The arena of the context value and of every value of execution."""
    var context_value: Int
    """The context value: a value of `values`."""
    var query_hash: String
    """The SHA-256 of the query, in hexadecimal; empty at first."""
    var source: Optional[String]
    """The query text, once the pipeline has it."""
    var document: Optional[ArcPointer[Document]]
    """The parsed document, once the pipeline has it."""
    var operation: Int
    """The `OperationDefinition` node to run, or `NO_NODE`."""
    var operation_name: Optional[String]
    """The name of that operation."""
    var errors: List[ServerError]
    """The errors that `did_encounter_errors` gets."""
    var metrics: GraphQLRequestMetrics
    """The metrics."""
    var overall_cache_policy: CachePolicy
    """The cache policy of the response."""
    var request_is_batched: Bool
    """Whether the request is one of a batch."""

    def __init__(
        out self,
        var request: GraphQLRequest,
        var http: HTTPGraphQLHead,
        var values: Values,
        context_value: Int,
        request_is_batched: Bool,
    ):
        """Start the state of a request.

        Args:
            request: The request.
            http: The head that the response starts with.
            values: The arena of the context value.
            context_value: The context value.
            request_is_batched: Whether the request is one of a batch.
        """
        self.request = request^
        self.response = GraphQLResponse(http^)
        self.values = values^
        self.context_value = context_value
        self.query_hash = String("")
        self.source = None
        self.document = None
        self.operation = NO_NODE
        self.operation_name = None
        self.errors = List[ServerError]()
        self.metrics = GraphQLRequestMetrics(False, False)
        self.overall_cache_policy = CachePolicy()
        self.request_is_batched = request_is_batched

    def take_response(deinit self) -> GraphQLResponse:
        """End the request and return its response.

        Returns:
            The response.
        """
        return self.response^

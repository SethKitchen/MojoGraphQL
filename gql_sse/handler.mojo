# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The request parameters, the executor interface, and the JSON answers of
a GraphQL over SSE server.

Ports graphql-sse 2.6.3 `src/handler.ts`: `parseReq`, the `RequestParams`
checks, and the error bodies. `SseExecutor` stands for the `prepare` and
`perform` steps, so the server does not depend on an execution engine.

Differences from upstream: the `onSubscribe`, `onOperation`, `onNext` and
`onComplete` hooks are one `SseExecutor.prepare`. A JSON body that is not
valid JSON gets the message of `gql_json`, not of `JSON.parse`.
"""

from gql_http.parser import Request
from gql_http.status import Method, Status
from gql_http.url import QueryParam, parse_query, query_value
from gql_json.parser import parse
from gql_json.value import NO_NODE, JsonDocument, JsonKind
from gql_json.writer import write_string
from gql_stream.stream import AnyStream


comptime TOKEN_HEADER_KEY = "x-graphql-event-stream-token"
"""The header of the token of a reserved stream."""
comptime TOKEN_QUERY_KEY = "token"
"""The query parameter of the token of a reserved stream."""
comptime JSON_TYPE = "application/json; charset=utf-8"
"""The `content-type` of the JSON answers."""
comptime EVENT_STREAM_TYPE = "text/event-stream; charset=utf-8"
"""The `content-type` of an event stream."""


def error_json(message: StringSlice) -> String:
    """Return `{"errors":[{"message":<message>}]}`.

    Args:
        message: The message.

    Returns:
        The JSON text.
    """
    var out = List[UInt8]()
    out.extend(StaticString('{"errors":[{"message":').as_bytes())
    write_string(out, message.as_bytes())
    out.extend(StaticString("}]}").as_bytes())
    return String(unsafe_from_utf8=out)


struct RequestParams(Movable):
    """The GraphQL parameters of a request, from its URL or its body."""

    var document: JsonDocument
    """The JSON value that holds the parameters."""
    var root: Int
    """The object of the parameters in `document`."""
    var query: String
    """The query."""
    var operation_name: Optional[String]
    """The operation name, if any."""
    var variables: Int
    """The object of the variables in `document`, or `NO_NODE`."""
    var extensions: Int
    """The object of the extensions in `document`, or `NO_NODE`."""

    def __init__(out self, var document: JsonDocument, root: Int) raises:
        """Check the parameters of an object (`parseReq`).

        Args:
            document: The JSON value.
            root: The object of the parameters.

        Raises:
            Error: `Missing query`, `Invalid query`, `Invalid variables` and
                `Invalid extensions`.
        """
        self.document = document^
        self.root = root
        var query = self.document.find(root, "query")
        if query == NO_NODE or self.document.kind(query) == JsonKind.NULL:
            raise Error("Missing query")
        if self.document.kind(query) != JsonKind.STRING:
            raise Error("Invalid query")
        self.query = self.document.string_value(query)
        self.operation_name = None
        var name = self.document.find(root, "operationName")
        if name != NO_NODE and self.document.kind(name) == JsonKind.STRING:
            self.operation_name = self.document.string_value(name)
        self.variables = _object_or_none(
            self.document, root, "variables", "Invalid variables"
        )
        self.extensions = _object_or_none(
            self.document, root, "extensions", "Invalid extensions"
        )

    def operation_id(self) -> String:
        """Return `extensions.operationId` as text; empty when it is none.

        Returns:
            The operation id.
        """
        if self.extensions == NO_NODE:
            return String()
        var node = self.document.find(self.extensions, "operationId")
        if node == NO_NODE:
            return String()
        var kind = self.document.kind(node)
        if kind == JsonKind.STRING:
            return self.document.string_value(node)
        if kind == JsonKind.NUMBER:
            return String(self.document.text(node))
        return String()


def _object_or_none(
    document: JsonDocument, root: Int, key: StaticString, message: StaticString
) raises -> Int:
    """Return the object of a member, `NO_NODE` for none or null."""
    var node = document.find(root, key)
    if node == NO_NODE or document.kind(node) == JsonKind.NULL:
        return NO_NODE
    if document.kind(node) != JsonKind.OBJECT:
        raise Error(message)
    return node


struct ParseOutcome(Movable):
    """The parameters of a request, or the answer that refuses it."""

    var params: Optional[RequestParams]
    """The parameters, when the request has valid ones."""
    var status: Status
    """The status of the refusal: 400 or 415."""
    var json: String
    """The JSON body of the refusal; empty for none."""

    def __init__(
        out self,
        var params: Optional[RequestParams],
        status: Status,
        json: String,
    ):
        """Make an outcome.

        Args:
            params: The parameters, if any.
            status: The status of a refusal.
            json: The body of a refusal.
        """
        self.params = params^
        self.status = status
        self.json = json


def parse_request(request: Request) -> ParseOutcome:
    """Read the GraphQL parameters of a GET or a JSON POST (`parseReq`).

    Args:
        request: The request.

    Returns:
        The parameters, or a 400 with the error, or a 415 with no body.
    """
    try:
        if request.method == Method.GET:
            return ParseOutcome(_from_url(request), Status.OK, String())
        var content_type = request.header("content-type")
        if (
            request.method != Method.POST
            or not content_type
            or (content_type.value().find("application/json") < 0)
        ):
            return ParseOutcome(None, Status.UNSUPPORTED_MEDIA_TYPE, String())
        if len(request.body()) == 0:
            raise Error("Missing body")
        var document = parse(StringSlice(unsafe_from_utf8=request.body()))
        if document.kind(0) != JsonKind.OBJECT:
            raise Error("JSON body must be an object")
        return ParseOutcome(RequestParams(document^, 0), Status.OK, String())
    except e:
        return ParseOutcome(None, Status.BAD_REQUEST, error_json(String(e)))


def _from_url(request: Request) raises -> RequestParams:
    """Read the parameters of a GET from its query string."""
    var document = JsonDocument()
    var root: Int
    var pairs: List[QueryParam]
    try:
        pairs = parse_query(request.query())
    except:
        raise Error("Unparsable URL")
    try:
        root = document.add_object()
        var name = query_value(pairs, "operationName")
        if name:
            document.add_member(
                root, "operationName", document.add_string(name.value())
            )
        var query = query_value(pairs, "query")
        if query:
            document.add_member(
                root, "query", document.add_string(query.value())
            )
        _add_json(document, root, pairs, "variables")
        _add_json(document, root, pairs, "extensions")
    except:
        raise Error("Unparsable URL")
    return RequestParams(document^, root)


def _add_json(
    mut document: JsonDocument,
    root: Int,
    pairs: List[QueryParam],
    key: StaticString,
) raises:
    """Parse a JSON parameter of a query string into the document."""
    var text = query_value(pairs, key)
    if not text or text.value().byte_length() == 0:
        return
    var value = parse(text.value())
    document.add_member(root, key, document.add_copy(value, 0))


struct PreparedKind(Equatable, ImplicitlyCopyable, Writable):
    """What `SseExecutor.prepare` made of an operation."""

    var value: UInt8
    """The index of the kind; see `is_valid`."""

    comptime RESPONSE = PreparedKind(0)
    """An answer that refuses the operation, such as a syntax error."""
    comptime RESULT = PreparedKind(1)
    """One result: a `next` event, then `complete`."""
    comptime STREAM = PreparedKind(2)
    """A stream of results, each one a `next` event."""

    @implicit
    def __init__(out self, value: Int):
        """Make a kind from its index.

        Args:
            value: The index.
        """
        self.value = UInt8(value)

    def is_valid(self) -> Bool:
        """Return True for one of the three kinds.

        Returns:
            Whether the index is in range.
        """
        return self.value <= 2

    def write_to(self, mut writer: Some[Writer]):
        """Write the index of the kind.

        Args:
            writer: The destination.
        """
        writer.write("PreparedKind(", self.value, ")")


struct Prepared(Movable):
    """An operation that is ready to stream, or the answer that refuses it."""

    var kind: PreparedKind
    """What it is."""
    var status: Status
    """The status of a `RESPONSE`."""
    var json: String
    """The body of a `RESPONSE`, or the result of a `RESULT`."""
    var allow: String
    """The `allow` field of a `RESPONSE`; empty for none."""
    var stream: Optional[AnyStream]
    """The results of a `STREAM`."""

    def __init__(
        out self,
        kind: PreparedKind,
        status: Status,
        json: String,
        allow: String,
        var stream: Optional[AnyStream],
    ):
        """Make a prepared operation; the static methods are shorter.

        Args:
            kind: What it is.
            status: The status of a `RESPONSE`.
            json: The body or the result.
            allow: The `allow` field of a `RESPONSE`.
            stream: The results of a `STREAM`.
        """
        self.kind = kind
        self.status = status
        self.json = json
        self.allow = allow
        self.stream = stream^

    @staticmethod
    def response(status: Status, json: String, allow: String = "") -> Prepared:
        """Refuse the operation with an answer.

        Args:
            status: The status, such as 400.
            json: The JSON body, such as `error_json(message)`.
            allow: The `allow` field; empty for none.

        Returns:
            A `RESPONSE`.
        """
        return Prepared(PreparedKind.RESPONSE, status, json, allow, None)

    @staticmethod
    def result(json: String) -> Prepared:
        """Stream one result.

        Args:
            json: The result as JSON text.

        Returns:
            A `RESULT`.
        """
        return Prepared(PreparedKind.RESULT, Status.OK, json, "", None)

    @staticmethod
    def of_stream(var stream: AnyStream) -> Prepared:
        """Stream the results of a stream.

        Args:
            stream: The results; each event is one result.

        Returns:
            A `STREAM`.
        """
        return Prepared(PreparedKind.STREAM, Status.OK, "", "", stream^)


trait SseExecutor(Deinitable, Movable):
    """The GraphQL side of an SSE server: `prepare` and `perform`."""

    def prepare(
        mut self, request: Request, params: RequestParams, event_stream: Bool
    ) raises -> Prepared:
        """Parse, validate and start one operation.

        Upstream answers 400 for a syntax error, 400 for no operation,
        405 with `allow: POST` for a mutation over GET, and 400 for
        validation errors. When `event_stream` is True, validation errors
        are a `RESULT` instead, so the stream reports them.

        Args:
            request: The request of the operation.
            params: Its parameters.
            event_stream: Whether the request accepts `text/event-stream`.

        Returns:
            The answer, the result, or the stream of results.

        Raises:
            Error: Any error; the client gets a 500.
        """
        ...

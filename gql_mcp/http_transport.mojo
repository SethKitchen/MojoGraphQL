# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The Streamable HTTP transport, on the `gql_http` server, at `/mcp`.

The MCP specification (2025-06-18, "Transports") defines the transport.
The status codes, the texts and the event framing are those of the
Apollo MCP Server 2.0.0 binary, whose transport is the SDK's (`rmcp`,
Apache-2.0 only); this module ports no code.

A `POST` carries one JSON-RPC message. Its `Accept` must name both
`application/json` and `text/event-stream` (406), its `Content-Type` must
start with `application/json` (415), and its content must be one message
(415, `fail to deserialize request body ...`). A notification or a response
gets 202. A request gets 200 and a `text/event-stream` with its reply.

In stateful mode (the default) an `initialize` without `Mcp-Session-Id`
starts a session: the reply has the new id in `mcp-session-id`, and its
stream is `data: \\nid: 0\\nretry: 3000\\n\\n` (the priming event) and
`data: <reply>\\n\\n`. Each later request of the session gets the stream
`data: \\nid: 0/<n>\\nretry: 3000\\n\\n` and `data: <reply>\\nid: 1/<n>\\n\\n`,
where `<n>` counts the session's requests from 0. Another request without a
session gets 422, an unknown session 404. `DELETE` ends a session (202);
without an id it gets 400. `GET` opens the server's stream of a session.
Other methods get 405.

In stateless mode each request stands alone: no session, no priming
event, and the stream is `data: <reply>\\n\\n`. The protocol version is the
`MCP-Protocol-Version` field, or 2025-03-26 without one. Only `POST` is
allowed.

Differences from upstream:

- A stream has `Content-Length` and ends after the reply; the upstream
  uses chunked coding. A `GET` stream sends its priming event and ends,
  because the server sends no notifications in phase 1.
- The text after `fail to deserialize request body ` is a `gql_json`
  message, not a `serde_json` one.
- No CORS, no host validation, no authentication and no health check
  (phase 2); the sessionless protocol 2026-07-28 is not ported.
"""

from std.collections import Dict
from std.random import random_ui64

from gql_http.error import HttpError
from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter, Server, ServerConfig
from gql_http.server import listen
from gql_http.status import Method, Status
from gql_mcp.jsonrpc import Message, MessageKind, parse_message
from gql_mcp.server import McpServer, Session

comptime MCP_PATH: StaticString = "/mcp"
"""The path of the endpoint."""
comptime SESSION_HEADER: StaticString = "mcp-session-id"
"""The field that names a session."""
comptime DEFAULT_PROTOCOL_VERSION: StaticString = "2025-03-26"
"""The version of a stateless request without `MCP-Protocol-Version`."""
comptime _DESERIALIZE = "fail to deserialize request body "
"""The start of the 415 text of content that is not one message."""


struct HttpSession(Copyable, Movable):
    """One client of the stateful mode."""

    var session: Session
    """The MCP session."""
    var requests: Int
    """How many requests the session has had, after `initialize`."""

    def __init__(out self):
        """Start a session."""
        self.session = Session()
        self.requests = 0


def new_session_id() -> String:
    """Return a random UUID version 4, as the upstream session ids.

    Returns:
        Such as `3d86c4a4-f461-4a62-8dff-89bfb35aea0f`.
    """
    var high = random_ui64(0, UInt64.MAX)
    var low = random_ui64(0, UInt64.MAX)
    high = (high & ~UInt64(0xF000)) | UInt64(0x4000)
    low = (low & ~(UInt64(0xC) << 60)) | (UInt64(0x8) << 60)
    var hex = _hex(high) + _hex(low)
    return (
        String(hex[byte=0:8])
        + "-"
        + String(hex[byte=8:12])
        + "-"
        + String(hex[byte=12:16])
        + "-"
        + String(hex[byte=16:20])
        + "-"
        + String(hex[byte=20:32])
    )


def _hex(value: UInt64) -> String:
    """Write 16 lowercase hexadecimal digits."""
    var digits = "0123456789abcdef".as_bytes()
    var out = List[UInt8](capacity=16)
    var shift = 60
    while shift >= 0:
        out.append(digits[Int((value >> UInt64(shift)) & 15)])
        shift -= 4
    return String(unsafe_from_utf8=out)


struct McpHttpHandler(Handler):
    """Serves an `McpServer` over Streamable HTTP."""

    var server: McpServer
    """The MCP server."""
    var stateful: Bool
    """Whether clients have sessions, as upstream `stateful_mode`."""
    var sessions: Dict[String, HttpSession]
    """The open sessions, by id."""

    def __init__(out self, var server: McpServer, stateful: Bool = True):
        """Make a handler.

        Args:
            server: The MCP server.
            stateful: Whether clients have sessions.
        """
        self.server = server^
        self.stateful = stateful
        self.sessions = Dict[String, HttpSession]()

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        """Answer one HTTP request.

        Args:
            request: The request.
            response: The response to fill.

        Raises:
            Error: When the response cannot be written.
        """
        if request.path() != MCP_PATH:
            response.set_status(Status.NOT_FOUND)
            return
        if request.method == Method.POST:
            self._post(request, response)
            return
        if self.stateful and request.method == Method.GET:
            self._get(request, response)
            return
        if self.stateful and request.method == Method.DELETE:
            self._delete(request, response)
            return
        response.add_header(
            "allow", "GET, POST, DELETE" if self.stateful else "POST"
        )
        _text(response, Status.METHOD_NOT_ALLOWED, "Method Not Allowed")

    def _get(mut self, request: Request, mut response: ResponseWriter) raises:
        """Open the server's stream of a session."""
        var accept = request.header("accept")
        if not accept or "text/event-stream" not in accept.value():
            _text(
                response,
                Status.NOT_ACCEPTABLE,
                "Not Acceptable: Client must accept text/event-stream",
            )
            return
        var id = request.header(SESSION_HEADER)
        if not id:
            _text(
                response,
                Status.BAD_REQUEST,
                "Bad Request: Session ID is required",
            )
            return
        if String(id.value()) not in self.sessions:
            _text(response, Status.NOT_FOUND, "Not Found: Session not found")
            return
        _stream(response, "data: \nid: 0\nretry: 3000\n\n")

    def _delete(
        mut self, request: Request, mut response: ResponseWriter
    ) raises:
        """End a session."""
        var id = request.header(SESSION_HEADER)
        if not id:
            _text(
                response,
                Status.BAD_REQUEST,
                "Bad Request: Session ID is required",
            )
            return
        var key = String(id.value())
        if key in self.sessions:
            _ = self.sessions.pop(key)
        response.set_status(Status.ACCEPTED)

    def _post(mut self, request: Request, mut response: ResponseWriter) raises:
        """Answer one message."""
        var accept = request.header("accept")
        if (
            not accept
            or "application/json" not in accept.value()
            or "text/event-stream" not in accept.value()
        ):
            _text(
                response,
                Status.NOT_ACCEPTABLE,
                (
                    "Not Acceptable: Client must accept both application/json"
                    " and text/event-stream"
                ),
            )
            return
        var content_type = request.header("content-type")
        if not content_type or not content_type.value().startswith(
            "application/json"
        ):
            _text(
                response,
                Status.UNSUPPORTED_MEDIA_TYPE,
                "Unsupported Media Type: Content-Type must be application/json",
            )
            return
        var message = parse_message(
            StringSlice(unsafe_from_utf8=request.body())
        )
        if message.kind == MessageKind.MALFORMED:
            _text(
                response,
                Status.UNSUPPORTED_MEDIA_TYPE,
                _DESERIALIZE + message.error,
            )
            return
        if message.kind == MessageKind.INVALID:
            _text(
                response,
                Status.UNSUPPORTED_MEDIA_TYPE,
                _DESERIALIZE
                + "data did not match any variant of untagged enum"
                " JsonRpcMessage",
            )
            return
        if not self.stateful:
            self._stateless(request, message, response)
            return
        var id = request.header(SESSION_HEADER)
        if not id:
            if (
                message.kind != MessageKind.REQUEST
                or message.method != "initialize"
            ):
                _text(
                    response,
                    Status.UNPROCESSABLE_CONTENT,
                    "Unexpected message, expect initialize request",
                )
                return
            var created = HttpSession()
            var reply = self.server.handle_message(created.session, message)
            var key = new_session_id()
            self.sessions[key] = created^
            response.add_header(SESSION_HEADER, key)
            _stream(
                response,
                "data: \nid: 0\nretry: 3000\n\ndata: " + reply.value() + "\n\n",
            )
            return
        var key = String(id.value())
        if key not in self.sessions:
            _text(response, Status.NOT_FOUND, "Not Found: Session not found")
            return
        if message.kind != MessageKind.REQUEST:
            response.set_status(Status.ACCEPTED)
            return
        ref entry = self.sessions[key]
        var reply = self.server.handle_message(entry.session, message)
        var n = String(entry.requests)
        entry.requests += 1
        _stream(
            response,
            "data: \nid: 0/"
            + n
            + "\nretry: 3000\n\ndata: "
            + reply.value()
            + "\nid: 1/"
            + n
            + "\n\n",
        )

    def _stateless(
        mut self,
        request: Request,
        message: Message,
        mut response: ResponseWriter,
    ) raises:
        """Answer one message without a session."""
        if message.kind != MessageKind.REQUEST:
            response.set_status(Status.ACCEPTED)
            return
        var session = Session()
        session.initialized = True
        session.protocol_version = String(DEFAULT_PROTOCOL_VERSION)
        var version = request.header("mcp-protocol-version")
        if version:
            session.protocol_version = String(version.value())
        var reply = self.server.handle_message(session, message)
        _stream(response, "data: " + reply.value() + "\n\n")


def _text(
    mut response: ResponseWriter, status: Status, text: StringSlice
) raises:
    """Send a plain-text error."""
    response.set_status(status)
    response.write_text(text)


def _stream(mut response: ResponseWriter, events: String) raises:
    """Send an event stream."""
    response.add_header("cache-control", "no-cache")
    response.add_header("x-accel-buffering", "no")
    response.send(Status.OK, "text/event-stream", events)


def listen_http(
    var server: McpServer, config: ServerConfig, stateful: Bool = True
) raises HttpError -> Server[McpHttpHandler]:
    """Listen for MCP clients on the address and the port of a
    configuration, in this process. Call `run()` on the result to serve.

    Args:
        server: The MCP server.
        config: The HTTP configuration; the upstream default port is 8000.
        stateful: Whether clients have sessions.

    Returns:
        The HTTP server.

    Raises:
        HttpError: When the socket cannot be opened.
    """
    return listen(McpHttpHandler(server^, stateful), config)

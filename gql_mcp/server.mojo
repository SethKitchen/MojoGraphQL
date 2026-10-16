# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The MCP server: its configuration, its lifecycle and its dispatch.

The server answers `initialize`, `ping`, `tools/list` and `tools/call`.

Port of the request handling of Apollo MCP Server 2.0.0 (04e4e6e)
`crates/apollo-mcp-server/src/server/states/running.rs` (`call_tool_impl`,
`list_tools_impl`, `get_info`), `server/states/starting.rs` (how the
built-in tools are made), `server_info.rs` and the `server.rs` defaults.
The protocol behavior that the SDK (`rmcp`, Apache-2.0 only) gives is
reimplemented from the MCP specification and the replies of the upstream
binary:

- `initialize` needs a string `protocolVersion`, an object
  `capabilities`, and an object `clientInfo` with a string `name` and a
  string `version`. Without them the reply is the -32602 error that the
  upstream sends. The server answers with the client's version when it
  knows it (2024-11-05, 2025-03-26, 2025-06-18, 2025-11-25), and else with
  2025-11-25.
- Before `initialize`, `ping` gets its reply, and another request gets that
  -32602 error.
- `tools/list` lists the operation tools sorted by name, then `execute`,
  `introspect`, `search` and `validate`. The server writes both forms of
  the list once, with and without output schemas: a client before
  2025-06-18 gets no `outputSchema` and no `structuredContent`.
- `tools/call` without an object `params` with a string `name`, or with
  `arguments` that are not an object, gets -32601 with the method name, as
  the upstream answers. An unknown tool gets -32602 `Tool <name> not found`.
- `resources/list`, `resources/templates/list` and `prompts/list` give
  empty lists, `logging/setLevel` an empty result, and `prompts/get` the
  -32602 `Prompt '<name>' not found` error: the server has no resources and
  no prompts. Another method gets -32601 with the method name.

Differences from upstream:

- Phase 1 has no authentication, no Rhai hooks, no apps, no prompts, no
  telemetry, no GraphOS registry or uplink, no hot reload, and no
  `@private` fields; the configuration is a struct, not a YAML file.
- The sessionless protocol 2026-07-28 (`_meta` in each request) is not
  ported.
- A `notifications/initialized` before `initialize` is ignored; the
  upstream ends the stdio session.
- An operation that does not load is left out, and its error is kept in
  `load_errors`; the upstream writes it to the log.
"""

from std.collections import Dict

from gql_http.client import Client
from gql_http.headers import Headers
from gql_json.value import JsonDocument, JsonKind, NO_NODE
from gql_json.writer import JsonWriter
from gql_language.ast import OperationType
from gql_schema.definition import NO_TYPE, Schema
from gql_mcp.builtin_tools import (
    EXECUTE_TOOL_NAME,
    INTROSPECT_TOOL_NAME,
    SEARCH_TOOL_NAME,
    VALIDATE_TOOL_NAME,
    execute_tool,
    introspect_tool,
    search_tool,
    validate_tool,
)
from gql_mcp.call_result import CallToolResult
from gql_mcp.custom_scalar_map import CustomScalarMap
from gql_mcp.graphql import execute_request, normalized_json, request_body
from gql_mcp.json_tree import JsonTree
from gql_mcp.jsonrpc import (
    ErrorCode,
    Message,
    MessageKind,
    error_message,
    invalid_request_message,
    parse_message,
    result_message,
)
from gql_mcp.operation import Operation, RawOperation
from gql_mcp.tool import AnnotationOverrides, MutationMode, Tool
from gql_mcp.schema_index import RootTypes, SchemaIndex
from gql_mcp.tools import prepare_execute, run_introspect, run_search
from gql_mcp.tools import run_validate

comptime LATEST_PROTOCOL_VERSION = "2025-11-25"
"""The newest protocol version with `initialize`, which the server offers
when it does not know the client's version."""
comptime OUTPUT_SCHEMA_PROTOCOL_VERSION = "2025-06-18"
"""The first protocol version with `outputSchema` and
`structuredContent`."""
comptime META_ERROR = (
    "request _meta is missing or has malformed required fields:"
    " io.modelcontextprotocol/protocolVersion,"
    " io.modelcontextprotocol/clientCapabilities"
)
"""The -32602 message of a request that the server cannot place in a
session."""


def is_known_protocol_version(version: StringSlice) -> Bool:
    """Return whether the server speaks a protocol version.

    Args:
        version: The version that the client asks for.

    Returns:
        True for 2024-11-05, 2025-03-26, 2025-06-18 and 2025-11-25.
    """
    return (
        version == "2024-11-05"
        or version == "2025-03-26"
        or version == "2025-06-18"
        or version == LATEST_PROTOCOL_VERSION
    )


@fieldwise_init
struct ServerInfo(Copyable, Movable):
    """The `serverInfo` of `initialize`, as upstream `ServerInfo`."""

    var name: String
    """The implementation's name."""
    var version: String
    """The implementation's version."""
    var title: Optional[String]
    """A title for people."""
    var description: Optional[String]
    """What the server does."""
    var website_url: Optional[String]
    """The documentation's URL."""

    @staticmethod
    def default() -> ServerInfo:
        """Return the upstream defaults.

        Returns:
            The information of Apollo MCP Server 2.0.0.
        """
        return ServerInfo(
            "Apollo MCP Server",
            "2.0.0",
            String("Apollo MCP Server"),
            String(
                "A Model Context Protocol (MCP) server for exposing GraphQL"
                " APIs as tools."
            ),
            String("https://www.apollographql.com/docs/apollo-mcp-server"),
        )


struct ServerConfig(Copyable, Movable):
    """What the server exposes and where it sends operations. The defaults
    are those of the upstream configuration."""

    var endpoint: String
    """The GraphQL endpoint URL."""
    var headers: List[Tuple[String, String]]
    """The header fields of each GraphQL request."""
    var mutation_mode: MutationMode
    """Which mutations the server exposes."""
    var execute_enabled: Bool
    """Whether the `execute` tool is on."""
    var introspect_enabled: Bool
    """Whether the `introspect` tool is on."""
    var search_enabled: Bool
    """Whether the `search` tool is on."""
    var validate_enabled: Bool
    """Whether the `validate` tool is on."""
    var introspect_minify: Bool
    """Whether `introspect` uses the minified notation."""
    var search_minify: Bool
    """Whether `search` uses the minified notation."""
    var search_leaf_depth: Int
    """How deep `search` follows the types at the ends of its paths."""
    var execute_hint: Optional[String]
    """A hint appended to the `execute` description."""
    var introspect_hint: Optional[String]
    """A hint appended to the `introspect` description."""
    var search_hint: Optional[String]
    """A hint appended to the `search` description."""
    var validate_hint: Optional[String]
    """A hint appended to the `validate` description."""
    var enable_output_schema: Bool
    """Whether operation tools have output schemas and structured results."""
    var disable_type_description: Bool
    """Whether operation descriptions leave out the root field types."""
    var disable_schema_description: Bool
    """Whether operation descriptions leave out the schema types."""
    var custom_scalars: CustomScalarMap
    """The JSON Schemas of custom scalars."""
    var annotations: Dict[String, AnnotationOverrides]
    """Annotation overrides, by operation name."""
    var descriptions: Dict[String, String]
    """Description overrides, by operation name."""
    var server_info: ServerInfo
    """The `serverInfo` of `initialize`."""
    var instructions: Optional[String]
    """The `instructions` of `initialize`."""

    def __init__(out self):
        """Make the default configuration: endpoint
        `http://localhost:4000/`, a JSON content type, no mutations, and no
        built-in tool."""
        self.endpoint = "http://localhost:4000/"
        self.headers = List[Tuple[String, String]]()
        self.headers.append(
            (String("content-type"), String("application/json"))
        )
        self.mutation_mode = MutationMode.NONE
        self.execute_enabled = False
        self.introspect_enabled = False
        self.search_enabled = False
        self.validate_enabled = False
        self.introspect_minify = False
        self.search_minify = False
        self.search_leaf_depth = 1
        self.execute_hint = None
        self.introspect_hint = None
        self.search_hint = None
        self.validate_hint = None
        self.enable_output_schema = False
        self.disable_type_description = False
        self.disable_schema_description = False
        self.custom_scalars = CustomScalarMap()
        self.annotations = Dict[String, AnnotationOverrides]()
        self.descriptions = Dict[String, String]()
        self.server_info = ServerInfo.default()
        self.instructions = None


struct Session(Copyable, Movable):
    """The state of one client: whether it sent `initialize`, and the
    protocol version that the server answered."""

    var initialized: Bool
    """Whether the client sent a valid `initialize`."""
    var protocol_version: String
    """The negotiated version; empty before `initialize`."""

    def __init__(out self):
        """Start a session before `initialize`."""
        self.initialized = False
        self.protocol_version = String()

    def supports_output_schema(self) -> Bool:
        """Return whether the client can read output schemas.

        Returns:
            True from protocol 2025-06-18 on.
        """
        return self.protocol_version >= OUTPUT_SCHEMA_PROTOCOL_VERSION


struct McpServer(Movable):
    """An MCP server over a GraphQL schema and its operations. A transport
    gives it each message with the session of its client."""

    var config: ServerConfig
    """The configuration."""
    var schema: Schema
    """The schema."""
    var operations: List[Operation]
    """The operation tools, sorted by name."""
    var builtin: List[Tool]
    """The built-in tools that are on, in list order."""
    var index: SchemaIndex
    """The search index; empty when `search` is off."""
    var load_errors: List[String]
    """The errors of the operations that did not load."""
    var client: Client
    """The HTTP client of the GraphQL endpoint."""
    var _tools_with_output: String
    """The `tools/list` result with output schemas."""
    var _tools_without_output: String
    """The `tools/list` result without output schemas."""
    var _headers: Headers
    """The header fields of each GraphQL request."""

    def __init__(
        out self,
        var config: ServerConfig,
        var schema: Schema,
        operations: List[RawOperation],
    ) raises:
        """Make the tools of the operations and of the configuration.

        Args:
            config: The configuration.
            schema: The schema; it must be valid.
            operations: The operations to expose.

        Raises:
            Error: When a configured header field is not valid HTTP.
        """
        self.config = config^
        self.schema = schema^
        self.operations = List[Operation]()
        self.load_errors = List[String]()
        for raw in operations:
            try:
                var operation = Operation.from_raw(
                    raw.copy(),
                    self.schema,
                    self.config.custom_scalars,
                    self.config.mutation_mode,
                    self.config.disable_type_description,
                    self.config.disable_schema_description,
                    self.config.enable_output_schema,
                    self.config.annotations,
                    self.config.descriptions,
                )
                if operation:
                    _insert_sorted(self.operations, operation.take())
            except e:
                self.load_errors.append("Invalid operation: " + String(e))
        self.builtin = List[Tool]()
        var all = self.config.mutation_mode == MutationMode.ALL
        var roots = RootTypes.NONE
        if self.config.search_enabled:
            roots = (
                RootTypes.QUERY | RootTypes.MUTATION if all else RootTypes.QUERY
            )
        self.index = SchemaIndex(self.schema, roots)
        if self.config.execute_enabled:
            self.builtin.append(
                execute_tool(
                    self.config.mutation_mode, self.config.execute_hint
                )
            )
        if self.config.introspect_enabled:
            self.builtin.append(
                introspect_tool(
                    _root_name(self.schema, OperationType.QUERY.value),
                    _root_name(
                        self.schema, OperationType.MUTATION.value
                    ) if all else None,
                    self.config.introspect_minify,
                    self.config.introspect_hint,
                )
            )
        if self.config.search_enabled:
            self.builtin.append(
                search_tool(self.config.search_minify, self.config.search_hint)
            )
        if self.config.validate_enabled:
            self.builtin.append(validate_tool(self.config.validate_hint))
        self._headers = Headers()
        for header in self.config.headers:
            self._headers.add(header[0], header[1])
        self.client = Client()
        self._tools_with_output = String()
        self._tools_without_output = String()
        self._tools_with_output = self._list(True)
        self._tools_without_output = self._list(False)

    def _list(self, with_output: Bool) -> String:
        """Write the `tools/list` result."""
        var writer = JsonWriter(capacity=4096)
        writer.begin_object()
        writer.key("tools")
        writer.begin_array()
        for operation in self.operations:
            if with_output:
                operation.tool.write(writer)
            else:
                var tool = operation.tool.copy()
                tool.output_schema = None
                tool.write(writer)
        for tool in self.builtin:
            tool.write(writer)
        writer.end_array()
        writer.end_object()
        return writer^.take_string()

    def tools_list(self, session: Session) -> String:
        """Return the `tools/list` result for a client.

        Args:
            session: The client's session.

        Returns:
            The JSON text of the result.
        """
        if (
            self.config.enable_output_schema
            and session.supports_output_schema()
        ):
            return self._tools_with_output
        return self._tools_without_output

    def handle(
        mut self, mut session: Session, text: StringSlice
    ) -> Optional[String]:
        """Answer one message of a client.

        Args:
            session: The client's session.
            text: The JSON text of the message.

        Returns:
            The JSON text of the reply, or `None` when the message gets no
            reply.
        """
        var message = parse_message(text)
        return self.handle_message(session, message)

    def handle_message(
        mut self, mut session: Session, message: Message
    ) -> Optional[String]:
        """Answer one parsed message of a client.

        Args:
            session: The client's session.
            message: The message.

        Returns:
            The JSON text of the reply, or `None` when the message gets no
            reply.
        """
        if message.kind == MessageKind.INVALID:
            return invalid_request_message()
        if message.kind != MessageKind.REQUEST:
            return None
        ref method = message.method
        if method == "ping":
            return result_message(message.id, "{}")
        if method == "initialize":
            return self._initialize(session, message)
        if not session.initialized:
            return error_message(
                message.id, ErrorCode.INVALID_PARAMS, META_ERROR
            )
        if method == "tools/list":
            return result_message(message.id, self.tools_list(session))
        if method == "tools/call":
            return self._call(session, message)
        if method == "resources/list":
            return result_message(message.id, '{"resources":[]}')
        if method == "resources/templates/list":
            return result_message(message.id, '{"resourceTemplates":[]}')
        if method == "prompts/list":
            return result_message(message.id, '{"prompts":[]}')
        if method == "logging/setLevel":
            return result_message(message.id, "{}")
        if method == "prompts/get":
            var name = _string_member(message.document, message.params, "name")
            if name:
                return error_message(
                    message.id,
                    ErrorCode.INVALID_PARAMS,
                    "Prompt '" + name.value() + "' not found",
                )
        return error_message(message.id, ErrorCode.METHOD_NOT_FOUND, method)

    def _initialize(mut self, mut session: Session, message: Message) -> String:
        """Answer `initialize` and start the session."""
        ref doc = message.document
        var params = message.params
        var version = _string_member(doc, params, "protocolVersion")
        var client = NO_NODE
        var valid = Bool(version)
        if valid:
            var capabilities = doc.find(params, "capabilities")
            client = doc.find(params, "clientInfo")
            valid = (
                capabilities != NO_NODE
                and doc.kind(capabilities) == JsonKind.OBJECT
                and client != NO_NODE
                and doc.kind(client) == JsonKind.OBJECT
            )
        if valid:
            valid = Bool(_string_member(doc, client, "name")) and Bool(
                _string_member(doc, client, "version")
            )
        if not valid:
            return error_message(
                message.id, ErrorCode.INVALID_PARAMS, META_ERROR
            )
        var negotiated = String(LATEST_PROTOCOL_VERSION)
        if is_known_protocol_version(version.value()):
            negotiated = version.value()
        session.initialized = True
        session.protocol_version = negotiated
        var writer = JsonWriter()
        writer.begin_object()
        writer.key("protocolVersion")
        writer.string(negotiated)
        writer.key("capabilities")
        writer.raw('{"tools":{"listChanged":true}}')
        writer.key("serverInfo")
        writer.begin_object()
        ref info = self.config.server_info
        writer.key("name")
        writer.string(info.name)
        if info.title:
            writer.key("title")
            writer.string(info.title.value())
        writer.key("version")
        writer.string(info.version)
        if info.description:
            writer.key("description")
            writer.string(info.description.value())
        if info.website_url:
            writer.key("websiteUrl")
            writer.string(info.website_url.value())
        writer.end_object()
        if self.config.instructions:
            writer.key("instructions")
            writer.string(self.config.instructions.value())
        writer.end_object()
        return result_message(message.id, writer^.take_string())

    def _call(mut self, session: Session, message: Message) -> String:
        """Answer `tools/call`."""
        ref doc = message.document
        var name = _string_member(doc, message.params, "name")
        if not name:
            return error_message(
                message.id, ErrorCode.METHOD_NOT_FOUND, message.method
            )
        var arguments = doc.find(message.params, "arguments")
        if arguments != NO_NODE:
            var kind = doc.kind(arguments)
            if kind == JsonKind.NULL:
                arguments = NO_NODE
            elif kind != JsonKind.OBJECT:
                return error_message(
                    message.id, ErrorCode.METHOD_NOT_FOUND, message.method
                )
        var result = self.call_tool(name.value(), doc, arguments)
        if not result:
            return error_message(
                message.id,
                ErrorCode.INVALID_PARAMS,
                "Tool " + name.value() + " not found",
            )
        var structured = (
            self.config.enable_output_schema
            and session.supports_output_schema()
        )
        return result_message(message.id, result.value().to_json(structured))

    def call_tool(
        mut self, name: String, document: JsonDocument, arguments: Int
    ) -> Optional[CallToolResult]:
        """Call a tool by name.

        Args:
            name: The tool's name.
            document: The request document.
            arguments: The `arguments` object, or `NO_NODE`.

        Returns:
            The result, or `None` when no tool has the name.
        """
        var all = self.config.mutation_mode == MutationMode.ALL
        if name == INTROSPECT_TOOL_NAME and self.config.introspect_enabled:
            var mutation = self.schema.root_type(OperationType.MUTATION.value)
            return run_introspect(
                self.schema,
                document,
                arguments,
                all and mutation != NO_TYPE,
                self.config.introspect_minify,
            )
        if name == EXECUTE_TOOL_NAME and self.config.execute_enabled:
            try:
                var request = prepare_execute(
                    document, arguments, self.config.mutation_mode
                )
                return _post(
                    self.client,
                    self.config.endpoint,
                    self._headers,
                    request.query,
                    request.operation_name,
                    request.variables,
                )
            except e:
                return CallToolResult.error(String(e))
        if name == SEARCH_TOOL_NAME and self.config.search_enabled:
            return run_search(
                self.schema,
                self.index,
                document,
                arguments,
                all,
                self.config.search_leaf_depth,
                self.config.search_minify,
            )
        if name == VALIDATE_TOOL_NAME and self.config.validate_enabled:
            return run_validate(self.schema, document, arguments)
        var index = 0
        while index < len(self.operations):
            if self.operations[index].name == name:
                return self._run_operation(index, document, arguments)
            index += 1
        return None

    def _run_operation(
        mut self, index: Int, document: JsonDocument, arguments: Int
    ) -> CallToolResult:
        """Send an operation tool's operation with the arguments."""
        ref operation = self.operations[index]
        var variables: String
        try:
            var input = JsonTree()
            if arguments == NO_NODE:
                input.root = input.add_null()
            else:
                input = normalized_json(document, arguments)
            var sent = operation.variables(input, input.root)
            variables = sent.to_string(sent.root)
        except e:
            return CallToolResult.error(String(e))
        var query = operation.query()
        var name = Optional(operation.name.copy())
        if len(operation.raw.headers) == 0:
            return _post(
                self.client,
                self.config.endpoint,
                self._headers,
                query,
                name,
                variables,
            )
        var headers = Headers()
        try:
            # The operation has headers, so the list is never empty.
            var fields = operation.headers(self.config.headers)
            var at = 0
            while at < len(fields):
                var field_name = fields[at][0].copy()
                var field_value = fields[at][1].copy()
                headers.add(field_name, field_value)
                at += 1
        except e:
            return CallToolResult.error(String(e))
        return _post(
            self.client, self.config.endpoint, headers, query, name, variables
        )


def _post(
    mut client: Client,
    endpoint: String,
    headers: Headers,
    query: String,
    operation_name: Optional[String],
    variables: String,
) -> CallToolResult:
    """Post an operation to the endpoint."""
    var body = request_body(query, operation_name, variables)
    return execute_request(client, endpoint, headers, body)


def _string_member(
    document: JsonDocument, object: Int, key: StringSlice
) -> Optional[String]:
    """Return a string member of an object, if it is there."""
    if object == NO_NODE:
        return None
    var node = document.find(object, key)
    if node == NO_NODE or document.kind(node) != JsonKind.STRING:
        return None
    return document.string_value(node)


def _root_name(schema: Schema, operation: UInt8) -> Optional[String]:
    """Return the name of a root type, if the schema has it."""
    var type = schema.root_type(operation)
    if type == NO_TYPE:
        return None
    return schema.types[type].name.copy()


def _insert_sorted(mut operations: List[Operation], var operation: Operation):
    """Insert an operation in name order, after those of the same name."""
    var at = len(operations)
    while at > 0 and operations[at - 1].name > operation.name:
        at -= 1
    operations.insert(at, operation^)

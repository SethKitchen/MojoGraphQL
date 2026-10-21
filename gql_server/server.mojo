# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The GraphQL server: its options, its start and stop, and the two ways
to run an operation.

Port of Apollo Server 5.5.1 `ApolloServer.ts`: the constructor and its
defaults, `start`, `stop`, `executeOperation`,
`executeHTTPGraphQLRequest`, `errorResponse` and the landing page check.

**Differences from upstream.**
- The plugins are one struct of a type parameter, `ApolloServer[P]`. Use
  `PluginPair` to combine plugins. `addPlugin` is not ported, because the
  type of the plugins cannot change.
- The schema is a `gql_schema` schema, with `gql_execution` resolvers.
  `ApolloServer.from_type_defs` builds it from SDL, as upstream
  `typeDefs` and `resolvers` do.
- `start` and `stop` are synchronous, so the `starting`, `stopping` and
  `draining` phases do not exist. There is no gateway and no
  `startInBackgroundHandlingStartupErrorsByLoggingAndFailingAllRequests`.
- The context function raises a Mojo `Error`, which always becomes
  `Context creation failed: <message>` with status 500. Upstream keeps a
  thrown `GraphQLError` as it is.
- There is no default landing page: upstream serves Apollo Sandbox, a
  web application. `landing_page_html` gives the page to serve.
- There is no logger, no usage reporting, no schema reporting and no
  Apollo configuration (`apollo`, `APOLLO_KEY`).
- The inline trace plugin is the `inline_trace` option, not a plugin of
  `P`: see `gql_server.inline_trace`.
- `stringifyResult`, custom caches and custom document stores are not
  options. The cache and the document store are in-memory LRU caches, as
  the upstream defaults.
"""

from std.memory import ArcPointer
from std.os import getenv

from gql_execution.execute import Resolvers
from gql_http.body import BodyPoll
from gql_stream.waker import Waker
from gql_execution.value import Values
from gql_language.parser import ParseOptions
from gql_schema.build import build_schema
from gql_schema.definition import Schema
from gql_schema.validate import assert_valid_schema
from gql_server.cache_policy import CalculateHttpHeaders
from gql_server.error_normalize import (
    FormatErrorFunction,
    normalize_and_format_errors,
)
from gql_server.errors import (
    ApolloServerErrorCode,
    ServerError,
    ensure_graphql_error,
    has_code,
)
from gql_server.http_types import (
    HTTPGraphQLHead,
    HTTPGraphQLRequest,
    HTTPGraphQLResponse,
)
from gql_server.incremental import (
    IncrementalResults,
    SubsequentPayload,
    TestingIncrementalResults,
    next_part,
)
from gql_server.inline_trace import InlineTraceOptions, InlineTracePlugin
from gql_server.lru import DEFAULT_MAX_SIZE, InMemoryLRUCache
from gql_server.plugin import NoPlugin, ServerPlugin
from gql_server.request_pipeline import (
    RootValueFunction,
    ServerInternals,
    internal_execute_operation,
    next_subsequent_payload,
)
from gql_server.run_http_query import (
    APPLICATION_JSON,
    choose_content_type_for_single_result_response,
    prefers_html,
    prevent_csrf,
    run_potentially_batched_http_query,
)
from gql_server.types import (
    GraphQLRequest,
    GraphQLResponse,
    pretty_json_stringify,
)
from gql_validation.validate import ValidationOptions

comptime ContextFunction = def(
    mut values: Values, request: HTTPGraphQLRequest
) raises thin -> Int
"""The `context` function of an HTTP integration: it makes the context
value of a request in the arena, from the request."""


def default_context(mut values: Values, request: HTTPGraphQLRequest) -> Int:
    """The default context function: an empty object, as upstream
    `async () => ({})`.

    Args:
        values: The arena.
        request: The request.

    Returns:
        A new empty object.
    """
    return values.add_object()


@fieldwise_init
struct ServerPhase(Equatable, ImplicitlyCopyable, Writable):
    """The phase of a server: the synchronous phases of upstream
    `ServerState`."""

    var value: UInt8
    """The index of the phase; see `is_valid`."""

    comptime INITIALIZED = ServerPhase(0)
    """Made, and not started."""
    comptime STARTED = ServerPhase(1)
    """Started: it runs operations."""
    comptime FAILED_TO_START = ServerPhase(2)
    """A `server_will_start` hook raised."""
    comptime STOPPED = ServerPhase(3)
    """Stopped."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the four phases.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 3

    def write_to(self, mut writer: Some[Writer]):
        """Write the phase as upstream names it.

        Args:
            writer: The destination.
        """
        if self.value == 0:
            writer.write("initialized")
        elif self.value == 1:
            writer.write("started")
        elif self.value == 2:
            writer.write("failed to start")
        elif self.value == 3:
            writer.write("stopped")
        else:
            writer.write("<invalid>")


struct ApolloServerOptions(Copyable, Movable):
    """The options of a server: upstream `ApolloServerOptions`. A field
    that is None takes the upstream default."""

    var node_env: Optional[String]
    """`nodeEnv`; None reads the `NODE_ENV` environment variable."""
    var introspection: Optional[Bool]
    """`introspection`; None is on unless `node_env` is `production`."""
    var include_stacktrace_in_error_responses: Optional[Bool]
    """`includeStacktraceInErrorResponses`; None is on unless `node_env`
    is `production` or `test`."""
    var format_error: Optional[FormatErrorFunction]
    """`formatError`."""
    var root_value: Optional[RootValueFunction]
    """`rootValue`, as a function of the document."""
    var persisted_queries: Bool
    """False for upstream `persistedQueries: false`."""
    var persisted_queries_ttl: Int
    """`persistedQueries.ttl` in seconds; 0 for none."""
    var cache_max_size: Int
    """The size limit of the cache, which holds the persisted queries."""
    var document_store: Bool
    """False for upstream `documentStore: null`."""
    var document_store_max_size: Int
    """The size limit of the document store."""
    var hide_schema_details_from_client_errors: Bool
    """`hideSchemaDetailsFromClientErrors`."""
    var dangerously_disable_validation: Bool
    """`dangerouslyDisableValidation`."""
    var validation_options: ValidationOptions
    """`validationOptions`."""
    var parse_options: ParseOptions
    """`parseOptions`."""
    var max_coercion_errors: Int
    """`executionOptions.maxCoercionErrors`."""
    var allow_batched_http_requests: Bool
    """`allowBatchedHttpRequests`."""
    var csrf_prevention: Bool
    """False for upstream `csrfPrevention: false`."""
    var csrf_prevention_request_headers: Optional[List[String]]
    """`csrfPrevention.requestHeaders`; None for the recommended ones."""
    var status400_for_variable_coercion_errors: Bool
    """`status400ForVariableCoercionErrors`."""
    var calculate_http_headers: CalculateHttpHeaders
    """`calculateHttpHeaders` of the cache control plugin."""
    var landing_page_html: Optional[String]
    """The HTML to answer a `GET` that prefers HTML with; None for none."""
    var testing_incremental_execution_results: Optional[
        TestingIncrementalResults
    ]
    """`__testing_incrementalExecutionResults`: the results of every
    operation, for the tests of the transport."""
    var inline_trace: Optional[InlineTraceOptions]
    """The inline trace plugin. The default traces only a subgraph, as
    the plugin that upstream installs; set `InlineTraceOptions()` to trace
    every schema, as `ApolloServerPluginInlineTrace()`; None turns it off,
    as `ApolloServerPluginInlineTraceDisabled()`."""

    def __init__(out self):
        """Make the upstream defaults."""
        self.node_env = None
        self.introspection = None
        self.include_stacktrace_in_error_responses = None
        self.format_error = None
        self.root_value = None
        self.persisted_queries = True
        self.persisted_queries_ttl = 0
        self.cache_max_size = DEFAULT_MAX_SIZE
        self.document_store = True
        self.document_store_max_size = DEFAULT_MAX_SIZE
        self.hide_schema_details_from_client_errors = False
        self.dangerously_disable_validation = False
        self.validation_options = ValidationOptions()
        self.parse_options = ParseOptions()
        self.max_coercion_errors = 50
        self.allow_batched_http_requests = False
        self.csrf_prevention = True
        self.csrf_prevention_request_headers = None
        self.status400_for_variable_coercion_errors = True
        self.calculate_http_headers = CalculateHttpHeaders.ON
        self.landing_page_html = None
        self.testing_incremental_execution_results = None
        self.inline_trace = InlineTraceOptions.only_if_subgraph()


struct ExecuteOperationOptions(Movable):
    """The second argument of `execute_operation`: upstream
    `ExecuteOperationOptions`."""

    var values: Values
    """The arena of the context value. The values of the operation stay
    here."""
    var context_value: Int
    """The context value; the operation gets a copy."""

    def __init__(out self):
        """Use an empty object as the context value, as upstream."""
        self.values = Values()
        self.context_value = self.values.add_object()


struct ApolloServer[P: ServerPlugin = NoPlugin](Movable):
    """A GraphQL server: upstream `ApolloServer`.

    Parameters:
        P: The type of the plugins.
    """

    var internals: ServerInternals
    """The configuration, the schema, the resolvers and the caches."""
    var plugin: Self.P
    """The plugins."""
    var phase: ServerPhase
    """The phase."""
    var landing_page_html: Optional[String]
    """The landing page, if any."""

    def __init__(
        out self,
        var schema: Schema,
        var resolvers: Resolvers,
        var options: ApolloServerOptions,
        var plugin: Self.P,
    ) raises:
        """Make a server, as `new ApolloServer(config)`.

        Args:
            schema: The schema.
            resolvers: Its resolvers.
            options: The options.
            plugin: The plugins.

        Raises:
            Error: When the schema is not valid, with the messages of
                `assertValidSchema`.
        """
        assert_valid_schema(schema)
        var node_env = options.node_env.or_else(getenv("NODE_ENV", ""))
        var is_dev = node_env != "production"
        self.internals = ServerInternals(schema^, resolvers^)
        ref internals = self.internals
        internals.format_error = options.format_error
        internals.root_value = options.root_value
        internals.include_stacktrace = (
            options.include_stacktrace_in_error_responses.or_else(
                is_dev and node_env != "test"
            )
        )
        internals.persisted_queries = options.persisted_queries
        internals.persisted_query_ttl = options.persisted_queries_ttl
        internals.cache = InMemoryLRUCache[String](options.cache_max_size)
        internals.document_store_enabled = options.document_store
        internals.document_store.max_size = options.document_store_max_size
        internals.introspection = options.introspection.or_else(is_dev)
        internals.hide_schema_details = (
            options.hide_schema_details_from_client_errors
        )
        internals.dangerously_disable_validation = (
            options.dangerously_disable_validation
        )
        internals.validation_options = options.validation_options
        internals.validation_options.assume_valid_schema = True
        internals.parse_options = options.parse_options
        internals.max_coercion_errors = options.max_coercion_errors
        internals.allow_batched_http_requests = (
            options.allow_batched_http_requests
        )
        if not options.csrf_prevention:
            internals.csrf_prevention_request_headers = None
        elif options.csrf_prevention_request_headers:
            internals.csrf_prevention_request_headers = (
                options.csrf_prevention_request_headers.copy()
            )
        internals.status400_for_variable_coercion_errors = (
            options.status400_for_variable_coercion_errors
        )
        internals.calculate_http_headers = options.calculate_http_headers
        internals.testing_incremental = (
            options.testing_incremental_execution_results.copy()
        )
        if options.inline_trace:
            internals.inline_trace = InlineTracePlugin(
                options.inline_trace.value().copy()
            )
        else:
            internals.inline_trace = InlineTracePlugin.disabled()
        self.plugin = plugin^
        self.phase = ServerPhase.INITIALIZED
        self.landing_page_html = options.landing_page_html.copy()

    @staticmethod
    def from_type_defs(
        type_defs: StringSlice,
        var resolvers: Resolvers,
        var options: ApolloServerOptions,
        var plugin: Self.P,
    ) raises -> ApolloServer[Self.P]:
        """Make a server from SDL, as upstream `typeDefs` and `resolvers`.

        Args:
            type_defs: The SDL of the schema.
            resolvers: The resolvers.
            options: The options.
            plugin: The plugins.

        Returns:
            The server.

        Raises:
            Error: When the SDL is not a valid schema.
        """
        return ApolloServer[Self.P](
            build_schema(type_defs), resolvers^, options^, plugin^
        )

    def start(mut self) raises:
        """Start the server: run the `server_will_start` hooks.

        Raises:
            Error: When the server is not new, or when a hook raises; the
                server then fails every operation.
        """
        if self.phase != ServerPhase.INITIALIZED:
            raise Error(
                "You should only call 'start()' or"
                " 'startInBackgroundHandlingStartupErrorsByLoggingAndFailingAllRequests()'"
                " once on your ApolloServer."
            )
        try:
            self.plugin.server_will_start()
            self.internals.inline_trace.server_will_start(self.internals.schema)
        except e:
            self.phase = ServerPhase.FAILED_TO_START
            raise e^
        self.phase = ServerPhase.STARTED

    def stop(mut self) raises:
        """Stop the server: run the `server_will_stop` hooks of a started
        server.

        Raises:
            Error: When a hook raises; the server is stopped anyway.
        """
        var started = self.phase == ServerPhase.STARTED
        self.phase = ServerPhase.STOPPED
        if started:
            self.plugin.server_will_stop()

    def _ensure_started(self) raises:
        """Upstream `_ensureStarted`."""
        if self.phase == ServerPhase.INITIALIZED:
            raise Error(
                "You need to call `server.start()` before using your Apollo"
                " Server."
            )
        if self.phase == ServerPhase.FAILED_TO_START:
            raise Error(
                "This data graph is missing a valid configuration. More"
                " details may be available in the server logs."
            )
        if self.phase == ServerPhase.STOPPED:
            raise Error(
                "Cannot execute GraphQL operations after the server has"
                " stopped.'"
            )

    def execute_operation(
        mut self,
        var request: GraphQLRequest,
        mut options: ExecuteOperationOptions,
    ) raises -> GraphQLResponse:
        """Run an operation in process, without HTTP: upstream
        `executeOperation`. A new server starts first.

        Args:
            request: The request.
            options: The context value and its arena.

        Returns:
            The response, with its HTTP status and fields.

        Raises:
            Error: When the server cannot start or is stopped; or
                `Internal server error` when a plugin hook raises.
        """
        if self.phase == ServerPhase.INITIALIZED:
            self.start()
        self._ensure_started()
        return internal_execute_operation(
            self.internals,
            self.plugin,
            request^,
            HTTPGraphQLHead(),
            options.values,
            options.context_value,
            False,
        )

    def execute_operation(
        mut self, var request: GraphQLRequest
    ) raises -> GraphQLResponse:
        """Run an operation with an empty object as the context value.

        Args:
            request: The request.

        Returns:
            The response.

        Raises:
            Error: As the other `execute_operation` raises.
        """
        var options = ExecuteOperationOptions()
        return self.execute_operation(request^, options)

    def next_subsequent_payload(
        mut self, mut response: GraphQLResponse, mut waker: Waker
    ) raises -> Optional[SubsequentPayload]:
        """Poll the next subsequent payload of an `incremental` response:
        upstream `for await (const payload of body.subsequentResults)`.

        Args:
            response: A response of `execute_operation`.
            waker: The waker of the owner; a stream that is not ready
                keeps it.

        Returns:
            The payload, or None when none is ready now or no payload
            follows: `finished` of `subsequent_results` tells which.

        Raises:
            Error: For a response that is not `incremental`, when the
                results fail, or when a plugin hook raises.
        """
        if not response.subsequent_results:
            raise Error("The response is not incremental")
        return next_subsequent_payload(
            self.internals,
            self.plugin,
            response.subsequent_results.value()[],
            waker,
        )

    def poll_chunk(
        mut self,
        chunks: ArcPointer[IncrementalResults],
        mut out: List[UInt8],
    ) -> BodyPoll:
        """Write the next part of a `chunked` body: upstream
        `writeMultipartBody` after the first part.

        Args:
            chunks: The `chunks` of an `HTTPGraphQLResponse`.
            out: Gets the bytes of the part.

        Returns:
            `READY` after a part, `PENDING` when no part is ready, `DONE`
            at the end, and `ERROR` when the results or a hook fail.
        """
        try:
            var waker = Waker.noop()
            var payload = next_subsequent_payload(
                self.internals, self.plugin, chunks[], waker
            )
            if payload:
                out.extend(next_part(payload.value()).as_bytes())
                return BodyPoll.DONE if chunks[].finished else BodyPoll.READY
        except:
            chunks[].close()
            return BodyPoll.ERROR
        if chunks[].finished:
            return BodyPoll.DONE
        return BodyPoll.PENDING

    def error_response(
        self, error: ServerError, request: HTTPGraphQLRequest
    ) -> HTTPGraphQLResponse:
        """Answer with one error: upstream `errorResponse`.

        Args:
            error: The error.
            request: The request, for its `accept` field.

        Returns:
            The response: the status of the error or 500, its fields, and
            the content type that `accept` prefers.
        """
        var errors = List[ServerError]()
        errors.append(error.copy())
        var normalized = normalize_and_format_errors(
            errors,
            self.internals.format_error,
            self.internals.include_stacktrace,
        )
        var head = HTTPGraphQLHead(normalized.http_from_errors.status)
        if head.status == 0:
            head.status = 500
        head.headers = normalized.http_from_errors.headers.copy()
        var content_type = choose_content_type_for_single_result_response(
            request.headers
        )
        head.headers.set(
            "content-type", content_type.or_else(String(APPLICATION_JSON))
        )
        # One error makes one formatted error.
        var body = String('{"errors":[')
        body += normalized.formatted_errors[0].to_json() + "]}"
        return HTTPGraphQLResponse(head^, pretty_json_stringify(body^))

    def _error_response(
        self, error: ServerError, accept: Optional[String]
    ) -> HTTPGraphQLResponse:
        """`error_response` with the `accept` field only."""
        var request = HTTPGraphQLRequest("GET")
        if accept:
            request.headers.set("accept", accept.value())
        return self.error_response(error, request)

    def execute_http_graphql_request(
        mut self,
        var http_request: HTTPGraphQLRequest,
        context: ContextFunction = default_context,
    ) -> HTTPGraphQLResponse:
        """Answer an HTTP request: upstream `executeHTTPGraphQLRequest`.

        The steps are: the landing page for a `GET` that prefers HTML, the
        CSRF check, the context function, then the operation or the batch.
        Every error becomes a response with `errors`.

        Args:
            http_request: The request; `body` is its JSON content.
            context: The context function.

        Returns:
            The response.
        """
        try:
            self._ensure_started()
        except e:
            return self.error_response(ensure_graphql_error(e), http_request)
        if self.landing_page_html and prefers_html(http_request):
            var head = HTTPGraphQLHead()
            head.headers.set("content-type", "text/html")
            return HTTPGraphQLResponse(head^, self.landing_page_html.value())
        var accept = http_request.headers.get("accept")
        try:
            return self._run(http_request^, context)
        except e:
            if has_code(e, ApolloServerErrorCode.BAD_REQUEST):
                try:
                    self.plugin.invalid_request_was_received(e)
                except:
                    pass
            return self._error_response(e, accept)

    def _run(
        mut self, var http_request: HTTPGraphQLRequest, context: ContextFunction
    ) raises ServerError -> HTTPGraphQLResponse:
        """The steps of `execute_http_graphql_request` that can raise."""
        if self.internals.csrf_prevention_request_headers:
            prevent_csrf(
                http_request.headers,
                self.internals.csrf_prevention_request_headers.value(),
            )
        var values = Values()
        var context_value: Int
        try:
            context_value = context(values, http_request)
        except e:
            var error = ensure_graphql_error(e, "Context creation failed: ")
            try:
                self.plugin.context_creation_did_fail(error)
            except:
                pass
            return self.error_response(error, http_request)
        return run_potentially_batched_http_query(
            self.internals, self.plugin, http_request^, values, context_value
        )

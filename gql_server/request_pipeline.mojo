# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The request pipeline: from a GraphQL request to its response.

Port of Apollo Server 5.5.1 `requestPipeline.ts`
(`processGraphQLRequest`), with `validationRules/NoIntrospection.ts`, the
`DisableSuggestions` plugin of `plugin/disableSuggestions/index.ts` and
`APQ_CACHE_PREFIX`.

The steps are those of upstream: persisted queries, the document store,
parse, validation, the operation, the plugin hooks, execution, the error
codes and the HTTP status.

**Differences from upstream.**
- Execution is `gql_execution.execute`, which is synchronous. A document
  with `@defer` or `@stream` runs with `experimental_execute_incrementally`
  instead; see `gql_server.incremental`. The gateway executor is not
  ported.
- In a batch, an operation with `@defer` or `@stream` gets an empty
  object as its context value: its execution keeps its arena, and the
  other operations of the batch share the arena of the context value.
- `willResolveField` is `GraphQLRequestContext.will_resolve_field`: when
  a plugin sets it, execution records the `FieldTiming` of each field in
  `GraphQLRequestContext.field_timings`. Only the inline trace plugin
  reads them; a `ServerPlugin` has no `willResolveField` hook.
- `NoIntrospection` runs after the specified rules. Its errors come after
  their errors; upstream runs all rules in one walk, so its errors can be
  among theirs.
- The `MaxRecursiveSelections` rule and custom validation rules are not
  ported: `gql_validation` rules are values, not functions.
- A variable coercion error is `BAD_USER_INPUT` when it has no path, one
  location and the upstream message prefix. Upstream also checks that its
  node is a variable definition; `gql_execution` errors have no nodes.
- The document store holds parsed documents by query hash. The size of an
  entry is the size of the query text and of its nodes; upstream uses the
  length of the JSON of the document.
- There is no logger: a failed write to a cache is not possible here.
"""

from std.memory import ArcPointer
from std.time import perf_counter_ns

from gql_execution.execute import ExecutionArgs, ExecutionResult, Resolvers
from gql_execution.execute import execute
from gql_execution.incremental import (
    ExperimentalIncrementalExecutionResults,
    experimental_execute_incrementally,
)
from gql_execution.value import Values
from gql_server.negotiator import preferred_media_type
from gql_stream.poll import PollState
from gql_stream.waker import Waker
from gql_json.value import NO_NODE as NO_JSON
from gql_json.value import JsonDocument, JsonKind
from gql_language.ast import NO_NODE, Document, Kind, OperationType
from gql_language.error import GraphQLError, quote_json_string
from gql_language.get_operation_ast import get_operation_ast
from gql_language.parser import ParseOptions, parse
from gql_schema.definition import Schema
from gql_schema.values import js_number_to_string
from gql_server.cache_policy import CalculateHttpHeaders, cache_control_header
from gql_server.error_normalize import (
    FormatErrorFunction,
    NormalizedErrors,
    normalize_and_format_errors,
)
from gql_server.errors import (
    ApolloServerValidationErrorCode,
    ServerError,
    bad_request_error,
    ensure_graphql_error,
    find_extension,
    operation_resolution_error,
    persisted_query_not_found_error,
    persisted_query_not_supported_error,
    set_extension,
    syntax_error,
    user_input_error,
    validation_error,
)
from gql_server.http_types import HTTPGraphQLHead, merge_http_graphql_head
from gql_server.incremental import (
    LEGACY_NOT_SUPPORTED_MESSAGE,
    MULTIPART_MIXED_EXPERIMENTAL_ALPHA_2,
    MULTIPART_MIXED_EXPERIMENTAL_ALPHA_9,
    IncrementalResults,
    SubsequentPayload,
    TestingIncrementalResults,
    uses_incremental_delivery,
    write_entry,
)
from gql_server.inline_trace import InlineTraceOptions, InlineTracePlugin
from gql_server.lru import InMemoryLRUCache
from gql_server.plugin import ServerPlugin
from gql_server.sha256 import sha256_hex
from gql_server.types import (
    GraphQLRequest,
    GraphQLRequestContext,
    GraphQLResponse,
)
from gql_validation.rules import ValidationRule, specified_rules
from gql_validation.validate import ValidationOptions, validate

comptime APQ_CACHE_PREFIX = "apq:"
"""The prefix of the keys of persisted queries in the cache."""

comptime NO_INTROSPECTION_MESSAGE = (
    "GraphQL introspection is not allowed by Apollo Server, but the query"
    " contained __schema or __type. To enable introspection, pass"
    " introspection: true to ApolloServer in production"
)
"""The message of the `NoIntrospection` rule."""

comptime RootValueFunction = def(
    mut values: Values, document: Document
) raises thin -> Int
"""The `rootValue` option as a function of the document: it returns the
root value, a value of the arena."""


struct ServerInternals(Movable):
    """The configuration and the state of a server that the pipeline
    reads: upstream `ApolloServerInternals` and `SchemaDerivedData`."""

    var schema: Schema
    """The schema, valid."""
    var resolvers: Resolvers
    """The resolvers of the schema."""
    var format_error: Optional[FormatErrorFunction]
    """The `formatError` option."""
    var root_value: Optional[RootValueFunction]
    """The `rootValue` option."""
    var include_stacktrace: Bool
    """The `includeStacktraceInErrorResponses` option."""
    var persisted_queries: Bool
    """Whether automatic persisted queries are on."""
    var persisted_query_ttl: Int
    """The `persistedQueries.ttl` option in seconds; 0 for none."""
    var cache: InMemoryLRUCache[String]
    """The cache of the server, which holds the persisted queries."""
    var document_store_enabled: Bool
    """Whether the document store is on."""
    var document_store: InMemoryLRUCache[ArcPointer[Document]]
    """The parsed and validated documents, by query hash."""
    var introspection: Bool
    """The `introspection` option."""
    var hide_schema_details: Bool
    """The `hideSchemaDetailsFromClientErrors` option."""
    var dangerously_disable_validation: Bool
    """The `dangerouslyDisableValidation` option."""
    var validation_rules: List[ValidationRule]
    """The specified rules."""
    var validation_options: ValidationOptions
    """The `validationOptions` option."""
    var parse_options: ParseOptions
    """The `parseOptions` option."""
    var max_coercion_errors: Int
    """The `executionOptions.maxCoercionErrors` option."""
    var allow_batched_http_requests: Bool
    """The `allowBatchedHttpRequests` option."""
    var csrf_prevention_request_headers: Optional[List[String]]
    """The headers of CSRF prevention, or None when it is off."""
    var status400_for_variable_coercion_errors: Bool
    """The `status400ForVariableCoercionErrors` option."""
    var calculate_http_headers: CalculateHttpHeaders
    """The `calculateHttpHeaders` option of the cache control plugin."""
    var accept_memo: Optional[String]
    """The last `accept` field that content negotiation read."""
    var accept_memo_result: Optional[String]
    """The content type that it chose for that field."""
    var inline_trace: InlineTracePlugin
    """The inline trace plugin, which upstream installs after the other
    plugins."""
    var shared_schema: Optional[ArcPointer[Schema]]
    """A copy of `schema` that incremental results share; made by the
    first incremental execution."""
    var shared_resolvers: Optional[ArcPointer[Resolvers]]
    """A copy of `resolvers` that incremental results share; made with
    `shared_schema`."""
    var testing_incremental: Optional[TestingIncrementalResults]
    """The `__testing_incrementalExecutionResults` option."""

    def __init__(out self, var schema: Schema, var resolvers: Resolvers):
        """Make the internals of a server with the upstream defaults of
        `NODE_ENV=production`.

        Args:
            schema: The schema; it must be valid.
            resolvers: The resolvers.
        """
        self.schema = schema^
        self.resolvers = resolvers^
        self.format_error = None
        self.root_value = None
        self.include_stacktrace = False
        self.persisted_queries = True
        self.persisted_query_ttl = 0
        self.cache = InMemoryLRUCache[String]()
        self.document_store_enabled = True
        self.document_store = InMemoryLRUCache[ArcPointer[Document]]()
        self.introspection = False
        self.hide_schema_details = False
        self.dangerously_disable_validation = False
        self.validation_rules = specified_rules()
        self.validation_options = ValidationOptions()
        self.validation_options.assume_valid_schema = True
        self.parse_options = ParseOptions()
        self.max_coercion_errors = 50
        self.allow_batched_http_requests = False
        self.csrf_prevention_request_headers = List[String](
            ["x-apollo-operation-name", "apollo-require-preflight"]
        )
        self.status400_for_variable_coercion_errors = True
        self.calculate_http_headers = CalculateHttpHeaders.ON
        self.accept_memo = None
        self.accept_memo_result = None
        self.inline_trace = InlineTracePlugin(
            InlineTraceOptions.only_if_subgraph()
        )
        self.shared_schema = None
        self.shared_resolvers = None
        self.testing_incremental = None


def js_truthy(json: JsonDocument, node: Int) -> Bool:
    """Return whether a JSON value is truthy in JavaScript.

    Args:
        json: The document.
        node: The value, or `NO_JSON` for `undefined`.

    Returns:
        False for `undefined`, `null`, `false`, `0`, NaN and `""`.
    """
    if node == NO_JSON:
        return False
    var kind = json.kind(node)
    if kind == JsonKind.NULL:
        return False
    if kind == JsonKind.BOOLEAN:
        return json.bool_value(node)
    if kind == JsonKind.NUMBER:
        return json.as_float64(node) != 0
    if kind == JsonKind.STRING:
        return json.text(node).byte_length() > 0
    return True


def js_string(json: JsonDocument, node: Int) -> String:
    """Return a JSON value as JavaScript `String(value)` writes it.

    Args:
        json: The document.
        node: The value, or `NO_JSON` for `undefined`.

    Returns:
        The text, such as `undefined`, `1` or `[object Object]`.
    """
    if node == NO_JSON:
        return String("undefined")
    var kind = json.kind(node)
    if kind == JsonKind.STRING:
        return json.string_value(node)
    if kind == JsonKind.NUMBER:
        return js_number_to_string(json.as_float64(node))
    if kind == JsonKind.OBJECT:
        return String("[object Object]")
    if kind == JsonKind.ARRAY:
        return _js_array_string(json, node)
    if kind == JsonKind.BOOLEAN:
        return String("true") if json.bool_value(node) else String("false")
    return String("null")


def _js_array_string(json: JsonDocument, node: Int) -> String:
    """`String(array)`: the items, joined by commas; `null` is empty."""
    var out = String("")
    var item = json.first(node)
    while item != NO_JSON:
        if item != json.first(node):
            out += ","
        if json.kind(item) != JsonKind.NULL:
            out += js_string(json, item)
        item = json.next(item)
    return out^


def is_bad_user_input_error(error: ServerError) -> Bool:
    """Return True for an error of variable coercion: upstream
    `isBadUserInputGraphQLError`.

    Args:
        error: An error of execution.

    Returns:
        Whether the error has no path, one location, no `code`, and a
        message such as `Variable "$x" got invalid value ...`.
    """
    if len(error.path) > 0 or len(error.locations) != 1:
        return False
    if find_extension(error.extensions, "code") >= 0:
        return False
    var prefix = StaticString('Variable "$')
    if not error.message.startswith(prefix):
        return False
    var rest = error.message[byte = prefix.byte_length() :]
    var quote = rest.find('"')
    if quote < 0:
        return False
    var after = rest[byte = quote + 1 :]
    return (
        after.startswith(" has invalid value")
        or after.startswith(" got invalid value ")
        or after.startswith(" of required type ")
        or after.startswith(" of non-null type ")
    )


def remove_suggestions(message: String) -> String:
    """Remove the suggestions from a validation message, as the
    `DisableSuggestions` plugin removes the regular expression
    `/ ?Did you mean(.+?)[?]$/`.

    Args:
        message: The message.

    Returns:
        The message without its last sentence when that sentence is a
        `Did you mean` question.
    """
    var at = message.find("Did you mean")
    if at < 0 or not message.endswith("?") or message.byte_length() < at + 14:
        return message
    if at > 0 and message.as_bytes()[at - 1] == 32:
        at -= 1
    return String(message[byte=:at])


def no_introspection_errors(document: Document) -> List[ServerError]:
    """Run the `NoIntrospection` rule: an error at each `__schema` and
    `__type` field, in document order.

    Args:
        document: The document.

    Returns:
        The errors, with the `validationErrorCode` extension.
    """
    var out = List[ServerError]()
    var node = 0
    while node < len(document.nodes):
        if document.kind(node) == Kind.FIELD:
            var name = document.name(node)
            if name == "__schema" or name == "__type":
                var error = ServerError(
                    String(NO_INTROSPECTION_MESSAGE), "GraphQLError"
                )
                error.locations.append(document.location(node))
                set_extension(
                    error.extensions,
                    "validationErrorCode",
                    '"'
                    + String(
                        ApolloServerValidationErrorCode.INTROSPECTION_DISABLED.text()
                    )
                    + '"',
                )
                out.append(error^)
        node += 1
    return out^


def _format_errors(
    internals: ServerInternals, errors: List[ServerError]
) -> NormalizedErrors:
    return normalize_and_format_errors(
        errors, internals.format_error, internals.include_stacktrace
    )


def _will_send_response[
    P: ServerPlugin
](
    mut internals: ServerInternals,
    mut plugin: P,
    mut ctx: GraphQLRequestContext,
) raises:
    """Run `willSendResponse`: the plugins, then the cache control plugin
    and the inline trace plugin, which upstream installs after them."""
    plugin.will_send_response(ctx)
    var header = cache_control_header(
        ctx.response.http.headers.get("cache-control"),
        ctx.overall_cache_policy,
        not ctx.response.has_errors and not ctx.response.is_incremental(),
        internals.calculate_http_headers,
    )
    if header:
        ctx.response.http.headers.set("cache-control", header.value())
    # Upstream has no inline traces for incremental delivery.
    if not ctx.response.is_incremental():
        internals.inline_trace.will_send_response(ctx, internals.schema)


def _send_error_response[
    P: ServerPlugin
](
    mut internals: ServerInternals,
    mut plugin: P,
    mut ctx: GraphQLRequestContext,
    var errors: List[ServerError],
) raises:
    """Upstream `sendErrorResponse`: a result with only errors, and status
    500 unless an error gives one."""
    ctx.errors = errors^
    plugin.did_encounter_errors(ctx)
    internals.inline_trace.did_encounter_errors(ctx, internals.schema)
    var normalized = _format_errors(internals, ctx.errors)
    swap(ctx.response.errors, normalized.formatted_errors)
    ctx.response.has_errors = True
    ctx.response.data = JsonDocument()
    merge_http_graphql_head(ctx.response.http, normalized.http_from_errors)
    if ctx.response.http.status == 0:
        ctx.response.http.status = 500
    _will_send_response(internals, plugin, ctx)


def _one(var error: ServerError) -> List[ServerError]:
    var out = List[ServerError]()
    out.append(error^)
    return out^


def _execute(
    mut internals: ServerInternals, mut ctx: GraphQLRequestContext
) raises -> ExecutionResult:
    """Execute the operation of the request with the arena of the request
    context and the resolvers of the server, and give both back."""
    var args = ExecutionArgs()
    swap(args.values, ctx.values)
    swap(args.resolvers, internals.resolvers)
    try:
        args.assume_valid_schema = True
        args.max_coercion_errors = internals.max_coercion_errors
        args.field_timing = ctx.will_resolve_field
        args.context_value = ctx.context_value
        args.operation_name = ctx.request.operation_name
        if ctx.request.variables != NO_JSON:
            args.variable_values = args.values.add_json(
                ctx.request.json, ctx.request.variables
            )
        ref document = ctx.document.value()[]
        if internals.root_value:
            args.root_value = internals.root_value.value()(
                args.values, document
            )
        var result = execute(internals.schema, document, args)
        swap(args.values, ctx.values)
        swap(args.resolvers, internals.resolvers)
        return result^
    except e:
        swap(args.values, ctx.values)
        swap(args.resolvers, internals.resolvers)
        raise e^


def _execute_incrementally(
    mut internals: ServerInternals, mut ctx: GraphQLRequestContext
) raises -> ExperimentalIncrementalExecutionResults:
    """Execute with `@defer` and `@stream`: upstream
    `executeIncrementally` with graphql-js 17.

    The results keep the arena of the request context, and share one copy
    of the schema and of the resolvers. In a batch, the arena is shared by the other operations:
    the execution then gets a new arena, with an empty object as its
    context value.
    """
    var args = ExecutionArgs()
    if ctx.request_is_batched:
        args.context_value = args.values.add_object()
    else:
        swap(args.values, ctx.values)
        args.context_value = ctx.context_value
    args.assume_valid_schema = True
    args.max_coercion_errors = internals.max_coercion_errors
    args.operation_name = ctx.request.operation_name
    if ctx.request.variables != NO_JSON:
        args.variable_values = args.values.add_json(
            ctx.request.json, ctx.request.variables
        )
    var stored = ctx.document.value()
    if internals.root_value:
        args.root_value = internals.root_value.value()(args.values, stored[])
    if not internals.shared_schema:
        internals.shared_schema = ArcPointer(internals.schema.copy())
        internals.shared_resolvers = ArcPointer(internals.resolvers.copy())
    return experimental_execute_incrementally(
        internals.shared_schema.value(),
        stored,
        internals.shared_resolvers.value(),
        args^,
    )


def _wants_legacy(ctx: GraphQLRequestContext) -> Bool:
    """Whether `accept` prefers the legacy format: upstream
    `useLegacyIncremental`."""
    var accept: Optional[String] = None
    if ctx.request.http:
        accept = ctx.request.http.value().headers.get("accept")
    var available: List[String] = [
        MULTIPART_MIXED_EXPERIMENTAL_ALPHA_9,
        MULTIPART_MIXED_EXPERIMENTAL_ALPHA_2,
    ]
    var chosen = preferred_media_type(accept, available)
    return (
        Bool(chosen) and chosen.value() == MULTIPART_MIXED_EXPERIMENTAL_ALPHA_2
    )


def process_graphql_request[
    P: ServerPlugin
](
    mut internals: ServerInternals,
    mut plugin: P,
    mut ctx: GraphQLRequestContext,
) raises:
    """Run a request through the pipeline: upstream
    `processGraphQLRequest`. The response is in `ctx.response`.

    Parameters:
        P: The type of the plugins.

    Args:
        internals: The configuration and the caches of the server.
        plugin: The plugins.
        ctx: The request context.

    Raises:
        Error: When a plugin hook raises. The server turns it into
            `Internal server error`.
    """
    plugin.request_did_start(ctx)
    internals.inline_trace.request_did_start(ctx)
    var query = ctx.request.query.copy()
    var query_hash: String
    ctx.metrics.persisted_query_hit = False
    ctx.metrics.persisted_query_register = False
    ref json = ctx.request.json
    var persisted = NO_JSON
    if ctx.request.extensions != NO_JSON:
        persisted = json.find(ctx.request.extensions, "persistedQuery")
    var now = Int(perf_counter_ns())
    if js_truthy(json, persisted):
        if not internals.persisted_queries:
            _send_error_response(
                internals,
                plugin,
                ctx,
                _one(persisted_query_not_supported_error()),
            )
            return
        var version = NO_JSON
        var hash = NO_JSON
        if json.kind(persisted) == JsonKind.OBJECT:
            version = json.find(persisted, "version")
            hash = json.find(persisted, "sha256Hash")
        if (
            version == NO_JSON
            or json.kind(version) != JsonKind.NUMBER
            or json.as_float64(version) != 1
        ):
            var error = ServerError(
                "Unsupported persisted query version", "GraphQLError"
            )
            error.http = HTTPGraphQLHead(400)
            _send_error_response(internals, plugin, ctx, _one(error^))
            return
        query_hash = js_string(json, hash)
        if not query:
            var cached = internals.cache.get(APQ_CACHE_PREFIX + query_hash, now)
            if cached and cached.value().byte_length() > 0:
                query = cached^
                ctx.metrics.persisted_query_hit = True
            else:
                _send_error_response(
                    internals,
                    plugin,
                    ctx,
                    _one(persisted_query_not_found_error()),
                )
                return
        else:
            var computed = sha256_hex(query.value())
            # A hash that is not a string never equals the computed one,
            # and `String(hash)` of one cannot be 64 hexadecimal digits.
            if query_hash != computed:
                var error = ServerError(
                    "provided sha does not match query", "GraphQLError"
                )
                error.http = HTTPGraphQLHead(400)
                _send_error_response(internals, plugin, ctx, _one(error^))
                return
            ctx.metrics.persisted_query_register = True
    elif query and query.value().byte_length() > 0:
        query_hash = sha256_hex(query.value())
    else:
        _send_error_response(
            internals,
            plugin,
            ctx,
            _one(
                bad_request_error(
                    "GraphQL operations must contain a non-empty `query` or a"
                    " `persistedQuery` extension."
                )
            ),
        )
        return
    ctx.query_hash = query_hash
    ctx.source = query.copy()
    plugin.did_resolve_source(ctx)
    _resolve_document(internals, plugin, ctx, now)


def _document_size(document: Document) -> Int:
    """The size of a document in the store: its text and its nodes."""
    return len(document.source.bytes) + len(document.nodes) * 32


def _resolve_document[
    P: ServerPlugin
](
    mut internals: ServerInternals,
    mut plugin: P,
    mut ctx: GraphQLRequestContext,
    now: Int,
) raises:
    """Find the document in the store, or parse and validate it."""
    if internals.document_store_enabled:
        ctx.document = internals.document_store.get(ctx.query_hash, now)
    if not ctx.document:
        plugin.parsing_did_start(ctx)
        var document: Document
        try:
            document = parse(ctx.source.value(), internals.parse_options)
        except e:
            var error = ServerError.from_graphql_error(e)
            plugin.parsing_did_end(ctx, error.copy())
            _send_error_response(
                internals, plugin, ctx, _one(syntax_error(error^))
            )
            return
        plugin.parsing_did_end(ctx, None)
        ctx.document = ArcPointer(document^)
        if not internals.dangerously_disable_validation:
            plugin.validation_did_start(ctx)
            var found = validate(
                internals.schema,
                ctx.document.value()[],
                internals.validation_rules,
                internals.validation_options,
            )
            var errors = List[ServerError]()
            for ref error in found:
                errors.append(ServerError.from_graphql_error(error))
            if not internals.introspection:
                errors.extend(no_introspection_errors(ctx.document.value()[]))
            if internals.hide_schema_details:
                for ref error in errors:
                    error.message = remove_suggestions(error.message)
            var failed = len(errors) > 0
            plugin.validation_did_end(ctx, errors)
            if failed:
                var wrapped = List[ServerError]()
                var index = 0
                while index < len(errors):
                    wrapped.append(validation_error(errors[index].copy()))
                    index += 1
                _send_error_response(internals, plugin, ctx, wrapped^)
                return
        if internals.document_store_enabled:
            ref stored = ctx.document.value()
            internals.document_store.set(
                ctx.query_hash, stored, _document_size(stored[]), now
            )
    _run_operation(internals, plugin, ctx, now)


def _run_operation[
    P: ServerPlugin
](
    mut internals: ServerInternals,
    mut plugin: P,
    mut ctx: GraphQLRequestContext,
    now: Int,
) raises:
    """Resolve the operation, run the plugins and execute."""
    var stored = ctx.document.value()
    ref document = stored[]
    var operation = get_operation_ast(document, ctx.request.operation_name)
    ctx.operation = operation
    ctx.operation_name = None
    if operation != NO_NODE and document.name(operation).byte_length() > 0:
        ctx.operation_name = String(document.name(operation))
    var is_get = ctx.request.http and ctx.request.http.value().method == "GET"
    if (
        is_get
        and operation != NO_NODE
        and document.operation(operation) != OperationType.QUERY
    ):
        var http = HTTPGraphQLHead(405)
        http.headers.set("allow", "POST")
        _send_error_response(
            internals,
            plugin,
            ctx,
            _one(
                bad_request_error(
                    "GET requests only support query operations, not "
                    + String(document.operation(operation))
                    + " operations",
                    http^,
                )
            ),
        )
        return
    try:
        plugin.did_resolve_operation(ctx)
    except e:
        _send_error_response(internals, plugin, ctx, _one(e^))
        return
    if ctx.metrics.persisted_query_register and internals.persisted_queries:
        ref text = ctx.source.value()
        internals.cache.set(
            APQ_CACHE_PREFIX + ctx.query_hash,
            text,
            text.byte_length(),
            now,
            internals.persisted_query_ttl,
        )
    if plugin.response_for_operation(ctx):
        _will_send_response(internals, plugin, ctx)
        return
    plugin.execution_did_start(ctx)
    if internals.testing_incremental:
        _complete_testing(internals, plugin, ctx)
        return
    var incremental = uses_incremental_delivery(document)
    if incremental and _wants_legacy(ctx):
        _fail_execution(
            internals,
            plugin,
            ctx,
            bad_request_error(
                LEGACY_NOT_SUPPORTED_MESSAGE, HTTPGraphQLHead(406)
            ),
        )
        return
    if not incremental:
        # The hot path: no wrapper of incremental results.
        var result: ExecutionResult
        try:
            result = _execute(internals, ctx)
        except e:
            _fail_execution(internals, plugin, ctx, ensure_graphql_error(e))
            return
        if ctx.operation == NO_NODE:
            _fail_execution(
                internals,
                plugin,
                ctx,
                operation_resolution_error(
                    ServerError.from_graphql_error(result.errors[0])
                ),
            )
            return
        _complete(internals, plugin, ctx, result^)
        return
    var full: ExperimentalIncrementalExecutionResults
    try:
        full = _execute_incrementally(internals, ctx)
    except e:
        _fail_execution(internals, plugin, ctx, ensure_graphql_error(e))
        return
    if ctx.operation == NO_NODE:
        _fail_execution(
            internals,
            plugin,
            ctx,
            operation_resolution_error(
                ServerError.from_graphql_error(full.result.value().errors[0])
            ),
        )
        return
    if full.is_incremental():
        _complete_incremental(internals, plugin, ctx, full^)
        return
    _complete(internals, plugin, ctx, full.result.take())


def _fail_execution[
    P: ServerPlugin
](
    mut internals: ServerInternals,
    mut plugin: P,
    mut ctx: GraphQLRequestContext,
    var error: ServerError,
) raises:
    """End the execution with an error, and send the error response."""
    plugin.execution_did_end(ctx, error.copy())
    _send_error_response(internals, plugin, ctx, _one(error^))


def _complete[
    P: ServerPlugin
](
    mut internals: ServerInternals,
    mut plugin: P,
    mut ctx: GraphQLRequestContext,
    var result: ExecutionResult,
) raises:
    """Turn the result of execution into the response."""
    swap(ctx.field_timings, result.field_timings)
    _record_errors(internals, plugin, ctx, result.errors, result.has_data())
    ctx.response.data = result^.take_data()
    plugin.execution_did_end(ctx, None)
    _will_send_response(internals, plugin, ctx)


def _complete_incremental[
    P: ServerPlugin
](
    mut internals: ServerInternals,
    mut plugin: P,
    mut ctx: GraphQLRequestContext,
    var full: ExperimentalIncrementalExecutionResults,
) raises:
    """Turn the initial result into the response, with an `incremental`
    body."""
    var initial = full.initial_result.take()
    _record_errors(internals, plugin, ctx, initial.errors, True)
    swap(ctx.response.data, initial.data)
    var pending = String("[")
    var index = 0
    while index < len(initial.pending):
        if index > 0:
            pending += ","
        initial.pending[index].write_json(pending)
        index += 1
    ctx.response.pending = pending + "]"
    ctx.response.subsequent_results = ArcPointer(
        IncrementalResults(full.take_subsequent_results())
    )
    plugin.execution_did_end(ctx, None)
    _will_send_response(internals, plugin, ctx)


def _complete_testing[
    P: ServerPlugin
](
    mut internals: ServerInternals,
    mut plugin: P,
    mut ctx: GraphQLRequestContext,
) raises:
    """Answer with the results of the testing option: upstream
    `__testing_incrementalExecutionResults`."""
    ref testing = internals.testing_incremental.value()
    ctx.response.initial_json = testing.initial_result
    ctx.response.subsequent_results = ArcPointer(
        IncrementalResults(testing.subsequent_results())
    )
    plugin.execution_did_end(ctx, None)
    _will_send_response(internals, plugin, ctx)


def _record_errors[
    P: ServerPlugin
](
    mut internals: ServerInternals,
    mut plugin: P,
    mut ctx: GraphQLRequestContext,
    result_errors: List[GraphQLError],
    has_data: Bool,
) raises:
    """Format the errors of the initial result, run `didEncounterErrors`,
    and set the HTTP status that they give."""
    var errors = List[ServerError]()
    for ref error in result_errors:
        var converted = ServerError.from_graphql_error(
            error, "Error" if len(error.path) > 0 else "GraphQLError"
        )
        if is_bad_user_input_error(converted):
            converted = user_input_error(converted^)
        errors.append(converted^)
    var http_from_errors = HTTPGraphQLHead()
    if len(errors) > 0:
        ctx.errors = errors.copy()
        plugin.did_encounter_errors(ctx)
        internals.inline_trace.did_encounter_errors(ctx, internals.schema)
        var normalized = _format_errors(internals, errors)
        swap(ctx.response.errors, normalized.formatted_errors)
        ctx.response.has_errors = True
        swap(http_from_errors, normalized.http_from_errors)
    if (
        internals.status400_for_variable_coercion_errors
        and len(errors) > 0
        and not has_data
    ):
        # Upstream also needs `httpFromErrors.status` to be unset. An error
        # of execution has no `http` extension here, so it always is.
        http_from_errors.status = 400
    merge_http_graphql_head(ctx.response.http, http_from_errors)


def internal_execute_operation[
    P: ServerPlugin
](
    mut internals: ServerInternals,
    mut plugin: P,
    var request: GraphQLRequest,
    var http: HTTPGraphQLHead,
    mut values: Values,
    context_value: Int,
    request_is_batched: Bool,
) raises -> GraphQLResponse:
    """Run one operation: upstream `internalExecuteOperation` of
    `ApolloServer.ts`.

    Parameters:
        P: The type of the plugins.

    Args:
        internals: The configuration and the caches of the server.
        plugin: The plugins.
        request: The request.
        http: The head that the response starts with: a new one, or the
            head that the operations of a batch share.
        values: The arena of the context value. The operation runs in it,
            and its values stay there.
        context_value: The context value. The operation gets a copy, as
            upstream clones the context object.
        request_is_batched: Whether the request is one of a batch.

    Returns:
        The response.

    Raises:
        Error: `Internal server error` when a plugin hook raises, after
            `unexpected_error_processing_request`; or the error of that
            hook when it raises.
    """
    var ctx = GraphQLRequestContext(
        request^, http^, Values(), context_value, request_is_batched
    )
    swap(ctx.values, values)
    ctx.context_value = ctx.values.copy(context_value)
    try:
        process_graphql_request(internals, plugin, ctx)
    except e:
        var error = ensure_graphql_error(e)
        try:
            plugin.unexpected_error_processing_request(ctx, error)
        except hook_error:
            swap(ctx.values, values)
            raise hook_error^
        swap(ctx.values, values)
        raise Error("Internal server error")
    swap(ctx.values, values)
    return ctx^.take_response()


def _format_subsequent_errors(
    internals: ServerInternals,
    errors: List[GraphQLError],
    mut originals: List[ServerError],
) raises -> String:
    """Format the errors of an entry of a subsequent payload, as upstream
    `formatErrors` does, and write them as a JSON array. `originals` gets
    the errors, for `did_encounter_subsequent_errors`."""
    # Each error of a subsequent payload comes from a field, with a path:
    # upstream wraps the original `Error`. The callers pass only an entry
    # with errors, so the list is never empty.
    for ref error in errors:  # pragma: no branch
        originals.append(ServerError.from_graphql_error(error, "Error"))
    var normalized = _format_errors(internals, originals)
    var out = String("[")
    var index = 0
    while index < len(normalized.formatted_errors):
        if index > 0:
            out += ","
        out += normalized.formatted_errors[index].to_json()
        index += 1
    return out + "]"


def next_subsequent_payload[
    P: ServerPlugin
](
    mut internals: ServerInternals,
    mut plugin: P,
    mut results: IncrementalResults,
    mut waker: Waker,
) raises -> Optional[SubsequentPayload]:
    """Poll the next subsequent payload, formatted: upstream
    `formatErrorsInSubsequentResultsAlpha9`.

    The errors of each `incremental` and `completed` entry are formatted
    as the errors of a response. Their `http` extensions have no effect,
    because the head has gone out. `did_encounter_subsequent_errors` gets
    the errors of each entry, and `will_send_subsequent_payload` gets the
    payload.

    Parameters:
        P: The type of the plugins.

    Args:
        internals: The configuration of the server.
        plugin: The plugins.
        results: The subsequent results of a response.
        waker: The waker of the owner; a stream that is not ready keeps
            it.

    Returns:
        The payload, or None when none is ready or the results are done:
        `results.finished` tells which.

    Raises:
        Error: When the stream of the testing option fails, or a plugin
            hook raises.
    """
    if results.finished:
        return None
    if results.testing:
        var poll = results.testing.value().poll_next(waker)
        if poll.state == PollState.PENDING:
            return None
        if poll.state != PollState.READY:
            results.finished = True
            if poll.state == PollState.ERROR:
                raise Error(poll.message)
            return None
        ref event = poll.event.value()
        var has_next = event.document[].find(event.root(), "hasNext")
        var payload = SubsequentPayload(
            event.to_json(),
            has_next != NO_JSON and event.document[].bool_value(has_next),
        )
        plugin.will_send_subsequent_payload(payload)
        return payload^
    ref stream = results.stream.value()
    var polled = stream.poll_payload(waker)
    if not polled:
        results.finished = stream.is_done()
        return None
    ref result = polled.value()
    var out = String('{"hasNext":')
    out += "true" if result.has_next else "false"
    var index = 0
    if result.pending:
        out += ',"pending":['
        while index < len(result.pending):
            if index > 0:
                out += ","
            result.pending[index].write_json(out)
            index += 1
        out += "]"
    if result.incremental:
        out += ',"incremental":['
        index = 0
        while index < len(result.incremental):
            if index > 0:
                out += ","
            ref entry = result.incremental[index]
            var errors: Optional[String] = None
            if entry.errors:
                var originals = List[ServerError]()
                errors = _format_subsequent_errors(
                    internals, entry.errors, originals
                )
                plugin.did_encounter_subsequent_errors(originals)
            write_entry(out, entry, errors)
            index += 1
        out += "]"
    if result.completed:
        out += ',"completed":['
        index = 0
        while index < len(result.completed):
            if index > 0:
                out += ","
            ref completed = result.completed[index]
            out += '{"id":' + quote_json_string(completed.id)
            if completed.errors:
                var originals = List[ServerError]()
                out += ',"errors":' + _format_subsequent_errors(
                    internals, completed.errors, originals
                )
                plugin.did_encounter_subsequent_errors(originals)
            out += "}"
            index += 1
        out += "]"
    if not result.has_next:
        results.finished = True
    var payload = SubsequentPayload(out + "}", result.has_next)
    plugin.will_send_subsequent_payload(payload)
    return payload^

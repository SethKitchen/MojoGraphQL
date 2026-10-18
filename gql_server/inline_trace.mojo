# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The inline trace plugin: federated traces in `extensions.ftv1`.

Port of Apollo Server 5.5.1 `plugin/inlineTrace/index.ts`
(`ApolloServerPluginInlineTrace`), `plugin/disabled/index.ts`
(`ApolloServerPluginInlineTraceDisabled`) and
`plugin/schemaIsSubgraph.ts` (`schemaIsSubgraph`).

When a request has the HTTP header `apollo-federation-include-trace:
ftv1`, the response gets `extensions.ftv1`: the base64 of the protobuf
`Trace` of the request. A gateway or a router reads it to build the trace
of a federated operation.

The server installs the plugin in "only if the schema is a subgraph"
mode, as upstream does when no inline trace plugin is installed. A schema
is a subgraph when it has a `_Service` object type with a `sdl: String`
field.

**Differences from upstream.**
- The plugin is the `inline_trace` option of `ApolloServerOptions`, not
  a plugin of the type parameter of `ApolloServer`. Upstream checks that
  no inline trace plugin is installed before it installs its own; a type
  parameter cannot be checked in that way. The server runs its hooks after
  the hooks of the other plugins and of the cache control plugin, in the
  upstream order.
- The `TraceTreeBuilder` of a request is `GraphQLRequestContext.inline_trace`.
  Upstream keeps it in the closure of `requestDidStart`.
- The plugin sets `GraphQLRequestContext.will_resolve_field`, so that
  execution records the `FieldTiming` of each field. It reads them at
  `did_encounter_errors` or `will_send_response`. Upstream returns a
  `willResolveField` hook.
- There is no logger, so the plugin does not log that it is enabled.
- There is no query plan, so `queryPlan` is not set.
"""

from gql_json.parser import parse as parse_json
from gql_json.value import NO_NODE as NO_JSON
from gql_schema.definition import NO_TYPE, Schema, TypeKind
from gql_server.base64 import base64_encode
from gql_server.trace_tree_builder import SendErrorsOptions, TraceTreeBuilder
from gql_server.types import GraphQLRequestContext

comptime INLINE_TRACE_HEADER = "apollo-federation-include-trace"
"""The HTTP header that asks for a trace."""

comptime MASKED_BY = "ApolloServerPluginInlineTrace"
"""The `maskedBy` extension of a masked error."""


def schema_is_subgraph(schema: Schema) -> Bool:
    """Return True when a schema looks like a subgraph: upstream
    `schemaIsSubgraph`.

    Args:
        schema: The schema.

    Returns:
        Whether `_Service` is an object type with a `sdl` field of type
        `String` or `String!`.
    """
    var service = schema.type_named("_Service")
    if service == NO_TYPE or schema.types[service].kind != TypeKind.OBJECT:
        return False
    var sdl = schema.field_named(service, "sdl")
    if sdl == NO_TYPE:
        return False
    var type = schema.fields[sdl].type
    if type.is_non_null():
        type = type.of_type()
    if type.is_wrapped():
        return False
    ref named = schema.types[Int(type.named)]
    return named.kind == TypeKind.SCALAR and named.name == "String"


struct InlineTraceOptions(Copyable, Movable):
    """The options of the plugin: upstream
    `ApolloServerPluginInlineTraceOptions`."""

    var include_errors: SendErrorsOptions
    """`includeErrors`: how the errors go into the trace. The default
    masks them."""
    var only_if_schema_is_subgraph: Bool
    """`__onlyIfSchemaIsSubgraph`: trace only when the schema is a
    subgraph."""

    def __init__(out self):
        """Make the options of `ApolloServerPluginInlineTrace()`."""
        self.include_errors = SendErrorsOptions()
        self.only_if_schema_is_subgraph = False

    @staticmethod
    def only_if_subgraph() -> InlineTraceOptions:
        """Return the options of the plugin that the server installs:
        `{ __onlyIfSchemaIsSubgraph: true }`.

        Returns:
            The options.
        """
        var options = InlineTraceOptions()
        options.only_if_schema_is_subgraph = True
        return options^


struct InlineTracePlugin(Movable):
    """The plugin: upstream `ApolloServerPluginInlineTrace`."""

    var options: InlineTraceOptions
    """The options."""
    var enabled: Bool
    """Whether the plugin traces requests."""
    var decided: Bool
    """Whether `enabled` is known: False until `server_will_start` in
    "only if the schema is a subgraph" mode, as upstream `null`."""

    def __init__(out self, var options: InlineTraceOptions):
        """Make the plugin: `ApolloServerPluginInlineTrace(options)`.

        Args:
            options: The options.
        """
        self.decided = not options.only_if_schema_is_subgraph
        self.enabled = self.decided
        self.options = options^

    @staticmethod
    def disabled() -> InlineTracePlugin:
        """Return a plugin that never traces:
        `ApolloServerPluginInlineTraceDisabled()`.

        Returns:
            The plugin.
        """
        var plugin = InlineTracePlugin(InlineTraceOptions())
        plugin.enabled = False
        return plugin^

    def server_will_start(mut self, schema: Schema):
        """Decide whether to trace: upstream `serverWillStart`.

        Args:
            schema: The schema of the server.
        """
        if not self.decided:
            self.enabled = schema_is_subgraph(schema)
            self.decided = True

    def request_did_start(mut self, mut ctx: GraphQLRequestContext) raises:
        """Start the trace of a request that asks for one: upstream
        `requestDidStart`.

        Args:
            ctx: The request context.

        Raises:
            Error: Never; the timing starts once.
        """
        if not self.enabled:
            return
        if (
            not ctx.request.http
            or ctx.request.http.value()
            .headers.get(INLINE_TRACE_HEADER)
            .or_else(String(""))
            != "ftv1"
        ):
            return
        # If another plugin decided not to capture traces, do not.
        if ctx.metrics.capture_traces.or_else(True) == False:
            return
        ctx.metrics.capture_traces = True
        var builder = TraceTreeBuilder(
            MASKED_BY, self.options.include_errors.copy()
        )
        builder.start_timing()
        ctx.will_resolve_field = True
        ctx.inline_trace = builder^

    def did_encounter_errors(
        self, mut ctx: GraphQLRequestContext, schema: Schema
    ) raises:
        """Add the errors to the trace: upstream `didEncounterErrors`.

        Args:
            ctx: The request context; `ctx.errors` holds the errors.
            schema: The schema of the server.

        Raises:
            Error: When a `transform` function raises.
        """
        if not ctx.inline_trace:
            return
        var builder = ctx.inline_trace.take()
        try:
            _record_fields(builder, ctx, schema)
            builder.did_encounter_errors(ctx.errors)
        except e:
            ctx.inline_trace = builder^
            raise e^
        ctx.inline_trace = builder^

    def will_send_response(
        self, mut ctx: GraphQLRequestContext, schema: Schema
    ) raises:
        """Stop the trace and put it in `extensions.ftv1`: upstream
        `willSendResponse`.

        Args:
            ctx: The request context.
            schema: The schema of the server.

        Raises:
            Error: `The ftv1 extension was already present.` when another
                plugin set `extensions.ftv1`.
        """
        if not ctx.inline_trace:
            return
        var builder = ctx.inline_trace.take()
        _record_fields(builder, ctx, schema)
        builder.stop_timing()
        var encoded = base64_encode(builder.trace.encode())
        var member = '"ftv1":"' + encoded + '"'
        if not ctx.response.extensions:
            ctx.response.extensions = "{" + member + "}"
            return
        var text = String(ctx.response.extensions.value().strip())
        var extensions = parse_json(text)
        if extensions.find(extensions.root, "ftv1") != NO_JSON:
            raise Error("The `ftv1` extension was already present.")
        var head = String(text[byte = 0 : text.byte_length() - 1])
        if extensions.length(extensions.root) > 0:
            head += ","
        ctx.response.extensions = head + member + "}"


def _record_fields(
    mut builder: TraceTreeBuilder,
    mut ctx: GraphQLRequestContext,
    schema: Schema,
) raises:
    """Give the field timings of execution to the builder, once."""
    for ref timing in ctx.field_timings:
        builder.will_resolve_field(timing, schema)
    ctx.field_timings.clear()

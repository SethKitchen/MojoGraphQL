# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Server plugins: the hooks of the server and request lifecycle.

Port of Apollo Server 5.5.1 `externalTypes/plugins.ts`
(`ApolloServerPlugin`, `GraphQLRequestListener`,
`GraphQLRequestExecutionListener`) and the order of calls of
`utils/invokeHooks.ts`.

A plugin is a struct that implements `ServerPlugin`. Each hook has a
default that does nothing, so a plugin implements only the hooks it needs.
`PluginPair` runs two plugins as one; nest it for more. The server calls
the `*_did_end` hooks in the reverse order of their start hooks, as
upstream `invokeDidStartHook` does.

**Differences from upstream.**
- The request listener of upstream is the plugin itself: one struct gets
  every hook, with the request context.
- `parsingDidStart`, `validationDidStart` and `executionDidStart` of
  upstream return the end hook. Here the end hooks are the methods
  `parsing_did_end`, `validation_did_end` and `execution_did_end`.
- `responseForOperation` returns a response. Here
  `response_for_operation` fills `ctx.response` and returns True.
- `didEncounterSubsequentErrors` gets the errors only, and
  `willSendSubsequentPayload` gets the payload only: the request context
  ends with the initial result here.
- `willResolveField`, `startupDidFail`, `renderLandingPage` and the
  gateway hooks are not ported. The inline trace plugin of
  `gql_server.inline_trace` gets the `FieldTiming` of each field from
  execution in place of `willResolveField`.
- A hook raises a Mojo `Error`. `did_resolve_operation` raises a
  `ServerError`, so that it can give a code and an HTTP status, as an
  upstream hook that throws a `GraphQLError`.
"""

from gql_server.errors import ServerError
from gql_server.incremental import SubsequentPayload
from gql_server.types import GraphQLRequestContext


trait ServerPlugin(Deinitable, Movable):
    """The hooks of a plugin: upstream `ApolloServerPlugin` and its
    request listener."""

    def server_will_start(mut self) raises:
        """Run when the server starts: upstream `serverWillStart`.

        Raises:
            Error: To make the start fail.
        """
        pass

    def server_will_stop(mut self) raises:
        """Run when the server stops: upstream `serverWillStop`.

        Raises:
            Error: To make the stop fail.
        """
        pass

    def request_did_start(mut self, mut ctx: GraphQLRequestContext) raises:
        """Run when a request starts: upstream `requestDidStart`.

        Args:
            ctx: The request context.

        Raises:
            Error: To fail the request with `Internal server error`.
        """
        pass

    def did_resolve_source(mut self, mut ctx: GraphQLRequestContext) raises:
        """Run when the query text is known: upstream `didResolveSource`.

        Args:
            ctx: The request context; `ctx.source` is set.

        Raises:
            Error: To fail the request with `Internal server error`.
        """
        pass

    def parsing_did_start(mut self, mut ctx: GraphQLRequestContext) raises:
        """Run before the query is parsed: upstream `parsingDidStart`.

        Args:
            ctx: The request context.

        Raises:
            Error: To fail the request with `Internal server error`.
        """
        pass

    def parsing_did_end(
        mut self, mut ctx: GraphQLRequestContext, error: Optional[ServerError]
    ) raises:
        """Run after the parse: the end hook of `parsingDidStart`.

        Args:
            ctx: The request context.
            error: The syntax error, or None.

        Raises:
            Error: To fail the request with `Internal server error`.
        """
        pass

    def validation_did_start(mut self, mut ctx: GraphQLRequestContext) raises:
        """Run before validation: upstream `validationDidStart`.

        Args:
            ctx: The request context; `ctx.document` is set.

        Raises:
            Error: To fail the request with `Internal server error`.
        """
        pass

    def validation_did_end(
        mut self, mut ctx: GraphQLRequestContext, mut errors: List[ServerError]
    ) raises:
        """Run after validation: the end hook of `validationDidStart`.

        Args:
            ctx: The request context.
            errors: The validation errors, empty for a valid operation. A
                plugin can change them, as upstream plugins change the
                messages.

        Raises:
            Error: To fail the request with `Internal server error`.
        """
        pass

    def did_resolve_operation(
        mut self, mut ctx: GraphQLRequestContext
    ) raises ServerError:
        """Run when the operation to run is known: upstream
        `didResolveOperation`.

        Args:
            ctx: The request context; `ctx.operation` is set.

        Raises:
            ServerError: To fail the request with this error. Its `http`
                status is the status of the response, 500 by default.
        """
        pass

    def response_for_operation(
        mut self, mut ctx: GraphQLRequestContext
    ) raises -> Bool:
        """Give the response without execution: upstream
        `responseForOperation`.

        Args:
            ctx: The request context; the plugin can fill `ctx.response`.

        Returns:
            True when the plugin filled `ctx.response`, so that the server
            does not execute the operation.

        Raises:
            Error: To fail the request with `Internal server error`.
        """
        return False

    def execution_did_start(mut self, mut ctx: GraphQLRequestContext) raises:
        """Run before execution: upstream `executionDidStart`.

        Args:
            ctx: The request context.

        Raises:
            Error: To fail the request with `Internal server error`.
        """
        pass

    def execution_did_end(
        mut self, mut ctx: GraphQLRequestContext, error: Optional[ServerError]
    ) raises:
        """Run after execution: upstream `executionDidEnd`.

        Args:
            ctx: The request context.
            error: The error that stopped execution, or None.

        Raises:
            Error: To fail the request with `Internal server error`.
        """
        pass

    def did_encounter_errors(mut self, mut ctx: GraphQLRequestContext) raises:
        """Run when the request has errors: upstream `didEncounterErrors`.

        Args:
            ctx: The request context; `ctx.errors` holds the errors.

        Raises:
            Error: To fail the request with `Internal server error`.
        """
        pass

    def will_send_response(mut self, mut ctx: GraphQLRequestContext) raises:
        """Run before the response goes out: upstream `willSendResponse`.

        Args:
            ctx: The request context; the plugin can change
                `ctx.response`.

        Raises:
            Error: To fail the request with `Internal server error`.
        """
        pass

    def did_encounter_subsequent_errors(
        mut self, errors: List[ServerError]
    ) raises:
        """Run when a subsequent payload of incremental delivery has
        errors: upstream `didEncounterSubsequentErrors`.

        Args:
            errors: The errors of one entry of the payload.

        Raises:
            Error: To end the body of the response.
        """
        pass

    def will_send_subsequent_payload(
        mut self, mut payload: SubsequentPayload
    ) raises:
        """Run before a subsequent payload of incremental delivery goes
        out: upstream `willSendSubsequentPayload`.

        Args:
            payload: The payload; the plugin can change its JSON text.

        Raises:
            Error: To end the body of the response.
        """
        pass

    def context_creation_did_fail(mut self, error: ServerError) raises:
        """Run when the context function raises: upstream
        `contextCreationDidFail`.

        Args:
            error: The error of the context function.

        Raises:
            Error: The server ignores it, as upstream logs it.
        """
        pass

    def invalid_request_was_received(mut self, error: ServerError) raises:
        """Run for an HTTP request that the server refuses with
        `BAD_REQUEST`: upstream `invalidRequestWasReceived`.

        Args:
            error: The error.

        Raises:
            Error: The server ignores it, as upstream logs it.
        """
        pass

    def unexpected_error_processing_request(
        mut self, mut ctx: GraphQLRequestContext, error: ServerError
    ) raises:
        """Run when a hook raises: upstream
        `unexpectedErrorProcessingRequest`.

        Args:
            ctx: The request context.
            error: The error.

        Raises:
            Error: This error goes to the client in place of `Internal
                server error`, as upstream.
        """
        pass


@fieldwise_init
struct NoPlugin(ServerPlugin):
    """A plugin with only the default hooks."""

    pass


@fieldwise_init
struct PluginPair[A: ServerPlugin, B: ServerPlugin](ServerPlugin):
    """Two plugins as one. The hooks of `first` run before the hooks of
    `second`, and the end hooks run in the reverse order.

    Parameters:
        A: The type of the first plugin.
        B: The type of the second plugin.
    """

    var first: Self.A
    """The first plugin."""
    var second: Self.B
    """The second plugin."""

    def server_will_start(mut self) raises:
        """Run both hooks.

        Raises:
            Error: When a hook raises.
        """
        self.first.server_will_start()
        self.second.server_will_start()

    def server_will_stop(mut self) raises:
        """Run both hooks.

        Raises:
            Error: When a hook raises.
        """
        self.first.server_will_stop()
        self.second.server_will_stop()

    def request_did_start(mut self, mut ctx: GraphQLRequestContext) raises:
        """Run both hooks.

        Args:
            ctx: The request context.

        Raises:
            Error: When a hook raises.
        """
        self.first.request_did_start(ctx)
        self.second.request_did_start(ctx)

    def did_resolve_source(mut self, mut ctx: GraphQLRequestContext) raises:
        """Run both hooks.

        Args:
            ctx: The request context.

        Raises:
            Error: When a hook raises.
        """
        self.first.did_resolve_source(ctx)
        self.second.did_resolve_source(ctx)

    def parsing_did_start(mut self, mut ctx: GraphQLRequestContext) raises:
        """Run both hooks.

        Args:
            ctx: The request context.

        Raises:
            Error: When a hook raises.
        """
        self.first.parsing_did_start(ctx)
        self.second.parsing_did_start(ctx)

    def parsing_did_end(
        mut self, mut ctx: GraphQLRequestContext, error: Optional[ServerError]
    ) raises:
        """Run both end hooks, the second plugin first.

        Args:
            ctx: The request context.
            error: The syntax error, or None.

        Raises:
            Error: When a hook raises.
        """
        self.second.parsing_did_end(ctx, error)
        self.first.parsing_did_end(ctx, error)

    def validation_did_start(mut self, mut ctx: GraphQLRequestContext) raises:
        """Run both hooks.

        Args:
            ctx: The request context.

        Raises:
            Error: When a hook raises.
        """
        self.first.validation_did_start(ctx)
        self.second.validation_did_start(ctx)

    def validation_did_end(
        mut self, mut ctx: GraphQLRequestContext, mut errors: List[ServerError]
    ) raises:
        """Run both end hooks, the second plugin first.

        Args:
            ctx: The request context.
            errors: The validation errors.

        Raises:
            Error: When a hook raises.
        """
        self.second.validation_did_end(ctx, errors)
        self.first.validation_did_end(ctx, errors)

    def did_resolve_operation(
        mut self, mut ctx: GraphQLRequestContext
    ) raises ServerError:
        """Run both hooks.

        Args:
            ctx: The request context.

        Raises:
            ServerError: When a hook raises.
        """
        self.first.did_resolve_operation(ctx)
        self.second.did_resolve_operation(ctx)

    def response_for_operation(
        mut self, mut ctx: GraphQLRequestContext
    ) raises -> Bool:
        """Ask the first plugin, then the second, as upstream
        `invokeHooksUntilDefinedAndNonNull`.

        Args:
            ctx: The request context.

        Returns:
            Whether a plugin filled `ctx.response`.

        Raises:
            Error: When a hook raises.
        """
        if self.first.response_for_operation(ctx):
            return True
        return self.second.response_for_operation(ctx)

    def execution_did_start(mut self, mut ctx: GraphQLRequestContext) raises:
        """Run both hooks.

        Args:
            ctx: The request context.

        Raises:
            Error: When a hook raises.
        """
        self.first.execution_did_start(ctx)
        self.second.execution_did_start(ctx)

    def execution_did_end(
        mut self, mut ctx: GraphQLRequestContext, error: Optional[ServerError]
    ) raises:
        """Run both end hooks, the second plugin first.

        Args:
            ctx: The request context.
            error: The error that stopped execution, or None.

        Raises:
            Error: When a hook raises.
        """
        self.second.execution_did_end(ctx, error)
        self.first.execution_did_end(ctx, error)

    def did_encounter_errors(mut self, mut ctx: GraphQLRequestContext) raises:
        """Run both hooks.

        Args:
            ctx: The request context.

        Raises:
            Error: When a hook raises.
        """
        self.first.did_encounter_errors(ctx)
        self.second.did_encounter_errors(ctx)

    def will_send_response(mut self, mut ctx: GraphQLRequestContext) raises:
        """Run both hooks.

        Args:
            ctx: The request context.

        Raises:
            Error: When a hook raises.
        """
        self.first.will_send_response(ctx)
        self.second.will_send_response(ctx)

    def did_encounter_subsequent_errors(
        mut self, errors: List[ServerError]
    ) raises:
        """Run both hooks.

        Args:
            errors: The errors.

        Raises:
            Error: When a hook raises.
        """
        self.first.did_encounter_subsequent_errors(errors)
        self.second.did_encounter_subsequent_errors(errors)

    def will_send_subsequent_payload(
        mut self, mut payload: SubsequentPayload
    ) raises:
        """Run both hooks.

        Args:
            payload: The payload.

        Raises:
            Error: When a hook raises.
        """
        self.first.will_send_subsequent_payload(payload)
        self.second.will_send_subsequent_payload(payload)

    def context_creation_did_fail(mut self, error: ServerError) raises:
        """Run both hooks.

        Args:
            error: The error of the context function.

        Raises:
            Error: When a hook raises.
        """
        self.first.context_creation_did_fail(error)
        self.second.context_creation_did_fail(error)

    def invalid_request_was_received(mut self, error: ServerError) raises:
        """Run both hooks.

        Args:
            error: The error.

        Raises:
            Error: When a hook raises.
        """
        self.first.invalid_request_was_received(error)
        self.second.invalid_request_was_received(error)

    def unexpected_error_processing_request(
        mut self, mut ctx: GraphQLRequestContext, error: ServerError
    ) raises:
        """Run both hooks.

        Args:
            ctx: The request context.
            error: The error.

        Raises:
            Error: When a hook raises.
        """
        self.first.unexpected_error_processing_request(ctx, error)
        self.second.unexpected_error_processing_request(ctx, error)

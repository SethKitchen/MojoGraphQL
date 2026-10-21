# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A plugin of the gql_server tests that records each hook, and can raise
in one of them, as the `jest.fn` hooks of Apollo Server 5.5.1
`src/__tests__/runQuery.test.ts` do."""

from gql_server.errors import ServerError
from gql_server.http_types import HTTPGraphQLHead
from gql_server.incremental import SubsequentPayload
from gql_server.plugin import ServerPlugin
from gql_server.types import GraphQLRequestContext


struct Recorder(ServerPlugin):
    """Records the name of each hook, with a prefix."""

    var prefix: String
    var log: List[String]
    var fail_at: String
    var status: Int
    var respond: Bool
    var clear_validation: Bool

    def __init__(out self, prefix: String = "", fail_at: String = ""):
        self.prefix = prefix
        self.log = List[String]()
        self.fail_at = fail_at
        self.status = 0
        self.respond = False
        self.clear_validation = False

    def _hook(mut self, name: String) raises:
        self.log.append(self.prefix + name)
        if name == self.fail_at:
            raise Error(name + " failed")

    def server_will_start(mut self) raises:
        self._hook("serverWillStart")

    def server_will_stop(mut self) raises:
        self._hook("serverWillStop")

    def request_did_start(mut self, mut ctx: GraphQLRequestContext) raises:
        self._hook("requestDidStart")

    def did_resolve_source(mut self, mut ctx: GraphQLRequestContext) raises:
        self._hook("didResolveSource")

    def parsing_did_start(mut self, mut ctx: GraphQLRequestContext) raises:
        self._hook("parsingDidStart")

    def parsing_did_end(
        mut self, mut ctx: GraphQLRequestContext, error: Optional[ServerError]
    ) raises:
        self._hook("parsingDidEnd" + ("(error)" if error else ""))

    def validation_did_start(mut self, mut ctx: GraphQLRequestContext) raises:
        self._hook("validationDidStart")

    def validation_did_end(
        mut self, mut ctx: GraphQLRequestContext, mut errors: List[ServerError]
    ) raises:
        self._hook("validationDidEnd(" + String(len(errors)) + ")")
        if self.clear_validation:
            errors.clear()

    def did_resolve_operation(
        mut self, mut ctx: GraphQLRequestContext
    ) raises ServerError:
        self.log.append(self.prefix + "didResolveOperation")
        if self.fail_at == "didResolveOperation":
            var error = ServerError("denied", "GraphQLError")
            error.http = HTTPGraphQLHead(self.status)
            raise error^

    def response_for_operation(
        mut self, mut ctx: GraphQLRequestContext
    ) raises -> Bool:
        self._hook("responseForOperation")
        if self.respond:
            ctx.response.data.root = ctx.response.data.add_object()
            ctx.response.http.status = 202
        return self.respond

    def execution_did_start(mut self, mut ctx: GraphQLRequestContext) raises:
        self._hook("executionDidStart")

    def execution_did_end(
        mut self, mut ctx: GraphQLRequestContext, error: Optional[ServerError]
    ) raises:
        self._hook("executionDidEnd" + ("(error)" if error else ""))

    def did_encounter_errors(mut self, mut ctx: GraphQLRequestContext) raises:
        self._hook("didEncounterErrors(" + String(len(ctx.errors)) + ")")

    def will_send_response(mut self, mut ctx: GraphQLRequestContext) raises:
        self._hook("willSendResponse")
        if self.prefix == "format:":
            ctx.response.extensions = String('{"formatted":true}')

    def did_encounter_subsequent_errors(
        mut self, errors: List[ServerError]
    ) raises:
        self._hook("didEncounterSubsequentErrors(" + String(len(errors)) + ")")

    def will_send_subsequent_payload(
        mut self, mut payload: SubsequentPayload
    ) raises:
        self._hook("willSendSubsequentPayload")
        if self.prefix == "rewrite:":
            payload.json = String('{"hasNext":false,"rewritten":true}')
            payload.has_next = False

    def context_creation_did_fail(mut self, error: ServerError) raises:
        self._hook("contextCreationDidFail")

    def invalid_request_was_received(mut self, error: ServerError) raises:
        self._hook("invalidRequestWasReceived")

    def unexpected_error_processing_request(
        mut self, mut ctx: GraphQLRequestContext, error: ServerError
    ) raises:
        self._hook("unexpectedErrorProcessingRequest")


def joined(log: List[String]) -> String:
    """The log, joined by spaces."""
    var out = String("")
    for ref entry in log:
        out += (" " if out.byte_length() > 0 else "") + entry
    return out^

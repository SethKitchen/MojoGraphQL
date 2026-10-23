# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The Apollo Server subscription callback plugin.

Port of Apollo Server 5.5.1 `plugin/subscriptionCallback/index.ts`
(`ApolloServerPluginSubscriptionCallback`): the HTTP callback protocol of
the Apollo Router for subscriptions.

When a subscription operation has `extensions.subscription` with
`callbackUrl` and `subscriptionId`:
1. `response_for_operation` runs `subscribe` on the schema and resolvers.
2. It posts `{ "kind": "subscription", "action": "check", "id": ... }` to
   `callbackUrl`, with `content-type: application/json; callbackSpec=1.0;
   charset=utf-8` and `apollo-subscription-protocol: callback/1.0`. A
   status below 200 or above 299 fails the request with
   `SUBSCRIPTION_HANDSHAKE_FAILED`.
3. It sets the `content-type` header of the response to
   `application/json; callbackSpec=1.0; charset=utf-8` and returns
   `{ "data": null }`.
4. `poll` drives active subscriptions: it posts `{ "kind": "subscription",
   "action": "next", "id": ..., "payload": ... }` for each event,
   `{ "kind": "subscription", "action": "complete", "id": ..., "errors":
   ... }` when the stream ends, and `{ "kind": "subscription", "action":
   "check", "id": ... }` when `heartbeat_interval_ms` has passed. A callback
   response outside 200..299 closes and removes the subscription.
"""

from std.memory import ArcPointer
from std.time import perf_counter_ns

from gql_execution.execute import ExecutionArgs, Resolvers
from gql_execution.subscribe import ResponseStream, Subscription, subscribe
from gql_http.client import Client, ClientConfig
from gql_http.error import HttpError
from gql_http.headers import Headers
from gql_http.status import Method
from gql_json.value import NO_NODE as NO_JSON
from gql_json.value import JsonDocument, JsonKind
from gql_language.ast import Document, NO_NODE, OperationType
from gql_language.error import quote_json_string
from gql_schema.definition import Schema
from gql_server.error_normalize import FormattedError
from gql_server.errors import ServerError
from gql_server.http_types import HTTPGraphQLHead
from gql_server.plugin import ServerPlugin
from gql_server.run_http_query import APPLICATION_JSON_GRAPHQL_CALLBACK
from gql_server.types import GraphQLRequestContext
from gql_stream.poll import PollState
from gql_stream.waker import Waker

comptime SUBSCRIPTION_PROTOCOL_HEADER = "apollo-subscription-protocol"
"""The callback protocol header name."""
comptime SUBSCRIPTION_PROTOCOL_VALUE = "callback/1.0"
"""The callback protocol header value."""
comptime SUBSCRIPTION_HANDSHAKE_FAILED = "SUBSCRIPTION_HANDSHAKE_FAILED"
"""The error code when the initial check fails."""


def _now_ms() -> Int:
    """Return a monotonic time in milliseconds."""
    return Int(perf_counter_ns() // 1_000_000)


@fieldwise_init
struct SubscriptionCallbackOptions(Copyable, ImplicitlyCopyable, Movable):
    """The options of `SubscriptionCallbackPlugin`: upstream
    `ApolloServerPluginSubscriptionCallbackOptions`."""

    var heartbeat_interval_ms: Int
    """How often to send a `check` heartbeat in milliseconds; 5000 by
    default."""
    var max_retries: Int
    """How many times to retry a failed callback POST; 5 by default."""

    def __init__(out self):
        """Make the upstream defaults."""
        self.heartbeat_interval_ms = 5000
        self.max_retries = 5


struct _ActiveSubscription(Movable):
    """One active callback subscription."""

    var id: String
    var callback_url: String
    var verifier: String
    var heartbeat_interval_ms: Int
    var last_check_ms: Int
    var stream: ResponseStream

    def __init__(
        out self,
        var id: String,
        var callback_url: String,
        var verifier: String,
        heartbeat_interval_ms: Int,
        last_check_ms: Int,
        var stream: ResponseStream,
    ):
        self.id = id^
        self.callback_url = callback_url^
        self.verifier = verifier^
        self.heartbeat_interval_ms = heartbeat_interval_ms
        self.last_check_ms = last_check_ms
        self.stream = stream^


struct SubscriptionCallbackPlugin(ServerPlugin):
    """The `ApolloServerPluginSubscriptionCallback` plugin."""

    var schema: ArcPointer[Schema]
    """The schema."""
    var resolvers: ArcPointer[Resolvers]
    """The resolvers."""
    var options: SubscriptionCallbackOptions
    """The options."""
    var client: Client
    """The HTTP client that posts callback messages."""
    var active: List[_ActiveSubscription]
    """The active callback subscriptions."""
    var stopped: Bool
    """Whether `server_will_stop` has run."""

    def __init__(
        out self,
        schema: Schema,
        resolvers: Resolvers,
        options: SubscriptionCallbackOptions = SubscriptionCallbackOptions(),
    ):
        """Make a callback plugin for a schema and its resolvers.

        Args:
            schema: The schema.
            resolvers: The resolvers.
            options: The options.
        """
        self.schema = ArcPointer(schema.copy())
        self.resolvers = ArcPointer(resolvers.copy())
        self.options = options
        var config = ClientConfig()
        config.connect_timeout_ms = 2000
        config.timeout_ms = 5000
        self.client = Client(config)
        self.active = List[_ActiveSubscription]()
        self.stopped = False

    def server_will_start(mut self) raises:
        """Reset `stopped` when the server starts.

        Raises:
            Error: Never.
        """
        self.stopped = False

    def server_will_stop(mut self) raises:
        """Close every active subscription when the server stops.

        Raises:
            Error: Never.
        """
        self.stopped = True
        self.active.clear()
        self.client.close_idle()

    def _post_callback(mut self, var url: String, var body: String) -> Int:
        """POST a callback payload with retries; return the status or 0."""
        var attempts = 0
        var limit = self.options.max_retries + 1
        if limit < 1:
            limit = 1
        while attempts < limit:
            attempts += 1
            try:
                var endpoint = self.client.endpoint(url)
                var target = endpoint.target.copy()
                var headers = self._headers()
                var resp = self.client.send(
                    endpoint,
                    Method.POST,
                    target,
                    headers,
                    body.as_bytes(),
                )
                var code = Int(resp.status.code)
                if code >= 200 and code < 300:
                    return code
                if attempts >= limit:
                    return code
            except:
                if attempts >= limit:
                    return 0
        return 0

    def _headers(self) raises HttpError -> Headers:
        var headers = Headers()
        headers.add("Content-Type", APPLICATION_JSON_GRAPHQL_CALLBACK)
        headers.add(SUBSCRIPTION_PROTOCOL_HEADER, SUBSCRIPTION_PROTOCOL_VALUE)
        return headers^

    def _check_body(self, id: String, verifier: String) -> String:
        var out = (
            '{"kind":"subscription","action":"check","id":'
            + quote_json_string(id)
        )
        if verifier.byte_length() > 0:
            out += ',"verifier":' + quote_json_string(verifier)
        return out + "}"

    def _next_body(
        self, id: String, verifier: String, payload_json: String
    ) -> String:
        var out = (
            '{"kind":"subscription","action":"next","id":'
            + quote_json_string(id)
        )
        if verifier.byte_length() > 0:
            out += ',"verifier":' + quote_json_string(verifier)
        return out + ',"payload":' + payload_json + "}"

    def _complete_body(
        self, id: String, verifier: String, error_msg: Optional[String]
    ) -> String:
        var out = (
            '{"kind":"subscription","action":"complete","id":'
            + quote_json_string(id)
        )
        if verifier.byte_length() > 0:
            out += ',"verifier":' + quote_json_string(verifier)
        if error_msg:
            out += (
                ',"errors":[{"message":'
                + quote_json_string(error_msg.value())
                + "}]"
            )
        return out + "}"

    def response_for_operation(
        mut self, mut ctx: GraphQLRequestContext
    ) raises -> Bool:
        """Handle a subscription operation that has a `subscription`
        callback extension.

        Args:
            ctx: The request context.

        Returns:
            True when the operation is a callback subscription and its
            response is set; False otherwise.

        Raises:
            Error: When subscription setup fails unexpectedly.
        """
        if not ctx.document or ctx.operation == NO_NODE:
            return False
        ref doc = ctx.document.value()[]
        if doc.operation(ctx.operation) != OperationType.SUBSCRIPTION:
            return False
        if ctx.request.extensions == NO_JSON:
            return False
        ref json = ctx.request.json
        var sub_ext = json.find(ctx.request.extensions, "subscription")
        if sub_ext == NO_JSON or json.kind(sub_ext) != JsonKind.OBJECT:
            return False
        var url_node = json.find(sub_ext, "callbackUrl")
        var id_node = json.find(sub_ext, "subscriptionId")
        if (
            url_node == NO_JSON
            or json.kind(url_node) != JsonKind.STRING
            or id_node == NO_JSON
            or json.kind(id_node) != JsonKind.STRING
        ):
            return False
        var callback_url = json.string_value(url_node)
        var subscription_id = json.string_value(id_node)
        var verifier = String("")
        var ver_node = json.find(sub_ext, "verifier")
        if ver_node != NO_JSON and json.kind(ver_node) == JsonKind.STRING:
            verifier = json.string_value(ver_node)
        var hb_ms = self.options.heartbeat_interval_ms
        var hb_node = json.find(sub_ext, "heartbeatIntervalMs")
        if hb_node != NO_JSON and json.kind(hb_node) == JsonKind.NUMBER:
            var parsed_hb = Int(json.as_float64(hb_node))
            if parsed_hb >= 0:
                hb_ms = parsed_hb

        var args = ExecutionArgs()
        args.assume_valid_schema = True
        args.context_value = args.values.copy(ctx.context_value)
        args.operation_name = ctx.request.operation_name
        if ctx.request.variables != NO_JSON:
            args.variable_values = args.values.add_json(
                json, ctx.request.variables
            )
        args.resolvers = self.resolvers[].copy()
        var sub = subscribe(self.schema, ctx.document.value(), args^)
        if not sub.is_stream():
            var result = sub.result.take()
            ctx.response.has_errors = True
            ctx.response.data = JsonDocument()
            for ref err in result.errors:
                var fmt = FormattedError(err.message)
                fmt.locations = err.locations.copy()
                fmt.path = err.path.copy()
                fmt.set_extension("code", '"INTERNAL_SERVER_ERROR"')
                ctx.response.errors.append(fmt^)
            ctx.response.http.headers.set(
                "content-type", APPLICATION_JSON_GRAPHQL_CALLBACK
            )
            return True
        var status = self._post_callback(
            callback_url.copy(), self._check_body(subscription_id, verifier)
        )
        if status < 200 or status >= 300:
            ctx.response.http.status = 500
            ctx.response.has_errors = True
            var fmt = FormattedError(
                "Subscription check failed with status " + String(status)
            )
            fmt.set_extension(
                "code", '"' + String(SUBSCRIPTION_HANDSHAKE_FAILED) + '"'
            )
            ctx.response.errors.append(fmt^)
            ctx.response.data = JsonDocument()
            ctx.response.http.headers.set(
                "content-type", APPLICATION_JSON_GRAPHQL_CALLBACK
            )
            return True
        var stream = sub.take_stream()
        self.active.append(
            _ActiveSubscription(
                subscription_id^,
                callback_url^,
                verifier^,
                hb_ms,
                _now_ms(),
                stream^,
            )
        )
        var data = JsonDocument()
        data.root = data.add_null()
        ctx.response.data = data^
        ctx.response.http.headers.set(
            "content-type", APPLICATION_JSON_GRAPHQL_CALLBACK
        )
        return True

    def poll(mut self) raises -> Int:
        """Poll active subscriptions, send ready `next` or `complete`
        callbacks, and send `check` heartbeats when due.

        Returns:
            The number of callback HTTP requests sent in this turn.

        Raises:
            Error: When polling a stream fails unexpectedly.
        """
        if self.stopped:
            return 0
        var sent = 0
        var waker = Waker.noop()
        var index = 0
        while index < len(self.active):
            var remove = False
            while True:
                var polled = self.active[index].stream.poll_next(waker)
                if polled.state == PollState.PENDING:
                    break
                if polled.state == PollState.READY:
                    var url = self.active[index].callback_url.copy()
                    var body = self._next_body(
                        self.active[index].id,
                        self.active[index].verifier,
                        polled.event.value().to_json(),
                    )
                    var status = self._post_callback(url^, body^)
                    sent += 1
                    self.active[index].last_check_ms = _now_ms()
                    if status < 200 or status >= 300:
                        remove = True
                        break
                elif polled.state == PollState.DONE:
                    var url = self.active[index].callback_url.copy()
                    var body = self._complete_body(
                        self.active[index].id,
                        self.active[index].verifier,
                        None,
                    )
                    _ = self._post_callback(url^, body^)
                    sent += 1
                    remove = True
                    break
                else:
                    var url = self.active[index].callback_url.copy()
                    var body = self._complete_body(
                        self.active[index].id,
                        self.active[index].verifier,
                        polled.message,
                    )
                    _ = self._post_callback(url^, body^)
                    sent += 1
                    remove = True
                    break
            if not remove:
                var now = _now_ms()
                var hb = self.active[index].heartbeat_interval_ms
                if hb > 0 and now - self.active[index].last_check_ms >= hb:
                    var url = self.active[index].callback_url.copy()
                    var body = self._check_body(
                        self.active[index].id,
                        self.active[index].verifier,
                    )
                    var status = self._post_callback(url^, body^)
                    sent += 1
                    self.active[index].last_check_ms = now
                    if status < 200 or status >= 300:
                        remove = True
            if remove:
                _ = self.active.pop(index)
            else:
                index += 1
        return sent

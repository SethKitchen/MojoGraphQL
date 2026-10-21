# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The router pipeline: from a GraphQL request to a response body.

Port of `execute_pipeline` of Hive Router `1a29df9`
`bin/router/src/pipeline/mod.rs`, with the steps of `parser.rs`,
`normalize.rs`, `coerce_variables.rs`, `query_plan.rs` and
`execution.rs`, the validation step of `validation/mod.rs`, and the error
responses of `error.rs`.

`RouterSchema` reads a supergraph once: the planner, the consumer schema,
its metadata, the validation schema and the entity keys. `Router.execute`
parses the operation, validates it, normalizes it, splits off the
introspection part, coerces the variables,
plans the downstream part, resolves the introspection part, runs the plan
and projects the response. The normalized operation, its projection plan
and its query plan are kept in an operation cache, by operation name and
document. A second cache keeps the validation result of each document
text, as upstream `validate_cache`.

**Differences from upstream.** Upstream keeps separate caches for
parsing, normalization and query plans. This port keeps one cache with the
three results, keyed by the operation name and the document text.
`gql_router.validation` gives the differences of the validation step.
There are no plugins,
coprocessors, persisted documents, authorization, progressive override
labels, demand control, CSRF prevention, or subscriptions. A parse error
message is the `gql_language` text.
"""

from std.time import perf_counter_ns

from gql_json.value import NO_NODE, JsonDocument
from gql_language.ast import Document
from gql_language.parser import parse
from gql_router.ast import NONE
from gql_router.cache import CacheLimits, OperationCache, default_cache_limits
from gql_router.consumer_schema import ConsumerSchema
from gql_router.entity_keys import EntityKeys
from gql_router.exec_http import SubgraphTransport
from gql_router.exec_introspection import resolve_introspection
from gql_router.exec_partition import partition_operation
from gql_router.exec_plan import (
    Executor,
    PlanExecutionOutput,
    subscription_node,
    subscription_request_body,
)
from gql_router.exec_projection_plan import ProjectionPlan
from gql_router.exec_variables import CoerceVariablesPayload, collect_variables
from gql_router.federation_spec import OperationKind
from gql_router.graphql_error import GraphQLError, error_json, error_with_code
from gql_router.normalize import normalize_operation
from gql_router.operation import OperationDefinition
from gql_router.plan_nodes import QueryPlan
from gql_router.planner import Planner
from gql_router.schema_metadata import SchemaMetadata, schema_metadata
from gql_router.validation import (
    default_rules_validation_plan,
    errors_json,
    validate_operation,
    validation_schema,
)
from gql_schema.definition import Schema
from gql_validation.rules import ValidationRule


@fieldwise_init
struct PipelineErrorKind(Equatable, ImplicitlyCopyable, Movable):
    """The kind of a request error, as upstream `ClientPipelineError` and
    `InternalPipelineError`."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime CLIENT = PipelineErrorKind(0)
    """A client error with a fixed status."""
    comptime CLIENT_PREFER_OK = PipelineErrorKind(1)
    """A client error whose status is 200 for `application/json`."""
    comptime INTERNAL = PipelineErrorKind(2)
    """An internal error: the client sees `Internal server error`."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the three kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 2


@fieldwise_init
struct PipelineError(Copyable, Movable, Writable):
    """A request error, as upstream `PipelineError`."""

    var kind: PipelineErrorKind
    """How the client sees the error."""
    var message: String
    """The message."""
    var code: String
    """The GraphQL error code, as upstream `graphql_error_code`."""
    var status: Int
    """The HTTP status when the status is not 200."""
    var validation_body: String
    """The body of a validation failure, as upstream `ValidationErrors`;
    empty for every other error."""

    def client_message(self) -> String:
        """Return the message the client sees, as upstream
        `graphql_error_message`.

        Returns:
            The message, or `Internal server error` for an internal error.
        """
        if self.kind == PipelineErrorKind.INTERNAL:
            return String("Internal server error")
        return self.message

    def status_code(self, prefer_ok: Bool) -> Int:
        """Return the HTTP status, as upstream `default_status_code`.

        Args:
            prefer_ok: Whether the response type is `application/json`.

        Returns:
            200 when the kind prefers it and `prefer_ok` is set; otherwise
            the status of the error.
        """
        if prefer_ok and self.kind != PipelineErrorKind.CLIENT:
            return 200
        return self.status

    def body(self) -> String:
        """Return the response body, as upstream `FailedExecutionResult`.

        Returns:
            `{"errors":[{"message":...,"extensions":{"code":...}}]}`, or
            each validation error.
        """
        if self.validation_body.byte_length() > 0:
            return self.validation_body
        return (
            '{"errors":['
            + error_json(error_with_code(self.client_message(), self.code))
            + "]}"
        )

    def write_to(self, mut writer: Some[Writer]):
        """Write the code and the message.

        Args:
            writer: The destination.
        """
        writer.write(self.code, ": ", self.message)


def client_error(
    message: String, code: String, status: Int = 400
) -> PipelineError:
    """Make a client error with a fixed status.

    Args:
        message: The message.
        code: The error code.
        status: The HTTP status.

    Returns:
        The error.
    """
    return PipelineError(
        PipelineErrorKind.CLIENT, message, code, status, String()
    )


def validation_error(body: String) -> PipelineError:
    """Make the error of a failed validation, as upstream
    `ClientPipelineError::ValidationErrors`.

    Args:
        body: The response body, from `errors_json`.

    Returns:
        The error, with the code `GRAPHQL_VALIDATION_FAILED`; status 400,
        or 200 for `application/json`.
    """
    return PipelineError(
        PipelineErrorKind.CLIENT_PREFER_OK,
        "Validation errors",
        "GRAPHQL_VALIDATION_FAILED",
        400,
        body,
    )


def client_error_prefer_ok(message: String, code: String) -> PipelineError:
    """Make a client error whose status is 200 for `application/json`.

    Args:
        message: The message.
        code: The error code.

    Returns:
        The error, with status 400 otherwise.
    """
    return PipelineError(
        PipelineErrorKind.CLIENT_PREFER_OK, message, code, 400, String()
    )


def internal_error(message: String, code: String) -> PipelineError:
    """Make an internal error.

    Args:
        message: The message, for logs only.
        code: The error code.

    Returns:
        The error, with status 500.
    """
    return PipelineError(
        PipelineErrorKind.INTERNAL, message, code, 500, String()
    )


struct RouterSchema(Movable):
    """A supergraph, read once, as upstream `SupergraphSnapshot`."""

    var planner: Planner
    """The query planner and its store."""
    var consumer: ConsumerSchema
    """The schema that clients see."""
    var metadata: SchemaMetadata
    """The metadata of the consumer schema."""
    var keys: EntityKeys
    """The entity keys of each subgraph."""
    var validation: Schema
    """The consumer schema that operations are validated against."""
    var rules: List[ValidationRule]
    """The validation rules, as upstream `validation_plan`."""
    var subgraph_names: List[String]
    """The subgraph names, sorted."""
    var subgraph_urls: List[String]
    """The URL of each subgraph, parallel to `subgraph_names`."""

    def __init__(out self, sdl: String) raises:
        """Read a supergraph SDL.

        Args:
            sdl: The supergraph SDL.

        Raises:
            Error: When the SDL does not parse or plan.
        """
        self.planner = Planner(sdl)
        var supergraph = parse(sdl)
        self.consumer = ConsumerSchema.new_from_supergraph(supergraph)
        self.validation = validation_schema(supergraph)
        self.rules = default_rules_validation_plan()
        self.metadata = schema_metadata(self.consumer.document)
        self.keys = EntityKeys.new(self.planner.store, self.planner.state)
        self.subgraph_names = List[String]()
        self.subgraph_urls = List[String]()
        var index = 0
        while index < len(self.planner.state.subgraph_names):
            var name = self.planner.state.subgraph_names[index]
            self.subgraph_names.append(String(self.planner.store.name(name)))
            var url = self.planner.state.subgraph_endpoints.get(name)
            self.subgraph_urls.append(url.value() if url else String())
            index += 1


struct CachedOperation(Movable):
    """The normalized operation and its plans, as upstream
    `GraphQLNormalizationPayload` with its query plan."""

    var downstream: OperationDefinition
    """The part of the operation that the subgraphs resolve."""
    var introspection: OperationDefinition
    """The introspection part."""
    var has_introspection: Bool
    """Whether there is an introspection part."""
    var root_type_name: String
    """The root type of the operation."""
    var projection: ProjectionPlan
    """The projection plan of the whole operation."""
    var plan: QueryPlan
    """The executable query plan of the downstream part."""
    var planned: Bool
    """Whether `plan` is built; it is built after the first coercion of
    the variables, as upstream plans after coercion."""

    def __init__(
        out self,
        var downstream: OperationDefinition,
        var introspection: OperationDefinition,
        has_introspection: Bool,
        var root_type_name: String,
        var projection: ProjectionPlan,
    ):
        """Hold the results of normalizing an operation.

        Args:
            downstream: The downstream part.
            introspection: The introspection part.
            has_introspection: Whether there is an introspection part.
            root_type_name: The root type.
            projection: The projection plan.
        """
        self.downstream = downstream^
        self.introspection = introspection^
        self.has_introspection = has_introspection
        self.root_type_name = root_type_name^
        self.projection = projection^
        self.plan = QueryPlan()
        self.planned = False


struct RouterResponse(Movable):
    """The HTTP status and body of one request."""

    var status: Int
    """The HTTP status code."""
    var body: List[UInt8]
    """The JSON body."""

    def __init__(out self, status: Int, var body: List[UInt8]):
        """Wrap a status and a body.

        Args:
            status: The HTTP status code.
            body: The JSON body.
        """
        self.status = status
        self.body = body^

    def take_body(deinit self) -> List[UInt8]:
        """Return the body.

        Returns:
            The JSON body.
        """
        return self.body^

    @staticmethod
    def from_error(error: PipelineError, prefer_ok: Bool) -> RouterResponse:
        """Make the response of a request error, as upstream
        `handle_pipeline_error`.

        Args:
            error: The error.
            prefer_ok: Whether the response type is `application/json`.

        Returns:
            The error response.
        """
        return RouterResponse(
            error.status_code(prefer_ok), List[UInt8](error.body().as_bytes())
        )


struct PreparedRequest(Movable):
    """A request after its parse, validation, normalization, variable
    coercion and plan: what `Router.run_prepared` and the subscription
    calls take."""

    var slot: Int
    """The slot of the cached operation."""
    var kind: OperationKind
    """The kind of the operation."""
    var variables: CoerceVariablesPayload
    """The coerced variables."""

    def __init__(
        out self,
        slot: Int,
        kind: OperationKind,
        var variables: CoerceVariablesPayload,
    ):
        """Wrap a prepared request.

        Args:
            slot: The slot of the cached operation.
            kind: The kind of the operation.
            variables: The coerced variables.
        """
        self.slot = slot
        self.kind = kind
        self.variables = variables^

    def is_subscription(self) -> Bool:
        """Tell if the operation is a subscription.

        Returns:
            True for a subscription.
        """
        return self.kind == OperationKind.SUBSCRIPTION


struct SubscriptionStart(Movable):
    """The subgraph request that opens a subscription, as the
    `SubgraphExecutionRequest` of upstream `execute_query_plan`."""

    var subgraph: String
    """The subgraph of the subscription fetch."""
    var body: List[UInt8]
    """The JSON body of the request."""

    def __init__(out self, var subgraph: String, var body: List[UInt8]):
        """Wrap a subscription request.

        Args:
            subgraph: The subgraph name.
            body: The JSON body.
        """
        self.subgraph = subgraph^
        self.body = body^


def failure_body(message: String, code: String) -> List[UInt8]:
    """Write the body of a failed event, as upstream
    `FailedExecutionResult`.

    Args:
        message: The message.
        code: The error code.

    Returns:
        `{"errors":[{"message":...,"extensions":{"code":...}}]}`.
    """
    var text = '{"errors":[' + error_json(error_with_code(message, code)) + "]}"
    return List[UInt8](text.as_bytes())


def _now_ms() -> Int:
    """Return a monotonic time in milliseconds."""
    return Int(perf_counter_ns() // 1_000_000)


struct Router[T: SubgraphTransport](Movable):
    """The router: a supergraph, an executor and an operation cache.

    Parameters:
        T: The transport to the subgraphs.
    """

    var schema: RouterSchema
    """The supergraph."""
    var executor: Executor[Self.T]
    """The executor and its transport."""
    var cache: OperationCache
    """The slot of each cached operation, by name and document."""
    var slots: List[CachedOperation]
    """The cached operations."""
    var slot_keys: List[String]
    """The cache key of each slot."""
    var validated: OperationCache
    """The validation result of each document text, as upstream
    `validate_cache`: empty for a valid document, else the error body."""
    var pins: List[Int]
    """How many open subscriptions use each slot. A pinned slot is not
    reused, even when its operation leaves the cache."""

    def __init__(
        out self,
        var schema: RouterSchema,
        var transport: Self.T,
        limits: CacheLimits = default_cache_limits(),
    ):
        """Make a router.

        Args:
            schema: The supergraph.
            transport: The transport to the subgraphs.
            limits: The limits of the operation cache.
        """
        self.schema = schema^
        self.executor = Executor[Self.T](transport^)
        self.cache = OperationCache(limits)
        self.slots = List[CachedOperation]()
        self.slot_keys = List[String]()
        self.validated = OperationCache(limits)
        self.pins = List[Int]()

    def pin(mut self, slot: Int):
        """Keep a slot for an open subscription.

        Args:
            slot: The slot.
        """
        self.pins[slot] += 1

    def unpin(mut self, slot: Int):
        """Release a slot that `pin` keeps.

        Args:
            slot: The slot.
        """
        self.pins[slot] -= 1

    def validate(
        mut self, query: String, document: Document, now: Int
    ) raises PipelineError:
        """Validate a parsed document, or find its result in the cache, as
        upstream `validate_operation_with_cache`.

        Args:
            query: The document text: the cache key.
            document: The parsed document.
            now: The time in milliseconds.

        Raises:
            PipelineError: `GRAPHQL_VALIDATION_FAILED`, with each error.
        """
        var body: String
        var cached = self.validated.get(query, now)
        if cached:
            body = cached.value()
        else:
            var errors: List[GraphQLError]
            try:
                errors = validate_operation(
                    self.schema.validation, document, self.schema.rules
                )
            except e:
                raise client_error(String(e), "GRAPHQL_VALIDATION_FAILED")
            body = errors_json(errors) if len(errors) > 0 else String()
            self.validated.insert(query, body, now)
        if body.byte_length() > 0:
            raise validation_error(body)

    def prepare(
        mut self,
        query: String,
        operation_name: Optional[String],
        validate: Bool = True,
    ) raises PipelineError -> Int:
        """Parse, normalize and partition an operation, or find it in the
        cache, as upstream `parse_operation_with_cache` and
        `normalize_request_with_cache`.

        Args:
            query: The operation document.
            operation_name: The operation to run.
            validate: False for a document derived from a valid one, such
                as the primary part of an operation with `@defer`.

        Returns:
            The slot of the operation.

        Raises:
            PipelineError: When the document does not parse or normalize.
        """
        var key = (
            (operation_name.value() if operation_name else String())
            + "\n"
            + query
        )
        var now = _now_ms()
        if self.cache.get(key, now):
            var found = 0
            while self.slot_keys[found] != key:
                found += 1
            return found
        var document: Document
        try:
            document = parse(query)
        except e:
            raise client_error_prefer_ok(
                "Failed to parse GraphQL operation: " + String(e),
                "GRAPHQL_PARSE_FAILED",
            )
        if validate:
            self.validate(query, document, now)
        var operation: OperationDefinition
        try:
            operation = normalize_operation(
                self.schema.planner.store,
                self.schema.planner.state,
                document,
                operation_name,
            )
        except:
            raise client_error(
                "Failed to normalize GraphQL operation",
                "OPERATION_RESOLUTION_FAILURE",
            )
        var built = ProjectionPlan.from_operation(
            self.schema.planner.store, operation, self.schema.metadata
        )
        var parts = partition_operation(self.schema.planner.store, operation)
        var cached = CachedOperation(
            parts.downstream_operation.copy(),
            parts.introspection_operation.copy(),
            parts.has_introspection,
            built[0],
            built[1].copy(),
        )
        var slot = self._free_slot(now)
        if slot == len(self.slots):
            self.slots.append(cached^)
            self.slot_keys.append(key)
            self.pins.append(0)
        else:
            self.slots[slot] = cached^
            self.slot_keys[slot] = key
        self.cache.insert(key, String(), now)
        return slot

    def _free_slot(mut self, now: Int) -> Int:
        """Return a slot whose operation left the cache, or a new slot."""
        var index = 0
        while index < len(self.slot_keys):
            if self.pins[index] == 0 and not self.cache.get(
                self.slot_keys[index], now
            ):
                return index
            index += 1
        return len(self.slots)

    def execute(
        mut self,
        query: String,
        operation_name: Optional[String],
        var variables: JsonDocument,
        variables_root: Int,
        is_get: Bool,
        prefer_ok: Bool,
    ) -> RouterResponse:
        """Run one GraphQL request, as upstream `execute_pipeline`.

        Args:
            query: The operation document.
            operation_name: The operation to run.
            variables: The parsed `variables` of the request.
            variables_root: The variables object, or `NO_NODE`.
            is_get: Whether the request is a `GET`.
            prefer_ok: Whether the response type is `application/json`.

        Returns:
            The status and the body.
        """
        try:
            return self._execute(
                query, operation_name, variables^, variables_root, is_get
            )
        except error:
            return RouterResponse.from_error(error, prefer_ok)

    def _execute(
        mut self,
        query: String,
        operation_name: Optional[String],
        var variables: JsonDocument,
        variables_root: Int,
        is_get: Bool,
    ) raises PipelineError -> RouterResponse:
        """Run one request; raise its pipeline error."""
        var prepared = self.prepare_request(
            query, operation_name, variables^, variables_root, is_get, False
        )
        return self.run_prepared(prepared)

    def prepare_request(
        mut self,
        query: String,
        operation_name: Optional[String],
        var variables: JsonDocument,
        variables_root: Int,
        is_get: Bool,
        subscriptions: Bool,
    ) raises PipelineError -> PreparedRequest:
        """Run the steps of a request before its execution: parse,
        validate, normalize, coerce the variables, and plan.

        Args:
            query: The operation document.
            operation_name: The operation to run.
            variables: The parsed `variables` of the request.
            variables_root: The variables object, or `NO_NODE`.
            is_get: Whether the request is a `GET`.
            subscriptions: Whether the caller can stream a subscription.

        Returns:
            The prepared request.

        Raises:
            PipelineError: As upstream: `SUBSCRIPTIONS_NOT_SUPPORTED` (415)
                for a subscription that the caller cannot stream, and the
                errors of each step.
        """
        var slot = self.prepare(query, operation_name)
        var kind = self.slots[slot].downstream.kind
        if kind == OperationKind.SUBSCRIPTION and not subscriptions:
            raise client_error(
                "Subscriptions are not supported",
                "SUBSCRIPTIONS_NOT_SUPPORTED",
                415,
            )
        if kind == OperationKind.MUTATION and is_get:
            raise client_error(
                "Cannot perform mutations over GET",
                "MUTATION_NOT_ALLOWED_OVER_HTTP_GET",
                405,
            )
        var coerced: CoerceVariablesPayload
        try:
            coerced = collect_variables(
                self.schema.planner.store,
                self.slots[slot].downstream,
                variables^,
                variables_root,
                self.schema.metadata,
            )
        except error:
            raise client_error_prefer_ok(String(error), "BAD_USER_INPUT")
        self._plan(slot)
        return PreparedRequest(slot, kind, coerced^)

    def prepare_coerced(
        mut self,
        query: String,
        operation_name: Optional[String],
        variables: CoerceVariablesPayload,
        validate: Bool = True,
    ) raises PipelineError -> PreparedRequest:
        """Prepare a second document of a request with the variables that
        `prepare_request` coerced, such as the parts of an operation with
        `@defer`. Its variable definitions must be the same.

        Args:
            query: The operation document.
            operation_name: The operation to run.
            variables: The coerced variables of the first document.
            validate: False for a document derived from a valid one.

        Returns:
            The prepared request.

        Raises:
            PipelineError: The errors of the parse, the validation, the
                normalization and the plan.
        """
        var slot = self.prepare(query, operation_name, validate)
        var kind = self.slots[slot].downstream.kind
        self._plan(slot)
        return PreparedRequest(slot, kind, variables.copy())

    def _plan(mut self, slot: Int) raises PipelineError:
        """Plan the operation of a slot once."""
        var downstream_set = self.slots[slot].downstream.selection_set
        var empty = (
            self.schema.planner.store.items[downstream_set].first == NONE
        )
        if not self.slots[slot].planned and empty:
            # Nothing to plan, as upstream `EMPTY_QUERY_PLAN`.
            self.slots[slot].planned = True
        if not self.slots[slot].planned:
            var downstream = self.slots[slot].downstream.copy()
            try:
                var plan = self.schema.planner.plan(downstream)
                self.slots[slot].plan = plan^.into_executable()
            except error:
                raise internal_error(
                    "Failed to produce a plan: " + String(error),
                    "QUERY_PLAN_BUILD_FAILED",
                )
            self.slots[slot].planned = True

    def run_prepared(
        mut self, prepared: PreparedRequest
    ) raises PipelineError -> RouterResponse:
        """Execute a prepared query or mutation and project its response.

        Args:
            prepared: The request from `prepare_request`.

        Returns:
            The status and the body.

        Raises:
            PipelineError: `PLAN_EXECUTION_FAILED` when the plan fails.
        """
        var slot = prepared.slot
        var arena = JsonDocument()
        var data = NO_NODE
        if self.slots[slot].has_introspection:
            data = resolve_introspection(
                self.schema.planner.store,
                self.slots[slot].introspection,
                self.schema.consumer.document,
                self.schema.metadata,
                prepared.variables,
                arena,
            )
        try:
            var output = self.executor.execute(
                self.schema.planner.store,
                self.slots[slot].plan,
                self.schema.metadata,
                self.schema.keys,
                prepared.variables,
                self.slots[slot].projection,
                self.slots[slot].root_type_name,
                arena^,
                data,
                List[GraphQLError](),
            )
            var status = output.status_code
            return RouterResponse(status, output^.take_body())
        except error:
            raise internal_error(
                "Failed to execute a plan: " + String(error),
                "PLAN_EXECUTION_FAILED",
            )

    def subscription_start(
        mut self, prepared: PreparedRequest
    ) raises PipelineError -> SubscriptionStart:
        """Return the subgraph request that opens a prepared subscription.

        Args:
            prepared: A subscription from `prepare_request`.

        Returns:
            The subgraph and the body of the subscription fetch.

        Raises:
            PipelineError: `PLAN_EXECUTION_FAILED` when the plan has no
                `Subscription` node.
        """
        ref plan = self.slots[prepared.slot].plan
        var node = subscription_node(plan)
        if node == NONE:
            raise internal_error(
                "The plan of a subscription has no Subscription node",
                "PLAN_EXECUTION_FAILED",
            )
        ref store = self.schema.planner.store
        var service = plan.fetches[plan.nodes[node].fetch].service_name
        return SubscriptionStart(
            String(store.name(service)),
            subscription_request_body(store, plan, node, prepared.variables),
        )

    def subscription_event(
        mut self,
        slot: Int,
        variables: CoerceVariablesPayload,
        var body: List[UInt8],
    ) raises -> List[UInt8]:
        """Run the rest of a subscription plan for one event.

        Args:
            slot: The slot of the subscription; `pin` keeps it.
            variables: The coerced variables of the subscription.
            body: The JSON of the subgraph event.

        Returns:
            The response body of the event.

        Raises:
            Error: When the event is not a GraphQL response, or when the
                execution fails.
        """
        var output = self.executor.execute_event(
            self.schema.planner.store,
            self.slots[slot].plan,
            self.schema.metadata,
            self.schema.keys,
            variables,
            self.slots[slot].projection,
            self.slots[slot].root_type_name,
            body^,
        )
        return output^.take_body()

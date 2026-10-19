# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Run a query plan against the subgraphs.

Port of `execute_query_plan`, `Executor` and `ExecutionJob` of Hive Router
`1a29df9` `bin/router/src/executor/execution/plan.rs`, and of
`ExecutionContext::handle_errors` of `executor/execution_context.rs`.

A `Sequence` runs its children in order. A `Parallel` node prepares every
child from the same data first. Then it starts every request, so they are
in flight at the same time, and then it reads and merges each response. A
`Condition` runs its `if` branch when the variable is `true`, and its
`else` branch otherwise; without the variable it runs nothing. A `Fetch`
merges its data at the root. A `Flatten` over a fetch with `requires` sends
the entity representations found at its path as `$representations`, and
merges each returned entity back into the place it came from. A `Flatten`
over a fetch without `requires` is a root re-entry: its data merges into
each value at the path. A `BatchFetch` sends the representations of each
alias, and merges each alias's entities back at every path of the alias.

A failed fetch adds one error and the rest of the plan still runs. The
errors of a subgraph get its name, the affected path, and the response
path of each entity. The final response is the projection of the merged
data by the client operation.

**Differences from upstream.** Upstream merges each child of a `Parallel`
node as its response arrives. This port reads and merges the responses in
plan order, so the errors are in plan order. The requests are still in
flight at the same time: with `HttpTransport`, the slowest subgraph sets
the time of the node, as upstream.
Upstream walks the path of a flatten fetch again to merge; this port keeps
the values that the prepare step found, and walks again only to get the
error paths. Subscriptions are not supported: a plan with a `Subscription` node raises
`Error`. There are no plugins, header rules, coprocessors, demand control,
extensions or error masking. The operation name is never forwarded.
"""

from gql_json.value import NO_NODE, JsonDocument, JsonKind
from gql_router.ast import NONE
from gql_router.entity_keys import EntityKeys, KeysByType
from gql_router.exec_http import (
    SubgraphFailure,
    SubgraphHttpResponse,
    SubgraphTransport,
    build_request_body,
    is_valid_graphql_content_type,
)
from gql_router.exec_projection import project_by_operation
from gql_router.exec_projection_plan import ProjectionPlan
from gql_router.exec_requires import project_requires, requires_hash
from gql_router.exec_rewrites import apply_rewrite
from gql_router.exec_subgraph_response import (
    SubgraphResponse,
    read_subgraph_response,
)
from gql_router.exec_traverse import TraverseTargets, traverse
from gql_router.exec_value import copy_value, deep_merge, take_member
from gql_router.exec_variables import CoerceVariablesPayload
from gql_router.fetch_step import FetchRewrite
from gql_router.graphql_error import (
    ErrorPath,
    ErrorSegmentKind,
    GraphQLError,
    add_affected_path,
    add_subgraph_name,
    error_with_code,
    handle_subgraph_errors,
    http_status_error,
)
from gql_router.plan_nodes import FlattenNodePath, PlanNodeKind, QueryPlan
from gql_router.schema_metadata import SchemaMetadata
from gql_router.store import Store


@fieldwise_init
struct JobKind(Equatable, ImplicitlyCopyable, Movable):
    """The kind of a fetch job, as upstream `ExecutionJob`."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime NONE = JobKind(0)
    """Nothing to fetch."""
    comptime FETCH = JobKind(1)
    """A fetch that merges at the root, or at a re-entry path."""
    comptime FLATTEN_FETCH = JobKind(2)
    """An `_entities` fetch under a flatten node."""
    comptime BATCH_FETCH = JobKind(3)
    """A batch of `_entities` fetches to one subgraph."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the four kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 3


struct AliasState(Copyable, Movable):
    """The representations of one batch alias, as upstream
    `AliasBatchState`."""

    var alias: Int
    """The index of the alias in its batch."""
    var path_entities: List[List[Int]]
    """For each merge path, the entity index of each value it reaches, or
    -1 when the value sends no representation."""
    var path_targets: List[List[Int]]
    """For each merge path, the values it reaches when it was prepared."""
    var count: Int
    """How many representations the alias sends."""

    def __init__(out self, alias: Int):
        """Start an alias with no representations.

        Args:
            alias: The index of the alias in its batch.
        """
        self.alias = alias
        self.path_entities = List[List[Int]]()
        self.path_targets = List[List[Int]]()
        self.count = 0


struct Job(Movable):
    """One prepared subgraph request."""

    var kind: JobKind
    """What the job merges."""
    var subgraph: String
    """The subgraph name."""
    var plan_node: Int
    """The plan node: the fetch, the flatten or the batch fetch."""
    var fetch: Int
    """The index in `QueryPlan.fetches`, or in `batches` for a batch."""
    var body: List[UInt8]
    """The request body."""
    var has_merge_path: Bool
    """Whether the job merges at the path of its flatten node."""
    var entities: List[Int]
    """For a flatten fetch, the entity index of each value at the path, or
    -1."""
    var targets: List[Int]
    """For a flatten fetch, the values at the path when it was prepared."""
    var aliases: List[AliasState]
    """For a batch fetch, the state of each alias."""

    def __init__(
        out self, kind: JobKind, subgraph: String, plan_node: Int, fetch: Int
    ):
        """Start a job with an empty body.

        Args:
            kind: The kind.
            subgraph: The subgraph name.
            plan_node: The plan node.
            fetch: The fetch index.
        """
        self.kind = kind
        self.subgraph = subgraph
        self.plan_node = plan_node
        self.fetch = fetch
        self.body = List[UInt8]()
        self.has_merge_path = False
        self.entities = List[Int]()
        self.targets = List[Int]()
        self.aliases = List[AliasState]()


struct PlanExecutionOutput(Movable):
    """The response of a plan, as upstream `PlanExecutionOutput`."""

    var body: List[UInt8]
    """The response body."""
    var error_count: Int
    """How many errors the response has."""
    var status_code: Int
    """The HTTP status code."""

    def __init__(out self, var body: List[UInt8], error_count: Int):
        """Wrap a response body with status 200.

        Args:
            body: The body.
            error_count: The number of errors.
        """
        self.body = body^
        self.error_count = error_count
        self.status_code = 200

    def take_body(deinit self) -> List[UInt8]:
        """Return the response body.

        Returns:
            The body.
        """
        return self.body^


struct ExecutionContext(Movable):
    """The data and errors of one execution, as upstream
    `ExecutionContext`."""

    var arena: JsonDocument
    """Every value of the request."""
    var data: Int
    """The data object."""
    var errors: List[GraphQLError]
    """The errors so far."""
    var response_bytes: Int
    """The size of every subgraph response, for the size estimate."""

    def __init__(
        out self,
        var arena: JsonDocument,
        data: Int,
        var errors: List[GraphQLError],
    ):
        """Start an execution.

        Args:
            arena: The arena; `data` is one of its nodes.
            data: The data object.
            errors: The initial errors.
        """
        self.arena = arena^
        self.data = data
        self.errors = errors^
        self.response_bytes = 0

    def handle_errors(
        mut self,
        subgraph: String,
        affected_path: String,
        has_affected_path: Bool,
        var errors: List[GraphQLError],
        has_entities: Bool,
        indexes: List[Int],
        paths: List[ErrorPath],
    ):
        """Add the errors of a subgraph, as upstream `handle_errors`.

        Args:
            subgraph: The subgraph name.
            affected_path: The path of the flatten node.
            has_affected_path: Whether there is an affected path.
            errors: The subgraph errors.
            has_entities: Whether `_entities` errors move to entity paths.
            indexes: The entity index of each path in `paths`.
            paths: The response path of each entity.
        """
        handle_subgraph_errors(
            self.errors,
            subgraph,
            has_affected_path,
            affected_path,
            errors^,
            has_entities,
            indexes,
            paths,
        )


def plan_error(
    message: String, code: String, subgraph: String, affected_path: String
) -> GraphQLError:
    """Make the error of a failed fetch, as upstream
    `From<&PlanExecutionError> for GraphQLError`.

    Args:
        message: The message.
        code: The error code.
        subgraph: The subgraph name.
        affected_path: The flatten path, or empty.

    Returns:
        The error with its code, service and affected path.
    """
    var error = error_with_code(message, code)
    add_subgraph_name(error, subgraph)
    if affected_path.byte_length() > 0:
        add_affected_path(error, affected_path)
    return error^


def failure_error(
    response: SubgraphHttpResponse, subgraph: String, affected_path: String
) -> GraphQLError:
    """Make the error of a request that has no response.

    Args:
        response: The failed result.
        subgraph: The subgraph name.
        affected_path: The flatten path, or empty.

    Returns:
        The error, with the upstream message and code of the failure.
    """
    var failure = response.failure
    if failure == SubgraphFailure.REQUEST_TIMEOUT:
        return plan_error(
            "Request to subgraph timed out",
            "SUBGRAPH_REQUEST_TIMEOUT",
            subgraph,
            affected_path,
        )
    if failure == SubgraphFailure.RESPONSE_FAILURE:
        return plan_error(
            "Failed to receive response: " + response.failure_text,
            "SUBGRAPH_RESPONSE_FAILURE",
            subgraph,
            affected_path,
        )
    if failure == SubgraphFailure.UNKNOWN_SUBGRAPH:
        return plan_error(
            response.failure_text,
            "SUBGRAPH_STATIC_ENDPOINT_NOT_FOUND",
            subgraph,
            affected_path,
        )
    return plan_error(
        "Failed to send request to subgraph: " + response.failure_text,
        "SUBREQUEST_HTTP_ERROR",
        subgraph,
        affected_path,
    )


def select_fetch_variables(
    store: Store,
    usages: List[Int],
    has_usages: Bool,
    variables: CoerceVariablesPayload,
    mut names: List[String],
    mut nodes: List[Int],
) -> Bool:
    """Pick the variables that a fetch uses, as upstream
    `select_fetch_variables`.

    Args:
        store: The store with the variable names.
        usages: The variables the fetch uses, as symbols.
        has_usages: False when upstream `variable_usages` is `None`.
        variables: The coerced variables.
        names: Where the names of the used variables go.
        nodes: Where their values go, parallel to `names`.

    Returns:
        False when upstream returns `None`: there is no variable map, or
        the fetch has no usages.
    """
    if not variables.is_some or not has_usages:
        return False
    var index = 0
    while index < len(usages):
        var name = String(store.name(usages[index]))
        var node = variables.variable(name)
        if node != NO_NODE:
            names.append(name^)
            nodes.append(node)
        index += 1
    return True


def condition_target(
    plan: QueryPlan, store: Store, node: Int, variables: CoerceVariablesPayload
) -> Int:
    """Pick the branch of a condition node, as upstream
    `condition_node_by_variables`.

    Args:
        plan: The query plan.
        store: The store with the variable name.
        node: The condition node.
        variables: The coerced variables.

    Returns:
        The `if` branch when the variable is `true`, the `else` branch
        otherwise, and `NONE` when there is no variable map or no value.
    """
    if not variables.is_some:
        return NONE
    ref condition = plan.nodes[node]
    var name = store.name(condition.condition)
    if variables.variable(name) == NO_NODE:
        return NONE
    if variables.variable_equals_true(name):
        return condition.if_clause
    return condition.else_clause


struct _Representations(Movable):
    """The representations of one `_entities` list while it is built."""

    var buffer: List[UInt8]
    """The JSON array."""
    var seen: Dict[UInt64, Int]
    """The entity index of each representation hash."""
    var count: Int
    """How many representations the array has."""

    def __init__(out self):
        """Start an empty array."""
        self.buffer = List[UInt8]()
        self.buffer.append(UInt8(ord("[")))
        self.seen = Dict[UInt64, Int]()
        self.count = 0

    def take(deinit self) -> List[UInt8]:
        """Return the JSON array."""
        return self.buffer^


def _collect_representations(
    store: Store,
    metadata: SchemaMetadata,
    keys: KeysByType,
    has_keys: Bool,
    requires: Int,
    rewrites: List[FetchRewrite],
    mut arena: JsonDocument,
    data: Int,
    path: FlattenNodePath,
    mut reps: _Representations,
    mut entities: List[Int],
) -> List[Int]:
    """Write the representation of each entity at a path, once per hash,
    as upstream does in `prepare_job_future`. Returns the values at the
    path, which the merge uses again."""
    var targets = TraverseTargets(False)
    traverse(arena, data, path, store, metadata.possible_types, targets)
    for node in targets.nodes:
        if arena.kind(node) == JsonKind.NULL:
            entities.append(-1)
            continue
        var hash = requires_hash(
            store, metadata.possible_types, requires, arena, node
        )
        var found = reps.seen.get(hash)
        if found:
            entities.append(found.value())
            continue
        var entity = node
        if len(rewrites) > 0:
            entity = copy_value(arena, node)
            var at = 0
            while at < len(rewrites):
                apply_rewrite(
                    store, metadata.possible_types, rewrites[at], arena, entity
                )
                at += 1
        var projected = project_requires(
            store,
            metadata.possible_types,
            requires,
            arena,
            entity,
            reps.buffer,
            len(reps.seen) == 0,
            "",
            False,
            False,
            keys,
            has_keys,
        )
        if not projected:
            entities.append(-1)
            continue
        reps.seen[hash] = reps.count
        entities.append(reps.count)
        reps.count += 1
    return targets^.take_nodes()


struct Executor[T: SubgraphTransport](Movable):
    """Runs query plans through a transport, as upstream `Executor`.

    Parameters:
        T: The transport type.
    """

    var transport: Self.T
    """Where subgraph requests go."""

    def __init__(out self, var transport: Self.T):
        """Make an executor.

        Args:
            transport: The transport.
        """
        self.transport = transport^

    def execute(
        mut self,
        store: Store,
        plan: QueryPlan,
        metadata: SchemaMetadata,
        keys: EntityKeys,
        variables: CoerceVariablesPayload,
        projection: ProjectionPlan,
        root_type_name: String,
        var arena: JsonDocument,
        data: Int,
        var errors: List[GraphQLError],
    ) raises -> PlanExecutionOutput:
        """Run a plan and project the response, as upstream
        `execute_query_plan_with_data`.

        Args:
            store: The planner store.
            plan: The executable query plan.
            metadata: The metadata of the consumer schema.
            keys: The entity keys of each subgraph.
            variables: The coerced variables.
            projection: The projection plan of the client operation.
            root_type_name: The root type of the operation.
            arena: The arena that holds `data`.
            data: The initial data object, such as the introspection data,
                or `NO_NODE` for an empty object.
            errors: The initial errors.

        Returns:
            The response body.

        Raises:
            Error: For a subscription, or when the projection fails.
        """
        var start = data
        if start == NO_NODE:
            start = arena.add_object()
        var ctx = ExecutionContext(arena^, start, errors^)
        if plan.node != NONE:
            self._run(ctx, store, plan, metadata, keys, variables, plan.node)
        var error_count = len(ctx.errors)
        var body = project_by_operation(
            ctx.arena,
            ctx.data,
            ctx.errors.copy(),
            root_type_name,
            projection,
            variables,
            ctx.response_bytes,
            metadata,
        )
        return PlanExecutionOutput(body^, error_count)

    def _run(
        mut self,
        mut ctx: ExecutionContext,
        store: Store,
        plan: QueryPlan,
        metadata: SchemaMetadata,
        keys: EntityKeys,
        variables: CoerceVariablesPayload,
        node: Int,
    ) raises:
        """Run one plan node, as upstream `execute_plan_node`."""
        var kind = plan.nodes[node].kind
        ref children = plan.nodes[node].nodes
        if kind == PlanNodeKind.SEQUENCE:
            var position = 0
            while position < len(children):
                self._run(
                    ctx,
                    store,
                    plan,
                    metadata,
                    keys,
                    variables,
                    children[position],
                )
                position += 1
            return
        if kind == PlanNodeKind.PARALLEL:
            var jobs = List[Job]()
            var position = 0
            while position < len(children):
                jobs.append(
                    self._prepare(
                        ctx,
                        store,
                        plan,
                        metadata,
                        keys,
                        variables,
                        children[position],
                    )
                )
                position += 1
            # Send every request first, so they are in flight at once; then
            # read and merge each response.
            var index = 0
            while index < len(jobs):
                self._start(plan, jobs[index])
                index += 1
            index = 0
            while index < len(jobs):
                self._finish(ctx, store, plan, metadata, jobs[index])
                index += 1
            return
        if kind == PlanNodeKind.CONDITION:
            var next = condition_target(plan, store, node, variables)
            if next != NONE:
                self._run(ctx, store, plan, metadata, keys, variables, next)
            return
        if kind == PlanNodeKind.SUBSCRIPTION or kind == PlanNodeKind.DEFER:
            raise Error("Subscriptions and @defer are not supported")
        var job = self._prepare(
            ctx, store, plan, metadata, keys, variables, node
        )
        self._start(plan, job)
        self._finish(ctx, store, plan, metadata, job)

    def _prepare(
        mut self,
        mut ctx: ExecutionContext,
        store: Store,
        plan: QueryPlan,
        metadata: SchemaMetadata,
        keys: EntityKeys,
        variables: CoerceVariablesPayload,
        node: Int,
    ) -> Job:
        """Prepare the request of a plan node, as upstream
        `prepare_job_future`; a `NONE` job when there is nothing to send."""
        ref plan_node = plan.nodes[node]
        var kind = plan_node.kind
        if kind == PlanNodeKind.CONDITION:
            var next = condition_target(plan, store, node, variables)
            if next == NONE:
                return Job(JobKind.NONE, String(), node, NONE)
            return self._prepare(
                ctx, store, plan, metadata, keys, variables, next
            )
        if kind == PlanNodeKind.FETCH:
            ref fetch = plan.fetches[plan_node.fetch]
            var job = Job(
                JobKind.FETCH,
                String(store.name(fetch.service_name)),
                node,
                plan_node.fetch,
            )
            job.body = _fetch_body(
                store,
                fetch.operation.document_str,
                fetch.variable_usages,
                fetch.has_variable_usages,
                variables,
                List[String](),
                List[List[UInt8]](),
            )
            return job^
        if kind == PlanNodeKind.BATCH_FETCH:
            return _prepare_batch(
                ctx, store, plan, metadata, keys, variables, node
            )
        if (
            kind != PlanNodeKind.FLATTEN
            or plan.nodes[plan_node.node].kind != PlanNodeKind.FETCH
        ):
            return Job(JobKind.NONE, String(), node, NONE)
        var fetch_index = plan.nodes[plan_node.node].fetch
        ref fetch = plan.fetches[fetch_index]
        var subgraph = String(store.name(fetch.service_name))
        if fetch.requires == NONE:
            var job = Job(JobKind.FETCH, subgraph, node, fetch_index)
            job.has_merge_path = True
            job.body = _fetch_body(
                store,
                fetch.operation.document_str,
                fetch.variable_usages,
                fetch.has_variable_usages,
                variables,
                List[String](),
                List[List[UInt8]](),
            )
            return job^
        var key_index = keys.index_of(subgraph)
        var reps = _Representations()
        var job = Job(JobKind.FLATTEN_FETCH, subgraph, node, fetch_index)
        job.targets = _collect_representations(
            store,
            metadata,
            keys.subgraphs[key_index],
            key_index > 0,
            fetch.requires,
            fetch.input_rewrites,
            ctx.arena,
            ctx.data,
            plan_node.path,
            reps,
            job.entities,
        )
        if reps.count == 0:
            return Job(JobKind.NONE, subgraph, node, NONE)
        reps.buffer.append(UInt8(ord("]")))
        var raw_names: List[String] = ["representations"]
        var raw_values = List[List[UInt8]]()
        raw_values.append(reps^.take())
        job.body = _fetch_body(
            store,
            fetch.operation.document_str,
            fetch.variable_usages,
            fetch.has_variable_usages,
            variables,
            raw_names,
            raw_values,
        )
        return job^

    def _start(mut self, plan: QueryPlan, job: Job):
        """Send the request of a job, as upstream `prepare_execution_job`."""
        if job.kind == JobKind.NONE:
            return
        if job.kind == JobKind.BATCH_FETCH:
            self.transport.start(
                job.subgraph,
                plan.batches[job.fetch].operation.document_str,
                job.body,
            )
        else:
            self.transport.start(
                job.subgraph,
                plan.fetches[job.fetch].operation.document_str,
                job.body,
            )

    def _finish(
        mut self,
        mut ctx: ExecutionContext,
        store: Store,
        plan: QueryPlan,
        metadata: SchemaMetadata,
        job: Job,
    ):
        """Read the response of a job that `_start` sent and merge it, as
        upstream `process_job_result`."""
        if job.kind == JobKind.NONE:
            return
        var affected = String()
        if job.kind == JobKind.FLATTEN_FETCH or job.has_merge_path:
            affected = plan.nodes[job.plan_node].path.text(store)
        var result = self.transport.finish()
        if result.failure != SubgraphFailure.NONE:
            ctx.errors.append(failure_error(result, job.subgraph, affected))
            return
        if len(result.body) == 0:
            ctx.errors.append(
                plan_error(
                    'Received empty response body from subgraph "'
                    + job.subgraph
                    + '"',
                    "SUBGRAPH_RESPONSE_BODY_EMPTY",
                    job.subgraph,
                    affected,
                )
            )
            return
        if not result.has_content_type or not is_valid_graphql_content_type(
            result.content_type
        ):
            ctx.errors.append(
                plan_error(
                    "Invalid content type returned from subgraph '"
                    + job.subgraph
                    + "': '"
                    + result.content_type
                    + "'",
                    "SUBREQUEST_MALFORMED_RESPONSE",
                    job.subgraph,
                    affected,
                )
            )
            return
        ctx.response_bytes += len(result.body)
        var status = result.status
        var response: SubgraphResponse
        try:
            response = read_subgraph_response(ctx.arena, result^.take_body())
        except e:
            ctx.errors.append(
                plan_error(
                    String(e),
                    "SUBREQUEST_MALFORMED_RESPONSE",
                    job.subgraph,
                    affected,
                )
            )
            return
        if status < 200 or status > 299:
            response.append_error(http_status_error(status, job.subgraph))
        if job.kind == JobKind.FETCH:
            _merge_fetch(ctx, store, plan, metadata, job, response^, affected)
        elif job.kind == JobKind.FLATTEN_FETCH:
            _merge_flatten(ctx, store, plan, metadata, job, response^, affected)
        else:
            _merge_batch(ctx, store, plan, metadata, job, response^)


def _fetch_body(
    store: Store,
    query: String,
    usages: List[Int],
    has_usages: Bool,
    variables: CoerceVariablesPayload,
    raw_names: List[String],
    raw_values: List[List[UInt8]],
) -> List[UInt8]:
    """Write the body of a fetch with the variables it uses."""
    var names = List[String]()
    var nodes = List[Int]()
    _ = select_fetch_variables(
        store, usages, has_usages, variables, names, nodes
    )
    return build_request_body(
        query, names, variables.document, nodes, raw_names, raw_values
    )


def _prepare_batch(
    mut ctx: ExecutionContext,
    store: Store,
    plan: QueryPlan,
    metadata: SchemaMetadata,
    keys: EntityKeys,
    variables: CoerceVariablesPayload,
    node: Int,
) -> Job:
    """Prepare a batch fetch, as upstream `prepare_batch_fetch_job_state`."""
    var batch_index = plan.nodes[node].fetch
    ref batch = plan.batches[batch_index]
    var subgraph = String(store.name(batch.service_name))
    var key_index = keys.index_of(subgraph)
    var job = Job(JobKind.BATCH_FETCH, subgraph, node, batch_index)
    var raw_names = List[String]()
    var raw_values = List[List[UInt8]]()
    var any = False
    var alias_index = 0
    while alias_index < len(batch.aliases):
        ref alias = batch.aliases[alias_index]
        var state = AliasState(alias_index)
        var reps = _Representations()
        var path_index = 0
        while path_index < len(alias.merge_paths):
            var leader = 0
            while alias.merge_paths[leader] != alias.merge_paths[path_index]:
                leader += 1
            if leader < path_index:
                state.path_entities.append(state.path_entities[leader].copy())
                state.path_targets.append(state.path_targets[leader].copy())
            else:
                var entities = List[Int]()
                var targets = _collect_representations(
                    store,
                    metadata,
                    keys.subgraphs[key_index],
                    key_index > 0,
                    alias.requires,
                    alias.input_rewrites,
                    ctx.arena,
                    ctx.data,
                    alias.merge_paths[path_index],
                    reps,
                    entities,
                )
                state.path_entities.append(entities^)
                state.path_targets.append(targets^)
            path_index += 1
        reps.buffer.append(UInt8(ord("]")))
        state.count = reps.count
        any = any or reps.count > 0
        var name = String(store.name(alias.representations_variable_name))
        if name not in raw_names:
            raw_names.append(name^)
            raw_values.append(reps^.take())
        job.aliases.append(state^)
        alias_index += 1
    if not any:
        return Job(JobKind.NONE, subgraph, node, NONE)
    job.body = _fetch_body(
        store,
        batch.operation.document_str,
        batch.variable_usages,
        batch.has_variable_usages,
        variables,
        raw_names,
        raw_values,
    )
    return job^


def _merge_fetch(
    mut ctx: ExecutionContext,
    store: Store,
    plan: QueryPlan,
    metadata: SchemaMetadata,
    job: Job,
    var response: SubgraphResponse,
    affected: String,
):
    """Merge a root fetch or a root re-entry fetch."""
    ref fetch = plan.fetches[job.fetch]
    if response.data != NO_NODE:
        for rewrite in fetch.output_rewrites:
            apply_rewrite(
                store,
                metadata.possible_types,
                rewrite,
                ctx.arena,
                response.data,
            )
        if not job.has_merge_path:
            deep_merge(ctx.arena, ctx.data, response.data)
        else:
            var targets = TraverseTargets(False)
            traverse(
                ctx.arena,
                ctx.data,
                plan.nodes[job.plan_node].path,
                store,
                metadata.possible_types,
                targets,
            )
            for target in targets.nodes:
                var source = copy_value(ctx.arena, response.data)
                deep_merge(ctx.arena, target, source)
    ctx.handle_errors(
        job.subgraph,
        affected,
        job.has_merge_path,
        response.errors.copy(),
        False,
        List[Int](),
        List[ErrorPath](),
    )


def _merge_entities(
    mut ctx: ExecutionContext,
    store: Store,
    metadata: SchemaMetadata,
    path: FlattenNodePath,
    prepared: List[Int],
    entities: List[Int],
    sources: List[Int],
    mut uses: List[Int],
    collect_paths: Bool,
    mut indexes: List[Int],
    mut paths: List[ErrorPath],
):
    """Merge each returned entity into the values at a path that sent it.

    The values are the ones the job found when it was prepared. Only the
    error paths need a new walk.
    """
    var targets = TraverseTargets(collect_paths)
    if collect_paths:
        traverse(
            ctx.arena, ctx.data, path, store, metadata.possible_types, targets
        )
    else:
        targets.nodes = prepared.copy()
    var count = min(len(targets.nodes), len(entities))
    var index = 0
    while index < count:
        var entity = entities[index]
        if entity >= 0:
            if collect_paths:
                indexes.append(entity)
                paths.append(targets.paths[index].copy())
            if entity < len(sources):
                uses[entity] -= 1
                var source = sources[entity]
                if uses[entity] > 0:
                    source = copy_value(ctx.arena, source)
                deep_merge(ctx.arena, targets.nodes[index], source)
        index += 1


def _count_uses(path_entities: List[List[Int]], count: Int) -> List[Int]:
    """Count how many values each entity merges into."""
    var uses = List[Int](length=count, fill=0)
    var path = 0
    while path < len(path_entities):
        ref entities = path_entities[path]
        var index = 0
        while index < len(entities):
            var entity = entities[index]
            if entity >= 0 and entity < count:
                uses[entity] += 1
            index += 1
        path += 1
    return uses^


def _entity_nodes(arena: JsonDocument, array: Int) -> List[Int]:
    """Return the items of an `_entities` array."""
    var out = List[Int]()
    var item = arena.first(array)
    while item != NO_NODE:
        out.append(item)
        item = arena.next(item)
    return out^


def _take_entities(mut arena: JsonDocument, data: Int, key: StringSlice) -> Int:
    """Take an entity array off the response data, as upstream
    `take_entities_by_key`; `NO_NODE` when it is absent or not a list."""
    if data == NO_NODE:
        return NO_NODE
    var member = take_member(arena, data, key)
    if member == NO_NODE or arena.kind(member) != JsonKind.ARRAY:
        return NO_NODE
    return member


def _merge_flatten(
    mut ctx: ExecutionContext,
    store: Store,
    plan: QueryPlan,
    metadata: SchemaMetadata,
    job: Job,
    var response: SubgraphResponse,
    affected: String,
):
    """Merge the entities of a flatten fetch, as upstream does for
    `ExecutionJob::FlattenFetch`."""
    var array = _take_entities(ctx.arena, response.data, "_entities")
    if array == NO_NODE:
        ctx.handle_errors(
            job.subgraph,
            affected,
            True,
            response.errors.copy(),
            False,
            List[Int](),
            List[ErrorPath](),
        )
        return
    ref fetch = plan.fetches[job.fetch]
    var sources = _entity_nodes(ctx.arena, array)
    for rewrite in fetch.output_rewrites:
        for source in sources:
            apply_rewrite(
                store, metadata.possible_types, rewrite, ctx.arena, source
            )
    var all = List[List[Int]]()
    all.append(job.entities.copy())
    var uses = _count_uses(all, len(sources))
    var indexes = List[Int]()
    var paths = List[ErrorPath]()
    _merge_entities(
        ctx,
        store,
        metadata,
        plan.nodes[job.plan_node].path,
        job.targets,
        job.entities,
        sources,
        uses,
        response.has_errors,
        indexes,
        paths,
    )
    ctx.handle_errors(
        job.subgraph,
        affected,
        True,
        response.errors.copy(),
        response.has_errors,
        indexes,
        paths,
    )


def _alias_of(
    store: Store, batch_aliases: List[Int], error: GraphQLError
) -> Int:
    """Return the alias an error belongs to, by the first step of its
    path, or -1."""
    if not error.has_path or len(error.path.segments) == 0:
        return -1
    ref first = error.path.segments[0]
    if first.kind != ErrorSegmentKind.FIELD:
        return -1
    var index = 0
    while index < len(batch_aliases):
        if store.name(batch_aliases[index]) == first.field:
            return index
        index += 1
    return -1


def _merge_batch(
    mut ctx: ExecutionContext,
    store: Store,
    plan: QueryPlan,
    metadata: SchemaMetadata,
    job: Job,
    var response: SubgraphResponse,
):
    """Merge each alias of a batch fetch, as upstream does for
    `ExecutionJob::BatchFetch`."""
    ref batch = plan.batches[job.fetch]
    # A batch has at least one alias, so these loops are `while` loops.
    var alias_names = List[Int]()
    var by_alias = List[List[GraphQLError]]()
    var has_alias_errors = List[Bool]()
    var at = 0
    while at < len(batch.aliases):
        alias_names.append(batch.aliases[at].alias)
        by_alias.append(List[GraphQLError]())
        has_alias_errors.append(False)
        at += 1
    # Split the errors by alias, as upstream `partition_batch_errors_by_alias`.
    var unmatched = List[GraphQLError]()
    for error in response.errors:
        var found = _alias_of(store, alias_names, error)
        if found < 0:
            unmatched.append(error.copy())
            continue
        var moved = error.copy()
        moved.path.segments[0].field = "_entities"
        by_alias[found].append(moved^)
        has_alias_errors[found] = True
    # Take each alias's entities, as `collect_batched_entities_by_alias`.
    var arrays = List[Int]()
    at = 0
    while at < len(alias_names):
        arrays.append(
            _take_entities(
                ctx.arena, response.data, store.name(alias_names[at])
            )
        )
        at += 1
    var position = 0
    while position < len(job.aliases):
        ref state = job.aliases[position]
        position += 1
        var a = state.alias
        ref alias = batch.aliases[a]
        var collect = has_alias_errors[a]
        var indexes = List[Int]()
        var paths = List[ErrorPath]()
        if arrays[a] != NO_NODE:
            var sources = _entity_nodes(ctx.arena, arrays[a])
            for rewrite in alias.output_rewrites:
                for source in sources:
                    apply_rewrite(
                        store,
                        metadata.possible_types,
                        rewrite,
                        ctx.arena,
                        source,
                    )
            if state.count > 0:
                var uses = _count_uses(state.path_entities, len(sources))
                var p = 0
                while p < len(alias.merge_paths):
                    _merge_entities(
                        ctx,
                        store,
                        metadata,
                        alias.merge_paths[p],
                        state.path_targets[p],
                        state.path_entities[p],
                        sources,
                        uses,
                        collect,
                        indexes,
                        paths,
                    )
                    p += 1
        var affected = String()
        if len(alias.merge_paths) == 1:
            affected = alias.merge_paths[0].text(store)
        ctx.handle_errors(
            job.subgraph,
            affected,
            len(alias.merge_paths) == 1,
            by_alias[a].copy(),
            collect,
            indexes,
            paths,
        )
    if len(unmatched) > 0:
        ctx.handle_errors(
            job.subgraph,
            String(),
            False,
            unmatched^,
            False,
            List[Int](),
            List[ErrorPath](),
        )

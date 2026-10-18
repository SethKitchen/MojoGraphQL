# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Run a query plan against the subgraphs.

Port of `execute_query_plan`, `Executor` and `ExecutionJob` of Hive Router
`1a29df9` `bin/router/src/executor/execution/plan.rs`, and of
`ExecutionContext::handle_errors` of `executor/execution_context.rs`.

A `Sequence` runs its children in order. A `Parallel` node prepares every
child from the same data first, then sends and merges each one. A
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

**Differences from upstream.** Upstream runs the children of a `Parallel`
node at the same time and merges each one as it arrives. This port sends
them one at a time, in plan order, so the errors are in plan order.
Subscriptions are not supported: a plan with a `Subscription` node raises
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
    var count: Int
    """How many representations the alias sends."""

    def __init__(out self, alias: Int):
        """Start an alias with no representations.

        Args:
            alias: The index of the alias in its batch.
        """
        self.alias = alias
        self.path_entities = List[List[Int]]()
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
    var aliases: List[AliasState]
    """For a batch fetch, the state of each alias."""

    def __init__(out self, kind: JobKind, subgraph: String, plan_node: Int, fetch: Int):
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

    def __init__(out self, var arena: JsonDocument, data: Int, var errors: List[GraphQLError]):
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


def failure_error(response: SubgraphHttpResponse, subgraph: String, affected_path: String) -> GraphQLError:
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

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The graphql-sse `prepare` and `perform` steps on gql_execution.

`GraphQLExecution` parses, finds the operation, validates, and then runs
`execute`, `subscribe`, or `experimental_execute_incrementally`. An
operation with `@defer` or `@stream` becomes a stream: the initial
payload, then each subsequent payload, each one a `next` event.

Ports graphql-sse 2.6.3 `src/handler.ts` `prepare`: its status codes and
messages.

Differences from upstream: graphql-sse 2.6.3 runs graphql-js 16, which
has no incremental delivery. With `incremental` set, the operation runs
as graphql-js 17 `experimentalExecuteIncrementally`, and the validation
adds `incremental_rules()`.
"""

from std.memory import ArcPointer

from gql_execution.execute import (
    ExecutionArgs,
    Resolvers,
    execute_with_resolvers,
)
from gql_execution.incremental import (
    SubsequentResultStream,
    experimental_execute_incrementally,
)
from gql_execution.subscribe import subscribe
from gql_execution.value import UNDEFINED, Values
from gql_http.parser import Request
from gql_http.status import Method, Status
from gql_json.parser import parse as parse_json
from gql_json.value import NO_NODE
from gql_language.ast import Document, OperationType
from gql_language.get_operation_ast import get_operation_ast
from gql_language.parser import parse
from gql_schema.definition import Schema
from gql_sse.handler import Prepared, RequestParams, SseExecutor, error_json
from gql_stream.poll import Event, EventStream, Poll
from gql_stream.stream import AnyStream
from gql_stream.waker import Waker
from gql_validation.rules import incremental_rules, specified_rules
from gql_validation.validate import validate


trait Roots(Deinitable, Movable):
    """The root values of the operations, as the `roots` option."""

    def root(
        mut self, mut values: Values, document: Document, operation: Int
    ) raises -> Int:
        """Make the root value of an operation.

        Args:
            values: The arena of the execution.
            document: The document.
            operation: The node of the operation.

        Returns:
            The root value in `values`, or `UNDEFINED`.

        Raises:
            Error: Any error; the client gets a 500.
        """
        ...


struct NoRoot(Roots):
    """Gives every operation no root value."""

    def __init__(out self):
        """Make the roots."""
        pass

    def root(
        mut self, mut values: Values, document: Document, operation: Int
    ) raises -> Int:
        """Return `UNDEFINED`.

        Args:
            values: The arena of the execution.
            document: The document.
            operation: The node of the operation.

        Returns:
            `UNDEFINED`.

        Raises:
            Error: Never; the trait method can raise.
        """
        return UNDEFINED


struct JsonRoot(Roots):
    """Gives every operation one root value, from JSON text."""

    var json: String
    """The JSON text of the root value."""

    def __init__(out self, json: String):
        """Make the roots.

        Args:
            json: The JSON text of the root value.
        """
        self.json = json

    def root(
        mut self, mut values: Values, document: Document, operation: Int
    ) raises -> Int:
        """Add the JSON value to the arena.

        Args:
            values: The arena of the execution.
            document: The document.
            operation: The node of the operation.

        Returns:
            The root value.

        Raises:
            Error: When the text is not JSON.
        """
        var value = parse_json(self.json)
        return values.add_json(value, value.root)


struct IncrementalStream(EventStream):
    """The payloads of an incremental result: the initial one, then each
    subsequent one."""

    var initial: Optional[Event]
    """The initial payload, until it is polled."""
    var rest: SubsequentResultStream
    """The subsequent payloads."""

    def __init__(
        out self, initial: String, var rest: SubsequentResultStream
    ) raises:
        """Make the stream.

        Args:
            initial: The JSON of the initial payload.
            rest: The subsequent payloads.

        Raises:
            Error: When the initial payload is not JSON.
        """
        self.initial = Event.parse(initial)
        self.rest = rest^

    def poll_next(mut self, mut waker: Waker) -> Poll:
        """Return the initial payload first, then the subsequent ones.

        Args:
            waker: The waker of the subsequent payloads.

        Returns:
            The next payload, `PENDING`, `DONE` or `ERROR`.
        """
        if self.initial:
            return Poll.ready(self.initial.take())
        return self.rest.poll_next(waker)

    def close(mut self):
        """Stop the subsequent payloads."""
        self.initial = None
        self.rest.close()


struct GraphQLExecution[R: Roots](SseExecutor):
    """Parse, validate and run each operation against a schema.

    Parameters:
        R: The type of the root values.
    """

    var schema: ArcPointer[Schema]
    """The schema, shared with each stream of results."""
    var resolvers: Resolvers
    """The resolvers of every operation."""
    var roots: Self.R
    """The root values."""
    var incremental: Bool
    """Whether `@defer` and `@stream` run; False at first."""

    def __init__(
        out self,
        var schema: Schema,
        var resolvers: Resolvers,
        var roots: Self.R,
        incremental: Bool = False,
    ):
        """Make an executor.

        Args:
            schema: The schema; with the `@defer` and `@stream` directives
                when `incremental` is True.
            resolvers: The resolvers.
            roots: The root values.
            incremental: Whether `@defer` and `@stream` run.
        """
        self.schema = ArcPointer(schema^)
        self.resolvers = resolvers^
        self.roots = roots^
        self.incremental = incremental

    def prepare(
        mut self, request: Request, params: RequestParams, event_stream: Bool
    ) raises -> Prepared:
        """Parse, validate and start one operation.

        Args:
            request: The request.
            params: The parameters.
            event_stream: Whether the request accepts `text/event-stream`.

        Returns:
            A 400 for a syntax error or no operation, a 405 for a mutation
            over GET, a 400 or a result for validation errors, or the
            result or the stream of results.

        Raises:
            Error: The errors of execution and of the roots.
        """
        var document: Document
        try:
            document = parse(params.query)
        except e:
            return Prepared.response(Status.BAD_REQUEST, error_json(e.message))
        var operation = get_operation_ast(document, params.operation_name)
        if operation == NO_NODE:
            return Prepared.response(
                Status.BAD_REQUEST, error_json("Unable to detect operation AST")
            )
        var kind = document.operation(operation)
        if kind == OperationType.MUTATION and request.method == Method.GET:
            return Prepared.response(
                Status.METHOD_NOT_ALLOWED,
                error_json("Cannot perform mutations over GET"),
                "POST",
            )
        var rules = specified_rules()
        if self.incremental:
            rules.extend(incremental_rules())
        var errors = validate(self.schema[], document, rules)
        if len(errors) > 0:
            var parts = List[String]()
            var index = 0
            while index < len(errors):
                parts.append(errors[index].to_json())
                index += 1
            var json = String('{"errors":[') + ",".join(parts) + "]}"
            if event_stream:
                return Prepared.result(json)
            return Prepared.response(Status.BAD_REQUEST, json)
        var args = ExecutionArgs()
        args.assume_valid_schema = True
        args.operation_name = params.operation_name
        if params.variables != NO_NODE:
            args.variable_values = args.values.add_json(
                params.document, params.variables
            )
        args.root_value = self.roots.root(args.values, document, operation)
        if kind == OperationType.SUBSCRIPTION:
            args.resolvers = self.resolvers.copy()
            var subscription = subscribe(
                self.schema, ArcPointer(document^), args^
            )
            if not subscription.is_stream():
                return Prepared.result(subscription.to_json())
            return Prepared.of_stream(AnyStream(subscription.take_stream()))
        if not self.incremental:
            var result = execute_with_resolvers(
                self.schema[], document, self.resolvers, args
            )
            return Prepared.result(result.to_json())
        args.resolvers = self.resolvers.copy()
        var results = experimental_execute_incrementally(
            self.schema, ArcPointer(document^), args^
        )
        if not results.is_incremental():
            return Prepared.result(results.to_json())
        var initial = results.to_json()
        return Prepared.of_stream(
            AnyStream(
                IncrementalStream(initial, results.take_subsequent_results())
            )
        )

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The executor of `graphql-transport-ws` on gql_execution: parse,
validate, and execute or subscribe, as the default path of graphql-ws
`makeServer`.

`GraphQLExecution` is a `GraphQLExecutor` for `gql_ws.transport_server`.
For each `subscribe` it parses the query, validates it against the
schema, and finds the operation. A query or a mutation runs `execute`,
and the result is one `next`, then `complete`. A subscription runs
`subscribe`: its response stream goes into the event loop, and each
event is a `next`. A syntax error closes the socket with 4500, as the
`ws` adapter of graphql-ws does with the thrown `GraphQLError`.
Validation errors are one `error`.

`Hooks` holds what graphql-ws takes as options: `onConnect`, the
`roots` of each operation type, and `onClose`. Mojo has no closures, so a
root value is where a subscription finds its source stream, as in the
gql_execution tests. `PubSubRoot` gives each root field a stream of a
`PubSub` trigger.

This module ports the `subscribe` path of graphql-ws 6.4.1
`src/server.ts` (`makeServer`: `parse`, `validate`, `getOperationAST`,
`roots`, `subscribe` and `execute`), with `tests/server.test.ts`.

Differences from upstream: the hooks are one trait. Execution is
synchronous. The `next` payload is the JSON of gql_execution, with
`errors` first, as graphql-js `JSON.stringify(result)`; graphql-ws writes
`errors` after `data`.
"""

from std.memory import ArcPointer

from gql_execution.execute import (
    ExecutionArgs,
    Resolvers,
    execute_with_resolvers,
)
from gql_execution.subscribe import subscribe
from gql_execution.value import UNDEFINED, Values
from gql_json.value import NO_NODE
from gql_language.ast import Document, OperationType
from gql_language.get_operation_ast import get_operation_ast
from gql_language.parser import parse
from gql_schema.definition import Schema
from gql_stream.pubsub import PubSub
from gql_stream.stream import AnyStream
from gql_validation.validate import validate

from gql_ws.graphql_ws import ProtocolMessage, error_payload
from gql_ws.transport_server import Acknowledgement, GraphQLExecutor, Operation


trait Hooks(Deinitable, Movable):
    """The options of graphql-ws that are not the schema."""

    def on_connect(
        mut self, socket: Int, message: ProtocolMessage
    ) raises -> Acknowledgement:
        """Accept or refuse a connection, as `onConnect`.

        Args:
            socket: The connection id.
            message: The `connection_init`.

        Returns:
            Whether to acknowledge, and the payload of the ack.

        Raises:
            Error: Any error; the socket closes with 4500.
        """
        ...

    def root(
        mut self,
        mut values: Values,
        document: Document,
        operation: Int,
    ) raises -> Int:
        """Make the root value of an operation, as `roots[operation]`.

        Args:
            values: The arena of the execution.
            document: The document.
            operation: The node of the operation.

        Returns:
            The root value in `values`, or `UNDEFINED`.

        Raises:
            Error: Any error; the socket closes with 4500.
        """
        ...

    def on_close(mut self, socket: Int, code: UInt16, reason: String):
        """Forget a connection, as `onClose`.

        Args:
            socket: The connection id.
            code: The close code.
            reason: The close reason.
        """
        ...


@fieldwise_init
struct DefaultHooks(Hooks):
    """Acknowledge every connection, with no root value."""

    def on_connect(
        mut self, socket: Int, message: ProtocolMessage
    ) raises -> Acknowledgement:
        """Acknowledge the connection without a payload.

        Args:
            socket: The connection id.
            message: The `connection_init`.

        Returns:
            A permitted acknowledgement.

        Raises:
            Error: Never.
        """
        return Acknowledgement(True, String())

    def root(
        mut self,
        mut values: Values,
        document: Document,
        operation: Int,
    ) raises -> Int:
        """Return no root value.

        Args:
            values: The arena of the execution.
            document: The document.
            operation: The node of the operation.

        Returns:
            `UNDEFINED`.

        Raises:
            Error: Never.
        """
        return UNDEFINED

    def on_close(mut self, socket: Int, code: UInt16, reason: String):
        """Do nothing.

        Args:
            socket: The connection id.
            code: The close code.
            reason: The close reason.
        """
        pass


struct PubSubRoot(Hooks):
    """Acknowledge every connection; the root value of a subscription has
    a stream of a `PubSub` trigger for each of some fields."""

    var pubsub: PubSub
    """The PubSub; a copy shares its engine."""
    var fields: List[String]
    """The root fields of the subscription type."""
    var triggers: List[String]
    """The trigger of each field."""

    def __init__(out self, pubsub: PubSub):
        """Make the hooks without fields.

        Args:
            pubsub: The PubSub.
        """
        self.pubsub = pubsub.copy()
        self.fields = List[String]()
        self.triggers = List[String]()

    def add(mut self, field: StringSlice, trigger: StringSlice):
        """Give a root field the events of a trigger.

        Args:
            field: The name of the subscription field.
            trigger: The trigger of the PubSub.
        """
        self.fields.append(String(field))
        self.triggers.append(String(trigger))

    def on_connect(
        mut self, socket: Int, message: ProtocolMessage
    ) raises -> Acknowledgement:
        """Acknowledge the connection without a payload.

        Args:
            socket: The connection id.
            message: The `connection_init`.

        Returns:
            A permitted acknowledgement.

        Raises:
            Error: Never.
        """
        return Acknowledgement(True, String())

    def root(
        mut self,
        mut values: Values,
        document: Document,
        operation: Int,
    ) raises -> Int:
        """Make an object with a new stream for each field, for a
        subscription; `UNDEFINED` for another operation.

        Args:
            values: The arena of the execution.
            document: The document.
            operation: The node of the operation.

        Returns:
            The root value.

        Raises:
            Error: Never.
        """
        if document.operation(operation) != OperationType.SUBSCRIPTION:
            return UNDEFINED
        var root = values.add_object()
        var index = 0
        while index < len(self.fields):
            var stream = self.pubsub.subscribe(self.triggers[index])
            values.add_member(
                root, self.fields[index], values.add_stream(AnyStream(stream^))
            )
            index += 1
        return root

    def on_close(mut self, socket: Int, code: UInt16, reason: String):
        """Do nothing.

        Args:
            socket: The connection id.
            code: The close code.
            reason: The close reason.
        """
        pass


struct GraphQLExecution[K: Hooks](GraphQLExecutor):
    """Parse, validate and execute each operation against a schema.

    Parameters:
        K: The type of the hooks.
    """

    var schema: ArcPointer[Schema]
    """The schema, shared with each response stream."""
    var resolvers: Resolvers
    """The resolvers of every operation."""
    var hooks: Self.K
    """The hooks."""

    def __init__(
        out self,
        var schema: Schema,
        var resolvers: Resolvers,
        var hooks: Self.K,
    ):
        """Make an executor.

        Args:
            schema: The schema.
            resolvers: The resolvers.
            hooks: The hooks.
        """
        self.schema = ArcPointer(schema^)
        self.resolvers = resolvers^
        self.hooks = hooks^

    def on_connect(
        mut self, socket: Int, message: ProtocolMessage
    ) raises -> Acknowledgement:
        """Ask the hooks.

        Args:
            socket: The connection id.
            message: The `connection_init`.

        Returns:
            The answer of `Hooks.on_connect`.

        Raises:
            Error: The errors of the hooks.
        """
        return self.hooks.on_connect(socket, message)

    def operation(
        mut self, socket: Int, message: ProtocolMessage
    ) raises -> Operation:
        """Parse, validate and run a `subscribe`.

        Args:
            socket: The connection id.
            message: The `subscribe`.

        Returns:
            Validation errors, a result, or the response stream of a
            subscription.

        Raises:
            Error: A syntax error, and the errors of execution and of the
                hooks.
        """
        var document: Document
        try:
            document = parse(message.member_string("query"))
        except e:
            raise Error(e.message)
        var errors = validate(self.schema[], document)
        if len(errors) > 0:
            var parts = List[String]()
            var index = 0
            while index < len(errors):
                parts.append(errors[index].to_json())
                index += 1
            return Operation.errors("[" + ",".join(parts) + "]")
        var name: Optional[String] = None
        var name_node = message.member("operationName")
        if name_node != NO_NODE:
            name = message.document.string_value(name_node)
        var operation = get_operation_ast(document, name)
        if operation == NO_NODE:
            return Operation.errors(
                error_payload("Unable to identify operation")
            )
        var args = ExecutionArgs()
        args.assume_valid_schema = True
        args.operation_name = name
        var variables = message.member("variables")
        if variables != NO_NODE:
            args.variable_values = args.values.add_json(
                message.document, variables
            )
        args.root_value = self.hooks.root(args.values, document, operation)
        if document.operation(operation) != OperationType.SUBSCRIPTION:
            var result = execute_with_resolvers(
                self.schema[], document, self.resolvers, args
            )
            return Operation.result(result.to_json())
        args.resolvers = self.resolvers.copy()
        var subscription = subscribe(self.schema, ArcPointer(document^), args^)
        if not subscription.is_stream():
            return Operation.result(subscription.to_json())
        return Operation.of_stream(AnyStream(subscription.take_stream()))

    def on_close(mut self, socket: Int, code: UInt16, reason: String):
        """Tell the hooks.

        Args:
            socket: The connection id.
            code: The close code.
            reason: The close reason.
        """
        self.hooks.on_close(socket, code, reason)

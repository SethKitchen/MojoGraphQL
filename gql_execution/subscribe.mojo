# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Subscriptions: `subscribe` and `create_source_event_stream`.

Port of graphql-js 16.14.2 `execution/subscribe.ts`. `subscribe` calls
the `subscribe` function of the root field and gets the source event
stream. It maps each event of the stream to a response: it executes the
operation with the event as the root value, as graphql-js maps the stream
with `mapAsyncIterator`. The response stream is a `gql_stream`
`EventStream`, so an event loop polls it.

**Source streams.** A `subscribe` function is a `FieldResolver`, set with
`Resolvers.subscribe`. It returns a value that `Values.add_stream` made:

    def important_email(
        mut values: Values, source: Int, args: Int, info: ResolveInfo
    ) raises -> Int:
        return values.add_stream(AnyStream(pubsub.subscribe("EMAIL")))

A field with no `subscribe` function uses `subscribeFieldResolver`, which
is `defaultFieldResolver`: the property of the root value. Put a stream
there with `add_stream`, as graphql-js puts an `AsyncIterable` there.

**Events.** An event of the source stream is a JSON value. Each event
becomes the root value of one execution, in the arena of the
subscription. The values of an event are dropped after its execution,
unless a resolver linked one of them into an older value.

**Responses.** An event of the response stream is the JSON of the
`ExecutionResult`: `{"errors":[...],"data":{...}}`, the text of
graphql-js `JSON.stringify(result)`. `response_event` makes it.

**Differences from upstream.**

- Execution is synchronous. `subscribe` returns at once: a `Subscription`
  with a stream or with a result, not a promise.
- A subscription field must return a stream that `Values.add_stream`
  made. Another value raises `Subscription field must return Async
  Iterable. Received: ...`, as graphql-js throws for a value that is not
  an `AsyncIterable`.
- An event that execution cannot run, because it raises, ends the
  response stream with `ERROR`, as `mapAsyncIterator` rejects. Execution
  raises only for the checks that `subscribe` made already.
- The schema is validated once, by `subscribe`. Each event executes with
  `assume_valid_schema`.
- The meta field `__typename` as the root field of a subscription is "not
  defined". The validation rule `SingleFieldSubscriptionsRule` refuses
  such a document, so only a document that is not valid meets it.
- The positional arguments of graphql-js 15 are not ported.
"""

from std.memory import ArcPointer

from gql_json.parser import parse
from gql_json.value import JsonDocument
from gql_language.ast import Document
from gql_language.error import GraphQLError
from gql_schema.definition import Schema
from gql_execution.execute import (
    ExecutionArgs,
    ExecutionResult,
    Resolvers,
    execute_with_resolvers,
    resolve_source_event,
)
from gql_execution.value import UNDEFINED, Values, inspect
from gql_stream.combinators import Mapper, MapStream
from gql_stream.poll import Event
from gql_stream.stream import AnyStream


struct SourceEventStream(Movable):
    """What `create_source_event_stream` returns: the source event stream,
    or an `ExecutionResult` with errors and no data."""

    var stream: Optional[AnyStream]
    """The source event stream, when there is no error."""
    var result: Optional[ExecutionResult]
    """The result with the errors, when there is no stream."""

    def __init__(
        out self,
        var stream: Optional[AnyStream],
        var result: Optional[ExecutionResult],
    ):
        """Make a source event stream or a result.

        Args:
            stream: The stream, or None.
            result: The result, or None.
        """
        self.stream = stream^
        self.result = result^

    def is_stream(self) -> Bool:
        """Return True when there is a stream.

        Returns:
            Whether `stream` holds the stream.
        """
        return Bool(self.stream)


def _errors_only(var errors: List[GraphQLError]) -> ExecutionResult:
    """Return a result with errors and no `data` key."""
    var data = JsonDocument()
    return ExecutionResult(data^, errors^)


def create_source_event_stream(
    schema: Schema, document: Document, mut args: ExecutionArgs
) raises -> SourceEventStream:
    """Resolve the source event stream of a subscription: graphql-js
    `createSourceEventStream`.

    Args:
        schema: The schema.
        document: The document; it is not validated.
        args: The inputs. `args.resolvers` has the `subscribe` functions.

    Returns:
        The source event stream, or a result with the errors of the
        operation, of the variables, or of `subscribe`.

    Raises:
        Error: The `assertValidSchema` error, the error of variable values
            that are not an object, or `Subscription field must return
            Async Iterable. Received: ...`.
    """
    var errors = List[GraphQLError]()
    var resolvers = Resolvers()
    swap(resolvers, args.resolvers)
    var value: Int
    try:
        value = resolve_source_event(schema, document, resolvers, args, errors)
    except e:
        swap(resolvers, args.resolvers)
        raise e^
    swap(resolvers, args.resolvers)
    if errors:
        return SourceEventStream(None, _errors_only(errors^))
    if not args.values.is_stream(value):
        raise Error(
            "Subscription field must return Async Iterable. Received: ",
            inspect(args.values, value),
            ".",
        )
    return SourceEventStream(args.values.take_stream(value), None)


def response_event(var result: ExecutionResult) raises -> Event:
    """Make the JSON event of an execution result.

    Args:
        result: The result.

    Returns:
        The event: `{"errors":[...],"data":...}`, with the keys of
        `ExecutionResult.to_json`.

    Raises:
        Error: Never; the JSON of an error is always valid.
    """
    var errors = List[GraphQLError]()
    swap(errors, result.errors)
    var has_data = result.has_data()
    var data_root = result.data.root
    var document = result^.take_data()
    return _response(document^, has_data, data_root, errors)


def _response(
    var document: JsonDocument,
    has_data: Bool,
    data_root: Int,
    errors: List[GraphQLError],
) raises -> Event:
    """Put the errors and the data under one object, as the root."""
    var object = document.add_object()
    if errors:
        var list = document.add_array()
        var index = 0
        while index < len(errors):
            var error = parse(errors[index].to_json())
            document.append(list, document.add_copy(error, error.root))
            index += 1
        document.add_member(object, "errors", list)
    if has_data:
        document.add_member(object, "data", data_root)
    document.root = object
    return Event(document^)


struct MapSourceToResponse(Mapper):
    """Executes the operation for each event: graphql-js
    `mapSourceToResponse`."""

    var schema: ArcPointer[Schema]
    """The schema."""
    var document: ArcPointer[Document]
    """The document."""
    var resolvers: Resolvers
    """The resolvers."""
    var args: ExecutionArgs
    """The other inputs, with the arena of the subscription."""

    def __init__(
        out self,
        schema: ArcPointer[Schema],
        document: ArcPointer[Document],
        var resolvers: Resolvers,
        var args: ExecutionArgs,
    ):
        """Keep what each execution needs.

        Args:
            schema: The schema.
            document: The document.
            resolvers: The resolvers.
            args: The other inputs; `args.resolvers` is not read.
        """
        self.schema = schema
        self.document = document
        self.resolvers = resolvers^
        self.args = args^

    def map(mut self, event: Event) raises -> Event:
        """Execute the operation with the event as the root value.

        Args:
            event: The event of the source stream.

        Returns:
            The response: the JSON of the `ExecutionResult`.

        Raises:
            Error: When execution raises.
        """
        var mark = self.args.values.mark()
        self.args.root_value = self.args.values.add_json(
            event.document[], event.root()
        )
        var result = execute_with_resolvers(
            self.schema[], self.document[], self.resolvers, self.args
        )
        self.args.root_value = UNDEFINED
        _ = self.args.values.release(mark)
        return response_event(result^)


comptime ResponseStream = MapStream[AnyStream, MapSourceToResponse]
"""The response stream of a subscription: the source event stream, mapped
with `MapSourceToResponse`."""


struct Subscription(Movable):
    """What `subscribe` returns: the response stream, or an
    `ExecutionResult` with errors and no data."""

    var stream: Optional[ResponseStream]
    """The response stream, when there is no error."""
    var result: Optional[ExecutionResult]
    """The result with the errors, when there is no stream."""

    def __init__(
        out self,
        var stream: Optional[ResponseStream],
        var result: Optional[ExecutionResult],
    ):
        """Make a subscription or a result.

        Args:
            stream: The stream, or None.
            result: The result, or None.
        """
        self.stream = stream^
        self.result = result^

    def is_stream(self) -> Bool:
        """Return True when there is a stream.

        Returns:
            Whether `stream` holds the stream.
        """
        return Bool(self.stream)

    def take_stream(mut self) raises -> ResponseStream:
        """Take the response stream out.

        Returns:
            The stream.

        Raises:
            Error: When there is no stream; read `result` then.
        """
        if not self.stream:
            raise Error("The subscription has no stream: ", self.to_json())
        return self.stream.take()

    def to_json(self) -> String:
        """Return the JSON of the result, or an empty string for a stream.

        Returns:
            `ExecutionResult.to_json` of the result.
        """
        if self.result:
            return self.result.value().to_json()
        return ""


def subscribe(
    schema: ArcPointer[Schema],
    document: ArcPointer[Document],
    var args: ExecutionArgs,
) raises -> Subscription:
    """Subscribe to an operation: graphql-js `subscribe`.

    Args:
        schema: The schema, shared with the response stream.
        document: The document, shared with the response stream.
        args: The inputs; the response stream keeps them, with their arena.

    Returns:
        The response stream, or a result with the errors of
        `create_source_event_stream`.

    Raises:
        Error: As `create_source_event_stream` raises.
    """
    var source = create_source_event_stream(schema[], document[], args)
    if not source.is_stream():
        return Subscription(None, source.result.take())
    args.assume_valid_schema = True
    var resolvers = Resolvers()
    swap(resolvers, args.resolvers)
    var mapper = MapSourceToResponse(schema, document, resolvers^, args^)
    return Subscription(ResponseStream(source.stream.take(), mapper^), None)


def subscribe(
    schema: Schema, document: Document, var args: ExecutionArgs
) raises -> Subscription:
    """Subscribe to an operation, with copies of the schema and the
    document for the response stream.

    Args:
        schema: The schema.
        document: The document.
        args: The inputs.

    Returns:
        As the other `subscribe` returns.

    Raises:
        Error: As the other `subscribe` raises.
    """
    return subscribe(
        ArcPointer(schema.copy()), ArcPointer(document.copy()), args^
    )

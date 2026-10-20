# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The subscription benchmark of gql_execution.

`stream/subscribe-publish-100` subscribes to an operation, then publishes
100 events to a `PubSub` and consumes the 100 responses. The baseline is
graphql-js 16.14.2 `subscribe` with a graphql-subscriptions 3.0.0
`PubSub`, in `bench/baselines/js-stream`. Both build the schema and parse
the document once, outside the timer. Each response is read: the `id` of
the message.
"""

from std.memory import ArcPointer

from _harness import Workload, measure, parse_document
from gql_execution.execute import ExecutionArgs
from gql_execution.subscribe import subscribe
from gql_json.value import JsonDocument
from gql_language.ast import Document
from gql_schema.build import build_schema
from gql_schema.definition import Schema
from gql_stream.poll import Event
from gql_stream.pubsub import PubSub
from gql_stream.stream import AnyStream
from gql_stream.waker import Waker

comptime EVENTS = 100


def _message(id: Int) -> Event:
    var document = JsonDocument()
    var root = document.add_object()
    var message = document.add_object()
    document.add_member(message, "id", document.add_int(Int64(id)))
    document.add_member(message, "text", document.add_string("hello"))
    document.add_member(message, "channel", document.add_string("general"))
    document.add_member(root, "messageAdded", message)
    document.root = root
    return Event(document^)


struct SubscribePublish(Movable, Workload):
    """Subscribe, publish `EVENTS` events, and read each response."""

    var schema: ArcPointer[Schema]
    var document: ArcPointer[Document]
    var waker: Waker

    def __init__(out self) raises:
        self.schema = ArcPointer(
            build_schema(
                "type Query { dummy: String }"
                " type Message { id: Int text: String channel: String }"
                " type Subscription { messageAdded(channel: String!): Message }"
            )
        )
        self.document = ArcPointer(
            parse_document(
                'subscription { messageAdded(channel: "general") { id text'
                " channel } }"
            )
        )
        self.waker = Waker.noop()

    def run(mut self) raises -> Int:
        var pubsub = PubSub()
        var args = ExecutionArgs()
        var root = args.values.add_object()
        args.values.add_member(
            root,
            "messageAdded",
            args.values.add_stream(
                AnyStream(pubsub.async_iterable_iterator("MESSAGE"))
            ),
        )
        args.root_value = root
        var subscription = subscribe(self.schema, self.document, args^)
        var responses = subscription.take_stream()
        var total = 0
        _ = responses.poll_next(self.waker)
        for i in range(EVENTS):
            pubsub.publish("MESSAGE", _message(i))
            var poll = responses.poll_next(self.waker)
            ref response = poll.event.value().document[]
            var data = response.find(response.root, "data")
            var message = response.find(data, "messageAdded")
            total += Int(response.as_int64(response.find(message, "id")))
        responses.close()
        return total + 1


def main() raises:
    measure("stream/subscribe-publish-100", SubscribePublish())

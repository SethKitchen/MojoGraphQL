# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of the response stream of `subscribe`: the "Subscription Publish
Phase" of graphql-js 16.14.2 `src/execution/__tests__/subscribe-test.ts`.

`SimplePubSub` of upstream is a `gql_stream` `PubSub`. Its subscriber
pushes each email into the inbox of its subscription when the email is
emitted, and execution reads the inbox later. Here `_emit` pushes the
email into each inbox, then publishes it, and `_EmailMapper` makes the
root value from the email and the inbox when the stream is polled. The
results are the same, "event order is correct for multiple publishes"
included.

Not ported: "should not trigger when subscription is thrown", because an
`EventStream` has no `throw()`.
"""

from std.memory import ArcPointer
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from gql_execution.execute import ExecutionArgs, ResolveInfo
from gql_execution.subscribe import ResponseStream, subscribe
from gql_execution.value import Values
from gql_language.parser import parse
from gql_schema.build import build_schema
from gql_stream.combinators import Mapper, MapStream
from gql_stream.poll import Event, Poll
from gql_stream.pubsub import PubSub, PubSubAsyncIterableIterator
from gql_stream.stream import AnyStream, ListStream
from gql_stream.waker import Waker

comptime _EMAIL_SCHEMA = """
type Email { from: String subject: String message: String unread: Boolean }
type Inbox { total: Int unread: Int emails: [Email] }
type Query { inbox: Inbox }
type EmailEvent { email: Email inbox: Inbox }
type Subscription { importantEmail(priority: Int): EmailEvent }
"""

comptime _EMAIL_QUERY = """
    subscription ($priority: Int = 0) {
      importantEmail(priority: $priority) {
        email {
          from
          subject
        }
        inbox {
          unread
          total
        }
      }
    }
"""

comptime _JOE = (
    '{"from":"joe@graphql.org","subject":"Hello","message":"Hello World",'
    '"unread":false}'
)


struct _Inbox(Movable):
    var emails: List[String]

    def __init__(out self):
        self.emails = List[String]()
        self.emails.append(_JOE)


struct _EmailMapper(Mapper):
    var inbox: ArcPointer[_Inbox]

    def __init__(out self, inbox: ArcPointer[_Inbox]):
        self.inbox = inbox

    def map(mut self, event: Event) raises -> Event:
        var text = String('{"importantEmail":{"email":')
        text += event.to_json()
        text += ',"inbox":{"emails":['
        var index = 0
        while index < len(self.inbox[].emails):
            if index > 0:
                text += ","
            text += self.inbox[].emails[index]
            index += 1
        text += "]}}}"
        return Event.parse(text)


def _total(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.add_number(
        Float64(values.length(values.get(source, "emails")))
    )


def _unread(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    var count = 0
    var email = values.first(values.get(source, "emails"))
    while email != -1:
        if values.bool_value(values.get(email, "unread")):
            count += 1
        email = values.next(email)
    return values.add_number(Float64(count))


struct _Emails:
    var pubsub: PubSub
    var inboxes: List[ArcPointer[_Inbox]]

    def __init__(out self):
        self.pubsub = PubSub()
        self.inboxes = List[ArcPointer[_Inbox]]()

    def create_subscription(mut self) raises -> ResponseStream:
        var inbox = ArcPointer(_Inbox())
        self.inboxes.append(inbox)
        var source = MapStream(
            self.pubsub.subscribe("email"), _EmailMapper(inbox)
        )
        var args = ExecutionArgs()
        args.resolvers.field("Inbox", "total", _total)
        args.resolvers.field("Inbox", "unread", _unread)
        var root = args.values.add_object()
        args.values.add_member(
            root, "importantEmail", args.values.add_stream(AnyStream(source^))
        )
        args.root_value = root
        var subscription = subscribe(
            build_schema(_EMAIL_SCHEMA), parse(_EMAIL_QUERY), args^
        )
        return subscription.take_stream()

    def emit(mut self, sender: String, subject: String) raises -> Bool:
        if self.pubsub.listener_count("email") == 0:
            return False
        var email = String('{"from":"') + sender + '","subject":"'
        email += subject + '","message":"Tests are good","unread":true}'
        var index = 0
        while index < len(self.inboxes):
            self.inboxes[index][].emails.append(email)
            index += 1
        self.pubsub.publish("email", Event.parse(email))
        return True


def _expected(
    sender: String, subject: String, unread: Int, total: Int
) -> String:
    return (
        String('{"data":{"importantEmail":{"email":{"from":"')
        + sender
        + '","subject":"'
        + subject
        + '"},"inbox":{"unread":'
        + String(unread)
        + ',"total":'
        + String(total)
        + "}}}}"
    )


def _next(mut stream: ResponseStream) raises -> Poll:
    var waker = Waker.noop()
    return stream.poll_next(waker)


def test_produces_a_payload_for_multiple_subscribe_in_same_subscription() raises:
    var emails = _Emails()
    var subscription = emails.create_subscription()
    var second_subscription = emails.create_subscription()
    assert_true(_next(subscription).is_pending())
    assert_true(_next(second_subscription).is_pending())
    assert_true(emails.emit("yuzhi@graphql.org", "Alright"))
    var expected = _expected("yuzhi@graphql.org", "Alright", 1, 2)
    assert_equal(_next(subscription).value().to_json(), expected)
    assert_equal(_next(second_subscription).value().to_json(), expected)


def test_produces_a_payload_per_subscription_event() raises:
    var emails = _Emails()
    var subscription = emails.create_subscription()
    assert_true(_next(subscription).is_pending())
    assert_true(emails.emit("yuzhi@graphql.org", "Alright"))
    assert_equal(
        _next(subscription).value().to_json(),
        _expected("yuzhi@graphql.org", "Alright", 1, 2),
    )
    assert_true(emails.emit("hyo@graphql.org", "Tools"))
    assert_equal(
        _next(subscription).value().to_json(),
        _expected("hyo@graphql.org", "Tools", 2, 3),
    )
    subscription.close()
    assert_false(emails.emit("adam@graphql.org", "Important"))
    assert_true(_next(subscription).is_done())


def test_produces_a_payload_when_there_are_multiple_events() raises:
    var emails = _Emails()
    var subscription = emails.create_subscription()
    assert_true(emails.emit("yuzhi@graphql.org", "Alright"))
    assert_equal(
        _next(subscription).value().to_json(),
        _expected("yuzhi@graphql.org", "Alright", 1, 2),
    )
    assert_true(_next(subscription).is_pending())
    assert_true(emails.emit("yuzhi@graphql.org", "Alright 2"))
    assert_equal(
        _next(subscription).value().to_json(),
        _expected("yuzhi@graphql.org", "Alright 2", 2, 3),
    )


def test_should_not_trigger_when_subscription_is_already_done() raises:
    var emails = _Emails()
    var subscription = emails.create_subscription()
    assert_true(emails.emit("yuzhi@graphql.org", "Alright"))
    assert_equal(
        _next(subscription).value().to_json(),
        _expected("yuzhi@graphql.org", "Alright", 1, 2),
    )
    var waker = Waker.noop()
    assert_true(subscription.poll_next(waker).is_pending())
    subscription.close()
    assert_true(waker.woken())
    assert_false(emails.emit("yuzhi@graphql.org", "Alright 2"))
    assert_true(subscription.poll_next(waker).is_done())


def test_event_order_is_correct_for_multiple_publishes() raises:
    var emails = _Emails()
    var subscription = emails.create_subscription()
    assert_true(_next(subscription).is_pending())
    assert_true(emails.emit("yuzhi@graphql.org", "Message"))
    assert_true(emails.emit("yuzhi@graphql.org", "Message 2"))
    assert_equal(
        _next(subscription).value().to_json(),
        _expected("yuzhi@graphql.org", "Message", 2, 3),
    )
    assert_equal(
        _next(subscription).value().to_json(),
        _expected("yuzhi@graphql.org", "Message 2", 2, 3),
    )


def _generate_messages(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    var texts = List[String]()
    texts.append('"Hello"')
    texts.append('"Goodbye"')
    texts.append('"Bonjour"')
    return values.add_stream(AnyStream(ListStream.of_json(texts)))


def _hello_then_error(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    var texts = List[String]()
    texts.append('"Hello"')
    return values.add_stream(AnyStream(ListStream.of_json(texts, "test error")))


def _message(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    if values.string(source) == "Goodbye":
        raise Error("Never leave.")
    return source


def _message_stream(
    subscribe_fn: def(
        mut values: Values, source: Int, args: Int, info: ResolveInfo
    ) raises thin -> Int
) raises -> ResponseStream:
    var args = ExecutionArgs()
    args.resolvers.subscribe("Subscription", "newMessage", subscribe_fn)
    args.resolvers.field("Subscription", "newMessage", _message)
    var subscription = subscribe(
        build_schema(
            "type Query { dummy: String } type Subscription { newMessage:"
            " String }"
        ),
        parse("subscription { newMessage }"),
        args^,
    )
    return subscription.take_stream()


def test_should_handle_error_during_execution_of_source_event() raises:
    var subscription = _message_stream(_generate_messages)
    assert_equal(
        _next(subscription).value().to_json(), '{"data":{"newMessage":"Hello"}}'
    )
    assert_equal(
        _next(subscription).value().to_json(),
        (
            '{"errors":[{"message":"Never leave.","locations":[{"line":1,'
            '"column":16}],"path":["newMessage"]}],"data":{"newMessage":null}}'
        ),
    )
    assert_equal(
        _next(subscription).value().to_json(),
        '{"data":{"newMessage":"Bonjour"}}',
    )
    assert_true(_next(subscription).is_done())


def test_should_pass_through_error_thrown_in_source_event_stream() raises:
    var subscription = _message_stream(_hello_then_error)
    assert_equal(
        _next(subscription).value().to_json(), '{"data":{"newMessage":"Hello"}}'
    )
    var poll = _next(subscription)
    assert_true(poll.is_error())
    assert_equal(poll.message, "test error")
    assert_true(_next(subscription).is_done())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

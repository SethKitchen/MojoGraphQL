# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of subscriptions and incremental delivery on subgraph schemas.

`test_attaches_the_subscribe_function` ports `@apollo/subgraph` 2.14.4
`src/__tests__/buildSubgraphSchema.test.ts`, `correctly attaches the
provided subscribe function to the schema object`. Upstream checks that
the field has the function; here the subscription runs, and each word of
the async generator of upstream is one event. The expected responses are
those of graphql-js `subscribe` on the schema of upstream, run in Node.js.

The other cases have no upstream test: they run `@defer`, `@stream` and
`_entities` through the subgraph resolvers.
"""

from std.memory import ArcPointer
from std.testing import TestSuite, assert_equal, assert_raises, assert_true
from gql_execution.execute import ExecutionArgs, ResolveInfo
from gql_execution.value import Values
from gql_language.parser import parse
from gql_stream.poll import Event
from gql_stream.stream import AnyStream, ListStream
from gql_stream.waker import Waker
from gql_subgraph.build_subgraph_schema import (
    SchemaModule,
    SubgraphResolvers,
    build_subgraph_schema,
)

comptime HELLO_SDL = """
type Query {
  hello: String!
}

type Subscription {
  hello: String!
}
"""
"""The schema of the upstream test."""

comptime DEFER_SDL = """
extend schema @link(url: "https://specs.apollo.dev/federation/v2.3", import: ["@key"])
directive @defer(if: Boolean! = true, label: String) on FRAGMENT_SPREAD | INLINE_FRAGMENT
directive @stream(if: Boolean! = true, label: String, initialCount: Int! = 0) on FIELD
type Query { me: User words: [String] }
type User @key(fields: "id") { id: ID! name: String }
"""
"""A federation 2 subgraph that defines `@defer` and `@stream`."""


def _subscribe_fn(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`async function* subscribeFn()`: Hello, Bonjour, Ciao."""
    var texts: List[String] = ['"Hello"', '"Bonjour"', '"Ciao"']
    return values.add_stream(AnyStream(ListStream.of_json(texts)))


def _greetings(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """Events that the default resolver of `hello` can read."""
    var texts: List[String] = ['{"hello":"Hello"}', '{"hello":"Bonjour"}']
    return values.add_stream(AnyStream(ListStream.of_json(texts)))


def _me(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    var user = values.add_object()
    values.add_member(user, "id", values.add_string("1"))
    values.add_member(user, "name", values.add_string("Ada"))
    return user


def _words(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    var texts: List[String] = ['"a"', '"b"']
    return values.add_stream(AnyStream(ListStream.of_json(texts)))


def test_attaches_the_subscribe_function() raises:
    var resolvers = SubgraphResolvers()
    resolvers.subscribe("Subscription", "hello", _subscribe_fn)
    var modules = List[SchemaModule]()
    modules.append(SchemaModule(parse(HELLO_SDL), resolvers^))
    var subgraph = build_subgraph_schema(modules^)
    var subscription = subgraph.subscribe(
        ArcPointer(parse("subscription { hello }")), ExecutionArgs()
    )
    assert_true(subscription.is_stream())
    var stream = subscription.take_stream()
    var waker = Waker.noop()
    # Each event is a string, and the default resolver of `hello` reads
    # `"Hello".hello`, which is undefined.
    var expected = String(
        '{"errors":[{"message":"Cannot return null for non-nullable field'
        ' Subscription.hello.","locations":[{"line":1,"column":16}],'
        '"path":["hello"]}],"data":null}'
    )
    for _ in range(3):
        assert_equal(stream.poll_next(waker).value().to_json(), expected)
    assert_true(stream.poll_next(waker).is_done())


def test_subscribe_function_of_a_later_module_wins() raises:
    var first = SubgraphResolvers()
    first.subscribe("Subscription", "hello", _words)
    var second = SubgraphResolvers()
    second.subscribe("Subscription", "hello", _greetings)
    var modules = List[SchemaModule]()
    modules.append(SchemaModule(parse(HELLO_SDL), first^))
    modules.append(SchemaModule(parse("scalar Unused"), second^))
    var subgraph = build_subgraph_schema(modules^)
    var subscription = subgraph.subscribe(
        ArcPointer(parse("subscription { hello }")), ExecutionArgs()
    )
    var stream = subscription.take_stream()
    var waker = Waker.noop()
    assert_equal(
        stream.poll_next(waker).value().to_json(), '{"data":{"hello":"Hello"}}'
    )


def test_subscription_without_subscribe_function() raises:
    # graphql-js 16 throws the error: it is not a `GraphQLError`.
    var subgraph = build_subgraph_schema(parse(HELLO_SDL))
    var document = ArcPointer(parse("subscription { hello }"))
    # The second call reuses the shared copies of the first.
    for _ in range(2):
        with assert_raises(
            contains=(
                "Subscription field must return Async Iterable. Received:"
                " undefined."
            )
        ):
            _ = subgraph.subscribe(document, ExecutionArgs())


def test_defer_and_stream_on_a_subgraph() raises:
    var resolvers = SubgraphResolvers()
    resolvers.field("Query", "me", _me)
    resolvers.field("Query", "words", _words)
    var modules = List[SchemaModule]()
    modules.append(SchemaModule(parse(DEFER_SDL), resolvers^))
    var subgraph = build_subgraph_schema(modules^)
    var results = subgraph.execute_incrementally(
        ArcPointer(
            parse(
                "{ me { id ... @defer { name } } words @stream"
                " _service { sdl } }"
            )
        ),
        ExecutionArgs(),
    )
    assert_true(results.is_incremental())
    var initial = results.to_json()
    assert_true(
        initial.startswith('{"data":{"me":{"id":"1"},"words":[]'),
        initial,
    )
    assert_true('"_service":{"sdl":"' in initial, initial)
    var stream = results.take_subsequent_results()
    var waker = Waker.noop()
    var texts = String("")
    while not stream.is_done():
        var poll = stream.poll_next(waker)
        if poll.is_ready():
            texts += poll.value().to_json()
    # The items that are ready together come in one entry.
    assert_equal(
        texts,
        (
            '{"hasNext":true,"incremental":[{"id":"0","data":{"name":"Ada"}}],'
            '"completed":[{"id":"0"}]}{"hasNext":false,"incremental":[{"id":"1",'
            '"items":["a","b"]}],"completed":[{"id":"1"}]}'
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

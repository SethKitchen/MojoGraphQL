# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `subscribe` and `create_source_event_stream`: the
"Subscription Initialization Phase" of graphql-js 16.14.2
`src/execution/__tests__/subscribe-test.ts`.

An `async function*` generator is a `ListStream`. A root value that holds
a generator function holds a stream that `Values.add_stream` made: the
default field resolver of graphql-js calls the function, and the Mojo one
returns the stream. A flag that a JavaScript test sets in a closure is a
property of the context value here.

Not ported: "accepts type definition with async subscribe function" is
"accepts type definition with sync subscribe function", because a Mojo
`subscribe` cannot be asynchronous; and the two "Deprecated" cases of the
positional arguments of graphql-js 15. The "Subscription Publish Phase"
cases are in `test_subscribe_publish.mojo`.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from gql_execution.execute import ExecutionArgs, ExecutionResult, ResolveInfo
from gql_json.value import JsonDocument
from gql_language.error import GraphQLError
from gql_execution.subscribe import (
    ResponseStream,
    create_source_event_stream,
    response_event,
    subscribe,
)
from gql_execution.value import UNDEFINED, Values
from gql_language.parser import parse
from gql_schema.build import BuildOptions, build_schema
from gql_stream.poll import Event, Poll
from gql_stream.stream import AnyStream, ListStream
from gql_stream.waker import Waker

comptime _FOO_SCHEMA = (
    "type Query { dummy: String } type Subscription { foo: String bar: String }"
)


def _foo_generator() raises -> AnyStream:
    var texts = List[String]()
    texts.append('{"foo":"FooValue"}')
    return AnyStream(ListStream.of_json(texts))


def _subscribe_foo(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    var context = info.context_value
    if context != UNDEFINED:
        values.set(context, "didResolveFoo", values.add_bool(True))
    return values.add_stream(_foo_generator())


def _subscribe_foo_async(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    var context = info.context_value
    if context != UNDEFINED:
        values.set(context, "didResolveFoo", values.add_bool(True))
    return values.add_promise(values.add_stream(_foo_generator()))


def _subscribe_bar(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    values.set(info.context_value, "didResolveBar", values.add_bool(True))
    return UNDEFINED


def _custom_foo(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.get(source, "customFoo")


def _next(mut stream: ResponseStream) raises -> Poll:
    var waker = Waker.noop()
    return stream.poll_next(waker)


def _expect_foo_then_done(mut stream: ResponseStream) raises:
    assert_equal(_next(stream).value().to_json(), '{"data":{"foo":"FooValue"}}')
    assert_true(_next(stream).is_done())


def test_accepts_multiple_subscription_fields_defined_in_schema() raises:
    var schema = build_schema(_FOO_SCHEMA)
    var args = ExecutionArgs()
    var root = args.values.add_object()
    args.values.add_member(
        root, "foo", args.values.add_stream(_foo_generator())
    )
    args.root_value = root
    var subscription = subscribe(schema, parse("subscription { foo }"), args^)
    assert_true(subscription.is_stream())
    var stream = subscription.take_stream()
    _expect_foo_then_done(stream)


def test_accepts_type_definition_with_sync_subscribe_function() raises:
    var schema = build_schema(_FOO_SCHEMA)
    var args = ExecutionArgs()
    args.resolvers.subscribe("Subscription", "foo", _subscribe_foo)
    # A function of another type, or of another field, is not used.
    args.resolvers.subscribe("Query", "foo", _returns_test)
    args.resolvers.subscribe("Subscription", "bar", _returns_test)
    args.assume_valid_schema = True
    var subscription = subscribe(schema, parse("subscription { foo }"), args^)
    assert_equal(subscription.to_json(), "")
    var stream = subscription.take_stream()
    _expect_foo_then_done(stream)


def test_accepts_type_definition_with_async_subscribe_function() raises:
    var schema = build_schema(_FOO_SCHEMA)
    var args = ExecutionArgs()
    args.resolvers.subscribe("Subscription", "foo", _subscribe_foo_async)
    args.assume_valid_schema = True
    var subscription = subscribe(schema, parse("subscription { foo }"), args^)
    assert_equal(subscription.to_json(), "")
    var stream = subscription.take_stream()
    _expect_foo_then_done(stream)


def test_uses_a_custom_default_subscribe_field_resolver() raises:
    var schema = build_schema(_FOO_SCHEMA)
    var args = ExecutionArgs()
    var root = args.values.add_object()
    args.values.add_member(
        root, "customFoo", args.values.add_stream(_foo_generator())
    )
    args.root_value = root
    args.resolvers.subscribe_field_resolver(_custom_foo)
    var subscription = subscribe(schema, parse("subscription { foo }"), args^)
    var stream = subscription.take_stream()
    _expect_foo_then_done(stream)


def test_should_only_resolve_the_first_field_of_invalid_multi_field() raises:
    var schema = build_schema(_FOO_SCHEMA)
    var args = ExecutionArgs()
    args.resolvers.subscribe("Subscription", "foo", _subscribe_foo)
    args.resolvers.subscribe("Subscription", "bar", _subscribe_bar)
    var context = args.values.add_object()
    args.context_value = context
    var document = parse("subscription { foo bar }")
    var source = create_source_event_stream(schema, document, args)
    assert_true(source.is_stream())
    assert_true(
        args.values.bool_value(args.values.get(context, "didResolveFoo"))
    )
    assert_equal(args.values.get(context, "didResolveBar"), UNDEFINED)
    var subscription = subscribe(schema, document, args^)
    var stream = subscription.take_stream()
    assert_true(_next(stream).is_ready())
    assert_true(_next(stream).is_done())


def _expect_raises(
    sdl: String, query: String, var args: ExecutionArgs, message: String
) raises:
    try:
        _ = subscribe(build_schema(sdl), parse(query), args^)
    except error:
        assert_equal(String(error), message)
        return
    raise Error("expected an error")


def test_throws_an_error_if_some_of_required_arguments_are_missing() raises:
    # A Mojo schema and document cannot be null. The checks of
    # `assertValidExecutionArguments` that remain are the schema and the
    # variable values.
    _expect_raises(
        (
            "type Query { dummy: String } type Subscription { foo: Query! }"
            " input Query { x: Int }"
        ),
        "subscription { foo }",
        ExecutionArgs(),
        'There can be only one type named "Query".',
    )
    var args = ExecutionArgs()
    args.variable_values = args.values.add_string("x")
    _expect_raises(
        _FOO_SCHEMA,
        "subscription { foo }",
        args^,
        (
            "Variables must be provided as an Object where each property is a"
            " variable value. Perhaps look to see if an unparsed JSON string"
            " was provided."
        ),
    )


def _result_json(
    sdl: String, query: String, var args: ExecutionArgs
) raises -> String:
    var subscription = subscribe(build_schema(sdl), parse(query), args^)
    assert_false(subscription.is_stream())
    return subscription.to_json()


def test_resolves_to_an_error_if_schema_does_not_support_subscriptions() raises:
    assert_equal(
        _result_json(
            "type Query { dummy: String }",
            "subscription { unknownField }",
            ExecutionArgs(),
        ),
        (
            '{"errors":[{"message":"Schema is not configured to execute'
            ' subscription operation.","locations":[{"line":1,"column":1}]}]}'
        ),
    )


def test_resolves_to_an_error_for_unknown_subscription_field() raises:
    assert_equal(
        _result_json(
            _FOO_SCHEMA, "subscription { unknownField }", ExecutionArgs()
        ),
        (
            '{"errors":[{"message":"The subscription field \\"unknownField\\"'
            ' is not defined.","locations":[{"line":1,"column":16}]}]}'
        ),
    )
    assert_equal(
        _result_json(
            _FOO_SCHEMA, "subscription { __typename }", ExecutionArgs()
        ),
        (
            '{"errors":[{"message":"The subscription field \\"__typename\\" is'
            ' not defined.","locations":[{"line":1,"column":16}]}]}'
        ),
    )


def _returns_test(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.add_string("test")


def test_throws_an_error_if_subscribe_does_not_return_an_iterator() raises:
    var args = ExecutionArgs()
    args.resolvers.subscribe("Subscription", "foo", _returns_test)
    _expect_raises(
        _FOO_SCHEMA,
        "subscription { foo }",
        args^,
        'Subscription field must return Async Iterable. Received: "test".',
    )
    _expect_raises(
        _FOO_SCHEMA,
        "subscription { foo }",
        ExecutionArgs(),
        "Subscription field must return Async Iterable. Received: undefined.",
    )


def _returns_error(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.add_error("test error")


def _throws_error(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    raise Error("test error")


def test_resolves_to_an_error_for_subscription_resolver_errors() raises:
    comptime expected = (
        '{"errors":[{"message":"test error","locations":[{"line":1,'
        '"column":16}],"path":["foo"]}]}'
    )
    var returning = ExecutionArgs()
    returning.resolvers.subscribe("Subscription", "foo", _returns_error)
    assert_equal(
        _result_json(_FOO_SCHEMA, "subscription { foo }", returning^), expected
    )
    var throwing = ExecutionArgs()
    throwing.resolvers.subscribe("Subscription", "foo", _throws_error)
    var schema = build_schema(_FOO_SCHEMA)
    var source = create_source_event_stream(
        schema, parse("subscription { foo }"), throwing
    )
    assert_false(source.is_stream())
    assert_equal(source.result.value().to_json(), expected)
    assert_equal(
        _result_json(_FOO_SCHEMA, "subscription { foo }", throwing^), expected
    )


def test_resolves_to_an_error_if_variables_were_wrong_type() raises:
    var args = ExecutionArgs()
    var variables = args.values.add_object()
    args.values.add_member(variables, "arg", args.values.add_string("meow"))
    args.variable_values = variables
    assert_equal(
        _result_json(
            (
                "type Query { dummy: String }"
                " type Subscription { foo(arg: Int): String }"
            ),
            (
                "\n      subscription ($arg: Int) {\n        foo(arg: $arg)\n  "
                "    }\n"
            ),
            args^,
        ),
        (
            '{"errors":[{"message":"Variable \\"$arg\\" got invalid value'
            ' \\"meow\\"; Int cannot represent non-integer value: \\"meow\\"",'
            '"locations":[{"line":2,"column":21}]}]}'
        ),
    )


def test_errors_of_arguments_are_located_at_the_field() raises:
    assert_equal(
        _result_json(
            (
                "type Query { dummy: String }"
                " type Subscription { foo(arg: Int!): String }"
            ),
            "subscription { foo }",
            ExecutionArgs(),
        ),
        (
            '{"errors":[{"message":"Argument \\"arg\\" of required type'
            ' \\"Int!\\" was not'
            ' provided.","locations":[{"line":1,"column":16}],"path":["foo"]}]}'
        ),
    )


def test_a_default_value_that_reaches_an_output_type_raises() raises:
    # A schema built with `assumeValid` can have an input field of an output
    # type. `valueFromAST` reaches its invariant for the default value of the
    # variable, and the error goes out of `subscribe`.
    var options = BuildOptions()
    options.assume_valid = True
    options.assume_valid_sdl = True
    var schema = build_schema(
        (
            "type Query { dummy: String } type Subscription { foo(a: In):"
            " String } input In { q: Query }"
        ),
        options,
    )
    var args = ExecutionArgs()
    args.assume_valid_schema = True
    var context = args.values.add_object()
    args.context_value = context
    var document = parse("subscription ($v: In = {q: {}}) { foo(a: $v) }")
    try:
        _ = create_source_event_stream(schema, document, args)
    except error:
        assert_equal(String(error), "Unexpected input type: Query")
        assert_equal(args.context_value, context)
        assert_equal(args.values.length(context), 0)
        return
    raise Error("expected an error")


def test_response_event_of_a_result_without_data() raises:
    var errors = List[GraphQLError]()
    errors.append(GraphQLError("x"))
    var result = ExecutionResult(JsonDocument(), errors^)
    assert_equal(
        response_event(result^).to_json(), '{"errors":[{"message":"x"}]}'
    )


def test_operation_errors() raises:
    # graphql-js `executeSubscription` reads the subscription type for any
    # operation, so a query names its field as a subscription field.
    assert_equal(
        _result_json(_FOO_SCHEMA, "{ dummy }", ExecutionArgs()),
        (
            '{"errors":[{"message":"The subscription field \\"dummy\\" is'
            ' not defined.","locations":[{"line":1,"column":3}]}]}'
        ),
    )
    var args = ExecutionArgs()
    args.operation_name = String("Nope")
    assert_equal(
        _result_json(_FOO_SCHEMA, "subscription S { foo }", args^),
        '{"errors":[{"message":"Unknown operation named \\"Nope\\"."}]}',
    )
    var subscription = subscribe(
        build_schema(_FOO_SCHEMA), parse("{ dummy }"), ExecutionArgs()
    )
    try:
        _ = subscription.take_stream()
    except error:
        assert_true(String(error).startswith("The subscription has no stream"))
        return
    raise Error("expected an error")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

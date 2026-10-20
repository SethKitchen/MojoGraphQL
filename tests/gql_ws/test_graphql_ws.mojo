# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_ws.graphql_ws`.

Ported from graphql-ws 6.4.1 `tests/common.test.ts` ("should report
invalid message with descriptive error" and "should accept valid
message"), with the texts of `tests/__snapshots__/common.test.ts.snap`.
"""

from gql_json.value import NO_NODE
from gql_ws.graphql_ws import (
    BAD_REQUEST,
    GRAPHQL_TRANSPORT_WS_PROTOCOL,
    MessageType,
    error_payload,
    id_message,
    limit_close_reason,
    parse_message,
    payload_message,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def error_of(text: StringSlice) -> String:
    try:
        _ = parse_message(text)
    except e:
        return String(e)
    return "valid"


def test_invalid_messages() raises:
    # Each case of the upstream table, with its snapshot text.
    var cases: List[Tuple[String, String]] = [
        ("{}", "Message is missing the 'type' property"),
        ('""', "Message is expected to be an object, but got string"),
        ("[]", "Message is expected to be an object, but got array"),
        ("0", "Message is expected to be an object, but got number"),
        ("9", "Message is expected to be an object, but got number"),
        ("null", "Message is expected to be an object, but got null"),
        ('{"type":""}', "Message is missing the 'type' property"),
        ('{"type":null}', "Message is missing the 'type' property"),
        ('{"type":0}', "Message is missing the 'type' property"),
        ('{"type":false}', "Message is missing the 'type' property"),
        (
            '{"type":true}',
            (
                "Message is expects the 'type' property to be a string, but got"
                " boolean"
            ),
        ),
        (
            '{"type":1}',
            (
                "Message is expects the 'type' property to be a string, but got"
                " number"
            ),
        ),
        (
            '{"type":{}}',
            (
                "Message is expects the 'type' property to be a string, but got"
                " object"
            ),
        ),
        ('{"type":"nuxt"}', "Invalid message 'type' property \"nuxt\""),
        (
            '{"type":"connection_init","payload":""}',
            (
                "\"connection_init\" message expects the 'payload' property to"
                ' be an object or nullish or missing, but got ""'
            ),
        ),
        (
            '{"type":"connection_init","payload":0}',
            (
                "\"connection_init\" message expects the 'payload' property to"
                ' be an object or nullish or missing, but got "0"'
            ),
        ),
        (
            '{"type":"connection_ack","payload":""}',
            (
                "\"connection_ack\" message expects the 'payload' property to"
                ' be an object or nullish or missing, but got ""'
            ),
        ),
        (
            '{"type":"ping","payload":0}',
            (
                "\"ping\" message expects the 'payload' property to be an"
                ' object or nullish or missing, but got "0"'
            ),
        ),
        (
            '{"type":"pong","payload":[1,[2,{}]]}',
            (
                "\"pong\" message expects the 'payload' property to be an"
                ' object or nullish or missing, but got "1,2,[object Object]"'
            ),
        ),
        (
            '{"type":"subscribe"}',
            (
                "\"subscribe\" message expects the 'id' property to be a"
                " string, but got undefined"
            ),
        ),
        (
            '{"id":0,"type":"subscribe"}',
            (
                "\"subscribe\" message expects the 'id' property to be a"
                " string, but got number"
            ),
        ),
        (
            '{"id":"","type":"subscribe"}',
            "\"subscribe\" message requires a non-empty 'id' property",
        ),
        (
            '{"id":"id","type":"subscribe"}',
            (
                "\"subscribe\" message expects the 'payload' property to be an"
                " object, but got undefined"
            ),
        ),
        (
            '{"id":"id","type":"subscribe","payload":[]}',
            (
                "\"subscribe\" message expects the 'payload' property to be an"
                " object, but got array"
            ),
        ),
        (
            '{"id":"id","type":"subscribe","payload":""}',
            (
                "\"subscribe\" message expects the 'payload' property to be an"
                " object, but got string"
            ),
        ),
        (
            '{"id":"id","type":"subscribe","payload":{}}',
            (
                "\"subscribe\" message payload expects the 'query' property to"
                " be a string, but got undefined"
            ),
        ),
        (
            '{"id":"id","type":"subscribe","payload":{"query":0}}',
            (
                "\"subscribe\" message payload expects the 'query' property to"
                " be a string, but got number"
            ),
        ),
        (
            '{"id":"id","type":"subscribe","payload":{"query":{}}}',
            (
                "\"subscribe\" message payload expects the 'query' property to"
                " be a string, but got object"
            ),
        ),
        (
            (
                '{"id":"id","type":"subscribe","payload":{"operationName":0,'
                '"query":""}}'
            ),
            (
                "\"subscribe\" message payload expects the 'operationName'"
                " property to be a string or nullish or missing, but got number"
            ),
        ),
        (
            (
                '{"id":"id","type":"subscribe","payload":{"operationName":{},'
                '"query":""}}'
            ),
            (
                "\"subscribe\" message payload expects the 'operationName'"
                " property to be a string or nullish or missing, but got object"
            ),
        ),
        (
            (
                '{"id":"id","type":"subscribe","payload":{"query":"",'
                '"variables":""}}'
            ),
            (
                "\"subscribe\" message payload expects the 'variables' property"
                " to be a an object or nullish or missing, but got string"
            ),
        ),
        (
            (
                '{"id":"id","type":"subscribe","payload":{"query":"",'
                '"extensions":""}}'
            ),
            (
                "\"subscribe\" message payload expects the 'extensions'"
                " property to be a an object or nullish or missing, but got"
                " string"
            ),
        ),
        (
            (
                '{"id":"id","type":"subscribe","payload":{"query":"",'
                '"extensions":0}}'
            ),
            (
                "\"subscribe\" message payload expects the 'extensions'"
                " property to be a an object or nullish or missing, but got"
                " number"
            ),
        ),
        (
            '{"type":"next"}',
            (
                "\"next\" message expects the 'id' property to be a string, but"
                " got undefined"
            ),
        ),
        (
            '{"id":"","type":"next"}',
            "\"next\" message requires a non-empty 'id' property",
        ),
        (
            '{"id":"id","type":"next"}',
            (
                "\"next\" message expects the 'payload' property to be an"
                " object, but got undefined"
            ),
        ),
        (
            '{"id":"id","type":"next","payload":""}',
            (
                "\"next\" message expects the 'payload' property to be an"
                " object, but got string"
            ),
        ),
        (
            '{"type":"error"}',
            (
                "\"error\" message expects the 'id' property to be a string,"
                " but got undefined"
            ),
        ),
        (
            '{"id":"","type":"error"}',
            "\"error\" message requires a non-empty 'id' property",
        ),
        (
            '{"id":"id","type":"error"}',
            (
                "\"error\" message expects the 'payload' property to be an"
                " array of GraphQL errors, but got undefined"
            ),
        ),
        (
            '{"id":"id","type":"error","payload":{}}',
            (
                "\"error\" message expects the 'payload' property to be an"
                " array of GraphQL errors, but got {}"
            ),
        ),
        (
            '{"id":"id","type":"error","payload":""}',
            (
                "\"error\" message expects the 'payload' property to be an"
                ' array of GraphQL errors, but got ""'
            ),
        ),
        (
            '{"id":"id","type":"error","payload":[]}',
            (
                "\"error\" message expects the 'payload' property to be an"
                " array of GraphQL errors, but got []"
            ),
        ),
        (
            '{"id":"id","type":"error","payload":[{"iam":"invalid"}]}',
            (
                "\"error\" message expects the 'payload' property to be an"
                ' array of GraphQL errors, but got [{"iam":"invalid"}]'
            ),
        ),
        (
            '{"id":"id","type":"error","payload":[1]}',
            (
                "\"error\" message expects the 'payload' property to be an"
                " array of GraphQL errors, but got [1]"
            ),
        ),
        (
            '{"type":"complete"}',
            (
                "\"complete\" message expects the 'id' property to be a string,"
                " but got undefined"
            ),
        ),
        (
            '{"id":"","type":"complete"}',
            "\"complete\" message requires a non-empty 'id' property",
        ),
        (
            '{"id":0,"type":"complete"}',
            (
                "\"complete\" message expects the 'id' property to be a string,"
                " but got number"
            ),
        ),
    ]
    for item in cases:
        assert_equal(error_of(item[0]), item[1], item[0])
    assert_true(error_of("{").byte_length() > 0)
    assert_false(error_of("{") == "valid")


def test_valid_messages() raises:
    var cases: List[String] = [
        '{"type":"connection_init"}',
        '{"type":"connection_init","payload":{}}',
        '{"type":"connection_init","payload":null}',
        '{"type":"connection_ack"}',
        '{"type":"connection_ack","payload":{}}',
        '{"type":"connection_ack","payload":null}',
        '{"type":"ping"}',
        '{"type":"ping","payload":{}}',
        '{"type":"ping","payload":null}',
        '{"type":"pong"}',
        '{"type":"pong","payload":{}}',
        '{"type":"pong","payload":null}',
        '{"id":"id","type":"subscribe","payload":{"query":""}}',
        (
            '{"id":"id","type":"subscribe","payload":{"operationName":null,'
            '"variables":null,"extensions":null,"query":""}}'
        ),
        (
            '{"id":"id","type":"subscribe","payload":{"operationName":"Op",'
            '"variables":{},"extensions":{},"query":""}}'
        ),
        '{"id":"id","type":"error","payload":[{"message":"I am Error"}]}',
        '{"id":"id","type":"next","payload":{"data":null}}',
        '{"id":"id","type":"complete"}',
    ]
    for item in cases:
        assert_equal(error_of(item), "valid", item)


def test_message_parts() raises:
    var m = parse_message(
        '{"id":"7","type":"subscribe","payload":{"query":"{ a }",'
        '"variables":{"x":1},"operationName":null}}'
    )
    assert_true(m.type == MessageType.SUBSCRIBE)
    assert_equal(m.id, "7")
    assert_equal(m.member_string("query"), "{ a }")
    assert_equal(m.member_json("variables"), '{"x":1}')
    assert_equal(m.member_json("operationName"), "")
    assert_equal(m.member_string("operationName"), "")
    assert_equal(m.member_string("variables"), "")
    assert_equal(m.member_json("extensions"), "")
    assert_true(m.payload_json().startswith('{"query"'))
    var ping = parse_message('{"type":"ping","payload":null}')
    assert_true(ping.payload == NO_NODE)
    assert_equal(ping.payload_json(), "")
    assert_true(ping.member("x") == NO_NODE)
    assert_equal(ping.id, "")


def test_writers() raises:
    assert_equal(
        payload_message(MessageType.CONNECTION_INIT),
        '{"type":"connection_init"}',
    )
    assert_equal(
        payload_message(MessageType.PONG, '{"a":1}'),
        '{"type":"pong","payload":{"a":1}}',
    )
    assert_equal(
        id_message(MessageType.NEXT, 'a"b', '{"data":{}}'),
        '{"id":"a\\"b","type":"next","payload":{"data":{}}}',
    )
    assert_equal(
        id_message(MessageType.COMPLETE, "1"), '{"id":"1","type":"complete"}'
    )
    assert_equal(error_payload('bad "x"'), '[{"message":"bad \\"x\\""}]')
    # Each text that a writer makes is a valid message.
    _ = parse_message(id_message(MessageType.ERROR, "1", error_payload("e")))


def test_types() raises:
    assert_equal(MessageType.CONNECTION_ACK.text(), "connection_ack")
    assert_equal(String(MessageType.COMPLETE), "complete")
    assert_equal(MessageType(8).text(), "invalid")
    assert_false(MessageType(8).is_valid())
    assert_true(MessageType.from_text("next") == MessageType.NEXT)
    assert_false(MessageType.from_text("x").is_valid())
    assert_equal(Int(BAD_REQUEST.value), 4400)
    assert_equal(GRAPHQL_TRANSPORT_WS_PROTOCOL, "graphql-transport-ws")
    assert_equal(limit_close_reason("short", "long"), "short")
    assert_equal(limit_close_reason(String("x") * 124, "long"), "long")
    assert_equal(
        limit_close_reason(String("x") * 123, "long").byte_length(), 123
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

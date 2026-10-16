# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_mcp.jsonrpc` and `gql_mcp.call_result`.

There is no upstream test file: the expected classifications and texts are
the replies of the Apollo MCP Server 2.0.0 binary over stdio.
"""

from gql_json.value import NO_NODE
from gql_mcp.call_result import CallToolResult
from gql_mcp.jsonrpc import (
    ErrorCode,
    MessageKind,
    error_message,
    invalid_request_message,
    is_integer_id,
    parse_message,
    result_message,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _kind(text: StringSlice) -> MessageKind:
    return parse_message(text).kind


def test_classify() raises:
    assert_true(_kind("garbage") == MessageKind.MALFORMED)
    assert_true(parse_message("{").error.byte_length() > 0)
    assert_true(
        _kind('[{"jsonrpc":"2.0","id":2,"method":"ping"}]')
        == MessageKind.INVALID
    )
    assert_true(_kind("5") == MessageKind.INVALID)
    assert_true(_kind("{}") == MessageKind.INVALID)
    assert_true(_kind('{"id":4,"method":"ping"}') == MessageKind.INVALID)
    assert_true(
        _kind('{"jsonrpc":2,"id":4,"method":"ping"}') == MessageKind.INVALID
    )
    assert_true(
        _kind('{"jsonrpc":"1.0","id":5,"method":"ping"}') == MessageKind.INVALID
    )
    assert_true(_kind('{"jsonrpc":"2.0","id":15}') == MessageKind.INVALID)
    assert_true(_kind('{"jsonrpc":"2.0","result":{}}') == MessageKind.INVALID)
    assert_true(
        _kind('{"jsonrpc":"2.0","id":16,"method":5}') == MessageKind.INVALID
    )
    assert_true(
        _kind('{"jsonrpc":"2.0","id":13,"method":"ping","params":5}')
        == MessageKind.INVALID
    )
    assert_true(
        _kind('{"jsonrpc":"2.0","id":14,"result":{}}') == MessageKind.RESPONSE
    )
    assert_true(
        _kind('{"jsonrpc":"2.0","id":20,"error":{"code":1,"message":"x"}}')
        == MessageKind.RESPONSE
    )
    assert_true(
        _kind('{"jsonrpc":"2.0","id":null,"method":"ping"}')
        == MessageKind.IGNORED
    )
    assert_true(
        _kind('{"jsonrpc":"2.0","id":1.5,"method":"ping"}')
        == MessageKind.IGNORED
    )
    assert_true(
        _kind('{"jsonrpc":"2.0","id":true,"method":"ping"}')
        == MessageKind.IGNORED
    )
    var note = parse_message(
        '{"jsonrpc":"2.0","method":"notifications/initialized"}'
    )
    assert_true(note.kind == MessageKind.NOTIFICATION)
    assert_equal(note.method, "notifications/initialized")
    assert_equal(note.params, NO_NODE)


def test_requests() raises:
    var request = parse_message(
        '{"jsonrpc":"2.0","id":"s\\u0036","method":"ping","params":{"a":1}}'
    )
    assert_true(request.kind == MessageKind.REQUEST)
    assert_equal(request.id, '"s6"')
    assert_equal(request.method, "ping")
    assert_true(request.params != NO_NODE)
    var big = parse_message(
        '{"jsonrpc":"2.0","id":9007199254740993,"method":"ping","params":null}'
    )
    assert_equal(big.id, "9007199254740993")
    assert_equal(big.params, NO_NODE)
    assert_equal(
        parse_message('{"jsonrpc":"2.0","id":-3,"method":"x"}').id, "-3"
    )


def test_integer_ids() raises:
    assert_true(is_integer_id("0"))
    assert_true(is_integer_id("-9223372036854775808"))
    assert_false(is_integer_id("-9223372036854775809"))
    assert_true(is_integer_id("18446744073709551615"))
    assert_false(is_integer_id("18446744073709551616"))
    assert_false(is_integer_id("184467440737095516150"))
    assert_false(is_integer_id("1e2"))
    assert_false(is_integer_id("1.0"))


def test_replies() raises:
    assert_equal(
        result_message("1", "{}"), '{"jsonrpc":"2.0","id":1,"result":{}}'
    )
    assert_equal(
        error_message('"a"', ErrorCode.METHOD_NOT_FOUND, 'no "x"'),
        (
            '{"jsonrpc":"2.0","id":"a","error":{"code":-32601,"message":"no'
            ' \\"x\\""}}'
        ),
    )
    assert_equal(
        invalid_request_message(),
        '{"jsonrpc":"2.0","error":{"code":-32600,"message":"Invalid request"}}',
    )
    assert_true(ErrorCode.PARSE_ERROR.is_valid())
    assert_true(ErrorCode.INTERNAL_ERROR.is_valid())
    assert_true(ErrorCode.INVALID_PARAMS.is_valid())
    assert_true(ErrorCode(-32020).is_valid())
    assert_true(ErrorCode(-32000).is_valid())
    assert_false(ErrorCode(-32099 - 1).is_valid())
    assert_false(ErrorCode(-31999).is_valid())
    assert_false(ErrorCode(-32604).is_valid())
    assert_false(ErrorCode(-32599).is_valid())
    assert_false(ErrorCode(-32701).is_valid())
    assert_true(MessageKind.MALFORMED.is_valid())
    assert_false(MessageKind(6).is_valid())


def test_call_result() raises:
    var texts = List[String]()
    assert_equal(
        CallToolResult.success(texts^).to_json(),
        '{"content":[],"isError":false}',
    )
    assert_equal(
        CallToolResult.error("bad").to_json(),
        '{"content":[{"type":"text","text":"bad"}],"isError":true}',
    )
    var structured = CallToolResult.structured('{"data":null}', True)
    assert_equal(
        structured.to_json(),
        '{"content":[{"type":"text","text":"{\\"data\\":null}"}],'
        + '"structuredContent":{"data":null},"isError":true}',
    )
    assert_equal(
        structured.to_json(False),
        '{"content":[{"type":"text","text":"{\\"data\\":null}"}],"isError":true}',
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

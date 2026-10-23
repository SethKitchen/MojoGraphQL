# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `gql_server.usage_reporting_protobuf` and `gql_server.base64`.

Apollo Server 5.5.1 has no tests of the generated protobuf code. The
expected encodings come from `Trace.encode` of
`@apollo/usage-reporting-protobuf` 4.1.2 in Node.js, and the expected
base64 from Node.js `Buffer.toString('base64')`.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_raises
from std.testing import assert_true
from gql_server.base64 import base64_decode, base64_encode
from gql_server.usage_reporting_protobuf import (
    Timestamp,
    Trace,
    TraceError,
    TraceLocation,
    TraceNode,
)

comptime SAMPLE = (
    "GgsIgOLPqgYQwLLNOyILCIDiz6oGEMCp0zpYgIl6cnhiUQoBYRoCQSFA6AdI0A9iOwoKYnJv"
    "a2VuTGlzdBoKW1N0cmluZyFdIUC4F0igH2IYEAFaFAoIPG1hc2tlZD4SBAgBEAQiAnt9agFB"
    "agVRdWVyeWIfCgFiGgZTdHJpbmdAiCdI8C5qBVF1ZXJ5cgVoZWxsb2ICEAD5AQAAAAAAAPA/"
)
"""The base64 of the protobufjs encoding of `_sample()`."""


def _node(mut trace: Trace, parent: Int, var node: TraceNode) -> Int:
    """Add a node under a parent."""
    var index = len(trace.nodes)
    trace.nodes.append(node^)
    trace.nodes[parent].child.append(index)
    return index


def _field(
    name: String, type: String, parent_type: String, start: Int, end: Int
) -> TraceNode:
    """A field node."""
    var node = TraceNode()
    node.response_name = name
    node.type = type
    node.parent_type = parent_type
    node.start_time = start
    node.end_time = end
    return node^


def _sample() -> Trace:
    """A trace with fields, a list item with an error, an alias, and an
    index 0."""
    var trace = Trace()
    trace.start_time = Timestamp(1700000000, 123000000)
    trace.end_time = Timestamp(1700000000, 125000000)
    trace.duration_ns = 2000000
    trace.field_execution_weight = 1
    var a = _node(trace, 0, _field("a", "A!", "Query", 1000, 2000))
    var list = _node(
        trace, a, _field("brokenList", "[String!]!", "A", 3000, 4000)
    )
    var item = TraceNode()
    item.index = 1
    var error = TraceError("<masked>")
    error.location.append(TraceLocation(1, 4))
    error.json = "{}"
    item.error.append(error^)
    _ = _node(trace, list, item^)
    var b = _field("b", "String", "Query", 5000, 6000)
    b.original_field_name = "hello"
    _ = _node(trace, 0, b^)
    var zero = TraceNode()
    zero.index = 0
    _ = _node(trace, 0, zero^)
    return trace^


def test_encode_matches_protobufjs() raises:
    var encoded = _sample().encode()
    assert_equal(base64_encode(encoded), SAMPLE)


def test_encode_empty_trace() raises:
    assert_equal(base64_encode(Trace().encode()), "GgAiAHIA")


def test_decode_round_trip() raises:
    var bytes = base64_decode(SAMPLE)
    var trace = Trace.decode(bytes)
    assert_true(trace.start_time == Timestamp(1700000000, 123000000))
    assert_true(trace.end_time == Timestamp(1700000000, 125000000))
    assert_equal(trace.duration_ns, 2000000)
    assert_equal(trace.field_execution_weight, 1.0)
    ref root = trace.nodes[0]
    assert_equal(len(root.child), 3)
    ref a = trace.nodes[root.child[0]]
    assert_equal(a.response_name.value(), "a")
    assert_false(Bool(a.index))
    assert_equal(a.type, "A!")
    assert_equal(a.parent_type, "Query")
    assert_equal(a.start_time, 1000)
    assert_equal(a.end_time, 2000)
    ref list = trace.nodes[a.child[0]]
    assert_equal(list.type, "[String!]!")
    ref item = trace.nodes[list.child[0]]
    assert_equal(item.index.value(), 1)
    assert_false(Bool(item.response_name))
    assert_equal(item.error[0].message, "<masked>")
    assert_true(item.error[0].location[0] == TraceLocation(1, 4))
    assert_equal(item.error[0].json, "{}")
    ref b = trace.nodes[root.child[1]]
    assert_equal(b.original_field_name, "hello")
    assert_equal(trace.nodes[root.child[2]].index.value(), 0)
    assert_equal(base64_encode(trace.encode()), SAMPLE)


def test_decode_oneof_keeps_the_last() raises:
    # A node with `index` 3, then `response_name` "x"; then one with
    # "y", then index 5.
    var bytes: List[UInt8] = [
        114,
        14,
        98,
        5,
        16,
        3,
        10,
        1,
        120,
        98,
        5,
        10,
        1,
        121,
        16,
        5,
    ]
    var trace = Trace.decode(bytes)
    ref first = trace.nodes[trace.nodes[0].child[0]]
    assert_equal(first.response_name.value(), "x")
    assert_false(Bool(first.index))
    ref second = trace.nodes[trace.nodes[0].child[1]]
    assert_equal(second.index.value(), 5)
    assert_false(Bool(second.response_name))


def test_decode_skips_unknown_fields() raises:
    # Trace: varint field 1, fixed64 field 2, length field 5, fixed32
    # field 6; a timestamp, a node, an error and a location with an
    # unknown field each; an error `time_ns`.
    var bytes: List[UInt8] = [
        8,
        1,
        17,
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        42,
        2,
        0,
        0,
        53,
        1,
        2,
        3,
        4,
        34,
        4,
        8,
        7,
        24,
        1,
        114,
        14,
        24,
        9,
        90,
        10,
        24,
        6,
        18,
        4,
        8,
        2,
        40,
        1,
        40,
        2,
    ]
    var trace = Trace.decode(bytes)
    assert_equal(trace.start_time.seconds, 7)
    ref root = trace.nodes[0]
    assert_equal(root.error[0].time_ns, 6)
    assert_equal(root.error[0].location[0].line, 2)
    assert_equal(root.error[0].location[0].column, 0)


def test_decode_errors() raises:
    var cases: List[List[UInt8]] = [
        [8],
        [8, 128],
        [8, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 1],
        [42, 5, 1],
        [17, 1, 2],
        [53, 1],
        [249, 1, 0, 0],
        [11],
    ]
    for ref bytes in cases:
        with assert_raises():
            _ = Trace.decode(bytes)


def test_encode_writes_error_time() raises:
    var trace = Trace()
    var error = TraceError("m")
    error.time_ns = 9
    trace.nodes[0].error.append(error^)
    var decoded = Trace.decode(trace.encode())
    assert_equal(decoded.nodes[0].error[0].time_ns, 9)
    assert_equal(decoded.nodes[0].error[0].message, "m")


def test_base64_padding() raises:
    var expected: List[String] = [
        "",
        "Zg==",
        "Zm8=",
        "Zm9v",
        "Zm9vYg==",
        "Zm9vYmE=",
        "Zm9vYmFy",
    ]
    var text = String("foobar")
    for length in range(7):
        var part = String(text[byte=0:length])
        assert_equal(base64_encode(part.as_bytes()), expected[length])
        var decoded = base64_decode(expected[length])
        assert_equal(String(unsafe_from_utf8=decoded), part)


def test_base64_alphabet() raises:
    var bytes = List[UInt8]()
    for value in range(256):
        bytes.append(UInt8(value))
    var text = base64_encode(bytes)
    assert_true(text.startswith("AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwd"))
    assert_true(text.endswith("+/w=="))
    var decoded = base64_decode(text)
    assert_equal(len(decoded), 256)
    for value in range(256):
        assert_equal(Int(decoded[value]), value)


def test_base64_decode_errors() raises:
    with assert_raises(contains="Invalid base64 length: 3"):
        _ = base64_decode("Zm9")
    with assert_raises(contains="Invalid base64 character: 46"):
        _ = base64_decode("Zm.v")
    with assert_raises(contains="Invalid base64 character: 126"):
        _ = base64_decode("Zm~v")
    with assert_raises(contains="Invalid base64 character: 61"):
        _ = base64_decode("Z=9v")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

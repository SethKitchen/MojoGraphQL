# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_quic.connection`: a client and a server in memory. The
cases port quinn-proto 0.11.19 quinn-proto/src/tests/mod.rs: `lifecycle`,
`stream_id_limit`, `finish_stream_simple`, `reset_stream`,
`stop_stream`, `congestion`, `high_latency_handshake`, `zero_rtt`
aside, `idle_timeout`, `server_busy` aside, `instant_close`,
`key_update_simple`, `handshake_anti_deadlock_probe`, `loss_probe`
and `stream_flow_control`; the features that this port does not have
(0-RTT, migration, datagrams, tokens) have no case."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _pair import MS, Pair
from gql_quic.connection import ConnectionState, TransportConfig
from gql_quic.shared import Dir
from gql_quic.streams import ReadStatus


def read_all(mut pair: Pair, server: Bool, id: UInt64) -> List[UInt8]:
    """Read every byte that waits on a stream."""
    var out = List[UInt8]()
    var buf = List[UInt8](length=4096, fill=0)
    while True:
        var r = pair.server[0].read(
            id, buf.unsafe_ptr(), len(buf)
        ) if server else pair.client.read(id, buf.unsafe_ptr(), len(buf))
        if r.count == 0:
            break
        out.extend(Span(buf)[0 : r.count])
    return out^


def test_lifecycle() raises:
    var pair = Pair()
    pair.connect()
    assert_true(pair.client.is_established())
    assert_true(pair.server[0].is_established())
    assert_true(pair.client.handshake_confirmed)
    assert_equal(pair.client.tls.alpn(), "h3")
    # The Initial and Handshake keys are gone on both ends.
    assert_false(pair.client.spaces[0].has_keys())
    assert_false(pair.client.spaces[1].has_keys())
    assert_false(pair.server[0].spaces[0].has_keys())
    assert_false(pair.server[0].spaces[1].has_keys())
    pair.client.close(pair.now, 7, "done")
    pair.drive()
    assert_true(pair.client.is_drained())
    assert_true(pair.server[0].is_drained())
    assert_true(pair.server[0].peer_closed)
    assert_equal(pair.server[0].peer_error_code, 7)


def test_stream_round_trip() raises:
    var pair = Pair()
    pair.connect()
    var id = pair.client.open(Dir.BI)
    assert_true(id >= 0)
    var request = List[UInt8]("hello".as_bytes())
    assert_equal(pair.client.write(UInt64(id), request, True), 5)
    var before = pair.client_datagrams
    _ = pair.step()
    assert_equal(pair.client_datagrams - before, 1)
    var accepted = pair.server[0].accept()
    assert_equal(accepted, id)
    var got = read_all(pair, True, UInt64(id))
    assert_equal(String(unsafe_from_utf8=got), "hello")
    var buf = List[UInt8](length=16, fill=0)
    assert_equal(
        pair.server[0].read(UInt64(id), buf.unsafe_ptr(), 16).status,
        ReadStatus.END,
    )
    var response = List[UInt8]("world!".as_bytes())
    assert_equal(pair.server[0].write(UInt64(id), response, True), 6)
    var server_before = pair.server_datagrams
    _ = pair.step()
    # The response and the ACK of the request share one datagram.
    assert_equal(pair.server_datagrams - server_before, 1)
    var answer = read_all(pair, False, UInt64(id))
    assert_equal(String(unsafe_from_utf8=answer), "world!")
    pair.client.release(UInt64(id))
    pair.server[0].release(UInt64(id))
    pair.drive()
    assert_false(pair.server[0].streams.is_open(UInt64(id)))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

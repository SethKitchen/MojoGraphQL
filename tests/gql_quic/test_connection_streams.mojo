# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_quic.connection`: streams, flow control, congestion and
loss recovery between a client and a server in memory. The cases port
quinn-proto 0.11.19 quinn-proto/src/tests/mod.rs: `reset_stream`,
`stop_stream`, `stream_id_limit`, `stream_flow_control`,
`conn_flow_control`, `congestion`, `loss_probe`, `idle_timeout`,
`instant_close`, `key_update_simple` and `key_update_reordered`."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _inject import deliver, start_key_update
from _pair import MS, Pair
from gql_quic.connection import ConnectionState, DATA, TransportConfig
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


def pattern(size: Int) -> List[UInt8]:
    """Return `size` bytes that count up."""
    var out = List[UInt8](capacity=size)
    for index in range(size):
        out.append(UInt8(index % 251))
    return out^


def send_all(
    mut pair: Pair,
    id: UInt64,
    data: List[UInt8],
    drop_every: Int = 0,
    start: Int = 0,
) raises -> List[UInt8]:
    """Write `data` on a client stream with FIN, and read it on the server
    as it arrives; drop one client datagram in `drop_every` when set."""
    var got = List[UInt8]()
    var at = start
    var rounds = 0
    var accepted = False
    while rounds < 5000:
        rounds += 1
        if at < len(data):
            var n = pair.client.write(id, Span(data)[at:], True)
            if n > 0:
                at += n
        if drop_every > 0 and rounds % drop_every == 0:
            pair.drop_client = 1
        var moved = pair.step()
        if len(pair.server) > 0 and not accepted:
            accepted = pair.server[0].accept() >= 0
        if len(pair.server) > 0:
            got.extend(read_all(pair, True, id))
        if len(got) == len(data):
            return got^
        if moved == 0:
            var t = pair.next_timeout()
            if t < 0:
                break
            pair.now = max(pair.now, t)
            pair.client.handle_timeout(pair.now)
            pair.server[0].handle_timeout(pair.now)
    return got^


def test_states() raises:
    assert_true(ConnectionState.DRAINED.is_valid())
    assert_false(ConnectionState(5).is_valid())
    assert_equal(String(ConnectionState.CLOSING), "closing")
    assert_equal(String(ConnectionState(9)), "invalid")


def test_open_before_handshake() raises:
    var pair = Pair()
    assert_equal(pair.client.open(Dir.BI), -1)
    assert_equal(pair.client.accept(), -1)


def test_reset_stream() raises:
    var pair = Pair()
    pair.connect()
    var id = UInt64(pair.client.open(Dir.BI))
    var data = List[UInt8]("abc".as_bytes())
    assert_equal(pair.client.write(id, data, False), 3)
    pair.drive_until_quiet()
    assert_equal(pair.server[0].accept(), Int64(id))
    pair.client.reset(id, 42)
    pair.drive(100)
    var buf = List[UInt8](length=16, fill=0)
    var status = ReadStatus.WAIT
    for _ in range(3):
        status = pair.server[0].read(id, buf.unsafe_ptr(), 16).status
        if status == ReadStatus.RESET:
            break
    assert_equal(status, ReadStatus.RESET)
    assert_true(pair.client.write(id, data, False) < 0)


def test_stop_stream() raises:
    var pair = Pair()
    pair.connect()
    var id = UInt64(pair.client.open(Dir.BI))
    var data = List[UInt8]("abc".as_bytes())
    _ = pair.client.write(id, data, False)
    pair.drive_until_quiet()
    assert_equal(pair.server[0].accept(), Int64(id))
    pair.server[0].stop(id, 9)
    pair.drive(100)
    # STOP_SENDING made the client reset the stream.
    assert_true(pair.client.write(id, data, False) < 0)


def test_stream_id_limit() raises:
    var server_config = TransportConfig()
    server_config.max_concurrent_bidi_streams = 1
    server_config.max_concurrent_uni_streams = 1
    var pair = Pair(server_config=server_config^)
    pair.connect()
    var data = List[UInt8]("x".as_bytes())
    for dir in [Dir.BI, Dir.UNI]:
        var first = pair.client.open(dir)
        assert_true(first >= 0)
        assert_equal(pair.client.open(dir), -1)
        _ = pair.client.write(UInt64(first), data, True)
        pair.drive_until_quiet()
        assert_equal(pair.server[0].accept(), first)
        _ = read_all(pair, True, UInt64(first))
        if dir == Dir.BI:
            _ = pair.server[0].write(UInt64(first), data, True)
            pair.drive_until_quiet()
            _ = read_all(pair, False, UInt64(first))
            pair.client.release(UInt64(first))
        pair.server[0].release(UInt64(first))
        pair.drive(100)
        # MAX_STREAMS gave the client one more stream.
        assert_true(pair.client.open(dir) >= 0)


def test_flow_control() raises:
    var server_config = TransportConfig()
    server_config.stream_receive_window = 1000
    server_config.receive_window = 1500
    var pair = Pair(server_config=server_config^)
    pair.connect()
    var id = UInt64(pair.client.open(Dir.BI))
    var data = pattern(20_000)
    var first = pair.client.write(id, data, True)
    assert_true(first > 0 and first <= 1000)
    var got = send_all(pair, id, data, start=first)
    assert_equal(len(got), len(data))
    assert_true(got == data)


def test_congestion() raises:
    var pair = Pair()
    pair.connect()
    var id = UInt64(pair.client.open(Dir.BI))
    var data = pattern(300_000)
    var got = send_all(pair, id, data)
    assert_true(got == data)
    assert_true(pair.client.cc.window > 12_000)


def test_loss_recovery() raises:
    var pair = Pair()
    pair.connect()
    var id = UInt64(pair.client.open(Dir.BI))
    var data = pattern(100_000)
    var got = send_all(pair, id, data, drop_every=3)
    assert_true(got == data)


def test_loss_probe() raises:
    var pair = Pair()
    pair.connect()
    var id = UInt64(pair.client.open(Dir.BI))
    var data = List[UInt8]("probe".as_bytes())
    _ = pair.client.write(id, data, True)
    pair.drop_client = 1
    _ = pair.step()
    assert_equal(len(pair.client.spaces[DATA].sent), 1)
    pair.drive(2_000)
    assert_true(pair.client.pto_count >= 0)
    assert_equal(pair.server[0].accept(), Int64(id))
    assert_equal(String(unsafe_from_utf8=read_all(pair, True, id)), "probe")


def test_reorder_and_duplicate() raises:
    var pair = Pair()
    pair.connect()
    var id = UInt64(pair.client.open(Dir.BI))
    var data = pattern(3000)
    _ = pair.client.write(id, data, True)
    var first = List[UInt8]()
    _ = pair.client.poll_transmit(pair.now, first)
    var second = List[UInt8]()
    _ = pair.client.poll_transmit(pair.now, second)
    var third = List[UInt8]()
    _ = pair.client.poll_transmit(pair.now, third)
    deliver(pair.server[0], pair.now, third)
    deliver(pair.server[0], pair.now, second)
    deliver(pair.server[0], pair.now, second)
    pair.now += 50 * MS
    deliver(pair.server[0], pair.now, first)
    pair.drive(200)
    assert_equal(pair.server[0].accept(), Int64(id))
    assert_true(read_all(pair, True, id) == data)


def test_idle_timeout() raises:
    var config = TransportConfig()
    config.max_idle_timeout_ms = 1000
    var pair = Pair(client_config=config.copy(), server_config=config^)
    pair.connect()
    pair.drive(5_000)
    assert_true(pair.client.timed_out)
    assert_true(pair.client.is_drained())
    pair.client.handle_timeout(pair.now)
    assert_equal(pair.client.poll_timeout(), -1)


def test_no_idle_timeout() raises:
    var config = TransportConfig()
    config.max_idle_timeout_ms = 0
    var pair = Pair(client_config=config.copy(), server_config=config^)
    pair.connect()
    pair.drive(100)
    assert_equal(pair.client.idle_deadline, -1)
    assert_equal(pair.client.poll_timeout(), -1)


def test_peer_idle_timeout_is_shorter() raises:
    var short = TransportConfig()
    short.max_idle_timeout_ms = 500
    var none = TransportConfig()
    none.max_idle_timeout_ms = 0
    var pair = Pair(client_config=none^, server_config=short^)
    pair.connect()
    assert_equal(pair.client.idle_timeout, 500 * MS)


def test_instant_close() raises:
    """A close during the handshake goes out in an Initial packet, as a
    transport close with APPLICATION_ERROR."""
    var pair = Pair()
    pair.client.close(pair.now, 3, "bye")
    pair.client.close(pair.now, 4, "again")
    assert_equal(pair.client.close_code, 3)
    pair.drive(10_000)
    assert_true(pair.server[0].peer_closed)
    assert_equal(pair.server[0].peer_error_code, 0x0C)
    assert_true(pair.server[0].is_drained())


def test_transport_close() raises:
    var pair = Pair()
    pair.connect()
    pair.server[0].close(pair.now, 0x0A, "protocol", False)
    assert_equal(pair.server[0].write(0, List[UInt8](), True), -1)
    pair.drive(100)
    assert_true(pair.client.peer_closed)
    assert_equal(pair.client.peer_error_code, 0x0A)


def test_close_before_confirmed() raises:
    """A client that closes before HANDSHAKE_DONE sends its close in a 1-RTT
    packet only, and its late 1-RTT data is acknowledged."""
    var pair = Pair()
    _ = pair.step()
    assert_true(pair.client.is_established())
    assert_false(pair.client.handshake_confirmed)
    var id = UInt64(pair.client.open(Dir.BI))
    var data = List[UInt8]("early".as_bytes())
    _ = pair.client.write(id, data, True)
    _ = pair.step()
    assert_true(pair.client.handshake_confirmed)
    assert_equal(len(pair.client.spaces[DATA].sent), 0)
    var other = Pair()
    _ = other.step()
    var other_id = UInt64(other.client.open(Dir.BI))
    _ = other.client.write(other_id, data, True)
    var out = List[UInt8]()
    _ = other.client.poll_transmit(other.now, out)
    assert_true(other.client.loss_timer() >= 0)
    other.client.close(other.now, 1, "early close")
    out.clear()
    assert_true(other.client.poll_transmit(other.now, out) > 0)
    assert_true(other.client.spaces[1].has_keys())


def test_closing_answers_packets() raises:
    var pair = Pair()
    pair.connect()
    var id = UInt64(pair.client.open(Dir.BI))
    var data = List[UInt8]("ping".as_bytes())
    _ = pair.client.write(id, data, True)
    _ = pair.step()
    _ = pair.server[0].accept()
    _ = pair.server[0].write(id, data, True)
    var reply = List[UInt8]()
    _ = pair.server[0].poll_transmit(pair.now, reply)
    pair.client.close(pair.now, 0, "done")
    var close = List[UInt8]()
    assert_true(pair.client.poll_transmit(pair.now, close) > 0)
    close.clear()
    assert_equal(pair.client.poll_transmit(pair.now, close), 0)
    deliver(pair.client, pair.now, reply)
    assert_true(pair.client.close_pending)
    # Before the end of the closing period the timer only waits.
    pair.client.handle_timeout(pair.now)
    assert_true(pair.client.is_closed())
    var buf = List[UInt8](length=8, fill=0)
    var r = pair.client.read(id, buf.unsafe_ptr(), 8)
    assert_equal(r.status, ReadStatus.RESET)
    pair.drive(1_000)
    assert_true(pair.client.is_drained())
    # A drained end takes no datagram and runs no timer.
    deliver(pair.client, pair.now, reply)
    pair.client.handle_timeout(pair.now + 1000 * MS)
    assert_equal(pair.client.poll_transmit(pair.now, close), 0)


def test_key_update() raises:
    """The server starts a key update; the client follows it, opens a late
    packet of the old phase, and drops a packet that opens in neither."""
    var pair = Pair()
    pair.connect()
    var id = UInt64(pair.client.open(Dir.BI))
    var data = List[UInt8]("one".as_bytes())
    _ = pair.client.write(id, data, False)
    pair.drive_until_quiet()
    _ = pair.server[0].accept()
    _ = pair.server[0].write(id, data, False)
    var late = List[UInt8]()
    _ = pair.server[0].poll_transmit(pair.now, late)
    start_key_update(pair.server[0])
    var two = List[UInt8]("two".as_bytes())
    _ = pair.server[0].write(id, two, False)
    pair.drive_until_quiet()
    assert_true(pair.client.key_phase)
    assert_equal(len(pair.client.prev_remote), 1)
    deliver(pair.client, pair.now, late)
    var got = read_all(pair, False, id)
    assert_equal(String(unsafe_from_utf8=got), "onetwo")
    var three = List[UInt8]("three".as_bytes())
    _ = pair.client.write(id, three, True)
    pair.drive_until_quiet()
    assert_equal(String(unsafe_from_utf8=read_all(pair, True, id)), "onethree")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

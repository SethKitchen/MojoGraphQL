# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_quic.connection`: packets and frames that a test writes
by hand, from one end of a pair to the other. The cases port quinn-proto
0.11.19 quinn-proto/src/tests/mod.rs: `version_negotiate_client`,
`reject_self_signed_server_cert` aside, `malformed_token_len`,
`cid_retirement`, `cid_rotation`, `path_challenge_retransmit`,
`handshake_done_from_client` (`client_sends_handshake_done`), `ack_frame_ecn`
and `stream_id_limit`; and the checks of `handle_packet` and
`process_payload` in quinn-proto/src/connection/mod.rs."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _inject import deliver, packet, seal_packet, start_key_update
from _pair import MS, Pair
from gql_quic.cid import ConnectionId, ResetToken
from gql_quic.connection import (
    DATA,
    HANDSHAKE,
    INITIAL,
    ConnectionState,
    TransportConfig,
)
from gql_quic.error import TransportErrorCode
from gql_quic.frame import (
    write_ack,
    write_connection_close,
    write_crypto_header,
    write_handshake_done,
    write_max_data,
    write_new_connection_id,
    write_new_token,
    write_path_challenge,
    write_ping,
)
from gql_quic.packet import (
    LongType,
    QUIC_VERSION_1,
    set_length,
    write_long_header,
)
from gql_quic.range_set import RangeSet
from gql_quic.shared import Dir


def ping() -> List[UInt8]:
    """Return a payload of one PING frame."""
    var out = List[UInt8]()
    write_ping(out)
    return out^


def connected() raises -> Pair:
    """Return a pair after the handshake."""
    var pair = Pair()
    pair.connect()
    return pair^


def raw_long(first: UInt8, version: UInt32, pair: Pair) -> List[UInt8]:
    """Return the start of a long header to the client of a pair."""
    var out = List[UInt8]()
    out.append(first)
    for shift in [24, 16, 8, 0]:
        out.append(UInt8((version >> UInt32(shift)) & 0xFF))
    pair.client.local_cid.encode_long(out)
    pair.client.remote_cid.encode_long(out)
    return out^


def test_version_negotiation() raises:
    """A client without a server connection ID stops on Version
    Negotiation; other ends ignore it."""
    var pair = Pair()
    var vn = raw_long(0xC0, 0, pair)
    for b in [0xFF, 0x00, 0x00, 0x1D]:
        vn.append(UInt8(b))
    deliver(pair.client, pair.now, vn)
    assert_true(pair.client.is_drained())
    var done = connected()
    var again = raw_long(0xC0, 0, done)
    deliver(done.client, done.now, again)
    deliver(done.server[0], done.now, again)
    assert_true(done.client.is_established())
    assert_true(done.server[0].is_established())


def test_ignored_long_packets() raises:
    """Packets of another version, Retry and 0-RTT packets are dropped."""
    var pair = connected()
    var before = pair.client.datagrams_received
    var other = raw_long(0xC0, 0xFF00001D, pair)
    other.resize(len(other) + 40, 7)
    deliver(pair.client, pair.now, other)
    var retry = raw_long(0xF0, QUIC_VERSION_1, pair)
    retry.resize(len(retry) + 24, 9)
    deliver(pair.client, pair.now, retry)
    var zero = List[UInt8]()
    var marks = write_long_header(
        zero,
        LongType.ZERO_RTT,
        QUIC_VERSION_1,
        pair.server[0].local_cid,
        pair.client.local_cid,
        List[UInt8](),
        0,
        1,
    )
    zero.resize(len(zero) + 40, 0)
    set_length(zero, marks, len(zero))
    deliver(pair.server[0], pair.now, zero)
    # A Handshake packet after the Handshake keys are gone is dropped too.
    var late = List[UInt8]()
    marks = write_long_header(
        late,
        LongType.HANDSHAKE,
        QUIC_VERSION_1,
        pair.client.local_cid,
        pair.server[0].local_cid,
        List[UInt8](),
        0,
        1,
    )
    late.resize(len(late) + 40, 0)
    set_length(late, marks, len(late))
    deliver(pair.client, pair.now, late)
    assert_equal(pair.client.datagrams_received, before + 3)
    assert_true(pair.client.is_established())
    assert_true(pair.server[0].is_established())


def test_undecodable_datagrams() raises:
    var pair = connected()
    # A clear fixed bit does not parse.
    var bad: List[UInt8] = [0x00, 1, 2]
    deliver(pair.client, pair.now, bad)
    # Too short for a header protection sample.
    var short: List[UInt8] = [0x40]
    short.extend(pair.client.local_cid.bytes())
    short.resize(len(short) + 5, 0)
    deliver(pair.client, pair.now, short)
    # A tag that does not verify.
    # Forty PING frames: the tag ends past the header protection sample,
    # so a changed tag leaves the key phase bit as it was.
    var p = List[UInt8](length=40, fill=1)
    deliver(
        pair.client, pair.now, packet(pair.server[0], DATA, p, corrupt=True)
    )
    # Neither key phase opens it, before and after a key update.
    deliver(
        pair.client,
        pair.now,
        packet(pair.server[0], DATA, p, flip_phase=True, corrupt=True),
    )
    start_key_update(pair.server[0])
    deliver(pair.client, pair.now, packet(pair.server[0], DATA, p))
    assert_true(pair.client.key_phase)
    deliver(
        pair.client,
        pair.now,
        packet(pair.server[0], DATA, p, flip_phase=True, corrupt=True),
    )
    assert_true(pair.client.is_established())
    assert_true(pair.client.key_phase)


def test_reserved_bits() raises:
    var pair = connected()
    var p = ping()
    deliver(
        pair.client, pair.now, packet(pair.server[0], DATA, p, first_or=0x18)
    )
    assert_true(pair.client.is_closed())
    assert_equal(
        pair.client.close_code, TransportErrorCode.PROTOCOL_VIOLATION.value
    )


def test_frame_not_allowed_in_handshake() raises:
    """A Handshake packet cannot carry MAX_DATA; the close names it."""
    var pair = Pair()
    _ = pair.step()
    var payload = List[UInt8]()
    write_max_data(payload, 100)
    deliver(pair.client, pair.now, packet(pair.server[0], HANDSHAKE, payload))
    assert_true(pair.client.is_closed())
    assert_equal(pair.client.close_frame_type, 0x10)
    pair.drive(100)
    assert_true(pair.server[0].peer_closed)
    assert_equal(
        pair.server[0].peer_error_code,
        TransportErrorCode.PROTOCOL_VIOLATION.value,
    )


def test_handshake_done_from_client() raises:
    var pair = connected()
    var payload = List[UInt8]()
    write_handshake_done(payload)
    deliver(pair.server[0], pair.now, packet(pair.client, DATA, payload))
    assert_true(pair.server[0].is_closed())


def test_new_token() raises:
    """A client ignores NEW_TOKEN; a server closes on it."""
    var pair = connected()
    var payload = List[UInt8]()
    var token: List[UInt8] = [1, 2, 3]
    write_new_token(payload, token)
    deliver(pair.client, pair.now, packet(pair.server[0], DATA, payload))
    assert_true(pair.client.is_established())
    deliver(pair.server[0], pair.now, packet(pair.client, DATA, payload))
    assert_true(pair.server[0].is_closed())


def test_crypto_buffer_exceeded() raises:
    var pair = connected()
    var payload = List[UInt8]()
    write_crypto_header(payload, 70_000, 1)
    payload.append(0)
    deliver(pair.client, pair.now, packet(pair.server[0], DATA, payload))
    assert_equal(
        pair.client.close_code,
        TransportErrorCode.CRYPTO_BUFFER_EXCEEDED.value,
    )


def acks(start: UInt64, end: UInt64) -> RangeSet:
    """Return a range set of `[start, end)`."""
    var r = RangeSet()
    _ = r.insert(start, end)
    return r^


def test_ack_ecn_and_rtt_sample() raises:
    """An ACK_ECN frame acknowledges like ACK. An ACK whose largest packet
    carried only an ACK frame gives no RTT sample."""
    var pair = connected()
    var id = UInt64(pair.client.open(Dir.BI))
    var data = List[UInt8]("x".as_bytes())
    _ = pair.client.write(id, data, False)
    var out = List[UInt8]()
    _ = pair.client.poll_transmit(pair.now, out)
    var eliciting = pair.client.spaces[DATA].next_pn - 1
    # The server's PING makes the client send an ACK-only packet.
    var p = ping()
    deliver(pair.client, pair.now, packet(pair.server[0], DATA, p))
    pair.now += 30 * MS
    out.clear()
    assert_true(pair.client.poll_transmit(pair.now, out) > 0)
    var ack_only = pair.client.spaces[DATA].next_pn - 1
    assert_equal(ack_only, eliciting + 1)
    var smoothed = pair.client.rtt.get()
    var payload = List[UInt8]()
    write_ack(payload, acks(eliciting, ack_only + 1), 0, True, 1, 0, 0)
    deliver(pair.client, pair.now, packet(pair.server[0], DATA, payload))
    assert_equal(len(pair.client.spaces[DATA].sent), 0)
    assert_equal(pair.client.rtt.get(), smoothed)


def test_ack_of_unsent_packet() raises:
    var pair = connected()
    var payload = List[UInt8]()
    var next = pair.client.spaces[DATA].next_pn
    write_ack(payload, acks(0, next + 10), 0)
    deliver(pair.client, pair.now, packet(pair.server[0], DATA, payload))
    assert_equal(
        pair.client.close_code, TransportErrorCode.PROTOCOL_VIOLATION.value
    )


def new_cid(mut out: List[UInt8], seq: UInt64, retire: UInt64) -> ConnectionId:
    """Append a NEW_CONNECTION_ID frame; return its connection ID."""
    var cid = ConnectionId.random(8)
    write_new_connection_id(out, seq, retire, cid, ResetToken.random())
    return cid


def test_new_connection_id() raises:
    """The client keeps one spare ID of the server, ignores repeats and old
    sequence numbers, and moves to the lowest ID that a retirement keeps."""
    var pair = connected()
    var payload = List[UInt8]()
    _ = new_cid(payload, 3, 0)
    _ = new_cid(payload, 3, 0)
    _ = new_cid(payload, 0, 0)
    deliver(pair.client, pair.now, packet(pair.server[0], DATA, payload))
    assert_equal(len(pair.client._peer_cids), 1)
    payload.clear()
    var one = new_cid(payload, 1, 1)
    deliver(pair.client, pair.now, packet(pair.server[0], DATA, payload))
    assert_true(pair.client.is_established())
    assert_equal(pair.client.remote_cid_seq, 1)
    assert_true(pair.client.remote_cid == one)
    assert_equal(len(pair.client._retire_queue), 1)
    payload.clear()
    var four = new_cid(payload, 4, 4)
    deliver(pair.client, pair.now, packet(pair.server[0], DATA, payload))
    assert_equal(pair.client.remote_cid_seq, 4)
    assert_true(pair.client.remote_cid == four)
    assert_equal(len(pair.client._peer_cids), 0)
    # Of two IDs that a retirement keeps, the lower one is used.
    payload.clear()
    var five = new_cid(payload, 5, 0)
    deliver(pair.client, pair.now, packet(pair.server[0], DATA, payload))
    payload.clear()
    _ = new_cid(payload, 6, 5)
    deliver(pair.client, pair.now, packet(pair.server[0], DATA, payload))
    assert_equal(pair.client.remote_cid_seq, 5)
    assert_true(pair.client.remote_cid == five)
    # The RETIRE_CONNECTION_ID frames are lost once, and go out again.
    pair.drop_client = 1
    pair.drive(2_000)
    assert_equal(len(pair.client._retire_queue), 0)
    assert_true(pair.client.is_established())
    assert_true(pair.server[0].is_established())


def test_too_many_connection_ids() raises:
    var pair = connected()
    var payload = List[UInt8]()
    _ = new_cid(payload, 1, 0)
    _ = new_cid(payload, 2, 0)
    deliver(pair.client, pair.now, packet(pair.server[0], DATA, payload))
    assert_equal(
        pair.client.close_code,
        TransportErrorCode.CONNECTION_ID_LIMIT_ERROR.value,
    )


def test_retire_prior_to_above_sequence() raises:
    """Retire Prior To above the Sequence Number is a frame encoding error
    (RFC 9000 section 19.15), so a retirement always keeps one ID."""
    var pair = connected()
    var payload = List[UInt8]()
    _ = new_cid(payload, 1, 5)
    deliver(pair.client, pair.now, packet(pair.server[0], DATA, payload))
    assert_equal(
        pair.client.close_code, TransportErrorCode.FRAME_ENCODING_ERROR.value
    )


def test_many_retirements() raises:
    """More RETIRE_CONNECTION_ID frames than one packet holds."""
    var pair = connected()
    var seq = UInt64(1)
    for _ in range(14):
        var payload = List[UInt8]()
        for _ in range(40):
            _ = new_cid(payload, seq, seq)
            seq += 1
        deliver(pair.client, pair.now, packet(pair.server[0], DATA, payload))
    assert_equal(len(pair.client._retire_queue), 560)
    var out = List[UInt8]()
    assert_true(pair.client.poll_transmit(pair.now, out) > 0)
    assert_true(len(pair.client._retire_queue) > 0)
    pair.drive(500)
    assert_equal(len(pair.client._retire_queue), 0)


def test_path_challenge() raises:
    """Each PATH_CHALLENGE gets a PATH_RESPONSE, in as many packets as
    they need."""
    var pair = connected()
    var payload = List[UInt8]()
    for index in range(140):
        write_path_challenge(payload, UInt64(index))
    deliver(pair.client, pair.now, packet(pair.server[0], DATA, payload))
    var out = List[UInt8]()
    assert_true(pair.client.poll_transmit(pair.now, out) > 0)
    assert_true(len(pair.client._path_responses) > 0)
    pair.drive(500)
    assert_equal(len(pair.client._path_responses), 0)


def test_close_while_handshake_completes() raises:
    """A Handshake packet that ends the handshake and closes: the client
    completes the handshake, and stays draining."""
    var pair = Pair()
    pair.drop_server = 100
    _ = pair.step()
    ref server = pair.server[0]
    ref initial = server.spaces[INITIAL].crypto_send
    var hello = List[UInt8]()
    write_crypto_header(hello, 0, initial.offset)
    hello.extend(initial.get(0, initial.offset))
    deliver(pair.client, pair.now, packet(server, INITIAL, hello))
    assert_true(pair.client.spaces[HANDSHAKE].has_keys())
    ref flight = server.spaces[HANDSHAKE].crypto_send
    var payload = List[UInt8]()
    write_crypto_header(payload, 0, flight.offset)
    payload.extend(flight.get(0, flight.offset))
    write_connection_close(payload, TransportErrorCode.NO_ERROR, 0, "closing")
    deliver(pair.client, pair.now, packet(server, HANDSHAKE, payload))
    assert_true(pair.client.handshake_done)
    assert_equal(pair.client.state, ConnectionState.DRAINING)


def test_error_after_close_in_one_datagram() raises:
    """A packet after a CONNECTION_CLOSE in the same datagram is still
    read, and its error does not close the connection twice."""
    var pair = Pair()
    _ = pair.step()
    var close = List[UInt8]()
    write_connection_close(close, TransportErrorCode.NO_ERROR, 0, "bye")
    var datagram = List[UInt8]()
    seal_packet(pair.server[0], HANDSHAKE, close, datagram)
    var p = ping()
    seal_packet(pair.server[0], HANDSHAKE, p, datagram, first_or=0x0C)
    deliver(pair.client, pair.now, datagram)
    assert_true(pair.client.peer_closed)
    assert_equal(pair.client.state, ConnectionState.DRAINING)


def test_ack_of_the_first_packet_only() raises:
    """Packets after the largest acknowledged one stay in flight; one
    before it waits for the time threshold, then is lost and sent again."""
    var pair = connected()
    var id = UInt64(pair.client.open(Dir.BI))
    var datagrams = List[List[UInt8]]()
    for word in ["one", "two", "six"]:
        var data = List[UInt8](word.as_bytes())
        _ = pair.client.write(id, data, False)
        var out = List[UInt8]()
        _ = pair.client.poll_transmit(pair.now, out)
        datagrams.append(out^)
    var first = pair.client.spaces[DATA].sent[0].pn
    var payload = List[UInt8]()
    write_ack(payload, acks(first, first + 1), 0)
    deliver(pair.client, pair.now, packet(pair.server[0], DATA, payload))
    assert_equal(len(pair.client.spaces[DATA].sent), 2)
    assert_equal(pair.client.spaces[DATA].loss_time, -1)
    payload.clear()
    write_ack(payload, acks(first + 2, first + 3), 0)
    deliver(pair.client, pair.now, packet(pair.server[0], DATA, payload))
    assert_equal(len(pair.client.spaces[DATA].sent), 1)
    var t = pair.client.loss_timer()
    assert_true(t >= 0)
    assert_equal(t, pair.client.spaces[DATA].loss_time)
    pair.now = t
    pair.client.handle_timeout(pair.now)
    assert_equal(len(pair.client.spaces[DATA].sent), 0)
    deliver(pair.server[0], pair.now, datagrams[0])
    deliver(pair.server[0], pair.now, datagrams[2])
    pair.drive(500)
    _ = pair.server[0].accept()
    var buf = List[UInt8](length=16, fill=0)
    var r = pair.server[0].read(id, buf.unsafe_ptr(), 16)
    assert_equal(r.count, 9)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

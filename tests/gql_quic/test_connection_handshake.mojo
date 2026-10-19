# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_quic.connection`: the handshake, its failures, the
transport parameters, the anti-amplification limit and the probes of the
handshake. The cases port quinn-proto 0.11.19 quinn-proto/src/tests/mod.rs:
`reject_self_signed_server_cert` (`reject_missing_client_cert` aside),
`handshake_anti_deadlock_probe`, `server_hs_retransmit`,
`high_latency_handshake` and `initial_retransmit`; and the transport
parameter checks of quinn-proto/src/connection/mod.rs
`handle_peer_params`."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _inject import deliver, packet
from _pair import MS, Pair
from gql_tls.openssl import OpenSsl, TlsCall, TlsFaults
from gql_quic.cid import ConnectionId
from gql_quic.connection import (
    DATA,
    HANDSHAKE,
    INITIAL,
    Connection,
    TransportConfig,
    _level_space,
    _space_level,
)
from gql_quic.error import TransportErrorCode
from gql_quic.frame import write_ack, write_crypto_header
from gql_quic.packet import parse_header
from gql_quic.range_set import RangeSet
from gql_quic.shared import Dir
from gql_quic.tls import Level, QuicTls, Secret
from gql_quic.transport_params import TransportParameters


def test_levels() raises:
    assert_equal(_level_space(Level.INITIAL), INITIAL)
    assert_equal(_level_space(Level.EARLY), -1)
    assert_equal(_level_space(Level.HANDSHAKE), HANDSHAKE)
    assert_equal(_level_space(Level.APPLICATION), DATA)
    assert_true(_space_level(INITIAL) == Level.INITIAL)
    assert_true(_space_level(HANDSHAKE) == Level.HANDSHAKE)
    assert_true(_space_level(DATA) == Level.APPLICATION)


def test_early_secret_is_ignored() raises:
    """This port has no 0-RTT: a secret of the early level installs
    nothing."""
    var pair = Pair()
    var secret = List[UInt8](length=32, fill=1)
    pair.client.tls._bridge[].secrets.append(Secret(Level.EARLY, True, secret^))
    pair.client._drive_tls(pair.now)
    assert_equal(len(pair.client._pending_local[DATA]), 0)
    assert_false(pair.client.is_closed())


def test_certificate_does_not_verify() raises:
    var pair = Pair(host="example.com")
    pair.drive(100)
    assert_true(pair.client.tls_failed)
    assert_true(pair.client.close_reason.find("did not verify") >= 0)
    assert_true(pair.client.close_code >= TransportErrorCode.crypto(0).value)
    assert_true(pair.server[0].peer_closed)


def test_handshake_fails_without_alert() raises:
    var pair = Pair()
    var faulty = OpenSsl()
    faulty.faults = TlsFaults(TlsCall.HANDSHAKE, 0, -1)
    var client = Connection.client(
        TransportConfig(),
        pair.crypto,
        QuicTls(faulty^),
        pair.cctx.ctx,
        "localhost",
        True,
        pair.now,
    )
    assert_true(client.tls_failed)
    assert_equal(client.close_code, TransportErrorCode.INTERNAL_ERROR.value)
    assert_equal(client.close_reason.find("did not verify"), -1)


def test_wrong_source_connection_id() raises:
    """A server that expects another Source Connection ID refuses the
    transport parameters of the client."""
    var pair = Pair()
    # The ClientHello, with its hybrid key share, fills two datagrams.
    var out = List[UInt8]()
    _ = pair.client.poll_transmit(pair.now, out)
    var rest = List[UInt8]()
    _ = pair.client.poll_transmit(pair.now, rest)
    var header = parse_header(out, 0, 8)
    var server = Connection.server(
        TransportConfig(),
        pair.crypto,
        QuicTls(OpenSsl()),
        pair.sctx.ctx,
        header.dcid,
        ConnectionId.random(8),
        pair.now,
    )
    deliver(server, pair.now, out)
    deliver(server, pair.now, rest)
    assert_true(server.is_closed())
    assert_equal(
        server.close_code,
        TransportErrorCode.TRANSPORT_PARAMETER_ERROR.value,
    )


def accepts(mut c: Connection, params: TransportParameters) -> Bool:
    """Return True if an end takes the transport parameters."""
    var data = List[UInt8]()
    params.encode(data)
    try:
        c._apply_params(data)
        return True
    except:
        return False


def test_transport_parameters() raises:
    var pair = Pair()
    ref client = pair.client
    var params = TransportParameters()
    assert_false(accepts(client, params))
    params.initial_src_cid = ConnectionId.random(8)
    assert_false(accepts(client, params))
    params.initial_src_cid = client.remote_cid
    assert_false(accepts(client, params))
    params.original_dst_cid = ConnectionId.random(8)
    assert_false(accepts(client, params))
    params.original_dst_cid = client.original_dcid
    params.max_idle_timeout = 0
    assert_true(accepts(client, params))
    assert_equal(client.idle_timeout, 30_000 * MS)
    params.max_idle_timeout = 60_000
    assert_true(accepts(client, params))
    assert_equal(client.idle_timeout, 30_000 * MS)
    params.max_idle_timeout = 10_000
    assert_true(accepts(client, params))
    assert_equal(client.idle_timeout, 10_000 * MS)


def test_amplification_limit() raises:
    """A server that hears nothing more from the client sends at most
    three times what it received, then stops its timer."""
    var pair = Pair()
    pair.drop_server = 1000
    _ = pair.step()
    pair.drop_client = 1000
    pair.drive(20_000)
    ref server = pair.server[0]
    assert_true(server.bytes_sent <= 3 * server.bytes_received)
    assert_true(server.bytes_sent > server.bytes_received)
    assert_equal(server.loss_timer(), -1)
    var out = List[UInt8]()
    assert_equal(server.poll_transmit(pair.now, out), 0)


def server_initial(mut pair: Pair, hello: Bool) -> List[UInt8]:
    """Return an Initial packet of the server that acknowledges the first
    Initial of the client, with the ServerHello when `hello` is set."""
    ref server = pair.server[0]
    var payload = List[UInt8]()
    var ranges = RangeSet()
    _ = ranges.insert(0, pair.client.spaces[INITIAL].next_pn)
    write_ack(payload, ranges, 0)
    if hello:
        ref initial = server.spaces[INITIAL].crypto_send
        write_crypto_header(payload, 0, initial.offset)
        payload.extend(initial.get(0, initial.offset))
    return packet(server, INITIAL, payload)


def test_anti_deadlock_probe() raises:
    """A client with nothing in flight before the handshake ends probes
    the server: in a Handshake packet once it has the Handshake keys, and
    in an Initial packet before."""
    for hello in [True, False]:
        var pair = Pair()
        pair.drop_server = 1000
        _ = pair.step()
        deliver(pair.client, pair.now, server_initial(pair, hello))
        assert_equal(pair.client.spaces[INITIAL].ack_eliciting_in_flight, 0)
        assert_equal(pair.client.spaces[HANDSHAKE].has_keys(), hello)
        var t = pair.client.loss_timer()
        assert_true(t > pair.now)
        pair.now = t
        pair.client.handle_timeout(pair.now)
        var sent = pair.client.spaces[INITIAL].next_pn
        var out = List[UInt8]()
        assert_true(pair.client.poll_transmit(pair.now, out) > 0)
        if hello:
            assert_equal(pair.client.spaces[HANDSHAKE].next_pn, 1)
        else:
            assert_equal(len(out), 1200)
            assert_equal(pair.client.spaces[INITIAL].next_pn, sent + 1)


def test_server_handshake_retransmit() raises:
    """The flight of the server is lost twice, and the handshake ends."""
    var pair = Pair()
    pair.drop_server = 2
    pair.connect()
    for _ in range(10):
        if pair.client.handshake_confirmed:
            break
        pair.drive(1_000)
    assert_true(pair.client.is_established())
    assert_true(pair.server[0].is_established())


def test_large_initial_has_no_padding() raises:
    """An Initial datagram of 1452 bytes needs no padding."""
    var config = TransportConfig()
    config.datagram_size = 1452
    var pair = Pair(client_config=config^)
    var out = List[UInt8]()
    assert_true(pair.client.poll_transmit(pair.now, out) > 1200)
    pair.connect()
    assert_true(pair.client.is_established())


def test_lost_handshake_done() raises:
    var pair = Pair()
    _ = pair.step()
    pair.drop_server = 1
    _ = pair.step()
    assert_false(pair.client.handshake_confirmed)
    pair.drive(3_000)
    assert_true(pair.client.handshake_confirmed)


def test_no_probe_before_confirmed() raises:
    """With only 1-RTT packets in flight before the handshake is
    confirmed, the client runs no probe timer (RFC 9002 appendix A.8)."""
    var pair = Pair()
    _ = pair.step()
    var id = UInt64(pair.client.open(Dir.BI))
    var data = List[UInt8]("x".as_bytes())
    _ = pair.client.write(id, data, False)
    var out = List[UInt8]()
    _ = pair.client.poll_transmit(pair.now, out)
    var payload = List[UInt8]()
    var ranges = RangeSet()
    _ = ranges.insert(0, pair.client.spaces[HANDSHAKE].next_pn)
    write_ack(payload, ranges, 0)
    deliver(pair.client, pair.now, packet(pair.server[0], HANDSHAKE, payload))
    assert_equal(pair.client.spaces[HANDSHAKE].ack_eliciting_in_flight, 0)
    assert_equal(pair.client.spaces[DATA].ack_eliciting_in_flight, 1)
    assert_equal(pair.client.loss_timer(), -1)


def test_packet_without_frames_is_dropped() raises:
    """A space whose work writes no frame, and that has no ACK frame to
    send, sends no packet: a queued stream that is gone writes nothing."""
    var pair = Pair()
    _ = pair.step()
    pair.client.streams.send_queue.append(999)
    var before = pair.client.spaces[DATA].next_pn
    var out = List[UInt8]()
    assert_true(pair.client.poll_transmit(pair.now, out) > 0)
    assert_equal(pair.client.spaces[DATA].next_pn, before)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

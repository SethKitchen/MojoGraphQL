# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_quic.transport_params`.

Upstream: quinn-proto 0.11.19 (8192ed3)
quinn-proto/src/transport_parameters.rs, the `test` module: `coding`,
`reserved_transport_parameter_ignored_when_read`,
`read_semantic_validation`, `read_length_mismatch`,
`read_min_ack_delay_length_mismatch` and
`read_preferred_address_length_mismatch`. The cases that use
`max_datagram_frame_size` and `min_ack_delay`, which are not ported, use
an integer parameter in their place. `reserved_transport_parameter_
generate_reserved_id` and `resumption_params_validation` test code that is
not ported. The other tests cover each check of `read`.
"""

from gql_quic.cid import ConnectionId, ResetToken
from gql_quic.transport_params import (
    ACK_DELAY_EXPONENT,
    ACTIVE_CONNECTION_ID_LIMIT,
    DISABLE_ACTIVE_MIGRATION,
    GREASE_QUIC_BIT,
    INITIAL_MAX_DATA,
    INITIAL_MAX_STREAMS_BIDI,
    INITIAL_MAX_STREAMS_UNI,
    INITIAL_SOURCE_CONNECTION_ID,
    MAX_ACK_DELAY,
    MAX_IDLE_TIMEOUT,
    MAX_UDP_PAYLOAD_SIZE,
    ORIGINAL_DESTINATION_CONNECTION_ID,
    PREFERRED_ADDRESS,
    RETRY_SOURCE_CONNECTION_ID,
    STATELESS_RESET_TOKEN,
    TransportParameters,
)
from gql_quic.varint import write_varint
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime MALFORMED = "TRANSPORT_PARAMETER_ERROR: malformed"
comptime ILLEGAL = "TRANSPORT_PARAMETER_ERROR: illegal value"


def _bytes(*values: Int) -> List[UInt8]:
    var out = List[UInt8]()
    for v in values:
        out.append(UInt8(v))
    return out^


def _param(mut out: List[UInt8], id: UInt64, value: List[UInt8]):
    write_varint(out, id)
    write_varint(out, UInt64(len(value)))
    out.extend(Span(value))


def _int_param(mut out: List[UInt8], id: UInt64, value: UInt64):
    var v = List[UInt8]()
    write_varint(v, value)
    _param(out, id, v)


def _error(data: List[UInt8], from_server: Bool) -> String:
    try:
        _ = TransportParameters.decode(Span(data), from_server)
    except e:
        return String(e)
    return "no error"


def _preferred_address(
    v4: Bool, v6: Bool, cid: List[UInt8], token_len: Int = 16
) -> List[UInt8]:
    var out = List[UInt8]()
    if v4:
        out.extend(Span(_bytes(127, 0, 0, 1, 0, 42)))
    else:
        out.extend(Span(List[UInt8](length=6, fill=0)))
    var v6_bytes = List[UInt8](length=18, fill=0)
    if v6:
        v6_bytes[15] = 1
        v6_bytes[17] = 24
    out.extend(Span(v6_bytes))
    out.append(UInt8(len(cid)))
    out.extend(Span(cid))
    out.extend(Span(List[UInt8](length=token_len, fill=0xAB)))
    return out^


def _same_cid(a: Optional[ConnectionId], b: Optional[ConnectionId]) -> Bool:
    if not a:
        return not b
    return Bool(b) and a.value() == b.value()


def _assert_same(a: TransportParameters, b: TransportParameters) raises:
    assert_true(_same_cid(a.original_dst_cid, b.original_dst_cid))
    assert_true(_same_cid(a.initial_src_cid, b.initial_src_cid))
    assert_true(_same_cid(a.retry_src_cid, b.retry_src_cid))
    assert_equal(Bool(a.stateless_reset_token), Bool(b.stateless_reset_token))
    if a.stateless_reset_token:
        assert_true(
            a.stateless_reset_token.value() == b.stateless_reset_token.value()
        )
    assert_equal(a.max_idle_timeout, b.max_idle_timeout)
    assert_equal(a.max_udp_payload_size, b.max_udp_payload_size)
    assert_equal(a.initial_max_data, b.initial_max_data)
    assert_equal(
        a.initial_max_stream_data_bidi_local,
        b.initial_max_stream_data_bidi_local,
    )
    assert_equal(
        a.initial_max_stream_data_bidi_remote,
        b.initial_max_stream_data_bidi_remote,
    )
    assert_equal(a.initial_max_stream_data_uni, b.initial_max_stream_data_uni)
    assert_equal(a.initial_max_streams_bidi, b.initial_max_streams_bidi)
    assert_equal(a.initial_max_streams_uni, b.initial_max_streams_uni)
    assert_equal(a.ack_delay_exponent, b.ack_delay_exponent)
    assert_equal(a.max_ack_delay, b.max_ack_delay)
    assert_equal(a.disable_active_migration, b.disable_active_migration)
    assert_equal(a.active_connection_id_limit, b.active_connection_id_limit)
    assert_equal(a.has_preferred_address, b.has_preferred_address)
    assert_equal(a.grease_quic_bit, b.grease_quic_bit)


def test_coding() raises:
    var params = TransportParameters()
    params.initial_src_cid = ConnectionId()
    params.original_dst_cid = ConnectionId()
    params.initial_max_streams_bidi = 16
    params.initial_max_streams_uni = 16
    params.ack_delay_exponent = 2
    params.max_udp_payload_size = 1200
    params.grease_quic_bit = True
    var buf = List[UInt8]()
    params.encode(buf)
    _assert_same(TransportParameters.decode(Span(buf), True), params)


def test_coding_every_field() raises:
    var params = TransportParameters()
    params.original_dst_cid = ConnectionId(Span(_bytes(1, 2, 3, 4)))
    params.max_idle_timeout = 30000
    params.stateless_reset_token = ResetToken.random()
    params.max_udp_payload_size = 1472
    params.initial_max_data = 1 << 20
    params.initial_max_stream_data_bidi_local = 1 << 16
    params.initial_max_stream_data_bidi_remote = 1 << 17
    params.initial_max_stream_data_uni = 1 << 18
    params.initial_max_streams_bidi = 100
    params.initial_max_streams_uni = 3
    params.ack_delay_exponent = 20
    params.max_ack_delay = 16383
    params.disable_active_migration = True
    params.active_connection_id_limit = 8
    params.initial_src_cid = ConnectionId.random(8)
    params.retry_src_cid = ConnectionId.random(20)
    var buf = List[UInt8]()
    params.encode(buf)
    var got = TransportParameters.decode(Span(buf), True)
    _assert_same(got, params)
    assert_equal(_error(buf, False), ILLEGAL)


def test_defaults() raises:
    var buf = List[UInt8]()
    TransportParameters().encode(buf)
    assert_equal(len(buf), 0)
    var p = TransportParameters.decode(Span(buf), False)
    assert_equal(p.max_udp_payload_size, 65527)
    assert_equal(p.ack_delay_exponent, 3)
    assert_equal(p.max_ack_delay, 25)
    assert_equal(p.active_connection_id_limit, 2)
    assert_false(p.original_dst_cid)
    assert_true(p.copy().max_ack_delay == 25)


def test_reserved_transport_parameter_ignored_when_read() raises:
    var buf = List[UInt8]()
    # A reserved ID is 31 * N + 27.
    _param(buf, 31 * 1000 + 27, _bytes(1, 2, 3, 4, 5))
    _param(buf, 0x20, _bytes(9))
    _param(buf, 0xFF04DE1B, List[UInt8]())
    var p = TransportParameters.decode(Span(buf), False)
    _assert_same(p, TransportParameters())


def test_read_semantic_validation() raises:
    # A preferred address with an empty connection ID.
    var buf = List[UInt8]()
    _param(
        buf, PREFERRED_ADDRESS, _preferred_address(True, False, List[UInt8]())
    )
    assert_equal(_error(buf, True), ILLEGAL)
    assert_equal(_error(buf, False), ILLEGAL)


def test_read_length_mismatch() raises:
    # The parameter claims three bytes of value but holds a one-byte
    # integer, so a whole disable_active_migration fits inside it.
    var buf = List[UInt8]()
    write_varint(buf, INITIAL_MAX_DATA)
    write_varint(buf, 3)
    write_varint(buf, 0)
    write_varint(buf, DISABLE_ACTIVE_MIGRATION)
    write_varint(buf, 0)
    assert_equal(_error(buf, False), MALFORMED)


def test_read_integer_length_zero() raises:
    # As upstream's read_min_ack_delay_length_mismatch: no value at all.
    var buf = List[UInt8]()
    _param(buf, MAX_IDLE_TIMEOUT, List[UInt8]())
    _int_param(buf, INITIAL_MAX_DATA, 7)
    assert_equal(_error(buf, False), MALFORMED)


def test_read_preferred_address_length_mismatch() raises:
    var value = _preferred_address(True, False, _bytes(0x42))
    write_varint(value, DISABLE_ACTIVE_MIGRATION)
    write_varint(value, 0)
    var buf = List[UInt8]()
    _param(buf, PREFERRED_ADDRESS, value)
    assert_equal(_error(buf, True), MALFORMED)


def test_preferred_address() raises:
    var buf = List[UInt8]()
    _param(buf, PREFERRED_ADDRESS, _preferred_address(False, True, _bytes(7)))
    var p = TransportParameters.decode(Span(buf), True)
    assert_true(p.has_preferred_address)
    assert_equal(_error(buf, False), ILLEGAL)
    buf.clear()
    _param(buf, PREFERRED_ADDRESS, _preferred_address(False, False, _bytes(7)))
    assert_equal(_error(buf, True), ILLEGAL)
    buf.clear()
    _param(buf, PREFERRED_ADDRESS, _bytes(1, 2, 3))
    assert_equal(_error(buf, True), MALFORMED)
    buf.clear()
    var long = List[UInt8](length=21, fill=1)
    _param(buf, PREFERRED_ADDRESS, _preferred_address(True, True, long))
    assert_equal(_error(buf, True), MALFORMED)
    buf.clear()
    _param(buf, PREFERRED_ADDRESS, _preferred_address(True, True, _bytes(1), 8))
    assert_equal(_error(buf, True), MALFORMED)
    buf.clear()
    _param(buf, PREFERRED_ADDRESS, _preferred_address(True, True, _bytes(1)))
    _param(buf, PREFERRED_ADDRESS, _preferred_address(True, True, _bytes(1)))
    assert_equal(_error(buf, True), MALFORMED)


def _limit(id: UInt64, value: UInt64, ok: Bool) raises:
    var buf = List[UInt8]()
    _int_param(buf, id, value)
    var want = "no error" if ok else ILLEGAL
    assert_equal(_error(buf, False), want, String(id, " ", value))


def test_value_limits() raises:
    _limit(ACK_DELAY_EXPONENT, 20, True)
    _limit(ACK_DELAY_EXPONENT, 21, False)
    _limit(MAX_ACK_DELAY, 16383, True)
    _limit(MAX_ACK_DELAY, 16384, False)
    _limit(ACTIVE_CONNECTION_ID_LIMIT, 2, True)
    _limit(ACTIVE_CONNECTION_ID_LIMIT, 1, False)
    _limit(MAX_UDP_PAYLOAD_SIZE, 1200, True)
    _limit(MAX_UDP_PAYLOAD_SIZE, 1199, False)
    _limit(INITIAL_MAX_STREAMS_BIDI, 1 << 60, True)
    _limit(INITIAL_MAX_STREAMS_BIDI, (1 << 60) + 1, False)
    _limit(INITIAL_MAX_STREAMS_UNI, 1 << 60, True)
    _limit(INITIAL_MAX_STREAMS_UNI, (1 << 60) + 1, False)


def test_server_only() raises:
    var cid = _bytes(1, 2, 3)
    for id in [ORIGINAL_DESTINATION_CONNECTION_ID, RETRY_SOURCE_CONNECTION_ID]:
        var buf = List[UInt8]()
        _param(buf, id, cid)
        assert_equal(_error(buf, True), "no error")
        assert_equal(_error(buf, False), ILLEGAL)
    var buf = List[UInt8]()
    _param(buf, STATELESS_RESET_TOKEN, List[UInt8](length=16, fill=5))
    assert_equal(_error(buf, True), "no error")
    assert_equal(_error(buf, False), ILLEGAL)
    buf.clear()
    _param(buf, INITIAL_SOURCE_CONNECTION_ID, cid)
    assert_equal(_error(buf, False), "no error")


def test_malformed() raises:
    var buf = List[UInt8]()
    _int_param(buf, MAX_IDLE_TIMEOUT, 5)
    _int_param(buf, MAX_IDLE_TIMEOUT, 5)
    assert_equal(_error(buf, False), MALFORMED)
    buf.clear()
    _param(buf, INITIAL_SOURCE_CONNECTION_ID, _bytes(1))
    _param(buf, INITIAL_SOURCE_CONNECTION_ID, _bytes(1))
    assert_equal(_error(buf, False), MALFORMED)
    buf.clear()
    _param(buf, INITIAL_SOURCE_CONNECTION_ID, List[UInt8](length=21, fill=1))
    assert_equal(_error(buf, False), MALFORMED)
    buf.clear()
    _param(buf, STATELESS_RESET_TOKEN, List[UInt8](length=15, fill=5))
    assert_equal(_error(buf, True), MALFORMED)
    buf.clear()
    _param(buf, DISABLE_ACTIVE_MIGRATION, _bytes(0))
    assert_equal(_error(buf, False), MALFORMED)
    buf.clear()
    _param(buf, GREASE_QUIC_BIT, _bytes(0))
    assert_equal(_error(buf, False), MALFORMED)
    # A 2-byte form of 5 is not the shortest form.
    buf.clear()
    _param(buf, MAX_IDLE_TIMEOUT, _bytes(0x40, 0x05))
    assert_equal(_error(buf, False), MALFORMED)
    # A length past the end, and an ID cut off.
    assert_equal(_error(_bytes(0x01, 0x05, 0x01), False), MALFORMED)
    assert_equal(_error(_bytes(0x40), False), MALFORMED)
    assert_equal(_error(_bytes(0x01), False), MALFORMED)


def test_grease_quic_bit_twice() raises:
    # Upstream does not refuse a repeated grease_quic_bit.
    var buf = List[UInt8]()
    _param(buf, GREASE_QUIC_BIT, List[UInt8]())
    _param(buf, GREASE_QUIC_BIT, List[UInt8]())
    assert_true(TransportParameters.decode(Span(buf), False).grease_quic_bit)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

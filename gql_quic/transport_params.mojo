# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""QUIC transport parameters (RFC 9000 section 18).

Each endpoint sends its transport parameters in the TLS handshake, in the
`quic_transport_parameters` extension. A parameter is an ID, a length and
a value. `TransportParameters.encode` writes the parameters that differ
from their defaults, in upstream's order. `TransportParameters.decode`
reads them, skips unknown and reserved IDs, and checks them as upstream:
a parameter that does not decode, has a wrong length or comes twice is
`malformed`; a value out of range, or a parameter that only a server can
send in the parameters of a client, is `illegal value`. Both raise
`QuicError` with `TRANSPORT_PARAMETER_ERROR`.

This module ports quinn-proto 0.11.19 (8192ed3)
quinn-proto/src/transport_parameters.rs (MIT OR Apache-2.0, used under
MIT).

Differences from upstream: the preferred address is decoded and checked
as upstream does, but only `has_preferred_address` is kept, and `encode`
does not write one. `max_datagram_frame_size` (RFC 9221) and
`min_ack_delay` (the ACK frequency draft) are not ported: their IDs are
skipped as unknown IDs. `encode` writes no reserved (grease) parameter;
upstream writes a random one when it is configured. The integer parameters
are `UInt64` fields in place of `VarInt`. `decode` takes `from_server` in
place of upstream's `Side` of the reader: a server reads the parameters of
a client with `from_server` False.
"""

from gql_quic.cid import (
    MAX_CID_SIZE,
    RESET_TOKEN_SIZE,
    ConnectionId,
    ResetToken,
)
from gql_quic.error import QuicError, TransportErrorCode
from gql_quic.varint import (
    read_be,
    read_varint,
    varint_size,
    write_bytes,
    write_varint,
)

comptime ORIGINAL_DESTINATION_CONNECTION_ID: UInt64 = 0x00
"""The ID of `original_dst_cid`."""
comptime MAX_IDLE_TIMEOUT: UInt64 = 0x01
"""The ID of `max_idle_timeout`."""
comptime STATELESS_RESET_TOKEN: UInt64 = 0x02
"""The ID of `stateless_reset_token`."""
comptime MAX_UDP_PAYLOAD_SIZE: UInt64 = 0x03
"""The ID of `max_udp_payload_size`."""
comptime INITIAL_MAX_DATA: UInt64 = 0x04
"""The ID of `initial_max_data`."""
comptime INITIAL_MAX_STREAM_DATA_BIDI_LOCAL: UInt64 = 0x05
"""The ID of `initial_max_stream_data_bidi_local`."""
comptime INITIAL_MAX_STREAM_DATA_BIDI_REMOTE: UInt64 = 0x06
"""The ID of `initial_max_stream_data_bidi_remote`."""
comptime INITIAL_MAX_STREAM_DATA_UNI: UInt64 = 0x07
"""The ID of `initial_max_stream_data_uni`."""
comptime INITIAL_MAX_STREAMS_BIDI: UInt64 = 0x08
"""The ID of `initial_max_streams_bidi`."""
comptime INITIAL_MAX_STREAMS_UNI: UInt64 = 0x09
"""The ID of `initial_max_streams_uni`."""
comptime ACK_DELAY_EXPONENT: UInt64 = 0x0A
"""The ID of `ack_delay_exponent`."""
comptime MAX_ACK_DELAY: UInt64 = 0x0B
"""The ID of `max_ack_delay`."""
comptime DISABLE_ACTIVE_MIGRATION: UInt64 = 0x0C
"""The ID of `disable_active_migration`."""
comptime PREFERRED_ADDRESS: UInt64 = 0x0D
"""The ID of the preferred address."""
comptime ACTIVE_CONNECTION_ID_LIMIT: UInt64 = 0x0E
"""The ID of `active_connection_id_limit`."""
comptime INITIAL_SOURCE_CONNECTION_ID: UInt64 = 0x0F
"""The ID of `initial_src_cid`."""
comptime RETRY_SOURCE_CONNECTION_ID: UInt64 = 0x10
"""The ID of `retry_src_cid`."""
comptime GREASE_QUIC_BIT: UInt64 = 0x2AB2
"""The ID of `grease_quic_bit` (RFC 9287)."""

comptime _MAX_STREAM_COUNT: UInt64 = UInt64(1) << 60
"""The largest initial stream count."""
comptime _PREFERRED_ADDRESS_FIXED = 4 + 2 + 16 + 2 + 1
"""The bytes of a preferred address before its connection ID."""


@always_inline
def _malformed() -> QuicError:
    """Return the error for parameters that do not decode."""
    return QuicError(TransportErrorCode.TRANSPORT_PARAMETER_ERROR, "malformed")


@always_inline
def _illegal() -> QuicError:
    """Return the error for a parameter value that is not permitted."""
    return QuicError(
        TransportErrorCode.TRANSPORT_PARAMETER_ERROR, "illegal value"
    )


@always_inline
def _write_int(mut out: List[UInt8], id: UInt64, value: UInt64):
    """Append an integer parameter."""
    write_varint(out, id)
    write_varint(out, UInt64(varint_size(value)))
    write_varint(out, value)


@always_inline
def _write_cid(mut out: List[UInt8], id: UInt64, cid: ConnectionId):
    """Append a connection ID parameter."""
    write_varint(out, id)
    write_varint(out, UInt64(cid.len()))
    write_bytes(out, cid.bytes())


@always_inline
def _all_zero(value: Span[UInt8, _]) -> Bool:
    """Return True when every byte is 0."""
    var acc = UInt8(0)
    var i = 0
    while i < len(value):
        acc |= value[i]
        i += 1
    return acc == 0


def _check_preferred_address(value: Span[UInt8, _]) raises QuicError:
    """Check a preferred address as upstream's `PreferredAddress::read`."""
    if len(value) < _PREFERRED_ADDRESS_FIXED:
        raise _malformed()
    var cid_len = Int(value[_PREFERRED_ADDRESS_FIXED - 1])
    var tail = len(value) - _PREFERRED_ADDRESS_FIXED
    if cid_len > MAX_CID_SIZE or tail < cid_len + RESET_TOKEN_SIZE:
        raise _malformed()
    var no_v4 = _all_zero(value[0:6])
    var no_v6 = _all_zero(value[6:24])
    if no_v4 and no_v6:
        raise _illegal()
    if tail != cid_len + RESET_TOKEN_SIZE:
        raise _malformed()
    if cid_len == 0:
        raise _illegal()


struct TransportParameters(Copyable, Movable):
    """The transport parameters of one endpoint (RFC 9000 section 18.2),
    with the defaults of the RFC."""

    var original_dst_cid: Optional[ConnectionId]
    """Server only: the destination ID of the client's first Initial."""
    var max_idle_timeout: UInt64
    """The idle timeout in milliseconds; 0 for none."""
    var stateless_reset_token: Optional[ResetToken]
    """Server only: the reset token of the server's connection ID."""
    var max_udp_payload_size: UInt64
    """The largest UDP payload that the endpoint receives; 65527."""
    var initial_max_data: UInt64
    """The initial connection flow-control limit."""
    var initial_max_stream_data_bidi_local: UInt64
    """The initial limit of a bidirectional stream that the endpoint
    opens."""
    var initial_max_stream_data_bidi_remote: UInt64
    """The initial limit of a bidirectional stream that the peer opens."""
    var initial_max_stream_data_uni: UInt64
    """The initial limit of a unidirectional stream that the peer opens."""
    var initial_max_streams_bidi: UInt64
    """The bidirectional streams that the peer can open; at most 2^60."""
    var initial_max_streams_uni: UInt64
    """The unidirectional streams that the peer can open; at most 2^60."""
    var ack_delay_exponent: UInt64
    """The exponent of the ACK Delay field; 3, at most 20."""
    var max_ack_delay: UInt64
    """The largest ACK delay in milliseconds; 25, below 2^14."""
    var disable_active_migration: Bool
    """The endpoint does not support connection migration."""
    var active_connection_id_limit: UInt64
    """The connection IDs that the endpoint stores; 2, at least 2."""
    var initial_src_cid: Optional[ConnectionId]
    """The source ID of the endpoint's first Initial."""
    var retry_src_cid: Optional[ConnectionId]
    """Server only: the source ID of the server's Retry."""
    var has_preferred_address: Bool
    """Server only: a preferred address was sent; it is checked and not
    kept."""
    var grease_quic_bit: Bool
    """The peer accepts packets with the fixed bit clear (RFC 9287)."""

    def __init__(out self):
        """Make the parameters with the defaults of RFC 9000."""
        self.original_dst_cid = None
        self.max_idle_timeout = 0
        self.stateless_reset_token = None
        self.max_udp_payload_size = 65527
        self.initial_max_data = 0
        self.initial_max_stream_data_bidi_local = 0
        self.initial_max_stream_data_bidi_remote = 0
        self.initial_max_stream_data_uni = 0
        self.initial_max_streams_bidi = 0
        self.initial_max_streams_uni = 0
        self.ack_delay_exponent = 3
        self.max_ack_delay = 25
        self.disable_active_migration = False
        self.active_connection_id_limit = 2
        self.initial_src_cid = None
        self.retry_src_cid = None
        self.has_preferred_address = False
        self.grease_quic_bit = False

    def encode(self, mut out: List[UInt8]):
        """Append the parameters that differ from their defaults, in the
        order of upstream.

        Args:
            out: The destination.
        """
        var d = TransportParameters()
        if self.max_idle_timeout != d.max_idle_timeout:
            _write_int(out, MAX_IDLE_TIMEOUT, self.max_idle_timeout)
        if self.max_udp_payload_size != d.max_udp_payload_size:
            _write_int(out, MAX_UDP_PAYLOAD_SIZE, self.max_udp_payload_size)
        if self.initial_max_data != d.initial_max_data:
            _write_int(out, INITIAL_MAX_DATA, self.initial_max_data)
        if self.initial_max_stream_data_bidi_local != 0:
            _write_int(
                out,
                INITIAL_MAX_STREAM_DATA_BIDI_LOCAL,
                self.initial_max_stream_data_bidi_local,
            )
        if self.initial_max_stream_data_bidi_remote != 0:
            _write_int(
                out,
                INITIAL_MAX_STREAM_DATA_BIDI_REMOTE,
                self.initial_max_stream_data_bidi_remote,
            )
        if self.initial_max_stream_data_uni != 0:
            _write_int(
                out,
                INITIAL_MAX_STREAM_DATA_UNI,
                self.initial_max_stream_data_uni,
            )
        if self.initial_max_streams_bidi != 0:
            _write_int(
                out, INITIAL_MAX_STREAMS_BIDI, self.initial_max_streams_bidi
            )
        if self.initial_max_streams_uni != 0:
            _write_int(
                out, INITIAL_MAX_STREAMS_UNI, self.initial_max_streams_uni
            )
        if self.ack_delay_exponent != d.ack_delay_exponent:
            _write_int(out, ACK_DELAY_EXPONENT, self.ack_delay_exponent)
        if self.max_ack_delay != d.max_ack_delay:
            _write_int(out, MAX_ACK_DELAY, self.max_ack_delay)
        if self.active_connection_id_limit != d.active_connection_id_limit:
            _write_int(
                out, ACTIVE_CONNECTION_ID_LIMIT, self.active_connection_id_limit
            )
        if self.stateless_reset_token:
            write_varint(out, STATELESS_RESET_TOKEN)
            write_varint(out, UInt64(RESET_TOKEN_SIZE))
            write_bytes(out, self.stateless_reset_token.value().bytes())
        if self.disable_active_migration:
            write_varint(out, DISABLE_ACTIVE_MIGRATION)
            write_varint(out, 0)
        if self.original_dst_cid:
            _write_cid(
                out,
                ORIGINAL_DESTINATION_CONNECTION_ID,
                self.original_dst_cid.value(),
            )
        if self.initial_src_cid:
            _write_cid(
                out, INITIAL_SOURCE_CONNECTION_ID, self.initial_src_cid.value()
            )
        if self.retry_src_cid:
            _write_cid(
                out, RETRY_SOURCE_CONNECTION_ID, self.retry_src_cid.value()
            )
        if self.grease_quic_bit:
            write_varint(out, GREASE_QUIC_BIT)
            write_varint(out, 0)

    @staticmethod
    def decode(
        data: Span[UInt8, _], from_server: Bool
    ) raises QuicError -> TransportParameters:
        """Read and check the parameters of the peer, as upstream's
        `TransportParameters::read`.

        Args:
            data: The value of the `quic_transport_parameters` extension.
            from_server: True when a server sent the parameters; False
                refuses the parameters that only a server can send.

        Returns:
            The parameters, with the defaults for the absent ones.

        Raises:
            QuicError: `TRANSPORT_PARAMETER_ERROR` with `malformed` or
                `illegal value`.
        """
        var p = TransportParameters()
        try:
            _read_all(data, p)
        except e:
            if e.code == TransportErrorCode.FRAME_ENCODING_ERROR:
                raise _malformed()
            raise e^
        _validate(p, from_server)
        return p^


def _read_cid(
    value: Span[UInt8, _], mut field: Optional[ConnectionId]
) raises QuicError:
    """Read a connection ID parameter, as upstream's `decode_cid`."""
    if len(value) > MAX_CID_SIZE:
        raise _malformed()
    field = ConnectionId(value)


def _read_int(value: Span[UInt8, _]) raises QuicError -> UInt64:
    """Read an integer parameter whose length must be its shortest size."""
    var pos = 0
    var v = read_varint(value, pos)
    # A longer encoding, or bytes after the integer, give another size.
    if varint_size(v) != len(value):
        raise _malformed()
    return v


def _read_all(
    data: Span[UInt8, _], mut p: TransportParameters
) raises QuicError:
    """Read every parameter; check lengths and duplicates."""
    var pos = 0
    var seen = UInt64(0)
    while pos < len(data):
        var id = read_varint(data, pos)
        var length = read_varint(data, pos)
        if length > UInt64(len(data) - pos):
            raise _malformed()
        var value = data[pos : pos + Int(length)]
        pos += Int(length)
        if id <= RETRY_SOURCE_CONNECTION_ID:
            var bit = UInt64(1) << id
            if seen & bit != 0:
                raise _malformed()
            seen |= bit
        _read_one(id, value, p)


def _read_one(
    id: UInt64, value: Span[UInt8, _], mut p: TransportParameters
) raises QuicError:
    """Read one parameter whose ID is not a duplicate."""
    if id == ORIGINAL_DESTINATION_CONNECTION_ID:
        _read_cid(value, p.original_dst_cid)
    elif id == MAX_IDLE_TIMEOUT:
        p.max_idle_timeout = _read_int(value)
    elif id == STATELESS_RESET_TOKEN:
        if len(value) != RESET_TOKEN_SIZE:
            raise _malformed()
        p.stateless_reset_token = ResetToken(value)
    elif id == MAX_UDP_PAYLOAD_SIZE:
        p.max_udp_payload_size = _read_int(value)
    elif id == INITIAL_MAX_DATA:
        p.initial_max_data = _read_int(value)
    elif id == INITIAL_MAX_STREAM_DATA_BIDI_LOCAL:
        p.initial_max_stream_data_bidi_local = _read_int(value)
    elif id == INITIAL_MAX_STREAM_DATA_BIDI_REMOTE:
        p.initial_max_stream_data_bidi_remote = _read_int(value)
    elif id == INITIAL_MAX_STREAM_DATA_UNI:
        p.initial_max_stream_data_uni = _read_int(value)
    elif id == INITIAL_MAX_STREAMS_BIDI:
        p.initial_max_streams_bidi = _read_int(value)
    elif id == INITIAL_MAX_STREAMS_UNI:
        p.initial_max_streams_uni = _read_int(value)
    elif id == ACK_DELAY_EXPONENT:
        p.ack_delay_exponent = _read_int(value)
    elif id == MAX_ACK_DELAY:
        p.max_ack_delay = _read_int(value)
    elif id == DISABLE_ACTIVE_MIGRATION:
        if len(value) != 0:
            raise _malformed()
        p.disable_active_migration = True
    elif id == PREFERRED_ADDRESS:
        _check_preferred_address(value)
        p.has_preferred_address = True
    elif id == ACTIVE_CONNECTION_ID_LIMIT:
        p.active_connection_id_limit = _read_int(value)
    elif id == INITIAL_SOURCE_CONNECTION_ID:
        _read_cid(value, p.initial_src_cid)
    elif id == RETRY_SOURCE_CONNECTION_ID:
        _read_cid(value, p.retry_src_cid)
    elif id == GREASE_QUIC_BIT:
        if len(value) != 0:
            raise _malformed()
        p.grease_quic_bit = True


def _validate(p: TransportParameters, from_server: Bool) raises QuicError:
    """Check the values, as the end of upstream's `read`."""
    if p.ack_delay_exponent > 20:
        raise _illegal()
    if p.max_ack_delay >= 1 << 14:
        raise _illegal()
    if p.active_connection_id_limit < 2:
        raise _illegal()
    if p.max_udp_payload_size < 1200:
        raise _illegal()
    if p.initial_max_streams_bidi > _MAX_STREAM_COUNT:
        raise _illegal()
    if p.initial_max_streams_uni > _MAX_STREAM_COUNT:
        raise _illegal()
    if from_server:
        return
    if p.original_dst_cid:
        raise _illegal()
    if p.has_preferred_address:
        raise _illegal()
    if p.retry_src_cid:
        raise _illegal()
    if p.stateless_reset_token:
        raise _illegal()

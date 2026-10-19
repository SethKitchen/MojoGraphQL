# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A QUIC connection (RFC 9000, 9001 and 9002), without I/O.

`Connection` is the state machine of one end of a connection. It does no
I/O and reads no clock: the caller gives it datagrams and the time, and
takes datagrams and the next deadline.

- `handle_datagram(now, data, size)` opens and reads every packet of a
  datagram, in place.
- `poll_transmit(now, out)` appends the next datagram to `out`: the
  packets of each space that has something to send, coalesced, with the
  ACK frames of the space in each packet. It returns 0 when nothing waits.
- `poll_timeout()` and `handle_timeout(now)` run the timers: loss
  detection and probe timeouts, the delayed ACK, the idle timeout, and the
  closing and draining periods.
- The stream calls `open`, `accept`, `write`, `read`, `reset`, `stop`
  and `release` act on `StreamsState`.

An ACK frame goes out at once for Initial and Handshake packets, after two
ack-eliciting packets, or after a gap; else it waits up to `max_ack_delay`
and rides on the next packet that carries data. So one request and one
response cost one datagram each way.

The handshake runs in `gql_quic.tls`, and `gql_quic.crypto` derives the
keys of each secret. The server discards the Initial keys when the first
Handshake packet opens, the client when it first sends one. Both discard
the Handshake keys once the handshake is confirmed (RFC 9001 section 4.9).

This module ports quinn-proto 0.11.19 (8192ed3)
quinn-proto/src/connection/mod.rs (MIT OR Apache-2.0, used under MIT):
`handle_packet`, `process_payload`, `on_ack_received`,
`detect_lost_packets`, `set_loss_detection_timer`, `on_loss_detection_timeout`,
`poll_transmit` and `populate_packet`, `close` and the timers.

Differences from upstream: no 0-RTT, no Retry, no path migration, no
MTU discovery (the datagram size stays `TransportConfig.datagram_size`),
no ECN, no pacing, no keep-alive and no stateless reset. This end never
starts a key update, and it follows one that the peer starts. It issues
no extra connection IDs, and it follows the NEW_CONNECTION_ID frames of
the peer only to retire IDs. Persistent congestion is not detected. The
controller is NewReno, where quinn's default is Cubic. Events are not a
queue: the caller asks for the state.
"""

from gql_tls.error import TlsError
from gql_quic.cid import ConnectionId, ResetToken
from gql_quic.crypto import (
    TAG_SIZE,
    Crypto,
    DirectionalKeys,
    KeyPair,
    PacketKey,
    initial_keys,
)
from gql_quic.error import NO_FRAME, QuicError, TransportErrorCode
from gql_quic.frame import (
    Frame,
    FrameType,
    ack_ranges,
    check_payload,
    crypto_header_size,
    read_frame,
    write_ack,
    write_application_close,
    write_connection_close,
    write_crypto_header,
    write_handshake_done,
    write_path_response,
    write_ping,
    write_retire_connection_id,
)
from gql_quic.packet import (
    HeaderMarks,
    LongType,
    PacketHeader,
    QUIC_VERSION_1,
    SpaceId,
    decode_packet_number,
    key_phase,
    packet_number_len,
    parse_header,
    reserved_bits_valid,
    set_length,
    write_long_header,
    write_short_header,
)
from gql_quic.range_set import RangeSet
from gql_quic.recovery import (
    NS_PER_MS,
    NewReno,
    PACKET_THRESHOLD,
    RttEstimator,
    TIMER_GRANULARITY,
)
from gql_quic.shared import Dir, Side
from gql_quic.spaces import PacketSpace, SentFrame, SentPacket
from gql_quic.streams import ReadStatus, StreamRead, StreamsState
from gql_quic.tls import Level, QuicTls, TlsSession
from gql_quic.transport_params import TransportParameters

comptime INITIAL = 0
"""The index of the Initial space."""
comptime HANDSHAKE = 1
"""The index of the Handshake space."""
comptime DATA = 2
"""The index of the application data space."""
comptime MIN_INITIAL_SIZE = 1200
"""The smallest datagram that carries an ack-eliciting Initial packet."""
comptime MAX_CRYPTO_BUFFER = 65536
"""The most CRYPTO bytes of a space that wait for the bytes before them."""
comptime _NEVER = Int.MAX
"""A time later than every timer."""


@fieldwise_init
struct ConnectionState(Equatable, ImplicitlyCopyable, Writable):
    """The state of a connection, as a type."""

    var value: UInt8
    """The state's index; see `is_valid`."""

    comptime HANDSHAKE = ConnectionState(0)
    """The handshake runs."""
    comptime ESTABLISHED = ConnectionState(1)
    """The handshake is complete; streams carry data."""
    comptime CLOSING = ConnectionState(2)
    """This end closed: it answers packets with CONNECTION_CLOSE."""
    comptime DRAINING = ConnectionState(3)
    """The peer closed: this end sends nothing."""
    comptime DRAINED = ConnectionState(4)
    """The connection is over; free it."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the states.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 4

    def write_to(self, mut writer: Some[Writer]):
        """Write the name of the state.

        Args:
            writer: The destination.
        """
        comptime names: Array[StaticString, 6] = [
            "handshake",
            "established",
            "closing",
            "draining",
            "drained",
            "invalid",
        ]
        writer.write(materialize[names]()[Int(min(self.value, 5))])


struct TransportConfig(Copyable, Movable):
    """The transport settings of one end, as quinn's `TransportConfig`."""

    var max_idle_timeout_ms: UInt64
    """The idle timeout; 0 turns it off."""
    var stream_receive_window: UInt64
    """The receive window of each stream."""
    var receive_window: UInt64
    """The receive window of the connection."""
    var max_concurrent_bidi_streams: UInt64
    """The bidirectional streams that the peer can open at once."""
    var max_concurrent_uni_streams: UInt64
    """The unidirectional streams that the peer can open at once."""
    var max_ack_delay_ms: UInt64
    """How long this end delays an ACK frame."""
    var ack_delay_exponent: UInt64
    """The exponent of the ACK delay of this end."""
    var datagram_size: Int
    """The size of every full datagram."""
    var initial_rtt_ns: Int
    """The RTT before the first sample."""
    var cid_len: Int
    """The length of the connection IDs of this end."""

    def __init__(out self):
        """Make the defaults of quinn, with a 1200-byte datagram."""
        self.max_idle_timeout_ms = 30_000
        self.stream_receive_window = 1_250_000
        self.receive_window = 15_000_000
        self.max_concurrent_bidi_streams = 100
        self.max_concurrent_uni_streams = 100
        self.max_ack_delay_ms = 25
        self.ack_delay_exponent = 3
        self.datagram_size = 1200
        self.initial_rtt_ns = 333 * NS_PER_MS
        self.cid_len = 8


@fieldwise_init
struct _Built(Copyable, Movable):
    """A packet of a datagram that waits for its padding and protection."""

    var space: Int
    var marks: HeaderMarks
    var payload_end: Int
    var pn: UInt64


def _level_space(level: Level) -> Int:
    """Return the space of a TLS level; -1 for early data."""
    if level == Level.INITIAL:
        return INITIAL
    if level == Level.HANDSHAKE:
        return HANDSHAKE
    if level == Level.APPLICATION:
        return DATA
    return -1


def _space_level(space: Int) -> Level:
    """Return the TLS level of a space."""
    if space == INITIAL:
        return Level.INITIAL
    if space == HANDSHAKE:
        return Level.HANDSHAKE
    return Level.APPLICATION


struct Connection(Movable):
    """One end of a QUIC connection."""

    var side: Side
    """This end."""
    var config: TransportConfig
    """The transport settings."""
    var crypto: Crypto
    """The libcrypto functions."""
    var tls: TlsSession
    """The handshake."""
    var state: ConnectionState
    """The state."""
    var spaces: List[PacketSpace]
    """The Initial, Handshake and application data spaces."""
    var streams: StreamsState
    """The streams and the flow control."""
    var rtt: RttEstimator
    """The RTT estimates."""
    var cc: NewReno
    """The congestion controller."""
    var bytes_in_flight: Int
    """The bytes of the packets in flight."""
    var pto_count: Int
    """The probe timeouts since the last acknowledgment."""
    var local_cid: ConnectionId
    """The connection ID of this end."""
    var remote_cid: ConnectionId
    """The connection ID that packets of this end carry."""
    var remote_cid_seq: UInt64
    """The sequence number of `remote_cid`."""
    var original_dcid: ConnectionId
    """The Destination Connection ID of the first Initial of the client."""
    var handshake_done: Bool
    """Whether the TLS handshake is complete."""
    var handshake_confirmed: Bool
    """Whether the handshake is confirmed (RFC 9001 section 4.1.2)."""
    var handshake_done_pending: Bool
    """Whether the server must send HANDSHAKE_DONE."""
    var address_validated: Bool
    """Whether a server may send more than three times what it received."""
    var bytes_received: Int
    """The bytes of every datagram that arrived."""
    var bytes_sent: Int
    """The bytes of every datagram that went out."""
    var idle_timeout: Int
    """The idle timeout in nanoseconds; 0 for none."""
    var idle_deadline: Int
    """When the connection times out; -1 for never."""
    var close_deadline: Int
    """When the closing or the draining period ends; -1 for none."""
    var close_pending: Bool
    """Whether a CONNECTION_CLOSE must go out."""
    var close_code: UInt64
    """The error code of the close of this end."""
    var close_frame_type: UInt64
    """The frame type of a transport close, or `NO_FRAME`."""
    var close_app: Bool
    """Whether the close of this end is an application close."""
    var close_reason: String
    """Why the connection closed, for messages."""
    var peer_closed: Bool
    """Whether the peer sent CONNECTION_CLOSE."""
    var peer_error_code: UInt64
    """The error code of the close of the peer."""
    var timed_out: Bool
    """Whether the idle timeout ended the connection."""
    var tls_failed: Bool
    """Whether the TLS handshake failed."""
    var key_phase: Bool
    """The key phase of the 1-RTT keys in use."""
    var prev_remote: List[PacketKey]
    """The 1-RTT key of the previous key phase of the peer, for late
    packets: none or one."""
    var peer_max_ack_delay: Int
    """The `max_ack_delay` of the peer, in nanoseconds."""
    var peer_ack_delay_exponent: UInt64
    """The `ack_delay_exponent` of the peer."""
    var params_done: Bool
    """Whether the transport parameters of the peer were applied."""
    var datagrams_sent: Int
    """The count of datagrams that went out."""
    var datagrams_received: Int
    """The count of datagrams that arrived."""
    var _pending_local: List[List[DirectionalKeys]]
    var _pending_remote: List[List[DirectionalKeys]]
    var _peer_cids: List[Tuple[UInt64, ConnectionId]]
    var _retire_queue: List[UInt64]
    var _path_responses: List[UInt64]
    var _have_server_cid: Bool
    var _tls_dirty: Bool
    var _ack_scratch: RangeSet
    var _built: List[_Built]
    var _no_token: List[UInt8]

    def __init__(
        out self,
        side: Side,
        var config: TransportConfig,
        crypto: Crypto,
        var tls: QuicTls,
        ctx: Int,
        var host: String,
        verify: Bool,
        local_cid: ConnectionId,
        remote_cid: ConnectionId,
        original_dcid: ConnectionId,
        now: Int,
    ) raises TlsError:
        """Make a connection; use `client` or `server` instead.

        Args:
            side: This end.
            config: The transport settings.
            crypto: The libcrypto functions.
            tls: The libssl functions.
            ctx: A TLS `SSL_CTX` from `gql_tls.TlsContext`.
            host: The name of the server, for a client.
            verify: Whether a client checks the name.
            local_cid: The connection ID of this end.
            remote_cid: The first connection ID of the peer.
            original_dcid: The Destination Connection ID of the first
                Initial of the client.
            now: The current time.

        Raises:
            TlsError: `CONFIG` when libssl cannot make the session.
        """
        var params = TransportParameters()
        params.max_idle_timeout = config.max_idle_timeout_ms
        params.initial_max_data = config.receive_window
        params.initial_max_stream_data_bidi_local = config.stream_receive_window
        params.initial_max_stream_data_bidi_remote = (
            config.stream_receive_window
        )
        params.initial_max_stream_data_uni = config.stream_receive_window
        params.initial_max_streams_bidi = config.max_concurrent_bidi_streams
        params.initial_max_streams_uni = config.max_concurrent_uni_streams
        params.ack_delay_exponent = config.ack_delay_exponent
        params.max_ack_delay = config.max_ack_delay_ms
        params.disable_active_migration = True
        params.initial_src_cid = local_cid
        if side.is_server():
            params.original_dst_cid = original_dcid
            params.stateless_reset_token = ResetToken.random()
        var encoded = List[UInt8]()
        params.encode(encoded)
        self.tls = TlsSession(
            tls^, ctx, side.is_server(), host^, verify, encoded^
        )
        self.side = side
        self.crypto = crypto
        self.state = ConnectionState.HANDSHAKE
        self.spaces = List[PacketSpace]()
        while len(self.spaces) < 3:
            self.spaces.append(PacketSpace())
        self.spaces[INITIAL].keys.append(
            initial_keys(crypto, original_dcid.bytes(), side.is_server())
        )
        self.streams = StreamsState(
            side,
            config.max_concurrent_bidi_streams,
            config.max_concurrent_uni_streams,
            config.stream_receive_window,
            config.receive_window,
        )
        self.rtt = RttEstimator(config.initial_rtt_ns)
        self.cc = NewReno(config.datagram_size)
        self.bytes_in_flight = 0
        self.pto_count = 0
        self.local_cid = local_cid
        self.remote_cid = remote_cid
        self.remote_cid_seq = 0
        self.original_dcid = original_dcid
        self.handshake_done = False
        self.handshake_confirmed = False
        self.handshake_done_pending = False
        self.address_validated = side.is_client()
        self.bytes_received = 0
        self.bytes_sent = 0
        self.idle_timeout = Int(config.max_idle_timeout_ms) * NS_PER_MS
        self.idle_deadline = -1
        if self.idle_timeout > 0:
            self.idle_deadline = now + self.idle_timeout
        self.close_deadline = -1
        self.close_pending = False
        self.close_code = 0
        self.close_frame_type = NO_FRAME
        self.close_app = False
        self.close_reason = String()
        self.peer_closed = False
        self.peer_error_code = 0
        self.timed_out = False
        self.tls_failed = False
        self.key_phase = False
        self.prev_remote = List[PacketKey]()
        self.peer_max_ack_delay = 25 * NS_PER_MS
        self.peer_ack_delay_exponent = 3
        self.params_done = False
        self.datagrams_sent = 0
        self.datagrams_received = 0
        self._pending_local = List[List[DirectionalKeys]]()
        self._pending_remote = List[List[DirectionalKeys]]()
        while len(self._pending_local) < 3:
            self._pending_local.append(List[DirectionalKeys]())
            self._pending_remote.append(List[DirectionalKeys]())
        self._peer_cids = List[Tuple[UInt64, ConnectionId]]()
        self._retire_queue = List[UInt64]()
        self._path_responses = List[UInt64]()
        self._have_server_cid = side.is_server()
        self._tls_dirty = side.is_client()
        self._ack_scratch = RangeSet()
        self._built = List[_Built]()
        self._no_token = List[UInt8]()
        self.config = config^
        if side.is_client():
            self._drive_tls(now)

    @staticmethod
    def client(
        var config: TransportConfig,
        crypto: Crypto,
        var tls: QuicTls,
        ctx: Int,
        var host: String,
        verify: Bool,
        now: Int,
    ) raises TlsError -> Connection:
        """Start a client connection; its first datagram waits in
        `poll_transmit`.

        Args:
            config: The transport settings.
            crypto: The libcrypto functions.
            tls: The libssl functions.
            ctx: A client `SSL_CTX` with the ALPN protocols.
            host: The name of the server, for SNI and verification.
            verify: Whether to check the name.
            now: The current time.

        Returns:
            The connection.

        Raises:
            TlsError: `CONFIG` when libssl cannot make the session.
        """
        var local = ConnectionId.random(config.cid_len)
        var dcid = ConnectionId.random(8)
        return Connection(
            Side.CLIENT,
            config^,
            crypto,
            tls^,
            ctx,
            host^,
            verify,
            local,
            dcid,
            dcid,
            now,
        )

    @staticmethod
    def server(
        var config: TransportConfig,
        crypto: Crypto,
        var tls: QuicTls,
        ctx: Int,
        client_dcid: ConnectionId,
        client_scid: ConnectionId,
        now: Int,
    ) raises TlsError -> Connection:
        """Accept a connection for the first Initial of a client.

        Args:
            config: The transport settings.
            crypto: The libcrypto functions.
            tls: The libssl functions.
            ctx: A server `SSL_CTX` with the certificate.
            client_dcid: The Destination Connection ID of the Initial.
            client_scid: The Source Connection ID of the Initial.
            now: The current time.

        Returns:
            The connection; give it the datagram next.

        Raises:
            TlsError: `CONFIG` when libssl cannot make the session.
        """
        var local = ConnectionId.random(config.cid_len)
        return Connection(
            Side.SERVER,
            config^,
            crypto,
            tls^,
            ctx,
            String(),
            False,
            local,
            client_scid,
            client_dcid,
            now,
        )

    # ---- state ----

    def is_established(self) -> Bool:
        """Return True once the handshake is complete and the connection
        has not closed.

        Returns:
            Whether streams can carry data.
        """
        return self.state == ConnectionState.ESTABLISHED

    def is_closed(self) -> Bool:
        """Return True once either end closed the connection.

        Returns:
            Whether the state is closing, draining or drained.
        """
        return self.state.value >= ConnectionState.CLOSING.value

    def is_drained(self) -> Bool:
        """Return True when the connection is over and can be freed.

        Returns:
            Whether the state is drained.
        """
        return self.state == ConnectionState.DRAINED

    def _pto(self, space: Int) -> Int:
        """Return the probe timeout of a space, with the backoff."""
        var duration = self.rtt.pto_base()
        if space == DATA:
            duration += self.peer_max_ack_delay
        return duration << min(self.pto_count, 20)

    def close(
        mut self, now: Int, code: UInt64, reason: StringSlice, app: Bool = True
    ):
        """Close the connection: send CONNECTION_CLOSE, and wait three
        probe timeouts for late packets.

        Args:
            now: The current time.
            code: The error code.
            reason: The reason phrase.
            app: True for an application close; False for a transport
                error code.
        """
        if self.is_closed():
            return
        self.state = ConnectionState.CLOSING
        self.close_pending = True
        self.close_code = code
        self.close_frame_type = NO_FRAME
        self.close_app = app
        self.close_reason = String(reason)
        self.close_deadline = now + 3 * self._pto(INITIAL)

    def _fail(mut self, now: Int, error: QuicError):
        """Close the connection with a transport error."""
        if self.is_closed():
            return
        self.close(now, error.code.value, error.reason, False)
        self.close_frame_type = error.frame_type
        self.close_reason = String(error)

    # ---- handshake ----

    def _discard(mut self, space: Int):
        """Drop the keys and the packets in flight of a space."""
        if not self.spaces[space].has_keys():
            return
        self.bytes_in_flight -= self.spaces[space].discard()
        self.pto_count = 0

    def _install(mut self, space: Int):
        """Install the keys of a space once both directions are known."""
        var ready = min(
            len(self._pending_local[space]), len(self._pending_remote[space])
        )
        if ready == 0:
            return
        var local = self._pending_local[space].pop()
        var remote = self._pending_remote[space].pop()
        self.spaces[space].keys.append(KeyPair(local^, remote^))

    def _drive_tls(mut self, now: Int):
        """Run the handshake, and take its secrets, bytes and parameters."""
        self._tls_dirty = False
        if not self.tls.advance():
            self.tls_failed = True
            var alert = self.tls.alert()
            var code = TransportErrorCode.INTERNAL_ERROR
            if alert >= 0:
                code = TransportErrorCode.crypto(UInt8(alert))
            var reason = "the TLS handshake failed"
            var why = self.tls.verify_failure()
            if why.byte_length() > 0:
                reason = "the certificate did not verify: " + why
            self._fail(now, QuicError(code, reason))
            return
        var secrets = self.tls.take_secrets()
        var index = 0
        while index < len(secrets):
            ref secret = secrets[index]
            index += 1
            var space = _level_space(secret.level)
            if space < 0:
                continue
            var keys = DirectionalKeys(
                self.crypto,
                self.tls.cipher_suite(),
                secret.secret,
                secret.write,
            )
            if secret.write:
                self._pending_local[space].append(keys^)
            else:
                self._pending_remote[space].append(keys^)
            self._install(space)
        var space = 0
        while space < 3:
            var data = self.tls.take_send(_space_level(space))
            if len(data) > 0:
                self.spaces[space].crypto_send.write(data)
            space += 1
        if not self.params_done and self.tls.has_peer_params():
            try:
                self._apply_params(self.tls.peer_params())
            except e:
                self._fail(now, e)
                return
        if self.tls.done and not self.handshake_done:
            self.handshake_done = True
            if self.state == ConnectionState.HANDSHAKE:
                self.state = ConnectionState.ESTABLISHED
            if self.side.is_server():
                self.handshake_confirmed = True
                self.handshake_done_pending = True
                self._discard(HANDSHAKE)

    def _apply_params(mut self, data: List[UInt8]) raises QuicError:
        """Check the transport parameters of the peer, and use them."""
        var params = TransportParameters.decode(data, self.side.is_client())
        var src = params.initial_src_cid
        if not src or src.value() != self.remote_cid:
            raise QuicError(
                TransportErrorCode.TRANSPORT_PARAMETER_ERROR,
                "initial_source_connection_id does not match",
            )
        if self.side.is_client():
            var odcid = params.original_dst_cid
            if not odcid or odcid.value() != self.original_dcid:
                raise QuicError(
                    TransportErrorCode.TRANSPORT_PARAMETER_ERROR,
                    "original_destination_connection_id does not match",
                )
        self.params_done = True
        self.streams.set_peer_limits(
            params.initial_max_data,
            params.initial_max_stream_data_bidi_local,
            params.initial_max_stream_data_bidi_remote,
            params.initial_max_stream_data_uni,
            params.initial_max_streams_bidi,
            params.initial_max_streams_uni,
        )
        var peer_idle = Int(params.max_idle_timeout) * NS_PER_MS
        if peer_idle > 0 and (
            self.idle_timeout == 0 or peer_idle < self.idle_timeout
        ):
            self.idle_timeout = peer_idle
        self.peer_max_ack_delay = Int(params.max_ack_delay) * NS_PER_MS
        self.peer_ack_delay_exponent = params.ack_delay_exponent

    # ---- receive ----

    def handle_datagram(
        mut self, now: Int, data: Pointer[mut=True, UInt8, _], size: Int
    ):
        """Open and read every packet of a datagram, in place.

        Packets that do not parse or do not open are dropped, as RFC 9000
        section 12.2 asks. A frame that breaks the protocol closes the
        connection with its error.

        Args:
            now: The current time.
            data: The datagram; its bytes change.
            size: Its size.
        """
        if self.state.value >= ConnectionState.DRAINING.value:
            return
        self.datagrams_received += 1
        self.bytes_received += size
        var span = Span(unsafe_ptr=data, length=size)
        var pos = 0
        while pos < size:
            var header: PacketHeader
            try:
                header = parse_header(span, pos, self.config.cid_len)
            except:
                break
            pos = header.end
            try:
                self._handle_packet(now, data, header)
            except e:
                self._fail(now, e)
                return
            # The keys of the next packet, such as the Handshake packet
            # after the Initial of a server, can come from these bytes.
            if self._tls_dirty:
                self._drive_tls(now)

    def _handle_packet(
        mut self,
        now: Int,
        data: Pointer[mut=True, UInt8, _],
        header: PacketHeader,
    ) raises QuicError:
        """Open one packet and read its frames."""
        if header.is_version_negotiation:
            if self.side.is_client() and not self._have_server_cid:
                # QUIC version 1 is the only version: no common version.
                self.state = ConnectionState.DRAINED
                self.close_reason = String(
                    "the server offers no QUIC version 1"
                )
            return
        if header.is_long and (
            not header.is_supported_version()
            or header.long_type == LongType.RETRY
            or header.long_type == LongType.ZERO_RTT
        ):
            return
        var space = Int(header.space().value)
        if not self.spaces[space].has_keys():
            return
        var start = header.start
        var pn_len = (
            self.spaces[space]
            .keys[0]
            .remote.header.unprotect(data, start, header.pn_offset, header.end)
        )
        if pn_len == 0:
            return
        var first = data[unsafe_offset=start]
        var truncated = UInt64(0)
        var index = 0
        while index < pn_len:
            truncated = (truncated << 8) | UInt64(
                data[unsafe_offset=header.pn_offset + index]
            )
            index += 1
        var expected = UInt64(self.spaces[space].rx_largest + 1)
        var pn = decode_packet_number(expected, truncated, pn_len)
        var header_end = header.pn_offset + pn_len
        if not self._open(
            space, data, start, header_end, header.end, pn, first
        ):
            return
        if not reserved_bits_valid(first, header.is_long):
            raise QuicError(
                TransportErrorCode.PROTOCOL_VIOLATION, "reserved bits are set"
            )
        if self.spaces[space].seen.contains(pn):
            return
        _ = self.spaces[space].seen.insert_one(pn)
        if self.state == ConnectionState.CLOSING:
            self.close_pending = True
            return
        if self.side.is_client() and not self._have_server_cid:
            self._have_server_cid = True
            self.remote_cid = header.scid
        if self.side.is_server() and space == HANDSHAKE:
            self.address_validated = True
            self._discard(INITIAL)
        if self.idle_timeout > 0:
            self.idle_deadline = now + self.idle_timeout
        var payload = Span(
            unsafe_ptr=data.unsafe_offset(header_end),
            length=header.end - TAG_SIZE - header_end,
        )
        # No frame discards the keys of the space that carried it: only
        # HANDSHAKE_DONE discards keys, and only a 1-RTT packet carries it.
        var eliciting = self._process_payload(now, space, payload)
        ref sp = self.spaces[space]
        var in_order = Int64(pn) == sp.rx_largest + 1
        _ = sp.pending_acks.insert_one(pn)
        if Int64(pn) > sp.rx_largest:
            sp.rx_largest = Int64(pn)
            sp.rx_largest_time = now
        if not eliciting:
            return
        sp.unacked_eliciting += 1
        if space != DATA or sp.unacked_eliciting >= 2 or not in_order:
            sp.immediate_ack = True
        else:
            # The first ack-eliciting packet since the last ACK frame: no
            # deadline runs, as the ACK frame cleared it.
            sp.ack_deadline = (
                now + Int(self.config.max_ack_delay_ms) * NS_PER_MS
            )

    def _open(
        mut self,
        space: Int,
        data: Pointer[mut=True, UInt8, _],
        start: Int,
        header_end: Int,
        end: Int,
        pn: UInt64,
        first: UInt8,
    ) -> Bool:
        """Open the payload of a packet; follow a key update of the peer."""
        ref keys = self.spaces[space].keys[0]
        if space != DATA or key_phase(first) == self.key_phase:
            return keys.remote.packet.open(data, start, header_end, end, pn)
        # A late packet of the previous phase, or the first packet of the
        # next phase (RFC 9001 section 6).
        if len(self.prev_remote) > 0 and self.prev_remote[0].open(
            data, start, header_end, end, pn
        ):
            return True
        var secret = keys.remote.next_secret()
        var next = keys.remote.next_packet_key(secret)
        if not next.open(data, start, header_end, end, pn):
            return False
        var old = keys.remote.update()
        _ = keys.local.update()
        self.prev_remote.clear()
        self.prev_remote.append(old^)
        self.key_phase = not self.key_phase
        return True

    def _process_payload(
        mut self, now: Int, space: Int, payload: Span[UInt8, _]
    ) raises QuicError -> Bool:
        """Read the frames of a packet; return whether one elicits an ACK."""
        check_payload(payload)
        var eliciting = False
        var pos = 0
        while pos < len(payload):
            var f = read_frame(payload, pos)
            var t = f.type.value
            if space != DATA and not (
                t <= FrameType.ACK_ECN.value
                or t == FrameType.CRYPTO.value
                or t == FrameType.CONNECTION_CLOSE.value
            ):
                raise QuicError(
                    TransportErrorCode.PROTOCOL_VIOLATION,
                    t,
                    "a frame that Initial and Handshake packets cannot carry",
                )
            eliciting = eliciting or f.type.is_ack_eliciting()
            if f.type.is_stream():
                self.streams.on_stream_frame(
                    f.stream_id.value,
                    f.offset,
                    payload[f.data_start : f.data_start + f.data_len],
                    f.fin,
                )
            elif t == FrameType.ACK.value or t == FrameType.ACK_ECN.value:
                self._on_ack(now, space, payload, f)
            elif t == FrameType.CRYPTO.value:
                self._on_crypto(
                    space,
                    f.offset,
                    payload[f.data_start : f.data_start + f.data_len],
                )
            elif t == FrameType.RESET_STREAM.value:
                self.streams.on_reset_stream(
                    f.stream_id.value, f.error_code, f.final_size
                )
            elif t == FrameType.STOP_SENDING.value:
                self.streams.on_stop_sending(f.stream_id.value, f.error_code)
            elif t == FrameType.MAX_DATA.value:
                self.streams.on_max_data(f.value)
            elif t == FrameType.MAX_STREAM_DATA.value:
                self.streams.on_max_stream_data(f.stream_id.value, f.value)
            elif (
                t == FrameType.MAX_STREAMS_BIDI.value
                or t == FrameType.MAX_STREAMS_UNI.value
            ):
                self.streams.on_max_streams(f.dir(), f.value)
            elif t == FrameType.NEW_CONNECTION_ID.value:
                self._on_new_cid(f)
            elif t == FrameType.PATH_CHALLENGE.value:
                self._path_responses.append(f.token)
            elif (
                t == FrameType.CONNECTION_CLOSE.value
                or t == FrameType.APPLICATION_CLOSE.value
            ):
                self.peer_closed = True
                self.peer_error_code = f.error_code
                self.close_reason = "the peer closed the connection: " + String(
                    StringSlice(
                        unsafe_from_utf8=payload[
                            f.reason_start : f.reason_start + f.reason_len
                        ]
                    )
                )
                self.state = ConnectionState.DRAINING
                self.close_deadline = now + 3 * self._pto(INITIAL)
                return False
            elif t == FrameType.HANDSHAKE_DONE.value:
                if self.side.is_server():
                    raise QuicError(
                        TransportErrorCode.PROTOCOL_VIOLATION,
                        t,
                        "a client sent HANDSHAKE_DONE",
                    )
                self.handshake_confirmed = True
                self._discard(HANDSHAKE)
            elif t == FrameType.NEW_TOKEN.value and self.side.is_server():
                raise QuicError(
                    TransportErrorCode.PROTOCOL_VIOLATION,
                    t,
                    "a client sent NEW_TOKEN",
                )
            # PADDING, PING, the BLOCKED frames, RETIRE_CONNECTION_ID,
            # PATH_RESPONSE and NEW_TOKEN need nothing more.
        return eliciting

    def _on_crypto(
        mut self, space: Int, offset: UInt64, data: Span[UInt8, _]
    ) raises QuicError:
        """Take CRYPTO bytes, and give the ones in order to TLS."""
        ref recv = self.spaces[space].crypto_recv
        var end = offset + UInt64(len(data))
        if end > recv.bytes_read + MAX_CRYPTO_BUFFER:
            raise QuicError(
                TransportErrorCode.CRYPTO_BUFFER_EXCEEDED,
                FrameType.CRYPTO.value,
                "too many CRYPTO bytes wait for earlier ones",
            )
        recv.insert(offset, data)
        var ready = recv.readable()
        if ready == 0:
            return
        self.tls.feed(_space_level(space), recv.peek())
        recv.consume(ready)
        self._tls_dirty = True

    def _on_new_cid(mut self, f: Frame) raises QuicError:
        """Keep a connection ID of the peer, and retire the ones that it
        asks to retire."""
        if f.sequence > self.remote_cid_seq:
            var known = False
            for index in range(len(self._peer_cids)):
                if self._peer_cids[index][0] == f.sequence:
                    known = True
            if not known:
                self._peer_cids.append((f.sequence, f.cid))
        if f.retire_prior_to > self.remote_cid_seq:
            # `read_frame` refuses Retire Prior To above the Sequence
            # Number, so the ID of this frame, which is in the list now,
            # stays: `best` is found.
            var best = 0
            var best_seq = UInt64.MAX
            var index = 0
            while index < len(self._peer_cids):
                var seq = self._peer_cids[index][0]
                if seq >= f.retire_prior_to and seq < best_seq:
                    best = index
                    best_seq = seq
                index += 1
            self._retire_queue.append(self.remote_cid_seq)
            self.remote_cid_seq = best_seq
            self.remote_cid = self._peer_cids[best][1]
            var keep = List[Tuple[UInt64, ConnectionId]]()
            index = 0
            while index < len(self._peer_cids):
                var seq = self._peer_cids[index][0]
                if seq < f.retire_prior_to:
                    self._retire_queue.append(seq)
                elif seq != self.remote_cid_seq:
                    keep.append(self._peer_cids[index])
                index += 1
            self._peer_cids = keep^
        # This end allows two IDs of the peer at once: the one in use and
        # one more (active_connection_id_limit 2).
        if len(self._peer_cids) > 1:
            raise QuicError(
                TransportErrorCode.CONNECTION_ID_LIMIT_ERROR,
                FrameType.NEW_CONNECTION_ID.value,
                "the peer sent too many connection IDs",
            )

    # ---- loss recovery ----

    def _on_ack(
        mut self, now: Int, space: Int, payload: Span[UInt8, _], f: Frame
    ) raises QuicError:
        """Take an ACK frame (RFC 9002 section 6 and appendix A.7)."""
        if f.ack_largest >= self.spaces[space].next_pn:
            raise QuicError(
                TransportErrorCode.PROTOCOL_VIOLATION,
                f.type.value,
                "an ACK of a packet that was never sent",
            )
        self._ack_scratch.clear()
        ack_ranges(payload, f, self._ack_scratch)
        if Int64(f.ack_largest) > self.spaces[space].largest_acked:
            self.spaces[space].largest_acked = Int64(f.ack_largest)
        # `sent` holds only ack-eliciting packets, so an RTT sample is
        # taken when the largest acknowledged packet is one of them.
        var largest_time = -1
        var index = len(self.spaces[space].sent) - 1
        var acked = 0
        while index >= 0:
            var pn = self.spaces[space].sent[index].pn
            if self._ack_scratch.contains(pn):
                var packet = self.spaces[space].sent.pop(index)
                acked += 1
                if pn == f.ack_largest:
                    largest_time = packet.time
                self._on_packet_acked(space, packet)
            index -= 1
        if acked == 0:
            return
        if largest_time >= 0:
            var delay = 0
            if space == DATA:
                delay = Int(f.ack_delay << self.peer_ack_delay_exponent) * 1000
                if self.handshake_confirmed:
                    delay = min(delay, self.peer_max_ack_delay)
            self.rtt.update(delay, now - largest_time)
        self.pto_count = 0
        self._detect_lost(now, space)

    def _on_packet_acked(mut self, space: Int, packet: SentPacket):
        """Release what an acknowledged packet carried: an ack-eliciting
        packet in flight."""
        ref sp = self.spaces[space]
        self.bytes_in_flight -= packet.size
        self.cc.on_ack(packet.time, packet.size, False)
        sp.ack_eliciting_in_flight -= 1
        var index = 0
        while index < len(packet.frames):
            ref frame = packet.frames[index]
            index += 1
            var kind = frame.kind
            if kind == FrameType.ACK.value:
                _ = sp.pending_acks.remove(0, frame.value + 1)
            elif kind == FrameType.CRYPTO.value:
                sp.crypto_send.ack(frame.offset, frame.offset + frame.length)
            elif (
                kind == FrameType.STREAM.value
                or kind == FrameType.RESET_STREAM.value
            ):
                self.streams.on_frame_acked(frame)

    def _on_frame_lost(mut self, space: Int, frame: SentFrame):
        """Queue again what a lost frame carried."""
        var kind = frame.kind
        if kind == FrameType.CRYPTO.value:
            self.spaces[space].crypto_send.retransmit(
                frame.offset, frame.offset + frame.length
            )
        elif kind == FrameType.HANDSHAKE_DONE.value:
            self.handshake_done_pending = True
        elif kind == FrameType.RETIRE_CONNECTION_ID.value:
            self._retire_queue.append(frame.id)
        elif kind != FrameType.ACK.value and kind != FrameType.PING.value:
            self.streams.on_frame_lost(frame)

    def _detect_lost(mut self, now: Int, space: Int):
        """Declare the packets lost that a later acknowledgment or the time
        threshold condemns (RFC 9002 section 6.1)."""
        # An ACK frame or a loss time, which needs an ACK frame, calls
        # this, so `largest_acked` is set.
        self.spaces[space].loss_time = -1
        var largest = UInt64(self.spaces[space].largest_acked)
        var loss_delay = max(
            9 * max(self.rtt.latest, self.rtt.get()) // 8, TIMER_GRANULARITY
        )
        var lost_before = now - loss_delay
        var lost_time = -1
        var loss_time = -1
        while len(self.spaces[space].sent) > 0:
            var pn = self.spaces[space].sent[0].pn
            var sent_time = self.spaces[space].sent[0].time
            if pn > largest:
                break
            if pn + PACKET_THRESHOLD <= largest or sent_time <= lost_before:
                var gone = self.spaces[space].sent.pop(0)
                lost_time = max(lost_time, gone.time)
                self.bytes_in_flight -= gone.size
                self.spaces[space].ack_eliciting_in_flight -= 1
                var at = 0
                while at < len(gone.frames):
                    self._on_frame_lost(space, gone.frames[at])
                    at += 1
                continue
            # `sent` is in the order of packet numbers and of times, so
            # the later packets are not lost either, and this one is the
            # first that the time threshold will condemn.
            loss_time = sent_time + loss_delay
            break
        self.spaces[space].loss_time = loss_time
        if lost_time >= 0:
            self.cc.on_congestion_event(now, lost_time, False)

    def _peer_validated(self) -> Bool:
        """Return True when the peer has validated the address of this end:
        always for a server, after the handshake for a client."""
        return self.side.is_server() or self.handshake_done

    def _amplification_limited(self) -> Bool:
        """Return True when a server cannot send a full datagram: before
        it validates the address of the client, it sends at most three
        times what it received (RFC 9000 section 8). A client validates
        nothing, so the limit never applies to it."""
        if self.address_validated:
            return False
        return (
            3 * self.bytes_received - self.bytes_sent
            < self.config.datagram_size
        )

    def _loss_space(self) -> Int:
        """Return the space with the earliest loss time, or -1."""
        var best = -1
        var earliest = _NEVER
        var space = 0
        while space < 3:
            var t = self.spaces[space].loss_time
            if t < 0:
                t = _NEVER
            if t < earliest:
                earliest = t
                best = space
            space += 1
        return best

    def _probe_time(self, space: Int) -> Int:
        """Return when the probe timeout of a space fires: `_NEVER` when
        nothing is in flight, and for the application data space before
        the handshake is confirmed."""
        ref sp = self.spaces[space]
        if sp.ack_eliciting_in_flight == 0:
            return _NEVER
        if space == DATA and not self.handshake_confirmed:
            return _NEVER
        return sp.last_ack_eliciting + self._pto(space)

    def _probe_space(self) -> Int:
        """Return the space with the earliest probe timeout, or -1."""
        var best = -1
        var earliest = _NEVER
        var space = 0
        while space < 3:
            var t = self._probe_time(space)
            if t < earliest:
                earliest = t
                best = space
            space += 1
        return best

    def loss_timer(self) -> Int:
        """Return when loss detection or a probe timeout fires.

        Returns:
            The time, or -1 when no timer runs (RFC 9002 appendix A.8).
        """
        var space = self._loss_space()
        if space >= 0:
            return self.spaces[space].loss_time
        if self._amplification_limited():
            return -1
        var in_flight = (
            self.spaces[INITIAL].ack_eliciting_in_flight
            + self.spaces[HANDSHAKE].ack_eliciting_in_flight
            + self.spaces[DATA].ack_eliciting_in_flight
        )
        if in_flight == 0:
            if self._peer_validated():
                return -1
            # The anti-deadlock probe of a client (RFC 9002 section 6.2.2.1).
            var last = max(
                self.spaces[INITIAL].last_ack_eliciting,
                self.spaces[HANDSHAKE].last_ack_eliciting,
            )
            return max(last, 0) + self._pto(INITIAL)
        space = self._probe_space()
        if space < 0:
            return -1
        return self._probe_time(space)

    def _on_loss_timeout(mut self, now: Int):
        """Run loss detection, or send probes (RFC 9002 section 6.2.4).

        `handle_timeout` calls it once `loss_timer` is due, so the earliest
        loss time, when there is one, is due.
        """
        var space = self._loss_space()
        if space >= 0:
            self._detect_lost(now, space)
            return
        var probe = self._probe_space()
        if probe < 0:
            # The client has nothing in flight: probe in the highest space
            # with keys, so that the server can answer.
            probe = HANDSHAKE if self.spaces[HANDSHAKE].has_keys() else INITIAL
            self.spaces[probe].ping_pending = True
        self.spaces[probe].loss_probes = 2
        self.pto_count += 1

    # ---- transmit ----

    def _requeue_probe(mut self, space: Int):
        """Queue again the frames of the oldest packet in flight, as the
        content of a probe; every packet in `sent` is ack-eliciting."""
        ref sp = self.spaces[space]
        if len(sp.sent) == 0:
            return
        var frames = sp.sent[0].frames.copy()
        var at = 0
        while at < len(frames):
            self._on_frame_lost(space, frames[at])
            at += 1

    def _data_work(self) -> Bool:
        """Return True when the application data space has frames to send."""
        return (
            self.handshake_done_pending
            or len(self._path_responses) > 0
            or len(self._retire_queue) > 0
            or self.streams.has_pending()
        )

    def _work(self, space: Int) -> Bool:
        """Return True when a space has ack-eliciting frames to send."""
        ref sp = self.spaces[space]
        if sp.crypto_send.has_unsent_data() or sp.ping_pending:
            return True
        return space == DATA and self._data_work()

    def _build_packet(
        mut self, now: Int, space: Int, mut out: List[UInt8], end: Int
    ) -> Int:
        """Write one packet of a space, without its protection.

        Returns:
            0 when the space sent nothing, 1 for a packet, 2 for an
            ack-eliciting packet.
        """
        var packet_start = len(out)
        if end - packet_start - TAG_SIZE < 64:
            return 0
        var closing = self.state == ConnectionState.CLOSING
        var work = closing
        if not closing:
            if self.spaces[space].loss_probes > 0 and not self._work(space):
                self._requeue_probe(space)
                if not self._work(space):
                    self.spaces[space].ping_pending = True
            work = self._work(space)
            if (
                work
                and self.spaces[space].loss_probes == 0
                and self.bytes_in_flight + self.config.datagram_size
                > self.cc.window
            ):
                work = False
            if not work and not self.spaces[space].wants_ack(now):
                return 0
        ref sp = self.spaces[space]
        var pn = sp.next_pn
        var pn_len = packet_number_len(pn, sp.largest_acked)
        var marks: HeaderMarks
        if space == DATA:
            marks = write_short_header(
                out, False, self.key_phase, self.remote_cid, pn, pn_len
            )
        else:
            var kind = (
                LongType.INITIAL if space == INITIAL else LongType.HANDSHAKE
            )
            marks = write_long_header(
                out,
                kind,
                QUIC_VERSION_1,
                self.remote_cid,
                self.local_cid,
                self._no_token,
                pn,
                pn_len,
            )
        var limit = end - TAG_SIZE
        var record = SentPacket(pn, now)
        if not sp.pending_acks.is_empty():
            var delay = UInt64(0)
            if space == DATA:
                delay = (
                    UInt64(max(now - sp.rx_largest_time, 0) // 1000)
                    >> self.config.ack_delay_exponent
                )
            write_ack(out, sp.pending_acks, delay)
            record.frames.append(
                SentFrame(
                    FrameType.ACK.value,
                    0,
                    0,
                    0,
                    False,
                    UInt64(sp.rx_largest),
                )
            )
            sp.immediate_ack = False
            sp.unacked_eliciting = 0
            sp.ack_deadline = -1
        var acks = len(record.frames)
        var eliciting = False
        if closing:
            if self.close_app and space == DATA:
                write_application_close(
                    out, self.close_code, self.close_reason, limit - len(out)
                )
            else:
                var code = TransportErrorCode(self.close_code)
                var frame_type = self.close_frame_type
                if self.close_app:
                    code = TransportErrorCode.APPLICATION_ERROR
                    frame_type = 0
                if frame_type == NO_FRAME:
                    frame_type = 0
                write_connection_close(
                    out, code, frame_type, self.close_reason, limit - len(out)
                )
        elif work:
            # A PING goes first, as in quinn: the packet has room for it.
            if sp.ping_pending:
                sp.ping_pending = False
                write_ping(out)
                record.frames.append(
                    SentFrame(FrameType.PING.value, 0, 0, 0, False, 0)
                )
            if space == DATA and self.handshake_done_pending:
                self.handshake_done_pending = False
                write_handshake_done(out)
                record.frames.append(
                    SentFrame(FrameType.HANDSHAKE_DONE.value, 0, 0, 0, False, 0)
                )
            while sp.crypto_send.has_unsent_data():
                var room = limit - len(out) - 13
                if room <= 0:
                    break
                var range = sp.crypto_send.poll_transmit(room)
                var length = range.end - range.start
                write_crypto_header(out, range.start, length)
                out.extend(sp.crypto_send.get(range.start, range.end))
                record.frames.append(
                    SentFrame(
                        FrameType.CRYPTO.value,
                        0,
                        range.start,
                        length,
                        False,
                        0,
                    )
                )
            if space == DATA:
                while len(self._path_responses) > 0 and len(out) + 9 <= limit:
                    write_path_response(out, self._path_responses.pop())
                    record.frames.append(
                        SentFrame(
                            FrameType.PATH_RESPONSE.value, 0, 0, 0, False, 0
                        )
                    )
                while len(self._retire_queue) > 0 and len(out) + 9 <= limit:
                    var seq = self._retire_queue.pop()
                    write_retire_connection_id(out, seq)
                    record.frames.append(
                        SentFrame(
                            FrameType.RETIRE_CONNECTION_ID.value,
                            seq,
                            0,
                            0,
                            False,
                            0,
                        )
                    )
                self.streams.write_control(out, limit, record.frames)
                self.streams.write_frames(out, limit, record.frames)
            # Every frame after the ACK frame elicits an ACK.
            eliciting = len(record.frames) > acks
        var header_end = marks.pn_at + pn_len
        if len(out) == header_end:
            out.resize(packet_start, 0)
            return 0
        var payload = len(out) - header_end
        if payload + pn_len < 4:
            out.resize(len(out) + 4 - pn_len - payload, 0)
        var payload_end = len(out)
        out.resize(payload_end + TAG_SIZE, 0)
        sp.next_pn += 1
        self._built.append(_Built(space, marks, payload_end, pn))
        if not eliciting:
            return 1
        record.ack_eliciting = True
        record.in_flight = True
        record.size = len(out) - packet_start
        sp.ack_eliciting_in_flight += 1
        sp.last_ack_eliciting = now
        self.bytes_in_flight += record.size
        if sp.loss_probes > 0:
            sp.loss_probes -= 1
        sp.sent.append(record^)
        return 2

    def poll_transmit(mut self, now: Int, mut out: List[UInt8]) -> Int:
        """Append the next datagram to `out`.

        Args:
            now: The current time.
            out: The buffer; the datagram goes after its bytes.

        Returns:
            The size of the datagram; 0 when nothing waits.
        """
        if self.state.value >= ConnectionState.DRAINING.value:
            return 0
        var closing = self.state == ConnectionState.CLOSING
        if closing and not self.close_pending:
            return 0
        var start = len(out)
        var size = self.config.datagram_size
        if self._amplification_limited():
            return 0
        self._built.clear()
        var pad = False
        var handshake_sent = False
        # Before the handshake is confirmed the peer may lack the 1-RTT
        # keys, so a close goes out in each space with keys (RFC 9000
        # section 10.2.3); after it, only the 1-RTT keys remain.
        var space = 0
        while space < 3:
            var this = space
            space += 1
            if not self.spaces[this].has_keys():
                continue
            var built = self._build_packet(now, this, out, start + size)
            if built == 2 and this == INITIAL:
                pad = True
            if built > 0 and this == HANDSHAKE:
                handshake_sent = True
        if closing:
            self.close_pending = False
        if len(self._built) == 0:
            return 0
        if pad and len(out) - start < MIN_INITIAL_SIZE:
            # PADDING frames go at the end of the last packet.
            ref last = self._built[len(self._built) - 1]
            var extra = MIN_INITIAL_SIZE - (len(out) - start)
            out.resize(last.payload_end, 0)
            out.resize(last.payload_end + extra, 0)
            last.payload_end += extra
            out.resize(last.payload_end + TAG_SIZE, 0)
        var p = out.unsafe_ptr()
        var index = 0
        while index < len(self._built):
            ref b = self._built[index]
            index += 1
            set_length(out, b.marks, b.payload_end + TAG_SIZE)
            ref keys = self.spaces[b.space].keys[0]
            var header_end = b.marks.pn_at + b.marks.pn_len
            keys.local.packet.seal(
                p, b.marks.header_start, header_end, b.payload_end, b.pn
            )
            keys.local.header.protect(
                p, b.marks.header_start, b.marks.pn_at, b.marks.pn_len
            )
        if handshake_sent and self.side.is_client():
            self._discard(INITIAL)
        var total = len(out) - start
        self.datagrams_sent += 1
        self.bytes_sent += total
        return total

    # ---- timers ----

    def poll_timeout(self) -> Int:
        """Return when `handle_timeout` must run next.

        Returns:
            The time, or -1 when no timer runs.
        """
        if self.state == ConnectionState.DRAINED:
            return -1
        if self.is_closed():
            return self.close_deadline
        var earliest = self.loss_timer()
        if earliest < 0:
            earliest = _NEVER
        if self.idle_deadline >= 0:
            earliest = min(earliest, self.idle_deadline)
        # An ACK deadline comes with a new packet number in `pending_acks`,
        # and the ACK frame that carries it clears the deadline.
        var space = 0
        while space < 3:
            var deadline = self.spaces[space].ack_deadline
            space += 1
            if deadline >= 0:
                earliest = min(earliest, deadline)
        if earliest == _NEVER:
            return -1
        return earliest

    def handle_timeout(mut self, now: Int):
        """Run the timers that are due.

        Args:
            now: The current time.
        """
        if self.state == ConnectionState.DRAINED:
            return
        if self.is_closed():
            if now >= self.close_deadline:
                self.state = ConnectionState.DRAINED
            return
        if self.idle_deadline >= 0 and now >= self.idle_deadline:
            self.state = ConnectionState.DRAINED
            self.timed_out = True
            self.close_reason = String("the connection timed out")
            return
        var timer = self.loss_timer()
        if timer >= 0 and now >= timer:
            self._on_loss_timeout(now)

    # ---- streams ----

    def open(mut self, dir: Dir) -> Int64:
        """Open a stream of this end.

        Args:
            dir: The direction.

        Returns:
            The stream id, or -1 before the handshake, after the close, or
            when the peer allows no more streams now.
        """
        if not self.is_established():
            return -1
        return self.streams.open(dir)

    def accept(mut self) -> Int64:
        """Take the oldest stream that the peer opened.

        Returns:
            Its id, or -1 when none waits.
        """
        return self.streams.accept()

    def write(mut self, id: UInt64, data: Span[UInt8, _], fin: Bool) -> Int:
        """Write bytes to a stream, as far as flow control allows.

        Args:
            id: The stream.
            data: The bytes.
            fin: Whether to end the stream after them.

        Returns:
            The count of bytes taken, or -1 when the stream or the
            connection cannot send.
        """
        if self.is_closed():
            return -1
        return self.streams.write(id, data, fin)

    def read(
        mut self, id: UInt64, dest: Pointer[mut=True, UInt8, _], size: Int
    ) -> StreamRead:
        """Read bytes of a stream in order.

        Args:
            id: The stream.
            dest: The buffer.
            size: Its size.

        Returns:
            The count and the state; `RESET` once the connection is closed
            and no byte waits.
        """
        var result = self.streams.read(id, dest, size)
        if result.status == ReadStatus.WAIT and self.is_closed():
            return StreamRead(0, ReadStatus.RESET)
        return result

    def reset(mut self, id: UInt64, code: UInt64):
        """Abort the send part of a stream.

        Args:
            id: The stream.
            code: The application error code.
        """
        self.streams.reset(id, code)

    def stop(mut self, id: UInt64, code: UInt64):
        """Ask the peer to stop sending on a stream.

        Args:
            id: The stream.
            code: The application error code.
        """
        self.streams.stop(id, code)

    def release(mut self, id: UInt64):
        """Give up a stream; it leaves the state once it is done.

        Args:
            id: The stream.
        """
        self.streams.release(id)

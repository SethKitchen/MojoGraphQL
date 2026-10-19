# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_quic.streams`. The cases port quinn-proto 0.11.19
quinn-proto/src/connection/streams/state.rs: `trivial_flow_control`,
`reset_flow_control`, `reset_after_empty_frame_flow_control`,
`duplicate_reset_flow_control`, `recv_stopped`, `stopped_reset`,
`send_stopped`, `final_offset_flow_control`, `stop_finished`,
`reset_stream_cannot_send`, `stream_limit_fixed`, `stream_limit_grows`,
`expand_receive_window` and `max_stream_data_over_stream_limit`.

This port raises a window when half of it is used, and frees a stream
only after `release`, so the cases check those rules where upstream
checks its own. The priority cases (`stream_priority` and the like) and
the send window cases test features that this port does not have, and
have no case. `reordered_frames_while_stopped` of recv.rs tests a stop
that drops the bytes, which this port does in `release`; `test_release`
covers it. The other cases test the frames that `write_control` and
`write_frames` write, the records of acknowledged and lost frames, and
each error of the receive checks."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from gql_quic.error import TransportErrorCode
from gql_quic.frame import FrameType
from gql_quic.shared import Dir, Side, StreamId
from gql_quic.spaces import SentFrame
from gql_quic.streams import ReadStatus, StreamRead, StreamsState

comptime MIB: UInt64 = 1024 * 1024


def make(
    side: Side, stream_window: UInt64 = MIB, conn_window: UInt64 = MIB
) -> StreamsState:
    """Make the state of one end, with the peer's limits as upstream's
    `make`: 128 streams of each direction and 1 MiB of credit."""
    var s = StreamsState(side, 128, 128, stream_window, conn_window)
    s.set_peer_limits(MIB, MIB, MIB, MIB, 128, 128)
    return s^


def sid(side: Side, dir: Dir, index: UInt64) -> UInt64:
    """Return the id of a stream."""
    return StreamId(side, dir, index).value


def recv(
    mut s: StreamsState, id: UInt64, offset: UInt64, n: Int, fin: Bool
) -> String:
    """Take a STREAM frame of `n` zero bytes; return "ok" or the error."""
    var data = List[UInt8](length=n, fill=0)
    try:
        s.on_stream_frame(id, offset, data, fin)
    except e:
        return String(e.code)
    return "ok"


def reset(
    mut s: StreamsState, id: UInt64, code: UInt64, final_size: UInt64
) -> String:
    """Take a RESET_STREAM frame; return "ok" or the error."""
    try:
        s.on_reset_stream(id, code, final_size)
    except e:
        return String(e.code)
    return "ok"


def stop_sending(mut s: StreamsState, id: UInt64, code: UInt64) -> String:
    """Take a STOP_SENDING frame; return "ok" or the error."""
    try:
        s.on_stop_sending(id, code)
    except e:
        return String(e.code)
    return "ok"


def max_stream_data(mut s: StreamsState, id: UInt64, value: UInt64) -> String:
    """Take a MAX_STREAM_DATA frame; return "ok" or the error."""
    try:
        s.on_max_stream_data(id, value)
    except e:
        return String(e.code)
    return "ok"


def read(mut s: StreamsState, id: UInt64, size: Int) -> StreamRead:
    """Read at most `size` bytes of a stream."""
    var buf = List[UInt8](length=max(size, 1), fill=0)
    return s.read(id, buf.unsafe_ptr(), size)


def control(mut s: StreamsState, room: Int) -> List[SentFrame]:
    """Write the control frames that fit in `room` bytes."""
    var out = List[UInt8]()
    var frames = List[SentFrame]()
    s.write_control(out, room, frames)
    return frames^


def frames(mut s: StreamsState, room: Int) -> List[SentFrame]:
    """Write the STREAM and RESET_STREAM frames that fit in `room` bytes."""
    var out = List[UInt8]()
    var sent = List[SentFrame]()
    s.write_frames(out, room, sent)
    return sent^


def test_read_status_names() raises:
    assert_equal(String(ReadStatus.DATA), "data")
    assert_equal(String(ReadStatus.WAIT), "wait")
    assert_equal(String(ReadStatus.END), "end")
    assert_equal(String(ReadStatus.RESET), "reset")
    assert_equal(String(ReadStatus(9)), "invalid")
    assert_true(ReadStatus.RESET.is_valid())
    assert_false(ReadStatus(4).is_valid())
    assert_equal(String(StreamRead(3, ReadStatus.END)), "3 end")


def test_trivial_flow_control() raises:
    var client = StreamsState(Side.CLIENT, 1, 1, MIB, 4000)
    client.set_peer_limits(MIB, MIB, MIB, MIB, 1, 1)
    var id = sid(Side.SERVER, Dir.UNI, 0)
    var initial_max = client.local_max_data
    assert_equal(recv(client, id, 0, 2048, True), "ok")
    assert_equal(client.data_recvd, 2048)
    assert_equal(client.local_max_data - initial_max, 0)
    var r = read(client, id, 2048)
    assert_equal(r.count, 2048)
    assert_equal(r.status, ReadStatus.DATA)
    assert_equal(read(client, id, 2048).status, ReadStatus.END)
    # Less than half of the connection window is left: MAX_DATA goes out.
    assert_true(client.max_data_pending)
    assert_equal(client.local_max_data - initial_max, 2048)
    # The stream ended, so its window does not grow.
    assert_equal(len(client.max_stream_data_pending), 0)
    client.release(id)
    assert_false(client.is_open(id))
    assert_true(client.max_streams_pending[1])
    assert_equal(client.max_remote[1], 2)


def test_reset_flow_control() raises:
    var client = make(Side.CLIENT, MIB, 8000)
    var id = sid(Side.SERVER, Dir.UNI, 0)
    var initial_max = client.local_max_data
    assert_equal(recv(client, id, 0, 2048, False), "ok")
    assert_equal(client.data_recvd, 2048)
    assert_equal(client.local_max_data - initial_max, 0)
    assert_equal(read(client, id, 1024).count, 1024)
    assert_equal(client.local_max_data - initial_max, 0)
    assert_equal(reset(client, id, 0, 4096), "ok")
    assert_equal(client.data_recvd, 4096)
    # The bytes that will not be read are credited.
    assert_equal(client.local_max_data - initial_max, 4096)
    # A read after the reset gives no credit again.
    assert_equal(read(client, id, 1024).status, ReadStatus.RESET)
    assert_equal(client.data_recvd, 4096)
    assert_equal(client.local_max_data - initial_max, 4096)


def test_reset_after_empty_frame_flow_control() raises:
    var client = make(Side.CLIENT, MIB, 8000)
    var id = sid(Side.SERVER, Dir.UNI, 0)
    var initial_max = client.local_max_data
    assert_equal(recv(client, id, 4096, 0, False), "ok")
    assert_equal(client.data_recvd, 4096)
    assert_equal(client.local_max_data - initial_max, 0)
    assert_equal(reset(client, id, 0, 4096), "ok")
    assert_equal(client.data_recvd, 4096)
    assert_equal(client.local_max_data - initial_max, 4096)


def test_duplicate_reset_flow_control() raises:
    var client = make(Side.CLIENT)
    var id = sid(Side.SERVER, Dir.UNI, 0)
    assert_equal(reset(client, id, 0, 4096), "ok")
    assert_equal(client.data_recvd, 4096)
    assert_equal(reset(client, id, 0, 4096), "ok")
    assert_equal(client.data_recvd, 4096)
    assert_equal(client.data_read, 4096)


def test_final_offset_flow_control() raises:
    var client = make(Side.CLIENT)
    var id = sid(Side.SERVER, Dir.UNI, 0)
    assert_equal(
        reset(client, id, 0, (UInt64(1) << 62) - 1), "FLOW_CONTROL_ERROR"
    )


def test_recv_stopped() raises:
    var client = make(Side.CLIENT)
    var id = sid(Side.SERVER, Dir.UNI, 0)
    var initial_max = client.local_max_data
    assert_equal(recv(client, id, 0, 32, False), "ok")
    assert_equal(client.local_max_data, initial_max)
    client.stop(id, 0)
    assert_equal(len(client.stop_queue), 1)
    assert_false(client.max_data_pending)
    # A second stop changes nothing.
    client.stop(id, 0)
    assert_equal(len(client.stop_queue), 1)
    # The release drops the bytes that wait, and credits them.
    client.release(id)
    assert_equal(client.data_read, 32)
    assert_true(client.is_open(id))
    assert_equal(recv(client, id, 32, 16, True), "ok")
    assert_equal(client.data_read, 48)
    assert_equal(client.data_recvd, 48)
    assert_false(client.is_open(id))
    assert_equal(client.max_remote[1], 129)
    # The STOP_SENDING of a freed stream does not go out.
    var sent = control(client, 1200)
    assert_equal(len(sent), 1)
    assert_equal(sent[0].kind, FrameType.MAX_STREAMS_UNI.value)
    assert_equal(len(client.stop_queue), 0)


def test_stopped_reset() raises:
    var finals = List[UInt64]()
    finals.append(32)
    finals.append(48)
    for index in range(len(finals)):
        var final_size = finals[index]
        var client = make(Side.CLIENT)
        var id = sid(Side.SERVER, Dir.UNI, 0)
        assert_equal(recv(client, id, 0, 32, False), "ok")
        client.stop(id, 0)
        assert_equal(len(client.stop_queue), 1)
        client.release(id)
        var prev_max = client.max_remote[1]
        assert_equal(reset(client, id, 0, final_size), "ok")
        assert_false(client.is_open(id))
        assert_equal(client.max_remote[1], prev_max + 1)
        assert_equal(client.data_recvd, final_size)
        assert_equal(client.data_read, final_size)


def test_stop_finished() raises:
    var client = make(Side.CLIENT)
    var id = sid(Side.SERVER, Dir.UNI, 0)
    assert_equal(recv(client, id, 0, 32, True), "ok")
    assert_equal(read(client, id, 64).count, 32)
    # Every byte was read: no STOP_SENDING.
    client.stop(id, 0)
    assert_equal(len(client.stop_queue), 0)
    client.release(id)
    assert_false(client.is_open(id))
    # A stop of a closed stream, or of a send-only one, does nothing.
    client.stop(id, 0)
    var local = client.open(Dir.UNI)
    client.stop(UInt64(local), 0)
    assert_equal(len(client.stop_queue), 0)


def test_send_stopped() raises:
    var server = make(Side.SERVER)
    server.set_peer_limits(42, 0, 0, 42, 0, 1)
    var id = UInt64(server.open(Dir.UNI))
    assert_equal(id, sid(Side.SERVER, Dir.UNI, 0))
    assert_equal(stop_sending(server, id, 0), "ok")
    assert_equal(server.streams[server.find(id)].reset_code, 0)
    var empty = List[UInt8]()
    assert_equal(server.write(id, empty, False), -1)
    # The stream is reset already.
    server.reset(id, 5)
    assert_equal(server.streams[server.find(id)].reset_code, 0)
    # A duplicate frame changes nothing.
    assert_equal(stop_sending(server, id, 7), "ok")
    assert_equal(server.streams[server.find(id)].reset_code, 0)
    var sent = frames(server, 1200)
    assert_equal(len(sent), 1)
    assert_equal(sent[0].kind, FrameType.RESET_STREAM.value)
    assert_equal(sent[0].value, 0)


def test_reset_stream_cannot_send() raises:
    var server = make(Side.SERVER)
    server.set_peer_limits(42, 0, 0, 42, 0, 1)
    var id = UInt64(server.open(Dir.UNI))
    assert_equal(server.write(id, "hello".as_bytes(), False), 5)
    server.reset(id, 0)
    assert_true(server.has_pending())
    var sent = frames(server, 1200)
    # Only the RESET_STREAM goes out, with the final size.
    assert_equal(len(sent), 1)
    assert_equal(sent[0].kind, FrameType.RESET_STREAM.value)
    assert_equal(sent[0].offset, 5)
    assert_false(server.has_pending())


def test_stream_limit_fixed() raises:
    var client = make(Side.CLIENT)
    # Open the streams 0 to 127.
    assert_equal(recv(client, sid(Side.SERVER, Dir.UNI, 127), 0, 0, True), "ok")
    assert_equal(len(client.accept_queue), 128)
    assert_equal(client.accept(), Int64(sid(Side.SERVER, Dir.UNI, 0)))
    # Stream 128 is above the limit.
    assert_equal(
        recv(client, sid(Side.SERVER, Dir.UNI, 128), 0, 0, True),
        "STREAM_LIMIT_ERROR",
    )
    # Free stream 127.
    client.release(sid(Side.SERVER, Dir.UNI, 127))
    assert_false(client.is_open(sid(Side.SERVER, Dir.UNI, 127)))
    assert_equal(recv(client, sid(Side.SERVER, Dir.UNI, 128), 0, 0, True), "ok")


def test_stream_limit_grows() raises:
    var client = make(Side.CLIENT)
    assert_equal(recv(client, sid(Side.SERVER, Dir.UNI, 127), 0, 0, True), "ok")
    assert_false(client.has_control())
    client.release(sid(Side.SERVER, Dir.UNI, 127))
    assert_true(client.has_control())
    assert_true(client.has_pending())
    var out = List[UInt8]()
    var sent = List[SentFrame]()
    client.write_control(out, 1200, sent)
    assert_equal(len(sent), 1)
    assert_equal(sent[0].kind, FrameType.MAX_STREAMS_UNI.value)
    # The type byte, then 129 as a two byte varint.
    assert_equal(len(out), 3)
    assert_equal(out[0], 0x13)
    assert_false(client.has_control())


def test_expand_receive_window() raises:
    var client = make(Side.CLIENT, 100, MIB)
    var id = sid(Side.SERVER, Dir.UNI, 0)
    assert_equal(recv(client, id, 0, 40, False), "ok")
    # Less than half of the window is used: no MAX_STREAM_DATA.
    assert_equal(read(client, id, 40).count, 40)
    assert_equal(len(client.max_stream_data_pending), 0)
    assert_equal(recv(client, id, 40, 20, False), "ok")
    assert_equal(read(client, id, 40).count, 20)
    assert_equal(client.streams[client.find(id)].recv_max, 160)
    var sent = control(client, 1200)
    assert_equal(len(sent), 1)
    assert_equal(sent[0].kind, FrameType.MAX_STREAM_DATA.value)
    assert_equal(sent[0].id, id)
    assert_equal(recv(client, id, 60, 100, False), "ok")
    assert_equal(recv(client, id, 160, 1, False), "FLOW_CONTROL_ERROR")


def test_max_stream_data_over_stream_limit() raises:
    var server = make(Side.SERVER)
    # The limit is 128 streams, so the client can open the streams 0 to 127.
    var id = sid(Side.CLIENT, Dir.BI, UInt64(1) << 40)
    assert_equal(max_stream_data(server, id, 1), "STREAM_LIMIT_ERROR")
    assert_equal(server.next_remote[0], 0)


def test_stream_directions() raises:
    var client = make(Side.CLIENT)
    var bidi = UInt64(client.open(Dir.BI))
    var uni = UInt64(client.open(Dir.UNI))
    var remote = sid(Side.SERVER, Dir.UNI, 0)
    assert_equal(recv(client, remote, 0, 1, False), "ok")
    ref b = client.streams[client.find(bidi)]
    assert_true(b.can_send and b.can_recv)
    assert_false(b.send_done())
    assert_false(b.recv_done())
    ref u = client.streams[client.find(uni)]
    assert_true(u.can_send)
    assert_false(u.can_recv)
    assert_true(u.recv_done())
    ref r = client.streams[client.find(remote)]
    assert_false(r.can_send)
    assert_true(r.can_recv)
    assert_true(r.send_done())


def test_open_and_accept() raises:
    var client = make(Side.CLIENT)
    client.set_peer_limits(MIB, MIB, MIB, MIB, 1, 1)
    assert_equal(client.accept(), -1)
    assert_equal(client.open(Dir.BI), Int64(sid(Side.CLIENT, Dir.BI, 0)))
    assert_equal(client.open(Dir.BI), -1)
    # A MAX_STREAMS frame raises the limit, and never lowers it.
    client.on_max_streams(Dir.BI, 2)
    client.on_max_streams(Dir.BI, 1)
    assert_equal(client.max_local[0], 2)
    assert_equal(client.open(Dir.BI), Int64(sid(Side.CLIENT, Dir.BI, 1)))
    var uni = client.open(Dir.UNI)
    assert_equal(uni, Int64(sid(Side.CLIENT, Dir.UNI, 0)))
    # The streams of the peer wait for `accept` in the order they opened.
    assert_equal(recv(client, sid(Side.SERVER, Dir.BI, 1), 0, 0, False), "ok")
    assert_equal(client.accept(), Int64(sid(Side.SERVER, Dir.BI, 0)))
    assert_equal(client.accept(), Int64(sid(Side.SERVER, Dir.BI, 1)))
    assert_equal(client.accept(), -1)


def test_slot_reuse() raises:
    var client = make(Side.CLIENT)
    var id = sid(Side.SERVER, Dir.UNI, 0)
    assert_equal(recv(client, id, 0, 0, True), "ok")
    client.release(id)
    assert_false(client.is_open(id))
    var count = len(client.streams)
    var bidi = UInt64(client.open(Dir.BI))
    # The new stream takes the free slot.
    assert_equal(len(client.streams), count)
    assert_true(client.is_open(bidi))
    # A release of a closed stream does nothing.
    client.release(id)
    assert_equal(len(client._free), 0)


def test_state_errors() raises:
    var client = make(Side.CLIENT)
    # A frame for a stream that this end did not open yet.
    assert_equal(
        recv(client, sid(Side.CLIENT, Dir.BI, 0), 0, 1, False),
        "STREAM_STATE_ERROR",
    )
    var uni = UInt64(client.open(Dir.UNI))
    assert_equal(recv(client, uni, 0, 1, False), "STREAM_STATE_ERROR")
    assert_equal(reset(client, uni, 0, 0), "STREAM_STATE_ERROR")
    var remote = sid(Side.SERVER, Dir.UNI, 0)
    assert_equal(stop_sending(client, remote, 0), "STREAM_STATE_ERROR")
    assert_equal(max_stream_data(client, remote, 9), "STREAM_STATE_ERROR")
    # MAX_STREAM_DATA raises the send limit, and never lowers it.
    assert_equal(max_stream_data(client, uni, 2 * MIB), "ok")
    assert_equal(max_stream_data(client, uni, 1), "ok")
    assert_equal(client.streams[client.find(uni)].send_max, 2 * MIB)


def test_closed_stream_frames() raises:
    var client = make(Side.CLIENT)
    var uni = UInt64(client.open(Dir.UNI))
    var empty = List[UInt8]()
    assert_equal(client.write(uni, empty, True), 0)
    var sent = frames(client, 1200)
    assert_equal(len(sent), 1)
    assert_true(sent[0].fin)
    assert_equal(sent[0].length, 0)
    # The FIN is not acknowledged yet: the stream stays.
    client.release(uni)
    assert_true(client.is_open(uni))
    client.on_frame_acked(sent[0])
    assert_false(client.is_open(uni))
    # The limit of the peer does not change for a stream of this end.
    assert_false(client.has_control())
    # Frames for the closed stream are ignored.
    assert_equal(recv(client, uni, 0, 1, False), "ok")
    assert_equal(reset(client, uni, 0, 0), "ok")
    assert_equal(stop_sending(client, uni, 0), "ok")
    assert_equal(max_stream_data(client, uni, 9), "ok")
    var remote = sid(Side.SERVER, Dir.UNI, 0)
    assert_equal(recv(client, remote, 0, 0, True), "ok")
    client.release(remote)
    assert_equal(recv(client, remote, 0, 1, False), "ok")
    assert_equal(reset(client, remote, 0, 0), "ok")
    client.on_frame_acked(sent[0])
    client.on_frame_lost(sent[0])
    assert_equal(len(client.send_queue), 0)


def test_final_size_errors() raises:
    var client = make(Side.CLIENT)
    var id = sid(Side.SERVER, Dir.UNI, 0)
    assert_equal(recv(client, id, 0, 10, True), "ok")
    # Bytes above the final size.
    assert_equal(recv(client, id, 10, 5, False), "FINAL_SIZE_ERROR")
    # A second FIN at another offset.
    assert_equal(recv(client, id, 0, 5, True), "FINAL_SIZE_ERROR")
    # Bytes below the final size, and the same FIN again.
    assert_equal(recv(client, id, 0, 5, False), "ok")
    assert_equal(recv(client, id, 5, 5, True), "ok")
    assert_equal(reset(client, id, 0, 11), "FINAL_SIZE_ERROR")
    var other = sid(Side.SERVER, Dir.UNI, 1)
    assert_equal(recv(client, other, 0, 10, False), "ok")
    # A FIN below the bytes that arrived.
    assert_equal(recv(client, other, 0, 5, True), "FINAL_SIZE_ERROR")
    assert_equal(client.data_recvd, 20)


def test_connection_limit_error() raises:
    var client = make(Side.CLIENT, 100, 150)
    assert_equal(
        recv(client, sid(Side.SERVER, Dir.UNI, 0), 0, 100, False), "ok"
    )
    assert_equal(
        recv(client, sid(Side.SERVER, Dir.UNI, 1), 0, 100, False),
        "FLOW_CONTROL_ERROR",
    )


def test_frames_after_reset() raises:
    var client = make(Side.CLIENT)
    var id = sid(Side.SERVER, Dir.UNI, 0)
    assert_equal(reset(client, id, 3, 10), "ok")
    ref s = client.streams[client.find(id)]
    assert_true(s.peer_reset)
    assert_equal(s.peer_reset_code, 3)
    # The bytes of a reset stream are dropped.
    assert_equal(recv(client, id, 0, 10, True), "ok")
    assert_equal(client.streams[client.find(id)].recv.readable(), 0)
    assert_true(client.readable(id))
    assert_equal(read(client, id, 10).status, ReadStatus.RESET)


def test_write_rules() raises:
    var client = make(Side.CLIENT)
    client.set_peer_limits(10, MIB, MIB, 42, 128, 128)
    var data = List[UInt8](length=50, fill=7)
    assert_equal(client.write(99, data, False), -1)
    var remote = sid(Side.SERVER, Dir.UNI, 0)
    assert_equal(recv(client, remote, 0, 0, False), "ok")
    assert_equal(client.write(remote, data, False), -1)
    var bidi = UInt64(client.open(Dir.BI))
    # Nothing to send: the stream does not join the queue.
    var empty = List[UInt8]()
    assert_equal(client.write(bidi, empty, False), 0)
    assert_equal(len(client.send_queue), 0)
    # The connection credit is 10 bytes, so the FIN waits.
    assert_equal(client.write(bidi, data, True), 10)
    assert_false(client.streams[client.find(bidi)].finished)
    assert_equal(len(client.send_queue), 1)
    client.on_max_data(100)
    client.on_max_data(5)
    assert_equal(client.peer_max_data, 100)
    # The stream joins the queue once.
    assert_equal(client.write(bidi, Span(data)[0:20], True), 20)
    assert_equal(len(client.send_queue), 1)
    assert_true(client.streams[client.find(bidi)].finished)
    assert_equal(client.write(bidi, data, False), -1)
    # The stream credit of a uni stream is 42 bytes.
    var uni = UInt64(client.open(Dir.UNI))
    assert_equal(client.write(uni, data, False), 42)
    assert_equal(client.written, 72)


def test_reset_rules() raises:
    var client = make(Side.CLIENT)
    client.reset(99, 0)
    var remote = sid(Side.SERVER, Dir.UNI, 0)
    assert_equal(recv(client, remote, 0, 0, False), "ok")
    client.reset(remote, 0)
    assert_equal(len(client.send_queue), 0)
    var uni = UInt64(client.open(Dir.UNI))
    assert_equal(client.write(uni, "a".as_bytes(), True), 1)
    var sent = frames(client, 1200)
    client.on_frame_acked(sent[0])
    assert_true(client.streams[client.find(uni)].fin_acked)
    # The stream is done: a reset is too late.
    client.reset(uni, 0)
    assert_equal(client.streams[client.find(uni)].reset_code, -1)
    assert_true(client.streams[client.find(uni)].send_done())


def test_read_rules() raises:
    var client = make(Side.CLIENT)
    assert_equal(read(client, 99, 8).status, ReadStatus.RESET)
    assert_true(client.readable(99))
    var uni = UInt64(client.open(Dir.UNI))
    assert_equal(read(client, uni, 8).status, ReadStatus.RESET)
    var id = sid(Side.SERVER, Dir.UNI, 0)
    assert_equal(recv(client, id, 5, 3, False), "ok")
    # A gap at the front: the read waits.
    assert_false(client.readable(id))
    assert_equal(read(client, id, 8).status, ReadStatus.WAIT)
    assert_equal(recv(client, id, 0, 5, False), "ok")
    assert_equal(recv(client, id, 8, 0, True), "ok")
    assert_true(client.readable(id))
    var r = read(client, id, 8)
    assert_equal(r.count, 8)
    assert_equal(r.status, ReadStatus.DATA)
    assert_true(client.readable(id))
    assert_equal(read(client, id, 8).status, ReadStatus.END)


def test_has_send_work() raises:
    var client = make(Side.CLIENT)
    var uni = UInt64(client.open(Dir.UNI))
    assert_false(client.streams[client.find(uni)].has_send_work())
    assert_equal(client.write(uni, "abc".as_bytes(), False), 3)
    assert_true(client.streams[client.find(uni)].has_send_work())
    client.reset(uni, 4)
    # A reset stream sends its RESET_STREAM only.
    assert_true(client.streams[client.find(uni)].has_send_work())
    _ = frames(client, 1200)
    assert_false(client.streams[client.find(uni)].has_send_work())


def test_write_frames_room() raises:
    var client = make(Side.CLIENT)
    var a = UInt64(client.open(Dir.UNI))
    var b = UInt64(client.open(Dir.UNI))
    var data = List[UInt8](length=100, fill=1)
    assert_equal(client.write(a, data, False), 100)
    assert_equal(client.write(b, data, True), 100)
    # Too little room for a frame.
    assert_equal(len(frames(client, 31)), 0)
    assert_equal(len(client.send_queue), 2)
    # The room takes part of each stream, in turn.
    var sent = frames(client, 60)
    assert_equal(len(sent), 1)
    assert_equal(sent[0].id, a)
    assert_equal(sent[0].length, 41)
    sent = frames(client, 60)
    assert_equal(sent[0].id, b)
    assert_false(sent[0].fin)
    # Both streams in one packet; the FIN goes with the last byte.
    var out = List[UInt8]()
    var all = List[SentFrame]()
    client.write_frames(out, 1200, all)
    assert_equal(len(all), 2)
    assert_equal(all[0].id, a)
    assert_equal(all[0].offset, 41)
    assert_equal(all[0].length, 59)
    assert_false(all[0].fin)
    assert_equal(all[1].id, b)
    assert_true(all[1].fin)
    assert_equal(all[1].offset + all[1].length, 100)
    assert_false(client.has_pending())


def test_write_frames_skips() raises:
    var client = make(Side.CLIENT)
    var uni = UInt64(client.open(Dir.UNI))
    assert_equal(client.write(uni, "abc".as_bytes(), False), 3)
    var sent = frames(client, 1200)
    assert_equal(len(sent), 1)
    assert_false(sent[0].fin)
    # A loss of a range that was acknowledged since sends nothing.
    client.on_frame_acked(sent[0])
    client.on_frame_lost(sent[0])
    assert_equal(len(client.send_queue), 1)
    assert_equal(len(frames(client, 1200)), 0)
    # A FIN alone.
    var empty = List[UInt8]()
    assert_equal(client.write(uni, empty, True), 0)
    sent = frames(client, 1200)
    assert_equal(len(sent), 1)
    assert_true(sent[0].fin)
    assert_equal(sent[0].offset, 3)
    assert_equal(sent[0].length, 0)
    # A stream that was freed while it waited in the queue.
    client.release(uni)
    client.on_frame_lost(sent[0])
    assert_equal(len(client.send_queue), 1)
    client.on_frame_acked(sent[0])
    assert_false(client.is_open(uni))
    assert_equal(len(frames(client, 1200)), 0)
    assert_equal(len(client.send_queue), 0)


def test_write_control_room() raises:
    var client = make(Side.CLIENT)
    var id = sid(Side.SERVER, Dir.UNI, 0)
    assert_equal(recv(client, id, 0, 3, False), "ok")
    var bidi = sid(Side.SERVER, Dir.BI, 0)
    assert_equal(recv(client, bidi, 0, 3, False), "ok")
    # Lost frames make every control frame pending.
    client.on_frame_lost(SentFrame(FrameType.MAX_DATA.value, 0, 0, 0, False, 0))
    client.on_frame_lost(
        SentFrame(FrameType.MAX_STREAMS_BIDI.value, 0, 0, 0, False, 0)
    )
    client.on_frame_lost(
        SentFrame(FrameType.MAX_STREAMS_UNI.value, 0, 0, 0, False, 0)
    )
    client.on_frame_lost(
        SentFrame(FrameType.MAX_STREAM_DATA.value, bidi, 0, 0, False, 0)
    )
    client.stop(id, 6)
    assert_true(client.has_control())
    # No room: every frame waits.
    assert_equal(len(control(client, 8)), 0)
    assert_true(client.max_data_pending)
    assert_true(client.max_streams_pending[0])
    assert_true(client.max_streams_pending[1])
    assert_equal(len(client.max_stream_data_pending), 1)
    assert_equal(len(client.stop_queue), 1)
    # The room for the three small frames only.
    var sent = control(client, 27)
    assert_equal(len(sent), 3)
    assert_equal(sent[0].kind, FrameType.MAX_DATA.value)
    assert_equal(sent[1].kind, FrameType.MAX_STREAMS_BIDI.value)
    assert_equal(sent[2].kind, FrameType.MAX_STREAMS_UNI.value)
    sent = control(client, 1200)
    assert_equal(len(sent), 2)
    assert_equal(sent[0].kind, FrameType.MAX_STREAM_DATA.value)
    assert_equal(sent[0].id, bidi)
    assert_equal(sent[1].kind, FrameType.STOP_SENDING.value)
    assert_equal(sent[1].value, 6)
    assert_false(client.has_control())


def test_write_control_skips() raises:
    var client = make(Side.CLIENT, 100, MIB)
    var a = sid(Side.SERVER, Dir.UNI, 0)
    var b = sid(Side.SERVER, Dir.UNI, 1)
    assert_equal(recv(client, a, 0, 60, False), "ok")
    assert_equal(recv(client, b, 0, 60, False), "ok")
    assert_equal(read(client, a, 60).count, 60)
    assert_equal(read(client, b, 60).count, 60)
    assert_equal(len(client.max_stream_data_pending), 2)
    # Stream a is reset, and stream b is reset and freed: their
    # MAX_STREAM_DATA frames do not go out.
    assert_equal(reset(client, a, 0, 60), "ok")
    client.release(b)
    assert_equal(reset(client, b, 0, 60), "ok")
    assert_false(client.is_open(b))
    var sent = control(client, 1200)
    assert_equal(len(sent), 1)
    assert_equal(sent[0].kind, FrameType.MAX_STREAMS_UNI.value)
    assert_equal(len(client.max_stream_data_pending), 0)


def test_stop_sending_lost() raises:
    var client = make(Side.CLIENT)
    var id = sid(Side.SERVER, Dir.UNI, 0)
    assert_equal(recv(client, id, 0, 3, False), "ok")
    client.stop(id, 2)
    var sent = control(client, 1200)
    assert_equal(len(sent), 1)
    var record = sent[0].copy()
    # Two losses queue the stream twice; one frame goes out.
    client.on_frame_lost(record)
    client.on_frame_lost(record)
    assert_equal(len(client.stop_queue), 2)
    sent = control(client, 1200)
    assert_equal(len(sent), 1)
    assert_equal(sent[0].kind, FrameType.STOP_SENDING.value)
    assert_equal(len(client.stop_queue), 0)
    # Once the peer reset the stream, a loss needs nothing.
    assert_equal(reset(client, id, 2, 3), "ok")
    client.on_frame_lost(record)
    assert_equal(len(client.stop_queue), 0)


def test_frame_acked() raises:
    var server = make(Side.SERVER)
    var id = sid(Side.CLIENT, Dir.BI, 0)
    assert_equal(recv(server, id, 0, 1, True), "ok")
    assert_equal(read(server, id, 8).count, 1)
    server.reset(id, 9)
    var sent = frames(server, 1200)
    assert_equal(len(sent), 1)
    assert_equal(sent[0].kind, FrameType.RESET_STREAM.value)
    # An ack of an unknown stream, or of a frame that holds no bytes.
    server.on_frame_acked(SentFrame(FrameType.STREAM.value, 99, 0, 0, False, 0))
    server.on_frame_acked(
        SentFrame(FrameType.MAX_STREAM_DATA.value, id, 0, 0, False, 0)
    )
    server.on_frame_acked(sent[0])
    assert_true(server.streams[server.find(id)].reset_acked)
    assert_true(server.streams[server.find(id)].send_done())
    # The stream is done but not released.
    assert_true(server.is_open(id))
    server.release(id)
    assert_false(server.is_open(id))
    var control_sent = control(server, 1200)
    assert_equal(len(control_sent), 1)
    assert_equal(control_sent[0].kind, FrameType.MAX_STREAMS_BIDI.value)
    assert_equal(server.max_remote[0], 129)


def test_frame_lost() raises:
    var client = make(Side.CLIENT)
    client.on_frame_lost(SentFrame(FrameType.STREAM.value, 99, 0, 1, True, 0))
    var uni = UInt64(client.open(Dir.UNI))
    assert_equal(client.write(uni, "a".as_bytes(), True), 1)
    var first = frames(client, 1200)
    # A lost FIN goes again.
    client.on_frame_lost(first[0])
    assert_true(client.streams[client.find(uni)].fin_pending)
    var second = frames(client, 1200)
    assert_equal(len(second), 1)
    assert_true(second[0].fin)
    assert_equal(second[0].length, 1)
    client.on_frame_acked(second[0])
    # The FIN was acknowledged in the other packet.
    client.on_frame_lost(first[0])
    assert_false(client.streams[client.find(uni)].fin_pending)
    assert_equal(len(frames(client, 1200)), 0)
    # A frame type that holds nothing of the stream.
    client.on_frame_lost(SentFrame(FrameType.PING.value, uni, 0, 0, False, 0))
    assert_equal(len(client.send_queue), 0)


def test_reset_lost() raises:
    var client = make(Side.CLIENT)
    var uni = UInt64(client.open(Dir.UNI))
    assert_equal(client.write(uni, "abc".as_bytes(), False), 3)
    var data = frames(client, 1200)
    client.reset(uni, 8)
    # A lost STREAM frame of a reset stream needs nothing.
    client.on_frame_lost(data[0])
    var sent = frames(client, 1200)
    assert_equal(len(sent), 1)
    assert_equal(sent[0].kind, FrameType.RESET_STREAM.value)
    assert_equal(sent[0].offset, 3)
    assert_equal(sent[0].value, 8)
    # A lost RESET_STREAM goes again, until it is acknowledged.
    client.on_frame_lost(sent[0])
    assert_true(client.has_pending())
    var again = frames(client, 1200)
    assert_equal(len(again), 1)
    client.on_frame_acked(again[0])
    client.on_frame_lost(sent[0])
    assert_false(client.has_pending())
    client.release(uni)
    assert_false(client.is_open(uni))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Time the frame codec of gql_ws: read a masked text frame, and write a
text frame.

    mojo build -I . -o .cache/bin/ws_frames bench/gql_ws/frames.mojo
    .cache/bin/ws_frames

`ws/frame-parse`: a server `WebSocket` takes the bytes of one masked text
frame of 1 KiB from a client, unmasks it, checks its UTF-8, and returns
the message. `ws/frame-write`: a server `WebSocket` writes one text
message of 1 KiB as a frame into its output, and the output is taken.
The baselines run tungstenite 0.30.0 (Rust) and `ws` 8 (Node.js) on the
same bytes, with the same method: a warm-up, then the fastest of 5 rounds
of at least one second each.
"""

from std.benchmark import keep
from std.time import perf_counter_ns

from gql_ws.frame import OpCode, apply_mask, write_header
from gql_ws.protocol import Message, Role, WebSocket

comptime ROUNDS = 5
"""How many rounds are timed."""
comptime ROUND_NS = 1_000_000_000
"""The least length of a round, in nanoseconds."""
comptime WARMUP_NS = 500_000_000
"""How long a workload warms up, in nanoseconds."""
comptime PAYLOAD_SIZE = 1024
"""The bytes of the text of each frame."""


def payload() -> String:
    """The 1 KiB of text: a GraphQL `next` message, padded."""
    var text = String(
        '{"id":"1","type":"next","payload":{"data":{"greetings":"'
    )
    while text.byte_length() < PAYLOAD_SIZE - 4:
        text += "hello "
    var cut = String(text[byte = : PAYLOAD_SIZE - 4])
    text = cut^
    return text + '"}}}'


def masked_frame(text: String) -> List[UInt8]:
    """The frame of a client, masked with a fixed key."""
    var out = List[UInt8]()
    var mask: UInt32 = 0x9ABCDEF0
    write_header(out, True, OpCode.TEXT, text.byte_length(), True, mask)
    var start = len(out)
    out.extend(text.as_bytes())
    apply_mask(out.unsafe_ptr(), start, text.byte_length(), mask)
    return out^


def run_parse(
    frame: List[UInt8], mut ws: WebSocket, mut message: Message, iterations: Int
) raises -> Int:
    """Read the frame a number of times; return the nanoseconds."""
    var sink = 0
    var start = perf_counter_ns()
    for _ in range(iterations):
        ws.receive(frame)
        if not ws.read(message):
            raise Error("no message")
        sink += len(message.data)
    var elapsed = Int(perf_counter_ns() - start)
    keep(sink)
    return elapsed


def run_write(text: String, mut ws: WebSocket, iterations: Int) raises -> Int:
    """Write the message a number of times; return the nanoseconds."""
    var sink = 0
    var start = perf_counter_ns()
    for _ in range(iterations):
        ws.send_text(text)
        sink += Int(ws.output()[unsafe_offset=1])
        ws.advance(ws.pending())
    var elapsed = Int(perf_counter_ns() - start)
    keep(sink)
    return elapsed


def iterations_for[
    parse: Bool
](
    frame: List[UInt8], text: String, mut ws: WebSocket, mut message: Message
) raises -> Int:
    """Warm up, and find the iterations of one round."""
    var iterations = 1
    var warm = 0
    while True:
        var elapsed: Int
        comptime if parse:
            elapsed = run_parse(frame, ws, message, iterations)
        else:
            elapsed = run_write(text, ws, iterations)
        warm += elapsed
        if elapsed * 4 >= WARMUP_NS or warm >= WARMUP_NS:
            var per_op = max(elapsed // iterations, 1)
            return max(ROUND_NS // per_op, 1)
        iterations *= 2


def main() raises:
    """Run the workloads and print their `BENCH` lines."""
    var text = payload()
    var frame = masked_frame(text)
    var server = WebSocket(Role.SERVER)
    var message = Message()
    var iterations = iterations_for[True](frame, text, server, message)
    var best = Float64.MAX
    for _ in range(ROUNDS):
        var elapsed = run_parse(frame, server, message, iterations)
        best = min(best, Float64(elapsed) / Float64(iterations))
    print("BENCH ws/frame-parse", Float64(Int(best * 10.0)) / 10.0)
    var writer = WebSocket(Role.SERVER)
    iterations = iterations_for[False](frame, text, writer, message)
    best = Float64.MAX
    for _ in range(ROUNDS):
        var elapsed = run_write(text, writer, iterations)
        best = min(best, Float64(elapsed) / Float64(iterations))
    print("BENCH ws/frame-write", Float64(Int(best * 10.0)) / 10.0)

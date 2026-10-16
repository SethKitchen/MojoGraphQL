# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The stdio transport: one JSON-RPC message per line.

The MCP specification (2025-06-18, "Transports") defines it: the client
writes each message to the server's standard input, ended by a newline,
and the server writes each reply to its standard output in the same way.
As in the upstream SDK, a line may end with `\\r\\n`, and a line that is not
JSON gets no reply. The server answers the messages in their order; the
upstream answers requests at the same time, so its replies can come in
another order.

This module ports no code (the upstream transport is the SDK's).

Differences from upstream: the replies keep the order of the requests.
"""

from gql_http.socket import Sys
from gql_mcp.server import McpServer, Session

comptime _READ_SIZE = 65536
"""The bytes of each read."""


def serve_stream(mut server: McpServer, input: Int, output: Int) -> Int:
    """Answer the messages of one client until its input ends.

    `serve_stream(server, 0, 1)` serves standard input and standard
    output.

    Args:
        server: The server.
        input: The descriptor to read messages from.
        output: The descriptor to write replies to.

    Returns:
        How many lines the server read, or the negated error number when a
        read or a write failed.
    """
    var sys = Sys()
    var session = Session()
    var pending = List[UInt8]()
    var chunk = List[UInt8](length=_READ_SIZE, fill=0)
    var lines = 0
    var count = sys.read(input, chunk.unsafe_ptr(), _READ_SIZE)
    while count > 0:
        var start = 0
        var index = 0
        while index < count:
            if chunk[index] == UInt8(ord("\n")):
                pending.extend(Span(chunk)[start:index])
                lines += 1
                var rc = _answer(server, session, sys, output, pending)
                if rc < 0:
                    return rc
                pending.clear()
                start = index + 1
            index += 1
        pending.extend(Span(chunk)[start:count])
        count = sys.read(input, chunk.unsafe_ptr(), _READ_SIZE)
    if count < 0:
        return count
    if len(pending) > 0:
        lines += 1
        var rc = _answer(server, session, sys, output, pending)
        if rc < 0:
            return rc
    return lines


def _answer(
    mut server: McpServer,
    mut session: Session,
    mut sys: Sys,
    output: Int,
    line: List[UInt8],
) -> Int:
    """Answer one line, and write the reply with its newline."""
    var end = len(line)
    if end > 0 and line[end - 1] == UInt8(ord("\r")):
        end -= 1
    var reply = server.handle(
        session, StringSlice(unsafe_from_utf8=Span(line)[:end])
    )
    if not reply:
        return 0
    var bytes = List[UInt8](capacity=reply.value().byte_length() + 1)
    bytes.extend(reply.value().as_bytes())
    bytes.append(UInt8(ord("\n")))
    var sent = 0
    while sent < len(bytes):
        var written = sys.write(
            output, bytes.unsafe_ptr().unsafe_offset(sent), len(bytes) - sent
        )
        if written < 0:
            return written
        sent += written
    return 0

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Time a held, chunked response of the gql_http server under the load of
`_loadgen.mojo`.

    mojo build -I . -o .cache/bin/http_chunked bench/gql_http/chunked.mojo
    .cache/bin/http_chunked

`http/chunked-16-parts`: one worker process answers each POST `/stream`
with a chunked response. The handler begins the stream and holds it. Then
`poll_body` adds one chunk of `{"data":{"hello":"world"}}` per call, 16 in
all, over 64 keep-alive connections. The number is nanoseconds per
request. The baseline in `bench/baselines/rust-http` is a hyper 1 server
with one thread, whose body yields the same 16 frames.
"""

from _loadgen import RESPONSE_BODY, STREAM_CHUNKS, run_load
from gql_http.body import BodyPoll
from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter, ServerConfig, start_workers
from gql_http.socket import IPv4Address


struct Chunks(Handler):
    """Streams `STREAM_CHUNKS` chunks of the JSON response per request."""

    var left: List[Int]
    """The chunks that each connection has yet to send, by socket."""

    def __init__(out self):
        """Make a handler with no open streams."""
        self.left = List[Int](length=65536, fill=0)

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        """Begin the stream and hold it.

        Args:
            request: The request.
            response: The response.

        Raises:
            Error: Never; the content type is valid.
        """
        response.add_header("Content-Type", "application/json")
        response.begin_chunked()
        response.hold()
        self.left[response.connection()] = STREAM_CHUNKS

    def poll_body(mut self, id: Int, mut out: List[UInt8]) raises -> BodyPoll:
        """Add the next chunk, or end the stream.

        Args:
            id: The connection of the response.
            out: The destination of the bytes.

        Returns:
            `READY` after one chunk, and `DONE` after the last one.

        Raises:
            Error: Never.
        """
        if self.left[id] == 0:
            return BodyPoll.DONE
        self.left[id] -= 1
        out.extend(StaticString(RESPONSE_BODY).as_bytes())
        return BodyPoll.READY

    def body_closed(mut self, id: Int):
        """Forget a stream that ends early.

        Args:
            id: The connection of the response.
        """
        self.left[id] = 0


def main() raises:
    """Start one worker, load it, and stop it."""
    var config = ServerConfig()
    config.host = IPv4Address.LOOPBACK
    config.port = 0
    config.workers = 1
    var pool = start_workers(Chunks(), config)
    try:
        run_load("http/chunked-16-parts", pool.port)
    except e:
        _ = pool.stop(1000)
        raise e^
    _ = pool.stop(3000)

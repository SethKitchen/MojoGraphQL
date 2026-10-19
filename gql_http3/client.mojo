# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""An HTTP/3 client (RFC 9114) over QUIC from OpenSSL 3.5.

`H3Client` sends one request at a time and returns the whole
`gql_http.client.Response`, the type of the HTTP/1.1 and HTTPS clients. It
keeps one QUIC connection per address and port, and opens one request
stream per request. It opens its control stream with SETTINGS, and it
reads and drops the streams that the server opens.

Each request has the deadline `ClientConfig.timeout_ms`, for the
handshake and the whole response; the handshake also has
`connect_timeout_ms`. A short `connect_timeout_ms` makes HTTP/3 fail fast,
so that `gql_http3.fallback` can use TCP when UDP is blocked.

This module ports the request rules of hyperium/h3 h3-v0.0.8
h3/src/client/connection.rs and h3/src/client/stream.rs (MIT): one
HEADERS frame and DATA frames per request, and the end of the stream after
the content.

Differences from upstream: h3 is async and generic over a QUIC
implementation, and streams the content. This client is blocking with a
deadline, and reads the whole response.
"""

from std.time import perf_counter_ns

from gql_http.client import ClientConfig, Response, ResponseSource
from gql_http.client import read_response
from gql_http.error import ErrorKind, HttpError
from gql_http.headers import Headers
from gql_http.socket import POLLIN, Sys
from gql_http.status import Method
from gql_http.url import Url
from gql_tls.client import HttpsEndpoint
from gql_tls.error import TlsError, TlsErrorKind
from gql_tls.openssl import OpenSsl
from gql_http3.error import H3Error
from gql_http3.message import MessageReader, request_fields
from gql_http3.message import to_http1_response, write_message
from gql_http3.qpack_decoder import QpackDecoder
from gql_http3.qpack_encoder import QpackEncoder
from gql_http3.qpack_field import FieldList
from gql_http3.quic import Quic, QuicContext, ReadState
from gql_http3.server import control_preface


def _now_ns() -> Int:
    """Return a monotonic time in nanoseconds."""
    return Int(perf_counter_ns())


def h3_error(error: H3Error) -> TlsError:
    """Carry an HTTP/3 error as a `PROTOCOL` error.

    Args:
        error: The error.

    Returns:
        A `PROTOCOL` error whose `errno` is the HTTP/3 error code.
    """
    return TlsError(TlsErrorKind.PROTOCOL, String(error), Int(error.code.value))


struct _Bytes(ResponseSource):
    """A response that is in memory already."""

    var data: List[UInt8]

    def __init__(out self, var data: List[UInt8]):
        self.data = data^

    def read_more(
        mut self, mut data: List[UInt8], mut end: Int, deadline: Int
    ) raises HttpError -> Int:
        """Give the whole response, then the end of the stream."""
        var size = len(self.data)
        data.resize(end, 0)
        data.extend(Span(self.data))
        end += size
        self.data.clear()
        return size


def _key(endpoint: HttpsEndpoint) -> Int:
    """Return one number for the address and the port of an endpoint."""
    return Int(endpoint.address.value) << 16 | endpoint.port


struct _Connection(Movable):
    """A QUIC connection to one server."""

    var key: Int
    var fd: Int
    var ssl: Int
    var control: Int
    var decoder: QpackDecoder
    var encoder: QpackEncoder

    def __init__(out self, key: Int, fd: Int, ssl: Int):
        self.key = key
        self.fd = fd
        self.ssl = ssl
        self.control = 0
        self.decoder = QpackDecoder()
        self.encoder = QpackEncoder()


struct H3Client(Movable):
    """An HTTP/3 client with one QUIC connection per server."""

    var quic: Quic
    """The QUIC functions, and the fault plan of the calls."""
    var context: QuicContext
    """The client context: trust store and verification."""
    var config: ClientConfig
    """The timeouts and limits."""
    var sys: Sys
    """The system calls; tests give one with faults."""
    var _conns: List[_Connection]
    var _buffer: List[UInt8]
    var _fields: FieldList
    var _block: List[UInt8]
    var _encoder_out: List[UInt8]
    var _out: List[UInt8]
    var _no_stream: Bool

    def __init__(
        out self,
        var context: QuicContext,
        config: ClientConfig = ClientConfig(),
    ):
        """Make a client without connections.

        Args:
            context: A client context from `QuicContext.client`.
            config: The timeouts and limits.
        """
        self.quic = context.quic.copy()
        self.context = context^
        self.config = config.copy()
        self.sys = Sys()
        self._conns = List[_Connection]()
        self._buffer = List[UInt8](length=65536, fill=0)
        self._fields = FieldList()
        self._block = List[UInt8]()
        self._encoder_out = List[UInt8]()
        self._out = List[UInt8]()
        self._no_stream = False

    @staticmethod
    def system(
        config: ClientConfig = ClientConfig(),
    ) raises TlsError -> H3Client:
        """Make a client that trusts the system CA store.

        Args:
            config: The timeouts and limits.

        Returns:
            The client.

        Raises:
            TlsError: `LIBRARY` without OpenSSL 3.5; `CONFIG` when the
                system store does not load.
        """
        var context = QuicContext.client(Quic(OpenSsl()))
        return H3Client(context^, config)

    def __deinit__(deinit self):
        """Close every connection."""
        self.close()

    def connections(self) -> Int:
        """Return the count of open connections.

        Returns:
            The count.
        """
        return len(self._conns)

    def close(mut self):
        """Close every connection."""
        while len(self._conns) > 0:
            self._drop(len(self._conns) - 1)

    def _drop(mut self, index: Int):
        """Close one connection and forget it."""
        var conn = self._conns.pop(index)
        self.quic.free(conn.control)
        self.quic.close_connection(conn.ssl, 0x100)
        self.quic.free(conn.ssl)
        self.sys.close(conn.fd)

    def endpoint(mut self, url: StringSlice) raises TlsError -> HttpsEndpoint:
        """Parse an `https` URL and resolve its host.

        Args:
            url: The URL, such as `https://localhost:4433/graphql`.

        Returns:
            The endpoint.

        Raises:
            TlsError: `PROTOCOL` for an invalid URL, `USAGE` for a scheme
                other than `https`, `RESOLVE` for an unknown host.
        """
        try:
            var parsed = Url.parse(url)
            if parsed.scheme != "https":
                raise HttpError(
                    ErrorKind.USAGE,
                    "HTTP/3 needs an https URL: " + String(url),
                    0,
                )
            var address = self.sys.resolve(parsed.host)
            return HttpsEndpoint(
                address,
                parsed.port,
                parsed.host.copy(),
                parsed.authority(),
                parsed.target(),
            )
        except e:
            raise TlsError.from_http(e)

    def get(mut self, url: StringSlice) raises TlsError -> Response:
        """Send a `GET` request.

        Args:
            url: The URL.

        Returns:
            The response.

        Raises:
            TlsError: For an invalid URL, a failed handshake, a timeout or
                an invalid response.
        """
        var endpoint = self.endpoint(url)
        var target = endpoint.target.copy()
        return self.send(endpoint, Method.GET, target, Headers(), List[UInt8]())

    def post(
        mut self, url: StringSlice, content_type: StringSlice, body: StringSlice
    ) raises TlsError -> Response:
        """Send a `POST` request with content.

        Args:
            url: The URL.
            content_type: The `Content-Type` value.
            body: The content.

        Returns:
            The response.

        Raises:
            TlsError: For an invalid URL or content type, a failed
                handshake, a timeout or an invalid response.
        """
        var endpoint = self.endpoint(url)
        var headers = Headers()
        try:
            headers.add("Content-Type", content_type)
        except e:
            raise TlsError.from_http(e)
        var target = endpoint.target.copy()
        return self.send(
            endpoint, Method.POST, target, headers, body.as_bytes()
        )

    def _wait(mut self, index: Int, deadline: Int) raises TlsError:
        """Wait for a datagram or a timer of a connection, then run it."""
        var remaining = (deadline - _now_ns() + 999_999) // 1_000_000
        if remaining <= 0:
            raise TlsError(
                TlsErrorKind.TIMEOUT, "the HTTP/3 request timed out", 0
            )
        ref conn = self._conns[index]
        var timer = self.quic.event_timeout_ms(conn.ssl)
        var wait = remaining if timer < 0 else min(timer, remaining)
        _ = self.sys.poll(conn.fd, POLLIN, wait)
        self.quic.handle_events(conn.ssl)

    def _find(mut self, endpoint: HttpsEndpoint) -> Int:
        """Return the open connection to an endpoint, or -1."""
        var index = len(self._conns) - 1
        while index >= 0:
            ref conn = self._conns[index]
            if conn.key == _key(endpoint):
                if not self.quic.connection_closed(conn.ssl):
                    return index
                self._drop(index)
            index -= 1
        return -1

    def _connect(
        mut self, endpoint: HttpsEndpoint, deadline: Int
    ) raises TlsError -> Int:
        """Open a QUIC connection, run the handshake, open the control
        stream, and return the index of the connection."""
        var fd = self.quic.udp_socket()
        if fd < 0:
            raise TlsError(TlsErrorKind.OS, "cannot open a UDP socket", 0)
        var rc = self.sys.connect(fd, endpoint.address, endpoint.port)
        if rc < 0:
            self.sys.close(fd)
            raise TlsError(
                TlsErrorKind.CONNECT,
                "cannot connect to " + String(endpoint),
                -rc,
            )
        var ssl = self.quic.client_connection(
            self.context.ctx, fd, endpoint.host, self.context.verify
        )
        if ssl == 0:
            self.sys.close(fd)
            raise TlsError(
                TlsErrorKind.CONFIG, "cannot make a QUIC connection", 0
            )
        self._conns.append(_Connection(_key(endpoint), fd, ssl))
        var index = len(self._conns) - 1
        var limit = min(
            deadline, _now_ns() + self.config.connect_timeout_ms * 1_000_000
        )
        try:
            while True:
                var result = self.quic.connect(ssl)
                if result == 1:
                    break
                if result < 0:
                    raise self._handshake_error(ssl)
                # Send the handshake packets, then wait for the answer.
                self.quic.handle_events(ssl)
                self._wait(index, limit)
            var control = self.quic.new_stream(ssl, True)
            if control == 0:
                raise TlsError(
                    TlsErrorKind.PROTOCOL, "cannot open the control stream", 0
                )
            self._conns[index].control = control
            var preface = control_preface(self.config.limits)
            _ = self.quic.write(
                control, preface.unsafe_ptr(), len(preface), False
            )
        except e:
            self._drop(index)
            raise e^
        return index

    def _handshake_error(mut self, ssl: Int) -> TlsError:
        """Make the error of a failed handshake."""
        if self.context.verify:
            var text = self.quic.verify_failure(ssl)
            if text.byte_length() > 0:
                return TlsError(
                    TlsErrorKind.VERIFY,
                    "the certificate of the server did not verify: " + text,
                    0,
                )
        var detail = self.quic.failure(ssl)
        return TlsError(
            TlsErrorKind.HANDSHAKE, "the QUIC handshake failed: " + detail, 0
        )

    def send(
        mut self,
        endpoint: HttpsEndpoint,
        method: Method,
        target: StringSlice,
        headers: Headers,
        body: Span[UInt8, _],
    ) raises TlsError -> Response:
        """Send a request on a request stream and read the whole response.

        Args:
            endpoint: Where to send it.
            method: The method; not `OTHER`.
            target: The request target, such as `/graphql?x=1`.
            headers: The other header fields; `Host` and the fields that
                are specific to a connection are dropped.
            body: The content; empty for none.

        Returns:
            The response.

        Raises:
            TlsError: `USAGE` for an `OTHER` method; `CONNECT`,
                `HANDSHAKE`, `VERIFY`, `TIMEOUT`, `CLOSED`, `PROTOCOL` or
                `OS` when the exchange fails.
        """
        if method == Method.OTHER or not method.is_valid():
            raise TlsError(TlsErrorKind.USAGE, "invalid method", 0)
        var deadline = _now_ns() + self.config.timeout_ms * 1_000_000
        var index = self._find(endpoint)
        if index >= 0:
            try:
                return self._exchange(
                    index, method, endpoint, target, headers, body, deadline
                )
            except e:
                self._drop(index)
                # A connection that is closing gives no stream: the
                # request did not go out, so a new connection sends it.
                if not self._no_stream:
                    raise e^
        index = self._connect(endpoint, deadline)
        try:
            return self._exchange(
                index, method, endpoint, target, headers, body, deadline
            )
        except e:
            self._drop(index)
            raise e^

    def _exchange(
        mut self,
        index: Int,
        method: Method,
        endpoint: HttpsEndpoint,
        target: StringSlice,
        headers: Headers,
        body: Span[UInt8, _],
        deadline: Int,
    ) raises TlsError -> Response:
        """Run one request on a connection."""
        var stream = self.quic.new_stream(self._conns[index].ssl, False)
        self._no_stream = stream == 0
        if stream == 0:
            raise TlsError(TlsErrorKind.PROTOCOL, "cannot open a stream", 0)
        try:
            return self._run(
                index, stream, method, endpoint, target, headers, body, deadline
            )
        finally:
            self.quic.free(stream)

    def _run(
        mut self,
        index: Int,
        stream: Int,
        method: Method,
        endpoint: HttpsEndpoint,
        target: StringSlice,
        headers: Headers,
        body: Span[UInt8, _],
        deadline: Int,
    ) raises TlsError -> Response:
        """Write the request on a stream and read the response."""
        var id = self.quic.stream_id(stream)
        request_fields(
            method, endpoint.authority, target, headers, len(body), self._fields
        )
        self._block.clear()
        self._encoder_out.clear()
        _ = self._conns[index].encoder.encode(
            id, self._fields, self._block, self._encoder_out
        )
        self._out.clear()
        write_message(self._block, body, self._out)
        var sent = 0
        while True:
            var n = self.quic.write(
                stream,
                self._out.unsafe_ptr().unsafe_offset(sent),
                len(self._out) - sent,
                True,
            )
            if n < 0:
                raise TlsError(TlsErrorKind.CLOSED, "the stream failed", 0)
            sent += n
            if sent >= len(self._out):
                break
            # Send what the stream took, then wait for more credit.
            self.quic.handle_events(self._conns[index].ssl)
            self._wait(index, deadline)
        self.quic.handle_events(self._conns[index].ssl)
        var reader = MessageReader(self.config.limits.max_body_bytes)
        while True:
            var result = self.quic.read(
                stream, self._buffer.unsafe_ptr(), len(self._buffer)
            )
            if result.state == ReadState.WAIT:
                # The streams of the server matter only while the client
                # waits. Reads do no network I/O, so none is missed.
                self._drain_incoming(index)
                self._wait(index, deadline)
                continue
            if result.state == ReadState.DATA:
                try:
                    reader.feed(
                        Span(self._buffer)[0 : result.count],
                        id,
                        self._conns[index].decoder,
                    )
                except e:
                    raise h3_error(e)
                continue
            if result.state == ReadState.END:
                break
            raise TlsError(
                TlsErrorKind.CLOSED, "the server reset the stream", 0
            )
        var bytes = List[UInt8]()
        try:
            reader.finish()
            to_http1_response(reader.fields, reader.body, bytes)
        except e:
            raise h3_error(e)
        var source = _Bytes(bytes^)
        var response = Response()
        try:
            _ = read_response(
                source, method, self.config.limits, deadline, response
            )
        except e:
            raise TlsError.from_http(e)
        return response^

    def _drain_incoming(mut self, index: Int):
        """Accept the streams that the server opens, and drop their bytes."""
        while True:
            var ssl = self.quic.accept_stream(self._conns[index].ssl)
            if ssl == 0:
                return
            while True:
                var result = self.quic.read(
                    ssl, self._buffer.unsafe_ptr(), len(self._buffer)
                )
                if result.state != ReadState.DATA:
                    break
            self.quic.free(ssl)

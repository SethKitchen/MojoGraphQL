# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A `gql_http2` `Transport` over a TLS connection of `gql_tls`.

`TlsTransport` owns a `TlsStream` after its handshake, and its socket.
`read` and `write` never block:

- A TLS operation that waits for the socket returns `-EAGAIN`. OpenSSL
  gives the decrypted bytes that it holds before it waits, so a caller
  that polls `fd()` after `-EAGAIN` misses no byte.
- A TLS error returns its system error number, or `-ECONNRESET` when it
  has none, such as a bad record.
- `close()` sends `close_notify`, frees the stream and closes the socket.

A TLS 1.3 read can wait for a write. The transport returns `-EAGAIN` then,
and the caller waits for the socket to be readable, as RFC 8446 lets a
peer do.

This module ports no code. The behavior follows RFC 9113 section 3.2 and
RFC 8446.

Differences from upstream: none; there is no upstream.
"""

from gql_http.socket import ECONNRESET, EAGAIN, Sys
from gql_http2.session import Transport
from gql_tls.error import TlsError
from gql_tls.stream import TlsStream


def transport_errno(error: TlsError) -> Int:
    """Return the negative error number of a failed TLS read or write.

    Args:
        error: The error.

    Returns:
        `-errno` of the error, or `-ECONNRESET` when it has none.
    """
    if error.errno > 0:
        return -error.errno
    return -ECONNRESET


struct TlsTransport(Transport):
    """A TLS connection as an HTTP/2 transport."""

    var stream: TlsStream
    """The stream, after its handshake; a placeholder once closed."""
    var sys: Sys
    """The system calls that close the socket."""

    def __init__(out self, var stream: TlsStream, var sys: Sys = Sys()):
        """Take a stream and its socket.

        Args:
            stream: The stream, after its handshake. The transport closes
                its socket.
            sys: The system calls; tests give one with faults.
        """
        self.stream = stream^
        self.sys = sys^

    def __deinit__(deinit self):
        """Close the connection when it is still open."""
        self.close()

    def read(
        mut self, data: Pointer[UInt8, MutUntrackedOrigin], size: Int
    ) -> Int:
        """Read decrypted bytes.

        Args:
            data: Where to put them.
            size: The most bytes to read.

        Returns:
            The count of bytes; 0 at the end of the stream; `-EAGAIN` when
            the stream waits for the socket; another negative error number
            when the connection failed.
        """
        try:
            var n = self.stream.read(data, size)
            if n < 0:
                return -EAGAIN
            return n
        except e:
            return transport_errno(e)

    def write(
        mut self, data: Pointer[UInt8, ImmUntrackedOrigin], size: Int
    ) -> Int:
        """Encrypt and send bytes, as many as the stream takes now.

        Args:
            data: The bytes.
            size: How many.

        Returns:
            The count of bytes taken; `-EAGAIN` when the stream waits for
            the socket; another negative error number when the connection
            failed.
        """
        try:
            var n = self.stream.write(data, size)
            if n < 0:
                return -EAGAIN
            return n
        except e:
            return transport_errno(e)

    def close(mut self):
        """Send `close_notify`, free the stream and close the socket, once."""
        var fd = self.stream.fd
        if fd < 0:
            return
        _ = self.stream.shutdown()
        var openssl = self.stream.openssl.copy()
        self.stream = TlsStream(openssl)
        self.sys.close(fd)

    def fd(self) -> Int:
        """Return the socket.

        Returns:
            The descriptor, or -1 once closed.
        """
        return self.stream.fd

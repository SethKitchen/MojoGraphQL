# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The system OpenSSL 3, loaded at run time with `dlopen`.

`load_openssl` opens `libssl.so.3` and `libcrypto.so.3` and looks up each
function once. A program that does not call it does not need OpenSSL: no
symbol of OpenSSL is linked. When the library is missing, `load_openssl`
raises a `LIBRARY` error that says what to install.

`OpenSsl` is a table of the functions, and a reference to the open
library. Copies share the library, which closes when the last copy ends.
Every call goes through a method of `OpenSsl`, and `OpenSsl.faults` can
make one kind of call fail, so that tests can reach the error paths.
`function` looks up another function, such as the QUIC API that
`gql_http3` uses.

An opaque OpenSSL object, such as `SSL_CTX *` or `SSL *`, is an `Int`
address. A buffer is a typed `Pointer`, so that its owner stays alive for
the call.

This module ports no code. It calls the public API of OpenSSL 3, which is
Apache-2.0 licensed; no OpenSSL code is copied. The constants are those of
the OpenSSL 3 headers `ssl.h`, `tls1.h` and `x509_vfy.h`.

The cached function pointers are `std.ffi._DLCallable` values: the public
`OwnedDLHandle.get_function` returns that type, and a struct field must
name it. This is one of the places the project reaches past a leading
underscore.

Differences from upstream: none; there is no upstream.
"""

from std.ffi import OwnedDLHandle, RTLD, _DLCallable, external_call
from std.memory import ArcPointer, stack_allocation

from gql_tls.error import TlsError, TlsErrorKind

comptime CFunction[R: RegisterPassable] = _DLCallable[R, MutUntrackedOrigin]
"""A function of a loaded library that returns `R`."""

comptime SSL_ERROR_NONE: Int32 = 0
"""`SSL_get_error`: the call succeeded."""
comptime SSL_ERROR_SSL: Int32 = 1
"""`SSL_get_error`: a protocol error; the error queue says more."""
comptime SSL_ERROR_WANT_READ: Int32 = 2
"""`SSL_get_error`: the call needs to read from the socket first."""
comptime SSL_ERROR_WANT_WRITE: Int32 = 3
"""`SSL_get_error`: the call needs to write to the socket first."""
comptime SSL_ERROR_SYSCALL: Int32 = 5
"""`SSL_get_error`: a system call failed, or the peer closed at once."""
comptime SSL_ERROR_ZERO_RETURN: Int32 = 6
"""`SSL_get_error`: the peer sent `close_notify`."""

comptime TLS1_2_VERSION = 0x0303
"""The protocol number of TLS 1.2."""
comptime TLS1_3_VERSION = 0x0304
"""The protocol number of TLS 1.3."""

comptime SSL_CTRL_MODE: Int32 = 33
"""`SSL_CTX_ctrl`: add mode bits."""
comptime SSL_CTRL_SET_TLSEXT_HOSTNAME: Int32 = 55
"""`SSL_ctrl`: set the server name indication."""
comptime SSL_CTRL_SET_MIN_PROTO_VERSION: Int32 = 123
"""`SSL_CTX_ctrl`: set the oldest protocol version."""
comptime SSL_MODE_ENABLE_PARTIAL_WRITE = 0x1
"""A write can send part of the buffer."""
comptime SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER = 0x2
"""A retried write can pass another buffer address."""
comptime SSL_FILETYPE_PEM: Int32 = 1
"""A PEM file."""
comptime SSL_VERIFY_NONE: Int32 = 0
"""Do not verify the peer."""
comptime SSL_VERIFY_PEER: Int32 = 1
"""Verify the certificate of the peer."""
comptime SSL_TLSEXT_ERR_OK: Int32 = 0
"""ALPN selection: a protocol was chosen."""
comptime SSL_TLSEXT_ERR_NOACK: Int32 = 3
"""ALPN selection: no common protocol; go on without ALPN."""
comptime SSL_OP_IGNORE_UNEXPECTED_EOF: UInt64 = 1 << 7
"""Read an end of stream without `close_notify` as a clean end."""
comptime SSL_OP_NO_RENEGOTIATION: UInt64 = 1 << 30
"""Refuse TLS 1.2 renegotiation."""
comptime X509_V_OK = 0
"""The certificate verified."""
comptime OPENSSL_3 = 0x30000000
"""The version number of OpenSSL 3.0.0."""


@fieldwise_init
struct TlsCall(Equatable, ImplicitlyCopyable, Writable):
    """A kind of OpenSSL call that `TlsFaults` can make fail."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime NONE = TlsCall(0)
    """No call: faults are off."""
    comptime CTX_NEW = TlsCall(1)
    """`SSL_CTX_new`."""
    comptime CTX_CTRL = TlsCall(2)
    """`SSL_CTX_ctrl`."""
    comptime TRUST = TlsCall(3)
    """`SSL_CTX_set_default_verify_paths` and `SSL_CTX_load_verify_locations`."""
    comptime ALPN = TlsCall(4)
    """`SSL_CTX_set_alpn_protos`."""
    comptime SSL_NEW = TlsCall(5)
    """`SSL_new`."""
    comptime SET_FD = TlsCall(6)
    """`SSL_set_fd`."""
    comptime SET_HOST = TlsCall(7)
    """`SSL_set1_host` and the server name of `SSL_ctrl`."""
    comptime HANDSHAKE = TlsCall(8)
    """`SSL_do_handshake`; a fault is `SSL_ERROR_SSL`."""
    comptime READ = TlsCall(9)
    """`SSL_read`; a fault is `SSL_ERROR_SSL`."""
    comptime WRITE = TlsCall(10)
    """`SSL_write`; a fault is `SSL_ERROR_SSL`."""
    comptime SHUTDOWN = TlsCall(11)
    """`SSL_shutdown`; a fault is a failure."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 11

    def write_to(self, mut writer: Some[Writer]):
        """Write the index of the kind.

        Args:
            writer: The destination.
        """
        writer.write("TlsCall(", self.value, ")")


@fieldwise_init
struct TlsFaults(Copyable, Movable):
    """A plan that makes one kind of OpenSSL call fail, for tests.

    The first `skip` matching calls run. The next `count` matching calls
    fail without reaching OpenSSL. A `count` of -1 fails every later call.
    """

    var call: TlsCall
    """The kind of call to fail, or `TlsCall.NONE`."""
    var skip: Int
    """How many matching calls run before the first failure."""
    var count: Int
    """How many matching calls fail; -1 for no limit."""

    def __init__(out self):
        """Make a plan that fails nothing."""
        self.call = TlsCall.NONE
        self.skip = 0
        self.count = 0

    def take(mut self, call: TlsCall) -> Bool:
        """Decide whether this call fails.

        Args:
            call: The kind of the call that is about to run.

        Returns:
            True when the call must fail.
        """
        if self.call != call or self.count == 0:
            return False
        if self.skip > 0:
            self.skip -= 1
            return False
        if self.count > 0:
            self.count -= 1
        return True


def c_string(address: Int) -> String:
    """Copy a NUL-terminated C string.

    Args:
        address: The address of the string; 0 gives an empty string.

    Returns:
        The text.
    """
    if address == 0:
        return String()
    var size = external_call["strlen", Int](address)
    var p = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=address)
    return String(unsafe_from_utf8=Span(unsafe_ptr=p, length=size))


def select_protocol(
    server: Pointer[UInt8, _], client: Pointer[UInt8, _], client_size: Int
) -> Int:
    """Choose the ALPN protocol: the first of the server that the client
    offers (RFC 7301 section 3.2).

    Args:
        server: The protocols of the server, each with a length byte
            before it, and a 0 byte at the end.
        client: The protocols of the client, each with a length byte.
        client_size: The size of the client list.

    Returns:
        The offset of the length byte of the chosen protocol in the client
        list, or -1 when they have no protocol in common.
    """
    var at = 0
    while server[unsafe_offset=at] != 0:
        var size = Int(server[unsafe_offset=at])
        var offset = 0
        while offset < client_size:
            var other = Int(client[unsafe_offset=offset])
            if other == size and offset + 1 + size <= client_size:
                var index = 0
                while index < size and (
                    server[unsafe_offset=at + 1 + index]
                    == client[unsafe_offset=offset + 1 + index]
                ):
                    index += 1
                if index == size:
                    return offset
            offset += 1 + other
        at += 1 + size
    return -1


def _alpn_select(
    ssl: Int,
    selected: Pointer[Int, MutUntrackedOrigin],
    out_size: Pointer[UInt8, MutUntrackedOrigin],
    client: Pointer[UInt8, MutUntrackedOrigin],
    client_size: UInt32,
    server: Pointer[UInt8, MutUntrackedOrigin],
) abi("C") -> Int32:
    """The ALPN callback of `SSL_CTX_set_alpn_select_cb`.

    With no protocol in common, the handshake goes on without ALPN, and
    the connection is HTTP/1.1: the fallback that RFC 7301 allows.
    """
    var offset = select_protocol(server, client, Int(client_size))
    if offset < 0:
        return SSL_TLSEXT_ERR_NOACK
    selected[] = Int(client.unsafe_offset(offset + 1))
    out_size[] = client[unsafe_offset=offset]
    return SSL_TLSEXT_ERR_OK


def _open(path: String) raises TlsError -> ArcPointer[OwnedDLHandle]:
    """Open a library, or raise the `LIBRARY` error that says what to do."""
    try:
        return ArcPointer(OwnedDLHandle(path, RTLD.NOW | RTLD.GLOBAL))
    except e:
        raise TlsError(
            TlsErrorKind.LIBRARY,
            "gql_tls needs OpenSSL 3 at run time, and "
            + path
            + " did not load ("
            + String(e)
            + "). Install the OpenSSL 3 library, such as the libssl3"
            " package, or pick a package without TLS.",
            0,
        )


def _find[
    R: RegisterPassable
](library: ArcPointer[OwnedDLHandle], name: StaticString) raises TlsError -> (
    CFunction[R]
):
    """Look up one function of an open library."""
    var symbol = library[].get_symbol[NoneType](String(name))
    if not symbol:
        raise TlsError(
            TlsErrorKind.LIBRARY,
            "the OpenSSL library has no function " + String(name),
            0,
        )
    return CFunction[R](
        symbol.value().unsafe_origin_cast[MutUntrackedOrigin](),
        Pointer(to=library[]).unsafe_origin_cast[MutUntrackedOrigin](),
    )


struct OpenSsl(Copyable, Movable):
    """The functions of OpenSSL 3 that `gql_tls` calls, and a fault plan.

    Copies share the open libraries. A copy has its own fault plan.
    """

    var ssl_library: ArcPointer[OwnedDLHandle]
    """`libssl.so.3`."""
    var crypto_library: ArcPointer[OwnedDLHandle]
    """`libcrypto.so.3`."""
    var faults: TlsFaults
    """The plan of calls that fail; empty by default."""
    var version: UInt64
    """`OpenSSL_version_num()`, such as `0x30500050` for 3.5.5."""
    var _server_method: CFunction[Int]
    var _client_method: CFunction[Int]
    var _ctx_new: CFunction[Int]
    var _ctx_free: CFunction[NoneType]
    var _ctx_ctrl: CFunction[Int]
    var _use_chain: CFunction[Int32]
    var _use_key: CFunction[Int32]
    var _check_key: CFunction[Int32]
    var _default_paths: CFunction[Int32]
    var _load_locations: CFunction[Int32]
    var _set_verify: CFunction[NoneType]
    var _set_options: CFunction[UInt64]
    var _alpn_select_cb: CFunction[NoneType]
    var _set_alpn: CFunction[Int32]
    var _ssl_new: CFunction[Int]
    var _ssl_free: CFunction[NoneType]
    var _set_fd: CFunction[Int32]
    var _accept_state: CFunction[NoneType]
    var _connect_state: CFunction[NoneType]
    var _handshake: CFunction[Int32]
    var _read: CFunction[Int32]
    var _write: CFunction[Int32]
    var _get_error: CFunction[Int32]
    var _shutdown: CFunction[Int32]
    var _alpn_selected: CFunction[NoneType]
    var _set1_host: CFunction[Int32]
    var _ssl_ctrl: CFunction[Int]
    var _verify_result: CFunction[Int]
    var _pending: CFunction[Int32]
    var _err_get: CFunction[UInt64]
    var _err_string: CFunction[NoneType]
    var _err_clear: CFunction[NoneType]
    var _verify_string: CFunction[Int]
    var _faulted: Bool

    def __init__(
        out self,
        ssl_path: String = "libssl.so.3",
        crypto_path: String = "libcrypto.so.3",
        min_version: UInt64 = OPENSSL_3,
    ) raises TlsError:
        """Load OpenSSL and look up its functions.

        Args:
            ssl_path: The file name or path of libssl.
            crypto_path: The file name or path of libcrypto.
            min_version: The oldest `OpenSSL_version_num()` to accept.

        Raises:
            TlsError: `LIBRARY` when a library does not load, lacks a
                function, or is older than `min_version`.
        """
        var crypto = _open(crypto_path)
        var ssl = _open(ssl_path)
        var version = _find[UInt64](crypto, "OpenSSL_version_num")()
        if version < min_version:
            raise TlsError(
                TlsErrorKind.LIBRARY,
                "gql_tls needs OpenSSL 3 or newer; the library is version "
                + hex(version),
                0,
            )
        self._server_method = _find[Int](ssl, "TLS_server_method")
        self._client_method = _find[Int](ssl, "TLS_client_method")
        self._ctx_new = _find[Int](ssl, "SSL_CTX_new")
        self._ctx_free = _find[NoneType](ssl, "SSL_CTX_free")
        self._ctx_ctrl = _find[Int](ssl, "SSL_CTX_ctrl")
        self._use_chain = _find[Int32](
            ssl, "SSL_CTX_use_certificate_chain_file"
        )
        self._use_key = _find[Int32](ssl, "SSL_CTX_use_PrivateKey_file")
        self._check_key = _find[Int32](ssl, "SSL_CTX_check_private_key")
        self._default_paths = _find[Int32](
            ssl, "SSL_CTX_set_default_verify_paths"
        )
        self._load_locations = _find[Int32](
            ssl, "SSL_CTX_load_verify_locations"
        )
        self._set_verify = _find[NoneType](ssl, "SSL_CTX_set_verify")
        self._set_options = _find[UInt64](ssl, "SSL_CTX_set_options")
        self._alpn_select_cb = _find[NoneType](
            ssl, "SSL_CTX_set_alpn_select_cb"
        )
        self._set_alpn = _find[Int32](ssl, "SSL_CTX_set_alpn_protos")
        self._ssl_new = _find[Int](ssl, "SSL_new")
        self._ssl_free = _find[NoneType](ssl, "SSL_free")
        self._set_fd = _find[Int32](ssl, "SSL_set_fd")
        self._accept_state = _find[NoneType](ssl, "SSL_set_accept_state")
        self._connect_state = _find[NoneType](ssl, "SSL_set_connect_state")
        self._handshake = _find[Int32](ssl, "SSL_do_handshake")
        self._read = _find[Int32](ssl, "SSL_read")
        self._write = _find[Int32](ssl, "SSL_write")
        self._get_error = _find[Int32](ssl, "SSL_get_error")
        self._shutdown = _find[Int32](ssl, "SSL_shutdown")
        self._alpn_selected = _find[NoneType](ssl, "SSL_get0_alpn_selected")
        self._set1_host = _find[Int32](ssl, "SSL_set1_host")
        self._ssl_ctrl = _find[Int](ssl, "SSL_ctrl")
        self._verify_result = _find[Int](ssl, "SSL_get_verify_result")
        self._pending = _find[Int32](ssl, "SSL_pending")
        self._err_get = _find[UInt64](crypto, "ERR_get_error")
        self._err_string = _find[NoneType](crypto, "ERR_error_string_n")
        self._err_clear = _find[NoneType](crypto, "ERR_clear_error")
        self._verify_string = _find[Int](
            crypto, "X509_verify_cert_error_string"
        )
        self.ssl_library = ssl^
        self.crypto_library = crypto^
        self.faults = TlsFaults()
        self.version = version
        self._faulted = False

    def function[
        R: RegisterPassable
    ](self, name: StaticString) raises TlsError -> CFunction[R]:
        """Look up another function of libssl, such as `SSL_new_listener`.

        The function is valid while a copy of this `OpenSsl` lives.

        Parameters:
            R: The return type of the function.

        Args:
            name: The name of the function.

        Returns:
            The function.

        Raises:
            TlsError: `LIBRARY` when libssl has no such function.
        """
        return _find[R](self.ssl_library, name)

    def has_function(self, name: StaticString) -> Bool:
        """Return True when libssl has a function, such as the QUIC API.

        Args:
            name: The name of the function.

        Returns:
            Whether the symbol exists.
        """
        return self.ssl_library[].check_symbol(String(name))

    @always_inline
    def _fail(mut self, call: TlsCall) -> Bool:
        """Return True when the fault plan fails this call."""
        if self.faults.call.value == 0:
            return False
        return self.faults.take(call)

    def last_error(mut self) -> String:
        """Take the oldest error of the OpenSSL error queue, and clear it.

        Returns:
            The OpenSSL text, such as `error:0A000086:SSL
            routines::certificate verify failed`, or an empty string.
        """
        var code = self._err_get()
        var text = String()
        if code != 0:
            var buffer = stack_allocation[256, UInt8]()
            buffer[unsafe_offset=0] = 0
            self._err_string(code, buffer, 256)
            text = c_string(Int(buffer))
        self._err_clear()
        return text^

    def clear_errors(mut self):
        """Clear the OpenSSL error queue of this thread."""
        self._err_clear()

    def verify_text(mut self, result: Int) -> String:
        """Describe an X.509 verification result.

        Args:
            result: The result of `SSL_get_verify_result`.

        Returns:
            The text, such as `self-signed certificate`.
        """
        return c_string(self._verify_string(result))

    def ctx_new(mut self, server: Bool) -> Int:
        """Make an `SSL_CTX` for TLS servers or TLS clients.

        Args:
            server: True for a server context.

        Returns:
            The context, or 0.
        """
        if self._fail(TlsCall.CTX_NEW):
            return 0
        var method = self._server_method() if server else self._client_method()
        return self._ctx_new(method)

    def ctx_free(mut self, ctx: Int):
        """Free an `SSL_CTX`.

        Args:
            ctx: The context.
        """
        self._ctx_free(ctx)

    def ctx_ctrl(mut self, ctx: Int, command: Int32, value: Int) -> Int:
        """Call `SSL_CTX_ctrl` with an integer argument.

        Args:
            ctx: The context.
            command: The `SSL_CTRL_*` command.
            value: The argument.

        Returns:
            The result; 0 is a failure for most commands.
        """
        if self._fail(TlsCall.CTX_CTRL):
            return 0
        return self._ctx_ctrl(ctx, command, value, 0)

    def use_certificate_chain(mut self, ctx: Int, var path: String) -> Bool:
        """Load a PEM certificate chain, leaf first.

        Args:
            ctx: The context.
            path: The file.

        Returns:
            Whether it loaded.
        """
        return self._use_chain(ctx, path.as_c_string_span().ptr()) == 1

    def use_private_key(mut self, ctx: Int, var path: String) -> Bool:
        """Load a PEM private key, and check that it fits the certificate.

        Args:
            ctx: The context.
            path: The file.

        Returns:
            Whether it loaded and fits.
        """
        var name = path.as_c_string_span().ptr()
        if self._use_key(ctx, name, SSL_FILETYPE_PEM) != 1:
            return False
        return self._check_key(ctx) == 1

    def use_trust(mut self, ctx: Int, var ca_file: String) -> Bool:
        """Trust a PEM file of CA certificates, or the system store.

        Args:
            ctx: The context.
            ca_file: The file; empty for the default system store.

        Returns:
            Whether it loaded.
        """
        if self._fail(TlsCall.TRUST):
            return False
        if ca_file.byte_length() == 0:
            return self._default_paths(ctx) == 1
        var name = ca_file.as_c_string_span().ptr()
        return self._load_locations(ctx, name, 0) == 1

    def set_verify(mut self, ctx: Int, mode: Int32):
        """Set the verification mode of a context.

        Args:
            ctx: The context.
            mode: `SSL_VERIFY_NONE` or `SSL_VERIFY_PEER`.
        """
        self._set_verify(ctx, mode, 0)

    def set_options(mut self, ctx: Int, options: UInt64):
        """Add `SSL_OP_*` options to a context.

        Args:
            ctx: The context.
            options: The option bits.
        """
        _ = self._set_options(ctx, options)

    def set_alpn_select(mut self, ctx: Int, wire: Span[UInt8, _]):
        """Make a server context choose a protocol with `select_protocol`.

        Args:
            ctx: The context.
            wire: The protocols of the server, in order of preference, each
                with a length byte before it, and a 0 byte at the end. It
                must live and stay unchanged as long as the context.
        """
        self._alpn_select_cb(ctx, _alpn_select, wire.unsafe_ptr())

    def set_alpn_protocols(mut self, ctx: Int, wire: Span[UInt8, _]) -> Bool:
        """Set the protocols that a client context offers.

        Args:
            ctx: The context.
            wire: The protocols, each with a length byte before it.

        Returns:
            Whether OpenSSL took them.
        """
        if self._fail(TlsCall.ALPN):
            return False
        return self._set_alpn(ctx, wire.unsafe_ptr(), UInt32(len(wire))) == 0

    def ssl_new(mut self, ctx: Int) -> Int:
        """Make an `SSL` connection object.

        Args:
            ctx: The context.

        Returns:
            The object, or 0.
        """
        if self._fail(TlsCall.SSL_NEW):
            return 0
        return self._ssl_new(ctx)

    def ssl_free(mut self, ssl: Int):
        """Free an `SSL` object.

        Args:
            ssl: The object.
        """
        self._ssl_free(ssl)

    def set_fd(mut self, ssl: Int, fd: Int) -> Bool:
        """Bind a connection object to a socket.

        Args:
            ssl: The object.
            fd: The socket.

        Returns:
            Whether it worked.
        """
        if self._fail(TlsCall.SET_FD):
            return False
        return self._set_fd(ssl, Int32(fd)) == 1

    def set_accept_state(mut self, ssl: Int):
        """Make a connection object act as the server.

        Args:
            ssl: The object.
        """
        self._accept_state(ssl)

    def set_connect_state(mut self, ssl: Int):
        """Make a connection object act as the client.

        Args:
            ssl: The object.
        """
        self._connect_state(ssl)

    def set_host(mut self, ssl: Int, var host: String) -> Bool:
        """Set the server name of a client: SNI and the name to verify.

        Args:
            ssl: The object.
            host: The host name.

        Returns:
            Whether it worked.
        """
        if self._fail(TlsCall.SET_HOST):
            return False
        var name = host.as_c_string_span().ptr()
        if self._set1_host(ssl, name) != 1:
            return False
        var sni = self._ssl_ctrl(
            ssl, SSL_CTRL_SET_TLSEXT_HOSTNAME, 0, Int(name)
        )
        return sni == 1

    def handshake(mut self, ssl: Int) -> Int32:
        """Run the handshake as far as the socket allows.

        Args:
            ssl: The object.

        Returns:
            1 when done, else a value for `get_error`.
        """
        if self._fail(TlsCall.HANDSHAKE):
            self._faulted = True
            return -1
        return self._handshake(ssl)

    def read(mut self, ssl: Int, data: Pointer[UInt8, _], size: Int) -> Int32:
        """Read decrypted bytes.

        Args:
            ssl: The object.
            data: The buffer.
            size: The size of the buffer.

        Returns:
            The count of bytes, else a value for `get_error`.
        """
        if self._fail(TlsCall.READ):
            self._faulted = True
            return -1
        return self._read(ssl, data, Int32(min(size, 0x7FFFFFFF)))

    def write(mut self, ssl: Int, data: Pointer[UInt8, _], size: Int) -> Int32:
        """Encrypt and send bytes.

        Args:
            ssl: The object.
            data: The bytes.
            size: The count of bytes.

        Returns:
            The count of bytes taken, else a value for `get_error`.
        """
        if self._fail(TlsCall.WRITE):
            self._faulted = True
            return -1
        return self._write(ssl, data, Int32(min(size, 0x7FFFFFFF)))

    def get_error(mut self, ssl: Int, result: Int32) -> Int32:
        """Classify the result of a handshake, a read or a write.

        The result of a call that a fault made fail is `SSL_ERROR_SSL`.

        Args:
            ssl: The object.
            result: The result of the call.

        Returns:
            An `SSL_ERROR_*` value.
        """
        if self._faulted:
            self._faulted = False
            return SSL_ERROR_SSL
        return self._get_error(ssl, result)

    def shutdown(mut self, ssl: Int) -> Int32:
        """Send `close_notify`.

        Args:
            ssl: The object.

        Returns:
            0 or 1 when it went out, else a negative value.
        """
        if self._fail(TlsCall.SHUTDOWN):
            return -1
        return self._shutdown(ssl)

    def alpn_selected(mut self, ssl: Int) -> String:
        """Return the protocol that ALPN chose.

        Args:
            ssl: The object, after the handshake.

        Returns:
            The protocol, such as `h2`, or an empty string.
        """
        var data = stack_allocation[1, Int]()
        var size = stack_allocation[1, UInt32]()
        data[unsafe_offset=0] = 0
        size[unsafe_offset=0] = 0
        self._alpn_selected(ssl, data, size)
        if data[unsafe_offset=0] == 0:
            return String()
        var p = Pointer[UInt8, MutUntrackedOrigin](
            unsafe_from_address=data[unsafe_offset=0]
        )
        var length = Int(size[unsafe_offset=0])
        return String(unsafe_from_utf8=Span(unsafe_ptr=p, length=length))

    def verify_result(mut self, ssl: Int) -> Int:
        """Return the X.509 verification result of the peer.

        Args:
            ssl: The object.

        Returns:
            `X509_V_OK`, or an `X509_V_ERR_*` code.
        """
        return self._verify_result(ssl)

    def pending(mut self, ssl: Int) -> Int:
        """Return the count of decrypted bytes that wait in OpenSSL.

        Args:
            ssl: The object.

        Returns:
            The count.
        """
        return Int(self._pending(ssl))

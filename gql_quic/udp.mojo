# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Batched UDP I/O on Linux: `recvmmsg`, `sendmmsg` and GSO.

`UdpIo` reads and writes the datagrams of one non-blocking UDP socket of
IPv4. `recv` takes up to `BATCH` datagrams with one `recvmmsg` call.
`send` takes datagrams that lie one after another in one buffer: the
datagrams to one peer of one size go out as one GSO message with the
`UDP_SEGMENT` option, so the kernel splits them (generic segmentation
offload), and the messages go out with one `sendmmsg` call. A kernel
without GSO fails the first such send; `UdpIo` then turns GSO off and
sends the datagrams one by one.

A connected socket sends without addresses; that is the client of
`gql_http3`. An unconnected socket gives the address of each datagram that
arrives, and takes one for each that goes out; that is the server.

This module ports the role of quinn-udp 0.5.16 (quinn-udp/src/unix.rs,
MIT OR Apache-2.0, used under MIT): batched receive and GSO send.

Differences from upstream: IPv4 only; no ECN, no GRO, no `IP_PKTINFO`.
The layouts are those of glibc and musl on x86-64 and AArch64.
"""

from std.ffi import external_call
from std.memory import stack_allocation
from std.sys._libc_errno import get_errno

comptime BATCH = 32
"""The most datagrams of one `recvmmsg` or `sendmmsg` call."""
comptime SLOT = 2048
"""The receive buffer of each datagram; larger datagrams are cut."""
comptime MAX_SEGMENTS = 64
"""The most datagrams of one GSO message."""
comptime _MSGHDR = 64
comptime _IOVEC = 16
comptime _SOCKADDR = 16
comptime _CMSG = 24
comptime _SOL_UDP: Int32 = 17
comptime _UDP_SEGMENT: Int32 = 103
comptime _MSG_DONTWAIT: Int32 = 0x40
comptime EAGAIN = 11
"""The error number of a socket with nothing to read or no room."""
comptime ECONNREFUSED = 111
"""The error number after an ICMP port unreachable on a connected socket."""
comptime _EIO = 5
comptime _EINVAL = 22


@fieldwise_init
struct Peer(Equatable, ImplicitlyCopyable, Writable):
    """An IPv4 address and a port, in host byte order."""

    var address: UInt32
    """The address, such as `0x7F000001` for 127.0.0.1."""
    var port: UInt16
    """The port."""

    def write_to(self, mut writer: Some[Writer]):
        """Write the address as `a.b.c.d:port`.

        Args:
            writer: The destination.
        """
        writer.write(
            self.address >> 24,
            ".",
            (self.address >> 16) & 0xFF,
            ".",
            (self.address >> 8) & 0xFF,
            ".",
            self.address & 0xFF,
            ":",
            self.port,
        )


@always_inline
def _store[T: TrivialRegisterPassable](base: Int, offset: Int, value: T):
    """Write a value at an address."""
    Pointer[T, MutUntrackedOrigin](unsafe_from_address=base + offset)[] = value


@always_inline
def _load[T: TrivialRegisterPassable](base: Int, offset: Int) -> T:
    """Read a value at an address."""
    return Pointer[T, MutUntrackedOrigin](unsafe_from_address=base + offset)[]


@always_inline
def _swap16(value: UInt16) -> UInt16:
    """Swap the bytes of a 16-bit value."""
    return (value >> 8) | (value << 8)


@always_inline
def _swap32(value: UInt32) -> UInt32:
    """Swap the bytes of a 32-bit value."""
    return (
        (value >> 24)
        | ((value >> 8) & 0xFF00)
        | ((value << 8) & 0xFF0000)
        | (value << 24)
    )


struct UdpIo(Movable):
    """Batched I/O on one non-blocking UDP socket."""

    var fd: Int
    """The socket; `UdpIo` does not close it."""
    var connected: Bool
    """Whether the socket is connected, so datagrams carry no address."""
    var gso: Bool
    """Whether to send with GSO; off after the kernel refuses it."""
    var data: List[UInt8]
    """The receive buffers, `SLOT` bytes for each datagram."""
    var sizes: List[Int]
    """The sizes of the datagrams of the last `recv`."""
    var peers: List[Peer]
    """The senders of the datagrams of the last `recv`."""
    var _recv_hdrs: List[UInt8]
    var _recv_iovs: List[UInt8]
    var _recv_addrs: List[UInt8]
    var _send_hdrs: List[UInt8]
    var _send_iovs: List[UInt8]
    var _send_addrs: List[UInt8]
    var _send_cmsgs: List[UInt8]

    def __init__(out self, fd: Int, connected: Bool, gso: Bool = True):
        """Prepare the buffers of a socket.

        Args:
            fd: A non-blocking IPv4 UDP socket.
            connected: Whether it is connected to its peer.
            gso: Whether to try GSO.
        """
        self.fd = fd
        self.connected = connected
        self.gso = gso
        self.data = List[UInt8](length=BATCH * SLOT, fill=0)
        self.sizes = List[Int](length=BATCH, fill=0)
        self.peers = List[Peer](length=BATCH, fill=Peer(0, 0))
        self._recv_hdrs = List[UInt8](length=BATCH * _MSGHDR, fill=0)
        self._recv_iovs = List[UInt8](length=BATCH * _IOVEC, fill=0)
        self._recv_addrs = List[UInt8](length=BATCH * _SOCKADDR, fill=0)
        self._send_hdrs = List[UInt8](length=BATCH * _MSGHDR, fill=0)
        self._send_iovs = List[UInt8](length=BATCH * _IOVEC, fill=0)
        self._send_addrs = List[UInt8](length=BATCH * _SOCKADDR, fill=0)
        self._send_cmsgs = List[UInt8](length=BATCH * _CMSG, fill=0)
        var hdrs = Int(self._recv_hdrs.unsafe_ptr())
        var iovs = Int(self._recv_iovs.unsafe_ptr())
        var base = Int(self.data.unsafe_ptr())
        var index = 0
        while index < BATCH:
            var hdr = hdrs + index * _MSGHDR
            var iov = iovs + index * _IOVEC
            _store[Int](iov, 0, base + index * SLOT)
            _store[Int](iov, 8, SLOT)
            _store[Int](hdr, 16, iov)
            _store[Int](hdr, 24, 1)
            index += 1

    def datagram(self, index: Int) -> Span[UInt8, origin_of(self.data)]:
        """Return a datagram of the last `recv`.

        Args:
            index: Its index, below the count that `recv` returned.

        Returns:
            Its bytes, in `data`.
        """
        return Span(self.data)[index * SLOT : index * SLOT + self.sizes[index]]

    def recv(mut self) -> Int:
        """Take the datagrams that wait, without waiting.

        Returns:
            The count of datagrams, 0 when none waits, or the negated error
            number, such as `-ECONNREFUSED`.
        """
        var hdrs = Int(self._recv_hdrs.unsafe_ptr())
        var addrs = Int(self._recv_addrs.unsafe_ptr())
        var index = 0
        while index < BATCH:
            var hdr = hdrs + index * _MSGHDR
            if self.connected:
                _store[Int](hdr, 0, 0)
                _store[UInt32](hdr, 8, 0)
            else:
                _store[Int](hdr, 0, addrs + index * _SOCKADDR)
                _store[UInt32](hdr, 8, _SOCKADDR)
            _store[Int](hdr, 32, 0)
            _store[Int](hdr, 40, 0)
            _store[Int32](hdr, 48, 0)
            index += 1
        var rc = Int(
            external_call["recvmmsg", Int32](
                Int32(self.fd), hdrs, UInt32(BATCH), _MSG_DONTWAIT, 0
            )
        )
        if rc < 0:
            var errno = Int(get_errno().value)
            return 0 if errno == EAGAIN else -errno
        # `recvmmsg` of a non-blocking socket fails with EAGAIN rather than
        # return 0, so the loop runs at least once.
        index = 0
        while index < rc:
            self.sizes[index] = min(
                Int(_load[UInt32](hdrs + index * _MSGHDR, 56)), SLOT
            )
            if not self.connected:
                var at = addrs + index * _SOCKADDR
                self.peers[index] = Peer(
                    _swap32(_load[UInt32](at, 4)),
                    _swap16(_load[UInt16](at, 2)),
                )
            index += 1
        return rc

    def _message(
        mut self,
        count: Int,
        start: Int,
        size: Int,
        segment: Int,
        peer: Peer,
    ):
        """Fill message `count` with `size` bytes at `start`, and GSO when
        `segment` is below the size."""
        var hdr = Int(self._send_hdrs.unsafe_ptr()) + count * _MSGHDR
        var iov = Int(self._send_iovs.unsafe_ptr()) + count * _IOVEC
        _store[Int](iov, 0, start)
        _store[Int](iov, 8, size)
        if self.connected:
            _store[Int](hdr, 0, 0)
            _store[UInt32](hdr, 8, 0)
        else:
            var addr = Int(self._send_addrs.unsafe_ptr()) + count * _SOCKADDR
            _store[UInt16](addr, 0, 2)
            _store[UInt16](addr, 2, _swap16(peer.port))
            _store[UInt32](addr, 4, _swap32(peer.address))
            _store[Int](addr, 8, 0)
            _store[Int](hdr, 0, addr)
            _store[UInt32](hdr, 8, _SOCKADDR)
        _store[Int](hdr, 16, iov)
        _store[Int](hdr, 24, 1)
        if segment < size:
            var cmsg = Int(self._send_cmsgs.unsafe_ptr()) + count * _CMSG
            _store[Int](cmsg, 0, 18)
            _store[Int32](cmsg, 8, _SOL_UDP)
            _store[Int32](cmsg, 12, _UDP_SEGMENT)
            _store[UInt16](cmsg, 16, UInt16(segment))
            _store[Int](hdr, 32, cmsg)
            _store[Int](hdr, 40, _CMSG)
        else:
            _store[Int](hdr, 32, 0)
            _store[Int](hdr, 40, 0)
        _store[Int32](hdr, 48, 0)

    def send(
        mut self,
        data: List[UInt8],
        sizes: List[Int],
        peers: List[Peer],
    ) -> Int:
        """Send datagrams that lie one after another in a buffer.

        A datagram that the socket has no room for is dropped, as the
        network may drop it; QUIC sends its frames again.

        Args:
            data: The datagrams, one after another.
            sizes: The size of each datagram.
            peers: The peer of each datagram; unused on a connected socket.

        Returns:
            The count of datagrams sent, or the negated error number of a
            failure other than `EAGAIN`.
        """
        var base = Int(data.unsafe_ptr())
        var index = 0
        var offset = 0
        var sent = 0
        while index < len(sizes):
            # Fill up to BATCH messages, each one datagram or a GSO run.
            var count = 0
            var first = index
            var first_offset = offset
            var runs = List[Int]()
            while index < len(sizes) and count < BATCH:
                var segment = sizes[index]
                var run = 1
                var size = segment
                if self.gso:
                    while (
                        index + run < len(sizes)
                        and run < MAX_SEGMENTS
                        and sizes[index + run] <= segment
                        and size + sizes[index + run] <= 65000
                        and (
                            self.connected or peers[index + run] == peers[index]
                        )
                    ):
                        size += sizes[index + run]
                        run += 1
                        if sizes[index + run - 1] < segment:
                            break
                var peer = Peer(0, 0) if self.connected else peers[index]
                self._message(count, base + offset, size, segment, peer)
                runs.append(run)
                offset += size
                index += run
                count += 1
            var rc = Int(
                external_call["sendmmsg", Int32](
                    Int32(self.fd),
                    Int(self._send_hdrs.unsafe_ptr()),
                    UInt32(count),
                    _MSG_DONTWAIT,
                )
            )
            if rc < 0:
                var errno = Int(get_errno().value)
                if self.gso and (errno == _EIO or errno == _EINVAL):
                    # The kernel has no GSO: send this batch again without.
                    self.gso = False
                    index = first
                    offset = first_offset
                    continue
                if errno == EAGAIN:
                    return sent
                return -errno
            # A batch has at least one message, and `sendmmsg` fails rather
            # than send none, so the loop runs at least once.
            var at = 0
            while at < rc:
                sent += runs[at]
                at += 1
            if rc < count:
                return sent
        _ = data
        return sent

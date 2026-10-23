# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""POSIX sockets, epoll, processes and signals, through the C library.

This is the only module of `gql_http` that calls the operating system, and
the only one that imports `std.sys._libc_errno`. A port to macOS replaces
this module: `kqueue` for epoll, `EVFILT_SIGNAL` for `signalfd`, and the
macOS layouts of `sockaddr_in` and `addrinfo`.

Every call goes through `Sys`. A call returns its result, or the negated
error number: `-EAGAIN`, not -1. `Sys.faults` can make one kind of call
fail, so that tests can reach the error paths of the server and the client.

Linux only: `epoll`, `accept4`, `signalfd`, `prctl(PR_SET_PDEATHSIG)`, the
`SOCK_NONBLOCK` and `SOCK_CLOEXEC` flags, and the constants below. The
layouts are those of glibc and musl on x86-64 and AArch64.

This module ports no code.

Differences from upstream: none; there is no upstream.
"""

from std.ffi import external_call
from std.memory import stack_allocation
from std.sys import CompilationTarget
from std.sys._libc_errno import get_errno

from gql_http.error import ErrorKind, HttpError

comptime EINTR = 4
"""Interrupted system call."""
comptime EBADF = 9
"""Bad file descriptor."""
comptime EAGAIN = 11
"""Resource temporarily unavailable: the call would block."""
comptime EMFILE = 24
"""Too many open files."""
comptime EPIPE = 32
"""Broken pipe: the peer closed the connection."""
comptime EADDRINUSE = 98
"""Address already in use."""
comptime ECONNRESET = 104
"""Connection reset by peer."""
comptime ETIMEDOUT = 110
"""Connection timed out."""
comptime ECONNREFUSED = 111
"""Connection refused."""
comptime EINPROGRESS = 115
"""A non-blocking connect has started."""

comptime EPOLLIN: UInt32 = 0x001
"""For epoll: the descriptor can be read."""
comptime EPOLLOUT: UInt32 = 0x004
"""For epoll: the descriptor can be written."""
comptime EPOLLERR: UInt32 = 0x008
"""For epoll: an error is pending."""
comptime EPOLLHUP: UInt32 = 0x010
"""For epoll: the peer hung up."""
comptime EPOLL_CTL_ADD = 1
"""For `epoll_ctl`: add a descriptor."""
comptime EPOLL_CTL_DEL = 2
"""For `epoll_ctl`: remove a descriptor."""
comptime EPOLL_CTL_MOD = 3
"""For `epoll_ctl`: change the events of a descriptor."""
comptime EPOLL_EVENT_SIZE = 12 if CompilationTarget.is_x86() else 16
"""The size of `struct epoll_event`: packed on x86-64 only."""
comptime _EPOLL_DATA_OFFSET = 4 if CompilationTarget.is_x86() else 8
"""The offset of `epoll_event.data`."""

comptime POLLIN = 0x001
"""For poll: the descriptor can be read."""
comptime POLLOUT = 0x004
"""For poll: the descriptor can be written."""

comptime SIGINT = 2
"""Interrupt, from the terminal."""
comptime SIGKILL = 9
"""Kill; it cannot be caught."""
comptime SIGPIPE = 13
"""Write to a closed pipe or socket."""
comptime SIGTERM = 15
"""Termination request."""

comptime SHUT_WR = 1
"""For `shutdown`: no more sends."""

comptime _AF_INET: Int32 = 2
comptime _SOCK_STREAM: Int32 = 1
comptime _SOCK_NONBLOCK: Int32 = 0o4000
comptime _SOCK_CLOEXEC: Int32 = 0o2000000
comptime _SOL_SOCKET: Int32 = 1
comptime _SO_REUSEADDR: Int32 = 2
comptime _SO_ERROR: Int32 = 4
comptime _SO_REUSEPORT: Int32 = 15
comptime _IPPROTO_TCP: Int32 = 6
comptime _TCP_NODELAY: Int32 = 1
comptime _MSG_NOSIGNAL: Int32 = 0x4000
comptime _MSG_PEEK: Int32 = 0x2
comptime _MSG_DONTWAIT: Int32 = 0x40
comptime _SIG_BLOCK: Int32 = 0
comptime _WNOHANG: Int32 = 1
comptime _PR_SET_PDEATHSIG: Int32 = 1
comptime _SIGSET_BYTES = 128
comptime _AI_ADDR_OFFSET = 24


@fieldwise_init
struct SysCall(Equatable, ImplicitlyCopyable, Writable):
    """A kind of system call that `Faults` can make fail."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime NONE = SysCall(0)
    """No call: faults are off."""
    comptime SOCKET = SysCall(1)
    """`socket`."""
    comptime SETSOCKOPT = SysCall(2)
    """`setsockopt`."""
    comptime BIND = SysCall(3)
    """`bind`."""
    comptime LISTEN = SysCall(4)
    """`listen`."""
    comptime GETSOCKNAME = SysCall(5)
    """`getsockname`."""
    comptime ACCEPT = SysCall(6)
    """`accept4`."""
    comptime CONNECT = SysCall(7)
    """`connect`."""
    comptime RECV = SysCall(8)
    """`recv`."""
    comptime SEND = SysCall(9)
    """`send`."""
    comptime SHUTDOWN = SysCall(10)
    """`shutdown`."""
    comptime EPOLL_CREATE = SysCall(11)
    """`epoll_create1`."""
    comptime EPOLL_CTL = SysCall(12)
    """`epoll_ctl`."""
    comptime EPOLL_WAIT = SysCall(13)
    """`epoll_wait`."""
    comptime POLL = SysCall(14)
    """`poll`."""
    comptime FORK = SysCall(15)
    """`fork`."""
    comptime SIGNALFD = SysCall(16)
    """`sigprocmask` and `signalfd`."""
    comptime GETSOCKOPT = SysCall(17)
    """`getsockopt`."""
    comptime RESOLVE = SysCall(18)
    """`getaddrinfo`; the error number is the `EAI_*` code."""
    comptime PIPE = SysCall(19)
    """`pipe2`."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 19

    def write_to(self, mut writer: Some[Writer]):
        """Write the index of the kind.

        Args:
            writer: The destination.
        """
        writer.write("SysCall(", self.value, ")")


@fieldwise_init
struct Faults(Copyable, Movable):
    """A plan that makes one kind of system call fail, for tests.

    The first `skip` matching calls run. The next `count` matching calls
    fail with `errno` without reaching the system. A `count` of -1 fails
    every later call.
    """

    var call: SysCall
    """The kind of call to fail, or `SysCall.NONE`."""
    var errno: Int
    """The error number that a failed call returns, negated."""
    var skip: Int
    """How many matching calls run before the first failure."""
    var count: Int
    """How many matching calls fail; -1 for no limit."""

    def __init__(out self):
        """Make a plan that fails nothing."""
        self.call = SysCall.NONE
        self.errno = 0
        self.skip = 0
        self.count = 0

    def take(mut self, call: SysCall) -> Int:
        """Decide whether this call fails.

        Args:
            call: The kind of the call that is about to run.

        Returns:
            The error number to fail with, or 0 to run the call.
        """
        if self.call != call or self.count == 0:
            return 0
        if self.skip > 0:
            self.skip -= 1
            return 0
        if self.count > 0:
            self.count -= 1
        return self.errno


@always_inline
def _result(rc: Int) -> Int:
    """Return a call's result, or its negated error number when it is -1."""
    return rc if rc >= 0 else -Int(get_errno().value)


@fieldwise_init
struct IPv4Address(Equatable, ImplicitlyCopyable, Writable):
    """An IPv4 address, in host byte order."""

    var value: UInt32
    """The address; `a.b.c.d` is `a << 24 | b << 16 | c << 8 | d`."""

    comptime ANY = IPv4Address(0)
    """`0.0.0.0`: every local address."""
    comptime LOOPBACK = IPv4Address(0x7F000001)
    """`127.0.0.1`."""

    @staticmethod
    def parse(text: StringSlice) -> Optional[IPv4Address]:
        """Read a dotted-decimal address, such as `127.0.0.1`.

        Each of the four parts is 0 to 255, without a leading zero. This
        refuses the octal and short forms that `inet_aton` reads.

        Args:
            text: The text.

        Returns:
            The address, or None when the text is not in that form.
        """
        var bytes = text.as_bytes()
        var value: UInt32 = 0
        var parts = 0
        var index = 0
        var n = len(bytes)
        while index < n:
            var start = index
            var part = 0
            while index < n and bytes[index] >= 48 and bytes[index] <= 57:
                part = part * 10 + Int(bytes[index] - 48)
                index += 1
            var digits = index - start
            if digits == 0 or digits > 3 or part > 255:
                return None
            if digits > 1 and bytes[start] == 48:
                return None
            value = (value << 8) | UInt32(part)
            parts += 1
            if index < n:
                if bytes[index] != 46 or parts == 4:
                    return None
                index += 1
                if index == n:
                    return None
        if parts != 4:
            return None
        return IPv4Address(value)

    def write_to(self, mut writer: Some[Writer]):
        """Write the address in dotted-decimal form.

        Args:
            writer: The destination.
        """
        writer.write(
            (self.value >> 24) & 255,
            ".",
            (self.value >> 16) & 255,
            ".",
            (self.value >> 8) & 255,
            ".",
            self.value & 255,
        )


def _fill_sockaddr(
    p: Pointer[UInt8, MutUntrackedOrigin], address: IPv4Address, port: Int
):
    """Write a Linux `sockaddr_in` of 16 bytes at `p`."""
    var index = 0
    while index < 16:
        p[unsafe_offset=index] = 0
        index += 1
    p[unsafe_offset=0] = UInt8(_AF_INET)
    p[unsafe_offset=2] = UInt8((port >> 8) & 255)
    p[unsafe_offset=3] = UInt8(port & 255)
    p[unsafe_offset=4] = UInt8((address.value >> 24) & 255)
    p[unsafe_offset=5] = UInt8((address.value >> 16) & 255)
    p[unsafe_offset=6] = UInt8((address.value >> 8) & 255)
    p[unsafe_offset=7] = UInt8(address.value & 255)


@fieldwise_init
struct Sys(Copyable, Movable):
    """The system calls of `gql_http`, with an optional fault plan."""

    var faults: Faults
    """The plan of calls that fail; empty by default."""

    def __init__(out self):
        """Make a system interface that fails nothing."""
        self.faults = Faults()

    @always_inline
    def _fault(mut self, call: SysCall) -> Int:
        """Return the negated error number of a planned failure, or 0."""
        if self.faults.call.value == 0:
            return 0
        return -self.faults.take(call)

    def socket(mut self) -> Int:
        """Open a non-blocking IPv4 TCP socket, closed on exec.

        Returns:
            The descriptor, or the negated error number.
        """
        var fault = self._fault(SysCall.SOCKET)
        if fault != 0:
            return fault
        return _result(
            Int(
                external_call["socket", Int32](
                    _AF_INET, _SOCK_STREAM | _SOCK_NONBLOCK | _SOCK_CLOEXEC, 0
                )
            )
        )

    def _setsockopt(
        mut self, fd: Int, level: Int32, name: Int32, value: Int32
    ) -> Int:
        """Set an integer socket option."""
        var fault = self._fault(SysCall.SETSOCKOPT)
        if fault != 0:
            return fault
        var slot = stack_allocation[1, Int32]()
        slot[unsafe_offset=0] = value
        return _result(
            Int(
                external_call["setsockopt", Int32](
                    Int32(fd), level, name, slot.unsafe_bitcast[NoneType](), 4
                )
            )
        )

    def set_reuse_address(mut self, fd: Int) -> Int:
        """Set `SO_REUSEADDR`, so a restart can bind a port in TIME_WAIT.

        Args:
            fd: The socket.

        Returns:
            0, or the negated error number.
        """
        return self._setsockopt(fd, _SOL_SOCKET, _SO_REUSEADDR, 1)

    def set_reuse_port(mut self, fd: Int) -> Int:
        """Set `SO_REUSEPORT`, so several sockets can listen on one port.

        Args:
            fd: The socket.

        Returns:
            0, or the negated error number.
        """
        return self._setsockopt(fd, _SOL_SOCKET, _SO_REUSEPORT, 1)

    def set_no_delay(mut self, fd: Int) -> Int:
        """Set `TCP_NODELAY`, so small responses are not delayed.

        Args:
            fd: The socket.

        Returns:
            0, or the negated error number.
        """
        return self._setsockopt(fd, _IPPROTO_TCP, _TCP_NODELAY, 1)

    def bind(mut self, fd: Int, address: IPv4Address, port: Int) -> Int:
        """Bind a socket to an address and a port.

        Args:
            fd: The socket.
            address: The local address.
            port: The local port; 0 lets the system choose.

        Returns:
            0, or the negated error number.
        """
        var fault = self._fault(SysCall.BIND)
        if fault != 0:
            return fault
        var addr = stack_allocation[16, UInt8]()
        _fill_sockaddr(addr, address, port)
        return _result(
            Int(
                external_call["bind", Int32](
                    Int32(fd), addr.unsafe_bitcast[NoneType](), 16
                )
            )
        )

    def listen(mut self, fd: Int, backlog: Int) -> Int:
        """Make a bound socket accept connections.

        Args:
            fd: The socket.
            backlog: The length of the queue of pending connections.

        Returns:
            0, or the negated error number.
        """
        var fault = self._fault(SysCall.LISTEN)
        if fault != 0:
            return fault
        return _result(
            Int(external_call["listen", Int32](Int32(fd), Int32(backlog)))
        )

    def local_port(mut self, fd: Int) -> Int:
        """Return the local port of a bound socket.

        Args:
            fd: The socket.

        Returns:
            The port, or the negated error number.
        """
        var fault = self._fault(SysCall.GETSOCKNAME)
        if fault != 0:
            return fault
        var addr = stack_allocation[16, UInt8]()
        var size = stack_allocation[1, UInt32]()
        size[unsafe_offset=0] = 16
        var rc = _result(
            Int(
                external_call["getsockname", Int32](
                    Int32(fd),
                    addr.unsafe_bitcast[NoneType](),
                    size.unsafe_bitcast[NoneType](),
                )
            )
        )
        if rc < 0:
            return rc
        return Int(addr[unsafe_offset=2]) * 256 + Int(addr[unsafe_offset=3])

    def accept(mut self, fd: Int) -> Int:
        """Accept a connection as a non-blocking socket, closed on exec.

        Args:
            fd: The listening socket.

        Returns:
            The new descriptor, or the negated error number.
        """
        var fault = self._fault(SysCall.ACCEPT)
        if fault != 0:
            return fault
        return _result(
            Int(
                external_call["accept4", Int32](
                    Int32(fd), Int(0), Int(0), _SOCK_NONBLOCK | _SOCK_CLOEXEC
                )
            )
        )

    def connect(mut self, fd: Int, address: IPv4Address, port: Int) -> Int:
        """Start to connect a non-blocking socket.

        Args:
            fd: The socket.
            address: The address of the peer.
            port: The port of the peer.

        Returns:
            0, `-EINPROGRESS` while the connection is made, or another
            negated error number.
        """
        var fault = self._fault(SysCall.CONNECT)
        if fault != 0:
            return fault
        var addr = stack_allocation[16, UInt8]()
        _fill_sockaddr(addr, address, port)
        return _result(
            Int(
                external_call["connect", Int32](
                    Int32(fd), addr.unsafe_bitcast[NoneType](), 16
                )
            )
        )

    def socket_error(mut self, fd: Int) -> Int:
        """Return and clear the pending error of a socket: `SO_ERROR`.

        Args:
            fd: The socket.

        Returns:
            The pending error number, 0 for none, or the negated error
            number of `getsockopt`.
        """
        var fault = self._fault(SysCall.GETSOCKOPT)
        if fault != 0:
            return fault
        var value = stack_allocation[1, Int32]()
        var size = stack_allocation[1, UInt32]()
        value[unsafe_offset=0] = 0
        size[unsafe_offset=0] = 4
        var rc = _result(
            Int(
                external_call["getsockopt", Int32](
                    Int32(fd),
                    _SOL_SOCKET,
                    _SO_ERROR,
                    value.unsafe_bitcast[NoneType](),
                    size.unsafe_bitcast[NoneType](),
                )
            )
        )
        if rc < 0:
            return rc
        return Int(value[unsafe_offset=0])

    @always_inline
    def recv(mut self, fd: Int, data: Pointer[UInt8, _], size: Int) -> Int:
        """Read up to `size` bytes from a socket.

        Args:
            fd: The socket.
            data: Where the bytes go.
            size: The room at `data`.

        Returns:
            The count read, 0 at the end of the stream, or the negated
            error number.
        """
        var fault = self._fault(SysCall.RECV)
        if fault != 0:
            return fault
        return _result(
            external_call["recv", Int](
                Int32(fd), data.unsafe_bitcast[NoneType](), size, Int32(0)
            )
        )

    def peek(mut self, fd: Int) -> Int:
        """Look, without waiting, for one byte or the end of the stream.

        Args:
            fd: The socket.

        Returns:
            1 when a byte waits, 0 at the end of the stream, `-EAGAIN`
            when the connection is open and quiet, or another negated
            error number.
        """
        var fault = self._fault(SysCall.RECV)
        if fault != 0:
            return fault
        var byte = stack_allocation[1, UInt8]()
        return _result(
            external_call["recv", Int](
                Int32(fd),
                byte.unsafe_bitcast[NoneType](),
                1,
                _MSG_PEEK | _MSG_DONTWAIT,
            )
        )

    @always_inline
    def send(mut self, fd: Int, data: Pointer[UInt8, _], size: Int) -> Int:
        """Write up to `size` bytes to a socket, without `SIGPIPE`.

        Args:
            fd: The socket.
            data: The bytes.
            size: How many bytes to write.

        Returns:
            The count written, or the negated error number.
        """
        var fault = self._fault(SysCall.SEND)
        if fault != 0:
            return fault
        return _result(
            external_call["send", Int](
                Int32(fd), data.unsafe_bitcast[NoneType](), size, _MSG_NOSIGNAL
            )
        )

    def shutdown_write(mut self, fd: Int) -> Int:
        """Send the end of the stream, and keep the read side open.

        Args:
            fd: The socket.

        Returns:
            0, or the negated error number.
        """
        var fault = self._fault(SysCall.SHUTDOWN)
        if fault != 0:
            return fault
        return _result(
            Int(external_call["shutdown", Int32](Int32(fd), Int32(SHUT_WR)))
        )

    def close(mut self, fd: Int):
        """Close a descriptor. A failed close cannot be retried on Linux.

        Args:
            fd: The descriptor.
        """
        _ = external_call["close", Int32](Int32(fd))

    def epoll_create(mut self) -> Int:
        """Open an epoll instance, closed on exec.

        Returns:
            The descriptor, or the negated error number.
        """
        var fault = self._fault(SysCall.EPOLL_CREATE)
        if fault != 0:
            return fault
        return _result(
            Int(external_call["epoll_create1", Int32](_SOCK_CLOEXEC))
        )

    def epoll_ctl(
        mut self, epoll: Int, op: Int, fd: Int, events: UInt32
    ) -> Int:
        """Add, change or remove a descriptor of an epoll instance.

        The event data is the descriptor itself.

        Args:
            epoll: The epoll instance.
            op: `EPOLL_CTL_ADD`, `EPOLL_CTL_MOD` or `EPOLL_CTL_DEL`.
            fd: The descriptor.
            events: The `EPOLL*` events to wait for.

        Returns:
            0, or the negated error number.
        """
        var fault = self._fault(SysCall.EPOLL_CTL)
        if fault != 0:
            return fault
        var event = stack_allocation[16, UInt8]()
        event.unsafe_bitcast[UInt32]().unsafe_store(events)
        event.unsafe_offset(_EPOLL_DATA_OFFSET).unsafe_bitcast[
            UInt64
        ]().unsafe_store(UInt64(fd))
        return _result(
            Int(
                external_call["epoll_ctl", Int32](
                    Int32(epoll),
                    Int32(op),
                    Int32(fd),
                    event.unsafe_bitcast[NoneType](),
                )
            )
        )

    def epoll_wait(
        mut self,
        epoll: Int,
        events: Pointer[UInt8, _],
        capacity: Int,
        timeout_ms: Int,
    ) -> Int:
        """Wait for events of an epoll instance.

        Args:
            epoll: The epoll instance.
            events: Room for `capacity` events of `EPOLL_EVENT_SIZE` bytes.
            capacity: The most events to return.
            timeout_ms: The longest wait in milliseconds; -1 waits forever.

        Returns:
            The count of events, or the negated error number.
        """
        var fault = self._fault(SysCall.EPOLL_WAIT)
        if fault != 0:
            return fault
        return _result(
            Int(
                external_call["epoll_wait", Int32](
                    Int32(epoll),
                    events.unsafe_bitcast[NoneType](),
                    Int32(capacity),
                    Int32(timeout_ms),
                )
            )
        )

    def poll(mut self, fd: Int, events: Int, timeout_ms: Int) -> Int:
        """Wait until one descriptor is ready.

        Args:
            fd: The descriptor.
            events: `POLLIN`, `POLLOUT` or both.
            timeout_ms: The longest wait in milliseconds.

        Returns:
            The returned events, 0 after the timeout, or the negated error
            number.
        """
        var fault = self._fault(SysCall.POLL)
        if fault != 0:
            return fault
        var entry = stack_allocation[2, Int32]()
        entry[unsafe_offset=0] = Int32(fd)
        entry[unsafe_offset=1] = Int32(events)
        var rc = _result(
            Int(
                external_call["poll", Int32](
                    entry.unsafe_bitcast[NoneType](), Int(1), Int32(timeout_ms)
                )
            )
        )
        if rc <= 0:
            return rc
        return Int((entry[unsafe_offset=1] >> 16) & 0xFFFF)

    def fork(mut self) -> Int:
        """Start a child process.

        Returns:
            0 in the child, the child's process id in the parent, or the
            negated error number.
        """
        var fault = self._fault(SysCall.FORK)
        if fault != 0:
            return fault
        return _result(Int(external_call["fork", Int32]()))

    def kill(mut self, pid: Int, signal: Int) -> Int:
        """Send a signal to a process.

        Args:
            pid: The process.
            signal: The signal, such as `SIGTERM`.

        Returns:
            0, or the negated error number.
        """
        return _result(
            Int(external_call["kill", Int32](Int32(pid), Int32(signal)))
        )

    def wait(mut self, pid: Int, block: Bool) -> Tuple[Int, Int]:
        """Wait for a child process to end.

        Args:
            pid: The child.
            block: Whether to wait; False returns at once.

        Returns:
            The child's id and its exit code, or (0, 0) when it still runs
            and `block` is False, or (negated error number, 0). A child
            that a signal ended has the exit code 128 plus the signal.
        """
        var status = stack_allocation[1, Int32]()
        status[unsafe_offset=0] = 0
        var rc = _result(
            Int(
                external_call["waitpid", Int32](
                    Int32(pid),
                    status.unsafe_bitcast[NoneType](),
                    Int32(0) if block else _WNOHANG,
                )
            )
        )
        var raw = Int(status[unsafe_offset=0])
        var signal = raw & 0x7F
        var code = 128 + signal if signal != 0 else (raw >> 8) & 0xFF
        return (rc, code)

    def exit_now(mut self, code: Int):
        """End this process at once, without exit handlers: `_exit`.

        Args:
            code: The exit code.
        """
        external_call["_exit", NoneType](Int32(code))

    def die_with_parent(mut self) -> Int:
        """Ask for `SIGTERM` when the parent process ends (Linux `prctl`).

        Returns:
            0, or the negated error number.
        """
        return _result(
            Int(
                external_call["prctl", Int32](
                    _PR_SET_PDEATHSIG, Int(SIGTERM), Int(0), Int(0), Int(0)
                )
            )
        )

    def parent_pid(mut self) -> Int:
        """Return the id of the parent process.

        Returns:
            The id; 1 or a subreaper once the parent has ended.
        """
        return Int(external_call["getppid", Int32]())

    def ignore_broken_pipe(mut self):
        """Ignore `SIGPIPE`, so a write to a closed socket returns `EPIPE`."""
        _ = external_call["signal", Int](Int32(SIGPIPE), Int(1))

    def signal_fd(mut self) -> Int:
        """Block `SIGTERM` and `SIGINT`, and read them from a descriptor.

        This blocks the signals in the calling thread only. Use it in a
        worker process, which has one thread after `fork`.

        Returns:
            A non-blocking `signalfd` descriptor, or the negated error
            number.
        """
        var fault = self._fault(SysCall.SIGNALFD)
        if fault != 0:
            return fault
        var set = stack_allocation[_SIGSET_BYTES, UInt8]()
        var raw = set.unsafe_bitcast[NoneType]()
        _ = external_call["sigemptyset", Int32](raw)
        _ = external_call["sigaddset", Int32](raw, Int32(SIGTERM))
        _ = external_call["sigaddset", Int32](raw, Int32(SIGINT))
        _ = external_call["sigprocmask", Int32](_SIG_BLOCK, raw, Int(0))
        return _result(
            Int(
                external_call["signalfd", Int32](
                    Int32(-1), raw, _SOCK_NONBLOCK | _SOCK_CLOEXEC
                )
            )
        )

    def read_signal(mut self, fd: Int) -> Int:
        """Read one signal from a `signalfd` descriptor.

        Args:
            fd: The descriptor.

        Returns:
            The signal number, or the negated error number.
        """
        var info = stack_allocation[128, UInt8]()
        var rc = _result(
            external_call["read", Int](
                Int32(fd), info.unsafe_bitcast[NoneType](), 128
            )
        )
        if rc < 0:
            return rc
        return Int(info.unsafe_bitcast[UInt32]().unsafe_load())

    def wall_seconds(mut self) -> Int:
        """Return the wall-clock time: `time(NULL)`.

        Returns:
            The seconds since 1970-01-01 00:00:00 UTC.
        """
        return external_call["time", Int](Int(0))

    def pid(mut self) -> Int:
        """Return the id of this process.

        Returns:
            The id.
        """
        return Int(external_call["getpid", Int32]())

    def pipe(mut self) -> Tuple[Int, Int]:
        """Open a pipe, closed on exec.

        Returns:
            The read end and the write end, or two negated error numbers.
        """
        var fds = stack_allocation[2, Int32]()
        var rc = self._fault(SysCall.PIPE)
        if rc == 0:
            rc = _result(
                Int(
                    external_call["pipe2", Int32](
                        fds.unsafe_bitcast[NoneType](), _SOCK_CLOEXEC
                    )
                )
            )
        if rc < 0:
            return (rc, rc)
        return (Int(fds[unsafe_offset=0]), Int(fds[unsafe_offset=1]))

    def read(mut self, fd: Int, data: Pointer[UInt8, _], size: Int) -> Int:
        """Read from a descriptor, such as a pipe.

        Args:
            fd: The descriptor.
            data: Where the bytes go.
            size: The room at `data`.

        Returns:
            The count read, 0 at the end, or the negated error number.
        """
        return _result(
            external_call["read", Int](
                Int32(fd), data.unsafe_bitcast[NoneType](), size
            )
        )

    def write(mut self, fd: Int, data: Pointer[UInt8, _], size: Int) -> Int:
        """Write to a descriptor, such as a pipe.

        Args:
            fd: The descriptor.
            data: The bytes.
            size: How many bytes to write.

        Returns:
            The count written, or the negated error number.
        """
        return _result(
            external_call["write", Int](
                Int32(fd), data.unsafe_bitcast[NoneType](), size
            )
        )

    def resolve(mut self, host: StringSlice) raises HttpError -> IPv4Address:
        """Find the IPv4 address of a host name with `getaddrinfo`.

        A dotted-decimal address is read without a lookup.

        Args:
            host: A name, such as `localhost`, or an address.

        Returns:
            The first IPv4 address of the host.

        Raises:
            HttpError: `RESOLVE` when the name has no IPv4 address.
        """
        var literal = IPv4Address.parse(host)
        if literal:
            return literal.value()
        var code = -self._fault(SysCall.RESOLVE)
        var name = String(host)
        var hints = stack_allocation[48, UInt8]()
        var index = 0
        while index < 48:
            hints[unsafe_offset=index] = 0
            index += 1
        hints.unsafe_bitcast[Int32]().unsafe_offset(1).unsafe_store(_AF_INET)
        hints.unsafe_bitcast[Int32]().unsafe_offset(2).unsafe_store(
            _SOCK_STREAM
        )
        var result = stack_allocation[1, Int]()
        result[unsafe_offset=0] = 0
        if code == 0:
            code = Int(
                external_call["getaddrinfo", Int32](
                    name.as_c_string_span().ptr(),
                    Int(0),
                    hints.unsafe_bitcast[NoneType](),
                    result.unsafe_bitcast[NoneType](),
                )
            )
        if code != 0:
            raise HttpError(
                ErrorKind.RESOLVE,
                "cannot resolve "
                + name
                + ": getaddrinfo error "
                + String(code),
                code,
            )
        var info = Pointer[UInt8, MutUntrackedOrigin](
            unsafe_from_address=result[unsafe_offset=0]
        )
        var sockaddr = Pointer[UInt8, MutUntrackedOrigin](
            unsafe_from_address=info.unsafe_offset(_AI_ADDR_OFFSET)
            .unsafe_bitcast[Int]()
            .unsafe_load()
        )
        var value = (
            (UInt32(sockaddr[unsafe_offset=4]) << 24)
            | (UInt32(sockaddr[unsafe_offset=5]) << 16)
            | (UInt32(sockaddr[unsafe_offset=6]) << 8)
            | UInt32(sockaddr[unsafe_offset=7])
        )
        external_call["freeaddrinfo", NoneType](result[unsafe_offset=0])
        return IPv4Address(value)


def event_fd(events: Pointer[UInt8, _], index: Int) -> Int:
    """Return the descriptor of one event that `Sys.epoll_wait` returned.

    Args:
        events: The event buffer.
        index: The event's index.

    Returns:
        The descriptor that `Sys.epoll_ctl` stored.
    """
    return Int(
        events.unsafe_offset(index * EPOLL_EVENT_SIZE + _EPOLL_DATA_OFFSET)
        .unsafe_bitcast[UInt64]()
        .unsafe_load()
    )


def event_flags(events: Pointer[UInt8, _], index: Int) -> UInt32:
    """Return the `EPOLL*` flags of one event that `Sys.epoll_wait` returned.

    Args:
        events: The event buffer.
        index: The event's index.

    Returns:
        The flags.
    """
    return (
        events.unsafe_offset(index * EPOLL_EVENT_SIZE)
        .unsafe_bitcast[UInt32]()
        .unsafe_load()
    )

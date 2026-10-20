# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""An epoll event loop that runs event streams and watches descriptors.

The loop owns streams, each with an id. A turn, `poll(timeout_ms)`, waits
in `epoll_wait` for a descriptor or a wake, then polls each woken stream
until it is `PENDING`. The results go into `stream_events`, and the ready
descriptors into `fd_events`, for the owner to act on. A stream that ends
or fails leaves the loop after its last result.

One `eventfd` serves every stream: see `gql_stream.waker`. A turn with
woken streams does not block. An idle turn makes one `epoll_wait`.

To embed another loop, watch its descriptor. A `gql_http` `Server` has
`epoll_fd()`: watch it for `EPOLLIN`, and call `server.poll(0)` when it is
in `fd_events`. Another loop can also watch `fd()` of this loop, and call
`poll(0)` when it is readable.

Linux only. The loop runs on one thread. No code is ported.

Differences from upstream: none; there is no upstream.
"""

from std.ffi import external_call
from std.memory import ArcPointer, stack_allocation
from std.sys import CompilationTarget
from std.sys._libc_errno import get_errno

from gql_stream.poll import EventStream, Poll
from gql_stream.stream import AnyStream
from gql_stream.waker import WakeSet, Waker

comptime EPOLLIN: UInt32 = 0x001
"""The descriptor is readable."""
comptime EPOLLOUT: UInt32 = 0x004
"""The descriptor is writable."""
comptime EPOLLERR: UInt32 = 0x008
"""The descriptor has an error."""
comptime EPOLLHUP: UInt32 = 0x010
"""The peer hung up."""
comptime _EPOLL_CTL_ADD: Int32 = 1
comptime _EPOLL_CTL_DEL: Int32 = 2
comptime _EPOLL_CTL_MOD: Int32 = 3
comptime _EPOLL_CLOEXEC: Int32 = 0o2000000
comptime _EINTR = 4
comptime _EVENT_SIZE = 12 if CompilationTarget.is_x86() else 16
comptime _DATA_OFFSET = 4 if CompilationTarget.is_x86() else 8


@fieldwise_init
struct StreamEvent(Copyable, Movable):
    """One result of one stream in one turn."""

    var id: Int
    """The id of the stream."""
    var poll: Poll
    """The result: `READY`, `DONE` or `ERROR`; never `PENDING`."""


@fieldwise_init
struct FdEvent(Copyable, Movable):
    """One ready descriptor in one turn."""

    var fd: Int
    """The descriptor."""
    var flags: UInt32
    """The `EPOLL*` flags that are set."""


struct EventLoop(Movable):
    """Runs event streams and watches descriptors with one epoll."""

    var wake_set: ArcPointer[WakeSet]
    """The ready set of the streams, with the `eventfd`."""
    var stream_events: List[StreamEvent]
    """The stream results of the last turn, in order."""
    var fd_events: List[FdEvent]
    """The ready descriptors of the last turn."""
    var budget: Int
    """The most results of one stream in one turn; then it waits a turn."""
    var _epoll: Int
    var _streams: List[Optional[AnyStream]]
    var _free: List[Int]
    var _count: Int
    var _ready: List[Int]
    var _buffer: List[UInt8]

    def __init__(out self, max_events: Int = 256, budget: Int = 64) raises:
        """Open the epoll instance and the `eventfd`.

        Args:
            max_events: The most descriptors of one `epoll_wait`.
            budget: The most results of one stream in one turn.

        Raises:
            Error: When epoll or the `eventfd` cannot be opened.
        """
        self.wake_set = ArcPointer(WakeSet(True))
        self.stream_events = List[StreamEvent]()
        self.fd_events = List[FdEvent]()
        self.budget = max(budget, 1)
        self._epoll = -1
        self._streams = List[Optional[AnyStream]]()
        self._free = List[Int]()
        self._count = 0
        self._ready = List[Int]()
        self._buffer = List[UInt8](
            length=max(max_events, 1) * _EVENT_SIZE, fill=0
        )
        var epoll = Int(external_call["epoll_create1", Int32](_EPOLL_CLOEXEC))
        if epoll < 0:
            raise Error("epoll_create1 failed: errno ", get_errno().value)
        self._epoll = epoll
        self.watch(self.wake_set[].fd, EPOLLIN)

    def __deinit__(deinit self):
        """Close every stream, then epoll. The `eventfd` closes with the
        last waker."""
        var id = 0
        while id < len(self._streams):
            if self._streams[id]:
                self._streams[id].value().close()
            id += 1
        _ = external_call["close", Int32](Int32(self._epoll))

    def fd(self) -> Int:
        """Return the epoll descriptor, for an outer loop to watch.

        Returns:
            The descriptor.
        """
        return self._epoll

    def _ctl(mut self, op: Int32, fd: Int, events: UInt32) raises:
        """Run one `epoll_ctl`; the event data is the descriptor."""
        var event = stack_allocation[16, UInt8]()
        event.unsafe_bitcast[UInt32]().unsafe_store(events)
        event.unsafe_offset(_DATA_OFFSET).unsafe_bitcast[UInt64]().unsafe_store(
            UInt64(fd)
        )
        var rc = external_call["epoll_ctl", Int32](
            Int32(self._epoll), op, Int32(fd), event.unsafe_bitcast[NoneType]()
        )
        if rc < 0:
            raise Error("epoll_ctl failed: errno ", get_errno().value)

    def watch(mut self, fd: Int, events: UInt32) raises:
        """Watch a descriptor; it is level-triggered.

        Args:
            fd: The descriptor.
            events: The `EPOLL*` events to wait for.

        Raises:
            Error: When epoll refuses the descriptor.
        """
        self._ctl(_EPOLL_CTL_ADD, fd, events)

    def modify(mut self, fd: Int, events: UInt32) raises:
        """Change the events of a watched descriptor.

        Args:
            fd: The descriptor.
            events: The `EPOLL*` events to wait for.

        Raises:
            Error: When the descriptor is not watched.
        """
        self._ctl(_EPOLL_CTL_MOD, fd, events)

    def unwatch(mut self, fd: Int) raises:
        """Stop watching a descriptor. Do it before you close it.

        Args:
            fd: The descriptor.

        Raises:
            Error: When the descriptor is not watched.
        """
        self._ctl(_EPOLL_CTL_DEL, fd, 0)

    def add[S: EventStream](mut self, var stream: S) -> Int:
        """Add a stream; the next turn polls it.

        Parameters:
            S: The type of the stream.

        Args:
            stream: The stream; the loop owns it.

        Returns:
            The id of the stream. A free id is used again.
        """
        return self.add(AnyStream(stream^))

    def add(mut self, var stream: AnyStream) -> Int:
        """Add a boxed stream; the next turn polls it.

        Args:
            stream: The stream; the loop owns it.

        Returns:
            The id of the stream. A free id is used again.
        """
        var id: Int
        if self._free:
            id = self._free.pop()
            self._streams[id] = Optional(stream^)
        else:
            id = len(self._streams)
            self._streams.append(Optional(stream^))
        self._count += 1
        self.wake_set[].wake(id)
        return id

    def cancel(mut self, id: Int) -> Bool:
        """Close a stream and remove it, as an unsubscribe does.

        Args:
            id: The id of the stream.

        Returns:
            Whether the stream was in the loop.
        """
        if not self.has(id):
            return False
        self._streams[id].value().close()
        self._remove(id)
        return True

    def _remove(mut self, id: Int):
        """Drop a stream and make its id free."""
        self._streams[id] = None
        self._free.append(id)
        self._count -= 1

    def has(self, id: Int) -> Bool:
        """Return True when a stream with the id is in the loop.

        Args:
            id: The id.

        Returns:
            Whether the id names a stream of the loop.
        """
        return id >= 0 and id < len(self._streams) and Bool(self._streams[id])

    def stream_count(self) -> Int:
        """Return the count of streams in the loop.

        Returns:
            The count.
        """
        return self._count

    def waker(self, id: Int) -> Waker:
        """Return the waker of a stream id.

        Args:
            id: The id.

        Returns:
            The waker.
        """
        return Waker(self.wake_set, id)

    def run_ready(mut self) -> Int:
        """Poll each woken stream until it is `PENDING`, without waiting.

        The results go after those in `stream_events`. A stream that gives
        `budget` results waits for the next turn, so that one busy stream
        cannot starve the others.

        Returns:
            The count of results that this call added.
        """
        var before = len(self.stream_events)
        self.wake_set[].take(self._ready)
        var index = 0
        while index < len(self._ready):
            var id = self._ready[index]
            index += 1
            if not self.has(id):
                continue
            var waker = Waker(self.wake_set, id)
            var results = 0
            while True:
                var poll = self._streams[id].value().poll_next(waker)
                if poll.is_pending():
                    break
                var last = not poll.is_ready()
                self.stream_events.append(StreamEvent(id, poll^))
                if last:
                    self._remove(id)
                    break
                results += 1
                if results == self.budget:
                    waker.wake()
                    break
        return len(self.stream_events) - before

    def poll(mut self, timeout_ms: Int) raises -> Int:
        """Run one turn: wait for descriptors or wakes, then run the streams.

        The turn clears `stream_events` and `fd_events` first. It does not
        block when a stream is woken already.

        Args:
            timeout_ms: The longest wait in milliseconds; -1 waits until an
                event, 0 does not wait.

        Returns:
            The count of stream results and ready descriptors.

        Raises:
            Error: When `epoll_wait` fails.
        """
        self.stream_events.clear()
        self.fd_events.clear()
        var wait = 0 if self.wake_set[].pending() > 0 else timeout_ms
        var buffer = self._buffer.unsafe_ptr()
        var count = Int(
            external_call["epoll_wait", Int32](
                Int32(self._epoll),
                buffer.unsafe_bitcast[NoneType](),
                Int32(len(self._buffer) // _EVENT_SIZE),
                Int32(wait),
            )
        )
        if count < 0:
            var errno = Int(get_errno().value)
            if errno != _EINTR:
                raise Error("epoll_wait failed: errno ", errno)
            count = 0
        var wake_fd = self.wake_set[].fd
        for index in range(count):
            var at = buffer.unsafe_offset(index * _EVENT_SIZE)
            var fd = Int(
                at.unsafe_offset(_DATA_OFFSET)
                .unsafe_bitcast[UInt64]()
                .unsafe_load()
            )
            if fd != wake_fd:
                var flags = at.unsafe_bitcast[UInt32]().unsafe_load()
                self.fd_events.append(FdEvent(fd, flags))
        _ = self.run_ready()
        return len(self.stream_events) + len(self.fd_events)

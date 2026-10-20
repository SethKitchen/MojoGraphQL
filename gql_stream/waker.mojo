# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Wakers: how a stream tells its event loop that it can make progress.

A `WakeSet` is the ready set of one event loop. It holds the ids of the
streams that are ready, each id at most once, and a Linux `eventfd`. The
first wake after the loop took the ready ids writes the `eventfd` once, so
that an `epoll_wait` on it returns. Thousands of streams share the one
descriptor; the id tells them apart.

A `Waker` is a copy of a reference to a `WakeSet` and one stream id. A
stream that returns `PENDING` keeps the waker of that poll, and calls
`wake()` when it has an event, is done, or failed. A spurious wake is
harmless: the loop polls the stream, and the stream returns `PENDING`
again.

All of this runs on the thread of the loop. A `WakeSet` has no locks, so
do not call `wake()` from another thread.

The model is the Rust `std::task::Waker` and `futures::Stream` model, but
no code is ported.

Differences from upstream: none; there is no upstream.
"""

from std.ffi import external_call
from std.memory import ArcPointer, stack_allocation
from std.sys._libc_errno import get_errno

comptime _EFD_NONBLOCK: Int32 = 0o4000
comptime _EFD_CLOEXEC: Int32 = 0o2000000


struct WakeSet(Movable):
    """The ready set of one event loop, with its `eventfd`."""

    var fd: Int
    """The `eventfd`, or -1 for a set without one."""
    var signaled: Bool
    """Whether the `eventfd` holds a count that nobody has read."""
    var ready: List[Int]
    """The ids of the ready streams, in the order of their first wake."""
    var queued: List[Bool]
    """For each id, whether it is in `ready`."""

    def __init__(out self, with_fd: Bool) raises:
        """Make an empty ready set.

        Args:
            with_fd: Whether to open an `eventfd`. A set without one serves
                a loop that never blocks, such as a test.

        Raises:
            Error: When the `eventfd` cannot be opened; the message names
                the error number.
        """
        self.fd = -1
        self.signaled = False
        self.ready = List[Int]()
        self.queued = List[Bool]()
        if not with_fd:
            return
        var fd = Int(
            external_call["eventfd", Int32](
                Int32(0), _EFD_NONBLOCK | _EFD_CLOEXEC
            )
        )
        if fd < 0:
            raise Error("eventfd failed: errno ", get_errno().value)
        self.fd = fd

    def __deinit__(deinit self):
        """Close the `eventfd`."""
        if self.fd >= 0:
            _ = external_call["close", Int32](Int32(self.fd))

    def wake(mut self, id: Int):
        """Mark a stream as ready.

        The first wake after `take` writes the `eventfd`. A stream that is
        ready already stays in its place.

        Args:
            id: The id of the stream; zero or more.
        """
        while len(self.queued) <= id:
            self.queued.append(False)
        if self.queued[id]:
            return
        self.queued[id] = True
        self.ready.append(id)
        if self.signaled or self.fd < 0:
            return
        self.signaled = True
        _ = external_call["eventfd_write", Int32](Int32(self.fd), UInt64(1))

    def take(mut self, mut into: List[Int]):
        """Move the ready ids out, in order, and clear the signal.

        The `eventfd` is read only when a wake wrote it, so an idle turn
        makes no system call.

        Args:
            into: The list that gets the ids; it is cleared first.
        """
        into.clear()
        swap(into, self.ready)
        for index in range(len(into)):
            self.queued[into[index]] = False
        if not self.signaled:
            return
        self.signaled = False
        var count = stack_allocation[1, UInt64]()
        _ = external_call["eventfd_read", Int32](
            Int32(self.fd), count.unsafe_bitcast[NoneType]()
        )

    def pending(self) -> Int:
        """Return the count of ready ids.

        Returns:
            The count.
        """
        return len(self.ready)


struct Waker(Copyable, Movable):
    """Wakes one stream of one event loop: graphql-js has no counterpart;
    this is the Rust `Waker`."""

    var _set: ArcPointer[WakeSet]
    var _id: Int

    def __init__(out self, set: ArcPointer[WakeSet], id: Int):
        """Make the waker of one stream.

        Args:
            set: The ready set of the loop.
            id: The id of the stream; zero or more.
        """
        self._set = set
        self._id = id

    @staticmethod
    def noop() raises -> Waker:
        """Make a waker that wakes nothing that blocks.

        It has its own ready set, without an `eventfd`. Use it to poll a
        stream outside an event loop, as a test does.

        Returns:
            The waker, with the id 0.

        Raises:
            Error: Never; the set opens no descriptor.
        """
        return Waker(ArcPointer(WakeSet(False)), 0)

    def wake(self):
        """Tell the loop that the stream can make progress."""
        self._set[].wake(self._id)

    def id(self) -> Int:
        """Return the id of the stream.

        Returns:
            The id.
        """
        return self._id

    def will_wake(self, other: Waker) -> Bool:
        """Return True when both wakers wake the same stream of the same loop.

        A stream can keep its waker when the new one would wake the same.

        Args:
            other: The other waker.

        Returns:
            Whether the set and the id are the same.
        """
        return self._id == other._id and self._set_address() == (
            other._set_address()
        )

    def _set_address(self) -> Int:
        """Return the address of the ready set."""
        return Int(Pointer(to=self._set[]))

    def woken(self) -> Bool:
        """Return True when the stream is in the ready set now.

        Returns:
            Whether a wake is pending for this id.
        """
        ref set = self._set[]
        return self._id < len(set.queued) and set.queued[self._id]

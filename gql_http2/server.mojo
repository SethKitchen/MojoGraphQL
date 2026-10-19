# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A server for HTTP/2 and HTTP/1.1 on one port: an epoll event loop that
reads the first bytes of each connection to choose the protocol.

A connection that starts with the HTTP/2 preface is h2c with prior
knowledge (RFC 9113 section 3.3), and a `ServerSession` serves it. Any
other connection goes to an HTTP/1.1 server of gql_http, which runs in the
same process with its epoll descriptor inside this loop. When
`ServerConfig.upgrade` is on, a first request with `Upgrade: h2c` and
`HTTP2-Settings` switches the connection to HTTP/2 (RFC 7540 section 3.2).
RFC 9113 deprecates the upgrade, so it is off by default.

One `Handler` serves both protocols. For TLS, a TLS layer chooses the
protocol with ALPN and calls `serve_transport` of `gql_http2.session`.

This module ports the accept and handshake parts of h2 v0.4.20
`src/server.rs` (`handshake`, `Builder`, `Connection::graceful_shutdown`),
and the worker model of gql_http.

Differences from upstream: h2 serves a connection that its caller
accepted, and has no listener and no HTTP/1.1. Here the server listens,
chooses the protocol, and serves HTTP/1.1 with gql_http, as hyper's
`auto` connection builder does.
"""

from std.time import perf_counter_ns

from gql_http.error import ErrorKind, HttpError
from gql_http.parser import ParseState, RequestReader
from gql_http.scan import move_down
from gql_http.server import (
    Handler,
    Listener,
    WorkerPool,
    detached,
    open_listener,
)
from gql_http.server import Server as HttpServer
from gql_http.server import ServerConfig as HttpConfig
from gql_http.socket import (
    EAGAIN,
    EINTR,
    EPOLL_CTL_ADD,
    EPOLL_CTL_DEL,
    EPOLL_CTL_MOD,
    EPOLL_EVENT_SIZE,
    EPOLLIN,
    EPOLLOUT,
    Sys,
    event_fd,
    event_flags,
)

from gql_http2.connection import Config
from gql_http2.error import Reason
from gql_http2.frame import PREFACE, PREFACE_SIZE
from gql_http2.session import ServerSession, is_h2c_upgrade


struct ServerConfig(Copyable, Movable):
    """The configuration of a server for HTTP/2 and HTTP/1.1."""

    var http: HttpConfig
    """The address, the port, the workers, the timeouts and the request
    limits, as for a gql_http server."""
    var h2: Config
    """The limits of each HTTP/2 connection."""
    var prior_knowledge: Bool
    """Whether a connection that starts with the preface gets HTTP/2."""
    var upgrade: Bool
    """Whether a first request with `Upgrade: h2c` switches to HTTP/2."""

    def __init__(out self):
        """Make the defaults: h2c with prior knowledge, no upgrade."""
        self.http = HttpConfig()
        self.h2 = Config()
        self.prior_knowledge = True
        self.upgrade = False


struct _Conn(Movable):
    """The state of one connection of this loop."""

    var fd: Int
    var session: Int
    var detect: List[UInt8]
    var deadline_ms: Int
    var interest: UInt32

    def __init__(out self):
        self.fd = -1
        self.session = -1
        self.detect = List[UInt8]()
        self.deadline_ms = 0
        self.interest = 0


def _now_ms() -> Int:
    """Return a monotonic time in milliseconds."""
    return Int(perf_counter_ns() // 1_000_000)


struct Server[H: Handler](Movable):
    """One event loop that serves a handler with HTTP/2 and HTTP/1.1.

    Parameters:
        H: The type of the handler.
    """

    var http1: HttpServer[Self.H]
    """The HTTP/1.1 server; it owns the handler of both protocols."""
    var config: ServerConfig
    """The configuration."""
    var sys: Sys
    """The system calls of the loop."""
    var port: Int
    """The local port."""
    var open_connections: Int
    """The connections of this loop: HTTP/2, and those not chosen yet."""
    var draining: Bool
    """Whether a graceful shutdown has begun."""
    var _listen_fd: Int
    var _epoll_fd: Int
    var _conns: List[_Conn]
    var _sessions: List[ServerSession]
    var _free: List[Int]
    var _events: List[UInt8]
    var _buffer: List[UInt8]
    var _probe: RequestReader
    var _now: Int
    var _last_sweep: Int
    var _drain_deadline: Int

    def __init__(
        out self,
        var handler: Self.H,
        config: ServerConfig,
        listener: Listener,
        var sys: Sys,
    ) raises HttpError:
        """Serve on a listening socket that is open already.

        Args:
            handler: The handler of every request.
            config: The configuration.
            listener: The socket; the server closes it.
            sys: The system calls; tests give one with faults.

        Raises:
            HttpError: `OS` when epoll cannot be opened, or cannot watch the
                socket. The socket is closed.
        """
        # The HTTP/1.1 server has its own system calls: the faults of a
        # test are for this loop.
        self.http1 = detached(handler^, config.http)
        self.config = config.copy()
        self.sys = sys^
        self.port = listener.port
        self.open_connections = 0
        self.draining = False
        self._listen_fd = listener.fd
        self._epoll_fd = -1
        self._conns = List[_Conn]()
        self._sessions = List[ServerSession]()
        self._free = List[Int]()
        self._events = List[UInt8](
            length=max(config.http.max_events, 1) * EPOLL_EVENT_SIZE, fill=0
        )
        self._buffer = List[UInt8](length=65536, fill=0)
        self._probe = RequestReader(config.http.limits)
        self._now = _now_ms()
        self._last_sweep = self._now
        self._drain_deadline = 0
        var epoll = self.sys.epoll_create()
        if epoll < 0:
            self.close()
            raise HttpError.os("epoll_create1", -epoll)
        self._epoll_fd = epoll
        var rc = self.sys.epoll_ctl(epoll, EPOLL_CTL_ADD, listener.fd, EPOLLIN)
        if rc >= 0:
            rc = self.sys.epoll_ctl(
                epoll, EPOLL_CTL_ADD, self.http1.epoll_fd(), EPOLLIN
            )
        if rc < 0:
            self.close()
            raise HttpError.os("epoll_ctl", -rc)

    def __deinit__(deinit self):
        """Close every descriptor that is still open."""
        self.close()

    def close(mut self):
        """Close the listening socket, every connection and epoll at once."""
        var fd = 0
        while fd < len(self._conns):
            if self._conns[fd].fd >= 0:
                self._close(fd)
            fd += 1
        if self._listen_fd >= 0:
            self.sys.close(self._listen_fd)
            self._listen_fd = -1
        if self._epoll_fd >= 0:
            self.sys.close(self._epoll_fd)
            self._epoll_fd = -1
        self.http1.close()

    def listen_signals(mut self) raises HttpError:
        """Begin a graceful shutdown on `SIGTERM` or `SIGINT`.

        Call it only in a process with one thread, such as a worker.

        Raises:
            HttpError: `OS` when the `signalfd` cannot be opened or watched.
        """
        self.http1.listen_signals()

    def stopped(self) -> Bool:
        """Return True when a graceful shutdown has ended.

        Returns:
            Whether both protocols drain and no connection is open.
        """
        return (
            self.draining
            and self.open_connections == 0
            and self.http1.stopped()
        )

    def run(mut self) raises HttpError:
        """Run the loop until a graceful shutdown ends.

        Raises:
            HttpError: `OS` when `epoll_wait` fails.
        """
        while not self.stopped():
            _ = self.poll(-1)

    def begin_shutdown(mut self):
        """Stop accepting, and end each connection gracefully: HTTP/2 with
        `GOAWAY`, HTTP/1.1 as gql_http does."""
        if self.draining:
            return
        self.draining = True
        self._drain_deadline = self._now + self.config.http.shutdown_timeout_ms
        if self._listen_fd >= 0:
            _ = self.sys.epoll_ctl(
                self._epoll_fd, EPOLL_CTL_DEL, self._listen_fd, 0
            )
            self.sys.close(self._listen_fd)
            self._listen_fd = -1
        self.http1.begin_shutdown()
        var fd = 0
        while fd < len(self._conns):
            if self._conns[fd].fd >= 0:
                if self._conns[fd].session < 0:
                    self._close(fd)
                else:
                    self._sessions[
                        self._conns[fd].session
                    ].conn.begin_shutdown()
                    self._flush(fd)
            fd += 1

    def poll(mut self, timeout_ms: Int) raises HttpError -> Int:
        """Run one turn of the loop: wait for events and handle them.

        Args:
            timeout_ms: The longest wait in milliseconds; -1 waits until an
                event. With open connections the wait is at most a second,
                so that idle connections time out.

        Returns:
            The count of events.

        Raises:
            HttpError: `OS` when `epoll_wait` fails.
        """
        var wait = timeout_ms
        var busy = self.open_connections + self.http1.open_connections
        if busy > 0 or self.draining:
            wait = 1000 if wait < 0 else min(wait, 1000)
        var count = self.sys.epoll_wait(
            self._epoll_fd,
            self._events.unsafe_ptr(),
            len(self._events) // EPOLL_EVENT_SIZE,
            wait,
        )
        if count == -EINTR:
            count = 0
        if count < 0:
            raise HttpError.os("epoll_wait", -count)
        self._now = _now_ms()
        var events = self._events.unsafe_ptr()
        var index = 0
        while index < count:
            var fd = event_fd(events, index)
            var flags = event_flags(events, index)
            index += 1
            if fd == self._listen_fd:
                self._accept()
            elif fd == self.http1.epoll_fd():
                _ = self.http1.poll(0)
            elif flags & EPOLLOUT != 0:
                # Only its own event closes a connection, so the events of
                # one turn are of open connections.
                self._flush(fd)
            else:
                self._readable(fd)
        if self.http1.draining:
            self.begin_shutdown()
        if self._now - self._last_sweep >= 1000 or self.draining:
            self._sweep()
        return count

    def _sweep(mut self) raises HttpError:
        """Close the connections whose deadline has passed, and let the
        HTTP/1.1 server sweep its own."""
        self._last_sweep = self._now
        _ = self.http1.poll(0)
        var force = self.draining and self._now >= self._drain_deadline
        var fd = 0
        while fd < len(self._conns):
            if self._conns[fd].fd >= 0 and (
                force or self._now >= self._conns[fd].deadline_ms
            ):
                var session = self._conns[fd].session
                if session >= 0:
                    self._sessions[session].conn.abort(Reason.NO_ERROR)
                    ref out = self._sessions[session].conn.out
                    _ = self.sys.send(fd, out.unsafe_ptr(), len(out))
                self._close(fd)
            fd += 1

    def _accept(mut self):
        """Accept every pending connection."""
        while True:
            var fd = self.sys.accept(self._listen_fd)
            if fd < 0:
                return
            var open = self.open_connections + self.http1.open_connections
            if open >= self.config.http.max_connections:
                self.sys.close(fd)
                continue
            _ = self.sys.set_no_delay(fd)
            while len(self._conns) <= fd:
                self._conns.append(_Conn())
            if (
                self.sys.epoll_ctl(self._epoll_fd, EPOLL_CTL_ADD, fd, EPOLLIN)
                < 0
            ):
                self.sys.close(fd)
                continue
            self._conns[fd].fd = fd
            self._conns[fd].session = -1
            self._conns[fd].detect.clear()
            self._conns[fd].interest = EPOLLIN
            self._conns[fd].deadline_ms = (
                self._now + self.config.http.idle_timeout_ms
            )
            self.open_connections += 1

    def _close(mut self, fd: Int):
        """Close a connection and make its slot free."""
        self.sys.close(fd)
        var session = self._conns[fd].session
        if session >= 0:
            self._free.append(session)
        self._conns[fd].fd = -1
        self._conns[fd].session = -1
        self._conns[fd].detect.clear()
        self.open_connections -= 1

    def _watch(mut self, fd: Int, events: UInt32) -> Bool:
        """Set the events of a connection; False after closing it."""
        if self._conns[fd].interest == events:
            return True
        if self.sys.epoll_ctl(self._epoll_fd, EPOLL_CTL_MOD, fd, events) < 0:
            self._close(fd)
            return False
        self._conns[fd].interest = events
        return True

    def _readable(mut self, fd: Int):
        """Read from a connection: choose its protocol, or serve HTTP/2."""
        var n = self.sys.recv(fd, self._buffer.unsafe_ptr(), len(self._buffer))
        if n == -EAGAIN or n == -EINTR:
            return
        if n <= 0:
            self._close(fd)
            return
        self._conns[fd].deadline_ms = (
            self._now + self.config.http.idle_timeout_ms
        )
        var data = Span[UInt8, ImmUntrackedOrigin](
            unsafe_ptr=Pointer[UInt8, ImmUntrackedOrigin](
                unsafe_from_address=Int(self._buffer.unsafe_ptr())
            ),
            length=n,
        )
        var session = self._conns[fd].session
        if session >= 0:
            self._sessions[session].receive(self.http1.handler, data)
            self._flush(fd)
            return
        self._conns[fd].detect.extend(data)
        self._detect(fd)

    def _detect(mut self, fd: Int):
        """Choose the protocol of a connection from its first bytes."""
        var size = len(self._conns[fd].detect)
        var address = Int(self._conns[fd].detect.unsafe_ptr())
        var data = Span[UInt8, ImmUntrackedOrigin](
            unsafe_ptr=Pointer[UInt8, ImmUntrackedOrigin](
                unsafe_from_address=address
            ),
            length=size,
        )
        if self.config.prior_knowledge and _starts_preface(data):
            if size < PREFACE_SIZE:
                return
            var session = self._new_session(fd)
            self._sessions[session].start()
            self._sessions[session].receive(self.http1.handler, data)
            self._conns[fd].detect.clear()
            self._flush(fd)
            return
        if self.config.upgrade:
            # The reader waits for the whole request, content too.
            self._probe.reset()
            self._probe.append(data)
            var result = self._probe.next()
            if result.state == ParseState.INCOMPLETE:
                return
            if result.state == ParseState.COMPLETE and is_h2c_upgrade(
                self._probe.request
            ):
                var session = self._new_session(fd)
                if (
                    self._sessions[session].upgrade(self.http1.handler, data)
                    >= 0
                ):
                    self._conns[fd].detect.clear()
                    self._flush(fd)
                    return
                self._free.append(session)
                self._conns[fd].session = -1
        self._adopt(fd)

    def _new_session(mut self, fd: Int) -> Int:
        """Make a session for a connection in a free slot."""
        var session = ServerSession(self.config.h2, self.config.http.limits)
        var index: Int
        if len(self._free) > 0:
            index = self._free.pop()
            self._sessions[index] = session^
        else:
            index = len(self._sessions)
            self._sessions.append(session^)
        self._conns[fd].session = index
        return index

    def _adopt(mut self, fd: Int):
        """Give a connection to the HTTP/1.1 server, with what it read."""
        _ = self.sys.epoll_ctl(self._epoll_fd, EPOLL_CTL_DEL, fd, 0)
        self._conns[fd].fd = -1
        self.open_connections -= 1
        self.http1.adopt(fd, self._conns[fd].detect)
        self._conns[fd].detect.clear()

    def _flush(mut self, fd: Int):
        """Send the output of a session, and keep what the socket refuses.
        A connection with output waits for `EPOLLOUT` before it reads."""
        var session = self._conns[fd].session
        var total = len(self._sessions[session].conn.out)
        if total > 0:
            var sent = self.sys.send(
                fd, self._sessions[session].conn.out.unsafe_ptr(), total
            )
            if sent == -EAGAIN or sent == -EINTR:
                sent = 0
            if sent < 0:
                self._close(fd)
                return
            var rest = total - sent
            move_down(
                self._sessions[session].conn.out.unsafe_ptr(), 0, sent, rest
            )
            self._sessions[session].conn.out.resize(rest, 0)
            if rest > 0:
                # The peer reads: the connection is not quiet.
                self._conns[fd].deadline_ms = (
                    self._now + self.config.http.idle_timeout_ms
                )
                _ = self._watch(fd, EPOLLOUT)
                return
        if self._sessions[session].is_done():
            self._close(fd)
            return
        _ = self._watch(fd, EPOLLIN)


def _starts_preface(data: Span[UInt8, _]) -> Bool:
    """Return True when bytes are the preface, or the start of it."""
    var preface = StaticString(PREFACE).as_bytes()
    var index = 0
    while index < min(len(data), PREFACE_SIZE):
        if data[index] != preface[index]:
            return False
        index += 1
    return True


def listen[
    H: Handler
](
    var handler: H, config: ServerConfig, var sys: Sys = Sys()
) raises HttpError -> Server[H]:
    """Make a server that listens on the address and the port of a
    configuration, in this process.

    Args:
        handler: The handler of every request, for both protocols.
        config: The configuration.
        sys: The system calls; tests give one with faults.

    Returns:
        The server. Its `port` is the port it listens on.

    Raises:
        HttpError: `OS` when the socket or epoll cannot be opened.

    Parameters:
        H: The type of the handler.
    """
    var listener = open_listener(
        sys,
        config.http.host,
        config.http.port,
        config.http.backlog,
        config.http.reuse_port,
    )
    return Server(handler^, config, listener, sys^)


def start_workers[
    H: Handler
](
    var handler: H, config: ServerConfig, var sys: Sys = Sys()
) raises HttpError -> WorkerPool:
    """Fork `config.http.workers` processes that serve a handler on one
    port, with HTTP/2 and HTTP/1.1.

    The parent opens one listening socket per worker with `SO_REUSEPORT`,
    and then forks, as gql_http does. The call returns at once.

    Args:
        handler: The handler; each worker gets a copy of its memory.
        config: The configuration. A port of 0 picks a free port.
        sys: The system calls; tests give one with faults.

    Returns:
        The pool, with the port.

    Raises:
        HttpError: `OS` when a socket cannot be opened or `fork` fails.
            The workers that had started are stopped.

    Parameters:
        H: The type of the handler.
    """
    var count = max(config.http.workers, 1)
    var listeners = List[Int]()
    var port = config.http.port
    while len(listeners) < count:
        try:
            var listener = open_listener(
                sys, config.http.host, port, config.http.backlog, True
            )
            port = listener.port
            listeners.append(listener.fd)
        except e:
            _close_all(sys, listeners)
            raise e^
    var parent = sys.pid()
    var pids = List[Int]()
    var child = -1
    while len(pids) < count:
        var pid = sys.fork()
        if pid == 0:
            child = len(pids)
            break
        if pid < 0:
            _close_all(sys, listeners)
            var started = WorkerPool(pids^, port)
            _ = started.stop(1000)
            raise HttpError.os("fork", -pid)
        pids.append(pid)
    if child >= 0:
        run_worker(handler^, config, listeners, child, port, parent, sys.copy())
    _close_all(sys, listeners)
    return WorkerPool(pids^, port)


def _close_all(mut sys: Sys, fds: List[Int]):
    """Close every descriptor of a list."""
    var index = 0
    while index < len(fds):
        sys.close(fds[index])
        index += 1


def run_worker[
    H: Handler
](
    var handler: H,
    config: ServerConfig,
    listeners: List[Int],
    index: Int,
    port: Int,
    parent: Int,
    var sys: Sys = Sys(),
):
    """Run the event loop of one worker, then end the process.

    `start_workers` calls it in each child. It does not return.

    Args:
        handler: The handler.
        config: The configuration.
        listeners: Every listening socket; the worker keeps one.
        index: Which socket the worker keeps.
        port: The port.
        parent: The id of the parent process. When the parent has ended
            already, the worker ends at once with status 1.
        sys: The system calls of the worker and its server.

    Parameters:
        H: The type of the handler.
    """
    var position = 0
    while position < len(listeners):
        if position != index:
            sys.close(listeners[position])
        position += 1
    _ = sys.die_with_parent()
    var code = 0
    if sys.parent_pid() != parent:
        sys.close(listeners[index])
        code = 1
    else:
        try:
            var server = Server(
                handler^, config, Listener(listeners[index], port), sys.copy()
            )
            server.listen_signals()
            server.run()
        except:
            code = 1
    sys.exit_now(code)


def serve[
    H: Handler
](var handler: H, config: ServerConfig, var sys: Sys = Sys()) raises HttpError:
    """Serve a handler with worker processes until they end.

    Send `SIGTERM` or `SIGINT` to the process group for a graceful
    shutdown; a worker also gets `SIGTERM` when this process ends.

    Args:
        handler: The handler, for both protocols.
        config: The configuration.
        sys: The system calls of the parent and the workers.

    Raises:
        HttpError: `OS` when the workers cannot start, or a worker fails.

    Parameters:
        H: The type of the handler.
    """
    var pool = start_workers(handler^, config, sys^)
    var failed = pool.wait()
    if failed > 0:
        raise HttpError(ErrorKind.OS, String(failed) + " workers failed", 0)

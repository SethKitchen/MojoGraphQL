# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Start and stop a server command for the load generator, as
`bench/gql_ws/_wsload.mojo` does."""

from std.ffi import external_call
from std.time import perf_counter_ns

from gql_http.socket import SIGKILL, SIGTERM, Sys


def spawn(command: String) raises -> Tuple[Int, Int]:
    """Start `/bin/sh -c command` in its own process group, and return its
    process id and the port from its `PORT <n>` output line.

    Args:
        command: The server command.

    Returns:
        The process id and the port.

    Raises:
        Error: When the server ends before it prints its port.
    """
    var sys = Sys()
    var fds = sys.pipe()
    var shell = String("/bin/sh")
    var flag = String("-c")
    var cmd = command.copy()
    var pid = sys.fork()
    if pid == 0:
        _ = external_call["setpgid", Int32](Int32(0), Int32(0))
        _ = external_call["dup2", Int32](Int32(fds[1]), Int32(1))
        var args = List[Int]()
        args.append(Int(shell.as_c_string_span().ptr()))
        args.append(Int(flag.as_c_string_span().ptr()))
        args.append(Int(cmd.as_c_string_span().ptr()))
        args.append(0)
        _ = external_call["execv", Int32](
            shell.as_c_string_span().ptr(), args.unsafe_ptr()
        )
        sys.exit_now(127)
    _ = shell
    _ = flag
    _ = cmd
    sys.close(fds[1])
    var line = List[UInt8]()
    var byte = List[UInt8](length=1, fill=0)
    while True:
        var n = sys.read(fds[0], byte.unsafe_ptr(), 1)
        if n <= 0:
            raise Error("the server ended before it printed PORT <n>")
        if byte[0] == 10:
            var text = String(unsafe_from_utf8=line)
            if text.startswith("PORT "):
                break
            line.clear()
            continue
        line.append(byte[0])
    var text = String(unsafe_from_utf8=line)
    sys.close(fds[0])
    return (pid, Int(String(text[byte=5:])))


def stop(pid: Int):
    """Stop a server process group: SIGTERM, then SIGKILL after 3 s.

    Args:
        pid: The process id, which is also the group id.
    """
    var sys = Sys()
    _ = sys.kill(-pid, SIGTERM)
    var deadline = Int(perf_counter_ns()) + 3_000_000_000
    while Int(perf_counter_ns()) < deadline:
        var result = sys.wait(pid, False)
        if result[0] != 0:
            _ = sys.kill(-pid, SIGKILL)
            return
        _ = sys.poll(-1, 0, 10)
    _ = sys.kill(-pid, SIGKILL)
    _ = sys.wait(pid, True)

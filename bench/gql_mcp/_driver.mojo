# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The MCP client of the gql_mcp server benchmarks, in Mojo.

Every server workload, the Mojo one and the Apollo MCP Server baseline,
runs under this program, so that only the server differs. The driver:

1. splits `bench/fixtures/mcp-operations.graphql` into one file for each
   of its 200 operations, in `.cache/mcp-bench/operations/`;
2. starts a stub GraphQL endpoint, a gql_http worker that answers each
   POST with the same small result;
3. sets `MCP_BENCH_ROOT`, `MCP_BENCH_DIR` and `APOLLO_MCP_ENDPOINT`, and
   starts the server command with pipes on its standard input and output;
4. sends `initialize` and `notifications/initialized`, as an MCP client
   does over the stdio transport;
5. times each workload: it writes one request line and reads the whole
   response line, one request in flight. The method is the one of every
   benchmark: a warm-up of at least 200 ms, then the fastest of 5 rounds
   of at least one second each.

Workloads:

- `mcp/tools-list-200`: `tools/list` of the 200 operations and the
  `execute`, `introspect`, `search` and `validate` tools, with output
  schemas, over the GitHub schema of graphql-js `benchmark/`.
- `mcp/call-operation`: `tools/call` of the operation `Repository01`: the
  server sends the operation to the stub endpoint over HTTP and returns the
  result as structured content.
- `mcp/call-search`: `tools/call` of `search` with two terms: the schema
  index of the GitHub schema, and the types that it finds.
- `mcp/call-introspect`: `tools/call` of `introspect` of `Repository`, a
  type of more than 100 fields, at depth 1.
- `mcp/call-validate`: `tools/call` of `validate` of an operation with
  variables, arguments and nesting.

As a program, it takes the server command:

    mcp_driver [--root <repository root>] <server command>

With `MCP_BENCH_SHOW` set, it also prints the `tools/call` response, so
that the replies of two servers can be compared.
"""

from std.ffi import external_call
from std.os import getenv, makedirs
from std.sys import argv
from std.time import perf_counter_ns

from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter, ServerConfig, start_workers
from gql_http.server import WorkerPool
from gql_http.socket import SIGKILL, SIGTERM, IPv4Address, Sys

comptime OPERATIONS_FIXTURE = "bench/fixtures/mcp-operations.graphql"
"""The 200 operations, separated by blank lines."""
comptime BENCH_DIR = ".cache/mcp-bench"
"""Where the driver writes the operation files."""
comptime STUB_BODY = (
    '{"data":{"repository":{"id":"MDEwOlJlcG9zaXRvcnkx","name":'
    '"apollo-mcp-server","description":"Apollo MCP Server","stargazers":'
    '{"totalCount":1000}}}}'
)
"""The result that the stub endpoint sends for every request."""
comptime TOOL_COUNT = 204
"""The tools that `tools/list` must return: 200 operations and 4 tools."""
comptime INITIALIZE = (
    '{"jsonrpc":"2.0","id":0,"method":"initialize","params":'
    '{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":'
    '{"name":"mojographql-bench","version":"0.0.0"}}}'
)
"""The `initialize` request."""
comptime INITIALIZED = '{"jsonrpc":"2.0","method":"notifications/initialized"}'
"""The notification that ends the handshake."""
comptime TOOLS_LIST = '"method":"tools/list"}'
"""The tail of a `tools/list` request."""
comptime CALL = (
    '"method":"tools/call","params":{"name":"Repository01","arguments":'
    '{"owner":"apollographql","name":"apollo-mcp-server"}}}'
)
"""The tail of the `tools/call` request."""
comptime SEARCH = (
    '"method":"tools/call","params":{"name":"search","arguments":'
    '{"terms":["pull request","review comment"]}}}'
)
"""The tail of a `search` call: the schema index of the GitHub schema."""
comptime INTROSPECT = (
    '"method":"tools/call","params":{"name":"introspect","arguments":'
    '{"type_name":"Repository","depth":1}}}'
)
"""The tail of an `introspect` call of a large type."""
comptime VALIDATE = (
    '"method":"tools/call","params":{"name":"validate","arguments":'
    '{"operation":"query($owner: String!, $name: String!) { repository(owner:'
    " $owner, name: $name) { name stargazers { totalCount } issues(first: 10)"
    ' { nodes { title author { login } } } } }"}}}'
)
"""The tail of a `validate` call of a valid operation."""
comptime WARMUP_NS = 200_000_000
"""The least time of the warm-up."""
comptime ROUND_NS = 1_000_000_000
"""The least time of a round."""
comptime ROUNDS = 5
"""How many rounds each workload runs."""


@fieldwise_init
struct Stub(Handler):
    """The stub GraphQL endpoint: the same result for every request."""

    var requests: Int
    """How many requests the stub answered."""

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        """Write the result.

        Args:
            request: The request.
            response: The response.

        Raises:
            Error: Never; the content type is valid.
        """
        self.requests += 1
        response.add_header("Content-Type", "application/json")
        response.write_text(STUB_BODY)


def start_stub() raises -> WorkerPool:
    """Start the stub endpoint in one worker process on a free port.

    Returns:
        The worker pool; its `port` is the endpoint's port.

    Raises:
        Error: If the worker does not start.
    """
    var config = ServerConfig()
    config.host = IPv4Address.LOOPBACK
    config.port = 0
    config.workers = 1
    return start_workers(Stub(0), config)


def write_operations(root: String) raises -> Int:
    """Split the operations fixture into one file for each operation.

    Args:
        root: The repository root, relative to the working directory.

    Returns:
        How many files the driver wrote.

    Raises:
        Error: If a file cannot be read or written.
    """
    var text: String
    with open(root + "/" + OPERATIONS_FIXTURE, "r") as file:
        text = file.read()
    var directory = root + "/" + BENCH_DIR + "/operations"
    makedirs(directory, exist_ok=True)
    var parts = text.split("\n\n")
    var count = 0
    for ref part in parts:
        var operation = String(String(part).strip())
        if operation.byte_length() == 0:
            continue
        count += 1
        var name = String(count)
        while name.byte_length() < 3:
            name = "0" + name
        with open(directory + "/" + name + ".graphql", "w") as file:
            file.write(operation, "\n")
    return count


def set_env(name: String, value: String):
    """Set an environment variable for the server command."""
    var key = name.copy()
    var text = value.copy()
    _ = external_call["setenv", Int32](
        key.as_c_string_span().ptr(),
        text.as_c_string_span().ptr(),
        Int32(1),
    )
    _ = key
    _ = text


struct Session(Movable):
    """A server process and the two pipes to it."""

    var pid: Int
    """The server's process id, which is also its process group."""
    var to_server: Int
    """The write end of the server's standard input."""
    var from_server: Int
    """The read end of the server's standard output."""
    var buffer: List[UInt8]
    """Bytes read and not yet consumed."""
    var start: Int
    """The first unconsumed byte of `buffer`."""
    var next_id: Int
    """The id of the next request."""

    def __init__(out self, command: String) raises:
        """Start `/bin/sh -c command` in its own process group.

        Args:
            command: The server command.

        Raises:
            Error: If the pipes or the process cannot be made.
        """
        var sys = Sys()
        var input = sys.pipe()
        var output = sys.pipe()
        if input[0] < 0 or output[0] < 0:
            raise Error("pipe failed")
        var shell = String("/bin/sh")
        var flag = String("-c")
        var cmd = command.copy()
        var pid = sys.fork()
        if pid == 0:
            _ = external_call["setpgid", Int32](Int32(0), Int32(0))
            _ = external_call["dup2", Int32](Int32(input[0]), Int32(0))
            _ = external_call["dup2", Int32](Int32(output[1]), Int32(1))
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
        sys.close(input[0])
        sys.close(output[1])
        self.pid = pid
        self.to_server = input[1]
        self.from_server = output[0]
        self.buffer = List[UInt8](capacity=1 << 22)
        self.start = 0
        self.next_id = 1

    def send(mut self, line: String) raises:
        """Write one message and its line break.

        Args:
            line: The JSON text of the message.

        Raises:
            Error: If the server closed its input.
        """
        var sys = Sys()
        var bytes = line.as_bytes()
        var done = 0
        while done < len(bytes):
            var n = sys.write(
                self.to_server,
                bytes.unsafe_ptr().unsafe_offset(done),
                len(bytes) - done,
            )
            if n <= 0:
                raise Error("the server closed its input")
            done += n
        var newline = List[UInt8](length=1, fill=10)
        if sys.write(self.to_server, newline.unsafe_ptr(), 1) != 1:
            raise Error("the server closed its input")

    def read_line(mut self) raises -> Tuple[Int, Int]:
        """Read up to the next line break.

        Returns:
            The start and the end of the line in `buffer`, without the line
            break; valid until the next read.

        Raises:
            Error: If the server closed its output.
        """
        var sys = Sys()
        var scanned = self.start
        while True:
            var end = len(self.buffer)
            if scanned < end:
                var base = Int(self.buffer.unsafe_ptr())
                var found = external_call["memchr", Int](
                    self.buffer.unsafe_ptr().unsafe_offset(scanned),
                    Int32(10),
                    end - scanned,
                )
                if found != 0:
                    var line_start = self.start
                    self.start = found - base + 1
                    return (line_start, found - base)
                scanned = end
            if self.start > 0:
                var rest = end - self.start
                var at = Int(self.buffer.unsafe_ptr())
                _ = external_call["memmove", Int](at, at + self.start, rest)
                self.buffer.resize(rest, 0)
                scanned -= self.start
                self.start = 0
            var old = len(self.buffer)
            self.buffer.resize(old + 65536, 0)
            var n = sys.read(
                self.from_server,
                self.buffer.unsafe_ptr().unsafe_offset(old),
                65536,
            )
            if n <= 0:
                raise Error("the server closed its output")
            self.buffer.resize(old + n, 0)

    def request(mut self, tail: StringSlice) raises -> Tuple[Int, Int]:
        """Send a request with the next id, and read its response.

        Lines without the id, such as notifications, are skipped.

        Args:
            tail: The request text after `"id":<n>,`.

        Returns:
            The start and the end of the response line in `buffer`.

        Raises:
            Error: If the server closed a pipe.
        """
        var id = String(self.next_id)
        self.next_id += 1
        self.send('{"jsonrpc":"2.0","id":' + id + "," + tail)
        var prefix = '{"jsonrpc":"2.0","id":' + id + ","
        var size = prefix.byte_length()
        while True:
            var line = self.read_line()
            if line[1] - line[0] >= size and (
                external_call["memcmp", Int32](
                    self.buffer.unsafe_ptr().unsafe_offset(line[0]),
                    prefix.unsafe_ptr(),
                    size,
                )
                == 0
            ):
                return line

    def text(self, line: Tuple[Int, Int]) -> String:
        """Return a line that `read_line` returned, as text.

        Args:
            line: The start and the end.

        Returns:
            The text.
        """
        return String(unsafe_from_utf8=Span(self.buffer)[line[0] : line[1]])

    def handshake(mut self) raises:
        """Send `initialize` and `notifications/initialized`.

        Raises:
            Error: If the server does not answer `initialize`.
        """
        self.send(INITIALIZE)
        var line = self.text(self.read_line())
        if not line.startswith('{"jsonrpc":"2.0","id":0,"result":'):
            raise Error("initialize failed: " + line)
        self.send(INITIALIZED)

    def run(mut self, tail: StringSlice, iterations: Int) raises -> Int:
        """Send a request `iterations` times, one at a time.

        Args:
            tail: The request text after the id.
            iterations: How many requests.

        Returns:
            The elapsed nanoseconds.

        Raises:
            Error: If the server closed a pipe.
        """
        var start = perf_counter_ns()
        for _ in range(iterations):
            _ = self.request(tail)
        return Int(perf_counter_ns() - start)

    def stop(mut self):
        """Close the server's input, and end its process group."""
        var sys = Sys()
        sys.close(self.to_server)
        sys.close(self.from_server)
        var deadline = Int(perf_counter_ns()) + 3_000_000_000
        while Int(perf_counter_ns()) < deadline:
            var result = sys.wait(self.pid, False)
            if result[0] != 0:
                _ = sys.kill(-self.pid, SIGKILL)
                return
            _ = sys.poll(-1, 0, 10)
        _ = sys.kill(-self.pid, SIGTERM)
        _ = sys.poll(-1, 0, 100)
        _ = sys.kill(-self.pid, SIGKILL)
        _ = sys.wait(self.pid, True)


def measure(name: StaticString, mut session: Session, tail: StringSlice) raises:
    """Time one workload and print its `BENCH` line.

    Args:
        name: The workload.
        session: The server.
        tail: The request text after the id.

    Raises:
        Error: If the server closed a pipe.
    """
    var iterations = 1
    while True:
        var elapsed = session.run(tail, iterations)
        if elapsed >= WARMUP_NS:
            var per_op = max(elapsed // iterations, 1)
            iterations = max(ROUND_NS // per_op, 1)
            break
        iterations *= 2
    var best = Float64(1e300)
    for _ in range(ROUNDS):
        var elapsed = session.run(tail, iterations)
        best = min(best, Float64(elapsed) / Float64(iterations))
    print("BENCH", name, Float64(Int(best * 10.0)) / 10.0)


def run_server_workloads(command: String, root: String) raises:
    """Prepare the fixtures, start the stub and the server, check the
    answers, and time each workload.

    Args:
        command: The server command.
        root: The repository root, relative to the working directory.

    Raises:
        Error: If a check fails or a process fails.
    """
    var count = write_operations(root)
    if count != 200:
        raise Error("expected 200 operations, found " + String(count))
    var stub = start_stub()
    set_env("MCP_BENCH_ROOT", root)
    set_env("MCP_BENCH_DIR", root + "/" + BENCH_DIR)
    set_env(
        "APOLLO_MCP_ENDPOINT",
        "http://127.0.0.1:" + String(stub.port) + "/graphql",
    )
    var session = Session(command)
    try:
        session.handshake()
        var listed = session.text(session.request(TOOLS_LIST))
        var tools = listed.count('"inputSchema":')
        if tools != TOOL_COUNT:
            raise Error("tools/list returned " + String(tools) + " tools")
        var called = session.text(session.request(CALL))
        if not ('"isError":false' in called and "apollo-mcp-server" in called):
            raise Error("tools/call failed: " + called)
        if getenv("MCP_BENCH_SHOW") != "":
            print("CALL", called)
        var tails: List[String] = [
            String(SEARCH),
            String(INTROSPECT),
            String(VALIDATE),
        ]
        var index = 0
        while index < len(tails):
            var answer = session.text(session.request(tails[index]))
            if not '"isError":false' in answer:
                raise Error("tools/call failed: " + answer)
            if getenv("MCP_BENCH_SHOW") != "":
                print("CALL", answer)
            index += 1
        measure("mcp/tools-list-200", session, TOOLS_LIST)
        measure("mcp/call-operation", session, CALL)
        measure("mcp/call-search", session, SEARCH)
        measure("mcp/call-introspect", session, INTROSPECT)
        measure("mcp/call-validate", session, VALIDATE)
    except e:
        session.stop()
        _ = stub.stop(1000)
        raise e^
    session.stop()
    _ = stub.stop(3000)


def main() raises:
    """Run the server workloads against a server command."""
    var args = argv()
    var root = String(".")
    var first = 1
    if len(args) > 2 and String(args[1]) == "--root":
        root = String(args[2])
        first = 3
    if len(args) <= first:
        raise Error("usage: mcp_driver [--root <dir>] <server command>")
    var command = String(args[first])
    for k in range(first + 1, len(args)):
        command += " " + String(args[k])
    run_server_workloads(command, root)

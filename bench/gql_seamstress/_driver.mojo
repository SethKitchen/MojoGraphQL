# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The process driver of the gql_seamstress introspection benchmarks.

Every introspection workload, the Mojo one and the Rover baseline, runs
under this program, so that only the program differs: `seamstress` or `rover`. The driver:

1. starts a stub GraphQL endpoint, a gql_http worker: `/graph` answers
   with the full introspection result of
   `bench/fixtures/github-schema.graphql`, the GitHub schema of graphql-js
   `benchmark/`, and `/subgraph` answers
   `_service { sdl }` with `bench/fixtures/subgraph-catalog.graphql`;
2. sets `APOLLO_TELEMETRY_DISABLED` and `APOLLO_ROVER_SKIP_UPDATE`, so that
   Rover does not reach the network;
3. times each workload: one run of the program, from `fork` to its exit,
   with its output sent to `/dev/null`. The method is the one of every
   benchmark: a warm-up of at least 200 ms, then the fastest of 5 rounds
   of at least one second each.

Workloads:

- `seamstress/graph-introspect-github`: `<program> graph introspect <url>/graph`.
- `seamstress/subgraph-introspect-catalog`: `<program> subgraph introspect
  <url>/subgraph`.

As a program, it takes the program and the repository root:

    .cache/bin/seamstress_driver <program> [<root>]
"""

from std.ffi import external_call
from std.sys import argv
from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter, ServerConfig, WorkerPool
from gql_http.server import start_workers
from gql_http.socket import IPv4Address, Sys
from gql_http.status import Status
from gql_execution.introspection import introspection_from_schema
from gql_json.writer import JsonWriter, stringify
from gql_schema.build import build_schema
from _harness import Workload, measure


def _read(path: String) raises -> String:
    """Read a whole file."""
    with open(path, "r") as file:
        return file.read()


struct BenchEndpoint(Handler):
    """Answers `/graph` and `/subgraph` with fixed responses."""

    var graph: String
    """The introspection response of the GitHub schema."""
    var subgraph: String
    """The `_service { sdl }` response."""

    def __init__(out self, root: String) raises:
        """Read the fixtures under a repository root.

        Args:
            root: The repository root.

        Raises:
            Error: If a fixture cannot be read.
        """
        var result = introspection_from_schema(
            build_schema(_read(root + "/bench/fixtures/github-schema.graphql"))
        )
        self.graph = '{"data":' + stringify(result, result.root) + "}"
        var writer = JsonWriter()
        writer.begin_object()
        writer.key("data")
        writer.begin_object()
        writer.key("_service")
        writer.begin_object()
        writer.key("sdl")
        writer.string(_read(root + "/bench/fixtures/subgraph-catalog.graphql"))
        writer.end_object()
        writer.end_object()
        writer.end_object()
        self.subgraph = writer^.take_string()

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        """Answer one request.

        Args:
            request: The request.
            response: The response writer.

        Raises:
            Error: If the response cannot be written.
        """
        if request.path() == "/graph":
            response.send(Status.OK, "application/json", self.graph)
        else:
            response.send(Status.OK, "application/json", self.subgraph)


def set_env(name: String, value: String):
    """Set an environment variable for the programs that the driver runs.

    Args:
        name: The variable.
        value: Its value.
    """
    var key = name.copy()
    var text = value.copy()
    _ = external_call["setenv", Int32](
        key.as_c_string_span().ptr(),
        text.as_c_string_span().ptr(),
        Int32(1),
    )
    _ = key
    _ = text


struct Spawn(Workload):
    """One run of a program, with its output sent to `/dev/null`."""

    var args: List[String]
    """The program and its arguments."""

    def __init__(out self, var args: List[String]):
        """Make the workload.

        Args:
            args: The program and its arguments.
        """
        self.args = args^

    def run(mut self) raises -> Int:
        """Run the program once and wait for it.

        Returns:
            1.

        Raises:
            Error: If the program cannot start, or exits with a non-zero
                status.
        """
        var sys = Sys()
        var null = String("/dev/null")
        var pointers = List[Int]()
        for ref arg in self.args:
            pointers.append(Int(arg.as_c_string_span().ptr()))
        pointers.append(0)
        var pid = sys.fork()
        if pid == 0:
            var fd = external_call["creat", Int32](
                null.as_c_string_span().ptr(), UInt32(0o644)
            )
            _ = external_call["dup2", Int32](fd, Int32(1))
            _ = external_call["dup2", Int32](fd, Int32(2))
            _ = external_call["execv", Int32](
                self.args[0].as_c_string_span().ptr(), pointers.unsafe_ptr()
            )
            sys.exit_now(127)
        _ = null
        var waited = sys.wait(pid, True)
        if waited[1] != 0:
            raise Error(
                self.args[0] + " exited with status " + String(waited[1])
            )
        return 1


def run_process_workloads(program: String, root: String) raises:
    """Time the introspection workloads of a program: `seamstress` or `rover`.

    Args:
        program: The path of the program: `seamstress` or `rover`.
        root: The repository root.

    Raises:
        Error: If the endpoint cannot start, or a run fails.
    """
    set_env("APOLLO_TELEMETRY_DISABLED", "1")
    set_env("APOLLO_ROVER_SKIP_UPDATE", "1")
    var config = ServerConfig()
    config.host = IPv4Address.LOOPBACK
    config.port = 0
    var pool = start_workers(BenchEndpoint(root), config)
    var base = "http://127.0.0.1:" + String(pool.port)
    measure(
        "seamstress/graph-introspect-github",
        Spawn([program, "graph", "introspect", base + "/graph"]),
    )
    measure(
        "seamstress/subgraph-introspect-catalog",
        Spawn([program, "subgraph", "introspect", base + "/subgraph"]),
    )
    _ = pool.stop()


def main() raises:
    """Time the workloads of the program named by the first
    argument."""
    var args = argv()
    var root = String(args[2]) if len(args) > 2 else String(".")
    run_process_workloads(String(args[1]), root)

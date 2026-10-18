# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Time the gql_seamstress commands.

    mojo build -I . -o .cache/bin/seamstress_bench bench/gql_seamstress/seamstress.mojo
    .cache/bin/seamstress_bench

Workloads:

- `seamstress/supergraph-compose-stars-stuff`: `supergraph compose` of a
  configuration that names the five subgraph files of the Hive fixture
  `__tests__/fixtures/stars-stuff.ts` (`bench/fixtures/hive-stars-stuff`):
  read the YAML, read and parse each file, compose, and print. The
  baseline in `bench/baselines/js-seamstress` reads and parses the same files
  and runs Hive `composeServices`. The Elastic licensed `supergraph`
  plugin of Rover is never run.
- `seamstress/graph-introspect-github` and `seamstress/subgraph-introspect-catalog`:
  one run of the `seamstress` program of `_seamstress.mojo`, under the process
  driver of `_driver.mojo`. The baseline in `bench/baselines/rust-seamstress`
  runs the release build of Rover 1.0.0 under the same driver.
"""

from std.os import makedirs
from std.subprocess import run
from gql_seamstress.compose import supergraph_compose
from _driver import run_process_workloads
from _harness import Workload, measure

comptime PROGRAM = ".cache/bin/gql_seamstress"
"""The `seamstress` program."""

comptime SCRATCH = "/tmp/gql-seamstress-bench"
"""Where the workloads keep their files. The repository can be on a slow
file system, such as a Windows drive under WSL, and Rover is on the Linux
file system, so the program and the fixture copies are put here."""

comptime STARS = ["inventory", "pandas", "products", "reviews", "users"]
"""The subgraphs of the `stars-stuff` fixture."""


struct Compose(Workload):
    """`supergraph compose` of one configuration file."""

    var path: String
    """The configuration file."""

    def __init__(out self, path: String):
        """Make the workload.

        Args:
            path: The configuration file.
        """
        self.path = path

    def run(mut self) raises -> Int:
        """Compose once.

        Returns:
            The length of the supergraph SDL.

        Raises:
            Error: If the composition fails.
        """
        var result = supergraph_compose(self.path, None, None)
        if result.error:
            raise Error(result.error.value().text())
        return result.text.byte_length()


def _stars_config() raises -> String:
    """Write the configuration of the `stars-stuff` subgraphs."""
    var directory = String(SCRATCH)
    makedirs(directory, exist_ok=True)
    var text = String("federation_version: =2.3.0\nsubgraphs:\n")
    for name in materialize[STARS]():
        text += "  " + name + ":\n    routing_url: http://" + name
        text += ".example.com/graphql\n    schema:\n      file: "
        var source = "bench/fixtures/hive-stars-stuff/" + name + ".graphql"
        var sdl: String
        with open(source, "r") as file:
            sdl = file.read()
        with open(directory + "/" + name + ".graphql", "w") as file:
            file.write(sdl)
        text += "./" + name + ".graphql\n"
    var path = directory + "/stars-stuff.yaml"
    with open(path, "w") as file:
        file.write(text)
    return path


def main() raises:
    """Build the `seamstress` program, and run the workloads."""
    measure(
        "seamstress/supergraph-compose-stars-stuff", Compose(_stars_config())
    )
    var built = run(
        "mkdir -p .cache/bin && .venv/bin/mojo build -I . -o "
        + PROGRAM
        + " bench/gql_seamstress/_seamstress.mojo > /dev/null 2>&1 && cp "
        + PROGRAM
        + " "
        + SCRATCH
        + "/seamstress; echo __rc=$?"
    )
    if not "__rc=0" in built:
        raise Error("building bench/gql_seamstress/_seamstress.mojo failed")
    run_process_workloads(SCRATCH + "/seamstress", ".")

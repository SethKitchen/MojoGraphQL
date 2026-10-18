# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The `seamstress` program: the offline commands of Apollo Rover.

    mojo build -I . -o seamstress bench/gql_seamstress/_seamstress.mojo
    ./seamstress supergraph compose --config supergraph.yaml

It passes its arguments to `gql_seamstress.cli.run_seamstress`, writes the
standard output and the standard error that it returns, and exits with its
code.
With `--config -`, it reads the configuration from standard input.
"""

from std.sys import argv, exit, stderr
from gql_seamstress.cli import run_seamstress


def _read_stdin() raises -> String:
    """Read all of standard input."""
    with open("/dev/stdin", "r") as file:
        return file.read()


def main() raises:
    """Run one Rover command line."""
    var args = List[String]()
    var raw = argv()
    for index in range(1, len(raw)):
        args.append(String(raw[index]))
    var stdin = Optional[String](None)
    for index in range(len(args)):
        if args[index] == "-" or args[index] == "--config=-":
            stdin = _read_stdin()
    var result = run_seamstress(args, stdin)
    print(result.stdout, end="")
    print(result.stderr, end="", file=stderr)
    if result.exit_code != 0:
        exit(result.exit_code)

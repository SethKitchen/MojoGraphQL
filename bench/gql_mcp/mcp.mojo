# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Time the gql_mcp server over stdio, under the driver of `_driver.mojo`.

    mojo build -I . -o .cache/bin/mcp bench/gql_mcp/mcp.mojo
    .cache/bin/mcp

The program builds `_server.mojo`, the gql_mcp server with the
configuration of `bench/baselines/rust-mcp/config.yaml`, into
`.cache/bin/mcp_server`. Then it runs the workloads of `_driver.mojo`
against that server: `mcp/tools-list-200` and `mcp/call-operation`. The
baseline in `bench/baselines/rust-mcp` runs Apollo MCP Server under the
same driver, so that only the server differs.
"""

from std.subprocess import run

from _driver import run_server_workloads

comptime SERVER = ".cache/bin/mcp_server"
"""The server program."""


def main() raises:
    """Build the server, and run the server workloads."""
    var built = run(
        "mkdir -p .cache/bin && .venv/bin/mojo build -I . -o "
        + SERVER
        + " bench/gql_mcp/_server.mojo > /dev/null 2>&1; echo __rc=$?"
    )
    if not "__rc=0" in built:
        raise Error("building bench/gql_mcp/_server.mojo failed")
    run_server_workloads(SERVER, ".")

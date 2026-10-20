# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The router of the Apollo Federation subgraph compatibility suite
(f9520a4, MIT): the Mojo counterpart of the Apollo Router that the suite
starts with `rover dev` or `docker compose`.

`gql_seamstress` composes the supergraph from a Rover `supergraph.yaml`,
as `seamstress supergraph compose --config <FILE>` does. `gql_router`
serves the supergraph over HTTP on `/`, the URL `http://localhost:4000/`
of the jest tests. Set these environment variables:

- `SUPERGRAPH_CONFIG`: the `supergraph.yaml` to compose. It is required.
- `SUPERGRAPH_OUT`: a file that receives the supergraph SDL. It is optional.
- `ROUTER_PORT`: the port, 4000 by default.

Run it from the repository root:

    SUPERGRAPH_CONFIG=supergraph.yaml .venv/bin/mojo run -I . bench/compat/router.mojo

`run_official.sh` starts it with the three subgraphs.
"""

from std.os import getenv

from gql_http.server import ServerConfig, start_workers
from gql_router.exec_http import HttpTransport
from gql_router.pipeline import Router, RouterSchema
from gql_router.router_server import RouterHandler
from gql_seamstress.cli import run_seamstress


def compose(config_path: String) raises -> String:
    """Compose the supergraph of a `supergraph.yaml`.

    Args:
        config_path: The path of the configuration.

    Returns:
        The supergraph SDL.

    Raises:
        Error: When the composition fails, with the seamstress error.
    """
    var result = run_seamstress(
        ["supergraph", "compose", "--config", config_path]
    )
    if result.exit_code != 0:
        raise Error("composition failed:\n" + result.stderr + result.stdout)
    return result.stdout


def main() raises:
    """Compose the supergraph and serve it until the process is stopped."""
    var config_path = getenv("SUPERGRAPH_CONFIG")
    if config_path.byte_length() == 0:
        raise Error("set SUPERGRAPH_CONFIG to the supergraph.yaml")
    var sdl = compose(config_path)
    var out_path = getenv("SUPERGRAPH_OUT")
    if out_path.byte_length() > 0:
        with open(out_path, "w") as file:
            file.write(sdl)
    var schema = RouterSchema(sdl)
    var transport = HttpTransport(
        schema.subgraph_names.copy(), schema.subgraph_urls.copy()
    )
    var router = Router(schema^, transport^)
    var config = ServerConfig()
    config.port = Int(getenv("ROUTER_PORT", "4000"))
    var pool = start_workers(RouterHandler(router^, "/"), config)
    print(
        "Router ready at http://localhost:" + String(pool.port) + "/",
        flush=True,
    )
    _ = pool.wait()

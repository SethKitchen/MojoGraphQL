# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The `forge` program: observe supergraphs that you already host.

    make forge
    dist/forge --advertise-ip 203.0.113.10 --token "$(openssl rand -hex 16)"
"""

from std.sys import argv, exit, stderr

from gql_forge.cli import USAGE, VERSION, forge_config, parse_cli, parse_host
from gql_forge.server import Forge, serve_forge
from gql_http.server import ServerConfig
from gql_http.socket import IPv4Address


def main() raises:
    """Run Forge from the command line.

    Raises:
        Error: When the server cannot start.
    """
    var args = List[String]()
    var all = argv()
    var index = 1
    while index < len(all):
        args.append(String(all[index]))
        index += 1
    var options = parse_cli(args)
    if options.help:
        print(USAGE)
        return
    if options.version:
        print(VERSION)
        return
    if options.error.byte_length() > 0:
        print(options.error, file=stderr)
        print(USAGE, file=stderr)
        exit(2)
    var host = parse_host(options.host)
    if not host:
        print("Invalid host '" + options.host + "'.", file=stderr)
        exit(2)
    var http = ServerConfig()
    http.host = host.value()
    http.port = options.port
    http.workers = options.workers
    var config = forge_config(options)
    var token = config.admin_token.value().copy()
    var forge = Forge(config^)
    print("Forge on http://" + options.host + ":" + String(options.port) + "/")
    if options.host == "0.0.0.0":
        print(
            "   Listening on every interface; use this machine's IP address"
            " from other machines."
        )
    print("   Catalog:   " + options.data_directory)
    print("   Forge does not host graphs. Register a URL on the Connect page.")
    if not options.token:
        print("   Admin token: " + token)
        print(
            "   Forge made this token because no --token or FORGE_TOKEN is"
            " set. Enter it on the site."
        )
    serve_forge(forge^, http)

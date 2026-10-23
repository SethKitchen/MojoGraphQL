# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The command line of the `forge` program.

    forge [--data DIR] [--host ADDRESS] [--port PORT] [--workers N]
          [--title TEXT] [--token TOKEN] [--advertise-ip IP]
          [--pull-timeout MS]

`parse_cli` reads the arguments into `CliOptions`. `forge_config` makes
the `ForgeConfig` of `serve`.

A flag can also be written as `--flag=value`. `FORGE_TOKEN` is the default
of `--token`.

Differences from upstream: none; there is no upstream.
"""

from std.os import getenv

from gql_forge.server import ForgeConfig
from gql_http.socket import IPv4Address

comptime VERSION = "forge 0.1.0"
"""The text of `forge --version`."""

comptime USAGE = """Forge: observe supergraphs that you already host.

Usage:
  forge [OPTIONS]

The default start runs only the control plane. It starts no graph.
Register the ScorchQL or router URL that you already run. Allowlist the
Forge IP, or upload SDL.

Options:
  --data <DIR>           The catalog directory [default: .forge]
  --host <ADDRESS>       The IPv4 address to listen on [default: 0.0.0.0]
  --port <PORT>          The port [default: 4100]
  --workers <N>          The worker processes [default: 1]
  --title <TEXT>         The name in the site [default: Forge]
  --token <TOKEN>        Require 'Authorization: Bearer <TOKEN>'
  --advertise-ip <IP>    The IP that customers allowlist
  --pull-timeout <MS>    The schema pull deadline [default: 5000]
  --help                 Show this text
  --version, -V          Show the version

FORGE_TOKEN is the default of --token.
"""
"""The text of `forge --help`."""


@fieldwise_init
struct CliOptions(Copyable, Movable):
    """The parsed command line."""

    var help: Bool
    """Whether `--help` was set."""
    var version: Bool
    """Whether `--version` was set."""
    var error: String
    """Why parse failed. Empty when it succeeded."""
    var data_directory: String
    """The catalog directory."""
    var host: String
    """The listen address text."""
    var port: Int
    """The listen port."""
    var workers: Int
    """The worker processes."""
    var title: String
    """The site title."""
    var token: Optional[String]
    """The admin token, if any."""
    var advertise_ip: String
    """The IP that customers allowlist."""
    var pull_timeout_ms: Int
    """The schema pull deadline."""


def default_options() -> CliOptions:
    """Return the default options.

    Returns:
        The defaults.
    """
    var token = Optional[String]()
    var env = getenv("FORGE_TOKEN", "")
    if env.byte_length() > 0:
        token = env
    return CliOptions(
        False,
        False,
        String(""),
        String(".forge"),
        String("0.0.0.0"),
        4100,
        1,
        String("Forge"),
        token^,
        String(""),
        5000,
    )


def _split_flag(arg: StringSlice) -> Tuple[String, Optional[String]]:
    """Split `--flag=value` or return the flag alone.

    Args:
        arg: One argument.

    Returns:
        The flag and an optional attached value.
    """
    var text = String(arg)
    var eq = text.find("=")
    if eq < 0:
        return (text, None)
    return (String(text[byte=:eq]), String(text[byte = eq + 1 :]))


def parse_cli(args: List[String]) -> CliOptions:
    """Read command-line arguments.

    Args:
        args: The arguments, without the program name.

    Returns:
        The options. `error` is set when a flag is unknown or a value is
        missing.
    """
    var options = default_options()
    var index = 0
    while index < len(args):
        var split = _split_flag(args[index])
        var flag = split[0]
        var attached = split[1]
        if flag == "--help" or flag == "-h":
            options.help = True
            index += 1
            continue
        if flag == "--version" or flag == "-V":
            options.version = True
            index += 1
            continue
        if not flag.startswith("--"):
            options.error = "Unknown argument '" + flag + "'."
            return options^
        var value: String
        if attached:
            value = attached.value().copy()
            index += 1
        else:
            if index + 1 >= len(args):
                options.error = "Missing value for " + flag + "."
                return options^
            value = args[index + 1].copy()
            index += 2
        if flag == "--data":
            options.data_directory = value^
        elif flag == "--host":
            options.host = value^
        elif flag == "--port":
            try:
                options.port = atol(value)
            except:
                options.error = "Invalid port '" + value + "'."
                return options^
        elif flag == "--workers":
            try:
                options.workers = atol(value)
            except:
                options.error = "Invalid workers '" + value + "'."
                return options^
        elif flag == "--title":
            options.title = value^
        elif flag == "--token":
            options.token = value^
        elif flag == "--advertise-ip":
            options.advertise_ip = value^
        elif flag == "--pull-timeout":
            try:
                options.pull_timeout_ms = atol(value)
            except:
                options.error = "Invalid pull timeout '" + value + "'."
                return options^
        else:
            options.error = "Unknown flag '" + flag + "'."
            return options^
    return options^


def parse_host(text: StringSlice) -> Optional[IPv4Address]:
    """Read an IPv4 address.

    Args:
        text: Dotted decimal, such as `0.0.0.0`.

    Returns:
        The address, or none when the text is not an IPv4 address.
    """
    return IPv4Address.parse(text)


def forge_config(options: CliOptions) -> ForgeConfig:
    """Make the Forge configuration of parsed options.

    Args:
        options: The options.

    Returns:
        The configuration.
    """
    var config = ForgeConfig()
    config.title = options.title.copy()
    config.data_directory = options.data_directory.copy()
    config.advertise_ip = options.advertise_ip.copy()
    config.admin_token = None
    if options.token:
        config.admin_token = options.token.value().copy()
    config.pull_timeout_ms = options.pull_timeout_ms
    config.http_port = options.port
    return config^

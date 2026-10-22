# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The command line of the `scorchql` program.

    scorchql [serve] [--registry DIR | --supergraph FILE] [--config YAML]
             [--host ADDRESS] [--port PORT] [--workers N] [--path PATH]
             [--title TEXT] [--token TOKEN] [--poll SECONDS]
             [--subscriptions ws|http|off]
             [--tls-cert FILE --tls-key FILE] [--https-port PORT] [--h3 on|off]
    scorchql publish --gateway URL --name NAME --url URL [--schema FILE]
             [--token TOKEN]
    scorchql remove --gateway URL --name NAME [--token TOKEN]
    scorchql refresh --gateway URL [--token TOKEN]

`parse_cli` reads the arguments into `CliOptions`. `gateway_config` makes
the `GatewayConfig` of `serve`. `admin_request` makes the HTTP request of
`publish`, `remove` and `refresh`, and `send_admin` sends it.

A flag can also be written as `--flag=value`. `SCORCHQL_TOKEN` is the
default of `--token`.

Differences from upstream: none; there is no upstream. `publish` takes
the options of `rover subgraph publish`: a name, a routing URL and an
optional schema file.
"""

from std.os import getenv

from gql_composition.printer import json_string
from gql_http.client import Client
from gql_http.headers import Headers
from gql_http.socket import IPv4Address
from gql_http.status import Method
from gql_scorchql.gateway import GatewayConfig
from gql_scorchql.registry import read_file

comptime VERSION = "scorchql 0.1.0"
"""The text of `scorchql --version`."""

comptime USAGE = """ScorchQL: a federated GraphQL gateway with an explorer.

Usage:
  scorchql [serve] [OPTIONS]      Serve the gateway and the explorer
  scorchql publish [OPTIONS]      Publish a subgraph to a running gateway
  scorchql remove [OPTIONS]       Remove a subgraph from a running gateway
  scorchql refresh [OPTIONS]      Read the SDL of each subgraph again

Serve options:
  --registry <DIR>       The registry directory [default: .scorchql]
  --supergraph <FILE>    Serve a fixed supergraph SDL, without a registry
  --config <YAML>        Publish the subgraphs of a supergraph.yaml at start
  --host <ADDRESS>       The IPv4 address to listen on [default: 0.0.0.0]
  --port <PORT>          The port [default: 4000]
  --workers <N>          The worker processes [default: 1]
  --path <PATH>          The GraphQL path [default: /graphql]
  --title <TEXT>         The name in the explorer [default: ScorchQL]
  --token <TOKEN>        Require 'Authorization: Bearer <TOKEN>' to publish
  --poll <SECONDS>       Read the SDL of each subgraph again this often;
                         0 turns it off [default: 10]
  --subscriptions <MODE> Subgraph subscription transport: ws, http or
                         off [default: ws]
  --tls-cert <FILE>      A PEM certificate chain: also serve HTTPS with h2
  --tls-key <FILE>       The PEM private key of --tls-cert
  --https-port <PORT>    The TCP port of HTTPS, and the UDP port of
                         HTTP/3 [default: 4443]
  --h3 <on|off>          Serve HTTP/3 next to HTTPS [default: on]

Publish, remove and refresh options:
  --gateway <URL>        The gateway, such as http://localhost:4000
  --name <NAME>          The subgraph name
  --url <URL>            The routing URL of the subgraph
  --schema <FILE>        The subgraph SDL; without it, the gateway reads
                         the SDL from the subgraph
  --token <TOKEN>        The publish token of the gateway

SCORCHQL_TOKEN is the default of --token.
"""
"""The text of `scorchql --help`."""


struct CommandKind(Equatable, ImplicitlyCopyable, Writable):
    """The command of a `scorchql` command line."""

    var value: UInt8
    """The command, as a number; see `is_valid`."""

    comptime SERVE = CommandKind(0)
    """Serve the gateway."""
    comptime PUBLISH = CommandKind(1)
    """Publish a subgraph to a gateway."""
    comptime REMOVE = CommandKind(2)
    """Remove a subgraph from a gateway."""
    comptime REFRESH = CommandKind(3)
    """Read the SDL of each subgraph again."""
    comptime HELP = CommandKind(4)
    """Print the usage."""
    comptime VERSION = CommandKind(5)
    """Print the version."""

    @implicit
    def __init__(out self, value: UInt8):
        """Make a command from its number.

        Args:
            value: The number.
        """
        self.value = value

    def is_valid(self) -> Bool:
        """Return True for one of the named commands.

        Returns:
            Whether the value is from `SERVE` to `VERSION`.
        """
        return self.value <= 5

    def __eq__(self, other: Self) -> Bool:
        """Compare two commands.

        Args:
            other: The other command.

        Returns:
            Whether they are the same command.
        """
        return self.value == other.value

    def write_to(self, mut writer: Some[Writer]):
        """Write the command name.

        Args:
            writer: The writer.
        """
        var names: List[StaticString] = [
            "serve",
            "publish",
            "remove",
            "refresh",
            "help",
            "version",
        ]
        writer.write(names[Int(self.value)] if self.is_valid() else "invalid")


struct SubscriptionMode(Equatable, ImplicitlyCopyable, Writable):
    """How the gateway runs subscriptions against subgraphs."""

    var value: UInt8
    """The mode, as a number; see `is_valid`."""

    comptime WS = SubscriptionMode(0)
    """Subgraph subscriptions use `graphql-transport-ws` over WebSocket."""
    comptime HTTP = SubscriptionMode(1)
    """Subgraph subscriptions use HTTP streaming: SSE or multipart HTTP."""
    comptime OFF = SubscriptionMode(2)
    """Subscriptions are disabled."""

    @implicit
    def __init__(out self, value: UInt8):
        """Make a mode from its number.

        Args:
            value: The number.
        """
        self.value = value

    def is_valid(self) -> Bool:
        """Return True for one of the three modes.

        Returns:
            Whether the value is `WS`, `HTTP` or `OFF`.
        """
        return self.value <= 2

    def __eq__(self, other: Self) -> Bool:
        """Compare two modes.

        Args:
            other: The other mode.

        Returns:
            Whether they are the same mode.
        """
        return self.value == other.value

    def write_to(self, mut writer: Some[Writer]):
        """Write the mode name.

        Args:
            writer: The writer.
        """
        var names: List[StaticString] = ["ws", "http", "off"]
        writer.write(names[Int(self.value)] if self.is_valid() else "invalid")


struct CliOptions(Copyable, Movable):
    """The options of one command line."""

    var command: CommandKind
    """The command."""
    var registry: String
    """`--registry`."""
    var supergraph: Optional[String]
    """`--supergraph`."""
    var config: Optional[String]
    """`--config`."""
    var host: IPv4Address
    """`--host`."""
    var host_text: String
    """`--host`, as it was written."""
    var port: Int
    """`--port`."""
    var workers: Int
    """`--workers`."""
    var path: String
    """`--path`."""
    var title: String
    """`--title`."""
    var token: Optional[String]
    """`--token`, or `SCORCHQL_TOKEN`."""
    var poll_seconds: Int
    """`--poll`."""
    var subscriptions: SubscriptionMode
    """`--subscriptions`."""
    var tls_cert: Optional[String]
    """`--tls-cert`."""
    var tls_key: Optional[String]
    """`--tls-key`."""
    var https_port: Int
    """`--https-port`."""
    var h3: Bool
    """`--h3`."""
    var gateway: String
    """`--gateway`."""
    var name: String
    """`--name`."""
    var url: String
    """`--url`."""
    var schema: Optional[String]
    """`--schema`."""

    def __init__(out self):
        """Make the defaults of `serve`."""
        self.command = CommandKind.SERVE
        self.registry = ".scorchql"
        self.supergraph = None
        self.config = None
        self.host = IPv4Address.ANY
        self.host_text = "0.0.0.0"
        self.port = 4000
        self.workers = 1
        self.path = "/graphql"
        self.title = "ScorchQL"
        self.token = None
        self.poll_seconds = 10
        self.subscriptions = SubscriptionMode.WS
        self.tls_cert = None
        self.tls_key = None
        self.https_port = 4443
        self.h3 = True
        self.gateway = ""
        self.name = ""
        self.url = ""
        self.schema = None


def _number(flag: String, text: String, low: Int, high: Int) raises -> Int:
    """Read a decimal flag value in a range."""
    var value: Int
    try:
        value = atol(text)
    except:
        raise Error("invalid value '" + text + "' for '" + flag + "'")
    if value < low or value > high:
        raise Error(
            "'"
            + flag
            + "' must be from "
            + String(low)
            + " to "
            + String(high)
            + ", not "
            + text
        )
    return value


def parse_cli(args: List[String]) raises -> CliOptions:
    """Read a command line.

    Args:
        args: The arguments, without the program name.

    Returns:
        The options.

    Raises:
        Error: For an unknown command or flag, a flag without a value, a
            bad value, or a missing required flag. The message names the
            problem.
    """
    var options = CliOptions()
    var token = getenv("SCORCHQL_TOKEN", "")
    if token != "":
        options.token = token
    var index = 0
    if len(args) > 0 and not args[0].startswith("-"):
        var word = args[0]
        if word == "serve":
            options.command = CommandKind.SERVE
        elif word == "publish":
            options.command = CommandKind.PUBLISH
        elif word == "remove":
            options.command = CommandKind.REMOVE
        elif word == "refresh":
            options.command = CommandKind.REFRESH
        elif word == "help":
            options.command = CommandKind.HELP
        else:
            raise Error("unknown command '" + word + "'")
        index = 1
    while index < len(args):
        var arg = args[index]
        index += 1
        if arg == "--help" or arg == "-h":
            options.command = CommandKind.HELP
            return options^
        if arg == "--version" or arg == "-V":
            options.command = CommandKind.VERSION
            return options^
        if not arg.startswith("--"):
            raise Error("unexpected argument '" + arg + "'")
        var flag = arg
        var value: String
        var equals = arg.find("=")
        if equals > 0:
            flag = String(arg[byte=:equals])
            value = String(arg[byte = equals + 1 :])
        else:
            if index >= len(args):
                raise Error("'" + arg + "' needs a value")
            value = args[index]
            index += 1
        var serve = options.command == CommandKind.SERVE
        var admin = not serve
        if flag == "--token":
            options.token = value
        elif serve and flag == "--registry":
            options.registry = value
        elif serve and flag == "--supergraph":
            options.supergraph = value
        elif serve and flag == "--config":
            options.config = value
        elif serve and flag == "--host":
            var host = IPv4Address.parse(value)
            if not host:
                raise Error("invalid IPv4 address '" + value + "' for '--host'")
            options.host = host.value()
            options.host_text = value
        elif serve and flag == "--port":
            options.port = _number(flag, value, 0, 65535)
        elif serve and flag == "--workers":
            options.workers = _number(flag, value, 1, 256)
        elif serve and flag == "--path":
            if not value.startswith("/"):
                raise Error("'--path' must start with '/'")
            options.path = value
        elif serve and flag == "--title":
            options.title = value
        elif serve and flag == "--poll":
            options.poll_seconds = _number(flag, value, 0, 86400)
        elif serve and flag == "--subscriptions":
            if value == "ws":
                options.subscriptions = SubscriptionMode.WS
            elif value == "http":
                options.subscriptions = SubscriptionMode.HTTP
            elif value == "off":
                options.subscriptions = SubscriptionMode.OFF
            else:
                raise Error(
                    "'--subscriptions' must be 'ws', 'http' or 'off', not '"
                    + value
                    + "'"
                )
        elif serve and flag == "--tls-cert":
            options.tls_cert = value
        elif serve and flag == "--tls-key":
            options.tls_key = value
        elif serve and flag == "--https-port":
            options.https_port = _number(flag, value, 1, 65535)
        elif serve and flag == "--h3":
            if value == "on":
                options.h3 = True
            elif value == "off":
                options.h3 = False
            else:
                raise Error("'--h3' must be 'on' or 'off', not '" + value + "'")
        elif admin and flag == "--gateway":
            options.gateway = value
        elif admin and flag == "--name":
            options.name = value
        elif admin and flag == "--url":
            options.url = value
        elif admin and flag == "--schema":
            options.schema = value
        else:
            raise Error(
                "unknown option '"
                + flag
                + "' for '"
                + String(options.command)
                + "'"
            )
    if options.command == CommandKind.SERVE:
        if options.supergraph and options.config:
            raise Error("'--supergraph' and '--config' cannot be used together")
        if Bool(options.tls_cert) != Bool(options.tls_key):
            raise Error("'--tls-cert' and '--tls-key' must be used together")
        if options.tls_cert and options.https_port == options.port:
            raise Error("'--https-port' must differ from '--port'")
    elif options.command != CommandKind.HELP:
        if options.gateway == "":
            raise Error("'--gateway <URL>' is required")
        if options.command != CommandKind.REFRESH and options.name == "":
            raise Error("'--name <NAME>' is required")
        if options.command == CommandKind.PUBLISH and options.url == "":
            raise Error("'--url <URL>' is required")
    return options^


def gateway_config(options: CliOptions) raises -> GatewayConfig:
    """Make the gateway configuration of `serve`.

    Args:
        options: The options.

    Returns:
        Registry mode in `--registry`, or static mode with the content of
        `--supergraph`.

    Raises:
        Error: When the `--supergraph` file cannot be read.
    """
    var config = GatewayConfig()
    config.title = options.title
    config.graphql_path = options.path
    config.publish_token = options.token
    config.http_port = options.port
    config.subscriptions.enabled = options.subscriptions != SubscriptionMode.OFF
    config.subscriptions.server_enabled = True
    config.subscriptions.websocket_all = (
        options.subscriptions == SubscriptionMode.WS
    )
    if options.tls_cert:
        config.https_port = options.https_port
        if options.h3:
            config.h3_port = options.https_port
    if options.supergraph:
        config.registry_directory = None
        config.static_sdl = read_file(options.supergraph.value())
    else:
        config.registry_directory = options.registry
    return config^


@fieldwise_init
struct AdminRequest(Copyable, Movable):
    """The HTTP request of `publish`, `remove` or `refresh`."""

    var url: String
    """The URL of the gateway endpoint."""
    var body: String
    """The JSON body."""


def _gateway_base(gateway: String) -> String:
    """Return the gateway URL without a final `/` or GraphQL path."""
    var base = gateway
    if base.endswith("/graphql"):
        var trimmed = String(base[byte = : base.byte_length() - 8])
        base = trimmed^
    while base.endswith("/"):
        var shorter = String(base[byte = : base.byte_length() - 1])
        base = shorter^
    return base^


def admin_request(options: CliOptions) raises -> AdminRequest:
    """Make the request of `publish`, `remove` or `refresh`.

    Args:
        options: The options of one of those commands.

    Returns:
        The URL and the body.

    Raises:
        Error: When the `--schema` file cannot be read, or the command is
            not one of the three.
    """
    var base = _gateway_base(options.gateway)
    if options.command == CommandKind.PUBLISH:
        var body = (
            '{"name":'
            + json_string(options.name)
            + ',"url":'
            + json_string(options.url)
        )
        if options.schema:
            body += ',"sdl":' + json_string(read_file(options.schema.value()))
        return AdminRequest(base + "/scorchql/publish", body + "}")
    if options.command == CommandKind.REMOVE:
        return AdminRequest(
            base + "/scorchql/remove",
            '{"name":' + json_string(options.name) + "}",
        )
    if options.command == CommandKind.REFRESH:
        return AdminRequest(base + "/scorchql/refresh", "{}")
    raise Error("'" + String(options.command) + "' sends no request")


def send_admin(
    mut client: Client, options: CliOptions
) raises -> Tuple[Int, String]:
    """Send the request of `publish`, `remove` or `refresh`.

    Args:
        client: The HTTP client.
        options: The options.

    Returns:
        The HTTP status code and the response body.

    Raises:
        Error: As `admin_request` raises, or when the request fails.
    """
    var request = admin_request(options)
    var endpoint = client.endpoint(request.url)
    var headers = Headers()
    headers.add("Content-Type", "application/json")
    if options.token:
        headers.add("Authorization", "Bearer " + options.token.value())
    var target = endpoint.target.copy()
    var response = client.send(
        endpoint, Method.POST, target, headers, request.body.as_bytes()
    )
    return (Int(response.status.code), response.text())

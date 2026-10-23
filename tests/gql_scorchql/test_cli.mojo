# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the command line of `scorchql`, `gql_scorchql.cli`.

ScorchQL has no upstream, so there is no upstream test suite to port. The
`publish` options follow `rover subgraph publish`.
"""

from std.os import makedirs, setenv, unsetenv

from _fixtures import fresh_directory, loopback
from gql_http.client import Client
from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter, start_workers
from gql_http.socket import IPv4Address
from gql_scorchql.cli import (
    CliOptions,
    CommandKind,
    SubscriptionMode,
    USAGE,
    VERSION,
    admin_request,
    gateway_config,
    parse_cli,
    send_admin,
)
from gql_scorchql.registry import write_file_atomic
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)


def _args(*words: String) -> List[String]:
    var out = List[String]()
    for word in words:
        out.append(String(word))
    return out^


def test_command_kind() raises:
    assert_true(CommandKind.VERSION.is_valid())
    assert_false(CommandKind(6).is_valid())
    assert_equal(String(CommandKind.SERVE), "serve")
    assert_equal(String(CommandKind.PUBLISH), "publish")
    assert_equal(String(CommandKind.REMOVE), "remove")
    assert_equal(String(CommandKind.REFRESH), "refresh")
    assert_equal(String(CommandKind.HELP), "help")
    assert_equal(String(CommandKind.VERSION), "version")
    assert_equal(String(CommandKind(9)), "invalid")
    assert_true(CommandKind.HELP == CommandKind(4))
    assert_true(CommandKind.HELP != CommandKind.SERVE)


def test_subscription_mode() raises:
    assert_true(SubscriptionMode.WS.is_valid())
    assert_true(SubscriptionMode.HTTP.is_valid())
    assert_true(SubscriptionMode.OFF.is_valid())
    assert_false(SubscriptionMode(3).is_valid())
    assert_equal(String(SubscriptionMode.WS), "ws")
    assert_equal(String(SubscriptionMode.HTTP), "http")
    assert_equal(String(SubscriptionMode.OFF), "off")
    assert_equal(String(SubscriptionMode(9)), "invalid")
    assert_true(SubscriptionMode.WS == SubscriptionMode(0))
    assert_true(SubscriptionMode.WS != SubscriptionMode.HTTP)


def test_serve_defaults() raises:
    var options = parse_cli(List[String]())
    assert_true(options.command == CommandKind.SERVE)
    assert_equal(options.registry, ".scorchql")
    assert_false(options.supergraph)
    assert_false(options.config)
    assert_false(options.demo)
    assert_true(options.host == IPv4Address.ANY)
    assert_equal(options.host_text, "0.0.0.0")
    assert_equal(options.port, 4000)
    assert_equal(options.workers, 1)
    assert_equal(options.path, "/graphql")
    assert_equal(options.title, "ScorchQL")
    assert_false(options.token)
    assert_equal(options.poll_seconds, 10)
    assert_true(options.subscriptions == SubscriptionMode.WS)
    assert_true(parse_cli(_args("serve")).command == CommandKind.SERVE)


def test_serve_flags() raises:
    var options = parse_cli(
        _args(
            "serve",
            "--registry",
            "/var/lib/scorchql",
            "--config=supergraph.yaml",
            "--host",
            "127.0.0.1",
            "--port",
            "8080",
            "--workers=4",
            "--path",
            "/api",
            "--title",
            "Fire Lab",
            "--token",
            "s3cret",
            "--poll",
            "0",
            "--subscriptions",
            "http",
        )
    )
    assert_equal(options.registry, "/var/lib/scorchql")
    assert_equal(options.config.value(), "supergraph.yaml")
    assert_true(options.host == IPv4Address.LOOPBACK)
    assert_equal(options.host_text, "127.0.0.1")
    assert_equal(options.port, 8080)
    assert_equal(options.workers, 4)
    assert_equal(options.path, "/api")
    assert_equal(options.title, "Fire Lab")
    assert_equal(options.token.value(), "s3cret")
    assert_equal(options.poll_seconds, 0)
    assert_true(options.subscriptions == SubscriptionMode.HTTP)
    assert_true(
        parse_cli(_args("--subscriptions", "ws")).subscriptions
        == SubscriptionMode.WS
    )
    assert_true(
        parse_cli(_args("--subscriptions", "off")).subscriptions
        == SubscriptionMode.OFF
    )
    var fixed = parse_cli(_args("--supergraph", "s.graphql"))
    assert_equal(fixed.supergraph.value(), "s.graphql")
    var demo = parse_cli(_args("--demo", "--port", "4000"))
    assert_true(demo.demo)
    assert_equal(demo.port, 4000)
    assert_true("--demo" in USAGE)


def test_the_token_comes_from_the_environment() raises:
    _ = setenv("SCORCHQL_TOKEN", "from-env")
    var options = parse_cli(List[String]())
    var flagged = parse_cli(_args("--token", "flag"))
    _ = unsetenv("SCORCHQL_TOKEN")
    assert_equal(options.token.value(), "from-env")
    assert_equal(flagged.token.value(), "flag")


def test_tls_flags() raises:
    var options = parse_cli(
        _args(
            "--tls-cert", "c.pem", "--tls-key", "k.pem", "--https-port", "8443"
        )
    )
    assert_equal(options.tls_cert.value(), "c.pem")
    assert_equal(options.tls_key.value(), "k.pem")
    assert_equal(options.https_port, 8443)
    assert_true(options.h3)
    var config = gateway_config(options)
    assert_equal(config.http_port, 4000)
    assert_equal(config.https_port, 8443)
    assert_equal(config.h3_port, 8443)
    var no_h3 = parse_cli(
        _args("--tls-cert", "c", "--tls-key", "k", "--h3", "off")
    )
    assert_false(no_h3.h3)
    var config_no_h3 = gateway_config(no_h3)
    assert_equal(config_no_h3.https_port, 4443)
    assert_equal(config_no_h3.h3_port, 0)
    assert_true(parse_cli(_args("--h3", "on")).h3)
    var plain = gateway_config(parse_cli(List[String]()))
    assert_equal(plain.https_port, 0)
    assert_equal(plain.h3_port, 0)
    with assert_raises(contains="must be used together"):
        _ = parse_cli(_args("--tls-cert", "c"))
    with assert_raises(contains="must be used together"):
        _ = parse_cli(_args("--tls-key", "k"))
    with assert_raises(contains="must differ"):
        _ = parse_cli(
            _args("--tls-cert", "c", "--tls-key", "k", "--https-port", "4000")
        )
    with assert_raises(contains="'--h3' must be 'on' or 'off'"):
        _ = parse_cli(_args("--h3", "yes"))
    with assert_raises(
        contains="'--subscriptions' must be 'ws', 'http' or 'off'"
    ):
        _ = parse_cli(_args("--subscriptions", "sse"))


def test_help_and_version() raises:
    assert_true(parse_cli(_args("--help")).command == CommandKind.HELP)
    assert_true(parse_cli(_args("-h")).command == CommandKind.HELP)
    assert_true(parse_cli(_args("help")).command == CommandKind.HELP)
    assert_true(
        parse_cli(_args("publish", "--help")).command == CommandKind.HELP
    )
    assert_true(parse_cli(_args("--version")).command == CommandKind.VERSION)
    assert_true(parse_cli(_args("-V")).command == CommandKind.VERSION)
    assert_true(USAGE.startswith("ScorchQL"))
    assert_true(VERSION.startswith("scorchql "))


def test_admin_commands() raises:
    var publish = parse_cli(
        _args(
            "publish",
            "--gateway",
            "http://gw:4000",
            "--name",
            "products",
            "--url",
            "http://p:4001/",
            "--schema",
            "p.graphql",
            "--token=t",
        )
    )
    assert_true(publish.command == CommandKind.PUBLISH)
    assert_equal(publish.gateway, "http://gw:4000")
    assert_equal(publish.name, "products")
    assert_equal(publish.url, "http://p:4001/")
    assert_equal(publish.schema.value(), "p.graphql")
    assert_equal(publish.token.value(), "t")
    var remove = parse_cli(
        _args("remove", "--gateway", "http://gw", "--name", "products")
    )
    assert_true(remove.command == CommandKind.REMOVE)
    var refresh = parse_cli(_args("refresh", "--gateway", "http://gw"))
    assert_true(refresh.command == CommandKind.REFRESH)


def test_errors() raises:
    with assert_raises(contains="unknown command 'deploy'"):
        _ = parse_cli(_args("deploy"))
    with assert_raises(contains="unexpected argument 'x'"):
        _ = parse_cli(_args("serve", "x"))
    with assert_raises(contains="'--port' needs a value"):
        _ = parse_cli(_args("--port"))
    with assert_raises(contains="invalid value 'ten' for '--port'"):
        _ = parse_cli(_args("--port", "ten"))
    with assert_raises(contains="must be from 0 to 65535, not 70000"):
        _ = parse_cli(_args("--port", "70000"))
    with assert_raises(contains="must be from 1 to 256, not 0"):
        _ = parse_cli(_args("--workers", "0"))
    with assert_raises(contains="must be from 0 to 86400, not -1"):
        _ = parse_cli(_args("--poll", "-1"))
    with assert_raises(contains="invalid IPv4 address 'localhost'"):
        _ = parse_cli(_args("--host", "localhost"))
    with assert_raises(contains="'--path' must start with '/'"):
        _ = parse_cli(_args("--path", "graphql"))
    with assert_raises(contains="unknown option '--name' for 'serve'"):
        _ = parse_cli(_args("--name", "x"))
    with assert_raises(contains="unknown option '--port' for 'publish'"):
        _ = parse_cli(_args("publish", "--port", "1"))
    with assert_raises(contains="cannot be used together"):
        _ = parse_cli(_args("--supergraph", "a", "--config", "b"))
    with assert_raises(contains="'--demo' and '--supergraph'"):
        _ = parse_cli(_args("--demo", "--supergraph", "a"))
    with assert_raises(contains="'--demo' and '--config'"):
        _ = parse_cli(_args("--config", "b", "--demo"))
    with assert_raises(contains="unknown option '--demo' for 'publish'"):
        _ = parse_cli(_args("publish", "--demo", "--gateway", "http://g"))
    with assert_raises(contains="'--gateway <URL>' is required"):
        _ = parse_cli(_args("refresh"))
    with assert_raises(contains="'--name <NAME>' is required"):
        _ = parse_cli(_args("remove", "--gateway", "http://gw"))
    with assert_raises(contains="'--url <URL>' is required"):
        _ = parse_cli(_args("publish", "--gateway", "http://g", "--name", "a"))


def test_gateway_config() raises:
    var options = parse_cli(
        _args("--title", "Lab", "--path", "/q", "--token", "t")
    )
    var config = gateway_config(options)
    assert_equal(config.title, "Lab")
    assert_equal(config.graphql_path, "/q")
    assert_equal(config.publish_token.value(), "t")
    assert_equal(config.registry_directory.value(), ".scorchql")
    assert_false(config.static_sdl)
    assert_true(config.subscriptions.enabled)
    assert_true(config.subscriptions.websocket_all)
    var http_sub = gateway_config(parse_cli(_args("--subscriptions", "http")))
    assert_true(http_sub.subscriptions.enabled)
    assert_false(http_sub.subscriptions.websocket_all)
    var off_sub = gateway_config(parse_cli(_args("--subscriptions", "off")))
    assert_false(off_sub.subscriptions.enabled)
    var directory = fresh_directory("cli")
    makedirs(directory, exist_ok=True)
    write_file_atomic(directory + "/s.graphql", "type Query { a: Int }")
    var fixed = gateway_config(
        parse_cli(_args("--supergraph", directory + "/s.graphql"))
    )
    assert_false(fixed.registry_directory)
    assert_equal(fixed.static_sdl.value(), "type Query { a: Int }")
    with assert_raises():
        _ = gateway_config(
            parse_cli(_args("--supergraph", directory + "/none"))
        )


def test_admin_request() raises:
    var directory = fresh_directory("cli_admin")
    makedirs(directory, exist_ok=True)
    write_file_atomic(directory + "/p.graphql", 'type Query { "a" a: Int }\n')
    var publish = admin_request(
        parse_cli(
            _args(
                "publish",
                "--gateway",
                "http://gw:4000/graphql",
                "--name",
                "p",
                "--url",
                "http://p/",
            )
        )
    )
    assert_equal(publish.url, "http://gw:4000/scorchql/publish")
    assert_equal(publish.body, '{"name":"p","url":"http://p/"}')
    var with_schema = admin_request(
        parse_cli(
            _args(
                "publish",
                "--gateway",
                "http://gw//",
                "--name",
                "p",
                "--url",
                "http://p/",
                "--schema",
                directory + "/p.graphql",
            )
        )
    )
    assert_equal(with_schema.url, "http://gw/scorchql/publish")
    assert_equal(
        with_schema.body,
        (
            '{"name":"p","url":"http://p/","sdl":"type Query { \\"a\\" a: Int'
            ' }\\n"}'
        ),
    )
    var remove = admin_request(
        parse_cli(_args("remove", "--gateway", "http://gw", "--name", "p"))
    )
    assert_equal(remove.url, "http://gw/scorchql/remove")
    assert_equal(remove.body, '{"name":"p"}')
    var refresh = admin_request(
        parse_cli(_args("refresh", "--gateway", "http://gw/"))
    )
    assert_equal(refresh.url, "http://gw/scorchql/refresh")
    assert_equal(refresh.body, "{}")
    with assert_raises(contains="'serve' sends no request"):
        _ = admin_request(CliOptions())


struct _Echo(Handler):
    """Answers each request with its path and its `Authorization` header."""

    def __init__(out self):
        pass

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        var auth = request.header("authorization")
        response.add_header("Content-Type", "application/json")
        response.write_text(
            String(request.path())
            + " "
            + (String(auth.value()) if auth else String("-"))
            + " "
            + String(StringSlice(unsafe_from_utf8=request.body()))
        )


def test_send_admin() raises:
    var pool = start_workers(_Echo(), loopback())
    var gateway = "http://127.0.0.1:" + String(pool.port)
    var client = Client()
    var plain = send_admin(
        client, parse_cli(_args("refresh", "--gateway", gateway))
    )
    assert_equal(plain[0], 200)
    assert_equal(plain[1], "/scorchql/refresh - {}")
    var signed = send_admin(
        client,
        parse_cli(
            _args("remove", "--gateway", gateway, "--name", "a", "--token", "t")
        ),
    )
    assert_equal(signed[1], '/scorchql/remove Bearer t {"name":"a"}')
    client.close_idle()
    assert_equal(pool.stop(), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

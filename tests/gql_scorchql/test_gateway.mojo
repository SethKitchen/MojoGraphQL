# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the gateway handler, `gql_scorchql.gateway`.

ScorchQL has no upstream, so there is no upstream test suite to port. Most
cases call `Gateway.answer` without a socket. The socket cases serve the
gateway and a fake pair of subgraphs over HTTP, SSE, multipart and
`graphql-transport-ws` WebSocket on the loopback interface.
"""

from std.memory import ArcPointer

from _fixtures import (
    CONFLICT_SDL,
    FakeSubgraphs,
    PRODUCTS_SDL,
    REVIEWS_SDL,
    fresh_directory,
    loopback,
    start_fake_subgraphs,
)
from gql_http.body import BodyPoll
from gql_http.client import Client
from gql_http.server import start_workers
from gql_http.socket import EAGAIN, Faults, IPv4Address, Sys, SysCall
from gql_http.status import Method, Status
from gql_router.router_server import HttpAnswer
from gql_scorchql.gateway import (
    Gateway,
    GatewayConfig,
    GatewayWsExecutor,
    GatewayWsHandler,
    SharedGateway,
    refresh_registry,
    serve_gateway,
    wants_explorer,
)
from gql_scorchql.registry import Registry, write_file_atomic
from gql_ws.graphql_ws import parse_message
from gql_ws.server import ServerConfig as WsServerConfig
from gql_ws.server import Sockets
from gql_ws.transport_server import OperationKind
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)

comptime HTML = "text/html, application/xhtml+xml"


def _registry_config(name: String) -> GatewayConfig:
    var config = GatewayConfig()
    config.registry_directory = fresh_directory(name)
    config.reload_interval_ms = 0
    return config^


def _call(
    mut gateway: Gateway,
    method: Method,
    path: StringSlice,
    body: StringSlice = "",
    query: StringSlice = "",
    accept: Optional[String] = None,
    authorization: Optional[String] = None,
) raises -> HttpAnswer:
    return gateway.answer(
        method,
        path,
        query,
        Optional[String]("application/json"),
        accept,
        authorization,
        List[UInt8](body.as_bytes()),
    )


def _text(answer: HttpAnswer) -> String:
    return String(StringSlice(unsafe_from_utf8=Span(answer.body)))


def _publish_json(name: String, url: String, sdl: String) -> String:
    var escaped = (
        sdl.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    )
    return '{"name":"' + name + '","url":"' + url + '","sdl":"' + escaped + '"}'


def test_wants_explorer() raises:
    assert_true(wants_explorer(Method.GET, "", Optional[String](HTML)))
    assert_true(wants_explorer(Method.GET, "x=1", Optional[String](HTML)))
    assert_false(
        wants_explorer(Method.GET, "query=%7Ba%7D", Optional[String](HTML))
    )
    assert_false(wants_explorer(Method.POST, "", Optional[String](HTML)))
    assert_false(wants_explorer(Method.GET, "", None))
    assert_false(
        wants_explorer(Method.GET, "", Optional[String]("application/json"))
    )
    assert_false(wants_explorer(Method.GET, "a=%zz", Optional[String](HTML)))


def test_the_default_config() raises:
    var config = GatewayConfig()
    assert_equal(config.title, "ScorchQL")
    assert_equal(config.graphql_path, "/graphql")
    assert_equal(config.registry_directory.value(), ".scorchql")
    assert_false(config.static_sdl)
    assert_false(config.publish_token)
    assert_equal(config.reload_interval_ms, 250)
    assert_equal(config.introspect_timeout_ms, 5000)
    assert_true(config.subscriptions.enabled)
    assert_true(config.subscriptions.server_enabled)
    assert_true(config.subscriptions.websocket_all)
    var sys = Sys()
    sys.faults = Faults(SysCall.EPOLL_CREATE, 24, 0, 1)
    with assert_raises(contains="epoll_create failed: 24"):
        _ = Gateway(_registry_config("epoll_fail"), sys^)


def test_an_empty_gateway() raises:
    var gateway = Gateway(_registry_config("empty"))
    assert_equal(gateway.revision, 0)
    assert_equal(len(gateway.streams), 0)
    var out = List[UInt8]()
    assert_true(gateway.poll_body(0, out) == BodyPoll.DONE)
    gateway.body_closed(0)
    var page = _call(gateway, Method.GET, "/")
    assert_equal(page.status, 200)
    assert_equal(page.content_type, "text/html; charset=utf-8")
    assert_true(_text(page).startswith("<!doctype html>"))
    assert_equal(_text(_call(gateway, Method.GET, "/index.html")), _text(page))
    var browser = _call(gateway, Method.GET, "/graphql", accept=String(HTML))
    assert_equal(browser.content_type, "text/html; charset=utf-8")
    var graphql = _call(gateway, Method.POST, "/graphql", '{"query":"{a}"}')
    assert_equal(graphql.status, 503)
    assert_true('"code":"NO_SUPERGRAPH"' in _text(graphql))
    var health = _call(gateway, Method.GET, "/health")
    assert_equal(_text(health), '{"status":"pass"}')
    var icon = _call(gateway, Method.GET, "/favicon.svg")
    assert_equal(icon.content_type, "image/svg+xml")
    assert_equal(_call(gateway, Method.GET, "/favicon.ico").status, 200)
    var state = _text(_call(gateway, Method.GET, "/scorchql/state"))
    assert_equal(
        state,
        (
            '{"title":"ScorchQL","graphqlPath":"/graphql","mode":"registry",'
            '"revision":0,"publishRequiresToken":false,"httpPort":0,"httpsPort":0,'
            '"h3Port":0,"subscriptions":"ws","loadError":null,'
            '"subgraphs":[]}'
        ),
    )
    gateway.config.subscriptions.websocket_all = False
    assert_true('"subscriptions":"http"' in gateway.state_json())
    gateway.config.subscriptions.enabled = False
    assert_true('"subscriptions":"off"' in gateway.state_json())
    var sdl = _call(gateway, Method.GET, "/scorchql/supergraph.graphql")
    assert_equal(sdl.status, 404)
    assert_equal(_call(gateway, Method.GET, "/nothing").status, 404)
    assert_equal(_call(gateway, Method.PUT, "/scorchql/state").status, 405)
    assert_equal(_call(gateway, Method.POST, "/nothing").status, 404)
    var plan = _call(gateway, Method.POST, "/scorchql/plan", '{"query":"{a}"}')
    assert_equal(plan.status, 503)


def test_publish_plan_and_query() raises:
    var gateway = Gateway(_registry_config("publish"))
    var published = _call(
        gateway,
        Method.POST,
        "/scorchql/publish",
        _publish_json("products", "http://127.0.0.1:9/", PRODUCTS_SDL),
    )
    assert_equal(published.status, 200)
    assert_equal(_text(published), '{"ok":true,"changed":true,"revision":1}')
    assert_equal(gateway.revision, 1)
    assert_equal(len(gateway.streams), 1)
    var out = List[UInt8]()
    assert_true(gateway.poll_body(99, out) == BodyPoll.DONE)
    gateway.body_closed(99)
    var again = _call(
        gateway,
        Method.POST,
        "/scorchql/publish",
        _publish_json("products", "http://127.0.0.1:9/", PRODUCTS_SDL),
    )
    assert_equal(_text(again), '{"ok":true,"changed":false,"revision":1}')
    var sdl = _call(gateway, Method.GET, "/scorchql/supergraph.graphql")
    assert_equal(sdl.status, 200)
    assert_true(_text(sdl).startswith("schema @link"))
    var state = _text(_call(gateway, Method.GET, "/scorchql/state"))
    assert_true(
        '"subgraphs":[{"name":"products","url":"http://127.0.0.1:9/"' in state
    )
    var plan = _call(
        gateway,
        Method.POST,
        "/scorchql/plan",
        '{"query":"{ products { name } }","operationName":null}',
    )
    assert_equal(plan.status, 200)
    assert_true(_text(plan).startswith('{"ok":true,"plan":"QueryPlan {'))
    var defer_plan = _call(
        gateway,
        Method.POST,
        "/scorchql/plan",
        '{"query":"{ products { id ... @defer { name } } }"}',
    )
    assert_true(_text(defer_plan).startswith('{"ok":true,"plan":"QueryPlan {'))
    var bad_plan = _text(
        _call(gateway, Method.POST, "/scorchql/plan", '{"query":"{ nope }"}')
    )
    assert_true(bad_plan.startswith('{"ok":false,"errors":["'))
    # The subgraph at port 9 is down, so the router answers with an error.
    var down = _call(
        gateway, Method.POST, "/graphql", '{"query":"{ products { name } }"}'
    )
    assert_equal(down.status, 200)
    assert_true('"errors"' in _text(down))
    var introspection = _call(
        gateway,
        Method.GET,
        "/graphql",
        query="query=%7B__schema%7BqueryType%7Bname%7D%7D%7D",
    )
    assert_equal(
        _text(introspection),
        '{"data":{"__schema":{"queryType":{"name":"Query"}}}}',
    )


def test_operations_are_validated() raises:
    var gateway = Gateway(_registry_config("validate"))
    _ = _call(
        gateway,
        Method.POST,
        "/scorchql/publish",
        _publish_json("products", "http://127.0.0.1:9/", PRODUCTS_SDL),
    )
    var typo = _call(
        gateway, Method.POST, "/graphql", '{"query":"{ products { nmae } }"}'
    )
    assert_equal(typo.status, 200)
    assert_equal(typo.content_type, "application/json")
    assert_equal(
        _text(typo),
        (
            '{"errors":[{"message":"Cannot query field \\"nmae\\" on type'
            ' \\"Product\\".","locations":[{"line":1,'
            '"column":14}],"extensions":{"code":"FieldsOnCorrectType"}}]}'
        ),
    )
    var strict = _call(
        gateway,
        Method.POST,
        "/graphql",
        '{"query":"{ products @nope { id } }"}',
        accept=String("application/graphql-response+json"),
    )
    assert_equal(strict.status, 400)
    assert_equal(strict.content_type, "application/graphql-response+json")
    assert_true("Unknown directive" in _text(strict))
    var by_get = _call(
        gateway, Method.GET, "/graphql", query="query=%7Bnope%7D"
    )
    assert_true("Cannot query field" in _text(by_get))
    var mutation = _call(
        gateway, Method.POST, "/graphql", '{"query":"mutation { a }"}'
    )
    assert_true("OPERATION_RESOLUTION_FAILURE" in _text(mutation))
    # A cached validation result gives the same answer.
    assert_equal(
        _text(
            _call(
                gateway,
                Method.POST,
                "/graphql",
                '{"query":"{ products { nmae } }"}',
            )
        ),
        _text(typo),
    )
    var syntax = _call(gateway, Method.POST, "/graphql", '{"query":"{"}')
    assert_true("GRAPHQL_PARSE_FAILED" in _text(syntax))
    var no_query = _call(gateway, Method.POST, "/graphql", "{}")
    assert_true("MISSING_QUERY_PARAM" in _text(no_query))
    var bad_json = _call(gateway, Method.POST, "/graphql", "{")
    assert_equal(bad_json.status, 400)
    var other = _call(gateway, Method.PUT, "/graphql", "{}")
    assert_equal(other.status, 405)


def test_subscriptions_can_be_disabled() raises:
    var config = _registry_config("sub_disabled")
    config.subscriptions.enabled = False
    var gateway = Gateway(config^)
    _ = _call(
        gateway,
        Method.POST,
        "/scorchql/publish",
        _publish_json("products", "http://127.0.0.1:9/", PRODUCTS_SDL),
    )
    _ = _call(
        gateway,
        Method.POST,
        "/scorchql/publish",
        _publish_json("reviews", "http://127.0.0.1:9/", REVIEWS_SDL),
    )
    var answer = _call(
        gateway,
        Method.POST,
        "/graphql",
        '{"query":"subscription { reviewAdded { id } }"}',
        accept=String("text/event-stream"),
    )
    assert_true("SUBSCRIPTIONS_NOT_SUPPORTED" in _text(answer))


def test_bad_requests() raises:
    var gateway = Gateway(_registry_config("bad"))
    var not_json = _call(gateway, Method.POST, "/scorchql/publish", "{")
    assert_equal(not_json.status, 400)
    var array = _call(gateway, Method.POST, "/scorchql/publish", "[]")
    assert_true("must be a JSON object" in _text(array))
    var number = _call(
        gateway, Method.POST, "/scorchql/publish", '{"name":1,"url":"x"}'
    )
    assert_true("'name' must be a string." in _text(number))
    var missing = _call(
        gateway, Method.POST, "/scorchql/publish", '{"name":"a"}'
    )
    assert_true("'name' and 'url' are required." in _text(missing))
    var null_url = _call(
        gateway, Method.POST, "/scorchql/publish", '{"name":"a","url":null}'
    )
    assert_equal(null_url.status, 400)
    var invalid = _call(
        gateway,
        Method.POST,
        "/scorchql/publish",
        '{"name":"9","url":"ftp://x"}',
    )
    assert_equal(invalid.status, 422)
    assert_true("Invalid subgraph name '9'" in _text(invalid))
    var unreachable = _call(
        gateway,
        Method.POST,
        "/scorchql/publish",
        '{"name":"a","url":"http://127.0.0.1:9/"}',
    )
    assert_equal(unreachable.status, 422)
    assert_true(
        "Cannot read the SDL of 'a' from http://127.0.0.1:9/"
        in _text(unreachable)
    )
    assert_equal(
        _call(gateway, Method.POST, "/scorchql/remove", "{").status, 400
    )
    var no_name = _call(gateway, Method.POST, "/scorchql/remove", "{}")
    assert_true("'name' is required." in _text(no_name))
    var unknown = _call(
        gateway, Method.POST, "/scorchql/remove", '{"name":"products"}'
    )
    assert_equal(unknown.status, 422)
    _ = _call(
        gateway,
        Method.POST,
        "/scorchql/publish",
        _publish_json("products", "http://127.0.0.1:9/", PRODUCTS_SDL),
    )
    var conflict = _call(
        gateway,
        Method.POST,
        "/scorchql/publish",
        _publish_json("bad", "http://127.0.0.1:9/", CONFLICT_SDL),
    )
    assert_equal(conflict.status, 422)
    assert_true('{"ok":false,"errors":["' in _text(conflict))
    assert_equal(_call(gateway, Method.POST, "/scorchql/plan", "{").status, 400)
    var no_query = _call(gateway, Method.POST, "/scorchql/plan", "{}")
    assert_true("'query' is required." in _text(no_query))


def test_remove_through_the_gateway() raises:
    var gateway = Gateway(_registry_config("remove"))
    _ = _call(
        gateway,
        Method.POST,
        "/scorchql/publish",
        _publish_json("products", "http://127.0.0.1:9/", PRODUCTS_SDL),
    )
    var removed = _call(
        gateway, Method.POST, "/scorchql/remove", '{"name":"products"}'
    )
    assert_equal(_text(removed), '{"ok":true,"changed":true,"revision":2}')
    assert_equal(len(gateway.streams), 0)
    assert_equal(gateway.sdl, "")


def test_the_publish_token() raises:
    var config = _registry_config("token")
    config.publish_token = String("s3cret")
    var gateway = Gateway(config^)
    var body = _publish_json("products", "http://127.0.0.1:9/", PRODUCTS_SDL)
    var none = _call(gateway, Method.POST, "/scorchql/publish", body)
    assert_equal(none.status, 401)
    var wrong = _call(
        gateway,
        Method.POST,
        "/scorchql/publish",
        body,
        authorization=String("Bearer nope"),
    )
    assert_equal(wrong.status, 401)
    var right = _call(
        gateway,
        Method.POST,
        "/scorchql/publish",
        body,
        authorization=String("Bearer s3cret"),
    )
    assert_equal(right.status, 200)
    assert_true(
        '"publishRequiresToken":true'
        in _text(_call(gateway, Method.GET, "/scorchql/state"))
    )
    # Reading needs no token.
    assert_equal(_call(gateway, Method.GET, "/scorchql/state").status, 200)


def test_a_worker_follows_another_workers_publish() raises:
    var config = _registry_config("follow")
    var directory = config.registry_directory.value()
    config.reload_interval_ms = 60000
    var gateway = Gateway(config^)
    var other = Registry(directory)
    _ = other.publish("products", "http://127.0.0.1:9/", PRODUCTS_SDL)
    gateway.maybe_reload()
    assert_equal(gateway.revision, 0)
    gateway.reload()
    assert_equal(gateway.revision, 1)
    assert_equal(len(gateway.streams), 1)
    gateway.config.reload_interval_ms = 0
    _ = other.remove("products")
    gateway.maybe_reload()
    assert_equal(gateway.revision, 2)
    assert_equal(len(gateway.streams), 0)


def test_a_supergraph_that_cannot_be_served() raises:
    var config = _registry_config("broken")
    var directory = config.registry_directory.value()
    var gateway = Gateway(config^)
    _ = _call(
        gateway,
        Method.POST,
        "/scorchql/publish",
        _publish_json("products", "http://127.0.0.1:9/", PRODUCTS_SDL),
    )
    write_file_atomic(directory + "/supergraph.graphql", "type Query {")
    write_file_atomic(directory + "/revision", "7\n")
    gateway.reload()
    assert_true(
        gateway.load_error.startswith("The supergraph cannot be served")
    )
    # The old router keeps serving.
    assert_equal(len(gateway.streams), 1)
    assert_true(
        '"loadError":"The supergraph cannot be served'
        in _text(_call(gateway, Method.GET, "/scorchql/state"))
    )
    gateway.streams.clear()
    var graphql = _call(gateway, Method.POST, "/graphql", '{"query":"{a}"}')
    assert_equal(graphql.status, 503)
    assert_true("The supergraph cannot be served" in _text(graphql))


def test_static_mode() raises:
    var registry = Registry(fresh_directory("static_source"))
    _ = registry.publish("products", "http://127.0.0.1:9/", PRODUCTS_SDL)
    var config = GatewayConfig()
    config.registry_directory = None
    config.static_sdl = registry.supergraph()
    config.title = "Fixed"
    var gateway = Gateway(config^)
    assert_equal(len(gateway.streams), 1)
    gateway.reload()
    assert_equal(gateway.revision, -1)
    var state = _text(_call(gateway, Method.GET, "/scorchql/state"))
    assert_true('"title":"Fixed"' in state)
    assert_true('"mode":"static"' in state)
    assert_true(
        '"subgraphs":[{"name":"products","url":"http://127.0.0.1:9/",'
        '"publishedAt":0,"sdl":""}]'
        in state
    )
    for path in ["/scorchql/publish", "/scorchql/remove", "/scorchql/refresh"]:
        var refused = _call(gateway, Method.POST, path, "{}")
        assert_equal(refused.status, 409)
    var bad = GatewayConfig()
    bad.registry_directory = None
    bad.static_sdl = String("type Query {")
    with assert_raises(contains="The supergraph cannot be served"):
        _ = Gateway(bad^)


def test_static_mode_without_a_router_lists_no_subgraphs() raises:
    var registry = Registry(fresh_directory("static_empty"))
    _ = registry.publish("products", "http://127.0.0.1:9/", PRODUCTS_SDL)
    var config = GatewayConfig()
    config.registry_directory = None
    config.static_sdl = registry.supergraph()
    var gateway = Gateway(config^)
    gateway.streams.clear()
    assert_true('"subgraphs":[]' in gateway.state_json())


def test_refresh_and_publish_by_url() raises:
    var subgraphs = start_workers(FakeSubgraphs(), loopback())
    var base = "http://127.0.0.1:" + String(subgraphs.port)
    var gateway = Gateway(_registry_config("refresh"))
    var by_url = _call(
        gateway,
        Method.POST,
        "/scorchql/publish",
        '{"name":"products","url":"' + base + '/products"}',
    )
    assert_equal(_text(by_url), '{"ok":true,"changed":true,"revision":1}')
    # Publish a stale SDL for reviews, then let the refresh read the new one.
    _ = _call(
        gateway,
        Method.POST,
        "/scorchql/publish",
        _publish_json("reviews", base + "/reviews", REVIEWS_SDL + "\n# old\n"),
    )
    var refreshed = _text(
        _call(gateway, Method.POST, "/scorchql/refresh", "{}")
    )
    assert_equal(
        refreshed,
        (
            '{"ok":true,"revision":3,"subgraphs":[{"name":"products","status":'
            '"unchanged"},{"name":"reviews","status":"updated"}]}'
        ),
    )
    # A subgraph that went down, and one whose new SDL does not compose.
    var registry = Registry(gateway.config.registry_directory.value())
    var header = String(
        'extend schema @link(url: "https://specs.apollo.dev/federation/v2.3",'
        ' import: ["@key"])\n'
    )
    assert_true(
        registry.publish(
            "broken", base + "/broken", header + "type Query { b: Int }\n"
        ).accepted
    )
    assert_true(
        registry.publish(
            "bad", base + "/bad", header + "type Query { c: Int }\n"
        ).accepted
    )
    var client = Client()
    var outcomes = refresh_registry(registry, client)
    assert_equal(len(outcomes), 4)
    assert_equal(outcomes[0].name, "bad")
    assert_equal(outcomes[0].status, "failed")
    assert_true("incompatible" in outcomes[0].error)
    assert_equal(outcomes[1].name, "broken")
    assert_equal(outcomes[1].status, "failed")
    assert_true("down for repair" in outcomes[1].error)
    assert_equal(outcomes[2].status, "unchanged")
    assert_equal(outcomes[3].status, "unchanged")
    var answer = _text(_call(gateway, Method.POST, "/scorchql/refresh", "{}"))
    assert_true('"status":"failed","error":"' in answer)
    client.close_idle()
    gateway.client.close_idle()
    assert_equal(subgraphs.stop(), 0)


def test_alt_svc_announces_http3() raises:
    var config = _registry_config("alt_svc")
    config.http_port = 4000
    config.https_port = 4443
    config.h3_port = 4443
    var front = start_workers(Gateway(config^), loopback())
    var client = Client()
    var health = client.get(
        "http://127.0.0.1:" + String(front.port) + "/health"
    )
    assert_equal(health.header("alt-svc").value(), 'h3=":4443"; ma=86400')
    client.close_idle()
    assert_equal(front.stop(), 0)
    var state = Gateway(_registry_config("ports"))
    state.config.https_port = 4443
    assert_true('"httpsPort":4443,"h3Port":0' in state.state_json())


def test_defer_in_gateway_answer() raises:
    var subgraphs = start_workers(FakeSubgraphs(), loopback())
    var base = "http://127.0.0.1:" + String(subgraphs.port)
    var gateway = Gateway(_registry_config("defer_answer"))
    _ = _call(
        gateway,
        Method.POST,
        "/scorchql/publish",
        '{"name":"products","url":"' + base + '/products"}',
    )
    _ = _call(
        gateway,
        Method.POST,
        "/scorchql/publish",
        '{"name":"reviews","url":"' + base + '/reviews"}',
    )
    var multipart = _call(
        gateway,
        Method.POST,
        "/graphql",
        (
            '{"query":"{ products { name ... @defer(label: \\"r\\") { rating }'
            ' } }"}'
        ),
        accept=String("multipart/mixed"),
    )
    assert_equal(multipart.status, 200)
    assert_equal(multipart.content_type, 'multipart/mixed;boundary="-"')
    assert_true(
        '"pending":[{"id":"0","path":["products",0],"label":"r"}],"hasNext":true'
        in _text(multipart)
    )
    assert_true(
        '"incremental":[{"id":"0","data":{"rating":5}}],"completed":[{"id":"0"}]'
        in _text(multipart)
    )
    var inactive = _call(
        gateway,
        Method.POST,
        "/graphql",
        '{"query":"{ products { name ... @defer(if: false) { rating } } }"}',
        accept=String("multipart/mixed"),
    )
    assert_equal(inactive.status, 200)
    assert_true(
        '{"data":{"products":[{"name":"Torch","rating":5}]}}' in _text(inactive)
    )
    gateway.client.close_idle()
    assert_equal(subgraphs.stop(), 0)


def _connect(mut sys: Sys, port: Int) raises -> Int:
    var fd = sys.socket()
    var rc = sys.connect(fd, IPv4Address.LOOPBACK, port)
    if rc < 0 and rc != -115:
        raise Error("connect failed: " + String(rc))
    return fd


def _send(mut sys: Sys, fd: Int, text: String) raises:
    var bytes = text.as_bytes()
    var sent = 0
    while sent < len(bytes):
        var n = sys.send(
            fd, bytes.unsafe_ptr().unsafe_offset(sent), len(bytes) - sent
        )
        if n == -EAGAIN:
            _ = sys.poll(fd, 4, 100)
            continue
        if n < 0:
            raise Error("send failed: " + String(n))
        sent += n


def test_websocket_executor_and_handler() raises:
    var subgraphs = start_fake_subgraphs()
    var base = "http://127.0.0.1:" + String(subgraphs.port)
    var shared = ArcPointer(Gateway(_registry_config("ws_exec")))
    var executor = GatewayWsExecutor(shared)
    assert_true(
        executor.on_connect(
            1, parse_message('{"type":"connection_init"}')
        ).permitted
    )
    # Before a publish, a WebSocket operation gets NO_SUPERGRAPH.
    var no_sg = executor.operation(
        1,
        parse_message(
            '{"id":"1","type":"subscribe","payload":{"query":"{ products {'
            ' name } }"}}'
        ),
    )
    assert_true(no_sg.kind == OperationKind.ERRORS)
    assert_true("NO_SUPERGRAPH" in no_sg.json)
    var handler = GatewayWsHandler(shared)
    assert_equal(handler.fd(), shared[].epoll)
    assert_equal(handler.wait_ms(), -1)
    var sockets = Sockets(WsServerConfig().ws, 1000)
    # Tick with no loaded supergraph does nothing.
    handler.on_tick(sockets)
    handler.on_close(sockets, 1, 1000, "")
    executor.on_close(1, 1000, "")
    # Publish both subgraphs; the executor now runs queries and subscriptions.
    for name in ["products", "reviews"]:
        _ = _call(
            shared[],
            Method.POST,
            "/scorchql/publish",
            '{"name":"' + name + '","url":"' + base + "/" + name + '"}',
        )
    var query_op = executor.operation(
        1,
        parse_message(
            '{"id":"1","type":"subscribe","payload":{"query":"{ products {'
            ' name rating } }"}}'
        ),
    )
    assert_true(query_op.kind == OperationKind.RESULT)
    assert_equal(
        query_op.json, '{"data":{"products":[{"name":"Torch","rating":5}]}}'
    )
    var sub_op = executor.operation(
        1,
        parse_message(
            '{"id":"2","type":"subscribe","payload":{"query":"subscription {'
            ' reviewAdded { id body product { name } } }"}}'
        ),
    )
    assert_true(sub_op.kind == OperationKind.STREAM)
    handler.on_tick(sockets)
    var http_shared = SharedGateway(shared)
    var out = List[UInt8]()
    assert_true(http_shared.poll_body(99, out) == BodyPoll.DONE)
    http_shared.body_closed(99)
    shared[].client.close_idle()
    assert_equal(subgraphs.stop(), 0)


def test_the_gateway_serves_http_sse_and_websocket() raises:
    var subgraphs = start_fake_subgraphs()
    var base = "http://127.0.0.1:" + String(subgraphs.port)
    var gw_config = _registry_config("http_sse_ws")
    gw_config.subscriptions.websocket_all = False
    var ws_config = WsServerConfig()
    ws_config.http = loopback()
    var server = serve_gateway(Gateway(gw_config^), ws_config^)
    var sys = Sys()
    # Publish both subgraphs over HTTP through `serve_gateway`.
    for name in ["products", "reviews"]:
        var body = '{"name":"' + name + '","url":"' + base + "/" + name + '"}'
        var req = (
            "POST /scorchql/publish HTTP/1.1\r\nHost: x\r\nContent-Type:"
            " application/json\r\nContent-Length: "
            + String(body.byte_length())
            + "\r\nConnection: close\r\n\r\n"
            + body
        )
        var fd = _connect(sys, server.port)
        _send(sys, fd, req)
        var text = String()
        for _ in range(400):
            _ = server.poll(2)
            var buf = List[UInt8](length=4096, fill=0)
            var n = sys.recv(fd, buf.unsafe_ptr(), len(buf))
            if n > 0:
                text += String(unsafe_from_utf8=Span(buf)[:n])
            if '"ok":true' in text:
                break
        sys.close(fd)
        assert_true('"ok":true' in text, text)

    # Stream a federated subscription over SSE (`Accept: text/event-stream`),
    # where `reviews` sends the event and `products` resolves `product.name`.
    var sub_body = (
        '{"query":"subscription { reviewAdded { id body product { name } } }"}'
    )
    var sub_req = (
        "POST /graphql HTTP/1.1\r\nHost: x\r\nContent-Type:"
        " application/json\r\nAccept: text/event-stream\r\nContent-Length: "
        + String(sub_body.byte_length())
        + "\r\n\r\n"
        + sub_body
    )
    var sub_fd = _connect(sys, server.port)
    _send(sys, sub_fd, sub_req)
    var sse_out = String()
    for _ in range(500):
        _ = server.poll(2)
        var buf = List[UInt8](length=4096, fill=0)
        var n = sys.recv(sub_fd, buf.unsafe_ptr(), len(buf))
        if n > 0:
            sse_out += String(unsafe_from_utf8=Span(buf)[:n])
        if "event: complete" in sse_out:
            break
    sys.close(sub_fd)
    assert_true(
        'event: next\ndata: {"data":{"reviewAdded":{"id":"r1","body":"Hot!",'
        '"product":{"name":"Torch"}}}}'
        in sse_out,
        sse_out,
    )
    assert_true("event: complete" in sse_out, sse_out)

    # Connect a WebSocket client on `/graphql` (`graphql-transport-ws`).
    var ws_fd = _connect(sys, server.port)
    _send(
        sys,
        ws_fd,
        (
            "GET /graphql HTTP/1.1\r\nHost: x\r\nUpgrade: websocket\r\n"
            "Connection: Upgrade\r\nSec-WebSocket-Key:"
            " dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n"
            "Sec-WebSocket-Protocol: graphql-transport-ws\r\n\r\n"
        ),
    )
    var ws_out = String()
    for _ in range(200):
        _ = server.poll(2)
        var buf = List[UInt8](length=4096, fill=0)
        var n = sys.recv(ws_fd, buf.unsafe_ptr(), len(buf))
        if n > 0:
            ws_out += String(unsafe_from_utf8=Span(buf)[:n])
        if "101 Switching Protocols" in ws_out:
            break
    assert_true("101 Switching Protocols" in ws_out, ws_out)
    # Send a masked `connection_init` text frame: `{"type":"connection_init"}`
    var payload = StaticString('{"type":"connection_init"}').as_bytes()
    var frame = List[UInt8]()
    frame.append(0x81)
    frame.append(UInt8(0x80 | len(payload)))
    frame.extend([UInt8(0), UInt8(0), UInt8(0), UInt8(0)])
    frame.extend(payload)
    _ = sys.send(ws_fd, frame.unsafe_ptr(), len(frame))
    ws_out = String()
    for _ in range(200):
        _ = server.poll(2)
        var buf = List[UInt8](length=4096, fill=0)
        var n = sys.recv(ws_fd, buf.unsafe_ptr(), len(buf))
        if n > 0:
            ws_out += String(unsafe_from_utf8=Span(buf)[2:n])
        if "connection_ack" in ws_out:
            break
    assert_true("connection_ack" in ws_out, ws_out)
    sys.close(ws_fd)
    for _ in range(50):
        _ = server.poll(1)
    server.close()
    assert_equal(subgraphs.stop(), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

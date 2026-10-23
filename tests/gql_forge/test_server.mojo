# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_forge.server`."""

from std.os import makedirs
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)

from _fixtures import PRODUCTS_SDL, STAGING_SDL, fresh_directory
from gql_forge.server import (
    Forge,
    ForgeConfig,
    HttpAnswer,
    bearer_token,
    is_authorized,
    json_error,
    json_ok,
    serve_forge,
)
from gql_forge.store import write_file_atomic
from gql_http.body import BodyPoll
from gql_http.parser import Limits, ParseState, RequestReader
from gql_http.server import ResponseWriter, ServerConfig
from gql_http.socket import Faults, Sys, SysCall
from gql_http.status import Method
from gql_json.writer import JsonWriter


def _forge(name: String, token: String = "") raises -> Forge:
    var config = ForgeConfig()
    config.data_directory = fresh_directory(name)
    config.advertise_ip = "203.0.113.10"
    config.title = "Forge Lab"
    if token.byte_length() > 0:
        config.admin_token = token
    var forge = Forge(config^)
    forge.open()
    return forge^


def _post(
    mut forge: Forge, path: String, body: String, token: String = ""
) raises -> HttpAnswer:
    var header = Optional[String]()
    if token.byte_length() > 0:
        header = "Bearer " + token
    return forge.answer(Method.POST, path, "", header, body)


def test_auth_helpers() raises:
    assert_equal(bearer_token(None), "")
    assert_equal(bearer_token(Optional[String]("Basic x")), "")
    assert_equal(bearer_token(Optional[String]("Bearer abc")), "abc")
    assert_true(is_authorized(None, None))
    assert_false(is_authorized(Optional[String]("t"), None))
    assert_true(
        is_authorized(Optional[String]("t"), Optional[String]("Bearer t"))
    )
    var err = json_error(400, "nope")
    assert_equal(err.status, 400)
    assert_true(err.body.find("nope") >= 0)
    assert_equal(json_ok("{}").status, 200)


def test_pages_and_state() raises:
    var forge = _forge("srv")
    var page = forge.answer(Method.GET, "/", "", None, "")
    assert_equal(page.status, 200)
    assert_true(page.body.find("Forge") >= 0)
    var icon = forge.answer(Method.GET, "/favicon.svg", "", None, "")
    assert_true(icon.body.find("<svg") >= 0)
    var health = forge.answer(Method.GET, "/health", "", None, "")
    assert_true(health.body.find("pass") >= 0)
    var missing = forge.answer(Method.GET, "/nope", "", None, "")
    assert_equal(missing.status, 404)
    var state = forge.answer(Method.GET, "/forge/state", "", None, "")
    assert_true(state.body.find("203.0.113.10") >= 0)
    assert_true(state.body.find("organizations") >= 0)


def test_catalog_http() raises:
    var forge = _forge("http")
    var org = _post(forge, "/forge/orgs", '{"slug":"acme","name":"Acme"}')
    assert_equal(org.status, 200)
    var org_bad = _post(forge, "/forge/orgs", "")
    assert_equal(org_bad.status, 400)
    var graph = _post(
        forge, "/forge/graphs", '{"org":"acme","ref":"shop","name":"Shop"}'
    )
    assert_equal(graph.status, 200)
    var graph_bad = _post(forge, "/forge/graphs", "{")
    assert_equal(graph_bad.status, 400)
    var variant = _post(
        forge,
        "/forge/variants",
        '{"org":"acme","graph":"shop","name":"prod","endpointUrl":"http://127.0.0.1:9/graphql"}',
    )
    assert_equal(variant.status, 200)
    var variant_bad = _post(forge, "/forge/variants", "{}")
    assert_equal(variant_bad.status, 400)
    var staging = _post(
        forge,
        "/forge/variants",
        '{"org":"acme","graph":"shop","name":"staging","endpointUrl":"https://example/g"}',
    )
    assert_equal(staging.status, 200)
    var patch = forge.answer(
        Method.PATCH,
        "/forge/variants",
        "",
        None,
        '{"org":"acme","graph":"shop","name":"prod","endpointUrl":"http://127.0.0.1:8/","pullToken":"p"}',
    )
    assert_equal(patch.status, 200)
    var patch_bad = forge.answer(Method.PATCH, "/forge/variants", "", None, "")
    assert_equal(patch_bad.status, 400)
    var upload = _post(
        forge,
        "/forge/schema",
        '{"org":"acme","graph":"shop","name":"prod","sdl":'
        + _sdl_json(PRODUCTS_SDL)
        + "}",
    )
    assert_equal(upload.status, 200)
    var upload_bad = _post(forge, "/forge/schema", "{}")
    assert_equal(upload_bad.status, 400)
    var upload_err = _post(
        forge,
        "/forge/schema",
        '{"org":"acme","graph":"shop","name":"prod","sdl":"nope"}',
    )
    assert_equal(upload_err.status, 400)
    var pull = _post(
        forge, "/forge/pull", '{"org":"acme","graph":"shop","name":"staging"}'
    )
    assert_equal(pull.status, 400)
    var pull_bad = _post(forge, "/forge/pull", "")
    assert_equal(pull_bad.status, 400)
    var schema = forge.answer(
        Method.GET,
        "/forge/schema",
        "org=acme&graph=shop&variant=prod",
        None,
        "",
    )
    assert_equal(schema.status, 200)
    var schema_missing = forge.answer(
        Method.GET,
        "/forge/schema",
        "org=acme&graph=shop&name=staging",
        None,
        "",
    )
    assert_equal(schema_missing.status, 404)
    var index = forge.answer(
        Method.GET,
        "/forge/schema-index",
        "org=acme&graph=shop&variant=prod",
        None,
        "",
    )
    assert_equal(index.status, 200)
    var index_missing = forge.answer(
        Method.GET,
        "/forge/schema-index",
        "org=acme&graph=shop&variant=staging",
        None,
        "",
    )
    assert_equal(index_missing.status, 404)
    _ = _post(
        forge,
        "/forge/schema",
        '{"org":"acme","graph":"shop","name":"staging","sdl":'
        + _sdl_json(STAGING_SDL)
        + "}",
    )
    var cmp = forge.answer(
        Method.GET,
        "/forge/compare",
        "org=acme&graph=shop&from=prod&to=staging",
        None,
        "",
    )
    assert_equal(cmp.status, 200)
    var cmp_bad = forge.answer(
        Method.GET,
        "/forge/compare",
        "org=acme&graph=shop&from=prod&to=nope",
        None,
        "",
    )
    assert_equal(cmp_bad.status, 400)
    var insights = forge.answer(
        Method.GET,
        "/forge/insights",
        "org=acme&graph=shop&variant=prod",
        None,
        "",
    )
    assert_equal(insights.status, 200)
    var ops = forge.answer(
        Method.GET,
        "/forge/operations",
        "org=acme&graph=shop&variant=prod",
        None,
        "",
    )
    assert_equal(ops.status, 200)
    var analyze = _post(
        forge,
        "/forge/analyze",
        '{"org":"acme","graph":"shop","question":"health"}',
    )
    assert_equal(analyze.status, 200)
    var analyze_bad = _post(forge, "/forge/analyze", "")
    assert_equal(analyze_bad.status, 400)
    var method = forge.answer(Method.PUT, "/forge/state", "", None, "")
    assert_equal(method.status, 405)
    var remove = forge.answer(
        Method.DELETE,
        "/forge/variants",
        "",
        None,
        '{"org":"acme","graph":"shop","name":"staging"}',
    )
    assert_equal(remove.status, 200)
    var remove_bad = forge.answer(
        Method.DELETE, "/forge/variants", "", None, ""
    )
    assert_equal(remove_bad.status, 400)


def _sdl_json(sdl: String) -> String:
    var writer = JsonWriter()
    writer.string(sdl)
    return writer^.take_string()


def test_token_and_telemetry() raises:
    var forge = _forge("tok", "secret")
    var denied = forge.answer(Method.GET, "/forge/state", "", None, "")
    assert_equal(denied.status, 401)
    var ok = forge.answer(
        Method.GET, "/forge/state", "", Optional[String]("Bearer secret"), ""
    )
    assert_equal(ok.status, 200)
    _ = _post(forge, "/forge/orgs", '{"slug":"acme"}', "secret")
    _ = _post(forge, "/forge/graphs", '{"org":"acme","ref":"shop"}', "secret")
    _ = _post(
        forge,
        "/forge/variants",
        '{"org":"acme","graph":"shop","name":"prod","endpointUrl":"http://127.0.0.1/g"}',
        "secret",
    )
    var variant = forge.catalog.get_variant("acme", "shop", "prod")
    var tel = forge.answer(
        Method.POST,
        "/forge/telemetry",
        "",
        Optional[String]("Bearer " + variant.ingest_token),
        '{"org":"acme","graph":"shop","variant":"prod","name":"Q","durationMs":4}',
    )
    assert_equal(tel.status, 200)
    var admin_tel = forge.answer(
        Method.POST,
        "/forge/telemetry",
        "",
        Optional[String]("Bearer secret"),
        '{"org":"acme","graph":"shop","variant":"prod","name":"Q","durationMs":4}',
    )
    assert_equal(admin_tel.status, 200)
    var bad_tel = forge.answer(
        Method.POST,
        "/forge/telemetry",
        "",
        Optional[String]("Bearer nope"),
        '{"org":"acme","graph":"shop","variant":"prod","name":"Q","durationMs":4}',
    )
    assert_equal(bad_tel.status, 401)
    var missing_var = forge.answer(
        Method.POST,
        "/forge/telemetry",
        "",
        Optional[String]("Bearer secret"),
        '{"org":"acme","graph":"shop","variant":"nope","name":"Q"}',
    )
    assert_equal(missing_var.status, 404)
    var bad_json = forge.answer(Method.POST, "/forge/telemetry", "", None, "{")
    assert_equal(bad_json.status, 400)
    var open_forge = _forge("open")
    _ = _post(open_forge, "/forge/orgs", '{"slug":"acme"}')
    _ = _post(open_forge, "/forge/graphs", '{"org":"acme","ref":"shop"}')
    _ = _post(
        open_forge,
        "/forge/variants",
        '{"org":"acme","graph":"shop","name":"prod","endpointUrl":"http://127.0.0.1/g"}',
    )
    var open_variant = open_forge.catalog.get_variant("acme", "shop", "prod")
    var open_tel = open_forge.answer(
        Method.POST,
        "/forge/telemetry",
        "",
        Optional[String]("Bearer " + open_variant.ingest_token),
        '{"org":"acme","graph":"shop","variant":"prod","name":"Q","durationMs":1}',
    )
    assert_equal(open_tel.status, 200)
    var out = List[UInt8]()
    assert_equal(open_forge.poll_body(1, out), BodyPoll.DONE)
    open_forge.body_closed(1)
    var blank = open_forge.catalog.get_variant("acme", "shop", "prod")
    blank.ingest_token = String("")
    open_forge.catalog.save_variant(blank)
    var no_token = open_forge.answer(
        Method.POST,
        "/forge/telemetry",
        "",
        None,
        '{"org":"acme","graph":"shop","variant":"prod","name":"Q","durationMs":1}',
    )
    assert_equal(no_token.status, 200)


def test_handle_and_serve() raises:
    var forge = _forge("hdl")
    var reader = RequestReader(Limits())
    reader.append("GET /health HTTP/1.1\r\nHost: x\r\n\r\n".as_bytes())
    assert_equal(reader.next().state, ParseState.COMPLETE)
    var response = ResponseWriter()
    forge.handle(reader.request, response)
    assert_true(String(unsafe_from_utf8=response.body).find("pass") >= 0)
    var auth_reader = RequestReader(Limits())
    auth_reader.append(
        "GET /health HTTP/1.1\r\nHost: x\r\nAuthorization: Bearer t\r\n\r\n"
        .as_bytes()
    )
    assert_equal(auth_reader.next().state, ParseState.COMPLETE)
    var auth_response = ResponseWriter()
    forge.handle(auth_reader.request, auth_response)
    assert_equal(auth_response.status.code, 200)
    var quiet = ForgeConfig()
    quiet.data_directory = fresh_directory("noip")
    var open_forge = Forge(quiet^)
    open_forge.open()
    var state = open_forge.answer(Method.GET, "/forge/state", "", None, "")
    assert_true(state.body.find("advertiseIp") >= 0)
    with assert_raises():
        _ = forge.answer(Method.GET, "/forge/schema", "org=%ZZ", None, "")
    var missing_coords = forge.answer(Method.GET, "/forge/schema", "", None, "")
    assert_equal(missing_coords.status, 404)
    var schema_dir = forge.catalog.store.schema_dir("acme", "shop", "ghost")
    makedirs(schema_dir, exist_ok=True)
    write_file_atomic(
        forge.catalog.store.current_schema_path("acme", "shop", "ghost"), "1\n"
    )
    write_file_atomic(
        forge.catalog.store.schema_path("acme", "shop", "ghost", 1), "not sdl"
    )
    var bad_index = forge.answer(
        Method.GET,
        "/forge/schema-index",
        "org=acme&graph=shop&variant=ghost",
        None,
        "",
    )
    assert_equal(bad_index.status, 400)
    var sys = Sys()
    var faults = Faults()
    faults.call = SysCall.SOCKET
    faults.errno = 24
    faults.count = 1
    sys.faults = faults^
    var boom = _forge("serve")
    var http = ServerConfig()
    with assert_raises():
        serve_forge(boom^, http, sys^)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

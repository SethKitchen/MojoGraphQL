# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_forge.pull`."""

from _fixtures import PRODUCTS_SDL, seeded_catalog
from gql_forge.pull import (
    introspection_body,
    pull_variant,
    read_introspection_sdl,
    record_pull_error,
    store_schema_sdl,
    upload_schema,
)
from gql_http.body import BodyPoll
from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter, ServerConfig, start_workers
from gql_http.socket import IPv4Address
from gql_http.status import Status
from gql_json.writer import stringify
from gql_schema.build import build_schema
from gql_schema.introspection import introspection_from_schema
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_true,
    assert_raises,
)


def test_read_introspection_sdl() raises:
    var data = introspection_from_schema(build_schema(PRODUCTS_SDL))
    var body = '{"data":' + stringify(data, data.root) + "}"
    var sdl = read_introspection_sdl(200, List[UInt8](body.as_bytes()))
    assert_true(sdl.find("type Product") >= 0)
    with assert_raises(contains="HTTP 500"):
        _ = read_introspection_sdl(500, List[UInt8]("x".as_bytes()))
    with assert_raises(contains="not a JSON object"):
        _ = read_introspection_sdl(200, List[UInt8]("[]".as_bytes()))
    with assert_raises(contains="the graph answered:"):
        _ = read_introspection_sdl(
            200, List[UInt8]('{"errors":[{"message":"boom"}]}'.as_bytes())
        )
    with assert_raises(contains="GraphQL errors"):
        _ = read_introspection_sdl(
            200, List[UInt8]('{"errors":[1]}'.as_bytes())
        )
    with assert_raises(contains="no data object"):
        _ = read_introspection_sdl(200, List[UInt8]("{}".as_bytes()))
    _ = introspection_body()


def test_upload_and_store() raises:
    var catalog = seeded_catalog("pull")
    var missing = upload_schema(catalog, "acme", "shop", "nope", PRODUCTS_SDL)
    assert_true(missing.find("not in Forge") >= 0)
    var bad = upload_schema(catalog, "acme", "shop", "prod", "not sdl")
    assert_true(bad.find("error") >= 0)
    var ok = upload_schema(catalog, "acme", "shop", "prod", PRODUCTS_SDL)
    assert_true(ok.find("revision") >= 0)
    assert_true(ok.find('"changed":true') >= 0)
    var again = upload_schema(catalog, "acme", "shop", "prod", PRODUCTS_SDL)
    assert_true(again.find("revision") >= 0)
    # The same SDL again keeps the current snapshot.
    assert_true(again.find('"changed":false') >= 0)
    var prod = catalog.get_variant("acme", "shop", "prod")
    assert_true(prod.last_pull_ok)
    assert_true(prod.schema_revision >= 1)
    record_pull_error(catalog, prod, String("x"))
    assert_false(catalog.get_variant("acme", "shop", "prod").last_pull_ok)
    var https = pull_variant(catalog, "acme", "shop", "staging")
    assert_true(https.find("http://") >= 0)
    var none = pull_variant(catalog, "acme", "shop", "nope")
    assert_true(none.find("not in Forge") >= 0)
    var fail = pull_variant(catalog, "acme", "shop", "prod", 10)
    assert_true(fail.find("error") >= 0)


struct _Graph(Handler):
    """A customer graph: it answers introspection when the pull token is
    right, and 401 otherwise."""

    def __init__(out self):
        pass

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        var authorization = request.header("authorization")
        if not authorization or authorization.value() != StaticString(
            "Bearer p"
        ):
            response.set_status(Status.UNAUTHORIZED)
            return
        var data = introspection_from_schema(build_schema(PRODUCTS_SDL))
        response.add_header("Content-Type", "application/json")
        response.write_text('{"data":' + stringify(data, data.root) + "}")

    def poll_body(mut self, id: Int, mut out: List[UInt8]) raises -> BodyPoll:
        return BodyPoll.DONE

    def body_closed(mut self, id: Int):
        pass


def test_a_pull_stores_the_schema() raises:
    var config = ServerConfig()
    config.host = IPv4Address.LOOPBACK
    config.port = 0
    var pool = start_workers(_Graph(), config)
    var url = "http://127.0.0.1:" + String(pool.port) + "/graphql"
    var catalog = seeded_catalog("pull_ok")
    _ = catalog.update_variant(
        "acme", "shop", "prod", Optional[String](url), Optional[String]("p")
    )
    var pulled = pull_variant(catalog, "acme", "shop", "prod")
    assert_true(pulled.find('"revision":1') >= 0, pulled)
    var prod = catalog.get_variant("acme", "shop", "prod")
    assert_true(prod.last_pull_ok)
    assert_equal(prod.schema_revision, 1)
    # The same schema again keeps the revision.
    var again = pull_variant(catalog, "acme", "shop", "prod")
    assert_true(again.find('"revision":1') >= 0, again)
    # A wrong pull token gets 401, and the variant records the error.
    _ = catalog.update_variant(
        "acme", "shop", "prod", None, Optional[String]("wrong")
    )
    var refused = pull_variant(catalog, "acme", "shop", "prod")
    assert_true(refused.find("HTTP 401") >= 0, refused)
    assert_false(catalog.get_variant("acme", "shop", "prod").last_pull_ok)
    assert_equal(pool.stop(), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

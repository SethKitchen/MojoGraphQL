# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_forge.store`."""

from std.os import makedirs

from _fixtures import fresh_directory
from gql_forge.store import (
    Store,
    parse_object,
    read_file,
    read_object_bool,
    read_object_int,
    read_object_string,
    read_object_string_or,
    unix_time,
    write_file_atomic,
)
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)


def test_unix_time() raises:
    assert_true(unix_time() > 0)


def test_files_and_revision() raises:
    var store = Store(fresh_directory("store"))
    store.open()
    assert_equal(store.revision(), 0)
    assert_equal(store.advertise_ip(), "")
    assert_equal(store.bump_revision(), 1)
    assert_equal(store.revision(), 1)
    store.set_advertise_ip("203.0.113.10")
    assert_equal(store.advertise_ip(), "203.0.113.10")
    assert_true(store.org_path("acme").endswith("/orgs/acme.json"))
    assert_true(
        store.graph_path("acme", "shop").find("/graphs/acme/shop.json") >= 0
    )
    assert_true(
        store.variant_path("acme", "shop", "prod").find(
            "/variants/acme/shop/prod.json"
        )
        >= 0
    )
    assert_true(
        store.schema_path("acme", "shop", "prod", 3).find(
            "/schemas/acme/shop/prod/3.graphql"
        )
        >= 0
    )
    assert_true(
        store.current_schema_path("acme", "shop", "prod").endswith("/current")
    )
    assert_true(
        store.telemetry_path("acme", "shop", "prod").endswith(
            "/telemetry/acme/shop/prod.json"
        )
    )
    assert_false(store.exists_file(store.org_path("missing")))
    store.write_json(store.org_path("acme"), '{"slug":"acme"}')
    assert_true(store.exists_file(store.org_path("acme")))
    assert_equal(read_file(store.org_path("acme")), '{"slug":"acme"}')


def test_json_helpers() raises:
    var document = parse_object('{"name":"x","n":12,"flag":true,"bad":"soon"}')
    var root = document.root
    assert_equal(read_object_string(document, root, "name"), "x")
    assert_equal(read_object_string_or(document, root, "name", "z"), "x")
    assert_equal(read_object_string_or(document, root, "nope", "z"), "z")
    assert_equal(read_object_int(document, root, "n", 0), 12)
    assert_equal(read_object_int(document, root, "nope", 7), 7)
    assert_equal(read_object_int(document, root, "bad", 7), 7)
    var float_doc = parse_object('{"n":1.5}')
    assert_equal(read_object_int(float_doc, float_doc.root, "n", 7), 7)
    assert_true(read_object_bool(document, root, "flag", False))
    assert_false(read_object_bool(document, root, "nope", False))
    with assert_raises(contains="no string missing"):
        _ = read_object_string(document, root, "missing")
    with assert_raises(contains="not an object"):
        _ = parse_object("[]")


def test_write_file_atomic_round_trip() raises:
    var path = fresh_directory("atomic") + "/file.txt"
    var store = Store(fresh_directory("atomic-parent"))
    store.open()
    write_file_atomic(store.directory + "/note.txt", "hello")
    assert_equal(read_file(store.directory + "/note.txt"), "hello")
    write_file_atomic(store.revision_path(), "nope\n")
    assert_equal(store.revision(), 0)
    var blocked = store.directory + "/blocked"
    makedirs(blocked, exist_ok=True)
    with assert_raises(contains="cannot rename"):
        write_file_atomic(blocked, "x")
    _ = path


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the subgraph registry, `gql_scorchql.registry`.

ScorchQL has no upstream, so there is no upstream test suite to port. The
publish cases follow the GraphOS documentation of `rover subgraph publish`:
a publish that composes is accepted, and one that does not is refused.
"""

from std.os import makedirs
from std.os.path import exists

from _fixtures import CONFLICT_SDL, PRODUCTS_SDL, REVIEWS_SDL, fresh_directory
from gql_scorchql.registry import (
    PublishedSubgraph,
    Registry,
    compose_published,
    file_changed_at,
    is_valid_routing_url,
    is_valid_subgraph_name,
    parse_subgraph_json,
    publish_errors,
    read_file,
    subgraph_json,
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

comptime PRODUCTS_URL = "http://127.0.0.1:4001/"
comptime REVIEWS_URL = "http://127.0.0.1:4002/"


def test_subgraph_names() raises:
    assert_true(is_valid_subgraph_name("products"))
    assert_true(is_valid_subgraph_name("Products_v2-eu"))
    assert_true(is_valid_subgraph_name("a"))
    assert_true(is_valid_subgraph_name("Z9"))
    assert_true(is_valid_subgraph_name("a" * 64))
    assert_false(is_valid_subgraph_name(""))
    assert_false(is_valid_subgraph_name("a" * 65))
    assert_false(is_valid_subgraph_name("9products"))
    assert_false(is_valid_subgraph_name("_products"))
    assert_false(is_valid_subgraph_name("pro ducts"))
    assert_false(is_valid_subgraph_name("pro/ducts"))
    assert_false(is_valid_subgraph_name("pro.ducts"))
    # The bounds of each letter range.
    assert_true(is_valid_subgraph_name("AZaz"))
    assert_false(is_valid_subgraph_name("@"))
    assert_false(is_valid_subgraph_name("["))
    assert_false(is_valid_subgraph_name("`"))
    assert_false(is_valid_subgraph_name("{"))
    assert_false(is_valid_subgraph_name("a:"))
    assert_false(is_valid_subgraph_name("a/"))


def test_routing_urls() raises:
    assert_true(is_valid_routing_url("http://localhost:4001/"))
    assert_true(is_valid_routing_url("http://a"))
    assert_false(is_valid_routing_url("http://"))
    assert_false(is_valid_routing_url("https://example.com/"))
    assert_false(is_valid_routing_url("localhost:4001"))


def test_publish_errors() raises:
    assert_equal(len(publish_errors("products", PRODUCTS_URL)), 0)
    var both = publish_errors("9", "ftp://x")
    assert_equal(len(both), 2)
    assert_true(both[0].startswith("Invalid subgraph name '9'"))
    assert_equal(
        both[1], "Invalid routing URL 'ftp://x': it must start with http://."
    )
    assert_equal(len(publish_errors("ok", "ftp://x")), 1)
    assert_equal(len(publish_errors("9", PRODUCTS_URL)), 1)


def test_subgraph_json_round_trip() raises:
    var subgraph = PublishedSubgraph(
        "products", PRODUCTS_URL, 'type Query { a: String }\n"x"', 42
    )
    var text = subgraph_json(subgraph)
    assert_equal(
        text,
        (
            '{"name":"products","url":"http://127.0.0.1:4001/","sdl":"type'
            ' Query { a: String }\\n\\"x\\"","publishedAt":42}'
        ),
    )
    var back = parse_subgraph_json(text)
    assert_equal(back.name, "products")
    assert_equal(back.url, PRODUCTS_URL)
    assert_equal(back.sdl, subgraph.sdl)
    assert_equal(back.published_at, 42)


def test_subgraph_json_errors() raises:
    with assert_raises(contains="not a JSON object"):
        _ = parse_subgraph_json("[]")
    with assert_raises(contains="no string url"):
        _ = parse_subgraph_json('{"name":"a","sdl":"x"}')
    with assert_raises(contains="no string sdl"):
        _ = parse_subgraph_json('{"name":"a","url":"u","sdl":1}')
    var untimed = parse_subgraph_json('{"name":"a","url":"u","sdl":"s"}')
    assert_equal(untimed.published_at, 0)
    var text_time = parse_subgraph_json(
        '{"name":"a","url":"u","sdl":"s","publishedAt":"soon"}'
    )
    assert_equal(text_time.published_at, 0)


def test_compose_published() raises:
    var subgraphs = List[PublishedSubgraph]()
    subgraphs.append(
        PublishedSubgraph("products", PRODUCTS_URL, PRODUCTS_SDL, 0)
    )
    var composed = compose_published(subgraphs)
    assert_equal(len(composed[1]), 0)
    assert_true("join__Graph" in composed[0])
    subgraphs.append(
        PublishedSubgraph("broken", PRODUCTS_URL, "type Query {", 0)
    )
    var syntax = compose_published(subgraphs)
    assert_equal(syntax[0], "")
    assert_equal(len(syntax[1]), 1)
    assert_true(syntax[1][0].startswith("[broken] "))
    subgraphs[1] = PublishedSubgraph("bad", PRODUCTS_URL, CONFLICT_SDL, 0)
    var conflict = compose_published(subgraphs)
    assert_equal(conflict[0], "")
    assert_true(len(conflict[1]) > 0)
    assert_true("incompatible" in conflict[1][0])


def test_compose_published_reports_a_raised_error() raises:
    var subgraphs = List[PublishedSubgraph]()
    subgraphs.append(
        PublishedSubgraph(
            "products",
            PRODUCTS_URL,
            (
                "extend schema @link(url:"
                ' "https://specs.apollo.dev/federation/v2.3", import:'
                " [1])\ntype Query { a: String }"
            ),
            0,
        )
    )
    var composed = compose_published(subgraphs)
    assert_equal(composed[0], "")
    assert_equal(len(composed[1]), 1)


def test_an_empty_registry() raises:
    var registry = Registry(fresh_directory("empty"))
    assert_equal(registry.revision(), 0)
    assert_false(registry.supergraph())
    assert_equal(len(registry.subgraphs()), 0)
    registry.open()
    assert_true(exists(registry.directory + "/subgraphs"))
    assert_equal(len(registry.subgraphs()), 0)
    assert_equal(
        registry.subgraph_path("a"), registry.directory + "/subgraphs/a.json"
    )


def test_publish_composes_and_counts_revisions() raises:
    var registry = Registry(fresh_directory("publish"))
    var first = registry.publish("products", PRODUCTS_URL, PRODUCTS_SDL)
    assert_true(first.accepted)
    assert_true(first.changed)
    assert_equal(first.revision, 1)
    assert_equal(len(first.errors), 0)
    assert_true(registry.supergraph().value().startswith("schema @link"))
    var same = registry.publish("products", PRODUCTS_URL, PRODUCTS_SDL)
    assert_true(same.accepted)
    assert_false(same.changed)
    assert_equal(same.revision, 1)
    var second = registry.publish("reviews", REVIEWS_URL, REVIEWS_SDL)
    assert_true(second.changed)
    assert_equal(second.revision, 2)
    var moved = registry.publish("products", REVIEWS_URL, PRODUCTS_SDL)
    assert_true(moved.changed)
    assert_equal(moved.revision, 3)
    var listed = registry.subgraphs()
    assert_equal(len(listed), 2)
    assert_equal(listed[0].name, "products")
    assert_equal(listed[0].url, REVIEWS_URL)
    assert_equal(listed[1].name, "reviews")
    assert_true(listed[1].published_at > 1_700_000_000)
    assert_true(
        'url: "http://127.0.0.1:4002/"' in registry.supergraph().value()
    )
    assert_equal(read_file(registry.revision_path()), "3\n")


def test_a_publish_with_new_sdl_is_a_change() raises:
    var registry = Registry(fresh_directory("sdl"))
    _ = registry.publish("products", PRODUCTS_URL, PRODUCTS_SDL)
    var edited = registry.publish(
        "products", PRODUCTS_URL, PRODUCTS_SDL + "\ntype Extra { a: Int }\n"
    )
    assert_true(edited.changed)
    assert_equal(edited.revision, 2)


def test_a_publish_that_does_not_compose_is_refused() raises:
    var registry = Registry(fresh_directory("refuse"))
    _ = registry.publish("products", PRODUCTS_URL, PRODUCTS_SDL)
    var refused = registry.publish("bad", REVIEWS_URL, CONFLICT_SDL)
    assert_false(refused.accepted)
    assert_false(refused.changed)
    assert_equal(refused.revision, 1)
    assert_true(len(refused.errors) > 0)
    assert_equal(len(registry.subgraphs()), 1)
    assert_false(exists(registry.subgraph_path("bad")))


def test_a_publish_with_a_bad_name_or_url_is_refused() raises:
    var registry = Registry(fresh_directory("names"))
    var refused = registry.publish("../x", "ftp://x", PRODUCTS_SDL)
    assert_false(refused.accepted)
    assert_equal(len(refused.errors), 2)
    assert_equal(refused.revision, 0)
    assert_false(exists(registry.directory))


def test_remove() raises:
    var registry = Registry(fresh_directory("remove"))
    var unknown = registry.remove("products")
    assert_false(unknown.accepted)
    assert_equal(
        unknown.errors[0], "No subgraph named 'products' is published."
    )
    var bad_name = registry.remove("../etc")
    assert_false(bad_name.accepted)
    _ = registry.publish("products", PRODUCTS_URL, PRODUCTS_SDL)
    _ = registry.publish("reviews", REVIEWS_URL, REVIEWS_SDL)
    var removed = registry.remove("reviews")
    assert_true(removed.accepted)
    assert_true(removed.changed)
    assert_equal(removed.revision, 3)
    assert_false("REVIEWS" in registry.supergraph().value())
    var last = registry.remove("products")
    assert_true(last.accepted)
    assert_equal(last.revision, 4)
    assert_false(registry.supergraph())
    assert_equal(len(registry.subgraphs()), 0)


def test_a_removal_that_does_not_compose_is_refused() raises:
    var directory = fresh_directory("remove_refused")
    var registry = Registry(directory)
    _ = registry.publish("products", PRODUCTS_URL, PRODUCTS_SDL)
    _ = registry.publish("reviews", REVIEWS_URL, REVIEWS_SDL)
    # A subgraph that only extends Product cannot be composed alone: it has
    # no query type.
    var refused = registry.remove("products")
    assert_false(refused.accepted)
    assert_true(len(refused.errors) > 0)
    assert_equal(refused.revision, 2)
    assert_true(exists(registry.subgraph_path("products")))


def test_a_bad_revision_file_reads_as_zero() raises:
    var registry = Registry(fresh_directory("revision"))
    registry.open()
    write_file_atomic(registry.revision_path(), "seven\n")
    assert_equal(registry.revision(), 0)


def test_a_bad_registry_file_raises() raises:
    var registry = Registry(fresh_directory("corrupt"))
    registry.open()
    write_file_atomic(registry.subgraph_path("x"), "{")
    with assert_raises():
        _ = registry.subgraphs()
    with assert_raises():
        _ = registry.publish("products", PRODUCTS_URL, PRODUCTS_SDL)


def test_other_files_in_the_registry_are_ignored() raises:
    var registry = Registry(fresh_directory("other"))
    _ = registry.publish("products", PRODUCTS_URL, PRODUCTS_SDL)
    write_file_atomic(registry.directory + "/subgraphs/notes.txt", "hello")
    assert_equal(len(registry.subgraphs()), 1)


def test_files() raises:
    var directory = fresh_directory("files")
    makedirs(directory, exist_ok=True)
    var path = directory + "/a.txt"
    assert_equal(file_changed_at(path), -1)
    write_file_atomic(path, "one")
    assert_equal(read_file(path), "one")
    assert_true(file_changed_at(path) > 0)
    assert_false(exists(path + ".tmp"))
    with assert_raises(contains="cannot rename"):
        write_file_atomic(directory, "x")
    assert_false(exists(directory + ".tmp"))
    with assert_raises():
        _ = read_file(directory + "/missing")
    with assert_raises():
        write_file_atomic(path + "/a.txt", "x")
    assert_true(unix_time() > 1_700_000_000)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

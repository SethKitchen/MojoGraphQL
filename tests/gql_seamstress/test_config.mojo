# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the supergraph configuration.

Ported from `apollo-federation-types` 0.18.0-rc.1 `src/config/supergraph.rs`
(the `it_can_parse_*`, `it_errors_*` and `it_errs_on_bad_version*` tests)
and `src/config/subgraph.rs` (`test_schema_source`).
"""

from gql_seamstress.config import SchemaSourceKind, SupergraphConfig, is_url
from gql_seamstress.config import normalize_url, parse_supergraph_config
from gql_seamstress.federation_version import FEDERATION_ONE_UNSUPPORTED
from gql_seamstress.federation_version import FederationVersionKind
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime _FILMS_PEOPLE = """subgraphs:
  films:
    routing_url: https://films.example.com
    schema:
      file: ./good-films.graphql
  people:
    routing_url: https://people.example.com
    schema:
      file: ./good-people.graphql
"""

comptime _JSON_BODY = """"subgraphs": {
      "films": {
        "routing_url": "https://films.example.com",
        "schema": { "file": "./good-films.graphql" }
      },
      "people": {
        "routing_url": "https://people.example.com",
        "schema": { "file": "./good-people.graphql" }
      }
    }"""


def _version_kind(text: String) raises -> FederationVersionKind:
    return parse_supergraph_config(text).federation_version.value().kind


def _error(text: String) raises -> String:
    try:
        _ = parse_supergraph_config(text)
    except e:
        return String(e)
    raise Error("no error for: " + text)


def test_it_can_parse_valid_config_without_version() raises:
    var config = parse_supergraph_config("---\n" + _FILMS_PEOPLE)
    assert_false(config.federation_version.__bool__())
    assert_equal(len(config.subgraphs), 2)
    assert_equal(config.subgraphs[0].name, "films")
    assert_equal(
        config.subgraphs[0].routing_url.value(), "https://films.example.com"
    )
    assert_equal(config.subgraphs[1].schema.file, "./good-people.graphql")
    var json = parse_supergraph_config("{\n    " + _JSON_BODY + "\n  }\n")
    assert_false(json.federation_version.__bool__())
    assert_equal(len(json.subgraphs), 2)


def test_it_can_parse_valid_config_versions() raises:
    assert_true(
        _version_kind("---\nfederation_version: 0\n" + _FILMS_PEOPLE)
        == FederationVersionKind.LATEST_FED_ONE
    )
    assert_true(
        _version_kind("---\nfederation_version: 1\n" + _FILMS_PEOPLE)
        == FederationVersionKind.LATEST_FED_ONE
    )
    assert_true(
        _version_kind("---\nfederation_version: 2\n" + _FILMS_PEOPLE)
        == FederationVersionKind.LATEST_FED_TWO
    )
    assert_true(
        _version_kind("---\nfederation_version: =0.36.0\n" + _FILMS_PEOPLE)
        == FederationVersionKind.EXACT_FED_ONE
    )
    assert_true(
        _version_kind("---\nfederation_version: =2.0.0\n" + _FILMS_PEOPLE)
        == FederationVersionKind.EXACT_FED_TWO
    )
    assert_true(
        _version_kind('{"federation_version": 0, ' + _JSON_BODY + "}")
        == FederationVersionKind.LATEST_FED_ONE
    )
    assert_true(
        _version_kind('{"federation_version": 2, ' + _JSON_BODY + "}")
        == FederationVersionKind.LATEST_FED_TWO
    )
    assert_true(
        _version_kind('{"federation_version": "=2.0.0", ' + _JSON_BODY + "}")
        == FederationVersionKind.EXACT_FED_TWO
    )
    assert_false(
        parse_supergraph_config(
            "federation_version: null\nsubgraphs: {}\n"
        ).federation_version.__bool__()
    )


def test_it_can_parse_valid_config_with_introspection() raises:
    var config = parse_supergraph_config(
        "subgraphs:\n  films:\n    routing_url: https://films.example.com\n   "
        " schema:\n      file: ./films.graphql\n  people:\n    schema:\n     "
        " subgraph_url: https://people.example.com\n  robots:\n    routing_url:"
        ' https://robots.example.com\n    schema:\n      sdl: "type Query {'
        ' robot: String }"\n'
    )
    assert_equal(len(config.subgraphs), 3)
    assert_true(
        config.subgraphs[1].schema.kind
        == SchemaSourceKind.SUBGRAPH_INTROSPECTION
    )
    assert_equal(
        config.subgraphs[1].schema.subgraph_url, "https://people.example.com/"
    )
    assert_false(config.subgraphs[1].routing_url.__bool__())
    assert_true(config.subgraphs[2].schema.kind == SchemaSourceKind.SDL)
    var json = parse_supergraph_config(
        '{"subgraphs": {"people": {"schema": {"subgraph_url":'
        ' "https://people.example.com"}}}}'
    )
    assert_equal(
        json.subgraphs[0].schema.subgraph_url, "https://people.example.com/"
    )


def test_it_errors_on_invalid_config() raises:
    var bad = (
        "subgraphs:\n  films:\n    routing_url: https://films.example.com\n   "
        " schemaaa:\n        file:: ./good-films.graphql\n  people:\n   "
        " routing_url: https://people.example.com\n    schema_____file:"
        " ./good-people.graphql"
    )
    assert_equal(_error(bad), "subgraphs.films: missing field `schema`")


def test_it_errs_on_bad_version() raises:
    assert_equal(
        _error("---\nfederation_version: 4\n" + _FILMS_PEOPLE),
        "federation_version: specified version `4` is not supported",
    )
    assert_equal(
        _error('{"federation_version": 4, ' + _JSON_BODY + "}"),
        "federation_version: specified version `4` is not supported",
    )
    assert_equal(
        _error("federation_version: latest\nsubgraphs: {}\n"),
        (
            "federation_version: Specified version `latest` is not supported."
            " You can either specify '1', '2', '3', or a fully qualified"
            " version prefixed with an '=', like: =2.0.0"
        ),
    )
    assert_equal(
        _error("federation_version: =1.2.0\nsubgraphs: {}\n"),
        FEDERATION_ONE_UNSUPPORTED,
    )
    var expected = (
        ", expected literal '1', '2' or '3' (as a string or number), or a fully"
        " qualified version prefixed with an '=', like: =2.0.0"
    )
    assert_equal(
        _error("federation_version: true\nsubgraphs: {}\n"),
        "federation_version: invalid type: boolean `true`" + expected,
    )
    assert_equal(
        _error("federation_version: false\nsubgraphs: {}\n"),
        "federation_version: invalid type: boolean `false`" + expected,
    )
    assert_equal(
        _error("federation_version: =0.20.0\nsubgraphs: {}\n"),
        FEDERATION_ONE_UNSUPPORTED,
    )
    assert_equal(
        _error('{"federation_version": 2.5, "subgraphs": {}}'),
        "federation_version: invalid type: integer `2.5`" + expected,
    )
    assert_equal(
        _error("federation_version: 123456\nsubgraphs: {}\n"),
        "federation_version: invalid type: integer `123456`" + expected,
    )


def test_schema_sources() raises:
    var config = parse_supergraph_config(
        "subgraphs:\n  a:\n    schema:\n      file: some/path.thing\n  b:\n   "
        " schema:\n      subgraph_url: https://example.com/graphql\n  c:\n   "
        " schema:\n      subgraph_url: https://example.com/graphql\n     "
        " introspection_headers:\n        Router-Authorization:"
        " ${env.HELLO_TESTS}\n        A-First: x\n  d:\n    schema:\n     "
        " graphref: my-graph@current\n      subgraph: my-subgraph\n  e:\n   "
        " schema:\n      sdl: |\n        type Query {\n            hello:"
        " String\n        }\n  f:\n    schema:\n      subgraph_url: x:y\n     "
        " introspection_headers: null\n"
    )
    ref s = config.subgraphs
    assert_true(s[0].schema.kind == SchemaSourceKind.FILE)
    assert_equal(s[0].schema.file, "some/path.thing")
    assert_equal(len(s[1].schema.introspection_headers), 0)
    assert_equal(len(s[2].schema.introspection_headers), 2)
    assert_equal(s[2].schema.introspection_headers[0].name, "A-First")
    assert_equal(
        s[2].schema.introspection_headers[1].value, "${env.HELLO_TESTS}"
    )
    assert_true(s[3].schema.kind == SchemaSourceKind.SUBGRAPH)
    assert_equal(s[3].schema.graphref, "my-graph@current")
    assert_equal(s[3].schema.subgraph, "my-subgraph")
    assert_equal(s[4].schema.sdl, "type Query {\n    hello: String\n}\n")
    assert_equal(s[5].schema.subgraph_url, "x:y")
    var json = parse_supergraph_config(
        '{"subgraphs": {"z": {"schema": {"sdl": "z"}}, "a": {"schema":'
        ' {"subgraph_url": "http://a", "introspection_headers": {"b": "1",'
        ' "a": "2", "b": "3"}}}, "z": {"schema": {"file": "f"}}}}'
    )
    assert_equal(len(json.subgraphs), 2)
    assert_equal(json.subgraphs[0].name, "a")
    assert_equal(len(json.subgraphs[0].schema.introspection_headers), 2)
    assert_equal(json.subgraphs[0].schema.introspection_headers[1].value, "3")
    assert_true(json.subgraphs[1].schema.kind == SchemaSourceKind.FILE)


def test_structure_errors() raises:
    var mismatch = (
        "subgraphs.a.schema: data did not match any variant of untagged enum"
        " SchemaSource"
    )
    for schema in [
        "file: 1",
        "subgraph_url: not a url",
        "sdl: 5",
        "graphref: g",
        "subgraph_url: http://x\n      introspection_headers: 5",
        "subgraph_url: http://x\n      introspection_headers:\n        a: 1",
    ]:
        assert_equal(
            _error("subgraphs:\n  a:\n    schema:\n      " + schema + "\n"),
            mismatch,
        )
    assert_equal(_error("subgraphs:\n  a:\n    schema: x\n"), mismatch)
    assert_equal(
        _error("subgraphs:\n  a: 5\n"),
        (
            "subgraphs.a: invalid type: integer `5`, expected struct"
            " SubgraphConfig"
        ),
    )
    assert_equal(
        _error(
            "subgraphs:\n  a:\n    routing_url: 5\n    schema:\n      file: f\n"
        ),
        "subgraphs.a.routing_url: invalid type: integer `5`, expected a string",
    )
    assert_equal(
        _error(
            "subgraphs:\n  a:\n    routing_url:\n      x: 1\n    schema:\n     "
            " file: f\n"
        ),
        "subgraphs.a.routing_url: invalid type: map, expected a string",
    )
    assert_true(
        _error('{"federation_version": 1e5, "subgraphs": {}}').startswith(
            "federation_version: invalid type: integer `1e5`"
        )
    )
    var headers = parse_supergraph_config(
        '{"subgraphs": {"a": {"schema": {"subgraph_url": "http://a",'
        ' "introspection_headers": {"a": "1", "b": "2"}}}, "b": {"schema":'
        ' {"subgraph_url": "http://b", "introspection_headers": {}}}}}'
    )
    assert_equal(headers.subgraphs[0].schema.introspection_headers[1].name, "b")
    assert_equal(len(headers.subgraphs[1].schema.introspection_headers), 0)
    assert_equal(
        _error("subgraphs: x\n"),
        'subgraphs: invalid type: string "x", expected a map',
    )
    assert_equal(
        _error("subgraphs:\n- a\n"),
        "subgraphs: invalid type: sequence, expected a map",
    )
    assert_equal(_error("federation_version: 2\n"), "missing field `subgraphs`")
    assert_equal(_error(""), "missing field `subgraphs`")
    assert_equal(
        _error("- 1\n"),
        "invalid type: sequence, expected struct SupergraphConfig",
    )
    assert_equal(
        _error("x\n"),
        'invalid type: string "x", expected struct SupergraphConfig',
    )
    assert_equal(_error('{"a": {}}'), "missing field `subgraphs`")
    assert_equal(_error('{"subgraphs": {"a": {"schema": null}}}'), mismatch)
    assert_equal(
        _error('{"subgraphs": {"a": null}}'),
        "subgraphs.a: invalid type: unit value, expected struct SubgraphConfig",
    )
    assert_equal(
        _error(
            '{"subgraphs": {"a": {"routing_url": null, "schema": {"x": 1}}}}'
        ),
        mismatch,
    )


def test_kinds_and_urls() raises:
    assert_true(SchemaSourceKind.SDL.is_valid())
    assert_false(SchemaSourceKind(4).is_valid())
    assert_equal(
        String(SchemaSourceKind.SUBGRAPH_INTROSPECTION), "SubgraphIntrospection"
    )
    assert_equal(String(SchemaSourceKind(7)), "<invalid>")
    assert_equal(
        normalize_url("HTTP://Example.COM:4001"), "http://example.com:4001/"
    )
    assert_equal(
        normalize_url("https://x.dev/a/B?q=1"), "https://x.dev/a/B?q=1"
    )
    assert_equal(normalize_url("http://x?q#f"), "http://x/?q#f")
    assert_equal(normalize_url("http://x#f"), "http://x/#f")
    assert_equal(normalize_url("mailto:A@B"), "mailto:A@B")
    assert_equal(normalize_url("http:x"), "http:x")
    assert_equal(normalize_url("http://"), "http:///")
    assert_true(is_url("a+b.c-d9:x"))
    assert_true(is_url("Ab:x"))
    assert_false(is_url("~a:x"))
    assert_false(is_url("_a:x"))
    assert_false(is_url("a"))
    for text in ["", "1abc:x", "a b:x", "abc", "abc:", ":x"]:
        assert_false(is_url(text), text)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

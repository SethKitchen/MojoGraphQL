# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `seamstress supergraph compose`.

A configuration that names the subgraph files of a Hive fixture must give
the supergraph that Hive `composeServices` prints for them. The error
cases give the messages of Rover 1.0.0 `src/composition` and
`src/command/supergraph/compose`.
"""

from std.os import makedirs
from _compose_fixture import BASIC_SDL, BASIC_SUBGRAPHS, BASIC_SUPERGRAPH
from _compose_fixture import STARS_STUFF_SDL, STARS_STUFF_SUBGRAPHS
from _compose_fixture import STARS_STUFF_SUPERGRAPH
from _endpoint import start_endpoint
from gql_composition.compose import compose_subgraphs
from gql_composition.validate import Subgraph
from gql_language.parser import parse
from gql_seamstress.cli import run_seamstress
from gql_seamstress.compose import FLOATING_VERSION_WARNING, MERGING
from gql_seamstress.compose import absolute_path, composition_error
from gql_seamstress.federation_version import FEDERATION_ONE_UNSUPPORTED
from std.testing import TestSuite, assert_equal, assert_true

comptime DIR = "/tmp/gql_seamstress_compose"


def _write(name: String, text: String) raises -> String:
    makedirs(DIR, exist_ok=True)
    var path = DIR + "/" + name
    with open(path, "w") as file:
        file.write(text)
    return path


def _fixture_config(
    names: List[String], sdl: List[String], version: String
) raises -> String:
    var config = String("federation_version: " + version + "\nsubgraphs:\n")
    for index in range(len(names)):
        _ = _write(names[index] + ".graphql", sdl[index])
        config += (
            "  "
            + names[index]
            + ":\n    routing_url: http://"
            + names[index]
            + ".example.com/graphql\n    schema:\n      file: ./"
            + names[index]
            + ".graphql\n"
        )
    return _write("supergraph.yaml", config)


def _compose(path: String, format: String = "plain") raises -> List[String]:
    var out = run_seamstress(
        ["supergraph", "compose", "--config", path, "--format", format]
    )
    return [out.stdout, out.stderr, String(out.exit_code)]


def test_compose_hive_fixtures() raises:
    var basic = _fixture_config(BASIC_SUBGRAPHS(), BASIC_SDL(), "=2.3.0")
    var out = _compose(basic)
    assert_equal(out[0], BASIC_SUPERGRAPH() + "\n")
    assert_equal(out[1], MERGING)
    assert_equal(out[2], "0")
    var stars = _fixture_config(STARS_STUFF_SUBGRAPHS(), STARS_STUFF_SDL(), "2")
    var composed = _compose(stars)
    assert_equal(composed[0], STARS_STUFF_SUPERGRAPH() + "\n")
    assert_equal(composed[1], MERGING + FLOATING_VERSION_WARNING)


def test_compose_matches_gql_composition() raises:
    var names = BASIC_SUBGRAPHS()
    var sdl = BASIC_SDL()
    var subgraphs = List[Subgraph]()
    for index in range(len(names)):
        subgraphs.append(
            Subgraph(
                names[index],
                "http://" + names[index] + ".example.com/graphql",
                parse(sdl[index]),
            )
        )
    var direct = compose_subgraphs(subgraphs)
    var path = _fixture_config(names, sdl, "=2.3.0")
    var json = _compose(path, "json")
    assert_true(
        json[0].startswith('{"json_version":"1","data":{"core_schema":')
    )
    assert_true(
        json[0].endswith(
            ',"hints":[],"federation_version":"=2.3.0","plugins":[],"success":true},"error":null}\n'
        )
    )
    assert_equal(_compose(path)[0], direct.supergraph_sdl + "\n")


def test_compose_sources() raises:
    var pool = start_endpoint()
    var base = "http://127.0.0.1:" + String(pool.port) + "/subgraph/"
    var path = _write(
        "sources.yaml",
        "federation_version: =2.3.0\nsubgraphs:\n  products:\n    schema:\n    "
        "  subgraph_url: "
        + base
        + "products\n  reviews:\n    routing_url:"
        " http://reviews\n    schema:\n      subgraph_url: "
        + base
        + "reviews\n      introspection_headers:\n        x-a: b\n  users:\n   "
        " schema:\n      sdl: |\n        extend schema @link(url:"
        ' "https://specs.apollo.dev/federation/v2.3")\n        type Query {'
        " me: String }\n",
    )
    var out = _compose(path)
    assert_equal(out[2], "0")
    assert_true(
        out[0].find(
            '@join__graph(name: "products", url: "' + base + 'products")'
        )
        >= 0
    )
    assert_true(
        out[0].find('@join__graph(name: "reviews", url: "http://reviews")') >= 0
    )
    assert_true(out[0].find('@join__graph(name: "users", url: "")') >= 0)
    var stdin = run_seamstress(
        ["supergraph", "compose", "--config", "-"],
        String(
            "subgraphs:\n  a:\n    schema:\n      sdl: 'type Query { a: Int"
            " }'\n"
        ),
    )
    assert_equal(stdin.exit_code, 0)
    var null = _write(
        "null.yaml",
        "subgraphs:\n  n:\n    schema:\n      subgraph_url: http://127.0.0.1:"
        + String(pool.port)
        + "/null\n",
    )
    assert_true(
        _compose(null)[1].endswith(
            '    n: Failed to introspect the subgraph "n": No introspection'
            " response available.\n"
        )
    )
    _ = pool.stop()


def test_resolve_errors() raises:
    var path = _write(
        "broken.yaml",
        (
            "federation_version: =2.3.0\nsubgraphs:\n  films:\n    schema:\n   "
            "   file: ./missing.graphql\n  gone:\n    schema:\n     "
            " subgraph_url: http://127.0.0.1:1/x\n  remote:\n    schema:\n     "
            " graphref: g@v\n      subgraph: s\n  dir:\n    schema:\n     "
            " file: /tmp\n"
        ),
    )
    var out = _compose(path)
    assert_equal(
        out[1],
        MERGING
        + "error: Error resolving subgraphs\n\nCaused by:\n    Unable to"
        " resolve"
        " subgraphs.\n    dir: Could not find schema file (/tmp) relative to ("
        + DIR
        + ") for subgraph `dir`: "
        + String(
            out[1][
                byte = out[1].find("`dir`: ") + 7 : out[1].find("\n    films")
            ]
        )
        + "\n    films: Could not find schema file (./missing.graphql) relative"
        " to ("
        + DIR
        + ") for subgraph `films`: No such file or directory (os error 2)\n   "
        ' gone: Failed to introspect the subgraph "gone": Service error:'
        " Upstream service error: Connect error\n    remote: Failed to fetch"
        " the sdl for subgraph `remote` from remote: GraphOS is not available"
        " offline\n",
    )
    assert_equal(out[2], "1")
    var json = _compose(path, "json")
    assert_true(
        json[0].startswith(
            '{"json_version":"1","data":{"plugins":[],"success":false},"error":{"message":"Error'
            ' resolving subgraphs","causes":['
        )
    )


def test_composition_errors() raises:
    var path = _write(
        "invalid.yaml",
        (
            "federation_version: =2.3.0\nsubgraphs:\n  a:\n    schema:\n     "
            " sdl: 'type Query { a: Int }'\n  b:\n    schema:\n      sdl: 'type"
            " Query { a: String }'\n"
        ),
    )
    var subgraphs = List[Subgraph]()
    subgraphs.append(Subgraph("a", None, parse("type Query { a: Int }")))
    subgraphs.append(Subgraph("b", None, parse("type Query { a: String }")))
    var expected = composition_error(compose_subgraphs(subgraphs).errors)
    var out = _compose(path)
    assert_equal(out[1], MERGING + expected.text())
    assert_true(out[1].find("error[E029]: Encountered ") >= 0)
    assert_equal(_compose(path, "json")[0], expected.json() + "\n")
    var broken = _write(
        "syntax.yaml",
        (
            "federation_version: =2.3.0\nsubgraphs:\n  a:\n    schema:\n     "
            " sdl: 'type Query {'\n"
        ),
    )
    var syntax = _compose(broken)
    assert_true(
        syntax[1].startswith(
            MERGING
            + "error[E029]: Encountered 1 build error while trying to build a"
            " supergraph.\n\nCaused by:\n    INVALID_GRAPHQL: [a] Syntax Error:"
        )
    )
    assert_true(
        syntax[1].endswith(
            "\n    \n        The subgraph schema you provided is invalid. See"
            " https://www.apollographql.com/docs/federation/errors/ for more"
            " information on resolving build errors.\n"
        )
    )
    var none = _write(
        "none.yaml", "federation_version: =2.3.0\nsubgraphs: {}\n"
    )
    assert_equal(_compose(none)[2], "1")


def test_configuration_errors() raises:
    var missing = _compose(DIR + "/nope.yaml")
    assert_equal(
        missing[1],
        MERGING
        + "error: Failed to load the supergraph config\n\nCaused by:\n    Could"
        " not read the supergraph config at "
        + DIR
        + "/nope.yaml: No such file or directory (os error 2)\n",
    )
    var syntax = _compose(
        _write("syntax-error.yaml", "subgraphs:\n  a: 'open\n")
    )
    assert_equal(
        syntax[1],
        MERGING
        + "error: Failed to load the supergraph config\n\nCaused by:\n    0:"
        " Failed to deserialise the supergraph config\n    1: line 2: a quoted"
        " scalar is not closed\n",
    )
    var directory = _compose(DIR)
    assert_true(directory[1].find("Failed to load the supergraph config") >= 0)
    var fed_one = "error[E064]: " + FEDERATION_ONE_UNSUPPORTED + "\n"
    assert_equal(
        _compose(_write("one.yaml", "federation_version: 1\nsubgraphs: {}\n"))[
            1
        ],
        MERGING + fed_one,
    )
    assert_equal(
        _compose(
            _write("pin.yaml", "federation_version: =1.0.0\nsubgraphs: {}\n")
        )[1],
        MERGING + fed_one,
    )
    var flag = run_seamstress(
        [
            "supergraph",
            "compose",
            "--config",
            DIR + "/none.yaml",
            "--federation-version",
            "=0.36.0",
        ]
    )
    assert_equal(flag.stderr, MERGING + fed_one)
    var flag_two = run_seamstress(
        [
            "supergraph",
            "compose",
            "--config",
            DIR + "/one.yaml",
            "--federation-version",
            "=2.3.0",
        ]
    )
    assert_equal(flag_two.stderr.find("E064"), -1)


def test_select_federation_version() raises:
    # Port of `test_select_federation_version_defaults_to_fed_two` of Rover
    # `src/composition/supergraph/config/resolver/mod.rs`, and of
    # `test_resolve_from_user_selection` and
    # `test_resolve_from_supergraph_config` of `federation.rs` there.
    var subgraphs = String(
        "subgraphs:\n  a:\n    schema:\n      sdl: 'extend schema @link(url:"
        ' "https://specs.apollo.dev/federation/v2.3") type Query { a: Int'
        " }'\n"
    )
    var default = _compose(_write("default.yaml", subgraphs), "json")
    assert_true(default[0].find('"federation_version":"2"') >= 0, default[0])
    var pinned = _write(
        "pinned.yaml", "federation_version: =2.3.0\n" + subgraphs
    )
    var config = _compose(pinned, "json")
    assert_true(config[0].find('"federation_version":"=2.3.0"') >= 0, config[0])
    var user = run_seamstress(
        [
            "supergraph",
            "compose",
            "--config",
            pinned,
            "--federation-version",
            "=2.4.0",
            "--format",
            "json",
        ]
    )
    assert_true(
        user.stdout.find('"federation_version":"=2.4.0"') >= 0, user.stdout
    )


def test_absolute_path() raises:
    assert_equal(absolute_path("/a/./b/../c//d"), "/a/c/d")
    assert_equal(absolute_path("/.."), "/")
    assert_true(absolute_path("x/y").endswith("/x/y"))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `seamstress subgraph publish`, `delete` and `list`.

Each command runs against the stub gateway of `_gateway.mojo`. The
messages and the JSON follow the `SubgraphPublishResponse`,
`SubgraphDeleteResponse` and `SubgraphList` cases of Rover
`src/command/output.rs`; those Rover tests need GraphOS, so they are not
ported.
"""

from std.os import setenv, unsetenv

from _gateway import start_gateway
from gql_seamstress.cli import run_seamstress
from gql_seamstress.publish import PublishedEntry, gateway_base, read_schema
from gql_seamstress.publish import read_state, registry_token, subgraph_table
from gql_seamstress.publish import utc_time
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime SDL = "type Query {\n  a: Int\n}\n"


def _run(
    args: List[String], stdin: Optional[String] = None
) raises -> List[String]:
    var out = run_seamstress(args, stdin)
    return [out.stdout, out.stderr, String(out.exit_code)]


def test_publish_update_list_and_delete() raises:
    _ = unsetenv("APOLLO_KEY")
    _ = unsetenv("SCORCHQL_TOKEN")
    var pool = start_gateway()
    var gateway = "http://127.0.0.1:" + String(pool.port)
    var listed = _run(["subgraph", "list", gateway + "/graphql"])
    assert_equal(
        listed[0],
        (
            "┌──────┬─────────────┬──────────────┐\n│ Name ┆ Routing Url ┆ Last"
            " Updated"
            " │\n╞══════╪═════════════╪══════════════╡\n└──────┴─────────────┴──────────────┘\n"
        ),
    )
    assert_equal(listed[1], "Listing subgraphs for " + gateway + ".\n")

    var publish: List[String] = [
        "subgraph",
        "publish",
        gateway + "/",
        "--name",
        "products",
        "--schema",
        "-",
        "--routing-url",
        "http://127.0.0.1:4001/",
    ]
    var created = _run(publish, String(SDL))
    assert_equal(created[0], "")
    assert_equal(
        created[1],
        "Publishing SDL to "
        + gateway
        + " (subgraph: products).\nA new subgraph called 'products' was"
        " created in '"
        + gateway
        + "' (#1)\nThe supergraph schema for '"
        + gateway
        + "' was updated, composed from the updated 'products' subgraph\n",
    )
    assert_equal(created[2], "0")

    var same = _run(publish, String(SDL))
    assert_equal(
        same[1],
        "Publishing SDL to "
        + gateway
        + " (subgraph: products).\nThe 'products' subgraph was NOT updated"
        " because no changes were detected\nThe supergraph schema for '"
        + gateway
        + "' was NOT updated with a new schema\n",
    )

    # Without --schema and --routing-url, the gateway introspects the URL
    # that it has.
    var updated = _run(
        ["--format", "json", "subgraph", "publish", gateway, "-n", "products"]
    )
    assert_equal(
        updated[0],
        (
            '{"json_version":"1","data":{"api_schema_hash":"2",'
            '"supergraph_was_updated":true,"subgraph_was_created":false,'
            '"subgraph_was_updated":true,"launch_url":null,"launch_cli_copy":null,'
            '"launch_status":null,"launch_superseded":false,'
            '"downstream_launches":[],"success":true},"error":null}\n'
        ),
    )
    assert_equal(
        updated[1],
        "Publishing SDL to " + gateway + " (subgraph: products).\n",
    )
    var plain = _run(["subgraph", "publish", gateway, "--name=products"])
    assert_true("was NOT updated because no changes" in plain[1])
    assert_true("' was updated (#" not in plain[1])
    var changed_url = _run(
        [
            "subgraph",
            "publish",
            gateway,
            "--name",
            "products",
            "--routing-url=http://127.0.0.1:4009/",
        ]
    )
    assert_true(
        "The 'products' subgraph in '" + gateway + "' was updated (#3)"
        in changed_url[1]
    )

    listed = _run(["--format", "json", "subgraph", "list", gateway])
    assert_equal(
        listed[0],
        (
            '{"json_version":"1","data":{"subgraphs":[{"name":"products",'
            '"url":"http://127.0.0.1:4009/","updated_at":{"local":'
            '"2025-10-09T08:53:20Z","utc":"2025-10-09T08:53:20Z"}}],'
            '"success":true},"error":null}\n'
        ),
    )

    var deleted = _run(
        ["subgraph", "delete", gateway, "--name", "products", "--confirm"]
    )
    assert_equal(deleted[0], "")
    assert_equal(
        deleted[1],
        "The 'products' subgraph was removed from '"
        + gateway
        + "'. The remaining subgraphs were composed.\n",
    )
    var again = _run(
        [
            "--format",
            "json",
            "subgraph",
            "delete",
            gateway,
            "--name",
            "products",
            "--confirm",
        ]
    )
    assert_equal(
        again[0],
        (
            '{"json_version":"1","data":{"supergraph_was_updated":false,'
            '"success":true},"error":null}\n'
        ),
    )
    var missing = _run(
        ["subgraph", "delete", gateway, "--name", "products", "--confirm"]
    )
    assert_equal(
        missing[1],
        "WARN: The supergraph schema for '"
        + gateway
        + "' was not updated. The 'products' subgraph is not published.\n",
    )
    _ = pool.stop()


def test_refusals() raises:
    _ = unsetenv("APOLLO_KEY")
    _ = unsetenv("SCORCHQL_TOKEN")
    var pool = start_gateway()
    var gateway = "http://127.0.0.1:" + String(pool.port)
    var new = _run(["subgraph", "publish", gateway, "--name", "fresh"])
    assert_equal(
        new[1],
        (
            "error: No routing URL is known for the new subgraph 'fresh'.\n "
            "       Pass the URL of the subgraph with --routing-url.\n"
        ),
    )
    assert_equal(new[2], "1")
    var clash = _run(
        [
            "subgraph",
            "publish",
            gateway,
            "--name",
            "clash",
            "--routing-url",
            "http://x/",
        ]
    )
    assert_equal(
        clash[1],
        "Publishing SDL to "
        + gateway
        + " (subgraph: clash).\nerror: The gateway '"
        + gateway
        + "' refused the subgraph 'clash'.\n\nCaused by:\n    0: first"
        " problem\n    1: second problem\n",
    )
    var no_url = _run(
        ["subgraph", "publish", gateway, "--name", "clash2", "--no-url"]
    )
    assert_true("refused the subgraph 'clash2'" in no_url[1])
    var both = _run(
        [
            "subgraph",
            "publish",
            gateway,
            "--name",
            "a",
            "--no-url",
            "--routing-url",
            "http://x/",
            "--allow-invalid-routing-url",
        ]
    )
    assert_equal(
        both[1],
        "error: You cannot use --no-url and --routing-url at the same time.\n",
    )
    var unconfirmed = _run(["subgraph", "delete", gateway, "--name", "a"])
    assert_equal(
        unconfirmed[1],
        (
            "error: seamstress cannot ask to confirm the delete of 'a'.\n      "
            "  Pass --confirm to delete it.\n"
        ),
    )
    assert_equal(unconfirmed[2], "1")

    var broken = _run(["subgraph", "list", gateway + "/broken"])
    assert_equal(
        broken[1],
        "Listing subgraphs for "
        + gateway
        + "/broken.\nerror: The gateway '"
        + gateway
        + "/broken' answered HTTP 500.\n\nCaused by:\n    boom\n",
    )
    var other = _run(["subgraph", "list", gateway + "/other"])
    assert_true(
        "error: The gateway '" + gateway + "/other' is not a ScorchQL gateway."
        in other[1]
    )
    assert_true("the gateway state has no 'subgraphs' list" in other[1])
    var publish_other = _run(
        ["subgraph", "publish", gateway + "/broken", "--name", "a"]
    )
    assert_true("answered HTTP 500" in publish_other[1])
    _ = pool.stop()


def test_token() raises:
    _ = unsetenv("APOLLO_KEY")
    _ = unsetenv("SCORCHQL_TOKEN")
    assert_false(registry_token())
    var pool = start_gateway()
    var gateway = "http://127.0.0.1:" + String(pool.port)
    var publish: List[String] = [
        "subgraph",
        "publish",
        gateway,
        "--name",
        "locked",
        "--routing-url",
        "http://x/",
    ]
    var refused = _run(publish)
    assert_equal(
        refused[1],
        "Publishing SDL to "
        + gateway
        + " (subgraph: locked).\nerror: Invalid credentials provided. Set"
        " APOLLO_KEY or SCORCHQL_TOKEN to the token of the gateway.\n\nCaused"
        " by:\n    This gateway needs 'Authorization: Bearer <token>'.\n",
    )
    _ = setenv("SCORCHQL_TOKEN", "wrong")
    _ = setenv("APOLLO_KEY", "s3cret")
    assert_equal(registry_token().value(), "s3cret")
    var accepted = _run(publish)
    assert_true(" (subgraph: locked) using a registry token.\n" in accepted[1])
    assert_equal(accepted[2], "0")
    _ = unsetenv("APOLLO_KEY")
    assert_equal(registry_token().value(), "wrong")
    var removed = _run(
        ["subgraph", "delete", gateway, "--name", "locked", "--confirm"]
    )
    assert_true("Invalid credentials provided" in removed[1])
    _ = unsetenv("SCORCHQL_TOKEN")
    _ = pool.stop()


def test_no_gateway() raises:
    var down = "http://127.0.0.1:1"
    var expected = (
        "error: Service error\n\nCaused by:\n    0: Upstream service error\n   "
        " 1: Connect error\n"
    )
    assert_equal(
        _run(["subgraph", "list", down])[1],
        "Listing subgraphs for " + down + ".\n" + expected,
    )
    assert_equal(
        _run(["subgraph", "publish", down, "--name", "a"])[1], expected
    )
    assert_equal(
        _run(["subgraph", "delete", down, "--name", "a", "--confirm"])[1],
        expected,
    )


def test_usage_errors() raises:
    var hint = "\nFor more information, try '--help'.\n"
    var publish_usage = (
        "\nUsage: seamstress subgraph publish [OPTIONS] --name <SUBGRAPH_NAME>"
        " <GRAPH_REF>\n"
    )
    var none = _run(["subgraph", "publish", "--name", "a"])
    assert_equal(
        none[1],
        "error: the following required arguments were not provided:\n "
        " <GRAPH_REF>\n"
        + publish_usage
        + hint,
    )
    assert_equal(none[2], "2")
    var nameless = _run(["subgraph", "delete", "http://x"])
    assert_true("  --name <SUBGRAPH_NAME>\n" in nameless[1])
    assert_true("seamstress subgraph delete [OPTIONS]" in nameless[1])
    var extra = _run(["subgraph", "list", "http://x", "http://y"])
    assert_equal(
        extra[1],
        "error: unexpected argument 'http://y' found\n\nUsage: seamstress"
        " subgraph list <GRAPH_REF>\n"
        + hint,
    )
    var flag = _run(["subgraph", "list", "http://x", "--name", "a"])
    assert_true("unexpected argument '--name' found" in flag[1])
    var confirm = _run(["subgraph", "publish", "http://x", "--confirm"])
    assert_true("unexpected argument '--confirm' found" in confirm[1])
    var ref_name = _run(["subgraph", "list", "graph@current"])
    assert_equal(
        ref_name[1],
        "error: invalid value 'graph@current' for '<GRAPH_REF>': seamstress"
        " publishes to a ScorchQL gateway: pass its URL, such as"
        " http://localhost:4000\n"
        + hint,
    )
    var empty = _run(
        ["subgraph", "publish", "http://x", "--name", "a", "-s", "-"],
        String("\n"),
    )
    assert_equal(
        empty[1],
        (
            "error: The SDL you passed was empty\n        Make sure the command"
            " you are piping to seamstress contains output.\n"
        ),
    )


def test_read_schema() raises:
    var piped = read_schema("-", String(SDL))
    assert_equal(piped[0], SDL)
    assert_false(piped[1])
    var unread = read_schema("-", None)
    assert_equal(unread[1].value().message, "Failed to read SDL from stdin")
    var lost = read_schema("/nonexistent/x.graphql", None)
    assert_equal(
        lost[1].value().message,
        "Invalid path. No file found at /nonexistent/x.graphql",
    )
    var path = "/dev/null"
    var blank = read_schema(path, None)
    assert_equal(blank[1].value().message, "The SDL you passed was empty")
    assert_equal(
        blank[1].value().suggestions[0],
        "Make sure /dev/null contains a schema.",
    )


def test_gateway_base() raises:
    assert_equal(gateway_base("http://h:4000"), "http://h:4000")
    assert_equal(gateway_base("http://h:4000/"), "http://h:4000")
    assert_equal(gateway_base("http://h:4000/graphql/"), "http://h:4000")
    assert_equal(gateway_base("http://h/api/graphql"), "http://h/api")


def test_utc_time() raises:
    var time = utc_time(1760000000)
    assert_equal(time[0], "2025-10-09 08:53:20 UTC")
    assert_equal(time[1], "2025-10-09T08:53:20Z")
    assert_equal(utc_time(951782400)[1], "2000-02-29T00:00:00Z")
    assert_equal(utc_time(0)[0], "1970-01-01 00:00:00 UTC")


def test_subgraph_table() raises:
    var entries: List[PublishedEntry] = [
        PublishedEntry("a", "", 0),
        PublishedEntry("longer-name", "http://h/", 1760000000),
    ]
    assert_equal(
        subgraph_table(entries),
        (
            "┌─────────────┬─────────────┬─────────────────────────┐\n"
            "│    Name     ┆ Routing Url ┆      Last Updated       │\n"
            "╞═════════════╪═════════════╪═════════════════════════╡\n"
            "│ a           ┆ unspecified ┆ N/A                     │\n"
            "├╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┤\n"
            "│ longer-name ┆ http://h/   ┆ 2025-10-09 08:53:20 UTC │\n"
            "└─────────────┴─────────────┴─────────────────────────┘"
        ),
    )


def test_read_state() raises:
    var entries = read_state(
        '{"subgraphs":[{"name":"a","url":"http://h/","publishedAt":5},'
        '{"name":7},{"name":"b","url":null}]}'
    )
    assert_equal(len(entries), 2)
    assert_equal(entries[0].url, "http://h/")
    assert_equal(entries[0].published_at, 5)
    assert_equal(entries[1].name, "b")
    assert_equal(entries[1].url, "")
    assert_equal(entries[1].published_at, 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the explorer page, `gql_scorchql.explorer`.

ScorchQL has no upstream, so there is no upstream test suite to port.
"""

from gql_scorchql.explorer import (
    BOOT_MARKER,
    EXPLORER_HTML,
    FAVICON_SVG,
    TITLE_MARKER,
    escape_html,
    explorer_page,
    script_json,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_escape_html() raises:
    assert_equal(escape_html("plain"), "plain")
    assert_equal(
        escape_html("<a href=\"x\">'Q&A'</a>"),
        "&lt;a href=&quot;x&quot;&gt;&#39;Q&amp;A&#39;&lt;/a&gt;",
    )
    assert_equal(escape_html("🔥 fire"), "🔥 fire")
    assert_equal(escape_html(""), "")


def test_script_json() raises:
    assert_equal(script_json("/graphql"), '"/graphql"')
    assert_equal(script_json('</script>"x"'), '"\\u003c/script>\\"x\\""')


def test_the_page_has_one_of_each_marker() raises:
    assert_equal(EXPLORER_HTML.count(TITLE_MARKER), 1)
    assert_equal(EXPLORER_HTML.count(BOOT_MARKER), 1)
    assert_true(EXPLORER_HTML.startswith("<!doctype html>"))
    assert_true(EXPLORER_HTML.endswith("</html>\n"))


def test_explorer_page() raises:
    var page = explorer_page("Fire <Lab>", "/api/graphql")
    assert_true("<title>Fire &lt;Lab&gt;</title>" in page)
    assert_true(
        'const BOOT = {"title":"Fire'
        ' \\u003cLab>","graphqlPath":"/api/graphql"};'
        in page
    )
    assert_false(TITLE_MARKER in page)
    assert_false(BOOT_MARKER in page)


def test_the_publish_hint_uses_seamstress() raises:
    assert_true("seamstress subgraph publish " in EXPLORER_HTML)
    assert_true("--routing-url " in EXPLORER_HTML)
    assert_true("SCORCHQL_TOKEN=<token> " in EXPLORER_HTML)
    assert_false("scorchql publish" in EXPLORER_HTML)
    assert_false("the scorchql program" in EXPLORER_HTML)


def test_the_page_needs_no_network_resource() raises:
    assert_false("<script src" in EXPLORER_HTML)
    assert_false("stylesheet" in EXPLORER_HTML)
    assert_false('src="http' in EXPLORER_HTML)
    assert_false('href="http' in EXPLORER_HTML)
    assert_false("url(http" in EXPLORER_HTML)
    assert_false("@import" in EXPLORER_HTML)
    assert_true("graphql-transport-ws" in EXPLORER_HTML)
    assert_true("multipart/mixed" in EXPLORER_HTML)
    assert_true("text/event-stream" in EXPLORER_HTML)


def test_favicon() raises:
    assert_true(FAVICON_SVG.startswith("<svg"))
    assert_true(FAVICON_SVG.endswith("</svg>"))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

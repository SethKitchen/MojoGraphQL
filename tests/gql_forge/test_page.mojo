# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_forge.page`."""

from gql_forge.page import (
    BOOT_MARKER,
    FAVICON_SVG,
    PAGE_HTML,
    TITLE_MARKER,
    escape_html,
    forge_page,
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
    assert_equal(script_json("/forge"), '"/forge"')
    assert_equal(script_json('</script>"x"'), '"\\u003c/script>\\"x\\""')


def test_page() raises:
    assert_equal(PAGE_HTML.count(TITLE_MARKER), 1)
    assert_equal(PAGE_HTML.count(BOOT_MARKER), 1)
    var page = forge_page("Forge <Lab>")
    assert_true("<title>Forge &lt;Lab&gt;</title>" in page)
    assert_true('const BOOT = {"title":"Forge \\u003cLab>"};' in page)
    assert_false(TITLE_MARKER in page)
    assert_false(BOOT_MARKER in page)
    assert_false("<script src" in PAGE_HTML)
    assert_false("stylesheet" in PAGE_HTML)
    assert_false('src="http' in PAGE_HTML)
    assert_false('href="http' in PAGE_HTML)
    assert_false("url(http" in PAGE_HTML)
    assert_false("@import" in PAGE_HTML)
    assert_true(FAVICON_SVG.startswith("<svg"))
    assert_true(FAVICON_SVG.endswith("</svg>"))
    assert_true("Analyst" in PAGE_HTML)
    assert_true("Compare environments" in PAGE_HTML)
    assert_true("/forge/analyze" in PAGE_HTML)


def test_the_connect_hint_uses_curl() raises:
    assert_true("curl /forge/telemetry" in PAGE_HTML)
    assert_true("authorization: Bearer" in PAGE_HTML)
    assert_true("Forge does not start that process." in PAGE_HTML)
    assert_false("Studio" in PAGE_HTML)
    assert_false("scorchql publish" in PAGE_HTML)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

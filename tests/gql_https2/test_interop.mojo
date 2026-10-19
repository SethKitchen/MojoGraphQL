# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""An interop check of `listen_https2` against curl and its nghttp2 HTTP/2
stack: `h2` over TLS with ALPN, and HTTPS/1.1 on the same port.

The check runs only when `curl --version` lists `HTTP2`. Without such a
curl, each test passes at once: the suite never installs anything and
never uses the network beyond the loopback address.
"""

from std.subprocess import run
from std.testing import TestSuite, assert_true

from _h2tls import start_h2


def _has_curl() -> Bool:
    try:
        return "HTTP2" in run("curl --version 2>/dev/null")
    except:
        return False


def _curl(flags: StringSlice) raises -> String:
    var child = start_h2()
    var url = child.url("/graphql?x=1")
    var out = run(
        "curl -s -k -i --max-time 5 " + String(flags) + " " + url + " 2>&1"
    )
    child.stop()
    return out


def test_h2_over_tls() raises:
    if not _has_curl():
        return
    var out = _curl("--http2 -d hello")
    assert_true(out.startswith("HTTP/2 200"), out)
    assert_true(out.endswith("/graphql:hello"), out)


def test_http1_over_tls() raises:
    if not _has_curl():
        return
    var out = _curl("--http1.1 -d old")
    assert_true(out.startswith("HTTP/1.1 200 OK"), out)
    assert_true(out.endswith("/graphql:old"), out)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

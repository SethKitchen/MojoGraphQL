# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `src/specifications/link.spec.ts`.

The `parseLinkUrl` table is the upstream table. The other URLs check the
URL parsing; their expected values come from upstream `parseLinkUrl` in
Node.js. The `parseLinkImport` cases are in `test_link_import.mojo`.
"""

from gql_composition.link import (
    ImportKind,
    LinkImport,
    parse_link_url,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _check(url: String, expected: String) raises:
    assert_equal(String(parse_link_url(url)), expected, url)


def test_parse_link_url() raises:
    _check("https://spec.example.com/a/b/mySchema/v1.0/", "https://spec.example.com/a/b/mySchema name=mySchema version=v1.0")
    _check("https://spec.example.com/a/b/mySchema/v1.0", "https://spec.example.com/a/b/mySchema name=mySchema version=v1.0")
    _check("https://spec.example.com", "https://spec.example.com name=null version=null")
    _check("https://spec.example.com/mySchema/v0.1?q=v#frag", "https://spec.example.com/mySchema name=mySchema version=v0.1")
    _check("https://spec.example.com/mySchema/not-a-version", "https://spec.example.com/mySchema/not-a-version name=not-a-version version=null")
    _check("https://spec.example.com/v1.0", "https://spec.example.com name=null version=v1.0")
    _check("https://spec.example.com/vX", "https://spec.example.com/vX name=vX version=null")
    _check("file:///extensions/permissions", "file:///extensions/permissions name=permissions version=null")
    _check("https://specs.apollo.dev/federation/not-a-version", "https://specs.apollo.dev/federation/not-a-version name=not-a-version version=null")
    _check("https://specs.apollo.dev", "https://specs.apollo.dev name=null version=null")
    _check("specs.apollo.dev", "specs.apollo.dev name=null version=null")
    _check("not-valid.apollo.dev/v1", "not-valid.apollo.dev/v1 name=null version=null")


def test_parse_link_url_more() raises:
    _check("HTTPS://Spec.Example.COM/A/v1.0", "https://spec.example.com/A name=A version=v1.0")
    _check("http://example.com:80/a/v1.0", "http://example.com/a name=a version=v1.0")
    _check("http://example.com:8080/a/v1.0", "http://example.com:8080/a name=a version=v1.0")
    _check("https://example.com:443/a", "https://example.com/a name=a version=null")
    _check("https://example.com:0443/a", "https://example.com/a name=a version=null")
    _check("https://example.com:65535/a", "https://example.com:65535/a name=a version=null")
    _check("https://example.com:65536/a", "https://example.com:65536/a name=null version=null")
    _check("https://example.com:12a/a", "https://example.com:12a/a name=null version=null")
    _check("https://example.com:/a", "https://example.com/a name=a version=null")
    _check("ws://example.com:80/a", "ws://example.com/a name=a version=null")
    _check("wss://example.com:443/a", "wss://example.com/a name=a version=null")
    _check("wss://example.com:444/a", "wss://example.com:444/a name=a version=null")
    _check("ftp://example.com:21/a", "ftp://example.com/a name=a version=null")
    _check("ftp://example.com:22/a", "ftp://example.com:22/a name=a version=null")
    _check("https://user:pass@example.com/a/v2", "https://example.com/a name=a version=v2")
    _check("https://user@example.com:81/a", "https://example.com:81/a name=a version=null")
    _check("https://example.com/a/./b/../c/v1.0", "https://example.com/a/c name=c version=v1.0")
    _check("https://example.com/../../a", "https://example.com/a name=a version=null")
    _check("https://example.com/a/%2e%2E/b", "https://example.com/b name=b version=null")
    _check("https://example.com/a b/c\"d<e>f`g{h}i/v1.0", "https://example.com/a%20b/c%22d%3Ce%3Ef%60g%7Bh%7Di name=c%22d%3Ce%3Ef%60g%7Bh%7Di version=v1.0")
    _check("https://example.com/café/v1.0", "https://example.com/caf%C3%A9 name=caf%C3%A9 version=v1.0")
    _check("https://example.com\\a\\b/v1", "https://example.com/a/b name=b version=v1")
    _check("https://example.com/a//b///v1", "https://example.com/a/b name=b version=v1")
    _check("https://example.com?x=1", "https://example.com name=null version=null")
    _check("https://example.com#f", "https://example.com name=null version=null")
    _check("https://", "https:// name=null version=null")
    _check("https:///a", "https://a name=null version=null")
    _check("https:", "https: name=null version=null")
    _check("http:example.com/a", "http://example.com/a name=a version=null")
    _check("foo://host/a/v1.0", "null/a name=a version=v1.0")
    _check("foo://host:99/a", "null/a name=a version=null")
    _check("foo:/a/b", "null/a/b name=b version=null")
    _check("foo:bar", "null/bar name=bar version=null")
    _check("mailto:a@b.c", "null/a@b.c name=a@b.c version=null")
    _check("1http://x/a", "1http://x/a name=null version=null")
    _check("a+b-c.d://h/p", "null/p name=p version=null")
    _check("  https://example.com/a  ", "https://example.com/a name=a version=null")
    _check("\thttps://example.com/a\n", "https://example.com/a name=a version=null")
    _check("file://host/a/b", "file:///a/b name=b version=null")
    _check("file:/a/b/v2", "null/a/b name=b version=v2")
    _check("file:a", "file:///a name=a version=null")
    _check("https://example.com/V1", "https://example.com name=null version=V1")
    _check("https://example.com/a/v", "https://example.com/a/v name=v version=null")
    _check("https://a%41/x", "https://aa/x name=x version=null")
    _check("https://a%4/x", "https://a%4/x name=null version=null")
    _check("https://a%G1/x", "https://a%G1/x name=null version=null")
    _check("https://a%4G/x", "https://a%4G/x name=null version=null")
    _check("https://a%2f/x", "https://a%2f/x name=null version=null")
    _check("https://a%01/x", "https://a%01/x name=null version=null")
    _check("https://a%7F/x", "https://a%7F/x name=null version=null")
    _check("https://a%20/x", "https://a%20/x name=null version=null")
    _check("https://a%23/x", "https://a%23/x name=null version=null")
    _check("https://a%3A/x", "https://a%3A/x name=null version=null")
    _check("https://a%3C/x", "https://a%3C/x name=null version=null")
    _check("https://a%3E/x", "https://a%3E/x name=null version=null")
    _check("https://a%3F/x", "https://a%3F/x name=null version=null")
    _check("https://a%40/x", "https://a%40/x name=null version=null")
    _check("https://a%5B/x", "https://a%5B/x name=null version=null")
    _check("https://a%5C/x", "https://a%5C/x name=null version=null")
    _check("https://a%5D/x", "https://a%5D/x name=null version=null")
    _check("https://a%5E/x", "https://a%5E/x name=null version=null")
    _check("https://a%7C/x", "https://a%7C/x name=null version=null")
    _check("https://a%25/x", "https://a%25/x name=null version=null")
    _check("https://a%61%62/x", "https://aab/x name=x version=null")
    _check("https://a:b:80/x", "https://a:b:80/x name=null version=null")
    _check("https://a<b/x", "https://a<b/x name=null version=null")
    _check("https://a^b/x", "https://a^b/x name=null version=null")
    _check("https://a|b/x", "https://a|b/x name=null version=null")
    _check("https://@a/x", "https://a/x name=x version=null")
    _check("https://a@/x", "https://a@/x name=null version=null")
    _check("https://a:/x", "https://a/x name=x version=null")
    _check("https://a:99999/x", "https://a:99999/x name=null version=null")
    _check("https://A.B/x", "https://a.b/x name=x version=null")
    _check("https://example.com/a0001b/v1", "https://example.com/a0001b name=a0001b version=v1")
    _check("https://exa mple.com/a", "https://exa mple.com/a name=null version=null")
    _check("", " name=null version=null")


def test_import_kind() raises:
    assert_equal(String(ImportKind.of("@key")), "directive")
    assert_equal(String(ImportKind.of("FieldSet")), "type")
    assert_true(ImportKind(1).is_valid())
    assert_false(ImportKind(2).is_valid())
    assert_equal(String(ImportKind(2)), "<invalid>")


def test_link_import_text() raises:
    assert_equal(
        String(LinkImport(ImportKind.DIRECTIVE, "@key", String("@id"))),
        "directive @key as @id",
    )
    assert_equal(
        String(LinkImport(ImportKind.TYPE, "FieldSet", None)), "type FieldSet"
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
